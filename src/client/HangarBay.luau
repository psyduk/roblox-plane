-- The living parts of the hangar that differ for every pilot, built locally:
-- your own plane in the centre bay, the next unlock on its stand, the other
-- pilots' planes along the wall, and departures on the runway outside.
-- Everything here is presentation. Coins and ownership come from snapshots.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("FlightGame")
local Catalog = require(shared:WaitForChild("CosmeticCatalog"))
local PlaneCatalog = require(shared:WaitForChild("PlaneCatalog"))
local World = require(shared:WaitForChild("World"))

local Bay = {}
Bay.__index = Bay

local INK = Color3.fromRGB(23, 39, 77)
local CREAM = Color3.fromRGB(255, 245, 217)
local GOLD = Color3.fromRGB(255, 217, 65)
local GREEN = Color3.fromRGB(105, 226, 66)
local CYAN = Color3.fromRGB(66, 225, 239)
local STEEL = Color3.fromRGB(48, 67, 83)
local PIPS = 12

local function block(parent, name, size, color, neon, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	if shape then part.Shape = shape end
	part.Parent = parent
	return part
end

-- A camera-facing caption sized in studs, so it reads as part of the hangar.
local function caption(adornee, offset, width, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Caption"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(width, height)
	gui.StudsOffsetWorldSpace = offset
	gui.LightInfluence = 0
	gui.MaxDistance = 260
	gui.Parent = adornee
	return gui
end

local function line(gui, name, y, height, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, y)
	label.Size = UDim2.fromScale(1, height)
	label.Font = Enum.Font.FredokaOne
	label.Text = ""
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = INK
	label.TextStrokeTransparency = 0
	label.Parent = gui
	return label
end

local function makeRibbons(parent, count)
	local set = table.create(count)
	for index = 1, count do
		set[index] = block(parent, "TrailRibbon", Vector3.one, CREAM, true)
	end
	return set
end

-- A parked plane cannot draw a real Trail, so a tapered ribbon streams back
-- from the tail in the trail's catalog colors, as if in a wind tunnel.
local function flowRibbons(set, pose, scale, color, second, width, length, clock)
	local count = #set
	for index, segment in ipairs(set) do
		local t = (clock * 0.55 + (index - 1) / count) % 1
		local sway = math.sin(t * 5 + clock * 2.4) * 0.35 * t * scale
		segment.Size = Vector3.new(length / count * 1.25, 0.14 * scale, 1.4 * scale * width * (1 - t * 0.55))
		segment.CFrame = pose * CFrame.new(-3.8 * scale - t * length, 0.3 * scale + sway, 0)
		segment.Color = color:Lerp(second, t)
		-- Fade in at the tail so a wrapping segment never pops into view.
		segment.Transparency = 1 - (0.88 - t * 0.88) * math.min(1, t / 0.08)
	end
end

local function nextUnlock(economy)
	for _, id in ipairs(Catalog.ORDER) do
		local item = Catalog.get(id)
		if item.price > 0 and not economy.owned[id] then return item end
	end
	return nil
end

function Bay.new(callbacks)
	local self = setmetatable({}, Bay)
	self.send = callbacks.send
	self.openShop = callbacks.openShop
	self.reducedMotion = false
	pcall(function() self.reducedMotion = GuiService.ReducedMotionEnabled end)
	self.folder = Instance.new("Folder")
	self.folder.Name = "HangarBayVisuals"
	self.folder.Parent = workspace
	self.clock = 0
	self.lineup = {}
	self.coins = {}
	self.lineupTimer = 0
	self.celebrateUntil = 0
	self.nextDeparture = os.clock() + 5
	return self
end

function Bay:_clear()
	self.folder:ClearAllChildren()
	self.hero, self.stand, self.departure = nil, nil, nil
	self.lineup, self.coins = {}, {}
	self.lineupTimer = 0
	self.active = false
end

function Bay:_updateHero(snapshot, settings, dt)
	local bay = World.HERO_BAY
	local key = settings.planeId .. ":" .. tostring(settings.color) .. ":" .. tostring(settings.trailId)
	local hero = self.hero
	if not hero or hero.key ~= key then
		local previous = hero
		if previous then previous.holder:Destroy() end
		local holder = Instance.new("Folder")
		holder.Name = "HeroBay"
		holder.Parent = self.folder
		local model = World.createParkedPlane(holder, "HeroPlane", settings.color, settings.planeId,
			bay.position, bay.rotation, bay.scale, settings.trailId)
		local gui = caption(model.PrimaryPart, Vector3.new(0, 8.6, 0), 21, 4.8)
		hero = { key = key, holder = holder, model = model, rest = model:GetPivot(),
			ribbons = makeRibbons(holder, 9), trailId = settings.trailId, droppedAt = os.clock(),
			name = line(gui, "PlaneName", 0, 0.58, CREAM), record = line(gui, "Record", 0.6, 0.4, GOLD) }
		local plane = PlaneCatalog.get(settings.planeId) or PlaneCatalog.get(PlaneCatalog.DEFAULT_ID)
		hero.name.Text = string.upper(plane.name)
		-- A newly claimed or equipped trail flares for a moment.
		if previous and previous.trailId ~= settings.trailId then self.celebrateUntil = os.clock() + 1.2 end
		self.hero = hero
	end
	-- A swapped plane settles onto its wheels rather than appearing in place.
	local drop = self.reducedMotion and 1 or math.clamp((os.clock() - hero.droppedAt) / 0.28, 0, 1)
	if drop < 1 or hero.settled ~= true then
		hero.model:PivotTo(hero.rest + Vector3.new(0, (1 - drop) ^ 2 * 2.4, 0))
		hero.settled = drop >= 1
	end
	World.idlePlane(hero.model, dt)
	local color, second, entry = World.trailLook(settings.trailId)
	local flare = 1 + math.max(0, self.celebrateUntil - os.clock()) * 0.9
	flowRibbons(hero.ribbons, hero.model:GetPivot(), bay.scale, color, second, entry.width * flare, 15, self.clock)
	local best = snapshot.stats and tonumber(snapshot.stats.bestDistance) or 0
	hero.record.Text = best > 0 and string.format("YOUR BEST  %.1f M", best) or "FLY TO SET YOUR RECORD"
end

function Bay:_buildStand(item, settings, key)
	if self.stand then self.stand.holder:Destroy() end
	local origin = World.UNLOCK_STAND
	local holder = Instance.new("Folder")
	holder.Name = "UnlockStand"
	holder.Parent = self.folder
	local shown = item or Catalog.get(settings.trailId) or Catalog.get(Catalog.DEFAULT_ID)
	local model = World.createPlane(holder, "UnlockPlane", settings.color, settings.planeId, shown.id)
	model:ScaleTo(0.85)
	local anchor = block(holder, "CaptionAnchor", Vector3.one, CREAM)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(origin + Vector3.new(0, 7.6, 0))
	local color, second = World.trailLook(shown.id)
	local gui = caption(anchor, Vector3.new(0, 5.6, 0), 19, 6)
	local stand = { key = key, holder = holder, model = model, item = item, shown = shown,
		ribbons = makeRibbons(holder, 5), pips = table.create(PIPS), color = color, second = second,
		heading = line(gui, "Heading", 0, 0.24, CREAM), name = line(gui, "EffectName", 0.24, 0.44, color),
		progress = line(gui, "Progress", 0.7, 0.3, GOLD) }
	for index = 1, PIPS do
		local pip = block(holder, "ProgressPip", Vector3.new(2.2, 1, 0.8), STEEL, true)
		pip.CFrame = CFrame.new(origin + Vector3.new(0, 3.9, 0)) * CFrame.Angles(0, (index - 1) / PIPS * math.pi * 2, 0) * CFrame.new(0, 0, -6.4)
		stand.pips[index] = pip
	end
	stand.heading.Text = item and "NEXT UNLOCK" or "COLLECTION COMPLETE"
	stand.name.Text = string.upper(shown.name)
	self.stand = stand
	return stand
end

function Bay:_updateStand(snapshot, settings, dt)
	local economy = snapshot.economy
	self.economy = economy
	if not economy then return end
	local item = nextUnlock(economy)
	local key = (item and item.id or "complete") .. ":" .. settings.planeId .. ":" .. tostring(settings.color)
	local stand = self.stand
	if not stand or stand.key ~= key then stand = self:_buildStand(item, settings, key) end

	-- Coins earned since the pilot was last in the hangar fly from the plane to
	-- the stand. The balance shown only ever catches up to the server's value.
	local credits = math.max(0, tonumber(economy.credits) or 0)
	if self.lastCredits == nil or credits < self.lastCredits or self.reducedMotion or not self.hero then
		self.shownCredits = credits
	elseif credits > self.lastCredits then
		local gain = credits - self.lastCredits
		local count = math.clamp(math.ceil(gain / 5), 3, 12)
		local from = self.hero.model:GetPivot().Position + Vector3.new(0, 2, 0)
		for index = 1, count do
			local coin = block(self.folder, "FlyingCoin", Vector3.new(0.4, 1.7, 1.7), GOLD, true, Enum.PartType.Cylinder)
			coin.Transparency = 1
			table.insert(self.coins, { part = coin, from = from, to = World.UNLOCK_STAND + Vector3.new(0, 6.5, 0),
				age = -(index - 1) * 0.09, value = gain / count })
		end
	end
	self.lastCredits = credits
	if #self.coins == 0 then self.shownCredits = credits end
	local shown = math.min(credits, math.floor(self.shownCredits + 0.5))

	local affordable = item ~= nil and credits >= item.price
	local fraction = item and math.clamp(shown / item.price, 0, 1) or 1
	local lit = math.floor(fraction * PIPS + 0.001)
	local pulse = affordable and (0.5 + 0.5 * math.sin(self.clock * 6)) or 0
	for index, pip in ipairs(stand.pips) do
		local on = index <= lit
		pip.Color = on and (affordable and GREEN or stand.color) or STEEL
		pip.Material = on and Enum.Material.Neon or Enum.Material.Metal
		pip.Transparency = on and pulse * 0.35 or 0
	end
	if item then
		stand.progress.Text = affordable and "READY  -  CLAIM IT!" or (tostring(shown) .. " / " .. tostring(item.price) .. " COINS")
		stand.progress.TextColor3 = affordable and GREEN or GOLD
	else
		stand.progress.Text = "FLY YOUR SIGNATURE TRAIL"
	end
	stand.angle = ((stand.angle or 0) + dt * (affordable and 1.5 or 0.5) * (self.reducedMotion and 0 or 1)) % (math.pi * 2)
	local pose = CFrame.new(World.UNLOCK_STAND + Vector3.new(0, 7.6 + math.sin(self.clock * 1.6) * 0.3, 0))
		* CFrame.Angles(0, stand.angle, 0) * CFrame.Angles(0, 0, 0.14)
	stand.model:PivotTo(pose)
	World.idlePlane(stand.model, dt)
	local _, _, entry = World.trailLook(stand.shown.id)
	flowRibbons(stand.ribbons, pose, 0.85, stand.color, stand.second, entry.width, 8, self.clock)

	local lobby = workspace:FindFirstChild("FlightLobby")
	local pedestal = lobby and lobby:FindFirstChild("UnlockPedestal")
	local prompt = pedestal and pedestal:FindFirstChild("UnlockStandPrompt")
	if prompt then
		prompt.ActionText = affordable and economy.canShop and ("Claim " .. item.name) or (item and "View effect" or "Browse effects")
		prompt.ObjectText = item and "NEXT UNLOCK" or "FLIGHT EFFECTS"
	end

	-- A claim buys the effect, then equips it once the server confirms ownership.
	local pending = self.pendingEquip
	if pending then
		if economy.equippedTrail == pending then
			self.pendingEquip = nil
		elseif economy.owned[pending] then
			if os.clock() >= self.equipAt then
				self.equipAt = os.clock() + 1
				self.send("equipCosmetic", { itemId = pending })
			end
		elseif os.clock() > self.claimLockUntil + 1 then
			self.pendingEquip = nil
		end
	end
end

function Bay:activateStand()
	local economy = self.economy
	local item = economy and nextUnlock(economy)
	if item and economy.canShop and economy.credits >= item.price then
		if os.clock() < (self.claimLockUntil or 0) then return end
		self.claimLockUntil = os.clock() + 2
		self.pendingEquip, self.equipAt = item.id, os.clock() + 0.4
		self.send("buyCosmetic", { itemId = item.id })
	else
		self.openShop(item and item.id or nil)
	end
end

function Bay:_updateCoins(dt)
	for index = #self.coins, 1, -1 do
		local coin = self.coins[index]
		coin.age += dt
		local t = coin.age / 0.8
		if t >= 1 then
			coin.part:Destroy()
			table.remove(self.coins, index)
			self.shownCredits = (self.shownCredits or 0) + coin.value
		elseif t > 0 then
			local eased = t * t * (3 - 2 * t)
			coin.part.Transparency = 0
			coin.part.CFrame = CFrame.new(coin.from:Lerp(coin.to, eased) + Vector3.new(0, math.sin(eased * math.pi) * 9, 0))
				* CFrame.Angles(0, coin.age * 9, 0)
		end
	end
end

function Bay:_updateLineup(dt)
	self.lineupTimer -= dt
	if self.lineupTimer <= 0 then
		self.lineupTimer = 0.5
		local seen = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local slot = player:GetAttribute("SkyboundBay")
			local bay = player ~= Players.LocalPlayer and type(slot) == "number" and World.LINEUP_BAYS[slot] or nil
			if bay then
				seen[slot] = true
				local planeId = player:GetAttribute("SkyboundPlane") or PlaneCatalog.DEFAULT_ID
				local color = player:GetAttribute("SkyboundColor") or 1
				local trailId = player:GetAttribute("SkyboundTrail") or Catalog.DEFAULT_ID
				local flying = player:GetAttribute("SkyboundFlying") == true
				local key = table.concat({ tostring(player.UserId), tostring(planeId), tostring(color), tostring(trailId), tostring(flying) }, ":")
				local entry = self.lineup[slot]
				if not entry or entry.key ~= key then
					if entry then entry.holder:Destroy() end
					local holder = Instance.new("Folder")
					holder.Name = "ClubBay" .. tostring(slot)
					holder.Parent = self.folder
					local anchor = block(holder, "CaptionAnchor", Vector3.one, CREAM)
					anchor.Transparency = 1
					anchor.CFrame = CFrame.new(bay.position + Vector3.new(0, 4, 0))
					local gui = caption(anchor, Vector3.new(0, 7, 0), 20, 5)
					line(gui, "Pilot", 0, 0.58, CREAM).Text = string.upper(player.DisplayName)
					line(gui, "Status", 0.6, 0.4, flying and GOLD or CYAN).Text = flying and "FLYING NOW" or "IN THE HANGAR"
					entry = { key = key, holder = holder, bay = bay, trailId = trailId }
					-- A pilot who is in a duel has taken their plane with them.
					if not flying then
						entry.model = World.createParkedPlane(holder, "ClubPlane", color, planeId, bay.position, bay.rotation, bay.scale, trailId)
						entry.ribbons = makeRibbons(holder, 5)
					end
					self.lineup[slot] = entry
				end
			end
		end
		for slot, entry in pairs(self.lineup) do
			if not seen[slot] then entry.holder:Destroy(); self.lineup[slot] = nil end
		end
	end
	for _, entry in pairs(self.lineup) do
		if entry.model then
			World.idlePlane(entry.model, dt)
			local color, second, trail = World.trailLook(entry.trailId)
			flowRibbons(entry.ribbons, entry.model:GetPivot(), entry.bay.scale, color, second, trail.width, 9, self.clock)
		end
	end
end

-- Planes leave from the runway outside the doors: on a timer, and promptly
-- whenever another duel starts on this server.
function Bay:_updateDeparture(dt)
	if self.reducedMotion then return end
	local duels = shared:GetAttribute("ActiveDuels") or 0
	if duels > (self.lastDuels or 0) then self.nextDeparture = math.min(self.nextDeparture, os.clock() + 0.5) end
	self.lastDuels = duels
	local flight = self.departure
	if not flight then
		if os.clock() < self.nextDeparture then return end
		local planeId = PlaneCatalog.ORDER[math.random(1, #PlaneCatalog.ORDER)]
		local trailId = Catalog.ORDER[math.random(1, #Catalog.ORDER)]
		local model = World.createParkedPlane(self.folder, "DepartingPlane", math.random(1, 4), planeId,
			Vector3.new(0, 4, -150), math.pi / 2, 1.8, trailId)
		self.departure = { model = model, age = 0, height = model:GetPivot().Position.Y }
		return
	end
	flight.age += dt
	local roll = 17 * flight.age * flight.age
	local climb = math.max(0, flight.age - 3.2)
	flight.model:PivotTo(CFrame.new(0, flight.height + climb * climb * 9, -150 - roll)
		* CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, math.min(0.38, climb * 0.3)))
	World.idlePlane(flight.model, dt, true)
	if flight.age > 7 then
		flight.model:Destroy()
		self.departure = nil
		self.nextDeparture = os.clock() + 12 + math.random() * 8
	end
end

-- `settings` is the local pilot's authoritative loadout from the snapshot.
function Bay:update(snapshot, settings, inHub, dt)
	if not inHub or not settings then
		if self.active then self:_clear() end
		return
	end
	self.active = true
	if not self.reducedMotion then self.clock += dt end
	self:_updateHero(snapshot, settings, dt)
	self:_updateStand(snapshot, settings, dt)
	self:_updateCoins(dt)
	self:_updateLineup(dt)
	self:_updateDeparture(dt)
end

function Bay:destroy()
	self.folder:Destroy()
end

return Bay
