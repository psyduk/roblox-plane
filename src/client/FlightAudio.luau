-- Local presentation only: both duel pilots share a bounded mix. Each pilot
-- retains its own event cursor, even when the spectator camera changes.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Audio = {}
Audio.__index = Audio

-- Free Creator Store cartoon jump by Dizzota; bundled Roblox sounds keep every
-- other layer available without uploads. If the public jump is unavailable,
-- the local jump sound is substituted after preload.
local BOING = "rbxassetid://2772396665"
local JUMP = "rbxasset://sounds/action_jump.mp3"
local EXPLOSION = "rbxasset://sounds/impact_explosion_03.mp3"
local CHIME = "rbxasset://sounds/volume_slider.ogg"
local LAND = "rbxasset://sounds/action_jump_land.mp3"
local SOURCES = { boing=BOING, jump=JUMP, boom=EXPLOSION, chime=CHIME, land=LAND }
Audio.VOICES_PER_SOURCE = 4
Audio.VOICE_POOL_LIMIT = 20

function Audio.new()
    local self=setmetatable({voices={},nextVoice={},tracks={},key=nil,muted=false,
        tweens={},played=0,ghostPlayed=0,humanPlayed=0,ready=false,selectionAt={}},Audio)
    self.folder=Instance.new("Folder"); self.folder.Name="SkyboundAudio"; self.folder.Parent=SoundService
    self.group=Instance.new("SoundGroup"); self.group.Name="FlightMix"; self.group.Volume=0.75; self.group.Parent=self.folder
    local preload={}
    for name,id in pairs(SOURCES) do
        self.voices[name]={}; self.nextVoice[name]=0
        for index=1,Audio.VOICES_PER_SOURCE do
            local sound=Instance.new("Sound")
            sound.Name=name..index; sound.SoundId=id; sound.Volume=0; sound.SoundGroup=self.group
            sound.Parent=self.folder; table.insert(self.voices[name],sound); table.insert(preload,sound)
        end
    end
    task.spawn(function()
        pcall(function() ContentProvider:PreloadAsync(preload) end)
        if not self.folder.Parent then return end
        for _,sound in ipairs(self.voices.boing) do if not sound.IsLoaded then sound.SoundId=JUMP end end
        self.ready=true
        self.folder:SetAttribute("Ready",true)
    end)
    return self
end

function Audio:setMuted(muted)
    self.muted=muted==true
    self.group.Volume=self.muted and 0 or 0.75
    self.folder:SetAttribute("Muted",self.muted)
    if self.muted then
        -- Keep event cursors while silencing active voices, so unmuting never
        -- replays contacts that happened while the player chose quiet mode.
        for _,tween in pairs(self.tweens) do tween:Cancel() end
        for _,pool in pairs(self.voices) do for _,sound in ipairs(pool) do sound:Stop() end end
    end
end

function Audio:voice(name,volume,pitch,duration,finishPitch)
    if self.muted or not self.folder.Parent then return end
    local pool=self.voices[name]
    if not pool then return end
    local index=self.nextVoice[name]%#pool+1; self.nextVoice[name]=index
    local sound=pool[index]
    if self.tweens[sound] then self.tweens[sound]:Cancel() end
    sound:Stop(); sound.TimePosition=0; sound.Volume=volume; sound.PlaybackSpeed=pitch
    sound:Play()
    self.tweens[sound]=TweenService:Create(sound,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {Volume=0,PlaybackSpeed=finishPitch or pitch})
    self.tweens[sound]:Play()
end

