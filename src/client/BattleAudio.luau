-- Local presentation only. Authoritative events decide which impacts are heard.
-- No looping tracks, per-event instances, delayed callbacks, or uploaded assets.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local BattleAudio = {}
BattleAudio.__index = BattleAudio
BattleAudio.VOICES_PER_SOURCE = 4
BattleAudio.VOICE_POOL_LIMIT = 16
BattleAudio.MAX_EVENTS_PER_UPDATE = 4
BattleAudio.MAX_EVENT_AGE = 0.55
BattleAudio.JOIN_GRACE = 0.3
BattleAudio.MAX_CRASH_AGE = 3

local SOURCES = {
    jump = "rbxasset://sounds/action_jump.mp3",
    boom = "rbxasset://sounds/impact_explosion_03.mp3",
    chime = "rbxasset://sounds/volume_slider.ogg",
    land = "rbxasset://sounds/action_jump_land.mp3",
}
local KINDS = {
    launch=true, windup=true, dive=true, rocket=true, hit=true, bump=true,
    bumper_block=true, wake_hit=true, afterburner=true, finish=true, knockout=true,
}
local function finite(value)
    return type(value)=="number" and value==value and value>-math.huge and value<math.huge
end
local function audibleKind(event)
    if event.kind=="modifier" then
        return event.modifierId=="Afterburner" and "afterburner" or nil
    elseif event.kind=="blocked" then
        return event.modifierId=="SpringBumper" and "bumper_block" or nil
    end
    return KINDS[event.kind] and event.kind or nil
end

