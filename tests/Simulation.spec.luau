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
		local state = Simulation.newFlight({ angle = math.huge, power = 0 / 0, gadget = "PaidPower" }, course)
		check(state.settings.angle == 35 and state.settings.power == 75 and state.gadget == "Shield", "Settings defaults failed")
		local capped = Simulation.newFlight({ angle = 9999, power = -9999 }, course)
		check(capped.settings.angle == 60 and capped.settings.power == 45, "Input clamps failed")
		Simulation.step(state, course, 0 / 0)
		Simulation.step(state, course, -1)
		check(state.elapsed == 0, "Invalid timestep advanced flight")
	end)

	test("all angle power and gadget extremes finish safely", function()
		for _, variant in ipairs({ "Coast", "Skyline", "Storm" }) do
			for _, angle in ipairs({ 15, 35, 60 }) do
				for _, power in ipairs({ 45, 75, 100 }) do
					for _, gadget in ipairs({ "Shield", "Magnet", "Boost" }) do
						local state = run({ angle = angle, power = power, gadget = gadget }, Simulation.makeCourse(12345, variant))
						check(state.distance > 0 and state.distance < 5000 and state.elapsed <= Simulation.MAX_FLIGHT_TIME, "Invalid extreme result")
						check(state.x == state.x and state.y == state.y, "NaN in flight")
					end
				end
			end
		end
	end)

	test("launch settings change outcome", function()
		local course = Simulation.makeCourse(98123, "Coast")
		local low = run({ angle = 15, power = 45, gadget = "Shield" }, course)
		local high = run({ angle = 60, power = 100, gadget = "Shield" }, course)
		check(math.abs(low.distance - high.distance) > 10, "Launch settings had no meaningful effect")
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

	return tostring(passed) .. " simulation tests passed"
end
