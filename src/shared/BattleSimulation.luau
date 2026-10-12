-- Pure, deterministic spinning-top battle. No Roblox services or physics.
-- Two tops are launched into a walled bowl. Nobody steers: each top goes
-- where its tip and the slope of the bowl take it. A round is lost by being
-- knocked out through one of the gaps in the wall, or by running out of spin.
--
-- step accepts elapsed time and consumes fixed ticks; a stalled caller advances
-- at most MAX_STEP_DT per call. Rendering reads state but never decides a hit.
-- What each top and part is made of lives in BattleSkills.
local Skills = require(script.Parent.BattleSkills)
local BattleSimulation = {}

BattleSimulation.CONTRACT_VERSION = "sky-battle-ring-v2"
BattleSimulation.FIXED_DT = 1 / 60
BattleSimulation.MAX_STEP_DT = 0.25
BattleSimulation.MAX_WILD = 2
-- The bowl is a disc centred on the origin with a wall round its rim. The
-- wall has three gaps, placed so that neither seat is nearer to one. GAPS are
-- the angles of their middles; GAP_HALF is half the angle each one spans.
BattleSimulation.RING_RADIUS = 24
BattleSimulation.GAPS = { math.pi / 2, math.pi * 7 / 6, math.pi * 11 / 6 }
BattleSimulation.GAP_HALF = 0.2
-- A top moving this much faster than its own cruise speed has been thrown.
BattleSimulation.THROWN = 2
BattleSimulation.START_DISTANCE = 12
-- A round that somehow outlasts both tops' spin budget goes to whichever has
-- more spin left.
BattleSimulation.MAX_TIME = 40
-- Every top starts with this much spin; a part may add to it.
BattleSimulation.SPIN = 100
-- A slowing top wobbles, and a wobbling top loses spin faster still.
BattleSimulation.WOBBLE_DECAY = 1.2
-- A top with no spin left still crawls at this share of its cruise speed.
BattleSimulation.IDLE_CRUISE = 0.3
-- The bowl pulls a top toward the middle this hard at the rim.
BattleSimulation.BOWL = 80
-- A touch: an ordinary bounce, plus recoil from the two spinning rims
-- catching each other. Rims turning the same way meet head-on and smash;
-- rims turning opposite ways roll together and only grind.
BattleSimulation.RESTITUTION = 0.35
BattleSimulation.RECOIL = 1.5
-- Rims also throw each other sideways, so no two hits go the same way.
BattleSimulation.UNSTEADY = 1.6
BattleSimulation.SIDE_KICK = 1.3
-- How far luck can tip one touch either way.
BattleSimulation.LUCK = 0.35
BattleSimulation.CLASH_COOLDOWN = 0.1
-- Spin a touch costs, per unit of recoil taken.
BattleSimulation.HIT_COST = 0.06
-- Opposite spins even out: this share of the gap moves from the faster top
-- to the slower one on every touch, and a little is lost on the way.
BattleSimulation.EQUALIZE = 0.16
BattleSimulation.EQUALIZE_KEEP = 0.8
-- Bouncing off the wall keeps this much speed and costs a little spin.
BattleSimulation.WALL_BOUNCE = 0.55
BattleSimulation.WALL_COST = 0.05
-- Hitting the wall this close to a gap, this hard, was a close call.
BattleSimulation.CLOSE_ANGLE = 0.16
BattleSimulation.CLOSE_SPEED = 16

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
-- Parts are sorted so the order they were picked in never changes a fight.
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

