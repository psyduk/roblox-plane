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
--   release(api, state, fighter, opponent)   as the attack ends, before the plane banks away
-- `range` says how close the attack must be; a Mothership's drones honour it.
-- An attack hook may be run for a drone: `fighter` is then a stand-in at the
-- drone's position, so read where the attack starts from only through it.
-- A movement hook may return nil for any value to keep the default.
--
-- Wild card hooks (all optional):
--   start(api, state, fighter)              once, when the round is made
--   attack(api, state, fighter, opponent)   the moment an attack is committed
--   recover(api, state, fighter, opponent)  when the plane banks away
--   moved(api, state, fighter, dt)          every tick, after the plane moves
--   hit(api, state, target, actor, x, y, dirX, dirY, source) -> true to cancel the hit
--   damaged(api, state, fighter, actor)     after this plane loses armor
--   landed(api, state, fighter, target)     after this plane's hit removes armor
--
-- A wild card may reshape its plane in `start`: armor and maxArmor, radius and
-- scale (how big it is and looks), speedScale, shotScale and squad (how many
-- planes fly, one per armor left). `form` names an entry in BattleSkills.form
-- that replaces the plane's attack for the rest of the round.
local BattleSkills = { offence = {}, wild = {}, form = {} }

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
	steal = true,
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
	steal = true,
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
	steal = true,
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
	steal = true,
	duration = 0.8,
	start = function(_, _, fighter) fighter.magnetLeft = 0 end,
	attack = function(api, state, fighter)
		fighter.magnetLeft = BattleSkills.wild.Magnet.duration
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, 0, "magnet", "Magnet")
	end,
}

-- Comeback: on the last armor the plane flies faster and attacks sooner.
BattleSkills.wild.SecondWind = {
	steal = true,
	start = function(_, _, fighter) fighter.secondWind = false end,
	damaged = function(api, state, fighter)
		if fighter.armor ~= 1 or fighter.secondWind then return end
		fighter.secondWind = true
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, 0, "secondwind", "SecondWind")
	end,
}

-- Swarm: three small planes with one life each, all firing your attack.
BattleSkills.wild.Squadron = {
	count = 3, size = 0.62,
	start = function(_, _, fighter)
		local self = BattleSkills.wild.Squadron
		fighter.squad = self.count
		fighter.scale, fighter.radius = fighter.scale * self.size, fighter.radius * self.size
	end,
}

-- Huge: double size and an extra armor, but slow and easy to hit.
BattleSkills.wild.Giant = {
	armor = 1, size = 1.9, speed = 0.86, shot = 1.7,
	start = function(_, _, fighter)
		local self = BattleSkills.wild.Giant
		fighter.armor = fighter.armor + self.armor
		fighter.maxArmor = fighter.armor
		fighter.scale, fighter.radius = fighter.scale * self.size, fighter.radius * self.size
		fighter.speedScale, fighter.shotScale = fighter.speedScale * self.speed, fighter.shotScale * self.shot
	end,
}

-- Hungry: start one armor down, but every hit you land steals one back.
BattleSkills.wild.Vampire = {
	most = 5,
	start = function(_, _, fighter)
		fighter.armor = math.max(1, fighter.armor - 1)
	end,
	landed = function(api, state, fighter, target)
		-- A pilot on a parachute has one life and nothing adds to it.
		if fighter.armor <= 0 or fighter.ejected or fighter.armor >= BattleSkills.wild.Vampire.most then return end
		fighter.armor = fighter.armor + 1
		fighter.maxArmor = math.max(fighter.maxArmor, fighter.armor)
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, target.id, "vampire", "Vampire")
	end,
}

-- Curse: your first hit turns the rival into a chicken that cannot attack.
BattleSkills.wild.Chicken = {
	steal = true,
	duration = 3,
	start = function(_, _, fighter) fighter.chickenReady = true end,
	landed = function(api, state, fighter, target)
		if not fighter.chickenReady or target.armor <= 0 then return end
		fighter.chickenReady = false
		target.chickenLeft = BattleSkills.wild.Chicken.duration
		api.event(state, "skill", target.x, target.y, fighter.id, target.id, "chicken", "Chicken")
	end,
}

