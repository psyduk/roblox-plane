--!nonstrict
-- One atomic record per player. UpdateAsync owns acquisition, renewal and release
-- of a fenced session lease. A failed load is NEVER eligible for a later write.
-- Reference: https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing
local PlayerStats = {}
PlayerStats.__index = PlayerStats
PlayerStats.DATASTORE_NAME = "Skybound_PlayerStats_v1"
PlayerStats.SCHEMA_VERSION = 1
PlayerStats.RECEIPT_LIMIT = 128

local FIELDS = { "bestDistance", "totalFlights", "wins", "losses", "draws", "currentStreak", "bestStreak", "practiceFlights" }
local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function copyStats(source)
	local result = {}
	for _, field in ipairs(FIELDS) do result[field] = source and source[field] or 0 end
	return result
end
local function copyArray(source)
	local result = {}
	for _, value in ipairs(source or {}) do table.insert(result, value) end
	return result
end
local function decode(value)
	if value == nil then return { schemaVersion = 1, stats = copyStats(), receipts = {} } end
	if type(value) ~= "table" or value.schemaVersion ~= 1 or type(value.stats) ~= "table" then return nil end
	local stats = copyStats(value.stats)
	for _, field in ipairs(FIELDS) do
		if not finite(stats[field]) or stats[field] < 0 or stats[field] > 1e12 then return nil end
		if field ~= "bestDistance" and stats[field] % 1 ~= 0 then return nil end
	end
	if value.lease ~= nil and (type(value.lease) ~= "table" or type(value.lease.id) ~= "string" or not finite(value.lease.expiresAt)) then return nil end
	local receipts = {}
	if value.receipts ~= nil and type(value.receipts) ~= "table" then return nil end
	for _, id in ipairs(value.receipts or {}) do
		if type(id) ~= "string" or #id > 160 then return nil end
		table.insert(receipts, id)
	end
	while #receipts > PlayerStats.RECEIPT_LIMIT do table.remove(receipts, 1) end
	return { schemaVersion = 1, stats = stats, receipts = receipts, lease = value.lease, lastWrite = value.lastWrite }
end

