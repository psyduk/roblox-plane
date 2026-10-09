--!nonstrict
-- Original, asset-free arcade scenery. Gameplay decisions live in Simulation.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Simulation = require(script.Parent.Simulation)
local PlaneCatalog = require(script.Parent.PlaneCatalog)

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
	Hub = {
		clock = 14, brightness = 1.7, exposure = -0.2,
		ambient = Color3.fromRGB(80, 85, 100), outdoor = Color3.fromRGB(100, 105, 120),
		tint = Color3.new(1, 1, 1), saturation = 0, contrast = 0,
		fog = Color3.fromRGB(190, 216, 236),
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
	correction.Enabled = theme ~= THEMES.Hub
	correction.TintColor = theme.tint
	correction.Saturation = theme.saturation
	correction.Contrast = theme.contrast
	correction.Brightness = 0
end

function World.resetTheme()
	World.setArenaTheme("Hub")
end

World.LOBBY_SPAWN = Vector3.new(0, 7, 62)
World.COURSE_ORIGIN = Vector3.new(0, 0, -5000)
World.LOBBY_CAMERA = {
	position = Vector3.new(16, 25, 86),
	lookAt = Vector3.new(0, 8, 62),
}
World.DUEL_STATIONS = {}
for index, x in { -81, -27, 27, 81 } do
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

local function rail(parent, name, position, size)
	part(parent, name .. "Barrier", size, CFrame.new(position), COLORS.cyan, Enum.Material.SmoothPlastic, true).Transparency = 0.76
	part(parent, name .. "Top", Vector3.new(size.X, 0.35, size.Z), CFrame.new(position + Vector3.new(0, size.Y / 2, 0)), COLORS.cyan, Enum.Material.Neon)
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
		flare = flare, trail = trail, smoke = smoke,
		hitAge = 100, boostAge = 100, nearMissAge = 100, lastEventSerial = -1,
		trailMode = "normal", trailColors = {
			normal = trail.Color,
			boost = ColorSequence.new(COLORS.lime, COLORS.cream),
			hit = ColorSequence.new(Color3.fromRGB(104, 101, 110), COLORS.cream),
		},
	}
	model:ScaleTo(3.1)
	return model
end

function World.createPlane(parent, name, colorIndex, planeId)
	return makePlane(parent, name, colorIndex, planeId)
end

-- Base-scale pilot HumanoidRootPart pose. Roblox avatars face local -Z, so
-- rotate them toward the aircraft's +X nose; getCockpitCFrame scales position.
World.COCKPIT_OFFSET = CFrame.new(0.5, 2.1, 0) * CFrame.Angles(0, -math.pi / 2, 0)
function World.getCockpitCFrame(model)
	local scale = model:GetScale()
	return model:GetPivot() * CFrame.new(0.5 * scale, 2.1 * scale, 0) * CFrame.Angles(0, -math.pi / 2, 0)
end

local function planter(parent, position, size)
	part(parent, "PlanterBase", size, CFrame.new(position), COLORS.navy, nil, true)
	part(parent, "PlanterGrass", Vector3.new(size.X - 1, 0.4, size.Z - 1), CFrame.new(position + Vector3.new(0, size.Y / 2 + 0.1, 0)), Color3.fromRGB(127, 202, 114))
	local top = position.Y + size.Y / 2
	part(parent, "Topiary", Vector3.new(size.X * 0.75, 5, size.Z * 0.75), CFrame.new(position.X, top + 2, position.Z), Color3.fromRGB(66, 153, 111), nil, false, Enum.PartType.Ball)
end

local function bench(parent, position, rotation)
	local pose = CFrame.new(position) * CFrame.Angles(0, rotation or 0, 0)
	part(parent, "BenchSeat", Vector3.new(12, 0.8, 4), pose, COLORS.cream, nil, true)
	part(parent, "BenchBack", Vector3.new(12, 3.5, 0.6), pose * CFrame.new(0, 1.4, 1.7), COLORS.coral, nil, true)
	for _, x in { -4, 4 } do
		part(parent, "BenchLeg", Vector3.new(1, 2, 3), pose * CFrame.new(x, -1.2, 0), COLORS.navy, nil, true)
	end
end

