-- How every top and upgrade behaves, as plain numbers. BattleSimulation reads
-- this table and owns all the physics; SkillCatalog holds the words and
-- colours under the same ids. No Roblox services are required.
--
-- A top is a disc with a mass, a size, a cruise speed it always spins back up
-- to, a turn rate (how sharply it can lean toward its rival) and a kick: the
-- extra shove it gives whatever it touches. A plain bump is a nudge. The big
-- throws come from each top's signature move, which repeats on a timer:
--   dash   stop, aim, then shoot across the ring in a straight line
--   swoop  break out of a wide circle and cut in fast
--   jump   leap to where the rival is and land with a shockwave
--   shove  lower its weight and bulldoze for a moment
local BattleSkills = { offence = {}, wild = {} }

BattleSkills.offence.Boulder = {
	mass = 1.63, radius = 5.8, cruise = 16, turn = 3, kick = 1,
	move = { kind = "shove", every = 3.2, windup = 0, time = 1, speed = 1.6, turn = 1.5, recover = 0 },
}

BattleSkills.offence.Bolt = {
	mass = 0.9, radius = 4, cruise = 26, turn = 4, kick = 0.8,
	move = { kind = "dash", every = 2, windup = 0.5, time = 0.3, speed = 78, recover = 0.4 },
}

BattleSkills.offence.Cyclone = {
	mass = 1.05, radius = 4.6, cruise = 32, turn = 2.1, kick = 1.1,
	move = { kind = "swoop", every = 2.3, windup = 0, time = 1, speed = 1.35, turn = 3, recover = 0 },
}

BattleSkills.offence.Pogo = {
	mass = 1.15, radius = 4.8, cruise = 22, turn = 3.5, kick = 0.9,
	move = { kind = "jump", every = 2.5, windup = 0.35, time = 0.7, height = 18, reach = 15.5, kick = 4, recover = 0.4 },
}

-- Upgrades multiply a top's numbers or switch on one rule in the simulation.
BattleSkills.wild.Heavy = { mass = 1.09, radius = 1.1 }
BattleSkills.wild.Spikes = { kick = 1.2 }
BattleSkills.wild.Turbo = { cruise = 1.15, tempo = 0.8 }
BattleSkills.wild.Claws = { claws = true }
BattleSkills.wild.Bumper = { bumper = true }
BattleSkills.wild.Jetpack = { jetpack = true }

return BattleSkills