function PlayerStats.new(options)
	options = options or {}
	assert(type(options.sessionId) == "string" and #options.sessionId > 0, "A unique server session ID is required")
	return setmetatable({
		store = options.store, sessionId = options.sessionId, sessionOnly = options.sessionOnly == true,
		clock = options.clock or os.time, monotonic = options.monotonic or os.clock,
		wait = options.wait or function(seconds) task.wait(seconds) end,
		spawn = options.spawn or function(callback) task.spawn(callback) end,
		onChanged = options.onChanged, jitter = options.jitter or math.random,
		leaseSeconds = options.leaseSeconds or 180, saveInterval = options.saveInterval or 45,
		maxAttempts = options.maxAttempts or 3, records = {}, sequence = 0, nextSweep = 0,
	}, PlayerStats)
end

function PlayerStats:_changed(record)
	if self.onChanged then pcall(self.onChanged, record.userId, record.status) end
end

function PlayerStats:open(userId)
	self.sequence = self.sequence + 1
	local token = self.sessionId .. ":" .. tostring(userId) .. ":" .. tostring(self.sequence)
	local record = { userId = userId, token = token, key = "player_" .. tostring(userId), stats = copyStats(),
		status = self.sessionOnly and "session_only" or "loading", safe = false, busy = false,
		version = 0, savedVersion = 0, writeSequence = 0, receipts = {}, seen = {}, pending = {},
		nextSave = self.clock() + self.saveInterval + math.abs(userId) % 15 }
	self.records[token] = record
	return record
end

function PlayerStats:get(record)
	return copyStats(record and record.stats), record and record.status or "unavailable"
end

function PlayerStats:_retry(callback)
	local lastError
	for attempt = 1, self.maxAttempts do
		local ok, result, reason = pcall(callback)
		if ok and result then return true, result end
		lastError = ok and reason or result
		if lastError == "corrupt" or lastError == "lease_lost" or lastError == "closed" then break end
		if attempt < self.maxAttempts then
			self.wait(math.min(4, 2 ^ (attempt - 1)) + self.jitter() * 0.25)
		end
	end
	return false, lastError
end

function PlayerStats:_apply(record, id, outcome)
	if record.seen[id] then return false end
	record.seen[id] = true
	table.insert(record.receipts, id)
	while #record.receipts > PlayerStats.RECEIPT_LIMIT do table.remove(record.receipts, 1) end
	local stats = record.stats
	stats.totalFlights = stats.totalFlights + 1
	if outcome.practice then
		stats.practiceFlights = stats.practiceFlights + 1
	elseif outcome.forfeit or outcome.outcome == "loss" then
		stats.losses = stats.losses + 1
		stats.currentStreak = 0
	elseif outcome.outcome == "win" then
		stats.wins = stats.wins + 1
		stats.currentStreak = stats.currentStreak + 1
		stats.bestStreak = math.max(stats.bestStreak, stats.currentStreak)
	elseif outcome.outcome == "draw" then
		stats.draws = stats.draws + 1 -- A draw preserves the current streak.
	end
	if outcome.completed and not outcome.forfeit then stats.bestDistance = math.max(stats.bestDistance, outcome.distance) end
	record.version = record.version + 1
	return true
end

function PlayerStats:recordFlight(record, resultId, input)
	if not record or record.closed or record.closing or type(resultId) ~= "string" or #resultId == 0 or #resultId > 160 then return false end
	if type(input) ~= "table" or not finite(input.distance) or input.distance < 0 or input.distance > 1e7 then return false end
	if not input.practice and input.outcome ~= "win" and input.outcome ~= "loss" and input.outcome ~= "draw" and not input.forfeit then return false end
	local outcome = { distance = input.distance, practice = input.practice == true, completed = input.completed == true,
		forfeit = input.forfeit == true, outcome = input.outcome }
	if not self:_apply(record, resultId, outcome) then return false end
	if record.status == "loading" then table.insert(record.pending, { id = resultId, outcome = outcome })
	elseif record.safe and record.status ~= "unavailable" then record.status = "pending" end
	self:_changed(record)
	return true
end

function PlayerStats:load(record)
	if not record or record.closed or record.closing or record.busy then return false end
	if self.sessionOnly then record.status = "session_only"; self:_changed(record); return true end
	if record.status ~= "loading" then return record.safe end
	if not self.store then record.status = "unavailable"; self:_changed(record); return false end
	record.busy = true
	local ok, loaded = self:_retry(function()
		local rejection
		local timestamp = self.clock()
		local result = self.store:UpdateAsync(record.key, function(old)
			rejection = nil
			local value = decode(old)
			if not value then rejection = "corrupt"; return nil end
			if value.lease and value.lease.id ~= record.token and value.lease.expiresAt > timestamp then rejection = "locked"; return nil end
			value.lease = { id = record.token, expiresAt = timestamp + self.leaseSeconds }
			return value
		end)
		if result and result.lease and result.lease.id == record.token then return result end
		return false, rejection or "load_failed"
	end)
	if ok then
		record.stats = copyStats(loaded.stats)
		record.receipts = copyArray(loaded.receipts)
		record.seen = {}
		for _, id in ipairs(record.receipts) do record.seen[id] = true end
		record.version, record.savedVersion = 0, 0
		for _, pending in ipairs(record.pending) do self:_apply(record, pending.id, pending.outcome) end
		record.pending = {}
		record.safe = true
		record.status = record.version > 0 and "pending" or "saved"
	else
		record.safe = false
		record.pending = {}
		record.status = "unavailable"
	end
	record.busy = false
	self:_changed(record)
	if record.closed and record.safe then self:save(record, true) end
	return ok
end

function PlayerStats:save(record, releaseLease)
	if not record or (record.closed and not releaseLease) or record.busy or not record.safe or self.sessionOnly or not self.store then return false end
	record.busy = true
	record.writeSequence = record.writeSequence + 1
	local operationId = record.token .. ":write:" .. tostring(record.writeSequence)
	local stats, receipts, version = copyStats(record.stats), copyArray(record.receipts), record.version
	local ok, reason = self:_retry(function()
		local rejection, alreadyCommitted
		local timestamp = self.clock()
		local result = self.store:UpdateAsync(record.key, function(old)
			rejection, alreadyCommitted = nil, false
			local value = decode(old)
			if not value then rejection = "corrupt"; return nil end
			-- A successful final write can lose its network response. Recognize its
			-- receipt without reacquiring or touching a newer server's lease.
			if releaseLease and value.lastWrite and value.lastWrite.id == operationId then alreadyCommitted = true; return nil end
			if not value.lease or value.lease.id ~= record.token then rejection = "lease_lost"; return nil end
			return { schemaVersion = 1, stats = copyStats(stats), receipts = copyArray(receipts),
				lease = not releaseLease and { id = record.token, expiresAt = timestamp + self.leaseSeconds } or nil,
				lastWrite = { id = operationId, version = version } }
		end)
		if alreadyCommitted or (result and result.lastWrite and result.lastWrite.id == operationId) then return true end
		return false, rejection or "save_failed"
	end)
	if ok then
		record.savedVersion = version
		record.status = record.version == version and "saved" or "pending"
		if releaseLease then record.safe = false; record.released = true end
	else
		record.status = "unavailable"
		if reason == "lease_lost" or reason == "corrupt" then record.safe = false end
	end
	record.busy = false
	self:_changed(record)
	if record.closed and record.safe and not releaseLease then self:save(record, true) end
	return ok
end

function PlayerStats:close(record, timeout)
	if not record or record.closed then return true end
	if record.closing then return false end
	record.closing = true
	local deadline = self.monotonic() + (timeout or 20)
	while record.busy and self.monotonic() < deadline do self.wait(0.05) end
	local saved = self.sessionOnly
	if not record.busy and record.safe then saved = self:save(record, true) end
	-- A request still in flight retains its handle until it finishes. Never let
	-- another handle use this lease; an unreleased lock expires on its own.
	record.closed = true
	self.records[record.token] = nil
	return saved
end

function PlayerStats:step()
	local timestamp = self.clock()
	if timestamp < self.nextSweep then return end
	self.nextSweep = timestamp + 1
	for _, record in pairs(self.records) do
		if record.safe and not record.busy and not record.closing and timestamp >= record.nextSave then
			record.nextSave = timestamp + self.saveInterval
			self.spawn(function() self:save(record, false) end)
		end
	end
end

function PlayerStats:shutdown(timeout)
	local deadline = self.monotonic() + (timeout or 25)
	for _, record in pairs(self.records) do
		if not record.closed and not record.closing then
			self.spawn(function() self:close(record, math.max(0, deadline - self.monotonic())) end)
		end
	end
	-- Also wait for PlayerRemoving saves that were already running when Roblox
	-- started shutdown; they share this service's active-record registry.
	while next(self.records) ~= nil and self.monotonic() < deadline do self.wait(0.05) end
	return next(self.records) == nil
end

return PlayerStats