function World.buildLobby()
	-- Set the same arcade palette in an imported Studio place and a fresh build.
	Lighting.ClockTime = 14
	Lighting.Brightness = 1.7
	Lighting.Ambient = Color3.fromRGB(80, 85, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(100, 105, 120)
	Lighting.ExposureCompensation = -0.2
	local existing = Workspace:FindFirstChild("FlightLobby")
	if existing then existing:Destroy() end
	queueLabels = {}
	local lobby = Instance.new("Folder")
	lobby.Name = "FlightLobby"
	lobby.Parent = Workspace
	-- A walkable social plaza. Matches render in a separate client-only location.
	part(lobby, "Landscape", Vector3.new(900, 8, 900), CFrame.new(0, -6, 0), Color3.fromRGB(113, 184, 103), nil, true)
	part(lobby, "Foundation", Vector3.new(254, 8, 204), CFrame.new(0, -2, 0), COLORS.navy, nil, true)
	part(lobby, "Concourse", Vector3.new(250, 2, 200), CFrame.new(0, 3, 0), Color3.fromRGB(221, 214, 198), nil, true)
	part(lobby, "MainPromenade", Vector3.new(232, 0.12, 22), CFrame.new(0, 4.08, 0), Color3.fromRGB(177, 207, 193))
	part(lobby, "CenterPromenade", Vector3.new(22, 0.12, 169), CFrame.new(0, 4.09, -4), Color3.fromRGB(177, 207, 193))
	for _, z in { -98.5, 98.5 } do
		rail(lobby, "Perimeter", Vector3.new(0, 6.1, z), Vector3.new(248, 4, 0.7))
	end
	for _, x in { -123.5, 123.5 } do
		rail(lobby, "Perimeter", Vector3.new(x, 6.1, 0), Vector3.new(0.7, 4, 197))
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
	for _, x in { -116, 116 } do
		for _, z in { -87, 85 } do
			part(lobby, "LightColumn", Vector3.new(1.5, 22, 1.5), CFrame.new(x, 15, z), COLORS.navy, nil, true)
			part(lobby, "LightCap", Vector3.new(5, 2, 5), CFrame.new(x, 27, z), COLORS.cyan, Enum.Material.Neon)
		end
	end
	for _, x in { -50, 50 } do
		part(lobby, "ClubSignPost", Vector3.new(3, 35, 3), CFrame.new(x, 21.5, -88), COLORS.navy, nil, true)
	end
	sign(lobby, "ClubSign", Vector3.new(0, 33, -88), Vector3.new(96, 18, 1.5), "SKYBOUND", "F L I G H T   C L U B", COLORS.cyan, math.pi)
	sign(lobby, "QueueInstructions", Vector3.new(0, 16, -88), Vector3.new(87, 9, 1), "PICK A PARTNER. CLAIM A PAD.", "1v1 FLIGHTS  /  FURTHEST DISTANCE WINS", COLORS.coral, math.pi)
	for index, station in World.DUEL_STATIONS do
		local x = (station.seats[1].X + station.seats[2].X) / 2
		local accent = PLANE_COLORS[index]
		part(lobby, "QueueApproach", Vector3.new(32, 0.13, 36), CFrame.new(x, 4.08, -28), Color3.fromRGB(177, 207, 193))
		part(lobby, "QueueBase", Vector3.new(38, 0.3, 22), CFrame.new(x, 4.15, -47), COLORS.navy)
		for seatIndex, seat in station.seats do
			local pad = part(lobby, station.id .. "Pad" .. seatIndex, Vector3.new(12, 0.3, 12), CFrame.new(seat), accent, nil, true)
			local inset = part(lobby, "PadInset", Vector3.new(10.4, 0.08, 10.4), CFrame.new(seat + Vector3.new(0, 0.19, 0)), COLORS.navy)
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Top
			gui.CanvasSize = Vector2.new(300, 300)
			gui.LightInfluence = 0
			gui.Parent = inset
			textLabel(gui, tostring(seatIndex), UDim2.fromScale(0.12, 0.12), UDim2.fromScale(0.76, 0.76), COLORS.cream)
		end
		for _, offset in { -20, 20 } do
			part(lobby, "QueueArchPost", Vector3.new(1.5, 17, 1.5), CFrame.new(x + offset, 12.5, -60), COLORS.navy, nil, true)
		end
		part(lobby, "QueueArch", Vector3.new(42, 1.5, 2), CFrame.new(x, 21, -60), accent, Enum.Material.Neon)
		local display = part(lobby, station.id .. "Display", Vector3.new(30, 9, 1), CFrame.new(x, 16, -60) * CFrame.Angles(0, math.pi, 0), COLORS.navy)
		local gui = surface(display, station.name, "0 / 2 READY", accent)
		queueLabels[station.id] = gui:FindFirstChild("Subtitle")
	end
	-- The fleet uses the same models as flight selection, with room to walk.
	part(lobby, "HangarFloor", Vector3.new(69, 0.4, 70), CFrame.new(-80, 4.25, 45), COLORS.navy)
	for _, x in { -115, -45 } do
		for _, z in { 12, 80 } do
			part(lobby, "HangarPillar", Vector3.new(2.5, 25, 2.5), CFrame.new(x, 16.5, z), COLORS.navy, nil, true)
		end
	end
	part(lobby, "HangarCanopy", Vector3.new(74, 2, 17), CFrame.new(-80, 29, 72), COLORS.cyan, nil, true)
	sign(lobby, "HangarTitle", Vector3.new(-80, 25, 79), Vector3.new(64, 10, 1), "PICK YOUR PLANE", "THREE FREE PLANES. THREE FLIGHT STYLES.", COLORS.yellow)
	local exhibitPlaces = { Vector3.new(-98, 9, 28), Vector3.new(-62, 9, 28), Vector3.new(-80, 9, 60) }
	for index, planeId in PlaneCatalog.ORDER do
		local position = exhibitPlaces[index]
		local entry = PlaneCatalog.get(planeId)
		part(lobby, "ExhibitPlinth", Vector3.new(26, 1.7, 23), CFrame.new(position.X, 5.25, position.Z), COLORS.cream, nil, true)
		part(lobby, "ExhibitAccent", Vector3.new(26, 0.15, 23), CFrame.new(position.X, 6.2, position.Z), PLANE_COLORS[index], Enum.Material.Neon)
		local plane = makePlane(lobby, "ShowroomPlane" .. index, index, planeId)
		plane:ScaleTo(1.4)
		plane:PivotTo(CFrame.new(position) * CFrame.Angles(0, -0.55, 0))
		sign(lobby, "FleetLabel" .. index, Vector3.new(position.X, 7.3, position.Z - 12), Vector3.new(25, 4.7, 0.5), string.upper(entry.name), "SELECT BEFORE TAKEOFF", PLANE_COLORS[index])
	end
	-- Central green, social seating and an original plane sculpture.
	planter(lobby, Vector3.new(0, 6, 37), Vector3.new(29, 4, 26))
	local statue = makePlane(lobby, "ClubMascot", 2)
	statue:ScaleTo(2.05)
	statue:PivotTo(CFrame.new(0, 16, 37) * CFrame.Angles(0, -0.5, 0.16))
	for _, x in { -28, 28 } do bench(lobby, Vector3.new(x, 6.5, 38), x < 0 and math.pi / 2 or -math.pi / 2) end
	for _, position in { Vector3.new(-30, 5.5, 74), Vector3.new(30, 5.5, 74), Vector3.new(-114, 5.5, -20), Vector3.new(114, 5.5, -20) } do
		planter(lobby, position, Vector3.new(10, 3, 12))
	end
	-- Winner podiums, gift-shaped cosmetic exhibits and a club information wall.
	part(lobby, "WinnersPlaza", Vector3.new(66, 0.3, 70), CFrame.new(81, 4.2, 45), Color3.fromRGB(227, 218, 204))
	for index, data in { { -17, 3, "2" }, { 0, 5.5, "1" }, { 17, 2, "3" } } do
		local height = data[2]
		local base = part(lobby, "Podium" .. data[3], Vector3.new(14, height, 14), CFrame.new(81 + data[1], 4 + height / 2, 34), index == 2 and COLORS.yellow or COLORS.navy, nil, true)
		billboard(base, data[3], COLORS.cream, height / 2 + 2, 45, 45)
	end
	sign(lobby, "WinnersTitle", Vector3.new(81, 24, 78), Vector3.new(65, 12, 1), "WINNER'S CIRCLE", "MAKE YOUR NEXT FLIGHT YOUR BEST", COLORS.coral)
	for index, x in { 61, 81, 101 } do
		part(lobby, "ColorCrate", Vector3.new(11, 8, 11), CFrame.new(x, 8.5, 64), PLANE_COLORS[index], nil, true)
		part(lobby, "CrateBand", Vector3.new(11.2, 1.8, 11.2), CFrame.new(x, 10, 64), COLORS.navy)
		part(lobby, "CrateTop", Vector3.new(11.5, 0.7, 11.5), CFrame.new(x, 12.9, 64), COLORS.cream)
	end
	sign(lobby, "HowToPlay", Vector3.new(0, 17, 91), Vector3.new(72, 12, 1), "GOOD COMPANY. GREAT FLIGHTS.", "CLAIM A PAD  /  SET YOUR PLANE  /  WATCH IT FLY", COLORS.cyan)
	World.updateLobbyQueues({})
	return lobby
end

function World.updateLobbyQueues(queueCounts)
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
	local isPower = event.kind == "boost" or event.kind == "shield"
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
	slot.kind = isHit and "hit" or "pickup"
	slot.duration = isHit and 0.78 or 0.68
	slot.origin = World.COURSE_ORIGIN + Vector3.new(event.x or state.x or 0, event.y or state.y or 0, z or 0)
	slot.color = isHit and COLORS.yellow or (event.kind == "shield" and COLORS.cyan or COLORS.lime)
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
		slot.caption.Text = isPickup and ("+" .. tostring(event.value or "")) or string.upper(event.kind)
		slot.caption.TextColor3 = slot.color
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
				local ringDiameter = (isHit and 8 or 5) + (isHit and 30 or 22) * math.sqrt(progress)
				slot.ringGui.Size = UDim2.new(ringDiameter, 0, ringDiameter, 0)
				slot.stroke.Thickness = 2.4 - progress * 1.2
				slot.stroke.Transparency = 0.08 + progress * 0.92
				local flash = math.max(0, 1 - slot.age / (isHit and 0.16 or 0.2))
				local coreSize = (isHit and 6 or 3) + (1 - flash) * (isHit and 8 or 4)
				slot.core.Size = Vector3.new(coreSize, coreSize, coreSize)
				slot.core.CFrame = CFrame.new(slot.origin)
				slot.core.Transparency = flash > 0 and (0.34 + (1 - flash) * 0.66) or 1
				if isHit then
					for index, spark in slot.sparks do
						local angle = (index - 1) * math.pi / 3 + 0.24
						local radius = 4 + progress * 22
						local point = slot.origin + Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius - slot.age * slot.age * 10, 1)
						spark.CFrame = CFrame.new(point) * CFrame.Angles(0, 0, angle)
						spark.Size = Vector3.new(1.2 + (1 - progress) * 3.8, 0.65, 0.65)
						spark.Transparency = 0.1 + progress * 0.9
					end
					for index, puff in slot.smoke do
						local smokeAge = math.max(0, slot.age - 0.08)
						local diameter = 3 + smokeAge * 11
						puff.Size = Vector3.new(diameter, diameter, diameter)
						puff.CFrame = CFrame.new(slot.origin + Vector3.new((index - 2) * (3 + smokeAge * 6), 2 + smokeAge * 13, -1))
						puff.Transparency = 0.48 + progress * 0.52
					end
				else
					local jump = math.sin(math.min(1, progress * 1.6) * math.pi / 2)
					slot.captionGui.StudsOffset = Vector3.new(0, 13 * jump, 0)
					slot.captionGui.Size = UDim2.new(25 + 4 * jump, 0, 13 + 2 * jump, 0)
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
		-- Effects age on render time after acceptance, so touchdown or a newer
		-- near miss cannot leave a fire frozen or prematurely erase a hit.
		data.hitAge = data.hitAge + frameTime
		data.boostAge = data.boostAge + frameTime
		data.nearMissAge = data.nearMissAge + frameTime
		for _, event in state.recentEvents or {} do acceptPlaneEvent(data, state, event, model, z) end
		acceptPlaneEvent(data, state, state.lastEvent, model, z)
		updateBursts(data, frameTime)
	end
	local maxPitch = math.rad(60)
	local pitch = math.clamp(math.atan2(state.vy or 0, math.max(1, state.vx or 1)), -0.8, maxPitch)
	local y = state.y or 10
	local hitKick = data and math.max(0, 1 - data.hitAge / 0.48) or 0
	local boostKick = data and math.max(0, 1 - data.boostAge / 0.58) or 0
	pitch = math.clamp(pitch - hitKick * 0.24 + boostKick * 0.14, -1, maxPitch)
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
		local envelope = math.max(boost, fire)
		if envelope > 0 then
			data.flare.Color = fire > 0 and Color3.fromRGB(255, 143, 62) or COLORS.lime
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
		local trailMode = boost > 0 and "boost" or (data.hitAge < 0.9 and "hit" or "normal")
		if trailMode ~= data.trailMode then
			data.trailMode = trailMode
			data.trail.Color = data.trailColors[trailMode]
		end
	end
end

function World.destroyCourse(render)
	if render and render.folder then
		render.folder:Destroy()
	end
end

return World
