-- Pure, deterministic ring-out simulation. No Roblox services or physics.
-- Two spinning tops share a round platform in the sky. They bump each other
-- about and the first one whose centre leaves the platform loses the round.
-- There is no health: where a top stands is how much trouble it is in.
--
-- step accepts elapsed time and consumes fixed ticks; a stalled caller advances
-- at most MAX_STEP_DT per call. Rendering reads state but never decides a hit.
-- What each top and upgrade is made of lives in BattleSkills.
local Skills = require(script.Parent.BattleSkills)
local BattleSimulation = {}

BattleSimulation.CONTRACT_VERSION = "sky-battle-ring-v1"
BattleSimulation.FIXED_DT = 1 / 60
BattleSimulation.MAX_STEP_DT = 0.25
BattleSimulation.MAX_WILD = 2
-- The platform is a disc centred on the origin. After SHRINK_START it closes
-- in steadily, reaching RING_END at MAX_TIME, so every round has to end.
BattleSimulation.RING_RADIUS = 40
BattleSimulation.RING_END = 8
BattleSimulation.SHRINK_START = 8
BattleSimulation.MAX_TIME = 26
BattleSimulation.START_DISTANCE = 18
-- A touch always throws both tops apart: an ordinary bounce plus each top's
-- kick. Kicks grow once the round has run HEAT_START seconds.
BattleSimulation.RESTITUTION = 0
BattleSimulation.KICK = 10
-- A top driving into a touch at this speed kicks twice as hard as one standing still.
BattleSimulation.KICK_SPEED = 25
-- How far luck can tip one touch either way.
BattleSimulation.LUCK = 0.5
BattleSimulation.HEAT_START = 6
BattleSimulation.HEAT_RATE = 0.06
-- A top that was just thrown cannot steer for a moment.
BattleSimulation.STUN = 0.34
BattleSimulation.CLASH_COOLDOWN = 0.12
-- A free top leans toward its rival and spins itself back up to its cruise
-- speed; how fast it can turn and how fast it cruises are its own. The
-- platform is dished, pulling this hard toward the middle at the edge.
BattleSimulation.BOWL = 26
BattleSimulation.CRUISE_GRIP = 2
BattleSimulation.STUN_DRAG = 0.5
-- A top that comes this close to the edge and gets back had a close call.
BattleSimulation.CLOSE_MARGIN = 3
BattleSimulation.CLOSE_CLEAR = 8
BattleSimulation.AIM_LOCK = 0.28
BattleSimulation.WINDUP_BRAKE = 6
BattleSimulation.RECOVER_BRAKE = 4.5
BattleSimulation.CLAW_ZONE = 0.6
BattleSimulation.CLAW_BRAKE = 1.2
BattleSimulation.BUMPER_RETURN = 2.6
BattleSimulation.JET_TIME = 0.9
BattleSimulation.JET_HEIGHT = 14
BattleSimulation.JET_LANDING = 0.72

local PI = math.pi
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
	local difference = (target - heading + PI) % (2 * PI) - PI
	return (heading + clamp(difference, -amount, amount) + PI) % (2 * PI) - PI
end
local function direction(x, y, fallbackX, fallbackY)
	local length = math.sqrt(x * x + y * y)
	if length < EPSILON then return fallbackX or 1, fallbackY or 0 end
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
-- Upgrades are sorted so the order they were picked in never changes a fight.
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
	return { offenceId = BattleSimulation.validOffence(input.offenceId) and input.offenceId or fallback, wildIds = wildIds }
end

local function roll(state)
	state._random = (state._random * 16807) % 2147483647
	return (state._random - 1) / 2147483646
end

