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
SkillCatalog.DEFAULT_OFFENCE = "Bolt"
SkillCatalog.ROSTER_VERSION = "sky-battle-tops-v2"
SkillCatalog.CONTRACT_VERSION = "sky-battle-ring-v2"

-- Order is display order. `starter` skills are owned from the first fight.
-- Rarity says how strange a skill is, never how strong. `teaser` is the one
-- line shown for a card the player has not met yet.
local order = { "Bolt", "Cyclone", "Boulder", "Drifter", "Heavy", "Spikes", "Turbo", "Guard", "Flywheel", "LeftSpin" }
local skills = {
	Bolt = { id = "Bolt", kind = "offence", name = "Bolt", icon = "⚡", word = "CRACK!", role = "ATTACK",
		teaser = "It never stops moving.",
		promise = "Grippy tip, jagged rim. Tears round the bowl and hits hard, but burns its spin fast.",
		color = { r = 255, g = 205, b = 70 }, starter = true, rarity = "common" },
	Cyclone = { id = "Cyclone", kind = "offence", name = "Cyclone", icon = "🌀", word = "WHIRR!", role = "STAMINA",
		teaser = "Still spinning when the rest have stopped.",
		promise = "Needle tip. Sits in the middle and spins for ages, but a good hit sends it sliding.",
		color = { r = 110, g = 215, b = 255 }, starter = true, rarity = "common" },
	Boulder = { id = "Boulder", kind = "offence", name = "Boulder", icon = "⛰️", word = "CLANG!", role = "DEFENSE",
		teaser = "Good luck moving it.",
		promise = "Heavy, with a ball tip and a smooth rim. Shrugs off hits and rolls back to the middle.",
		color = { r = 255, g = 140, b = 90 }, starter = true, rarity = "rare" },
	Drifter = { id = "Drifter", kind = "offence", name = "Drifter", icon = "☄️", word = "CLACK!", role = "BALANCE",
		teaser = "A bit of everything.",
		promise = "Loops wide and steady. No big weakness, no big strength.",
		color = { r = 170, g = 140, b = 255 }, starter = true, rarity = "rare" },
	Heavy = { id = "Heavy", kind = "wild", name = "Metal Weight", icon = "⚓", word = "CLUNK!",
		teaser = "Something inside it weighs a lot.",
		when = "WEIGHT", promise = "Heavier, so hits move your top less.",
		color = { r = 150, g = 170, b = 200 }, starter = true, rarity = "common" },
	Spikes = { id = "Spikes", kind = "wild", name = "Jagged Rim", icon = "🔱", word = "WHACK!",
		teaser = "Pointy on every side.",
		when = "RIM", promise = "Your rim bites: hits throw harder and cost your rival more spin.",
		color = { r = 255, g = 96, b = 110 }, starter = true, rarity = "common" },
	Turbo = { id = "Turbo", kind = "wild", name = "Rubber Tip", icon = "🔥", word = "ZOOM!",
		teaser = "Faster than it looks.",
		when = "TIP", promise = "More grip: your top moves a little faster, slides less when hit and wastes less spin.",
		color = { r = 255, g = 168, b = 66 }, starter = true, rarity = "common" },
	Guard = { id = "Guard", kind = "wild", name = "Free-Spin Guard", icon = "🛡️", word = "TING!",
		teaser = "Hits slide right off.",
		when = "RIM", promise = "A loose outer ring soaks up hits: less recoil and less spin lost.",
		color = { r = 196, g = 255, b = 91 }, starter = true, rarity = "rare" },
	Flywheel = { id = "Flywheel", kind = "wild", name = "Flywheel", icon = "⚙️", word = "HUMMM!",
		teaser = "It just keeps going.",
		when = "WEIGHT", promise = "Starts with more spin and holds on to it longer.",
		color = { r = 255, g = 225, b = 120 }, starter = true, rarity = "rare" },
	LeftSpin = { id = "LeftSpin", kind = "wild", name = "Left Spin", icon = "↩️", word = "GRIND!",
		teaser = "It turns the other way.",
		when = "SPIN", promise = "Spin the other way. Touches grind instead of smash, and the slower top steals spin.",
		color = { r = 120, g = 200, b = 255 }, starter = true, rarity = "epic" },
}

-- Cards from the plane fight this game used to be. A saved profile may still
-- list them; they are dropped quietly instead of spoiling the save.
SkillCatalog.RETIRED = {}
for _, id in ipairs({ "Meteor", "Firework", "MachineGun", "Pinball", "Sniper", "Boomerang", "BlackHole", "UFOBeam",
	"Afterburner", "SpringBumper", "FizzyFuel", "Magnet", "SecondWind", "Squadron", "Giant", "Eject", "Vampire",
	"Chicken", "Bug", "Snowball", "Swap", "Gambler", "Wrap", "HotPotato", "Decoy", "Thief", "Mothership", "Rewind",
	-- From the first ring-out pass, before the tops had real spin.
	"Pogo", "Claws", "Bumper", "Jetpack" }) do
	SkillCatalog.RETIRED[id] = true
end

-- The short words shown for a top in a fight.
function SkillCatalog.tells(offenceId)
	local entry = skills[offenceId]
	if not entry or entry.kind ~= "offence" then return nil end
	return { name = entry.name, icon = entry.icon, role = entry.role }
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
