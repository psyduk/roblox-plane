-- Full-body avatar presentation only. No code or sounds from a character run
-- in this viewport, and the live character is never moved or re-parented.
local Players = game:GetService("Players")
local AvatarView = {}
AvatarView.__index = AvatarView

local function make(class, name, parent, properties)
    local object = Instance.new(class)
    object.Name = name
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function part(model, name, size, position, color, shape)
    return make("Part", name, model, {
        Size = size, CFrame = CFrame.new(position), Color = color,
        Shape = shape or Enum.PartType.Block, Material = Enum.Material.SmoothPlastic,
        Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
        TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
    })
end

-- An original little arcade mascot, used only for an explicit practice ghost
-- or while an unavailable avatar loads. No uploaded meshes/textures required.
local function fallbackModel(accent, ghost)
    local model = Instance.new("Model")
    model.Name = ghost and "PracticeGhost" or "StudioPlayer"
    local cream = Color3.fromRGB(255, 231, 191)
    local ink = Color3.fromRGB(38, 43, 80)
    if ghost then
        local pearl = accent:Lerp(Color3.new(1, 1, 1), 0.8)
        part(model, "Body", Vector3.new(2.3, 2.8, 1.8), Vector3.new(0, 2.4, 0), pearl, Enum.PartType.Ball)
        for i = -1, 1 do
            part(model, "Wisp" .. i, Vector3.new(0.85, 1.2, 1.5), Vector3.new(i * 0.65, 1.35, 0), pearl, Enum.PartType.Ball)
        end
        part(model, "LeftEye", Vector3.new(0.21, 0.32, 0.16), Vector3.new(-0.42, 2.9, -0.84), ink, Enum.PartType.Ball)
        part(model, "RightEye", Vector3.new(0.21, 0.32, 0.16), Vector3.new(0.42, 2.9, -0.84), ink, Enum.PartType.Ball)
        part(model, "Smile", Vector3.new(0.36, 0.16, 0.12), Vector3.new(0, 2.52, -0.89), accent, Enum.PartType.Ball)
        part(model, "LeftHand", Vector3.new(0.65, 0.8, 0.7), Vector3.new(-1.25, 2.0, 0), pearl, Enum.PartType.Ball)
        part(model, "RightHand", Vector3.new(0.65, 0.8, 0.7), Vector3.new(1.25, 2.0, 0), pearl, Enum.PartType.Ball)
    else
        local torso = part(model, "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), accent)
        model.PrimaryPart = torso
        part(model, "Head", Vector3.new(1.65, 1.5, 1.45), Vector3.new(0, 4.7, 0), cream)
        part(model, "LeftArm", Vector3.new(0.85, 2, 0.9), Vector3.new(-1.45, 3, 0), cream)
        part(model, "RightArm", Vector3.new(0.85, 2, 0.9), Vector3.new(1.45, 3, 0), cream)
        part(model, "LeftLeg", Vector3.new(0.9, 2, 0.95), Vector3.new(-0.52, 1, 0), ink)
        part(model, "RightLeg", Vector3.new(0.9, 2, 0.95), Vector3.new(0.52, 1, 0), ink)
        part(model, "LeftEye", Vector3.new(0.17, 0.2, 0.1), Vector3.new(-0.37, 4.84, -0.76), ink)
        part(model, "RightEye", Vector3.new(0.17, 0.2, 0.1), Vector3.new(0.37, 4.84, -0.76), ink)
        part(model, "Smile", Vector3.new(0.45, 0.12, 0.1), Vector3.new(0, 4.4, -0.76), ink)
        part(model, "ShirtMark", Vector3.new(0.55, 0.55, 0.07), Vector3.new(0, 3.18, -0.54), Color3.new(1, 1, 1))
    end
    return model
end

local function cloneCharacter(character)
    if not character or not character:FindFirstChild("Head") or not character:FindFirstChildWhichIsA("BasePart", true) then return nil end
    local previous = character.Archivable
    local ok, result = pcall(function()
        character.Archivable = true
        return character:Clone()
    end)
    -- Clone is synchronous. Restore even if cloning itself raises an error.
    pcall(function() character.Archivable = previous end)
    return ok and result or nil
end

local function scrub(model)
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("LuaSourceContainer") or child:IsA("Tool") or child:IsA("Sound")
            or child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Beam")
            or child:IsA("Smoke") or child:IsA("Fire") or child:IsA("Sparkles")
            or child:IsA("BillboardGui") or child:IsA("SurfaceGui")
            or child:IsA("ProximityPrompt") or child:IsA("Animator") then
            child:Destroy()
        elseif child:IsA("BasePart") then
            child.Anchored = true
            child.LocalTransparencyModifier = 0
            child.CanCollide, child.CanTouch, child.CanQuery = false, false, false
            child.AssemblyLinearVelocity, child.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
        elseif child:IsA("Motor6D") then
            child.Transform = CFrame.identity
        elseif child:IsA("Humanoid") then
            child.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            child.AutoRotate, child.BreakJointsOnDeath = false, false
        end
    end
end

-- Visible bounds exclude invisible gameplay hitboxes while including worn
-- accessories. Bounds are calculated once per appearance, not per frame.
local function visibleBounds(model)
    local minimum = Vector3.new(math.huge, math.huge, math.huge)
    local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
    local found = false
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("BasePart") and child.Transparency < 0.99 then
            found = true
            local half = child.Size / 2
            for _, x in ipairs({-1, 1}) do
                for _, y in ipairs({-1, 1}) do
                    for _, z in ipairs({-1, 1}) do
                        local point = child.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
                        minimum = Vector3.new(math.min(minimum.X, point.X), math.min(minimum.Y, point.Y), math.min(minimum.Z, point.Z))
                        maximum = Vector3.new(math.max(maximum.X, point.X), math.max(maximum.Y, point.Y), math.max(maximum.Z, point.Z))
                    end
                end
            end
        end
    end
    if not found then return Vector3.zero, Vector3.new(4, 6, 2) end
    return (minimum + maximum) / 2, maximum - minimum
end

function AvatarView.new(parent, accentColor, facing)
    local self = setmetatable({accent = accentColor or Color3.fromRGB(67, 221, 248),
        facing = type(facing) == "number" and math.clamp(facing, -1, 1) or 1,
        generation = 0, connections = {}, reducedMotion = false, time = 0,
        phase = nil, celebration = 99, sourcePriority = 0, destroyed = false}, AvatarView)
    self.root = make("Frame", "AvatarPresenter", parent, {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0, ClipsDescendants = false})
    self.viewport = make("ViewportFrame", "Avatar", self.root, {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
        Ambient = Color3.fromRGB(224, 227, 247), LightColor = Color3.fromRGB(255, 244, 225),
        LightDirection = Vector3.new(-0.45, -0.65, -1), ImageColor3 = Color3.new(1, 1, 1),
    })
    self.world = make("WorldModel", "AvatarWorld", self.viewport)
    self.camera = make("Camera", "AvatarCamera", self.viewport, {FieldOfView = 28})
    self.viewport.CurrentCamera = self.camera
    self.resizeConnection = self.viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:_fit() end)
    return self
