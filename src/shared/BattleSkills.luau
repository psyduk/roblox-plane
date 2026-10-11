-- How each skill behaves in a fight. One table per skill, keyed by the same id
-- as its SkillCatalog entry. BattleSimulation owns the round and calls these
-- hooks; a skill never reaches into another skill. Pure and deterministic: no
-- Roblox services, no math.random, no clocks.
--
-- Every hook receives `api` first (BattleSimulation's helpers: event, clamp,
-- direction, launch, puff). `opponent` is usually the rival's position from
-- before this tick, so only its id, x, y, vx and vy are safe to read. That is
-- what keeps the first player from getting an advantage.
--
-- Offence fields (numbers are required, hooks are optional):
--   windup, attackTime   seconds spent charging, then attacking
--   attackSpeed          flight speed while attacking
--   earliest             an approach may end this many seconds early if inPosition
--   leadSpeed, leadFactor  how far ahead of the rival the attack aims
--   ram                  set to a source name if the plane's nose is the weapon
-- A launched projectile may carry `bounces`: it reflects off the arena edge that
-- many times before it can leave.
--   inPosition(api, state, fighter, opponent, dx, dy) -> boolean
--   approach(api, state, fighter, opponent, dx, dy) -> targetX, targetY, speed, turnRate
--   windupStart(api, state, fighter, opponent)
--   windupMove(api, state, fighter, opponent) -> targetX, targetY, speed, turnRate
--   attack(api, state, fighter, opponent)
-- A movement hook may return nil for any value to keep the default.
--
-- Wild card hooks (all optional):
--   start(api, state, fighter)              once, when the round is made
--   attack(api, state, fighter, opponent)   the moment an attack is committed
--   recover(api, state, fighter, opponent)  when the plane banks away
--   moved(api, state, fighter, dt)          every tick, after the plane moves
--   hit(api, state, target, actor, x, y, dirX, dirY, source) -> true to cancel the hit
local BattleSkills = { offence = {}, wild = {} }

local PI = math.pi

BattleSkills.offence.Meteor = {
	windup = 1, aimTime = 0.4, attackTime = 1.05, attackSpeed = 65,
	earliest = 1.85, leadSpeed = 65, leadFactor = 0.85, ram = "meteor",
	inPosition = function(_, _, fighter, opponent, dx)
		return fighter.y >= opponent.y + 8 and math.abs(dx) < 68
	end,
	approach = function(api, state, _, opponent, dx)
		return api.clamp(opponent.x - (dx >= 0 and 18 or -18), state.bounds.left + 10, state.bounds.right - 10),
			math.min(state.bounds.top - 8, opponent.y + 28), 31
	end,
	windupStart = function(api, state, fighter, opponent)
		-- Pull away before aiming so a pursuing rival cannot simply sit
		-- inside the armed nose at release. The waypoint stays fixed for
		-- this charge and is reached through a bounded turn. Choose open
		-- space locally: blindly climbing at the ceiling or reversing at
		-- a side wall would erase the very separation this arc creates.
		local best = -math.huge
		for index = 0, 7 do
			local angle = index * PI / 4
			local x = api.clamp(fighter.x + math.cos(angle) * 46, state.bounds.left + 9, state.bounds.right - 9)
			local y = api.clamp(fighter.y + math.sin(angle) * 46, state.bounds.bottom + 9, state.bounds.top - 9)
			local score = (x - opponent.x) ^ 2 + (y - opponent.y) ^ 2 +
				0.35 * ((x - fighter.x) ^ 2 + (y - fighter.y) ^ 2)
			if score > best then
				best, fighter._chargeX, fighter._chargeY = score, x, y
			end
		end
	end,
	windupMove = function(_, _, fighter)
		if fighter.phaseLeft > BattleSkills.offence.Meteor.aimTime then
			return fighter._chargeX, fighter._chargeY, 60, 5.5
		end
		return nil, nil, 5, 8
	end,
	attack = function(api, state, fighter, opponent)
		-- A dive can connect and recover before the next network snapshot.
		-- Preserve the committed moment for presentation without delaying it.
		local commitment = api.event(state, "dive", fighter.x, fighter.y, fighter.id, opponent.id, "meteor")
		commitment.heading = fighter._attackHeading
	end,
}

