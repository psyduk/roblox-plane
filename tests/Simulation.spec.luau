-- Pure tests: run require(thisModule)(Simulation) in Studio or any Lua runtime.
-- No services or game state are touched. The returned string lists coverage.
return function(Simulation)
	local passed = 0
	local function check(condition, message)
		assert(condition, message)
	end
	local function close(a, b)
		return math.abs(a - b) < 0.0000001
	end
	local function test(name, callback)
		local ok, problem = pcall(callback)
		assert(ok, name .. ": " .. tostring(problem))
		passed = passed + 1
	end
	local function emptyCourse()
		return { seed = 1, name = "Test", items = {}, length = 4200 }
	end
	local function run(settings, course)
		local state = Simulation.newFlight(settings, course)
		for _ = 1, math.ceil(Simulation.MAX_FLIGHT_TIME / Simulation.FIXED_DT) + 1 do
			Simulation.step(state, course, Simulation.FIXED_DT)
			if not state.alive then
				return state
			end
		end
		error("Flight exceeded safety timeout")
	end
	local function item(kind, x, y, id, value)
		return { id = id or 1, kind = kind, x = x, y = y, radius = 2, value = value or 10 }
	end

	test("course and flight determinism", function()
		local a, b = Simulation.makeCourse(492531, "Storm"), Simulation.makeCourse(492531, "Storm")
		check(#a.items == #b.items and #a.items > 20, "Course item count changed")
		for i, entry in ipairs(a.items) do
			local other = b.items[i]
			check(entry.id == i, "Course IDs must be unique")
			check(entry.kind == other.kind and entry.x == other.x and entry.y == other.y and entry.value == other.value, "Seed produced different course")
			local ax, ay = Simulation.itemPosition(entry, 12.5)
			local bx, by = Simulation.itemPosition(other, 12.5)
			check(ax == bx and ay == by, "Missile motion is nondeterministic")
		end
		local f, g = run(Simulation.DEFAULT_SETTINGS, a), run(Simulation.DEFAULT_SETTINGS, b)
		check(f.x == g.x and f.y == g.y and f.elapsed == g.elapsed and f.hits == g.hits and f.pickups == g.pickups, "Repeated flight differed")
		check(f.lastEvent.kind == g.lastEvent.kind and f.finishReason == g.finishReason, "Finish differs")
		check(f.nearMisses == g.nearMisses and f.eventSerial == g.eventSerial, "Event sequence differs")
		for id in pairs(f.used) do
			check(g.used[id], "Collision order differs")
		end
	end)

	test("fuel adds forward and upward motion only once", function()
		local course = emptyCourse()
		course.items = { item("fuel", 0, 18, 1, 20) }
		local baseline = Simulation.newFlight(nil, course)
		local boosted = Simulation.newFlight(nil, course)
		Simulation.step(baseline, emptyCourse(), Simulation.FIXED_DT)
		Simulation.step(boosted, course, Simulation.FIXED_DT)
		check(boosted.vx > baseline.vx and boosted.vy > baseline.vy, "Fuel did not boost both velocities")
		check(boosted.pickups == 1 and boosted.used[1] and boosted.lastEvent.kind == "fuel", "Missing pickup event")
		for _ = 1, 4 do
			Simulation.step(boosted, course, Simulation.FIXED_DT)
		end
		check(boosted.pickups == 1, "Fuel collected twice")
	end)

	test("shield blocks exactly one missile", function()
		local course = emptyCourse()
		course.items = { item("missile", 0, 18, 1), item("missile", 0, 18, 2) }
		local state = Simulation.newFlight({ gadget = "Shield" }, course)
		local initialSpeed = state.vx
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.alive and state.hits == 2 and state.shield == 0, "Shield must consume once and allow damage afterward")
		check(state.vx < initialSpeed * 0.95 and state.vx > initialSpeed * 0.88 and state.lastEvent.kind == "missile", "Exactly one missile should damage through the shield")
	end)

	test("missile damage is recoverable with fuel", function()
		local course = emptyCourse()
		local state = Simulation.newFlight({ gadget = "Magnet" }, course)
		state.x, state.y, state.vx, state.vy = 0, 70, 60, -5
		course.items = { item("missile", 0, 70, 1) }
		Simulation.step(state, course, Simulation.FIXED_DT)
		local damagedVx, damagedVy = state.vx, state.vy
		check(state.alive and damagedVy < -14 and state.hits == 1, "Missile should hurt without ending flight")
		course.items = { item("fuel", state.x, state.y, 2, 20) }
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.alive and state.vx > damagedVx and state.vy > damagedVy + 15, "Fuel cannot recover a damaged plane")
	end)

	test("magnet increases fuel reach but not missile reach", function()
		local course = emptyCourse()
		course.items = { item("fuel", 0, 35, 1), item("missile", 0, 35, 2) }
		local magnet = Simulation.newFlight({ gadget = "Magnet" }, course)
		local normal = Simulation.newFlight({ gadget = "Shield" }, course)
		Simulation.step(magnet, course, Simulation.FIXED_DT)
		Simulation.step(normal, course, Simulation.FIXED_DT)
		check(magnet.pickups == 1 and normal.pickups == 0, "Magnet does not increase pickup radius")
		check(magnet.hits == 0, "Magnet attracted a missile")
	end)

	test("automatic rescue boost fires once", function()
		local course = emptyCourse()
		local state = Simulation.newFlight({ gadget = "Boost" }, course)
		state.elapsed, state.y, state.vy = 2, 18, -10
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.boostUsed and state.vy > 20 and state.lastEvent.kind == "boost", "Rescue did not fire automatically")
		state.y, state.vy = 18, -10
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.vy < 0, "Rescue fired twice")
	end)

	test("swept collision catches skipped endpoints", function()
		local course = emptyCourse()
		course.items = { item("fuel", 100, 50, 1, 5) }
		local state = Simulation.newFlight(nil, course)
		state.y, state.vx, state.vy = 50, 12000, 0
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.x > 190 and state.pickups == 1, "Swept collision missed a crossed pickup")
	end)

	test("moving missile uses matching visual position", function()
		local course = emptyCourse()
		local missile = item("missile", 0, 50, 1)
		missile.amplitude, missile.frequency, missile.phase = 100, math.pi / Simulation.FIXED_DT, -math.pi / 2
		course.items = { missile }
		local state = Simulation.newFlight({ gadget = "Shield" }, course)
		state.y, state.vx, state.vy = 50, 18, 0
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.hits == 1 and state.shield == 0, "Relative sweep missed moving missile")
	end)

	test("ground touchdown ends run at first impact and locks distance", function()
		local course = emptyCourse()
		local state = Simulation.newFlight(nil, course)
		state.y, state.vy, state.vx = 0.01, -20, 60
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(not state.alive and state.y == 0 and state.finishReason == "landed", "Ground touchdown failed to end run")
		check(state.lastEvent.text == "TOUCHDOWN! Distance locked!", "Touchdown feedback is missing")
		check(state.distance > 0 and state.distance < 0.1, "Distance continued past first ground contact")
		local finalDistance, elapsed = state.distance, state.elapsed
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.distance == finalDistance and state.elapsed == elapsed, "Finished flight advanced")
	end)

	test("hard timeout prevents endless rounds", function()
		local course = emptyCourse()
		local state = Simulation.newFlight(nil, course)
		state.elapsed, state.y, state.vy = Simulation.MAX_FLIGHT_TIME - 0.005, 150, 20
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(not state.alive and state.finishReason == "timeout" and close(state.elapsed, Simulation.MAX_FLIGHT_TIME), "Timeout failed")
	end)

	test("invalid inputs are bounded and finite", function()
		local course = Simulation.makeCourse(0 / 0, "unknown")
		check(course.name == "Coast" and course.seed == 1, "Course defaults failed")
		local state = Simulation.newFlight({ planeId = "unknown", angle = math.huge, speed = 0 / 0, gadget = "PaidPower" }, course)
		check(state.settings.planeId == "cruiser" and state.settings.angle == 35 and state.settings.speed == 72.25 and state.gadget == "Shield", "Settings defaults failed")
		local capped = Simulation.newFlight({ planeId = "dart", angle = 9999, speed = -9999, power = 100 }, course)
		check(capped.settings.angle == 60 and capped.settings.speed == 81 and capped.settings.power == nil, "Angle clamp or fixed plane speed failed")
		Simulation.step(state, course, 0 / 0)
		Simulation.step(state, course, -1)
		check(state.elapsed == 0, "Invalid timestep advanced flight")
	end)

	test("all plane angle and gadget choices finish safely", function()
		for _, variant in ipairs({ "Coast", "Skyline", "Storm" }) do
			for _, angle in ipairs({ 15, 35, 60 }) do
				for _, planeId in ipairs({ "cruiser", "skyhopper", "dart" }) do
					for _, gadget in ipairs({ "Shield", "Magnet", "Boost" }) do
						local state = run({ planeId = planeId, angle = angle, gadget = gadget }, Simulation.makeCourse(12345, variant))
						check(state.distance > 0 and state.distance < 5000 and state.elapsed <= Simulation.MAX_FLIGHT_TIME, "Invalid extreme result")
						check(state.x == state.x and state.y == state.y, "NaN in flight")
					end
				end
			end
		end
	end)

	test("launch settings change outcome", function()
		local course = Simulation.makeCourse(98123, "Coast")
		local low = run({ planeId = "cruiser", angle = 15, gadget = "Shield" }, course)
		local high = run({ planeId = "cruiser", angle = 60, gadget = "Shield" }, course)
		check(math.abs(low.distance - high.distance) > 10, "Launch settings had no meaningful effect")
	end)

	test("plane profiles fix speed while launch direction follows the chosen angle", function()
		local course = emptyCourse()
		for _, profile in ipairs({ { "cruiser", 35, 72.25 }, { "skyhopper", 48, 64.5 }, { "dart", 24, 81 } }) do
			local defaults = Simulation.newFlight({ planeId = profile[1] }, course)
			check(defaults.settings.angle == profile[2], "Plane default angle was lost")
			for _, angle in ipairs({ 15, 27.4, 60 }) do
				local state = Simulation.newFlight({ planeId = profile[1], angle = angle, speed = 999, power = 999 }, course)
				local radians = math.rad(math.floor(angle + 0.5))
				check(close(state.vx, math.cos(radians) * profile[3]) and close(state.vy, math.sin(radians) * profile[3]), "Aim and velocity direction disagree")
				check(close(math.sqrt(state.vx * state.vx + state.vy * state.vy), profile[3]), "A client field overrode plane speed")
			end
		end
		local default = Simulation.newFlight(nil, course)
		local explicit = Simulation.newFlight({ planeId = "cruiser", angle = 35, gadget = "Shield" }, course)
		check(default.vx == explicit.vx and default.vy == explicit.vy and default.settings.speed == 72.25, "Default plane differs from explicit Cruiser")
	end)

	test("all planes repeat exactly on shared seeded conditions", function()
		for _, planeId in ipairs({ "cruiser", "skyhopper", "dart" }) do
			local settings = { planeId = planeId, angle = 29, gadget = "Magnet" }
			local a = run(settings, Simulation.makeCourse(98123, "Storm"))
			local b = run(settings, Simulation.makeCourse(98123, "Storm"))
			check(a.distance == b.distance and a.elapsed == b.elapsed and a.eventSerial == b.eventSerial, "Plane flight is nondeterministic")
		end
	end)

	test("aim preview uses real physics without mutating settings or live flight", function()
		local settings = { planeId = "dart", angle = 27, gadget = "Boost" }
		local course = emptyCourse()
		local live = Simulation.newFlight(settings, course)
		local points = Simulation.previewTrajectory(settings, 2)
		check(#points == 21 and points[1].x == 0 and points[1].y == 18, "Preview origin or sampling changed")
		check(live.elapsed == 0 and not live.boostUsed and settings.angle == 27, "Preview changed active state")
		for _ = 1, 120 do Simulation.step(live, course, Simulation.FIXED_DT) end
		check(close(points[#points].x, live.x) and close(points[#points].y, live.y), "Preview diverges from empty-course physics")
		check(#Simulation.previewTrajectory(settings, math.huge) == 26 and #Simulation.previewTrajectory(settings, 99) == 41, "Preview duration is not bounded")
	end)

	test("dense course mixes values and leaves room between encounter objects", function()
		for _, variant in ipairs({ "Coast", "Skyline", "Storm" }) do
			local course = Simulation.makeCourse(812345, variant)
			check(#course.items >= 240, "Course has too few objects for dense upcoming encounters")
			local earlyFuel, earlyMissiles, lateFuel, lateMissiles = 0, 0, 0, 0
			local lowRescues, highSmallFuel = 0, 0
			for _, entry in ipairs(course.items) do
				check(entry.y >= 20 and entry.y <= 172, "Object is outside the readable flight bands")
				if entry.kind == "missile" then
					check(entry.amplitude <= 10, "Missile moves too far from its visible corridor")
				else
					if entry.value == 20 and entry.y <= 40 then lowRescues = lowRescues + 1 end
					if entry.value == 5 and entry.y > 120 then highSmallFuel = highSmallFuel + 1 end
				end
				if entry.x < 900 then
					if entry.kind == "fuel" then earlyFuel = earlyFuel + 1 else earlyMissiles = earlyMissiles + 1 end
				elseif entry.x > 1500 then
					if entry.kind == "fuel" then lateFuel = lateFuel + 1 else lateMissiles = lateMissiles + 1 end
				end
			end
			check(lowRescues > 0 and highSmallFuel > 0, "Fuel strength is still tied only to altitude")
			check(earlyMissiles > 0 and lateMissiles / lateFuel > earlyMissiles / earlyFuel, "Later course should visibly add pressure")
			for i, a in ipairs(course.items) do
				for j = i + 1, #course.items do
					local b = course.items[j]
					if math.abs(a.x - b.x) < 40 then
						local dx, dy = a.x - b.x, a.y - b.y
						check(dx * dx + dy * dy > (a.radius + b.radius) ^ 2, "Encounter contains overlapping pickup or hazard bodies")
					end
				end
			end
		end
	end)

	test("near miss waits for full clearance and has no mechanical reward", function()
		local course = emptyCourse()
		course.items = { item("missile", 30, 66, 1) }
		local state, baseline = Simulation.newFlight(nil, course), Simulation.newFlight(nil, course)
		state.y, state.vx, state.vy = 50, 60, 0
		baseline.y, baseline.vx, baseline.vy = 50, 60, 0
		for _ = 1, 40 do
			Simulation.step(state, course, Simulation.FIXED_DT)
			Simulation.step(baseline, emptyCourse(), Simulation.FIXED_DT)
		end
		check(state.nearMisses == 0, "Near miss announced before clearing the missile")
		for _ = 1, 40 do
			Simulation.step(state, course, Simulation.FIXED_DT)
			Simulation.step(baseline, emptyCourse(), Simulation.FIXED_DT)
		end
		check(state.nearMisses == 1 and state.hits == 0 and not state.used[1], "Close pass did not resolve exactly once")
		check(state.x == baseline.x and state.y == baseline.y and state.vx == baseline.vx and state.vy == baseline.vy, "Near miss changed flight performance")
		check(state.lastEvent.kind == "nearMiss" and state.lastEvent.itemId == 1, "Near-miss feedback missing")
	end)

	test("a missile cannot award both contact and near miss", function()
		local course = emptyCourse()
		course.items = { item("missile", 30, 50, 1) }
		local state = Simulation.newFlight(nil, course)
		state.y, state.vx, state.vy = 50, 60, 0
		for _ = 1, 90 do Simulation.step(state, course, Simulation.FIXED_DT) end
		check(state.hits == 1 and state.used[1] and state.nearMisses == 0, "Hit missile also counted as a near miss")
	end)

	test("ground contact prevents a terminal-step near miss", function()
		local course = emptyCourse()
		course.items = { item("missile", -19.5, 10, 1) }
		local state = Simulation.newFlight(nil, course)
		state.y, state.vy, state.vx = 0.01, -20, 60
		state.nearCandidates[1] = 1
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.finishReason == "landed" and state.distance < 0.1 and state.nearMisses == 0, "Near miss awarded after first ground contact")
	end)

	test("feedback history preserves rapid events with bounded ordered serials", function()
		local course = emptyCourse()
		course.items = { item("fuel", 0, 18, 1, 5), item("fuel", 0, 18, 2, 20) }
		local state = Simulation.newFlight(nil, course)
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.recentEvents[2].itemId == 1 and state.recentEvents[3].itemId == 2, "Rapid events were overwritten")
		check(state.recentEvents[2].value == 5 and state.recentEvents[3].value == 20, "Fuel feedback lost its number")
		for id = 3, 30 do
			course.items = { item("fuel", state.x, state.y, id, 5) }
			Simulation.step(state, course, Simulation.FIXED_DT)
		end
		check(#state.recentEvents <= Simulation.EVENT_HISTORY_LIMIT, "Feedback history grows without limit")
		for index, entry in ipairs(state.recentEvents) do
			check(type(entry.x) == "number" and type(entry.y) == "number" and type(entry.value) == "number", "Feedback lost spatial/value metadata")
			if index > 1 then check(entry.serial == state.recentEvents[index - 1].serial + 1 and entry.at >= state.recentEvents[index - 1].at, "Feedback serial/time order changed") end
		end
		check(state.lastEvent.serial == state.eventSerial and state.lastEvent.serial == state.recentEvents[#state.recentEvents].serial, "Latest event serial is inconsistent")
	end)

	test("late fuel visibly rescues a dive before touchdown", function()
		local course = emptyCourse()
		local state = Simulation.newFlight({ gadget = "Shield" }, course)
		state.y, state.vy, state.vx = 12, -22, 60
		course.items = { item("fuel", 0, 12, 1, 20) }
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.alive and state.vy > 0 and state.pickups == 1, "Large fuel pickup did not turn a near-ground dive upward")
		local rescuedHeight = state.y
		for _ = 1, 20 do Simulation.step(state, course, Simulation.FIXED_DT) end
		check(state.alive and state.y > rescuedHeight, "Recovered flight did not visibly climb")
	end)

	test("a valid round power suppresses every legacy gadget effect", function()
		for _, powerId in ipairs({ "Pinball", "Muncher", "Meteor" }) do
			local course = emptyCourse()
			local shield = Simulation.newFlight({ powerId = powerId, gadget = "Shield" }, course)
			check(shield.shield == 0 and shield.powerId == powerId and shield.settings.powerId == powerId, "Round power kept a shield or lost identity")
			local magnet = Simulation.newFlight({ powerId = powerId, gadget = "Magnet" }, course)
			course.items = { item("fuel", 0, 35, 1) }
			Simulation.step(magnet, course, Simulation.FIXED_DT)
			check(magnet.pickups == 0, "Round power kept magnet reach")
			local boost = Simulation.newFlight({ powerId = powerId, gadget = "Boost" }, course)
			boost.elapsed, boost.y, boost.vy = 2, 10, -10
			Simulation.step(boost, emptyCourse(), Simulation.FIXED_DT)
			check(not boost.boostUsed, "Round power kept the rescue gadget")
			for _, entry in ipairs(boost.recentEvents) do check(entry.kind ~= "boost", "Legacy rescue feedback leaked into round powers") end
		end
	end)

	test("missing or invalid powers retain the legacy simulation path", function()
		for _, invalid in ipairs({ "Unknown", "pinball", 123, {} }) do
			local state = Simulation.newFlight({ powerId = invalid, gadget = "Shield", powerCharges = 999 }, emptyCourse())
			check(state.powerId == nil and state.powerCharges == 0 and state.powerUses == 0 and state.shield == 1, "Invalid power affected the simulation")
		end
		local state = Simulation.newFlight({ powerId = "Meteor", powerCharges = 999, powerPeak = 99999 }, emptyCourse())
		check(state.powerCharges == 1 and state.powerPeak == 18 and state.powerPhase == "armed", "Client fields supplied power strength")
	end)

	test("Pinball bounces at three descending contacts and lands on the fourth", function()
		local course = emptyCourse()
		local state = Simulation.newFlight({ powerId = "Pinball" }, course)
		for bounce = 1, 3 do
			local oldX = state.x
			state.y, state.vy, state.vx = 0.01, -20, 60
			Simulation.step(state, course, Simulation.FIXED_DT)
			check(state.alive and state.y == 0 and state.vy > 0 and state.vx > 75, "Pinball did not turn impact into forward/upward motion")
			check(state.x > oldX and state.x < oldX + 0.1, "Bounce advanced past the first ground contact")
			check(state.powerCharges == 3 - bounce and state.powerUses == bounce, "Bounce charge count differs")
			check(state.lastEvent.kind == "pinball" and state.lastEvent.value == bounce and state.lastEvent.y == 0, "Bounce feedback lacks impact position/count")
			Simulation.step(state, course, Simulation.FIXED_DT)
			check(state.y > 0 and state.powerUses == bounce, "Takeoff from a bounce consumed another charge")
		end
		check(state.powerPhase == "spent", "Exhausted Pinball stayed armed")
		state.y, state.vy = 0.01, -20
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(not state.alive and state.finishReason == "landed" and state.powerUses == 3, "Fourth ground contact did not end the flight")
		local distance, serial = state.distance, state.eventSerial
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.distance == distance and state.eventSerial == serial, "Finished Pinball resumed")
	end)

	test("Pinball cannot resurrect a plane already below ground or survive its deadline", function()
		local course = emptyCourse()
		local below = Simulation.newFlight({ powerId = "Pinball" }, course)
		below.y, below.vy = -1, -10
		Simulation.step(below, course, Simulation.FIXED_DT)
		check(not below.alive and below.powerUses == 0, "Pinball resurrected a plane below ground")
		local late = Simulation.newFlight({ powerId = "Pinball" }, course)
		late.elapsed, late.y, late.vy = Simulation.MAX_FLIGHT_TIME - 0.001, 0.001, -20
		Simulation.step(late, course, Simulation.FIXED_DT)
		check(not late.alive and late.powerUses == 0 and close(late.elapsed, Simulation.MAX_FLIGHT_TIME), "Pinball bounced after the flight deadline")
	end)

	test("Muncher eats exactly three missiles with escalating kicks then takes a hit", function()
		local course = emptyCourse()
		local state = Simulation.newFlight({ powerId = "Muncher", gadget = "Shield" }, course)
		local previousKick, previousLift = 0, -12
		for bite = 1, 3 do
			state.y, state.vy, state.vx = 70, -12, 40
			course.items = { item("missile", state.x, state.y, bite) }
			Simulation.step(state, course, Simulation.FIXED_DT)
			local kick = state.vx - 40
			check(kick > previousKick and state.vy > previousLift and state.hits == 0, "Bite did not give a growing harmless boost")
			check(state.used[bite] and state.powerUses == bite and state.powerCharges == 3 - bite, "Missile bite count changed")
			check(state.lastEvent.kind == "munch" and state.lastEvent.itemId == bite and state.lastEvent.value == bite, "Bite feedback lost its missile/count")
			Simulation.step(state, course, Simulation.FIXED_DT)
			check(state.powerUses == bite, "A consumed missile was eaten again")
			previousKick, previousLift = kick, state.vy
		end
		check(state.powerPhase == "spent", "Exhausted Muncher stayed armed")
		state.y, state.vy, state.vx = 70, 0, 80
		course.items = { item("missile", state.x, state.y, 4) }
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.hits == 1 and state.vx < 75 and state.vy < -9 and state.powerUses == 3 and state.lastEvent.kind == "missile", "Fourth missile was absorbed or still granted a boost")
	end)

	test("Muncher resolves multiple swept contacts in order without sharing charges", function()
		local course = emptyCourse()
		for id = 1, 4 do table.insert(course.items, item("missile", 0, 18, id)) end
		local first = Simulation.newFlight({ powerId = "Muncher" }, course)
		local other = Simulation.newFlight({ powerId = "Muncher" }, course)
		Simulation.step(first, course, Simulation.FIXED_DT)
		check(first.powerUses == 3 and first.hits == 1 and first.powerCharges == 0, "Simultaneous missiles bypassed exhaustion")
		for index = 2, 4 do
			check(first.recentEvents[index].kind == "munch" and first.recentEvents[index].itemId == index - 1, "Eating order was nondeterministic")
		end
		check(other.powerCharges == 3 and other.powerUses == 0 and next(other.used) == nil, "One pilot consumed another pilot's charges or missiles")
		Simulation.step(other, course, Simulation.FIXED_DT)
		check(first.x == other.x and first.vx == other.vx and first.vy == other.vy and first.eventSerial == other.eventSerial, "Identical pilots diverged on the same course")
	end)

	test("Meteor automatically dives at its first apex and safely pulls up once", function()
		local course = emptyCourse()
		local state = Simulation.newFlight({ powerId = "Meteor" }, course)
		state.y, state.vy = 100, 0.01
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.powerPhase == "diving" and state.vy < -40 and state.powerPeak >= 100 and state.lastEvent.kind == "meteorDive", "Meteor did not turn its apex into a dive")
		check(state.powerCharges == 1 and state.powerUses == 0, "Meteor consumed its burst before the pull-up")
		local diveSerial, previousSpeed = state.eventSerial, state.vx
		for _ = 1, 180 do
			previousSpeed = state.vx
			Simulation.step(state, course, Simulation.FIXED_DT)
			check(state.alive and state.y > 0, "Meteor hit the ground before pulling up")
			if state.powerPhase == "spent" then break end
		end
		check(state.powerPhase == "spent" and state.powerUses == 1 and state.powerCharges == 0, "Meteor did not spend exactly one burst")
		check(state.vx > previousSpeed + 50 and state.vy > 22 and state.vy <= 32 and state.lastEvent.kind == "meteorBoost" and state.eventSerial == diveSerial + 1, "Meteor pull-up lacks its forward blast or compact recovery")
		state.y, state.vy = 10, -15
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.powerUses == 1 and state.vy < 0 and state.eventSerial == diveSerial + 1, "Spent Meteor reactivated")
	end)

	test("Meteor height determines a bounded blast and low-altitude crossing cannot tunnel", function()
		local function blast(peak)
			local state = Simulation.newFlight({ powerId = "Meteor" }, emptyCourse())
			state.powerPhase, state.powerPeak = "diving", peak
			state.y, state.vy, state.vx = 18.01, -64, 60
			Simulation.step(state, emptyCourse(), 1 / 15)
			check(state.alive and state.y > 18 and state.vy > 0 and state.powerPhase == "spent", "Coarse-step Meteor tunneled below the pull-up")
			return state
		end
		local low, high, extreme = blast(40), blast(160), blast(10000)
		check(high.vx > low.vx + 25 and high.vy > low.vy, "Achieved height did not strengthen Meteor")
		check(extreme.vx <= 165 and extreme.vy <= 32, "Meteor strength is unbounded")
	end)

	test("fuel cannot cancel Meteor's committed dive or erase its high-speed burst", function()
		local course = emptyCourse()
		local state = Simulation.newFlight({ powerId = "Meteor" }, course)
		state.powerPhase, state.powerPeak = "diving", 160
		state.y, state.vy, state.vx = 80, -50, 100
		course.items = { item("fuel", state.x, state.y, 1, 20) }
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.pickups == 1 and state.vy < -40 and state.powerPhase == "diving", "Fuel reversed the committed Meteor dive")
		state.y, state.vy = 18.01, -64
		Simulation.step(state, emptyCourse(), Simulation.FIXED_DT)
		local burstSpeed = state.vx
		check(burstSpeed > 130, "Meteor burst was not larger than the legacy fuel cap")
		course.items = { item("fuel", state.x, state.y, 2, 5) }
		Simulation.step(state, course, Simulation.FIXED_DT)
		check(state.pickups == 2 and state.vx >= burstSpeed and state.vx <= 165, "Ordinary fuel erased Meteor's forward kick")
	end)

	test("all powers preserve hard timeouts and finish within bounded generated flights", function()
		for _, powerId in ipairs({ "Pinball", "Muncher", "Meteor" }) do
			local late = Simulation.newFlight({ powerId = powerId }, emptyCourse())
			late.elapsed, late.y, late.vy = Simulation.MAX_FLIGHT_TIME - 0.001, 120, 0
			Simulation.step(late, emptyCourse(), Simulation.FIXED_DT)
			check(not late.alive and late.finishReason == "timeout" and late.powerUses == 0, "Power bypassed the hard timeout")
			for _, variant in ipairs({ "Coast", "Skyline", "Storm" }) do
				for _, angle in ipairs({ 15, 35, 60 }) do
					local settings = { powerId = powerId, planeId = "cruiser", angle = angle }
					local a = run(settings, Simulation.makeCourse(74123, variant))
					local b = run(settings, Simulation.makeCourse(74123, variant))
					check(not a.alive and a.elapsed <= Simulation.MAX_FLIGHT_TIME and a.distance > 0 and a.distance < 7500, "Powered flight escaped round bounds")
					check(a.distance == b.distance and a.powerUses == b.powerUses and a.eventSerial == b.eventSerial, "Powered seeded flight was nondeterministic")
					check(a.vx <= 165 and a.vy == a.vy and a.powerCharges >= 0, "Power velocity or charges were unbounded")
				end
			end
		end
	end)

	test("power bursts fade without surrendering earned distance or fuel momentum", function()
		local course = emptyCourse()
		local boosted = Simulation.newFlight({ powerId = "Muncher" }, course)
		local baseline = Simulation.newFlight({ powerId = "Muncher" }, course)
		boosted.y, boosted.vy = 120, 0
		baseline.y, baseline.vy = 120, 0
		course.items = { item("missile", 0, 120, 1) }
		Simulation.step(boosted, course, Simulation.FIXED_DT)
		Simulation.step(baseline, emptyCourse(), Simulation.FIXED_DT)
		baseline.vy = boosted.vy
		local kick = boosted.vx - baseline.vx
		check(kick > 10, "Power burst lost its immediate kick")
		-- Both pilots collect identical fuel after the kick. Fading the burst
		-- must not subtract that ordinary earned momentum from either flight.
		for _, state in ipairs({ boosted, baseline }) do
			local fuel = emptyCourse()
			fuel.items = { item("fuel", state.x, state.y, 2, 10) }
			Simulation.step(state, fuel, Simulation.FIXED_DT)
		end
		local previousGap = boosted.x - baseline.x
		for _ = 1, 300 do
			Simulation.step(boosted, emptyCourse(), Simulation.FIXED_DT)
			Simulation.step(baseline, emptyCourse(), Simulation.FIXED_DT)
			local gap = boosted.x - baseline.x
			check(boosted.alive and baseline.alive and gap >= previousGap, "Burst decay erased earned distance")
			previousGap = gap
		end
		check(boosted.vx > baseline.vx and boosted.vx - baseline.vx < kick * 0.05, "Burst left a permanent speed advantage")
		check(previousGap > 10 and previousGap < 25, "Brief burst did not earn bounded forward distance")
	end)

	test("fuel at the burst speed cap still earns lasting momentum", function()
		local boosted = Simulation.newFlight({ powerId = "Muncher" }, emptyCourse())
		local baseline = Simulation.newFlight({ powerId = "Muncher" }, emptyCourse())
		boosted.y, boosted.vy, boosted.vx = 120, 0, 100
		baseline.y, baseline.vy, baseline.vx = 120, 0, 100
		local missiles = emptyCourse()
		for id = 1, 3 do table.insert(missiles.items, item("missile", 0, 120, id)) end
		Simulation.step(boosted, missiles, Simulation.FIXED_DT)
		Simulation.step(baseline, emptyCourse(), Simulation.FIXED_DT)
		baseline.vy = boosted.vy
		check(boosted.vx == 125, "Regression setup did not fill the Muncher speed cap")
		for _, state in ipairs({ boosted, baseline }) do
			local fuel = emptyCourse()
			for id = 4, 6 do table.insert(fuel.items, item("fuel", state.x, state.y, id, 20)) end
			Simulation.step(state, fuel, Simulation.FIXED_DT)
		end
		for _ = 1, 300 do
			Simulation.step(boosted, emptyCourse(), Simulation.FIXED_DT)
			Simulation.step(baseline, emptyCourse(), Simulation.FIXED_DT)
			check(boosted.vx >= baseline.vx - 0.0000001 and boosted.distance >= baseline.distance, "Burst cap forfeited fuel momentum after the power faded")
			check(boosted.vx <= 125 and boosted.burstVx >= 0, "Fuel replacement escaped the speed cap")
		end
	end)

	test("headwind follows a shared clock and preserves unspent power charges", function()
		local function fall(elapsed, x, charges)
			local state = Simulation.newFlight({ powerId = "Pinball" }, emptyCourse())
			state.elapsed, state.x, state.y, state.vy, state.powerCharges = elapsed, x, 100, 0, charges
			Simulation.step(state, emptyCourse(), Simulation.FIXED_DT)
			check(state.powerCharges == charges, "Headwind silently consumed a power charge")
			return state.vy
		end
		local early = fall(5, 0, 3)
		local before = fall(Simulation.PRESSURE_START - 1, 900, 3)
		local middle = fall(Simulation.PRESSURE_START + Simulation.PRESSURE_RAMP / 2, 200, 1)
		local leader = fall(Simulation.PRESSURE_START + Simulation.PRESSURE_RAMP / 2, 2200, 3)
		local late = fall(Simulation.PRESSURE_START + Simulation.PRESSURE_RAMP + 1, 0, 0)
		check(close(early, before), "Headwind altered the opening launch")
		check(middle < early and late < middle, "Late pressure did not build gradually")
		check(close(middle, leader), "Headwind depends on race position or remaining power")
	end)

	test("headwind weakens late fuel lift while retaining its forward reward", function()
		local function refuel(elapsed)
			local course = emptyCourse()
			local state = Simulation.newFlight({ powerId = "Muncher" }, course)
			state.elapsed, state.y, state.vy, state.vx = elapsed, 12, -22, 60
			course.items = { item("fuel", 0, 12, 1, 20) }
			Simulation.step(state, course, Simulation.FIXED_DT)
			return state
		end
		local early, late = refuel(5), refuel(Simulation.PRESSURE_START + Simulation.PRESSURE_RAMP)
		check(early.vy > late.vy and late.vy > 0, "Late fuel should give a small save rather than another long climb")
		check(close(early.vx, late.vx) and late.pickups == 1, "Headwind removed the earned forward fuel reward")
	end)

	test("Pinball recoveries shrink and resolve promptly without course contacts", function()
		local state = Simulation.newFlight({ powerId = "Pinball" }, emptyCourse())
		state.y, state.vy = 0.01, -20
		local lastUses, lastLift, firstBounce = 0, math.huge, nil
		for _ = 1, 1500 do
			Simulation.step(state, emptyCourse(), Simulation.FIXED_DT)
			if state.powerUses > lastUses then
				check(state.vy > 0 and state.vy < lastLift, "Successive bounces did not get lower")
				firstBounce = firstBounce or state.elapsed
				lastLift, lastUses = state.vy, state.powerUses
			end
			if not state.alive then break end
		end
		check(not state.alive and state.powerUses == 3 and state.finishReason == "landed", "Compact skips failed to finish after three charges")
		check(state.elapsed - firstBounce < 17, "Three empty-course skips still create a long second flight")
	end)

	return tostring(passed) .. " simulation tests passed"
end