-- True when a top at this angle on the rim is in front of a gap.
function BattleSimulation.gapAt(angle, margin)
	for _, middle in ipairs(BattleSimulation.GAPS) do
		local off = math.abs((angle - middle + PI) % (2 * PI) - PI)
		if off < BattleSimulation.GAP_HALF + (margin or 0) then return true end
	end
	return false
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
		ring = BattleSimulation.RING_RADIUS, _accumulator = 0, _clashCool = 0,
		_random = (seed * 48271) % 2147483647,
	}
	local swing = seed % 2 == 0 and 1 or -1
	local configs = { settings(settingsA, "Bolt"), settings(settingsB, "Cyclone") }
	for id, config in ipairs(configs) do
		local side = id == 1 and -1 or 1
		local spec = Skills.offence[config.offenceId]
		local top = {
			id = id, offenceId = config.offenceId, settings = config, wildIds = config.wildIds,
			x = side * BattleSimulation.START_DISTANCE, y = (random() * 2 - 1) * 6,
			vx = 0, vy = 0, heading = 0,
			mass = spec.mass, radius = spec.radius, cruise = spec.cruise, grip = spec.grip, brake = spec.brake,
			curl = spec.curl, dive = spec.dive, decay = spec.decay, bite = spec.bite, guard = spec.guard, rail = spec.rail,
			-- 1 turns the usual way, -1 the other.
			turn = 1, spinMax = BattleSimulation.SPIN, spin = BattleSimulation.SPIN,
			hits = 0, wallHits = 0, closeCalls = 0, edge = 0, out = false, down = false,
		}
		for _, wildId in ipairs(config.wildIds) do
			local wild = Skills.wild[wildId]
			top.mass = top.mass * (wild.mass or 1)
			top.cruise = top.cruise * (wild.cruise or 1)
			top.grip = top.grip * (wild.grip or 1)
			top.brake = top.brake * (wild.brake or 1)
			top.decay = top.decay * (wild.decay or 1)
			top.bite = top.bite * (wild.bite or 1)
			top.guard = top.guard * (wild.guard or 1)
			top.spinMax = top.spinMax * (wild.spin or 1)
			if wild.left then top.turn = -1 end
		end
		top.spin = top.spinMax
		-- Launched across the bowl, not straight at the rival. The seed sets
		-- the exact angle and never how hard anything hits.
		top.heading = (side < 0 and 0 or PI) + swing * (0.5 + random() * 0.9)
		local launch = math.max(top.cruise, 14)
		top.vx, top.vy = math.cos(top.heading) * launch, math.sin(top.heading) * launch
		state.fighters[id] = top
		event(state, "launch", top.x, top.y, id, 0)
	end
	return state
end

local function advance(top, dt)
	local share = clamp(top.spin / top.spinMax, 0, 1)
	-- The bowl leans every top toward the middle, harder the further out it is.
	local lean = BattleSimulation.BOWL / BattleSimulation.RING_RADIUS
	top.vx, top.vy = top.vx - top.x * lean * dt, top.vy - top.y * lean * dt
	local speed = math.sqrt(top.vx * top.vx + top.vy * top.vy)
	local headX, headY = direction(top.vx, top.vy, math.cos(top.heading), math.sin(top.heading))
	-- The tip: it bends the path, drives the top up to its cruising speed, and
	-- scrubs off anything a hit added. All three fade as the spin does.
	local bend = top.curl * top.turn * dt * (0.4 + 0.6 * share)
	local cos, sin = math.cos(bend), math.sin(bend)
	headX, headY = headX * cos - headY * sin, headX * sin + headY * cos
	-- A leaning tip also bites toward the low point of the bowl, so a top
	-- does not settle into circling the rim: it keeps diving back through
	-- the middle and out the other side, and the bend above turns each
	-- pass a little. That is the petal pattern real tops trace.
	local distance = math.sqrt(top.x * top.x + top.y * top.y)
	if distance > 1 then
		local rx, ry = top.x / distance, top.y / distance
		local along = headX * rx + headY * ry
		local shed = math.min(1, top.dive * dt)
		headX, headY = direction(headX - (headX - along * rx) * shed, headY - (headY - along * ry) * shed, headX, headY)
	end
	local wanted = top.cruise * (BattleSimulation.IDLE_CRUISE + (1 - BattleSimulation.IDLE_CRUISE) * share)
	if speed < wanted then
		speed = math.min(wanted, speed + top.grip * dt)
	else
		speed = math.max(wanted, speed - top.brake * (0.3 + 0.7 * share) * dt)
	end
	top.vx, top.vy = headX * speed, headY * speed
	top.x, top.y = top.x + top.vx * dt, top.y + top.vy * dt
	if speed > 1 then top.heading = atan2(top.vy, top.vx) end
	top.spin = top.spin - top.decay * (1 + BattleSimulation.WOBBLE_DECAY * (1 - share)) * dt
