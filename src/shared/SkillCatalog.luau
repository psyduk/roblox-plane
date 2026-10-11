-- Every skill a pilot can bring to a fight: what it is called and how it is
-- shown. How a skill behaves lives in BattleSkills under the same id. Records
-- are returned detached so UI edits never change the catalog. No Roblox
-- services are required.
local SkillCatalog = {}

SkillCatalog.KINDS = { "offence", "wild" }
SkillCatalog.MAX_WILD = 2
SkillCatalog.DEFAULT_OFFENCE = "Meteor"
SkillCatalog.ROSTER_VERSION = "sky-battle-public-v1"
SkillCatalog.CONTRACT_VERSION = "sky-battle-combat-v1"

-- Order is display order. `starter` skills are owned from the first fight.
-- Rarity says how strange a skill is, never how strong. `teaser` is the one
-- line shown for a card the player has not met yet.
local order = { "Meteor", "Firework", "MachineGun", "Pinball", "Sniper", "Boomerang", "BlackHole", "UFOBeam", "Afterburner", "SpringBumper", "FizzyFuel", "Magnet", "SecondWind",
	"Squadron", "Giant", "Eject", "Vampire", "Chicken", "Bug", "Snowball", "Swap", "Gambler",
	"Wrap", "HotPotato", "Decoy", "Thief", "Mothership", "Rewind" }