end

function AvatarView:_fit()
    if self.destroyed or not self.size then return end
    local viewportSize = self.viewport.AbsoluteSize
    if viewportSize.X < 1 or viewportSize.Y < 1 then return end
    local aspect = viewportSize.X / viewportSize.Y
    local tangent = math.tan(math.rad(self.camera.FieldOfView / 2))
    local paddedHeight = self.size.Y * 1.23
    local paddedWidth = self.size.X * 1.2
    local distance = math.max(paddedHeight / (2 * tangent), paddedWidth / (2 * tangent * aspect)) + self.size.Z / 2
    local focus = Vector3.new(0, self.size.Y * 0.51, 0)
    self.camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, distance), focus)
    self.camera.Focus = CFrame.new(focus)
end

function AvatarView:_show(model, source, priority, generation)
    if self.destroyed or generation ~= self.generation or priority < self.sourcePriority then model:Destroy(); return end
    scrub(model)
    model.Name = self.isGhost and "PracticeGhost" or "PlayerAvatar"
    model:PivotTo(CFrame.Angles(0, math.rad(180 + self.facing * 12), 0))
    local center, size = visibleBounds(model)
    local move = Vector3.new(-center.X, -center.Y + size.Y / 2, -center.Z)
    model:PivotTo(CFrame.new(move) * model:GetPivot())
    if self.model then self.model:Destroy() end
    self.model, self.size, self.basePivot = model, size, model:GetPivot()
    self.sourcePriority = priority
    model.Parent = self.world
    self.root:SetAttribute("AvatarSource", source)
    self.root:SetAttribute("AvatarLoaded", source == "character" or source == "account-avatar" or source == "practice-ghost" or source == "studio-fallback")
    self.root:SetAttribute("IsGhost", self.isGhost == true)
    self:_fit()
end

function AvatarView:_disconnect()
    for _, connection in ipairs(self.connections) do connection:Disconnect() end
    self.connections = {}
    if self.appearanceConnection then self.appearanceConnection:Disconnect(); self.appearanceConnection = nil end
    self.observedCharacter = nil
    self.boundPlayer = nil
end

function AvatarView:_watchCharacter(character, generation)
    if self.destroyed or generation ~= self.generation then return end
    self.observedCharacter = character
    if self.appearanceConnection then self.appearanceConnection:Disconnect() end
    local rebuildSerial, rebuildCount = 0, 0
    local function rebuild()
        if self.destroyed or generation ~= self.generation or self.observedCharacter ~= character or not character.Parent then return end
        local model = cloneCharacter(character)
        if model then self:_show(model, "character", 3, generation) end
    end
    self.appearanceConnection = character.DescendantAdded:Connect(function(child)
        if not (child:IsA("Accessory") or child:IsA("Clothing") or child:IsA("CharacterMesh")
            or child:IsA("BodyColors") or child:IsA("BasePart") or child:IsA("WrapLayer")) then return end
        if rebuildCount >= 8 then return end
        rebuildSerial = rebuildSerial + 1
        local serial = rebuildSerial
        task.delay(0.25, function()
            if serial ~= rebuildSerial then return end
            rebuildCount = rebuildCount + 1
            rebuild()
        end)
    end)
    rebuild()
    -- CharacterAppearanceLoaded is server-only. These bounded client retries
    -- let replicated clothing/accessories settle without polling forever.
    for _, delay in ipairs({0.3, 1.2, 3}) do task.delay(delay, rebuild) end
