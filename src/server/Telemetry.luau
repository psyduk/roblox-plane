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
local OUTCOMES = {win = true, loss = true, tie = true, draw = true, abandoned = true, forfeit = true, completed = true}
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
		_battle = {},
		_battleLog = {},
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

-- Version 1 rivalry funnel. Identifiers stay in a bounded server diagnostic ring;
-- native analytics receives only fixed, low-cardinality segments and durations.
local BATTLE_EVENTS = {join=true,usable_lobby=true,queue=true,match_accepted=true,
    first_launch=true,terminal_result=true,reward_shown=true,replay_requested=true,
    next_actual_launch=true,abandoned=true,goal_selected=true,goal_earned=true,goal_equipped=true}
local DEVICES = {phone=true,tablet=true,desktop=true,console=true,unknown=true}
local MODES = {public=true,challenge=true,practice=true,experimental=true}
function Telemetry:battleEvent(player, name, data)
    if not player or not BATTLE_EVENTS[name] then return false end
    data = type(data)=="table" and data or {}
    local now = self:_now()
    if not now then return false end
    local state = self._battle[player]
    if not state then
        state={startedAt=now,seen={},order={},device="unknown",cohort="unknown"}
        self._battle[player]=state
    end
    if DEVICES[data.device] then state.device=data.device end
    if data.cohort=="new" or data.cohort=="returning" then state.cohort=data.cohort end
    local matchId=tostring(data.matchId or "session")
    local key=name..":"..matchId..":"..tostring(data.itemId or "")
    if name=="queue" then key=key..":"..tostring(data.queueId or data.sequence or 0) end
    if state.seen[key] then return false end
    state.seen[key]=true; table.insert(state.order,key)
    if #state.order>128 then state.seen[table.remove(state.order,1)]=nil end
    if name=="usable_lobby" then state.usableAt=state.usableAt or now end
    if name=="terminal_result" then state.resultAt=now; state.resultMatch=matchId; state.lastOutcome=data.outcome;state.voluntary=false end
    if name=="replay_requested" then state.voluntary=true end
    local entry={version=1,event=name,rosterVersion=string.sub(tostring(data.rosterVersion or "sky-battle-public-v1"),1,64),matchId=matchId,time=now,device=state.device,cohort=state.cohort,
        developer=not self._enabled,mode=MODES[data.mode] and data.mode or "public",
        opponentType=data.opponentType=="human" and "human" or "bot",outcome=data.outcome,
        voluntary=data.voluntary==true,phase=data.phase,elapsed=data.elapsed,queueSeconds=data.queueSeconds,draftSeconds=data.draftSeconds,
        fightSeconds=data.fightSeconds,transitionSeconds=data.transitionSeconds}
    if name=="first_launch" then
        if not state.launched then entry.firstLaunchSeconds=now-(state.usableAt or state.startedAt)
        else entry.event="match_launch" end
        state.launched=true
        if state.resultAt and state.resultMatch~=matchId then
            entry.resultToLaunchSeconds=now-state.resultAt
            self:battleEvent(player,"next_actual_launch",{matchId=matchId,mode=entry.mode,rosterVersion=entry.rosterVersion,
                opponentType=entry.opponentType,outcome=state.lastOutcome,elapsed=entry.resultToLaunchSeconds,voluntary=state.voluntary})
            state.resultAt=nil
        end
    end
    table.insert(self._battleLog,entry)
    if #self._battleLog>256 then table.remove(self._battleLog,1) end
    local native=self._sessions[player]
    if native then
        entry.submitted=self:_emit(player,native,"SkyBattle_v1_"..entry.event,
            math.max(0,math.min(86400,entry.firstLaunchSeconds or data.elapsed or 1)),
            {CustomField01=state.cohort..":"..state.device,
             CustomField02=entry.mode..":"..entry.opponentType..":"..entry.rosterVersion,
             CustomField03=(OUTCOMES[data.outcome] and data.outcome or "none")..(name=="next_actual_launch" and (entry.voluntary and ":voluntary" or ":continuation") or "")})
    end
    return true
end
function Telemetry:battleLog()
    local result={}
    for _,entry in ipairs(self._battleLog) do
        local copy={}; for key,value in pairs(entry) do copy[key]=value end
        table.insert(result,copy)
    end
    return result
end
function Telemetry:battleContext(player,data)
    local state=self._battle[player]
    if state and (data.cohort=="new" or data.cohort=="returning") then state.cohort=data.cohort end
end
function Telemetry:battleLeave(player)
    self._battle[player]=nil
end
return Telemetry
