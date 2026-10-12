--!nonstrict
-- Local presentation for Sky Battle: two spinning tops in a walled stadium in
-- the sky. The simulation owns every hit and outcome; this file only draws
-- what the latest snapshot says. The caller owns the render connection and
-- must skip its normal camera while calling update. viewportRect uses
-- Camera.ViewportSize pixel coordinates.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local BattleView = {}
BattleView.__index = BattleView

-- The platform's top surface sits at ORIGIN. Simulation x runs across the
-- screen and simulation y runs toward the camera.
local ORIGIN = Vector3.new(0, 80, -4000)
local RING = 24
-- The gaps in the wall, matching BattleSimulation: their middles and half-width.
local GAPS = { math.pi / 2, math.pi * 7 / 6, math.pi * 11 / 6 }
local GAP_HALF = 0.2
local WALL_HEIGHT = 2.6
local COLORS = {
	coral = Color3.fromRGB(255, 104, 102), cyan = Color3.fromRGB(66, 225, 239),
	cream = Color3.fromRGB(255, 245, 217), yellow = Color3.fromRGB(255, 212, 80),
	fire = Color3.fromRGB(255, 145, 54), purple = Color3.fromRGB(184, 138, 255),
	ink = Color3.fromRGB(14, 22, 44), steel = Color3.fromRGB(168, 176, 188),
	gunmetal = Color3.fromRGB(70, 78, 92), rubber = Color3.fromRGB(28, 30, 36),
	deck = Color3.fromRGB(36, 44, 62), deckLight = Color3.fromRGB(58, 70, 96),
	danger = Color3.fromRGB(214, 70, 78), gold = Color3.fromRGB(214, 176, 84),
	skyTop = Color3.fromRGB(30, 78, 186), skyMid = Color3.fromRGB(78, 158, 236),
	horizon = Color3.fromRGB(255, 216, 176), cloud = Color3.fromRGB(255, 247, 232),
	cloudShade = Color3.fromRGB(255, 205, 196), lime = Color3.fromRGB(196, 255, 91),
	claw = Color3.fromRGB(96, 230, 170), jet = Color3.fromRGB(120, 200, 255),
}
-- Same order as the hangar's paint swatch, so a pilot's paint carries over.
local PAINTS = { COLORS.coral, COLORS.cyan, COLORS.yellow, COLORS.purple }
local PARKED = CFrame.new(0, -2000, 0)
local ELEVATION = math.rad(42)
local CAMERA_DISTANCE = 190
local GRAVITY = 110
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local RING_POOL, WORD_POOL = 6, 3
local WALL_SEGMENTS = 72

local function part(parent, name, size, pose, color, material, shape)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = pose
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.Anchored = true
	object.CanCollide = false
	object.CanTouch = false
	object.CanQuery = false
	object.CastShadow = false
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	if shape then object.Shape = shape end
	object.Parent = parent
	return object
end

-- A flat disc lying on the platform: `y` is the height of its middle.
local function discPose(x, y, z)
	return CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
end

local function disc(parent, name, radius, height, y, color, material)
	return part(parent, name, Vector3.new(height, radius * 2, radius * 2), discPose(0, y, 0), color, material, Enum.PartType.Cylinder)
end

local function ellipsoid(parent, name, size, pose, color, material)
	local object = part(parent, name, size, pose, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = object
	return object
end

local function numeric(value, fallback)
	return type(value) == "number" and value == value and math.abs(value) < 1e7 and value or fallback
end

local function worldPoint(x, y, height)
	return ORIGIN + Vector3.new(x, height or 0, y)
end

local function emitter(parent, name, texture, properties)
	local object = Instance.new("ParticleEmitter")
	object.Name = name
	object.Texture = texture
	object.Enabled = false
	object.Rate = 0
	object.LightInfluence = 0
	object.SpreadAngle = Vector2.new(180, 180)
	for key, value in pairs(properties) do object[key] = value end
	object.Parent = parent
	return object
end

local function fade(from, to)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, to) })
end

