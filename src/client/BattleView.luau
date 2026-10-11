--!nonstrict
-- Local presentation for Battle Lab. Simulation owns every hit and outcome.
-- The caller owns the render connection and must skip its normal flight camera
-- while calling update. viewportRect uses Camera.ViewportSize pixel coordinates.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local BattleView = {}
BattleView.__index = BattleView

local ORIGIN = Vector3.new(0, 80, -4000)
local SCALE = 1.5
local MIN_X, MAX_X, MIN_Y, MAX_Y = -72, 72, 8, 96
local CENTER_Y = (MIN_Y + MAX_Y) / 2
local COLORS = {
	coral = Color3.fromRGB(255, 104, 102), cyan = Color3.fromRGB(66, 225, 239),
	cream = Color3.fromRGB(255, 245, 217), yellow = Color3.fromRGB(255, 212, 80),
	fire = Color3.fromRGB(255, 145, 54), boost = Color3.fromRGB(161, 246, 255),
	navy = Color3.fromRGB(20, 35, 59), dark = Color3.fromRGB(12, 22, 39),
	grid = Color3.fromRGB(39, 62, 83), steel = Color3.fromRGB(60, 86, 104),
	purple = Color3.fromRGB(184, 138, 255), ink = Color3.fromRGB(14, 22, 44),
	skyTop = Color3.fromRGB(30, 78, 186), skyMid = Color3.fromRGB(78, 158, 236),
	horizon = Color3.fromRGB(255, 216, 176), cloud = Color3.fromRGB(255, 247, 232),
	cloudShade = Color3.fromRGB(255, 205, 196), deck = Color3.fromRGB(38, 58, 92),
	storm = Color3.fromRGB(86, 64, 150),
}
-- Same order as the hangar's paint swatch, so a pilot's paint carries over.
-- Each power owns one colour, so a glance says which one just fired.
local POWER = {
	pinball = Color3.fromRGB(80, 215, 255), fizz = Color3.fromRGB(96, 255, 190),
	magnet = Color3.fromRGB(255, 96, 200), wind = Color3.fromRGB(150, 255, 120),
	burner = Color3.fromRGB(120, 200, 255), bumper = Color3.fromRGB(215, 255, 80),
}
local PLANE_COLORS = { COLORS.coral, COLORS.cyan, COLORS.yellow, COLORS.purple }
local PLAYER_COLORS = { COLORS.coral, COLORS.cyan }
local FAN_COLORS = { COLORS.coral, COLORS.cyan, COLORS.yellow, COLORS.cream, COLORS.purple }
local FULL_WIDTH, FULL_HEIGHT = 172, 112
-- The lens rests fairly wide and only closes in while someone is attacking.
local REST_VIEW_WIDTH, REST_VIEW_HEIGHT = 126, 80
local ATTACK_VIEW_WIDTH, ATTACK_VIEW_HEIGHT = 94, 60
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local BURST_LIMIT = 6
local EFFECT_LIMIT, ROCKET_LIMIT, WAKE_LIMIT = 10, 24, 12

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

local function ellipsoid(parent, name, size, pose, color, material)
	local object = part(parent, name, size, pose, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = object
	return object
end

local function arenaPose(x, y, z)
	return CFrame.new(ORIGIN + Vector3.new(x, y, z or 0))
end

local function numeric(value, fallback)
	return type(value) == "number" and value == value and math.abs(value) < 1e7 and value or fallback
end

local function hide(pieces)
	for _, piece in ipairs(pieces) do piece.Transparency = 1 end
end

local function makeRing(parent, name, count, color)
	local pieces = {}
	for index = 1, count do
		pieces[index] = part(parent, name, Vector3.one, CFrame.identity, color, Enum.Material.Neon)
		pieces[index].Transparency = 1
	end
	return pieces
end

local function ring(pieces, center, radius, color, transparency, rotation, thickness)
	for index, piece in ipairs(pieces) do
		local angle = index / #pieces * math.pi * 2 + (rotation or 0)
		piece.Size = Vector3.new(math.max(0.1, 2 * radius * math.sin(math.pi / #pieces) * 0.78), thickness or 0.35, 0.18)
		piece.CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0))
			* CFrame.Angles(0, 0, angle + math.pi / 2)
		piece.Color, piece.Transparency = color, transparency
	end
end

local function makeWake(parent)
	local disc = part(parent, "FizzyFuelHazard", Vector3.one, CFrame.identity, COLORS.fire, Enum.Material.Neon, Enum.PartType.Cylinder)
	disc.Transparency = 1
	return { disc = disc, edge = makeRing(parent, "WakeBoundary", 8, COLORS.fire) }
end

local function hideWake(wake)
	wake.disc.Transparency = 1
	hide(wake.edge)
end

local function poseForVelocity(position, vx, vy, facing, bank)
	-- Plane geometry points along local +X. Yaw when facing left preserves the
	-- cockpit above the wings instead of flipping the aircraft upside down.
	-- Yaw(pi) * Rz(pitch) maps the nose to (-cos(pitch), sin(pitch), 0),
	-- so positive vertical velocity correctly pitches UP on either heading.
	local pitch = math.clamp(math.atan2(vy, math.max(0.1, math.abs(vx))), -1.5, 1.5)
	return CFrame.new(position) * CFrame.Angles(0, facing < 0 and math.pi or 0, 0)
		* CFrame.Angles(0, 0, pitch) * CFrame.Angles(bank or 0.22, 0, 0)
end

local function chargeProgress(fighter, state, sampleAge)
	local duration = math.max(0.01, numeric(state.windupDuration, fighter.observedWindupDuration or 1))
	return math.clamp(1 - (numeric(state.phaseLeft, duration) - sampleAge) / duration, 0, 1)
end

local function solidBottom(geometry, rotation)
	local bottom = math.huge
	for _, solid in ipairs(geometry) do
		local pose = rotation * solid.pose
		local half = solid.half
		local extent = math.abs(pose.RightVector.Y) * half.X
			+ math.abs(pose.UpVector.Y) * half.Y + math.abs(pose.LookVector.Y) * half.Z
		bottom = math.min(bottom, pose.Position.Y - extent)
	end
	return bottom < math.huge and bottom or -3
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
	-- A painted late-afternoon sky above a cloud sea. Everything is far behind
	-- the combat plane, so the moving camera gets parallax for free.
	local sky = part(scenery, "Sky", Vector3.new(2048, 1500, 4), arenaPose(0, CENTER_Y + 150, -270), COLORS.skyMid)
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
		ColorSequenceKeypoint.new(0, COLORS.skyTop), ColorSequenceKeypoint.new(0.56, COLORS.skyMid),
		ColorSequenceKeypoint.new(0.67, COLORS.horizon), ColorSequenceKeypoint.new(1, COLORS.cloudShade),
	})
	gradient.Parent = wash
	local sun = ellipsoid(scenery, "Sun", Vector3.new(56, 56, 3), arenaPose(-120, CENTER_Y + 62, -262), COLORS.cream, Enum.Material.Neon)
	sun.Transparency = 0.1
	local halo = ellipsoid(scenery, "SunHalo", Vector3.new(150, 150, 3), arenaPose(-120, CENTER_Y + 62, -265), COLORS.horizon, Enum.Material.Neon)
	halo.Transparency = 0.72
	local clouds = {}
	local function cloud(x, y, z, size, drift)
		local model = Instance.new("Model")
		model.Name = "Cloud"
		model.Parent = scenery
		local core = ellipsoid(model, "Puff", Vector3.new(size * 2.2, size * 0.8, size * 0.6), arenaPose(x, y, z), COLORS.cloud)
		model.PrimaryPart = core
		ellipsoid(model, "Puff", Vector3.new(size * 1.3, size * 0.95, size * 0.6), arenaPose(x - size * 0.42, y + size * 0.26, z + 0.4), COLORS.cloud)
		ellipsoid(model, "Puff", Vector3.new(size * 1.1, size * 0.75, size * 0.6), arenaPose(x + size * 0.5, y + size * 0.16, z + 0.2), COLORS.cloud)
		ellipsoid(model, "Shade", Vector3.new(size * 1.9, size * 0.34, size * 0.5), arenaPose(x + size * 0.05, y - size * 0.24, z + 0.6), COLORS.cloudShade)
		table.insert(clouds, { model = model, x = x, y = y, z = z, drift = drift, span = 300 + math.abs(z) * 1.5 })
	end
	-- Deterministic scatter: near clouds are large and quick, far ones slow.
	local seed = 11
	local function roll()
		seed = (seed * 16807) % 2147483647
		return (seed - 1) / 2147483646
	end
	for layer, depth in ipairs({ -50, -100, -160, -225 }) do
		for _ = 1, 5 do
			local span = 300 + math.abs(depth) * 1.5
			cloud((roll() * 2 - 1) * span, CENTER_Y - 30 + roll() * (100 + layer * 20), depth - roll() * 14,
				14 + layer * 6 + roll() * 10, (1.6 + roll() * 1.4) * (5 - layer) * 0.6)
		end
	end
	-- The cloud sea the arena floats above.
	for index = 1, 12 do
		local z = -34 - (index % 4) * 40
		local span = 300 + math.abs(z) * 1.5
		cloud((roll() * 2 - 1) * span, MIN_Y - 24 - (index % 3) * 9, z, 44 + roll() * 30, 1.2 + roll())
	end
	return clouds
end

