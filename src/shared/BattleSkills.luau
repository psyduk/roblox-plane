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
--   inPosition(api, state, fighter, opponent, dx, dy) -> boolean
--   approach(api, state, fighter, opponent, dx, dy) -> targetX, targetY, speed, turnRate
--   windupStart(api, state, fighter, opponent)
--   windupMove(api, state, fighter) -> targetX, targetY, speed, turnRate
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
	earliest = 1.0, leadSpeed = 90, leadFactor = 0.35,
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
	windup = 2.4, attackTime = 1.3, attackSpeed = 65,
	earliest = 1.7, leadSpeed = 72, leadFactor = 0.45, ram = "pinball", wallRam = true,
	-- The rebound is the hardest attack to dodge, so it comes round less often.
	approachTime = 3.2, recoveryTime = 2.2,
	inPosition = function(_, _, _, _, dx, dy) return dx * dx + dy * dy < 85 * 85 end,
	windupStart = function(_, state, fighter, opponent)
		local b = state.bounds
		local nearest, edge = math.huge, "left"
		for _, candidate in ipairs({ { "left", fighter.x - b.left }, { "right", b.right - fighter.x },
			{ "bottom", fighter.y - b.bottom }, { "top", b.top - fighter.y } }) do
			if candidate[2] < nearest then nearest, edge = candidate[2], candidate[1] end
		end
		-- The virtual rival is reflected across the selected rail. Following
		-- this visible straight run-up produces a real specular rebound.
		local predictedX = math.max(b.left + 8, math.min(b.right - 8, opponent.x + opponent.vx * 0.65))
		local predictedY = math.max(b.bottom + 8, math.min(b.top - 8, opponent.y + opponent.vy * 0.65))
		fighter._bankX, fighter._bankY = predictedX, predictedY
		if edge == "left" or edge == "right" then
			fighter._bankX = 2 * b[edge] - predictedX
		else fighter._bankY = 2 * b[edge] - predictedY end
	end,
	windupMove = function(_, _, fighter) return fighter._bankX, fighter._bankY, 45, 8 end,
	attack = function(api, state, fighter, opponent)
		local entry = api.event(state, "ricochet", fighter.x, fighter.y, fighter.id, opponent.id, "pinball", "Pinball")
		entry.heading = fighter._attackHeading
	end,
}

BattleSkills.wild.Afterburner = {
	duration = 0.9,
	start = function(_, _, fighter)
		fighter._boostPending = false
	end,
	attack = function(_, _, fighter)
		fighter._boostPending = true
	end,
	recover = function(api, state, fighter)
		if not fighter._boostPending then return end
		fighter.boostLeft = BattleSkills.wild.Afterburner.duration
		fighter._boostPending = false
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, 0, "afterburner", "Afterburner")
	end,
}

BattleSkills.wild.SpringBumper = {
	start = function(_, _, fighter)
		fighter.bumperReady = true
	end,
	hit = function(api, state, target, actor, x, y, dirX, dirY, source)
		if not target.bumperReady then return false end
		target.bumperReady = false
		-- The spring absorbs a whole hit, but its visible recoil banks the
		-- defender longer before the next attack. It never weakens the block.
		target._bumperRecovery = 0.7
		target.invulnerable = api.IMPACT_PROTECTION
		target._knockX, target._knockY = dirX * 32, dirY * 32
		actor._knockX, actor._knockY = -dirX * 24, -dirY * 24
		api.event(state, "blocked", x, y, target.id, actor.id, source, "SpringBumper")
		return true
	end,
}

BattleSkills.wild.FizzyFuel = {
	start = function(_, _, fighter)
		fighter._wakeLeft, fighter._wakeNext = 0, 0
	end,
	attack = function(api, state, fighter)
		fighter._wakeLeft, fighter._wakeNext = 0.8, 0
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, 0, "wake", "FizzyFuel")
	end,
	moved = function(api, state, fighter, dt)
		-- Committing spills fuel for 0.8s, including the beginning of the bank if
		-- the strike connects immediately. Otherwise successful attacks leave no
		-- useful trail for a rival to cross on the next approach.
		if fighter._wakeLeft <= 0 then return end
		fighter._wakeLeft = math.max(0, fighter._wakeLeft - dt)
		fighter._wakeNext = fighter._wakeNext - dt
		if fighter._wakeNext > 0 then return end
		fighter._wakeNext = fighter._wakeNext + 0.16
		api.puff(state, fighter, fighter.x - math.cos(fighter.heading) * 12,
			fighter.y - math.sin(fighter.heading) * 12, "FizzyFuel")
	end,
}

BattleSkills.wild.Magnet = {
	start = function(_, _, fighter) fighter.magnetLeft = 0 end,
	-- The pull starts with the strike, so it drags the rival into the attack
	-- instead of into the owner's unguarded turn away.
	attack = function(api, state, fighter)
		fighter.magnetLeft = 1
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, 0, "magnet", "Magnet")
	end,
}

BattleSkills.wild.SecondWind = {
	start = function(_, _, fighter) fighter.secondWind = false end,
	damaged = function(api, state, fighter)
		if fighter.armor ~= 1 or fighter.secondWind then return end
		fighter.secondWind = true
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, 0, "secondwind", "SecondWind")
	end,
}

return BattleSkills