function BattleAudio.new()
    local self=setmetatable({voices={},nextVoice={},tweens={},lastAt={},lastSerial=0,
        key=nil,started=false,muted=false,destroyed=false,played=0,crashes={},charging={}},BattleAudio)
    self.folder=Instance.new("Folder")
    self.folder.Name="SkyboundBattleAudio"; self.folder.Parent=SoundService
    self.group=Instance.new("SoundGroup")
    self.group.Name="BattleMix"; self.group.Volume=0.7; self.group.Parent=self.folder
    local preload={}
    for name,id in pairs(SOURCES) do
        local pool={}; self.voices[name]=pool; self.nextVoice[name]=0
        for index=1,BattleAudio.VOICES_PER_SOURCE do
            local sound=Instance.new("Sound")
            sound.Name=name..index; sound.SoundId=id; sound.Volume=0
            sound.Looped=false; sound.SoundGroup=self.group; sound.Parent=self.folder
            pool[index]=sound; preload[#preload+1]=sound
        end
    end
    task.spawn(function()
        local ok=pcall(function() ContentProvider:PreloadAsync(preload) end)
        if self.destroyed or not self.folder.Parent then return end
        self.folder:SetAttribute("PreloadCompleted",ok)
    end)
    return self
end

function BattleAudio:_silence()
    for _,tween in pairs(self.tweens) do tween:Cancel() end
    self.tweens={}; self.charging={}
    for _,pool in pairs(self.voices) do
        for _,sound in ipairs(pool) do sound:Stop() end
    end
end

function BattleAudio:setMuted(muted)
    if self.destroyed then return end
    self.muted=muted==true
    self.group.Volume=self.muted and 0 or 0.7
    self.folder:SetAttribute("Muted",self.muted)
    if self.muted then self:_silence() end
end

function BattleAudio:_stopCharges(actor)
    for sound,owner in pairs(self.charging or {}) do
        if not actor or owner==actor then
            if self.tweens[sound] then self.tweens[sound]:Cancel(); self.tweens[sound]=nil end
            sound:Stop(); self.charging[sound]=nil
        end
    end
end

function BattleAudio:_voice(name,volume,pitch,duration,finishPitch,swell,actor)
    if self.destroyed or self.muted or not self.folder.Parent then return end
    local pool=self.voices[name]
    if not pool then return end
    local index=self.nextVoice[name]%#pool+1
    self.nextVoice[name]=index
    local sound=pool[index]
    if self.tweens[sound] then self.tweens[sound]:Cancel() end
    -- Reusing a pooled voice transfers ownership, so a later dive cannot stop
    -- another cue that has since borrowed that same Sound.
    self.charging[sound]=swell and actor or nil
    sound:Stop(); sound.TimePosition=0
    if swell then
        -- With Quad/In pitch interpolation, mean speed is (2*start+end)/3.
        -- Fit the finite sample to the remaining windup instead of letting a
        -- longer charge go silent early. Before preload, scale the old cue.
        local endPitch=finishPitch or pitch
        local meanPitch=(2*pitch+endPitch)/3
        local fit=finite(sound.TimeLength) and sound.TimeLength>0
            and sound.TimeLength/(duration*meanPitch) or 0.65/duration
        fit=math.max(0.2,math.min(2.5,fit))
        pitch=pitch*fit; finishPitch=endPitch*fit
    end
    -- Charges swell on a finite, non-looping sample. Its natural end needs no
    -- delayed callback; ordinary impacts instead decay immediately.
    sound.Volume=swell and volume*0.18 or volume; sound.PlaybackSpeed=pitch
    sound:Play()
    local tween=TweenService:Create(sound,
        TweenInfo.new(duration,Enum.EasingStyle.Quad,swell and Enum.EasingDirection.In or Enum.EasingDirection.Out),
        {Volume=swell and volume or 0,PlaybackSpeed=finishPitch or pitch})
    self.tweens[sound]=tween; tween:Play()
end

function BattleAudio:_playEvent(event,elapsed,simulation)
    if self.muted or self.destroyed then return end
    local kind=audibleKind(event)
    if not kind then return end
    local actor=event.actor==2 and 2 or 1
    local time=finite(event.at) and event.at or elapsed
    local key=kind..":"..actor
    local cooldown=(kind=="bump" and 0.3) or (kind=="windup" and 0.25) or 0.08
    if time-(self.lastAt[key] or -math.huge)<cooldown then return end
    self.lastAt[key]=time
    -- Both aircraft remain audible; a small timbral difference separates them.
    local gain=actor==2 and 0.88 or 1
    local pitchShift=actor==2 and 1.06 or 1
    local function voice(name,volume,pitch,duration,finishPitch,swell)
        self:_voice(name,volume*gain,pitch*pitchShift,duration,
            finishPitch and finishPitch*pitchShift,swell,actor)
    end
    if kind=="launch" then
        voice("jump",0.14,0.75,0.28,1.5)
    elseif kind=="windup" then
        local fighter=simulation.fighters and simulation.fighters[actor]
        if fighter and fighter.powerId=="Meteor" then
            -- Low rising charge, then a separate downward sweep on commitment.
            local duration=finite(fighter.windupDuration) and fighter.windupDuration>0
                and math.max(0.2,math.min(3,fighter.windupDuration)) or 0.65
            local age=math.max(0,elapsed-time)
            local remaining=math.max(0.08,duration-age)
            voice("jump",0.16,0.55,remaining,1.15,true)
            voice("chime",0.055,0.7,math.min(0.48,remaining),1.0)
        else
            -- A tiny bright arming cue leaves space for rocket ignition.
            voice("chime",0.11,1.85,0.24,2.1)
            voice("land",0.045,2.25,0.09)
        end
    elseif kind=="dive" then
        self:_stopCharges(actor)
        -- Commitment sounds fast and weighty, but never claims an armor hit.
        voice("jump",0.25,1.65,0.46,0.55)
        voice("land",0.10,0.75,0.16,0.5)
    elseif kind=="rocket" then
        voice("jump",0.22,1.15,0.3,1.9)
        voice("boom",0.12,2.1,0.14,1.6)
    elseif kind=="hit" then
        if event.source=="meteor" then
            voice("boom",0.30,0.8,0.46,0.55)
            voice("land",0.30,0.55,0.18)
        else
            voice("boom",0.29,1.5,0.32,0.95)
            voice("land",0.21,1.05,0.13)
        end
    elseif kind=="bumper_block" then
        voice("jump",0.27,0.85,0.4,1.9)
        voice("chime",0.12,1.6,0.28)
    elseif kind=="wake_hit" then
        voice("land",0.23,1.25,0.2)
        voice("boom",0.17,1.8,0.3,1.1)
    elseif kind=="afterburner" then
        voice("jump",0.17,0.65,0.32,1.8)
    elseif kind=="bump" then
        -- A normal collision pushes without armor loss: never use the hit mix.
        voice("land",0.065,1.55,0.11)
    elseif kind=="knockout" or (kind=="finish" and simulation.reason=="knockout") then
        self:_stopCharges()
        -- Armor breaking ends the fight. The heavier ground thud belongs to
        -- playCrash, when the defeated plane actually reaches the floor.
        voice("boom",0.13,1.25,0.24,0.85)
        voice("chime",0.21,0.95,0.48,1.4)
    elseif kind=="finish" then
        self:_stopCharges()
        voice("land",0.12,0.9,0.2)
        voice("chime",0.23,1.1,0.5)
    end
    self.played=self.played+1
    self.folder:SetAttribute("PlayedEvents",self.played)
    self.folder:SetAttribute("LastEvent",kind)
end

function BattleAudio:playCrash(roundId,actor)
    if self.destroyed or not self.key or tostring(roundId)~=self.key
        or (actor~=1 and actor~=2) or self.phase~="Results" or not self.crashAllowed
        or not self.resultsAt or os.clock()-self.resultsAt>BattleAudio.MAX_CRASH_AGE
        or not self.resultArmor or not finite(self.resultArmor[actor]) or self.resultArmor[actor]>0
        or self.crashes[actor] then return false end
    -- Consume muted landings too: unmuting must never replay an old crash.
    self.crashes[actor]=true
    if self.muted then return false end
    local gain=actor==2 and 0.88 or 1
    self:_voice("land",0.38*gain,0.5,0.24,0.4)
    self:_voice("boom",0.26*gain,0.62,0.48,0.45)
    self.played=self.played+1
    self.folder:SetAttribute("PlayedEvents",self.played)
    self.folder:SetAttribute("LastEvent","crash")
    return true
end

function BattleAudio:stop()
    if self.destroyed then return end
    self:_silence()
    self.key=nil; self.started=false; self.lastSerial=0; self.lastAt={}
    self.phase=nil; self.sawFight=false; self.resultsAt=nil; self.crashAllowed=false
    self.resultArmor=nil; self.crashes={}
end

function BattleAudio:update(snapshot)
    if self.destroyed then return end
    if type(snapshot)~="table" or snapshot.active~=true then
        if self.key then self:stop() end
        return
    end
    local key=tostring(snapshot.roundId)
    if self.key~=key then self:stop(); self.key=key end
    local phase=snapshot.phase
    local previousPhase=self.phase
    self.phase=phase
    self.crashAllowed=false
    -- newRound already contains launch events during setup. Leave their cursor
    -- untouched until the actual fight starts; Configure/Countdown stay quiet.
    if phase~="Fight" and phase~="Results" then return end
    local simulation=snapshot.simulation
    if type(simulation)~="table" then return end
    if phase=="Fight" then
        self.sawFight=true
    elseif phase=="Results" then
        if previousPhase~="Results" then self.resultsAt=os.clock(); self:_stopCharges() end
        self.crashAllowed=self.sawFight==true and simulation.finished==true and simulation.reason=="knockout"
        self.resultArmor={}
        for index,fighter in ipairs(simulation.fighters or {}) do
            if index>2 then break end
            self.resultArmor[fighter.id or index]=fighter.armor
        end
    end
    local elapsed=finite(simulation.elapsed) and simulation.elapsed or 0
    local events=type(simulation.events)=="table" and simulation.events or {}
    local skipHistory=not self.started and (phase=="Results" or elapsed>BattleAudio.JOIN_GRACE)
    self.started=true
    local newest=self.lastSerial
    local pending={}
    for index=1,math.min(#events,32) do
        local event=events[index]
        local serial=type(event)=="table" and event.serial
        if finite(serial) and serial>self.lastSerial then
            newest=math.max(newest,serial)
            local age=finite(event.at) and elapsed-event.at or 0
            if not skipHistory and age>=-0.001 and age<=BattleAudio.MAX_EVENT_AGE
                and audibleKind(event) then pending[#pending+1]=event end
        end
    end
    -- Cursors advance even while muted, for unknown events, and stale batches.
    self.lastSerial=newest
    table.sort(pending,function(a,b) return a.serial<b.serial end)
    -- Keep the freshest feedback after a delivery stall; never burst the full
    -- server history. Its serial order preserves a hit followed by its finish.
    for index=math.max(1,#pending-BattleAudio.MAX_EVENTS_PER_UPDATE+1),#pending do
        self:_playEvent(pending[index],elapsed,simulation)
    end
end

function BattleAudio:destroy()
    if self.destroyed then return end
    self:stop(); self.destroyed=true
    self.folder:Destroy()
    self.voices={}; self.nextVoice={}
end

return BattleAudio
