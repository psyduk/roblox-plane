-- Pop Duel: the native GUI client. All outcomes arrive from the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local localPlayer = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("PegGame")
local Simulation = require(shared:WaitForChild("PegSimulation"))
local Powers = require(shared:WaitForChild("PegPowers"))
local BoardView = require(script.Parent:WaitForChild("PegBoardView"))
local AvatarView = require(script.Parent:WaitForChild("PegAvatarView"))
local Audio = require(script.Parent:WaitForChild("PegAudio"))
local command = shared:WaitForChild("Command")
local snapshots = shared:WaitForChild("Snapshot")
local audio = Audio.new()
local latest, localEntry, rivalEntry = nil, nil, nil
local angle, powerId = 0, Powers.DEFAULT_ID or "pulse"
local lastAimSent, pendingAim, dragInput = -1, false, nil
local readyPending = false
local readySentAt, readyRetryUntil = 0, 0
local keyLeft, keyRight = false, false
local clockOffset = 0
local controls, controlsActive, savedCamera = nil, true, nil
local muted, reducedMotion = false, false
local lastRoundKey, resultKey, lastPhase = nil, nil, nil
local shownScore, shownRivalScore = 0, 0
local width, height, layoutMode = 0, 0, "portrait"
local TEAL = Color3.fromRGB(74, 235, 228)
local ORANGE = Color3.fromRGB(255, 165, 63)
local WHITE = Color3.fromRGB(255, 253, 241)
local MUTED = Color3.fromRGB(89, 73, 151)
local NAVY = Color3.fromRGB(50, 33, 112)
local YELLOW = Color3.fromRGB(255, 226, 76)
local PINK = Color3.fromRGB(255, 109, 170)
local BLUE = Color3.fromRGB(58, 191, 255)
local FONT = Enum.Font.GothamBold
local DISPLAY = Enum.Font.FredokaOne

local function make(class, name, parent, props)
    local obj = Instance.new(class)
    obj.Name = name
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function corner(obj, px)
    make("UICorner", "Corner", obj, {CornerRadius = UDim.new(0, px or 14)})
end
local function stroke(obj, color, thick)
    return make("UIStroke", "Outline", obj, {Color = color, Thickness = thick or 3,
        Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
local function label(parent, name, text, size, color, font)
    return make("TextLabel", name, parent, {BackgroundTransparency = 1, Text = text,
        TextColor3 = color or WHITE, Font = font or FONT, TextSize = size or 16,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.fromScale(1, 1), ZIndex = parent.ZIndex + 1})
end
local function button(parent, name, text, color, onClick)
    local b = make("TextButton", name, parent, {Text = text, Font = FONT, TextSize = 17,
        TextColor3 = NAVY, BackgroundColor3 = color or WHITE,
        BorderSizePixel = 0, AutoButtonColor = true, ZIndex = parent.ZIndex + 1,
        Size = UDim2.fromOffset(160, 48), Selectable = true})
    corner(b, 16)
    stroke(b, WHITE, 3)
    b.Activated:Connect(function() onClick() end)
    return b
end
local function place(obj, x, y, w, h)
    obj.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
    obj.Size = UDim2.fromOffset(math.max(1, math.floor(w)), math.max(1, math.floor(h)))
end
local function commas(value)
    local str = tostring(math.floor(value or 0))
    local formatted = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return formatted:gsub("^,", "")
end
local function send(kind, values)
    local packet = values or {}
    packet.kind = kind
    if latest then packet.matchId = latest.matchId; packet.roundId = latest.roundId end
    command:FireServer(packet)
end
local function canAim()
    return latest and latest.phase == "Aim" and localEntry and not localEntry.ready and not readyPending
end
local function activeMatch()
    return latest and latest.phase ~= "Lobby" and latest.phase ~= "Queued"
end
local function ready()
    if not canAim() then return end
    pendingAim, readyPending, dragInput = false, true, nil
    readySentAt = os.clock()
    send("ready", {angle = angle, powerId = powerId})
    audio:select(true)
end

local previous = localPlayer:WaitForChild("PlayerGui"):FindFirstChild("PegHud")
if previous then previous:Destroy() end
local oldBackdrop = localPlayer.PlayerGui:FindFirstChild("PegBackdrop")
if oldBackdrop then oldBackdrop:Destroy() end
local backdropGui = make("ScreenGui", "PegBackdrop", localPlayer.PlayerGui, {
    ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 29,
})
local backdrop = make("Frame", "FullViewport", backdropGui, {BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, ClipsDescendants = true})
make("UIGradient", "SkyCandy", backdrop, {Rotation = 85, Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(72, 195, 255)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(124, 219, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(171, 155, 255)),
})})
-- Native shapes keep the sky crisp at any resolution and need no asset downloads.
for i = 1, 14 do
    local bubble = make("Frame", "SkyBubble" .. i, backdrop, {AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale((i * 0.618034) % 1, (i * 0.271828) % 1),
        Size = UDim2.fromOffset(22 + i % 5 * 19, 22 + i % 5 * 19),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, BorderSizePixel = 0})
    corner(bubble, 100)
    local edge = stroke(bubble, WHITE, 2); edge.Transparency = 0.7
