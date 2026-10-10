--!nonstrict
-- Pure, deterministic 2D shot simulation. The server owns scoring; clients
-- draw these same coordinates. Hit pegs stay solid until shot completion,
-- except the explicit stuck-ball escape. No Roblox physics or random globals.
local PegSimulation = {}
local PegPowers = require(script.Parent.PegPowers)

PegSimulation.WIDTH = 1000
PegSimulation.HEIGHT = 900
PegSimulation.LAUNCH_X = 500
PegSimulation.LAUNCH_Y = 55
PegSimulation.FIXED_DT = 1 / 120
PegSimulation.MAX_SHOT_TIME = 25
PegSimulation.BALL_RADIUS = 9
PegSimulation.LAUNCH_SPEED = 650
PegSimulation.GRAVITY = 690
PegSimulation.RESTITUTION = 0.75
PegSimulation.STUCK_RELEASE_TIME = 0.75
PegSimulation.BUCKET_WIDTH = 155
PegSimulation.BUCKET_Y = 865
PegSimulation.PULSE_RADIUS = 145
PegSimulation.EVENT_HISTORY_LIMIT = 32

local EPSILON = 0.000001
local BASE_VALUE = { blue = 10, orange = 100, green = 10, purple = 500 }

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function cleanAngle(value)
	return finite(value) and clamp(value, -65, 65) or 0
end

local function randomGenerator(seed)
	local current = math.floor(math.abs(seed)) % 2147483646 + 1
	return function()
		current = current * 48271 % 2147483647
		return current / 2147483647
	end
end

