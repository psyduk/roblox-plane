--!nonstrict
-- Pure shared simulation. The server steps flights and owns results; clients
-- reconstruct the course and interpolate snapshots. Randomness is seeded.
local Simulation = {}
local PlaneCatalog = require(script.Parent.PlaneCatalog)
local PowerCatalog = require(script.Parent.PowerCatalog)

Simulation.DEFAULT_SETTINGS = { planeId = PlaneCatalog.DEFAULT_ID, angle = 35, gadget = "Shield" }
Simulation.MAX_FLIGHT_TIME = 45
Simulation.FIXED_DT = 1 / 60
Simulation.PLANE_RADIUS = 6
Simulation.GRAVITY = 3.8
Simulation.THIN_AIR_HEIGHT = 135
Simulation.NEAR_MISS_MARGIN = 12
Simulation.EVENT_HISTORY_LIMIT = 12

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function setting(value, fallback, low, high)
	if not finite(value) then
		return fallback
	end
	return math.floor(clamp(value, low, high) + 0.5)
end

-- Park-Miller's product fits exactly in a double; no platform-specific bit ops.
local function randomGenerator(seed)
	local current = math.floor(math.abs(seed)) % 2147483646 + 1
	return function(low, high)
		current = current * 48271 % 2147483647
		return low + (high - low) * (current / 2147483647)
	end
end