-- Last chance: when the plane is shot down, the pilot bails out on a parachute
-- with a pea-shooter and one more life.
BattleSkills.wild.Eject = {
	steal = true,
	size = 0.6, hitbox = 5.5, speed = 0.5, protection = 1,
	start = function(_, _, fighter) fighter.ejected = false end,
	damaged = function(api, state, fighter)
		if fighter.armor > 0 or fighter.ejected then return end
		local self = BattleSkills.wild.Eject
		fighter.ejected, fighter.armor = true, 1
		fighter.form, fighter.windupDuration = "PeaShooter", BattleSkills.form.PeaShooter.windup
		fighter.squad, fighter.shotScale = 0, 1
		fighter.radius = self.hitbox
		fighter.scale, fighter.speedScale = self.size, self.speed
		fighter.invulnerable = self.protection
		fighter.chickenLeft, fighter.secondWind = 0, false
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, 0, "eject", "Eject")
	end,
}

-- The parachuting pilot's attack: quick, small and easy to miss with.
BattleSkills.form.PeaShooter = {
	windup = 0.5, attackTime = 0.3, attackSpeed = 12,
	earliest = 0.9, leadSpeed = 70, leadFactor = 0.5,
	approachTime = 3, recoveryTime = 2,
	inPosition = function(_, _, _, _, dx, dy) return dx * dx + dy * dy < 70 * 70 end,
	attack = function(api, state, fighter, opponent)
		local dx, dy = math.cos(fighter.heading), math.sin(fighter.heading)
		api.launch(state, fighter, { x = fighter.x + dx * 4, y = fighter.y + dy * 4,
			vx = dx * 60, vy = dy * 60, life = 1.4, radius = 1.2, source = "pea" })
		api.event(state, "rocket", fighter.x + dx * 4, fighter.y + dy * 4, fighter.id, opponent.id, "pea")
	end,
}

-- Tiny: a quick speck that is hard to hit, with two armor.
BattleSkills.wild.Bug = {
	lost = 1, size = 0.35, speed = 1.2, pace = 0.88,
	start = function(_, _, fighter)
		local self = BattleSkills.wild.Bug
		fighter.armor = math.max(1, fighter.armor - self.lost)
		fighter.maxArmor = fighter.armor
		fighter.scale, fighter.radius = fighter.scale * self.size, fighter.radius * self.size
		fighter.speedScale = fighter.speedScale * self.speed
		-- A pest: it is back for another go sooner than a full-sized plane.
		fighter.pace = self.pace
	end,
}

-- Rolling: starts small, grows with every hit it lands, and once it has
-- grown its hits break two armor.
BattleSkills.wild.Snowball = {
	first = 0.8, grow = 1.4, most = 2,
	start = function(_, _, fighter)
		local self = BattleSkills.wild.Snowball
		fighter.snowball = 0
		fighter.scale, fighter.radius = fighter.scale * self.first, fighter.radius * self.first
		fighter.shotScale = fighter.shotScale * self.first
	end,
	landed = function(api, state, fighter, target)
		local self = BattleSkills.wild.Snowball
		if fighter.ejected or fighter.snowball >= self.most then return end
		fighter.snowball = fighter.snowball + 1
		fighter.scale, fighter.radius = fighter.scale * self.grow, fighter.radius * self.grow
		fighter.shotScale = fighter.shotScale * self.grow
		fighter.bonus = 1
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, target.id, "snowball", "Snowball")
	end,
}

-- Trade: at half time the two planes swap armor. It happens once, even if
-- both pilots brought the card.
BattleSkills.wild.Swap = {
	at = 9,
	start = function(_, state, fighter) fighter.swapAt = BattleSkills.wild.Swap.at end,
	moved = function(api, state, fighter)
		if state.swapped or state.elapsed < BattleSkills.wild.Swap.at then return end
		local rival = state.fighters[3 - fighter.id]
		if fighter.armor <= 0 or rival.armor <= 0 then return end
		state.swapped = true
		fighter.armor, rival.armor = rival.armor, fighter.armor
		api.event(state, "skill", (fighter.x + rival.x) / 2, (fighter.y + rival.y) / 2, fighter.id, rival.id, "swap", "Swap")
	end,
}

-- Luck: a die rolls as the round starts. A 1 costs an armor, a 4 or 5 adds
-- one, and a 6 adds one and makes every hit break two.
BattleSkills.wild.Gambler = {
	start = function(api, state, fighter)
		local seat = state.seed % 2 == 0 and fighter.id or 3 - fighter.id
		local mixed = (state.seed * 48271 + seat * 1299709) % 2147483647 * 16807 % 2147483647
		local roll = math.floor(mixed / 2147483647 * 6) + 1
		fighter.roll = roll
		if roll == 1 then
			fighter.armor = math.max(1, fighter.armor - 1)
		elseif roll >= 4 then
			fighter.armor = fighter.armor + 1
			fighter.maxArmor = math.max(fighter.maxArmor, fighter.armor)
		end
		if roll == 6 then fighter.bonus = 1 end
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, 0, "gambler", "Gambler").roll = roll
	end,
}

