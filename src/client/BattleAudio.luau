-- Local presentation only. Authoritative events decide which impacts are heard.
-- No per-event instances or delayed callbacks. The original pitched stock
-- voices are layered with licensed Creator Store samples and three beds.
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
-- Licensed one-shots from Pro Sound Effects' official Creator Store channel
-- (@ProSoundEffects): free for use in experiences, not open user uploads.
local SAMPLES = {
    thump = "rbxassetid://9116329674",    -- Low Impacts 1
    punch = "rbxassetid://9119061110",    -- Sharp Punch 2
    crunch = "rbxassetid://9120188871",   -- Toolbox Impact Wood Metal Hits Fall Crash 12
    shatter = "rbxassetid://9114591567",  -- Glass Breaks 4
    blast = "rbxassetid://9117982785",    -- Pyro Explosion 4
    bigBlast = "rbxassetid://9117982449", -- Pyro Explosion 1
    sub = "rbxassetid://9126009582",      -- Subwoofer Impact Deep Rumbling Pops Booming
    whoosh = "rbxassetid://9126229255",   -- Whoosh By Fast Airy Swooshing Whipping Thuds
    rise = "rbxassetid://9125805781",     -- Rising Whoosh Hissing Build Up Ascending
    ignite = "rbxassetid://9114446852",   -- Fire Whoosh 15
    comic = "rbxassetid://9113496949",    -- Body Hit Comic 2
    beep = "rbxassetid://9117060347",     -- Nasa Transmission Beep 1
    whistle = "rbxassetid://9125967307",  -- Soccer Whistle Acme Thunderer
    cheer = "rbxassetid://9120974378",    -- Wrestling Crowd 3
    gasp = "rbxassetid://9114013354",     -- Crowd Reaction 4
    thunder = "rbxassetid://9120018172",  -- Thunder Distant Boom Thud Rapid Hits 20
    click = "rbxassetid://9119717523",    -- Switch Click On Or Off Toggle Button 2
    -- APM Music "Champion Fanfare" (Bruton, Big Heavy Horn Riffs), @APMOfficial.
    fanfare = "rbxassetid://9043234711",
}
-- Beds. Music is APM Music's "Feel That Move" (30 second light version: 80s
-- clavinet funk) from the official @APMOfficial channel, chosen after the
-- cinematic "Rival" cue proved too dramatic; the rest are Pro Sound Effects.
local LOOPS = {
    music = "rbxassetid://9044946334",
    crowd = "rbxassetid://9119562311",    -- Stadium Crowd 2
    storm = "rbxassetid://9125742262",    -- Plasma Trails Constant Airy Whooshing Windy
}
BattleAudio.SHOTS_PER_SAMPLE = 2
BattleAudio.ROUND_TIME = 26
-- A touch that throws a top at least this fast is a big hit, not a bump.
BattleAudio.BIG_HIT = 38
local function finite(value)
    return type(value)=="number" and value==value and value>-math.huge and value<math.huge
end
-- What a simulation event sounds like, or nil for one that makes no sound.
local function audibleKind(event)
    if event.kind=="clash" then
        if event.source=="slam" then return "slam_hit" end
        return finite(event.power) and event.power>=BattleAudio.BIG_HIT and "big_hit" or "bump"
    elseif event.kind=="windup" or event.kind=="attack" then
        return (event.source=="dash" or event.source=="jump" or event.source=="swoop" or event.source=="shove") and event.kind..":"..event.source or nil
    elseif event.kind=="blocked" then
        return event.skillId=="Bumper" and "bumper_block" or nil
    elseif event.kind=="revive" then
        return "jetpack"
    elseif event.kind=="launch" or event.kind=="slam" or event.kind=="land" or event.kind=="close"
        or event.kind=="ringout" or event.kind=="finish" then
        return event.kind
    end
    return nil
end