function PegSimulation.makeBoard(seed)
	seed = finite(seed) and math.floor(clamp(seed, -2147483646, 2147483646)) or 1
	local board = { seed = seed, width = PegSimulation.WIDTH, height = PegSimulation.HEIGHT, pegs = {} }
	local function peg(x, y, kind)
		table.insert(board.pegs, { id = #board.pegs + 1, x = x, y = y, radius = 14, kind = kind or "blue" })
	end
	-- A reachable high trigger, isolated targets, two original sweeping tracks,
	-- and a low scoring band. Every drawn target is a physical circle.
	peg(380, 185, "green")
	for _, position in ipairs({
		{180, 210}, {260, 250}, {330, 290}, {440, 255}, {520, 205},
		{600, 255}, {670, 290}, {740, 250}, {820, 210}, {500, 310},
	}) do
		peg(position[1], position[2])
	end
	for i = 0, 20 do
		local t = i / 20
		peg(160 + 680 * t, 340 + 100 * math.sin(t * math.pi))
	end
	for i = 0, 5 do
		peg(80, 350 + i * 75)
		peg(920, 350 + i * 75)
	end
	for i = 0, 16 do
		local t = i / 16
		peg(210 + 580 * t, 655 - 125 * math.sin(t * math.pi))
	end
	for i = 0, 10 do
		peg(150 + i * 70, 770 + (i % 2) * 25)
	end
	board.pegs[59].kind = "purple"
	local candidates = {}
	for _, target in ipairs(board.pegs) do
		if target.kind == "blue" then table.insert(candidates, target) end
	end
	local random = randomGenerator(seed)
	for i = #candidates, 2, -1 do
		local j = math.floor(random() * i) + 1
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end
	for i = 1, 15 do candidates[i].kind = "orange" end
	return board
end

function PegSimulation.bucketX(elapsed)
	elapsed = finite(elapsed) and elapsed or 0
	return PegSimulation.WIDTH / 2 + 340 * math.sin(elapsed * 1.12)
end

local function emit(state, kind, x, y, pegId, value, text)
	state.eventSerial = state.eventSerial + 1
	table.insert(state.recentEvents, {
		serial = state.eventSerial, kind = kind, x = x, y = y,
		pegId = pegId, value = value, text = text,
	})
	if #state.recentEvents > PegSimulation.EVENT_HISTORY_LIMIT then
		table.remove(state.recentEvents, 1)
	end
end

local function refreshScore(state)
	local pegScore = state.subtotal * state.hitCount
	state.catchBonus = state.bucketCaught and math.floor(pegScore * 0.1 + 0.5) or 0
	state.score = pegScore + state.catchBonus
end

local function multiplier(orangeHits)
	if orangeHits >= 12 then return 10 end
	if orangeHits >= 9 then return 5 end
	if orangeHits >= 6 then return 3 end
	if orangeHits >= 3 then return 2 end
	return 1
end

local function awardPeg(state, target)
	if state.hit[target.id] then return false end
	state.hit[target.id] = true
	state.hitCount = state.hitCount + 1
	if target.kind == "orange" then
		state.orangeHits = state.orangeHits + 1
		state.multiplier = multiplier(state.orangeHits)
	end
	local value = (BASE_VALUE[target.kind] or 10) * state.multiplier
	state.subtotal = state.subtotal + value
	refreshScore(state)
	emit(state, "hit", target.x, target.y, target.id, value)
	return true
end

local function activatePower(state, board, target, ball)
	if state.powerUsed or target.kind ~= "green" then return end
	state.powerUsed = true
	emit(state, "power", target.x, target.y, target.id, nil, PegPowers.get(state.powerId).name)
	if state.powerId == "pulse" then
		for _, nearby in ipairs(board.pegs) do
			local dx, dy = nearby.x - target.x, nearby.y - target.y
			if dx * dx + dy * dy <= PegSimulation.PULSE_RADIUS * PegSimulation.PULSE_RADIUS then
				awardPeg(state, nearby)
			end
		end
	elseif state.powerId == "split" then
		local horizontal = ball.vx >= 0 and -260 or 260
		table.insert(state.balls, {
			id = #state.balls + 1, x = ball.x, y = ball.y,
			vx = horizontal, vy = -math.max(220, math.abs(ball.vy) * 0.7), alive = true,
			anchorX = ball.x, anchorY = ball.y, stuckTime = 0,
		})
	elseif state.powerId == "return" then
		state.returnArmed = true
	end
end

function PegSimulation.newShot(board, settings)
	settings = type(settings) == "table" and settings or {}
	local angle = cleanAngle(settings.angle)
	local powerId = PegPowers.isValid(settings.powerId) and settings.powerId or PegPowers.DEFAULT_ID
	local radians = angle * math.pi / 180
	local state = {
		elapsed = 0, done = false, score = 0, subtotal = 0, hitCount = 0,
		orangeHits = 0, multiplier = 1, hit = {}, removed = {},
		balls = {{
			id = 1, x = PegSimulation.LAUNCH_X, y = PegSimulation.LAUNCH_Y,
			vx = math.sin(radians) * PegSimulation.LAUNCH_SPEED,
			vy = math.cos(radians) * PegSimulation.LAUNCH_SPEED, alive = true,
			anchorX = PegSimulation.LAUNCH_X, anchorY = PegSimulation.LAUNCH_Y, stuckTime = 0,
		}},
		angle = angle, powerId = powerId, powerUsed = false,
		returnArmed = false, returnUsed = false, bucketCaught = false, catchBonus = 0,
		recentEvents = {}, eventSerial = 0, accumulator = 0, ticks = 0,
	}
	emit(state, "launch", PegSimulation.LAUNCH_X, PegSimulation.LAUNCH_Y)
	return state
end

-- Earliest impact on an expanded circle, measured in seconds along velocity.
-- The sweep catches high-speed contacts even when both endpoints miss.
local function circleTime(x, y, vx, vy, target, duration)
	local dx, dy = x - target.x, y - target.y
	local radius = PegSimulation.BALL_RADIUS + target.radius
	local c = dx * dx + dy * dy - radius * radius
	local approach = dx * vx + dy * vy
	if c < EPSILON then
		if approach < -EPSILON then return 0 end
		return nil
	end
	if approach >= 0 then return nil end
	local speedSquared = vx * vx + vy * vy
	if speedSquared < EPSILON then return nil end
	local discriminant = approach * approach - speedSquared * c
	if discriminant < 0 then return nil end
	local time = (-approach - math.sqrt(discriminant)) / speedSquared
	if time >= -EPSILON and time <= duration + EPSILON then return math.max(0, time) end
	return nil
end

local function validPeg(target)
	return type(target) == "table" and finite(target.id) and finite(target.x) and finite(target.y)
		and finite(target.radius) and target.radius > 0
end

local function nextCollision(ball, board, removed, duration)
	local time, kind, peg = duration, nil, nil
	local function consider(candidate, candidateKind, candidatePeg)
		if candidate and candidate >= 0 and candidate <= time then
			time, kind, peg = candidate, candidateKind, candidatePeg
		end
	end
	local r = PegSimulation.BALL_RADIUS
	if ball.vx < -EPSILON then consider(math.max(0, (r - ball.x) / ball.vx), "left") end
	if ball.vx > EPSILON then consider(math.max(0, (PegSimulation.WIDTH - r - ball.x) / ball.vx), "right") end
	if ball.vy < -EPSILON then consider(math.max(0, (r - ball.y) / ball.vy), "top") end
	for _, target in ipairs(board.pegs) do
		if validPeg(target) and not removed[target.id] then
			consider(circleTime(ball.x, ball.y, ball.vx, ball.vy, target, duration), "peg", target)
		end
	end
	return time, kind, peg
end

local function finish(state, reason)
	if state.done then return end
	state.done = true
	state.finishReason = reason
	for _, ball in ipairs(state.balls) do ball.alive = false end
	refreshScore(state)
	emit(state, "finish", PegSimulation.WIDTH / 2, PegSimulation.HEIGHT / 2, nil, state.score, reason)
end

local function moveBall(state, board, ball, dt, tickStart)
	if not (finite(ball.x) and finite(ball.y) and finite(ball.vx) and finite(ball.vy)) then
		ball.x, ball.y, ball.vx, ball.vy, ball.alive = PegSimulation.LAUNCH_X, PegSimulation.LAUNCH_Y, 0, 0, false
		return
	end
	ball.vy = ball.vy + PegSimulation.GRAVITY * dt
	local remaining, used = dt, 0
	for _ = 1, 10 do
		if remaining <= EPSILON or not ball.alive then break end
		local time, kind, target = nextCollision(ball, board, state.removed, remaining)
		-- Resolve the bucket and return at their actual crossing time, before
		-- later peg/wall contacts. The armed return temporarily caps the bucket.
		if ball.vy > EPSILON then
			if not state.returnArmed and ball.y <= PegSimulation.BUCKET_Y then
				local catchTime = (PegSimulation.BUCKET_Y - ball.y) / ball.vy
				local catchX = ball.x + ball.vx * catchTime
				local center = PegSimulation.bucketX(tickStart + used + catchTime)
				if catchTime >= 0 and catchTime <= time and math.abs(catchX - center) <= PegSimulation.BUCKET_WIDTH / 2 - PegSimulation.BALL_RADIUS then
					time, kind, target = catchTime, "bucket", nil
				end
			end
			local exitTime = (PegSimulation.HEIGHT + PegSimulation.BALL_RADIUS - ball.y) / ball.vy
			if exitTime >= 0 and exitTime <= time then time, kind, target = exitTime, "exit", nil end
		end
		ball.x, ball.y = ball.x + ball.vx * time, ball.y + ball.vy * time
		remaining, used = remaining - time, used + time
		if kind == "peg" then
			local dx, dy = ball.x - target.x, ball.y - target.y
			local distance = math.sqrt(dx * dx + dy * dy)
			local nx, ny = 0, -1
			if distance > EPSILON then nx, ny = dx / distance, dy / distance end
			local approach = ball.vx * nx + ball.vy * ny
			if approach < 0 then
				ball.vx = ball.vx - (1 + PegSimulation.RESTITUTION) * approach * nx
				ball.vy = ball.vy - (1 + PegSimulation.RESTITUTION) * approach * ny
			end
			ball.x = target.x + nx * (target.radius + PegSimulation.BALL_RADIUS + 0.001)
			ball.y = target.y + ny * (target.radius + PegSimulation.BALL_RADIUS + 0.001)
			if awardPeg(state, target) then activatePower(state, board, target, ball) end
		elseif kind == "left" then
			ball.x, ball.vx = PegSimulation.BALL_RADIUS + 0.001, math.abs(ball.vx) * 0.92
		elseif kind == "right" then
			ball.x, ball.vx = PegSimulation.WIDTH - PegSimulation.BALL_RADIUS - 0.001, -math.abs(ball.vx) * 0.92
		elseif kind == "top" then
			ball.y, ball.vy = PegSimulation.BALL_RADIUS + 0.001, math.abs(ball.vy) * 0.83
		elseif kind == "bucket" then
			ball.alive = false
			if not state.bucketCaught then
				state.bucketCaught = true
				refreshScore(state)
				emit(state, "catch", ball.x, ball.y, nil, state.catchBonus, "BUCKET BONUS")
			end
		elseif kind == "exit" then
			if state.returnArmed then
				state.returnArmed, state.returnUsed = false, true
				ball.y = PegSimulation.BALL_RADIUS + 0.001
				ball.vy = math.min(math.max(ball.vy, 350), 850)
				ball.anchorX, ball.anchorY, ball.stuckTime = ball.x, ball.y, 0
				emit(state, "return", ball.x, ball.y, nil, nil, "SECOND WIND")
			else
				ball.alive = false
			end
		else
			break
		end
	end
	-- A ball trapped on illuminated circles must not wait for the hard limit.
	-- Measure local displacement rather than instantaneous speed at bounce apex.
	local dx, dy = ball.x - ball.anchorX, ball.y - ball.anchorY
	if dx * dx + dy * dy < 18 * 18 then
		ball.stuckTime = ball.stuckTime + dt
	else
		ball.anchorX, ball.anchorY, ball.stuckTime = ball.x, ball.y, 0
	end
	if ball.alive and ball.stuckTime >= PegSimulation.STUCK_RELEASE_TIME then
		for _, target in ipairs(board.pegs) do
			if state.hit[target.id] and not state.removed[target.id] then
				local tx, ty = ball.x - target.x, ball.y - target.y
				local reach = target.radius + PegSimulation.BALL_RADIUS + 24
				if tx * tx + ty * ty < reach * reach then
					state.removed[target.id] = true
					emit(state, "stuck", target.x, target.y, target.id, nil, "KEEP IT MOVING")
				end
			end
		end
		ball.vx, ball.vy = (ball.id % 2 == 0 and -1 or 1) * 45, 125
		ball.anchorX, ball.anchorY, ball.stuckTime = ball.x, ball.y, 0
	end
end

function PegSimulation.step(state, board, dt)
	if state.done then return state end
	dt = dt == nil and PegSimulation.FIXED_DT or dt
	if not finite(dt) or dt <= 0 then return state end
	if type(board) ~= "table" or type(board.pegs) ~= "table" then
		finish(state, "invalid board")
		return state
	end
	state.accumulator = state.accumulator + math.min(dt, PegSimulation.MAX_SHOT_TIME)
	while state.accumulator + EPSILON >= PegSimulation.FIXED_DT and not state.done do
		state.accumulator = math.max(0, state.accumulator - PegSimulation.FIXED_DT)
		local tickStart = state.ticks * PegSimulation.FIXED_DT
		state.ticks = state.ticks + 1
		state.elapsed = state.ticks * PegSimulation.FIXED_DT
		-- A newly split ball starts on the next tick, independent of ipairs
		-- append behavior and clients' heartbeat chunk sizes.
		local ballCount = #state.balls
		for index = 1, ballCount do
			local ball = state.balls[index]
			if ball.alive then moveBall(state, board, ball, PegSimulation.FIXED_DT, tickStart) end
		end
		local anyAlive = false
		for _, ball in ipairs(state.balls) do if ball.alive then anyAlive = true end end
		if not anyAlive then finish(state, "complete") end
		if state.elapsed >= PegSimulation.MAX_SHOT_TIME then finish(state, "time limit") end
	end
	return state
end

function PegSimulation.preview(board, angle)
	angle = cleanAngle(angle)
	local radians = angle * math.pi / 180
	local ball = {
		x = PegSimulation.LAUNCH_X, y = PegSimulation.LAUNCH_Y,
		vx = math.sin(radians) * PegSimulation.LAUNCH_SPEED,
		vy = math.cos(radians) * PegSimulation.LAUNCH_SPEED,
	}
	local points = {{ x = ball.x, y = ball.y }}
	if type(board) ~= "table" or type(board.pegs) ~= "table" then return points end
	for i = 1, 48 do
		ball.vy = ball.vy + PegSimulation.GRAVITY * PegSimulation.FIXED_DT
		local time, kind = nextCollision(ball, board, {}, PegSimulation.FIXED_DT)
		ball.x, ball.y = ball.x + ball.vx * time, ball.y + ball.vy * time
		if i % 3 == 0 or kind then table.insert(points, { x = ball.x, y = ball.y }) end
		if kind then break end
	end
	return points
end

return PegSimulation