function Audio:playEvent(event, gain, pitchFactor, track, pilot)
    if self.muted then return end
    local kind=event.kind
    local now=os.clock()
    gain, pitchFactor = gain or 1, pitchFactor or 1
    track = track or {lastAt={}}
    -- A history batch can contain several contacts; avoid a wall of identical sounds.
    local cooldown=kind=="nearMiss" and 0.45 or 0.07
    if now-(track.lastAt[kind] or -math.huge)<cooldown then return end
    track.lastAt[kind]=now
    local function voice(name, volume, pitch, duration, finishPitch)
        self:voice(name,volume*gain,pitch*pitchFactor,duration,finishPitch and finishPitch*pitchFactor)
    end
    if kind=="fuel" or kind=="boost" then
        local amount=kind=="boost" and 20 or (event.value or 5)
        local pitch=0.95+math.clamp(amount,0,20)*0.017
        voice("boing",0.44,pitch,0.62,pitch+0.12)
        voice("chime",0.22,pitch*1.25,0.48,pitch*1.4)
    elseif kind=="missile" or kind=="hit" then
        voice("boom",0.42,1.2,0.8,0.9)
        voice("land",0.38,0.7,0.24)
    elseif kind=="shield" then
        voice("boom",0.15,1.75,0.36)
        voice("chime",0.36,1.65,0.55)
    elseif kind=="nearMiss" then
        voice("jump",0.16,0.8,0.24,1.55)
    elseif kind=="launch" then
        voice("jump",0.30,0.65,0.4,1.8)
        voice("boom",0.18,1.45,0.35)
    elseif kind=="finish" then
        voice("land",0.42,0.85,0.45)
        voice("chime",0.20,0.95,0.7)
    elseif kind=="pinball" then
        local pitch=0.85+math.clamp(event.value or 1,1,3)*0.16
        voice("boing",0.66,pitch,0.8,pitch+0.4)
        voice("land",0.29,0.7,0.2,1.25)
        voice("chime",0.21,pitch*1.45,0.5)
    elseif kind=="munch" then
        voice("land",0.64,0.65,0.27,1.5)
        voice("boom",0.3,1.9,0.28,1.25)
        voice("jump",0.3,0.95,0.55,1.8)
    elseif kind=="meteorDive" then
        voice("jump",0.48,1.8,0.75,0.6)
        voice("boom",0.27,0.65,0.85,0.45)
    elseif kind=="meteorBoost" then
        voice("boom",0.52,0.95,0.72,1.35)
        voice("jump",0.44,0.65,0.64,1.9)
        voice("chime",0.26,1.2,0.6,1.8)
    else return end
    self.played+=1
    self.folder:SetAttribute("PlayedEvents",self.played)
    self.folder:SetAttribute("LastEvent",kind)
    if pilot then
        self.folder:SetAttribute("LastPilot",tostring(pilot.userId))
        if pilot.bot then self.ghostPlayed+=1 else self.humanPlayed+=1 end
        self.folder:SetAttribute("GhostEvents",self.ghostPlayed)
        self.folder:SetAttribute("HumanEvents",self.humanPlayed)
    end
end

-- Selection sounds only follow deliberate UI input. This shares the same
-- bounded voice pool and mute switch as both pilots' flight events.
function Audio:playSelection(powerId, confirmed)
    if self.muted or (powerId~="Pinball" and powerId~="Muncher" and powerId~="Meteor") then return end
    self.selectionAt=self.selectionAt or {}
    local key=powerId..(confirmed and ":lock" or ":preview")
    local now=os.clock()
    if now-(self.selectionAt[key] or -math.huge)<0.12 then return end
    self.selectionAt[key]=now
    local gain=confirmed and 1 or 0.55
    if powerId=="Pinball" then
        self:voice("boing",0.5*gain,1.1,0.55,1.55)
    elseif powerId=="Muncher" then
        self:voice("land",0.48*gain,0.7,0.22,1.4)
        self:voice("boom",0.2*gain,1.8,0.3)
    else
        self:voice("jump",0.4*gain,1.4,0.6,0.75)
        self:voice("boom",0.23*gain,0.8,0.48)
    end
    if confirmed then self:voice("chime",0.32,1.4,0.65,1.75) end
    self.folder:SetAttribute("LastSelection",powerId)
    self.folder:SetAttribute("SelectionConfirmed",confirmed==true)
end

function Audio:stop()
    for _,tween in pairs(self.tweens) do tween:Cancel() end
    for _,pool in pairs(self.voices) do for _,sound in ipairs(pool) do sound:Stop() end end
    self.key=nil; self.tracks={}
end

function Audio:update(players,roundKey,watchedUserId,active)
    if not active then if self.key then self:stop() end; return end
    local key=tostring(roundKey)
    if self.key~=key then
        self:stop(); self.key=key
    end
    local present={}
    -- A duel has two entrants. Bounding traversal also bounds cursor storage.
    for index=1,math.min(2,#(players or {})) do
        local pilot=players[index]
        local flight=pilot.flight
        if flight then
            local id=tostring(pilot.userId)
            present[id]=true
            local events=flight.recentEvents or (flight.lastEvent and {flight.lastEvent}) or {}
            local track=self.tracks[id]
            if not track then
                track={lastSerial=0,lastAt={}}; self.tracks[id]=track
                -- Suppress history only on joining a flight already in progress.
                -- Switching cameras must not reset either pilot's cursor.
                if (flight.elapsed or 0)>0.6 then
                    for _,event in ipairs(events) do track.lastSerial=math.max(track.lastSerial,event.serial or 0) end
                end
            end
            for _,event in ipairs(events) do
                local serial=event.serial or 0
                if serial>track.lastSerial then
                    track.lastSerial=serial
                    local age=(flight.elapsed or 0)-(event.at or 0)
                    if age>=0 and age<0.7 then
                        self:playEvent(event,pilot.userId==watchedUserId and 1 or 0.65,pilot.bot and 0.94 or 1,track,pilot)
                    end
                end
            end
        end
    end
    for id in pairs(self.tracks) do if not present[id] then self.tracks[id]=nil end end
end

function Audio:destroy()
    self:stop()
    self.folder:Destroy()
end
return Audio
