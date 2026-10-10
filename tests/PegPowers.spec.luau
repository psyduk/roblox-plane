-- Run require(thisModule)(PegPowers) in Studio or the offline pure-Lua runner.
return function(PegPowers)
	assert(PegPowers.DEFAULT_ID == "pulse", "Default power changed")
	assert(#PegPowers.ITEMS == 3, "Expected exactly three free starting powers")
	local seen = {}
	for _, power in ipairs(PegPowers.ITEMS) do
		assert(not seen[power.id], "Duplicate power id")
		seen[power.id] = true
		assert(PegPowers.isValid(power.id) and PegPowers.get(power.id) == power, "Power lookup differs")
		assert(type(power.name) == "string" and #power.description > 20 and #power.tagline > 0, "Missing player copy")
		for _, channel in ipairs({ "r", "g", "b" }) do
			assert(type(power.color[channel]) == "number" and power.color[channel] >= 0 and power.color[channel] <= 255, "Invalid RGB color")
		end
	end
	assert(seen.pulse and seen.split and seen["return"], "Power choices changed")
	for _, invalid in ipairs({ "unknown", "", 123, false, {} }) do
		assert(not PegPowers.isValid(invalid), "Invalid power accepted")
		assert(PegPowers.get(invalid).id == PegPowers.DEFAULT_ID, "Default lookup failed")
	end
	assert(PegPowers.get(nil).id == PegPowers.DEFAULT_ID, "Missing id should return default")
	return "PegPowers: catalog, names, RGB colors, three free choices and invalid-id fallback passed"
end
