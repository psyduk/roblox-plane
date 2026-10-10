--!nonstrict
-- One atomic record per player. UpdateAsync owns acquisition, renewal and release
-- of a fenced session lease. Writes require a verified load and an owned lease.
-- Reference: https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing
local CosmeticCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("FlightGame"):WaitForChild("CosmeticCatalog"))
local SkillCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("FlightGame"):WaitForChild("SkillCatalog"))
local PlayerStats = {}
PlayerStats.__index = PlayerStats
PlayerStats.DATASTORE_NAME = "Skybound_PlayerStats_v1"
PlayerStats.SCHEMA_VERSION = 3
PlayerStats.MAX_CREDITS = 1e12
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
local BATTLE_FIELDS = { "matches", "wins", "losses", "draws", "currentStreak", "bestStreak" }
local function copyBattle(source)
    local result = { mastery = {}, starterAvailable = source and source.starterAvailable == true or false,
        starterChoice = source and source.starterChoice or nil, goalId = source and source.goalId or CosmeticCatalog.BATTLE_GOAL_ID }
    for _,field in ipairs(BATTLE_FIELDS) do result[field] = source and source[field] or 0 end
    for id,value in pairs(source and source.mastery or {}) do result.mastery[id] = value end
    return result
end
local function starter(id)
    for _,choice in ipairs(CosmeticCatalog.STARTER_CHOICES) do if choice == id then return true end end
    return false
end
local function decodeBattle(value)
    if type(value) ~= "table" or type(value.mastery) ~= "table" or type(value.starterAvailable) ~= "boolean" then return nil end
    for _,field in ipairs(BATTLE_FIELDS) do
        if not finite(value[field]) or value[field] < 0 or value[field] % 1 ~= 0 or value[field] > 1e12 then return nil end
    end
    for id,amount in pairs(value.mastery) do
        if not SkillCatalog.valid(id) or not finite(amount) or amount < 0 or amount % 1 ~= 0 or amount > 1e12 then return nil end
    end
    if value.starterChoice ~= nil and not starter(value.starterChoice) then return nil end
    if value.starterChoice and value.starterAvailable then return nil end
    local goal = CosmeticCatalog.get(value.goalId)
    if not goal or goal.earnedOnly or goal.price <= 0 then return nil end
    return copyBattle(value)
end
local function copyEconomy(source)
	local owned = { [CosmeticCatalog.DEFAULT_ID] = true }
	for id, value in pairs(source and source.owned or {}) do if value then owned[id] = true end end
	return { credits = source and source.credits or 0, owned = owned,
		equippedTrail = source and source.equippedTrail or CosmeticCatalog.DEFAULT_ID }
end
local function decodeEconomy(value)
	if type(value) ~= "table" or not finite(value.credits) or value.credits < 0
		or value.credits > PlayerStats.MAX_CREDITS or value.credits % 1 ~= 0 or type(value.owned) ~= "table" then return nil end
	for id, owned in pairs(value.owned) do
		if owned ~= true or not CosmeticCatalog.get(id) then return nil end
	end
	if not CosmeticCatalog.get(value.equippedTrail) or value.owned[value.equippedTrail] ~= true then return nil end
	return copyEconomy(value)
end
local function decode(value)
	if value == nil then return { schemaVersion = PlayerStats.SCHEMA_VERSION, stats = copyStats(), receipts = {}, economy = copyEconomy(), battle = copyBattle() } end
	if type(value) ~= "table" or (value.schemaVersion ~= 1 and value.schemaVersion ~= 2 and value.schemaVersion ~= PlayerStats.SCHEMA_VERSION)
		or type(value.stats) ~= "table" then return nil end
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
	local economy = value.schemaVersion == 1 and copyEconomy() or decodeEconomy(value.economy)
	if not economy then return nil end
    local battle = value.schemaVersion < 3 and copyBattle() or decodeBattle(value.battle)
    if not battle or (battle.starterChoice and not economy.owned[battle.starterChoice]) then return nil end
	return { schemaVersion = PlayerStats.SCHEMA_VERSION, stats = stats, receipts = receipts, economy = economy, battle = battle,
		lease = value.lease, lastWrite = value.lastWrite }
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
		loaded = self.sessionOnly, loadFailures = 0,
		version = 0, savedVersion = 0, writeSequence = 0, receipts = {}, seen = {}, pending = {}, economy = copyEconomy(), battle = copyBattle(),
		nextSave = self.clock() + self.saveInterval + math.abs(userId) % 15 }
	self.records[token] = record
	return record
end

function PlayerStats:get(record)
	return copyStats(record and record.stats), record and record.status or "unavailable"
