--!nonstrict
-- Original, asset-free arcade scenery. Gameplay decisions live in Simulation.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Simulation = require(script.Parent.Simulation)
local PlaneCatalog = require(script.Parent.PlaneCatalog)
local CosmeticCatalog = require(script.Parent.CosmeticCatalog)

local World = {}

local COLORS = {
	navy = Color3.fromRGB(20, 35, 69),
	deep = Color3.fromRGB(12, 23, 47),
	cream = Color3.fromRGB(255, 245, 217),
	cyan = Color3.fromRGB(66, 225, 239),
	coral = Color3.fromRGB(255, 104, 102),
	yellow = Color3.fromRGB(255, 212, 80),
	lime = Color3.fromRGB(173, 255, 112),
	purple = Color3.fromRGB(184, 138, 255),
}
local PLANE_COLORS = { COLORS.coral, COLORS.cyan, COLORS.yellow, COLORS.purple }
local planeData = setmetatable({}, { __mode = "k" })

local THEMES = {
	-- Late-afternoon light: a warm tint instead of flat grey midday.
	Hub = {
		clock = 16.3, brightness = 1.9, exposure = -0.1,
		ambient = Color3.fromRGB(100, 96, 100), outdoor = Color3.fromRGB(136, 128, 124),
		tint = Color3.fromRGB(255, 249, 240), saturation = 0.06, contrast = 0.04,
		fog = Color3.fromRGB(236, 208, 182),
	},
	Coast = {
		clock = 13.5, brightness = 1.8, exposure = -0.12,
		ambient = Color3.fromRGB(94, 101, 111), outdoor = Color3.fromRGB(125, 137, 143),
		tint = Color3.fromRGB(255, 250, 239), saturation = 0.04, contrast = 0.02,
		ground = Color3.fromRGB(135, 190, 112), sky = Color3.fromRGB(144, 218, 238),
		accent = Color3.fromRGB(255, 131, 113), cloud = Color3.fromRGB(255, 246, 218),
		fog = Color3.fromRGB(177, 224, 237),
	},
	Skyline = {
		clock = 17.1, brightness = 1.9, exposure = -0.03,
		ambient = Color3.fromRGB(101, 96, 116), outdoor = Color3.fromRGB(146, 124, 128),
		tint = Color3.fromRGB(255, 236, 220), saturation = -0.03, contrast = 0.05,
		ground = Color3.fromRGB(73, 87, 110), sky = Color3.fromRGB(242, 196, 164),
		accent = Color3.fromRGB(94, 228, 234), cloud = Color3.fromRGB(255, 225, 199),
		fog = Color3.fromRGB(226, 190, 174),
	},
	Storm = {
		clock = 14.8, brightness = 2, exposure = 0.02,
		ambient = Color3.fromRGB(140, 130, 170), outdoor = Color3.fromRGB(175, 165, 200),
		tint = Color3.fromRGB(235, 224, 255), saturation = 0.04, contrast = 0.07,
		ground = Color3.fromRGB(69, 62, 103), sky = Color3.fromRGB(78, 62, 120),
		accent = Color3.fromRGB(181, 140, 255), cloud = Color3.fromRGB(116, 99, 156),
		fog = Color3.fromRGB(110, 91, 155),
	},
}

-- Call these locally when entering/leaving a match; each client's arena can
-- differ while the server continues presenting the shared social hub.
function World.setArenaTheme(name)
	local theme = THEMES[name] or THEMES.Hub
	Lighting.ClockTime = theme.clock
	Lighting.Brightness = theme.brightness
	Lighting.Ambient = theme.ambient
	Lighting.OutdoorAmbient = theme.outdoor
	Lighting.ExposureCompensation = theme.exposure
	Lighting.FogColor = theme.fog
	Lighting.FogStart = 1800
	Lighting.FogEnd = 9000
	local correction = Lighting:FindFirstChild("FlightArenaColor")
	if not correction then
		correction = Instance.new("ColorCorrectionEffect")
		correction.Name = "FlightArenaColor"
		correction.Parent = Lighting
	end
	correction.Enabled = true
	correction.TintColor = theme.tint
	correction.Saturation = theme.saturation
	correction.Contrast = theme.contrast
	correction.Brightness = 0
end

function World.resetTheme()
	World.setArenaTheme("Hub")
end

World.LOBBY_SPAWN = Vector3.new(9, 7, 32)
-- Floor positions. The hero bay holds the local pilot's own plane, nose toward
-- the doors; line-up bays show other pilots; the stand shows the next unlock.
World.HERO_BAY = { position = Vector3.new(0, 4, 10), rotation = math.pi / 2, scale = 2 }
World.UNLOCK_STAND = Vector3.new(30, 4, 20)
World.LINEUP_BAYS = {
	{ position = Vector3.new(-74, 4, 42), rotation = 0, scale = 1.3 },
	{ position = Vector3.new(-74, 4, 14), rotation = 0, scale = 1.3 },
	{ position = Vector3.new(-74, 4, -14), rotation = 0, scale = 1.3 },
	{ position = Vector3.new(74, 4, -14), rotation = math.pi, scale = 1.3 },
}
World.COURSE_ORIGIN = Vector3.new(0, 0, -5000)
World.LOBBY_CAMERA = {
	position = Vector3.new(8, 17, 60),
	lookAt = Vector3.new(0, 9, 10),
}
World.DUEL_STATIONS = {}
for index, x in { -27, 27 } do
	table.insert(World.DUEL_STATIONS, {
		id = "duel" .. index,
		name = "DUEL " .. index,
		seats = { Vector3.new(x - 8, 4.3, -47), Vector3.new(x + 8, 4.3, -47) },
	})
end
local queueLabels = {}

local function part(parent, name, size, cframe, color, material, collidable, shape)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.Anchored = true
	object.CanCollide = collidable == true
	object.CanTouch = collidable == true
	object.CanQuery = collidable == true
	object.CastShadow = false
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	if shape == Enum.PartType.Ball then
		-- PartType.Ball renders a sphere using the smallest dimension. A built-in
		-- Sphere mesh preserves the deliberate ellipsoid dimensions of scenery,
		-- fuselages and cockpit glass without loading any external mesh asset.
		local mesh = Instance.new("SpecialMesh")
		mesh.Name = "Ellipsoid"
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.one
		mesh.Parent = object
	elseif shape then
		object.Shape = shape
	end
	object.Parent = parent
	return object
end

local function textLabel(parent, text, position, size, color, font)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = color or COLORS.cream
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function surface(parent, title, subtitle, accent)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	-- Match the physical sign's aspect ratio; a fixed canvas stretches wide
	-- lobby headings and makes the same font look different on each display.
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.Parent = parent
	textLabel(gui, title, UDim2.fromScale(0.05, 0.14), UDim2.fromScale(0.9, 0.4), accent).Name = "Title"
	if subtitle and subtitle ~= "" then
		textLabel(gui, subtitle, UDim2.fromScale(0.07, 0.62), UDim2.fromScale(0.86, 0.22), COLORS.cream, Enum.Font.GothamMedium).Name = "Subtitle"
	end
	return gui
end

local function billboard(parent, text, color, offset, width, height, badge)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Caption"
	gui.Adornee = parent
	gui.Size = UDim2.fromOffset(width or 120, height or 40)
	gui.StudsOffset = Vector3.new(0, offset or 5, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = parent
	local label = textLabel(gui, text, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), color)
	label.TextStrokeColor3 = COLORS.deep
	label.TextStrokeTransparency = 0
	if badge then
		label.BackgroundColor3 = COLORS.navy
		label.BackgroundTransparency = 0.08
		label.BorderSizePixel = 0
		label.TextStrokeTransparency = 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.22, 0)
		corner.Parent = label
	end
	return gui
end

local function sign(parent, name, position, size, title, subtitle, accent, rotation)
	local cframe = CFrame.new(position) * CFrame.Angles(0, rotation or 0, 0)
	local frame = part(parent, name, size + Vector3.new(1, 1, 0.2), cframe, accent)
	local panel = part(parent, name .. "Face", size, cframe * CFrame.new(0, 0, -0.2), COLORS.navy)
	surface(panel, title, subtitle, accent)
	return frame
end