local function makeSky(scenery)
	-- A painted late-afternoon sky behind a cloud sea the platform floats above.
	local sky = part(scenery, "Sky", Vector3.new(2400, 1500, 4), CFrame.new(ORIGIN + Vector3.new(0, 120, -420)), COLORS.skyMid)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0
	gui.CanvasSize = Vector2.new(64, 256)
	gui.Parent = sky
	local wash = Instance.new("Frame")
	wash.Size = UDim2.fromScale(1, 1)
	wash.BorderSizePixel = 0
	wash.BackgroundColor3 = Color3.new(1, 1, 1)
	wash.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.skyTop), ColorSequenceKeypoint.new(0.5, COLORS.skyMid),
		ColorSequenceKeypoint.new(0.72, COLORS.horizon), ColorSequenceKeypoint.new(1, COLORS.cloudShade),
	})
	gradient.Parent = wash
	-- The camera looks down, so most of what it sees behind the platform is
	-- this floor of soft cloud far below.
	part(scenery, "CloudFloor", Vector3.new(2400, 2, 1400), CFrame.new(ORIGIN + Vector3.new(0, -150, -120)), COLORS.skyMid)
	local clouds = {}
	local seed = 11
	local function roll()
		seed = (seed * 16807) % 2147483647
		return (seed - 1) / 2147483646
	end
	for index = 1, 14 do
		local size = 26 + roll() * 34
		local x, y, z = (roll() * 2 - 1) * 330, -90 - roll() * 50, -260 + roll() * 330
		-- Keep the air round and under the stadium clear, so it stands alone
		-- against the sky and tops fall into nothing.
		if math.abs(x) < 130 and math.abs(z) < 150 then x = x + (x < 0 and -150 or 150) end
		local model = Instance.new("Model")
		model.Name = "Cloud"
		model.Parent = scenery
		local core = ellipsoid(model, "Puff", Vector3.new(size * 2.2, size * 0.7, size * 1.3), CFrame.new(ORIGIN + Vector3.new(x, y, z)), COLORS.cloud)
		model.PrimaryPart = core
		ellipsoid(model, "Puff", Vector3.new(size * 1.3, size * 0.85, size), CFrame.new(ORIGIN + Vector3.new(x - size * 0.45, y + size * 0.2, z + 2)), COLORS.cloud)
		ellipsoid(model, "Puff", Vector3.new(size * 1.1, size * 0.7, size * 0.9), CFrame.new(ORIGIN + Vector3.new(x + size * 0.5, y + size * 0.12, z - 2)), COLORS.cloud)
		clouds[index] = { model = model, x = x, y = y, z = z, drift = 1 + roll() * 2.5 }
	end
	return clouds
end

local function inGap(angle)
	for _, middle in ipairs(GAPS) do
		if math.abs((angle - middle + math.pi) % (2 * math.pi) - math.pi) < GAP_HALF then return true end
	end
	return false
end

-- The stadium: a dark dish with a low wall round it, broken by three exits.
local function makeStadium(parent)
	local scenery = Instance.new("Folder")
	scenery.Name = "Stadium"
	scenery.Parent = parent
	local clouds = makeSky(scenery)
	local function layer(name, radius, height, y, color, material)
		local object = disc(scenery, name, radius, height, 0, color, material)
		object.CFrame = discPose(ORIGIN.X, ORIGIN.Y + y, ORIGIN.Z)
		return object
	end
	-- The outer tray is where a knocked-out top lands before it drops away.
	layer("Tray", RING + 5, 1.4, -2.2, COLORS.gunmetal, Enum.Material.Metal)
	layer("Deck", RING, 2.4, -1.2, COLORS.deck)
	local sheen = layer("DeckSheen", RING - 0.4, 0.1, 0.02, COLORS.deckLight, Enum.Material.Glass)
	sheen.Transparency, sheen.Reflectance = 0.55, 0.25
	-- Faint rings give the eye something to judge distance from the middle by.
	for index, fraction in ipairs({ 0.72, 0.44 }) do
		layer("Ring" .. index, RING * fraction, 0.1, 0.05 + index * 0.02, COLORS.deckLight)
		layer("RingFill" .. index, RING * fraction - 0.45, 0.1, 0.06 + index * 0.02, COLORS.deck)
	end
	local mark = layer("CentreMark", RING * 0.1, 0.1, 0.12, COLORS.steel, Enum.Material.Metal)
	mark.Reflectance = 0.3
	layer("Keel", RING * 0.75, 9, -7.4, COLORS.ink)
	layer("KeelTip", RING * 0.4, 9, -15.4, COLORS.ink)
	-- The wall is a ring of short straight pieces; the ones in front of a gap
	-- are left out, and the deck there is painted as an exit.
	local step = math.pi * 2 / WALL_SEGMENTS
	local length = 2 * (RING + 0.6) * math.tan(step / 2) + 0.05
	for index = 0, WALL_SEGMENTS - 1 do
		local angle = (index + 0.5) * step
		local centre = ORIGIN + Vector3.new(math.cos(angle) * (RING + 0.6), 0, math.sin(angle) * (RING + 0.6))
		local pose = CFrame.lookAt(centre, Vector3.new(ORIGIN.X, centre.Y, ORIGIN.Z))
		if inGap(angle) then
			part(scenery, "Exit", Vector3.new(length, 0.12, 2.6), pose * CFrame.new(0, 0.08, 0.6), COLORS.danger)
		else
			local wall = part(scenery, "Wall", Vector3.new(length, WALL_HEIGHT, 1.2), pose * CFrame.new(0, WALL_HEIGHT / 2, 0), COLORS.steel, Enum.Material.Metal)
			wall.Reflectance = 0.2
			part(scenery, "WallCap", Vector3.new(length, 0.25, 1.4), pose * CFrame.new(0, WALL_HEIGHT + 0.12, 0), COLORS.cream, Enum.Material.Metal).Reflectance = 0.3
		end
	end
	-- A post at each side of every exit, lit so the gaps read from any angle.
	for _, middle in ipairs(GAPS) do
		for _, side in ipairs({ -1, 1 }) do
			local angle = middle + side * (GAP_HALF + step * 0.2)
			part(scenery, "ExitPost", Vector3.new(1.3, WALL_HEIGHT + 0.8, 1.3),
				CFrame.new(ORIGIN + Vector3.new(math.cos(angle) * (RING + 0.6), (WALL_HEIGHT + 0.8) / 2, math.sin(angle) * (RING + 0.6))), COLORS.danger, Enum.Material.Neon)
		end
	end
	local lamp = Instance.new("PointLight")
	lamp.Color, lamp.Brightness, lamp.Range, lamp.Shadows = COLORS.cream, 0.6, 60, false
	lamp.Parent = mark
	return scenery, clouds
