-- Pure tests: require(thisModule)(BattleSimulation, SkillCatalog, BattleSkills)
-- in Studio or a Lua runtime. The last two are optional.
return function(Simulation, Catalog, Skills)
	local passed = 0
	local DT = Simulation.FIXED_DT
	local function check(value, message) assert(value, message) end
	local function test(name, callback)
		local ok, problem = pcall(callback)
		assert(ok, name .. ": " .. tostring(problem))
		passed = passed + 1
	end
	local function run(seed, a, b)
		local state = Simulation.newRound(seed, a, b)
		for _ = 1, math.ceil(Simulation.MAX_TIME / DT) + 2 do
			Simulation.step(state, DT)
			if state.finished then return state end
		end
		error("Round exceeded hard limit")
	end
	-- Puts a top somewhere with a velocity of the test's choosing.
	local function place(top, x, y, vx, vy)
		top.x, top.y, top.vx, top.vy = x, y, vx or 0, vy or 0
		top.heading = (vx or 0) < 0 and math.pi or 0
	end
	local function seen(state, kind)
		for _, event in ipairs(state.events) do
			if event.kind == kind then return event end
		end
		return nil
	end
	local function speed(top) return math.sqrt(top.vx * top.vx + top.vy * top.vy) end
	local function centre(top) return math.sqrt(top.x * top.x + top.y * top.y) end
	-- Luck is part of every touch; tests that measure a throw switch it off.
	local function steady(callback)
		local luck = Simulation.LUCK
		Simulation.LUCK = 0
		local ok, problem = pcall(callback)
		Simulation.LUCK = luck
		assert(ok, problem)
	end
	local TOPS = { "Bolt", "Cyclone", "Boulder", "Drifter" }
	local PARTS = { "Heavy", "Spikes", "Turbo", "Guard", "Flywheel", "LeftSpin" }
	local R = Simulation.RING_RADIUS

	test("a round starts with two tops on opposite sides of the bowl at full spin", function()
		local state = Simulation.newRound(7)
		local a, b = state.fighters[1], state.fighters[2]
		check(a.offenceId == "Bolt" and b.offenceId == "Cyclone", "Defaults changed")
		check(a.x < 0 and b.x > 0 and centre(a) < R and centre(b) < R, "Tops do not start inside the bowl")
		check(a.spin == a.spinMax and b.spin == Simulation.SPIN and a.turn == 1, "Tops do not start at full spin")
		check(speed(a) > 10 and speed(b) > 10 and not state.finished, "Tops are not launched")
		check(#state.events == 2 and state.events[1].kind == "launch", "Launch events missing")
	end)

	test("the same seed and builds always play out the same way", function()
		for _, seed in ipairs({ 1, 99, 4242 }) do
			local first = run(seed, { offenceId = "Cyclone", wildIds = { "Spikes" } }, { offenceId = "Drifter", wildIds = { "LeftSpin" } })
			local second = run(seed, { offenceId = "Cyclone", wildIds = { "Spikes" } }, { offenceId = "Drifter", wildIds = { "LeftSpin" } })
			check(first.winner == second.winner and first.elapsed == second.elapsed, "Replay diverged")
			check(first.fighters[1].x == second.fighters[1].x and first.fighters[2].spin == second.fighters[2].spin, "State diverged")
		end
		local one, other = run(11, { offenceId = "Bolt" }, { offenceId = "Bolt" }), run(12, { offenceId = "Bolt" }, { offenceId = "Bolt" })
		check(one.elapsed ~= other.elapsed or one.fighters[1].x ~= other.fighters[1].x, "Seed changes nothing")
	end)

	test("every catalog entry has rules and every rule has a catalog entry", function()
		if not Catalog or not Skills then return end
		for _, entry in ipairs(Catalog.all()) do
			local rules = entry.kind == "offence" and Skills.offence[entry.id] or Skills.wild[entry.id]
			check(rules ~= nil, entry.id .. " has no rules")
			check(entry.kind ~= "offence" or Simulation.validOffence(entry.id), entry.id .. " is not a usable top")
			check(entry.kind ~= "wild" or Simulation.validWild(entry.id), entry.id .. " is not a usable part")
		end
		for id in pairs(Skills.offence) do check(Catalog.valid(id, "offence"), id .. " is missing from the catalog") end
		for id in pairs(Skills.wild) do check(Catalog.valid(id, "wild"), id .. " is missing from the catalog") end
	end)

	test("builds are cleaned: unknown tops fall back, parts are unique, sorted and capped", function()
		local state = Simulation.newRound(3, { offenceId = "Meteor", wildIds = { "Turbo", "Nope", "Turbo", "Heavy", "Spikes" } }, { offenceId = "Drifter", wildIds = "bad" })
		local a, b = state.fighters[1], state.fighters[2]
		check(a.offenceId == "Bolt" and b.offenceId == "Drifter", "Fallback top is wrong")
		check(#a.wildIds == 2 and a.wildIds[1] == "Heavy" and a.wildIds[2] == "Turbo", "Parts not cleaned")
		check(#b.wildIds == 0, "A bad part list was kept")
		local swapped = Simulation.newRound(3, { offenceId = "Bolt", wildIds = { "Heavy", "Turbo" } })
		check(swapped.fighters[1].mass == a.mass and swapped.fighters[1].cruise == a.cruise, "Pick order changed the top")
	end)

	test("step consumes fixed ticks, bounds a stalled caller and stops at the end", function()
		local state = Simulation.newRound(5)
		Simulation.step(state, DT * 0.4)
		check(state.elapsed == 0, "A partial tick advanced the round")
		Simulation.step(state, DT * 0.7)
		check(math.abs(state.elapsed - DT) < 1e-9, "Accumulated time did not make one tick")
		Simulation.step(state, 50)
		check(state.elapsed <= DT + Simulation.MAX_STEP_DT + DT, "A stalled caller skipped ahead")
		Simulation.step(state, -1); Simulation.step(state, 0 / 0)
		local done = run(5)
		local at = done.elapsed
		Simulation.step(done, 1)
		check(done.elapsed == at, "A finished round kept running")
	end)

	test("nobody steers: a top curves round the bowl on its own and loses spin as it goes", function()
		local state = Simulation.newRound(4, { offenceId = "Bolt" }, { offenceId = "Cyclone" })
		local bolt, other = state.fighters[1], state.fighters[2]
		local first = bolt.heading
		local turned, furthest = 0, 0
		for _ = 1, 90 do
			-- Keep the rival out of the way so nothing touches.
			place(other, 0, -R + 6)
			local before = bolt.heading
			Simulation.step(state, DT)
			turned = turned + math.abs((bolt.heading - before + math.pi) % (2 * math.pi) - math.pi)
			furthest = math.max(furthest, centre(bolt))
			if state.finished then break end
		end
		check(turned > 1.5, "The path did not bend: " .. tostring(turned) .. " from " .. tostring(first))
		check(furthest <= R and not state.finished, "A top under its own power left the bowl")
		check(bolt.spin < bolt.spinMax - 3 and other.spin < other.spinMax, "Spin does not run down")
		check(bolt.spinMax - bolt.spin > other.spinMax - other.spin, "A grippy tip should burn spin faster than a needle")
	end)

	test("the wall turns a top back", function()
		local state = Simulation.newRound(9, { offenceId = "Boulder" }, { offenceId = "Boulder" })
		local top = state.fighters[1]
		place(state.fighters[2], 0, 0)
		check(not Simulation.gapAt(0), "This test needs wall at angle 0")
		place(top, R - top.radius - 0.2, 0, 50, 0)
		local before = top.spin
		Simulation.step(state, DT)
		check(not state.finished and top.vx < 0 and centre(top) <= R - top.radius + 1e-6, "The wall did not turn the top back")
		check(-top.vx < 50 and top.spin < before, "The wall cost nothing")
		local bump = seen(state, "wall")
		check(bump and bump.actor == 1 and bump.power > 30 and top.wallHits == 1, "No wall event")
	end)

	test("a thrown top goes out through a gap, a top under its own power does not", function()
		local gap = Simulation.GAPS[1]
		local gx, gy = math.cos(gap), math.sin(gap)
		local state = Simulation.newRound(9, { offenceId = "Cyclone" }, { offenceId = "Cyclone" })
		local top = state.fighters[2]
		place(state.fighters[1], 0, -10)
		place(top, gx * (R - 0.4), gy * (R - 0.4), gx * 60, gy * 60)
		Simulation.step(state, DT)
		check(state.finished and state.winner == 1 and state.reason == "ringout" and top.out, "A thrown top did not go out")
		local fall = seen(state, "ringout")
		check(fall and fall.target == 2 and fall.actor == 1 and seen(state, "finish").actor == 1, "Ring-out events are wrong")
		local calm = Simulation.newRound(9, { offenceId = "Bolt" }, { offenceId = "Cyclone" })
		local rider = calm.fighters[1]
		place(calm.fighters[2], 0, -10)
		place(rider, gx * (R - rider.radius), gy * (R - rider.radius), gx * rider.cruise, gy * rider.cruise)
		for _ = 1, 20 do Simulation.step(calm, DT) end
		check(not calm.finished and not rider.out, "A top left the bowl under its own power")
	end)

	test("the gaps favour neither seat, and two tops out on the same tick draw", function()
		for step = 0, 62 do
			local angle = step / 10
			check(Simulation.gapAt(angle) == Simulation.gapAt(math.pi - angle), "The gaps are not mirrored at " .. angle)
		end
		local state = Simulation.newRound(9, { offenceId = "Bolt" }, { offenceId = "Bolt" })
		for index, top in ipairs(state.fighters) do
			local angle = Simulation.GAPS[index + 1]
			place(top, math.cos(angle) * (R - 0.4), math.sin(angle) * (R - 0.4), math.cos(angle) * 60, math.sin(angle) * 60)
		end
		Simulation.step(state, DT)
		check(state.finished and state.winner == 0 and state.reason == "ringout", "Double ring-out is not a draw")
	end)

	test("a top that runs out of spin falls over and loses", function()
		local state = Simulation.newRound(9, { offenceId = "Bolt" }, { offenceId = "Cyclone" })
		place(state.fighters[1], -10, 0); place(state.fighters[2], 10, 0)
		state.fighters[1].spin = 0.01
		Simulation.step(state, DT)
		check(state.finished and state.winner == 2 and state.reason == "spinout", "Spin-out not adjudicated")
		check(state.fighters[1].down and state.fighters[1].spin == 0 and not state.fighters[2].down, "Wrong top fell")
		check(seen(state, "spinout").target == 1, "No spinout event")
		local both = Simulation.newRound(9, { offenceId = "Bolt" }, { offenceId = "Bolt" })
		place(both.fighters[1], -10, 0); place(both.fighters[2], 10, 0)
		both.fighters[1].spin, both.fighters[2].spin = 0.001, 0.02
		Simulation.step(both, DT)
		check(both.winner == 2 and not both.fighters[2].down, "The top with more spin left should outlast the other")
	end)

	test("a round still going at the limit goes to the top with more spin left", function()
		local state = Simulation.newRound(4)
		state.fighters[1].spin, state.fighters[2].spin = 30, 45
		Simulation.expire(state)
		check(state.finished and state.winner == 2 and state.reason == "timeout", "More spin did not win")
		local level = Simulation.newRound(4, { offenceId = "Bolt" }, { offenceId = "Bolt", wildIds = { "Flywheel" } })
		level.fighters[1].spin, level.fighters[2].spin = 50, level.fighters[2].spinMax / 2
		Simulation.expire(level)
		check(level.winner == 0, "Equal shares of spin should draw")
		Simulation.expire(state)
		check(state.winner == 2, "Expiring twice changed the result")
	end)

	-- Two tops meeting head-on in the middle of the bowl; returns both after the touch.
	local function touch(a, b, closing, prepare)
		local state = Simulation.newRound(8, a, b)
		local left, right = state.fighters[1], state.fighters[2]
		place(left, -left.radius + 0.1, 0, closing or 12, 0)
		place(right, right.radius - 0.1, 0, -(closing or 12), 0)
		if prepare then prepare(left, right) end
		Simulation.step(state, DT)
		return left, right, state
	end

	test("a touch throws both tops apart, sideways too, and the lighter one further", function()
		steady(function()
			local heavy, light, state = touch({ offenceId = "Boulder" }, { offenceId = "Bolt" })
			check(heavy.vx < 0 and light.vx > 0, "Tops were not thrown apart")
			check(light.vx > -heavy.vx * 1.3, "The lighter top was not thrown further")
			check(math.abs(light.vy) > 2 and heavy.vy * light.vy < 0, "Spinning rims gave no sideways throw")
			local hit = seen(state, "clash")
			check(hit and hit.actor == 1 and hit.target == 2 and hit.power > 0 and hit.source == "smash", "Touch was not credited to the top that held its ground")
			check(heavy.hits == 1 and light.hits == 0, "Hit bookkeeping is wrong")
			check(heavy.spin < heavy.spinMax - 1 and light.spin < light.spinMax - 1, "A touch cost no spin")
		end)
	end)

	test("same spins smash, opposite spins grind and even out", function()
		steady(function()
			local _, same = touch({ offenceId = "Drifter" }, { offenceId = "Drifter" })
			local _, opposite, state = touch({ offenceId = "Drifter" }, { offenceId = "Drifter", wildIds = { "LeftSpin" } })
			check(opposite.turn == -1, "Left Spin does not turn the top the other way")
			check(same.vx > opposite.vx + 8, "Opposite spins should throw much less: " .. same.vx .. " against " .. opposite.vx)
			check(seen(state, "clash").source == "grind", "An opposite-spin touch was not a grind")
			local fast, slow = touch({ offenceId = "Drifter" }, { offenceId = "Drifter", wildIds = { "LeftSpin" } }, 12, function(a, b)
				a.spin, b.spin = 90, 30
			end)
			check(slow.spin > 31 and fast.spin < 88, "The slower top did not take spin from the faster one")
			local keeps, loses = touch({ offenceId = "Drifter" }, { offenceId = "Drifter" }, 12, function(a, b)
				a.spin, b.spin = 90, 30
			end)
			check(loses.spin < 30 and keeps.spin < 90, "Same spins should not share spin")
		end)
	end)

	test("a top with little spin left is thrown further than the one that hit it", function()
		steady(function()
			local full, tired = touch({ offenceId = "Cyclone" }, { offenceId = "Cyclone" }, 12, function(a, b)
				a.spin, b.spin = a.spinMax, 15
			end)
			check(tired.vx > -full.vx * 1.4, "Low spin did not make the top easier to throw")
		end)
	end)

	test("parts change the numbers they promise", function()
		local function top(...)
			return Simulation.newRound(2, { offenceId = "Drifter", wildIds = { ... } }).fighters[1]
		end
		local bare = top()
		check(top("Heavy").mass > bare.mass * 1.05, "Metal Weight adds no weight")
		check(top("Spikes").bite > bare.bite * 1.1, "Jagged Rim adds no bite")
		check(top("Turbo").cruise > bare.cruise * 1.05 and top("Turbo").brake > bare.brake * 1.2, "Rubber Tip adds no speed or grip")
		check(top("Guard").guard < bare.guard * 0.97, "Free-Spin Guard soaks nothing up")
		check(top("Flywheel").spinMax > bare.spinMax * 1.02 and top("Flywheel").spin == top("Flywheel").spinMax and top("Flywheel").decay < bare.decay, "Flywheel adds no spin")
		check(top("LeftSpin").turn == -1 and bare.turn == 1, "Left Spin does not reverse the top")
		steady(function()
			local _, plain = touch({ offenceId = "Drifter" }, { offenceId = "Drifter" })
			local _, guarded = touch({ offenceId = "Drifter" }, { offenceId = "Drifter", wildIds = { "Guard" } })
			local _, bitten = touch({ offenceId = "Drifter", wildIds = { "Spikes" } }, { offenceId = "Drifter" })
			check(guarded.vx < plain.vx and guarded.spin > plain.spin, "A guard took the full hit")
			check(bitten.spin < plain.spin and bitten.vx > plain.vx, "A jagged rim hit no harder")
		end)
	end)

	test("seats are fair and rounds are a watchable length", function()
		local lengths, wins, draws, rounds, outs = {}, 0, 0, 0, 0
		for index, top in ipairs(TOPS) do
			for seed = 1, 30 do
				local done = run(seed * 7919 + index * 13, { offenceId = top }, { offenceId = top })
				rounds = rounds + 1
				lengths[#lengths + 1] = done.elapsed
				if done.winner == 1 then wins = wins + 1 elseif done.winner == 0 then draws = draws + 1 end
				if done.reason == "ringout" then outs = outs + 1 end
				for _, fighter in ipairs(done.fighters) do
					check(fighter.x == fighter.x and math.abs(fighter.x) < 1e4 and fighter.spin >= 0, "State is not finite")
				end
			end
		end
		table.sort(lengths)
		local median = lengths[math.ceil(#lengths / 2)]
		check(wins / rounds > 0.36 and wins / rounds < 0.64, "Mirror matches favour a seat: " .. tostring(wins / rounds))
		check(draws / rounds < 0.08, "Too many drawn rounds: " .. tostring(draws / rounds))
		check(median > 7 and median < 24 and lengths[#lengths] <= Simulation.MAX_TIME + DT, "Round length is off: " .. tostring(median))
		check(outs > 0 and outs < rounds, "Rounds should end both ways: " .. tostring(outs) .. " of " .. tostring(rounds))
	end)

	test("every part works on every top without breaking a round", function()
		for index, top in ipairs(TOPS) do
			for other, part in ipairs(PARTS) do
				local done = run(index * 101 + other * 7, { offenceId = top, wildIds = { part, PARTS[other % #PARTS + 1] } },
					{ offenceId = TOPS[(index + other) % #TOPS + 1], wildIds = { part } })
				check(done.finished and (done.winner == 0 or done.winner == 1 or done.winner == 2), "Round did not resolve")
			end
		end
	end)

	return passed .. " battle simulation tests passed"
end
