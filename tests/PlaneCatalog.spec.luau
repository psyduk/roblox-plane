-- Pure catalog contract tests: require(thisModule)(PlaneCatalog).
return function(PlaneCatalog)
	local count, seen = 0, {}
	assert(PlaneCatalog.DEFAULT_ID == "cruiser" and #PlaneCatalog.ORDER == 3, "Starter catalog changed")
	for _, id in ipairs(PlaneCatalog.ORDER) do
		local plane = PlaneCatalog.get(id)
		assert(not seen[id] and plane.id == id and plane.available and plane.free, "Starter plane missing or unavailable")
		assert(PlaneCatalog.isSelectable(id) and type(plane.description) == "string" and plane.visualKey == id, "Plane metadata is incomplete")
		assert(plane.angle == plane.defaultAngle and plane.angle >= 15 and plane.angle <= 60 and plane.speed > 0, "Invalid flight profile")
		seen[id] = true
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