end

function BattleView.new(World, onPresentationCue, options)
	local self = setmetatable({
		World = World, fighters = {}, roundId = nil, lastEvent = 0, clock = 0, realClock = 0,
		sampleElapsed = nil, sampleAge = 0, destroyed = false,
		shake = 0, punch = 0, screenFlash = 0, hype = 0, ringCursor = 0, wordCursor = 0,
		onPresentationCue = type(onPresentationCue) == "function" and onPresentationCue or nil,
		-- SkillCatalog, for the words a top shouts. Optional in tests.
		skills = type(options) == "table" and options.skills or nil,
	}, BattleView)
	pcall(function() self.reducedMotion = GuiService.ReducedMotionEnabled end)
	self.folder = Instance.new("Folder")
	self.folder.Name = "SkyboundBattleView"
	self.folder.Parent = Workspace
	self.scenery, self.clouds = makeStadium(self.folder)
	-- Glow and grade belong to this view and leave with it.
	self.bloom = Instance.new("BloomEffect")
	self.bloom.Name = "SkyboundBattleBloom"
	self.bloom.Intensity, self.bloom.Size, self.bloom.Threshold = 0.3, 18, 1.4
	self.bloom.Parent = Lighting
	self.grade = Instance.new("ColorCorrectionEffect")
	self.grade.Name = "SkyboundBattleGrade"
	self.grade.Saturation, self.grade.Contrast = 0.02, 0.1
	self.grade.Parent = Lighting
	self.groundY = ORIGIN.Y
	self.folder:SetAttribute("GroundY", self.groundY)
	self.dynamic = Instance.new("Folder")
	self.dynamic.Name = "Combat"
	self.dynamic.Parent = self.folder
	-- One anchor carries every burst of sparks; it is moved, then told to emit.
	self.fxAnchor = part(self.dynamic, "ParticleAnchor", Vector3.one, CFrame.new(ORIGIN), COLORS.cream)
	self.fxAnchor.Transparency = 1
	self.sparks = emitter(self.fxAnchor, "Sparks", SPARK_TEXTURE, {
		Lifetime = NumberRange.new(0.15, 0.4), Speed = NumberRange.new(20, 52), Size = fade(0.9, 0),
		LightEmission = 1, Drag = 3, Acceleration = Vector3.new(0, -30, 0),
	})
	self.smoke = emitter(self.fxAnchor, "Dust", SMOKE_TEXTURE, {
		Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(6, 16), Size = fade(3, 7),
		Transparency = fade(0.55, 1), Drag = 2, Color = ColorSequence.new(COLORS.cream),
	})
	-- Shockwaves are flat neon discs that grow and fade.
	self.rings = {}
	for index = 1, RING_POOL do
		local wave = disc(self.dynamic, "Shockwave", 1, 0.3, 0, COLORS.cream, Enum.Material.Neon)
		wave.CFrame, wave.Transparency = PARKED, 1
		self.rings[index] = { part = wave, start = -100, life = 0.4, radius = 10, x = 0, y = 0 }
	end
	-- Comic words that pop up where something happened.
	self.words = {}
	for index = 1, WORD_POOL do
		local anchor = part(self.dynamic, "WordAnchor", Vector3.one, PARKED, COLORS.cream)
		anchor.Transparency = 1
		local board = Instance.new("BillboardGui")
		board.Name = "Word"
		board.Size = UDim2.fromOffset(260, 70)
		board.AlwaysOnTop = true
		board.Enabled = false
		board.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 40
		label.Parent = board
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = COLORS.ink
		stroke.Parent = label
		local scale = Instance.new("UIScale")
		scale.Parent = label
		self.words[index] = { anchor = anchor, board = board, label = label, stroke = stroke, scale = scale, start = -100, x = 0, y = 0 }
	end
	return self
end

function BattleView:_resetRound(roundId)
	self.roundId, self.lastEvent, self.sampleElapsed, self.sampleAge = roundId, 0, nil, 0
	self.finishReal = nil
	self.shake, self.punch, self.screenFlash = 0, 0, 0
	self.grade.Brightness, self.grade.Contrast, self.grade.Saturation = 0, 0.1, 0.02
	for _, fighter in pairs(self.fighters) do fighter.model:Destroy() end
	self.fighters = {}
	for _, wave in ipairs(self.rings) do wave.start, wave.part.Transparency = -100, 1 end
	for _, word in ipairs(self.words) do word.start, word.board.Enabled = -100, false end