end

function PlayerStats:canShop(record)
	return record ~= nil and not record.closed and not record.closing
		and (record.status == "session_only" or (record.safe and (record.status == "saved" or record.status == "pending")))
end

function PlayerStats:getBattle(record)
    local result = copyBattle(record and record.battle)
    result.title = result.matches >= 15 and "Sky Rival" or result.matches >= 5 and "Wingmate" or result.matches >= 1 and "Rookie" or "New Pilot"
    result.nextTitleAt = result.matches < 1 and 1 or result.matches < 5 and 5 or result.matches < 15 and 15 or nil
    result.status = record and record.status or "unavailable"
    result.confirmed = result.status == "saved"
    return result
end
function PlayerStats:getEconomy(record)
    local result = copyEconomy(record and record.economy)
    result.canShop = self:canShop(record)
    result.progression = self:getBattle(record)
    result.starterChoices = copyArray(CosmeticCatalog.STARTER_CHOICES)
    local goal = CosmeticCatalog.get(result.progression.goalId)
    result.goal = {id=goal.id,name=goal.name,price=goal.price,owned=result.owned[goal.id]==true,
        remaining=result.owned[goal.id] and 0 or math.max(0,goal.price-result.credits)}
    return result
end

local function feedback(ok, code, message, itemId)
	return { ok = ok, code = code, message = message, itemId = itemId }
end
function PlayerStats:_cosmetic(record, itemId, equip)
	local item = CosmeticCatalog.get(itemId)
	if not item then return feedback(false, "invalid_item", "That effect is not in the hangar shop.") end
	if not self:canShop(record) then
		local loading = record and record.status == "loading"
		return feedback(false, loading and "loading" or "unavailable",
			loading and "Your collection is still loading. Try again in a moment." or "Saving is unavailable. The shop will reopen when your data is safe.", itemId)
	end
	local economy = record.economy
    if not equip and item.earnedOnly then return feedback(false,"earned_only","Choose this trail after your first completed battle.",itemId) end
	if equip then
		if not economy.owned[itemId] then return feedback(false, "not_owned", "Unlock this trail before equipping it.", itemId) end
		if economy.equippedTrail == itemId then return feedback(true, "already_equipped", item.name .. " is already equipped.", itemId) end
		economy.equippedTrail = itemId
	else
		if economy.owned[itemId] then return feedback(false, "already_owned", "You already own " .. item.name .. ". Select Equip to use it.", itemId) end
		if economy.credits < item.price then
			return feedback(false, "insufficient_credits", "Earn " .. tostring(item.price - economy.credits) .. " more coins to buy " .. item.name .. ".", itemId)
		end
		-- The debit and ownership grant share one fenced persistence record.
		economy.credits = economy.credits - item.price
		economy.owned[itemId] = true
	end
	record.version = record.version + 1
	if not self.sessionOnly then record.status = "pending" end
	self:_changed(record)
	return feedback(true, equip and "equipped" or "purchased",
		equip and (item.name .. " equipped. Ready for takeoff.") or (item.name .. " unlocked! Select Equip to use it."), itemId)
end

function PlayerStats:buyCosmetic(record, itemId)
	return self:_cosmetic(record, itemId, false)
end

function PlayerStats:equipCosmetic(record, itemId)
	return self:_cosmetic(record, itemId, true)
end

function PlayerStats:claimStarter(record, itemId)
    if not starter(itemId) then return feedback(false,"invalid_item","Choose one of the two first-battle trails.",itemId) end
    if not self:canShop(record) then return feedback(false,"unavailable","Your collection must finish saving before this choice.",itemId) end
    if record.battle.starterChoice then return feedback(false,"already_claimed","Your first-battle trail is already in your collection.",record.battle.starterChoice) end
    if not record.battle.starterAvailable then return feedback(false,"not_earned","Complete a battle to choose your first trail.",itemId) end
    record.battle.starterAvailable = false; record.battle.starterChoice = itemId
    record.economy.owned[itemId] = true; record.economy.equippedTrail = itemId
    record.version = record.version + 1
    if not self.sessionOnly then record.status = "pending" end
    self:_changed(record)
    return feedback(true,"claimed",CosmeticCatalog.get(itemId).name.." chosen and equipped!",itemId)
