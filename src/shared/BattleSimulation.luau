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
BattleSimulation.MAGNET_SHOT_SPEED = 45
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
BattleSimulation.APPROACH_TIME = 3
BattleSimulation.RECOVERY_TIME = 2
-- A plane that is not yet ready to attack circles its rival at this distance.
-- Flying nose-first at the rival is saved for the attack itself, so closing in
-- always means something is about to happen.
BattleSimulation.STANDOFF = 34
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

-- What a plane attacks with right now. A wild card may swap the plane into a
-- different form for the rest of the round (an ejected pilot's pea-shooter).
local function offenceOf(fighter)
	return fighter.form and Skills.form[fighter.form] or Skills.offence[fighter.offenceId]
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
local api = { event = event, clamp = clamp, direction = direction,
	IMPACT_PROTECTION = BattleSimulation.IMPACT_PROTECTION }

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
		pressure = 0, regulationTime = BattleSimulation.REGULATION_TIME, maxTime = BattleSimulation.MAX_TIME, _accumulator = 0, _projectileSerial = 0, _bumpCooldown = 0,
		_wakeSerial = 0, spin = seed % 2 == 0 and 1 or -1,
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
			_approachOffset = ((seed * 48271 + (seed % 2 == 0 and id or 3 - id) * 1299709) % 2147483647) / 2147483647 * 2.4 - 1.2,
			x = -52 * side, y = 31 + random() * 13,
			heading = heading, vx = math.cos(heading) * 29, vy = math.sin(heading) * 29,
			armor = 3, maxArmor = 3, scale = 1, speedScale = 1, shotScale = 1, squad = 0, phase = "Approach", phaseLeft = (Skills.offence[config.offenceId].approachTime or BattleSimulation.APPROACH_TIME) +
				(configs[1].offenceId == "Meteor" and configs[2].offenceId == "Meteor" and id == seed % 2 + 1 and (0.25 + (seed * 69621 % 9999) / 9999 * 0.35) or 0),
			windupDuration = Skills.offence[config.offenceId].windup,
			armed = false, invulnerable = 0, attacks = 0, hits = 0,
			radius = BattleSimulation.PLANE_RADIUS, lockX = 0, lockY = 50,
			_knockX = 0, _knockY = 0, _attackHit = false,
		}
		-- The opening pass gets the same seeded timing spread as every later one,
		-- so the same attack does not always strike first.
		-- One extra step of the cadence separates the two planes' timing.
		fighter.phaseLeft = fighter.phaseLeft + (fighter._cadence * 16807) % 2147483647 / 2147483647 * 2.4 - 1.2
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
	fighter._approachOffset = fighter._cadence / 2147483647 * 2.4 - 1.2
	-- Both planes circle the same way round, or they would meet head-on.
	state.spin = fighter._cadence % 2 == 0 and 1 or -1
	fighter.phase, fighter.phaseLeft = "Recover", ((duration or offenceOf(fighter).recoveryTime or BattleSimulation.RECOVERY_TIME) + (fighter._bumperRecovery or 0)) * (fighter.secondWind and 0.88 or 1) * (fighter.tempo or 1)
	fighter._bumperRecovery = nil
	fighter.armed = false
	local awayX, awayY = direction(fighter.x - opponent.x, fighter.y - opponent.y, fighter.id == 1 and -1 or 1)
	fighter._recoverX = clamp(fighter.x + awayX * 32, -48, 48)
	-- The higher plane banks up and the lower one down, so two planes turning
	-- away at once open a gap instead of meeting again in the middle.
	local above = fighter.y > opponent.y or (fighter.y == opponent.y and fighter.id == 1)
	fighter._recoverY = clamp(fighter.y + awayY * 15 + (above and 18 or -18), 25, 77)
end

local function lockTarget(fighter, opponent)
	local distance = math.sqrt((opponent.x - fighter.x) ^ 2 + (opponent.y - fighter.y) ^ 2)
	local offence = offenceOf(fighter)
	local lead = clamp(distance / offence.leadSpeed, 0, 0.95) * offence.leadFactor
	fighter.lockX = clamp(opponent.x + opponent.vx * lead, -64, 64)
	fighter.lockY = clamp(opponent.y + opponent.vy * lead, 15, 88)
end

local function beginAttack(state, fighter, opponent)
	local offence = offenceOf(fighter)
	lockTarget(fighter, opponent)
	fighter.phase = "Attack"
	fighter.phaseLeft = offence.attackTime
	fighter.armed = offence.ram ~= nil
	fighter.attacks = fighter.attacks + 1
	fighter._attackHit = false
	wild(fighter, "attack", state, fighter, opponent)
	-- The direction is locked for the whole attack; no homing after launch.
	fighter._attackHeading = fighter.heading
	if offence.attack then offence.attack(api, state, fighter, opponent) end
