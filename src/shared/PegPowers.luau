--!nonstrict
-- Original working names; all powers activate on the current shot.
local PegPowers = {}

PegPowers.DEFAULT_ID = "pulse"
PegPowers.ITEMS = {
	{
		id = "pulse", name = "Pulse Pop", tagline = "LIGHT UP A CLUSTER",
		description = "Hit the green peg to light nearby targets in one burst.",
		color = { r = 85, g = 235, b = 164 },
	},
	{
		id = "split", name = "Split Shot", tagline = "DOUBLE THE CHAOS",
		description = "Hit the green peg to add a second ball. Both share one score.",
		color = { r = 90, g = 191, b = 255 },
	},
	{
		id = "return", name = "Second Wind", tagline = "ONE MORE PASS",
		description = "Hit the green peg to return through the top once. The bucket reopens after your return.",
		color = { r = 201, g = 151, b = 255 },
	},
}

local byId = {}
for _, power in ipairs(PegPowers.ITEMS) do
	byId[power.id] = power
end

function PegPowers.isValid(id)
	return type(id) == "string" and byId[id] ~= nil
end

function PegPowers.get(id)
	return byId[id] or byId[PegPowers.DEFAULT_ID]
end

return PegPowers