local function event(state, kind, x, y, actor, target)
	state.eventSerial = state.eventSerial + 1
	local entry = { serial = state.eventSerial, kind = kind, x = x, y = y,
		actor = actor or 0, target = target or 0, at = state.elapsed }
	state.events[#state.events + 1] = entry
	if #state.events > 24 then table.remove(state.events, 1) end
	return entry
end

local function finish(state, reason, winner)
	state.finished = true
	state.reason = reason
	state.winner = winner
	local a, b = state.fighters[1], state.fighters[2]
	event(state, "finish", (a.x + b.x) / 2, (a.y + b.y) / 2, winner, 0)
end

local function updateRing(state)
	local pressure = clamp((state.elapsed - BattleSimulation.SHRINK_START)
		/ (BattleSimulation.MAX_TIME - BattleSimulation.SHRINK_START), 0, 1)
	state.pressure = pressure
	state.ring = BattleSimulation.RING_RADIUS - (BattleSimulation.RING_RADIUS - BattleSimulation.RING_END) * pressure
	state.heat = 1 + math.max(0, state.elapsed - BattleSimulation.HEAT_START) * BattleSimulation.HEAT_RATE
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
		fighters = {}, events = {}, eventSerial = 0, maxTime = BattleSimulation.MAX_TIME,
		shrinkStart = BattleSimulation.SHRINK_START, _accumulator = 0, _clashCool = 0,
		_random = (seed * 48271) % 2147483647,
	}
	updateRing(state)
	local spin = seed % 2 == 0 and 1 or -1
	local configs = { settings(settingsA, "Boulder"), settings(settingsB, "Bolt") }
	for id, config in ipairs(configs) do
		local side = id == 1 and -1 or 1
		local spec = Skills.offence[config.offenceId]
		local top = {
			id = id, offenceId = config.offenceId, settings = config, wildIds = config.wildIds,
			x = side * BattleSimulation.START_DISTANCE, y = (random() * 2 - 1) * 9, z = 0,
			vx = 0, vy = 0, heading = 0,
			mass = spec.mass, radius = spec.radius, cruise = spec.cruise, turn = spec.turn, kick = spec.kick,
			move = spec.move, tempo = 1,
			phase = "Roam", phaseLeft = 0, moveLeft = 0, moveEvery = 0, stun = 0, lockX = 0, lockY = 0,
			hits = 0, closeCalls = 0, edge = 0, out = false,
			claws = false, bumperReady = false, jetReady = false,
		}
		for _, wildId in ipairs(config.wildIds) do
			local wild = Skills.wild[wildId]
			top.mass = top.mass * (wild.mass or 1)
			top.radius = top.radius * (wild.radius or 1)
			top.cruise = top.cruise * (wild.cruise or 1)
			top.kick = top.kick * (wild.kick or 1)
			top.tempo = top.tempo * (wild.tempo or 1)
			if wild.claws then top.claws = true end
			if wild.bumper then top.bumperReady = true end
			if wild.jetpack then top.jetReady = true end
		end
		if top.move then
			top.moveEvery = top.move.every * top.tempo
			-- The seed decides who makes the first move, never how hard it lands.
			top.moveLeft = top.moveEvery * (0.7 + random() * 0.6)
		end
		-- Both tops are launched across the ring, not straight at each other.
		-- The seed sets the exact angle.
		top.heading = (side < 0 and 0 or PI) + spin * (0.4 + random() * 0.8)
		top.vx, top.vy = math.cos(top.heading) * top.cruise, math.sin(top.heading) * top.cruise
		state.fighters[id] = top
		event(state, "launch", top.x, top.y, id, 0)
	end
	return state
end

local function endAttack(top)
	local recover = top.move and top.move.recover or 0
	top.phase, top.phaseLeft = recover > 0 and "Recover" or "Roam", recover
	top.moveLeft = top.moveEvery
end

-- A thrown top that was charging keeps its charge and fires once it has
-- steadied; one caught mid-move has that move cut short.
local function interrupt(top)
	if top.phase == "Attack" then endAttack(top) end
end

-- Throws `target` along (nx, ny) with `impulse`, unless its bumper is still
-- loaded: then the target stays put and `source` takes the throw instead.
-- Returns the speed the target gained, then the speed the source was thrown back.
local function throw(state, source, target, nx, ny, impulse)
	if target.bumperReady then
		target.bumperReady = false
		local back = impulse * BattleSimulation.BUMPER_RETURN / source.mass
		source.vx, source.vy = source.vx - nx * back, source.vy - ny * back
		source.stun = math.max(source.stun, BattleSimulation.STUN)
		interrupt(source)
		event(state, "blocked", target.x, target.y, target.id, source.id).skillId = "Bumper"
		return 0, back
	end
	local gained = impulse / target.mass
	target.vx, target.vy = target.vx + nx * gained, target.vy + ny * gained
	target.stun = math.max(target.stun, BattleSimulation.STUN * clamp(gained / 35, 0.4, 1.6))
	interrupt(target)
	return gained, 0