function BattleAudio.new()
    local self=setmetatable({voices={},nextVoice={},tweens={},lastAt={},lastSerial=0,
        key=nil,started=false,muted=false,destroyed=false,played=0,crashes={},charging={}},BattleAudio)
    self.folder=Instance.new("Folder")
    self.folder.Name="SkyboundBattleAudio"; self.folder.Parent=SoundService
    self.group=Instance.new("SoundGroup")
    self.group.Name="BattleMix"; self.group.Volume=0.7; self.group.Parent=self.folder
    local preload={}
    self.shots,self.nextShot,self.loops={}, {}, {}
    for name,id in pairs(SAMPLES) do
        local pool={}; self.shots[name]=pool
        for index=1,BattleAudio.SHOTS_PER_SAMPLE do
            local sound=Instance.new("Sound")
            sound.Name="shot_"..name..index; sound.SoundId=id; sound.Volume=0
            sound.Looped=false; sound.SoundGroup=self.group; sound.Parent=self.folder
            pool[index]=sound; preload[#preload+1]=sound
        end
    end
    for name,id in pairs(LOOPS) do
        local sound=Instance.new("Sound")
        sound.Name="loop_"..name; sound.SoundId=id; sound.Volume=0
        sound.Looped=true; sound.SoundGroup=self.group; sound.Parent=self.folder
        self.loops[name]=sound; preload[#preload+1]=sound
    end
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
    for _,pool in pairs(self.shots or {}) do
        for _,sound in ipairs(pool) do sound:Stop() end
    end
end

-- A licensed sample at its natural length. Mocked mixes have no pools.
function BattleAudio:_shot(name,volume,speed)
    local pool=self.shots and self.shots[name]
    if not pool or self.destroyed or self.muted then return end
    local index=(self.nextShot[name] or 0)%#pool+1
    self.nextShot[name]=index
    local sound=pool[index]
    sound:Stop(); sound.TimePosition=0
    sound.Volume=volume; sound.PlaybackSpeed=speed or 1
    sound:Play()
end

function BattleAudio:_loop(name,volume,speed)
    local sound=self.loops[name]
    if self.muted then volume=0 end
    if volume>0 and not sound.IsPlaying then sound:Play() end
    sound.Volume=sound.Volume+(volume-sound.Volume)*0.07
    sound.PlaybackSpeed=speed
    if volume==0 and sound.Volume<0.004 and sound.IsPlaying then sound:Stop() end
end

-- Music, crowd and storm beds follow the phase every frame, including the
-- frames after a battle closes so each bed fades instead of cutting.
function BattleAudio:_ambience(snapshot)
    if not self.loops or self.destroyed then return end
    local active=type(snapshot)=="table" and snapshot.active==true
    local phase=active and snapshot.phase or nil
    local simulation=active and type(snapshot.simulation)=="table" and snapshot.simulation or nil
    local pressure=simulation and finite(simulation.pressure) and simulation.pressure or 0
    local elapsed=simulation and finite(simulation.elapsed) and simulation.elapsed or 0
    local fighting=phase=="Fight"
    local closing=fighting and pressure>0
    -- The tops spin faster as a round goes on, and the band keeps pace.
    local heat=fighting and simulation and finite(simulation.heat) and math.clamp(simulation.heat,1,2.2) or 1
    -- The battle loop steps right back at the result so the sting can land.
    self:_loop("music",active and ((fighting or phase=="Countdown") and 0.24 or ((phase=="Results" or phase=="RoundOver" or phase=="MatchOver") and 0.05 or 0.13)) or 0,1+(heat-1)*0.22+(closing and 0.03 or 0))
    self:_loop("crowd",active and ((fighting or phase=="Countdown") and 0.22 or 0.1) or 0,1)
    self:_loop("storm",closing and 0.14+pressure*0.3 or 0,1)
    if phase=="Countdown" and finite(snapshot.endsAt) then
        -- Three evenly spaced beats, however long the server's countdown is.
        local remaining=snapshot.endsAt-workspace:GetServerTimeNow()
        if self.countRound~=snapshot.roundId then
            self.countRound,self.countSpan,self.countBeat=snapshot.roundId,math.max(0.3,remaining),0
            if snapshot.matchPoint then self:_shot("whistle",0.3,1.25) end
        end
        local beat=math.clamp(math.floor((1-remaining/self.countSpan)*3)+1,1,3)
        if beat>self.countBeat then self.countBeat=beat; self:_shot("beep",0.5,0.85+beat*0.1) end
    elseif fighting then
        if self.ambientPhase=="Countdown" then self:_shot("whistle",0.55,1); self:_shot("cheer",0.4,1) end
        if closing and not self.wasClosing then self:_shot("thunder",0.6,1) end
        local left=math.ceil((simulation and finite(simulation.maxTime) and simulation.maxTime or BattleAudio.ROUND_TIME)-elapsed)
        if left<=5 and left>0 and left~=self.lastTick then self.lastTick=left; self:_shot("beep",0.3,1.6) end
    end
    self.wasClosing=closing
    self.ambientPhase=phase
end

-- The result banner: horns and a roar for a win, a groan for a loss.
function BattleAudio:result(outcome)
    self:_stopShot("fanfare")
    if outcome=="win" then self:_shot("fanfare",0.5,1); self:_shot("cheer",0.6,1)
    elseif outcome=="lose" then self:_shot("gasp",0.55,0.85); self:_shot("thump",0.5,0.7)
    else self:_shot("whistle",0.4,0.8); self:_shot("gasp",0.35,1) end
end
function BattleAudio:_stopShot(name)
    for _,sound in ipairs(self.shots and self.shots[name] or {}) do sound:Stop() end
end

-- One quiet vocabulary shared by battle and hangar controls. Boolean callers
-- retain the old select/confirm contract. Duplicate helper/callback pulses are
-- suppressed without delaying the actual command.
function BattleAudio:ui(action)
    if self.muted or self.destroyed then return end
    if action==true then action="confirm" elseif action==false or action==nil then action="select" end
    local now=os.clock()
    if self.lastUi==action and now-(self.lastUiAt or -100)<0.06 then return end
    self.lastUi,self.lastUiAt=action,now
    self:_stopShot("fanfare")
    if action=="confirm" then self:_shot("whoosh",0.22,1.1); self:_shot("click",0.2,0.9)
    elseif action=="back" then self:_shot("click",0.16,0.72)
    elseif action=="error" then self:_shot("beep",0.16,0.65)
    elseif action=="purchase" then self:_voice("chime",0.16,1.1,0.3,1.7); self:_shot("click",0.18,1.25)
    elseif action=="select" then self:_shot("click",0.2,1.15); self:_voice("chime",0.045,1.7,0.12)
    else self:_shot("click",0.13,1.1) end
    if self.folder then self.folder:SetAttribute("LastUI",action) end
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
    local cooldown=(kind=="bump" and 0.16) or 0.08
    if time-(self.lastAt[key] or -math.huge)<cooldown then return end
    self.lastAt[key]=time
    -- Both tops remain audible; a small timbral difference separates them.
    local gain=actor==2 and 0.88 or 1
    local pitchShift=actor==2 and 1.06 or 1
    local function voice(name,volume,pitch,duration,finishPitch,swell)
        self:_voice(name,volume*gain,pitch*pitchShift,duration,
            finishPitch and finishPitch*pitchShift,swell,actor)
    end
    local function shot(name,volume,speed) self:_shot(name,volume*gain,speed) end
    local power=finite(event.power) and event.power or 20
    if kind=="launch" then
        shot("whoosh",0.22,0.85)
        voice("jump",0.14,0.75,0.28,1.5)
    elseif kind=="bump" then
        -- The everyday clack of two tops touching: louder the harder it was.
        local weight=math.clamp(power/BattleAudio.BIG_HIT,0.25,1)
        shot("punch",0.2+0.3*weight,1.25-0.25*weight)
        voice("land",0.1+0.12*weight,1.5,0.12,1.1)
    elseif kind=="big_hit" then
        self:_stopCharges(event.target==2 and 2 or 1)
        shot("punch",0.7,0.85); shot("thump",0.7,0.9); shot("comic",0.4,1.1)
        voice("boom",0.16,1.2,0.22,0.8)
        if power>=55 then shot("sub",0.6,1.1); shot("gasp",0.35,1.1) end
    elseif kind=="windup:dash" then
        -- A rising whine while the top winds itself up.
        voice("chime",0.2,0.7,0.5,1.9,true)
        shot("rise",0.25,1.5)
    elseif kind=="attack:dash" then
        self:_stopCharges(actor)
        shot("whoosh",0.6,1.4); shot("ignite",0.35,1.3)
    elseif kind=="attack:swoop" then
        shot("whoosh",0.45,0.95); voice("jump",0.12,1.1,0.4,1.7)
    elseif kind=="attack:shove" then
        shot("thunder",0.3,1.4); voice("boom",0.1,0.6,0.5,0.9)
    elseif kind=="windup:jump" then
        voice("jump",0.16,0.55,0.35,0.9,true)
    elseif kind=="attack:jump" then
        self:_stopCharges(actor)
        voice("jump",0.3,0.9,0.4,1.6); shot("whoosh",0.3,1.1)
    elseif kind=="slam" then
        shot("thump",0.75,0.75); shot("crunch",0.35,1.1)
        voice("land",0.3,0.6,0.25,0.45)
    elseif kind=="slam_hit" then
        shot("punch",0.6,0.8); shot("comic",0.4,0.95)
    elseif kind=="land" then
        voice("land",0.26,0.8,0.2,0.6); shot("thump",0.4,1.1)
    elseif kind=="bumper_block" then
        voice("jump",0.34,1.5,0.3,0.7); shot("comic",0.6,1.4); shot("punch",0.4,1.3)
    elseif kind=="jetpack" then
        shot("ignite",0.7,1); shot("rise",0.45,1.2); shot("cheer",0.4,1)
    elseif kind=="close" then
        shot("gasp",0.4,1.2); voice("chime",0.16,1.3,0.3,1.8)
    elseif kind=="ringout" then
        self:_stopCharges()
        -- Going over the edge is the finishing blow: its own, larger sound,
        -- and the stands erupt. The fall itself belongs to playCrash.
        voice("boom",0.13,1.25,0.24,0.85)
        shot("bigBlast",0.7,0.95); shot("sub",0.8,1); shot("cheer",0.7,1)
    elseif kind=="finish" then
        self:_stopCharges()
        voice("chime",0.23,1.1,0.5)
        if simulation.reason~="ringout" then shot("whistle",0.55,0.9); shot("cheer",0.5,1) end
    end
    self.played=self.played+1
    self.folder:SetAttribute("PlayedEvents",self.played)
    self.folder:SetAttribute("LastEvent",kind)
end

function BattleAudio:playCrash(roundId,actor)
    if self.destroyed or not self.key or tostring(roundId)~=self.key
        or (actor~=1 and actor~=2) or self.phase~="Results" or not self.crashAllowed
        or not self.resultsAt or os.clock()-self.resultsAt>BattleAudio.MAX_CRASH_AGE
        or not self.resultOut or self.resultOut[actor]~=true
        or self.crashes[actor] then return false end
    -- Consume muted falls too: unmuting must never replay an old one.
    self.crashes[actor]=true
    if self.muted then return false end
    local gain=actor==2 and 0.88 or 1
    -- A long falling whistle as the top drops out of the sky.
    self:_voice("chime",0.3*gain,1.6,1.1,0.35)
    self:_shot("whoosh",0.5*gain,0.6)
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
    self.resultOut=nil; self.crashes={}
end

function BattleAudio:update(snapshot)
    if self.destroyed then return end
    self:_ambience(snapshot)
    if type(snapshot)~="table" or snapshot.active~=true then
        if self.key then self:stop() end
        return
    end
    local key=tostring(snapshot.roundId)
    if self.key~=key then self:stop(); self.key=key end
    local phase=(snapshot.phase=="RoundOver" or snapshot.phase=="MatchOver") and "Results" or snapshot.phase
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
        self.crashAllowed=self.sawFight==true and simulation.finished==true and simulation.reason=="ringout"
        self.resultOut={}
        for index,fighter in ipairs(simulation.fighters or {}) do
            if index>2 then break end
            self.resultOut[fighter.id or index]=fighter.out==true
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
