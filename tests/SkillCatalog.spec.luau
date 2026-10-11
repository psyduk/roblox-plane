-- Pure tests: require(thisModule)(SkillCatalog) in Studio or a Lua runtime.
return function(Catalog)
	local passed = 0
	local function check(value, message) assert(value, message) end
	local function test(name, callback)
		local ok, problem = pcall(callback)
		assert(ok, name .. ": " .. tostring(problem))
		passed = passed + 1
	end

	test("every skill has a kind and the copy a player reads", function()
		local seen = {}
		for _, entry in ipairs(Catalog.all()) do
			check(not seen[entry.id], "Duplicate id " .. tostring(entry.id))
			seen[entry.id] = true
			check(entry.kind == "offence" or entry.kind == "wild", "Unknown kind on " .. entry.id)
			for _, field in ipairs({ "name", "promise", "icon", "word", "rarity" }) do
				check(type(entry[field]) == "string" and #entry[field] > 0, entry.id .. " lacks " .. field)
			end
			for _, channel in ipairs({ "r", "g", "b" }) do
				check(type(entry.color[channel]) == "number" and entry.color[channel] >= 0 and entry.color[channel] <= 255, entry.id .. " has a bad colour")
			end
			check(type(entry.starter) == "boolean", entry.id .. " lacks starter")
			if entry.kind == "offence" then
				check(type(entry.windupTell) == "string" and type(entry.attackTell) == "string", entry.id .. " lacks callouts")
			end
			check(entry.price == nil and entry.robux == nil and entry.power == nil, "Catalog carries a price or strength")
		end
	end)

	test("kinds filter and starters cover a full build", function()
		local offence, wild = Catalog.all("offence"), Catalog.all("wild")
		check(#offence + #wild == #Catalog.all() and #offence >= 2 and #wild >= 3, "Kind filter lost skills")
		for _, entry in ipairs(offence) do check(entry.kind == "offence", "Wrong kind in offence list") end
		for _, entry in ipairs(wild) do check(entry.kind == "wild", "Wrong kind in wild list") end
		check(#Catalog.starters("offence") >= 1 and #Catalog.starters("wild") >= Catalog.MAX_WILD, "Starters cannot fill a build")
		check(Catalog.valid(Catalog.DEFAULT_OFFENCE, "offence"), "Default offence is missing")
		check(Catalog.valid("Meteor") and Catalog.valid("Meteor", "offence") and not Catalog.valid("Meteor", "wild"), "Kind check failed")
		check(not Catalog.valid("Paid") and not Catalog.valid({}) and not Catalog.valid(nil) and Catalog.get("Paid") == nil, "Unknown id accepted")
	end)

	test("the public first-test roster is equal and excludes expansion", function()
		local wanted = { Meteor = true, Firework = true, MachineGun = true, Pinball = true,
			Afterburner = true, SpringBumper = true, FizzyFuel = true, Magnet = true, SecondWind = true,
			Squadron = true, Giant = true, Eject = true, Vampire = true, Chicken = true }
		check(#Catalog.all("offence") == 4 and #Catalog.all("wild") == 10, "Approved roster changed")
		for _, entry in ipairs(Catalog.all()) do
			check(wanted[entry.id] and entry.starter, "Skill is gated or outside agreed roster")
		end
		check(not Catalog.valid("Copycat") and not Catalog.valid("Harpoon"), "Expansion leaked into active roster")
		check(Catalog.ROSTER_VERSION == "sky-battle-public-v1", "Roster has no version")
	end)

	test("records are detached from the catalog", function()
		for _, entry in ipairs(Catalog.all()) do
			local original = Catalog.get(entry.id)
			entry.name, entry.kind, entry.color.r = "mutated", "wild", -1
			local again = Catalog.get(entry.id)
			check(again.name == original.name and again.kind == original.kind and again.color.r == original.color.r, "UI edit reached the catalog")
		end
	end)

	test("a build is one offence and up to two different wild cards", function()
		local build = Catalog.build("Meteor", { "SpringBumper", "Afterburner" })
		check(build and build.offenceId == "Meteor" and #build.wildIds == 2, "Valid build rejected")
		check(build.wildIds[1] == "SpringBumper" and build.wildIds[2] == "Afterburner", "Pick order was not kept")
		local source = { "FizzyFuel" }
		local copy = Catalog.build("Firework", source)
		source[1] = "Afterburner"
		check(copy.wildIds[1] == "FizzyFuel", "Build shares the caller's table")
		check(#Catalog.build("Firework").wildIds == 0 and #Catalog.build("Firework", {}).wildIds == 0, "A build with no wild cards was rejected")
		local function refused(offence, wild, reason)
			local result, why = Catalog.build(offence, wild)
			check(result == nil and why == reason, "Expected " .. reason .. ", got " .. tostring(why))
		end
		refused("Unknown", {}, "offence")
		refused(nil, {}, "offence")
		refused("Afterburner", {}, "offence")
		refused("Meteor", { "Unknown" }, "wild")
		refused("Meteor", { "Firework" }, "wild")
		refused("Meteor", "Afterburner", "wild")
		refused("Meteor", { 5 }, "wild")
		refused("Meteor", { first = "Afterburner" }, "wild")
		refused("Meteor", { [2] = "Afterburner" }, "wild")
		refused("Meteor", { "Afterburner", "Afterburner" }, "duplicate")
		refused("Meteor", { "Afterburner", "SpringBumper", "FizzyFuel" }, "too many")
	end)

	return string.format("SkillCatalog: %d tests passed (copy, kinds, starters, detached records, build rules)", passed)
end