BattleSkills.offence.Firework = {
	windup = 1, attackTime = 0.5, attackSpeed = 27,
	earliest = 1.1, leadSpeed = 60, leadFactor = 0.55,
	inPosition = function(_, _, _, _, dx, dy)
		return dx * dx + dy * dy < 76 * 76
	end,
	attack = function(api, state, fighter, opponent)
		local dx, dy = math.cos(fighter.heading), math.sin(fighter.heading)
		api.launch(state, fighter, {
			x = fighter.x + dx * 7, y = fighter.y + dy * 7,
			vx = dx * 60, vy = dy * 60, life = 2.4, radius = 3.5,
		})
		api.event(state, "rocket", fighter.x + dx * 7, fighter.y + dy * 7, fighter.id, opponent.id)
	end,
}

BattleSkills.offence.MachineGun = {
	windup = 0.65, attackTime = 0.65, attackSpeed = 25,
	earliest = 0.95, leadSpeed = 90, leadFactor = 0.35,
	approachTime = 2.9, recoveryTime = 2,
	inPosition = function(_, _, _, _, dx, dy) return dx * dx + dy * dy < 68 * 68 end,
	attack = function(api, state, fighter, opponent)
		fighter._burstNext, fighter._burstShots = 0, 0
		fighter.burstConnections, fighter.burstCancelled, fighter._burstDamaged = 0, false, false
		api.event(state, "burst", fighter.x, fighter.y, fighter.id, opponent.id, "machinegun", "MachineGun")
	end,
	attackTick = function(api, state, fighter, dt)
		fighter._burstNext = fighter._burstNext - dt
		if fighter._burstShots >= 6 or fighter._burstNext > 0 then return end
		fighter._burstShots = fighter._burstShots + 1
		fighter._burstNext = fighter._burstNext + 0.1
		local dx, dy = math.cos(fighter._attackHeading), math.sin(fighter._attackHeading)
		api.launch(state, fighter, { x = fighter.x + dx * 7, y = fighter.y + dy * 7,
			vx = dx * 90, vy = dy * 90, life = 0.8, radius = 1.2,
			source = "machinegun", burstId = fighter.attacks })
	end,
}

BattleSkills.offence.Pinball = {
	windup = 1, attackTime = 0.5, attackSpeed = 27,
	earliest = 1.15, leadSpeed = 72, leadFactor = 0.45,
	ballSpeed = 78, ballLife = 3.4, ballRadius = 3.2, bounces = 3,
	inPosition = function(_, _, _, _, dx, dy) return dx * dx + dy * dy < 85 * 85 end,
	windupStart = function(_, state, fighter)
		-- Bank off whichever wall is nearest when the charge begins.
		local b = state.bounds
		local nearest = math.huge
		for _, candidate in ipairs({ { "left", fighter.x - b.left }, { "right", b.right - fighter.x },
			{ "bottom", fighter.y - b.bottom }, { "top", b.top - fighter.y } }) do
			if candidate[2] < nearest then nearest, fighter._bankEdge = candidate[2], candidate[1] end
		end
	end,
	windupMove = function(api, state, fighter, opponent)
		-- Aim at the rival's reflection in the chosen wall, so the shot that
		-- leaves the nose reaches them after one real bounce.
		local b, self = state.bounds, BattleSkills.offence.Pinball
		local edge = fighter._bankEdge or "left"
		local function mirrored(x, y)
			if edge == "left" or edge == "right" then return 2 * b[edge] - x, y end
			return x, 2 * b[edge] - y
		end
		local mx, my = mirrored(opponent.x, opponent.y)
		local lead = math.sqrt((mx - fighter.x) ^ 2 + (my - fighter.y) ^ 2) / self.ballSpeed * self.leadFactor
		mx, my = mirrored(api.clamp(opponent.x + opponent.vx * lead, b.left + 6, b.right - 6),
			api.clamp(opponent.y + opponent.vy * lead, b.bottom + 6, b.top - 6))
		fighter._bankX, fighter._bankY = mx, my
		return mx, my, 9, 6
	end,
	attack = function(api, state, fighter, opponent)
		local self = BattleSkills.offence.Pinball
		local dx, dy = math.cos(fighter.heading), math.sin(fighter.heading)
		api.launch(state, fighter, {
			x = fighter.x + dx * 7, y = fighter.y + dy * 7,
			vx = dx * self.ballSpeed, vy = dy * self.ballSpeed, life = self.ballLife, radius = self.ballRadius,
			source = "pinball", bounces = self.bounces,
		})
		local entry = api.event(state, "ricochet", fighter.x + dx * 7, fighter.y + dy * 7, fighter.id, opponent.id, "pinball", "Pinball")
		entry.heading = fighter.heading
	end,
}

