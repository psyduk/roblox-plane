-- SKYBOUND's client-only presentation. Match state and rewards stay on the server.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlaneCatalog = require(ReplicatedStorage:WaitForChild("FlightGame"):WaitForChild("PlaneCatalog"))

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
}
local DISPLAY_TEXT = {
	Brand = true, Title = true, Timer = true, Name = true, Votes = true,
	Distance = true, OpponentDistance = true, YourDistance = true, BestDistance = true,
	Lead = true, Rank = true,
}
local PAINTS = {
	Color3.fromRGB(255, 104, 102),
	Color3.fromRGB(66, 225, 239),
	Color3.fromRGB(255, 212, 80),
	Color3.fromRGB(184, 138, 255),
}
local PAINT_NAMES = { "Coral", "Cyan", "Gold", "Lilac" }
local GADGETS = { "Shield", "Magnet", "Boost" }
local GADGET_COPY = {
	Shield = "SHIELD  /  Absorbs one missile hit. A little room for error.",
	Magnet = "MAGNET  /  Collect fuel from farther away. Chase the pickups.",
	Boost = "BOOST  /  One automatic rescue burst when you drop low.",
}
local GADGET_SHORT_COPY = {
	Shield = "SHIELD · Blocks one missile hit.",
	Magnet = "MAGNET · Collects fuel from farther away.",
	Boost = "BOOST · One automatic low-altitude rescue.",
}
local PHASE_NAMES = {
	Lobby = "FLIGHT CLUB",
	Queued = "FINDING YOUR RIVAL",
	Waiting = "GETTING READY",
	Voting = "CHOOSE A COURSE",
	Configure = "CHOOSE YOUR JET",
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
		TextSize = 16,
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
		and a.gadget == b.gadget and a.color == b.color
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
		gadget = GADGET_COPY[settings.gadget] and settings.gadget or "Shield",
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
	self.aimHandle.Visible, self.aimLine.Visible = interactive, interactive
	local size = self.aimPad.AbsoluteSize
	local short = self.lastViewport.Y < 400
	local origin = visible and self.aimScreenOrigin - self.aimPad.AbsolutePosition or Vector2.zero
	local function pointAt(angle, radius)
		local radians = math.rad(angle)
		return origin + Vector2.new(math.cos(radians), -math.sin(radians)) * radius
	end
	local function inside(point, margin)
		return point.X >= margin and point.Y >= margin and point.X <= size.X - margin and point.Y <= size.Y - margin
	end
	local function segment(control, first, last, thickness)
		local delta = last - first
		control.Position = UDim2.fromOffset((first.X + last.X) / 2, (first.Y + last.Y) / 2)
		control.Size = UDim2.fromOffset(delta.Magnitude, thickness)
		control.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	end
	if visible then
		local reticleRadius = short and 48 or 64
		local handle = pointAt(self.settings.angle, reticleRadius)
		self.aimHandleScreen = handle + self.aimPad.AbsolutePosition
		self.aimHandle.Position = UDim2.fromOffset(handle.X, handle.Y)
		self.aimReticleRing.BackgroundColor3 = self.aimDrag and COLORS.gold or COLORS.cyan
		self.aimReticleRing.BackgroundTransparency = self.aimDrag and 0.1 or 0.35
		self.aimHandle.Visible = interactive and inside(handle, 15)
		segment(self.aimLine, pointAt(self.settings.angle, 22), pointAt(self.settings.angle, reticleRadius - 15), 3)
	end
	-- The labeled arc is a compact compass for the allowed launch range.
	local arcRadius = math.min(short and 56 or 80, math.max(28, (origin.Y - 16) / math.sin(math.rad(60)) - 18))
	for index, arc in ipairs(self.aimArc) do
		local first = pointAt(15 + (index - 1) * 45 / #self.aimArc, arcRadius)
		local last = pointAt(15 + index * 45 / #self.aimArc, arcRadius)
		arc.Visible = interactive and inside(first, 2) and inside(last, 2)
		if arc.Visible then segment(arc, first, last, 2) end
	end
	for _, tick in ipairs(self.aimTicks) do
		local inner, outer = pointAt(tick.angle, arcRadius - 4), pointAt(tick.angle, arcRadius + 5)
		local textPoint = pointAt(tick.angle, arcRadius + 24)
		tick.line.Visible = interactive and inside(inner, 3) and inside(outer, 3)
		tick.label.Visible = interactive and inside(textPoint, 9)
		if tick.line.Visible then segment(tick.line, inner, outer, 3) end
		tick.label.Position = UDim2.fromOffset(textPoint.X, textPoint.Y)
		tick.label.TextSize = short and 9 or 11
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
	self.fixedStats.Text = "ANGLE " .. statNumber(setting.angle) .. "°   /   SPEED " .. statNumber(plane.speed) .. " m/s"
	self.planeSpeed.Text = plane.name .. "  ·  " .. statNumber(plane.speed) .. " m/s"
	self.planeStrategy.Text = plane.description
	for id, control in pairs(self.planeButtons) do
		local chosen = setting.planeId == id
		control.Text = (chosen and "✓ " or "") .. PlaneCatalog.get(id).name
		control.BackgroundColor3 = chosen and COLORS.green or COLORS.blue
		self.planeStrokes[id].Thickness = chosen and 3 or 2
	end
	self.gadgetCopy.Text = GADGET_COPY[setting.gadget]
	self.gadgetSummary.Text = GADGET_SHORT_COPY[setting.gadget]
	for name, control in pairs(self.gadgetButtons) do
		local selected = setting.gadget == name
		control.BackgroundColor3 = selected and COLORS.cyan or COLORS.soft
		control.Text = (selected and "• " or "") .. name
	end
	for index, control in ipairs(self.colorButtons) do
		control.Text = setting.color == index and "✓" or ""
		self.colorStrokes[index].Thickness = setting.color == index and 4 or 2
	end
	self.paintName.Text = PAINT_NAMES[setting.color] .. " / cosmetic only"
	local locked = not self:_canConfigure()
	self.readyButton.Text = self.ready and "WAITING FOR RIVAL…" or "NEXT: AIM JET"
	self.readyButton.BackgroundColor3 = self.ready and COLORS.cyan or COLORS.green
	self.readyButton.Active = not locked
	self.readyButton.Selectable = not locked
	for _, control in ipairs(self.configControls) do
		control.Active = not locked
		control.Selectable = not locked
		control.AutoButtonColor = not locked
	end
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
		if GADGET_COPY[settings.gadget] then nextSettings.gadget = settings.gadget end
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
	self.pendingReady = self.ready
	self.readyPendingUntil = workspace:GetServerTimeNow() + 0.75
	self:_refreshSettings()
	self:_call("ready", self.ready)
end

function Hud.new(callbacks)
	local self = setmetatable({}, Hud)
	self.callbacks = callbacks or {}
	self.connections = {}
	self.scaledPanels = {}
	self.configControls = {}
	self.settings = selection({ planeId = PlaneCatalog.DEFAULT_ID, gadget = "Shield", color = 1 })
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
	self.footer = label(self.gui, "Prototype", "LOCAL PROTOTYPE · cosmetic colors are free", 0, 0, 500, 16, 10, COLORS.white, true)
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
	self.hubInstruction = label(self.hubCard, "Instruction", "Walk onto a 1v1 pad with an opponent.", 14, 34, 292, 31, 12, COLORS.white)
	self.hubInstruction.TextWrapped = true
	self.hubAction = button(self.gui, "HubAction", "PRACTICE VS GHOST", 0, 0, 198, 48, COLORS.cyan)
	self.hubAction.AnchorPoint = Vector2.new(1, 1)
	self.hubAction.Position = UDim2.new(1, -16, 1, -28)
	self.hubAction.TextSize = 14
	self:_connect(self.hubAction.Activated, function()
		if self.phase == "Queued" then self:_call("leaveQueue")
		elseif self.phase == "Lobby" then self:_call("practice") end
	end)

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

	self.configPanel = self:_panel("Configure", 509)
	label(self.configPanel, "Eyebrow", "THREE FREE PLANES. THREE WAYS TO FLY.", 24, 19, 422, 17, 10, COLORS.muted, true)
	label(self.configPanel, "Title", "PICK A FREE PLANE", 24, 40, 422, 33, 27, COLORS.ink, true)
	frame(self.configPanel, "Divider", 24, 87, 422, 1, COLORS.line)
	self.planeButtons, self.planeStrokes = {}, {}
	for index, id in ipairs(PlaneCatalog.ORDER) do
		local control = button(self.configPanel, "Plane_" .. id, PlaneCatalog.get(id).name, 24 + (index - 1) * 145, 102, 132, 52, COLORS.blue)
		self.planeButtons[id] = control
		self.planeStrokes[id] = stroke(control, COLORS.ink, 2)
		table.insert(self.configControls, control)
		self:_connect(control.Activated, function() self:setLocalSettings({ planeId = id }) end)
	end
	self.planeSpeed = label(self.configPanel, "PlaneSpeed", "", 24, 165, 422, 24, 14, COLORS.ink, true)
	self.planeStrategy = label(self.configPanel, "PlaneStrategy", "", 24, 194, 422, 20, 12, COLORS.muted)
	self.planeStrategy.TextTruncate = Enum.TextTruncate.AtEnd
	self.aimPad = create("TextButton", {
		Name = "AimPad", Text = "", Position = UDim2.fromOffset(0, 81), Size = UDim2.new(1, 0, 1, -183),
		BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Selectable = false,
		Active = false, Visible = false, ClipsDescendants = false,
	}, self.gui)
	self.aimLine = frame(self.aimPad, "AimDirection", 0, 0, 30, 3, COLORS.cyan)
	self.aimLine.AnchorPoint = Vector2.new(0.5, 0.5)
	stroke(self.aimLine, COLORS.ink, 1)
	self.aimArc, self.aimTicks = {}, {}
	for index = 1, 12 do
		local arc = frame(self.aimPad, "AimArc" .. index, 0, 0, 1, 2, COLORS.cyan)
		arc.AnchorPoint = Vector2.new(0.5, 0.5)
		arc.BackgroundTransparency = 0.15
		stroke(arc, COLORS.ink, 0.75)
		table.insert(self.aimArc, arc)
	end
	for _, angle in ipairs({ 15, 30, 45, 60 }) do
		local tick = frame(self.aimPad, "AngleTick" .. angle, 0, 0, 8, 3, COLORS.white)
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		stroke(tick, COLORS.ink, 1)
		local text = label(self.aimPad, "AngleLabel" .. angle, tostring(angle) .. "°", 0, 0, 26, 12, 11, COLORS.white, true)
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.TextXAlignment = Enum.TextXAlignment.Center
		text.TextStrokeColor3, text.TextStrokeTransparency = COLORS.ink, 0
		text.ZIndex = 2
		table.insert(self.aimTicks, { angle = angle, line = tick, label = text })
	end
	self.aimDots = {}
	for index = 1, 26 do
		local dot = frame(self.aimPad, "Trajectory" .. index, 0, 0, 16, 16, index % 5 == 0 and COLORS.gold or COLORS.white)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		corner(dot, 10)
		stroke(dot, COLORS.ink, 2)
		table.insert(self.aimDots, dot)
	end
	-- A 44px target surrounds the smaller reticle; the whole forward field also aims.
	self.aimHandle = frame(self.aimPad, "AimReticle", 0, 0, 44, 44, COLORS.cyan)
	self.aimHandle.AnchorPoint = Vector2.new(0.5, 0.5)
	self.aimHandle.ZIndex = 3
	self.aimHandle.BackgroundTransparency = 1
	self.aimReticleRing = frame(self.aimHandle, "Ring", 8, 8, 28, 28, COLORS.cyan)
	corner(self.aimReticleRing, 20)
	stroke(self.aimReticleRing, COLORS.ink, 2)
	local center = frame(self.aimHandle, "Center", 19, 19, 6, 6, COLORS.white)
	corner(center, 6)
	stroke(center, COLORS.ink, 1)
	for index, geometry in ipairs({ { 20.5, 4, 3, 9 }, { 20.5, 31, 3, 9 }, { 4, 20.5, 9, 3 }, { 31, 20.5, 9, 3 } }) do
		local mark = frame(self.aimHandle, "Crosshair" .. index, geometry[1], geometry[2], geometry[3], geometry[4], COLORS.white)
		stroke(mark, COLORS.ink, 1)
	end
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
	label(self.configPanel, "GadgetTitle", "PICK ONE FREE GADGET", 24, 229, 422, 20, 13, COLORS.ink, true)
	self.gadgetButtons = {}
	for index, name in ipairs(GADGETS) do
		local control = button(self.configPanel, name, name, 24 + (index - 1) * 145, 258, 132, 43)
		self.gadgetButtons[name] = control
		table.insert(self.configControls, control)
		self:_connect(control.Activated, function() self:setLocalSettings({ gadget = name }) end)
	end
	self.gadgetCopy = label(self.configPanel, "GadgetDetail", "", 24, 310, 422, 36, 12, COLORS.muted)
	self.gadgetCopy.TextWrapped = true
	label(self.configPanel, "PaintTitle", "YOUR COLORS", 24, 355, 190, 23, 13, COLORS.ink, true)
	self.paintName = label(self.configPanel, "PaintName", "", 24, 379, 224, 18, 11, COLORS.muted)
	self.colorButtons, self.colorStrokes = {}, {}
	for index, paint in ipairs(PAINTS) do
		local control = button(self.configPanel, "Paint" .. index, "", 248 + (index - 1) * 51, 354, 44, 44, paint)
		control.TextSize = 23
		self.colorButtons[index] = control
		self.colorStrokes[index] = stroke(control, COLORS.ink, 2)
		table.insert(self.configControls, control)
		self:_connect(control.Activated, function() self:setLocalSettings({ color = index }) end)
	end
	self.readyButton = button(self.configPanel, "Ready", "READY TO FLY", 24, 418, 422, 55, COLORS.green)
	self.readyButton.TextSize = 21
	self:_connect(self.readyButton.Activated, function() self:toggleReady() end)
	self.readyStatus = label(self.configPanel, "ReadyStatus", "", 24, 481, 422, 16, 11, COLORS.muted)
	self.readyStatus.TextXAlignment = Enum.TextXAlignment.Center
	-- Keep the primary action reachable while the choices scroll on short screens.
	self.configActions = frame(self.gui, "ConfigureActions", 0, 0, 470, 90)
	self.configActions.AnchorPoint = Vector2.new(0.5, 0)
	self.configActions.Visible = false
	corner(self.configActions, 16)
	stroke(self.configActions, COLORS.ink, 3)
	self.readyButton.Parent = self.configActions
	self.readyStatus.Parent = self.configActions
	self.gadgetSummary = label(self.configActions, "GadgetSummary", "", 16, 7, 420, 21, 12, COLORS.ink, true)
	self.gadgetSummary.Visible = false
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
	self.resultActions = frame(self.gui, "ResultActions", 0, 0, 470, 64)
	self.resultActions.AnchorPoint = Vector2.new(0.5, 0)
	self.resultActions.Visible = false
	corner(self.resultActions, 14)
	stroke(self.resultActions, COLORS.ink, 3)
	self.rematchButton = button(self.resultActions, "Rematch", "REMATCH", 8, 8, 219, 48, COLORS.green)
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
	local width = math.min(470, viewport.X - 24)
	local cardHeight = math.min(338, height - 16)
	self.statsCard.Size = UDim2.fromOffset(width, cardHeight)
	self.statsCard.Title.TextSize = width < 400 and 18 or 24
	self.statsCard.Title.Size = UDim2.fromOffset(width - 80, 30)
	self.statsClose.Position = UDim2.fromOffset(width - 52, 8)
	local cellWidth = (width - 44) / 2
	local cellHeight = (cardHeight - 126) / 3
	for index, cell in ipairs(self.statsCells) do
		cell.Position = UDim2.fromOffset(16 + ((index - 1) % 2) * (cellWidth + 12), 59 + math.floor((index - 1) / 2) * (cellHeight + 7))
		cell.Size = UDim2.fromOffset(cellWidth, cellHeight)
		cell.Caption.Size = UDim2.fromOffset(cellWidth - 24, 15)
		cell.Distance.Position = UDim2.fromOffset(12, 21)
		cell.Distance.Size = UDim2.fromOffset(cellWidth - 24, math.max(20, cellHeight - 23))
		cell.Distance.TextSize = cardHeight < 310 and 20 or 24
	end
	self.statsRecord.Position = UDim2.fromOffset(18, cardHeight - 48)
	self.statsRecord.Size = UDim2.fromOffset(width - 36, 18)
	self.statsSave.Position = UDim2.fromOffset(18, cardHeight - 28)
	self.statsSave.Size = UDim2.fromOffset(width - 36, 22)
end

function Hud:_layoutDuel(viewport, height)
	local function place(item, x, y, width, sizeY)
		item.Position = UDim2.fromOffset(x, y)
		item.Size = UDim2.fromOffset(width, sizeY)
	end
	local hubWidth = math.min(320, viewport.X - 32)
	self.hubCard.Size = UDim2.fromOffset(hubWidth, 76)
	self.hubTitle.Size = UDim2.fromOffset(hubWidth - 28, 22)
	self.hubInstruction.Size = UDim2.fromOffset(hubWidth - 28, 31)
	self.hubAction.AnchorPoint = Vector2.new(1, 0)
	self.hubAction.Position = UDim2.new(1, -16, 0, viewport.X >= 560 and 10 or 94)
	-- The flight bar replaces the normal header; the course keeps the center.
	local flightWidth = math.min(690, viewport.X - 24)
	local column = (flightWidth - 32) / 3
	self.flightPanel.Position = UDim2.new(0.5, 0, 0, 6)
	self.flightPanel.Size = UDim2.fromOffset(flightWidth, 64)
	self.flightPanel.CanvasSize = UDim2.fromOffset(0, 64)
	self.flightPanel.Rule.Visible = false
	place(self.ownPilot, 14, 3, column, 15)
	place(self.flightDistance, 14, 19, column, 29)
	self.flightDistance.TextSize = 26
	place(self.opponentPilot, flightWidth - column - 14, 3, column, 15)
	place(self.opponentDistance, flightWidth - column - 14, 19, column, 29)
	self.opponentDistance.TextSize = 26
	place(self.leadLabel, 16 + column, 6, column, 23)
	self.leadLabel.TextSize = flightWidth < 430 and 12 or 18
	place(self.flightStatus, 16 + column, 29, column, 17)
	self.flightStatus.TextXAlignment = Enum.TextXAlignment.Center
	self.flightStatus.TextSize = flightWidth < 430 and 10 or 12
	place(self.watchedLabel, 14, 47, flightWidth / 2 - 18, 15)
	self.watchedLabel.TextSize = 10
	place(self.flightStats, flightWidth / 2, 47, flightWidth / 2 - 14, 15)
	self.flightStats.TextSize = 10
	self.flightStats.TextXAlignment = Enum.TextXAlignment.Right
	self.flightStats.TextTruncate = Enum.TextTruncate.AtEnd
	self.flightControls.AnchorPoint = Vector2.new(1, 1)
	self.flightControls.Position = UDim2.new(1, -12, 1, -26)
	self.flightControls.Size = UDim2.fromOffset(326, 52)
	self.flightControls.CanvasSize = UDim2.fromOffset(0, 52)
	place(self.flightControls.PreviousPilot, 4, 4, 44, 44)
	place(self.spectateLabel, 52, 4, 58, 44)
	self.spectateLabel.Visible = true
	self.spectateLabel.Text = "CAMERA"
	self.spectateLabel.TextSize = 10
	place(self.flightControls.NextPilot, 114, 4, 44, 44)
	place(self.lobbyButton, 166, 4, 156, 44)
	self.lobbyButton.TextSize = 13
	if viewport.X > viewport.Y and viewport.Y < 400 then
		self.flightPanel.Size = UDim2.fromOffset(flightWidth, 52)
		self.flightPanel.CanvasSize = UDim2.fromOffset(0, 52)
		place(self.ownPilot, 14, 2, column, 13)
		place(self.opponentPilot, flightWidth - column - 14, 2, column, 13)
		self.ownPilot.TextSize, self.opponentPilot.TextSize = 10, 10
		place(self.flightDistance, 14, 15, column, 23)
		place(self.opponentDistance, flightWidth - column - 14, 15, column, 23)
		self.flightDistance.TextSize, self.opponentDistance.TextSize = 22, 22
		place(self.leadLabel, 16 + column, 4, column, 20)
		self.leadLabel.TextSize = flightWidth < 430 and 12 or 16
		place(self.flightStatus, 16 + column, 24, column, 14)
		self.flightStatus.TextSize = 10
		place(self.watchedLabel, 14, 38, flightWidth / 2 - 18, 13)
		place(self.flightStats, flightWidth / 2, 38, flightWidth / 2 - 14, 13)
		self.flightControls.Size = UDim2.fromOffset(230, 44)
		self.flightControls.CanvasSize = UDim2.fromOffset(0, 44)
		place(self.flightControls.PreviousPilot, 4, 0, 44, 44)
		place(self.flightControls.NextPilot, 52, 0, 44, 44)
		place(self.lobbyButton, 100, 0, 126, 44)
		self.lobbyButton.TextSize = 12
		self.spectateLabel.Visible = false
	else
		self.ownPilot.TextSize, self.opponentPilot.TextSize = 11, 11
	end
	local width = math.min(470, viewport.X - 24)
	local inner = width - 48
	local landscape = viewport.X >= 680 and height < 470
	local personal = self.resultsPanel.PersonalResult
	self.resultsPanel.Eyebrow.Visible = not landscape
	self.nextRoundLabel.Visible = not landscape
	self.resultsPanel.AnchorPoint = Vector2.new(0.5, 0)
	if landscape then
		width = math.min(760, viewport.X - 32)
		local half = width / 2
		local rowWidth = half - 24
		local top = height < 330 and 54 or 65
		self.resultsPanel.Position = UDim2.new(0.5, 0, 0, top)
		self.resultsPanel.Size = UDim2.fromOffset(width, 134)
		self.resultsPanel.CanvasSize = UDim2.fromOffset(0, 134)
		place(self.resultsPanel.Title, 16, 3, width - 32, 27)
		self.resultsPanel.Title.TextSize = 21
		place(self.resultMessage, 16, 31, width - 32, 18)
		for index, row in ipairs(self.resultRows) do
			place(row.frame, 16, 54 + (index - 1) * 42, rowWidth, 34)
			place(row.rank, 10, 0, 26, 34)
			place(row.name, 41, 0, rowWidth - 145, 34)
			place(row.distance, rowWidth - 99, 0, 90, 34)
			row.name.TextSize = 12
			row.distance.TextSize = 15
		end
		place(personal, half + 8, 55, rowWidth, 75)
		local recordHalf = rowWidth / 2
		place(personal.YourLabel, 12, 10, recordHalf - 12, 16)
		place(personal.BestLabel, recordHalf + 4, 10, recordHalf - 12, 16)
		place(self.yourDistance, 12, 32, recordHalf - 12, 28)
		place(self.bestDistance, recordHalf + 4, 32, recordHalf - 12, 28)
		self.yourDistance.TextSize, self.bestDistance.TextSize = 21, 21
		self.resultActions.Position = UDim2.new(0.5, 0, 0, top + 140)
	else
		local available = math.max(110, height - 185)
		local visible = math.min(328, available)
		self.resultsPanel.Position = UDim2.new(0.5, 0, 0, 87)
		self.resultsPanel.Size = UDim2.fromOffset(width, visible)
		self.resultsPanel.CanvasSize = UDim2.fromOffset(0, 328)
		place(self.resultsPanel.Title, 24, 43, inner, 34)
		place(self.resultMessage, 24, 80, inner, 20)
		for index, row in ipairs(self.resultRows) do
			place(row.frame, 24, 112 + (index - 1) * 44, inner, 37)
			place(row.rank, 12, 0, 30, 37)
			place(row.name, 44, 0, inner - 151, 37)
			place(row.distance, inner - 110, 0, 98, 37)
		end
		place(personal, 24, 211, inner, 75)
		place(self.nextRoundLabel, 24, 300, inner, 18)
		self.resultActions.Position = UDim2.new(0.5, 0, 0, 87 + visible + 8)
	end
	self.resultActions.Size = UDim2.fromOffset(width, 64)
	local actionWidth = (width - 24) / 2
	place(self.rematchButton, 8, 8, actionWidth, 48)
	place(self.returnButton, 16 + actionWidth, 8, actionWidth, 48)
	self.rematchButton.TextSize = width < 430 and 11 or 14
	self.returnButton.TextSize = width < 430 and 11 or 14
end

function Hud:_layoutPlaneChoices(viewport, height)
	local width = math.min(470, math.max(260, viewport.X - 24))
	local left, top, contentWidth, buttonHeight = 24, 102, width - 48, 52
	local statsY, strategyY = 165, 194
	local landscape = viewport.X >= 680 and height < 470
	self.configPanel.Title.Visible, self.planeStrategy.Visible = true, true
	if landscape then
		left, contentWidth = 16, math.min(760, viewport.X - 32) / 2 - 32
		if height < 330 then top, buttonHeight, statsY, strategyY = 28, 44, 79, 106
		else top, buttonHeight, statsY, strategyY = 43, 48, 101, 132 end
	end
	local buttonWidth = (contentWidth - 16) / 3
	for index, id in ipairs(PlaneCatalog.ORDER) do
		local control = self.planeButtons[id]
		control.Position = UDim2.fromOffset(left + (index - 1) * (buttonWidth + 8), top)
		control.Size, control.TextSize = UDim2.fromOffset(buttonWidth, buttonHeight), buttonWidth < 110 and 13 or 16
	end
	self.planeSpeed.Position, self.planeSpeed.Size = UDim2.fromOffset(left, statsY), UDim2.fromOffset(contentWidth, 23)
	self.planeSpeed.TextSize = landscape and 13 or 14
	self.planeStrategy.Position, self.planeStrategy.Size = UDim2.fromOffset(left, strategyY), UDim2.fromOffset(contentWidth, 20)
	self.planeStrategy.TextSize = landscape and 11 or 12
	local aimWidth = math.min(690, viewport.X - 24)
	local portrait = viewport.X < 560
	local actionHeight = portrait and 98 or 64
	self.aimActions.Size = UDim2.fromOffset(aimWidth, actionHeight)
	local textWidth = portrait and aimWidth - 28 or aimWidth - 282
	self.aimHint.Position, self.aimHint.Size = UDim2.fromOffset(14, 5), UDim2.fromOffset(textWidth, 17)
	self.aimHint.TextSize = portrait and 11 or 12
	self.fixedStats.Position, self.fixedStats.Size = UDim2.fromOffset(14, 25), UDim2.fromOffset(textWidth, 19)
	self.fixedStats.TextSize = portrait and 11 or 12
	self.aimStatus.Position, self.aimStatus.Size = UDim2.fromOffset(portrait and aimWidth / 2 or 14, portrait and 7 or 46), UDim2.fromOffset(portrait and aimWidth / 2 - 14 or textWidth, 14)
	self.aimStatus.TextXAlignment = portrait and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
	self.aimStatus.Visible = not portrait
	self.aimReadyButton.Position = UDim2.fromOffset(portrait and 10 or aimWidth - 258, portrait and 47 or 8)
	self.aimReadyButton.Size = UDim2.fromOffset(portrait and aimWidth - 20 or 246, 44)
	self.aimReadyButton.TextSize = portrait and 16 or 17
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
	self:_layoutPersonal(viewport, height)
	local width = math.min(470, math.max(260, viewport.X - 24))
	local inner = width - 48
	local narrowCard = width < 430
	local available = math.max(90, height - 112)
	local configHeight = narrowCard and 448 or 414
	local function place(item, x, y, w, h)
		item.Position = UDim2.fromOffset(x, y)
		item.Size = UDim2.fromOffset(w, h)
	end
	for _, entry in ipairs(self.scaledPanels) do
		local isFlight = entry.panel == self.flightPanel or entry.panel == self.toast or entry.panel == self.flightControls
		entry.scale.Scale = 1
		entry.panel.ScrollBarThickness = isFlight and 0 or 5
		entry.panel.ScrollingEnabled = not isFlight
		if not isFlight then
			local contentHeight = entry.panel == self.configPanel and configHeight or entry.height
			local maxHeight = entry.panel == self.configPanel and math.max(75, available - 98) or available
			local visibleHeight = math.min(contentHeight, maxHeight)
			local totalHeight = visibleHeight + (entry.panel == self.configPanel and 98 or 0)
			entry.panel.AnchorPoint = Vector2.new(0.5, 0)
			entry.panel.Position = UDim2.new(0.5, 0, 0, 87 + math.max(0, (available - totalHeight) / 2))
			entry.panel.Size = UDim2.fromOffset(width, visibleHeight)
			entry.panel.CanvasSize = UDim2.fromOffset(0, contentHeight)
		end
	end
	for _, panel in ipairs({ self.waitingPanel, self.votePanel, self.configPanel, self.resultsPanel }) do
		for _, child in ipairs(panel:GetChildren()) do
			if child:IsA("TextLabel") and child.Position.X.Offset == 24 then
				child.Size = UDim2.new(0, inner, 0, child.Size.Y.Offset)
			end
		end
	end
	self.waitingPanel.Title.TextSize = narrowCard and 19 or 24
	self.waitingPanel.Copy.TextSize = narrowCard and 16 or 18
	self.waitingPanel.Status.TextWrapped = true
	self.votePanel.Title.TextSize = narrowCard and 24 or 27
	self.votePanel.Eyebrow.Visible = true
	place(self.votePanel.Title, 24, 42, inner, 34)
	place(self.votePanel.VoteHint, 24, 371, inner, 20)
	self.votePanel.VoteHint.TextSize = narrowCard and 11 or 12
	for index, name in ipairs({ "Coast", "Skyline", "Storm" }) do
		local control = self.voteButtons[name]
		control.Position = UDim2.fromOffset(24, 91 + (index - 1) * 90)
		control.Size = UDim2.fromOffset(inner, 78)
		place(control.Badge, 11, 12, 49, 54)
		place(control.Badge.Number, 0, 0, 49, 54)
		control.Badge.Number.TextSize = 20
		local courseTitle = control:FindFirstChild("Name")
		place(courseTitle, 73, 13, inner - 127, 24)
		courseTitle.TextSize = narrowCard and 16 or 20
		place(control.Detail, 73, 39, inner - 123, 30)
		control.Detail.TextWrapped = true
		place(control.Votes, inner - 51, 19, 42, 26)
		place(control.VotesLabel, inner - 54, 47, 47, 14)
	end
	if viewport.X >= 560 and height < 560 then
		local wide = math.min(760, viewport.X - 32)
		local cardWidth = (wide - 56) / 3
		self.votePanel.Position = UDim2.new(0.5, 0, 0, 87)
		self.votePanel.Size = UDim2.fromOffset(wide, math.min(206, available))
		self.votePanel.CanvasSize = UDim2.fromOffset(0, 206)
		self.votePanel.CanvasPosition = Vector2.zero
		self.votePanel.Eyebrow.Visible = false
		place(self.votePanel.Title, 16, 9, wide - 32, 31)
		self.votePanel.Title.TextSize = 24
		for index, name in ipairs({ "Coast", "Skyline", "Storm" }) do
			local control = self.voteButtons[name]
			place(control, 16 + (index - 1) * (cardWidth + 12), 50, cardWidth, 119)
			place(control.Badge, 10, 10, 34, 34)
			place(control.Badge.Number, 0, 0, 34, 34)
			control.Badge.Number.TextSize = 15
			local courseTitle = control:FindFirstChild("Name")
			place(courseTitle, 54, 13, cardWidth - 64, 24)
			courseTitle.TextSize = 16
			place(control.Detail, 10, 53, cardWidth - 20, 32)
			place(control.Votes, cardWidth - 49, 86, 37, 26)
			place(control.VotesLabel, 10, 94, cardWidth - 67, 14)
		end
		place(self.votePanel.VoteHint, 16, 181, wide - 32, 18)
		self.votePanel.VoteHint.TextSize = 11
	end
	self.configPanel.Eyebrow.TextSize = narrowCard and 9 or 10
	self.configPanel.Divider.Size = UDim2.fromOffset(inner, 1)
	local gadgetWidth = (inner - 20) / 3
	for index, name in ipairs(GADGETS) do
		place(self.gadgetButtons[name], 24 + (index - 1) * (gadgetWidth + 10), 258, gadgetWidth, 48)
		self.gadgetButtons[name].TextSize = narrowCard and 14 or 16
	end
	place(self.gadgetCopy, 24, 314, inner, 41)
	place(self.configPanel.PaintTitle, 24, narrowCard and 363 or 365, narrowCard and 120 or 190, 23)
	place(self.paintName, narrowCard and (24 + inner - 146) or 24, narrowCard and 365 or 389, narrowCard and 146 or 205, 18)
	for index, control in ipairs(self.colorButtons) do
		place(control, narrowCard and (24 + (index - 1) * 61) or (width - 222 + (index - 1) * 51), narrowCard and 394 or 362, 48, 48)
	end
	self.configActions.Position = UDim2.new(0.5, 0, 0, self.configPanel.Position.Y.Offset + self.configPanel.Size.Y.Offset + 8)
	self.configActions.Size = UDim2.fromOffset(width, 90)
	place(self.readyButton, 12, 10, width - 24, 49)
	place(self.readyStatus, 12, 64, width - 24, 17)
	self.readyStatus.TextSize = narrowCard and 10 or 11
	self.readyStatus.TextWrapped = false
	self.gadgetSummary.Visible = false
	self.gadgetCopy.Visible = true
	self.paintName.Visible = true
	self.configPanel.Eyebrow.Visible = true
	place(self.configPanel.Title, 24, 40, inner, 33)
	self.configPanel.Title.TextSize = 27
	place(self.configPanel.GadgetTitle, 24, 229, inner, 20)
	local landscape = viewport.X >= 680 and height < 470
	if landscape then
		-- Two columns keep every choice usable at normal touch size in landscape.
		-- Very short devices can scroll the description while READY stays pinned.
		local wide = math.min(760, viewport.X - 32)
		local halfWidth = wide / 2
		local right = halfWidth + 16
		local rightInner = halfWidth - 32
		local bodyHeight = math.min(201, math.max(104, height - 153))
		self.configPanel.Position = UDim2.new(0.5, 0, 0, 65)
		self.configPanel.Size = UDim2.fromOffset(wide, bodyHeight)
		self.configPanel.CanvasSize = UDim2.fromOffset(0, 201)
		self.configPanel.Eyebrow.Visible = false
		place(self.configPanel.Title, 16, 8, halfWidth - 32, 27)
		self.configPanel.Title.TextSize = 21
		place(self.configPanel.Divider, 16, 39, halfWidth - 32, 1)
		place(self.configPanel.GadgetTitle, right, 13, rightInner, 20)
		local gadgetSize = (rightInner - 16) / 3
		for index, name in ipairs(GADGETS) do
			place(self.gadgetButtons[name], right + (index - 1) * (gadgetSize + 8), 43, gadgetSize, 48)
			self.gadgetButtons[name].TextSize = 14
		end
		place(self.configPanel.PaintTitle, right, 103, halfWidth - 232, 22)
		place(self.paintName, right, 127, halfWidth - 232, 20)
		self.paintName.TextSize = 10
		for index, control in ipairs(self.colorButtons) do
			place(control, wide - 216 + (index - 1) * 50, 102, 44, 44)
		end
		place(self.gadgetCopy, right, 155, rightInner, 36)
		self.gadgetCopy.Visible = false
		self.configActions.Position = UDim2.new(0.5, 0, 0, 65 + bodyHeight + 8)
		self.configActions.Size = UDim2.fromOffset(wide, 64)
		place(self.readyButton, wide - 258, 8, 246, 48)
		self.readyButton.TextSize = 17
		self.gadgetSummary.Visible = true
		place(self.gadgetSummary, 16, 5, wide - 290, 23)
		place(self.readyStatus, 16, 30, wide - 290, 25)
		self.readyStatus.TextWrapped = true
	else
		self.paintName.TextSize = 11
		self.readyButton.TextSize = 21
	end
	self.resultsPanel.Title.TextSize = narrowCard and 24 or 27
	self.resultMessage.TextSize = narrowCard and 11 or 12
	self.resultMessage.TextTruncate = Enum.TextTruncate.AtEnd
	for _, row in ipairs(self.resultRows) do
		row.frame.Size = UDim2.fromOffset(inner, 37)
		place(row.name, 44, 0, inner - 151, 37)
		row.name.TextSize = narrowCard and 12 or 15
		place(row.distance, inner - 110, 0, 98, 37)
		row.distance.TextSize = narrowCard and 15 or 17
	end
	local personal = self.resultsPanel.PersonalResult
	personal.Size = UDim2.fromOffset(inner, 75)
	local half = inner / 2
	place(personal.YourLabel, 15, 11, half - 15, 16)
	place(personal.BestLabel, half + 8, 11, half - 20, 16)
	place(self.yourDistance, 15, 33, half - 15, 28)
	place(self.bestDistance, half + 8, 33, half - 20, 28)
	self.yourDistance.TextSize = narrowCard and 21 or 23
	self.bestDistance.TextSize = narrowCard and 21 or 23
	self.nextRoundLabel.TextSize = narrowCard and 10 or 12
	self.compactFlight = height < 430
	local flightHeight = self.compactFlight and 103 or 126
	self.flightPanel.Size = UDim2.fromOffset(width, flightHeight)
	self.flightPanel.CanvasSize = UDim2.fromOffset(0, flightHeight)
	place(self.watchedLabel, 20, self.compactFlight and 8 or 13, width - 40, 19)
	place(self.flightDistance, 20, self.compactFlight and 28 or 33, width - 163, self.compactFlight and 38 or 46)
	self.flightDistance.TextSize = self.compactFlight and 32 or 39
	place(self.flightStatus, width - 137, self.compactFlight and 39 or 46, 116, 25)
	self.flightStatus.TextSize = narrowCard and 12 or 15
	place(self.flightPanel.Rule, 20, self.compactFlight and 73 or 88, width - 40, 1)
	place(self.flightStats, 20, self.compactFlight and 82 or 98, width - 40, 17)
	self.flightStats.TextSize = narrowCard and 10 or 12
	self.toast.Size = UDim2.fromOffset(width, 47)
	self.toast.Position = UDim2.new(0.5, 0, 0, 87 + flightHeight + 12)
	place(self.toastText, 16, 9, width - 32, 28)
	self.toastText.TextSize = narrowCard and 14 or 17
	self.flightControls.Size = UDim2.fromOffset(width, 67)
	local spectateWidth = width - 171
	place(self.flightControls.PreviousPilot, 8, 10, 48, 47)
	place(self.spectateLabel, 61, 11, math.max(20, spectateWidth - 109), 45)
	self.spectateLabel.Text = narrowCard and "PILOTS" or "WATCH PILOTS"
	self.spectateLabel.TextSize = narrowCard and 10 or 12
	place(self.flightControls.NextPilot, spectateWidth - 43, 10, 48, 47)
	place(self.lobbyButton, spectateWidth + 13, 10, 148, 47)
	self.lobbyButton.TextSize = narrowCard and 14 or 16
	self.flightPanel.Position = UDim2.new(0.5, 0, 0, 87)
	local narrow = viewport.X < 600
	self.header.Position = UDim2.fromOffset(narrow and 8 or 16, 10)
	self.header.Size = UDim2.new(1, narrow and -16 or -32, 0, 65)
	self.header.Brand.TextSize = narrow and 18 or 23
	self.header.Brand.Size = UDim2.fromOffset(narrow and 135 or 175, 24)
	self.brandSub.TextSize = narrow and 8 or 10
	self.phaseLabel.TextSize = narrow and 9 or 13
	self.phaseLabel.Size = UDim2.fromOffset(narrow and 136 or 310, 23)
	self.phaseLabel.Position = UDim2.new(1, narrow and -190 or -390, 0, 13)
	self.courseLabel.TextSize = narrow and 9 or 11
	self.courseLabel.Size = UDim2.fromOffset(narrow and 136 or 310, 17)
	self.courseLabel.Position = UDim2.new(1, narrow and -190 or -390, 0, 37)
	self.timer.TextSize = narrow and 23 or 28
	self.timer.Position = UDim2.new(1, narrow and -53 or -68, 0, 10)
	self.timer.Size = UDim2.fromOffset(narrow and 46 or 58, 44)
	self.footer.TextSize = viewport.X < 390 and 8 or 10
	if landscape then
		self.header.Position = UDim2.fromOffset(16, 6)
		self.header.Size = UDim2.new(1, -32, 0, 50)
		self.header.Brand.Position = UDim2.fromOffset(18, 3)
		self.brandSub.Position = UDim2.fromOffset(19, 27)
		self.phaseLabel.Position = UDim2.new(1, -390, 0, 4)
		self.courseLabel.Position = UDim2.new(1, -390, 0, 27)
		self.timer.Position = UDim2.new(1, -68, 0, 3)
		if height < 330 then
			-- Small landscape phones have as little as 280 px below the safe inset.
			-- Fit every choice at touch size, preserving the fixed action footer.
			local wide = math.min(760, viewport.X - 32)
			local halfWidth = wide / 2
			local right = halfWidth + 16
			local bodyHeight = math.min(140, math.max(130, height - 146))
			self.header.Size = UDim2.new(1, -32, 0, 42)
			self.header.Brand.Position = UDim2.fromOffset(18, 0)
			self.brandSub.Position = UDim2.fromOffset(19, 23)
			self.phaseLabel.Position = UDim2.new(1, -390, 0, 0)
			self.courseLabel.Position = UDim2.new(1, -390, 0, 23)
			self.timer.Size = UDim2.fromOffset(58, 36)
			self.timer.TextSize = 25
			self.configPanel.Position = UDim2.new(0.5, 0, 0, 54)
			self.configPanel.Size = UDim2.fromOffset(wide, bodyHeight)
			self.configPanel.CanvasSize = UDim2.fromOffset(0, bodyHeight)
			place(self.configPanel.Title, 16, 1, halfWidth - 32, 24)
			self.configPanel.Title.TextSize = 18
			self.configPanel.Divider.Visible = false
			place(self.configPanel.GadgetTitle, right, 4, halfWidth - 32, 20)
			for _, control in pairs(self.gadgetButtons) do
				control.Position = UDim2.fromOffset(control.Position.X.Offset, 30)
			end
			place(self.configPanel.PaintTitle, right, 98, halfWidth - 232, 22)
			self.paintName.Visible = false
			for _, control in ipairs(self.colorButtons) do
				control.Position = UDim2.fromOffset(control.Position.X.Offset, 88)
			end
			self.configActions.Position = UDim2.new(0.5, 0, 0, 54 + bodyHeight + 6)
			self.votePanel.Position = UDim2.new(0.5, 0, 0, 54)
			self.votePanel.Size = UDim2.fromOffset(math.min(760, viewport.X - 32), 206)
			self.flightPanel.Position = UDim2.new(0.5, 0, 0, 60)
		else
			self.configPanel.Divider.Visible = true
		end
	else
		self.header.Brand.Position = UDim2.fromOffset(18, 10)
		self.brandSub.Position = UDim2.fromOffset(19, 35)
		self.configPanel.Divider.Visible = true
	end
	self:_layoutPlaneChoices(viewport, height)
	self:_layoutDuel(viewport, height)
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
		self.rematchButton.Text = "REMATCH"
		self.rematchButton.Active = true
		self.pendingSettings = nil
		self.pendingReady = nil
		self.pendingUntil = 0
		self.readyPendingUntil = 0
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
	self.phaseLabel.Text = PHASE_NAMES[phase] or string.upper(phase)
	self.timer.Text = (snapshot.endsAt or 0) > 0 and tostring(remaining) or "--"
	self.courseLabel.Text = snapshot.courseName and string.upper(snapshot.courseName) or "DISTANCE WINS"
	local inHub = phase == "Lobby" or phase == "Queued"
	self.statsButton.Visible = inHub
	if not inHub then self.statsOverlay.Visible = false end
	self.statsButton.Position = UDim2.fromOffset(16, self.lastViewport.X < 560 and 150 or 100)
	self.soundButton.Visible = inHub or phase == "Flight"
	self.soundButton.AnchorPoint = inHub and Vector2.zero or Vector2.new(0, 1)
	self.soundButton.Position = inHub and UDim2.fromOffset(152, self.lastViewport.X < 560 and 150 or 100)
		or UDim2.new(0, 12, 1, self.lastViewport.X < 480 and -86 or -26)
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
	self.hubCard.Visible = inHub
	self.hubAction.Visible = inHub
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
	self.waitingMessage.Text = snapshot.message or "Getting the runway ready…"
	if phase == "Lobby" then
		self.hubTitle.Text = "SKYBOUND / FLIGHT CLUB"
		self.hubInstruction.Text = "Walk onto a 1v1 pad with an opponent."
		self.hubAction.Text = "PRACTICE VS GHOST"
		self.hubAction.Visible = self.callbacks.practice ~= nil
	elseif phase == "Queued" then
		self.hubTitle.Text = "WAITING FOR OPPONENT"
		local queue = snapshot.queue or {}
		local station = queue.stationName or (queue.stationId and "Pad " .. tostring(queue.stationId)) or "1v1 pad"
		self.hubInstruction.Text = station .. " · walk off the pad to leave."
		self.hubAction.Text = "LEAVE QUEUE"
	elseif phase == "Voting" then
		for name, votes in pairs(self.voteCounts) do
			votes.Text = tostring((snapshot.votes or {})[name] or 0)
		end
	elseif phase == "Configure" then
		self:_refreshSettings()
		self.readyStatus.Text = self.ready and "Waiting for your rival. Tap to change choices." or "Choose your loadout. Aim your jet next."
	elseif phase == "Aim" or phase == "Countdown" then
		self:_refreshSettings()
		if phase == "Countdown" then
			self.aimStatus.Text = "Takeoff in " .. remaining .. "…"
		else
			local readyText = tostring(readyCount) .. "/" .. tostring(humanCount) .. " ready"
			self.aimStatus.Text = self.ready and (readyText .. " · Waiting for rival") or (readyText .. (UserInputService.KeyboardEnabled and " · A/D aim · R ready" or " · Release to set angle"))
		end
	elseif phase == "Flight" then
		local flight = watchedPlayer and watchedPlayer.flight
		local ownFlight = localPlayer and localPlayer.flight
		local rivalFlight = opponent and opponent.flight
		local ownDistance = ownFlight and (ownFlight.distance or ownFlight.x) or 0
		local rivalDistance = rivalFlight and (rivalFlight.distance or rivalFlight.x) or 0
		local gap = ownDistance - rivalDistance
		self.ownPilot.Text = "YOU" .. (localPlayer and " · " .. string.upper(localPlayer.name) or "")
		self.opponentPilot.Text = opponent and string.upper(opponent.name) or "OPPONENT"
		self.flightDistance.Text = distance(ownDistance)
		self.opponentDistance.Text = distance(rivalDistance)
		if math.abs(gap) < 0.5 then self.leadLabel.Text = "NECK AND NECK"
		elseif gap > 0 then self.leadLabel.Text = "LEAD +" .. distance(gap)
		else self.leadLabel.Text = "TRAIL " .. distance(-gap) end
		self.leadLabel.TextColor3 = gap < -0.5 and COLORS.coral or COLORS.green
		self.watchedLabel.Text = watchedPlayer and ("CAMERA: " .. string.upper(watchedPlayer.name)) or "CAMERA: TAKEOFF"
		self.watchedLabel.TextTruncate = Enum.TextTruncate.AtEnd
		local altitude = flight and math.max(0, flight.y or 0) or 0
		self.flightStatus.Text = flight and flight.alive and ("GROUND " .. distance(altitude)) or "DISTANCE LOCKED"
		self.flightStatus.TextColor3 = flight and flight.alive and altitude < 28 and COLORS.coral or COLORS.muted
		self.flightStats.Text = "Waiting for takeoff"
		self.flightStats.TextColor3 = COLORS.muted
		if flight then
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
		self.resultsPanel.Title.Text = yourResult and yourResult.rank == 1
			and (hasForfeit and "YOU WIN THE DUEL." or "YOU WENT FURTHEST.") or "ONE MORE FLIGHT?"
		self.nextRoundLabel.Text = (snapshot.endsAt or 0) > 0 and ("Return to lobby in " .. remaining .. "s") or "Request a rematch or head back to the club."
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
			self.rematchButton.Text = opponent and opponent.rematchReady and "ACCEPT REMATCH" or "REMATCH"
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
			elseif entry.kind == "boost" then text = "RESCUE BOOST!" end
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
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	table.clear(self.connections)
	if self.gui then self.gui:Destroy() end
end

return Hud