end

function AvatarView:setPlayer(entry)
    local key = entry and (tostring(entry.userId) .. ":" .. tostring(entry.isGhost == true)) or "none"
    if self.key == key then return end
    self.key = key
    self.generation = self.generation + 1
    local generation = self.generation
    self:_disconnect()
    self.sourcePriority, self.phase, self.celebration = 0, nil, 99
    self.userId, self.isGhost = entry and entry.userId, entry and entry.isGhost == true
    if not entry then
        if self.model then self.model:Destroy(); self.model = nil end
        self.size, self.basePivot = nil, nil
        self.root:SetAttribute("AvatarSource", "none")
        self.root:SetAttribute("AvatarLoaded", false)
        self.root:SetAttribute("UserId", nil)
        self.root:SetAttribute("AvatarUserId", nil)
        self.root:SetAttribute("PlayerName", nil)
        self.root:SetAttribute("IsGhost", false)
        return
    end
    self.root:SetAttribute("UserId", entry.userId or 0)
    self.root:SetAttribute("AvatarUserId", entry.userId or 0)
    self.root:SetAttribute("PlayerName", entry.name or "Player")
    self:_show(fallbackModel(self.accent, self.isGhost), self.isGhost and "practice-ghost" or "placeholder", 0, generation)
    if self.isGhost then return end
    local function bindPlayer(player)
        if self.destroyed or generation ~= self.generation or self.boundPlayer then return end
        self.boundPlayer = player
        table.insert(self.connections, player.CharacterAdded:Connect(function(character)
            self:_watchCharacter(character, generation)
        end))
        if player.Character then self:_watchCharacter(player.Character, generation) end
    end
    local player
    for _, candidate in ipairs(Players:GetPlayers()) do
        if candidate.UserId == entry.userId then player = candidate; break end
    end
    if player then
        bindPlayer(player)
    else
        local playerAdded
        playerAdded = Players.PlayerAdded:Connect(function(candidate)
            if candidate.UserId ~= entry.userId then return end
            playerAdded:Disconnect()
            bindPlayer(candidate)
        end)
        table.insert(self.connections, playerAdded)
    end
    -- Negative Studio IDs are not Roblox account IDs. Never request them.
    if type(entry.userId) ~= "number" or entry.userId <= 0 then
        if self.sourcePriority == 0 then
            self.root:SetAttribute("AvatarSource", "studio-fallback")
            self.root:SetAttribute("AvatarLoaded", true)
        end
        return
    end
    if self.sourcePriority >= 3 then return end
    local userId = entry.userId
    task.spawn(function()
        local ok, description = pcall(function() return Players:GetHumanoidDescriptionFromUserIdAsync(userId) end)
        if not ok or not description then return end
        if self.destroyed or self.generation ~= generation or self.sourcePriority >= 3 then description:Destroy(); return end
        local built, model = pcall(function()
            return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
        end)
        description:Destroy()
        if built and model then self:_show(model, "account-avatar", 2, generation) end
    end)
end

function AvatarView:setReducedMotion(value)
    self.reducedMotion = value == true
end

function AvatarView:update(dt, state)
    if self.destroyed or not self.model then return end
    state = state or {}
    dt = math.clamp(dt or 0, 0, 0.1)
    self.time = self.time + dt
    if state.phase ~= self.phase then
        self.phase = state.phase
        local result = state.result
        if self.phase == "Results" and result and not result.draw and result.winnerId == self.userId then
            self.celebration = 0
        end
    end
    self.celebration = self.celebration + dt
    local y, turn, lean = 0, 0, 0
    if not self.reducedMotion then
        y = math.sin(self.time * 1.9) * self.size.Y * (self.isGhost and 0.018 or 0.004)
        turn = math.sin(self.time * 0.8) * 0.018
        if state.ready and self.phase == "Aim" then lean = self.facing * -0.025 end
        if self.celebration < 2.2 then
            local fade = 1 - self.celebration / 2.2
            y = y + math.abs(math.sin(self.celebration * 8)) * self.size.Y * 0.055 * fade
            lean = math.sin(self.celebration * 8) * 0.07 * fade
        end
    end
    self.model:PivotTo(CFrame.new(0, y, 0) * self.basePivot * CFrame.Angles(0, turn, lean))
end

function AvatarView:destroy()
    if self.destroyed then return end
    self.destroyed = true
    self.generation = self.generation + 1
    self:_disconnect()
    if self.resizeConnection then self.resizeConnection:Disconnect() end
    self.root:Destroy()
    self.model = nil
end

return AvatarView