local function makePlane(parent, name, colorIndex, planeId)
	planeId = (planeId == "skyhopper" or planeId == "dart") and planeId or PlaneCatalog.DEFAULT_ID
	local color = PLANE_COLORS[((colorIndex or 1) - 1) % #PLANE_COLORS + 1]
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("PlaneId", planeId)
	model.Parent = parent
	local pivot = part(model, "FlightPivot", Vector3.one, CFrame.identity, color)
	pivot.Transparency = 1
	model.PrimaryPart = pivot
	local bodySize = planeId == "dart" and Vector3.new(9.6, 2.3, 2.2) or Vector3.new(8.7, 3.1, 3.1)
	local body = part(model, "Fuselage", bodySize, CFrame.identity, color, nil, false, Enum.PartType.Ball)
	if planeId == "skyhopper" then
		-- Two broad wings and visible struts give the climbing plane a clear
		-- silhouette from both the side-on match camera and the showroom.
		-- The upper wing sits aft of the shared open cockpit and seated pilot.
		part(model, "MainWing", Vector3.new(3.4, 0.45, 13.6), CFrame.new(-1.15, -0.45, 0), color)
		part(model, "UpperWing", Vector3.new(2.5, 0.45, 15), CFrame.new(-1.55, 2.1, 0), color)
		for _, side in { -1, 1 } do
			part(model, "WingStrut", Vector3.new(0.32, 2.65, 0.32), CFrame.new(-1.45, 0.8, side * 4.9) * CFrame.Angles(0, 0, 0.12), COLORS.navy)
			part(model, "UpperWingTip", Vector3.new(2.6, 0.52, 1.15), CFrame.new(-1.55, 2.12, side * 6.95), COLORS.cream)
		end
		part(model, "TailWing", Vector3.new(2.1, 0.35, 6.3), CFrame.new(-3.5, 0.35, 0), COLORS.cream)
		part(model, "TailFin", Vector3.new(2.1, 2.7, 0.42), CFrame.new(-3.3, 1.7, 0) * CFrame.Angles(0, 0, -0.16), color)
	elseif planeId == "dart" then
		-- Narrow fuselage, swept panels and a raked tail read as a fast racer.
		for _, side in { -1, 1 } do
			local wingPose = CFrame.new(-1.25, -0.3, side * 2.9) * CFrame.Angles(0, -side * 0.48, 0)
			part(model, "SweptWing", Vector3.new(2.7, 0.3, 6.5), wingPose, color)
			part(model, "RacerWingTip", Vector3.new(2.4, 0.4, 0.85), wingPose * CFrame.new(0, 0, side * 2.95), COLORS.cream)
			part(model, "RacingStripe", Vector3.new(4.5, 0.23, 0.09), CFrame.new(-0.7, 0.45, side * 1.06), COLORS.cream)
		end
		part(model, "TailWing", Vector3.new(1.5, 0.24, 4.6), CFrame.new(-3.9, 0.25, 0), COLORS.cream)
		part(model, "TailFin", Vector3.new(2.2, 1.7, 0.3), CFrame.new(-3.75, 1.15, 0) * CFrame.Angles(0, 0, -0.48), color)
	else
		part(model, "MainWing", Vector3.new(3.1, 0.42, 12), CFrame.new(-0.5, -0.25, 0), color)
		part(model, "LeftWingTip", Vector3.new(3.2, 0.5, 1), CFrame.new(-0.5, -0.21, -5.65), COLORS.cream)
		part(model, "RightWingTip", Vector3.new(3.2, 0.5, 1), CFrame.new(-0.5, -0.21, 5.65), COLORS.cream)
		part(model, "TailWing", Vector3.new(1.8, 0.3, 5.2), CFrame.new(-3.5, 0.35, 0), COLORS.cream)
		part(model, "TailFin", Vector3.new(1.9, 2.2, 0.35), CFrame.new(-3.2, 1.45, 0) * CFrame.Angles(0, 0, -0.25), color)
	end
	part(model, "Cockpit", Vector3.new(3.15, 1.7, 2.25), CFrame.new(0.6, 1.3, 0), COLORS.navy, nil, false, Enum.PartType.Ball)
	local noseSize = planeId == "dart" and Vector3.new(2.3, 1.9, 1.9) or Vector3.new(1.9, 2.7, 2.7)
	part(model, "Nose", noseSize, CFrame.new(3.7, 0, 0), COLORS.cream, nil, false, Enum.PartType.Ball)
	local propeller = Instance.new("Model")
	propeller.Name = "Propeller"
	propeller.Parent = model
	local hub = part(propeller, "Hub", Vector3.new(0.75, 0.8, 0.8), CFrame.new(5.1, 0, 0), COLORS.navy, nil, false, Enum.PartType.Cylinder)
	propeller.PrimaryPart = hub
	part(propeller, "BladeA", Vector3.new(0.22, 5, 0.43), CFrame.new(5.05, 0, 0), COLORS.navy)
	part(propeller, "BladeB", Vector3.new(0.22, 0.43, 5), CFrame.new(5.05, 0, 0), COLORS.navy)
	local flare = part(model, "FlightFlare", Vector3.new(4.5, 1.8, 1.8), CFrame.new(-5.1, 0, 0), COLORS.lime, Enum.Material.Neon, false, Enum.PartType.Ball)
	flare.Transparency = 1
	local smoke = {}
	for index = 1, 3 do
		local puff = part(model, "HitSmoke" .. index, Vector3.one, CFrame.new(-6 - index, 0, 0), Color3.fromRGB(71, 76, 89), nil, false, Enum.PartType.Ball)
		puff.Transparency = 1
		table.insert(smoke, puff)
	end
	local attachmentA = Instance.new("Attachment")
	attachmentA.Position = Vector3.new(-3.8, 0.3, -0.7)
	attachmentA.Parent = pivot
	local attachmentB = Instance.new("Attachment")
	attachmentB.Position = Vector3.new(-3.8, 0.3, 0.7)
	attachmentB.Parent = pivot
	local trail = Instance.new("Trail")
	trail.Name = "Contrail"
	trail.Attachment0 = attachmentA
	trail.Attachment1 = attachmentB
	trail.Color = ColorSequence.new(color, COLORS.cream)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 0.35
	trail.MinLength = 0.25
	trail.LightEmission = 0.6
	trail.Enabled = false
	trail.Parent = pivot
	planeData[model] = {
		propeller = propeller, phase = 0, body = body, color = color,
		bodySize = bodySize, powerAge = 100,
		flare = flare, trail = trail, smoke = smoke,
		hitAge = 100, boostAge = 100, nearMissAge = 100, lastEventSerial = -1,
		trailMode = "normal", trailColors = {
			normal = trail.Color,
			boost = ColorSequence.new(COLORS.lime, COLORS.cream),
			meteor = ColorSequence.new(COLORS.coral, COLORS.yellow),
			hit = ColorSequence.new(Color3.fromRGB(104, 101, 110), COLORS.cream),
		},
	}
	model:ScaleTo(3.1)
	return model
end

local function cosmeticColor(channels)
	return Color3.fromRGB(channels.r, channels.g, channels.b)
end

local function restoreNormalTrail(data)
	data.trail.Color = data.trailColors.normal
	data.trail.Lifetime = data.normalTrail.lifetime
	data.trail.LightEmission = data.normalTrail.emission
	data.trail.WidthScale = NumberSequence.new(data.normalTrail.width)
end

function World.applyCosmeticTrail(model, trailId)
	local data = planeData[model]
	if not data then return end
	local entry = CosmeticCatalog.get(trailId) or CosmeticCatalog.get(CosmeticCatalog.DEFAULT_ID)
	if data.trailId == entry.id then return end
	data.trailId = entry.id
	data.normalTrail = entry
	data.trailColors.normal = ColorSequence.new(cosmeticColor(entry.color), cosmeticColor(entry.secondaryColor))
	data.trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 1) })
	model:SetAttribute("TrailId", entry.id)
	-- A mid-flight equipment update must not erase a current power/hit cue.
	if data.trailMode == "normal" then restoreNormalTrail(data) end
end

function World.createPlane(parent, name, colorIndex, planeId, trailId)
	local model = makePlane(parent, name, colorIndex, planeId)
	World.applyCosmeticTrail(model, trailId)
	return model
end

-- Base-scale pilot HumanoidRootPart pose. Roblox avatars face local -Z, so
-- rotate them toward the aircraft's +X nose; getCockpitCFrame scales position.
World.COCKPIT_OFFSET = CFrame.new(0.5, 2.1, 0) * CFrame.Angles(0, -math.pi / 2, 0)
function World.getCockpitCFrame(model)
	local scale = model:GetScale()
	return model:GetPivot() * CFrame.new(0.5 * scale, 2.1 * scale, 0) * CFrame.Angles(0, -math.pi / 2, 0)
end

local POWER_COLORS = { Pinball = COLORS.yellow, Muncher = COLORS.lime, Meteor = COLORS.coral }
local POWER_EVENTS = { pinball = "Pinball", munch = "Muncher", meteorDive = "Meteor", meteorBoost = "Meteor" }

