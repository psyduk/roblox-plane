--!nonstrict
-- Local presentation for Sky Battle: two spinning tops on a round platform in
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
local RING = 40
local COLORS = {
	coral = Color3.fromRGB(255, 104, 102), cyan = Color3.fromRGB(66, 225, 239),
	cream = Color3.fromRGB(255, 245, 217), yellow = Color3.fromRGB(255, 212, 80),
	fire = Color3.fromRGB(255, 145, 54), purple = Color3.fromRGB(184, 138, 255),
	ink = Color3.fromRGB(14, 22, 44), steel = Color3.fromRGB(96, 116, 140),
	deck = Color3.fromRGB(44, 66, 110), deckLight = Color3.fromRGB(62, 92, 148),
	danger = Color3.fromRGB(214, 70, 78), stone = Color3.fromRGB(150, 150, 160),
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
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local RING_POOL, WORD_POOL, DEBRIS = 6, 5, 12

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
	for index = 1, 22 do
		local size = 26 + roll() * 34
		local x, y, z = (roll() * 2 - 1) * 330, -60 - roll() * 70, -260 + roll() * 330
		-- Keep the air straight under the platform clear, so tops fall into sky.
		if math.abs(x) < 70 and math.abs(z) < 70 then x = x + (x < 0 and -90 or 90) end
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

local function makePlatform(parent)
	local scenery = Instance.new("Folder")
	scenery.Name = "Stadium"
	scenery.Parent = parent
	local clouds = makeSky(scenery)
	-- Everything round is a child of one folder and is resized together as the
	-- ring closes. `fraction` is each disc's share of the live ring.
	local discs = {}
	local function layer(name, fraction, inset, height, y, color, material)
		local object = disc(scenery, name, RING * fraction - inset, height, ORIGIN.Y + y, color, material)
		object.CFrame = discPose(ORIGIN.X, ORIGIN.Y + y, ORIGIN.Z)
		discs[#discs + 1] = { part = object, fraction = fraction, inset = inset, height = height, y = y }
		return object
	end
	-- Where the platform used to reach, left as a faint ghost once it shrinks.
	local ghost = disc(scenery, "LostRing", RING, 0.6, 0, COLORS.danger, Enum.Material.Neon)
	ghost.CFrame = discPose(ORIGIN.X, ORIGIN.Y - 2.6, ORIGIN.Z)
	ghost.Transparency = 1
	local rim = layer("Rim", 1, -0.9, 1.2, -1.5, COLORS.cream, Enum.Material.Neon)
	layer("DangerBand", 1, 0, 2.4, -1.2, COLORS.danger)
	layer("Deck", 1, 3.2, 2.4, -1.15, COLORS.deck)
	layer("MidRing", 0.62, 0, 2.4, -1.1, COLORS.deckLight)
	layer("InnerDeck", 0.58, 0, 2.4, -1.05, COLORS.deck)
	local mark = layer("CentreMark", 0.14, 0, 2.4, -1, COLORS.cream, Enum.Material.Neon)
	mark.Transparency = 0.25
	-- The keel under the platform gives it weight and somewhere to fall past.
	layer("Keel", 0.7, 0, 9, -7, COLORS.ink)
	layer("KeelTip", 0.36, 0, 9, -15, COLORS.ink)
	local lamp = Instance.new("PointLight")
	lamp.Color, lamp.Brightness, lamp.Range, lamp.Shadows = COLORS.cream, 0.5, 70, false
	lamp.Parent = mark
	local debris = {}
	for index = 1, DEBRIS do
		debris[index] = { part = part(scenery, "Crumble", Vector3.new(2.4, 1.2, 2.4), PARKED, COLORS.deck), offset = index / DEBRIS, angle = index * 2.399 }
		debris[index].part.Transparency = 1
	end
	return scenery, discs, rim, ghost, clouds, debris
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
	self.scenery, self.discs, self.rim, self.ghost, self.clouds, self.debris = makePlatform(self.folder)
	-- Glow and grade belong to this view and leave with it.
	self.bloom = Instance.new("BloomEffect")
	self.bloom.Name = "SkyboundBattleBloom"
	self.bloom.Intensity, self.bloom.Size, self.bloom.Threshold = 0.55, 24, 1.1
	self.bloom.Parent = Lighting
	self.grade = Instance.new("ColorCorrectionEffect")
	self.grade.Name = "SkyboundBattleGrade"
	self.grade.Saturation, self.grade.Contrast = 0.14, 0.06
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
		Lifetime = NumberRange.new(0.25, 0.6), Speed = NumberRange.new(18, 46), Size = fade(2.2, 0),
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
	self.grade.Brightness, self.grade.Contrast, self.grade.Saturation = 0, 0.06, 0.14
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

-- Builds one top around the origin, spinning about +Y with its tip at y = 0.
-- Every part is a child of `model`; `spin` holds the ones that turn.
local function buildTop(parent, state, color, accent)
	local model = Instance.new("Model")
	model.Name = "BattleTop" .. tostring(state.id)
	model.Parent = parent
	local radius = numeric(state.radius, 4.6)
	local kind = state.offenceId
	local lift = kind == "Pogo" and 1.4 or 0
	local root = part(model, "Root", Vector3.one * 0.4, CFrame.identity, color)
	root.Transparency = 1
	model.PrimaryPart = root
	local function solid(name, size, pose, tint, material, shape)
		return part(model, name, size, pose, tint, material, shape)
	end
	local function round(name, r, height, y, tint, material)
		return solid(name, Vector3.new(height, r * 2, r * 2), discPose(0, y + lift, 0), tint, material, Enum.PartType.Cylinder)
	end
	round("Tip", radius * 0.16, 1.3, 0.65 - lift, COLORS.steel, Enum.Material.Metal)
	round("Bowl", radius * 0.68, 1, 1.6, color:Lerp(COLORS.ink, 0.45))
	round("AttackRing", radius, 1.4, 2.6, color)
	round("Cap", radius * 0.62, 0.9, 3.6, COLORS.cream)
	round("Knob", radius * 0.2, 1.3, 4.5, accent, Enum.Material.Neon)
	-- Two bright bars across the cap make the spin readable at any speed.
	solid("SpinStripe", Vector3.new(radius * 1.2, 0.2, radius * 0.24), CFrame.new(0, 4.08 + lift, 0), accent, Enum.Material.Neon)
	solid("SpinStripe", Vector3.new(radius * 0.24, 0.2, radius * 1.2), CFrame.new(0, 4.08 + lift, 0), color, Enum.Material.Neon)
	if kind == "Boulder" then
		for index = 0, 3 do
			local angle = index * math.pi / 2 + math.pi / 4
			solid("Stud", Vector3.new(radius * 0.46, 1.9, radius * 0.46),
				CFrame.new(math.cos(angle) * radius * 0.86, 2.6, math.sin(angle) * radius * 0.86) * CFrame.Angles(0, -angle, 0), COLORS.stone, Enum.Material.Slate)
		end
	elseif kind == "Bolt" then
		solid("Blade", Vector3.new(radius * 2.7, 0.35, 0.9), CFrame.new(0, 2.6, 0), COLORS.yellow, Enum.Material.Neon)
		solid("Blade", Vector3.new(0.9, 0.35, radius * 2.2), CFrame.new(0, 2.6, 0), COLORS.yellow, Enum.Material.Neon)
	elseif kind == "Cyclone" then
		for index = 0, 2 do
			local angle = index * math.pi * 2 / 3
			solid("Fin", Vector3.new(radius * 1.05, 0.5, 1.3),
				CFrame.Angles(0, angle, 0) * CFrame.new(radius * 0.82, 2.6, radius * 0.4) * CFrame.Angles(0, 0.7, 0), COLORS.cyan, Enum.Material.Neon)
		end
	elseif kind == "Pogo" then
		for index = 0, 2 do
			round("Spring", radius * 0.34, 0.3, 0.35 + index * 0.55 - lift, COLORS.purple, Enum.Material.Neon)
		end
		ellipsoid(model, "Head", Vector3.new(radius * 1.2, radius * 0.8, radius * 1.2), CFrame.new(0, 4.2 + lift, 0), COLORS.purple)
	end
	local parts = { bumper = nil, jets = {}, flames = {} }
	local wilds = state.wildIds
	if has(wilds, "Heavy") then
		round("HeavyBand", radius * 1.03, 0.7, 2.6, COLORS.steel, Enum.Material.Metal)
		round("HeavyCore", radius * 0.4, 1.2, 3.9, COLORS.steel, Enum.Material.Metal)
	end
	if has(wilds, "Spikes") then
		for index = 0, 5 do
			local angle = index * math.pi / 3
			solid("Spike", Vector3.new(radius * 0.55, 0.5, 0.7),
				CFrame.Angles(0, angle, 0) * CFrame.new(radius * 1.16, 2.6, 0), COLORS.coral, Enum.Material.Neon)
		end
	end
	if has(wilds, "Claws") then
		for index = 0, 2 do
			local angle = index * math.pi * 2 / 3 + 0.5
			solid("Claw", Vector3.new(radius * 0.6, 0.4, 0.55),
				CFrame.Angles(0, angle, 0) * CFrame.new(radius * 0.82, 0.9, 0) * CFrame.Angles(0, 0, -0.6), COLORS.claw, Enum.Material.Neon)
		end
	end
	if has(wilds, "Turbo") then
		round("TurboGlow", radius * 0.8, 0.25, 1.05, COLORS.fire, Enum.Material.Neon)
		local point = Instance.new("Attachment")
		point.Position = Vector3.new(0, 1, 0)
		point.Parent = root
		parts.turbo = emitter(point, "TurboFlame", FIRE_TEXTURE, {
			Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(2, 6), Size = fade(2.6, 0), LightEmission = 1,
			Color = ColorSequence.new(COLORS.yellow, COLORS.fire), Rate = 26, Enabled = true,
		})
	end
	if has(wilds, "Bumper") then
		parts.bumper = solid("BumperShield", Vector3.one * radius * 2.7, CFrame.new(0, 2.6, 0), COLORS.lime, Enum.Material.ForceField, Enum.PartType.Ball)
		parts.bumper.Transparency = 0.35
	end
	if has(wilds, "Jetpack") then
		for index, side in ipairs({ -1, 1 }) do
			parts.jets[index] = solid("JetTank", Vector3.new(1.7, radius * 0.3, radius * 0.3),
				discPose(side * radius * 0.36, 4.5 + lift, 0), COLORS.jet, Enum.Material.Metal, Enum.PartType.Cylinder)
			local point = Instance.new("Attachment")
			point.Position = Vector3.new(side * radius * 0.36, 3.4 + lift, 0)
			point.Parent = root
			parts.flames[index] = emitter(point, "JetFlame", FIRE_TEXTURE, {
				Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(14, 22), Size = fade(2.4, 0), LightEmission = 1,
				Color = ColorSequence.new(COLORS.cream, COLORS.jet), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(14, 14), Rate = 50,
			})
		end
	end
	-- Where every piece sits on the top, so the whole thing can be posed at once.
	parts.pieces = {}
	for _, piece in ipairs(model:GetChildren()) do
		if piece:IsA("BasePart") and piece ~= root then parts.pieces[#parts.pieces + 1] = { part = piece, rest = piece.CFrame } end
	end
	-- A ribbon in the pilot's trail colours follows the top round the ring.
	local low, high = Instance.new("Attachment"), Instance.new("Attachment")
	low.Position, high.Position = Vector3.new(0, 1.9, 0), Vector3.new(0, 3.3, 0)
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
	parts.trail.Transparency = NumberSequence.new(0.2, 1)
	-- A paint-coloured ring on the deck says whose top this is, and stays on
	-- the ground when the top jumps.
	local halo = disc(model, "Halo", radius * 1.25, 0.2, 0, look.color, Enum.Material.Neon)
	halo.Transparency = 0.45
	local target = disc(model, "LandingMark", 4, 0.2, 0, look.color, Enum.Material.Neon)
	target.Transparency = 1
	local line = part(model, "AimLine", Vector3.one, PARKED, look.color, Enum.Material.Neon)
	line.Transparency = 1
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
		halo = halo, target = target, line = line, tagAnchor = tagAnchor, label = label, skill = skill,
		spin = index * 1.7, position = nil, wobble = 0, hitTime = -100, closeTime = -100,
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
				local big = power >= 38
				local color = actor and actor.color or COLORS.cream
				self:_burst(x, y, color, big and 26 or 10, big and 5 or 0)
				self:_jolt(math.min(1.6, power / 45), big and 0.6 or 0.15, big and 0.7 or 0, big and 0.35 or 0.05)
				if target then target.hitTime, target.wobble = self.realClock, math.min(0.6, power / 80) end
				if big then
					self:_wave(x, y, 9 + power * 0.12, color, 0.35)
					self:_word(x, y, actor and actor.skill and actor.skill.word or "WHAM!", color:Lerp(Color3.new(1, 1, 1), 0.3), 44)
				end
			elseif event.kind == "slam" then
				self:_wave(x, y, numeric(event.radius, 14), actor and actor.color or COLORS.cream, 0.45)
				self:_burst(x, y, actor and actor.color or COLORS.cream, 12, 8)
				self:_jolt(0.7, 0.3, 0.2, 0.15)
			elseif event.kind == "blocked" then
				self:_wave(x, y, 11, COLORS.lime, 0.4)
				self:_burst(x, y, COLORS.lime, 22, 0)
				self:_word(x, y, "BOING!", COLORS.lime, 46)
				self:_jolt(0.8, 0.4, 0.4, 0.3)
			elseif event.kind == "revive" then
				self:_word(x, y, "JETPACK!", COLORS.jet, 44)
				self:_burst(x, y, COLORS.jet, 18, 6)
				self:_jolt(0.5, 0.3, 0.3, 0.4)
			elseif event.kind == "close" then
				self:_word(x, y, "CLOSE!", COLORS.yellow, 38)
				if actor then actor.closeTime = self.realClock end
				self:_jolt(0, 0, 0, 0.25)
			elseif event.kind == "attack" then
				if actor then self:_burst(x, y, actor.accent, 8, 2) end
			elseif event.kind == "ringout" then
				self:_burst(x, y, COLORS.cream, 34, 10)
				self:_wave(x, y, 16, COLORS.cream, 0.5)
				self:_jolt(1.8, 1, 1, 1)
			end
		end
	end
end

-- Draws one top where the snapshot says it is, a little ahead for the time
-- since that snapshot arrived.
function BattleView:_pose(fighter, state, simulation, moving, dt, realDt)
	local x, y, height = numeric(state.x, 0), numeric(state.y, 0), numeric(state.z, 0)
	local vx, vy = numeric(state.vx, 0), numeric(state.vy, 0)
	local ahead = moving and math.min(self.sampleAge, 0.055) or 0
	local goal = Vector3.new(x + vx * ahead, height, y + vy * ahead)
	if state.out then
		-- A top that left the ring keeps going and drops out of the sky. The
		-- simulation is over; this is only the picture of it.
		if not fighter.fall then
			fighter.fall = { position = fighter.position or goal, velocity = Vector3.new(vx, 6, vy), time = 0 }
			if self.onPresentationCue then self.onPresentationCue({ kind = "crash", roundId = self.roundId, actor = fighter.index }) end
		end
		local fall = fighter.fall
		fall.time = fall.time + dt
		fall.velocity = fall.velocity + Vector3.new(0, -GRAVITY * dt, 0)
		fall.position = fall.position + fall.velocity * dt
		fighter.position = fall.position
	elseif not fighter.position or (fighter.position - goal).Magnitude > 14 then
		fighter.position, fighter.fall = goal, nil
	else
		fighter.position, fighter.fall = fighter.position:Lerp(goal, 1 - math.exp(-28 * realDt)), nil
	end
	local position = fighter.position
	-- Spin gets quicker as the round heats up; a top that is charging winds
	-- itself up faster still.
	local heat = numeric(simulation.heat, 1)
	local rate = 13 * heat * (state.phase == "Windup" and 1.8 or 1) * (state.phase == "Attack" and 2 or 1)
	fighter.spin = (fighter.spin + rate * dt * (fighter.index == 1 and 1 or -1)) % (math.pi * 2)
	fighter.wobble = fighter.wobble * math.exp(-2.2 * realDt)
	local speed = math.sqrt(vx * vx + vy * vy)
	local lean = self.reducedMotion and 0 or math.clamp(speed / 160, 0, 0.3)
	local wobble = self.reducedMotion and 0 or (0.03 + fighter.wobble + (numeric(state.stun, 0) > 0 and 0.12 or 0))
	local up = Vector3.new(0, 1, 0)
	if speed > 1 then up = up + Vector3.new(vx / speed, 0, vy / speed) * lean end
	up = up + Vector3.new(math.cos(self.clock * 9 + fighter.index), 0, math.sin(self.clock * 9 + fighter.index)) * wobble
	if fighter.fall then
		local tumble = math.min(1.3, fighter.fall.time * 2.4)
		up = up + Vector3.new(math.cos(fighter.spin * 0.3), 0, math.sin(fighter.spin * 0.3)) * tumble
	end
	up = up.Unit
	local reference = Vector3.new(math.cos(fighter.spin), 0, math.sin(fighter.spin))
	local right = (reference - up * reference:Dot(up)).Unit
	fighter.model.PrimaryPart.CFrame = CFrame.fromMatrix(ORIGIN + position, right, up)
	local pose = fighter.model.PrimaryPart.CFrame
	local flash = math.max(0, 1 - (self.realClock - fighter.hitTime) / 0.25)
	local parts = fighter.parts
	for _, piece in ipairs(parts.pieces) do piece.part.CFrame = pose * piece.rest end
	if parts.bumper then
		parts.bumper.Transparency = state.bumperReady and (0.35 + (self.reducedMotion and 0 or 0.12 * math.sin(self.clock * 6))) or 1
	end
	for index, tank in ipairs(parts.jets) do
		tank.Transparency = (state.jetReady or state.flying == "jet") and 0 or 0.7
		parts.flames[index].Enabled = state.flying == "jet"
	end
	parts.trail.Enabled = not fighter.fall and numeric(state.z, 0) < 1
	-- On the deck: whose top it is, where it means to land, where it means to go.
	local grounded = Vector3.new(position.X, 0, position.Z)
	fighter.halo.CFrame = discPose(ORIGIN.X + grounded.X, ORIGIN.Y + 0.32, ORIGIN.Z + grounded.Z)
	fighter.halo.Transparency = fighter.fall and 1 or (0.45 - flash * 0.4)
	fighter.halo.Color = fighter.color:Lerp(Color3.new(1, 1, 1), flash)
	local windup, air = state.phase == "Windup", state.phase == "Air"
	local lockX, lockY = numeric(state.lockX, x), numeric(state.lockY, y)
	local jump = state.flying == "jump" or (windup and state.move and state.move.kind == "jump")
	if (air or windup) and jump then
		local reach = state.move and numeric(state.move.reach, 12) or 12
		fighter.target.Size = Vector3.new(0.2, reach * 2, reach * 2)
		fighter.target.CFrame = discPose(ORIGIN.X + lockX, ORIGIN.Y + 0.4, ORIGIN.Z + lockY)
		fighter.target.Transparency = 0.82 - (self.reducedMotion and 0 or 0.1 * math.sin(self.clock * 14))
	else
		fighter.target.Transparency = 1
	end
	if windup and not jump then
		local from, to = Vector3.new(x, 0, y), Vector3.new(lockX, 0, lockY)
		local reach = (to - from).Magnitude
		if reach > 1 then
			local far = from + (to - from).Unit * (reach + 16)
			fighter.line.Size = Vector3.new(1.1, 0.2, (far - from).Magnitude)
			fighter.line.CFrame = CFrame.lookAt(ORIGIN + (from + far) / 2 + Vector3.new(0, 0.5, 0), ORIGIN + far + Vector3.new(0, 0.5, 0))
			fighter.line.Transparency = 0.35 + (self.reducedMotion and 0 or 0.25 * math.sin(self.clock * 20))
		end
	else
		fighter.line.Transparency = 1
	end
	fighter.tagAnchor.CFrame = CFrame.new(ORIGIN + position)
	local tells = fighter.skill
	local tag = fighter.index == 1 and "YOU" or string.upper(fighter.name or "RIVAL")
	if moving and windup then tag = tells and tells.windupTell or "CHARGING..."
	elseif moving and (state.phase == "Attack" or (air and jump)) then tag = tells and tells.attackTell or "GO!" end
	fighter.label.Text = fighter.fall and "" or tag
	fighter.model:SetAttribute("Phase", state.out and "Out" or tostring(state.phase))
end

function BattleView:_platform(simulation, realDt)
	local ring = math.clamp(numeric(simulation.ring, RING), 1, RING)
	local pressure = math.clamp(numeric(simulation.pressure, 0), 0, 1)
	for _, layer in ipairs(self.discs) do
		local radius = math.max(0.5, ring * layer.fraction - layer.inset)
		layer.part.Size = Vector3.new(layer.height, radius * 2, radius * 2)
	end
	local pulse = self.reducedMotion and 0.5 or 0.5 + 0.5 * math.sin(self.clock * (4 + pressure * 8))
	self.rim.Color = pressure > 0 and COLORS.yellow:Lerp(COLORS.danger, pulse) or COLORS.cream
	self.ghost.Transparency = pressure > 0 and 0.86 or 1
	-- Chunks break off the edge while the ring is closing.
	for _, chunk in ipairs(self.debris) do
		if pressure > 0 and not self.reducedMotion then
			local age = (self.clock * 0.7 + chunk.offset) % 1
			local angle = chunk.angle + math.floor(self.clock * 0.7 + chunk.offset) * 1.7
			chunk.part.CFrame = CFrame.new(worldPoint(math.cos(angle) * (ring + 1.5), math.sin(angle) * (ring + 1.5), -1 - age * age * 46))
				* CFrame.Angles(age * 5, angle, age * 3)
			chunk.part.Transparency = 0.1 + age * 0.9
		else
			chunk.part.Transparency = 1
		end
	end
	for _, cloud in ipairs(self.clouds) do
		cloud.x = cloud.x + cloud.drift * realDt
		if cloud.x > 340 then cloud.x = -340 end
		cloud.model:PivotTo(CFrame.new(ORIGIN + Vector3.new(cloud.x, cloud.y, cloud.z)))
	end
	for _, wave in ipairs(self.rings) do
		local age = (self.realClock - wave.start) / wave.life
		if age >= 0 and age < 1 then
			local radius = math.max(0.5, wave.radius * (0.25 + 0.75 * age))
			wave.part.Size = Vector3.new(0.25, radius * 2, radius * 2)
			wave.part.CFrame = discPose(ORIGIN.X + wave.x, ORIGIN.Y + 0.6, ORIGIN.Z + wave.y)
			wave.part.Transparency = 0.35 + 0.65 * age
		else
			wave.part.Transparency = 1
		end
	end
	for _, word in ipairs(self.words) do
		local age = self.realClock - word.start
		if age >= 0 and age < 0.9 then
			word.anchor.CFrame = CFrame.new(worldPoint(word.x, word.y, 9 + age * 7))
			word.scale.Scale = self.reducedMotion and 1 or 1 + 0.9 * math.max(0, 1 - age / 0.14) ^ 2
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
	-- Frame whatever is left of the ring plus a margin, and close in as it
	-- shrinks so the tops never get small.
	local ring = math.clamp(numeric(simulation.ring, RING), 8, RING)
	local reach = ring + 3
	for _, fighter in pairs(self.fighters) do
		if fighter.position and not fighter.fall then
			reach = math.max(reach, math.sqrt(fighter.position.X ^ 2 + fighter.position.Z ^ 2) + 6)
		end
	end
	if self.reducedMotion then reach = RING + 3 end
	self.frame = self.frame or reach
	local follow = 1 - math.exp(-(reach > self.frame and 8 or 1.6) * dt)
	self.frame = self.frame + (reach - self.frame) * follow
	local span = self.frame * (1 - 0.05 * self.punch)
	-- Seen from above at an angle the ring is an ellipse: full width, and its
	-- depth squashed by the camera's tilt. Jumps need a little headroom.
	local fullWidth = 2 * span / ((right - left) / width)
	local fullHeight = math.max(fullWidth / aspect, (2 * span * math.sin(ELEVATION) + 9) / ((bottom - top) / height))
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
	local slowMotion = not self.reducedMotion and simulation.finished == true and simulation.reason == "ringout"
		and self.realClock - self.finishReal < 0.45
	if slowMotion then dt = dt * 0.35 end
	self.clock = self.clock + dt
	self.shake = self.shake * math.exp(-9 * realDt)
	self.punch = self.punch * math.exp(-6 * realDt)
	self.screenFlash = self.screenFlash * math.exp(-11 * realDt)
	self.hype = self.hype * math.exp(-0.9 * realDt)
	self.grade.Brightness = self.screenFlash * 0.16
	self.grade.Contrast = 0.06 + self.screenFlash * 0.2
	self.grade.Saturation = slowMotion and -0.3 or 0.14
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
			fighter.position, fighter.fall = nil, nil
			fighter.label.Text = ""
		end
	end
	if shown then self:_events(simulation) end
	self:_platform(shown and simulation or {}, realDt)
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
