--!nonstrict
-- Earned visual effects only. Nothing here modifies a flight's simulation.
local CosmeticCatalog = {}
CosmeticCatalog.DEFAULT_ID = "classic"
CosmeticCatalog.ORDER = { "classic", "skyblue", "ember", "mint", "violet", "sunset" }
CosmeticCatalog.PRACTICE_REWARD = 25
CosmeticCatalog.DUEL_REWARD = 40
CosmeticCatalog.WIN_BONUS = 20
CosmeticCatalog.DRAW_BONUS = 10

local profiles = {
	classic = { id = "classic", name = "Classic Contrail", description = "A clean white signature across the sky.", price = 0,
		rarity = "Starter", color = { r = 232, g = 243, b = 255 }, secondaryColor = { r = 160, g = 200, b = 235 }, lifetime = 0.6, width = 1, emission = 0.25 },
	skyblue = { id = "skyblue", name = "Sky Blue", description = "A bright blue ribbon for your first upgrade.", price = 40,
		rarity = "Fresh", color = { r = 67, g = 200, b = 255 }, secondaryColor = { r = 172, g = 242, b = 255 }, lifetime = 0.9, width = 1.15, emission = 0.65 },
	ember = { id = "ember", name = "Afterburner", description = "Leave a warm orange streak behind your jet.", price = 100,
		rarity = "Fresh", color = { r = 255, g = 116, b = 42 }, secondaryColor = { r = 255, g = 214, b = 79 }, lifetime = 0.85, width = 1.25, emission = 0.8 },
	mint = { id = "mint", name = "Mint Current", description = "A long cool wake in electric green.", price = 180,
		rarity = "Bright", color = { r = 72, g = 248, b = 180 }, secondaryColor = { r = 181, g = 255, b = 226 }, lifetime = 1.1, width = 1.3, emission = 0.7 },
	violet = { id = "violet", name = "Violet Pulse", description = "Paint your flight path in violet and pink.", price = 300,
		rarity = "Bright", color = { r = 167, g = 103, b = 255 }, secondaryColor = { r = 255, g = 128, b = 225 }, lifetime = 1.25, width = 1.4, emission = 0.8 },
	sunset = { id = "sunset", name = "Golden Hour", description = "A golden ribbon that fades into sunset coral.", price = 500,
		rarity = "Signature", color = { r = 255, g = 218, b = 94 }, secondaryColor = { r = 255, g = 101, b = 131 }, lifetime = 1.5, width = 1.5, emission = 0.85 },
}

function CosmeticCatalog.get(id)
	local profile = type(id) == "string" and profiles[id] or nil
	if not profile then return nil end
	local result = {}
	for key, value in pairs(profile) do
		if type(value) == "table" then
			local copy = {}
			for channel, amount in pairs(value) do copy[channel] = amount end
			result[key] = copy
		else result[key] = value end
	end
	return result
end

function CosmeticCatalog.all()
	local result = {}
	for _, id in ipairs(CosmeticCatalog.ORDER) do table.insert(result, CosmeticCatalog.get(id)) end
	return result
end

return CosmeticCatalog