end

local function collide(state, a, b)
	state._clashCool = math.max(0, state._clashCool - BattleSimulation.FIXED_DT)
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
	local shareA, shareB = clamp(a.spin / a.spinMax, 0, 1), clamp(b.spin / b.spinMax, 0, 1)
	-- How fast the two rims are sliding past each other where they meet.
	-- Turning the same way they pass in opposite directions and it is large;
	-- turning opposite ways they roll together and it nearly vanishes.
	local slip = a.turn * shareA * a.radius + b.turn * shareB * b.radius
	local bounce = -(1 + BattleSimulation.RESTITUTION) * closing / (1 / a.mass + 1 / b.mass)
	local recoil = BattleSimulation.RECOIL * math.abs(slip) * (a.bite + b.bite) / 2
	-- A seeded share of luck decides which rim catches the other cleanly.
	local luck = (roll(state) * 2 - 1) * BattleSimulation.LUCK
	-- Spin is what holds a top steady: the less it has left, the further a
	-- touch throws it.
	local looseA = 1 + BattleSimulation.UNSTEADY * (1 - shareA)
	local looseB = 1 + BattleSimulation.UNSTEADY * (1 - shareB)
	local takenA, takenB = (bounce + recoil * (1 - luck)) * a.guard, (bounce + recoil * (1 + luck)) * b.guard
	local onA, onB = takenA * looseA, takenB * looseB
	a.vx, a.vy = a.vx - nx * onA / a.mass, a.vy - ny * onA / a.mass
	b.vx, b.vy = b.vx + nx * onB / b.mass, b.vy + ny * onB / b.mass
	-- The sideways throw: each rim drags the other along the way it is turning.
	local side = BattleSimulation.SIDE_KICK * slip
	local tx, ty = -ny, nx
	a.vx, a.vy = a.vx - tx * side * a.guard / a.mass, a.vy - ty * side * a.guard / a.mass
	b.vx, b.vy = b.vx + tx * side * b.guard / b.mass, b.vy + ty * side * b.guard / b.mass
	-- What it cost each of them in spin.
	local same = a.turn == b.turn
	a.spin = a.spin - BattleSimulation.HIT_COST * takenA * b.bite * (same and 1 or 0.5)
	b.spin = b.spin - BattleSimulation.HIT_COST * takenB * a.bite * (same and 1 or 0.5)
	if not same then
		local gap = (shareA - shareB) * BattleSimulation.EQUALIZE
		local giver, taker = a, b
		if gap < 0 then giver, taker, gap = b, a, -gap end
		giver.spin = giver.spin - gap * giver.spinMax
		taker.spin = math.min(taker.spinMax, taker.spin + gap * taker.spinMax * BattleSimulation.EQUALIZE_KEEP)
	end
	-- Whoever is flung away faster took the hit; the other held its ground.
	local awayA, awayB = -(a.vx * nx + a.vy * ny), b.vx * nx + b.vy * ny
	local winner, loser = a, b
	if awayA > awayB then winner, loser = b, a end
	winner.hits = winner.hits + 1
	local hit = event(state, "clash", a.x + nx * a.radius, a.y + ny * a.radius, winner.id, loser.id)
	hit.power = math.max(awayA, awayB, 0)
	hit.source, hit.skillId = same and "smash" or "grind", winner.offenceId
	hit.even = math.abs(awayA - awayB) < 5
end

