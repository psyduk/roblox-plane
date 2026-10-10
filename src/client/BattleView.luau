--!nonstrict
-- Local presentation for Battle Lab. Simulation owns every hit and outcome.
-- The caller owns the render connection and must skip its normal flight camera
-- while calling update. viewportRect uses Camera.ViewportSize pixel coordinates.
local Workspace = game:GetService("Workspace")

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
}
local PLAYER_COLORS = { COLORS.coral, COLORS.cyan }
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

local function makeArena(parent)
	local scenery = Instance.new("Folder")
	scenery.Name = "Stadium"
	scenery.Parent = parent
	-- Fill the entire view, including space underneath the screen-space HUD.
	-- The smaller field plate remains distinct; sky must not reduce caption
	-- contrast when the camera makes room for setup controls or a narrow screen.
	part(scenery, "Background", Vector3.new(2048, 2048, 3), arenaPose(0, CENTER_Y, -32), COLORS.dark)
	part(scenery, "Backdrop", Vector3.new(180, 126, 3), arenaPose(0, CENTER_Y, -14), COLORS.dark)
	part(scenery, "PlayingField", Vector3.new(148, 92, 1), arenaPose(0, CENTER_Y, -11), COLORS.navy)
	-- An inset toy stadium, rather than a flat rectangle: quiet raised borders,
	-- recessed light bars, and a faint center medallion stay behind the flight.
	for _, side in ipairs({ -1, 1 }) do
		part(scenery, "OuterFrame", Vector3.new(4, 105, 6), arenaPose(side * 79, CENTER_Y, -8), Color3.fromRGB(28, 47, 65), Enum.Material.Metal)
		part(scenery, "InsetRail", Vector3.new(0.5, 91, 0.4), arenaPose(side * 76.8, CENTER_Y, -3.5), COLORS.grid, Enum.Material.Neon)
		for _, y in ipairs({ MIN_Y - 4, MAX_Y + 4 }) do
			part(scenery, "CornerBrace", Vector3.new(11, 2.4, 3), arenaPose(side * 74, y, -6), COLORS.steel)
			local lamp = part(scenery, "StadiumLamp", Vector3.new(6.5, 0.65, 0.7), arenaPose(side * 74, y, -3.8),
				side < 0 and COLORS.coral or COLORS.cyan, Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Color, light.Brightness, light.Range = lamp.Color, 0.45, 38
			light.Shadows = false
			light.Parent = lamp
		end
	end
	local medallion = makeRing(scenery, "CenterMedallion", 24, COLORS.grid)
	ring(medallion, ORIGIN + Vector3.new(0, CENTER_Y, -10.2), 13, COLORS.grid, 0.5, 0, 0.18)
	-- A quiet drafting-board grid makes movement and a shared collision plane
	-- legible. All grid parts are behind the action; none can collide.
	for x = -60, 60, 20 do
		part(scenery, "GridVertical", Vector3.new(0.13, 88, 0.1), arenaPose(x, CENTER_Y, -10.3), COLORS.grid)
	end
	for y = 12, 92, 20 do
		part(scenery, "GridHorizontal", Vector3.new(144, 0.13, 0.1), arenaPose(0, y, -10.3), COLORS.grid)
	end
	part(scenery, "Floor", Vector3.new(162, 5, 26), arenaPose(0, MIN_Y - 5, -4), COLORS.steel)
	local floorLip = part(scenery, "FloorLip", Vector3.new(160, 0.7, 1.2), arenaPose(0, MIN_Y - 2.1, 9), COLORS.cream)
	for index = -3, 3 do
		part(scenery, "FloorInset", Vector3.new(13, 0.2, 1), arenaPose(index * 21, MIN_Y - 2.25, 4),
			index < 0 and COLORS.coral or (index > 0 and COLORS.cyan or COLORS.yellow), Enum.Material.Neon)
	end
	local edges = {}
	for index, x in ipairs({ MIN_X, MAX_X }) do
		part(scenery, "Pylon" .. index, Vector3.new(2.2, 100, 5), arenaPose(x + (index == 1 and -3 or 3), CENTER_Y, -4), COLORS.steel)
		edges[index] = part(scenery, "SideBoundary" .. index, Vector3.new(0.6, 88, 0.5), arenaPose(x, CENTER_Y, -2), PLAYER_COLORS[index], Enum.Material.Neon)
		edges[index].Transparency = 0.35
		for y = MIN_Y, MAX_Y, 22 do
			part(scenery, "BoundaryTick", Vector3.new(2.2, 0.4, 0.5), arenaPose(x + (index == 1 and -1.8 or 1.8), y, -2), COLORS.cream)
		end
	end
	edges[3] = part(scenery, "CeilingBoundary", Vector3.new(144, 0.5, 0.5), arenaPose(0, MAX_Y, -2), COLORS.steel, Enum.Material.Neon)
	edges[4] = part(scenery, "FloorBoundary", Vector3.new(144, 0.5, 0.5), arenaPose(0, MIN_Y, -2), COLORS.steel, Enum.Material.Neon)
	local wind = {}
	for index = 1, 4 do
		wind[index] = part(scenery, "WindPressure" .. index, Vector3.one, arenaPose(0, CENTER_Y, -5), COLORS.yellow, Enum.Material.Neon)
		wind[index].Transparency = 1
	end
	return edges, wind, floorLip
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
	local stripes = {}
	local pieces = { body, nose, fin, crossFin, exhaust, core }
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
	trail.Transparency = NumberSequence.new(0.28, 1)
	trail.Lifetime = 0.26
	trail.LightEmission = 0.8
	trail.MinLength = 0.15
	trail.Parent = body
	return { model = model, nose = nose, fin = fin, crossFin = crossFin, trail = trail, pieces = pieces,
		stripes = stripes, sparks = sparks, exhaust = exhaust, core = core }
end

function BattleView.new(World, onPresentationCue)
	local self = setmetatable({
		World = World, fighters = {}, rockets = {}, rocketPool = {}, effects = {}, wakes = {}, wakePool = {},
		effectCursor = 0, roundId = nil, lastEvent = 0, clock = 0,
		sampleElapsed = nil, sampleAge = 0, destroyed = false,
		onPresentationCue = type(onPresentationCue) == "function" and onPresentationCue or nil,
	}, BattleView)
	self.folder = Instance.new("Folder")
	self.folder.Name = "SkyboundBattleView"
	self.folder.Parent = Workspace
	self.edges, self.wind, self.floorLip = makeArena(self.folder)
	self.groundY = self.floorLip.Position.Y + self.floorLip.Size.Y / 2
	self.folder:SetAttribute("GroundY", self.groundY)
	self.dynamic = Instance.new("Folder")
	self.dynamic.Name = "Combat"
	self.dynamic.Parent = self.folder
	return self
end

function BattleView:_resetRound(roundId)
	self.roundId, self.lastEvent, self.sampleElapsed, self.sampleAge = roundId, 0, nil, 0
	self.finishTime = nil
	for _, fighter in pairs(self.fighters) do
		fighter.position, fighter.pose, fighter.armor = nil, nil, nil
		fighter.hitTime, fighter.blockTime, fighter.lastHitBurst = -100, -100, -100
		fighter.shotTime = -100
		fighter.finishRotation, fighter.finishPosition = nil, nil
		fighter.crash, fighter.crashLanded, fighter.crashContactY = nil, false, nil
		fighter.crashGroundY = nil
		fighter.previousPhase, fighter.observedWindupDuration = nil, nil
		fighter.model:SetAttribute("CrashState", nil)
		fighter.model:SetAttribute("CrashContactY", nil)
		fighter.scuff.Transparency = 1
		hide(fighter.debris)
		fighter.highlight.Enabled = false
		hide(fighter.reticle)
		hide(fighter.aimDots)
		hide(fighter.statusRing)
		hide(fighter.speedLines)
		hide(fighter.cometFlames)
		hide(fighter.signatureSparks)
		hide(fighter.muzzleFlashes)
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
		for _, piece in ipairs(rocket.pieces) do piece.Transparency = 1 end
		table.insert(self.rocketPool, rocket)
		self.rockets[id] = nil
	end
	for _, effect in ipairs(self.effects) do
		effect.active = false
		hide(effect.pieces)
		hide(effect.ring)
		effect.flash.Transparency = 1
	end
end

function BattleView:_fighter(id, index)
	local fighter = self.fighters[id]
	if fighter then return fighter end
	local color = PLAYER_COLORS[index] or PLAYER_COLORS[1]
	local model = self.World.createPlane(self.dynamic, "BattlePlane" .. tostring(id), index, "cruiser")
	model:ScaleTo(SCALE)
	local pivot = model.PrimaryPart
	local trail = pivot:FindFirstChild("Contrail")
	-- The shared racing trail spans the wing axis, which is edge-on here. Give
	-- it vertical separation for a readable ribbon in the fixed side camera.
	trail.Attachment0.Position = Vector3.new(-4.1, -0.4, 0) * SCALE
	trail.Attachment1.Position = Vector3.new(-4.1, 0.4, 0) * SCALE
	trail.Color = ColorSequence.new(color, COLORS.cream)
	trail.Transparency = NumberSequence.new(0.42, 1)
	trail.Lifetime = 0.32
	trail.WidthScale = NumberSequence.new(1, 0)
	local noseGlow = part(model, "ArmedNose", Vector3.one * 2.7, CFrame.new(5.6 * SCALE, 0, 0), color, Enum.Material.Neon, Enum.PartType.Ball)
	noseGlow.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "AttackTell"
	gui.Adornee = pivot
	gui.Size = UDim2.fromOffset(136, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 10000
	gui.Enabled = false
	gui.Parent = pivot
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = COLORS.dark
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = color
	label.TextTransparency = 0
	label.TextStrokeColor3 = COLORS.dark
	label.TextStrokeTransparency = 0.15
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	local highlight = Instance.new("Highlight")
	highlight.Name = "CombatFeedback"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
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
	local scuff = ellipsoid(fx, "CrashScuff", Vector3.new(12, 0.6, 0.25), CFrame.identity, COLORS.dark)
	scuff.Transparency = 1
	local debris = makeRing(fx, "CrashDebris", 5, color)
	for index, fragment in ipairs(debris) do
		fragment.Material = Enum.Material.SmoothPlastic
		fragment.Color = index % 2 == 0 and COLORS.steel or color
	end
	fighter = {
		model = model, color = color, body = model:FindFirstChild("Fuselage"),
		propeller = model:FindFirstChild("Propeller"), trail = trail,
		flare = model:FindFirstChild("FlightFlare"), noseGlow = noseGlow,
		smoke = { model:FindFirstChild("HitSmoke1"), model:FindFirstChild("HitSmoke2"), model:FindFirstChild("HitSmoke3") },
		gui = gui, label = label, hitTime = -100, blockTime = -100, lastHitBurst = -100,
		facing = index == 1 and 1 or -1, highlight = highlight, fx = fx,
		reticle = makeRing(fx, "AttackLock", 8, color),
		aimDots = makeRing(fx, "AimDash", 3, color),
		statusRing = makeRing(fx, "BumperOrVictory", 12, COLORS.yellow),
		speedLines = makeRing(fx, "AfterburnerStreak", 2, COLORS.boost),
		chargeShell = chargeShell, cometFlames = cometFlames, muzzleFlashes = muzzleFlashes,
		signatureSparks = makeRing(fx, "SignatureSpark", 8, COLORS.yellow),
		lampAnchor = lampAnchor, noseLight = noseLight, shotTime = -100,
		scuff = scuff, debris = debris, crashLanded = false,
	}
	-- Smoke is positioned in world space and must never enlarge aircraft
	-- bounds or the damage highlight while a disabled plane falls.
	for _, puff in ipairs(fighter.smoke) do puff.Parent = fx end
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
		fighter.propeller:PivotTo(modelPose * CFrame.new(5.1 * SCALE, 0, 0) * CFrame.Angles(fighter.stoppedPropeller, 0, 0))
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
	return CFrame.new(position) * rotation
end

function BattleView:_setSignature(fighter, powerId)
	if fighter.powerId == powerId then return end
	if fighter.signature then fighter.signature:Destroy() end
	fighter.powerId = powerId
	fighter.signature = Instance.new("Folder")
	fighter.signature.Name = "Signature"
	fighter.signature.Parent = fighter.model
	local pose = fighter.model:GetPivot()
	fighter.chargePieces, fighter.muzzleOffsets = {}, {}
	for _, name in ipairs({ "MainWing", "LeftWingTip", "RightWingTip", "TailWing", "TailFin" }) do
		local original = fighter.model:FindFirstChild(name)
		if original then original.Transparency = 1 end
	end
	local function piece(name, size, offset, color, material, shape, rotation)
		return part(fighter.signature, name, size * SCALE, pose * CFrame.new(offset * SCALE) * (rotation or CFrame.identity), color, material, shape)
	end
	if powerId == "Firework" then
		fighter.body.Size = Vector3.new(9.7, 2.35, 2.6) * SCALE
		piece("ForkedTail", Vector3.new(1.8, 0.25, 6.8), Vector3.new(-3.9, 0.2, 0), COLORS.cream)
		for _, side in ipairs({ -1, 1 }) do
			piece("SweptLaunchWing", Vector3.new(2.6, 0.32, 6.5), Vector3.new(-1.4, -0.45, side * 2.9), fighter.color,
				nil, nil, CFrame.Angles(0, -side * 0.58, 0))
			piece("TwinTailFin", Vector3.new(1.7, 1.7, 0.3), Vector3.new(-3.8, 1.05, side * 1.55), fighter.color,
				nil, nil, CFrame.Angles(0, 0, -0.35))
			piece("RocketPod", Vector3.new(4.1, 1.8, 1.8), Vector3.new(0.8, -0.65, side * 3.75), COLORS.cream, nil, Enum.PartType.Cylinder)
			for _, stripeX in ipairs({ -0.45, 1.0 }) do
				piece("LauncherStripe", Vector3.new(0.5, 1.85, 1.85), Vector3.new(stripeX, -0.65, side * 3.75), fighter.color, nil, Enum.PartType.Cylinder)
			end
			piece("LauncherRim", Vector3.new(0.38, 2.15, 2.15), Vector3.new(2.9, -0.65, side * 3.75), COLORS.steel, nil, Enum.PartType.Cylinder)
			local mouth = piece("IgnitionChamber", Vector3.new(0.12, 1.6, 1.6), Vector3.new(3.11, -0.65, side * 3.75), COLORS.fire, Enum.Material.Neon, Enum.PartType.Cylinder)
			table.insert(fighter.chargePieces, mouth)
			table.insert(fighter.muzzleOffsets, Vector3.new(3.25, -0.65, side * 3.75) * SCALE)
		end
	else
		fighter.body.Size = Vector3.new(8.9, 3.6, 3.8) * SCALE
		piece("HeavyMainWing", Vector3.new(4.3, 0.65, 13.4), Vector3.new(-0.7, -0.15, 0), fighter.color)
		piece("WingArmor", Vector3.new(2.4, 0.18, 10.6), Vector3.new(-0.8, 0.28, 0), COLORS.steel)
		piece("HeavyTailWing", Vector3.new(2.2, 0.42, 6.0), Vector3.new(-3.5, 0.35, 0), COLORS.cream)
		piece("HeavyTailFin", Vector3.new(2.5, 2.8, 0.55), Vector3.new(-3.3, 1.6, 0), fighter.color, nil, nil, CFrame.Angles(0, 0, -0.23))
		piece("ImpactCollar", Vector3.new(1.15, 3.9, 3.9), Vector3.new(3.65, 0, 0), COLORS.yellow, nil, Enum.PartType.Cylinder)
		piece("NoseArmorBand", Vector3.new(0.35, 4.05, 4.05), Vector3.new(3.25, 0, 0), COLORS.steel, nil, Enum.PartType.Cylinder)
		for _, side in ipairs({ -1, 1 }) do
			piece("ArmoredWingTip", Vector3.new(3.9, 0.85, 1.2), Vector3.new(-0.7, -0.05, side * 6.3), COLORS.cream)
			local vent = piece("ChargeVent", Vector3.new(2.0, 0.22, 0.32), Vector3.new(0.3, 1.0, side * 1.65), COLORS.yellow, Enum.Material.Neon)
			table.insert(fighter.chargePieces, vent)
		end
	end
	-- Signature geometry is cosmetic. Collision and damage remain in the sim.
	fighter.model:SetAttribute("PowerId", powerId)
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
	local color = source == "meteor" and COLORS.yellow or (source == "rocket" and actorColor and actorColor:Lerp(COLORS.cream, 0.55) or COLORS.cream)
	self:_burst(x, y, color, true, source)
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
				elseif kind == "dive" and age <= 0.18 then
					-- A complete commitment can hit and recover between snapshots.
					-- Record only a short streak at its real launch point; never keep
					-- the plane looking armed after the simulation has recovered.
					self:_burst(x, y, COLORS.yellow, false, "dive", numeric(event.heading, 0))
				elseif kind == "rocket" then
					if actor then actor.shotTime = self.clock - math.max(0, age) end
				elseif kind == "miss" and actor and actor.powerId == "Firework" then
					self:_burst(x, y, COLORS.steel, false, "fizzle")
				elseif kind == "blocked" then
					if actor then actor.blockTime = self.clock end
					self:_burst(x, y, COLORS.yellow, false)
				elseif kind == "bounce" or kind == "wall" or kind == "bump" then
					self:_burst(x, y, COLORS.steel, false)
				end
			end
		end
	end
	self.lastEvent = newest
end

function BattleView:_signatureEffects(fighter, state, simulation, moving, pose)
	local meteor = fighter.powerId == "Meteor"
	local windup = moving and state.phase == "Windup"
	local armed = moving and state.armed == true
	local charge = windup and chargeProgress(fighter, state, self.sampleAge) or 0
	local shotAge = self.clock - fighter.shotTime
	local shooting = moving and not meteor and shotAge < 0.2
	local winner = simulation.finished == true and simulation.winner == state.id
	local finishAge = self.finishTime and self.clock - self.finishTime or 100
	local pulse = 1 + math.sin(self.clock * 34) * 0.08
	fighter.lampAnchor.CFrame = pose * CFrame.new(6, 0, 0)
	fighter.noseLight.Color = meteor and COLORS.fire or fighter.color
	fighter.noseLight.Brightness = armed and 0.85 or (shooting and 1 or charge * 0.5)
	for index, piece in ipairs(fighter.chargePieces or {}) do
		piece.Color = windup and COLORS.yellow or (armed and COLORS.cream or (meteor and COLORS.yellow or COLORS.fire))
		piece.Transparency = (windup or armed or shooting) and (0.05 + (1 - charge) * 0.15) or 0.62
		if not meteor and windup then piece.Transparency = 0.15 + (math.sin(self.clock * 24 + index * math.pi) + 1) * 0.2 end
	end
	if meteor and (windup or armed) then
		local shellCharge = armed and 1 or charge
		fighter.chargeShell.Size = Vector3.new(9 + shellCharge * 4, 3.8 + shellCharge * 3, 3.6 + shellCharge * 2.6) * SCALE
		fighter.chargeShell.CFrame = pose * CFrame.new(0.8, 0, 0)
		fighter.chargeShell.Color = armed and COLORS.yellow or COLORS.fire
		fighter.chargeShell.Transparency = armed and 0.87 or (0.96 - charge * 0.22)
	else
		fighter.chargeShell.Transparency = 1
	end
	for index, flame in ipairs(fighter.cometFlames) do
		if meteor and armed then
			local length = (21 - index * 4) * pulse
			local width = 5.8 - index * 1.4
			flame.Size = Vector3.new(length, width, width * 0.8)
			flame.CFrame = pose * CFrame.new(-7.4 - length * 0.3, 0, index * 0.2)
			flame.Transparency = 0.42 - index * 0.1
		else flame.Transparency = 1 end
	end
	for index, flash in ipairs(fighter.muzzleFlashes) do
		if shooting and fighter.muzzleOffsets[index] then
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
	fighter.highlight.Enabled = flashing or winner
	fighter.highlight.FillColor = flashing and COLORS.cream or COLORS.yellow
	fighter.highlight.OutlineColor = flashing and COLORS.cream or COLORS.yellow
	fighter.highlight.FillTransparency = flashing and (0.24 + math.min(1, hitAge / 0.18) * 0.65) or 0.88
	fighter.highlight.OutlineTransparency = flashing and 0 or (0.2 + math.sin(self.clock * 3) * 0.08)
	local center = fighter.position + Vector3.new(0, 0, 9)
	if winner then
		ring(fighter.statusRing, center, 10.5 + math.sin(self.clock * 3) * 0.3, COLORS.yellow, 0.2, self.clock * 0.2, 0.5)
	elseif not knockedOut and fighter.modifierId == "SpringBumper" then
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
			streak.Size = Vector3.new(length, 0.36, 0.25)
			streak.CFrame = displayPose * CFrame.new(-10 - length * 0.2, side * 3.1, 3)
			streak.Color, streak.Transparency = COLORS.boost, 0.18
		else
			streak.Transparency = 1
		end
	end
	local tell
	if winner then tell = "WINNER"
	elseif knockedOut then tell = "KNOCKED OUT"
	elseif hitAge < 0.28 then tell = "HIT!"
	elseif blockAge < 0.45 then tell = "BOING!"
	elseif windup then tell = fighter.powerId == "Meteor" and "CHARGING" or "TAKING AIM"
	elseif moving and state.phase == "Attack" then tell = fighter.powerId == "Meteor" and "DIVE!" or "FIRE!"
	elseif boosted then tell = "BOOST!" end
	fighter.gui.Enabled = tell ~= nil
	fighter.label.Text = tell or ""
	fighter.label.TextColor3 = winner and COLORS.yellow or (hitAge < 0.28 and COLORS.cream or fighter.color)
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
		local owner = self.fighters[state.owner]
		local edgeColor = owner and owner.color or COLORS.fire
		-- Keep the authoritative collision footprint fixed as it fades. These
		-- bright discs are hazardous, unlike the thin cosmetic contrails.
		wake.disc.Size = Vector3.new(0.16, radius * 2, radius * 2)
		wake.disc.CFrame = CFrame.new(center) * CFrame.Angles(0, math.pi / 2, 0)
		wake.disc.Color = arming and COLORS.yellow or COLORS.fire
		wake.disc.Transparency = life <= 0 and 1 or (arming and 0.8 or (0.5 + (1 - fraction) * 0.25))
		ring(wake.edge, center + Vector3.new(0, 0, 0.2), radius, edgeColor,
			life <= 0 and 1 or (arming and 0.5 or (0.12 + (1 - fraction) * 0.35)), self.clock * 0.5, 0.36)
	end
end

function BattleView:_camera(rect)
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
	-- Include the aircraft at their extreme positions, not just the playfield.
	local fullHeight = math.max(172 / (regionWidth / width) / aspect, 112 / (regionHeight / height))
	local fullWidth = fullHeight * aspect
	local centerX = ORIGIN.X - ((left + right) / (2 * width) - 0.5) * fullWidth
	local centerY = ORIGIN.Y + CENTER_Y + ((top + bottom) / (2 * height) - 0.5) * fullHeight
	-- Keep geometry close enough for Studio's lowest detail setting. A narrow
	-- lens with a far-away camera can cull the entire arena on small screens.
	local fieldOfView = math.clamp(math.deg(2 * math.atan(fullHeight / 360)), 25, 120)
	local distance = fullHeight / (2 * math.tan(math.rad(fieldOfView) / 2))
	local focus = Vector3.new(centerX, centerY, ORIGIN.Z)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = fieldOfView
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, distance), focus)
	camera.Focus = CFrame.new(focus)
	self.folder:SetAttribute("VisibleHeight", fullHeight)
