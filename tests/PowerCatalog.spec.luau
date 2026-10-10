-- Pure catalog checks: require(thisModule)(PowerCatalog).
return function(PowerCatalog)
	local expected = { "Pinball", "Muncher", "Meteor" }
	local all = PowerCatalog.all()
	assert(PowerCatalog.DEFAULT_ID == "Pinball" and #all == #expected, "Round power roster changed")
	for index, id in ipairs(expected) do
		local power = PowerCatalog.get(id)
		assert(power and power.id == id and all[index].id == id, "Power is missing or draft order changed")
		assert(type(power.name) == "string" and #power.name > 0 and #power.description > 20 and #power.aimHint > 15, "Choice lacks readable gameplay guidance")
		for _, channel in ipairs({ "r", "g", "b" }) do
			local value = power.color[channel]
			assert(type(value) == "number" and value >= 0 and value <= 255, "Power color is invalid")
		end
	end
	local copied = PowerCatalog.get("Pinball")
	copied.id, copied.color.r = "Meteor", -1
	all[1].name, all[1].color.g = "Changed", -1
	all[2] = nil
	assert(PowerCatalog.get("Pinball").id == "Pinball" and PowerCatalog.get("Pinball").color.r == 255, "get leaked a mutable catalog record")
	assert(PowerCatalog.all()[1].name == "Pinball" and PowerCatalog.all()[1].color.g == 218 and #PowerCatalog.all() == 3, "all leaked catalog state")
	for _, invalid in ipairs({ "", "pinball", "Shield", "Unknown", 1, true, {} }) do
		assert(PowerCatalog.get(invalid) == nil, "Invalid power ID was accepted")
	end
	assert(PowerCatalog.get(nil) == nil, "Missing power ID was accepted")
	return "6 PowerCatalog tests passed"
end