end

local function prepare(state, fighter, opponent, dt)
	local offence = offenceOf(fighter)
	fighter.invulnerable = math.max(0, fighter.invulnerable - dt)
	fighter.boostLeft = math.max(0, fighter.boostLeft - dt)
	if fighter.magnetLeft then fighter.magnetLeft = math.max(0, fighter.magnetLeft - dt) end
	fighter.phaseLeft = fighter.phaseLeft - dt
	if (fighter.chickenLeft or 0) > 0 then
		-- A chicken cannot attack: it flaps in circles until the spell ends.
		fighter.chickenLeft = math.max(0, fighter.chickenLeft - dt)
		fighter.phase, fighter.armed = "Approach", false
		fighter.phaseLeft = math.max(fighter.phaseLeft, offence.approachTime or BattleSimulation.APPROACH_TIME)
	end
	local dx, dy = opponent.x - fighter.x, opponent.y - fighter.y
	if fighter.phase == "Approach" then
		local inPosition = offence.inPosition ~= nil and offence.inPosition(api, state, fighter, opponent, dx, dy)
		if fighter.phaseLeft <= 0 or (fighter.phaseLeft < offence.earliest and inPosition) then
			fighter.phase, fighter.phaseLeft = "Windup", fighter.windupDuration
			-- A skill's hurry lasts for one trip back to the attack.
			fighter.tempo = nil
			if offence.windupStart then offence.windupStart(api, state, fighter, opponent) end
			lockTarget(fighter, opponent)
			event(state, "windup", fighter.x, fighter.y, fighter.id, opponent.id)
		end
	elseif fighter.phase == "Windup" and fighter.phaseLeft <= 0 then
		beginAttack(state, fighter, opponent)
	elseif fighter.phase == "Attack" and fighter.phaseLeft <= 0 then
		if offence.ram and not fighter._attackHit then
			event(state, "miss", fighter.x, fighter.y, fighter.id, opponent.id)
		end
		recover(state, fighter, opponent)
	elseif fighter.phase == "Recover" and fighter.phaseLeft <= 0 then
		fighter.phase, fighter.phaseLeft = "Approach", ((offence.approachTime or BattleSimulation.APPROACH_TIME) + fighter._approachOffset) * (fighter.tempo or 1)
	end

	local targetX, targetY = opponent.x, opponent.y
	local speed, turnRate = 28, 2.8
	local wantX, wantY, wantSpeed, wantTurn
	if fighter.phase == "Approach" then
		fighter.circling = fighter.phaseLeft >= offence.earliest
		if fighter.circling then
			-- Aim for a point on the standoff ring a little way round from here.
			local awayX, awayY = direction(-dx, -dy, fighter.id == 1 and -1 or 1)
			local c, s = math.cos(BattleSimulation.ORBIT_LEAD), math.sin(BattleSimulation.ORBIT_LEAD) * state.spin
			targetX = clamp(opponent.x + (awayX * c - awayY * s) * BattleSimulation.STANDOFF, state.bounds.left + 6, state.bounds.right - 6)
			targetY = clamp(opponent.y + (awayX * s + awayY * c) * BattleSimulation.STANDOFF, state.bounds.bottom + 6, state.bounds.top - 6)
			speed, turnRate = BattleSimulation.ORBIT_SPEED, 3.4
		end
		if offence.approach then
			wantX, wantY, wantSpeed, wantTurn = offence.approach(api, state, fighter, opponent, dx, dy)
		end
	elseif fighter.phase == "Windup" then
		lockTarget(fighter, opponent)
		targetX, targetY = fighter.lockX, fighter.lockY
		speed, turnRate = 9, 5.5
		if offence.windupMove then
			wantX, wantY, wantSpeed, wantTurn = offence.windupMove(api, state, fighter, opponent)
		end
	elseif fighter.phase == "Attack" then
		speed = offence.attackSpeed
		fighter.heading = fighter._attackHeading
		if offence.attackTick then offence.attackTick(api, state, fighter, dt) end
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
	if fighter.secondWind then speed, turnRate = speed * 1.12, turnRate * 1.2 end
	speed = speed * (fighter.speedScale or 1)
	turnRate = math.min(turnRate, BattleSimulation.MAX_TURN_RATE)
	if fighter.phase ~= "Attack" then
		-- Looking ahead turns the plane away from the visible edge before impact.
		local lookX = fighter.x + math.cos(fighter.heading) * speed * 0.45
		local lookY = fighter.y + math.sin(fighter.heading) * speed * 0.45
		if fighter.phase ~= "Windup" and (lookX < state.bounds.left + 3 or lookX > state.bounds.right - 3 or
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
local function damage(state, actorId, targetId, x, y, dirX, dirY, source, skillId)
	local actor, target = state.fighters[actorId], state.fighters[targetId]
	if target.invulnerable > 0 or target.armor <= 0 then return false end
	for _, id in ipairs(target.wildIds) do
		local handler = Skills.wild[id]
		if handler and handler.hit and handler.hit(api, state, target, actor, x, y, dirX, dirY, source) then
			actor._attackHit = true
			return false, true
		end
	end
	target.armor = math.max(0, target.armor - 1)
	target.invulnerable = BattleSimulation.IMPACT_PROTECTION
	-- A hit should throw the plane, not nudge it.
	target._knockX, target._knockY = dirX * BattleSimulation.HIT_KNOCK, dirY * BattleSimulation.HIT_KNOCK
	actor.hits = actor.hits + 1
	actor._attackHit = true
	event(state, source == "wake" and "wake_hit" or "hit", x, y, actorId, targetId, source, skillId)
	wild(target, "damaged", state, target, actor)
	wild(actor, "landed", state, actor, target)
	return true
end

local function tick(state)
	local dt = math.min(BattleSimulation.FIXED_DT, BattleSimulation.MAX_TIME - state.elapsed)
	state.elapsed = math.min(BattleSimulation.MAX_TIME, state.elapsed + dt)
	updateBounds(state)
	state._bumpCooldown = math.max(0, state._bumpCooldown - dt)
	local previous = {}
	for id, fighter in ipairs(state.fighters) do
		previous[id] = { id = id, x = fighter.x, y = fighter.y, vx = fighter.vx, vy = fighter.vy, heading = fighter.heading }
	end
	-- Both plans read the same pre-tick snapshot, avoiding first-player bias.
	for id, fighter in ipairs(state.fighters) do prepare(state, fighter, previous[3 - id], dt) end
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
		local magnitude = math.sqrt(fighter.vx ^ 2 + fighter.vy ^ 2)
		if magnitude > BattleSimulation.MAX_TOTAL_SPEED then
			fighter.vx, fighter.vy = fighter.vx * BattleSimulation.MAX_TOTAL_SPEED / magnitude, fighter.vy * BattleSimulation.MAX_TOTAL_SPEED / magnitude
		end
	end
	local edgeHit = {}
	for id, fighter in ipairs(state.fighters) do
		local x, y = fighter.x + fighter.vx * dt, fighter.y + fighter.vy * dt
		fighter.x = clamp(x, state.bounds.left, state.bounds.right)
		fighter.y = clamp(y, state.bounds.bottom, state.bounds.top)
		edgeHit[id] = x ~= fighter.x or y ~= fighter.y
		wild(fighter, "moved", state, fighter, dt)
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
					math.cos(fighter.heading), math.sin(fighter.heading), offenceOf(fighter).ram)
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

	local surviving = {}
	for _, projectile in ipairs(state.projectiles) do
		local oldX, oldY = projectile.x, projectile.y
		projectile.x, projectile.y = oldX + projectile.vx * dt, oldY + projectile.vy * dt
		projectile.life = projectile.life - dt
		local targetId = 3 - projectile.owner
		local target, old = state.fighters[targetId], previous[targetId]
		local hit = strike(oldX, oldY, projectile.x, projectile.y, targetId, projectile.radius or 3.5)
		if hit then
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
					oldX + (projectile.x - oldX) * hit, oldY + (projectile.y - oldY) * hit, nx, ny, projectile.source or "rocket")
			end
			if successful then landed[projectile.owner] = true end
			if successful or absorbed then resolved[projectile.owner] = true end
			-- Impact protection absorbs subsequent projectiles visibly at contact;
			-- they never wait inside a protected plane to deal delayed damage.
			if not successful and not absorbed then event(state, "miss", projectile.x, projectile.y, projectile.owner, targetId) end
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
		if resolved[id] or resolved[3 - id] then
			recover(state, fighter, state.fighters[3 - id])
		elseif edgeHit[id] and fighter.phase == "Attack" then
			if offenceOf(fighter).ram and not fighter._attackHit then
				event(state, "miss", fighter.x, fighter.y, id, 3 - id)
			end
			recover(state, fighter, state.fighters[3 - id])
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