end

function BattleView:_look(index)
	local player = Players.LocalPlayer
	local identity = self.identities and self.identities[index]
	local look
	if identity then
		look = { colorIndex = math.clamp(math.floor(numeric(identity.color, 1)), 1, #PAINTS), trailId = identity.trailId, name = identity.name }
	elseif index == 1 and player then
		look = { colorIndex = math.clamp(math.floor(numeric(player:GetAttribute("SkyboundColor"), 1)), 1, #PAINTS),
			trailId = player:GetAttribute("SkyboundTrail") }
	else
		look = { colorIndex = 2 }
	end
	look.color = PAINTS[look.colorIndex]
	look.trailColor, look.trailLife, look.trailEmission = ColorSequence.new(look.color, COLORS.cream), 0.45, 0.6
	if self.World and self.World.trailLook then
		local ok, first, second, entry = pcall(self.World.trailLook, look.trailId)
		if ok and entry then
			look.trailColor = ColorSequence.new(first, second)
			look.trailLife = 0.3 + numeric(entry.lifetime, 0.6) * 0.4
			look.trailEmission = numeric(entry.emission, 0.6)
		end
	end
	return look
end

-- Both pilots' paints, for a HUD that matches the tops.
function BattleView:accent(index)
	local fighter = self.fighters[index]
	return fighter and fighter.color or self:_look(index).color
end

local function has(list, id)
	for _, value in ipairs(list or {}) do
		if value == id then return true end
	end
	return false
end

-- Builds one top around the origin, spinning about +Y with its tip at y = 0:
-- a tip, a driver, a metal weight disc, a painted layer with the rim that
-- gives the type its shape, and a hub. Every part is a child of `model`.
local function buildTop(parent, state, color, accent)
	local model = Instance.new("Model")
	model.Name = "BattleTop" .. tostring(state.id)
	model.Parent = parent
	local radius = numeric(state.radius, 4.6)
	local kind = state.offenceId
	local wilds = state.wildIds
	local root = part(model, "Root", Vector3.one * 0.4, CFrame.identity, color)
	root.Transparency = 1
	model.PrimaryPart = root
	local function solid(name, size, pose, tint, material, shape)
		return part(model, name, size, pose, tint, material, shape)
	end
	local function round(name, r, height, y, tint, material)
		return solid(name, Vector3.new(height, r * 2, r * 2), discPose(0, y, 0), tint, material, Enum.PartType.Cylinder)
	end
	local function metal(object, shine)
		object.Material, object.Reflectance = Enum.Material.Metal, shine or 0.35
		return object
	end
	-- A ring of identical pieces set round the top at one height.
	local function around(name, count, offset, size, y, tint, sweep, material)
		for index = 0, count - 1 do
			local angle = index * math.pi * 2 / count
			solid(name, size, CFrame.Angles(0, angle, 0) * CFrame.new(offset, y, 0) * CFrame.Angles(0, sweep or 0, 0), tint, material)
		end
	end
	local rubber = has(wilds, "Turbo")
	metal(round("Tip", radius * (rubber and 0.2 or 0.1), 0.9, 0.45, rubber and COLORS.fire or COLORS.steel), rubber and 0 or 0.4)
	if rubber then model.Tip.Material = Enum.Material.SmoothPlastic end
	round("Driver", radius * 0.3, 0.8, 1.2, COLORS.rubber)
	round("DriverSkirt", radius * 0.5, 0.5, 1.75, COLORS.rubber)
	metal(round("Weight", radius * (has(wilds, "Heavy") and 0.97 or 0.84), has(wilds, "Heavy") and 1 or 0.6, 2.3, COLORS.steel))
	round("Layer", radius * 0.9, 0.7, 2.95, color)
	round("LayerInner", radius * 0.58, 0.3, 3.4, color:Lerp(COLORS.ink, 0.35))
	round("Hub", radius * 0.26, 0.5, 3.7, accent)
	-- One bright bar across the hub keeps the spin readable at any speed.
	solid("SpinStripe", Vector3.new(radius * 1.1, 0.14, radius * 0.16), CFrame.new(0, 3.6, 0), COLORS.cream)
	if kind == "Bolt" then
		-- Three long swept blades: all edges.
		around("Blade", 3, radius * 0.62, Vector3.new(radius * 0.95, 0.6, radius * 0.5), 2.95, color, 0.55)
		for index = 0, 2 do
			local angle = index * math.pi * 2 / 3
			metal(solid("BladeEdge", Vector3.new(radius * 0.5, 0.5, radius * 0.22),
				CFrame.Angles(0, angle, 0) * CFrame.new(radius * 0.88, 2.6, radius * 0.3) * CFrame.Angles(0, 0.55, 0), COLORS.steel))
		end
	elseif kind == "Cyclone" then
		-- A plain round rim with a thin metal band: nothing to catch on.
		metal(round("Band", radius, 0.3, 2.95, COLORS.steel))
		round("BandLip", radius * 0.94, 0.5, 2.95, color)
	elseif kind == "Boulder" then
		-- A thick metal tyre with shallow studs.
		metal(round("Tyre", radius, 1.1, 2.6, COLORS.gunmetal), 0.2)
		around("Stud", 8, radius * 0.98, Vector3.new(0.5, 0.7, radius * 0.3), 2.6, COLORS.steel, 0, Enum.Material.Metal)
	else
		-- Four stubby blades.
		around("Blade", 4, radius * 0.72, Vector3.new(radius * 0.6, 0.6, radius * 0.55), 2.95, color, 0.4)
		metal(round("Band", radius * 0.8, 0.25, 2.6, COLORS.steel))
	end
	if has(wilds, "Spikes") then
		around("Spike", 8, radius * 1.02, Vector3.new(radius * 0.34, 0.4, 0.5), 2.3, COLORS.steel, 0.5, Enum.Material.Metal)
	end
	local parts = {}
	if has(wilds, "Guard") then
		-- A loose outer ring that does not turn with the top.
		parts.guard = round("GuardRing", radius * 1.08, 0.35, 2.3, COLORS.lime, Enum.Material.Glass)
		parts.guard.Transparency = 0.35
	end
	if has(wilds, "Flywheel") then
		metal(round("Flywheel", radius * 0.5, 0.35, 3.45, COLORS.gold), 0.45)
	end
	if has(wilds, "LeftSpin") then
		round("LeftMark", radius * 0.14, 0.52, 3.72, COLORS.jet)
	end
	-- Where every piece sits on the top, so the whole thing can be posed at once.
	parts.pieces = {}
	for _, piece in ipairs(model:GetChildren()) do
		if piece:IsA("BasePart") and piece ~= root and piece ~= parts.guard then
			parts.pieces[#parts.pieces + 1] = { part = piece, rest = piece.CFrame }
		end
	end
	-- A ribbon in the pilot's trail colours follows the top round the bowl.
	local low, high = Instance.new("Attachment"), Instance.new("Attachment")
	low.Position, high.Position = Vector3.new(0, 2, 0), Vector3.new(0, 3.2, 0)
	low.Parent, high.Parent = root, root
	local trail = Instance.new("Trail")
	trail.Name = "Ribbon"
	trail.Attachment0, trail.Attachment1 = low, high
	trail.MinLength = 0.2
	trail.FaceCamera = true
	trail.Parent = root
	parts.trail = trail
	return model, parts, radius
end

function BattleView:_fighter(state, index)
	local fighter = self.fighters[index]
	if fighter then return fighter end
	local look = self:_look(index)
	local skill = self.skills and self.skills.get(state.offenceId or "")
	local accent = skill and Color3.fromRGB(skill.color.r, skill.color.g, skill.color.b) or COLORS.cream
	local model, parts, radius = buildTop(self.dynamic, state, look.color, accent)
	parts.trail.Color, parts.trail.Lifetime, parts.trail.LightEmission = look.trailColor, look.trailLife, look.trailEmission
	parts.trail.Transparency = NumberSequence.new(0.55, 1)
	-- A paint-coloured ring on the deck says whose top this is, and stays on
	-- the ground when the top jumps.
	local halo = disc(model, "Halo", radius * 1.2, 0.1, 0, look.color, Enum.Material.Neon)
	halo.Transparency = 0.6
	local tagAnchor = part(model, "TagAnchor", Vector3.one * 0.4, PARKED, look.color)
	tagAnchor.Transparency = 1
	local board = Instance.new("BillboardGui")
	board.Name = "Tag"
	board.Size = UDim2.fromOffset(220, 34)
	board.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	board.AlwaysOnTop = true
	board.Parent = tagAnchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 20
	label.TextColor3 = look.color:Lerp(Color3.new(1, 1, 1), 0.35)
	label.Parent = board
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = COLORS.ink
	stroke.Parent = label
	fighter = {
		index = index, model = model, parts = parts, radius = radius, color = look.color, accent = accent, name = look.name,
		halo = halo, tagAnchor = tagAnchor, label = label, skill = skill,
		spin = index * 1.7, lean = index * 2.1, position = nil, jolt = 0, hitTime = -100,
	}
	self.fighters[index] = fighter
	return fighter
end

function BattleView:_jolt(shake, punch, flash, hype)
	if self.reducedMotion then shake, punch, flash = shake * 0.25, 0, flash * 0.4 end
	self.shake = math.max(self.shake, shake)
	self.punch = math.max(self.punch, punch)
	self.screenFlash = math.max(self.screenFlash, flash)
	self.hype = math.min(1, self.hype + (hype or 0))
end

function BattleView:_burst(x, y, color, sparks, dust)
	self.fxAnchor.CFrame = CFrame.new(worldPoint(x, y, 2.5))
	self.sparks.Color = ColorSequence.new(COLORS.cream, color)
	self.sparks:Emit(self.reducedMotion and math.ceil(sparks / 3) or sparks)
	if dust and dust > 0 then self.smoke:Emit(dust) end
end

function BattleView:_wave(x, y, radius, color, life)
	self.ringCursor = self.ringCursor % RING_POOL + 1
	local wave = self.rings[self.ringCursor]
	wave.start, wave.life, wave.radius, wave.x, wave.y = self.realClock, life or 0.4, radius, x, y
	wave.part.Color = color
end

function BattleView:_word(x, y, text, color, size)
	self.wordCursor = self.wordCursor % WORD_POOL + 1
	local word = self.words[self.wordCursor]
	word.start, word.x, word.y = self.realClock, x, y
	word.label.Text, word.label.TextColor3, word.label.TextSize = text, color, size or 40
	word.board.Enabled = true
end

function BattleView:_events(simulation)
	for _, event in ipairs(simulation.events or {}) do
		local serial = numeric(event.serial, 0)
		if serial > self.lastEvent then
			self.lastEvent = serial
			local x, y = numeric(event.x, 0), numeric(event.y, 0)
			local actor, target = self.fighters[event.actor], self.fighters[event.target]
			-- An event from before this view joined the round is history.
			local fresh = numeric(simulation.elapsed, 0) - numeric(event.at, 0) < 0.6
			if not fresh then
				-- Nothing to show.
			elseif event.kind == "clash" then
				local power = numeric(event.power, 20)
				local big = power >= 34
				-- Metal on metal: white-hot sparks, more of them the harder it was.
				self:_burst(x, y, COLORS.yellow, math.clamp(math.floor(power / 3), 4, 30), big and 3 or 0)
				self:_jolt(math.min(1.3, power / 50), big and 0.5 or 0.1, big and 0.5 or 0, big and 0.3 or 0.05)
				if target then target.hitTime, target.jolt = self.realClock, math.min(0.5, power / 90) end
				if actor then actor.jolt = math.max(actor.jolt, math.min(0.25, power / 180)) end
				if big then self:_wave(x, y, 5 + power * 0.08, COLORS.cream, 0.25) end
			elseif event.kind == "wall" then
				self:_burst(x, y, COLORS.cream, math.clamp(math.floor(numeric(event.power, 10) / 4), 2, 12), 0)
				if actor then actor.jolt = math.max(actor.jolt, 0.15) end
			elseif event.kind == "close" then
				self:_word(x, y, "CLOSE!", COLORS.yellow, 34)
				self:_jolt(0, 0, 0, 0.25)
			elseif event.kind == "ringout" then
				self:_burst(x, y, COLORS.cream, 24, 6)
				self:_jolt(1.4, 0.8, 0.8, 1)
			elseif event.kind == "spinout" then
				self:_jolt(0.3, 0.2, 0.2, 0.6)
			end
		end
	end
end

-- Draws one top where the snapshot says it is, a little ahead for the time
-- since that snapshot arrived. How fast it turns and how badly it wobbles
-- both come from how much spin it has left.
function BattleView:_pose(fighter, state, simulation, moving, dt, realDt)
	local x, y = numeric(state.x, 0), numeric(state.y, 0)
	local vx, vy = numeric(state.vx, 0), numeric(state.vy, 0)
	local share = math.clamp(numeric(state.spin, 100) / math.max(1, numeric(state.spinMax, 100)), 0, 1)
	local ahead = moving and math.min(self.sampleAge, 0.055) or 0
	local goal = Vector3.new(x + vx * ahead, 0, y + vy * ahead)
	if state.out then
		-- A top that went out through a gap keeps going and drops out of the
		-- sky. The simulation is over; this is only the picture of it.
		if not fighter.fall then
			fighter.fall = { position = fighter.position or goal, velocity = Vector3.new(vx, 9, vy), time = 0 }
			if self.onPresentationCue then self.onPresentationCue({ kind = "crash", roundId = self.roundId, actor = fighter.index }) end
		end
		local fall = fighter.fall
		fall.time = fall.time + dt
		fall.velocity = fall.velocity + Vector3.new(0, -GRAVITY * dt, 0)
		fall.position = fall.position + fall.velocity * dt
		fighter.position = fall.position
	elseif not fighter.position or (fighter.position - goal).Magnitude > 12 then
		fighter.position, fighter.fall = goal, nil
	else
		fighter.position, fighter.fall = fighter.position:Lerp(goal, 1 - math.exp(-28 * realDt)), nil
	end
	local position = fighter.position
	-- A top that has stopped falls on its side and rolls to rest.
	if state.down then
		fighter.downTime = (fighter.downTime or 0) + dt
		if fighter.downTime == dt and self.onPresentationCue then
			self.onPresentationCue({ kind = "topple", roundId = self.roundId, actor = fighter.index })
		end
	else
		fighter.downTime = nil
	end
	local toppled = fighter.downTime and math.clamp(fighter.downTime / 0.45, 0, 1) or 0
	local turn = numeric(state.turn, 1) < 0 and -1 or 1
	local rate = 22 * (0.18 + 0.82 * share) * (1 - toppled)
	fighter.spin = (fighter.spin + rate * dt * turn) % (math.pi * 2)
	fighter.jolt = fighter.jolt * math.exp(-3 * realDt)
	-- The lean: nothing while it is spinning hard, a widening, quickening
	-- circle as it slows, and flat on its side once it has stopped.
	local wobble = self.reducedMotion and 0 or (0.02 + 0.42 * (1 - share) ^ 2 + fighter.jolt)
	fighter.lean = fighter.lean + (2.5 + 9 * (1 - share)) * dt * turn
	local tilt = wobble + toppled * 1.35
	local up = Vector3.new(math.cos(fighter.lean) * math.sin(tilt), math.cos(tilt), math.sin(fighter.lean) * math.sin(tilt))
	if fighter.fall then
		local tumble = math.min(1.3, fighter.fall.time * 2.4)
		up = (up + Vector3.new(math.cos(fighter.spin * 0.3), 0, math.sin(fighter.spin * 0.3)) * tumble).Unit
	end
	local reference = Vector3.new(math.cos(fighter.spin), 0, math.sin(fighter.spin))
	local right = reference - up * reference:Dot(up)
	right = right.Magnitude > 0.001 and right.Unit or Vector3.new(0, 0, 1)
	-- Tipped over, a top rests on its rim, not on its tip.
	local lift = Vector3.new(0, math.sin(math.min(tilt, 1.35)) * fighter.radius * 0.55, 0)
	local pose = CFrame.fromMatrix(ORIGIN + position + lift, right, up)
	fighter.model.PrimaryPart.CFrame = pose
	local parts = fighter.parts
	for _, piece in ipairs(parts.pieces) do piece.part.CFrame = pose * piece.rest end
	if parts.guard then
		-- The guard ring tilts with the top but does not spin with it.
		local still = Vector3.new(1, 0, 0) - up * up.X
		parts.guard.CFrame = CFrame.fromMatrix(ORIGIN + position + lift, still.Unit, up) * discPose(0, 2.3, 0)
	end
	parts.trail.Enabled = not fighter.fall and toppled == 0
	local flash = math.max(0, 1 - (self.realClock - fighter.hitTime) / 0.2)
	fighter.halo.CFrame = discPose(ORIGIN.X + position.X, ORIGIN.Y + 0.22, ORIGIN.Z + position.Z)
	fighter.halo.Transparency = fighter.fall and 1 or (0.6 - flash * 0.4)
	fighter.halo.Color = fighter.color:Lerp(Color3.new(1, 1, 1), flash)
	fighter.tagAnchor.CFrame = CFrame.new(ORIGIN + position)
	local tag = fighter.index == 1 and "YOU" or string.upper(fighter.name or "RIVAL")
	if moving and share < 0.25 then tag = "WOBBLING!" end
	fighter.label.Text = fighter.fall and "" or tag
	fighter.model:SetAttribute("Phase", state.out and "Out" or (state.down and "Down" or "Spinning"))
end

function BattleView:_effects(realDt)
	for _, cloud in ipairs(self.clouds) do
		cloud.x = cloud.x + cloud.drift * realDt
		if cloud.x > 340 then cloud.x = -340 end
		cloud.model:PivotTo(CFrame.new(ORIGIN + Vector3.new(cloud.x, cloud.y, cloud.z)))
	end
	for _, wave in ipairs(self.rings) do
		local age = (self.realClock - wave.start) / wave.life
		if age >= 0 and age < 1 then
			local radius = math.max(0.5, wave.radius * (0.25 + 0.75 * age))
			wave.part.Size = Vector3.new(0.15, radius * 2, radius * 2)
			wave.part.CFrame = discPose(ORIGIN.X + wave.x, ORIGIN.Y + 0.4, ORIGIN.Z + wave.y)
			wave.part.Transparency = 0.6 + 0.4 * age
		else
			wave.part.Transparency = 1
		end
	end
	for _, word in ipairs(self.words) do
		local age = self.realClock - word.start
		if age >= 0 and age < 0.9 then
			word.anchor.CFrame = CFrame.new(worldPoint(word.x, word.y, 7 + age * 5))
			word.scale.Scale = self.reducedMotion and 1 or 1 + 0.6 * math.max(0, 1 - age / 0.14) ^ 2
			local fading = math.clamp((age - 0.55) / 0.35, 0, 1)
			word.label.TextTransparency, word.stroke.Transparency = fading, fading
		elseif word.board.Enabled then
			word.board.Enabled = false
		end
	end
end

function BattleView:_camera(rect, simulation, dt)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local width, height = math.max(1, viewport.X), math.max(1, viewport.Y)
	local left = math.clamp(numeric(rect and rect.left, 16), 0, width - 1)
	local top = math.clamp(numeric(rect and rect.top, 90), 0, height - 1)
	local right = math.clamp(numeric(rect and rect.right, width - 16), left + 1, width)
	local bottom = math.clamp(numeric(rect and rect.bottom, height - 40), top + 1, height)
	local aspect = width / height
	-- The whole stadium stays in frame for the whole round.
	local span = (RING + 4) * (1 - 0.04 * self.punch)
	-- Seen from above at an angle the ring is an ellipse: full width, and its
	-- depth squashed by the camera's tilt. Jumps need a little headroom.
	local fullWidth = 2 * span / ((right - left) / width)
	local fullHeight = math.max(fullWidth / aspect, (2 * span * math.sin(ELEVATION) + 7) / ((bottom - top) / height))
	local fieldOfView = math.clamp(math.deg(2 * math.atan(fullHeight / (2 * CAMERA_DISTANCE))), 10, 110)
	local back = Vector3.new(0, math.sin(ELEVATION), math.cos(ELEVATION))
	local rightAxis = Vector3.new(1, 0, 0)
	local upAxis = back:Cross(rightAxis)
	-- Shift the aim so the ring sits in the middle of the free part of the screen.
	local shiftX = -((left + right) / (2 * width) - 0.5) * fullHeight * aspect
	local shiftY = ((top + bottom) / (2 * height) - 0.5) * fullHeight
	local shake = Vector3.new(math.sin(self.realClock * 83), math.cos(self.realClock * 97), 0) * self.shake
	local focus = ORIGIN + rightAxis * (shiftX + shake.X) + upAxis * (shiftY + shake.Y)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical
	camera.FieldOfView = fieldOfView
	camera.CFrame = CFrame.lookAt(focus + back * CAMERA_DISTANCE, focus, upAxis)
	camera.Focus = CFrame.new(focus)
	self.folder:SetAttribute("VisibleHeight", fullHeight)
end

function BattleView:update(snapshot, dt, viewportRect)
	if self.destroyed or not snapshot then return end
	dt = math.clamp(numeric(dt, 1 / 60), 0, 0.1)
	local realDt = dt
	self.realClock = self.realClock + realDt
	local identityKey = ""
	for _, identity in ipairs(snapshot.players or {}) do
		identityKey = identityKey .. tostring(identity.userId) .. ":" .. tostring(identity.name) .. ":" .. tostring(identity.color) .. ":" .. tostring(identity.trailId) .. ";"
	end
	local simulation = snapshot.simulation or {}
	-- A new round, a new rival or a changed build all mean new tops.
	local buildKey = identityKey
	for _, state in ipairs(simulation.fighters or {}) do
		buildKey = buildKey .. tostring(state.offenceId) .. ":" .. table.concat(state.wildIds or {}, ",") .. ";"
	end
	self.identities = snapshot.players
	if snapshot.roundId ~= self.roundId or buildKey ~= self.buildKey then
		self.buildKey = buildKey
		self:_resetRound(snapshot.roundId)
	end
	if simulation.finished == true then self.finishReal = self.finishReal or self.realClock
	else self.finishReal = nil end
	-- The fall plays in slow motion for a moment. Only this view's clock slows.
	local slowMotion = not self.reducedMotion and simulation.finished == true
		and (simulation.reason == "ringout" or simulation.reason == "spinout") and self.realClock - self.finishReal < 0.45
	if slowMotion then dt = dt * 0.35 end
	self.clock = self.clock + dt
	self.shake = self.shake * math.exp(-9 * realDt)
	self.punch = self.punch * math.exp(-6 * realDt)
	self.screenFlash = self.screenFlash * math.exp(-11 * realDt)
	self.hype = self.hype * math.exp(-0.9 * realDt)
	self.grade.Brightness = self.screenFlash * 0.16
	self.grade.Contrast = 0.1 + self.screenFlash * 0.15
	self.grade.Saturation = slowMotion and -0.3 or 0.02
	local elapsed = numeric(simulation.elapsed, 0)
	if elapsed ~= self.sampleElapsed then
		self.sampleElapsed, self.sampleAge = elapsed, 0
	else
		self.sampleAge = self.sampleAge + dt
	end
	local moving = snapshot.phase == "Fight" and simulation.finished ~= true
	local shown = snapshot.phase == "Fight" or snapshot.phase == "Countdown" or snapshot.phase == "RoundOver"
		or snapshot.phase == "MatchOver" or snapshot.phase == "Results"
	for index, state in ipairs(simulation.fighters or {}) do
		if index > 2 then break end
		local fighter = self:_fighter(state, index)
		if shown then
			self:_pose(fighter, state, simulation, moving, dt, realDt)
		else
			-- While pilots are still choosing, last round's tops are put away.
			for _, piece in ipairs(fighter.model:GetChildren()) do
				if piece:IsA("BasePart") then piece.CFrame = PARKED end
			end
			fighter.position, fighter.fall, fighter.downTime = nil, nil, nil
			fighter.label.Text = ""
		end
	end
	if shown then self:_events(simulation) end
	self:_effects(realDt)
	self.folder:SetAttribute("Phase", snapshot.phase or "Configure")
	self.folder:SetAttribute("RoundId", tostring(snapshot.roundId or ""))
	self:_camera(viewportRect, shown and simulation or {}, realDt)
end

function BattleView:destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.folder:Destroy()
	self.bloom:Destroy()
	self.grade:Destroy()
	table.clear(self.fighters)
	-- The normal client camera resumes on its next render. No connections,
	-- lighting effects, delayed callbacks, or external instances survive.
end

return BattleView