local function ensurePowerVisual(model, data, powerId)
	if not POWER_COLORS[powerId] then powerId = nil end
	if data.powerId == powerId then return end
	if data.powerFolder then data.powerFolder:Destroy() end
	data.powerId, data.powerFolder, data.powerPieces = powerId, nil, {}
	data.powerAge = 100
	data.powerPhase = nil
	data.body.Size = data.bodySize * model:GetScale()
	model:SetAttribute("PowerId", powerId)
	model:SetAttribute("PowerPhase", nil)
	model:SetAttribute("PowerPartCount", 0)
	for _, piece in data.propeller:GetChildren() do
		if piece:IsA("BasePart") then piece.Transparency = powerId == "Muncher" and 1 or 0 end
	end
	if not powerId then return end
	local folder = Instance.new("Folder")
	folder.Name = "PowerTransformation"
	folder.Parent = model
	data.powerFolder = folder
	local function add(name, size, position, color, group, angle, transparency, neon)
		local piece = part(folder, name, size, CFrame.identity, color,
			neon and Enum.Material.Neon or Enum.Material.SmoothPlastic, false, Enum.PartType.Ball)
		table.insert(data.powerPieces, { part = piece, size = size, position = position,
			group = group, angle = angle or 0, transparency = transparency or 0 })
	end
	if powerId == "Pinball" then
		-- Two inflatable hoops frame the cockpit; there is deliberately no
		-- opaque sphere around the pilot or the flight path.
		for _, side in { -1, 1 } do
			for index = 1, 12 do
				local a = (index - 1) * math.pi / 6
				local b = index * math.pi / 6
				local first = Vector3.new(math.cos(a) * 5.5, math.sin(a) * 3.6, side * 2.05)
				local last = Vector3.new(math.cos(b) * 5.5, math.sin(b) * 3.6, side * 2.05)
				local segment = last - first
				add("RubberHoop", Vector3.new(segment.Magnitude + 0.5, 0.72, 0.72),
					(first + last) / 2, index % 3 == 0 and COLORS.cream or COLORS.yellow,
					"ring", math.atan2(segment.Y, segment.X))
			end
		end
	elseif powerId == "Muncher" then
		for _, jaw in { -1, 1 } do
			local group = jaw == 1 and "upperJaw" or "lowerJaw"
			add("MuncherJaw", Vector3.new(5.7, 0.9, 4.3), Vector3.new(5.55, jaw * 1.1, 0), COLORS.lime, group)
			for _, side in { -1, 1 } do
				for index = 1, 3 do
					add("ChomperTooth", Vector3.new(0.72, 0.95, 0.75),
						Vector3.new(4.2 + index * 1.05, jaw * 0.5, side * 1.65), COLORS.cream, group, jaw * 0.2)
				end
			end
		end
		for _, side in { -1, 1 } do
			add("MuncherEye", Vector3.new(1.3, 1.4, 0.65), Vector3.new(4.15, 1.95, side * 1.8), COLORS.cream, "upperJaw")
			add("MuncherPupil", Vector3.new(0.58, 0.8, 0.25), Vector3.new(4.43, 1.92, side * 2.1), COLORS.deep, "upperJaw")
		end
		add("MuncherTongue", Vector3.new(3.9, 0.28, 2.1), Vector3.new(5.65, -0.42, 0), COLORS.coral, "lowerJaw")
	elseif powerId == "Meteor" then
		add("MeteorCore", Vector3.new(7, 3.8, 3.8), Vector3.new(-2, -0.3, 0), COLORS.coral, "core", 0, 0.7, true)
		for _, side in { -1, 1 } do
			add("MeteorFin", Vector3.new(4.7, 1.2, 1.7), Vector3.new(-2.6, 0.6, side * 3), COLORS.coral, "fin", -0.4)
			add("HotFinEdge", Vector3.new(3.5, 0.4, 1.9), Vector3.new(-2.5, 1, side * 3), COLORS.yellow, "fin", -0.4, 0.1, true)
		end
		for index = 1, 3 do
			add("MeteorFlame", Vector3.new(7 - index, 0.9, 0.9),
				Vector3.new(-7.3, (index - 2) * 1.2, (index - 2) * 0.4),
				index == 2 and COLORS.yellow or COLORS.coral, "flame", (index - 2) * 0.15, 1, true)
		end
	end
	model:SetAttribute("PowerPartCount", #data.powerPieces)
end

local function updatePowerVisual(model, data, state, pose, scale)
	if not data.powerId then return end
	local powerId = data.powerId
	local kick = math.max(0, 1 - data.powerAge / 0.7)
	local diving = powerId == "Meteor" and state.powerPhase == "diving"
	local heat = diving and 1 or (data.powerKind == "meteorBoost" and kick or 0)
	local phase = state.powerPhase or "armed"
	if data.powerPhase ~= phase then
		data.powerPhase = phase
		model:SetAttribute("PowerPhase", phase)
	end
	local squashX, squashY = 1, 1
	if powerId == "Pinball" and kick > 0 then
		local bounce = math.cos(data.powerAge * 19) * kick
		squashX, squashY = 1 + bounce * 0.2, 1 - bounce * 0.27
	end
	local idle = math.sin((state.elapsed or 0) * 2.8) * 0.025
	for _, entry in data.powerPieces do
		local position, size = entry.position, entry.size
		local transparency = entry.transparency
		local rotation = CFrame.Angles(0, 0, entry.angle)
		if entry.group == "ring" then
			position = Vector3.new(position.X * squashX, position.Y * squashY, position.Z)
			size = Vector3.new(size.X * (1 + kick * 0.06), size.Y * (1 + kick * 0.35), size.Z)
		elseif entry.group == "upperJaw" or entry.group == "lowerJaw" then
			local side = entry.group == "upperJaw" and 1 or -1
			local open = 0.13 + idle
			if data.powerKind == "munch" and kick > 0 then
				open = 0.04 + math.abs(math.sin(math.min(1, data.powerAge / 0.5) * math.pi * 2)) * kick * 0.4
			end
			local jawPose = CFrame.new(3, 0, 0) * CFrame.Angles(0, 0, side * open)
			position = jawPose:PointToWorldSpace(position - Vector3.new(3, 0, 0))
			rotation = CFrame.Angles(0, 0, side * open + entry.angle)
		elseif entry.group == "flame" then
			local flicker = 1 + math.sin(data.phase * 1.7 + position.Y * 3) * 0.12
			size = Vector3.new(size.X * (0.75 + heat * 1.1) * flicker, size.Y * (1 + heat), size.Z * (1 + heat))
			position = Vector3.new(position.X - heat * 2.5, position.Y, position.Z)
			transparency = heat > 0 and (0.1 + (1 - heat) * 0.65) or 1
		elseif entry.group == "core" then
			transparency = 0.78 - heat * 0.2
			size = size * (1 + heat * 0.16)
		end
		entry.part.Size = size * scale
		entry.part.CFrame = pose * CFrame.new(position * scale) * rotation
		entry.part.Transparency = transparency
	end
	-- Only the soft fuselage squashes. Wings, cockpit and seated-avatar mount
	-- retain their stable contract and every decorative part stays nonphysical.
	data.body.Size = Vector3.new(data.bodySize.X * squashX, data.bodySize.Y * squashY, data.bodySize.Z) * scale
	if data.hitAge >= 0.13 then
		data.body.Color = data.body.Color:Lerp(POWER_COLORS[powerId], 0.28 + kick * 0.35)
	end
end

local HANGAR = {
	steel = Color3.fromRGB(48, 67, 83),
	wall = Color3.fromRGB(133, 151, 157),
	roof = Color3.fromRGB(182, 191, 188),
	concrete = Color3.fromRGB(160, 164, 162),
	lane = Color3.fromRGB(88, 105, 112),
	white = Color3.fromRGB(238, 236, 216),
	amber = Color3.fromRGB(250, 185, 65),
}

local function beam(parent, name, first, last, thickness, color)
	return part(parent, name, Vector3.new(thickness, thickness, (last - first).Magnitude),
		CFrame.lookAt((first + last) / 2, last), color, Enum.Material.Metal)
end

local function lobbyPrompt(parent, name, action, object, distance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.MaxActivationDistance = distance or 13
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = parent
	return prompt
end

local function floorLabel(parent, name, position, size, title, color)
	local plate = part(parent, name, Vector3.new(size.X, 0.05, size.Y), CFrame.new(position), HANGAR.lane)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 18
	gui.LightInfluence = 0.3
	gui.Parent = plate
	textLabel(gui, title, UDim2.fromScale(0.03, 0.03), UDim2.fromScale(0.94, 0.94), color, Enum.Font.GothamBold)
	return plate
end

-- `floor` is the point on the ground beneath the aircraft's pivot.
local function parkedPlane(parent, name, colorIndex, planeId, floor, rotation, scale, trailId)
	local model = World.createPlane(parent, name, colorIndex, planeId, trailId)
	model:ScaleTo(scale)
	-- Parked aircraft have landing gear, so the fleet reads as a working
	-- hangar instead of floating models on shop pedestals.
	for _, side in { -1, 1 } do
		part(model, "LandingStrut", Vector3.new(0.22, 1.6, 0.22) * scale,
			CFrame.new(0.7 * scale, -1.65 * scale, side * 1.5 * scale), HANGAR.steel, Enum.Material.Metal)
		part(model, "LandingWheel", Vector3.new(0.5, 1.4, 1.4) * scale,
			CFrame.new(0.7 * scale, -2.1 * scale, side * 1.5 * scale) * CFrame.Angles(0, math.pi / 2, 0),
			COLORS.deep, Enum.Material.SmoothPlastic, false, Enum.PartType.Cylinder)
	end
	part(model, "TailWheel", Vector3.new(0.4, 0.8, 0.8) * scale,
		CFrame.new(-3.25 * scale, -2.4 * scale, 0) * CFrame.Angles(0, math.pi / 2, 0),
		COLORS.deep, Enum.Material.SmoothPlastic, false, Enum.PartType.Cylinder)
	model:PivotTo(CFrame.new(floor + Vector3.new(0, 2.8 * scale + 0.08, 0)) * CFrame.Angles(0, rotation, 0))
	return model
end
World.createParkedPlane = parkedPlane

-- Parked planes keep their engine ticking over; only the propeller moves.
-- Pass `moving` for a plane that is being flown along a path, so its real
-- Trail draws; leave it nil for a plane standing in a bay.
function World.idlePlane(model, dt, moving)
	local data = planeData[model]
	if not data then return end
	if moving ~= nil then data.trail.Enabled = moving end
	data.phase = (data.phase + dt * 26) % (math.pi * 2)
	data.propeller:PivotTo(model:GetPivot() * CFrame.new(5.1 * model:GetScale(), 0, 0) * CFrame.Angles(data.phase, 0, 0))
end

function World.trailLook(trailId)
	local entry = CosmeticCatalog.get(trailId) or CosmeticCatalog.get(CosmeticCatalog.DEFAULT_ID)
	return cosmeticColor(entry.color), cosmeticColor(entry.secondaryColor), entry
end

local function maintenanceCart(parent, position, accent)
	part(parent, "ToolChest", Vector3.new(7, 4, 4), CFrame.new(position), accent, Enum.Material.Metal, true)
	part(parent, "ToolChestTop", Vector3.new(7.5, 0.4, 4.4), CFrame.new(position + Vector3.new(0, 2.15, 0)), HANGAR.steel, Enum.Material.Metal)
	for _, y in { -0.9, 0.15, 1.2 } do
		part(parent, "DrawerHandle", Vector3.new(4, 0.15, 0.22), CFrame.new(position + Vector3.new(0, y, -2.1)), HANGAR.white, Enum.Material.Metal)
	end
	for _, x in { -2.5, 2.5 } do
		part(parent, "CartWheels", Vector3.new(0.5, 1.3, 4.1), CFrame.new(position + Vector3.new(x, -2.3, 0)), COLORS.deep)
	end
end

-- A neon outline on the floor marks a destination in its zone color.
local function floorOutline(parent, name, center, size, color)
	for _, side in { -1, 1 } do
		part(parent, name, Vector3.new(size.X, 0.12, 0.45), CFrame.new(center + Vector3.new(0, 0.1, side * size.Y / 2)), color, Enum.Material.Neon)
		part(parent, name, Vector3.new(0.45, 0.12, size.Y), CFrame.new(center + Vector3.new(side * size.X / 2, 0.1, 0)), color, Enum.Material.Neon)
	end
end

local boardLabels = {}
local lobbyDistanceMode = false

function World.buildLobby(distanceModeEnabled)
	lobbyDistanceMode = distanceModeEnabled == true
	World.resetTheme()
	local existing = Workspace:FindFirstChild("FlightLobby")
	if existing then existing:Destroy() end
	queueLabels = {}
	boardLabels = {}
	local lobby = Instance.new("Folder")
	lobby.Name = "FlightLobby"
	lobby:SetAttribute("DistanceModeEnabled", lobbyDistanceMode)
	lobby.Parent = Workspace
	-- A compact hangar: the pilot's own bay sits in the middle, with every
	-- other destination a few seconds' walk away. Each zone has one color:
	-- cyan for the pilot's bay, violet for flight effects, amber for duels.
	local HALF, FRONT, BACK = 100, -99, 64
	local MID, DEPTH = (FRONT + BACK) / 2, BACK - FRONT
	local hero = World.HERO_BAY.position
	part(lobby, "AirfieldGround", Vector3.new(1200, 8, 1400), CFrame.new(0, -6, -280), Color3.fromRGB(111, 154, 119), Enum.Material.Grass, true)
	part(lobby, "HangarFoundation", Vector3.new(HALF * 2 + 8, 8, DEPTH + 7), CFrame.new(0, -2, MID), HANGAR.steel, Enum.Material.Concrete, true)
	local slab = part(lobby, "PolishedConcrete", Vector3.new(HALF * 2 + 2, 2, DEPTH + 1), CFrame.new(0, 3, MID), HANGAR.concrete, Enum.Material.Concrete, true)
	slab.Reflectance = 0.045
	for _, x in { -66, -33, 33, 66 } do
		part(lobby, "ConcreteJoint", Vector3.new(0.08, 0.035, DEPTH - 2), CFrame.new(x, 4.025, MID), HANGAR.lane)
	end
	for _, z in { -70, -20, 40 } do
		part(lobby, "ConcreteJoint", Vector3.new(HALF * 2 - 2, 0.035, 0.08), CFrame.new(0, 4.025, z), HANGAR.lane)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = World.LOBBY_SPAWN - Vector3.new(0, 2.5, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = lobby

	-- Corrugated sidewalls, a back wall, and a faceted barrel roof establish
	-- an aircraft-scale interior. Skylight strips break up the metal roof.
	for _, side in { -1, 1 } do
		local wall = part(lobby, "HangarSideWall", Vector3.new(2, 30, DEPTH + 1), CFrame.new(side * (HALF + 1), 19, MID), HANGAR.wall, Enum.Material.Metal, true)
		wall.CastShadow = true
		part(lobby, "WallWainscot", Vector3.new(2.3, 7, DEPTH + 1), CFrame.new(side * (HALF - 0.3), 7.5, MID), HANGAR.steel, Enum.Material.Metal, true)
		part(lobby, "WallSafetyStripe", Vector3.new(2.4, 0.7, DEPTH + 1), CFrame.new(side * (HALF - 0.5), 11.3, MID), HANGAR.amber)
		for z = FRONT + 9, BACK - 4, 19 do
			part(lobby, "WallRib", Vector3.new(0.65, 23, 0.8), CFrame.new(side * (HALF - 0.4), 22.5, z), HANGAR.roof, Enum.Material.Metal)
		end
	end
	local backWall = part(lobby, "HangarBackWall", Vector3.new(HALF * 2 + 4, 30, 2), CFrame.new(0, 19, BACK + 1), HANGAR.wall, Enum.Material.Metal, true)
	backWall.CastShadow = true
	part(lobby, "BackWainscot", Vector3.new(HALF * 2, 7, 2), CFrame.new(0, 7.5, BACK - 0.2), HANGAR.steel, Enum.Material.Metal)
	part(lobby, "BackSafetyStripe", Vector3.new(HALF * 2, 0.7, 0.5), CFrame.new(0, 11.3, BACK - 0.5), HANGAR.amber)
	local roofProfile = {
		Vector2.new(-HALF - 1, 34), Vector2.new(-78, 46), Vector2.new(-49, 54),
		Vector2.new(0, 59), Vector2.new(49, 54), Vector2.new(78, 46), Vector2.new(HALF + 1, 34),
	}
	local roofRuns = { FRONT - 1, -78, -48, -14, 16, 44, BACK + 2 }
	for index = 1, #roofProfile - 1 do
		local a, b = roofProfile[index], roofProfile[index + 1]
		local angle = math.atan2(b.Y - a.Y, b.X - a.X)
		for run = 1, #roofRuns - 1 do
			local first, last = roofRuns[run], roofRuns[run + 1]
			local skylight = (index == 3 or index == 4) and (run == 2 or run == 4)
			local panel = part(lobby, skylight and "RoofSkylight" or "RoofPanel",
				Vector3.new((b - a).Magnitude + 0.5, 0.8, last - first + 0.1),
				CFrame.new((a.X + b.X) / 2, (a.Y + b.Y) / 2, (first + last) / 2) * CFrame.Angles(0, 0, angle),
				skylight and Color3.fromRGB(255, 232, 196) or HANGAR.roof,
				skylight and Enum.Material.Glass or Enum.Material.Metal, true)
			panel.Transparency = skylight and 0.68 or 0
			panel.CastShadow = not skylight
		end
	end
	for _, z in { FRONT + 1, -44, 10, BACK - 1 } do
		for index = 1, #roofProfile - 1 do
			local a, b = roofProfile[index], roofProfile[index + 1]
			local upperA, upperB = Vector3.new(a.X, a.Y - 0.8, z), Vector3.new(b.X, b.Y - 0.8, z)
			local lowerA, lowerB = upperA - Vector3.new(0, 4, 0), upperB - Vector3.new(0, 4, 0)
			beam(lobby, "RoofRib", upperA, upperB, 1.35, HANGAR.steel)
			beam(lobby, "RoofTrussChord", lowerA, lowerB, 0.85, HANGAR.steel)
			beam(lobby, "RoofTrussBrace", index % 2 == 0 and upperA or lowerA, index % 2 == 0 and lowerB or upperB, 0.55, HANGAR.steel)
		end
		for _, side in { -1, 1 } do
			part(lobby, "StructuralColumn", Vector3.new(2.1, 30, 2.1), CFrame.new(side * (HALF - 4), 19, z), HANGAR.steel, Enum.Material.Metal, true)
			part(lobby, "ColumnGuard", Vector3.new(2.4, 5, 2.4), CFrame.new(side * (HALF - 4), 6.5, z), HANGAR.amber, Enum.Material.Metal)
		end
	end
	for index = 2, #roofProfile - 1 do
		local point = roofProfile[index]
		part(lobby, "RoofPurlin", Vector3.new(0.7, 0.9, DEPTH), CFrame.new(point.X, point.Y - 1.2, MID), HANGAR.steel, Enum.Material.Metal)
	end
	-- End infill closes the roof above the entrance and rear wall without
	-- lowering the open doorway or obstructing the central view to the runway.
	for index = 1, #roofProfile - 1 do
		local a, b = roofProfile[index], roofProfile[index + 1]
		local bottom, top = 34, math.min(a.Y, b.Y)
		if top > bottom then
			for _, z in { FRONT, BACK + 1 } do
				local infill = part(lobby, "GableInfill", Vector3.new(b.X - a.X, top - bottom, 1.5), CFrame.new((a.X + b.X) / 2, (top + bottom) / 2, z), HANGAR.wall, Enum.Material.Metal, true)
				infill.CastShadow = true
			end
		end
		for _, z in { FRONT, BACK + 1 } do
			local infill = Instance.new("WedgePart")
			infill.Name = "SlopedGableInfill"
			infill.Size = Vector3.new(1.5, math.abs(b.Y - a.Y), b.X - a.X)
			infill.CFrame = CFrame.new((a.X + b.X) / 2, (a.Y + b.Y) / 2, z) * CFrame.Angles(0, b.Y > a.Y and math.pi / 2 or -math.pi / 2, 0)
			infill.Color = HANGAR.wall
			infill.Material = Enum.Material.Metal
			infill.Anchored = true
			infill.CastShadow = true
			infill.Parent = lobby
		end
	end
	for _, x in { -36, 36 } do
		for _, z in { -60, -8, 42 } do
			beam(lobby, "LightSuspension", Vector3.new(x, 52, z), Vector3.new(x, 29.5, z), 0.15, HANGAR.steel)
			part(lobby, "LightHousing", Vector3.new(17, 0.65, 2.5), CFrame.new(x, 29.5, z), HANGAR.steel, Enum.Material.Metal)
			local fixture = part(lobby, "HangarWorkLight", Vector3.new(15.8, 0.18, 1.8), CFrame.new(x, 29.08, z), Color3.fromRGB(255, 236, 200), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 226, 180)
			light.Brightness = 1.3
			light.Range = 60
			light.Shadows = false
			light.Parent = fixture
		end
	end
	for _, side in { -1, 1 } do
		part(lobby, "OpenDoorStack", Vector3.new(12, 30, 4), CFrame.new(side * (HALF - 7), 19, FRONT), HANGAR.steel, Enum.Material.Metal, true)
		for _, offset in { -3.7, 0, 3.7 } do
			part(lobby, "DoorPanelSeam", Vector3.new(0.18, 29, 0.2), CFrame.new(side * (HALF - 7) + offset, 19, FRONT + 2.2), HANGAR.wall)
		end
	end
	part(lobby, "DoorLintel", Vector3.new(HALF * 2, 2, 4), CFrame.new(0, 34.1, FRONT), HANGAR.steel, Enum.Material.Metal)
	part(lobby, "DoorTrack", Vector3.new(HALF * 2 - 24, 0.07, 1), CFrame.new(0, 4.08, FRONT + 2), HANGAR.steel, Enum.Material.Metal)

	-- The board introduces the active game. Distance records remain available
	-- when the shelved flight mode is explicitly enabled.
	local boardPose = CFrame.new(0, 43, FRONT + 3) * CFrame.Angles(0, math.pi, 0)
	part(lobby, "FlightBoardFrame", Vector3.new(112, 15, 0.9), boardPose, COLORS.cyan)
	local board = part(lobby, "FlightBoard", Vector3.new(110, 13, 0.9), boardPose * CFrame.new(0, 0, -0.2), COLORS.navy)
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "Board"
	boardGui.Face = Enum.NormalId.Front
	boardGui.LightInfluence = 0
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 20
	boardGui.Parent = board
	textLabel(boardGui, lobbyDistanceMode and "SKYBOUND  FLIGHT  CLUB" or "SKYBOUND  PLANE  BATTLES",
		UDim2.fromScale(0.04, 0.06), UDim2.fromScale(0.92, 0.3), COLORS.cyan).Name = "Title"
	boardLabels.flying = textLabel(boardGui, "", UDim2.fromScale(0.04, 0.4), UDim2.fromScale(0.92, 0.27), COLORS.yellow)
	boardLabels.flying.Name = "NowFlying"
	boardLabels.best = textLabel(boardGui, "", UDim2.fromScale(0.04, 0.7), UDim2.fromScale(0.92, 0.22), COLORS.cream, Enum.Font.GothamBold)
	boardLabels.best.Name = "ClubBest"
	World.updateLobbyBoard(nil, nil)

	-- The broad apron and runway are visible through the open hangar doors.
	part(lobby, "AircraftApron", Vector3.new(360, 6, 220), CFrame.new(0, 1, -210), Color3.fromRGB(126, 141, 143), Enum.Material.Concrete, true)
	part(lobby, "Runway", Vector3.new(94, 6, 620), CFrame.new(0, 1, -430), HANGAR.lane, Enum.Material.Asphalt, true)
	for _, side in { -1, 1 } do
		part(lobby, "RunwayEdge", Vector3.new(0.8, 0.08, 618), CFrame.new(side * 44, 4.07, -430), HANGAR.white)
		for z = -148, -700, -55 do
			part(lobby, "RunwayLamp", Vector3.new(1.1, 0.45, 1.1), CFrame.new(side * 48, 4.3, z), COLORS.cyan, Enum.Material.Neon)
		end
	end
	for z = -163, -690, -45 do
		part(lobby, "RunwayCenterMark", Vector3.new(2.1, 0.08, 18), CFrame.new(0, 4.08, z), HANGAR.white)
	end
	for _, x in { -30, -22, -14, 14, 22, 30 } do
		part(lobby, "RunwayThreshold", Vector3.new(3.5, 0.08, 22), CFrame.new(x, 4.08, -124), HANGAR.white)
	end
	parkedPlane(lobby, "ApronAircraftLeft", 1, "skyhopper", Vector3.new(-88, 4, -152), math.pi / 2, 1.8)
	parkedPlane(lobby, "ApronAircraftRight", 3, "dart", Vector3.new(89, 4, -170), math.pi / 2, 1.8)
	for _, x in { -93, 93 } do
		for _, z in { -182, -118 } do
			part(lobby, "ApronBayMark", Vector3.new(45, 0.08, 0.4), CFrame.new(x, 4.08, z), HANGAR.amber)
		end
	end

	-- The pilot's display bay. Its selected plane and trail personalize the
	-- hangar; battle signatures are chosen separately after pressing PLAY.
	part(lobby, "HeroBayFloor", Vector3.new(40, 0.08, 36), CFrame.new(hero + Vector3.new(0, 0.06, 0)), COLORS.navy)
	floorOutline(lobby, "HeroBayOutline", hero, Vector2.new(40, 36), COLORS.cyan)
	for _, side in { -1, 1 } do
		part(lobby, "WheelChock", Vector3.new(2, 0.6, 1.4), CFrame.new(hero + Vector3.new(side * 3, 0.4, -3.2)), HANGAR.amber)
	end
	-- A taxi line runs from the bay nose straight out of the doors.
	for z = hero.Z - 24, FRONT + 4, -11 do
		part(lobby, "TaxiDash", Vector3.new(0.7, 0.06, 6), CFrame.new(0, 4.1, z), HANGAR.amber)
	end
	local console = part(lobby, "HeroBayConsole", Vector3.new(4, 5, 4), CFrame.new(hero + Vector3.new(-17, 2.5, 13)), HANGAR.steel, Enum.Material.Metal, true)
	part(lobby, "HeroBayConsoleScreen", Vector3.new(3.2, 2, 0.15), CFrame.new(hero + Vector3.new(-17, 3.6, 15.1)), COLORS.cyan, Enum.Material.Neon)
	lobbyPrompt(console, "HeroBayPrompt", "Next plane", "YOUR BAY", 12)

	-- The next unlock stands beside the bay. Each client fills the display.
	local stand = World.UNLOCK_STAND
	local pedestal = part(lobby, "UnlockPedestal", Vector3.new(3.2, 11, 11), CFrame.new(stand + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), HANGAR.steel, Enum.Material.Metal, true, Enum.PartType.Cylinder)
	part(lobby, "UnlockPedestalTop", Vector3.new(0.3, 10, 10), CFrame.new(stand + Vector3.new(0, 3.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), COLORS.navy, nil, false, Enum.PartType.Cylinder)
	floorOutline(lobby, "UnlockStandOutline", stand, Vector2.new(18, 18), COLORS.purple)
	lobbyPrompt(pedestal, "UnlockStandPrompt", "View effect", "NEXT UNLOCK", 14)

	-- Legacy distance duels stay available for future QA, without advertising
	-- a second game or an unavailable player queue in the default battle lobby.
	if lobbyDistanceMode then
		for index, station in World.DUEL_STATIONS do
			local x = (station.seats[1].X + station.seats[2].X) / 2
			local accent = HANGAR.amber
			part(lobby, "QueueApproach", Vector3.new(34, 0.06, 28), CFrame.new(x, 4.09, -29), HANGAR.lane)
			for _, offset in { -17, 17 } do
				part(lobby, "QueueLaneMark", Vector3.new(0.45, 0.09, 42), CFrame.new(x + offset, 4.11, -35), HANGAR.white)
			end
			part(lobby, "QueueBase", Vector3.new(38, 0.3, 22), CFrame.new(x, 4.15, -47), COLORS.navy)
			for seatIndex, seat in station.seats do
				part(lobby, station.id .. "Pad" .. seatIndex, Vector3.new(12, 0.3, 12), CFrame.new(seat), accent, nil, true)
				local inset = part(lobby, "PadInset", Vector3.new(10.4, 0.08, 10.4), CFrame.new(seat + Vector3.new(0, 0.19, 0)), COLORS.navy)
				local gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Top
				gui.CanvasSize = Vector2.new(300, 300)
				gui.LightInfluence = 0
				gui.Parent = inset
				textLabel(gui, tostring(seatIndex), UDim2.fromScale(0.12, 0.12), UDim2.fromScale(0.76, 0.76), COLORS.cream)
			end
			for _, offset in { -20, 20 } do
				part(lobby, "DepartureGatePost", Vector3.new(1.2, 15.5, 1.2), CFrame.new(x + offset, 11.75, -62), HANGAR.steel, Enum.Material.Metal, true)
			end
			part(lobby, "DepartureGateAccent", Vector3.new(41, 0.5, 1.1), CFrame.new(x, 19.5, -62), accent, Enum.Material.Neon)
			local display = part(lobby, station.id .. "Display", Vector3.new(31, 7, 0.8), CFrame.new(x, 15.5, -62) * CFrame.Angles(0, math.pi, 0), COLORS.navy)
			local gui = surface(display, station.name, "0 / 2 READY", accent)
			queueLabels[station.id] = gui:FindFirstChild("Subtitle")
			floorLabel(lobby, station.id .. "GroundLabel", Vector3.new(x, 4.17, -25), Vector2.new(28, 6), "CHALLENGE A FRIEND", HANGAR.white)
		end
	end

	-- Other pilots' planes line the walls. Clients park each pilot's current
	-- plane and trail in the bay the server assigned to them.
	sign(lobby, "LineupTitle", Vector3.new(-HALF + 0.9, 24, 16), Vector3.new(62, 7, 0.6), "PILOTS IN THE CLUB", "", COLORS.cyan, -math.pi / 2)
	for index, bay in World.LINEUP_BAYS do
		part(lobby, "LineupBayFloor", Vector3.new(26, 0.08, 22), CFrame.new(bay.position + Vector3.new(0, 0.06, 0)), HANGAR.lane)
		floorOutline(lobby, "LineupBayOutline", bay.position, Vector2.new(26, 22), HANGAR.white)
	end
	maintenanceCart(lobby, Vector3.new(-88, 6.75, 58), COLORS.coral)

	-- Flight effects keep one violet corner: a counter that opens the shop
	-- and a banner for every trail in the catalog.
	part(lobby, "EffectsServiceFloor", Vector3.new(38, 0.1, 44), CFrame.new(80, 4.12, 36), HANGAR.lane)
	floorOutline(lobby, "EffectsOutline", Vector3.new(80, 4.12, 36), Vector2.new(38, 44), COLORS.purple)
	part(lobby, "EffectsBackboard", Vector3.new(1.2, 20, 44), CFrame.new(HALF - 1.2, 18, 36), COLORS.navy, Enum.Material.Metal)
	sign(lobby, "EffectsShopTitle", Vector3.new(HALF - 2.1, 24.5, 36), Vector3.new(40, 6, 0.6), "FLIGHT EFFECTS", "", COLORS.purple, math.pi / 2)
	local counter = part(lobby, "EffectsShopCounter", Vector3.new(6, 4.2, 34), CFrame.new(72, 6.1, 36), HANGAR.steel, Enum.Material.Metal, true)
	part(lobby, "EffectsCountertop", Vector3.new(7.4, 0.55, 35), CFrame.new(72, 8.5, 36), HANGAR.white, Enum.Material.SmoothPlastic, true)
	part(lobby, "EffectsCounterLight", Vector3.new(0.2, 0.4, 32), CFrame.new(68.9, 7.1, 36), COLORS.purple, Enum.Material.Neon)
	lobbyPrompt(counter, "EffectsShopPrompt", "Browse effects", "FLIGHT EFFECTS", 16)
	local terminal = part(lobby, "EffectsShopTerminal", Vector3.new(0.5, 2.8, 3.8), CFrame.new(70.4, 10, 36) * CFrame.Angles(0, 0, -0.13), COLORS.navy, Enum.Material.Metal)
	terminal:SetAttribute("ShopTerminal", true)
	for index, trailId in CosmeticCatalog.ORDER do
		local color, second = World.trailLook(trailId)
		local z = 19.5 + (index - 1) * 6.6
		part(lobby, "TrailBannerTop", Vector3.new(0.3, 4.5, 4.6), CFrame.new(HALF - 2, 16.5, z), color, Enum.Material.Neon)
		part(lobby, "TrailBannerTail", Vector3.new(0.3, 4.5, 4.6), CFrame.new(HALF - 2, 12, z), color:Lerp(second, 0.75), Enum.Material.Neon).Transparency = 0.2
	end
	maintenanceCart(lobby, Vector3.new(88, 6.75, 4), HANGAR.amber)
	World.updateLobbyQueues({})
	return lobby
end

-- Distance statistics are shown only while that mode is enabled. The default
-- board explains the current solo setup against a simulated opponent.
function World.updateLobbyBoard(flying, best)
	local nowFlying, clubBest = boardLabels.flying, boardLabels.best
	if not lobbyDistanceMode then
		if nowFlying and nowFlying.Parent then nowFlying.Text = "PRESS PLAY  -  CHOOSE YOUR SETUP" end
		if clubBest and clubBest.Parent then clubBest.Text = "PICK A POWER  -  FIGHT A SIMULATED OPPONENT" end
		return
	end
	if nowFlying and nowFlying.Parent then
		nowFlying.Text = flying and ("NOW FLYING   " .. string.upper(flying)) or "RUNWAY CLEAR  -  PRESS PLAY"
	end
	if clubBest and clubBest.Parent then
		clubBest.Text = best and string.format("CLUB BEST TODAY   %s   %.1f M", string.upper(best.name), best.distance)
			or "CLUB BEST TODAY   BE THE FIRST TO LAND"
	end
end

function World.updateLobbyQueues(queueCounts)
	if not lobbyDistanceMode then return end
	for _, station in World.DUEL_STATIONS do
		local entry = queueCounts and queueCounts[station.id]
		local count = type(entry) == "table" and entry.count or entry
		count = math.clamp(tonumber(count) or 0, 0, 2)
		local label = queueLabels[station.id]
		if label and label.Parent then
			label.Text = tostring(count) .. " / 2 READY" .. (count == 1 and "  -  JOIN IN!" or "")
		end
	end
end

-- The number occupies the collision center. A small fuel can underneath is a
-- secondary clue; no filled disks or oversized badges conceal nearby missiles.
local function fuelModel(parent, item)
	local model = Instance.new("Model")
	model.Name = "Fuel_" .. tostring(item.id)
	model.Parent = parent
	local color = item.value >= 20 and COLORS.cyan or COLORS.lime
	local anchor = part(model, "PickupCenter", Vector3.one, CFrame.identity, color)
	anchor.Transparency = 1
	model.PrimaryPart = anchor
	part(model, "Can", Vector3.new(3.1, 3.8, 2), CFrame.new(0, -8, 0), color, Enum.Material.Neon)
	part(model, "Handle", Vector3.new(1.8, 0.45, 1), CFrame.new(0, -5.8, 0), COLORS.navy)
	part(model, "LabelBand", Vector3.new(3.2, 0.8, 2.1), CFrame.new(0, -8, 0), COLORS.cream)
	local caption = billboard(anchor, "+" .. tostring(item.value), color, 0, 120, 56)
	caption.Name = "FuelNumber"
	caption.Size = UDim2.new(26, 0, 14, 0)
	caption.MaxDistance = 900
	local label = caption:FindFirstChildOfClass("TextLabel")
	label.Font = Enum.Font.FredokaOne
	label.TextStrokeTransparency = 1
	local outline = Instance.new("UIStroke")
	outline.Color = COLORS.deep
	outline.Thickness = 1.4
	outline.Transparency = 0.05
	outline.Parent = label
	return model
end

local function missileModel(parent, item)
	local model = Instance.new("Model")
	model.Name = "Missile_" .. tostring(item.id)
	model.Parent = parent
	local red = Color3.fromRGB(245, 72, 73)
	local body = part(model, "Rocket", Vector3.new(10.6, 2.3, 2.3), CFrame.identity, red, nil, false, Enum.PartType.Cylinder)
	model.PrimaryPart = body
	part(model, "Nose", Vector3.new(4, 2.4, 2.4), CFrame.new(-5.1, 0, 0), red, nil, false, Enum.PartType.Ball)
	part(model, "WarningBand", Vector3.new(0.9, 2.4, 2.4), CFrame.new(-2.9, 0, 0), COLORS.cream, nil, false, Enum.PartType.Cylinder)
	part(model, "FinVertical", Vector3.new(3.5, 5, 0.32), CFrame.new(3.8, 0, 0), red)
	part(model, "FinHorizontal", Vector3.new(3.5, 0.32, 5), CFrame.new(3.8, 0, 0), red)
	part(model, "Exhaust", Vector3.new(6.5, 1.65, 1.65), CFrame.new(7.6, 0, 0), COLORS.yellow, Enum.Material.Neon, false, Enum.PartType.Ball)
	local plume = part(model, "ExhaustPlume", Vector3.new(11, 1.1, 1.1), CFrame.new(13, 0, 0), COLORS.cream, nil, false, Enum.PartType.Ball)
	plume.Transparency = 0.67
	return model
end

World.ITEM_VIEW_BEHIND = 260
World.ITEM_VIEW_AHEAD = 700
World.ITEM_BUILD_BUDGET = 8

local function firstItemAt(visuals, x)
	local low, high = 1, #visuals + 1
	while low < high do
		local middle = math.floor((low + high) / 2)
		if visuals[middle].item.x < x then low = middle + 1 else high = middle end
	end
	return low
end

local function retireItem(render, visual)
	if visual.model then visual.model:Destroy() end
	visual.model = nil
	render.items[visual.item.id] = nil
	render._active[visual.item.id] = nil
end

local function materializeItem(render, visual, elapsed)
	local item = visual.item
	local model = item.kind == "fuel" and fuelModel(render.folder, item) or missileModel(render.folder, item)
	local x, y = Simulation.itemPosition(item, elapsed)
	model:PivotTo(CFrame.new(World.COURSE_ORIGIN + Vector3.new(x, y, 0)))
	visual.model = model
	render.items[item.id] = model
	render._active[item.id] = visual
end

function World.buildCourse(course)
	local folder = Instance.new("Folder")
	folder.Name = "LocalFlightCourse"
	folder.Parent = Workspace
	local origin = World.COURSE_ORIGIN
	local length = math.max(2200, course.length or 2200)
	local variant = (course.name == "Skyline" or course.name == "Storm") and course.name or "Coast"
	local theme = THEMES[variant]
	local function shallowDecoration(name, size, position, shape)
		-- Keep background silhouettes inside low-quality clients' draw distance.
		-- Ground/runway coordinates and all gameplay items retain their depth.
		if position.Z < -30 and name ~= "RunwayEdgeLight" then
			position = Vector3.new(position.X, position.Y, -14 + position.Z * 0.075)
			local depthLimit = shape == Enum.PartType.Cylinder and 13 or 12
			size = Vector3.new(size.X, size.Y, math.min(size.Z, depthLimit))
		end
		return size, position
	end
	local function scenery(name, size, x, y, z, color, shape, material)
		local adjustedSize, position = shallowDecoration(name, size, Vector3.new(x, y, z), shape)
		return part(folder, name, adjustedSize, CFrame.new(origin + position), color, material, false, shape)
	end
	local function placed(name, size, position, rotation, color, material, shape)
		local adjustedSize, adjustedPosition = shallowDecoration(name, size, position, shape)
		return part(folder, name, adjustedSize, CFrame.new(origin + adjustedPosition) * rotation, color, material, false, shape)
	end
	-- Shared collision coordinates stay untouched: all three themes have solid
	-- land at y=0, with decorative silhouettes behind the playable z=0 corridor.
	local groundEnd = length + 300
	for x = -300, groundEnd - 1, 1024 do
		local width = math.min(1024, groundEnd - x)
		scenery("ArenaGroundTile", Vector3.new(width, 10, 1000), x + width / 2, -5, 0, theme.ground)
		if variant == "Skyline" then
			scenery("RooftopRunway", Vector3.new(width, 0.14, 70), x + width / 2, 0.08, 0, Color3.fromRGB(43, 52, 70))
		elseif variant == "Storm" then
			scenery("StormCircuit", Vector3.new(width, 0.14, 58), x + width / 2, 0.08, 0, Color3.fromRGB(49, 43, 78))
		end
		if variant ~= "Coast" then
			for _, z in { -34, 34 } do
				scenery("RunwayEdgeLight", Vector3.new(width, 0.2, 0.5), x + width / 2, 0.2, z, theme.accent, nil, Enum.Material.Neon)
			end
		end
	end
	for x = 0, length, 100 do
		local marker = scenery("DistanceMarker", Vector3.new(0.7, 10, 0.7), x, 5, -26, theme.accent)
		local caption = billboard(marker, tostring(x), COLORS.cream, 7, 85, 32)
		caption.Size = UDim2.new(20, 0, 8, 0)
		scenery("GroundDistanceLine", Vector3.new(1.2, 0.1, 35), x, 0.18, 0, COLORS.cream).Transparency = 0.25
		if variant == "Skyline" then
			scenery("RunwayDash", Vector3.new(26, 0.12, 1.5), x + 45, 0.18, 0, COLORS.cream)
		end
	end

	for index = 1, math.ceil(length / 300) do
		local x = index * 300 - 100
		if variant == "Coast" then
			-- Warm sand, coral terraces, palms and striped lighthouses.
			scenery("CoastalSand", Vector3.new(200, 0.3, 95), x, 0.18, -155, Color3.fromRGB(230, 210, 161))
			scenery("CoralBluff", Vector3.new(150, 40 + index % 3 * 10, 80), x + 30, 8, -315, Color3.fromRGB(225, 139, 125), Enum.PartType.Ball)
			scenery("BluffGrass", Vector3.new(115, 12, 68), x + 30, 26 + index % 3 * 4, -315, Color3.fromRGB(156, 195, 115), Enum.PartType.Ball)
			local palmX, palmZ = x - 73, -100
			placed("PalmTrunk", Vector3.new(2.4, 28, 2.4), Vector3.new(palmX, 14, palmZ), CFrame.Angles(0, 0, -0.12), Color3.fromRGB(157, 117, 83))
			for leaf = 1, 3 do
				placed("PalmLeaf", Vector3.new(34, 4, 8), Vector3.new(palmX + 1, 28, palmZ), CFrame.Angles(0, (leaf - 2) * 0.08, (leaf - 2) * 0.22), Color3.fromRGB(65, 154, 106), nil, Enum.PartType.Ball)
			end
			if index % 3 == 1 then
				local lighthouseX, lighthouseZ = x + 62, -215
				for band = 0, 3 do
					placed("LighthouseBand", Vector3.new(10, 13, 13), Vector3.new(lighthouseX, 5 + band * 10, lighthouseZ), CFrame.Angles(0, 0, math.pi / 2), band % 2 == 0 and COLORS.cream or COLORS.coral, nil, Enum.PartType.Cylinder)
				end
				scenery("LighthouseLantern", Vector3.new(10, 7, 10), lighthouseX, 44, lighthouseZ, COLORS.yellow, nil, Enum.Material.Neon)
				scenery("LighthouseCap", Vector3.new(18, 5, 18), lighthouseX, 49, lighthouseZ, COLORS.navy, Enum.PartType.Ball)
			else
				local cabin = scenery("BeachCabin", Vector3.new(30, 16, 22), x + 45, 8, -185, index % 2 == 0 and COLORS.coral or COLORS.cyan)
				part(folder, "CabinDoor", Vector3.new(8, 11, 0.3), CFrame.new(cabin.Position + Vector3.new(0, -2.5, cabin.Size.Z / 2 + 0.2)), COLORS.cream)
				for _, side in { -1, 1 } do
					placed("CabinRoof", Vector3.new(34, 1.2, 15), Vector3.new(x + 45, 19, -185 + side * 6), CFrame.Angles(-side * math.rad(28), 0, 0), COLORS.navy)
				end
			end
		elseif variant == "Skyline" then
			-- An elevated runway with city towers and lit window bands behind it.
			for tower = 0, 1 do
				local towerX = x + tower * 112 - 55
				local height = 46 + ((index * 7 + tower * 3) % 6) * 14
				local z = tower == 0 and -168 or -294
				local color = tower == 0 and Color3.fromRGB(93, 127, 153) or Color3.fromRGB(124, 117, 153)
				local towerPart = scenery("CityTower", Vector3.new(65, height, 50), towerX, height / 2, z, color)
				scenery("TowerRoof", Vector3.new(69, 3, 54), towerX, height + 1, z, COLORS.navy)
				for window = 1, 3 do
					part(folder, "TowerWindowBand", Vector3.new(48, 3, 0.4), CFrame.new(towerPart.Position + Vector3.new(0, height * window / 4 - height / 2, towerPart.Size.Z / 2 + 0.3)), window % 2 == 0 and COLORS.cyan or COLORS.yellow, Enum.Material.Neon)
				end
				if tower == 0 then
					scenery("RoofAntenna", Vector3.new(1.5, 17, 1.5), towerX + 15, height + 10, z, COLORS.cream)
					scenery("AntennaBeacon", Vector3.new(3.5, 3.5, 3.5), towerX + 15, height + 19, z, COLORS.coral, Enum.PartType.Ball, Enum.Material.Neon)
				end
			end
			scenery("Skybridge", Vector3.new(82, 5, 20), x + 30, 24, -166, Color3.fromRGB(60, 84, 113))
			scenery("RunwayVent", Vector3.new(13, 7, 13), x - 105, 3.5, -73, Color3.fromRGB(126, 147, 166))
		else
			-- Purple dusk, jagged crystal groups, power pylons and distant bolts.
			scenery("BasaltMound", Vector3.new(155, 36, 76), x + 20, 5, -250, Color3.fromRGB(85, 73, 120), Enum.PartType.Ball)
			for crystal = 1, 3 do
				local height = 20 + crystal * 8
				placed("StormCrystal", Vector3.new(7, height, 7), Vector3.new(x - 90 + crystal * 12, height / 2, -106 - crystal * 4), CFrame.Angles(0, 0, (crystal - 2) * 0.22), crystal == 2 and COLORS.cyan or COLORS.purple, Enum.Material.Neon, Enum.PartType.Wedge)
			end
			for _, side in { -1, 1 } do
				placed("PowerPylonLeg", Vector3.new(3.5, 65, 3.5), Vector3.new(x + 59 + side * 10, 31, -205), CFrame.Angles(0, 0, side * 0.22), Color3.fromRGB(43, 39, 70))
			end
			scenery("PylonCrossbar", Vector3.new(38, 3, 5), x + 59, 57, -205, COLORS.purple, nil, Enum.Material.Neon)
			scenery("PylonCore", Vector3.new(9, 9, 9), x + 59, 68, -205, COLORS.cyan, Enum.PartType.Ball, Enum.Material.Neon)
			if index % 2 == 0 then
				for segment = 1, 3 do
					placed("DistantLightning", Vector3.new(2, 27, 2), Vector3.new(x + 106 + segment % 2 * 9, 235 - segment * 21, -380), CFrame.Angles(0, 0, segment % 2 == 0 and 0.45 or -0.45), Color3.fromRGB(222, 208, 255), Enum.Material.Neon)
				end
			end
		end
		for cloudIndex = 0, 1 do
			scenery("ArenaCloud", Vector3.new(72, 13, 31), x + cloudIndex * 29, 195 + (index % 3) * 16 + cloudIndex * 5, -370, theme.cloud, Enum.PartType.Ball).Transparency = variant == "Storm" and 0.08 or 0.18
		end
	end

	-- A single nearby backdrop follows the camera's part of the course. Static
	-- tile centers can leave the low-detail draw radius and expose sky seams.
	local backdrop = part(folder, "ArenaSkyBackdrop", Vector3.new(2048, 1200, 2),
		CFrame.new(origin + Vector3.new(140, 125, -52)), theme.sky)
	local render = { folder = folder, backdrop = backdrop, items = {}, _visuals = {}, _active = {} }
	for _, item in course.items do
		table.insert(render._visuals, { item = item })
	end
	table.sort(render._visuals, function(a, b)
		if a.item.x == b.item.x then return a.item.id < b.item.id end
		return a.item.x < b.item.x
	end)
	-- A small initial set appears synchronously. Remaining nearby objects fill
	-- over the next few preview frames; buildCourse never yields into a race.
	World.updateCourse(render, nil, 0)
	return render
end

function World.updateCourse(render, targetState, elapsed)
	if not render or not render.folder.Parent then return end
	local used = targetState and targetState.used or {}
	local center = targetState and targetState.x or 0
	if render.backdrop then
		render.backdrop.CFrame = CFrame.new(World.COURSE_ORIGIN + Vector3.new(center + 140,
			math.max(125, targetState and targetState.y or 0), -52))
	end
	local low = center - World.ITEM_VIEW_BEHIND
	local high = center + World.ITEM_VIEW_AHEAD
	elapsed = elapsed or 0
	-- Destroying distant/consumed models removes their GUIs and geometry from
	-- rendering work too. Switching pilots may legitimately recreate a pickup
	-- that the newly watched pilot has not consumed.
	for _, visual in pairs(render._active) do
		local item = visual.item
		if item.x < low or item.x > high or used[item.id] then
			retireItem(render, visual)
		elseif item.kind == "missile" then
			local x, y = Simulation.itemPosition(item, elapsed)
			visual.model:PivotTo(CFrame.new(World.COURSE_ORIGIN + Vector3.new(x, y, 0)))
		end
	end
	local missing = {}
	for index = firstItemAt(render._visuals, low), #render._visuals do
		local visual = render._visuals[index]
		local item = visual.item
		if item.x > high then break end
		if not visual.model and not used[item.id] then table.insert(missing, visual) end
	end
	-- Prioritize the immediate route instead of constructing the whole broad
	-- safety margin first, including after an abrupt spectator change.
	local priorityX = center + 110
	table.sort(missing, function(a, b)
		return math.abs(a.item.x - priorityX) < math.abs(b.item.x - priorityX)
	end)
	for index = 1, math.min(World.ITEM_BUILD_BUDGET, #missing) do
		materializeItem(render, missing[index], elapsed)
	end
end

World.EFFECT_POOL_LIMIT = 4

local function hideBurst(slot)
	slot.active = false
	slot.folder:SetAttribute("Active", false)
	slot.core.Transparency = 1
	slot.ringGui.Enabled = false
	slot.captionGui.Enabled = false
	for _, spark in slot.sparks do spark.Transparency = 1 end
	for _, puff in slot.smoke do puff.Transparency = 1 end
end

local function newBurstSlot(model, data)
	if not data.effectFolder then
		local folder = Instance.new("Folder")
		folder.Name = model.Name .. "_FlightBursts"
		folder.Parent = model.Parent
		folder:SetAttribute("PoolLimit", World.EFFECT_POOL_LIMIT)
		folder:SetAttribute("ActiveBurstCount", 0)
		data.effectFolder = folder
		data.bursts = {}
		-- Effects are siblings so anchored impact positions do not follow the
		-- moving plane. Destroying the plane also releases the entire small pool.
		model.Destroying:Connect(function()
			if data.effectFolder then data.effectFolder:Destroy(); data.effectFolder = nil end
		end)
	end
	local folder = Instance.new("Folder")
	folder.Name = "Burst" .. tostring(#data.bursts + 1)
	folder.Parent = data.effectFolder
	local anchor = part(folder, "BurstCenter", Vector3.one, CFrame.identity, COLORS.yellow)
	anchor.Transparency = 1
	local core = part(folder, "BurstCore", Vector3.one, CFrame.identity, COLORS.yellow, Enum.Material.Neon, false, Enum.PartType.Ball)
	local ringGui = Instance.new("BillboardGui")
	ringGui.Name = "Shockwave"
	ringGui.Adornee = anchor
	ringGui.AlwaysOnTop = false
	ringGui.LightInfluence = 0
	ringGui.MaxDistance = 1100
	ringGui.Parent = anchor
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromScale(1, 1)
	ring.Parent = ringGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.4
	stroke.Color = COLORS.yellow
	stroke.Parent = ring
	local captionGui = billboard(anchor, "", COLORS.lime, 0, 90, 45)
	captionGui.Name = "PickupJump"
	captionGui.Size = UDim2.new(25, 0, 13, 0)
	captionGui.MaxDistance = 1100
	local slot = {
		folder = folder, anchor = anchor, core = core, ringGui = ringGui, stroke = stroke,
		captionGui = captionGui, caption = captionGui:FindFirstChildOfClass("TextLabel"),
		sparks = {}, smoke = {}, age = 100, active = false,
	}
	for index = 1, 6 do
		local spark = part(folder, "Spark" .. index, Vector3.new(3, 0.65, 0.65), CFrame.identity, COLORS.yellow, Enum.Material.Neon)
		table.insert(slot.sparks, spark)
	end
	for index = 1, 3 do
		local puff = part(folder, "BurstSmoke" .. index, Vector3.one, CFrame.identity, Color3.fromRGB(76, 78, 99), nil, false, Enum.PartType.Ball)
		table.insert(slot.smoke, puff)
	end
	hideBurst(slot)
	table.insert(data.bursts, slot)
	return slot
end

local function startBurst(model, data, state, event, z, age)
	local isHit = event.kind == "missile" or event.kind == "hit"
	local isPickup = event.kind == "fuel"
	local powerId = POWER_EVENTS[event.kind]
	local isPower = powerId ~= nil or event.kind == "boost" or event.kind == "shield"
	if not (isHit or isPickup or isPower) or age > 0.65 then return end
	local slot
	for _, candidate in data.bursts or {} do
		if not candidate.active then slot = candidate; break end
	end
	if not slot and (not data.bursts or #data.bursts < World.EFFECT_POOL_LIMIT) then
		slot = newBurstSlot(model, data)
	elseif not slot then
		-- Reuse the oldest burst during unusually dense events; no unbounded
		-- Instances, delayed tasks, particles or frame connections accumulate.
		for _, candidate in data.bursts do
			if not slot or candidate.age > slot.age then slot = candidate end
		end
	end
	hideBurst(slot)
	slot.active = true
	slot.age = age
	slot.kind = isHit and "hit" or (powerId and "power" or "pickup")
	slot.eventKind = event.kind
	slot.duration = powerId and 0.94 or (isHit and 0.78 or 0.68)
	slot.origin = World.COURSE_ORIGIN + Vector3.new(event.x or state.x or 0, event.y or state.y or 0, z or 0)
	slot.color = powerId and POWER_COLORS[powerId] or (isHit and COLORS.yellow or (event.kind == "shield" and COLORS.cyan or COLORS.lime))
	slot.folder:SetAttribute("Active", true)
	slot.folder:SetAttribute("EventKind", event.kind)
	slot.folder:SetAttribute("EventSerial", event.serial or 0)
	data.effectFolder:SetAttribute("LastBurstKind", event.kind)
	data.effectFolder:SetAttribute("LastBurstSerial", event.serial or 0)
	slot.anchor.CFrame = CFrame.new(slot.origin)
	slot.ringGui.Enabled = true
	slot.stroke.Color = slot.color
	slot.core.Color = isHit and Color3.fromRGB(255, 173, 74) or slot.color
	for index, spark in slot.sparks do
		spark.Color = index % 2 == 0 and COLORS.coral or slot.color
	end
	if not isHit then
		slot.captionGui.Enabled = true
		local powerWords = { pinball = "BOING!", munch = "CHOMP!", meteorDive = "DIVE!", meteorBoost = "BLAST OFF!" }
		slot.caption.Text = powerWords[event.kind] or (isPickup and ("+" .. tostring(event.value or "")) or string.upper(event.kind))
		slot.caption.TextColor3 = slot.color
		slot.caption.Rotation = powerId and -7 or 0
	end
end

local function updateBursts(data, dt)
	local activeCount = 0
	for _, slot in data.bursts or {} do
		if slot.active then
			slot.age = slot.age + dt
			if slot.age >= slot.duration then
				hideBurst(slot)
			else
				activeCount = activeCount + 1
				local progress = slot.age / slot.duration
				local isHit = slot.kind == "hit"
				local isPower = slot.kind == "power"
				local ringDiameter = (isPower and 12 or (isHit and 8 or 5)) + (isPower and 43 or (isHit and 30 or 22)) * math.sqrt(progress)
				slot.ringGui.Size = UDim2.new(ringDiameter, 0, ringDiameter, 0)
				slot.stroke.Thickness = (isPower and 4 or 2.4) - progress * 1.2
				slot.stroke.Transparency = 0.08 + progress * 0.92
				local flash = math.max(0, 1 - slot.age / (isHit and 0.16 or 0.2))
				local coreSize = (isHit and 6 or 3) + (1 - flash) * (isHit and 8 or 4)
				slot.core.Size = Vector3.new(coreSize, coreSize, coreSize)
				slot.core.CFrame = CFrame.new(slot.origin)
				slot.core.Transparency = flash > 0 and (0.34 + (1 - flash) * 0.66) or 1
				if isHit or isPower then
					for index, spark in slot.sparks do
						local angle = (index - 1) * math.pi / 3 + 0.24
						if slot.eventKind == "meteorBoost" then angle = angle * 0.45 end
						local radius = 4 + progress * (isPower and 32 or 22)
						local point = slot.origin + Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius - slot.age * slot.age * 10, 1)
						spark.CFrame = CFrame.new(point) * CFrame.Angles(0, 0, angle)
						spark.Size = Vector3.new(1.2 + (1 - progress) * (isPower and 6 or 3.8), isPower and 1 or 0.65, 0.65)
						spark.Transparency = 0.1 + progress * 0.9
					end
				end
				if isHit then
					for index, puff in slot.smoke do
						local smokeAge = math.max(0, slot.age - 0.08)
						local diameter = 3 + smokeAge * 11
						puff.Size = Vector3.new(diameter, diameter, diameter)
						puff.CFrame = CFrame.new(slot.origin + Vector3.new((index - 2) * (3 + smokeAge * 6), 2 + smokeAge * 13, -1))
						puff.Transparency = 0.48 + progress * 0.52
					end
				else
					local jump = math.sin(math.min(1, progress * 1.6) * math.pi / 2)
					slot.captionGui.StudsOffset = Vector3.new(0, (isPower and 24 or 13) * jump, 0)
					slot.captionGui.Size = isPower and UDim2.new(52 + 8 * jump, 0, 15 + 3 * jump, 0)
						or UDim2.new(25 + 4 * jump, 0, 13 + 2 * jump, 0)
					slot.caption.TextTransparency = progress * progress
					slot.caption.TextStrokeTransparency = progress * progress
				end
			end
		end
	end
	if data.effectFolder and activeCount ~= data.activeBurstCount then
		data.activeBurstCount = activeCount
		data.effectFolder:SetAttribute("ActiveBurstCount", activeCount)
	end
end

local function acceptPlaneEvent(data, state, event, model, z)
	if not event then return end
	local age = (state.elapsed or 0) - (event.at or -100)
	if age < 0 then return end
	local serial = event.serial
	if type(serial) == "number" then
		if serial <= data.lastEventSerial then return end
		data.lastEventSerial = serial
	else
		local key = tostring(event.kind) .. ":" .. tostring(event.at)
		if key == data.lastEventKey then return end
		data.lastEventKey = key
	end
	if age > 1.1 then return end
	startBurst(model, data, state, event, z, age)
	if POWER_EVENTS[event.kind] then
		data.powerAge, data.powerKind = age, event.kind
		if event.kind ~= "meteorDive" then data.boostAge = age end
	end
	if event.kind == "missile" or event.kind == "hit" then
		data.hitAge = age
	elseif event.kind == "fuel" or event.kind == "boost" or event.kind == "shield" then
		data.boostAge = age
	elseif event.kind == "nearMiss" then
		data.nearMissAge = age
	end
end

function World.updatePlane(model, state, z, dt)
	if not model or not model.Parent or not state then return end
	local data = planeData[model]
	local frameTime = math.clamp(dt or 1 / 60, 0, 1)
	local scale = model:GetScale()
	if data then
		local trailId = state.trailId or (state.settings and state.settings.trailId)
		if trailId or not data.normalTrail then World.applyCosmeticTrail(model, trailId) end
		ensurePowerVisual(model, data, state.powerId or (state.settings and state.settings.powerId))
		-- Effects age on render time after acceptance, so touchdown or a newer
		-- near miss cannot leave a fire frozen or prematurely erase a hit.
		data.hitAge = data.hitAge + frameTime
		data.boostAge = data.boostAge + frameTime
		data.nearMissAge = data.nearMissAge + frameTime
		data.powerAge = data.powerAge + frameTime
		for _, event in state.recentEvents or {} do acceptPlaneEvent(data, state, event, model, z) end
		acceptPlaneEvent(data, state, state.lastEvent, model, z)
		updateBursts(data, frameTime)
	end
	local maxPitch = math.rad(60)
	local dive = data and data.powerId == "Meteor" and state.powerPhase == "diving"
	local minPitch = dive and -1.35 or -0.8
	local pitch = math.clamp(math.atan2(state.vy or 0, math.max(1, state.vx or 1)), minPitch, maxPitch)
	local y = state.y or 10
	local hitKick = data and math.max(0, 1 - data.hitAge / 0.48) or 0
	local boostKick = data and math.max(0, 1 - data.boostAge / 0.58) or 0
	pitch = math.clamp(pitch - hitKick * 0.24 + boostKick * 0.14, dive and minPitch or -1, maxPitch)
	if state.alive == false and state.finishReason == "landed" then
		pitch = 0
		y = math.max(y, 1.6 * scale)
	end
	local pose = CFrame.new(World.COURSE_ORIGIN + Vector3.new(state.x or 0, y, z or 0)) * CFrame.Angles(0, 0, pitch)
	model:PivotTo(pose)
	if data then
		data.phase = (data.phase + frameTime * 40) % (math.pi * 2)
		data.propeller:PivotTo(pose * CFrame.new(5.1 * scale, 0, 0) * CFrame.Angles(data.phase, 0, 0))
		data.trail.Enabled = (state.vx or 0) > 1 and state.alive ~= false
		local boost = math.max(0, 1 - data.boostAge / 0.8)
		local fire = math.max(0, 1 - data.hitAge / 0.52)
		local nearMiss = math.max(0, 1 - data.nearMissAge / 0.38)
		local meteor = data.powerId == "Meteor" and (dive and 1 or (data.powerKind == "meteorBoost" and math.max(0, 1 - data.powerAge / 0.8) or 0)) or 0
		local envelope = math.max(boost, fire, meteor)
		if envelope > 0 then
			data.flare.Color = meteor > 0 and COLORS.coral or (fire > 0 and Color3.fromRGB(255, 143, 62) or (data.powerId == "Pinball" and COLORS.yellow or COLORS.lime))
			data.flare.Size = Vector3.new(4.5 + envelope * 3.5, 0.9 + envelope, 0.9 + envelope) * scale
			data.flare.CFrame = pose * CFrame.new(-6.3 * scale, 0, 0)
			data.flare.Transparency = 0.12 + (1 - envelope) * 0.8
		else
			data.flare.Transparency = 1
		end
		for index, puff in data.smoke do
			local puffAge = data.hitAge - (index - 1) * 0.13
			if puffAge >= 0 and puffAge < 0.85 then
				local progress = puffAge / 0.85
				local diameter = (0.9 + progress * 1.8) * scale
				puff.Size = Vector3.new(diameter, diameter, diameter)
				puff.CFrame = pose * CFrame.new((-6.5 - progress * 11) * scale, (0.4 + progress * 3.7) * scale, ((index % 2) * 0.35 - 0.15) * scale)
				puff.Transparency = 0.34 + progress * 0.66
			else
				puff.Transparency = 1
			end
		end
		if data.hitAge < 0.13 then
			data.body.Color = COLORS.cream
		elseif boost > 0 then
			data.body.Color = data.color:Lerp(COLORS.lime, boost * 0.65)
		elseif nearMiss > 0 then
			data.body.Color = data.color:Lerp(COLORS.yellow, nearMiss * 0.55)
		else
			data.body.Color = data.color
		end
		local trailMode = meteor > 0 and "meteor" or (boost > 0 and "boost" or (data.hitAge < 0.9 and "hit" or "normal"))
		if trailMode ~= data.trailMode then
			data.trailMode = trailMode
			if trailMode == "normal" then
				restoreNormalTrail(data)
			else
				data.trail.Color = data.trailColors[trailMode]
				data.trail.Lifetime = trailMode == "meteor" and 0.65 or 0.35
				data.trail.LightEmission = 0.6
				data.trail.WidthScale = NumberSequence.new(1)
			end
		end
		updatePowerVisual(model, data, state, pose, scale)
	end
end

function World.destroyCourse(render)
	if render and render.folder then
		render.folder:Destroy()
	end
end

return World