-- One slow, careful shot. The aim locks before it fires, a hit breaks two
-- armor, and a miss leaves a long wait.
BattleSkills.offence.Sniper = {
	windup = 1.35, lockTime = 0.3, attackTime = 0.35, attackSpeed = 8,
	earliest = 1.6, leadSpeed = 220, leadFactor = 1,
	approachTime = 3.3, recoveryTime = 2.8,
	bulletSpeed = 220, bulletLife = 1, bulletRadius = 2.3, power = 2,
	inPosition = function(_, _, _, _, dx, dy) return dx * dx + dy * dy > 40 * 40 end,
	approach = function(api, state, fighter, opponent, dx, dy)
		-- A sniper wants room: back away from a rival that gets close.
		if dx * dx + dy * dy > 55 * 55 then return end
		local awayX, awayY = api.direction(-dx, -dy, fighter.id == 1 and -1 or 1)
		return api.clamp(fighter.x + awayX * 30, state.bounds.left + 8, state.bounds.right - 8),
			api.clamp(fighter.y + awayY * 30, state.bounds.bottom + 8, state.bounds.top - 8), 30, 3.6
	end,
	windupMove = function(_, _, fighter)
		-- Track the rival, then hold dead still for the last moment.
		if fighter.phaseLeft > BattleSkills.offence.Sniper.lockTime then return nil, nil, 5, 7 end
		return fighter.x + math.cos(fighter.heading) * 50, fighter.y + math.sin(fighter.heading) * 50, 2, 0
	end,
	attack = function(api, state, fighter, opponent)
		local self = BattleSkills.offence.Sniper
		local dx, dy = math.cos(fighter.heading), math.sin(fighter.heading)
		api.launch(state, fighter, { x = fighter.x + dx * 7, y = fighter.y + dy * 7,
			vx = dx * self.bulletSpeed, vy = dy * self.bulletSpeed, life = self.bulletLife,
			radius = self.bulletRadius, source = "sniper", power = self.power })
		local entry = api.event(state, "rocket", fighter.x + dx * 7, fighter.y + dy * 7, fighter.id, opponent.id, "sniper", "Sniper")
		entry.heading = fighter.heading
	end,
}

-- Portal: your shots, and a diving plane, leave one side of the arena and
-- come back in the other.
BattleSkills.wild.Wrap = {
	steal = true,
	start = function(_, _, fighter) fighter.wrapShots = true end,
}

-- Bomb: a ticking potato starts on the rival and jumps to whoever was hit
-- last, except that the first hit on its owner does not count. When the fuse
-- runs out, the holder loses an armor.
BattleSkills.wild.HotPotato = {
	fuse = 10,
	start = function(_, state, fighter)
		state.potatoes = state.potatoes or {}
		state.potatoes[#state.potatoes + 1] = { holder = 3 - fighter.id, left = BattleSkills.wild.HotPotato.fuse, owner = fighter.id, grace = 1 }
	end,
}

-- Fake: a balloon copy flies beside you. A rival that is nearer to it goes
-- for it, and a shot or dive that reaches it is wasted. It comes back later.
BattleSkills.wild.Decoy = {
	cooldown = 6,
	start = function(_, state, fighter)
		fighter.decoyUp, fighter.decoyLeft = true, 0
		fighter.decoySide = (state.seed + fighter.id) % 2 == 0 and 1 or -1
	end,
	moved = function(api, state, fighter, dt)
		if fighter.decoyUp then return end
		fighter.decoyLeft = fighter.decoyLeft - dt
		if fighter.decoyLeft > 0 then return end
		fighter.decoyUp = true
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, 0, "decoy", "Decoy")
	end,
}

