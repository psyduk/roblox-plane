-- Presentation only. PegSimulation and the server own every hit and score.
local View = {}
View.__index = View
local C = {
    blue = Color3.fromRGB(33, 197, 255),
    orange = Color3.fromRGB(255, 151, 36),
    green = Color3.fromRGB(122, 255, 87),
    purple = Color3.fromRGB(235, 120, 255),
}
local WHITE = Color3.fromRGB(255, 255, 255)
local CREAM = Color3.fromRGB(255, 249, 224)
local CYAN = Color3.fromRGB(116, 246, 255)
local YELLOW = Color3.fromRGB(255, 217, 64)
local INK = Color3.fromRGB(72, 50, 150)
local function make(class, name, parent, props)
    local obj = Instance.new(class)
    obj.Name = name
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function round(obj, value)
    make("UICorner", "Round", obj, {CornerRadius = UDim.new(value or 1, 0)})
end
local function line(parent, name, color, thickness)
    return make("UIStroke", name, parent, {Color = color, Thickness = thickness or 1, Transparency = 0.25})
end
local function circle(parent, name, x, y, size, color, z)
    local obj = make("Frame", name, parent, {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y),
        Size = UDim2.fromScale(size, size / 0.9), BackgroundColor3 = color,
        BorderSizePixel = 0, ZIndex = z or 2,
    })
    round(obj)
    return obj
end
local function gloss(parent, top, bottom, rotation)
    -- UIGradient multiplies the object's color. White preserves the palette.
    parent.BackgroundColor3 = WHITE
    return make("UIGradient", "CandyGloss", parent, {
        Rotation = rotation or 90, Color = ColorSequence.new(top, bottom),
    })
end
local function hideEffect(fx)
    fx.ring.Visible, fx.label.Visible, fx.flash.Visible = false, false, false
    for _, spark in ipairs(fx.sparks) do spark.Visible = false end
end