local function makeStands(scenery)
	-- Two bleachers behind the deck. Each row is one model so a whole row can
	-- bounce with a single pivot when the crowd reacts.
	local rows = {}
	for sideIndex, side in ipairs({ -1, 1 }) do
		local accent = PLAYER_COLORS[sideIndex]
		for row = 1, 3 do
			local model = Instance.new("Model")
			model.Name = "CrowdRow"
			model.Parent = scenery
			local y, z = MIN_Y - 3.4 + row * 3.1, -9 - row * 4.2
			local bench = part(model, "Bench", Vector3.new(58, 1.1, 4), arenaPose(side * 41, y - 1.6, z), row % 2 == 0 and COLORS.deck or COLORS.steel)
			model.PrimaryPart = bench
			for seat = 1, 13 do
				local x = side * 41 - 27 + (seat - 0.5) * 54 / 13 + (row % 2) * 1.6
				local color = (seat + row) % 3 == 0 and accent or FAN_COLORS[(seat * 3 + row * 2 + sideIndex) % #FAN_COLORS + 1]
				part(model, "Fan", Vector3.new(2.4, 2.4, 2.4), arenaPose(x, y, z), color, nil, Enum.PartType.Ball)
				part(model, "FanBody", Vector3.new(2.1, 1.7, 1.6), arenaPose(x, y - 1.6, z), color:Lerp(COLORS.ink, 0.25))
			end
			table.insert(rows, { model = model, base = bench.CFrame, phase = row * 1.3 + sideIndex * 0.7 })
		end
		part(scenery, "StandBack", Vector3.new(62, 15, 2), arenaPose(side * 41, MIN_Y + 2.5, -25), COLORS.deck)
		part(scenery, "StandBanner", Vector3.new(62, 1.6, 0.6), arenaPose(side * 41, MIN_Y + 10.4, -24), accent, Enum.Material.Neon)
	end
	return rows
end

local function makeArena(parent)
	local scenery = Instance.new("Folder")
	scenery.Name = "Stadium"
	scenery.Parent = parent
	local clouds = makeSky(scenery)
	local crowd = makeStands(scenery)
	-- A floating flight deck with tall light pylons marks the shared combat
	-- plane. The side rails are the real bounce walls; nothing here collides.
	for _, side in ipairs({ -1, 1 }) do
		for _, y in ipairs({ MIN_Y - 4, MAX_Y + 4 }) do
			part(scenery, "CornerBrace", Vector3.new(11, 2.4, 3), arenaPose(side * 74, y, -6), COLORS.steel)
			local lamp = part(scenery, "StadiumLamp", Vector3.new(6.5, 0.9, 0.9), arenaPose(side * 74, y, -3.8),
				side < 0 and COLORS.coral or COLORS.cyan, Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Color, light.Brightness, light.Range = lamp.Color, 0.45, 38
			light.Shadows = false
			light.Parent = lamp
		end
	end
	part(scenery, "Floor", Vector3.new(170, 5, 30), arenaPose(0, MIN_Y - 5, -6), COLORS.deck)
	part(scenery, "FloorKeel", Vector3.new(120, 9, 18), arenaPose(0, MIN_Y - 11, -8), COLORS.ink)
	local floorLip = part(scenery, "FloorLip", Vector3.new(160, 0.7, 1.2), arenaPose(0, MIN_Y - 2.1, 9), COLORS.cream)
	for index = -3, 3 do
		part(scenery, "FloorInset", Vector3.new(13, 0.2, 1), arenaPose(index * 21, MIN_Y - 2.25, 4),
			index < 0 and COLORS.coral or (index > 0 and COLORS.cyan or COLORS.yellow), Enum.Material.Neon)
	end
	for index = -7, 7 do
		part(scenery, "DeckStripe", Vector3.new(5, 0.12, 9), arenaPose(index * 11, MIN_Y - 2.45, -4), COLORS.cream).Transparency = 0.55
	end
	local edges = {}
	for index, x in ipairs({ MIN_X, MAX_X }) do
		part(scenery, "Pylon" .. index, Vector3.new(2.6, 104, 5), arenaPose(x + (index == 1 and -3.4 or 3.4), CENTER_Y, -4), COLORS.deck)
		part(scenery, "PylonCap" .. index, Vector3.new(5, 3, 6), arenaPose(x + (index == 1 and -3.4 or 3.4), MAX_Y + 8, -4), COLORS.cream)
		edges[index] = part(scenery, "SideBoundary" .. index, Vector3.new(0.9, 88, 0.6), arenaPose(x, CENTER_Y, -2), PLAYER_COLORS[index], Enum.Material.Neon)
		edges[index].Transparency = 0.2
		for y = MIN_Y, MAX_Y, 22 do
			part(scenery, "BoundaryTick", Vector3.new(2.2, 0.4, 0.5), arenaPose(x + (index == 1 and -1.8 or 1.8), y, -2), COLORS.cream)
		end
	end
	edges[3] = part(scenery, "CeilingBoundary", Vector3.new(144, 0.5, 0.5), arenaPose(0, MAX_Y, -2), COLORS.cream, Enum.Material.Neon)
	edges[4] = part(scenery, "FloorBoundary", Vector3.new(144, 0.5, 0.5), arenaPose(0, MIN_Y, -2), COLORS.cream, Enum.Material.Neon)
	local wind = {}
	for index = 1, 4 do
		wind[index] = part(scenery, "WindPressure" .. index, Vector3.one, arenaPose(0, CENTER_Y, -5), COLORS.storm, Enum.Material.Neon)
		wind[index].Transparency = 1
	end
	return edges, wind, floorLip, clouds, crowd
end

local function makeRocket(parent)
	local model = Instance.new("Model")
	model.Name = "BattleRocket"
	model.Parent = parent
	local body = part(model, "Body", Vector3.new(5, 1.65, 1.65), CFrame.identity, COLORS.cream, nil, Enum.PartType.Cylinder)
	model.PrimaryPart = body
	local nose = part(model, "Warhead", Vector3.new(2, 2, 2), CFrame.new(2.4, 0, 0), COLORS.coral, nil, Enum.PartType.Ball)
	local fin = part(model, "Fins", Vector3.new(1.6, 3.2, 0.3), CFrame.new(-1.65, 0, 0), COLORS.coral)
	local crossFin = part(model, "CrossFins", Vector3.new(1.6, 0.3, 3.2), CFrame.new(-1.65, 0, 0), COLORS.coral)
	local exhaust = ellipsoid(model, "Exhaust", Vector3.new(3.5, 1.1, 1.1), CFrame.new(-4, 0, 0), COLORS.fire, Enum.Material.Neon)
	local core = ellipsoid(model, "ExhaustCore", Vector3.new(2.6, 0.55, 0.55), CFrame.new(-3.5, 0, 0), COLORS.cream, Enum.Material.Neon)
	-- The same pooled projectile can be a rocket, a tracer or Pinball's ball.
	local ball = part(model, "PinballBall", Vector3.one * 6.4, CFrame.identity, POWER.pinball, Enum.Material.Neon, Enum.PartType.Ball)
	local ballCore = part(model, "PinballCore", Vector3.one * 3.4, CFrame.new(0, 0, 0.4), COLORS.cream, Enum.Material.Neon, Enum.PartType.Ball)
	local stripes = {}
	local pieces = { body, nose, fin, crossFin, exhaust, core, ball, ballCore }
	for _, x in ipairs({ -0.8, 0.65 }) do
		local stripe = part(model, "CandyStripe", Vector3.new(0.45, 1.72, 1.72), CFrame.new(x, 0, 0), COLORS.coral, nil, Enum.PartType.Cylinder)
		table.insert(stripes, stripe)
		table.insert(pieces, stripe)
	end
	local sparks = {}
	for index = 1, 3 do
		sparks[index] = part(model, "RocketSpark", Vector3.one * 0.35, CFrame.identity, COLORS.yellow, Enum.Material.Neon)
		table.insert(pieces, sparks[index])
	end
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(-2.5, -0.6, 0)
	a.Parent = body
	local b = Instance.new("Attachment")
	b.Position = Vector3.new(-2.5, 0.6, 0)
	b.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a, b
	trail.Color = ColorSequence.new(COLORS.yellow, COLORS.cream)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Lifetime = 0.7
	trail.LightEmission = 0.9
	trail.MinLength = 0.15
	trail.Parent = body
	local fizz = emitter(a, "RocketFizz", SPARK_TEXTURE, {
		Lifetime = NumberRange.new(0.35, 0.7), Speed = NumberRange.new(2, 9), Size = fade(1.5, 0),
		LightEmission = 1, Color = ColorSequence.new(COLORS.yellow, COLORS.fire), ZOffset = 1,
	})
	return { ball = ball, ballCore = ballCore, fizz = fizz, model = model, body = body, nose = nose, fin = fin, crossFin = crossFin, trail = trail, pieces = pieces,
		stripes = stripes, sparks = sparks, exhaust = exhaust, core = core }
end

-- options.pilots seats avatars in the cockpits (PilotAvatar module).
function BattleView.new(World, onPresentationCue, options)
	local self = setmetatable({
		World = World, fighters = {}, rockets = {}, rocketPool = {}, effects = {}, wakes = {}, wakePool = {},
		effectCursor = 0, roundId = nil, lastEvent = 0, clock = 0, realClock = 0,
		sampleElapsed = nil, sampleAge = 0, destroyed = false,
		shake = 0, punch = 0, freeze = 0, screenFlash = 0, hype = 0, bursts = {}, burstCursor = 0,
		onPresentationCue = type(onPresentationCue) == "function" and onPresentationCue or nil,
		pilots = type(options) == "table" and options.pilots or nil,
		-- SkillCatalog, for the words a skill shouts. Optional in tests.
		skills = type(options) == "table" and options.skills or nil,
	}, BattleView)
	pcall(function() self.reducedMotion = GuiService.ReducedMotionEnabled end)
	self.folder = Instance.new("Folder")
	self.folder.Name = "SkyboundBattleView"
	self.folder.Parent = Workspace
	self.edges, self.wind, self.floorLip, self.clouds, self.crowd = makeArena(self.folder)
	-- The closing wind is drawn as bright streaks blowing in from each rail.
	-- The sky itself stays sunny: no storm clouds, no darkened grade.
	self.windStreaks = {}
	for side = 1, 4 do
		self.windStreaks[side] = {}
		for n = 1, 5 do
			local streak = part(self.folder, "InwardWind", Vector3.one, CFrame.identity, COLORS.cream, Enum.Material.Neon)
			streak.Transparency = 1; self.windStreaks[side][n] = streak
		end
	end
	-- Glow and grade belong to this view and leave with it.
	self.bloom = Instance.new("BloomEffect")
	self.bloom.Name = "SkyboundBattleBloom"
	self.bloom.Intensity, self.bloom.Size, self.bloom.Threshold = 0.55, 24, 1.1
	self.bloom.Parent = Lighting
	self.grade = Instance.new("ColorCorrectionEffect")
	self.grade.Name = "SkyboundBattleGrade"
	self.grade.Saturation, self.grade.Contrast = 0.14, 0.06
	self.grade.Parent = Lighting
	self.fxAnchor = part(self.folder, "ParticleAnchor", Vector3.one, CFrame.new(ORIGIN), COLORS.cream)
	self.fxAnchor.Transparency = 1
	self.groundY = self.floorLip.Position.Y + self.floorLip.Size.Y / 2
	self.folder:SetAttribute("GroundY", self.groundY)
	self.dynamic = Instance.new("Folder")
	self.dynamic.Name = "Combat"
	self.dynamic.Parent = self.folder
	return self
end

function BattleView:_resetRound(roundId)
	self.roundId, self.lastEvent, self.sampleElapsed, self.sampleAge = roundId, 0, nil, 0
	self.finishTime, self.finishReal = nil, nil
	self.shake, self.punch, self.freeze, self.screenFlash = 0, 0, 0, 0
	self.grade.Brightness, self.grade.Contrast, self.grade.Saturation = 0, 0.06, 0.14
	for side = 1, 4 do hide(self.windStreaks[side]) end
	for _, fighter in pairs(self.fighters) do
		fighter.damageSmoke.Rate, fighter.damageFire.Rate = 0, 0
		fighter.damageSmoke:Clear()
		fighter.damageFire:Clear()
		fighter.position, fighter.pose, fighter.armor = nil, nil, nil
		fighter.hitTime, fighter.blockTime, fighter.lastHitBurst = -100, -100, -100
		fighter.shotTime, fighter.secondWindTime, fighter.magnetTime = -100, -100, -100
		fighter.finishRotation, fighter.finishPosition = nil, nil
		fighter.crash, fighter.crashLanded, fighter.crashContactY = nil, false, nil
		fighter.crashGroundY = nil
		fighter.previousPhase, fighter.observedWindupDuration = nil, nil
		fighter.model:SetAttribute("CrashState", nil)
		fighter.model:SetAttribute("CrashContactY", nil)
		fighter.scuff.Transparency = 1
		hide(fighter.debris)
		hide(fighter.reticle)
		hide(fighter.aimDots)
		hide(fighter.statusRing)
		hide(fighter.speedLines)
		hide(fighter.magnetRing)
		hide(fighter.windRing)
		hide(fighter.loadRing)
		hide(fighter.burnerFlames)
		hide(fighter.magnetGrip)
		fighter.magnetBeam.Transparency, fighter.windAura.Transparency = 1, 1
		fighter.approachSpan = nil
		hide(fighter.cometFlames)
		hide(fighter.signatureSparks)
		hide(fighter.muzzleFlashes)
		for _, ghost in ipairs(fighter.afterimages or {}) do hide(ghost.pieces) end
		fighter.chargeShell.Transparency = 1
		fighter.noseLight.Brightness = 0
		fighter.trail.Enabled = false
		fighter.trail:Clear()
	end
	for id, wake in pairs(self.wakes) do
		hideWake(wake)
		table.insert(self.wakePool, wake)
		self.wakes[id] = nil
	end
	for id, rocket in pairs(self.rockets) do
		rocket.trail.Enabled = false
		rocket.trail:Clear()
		rocket.fizz.Rate = 0
		for _, piece in ipairs(rocket.pieces) do piece.Transparency = 1 end
		table.insert(self.rocketPool, rocket)
		self.rockets[id] = nil
	end
	for _, burst in ipairs(self.bursts) do
		burst.spark:Clear()
		burst.smoke:Clear()
		burst.fire:Clear()
	end
	for _, effect in ipairs(self.effects) do
		effect.active = false
		hide(effect.pieces)
		hide(effect.ring)
		effect.flash.Transparency = 1
	end
end

-- Server snapshots map the recipient to side one and preserve both identities.
-- Paint never distinguishes sides by changing someone's equipped appearance.
function BattleView:_look(index)
	local player = Players.LocalPlayer
	local identity = self.identities and self.identities[index]
	local look
	if identity then
		look = { colorIndex = math.clamp(math.floor(numeric(identity.color, 1)), 1, #PLANE_COLORS),
			planeId = identity.planeId or "cruiser", trailId = identity.trailId,
			userId = not identity.bot and identity.userId or nil, name = identity.name, bot = identity.bot }
	elseif index == 1 and player then
		look = { colorIndex = math.clamp(math.floor(numeric(player:GetAttribute("SkyboundColor"), 1)), 1, #PLANE_COLORS),
			planeId = player:GetAttribute("SkyboundPlane") or "cruiser", trailId = player:GetAttribute("SkyboundTrail"), userId = player.UserId }
	else look = { colorIndex = 2, planeId = "dart", bot = true } end
	look.color = PLANE_COLORS[look.colorIndex]
	look.trailColor, look.trailLife, look.trailEmission, look.trailWidth =
		ColorSequence.new(look.color, COLORS.cream), 0.55, 0.6, 1
	if self.World.trailLook then
		local ok, first, second, entry = pcall(self.World.trailLook, look.trailId)
		if ok and entry then
			look.trailColor = ColorSequence.new(first, second)
			look.trailLife = 0.4 + numeric(entry.lifetime, 0.6) * 0.5
			look.trailEmission = numeric(entry.emission, 0.6)
			look.trailWidth = numeric(entry.width, 1)
		end
	end
	return look
end

-- A mount offset is relative to the model pivot after its one display scale.
local function mount(fighter, name)
	local attachment = fighter.model.PrimaryPart:FindFirstChild(name)
	assert(attachment and attachment:IsA("Attachment"), "Battle skin missing mount: " .. name)
	return fighter.model:GetPivot():ToObjectSpace(attachment.WorldCFrame)
end

-- Both pilots' paints, for a HUD that matches the planes.
function BattleView:accent(index)
	local fighter
	for _, candidate in pairs(self.fighters) do
		if candidate.index == index then fighter = candidate end
	end
	return fighter and fighter.color or self:_look(index).color
end

function BattleView:_fighter(id, index)
	local fighter = self.fighters[id]
	if fighter then return fighter end
	local look = self:_look(index)
	local color = look.color
	local model = self.World.createPlane(self.dynamic, "BattlePlane" .. tostring(id), look.colorIndex, look.planeId, look.trailId)
	model:ScaleTo(SCALE)
	local pivot = model.PrimaryPart
	local trail = pivot:FindFirstChild("Contrail")
	if not trail then
		trail = Instance.new("Trail"); trail.Name = "Contrail"; trail.Parent = pivot
		local first, last = Instance.new("Attachment"), Instance.new("Attachment")
		first.Parent, last.Parent = pivot, pivot; trail.Attachment0, trail.Attachment1 = first, last
	end
	-- The shared racing trail spans the wing axis, which is edge-on here. Give
	-- it vertical separation for a readable ribbon in the side camera.
	local tail = pivot:FindFirstChild("Tail")
	assert(tail and tail:IsA("Attachment"), "Battle skin missing Tail")
	trail.Attachment0.Position = tail.Position + Vector3.new(0, -0.75 * look.trailWidth, 0) * SCALE
	trail.Attachment1.Position = tail.Position + Vector3.new(0, 0.75 * look.trailWidth, 0) * SCALE
	trail.Color = look.trailColor
	trail.Transparency = NumberSequence.new(0.12, 1)
	trail.Lifetime = look.trailLife
	trail.LightEmission = look.trailEmission
	trail.WidthScale = NumberSequence.new(1, 0)
	if self.pilots then
		pcall(self.pilots.attach, model, look.userId, look.userId == nil)
	end
	local noseGlow = part(model, "ArmedNose", Vector3.one * 2.7, pivot.Nose.WorldCFrame, color, Enum.Material.Neon, Enum.PartType.Ball)
	noseGlow.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "AttackTell"
	gui.Adornee = pivot:FindFirstChild("Top") or pivot
	gui.Size = UDim2.fromOffset(260, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 10000
	gui.Enabled = false
	gui.Parent = pivot
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 26
	label.TextColor3 = COLORS.cream
	label.TextTransparency = 0
	label.Rotation = index == 1 and -5 or 5
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Color = 3.5, COLORS.ink
	stroke.Parent = label
	local pop = Instance.new("UIScale")
	pop.Parent = label
	local identityGui = Instance.new("BillboardGui")
	identityGui.Name = "PilotIdentity"; identityGui.Adornee = pivot:FindFirstChild("Top") or pivot
	identityGui.Size = UDim2.fromOffset(180, 26); identityGui.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	identityGui.AlwaysOnTop = true; identityGui.MaxDistance = 10000; identityGui.Parent = pivot
	local identityText = Instance.new("TextLabel")
	identityText.BackgroundTransparency = 1; identityText.Size = UDim2.fromScale(1, 1)
	identityText.Font = Enum.Font.FredokaOne; identityText.TextSize = index == 1 and 18 or 15
	identityText.Text = index == 1 and "▼ YOU" or string.upper(look.name or "RIVAL")
	identityText.TextColor3 = index == 1 and COLORS.yellow or COLORS.cream
	identityText.TextTruncate = Enum.TextTruncate.AtEnd; identityText.Parent = identityGui
	local identityEdge = Instance.new("UIStroke"); identityEdge.Thickness = 3; identityEdge.Color = COLORS.ink; identityEdge.Parent = identityText
	-- Always on: a dark ink outline makes any paint read against the sky. A hit
	-- fills it white for an instant; the winner's outline turns gold.
	local highlight = Instance.new("Highlight")
	highlight.Name = "CombatFeedback"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	local sideColor = index == 1 and Color3.fromRGB(87, 224, 248) or Color3.fromRGB(255, 141, 119)
	highlight.FillTransparency, highlight.OutlineColor, highlight.OutlineTransparency = 1, COLORS.ink, 0
	highlight.Parent = model
	-- Keep the FX outside the aircraft model so the full-model hit highlight
	-- cannot accidentally outline distant aim markers or a victory halo.
	local fx = Instance.new("Folder")
	fx.Name = "FighterEffects" .. tostring(id)
	fx.Parent = self.dynamic
	local chargeShell = ellipsoid(fx, "MeteorChargeShell", Vector3.one, CFrame.identity, COLORS.fire, Enum.Material.Neon)
	chargeShell.Transparency = 1
	local cometFlames = {}
	for index = 1, 3 do
		cometFlames[index] = ellipsoid(fx, "CometFlame" .. index, Vector3.one, CFrame.identity,
			index == 1 and COLORS.fire or (index == 2 and COLORS.yellow or COLORS.cream), Enum.Material.Neon)
		cometFlames[index].Transparency = 1
	end
	local burnerFlames = {}
	for index = 1, 3 do
		burnerFlames[index] = ellipsoid(fx, "AfterburnerFlame" .. index, Vector3.one, CFrame.identity,
			index == 1 and POWER.burner or (index == 2 and COLORS.boost or COLORS.cream), Enum.Material.Neon)
		burnerFlames[index].Transparency = 1
	end
	local magnetBeam = part(fx, "MagnetBeam", Vector3.one, CFrame.identity, POWER.magnet, Enum.Material.Neon)
	magnetBeam.Transparency = 1
	local windAura = ellipsoid(fx, "SecondWindAura", Vector3.one, CFrame.identity, POWER.wind, Enum.Material.ForceField)
	windAura.Transparency = 1
	local muzzleFlashes = {}
	for index = 1, 2 do
		muzzleFlashes[index] = ellipsoid(fx, "LauncherFlash" .. index, Vector3.one, CFrame.identity, COLORS.yellow, Enum.Material.Neon)
		muzzleFlashes[index].Transparency = 1
	end
	local lampAnchor = part(fx, "PowerLamp", Vector3.one, CFrame.identity, color)
	lampAnchor.Transparency = 1
	local noseLight = Instance.new("PointLight")
	noseLight.Color, noseLight.Range, noseLight.Brightness = COLORS.fire, 16, 0
	noseLight.Shadows = false
	noseLight.Parent = lampAnchor
	local smokeAnchor = part(fx, "DamageAnchor", Vector3.one, CFrame.identity, color)
	smokeAnchor.Transparency = 1
	local smokeAt = Instance.new("Attachment")
	smokeAt.Parent = smokeAnchor
	local damageSmoke = emitter(smokeAt, "DamageSmoke", SMOKE_TEXTURE, {
		Lifetime = NumberRange.new(0.7, 1.3), Speed = NumberRange.new(2, 6), Size = fade(2.4, 7),
		Transparency = fade(0.35, 1), Color = ColorSequence.new(Color3.fromRGB(58, 60, 74), Color3.fromRGB(120, 122, 136)),
		Acceleration = Vector3.new(0, 9, 0), RotSpeed = NumberRange.new(-70, 70), Rotation = NumberRange.new(0, 360),
		SpreadAngle = Vector2.new(25, 25), Enabled = true,
	})
	local damageFire = emitter(smokeAt, "DamageFire", FIRE_TEXTURE, {
		Lifetime = NumberRange.new(0.25, 0.5), Speed = NumberRange.new(3, 8), Size = fade(3.4, 0.4),
		Transparency = fade(0.1, 1), Color = ColorSequence.new(COLORS.yellow, COLORS.fire), LightEmission = 1,
		Acceleration = Vector3.new(0, 6, 0), SpreadAngle = Vector2.new(30, 30), ZOffset = 0.5, Enabled = true,
	})
	local scuff = ellipsoid(fx, "CrashScuff", Vector3.new(12, 0.6, 0.25), CFrame.identity, COLORS.dark)
	scuff.Transparency = 1
	local debris = makeRing(fx, "CrashDebris", 5, color)
	for index, fragment in ipairs(debris) do
		fragment.Material = Enum.Material.SmoothPlastic
		fragment.Color = index % 2 == 0 and COLORS.steel or color
	end
	fighter = {
		model = model, color = color, sideColor = sideColor, visualScale = math.clamp(numeric(model:GetAttribute("BattleVisualSize"), 12) / 12, 0.8, 1.25),
		body = model:FindFirstChild("Fuselage") or pivot,
		propeller = model:FindFirstChild("Propeller"), trail = trail,
		flare = model:FindFirstChild("FlightFlare"), noseGlow = noseGlow,
		smoke = { model:FindFirstChild("HitSmoke1"), model:FindFirstChild("HitSmoke2"), model:FindFirstChild("HitSmoke3") },
		gui = gui, label = label, pop = pop, stroke = stroke, look = look,
		smokeAnchor = smokeAnchor, damageSmoke = damageSmoke, damageFire = damageFire,
		hitTime = -100, blockTime = -100, lastHitBurst = -100, tellTime = -100,
		facing = index == 1 and 1 or -1, highlight = highlight, fx = fx,
		reticle = makeRing(fx, "AttackLock", 8, color),
		aimDots = makeRing(fx, "AimDash", 3, color),
		statusRing = makeRing(fx, "BumperOrVictory", 12, COLORS.yellow),
		speedLines = makeRing(fx, "AfterburnerStreak", 2, COLORS.boost),
		chargeShell = chargeShell, cometFlames = cometFlames, muzzleFlashes = muzzleFlashes,
		signatureSparks = makeRing(fx, "SignatureSpark", 8, COLORS.yellow),
		lampAnchor = lampAnchor, noseLight = noseLight, shotTime = -100, secondWindTime = -100, magnetTime = -100,
		magnetRing = makeRing(fx, "MagnetPull", 10, Color3.fromRGB(255, 120, 190)),
		windRing = makeRing(fx, "SecondWind", 10, Color3.fromRGB(130, 255, 190)),
		loadRing = makeRing(fx, "AttackLoad", 10, color),
		burnerFlames = burnerFlames, magnetBeam = magnetBeam, magnetGrip = makeRing(fx, "MagnetGrip", 8, POWER.magnet),
		windAura = windAura,
		scuff = scuff, debris = debris, crashLanded = false, index = index,
	}
	-- Smoke is positioned in world space and must never enlarge aircraft
	-- bounds or the damage highlight while a disabled plane falls.
	for _, puff in ipairs(fighter.smoke) do puff.Parent = fx end
	-- Two bounded silhouettes copy this exact equipped skin. They are purely
	-- translucent trailing images, without trails, pilots or particle emitters.
	fighter.afterimages = {}
	for number = 1, 2 do
		local ghost = Instance.new("Model"); ghost.Name = "SkinAfterimage" .. number; ghost.Parent = fx
		local pieces = {}
		for _, original in ipairs(model:GetChildren()) do
			if original:IsA("BasePart") and original.Transparency < 0.5 then
				local copy = original:Clone()
				for _, child in ipairs(copy:GetChildren()) do if not child:IsA("DataModelMesh") then child:Destroy() end end
				copy.Anchored, copy.CanCollide, copy.CanTouch, copy.CanQuery = true, false, false, false
				copy.Material = Enum.Material.Neon; copy.Color = fighter.color; copy.Transparency = 1; copy.Parent = ghost
				pieces[#pieces + 1] = copy
			end
		end
		ghost.WorldPivot = model:GetPivot()
		fighter.afterimages[number] = { model = ghost, pieces = pieces }
	end
	self.fighters[id] = fighter
	return fighter
end

function BattleView:_crashPose(fighter, state, target)
	local crash = fighter.crash
	if not crash then
		fighter.finishPosition, fighter.finishRotation = target, fighter.pose.Rotation
		fighter.stoppedPropeller = math.pi / 4
		-- Freeze the propeller before sampling the solid geometry. Visual
		-- flames, hidden race wings, and smoke never determine floor contact.
		local modelPose = fighter.model:GetPivot()
		if fighter.propeller then fighter.propeller:PivotTo(modelPose * mount(fighter, "Nose") * CFrame.Angles(fighter.stoppedPropeller, 0, 0)) end
		local geometry = {}
		for _, object in ipairs(fighter.model:GetDescendants()) do
			if object:IsA("BasePart") and object.Transparency < 0.95
				and object.Name ~= "FlightFlare" and object.Name ~= "ArmedNose" then
				table.insert(geometry, { pose = modelPose:ToObjectSpace(object.CFrame), half = object.Size / 2 })
			end
		end
		local clearance = math.max(0, target.Y + solidBottom(geometry, fighter.finishRotation) - self.groundY)
		local roomToFall = math.clamp(clearance / 16, 0, 1)
		local drift = (math.clamp(numeric(state.vx, 0) * 0.1, -6, 6) + (state.id == 1 and -3 or 3)) * roomToFall
		crash = {
			startedAt = self.clock,
			duration = clearance <= 0.01 and 0 or ((0.32 + roomToFall * 0.63) + math.clamp((clearance - 16) / 54, 0, 1) * 0.4),
			geometry = geometry, clearance = clearance, smoke = {},
			landX = math.clamp(target.X + drift, ORIGIN.X + MIN_X + 13, ORIGIN.X + MAX_X - 13),
			restRotation = CFrame.Angles(0, fighter.facing < 0 and math.pi or 0, 0) * CFrame.Angles(0.06, 0, -0.04),
		}
		fighter.crash, fighter.crashLanded, fighter.crashGroundY = crash, false, self.groundY
		fighter.model:SetAttribute("CrashState", "Falling")
	end
	local progress = crash.duration == 0 and 1 or math.clamp((self.clock - crash.startedAt) / crash.duration, 0, 1)
	-- Touching is landing: a frame that ends a hair above the floor must not
	-- look like contact while the thud and dust wait for the next one.
	if crash.clearance * (1 - progress * progress) < 0.004 then progress = 1 end
	local settle = math.clamp((progress - 0.64) / 0.36, 0, 1)
	settle = settle * settle * (3 - 2 * settle)
	local rotation
	if crash.clearance < 16 then
		-- There is no room for a somersault immediately above the floor.
		-- A brief belly-down settle reaches first contact with the thud.
		rotation = fighter.finishRotation:Lerp(crash.restRotation, progress * progress * (3 - 2 * progress))
	else
		local spin = math.clamp((progress - 0.18) / 0.68, 0, 1)
		rotation = (fighter.finishRotation * CFrame.Angles(0, 0, -math.pi * 2 * spin)):Lerp(crash.restRotation, settle)
	end
	local lower = solidBottom(crash.geometry, rotation)
	-- Descend the lowest solid point, not the pivot. Clamping a tumbling
	-- pivot to the floor can cause early contact followed by a ground spin.
	local clearance = crash.clearance * (1 - progress * progress)
	local position = Vector3.new(fighter.finishPosition.X + (crash.landX - fighter.finishPosition.X) * (1 - (1 - progress) ^ 2),
		self.groundY - lower + clearance, ORIGIN.Z)
	fighter.position = position
	fighter.crashContactY = position.Y + lower
	fighter.model:SetAttribute("CrashContactY", fighter.crashContactY)
	if progress >= 1 then
		if not fighter.crashLanded then
			fighter.crashLanded, crash.landedAt = true, self.clock
			fighter.model:SetAttribute("CrashState", "Landed")
			self:_burst(position.X - ORIGIN.X, self.groundY - ORIGIN.Y + 0.12, COLORS.yellow, true, "crash")
			self:_particles(position.X - ORIGIN.X, self.groundY - ORIGIN.Y + 1.5, COLORS.fire, 50, 22, 18, 60)
			self:_jolt(4, 0.6, 0.06, 0.4, 1)
			fighter.scuff.CFrame = CFrame.new(position.X, self.groundY + 0.05, ORIGIN.Z + 9.8)
			fighter.scuff.Transparency = 0.2
			if self.onPresentationCue then
				local ok, err = pcall(self.onPresentationCue, { kind = "crash", roundId = self.roundId, actor = state.id })
				if not ok then warn("BattleView presentation cue failed: " .. tostring(err)) end
			end
		end
		local scatter = math.clamp((self.clock - crash.landedAt) / 0.45, 0, 1)
		for index, fragment in ipairs(fighter.debris) do
			local side = index % 2 == 0 and -1 or 1
			local angle = index * 0.7 + scatter * side * 2
			fragment.Size = Vector3.new(0.7 + index * 0.13, 0.4, 0.5)
			local extent = math.abs(math.sin(angle)) * fragment.Size.X / 2 + math.abs(math.cos(angle)) * fragment.Size.Y / 2
			fragment.CFrame = CFrame.new(position.X + side * (2 + index * 1.6) * scatter,
				self.groundY + extent + math.sin(scatter * math.pi) * (1.5 + index * 0.3), ORIGIN.Z + 9.8)
				* CFrame.Angles(0, 0, angle)
			fragment.Transparency = 0
		end
	end
	-- One small presentation-only hop after first contact. Near-floor crashes
	-- settle directly; contact attributes/cue still fire on the first touch.
	if fighter.crashLanded and crash.clearance >= 16 then
		local bounce = math.clamp((self.clock - crash.landedAt) / 0.28, 0, 1)
		position = position + Vector3.new(fighter.facing * math.sin(bounce * math.pi) * 0.5, math.sin(bounce * math.pi) * 0.8, 0)
		fighter.position = position
		fighter.crashContactY = position.Y + lower
		fighter.model:SetAttribute("CrashContactY", fighter.crashContactY)
	end
	return CFrame.new(position) * rotation
end

function BattleView:_setSignature(fighter, offenceId)
	if fighter.offenceId == offenceId then return end
	if fighter.signature then fighter.signature:Destroy() end
	fighter.offenceId = offenceId
	fighter.signature = Instance.new("Folder")
	fighter.signature.Name = "Signature"; fighter.signature.Parent = fighter.model
	fighter.chargePieces, fighter.muzzleOffsets = {}, {}
	local pose, size = fighter.model:GetPivot(), fighter.visualScale * SCALE
	local function piece(name, dimensions, mountName, offset, color, material, shape)
		local localPose = mount(fighter, mountName) * CFrame.new(offset * size)
		local item = part(fighter.signature, name, dimensions * size, pose * localPose, color, material, shape)
		return item, localPose.Position
	end
	-- All stock geometry remains visible. A skill is equipment and a tell,
	-- never a replacement fuselage or wing silhouette.
	if offenceId == "Firework" or offenceId == "MachineGun" then
		local gun = offenceId == "MachineGun"
		for _, mountName in ipairs({ "WingLeft", "WingRight" }) do
			piece(gun and "GunBarrel" or "RocketPod", Vector3.new(gun and 2.8 or 3.1, gun and 0.7 or 1.25, gun and 0.7 or 1.25),
				mountName, Vector3.new(0, -0.65, 0), gun and COLORS.steel or COLORS.cream, nil, Enum.PartType.Cylinder)
			local chamber, offset = piece("IgnitionChamber", Vector3.new(0.15, gun and 0.65 or 1.15, gun and 0.65 or 1.15),
				mountName, Vector3.new(gun and 1.45 or 1.6, -0.65, 0), gun and COLORS.yellow or COLORS.fire, Enum.Material.Neon, Enum.PartType.Cylinder)
			table.insert(fighter.chargePieces, chamber); table.insert(fighter.muzzleOffsets, offset)
		end
	elseif offenceId == "Pinball" then
		local cap = piece("ReboundRing", Vector3.new(0.65, 2.9, 2.9), "Nose", Vector3.new(-0.55, 0, 0),
			Color3.fromRGB(110, 220, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
		table.insert(fighter.chargePieces, cap)
	elseif offenceId == "Meteor" then
		piece("ImpactCollar", Vector3.new(0.6, 2.8, 2.8), "Nose", Vector3.new(-0.5, 0, 0), COLORS.yellow, nil, Enum.PartType.Cylinder)
		for _, side in ipairs({ -1, 1 }) do
			local vent = piece("ChargeVent", Vector3.new(1.4, 0.22, 0.32), "Top", Vector3.new(0, 0, side * 0.8), COLORS.yellow, Enum.Material.Neon)
			table.insert(fighter.chargePieces, vent)
		end
	end
	fighter.model:SetAttribute("OffenceId", offenceId)
end

-- One pooled attachment with spark, smoke and fire emitters per impact.
function BattleView:_particles(x, y, color, sparks, smoke, fire, speed)
	self.burstCursor = self.burstCursor % BURST_LIMIT + 1
	local burst = self.bursts[self.burstCursor]
	if not burst then
		local at = Instance.new("Attachment")
		at.Parent = self.fxAnchor
		burst = { at = at,
			spark = emitter(at, "ImpactSparks", SPARK_TEXTURE, {
				Lifetime = NumberRange.new(0.35, 0.8), Size = fade(2.6, 0), LightEmission = 1, Drag = 3,
				Acceleration = Vector3.new(0, -26, 0), ZOffset = 3,
			}),
			smoke = emitter(at, "ImpactSmoke", SMOKE_TEXTURE, {
				Lifetime = NumberRange.new(0.6, 1.2), Size = fade(3, 9), Transparency = fade(0.3, 1), Drag = 4,
				Color = ColorSequence.new(Color3.fromRGB(70, 72, 88), Color3.fromRGB(150, 152, 166)),
				Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90), ZOffset = 1,
			}),
			fire = emitter(at, "ImpactFire", FIRE_TEXTURE, {
				Lifetime = NumberRange.new(0.2, 0.45), Size = fade(5, 0.5), Transparency = fade(0, 1), LightEmission = 1,
				Drag = 5, Color = ColorSequence.new(COLORS.cream, COLORS.fire), ZOffset = 2,
			}),
		}
		self.bursts[self.burstCursor] = burst
	end
	burst.at.WorldPosition = ORIGIN + Vector3.new(x, y, 3)
	burst.spark.Color = ColorSequence.new(COLORS.cream, color)
	burst.spark.Speed = NumberRange.new(speed * 0.4, speed)
	burst.smoke.Speed = NumberRange.new(speed * 0.1, speed * 0.35)
	burst.fire.Speed = NumberRange.new(speed * 0.1, speed * 0.4)
	if sparks > 0 and not self.reducedMotion then burst.spark:Emit(sparks) end
	if smoke > 0 then burst.smoke:Emit(smoke) end
	if fire > 0 then burst.fire:Emit(fire) end
end

-- Camera kick, freeze-frame and screen flash. Presentation only: the
-- simulation keeps running and the view catches up after the freeze.
function BattleView:_jolt(shake, punch, freeze, flash, hype)
	if self.reducedMotion then shake, punch, freeze, flash = 0, 0, 0, 0 end
	self.shake = math.max(self.shake, shake)
	self.punch = math.max(self.punch, punch)
	self.freeze = math.max(self.freeze, freeze)
	self.screenFlash = math.max(self.screenFlash, flash)
	self.hype = math.min(1, self.hype + hype)
end

function BattleView:_burst(x, y, color, strong, style, heading)
	self.effectCursor = self.effectCursor % EFFECT_LIMIT + 1
	local effect = self.effects[self.effectCursor]
	if not effect then
		effect = { pieces = {}, ring = makeRing(self.dynamic, "HitRing", 12, color) }
		effect.flash = ellipsoid(self.dynamic, "ImpactFlash", Vector3.one, CFrame.identity, COLORS.cream, Enum.Material.Neon)
		effect.flash.Transparency = 1
		for index = 1, 10 do
			effect.pieces[index] = part(self.dynamic, "ImpactRay", Vector3.one, CFrame.identity, color, Enum.Material.Neon)
		end
		self.effects[self.effectCursor] = effect
	end
	effect.active, effect.age, effect.x, effect.y, effect.strong = true, 0, x, y, strong
	effect.color = color
	effect.style, effect.heading = style, heading or 0
	for _, piece in ipairs(effect.pieces) do piece.Color = color end
	hide(effect.ring)
	effect.flash.Transparency = 1
end

function BattleView:_hit(fighter, x, y, source, actorColor)
	if fighter then
		fighter.hitTime = self.clock
		-- An armor delta and its event can arrive in the same snapshot. The
		-- authoritative impact protection makes distinct hits farther apart.
		if self.clock - fighter.lastHitBurst < 0.12 then return end
		fighter.lastHitBurst = self.clock
	end
	local color = source == "meteor" and COLORS.yellow or (source == "pinball" and POWER.pinball or (source == "wake" and POWER.fizz
		or (source == "rocket" and actorColor and actorColor:Lerp(COLORS.cream, 0.55) or COLORS.cream)))
	self:_burst(x, y, color, true, source)
	x, y = numeric(x, 0), numeric(y, CENTER_Y)
	if source == "meteor" then
		-- A slam: fire, black smoke and the longest freeze in the game.
		self:_particles(x, y, COLORS.fire, 70, 22, 28, 85)
		self:_jolt(5, 1, 0.15, 0.75, 0.8)
	elseif source == "rocket" then
		-- A firework is supposed to burst: a big ball of the shooter's colour.
		self:_particles(x, y, actorColor or COLORS.yellow, 90, 8, 10, 110)
		self:_particles(x, y, COLORS.yellow, 40, 0, 0, 60)
		self:_jolt(3.6, 0.9, 0.1, 0.6, 0.75)
	elseif source == "pinball" then
		-- An arcade smack: a clean electric-blue star, no smoke.
		self:_particles(x, y, POWER.pinball, 80, 0, 0, 120)
		self:_particles(x, y, COLORS.cream, 30, 0, 0, 50)
		self:_jolt(3.8, 0.95, 0.12, 0.6, 0.75)
	elseif source == "machinegun" then
		-- The burst chews through: hot sparks and shrapnel smoke.
		self:_particles(x, y, COLORS.yellow, 60, 14, 6, 90)
		self:_jolt(3.2, 0.8, 0.08, 0.45, 0.65)
	elseif source == "wake" then
		-- The cloud pops in a green splash.
		self:_particles(x, y, POWER.fizz, 70, 10, 0, 70)
		self:_jolt(3, 0.8, 0.08, 0.45, 0.6)
	else
		self:_particles(x, y, color, 44, 10, 10, 70)
		self:_jolt(3, 0.8, 0.08, 0.45, 0.6)
	end
end

function BattleView:_events(simulation)
	local newest = self.lastEvent
	for _, event in ipairs(simulation.events or {}) do
		local serial = numeric(event.serial, 0)
		if serial > self.lastEvent then
			newest = math.max(newest, serial)
			local kind = string.lower(tostring(event.kind or ""))
			local target = self.fighters[event.target]
			local actor = self.fighters[event.actor]
			local x = numeric(event.x, target and target.position and target.position.X - ORIGIN.X or 0)
			local y = numeric(event.y, target and target.position and target.position.Y - ORIGIN.Y or CENTER_Y)
			local age = numeric(simulation.elapsed, 0) - numeric(event.at, numeric(simulation.elapsed, 0))
			if age <= 0.45 then
				if kind == "hit" or kind == "wake_hit" or kind == "damage" or kind == "meteorhit" or kind == "rockethit" then
					self:_hit(target, x, y, event.source, actor and actor.color)
				elseif kind == "finish" then
					if simulation.reason == "knockout" then
						self:_particles(x, y, COLORS.yellow, 60, 16, 20, 90)
						self:_jolt(4.6, 1, 0.16, 0.9, 1)
					else
						self:_jolt(1.2, 0.4, 0, 0.3, 0.6)
					end
				elseif kind == "dive" and age <= 0.18 then
					self:_jolt(0.9, 0.25, 0, 0, 0.15)
					-- A complete commitment can hit and recover between snapshots.
					-- Record only a short streak at its real launch point; never keep
					-- the plane looking armed after the simulation has recovered.
					self:_burst(x, y, COLORS.yellow, false, "dive", numeric(event.heading, 0))
				elseif kind == "rocket" or kind == "burst" then
					if actor then actor.shotTime = self.clock - math.max(0, age) end
					self:_particles(x, y, COLORS.yellow, 14, 5, 6, 35)
					self:_jolt(0.7, 0.15, 0, 0, 0.1)
				elseif kind == "tracer_hit" then
					self:_particles(x, y, COLORS.yellow, 5, 0, 0, 16)
				elseif kind == "ricochet" then
					if actor then actor.shotTime = self.clock end
					self:_burst(x, y, POWER.pinball, false, "dive", numeric(event.heading, 0))
					self:_particles(x, y, POWER.pinball, 24, 0, 0, 55)
					self:_jolt(1, 0.3, 0, 0.1, 0.15)
				elseif kind == "bounce" and event.source == "pinball" then
					-- Every wall the ball touches lights up, so the path can be followed.
					self:_burst(x, y, POWER.pinball, true)
					self:_particles(x, y, POWER.pinball, 36, 0, 0, 75)
					self:_jolt(1.6, 0.4, 0, 0.12, 0.2)
				elseif kind == "skill" and event.skillId == "Magnet" and actor then
					actor.magnetTime = self.clock
					self:_burst(x, y, POWER.magnet, false)
					self:_jolt(1.2, 0.35, 0, 0.1, 0.2)
				elseif kind == "skill" and event.skillId == "SecondWind" and actor then
					actor.secondWindTime = self.clock
					self:_burst(x, y, POWER.wind, true)
					self:_particles(x, y, POWER.wind, 60, 0, 0, 80)
					self:_jolt(2.4, 0.6, 0.08, 0.3, 0.6)
				elseif kind == "skill" and event.skillId == "Afterburner" then
					-- The burner lights with a bang right behind the plane.
					self:_particles(x, y, POWER.burner, 40, 6, 24, 70)
					self:_jolt(1.4, 0.4, 0, 0.12, 0.25)
				elseif kind == "skill" and event.skillId == "FizzyFuel" then
					self:_particles(x, y, POWER.fizz, 30, 0, 0, 45)
				elseif kind == "miss" and actor and actor.offenceId == "Meteor" then
					self:_particles(x, y, COLORS.fire, 7, 3, 0, 14)
				elseif kind == "miss" and actor and actor.offenceId == "Firework" then
					self:_burst(x, y, COLORS.steel, false, "fizzle")
					self:_particles(x, y, actor.color, 26, 6, 0, 45)
				elseif kind == "blocked" then
					if actor then actor.blockTime = self.clock end
					-- The spring fires both planes apart in a ring of lime sparks.
					self:_burst(x, y, POWER.bumper, true)
					self:_particles(x, y, POWER.bumper, 70, 0, 0, 110)
					self:_jolt(3.2, 0.8, 0.1, 0.4, 0.6)
				elseif kind == "bounce" or kind == "wall" or kind == "bump" then
					self:_burst(x, y, COLORS.steel, false)
					self:_particles(x, y, COLORS.cream, 12, 3, 0, 40)
					self:_jolt(1, 0.3, 0, 0, 0.15)
				end
			end
		end
	end
	self.lastEvent = newest
end

function BattleView:_signatureEffects(fighter, state, simulation, moving, pose)
	local meteor = fighter.offenceId == "Meteor"
	local windup = moving and state.phase == "Windup"
	local armed = moving and state.armed == true
	local charge = windup and chargeProgress(fighter, state, self.sampleAge) or 0
	local shotAge = self.clock - fighter.shotTime
	local shooting = moving and (fighter.offenceId == "Firework" or fighter.offenceId == "MachineGun") and shotAge < 0.2
	local winner = simulation.finished == true and simulation.winner == state.id
	local finishAge = self.finishTime and self.clock - self.finishTime or 100
	local pulse = 1 + math.sin(self.clock * 34) * 0.08
	for index, ghost in ipairs(fighter.afterimages or {}) do
		local visible = meteor and armed and not self.reducedMotion
		if visible then ghost.model:PivotTo(pose * CFrame.new(-index * 6 * fighter.visualScale, 0, 0)) end
		for _, item in ipairs(ghost.pieces) do item.Transparency = visible and (0.8 + index * 0.055) or 1 end
	end
	fighter.lampAnchor.CFrame = pose * mount(fighter, "Nose")
	fighter.noseLight.Color = meteor and COLORS.fire or fighter.color
	fighter.noseLight.Brightness = armed and 0.85 or (shooting and 1 or charge * 0.5)
	for index, piece in ipairs(fighter.chargePieces or {}) do
		piece.Color = windup and COLORS.yellow or (armed and COLORS.cream or (meteor and COLORS.yellow or COLORS.fire))
		piece.Transparency = (windup or armed or shooting) and (0.05 + (1 - charge) * 0.15) or 0.62
		if not meteor and windup then piece.Transparency = 0.15 + (math.sin(self.clock * 24 + index * math.pi) + 1) * 0.2 end
	end
	if meteor and (windup or armed) then
		local shellCharge = armed and 1 or charge
		fighter.chargeShell.Size = Vector3.new(8 + shellCharge * 3.5, 3.6 + shellCharge * 2.6, 3.4 + shellCharge * 2.2) * SCALE * fighter.visualScale
		fighter.chargeShell.CFrame = pose * mount(fighter, "Centre")
		fighter.chargeShell.Color = armed and COLORS.yellow or COLORS.fire
		fighter.chargeShell.Transparency = armed and 0.62 or (0.92 - charge * 0.35)
	elseif fighter.offenceId == "Pinball" and windup then
		-- The ball swells on the nose until it is ready to fly.
		local size = (1.2 + charge * 5.2) * (self.reducedMotion and 1 or 1 + math.sin(self.clock * 26) * 0.06)
		fighter.chargeShell.Size = Vector3.one * size
		fighter.chargeShell.CFrame = pose * mount(fighter, "Nose") * CFrame.new(size * 0.45, 0, 0)
		fighter.chargeShell.Color = POWER.pinball
		fighter.chargeShell.Transparency = 0.25
	else
		fighter.chargeShell.Transparency = 1
	end
	for index, flame in ipairs(fighter.cometFlames) do
		if meteor and armed then
			local length = (21 - index * 4) * pulse
			local width = 5.8 - index * 1.4
			flame.Size = Vector3.new(length, width, width * 0.8)
			flame.CFrame = pose * mount(fighter, "Tail") * CFrame.new(-length * 0.3, 0, index * 0.2)
			flame.Transparency = 0.42 - index * 0.1
		else flame.Transparency = 1 end
	end
	for index, flash in ipairs(fighter.muzzleFlashes) do
		if shooting and not self.reducedMotion and fighter.muzzleOffsets[index] then
			local strength = 1 - shotAge / 0.2
			flash.Size = Vector3.new(2 + strength * 4.5, 1 + strength * 1.8, 1.2)
			flash.CFrame = pose * CFrame.new(fighter.muzzleOffsets[index] + Vector3.new(1.5, 0, 0))
			flash.Transparency = 0.12 + (1 - strength) * 0.7
		else flash.Transparency = 1 end
	end
	for index, spark in ipairs(fighter.signatureSparks) do
		if winner and finishAge < 1.1 then
			local progress = math.clamp(finishAge / 1.1, 0, 1)
			local angle = index / #fighter.signatureSparks * math.pi * 2
			local offset = Vector3.new(math.cos(angle) * (6 + progress * 8), 4 + math.sin(angle) * (3 + progress * 7) - progress * progress * 6, 8)
			spark.Size = Vector3.new(0.75, 1.7, 0.25)
			spark.CFrame = CFrame.new(fighter.position + offset) * CFrame.Angles(0, 0, angle + progress * 5)
			spark.Color = index % 2 == 0 and COLORS.yellow or fighter.color
			spark.Transparency = progress * progress
		elseif meteor and (windup or armed) then
			local angle = index / #fighter.signatureSparks * math.pi * 2 + self.clock * 2
			local radius = windup and (3.5 + charge * 2.2) or 3.8
			local offset = Vector3.new(4.7 + math.cos(angle) * radius * 0.35, math.sin(angle) * radius, math.cos(angle) * radius)
			spark.Size = Vector3.new(armed and 2.2 or (0.6 + charge * 0.6), 0.3, 0.3)
			spark.CFrame = pose * CFrame.new(offset) * CFrame.Angles(0, 0, windup and angle or 0)
			spark.Color, spark.Transparency = index % 2 == 0 and COLORS.cream or COLORS.yellow, windup and 0.35 or 0.14
		else spark.Transparency = 1 end
	end
end

function BattleView:_fighterEffects(fighter, state, simulation, moving, displayPose)
	local windup = moving and state.phase == "Windup"
	local boosted = moving and numeric(state.boostLeft, 0) > self.sampleAge
	local hitAge, blockAge = self.clock - fighter.hitTime, self.clock - fighter.blockTime
	local winner = simulation.finished == true and simulation.winner == state.id
	local knockedOut = simulation.finished == true and numeric(state.armor, 3) <= 0
	local flashing = hitAge < 0.18
	fighter.highlight.FillColor = flashing and Color3.new(1, 1, 1) or COLORS.yellow
	fighter.highlight.OutlineColor = flashing and Color3.new(1, 1, 1) or (winner and COLORS.yellow or (self.mirrorPaint and fighter.sideColor or COLORS.ink))
	fighter.highlight.FillTransparency = flashing and (0.05 + math.min(1, hitAge / 0.18) * 0.85) or (winner and 0.88 or 1)
	local center = (displayPose * mount(fighter, "Centre")).Position + Vector3.new(0, 0, 9)
	if winner then
		ring(fighter.statusRing, center, 10.5 + math.sin(self.clock * 3) * 0.3, COLORS.yellow, 0.2, self.clock * 0.2, 0.5)
	elseif not knockedOut and table.find(fighter.wildIds or {}, "SpringBumper") then
		local ready = state.bumperReady == true
		local popping = blockAge < 0.38
		local radius = popping and (8 + blockAge / 0.38 * 3) or 8
		ring(fighter.statusRing, center, radius, (ready or popping) and COLORS.yellow or COLORS.steel,
			popping and (0.15 + blockAge / 0.38 * 0.6) or (ready and 0.3 or 0.76), 0, ready and 0.5 or 0.22)
	else
		hide(fighter.statusRing)
	end
	if windup and type(state.lockX) == "number" and type(state.lockY) == "number" then
		local target = ORIGIN + Vector3.new(state.lockX, state.lockY, 7)
		local remaining = 1 - chargeProgress(fighter, state, self.sampleAge)
		ring(fighter.reticle, target, 2.7 + remaining * 2.5, fighter.color, 0.18, math.pi / 8, 0.38)
		local from = fighter.position + Vector3.new(0, 0, 7)
		local direction = target - from
		local angle = math.atan2(direction.Y, direction.X)
		for index, dash in ipairs(fighter.aimDots) do
			dash.Size = Vector3.new(2.4, 0.25, 0.18)
			dash.CFrame = CFrame.new(from:Lerp(target, 0.35 + index * 0.12)) * CFrame.Angles(0, 0, angle)
			dash.Color, dash.Transparency = fighter.color, 0.56
		end
	else
		hide(fighter.reticle)
		hide(fighter.aimDots)
	end
	for index, streak in ipairs(fighter.speedLines) do
		if boosted then
			local side = index == 1 and -1 or 1
			local length = 6 + math.sin(self.clock * 28 + index) * 2
			streak.Size = Vector3.new(length * 2.2, 0.5, 0.25)
			streak.CFrame = displayPose * mount(fighter, "Tail") * CFrame.new(-length * 0.6, side * 3.1, 3)
			streak.Color, streak.Transparency = COLORS.boost, 0.1
		else
			streak.Transparency = 1
		end
	end
	-- Afterburner: a long blue-white jet out of the tail for as long as it burns.
	for index, flame in ipairs(fighter.burnerFlames) do
		if boosted then
			local flicker = self.reducedMotion and 1 or 1 + math.sin(self.clock * 40 + index * 2) * 0.15
			local length = (30 - index * 7) * flicker
			local width = 5.2 - index * 1.3
			flame.Size = Vector3.new(length, width, width * 0.8)
			flame.CFrame = displayPose * mount(fighter, "Tail") * CFrame.new(-length * 0.42, 0, index * 0.2)
			flame.Transparency = 0.3 - index * 0.08
		else flame.Transparency = 1 end
	end
	-- Magnet: a hot-pink beam from the owner clamps a ring onto the rival.
	local magnet = moving and numeric(state.magnetLeft, 0) > self.sampleAge
	local secondWindAge = self.clock - fighter.secondWindTime
	local rival = self.fighters[state.id == 1 and 2 or 1]
	if magnet then
		ring(fighter.magnetRing, center, 9 + math.sin(self.clock * 6) * 1.2, POWER.magnet, 0.25, -self.clock * 0.8, 0.5)
		if rival and rival.position then
			local from, to = center, rival.position + Vector3.new(0, 0, 9)
			local span = to - from
			local wobble = self.reducedMotion and 1 or 1 + math.sin(self.clock * 50) * 0.3
			fighter.magnetBeam.Size = Vector3.new(span.Magnitude, 1.5 * wobble, 0.3)
			fighter.magnetBeam.CFrame = CFrame.new((from + to) / 2) * CFrame.Angles(0, 0, math.atan2(span.Y, span.X))
			fighter.magnetBeam.Transparency = 0.2
			ring(fighter.magnetGrip, to, 7.5 - (self.clock * 14 % 3), POWER.magnet, 0.1, self.clock * 3, 0.6)
		end
	else
		hide(fighter.magnetRing); hide(fighter.magnetGrip)
		fighter.magnetBeam.Transparency = 1
	end
	-- Second Wind: the whole plane burns green from the moment it wakes up.
	if moving and state.secondWind == true then
		local beat = self.reducedMotion and 0 or math.sin(self.clock * 9)
		ring(fighter.windRing, center, 8.4 + beat * 0.6, POWER.wind, 0.3, self.reducedMotion and 0 or self.clock * 1.4, 0.4)
		fighter.windAura.Size = Vector3.new(15, 9.5, 9) * (1 + beat * 0.06) * SCALE * fighter.visualScale
		fighter.windAura.CFrame = displayPose * mount(fighter, "Centre")
		fighter.windAura.Transparency = 0.35
	else
		hide(fighter.windRing)
		fighter.windAura.Transparency = 1
	end
	-- The load gauge rides on the plane: it fills piece by piece while the
	-- plane circles with nothing to fire, then snaps full and bright the moment
	-- the attack is loaded. An empty ring means a pass is only a pass.
	local loading = moving and not simulation.finished and (state.phase == "Approach" or state.phase == "Windup")
	if loading then
		local loaded = state.phase == "Windup" or state.circling == false
		local span = fighter.approachSpan or 3
		local fraction = loaded and 1 or math.clamp(1 - numeric(state.phaseLeft, span) / span, 0, 0.9)
		local pulse = (loaded and not self.reducedMotion) and 0.5 + 0.5 * math.sin(self.clock * 14) or 0
		ring(fighter.loadRing, center, 6.2 + pulse * 0.35, loaded and fighter.color:Lerp(Color3.new(1, 1, 1), 0.35 + pulse * 0.4) or fighter.color,
			loaded and 0.05 or 0.35, math.pi / 2, loaded and 0.5 or 0.32)
		local lit = math.floor(fraction * #fighter.loadRing + 0.5)
		for index, piece in ipairs(fighter.loadRing) do
			if index > lit then piece.Transparency = 0.88 end
		end
	else hide(fighter.loadRing) end
	fighter.model:SetAttribute("AttackLoaded", loading and (state.phase == "Windup" or state.circling == false) or false)
	local offence = self.skills and self.skills.get(fighter.offenceId)
	local tell
	if winner then tell = "WINNER!"
	elseif knockedOut then tell = "K.O.!"
	elseif hitAge < 0.45 then tell = "POW!"
	elseif blockAge < 0.45 then tell = "BOING!"
	elseif secondWindAge < 0.85 then tell = "SECOND WIND!"
	elseif magnet then tell = "PULL!"
	elseif boosted then tell = "ZOOM!"
	elseif windup then tell = offence and offence.windupTell or "LOCKED ON"
	elseif moving and state.phase == "Attack" then tell = offence and offence.attackTell or "FIRE!"
	end
	fighter.gui.Enabled = tell ~= nil
	if tell and tell ~= fighter.label.Text then fighter.tellTime = self.realClock end
	fighter.label.Text = tell or ""
	-- Each new word lands oversized and settles, like a comic sound effect.
	local landed = math.clamp((self.realClock - fighter.tellTime) / 0.16, 0, 1)
	fighter.pop.Scale = self.reducedMotion and 1 or (1.7 - 0.7 * (1 - (1 - landed) ^ 3))
	fighter.label.TextColor3 = (winner or hitAge < 0.45) and COLORS.yellow or COLORS.cream
	fighter.stroke.Color = (hitAge < 0.45 and not winner) and COLORS.coral:Lerp(COLORS.ink, 0.35) or fighter.color:Lerp(COLORS.ink, 0.55)
	self:_signatureEffects(fighter, state, simulation, moving, displayPose)
end

function BattleView:_wakes(simulation, moving)
	local active, states = {}, {}
	if moving then
		for index, state in ipairs(simulation.wakes or {}) do
			if index > WAKE_LIMIT then break end
			local id = state.id or index
			active[id] = true
			table.insert(states, { id = id, state = state })
		end
	end
	for id, wake in pairs(self.wakes) do
		if not active[id] then
			hideWake(wake)
			table.insert(self.wakePool, wake)
			self.wakes[id] = nil
		end
	end
	for _, entry in ipairs(states) do
		local state = entry.state
		local wake = self.wakes[entry.id]
		if not wake then
			wake = table.remove(self.wakePool) or makeWake(self.dynamic)
			self.wakes[entry.id] = wake
		end
		local radius = math.max(0.1, numeric(state.radius, 5))
		local life = math.max(0, numeric(state.life, 0) - self.sampleAge)
		local fraction = math.clamp(life / math.max(0.01, numeric(state.maxLife, 3.2)), 0, 1)
		local arming = numeric(state.armLeft, 0) > self.sampleAge
		local center = ORIGIN + Vector3.new(numeric(state.x, 0), numeric(state.y, CENTER_Y), 4)
		local owner = self.fighters[state.owner or state.actor]
		local edgeColor = owner and owner.color or COLORS.fire
		-- Keep the authoritative collision footprint fixed as it fades. These
		-- bright discs are hazardous, unlike the thin cosmetic contrails.
		local bubble = self.reducedMotion and 1 or 1 + math.sin(self.clock * 7 + numeric(tonumber(entry.id), 0) * 1.7) * 0.07
		wake.disc.Size = Vector3.new(0.16, radius * 2 * bubble, radius * 2 * bubble)
		wake.disc.CFrame = CFrame.new(center) * CFrame.Angles(0, math.pi / 2, 0)
		wake.disc.Color = arming and COLORS.cream or POWER.fizz
		wake.disc.Transparency = life <= 0 and 1 or (arming and 0.8 or (0.3 + (1 - fraction) * 0.4))
		ring(wake.edge, center + Vector3.new(0, 0, 0.2), radius, edgeColor,
			life <= 0 and 1 or (arming and 0.5 or (0.12 + (1 - fraction) * 0.35)), self.clock * 0.5, 0.36)
	end
end

-- The box the camera should hold: both planes and any rocket in flight, with
-- breathing room. Close fights fill the screen; a chase pulls the lens back.
function BattleView:_frame(simulation)
	if self.reducedMotion then return 0, CENTER_Y, FULL_WIDTH, FULL_HEIGHT end
	local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
	local function include(position)
		local x, y = position.X - ORIGIN.X, position.Y - ORIGIN.Y
		minX, maxX, minY, maxY = math.min(minX, x), math.max(maxX, x), math.min(minY, y), math.max(maxY, y)
	end
	-- A knockout first belongs to the plane going down, then to the scene.
	local knockout = simulation.finished == true and simulation.reason == "knockout"
		and self.finishReal ~= nil and self.realClock - self.finishReal < 1.1
	for _, fighter in pairs(self.fighters) do
		if fighter.position and (not knockout or fighter.crash) then include(fighter.position) end
	end
	if not knockout then
		for _, rocket in pairs(self.rockets) do
			if rocket.position then include(rocket.position) end
		end
	end
	if minX > maxX then return 0, CENTER_Y, FULL_WIDTH, FULL_HEIGHT end
	local attacking = knockout
	for _, state in ipairs(simulation.fighters or {}) do
		if state.phase == "Windup" or state.phase == "Attack" then attacking = true end
	end
	local width = math.clamp(maxX - minX + 58, attacking and ATTACK_VIEW_WIDTH or REST_VIEW_WIDTH, FULL_WIDTH)
	local height = math.clamp(maxY - minY + 42, attacking and ATTACK_VIEW_HEIGHT or REST_VIEW_HEIGHT, FULL_HEIGHT)
	local slackX, slackY = (FULL_WIDTH - width) / 2, (FULL_HEIGHT - height) / 2
	return math.clamp((minX + maxX) / 2, -slackX, slackX),
		math.clamp((minY + maxY) / 2, CENTER_Y - slackY, CENTER_Y + slackY), width, height
end

function BattleView:_camera(rect, simulation, dt)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local width, height = math.max(1, viewport.X), math.max(1, viewport.Y)
	local left = math.clamp(numeric(rect and rect.left, 16), 0, width - 1)
	local top = math.clamp(numeric(rect and rect.top, 90), 0, height - 1)
	local right = math.clamp(numeric(rect and rect.right, width - 16), left + 1, width)
	local bottom = math.clamp(numeric(rect and rect.bottom, height - 80), top + 1, height)
	local regionWidth, regionHeight = math.max(1, right - left), math.max(1, bottom - top)
	local aspect = width / height
	local targetX, targetY, targetWidth, targetHeight = self:_frame(simulation)
	local view = self.view
	if not view then
		view = { x = targetX, y = targetY, width = targetWidth, height = targetHeight }
		self.view = view
	end
	-- Widen quickly so nobody leaves the frame; close in gently.
	local follow = 1 - math.exp(-6 * dt)
	local widen, tighten = 1, 1 - math.exp(-3 * dt)
	view.x = view.x + (targetX - view.x) * follow
	view.y = view.y + (targetY - view.y) * follow
	view.width = view.width + (targetWidth - view.width) * (targetWidth > view.width and widen or tighten)
	view.height = view.height + (targetHeight - view.height) * (targetHeight > view.height and widen or tighten)
	-- Smoothing may never push a pilot outside the selected frame, including a
	-- fast cross-arena Meteor on a portrait display.
	for _, fighter in pairs(self.fighters) do
		if fighter.position and not fighter.crash then
			view.width = math.max(view.width, 2 * (math.abs(fighter.position.X - ORIGIN.X - view.x) + 16))
			view.height = math.max(view.height, 2 * (math.abs(fighter.position.Y - ORIGIN.Y - view.y) + 14))
		end
	end
	local zoom = 1 - 0.06 * self.punch
	local fullHeight = math.max(view.width * zoom / (regionWidth / width) / aspect, view.height * zoom / (regionHeight / height))
	local fullWidth = fullHeight * aspect
	local shakeX = math.sin(self.realClock * 83) * self.shake
	local shakeY = math.cos(self.realClock * 97) * self.shake
	local centerX = ORIGIN.X + view.x + shakeX - ((left + right) / (2 * width) - 0.5) * fullWidth
	local centerY = ORIGIN.Y + view.y + shakeY + ((top + bottom) / (2 * height) - 0.5) * fullHeight
	-- Keep geometry close enough for Studio's lowest detail setting. A narrow
	-- lens with a far-away camera can cull the entire arena on small screens.
	local fieldOfView = math.clamp(math.deg(2 * math.atan(fullHeight / 360)), 14, 120)
	local distance = fullHeight / (2 * math.tan(math.rad(fieldOfView) / 2))
	local focus = Vector3.new(centerX, centerY, ORIGIN.Z)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical
	camera.FieldOfView = fieldOfView
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, distance), focus)
	camera.Focus = CFrame.new(focus)
	self.folder:SetAttribute("VisibleHeight", fullHeight)
end

function BattleView:update(snapshot, dt, viewportRect)
	if self.destroyed or not snapshot then return end
	dt = math.clamp(numeric(dt, 1 / 60), 0, 0.1)
	local realDt = dt
	self.realClock = self.realClock + realDt
	if snapshot.roundId ~= self.roundId then self:_resetRound(snapshot.roundId) end
	local identityKey = ""
	for _, identity in ipairs(snapshot.players or {}) do
		identityKey = identityKey .. tostring(identity.userId) .. ":" .. tostring(identity.name) .. ":" .. tostring(identity.planeId) .. ":" .. tostring(identity.color) .. ":" .. tostring(identity.trailId) .. ";"
	end
	if self.identityKey ~= identityKey then
		for _, fighter in pairs(self.fighters) do fighter.model:Destroy(); fighter.fx:Destroy() end
		self.fighters = {}; self.identityKey = identityKey
	end
	self.identities = snapshot.players
	local paints = snapshot.players or {}
	self.mirrorPaint = paints[1] ~= nil and paints[2] ~= nil and paints[1].color == paints[2].color
	local simulation = snapshot.simulation or {}
	if simulation.finished == true then self.finishReal = self.finishReal or self.realClock
	else self.finishReal = nil end
	-- The final blow plays in slow motion. Only this view's clock slows.
	local slowMotion = not self.reducedMotion and simulation.finished == true and simulation.reason == "knockout"
		and self.realClock - self.finishReal < 0.5
	if slowMotion then dt = dt * 0.35 end
	self.clock = self.clock + dt
	self.freeze = math.max(0, self.freeze - realDt)
	self.shake = self.shake * math.exp(-9 * realDt)
	self.punch = self.punch * math.exp(-6 * realDt)
	self.screenFlash = self.screenFlash * math.exp(-11 * realDt)
	self.hype = self.hype * math.exp(-0.9 * realDt)
	self.grade.Brightness = self.screenFlash * 0.16
	self.grade.Contrast = 0.06 + self.screenFlash * 0.2
	self.grade.Saturation = slowMotion and -0.35 or 0.14
	for _, cloud in ipairs(self.clouds) do
		cloud.x = cloud.x + cloud.drift * realDt
		if cloud.x > cloud.span then cloud.x = -cloud.span end
		cloud.model:PivotTo(arenaPose(cloud.x, cloud.y, cloud.z))
	end
	for _, row in ipairs(self.crowd) do
		local hop = math.abs(math.sin(self.realClock * (4 + self.hype * 7) + row.phase)) * (0.2 + self.hype * 1.7)
		row.model:PivotTo(row.base + Vector3.new(0, self.reducedMotion and 0 or hop, 0))
	end
	local elapsed = numeric(simulation.elapsed, 0)
	if elapsed ~= self.sampleElapsed then
		self.sampleElapsed, self.sampleAge = elapsed, 0
	else
		self.sampleAge = self.sampleAge + dt
	end
	local moving = snapshot.phase == "Fight" and simulation.finished ~= true
	if simulation.finished == true then self.finishTime = self.finishTime or self.clock
	else self.finishTime = nil end
	local extrapolate = moving and math.min(self.sampleAge, 0.055) or 0
	-- A freeze-frame holds every aircraft and rocket where the blow landed.
	local smoothing = self.freeze > 0 and 0 or 1 - math.exp(-24 * dt)
	local states = simulation.fighters
	if not states or #states == 0 then
		states = {}
		for index = 1, 2 do
			local settings = snapshot.settings and snapshot.settings[index] or {}
			local direction = index == 1 and 1 or -1
			local angle = math.rad(numeric(settings.angle, 25))
			local wildIds = type(settings.wildIds) == "table" and settings.wildIds or {}
			states[index] = { id = index, offenceId = settings.offenceId or "",
				wildIds = wildIds, bumperReady = table.find(wildIds, "SpringBumper") ~= nil,
				x = -direction * 44, y = 34, vx = math.cos(angle) * direction, vy = math.sin(angle), armor = 3 }
		end
	end
	local bounds = simulation.bounds or { left = MIN_X, right = MAX_X, bottom = MIN_Y, top = MAX_Y }
	-- Ensure both event targets exist, then accept hits before drawing this
	-- frame. All stronger flashes below correspond to damage, never a bump.
	for index, state in ipairs(states) do
		if index > 2 then break end
		self:_fighter(state.id or index, index)
	end
	self:_events(simulation)
	local seenFighters = {}
	for index, state in ipairs(states) do
		if index > 2 then break end
		local id = state.id or index
		seenFighters[id] = true
		local fighter = self:_fighter(id, index)
		local settings = snapshot.settings and snapshot.settings[index]
		self:_setSignature(fighter, state.offenceId or (settings and settings.offenceId) or "")
		fighter.wildIds = type(state.wildIds) == "table" and state.wildIds
			or (settings and type(settings.wildIds) == "table" and settings.wildIds) or {}
		if state.phase == "Windup" and fighter.previousPhase ~= "Windup" then
			fighter.observedWindupDuration = math.max(0.01, numeric(state.phaseLeft, 1))
		end
		if state.phase == "Approach" and fighter.previousPhase ~= "Approach" then
			fighter.approachSpan = math.max(0.1, numeric(state.phaseLeft, 3))
		end
		fighter.previousPhase = state.phase
		local vx, vy = numeric(state.vx, 0), numeric(state.vy, 0)
		if math.abs(vx) > 0.1 then fighter.facing = vx > 0 and 1 or -1 end
		local target = ORIGIN + Vector3.new(
			math.clamp(numeric(state.x, index == 1 and -45 or 45) + vx * extrapolate, bounds.left, bounds.right),
			math.clamp(numeric(state.y, CENTER_Y) + vy * extrapolate, bounds.bottom, bounds.top), 0)
		fighter.position = fighter.position and fighter.position:Lerp(target, smoothing) or target
		local desiredPose = poseForVelocity(fighter.position, vx, vy, fighter.facing, 0.20 + math.sin(self.clock * 3 + index) * 0.05)
		fighter.pose = fighter.pose and fighter.pose:Lerp(desiredPose, smoothing) or desiredPose
		-- Position interpolation happens once; keep turn interpolation independent.
		fighter.pose = fighter.pose.Rotation + fighter.position
		local armor = numeric(state.armor, 3)
		local displayPose = fighter.pose
		local knockedOut = simulation.finished == true and armor <= 0
		if knockedOut then
			displayPose = self:_crashPose(fighter, state, target)
		else
			fighter.finishRotation, fighter.finishPosition = nil, nil
		end
		fighter.model:PivotTo(displayPose)
		local propellerPhase = knockedOut and fighter.stoppedPropeller or self.clock * (moving and 52 or 16)
		if fighter.propeller then fighter.propeller:PivotTo(displayPose * mount(fighter, "Nose") * CFrame.Angles(propellerPhase, 0, 0)) end
		if fighter.armor and armor < fighter.armor then self:_hit(fighter, state.x, state.y) end
		fighter.armor = armor
		fighter.model:SetAttribute("Armor", armor)
		fighter.model:SetAttribute("Phase", state.phase or "Approach")
		fighter.model:SetAttribute("WildIds", table.concat(fighter.wildIds, ","))
		fighter.model:SetAttribute("BumperReady", state.bumperReady == true)
		local flash = self.clock - fighter.hitTime < 0.14
		fighter.body.Color = flash and COLORS.cream or (armor <= 0 and fighter.color:Lerp(COLORS.steel, 0.65) or fighter.color)
		local protected = state.invulnerable == true or numeric(state.invulnerable, 0) > 0
		fighter.body.Transparency = protected and 0.16 or 0
		local windup = moving and state.phase == "Windup"
		local armed = moving and state.armed == true
		local boosted = moving and numeric(state.boostLeft, 0) > self.sampleAge
		fighter.noseGlow.Color = windup and COLORS.yellow or fighter.color
		fighter.noseGlow.Transparency = armed and 0.18 or (windup and (0.48 + math.sin(self.clock * 25) * 0.18) or 1)
		fighter.trail.Enabled = moving and armor > 0 and vx * vx + vy * vy > 4
		fighter.trail.Lifetime = fighter.look.trailLife * (armed and 1.5 or 1)
		if fighter.flare then
			fighter.flare.Transparency = (armed or boosted) and 0.12 or 1
			fighter.flare.Color = boosted and COLORS.boost or (fighter.offenceId == "Meteor" and COLORS.yellow or fighter.color)
			fighter.flare.Size = Vector3.new(boosted and 11 or (armed and 9 or 5), boosted and 2 or 1.5, 1.5) * SCALE
			fighter.flare.CFrame = displayPose * mount(fighter, "Tail") * CFrame.new(-3 * SCALE, 0, 0)
		end
		self:_fighterEffects(fighter, state, simulation, moving, displayPose)
		-- Damage shows on the airframe: smoke after one hit, fire after two.
		local hurt = (snapshot.phase == "Fight" or snapshot.phase == "Results" or snapshot.phase == "RoundOver" or snapshot.phase == "MatchOver") and 3 - armor or 0
		fighter.smokeAnchor.CFrame = displayPose * mount(fighter, "Belly")
		fighter.damageSmoke.Rate = knockedOut and (fighter.crashLanded and 12 or 46) or (hurt >= 2 and 24 or (hurt == 1 and 10 or 0))
		fighter.damageFire.Rate = knockedOut and (fighter.crashLanded and 6 or 28) or (hurt >= 2 and 16 or 0)
		for smokeIndex, puff in ipairs(fighter.smoke) do
			local smokeAge = self.clock - fighter.hitTime - (smokeIndex - 1) * 0.13
			if knockedOut and fighter.crash then
				local crash = fighter.crash
				local age = self.clock - crash.startedAt + (smokeIndex - 1) * 0.28
				local cycle = math.floor(age / 0.84)
				local sample = crash.smoke[smokeIndex]
				if not sample or sample.cycle ~= cycle then
					sample = { cycle = cycle, position = fighter.position + Vector3.new(-fighter.facing * 2, 1, 5) }
					crash.smoke[smokeIndex] = sample
				end
				local progress = age / 0.84 - cycle
				puff.Size = Vector3.one * (2 + progress * 4)
				puff.CFrame = CFrame.new(sample.position + Vector3.new(fighter.facing * progress, progress * 7, 0))
				puff.Transparency = 0.3 + progress * 0.7
			elseif smokeAge >= 0 and smokeAge < 0.85 then
				local progress = smokeAge / 0.85
				puff.Size = Vector3.one * (1.4 + progress * 3.2)
				puff.CFrame = displayPose * CFrame.new((-6 - progress * 4) * SCALE, 0, 0)
					+ Vector3.new(0, progress * 5, 1)
				puff.Transparency = 0.35 + progress * 0.65
			else
				puff.Transparency = 1
			end
		end
		if not moving then fighter.trail.Enabled = false end
	end
	for id, fighter in pairs(self.fighters) do
		if not seenFighters[id] then fighter.model:Destroy(); fighter.fx:Destroy(); self.fighters[id] = nil end
	end

	local seenRockets, rocketStates, rocketCount = {}, {}, 0
	for _, state in ipairs(simulation.projectiles or {}) do
		rocketCount = rocketCount + 1
		if rocketCount > ROCKET_LIMIT then break end
		local id = state.id or rocketCount
		seenRockets[id] = true
		table.insert(rocketStates, { id = id, state = state })
	end
	-- Release vanished IDs before acquiring replacements, so even a complete
	-- projectile turnover cannot grow the allocation beyond ROCKET_LIMIT.
	for id, rocket in pairs(self.rockets) do
		if not seenRockets[id] then
			rocket.trail.Enabled = false
			rocket.trail:Clear()
			rocket.fizz.Rate = 0
			for _, piece in ipairs(rocket.pieces) do piece.Transparency = 1 end
			table.insert(self.rocketPool, rocket)
			self.rockets[id] = nil
		end
	end
	for _, entry in ipairs(rocketStates) do
		local id, state = entry.id, entry.state
		local rocket = self.rockets[id]
		if not rocket then
			rocket = table.remove(self.rocketPool) or makeRocket(self.dynamic)
			self.rockets[id] = rocket
			rocket.position = nil
			for _, piece in ipairs(rocket.pieces) do piece.Transparency = 0 end
			rocket.trail:Clear()
		end
		local owner = self.fighters[state.owner or state.actor]
		local color = owner and owner.color or PLAYER_COLORS[tonumber(state.owner) or 1] or COLORS.yellow
		local tracer = state.source == "machinegun"
		local ball = state.source == "pinball"
		local squash = (ball and not self.reducedMotion) and 1 + 0.12 * math.sin(self.clock * 30) or 1
		rocket.ball.Size = Vector3.new(6.4 * squash, 6.4 / squash, 6.4)
		rocket.ball.Transparency, rocket.ballCore.Transparency = ball and 0.15 or 1, ball and 0 or 1
		rocket.body.Transparency = ball and 1 or 0
		if ball then tracer = true end
		rocket.body.Size = tracer and Vector3.new(3.4, 0.36, 0.36) or Vector3.new(5, 1.65, 1.65)
		rocket.body.Material = tracer and Enum.Material.Neon or Enum.Material.SmoothPlastic
		rocket.body.Color = tracer and COLORS.yellow or COLORS.cream
		rocket.nose.Transparency = tracer and 1 or 0
		rocket.fin.Transparency = tracer and 1 or 0
		rocket.crossFin.Transparency = tracer and 1 or 0
		for _, stripe in ipairs(rocket.stripes) do stripe.Transparency = tracer and 1 or 0 end
		rocket.nose.Color, rocket.fin.Color, rocket.crossFin.Color = color, color, color
		for _, stripe in ipairs(rocket.stripes) do stripe.Color = color end
		local vx, vy = numeric(state.vx, 0), numeric(state.vy, 0)
		local target = ORIGIN + Vector3.new(numeric(state.x, 0) + vx * extrapolate, numeric(state.y, CENTER_Y) + vy * extrapolate, 2)
		rocket.position = rocket.position and rocket.position:Lerp(target, smoothing) or target
		local rocketPose = CFrame.new(rocket.position) * CFrame.Angles(0, 0, math.atan2(vy, vx))
		rocket.model:PivotTo(rocketPose)
		local sputter = 1 + math.sin(self.clock * 49 + numeric(tonumber(id), 0)) * 0.23
		rocket.exhaust.Size = Vector3.new(3.6 * sputter, 1.25, 1.25)
		rocket.exhaust.CFrame = rocketPose * CFrame.new(-3.9, 0, 0)
		rocket.exhaust.Transparency = moving and not tracer and (0.18 + (sputter - 0.77) * 0.2) or 1
		rocket.core.Size = Vector3.new(2.4 * sputter, 0.62, 0.62)
		rocket.core.CFrame = rocketPose * CFrame.new(-3.55, 0, 0.25)
		rocket.core.Transparency = moving and not tracer and 0.08 or 1
		for index, spark in ipairs(rocket.sparks) do
			local progress = (self.clock * 7 + index / 3) % 1
			spark.Size = Vector3.new(0.55 * (1 - progress) + 0.12, 0.3, 0.25)
			spark.CFrame = rocketPose * CFrame.new(-4.5 - progress * 3.5, (index % 2 == 0 and 1 or -1) * progress, 1)
			spark.Transparency = moving and not tracer and not self.reducedMotion and progress or 1
		end
		rocket.trail.Enabled = moving
		rocket.trail.Color = ColorSequence.new(ball and POWER.pinball or color, COLORS.cream)
		rocket.trail.Lifetime = ball and 0.9 or (tracer and 0.12 or 0.55)
		rocket.trail.WidthScale = NumberSequence.new(ball and 4 or (tracer and 0.25 or 1), 0)
		rocket.fizz.Rate = moving and not tracer and not self.reducedMotion and 55 or 0
		rocket.fizz.Color = ColorSequence.new(COLORS.cream, color)
	end
	self:_wakes(simulation, moving)
	for _, effect in ipairs(self.effects) do
		if effect.active then
			effect.age = effect.age + dt
			local duration = effect.style == "dive" and 0.18 or (effect.strong and 0.42 or 0.24)
			local progress = math.clamp(effect.age / duration, 0, 1)
			local radius = 2 + progress * (effect.strong and 11 or 6)
			for index, piece in ipairs(effect.pieces) do
				local angle = index / #effect.pieces * math.pi * 2
				if effect.style == "dive" then
					local forward, across = -3 + progress * 5, (index - 2) * 1.5
					piece.Size = Vector3.new(8 * (1 - progress) + 0.1, 0.45, 0.3)
					piece.CFrame = arenaPose(effect.x + math.cos(effect.heading) * forward - math.sin(effect.heading) * across,
						effect.y + math.sin(effect.heading) * forward + math.cos(effect.heading) * across, 8) * CFrame.Angles(0, 0, effect.heading)
					piece.Transparency = index <= 3 and (0.2 + progress * 0.8) or 1
				elseif effect.style == "crash" then
					local groundAngle = (index - 0.5) / #effect.pieces * math.pi
					piece.Size = Vector3.new(2.8 * (1 - progress) + 0.1, 0.4, 0.3)
					piece.CFrame = arenaPose(effect.x + math.cos(groundAngle) * radius,
						effect.y + math.sin(groundAngle) * radius * 0.55 + 0.3, 10) * CFrame.Angles(0, 0, groundAngle)
					piece.Transparency = progress
				else
					local actualRadius = effect.style == "fizzle" and radius * 0.45 or radius
					piece.Size = Vector3.new((effect.strong and 3.5 or 2) * (1 - progress) + 0.1, effect.strong and 0.5 or 0.3, 0.3)
					piece.CFrame = arenaPose(effect.x + math.cos(angle) * actualRadius, effect.y + math.sin(angle) * actualRadius, 8) * CFrame.Angles(0, 0, angle)
					piece.Transparency = effect.strong and progress or (0.6 + progress * 0.4)
				end
			end
			if effect.strong then
				if effect.style == "crash" then
					for index, piece in ipairs(effect.ring) do
						local angle = (index - 0.5) / #effect.ring * math.pi
						piece.Size = Vector3.new(1.6, 0.3, 0.2)
						piece.CFrame = arenaPose(effect.x + math.cos(angle) * (2 + progress * 9),
							effect.y + math.sin(angle) * (2 + progress * 5), 10) * CFrame.Angles(0, 0, angle + math.pi / 2)
						piece.Color, piece.Transparency = effect.color, progress
					end
				else
					ring(effect.ring, ORIGIN + Vector3.new(effect.x, effect.y, 8), 2 + progress * 9,
						effect.color, progress, 0, 0.7 * (1 - progress) + 0.1)
				end
				effect.flash.Size = Vector3.new(3 + progress * 7, effect.style == "crash" and 2 or (3 + progress * 7), 0.5)
				effect.flash.CFrame = arenaPose(effect.x, effect.y + (effect.style == "crash" and 1 or 0), effect.style == "crash" and 10 or 8.5)
				effect.flash.Transparency = not self.reducedMotion and progress < 0.3 and (0.2 + progress * 2.5) or 1
			end
			if progress >= 1 then effect.active = false; hide(effect.ring); effect.flash.Transparency = 1 end
		end
	end
	local pressured = simulation.pressure == true or numeric(simulation.pressure, 0) > 0
	local fieldWidth, fieldHeight = bounds.right - bounds.left, bounds.top - bounds.bottom
	local fieldX, fieldY = (bounds.left + bounds.right) / 2, (bounds.bottom + bounds.top) / 2
	self.edges[1].Size = Vector3.new(0.6, fieldHeight, 0.5)
	self.edges[1].CFrame = arenaPose(bounds.left, fieldY, -2)
	self.edges[2].Size = Vector3.new(0.6, fieldHeight, 0.5)
	self.edges[2].CFrame = arenaPose(bounds.right, fieldY, -2)
	self.edges[3].Size = Vector3.new(fieldWidth, 0.5, 0.5)
	self.edges[3].CFrame = arenaPose(fieldX, bounds.top, -2)
	self.edges[4].Size = Vector3.new(fieldWidth, 0.5, 0.5)
	self.edges[4].CFrame = arenaPose(fieldX, bounds.bottom, -2)
	local windZones = {
		{ bounds.left - MIN_X, MAX_Y - MIN_Y, (bounds.left + MIN_X) / 2, CENTER_Y },
		{ MAX_X - bounds.right, MAX_Y - MIN_Y, (MAX_X + bounds.right) / 2, CENTER_Y },
		{ fieldWidth, MAX_Y - bounds.top, fieldX, (MAX_Y + bounds.top) / 2 },
		{ fieldWidth, bounds.bottom - MIN_Y, fieldX, (bounds.bottom + MIN_Y) / 2 },
	}
	for index, zone in ipairs(windZones) do
		self.wind[index].Size = Vector3.new(math.max(0.05, zone[1]), math.max(0.05, zone[2]), 0.2)
		self.wind[index].CFrame = arenaPose(zone[3], zone[4], -5)
		self.wind[index].Transparency = pressured and (0.6 + (self.reducedMotion and 0 or 0.08 * math.sin(self.clock * 4 + index))) or 1
	end
	local pressure = math.clamp(numeric(simulation.pressure, 0), 0, 1)
	for side = 1, 4 do
		local vertical = side <= 2
		local rail = side == 1 and bounds.left or side == 2 and bounds.right or side == 3 and bounds.top or bounds.bottom
		local outward = (side == 1 or side == 4) and -1 or 1
		local span = vertical and fieldHeight or fieldWidth
		local middle = vertical and fieldY or fieldX
		for n, streak in ipairs(self.windStreaks[side]) do
			local sweep = self.reducedMotion and 0.5 or (self.clock * (0.8 + pressure * 0.7) + n * 0.37) % 1
			local along = middle - span * 0.5 + (n - 0.5) * span / 5
			local across = rail + outward * (1.5 + (1 - sweep) * 12)
			local length = 4 + pressure * 5
			streak.Size = vertical and Vector3.new(length, 0.3, 0.15) or Vector3.new(0.3, length, 0.15)
			streak.CFrame = vertical and arenaPose(across, along, -4) or arenaPose(along, across, -4)
			streak.Transparency = pressured and (0.25 + math.abs(sweep - 0.5) * 1.5) or 1
		end
	end
	for index, edge in ipairs(self.edges) do
		edge.Color = pressured and COLORS.yellow or (index <= 2 and self:accent(index) or COLORS.cream)
		edge.Transparency = pressured and (0.05 + (self.reducedMotion and 0 or 0.12 * math.sin(self.clock * 5))) or (index <= 2 and 0.2 or 0.55)
	end
	self.folder:SetAttribute("Phase", snapshot.phase or "Configure")
	self.folder:SetAttribute("RoundId", tostring(snapshot.roundId or ""))
	self:_camera(viewportRect, simulation, realDt)
end

function BattleView:destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.folder:Destroy()
	self.bloom:Destroy()
	self.grade:Destroy()
	table.clear(self.fighters)
	table.clear(self.rockets)
	table.clear(self.rocketPool)
	table.clear(self.effects)
	table.clear(self.wakes)
	table.clear(self.wakePool)
	-- The normal client camera resumes on its next render. No connections,
	-- lighting effects, delayed callbacks, or external instances survive.
end

return BattleView