end
for i = 1, 7 do
    local cloud = make("Frame", "Cloud" .. i, backdrop, {BackgroundTransparency = 1,
        Position = UDim2.fromScale((i - 1) / 6 - 0.05, 0.87 + (i % 3) * 0.025),
        Size = UDim2.fromOffset(260, 150)})
    for j = 1, 4 do
        local puff = make("Frame", "Puff" .. j, cloud, {BackgroundColor3 = WHITE,
            BackgroundTransparency = 0.12, BorderSizePixel = 0,
            Position = UDim2.fromOffset((j - 1) * 52, j % 2 == 0 and 2 or 30),
            Size = UDim2.fromOffset(128, 128)})
        corner(puff, 100)
    end
end
local gui = make("ScreenGui", "PegHud", localPlayer.PlayerGui, {
    ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 30,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local root = make("Frame", "UI", gui, {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)})
local match = make("Frame", "Match", root, {BackgroundTransparency = 1,
    BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 1})
local header = make("Frame", "Scoreboard", match, {BackgroundTransparency = 1, BorderSizePixel = 0})
local brand = label(header, "Brand", "POP DUEL", 40, WHITE, DISPLAY)
brand.TextXAlignment = Enum.TextXAlignment.Center
brand.TextStrokeColor3, brand.TextStrokeTransparency = NAVY, 0
local phaseBadge = make("Frame", "PhaseBadge", header, {BackgroundColor3 = YELLOW, BorderSizePixel = 0})
corner(phaseBadge, 20); stroke(phaseBadge, WHITE, 3)
local function contestant(name, color)
    local group = make("Frame", name, match, {BackgroundTransparency = 1, ZIndex = 2})
    local halo = make("Frame", "Halo", group, {AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.43), Size = UDim2.fromScale(0.93, 0.76),
        BackgroundColor3 = color, BackgroundTransparency = 0.64, BorderSizePixel = 0})
    corner(halo, 150)
    local edge = stroke(halo, WHITE, 3); edge.Transparency = 0.6
    local podium = make("Frame", "Podium", group, {AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.84, 0.13),
        BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 2})
    corner(podium, 100); stroke(podium, WHITE, 3)
    local view = AvatarView.new(group, color, name == "YouAvatar" and -1 or 1)
    view.root.Size = UDim2.new(1, 0, 1, -5)
    view.root.ZIndex = 3
    return group, view
end
local youAvatar, youView = contestant("YouAvatar", BLUE)
local opponentAvatar, opponentView = contestant("OpponentAvatar", PINK)
local function scorePlate(name, color)
    local card = make("Frame", name, match, {BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 5})
    corner(card, 18); stroke(card, color, 4)
    return card
end
local yourPlate, rivalPlate = scorePlate("YourPlate", BLUE), scorePlate("RivalPlate", PINK)
local myName = label(yourPlate, "YourName", "YOU", 14, NAVY)
local myScore = label(yourPlate, "YourScore", "0", 38, NAVY, DISPLAY)
local rivalName = label(rivalPlate, "RivalName", "RIVAL", 14, NAVY)
local rivalScore = label(rivalPlate, "RivalScore", "0", 38, NAVY, DISPLAY)
for _, text in ipairs({myScore, rivalScore}) do
    text.TextScaled = true
    make("UITextSizeConstraint", "ScoreSize", text, {MinTextSize = 16, MaxTextSize = 38})
    text.TextXAlignment = Enum.TextXAlignment.Center
end
for _, text in ipairs({myName, rivalName}) do
    text.TextScaled = true
    make("UITextSizeConstraint", "NameSize", text, {MinTextSize = 9, MaxTextSize = 14})
    text.TextXAlignment = Enum.TextXAlignment.Center
