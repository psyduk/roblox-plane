--!nonstrict
-- Free prototype planes. Speed belongs to the server-owned profile; players
-- choose their launch angle independently. These profiles are not ranked tiers.
local PlaneCatalog = {}

PlaneCatalog.DEFAULT_ID = "cruiser"
PlaneCatalog.ORDER = { "cruiser", "skyhopper", "dart" }
PlaneCatalog.MIN_ANGLE = 15
PlaneCatalog.MAX_ANGLE = 60

local profiles = {
	cruiser = { id = "cruiser", name = "Cruiser", angle = 35, defaultAngle = 35, speed = 72.25,
		description = "A versatile start. Aim your own flight path.", visualKey = "cruiser", available = true, free = true },
	skyhopper = { id = "skyhopper", name = "Skyhopper", angle = 48, defaultAngle = 48, speed = 64.5,
		description = "A slower launch with a high starting aim.", visualKey = "skyhopper", available = true, free = true },
	dart = { id = "dart", name = "Dart", angle = 24, defaultAngle = 24, speed = 81,
		description = "A faster launch with a low starting aim.", visualKey = "dart", available = true, free = true },
}

function PlaneCatalog.get(id)
	local profile = type(id) == "string" and profiles[id] or nil
	if not profile then return nil end
	local result = {}
	for key, value in pairs(profile) do result[key] = value end
	return result
end

function PlaneCatalog.isSelectable(id)
	local profile = type(id) == "string" and profiles[id] or nil
	return profile ~= nil and profile.available == true and profile.free == true
end

return PlaneCatalog