function Simulation.makeCourse(seed, variant)
	seed = finite(seed) and math.floor(clamp(seed, -2147483646, 2147483646)) or 1
	if variant ~= "Coast" and variant ~= "Skyline" and variant ~= "Storm" then
		variant = "Coast"
	end
	local random = randomGenerator(seed)
	local course = { seed = seed, name = variant, items = {}, length = 4200 }
	local heights = { 24, 58, 94, 130, 165 }
	local laneShift = variant == "Skyline" and 3 or 0
	local patterns = {
		{ gap = 3, fuel = { 1, 5 } }, -- A gate: missiles flank an open middle.
		{ gap = 5, fuel = { 2, 4 } }, -- Alternating steps through the climb.
		{ gap = 1, fuel = { 3, 5 } }, -- A higher route with pressure below.
		{ gap = 4, fuel = { 1, 3 } }, -- Recovery route underneath a crossfire.
		{ gap = 2, fuel = { 1, 4, 5 } }, -- A short breath between pressure beats.
	}
	local x, row, previousPattern = 88, 0, 0
	while x < course.length - 70 do
		row = row + 1
		local patternIndex = math.floor(random(1, #patterns + 1))
		if patternIndex == previousPattern then patternIndex = patternIndex % #patterns + 1 end
		previousPattern = patternIndex
		local pattern = patterns[patternIndex]
		local recovery = row % (x > 1350 and 9 or 5) == 0
		for lane = 1, #heights do
			if lane ~= pattern.gap or (recovery and lane == 1) then
				local isFuel = recovery and lane == 1
				for _, fuelLane in ipairs(pattern.fuel) do isFuel = isFuel or lane == fuelLane end
				-- Later clusters visibly replace one reward route with pressure.
				-- Rescue pockets remain possible but stop appearing every cluster.
				if x > 1350 and not (recovery and lane == 1) then
					isFuel = isFuel and lane == pattern.fuel[#pattern.fuel]
				end
				local value = 0
				if isFuel then
					local roll = random(0, 1)
					value = recovery and lane == 1 and 20 or (roll < 0.65 and 5 or (roll < 0.94 and 10 or 20))
				end
				-- Adjacent bands are offset horizontally, avoiding vertical walls
				-- and giving each number or missile a distinct moment of contact.
				local itemX = x + (lane % 2 == 0 and 14 or -14) + random(-2, 2)
				local itemY = (recovery and lane == 1 and 31 or heights[lane]) + laneShift + random(-2, 2)
				table.insert(course.items, {
					id = #course.items + 1,
					kind = isFuel and "fuel" or "missile",
					x = itemX, y = itemY, value = value,
					radius = isFuel and 12 or 6,
					amplitude = isFuel and 0 or (variant == "Storm" and 7 or 4),
					frequency = variant == "Storm" and 1.2 or 0.8,
					phase = random(0, math.pi * 2),
					encounter = row,
					rescue = recovery and lane == 1 or false,
				})
			end
		end
		-- Short clusters and an occasional wider breath break up the old grid.
		x = x + (row % 4 == 0 and random(76, 88) or random(50, 60))
	end
	return course
end

function Simulation.itemPosition(item, elapsed)
	if item.kind == "missile" then
		return item.x, item.y + math.sin(elapsed * (item.frequency or 1.1) + (item.phase or 0)) * (item.amplitude or 0)
	end
	return item.x, item.y
end

function Simulation.newFlight(settings, course)
	settings = type(settings) == "table" and settings or Simulation.DEFAULT_SETTINGS
	local profile = PlaneCatalog.get(settings.planeId) or PlaneCatalog.get(PlaneCatalog.DEFAULT_ID)
	local angle = setting(settings.angle, profile.defaultAngle, PlaneCatalog.MIN_ANGLE, PlaneCatalog.MAX_ANGLE)
	local gadget = settings.gadget
	if gadget ~= "Shield" and gadget ~= "Magnet" and gadget ~= "Boost" then
		gadget = "Shield"
	end
	local radians = math.rad(angle)
	local speed = profile.speed
	local power = PowerCatalog.get(settings.powerId)
	local powerId = power and power.id or nil
	return {
		x = 0,
		y = 18,
		vx = math.cos(radians) * speed,
		vy = math.sin(radians) * speed,
		alive = true,
		distance = 0,
		elapsed = 0,
		pickups = 0,
		hits = 0,
		shield = not powerId and gadget == "Shield" and 1 or 0,
		powerId = powerId,
		powerCharges = powerId and (powerId == "Meteor" and 1 or 3) or 0,
		powerPhase = powerId and "armed" or "spent",
		powerPeak = 18,
		powerUses = 0,
		used = {},
		gadget = gadget,
		boostUsed = false,
		nearMisses = 0,
		nearCandidates = {},
		nearPassed = {},
		eventSerial = 1,
		recentEvents = { { kind = "launch", text = "Liftoff!", at = 0, serial = 1, x = 0, y = 18, value = 0 } },
		settings = { planeId = profile.id, angle = angle, speed = speed, gadget = gadget, powerId = powerId },
		lastEvent = { kind = "launch", text = "Liftoff!", at = 0, serial = 1, x = 0, y = 18, value = 0 },
	}
end

-- Relative swept circle collision also handles a missile moving across a plane
-- between frames. Return the first intersection, not just the closest point.
local function intersection(ax, ay, bx, by, radius)
	local c = ax * ax + ay * ay - radius * radius
	if c <= 0 then
		return 0
	end
	local dx, dy = bx - ax, by - ay
	local a = dx * dx + dy * dy
	if a <= 0.00000001 then
		return nil
	end
	local b = 2 * (ax * dx + ay * dy)
	local discriminant = b * b - 4 * a * c
	if discriminant < 0 then
		return nil
	end
	local t = (-b - math.sqrt(discriminant)) / (2 * a)
	if t >= 0 and t <= 1 then
		return t
	end
	return nil
end

local function event(state, kind, text, item, value)
	state.eventSerial = state.eventSerial + 1
	local x, y = state.x, state.y
	if item then x, y = Simulation.itemPosition(item, state.elapsed) end
	local record = { kind = kind, text = text, at = state.elapsed, serial = state.eventSerial,
		x = x, y = y, itemId = item and item.id or nil, value = value or (item and item.value) or 0 }
	state.lastEvent = record
	table.insert(state.recentEvents, record)
	if #state.recentEvents > Simulation.EVENT_HISTORY_LIMIT then table.remove(state.recentEvents, 1) end
end

local function forwardLimit(state)
	if state.powerId == "Meteor" then return 165 end
	if state.powerId == "Muncher" then return 125 end
	if state.powerId == "Pinball" then return 135 end
	return 105
end

local function consumePower(state)
	state.powerCharges = state.powerCharges - 1
	state.powerUses = state.powerUses + 1
	if state.powerCharges == 0 then state.powerPhase = "spent" end
end

local function sweptGap(ax, ay, bx, by, radius)
	local dx, dy = bx - ax, by - ay
	local lengthSquared = dx * dx + dy * dy
	local t = lengthSquared > 0 and clamp(-(ax * dx + ay * dy) / lengthSquared, 0, 1) or 0
	local x, y = ax + dx * t, ay + dy * t
	return math.sqrt(x * x + y * y) - radius
end

function Simulation.step(state, course, dt)
	if not state.alive or not finite(dt) or dt <= 0 then
		return state
	end
	-- Fixed-step callers use 1/60. Bound misuse so a stalled client cannot make
	-- one giant physics leap; catching up is the caller's accumulator's job.
	dt = math.min(dt, 1 / 15, Simulation.MAX_FLIGHT_TIME - state.elapsed)
	local oldX, oldY, oldTime = state.x, state.y, state.elapsed
	state.elapsed = state.elapsed + dt
	local beforeDeadline = state.elapsed < Simulation.MAX_FLIGHT_TIME
	state.powerPeak = math.max(state.powerPeak or oldY, oldY)
	state.vx = math.max(18, state.vx * (1 - 0.015 * dt))
	local meteorDiving = state.powerId == "Meteor" and state.powerPhase == "diving"
	state.vy = math.max(meteorDiving and -64 or -22, state.vy - Simulation.GRAVITY * (meteorDiving and 3.2 or 1) * dt)
	-- Upward thrust fades in thin air, keeping high launches near the stronger
	-- pickups. This only damps ascent; it never slams a plane down from a ceiling.
	if state.y > Simulation.THIN_AIR_HEIGHT and state.vy > 0 then
		state.vy = state.vy * math.max(0, 1 - (state.y - Simulation.THIN_AIR_HEIGHT) * 0.06 * dt)
	end
	-- The first apex (including one forced by a missile) commits Meteor to its
	-- dive. No steering or timing input is required after the launch decision.
	if beforeDeadline and state.powerId == "Meteor" and state.powerPhase == "armed" and state.vy <= 0 and oldY > 0 then
		state.powerPhase = "diving"
		state.vy = -(40 + 20 * clamp((state.powerPeak - 18) / 140, 0, 1))
		event(state, "meteorDive", "METEOR DIVE!", nil, state.powerPeak)
	end
	-- Predict the low-altitude crossing before movement, so even a coarse step
	-- cannot tunnel into the ground. Each step still has one straight collision
	-- sweep; the turn begins at most one step above the pull-up height.
	if beforeDeadline and state.powerId == "Meteor" and state.powerPhase == "diving" and oldY > 0 and oldY + state.vy * dt <= 18 then
		local charge = clamp((state.powerPeak - 18) / 140, 0, 1)
		state.vx = math.min(forwardLimit(state), state.vx + 35 + 45 * charge)
		state.vy = 25 + 10 * charge
		consumePower(state)
		event(state, "meteorBoost", "METEOR BLAST!", nil, state.powerPeak)
	end
	state.x = state.x + state.vx * dt
	state.y = state.y + state.vy * dt
	state.powerPeak = math.max(state.powerPeak, state.y)

	local contacts, clearedMissiles = {}, {}
	for _, item in ipairs(course.items) do
		if not state.used[item.id] and not state.nearPassed[item.id] and item.x >= math.min(oldX, state.x) - 65 and item.x <= math.max(oldX, state.x) + 65 then
			local ix0, iy0 = Simulation.itemPosition(item, oldTime)
			local ix1, iy1 = Simulation.itemPosition(item, state.elapsed)
			local radius = item.radius + Simulation.PLANE_RADIUS
			if item.kind == "fuel" and not state.powerId and state.gadget == "Magnet" then
				radius = radius + 10
			end
			local hitAt = intersection(oldX - ix0, oldY - iy0, state.x - ix1, state.y - iy1, radius)
			if item.kind == "missile" then
				local gap = sweptGap(oldX - ix0, oldY - iy0, state.x - ix1, state.y - iy1, radius)
				state.nearCandidates[item.id] = math.min(state.nearCandidates[item.id] or math.huge, gap)
				if state.x > item.x + radius + Simulation.NEAR_MISS_MARGIN then table.insert(clearedMissiles, item) end
			end
			if hitAt then
				table.insert(contacts, { item = item, fraction = hitAt })
			end
		end
	end
	table.sort(contacts, function(a, b)
		if a.fraction == b.fraction then
			return a.item.id < b.item.id
		end
		return a.fraction < b.fraction
	end)
	for _, contact in ipairs(contacts) do
		local item = contact.item
		-- Never collect an object after the flight has touched the ground.
		if oldY + (state.y - oldY) * contact.fraction > 0 then
			state.used[item.id] = true
			if item.kind == "fuel" then
				state.pickups = state.pickups + 1
				state.vx = math.min(forwardLimit(state), state.vx + 1 + item.value * 0.3)
				-- Fuel first steadies a dive, so even a late pickup visibly saves
				-- altitude. Stronger numbered cans then supply a larger lift.
				-- Meteor remains committed to its dive; fuel still adds speed but
				-- cannot cancel the promised automatic pull-up and blast.
				if state.powerPhase ~= "diving" then
					state.vy = math.min(62, math.max(state.vy, -8) + item.value * 0.65)
				end
				event(state, "fuel", "+" .. tostring(item.value) .. " FUEL!", item)
			elseif beforeDeadline and state.powerId == "Muncher" and state.powerCharges > 0 then
				consumePower(state)
				state.vx = math.min(forwardLimit(state), state.vx + 8 + 4 * state.powerUses)
				state.vy = math.min(56, math.max(state.vy, -8) + 1 + 3 * state.powerUses)
				event(state, "munch", "CHOMP! " .. tostring(state.powerUses) .. "/3", item, state.powerUses)
			else
				state.hits = state.hits + 1
				if state.shield > 0 then
					state.shield = state.shield - 1
					event(state, "shield", "SHIELD SAVE!", item)
				else
					state.vx = math.max(18, state.vx * 0.92)
					state.vy = math.max(state.powerPhase == "diving" and -64 or -22, state.vy - 10)
					event(state, "missile", "MISSILE HIT! Find fuel!", item)
				end
			end
		end
	end
	for _, item in ipairs(clearedMissiles) do
		state.nearPassed[item.id] = true
		local gap = state.nearCandidates[item.id]
		if state.y > 0 and not state.used[item.id] and gap > 0 and gap <= Simulation.NEAR_MISS_MARGIN then
			state.nearMisses = state.nearMisses + 1
			event(state, "nearMiss", "CLOSE CALL!", item)
		end
		state.nearCandidates[item.id] = nil
	end

	-- A rescue gadget fires before impact, once. It cannot resurrect a plane
	-- already on the ground and never asks the player for a mid-flight input.
	if not state.powerId and state.gadget == "Boost" and not state.boostUsed and state.elapsed > 1 and state.y > 0 and state.y < 19 and state.vy < 0 then
		state.boostUsed = true
		state.vy = 29
		state.vx = math.min(105, state.vx + 14)
		event(state, "boost", "RESCUE BOOST!")
	end

	if state.y <= 0 then
		local fraction = oldY / math.max(0.00000001, oldY - state.y)
		state.x = oldX + (state.x - oldX) * clamp(fraction, 0, 1)
		state.y = 0
		state.distance = math.max(state.distance, state.x)
		if beforeDeadline and oldY > 0 and state.powerId == "Pinball" and state.powerCharges > 0 then
			consumePower(state)
			state.vx = math.min(forwardLimit(state), state.vx + 18)
			state.vy = 17 - state.powerUses
			event(state, "pinball", "BOING! " .. tostring(state.powerUses) .. "/3", nil, state.powerUses)
		else
			state.alive = false
			state.finishReason = "landed"
			event(state, "finish", "TOUCHDOWN! Distance locked!")
		end
	elseif state.elapsed >= Simulation.MAX_FLIGHT_TIME then
		state.alive = false
		state.finishReason = "timeout"
		event(state, "finish", "Flight complete — distance locked!")
	end
	state.distance = math.max(state.distance, state.x)
	return state
end

-- A short aim guide using the same physics, without predicting course contacts.
-- Returned points include the launch origin. Settings and active flights remain
-- untouched, so dragging an aim control cannot consume fuel or a rescue gadget.
function Simulation.previewTrajectory(settings, seconds)
	seconds = finite(seconds) and clamp(seconds, 0.1, 4) or 2.5
	local course = { items = {} }
	local state = Simulation.newFlight(settings, course)
	local points = { { x = state.x, y = state.y } }
	local steps = math.ceil(seconds / Simulation.FIXED_DT)
	for index = 1, steps do
		Simulation.step(state, course, math.min(Simulation.FIXED_DT, seconds - state.elapsed))
		if index % 6 == 0 or index == steps or not state.alive then
			table.insert(points, { x = state.x, y = state.y })
		end
		if not state.alive then break end
	end
	return points
end

return Simulation