end
function PlayerStats:selectGoal(record, itemId)
    local item=CosmeticCatalog.get(itemId)
    if not item or item.earnedOnly or item.price<=0 then return feedback(false,"invalid_goal","Choose an earned-coin cosmetic goal.",itemId) end
    if not self:canShop(record) then return feedback(false,"unavailable","Your collection is not ready. Try again after saving.",itemId) end
    if record.battle.goalId==itemId then return feedback(true,"already_selected",item.name.." is your goal.",itemId) end
    record.battle.goalId=itemId;record.version=record.version+1
    if not self.sessionOnly then record.status="pending" end
    self:_changed(record)
    return feedback(true,"goal_selected",item.name.." is your new goal.",itemId)
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
	if record.seen[id] then return false, 0 end
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
	local credits = 0
	if outcome.completed and not outcome.forfeit and not outcome.aborted then
		credits = outcome.practice and CosmeticCatalog.PRACTICE_REWARD or (CosmeticCatalog.DUEL_REWARD
			+ (outcome.outcome == "win" and CosmeticCatalog.WIN_BONUS or (outcome.outcome == "draw" and CosmeticCatalog.DRAW_BONUS or 0)))
	end
	credits = math.min(credits, PlayerStats.MAX_CREDITS - record.economy.credits)
	record.economy.credits = record.economy.credits + credits
	record.version = record.version + 1
	return true, credits
end

function PlayerStats:recordFlight(record, resultId, input)
	if not record or record.closed or record.closing or type(resultId) ~= "string" or #resultId == 0 or #resultId > 160 then return false end
	if type(input) ~= "table" or not finite(input.distance) or input.distance < 0 or input.distance > 1e7 then return false end
	if not input.practice and input.outcome ~= "win" and input.outcome ~= "loss" and input.outcome ~= "draw" and not input.forfeit then return false end
	local outcome = { distance = input.distance, practice = input.practice == true, completed = input.completed == true,
		forfeit = input.forfeit == true, aborted = input.aborted == true, outcome = input.outcome }
	local applied, credits = self:_apply(record, resultId, outcome)
	if not applied then return false, 0 end
	if not record.loaded then table.insert(record.pending, { id = resultId, outcome = outcome })
	elseif record.safe and record.status ~= "unavailable" then record.status = "pending" end
	self:_changed(record)
	return true, credits
end

-- A terminal battle is a separate ledger operation from the archived distance
-- game. Coins, entitlement, mastery and receipt advance in one fenced record.
function PlayerStats:_applyBattle(record, id, outcome)
    if record.seen[id] then return false,0 end
    record.seen[id]=true;table.insert(record.receipts,id)
    while #record.receipts>PlayerStats.RECEIPT_LIMIT do table.remove(record.receipts,1) end
    local credits=0
    if outcome.eligible then
        local battle=record.battle
        battle.matches=battle.matches+1
        if outcome.outcome=="win" then
            battle.wins=battle.wins+1;battle.currentStreak=battle.currentStreak+1;battle.bestStreak=math.max(battle.bestStreak,battle.currentStreak)
        elseif outcome.outcome=="loss" then battle.losses=battle.losses+1;battle.currentStreak=0
        else battle.draws=battle.draws+1 end
        if battle.matches==1 and not battle.starterChoice then battle.starterAvailable=true end
        local used={}
        for _,skill in ipairs(outcome.skills) do
            if not used[skill] then battle.mastery[skill]=(battle.mastery[skill] or 0)+1;used[skill]=true end
        end
        credits=CosmeticCatalog.BATTLE_COMPLETION_REWARD+(outcome.outcome=="win" and CosmeticCatalog.BATTLE_WIN_BONUS or 0)
        credits=math.min(credits,PlayerStats.MAX_CREDITS-record.economy.credits)
        record.economy.credits=record.economy.credits+credits
    elseif outcome.abandoned then
        -- A real quit breaks a streak without granting completion, coins or
        -- mastery. Diagnostic matches never alter the public streak.
        record.battle.currentStreak=0
    end
    record.version=record.version+1
    return true,credits