end

local function land(state, top, rival)
	top.z, top.vx, top.vy, top.flying = 0, 0, 0, nil
	if top._jet then
		top._jet = nil
		top.phase, top.phaseLeft = "Roam", 0
		event(state, "land", top.x, top.y, top.id, 0)
		return
	end
	local move = top.move
	top.phase, top.phaseLeft = "Recover", move.recover
	top.moveLeft = top.moveEvery
	local slam = event(state, "slam", top.x, top.y, top.id, 0)
	slam.radius = move.reach
	if rival.out or rival.phase == "Air" then return end
	local dx, dy = rival.x - top.x, rival.y - top.y
	local distance = math.sqrt(dx * dx + dy * dy)
	local reach = move.reach + rival.radius
	if distance >= reach then return end
	-- A rival directly underneath is thrown the way it was already leaning.
	local nx, ny = direction(dx, dy, rival.x, rival.y)
	local impulse = BattleSimulation.KICK * state.heat * top.kick * move.kick * (1 - 0.55 * distance / reach)
	local gained = throw(state, top, rival, nx, ny, impulse)
	if gained > 0 then
		top.hits = top.hits + 1
		local hit = event(state, "clash", rival.x, rival.y, top.id, rival.id)
		hit.power, hit.source, hit.skillId = gained, "slam", top.offenceId
	end
end

local function beginAttack(state, top, rival)
	local move = top.move
	top.phase, top.phaseLeft = "Attack", move.time
	local started = event(state, "attack", top.x, top.y, top.id, rival.id)
	started.source, started.skillId = move.kind, top.offenceId
	if move.kind == "dash" then
		top._dashX, top._dashY = direction(top.lockX - top.x, top.lockY - top.y, rival.x - top.x, rival.y - top.y)
		top.heading = atan2(top._dashY, top._dashX)
	elseif move.kind == "jump" then
		top.phase, top.flying = "Air", "jump"
		top._fromX, top._fromY, top._airTime, top._airHeight = top.x, top.y, move.time, move.height
	end
end

local function aim(state, top, rival, lead)
	local x, y = rival.x + rival.vx * lead, rival.y + rival.vy * lead
	-- Never aim past the edge: a jump always lands on the platform.
	local distance = math.sqrt(x * x + y * y)
	local limit = math.max(0, state.ring - top.radius - 1)
	if distance > limit and distance > EPSILON then x, y = x / distance * limit, y / distance * limit end
	top.lockX, top.lockY = x, y
end

