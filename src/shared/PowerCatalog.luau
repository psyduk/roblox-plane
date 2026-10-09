--!nonstrict
-- Round powers are mutually exclusive, free, and automatic after takeoff.
-- Return detached records so UI decoration cannot change the shared catalog.
local PowerCatalog = {}

PowerCatalog.DEFAULT_ID = "Pinball"
local order = { "Pinball", "Muncher", "Meteor" }
local powers = {
	Pinball = { id = "Pinball", name = "Pinball", description = "Bounce off the ground three times. Every bounce kicks you forward!",
		aimHint = "Aim low. Turn the ground into a launchpad.", color = { r = 255, g = 218, b = 70 } },
	Muncher = { id = "Muncher", name = "Missile Muncher", description = "Eat three missiles. Each bite gives a bigger speed boost!",
		aimHint = "Aim into missiles. Three bites, then watch out.", color = { r = 147, g = 255, b = 70 } },
	Meteor = { id = "Meteor", name = "Meteor Dive", description = "Dive from your peak, then blast forward just above the ground!",
		aimHint = "Aim high. More height means a bigger blast.", color = { r = 255, g = 98, b = 63 } },
}

function PowerCatalog.get(id)
	local power = type(id) == "string" and powers[id] or nil
	if not power then return nil end
	local result = {}
	for key, value in pairs(power) do
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

function PowerCatalog.all()
	local result = {}
	for _, id in ipairs(order) do table.insert(result, PowerCatalog.get(id)) end
	return result
end

return PowerCatalog
