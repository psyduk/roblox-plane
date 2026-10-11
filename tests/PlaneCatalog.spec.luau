-- Pure catalog contract tests: require(thisModule)(PlaneCatalog).
return function(PlaneCatalog)
	local count, seen = 0, {}
	assert(PlaneCatalog.DEFAULT_ID == "cruiser" and #PlaneCatalog.ORDER == 7, "Expected three planes and four legendary cosmetics")
	assert(PlaneCatalog.ORDER[1] == "cruiser" and PlaneCatalog.ORDER[2] == "skyhopper" and PlaneCatalog.ORDER[3] == "dart", "Starter plane order changed")
	for _, id in ipairs(PlaneCatalog.ORDER) do
		local plane = PlaneCatalog.get(id)
		assert(not seen[id] and plane and plane.id == id and plane.available and plane.free, "Plane missing or unavailable")
		assert(PlaneCatalog.isSelectable(id) and type(plane.description) == "string" and plane.visualKey == id, "Plane metadata is incomplete")
		assert(plane.angle == plane.defaultAngle and plane.angle >= 15 and plane.angle <= 60 and plane.speed > 0, "Invalid flight profile")
		seen[id] = true
		count = count + 1
	end
	local cruiser = PlaneCatalog.get("cruiser")
	for _, id in ipairs({ "stormcrown", "ironwing", "phoenix", "riftmanta" }) do
		local look = PlaneCatalog.get(id)
		assert(seen[id] and look.rarity == "Legendary" and look.cosmeticOnly == true, "Legendary cosmetic missing from selector")
		assert(look.flightProfileId == "cruiser" and look.speed == cruiser.speed
			and look.angle == cruiser.angle and look.defaultAngle == cruiser.defaultAngle, "Cosmetic changed the underlying flight profile")
		assert(PlaneCatalog.battleVisualSize(id) == PlaneCatalog.battleVisualSize("cruiser"), "Cosmetic changed battle presentation scale")
		assert(look.battleMounts == nil and look.BATTLE_MOUNTS == nil, "Cosmetic overrides shared battle attachment locations")
		count = count + 1
	end
	local expectedMounts = { Nose = { 5.2, 0, 0 }, Belly = { 0, -1.8, 0 }, WingLeft = { -0.5, 0, -4.5 },
		WingRight = { -0.5, 0, 4.5 }, Tail = { -4.7, 0, 0 }, Centre = { 0, 0, 0 }, Top = { -1, 2.8, 0 } }
	assert(PlaneCatalog.BATTLE_CONTRACT_VERSION == 1, "Battle mount contract changed")
	for name, coordinates in pairs(expectedMounts) do
		local mount = PlaneCatalog.BATTLE_MOUNTS[name]
		assert(mount and #mount == 3, "Shared battle mount missing")
		for axis = 1, 3 do assert(mount[axis] == coordinates[axis], "Cosmetics changed shared battle mount geometry") end
		count = count + 1
	end
	local copied = PlaneCatalog.get("dart")
	copied.speed = 999
	copied.available = false
	assert(PlaneCatalog.get("dart").speed == 81 and PlaneCatalog.isSelectable("dart"), "Caller changed authoritative catalog")
	for _, id in ipairs({ "unknown", "Cruiser", "", 42, {} }) do
		assert(PlaneCatalog.get(id) == nil and not PlaneCatalog.isSelectable(id), "Invalid plane was selectable")
	end
	assert(not PlaneCatalog.isSelectable(nil) and PlaneCatalog.get(nil) == nil, "Missing plane was selectable")
	return tostring(count + 2) .. " PlaneCatalog tests passed"
end
