-- Pure tests: require(thisModule)(BattleSimulation, SkillCatalog, BattleSkills)
-- in Studio or a Lua runtime. The last two are optional.
return function(Simulation, Catalog, Skills)
	local passed = 0
	local function check(value, message) assert(value, message) end
	local function close(a, b) return math.abs(a - b) < 0.0000001 end
	local function test(name, callback)
		local ok, problem = pcall(callback)
		assert(ok, name .. ": " .. tostring(problem))
		passed = passed + 1
	end
	local function equal(a, b)
		if type(a) ~= type(b) then return false end
		if type(a) ~= "table" then return a == b end
		for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
		for key in pairs(b) do if a[key] == nil then return false end end
		return true
	end
	local function run(seed, a, b)
		local state = Simulation.newRound(seed, a, b)
		for _ = 1, math.ceil(Simulation.MAX_TIME / Simulation.FIXED_DT) + 2 do
			Simulation.step(state, Simulation.FIXED_DT)
			if state.finished then return state end
		end
		error("Round exceeded hard limit")
	end
	local function passive(fighter, x, y, heading)
		fighter.x, fighter.y, fighter.heading = x, y, heading or 0
		fighter.vx, fighter.vy = math.cos(fighter.heading) * 30, math.sin(fighter.heading) * 30
		fighter.phase, fighter.phaseLeft, fighter.armed = "Recover", 100, false
		fighter._recoverX = x + math.cos(fighter.heading) * 30
		fighter._recoverY = y + math.sin(fighter.heading) * 30
		fighter._knockX, fighter._knockY = 0, 0
	end
	local function projectile(id, owner, x, y, vx, vy)
		return { id = id, owner = owner, x = x, y = y, vx = vx, vy = vy, life = 2, radius = 3.5 }
	end
	local function armed(fighter, x, heading)
		passive(fighter, x, 50, heading)
		fighter.offenceId = "Meteor"
		fighter.phase, fighter.phaseLeft, fighter.armed = "Attack", 1, true
		fighter._attackHeading, fighter._attackHit = heading, false
	end
	local function wake(id, owner, x, y, armLeft)
		return { id = id, owner = owner, skillId = "FizzyFuel", x = x, y = y, radius = Simulation.WAKE_RADIUS,
			life = Simulation.WAKE_LIFE, maxLife = Simulation.WAKE_LIFE, armLeft = armLeft or 0 }
	end

	test("same seed settings and frame times reproduce entire round", function()
		local a = run(8137, { offenceId = "Meteor", angle = 10 }, { offenceId = "Firework", angle = 55 })
		local b = run(8137, { offenceId = "Meteor", angle = 10 }, { offenceId = "Firework", angle = 55 })
		check(equal(a, b), "Deterministic replay differed")
		check(a.finished and a.eventSerial > 2, "No combat occurred")
	end)

	test("fixed ticks are independent of frame grouping", function()
		local a, b = Simulation.newRound(37), Simulation.newRound(37)
		for _ = 1, 60 do Simulation.step(a, 1 / 60) end
		for _ = 1, 10 do Simulation.step(b, 0.1) end
		check(close(a.elapsed, 1) and close(b.elapsed, 1), "Wrong accumulated time")
		check(equal(a.fighters, b.fighters) and equal(a.events, b.events), "Frame partition changed combat")
	end)

	test("invalid dt is ignored and stalled frames are bounded", function()
		local state = Simulation.newRound(1)
		for _, dt in ipairs({ 0, -1, math.huge, -math.huge, 0 / 0, "1" }) do Simulation.step(state, dt) end
		Simulation.step(state, nil)
		check(state.elapsed == 0, "Invalid time advanced the round")
		Simulation.step(state, 10000)
		check(close(state.elapsed, Simulation.MAX_STEP_DT), "Stalled frame ran unbounded work")
		local partial = Simulation.newRound(1)
		Simulation.step(partial, Simulation.FIXED_DT / 2)
		check(partial.elapsed == 0, "Partial tick advanced")
		Simulation.step(partial, Simulation.FIXED_DT / 2)
		check(close(partial.elapsed, Simulation.FIXED_DT), "Partial ticks were discarded")
	end)

	test("settings are validated copied and bounded", function()
		local input = { offenceId = "Meteor", angle = 999 }
		local state = Simulation.newRound(0 / 0, input, { offenceId = "unknown", angle = math.huge })
		input.angle = 10
		check(state.seed == 1 and state.fighters[1].settings.angle == 55, "Seed or settings ownership failed")
		check(state.fighters[2].offenceId == "Firework" and state.fighters[2].settings.angle == 32, "Fallback failed")
		local other = Simulation.newRound({}, { angle = -99 }, false)
		check(other.fighters[1].settings.angle == 10 and other.fighters[2].armor == 3, "Malformed settings failed")
		check(Simulation.validOffence("Meteor") and Simulation.validOffence("Firework") and not Simulation.validOffence("Paid"), "Offence validation failed")
		check(not Simulation.validOffence("Afterburner") and not Simulation.validWild("Meteor") and not Simulation.validWild({}), "Skill kinds were mixed up")
	end)

	test("passive body contact only bumps", function()
		local state = Simulation.newRound(1)
		passive(state.fighters[1], -3, 50, math.pi)
		passive(state.fighters[2], 3, 50, 0)
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.fighters[1].armor == 3 and state.fighters[2].armor == 3, "Passive collision dealt damage")
		check(state.events[#state.events].kind == "bump", "Body contact lacked feedback")
		check(state.fighters[1]._knockX < 0 and state.fighters[2]._knockX > 0, "Bump did not separate fighters")
	end)

	test("armed frontal strike deals one pip and rear contact does not", function()
		local hit = Simulation.newRound(1)
		armed(hit.fighters[1], -8, 0)
		passive(hit.fighters[2], 0, 50, 0)
		Simulation.step(hit, Simulation.FIXED_DT)
		check(hit.fighters[2].armor == 2 and hit.fighters[1].hits == 1, "Frontal strike failed")
		check(hit.fighters[2].invulnerable > 0 and hit.fighters[1].phase == "Recover", "Hit lacked protection/recovery")
		local back = Simulation.newRound(1)
		armed(back.fighters[1], 5, 0)
		passive(back.fighters[2], 0, 50, 0)
		Simulation.step(back, Simulation.FIXED_DT)
		check(back.fighters[2].armor == 3, "Rear body contact counted as an armed nose")
	end)

	test("projectile sweep catches a target between endpoints", function()
		local state = Simulation.newRound(1)
		passive(state.fighters[1], -55, 50, 0)
		passive(state.fighters[2], 0, 50, 0)
		state.projectiles = { projectile(1, 1, -25, 50, 6000, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.fighters[2].armor == 2 and #state.projectiles == 0, "Swept rocket missed or survived impact")
		check(state.fighters[1].armor == 3 and state.fighters[1].hits == 1, "Wrong rocket attribution")
	end)

	test("projectile ownership excludes its own plane", function()
		local state = Simulation.newRound(1)
		passive(state.fighters[1], 0, 50, 0)
		passive(state.fighters[2], 50, 80, 0)
		state.projectiles = { projectile(1, 1, -20, 50, 1800, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.fighters[1].armor == 3 and state.fighters[2].armor == 3, "Projectile hit its owner")
		check(#state.projectiles == 1, "Projectile consumed itself against owner")
	end)

	test("impact protection blocks stacked hits and consumes rockets", function()
		local state = Simulation.newRound(1)
		passive(state.fighters[1], -55, 50, 0)
		passive(state.fighters[2], 0, 50, 0)
		state.projectiles = { projectile(1, 1, -25, 50, 6000, 0), projectile(2, 1, -25, 50, 6000, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.fighters[2].armor == 2 and state.fighters[1].hits == 1, "Stacked damage bypassed protection")
		check(#state.projectiles == 0, "Blocked rocket remained inside target")
		for _ = 1, 10 do Simulation.step(state, Simulation.FIXED_DT) end
		check(state.fighters[2].armor == 2, "Protection allowed delayed impact damage")
	end)

	test("committed attacks and rockets cannot home", function()
		local state = Simulation.newRound(1)
		armed(state.fighters[1], -40, 0.3)
		passive(state.fighters[2], 40, 80, 0)
		state.projectiles = { projectile(1, 1, -50, 15, 30, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.fighters[1].heading == 0.3, "Committed dive turned toward opponent")
		check(state.projectiles[1].vx == 30 and state.projectiles[1].vy == 0, "Rocket homed after launch")
	end)

	test("dive commitment survives a hit and recovery within one broadcast interval", function()
		local state = Simulation.newRound(1, { offenceId = "Meteor", wildIds = {} })
		passive(state.fighters[1], -8, 50, 0)
		passive(state.fighters[2], 0, 50, 0)
		state.fighters[1].phase, state.fighters[1].phaseLeft = "Windup", 0
		Simulation.step(state, 1 / 20)
		check(state.fighters[1].phase == "Recover" and state.fighters[2].armor == 2, "Fixture did not commit and hit before next snapshot")
		local count, commitment, impact = 0, nil, nil
		for _, entry in ipairs(state.events) do
			if entry.kind == "dive" then count, commitment = count + 1, entry end
			if entry.kind == "hit" then impact = entry end
		end
		check(count == 1 and commitment and impact and commitment.serial < impact.serial, "Commit event missing, duplicated, or out of order")
		check(commitment.actor == 1 and commitment.target == 2 and commitment.source == "meteor", "Wrong dive attribution")
		check(commitment.heading == 0 and commitment.x == -8 and commitment.y == 50, "Commit did not retain its actual origin and heading")
		check(commitment.at <= 1 / 20 and commitment.at == impact.at, "Immediate commit timing changed")
	end)

	test("controlled Meteor charge creates continuous space before a visible landed dive", function()
		local state = Simulation.newRound(731, { offenceId = "Meteor", angle = 32 }, { offenceId = "Firework", angle = 32 })
		-- A placed fixture: the Meteor is about to charge and the rival is held
		-- in an endless slow windup beside it. This measures charge geometry,
		-- not approach timing or who wins the opening.
		local meteor, rival = state.fighters[1], state.fighters[2]
		meteor.x, meteor.y, meteor.heading, meteor.phaseLeft = 0, 50, math.pi, 0.001
		rival.x, rival.y, rival.heading = 38, 50, math.pi
		rival.phase, rival.phaseLeft = "Windup", 100
		local charge, commitment, impact, waypointX, waypointY, previousHeading
		local serial = state.eventSerial
		for _ = 1, 300 do
			local fighter = state.fighters[1]
			local oldX, oldY = fighter.x, fighter.y
			previousHeading = fighter.heading
			Simulation.step(state, Simulation.FIXED_DT)
			for _, entry in ipairs(state.events) do
				if entry.serial > serial and entry.actor == 1 then
					if entry.kind == "windup" then charge = entry end
					if entry.kind == "dive" then commitment = entry end
					if entry.kind == "hit" and entry.source == "meteor" then impact = entry end
				end
			end
			serial = state.eventSerial
			check((fighter.x - oldX) ^ 2 + (fighter.y - oldY) ^ 2 <= (65 * Simulation.FIXED_DT + 0.00001) ^ 2,
				"Charging or release teleported the plane")
			if fighter.phase == "Windup" then
				check(not fighter.armed and fighter.invulnerable == 0, "Charge gained damage or immunity")
				check(fighter.windupDuration == Simulation.METEOR_WINDUP, "Renderer charge duration differs")
				waypointX, waypointY = waypointX or fighter._chargeX, waypointY or fighter._chargeY
				check(fighter._chargeX == waypointX and fighter._chargeY == waypointY, "Backoff waypoint homed during charge")
				local turn = (fighter.heading - previousHeading + math.pi) % (math.pi * 2) - math.pi
				check(math.abs(turn) <= 8 * Simulation.FIXED_DT + 0.00001, "Charge heading snapped")
			end
			if impact then break end
		end
		check(charge and commitment and impact, "Default charge did not finish in a real strike")
		check(close(commitment.at - charge.at, Simulation.METEOR_WINDUP), "Charge duration changed")
		check(impact.at - commitment.at >= 0.25 and impact.at - commitment.at <= 0.9, "Default strike has no visible flight")
		check(math.abs(commitment.x - charge.x) > 20, "Charge failed to create real separation")
		check(state.fighters[2].armor == 2 and state.fighters[1].armor == 3, "Strike changed the one-pip damage rule")
		check(state.fighters[2].attacks == 0, "The held rival attacked")
	end)

	test("Meteor remains vulnerable during the backoff charge", function()
		local state = Simulation.newRound(1)
		local fighter = state.fighters[1]
		passive(fighter, 0, 50, 0)
		fighter.phase, fighter.phaseLeft = "Windup", 0.8
		fighter._chargeX, fighter._chargeY = -40, 80
		passive(state.fighters[2], -40, 50, 0)
		state.projectiles = { projectile(1, 2, -25, 50, 6000, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(fighter.armor == 2 and fighter.phase == "Recover", "Charging Meteor ignored a valid rocket")
		check(not fighter.armed and fighter.attacks == 0, "Interrupted charge still released a dive")
	end)

	test("a committed Meteor can visibly miss and bank without damage", function()
		local state = Simulation.newRound(1)
		armed(state.fighters[1], -40, 0)
		passive(state.fighters[2], 30, 80, 0)
		for _ = 1, 62 do Simulation.step(state, Simulation.FIXED_DT) end
		local missed = false
		for _, entry in ipairs(state.events) do
			if entry.kind == "miss" and entry.actor == 1 then missed = true end
		end
		check(missed and state.fighters[1].phase == "Recover", "Miss lacked normal recovery")
		check(state.fighters[1].hits == 0 and state.fighters[2].armor == 3, "Miss fabricated a hit")
	end)

	test("simultaneous knockout is a draw without player-index priority", function()
		local state = Simulation.newRound(1)
		armed(state.fighters[1], -4, 0)
		armed(state.fighters[2], 4, math.pi)
		state.fighters[1].armor, state.fighters[2].armor = 1, 1
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.finished and state.winner == 0 and state.reason == "knockout", "Double knockout was biased")
		check(state.fighters[1].armor == 0 and state.fighters[2].armor == 0, "One simultaneous hit disappeared")
	end)

	test("pressure visibly shrinks bounds without dealing damage", function()
		local state = Simulation.newRound(1)
		state.elapsed = 16.5
		passive(state.fighters[1], -72, 8, math.pi)
		passive(state.fighters[2], 72, 96, 0)
		Simulation.step(state, Simulation.FIXED_DT)
		check(close(state.pressure, (state.elapsed - Simulation.PRESSURE_START) / (Simulation.REGULATION_TIME - Simulation.PRESSURE_START)), "Pressure timing differs")
		check(close(state.bounds.left, -72 + 24 * state.pressure) and close(state.bounds.top, 96 - 14 * state.pressure), "Rendered bounds contract differs")
		for _, fighter in ipairs(state.fighters) do
			check(fighter.x >= state.bounds.left and fighter.x <= state.bounds.right and fighter.y >= state.bounds.bottom and fighter.y <= state.bounds.top, "Plane escaped pressure")
			check(fighter.armor == 3, "Invisible edge damage")
		end
	end)

	test("regulation time awards higher armor and level armor goes to sudden death", function()
		local state = Simulation.newRound(1)
		state.elapsed = Simulation.REGULATION_TIME - 0.005
		passive(state.fighters[1], -40, 50, math.pi)
		passive(state.fighters[2], 40, 50, 0)
		state.fighters[2].armor = 2
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.finished and state.winner == 1 and state.reason == "timeout", "Regulation did not award the armor lead")
		state = Simulation.newRound(1)
		state.elapsed = Simulation.REGULATION_TIME - 0.005
		passive(state.fighters[1], -40, 50, math.pi)
		passive(state.fighters[2], 40, 50, 0)
		Simulation.step(state, Simulation.FIXED_DT)
		check(not state.finished and state.suddenDeath == true, "Level armor did not start sudden death")
		Simulation.step(state, Simulation.FIXED_DT)
		check(not state.finished, "Sudden death ended without a hit")
		state.fighters[1].armor = 2
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.finished and state.winner == 2 and state.reason == "sudden_death", "The next armor lost did not end sudden death")
	end)

	test("time cap awards higher armor and preserves equal armor draws", function()
		for _, armor in ipairs({ 2, 3 }) do
			local state = Simulation.newRound(1)
			state.elapsed = Simulation.MAX_TIME - 0.005
			state.fighters[2].armor = armor
			Simulation.step(state, Simulation.FIXED_DT)
			check(state.finished and state.elapsed == Simulation.MAX_TIME and state.reason == "timeout", "Hard limit failed")
			check(state.winner == (armor == 3 and 0 or 1), "Armor tiebreak failed")
			local elapsed, serial, x = state.elapsed, state.eventSerial, state.fighters[1].x
			Simulation.step(state, 1)
			check(state.elapsed == elapsed and state.eventSerial == serial and state.fighters[1].x == x, "Finished round changed")
		end
	end)

	test("extreme angles both sides stay finite bounded and finish", function()
		local wins, phases = {}, {}
		for _, power in ipairs({ "Meteor", "Firework" }) do
			for _, a in ipairs({ 10, 32, 55 }) do
				for _, b in ipairs({ 10, 32, 55 }) do
					local state = Simulation.newRound(104729 + a * 7919 + b, { offenceId = power, angle = a },
						{ offenceId = power == "Meteor" and "Firework" or "Meteor", angle = b })
					for _ = 1, 2102 do
						Simulation.step(state, Simulation.FIXED_DT)
						check(#state.events <= 24, "Event history leaked")
						for _, fighter in ipairs(state.fighters) do
							check(fighter.x == fighter.x and fighter.y == fighter.y and math.abs(fighter.vx) < 100 and math.abs(fighter.vy) < 100, "Nonfinite/excessive motion")
							check(fighter.x >= state.bounds.left and fighter.x <= state.bounds.right and fighter.y >= state.bounds.bottom and fighter.y <= state.bounds.top, "Out of bounds")
							check(fighter.armor >= 0 and fighter.armor <= 3, "Armor out of bounds")
							phases[fighter.phase] = true
						end
						if state.finished then break end
					end
					check(state.finished and state.elapsed <= Simulation.MAX_TIME, "Nonterminating match")
					if state.winner ~= 0 then wins[state.fighters[state.winner].offenceId] = true end
					for index = 2, #state.events do check(state.events[index].serial > state.events[index - 1].serial, "Event order changed") end
				end
			end
		end
		check(phases.Approach and phases.Windup and phases.Attack and phases.Recover, "A combat phase never occurred")
		check(wins.Meteor and wins.Firework, "One signature could never win the sample")
	end)

	local function has(fighter, id)
		for _, wildId in ipairs(fighter.wildIds) do if wildId == id then return true end end
		return false
	end
	local WILD = { "Afterburner", "FizzyFuel", "SpringBumper" }
	-- Every way to carry zero, one or two different wild cards.
	local LOADOUTS = { {}, { "Afterburner" }, { "FizzyFuel" }, { "SpringBumper" },
		{ "Afterburner", "FizzyFuel" }, { "Afterburner", "SpringBumper" }, { "FizzyFuel", "SpringBumper" } }

	test("wild cards validate and reset independently each round", function()
		local invalid = Simulation.newRound(1, { wildIds = { "PaidShield", {}, "Meteor" } }, { wildIds = "Afterburner" })
		check(#invalid.fighters[1].wildIds == 0 and #invalid.fighters[2].wildIds == 0, "Invalid wild cards accepted")
		check(invalid.fighters[1].bumperReady == nil, "A skill's private state appeared without the skill")
		for _, id in ipairs(WILD) do
			check(Simulation.validWild(id), "Catalog wild card rejected")
			local first = Simulation.newRound(12, { wildIds = { id } }, { wildIds = { id } })
			first.fighters[1].armor, first.fighters[1].boostLeft, first.fighters[1].bumperReady = 0, 0.8, false
			first.wakes = { wake(1, 1, 0, 50) }
			local nextRound = Simulation.newRound(12, { wildIds = { id } }, { wildIds = { id } })
			check(nextRound.fighters[1].armor == 3 and nextRound.fighters[1].boostLeft == 0 and #nextRound.wakes == 0, "Previous round effects leaked")
			check((nextRound.fighters[1].bumperReady == true) == (id == "SpringBumper"), "Bumper charge did not reset")
			check(nextRound.eventSerial == 2, "Activation events leaked into launch")
		end
	end)

	test("a build keeps at most two different wild cards in a fixed order", function()
		local state = Simulation.newRound(1, { wildIds = { "SpringBumper", "SpringBumper", "Afterburner", "FizzyFuel" } },
			{ wildIds = { "FizzyFuel", "Afterburner" } })
		local a, b = state.fighters[1].wildIds, state.fighters[2].wildIds
		check(#a == 2 and a[1] == "Afterburner" and a[2] == "SpringBumper", "Duplicate or third wild card kept")
		check(#b == 2 and b[1] == "Afterburner" and b[2] == "FizzyFuel", "Pick order leaked into the fight")
		local picked = { wildIds = { "SpringBumper", "FizzyFuel" } }
		local swapped = { wildIds = { "FizzyFuel", "SpringBumper" } }
		check(equal(run(4421, picked, picked), run(4421, swapped, swapped)), "Pick order changed a fight")
		check(#picked.wildIds == 2 and picked.wildIds[1] == "SpringBumper", "Caller's settings were edited")
	end)

	if Catalog and Skills then
		test("catalog and skill behaviour agree and catalog records are detached", function()
			local count = { offence = 0, wild = 0 }
			for _, entry in ipairs(Catalog.all()) do
				count[entry.kind] = count[entry.kind] + 1
				check(Skills[entry.kind][entry.id] ~= nil, "Catalog skill has no behaviour: " .. entry.id)
				check(Simulation.validOffence(entry.id) == (entry.kind == "offence") and
					Simulation.validWild(entry.id) == (entry.kind == "wild"), "Catalog and simulation disagree")
			end
			for kind, total in pairs(count) do
				local behaviours = 0
				for id in pairs(Skills[kind]) do
					behaviours = behaviours + 1
					check(Catalog.valid(id, kind), "Behaviour has no catalog entry: " .. id)
				end
				check(behaviours == total, "Catalog and behaviour counts differ")
			end
			for id, offence in pairs(Skills.offence) do
				for _, field in ipairs({ "windup", "attackTime", "attackSpeed", "earliest", "leadSpeed", "leadFactor" }) do
					check(type(offence[field]) == "number", id .. " lacks " .. field)
				end
			end
			check(Catalog.MAX_WILD == Simulation.MAX_WILD, "Wild card limit differs")
		end)
	end

	test("afterburner starts only after an attack and expires without retriggering", function()
		local state = Simulation.newRound(1, { offenceId = "Firework", wildIds = { "Afterburner" } })
		local fighter = state.fighters[1]
		passive(fighter, -40, 50, 0)
		passive(state.fighters[2], 50, 80, 0)
		Simulation.step(state, Simulation.FIXED_DT)
		check(fighter.boostLeft == 0 and close(math.sqrt(fighter.vx ^ 2 + fighter.vy ^ 2), 30), "Boost appeared without attacking")
		fighter.phase, fighter.phaseLeft = "Windup", 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(fighter.phase == "Attack" and fighter.boostLeft == 0, "Boost altered committed attack")
		fighter.phaseLeft = 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(fighter.phase == "Recover" and fighter.boostLeft > 0, "Attack did not trigger recovery boost")
		check(close(math.sqrt(fighter.vx ^ 2 + fighter.vy ^ 2), 56), "Boost did not change recovery speed")
		local activations = 0
		for _, entry in ipairs(state.events) do
			if entry.kind == "skill" and entry.skillId == "Afterburner" then activations = activations + 1 end
		end
		check(activations == 1, "Boost activation duplicated")
		for _ = 1, 60 do Simulation.step(state, Simulation.FIXED_DT) end
		check(fighter.boostLeft == 0 and fighter.phase == "Recover", "Boost did not expire during recovery")
		check(close(math.sqrt(fighter.vx ^ 2 + fighter.vy ^ 2), 30), "Boost speed persisted")
	end)

	test("spring bumper ignores passive or protected contact and blocks one valid strike", function()
		local state = Simulation.newRound(1, nil, { wildIds = { "SpringBumper" } })
		passive(state.fighters[1], -3, 50, math.pi)
		passive(state.fighters[2], 3, 50, 0)
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.fighters[2].bumperReady, "Passive bump spent the bumper")
		armed(state.fighters[1], -8, 0)
		passive(state.fighters[2], 0, 50, 0)
		state.fighters[2].invulnerable = 0.2
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.fighters[2].bumperReady and state.fighters[2].armor == 3, "Protected contact spent the bumper")
		armed(state.fighters[1], -8, 0)
		passive(state.fighters[2], 0, 50, 0)
		state.fighters[2].invulnerable = 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(not state.fighters[2].bumperReady and state.fighters[2].armor == 3, "Bumper did not absorb strike")
		check(state.fighters[1].hits == 0 and state.fighters[1].phase == "Recover", "Blocked strike counted as armor damage")
		check(state.fighters[1]._knockX < 0 and state.fighters[2]._knockX > 0, "Bumper failed to separate planes")
		local entry = state.events[#state.events]
		check(entry.kind == "blocked" and entry.actor == 2 and entry.target == 1 and entry.source == "meteor", "Block attribution differs")
		state.fighters[2].invulnerable = 0
		state.projectiles = { projectile(7, 1, -25, state.fighters[2].y, 6000, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.fighters[2].armor == 2, "Spent bumper blocked a second hit")
	end)

	test("spring bumper consumes a rocket without reporting armor loss", function()
		local state = Simulation.newRound(1, nil, { wildIds = { "SpringBumper" } })
		passive(state.fighters[1], -55, 50, 0)
		passive(state.fighters[2], 0, 50, 0)
		state.projectiles = { projectile(1, 1, -25, 50, 6000, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(#state.projectiles == 0 and state.fighters[2].armor == 3, "Bumper rocket resolution failed")
		local entry = state.events[#state.events]
		check(entry.kind == "blocked" and entry.source == "rocket" and entry.at == state.elapsed, "Blocked rocket has wrong feedback")
	end)

	test("fizzy wake starts at commitment and visibly arms before damage", function()
		local state = Simulation.newRound(1, { offenceId = "Firework", wildIds = { "FizzyFuel" } })
		local fighter = state.fighters[1]
		passive(fighter, -40, 50, 0)
		passive(state.fighters[2], 50, 80, 0)
		Simulation.step(state, Simulation.FIXED_DT)
		check(#state.wakes == 0, "Wake emitted outside attack")
		fighter.phase, fighter.phaseLeft = "Windup", 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(#state.wakes == 1 and state.wakes[1].x < fighter.x, "Attack did not leave a wake behind")
		check(state.wakes[1].armLeft > 0 and state.wakes[1].radius == Skills.wild.FizzyFuel.cloudRadius
			and state.wakes[1].life > 2, "Cloud lacks visible arming, size or hang time")
		local emitted = state._wakeSerial
		fighter.phaseLeft = 0
		for _ = 1, 12 do Simulation.step(state, Simulation.FIXED_DT) end
		check(fighter.phase == "Recover" and state._wakeSerial > emitted, "An early attack ending truncated its promised wake")
		local contact = Simulation.newRound(1)
		passive(contact.fighters[1], -55, 50, 0)
		passive(contact.fighters[2], 0, 50, 0)
		contact.wakes = { wake(1, 1, 0, 50, Simulation.WAKE_ARM_TIME) }
		for _ = 1, 3 do Simulation.step(contact, Simulation.FIXED_DT) end
		check(contact.fighters[2].armor == 3, "Wake damaged before its cue armed")
		for _ = 1, math.ceil(Simulation.WAKE_ARM_TIME / Simulation.FIXED_DT) do
			-- Hold contact for this timer unit case; live avoidance is sampled separately.
			passive(contact.fighters[2], 0, 50, 0)
			Simulation.step(contact, Simulation.FIXED_DT)
		end
		check(contact.fighters[2].armor == 2 and #contact.wakes == 0, "Armed wake failed contact resolution")
		local count = 0
		for _, entry in ipairs(contact.events) do
			if entry.kind == "wake_hit" then count = count + 1 end
			check(entry.kind ~= "hit", "Wake duplicated its hit event")
		end
		check(count == 1, "Wake damage feedback duplicated or missing")
	end)

	test("Spring Bumper trades its full block for visible defender recoil", function()
		local state = Simulation.newRound(1, nil, { wildIds = { "SpringBumper" } })
		armed(state.fighters[1], -8, 0); passive(state.fighters[2], 0, 50, 0)
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.fighters[2].armor == 3 and not state.fighters[2].bumperReady, "Recoil weakened the promised full block")
		check(close(state.fighters[2].phaseLeft, Simulation.RECOVERY_TIME + Skills.wild.SpringBumper.recoil), "Defender did not take visible extra recovery")
		check(close(state.fighters[1].phaseLeft, Simulation.RECOVERY_TIME), "Attacker inherited defender recoil")
	end)

	test("wake ownership protection and bumper interactions are consistent", function()
		local owner = Simulation.newRound(1)
		passive(owner.fighters[1], 0, 50, 0)
		passive(owner.fighters[2], 50, 80, 0)
		owner.wakes = { wake(1, 1, 0, 50) }
		Simulation.step(owner, Simulation.FIXED_DT)
		check(owner.fighters[1].armor == 3 and #owner.wakes == 1, "Wake hit its owner")
		for _, modifier in ipairs({ "None", "SpringBumper" }) do
			local state = Simulation.newRound(1, nil, { wildIds = { modifier } })
			passive(state.fighters[1], -55, 50, 0)
			passive(state.fighters[2], 0, 50, 0)
			state.wakes = { wake(1, 1, 0, 50), wake(2, 1, 0, 50) }
			Simulation.step(state, Simulation.FIXED_DT)
			check(state.fighters[2].armor == (modifier == "None" and 2 or 3), "Wake bypassed bumper/protection")
			check(#state.wakes == 0, "Overlapping wake remained inside protected plane")
			if modifier == "SpringBumper" then
				local entry = state.events[#state.events]
				check(not state.fighters[2].bumperReady and entry.kind == "blocked" and entry.source == "wake", "Wake did not consume bumper visibly")
			end
		end
	end)

	test("wake instances are bounded and expire after emission stops", function()
		local state = Simulation.newRound(1, { wildIds = { "FizzyFuel" } }, { wildIds = { "FizzyFuel" } })
		for _ = 1, 180 do
			for id, fighter in ipairs(state.fighters) do
				passive(fighter, 0, id == 1 and 80 or 20, id == 1 and 0 or math.pi)
				fighter.phase, fighter.phaseLeft, fighter._attackHeading = "Attack", 100, fighter.heading
				fighter.armed, fighter._wakeLeft = false, 100
			end
			Simulation.step(state, Simulation.FIXED_DT)
			check(#state.wakes <= Simulation.MAX_WAKES, "Wake instance count leaked")
			local owned = { 0, 0 }
			for _, entry in ipairs(state.wakes) do owned[entry.owner] = owned[entry.owner] + 1 end
			check(owned[1] <= 6 and owned[2] <= 6, "One plane exhausted the shared wake budget")
		end
		for id, fighter in ipairs(state.fighters) do
			passive(fighter, id == 1 and -50 or 50, 50, id == 1 and math.pi or 0)
			fighter._wakeLeft = 0
		end
		for _ = 1, math.ceil(Skills.wild.FizzyFuel.cloudLife / Simulation.FIXED_DT) + 2 do Simulation.step(state, Simulation.FIXED_DT) end
		check(#state.wakes == 0, "Expired wake persisted")
	end)

	test("afterburner and fizzy fuel both fire from one attack", function()
		local state = Simulation.newRound(1, { offenceId = "Firework", wildIds = { "FizzyFuel", "Afterburner" } })
		local fighter = state.fighters[1]
		passive(fighter, -40, 50, 0)
		passive(state.fighters[2], 50, 80, 0)
		fighter.phase, fighter.phaseLeft = "Windup", 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(fighter.phase == "Attack" and #state.wakes == 1 and fighter.boostLeft == 0, "Wake or boost timing changed when paired")
		fighter.phaseLeft = 0
		for _ = 1, 12 do Simulation.step(state, Simulation.FIXED_DT) end
		check(fighter.phase == "Recover" and fighter.boostLeft > 0 and state._wakeSerial > 1, "Paired wild cards did not both run")
		check(close(math.sqrt(fighter.vx ^ 2 + fighter.vy ^ 2), 56), "Boost speed lost when paired with a wake")
	end)

	test("spring bumper still blocks once beside another wild card", function()
		for _, partner in ipairs({ "Afterburner", "FizzyFuel" }) do
			local state = Simulation.newRound(1, nil, { wildIds = { partner, "SpringBumper" } })
			armed(state.fighters[1], -8, 0)
			passive(state.fighters[2], 0, 50, 0)
			Simulation.step(state, Simulation.FIXED_DT)
			check(not state.fighters[2].bumperReady and state.fighters[2].armor == 3, "Paired bumper did not absorb: " .. partner)
			local entry = state.events[#state.events]
			check(entry.kind == "blocked" and entry.skillId == "SpringBumper", "Paired block lacks feedback")
			state.fighters[2].invulnerable = 0
			state.projectiles = { projectile(7, 1, -25, state.fighters[2].y, 6000, 0) }
			Simulation.step(state, Simulation.FIXED_DT)
			check(state.fighters[2].armor == 2, "Paired bumper blocked twice: " .. partner)
		end
	end)

	test("a bumper carrier's own wake and boost are untouched by its block", function()
		local state = Simulation.newRound(1, { offenceId = "Firework", wildIds = { "Afterburner", "SpringBumper" } },
			{ wildIds = { "FizzyFuel", "SpringBumper" } })
		passive(state.fighters[1], -55, 50, 0)
		passive(state.fighters[2], 0, 50, 0)
		state.wakes = { wake(1, 2, -55, 50) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.fighters[1].armor == 3 and not state.fighters[1].bumperReady, "Bumper did not stop a rival wake")
		check(state.fighters[2].bumperReady and #state.wakes == 0, "Wake owner lost its own bumper or kept the puff")
	end)

	test("every loadout pair is deterministic bounded and terminates", function()
		for _, a in ipairs(LOADOUTS) do
			for _, b in ipairs(LOADOUTS) do
				local settingsA, settingsB = { offenceId = "Meteor", wildIds = a, angle = 10 }, { offenceId = "Firework", wildIds = b, angle = 55 }
				local first, second = run(91273, settingsA, settingsB), run(91273, settingsA, settingsB)
				local label = table.concat(a, "+") .. "/" .. table.concat(b, "+")
				check(equal(first, second), "Loadout replay differed: " .. label)
				check(#first.wakes <= Simulation.MAX_WAKES and first.elapsed <= Simulation.MAX_TIME, "Loadout lifecycle escaped bounds")
				for id, fighter in ipairs(first.fighters) do
					check(has(fighter, "SpringBumper") == (fighter.bumperReady ~= nil), "Bumper state on the wrong plane")
					check(#fighter.wildIds == #(id == 1 and a or b), "Loadout changed during the fight")
				end
				for _, entry in ipairs(first.events) do check(type(entry.at) == "number" and entry.at <= first.elapsed, "Event timestamp missing") end
			end
		end
	end)


	test("Machine Gun requires three connections and caps a burst at one pip", function()
		local state = Simulation.newRound(1, { offenceId = "MachineGun" })
		local actor = state.fighters[1]
		passive(actor, -55, 50, 0); passive(state.fighters[2], 0, 50, 0)
		actor.attacks, actor.burstConnections, actor.burstCancelled, actor._burstDamaged = 1, 0, false, false
		local function bullet(id)
			local shot = projectile(id, 1, -25, state.fighters[2].y, 6000, 0)
			shot.source, shot.burstId = "machinegun", 1
			return shot
		end
		state.projectiles = { bullet(1), bullet(2) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.fighters[2].armor == 3 and actor.burstConnections == 2, "Stray tracers dealt a pip")
		state.projectiles = { bullet(3), bullet(4), bullet(5), bullet(6) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.fighters[2].armor == 2 and actor.hits == 1 and actor._burstDamaged, "Burst threshold or cap failed")
		check(#state.projectiles == 0, "Contacting tracers leaked")
	end)

	test("bumper cancels an entire burst and protection preserves the bumper", function()
		for _, protected in ipairs({ false, true }) do
			local state = Simulation.newRound(1, { offenceId = "MachineGun" }, { wildIds = { "SpringBumper" } })
			local actor, target = state.fighters[1], state.fighters[2]
			passive(actor, -55, 50, 0); passive(target, 0, 50, 0)
			actor.attacks, actor.burstConnections, actor.burstCancelled = 1, 0, false
			target.invulnerable = protected and 1 or 0
			local shot = projectile(1, 1, -25, 50, 6000, 0)
			shot.source, shot.burstId = "machinegun", 1
			state.projectiles = { shot }; Simulation.step(state, Simulation.FIXED_DT)
			check(actor.burstCancelled and target.bumperReady == protected and target.armor == 3, "Wrong defense precedence")
			target.invulnerable = 0
			for id = 2, 6 do
				local nextShot = projectile(id, 1, -25, target.y, 6000, 0)
				nextShot.source, nextShot.burstId = "machinegun", 1
				state.projectiles[#state.projectiles + 1] = nextShot
			end
			Simulation.step(state, Simulation.FIXED_DT)
			check(target.armor == 3 and actor.burstConnections == 0, "Cancelled burst resumed after protection")
		end
	end)

	test("Pinball fires a ball that banks off a wall and never rams", function()
		local state = Simulation.newRound(1, { offenceId = "Pinball" })
		local actor, rival = state.fighters[1], state.fighters[2]
		passive(actor, -40, 50, math.pi); passive(rival, 40, 50, 0)
		rival.vx, rival.vy, rival._recoverX, rival._recoverY = 0, 0, 40, 50
		actor.phase, actor.phaseLeft = "Approach", 0.001
		local launched, bounced, hit
		for _ = 1, 240 do
			passive(rival, 40, 50, 0); rival.vx, rival.vy = 0, 0
			Simulation.step(state, Simulation.FIXED_DT)
			check(not actor.armed, "Pinball armed the plane's nose")
			for _, entry in ipairs(state.events) do
				if entry.kind == "ricochet" then launched = entry end
				if entry.kind == "bounce" and entry.source == "pinball" then bounced = bounced or entry end
				if entry.kind == "hit" and entry.source == "pinball" then hit = entry end
			end
			if hit then break end
		end
		check(launched and launched.actor == 1 and launched.skillId == "Pinball", "Launch lacks its authoritative cue")
		check(bounced and close(bounced.x, Simulation.ARENA.left), "The ball did not bank off the nearest wall")
		check(hit and bounced.serial < hit.serial and rival.armor == 2, "The banked ball did not land after its bounce")
		check(#state.projectiles == 0, "A ball that hit kept flying")
	end)

	test("a bouncing ball reflects a set number of times and then leaves", function()
		local state = Simulation.newRound(1)
		passive(state.fighters[1], -50, 20, 0); passive(state.fighters[2], 50, 20, 0)
		local ball = projectile(1, 1, 0, 80, 0, 300)
		ball.bounces, ball.life, ball.source = 2, 10, "pinball"
		state.projectiles = { ball }
		local bounces, missed = 0, false
		local serial = state.eventSerial
		for _ = 1, 120 do
			passive(state.fighters[1], -50, 20, 0); passive(state.fighters[2], 50, 20, 0)
			Simulation.step(state, Simulation.FIXED_DT)
			for _, entry in ipairs(state.events) do
				if entry.serial > serial then
					serial = entry.serial
					if entry.kind == "bounce" then bounces = bounces + 1 end
					if entry.kind == "miss" then missed = true end
				end
			end
			for _, live in ipairs(state.projectiles) do
				check(live.y <= state.bounds.top + 0.001 and live.y >= state.bounds.bottom - 0.001 or live.bounces == 0, "A live bounce left the arena")
			end
		end
		check(bounces == 2 and missed and #state.projectiles == 0, "Bounce count was not honoured")
	end)

	test("Second Wind triggers once at one armor without healing including simultaneous hits", function()
		local state = Simulation.newRound(1, { wildIds = { "SecondWind" } }, { wildIds = { "SecondWind" } })
		armed(state.fighters[1], -4, 0); armed(state.fighters[2], 4, math.pi)
		state.fighters[1].armor, state.fighters[2].armor = 2, 2
		Simulation.step(state, Simulation.FIXED_DT)
		for _, fighter in ipairs(state.fighters) do
			check(fighter.armor == 1 and fighter.secondWind, "Simultaneous last-armor trigger failed")
			check(close(fighter.phaseLeft, Simulation.RECOVERY_TIME * 0.88), "Trigger did not shorten same-step recovery")
		end
		local triggers = 0
		for _, entry in ipairs(state.events) do if entry.skillId == "SecondWind" then triggers = triggers + 1 end end
		check(triggers == 2, "Second Wind trigger duplicated or missing")
	end)

	test("Magnet yanks only the rival toward its owner", function()
		local state = Simulation.newRound(1, { wildIds = { "Magnet" } }, {})
		passive(state.fighters[1], -25, 50, math.pi); passive(state.fighters[2], 25, 50, 0)
		state.fighters[1].magnetLeft = 0.5
		Simulation.step(state, Simulation.FIXED_DT)
		check(close(state.fighters[1].vx, -30), "The magnet moved its own plane")
		check(close(state.fighters[2].vx, 30 - Simulation.MAGNET_SPEED), "The rival was not yanked toward the magnet")
		check(Simulation.MAGNET_SPEED >= 12 and Simulation.MAGNET_SHOT_SPEED > Simulation.MAGNET_SPEED, "The yank is too gentle to see")
		-- With a shot in the air the rival is dragged toward the shot, not the plane.
		local shot = Simulation.newRound(1, { wildIds = { "Magnet" } }, {})
		passive(shot.fighters[1], -25, 50, math.pi); passive(shot.fighters[2], 25, 50, 0)
		shot.fighters[2].vx, shot.fighters[2]._recoverX, shot.fighters[2]._recoverY = 0, 25, 50
		shot.fighters[1].magnetLeft = 0.5
		shot.projectiles = { projectile(1, 1, 25, 85, 0, 0) }
		Simulation.step(shot, Simulation.FIXED_DT)
		check(shot.fighters[2].vy > Simulation.MAGNET_SHOT_SPEED * 0.9, "The rival was not dragged toward the shot in the air")
		local both = Simulation.newRound(1, { wildIds = { "Magnet" } }, { wildIds = { "Magnet" } })
		passive(both.fighters[1], -25, 50, math.pi); passive(both.fighters[2], 25, 50, 0)
		both.fighters[1].magnetLeft, both.fighters[2].magnetLeft = 0.5, 0.5
		Simulation.step(both, Simulation.FIXED_DT)
		check(close(both.fighters[1].vx, -both.fighters[2].vx), "Two magnets did not pull evenly")
		local attack = Simulation.newRound(1, { offenceId = "Firework", wildIds = { "Magnet" } })
		passive(attack.fighters[1], -40, 50, 0); passive(attack.fighters[2], 40, 80, 0)
		attack.fighters[1].phase, attack.fighters[1].phaseLeft = "Windup", 0
		Simulation.step(attack, Simulation.FIXED_DT)
		check(close(attack.fighters[1].magnetLeft, Skills.wild.Magnet.duration), "The yank did not start with the attack")
	end)

	test("Afterburner shortens only the trip after its owner's own attack", function()
		local state = Simulation.newRound(1, { offenceId = "Firework", wildIds = { "Afterburner" } }, { offenceId = "Firework" })
		local actor, rival = state.fighters[1], state.fighters[2]
		passive(actor, -40, 50, 0); passive(rival, 40, 80, 0)
		actor.phase, actor.phaseLeft = "Windup", 0
		Simulation.step(state, Simulation.FIXED_DT)
		actor.phaseLeft = 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(actor.phase == "Recover" and actor.tempo == Skills.wild.Afterburner.tempo, "Attacking did not start the rush")
		check(close(actor.phaseLeft, Simulation.RECOVERY_TIME * actor.tempo), "The rush did not shorten the bank away")
		check(rival.tempo == nil, "The rival was hurried too")
		actor.phase, actor.phaseLeft = "Approach", 0
		passive(rival, 40, 80, 0)
		Simulation.step(state, Simulation.FIXED_DT)
		check(actor.phase == "Windup" and actor.tempo == nil, "The rush outlived one trip")
	end)

	test("final total speed caps knockback plus Second Wind and Afterburner", function()
		local state = Simulation.newRound(1, { wildIds = { "Afterburner", "SecondWind" } })
		local actor = state.fighters[1]
		passive(actor, 0, 50, 0); passive(state.fighters[2], 50, 80, 0)
		actor.boostLeft, actor.secondWind, actor._knockX, actor._knockY = 1, true, 200, 200
		Simulation.step(state, Simulation.FIXED_DT)
		check(math.sqrt(actor.vx ^ 2 + actor.vy ^ 2) <= Simulation.MAX_TOTAL_SPEED + 0.00001, "Stacked force escaped total speed cap")
	end)

	test("ram and projectile same-step knockout resolve together", function()
		for _, seat in ipairs({ 1, 2 }) do
			local state = Simulation.newRound(1)
			armed(state.fighters[seat], -4, 0); passive(state.fighters[3 - seat], 4, 50, math.pi)
			state.fighters[1].armor, state.fighters[2].armor = 1, 1
			state.projectiles = { projectile(1, 3 - seat, 20, 50, -6000, 0) }
			Simulation.step(state, Simulation.FIXED_DT)
			check(state.finished and state.winner == 0 and state.fighters[1].armor == 0 and state.fighters[2].armor == 0, "Attack category or seat decided double KO")
		end
	end)

	test("every active offence can attack and is deterministic inside the round cap", function()
		for _, entry in ipairs(Catalog.all("offence")) do
			local config = { offenceId = entry.id, wildIds = { "Magnet", "SecondWind" }, angle = 32 }
			local first, second = run(71391, config, config), run(71391, config, config)
			check(equal(first, second) and first.elapsed <= 35, "Roster replay/cap failed: " .. entry.id)
			check(first.fighters[1].attacks > 0 and first.fighters[2].attacks > 0, "Automatic pilot never attacks: " .. entry.id)
		end
	end)

	test("planes with nothing loaded circle each other and never touch", function()
		for _, seed in ipairs({ 104729, 112648, 9973131, 20261010 }) do
			for _, offence in ipairs({ "Firework", "MachineGun", "Pinball" }) do
				local state = Simulation.newRound(seed, { offenceId = offence, angle = 32 }, { offenceId = offence, angle = 32 })
				state.fighters[1].phaseLeft, state.fighters[2].phaseLeft = 100, 100
				local nearest, farthest = math.huge, 0
				for tick = 1, 360 do
					Simulation.step(state, Simulation.FIXED_DT)
					local a, b = state.fighters[1], state.fighters[2]
					local distance = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
					nearest = math.min(nearest, distance)
					if tick > 180 then farthest = math.max(farthest, distance) end
					check(a.circling and b.circling and a.phase == "Approach", "A waiting plane stopped circling")
				end
				check(nearest > Simulation.PLANE_RADIUS * 2 + 2, offence .. " planes touched while waiting, seed " .. seed)
				check(farthest < 70, offence .. " planes drifted apart instead of circling, seed " .. seed)
				for _, entry in ipairs(state.events) do check(entry.kind ~= "bump", "Waiting planes bumped") end
			end
		end
	end)

	test("each plane gets its own seeded opening timing", function()
		local different = 0
		for seed = 1, 40 do
			local state = Simulation.newRound(seed * 104729, { offenceId = "Firework" }, { offenceId = "Firework" })
			local again = Simulation.newRound(seed * 104729, { offenceId = "Firework" }, { offenceId = "Firework" })
			local a, b = state.fighters[1].phaseLeft, state.fighters[2].phaseLeft
			check(a == again.fighters[1].phaseLeft and b == again.fighters[2].phaseLeft, "Opening timing is not repeatable")
			check(a >= 1.8 - 0.000001 and a <= 4.2 + 0.000001 and b >= 1.8 - 0.000001 and b <= 4.2 + 0.000001, "Opening timing left its range")
			if math.abs(a - b) > 0.2 then different = different + 1 end
		end
		check(different >= 25, "Both planes share one opening timing, so the same attack always strikes first")
	end)

	test("colliding just after a hit is not announced as a new bump", function()
		local state = Simulation.newRound(1)
		passive(state.fighters[1], 0, 50, 0)
		passive(state.fighters[2], 8, 50, math.pi)
		state.fighters[2].invulnerable = 0.5
		local serial = state.eventSerial
		Simulation.step(state, Simulation.FIXED_DT)
		for _, entry in ipairs(state.events) do
			check(entry.serial <= serial or entry.kind ~= "bump", "A protected plane announced a bump")
		end
		check(state.fighters[1]._knockX < 0 and state.fighters[2]._knockX > 0, "Tangled planes were not pushed apart")
	end)

	return string.format("BattleSimulation: %d tests passed (determinism, fixed ticks, collisions, protection, endings, wild cards, wakes)", passed)
end