end
local phaseLabel = label(phaseBadge, "Phase", "AIM", 20, NAVY, DISPLAY)
phaseLabel.TextXAlignment = Enum.TextXAlignment.Center
local timerLabel = label(phaseBadge, "Timer", "", 13, NAVY)
timerLabel.TextXAlignment = Enum.TextXAlignment.Center
local boardContainer = make("Frame", "BoardContainer", match, {BackgroundTransparency = 1})
local mainView = BoardView.new(boardContainer, Simulation, false, function(event, shot) audio:event(event, shot) end)
local rivalContainer = make("Frame", "RivalPreview", match, {BackgroundTransparency = 1, Visible = false})
local rivalTitle = label(rivalContainer, "Label", "RIVAL'S BOARD", 15, NAVY, DISPLAY)
place(rivalTitle, 0, 0, 190, 24)
local rivalBoardContainer = make("Frame", "Preview", rivalContainer, {Position = UDim2.fromOffset(0, 28), Size = UDim2.fromOffset(176, 158), BackgroundTransparency = 1})
local rivalView = BoardView.new(rivalBoardContainer, Simulation, true)
local rivalCaption = label(rivalContainer, "Caption", "Same board. One shot.", 12, MUTED)
place(rivalCaption, 0, 196, 190, 35)
rivalCaption.TextWrapped = true
local controlsPanel = make("Frame", "ShotControls", match, {BackgroundTransparency = 1})
local chooseLabel = label(controlsPanel, "ChoosePower", "PICK YOUR POWER", 15, NAVY, DISPLAY)
local powerCards = {}
local descriptions = {
    pulse = "Pop a whole cluster.",
    split = "One ball becomes two.",
    ["return"] = "One trip back to the top.",
}
local powerColors = {pulse = Color3.fromRGB(83, 235, 169), split = ORANGE, ["return"] = Color3.fromRGB(196, 158, 255)}
local function powerIcon(parent, id, color)
    local function dot(name, x, y, diameter)
        local obj = make("Frame", name, parent, {AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(diameter, diameter),
            BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = parent.ZIndex + 1})
        corner(obj, diameter)
        return obj
    end
    if id == "split" then
        dot("LeftBall", 0.36, 0.44, 11)
        dot("RightBall", 0.68, 0.6, 11)
    else
        local ring = dot("Ring", 0.5, 0.5, 21)
        ring.BackgroundTransparency = 1
        local outline = stroke(ring, color, 2)
        outline.Transparency = 0
        if id == "pulse" then
            dot("Core", 0.5, 0.5, 7)
        else
            local arrow = label(parent, "ReturnArrow", ">", 18, color)
            arrow.AnchorPoint = Vector2.new(0.5, 0.5)
            arrow.Position = UDim2.fromScale(0.74, 0.39)
            arrow.Size = UDim2.fromOffset(13, 18)
            arrow.Rotation = 56
            arrow.TextXAlignment = Enum.TextXAlignment.Center
        end
    end
end
for _, item in ipairs(Powers.ITEMS) do
    local itemId = item.id
    local card = button(controlsPanel, "Power_" .. itemId, "", powerColors[itemId], function()
        if canAim() then powerId = itemId; send("power", {powerId = powerId}); audio:select(false) end
    end)
    local icon = label(card, "Icon", "", 29, powerColors[itemId] or TEAL, DISPLAY)
    icon.TextXAlignment = Enum.TextXAlignment.Center
    powerIcon(icon, itemId, NAVY)
    local name = label(card, "Name", item.name, 18, NAVY, DISPLAY)
    local desc = label(card, "Description", descriptions[itemId] or item.description, 12, NAVY)
    desc.TextWrapped = true
    local marker = make("Frame", "Selected", card, {BackgroundColor3 = WHITE,
        BorderSizePixel = 0, Size = UDim2.fromOffset(4, 40), Position = UDim2.fromOffset(0, 10), Visible = false})
    corner(marker, 3)
    powerCards[itemId] = {root = card, name = name, desc = desc, icon = icon, marker = marker}
end
local fire = button(controlsPanel, "Fire", "LET'S POP!", YELLOW, ready)
fire.Font, fire.TextSize = DISPLAY, 30
local hint = label(controlsPanel, "AimHint", "Drag to aim · R to lock", 12, MUTED)
hint.TextXAlignment = Enum.TextXAlignment.Center
local shotInfo = label(controlsPanel, "ShotInfo", "Hit green to unleash your power", 23, NAVY, DISPLAY)
shotInfo.TextXAlignment = Enum.TextXAlignment.Center
shotInfo.TextWrapped = true
local combo = label(match, "Combo", "", 24, NAVY, DISPLAY)
combo.TextXAlignment = Enum.TextXAlignment.Center
local boardTag = label(match, "BoardTag", "ONE SHOT. BIG SCORE.", 13, NAVY, DISPLAY)
boardTag.TextXAlignment = Enum.TextXAlignment.Center

local lobby = make("Frame", "Lobby", root, {BackgroundColor3 = WHITE, BackgroundTransparency = 0,
    BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), ZIndex = 20})
corner(lobby, 22)
stroke(lobby, BLUE, 5)
local eyebrow = label(lobby, "Brand", "S K Y B O U N D", 13, MUTED)
local title = label(lobby, "Title", "POP DUEL", 42, NAVY, DISPLAY)
local tagline = label(lobby, "Tagline", "Aim once. Let it pop.", 16, MUTED)
local play = button(lobby, "PlayDuel", "PLAY DUEL", YELLOW, function() send("join"); audio:select(true) end)
local practice = button(lobby, "Practice", "PRACTICE", TEAL, function() send("practice"); audio:select(false) end)
local cancel = button(lobby, "CancelQueue", "CANCEL", PINK, function() send("cancel") end)
cancel.Visible = false
local lobbyStats = label(lobby, "SessionStats", "0 WINS    ·    BEST 0", 11, MUTED)
local status = label(lobby, "Status", "A quick score duel on matching boards.", 12, MUTED)
status.TextWrapped = true

