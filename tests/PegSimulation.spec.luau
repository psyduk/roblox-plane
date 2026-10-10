-- Pure behavior tests; execute require(thisModule)(PegSimulation) in Studio.
return function(Sim)
	local passed = 0
	local function test(name, callback)
		local ok, problem = pcall(callback)
		assert(ok, name .. ": " .. tostring(problem))
		passed = passed + 1
	end
	local function close(a, b) return math.abs(a - b) < 0.00001 end
	local function board(pegs) return { seed = 1, width = Sim.WIDTH, height = Sim.HEIGHT, pegs = pegs or {} } end
	local function peg(id, x, y, kind) return { id = id, x = x, y = y, radius = 12, kind = kind or "blue" } end
	local function put(state, x, y, vx, vy)
		local ball = state.balls[1]
		ball.x, ball.y, ball.vx, ball.vy, ball.alive = x, y, vx or 0, vy or 0, true
		ball.anchorX, ball.anchorY, ball.stuckTime = x, y, 0
		return ball
	end
	local function run(course, angle, powerId, dt)
		local state = Sim.newShot(course, { angle = angle, powerId = powerId })
		for _ = 1, 15000 do
			Sim.step(state, course, dt or Sim.FIXED_DT)
			if state.done then return state end
		end
		error("Shot did not finish")
	end
	local function firstHit(powerId, course)
		local state = Sim.newShot(course, { angle = 0, powerId = powerId })
		put(state, 500, 150, 0, 1000)
		Sim.step(state, course, 0.04)
		return state
	end

	test("original board has deterministic roles and spaced physical circles", function()
		local a, b, c = Sim.makeBoard(17), Sim.makeBoard(17), Sim.makeBoard(18)
		assert(#a.pegs == 72 and a.width == 1000 and a.height == 900)
		local counts, changed = {}, false
		for i, target in ipairs(a.pegs) do
			assert(target.id == i and target.x == b.pegs[i].x and target.y == b.pegs[i].y and target.kind == b.pegs[i].kind)
			assert(target.x > target.radius and target.x < a.width - target.radius and target.y > 100 and target.y < 830)
			counts[target.kind] = (counts[target.kind] or 0) + 1
			changed = changed or target.kind ~= c.pegs[i].kind
			for j = i + 1, #a.pegs do
				local other = a.pegs[j]
				local dx, dy = target.x - other.x, target.y - other.y
				assert(dx * dx + dy * dy > (target.radius + other.radius + 3) ^ 2, "Overlapping targets")
			end
		end
		assert(counts.orange == 15 and counts.green == 1 and counts.purple == 1 and changed)
		assert(a.pegs[1].kind == "green" and a.pegs[1].y < 230, "Power trigger should be reachable early")
	end)

	test("repeat shots and different heartbeat chunk sizes are deterministic", function()
		local course = Sim.makeBoard(49351)
		local a, b, c = run(course, -39, "split"), run(course, -39, "split"), run(course, -39, "split", 1 / 30)
		for _, other in ipairs({ b, c }) do
			assert(a.score == other.score and a.subtotal == other.subtotal and a.hitCount == other.hitCount and a.elapsed == other.elapsed)
			assert(a.eventSerial == other.eventSerial and #a.balls == #other.balls)
			for id in pairs(a.hit) do assert(other.hit[id], "Different hit set") end
			for i, ball in ipairs(a.balls) do
				assert(close(ball.x, other.balls[i].x) and close(ball.y, other.balls[i].y), "Ball path differs")
			end
		end
	end)

	test("aim changes direction and resulting path", function()
		local course = Sim.makeBoard(17)
		local left = Sim.newShot(course, { angle = -35 })
		local right = Sim.newShot(course, { angle = 35 })
		assert(left.balls[1].vx < 0 and right.balls[1].vx > 0 and close(left.balls[1].vy, right.balls[1].vy))
		local a, b = run(course, -35, "pulse"), run(course, 35, "pulse")
		assert(a.score ~= b.score or a.hitCount ~= b.hitCount or a.elapsed ~= b.elapsed, "Aiming has no effect")
	end)

	test("a peg scores once and stays solid on the next contact", function()
		local course = board({ peg(1, 500, 200, "orange") })
		local state = firstHit("pulse", course)
		assert(state.hitCount == 1 and state.orangeHits == 1 and state.score == 100 and state.balls[1].vy < 0)
		put(state, 500, 150, 0, 1000)
		Sim.step(state, course, 0.04)
		assert(state.hitCount == 1 and state.subtotal == 100 and state.balls[1].vy < 0 and not state.removed[1])
	end)

	test("continuous collision catches crossed pegs and walls", function()
		local course = board({ peg(1, 500, 200) })
		local state = Sim.newShot(course)
		put(state, 500, 100, 0, 24000)
		Sim.step(state, course, Sim.FIXED_DT)
		assert(state.hitCount == 1, "Fast ball tunneled through peg")
		local wall = Sim.newShot(board())
		put(wall, 985, 300, 15000, 0)
		Sim.step(wall, board(), Sim.FIXED_DT)
		assert(wall.balls[1].x <= Sim.WIDTH - Sim.BALL_RADIUS and wall.balls[1].vx < 0)
	end)

	test("Pulse Pop lights only its radius and keeps targets solid", function()
		local course = board({ peg(1, 500, 200, "green"), peg(2, 590, 240, "orange"), peg(3, 720, 240, "purple") })
		local state = firstHit("pulse", course)
		assert(state.powerUsed and state.hit[1] and state.hit[2] and not state.hit[3] and state.hitCount == 2)
		assert(not state.removed[2] and state.subtotal == 110 and state.score == 220)
	end)

	test("Split Shot makes one extra ball and shares the hit ledger", function()
		local course = board({ peg(1, 500, 200, "green") })
		local state = firstHit("split", course)
		assert(state.powerUsed and #state.balls == 2 and state.balls[1].id ~= state.balls[2].id)
		for _, ball in ipairs(state.balls) do
			ball.x, ball.y, ball.vx, ball.vy = 500, 150, 0, 1000
		end
		Sim.step(state, course, 0.04)
		assert(#state.balls == 2 and state.hitCount == 1 and state.score == 10, "Power retrigger or duplicate scoring")
	end)

	test("Second Wind caps the bucket then returns once at the same x", function()
		local course = board({ peg(1, 500, 200, "green") })
		local state = firstHit("return", course)
		assert(state.returnArmed and state.powerUsed)
		local x = Sim.bucketX(state.elapsed)
		local ball = put(state, x, Sim.BUCKET_Y - 1, 0, 600)
		Sim.step(state, course, Sim.FIXED_DT)
		assert(ball.alive and state.returnArmed and not state.bucketCaught, "Armed bucket captured ball")
		put(state, x, Sim.HEIGHT + Sim.BALL_RADIUS - 1, 0, 600)
		Sim.step(state, course, Sim.FIXED_DT)
		assert(ball.alive and state.returnUsed and not state.returnArmed and ball.y < 25 and close(ball.x, x))
		put(state, 50, Sim.HEIGHT + Sim.BALL_RADIUS - 1, 0, 600)
		Sim.step(state, course, Sim.FIXED_DT)
		assert(state.done and not ball.alive, "Return repeated")
	end)

	test("catch awards ten percent and reopened return bucket can catch", function()
		local course = board({ peg(1, 500, 200, "orange") })
		local state = firstHit("pulse", course)
		put(state, Sim.bucketX(state.elapsed), Sim.BUCKET_Y - 1, 0, 600)
		Sim.step(state, course, Sim.FIXED_DT)
		assert(state.done and state.bucketCaught and state.catchBonus == 10 and state.score == 110)
		local returnCourse = board({ peg(1, 500, 200, "green") })
		local second = firstHit("return", returnCourse)
		put(second, 150, Sim.HEIGHT + Sim.BALL_RADIUS - 1, 0, 600)
		Sim.step(second, returnCourse, Sim.FIXED_DT)
		put(second, Sim.bucketX(second.elapsed), Sim.BUCKET_Y - 1, 0, 600)
		Sim.step(second, returnCourse, Sim.FIXED_DT)
		assert(second.done and second.returnUsed and second.bucketCaught and second.score == 11)
	end)

	test("compressed orange multiplier awards sum times distinct hits", function()
		local course = board({ peg(1, 500, 200, "green") })
		for i = 2, 13 do table.insert(course.pegs, peg(i, 500 + (i - 7) * 3, 250, "orange")) end
		local state = firstHit("pulse", course)
		-- Orange peg awards: 100+100+200+200+200+300+300+300+500+500+500+1000.
		assert(state.orangeHits == 12 and state.hitCount == 13 and state.multiplier == 10)
		assert(state.subtotal == 4210 and state.score == 4210 * 13, "Scoring formula differs")
	end)

	test("short preview uses gravity and ends at first contact", function()
		local course = board({ peg(1, 500, 200) })
		local guide = Sim.preview(course, 0)
		assert(#guide >= 2 and guide[1].x == Sim.LAUNCH_X and guide[1].y == Sim.LAUNCH_Y)
		assert(close(guide[#guide].y, 200 - 12 - Sim.BALL_RADIUS), "Guide passed first peg")
		local angled = Sim.preview(board(), 45)
		local last = angled[#angled]
		assert(last.x > Sim.LAUNCH_X and last.y - Sim.LAUNCH_Y > last.x - Sim.LAUNCH_X, "Gravity missing from guide")
	end)

	test("invalid inputs stay bounded and do not advance time", function()
		local course = Sim.makeBoard(0 / 0)
		assert(course.seed == 1)
		local state = Sim.newShot(course, { angle = math.huge, powerId = "paid" })
		assert(state.angle == 0 and state.powerId == "pulse")
		assert(Sim.newShot(course, { angle = 9000 }).angle == 65 and Sim.newShot(course, { angle = -9000 }).angle == -65)
		for _, dt in ipairs({ -1, 0, math.huge, 0 / 0 }) do Sim.step(state, course, dt) end
		assert(state.elapsed == 0 and state.score == 0)
		state.balls[1].vx = 0 / 0
		Sim.step(state, course, Sim.FIXED_DT)
		assert(state.done and state.balls[1].vx == 0, "Invalid internal ball leaked NaN")
	end)

	test("stuck recovery releases resting ball without clearing fresh pegs", function()
		local course = board({ peg(1, 500, 200), peg(2, 600, 200) })
		local state = Sim.newShot(course)
		put(state, 500, 200 - 12 - Sim.BALL_RADIUS - 0.001, 0, 0)
		for _ = 1, 160 do Sim.step(state, course, Sim.FIXED_DT) end
		assert(state.hit[1] and state.removed[1] and not state.removed[2] and state.balls[1].y > 200)
	end)

	test("hard timeout locks score and huge finite timestep remains bounded", function()
		local course = board()
		local state = Sim.newShot(course)
		state.ticks = math.floor(Sim.MAX_SHOT_TIME / Sim.FIXED_DT) - 1
		state.elapsed = state.ticks * Sim.FIXED_DT
		Sim.step(state, course, Sim.FIXED_DT)
		assert(state.done and state.finishReason == "time limit" and state.elapsed == Sim.MAX_SHOT_TIME)
		local huge = Sim.newShot(course)
		Sim.step(huge, course, 1e100)
		assert(huge.done and huge.elapsed <= Sim.MAX_SHOT_TIME and huge.elapsed > 0)
	end)

	test("all powers and extreme aims finish with bounded events and finite scores", function()
		for _, seed in ipairs({ 1, 987654 }) do
			for _, powerId in ipairs({ "pulse", "split", "return" }) do
				for _, angle in ipairs({ -65, -39, 0, 35, 65 }) do
					local state = run(Sim.makeBoard(seed), angle, powerId)
					assert(state.done and state.elapsed <= Sim.MAX_SHOT_TIME and state.score >= 0 and state.score < math.huge)
					assert(#state.recentEvents <= Sim.EVENT_HISTORY_LIMIT and #state.balls <= 2)
					local lastSerial = 0
					for _, event in ipairs(state.recentEvents) do assert(event.serial > lastSerial); lastSerial = event.serial end
					for _, ball in ipairs(state.balls) do assert(ball.x == ball.x and ball.y == ball.y and not ball.alive) end
					local score, elapsed = state.score, state.elapsed
					Sim.step(state, Sim.makeBoard(seed), 1)
					assert(state.score == score and state.elapsed == elapsed, "Finished shot changed")
				end
			end
		end
	end)

	return "PegSimulation: " .. passed .. " deterministic physics, powers, scoring and safety tests passed"
end