local function advance(state, top, rival, dt)
	top.stun = math.max(0, top.stun - dt)
	if top.phase == "Air" then
		top.phaseLeft = top.phaseLeft - dt
		local progress = clamp(1 - top.phaseLeft / top._airTime, 0, 1)
		local x = top._fromX + (top.lockX - top._fromX) * progress
		local y = top._fromY + (top.lockY - top._fromY) * progress
		top.vx, top.vy = (x - top.x) / dt, (y - top.y) / dt
		top.x, top.y = x, y
		top.z = math.sin(PI * progress) * top._airHeight
		if top.phaseLeft <= EPSILON then land(state, top, rival) end
		return
	end
	local move = top.move
	-- The platform is dished: the nearer the edge, the harder it leans a top
	-- back toward the middle.
	local lean = BattleSimulation.BOWL / math.max(state.ring, 1)
	local ax, ay = -top.x * lean, -top.y * lean
	-- What the top's own spin is trying to do: a speed, and how hard it grips.
	local wanted, grip, turning = top.cruise, BattleSimulation.CRUISE_GRIP, top.turn
	local drag = 0
	if top.phase == "Windup" then
		wanted, grip, turning = 0, BattleSimulation.WINDUP_BRAKE, 0
		if top.stun <= 0 then
			top.phaseLeft = top.phaseLeft - dt
			if top.phaseLeft > BattleSimulation.AIM_LOCK then aim(state, top, rival, move.kind == "jump" and 0.3 or 0.12) end
			if top.phaseLeft <= EPSILON then beginAttack(state, top, rival) end
		else
			grip, drag = 0, BattleSimulation.STUN_DRAG
		end
	elseif top.phase == "Attack" then
		top.phaseLeft = top.phaseLeft - dt
		if move.kind == "dash" then
			top.vx, top.vy, ax, ay, grip, turning = top._dashX * move.speed, top._dashY * move.speed, 0, 0, 0, 0
		else
			wanted, turning = top.cruise * move.speed, top.turn * move.turn
		end
		if top.phaseLeft <= EPSILON then endAttack(top) end
	elseif top.phase == "Recover" then
		top.phaseLeft = top.phaseLeft - dt
		grip, turning, drag = 0, 0, BattleSimulation.RECOVER_BRAKE
		if top.phaseLeft <= EPSILON then top.phase, top.phaseLeft = "Roam", 0 end
	elseif top.stun > 0 then
		grip, turning, drag = 0, 0, BattleSimulation.STUN_DRAG
	elseif move and not rival.out then
		top.moveLeft = top.moveLeft - dt
		if top.moveLeft <= EPSILON then
			aim(state, top, rival, 0)
			if move.windup > 0 then
				top.phase, top.phaseLeft = "Windup", move.windup
				local charging = event(state, "windup", top.x, top.y, top.id, rival.id)
				charging.source, charging.skillId = move.kind, top.offenceId
			else
				beginAttack(state, top, rival)
			end
		end
	end
	if turning > 0 then
		-- Every top leans toward its rival, or toward the middle with nobody to chase.
		local chaseX, chaseY = rival.x - top.x, rival.y - top.y
		if rival.out or rival.phase == "Air" then chaseX, chaseY = -top.x, -top.y end
		if chaseX * chaseX + chaseY * chaseY > EPSILON then
			top.heading = turn(top.heading, atan2(chaseY, chaseX), turning * dt)
		end
	end
	top.vx, top.vy = top.vx + ax * dt, top.vy + ay * dt
	if grip > 0 then
		local hold = 1 - math.exp(-grip * dt)
		top.vx = top.vx + (math.cos(top.heading) * wanted - top.vx) * hold
		top.vy = top.vy + (math.sin(top.heading) * wanted - top.vy) * hold
	end
	if drag > 0 then
		local keep = math.exp(-drag * dt)
		top.vx, top.vy = top.vx * keep, top.vy * keep
	end
	local distance = math.sqrt(top.x * top.x + top.y * top.y)
	top.clawing = false
	if top.claws and distance > BattleSimulation.CLAW_ZONE * state.ring and top.phase ~= "Attack" then
		local outward = (top.vx * top.x + top.vy * top.y) / distance
		if outward > 0 then
			local shed = outward * (1 - math.exp(-BattleSimulation.CLAW_BRAKE * dt))
			top.vx, top.vy = top.vx - top.x / distance * shed, top.vy - top.y / distance * shed
			top.clawing = outward > 8
		end
	end
	top.x, top.y = top.x + top.vx * dt, top.y + top.vy * dt
end