function View.new(parent, simulation, mini, eventCallback)
    local self = setmetatable({simulation = simulation, mini = mini, eventCallback = eventCallback,
        pegViews = {}, ballViews = {}, dots = {}, effects = {}, serial = 0, cursor = 0,
        receivedAt = 0, reducedMotion = false, shot = nil, angle = 0}, View)
    self.root = make("Frame", mini and "RivalBoard" or "Board", parent, {
        BackgroundColor3 = WHITE, BorderSizePixel = 0,
        ClipsDescendants = true, Size = UDim2.fromScale(1, 1), Active = not mini,
    })
    round(self.root, 0.035)
    self.border = line(self.root, "CabinetRim", CREAM, mini and 3 or 7)
    self.border.Transparency = 0
    make("UIGradient", "CandySky", self.root, {Rotation = 90, Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 76, 229)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(87, 108, 230)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 172, 224)),
    })})
    local inset = make("Frame", "InnerCabinetRim", self.root, {
        Position = UDim2.fromScale(0.011, 0.012), Size = UDim2.fromScale(0.978, 0.976),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
    })
    round(inset, 0.03)
    line(inset, "CyanTrim", CYAN, mini and 1 or 2.5).Transparency = 0.12
    -- Original native scenery stays behind every physical target. Wide soft
    -- rays and edge clouds add warmth without hiding paths through the board.
    local scenery = make("Frame", "CandySkyScenery", self.root, {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1,
    })
    for i, rotation in ipairs({-55, -28, 0, 28, 55}) do
        local ray = make("Frame", "SunRay" .. i, scenery, {
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.055),
            Size = UDim2.fromScale(0.055, 1.25), Rotation = rotation,
            BackgroundColor3 = CREAM, BackgroundTransparency = 0.955, BorderSizePixel = 0, ZIndex = 1,
        })
        make("UIGradient", "RayFade", ray, {Rotation = 90,
            Transparency = NumberSequence.new(0, 1)})
    end
    for i, cloud in ipairs({{0.065, 0.20, 0.13}, {0.94, 0.11, 0.16}, {0.04, 0.57, 0.14}, {0.96, 0.68, 0.17}}) do
        for j, puff in ipairs({{-0.30, 0.08, 0.62}, {0, -0.11, 0.82}, {0.30, 0.06, 0.56}}) do
            local shape = circle(scenery, "Cloud" .. i .. "Puff" .. j,
                cloud[1] + cloud[3] * puff[1], cloud[2] + cloud[3] * puff[2],
                cloud[3] * puff[3], CREAM, 1)
            shape.BackgroundTransparency = 0.89
        end
    end
    for i, position in ipairs({{0.11, 0.11}, {0.87, 0.30}, {0.17, 0.60}, {0.83, 0.83}, {0.28, 0.09}, {0.67, 0.91}}) do
        local shine = make("Frame", "SkyTwinkle" .. i, scenery, {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(position[1], position[2]),
            Size = UDim2.fromScale(0.008, 0.008 / 0.9), Rotation = 45,
            BackgroundColor3 = CREAM, BackgroundTransparency = 0.40, BorderSizePixel = 0, ZIndex = 1,
        })
        round(shine, 0.15)
    end
    self.pegsLayer = make("Frame", "Targets", self.root, {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3})
    self.previewLayer = make("Frame", "AimGuide", self.root, {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5})
    for i = 1, 28 do
        local dot = circle(self.previewLayer, "Dot" .. i, 0.5, 0.1, 0.009, CREAM, 5)
        dot.BackgroundTransparency = 0.05 + (i / 28) * 0.60
        dot.Visible = false
        self.dots[i] = dot
    end
    local launcherShadow = circle(self.root, "LauncherShadow", 0.5, 62 / 900, 0.091, INK, 6)
    launcherShadow.BackgroundTransparency = 0.35
    local launcherRing = circle(self.root, "LauncherRing", 0.5, 55 / 900, 0.09, YELLOW, 7)
    gloss(launcherRing, Color3.fromRGB(255, 242, 136), Color3.fromRGB(255, 172, 35))
    line(launcherRing, "Rim", CREAM, mini and 1 or 3).Transparency = 0
    self.launcher = circle(self.root, "Launcher", 0.5, 55 / 900, 0.062, YELLOW, 8)
    gloss(self.launcher, CREAM, YELLOW)
    self.barrel = make("Frame", "Barrel", self.launcher, {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.48, 1.05), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 8,
    })
    round(self.barrel, 0.22)
    gloss(self.barrel, CREAM, Color3.fromRGB(255, 194, 44), 0)
    line(self.barrel, "BarrelOutline", Color3.fromRGB(197, 116, 30), mini and 0.5 or 1.3).Transparency = 0.05
    local muzzle = make("Frame", "Muzzle", self.barrel, {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1),
        Size = UDim2.fromScale(1.17, 0.19), BackgroundColor3 = CREAM, BorderSizePixel = 0, ZIndex = 9,
    })
    round(muzzle, 0.24)
    local pivot = circle(self.launcher, "Pivot", 0.5, 0.5, 0.51, WHITE, 10)
    gloss(pivot, WHITE, CYAN)
    line(pivot, "PivotRing", CREAM, 1).Transparency = 0
    self.bucket = make("Frame", "CatchBucket", self.root, {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.96),
        Size = UDim2.fromScale(0.15, 0.034), BackgroundColor3 = WHITE,
        BorderSizePixel = 0, ZIndex = 4,
    })
    round(self.bucket, 0.20)
    gloss(self.bucket, Color3.fromRGB(129, 255, 223), Color3.fromRGB(19, 195, 207))
    line(self.bucket, "BucketRim", CREAM, mini and 1 or 2.5).Transparency = 0
    self.bucketLip = make("Frame", "BucketLip", self.bucket, {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
        Size = UDim2.fromScale(1.04, 0.25), BackgroundColor3 = CREAM, BorderSizePixel = 0, ZIndex = 6,
    })
    round(self.bucketLip, 0.3)
    self.bucketLabel = make("TextLabel", "CatchLabel", self.bucket, {
        BackgroundTransparency = 1, Position = UDim2.fromScale(0.04, 0.17), Size = UDim2.fromScale(0.92, 0.78),
        Text = "CATCH!", TextColor3 = Color3.fromRGB(19, 106, 134), Font = Enum.Font.FredokaOne, TextScaled = true, ZIndex = 6,
    })
    self.effectLayer = make("Frame", "Effects", self.root, {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 11})
    for i = 1, mini and 8 or 30 do
        local ring = circle(self.effectLayer, "Burst" .. i, 0, 0, 0.03, WHITE, 11)
        ring.BackgroundTransparency = 1
        ring.Visible = false
        local stroke = line(ring, "Glow", WHITE, mini and 1 or 2.5)
        local flash = circle(self.effectLayer, "PopFlash" .. i, 0, 0, 0.028, CREAM, 11)
        flash.Visible = false
        local sparks = {}
        for j = 1, mini and 2 or 4 do
            local spark = make("Frame", "Spark" .. i .. "_" .. j, self.effectLayer, {
                AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.008, 0.017 / 0.9),
                BackgroundColor3 = CREAM, BorderSizePixel = 0, ZIndex = 11, Visible = false,
            })
            round(spark, 0.45)
            sparks[j] = spark
        end
        local label = make("TextLabel", "Points", self.effectLayer, {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromScale(0.28, 0.055), TextColor3 = WHITE,
            TextScaled = true, Font = Enum.Font.FredokaOne, ZIndex = 12, Visible = false,
            TextStrokeColor3 = INK, TextStrokeTransparency = 0.35,
        })
        self.effects[i] = {ring = ring, stroke = stroke, label = label, flash = flash, sparks = sparks, untilAt = 0}
    end
    return self
