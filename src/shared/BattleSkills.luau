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
	earliest = 1.45, leadSpeed = 65, leadFactor = 0.85, ram = "meteor",
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
	windup = 1.05, attackTime = 0.5, attackSpeed = 27,
	earliest = 1.05, leadSpeed = 40, leadFactor = 0.35,
	inPosition = function(_, _, _, _, dx, dy)
		return dx * dx + dy * dy < 76 * 76
	end,
	attack = function(api, state, fighter, opponent)
		local dx, dy = math.cos(fighter.heading), math.sin(fighter.heading)
		api.launch(state, fighter, {
			x = fighter.x + dx * 7, y = fighter.y + dy * 7,
			vx = dx * 40, vy = dy * 40, life = 3.5, radius = 3.5,
		})
		api.event(state, "rocket", fighter.x + dx * 7, fighter.y + dy * 7, fighter.id, opponent.id)
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
		api.puff(state, fighter, fighter.x - math.cos(fighter.heading) * 8,
			fighter.y - math.sin(fighter.heading) * 8, "FizzyFuel")
	end,
}

return BattleSkills