local function collide(state, a, b)
	state._clashCool = math.max(0, state._clashCool - BattleSimulation.FIXED_DT)
	if a.out or b.out or a.phase == "Air" or b.phase == "Air" then return end
	local dx, dy = b.x - a.x, b.y - a.y
	local distance = math.sqrt(dx * dx + dy * dy)
	local reach = a.radius + b.radius
	if distance >= reach then return end
	local nx, ny = direction(dx, dy, 1, 0)
	local total = a.mass + b.mass
	local overlap = reach - distance
	a.x, a.y = a.x - nx * overlap * b.mass / total, a.y - ny * overlap * b.mass / total
	b.x, b.y = b.x + nx * overlap * a.mass / total, b.y + ny * overlap * a.mass / total
	local closing = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny
	if closing >= 0 or state._clashCool > 0 then return end
	state._clashCool = BattleSimulation.CLASH_COOLDOWN
	local bounce = -(1 + BattleSimulation.RESTITUTION) * closing / (1 / a.mass + 1 / b.mass)
	-- The faster a top is driving into the touch, the harder it kicks. A seeded
	-- share of luck decides which of the two catches the other cleanly.
	local luck = (roll(state) * 2 - 1) * BattleSimulation.LUCK
	local intoA = math.max(0, a.vx * nx + a.vy * ny) / BattleSimulation.KICK_SPEED
	local intoB = math.max(0, -(b.vx * nx + b.vy * ny)) / BattleSimulation.KICK_SPEED
	local kickA = BattleSimulation.KICK * state.heat * a.kick * (1 + intoA) * (1 + luck)
	local kickB = BattleSimulation.KICK * state.heat * b.kick * (1 + intoB) * (1 - luck)
	local x, y = a.x + nx * a.radius, a.y + ny * a.radius
	if a.bumperReady and b.bumperReady then
		-- Two bumpers meeting spend each other and the touch plays out as normal.
		a.bumperReady, b.bumperReady = false, false
	end
	local gainedA, gainedB
	if a.bumperReady then
		gainedA, gainedB = throw(state, b, a, -nx, -ny, bounce + kickB)
	elseif b.bumperReady then
		gainedB, gainedA = throw(state, a, b, nx, ny, bounce + kickA)
	else
		gainedB = throw(state, a, b, nx, ny, bounce + kickA)
		gainedA = throw(state, b, a, -nx, -ny, bounce + kickB)
	end
	-- Whoever is flung away faster took the hit; the other held its ground.
	local awayA, awayB = -(a.vx * nx + a.vy * ny), b.vx * nx + b.vy * ny
	local winner, loser = a, b
	if awayA > awayB then winner, loser = b, a end
	winner.hits = winner.hits + 1
	local hit = event(state, "clash", x, y, winner.id, loser.id)
	hit.power, hit.source, hit.skillId = math.max(awayA, awayB, 0), "bump", winner.offenceId
	hit.even = math.abs(awayA - awayB) < 5
	if gainedA == 0 or gainedB == 0 then hit.blocked = true end
end

local function jet(state, top)
	local distance = math.sqrt(top.x * top.x + top.y * top.y)
	top.jetReady = false
	top.phase, top.phaseLeft, top._jet, top.flying = "Air", BattleSimulation.JET_TIME, true, "jet"
	top._fromX, top._fromY, top._airTime, top._airHeight = top.x, top.y, BattleSimulation.JET_TIME, BattleSimulation.JET_HEIGHT
	local landing = state.ring * BattleSimulation.JET_LANDING
	top.lockX, top.lockY = top.x / distance * landing, top.y / distance * landing
	top.stun, top._near = 0, false
	event(state, "revive", top.x, top.y, top.id, 0).skillId = "Jetpack"
end

local function edges(state)
	local fallen = {}
	for _, top in ipairs(state.fighters) do
		if not top.out and top.phase ~= "Air" then
			local distance = math.sqrt(top.x * top.x + top.y * top.y)
			top.edge = distance / math.max(state.ring, EPSILON)
			if distance > state.ring then
				if top.jetReady then
					jet(state, top)
				else
					top.out, top.phase, top.phaseLeft = true, "Out", 0
					fallen[#fallen + 1] = top
				end
			elseif distance > state.ring - BattleSimulation.CLOSE_MARGIN then
				top._near = true
			elseif top._near and distance < state.ring - BattleSimulation.CLOSE_CLEAR then
				top._near = false
				top.closeCalls = top.closeCalls + 1
				event(state, "close", top.x, top.y, top.id, 0)
			end
		end
	end
	if #fallen == 0 then return end
	for _, top in ipairs(fallen) do
		event(state, "ringout", top.x, top.y, #fallen == 1 and 3 - top.id or 0, top.id)
	end
	finish(state, "ringout", #fallen == 1 and 3 - fallen[1].id or 0)
end

-- Ends a round that is still going: the top nearer the middle takes it.
function BattleSimulation.expire(state)
	if state.finished then return state end
	local a, b = state.fighters[1], state.fighters[2]
	local da, db = a.x * a.x + a.y * a.y, b.x * b.x + b.y * b.y
	finish(state, "timeout", math.abs(da - db) < 0.0001 and 0 or (da < db and 1 or 2))
	return state
end

local function tick(state)
	local dt = BattleSimulation.FIXED_DT
	state.elapsed = state.elapsed + dt
	updateRing(state)
	local a, b = state.fighters[1], state.fighters[2]
	if not a.out then advance(state, a, b, dt) end
	if not b.out then advance(state, b, a, dt) end
	collide(state, a, b)
	edges(state)
	if not state.finished and state.elapsed >= BattleSimulation.MAX_TIME - EPSILON then
		BattleSimulation.expire(state)
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
