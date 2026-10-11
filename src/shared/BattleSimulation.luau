-- Pure, deterministic battle simulation. No Roblox services or physics.
-- step accepts elapsed time and consumes fixed ticks; a stalled caller advances
-- at most MAX_STEP_DT per call. Rendering reads state but never decides hits.
-- This file owns the round: movement, phases, collisions, damage and endings.
-- What each skill does lives in BattleSkills and is reached only through hooks.
local Skills = require(script.Parent.BattleSkills)
local BattleSimulation = {}

BattleSimulation.CONTRACT_VERSION = "sky-battle-combat-v1"
BattleSimulation.MAX_TOTAL_SPEED = 88
BattleSimulation.MAX_TURN_RATE = 9.6
-- Pull toward the owner's plane, and the stronger pull toward a shot in the air.
BattleSimulation.MAGNET_SPEED = 14
BattleSimulation.MAGNET_SHOT_SPEED = 28
BattleSimulation.FIXED_DT = 1 / 60
BattleSimulation.MAX_STEP_DT = 0.25
-- A round is decided on armor at REGULATION_TIME. Level armor goes to sudden
-- death, where the next armor lost ends it; MAX_TIME is the hard stop.
BattleSimulation.REGULATION_TIME = 22
BattleSimulation.MAX_TIME = 35
BattleSimulation.PRESSURE_START = 10
BattleSimulation.ARENA = { left = -72, right = 72, bottom = 8, top = 96 }
BattleSimulation.PLANE_RADIUS = 5
BattleSimulation.IMPACT_PROTECTION = 0.85
BattleSimulation.HIT_KNOCK = 36
BattleSimulation.APPROACH_TIME = 1.7
BattleSimulation.RECOVERY_TIME = 1
-- How far a plane's seeded timing may drift either side of its base approach.
BattleSimulation.CADENCE_SPREAD = 0.6
-- Every attack begun shortens the trips that follow, down to a floor, so a
-- round ends faster than it started.
BattleSimulation.RUSH_STEP = 0.95
BattleSimulation.RUSH_FLOOR = 0.6
-- A plane that has just been hit is back for its answer sooner.
BattleSimulation.RALLY = 0.5
-- Being hit while charging does not cancel the attack; it only delays it.
BattleSimulation.STAGGER = 0.3
-- A plane keeps circling while it charges and turns its nose in at the end.
BattleSimulation.TURN_WAIT = 1.2
BattleSimulation.AIM_TIME = 0.35
BattleSimulation.AIM_SPEED = 22
-- A plane that is free to fly rolls out of the way of a shot or dive that is
-- about to reach it. A plane that is charging or attacking is committed and
-- cannot; neither can one that rolled a moment ago.
BattleSimulation.DODGE_REACT = 0.34
BattleSimulation.DODGE_TIME = 0.45
BattleSimulation.DODGE_SPEED = 48
BattleSimulation.DODGE_COOLDOWN = 2.4
BattleSimulation.DODGE_MARGIN = 2
BattleSimulation.HOLE_SCARE = 10
BattleSimulation.DANGER_DODGE = 0.6
-- The hit that leaves a plane on its last armor throws it harder.
BattleSimulation.DANGER_KNOCK = 1.4
-- A plane that is not yet ready to attack circles its rival at this distance.
-- Flying nose-first at the rival is saved for the attack itself, so closing in
-- always means something is about to happen.
BattleSimulation.STANDOFF = 46
BattleSimulation.ORBIT_LEAD = 0.9
BattleSimulation.ORBIT_SPEED = 28
-- Closer than this with nothing loaded, a circling plane peels away.
BattleSimulation.KEEP_CLEAR = 24
BattleSimulation.MAX_WILD = 2
BattleSimulation.METEOR_WINDUP = Skills.offence.Meteor.windup
BattleSimulation.WAKE_LIFE = 0.9
BattleSimulation.WAKE_ARM_TIME = 0.2
BattleSimulation.WAKE_RADIUS = 2.5
BattleSimulation.MAX_WAKES = 12

local PI, TAU = math.pi, math.pi * 2
local EPSILON = 0.000000001
local PLANE_REACH = BattleSimulation.PLANE_RADIUS
local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end
local function atan2(y, x)
	if x > 0 then return math.atan(y / x) end
	if x < 0 then return math.atan(y / x) + (y >= 0 and PI or -PI) end
	if y > 0 then return PI / 2 end
	if y < 0 then return -PI / 2 end
	return 0
end
local function turn(heading, target, amount)
	local difference = (target - heading + PI) % TAU - PI
	return (heading + clamp(difference, -amount, amount) + PI) % TAU - PI
end
local function direction(x, y, fallback)
	local length = math.sqrt(x * x + y * y)
	if length < EPSILON then return fallback or 1, 0 end
	return x / length, y / length
end

-- A skill is usable here once it has a BattleSkills table. Parity with
-- SkillCatalog is tested, so this file never needs the catalog itself.
function BattleSimulation.validOffence(id)
	return type(id) == "string" and Skills.offence[id] ~= nil
end

function BattleSimulation.validWild(id)
	return type(id) == "string" and Skills.wild[id] ~= nil
end

