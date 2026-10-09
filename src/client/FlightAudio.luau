-- Local presentation only: one bounded mix for the watched pilot, never the whole course.
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

function Audio.new()
    local self=setmetatable({voices={},nextVoice={},lastSerial=0,key=nil,muted=false,
        tweens={},lastAt={},played=0,ready=false},Audio)
    self.folder=Instance.new("Folder"); self.folder.Name="SkyboundAudio"; self.folder.Parent=SoundService
    self.group=Instance.new("SoundGroup"); self.group.Name="FlightMix"; self.group.Volume=0.75; self.group.Parent=self.folder
    local preload={}
    for name,id in pairs(SOURCES) do
        self.voices[name]={}; self.nextVoice[name]=0
        for index=1,3 do
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
end

function Audio:voice(name,volume,pitch,duration,finishPitch)
    if not self.folder.Parent then return end
    local pool=self.voices[name]
    local index=self.nextVoice[name]%#pool+1; self.nextVoice[name]=index
    local sound=pool[index]
    if self.tweens[sound] then self.tweens[sound]:Cancel() end
    sound:Stop(); sound.TimePosition=0; sound.Volume=volume; sound.PlaybackSpeed=pitch
    sound:Play()
    self.tweens[sound]=TweenService:Create(sound,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {Volume=0,PlaybackSpeed=finishPitch or pitch})
    self.tweens[sound]:Play()
end

function Audio:playEvent(event)
    local kind=event.kind
    local now=os.clock()
    -- A history batch can contain several contacts; avoid a wall of identical sounds.
    local cooldown=kind=="nearMiss" and 0.45 or 0.07
    if now-(self.lastAt[kind] or -math.huge)<cooldown then return end
    self.lastAt[kind]=now
    if kind=="fuel" or kind=="boost" then
        local amount=kind=="boost" and 20 or (event.value or 5)
        local pitch=0.95+math.clamp(amount,0,20)*0.017
        self:voice("boing",0.44,pitch,0.62,pitch+0.12)
        self:voice("chime",0.22,pitch*1.25,0.48,pitch*1.4)
    elseif kind=="missile" or kind=="hit" then
        self:voice("boom",0.42,1.2,0.8,0.9)
        self:voice("land",0.38,0.7,0.24)
    elseif kind=="shield" then
        self:voice("boom",0.15,1.75,0.36)
        self:voice("chime",0.36,1.65,0.55)
    elseif kind=="nearMiss" then
        self:voice("jump",0.16,0.8,0.24,1.55)
    elseif kind=="launch" then
        self:voice("jump",0.30,0.65,0.4,1.8)
        self:voice("boom",0.18,1.45,0.35)
    elseif kind=="finish" then
        self:voice("land",0.42,0.85,0.45)
        self:voice("chime",0.20,0.95,0.7)
    else return end
    self.played+=1
    self.folder:SetAttribute("PlayedEvents",self.played)
    self.folder:SetAttribute("LastEvent",kind)
end

function Audio:update(flight,roundKey,userId,active)
    if not flight or not active then self.key=nil; return end
    local key=tostring(roundKey)..":"..tostring(userId)
    local events=flight.recentEvents or (flight.lastEvent and {flight.lastEvent}) or {}
    if self.key~=key then
        self.key=key; self.lastSerial=0; self.lastAt={}
        -- When changing spectator, start with current events rather than replaying a backlog.
        if (flight.elapsed or 0)>0.6 then
            for _,event in ipairs(events) do self.lastSerial=math.max(self.lastSerial,event.serial or 0) end
            return
        end
    end
    for _,event in ipairs(events) do
        local serial=event.serial or 0
        if serial>self.lastSerial then
            self.lastSerial=serial
            local age=(flight.elapsed or 0)-(event.at or 0)
            if age>=0 and age<0.7 then self:playEvent(event) end
        end
    end
end

function Audio:destroy()
    for _,tween in pairs(self.tweens) do tween:Cancel() end
    self.folder:Destroy()
end
return Audio
