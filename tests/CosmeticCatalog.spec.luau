-- Pure catalog contract checks; visuals must never alter flight parameters.
return function(CosmeticCatalog)
	local seen, cheapest = {}, math.huge
	local all = CosmeticCatalog.all()
	assert(#all == 9 and CosmeticCatalog.get(CosmeticCatalog.DEFAULT_ID).price == 0)
	for _, item in ipairs(all) do
		assert(not seen[item.id] and type(item.name) == "string" and type(item.description) == "string")
		assert(item.price >= 0 and item.price % 1 == 0 and item.lifetime > 0 and item.width > 0)
		assert(item.speed == nil and item.power == nil and item.powerId == nil and item.gadget == nil)
		for _, color in ipairs({ item.color, item.secondaryColor }) do
			for _, channel in ipairs({ "r", "g", "b" }) do assert(color[channel] >= 0 and color[channel] <= 255) end
		end
		if item.price > 0 then cheapest = math.min(cheapest, item.price) end
		seen[item.id] = true
	end
	assert(cheapest <= CosmeticCatalog.PRACTICE_REWARD * 2, "First effect takes more than two completed practice flights")
	local copy = CosmeticCatalog.get("skyblue")
	copy.price = 0; copy.color.r = 0
	assert(CosmeticCatalog.get("skyblue").price == 40 and CosmeticCatalog.get("skyblue").color.r == 67)
	all[1].secondaryColor.r = 0
	assert(CosmeticCatalog.get("classic").secondaryColor.r == 160)
	for _, id in ipairs({ "", "unknown", "Skyblue", {}, 0, false }) do assert(CosmeticCatalog.get(id) == nil) end
	assert(CosmeticCatalog.get(nil) == nil)
	assert(CosmeticCatalog.get(CosmeticCatalog.BATTLE_GOAL_ID).price == CosmeticCatalog.BATTLE_COMPLETION_REWARD * 5)
    for _,id in ipairs(CosmeticCatalog.STARTER_CHOICES) do assert(CosmeticCatalog.get(id).earnedOnly and CosmeticCatalog.get(id).price==0) end
    return "11 CosmeticCatalog tests passed"
end