end

function View:setBoard(board, key)
    if self.key == key then return end
    self.key, self.board, self.serial, self.shot = key, board, 0, nil
    self.pegsLayer:ClearAllChildren()
    self.pegViews = {}
    for _, ball in pairs(self.ballViews) do
        ball.body:Destroy()
        for _, trail in ipairs(ball.trails) do trail:Destroy() end
    end
    self.ballViews = {}
    for _, fx in ipairs(self.effects) do hideEffect(fx); fx.untilAt = 0 end
    local width, height = board.width or 1000, board.height or 900
    for _, peg in ipairs(board.pegs) do
        local color = C[peg.kind] or C.blue
        local isBrick = peg.shape == "brick" or peg.shape == "rect" or peg.shape == "rectangle"
        local sizeX = (isBrick and peg.width or (peg.radius or 12) * 2) / width
        local sizeY = (isBrick and peg.height or (peg.radius or 12) * 2) / height
        local special = peg.kind == "green" or peg.kind == "purple"
        local shadow = make("Frame", "PegShadow" .. peg.id, self.pegsLayer, {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(peg.x / width, peg.y / height + 0.0035),
            Size = UDim2.fromScale(sizeX, sizeY), Rotation = peg.rotation or 0,
            BackgroundColor3 = INK, BackgroundTransparency = 0.28, BorderSizePixel = 0, ZIndex = 2,
        })
        round(shadow, isBrick and 0.22 or 1)
        local halo
        if special then
            halo = circle(self.pegsLayer, "SpecialHalo" .. peg.id, peg.x / width, peg.y / height, sizeX * 1.72, color, 2)
            halo.BackgroundTransparency = 0.82
            line(halo, "SpecialAura", color:Lerp(WHITE, 0.35), self.mini and 0.5 or 1).Transparency = 0.45
        end
        local rim = make("Frame", "Peg" .. peg.id, self.pegsLayer, {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(peg.x / width, peg.y / height),
            Size = UDim2.fromScale(sizeX, sizeY), Rotation = peg.rotation or 0,
            BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3,
        })
        round(rim, isBrick and 0.22 or 1)
        local stroke = line(rim, "Edge", color:Lerp(CREAM, special and 0.80 or 0.70), self.mini and 0.65 or (special and 1.9 or 1.25))
        stroke.Transparency = 0
        local gem = make("Frame", "Face", rim, {AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.43), Size = UDim2.fromScale(0.83, 0.79),
            BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 4})
        round(gem, isBrick and 0.2 or 1)
        gloss(gem, color:Lerp(WHITE, 0.68), color)
        local gleam = make("Frame", "SugarShine", rim, {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.34, 0.22),
            Size = UDim2.fromScale(0.30, 0.17), Rotation = -25,
            BackgroundColor3 = WHITE, BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 5,
        })
        round(gleam)
        local symbol
        if special then
            symbol = make("TextLabel", "Symbol", rim, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Text = peg.kind == "green" and "+" or "×", TextColor3 = Color3.fromRGB(74, 46, 129),
                TextScaled = true, Font = Enum.Font.GothamBlack, ZIndex = 5})
        end
        self.pegViews[peg.id] = {root = rim, face = gem, stroke = stroke, color = color,
            shadow = shadow, halo = halo, gleam = gleam, symbol = symbol}
    end
    self:setAim(self.angle, true)
end

