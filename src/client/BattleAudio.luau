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
BattleAudio.ROUND_TIME = 35
local KINDS = {
    launch=true, windup=true, dive=true, rocket=true, hit=true, bump=true,
    bumper_block=true, wake_hit=true, afterburner=true, finish=true, knockout=true,
    burst=true, tracer_hit=true, ricochet=true, magnet=true, secondwind=true,
    fizz=true, pinball_bounce=true, vampire=true, chicken=true, eject=true, combo=true,
    snowball=true, swap=true, gambler=true, sniper=true,
    wrap=true, potato=true, potato_pass=true, decoy_pop=true, thief=true, boomerang=true, catch=true,
}
local function finite(value)
    return type(value)=="number" and value==value and value>-math.huge and value<math.huge
end
local function audibleKind(event)
    if event.kind=="skill" then
        return ({Afterburner="afterburner",Magnet="magnet",SecondWind="secondwind",FizzyFuel="fizz",
            Vampire="vampire",Chicken="chicken",Eject="eject",Snowball="snowball",Swap="swap",Gambler="gambler",Thief="thief"})[event.skillId]
    elseif event.kind=="rocket" and event.source=="boomerang" then
        return "boomerang"
    elseif event.kind=="rocket" and event.source=="sniper" then
        return "sniper"
    elseif event.kind=="combo" then
        return "combo"
    elseif event.kind=="bounce" then
        return event.source=="pinball" and "pinball_bounce" or nil
    elseif event.kind=="blocked" then
        return event.skillId=="SpringBumper" and "bumper_block" or nil
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
    -- The battle loop steps right back at the result so the sting can land.
    self:_loop("music",active and ((fighting or phase=="Countdown") and 0.24 or ((phase=="Results" or phase=="RoundOver" or phase=="MatchOver") and 0.05 or 0.13)) or 0,closing and 1.04 or 1)
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
        local left=math.ceil(BattleAudio.ROUND_TIME-elapsed)
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
    local function shot(name,volume,speed) self:_shot(name,volume*gain,speed) end
    if kind=="launch" then
        shot("whoosh",0.22,0.85)
        voice("jump",0.14,0.75,0.28,1.5)
    elseif kind=="windup" then
        local fighter=simulation.fighters and simulation.fighters[actor]
        if fighter and fighter.offenceId=="Meteor" then
            -- Low rising charge, then a separate downward sweep on commitment.
            local duration=finite(fighter.windupDuration) and fighter.windupDuration>0
                and math.max(0.2,math.min(3,fighter.windupDuration)) or 0.65
            local age=math.max(0,elapsed-time)
            local remaining=math.max(0.08,duration-age)
            voice("jump",0.16,0.55,remaining,1.15,true)
            voice("chime",0.055,0.7,math.min(0.48,remaining),1.0)
            shot("rise",0.42,math.clamp(1.9/remaining,0.8,2.4))
        else
            -- A tiny bright arming cue leaves space for rocket ignition.
            voice("chime",0.11,1.85,0.24,2.1)
            voice("land",0.045,2.25,0.09)
            shot("beep",0.2,1.9)
        end
    elseif kind=="dive" then
        self:_stopCharges(actor)
        -- Commitment sounds fast and weighty, but never claims an armor hit.
        voice("jump",0.25,1.65,0.46,0.55)
        voice("land",0.10,0.75,0.16,0.5)
        shot("whoosh",0.6,0.75); shot("ignite",0.35,0.9)
    elseif kind=="rocket" then
        voice("jump",0.22,1.15,0.3,1.9)
        voice("boom",0.12,2.1,0.14,1.6)
        shot("ignite",0.55,1.15)
    elseif kind=="burst" then
        voice("land",0.12,2.5,0.12)
        shot("click",0.36,1.7); shot("beep",0.13,1.5)
    elseif kind=="tracer_hit" then
        -- Connections are light ticks; only the threshold event breaks armor.
        voice("chime",0.065,2.1,0.08)
    elseif kind=="ricochet" then
        -- Pinball is the arcade power: a flipper thwack and a rising bleep.
        voice("jump",0.24,0.8,0.24,2.2); voice("chime",0.16,1.2,0.2,2.4)
        shot("comic",0.5,1.5); shot("click",0.4,0.8)
    elseif kind=="pinball_bounce" then
        -- Each wall is a bumper: a bright ping that climbs with every bounce.
        voice("chime",0.2,1.9,0.16,2.6); voice("land",0.1,2.2,0.08)
        shot("beep",0.35,2.2); shot("comic",0.3,1.8)
    elseif kind=="magnet" then
        -- A heavy electric hum that drops as the rival is dragged in.
        voice("jump",0.22,1.9,0.6,0.45); voice("chime",0.14,0.6,0.5,0.4)
        shot("sub",0.5,1.3); shot("rise",0.35,0.7)
    elseif kind=="secondwind" then
        -- The comeback: thunder, a rising rush and the crowd on its feet.
        voice("chime",0.22,0.9,0.6,1.9)
        shot("thunder",0.7,1.1); shot("rise",0.45,1.3); shot("cheer",0.4,1.1)
    elseif kind=="vampire" then
        -- A wet gulp: a low thud that slides up as the armor is drained.
        voice("jump",0.24,0.5,0.4,1.5); voice("land",0.16,0.7,0.2,0.4)
        shot("sub",0.45,1.6); shot("comic",0.45,0.6)
    elseif kind=="chicken" then
        -- A squawk and a pop: high, silly and nothing like a weapon.
        voice("jump",0.26,2.6,0.14,1.5); voice("jump",0.2,2.1,0.22,2.9)
        shot("whistle",0.3,0.5); shot("comic",0.55,2)
    elseif kind=="eject" then
        -- The plane goes up, the seat goes out, the parachute snaps open.
        voice("jump",0.26,0.7,0.5,2.4)
        shot("bigBlast",0.6,1.2); shot("rise",0.5,1.6); shot("whoosh",0.4,0.7)
    elseif kind=="wrap" then
        -- A quick sci-fi blip, up then down.
        voice("chime",0.14,2.4,0.14,0.9); shot("beep",0.25,2.6)
    elseif kind=="potato" then
        -- The biggest bang in the game.
        voice("boom",0.4,0.7,0.5,0.4); shot("bigBlast",0.8,0.9); shot("sub",0.6,1); shot("gasp",0.4,1)
    elseif kind=="potato_pass" then
        -- A hot-hands yelp.
        voice("jump",0.2,1.8,0.12,2.6); shot("click",0.4,1.2); shot("beep",0.25,1.1)
    elseif kind=="decoy_pop" then
        -- A balloon.
        voice("land",0.2,2.8,0.06); shot("comic",0.5,2.4); shot("click",0.4,2.4)
    elseif kind=="thief" then
        -- A sneaky slide and a cash-register ping.
        voice("jump",0.18,1.2,0.25,2); voice("chime",0.2,2.4,0.2,2.6); shot("whoosh",0.3,1.8)
    elseif kind=="boomerang" then
        -- A low whirr that rises as the blade spins away.
        voice("jump",0.2,0.9,0.5,1.6); shot("whoosh",0.5,0.8); shot("rise",0.25,1.1)
    elseif kind=="catch" then
        voice("land",0.16,1.6,0.08); shot("click",0.35,1.5)
    elseif kind=="snowball" then
        -- A soft crunch that drops in pitch as the plane swells.
        voice("land",0.2,1.4,0.3,0.7); shot("crunch",0.4,1.5); shot("thump",0.4,1.3)
    elseif kind=="swap" then
        -- Two whooshes crossing over, then a chime.
        voice("chime",0.22,2,0.5,0.8); voice("chime",0.22,0.8,0.5,2)
        shot("whoosh",0.5,1.4); shot("rise",0.4,1.8)
    elseif kind=="gambler" then
        -- Dice on a table.
        voice("land",0.14,2.4,0.1); shot("click",0.5,1.6); shot("click",0.4,2.1); shot("beep",0.25,1.8)
    elseif kind=="sniper" then
        -- A single dry crack with a long tail, nothing like the other guns.
        voice("boom",0.3,2.2,0.12,1.2); shot("punch",0.7,0.7); shot("whoosh",0.3,2.2); shot("thunder",0.3,1.8)
    elseif kind=="combo" then
        -- A named build gets its own little announcement.
        voice("chime",0.2,1.1,0.3,2.2)
        shot("beep",0.3,1.4); shot("cheer",0.25,1.3)
    elseif kind=="fizz" then
        -- A shaken can: a hiss and a pop.
        voice("land",0.1,2.6,0.25,1.6)
        shot("ignite",0.3,1.9); shot("click",0.3,1.3)
    elseif kind=="hit" then
        if event.source=="machinegun" then
            voice("land",0.2,1.4,0.16); shot("punch",0.55,1.35); shot("thump",0.35,1.3)
        elseif event.source=="pinball" then
            -- Jackpot: the smack, then a falling arcade trill.
            voice("jump",0.26,2.0,0.3,0.6); voice("chime",0.2,2.4,0.3,1.2)
            shot("comic",0.65,0.85); shot("thump",0.7,1.2); shot("beep",0.3,1.6)
        elseif event.source=="meteor" then
            voice("boom",0.30,0.8,0.46,0.55)
            voice("land",0.30,0.55,0.18)
            -- A slam: low thump, a knuckle crack and bending metal.
            shot("thump",0.8,0.9); shot("punch",0.65,0.85); shot("crunch",0.5,0.9)
        else
            voice("boom",0.29,1.5,0.32,0.95)
            voice("land",0.21,1.05,0.13)
            -- A rocket: the bang first, then the same body blow underneath.
            shot("blast",0.7,1.1); shot("thump",0.55,1.1); shot("punch",0.4,1.15)
        end
        -- Every damaging hit breaks one armor pip: glass, a deep body blow
        -- under it, and the crowd feels it.
        shot("shatter",0.42,1.1); shot("sub",0.55,1.15); shot("gasp",0.34,1)
    elseif kind=="bumper_block" then
        -- A giant spring: the boing, then a metal clang as both planes fly apart.
        voice("jump",0.32,0.7,0.5,2.3)
        voice("chime",0.16,1.6,0.3)
        shot("comic",0.75,0.8); shot("crunch",0.45,1.4)
    elseif kind=="wake_hit" then
        -- The cloud bursts: a wet pop and a hiss, then the armor cracks.
        voice("land",0.26,1.6,0.2)
        voice("boom",0.2,2.2,0.3,1.2)
        shot("ignite",0.45,1.7); shot("punch",0.45,1.3); shot("shatter",0.34,1.3); shot("sub",0.4,1.3)
    elseif kind=="afterburner" then
        -- A jet lighting: ignition roar and a long fly-by.
        voice("jump",0.24,0.5,0.5,2.0)
        shot("ignite",0.7,0.75); shot("whoosh",0.6,1.3)
    elseif kind=="bump" then
        -- A normal collision pushes without armor loss: never use the hit mix.
        voice("land",0.065,1.55,0.11)
        shot("comic",0.26,1.35)
    elseif kind=="knockout" or (kind=="finish" and simulation.reason=="knockout") then
        self:_stopCharges()
        -- Armor breaking ends the fight. The heavier ground thud belongs to
        -- playCrash, when the defeated plane actually reaches the floor.
        voice("boom",0.13,1.25,0.24,0.85)
        voice("chime",0.21,0.95,0.48,1.4)
        -- The finishing blow is its own, larger sound, and the stands erupt.
        shot("bigBlast",0.85,0.9); shot("sub",0.9,1); shot("cheer",0.7,1)
    elseif kind=="finish" then
        self:_stopCharges()
        voice("land",0.12,0.9,0.2)
        voice("chime",0.23,1.1,0.5)
        shot("whistle",0.55,0.9); shot("cheer",0.5,1)
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
    self:_shot("crunch",0.85*gain,0.75); self:_shot("thump",0.8*gain,0.8)
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
