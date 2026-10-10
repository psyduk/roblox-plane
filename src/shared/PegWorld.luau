-- Original sky arcade lobby. Matches themselves use a fixed, readable 2D board.
local World = {}
World.LOBBY_SPAWN = Vector3.new(0, 6, 28)

local C = {
    navy=Color3.fromRGB(99,76,206), blue=Color3.fromRGB(72,173,238),
    teal=Color3.fromRGB(87,247,210), orange=Color3.fromRGB(255,214,79),
    cream=Color3.fromRGB(245,241,220), violet=Color3.fromRGB(152,123,246),
}

local function part(parent, name, size, position, color, material)
    local p=Instance.new("Part")
    p.Name=name; p.Size=size; p.Position=position; p.Anchored=true
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    p.Color=color; p.Material=material or Enum.Material.SmoothPlastic
    p.Parent=parent
    return p
end

local function sign(parent, name, text, size, position, color)
    local p=part(parent,name,size,position,C.navy)
    local gui=Instance.new("SurfaceGui"); gui.Face=Enum.NormalId.Back
    gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud; gui.PixelsPerStud=38
    gui.LightInfluence=0; gui.Parent=p
    local label=Instance.new("TextLabel"); label.Size=UDim2.fromScale(1,1)
    label.BackgroundTransparency=1; label.Text=text; label.TextColor3=color or C.cream
    label.Font=Enum.Font.FredokaOne; label.TextScaled=true; label.Parent=gui
    local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0.035,0);pad.PaddingRight=UDim.new(0.035,0)
    pad.PaddingTop=UDim.new(0.12,0);pad.PaddingBottom=UDim.new(0.12,0);pad.Parent=label
    return p
end

local function ball(parent, name, position, radius, color)
    local p=part(parent,name,Vector3.new(radius*2,radius*2,radius*2),position,color)
    p.Shape=Enum.PartType.Ball; p.CanCollide=false
    return p
end

local function cabinet(parent,x,color,title,kind)
    local model=Instance.new("Model");model.Name=kind=="practice" and "PracticeStation" or "DuelStation";model.Parent=parent
    part(model,"Base",Vector3.new(18,1,13),Vector3.new(x,1.1,-8),C.blue)
    part(model,"Cabinet",Vector3.new(15,18,3),Vector3.new(x,10,-13),C.navy)
    part(model,"LeftRail",Vector3.new(.35,17,.4),Vector3.new(x-7.2,10,-11.3),color,Enum.Material.Neon)
    part(model,"RightRail",Vector3.new(.35,17,.4),Vector3.new(x+7.2,10,-11.3),color,Enum.Material.Neon)
    sign(model,"Title",title,Vector3.new(18,3,1),Vector3.new(x,21,-12),color)
    sign(model,"Instruction",kind=="practice" and "PRACTICE WITH A GHOST" or "ONE SHOT. BIG SCORE.",Vector3.new(16,1.5,1),Vector3.new(x,18.5,-11.4),C.cream)
    for row=1,4 do
        for column=1,5 do
            local px=x+(column-3)*2.25+(row%2==0 and .7 or 0)
            ball(model,"DisplayPeg",Vector3.new(px,15-row*2.2,-11.1),.45,(column+row)%4==0 and C.orange or color)
        end
    end
    ball(model,"DisplayBall",Vector3.new(x+1,16,-10.8),.65,C.cream)
    local console=part(model,"PlayConsole",Vector3.new(14,3,4),Vector3.new(x,3.1,-6),C.blue)
    console.CFrame=console.CFrame*CFrame.Angles(math.rad(12),0,0)
    part(model,"Button",Vector3.new(3,.3,2),Vector3.new(x,4.8,-5.4),color,Enum.Material.Neon)
    local prompt=Instance.new("ProximityPrompt");prompt.Name="PlayPrompt";prompt.ActionText=kind=="practice" and "Practice" or "Join duel"
    prompt.ObjectText=title;prompt.HoldDuration=0;prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false
    prompt:SetAttribute("PegCommand",kind);prompt.Parent=console
end

function World.buildLobby()
    local prior=workspace:FindFirstChild("PegLobby")
    if prior then prior:Destroy() end
    local folder=Instance.new("Folder");folder.Name="PegLobby"
    part(folder,"Deck",Vector3.new(112,2,94),Vector3.new(0,-1,10),C.cream)
    part(folder,"ArcadeCarpet",Vector3.new(83,.12,71),Vector3.new(0,.06,7),C.navy)
    for _,x in ipairs({-43,43}) do
        part(folder,"CarpetTrim",Vector3.new(.25,.13,72),Vector3.new(x,.07,7),C.teal,Enum.Material.Neon)
    end
    for _,x in ipairs({-54,54}) do
        part(folder,"SafetyRail",Vector3.new(1,5,94),Vector3.new(x,2,10),C.blue)
        part(folder,"RailGlow",Vector3.new(1.1,.15,94),Vector3.new(x,4.55,10),C.teal,Enum.Material.Neon)
    end
    for _,z in ipairs({-36,56}) do
        part(folder,"SafetyRail",Vector3.new(108,5,1),Vector3.new(0,2,z),C.blue)
    end
    sign(folder,"Marquee","POP DUEL",Vector3.new(62,9,2),Vector3.new(0,29,-29),C.cream)
    sign(folder,"Arcade","P O P   D U E L   A R C A D E",Vector3.new(47,2.4,1),Vector3.new(0,36,-29),C.teal)
    sign(folder,"Tagline","AIM  •  BOUNCE  •  OUTSCORE",Vector3.new(44,2.4,1),Vector3.new(0,22,-29),C.orange)
    for _,x in ipairs({-35,35}) do
        part(folder,"ArchPillar",Vector3.new(2,35,2),Vector3.new(x,17,-29),C.blue)
        ball(folder,"MarqueeOrb",Vector3.new(x,36,-29),2.3,x<0 and C.teal or C.orange)
    end
    cabinet(folder,-20,C.teal,"PLAY DUEL","join")
    cabinet(folder,20,C.orange,"PRACTICE","practice")
    for n=1,5 do
        part(folder,"PathDot",Vector3.new(1.2,.12,1.2),Vector3.new(0,.14,35-n*5),C.orange,Enum.Material.Neon)
    end
    local spawn=Instance.new("SpawnLocation");spawn.Name="ArcadeSpawn";spawn.Size=Vector3.new(7,.2,7)
    spawn.Position=Vector3.new(0,.2,28);spawn.Anchored=true;spawn.Transparency=1;spawn.CanCollide=false
    spawn.Neutral=true;spawn.Duration=0;spawn.Parent=folder
    -- A small original constellation sculpture gives the room a visible focal point.
    for i=1,7 do
        local t=i*math.pi/4
        ball(folder,"OrbitPeg",Vector3.new(math.cos(t)*15,29+math.sin(t)*6,-30),.55,i%2==0 and C.orange or C.teal)
    end
    folder.Parent=workspace
    local lighting=game:GetService("Lighting")
    lighting.ClockTime=14;lighting.Brightness=2
    lighting.Ambient=Color3.fromRGB(120,140,172);lighting.OutdoorAmbient=Color3.fromRGB(145,163,188)
    lighting.FogStart=300;lighting.FogEnd=1800;lighting.FogColor=Color3.fromRGB(170,218,248)
    workspace:SetAttribute("PegGameVersion","pop-duel-v1")
    return folder
end

return World