local utilities = make("Frame", "Preferences", root, {BackgroundTransparency = 1, ZIndex = 60})
local soundButton = button(utilities, "Sound", "SFX", WHITE, function()
    muted = not muted; audio:setMuted(muted)
end)
soundButton.TextSize = 11
local motionButton = button(utilities, "Motion", "FX", WHITE, function()
    reducedMotion = not reducedMotion
    mainView:setReducedMotion(reducedMotion); rivalView:setReducedMotion(reducedMotion)
    youView:setReducedMotion(reducedMotion); opponentView:setReducedMotion(reducedMotion)
end)
motionButton.TextSize = 11
place(soundButton, 0, 0, 46, 44)
place(motionButton, 52, 0, 46, 44)

local results = make("Frame", "Results", root, {BackgroundColor3 = Color3.fromRGB(88, 65, 159),
    BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 40, Visible = false})
local resultCard = make("Frame", "Card", results, {AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = WHITE, Position = UDim2.fromScale(0.5, 0.5), BorderSizePixel = 0, ZIndex = 41})
corner(resultCard, 24)
stroke(resultCard, YELLOW, 6)
local resultEyebrow = label(resultCard, "Eyebrow", "SHOT COMPLETE", 12, MUTED)
resultEyebrow.TextXAlignment = Enum.TextXAlignment.Center
local resultTitle = label(resultCard, "Title", "NICE SHOT!", 37, NAVY, DISPLAY)
resultTitle.TextXAlignment = Enum.TextXAlignment.Center
local resultScore = label(resultCard, "Score", "0", 46, NAVY, DISPLAY)
resultScore.TextXAlignment = Enum.TextXAlignment.Center
local resultRival = label(resultCard, "Rival", "Rival: 0", 15, MUTED)
resultRival.TextXAlignment = Enum.TextXAlignment.Center
local resultDetail = label(resultCard, "Detail", "", 13, MUTED)
resultDetail.TextXAlignment = Enum.TextXAlignment.Center
local rematch = button(resultCard, "Rematch", "PLAY AGAIN", YELLOW, function() send("rematch"); audio:select(true) end)
local leave = button(resultCard, "ReturnLobby", "LOBBY", TEAL, function() send("returnLobby") end)
local confetti = {}
for i = 1, 28 do
    local bit = make("Frame", "Confetti" .. i, results, {BackgroundColor3 = ({TEAL, ORANGE, Color3.fromRGB(187, 144, 255)})[(i - 1) % 3 + 1],
        BorderSizePixel = 0, Size = UDim2.fromOffset(5 + i % 4, 8 + i % 5), ZIndex = 42, Visible = false})
    corner(bit, 2)
    confetti[i] = bit
end
local celebrationAt = -100

