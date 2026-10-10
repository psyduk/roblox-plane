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
local order = { "Meteor", "Firework", "MachineGun", "Pinball", "Afterburner", "SpringBumper", "FizzyFuel", "Magnet", "SecondWind" }
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
		promise = "Bounce off a wall and slam into your rival.",
		windupTell = "BANKING...", attackTell = "RICOCHET!",
		color = { r = 110, g = 220, b = 255 }, starter = true, rarity = "common" },
	Afterburner = { id = "Afterburner", kind = "wild", name = "Afterburner", icon = "🔥", word = "ZOOM!",
		when = "AFTER YOU ATTACK", promise = "Zoom away fast and turn tighter.",
		color = { r = 255, g = 168, b = 66 }, starter = true, rarity = "common" },
	SpringBumper = { id = "SpringBumper", kind = "wild", name = "Spring Bumper", icon = "🛡️", word = "BOING!",
		when = "FIRST HIT ON YOU", promise = "Bounce the hit away. You attack a bit later after.",
		color = { r = 196, g = 255, b = 91 }, starter = true, rarity = "common" },
	FizzyFuel = { id = "FizzyFuel", kind = "wild", name = "Fizzy Fuel", icon = "🥤", word = "FIZZ!",
		when = "WHEN YOU ATTACK", promise = "Leave a fizzy trail that hurts your rival.",
		color = { r = 96, g = 255, b = 214 }, starter = true, rarity = "common" },
	Magnet = { id = "Magnet", kind = "wild", name = "Magnet", icon = "🧲", word = "PULL!",
		when = "AFTER YOU ATTACK", promise = "Pull your rival close for a moment.",
		color = { r = 255, g = 120, b = 190 }, starter = true, rarity = "common" },
	SecondWind = { id = "SecondWind", kind = "wild", name = "Second Wind", icon = "💨", word = "SECOND WIND!",
		when = "ON YOUR LAST ARMOR", promise = "Fly faster and attack sooner.",
		color = { r = 130, g = 255, b = 190 }, starter = true, rarity = "common" },
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