-- Lenient on purpose: replay tools may pass anything. Unknown skills fall
-- away; servers reject bad builds with SkillCatalog.build before this point.
-- Wild cards are sorted so the order they were picked in never changes a fight.
local function settings(input, fallback)
	input = type(input) == "table" and input or {}
	local wildIds, seen = {}, {}
	if type(input.wildIds) == "table" then
		for _, id in ipairs(input.wildIds) do
			if #wildIds < BattleSimulation.MAX_WILD and BattleSimulation.validWild(id) and not seen[id] then
				seen[id] = true
				wildIds[#wildIds + 1] = id
			end
		end
	end
	table.sort(wildIds)
	return {
		offenceId = BattleSimulation.validOffence(input.offenceId) and input.offenceId or fallback,
		angle = finite(input.angle) and clamp(input.angle, 10, 55) or 32,
		wildIds = wildIds,
	}
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = copy(item) end
	return result
end

-- What a plane attacks with right now. A wild card may swap the plane into a
-- different form for the rest of the round (an ejected pilot's pea-shooter).
local function offenceOf(fighter)
	return fighter.form and Skills.form[fighter.form] or Skills.offence[fighter.offenceId]
end

-- A mothership does not attack with its own nose or guns: it launches drones.
local function launching(fighter)
	return fighter.mothership == true and not fighter.form
end

-- The source name of a plane whose nose is its weapon right now, or nil.
local function rams(fighter)
	return not launching(fighter) and offenceOf(fighter).ram or nil
end

-- How many planes a fighter is flying: one, or a squadron with one plane per
-- armor left.
local function members(fighter)
	if (fighter.squad or 0) <= 1 then return 1 end
	return math.max(1, math.min(fighter.squad, fighter.armor))
end

-- Where each of a fighter's planes is, given the leader's position. Wingmen
-- fly behind and to either side of the leader.
local WING = { { -9, 8 }, { -9, -8 } }
local function bodies(fighter, x, y, heading)
	local list = { { x = x, y = y } }
	local c, s = math.cos(heading), math.sin(heading)
	for index = 2, members(fighter) do
		local offset = WING[index - 1]
		list[index] = { x = x + offset[1] * c - offset[2] * s, y = y + offset[1] * s + offset[2] * c }
	end
	return list
end

-- Where a fighter's decoy flies: level with the plane and off to one side.
-- Returns nothing while the decoy is popped or was never brought.
local function decoyAt(state, fighter, x, y, heading)
	if not fighter.decoyUp or fighter.armor <= 0 then return nil end
	local side = fighter.decoySide or 1
	return clamp(x - math.sin(heading) * 14 * side, state.bounds.left, state.bounds.right),
		clamp(y + math.cos(heading) * 14 * side, state.bounds.bottom, state.bounds.top)
end

local function event(state, kind, x, y, actor, target, source, skillId)
	state.eventSerial = state.eventSerial + 1
	local entry = {
		serial = state.eventSerial, kind = kind, x = x, y = y,
		actor = actor or 0, target = target or 0,
		at = state.elapsed, source = source, skillId = skillId,
	}
	state.events[#state.events + 1] = entry
	if #state.events > 24 then table.remove(state.events, 1) end
	return entry
end

local function finish(state, reason)
	local a, b = state.fighters[1], state.fighters[2]
	state.finished = true
	state.reason = reason
	state.winner = a.armor == b.armor and 0 or (a.armor > b.armor and 1 or 2)
	for _, fighter in ipairs(state.fighters) do fighter.armed = false end
	event(state, "finish", (a.x + b.x) / 2, (a.y + b.y) / 2, state.winner, 0)
end

local function updateBounds(state)
	local pressure = clamp((state.elapsed - BattleSimulation.PRESSURE_START) /
		(BattleSimulation.REGULATION_TIME - BattleSimulation.PRESSURE_START), 0, 1)
	state.pressure = pressure
	state.bounds = { left = -72 + 24 * pressure, right = 72 - 24 * pressure,
		bottom = 8 + 10 * pressure, top = 96 - 14 * pressure }
end

-- Helpers handed to every skill hook.
local api = { event = event, clamp = clamp, direction = direction, atan2 = atan2,
	IMPACT_PROTECTION = BattleSimulation.IMPACT_PROTECTION }

-- A decoy that is reached pops, and comes back after its cooldown.
function api.pop(state, target, x, y, actorId)
	target.decoyUp, target.decoyLeft = false, Skills.wild.Decoy.cooldown
	target.decoyX, target.decoyY = nil, nil
	event(state, "decoy_pop", x, y, actorId, target.id, "decoy", "Decoy")
end

-- Open a hole in the arena. It drags both planes and bends every shot toward
-- it; once it has armed, its core breaks the armor of the rival that touches
-- it. A squadron opens one hole per plane.
function api.hole(state, fighter, x, y, options)
	state.holes = state.holes or {}
	state._holeSerial = (state._holeSerial or 0) + 1
	local b = state.bounds
	local hole = {
		id = state._holeSerial, owner = fighter.id, skillId = options.skillId,
		x = clamp(x, b.left + 6, b.right - 6), y = clamp(y, b.bottom + 6, b.top - 6),
		life = options.life, maxLife = options.life, armLeft = options.armTime,
		core = options.core * (fighter.shotScale or 1), reach = options.reach, pull = options.pull, bend = options.bend,
	}
	state.holes[#state.holes + 1] = hole
	return hole
end

-- Add a projectile owned by this fighter. It flies straight and hits only the rival.
function api.launch(state, fighter, projectile)
	projectile.radius = (projectile.radius or 3.5) * (fighter.shotScale or 1)
	local leaderX, leaderY = projectile.x, projectile.y
	for index, body in ipairs(bodies(fighter, 0, 0, fighter.heading)) do
		-- Every plane in a squadron fires the same shot from its own nose.
		local shot = projectile
		if index > 1 then
			shot = {}
			for key, value in pairs(projectile) do shot[key] = value end
		end
		state._projectileSerial = state._projectileSerial + 1
		shot.id, shot.owner = state._projectileSerial, fighter.id
		shot.x, shot.y = leaderX + body.x, leaderY + body.y
		if fighter.wrapShots then shot.wraps, shot.life = 2, shot.life + 1 end
		state.projectiles[#state.projectiles + 1] = shot
	end
	return projectile
end

-- Leave a short-lived puff that hurts the rival once it has armed. Each plane
-- keeps at most six; the oldest gives way.
function api.puff(state, fighter, x, y, skillId, options)
	local owned, oldest = 0, nil
	for index, wake in ipairs(state.wakes) do
		if wake.owner == fighter.id then
			owned = owned + 1
			oldest = oldest or index
		end
	end
	if owned >= 6 then table.remove(state.wakes, oldest) end
	if #state.wakes >= BattleSimulation.MAX_WAKES then return nil end
	state._wakeSerial = state._wakeSerial + 1
	local wake = {
		id = state._wakeSerial, owner = fighter.id, skillId = skillId, x = x, y = y,
		radius = options and options.radius or BattleSimulation.WAKE_RADIUS,
		life = options and options.life or BattleSimulation.WAKE_LIFE,
		maxLife = options and options.life or BattleSimulation.WAKE_LIFE, armLeft = BattleSimulation.WAKE_ARM_TIME,
	}
	state.wakes[#state.wakes + 1] = wake
	return wake
end

-- Run one hook on each of a fighter's wild cards, in their sorted order.
local function wild(fighter, hook, ...)
	for _, id in ipairs(fighter.wildIds) do
		local handler = Skills.wild[id]
		if handler and handler[hook] then handler[hook](api, ...) end
	end
end

function BattleSimulation.newRound(seed, settingsA, settingsB)
	seed = finite(seed) and math.floor(math.abs(seed)) % 2147483647 or 1
	if seed == 0 then seed = 1 end
	local randomState = seed
	local function random()
		randomState = (randomState * 16807) % 2147483647
		return (randomState - 1) / 2147483646
	end
	local state = {
		seed = seed, elapsed = 0, finished = false, winner = nil, reason = nil,
		fighters = {}, projectiles = {}, wakes = {}, events = {}, eventSerial = 0,
		_hurt = {}, pressure = 0, regulationTime = BattleSimulation.REGULATION_TIME, maxTime = BattleSimulation.MAX_TIME, _accumulator = 0, _projectileSerial = 0, _bumpCooldown = 0,
		_wakeSerial = 0, spin = seed % 2 == 0 and 1 or -1, exchanges = 0, rush = 1,
	}
	updateBounds(state)
	local configs = { settings(settingsA, "Meteor"), settings(settingsB, "Firework") }
	for id, config in ipairs(configs) do
		local side = id == 1 and 1 or -1
		local heading = math.rad(config.angle)
		if side < 0 then heading = PI - heading end
		-- Seed variation is visible in opening height, never in damage/accuracy.
		local fighter = {
			id = id, offenceId = config.offenceId, settings = config,
			wildIds = config.wildIds, boostLeft = 0,
			_cadence = (seed * 48271 + (seed % 2 == 0 and id or 3 - id) * 1299709) % 2147483647,
			_approachOffset = (((seed * 48271 + (seed % 2 == 0 and id or 3 - id) * 1299709) % 2147483647) / 2147483647 * 2 - 1) * BattleSimulation.CADENCE_SPREAD,
			x = -52 * side, y = 31 + random() * 13,
			heading = heading, vx = math.cos(heading) * 29, vy = math.sin(heading) * 29,
			armor = 3, maxArmor = 3, scale = 1, speedScale = 1, shotScale = 1, squad = 0, phase = "Approach", phaseLeft = (Skills.offence[config.offenceId].approachTime or BattleSimulation.APPROACH_TIME) +
				(configs[1].offenceId == "Meteor" and configs[2].offenceId == "Meteor" and id == seed % 2 + 1 and (0.25 + (seed * 69621 % 9999) / 9999 * 0.35) or 0),
			windupDuration = Skills.offence[config.offenceId].windup,
			armed = false, invulnerable = 0, attacks = 0, hits = 0, dodges = 0, dodgeLeft = 0, dodgeCool = 0,
			radius = BattleSimulation.PLANE_RADIUS, lockX = 0, lockY = 50,
			_knockX = 0, _knockY = 0, _attackHit = false,
		}
		-- The opening pass gets the same seeded timing spread as every later one,
		-- so the same attack does not always strike first.
		-- One extra step of the cadence separates the two planes' timing.
		fighter.phaseLeft = math.max(0.5, fighter.phaseLeft + ((fighter._cadence * 16807) % 2147483647 / 2147483647 * 2 - 1) * BattleSimulation.CADENCE_SPREAD)
		state.fighters[id] = fighter
		wild(fighter, "start", state, fighter)
		event(state, "launch", fighter.x, fighter.y, id, 0)
	end
	-- Name a build the first time its parts meet, so players go looking for more.
	for id, fighter in ipairs(state.fighters) do
		local has = { [fighter.offenceId] = true }
		for _, wildId in ipairs(fighter.wildIds) do has[wildId] = true end
		for _, combo in ipairs(Skills.combos) do
			if has[combo[1]] and has[combo[2]] then
				fighter.combo = combo[3]
				event(state, "combo", fighter.x, fighter.y, id, 0).text = combo[3]
				break
			end
		end
	end
	return state
end

-- Earliest intersection between moving circles. Relative sweeps account for
-- movement of BOTH objects and catch contacts that cross between fixed ticks.
local function sweep(ax, ay, nextAx, nextAy, bx, by, nextBx, nextBy, radius)
	local x, y = ax - bx, ay - by
	local dx, dy = (nextAx - ax) - (nextBx - bx), (nextAy - ay) - (nextBy - by)
	local c = x * x + y * y - radius * radius
	if c <= 0 then return 0 end
	local a = dx * dx + dy * dy
	if a < EPSILON then return nil end
	local b = 2 * (x * dx + y * dy)
	local discriminant = b * b - 4 * a * c
	if discriminant < 0 then return nil end
	local t = (-b - math.sqrt(discriminant)) / (2 * a)
	if t >= 0 and t <= 1 then return t end
	return nil
end

local function recover(state, fighter, opponent, duration)
	wild(fighter, "recover", state, fighter, opponent)
	-- Both pilots still see full tells. Vary only the next visible approach
	-- to prevent identical recovery cycles from becoming permanent trades or
	-- interruptions. The seed records every pass; no accuracy/winner roll.
	fighter._cadence = (fighter._cadence * 16807) % 2147483647
	fighter._approachOffset = (fighter._cadence / 2147483647 * 2 - 1) * BattleSimulation.CADENCE_SPREAD
	-- Both planes circle the same way round, or they would meet head-on.
	state.spin = fighter._cadence % 2 == 0 and 1 or -1
	fighter.phase, fighter.phaseLeft = "Recover", ((duration or offenceOf(fighter).recoveryTime or BattleSimulation.RECOVERY_TIME) * (fighter.rally or 1) * state.rush + (fighter._bumperRecovery or 0)) * (fighter.secondWind and 0.88 or 1) * (fighter.tempo or 1) * (fighter.pace or 1)
	fighter._bumperRecovery = nil
	fighter.dodgeLeft = 0
	fighter.armed = false
	local awayX, awayY = direction(fighter.x - opponent.x, fighter.y - opponent.y, fighter.id == 1 and -1 or 1)
	fighter._recoverX = clamp(fighter.x + awayX * 32, -48, 48)
	-- The higher plane banks up and the lower one down, so two planes turning
	-- away at once open a gap instead of meeting again in the middle.
	local above = fighter.y > opponent.y or (fighter.y == opponent.y and fighter.id == 1)
	fighter._recoverY = clamp(fighter.y + awayY * 15 + (above and 18 or -18), 25, 77)
end

-- A plane caught mid-attack by something that takes its controls away banks
-- off as if the attack were over.
function api.interrupt(state, fighter)
	if fighter.phase == "Windup" or fighter.phase == "Attack" then
		recover(state, fighter, state.fighters[3 - fighter.id])
	end
end

-- Where an attack from (x, y) should aim to meet a moving rival.
local function aimAt(offence, x, y, opponent)
	local distance = math.sqrt((opponent.x - x) ^ 2 + (opponent.y - y) ^ 2)
	local lead = clamp(distance / offence.leadSpeed, 0, 0.95) * offence.leadFactor
	return clamp(opponent.x + opponent.vx * lead, -64, 64), clamp(opponent.y + opponent.vy * lead, 15, 88)
end

local function lockTarget(fighter, opponent)
	fighter.lockX, fighter.lockY = aimAt(offenceOf(fighter), fighter.x, fighter.y, opponent)
end

-- A mothership's drones: small flyers that home on the rival, carry out the
-- plane's attack once from wherever they are, and fly off.
local function launchDrones(state, fighter)
	local self = Skills.wild.Mothership
	state.drones = state.drones or {}
	for index = 1, self.drones do
		state._droneSerial = (state._droneSerial or 0) + 1
		local fan = (index - (self.drones + 1) / 2) * self.fan
		local heading = fighter.heading + fan
		state.drones[#state.drones + 1] = {
			id = state._droneSerial, owner = fighter.id, mode = "fly", age = -(index - 1) * self.stagger,
			x = fighter.x + math.cos(heading) * 6, y = fighter.y + math.sin(heading) * 6,
			heading = heading, vx = math.cos(heading) * self.droneSpeed, vy = math.sin(heading) * self.droneSpeed,
		}
	end
	event(state, "drone", fighter.x, fighter.y, fighter.id, 3 - fighter.id, "drone", "Mothership")
end

-- Lets a drone run its owner's attack hooks from its own position. Everything
-- else the hooks read or write is the owner's.
local function droneProxy(owner, drone)
	return setmetatable({ x = drone.x, y = drone.y, vx = drone.vx, vy = drone.vy,
		heading = drone.heading, _attackHeading = drone.heading },
		{ __index = owner, __newindex = function(_, key, value) owner[key] = value end })
end

local function beginAttack(state, fighter, opponent)
	local offence = offenceOf(fighter)
	lockTarget(fighter, opponent)
	fighter.phase = "Attack"
	fighter.phaseLeft = offence.attackTime
	fighter.armed = rams(fighter) ~= nil
	fighter.attacks = fighter.attacks + 1
	fighter._attackHit, fighter._wrapped = false, false
	state.exchanges = state.exchanges + 1
	state.rush = math.max(BattleSimulation.RUSH_FLOOR, BattleSimulation.RUSH_STEP ^ state.exchanges)
	wild(fighter, "attack", state, fighter, opponent)
	-- The direction is locked for the whole attack; no homing after launch.
	fighter._attackHeading = fighter.heading
	if launching(fighter) then
		fighter.phaseLeft = Skills.wild.Mothership.launchTime
		launchDrones(state, fighter)
	elseif offence.attack then offence.attack(api, state, fighter, opponent) end
end

local function prepare(state, fighter, opponent, dt)
	local offence = offenceOf(fighter)
	fighter.invulnerable = math.max(0, fighter.invulnerable - dt)
	fighter.boostLeft = math.max(0, fighter.boostLeft - dt)
	if fighter.magnetLeft then fighter.magnetLeft = math.max(0, fighter.magnetLeft - dt) end
	fighter.phaseLeft = fighter.phaseLeft - dt
	-- A plane that is held or thrown has no controls: its attack clock stops.
	if fighter.hold or fighter.throw then fighter.phaseLeft = fighter.phaseLeft + dt end
	local carrier = launching(fighter)
	if (fighter.chickenLeft or 0) > 0 then
		-- A chicken cannot attack: it flaps in circles until the spell ends.
		fighter.chickenLeft = math.max(0, fighter.chickenLeft - dt)
		fighter.phase, fighter.armed = "Approach", false
		fighter.phaseLeft = math.max(fighter.phaseLeft, offence.approachTime or BattleSimulation.APPROACH_TIME)
	end
	local dx, dy = opponent.x - fighter.x, opponent.y - fighter.y
	if fighter.phase == "Approach" then
		-- Drones find their own way, so a mothership is always in position.
		local inPosition = carrier or (offence.inPosition ~= nil and offence.inPosition(api, state, fighter, opponent, dx, dy))
		-- Planes take turns: one does not start its charge while its rival is
		-- charging, unless it has already waited long enough.
		local waiting = opponent.phase == "Windup" and not opponent.decoy and fighter.phaseLeft > -BattleSimulation.TURN_WAIT
		if not waiting and (fighter.phaseLeft <= 0 or (fighter.phaseLeft < offence.earliest and inPosition)) then
			fighter.phase, fighter.phaseLeft = "Windup", carrier and Skills.wild.Mothership.windup or fighter.windupDuration
			-- A skill's hurry, and a rally after being hit, last for one trip back to the attack.
			fighter.tempo, fighter.rally = nil, nil
			if offence.windupStart and not carrier then offence.windupStart(api, state, fighter, opponent) end
			lockTarget(fighter, opponent)
			event(state, "windup", fighter.x, fighter.y, fighter.id, opponent.id)
		end
	elseif fighter.phase == "Windup" and fighter.phaseLeft <= 0 then
		beginAttack(state, fighter, opponent)
	elseif fighter.phase == "Attack" and fighter.phaseLeft <= 0 then
		if rams(fighter) and not fighter._attackHit then
			event(state, "miss", fighter.x, fighter.y, fighter.id, opponent.id)
		end
		if offence.release and not carrier then offence.release(api, state, fighter, opponent) end
		recover(state, fighter, opponent)
	elseif fighter.phase == "Recover" and fighter.phaseLeft <= 0 then
		fighter.phase, fighter.phaseLeft = "Approach", ((offence.approachTime or BattleSimulation.APPROACH_TIME) + fighter._approachOffset) * (fighter.tempo or 1) * (fighter.pace or 1) * (fighter.rally or 1) * state.rush
	end

	local targetX, targetY = opponent.x, opponent.y
	local speed, turnRate = 28, 2.8
	local wantX, wantY, wantSpeed, wantTurn
	-- A point on the standoff ring a little way round from here.
	local function ring()
		local awayX, awayY = direction(-dx, -dy, fighter.id == 1 and -1 or 1)
		local c, s = math.cos(BattleSimulation.ORBIT_LEAD), math.sin(BattleSimulation.ORBIT_LEAD) * state.spin
		local reach = offence.standoff or BattleSimulation.STANDOFF
		return clamp(opponent.x + (awayX * c - awayY * s) * reach, state.bounds.left + 6, state.bounds.right - 6),
			clamp(opponent.y + (awayX * s + awayY * c) * reach, state.bounds.bottom + 6, state.bounds.top - 6)
	end
	local free = (fighter.phase == "Approach" or fighter.phase == "Recover") and not fighter.hold and not fighter.throw
	local aiming = false
	if fighter.phase == "Approach" or (carrier and fighter.phase == "Windup") then
		-- A mothership never closes in: it circles until the drones are away.
		-- Only an attack that needs to be close flies nose-first at the rival.
		fighter.circling = carrier or fighter.phaseLeft >= offence.earliest or not (offence.ram or offence.range)
		if fighter.circling then
			targetX, targetY = ring()
			speed, turnRate = BattleSimulation.ORBIT_SPEED, 3.4
		end
		if offence.approach and not carrier then
			wantX, wantY, wantSpeed, wantTurn = offence.approach(api, state, fighter, opponent, dx, dy)
		end
	elseif fighter.phase == "Windup" then
		lockTarget(fighter, opponent)
		aiming = fighter.phaseLeft <= (offence.aimTime or BattleSimulation.AIM_TIME)
		if aiming then
			targetX, targetY = fighter.lockX, fighter.lockY
			speed, turnRate = BattleSimulation.AIM_SPEED, 9
		else
			-- Still flying: the charge is carried round the ring, not hovered.
			targetX, targetY = ring()
			speed, turnRate = BattleSimulation.ORBIT_SPEED, 3.4
		end
		if offence.windupMove and not carrier then
			wantX, wantY, wantSpeed, wantTurn = offence.windupMove(api, state, fighter, opponent)
			-- An attack that steers its own charge is committed for all of it.
			if wantX or wantSpeed then
				aiming = true
				targetX, targetY = fighter.lockX, fighter.lockY
			end
		end
	elseif fighter.phase == "Attack" then
		speed = carrier and 20 or offence.attackSpeed
		fighter.heading = fighter._attackHeading
		if offence.attackTick and not carrier then offence.attackTick(api, state, fighter, dt) end
	elseif fighter.phase == "Recover" then
		targetX, targetY = fighter._recoverX, fighter._recoverY
		speed, turnRate = 30, 3.5
		if fighter.boostLeft > 0 then speed, turnRate = 56, 6 end
	end
	targetX, targetY = wantX or targetX, wantY or targetY
	speed, turnRate = wantSpeed or speed, wantTurn or turnRate
	if fighter.phase == "Approach" and fighter.circling and dx * dx + dy * dy < BattleSimulation.KEEP_CLEAR ^ 2 then
		-- Too close with nothing loaded: peel off instead of brushing past.
		local awayX, awayY = direction(-dx, -dy, fighter.id == 1 and -1 or 1)
		targetX, targetY = fighter.x + awayX * 30, fighter.y + awayY * 30
		turnRate = math.max(turnRate, 4.5)
	end
	-- A plane still circling with its charge can roll too; once its nose turns
	-- in to aim, it is committed.
	free = not fighter.hold and not fighter.throw and (free or (fighter.phase == "Windup" and not aiming))
	fighter.dodgeCool = math.max(0, fighter.dodgeCool - dt)
	fighter.dodgeLeft = free and math.max(0, fighter.dodgeLeft - dt) or 0
	if free and fighter.dodgeLeft <= 0 and fighter.dodgeCool <= 0 then
		local function roll(sx, sy)
			local b = state.bounds
			if fighter.x + sx * 14 < b.left + 3 or fighter.x + sx * 14 > b.right - 3
				or fighter.y + sy * 14 < b.bottom + 3 or fighter.y + sy * 14 > b.top - 3 then sx, sy = -sx, -sy end
			-- A plane on its last armor flies for its life and is ready to roll again sooner.
			fighter.dodgeLeft, fighter.dodgeCool = BattleSimulation.DODGE_TIME, BattleSimulation.DODGE_COOLDOWN * (fighter.armor <= 1 and BattleSimulation.DANGER_DODGE or 1) * (fighter.dodgeScale or 1)
			fighter._dodgeX, fighter._dodgeY = sx, sy
			fighter.dodges = fighter.dodges + 1
			event(state, "dodge", fighter.x, fighter.y, fighter.id, opponent.id).heading = atan2(sy, sx)
			return true
		end
		-- A shot or an armed nose that will reach this plane in a moment.
		local function threat(x, y, vx, vy, radius)
			local px, py, rx, ry = x - fighter.x, y - fighter.y, vx - fighter.vx, vy - fighter.vy
			local closing = rx * rx + ry * ry
			if closing < EPSILON then return false end
			local when = -(px * rx + py * ry) / closing
			if when < 0 or when > BattleSimulation.DODGE_REACT then return false end
			local mx, my = px + rx * when, py + ry * when
			local reach = fighter.radius + radius + BattleSimulation.DODGE_MARGIN
			if mx * mx + my * my > reach * reach then return false end
			-- Roll away from the line the threat is flying, to whichever side is nearer.
			if mx * mx + my * my < 0.25 then
				local side = fighter._cadence % 2 == 0 and 1 or -1
				return roll(direction(-ry * side, rx * side))
			end
			return roll(direction(-mx, -my))
		end
		local rolled = opponent.armed and not opponent.decoy and threat(opponent.x, opponent.y, opponent.vx, opponent.vy, PLANE_REACH)
		for _, projectile in ipairs(state.projectiles) do
			if not rolled and projectile.owner ~= fighter.id then
				rolled = threat(projectile.x, projectile.y, projectile.vx, projectile.vy, projectile.radius or 3.5)
			end
		end
		for _, drone in ipairs(state.drones or {}) do
			if not rolled and drone.owner ~= fighter.id and drone.armed then
				rolled = threat(drone.x, drone.y, drone.vx, drone.vy, Skills.wild.Mothership.droneRadius)
			end
		end
		-- A hole that opens beside the plane, or a beam about to close on it, is
		-- fled directly.
		for _, hole in ipairs(state.holes or {}) do
			local gap = (hole.x - fighter.x) ^ 2 + (hole.y - fighter.y) ^ 2
			if not rolled and hole.owner ~= fighter.id and gap < (hole.core + fighter.radius + BattleSimulation.HOLE_SCARE) ^ 2 then
				rolled = roll(direction(fighter.x - hole.x, fighter.y - hole.y, fighter.id == 1 and -1 or 1))
			end
		end
		if not rolled and not opponent.decoy and opponent.grab and opponent.phase == "Windup" and opponent.phaseLeft <= BattleSimulation.DODGE_REACT
			and dx * dx + dy * dy < (opponent.grab + BattleSimulation.DODGE_MARGIN * 3) ^ 2 then
			roll(direction(-dx, -dy, fighter.id == 1 and -1 or 1))
		end
	end
	if free and fighter.dodgeLeft > 0 then
		targetX, targetY = fighter.x + fighter._dodgeX * 40, fighter.y + fighter._dodgeY * 40
		speed, turnRate = BattleSimulation.DODGE_SPEED, BattleSimulation.MAX_TURN_RATE
	end
	if fighter.secondWind then speed, turnRate = speed * 1.12, turnRate * 1.2 end
	speed = speed * (fighter.speedScale or 1)
	turnRate = math.min(turnRate, BattleSimulation.MAX_TURN_RATE)
	if fighter.phase ~= "Attack" then
		-- Looking ahead turns the plane away from the visible edge before impact.
		local lookX = fighter.x + math.cos(fighter.heading) * speed * 0.45
		local lookY = fighter.y + math.sin(fighter.heading) * speed * 0.45
		if not aiming and fighter.dodgeLeft <= 0 and (lookX < state.bounds.left + 3 or lookX > state.bounds.right - 3 or
			lookY < state.bounds.bottom + 3 or lookY > state.bounds.top - 3) then
			targetX, targetY = 0, (state.bounds.bottom + state.bounds.top) / 2
			turnRate = fighter.boostLeft > 0 and 5.2 or 4.5
		end
		fighter.heading = turn(fighter.heading, atan2(targetY - fighter.y, targetX - fighter.x), turnRate * dt)
	end
	fighter._knockX = fighter._knockX * math.exp(-5 * dt)
	fighter._knockY = fighter._knockY * math.exp(-5 * dt)
	fighter.vx = math.cos(fighter.heading) * speed + fighter._knockX
	fighter.vy = math.sin(fighter.heading) * speed + fighter._knockY
end

-- Returns landed, cancelled. A wild card on the target may cancel the hit;
-- the first one to say so wins and the rest are not asked.
-- A hit normally removes one armor. A shot may carry its own `power`, and a
-- wild card may add to every hit its plane lands through `bonus`.
local function damage(state, actorId, targetId, x, y, dirX, dirY, source, skillId, power)
	local actor, target = state.fighters[actorId], state.fighters[targetId]
	if target.invulnerable > 0 or target.armor <= 0 then return false end
	for _, id in ipairs(target.wildIds) do
		local handler = Skills.wild[id]
		if handler and handler.hit and handler.hit(api, state, target, actor, x, y, dirX, dirY, source) then
			actor._attackHit = true
			return false, true
		end
	end
	local amount = (power or 1) + (actor.bonus or 0)
	target.armor = math.max(0, target.armor - amount)
	target.invulnerable = BattleSimulation.IMPACT_PROTECTION
	-- A hit should throw the plane, not nudge it.
	local knock = BattleSimulation.HIT_KNOCK * (target.armor == 1 and BattleSimulation.DANGER_KNOCK or 1)
	target._knockX, target._knockY = dirX * knock, dirY * knock
	actor.hits = actor.hits + 1
	actor._attackHit = true
	state._hurt[targetId] = true
	event(state, source == "wake" and "wake_hit" or "hit", x, y, actorId, targetId, source, skillId).amount = amount
	-- A hot potato always jumps to whoever was hit last.
	for _, potato in ipairs(state.potatoes or {}) do
		if potato.holder ~= targetId and targetId == potato.owner and potato.grace > 0 then
			-- The first hit on the bomb's owner does not hand it over.
			potato.grace = potato.grace - 1
		elseif potato.holder ~= targetId then
			potato.holder = targetId
			event(state, "potato_pass", target.x, target.y, actorId, targetId, "potato", "HotPotato")
		end
	end
	wild(target, "damaged", state, target, actor)
	wild(actor, "landed", state, actor, target)
	return true
end

local function tick(state)
	local dt = math.min(BattleSimulation.FIXED_DT, BattleSimulation.MAX_TIME - state.elapsed)
	state.elapsed = math.min(BattleSimulation.MAX_TIME, state.elapsed + dt)
	updateBounds(state)
	state._bumpCooldown = math.max(0, state._bumpCooldown - dt)
	state._hurt = {}
	if state.recording then
		-- Keep a few seconds of the round, four pictures a second, for Rewind.
		local history = state._history or {}
		state._history = history
		local last = history[#history]
		if not last or state.elapsed - last.at >= 0.25 - EPSILON then
			local picture = {}
			for key, value in pairs(state) do
				if key ~= "_history" and key ~= "events" then picture[key] = copy(value) end
			end
			history[#history + 1] = { at = state.elapsed, state = picture }
			while history[1].at < state.elapsed - Skills.wild.Rewind.back - EPSILON do table.remove(history, 1) end
		end
	end
	local previous = {}
	for id, fighter in ipairs(state.fighters) do
		previous[id] = { id = id, x = fighter.x, y = fighter.y, vx = fighter.vx, vy = fighter.vy, heading = fighter.heading, armed = fighter.armed,
			phase = fighter.phase, phaseLeft = fighter.phaseLeft, grab = not launching(fighter) and offenceOf(fighter).range or nil }
	end
	-- Both plans read the same pre-tick snapshot, avoiding first-player bias.
	-- A plane goes for whichever is nearer: its rival or its rival's decoy.
	local function quarry(viewer, id)
		local real = previous[id]
		local x, y = decoyAt(state, state.fighters[id], real.x, real.y, real.heading)
		if not x or (x - viewer.x) ^ 2 + (y - viewer.y) ^ 2 >= (real.x - viewer.x) ^ 2 + (real.y - viewer.y) ^ 2 then return real end
		return { id = id, x = x, y = y, vx = real.vx, vy = real.vy, heading = real.heading, armed = real.armed, decoy = true,
			phase = real.phase, phaseLeft = real.phaseLeft, grab = real.grab }
	end
	for id, fighter in ipairs(state.fighters) do prepare(state, fighter, quarry(previous[id], 3 - id), dt) end
	-- A live magnet yanks the rival toward its owner's attack: the nearest shot
	-- the owner has in the air, or the owner's plane if there is none. The owner
	-- is not moved, and projectiles and wakes are never touched. Cap final
	-- velocity after knockback and pull.
	for id, fighter in ipairs(state.fighters) do
		if (state.fighters[3 - id].magnetLeft or 0) > 0 then
			local opponent = previous[3 - id]
			local towardX, towardY, nearest = opponent.x, opponent.y, math.huge
			local pull = BattleSimulation.MAGNET_SPEED
			for _, projectile in ipairs(state.projectiles) do
				local gap = (projectile.x - fighter.x) ^ 2 + (projectile.y - fighter.y) ^ 2
				if projectile.owner == 3 - id and gap < nearest then
					nearest, towardX, towardY = gap, projectile.x, projectile.y
					pull = BattleSimulation.MAGNET_SHOT_SPEED
				end
			end
			local nx, ny = direction(towardX - fighter.x, towardY - fighter.y)
			fighter.vx, fighter.vy = fighter.vx + nx * pull, fighter.vy + ny * pull
		end
		-- A hole drags every plane inside its reach, its owner included.
		for _, hole in ipairs(state.holes or {}) do
			local gap = math.sqrt((hole.x - fighter.x) ^ 2 + (hole.y - fighter.y) ^ 2)
			if gap < hole.reach and gap > EPSILON then
				local pull = hole.pull * (1 - gap / hole.reach)
				fighter.vx, fighter.vy = fighter.vx + (hole.x - fighter.x) / gap * pull, fighter.vy + (hole.y - fighter.y) / gap * pull
			end
		end
		if fighter.hold then
			-- Caught in a beam: dragged to where the beam holds it, whatever it wants.
			local hold = fighter.hold
			fighter.vx, fighter.vy = (hold.x - fighter.x) * 8, (hold.y - fighter.y) * 8
			hold.left = hold.left - dt
			if hold.left <= 0 then fighter.hold = nil end
		elseif fighter.throw then
			local throw = fighter.throw
			fighter.vx, fighter.vy = throw.vx, throw.vy
			throw.left = throw.left - dt
			if throw.left <= 0 then fighter.throw = nil end
		end
		local magnitude = math.sqrt(fighter.vx ^ 2 + fighter.vy ^ 2)
		if magnitude > BattleSimulation.MAX_TOTAL_SPEED then
			fighter.vx, fighter.vy = fighter.vx * BattleSimulation.MAX_TOTAL_SPEED / magnitude, fighter.vy * BattleSimulation.MAX_TOTAL_SPEED / magnitude
		end
	end
	local edgeHit, slams = {}, {}
	for id, fighter in ipairs(state.fighters) do
		local x, y = fighter.x + fighter.vx * dt, fighter.y + fighter.vy * dt
		fighter.x = clamp(x, state.bounds.left, state.bounds.right)
		fighter.y = clamp(y, state.bounds.bottom, state.bounds.top)
		edgeHit[id] = x ~= fighter.x or y ~= fighter.y
		if fighter.throw and edgeHit[id] then
			-- A thrown plane that reaches a wall is slammed into it.
			slams[#slams + 1] = { id = id, by = fighter.throw.by, vx = fighter.throw.vx, vy = fighter.throw.vy }
			fighter.throw = nil
		end
		if fighter.wrapShots and fighter.phase == "Attack" and rams(fighter) and not fighter._wrapped
			and (x < state.bounds.left or x > state.bounds.right) then
			-- A wrapping dive leaves one side of the arena and carries on from the other.
			event(state, "wrap", fighter.x, fighter.y, id, 0, "plane", "Wrap")
			fighter.x = x < state.bounds.left and state.bounds.right or state.bounds.left
			fighter._wrapped, edgeHit[id] = true, false
			local rival = state.fighters[3 - id]
			fighter._attackHeading = atan2(rival.y - fighter.y, rival.x - fighter.x)
			fighter.heading = fighter._attackHeading
			previous[id].x, previous[id].y = fighter.x, fighter.y
			event(state, "wrap", fighter.x, fighter.y, id, 0, "plane", "Wrap")
		end
		wild(fighter, "moved", state, fighter, dt)
		fighter.decoyX, fighter.decoyY = decoyAt(state, fighter, fighter.x, fighter.y, fighter.heading)
	end

	local a, b = state.fighters[1], state.fighters[2]
	-- Any plane of one side touching any plane of the other counts.
	local function strike(oldX, oldY, x, y, targetId, radius)
		local target, old, best = state.fighters[targetId], previous[targetId], nil
		local before, after = bodies(target, old.x, old.y, old.heading), bodies(target, target.x, target.y, target.heading)
		for index, body in ipairs(after) do
			local t = sweep(oldX, oldY, x, y, before[index].x, before[index].y, body.x, body.y, target.radius + radius)
			if t and (not best or t < best) then best = t end
		end
		return best
	end
	local contact
	local wasA, nowA = bodies(a, previous[1].x, previous[1].y, previous[1].heading), bodies(a, a.x, a.y, a.heading)
	for index, body in ipairs(nowA) do
		local t = strike(wasA[index].x, wasA[index].y, body.x, body.y, 2, a.radius)
		if t and (not contact or t < contact) then contact = t end
	end
	local landed, blocked, resolved = {}, {}, {}
	if contact then
		-- Evaluate BOTH armed noses before applying recovery: simultaneous strikes
		-- are allowed, including a double knockout, rather than favoring index 1.
		for id, fighter in ipairs(state.fighters) do
			local opponent, old, otherOld = state.fighters[3 - id], previous[id], previous[3 - id]
			local x = old.x + (fighter.x - old.x) * contact
			local y = old.y + (fighter.y - old.y) * contact
			local ox = otherOld.x + (opponent.x - otherOld.x) * contact
			local oy = otherOld.y + (opponent.y - otherOld.y) * contact
			local forward = (ox - x) * math.cos(fighter.heading) + (oy - y) * math.sin(fighter.heading)
			-- A squadron dives as a wall of noses, and any of a rival squadron's
			-- planes ahead of the nose can be the one that is struck.
			local ahead = forward >= -EPSILON or members(fighter) > 1
			for _, body in ipairs(bodies(opponent, ox, oy, opponent.heading)) do
				ahead = ahead or (body.x - x) * math.cos(fighter.heading) + (body.y - y) * math.sin(fighter.heading) >= -EPSILON
			end
			if fighter.armed and not fighter._attackHit and ahead then
				landed[id], blocked[id] = damage(state, id, 3 - id, (x + ox) / 2, (y + oy) / 2,
					math.cos(fighter.heading), math.sin(fighter.heading), rams(fighter))
				resolved[id] = landed[id] or blocked[id]
			end
		end
		if state._bumpCooldown <= 0 then
			local nx, ny = direction(a.x - b.x, a.y - b.y, -1)
			if not blocked[1] and not blocked[2] then
				a._knockX, a._knockY = nx * 26, ny * 26
				b._knockX, b._knockY = -nx * 26, -ny * 26
			end
			state._bumpCooldown = 0.45
			-- Planes still tangled just after a hit are part of that hit, not news.
			if not landed[1] and not landed[2] and not blocked[1] and not blocked[2]
				and a.invulnerable <= 0 and b.invulnerable <= 0 then
				event(state, "bump", (a.x + b.x) / 2, (a.y + b.y) / 2, 1, 2)
			end
		end
	end

	-- An armed nose that reaches a decoy pops it and wastes the dive.
	local function pop(target, x, y, actorId) api.pop(state, target, x, y, actorId) end
	for id, fighter in ipairs(state.fighters) do
		local opponent, otherOld = state.fighters[3 - id], previous[3 - id]
		local x, y = decoyAt(state, opponent, opponent.x, opponent.y, opponent.heading)
		if x and fighter.armed and not fighter._attackHit and not resolved[id] then
			local oldX, oldY = decoyAt(state, opponent, otherOld.x, otherOld.y, otherOld.heading)
			if sweep(previous[id].x, previous[id].y, fighter.x, fighter.y, oldX, oldY, x, y, fighter.radius + opponent.radius) then
				pop(opponent, x, y, id)
				fighter._attackHit = true
			end
		end
	end

	for _, slam in ipairs(slams) do
		local nx, ny = direction(slam.vx, slam.vy)
		local victim = state.fighters[slam.id]
		local successful, absorbed = damage(state, slam.by, slam.id, victim.x, victim.y, -nx, -ny, "ufo", "UFOBeam")
		if successful then landed[slam.by] = true end
		if successful or absorbed then resolved[slam.by] = true end
		event(state, "slam", victim.x, victim.y, slam.by, slam.id, "ufo", "UFOBeam").landed = successful == true
	end

	local openHoles = {}
	for _, hole in ipairs(state.holes or {}) do
		hole.life = hole.life - dt
		hole.armLeft = math.max(0, hole.armLeft - dt)
		local targetId = 3 - hole.owner
		local hit = hole.armLeft <= 0 and hole.life > 0 and strike(hole.x, hole.y, hole.x, hole.y, targetId, hole.core)
		if hit then
			-- The core takes one bite and the hole collapses.
			local target = state.fighters[targetId]
			local nx, ny = direction(target.x - hole.x, target.y - hole.y, targetId == 1 and -1 or 1)
			local successful, absorbed = damage(state, hole.owner, targetId, hole.x, hole.y, nx, ny, "blackhole", hole.skillId)
			if successful then landed[hole.owner] = true end
			if successful or absorbed then resolved[hole.owner] = true end
			event(state, "hole_close", hole.x, hole.y, hole.owner, targetId, "blackhole", hole.skillId)
		elseif hole.life > 0 then
			openHoles[#openHoles + 1] = hole
		else
			event(state, "hole_close", hole.x, hole.y, hole.owner, 0, "blackhole", hole.skillId)
		end
	end
	if state.holes then state.holes = openHoles end

	local flying = {}
	for _, drone in ipairs(state.drones or {}) do
		local carrier = Skills.wild.Mothership
		local owner, target = state.fighters[drone.owner], quarry(drone, 3 - drone.owner)
		local offence = offenceOf(owner)
		local oldX, oldY = drone.x, drone.y
		local speed = carrier.droneSpeed
		drone.age = drone.age + dt
		if drone.dead or owner.armor <= 0 then
			drone.mode, drone.left, drone.armed = "gone", 0, false
		elseif drone.mode == "fly" then
			drone.heading = turn(drone.heading, atan2(target.y - drone.y, target.x - drone.x), carrier.droneTurn * dt)
			local range = math.min(carrier.range, offence.range and offence.range - 6 or carrier.range)
			local gap = (target.x - drone.x) ^ 2 + (target.y - drone.y) ^ 2
			-- One drone attacks at a time; the next holds its fire until it is done.
			local busy = false
			for _, other in ipairs(state.drones) do busy = busy or (other.owner == drone.owner and other.mode == "fire") end
			if not busy and drone.age >= carrier.arm and (gap < range * range or drone.age >= carrier.flight) then
				-- The drone carries out its owner's attack from where it is.
				local aimX, aimY = aimAt(offence, drone.x, drone.y, target)
				drone.heading = atan2(aimY - drone.y, aimX - drone.x)
				drone.mode, drone.left = "fire", offence.attackTime
				owner.attacks = owner.attacks + 1
				event(state, "drone_fire", drone.x, drone.y, drone.owner, target.id, "drone", "Mothership").heading = drone.heading
				if offence.ram then drone.armed = true
				elseif offence.attack then offence.attack(api, state, droneProxy(owner, drone), target) end
			end
		elseif drone.mode == "fire" then
			speed = offence.ram and offence.attackSpeed * carrier.dive or carrier.droneSpeed * 0.4
			if offence.attackTick then offence.attackTick(api, state, droneProxy(owner, drone), dt) end
			drone.left = drone.left - dt
			if drone.left <= 0 then
				if offence.release then offence.release(api, state, droneProxy(owner, drone), target) end
				if drone.armed then event(state, "miss", drone.x, drone.y, drone.owner, target.id) end
				drone.mode, drone.left, drone.armed = "leave", carrier.leave, false
			end
		else
			drone.left = drone.left - dt
		end
		drone.vx, drone.vy = math.cos(drone.heading) * speed, math.sin(drone.heading) * speed
		drone.x, drone.y = drone.x + drone.vx * dt, drone.y + drone.vy * dt
		if drone.armed then
			local hit = strike(oldX, oldY, drone.x, drone.y, 3 - drone.owner, carrier.droneRadius)
			local rival = state.fighters[3 - drone.owner]
			local decoyX, decoyY = decoyAt(state, rival, rival.x, rival.y, rival.heading)
			if hit then
				local successful, absorbed = damage(state, drone.owner, 3 - drone.owner, drone.x, drone.y,
					math.cos(drone.heading), math.sin(drone.heading), offence.ram, owner.offenceId)
				if successful then landed[drone.owner] = true end
				if successful or absorbed then resolved[drone.owner] = true end
				drone.mode, drone.left, drone.armed = "gone", 0, false
				event(state, "drone_pop", drone.x, drone.y, drone.owner, 0, "drone", "Mothership")
			elseif decoyX and (decoyX - drone.x) ^ 2 + (decoyY - drone.y) ^ 2 < (carrier.droneRadius + rival.radius) ^ 2 then
				pop(rival, decoyX, decoyY, drone.owner)
				drone.mode, drone.left, drone.armed = "gone", 0, false
				event(state, "drone_pop", drone.x, drone.y, drone.owner, 0, "drone", "Mothership")
			end
		end
		local b = state.bounds
		if (drone.mode == "fly" or drone.mode == "fire" or drone.left > 0)
			and drone.x > b.left - 12 and drone.x < b.right + 12 and drone.y > b.bottom - 12 and drone.y < b.top + 12 then
			flying[#flying + 1] = drone
		end
	end
	if state.drones then state.drones = flying end

	local surviving = {}
	for _, projectile in ipairs(state.projectiles) do
		-- A hole bends every shot in its reach and swallows what reaches its core.
		local swallowed = false
		for _, hole in ipairs(state.holes or {}) do
			local gap = math.sqrt((hole.x - projectile.x) ^ 2 + (hole.y - projectile.y) ^ 2)
			if gap < hole.core then swallowed = true
			elseif gap < hole.reach then
				local speed = math.sqrt(projectile.vx ^ 2 + projectile.vy ^ 2)
				local bend = hole.bend * (1 - gap / hole.reach) * dt
				local nx, ny = direction(projectile.vx + (hole.x - projectile.x) / gap * bend, projectile.vy + (hole.y - projectile.y) / gap * bend)
				projectile.vx, projectile.vy = nx * speed, ny * speed
			end
		end
		if swallowed then projectile.life = 0 end
		if projectile.returnAfter then
			-- A boomerang flies out, then curves back to wherever its thrower is now.
			projectile.age = (projectile.age or 0) + dt
			if projectile.age >= projectile.returnAfter then
				local owner = state.fighters[projectile.owner]
				local nx, ny = direction(owner.x - projectile.x, owner.y - projectile.y)
				local blend = math.min(1, 5 * dt)
				projectile.vx = projectile.vx + (nx * projectile.returnSpeed - projectile.vx) * blend
				projectile.vy = projectile.vy + (ny * projectile.returnSpeed - projectile.vy) * blend
				projectile.returning = true
			end
		end
		local oldX, oldY = projectile.x, projectile.y
		projectile.x, projectile.y = oldX + projectile.vx * dt, oldY + projectile.vy * dt
		projectile.life = projectile.life - dt
		local targetId = 3 - projectile.owner
		local target, old = state.fighters[targetId], previous[targetId]
		local hit = strike(oldX, oldY, projectile.x, projectile.y, targetId, projectile.radius or 3.5)
		local decoyX, decoyY = decoyAt(state, target, target.x, target.y, target.heading)
		local fooled
		if decoyX then
			local wasX, wasY = decoyAt(state, target, old.x, old.y, old.heading)
			fooled = sweep(oldX, oldY, projectile.x, projectile.y, wasX, wasY, decoyX, decoyY, target.radius + (projectile.radius or 3.5))
		end
		local thrower = state.fighters[projectile.owner]
		local swatted
		for _, drone in ipairs(state.drones or {}) do
			if drone.owner == targetId and not drone.dead and not swatted
				and sweep(oldX, oldY, projectile.x, projectile.y, drone.x, drone.y, drone.x, drone.y,
					Skills.wild.Mothership.droneRadius + (projectile.radius or 3.5)) then
				swatted = drone
			end
		end
		if swallowed then
			event(state, "swallow", projectile.x, projectile.y, projectile.owner, 0, projectile.source)
		elseif swatted and not hit then
			-- The shot is spent on a drone.
			swatted.dead = true
			event(state, "drone_pop", swatted.x, swatted.y, projectile.owner, targetId, "drone", "Mothership")
		elseif fooled and (not hit or fooled < hit) then
			-- The shot is spent on the decoy.
			pop(target, decoyX, decoyY, projectile.owner)
		elseif projectile.returning and not hit and (projectile.x - thrower.x) ^ 2 + (projectile.y - thrower.y) ^ 2 < (thrower.radius + 4) ^ 2 then
			event(state, "catch", projectile.x, projectile.y, projectile.owner, 0, projectile.source)
		elseif hit then
			local nx, ny = direction(projectile.vx, projectile.vy)
			local successful, absorbed = false, false
			local actor = state.fighters[projectile.owner]
			if projectile.source == "machinegun" then
				if projectile.burstId == actor.attacks and not actor.burstCancelled and not actor._burstDamaged then
					-- Protection cancels this burst without spending a bumper. A
					-- bumper cancels the WHOLE burst on its first tracer contact.
					if target.invulnerable > 0 then actor.burstCancelled = true
					elseif target.bumperReady then
						absorbed = Skills.wild.SpringBumper.hit(api, state, target, actor, projectile.x, projectile.y, nx, ny, "machinegun")
						actor.burstCancelled = true
					else
						actor.burstConnections = actor.burstConnections + 1
						local spark = event(state, "tracer_hit", projectile.x, projectile.y, actor.id, targetId, "machinegun", "MachineGun")
						spark.connections, spark.threshold = actor.burstConnections, 3
						target._knockX, target._knockY = nx * 2, ny * 2
						if actor.burstConnections >= 3 then
							successful, absorbed = damage(state, actor.id, targetId, projectile.x, projectile.y, nx, ny, "machinegun", "MachineGun")
							actor._burstDamaged = successful
						end
					end
				end
			else
				successful, absorbed = damage(state, projectile.owner, targetId,
					oldX + (projectile.x - oldX) * hit, oldY + (projectile.y - oldY) * hit, nx, ny, projectile.source or "rocket", nil, projectile.power)
			end
			if successful then landed[projectile.owner] = true end
			if successful or absorbed then resolved[projectile.owner] = true end
			-- Impact protection absorbs subsequent projectiles visibly at contact;
			-- they never wait inside a protected plane to deal delayed damage.
			if not successful and not absorbed then event(state, "miss", projectile.x, projectile.y, projectile.owner, targetId) end
		elseif projectile.life > 0 and (projectile.wraps or 0) > 0 and (projectile.bounces or 0) <= 0 and (projectile.x < state.bounds.left or projectile.x > state.bounds.right
			or projectile.y < state.bounds.bottom or projectile.y > state.bounds.top) then
			-- A wrapping shot leaves one edge and comes back in the opposite one.
			local b = state.bounds
			event(state, "wrap", clamp(projectile.x, b.left, b.right), clamp(projectile.y, b.bottom, b.top), projectile.owner, 0, projectile.source, "Wrap")
			if projectile.x < b.left then projectile.x = b.right elseif projectile.x > b.right then projectile.x = b.left end
			if projectile.y < b.bottom then projectile.y = b.top elseif projectile.y > b.top then projectile.y = b.bottom end
			projectile.wraps = projectile.wraps - 1
			-- Coming back in, the shot turns once toward where the rival is now.
			local speed = math.sqrt(projectile.vx ^ 2 + projectile.vy ^ 2)
			local nx, ny = direction(target.x - projectile.x, target.y - projectile.y)
			projectile.vx, projectile.vy = nx * speed, ny * speed
			event(state, "wrap", projectile.x, projectile.y, projectile.owner, 0, projectile.source, "Wrap")
			surviving[#surviving + 1] = projectile
		elseif projectile.life > 0 and (projectile.bounces or 0) > 0 and (projectile.x < state.bounds.left or projectile.x > state.bounds.right
			or projectile.y < state.bounds.bottom or projectile.y > state.bounds.top) then
			-- A bouncing shot reflects off the visible arena edge and flies on.
			if projectile.x < state.bounds.left or projectile.x > state.bounds.right then projectile.vx = -projectile.vx end
			if projectile.y < state.bounds.bottom or projectile.y > state.bounds.top then projectile.vy = -projectile.vy end
			projectile.x = clamp(projectile.x, state.bounds.left, state.bounds.right)
			projectile.y = clamp(projectile.y, state.bounds.bottom, state.bounds.top)
			projectile.bounces = projectile.bounces - 1
			event(state, "bounce", projectile.x, projectile.y, projectile.owner, 0, projectile.source)
			surviving[#surviving + 1] = projectile
		elseif projectile.life <= 0 or projectile.x < state.bounds.left - 10 or projectile.x > state.bounds.right + 10 or
			projectile.y < state.bounds.bottom - 10 or projectile.y > state.bounds.top + 10 then
			event(state, "miss", projectile.x, projectile.y, projectile.owner, targetId)
		else
			surviving[#surviving + 1] = projectile
		end
	end
	state.projectiles = surviving
	local remainingWakes = {}
	for _, wake in ipairs(state.wakes) do
		wake.life = wake.life - dt
		wake.armLeft = math.max(0, wake.armLeft - dt)
		local targetId = 3 - wake.owner
		local target, old = state.fighters[targetId], previous[targetId]
		local hit = wake.armLeft <= 0 and wake.life > 0 and strike(wake.x, wake.y, wake.x, wake.y, targetId, wake.radius)
		if hit then
			local nx, ny = direction(target.x - wake.x, target.y - wake.y, targetId == 1 and -1 or 1)
			local successful, absorbed = damage(state, wake.owner, targetId, wake.x, wake.y, nx, ny, "wake", wake.skillId)
			if successful then landed[wake.owner] = true end
			if successful or absorbed then resolved[wake.owner] = true end
			-- A crossed puff is consumed even during impact protection. No delayed
			-- damage can hide inside the protected plane, and the owner is immune.
		elseif wake.life > 0 then
			remainingWakes[#remainingWakes + 1] = wake
		end
	end
	state.wakes = remainingWakes
	for id, fighter in ipairs(state.fighters) do
		local rival = state.fighters[3 - id]
		if resolved[id] and fighter.phase == "Attack" and rams(fighter) then
			-- The dive is spent on whatever it struck.
			recover(state, fighter, rival)
		elseif resolved[3 - id] and not fighter.hold and not fighter.throw and (fighter.phase == "Approach" or fighter.phase == "Recover") then
			-- Struck while free: bank away and come back sooner for the answer.
			if state._hurt[id] then fighter.rally = BattleSimulation.RALLY end
			recover(state, fighter, rival)
		elseif resolved[3 - id] and fighter.phase == "Windup" then
			-- Struck mid-charge: the attack is delayed, not cancelled.
			fighter.phaseLeft = fighter.phaseLeft + BattleSimulation.STAGGER
		elseif edgeHit[id] and fighter.phase == "Attack" then
			if rams(fighter) and not fighter._attackHit then
				event(state, "miss", fighter.x, fighter.y, id, 3 - id)
			end
			recover(state, fighter, rival)
		end
	end
	-- A hot potato goes off in the hands of whoever holds it. Nothing blocks it.
	for index = #(state.potatoes or {}), 1, -1 do
		local potato = state.potatoes[index]
		potato.left = potato.left - dt
		if potato.left <= 0 then
			local holder = state.fighters[potato.holder]
			table.remove(state.potatoes, index)
			if holder.armor > 0 then
				holder.armor = holder.armor - 1
				holder.invulnerable = BattleSimulation.IMPACT_PROTECTION
				event(state, "potato", holder.x, holder.y, 3 - potato.holder, potato.holder, "potato", "HotPotato")
				wild(holder, "damaged", state, holder, state.fighters[3 - potato.holder])
			end
		end
	end
	if state._rewind then
		-- The hit that set this off never happened: put the round back as it was
		-- a few seconds ago. The clock, the closing walls and the list of events
		-- carry on, so nothing a client has already seen is taken back.
		local owner, past = state._rewind, (state._history or {})[1]
		state._rewind = nil
		if past then
			local kept = { seed = true, elapsed = true, events = true, eventSerial = true, _accumulator = true,
				_projectileSerial = true, _wakeSerial = true, _droneSerial = true, _holeSerial = true, rewound = true, recording = true,
				regulationTime = true, maxTime = true, suddenDeath = true, pressure = true, bounds = true, _history = true }
			for key in pairs(state) do if not kept[key] and past.state[key] == nil then state[key] = nil end end
			for key, value in pairs(past.state) do if not kept[key] then state[key] = copy(value) end end
			state._history = {}
			state.rewound = state.rewound or {}
			state.rewound[owner] = true
			for id in pairs(state.rewound) do state.fighters[id].rewindReady = false end
			-- It must not simply play out the same way: both planes get new timing
			-- and circle the other way round.
			for _, fighter in ipairs(state.fighters) do
				fighter._cadence = (fighter._cadence * 16807) % 2147483647
				fighter.x = clamp(fighter.x, state.bounds.left, state.bounds.right)
				fighter.y = clamp(fighter.y, state.bounds.bottom, state.bounds.top)
			end
			state.spin = -state.spin
			a, b = state.fighters[1], state.fighters[2]
			event(state, "rewind", (a.x + b.x) / 2, (a.y + b.y) / 2, owner, 3 - owner, "rewind", "Rewind").back = state.elapsed - past.at
		end
	end
	if a.armor <= 0 or b.armor <= 0 then
		finish(state, "knockout")
	elseif state.elapsed >= BattleSimulation.MAX_TIME - EPSILON then
		state.elapsed = BattleSimulation.MAX_TIME
		finish(state, "timeout")
	elseif state.suddenDeath then
		if a.armor ~= b.armor then finish(state, "sudden_death") end
	elseif state.elapsed >= BattleSimulation.REGULATION_TIME - EPSILON then
		if a.armor ~= b.armor then
			finish(state, "timeout")
		else
			state.suddenDeath = true
			event(state, "sudden_death", (a.x + b.x) / 2, (a.y + b.y) / 2, 0, 0)
		end
	end
end

function BattleSimulation.step(state, dt)
	if state.finished or not finite(dt) or dt <= 0 then return state end
	state._accumulator = state._accumulator + math.min(dt, BattleSimulation.MAX_STEP_DT)
	while state._accumulator + EPSILON >= BattleSimulation.FIXED_DT and not state.finished do
		state._accumulator = math.max(0, state._accumulator - BattleSimulation.FIXED_DT)
		tick(state)
	end
	return state
end

return BattleSimulation