end

function BattleView:update(snapshot, dt, viewportRect)
	if self.destroyed or not snapshot then return end
	dt = math.clamp(numeric(dt, 1 / 60), 0, 0.1)
	self.clock = self.clock + dt
	if snapshot.roundId ~= self.roundId then self:_resetRound(snapshot.roundId) end
	local simulation = snapshot.simulation or {}
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
	local smoothing = 1 - math.exp(-24 * dt)
	local states = simulation.fighters
	if not states or #states == 0 then
		states = {}
		for index = 1, 2 do
			local settings = snapshot.settings and snapshot.settings[index] or {}
			local direction = index == 1 and 1 or -1
			local angle = math.rad(numeric(settings.angle, 25))
			states[index] = { id = index, powerId = settings.powerId or (index == 1 and "Meteor" or "Firework"),
				modifierId = settings.modifierId or "None", bumperReady = settings.modifierId == "SpringBumper",
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
		self:_setSignature(fighter, state.powerId or (settings and settings.powerId) or "Meteor")
		fighter.modifierId = state.modifierId or (settings and settings.modifierId) or "None"
		if state.phase == "Windup" and fighter.previousPhase ~= "Windup" then
			fighter.observedWindupDuration = math.max(0.01, numeric(state.phaseLeft, 1))
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
		fighter.propeller:PivotTo(displayPose * CFrame.new(5.1 * SCALE, 0, 0) * CFrame.Angles(propellerPhase, 0, 0))
		if fighter.armor and armor < fighter.armor then self:_hit(fighter, state.x, state.y) end
		fighter.armor = armor
		fighter.model:SetAttribute("Armor", armor)
		fighter.model:SetAttribute("Phase", state.phase or "Approach")
		fighter.model:SetAttribute("ModifierId", fighter.modifierId)
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
		fighter.trail.Lifetime = armed and 0.5 or 0.32
		fighter.flare.Transparency = (armed or boosted) and 0.12 or 1
		fighter.flare.Color = boosted and COLORS.boost or (fighter.powerId == "Meteor" and COLORS.yellow or fighter.color)
		fighter.flare.Size = Vector3.new(boosted and 11 or (armed and 9 or 5), boosted and 2 or 1.5, 1.5) * SCALE
		self:_fighterEffects(fighter, state, simulation, moving, displayPose)
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
		local owner = self.fighters[state.owner]
		local color = owner and owner.color or PLAYER_COLORS[tonumber(state.owner) or 1] or COLORS.yellow
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
		rocket.exhaust.Transparency = moving and (0.18 + (sputter - 0.77) * 0.2) or 1
		rocket.core.Size = Vector3.new(2.4 * sputter, 0.62, 0.62)
		rocket.core.CFrame = rocketPose * CFrame.new(-3.55, 0, 0.25)
		rocket.core.Transparency = moving and 0.08 or 1
		for index, spark in ipairs(rocket.sparks) do
			local progress = (self.clock * 7 + index / 3) % 1
			spark.Size = Vector3.new(0.55 * (1 - progress) + 0.12, 0.3, 0.25)
			spark.CFrame = rocketPose * CFrame.new(-4.5 - progress * 3.5, (index % 2 == 0 and 1 or -1) * progress, 1)
			spark.Transparency = moving and progress or 1
		end
		rocket.trail.Enabled = moving
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
				effect.flash.Transparency = progress < 0.3 and (0.2 + progress * 2.5) or 1
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
		self.wind[index].Transparency = pressured and 0.9 or 1
	end
	for index, edge in ipairs(self.edges) do
		edge.Color = pressured and COLORS.yellow or (PLAYER_COLORS[index] or COLORS.steel)
		edge.Transparency = pressured and (0.12 + 0.12 * math.sin(self.clock * 5)) or 0.35
	end
	self.folder:SetAttribute("Phase", snapshot.phase or "Configure")
	self.folder:SetAttribute("RoundId", tostring(snapshot.roundId or ""))
	self:_camera(viewportRect)
end

function BattleView:destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.folder:Destroy()
	table.clear(self.fighters)
	table.clear(self.rockets)
	table.clear(self.rocketPool)
	table.clear(self.effects)
	table.clear(self.wakes)
	table.clear(self.wakePool)
	-- The normal client camera resumes on its next render. No connections,
	-- lighting overrides, delayed callbacks, or external instances survive.
end

return BattleView
