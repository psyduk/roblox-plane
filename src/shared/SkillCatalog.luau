-- Everything a pilot can bring to a fight: one spinning top and up to two
-- upgrades. This file says what each is called and how it is shown; how it
-- behaves lives in BattleSkills under the same id. Records are returned
-- detached so UI edits never change the catalog. No Roblox services are
-- required.
--
-- The match protocol still calls the two kinds "offence" (the top) and "wild"
-- (an upgrade); only the words a player reads changed.
local SkillCatalog = {}

SkillCatalog.KINDS = { "offence", "wild" }
SkillCatalog.MAX_WILD = 2
SkillCatalog.DEFAULT_OFFENCE = "Boulder"
SkillCatalog.ROSTER_VERSION = "sky-battle-tops-v1"
SkillCatalog.CONTRACT_VERSION = "sky-battle-ring-v1"

-- Order is display order. `starter` skills are owned from the first fight.
-- Rarity says how strange a skill is, never how strong. `teaser` is the one
-- line shown for a card the player has not met yet.
local order = { "Boulder", "Bolt", "Cyclone", "Pogo", "Heavy", "Spikes", "Turbo", "Claws", "Bumper", "Jetpack" }
local skills = {
	Boulder = { id = "Boulder", kind = "offence", name = "Boulder", icon = "⛰️", word = "THUD!",
		teaser = "Good luck moving it.",
		promise = "Big and heavy. Very hard to push around.",
		windupTell = "ROLLING IN...", attackTell = "THUD!",
		color = { r = 255, g = 150, b = 86 }, starter = true, rarity = "common" },
	Bolt = { id = "Bolt", kind = "offence", name = "Bolt", icon = "⚡", word = "ZAP!",
		teaser = "Blink and it is across the ring.",
		promise = "Small and light. Charges up, then dashes straight at your rival.",
		windupTell = "CHARGING...", attackTell = "DASH!",
		color = { r = 255, g = 220, b = 90 }, starter = true, rarity = "common" },
	Cyclone = { id = "Cyclone", kind = "offence", name = "Cyclone", icon = "🌀", word = "WHOOSH!",
		teaser = "It never slows down.",
		promise = "Races round the ring, then swoops in at full speed.",
		windupTell = "BUILDING SPEED...", attackTell = "SWOOP!",
		color = { r = 110, g = 220, b = 255 }, starter = true, rarity = "rare" },
	Pogo = { id = "Pogo", kind = "offence", name = "Pogo", icon = "🐸", word = "SLAM!",
		teaser = "Watch the shadow.",
		promise = "Jumps high and slams down. The shockwave throws your rival back.",
		windupTell = "CROUCHING...", attackTell = "JUMP!",
		color = { r = 160, g = 128, b = 255 }, starter = true, rarity = "rare" },
	Heavy = { id = "Heavy", kind = "wild", name = "Heavy Core", icon = "⚓", word = "CLUNK!",
		teaser = "Something inside it weighs a lot.",
		when = "ALL ROUND", promise = "Your top is bigger and heavier, so hits move it less.",
		color = { r = 150, g = 170, b = 200 }, starter = true, rarity = "common" },
	Spikes = { id = "Spikes", kind = "wild", name = "Spikes", icon = "🔱", word = "WHACK!",
		teaser = "Pointy on every side.",
		when = "WHEN YOU HIT", promise = "Your hits throw your rival further.",
		color = { r = 255, g = 96, b = 110 }, starter = true, rarity = "common" },
	Turbo = { id = "Turbo", kind = "wild", name = "Turbo", icon = "🔥", word = "ZOOM!",
		teaser = "Faster than it looks.",
		when = "ALL ROUND", promise = "Your top moves faster and gets back in the fight sooner.",
		color = { r = 255, g = 168, b = 66 }, starter = true, rarity = "common" },
	Claws = { id = "Claws", kind = "wild", name = "Claws", icon = "🦀", word = "SCREECH!",
		teaser = "It hangs on.",
		when = "NEAR THE EDGE", promise = "Dig in and brake when you slide toward the edge.",
		color = { r = 96, g = 230, b = 170 }, starter = true, rarity = "common" },
	Bumper = { id = "Bumper", kind = "wild", name = "Spring Bumper", icon = "🛡️", word = "BOING!",
		teaser = "Boing.",
		when = "FIRST HIT ON YOU", promise = "The first hit bounces off you and throws your rival instead.",
		color = { r = 196, g = 255, b = 91 }, starter = true, rarity = "rare" },
	Jetpack = { id = "Jetpack", kind = "wild", name = "Jetpack", icon = "🚀", word = "WHOOSH!",
		teaser = "Falling is not always the end.",
		when = "FIRST TIME YOU FALL", promise = "Fly back onto the ring once. Then it is out of fuel.",
		color = { r = 120, g = 200, b = 255 }, starter = true, rarity = "epic" },
}

-- Cards from the plane fight this game used to be. A saved profile may still
-- list them; they are dropped quietly instead of spoiling the save.
SkillCatalog.RETIRED = {}
for _, id in ipairs({ "Meteor", "Firework", "MachineGun", "Pinball", "Sniper", "Boomerang", "BlackHole", "UFOBeam",
	"Afterburner", "SpringBumper", "FizzyFuel", "Magnet", "SecondWind", "Squadron", "Giant", "Eject", "Vampire",
	"Chicken", "Bug", "Snowball", "Swap", "Gambler", "Wrap", "HotPotato", "Decoy", "Thief", "Mothership", "Rewind" }) do
	SkillCatalog.RETIRED[id] = true
end

-- What a top shouts while it makes its move.
function SkillCatalog.tells(offenceId)
	local entry = skills[offenceId]
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

-- A build is one top and up to MAX_WILD different upgrades. Returns a clean
-- copy, or nil and a reason. Anything a client sends goes through here.
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
