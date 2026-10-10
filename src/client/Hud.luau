-- SKYBOUND's client-only presentation. Match state and rewards stay on the server.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PlaneCatalog = require(ReplicatedStorage:WaitForChild("FlightGame"):WaitForChild("PlaneCatalog"))
local PowerCatalog = require(ReplicatedStorage:WaitForChild("FlightGame"):WaitForChild("PowerCatalog"))
local CosmeticCatalog = require(ReplicatedStorage:WaitForChild("FlightGame"):WaitForChild("CosmeticCatalog"))
local Simulation = require(ReplicatedStorage:WaitForChild("FlightGame"):WaitForChild("Simulation"))

local Hud = {}
Hud.__index = Hud

local COLORS = {
	ink = Color3.fromRGB(23, 39, 77),
	muted = Color3.fromRGB(67, 87, 117),
	white = Color3.fromRGB(255, 254, 247),
	soft = Color3.fromRGB(214, 236, 253),
	blue = Color3.fromRGB(20, 109, 211),
	cyan = Color3.fromRGB(64, 224, 248),
	green = Color3.fromRGB(105, 226, 66),
	coral = Color3.fromRGB(242, 79, 106),
	line = Color3.fromRGB(156, 191, 221),
	gold = Color3.fromRGB(255, 217, 65),
	amber = Color3.fromRGB(153, 79, 12),
}
local DISPLAY_TEXT = {
	Brand = true, Title = true, Timer = true, Name = true, Votes = true,
	Distance = true, OpponentDistance = true, YourDistance = true, BestDistance = true,
	Lead = true, Rank = true, RewardAmount = true, RewardGoal = true,
}
local PAINTS = {
	Color3.fromRGB(255, 104, 102),
	Color3.fromRGB(66, 225, 239),
	Color3.fromRGB(255, 212, 80),
	Color3.fromRGB(184, 138, 255),
}
local PAINT_NAMES = { "Coral", "Cyan", "Gold", "Lilac" }
local POWER_IDS = { "Pinball", "Muncher", "Meteor" }
local POWER_COPY = {
	Pinball = { promise = "Turn crashes into takeoffs.", plan = "AIM LOW · BOUNCE FAR", sound = "BOING!" },
	Muncher = { promise = "Danger is your rocket fuel.", plan = "AIM AT THE MISSILES", sound = "CHOMP!" },
	Meteor = { promise = "Drop hard. Blast forward.", plan = "AIM HIGH · BUILD SPEED", sound = "BOOOM!" },
}
local PHASE_NAMES = {
	Lobby = "FLIGHT CLUB",
	Queued = "FINDING YOUR RIVAL",
	Waiting = "GETTING READY",
	Voting = "CHOOSE A COURSE",
	Configure = "CHOOSE YOUR POWER",
	Aim = "AIM YOUR JET",
	Countdown = "CLEARED FOR TAKEOFF",
	Flight = "GO THE DISTANCE",
	Results = "FLIGHT RESULTS",
}

local function create(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in pairs(properties) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 14) }, parent)
end

local function stroke(parent, color, thickness)
	local edge = parent:FindFirstChild("Border") or create("UIStroke", {
		Name = "Border", ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
	edge.Color = color or COLORS.ink
	edge.Thickness = thickness or 2
	return edge
end

local function gloss(parent)
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(207, 225, 245)),
	}, parent)
end

local function frame(parent, name, x, y, width, height, color)
	return create("Frame", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = color or COLORS.white,
		BorderSizePixel = 0,
	}, parent)
end