local skills = {
	Meteor = { id = "Meteor", kind = "offence", name = "Meteor", icon = "☄️", word = "BOOOM!",
		teaser = "It comes down from above.",
		promise = "Climb high, then dive-bomb your rival.",
		windupTell = "CHARGING...", attackTell = "DIVE!",
		color = { r = 255, g = 128, b = 86 }, starter = true, rarity = "common" },
	Firework = { id = "Firework", kind = "offence", name = "Firework", icon = "🎆", word = "FWOOSH!",
		teaser = "One rocket. One bang.",
		promise = "Shoot one big rocket every time you pass.",
		windupTell = "LOCKED ON", attackTell = "FIRE!",
		color = { r = 160, g = 128, b = 255 }, starter = true, rarity = "common" },
	MachineGun = { id = "MachineGun", kind = "offence", name = "Machine Gun", icon = "💥", word = "RAT-A-TAT!",
		teaser = "Six of them, very fast.",
		promise = "Spray six bullets. Land three to break armor.",
		windupTell = "SPINNING UP", attackTell = "RAT-A-TAT!",
		color = { r = 255, g = 220, b = 90 }, starter = true, rarity = "common" },
	Pinball = { id = "Pinball", kind = "offence", name = "Pinball", icon = "↗️", word = "RICOCHET!",
		teaser = "The walls are on its side.",
		promise = "Fire a ball that bounces off the walls.",
		windupTell = "AIMING...", attackTell = "PING!",
		color = { r = 110, g = 220, b = 255 }, starter = true, rarity = "common" },
	Sniper = { id = "Sniper", kind = "offence", name = "Sniper", icon = "🎯", word = "BANG!",
		teaser = "It only needs one.",
		promise = "One careful shot from far away. A hit breaks 2 armor.",
		windupTell = "TAKING AIM...", attackTell = "BANG!",
		color = { r = 255, g = 70, b = 70 }, starter = true, rarity = "rare" },
	Boomerang = { id = "Boomerang", kind = "offence", name = "Boomerang", icon = "↩️", word = "WHIRR!",
		teaser = "It comes back.",
		promise = "Throw a blade that curves back to you. It can hit going or coming.",
		windupTell = "WINDING UP...", attackTell = "THROW!",
		color = { r = 255, g = 170, b = 60 }, starter = true, rarity = "rare" },
	BlackHole = { id = "BlackHole", kind = "offence", name = "Black Hole", icon = "⚫", word = "CRUNCH!",
		teaser = "The sky has a hole in it.",
		promise = "Open a black hole beside your rival. It drags planes in and bends every shot.",
		windupTell = "TEARING THE SKY...", attackTell = "OPEN!",
		color = { r = 150, g = 90, b = 255 }, starter = true, rarity = "epic" },
	UFOBeam = { id = "UFOBeam", kind = "offence", name = "UFO Beam", icon = "🛸", word = "YOINK!",
		teaser = "You will be picked up shortly.",
		promise = "Get close, grab your rival in a beam and throw them into a wall.",
		windupTell = "BEAM CHARGING...", attackTell = "GOTCHA!",
		color = { r = 120, g = 255, b = 160 }, starter = true, rarity = "epic" },
	Afterburner = { id = "Afterburner", kind = "wild", name = "Afterburner", icon = "🔥", word = "ZOOM!",
		teaser = "Gone before you can blink.",
		when = "AFTER YOU ATTACK", promise = "Jet away, attack again sooner and dodge more often.",
		color = { r = 255, g = 168, b = 66 }, starter = true, rarity = "common" },
	SpringBumper = { id = "SpringBumper", kind = "wild", name = "Spring Bumper", icon = "🛡️", word = "BOING!",
		teaser = "Boing.",
		when = "FIRST HIT ON YOU", promise = "Spring the hit away. Your next attack is slower.",
		color = { r = 196, g = 255, b = 91 }, starter = true, rarity = "common" },
	FizzyFuel = { id = "FizzyFuel", kind = "wild", name = "Fizzy Fuel", icon = "🥤", word = "FIZZ!",
		teaser = "Do not fly through the bubbles.",
		when = "WHEN YOU ATTACK", promise = "Leave a cloud wall that hurts your rival.",
		color = { r = 96, g = 255, b = 214 }, starter = true, rarity = "common" },
	Magnet = { id = "Magnet", kind = "wild", name = "Magnet", icon = "🧲", word = "PULL!",
		teaser = "You are getting closer. Why?",
		when = "WHEN YOU ATTACK", promise = "Yank your rival into your attack.",
		color = { r = 255, g = 120, b = 190 }, starter = true, rarity = "common" },
	SecondWind = { id = "SecondWind", kind = "wild", name = "Second Wind", icon = "💨", word = "WHOOSH!",
		teaser = "Most dangerous when nearly beaten.",
		when = "ON YOUR LAST ARMOR", promise = "Power up! Fly faster and attack sooner.",
		color = { r = 130, g = 255, b = 190 }, starter = true, rarity = "common" },
	Squadron = { id = "Squadron", kind = "wild", name = "Squadron", icon = "✈️", word = "SQUAD UP!",
		teaser = "One plane? Count again.",
		when = "ALL ROUND", promise = "Fly 3 small planes. Each has 1 life and all of them shoot.",
		color = { r = 120, g = 190, b = 255 }, starter = true, rarity = "rare" },
	Giant = { id = "Giant", kind = "wild", name = "Giant", icon = "🐘", word = "STOMP!",
		teaser = "It barely fits in the sky.",
		when = "ALL ROUND", promise = "Double size, 2 extra armor and huge shots. Slow and easy to hit.",
		color = { r = 255, g = 150, b = 90 }, starter = true, rarity = "rare" },
	Eject = { id = "Eject", kind = "wild", name = "Eject", icon = "🪂", word = "EJECT!",
		teaser = "The plane is gone. The pilot is not.",
		when = "WHEN YOU ARE SHOT DOWN", promise = "Your pilot bails out with a pea-shooter and 1 last life.",
		color = { r = 255, g = 236, b = 150 }, starter = true, rarity = "rare" },
	Vampire = { id = "Vampire", kind = "wild", name = "Vampire", icon = "🧛", word = "SLURP!",
		teaser = "It is thirsty.",
		when = "EVERY HIT YOU LAND", promise = "Start with 2 armor. Every hit steals 1 from your rival.",
		color = { r = 220, g = 60, b = 110 }, starter = true, rarity = "rare" },
	Chicken = { id = "Chicken", kind = "wild", name = "Chicken", icon = "🐔", word = "BAWK!",
		teaser = "Bawk.",
		when = "YOUR FIRST HIT", promise = "Turn your rival into a chicken. Chickens cannot attack.",
		color = { r = 255, g = 244, b = 214 }, starter = true, rarity = "rare" },
	Bug = { id = "Bug", kind = "wild", name = "Bug", icon = "🐜", word = "BZZZ!",
		teaser = "Was that a speck of dust?",
		when = "ALL ROUND", promise = "Shrink to a quick speck that is hard to hit. You have 2 armor.",
		color = { r = 170, g = 230, b = 110 }, starter = true, rarity = "rare" },
	Snowball = { id = "Snowball", kind = "wild", name = "Snowball", icon = "⛄", word = "BIGGER!",
		teaser = "It was small a minute ago.",
		when = "EVERY HIT YOU LAND", promise = "Start small. Grow with each hit, then break 2 armor at a time.",
		color = { r = 200, g = 235, b = 255 }, starter = true, rarity = "rare" },
	Swap = { id = "Swap", kind = "wild", name = "Swap", icon = "🔄", word = "SWAP!",
		teaser = "What's yours is mine.",
		when = "AT HALF TIME", promise = "You and your rival trade armor. Lose yours first!",
		color = { r = 190, g = 130, b = 255 }, starter = true, rarity = "rare" },
	Gambler = { id = "Gambler", kind = "wild", name = "Gambler", icon = "🎲", word = "ROLL!",
		teaser = "Feeling lucky?",
		when = "AS THE ROUND STARTS", promise = "Roll a die. 1 costs an armor, 4 or 5 adds one, 6 is a jackpot.",
		color = { r = 255, g = 215, b = 80 }, starter = true, rarity = "rare" },
	Wrap = { id = "Wrap", kind = "wild", name = "Wrap", icon = "🌀", word = "WARP!",
		teaser = "The edge of the sky is not the edge.",
		when = "ALL ROUND", promise = "Shots that miss come back in the other side of the arena, aimed again.",
		color = { r = 110, g = 150, b = 255 }, starter = true, rarity = "rare" },
	HotPotato = { id = "HotPotato", kind = "wild", name = "Hot Potato", icon = "💣", word = "KABOOM!",
		teaser = "Tick. Tick. Tick.",
		when = "8 SECONDS IN", promise = "A bomb starts on your rival and jumps to whoever is hit. The first hit on you is free.",
		color = { r = 255, g = 110, b = 60 }, starter = true, rarity = "rare" },
	Decoy = { id = "Decoy", kind = "wild", name = "Decoy", icon = "🎈", word = "POP!",
		teaser = "One of these is not real.",
		when = "ALL ROUND", promise = "A fake you flies alongside. Attacks that hit it are wasted.",
		color = { r = 255, g = 150, b = 200 }, starter = true, rarity = "rare" },
	Thief = { id = "Thief", kind = "wild", name = "Thief", icon = "🦝", word = "YOINK!",
		teaser = "Check your pockets.",
		when = "YOUR FIRST HIT", promise = "Steal one of your rival's wild cards for the round.",
		color = { r = 150, g = 150, b = 170 }, starter = true, rarity = "rare" },
	Mothership = { id = "Mothership", kind = "wild", name = "Mothership", icon = "🛰️", word = "LAUNCH!",
		teaser = "It does not fight. Its children do.",
		when = "WHEN YOU ATTACK", promise = "Grow big and stop shooting. Send out 2 drones that fly in and use your attack.",
		color = { r = 140, g = 200, b = 220 }, starter = true, rarity = "epic" },
	Rewind = { id = "Rewind", kind = "wild", name = "Rewind", icon = "⏪", word = "REWIND!",
		teaser = "That hit never happened.",
		when = "FIRST HIT ON YOU", promise = "The fight scrubs back 3 seconds and the hit never happened.",
		color = { r = 120, g = 220, b = 255 }, starter = true, rarity = "epic" },
}