-- Pickpocket: your first hit takes one of the rival's wild cards for the rest
-- of the round. Cards that reshape a plane cannot be taken.
BattleSkills.wild.Thief = {
	ammo = 1.5,
	start = function(_, _, fighter) fighter.thiefReady = true end,
	landed = function(api, state, fighter, target)
		if not fighter.thiefReady or fighter.ejected then return end
		local taken
		for _, id in ipairs(target.wildIds) do
			local held = false
			for _, own in ipairs(fighter.wildIds) do held = held or own == id end
			if not taken and not held and BattleSkills.wild[id].steal then taken = id end
		end
		fighter.thiefReady = false
		if not taken then
			-- Nothing worth taking: pinch the rival's ammo instead, so its next
			-- attack is a long time coming.
			target._bumperRecovery = (target._bumperRecovery or 0) + BattleSkills.wild.Thief.ammo
			api.event(state, "skill", fighter.x, fighter.y, fighter.id, target.id, "thief", "Thief")
			return
		end
		local kept, mine = {}, { taken }
		for _, id in ipairs(target.wildIds) do if id ~= taken then kept[#kept + 1] = id end end
		for _, id in ipairs(fighter.wildIds) do mine[#mine + 1] = id end
		table.sort(mine)
		target.wildIds, fighter.wildIds = kept, mine
		-- Stop only the stolen card; the rival's other card keeps its state.
		-- Existing shots/clouds and an already-ejected pilot keep their form.
		if taken == "Afterburner" then target._boostPending, target.boostLeft, target.tempo = false, 0, nil
		elseif taken == "SpringBumper" then target.bumperReady = false
		elseif taken == "Chicken" then target.chickenReady = false
		elseif taken == "SecondWind" then target.secondWind = false
		elseif taken == "Wrap" then target.wrapShots = false
		elseif taken == "Magnet" then target.magnetLeft = 0
		elseif taken == "FizzyFuel" then target._wakeLeft, target._wakeNext = 0, 0
		elseif taken == "Rewind" then target.rewindReady = false end
		if BattleSkills.wild[taken].start then BattleSkills.wild[taken].start(api, state, fighter) end
		api.event(state, "skill", fighter.x, fighter.y, fighter.id, target.id, "thief", "Thief").stolen = taken
	end,
}

-- A spinning blade that flies out and curves back to its thrower. It can hit
-- once, on the way out or on the way home.
BattleSkills.offence.Boomerang = {
	windup = 0.9, attackTime = 0.45, attackSpeed = 24,
	earliest = 1.2, leadSpeed = 80, leadFactor = 0.5,
	approachTime = 3, recoveryTime = 2.45,
	bladeSpeed = 82, bladeLife = 3, bladeRadius = 3, outTime = 0.62, returnSpeed = 74,
	inPosition = function(_, _, _, _, dx, dy) return dx * dx + dy * dy < 62 * 62 end,
	attack = function(api, state, fighter, opponent)
		local self = BattleSkills.offence.Boomerang
		local dx, dy = math.cos(fighter.heading), math.sin(fighter.heading)
		api.launch(state, fighter, { x = fighter.x + dx * 7, y = fighter.y + dy * 7,
			vx = dx * self.bladeSpeed, vy = dy * self.bladeSpeed, life = self.bladeLife, radius = self.bladeRadius,
			source = "boomerang", returnAfter = self.outTime, returnSpeed = self.returnSpeed })
		api.event(state, "rocket", fighter.x + dx * 7, fighter.y + dy * 7, fighter.id, opponent.id, "boomerang", "Boomerang")
	end,
}

-- A hole in the sky. It opens beside the rival, drags both planes toward it
-- and bends every shot; once it has armed, touching its core costs the rival
-- an armor.
BattleSkills.offence.BlackHole = {
	windup = 0.85, attackTime = 0.4, attackSpeed = 20,
	earliest = 1.2, leadSpeed = 60, leadFactor = 0.6,
	approachTime = 3, recoveryTime = 2,
	holeLife = 2.6, armTime = 0.55, core = 4.5, reach = 34, pull = 20, bend = 170, lead = 0.35,
	inPosition = function(_, _, _, _, dx, dy) return dx * dx + dy * dy < 70 * 70 end,
	attack = function(api, state, fighter, opponent)
		local self = BattleSkills.offence.BlackHole
		local x, y = opponent.x + opponent.vx * self.lead, opponent.y + opponent.vy * self.lead
		local c, s = math.cos(fighter.heading), math.sin(fighter.heading)
		-- A squadron opens one hole per plane, spread like its formation.
		local planes = (fighter.squad or 0) > 1 and math.max(1, math.min(fighter.squad, fighter.armor)) or 1
		for index = 1, planes do
			local back, side = index == 1 and 0 or -9, index == 1 and 0 or (index == 2 and 12 or -12)
			api.hole(state, fighter, x + back * c - side * s, y + back * s + side * c, { skillId = "BlackHole",
				life = self.holeLife, armTime = self.armTime, core = self.core, reach = self.reach, pull = self.pull, bend = self.bend })
		end
		api.event(state, "hole", x, y, fighter.id, opponent.id, "blackhole", "BlackHole")
	end,
}

-- A flying saucer. It has to get close; then its beam grabs the rival, holds
-- it for a moment and hurls it away. A thrown plane that reaches a wall loses
-- an armor.
BattleSkills.offence.UFOBeam = {
	windup = 0.7, attackTime = 0.6, attackSpeed = 10,
	earliest = 1.1, leadSpeed = 60, leadFactor = 0.3,
	approachTime = 2.85, recoveryTime = 2.3,
	range = 24, chase = 38, throwSpeed = 80, throwTime = 2.2,
	inPosition = function(_, _, _, _, dx, dy) return dx * dx + dy * dy < 32 * 32 end,
	approach = function(_, _, fighter, opponent)
		-- With the beam loaded, chase harder than a circling plane flies.
		if fighter.circling then return end
		return opponent.x, opponent.y, BattleSkills.offence.UFOBeam.chase, 4.4
	end,
	windupMove = function(_, _, _, opponent)
		return opponent.x, opponent.y, BattleSkills.offence.UFOBeam.chase - 4, 5.5
	end,
	attack = function(api, state, fighter, opponent)
		local self = BattleSkills.offence.UFOBeam
		local victim = state.fighters[opponent.id]
		local dx, dy = opponent.x - fighter.x, opponent.y - fighter.y
		local reach = self.range * (fighter.shotScale or 1)
		if dx * dx + dy * dy > reach * reach or (not opponent.decoy and (victim.invulnerable > 0 or victim.hold or victim.throw)) or fighter.hold or fighter.throw then
			api.event(state, "beam_miss", fighter.x, fighter.y, fighter.id, opponent.id, "ufo", "UFOBeam")
			return
		end
		fighter._attackHit = true
		if opponent.decoy then
			-- The beam closes on a balloon.
			api.pop(state, victim, opponent.x, opponent.y, fighter.id)
			return
		end
		victim.hold = { x = fighter.x + dx * 0.85, y = fighter.y + dy * 0.85, by = fighter.id, left = self.attackTime + 0.1 }
		api.interrupt(state, victim)
		api.event(state, "beam", victim.x, victim.y, fighter.id, victim.id, "ufo", "UFOBeam")
	end,
	release = function(api, state, fighter)
		local self = BattleSkills.offence.UFOBeam
		local victim = state.fighters[3 - fighter.id]
		if not victim.hold or victim.hold.by ~= fighter.id then return end
		victim.hold = nil
		local heading = fighter._attackHeading
		victim.throw = { vx = math.cos(heading) * self.throwSpeed, vy = math.sin(heading) * self.throwSpeed, by = fighter.id, left = self.throwTime }
		api.event(state, "throw", victim.x, victim.y, fighter.id, victim.id, "ufo", "UFOBeam").heading = heading
	end,
}

-- Carrier: the plane grows, stops attacking and sends out drones instead.
-- Each drone homes on the rival, carries out the plane's attack once from
-- wherever it is, and flies off. A rival's shot that meets a drone pops it.
BattleSkills.wild.Mothership = {
	size = 1.3, speed = 0.9, pace = 1.06, windup = 0.4, launchTime = 0.35,
	drones = 2, fan = 0.9, stagger = 0.35, droneSpeed = 46, droneTurn = 3.2, droneRadius = 2.2,
	arm = 0.9, range = 30, flight = 2.4, leave = 0.7, dive = 0.5,
	start = function(_, _, fighter)
		local self = BattleSkills.wild.Mothership
		fighter.mothership = true
		fighter.scale, fighter.radius = fighter.scale * self.size, fighter.radius * self.size
		fighter.speedScale = fighter.speedScale * self.speed
		-- Readying a flight of drones takes longer than reloading a gun.
		fighter.pace = (fighter.pace or 1) * self.pace
	end,
}

-- Tape: the first hit on you scrubs the whole fight back a few seconds, and
-- it plays out again differently. The clock does not go back.
BattleSkills.wild.Rewind = {
	steal = true,
	back = 3,
	start = function(_, state, fighter)
		fighter.rewindReady = true
		state.recording = true
	end,
	hit = function(api, state, target, actor, x, y, _, _, source)
		if not target.rewindReady or state._rewind then return false end
		target.rewindReady = false
		state._rewind = target.id
		target.invulnerable = api.IMPACT_PROTECTION
		api.event(state, "skill", x, y, target.id, actor.id, source, "Rewind")
		return true
	end,
}

-- Builds worth a shout. The first pair a plane matches names it for the round.
BattleSkills.combos = {
	{ "Mothership", "UFOBeam", "ALIEN INVASION!" },
	{ "Chicken", "UFOBeam", "ALIEN ABDUCTION!" },
	{ "Mothership", "Squadron", "INVASION FLEET!" },
	{ "BlackHole", "Mothership", "EVENT HORIZON!" },
	{ "BlackHole", "Wrap", "RIP IN SPACE!" },
	{ "BlackHole", "Magnet", "NO ESCAPE!" },
	{ "BlackHole", "Giant", "SUPERMASSIVE!" },
	{ "BlackHole", "Squadron", "SWISS CHEESE SKY!" },
	{ "Giant", "UFOBeam", "TRACTOR BEAM!" },
	{ "Magnet", "UFOBeam", "COME HERE!" },
	{ "Rewind", "Swap", "TIME PARADOX!" },
	{ "Eject", "Rewind", "NINE LIVES!" },
	{ "Decoy", "Rewind", "DEJA VU!" },
	{ "HotPotato", "Rewind", "TICK TOCK!" },
	{ "Meteor", "Mothership", "DRONE STRIKE!" },
	{ "Mothership", "Sniper", "SNIPER NEST!" },
	{ "Giant", "Mothership", "PLANET KILLER!" },
	{ "Squadron", "Vampire", "VAMPIRE SWARM!" },
	{ "Meteor", "Wrap", "PORTAL DIVE!" },
	{ "Pinball", "Wrap", "PINBALL WIZARD!" },
	{ "Squadron", "Wrap", "FROM EVERYWHERE!" },
	{ "Decoy", "Squadron", "WHICH ONE IS REAL?" },
	{ "Bug", "Decoy", "HIDE AND SEEK!" },
	{ "Chicken", "HotPotato", "ROAST CHICKEN!" },
	{ "HotPotato", "Swap", "PASS THE PARCEL!" },
	{ "HotPotato", "SpringBumper", "NOT IT!" },
	{ "Thief", "Vampire", "SMASH AND GRAB!" },
	{ "Boomerang", "Wrap", "ROUND THE WORLD!" },
	{ "Boomerang", "Squadron", "TRIPLE THROW!" },
	{ "Boomerang", "Giant", "FRISBEE OF DOOM!" },
	{ "Bug", "Giant", "GIANT BUG!" },
	{ "Bug", "Swap", "BODY SWAP!" },
	{ "Bug", "Vampire", "MOSQUITO!" },
	{ "Bug", "Sniper", "ANT WITH A CANNON!" },
	{ "Snowball", "Squadron", "AVALANCHE!" },
	{ "Giant", "Snowball", "ABOMINABLE!" },
	{ "Gambler", "Swap", "DOUBLE OR NOTHING!" },
	{ "Gambler", "Vampire", "HIGH STAKES!" },
	{ "Swap", "Vampire", "BLOOD TRADE!" },
	{ "Giant", "Sniper", "ARTILLERY!" },
	{ "Squadron", "Sniper", "FIRING SQUAD!" },
	{ "Giant", "Squadron", "THREE GIANTS!" },
	{ "Eject", "Giant", "TINY PILOT, BIG PLANE!" },
	{ "Chicken", "Squadron", "CHICKEN HUNTERS!" },
	{ "Eject", "Vampire", "UNDEAD PILOT!" },
	{ "Giant", "Vampire", "DRACULA!" },
	{ "Chicken", "Magnet", "CHICKEN DINNER!" },
	{ "Squadron", "MachineGun", "BULLET STORM!" },
	{ "Squadron", "Meteor", "METEOR SHOWER!" },
	{ "Squadron", "Firework", "FIREWORK SHOW!" },
	{ "Squadron", "Pinball", "MULTIBALL!" },
	{ "Giant", "Meteor", "ASTEROID!" },
	{ "Giant", "Pinball", "WRECKING BALL!" },
	{ "Giant", "Firework", "MEGA ROCKET!" },
	{ "Giant", "MachineGun", "CANNONS!" },
}

return BattleSkills