end
function PlayerStats:recordBattle(record, resultId, input)
    if not record or record.closed or record.closing or type(resultId)~="string" or #resultId==0 or #resultId>160 or type(input)~="table" then return false end
    if not finite(input.completedRounds) or input.completedRounds<0 or input.completedRounds>5 or input.completedRounds%1~=0
        or not finite(input.fightSeconds) or input.fightSeconds<0 or input.fightSeconds>240 then return false end
    local outcome=input.outcome
    local abandoned=input.abandoned==true or outcome=="abandoned"
    if outcome=="abandoned" then outcome="loss" end
    if outcome==nil and (input.winner==0 or input.winner==1 or input.winner==2) then outcome=input.winner==0 and "draw" or input.winner==1 and "win" or "loss" end
    if outcome~="win" and outcome~="loss" and outcome~="draw" then return false end
    local normal=input.reason=="first_to_two" or input.reason=="round_cap" or input.reason=="wall_cap"
    local departure=input.reason=="exit" or input.reason=="disconnect"
    local eligible=not abandoned and not input.diagnostic and input.mode~="experimental"
        and ((normal and input.completedRounds>=1) or (departure and (input.completedRounds>=1 or input.fightSeconds>=30)))
    local reason=eligible and (departure and "opponent_departed" or "completed") or abandoned and "abandoned"
        or (input.diagnostic or input.mode=="experimental") and "diagnostic" or departure and "early_departure" or "uncompleted"
    local skills={}
    if input.offenceId~=nil then
        if not SkillCatalog.valid(input.offenceId,"offence") then return false end
        skills[#skills+1]=input.offenceId
    elseif eligible then return false end
    if input.wildIds~=nil and type(input.wildIds)~="table" then return false end
    if input.offenceId and not SkillCatalog.build(input.offenceId,input.wildIds) then return false end
    local seen={};local count=0
    for _,id in ipairs(input.wildIds or {}) do
        if not SkillCatalog.valid(id,"wild") or seen[id] then return false end
        count=count+1;if count>2 then return false end;seen[id]=true;skills[#skills+1]=id
    end
    local operation={eligible=eligible,outcome=outcome,skills=skills,
        abandoned=abandoned and not input.diagnostic and input.mode~="experimental"}
    local applied,credits=self:_applyBattle(record,resultId,operation)
    if applied then
        if not record.loaded then table.insert(record.pending,{id=resultId,kind="battle",outcome=operation})
        elseif record.safe and record.status~="unavailable" then record.status="pending" end
        self:_changed(record)
    end
    return applied,{coins=credits,balance=record.economy.credits,eligible=eligible,reason=reason,
        duplicate=not applied,status=record.status,confirmed=record.status=="saved",version=record.version,progression=self:getBattle(record)}
end

function PlayerStats:_loadFailed(record, reason)
	record.safe = false
	record.status = "unavailable"
	record.loadFailures = math.min(record.loadFailures + 1, 5)
	-- Keep pending ledger operations until a verified load can replay them.
	-- Corrupt data must not be retried into a replacement/default profile.
	if reason == "corrupt" or reason == "closed" then
		record.loadRetryAt = nil
	else
		local delay = math.min(60, 5 * 2 ^ (record.loadFailures - 1) + self.jitter() * 0.25)
		record.loadRetryAt = self.clock() + delay
	end
end

function PlayerStats:load(record)
	if not record or record.closed or record.closing or record.busy then return false end
	if self.sessionOnly then record.status = "session_only"; self:_changed(record); return true end
	if record.loaded then return record.safe end
	if record.status ~= "loading" and (not record.loadRetryAt or self.clock() < record.loadRetryAt) then return false end
	if not self.store then self:_loadFailed(record, "store_unavailable"); self:_changed(record); return false end
	record.busy = true
	local ok, loaded = self:_retry(function()
		if record.closed or record.closing then return false, "closed" end
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
		record.economy = copyEconomy(loaded.economy)
        record.battle = copyBattle(loaded.battle)
		record.receipts = copyArray(loaded.receipts)
		record.seen = {}
		for _, id in ipairs(record.receipts) do record.seen[id] = true end
		record.version, record.savedVersion = 0, 0
		for _, pending in ipairs(record.pending) do
            if pending.kind=="battle" then self:_applyBattle(record,pending.id,pending.outcome)
            else self:_apply(record, pending.id, pending.outcome) end
        end
		record.pending = {}
		record.loaded = true
		record.loadFailures = 0
		record.loadRetryAt = nil
		record.safe = true
		record.status = record.version > 0 and "pending" or "saved"
		record.nextSave = self.clock() + (record.version > 0 and 0 or self.saveInterval)
	else
		self:_loadFailed(record, loaded)
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
	local stats, receipts, economy, battle, version = copyStats(record.stats), copyArray(record.receipts), copyEconomy(record.economy), copyBattle(record.battle), record.version
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
			return { schemaVersion = PlayerStats.SCHEMA_VERSION, stats = copyStats(stats), receipts = copyArray(receipts), economy = copyEconomy(economy), battle = copyBattle(battle),
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
		if not record.loaded and record.loadRetryAt and timestamp >= record.loadRetryAt
			and not record.busy and not record.closing and not record.loadRetryQueued then
			record.loadRetryQueued = true
			self.spawn(function()
				self:load(record)
				record.loadRetryQueued = false
			end)
		elseif record.safe and not record.busy and not record.closing and timestamp >= record.nextSave then
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
