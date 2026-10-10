-- Original mix using only the short sounds bundled with Roblox.
-- Four voices per source keep a multiball cascade from allocating endlessly.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Audio = {}
Audio.__index = Audio
local SOURCES = {
    pop = "rbxasset://sounds/volume_slider.ogg",
    launch = "rbxasset://sounds/action_jump.mp3",
    bass = "rbxasset://sounds/action_jump_land.mp3",
    boom = "rbxasset://sounds/impact_explosion_03.mp3",
}

function Audio.new()
    local self = setmetatable({pools = {}, cursors = {}, tweens = {}, muted = false, lastHit = 0}, Audio)
    self.folder = Instance.new("Folder")
    self.folder.Name = "PegAudio"
    self.folder.Parent = SoundService
    for key, asset in pairs(SOURCES) do
        self.pools[key] = {}
        self.cursors[key] = 0
        for i = 1, 4 do
            local voice = Instance.new("Sound")
            voice.Name = key .. i
            voice.SoundId = asset
            voice.Volume = 0
            voice.Parent = self.folder
            table.insert(self.pools[key], voice)
        end
    end
    return self
end

function Audio:setMuted(value)
    self.muted = value == true
    self.folder:SetAttribute("Muted", self.muted)
    if self.muted then
        for _, pool in pairs(self.pools) do
            for _, voice in ipairs(pool) do voice:Stop() end
        end
    end
end

function Audio:play(key, volume, pitch, duration)
    if self.muted then return end
    local pool = self.pools[key]
    if not pool then return end
    self.cursors[key] = self.cursors[key] % #pool + 1
    local voice = pool[self.cursors[key]]
    if self.tweens[voice] then self.tweens[voice]:Cancel() end
    voice:Stop()
    voice.TimePosition = 0
    voice.Volume = volume
    voice.PlaybackSpeed = pitch
    voice:Play()
    local tween = TweenService:Create(voice, TweenInfo.new(duration or 0.35), {Volume = 0})
    self.tweens[voice] = tween
    tween:Play()
end

function Audio:event(event, shot)
    if event.kind == "hit" then
        if os.clock() - self.lastHit < 0.045 then return end
        self.lastHit = os.clock()
        local hits = shot and shot.hitCount or 0
        -- Pentatonic steps keep successive target pops in one musical family.
        local steps = {0, 2, 4, 7, 9}
        local degree = math.floor(hits % 15)
        local semitone = steps[degree % 5 + 1] + math.floor(degree / 5) * 5
        self:play("pop", 0.28, 0.78 * 2 ^ (semitone / 12), 0.26)
    elseif event.kind == "launch" then
        self:play("launch", 0.34, 1.25, 0.4)
        self:play("bass", 0.18, 0.8, 0.24)
    elseif event.kind == "power" then
        self:play("boom", 0.24, 1.5, 0.42)
        self:play("pop", 0.36, 1.75, 0.6)
    elseif event.kind == "return" then
        self:play("launch", 0.25, 1.65, 0.4)
    elseif event.kind == "catch" then
        self:play("pop", 0.36, 2, 0.65)
        self:play("bass", 0.2, 1.2, 0.3)
    elseif event.kind == "finish" then
        self:play("pop", 0.18, 1, 0.5)
    end
end

function Audio:select(confirmed)
    self:play("pop", confirmed and 0.32 or 0.14, confirmed and 1.65 or 1.25, 0.3)
end

function Audio:celebrate()
    for i, pitch in ipairs({1, 1.25, 1.5, 2}) do
        task.delay((i - 1) * 0.11, function()
            if self.folder.Parent then self:play("pop", 0.3, pitch, 0.6) end
        end)
    end
end

function Audio:destroy()
    for _, tween in pairs(self.tweens) do tween:Cancel() end
    self.folder:Destroy()
end

return Audio
