-- Server-owned single-round combat toy. No rewards, queues, or live opponents.
local BattleLab = {}
BattleLab.__index = BattleLab

local function finite(v)
    return type(v)=="number" and v==v and v>-math.huge and v<math.huge
end
-- A build is refused whole if any part is wrong: unknown skill, a skill of
-- the wrong kind, a repeated wild card or too many of them.
local function checked(value,skills)
    if type(value)~="table" or not finite(value.angle) then return nil end
    local build=skills.build(value.offenceId,value.wildIds)
    if not build then return nil end
    build.angle=math.floor(math.max(10,math.min(55,value.angle))+0.5)
    return build
end
function BattleLab.new(deps)
    return setmetatable({deps=deps,sessions={},throttle={},sequence=0,broadcastTime=0},BattleLab)
end
function BattleLab:snapshot(player)
    local s=self.sessions[player.UserId]
    if not s then return {active=false} end
    return {active=true,phase=s.phase,roundId=s.roundId,settings=s.settings,
        simulation=s.simulation,endsAt=s.endsAt,serverTime=self.deps.now(),simulatedOpponent=true}
end
function BattleLab:emit(player)
    self.deps.emit(player,self:snapshot(player))
end
function BattleLab:prepare(s)
    self.sequence=self.sequence+1
    s.roundId=self.sequence
    s.phase="Configure"
    s.endsAt=0
    s.accumulator=0
    -- Replaying identical settings keeps the same deterministic experiment.
    s.simulation=self.deps.simulation.newRound(731,s.settings[1],s.settings[2])
end
function BattleLab:command(player,payload)
    if type(payload)~="table" or type(payload.kind)~="string" then return end
    local kind=payload.kind
    if kind~="request" and kind~="enter" and kind~="exit" and kind~="configure"
        and kind~="launch" and kind~="restart" then return end
    local time=self.deps.now()
    -- A small burst budget accepts ordered setup + launch packets that arrive
    -- together after network jitter, while bounding work from remote floods.
    local budget=self.throttle[player.UserId] or {time=time,tokens=4}
    budget.tokens=math.min(4,budget.tokens+math.max(0,time-budget.time)*15)
    budget.time=time
    self.throttle[player.UserId]=budget
    if budget.tokens<1 then return end
    budget.tokens=budget.tokens-1
    local s=self.sessions[player.UserId]
    if kind=="enter" and not s and self.deps.canEnter(player) then
        s={player=player,settings={{offenceId="Meteor",wildIds={},angle=35},{offenceId="Firework",wildIds={},angle=30}}}
        self:prepare(s)
        self.sessions[player.UserId]=s
        self.deps.entered(player)
    elseif kind=="exit" and s then
        self.sessions[player.UserId]=nil
        self.deps.exited(player)
    elseif kind=="configure" and s and s.phase=="Configure" then
        local a=type(payload.settings)=="table" and checked(payload.settings[1],self.deps.skills)
        local b=type(payload.settings)=="table" and checked(payload.settings[2],self.deps.skills)
        if not a or not b then return end
        s.settings={a,b}
        self:prepare(s)
    elseif kind=="launch" and s and s.phase=="Configure" then
        -- Commit exactly the setup visible on the launching client's screen.
        -- Earlier configure packets can be rate-limited after network stalls.
        if payload.settings~=nil then
            local a=type(payload.settings)=="table" and checked(payload.settings[1],self.deps.skills)
            local b=type(payload.settings)=="table" and checked(payload.settings[2],self.deps.skills)
            if not a or not b then return end
            s.settings={a,b}; self:prepare(s)
        end
        s.phase="Countdown"; s.endsAt=time+2.4
    elseif kind=="restart" and s and s.phase=="Results" then
        self:prepare(s)
        -- One tap repeats the experiment. Edit is an explicit separate action.
        if payload.edit~=true then s.phase="Countdown"; s.endsAt=time+1.8 end
    end
    self:emit(player)
end
function BattleLab:step(dt)
    if not finite(dt) or dt<=0 then return end
    self.broadcastTime=self.broadcastTime+dt
    local emit=self.broadcastTime>=1/20
    if emit then self.broadcastTime=0 end
    for _,s in pairs(self.sessions) do
        if s.phase=="Countdown" and self.deps.now()>=s.endsAt then
            s.phase="Fight"; s.accumulator=0
        end
        if s.phase=="Fight" then
            -- Bound catch-up work after a server stall; never trust client time.
            s.accumulator=math.min(s.accumulator+dt,0.25)
            while s.accumulator>=self.deps.simulation.FIXED_DT do
                s.accumulator=s.accumulator-self.deps.simulation.FIXED_DT
                self.deps.simulation.step(s.simulation,self.deps.simulation.FIXED_DT)
                if s.simulation.finished then s.phase="Results"; break end
            end
        end
        if emit then self:emit(s.player) end
    end
end
function BattleLab:remove(player)
    self.sessions[player.UserId]=nil
    self.throttle[player.UserId]=nil
end
return BattleLab
