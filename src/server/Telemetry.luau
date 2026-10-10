-- Native server analytics; explicitly opt in with Telemetry.new({enabled = true}).
-- Studio is always disabled by the default environment check. isStudio/analytics/
-- clock can be injected for isolated tests. No HTTP service or external endpoint.
-- https://create.roblox.com/docs/production/analytics/custom-events
-- https://create.roblox.com/docs/production/analytics/event-types
-- https://create.roblox.com/docs/production/analytics/custom-fields
local Telemetry = {}
Telemetry.__index = Telemetry

local WINDOW_SECONDS = 60
local PLAYER_LIMIT = 16
local MAX_SESSIONS = 256
local OUTCOMES = {win = true, loss = true, tie = true, forfeit = true, completed = true}
local PHASES = {Lobby = true, Queued = true, Voting = true, Configure = true, Aim = true,
	Countdown = true, Flight = true, Results = true}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function service(name)
	local ok, result = pcall(function() return game:GetService(name) end)
	return ok and result or nil
end

local function studioCheck(override)
	if type(override) == "boolean" then return override end
	local ok, result = pcall(function()
		if type(override) == "function" then return override() end
		return game:GetService("RunService"):IsStudio()
	end)
	-- Unavailable or ambiguous environment detection must fail closed.
	return not ok or result ~= false
end

local function prune(timestamps, now)
	while timestamps[1] and now - timestamps[1] >= WINDOW_SECONDS do
		table.remove(timestamps, 1)
	end
end

function Telemetry.new(options)
	options = type(options) == "table" and options or {}
	local enabled = options.enabled == true and not studioCheck(options.isStudio)
	local analytics = enabled and (options.analytics or service("AnalyticsService")) or nil
	return setmetatable({
		_enabled = enabled and analytics ~= nil,
		_analytics = analytics,
		_clock = type(options.clock) == "function" and options.clock or os.clock,
		_lastNow = 0,
		_sessions = {},
		_sessionCount = 0,
		_events = {},
	}, Telemetry)
end

function Telemetry:_now()
	local ok, value = pcall(self._clock)
	if not ok or not finite(value) then return nil end
	self._lastNow = math.max(self._lastNow, value)
	return self._lastNow
end

function Telemetry:_emit(player, state, eventName, value, fields)
	local now = self:_now()
	if not self._enabled or not now then return false end
	prune(state.events, now)
	prune(self._events, now)
	-- Roblox's limit is 120 + 20*CCU requests/minute. Reserve headroom for other
	-- systems; these rolling windows also bound retained timestamps and retries.
	if #state.events >= PLAYER_LIMIT or #self._events >= 100 + 12 * self._sessionCount then return false end
	table.insert(state.events, now)
	table.insert(self._events, now)
	-- LogCustomEvent does not yield. Do not retry or expose error text/player data.
	local ok = pcall(function()
		self._analytics:LogCustomEvent(player, eventName, value, fields)
	end)
	return ok
end

function Telemetry:sessionStart(player)
	if not self._enabled or player == nil or self._sessions[player] or self._sessionCount >= MAX_SESSIONS then return false end
	local now = self:_now()
	if not now then return false end
	local state = {startedAt = now, events = {}}
	self._sessions[player] = state
	self._sessionCount = self._sessionCount + 1
	return self:_emit(player, state, "SessionStarted", 1)
end

function Telemetry:sessionEnd(player)
	local state = self._sessions[player]
	if not state then return false end
	local now = self:_now()
	local sent = now and self:_emit(player, state, "SessionDurationSeconds", math.min(now - state.startedAt, 86400)) or false
	-- Always clean up, even when the clock or AnalyticsService fails.
	self._sessions[player] = nil
	self._sessionCount = self._sessionCount - 1
	return sent
end

function Telemetry:queueStart(player)
	local state = self._sessions[player]
	if not state or state.queued or state.matchStartedAt then return false end
	state.queued = true
	state.abandonedPhase = nil
	return self:_emit(player, state, "QueueStarted", 1)
end

function Telemetry:matchStart(player, practice)
	local state = self._sessions[player]
	if not state or state.matchStartedAt then return false end
	local now = self:_now()
	if not now then return false end
	state.matchStartedAt = now
	state.mode = practice == true and "practice" or "duel"
	state.queued = false
	state.completed = false
	state.rematched = false
	state.abandonedPhase = nil
	return self:_emit(player, state, "MatchStarted", 1, {CustomField01 = state.mode})
end

function Telemetry:matchComplete(player, outcome, practice)
	local state = self._sessions[player]
	if not state or not state.matchStartedAt then return false end
	local startedAt = state.matchStartedAt
	state.matchStartedAt = nil
	state.completed = true
	-- Prefer the mode captured at launch; no caller-provided identifiers are sent.
	local fields = {CustomField01 = state.mode or (practice == true and "practice" or "duel"),
		CustomField02 = type(outcome) == "string" and OUTCOMES[outcome] and outcome or "unknown"}
	local sent = self:_emit(player, state, "MatchCompleted", 1, fields)
	local now = self:_now()
	if now then self:_emit(player, state, "MatchDurationSeconds", math.min(now - startedAt, 3600), fields) end
	return sent
end

function Telemetry:rematch(player)
	local state = self._sessions[player]
	if not state or not state.completed or state.rematched then return false end
	state.rematched = true
	return self:_emit(player, state, "RematchRequested", 1, {CustomField01 = state.mode})
end

function Telemetry:phaseAbandoned(player, phase)
	local state = self._sessions[player]
	if not state then return false end
	local safePhase = type(phase) == "string" and PHASES[phase] and phase or "Unknown"
	if state.abandonedPhase == safePhase then return false end
	state.abandonedPhase = safePhase
	state.queued = false
	state.matchStartedAt = nil
	state.completed = false
	return self:_emit(player, state, "PhaseAbandoned", 1, {CustomField03 = safePhase})
end

return Telemetry
