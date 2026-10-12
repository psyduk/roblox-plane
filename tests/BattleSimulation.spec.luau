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
	-- A fixture top stands where it is put and has no move of its own coming.
	local function place(top, x, y, vx, vy)
		top.x, top.y, top.vx, top.vy = x, y, vx or 0, vy or 0
		top.phase, top.phaseLeft, top.stun, top.moveLeft = "Roam", 0, 0, 1000
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
	local TOPS = { "Boulder", "Bolt", "Cyclone", "Pogo" }
	local UPGRADES = { "Heavy", "Spikes", "Turbo", "Claws", "Bumper", "Jetpack" }

	test("a round starts with two tops on opposite sides of the ring", function()
		local state = Simulation.newRound(7)
		local a, b = state.fighters[1], state.fighters[2]
		check(a.offenceId == "Boulder" and b.offenceId == "Bolt", "Defaults changed")
		check(a.x < 0 and b.x > 0 and centre(a) < state.ring and centre(b) < state.ring, "Tops do not start inside the ring")
		check(state.ring == Simulation.RING_RADIUS and state.heat == 1 and not state.finished, "Round does not start fresh")
		check(#state.events == 2 and state.events[1].kind == "launch", "Launch events missing")
	end)

	test("the same seed and builds always play out the same way", function()
		for _, seed in ipairs({ 1, 99, 4242 }) do
			local first = run(seed, { offenceId = "Cyclone", wildIds = { "Spikes" } }, { offenceId = "Pogo", wildIds = { "Bumper" } })
			local second = run(seed, { offenceId = "Cyclone", wildIds = { "Spikes" } }, { offenceId = "Pogo", wildIds = { "Bumper" } })
			check(first.winner == second.winner and first.elapsed == second.elapsed, "Replay diverged")
			check(first.fighters[1].x == second.fighters[1].x and first.fighters[2].y == second.fighters[2].y, "Positions diverged")
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
			check(entry.kind ~= "wild" or Simulation.validWild(entry.id), entry.id .. " is not a usable upgrade")
		end
		for id in pairs(Skills.offence) do check(Catalog.valid(id, "offence"), id .. " is missing from the catalog") end
		for id in pairs(Skills.wild) do check(Catalog.valid(id, "wild"), id .. " is missing from the catalog") end
	end)

	test("builds are cleaned: unknown tops fall back, upgrades are unique, sorted and capped", function()
		local state = Simulation.newRound(3, { offenceId = "Meteor", wildIds = { "Turbo", "Nope", "Turbo", "Heavy", "Spikes" } }, { offenceId = "Pogo", wildIds = "bad" })
		local a, b = state.fighters[1], state.fighters[2]
		check(a.offenceId == "Boulder" and b.offenceId == "Pogo", "Fallback top is wrong")
		check(#a.wildIds == 2 and a.wildIds[1] == "Heavy" and a.wildIds[2] == "Turbo", "Upgrades not cleaned")
		check(#b.wildIds == 0, "A bad upgrade list was kept")
		local swapped = Simulation.newRound(3, { offenceId = "Boulder", wildIds = { "Heavy", "Turbo" } })
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

	test("a top whose centre leaves the ring loses the round", function()
		local state = Simulation.newRound(9, { offenceId = "Boulder" }, { offenceId = "Boulder" })
		place(state.fighters[1], 0, 0)
		place(state.fighters[2], state.ring - 0.5, 0, 60, 0)
		state.fighters[2].stun = 1
		Simulation.step(state, DT)
		check(state.finished and state.winner == 1 and state.reason == "ringout", "Ring-out not adjudicated")
		check(state.fighters[2].out and state.fighters[2].phase == "Out" and not state.fighters[1].out, "Wrong top marked out")
		local fall = seen(state, "ringout")
		check(fall and fall.target == 2 and fall.actor == 1 and seen(state, "finish").actor == 1, "Ring-out events are wrong")
	end)

	test("two tops leaving on the same tick draw", function()
		local state = Simulation.newRound(9, { offenceId = "Bolt" }, { offenceId = "Bolt" })
		place(state.fighters[1], -(state.ring - 0.5), 0, -60, 0)
		place(state.fighters[2], state.ring - 0.5, 0, 60, 0)
		state.fighters[1].stun, state.fighters[2].stun = 1, 1
		Simulation.step(state, DT)
		check(state.finished and state.winner == 0 and state.reason == "ringout", "Double ring-out is not a draw")
		check(state.fighters[1].out and state.fighters[2].out, "Both tops should be out")
	end)

	test("the ring closes after its grace time and every round ends", function()
		local state = Simulation.newRound(21)
		for _ = 1, math.floor(Simulation.SHRINK_START / DT) - 2 do
			Simulation.step(state, DT)
			if state.finished then break end
		end
		check(state.finished or (state.ring == Simulation.RING_RADIUS and state.pressure == 0), "Ring closed early")
		local longest = 0
		for index, top in ipairs(TOPS) do
			for seed = 1, 12 do
				local done = run(seed * 977 + index, { offenceId = top }, { offenceId = TOPS[(index + seed) % #TOPS + 1] })
				check(done.finished and done.elapsed <= Simulation.MAX_TIME + DT, "Round overran")
				check(done.ring <= Simulation.RING_RADIUS and done.ring >= Simulation.RING_END - 1e-6, "Ring left its limits")
				for _, fighter in ipairs(done.fighters) do
					check(fighter.x == fighter.x and fighter.y == fighter.y and math.abs(fighter.x) < 1e4, "Position is not finite")
				end
				longest = math.max(longest, done.elapsed)
			end
		end
		check(longest > 6, "Every sampled round ended at once")
	end)

	test("a round still going at the limit goes to the top nearer the middle", function()
		local state = Simulation.newRound(4)
		place(state.fighters[1], 10, 0)
		place(state.fighters[2], -4, 3)
		Simulation.expire(state)
		check(state.finished and state.winner == 2 and state.reason == "timeout", "Nearer top did not win")
		local level = Simulation.newRound(4)
		place(level.fighters[1], 6, 0)
		place(level.fighters[2], 0, -6)
		Simulation.expire(level)
		check(level.winner == 0, "Level tops should draw")
		Simulation.expire(state)
		check(state.winner == 2, "Expiring twice changed the result")
	end)

	test("a touch throws both tops apart and the lighter one further", function()
		steady(function()
			local state = Simulation.newRound(8, { offenceId = "Boulder" }, { offenceId = "Bolt" })
			local heavy, light = state.fighters[1], state.fighters[2]
			place(heavy, -4.5, 0, 12, 0)
			place(light, 4.5, 0, -12, 0)
			Simulation.step(state, DT)
			check(heavy.vx < 0 and light.vx > 0, "Tops were not thrown apart")
			check(light.vx > -heavy.vx * 1.3, "The lighter top was not thrown further")
			local hit = seen(state, "clash")
			check(hit and hit.actor == 1 and hit.target == 2 and hit.power > 0, "Touch was not credited to the top that held its ground")
			check(heavy.hits == 1 and light.hits == 0 and light.stun > 0, "Hit bookkeeping is wrong")
		end)
	end)

	test("a faster top kicks harder", function()
		steady(function()
			local function thrown(closing)
				local state = Simulation.newRound(8, { offenceId = "Cyclone" }, { offenceId = "Cyclone" })
				place(state.fighters[1], -4.4, 0, closing, 0)
				place(state.fighters[2], 4.4, 0)
				Simulation.step(state, DT)
				return state.fighters[2].vx
			end
			check(thrown(60) > thrown(15) + 15, "Speed did not add to the throw")
		end)
	end)

	test("upgrades change the numbers they promise", function()
		local function top(...)
			return Simulation.newRound(2, { offenceId = "Cyclone", wildIds = { ... } }).fighters[1]
		end
		local bare = top()
		check(top("Heavy").mass > bare.mass * 1.05 and top("Heavy").radius > bare.radius, "Heavy Core adds no weight")
		check(top("Spikes").kick > bare.kick * 1.1, "Spikes add no kick")
		check(top("Turbo").cruise > bare.cruise * 1.1 and top("Turbo").moveEvery < bare.moveEvery, "Turbo adds no speed")
		check(top("Claws").claws and top("Bumper").bumperReady and top("Jetpack").jetReady, "A switch upgrade is not armed")
		check(not bare.claws and not bare.bumperReady and not bare.jetReady, "A bare top has upgrades")
	end)

	test("Spring Bumper bounces the first hit back, once", function()
		steady(function()
			local state = Simulation.newRound(8, { offenceId = "Bolt" }, { offenceId = "Bolt", wildIds = { "Bumper" } })
			local striker, shield = state.fighters[1], state.fighters[2]
			place(striker, -3.9, 0, 30, 0)
			place(shield, 3.9, 0)
			Simulation.step(state, DT)
			check(speed(shield) < 1 and striker.vx < -10, "The bumper did not send the hit back")
			check(shield.bumperReady == false, "The bumper was not spent")
			local blocked = seen(state, "blocked")
			check(blocked and blocked.actor == 2 and blocked.target == 1 and blocked.skillId == "Bumper", "No blocked event")
			place(striker, shield.x - 7.9, shield.y, 30, 0)
			state._clashCool = 0
			Simulation.step(state, DT)
			check(shield.vx > 10, "A spent bumper blocked again")
		end)
	end)

	test("Jetpack flies a fallen top back onto the ring, once", function()
		local state = Simulation.newRound(9, { offenceId = "Boulder", wildIds = { "Jetpack" } }, { offenceId = "Boulder" })
		local flyer = state.fighters[1]
		place(state.fighters[2], 0, 0)
		place(flyer, -(state.ring - 0.5), 0, -60, 0)
		flyer.stun = 1
		Simulation.step(state, DT)
		check(not state.finished and flyer.phase == "Air" and flyer.flying == "jet" and flyer.jetReady == false, "Jetpack did not fire")
		check(seen(state, "revive").actor == 1, "No revive event")
		for _ = 1, math.ceil(Simulation.JET_TIME / DT) + 2 do Simulation.step(state, DT) end
		check(not flyer.out and flyer.z == 0 and flyer.flying == nil and centre(flyer) < state.ring * 0.8, "Flyer did not land back on the ring")
		place(flyer, -(state.ring - 0.5), 0, -60, 0)
		flyer.stun = 1
		Simulation.step(state, DT)
		check(state.finished and state.winner == 2, "An empty jetpack saved a second fall")
	end)

	test("Claws brake a slide toward the edge", function()
		local function slide(...)
			local state = Simulation.newRound(6, { offenceId = "Bolt", wildIds = { ... } }, { offenceId = "Boulder" })
			local top = state.fighters[1]
			place(state.fighters[2], 0, 30)
			place(top, -26, 0, -22, 0)
			top.stun = 1
			local clawing = false
			for _ = 1, 24 do
				Simulation.step(state, DT)
				clawing = clawing or top.clawing
			end
			return -top.vx, clawing
		end
		local bare = slide()
		local gripped, clawing = slide("Claws")
		check(gripped < bare * 0.85, "Claws did not slow the slide")
		check(clawing == true, "Claws do not report digging in")
	end)

	test("Bolt stops, aims, and dashes in a straight line", function()
		local state = Simulation.newRound(6, { offenceId = "Bolt" }, { offenceId = "Boulder" })
		local bolt, rival = state.fighters[1], state.fighters[2]
		place(rival, 20, 10)
		place(bolt, -15, 0)
		bolt.moveLeft = 0
		Simulation.step(state, DT)
		check(bolt.phase == "Windup" and seen(state, "windup").source == "dash", "Bolt did not start charging")
		-- A hit while charging throws the top but does not cancel the charge.
		bolt.stun = 0.1
		for _ = 1, math.ceil((bolt.move.windup + 0.1) / DT) + 1 do
			place(rival, 20, 10)
			Simulation.step(state, DT)
			if bolt.phase == "Attack" then break end
		end
		check(bolt.phase == "Attack" and seen(state, "attack").source == "dash", "Charge did not become a dash")
		Simulation.step(state, DT)
		check(math.abs(speed(bolt) - bolt.move.speed) < 0.5, "Dash is not at dash speed")
		check(bolt.vx > 0 and bolt.vy > 0, "Dash is not toward the rival")
	end)

	test("Pogo cannot be touched in the air and lands with a shockwave", function()
		steady(function()
			local state = Simulation.newRound(6, { offenceId = "Pogo" }, { offenceId = "Bolt" })
			local pogo, rival = state.fighters[1], state.fighters[2]
			place(rival, 6, 0)
			place(pogo, -18, 0)
			pogo.moveLeft = 0
			local airborne = false
			for _ = 1, math.ceil((pogo.move.windup + pogo.move.time) / DT) + 4 do
				place(rival, 6, 0)
				Simulation.step(state, DT)
				if pogo.phase == "Air" then
					airborne = true
					check(pogo.z >= 0 and pogo.flying == "jump", "Jump has no height")
				end
				if seen(state, "slam") then break end
			end
			check(airborne and seen(state, "slam") ~= nil and pogo.z == 0, "Pogo did not jump and land")
			check(centre(pogo) <= state.ring, "Pogo landed off the ring")
			local hit = seen(state, "clash")
			check(hit and hit.source == "slam" and hit.actor == 1 and hit.target == 2, "Shockwave did not hit the rival beside it")
			check(speed(rival) > 15, "Shockwave did not throw the rival")
			-- Passing through a rival in the air is not a touch.
			local over = Simulation.newRound(6, { offenceId = "Pogo" }, { offenceId = "Bolt" })
			local jumper = over.fighters[1]
			place(over.fighters[2], 0, 0)
			place(jumper, 1, 0)
			jumper.phase, jumper.phaseLeft, jumper._airTime, jumper._airHeight = "Air", 0.5, 0.7, 18
			jumper._fromX, jumper._fromY, jumper.lockX, jumper.lockY = -10, 0, 12, 0
			Simulation.step(over, DT)
			check(seen(over, "clash") == nil and over.fighters[2].stun == 0, "An airborne top was touched")
		end)
	end)

	test("a top that nearly falls and gets back had a close call", function()
		local state = Simulation.newRound(6, { offenceId = "Boulder" }, { offenceId = "Boulder" })
		local top = state.fighters[1]
		place(state.fighters[2], 12, 12)
		place(top, -(state.ring - 1), 0, 40, 0)
		for _ = 1, 40 do
			Simulation.step(state, DT)
			if seen(state, "close") then break end
		end
		local close = seen(state, "close")
		check(close and close.actor == 1 and top.closeCalls == 1, "No close call recorded")
	end)

	test("seats are fair and rounds are a watchable length", function()
		local lengths, wins, draws, rounds = {}, 0, 0, 0
		for index, top in ipairs(TOPS) do
			for seed = 1, 30 do
				local done = run(seed * 7919 + index * 13, { offenceId = top }, { offenceId = top })
				rounds = rounds + 1
				lengths[#lengths + 1] = done.elapsed
				if done.winner == 1 then wins = wins + 1 elseif done.winner == 0 then draws = draws + 1 end
			end
		end
		table.sort(lengths)
		local median = lengths[math.ceil(#lengths / 2)]
		check(wins / rounds > 0.36 and wins / rounds < 0.64, "Mirror matches favour a seat: " .. tostring(wins / rounds))
		check(draws / rounds < 0.08, "Too many drawn rounds: " .. tostring(draws / rounds))
		check(median > 7 and median < 20, "Median round length is off: " .. tostring(median))
	end)

	test("every upgrade works on every top without breaking a round", function()
		for index, top in ipairs(TOPS) do
			for other, upgrade in ipairs(UPGRADES) do
				local done = run(index * 101 + other * 7, { offenceId = top, wildIds = { upgrade, UPGRADES[other % #UPGRADES + 1] } },
					{ offenceId = TOPS[(index + other) % #TOPS + 1], wildIds = { upgrade } })
				check(done.finished and (done.winner == 0 or done.winner == 1 or done.winner == 2), "Round did not resolve")
			end
		end
	end)

	return passed .. " battle simulation tests passed"
end