function View:setAim(angle, visible)
    self.angle = angle
    self.launcher.Rotation = -angle
    self.previewLayer.Visible = visible and not self.mini
    if not visible or self.mini or not self.board then return end
    local points = self.simulation.preview(self.board, angle)
    for i, dot in ipairs(self.dots) do
        local point = points[i]
        dot.Visible = point ~= nil
        if point then dot.Position = UDim2.fromScale(point.x / 1000, point.y / 900) end
    end
end

local function idMap(ids, fallback)
    if ids then
        local out = {}
        for _, id in ipairs(ids) do out[id] = true end
        return out
    end
    return fallback or {}
end

function View:burst(event)
    if event.kind == "finish" then return end
    self.cursor = self.cursor % #self.effects + 1
    local fx = self.effects[self.cursor]
    fx.start = os.clock()
    fx.duration = event.kind == "power" and 0.65 or 0.42
    fx.untilAt = fx.start + fx.duration
    fx.x, fx.y = (event.x or 500) / 1000, (event.y or 450) / 900
    fx.large = event.kind == "power" or event.kind == "return" or event.kind == "catch"
    local peg = self.pegViews[event.pegId]
    fx.color = event.kind == "power" and C.green or (event.kind == "return" and C.purple or (peg and peg.color or YELLOW))
    fx.ring.Visible = not self.reducedMotion
    fx.stroke.Color = fx.color:Lerp(WHITE, 0.6)
    fx.flash.BackgroundColor3 = CREAM
    for _, spark in ipairs(fx.sparks) do spark.BackgroundColor3 = fx.color:Lerp(WHITE, 0.45) end
    fx.label.Visible = not self.mini and (fx.large or (event.kind == "hit" and event.value ~= nil))
    fx.label.TextColor3 = fx.large and CREAM or fx.color:Lerp(WHITE, 0.8)
    fx.label.Size = UDim2.fromScale(fx.large and 0.48 or 0.085, fx.large and 0.065 or 0.033)
    fx.label.Text = event.text or (event.kind == "hit" and ("+" .. tostring(event.value or 0))
        or event.kind == "catch" and "NICE CATCH!" or event.kind == "return" and "SECOND WIND!" or "POWER POP!")
end

function View:setShot(shot)
    self.shot, self.receivedAt = shot, os.clock()
    if not shot then return end
    local hit, removed = idMap(shot.hitIds, shot.hit), idMap(shot.removedIds, shot.removed)
    for id, peg in pairs(self.pegViews) do
        local touched = hit[id] or hit[tostring(id)]
        local gone = removed[id] or removed[tostring(id)]
        -- Marked pegs remain readable throughout the shot; dim only when removed.
        peg.root.BackgroundColor3 = touched and peg.color:Lerp(WHITE, 0.80) or peg.color
        peg.face.BackgroundTransparency = gone and 0.94 or touched and 0.63 or 0
        peg.root.BackgroundTransparency = gone and 0.90 or 0
        peg.stroke.Color = touched and WHITE or peg.color:Lerp(CREAM, peg.symbol and 0.80 or 0.70)
        peg.stroke.Transparency = gone and 0.92 or 0
        peg.shadow.BackgroundTransparency = gone and 1 or 0.28
        peg.gleam.BackgroundTransparency = gone and 1 or touched and 0.65 or 0.12
        if peg.halo then peg.halo.Visible = not gone end
        if peg.symbol then peg.symbol.TextTransparency = gone and 0.92 or 0 end
    end
    for _, event in ipairs(shot.recentEvents or {}) do
        if (event.serial or 0) > self.serial then
            self.serial = event.serial
            if event.kind ~= "launch" and event.kind ~= "stuck" then self:burst(event) end
            if self.eventCallback then self.eventCallback(event, shot) end
        end
    end
end

function View:setReducedMotion(value)
    self.reducedMotion = value
end