-- What a plane shouts while it attacks. A wild card can change the attack a
-- plane is making (an ejected pilot's pea-shooter, a mothership's drones), so
-- the words follow the fighter's state in the fight, not just its build.
local forms = {
	PeaShooter = { name = "Pea-Shooter", icon = "🪂", windupTell = "TAKING AIM...", attackTell = "PEW!" },
	Mothership = { name = "Drones", icon = "🛰️", windupTell = "DRONES READY...", attackTell = "LAUNCH!" },
}
function SkillCatalog.tells(offenceId, state)
	local form = type(state) == "table" and (state.form and forms[state.form] or (state.mothership == true and forms.Mothership)) or nil
	local entry = form or skills[offenceId]
	if not entry then return nil end
	return { name = entry.name, icon = entry.icon, windupTell = entry.windupTell, attackTell = entry.attackTell }
end

function SkillCatalog.valid(id, kind)
	if type(id) ~= "string" or skills[id] == nil then return false end
	return kind == nil or skills[id].kind == kind
end

function SkillCatalog.get(id)
	if not SkillCatalog.valid(id) then return nil end
	local result = {}
	for key, value in pairs(skills[id]) do
		if type(value) == "table" then
			local copy = {}
			for channel, amount in pairs(value) do copy[channel] = amount end
			result[key] = copy
		else
			result[key] = value
		end
	end
	return result
end

-- All skills in display order, or only those of one kind.
function SkillCatalog.all(kind)
	local result = {}
	for _, id in ipairs(order) do
		if kind == nil or skills[id].kind == kind then result[#result + 1] = SkillCatalog.get(id) end
	end
	return result
end

function SkillCatalog.starters(kind)
	local result = {}
	for _, entry in ipairs(SkillCatalog.all(kind)) do
		if entry.starter then result[#result + 1] = entry end
	end
	return result
end

-- A build is one offence and up to MAX_WILD different wild cards. Returns a
-- clean copy, or nil and a reason. Anything a client sends goes through here.
function SkillCatalog.build(offenceId, wildIds)
	if not SkillCatalog.valid(offenceId, "offence") then return nil, "offence" end
	if wildIds == nil then wildIds = {} end
	if type(wildIds) ~= "table" then return nil, "wild" end
	local count = 0
	for key in pairs(wildIds) do
		if type(key) ~= "number" then return nil, "wild" end
		count = count + 1
	end
	if count > SkillCatalog.MAX_WILD then return nil, "too many" end
	local clean, seen = {}, {}
	for index = 1, count do
		local id = wildIds[index]
		if not SkillCatalog.valid(id, "wild") then return nil, "wild" end
		if seen[id] then return nil, "duplicate" end
		seen[id] = true
		clean[index] = id
	end
	return { offenceId = offenceId, wildIds = clean }
end

return SkillCatalog