local function label(parent, name, text, x, y, width, height, size, color, bold)
	local display = DISPLAY_TEXT[name] == true
	local result = create("TextLabel", {
		Name = name,
		Text = text,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		TextColor3 = display and (name == "Timer" or name == "Brand") and COLORS.gold
			or (display and COLORS.white or color or COLORS.ink),
		Font = display and Enum.Font.FredokaOne or (bold and Enum.Font.GothamBold or Enum.Font.GothamMedium),
		TextSize = size or 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
	if display then
		create("UIStroke", {
			Name = "LetterOutline", Color = COLORS.ink, Thickness = size >= 23 and 2 or 1.4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}, result)
	end
	return result
end

local function button(parent, name, text, x, y, width, height, color)
	local result = create("TextButton", {
		Name = name,
		Text = text,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = color or COLORS.soft,
		BorderSizePixel = 0,
		TextColor3 = COLORS.white,
		TextStrokeColor3 = COLORS.ink,
		TextStrokeTransparency = 0,
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		AutoButtonColor = true,
		Selectable = true,
	}, parent)
	corner(result, 13)
	stroke(result, COLORS.ink, 2)
	gloss(result)
	local lip = frame(result, "BottomLip", 0, 0, 0, 4, COLORS.ink)
	lip.Position = UDim2.new(0.04, 0, 1, -7)
	lip.Size = UDim2.new(0.92, 0, 0, 4)
	lip.BackgroundTransparency = 0.75
	corner(lip, 2)
	return result
end

-- Native silhouettes stay crisp at both desktop and compact phone badge sizes.
local function courseIcon(badge, name)
	local function shape(id, x, y, w, h, round, color, rotation)
		local part = frame(badge, id, 0, 0, 0, 0, color or COLORS.white)
		part.Position, part.Size = UDim2.fromScale(x, y), UDim2.fromScale(w, h)
		part.Rotation = rotation or 0
		if round then corner(part, 100) end
		return part
	end
	if name == "Skyline" then
		shape("TowerLeft", 0.18, 0.38, 0.2, 0.42)
		shape("TowerTall", 0.42, 0.18, 0.22, 0.62)
		shape("TowerRight", 0.68, 0.46, 0.15, 0.34)
		shape("Window", 0.47, 0.3, 0.1, 0.09, false, COLORS.ink)
	elseif name == "Storm" then
		shape("BoltTop", 0.44, 0.15, 0.2, 0.43, false, COLORS.gold, 28)
		shape("BoltBar", 0.32, 0.43, 0.38, 0.14, false, COLORS.gold)
		shape("BoltBottom", 0.34, 0.46, 0.2, 0.4, false, COLORS.gold, 28)
	else
		shape("CloudLeft", 0.13, 0.4, 0.43, 0.32, true)
		shape("CloudTop", 0.34, 0.23, 0.4, 0.48, true)
		shape("CloudRight", 0.55, 0.43, 0.34, 0.29, true)
	end
end

local function distance(value, precise)
	if precise then return string.format("%.1f m", tonumber(value) or 0) end
	return string.format("%s m", tostring(math.floor((tonumber(value) or 0) + 0.5)))
end

local function sameSettings(a, b)
	return a and b and a.planeId == b.planeId and a.angle == b.angle
		and a.powerId == b.powerId and a.color == b.color
end

local function selection(settings)
	settings = settings or {}
	local planeId = table.find(PlaneCatalog.ORDER, settings.planeId) and settings.planeId or PlaneCatalog.DEFAULT_ID
	local plane = PlaneCatalog.get(planeId)
	local angle = settings.angle
	if type(angle) ~= "number" or angle ~= angle or math.abs(angle) == math.huge then angle = plane.angle end
	return {
		planeId = planeId,
		angle = math.clamp(math.round(angle), 15, 60),
		powerId = table.find(POWER_IDS, settings.powerId) and settings.powerId or PowerCatalog.DEFAULT_ID,
		gadget = "Shield", -- Kept in the payload for older clients; powers replace gadgets.
		color = type(settings.color) == "number" and math.clamp(math.floor(settings.color), 1, #PAINTS) or 1,
	}
end

-- Forward pointing keeps the last valid angle near the pivot or behind the jet.
local function forwardAimAngle(origin, pointer)
	local direction = pointer - origin
	if direction.Magnitude < 16 or direction.X <= 0 then return nil end
	return math.clamp(math.round(math.deg(math.atan2(-direction.Y, direction.X))), 15, 60)
end

local function statNumber(value)
	return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end

function Hud:_connect(signal, handler)
	table.insert(self.connections, signal:Connect(handler))
end

function Hud:_call(name, ...)
	local handler = self.callbacks[name]
	if handler then
		handler(...)
	end
end

-- Each target owns at most one finite tween. Resize, selection, and destruction
-- can replace it without leaving animation tasks or signal connections behind.
function Hud:_tween(target, duration, properties, delay, reverses)
	if self.tweens[target] then self.tweens[target]:Cancel() end
	if self.reducedMotion then
		if not reverses then
			for key, value in pairs(properties) do target[key] = value end
		end
		return
	end
	local tween = TweenService:Create(target, TweenInfo.new(duration, Enum.EasingStyle.Back,
		Enum.EasingDirection.Out, 0, reverses == true, delay or 0), properties)
	self.tweens[target] = tween
	tween:Play()
end

local function powerColor(id)
	local color = PowerCatalog.get(id).color
	return Color3.fromRGB(color.r, color.g, color.b)
end

local function powerArtwork(parent, id)
	local art = frame(parent, "Artwork", 0, 0, 160, 108, COLORS.white)
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	local scale = create("UIScale", { Scale = 1 }, art)
	local function shape(name, x, y, w, h, color, rotation, round)
		local part = frame(art, name, x, y, w, h, color)
		part.Rotation = rotation or 0
		if round then corner(part, round) end
		return part
	end
	if id == "Pinball" then
		local ring = shape("BounceRing", 35, 5, 90, 90, COLORS.white, 0, 90)
		ring.BackgroundTransparency = 0.65
		stroke(ring, COLORS.white, 5)
		shape("Ground", 20, 98, 120, 5, COLORS.ink, 0, 3)
		for index = 1, 3 do shape("BounceMark" .. index, 33 + index * 21, 89, 6, 6, COLORS.white, -25, 6) end
	elseif id == "Meteor" then
		shape("OuterFlame", 15, 21, 108, 39, Color3.fromRGB(255, 88, 43), 27, 25)
		shape("MiddleFlame", 28, 26, 96, 32, COLORS.gold, 27, 25)
		shape("InnerFlame", 49, 38, 77, 19, COLORS.white, 27, 25)
	else
		shape("ChompHalo", 27, 4, 103, 90, Color3.fromRGB(55, 125, 49), -12, 65)
		for index = 1, 3 do shape("SpeedLine" .. index, 9, 29 + index * 15, 35, 5, COLORS.white, 0, 3) end
	end
	local jet = frame(art, "Plane", 80, 50, 100, 66, COLORS.white)
	jet.AnchorPoint = Vector2.new(0.5, 0.5)
	jet.BackgroundTransparency = 1
	jet.Rotation = id == "Meteor" and 25 or -15
	local function part(name, x, y, w, h, color, rotation)
		local item = frame(jet, name, x, y, w, h, color)
		item.Rotation = rotation or 0
		corner(item, 6)
		stroke(item, COLORS.ink, 2)
		return item
	end
	part("Tail", 9, 13, 18, 42, COLORS.white, -20)
	part("Wing", 42, 5, 21, 58, COLORS.white, -20)
	part("Body", 10, 25, 84, 20, COLORS.white)
	part("Cockpit", 68, 28, 15, 9, COLORS.cyan)
	if id == "Muncher" then
		local mouth = part("Mouth", 77, 18, 33, 33, COLORS.ink)
		corner(mouth, 16)
		for index = 1, 3 do
			local tooth = frame(mouth, "TopTooth" .. index, 5 + (index - 1) * 9, 2, 6, 10, COLORS.white)
			corner(tooth, 2)
			local bottom = frame(mouth, "BottomTooth" .. index, 5 + (index - 1) * 9, 23, 6, 8, COLORS.white)
			corner(bottom, 2)
		end
	end
	local sound = label(art, "Sound", POWER_COPY[id].sound, 59, 80, 106, 25, 19, COLORS.white, true)
	sound.Font, sound.Rotation = Enum.Font.FredokaOne, -9
	sound.TextStrokeColor3, sound.TextStrokeTransparency = COLORS.ink, 0
	return { frame = art, scale = scale, plane = jet }
end

function Hud:_animatePowerChoice(entrance)
	for index, id in ipairs(POWER_IDS) do
		local card = self.powerCards[id]
		local selected = id == self.settings.powerId
		if entrance and not self.reducedMotion then card.scale.Scale = 0.84 end
		self:_tween(card.scale, 0.3, { Scale = selected and 1.02 or 0.97 }, entrance and (index - 1) * 0.09 or 0)
		self:_tween(card.button, 0.25, { Rotation = selected and -1.5 or 0 })
		if selected and not entrance then
			local angle = id == "Meteor" and 47 or (id == "Pinball" and -34 or -5)
			self:_tween(card.art.plane, 0.24, { Rotation = angle }, 0, true)
		end
	end
end

function Hud:_showPowerBurst(title, detail, color, duration)
	self.powerBurstTitle.Text = title
	self.powerBurstDetail.Text = detail
	self.powerBurst.BackgroundColor3 = color
	self.powerBurstUntil = workspace:GetServerTimeNow() + duration
	self.powerBurst.Visible = true
	self.powerBurstScale.Scale = self.reducedMotion and 1 or 0.72
	self:_tween(self.powerBurstScale, 0.34, { Scale = 1 })
end

function Hud:_panel(name, height)
	local panel = create("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromOffset(470, height),
		Position = UDim2.new(0.5, 0, 0.5, 24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.white,
		BorderSizePixel = 0,
		Visible = false,
		CanvasSize = UDim2.fromOffset(0, height),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = COLORS.muted,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ClipsDescendants = true,
	}, self.gui)
	corner(panel, 22)
	stroke(panel, COLORS.ink, 3)
	local scale = create("UIScale", { Scale = 1 }, panel)
	table.insert(self.scaledPanels, { panel = panel, scale = scale, height = height })
	return panel
end

function Hud:_stageOpen()
	return not self.configEndsAt or self.configEndsAt <= 0 or workspace:GetServerTimeNow() < self.configEndsAt
end

function Hud:_canConfigure()
	return self.phase == "Configure" and self:_stageOpen()
end

function Hud:_canAim()
	return self.phase == "Aim" and self:_stageOpen()
end

-- Main projects the actual jet and physics arc into ScreenGui coordinates.
-- Points can extend beyond the visible aim field; those dots are simply hidden.
function Hud:updateAimProjection(origin, points, visible)
	self.aimScreenOrigin = origin
	self.aimScreenPoints = points or {}
	self.aimProjectionVisible = visible == true and origin ~= nil
	if not self.aimProjectionVisible and self.aimDrag then self:_finishAim(false) end
	self:_refreshAim()
	if self.aimFocusPending and self.aimPad.Selectable then
		self.aimFocusPending = false
		GuiService.SelectedObject = self.aimPad
	end
end

function Hud:_refreshAim()
	if not self.aimPad then return end
	local inAim = self.phase == "Aim" or self.phase == "Countdown"
	local visible = inAim and self.aimProjectionVisible == true
	local locked = not self:_canAim()
	local interactive = visible and not locked
	self.aimPad.Visible = inAim
	self.aimPad.Active, self.aimPad.Selectable = interactive, interactive
	local selected = GuiService.SelectedObject == self.aimPad
	local touch = self.aimLastTouch == true or (self.aimLastTouch == nil and UserInputService.TouchEnabled)
	self.aimHint.Text = locked and "FLIGHT PLAN LOCKED" or (selected and "D-PAD ← / → TO AIM"
		or (touch and "TAP OR DRAG TO AIM" or "CLICK OR DRAG TO AIM"))
	local size = self.aimPad.AbsoluteSize
	local short = self.lastViewport.Y < 400
	local function inside(point, margin)
		return point.X >= margin and point.Y >= margin and point.X <= size.X - margin and point.Y <= size.Y - margin
	end
	local points = self.aimScreenPoints or {}
	local dotDiameter = short and 12 or 16
	local lastDotPoint = nil
	for index, dot in ipairs(self.aimDots) do
		local point = visible and #points > 0 and points[math.clamp(math.round(index / #self.aimDots * (#points - 1)) + 1, 1, #points)] or nil
		local localPoint = point and point - self.aimPad.AbsolutePosition
		-- Leave a gap between the larger circles when a phone compresses the arc.
		dot.Visible = localPoint ~= nil and inside(localPoint, dotDiameter / 2 + 2)
			and (lastDotPoint == nil or (localPoint - lastDotPoint).Magnitude >= dotDiameter + 8)
		dot.Size = UDim2.fromOffset(dotDiameter, dotDiameter)
		if localPoint then dot.Position = UDim2.fromOffset(localPoint.X, localPoint.Y) end
		if dot.Visible then lastDotPoint = localPoint end
	end
end

function Hud:_beginAim(input)
	local touch = input.UserInputType == Enum.UserInputType.Touch
	if self.aimDrag or not self:_canAim() or not self.aimProjectionVisible or (not touch and input.UserInputType ~= Enum.UserInputType.MouseButton1) then return end
	local pointer = Vector2.new(input.Position.X, input.Position.Y)
	local fromOrigin = pointer - self.aimScreenOrigin
	if fromOrigin.X < 0 and fromOrigin.Magnitude > 16 then return end
	self.aimLastTouch = touch
	self.aimDrag = { input = input, touch = touch, startSettings = table.clone(self.settings) }
	-- Unready before aiming so the other pilot cannot start a countdown mid-drag.
	if self.ready then
		self.ready = false
		self.pendingReady = false
		self.readyPendingUntil = workspace:GetServerTimeNow() + 0.75
		self:_call("ready", false)
	end
	self:_dragAim(input.Position)
end

function Hud:_dragAim(position)
	if not self.aimDrag then return end
	if not self:_canAim() then self:_finishAim(false); return end
	-- InputObject.Position already shares the inset-adjusted GUI coordinate space.
	local pointer = Vector2.new(position.X, position.Y)
	local angle = forwardAimAngle(self.aimScreenOrigin, pointer)
	if angle then self.settings.angle = angle end
	self:_refreshSettings()
end

function Hud:_finishAim(commit)
	local drag = self.aimDrag
	if not drag then return end
	local chosen = table.clone(self.settings)
	self.aimDrag = nil
	self.settings = drag.startSettings
	if commit and self:_canAim() then self:setLocalSettings({ angle = chosen.angle }) end
	self:_refreshSettings()
end

function Hud:_refreshSettings()
	local setting = self.settings
	local plane = PlaneCatalog.get(setting.planeId)
	local power = PowerCatalog.get(setting.powerId)
	self.fixedStats.Text = string.upper(power.name) .. "  ·  " .. statNumber(setting.angle) .. "°"
	self.planeSpeed.Text = plane.name .. "  ·  " .. statNumber(plane.speed) .. " m/s"
	self.planeStrategy.Text = plane.description
	for id, control in pairs(self.planeButtons) do
		local chosen = setting.planeId == id
		control.Text = (chosen and "✓ " or "") .. PlaneCatalog.get(id).name
		control.BackgroundColor3 = chosen and COLORS.green or COLORS.blue
		self.planeStrokes[id].Thickness = chosen and 3 or 2
	end
	self.powerSummary.Text = string.upper(power.name) .. " · " .. power.description
	for id, card in pairs(self.powerCards) do
		local selected = setting.powerId == id
		card.edge.Color = selected and COLORS.white or COLORS.ink
		card.edge.Thickness = selected and 4 or 2
		card.chosen.Text = selected and "✓ YOUR POWER" or "CHOOSE"
		card.chosen.BackgroundColor3 = selected and COLORS.white or COLORS.ink
		card.chosen.TextColor3 = selected and COLORS.ink or COLORS.white
		card.button.BackgroundColor3 = powerColor(id)
	end
	for index, control in ipairs(self.colorButtons) do
		control.Text = setting.color == index and "✓" or ""
		self.colorStrokes[index].Thickness = setting.color == index and 4 or 2
	end
	self.paintName.Text = PAINT_NAMES[setting.color] .. " / cosmetic only"
	local locked = not self:_canConfigure()
	self.customizeButton.Text = self.compactPowerActions and (self.customizeOpen and "BACK TO\nPOWERS" or "PLANE /\nPAINT")
		or ((self.customizeOpen and "− " or "+ ") .. "PLANE & PAINT  ·  " .. string.upper(plane.name))
	self.readyButton.Text = self.compactPowerActions and (self.ready and "LOCKED ✓" or "LOCK IN →")
		or (self.ready and "POWER LOCKED ✓" or "LOCK IN POWER  →")
	self.readyButton.BackgroundColor3 = self.ready and COLORS.green or COLORS.gold
	self.readyButton.Active = not locked
	self.readyButton.Selectable = not locked
	for _, control in ipairs(self.configControls) do
		control.Active = not locked
		control.Selectable = not locked
		control.AutoButtonColor = not locked
	end
	for _, control in pairs(self.planeButtons) do control.Selectable = not locked and self.customizeOpen end
	for _, control in ipairs(self.colorButtons) do control.Selectable = not locked and self.customizeOpen end
	if self.displayedPower ~= setting.powerId then
		self.displayedPower = setting.powerId
		self:_animatePowerChoice(false)
	end
	self.readyButton.NextSelectionUp = self.powerCards[setting.powerId].button
	local aimLocked = not self:_canAim()
	self.aimReadyButton.Text = self.phase == "Countdown" and "LAUNCHING…" or (self.ready and "READY ✓ · WAITING" or "READY TO LAUNCH")
	self.aimReadyButton.BackgroundColor3 = self.ready and COLORS.cyan or COLORS.green
	self.aimReadyButton.Active, self.aimReadyButton.Selectable = not aimLocked, not aimLocked
	self:_refreshAim()
end

function Hud:getLocalSettings()
	return table.clone(self.settings)
end

function Hud:setLobbyView(enabled)
	self.lobbyView = enabled == true
	self.lobbyButton.Text = "LEAVE DUEL"
end

-- The keyboard/controller owner can use these to share exactly the same UI state.
function Hud:setLocalSettings(settings)
	if not self:_canConfigure() and not self:_canAim() then return end
	if self.aimDrag then self:_finishAim(false) end
	local nextSettings = table.clone(self.settings)
	if self:_canConfigure() then
		if table.find(PlaneCatalog.ORDER, settings.planeId) and nextSettings.planeId ~= settings.planeId then
			nextSettings.planeId = settings.planeId
			nextSettings.angle = PlaneCatalog.get(settings.planeId).angle
		end
		if table.find(POWER_IDS, settings.powerId) then nextSettings.powerId = settings.powerId end
		if type(settings.color) == "number" and settings.color == settings.color and math.abs(settings.color) < math.huge then
			nextSettings.color = math.clamp(math.floor(settings.color), 1, #PAINTS)
		end
	elseif type(settings.angle) == "number" and settings.angle == settings.angle and math.abs(settings.angle) < math.huge then
		nextSettings.angle = math.clamp(math.round(settings.angle), 15, 60)
	end
	if sameSettings(nextSettings, self.settings) then return end
	self.settings = nextSettings
	self.pendingSettings = table.clone(nextSettings)
	self.pendingUntil = workspace:GetServerTimeNow() + 0.75
	if self.ready then
		self.ready = false
	end
	-- Configure atomically updates the settings and clears ready on the server.
	-- A second ready command here would race its command rate limiter.
	self.pendingReady = false
	self.readyPendingUntil = self.pendingUntil
	self:_refreshSettings()
	self:_call("configure", table.clone(nextSettings))
end

function Hud:toggleReady()
	if not self:_canConfigure() and not self:_canAim() then
		return
	end
	if self.aimDrag then self:_finishAim(true) end
	self.ready = not self.ready
	if self.phase == "Configure" and self.ready then
		self:_call("powerSelect", self.settings.powerId, true)
		self:_showPowerBurst(string.upper(PowerCatalog.get(self.settings.powerId).name) .. "!", "LOCKED IN · NEXT: AIM YOUR PLANE", powerColor(self.settings.powerId), 0.85)
	end
	self.pendingReady = self.ready
	self.readyPendingUntil = workspace:GetServerTimeNow() + 0.75
	self:_refreshSettings()
	self:_call("ready", self.ready)
end

function Hud.new(callbacks)
	local self = setmetatable({}, Hud)
	self.callbacks = callbacks or {}
	self.connections = {}
	self.tweens = {}
	self.reducedMotion = false
	pcall(function() self.reducedMotion = GuiService.ReducedMotionEnabled end)
	self.scaledPanels = {}
	self.configControls = {}
	self.settings = selection({ planeId = PlaneCatalog.DEFAULT_ID, powerId = PowerCatalog.DEFAULT_ID, color = 1 })
	self.customizeOpen = false
	self.ready = false
	self.phase = "Lobby"
	self.roundId = nil
	self.lastViewport = Vector2.zero
	self.pendingUntil = 0
	self.readyPendingUntil = 0
	self.lobbyView = false
	self.rematchRequested = false
	self.rematchPendingUntil = 0
	self.canRematch = false
	self.rewardSeen, self.rewardOrder = {}, {}

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local previous = playerGui:FindFirstChild("SkyboundHUD")
	if previous then previous:Destroy() end
	self.gui = create("ScreenGui", {
		Name = "SkyboundHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
	}, playerGui)

	self.header = frame(self.gui, "Header", 16, 10, 600, 65, COLORS.blue)
	self.header.Size = UDim2.new(1, -32, 0, 65)
	corner(self.header, 16)
	stroke(self.header, COLORS.ink, 3)
	gloss(self.header)
	label(self.header, "Brand", "SKYBOUND", 18, 10, 175, 24, 23, COLORS.white, true)
	self.brandSub = label(self.header, "BrandSub", "F L I G H T   C L U B", 19, 35, 200, 17, 10, COLORS.white, true)
	self.phaseLabel = label(self.header, "Phase", "GETTING READY", 220, 14, 330, 22, 13, COLORS.white, true)
	self.phaseLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.phaseLabel.Position = UDim2.new(1, -390, 0, 13)
	self.phaseLabel.Size = UDim2.fromOffset(310, 23)
	self.courseLabel = label(self.header, "Course", "DISTANCE WINS", 220, 36, 330, 17, 11, COLORS.white)
	self.courseLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.courseLabel.Position = UDim2.new(1, -390, 0, 37)
	self.courseLabel.Size = UDim2.fromOffset(310, 17)
	self.timer = label(self.header, "Timer", "--", 0, 10, 58, 44, 28, COLORS.white, true)
	self.timer.Position = UDim2.new(1, -68, 0, 10)
	self.timer.TextXAlignment = Enum.TextXAlignment.Center
    self.footer = label(self.gui, "Prototype", "FLY · EARN COINS · COLLECT FLIGHT EFFECTS", 0, 0, 600, 18, 12, COLORS.white, true)
	self.footer.AnchorPoint = Vector2.new(0.5, 1)
	self.footer.Position = UDim2.new(0.5, 0, 1, -5)
	self.footer.TextXAlignment = Enum.TextXAlignment.Center
	self.footer.TextStrokeColor3 = COLORS.ink
	self.footer.TextStrokeTransparency = 0.25
	self.hubCard = frame(self.gui, "HubGuide", 16, 10, 320, 76, COLORS.blue)
	corner(self.hubCard, 14)
	stroke(self.hubCard, COLORS.ink, 3)
	gloss(self.hubCard)
	self.hubTitle = label(self.hubCard, "Title", "SKYBOUND / FLIGHT CLUB", 14, 9, 292, 22, 17, COLORS.white, true)
	self.hubTitle.TextScaled = true
	create("UITextSizeConstraint", { MinTextSize = 16, MaxTextSize = 27 }, self.hubTitle)
	self.hubInstruction = label(self.hubCard, "Instruction", "Walk onto a 1v1 pad with an opponent.", 14, 34, 292, 31, 12, COLORS.white)
	self.hubInstruction.TextWrapped = true
	self.hubCard.AnchorPoint = Vector2.new(0.5, 1)
	self.hubTitle.TextXAlignment = Enum.TextXAlignment.Center
	self.hubInstruction.TextXAlignment = Enum.TextXAlignment.Center
	-- One primary action: PLAY finds a rival, or flies a ghost if nobody is around.
	self.hubAction = button(self.gui, "HubAction", "PLAY", 0, 0, 280, 76, COLORS.green)
	self.hubAction.AnchorPoint = Vector2.new(0, 1)
	self:_connect(self.hubAction.Activated, function()
		if self.phase == "Queued" then self:_call("leaveQueue")
		elseif self.phase == "Lobby" then self:_call("play") end
	end)
	self.practiceButton = button(self.gui, "SoloPractice", "SOLO", 0, 0, 128, 76, COLORS.cyan)
	self.practiceButton.AnchorPoint = Vector2.new(0, 1)
	self:_connect(self.practiceButton.Activated, function()
		if self.phase == "Lobby" then self:_call("practice") end
	end)
	-- The plane parked in the bay is swapped in place, without walking anywhere.
	self.planeRow = frame(self.gui, "PlaneSelect", 0, 0, 420, 50, COLORS.ink)
	self.planeRow.AnchorPoint = Vector2.new(0.5, 1)
	self.planeRow.BackgroundTransparency = 0.12
	corner(self.planeRow, 14)
	stroke(self.planeRow, COLORS.ink, 2)
	self.planePrevious = button(self.planeRow, "PreviousPlane", "<", 4, 4, 42, 42, COLORS.blue)
	self.planeNext = button(self.planeRow, "NextPlane", ">", 0, 4, 42, 42, COLORS.blue)
	self.paintButton = button(self.planeRow, "Paint", "", 0, 4, 42, 42, PAINTS[1])
	self.planeName = label(self.planeRow, "Name", "CRUISER", 52, 2, 200, 28, 22, COLORS.white, true)
	self.planeName.TextXAlignment = Enum.TextXAlignment.Center
	self.planeName.TextScaled = true
	create("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 22 }, self.planeName)
	self.planeDetail = label(self.planeRow, "Detail", "", 52, 28, 200, 16, 11, COLORS.soft, true)
	self.planeDetail.TextXAlignment = Enum.TextXAlignment.Center
	self:_connect(self.planePrevious.Activated, function() if self.phase == "Lobby" then self:_call("cyclePlane", -1) end end)
	self:_connect(self.planeNext.Activated, function() if self.phase == "Lobby" then self:_call("cyclePlane", 1) end end)
	self:_connect(self.paintButton.Activated, function() if self.phase == "Lobby" then self:_call("cyclePaint") end end)

	self.waitingPanel = self:_panel("Waiting", 200)
	label(self.waitingPanel, "Title", "YOUR NEXT FLIGHT AWAITS", 24, 28, 422, 35, 24, COLORS.ink, true)
	local waitCopy = label(self.waitingPanel, "Copy", "Choose your launch. Chase the fuel.\nSee how far you can fly.", 24, 76, 422, 60, 18, COLORS.muted)
	waitCopy.TextWrapped = true
	self.waitingMessage = label(self.waitingPanel, "Status", "Getting the runway ready…", 24, 153, 422, 23, 13, COLORS.muted)

	self.votePanel = self:_panel("Voting", 409)
	label(self.votePanel, "Eyebrow", "NEXT STOP", 24, 20, 420, 17, 11, COLORS.muted, true)
	label(self.votePanel, "Title", "PICK YOUR SKIES", 24, 42, 420, 34, 27, COLORS.ink, true)
	self.voteButtons, self.voteCounts, self.voteStrokes = {}, {}, {}
	local courses = {
		{ "Coast", "Room to climb. Find your perfect line.", "", COLORS.blue },
		{ "Skyline", "Aim high. Keep your momentum.", "", COLORS.blue },
		{ "Storm", "Stay brave. Chase the next recovery.", "", COLORS.blue },
	}
	for index, course in ipairs(courses) do
		local name = course[1]
		local control = button(self.votePanel, name, "", 24, 91 + (index - 1) * 90, 422, 78, COLORS.soft)
		local line = stroke(control, COLORS.line, 2)
		local badge = frame(control, "Badge", 11, 12, 49, 54, course[4])
		corner(badge, 9)
		local number = label(badge, "Number", course[3], 0, 0, 49, 54, 20, COLORS.ink, true)
		number.TextXAlignment = Enum.TextXAlignment.Center
		courseIcon(badge, name)
		label(control, "Name", string.upper(name), 73, 13, 260, 24, 20, COLORS.ink, true)
		label(control, "Detail", course[2], 73, 42, 286, 18, 11, COLORS.muted)
		self.voteCounts[name] = label(control, "Votes", "0", 367, 19, 42, 26, 23, COLORS.ink, true)
		self.voteCounts[name].TextXAlignment = Enum.TextXAlignment.Center
		label(control, "VotesLabel", "VOTES", 364, 47, 47, 14, 9, COLORS.muted, true).TextXAlignment = Enum.TextXAlignment.Center
		self.voteButtons[name], self.voteStrokes[name] = control, line
		self:_connect(control.Activated, function()
			if self.phase ~= "Voting" then return end
			self.voted = name
			for key, edge in pairs(self.voteStrokes) do
				edge.Color = key == name and COLORS.ink or COLORS.line
				edge.Thickness = key == name and 3 or 2
			end
			self:_call("vote", name)
		end)
	end
	label(self.votePanel, "VoteHint", "One pilot, one vote. Ties are decided fairly.", 24, 371, 422, 20, 12, COLORS.muted)

	self.configPanel = self:_panel("Configure", 490)
	self.configPanel.BackgroundColor3 = Color3.fromRGB(38, 173, 246)
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(121, 237, 255), Color3.fromRGB(33, 145, 240)) }, self.configPanel)
	self.powerHeadline = label(self.configPanel, "PowerHeadline", "CHOOSE YOUR SUPERPOWER", 18, 14, 880, 56, 38, COLORS.white, true)
	self.powerHeadline.Font = Enum.Font.FredokaOne
	self.powerHeadline.TextXAlignment = Enum.TextXAlignment.Center
	self.powerHeadline.TextStrokeColor3, self.powerHeadline.TextStrokeTransparency = COLORS.ink, 0
	self.powerSubhead = label(self.configPanel, "PowerSubhead", "ONE PICK. ONE ROUND. GO HUGE.", 18, 69, 880, 20, 13, COLORS.ink, true)
	self.powerSubhead.TextXAlignment = Enum.TextXAlignment.Center
	self.powerCards = {}
	for index, id in ipairs(POWER_IDS) do
		local power = PowerCatalog.get(id)
		local control = button(self.configPanel, "Power_" .. id, "", 20, 110, 260, 268, powerColor(id))
		control.AnchorPoint = Vector2.new(0.5, 0.5)
		control.ClipsDescendants = false
		control.SelectionOrder = index
		local card = { button = control, edge = stroke(control, COLORS.ink, 3) }
		card.scale = create("UIScale", { Scale = 1 }, control)
		card.art = powerArtwork(control, id)
		card.title = label(control, "PowerName", string.upper(power.name), 12, 116, 236, 54, 29, COLORS.ink, true)
		card.title.Font = Enum.Font.FredokaOne
		card.title.TextWrapped = true
		card.title.TextXAlignment = Enum.TextXAlignment.Center
		card.promise = label(control, "Promise", POWER_COPY[id].promise, 12, 176, 236, 34, 14, COLORS.ink, true)
		card.promise.TextWrapped = true
		card.promise.TextXAlignment = Enum.TextXAlignment.Center
		card.plan = label(control, "AimPlan", POWER_COPY[id].plan, 10, 215, 240, 30, 12, COLORS.ink, true)
		card.plan.TextWrapped = true
		card.plan.TextXAlignment = Enum.TextXAlignment.Center
		card.chosen = label(control, "Chosen", "CHOOSE", 14, 9, 116, 21, 10, COLORS.white, true)
		card.chosen.BackgroundTransparency = 0
		card.chosen.BackgroundColor3 = COLORS.ink
		card.chosen.TextXAlignment = Enum.TextXAlignment.Center
		corner(card.chosen, 6)
		self.powerCards[id] = card
		table.insert(self.configControls, control)
		self:_connect(control.Activated, function()
			if not self:_canConfigure() then return end
			local unchanged = self.settings.powerId == id
			self:setLocalSettings({ powerId = id })
			if unchanged then self:_animatePowerChoice(false) end
			self:_call("powerSelect", id, false)
		end)
	end
	self.customizeButton = button(self.configPanel, "CustomizePlane", "+ PLANE & PAINT", 18, 398, 860, 44, COLORS.blue)
	self.customizeButton.TextSize = 14
	table.insert(self.configControls, self.customizeButton)
	self:_connect(self.customizeButton.Activated, function()
		if not self:_canConfigure() then return end
		self.customizeOpen = not self.customizeOpen
		self:_layoutPowerChoices(self.lastViewport, self.layoutHeight)
		self:_refreshSettings()
		if self.customizeOpen then
			self.configPanel.CanvasPosition = Vector2.new(0, math.max(0, self.configPanel.CanvasSize.Y.Offset - self.configPanel.Size.Y.Offset))
		else self.configPanel.CanvasPosition = Vector2.zero end
	end)
	self.customizePanel = frame(self.configPanel, "PlaneAndPaint", 18, 450, 860, 184, COLORS.soft)
	corner(self.customizePanel, 12)
	self.customizePanel.Visible = false
	self.planeButtons, self.planeStrokes = {}, {}
	for index, id in ipairs(PlaneCatalog.ORDER) do
		local control = button(self.customizePanel, "Plane_" .. id, PlaneCatalog.get(id).name, 12 + (index - 1) * 145, 12, 132, 44, COLORS.blue)
		self.planeButtons[id] = control
		self.planeStrokes[id] = stroke(control, COLORS.ink, 2)
		table.insert(self.configControls, control)
		self:_connect(control.Activated, function() self:setLocalSettings({ planeId = id }) end)
	end
	self.planeSpeed = label(self.customizePanel, "PlaneSpeed", "", 12, 66, 420, 20, 13, COLORS.ink, true)
	self.planeStrategy = label(self.customizePanel, "PlaneStrategy", "", 12, 90, 420, 20, 12, COLORS.muted)
	self.planeStrategy.TextTruncate = Enum.TextTruncate.AtEnd
	self.aimPad = create("TextButton", {
		Name = "AimPad", Text = "", Position = UDim2.fromOffset(0, 81), Size = UDim2.new(1, 0, 1, -183),
		BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Selectable = false,
		Active = false, Visible = false, ClipsDescendants = false,
	}, self.gui)
	self.aimDots = {}
	for index = 1, 26 do
		local dot = frame(self.aimPad, "Trajectory" .. index, 0, 0, 16, 16, index % 5 == 0 and COLORS.gold or COLORS.white)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		corner(dot, 10)
		stroke(dot, COLORS.ink, 2)
		table.insert(self.aimDots, dot)
	end
	-- The whole forward field accepts aiming input; only the trajectory is drawn.
	self.aimPad.NextSelectionLeft, self.aimPad.NextSelectionRight = self.aimPad, self.aimPad
	self:_connect(self.aimPad.InputBegan, function(input) self:_beginAim(input) end)
	self:_connect(UserInputService.InputBegan, function(input)
		if GuiService.SelectedObject ~= self.aimPad or not self:_canAim() then return end
		if input.KeyCode == Enum.KeyCode.DPadLeft then self:setLocalSettings({ angle = self.settings.angle - 1 })
		elseif input.KeyCode == Enum.KeyCode.DPadRight then self:setLocalSettings({ angle = self.settings.angle + 1 }) end
	end)
	self:_connect(UserInputService.InputChanged, function(input)
		local drag = self.aimDrag
		if drag and ((drag.touch and input == drag.input) or (not drag.touch and input.UserInputType == Enum.UserInputType.MouseMovement)) then
			self:_dragAim(input.Position)
		end
	end)
	self:_connect(UserInputService.InputEnded, function(input)
		local drag = self.aimDrag
		if drag and ((drag.touch and input == drag.input) or (not drag.touch and input.UserInputType == Enum.UserInputType.MouseButton1)) then
			self:_finishAim(true)
		end
	end)
	self.paintName = label(self.customizePanel, "PaintName", "", 12, 123, 210, 20, 11, COLORS.muted)
	self.colorButtons, self.colorStrokes = {}, {}
	for index, paint in ipairs(PAINTS) do
		local control = button(self.customizePanel, "Paint" .. index, "", 236 + (index - 1) * 51, 123, 44, 44, paint)
		control.TextSize = 23
		self.colorButtons[index] = control
		self.colorStrokes[index] = stroke(control, COLORS.ink, 2)
		table.insert(self.configControls, control)
		self:_connect(control.Activated, function() self:setLocalSettings({ color = index }) end)
	end
	-- The power action stays visible while secondary plane and paint choices scroll.
	self.configActions = frame(self.gui, "ConfigureActions", 0, 0, 900, 80, COLORS.ink)
	self.configActions.AnchorPoint = Vector2.new(0.5, 0)
	self.configActions.Visible = false
	corner(self.configActions, 16)
	stroke(self.configActions, COLORS.ink, 3)
	self.powerSummary = label(self.configActions, "PowerSummary", "", 16, 10, 500, 42, 13, COLORS.white, true)
	self.powerSummary.TextWrapped = true
	self.readyButton = button(self.configActions, "Ready", "LOCK IN POWER →", 590, 10, 294, 52, COLORS.gold)
	self.readyButton.TextSize = 22
	self:_connect(self.readyButton.Activated, function() self:toggleReady() end)
	self.readyStatus = label(self.configActions, "ReadyStatus", "", 16, 55, 500, 17, 11, COLORS.white)
	for index, id in ipairs(POWER_IDS) do
		local control = self.powerCards[id].button
		control.NextSelectionLeft = self.powerCards[POWER_IDS[math.max(1, index - 1)]].button
		control.NextSelectionRight = self.powerCards[POWER_IDS[math.min(#POWER_IDS, index + 1)]].button
		control.NextSelectionDown = self.readyButton
	end
	self.readyButton.NextSelectionUp = self.powerCards[PowerCatalog.DEFAULT_ID].button
	self.readyButton.NextSelectionDown = self.customizeButton
	self.aimActions = frame(self.gui, "AimActions", 0, 0, 690, 64)
	self.aimActions.AnchorPoint = Vector2.new(0.5, 1)
	self.aimActions.Position = UDim2.new(0.5, 0, 1, -28)
	self.aimActions.Visible = false
	corner(self.aimActions, 16)
	stroke(self.aimActions, COLORS.ink, 3)
	self.aimHint = label(self.aimActions, "AimHint", "CLICK OR DRAG TO AIM", 14, 7, 380, 17, 12, COLORS.ink, true)
	self.fixedStats = label(self.aimActions, "FixedPlaneStats", "", 14, 29, 380, 19, 12, COLORS.muted, true)
	self.aimStatus = label(self.aimActions, "AimStatus", "", 14, 47, 380, 13, 10, COLORS.muted)
	self.aimReadyButton = button(self.aimActions, "AimReady", "READY TO LAUNCH", 434, 8, 242, 48, COLORS.green)
	self.aimReadyButton.TextSize = 17
	self:_connect(self.aimReadyButton.Activated, function() self:toggleReady() end)
	self.aimPad.NextSelectionDown, self.aimPad.NextSelectionUp = self.aimReadyButton, self.aimReadyButton
	self.aimReadyButton.NextSelectionUp = self.aimPad

	self.flightPanel = self:_panel("Flight", 126)
	self.flightPanel.AnchorPoint = Vector2.new(0.5, 0)
	self.flightPanel.Position = UDim2.new(0.5, 0, 0, 87)
	self.watchedLabel = label(self.flightPanel, "Pilot", "YOUR FLIGHT", 20, 13, 365, 19, 11, COLORS.muted, true)
	self.flightDistance = label(self.flightPanel, "Distance", "0 m", 20, 33, 275, 46, 39, COLORS.ink, true)
	self.flightStatus = label(self.flightPanel, "Status", "FLYING", 307, 46, 142, 25, 15, COLORS.ink, true)
	self.flightStatus.TextXAlignment = Enum.TextXAlignment.Right
	frame(self.flightPanel, "Rule", 20, 88, 429, 1, COLORS.line)
	self.flightStats = label(self.flightPanel, "Stats", "ALTITUDE 0 m   /   FUEL 0   /   HITS 0", 20, 98, 429, 17, 12, COLORS.muted, true)
	self.ownPilot = label(self.flightPanel, "OwnPilot", "YOU", 16, 29, 135, 16, 11, COLORS.muted, true)
	self.opponentPilot = label(self.flightPanel, "OpponentPilot", "OPPONENT", 319, 29, 135, 16, 11, COLORS.muted, true)
	self.opponentDistance = label(self.flightPanel, "OpponentDistance", "0 m", 319, 46, 135, 34, 28, COLORS.ink, true)
	self.leadLabel = label(self.flightPanel, "Lead", "NECK AND NECK", 158, 34, 154, 24, 15, COLORS.ink, true)
	self.leadLabel.TextXAlignment = Enum.TextXAlignment.Center
	self.ownPilot.TextTruncate = Enum.TextTruncate.AtEnd
	self.opponentPilot.TextTruncate = Enum.TextTruncate.AtEnd
	self.opponentPilot.TextXAlignment = Enum.TextXAlignment.Right
	self.opponentDistance.TextXAlignment = Enum.TextXAlignment.Right
	self.toast = self:_panel("FlightEvent", 47)
	self.toast.AnchorPoint = Vector2.new(0.5, 0)
	self.toast.Position = UDim2.new(0.5, 0, 0, 226)
	self.toast.BackgroundColor3 = COLORS.cyan
	self.toastText = label(self.toast, "Text", "", 16, 9, 438, 28, 17, COLORS.ink, true)
	self.toastText.TextXAlignment = Enum.TextXAlignment.Center
	self.toastText.TextTruncate = Enum.TextTruncate.AtEnd
	self.toastText.Font = Enum.Font.FredokaOne
	self.toastText.TextStrokeColor3, self.toastText.TextStrokeTransparency = COLORS.ink, 0
	self.toastText.TextColor3 = COLORS.white
	self.toastScale = self.toast:FindFirstChildOfClass("UIScale")
	self.powerFlightBadge = frame(self.gui, "FlightPower", 0, 0, 300, 31, COLORS.gold)
	self.powerFlightBadge.AnchorPoint = Vector2.new(0.5, 0)
	self.powerFlightBadge.Visible = false
	corner(self.powerFlightBadge, 10)
	stroke(self.powerFlightBadge, COLORS.ink, 2)
	self.powerFlightText = label(self.powerFlightBadge, "PowerState", "PINBALL · 3 BOUNCES", 9, 3, 282, 25, 13, COLORS.ink, true)
	self.powerFlightText.Font = Enum.Font.FredokaOne
	self.powerFlightText.TextXAlignment = Enum.TextXAlignment.Center
	self.opponentPowerText = label(self.powerFlightBadge, "OpponentPowerState", "", 159, 3, 132, 25, 13, COLORS.cyan, true)
	self.opponentPowerText.Font = Enum.Font.FredokaOne
	self.opponentPowerText.TextXAlignment = Enum.TextXAlignment.Center
	self.powerFlightDivider = frame(self.powerFlightBadge, "Divider", 149, 6, 1, 19, COLORS.muted)
	self.powerFlightBadge.BackgroundColor3 = COLORS.ink
	self.powerBurst = frame(self.gui, "PowerLocked", 0, 0, 520, 112, COLORS.gold)
	self.powerBurst.AnchorPoint = Vector2.new(0.5, 0.5)
	self.powerBurst.Visible = false
	self.powerBurst.ZIndex = 12
	self.powerBurst.Rotation = -3
	corner(self.powerBurst, 18)
	stroke(self.powerBurst, COLORS.ink, 5)
	self.powerBurstScale = create("UIScale", { Scale = 1 }, self.powerBurst)
	self.powerBurstTitle = label(self.powerBurst, "PowerBurstTitle", "PINBALL!", 10, 5, 500, 76, 60, COLORS.white, true)
	self.powerBurstTitle.Font = Enum.Font.FredokaOne
	self.powerBurstTitle.TextScaled = true
	create("UITextSizeConstraint", { MinTextSize = 18, MaxTextSize = 60 }, self.powerBurstTitle)
	self.powerBurstTitle.TextXAlignment = Enum.TextXAlignment.Center
	self.powerBurstTitle.TextStrokeColor3, self.powerBurstTitle.TextStrokeTransparency = COLORS.ink, 0
	self.powerBurstDetail = label(self.powerBurst, "PowerBurstDetail", "LOCKED IN · NEXT: AIM YOUR PLANE", 10, 82, 500, 21, 13, COLORS.ink, true)
	self.powerBurstDetail.TextXAlignment = Enum.TextXAlignment.Center
	self.countdownText = label(self.gui, "BigCountdown", "3", 0, 0, 400, 190, 158, COLORS.gold, true)
	self.countdownText.AnchorPoint = Vector2.new(0.5, 0.5)
	self.countdownText.Position = UDim2.fromScale(0.5, 0.43)
	self.countdownText.Font = Enum.Font.FredokaOne
	self.countdownText.TextXAlignment = Enum.TextXAlignment.Center
	self.countdownText.TextStrokeColor3, self.countdownText.TextStrokeTransparency = COLORS.ink, 0
	self.countdownText.Visible = false
	self.countdownText.ZIndex = 14
	self.countdownScale = create("UIScale", { Scale = 1 }, self.countdownText)
	self.flightFeedback = {}
	for index = 1, 3 do
		local feedback = label(self.gui, "FlightFeedback" .. index, "", 0, 0, 190, 25, 20, COLORS.green, true)
		feedback.AnchorPoint = Vector2.new(0.5, 1)
		feedback.Font = Enum.Font.FredokaOne
		feedback.TextXAlignment = Enum.TextXAlignment.Center
		feedback.ZIndex = 5
		feedback.Visible = false
		create("UIStroke", {Name = "LetterOutline", Color = COLORS.ink, Thickness = 2}, feedback)
		table.insert(self.flightFeedback, feedback)
	end

	self.flightControls = self:_panel("FlightControls", 67)
	self.flightControls.AnchorPoint = Vector2.new(0.5, 1)
	self.flightControls.Position = UDim2.new(0.5, 0, 1, -31)
	local previousPilot = button(self.flightControls, "PreviousPilot", "‹", 10, 10, 48, 47)
	local nextPilot = button(self.flightControls, "NextPilot", "›", 220, 10, 48, 47)
	previousPilot.TextSize, nextPilot.TextSize = 30, 30
	self.spectateLabel = label(self.flightControls, "SpectateLabel", "WATCH PILOTS", 64, 11, 150, 45, 12, COLORS.ink, true)
	self.spectateLabel.TextXAlignment = Enum.TextXAlignment.Center
	self.lobbyButton = button(self.flightControls, "LobbyView", "LEAVE DUEL", 280, 10, 180, 47, COLORS.soft)
	self:_connect(previousPilot.Activated, function() self:_call("spectate", -1) end)
	self:_connect(nextPilot.Activated, function() self:_call("spectate", 1) end)
	self:_connect(self.lobbyButton.Activated, function()
		self:_call("returnLobby")
	end)

	self.resultsPanel = self:_panel("Results", 466)
	label(self.resultsPanel, "Eyebrow", "FURTHEST FLIGHT WINS", 24, 20, 422, 17, 11, COLORS.muted, true)
	label(self.resultsPanel, "Title", "WHAT A FLIGHT.", 24, 43, 422, 34, 27, COLORS.ink, true)
	self.resultMessage = label(self.resultsPanel, "Message", "", 24, 80, 422, 20, 12, COLORS.muted)
	self.resultRows = {}
	for index = 1, 5 do
		local row = frame(self.resultsPanel, "Rank" .. index, 24, 112 + (index - 1) * 44, 422, 37, COLORS.soft)
		corner(row, 8)
		stroke(row, COLORS.ink, 2)
		local rank = label(row, "Rank", tostring(index), 12, 0, 30, 37, 16, COLORS.muted, true)
		local name = label(row, "Pilot", "", 49, 0, 246, 37, 15, COLORS.ink, true)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local score = label(row, "Distance", "", 302, 0, 106, 37, 17, COLORS.ink, true)
		score.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(self.resultRows, { frame = row, rank = rank, name = name, distance = score })
	end
	local personal = frame(self.resultsPanel, "PersonalResult", 24, 343, 422, 75, COLORS.blue)
	corner(personal, 11)
	stroke(personal, COLORS.ink, 2)
	gloss(personal)
	label(personal, "YourLabel", "YOUR DISTANCE", 15, 11, 194, 16, 10, COLORS.white, true)
	label(personal, "BestLabel", "PERSONAL BEST", 223, 11, 183, 16, 10, COLORS.white, true)
	self.yourDistance = label(personal, "YourDistance", "0 m", 15, 33, 194, 28, 23, COLORS.white, true)
	self.bestDistance = label(personal, "BestDistance", "0 m", 223, 33, 183, 28, 23, COLORS.white, true)
	self.nextRoundLabel = label(self.resultsPanel, "NextRound", "Request a rematch or return to the club.", 24, 434, 422, 16, 12, COLORS.muted)
	self.nextRoundLabel.TextXAlignment = Enum.TextXAlignment.Center
	self.rewardPanel = frame(self.resultsPanel, "FlightReward", 24, 292, 422, 158, COLORS.ink)
	corner(self.rewardPanel, 16)
	stroke(self.rewardPanel, COLORS.gold, 3)
	self.rewardAmount = label(self.rewardPanel, "RewardAmount", "+0 COINS", 16, 8, 390, 44, 38, COLORS.gold, true)
	self.rewardAmount.TextColor3 = COLORS.gold
	self.rewardAmount.TextXAlignment = Enum.TextXAlignment.Center
	self.rewardBalance = label(self.rewardPanel, "Balance", "", 16, 53, 390, 20, 14, COLORS.white, true)
	self.rewardBalance.TextXAlignment = Enum.TextXAlignment.Center
	self.rewardGoal = label(self.rewardPanel, "RewardGoal", "NEXT: SKY BLUE", 16, 79, 390, 24, 21, COLORS.white, true)
	self.rewardGoal.TextXAlignment = Enum.TextXAlignment.Center
	create("UITextSizeConstraint", { MinTextSize = 14, MaxTextSize = 24 }, self.rewardGoal)
	self.rewardTrack = frame(self.rewardPanel, "ProgressTrack", 16, 110, 390, 14, COLORS.muted)
	corner(self.rewardTrack, 7)
	self.rewardFill = frame(self.rewardTrack, "ProgressFill", 0, 0, 0, 14, COLORS.cyan)
	corner(self.rewardFill, 7)
	self.rewardHint = label(self.rewardPanel, "ProgressHint", "", 16, 132, 390, 20, 14, COLORS.white, true)
	self.rewardHint.TextXAlignment = Enum.TextXAlignment.Center
	self.resultActions = frame(self.gui, "ResultActions", 0, 0, 470, 64)
	self.resultActions.AnchorPoint = Vector2.new(0.5, 0)
	self.resultActions.Visible = false
	corner(self.resultActions, 14)
	stroke(self.resultActions, COLORS.ink, 3)
	self.rematchButton = button(self.resultActions, "Rematch", "FLY AGAIN", 8, 8, 219, 48, COLORS.green)
	self.returnButton = button(self.resultActions, "ReturnLobby", "RETURN TO LOBBY", 239, 8, 223, 48, COLORS.soft)
	self:_connect(self.rematchButton.Activated, function()
		local now = workspace:GetServerTimeNow()
		if self.phase ~= "Results" or not self.canRematch or self.rematchRequested
			or now < self.rematchPendingUntil then return end
		-- Only the server's rematchReady flag confirms acceptance.
		self.rematchPendingUntil = now + 1
		self.rematchButton.Text = "REQUESTING…"
		self.rematchButton.Active = false
		self:_call("rematch")
	end)
	self:_connect(self.returnButton.Activated, function() self:_call("returnLobby") end)
	self.header.Visible = false
	self:_makePersonalHud()
	self:_refreshSettings()
	return self
end

function Hud:_makePersonalHud()
	self.statsButton = button(self.gui, "MyStats", "MY STATS", 16, 100, 124, 44, COLORS.gold)
	self.soundButton = button(self.gui, "SoundToggle", "SOUND ON", 152, 100, 112, 44, COLORS.blue)
	self.soundButton.TextSize = 14
	self.soundMuted = false
	self:_connect(self.soundButton.Activated, function()
		self.soundMuted = not self.soundMuted
		self.soundButton.Text = self.soundMuted and "SOUND OFF" or "SOUND ON"
		self:_call("mute", self.soundMuted)
	end)
	self.statsOverlay = frame(self.gui, "PersonalStats", 0, 0, 0, 0, COLORS.ink)
	self.statsOverlay.Size = UDim2.fromScale(1, 1)
	self.statsOverlay.BackgroundTransparency = 0.2
	self.statsOverlay.ZIndex = 20
	self.statsOverlay.Active = true
	self.statsOverlay.Visible = false
	self.statsCard = frame(self.statsOverlay, "Card", 0, 0, 470, 338, COLORS.blue)
	self.statsCard.AnchorPoint = Vector2.new(0.5, 0.5)
	self.statsCard.Position = UDim2.fromScale(0.5, 0.5)
	corner(self.statsCard, 18); stroke(self.statsCard, COLORS.ink, 3); gloss(self.statsCard)
	label(self.statsCard, "Title", "YOUR FLIGHT RECORD", 18, 13, 380, 30, 24, COLORS.white, true)
	self.statsClose = button(self.statsCard, "Close", "X", 412, 8, 44, 44, COLORS.coral)
	self.statsValues = {}
	local fields = { {"bestDistance", "FURTHEST FLIGHT"}, {"bestStreak", "BEST WIN STREAK"},
		{"wins", "DUEL WINS"}, {"currentStreak", "CURRENT STREAK"},
		{"totalFlights", "FLIGHTS FLOWN"}, {"practiceFlights", "PRACTICE FLIGHTS"} }
	self.statsCells = {}
	for index, field in ipairs(fields) do
		local cell = frame(self.statsCard, field[1], 16, 60, 210, 64, index <= 2 and COLORS.gold or COLORS.soft)
		corner(cell, 10); stroke(cell, COLORS.ink, 2)
		label(cell, "Caption", field[2], 12, 5, 184, 15, 10, COLORS.ink, true)
		self.statsValues[field[1]] = label(cell, "Distance", "0", 12, 23, 184, 32, 24, COLORS.white, true)
		table.insert(self.statsCells, cell)
	end
	self.statsRecord = label(self.statsCard, "Record", "0 wins  ·  0 losses  ·  0 draws", 18, 278, 434, 18, 11, COLORS.white, true)
	self.statsSave = label(self.statsCard, "SaveStatus", "Loading your record…", 18, 305, 434, 19, 11, COLORS.white)
	self.statsSave.TextWrapped = true
	self:_connect(self.statsButton.Activated, function() self.statsOverlay.Visible = not self.statsOverlay.Visible end)
	self:_connect(self.statsClose.Activated, function() self.statsOverlay.Visible = false end)
end

function Hud:_layoutPersonal(viewport, height)
	local width = math.min(620, viewport.X - 24)
	local short = height < 430
	local cardHeight = math.min(short and 304 or 420, height - 16)
	self.statsCard.Size = UDim2.fromOffset(width, cardHeight)
	self.statsCard.Title.TextSize = width < 400 and 22 or 30
	self.statsCard.Title.Size = UDim2.fromOffset(width - 80, 36)
	self.statsClose.Position = UDim2.fromOffset(width - 54, 10)
	local cellWidth = (width - 44) / 2
	local cellHeight = (cardHeight - 138) / 3
	for index, cell in ipairs(self.statsCells) do
		cell.Position = UDim2.fromOffset(16 + ((index - 1) % 2) * (cellWidth + 12), 61 + math.floor((index - 1) / 2) * (cellHeight + 8))
		cell.Size = UDim2.fromOffset(cellWidth, cellHeight)
		cell.Caption.Position = UDim2.fromOffset(10, 5)
		cell.Caption.Size = UDim2.fromOffset(cellWidth - 20, 18)
		cell.Caption.TextSize = width < 400 and 11 or 13
		cell.Distance.Position = UDim2.fromOffset(10, 23)
		cell.Distance.Size = UDim2.fromOffset(cellWidth - 20, math.max(22, cellHeight - 25))
		cell.Distance.TextSize = short and 25 or (width < 400 and 29 or 36)
	end
	self.statsRecord.Position = UDim2.fromOffset(18, cardHeight - 54)
	self.statsRecord.Size = UDim2.fromOffset(width - 36, 20)
	self.statsRecord.TextSize = width < 400 and 13 or 15
	self.statsSave.Position = UDim2.fromOffset(18, cardHeight - 32)
	self.statsSave.Size = UDim2.fromOffset(width - 36, 28)
	self.statsSave.TextSize = 12
end

function Hud:_layoutDuel(viewport, height)
	local function place(item, x, y, width, sizeY)
		item.Position, item.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(width, sizeY)
	end
	local portrait = viewport.X < 600
	local short = not portrait and height < 430
	-- Hub: one centered stack at the bottom. PLAY and SOLO share a row; the
	-- plane selector sits above it and gives way to the queue status.
	local margin = portrait and 12 or 16
	local blockWidth = math.min(420, viewport.X - margin * 2)
	local soloWidth = portrait and 96 or 128
	local playWidth = blockWidth - soloWidth - 8
	self.hubPlayWidth, self.hubBlockWidth = playWidth, blockWidth
	local playHeight = short and 54 or (portrait and 64 or 76)
	local blockLeft = (viewport.X - blockWidth) / 2
	-- Portrait phones keep Roblox's jump button in the bottom-right corner.
	local bottom = (short and -8 or -14) - ((portrait and UserInputService.TouchEnabled) and 104 or 0)
	self.hubAction.Position = UDim2.new(0, blockLeft, 1, bottom)
	self.hubAction.Size = UDim2.fromOffset(playWidth, playHeight)
	self.hubAction.TextSize = short and 32 or (portrait and 36 or 44)
	self.practiceButton.Position = UDim2.new(0, blockLeft + playWidth + 8, 1, bottom)
	self.practiceButton.Size = UDim2.fromOffset(soloWidth, playHeight)
	self.practiceButton.TextSize = short and 20 or 22
	local rowHeight = short and 44 or 50
	local rowBottom = bottom - playHeight - 8
	local arrow = rowHeight - 8
	self.planeRow.Position = UDim2.new(0.5, 0, 1, rowBottom)
	self.planeRow.Size = UDim2.fromOffset(blockWidth, rowHeight)
	place(self.planePrevious, 4, 4, arrow, arrow)
	place(self.planeNext, blockWidth - arrow * 2 - 10, 4, arrow, arrow)
	place(self.paintButton, blockWidth - arrow - 4, 4, arrow, arrow)
	local nameWidth = blockWidth - arrow * 3 - 26
	place(self.planeName, arrow + 10, 2, nameWidth, math.floor(rowHeight * 0.56))
	place(self.planeDetail, arrow + 10, math.floor(rowHeight * 0.58), nameWidth, math.floor(rowHeight * 0.34))
	self.planeDetail.TextSize = short and 10 or 11
	local hubHeight = short and 54 or 64
	self.hubCard.Position = UDim2.new(0.5, 0, 1, rowBottom)
	self.hubCard.Size = UDim2.fromOffset(blockWidth, hubHeight)
	place(self.hubTitle, 14, 5, blockWidth - 28, math.floor(hubHeight * 0.5))
	place(self.hubInstruction, 14, math.floor(hubHeight * 0.55), blockWidth - 28, math.floor(hubHeight * 0.38))
	self.hubInstruction.TextSize = blockWidth < 350 and 12 or 13
	local utilityY = short and 6 or 10
	local utilityWidth = portrait and (viewport.X - 36) / 2 or (short and 132 or 148)
	place(self.statsButton, margin, utilityY, utilityWidth, short and 44 or 46)
	self.statsButton.TextSize = short and 17 or 19
	self.hubSoundPosition = UDim2.fromOffset((portrait and 12 or 16) + utilityWidth + 12, utilityY)
	self.hubSoundSize = UDim2.fromOffset(utilityWidth, short and 44 or 46)
	-- Distances lead the scoreboard; two slim rows retain the shared race view.
	local flightWidth = math.min(900, viewport.X - 24)
	local flightHeight = short and 72 or (portrait and 82 or 94)
	local column = (flightWidth - 32) / 3
	self.flightPanel.Position = UDim2.new(0.5, 0, 0, 6)
	self.flightPanel.Size = UDim2.fromOffset(flightWidth, flightHeight)
	self.flightPanel.CanvasSize = UDim2.fromOffset(0, flightHeight)
	self.flightPanel.Rule.Visible = false
	local numberY, numberHeight = short and 18 or 24, short and 32 or 40
	place(self.ownPilot, 12, 4, column, 18)
	place(self.opponentPilot, flightWidth - column - 12, 4, column, 18)
	self.ownPilot.TextSize, self.opponentPilot.TextSize = portrait and 12 or 14, portrait and 12 or 14
	self.ownPilot.TextTruncate, self.opponentPilot.TextTruncate = Enum.TextTruncate.AtEnd, Enum.TextTruncate.AtEnd
	place(self.flightDistance, 12, numberY, column, numberHeight)
	place(self.opponentDistance, flightWidth - column - 12, numberY, column, numberHeight)
	self.flightDistance.TextSize, self.opponentDistance.TextSize = portrait and 30 or (short and 31 or 42), portrait and 30 or (short and 31 or 42)
	place(self.leadLabel, 16 + column, short and 8 or 12, column, portrait and 35 or 29)
	self.leadLabel.TextSize = portrait and 16 or (short and 21 or 25)
	self.leadLabel.TextWrapped = true
	place(self.flightStatus, 16 + column, short and 38 or 47, column, 21)
	self.flightStatus.TextXAlignment = Enum.TextXAlignment.Center
	self.flightStatus.TextSize = portrait and 11 or (short and 12 or 14)
	place(self.watchedLabel, 12, flightHeight - 21, flightWidth / 2 - 18, 18)
	self.watchedLabel.TextSize = portrait and 11 or 13
	place(self.flightStats, flightWidth / 2, flightHeight - 21, flightWidth / 2 - 12, 18)
	self.flightStats.TextSize = portrait and 11 or 13
	self.flightStats.TextXAlignment = Enum.TextXAlignment.Right
	self.flightStats.TextTruncate = Enum.TextTruncate.AtEnd
	self.flightControls.AnchorPoint = Vector2.new(1, 1)
	self.flightControls.Position = UDim2.new(1, -12, 1, -26)
	local controlsWidth = portrait and 274 or (short and 286 or 410)
	local controlsHeight = short and 48 or 58
	self.flightControls.Size = UDim2.fromOffset(controlsWidth, controlsHeight)
	self.flightControls.CanvasSize = UDim2.fromOffset(0, controlsHeight)
	local controlY = short and 2 or 5
	place(self.flightControls.PreviousPilot, 5, controlY, 46, 44)
	self.spectateLabel.Visible = not portrait and not short
	self.spectateLabel.Text = "CAMERA"
	self.spectateLabel.TextSize = 15
	place(self.spectateLabel, 57, controlY, 82, 44)
	local nextX = self.spectateLabel.Visible and 145 or 57
	place(self.flightControls.NextPilot, nextX, controlY, 46, 44)
	place(self.lobbyButton, nextX + 54, controlY, controlsWidth - nextX - 59, 44)
	self.lobbyButton.TextSize = portrait and 15 or 17
	self:_layoutResults(viewport, height)
end

function Hud:_layoutResults(viewport, height)
	local function place(item, x, y, width, sizeY)
		item.Position, item.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(width, sizeY)
	end
	local landscape = viewport.X >= 600 and height < 470
	local width = math.min(landscape and 960 or 620, viewport.X - 24)
	local inner = width - 32
	local top = self.header.Position.Y.Offset + self.header.Size.Y.Offset + 10
	local actionsHeight = landscape and 60 or 72
	local available = math.max(118, height - top - actionsHeight - 18)
	local contentHeight = landscape and 172 or 536
	local visible = math.min(contentHeight, available)
	self.resultsPanel.AnchorPoint = Vector2.new(0.5, 0)
	self.resultsPanel.Position = UDim2.new(0.5, 0, 0, top)
	self.resultsPanel.Size = UDim2.fromOffset(width, visible)
	self.resultsPanel.CanvasSize = UDim2.fromOffset(0, contentHeight)
	self.resultsPanel.Eyebrow.Visible = not landscape
	place(self.resultsPanel.Eyebrow, 20, 12, inner - 8, 18)
	self.resultsPanel.Eyebrow.TextSize = 12
	place(self.resultsPanel.Title, 16, landscape and 7 or 34, inner, landscape and 30 or 43)
	self.resultsPanel.Title.TextSize = landscape and 28 or (width < 430 and 29 or 39)
	place(self.resultMessage, 18, landscape and 42 or 78, inner - 4, 22)
	self.resultMessage.TextSize = width < 430 and 13 or 15
	self.resultMessage.TextTruncate = Enum.TextTruncate.AtEnd
	self.resultMessage.Visible = not landscape
	local scoreWidth = landscape and (inner - 16) / 2 or inner
	local rowY = landscape and 43 or 113
	local rowHeight = landscape and 38 or 49
	for index, row in ipairs(self.resultRows) do
		place(row.frame, 16, rowY + (index - 1) * (rowHeight + (landscape and 6 or 8)), scoreWidth, rowHeight)
		place(row.rank, 9, 0, 28, rowHeight)
		place(row.name, 42, 0, scoreWidth - 162, rowHeight)
		place(row.distance, scoreWidth - 116, 0, 105, rowHeight)
		row.rank.TextSize = 22
		row.name.TextSize = width < 430 and 14 or 17
		row.distance.TextSize = 23
	end
	local personal = self.resultsPanel.PersonalResult
	place(personal, 16, landscape and 133 or 232, scoreWidth, landscape and 30 or 75)
	local half = scoreWidth / 2
	place(personal.YourLabel, 12, 5, half - 16, 18)
	place(personal.BestLabel, half + 4, 5, half - 16, 18)
	personal.YourLabel.TextSize, personal.BestLabel.TextSize = 11, 11
	place(self.yourDistance, 12, landscape and 24 or 29, half - 16, landscape and 29 or 36)
	place(self.bestDistance, half + 4, landscape and 24 or 29, half - 16, landscape and 29 or 36)
	self.yourDistance.TextSize, self.bestDistance.TextSize = landscape and 26 or 30, landscape and 26 or 30
	personal.YourLabel.Visible, self.yourDistance.Visible = not landscape, not landscape
	if landscape then
		place(personal.BestLabel, 10, 5, half - 8, 20)
		place(self.bestDistance, half, 1, half - 12, 28)
	end
	local rewardWidth = landscape and scoreWidth or inner
	local rewardHeight = landscape and 122 or 175
	place(self.rewardPanel, landscape and 32 + scoreWidth or 16, landscape and 43 or 322, rewardWidth, rewardHeight)
	local rewardInner = rewardWidth - 24
	place(self.rewardAmount, 12, landscape and 1 or 5, rewardInner, landscape and 39 or 45)
	self.rewardAmount.TextSize = landscape and 34 or (width < 430 and 35 or 43)
	self.rewardTextSize = self.rewardAmount.TextSize
	place(self.rewardBalance, 12, landscape and 37 or 51, rewardInner, landscape and 18 or 21)
	self.rewardBalance.TextSize = 14
	place(self.rewardGoal, 12, landscape and 58 or 78, rewardInner, landscape and 24 or 27)
	self.rewardGoal.TextSize = width < 430 and 21 or 24
	self.rewardGoal.TextScaled = landscape
	place(self.rewardTrack, 14, landscape and 87 or 115, rewardWidth - 28, landscape and 10 or 14)
	place(self.rewardHint, 12, landscape and 102 or 137, rewardInner, landscape and 18 or 23)
	self.rewardHint.TextSize = landscape and 13 or 14
	self.nextRoundLabel.Visible = not landscape
	place(self.nextRoundLabel, 16, 507, inner, 20)
	self.nextRoundLabel.TextSize = 12
	self.resultActions.Position = UDim2.new(0.5, 0, 0, top + visible + 8)
	self.resultActions.Size = UDim2.fromOffset(width, actionsHeight)
	local actionWidth = (width - 24) / 2
	place(self.rematchButton, 8, 8, actionWidth, actionsHeight - 16)
	place(self.returnButton, 16 + actionWidth, 8, actionWidth, actionsHeight - 16)
	self.rematchButton.TextSize = width < 430 and 15 or 21
	self.returnButton.TextSize = width < 430 and 15 or 21
	self.rematchButton.TextWrapped, self.returnButton.TextWrapped = true, true
	self.returnButton.Text = "BACK TO HANGAR"
end

function Hud:_layoutPowerChoices(viewport, height)
	local function place(item, x, y, w, h)
		item.Position, item.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	end
	local portrait = viewport.X < 600
	local short = not portrait and height < 430
	self.compactPowerActions = portrait or short
	local width = math.min(1000, math.max(260, viewport.X - 24))
	local top = self.header.Position.Y.Offset + self.header.Size.Y.Offset + 9
	local actionHeight = portrait and 124 or (short and 72 or 92)
	local availableBody = math.max(130, height - top - actionHeight - 26)
	local headingHeight = portrait and 66 or (short and 34 or 88)
	local cardHeight = portrait and math.clamp((availableBody - headingHeight - 12) / 3 - 10, 116, 150)
		or (short and math.clamp(availableBody - headingHeight - 10, 94, 126) or 274)
	local gap = portrait and 12 or (short and 14 or 22)
	local cardWidth = portrait and width - 32 or (width - 36 - gap * 2) / 3
	local cardTop = headingHeight + (short and 2 or 7)
	local cardsBottom = cardTop + (portrait and (cardHeight * 3 + gap * 2) or cardHeight)
	local drawerTop = cardsBottom + (short and 12 or 18)
	local drawerHeight = short and 132 or 190
	local contentHeight = self.compactPowerActions and (self.customizeOpen and drawerTop + drawerHeight + 12 or cardsBottom + 12)
		or (drawerTop + 48 + (self.customizeOpen and 194 or 0) + 12)
	local bodyHeight = math.min(contentHeight, availableBody)
	self.configPanel.AnchorPoint = Vector2.new(0.5, 0)
	self.configPanel.Position = UDim2.new(0.5, 0, 0, top)
	self.configPanel.Size = UDim2.fromOffset(width, bodyHeight)
	self.configPanel.CanvasSize = UDim2.fromOffset(0, contentHeight)
	place(self.powerHeadline, 12, short and 2 or 9, width - 24, short and 30 or (portrait and 35 or 48))
	self.powerHeadline.TextSize = short and 24 or (portrait and (width < 350 and 22 or 25) or 38)
	self.powerSubhead.Visible = not short
	place(self.powerSubhead, 12, portrait and 43 or 57, width - 24, 19)
	self.powerSubhead.TextSize = portrait and 12 or 16
	for index, id in ipairs(POWER_IDS) do
		local card = self.powerCards[id]
		local x = portrait and width / 2 or 18 + cardWidth / 2 + (index - 1) * (cardWidth + gap)
		local y = cardTop + cardHeight / 2 + (portrait and (index - 1) * (cardHeight + gap) or 0)
		place(card.button, x, y, cardWidth, cardHeight)
		local title = string.upper(PowerCatalog.get(id).name)
		card.title.Text = title
		if portrait then
			local artWidth = cardWidth < 320 and 88 or 102
			local textLeft = artWidth + 8
			local textWidth = cardWidth - textLeft - 10
			card.art.frame.Position = UDim2.fromOffset(artWidth / 2 + 5, cardHeight / 2 + 5)
			card.art.scale.Scale = cardWidth < 320 and 0.59 or 0.68
			place(card.chosen, textLeft, 8, textWidth, 21)
			card.chosen.TextSize = 12
			place(card.title, textLeft, 32, textWidth, 27)
			card.title.TextSize = cardWidth < 320 and 21 or 25
			card.title.TextXAlignment = Enum.TextXAlignment.Left
			card.promise.Visible = cardHeight >= 144
			place(card.promise, textLeft, 61, textWidth, 32)
			card.promise.TextSize = 12
			card.promise.TextXAlignment = Enum.TextXAlignment.Left
			place(card.plan, textLeft, cardHeight - 37, textWidth, 28)
			card.plan.TextSize = 12
			card.plan.TextXAlignment = Enum.TextXAlignment.Left
		elseif short then
			card.art.frame.Position = UDim2.fromOffset(32, 49)
			card.art.scale.Scale = 0.34
			place(card.chosen, 7, 5, cardWidth - 14, 18)
			card.chosen.TextSize = 11
			place(card.title, 63, 27, cardWidth - 71, 44)
			card.title.TextSize = cardWidth < 205 and 18 or 21
			card.title.TextXAlignment = Enum.TextXAlignment.Center
			card.promise.Visible = false
			place(card.plan, 9, cardHeight - 33, cardWidth - 18, 27)
			card.plan.TextSize = 12
			card.plan.TextXAlignment = Enum.TextXAlignment.Center
		else
			card.art.frame.Position = UDim2.fromOffset(cardWidth / 2, 83)
			card.art.scale.Scale = math.min(1.08, cardWidth / 240)
			place(card.chosen, 12, 10, cardWidth - 24, 21)
			card.chosen.TextSize = 13
			place(card.title, 10, 142, cardWidth - 20, 59)
			card.title.TextSize = cardWidth < 240 and 25 or 30
			card.title.TextXAlignment = Enum.TextXAlignment.Center
			card.promise.Visible = true
			place(card.promise, 12, 201, cardWidth - 24, 31)
			card.promise.TextSize = 16
			card.promise.TextXAlignment = Enum.TextXAlignment.Center
			place(card.plan, 9, 238, cardWidth - 18, 26)
			card.plan.TextSize = cardWidth < 250 and 12 or 14
			card.plan.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
	self.customizeButton.Parent = self.compactPowerActions and self.configActions or self.configPanel
	if not self.compactPowerActions then place(self.customizeButton, 16, drawerTop, width - 32, 44) end
	self.customizeButton.TextSize = self.compactPowerActions and 14 or 19
	self.customizePanel.Visible = self.customizeOpen
	place(self.customizePanel, 16, drawerTop + (self.compactPowerActions and 0 or 52), width - 32, drawerHeight)
	local drawerWidth = width - 56
	local planeAreaWidth = short and (drawerWidth / 2 - 16) or drawerWidth
	local planeWidth = (planeAreaWidth - 16) / 3
	for index, id in ipairs(PlaneCatalog.ORDER) do
		place(self.planeButtons[id], 12 + (index - 1) * (planeWidth + 8), 10, planeWidth, 44)
		self.planeButtons[id].TextSize = self.compactPowerActions and 14 or 20
	end
	place(self.planeSpeed, 12, 61, planeAreaWidth, 20)
	self.planeSpeed.TextSize = self.compactPowerActions and 13 or 16
	place(self.planeStrategy, 12, 85, planeAreaWidth, 20)
	self.planeStrategy.TextSize = self.compactPowerActions and 12 or 15
	local paintLeft = short and (drawerWidth / 2 + 22) or 12
	place(self.paintName, paintLeft, short and 12 or 111, short and drawerWidth / 2 - 20 or drawerWidth, 18)
	self.paintName.TextSize = 13
	for index, control in ipairs(self.colorButtons) do place(control, paintLeft + (index - 1) * 56, short and 43 or 132, 46, 44) end
	self.configActions.Position = UDim2.new(0.5, 0, 0, top + bodyHeight + 8)
	self.configActions.Size = UDim2.fromOffset(width, actionHeight)
	if portrait then
		place(self.powerSummary, 12, 6, width - 24, 35)
		self.powerSummary.TextSize = 13
		place(self.customizeButton, 10, 48, 100, 48)
		place(self.readyButton, 118, 48, width - 128, 48)
		self.readyButton.TextSize = 20
		place(self.readyStatus, 10, 101, width - 20, 18)
		self.readyStatus.TextSize = 11
		self.readyStatus.TextXAlignment = Enum.TextXAlignment.Center
	else
		local buttonWidth = short and 226 or 286
		local summaryLeft = short and 122 or 14
		if short then place(self.customizeButton, 10, 8, 100, 44) end
		place(self.powerSummary, summaryLeft, short and 6 or 8, width - buttonWidth - summaryLeft - 30, short and 31 or 43)
		self.powerSummary.TextSize = short and 12 or 16
		place(self.readyButton, width - buttonWidth - 10, short and 8 or 12, buttonWidth, short and 44 or 54)
		self.readyButton.TextSize = short and 18 or 22
		place(self.readyStatus, summaryLeft, short and 46 or 66, width - buttonWidth - summaryLeft - 30, 19)
		self.readyStatus.TextSize = short and 11 or 13
		self.readyStatus.TextXAlignment = Enum.TextXAlignment.Left
	end
	local eventWidth = math.min(520, viewport.X - 32)
	self.powerBurst.Size = UDim2.fromOffset(eventWidth, short and 74 or 112)
	self.powerBurst.Position = UDim2.fromScale(0.5, short and 0.43 or 0.4)
	place(self.powerBurstTitle, 10, 5, eventWidth - 20, short and 44 or 76)
	self.powerBurstTitle.TextSize = short and 35 or (portrait and 39 or 60)
	place(self.powerBurstDetail, 10, short and 50 or 82, eventWidth - 20, 21)
	self.powerBurstDetail.TextSize = short and 12 or 15
	self.countdownText.Size = UDim2.fromOffset(math.min(400, viewport.X - 24), short and 120 or 190)
	self.countdownText.TextSize = short and 100 or 158
	local scoreBottom = self.flightPanel.Position.Y.Offset + self.flightPanel.Size.Y.Offset
	local badgeWidth = math.min(700, viewport.X - 28)
	local badgeHeight = short and 38 or 46
	self.powerFlightBadge.Size = UDim2.fromOffset(badgeWidth, badgeHeight)
	self.powerFlightBadge.Position = UDim2.new(0.5, 0, 0, scoreBottom + 8)
	place(self.powerFlightText, 6, 2, badgeWidth / 2 - 12, badgeHeight - 4)
	place(self.opponentPowerText, badgeWidth / 2 + 6, 2, badgeWidth / 2 - 12, badgeHeight - 4)
	place(self.powerFlightDivider, badgeWidth / 2, 6, 1, badgeHeight - 12)
	self.powerFlightText.TextSize = short and 12 or (portrait and 12 or 16)
	self.opponentPowerText.TextSize = self.powerFlightText.TextSize
	self.toast.Size = UDim2.fromOffset(eventWidth, short and 40 or 54)
	self.toast.CanvasSize = UDim2.fromOffset(0, short and 40 or 54)
	self.toast.Position = UDim2.new(0.5, 0, 0, scoreBottom + badgeHeight + 16)
	place(self.toastText, 8, 3, eventWidth - 16, short and 34 or 48)
	self.toastText.TextSize = short and 25 or (portrait and 27 or 33)
end

function Hud:_layoutPlaneChoices(viewport, height)
	local aimWidth = math.min(900, viewport.X - 24)
	local portrait = viewport.X < 560
	local actionHeight = portrait and 112 or 82
	self.aimActions.Size = UDim2.fromOffset(aimWidth, actionHeight)
	local textWidth = portrait and aimWidth - 28 or aimWidth - 282
	self.aimHint.Position, self.aimHint.Size = UDim2.fromOffset(14, 7), UDim2.fromOffset(textWidth, 23)
	self.aimHint.TextSize = portrait and 15 or 19
	self.fixedStats.Position, self.fixedStats.Size = UDim2.fromOffset(14, 33), UDim2.fromOffset(textWidth, 22)
	self.fixedStats.TextSize = portrait and 13 or 16
	self.aimStatus.Position, self.aimStatus.Size = UDim2.fromOffset(portrait and aimWidth / 2 or 14, portrait and 7 or 59), UDim2.fromOffset(portrait and aimWidth / 2 - 14 or textWidth, 14)
	self.aimStatus.TextXAlignment = portrait and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
	self.aimStatus.TextSize = 12
	self.aimStatus.Visible = not portrait
	self.aimReadyButton.Position = UDim2.fromOffset(portrait and 10 or aimWidth - 258, portrait and 61 or 12)
	self.aimReadyButton.Size = UDim2.fromOffset(portrait and aimWidth - 20 or 246, portrait and 44 or 58)
	self.aimReadyButton.TextSize = portrait and 20 or 22
	local fieldTop = self.header.Position.Y.Offset + self.header.Size.Y.Offset + 6
	self.aimPad.Position = UDim2.fromOffset(0, fieldTop)
	self.aimPad.Size = UDim2.fromOffset(viewport.X, math.max(20, height - 28 - actionHeight - 10 - fieldTop))
	self:_refreshAim()
end

function Hud:_resize()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(960, 720)
	if viewport == self.lastViewport then return end
	self.lastViewport = viewport
	local topInset, bottomInset = GuiService:GetGuiInset()
	local height = math.max(180, viewport.Y - topInset.Y - bottomInset.Y)
	self.layoutHeight = height
	local portrait = viewport.X < 600
	local short = not portrait and height < 470
	local function place(item, x, y, width, sizeY)
		item.Position, item.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(width, sizeY)
	end
	self.header.Position = UDim2.fromOffset(12, short and 6 or 10)
	self.header.Size = UDim2.new(1, -24, 0, short and 54 or 76)
	self.header.Brand.Visible, self.brandSub.Visible = not portrait, not portrait
	place(self.header.Brand, 18, short and 2 or 8, 225, 36)
	self.header.Brand.TextSize = short and 27 or 33
	place(self.brandSub, 20, short and 33 or 46, 235, 18)
	self.brandSub.TextSize = 12
	local phaseWidth = portrait and viewport.X - 108 or math.min(430, viewport.X - 350)
	self.phaseLabel.Position = UDim2.new(1, -phaseWidth - 78, 0, short and 1 or 8)
	self.phaseLabel.Size = UDim2.fromOffset(phaseWidth, short and 29 or 32)
	self.phaseLabel.TextXAlignment = portrait and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
	self.phaseLabel.Font = Enum.Font.FredokaOne
	self.phaseLabel.TextSize = portrait and 19 or (short and 20 or 23)
	self.courseLabel.Position = UDim2.new(1, -phaseWidth - 78, 0, short and 31 or 44)
	self.courseLabel.Size = UDim2.fromOffset(phaseWidth, 21)
	self.courseLabel.TextXAlignment = self.phaseLabel.TextXAlignment
	self.courseLabel.TextSize = portrait and 14 or 15
	self.timer.Position = UDim2.new(1, -70, 0, short and 1 or 8)
	self.timer.Size = UDim2.fromOffset(58, short and 48 or 57)
	self.timer.TextSize = short and 36 or 44
	self.footer.TextSize = portrait and 10 or 12
	self.footer.Size = UDim2.fromOffset(viewport.X - 24, 18)
	local top = self.header.Position.Y.Offset + self.header.Size.Y.Offset + 12
	local width = math.min(620, viewport.X - 24)
	local inner = width - 40
	local available = math.max(100, height - top - 24)
	for _, entry in ipairs(self.scaledPanels) do
		local flight = entry.panel == self.flightPanel or entry.panel == self.toast or entry.panel == self.flightControls
		entry.scale.Scale = 1
		entry.panel.ScrollBarThickness = flight and 0 or 5
		entry.panel.ScrollingEnabled = not flight
	end
	self.waitingPanel.AnchorPoint = Vector2.new(0.5, 0)
	self.waitingPanel.Position = UDim2.new(0.5, 0, 0, top + math.max(0, (available - 234) / 2))
	self.waitingPanel.Size = UDim2.fromOffset(width, math.min(234, available))
	self.waitingPanel.CanvasSize = UDim2.fromOffset(0, 234)
	place(self.waitingPanel.Title, 20, 22, inner, 70)
	self.waitingPanel.Title.TextSize = portrait and 29 or 34
	self.waitingPanel.Title.TextWrapped = true
	place(self.waitingPanel.Copy, 20, 97, inner, 67)
	self.waitingPanel.Copy.TextSize = portrait and 18 or 21
	place(self.waitingMessage, 20, 185, inner, 32)
	self.waitingMessage.TextSize, self.waitingMessage.TextWrapped = 15, true
	self.votePanel.AnchorPoint = Vector2.new(0.5, 0)
	self.votePanel.Position = UDim2.new(0.5, 0, 0, top)
	self.votePanel.Size = UDim2.fromOffset(width, math.min(454, available))
	self.votePanel.CanvasSize = UDim2.fromOffset(0, 454)
	self.votePanel.Eyebrow.Visible = not short
	place(self.votePanel.Eyebrow, 20, 15, inner, 18)
	self.votePanel.Eyebrow.TextSize = 13
	place(self.votePanel.Title, 20, 40, inner, 44)
	self.votePanel.Title.TextSize = portrait and 31 or 39
	place(self.votePanel.VoteHint, 20, 416, inner, 23)
	self.votePanel.VoteHint.TextSize = portrait and 12 or 15
	for index, name in ipairs({ "Coast", "Skyline", "Storm" }) do
		local control = self.voteButtons[name]
		place(control, 20, 100 + (index - 1) * 103, inner, 89)
		place(control.Badge, 12, 16, 54, 56)
		local title = control:FindFirstChild("Name")
		place(title, 80, 11, inner - 143, 31)
		title.TextSize = portrait and 23 or 29
		place(control.Detail, 80, 44, inner - 143, 36)
		control.Detail.TextSize, control.Detail.TextWrapped = portrait and 12 or 15, true
		place(control.Votes, inner - 53, 13, 42, 36)
		control.Votes.TextSize = 31
		place(control.VotesLabel, inner - 57, 54, 49, 18)
		control.VotesLabel.TextSize = 11
	end
	if short then
		local wide = math.min(960, viewport.X - 24)
		local cardWidth = (wide - 56) / 3
		self.votePanel.Size = UDim2.fromOffset(wide, math.min(226, available))
		self.votePanel.CanvasSize = UDim2.fromOffset(0, 226)
		place(self.votePanel.Title, 16, 6, wide - 32, 37)
		self.votePanel.Title.TextSize = 30
		for index, name in ipairs({ "Coast", "Skyline", "Storm" }) do
			local control = self.voteButtons[name]
			place(control, 16 + (index - 1) * (cardWidth + 12), 53, cardWidth, 134)
			place(control.Badge, 10, 12, 37, 37)
			local title = control:FindFirstChild("Name")
			place(title, 55, 12, cardWidth - 65, 30)
			title.TextSize = 22
			place(control.Detail, 10, 57, cardWidth - 20, 37)
			control.Detail.TextSize = 13
			place(control.Votes, cardWidth - 51, 96, 39, 30)
			place(control.VotesLabel, 12, 108, cardWidth - 70, 16)
		end
		place(self.votePanel.VoteHint, 16, 200, wide - 32, 20)
		self.votePanel.VoteHint.TextSize = 13
	end
	self:_layoutPersonal(viewport, height)
	self:_layoutPlaneChoices(viewport, height)
	self:_layoutDuel(viewport, height)
	self:_layoutPowerChoices(viewport, height)
end

-- Viewport coordinates, including Roblox's top inset. The camera and edge
-- markers share this clear area so neither drifts underneath the duel controls.
function Hud:getFlightViewport()
	self:_resize()
	local topInset, bottomInset = GuiService:GetGuiInset()
	local viewport = self.lastViewport
	local top = topInset.Y + self.powerFlightBadge.Position.Y.Offset + self.powerFlightBadge.Size.Y.Offset + 12
	local controlTop = self.flightControls.Position.Y.Offset - self.flightControls.Size.Y.Offset
	if viewport.X < 480 then controlTop = math.min(controlTop, -130) end
	local bottom = viewport.Y - bottomInset.Y + controlTop - 14
	return { left = 18, right = viewport.X - 18, top = top, bottom = math.max(top + 40, bottom) }
end

-- Offset from the bottom edge to just above the hub's plane selector, for
-- other hub controls that stack on top of it.
function Hud:getHubStackTop()
	self:_resize()
	return self.planeRow.Position.Y.Offset - self.planeRow.Size.Y.Offset - 8
end

function Hud:getAimViewport()
	self:_resize()
	local topInset = GuiService:GetGuiInset()
	local top = topInset.Y + self.aimPad.Position.Y.Offset
	return { left = 0, right = self.lastViewport.X, top = top, bottom = top + self.aimPad.Size.Y.Offset }
end

-- Animate presentation once for an authoritative award, never a refresh or purchase.
-- The final balance remains the server's value; no currency is granted here.
function Hud:_refreshReward(snapshot, yourResult, now)
	local economy = snapshot.economy
	local earned = math.max(0, tonumber(yourResult and yourResult.creditsEarned) or 0)
	local balance = math.max(0, tonumber(economy and economy.credits) or 0)
	local key = tostring(snapshot.matchId) .. ":" .. tostring(snapshot.roundId)
	local animation = self.rewardAnimation
	if economy and yourResult and earned > 0 and not self.rewardSeen[key] then
		self.rewardSeen[key] = true
		table.insert(self.rewardOrder, key)
		if #self.rewardOrder > 32 then self.rewardSeen[table.remove(self.rewardOrder, 1)] = nil end
		animation = { key = key, started = now, before = math.max(0, balance - earned), after = balance, earned = earned }
		self.rewardAnimation = animation
	end
	local progress = 1
	if animation and animation.key == key and not self.reducedMotion then
		progress = math.clamp((now - animation.started) / 0.85, 0, 1)
		progress = 1 - (1 - progress) ^ 3
	end
	local shownEarned = math.floor(earned * progress + 0.5)
	local shownBalance = balance
	if animation and animation.key == key and animation.after == balance then
		shownBalance = math.floor(animation.before + (balance - animation.before) * progress + 0.5)
	end
	self.rewardAmount.Text = earned > 0 and ("+" .. tostring(shownEarned) .. " COINS") or "FLIGHT COMPLETE"
	self.rewardAmount.TextSize = earned > 0 and (self.rewardTextSize or 35) or math.floor((self.rewardTextSize or 35) * 0.75)
	self.rewardBalance.Text = economy and (tostring(shownBalance) .. " COINS IN YOUR BANK") or "Loading your coin balance…"
	local nextItem
	if economy then
		for _, id in ipairs(CosmeticCatalog.ORDER) do
			local item = CosmeticCatalog.get(id)
			if item.price > 0 and not (economy.owned and economy.owned[id]) then nextItem = item; break end
		end
	end
	self.rewardTrack.Visible = nextItem ~= nil
	if nextItem then
		local color = nextItem.color
		self.rewardFill.BackgroundColor3 = Color3.fromRGB(color.r, color.g, color.b)
		self.rewardFill.Size = UDim2.new(math.clamp(shownBalance / nextItem.price, 0, 1), 0, 1, 0)
		self.rewardGoal.Text = "NEXT: " .. string.upper(nextItem.name)
		if balance >= nextItem.price then
			self.rewardHint.Text = "READY TO BUY · " .. nextItem.price .. " COINS IN HANGAR"
			self.rewardHint.TextColor3 = COLORS.gold
		else
			self.rewardHint.Text = tostring(balance) .. " / " .. nextItem.price .. " · " .. (nextItem.price - balance) .. " MORE COINS"
			self.rewardHint.TextColor3 = COLORS.white
		end
	elseif economy then
		self.rewardGoal.Text = "COLLECTION COMPLETE!"
		self.rewardHint.Text = "Try a different trail in the hangar."
		self.rewardHint.TextColor3 = COLORS.white
	else
		self.rewardGoal.Text = "YOUR NEXT FLIGHT EFFECT"
		self.rewardHint.Text = "Your collection will appear when loaded."
		self.rewardHint.TextColor3 = COLORS.white
	end
end

local function duelPowerState(player, role)
	local flight = player and player.flight
	if not flight then return role .. "\nREADY", COLORS.white end
	local id = flight.powerId or (player.settings and player.settings.powerId) or PowerCatalog.DEFAULT_ID
	local name = id == "Muncher" and "MUNCHER" or string.upper(id)
	if not flight.alive then return role .. " · LANDED\n" .. distance(flight.distance or flight.x), COLORS.white end
	local charges = math.max(0, flight.powerCharges or 0)
	local status
	if id == "Meteor" then
		status = flight.powerPhase == "diving" and "DIVING!" or (charges > 0 and "BLAST READY" or "POWER SPENT")
	else
		status = tostring(charges) .. (id == "Pinball" and " BOUNCES LEFT" or " BITES LEFT")
	end
	return role .. " · " .. name .. "\n" .. status, powerColor(id)
end

function Hud:update(snapshot, localUserId, watchedUserId)
	if not snapshot or not self.gui.Parent then return end
	self:_resize()
	local now = workspace:GetServerTimeNow()
	local phase = snapshot.phase or "Lobby"
	local remaining = math.max(0, math.ceil((snapshot.endsAt or now) - now))
	local localPlayer, watchedPlayer, opponent
	local readyCount, humanCount = 0, 0
	for _, player in ipairs(snapshot.players or {}) do
		if player.userId == localUserId then localPlayer = player end
		if player.userId ~= localUserId then opponent = player end
		if player.userId == watchedUserId then watchedPlayer = player end
		if not player.bot then
			humanCount += 1
			if player.ready then readyCount += 1 end
		end
	end
	watchedPlayer = watchedPlayer or localPlayer
	local changedPhase = self.phase ~= phase or self.roundId ~= snapshot.roundId or self.matchId ~= snapshot.matchId
	if changedPhase then
		if self.aimDrag then self:_finishAim(false) end
		self.phase = phase
		self.aimProjectionVisible = false
		self.aimFocusPending = phase == "Aim" and UserInputService.GamepadEnabled
		self.roundId = snapshot.roundId
		self.matchId = snapshot.matchId
		self.rematchRequested = false
		self.rematchPendingUntil = 0
		self.canRematch = false
		self.rematchButton.Text = "FLY AGAIN"
		self.rematchButton.Active = true
		self.pendingSettings = nil
		self.pendingReady = nil
		self.pendingUntil = 0
		self.readyPendingUntil = 0
		self.lastPowerEvent = nil
		self.lastCountdown = nil
		if phase == "Configure" then
			self.customizeOpen = false
			self:_layoutPowerChoices(self.lastViewport, self.layoutHeight)
		end
		for _, panel in ipairs({ self.votePanel, self.configPanel, self.resultsPanel }) do
			panel.CanvasPosition = Vector2.zero
		end
		if phase == "Voting" then
			self.voted = nil
			for _, line in pairs(self.voteStrokes) do
				line.Thickness, line.Color = 2, COLORS.line
			end
		end
		if phase == "Flight" then
			self.lobbyView = false
			self.lobbyButton.Text = "LEAVE DUEL"
		end
	end
	self.configEndsAt = snapshot.endsAt
	if self.aimDrag and not self:_canAim() then self:_finishAim(false) end
	if localPlayer then
		local authoritative = localPlayer.settings and selection(localPlayer.settings)
		if authoritative and not self.aimDrag and (changedPhase or not self.pendingSettings
			or sameSettings(authoritative, self.pendingSettings) or now > self.pendingUntil) then
			if not sameSettings(self.settings, authoritative) then
				self.settings = authoritative
			end
			self.pendingSettings = nil
		end
		if not self.aimDrag and (changedPhase or self.pendingReady == nil or localPlayer.ready == self.pendingReady or now > self.readyPendingUntil) then
			self.ready = localPlayer.ready == true
			self.pendingReady = nil
		end
	end
	if changedPhase and phase == "Configure" then
		self.displayedPower = self.settings.powerId
		self:_animatePowerChoice(true)
	end
	self.phaseLabel.Text = PHASE_NAMES[phase] or string.upper(phase)
	self.timer.Text = (snapshot.endsAt or 0) > 0 and tostring(remaining) or "--"
	self.courseLabel.Text = snapshot.courseName and string.upper(snapshot.courseName) or "DISTANCE WINS"
	local inHub = phase == "Lobby" or phase == "Queued"
	self.statsButton.Visible = inHub
	if not inHub then self.statsOverlay.Visible = false end
	self.soundButton.Visible = inHub or phase == "Flight"
	self.soundButton.AnchorPoint = inHub and Vector2.zero or Vector2.new(0, 1)
	self.soundButton.Position = inHub and self.hubSoundPosition
		or UDim2.new(0, 12, 1, self.lastViewport.X < 480 and -86 or -26)
	self.soundButton.Size = inHub and self.hubSoundSize or UDim2.fromOffset(118, 44)
	self.soundButton.TextSize = inHub and 18 or 14
	local stats = snapshot.stats or {}
	for key, value in pairs(self.statsValues) do
		value.Text = key == "bestDistance" and distance(stats[key] or 0, true) or tostring(stats[key] or 0)
	end
	self.statsRecord.Text = tostring(stats.wins or 0) .. " wins  ·  " .. tostring(stats.losses or 0) .. " losses  ·  " .. tostring(stats.draws or 0) .. " draws"
	local saveCopy = { loading = "Loading your record…", saved = "Record saved. Practice doesn't affect win streaks.",
		pending = "Saving your record…", session_only = "Session only · cloud saves start in the published game.",
		unavailable = "Cloud save unavailable · this session may not be saved." }
	self.statsSave.Text = saveCopy[snapshot.saveStatus] or "Loading your record…"
	self.header.Visible = not inHub and phase ~= "Flight"
	self.hubCard.Visible = phase == "Queued"
	self.hubAction.Visible = inHub
	self.practiceButton.Visible = phase == "Lobby"
	self.planeRow.Visible = phase == "Lobby"
	self.footer.Visible = not inHub
	self.waitingPanel.Visible = phase == "Waiting"
	self.votePanel.Visible = phase == "Voting"
	self.configPanel.Visible = phase == "Configure"
	self.configActions.Visible = self.configPanel.Visible
	self.aimActions.Visible = phase == "Aim" or phase == "Countdown"
	self.aimPad.Visible = self.aimActions.Visible
	self.flightPanel.Visible = phase == "Flight"
	self.flightControls.Visible = phase == "Flight"
	self.resultsPanel.Visible = phase == "Results"
	self.resultActions.Visible = phase == "Results"
	self.toast.Visible = false
	self.powerFlightBadge.Visible = phase == "Flight"
	self.powerBurst.Visible = (phase == "Configure" or phase == "Aim") and now < (self.powerBurstUntil or 0)
	if phase == "Countdown" then
		self.countdownText.Visible = true
		self.countdownText.Text = tostring(math.max(1, remaining))
		if self.lastCountdown ~= remaining then
			self.lastCountdown = remaining
			self.countdownScale.Scale = self.reducedMotion and 1 or 0.68
			self:_tween(self.countdownScale, 0.3, { Scale = 1 })
		end
	elseif phase == "Flight" and changedPhase then
		self.launchBannerUntil = now + 0.65
		self.countdownText.Text = "FLY!"
		self.countdownText.Visible = true
		self.countdownScale.Scale = self.reducedMotion and 1 or 0.68
		self:_tween(self.countdownScale, 0.25, { Scale = 1 })
	else
		self.countdownText.Visible = phase == "Flight" and now < (self.launchBannerUntil or 0)
	end
	self.waitingMessage.Text = snapshot.message or "Getting the runway ready…"
	if phase == "Lobby" then
		local plane = PlaneCatalog.get(self.settings.planeId) or PlaneCatalog.get(PlaneCatalog.DEFAULT_ID)
		self.planeName.Text = string.upper(plane.name)
		self.planeDetail.Text = tostring(plane.speed) .. " M/S  ·  " .. tostring(plane.defaultAngle) .. "° START"
		self.paintButton.BackgroundColor3 = PAINTS[self.settings.color] or PAINTS[1]
		self.hubAction.Text = "PLAY"
		self.hubAction.BackgroundColor3 = COLORS.green
		self.hubAction.Size = UDim2.fromOffset(self.hubPlayWidth, self.hubAction.Size.Y.Offset)
	elseif phase == "Queued" then
		local queue = snapshot.queue or {}
		if queue.quick then
			local wait = math.max(0, math.ceil((queue.fallbackAt or now) - now))
			self.hubTitle.Text = "FINDING A RIVAL…"
			self.hubInstruction.Text = wait > 0 and ("Nobody around? You fly a practice ghost in " .. wait .. "s.")
				or "Starting your flight…"
		else
			local station = queue.stationName or (queue.stationId and "Pad " .. tostring(queue.stationId)) or "1v1 pad"
			self.hubTitle.Text = "WAITING FOR A RIVAL"
			self.hubInstruction.Text = station .. " · walk off the pad to leave."
		end
		self.hubAction.Text = "CANCEL"
		self.hubAction.BackgroundColor3 = COLORS.coral
		self.hubAction.Size = UDim2.fromOffset(self.hubBlockWidth, self.hubAction.Size.Y.Offset)
	elseif phase == "Voting" then
		for name, votes in pairs(self.voteCounts) do
			votes.Text = tostring((snapshot.votes or {})[name] or 0)
		end
	elseif phase == "Configure" then
		self:_refreshSettings()
		if changedPhase and UserInputService.GamepadEnabled then GuiService.SelectedObject = self.powerCards[self.settings.powerId].button end
		self.readyStatus.Text = self.ready and "Waiting for rival · tap a card to change" or "Power lasts this round. Aim your plane next."
	elseif phase == "Aim" or phase == "Countdown" then
		self:_refreshSettings()
		if phase == "Countdown" then
			self.aimStatus.Text = "Takeoff in " .. remaining .. "…"
		else
			local readyText = tostring(readyCount) .. "/" .. tostring(humanCount) .. " ready"
			self.aimStatus.Text = self.ready and (readyText .. " · Waiting for rival") or PowerCatalog.get(self.settings.powerId).aimHint
		end
	elseif phase == "Flight" then
		local flight = watchedPlayer and watchedPlayer.flight
		local ownFlight = localPlayer and localPlayer.flight
		local rivalFlight = opponent and opponent.flight
		local ownDistance = ownFlight and (ownFlight.distance or ownFlight.x) or 0
		local rivalDistance = rivalFlight and (rivalFlight.distance or rivalFlight.x) or 0
		local gap = ownDistance - rivalDistance
		self.powerFlightText.Text, self.powerFlightText.TextColor3 = duelPowerState(localPlayer, "YOU")
		self.opponentPowerText.Text, self.opponentPowerText.TextColor3 = duelPowerState(opponent, opponent and opponent.bot and "GHOST" or "RIVAL")
		self.ownPilot.Text = "YOU" .. (localPlayer and " · " .. string.upper(localPlayer.name) or "")
		self.opponentPilot.Text = opponent and string.upper(opponent.name) or "OPPONENT"
		self.flightDistance.Text = distance(ownDistance)
		self.opponentDistance.Text = distance(rivalDistance)
		if math.abs(gap) < 0.5 then self.leadLabel.Text = "NECK AND NECK"
		elseif gap > 0 then self.leadLabel.Text = "LEAD +" .. distance(gap)
		else self.leadLabel.Text = "TRAIL " .. distance(-gap) end
		self.leadLabel.TextColor3 = gap < -0.5 and COLORS.coral or COLORS.green
		local altitude = flight and math.max(0, flight.y or 0) or 0
		local watchRole = watchedPlayer and (watchedPlayer.userId == localUserId and "YOU" or (watchedPlayer.bot and "GHOST" or "RIVAL")) or "TAKEOFF"
		self.watchedLabel.Text = "CAMERA: " .. watchRole .. (flight and flight.alive and (" · GROUND " .. distance(altitude)) or " · LANDED")
		self.watchedLabel.TextTruncate = Enum.TextTruncate.AtEnd
		self.watchedLabel.TextColor3 = flight and flight.alive and altitude < 28 and COLORS.coral or COLORS.muted
		local elapsed = snapshot.elapsed or 0
		local pressure = Simulation.flightPressure(elapsed)
		self.flightStatus.Text = elapsed < Simulation.PRESSURE_START
			and ("HEADWIND IN " .. tostring(math.ceil(Simulation.PRESSURE_START - elapsed)) .. "s")
			or (pressure >= 1 and "STRONG HEADWIND" or "HEADWIND ↑")
		self.flightStatus.TextColor3 = elapsed >= Simulation.PRESSURE_START and COLORS.amber or COLORS.muted
		self.flightStatus:SetAttribute("HeadwindPressure", pressure)
		self.flightStats.Text = "Waiting for takeoff"
		self.flightStats.TextColor3 = COLORS.muted
		if flight then
			local powerId = PowerCatalog.get(flight.powerId) and flight.powerId
				or (watchedPlayer.settings and watchedPlayer.settings.powerId) or PowerCatalog.DEFAULT_ID
			local power = PowerCatalog.get(powerId) or PowerCatalog.get(PowerCatalog.DEFAULT_ID)
			powerId = power.id
			self.flightStats.Text = "FUEL " .. tostring(flight.pickups or 0)
				.. "  /  HITS " .. tostring(flight.hits or 0)
				.. ((flight.shield == true or (type(flight.shield) == "number" and flight.shield > 0)) and "  /  SHIELD" or "")
			local event = flight.lastEvent
			local eventAge = event and ((snapshot.elapsed or flight.elapsed or 0) - (event.at or 0)) or math.huge
			if event and event.text and eventAge >= 0 and eventAge < 2.3 then
				self.flightStats.Text = event.text
				self.flightStats.TextColor3 = (event.kind == "hit" or event.kind == "missile") and COLORS.coral or COLORS.ink
			end
			if not flight.alive and eventAge >= 2.3 then
				self.flightStats.Text = "Final distance: " .. distance(flight.distance, true)
			end
			local powerEvent
			for _, entry in ipairs(flight.recentEvents or { flight.lastEvent }) do
				local age = (snapshot.elapsed or flight.elapsed or 0) - (entry.at or 0)
				if (entry.kind == "pinball" or entry.kind == "munch" or entry.kind == "meteorDive" or entry.kind == "meteorBoost")
					and age >= 0 and age < 1.35 then powerEvent = entry end
			end
			if powerEvent then
				self.toast.Visible = true
				self.toast.BackgroundColor3 = powerColor(powerId)
				self.toastText.Text = powerEvent.text or "POWER!"
				local key = tostring(watchedUserId) .. ":" .. powerEvent.kind .. ":" .. tostring(powerEvent.at)
				if self.lastPowerEvent ~= key then
					self.lastPowerEvent = key
					self.toastScale.Scale = self.reducedMotion and 1 or 0.76
					self:_tween(self.toastScale, 0.24, { Scale = 1 })
				end
			end
		end
	elseif phase == "Results" then
		local yourResult
		local hasForfeit = false
		for _, result in ipairs(snapshot.results or {}) do
			if result.userId == localUserId then yourResult = result end
			if result.forfeit then hasForfeit = true end
		end
		for index, row in ipairs(self.resultRows) do
			local result = (snapshot.results or {})[index]
			row.frame.Visible = result ~= nil and index <= 2
			if result then
				row.rank.Text = tostring(result.rank or index)
				row.name.Text = result.name .. (result.userId == localUserId and "  (YOU)" or "")
				row.distance.Text = distance(result.distance, true)
				row.frame.BackgroundColor3 = result.userId == localUserId and COLORS.cyan or (index == 1 and COLORS.gold or COLORS.soft)
			end
		end
		self.yourDistance.Text = yourResult and distance(yourResult.distance, true) or "—"
		self.bestDistance.Text = distance(stats.bestDistance or (localPlayer and localPlayer.best) or 0, true)
		self.resultsPanel.PersonalResult.BestLabel.Text = snapshot.saveStatus == "session_only" and "BEST THIS SESSION" or "PERSONAL BEST"
		self.resultMessage.Text = snapshot.message or "Change your setup. Chase a little farther."
		local firstPlaces = 0
		for _, result in ipairs(snapshot.results or {}) do
			if result.rank == 1 then firstPlaces += 1 end
		end
		self.resultsPanel.Title.Text = firstPlaces > 1 and "DEAD HEAT!"
			or (yourResult and yourResult.rank == 1
			and (hasForfeit and "YOU WIN THE DUEL." or "YOU WENT FURTHEST.") or "ONE MORE FLIGHT?")
        self.nextRoundLabel.Text = (snapshot.endsAt or 0) > 0 and ("Back to the hangar in " .. remaining .. "s") or "Request a rematch or head back to the club."
		self:_refreshReward(snapshot, yourResult, now)
		self.canRematch = snapshot.canRematch == true
		self.rematchRequested = localPlayer ~= nil and localPlayer.rematchReady == true
		if not self.canRematch then
			self.rematchPendingUntil = 0
			self.rematchButton.Text = "OPPONENT LEFT"
			self.nextRoundLabel.Text = "Your opponent left. Return to the club to find another duel."
		elseif self.rematchRequested then
			self.rematchPendingUntil = 0
			self.rematchButton.Text = "WAITING FOR RIVAL"
		elseif now < self.rematchPendingUntil then
			self.rematchButton.Text = "REQUESTING…"
		else
			self.rematchButton.Text = opponent and opponent.rematchReady and not opponent.bot and "ACCEPT REMATCH" or "FLY AGAIN"
		end
		local rematchEnabled = self.canRematch and not self.rematchRequested and now >= self.rematchPendingUntil
		self.rematchButton.Active = rematchEnabled
		self.rematchButton.Selectable = rematchEnabled
		self.rematchButton.AutoButtonColor = rematchEnabled
		self.rematchButton.BackgroundColor3 = self.canRematch and (self.rematchRequested and COLORS.cyan or COLORS.green) or COLORS.soft
		self.rematchButton.TextColor3 = self.canRematch and COLORS.white or COLORS.muted
	end
end

-- Show the actual server event sequence beside the watched plane. Several quick
-- collisions can happen between snapshots; the bounded event history retains them.
function Hud:updateFlightFeedback(flight, point, visible, elapsed)
	local events = {}
	if self.phase == "Flight" and flight and visible then
		for _, entry in ipairs(flight.recentEvents or {flight.lastEvent}) do
			local age = elapsed - (entry.at or 0)
			if age >= 0 and age < 1.8 and entry.kind ~= "launch" and entry.kind ~= "finish" then
				table.insert(events, entry)
			end
		end
	end
	local short = self.lastViewport.Y < 450
	local lineHeight = short and 19 or 25
	local stripBottom = self.flightPanel.Position.Y.Offset + self.flightPanel.Size.Y.Offset
	local roomAbove = math.floor((point.Y - 24 - stripBottom - 8) / lineHeight)
	local count = math.min(3, #events, math.max(1, roomAbove))
	for index, control in ipairs(self.flightFeedback) do
		local entry = index <= count and events[#events - index + 1] or nil
		control.Visible = entry ~= nil
		if entry then
			local age = elapsed - entry.at
			local color, text = COLORS.green, entry.text
			if entry.kind == "fuel" then text = "+" .. tostring(entry.value or "") .. " LIFT"
			elseif entry.kind == "missile" then color, text = COLORS.coral, "MISSILE HIT!"
			elseif entry.kind == "shield" then color, text = COLORS.gold, "SHIELD SAVE!"
			elseif entry.kind == "nearMiss" then color, text = COLORS.cyan, "CLOSE CALL!"
			elseif entry.kind == "boost" then text = "RESCUE BOOST!"
			elseif entry.kind == "pinball" then color = powerColor("Pinball")
			elseif entry.kind == "munch" then color = powerColor("Muncher")
			elseif entry.kind == "meteorDive" or entry.kind == "meteorBoost" then color = powerColor("Meteor") end
			control.Text, control.TextColor3 = text, color
			control.TextSize = short and 15 or 20
			control.Size = UDim2.fromOffset(190, lineHeight)
			local fade = math.clamp((age - 1.25) / 0.55, 0, 1)
			control.TextTransparency, control.LetterOutline.Transparency = fade, fade
			local x = math.clamp(point.X, 95, math.max(95, self.lastViewport.X - 95))
			-- Keep the stack out of the score strip, including phone safe insets.
			local bottom = math.max(stripBottom + count * lineHeight + 8, point.Y - 24 - age * 8)
			if roomAbove < 1 then
				-- Beside the aircraft when there is no room above it, never on it.
				x = point.X + 115
				if x > self.lastViewport.X - 95 then x = point.X - 115 end
				x = math.clamp(x, 95, math.max(95, self.lastViewport.X - 95))
				bottom = math.max(stripBottom + lineHeight + 8, point.Y + lineHeight / 2)
			end
			control.Position = UDim2.fromOffset(x, bottom - (index - 1) * lineHeight)
		end
	end
end

function Hud:destroy()
	self.aimDrag = nil
	for _, tween in pairs(self.tweens) do tween:Cancel() end
	table.clear(self.tweens)
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	table.clear(self.connections)
	if self.gui then self.gui:Destroy() end
end

return Hud