local function layout()
    width, height = root.AbsoluteSize.X, root.AbsoluteSize.Y
    if width < 1 or height < 1 then return end
    local landscape = height < 660 and width > height
    local desktop = width >= 950 and not landscape
    layoutMode = landscape and "landscape" or desktop and "desktop" or "portrait"
    place(header, 0, 0, width, desktop and 92 or landscape and 50 or 160)
    local bx, by, bw, bh, cx, cy, cw, ch
    local plateW, plateH
    if desktop then
        local side = math.clamp(width * 0.145, 170, 240)
        bw = math.min(width - 2 * (side + 28) - 36, (height - 142) / 0.9)
        bh = bw * 0.9; bx = (width - bw) / 2; by = 108
        local lx, rx = bx - side - 28, bx + bw + 28
        plateW, plateH = side, 68
        place(yourPlate, lx, by + 6, side, plateH)
        place(rivalPlate, rx, by + 6, side, plateH)
        local avatarH = math.clamp(height * 0.32, 125, 260)
        place(youAvatar, lx, by + 80, side, avatarH)
        place(opponentAvatar, rx, by + 80, side, avatarH)
        cx, cy, cw, ch = lx, by + 90 + avatarH, side, height - (by + 90 + avatarH) - 14
        local previewW = math.min(side - 20, 192)
        place(rivalContainer, rx + (side - previewW) / 2, cy + 4, previewW, previewW * 0.9 + 65)
        place(rivalTitle, 0, 0, previewW, 22)
        place(rivalBoardContainer, 0, 28, previewW, previewW * 0.9)
        place(rivalCaption, 0, previewW * 0.9 + 35, previewW, 26)
        place(brand, width / 2 - 150, 0, 300, 46); brand.TextSize = 42
        place(phaseBadge, width / 2 - 72, 47, 144, 36)
        place(phaseLabel, 8, 0, 90, 36); place(timerLabel, 99, 0, 36, 36)
        place(utilities, width - 110, 8, 98, 44)
    elseif landscape then
        local side = math.clamp(width * 0.2, 144, 170)
        bh = height - 90; bw = bh / 0.9
        bx, by = math.max(side + 12, (width - bw) / 2), 55
        plateW, plateH = side, 49
        place(yourPlate, 8, 56, side, plateH)
        place(rivalPlate, width - side - 8, 56, side, plateH)
        local avatarH = math.clamp(height - 226, 48, 180)
        place(youAvatar, 12, 113, side - 8, avatarH)
        place(opponentAvatar, width - side - 4, 113, side - 8, avatarH)
        cx, cy, cw, ch = width - side - 8, 121 + avatarH, side, height - 127 - avatarH
        place(brand, 12, 0, 170, 42); brand.TextSize = 28
        place(phaseBadge, width / 2 - 64, 3, 128, 38)
        place(phaseLabel, 4, 0, 85, 38); place(timerLabel, 88, 0, 35, 38)
        place(utilities, width - 108, 0, 98, 44)
    else
        plateW, plateH = math.min(125, width * 0.32), 48
        place(youAvatar, 9, 0, plateW, 100)
        place(opponentAvatar, width - plateW - 9, 0, plateW, 100)
        place(yourPlate, 8, 101, plateW, plateH)
        place(rivalPlate, width - plateW - 8, 101, plateW, plateH)
        place(brand, width / 2 - 64, 0, 128, 34); brand.TextSize = 24
        place(phaseBadge, width / 2 - 46, 37, 92, 57)
        place(phaseLabel, 4, 0, 84, 31); place(timerLabel, 4, 30, 84, 22)
        place(utilities, width / 2 - 49, 104, 98, 44)
        bw = math.min(width - 24, (height - 374) / 0.9)
        bw = math.max(150, bw); bh = bw * 0.9
        bx, by = (width - bw) / 2, 170
        cx, cy, cw, ch = 12, by + bh + 28, width - 24, 151
    end
    for _, pair in ipairs({{myName, myScore}, {rivalName, rivalScore}}) do
        place(pair[1], 5, 4, plateW - 10, desktop and 20 or 16)
        place(pair[2], 5, desktop and 24 or 19, plateW - 10, desktop and 40 or 27)
    end
    phaseLabel.TextSize = landscape and 18 or 20
    timerLabel.TextSize = desktop and 17 or 13
    place(boardContainer, bx, by, bw, bh)
    place(boardTag, bx, by - 20, bw, 16)
    place(combo, bx, by + bh + 4, bw, 22)
    place(controlsPanel, cx, cy, cw, ch)
    rivalContainer.Visible = desktop
    local compact = not desktop and not landscape
    chooseLabel.Visible = not landscape
    place(chooseLabel, 0, 0, cw, 20)
    for index, item in ipairs(Powers.ITEMS) do
        local card = powerCards[item.id]
        if compact then
            local cardW = (cw - 16) / 3
            place(card.root, (index - 1) * (cardW + 8), 25, cardW, 57)
            place(card.icon, 4, 2, cardW - 8, 25)
            place(card.name, 4, 28, cardW - 8, 24)
            card.name.TextSize = width < 400 and 13 or 15
            card.name.TextXAlignment = Enum.TextXAlignment.Center
            card.desc.Visible = false
            card.marker.Size = UDim2.fromOffset(4, 37)
            card.marker.Position = UDim2.fromOffset(0, 10)
        elseif landscape then
            -- A compact row preserves the board and both full-body avatars.
            local cardW = (cw - 8) / 3
            place(card.root, (index - 1) * (cardW + 4), 0, cardW, 44)
            place(card.icon, 0, 0, cardW, 27)
            place(card.name, 0, 27, cardW, 15)
            card.name.TextSize = 9
            card.name.TextXAlignment = Enum.TextXAlignment.Center
            card.desc.Visible = false
            card.marker.Size = UDim2.fromOffset(3, 28)
            card.marker.Position = UDim2.fromOffset(0, 8)
        else
            local cardH = math.clamp((ch - 151) / 3, 36, 65)
            place(card.root, 0, 27 + (index - 1) * (cardH + 8), cw, cardH)
            place(card.icon, 3, 0, 44, cardH)
            place(card.name, 50, 4, cw - 56, 25)
            card.name.TextSize = cw < 190 and 16 or 19
            card.name.TextXAlignment = Enum.TextXAlignment.Left
            place(card.desc, 50, 28, cw - 58, cardH - 31)
            card.desc.Visible = cardH >= 56
            card.marker.Size = UDim2.fromOffset(4, cardH - 20)
            card.marker.Position = UDim2.fromOffset(0, 10)
        end
        card.name.Visible = true
        card.name.Text = landscape and ({pulse = "PULSE", split = "SPLIT", ["return"] = "RETURN"})[item.id] or item.name
    end
    if compact then
        fire.TextSize, shotInfo.TextSize = 28, 20
        place(fire, 0, 94, cw, 49)
        place(hint, 0, 149, cw, 20); hint.Visible = true
        place(shotInfo, 4, 22, cw - 8, 64)
    elseif landscape then
        place(fire, 0, 53, cw, 44)
        fire.TextSize = 21
        place(hint, 4, 102, cw - 8, 15); hint.Visible = false
        place(shotInfo, 3, 0, cw - 6, 47)
        shotInfo.TextSize = 14
    else
        local cardH = math.clamp((ch - 151) / 3, 36, 65)
        local fireY = 27 + 3 * (cardH + 8) + 7
        place(fire, 0, fireY, cw, 52)
        place(hint, 2, fireY + 59, cw - 4, 34); hint.Visible = true
        place(shotInfo, 8, 30, cw - 16, fireY - 40)
        fire.TextSize = cw < 190 and 25 or 30
        shotInfo.TextSize = 24
    end
    local lobbyW, lobbyH = math.min(width - 24, 450), landscape and 225 or 292
    lobby.Position = UDim2.new(0.5, 0, 1, -16)
    lobby.Size = UDim2.fromOffset(lobbyW, lobbyH)
    place(eyebrow, 24, 17, lobbyW - 48, 20)
    place(title, 22, 39, lobbyW - 44, landscape and 48 or 59)
    title.TextSize = landscape and 35 or 43
    place(tagline, 24, landscape and 88 or 99, lobbyW - 48, 24)
    local buttonsY = landscape and 120 or 140
    place(play, 24, buttonsY, (lobbyW - 58) * 0.59, 51)
    place(practice, 34 + (lobbyW - 58) * 0.59, buttonsY, (lobbyW - 58) * 0.41, 51)
    place(cancel, 24, buttonsY, (lobbyW - 58) * 0.59, 51)
    place(lobbyStats, 24, buttonsY + 63, lobbyW - 48, 18)
    place(status, 24, buttonsY + 87, lobbyW - 48, 34)
    status.Visible = not landscape
    local rw, rh = math.min(460, width - 32), math.min(372, height - 24)
    resultCard.Size = UDim2.fromOffset(rw, rh)
    local smallResult = rh < 330
    place(resultEyebrow, 15, 16, rw - 30, 20)
    place(resultTitle, 15, 39, rw - 30, 49)
    resultTitle.TextSize = smallResult and 29 or 37
    place(resultScore, 15, smallResult and 85 or 102, rw - 30, 61)
    place(resultRival, 15, smallResult and 143 or 172, rw - 30, 25)
    place(resultDetail, 15, smallResult and 170 or 211, rw - 30, 26)
    place(rematch, 22, rh - 72, (rw - 54) * 0.64, 49)
    place(leave, 32 + (rw - 54) * 0.64, rh - 72, (rw - 54) * 0.36, 49)