function View:update(dt, aimElapsed)
    if not self.root.Visible then return end
    local now = os.clock()
    local elapsed = self.shot and (self.shot.elapsed or 0) or (aimElapsed or 0)
    self.bucket.Position = UDim2.fromScale(self.simulation.bucketX(elapsed) / 1000, (self.simulation.BUCKET_Y or 860) / 900)
    self.bucket.Size = UDim2.fromScale((self.simulation.BUCKET_WIDTH or 150) / 1000, 0.034)
    local returning = self.shot and self.shot.returnArmed
    self.bucketLip.BackgroundColor3 = returning and C.purple or CREAM
    self.bucketLabel.Text = returning and "RETURN" or "CATCH!"
    local alive = {}
    for _, ball in ipairs(self.shot and self.shot.balls or {}) do
        if ball.alive ~= false then
            alive[ball.id] = true
            local visual = self.ballViews[ball.id]
            if not visual then
                local radius = self.simulation.BALL_RADIUS or 9
                visual = {x = ball.x, y = ball.y, trails = {}, history = {}}
                for i = 1, self.mini and 2 or 5 do
                    local trail = circle(self.root, "Trail" .. ball.id .. "_" .. i, ball.x / 1000, ball.y / 900,
                        radius * 2 / 1000 * (1 - i * 0.1), YELLOW:Lerp(CREAM, i / 5), 7)
                    trail.BackgroundTransparency = 0.27 + i * 0.12
                    table.insert(visual.trails, trail)
                end
                visual.body = circle(self.root, "Ball" .. ball.id, ball.x / 1000, ball.y / 900, radius * 2.15 / 1000, WHITE, 9)
                line(visual.body, "Halo", YELLOW, self.mini and 0.65 or 1.6).Transparency = 0
                self.ballViews[ball.id] = visual
            end
            local prediction = self.shot.done and 0 or math.min(now - self.receivedAt, 0.065)
            local tx, ty = ball.x + (ball.vx or 0) * prediction, ball.y + (ball.vy or 0) * prediction
            local blend = 1 - math.exp(-32 * dt)
            if math.abs(visual.y - ty) > 180 then blend = 1 end -- Portal discontinuity.
            visual.x += (tx - visual.x) * blend
            visual.y += (ty - visual.y) * blend
            visual.body.Visible = true
            visual.body.Position = UDim2.fromScale(visual.x / 1000, visual.y / 900)
            table.insert(visual.history, 1, {x = visual.x, y = visual.y})
            if #visual.history > 16 then table.remove(visual.history) end
            for i, trail in ipairs(visual.trails) do
                local old = visual.history[math.min(#visual.history, i * 2 + 1)]
                trail.Visible = not self.reducedMotion
                trail.Position = UDim2.fromScale(old.x / 1000, old.y / 900)
            end
        end
    end
    for id, visual in pairs(self.ballViews) do
        if not alive[id] then
            visual.body.Visible = false
            for _, trail in ipairs(visual.trails) do trail.Visible = false end
        end
    end
    for _, fx in ipairs(self.effects) do
        if fx.untilAt > now then
            local t = (now - fx.start) / fx.duration
            local eased = 1 - (1 - t) * (1 - t)
            local size = (fx.large and 0.04 or 0.017) + eased * (fx.large and 0.24 or 0.052)
            fx.ring.Visible = not self.reducedMotion
            fx.ring.Position = UDim2.fromScale(fx.x, fx.y)
            fx.ring.Size = UDim2.fromScale(size, size / 0.9)
            fx.stroke.Transparency = t
            fx.flash.Visible = not self.reducedMotion and t < 0.28
            fx.flash.Position = UDim2.fromScale(fx.x, fx.y)
            fx.flash.Size = UDim2.fromScale(fx.large and 0.045 or 0.024, (fx.large and 0.045 or 0.024) / 0.9)
            fx.flash.BackgroundTransparency = math.clamp(t / 0.28, 0, 1)
            for i, spark in ipairs(fx.sparks) do
                local radians = (i / #fx.sparks) * math.pi * 2 + math.pi / 4
                local distance = (fx.large and 0.025 or 0.015) + eased * (fx.large and 0.09 or 0.035)
                spark.Visible = not self.reducedMotion
                spark.Position = UDim2.fromScale(fx.x + math.cos(radians) * distance,
                    fx.y + math.sin(radians) * distance / 0.9)
                spark.Rotation = radians * 180 / math.pi - 90
                spark.BackgroundTransparency = t
            end
            local labelHalf = fx.large and 0.24 or 0.043
            fx.label.Position = UDim2.fromScale(math.clamp(fx.x, labelHalf + 0.025, 1 - labelHalf - 0.025),
                math.clamp(fx.y - (self.reducedMotion and 0.035 or t * 0.065), 0.06, 0.9))
            fx.label.TextTransparency = math.max(0, (t - 0.5) * 2)
            fx.label.TextStrokeTransparency = 0.35 + math.max(0, (t - 0.5) * 1.3)
        else hideEffect(fx) end
    end
end

return View