-- The wall turns a top back unless it arrives at a gap. Returns true once a
-- top has gone out through one.
local function wall(state, top)
	local distance = math.sqrt(top.x * top.x + top.y * top.y)
	local limit = BattleSimulation.RING_RADIUS - top.radius
	top.edge = distance / limit
	if distance <= limit then return false end
	local angle = atan2(top.y, top.x)
	local speed = math.sqrt(top.vx * top.vx + top.vy * top.vy)
	-- A top under its own power follows the rim past a gap. Only one that has
	-- been thrown, and is still going faster than its tip would take it, goes out.
	if speed > top.cruise + BattleSimulation.THROWN and BattleSimulation.gapAt(angle) then
		return distance > BattleSimulation.RING_RADIUS
	end
	local rx, ry = top.x / distance, top.y / distance
	top.x, top.y = rx * limit, ry * limit
	local outward = top.vx * rx + top.vy * ry
	if outward <= 0 then return false end
	top.vx = top.vx - (1 + BattleSimulation.WALL_BOUNCE) * outward * rx
	top.vy = top.vy - (1 + BattleSimulation.WALL_BOUNCE) * outward * ry
	top.spin = top.spin - BattleSimulation.WALL_COST * outward
	-- A grippy tip catches the wall and comes off it faster than it went in.
	if top.rail > 0 and outward > 6 then
		local speed = math.sqrt(top.vx * top.vx + top.vy * top.vy)
		local boosted = top.cruise * top.rail * clamp(top.spin / top.spinMax, 0, 1)
		if speed > EPSILON and speed < boosted then
			top.vx, top.vy = top.vx / speed * boosted, top.vy / speed * boosted
		end
	end
	if outward > 8 then
		top.wallHits = top.wallHits + 1
		event(state, "wall", top.x, top.y, top.id, 0).power = outward
		if outward > BattleSimulation.CLOSE_SPEED and BattleSimulation.gapAt(angle, BattleSimulation.CLOSE_ANGLE) then
			top.closeCalls = top.closeCalls + 1
			event(state, "close", top.x, top.y, top.id, 0)
		end
	end
	return false
end

-- Ends a round that is still going: the top with more of its spin left takes it.
function BattleSimulation.expire(state)
	if state.finished then return state end
	local a, b = state.fighters[1], state.fighters[2]
	local shareA, shareB = a.spin / a.spinMax, b.spin / b.spinMax
	finish(state, "timeout", math.abs(shareA - shareB) < 0.0001 and 0 or (shareA > shareB and 1 or 2))
	return state
end

local function tick(state)
	local dt = BattleSimulation.FIXED_DT
	state.elapsed = state.elapsed + dt
	local a, b = state.fighters[1], state.fighters[2]
	advance(a, dt)
	advance(b, dt)
	collide(state, a, b)
	local fallen, stopped = {}, {}
	for _, top in ipairs(state.fighters) do
		if wall(state, top) then
			top.out = true
			fallen[#fallen + 1] = top
		elseif top.spin <= 0 then
			stopped[#stopped + 1] = top
		end
	end
	-- Two tops stopped by the same touch: the one it took more out of is the
	-- one that falls. Only a dead heat is a draw.
	if #stopped == 2 and math.abs(a.spin - b.spin) > 0.01 then
		stopped = { a.spin < b.spin and a or b }
	end
	for _, top in ipairs(stopped) do top.spin, top.down = 0, true end
	for _, top in ipairs(state.fighters) do top.spin = math.max(0, top.spin) end
	-- Going out through the wall settles it before running out of spin does.
	local lost, reason = fallen, "ringout"
	if #lost == 0 then lost, reason = stopped, "spinout" end
	if #lost > 0 then
		for _, top in ipairs(lost) do
			event(state, reason, top.x, top.y, #lost == 1 and 3 - top.id or 0, top.id)
		end
		finish(state, reason, #lost == 1 and 3 - lost[1].id or 0)
	elseif state.elapsed >= BattleSimulation.MAX_TIME - EPSILON then
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