end

local function updateControls()
    local aiming = latest and latest.phase == "Aim"
    for id, card in pairs(powerCards) do
        card.root.Visible = aiming == true
        card.marker.Visible = id == powerId
        card.root.BackgroundColor3 = id == powerId and powerColors[id] or powerColors[id]:Lerp(WHITE, 0.65)
        card.root.Outline.Color = id == powerId and NAVY or WHITE
        card.root.Outline.Thickness = id == powerId and 4 or 3
        card.root.AutoButtonColor = canAim() == true
        card.root.Selectable = canAim() == true
    end
    chooseLabel.Visible = aiming == true and layoutMode ~= "landscape"
    shotInfo.Visible = not aiming
    if latest then
        local shot = localEntry and localEntry.shot
        if latest.phase == "Countdown" then
            shotInfo.Text = "LOCKED IN\nBoth shots launch together."
        elseif latest.phase == "Shot" then
            local item = Powers.get(powerId)
            shotInfo.Text = (item and item.name or "POWER") .. "\n" .. (shot and shot.powerUsed and "POWER ACTIVATED!" or "Hit green to activate")
        end
    end
    fire.Text = aiming and ((readyPending or (localEntry and localEntry.ready)) and "LOCKED IN" or "LET'S POP!") or latest and latest.phase == "Countdown" and "GET READY" or "IN FLIGHT"
    fire.BackgroundColor3 = canAim() and YELLOW or Color3.fromRGB(197, 228, 255)
    fire.TextColor3 = NAVY
    fire.AutoButtonColor, fire.Selectable = canAim() == true, canAim() == true
    if latest and latest.phase == "Shot" then
        hint.Text = localEntry and localEntry.shot and localEntry.shot.done and "Your score is locked. Rival still bouncing." or "Every bounce counts."
    elseif latest and latest.phase == "Countdown" then
        hint.Text = "Both shots launch together."
    elseif readyPending or (localEntry and localEntry.ready) then
        hint.Text = "Waiting for the other shot…"
    elseif os.clock() < readyRetryUntil then
        hint.Text = "Tap LET'S POP! again to lock your shot."
    else
        hint.Text = UserInputService.TouchEnabled and "Drag to aim, then LET'S POP!" or "Drag to aim · A / D nudge · R fire"
    end
end

local function setMovement(enabled)
    if controls and controlsActive ~= enabled then
        if enabled then controls:Enable() else controls:Disable() end
        controlsActive = enabled
    end
    local camera = workspace.CurrentCamera
    if not enabled and not savedCamera and camera then
        savedCamera = {subject = camera.CameraSubject}
        camera.CameraType = Enum.CameraType.Scriptable
        local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:Move(Vector3.zero) end
    elseif enabled and savedCamera and camera then
        camera.CameraType = Enum.CameraType.Custom
        local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
        camera.CameraSubject = humanoid or savedCamera.subject
        savedCamera = nil
    end
