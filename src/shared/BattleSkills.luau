-- What every top and part is made of, as plain numbers. BattleSimulation reads
-- this table and owns all the physics; SkillCatalog holds the words and
-- colours under the same ids. No Roblox services are required.
--
-- Nobody steers a top. How it moves comes from its tip:
--   cruise  the speed its tip drives it at when spinning flat out
--   grip    how hard the tip pulls it back up to that speed
--   brake   how hard the tip slows it after a hit has thrown it
--   curl    how sharply its path bends
--   dive    how strongly it keeps turning back toward the middle of the bowl
--   decay   spin lost each second just from the tip rubbing the floor
-- and how it fights comes from its body:
--   mass    heavier tops are thrown less
--   bite    how jagged the rim is: recoil and spin damage dealt
--   guard   share of recoil and spin damage it takes (lower is better)
--   rail    speed it picks up off the stadium wall, as a multiple of cruise
local BattleSkills = { offence = {}, wild = {} }

-- Attack: wide grippy tip, jagged rim.
BattleSkills.offence.Bolt = {
	mass = 0.87, radius = 4.2, cruise = 30, grip = 60, brake = 34, curl = 0.7, dive = 1.4, decay = 2.9, bite = 1.6, guard = 1, rail = 1.25,
}
-- Stamina: needle tip, barely moves, slides when hit.
BattleSkills.offence.Cyclone = {
	mass = 0.99, radius = 4.6, cruise = 5, grip = 12, brake = 11, curl = 0.6, dive = 0.6, decay = 2.37, bite = 0.8, guard = 1, rail = 0,
}
-- Defense: heavy, ball tip, smooth rim.
BattleSkills.offence.Boulder = {
	mass = 1.25, radius = 5.4, cruise = 10, grip = 24, brake = 36, curl = 0.6, dive = 0.8, decay = 3, bite = 0.7, guard = 0.76, rail = 0,
}
-- Balance.
BattleSkills.offence.Drifter = {
	mass = 1.07, radius = 4.8, cruise = 19, grip = 36, brake = 22, curl = 0.7, dive = 1.1, decay = 3.05, bite = 1.09, guard = 0.95, rail = 1,
}

-- Parts multiply a top's numbers, add spin, or turn it the other way.
BattleSkills.wild.Heavy = { mass = 1.14 }
BattleSkills.wild.Spikes = { bite = 1.3 }
BattleSkills.wild.Turbo = { cruise = 1.08, grip = 1.2, brake = 1.5, decay = 0.95 }
BattleSkills.wild.Guard = { guard = 0.93 }
BattleSkills.wild.Flywheel = { spin = 1.04, decay = 0.97 }
BattleSkills.wild.LeftSpin = { left = true, guard = 0.92 }

return BattleSkills
