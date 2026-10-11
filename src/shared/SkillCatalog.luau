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
-- Rarity says how strange a skill is, never how strong.
local order = { "Meteor", "Firework", "MachineGun", "Pinball", "Sniper", "Afterburner", "SpringBumper", "FizzyFuel", "Magnet", "SecondWind",
	"Squadron", "Giant", "Eject", "Vampire", "Chicken", "Bug", "Snowball", "Swap", "Gambler" }
local skills = {
	Meteor = { id = "Meteor", kind = "offence", name = "Meteor", icon = "☄️", word = "BOOOM!",
		promise = "Climb high, then dive-bomb your rival.",
		windupTell = "CHARGING...", attackTell = "DIVE!",
		color = { r = 255, g = 128, b = 86 }, starter = true, rarity = "common" },
	Firework = { id = "Firework", kind = "offence", name = "Firework", icon = "🎆", word = "FWOOSH!",
		promise = "Shoot one big rocket every time you pass.",
		windupTell = "LOCKED ON", attackTell = "FIRE!",
		color = { r = 160, g = 128, b = 255 }, starter = true, rarity = "common" },
	MachineGun = { id = "MachineGun", kind = "offence", name = "Machine Gun", icon = "💥", word = "RAT-A-TAT!",
		promise = "Spray six bullets. Land three to break armor.",
		windupTell = "SPINNING UP", attackTell = "RAT-A-TAT!",
		color = { r = 255, g = 220, b = 90 }, starter = true, rarity = "common" },
	Pinball = { id = "Pinball", kind = "offence", name = "Pinball", icon = "↗️", word = "RICOCHET!",
		promise = "Fire a ball that bounces off the walls.",
		windupTell = "AIMING...", attackTell = "PING!",
		color = { r = 110, g = 220, b = 255 }, starter = true, rarity = "common" },
	Sniper = { id = "Sniper", kind = "offence", name = "Sniper", icon = "🎯", word = "BANG!",
		promise = "One careful shot from far away. A hit breaks 2 armor.",
		windupTell = "TAKING AIM...", attackTell = "BANG!",
		color = { r = 255, g = 70, b = 70 }, starter = true, rarity = "rare" },
	Afterburner = { id = "Afterburner", kind = "wild", name = "Afterburner", icon = "🔥", word = "ZOOM!",
		when = "AFTER YOU ATTACK", promise = "Jet away and attack again sooner.",
		color = { r = 255, g = 168, b = 66 }, starter = true, rarity = "common" },
	SpringBumper = { id = "SpringBumper", kind = "wild", name = "Spring Bumper", icon = "🛡️", word = "BOING!",
		when = "FIRST HIT ON YOU", promise = "Spring the hit away. Your next attack is slower.",
		color = { r = 196, g = 255, b = 91 }, starter = true, rarity = "common" },
	FizzyFuel = { id = "FizzyFuel", kind = "wild", name = "Fizzy Fuel", icon = "🥤", word = "FIZZ!",
		when = "WHEN YOU ATTACK", promise = "Leave a cloud wall that hurts your rival.",
		color = { r = 96, g = 255, b = 214 }, starter = true, rarity = "common" },
	Magnet = { id = "Magnet", kind = "wild", name = "Magnet", icon = "🧲", word = "PULL!",
		when = "WHEN YOU ATTACK", promise = "Yank your rival into your attack.",
		color = { r = 255, g = 120, b = 190 }, starter = true, rarity = "common" },
	SecondWind = { id = "SecondWind", kind = "wild", name = "Second Wind", icon = "💨", word = "WHOOSH!",
		when = "ON YOUR LAST ARMOR", promise = "Power up! Fly faster and attack sooner.",
		color = { r = 130, g = 255, b = 190 }, starter = true, rarity = "common" },
	Squadron = { id = "Squadron", kind = "wild", name = "Squadron", icon = "✈️", word = "SQUAD UP!",
		when = "ALL ROUND", promise = "Fly 3 small planes. Each has 1 life and all of them shoot.",
		color = { r = 120, g = 190, b = 255 }, starter = true, rarity = "rare" },
	Giant = { id = "Giant", kind = "wild", name = "Giant", icon = "🐘", word = "STOMP!",
		when = "ALL ROUND", promise = "Double size, 1 extra armor and huge shots. Slow and easy to hit.",
		color = { r = 255, g = 150, b = 90 }, starter = true, rarity = "rare" },
	Eject = { id = "Eject", kind = "wild", name = "Eject", icon = "🪂", word = "EJECT!",
		when = "WHEN YOU ARE SHOT DOWN", promise = "Your pilot bails out with a pea-shooter and 1 last life.",
		color = { r = 255, g = 236, b = 150 }, starter = true, rarity = "rare" },
	Vampire = { id = "Vampire", kind = "wild", name = "Vampire", icon = "🧛", word = "SLURP!",
		when = "EVERY HIT YOU LAND", promise = "Start with 2 armor. Every hit steals 1 from your rival.",
		color = { r = 220, g = 60, b = 110 }, starter = true, rarity = "rare" },
	Chicken = { id = "Chicken", kind = "wild", name = "Chicken", icon = "🐔", word = "BAWK!",
		when = "YOUR FIRST HIT", promise = "Turn your rival into a chicken. Chickens cannot attack.",
		color = { r = 255, g = 244, b = 214 }, starter = true, rarity = "rare" },
	Bug = { id = "Bug", kind = "wild", name = "Bug", icon = "🐜", word = "BZZZ!",
		when = "ALL ROUND", promise = "Shrink to a quick speck that is hard to hit. You have 2 armor.",
		color = { r = 170, g = 230, b = 110 }, starter = true, rarity = "rare" },
	Snowball = { id = "Snowball", kind = "wild", name = "Snowball", icon = "⛄", word = "BIGGER!",
		when = "EVERY HIT YOU LAND", promise = "Start small. Grow with each hit, then break 2 armor at a time.",
		color = { r = 200, g = 235, b = 255 }, starter = true, rarity = "rare" },
	Swap = { id = "Swap", kind = "wild", name = "Swap", icon = "🔄", word = "SWAP!",
		when = "AT HALF TIME", promise = "You and your rival trade armor. Lose yours first!",
		color = { r = 190, g = 130, b = 255 }, starter = true, rarity = "rare" },
	Gambler = { id = "Gambler", kind = "wild", name = "Gambler", icon = "🎲", word = "ROLL!",
		when = "AS THE ROUND STARTS", promise = "Roll a die. 1 costs an armor, 4 or 5 adds one, 6 is a jackpot.",
		color = { r = 255, g = 215, b = 80 }, starter = true, rarity = "rare" },
}

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