end
task.spawn(function()
    local playerModule = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
    if playerModule then
        local ok, value = pcall(function() return require(playerModule):GetControls() end)
        if ok then controls = value; setMovement(not activeMatch()) end
    end
end)
localPlayer.CharacterAdded:Connect(function()
    task.defer(function() setMovement(not activeMatch()) end)
end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)

snapshots.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" or type(data.phase) ~= "string" then return end
    latest = data
    clockOffset = (data.serverTime or workspace:GetServerTimeNow()) - os.clock()
    localEntry, rivalEntry = nil, nil
    for _, entry in ipairs(data.players or {}) do
        if entry.userId == localPlayer.UserId then localEntry = entry else rivalEntry = entry end
    end
    local roundKey = tostring(data.matchId) .. ":" .. tostring(data.roundId)
    if data.board and roundKey ~= lastRoundKey then
        lastRoundKey, resultKey = roundKey, nil
        angle = localEntry and localEntry.angle or 0
        powerId = localEntry and localEntry.powerId or Powers.DEFAULT_ID
        shownScore, shownRivalScore, pendingAim, readyPending = 0, 0, false, false
        readyRetryUntil = 0
        mainView:setBoard(data.board, roundKey)
        rivalView:setBoard(data.board, roundKey)
    end
    if localEntry then
        if data.phase ~= "Aim" or localEntry.ready then readyPending = false end
        -- A rejected/throttled ready must never strand the local controls.
        -- The server remains authoritative; retrying requires another press.
        if readyPending and not localEntry.ready and os.clock() - readySentAt > 1.2 then
            readyPending = false
            readyRetryUntil = os.clock() + 2
        end
        -- Preserve immediate local drag between throttled acknowledgements.
        if data.phase ~= "Aim" or localEntry.ready then
            angle, powerId = localEntry.angle or angle, localEntry.powerId or powerId
        end
        mainView:setShot(localEntry.shot)
    end
    if rivalEntry then rivalView:setShot(rivalEntry.shot); rivalView:setAim(rivalEntry.angle or 0, false) end
    mainView:setAim(angle, data.phase == "Aim")
    lobby.Visible = data.phase == "Lobby" or data.phase == "Queued"
    match.Visible = not lobby.Visible
    backdrop.Visible = match.Visible
    results.Visible = data.phase == "Results"
    setMovement(lobby.Visible)
    play.Visible, practice.Visible = data.phase == "Lobby", data.phase == "Lobby" or data.phase == "Queued"
    cancel.Visible = data.phase == "Queued"
    tagline.Text = data.phase == "Queued" and "Finding your next challenger…" or "Aim once. Let it pop."
    local stats = data.stats or {}
    lobbyStats.Text = tostring(stats.wins or 0) .. " WINS    ·    BEST " .. commas(stats.bestScore) .. "    ·    " .. tostring(stats.rounds or 0) .. " ROUNDS"
    status.Text = data.message or "A quick score duel on matching boards."
    myName.Text = "YOU"
    youView:setPlayer(localEntry)
    opponentView:setPlayer(rivalEntry)
    rivalName.Text = rivalEntry and (rivalEntry.isGhost and "PRACTICE RIVAL" or string.upper(string.sub(rivalEntry.name or "RIVAL", 1, 18))) or "RIVAL"
    if data.phase == "Results" then
        local outcome = data.result or {}
        local won = outcome.winnerId == localPlayer.UserId
        resultTitle.Text = outcome.draw and "SO CLOSE — A TIE!" or won and "YOU WIN!" or "NEXT SHOT'S YOURS"
        resultTitle.TextSize = won and 37 or 28
        resultEyebrow.Text = outcome.draw and "REMATCH?" or won and "WHAT A SHOT" or "SHOT COMPLETE"
        resultRival.Text = (rivalEntry and rivalEntry.name or "Rival") .. ": " .. commas(rivalEntry and rivalEntry.shot and rivalEntry.shot.score)
        local shot = localEntry and localEntry.shot
        resultDetail.Text = tostring(shot and shot.hitCount or 0) .. " TARGETS    ·    " .. tostring(shot and shot.multiplier or 1) .. "× MULTIPLIER"
        local waiting = data.rematchReady == true or (type(data.rematchReady) == "table" and (data.rematchReady[localPlayer.UserId] or data.rematchReady[tostring(localPlayer.UserId)]))
        rematch.Text = waiting and "WAITING…" or data.canRematch == false and "RIVAL LEFT" or "PLAY AGAIN"
        rematch.Active, rematch.Selectable = data.canRematch ~= false, data.canRematch ~= false
        rematch.AutoButtonColor = data.canRematch ~= false and not waiting
        if resultKey ~= roundKey then
            resultKey = roundKey
            celebrationAt = won and os.clock() or -100
            if won then audio:celebrate() end
        end
    end
    if lastPhase ~= data.phase then dragInput = nil; keyLeft = false; keyRight = false end
    lastPhase = data.phase
    updateControls()
    gui:SetAttribute("Phase", data.phase)
    gui:SetAttribute("MatchId", tostring(data.matchId or ""))
    gui:SetAttribute("RoundId", tostring(data.roundId or ""))
