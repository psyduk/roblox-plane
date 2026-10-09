local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local localPlayer = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("FlightGame")
local Simulation = require(shared:WaitForChild("Simulation"))
local PlaneCatalog = require(shared:WaitForChild("PlaneCatalog"))
local World = require(shared:WaitForChild("World"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local FlightAudio = require(script.Parent:WaitForChild("FlightAudio"))
local PilotAvatar = require(script.Parent:WaitForChild("PilotAvatar"))
local audio = FlightAudio.new()
local command = shared:WaitForChild("Command")
local snapshots = shared:WaitForChild("Snapshot")
local localSettings = {planeId=PlaneCatalog.DEFAULT_ID,angle=35,gadget="Shield",color=1}
local latest = nil
local receivedAt = 0
local watchedUserId = localPlayer.UserId
local lobbyView = true
local renderedCourse = nil
local courseKey = ""
local planes = {}
local planeLabels = {}
local smooth = {}
local previewPlane = nil
local aimTrajectory = {}
local aimTrajectoryKey = ""
local lastPhase = ""
local lastRound = ""
local cameraPosition = nil
local selfCrashedAt = nil
local hud = nil
local characterControls = nil
local controlsEnabled = nil
local lobbyCameraReset = true
local restoreZoomAt = 0
local worldFolder = Instance.new("Folder")
worldFolder.Name = "FlightClientVisuals"
worldFolder.Parent = workspace

task.spawn(function()
    local playerModule = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule",10)
    if playerModule then
        local ok, controls = pcall(function() return require(playerModule):GetControls() end)
        if ok then characterControls=controls end
    end
end)

local function send(kind, values)
    local payload=values or {}
    payload.kind=kind
    command:FireServer(payload)
end
local function cycleSpectate(delta)
    if not latest then return end
    local choices={}
    for _,p in ipairs(latest.players) do if p.flight then table.insert(choices,p.userId) end end
    if #choices==0 then return end
    local index=table.find(choices,watchedUserId) or 1
    watchedUserId=choices[(index-1+delta)%#choices+1]
    selfCrashedAt=nil
    cameraPosition=nil
end
hud=Hud.new({
    vote=function(variant) send("vote",{variant=variant}) end,
    configure=function(settings) localSettings=table.clone(settings); send("configure",{settings=settings}) end,
    ready=function(ready) send("ready",{ready=ready,settings=hud:getLocalSettings()}) end,
    spectate=cycleSpectate,
    practice=function() send("practice") end,
    leaveQueue=function() send("leaveQueue") end,
    returnLobby=function() send("returnLobby") end,
    rematch=function() send("rematch") end,
    lobby=function() send("returnLobby") end,
    mute=function(muted) audio:setMuted(muted) end,
})
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end)

local function clearPlanes()
    for _,model in pairs(planes) do model:Destroy() end
    for _,label in pairs(planeLabels) do label:Destroy() end
    planeLabels={}
    planes={}; smooth={}
    if previewPlane then previewPlane:Destroy(); previewPlane=nil end
end
local function getEntry(id)
    if latest then
        for _,p in ipairs(latest.players) do if p.userId==id then return p end end
    end
    return nil
end

snapshots.OnClientEvent:Connect(function(data)
    if type(data)~="table" or type(data.players)~="table" then return end
    local roundKey=tostring(data.matchId)..":"..tostring(data.roundId)
    local changedRound = lastRound~=roundKey
    local changedPhase = lastPhase~=data.phase
    if changedRound then clearPlanes(); lastRound=roundKey; watchedUserId=localPlayer.UserId; cameraPosition=nil end
    for _,p in ipairs(data.players) do
        if p.flight then
            p.flight.used={}
            for _,id in ipairs(p.flight.usedIds or {}) do p.flight.used[id]=true end
        end
    end
    latest=data
    lobbyView=data.phase=="Lobby" or data.phase=="Queued"
    if lobbyView and changedPhase and lastPhase~="Lobby" and lastPhase~="Queued" then lobbyCameraReset=true end
    receivedAt=os.clock()
    local own=getEntry(localPlayer.UserId)
    if changedPhase and own then localSettings=table.clone(own.settings) end
    if data.phase=="Flight" and changedPhase then
        lobbyView=false
        cameraPosition=nil
        watchedUserId=localPlayer.UserId
        selfCrashedAt=nil
        if previewPlane then previewPlane:Destroy(); previewPlane=nil end
    end
    local key=tostring(data.courseSeed)..data.courseName
    if key~=courseKey and not lobbyView then
        if renderedCourse then World.destroyCourse(renderedCourse) end
        renderedCourse=World.buildCourse(Simulation.makeCourse(data.courseSeed,data.courseName))
        World.setArenaTheme(data.courseName)
        courseKey=key
    end
    if lobbyView then
        if changedPhase then World.resetTheme() end
        clearPlanes()
        if renderedCourse then World.destroyCourse(renderedCourse); renderedCourse=nil; courseKey="" end
    end
    lastPhase=data.phase
    localPlayer:SetAttribute("SkyboundPhase",data.phase)
    localPlayer:SetAttribute("SkyboundRound",data.roundId)
    localPlayer:SetAttribute("SkyboundMatch",data.matchId)
    if own and own.flight then
        localPlayer:SetAttribute("SkyboundDistance",own.flight.distance)
        localPlayer:SetAttribute("SkyboundAlive",own.flight.alive)
    end
end)

local function adjust(key, amount, low, high)
    if not latest or latest.phase~="Aim" then return end
    local current = hud.getLocalSettings and hud:getLocalSettings() or table.clone(localSettings)
    current[key]=math.clamp(current[key]+amount,low,high)
    localSettings=current
    if hud.setLocalSettings then hud:setLocalSettings(current) else send("configure",{settings=current}) end
end
UserInputService.InputBegan:Connect(function(input,processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.R or input.KeyCode==Enum.KeyCode.ButtonY then
        if latest and (latest.phase=="Configure" or latest.phase=="Aim") then
            if hud.toggleReady then hud:toggleReady()
            else local own=getEntry(localPlayer.UserId); send("ready",{ready=not (own and own.ready),settings=localSettings}) end
        end
    elseif input.KeyCode==Enum.KeyCode.A then adjust("angle",-5,15,60)
    elseif input.KeyCode==Enum.KeyCode.D then adjust("angle",5,15,60)
    elseif input.KeyCode==Enum.KeyCode.Q or input.KeyCode==Enum.KeyCode.ButtonL1 then cycleSpectate(-1)
    elseif input.KeyCode==Enum.KeyCode.E or input.KeyCode==Enum.KeyCode.ButtonR1 then cycleSpectate(1)
    end
end)

RunService:BindToRenderStep("SkyboundFlightView",Enum.RenderPriority.Camera.Value+1,function(dt)
    local camera=workspace.CurrentCamera
    if not latest or not camera then return end
    local phase=latest.phase
    -- Roblox may re-enable avatar controls when a character finishes spawning.
    if characterControls and (controlsEnabled~=lobbyView or characterControls.controlsEnabled~=lobbyView) then
        controlsEnabled=lobbyView
        if lobbyView then characterControls:Enable() else characterControls:Disable() end
        localPlayer:SetAttribute("SkyboundLobbyControls",characterControls.controlsEnabled)
    end
    local active=phase=="Flight" or phase=="Results"
    local target=getEntry(watchedUserId)
    if active and (not target or not target.flight) then
        for _,p in ipairs(latest.players) do if p.flight then watchedUserId=p.userId; target=p; break end end
    end
    local own=getEntry(localPlayer.UserId)
    if phase=="Flight" and watchedUserId==localPlayer.UserId and own and own.flight and not own.flight.alive then
        selfCrashedAt=selfCrashedAt or os.clock()
        if os.clock()-selfCrashedAt>2 then
            local leader=nil
            for _,p in ipairs(latest.players) do
                if p.flight and p.flight.alive and (not leader or p.flight.distance>leader.flight.distance) then leader=p end
            end
            if leader then watchedUserId=leader.userId; target=leader; cameraPosition=nil end
        end
    end
    local renderTime=(latest.elapsed or 0)+(phase=="Flight" and math.min(os.clock()-receivedAt,0.15) or 0)
    if active then
        local present={}
        for index,p in ipairs(latest.players) do
            if p.flight then
                present[p.userId]=true
                if not planes[p.userId] then
                    local model=World.createPlane(worldFolder,p.name,p.settings.color,p.settings.planeId)
                    PilotAvatar.attach(model,p.userId,p.bot)
                    planes[p.userId]=model
                    local text=Instance.new("TextLabel")
                    text.Name="PilotIdentity"; text.Size=UDim2.fromOffset(80,20)
                    text.AnchorPoint=Vector2.new(0.5,0); text.BackgroundTransparency=1; text.ZIndex=3
                    text.Text=p.userId==localPlayer.UserId and "YOU" or (p.bot and "GHOST" or "RIVAL")
                    text.TextColor3=p.userId==localPlayer.UserId and Color3.fromRGB(255,225,112) or Color3.new(1,1,1)
                    text.TextStrokeTransparency=0.1; text.TextStrokeColor3=Color3.fromRGB(23,39,77)
                    text.TextSize=12; text.Font=Enum.Font.FredokaOne
                    text.Parent=localPlayer.PlayerGui:FindFirstChild("SkyboundHUD")
                    planeLabels[p.userId]=text
                end
                local f=p.flight
                local extrap=f.alive and math.min(os.clock()-receivedAt,0.15) or 0
                local wantX=f.x+f.vx*extrap
                local wantY=math.max(0,f.y+f.vy*extrap)
                local s=smooth[p.userId] or {x=wantX,y=wantY}
                local alpha=1-math.exp(-dt*18)
                s.x+=(wantX-s.x)*alpha; s.y+=(wantY-s.y)*alpha
                smooth[p.userId]=s
                local visual=table.clone(f); visual.x=s.x; visual.y=s.y; visual.elapsed=renderTime
                -- Cosmetic lanes only. All planes use the exact same 2D simulation course.
                World.updatePlane(planes[p.userId],visual,(index-1)*20-10,dt)
            end
        end
        for id,model in pairs(planes) do
            if not present[id] then
                model:Destroy(); planes[id]=nil; smooth[id]=nil
                if planeLabels[id] then planeLabels[id]:Destroy(); planeLabels[id]=nil end
            end
        end
    elseif phase=="Configure" or phase=="Aim" or phase=="Countdown" or phase=="Voting" then
        localSettings=hud:getLocalSettings()
        if not previewPlane or previewPlane:GetAttribute("PreviewColor")~=localSettings.color
            or previewPlane:GetAttribute("PreviewPlaneId")~=localSettings.planeId then
            if previewPlane then previewPlane:Destroy() end
            previewPlane=World.createPlane(worldFolder,localPlayer.DisplayName,localSettings.color,localSettings.planeId)
            previewPlane:SetAttribute("PreviewColor",localSettings.color)
            previewPlane:SetAttribute("PreviewPlaneId",localSettings.planeId)
            PilotAvatar.attach(previewPlane,localPlayer.UserId,false)
        end
        local profile=PlaneCatalog.get(localSettings.planeId) or PlaneCatalog.get(PlaneCatalog.DEFAULT_ID)
        local angle=math.rad(localSettings.angle or profile.angle)
        World.updatePlane(previewPlane,{x=0,y=18,vx=math.cos(angle)*profile.speed,vy=math.sin(angle)*profile.speed,elapsed=renderTime,alive=true},0,dt)
        if phase=="Aim" or phase=="Countdown" then
            local key=localSettings.planeId..":"..tostring(localSettings.angle)..":"..localSettings.gadget
            if key~=aimTrajectoryKey then
                aimTrajectory=Simulation.previewTrajectory(localSettings,2.5)
                aimTrajectoryKey=key
            end
        end
    end
    if renderedCourse then World.updateCourse(renderedCourse,target and target.flight or nil,renderTime) end
    if lobbyView then
        camera.CameraType=Enum.CameraType.Custom
        camera.FieldOfView=70
        local character=localPlayer.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then camera.CameraSubject=humanoid end
        if lobbyCameraReset and character and character:FindFirstChild("HumanoidRootPart") then
            local focus=character.HumanoidRootPart.Position+Vector3.new(0,2,0)
            localPlayer.CameraMinZoomDistance=32
            localPlayer.CameraMaxZoomDistance=70
            camera.CFrame=CFrame.lookAt(focus+Vector3.new(16,18,24),focus)
            camera.Focus=CFrame.new(focus)
            lobbyCameraReset=false; restoreZoomAt=os.clock()+0.2
        elseif restoreZoomAt>0 and os.clock()>=restoreZoomAt then
            localPlayer.CameraMinZoomDistance=8; restoreZoomAt=0
        end
    elseif phase=="Aim" or phase=="Countdown" then
        -- A fixed side-on aiming frame keeps pointer movement independent of
        -- camera movement. Match HUD's clear field between its header/footer.
        local viewport=camera.ViewportSize
        local topInset,bottomInset=GuiService:GetGuiInset()
        local guiHeight=math.max(1,viewport.Y-topInset.Y-bottomInset.Y)
        local landscape=viewport.X>=680 and guiHeight<470
        local fieldTop=landscape and (guiHeight<330 and 54 or 62) or 81
        local footerHeight=viewport.X<560 and 98 or 64
        local fieldBottom=guiHeight-28-footerHeight-10
        local fieldHeight=math.max(42,fieldBottom-fieldTop)
        local targetX=viewport.X*0.30
        local targetY=fieldTop+fieldHeight*0.60+topInset.Y
        -- Fit the whole tilted jet and its pilot; long guide points are clipped
        -- by HUD at the field edges instead of changing zoom with launch angle.
        local worldWidth=viewport.X<560 and 180 or 220
        local pixelsPerStud=math.max(0.1,math.min(viewport.X/worldWidth,fieldHeight/42))
        local visibleHeight=viewport.Y/pixelsPerStud
        local focus=World.COURSE_ORIGIN+Vector3.new(
            (viewport.X*0.5-targetX)/pixelsPerStud,
            18+(targetY-viewport.Y*0.5)/pixelsPerStud,
            0)
        camera.CameraType=Enum.CameraType.Scriptable
        camera.FieldOfView=50
        cameraPosition=focus+Vector3.new(0,0,visibleHeight/(2*math.tan(math.rad(25))))
        camera.CFrame=CFrame.lookAt(cameraPosition,cameraPosition-Vector3.new(0,0,1))
        camera.Focus=CFrame.new(focus)
    else
        camera.CameraType=Enum.CameraType.Scriptable
        local focus
        -- Keep ground and the staggered pickup field in view. Looking ahead makes
        -- upcoming choices readable without shrinking the plane every time it climbs.
        local aspect=camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y)
        local shortScreen=camera.ViewportSize.Y<450
        local fieldOfView=shortScreen and 85 or 70
        camera.FieldOfView=fieldOfView
        local visibleHeight=shortScreen and 300 or 260
        local centerHeight=shortScreen and 125 or 105
        local visibleWidth=visibleHeight*aspect
        local ahead=math.min(145,visibleWidth*0.21)
        if active and target and target.flight then
            local s=smooth[target.userId] or target.flight
            -- Follow a high climb gently so the aircraft stays below the HUD.
            -- The ground returns into view as soon as the plane descends.
            local viewCenterHeight=math.max(centerHeight,s.y+(shortScreen and 5 or -20))
            focus=World.COURSE_ORIGIN+Vector3.new(s.x+ahead,viewCenterHeight,0)
        else
            focus=World.COURSE_ORIGIN+Vector3.new(ahead,centerHeight,0)
        end
        local desired=focus+Vector3.new(0,0,visibleHeight/(2*math.tan(math.rad(fieldOfView/2))))
        cameraPosition=cameraPosition and cameraPosition:Lerp(desired,1-math.exp(-dt*6)) or desired
        camera.CFrame=CFrame.lookAt(cameraPosition,cameraPosition-Vector3.new(0,0,1))
        camera.Focus=CFrame.new(focus)
    end
    latest.viewingLobby=lobbyView
    local inset=GuiService:GetGuiInset()
    local previousPoint=nil
    for _,p in ipairs(latest.players) do
        local model,label=planes[p.userId],planeLabels[p.userId]
        if model and label then
            local point,visible=camera:WorldToViewportPoint(model:GetPivot().Position-Vector3.new(0,12,0))
            local y=point.Y-inset.Y
            if previousPoint and math.abs(point.X-previousPoint.X)<65 and math.abs(y-previousPoint.Y)<20 then y-=20 end
            label.Position=UDim2.fromOffset(point.X,y)
            label.Visible=phase=="Flight" and visible
            previousPoint=Vector2.new(point.X,y)
        end
    end
    if hud.setLobbyView then hud:setLobbyView(lobbyView) end
    hud:update(latest,localPlayer.UserId,watchedUserId)
    if (phase=="Aim" or phase=="Countdown") and previewPlane then
        local origin,visible=camera:WorldToViewportPoint(previewPlane:GetPivot().Position)
        local points=table.create(#aimTrajectory)
        for index,point in ipairs(aimTrajectory) do
            local projected=camera:WorldToViewportPoint(World.COURSE_ORIGIN+Vector3.new(point.x,point.y,0))
            points[index]=Vector2.new(projected.X-inset.X,projected.Y-inset.Y)
        end
        hud:updateAimProjection(Vector2.new(origin.X-inset.X,origin.Y-inset.Y),points,visible)
    else
        hud:updateAimProjection(Vector2.zero,{},false)
    end
    audio:update(latest.players,lastRound,watchedUserId,phase=="Flight" or phase=="Results")
    local watchedModel=planes[watchedUserId]
    if phase=="Flight" and watchedModel and target and target.flight then
        local point, visible=camera:WorldToViewportPoint(watchedModel:GetPivot().Position)
        hud:updateFlightFeedback(target.flight,Vector2.new(point.X,point.Y-inset.Y),visible,renderTime)
    else
        hud:updateFlightFeedback(nil,Vector2.zero,false,renderTime)
    end
end)

send("request")
task.delay(2,function() if not latest then send("request") end end)
print("SKYBOUND_CLIENT_READY")
