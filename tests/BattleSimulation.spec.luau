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
		-- A fixture plane holds its course: it has no roll to spend.
		fighter.dodgeLeft, fighter.dodgeCool = 0, 100
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
		-- A placed fixture: the Meteor is about to charge and the rival flies a
		-- steady course beside it with no roll to spend. This measures charge geometry,
		-- not approach timing or who wins the opening.
		local meteor, rival = state.fighters[1], state.fighters[2]
		meteor.x, meteor.y, meteor.heading, meteor.phaseLeft = 0, 50, math.pi, 0.001
		passive(rival, 30, 60, -math.pi / 2)
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
			check((fighter.x - oldX) ^ 2 + (fighter.y - oldY) ^ 2 <= (Skills.offence.Meteor.attackSpeed * Simulation.FIXED_DT + 0.00001) ^ 2,
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
		check(impact.at - commitment.at >= 0.25 and impact.at - commitment.at <= 0.9, "Default strike has no visible flight " .. (impact.at - commitment.at))
		check(math.abs(commitment.x - charge.x) > 20, "Charge failed to create real separation")
		check(state.fighters[2].armor == 2 and state.fighters[1].armor == 3, "Strike changed the one-pip damage rule")
		check(state.fighters[2].attacks == 0, "The held rival attacked")
	end)

	test("a hit during the backoff charge hurts and delays the Meteor without cancelling it", function()
		local state = Simulation.newRound(1)
		local fighter = state.fighters[1]
		passive(fighter, 0, 50, 0)
		fighter.phase, fighter.phaseLeft = "Windup", 0.8
		fighter._chargeX, fighter._chargeY = -40, 80
		passive(state.fighters[2], -40, 50, 0)
		state.projectiles = { projectile(1, 2, -25, 50, 6000, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(fighter.armor == 2, "Charging Meteor ignored a valid rocket")
		check(fighter.phase == "Windup" and close(fighter.phaseLeft, 0.8 - Simulation.FIXED_DT + Simulation.STAGGER), "The hit did not delay the charge by its stagger")
		check(not fighter.armed and fighter.attacks == 0, "The struck charge released early")
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
		check(fighter.boostLeft == 0, "Boost did not expire")
		check(math.sqrt(fighter.vx ^ 2 + fighter.vy ^ 2) <= 30.00001, "Boost speed persisted")
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
			and state.wakes[1].life > 1, "Cloud lacks visible arming, size or hang time")
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
		check(close(actor.phaseLeft, Simulation.RECOVERY_TIME * actor.tempo * state.rush) and state.rush < 1, "The rush did not shorten the bank away")
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
			local base, spread = Skills.offence.Firework.approachTime, Simulation.CADENCE_SPREAD
			check(a >= base - spread - 0.000001 and a <= base + spread + 0.000001 and b >= base - spread - 0.000001 and b <= base + spread + 0.000001, "Opening timing left its range")
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

	-- A rocket placed just short of this point on fighter 2's side, flying into it.
	local function shoot(state, x, y)
		state.projectiles[#state.projectiles + 1] = { id = 900 + #state.projectiles, owner = 1, x = x - 4, y = y, vx = 60, vy = 0, life = 1, radius = 3.5 }
		Simulation.step(state, Simulation.FIXED_DT)
	end
	local function said(state, kind, skillId)
		for _, entry in ipairs(state.events) do
			if entry.kind == kind and (skillId == nil or entry.skillId == skillId) then return entry end
		end
	end

	test("Squadron flies one plane per armor and every plane shoots and can be shot", function()
		local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "Squadron" } }, { offenceId = "Firework", wildIds = { "Squadron" } })
		local a, b = state.fighters[1], state.fighters[2]
		check(a.squad == 3 and a.armor == 3 and a.radius < Simulation.PLANE_RADIUS, "Squadron did not make three small planes")
		passive(a, -40, 50, 0); passive(b, 30, 50, 0)
		a.phase, a.phaseLeft, a.windupDuration = "Windup", 0, 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(#state.projectiles == 3, "Three planes did not fire three rockets")
		local seen = {}
		for _, shot in ipairs(state.projectiles) do seen[math.floor(shot.y + 0.5)] = true end
		local rows = 0
		for _ in pairs(seen) do rows = rows + 1 end
		check(rows == 3, "The rockets did not leave from three different planes")
		state.projectiles = {}
		passive(a, -40, 50, 0); passive(b, 30, 50, 0)
		-- A wingman sits behind and above the leader; a shot there is a hit.
		shoot(state, 21, 58)
		check(b.armor == 2, "A wingman could not be shot")
		passive(b, 30, 50, 0); b.invulnerable = 0
		-- With two planes left, the second wingman's place is empty sky.
		shoot(state, 21, 42)
		check(b.armor == 2, "An empty wing position was hit")
	end)

	test("Giant is bigger, tougher and slower, and fires bigger shots", function()
		local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "Giant" } }, { offenceId = "Firework" })
		local a = state.fighters[1]
		check(a.armor == 3 + Skills.wild.Giant.armor and a.maxArmor == a.armor and a.radius > Simulation.PLANE_RADIUS * 1.5, "Giant was not giant")
		passive(a, -40, 50, 0); passive(state.fighters[2], 40, 80, 0)
		a.phase, a.phaseLeft, a.windupDuration = "Windup", 0, 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(#state.projectiles == 1 and state.projectiles[1].radius > 3.5 * 1.5, "Giant fired a normal rocket")
		local plain = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework" })
		for _ = 1, 30 do Simulation.step(state, Simulation.FIXED_DT); Simulation.step(plain, Simulation.FIXED_DT) end
		local function pace(f) return math.sqrt((f.vx - f._knockX) ^ 2 + (f.vy - f._knockY) ^ 2) end
		check(pace(state.fighters[1]) < pace(plain.fighters[1]) * 0.9 or state.fighters[1].phase ~= plain.fighters[1].phase, "Giant was not slower")
	end)

	test("Vampire starts hungry and steals armor with every hit, but never as a pilot", function()
		local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "Vampire" } }, { offenceId = "Firework" })
		local a, b = state.fighters[1], state.fighters[2]
		check(a.armor == 2 and a.maxArmor == 3, "Vampire did not start one armor down")
		passive(a, -40, 80, 0); passive(b, 30, 50, 0)
		shoot(state, 30, 50)
		check(b.armor == 2 and a.armor == 3 and said(state, "skill", "Vampire"), "A hit did not steal armor")
		a.ejected = true; passive(b, 30, 50, 0); b.invulnerable = 0
		shoot(state, 30, 50)
		check(b.armor == 1 and a.armor == 3, "A parachuting pilot was healed")
	end)

	test("Chicken stops the rival attacking for three seconds, once", function()
		local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "Chicken" } }, { offenceId = "Firework" })
		local a, b = state.fighters[1], state.fighters[2]
		passive(a, -40, 80, 0); passive(b, 30, 50, 0)
		b.phase, b.phaseLeft = "Windup", 0.05
		shoot(state, 30, 50)
		check(b.chickenLeft and b.chickenLeft > 2.9 and said(state, "skill", "Chicken"), "The first hit made no chicken")
		local attacks = b.attacks
		for _ = 1, math.floor(2.9 / Simulation.FIXED_DT) do
			Simulation.step(state, Simulation.FIXED_DT)
			check(b.phase == "Approach" and not b.armed, "A chicken wound up an attack")
		end
		check(b.attacks == attacks, "A chicken attacked")
		for _ = 1, 30 do Simulation.step(state, Simulation.FIXED_DT) end
		check(b.chickenLeft == 0, "The spell did not end")
		passive(b, 30, 50, 0); b.invulnerable = 0; state.projectiles = {}
		shoot(state, 30, 50)
		check(b.chickenLeft == 0, "A second hit made another chicken")
	end)

	test("Eject gives one last life as a small slow pilot with a pea-shooter", function()
		local state = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Meteor", wildIds = { "Eject", "Giant" } })
		local a, b = state.fighters[1], state.fighters[2]
		passive(a, -40, 80, 0); passive(b, 30, 50, 0); b.armor = 1
		shoot(state, 30, 50)
		check(not state.finished and b.armor == 1 and b.ejected and b.form == "PeaShooter", "The pilot did not bail out")
		check(b.scale < 1 and b.speedScale < 1 and b.shotScale == 1 and b.invulnerable > 0 and said(state, "skill", "Eject"), "The pilot kept the plane's size")
		passive(a, -40, 80, 0); passive(b, 30, 50, math.pi)
		b.phase, b.phaseLeft = "Windup", 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(#state.projectiles == 1 and state.projectiles[1].source == "pea", "The pilot did not fire a pea")
		state.projectiles = {}; passive(b, 30, 50, 0); b.invulnerable = 0
		shoot(state, 30, 50)
		check(state.finished and state.winner == 1 and b.armor == 0, "The pilot had more than one life")
	end)

	test("ejecting during a Meteor dive leaves the pilot unable to ram", function()
		local state = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Meteor", wildIds = { "Eject" } })
		local a, b = state.fighters[1], state.fighters[2]
		passive(a, -40, 80, 0); armed(b, 30, 0); b.armor = 1
		shoot(state, 30, 50)
		check(b.ejected and b.armor == 1 and b.form == "PeaShooter", "The diving plane did not eject")
		-- Put the rival ahead of the pilot during the old dive's remaining time.
		passive(a, b.x + 7, b.y, 0)
		Simulation.step(state, Simulation.FIXED_DT)
		check(a.armor == 3 and b.hits == 0 and not b.armed, "An ejected pilot dealt ram damage")
		passive(a, -40, 80, 0); passive(b, 30, 50, math.pi)
		b.phase, b.phaseLeft = "Windup", 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(state.projectiles[1] and state.projectiles[1].source == "pea", "Disarming the old dive disabled the pilot's next shot")
	end)

	test("named builds are announced once and every new card finishes inside the cap", function()
		local state = Simulation.newRound(7, { offenceId = "Meteor", wildIds = { "Vampire", "Squadron" } }, { offenceId = "Pinball" })
		local shout = said(state, "combo")
		check(shout and shout.text == "VAMPIRE SWARM!" and shout.actor == 1 and state.fighters[2].combo == nil, "The build was not named")
		for _, combo in ipairs(Skills.combos) do
			check((Skills.wild[combo[1]] or Skills.offence[combo[1]]) and (Skills.wild[combo[2]] or Skills.offence[combo[2]]), "A combo names a missing skill")
		end
		for _, offence in ipairs({ "Meteor", "Firework", "MachineGun", "Pinball" }) do
			for _, card in ipairs({ "Squadron", "Giant", "Vampire", "Chicken", "Eject" }) do
				for seed = 1, 4 do
					local first = run(seed, { offenceId = offence, wildIds = { card } }, { offenceId = "Firework", wildIds = { "Eject", "Squadron" } })
					local again = run(seed, { offenceId = offence, wildIds = { card } }, { offenceId = "Firework", wildIds = { "Eject", "Squadron" } })
					check(first.elapsed <= Simulation.MAX_TIME and equal(first, again), offence .. " with " .. card .. " was not deterministic")
				end
			end
		end
	end)

	test("Bug is a small quick plane with two armor, and Giant adds two to whatever it has", function()
		local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "Bug" } }, { offenceId = "Firework", wildIds = { "Giant", "Bug" } })
		local a, b = state.fighters[1], state.fighters[2]
		check(a.armor == 2 and a.maxArmor == 2 and a.radius < Simulation.PLANE_RADIUS * 0.5 and a.pace < 1 and a.speedScale > 1, "Bug was not a bug")
		check(b.armor == 4 and b.combo == "GIANT BUG!", "Giant and Bug did not combine")
	end)

	test("Snowball starts small, grows twice and then breaks two armor a hit", function()
		local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "Snowball" } }, { offenceId = "Firework", wildIds = { "Giant" } })
		local a, b = state.fighters[1], state.fighters[2]
		local small = a.radius
		check(small < Simulation.PLANE_RADIUS and b.armor == 5, "Snowball did not start small")
		passive(a, -40, 80, 0); passive(b, 30, 50, 0)
		shoot(state, 30, 50)
		check(b.armor == 4 and a.snowball == 1 and a.radius > small and said(state, "skill", "Snowball"), "The first hit did not grow the plane")
		passive(b, 30, 50, 0); b.invulnerable = 0; state.projectiles = {}
		shoot(state, 30, 50)
		check(b.armor == 2 and a.snowball == 2, "A grown Snowball did not break two armor")
		local grown = a.radius
		passive(b, 30, 50, 0); b.invulnerable = 0; state.projectiles = {}
		shoot(state, 30, 50)
		check(b.armor == 0 and a.radius == grown, "Snowball grew past its limit")
	end)

	test("Swap trades armor once at half time, even when both pilots bring it", function()
		local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "Swap" } }, { offenceId = "Firework", wildIds = { "Swap", "Giant" } })
		local a, b = state.fighters[1], state.fighters[2]
		passive(a, -40, 80, 0); passive(b, 40, 30, 0)
		a.armor = 1
		state.elapsed = Skills.wild.Swap.at - 0.1
		Simulation.step(state, Simulation.FIXED_DT)
		check(a.armor == 1 and b.armor == 5 and not state.swapped, "The swap came early")
		state.elapsed = Skills.wild.Swap.at
		Simulation.step(state, Simulation.FIXED_DT)
		check(a.armor == 5 and b.armor == 1 and state.swapped and said(state, "skill", "Swap"), "Armor did not change hands")
		for _ = 1, 20 do Simulation.step(state, Simulation.FIXED_DT) end
		check(a.armor == 5 and b.armor == 1, "The armor swapped back")
	end)

	test("Gambler rolls every face from the seed and each face does what the card says", function()
		local faces = {}
		for seed = 1, 60 do
			local state = Simulation.newRound(seed, { offenceId = "Firework", wildIds = { "Gambler" } }, { offenceId = "Firework", wildIds = { "Gambler" } })
			for _, fighter in ipairs(state.fighters) do
				local roll = fighter.roll
				faces[roll] = true
				check(roll >= 1 and roll <= 6 and roll % 1 == 0, "The die showed a face it does not have")
				check(fighter.armor == (roll == 1 and 2 or (roll >= 4 and 4 or 3)), "Roll " .. roll .. " gave the wrong armor")
				check((fighter.bonus == 1) == (roll == 6), "Only a six should hit harder")
			end
			local again = Simulation.newRound(seed, { offenceId = "Firework", wildIds = { "Gambler" } }, { offenceId = "Firework" })
			check(again.fighters[1].roll == state.fighters[1].roll, "The same seed rolled a different face")
		end
		for face = 1, 6 do check(faces[face], "Face " .. face .. " never came up") end
	end)

	test("Sniper locks its aim, breaks two armor on a hit and stays inside the cap", function()
		local state = Simulation.newRound(4, { offenceId = "Sniper" }, { offenceId = "Firework" })
		local a, b = state.fighters[1], state.fighters[2]
		passive(a, -50, 50, 0); passive(b, 30, 50, math.pi / 2)
		b.vx, b.vy = 0, 0
		a.phase, a.phaseLeft = "Windup", 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(#state.projectiles == 1 and state.projectiles[1].power == 2 and state.projectiles[1].source == "sniper", "Sniper did not fire its shot")
		for _ = 1, 40 do
			passive(b, 30, 50, math.pi / 2); b.vx, b.vy = 0, 0
			Simulation.step(state, Simulation.FIXED_DT)
		end
		check(b.armor == 1, "A sniper hit did not break two armor")
		a.phase, a.phaseLeft, a.heading = "Windup", Skills.offence.Sniper.lockTime - 0.05, 0.3
		passive(b, 30, 90, 0)
		Simulation.step(state, Simulation.FIXED_DT)
		check(math.abs(a.heading - 0.3) < 0.0001, "The aim moved after it locked")
		for seed = 1, 6 do
			for _, rival in ipairs({ "Meteor", "Firework", "MachineGun", "Pinball", "Sniper" }) do
				local first = run(seed, { offenceId = "Sniper", wildIds = { "Squadron", "Snowball" } }, { offenceId = rival, wildIds = { "Bug", "Swap" } })
				local again = run(seed, { offenceId = "Sniper", wildIds = { "Squadron", "Snowball" } }, { offenceId = rival, wildIds = { "Bug", "Swap" } })
				check(first.elapsed <= Simulation.MAX_TIME and equal(first, again), "Sniper against " .. rival .. " was not deterministic")
			end
		end
	end)

	test("Wrap sends a missed shot back in the far side, aimed at the rival", function()
		local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "Wrap" } }, { offenceId = "Firework" })
		local a, b = state.fighters[1], state.fighters[2]
		passive(a, 40, 50, 0); passive(b, -30, 30, 0)
		a.phase, a.phaseLeft = "Windup", 0
		Simulation.step(state, Simulation.FIXED_DT)
		local shot = state.projectiles[1]
		check(shot and shot.wraps == 2, "The shot was not marked to wrap")
		for _ = 1, 60 do
			passive(a, 40, 50, 0); passive(b, -30, 30, 0)
			Simulation.step(state, Simulation.FIXED_DT)
			if shot.wraps < 2 then break end
		end
		check(shot.wraps == 1 and shot.x < 0 and said(state, "wrap"), "The shot did not come back in the other side")
		check(shot.vx > 0 and shot.vy < 0, "The returning shot did not turn toward the rival")
		local plain = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework" })
		passive(plain.fighters[1], 40, 50, 0); plain.fighters[1].phase, plain.fighters[1].phaseLeft = "Windup", 0
		Simulation.step(plain, Simulation.FIXED_DT)
		check(plain.projectiles[1].wraps == nil, "A plain shot wrapped")
	end)

	test("Hot Potato starts on the rival, spares its owner once, follows hits and goes off on time", function()
		local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "HotPotato" } }, { offenceId = "Firework", wildIds = { "SpringBumper" } })
		local a, b = state.fighters[1], state.fighters[2]
		local potato = state.potatoes[1]
		check(potato.holder == 2 and potato.owner == 1 and potato.left == Skills.wild.HotPotato.fuse, "The bomb did not start on the rival")
		local function strikeOwner()
			passive(a, -30, 50, math.pi); passive(b, 40, 80, 0); a.invulnerable = 0
			state.projectiles = { { id = 950, owner = 2, x = -26, y = 50, vx = -60, vy = 0, life = 1, radius = 3.5 } }
			Simulation.step(state, Simulation.FIXED_DT)
		end
		strikeOwner()
		check(a.armor == 2 and potato.holder == 2, "The first hit on the owner handed the bomb over")
		strikeOwner()
		check(a.armor == 1 and potato.holder == 1 and said(state, "potato_pass"), "The second hit did not pass the bomb")
		passive(a, -40, 80, 0); passive(b, 30, 50, 0); b.bumperReady = false; state.projectiles = {}
		shoot(state, 30, 50)
		check(potato.holder == 2, "A hit on the rival did not send the bomb back")
		passive(a, -40, 80, 0); passive(b, 30, 30, 0); b.invulnerable, b.bumperReady = 0, true
		state.projectiles = {}
		potato.left = Simulation.FIXED_DT / 2
		local armor = b.armor
		Simulation.step(state, Simulation.FIXED_DT)
		check(b.armor == armor - 1 and b.bumperReady and #state.potatoes == 0 and said(state, "potato"), "The bomb did not go off through the bumper")
	end)

	test("Decoy draws a nearer rival, eats one shot and comes back after its cooldown", function()
		local state = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework", wildIds = { "Decoy" } })
		local a, b = state.fighters[1], state.fighters[2]
		passive(a, -40, 80, 0); passive(b, 30, 50, 0)
		Simulation.step(state, Simulation.FIXED_DT)
		check(b.decoyUp and b.decoyX and math.abs(math.abs(b.decoyY - b.y) - 14) < 0.5, "The decoy was not flying beside its plane")
		local dx, dy = b.decoyX, b.decoyY
		state.projectiles = { { id = 960, owner = 1, x = dx - 4, y = dy, vx = 60, vy = 0, life = 1, radius = 3.5 } }
		passive(b, 30, 50, 0)
		Simulation.step(state, Simulation.FIXED_DT)
		check(b.armor == 3 and not b.decoyUp and #state.projectiles == 0 and said(state, "decoy_pop"), "The decoy did not eat the shot")
		check(b.decoyX == nil, "A popped decoy still had a position")
		for _ = 1, math.ceil(Skills.wild.Decoy.cooldown / Simulation.FIXED_DT) + 2 do
			passive(a, -40, 80, 0); passive(b, 30, 50, 0)
			Simulation.step(state, Simulation.FIXED_DT)
		end
		check(b.decoyUp, "The decoy never came back")
		-- A circling rival that is nearer the decoy steers by it, not by the plane.
		local lured = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework", wildIds = { "Decoy" } })
		local plain = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework" })
		for _, round in ipairs({ lured, plain }) do
			passive(round.fighters[2], 30, 50, 0)
			local f = round.fighters[1]
			f.x, f.y, f.heading = 30, 50 + 30 * (lured.fighters[2].decoySide or 1), 0
			f.phase, f.phaseLeft = "Windup", 0.5
			Simulation.step(round, Simulation.FIXED_DT)
		end
		check(math.abs(lured.fighters[1].lockY - plain.fighters[1].lockY) > 5, "The decoy did not draw the rival's aim")
	end)

	test("Thief takes one stealable card with its first hit and leaves plane-shaping cards alone", function()
		local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "Thief" } }, { offenceId = "Firework", wildIds = { "Giant", "SpringBumper" } })
		local a, b = state.fighters[1], state.fighters[2]
		passive(a, -40, 80, 0); passive(b, 30, 50, 0)
		b.bumperReady = false
		shoot(state, 30, 50)
		local stolen = said(state, "skill", "Thief")
		check(stolen and stolen.stolen == "SpringBumper", "The thief took the wrong card")
		check(#b.wildIds == 1 and b.wildIds[1] == "Giant" and b.scale > 1.5, "The victim's plane changed shape")
		check(#a.wildIds == 2 and a.wildIds[1] == "SpringBumper" and a.bumperReady == true and b.bumperReady == false, "The card did not change hands")
		passive(b, 30, 50, 0); b.invulnerable = 0; state.projectiles = {}
		shoot(state, 30, 50)
		check(#a.wildIds == 2 and #b.wildIds == 1, "The thief stole twice")
		local nothing = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "Thief" } }, { offenceId = "Firework", wildIds = { "Bug" } })
		passive(nothing.fighters[1], -40, 80, 0); passive(nothing.fighters[2], 30, 50, 0)
		shoot(nothing, 30, 50)
		check(#nothing.fighters[2].wildIds == 1 and #nothing.fighters[1].wildIds == 1, "A plane-shaping card was stolen")
		local pinched = said(nothing, "skill", "Thief")
		check(pinched and pinched.stolen == nil and not nothing.fighters[1].thiefReady, "A thief with nothing to take did not pinch ammo instead")
		check(nothing.fighters[2].phase == "Recover" and nothing.fighters[2].phaseLeft >= Skills.wild.Thief.ammo,
			"Losing ammo did not delay the rival's next attack")
	end)

	test("Thief stops only the stolen power and the retained power still works", function()
		for _, cards in ipairs({ { "Afterburner", "Chicken" }, { "Chicken", "Wrap" } }) do
			local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "Thief" } }, { offenceId = "Firework", wildIds = cards })
			local a, b = state.fighters[1], state.fighters[2]
			passive(a, -40, 80, 0); passive(b, 30, 50, 0)
			if cards[1] == "Afterburner" then b._boostPending, b.boostLeft, b.tempo = true, 0.6, Skills.wild.Afterburner.tempo end
			shoot(state, 30, 50)
			check(said(state, "skill", "Thief").stolen == cards[1] and #b.wildIds == 1 and b.wildIds[1] == cards[2], "The wrong card changed hands")
			if cards[2] == "Chicken" then
				check(b.chickenReady, "Stealing Afterburner disabled the retained Chicken")
				check(not b._boostPending and b.boostLeft == 0 and b.tempo == nil, "The stolen Afterburner kept rushing")
				passive(a, -40, 80, 0); passive(b, 30, 50, 0)
				state.projectiles = { projectile(999, 2, -36, 80, -60, 0) }
				Simulation.step(state, Simulation.FIXED_DT)
				check(a.chickenLeft == Skills.wild.Chicken.duration and not b.chickenReady, "The retained Chicken could not trigger")
			else
				check(not b.chickenReady and b.wrapShots, "Stealing Chicken disabled the retained Wrap")
				passive(a, -40, 80, 0); passive(b, 30, 50, 0)
				state.projectiles = {}; b.phase, b.phaseLeft = "Windup", 0
				Simulation.step(state, Simulation.FIXED_DT)
				check(state.projectiles[1] and state.projectiles[1].owner == 2 and state.projectiles[1].wraps == 2, "The retained Wrap could not mark its next shot")
			end
		end
	end)

	test("theft preserves retained and active dodge bonuses without activating a new Second Wind", function()
		local function setup(mine, theirs)
			local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = mine }, { offenceId = "Firework", wildIds = theirs })
			passive(state.fighters[1], -40, 80, 0); passive(state.fighters[2], 30, 50, 0)
			return state, state.fighters[1], state.fighters[2]
		end
		local function rollCooldown(state, id)
			local target, rival = state.fighters[id], state.fighters[3 - id]
			passive(target, 0, 50, math.pi / 2); passive(rival, -60, 80, 0)
			target.dodgeCool, target.dodgeLeft = 0, 0
			local before = target.dodges
			state.projectiles = { projectile(990, 3 - id, -16, 52, 60, 0) }
			Simulation.step(state, Simulation.FIXED_DT)
			check(target.dodges == before + 1, "The cooldown fixture did not roll")
			return target.dodgeCool / Simulation.DODGE_COOLDOWN / (target.armor <= 1 and Simulation.DANGER_DODGE or 1)
		end
		-- The hit activates Second Wind, then takes only Afterburner away.
		local state, a, b = setup({ "Thief" }, { "Afterburner", "SecondWind" })
		b.armor = 2; shoot(state, 30, 50)
		check(b.secondWind and #b.wildIds == 1 and b.wildIds[1] == "SecondWind", "The wrong power was retained")
		check(close(rollCooldown(state, 2), Skills.wild.SecondWind.dodge), "Stealing Afterburner removed the retained Second Wind's dodge bonus")
		check(close(rollCooldown(state, 1), Skills.wild.Afterburner.dodge), "The thief did not gain Afterburner's dodge bonus")
		-- An already-active Second Wind stays stronger when its owner steals Afterburner.
		state, a, b = setup({ "Thief", "SecondWind" }, { "Afterburner" })
		a.armor = 2
		state.projectiles = { projectile(991, 2, -36, 80, -60, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(a.secondWind, "The thief's Second Wind did not activate")
		passive(a, -40, 80, 0); passive(b, 30, 50, 0); state.projectiles = {}
		shoot(state, 30, 50)
		check(close(rollCooldown(state, 1), Skills.wild.SecondWind.dodge), "Acquiring Afterburner weakened active Second Wind")
		-- Holding Afterburner makes Thief take Second Wind instead. The victim
		-- keeps Afterburner; the stolen Second Wind starts inactive as before.
		state, a, b = setup({ "Thief", "Afterburner" }, { "Afterburner", "SecondWind" })
		b.armor = 2; shoot(state, 30, 50)
		check(not a.secondWind and not b.secondWind and b.wildIds[1] == "Afterburner", "Theft changed Second Wind activation rules")
		check(close(rollCooldown(state, 2), Skills.wild.Afterburner.dodge), "Stealing Second Wind removed retained Afterburner's dodge bonus")
		check(close(rollCooldown(state, 1), Skills.wild.Afterburner.dodge), "An unused stolen Second Wind granted its dodge bonus")
	end)

	test("Boomerang flies out, turns back to its thrower and is caught", function()
		local state = Simulation.newRound(4, { offenceId = "Boomerang" }, { offenceId = "Firework" })
		local a, b = state.fighters[1], state.fighters[2]
		passive(a, -40, 50, 0); passive(b, 60, 90, 0)
		a.phase, a.phaseLeft = "Windup", 0
		Simulation.step(state, Simulation.FIXED_DT)
		local blade = state.projectiles[1]
		check(blade and blade.source == "boomerang", "No blade was thrown")
		local farthest, caught = blade.x, false
		for _ = 1, 240 do
			passive(a, -40, 50, 0); passive(b, 60, 90, 0)
			Simulation.step(state, Simulation.FIXED_DT)
			farthest = math.max(farthest, blade.x)
			if #state.projectiles == 0 then caught = true; break end
		end
		check(farthest > 0 and blade.returning and caught and said(state, "catch") and b.armor == 3, "The blade did not come home")
		for seed = 1, 5 do
			for _, rival in ipairs({ "Meteor", "Pinball", "Boomerang" }) do
				local first = run(seed, { offenceId = "Boomerang", wildIds = { "Wrap", "Decoy" } }, { offenceId = rival, wildIds = { "HotPotato", "Thief" } })
				local again = run(seed, { offenceId = "Boomerang", wildIds = { "Wrap", "Decoy" } }, { offenceId = rival, wildIds = { "HotPotato", "Thief" } })
				check(first.elapsed <= Simulation.MAX_TIME and equal(first, again), "Boomerang against " .. rival .. " was not deterministic")
			end
		end
	end)

	test("Black Hole drags both planes, bends and swallows shots, and bites the rival once it has armed", function()
		local state = Simulation.newRound(4, { offenceId = "BlackHole" }, { offenceId = "Firework" })
		local a, b = state.fighters[1], state.fighters[2]
		passive(a, -40, 50, 0); passive(b, 30, 50, 0)
		b.vx, b.vy = 0, 0
		a.phase, a.phaseLeft = "Windup", 0
		Simulation.step(state, Simulation.FIXED_DT)
		local hole = state.holes and state.holes[1]
		check(hole and hole.owner == 1 and said(state, "hole") and #state.projectiles == 0, "No hole opened")
		check(math.abs(hole.x - 30) < 1 and math.abs(hole.y - 50) < 1, "The hole did not open on the rival")
		for _ = 1, 20 do
			passive(a, -40, 50, 0); passive(b, 30, 50, 0)
			Simulation.step(state, Simulation.FIXED_DT)
		end
		check(b.armor == 3 and #state.holes == 1, "The hole bit before it had armed")
		for _ = 1, 40 do
			passive(a, -40, 50, 0); passive(b, 30, 50, 0)
			Simulation.step(state, Simulation.FIXED_DT)
		end
		check(b.armor == 2 and a.hits == 1 and #state.holes == 0 and said(state, "hole_close"), "The armed core did not take one armor and collapse")
		local function open(armLeft)
			state.holes = { { id = 90, owner = 1, skillId = "BlackHole", x = 0, y = 50, life = 5, maxLife = 5, armLeft = armLeft,
				core = 4.5, reach = 34, pull = 20, bend = 170 } }
		end
		open(5)
		passive(a, -20, 50, math.pi / 2); passive(b, 20, 50, math.pi / 2); b.invulnerable = 0
		state.projectiles = { projectile(1, 1, -10, 62, 60, 0), projectile(2, 2, 1, 51, -60, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(a.x > -20 and b.x < 20, "The hole did not drag both planes toward it")
		local bent = state.projectiles[1]
		check(#state.projectiles == 1 and bent.id == 1 and said(state, "swallow"), "A shot in the core was not swallowed")
		check(bent.vy < 0 and close(math.sqrt(bent.vx ^ 2 + bent.vy ^ 2), 60), "A passing shot was not bent at constant speed")
		open(0); state.projectiles = {}
		passive(a, 0, 50, 0); passive(b, 60, 80, 0)
		Simulation.step(state, Simulation.FIXED_DT)
		check(a.armor == 3 and #state.holes == 1, "A hole hurt its own maker")
	end)

	test("UFO Beam grabs a close rival, takes its controls, and a thrown plane loses armor at the wall", function()
		local function grab(rivalCards, distance)
			local state = Simulation.newRound(4, { offenceId = "UFOBeam" }, { offenceId = "Firework", wildIds = rivalCards })
			local a, b = state.fighters[1], state.fighters[2]
			passive(a, 0, 50, 0); passive(b, distance, 50, 0)
			b.phase, b.phaseLeft = "Windup", 0.5
			a.phase, a.phaseLeft = "Windup", 0
			Simulation.step(state, Simulation.FIXED_DT)
			return state, a, b
		end
		local state, a, b = grab({}, 15)
		check(b.hold and b.hold.by == 1 and said(state, "beam"), "A rival in range was not grabbed")
		check(b.phase == "Recover" and #state.projectiles == 0, "The grabbed plane kept its attack")
		local frozen = b.phaseLeft
		for _ = 1, 10 do Simulation.step(state, Simulation.FIXED_DT) end
		check(close(b.phaseLeft, frozen) and math.abs(b.x - b.hold.x) < 3, "A held plane kept its clock running or flew free")
		for _ = 1, 40 do Simulation.step(state, Simulation.FIXED_DT) end
		check(b.hold == nil and b.throw and b.throw.vx > 60 and said(state, "throw"), "The beam did not throw the plane it held")
		for _ = 1, 200 do
			if not b.throw then break end
			Simulation.step(state, Simulation.FIXED_DT)
		end
		check(b.throw == nil and b.armor == 2 and a.hits == 1 and b.x > state.bounds.right - 2, "The thrown plane did not lose armor at the wall")
		local missed, _, far = grab({}, 60)
		check(far.hold == nil and said(missed, "beam_miss") and far.phase == "Windup", "The beam reached across the arena")
		local shielded, _, safe = grab({}, 15)
		check(safe.hold, "Fixture did not grab")
		local protected = Simulation.newRound(4, { offenceId = "UFOBeam" }, { offenceId = "Firework" })
		passive(protected.fighters[1], 0, 50, 0); passive(protected.fighters[2], 15, 50, 0)
		protected.fighters[2].invulnerable = 0.5
		protected.fighters[1].phase, protected.fighters[1].phaseLeft = "Windup", 0
		Simulation.step(protected, Simulation.FIXED_DT)
		check(protected.fighters[2].hold == nil, "A protected plane was grabbed")
		local bumped, _, springy = grab({ "SpringBumper" }, 15)
		for _ = 1, 260 do
			Simulation.step(bumped, Simulation.FIXED_DT)
			if springy.bumperReady == false then break end
		end
		check(springy.armor == 3 and springy.bumperReady == false and springy.throw == nil, "Spring Bumper did not soften the wall")
		check(shielded ~= nil)
	end)

	test("Mothership stops attacking and its drones carry the attack from where they are", function()
		local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "Mothership" } }, { offenceId = "Firework" })
		local a, b = state.fighters[1], state.fighters[2]
		check(a.mothership and a.radius > Simulation.PLANE_RADIUS and a.speedScale < 1, "A mothership is not a big slow plane")
		passive(a, -40, 50, 0); passive(b, 30, 50, 0)
		a.phase, a.phaseLeft = "Windup", 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(#state.drones == Skills.wild.Mothership.drones and #state.projectiles == 0 and said(state, "drone") and not a.armed,
			"The mothership fired its own attack instead of launching drones")
		local first
		for _ = 1, 400 do
			passive(a, -40, 50, 0); passive(b, 30, 50, 0)
			Simulation.step(state, Simulation.FIXED_DT)
			first = first or state.projectiles[1]
			if b.armor < 3 then break end
		end
		check(first and first.owner == 1, "No drone fired the plane's attack")
		check(b.armor == 2 and a.hits == 1, "A drone's shot did not count as its owner's hit")
		check(a.attacks >= 2, "A drone's attack was not counted")

		local dive = Simulation.newRound(4, { offenceId = "Meteor", wildIds = { "Mothership" } }, { offenceId = "Firework" })
		local c, d = dive.fighters[1], dive.fighters[2]
		passive(c, -40, 50, 0); passive(d, 30, 50, 0)
		c.phase, c.phaseLeft = "Windup", 0
		local struck
		for _ = 1, 400 do
			Simulation.step(dive, Simulation.FIXED_DT)
			check(not c.armed, "A Meteor mothership armed its own nose")
			passive(c, -40, 50, 0); passive(d, 30, 50, 0)
			for _, entry in ipairs(dive.events) do if entry.kind == "hit" and entry.source == "meteor" then struck = entry end end
			if struck then break end
		end
		check(struck and struck.actor == 1 and d.armor == 2, "A Meteor drone did not ram the rival")

		local swat = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework", wildIds = { "Mothership" } })
		passive(swat.fighters[1], -40, 80, 0); passive(swat.fighters[2], 40, 20, 0)
		swat.drones = { { id = 5, owner = 2, mode = "fly", age = 0, x = 0, y = 50, heading = math.pi, vx = 0, vy = 0 } }
		swat.projectiles = { projectile(7, 1, -6, 50, 60, 0) }
		Simulation.step(swat, Simulation.FIXED_DT)
		Simulation.step(swat, Simulation.FIXED_DT)
		check(#swat.drones == 0 and #swat.projectiles == 0 and said(swat, "drone_pop") and swat.fighters[2].armor == 3,
			"A shot that met a drone did not pop it and stop there")
	end)

	test("a shot-down Meteor drone cannot ram after its destruction", function()
		for _, destroyed in ipairs({ false, true }) do
			local state = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Meteor", wildIds = { "Mothership" } })
			local a, b = state.fighters[1], state.fighters[2]
			passive(a, -40, 80, 0); passive(b, 40, 20, 0)
			local drone = { id = 5, owner = 2, mode = "fire", left = 1, armed = true, age = 1,
				x = 0, y = 50, heading = math.pi, vx = 0, vy = 0 }
			state.drones = { drone }
			if destroyed then state.projectiles = { projectile(7, 1, -6, 50, 60, 0) } end
			Simulation.step(state, Simulation.FIXED_DT)
			if destroyed then
				check(drone.dead and said(state, "drone_pop") and #state.projectiles == 0, "The shot did not destroy the armed drone")
			end
			-- The rival enters the drone's path on the following tick. A live drone
			-- must hit here, but its destroyed counterpart must already be harmless.
			passive(a, drone.x, drone.y, 0)
			Simulation.step(state, Simulation.FIXED_DT)
			check(a.armor == (destroyed and 3 or 2) and b.hits == (destroyed and 0 or 1),
				destroyed and "A destroyed drone dealt ram damage" or "The live control drone did not ram")
			check(#state.drones == 0, "The resolved drone survived")
		end
	end)

	test("stealing Rewind again cannot reset a plane's consumed rewind", function()
		local state = Simulation.newRound(4, { offenceId = "Firework", wildIds = { "Thief" } },
			{ offenceId = "Firework", wildIds = { "Rewind" } })
		local function resetPositions()
			passive(state.fighters[1], -40, 80, 0); passive(state.fighters[2], 30, 50, 0)
			state.fighters[1].invulnerable, state.fighters[2].invulnerable = 0, 0
			state.projectiles = {}
		end
		local function shootThief()
			state.projectiles = { projectile(999, 2, -36, 80, -60, 0) }
			Simulation.step(state, Simulation.FIXED_DT)
		end
		for _ = 1, 20 do resetPositions(); Simulation.step(state, Simulation.FIXED_DT) end
		resetPositions(); shoot(state, 30, 50)
		check(state.rewound and state.rewound[2], "The rival did not consume its rewind")
		-- Record a state before the theft, after the rival's own rewind is spent.
		resetPositions(); Simulation.step(state, Simulation.FIXED_DT)
		resetPositions(); shoot(state, 30, 50)
		check(state.fighters[1].rewindReady and said(state, "skill", "Thief").stolen == "Rewind", "The first theft did not arm Rewind")
		resetPositions(); shootThief()
		local a, b = state.fighters[1], state.fighters[2]
		check(state.rewound[1] and a.thiefReady and #a.wildIds == 1 and a.wildIds[1] == "Thief",
			"Rewind did not restore the state before the theft")
		check(b.wildIds[1] == "Rewind" and not b.rewindReady, "The rival's spent card was not restored")
		resetPositions(); shoot(state, 30, 50)
		check(#state.fighters[1].wildIds == 2 and not state.fighters[1].rewindReady, "A second theft rearmed a consumed rewind")
		resetPositions(); shootThief()
		local rewinds = 0
		for _, entry in ipairs(state.events) do if entry.kind == "rewind" then rewinds = rewinds + 1 end end
		check(state.fighters[1].armor == 2 and rewinds == 2, "A plane rewound more than once")
	end)

	test("Rewind cancels the first hit and puts the whole round back three seconds, but not the clock", function()
		local state = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework", wildIds = { "Rewind" } })
		local a, b = state.fighters[1], state.fighters[2]
		check(state.recording and b.rewindReady, "Rewind was not armed")
		for _ = 1, 120 do
			passive(a, -40, 50, 0); passive(b, 30, 50, 0)
			Simulation.step(state, Simulation.FIXED_DT)
		end
		a.armor = 2
		for _ = 1, 120 do
			passive(a, -40, 70, 0); passive(b, 30, 70, 0)
			Simulation.step(state, Simulation.FIXED_DT)
		end
		passive(a, -40, 70, 0); passive(b, 30, 70, 0)
		local serial = state.eventSerial
		shoot(state, 30, 70)
		a, b = state.fighters[1], state.fighters[2]
		check(b.armor == 3 and not b.rewindReady, "The hit landed, or Rewind stayed ready")
		check(math.abs(b.y - 50) < 2 and math.abs(a.y - 50) < 2, "The planes were not put back where they were three seconds ago")
		check(a.armor == 3, "Rewind kept damage the rewinder had dealt in the last three seconds")
		check(state.elapsed > 4 and state.eventSerial > serial and #state.projectiles == 0, "The clock or the event list went backwards")
		local scrub = said(state, "rewind")
		check(scrub and scrub.actor == 2 and scrub.back > 2.5 and scrub.back <= 3.3 and said(state, "skill", "Rewind"), "The rewind was not announced")
		check(#state._history == 0, "A second rewind could reach back past the first")
		passive(a, -40, 50, 0); passive(b, 30, 50, 0); b.invulnerable = 0; state.projectiles = {}
		shoot(state, 30, 50)
		check(state.fighters[2].armor == 2, "Rewind worked twice")
		for seed = 1, 4 do
			for _, pair in ipairs({ { "BlackHole", "UFOBeam" }, { "UFOBeam", "Sniper" }, { "MachineGun", "BlackHole" } }) do
				local first = run(seed, { offenceId = pair[1], wildIds = { "Mothership", "Rewind" } }, { offenceId = pair[2], wildIds = { "Rewind", "Thief" } })
				local again = run(seed, { offenceId = pair[1], wildIds = { "Mothership", "Rewind" } }, { offenceId = pair[2], wildIds = { "Rewind", "Thief" } })
				check(first.elapsed <= Simulation.MAX_TIME and equal(first, again), pair[1] .. " against " .. pair[2] .. " was not deterministic")
			end
		end
	end)

	test("a free plane rolls away from a shot about to reach it, then has no roll to spend", function()
		local state = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework" })
		local a, b = state.fighters[1], state.fighters[2]
		passive(a, -60, 80, 0); passive(b, 0, 50, math.pi / 2)
		b.dodgeCool = 0
		state.projectiles = { projectile(1, 1, -16, 52, 60, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		local roll = said(state, "dodge")
		check(roll and roll.actor == 2 and b.dodges == 1, "A free plane did not roll away from a shot")
		check(b.dodgeLeft > 0 and b.dodgeCool > Simulation.DODGE_COOLDOWN - 0.05, "The roll did not start its cooldown")
		check(math.sqrt(b.vx ^ 2 + b.vy ^ 2) > 40, "The roll was no faster than cruising")
		b.dodgeLeft = 0
		state.projectiles = { projectile(2, 1, b.x - 16, b.y + 2, 60, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(b.dodges == 1, "A plane rolled again while its roll was spent")
	end)

	test("a plane that has turned in to aim, or is attacking, is committed and cannot roll", function()
		for _, phase in ipairs({ "Windup", "Attack" }) do
			local state = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework" })
			local a, b = state.fighters[1], state.fighters[2]
			passive(a, -60, 80, 0); passive(b, 0, 50, math.pi / 2)
			b.dodgeCool = 0
			b.phase, b.phaseLeft, b._attackHeading = phase, phase == "Windup" and Simulation.AIM_TIME - 0.05 or 0.4, math.pi / 2
			state.projectiles = { projectile(1, 1, -16, 52, 60, 0) }
			Simulation.step(state, Simulation.FIXED_DT)
			check(b.dodges == 0 and not said(state, "dodge"), "A committed plane rolled during " .. phase)
		end
		local state = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework" })
		local b = state.fighters[2]
		passive(state.fighters[1], -60, 80, 0); passive(b, 0, 50, math.pi / 2)
		b.dodgeCool = 0
		b.phase, b.phaseLeft = "Windup", Simulation.AIM_TIME + 0.4
		state.projectiles = { projectile(1, 1, -16, 52, 60, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(b.dodges == 1 and b.phase == "Windup", "A plane still circling with its charge could not roll")
	end)

	test("a plane on its last armor is ready to roll again sooner", function()
		local state = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework" })
		local b = state.fighters[2]
		passive(state.fighters[1], -60, 80, 0); passive(b, 0, 50, math.pi / 2)
		b.dodgeCool, b.armor = 0, 1
		state.projectiles = { projectile(1, 1, -16, 52, 60, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(b.dodges == 1 and b.dodgeCool < Simulation.DODGE_COOLDOWN * Simulation.DANGER_DODGE + 0.000001, "Last armor did not shorten the roll cooldown")
	end)

	test("planes take turns: one waits out its rival's charge, but not for ever", function()
		local state = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework" })
		local a, b = state.fighters[1], state.fighters[2]
		passive(a, -30, 50, 0); passive(b, 30, 50, math.pi)
		a.phase, a.phaseLeft = "Windup", 100
		b.phase, b.phaseLeft = "Approach", 0
		Simulation.step(state, Simulation.FIXED_DT); Simulation.step(state, Simulation.FIXED_DT)
		check(b.phase == "Approach", "A plane started charging while its rival was charging")
		b.phaseLeft = -Simulation.TURN_WAIT
		Simulation.step(state, Simulation.FIXED_DT)
		check(b.phase == "Windup", "A plane waited for ever")
		local free = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework" })
		passive(free.fighters[1], -30, 50, 0); passive(free.fighters[2], 30, 50, math.pi)
		free.fighters[2].phase, free.fighters[2].phaseLeft = "Approach", 0
		Simulation.step(free, Simulation.FIXED_DT); Simulation.step(free, Simulation.FIXED_DT)
		check(free.fighters[2].phase == "Windup", "A plane with a clear turn did not charge")
	end)

	test("every attack begun speeds the round up, down to a floor", function()
		local state = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework" })
		local a = state.fighters[1]
		check(state.rush == 1 and state.exchanges == 0, "A round started hurried")
		local last = 1
		for count = 1, 20 do
			passive(a, -40, 50, 0); passive(state.fighters[2], 40, 80, 0)
			a.phase, a.phaseLeft = "Windup", 0
			Simulation.step(state, Simulation.FIXED_DT)
			check(state.exchanges == count and state.rush <= last and state.rush >= Simulation.RUSH_FLOOR, "The rush left its range")
			last = state.rush
			state.projectiles = {}
		end
		check(close(last, Simulation.RUSH_FLOOR), "The rush never reached its floor")
		a.phaseLeft = 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(a.phase == "Recover" and close(a.phaseLeft, Simulation.RECOVERY_TIME * Simulation.RUSH_FLOOR), "A hurried round did not shorten the bank away")
	end)

	test("a plane that is hit while free rallies; a hit does not cancel the rival's own attack", function()
		local state = Simulation.newRound(4, { offenceId = "Firework" }, { offenceId = "Firework" })
		local a, b = state.fighters[1], state.fighters[2]
		passive(a, -40, 80, 0); passive(b, 30, 50, 0)
		shoot(state, 30, 50)
		check(b.armor == 2 and b.phase == "Recover" and b.rally == Simulation.RALLY, "The struck plane did not rally")
		check(close(b.phaseLeft, Simulation.RECOVERY_TIME * Simulation.RALLY), "The rally did not shorten the bank away")
		check(a.phase == "Recover" and a.phaseLeft > 50 and a.rally == nil, "Landing a shot changed the shooter's own timing")
		b.phase, b.phaseLeft = "Approach", 0
		Simulation.step(state, Simulation.FIXED_DT)
		check(b.phase == "Windup" and b.rally == nil, "The rally outlived one trip")
		passive(a, -40, 80, 0); a.invulnerable = 0
		a.phase, a.phaseLeft = "Attack", 0.3
		a._attackHeading = 0
		state.projectiles = { projectile(950, 2, a.x + 4, a.y, -60, 0) }
		Simulation.step(state, Simulation.FIXED_DT)
		check(a.armor == 2 and a.phase == "Attack", "A hit cancelled an attack already under way")
	end)

	return string.format("BattleSimulation: %d tests passed (determinism, fixed ticks, collisions, protection, endings, wild cards, wakes, plane-changing cards, rolls, turns, tempo)", passed)
end