-- Rush: after you attack, the trip back to your next attack is much shorter.
BattleSkills.wild.Afterburner = {
	duration = 0.9, tempo = 0.95,
	start = function(_, _, fighter)
		fighter._boostPending = false
	end,
	attack = function(_, _, fighter)
		fighter._boostPending = true
	end,
	recover = function(api, state, fighter)
		if not fighter._boostPending then return end
		fighter.boostLeft = BattleSkills.wild.Afterburner.duration
		fighter.tempo = BattleSkills.wild.Afterburner.tempo
		fighter._boostPending = false
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, 0, "afterburner", "Afterburner")
	end,
}

-- Block: the first hit bounces off, at the cost of a slow turn back.
BattleSkills.wild.SpringBumper = {
	recoil = 1.4,
	start = function(_, _, fighter)
		fighter.bumperReady = true
	end,
	hit = function(api, state, target, actor, x, y, dirX, dirY, source)
		if not target.bumperReady then return false end
		target.bumperReady = false
		-- The spring absorbs a whole hit, but its visible recoil banks the
		-- defender longer before the next attack. It never weakens the block.
		target._bumperRecovery = BattleSkills.wild.SpringBumper.recoil
		target.invulnerable = api.IMPACT_PROTECTION
		target._knockX, target._knockY = dirX * 32, dirY * 32
		actor._knockX, actor._knockY = -dirX * 24, -dirY * 24
		api.event(state, "blocked", x, y, target.id, actor.id, source, "SpringBumper")
		return true
	end,
}

-- Trap: every attack leaves a wall of fizz that hangs in the air.
BattleSkills.wild.FizzyFuel = {
	spill = 1.0, every = 0.18, cloudLife = 2.2, cloudRadius = 3.6,
	start = function(_, _, fighter)
		fighter._wakeLeft, fighter._wakeNext = 0, 0
	end,
	attack = function(api, state, fighter)
		fighter._wakeLeft, fighter._wakeNext = BattleSkills.wild.FizzyFuel.spill, 0
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, 0, "wake", "FizzyFuel")
	end,
	moved = function(api, state, fighter, dt)
		-- Committing spills fuel, including the beginning of the bank away if
		-- the strike connects at once, so the cloud wall always gets laid.
		local self = BattleSkills.wild.FizzyFuel
		if fighter._wakeLeft <= 0 then return end
		fighter._wakeLeft = math.max(0, fighter._wakeLeft - dt)
		fighter._wakeNext = fighter._wakeNext - dt
		if fighter._wakeNext > 0 then return end
		fighter._wakeNext = fighter._wakeNext + self.every
		api.puff(state, fighter, fighter.x - math.cos(fighter.heading) * 12,
			fighter.y - math.sin(fighter.heading) * 12, "FizzyFuel", { life = self.cloudLife, radius = self.cloudRadius })
	end,
}

-- Pull: one hard yank drags the rival toward you as you strike.
BattleSkills.wild.Magnet = {
	duration = 0.8,
	start = function(_, _, fighter) fighter.magnetLeft = 0 end,
	attack = function(api, state, fighter)
		fighter.magnetLeft = BattleSkills.wild.Magnet.duration
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, 0, "magnet", "Magnet")
	end,
}

-- Comeback: on the last armor the plane flies faster and attacks sooner.
BattleSkills.wild.SecondWind = {
	start = function(_, _, fighter) fighter.secondWind = false end,
	damaged = function(api, state, fighter)
		if fighter.armor ~= 1 or fighter.secondWind then return end
		fighter.secondWind = true
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, 0, "secondwind", "SecondWind")
	end,
}

return BattleSkills
