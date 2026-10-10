-- One optional, temporary Battle Lab effect. Detached records keep UI edits
-- from changing the authoritative catalog. No Roblox services are required.
local BattleModifiers = {}

BattleModifiers.DEFAULT_ID = "None"
local order = { "None", "Afterburner", "SpringBumper", "FizzyFuel" }
local modifiers = {
	None = { id = "None", name = "No Effect", description = "Your power, with no extra effect.",
		color = { r = 194, g = 204, b = 218 } },
	Afterburner = { id = "Afterburner", name = "Afterburner", description = "Burst forward and turn tighter after attacking.",
		color = { r = 255, g = 168, b = 66 } },
	SpringBumper = { id = "SpringBumper", name = "Spring Bumper", description = "Block the first hit and spring apart.",
		color = { r = 196, g = 255, b = 91 } },
	FizzyFuel = { id = "FizzyFuel", name = "Fizzy Fuel", description = "Leave a brief wake that damages rivals.",
		color = { r = 96, g = 255, b = 214 } },
}

function BattleModifiers.valid(id)
	return type(id) == "string" and modifiers[id] ~= nil
end

function BattleModifiers.get(id)
	if not BattleModifiers.valid(id) then return nil end
	local result = {}
	for key, value in pairs(modifiers[id]) do
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

function BattleModifiers.all()
	local result = {}
	for _, id in ipairs(order) do result[#result + 1] = BattleModifiers.get(id) end
	return result
end

return BattleModifiers