end)

local function pointOnBoard(screenPosition)
    -- InputObject.Position already uses the same CoreUISafeInsets coordinate
    -- system as GuiBase2d.AbsolutePosition, for both mouse and touch inputs.
    -- Only GetMouseLocation() would need its screen inset reconciled here.
    local p = Vector2.new(screenPosition.X, screenPosition.Y)
    local start, size = mainView.root.AbsolutePosition, mainView.root.AbsoluteSize
    return p, start, size
end
local function aimFromPointer(position)
    if not canAim() then return end
    local p, start, size = pointOnBoard(position)
    if size.X < 1 or size.Y < 1 then return end
    local x, y = (p.X - start.X) / size.X * 1000, (p.Y - start.Y) / size.Y * 900
    angle = math.clamp(math.deg(math.atan2(x - 500, math.max(45, y - 55))), -65, 65)
    pendingAim = true
    mainView:setAim(angle, true)
end
mainView.root.InputBegan:Connect(function(input)
    if canAim() and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        dragInput = input
        aimFromPointer(input.Position)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragInput and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement) then aimFromPointer(input.Position) end
end)
UserInputService.InputEnded:Connect(function(input)
    if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then dragInput = nil end
    if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then keyLeft = false end
    if input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then keyRight = false end
end)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.Space then ready()
    elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then keyLeft = true
    elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then keyRight = true end
end)
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()
RunService.RenderStepped:Connect(function(dt)
    if canAim() and (keyLeft or keyRight) then
        angle = math.clamp(angle + ((keyRight and 1 or 0) - (keyLeft and 1 or 0)) * 34 * math.min(dt, 0.05), -65, 65)
        pendingAim = true
        mainView:setAim(angle, true)
    end
    if pendingAim and canAim() and os.clock() - lastAimSent >= 0.1 then
        lastAimSent, pendingAim = os.clock(), false
        send("aim", {angle = angle})
    end
    soundButton.Text, motionButton.Text = muted and "SFX −" or "SFX +", reducedMotion and "FX −" or "FX +"
    if not latest then return end
    local remaining = math.max(0, (latest.phaseEndsAt or 0) - (os.clock() + clockOffset))
    if latest.phase == "Aim" then
        phaseLabel.Text = localEntry and localEntry.ready and "READY" or "AIM"
        timerLabel.Text = remaining > 0 and tostring(math.ceil(remaining)) .. "s" or ""
    elseif latest.phase == "Countdown" then
        phaseLabel.Text = tostring(math.max(1, math.ceil(remaining)))
        timerLabel.Text = "LET'S POP"
    elseif latest.phase == "Shot" then
        phaseLabel.Text = "POP!"
        timerLabel.Text = localEntry and localEntry.shot and localEntry.shot.done and "SHOT COMPLETE" or ""
    else phaseLabel.Text, timerLabel.Text = "RESULT", "" end
    local target = localEntry and localEntry.shot and localEntry.shot.score or 0
    local rivalTarget = rivalEntry and rivalEntry.shot and rivalEntry.shot.score or 0
    local blend = reducedMotion and 1 or 1 - math.exp(-13 * dt)
    shownScore += (target - shownScore) * blend
    shownRivalScore += (rivalTarget - shownRivalScore) * blend
    if math.abs(target - shownScore) < 1 then shownScore = target end
    if math.abs(rivalTarget - shownRivalScore) < 1 then shownRivalScore = rivalTarget end
    myScore.Text, rivalScore.Text = commas(shownScore), commas(shownRivalScore)
    resultScore.Text = commas(shownScore)
    local shot = localEntry and localEntry.shot
    combo.Text = shot and shot.hitCount > 0 and (tostring(shot.hitCount) .. " HITS  ·  " .. tostring(shot.multiplier or 1) .. "×") or ""
    if match.Visible then
        mainView:update(dt, 0)
        youView:update(dt, {phase = latest.phase, ready = localEntry and localEntry.ready,
            result = latest.result})
        opponentView:update(dt, {phase = latest.phase, ready = rivalEntry and rivalEntry.ready,
            result = latest.result})
        if rivalContainer.Visible then rivalView:update(dt, 0) end
    end
    local age = os.clock() - celebrationAt
    for i, bit in ipairs(confetti) do
        bit.Visible = results.Visible and not reducedMotion and age < 2.4
        if bit.Visible then
            local t = age / 2.4
            local x = (i * 0.6180339887) % 1
            bit.Position = UDim2.fromScale(x + math.sin(i * 2.2 + age * 3) * 0.03, -0.08 + t * 1.2)
            bit.Rotation = i * 47 + age * ((i % 2 == 0) and 140 or -100)
            bit.BackgroundTransparency = math.max(0, (t - 0.65) / 0.35)
        end
    end
end)
gui.Destroying:Connect(function()
    youView:destroy(); opponentView:destroy(); audio:destroy()
    if backdropGui.Parent then backdropGui:Destroy() end
end)
send("request")
