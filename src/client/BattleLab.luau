-- A deliberately small control surface for the first combat playtest.
local Players=game:GetService("Players")
local GuiService=game:GetService("GuiService")
local BattleView=require(script.Parent:WaitForChild("BattleView"))
local BattleAudio=require(script.Parent:WaitForChild("BattleAudio"))
local PilotAvatar=require(script.Parent:WaitForChild("PilotAvatar"))
local BattleLab={}
BattleLab.__index=BattleLab
local NAVY=Color3.fromRGB(18,31,51)
local WHITE=Color3.fromRGB(255,245,221)
local MUTED=Color3.fromRGB(172,191,210)
local ACCENTS={Color3.fromRGB(255,113,111),Color3.fromRGB(70,221,234)}
local DESCRIPTIONS={Meteor="Pull up, charge, then slam into a dive.",Firework="Launch a slow rocket on each attack pass."}
local function make(class,parent,name)
    local item=Instance.new(class); item.Name=name; item.Parent=parent; return item
end
local function surface(item,color,thickness)
    local stroke=make("UIStroke",item,"Edge")
    stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    stroke.Color=color; stroke.Thickness=thickness or 1; stroke.Transparency=0.6
    local gradient=make("UIGradient",item,"Shading")
    gradient.Rotation=90
    gradient.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(185,199,220))
    return stroke
end
local function label(parent,name,size,color)
    local item=make("TextLabel",parent,name)
    item.BackgroundTransparency=1; item.TextColor3=color or WHITE
    item.TextSize=size; item.Font=Enum.Font.GothamBold
    item.TextWrapped=true; item.Text=""
    return item
end
local function button(parent,name,text,callback)
    local item=make("TextButton",parent,name)
    item.BackgroundColor3=Color3.fromRGB(44,63,86); item.BorderSizePixel=0
    item.TextColor3=WHITE; item.Font=Enum.Font.GothamBold; item.TextSize=16; item.Text=text
    item.AutoButtonColor=true; item.Selectable=true
    make("UICorner",item,"Corner").CornerRadius=UDim.new(0,10)
    surface(item,Color3.fromRGB(132,169,201),1)
    item.Activated:Connect(callback)
    return item
end
local function place(item,x,y,w,h)
    item.Position=UDim2.fromOffset(x,y); item.Size=UDim2.fromOffset(w,h)
end
function BattleLab.new(World,shared)
    local self=setmetatable({World=World,active=false,data=nil,settings={},cards={},armorBars={},scorePlates={},outbox={},sending=false,lastSend=-math.huge},BattleLab)
    self.modifiers=require(shared:WaitForChild("BattleModifiers"))
    self.audio=BattleAudio.new()
    self.showAngles=false
    self.command=shared:WaitForChild("BattleCommand")
    self.gui=make("ScreenGui",Players.LocalPlayer:WaitForChild("PlayerGui"),"SkyboundBattleLab")
    self.gui.ResetOnSpawn=false; self.gui.DisplayOrder=30; self.gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    self.root=make("Frame",self.gui,"Root"); self.root.Size=UDim2.fromScale(1,1); self.root.BackgroundTransparency=1
    self.panel=make("Frame",self.root,"Lab"); self.panel.Size=UDim2.fromScale(1,1); self.panel.BackgroundTransparency=1; self.panel.Visible=false
    self.header=make("Frame",self.panel,"Header"); self.header.BackgroundColor3=NAVY; self.header.BorderSizePixel=0
    surface(self.header,Color3.fromRGB(67,111,147),1)
    self.title=label(self.header,"Title",20); self.title.Text="SKYBOUND CLASH"
    self.subtitle=label(self.header,"Subtitle",12,MUTED); self.subtitle.Text="BATTLE LAB · SIMULATED OPPONENT"
    self.exit=button(self.header,"Exit","Hangar",function() self:send("exit") end)
    self.mute=button(self.header,"Mute","Sound ON",function()
        local p=Players.LocalPlayer
        p:SetAttribute("SkyboundSoundMuted",p:GetAttribute("SkyboundSoundMuted")~=true)
    end)
    self.mute.TextSize=12
    self.status=label(self.panel,"Status",22)
    self.status.BackgroundColor3=Color3.fromRGB(31,49,69); self.status.BackgroundTransparency=0.08
    make("UICorner",self.status,"Corner").CornerRadius=UDim.new(0,10)
    self.statusEdge=surface(self.status,Color3.fromRGB(118,154,187),1)
    self.help=label(self.panel,"Help",14,MUTED)
    self.footer=make("Frame",self.panel,"Controls"); self.footer.BackgroundColor3=NAVY; self.footer.BorderSizePixel=0
    surface(self.footer,Color3.fromRGB(67,111,147),1)
    self.footer.AnchorPoint=Vector2.new(0,1)
    for index=1,2 do
        local i=index
        local card={}
        card.frame=make("Frame",self.footer,"Pilot"..i); card.frame.BackgroundTransparency=1
        card.role=label(card.frame,"Role",12,ACCENTS[i]); card.role.Text=i==1 and "YOUR PLANE" or "SIMULATED OPPONENT"
        card.power=button(card.frame,"Power","",function()
            if not self.data or self.data.phase~="Configure" then return end
            self.settings[i].powerId=self.settings[i].powerId=="Meteor" and "Firework" or "Meteor"
            self:send("configure",{settings=self.settings})
        end)
        card.description=label(card.frame,"Description",13,MUTED)
        card.modifier=button(card.frame,"Modifier","",function() self:cycleModifier(i) end)
        card.modifierDescription=label(card.frame,"ModifierDescription",13,MUTED)
        card.angle=label(card.frame,"Angle",14)
        card.minus=button(card.frame,"LowerAngle","−",function() self:angle(i,-5) end)
        card.plus=button(card.frame,"RaiseAngle","+",function() self:angle(i,5) end)
        self.cards[i]=card
        local plate=make("Frame",self.header,"ScorePlate"..i)
        plate.BackgroundColor3=NAVY:Lerp(ACCENTS[i],0.14); plate.BorderSizePixel=0
        make("UICorner",plate,"Corner").CornerRadius=UDim.new(0,8)
        surface(plate,ACCENTS[i],1)
        self.scorePlates[i]=plate
        local score=label(plate,"Score"..i,16,ACCENTS[i]); self["score"..i]=score
        self.armorBars[i]={}
        for pip=1,3 do
            local bar=make("Frame",plate,"Armor"..pip); bar.BorderSizePixel=0; bar.BackgroundColor3=ACCENTS[i]
            make("UICorner",bar,"Corner").CornerRadius=UDim.new(0,3)
            self.armorBars[i][pip]=bar
        end
    end
    self.angleToggle=button(self.footer,"Angles","Angles",function() self.showAngles=not self.showAngles end)
    self.launch=button(self.footer,"Launch","Launch battle",function() self:send("launch",{settings=self.settings}) end)
    self.launch.BackgroundColor3=Color3.fromRGB(224,81,64)
    self.launch.Edge.Color=Color3.fromRGB(255,207,117); self.launch.Edge.Transparency=0.2
    self.replay=button(self.footer,"Replay","Run it again",function() self:send("restart") end)
    self.replay.BackgroundColor3=Color3.fromRGB(224,81,64)
    self.edit=button(self.footer,"Edit","Change setup",function() self:send("restart",{edit=true}) end)
    self.footerHint=label(self.footer,"Hint",13,MUTED)
    -- Full-screen beats: a white impact flash and the 3-2-1-FIGHT call.
    self.flash=make("Frame",self.panel,"ImpactFlash")
    self.flash.Size=UDim2.fromScale(1,1); self.flash.BorderSizePixel=0; self.flash.Active=false
    self.flash.BackgroundColor3=Color3.new(1,1,1); self.flash.BackgroundTransparency=1; self.flash.ZIndex=40
    self.count=label(self.panel,"Countdown",150,Color3.fromRGB(255,221,87))
    self.count.Font=Enum.Font.FredokaOne; self.count.TextWrapped=false; self.count.ZIndex=41
    self.count.AnchorPoint=Vector2.new(0.5,0.5); self.count.Size=UDim2.fromOffset(900,220); self.count.Visible=false
    local countEdge=make("UIStroke",self.count,"Edge"); countEdge.Thickness=8; countEdge.Color=NAVY
    self.countScale=make("UIScale",self.count,"Pop")
    shared:WaitForChild("BattleSnapshot").OnClientEvent:Connect(function(data)
        if type(data)~="table" then return end
        local wasActive=self.active
        local previousPhase=self.data and self.data.phase
        self.active=data.active==true; self.data=data
        if self.active then
            -- This pilot owns setup edits. Older periodic snapshots must not
            -- roll back a tap that is still travelling to the server.
            if not wasActive or data.phase~="Configure" or previousPhase~="Configure" then
            self.settings={{powerId=data.settings[1].powerId,angle=data.settings[1].angle,modifierId=data.settings[1].modifierId or "None"},
                {powerId=data.settings[2].powerId,angle=data.settings[2].angle,modifierId=data.settings[2].modifierId or "None"}}
            end
            if not self.view then
                self.view=BattleView.new(World,function(cue)
                    if cue.kind=="crash" then self.audio:playCrash(cue.roundId,cue.actor) end
                end,{pilots=PilotAvatar})
            end
        elseif self.view then self.view:destroy(); self.view=nil end
        self.panel.Visible=self.active
        Players.LocalPlayer:SetAttribute("BattleLabPhase",self.active and data.phase or "Inactive")
    end)
    self:send("request")
    return self
end
function BattleLab:send(kind,payload)
    payload=payload or {}; payload.kind=kind
    if payload.settings then
        payload.settings={{powerId=payload.settings[1].powerId,angle=payload.settings[1].angle,modifierId=payload.settings[1].modifierId},
            {powerId=payload.settings[2].powerId,angle=payload.settings[2].angle,modifierId=payload.settings[2].modifierId}}
    end
    -- Queue button intents in order, including configuration before launch.
    -- Coalesce rapid setup taps and stay below the server's shared rate limit.
    local last=self.outbox[#self.outbox]
    if last and last.kind=="configure" and kind=="configure" then self.outbox[#self.outbox]=payload
    else table.insert(self.outbox,payload) end
    if self.sending then return end
    self.sending=true
    task.spawn(function()
        while #self.outbox>0 do
            local delay=0.08-(os.clock()-self.lastSend)
            if delay>0 then task.wait(delay) end
            local nextPayload=table.remove(self.outbox,1)
            self.command:FireServer(nextPayload); self.lastSend=os.clock()
        end
        self.sending=false
    end)
end
function BattleLab:isActive() return self.active end
function BattleLab:angle(index,delta)
    if not self.data or self.data.phase~="Configure" then return end
    self.settings[index].angle=math.clamp(self.settings[index].angle+delta,10,55)
    self:send("configure",{settings=self.settings})
end
function BattleLab:cycleModifier(index)
    if not self.data or self.data.phase~="Configure" then return end
    local choices=self.modifiers.all()
    local current=1
    for i,value in ipairs(choices) do if value.id==self.settings[index].modifierId then current=i end end
    self.settings[index].modifierId=choices[current%#choices+1].id
    self:send("configure",{settings=self.settings})
end
function BattleLab:feedback(data)
    local sim=data.simulation
    if self.feedbackRound~=data.roundId then
        self.feedbackRound=data.roundId; self.eventSerial=0; self.feedbackUntil=0; self.lastHit=nil; self.hitTimes={}
    end
    if data.phase=="Configure" or data.phase=="Countdown" then return end
    for _,event in ipairs(sim.events or {}) do
        if event.serial>(self.eventSerial or 0) then
            self.eventSerial=event.serial
            local recent=sim.elapsed-(event.at or 0)<0.75
            if event.kind=="hit" or event.kind=="wake_hit" then
                local attack=event.source=="meteor" and "METEOR SLAM" or (event.source=="wake" and "FIZZY WAKE HIT" or "ROCKET HIT")
                local victim=event.target==1 and "YOUR PLANE" or "SIM PLANE"
                self.lastHit={target=event.target,source=attack}
                if recent then
                    self.feedbackText=attack.." · "..victim.." −1"; self.feedbackUntil=os.clock()+0.7
                    self.hitTimes[event.target]=os.clock()
                end
            elseif event.kind=="blocked" and recent then
                self.feedbackText=(event.actor==1 and "YOUR BUMPER" or "SIM BUMPER").." SAVED A HIT!"
                self.feedbackUntil=os.clock()+0.8
            end
        end
    end
end
function BattleLab:update(dt)
    local width,height=self.root.AbsoluteSize.X,self.root.AbsoluteSize.Y
    local muted=Players.LocalPlayer:GetAttribute("SkyboundSoundMuted")==true
    if self.muted~=muted then self.audio:setMuted(muted); self.muted=muted end
    self.audio:update(self.data or {active=false})
    if not self.active or not self.data or not self.view then return end
    local data=self.data
    -- The HUD wears the same paint as the two planes.
    local accents={self.view:accent(1),self.view:accent(2)}
    local config=data.phase=="Configure"
    local results=data.phase=="Results"
    local compact=width<600
    local short=height<500
    local headerHeight=short and 82 or 94
    local plainFight=data.phase=="Fight" and (data.settings[1].modifierId or "None")=="None"
        and (data.settings[2].modifierId or "None")=="None"
    local footerHeight=config and (short and (compact and 146 or 112) or (self.showAngles and 282 or 240)) or (results and 108 or (plainFight and 0 or 54))
    self.footer.Visible=not plainFight
    place(self.header,0,0,width,headerHeight)
    place(self.title,12,4,width-184,26); self.title.TextXAlignment=Enum.TextXAlignment.Left
    self.title.TextSize=compact and 16 or 22
    self.title.Text=short and "LAB · SIMULATED OPPONENT" or "SKYBOUND CLASH"
    if short then self.title.TextSize=compact and 11 or 16 end
    place(self.subtitle,12,30,width-184,18); self.subtitle.TextXAlignment=Enum.TextXAlignment.Left
    self.subtitle.TextSize=compact and 9 or 12
    self.subtitle.Visible=not short
    place(self.exit,width-96,5,84,40)
    place(self.mute,width-166,5,64,40); self.mute.Text=muted and "Sound OFF" or "Sound ON"; self.mute.TextWrapped=true
    local scoreWidth=math.min(width/2-20,360)
    for i,plate in ipairs(self.scorePlates) do
        place(plate,width*(i==1 and 0.25 or 0.75)-scoreWidth/2,short and 48 or 52,scoreWidth,short and 30 or 38)
        place(self["score"..i],4,0,scoreWidth-8,short and 21 or 25)
        local pipWidth=(scoreWidth-28)/3
        for pip,bar in ipairs(self.armorBars[i]) do
            place(bar,8+(pip-1)*(pipWidth+6),short and 23 or 28,pipWidth,short and 4 or 6)
        end
    end
    self.score1.TextSize=compact and 13 or 17; self.score2.TextSize=self.score1.TextSize
    local statusWidth=math.min(width-24,620)
    place(self.status,(width-statusWidth)/2,headerHeight+3,statusWidth,28)
    self.status.TextSize=compact and 17 or 22
    place(self.help,12,headerHeight+30,width-24,22)
    self.help.TextSize=compact and 11 or 14
    self.help.Visible=not (short and config)
    place(self.footer,0,height,width,footerHeight)
    local half=(math.min(width,900)-32)/2
    if short and config and not compact then half=(width-204)/2 end
    local left=short and config and not compact and 12 or (width-half*2-8)/2
    for i,card in ipairs(self.cards) do
        card.frame.Visible=config
        place(card.frame,left+(i-1)*(half+8),8,half,footerHeight-62)
        place(card.role,0,0,half,17); card.role.Visible=not short
        card.role.TextColor3=accents[i]
        self.scorePlates[i].BackgroundColor3=NAVY:Lerp(accents[i],0.14)
        self.scorePlates[i].Edge.Color=accents[i]
        place(card.power,0,short and 0 or 21,half,short and 34 or 40)
        card.power.Text=(short and (i==1 and "YOU · " or "SIM · ") or "")..self.settings[i].powerId.."  ↔"
        card.power.TextSize=short and 14 or 16
        card.power.TextColor3=accents[i]
        card.power.BackgroundColor3=Color3.fromRGB(37,54,76):Lerp(accents[i],0.22)
        card.power.Edge.Color=accents[i]; card.power.Edge.Transparency=0.18
        place(card.description,4,63,half-8,28); card.description.Visible=not short
        card.description.Text=DESCRIPTIONS[self.settings[i].powerId]
        local modifier=self.modifiers.get(self.settings[i].modifierId) or self.modifiers.get("None")
        card.modifier.Visible=not short or not self.showAngles
        place(card.modifier,0,short and 40 or 96,half,short and 46 or 40)
        card.modifier.Text=short and (modifier.name.."  ↔\n"..modifier.description) or (modifier.name.."  ↔")
        card.modifier.TextWrapped=true
        card.modifier.TextSize=short and 11 or 15
        card.modifier.TextColor3=modifier.id=="None" and MUTED or accents[i]
        card.modifier.BackgroundColor3=modifier.id=="None" and Color3.fromRGB(36,48,67) or Color3.fromRGB(48,68,91)
        place(card.modifierDescription,4,139,half-8,34)
        card.modifierDescription.Text=modifier.description
        card.modifierDescription.Visible=not short
        local y=short and 40 or 178
        card.minus.Visible=self.showAngles; card.plus.Visible=self.showAngles; card.angle.Visible=self.showAngles
        place(card.minus,0,y,44,38); place(card.plus,half-44,y,44,38)
        place(card.angle,46,y,half-92,38); card.angle.Text="Aim "..self.settings[i].angle.."°"
    end
    self.launch.Visible=config; self.angleToggle.Visible=config
    self.replay.Visible=results; self.edit.Visible=results
    local actionWidth=math.min(width-24,510)
    place(self.angleToggle,(width-actionWidth)/2,footerHeight-54,112,44)
    place(self.launch,(width-actionWidth)/2+120,footerHeight-54,actionWidth-120,44)
    self.angleToggle.Text=self.showAngles and "Hide angles" or "Angles"
    if short and config and not compact then
        place(self.launch,width-172,8,160,48)
        place(self.angleToggle,width-172,62,160,40)
        self.angleToggle.Text=self.showAngles and "Back to effects" or "Tune angles"
    end
    local buttonWidth=math.min(260,(width-36)/2)
    place(self.replay,width/2-buttonWidth-6,footerHeight-54,buttonWidth,44)
    place(self.edit,width/2+6,footerHeight-54,buttonWidth,44)
    self.footerHint.Visible=not config
    self.footerHint.TextSize=compact and 12 or 13
    place(self.footerHint,12,results and 5 or 7,width-24,results and 40 or 40)
    local sim=data.simulation
    self:feedback(data)
    for i,f in ipairs(sim.fighters) do
        self["score"..i].Text=(i==1 and "YOU" or "SIM").." · "..string.upper(f.powerId)
        self["score"..i].TextColor3=accents[i]
        local flash=math.max(0,1-(os.clock()-((self.hitTimes or {})[i] or -100))/0.35)
        for pip,bar in ipairs(self.armorBars[i]) do
            bar.BackgroundColor3=(pip<=f.armor and accents[i] or Color3.fromRGB(43,51,66)):Lerp(WHITE,flash*0.65)
            bar.BackgroundTransparency=pip<=f.armor and 0 or 0.25
        end
        self.scorePlates[i].Edge.Transparency=0.55-flash*0.45
    end
    self.status.TextColor3=WHITE
    self.statusEdge.Color=Color3.fromRGB(118,154,187)
    self.statusEdge.Transparency=0.6
    if config then
        self.status.Text="Choose a power. Add one twist."
        self.help.Text="One optional effect per plane. Both fly and fight automatically."
    elseif data.phase=="Countdown" then
        self.status.Text="GET READY"
        self.help.Text="Watch the windup. The attack is committed."
        self.footerHint.Text="Meteor dives into a ram · Firework sends a rocket"
    elseif results then
        self.status.Text=sim.winner==0 and "DRAW · EVENLY MATCHED" or (sim.winner==1 and "YOUR PLANE WINS!" or "SIMULATED OPPONENT WINS")
        self.status.TextColor3=sim.winner==0 and WHITE or accents[sim.winner]
        self.statusEdge.Color=self.status.TextColor3; self.statusEdge.Transparency=0.1
        self.help.Text=string.format("%.1f seconds · %s",sim.elapsed,sim.reason=="timeout" and "armor at the time limit" or "armor depleted")
        self.footerHint.Text=string.format("You landed %d hits · SIM landed %d. Change one effect and see what happens.",sim.fighters[1].hits,sim.fighters[2].hits)
    else
        self.status.Text=sim.pressure>0 and "WIND CLOSING IN" or "BATTLE!"
        if os.clock()<(self.feedbackUntil or 0) then
            self.status.Text=self.feedbackText; self.status.TextColor3=Color3.fromRGB(255,213,94)
            self.statusEdge.Color=self.status.TextColor3; self.statusEdge.Transparency=0.15
        end
        self.help.Text=string.format("%02d seconds left · %s",math.max(0,math.ceil(35-sim.elapsed)),
            sim.pressure>0 and "Arena closing" or "Automatic combat")
        local effects={}
        for i,f in ipairs(sim.fighters) do
            local effect=self.modifiers.get(f.modifierId or "None")
            local name=effect and effect.name or "No effect"
            if f.modifierId=="SpringBumper" then name=f.bumperReady and "Bumper ready" or "Bumper spent" end
            if (f.boostLeft or 0)>0 then name="Afterburner firing!" end
            effects[i]=(i==1 and "YOU: " or "SIM: ")..name
        end
        self.footerHint.Text=table.concat(effects,"   ·   ")
    end
    -- Three evenly spaced beats across the server countdown, then FIGHT!
    local call=nil
    if data.phase=="Countdown" then
        local remaining=data.endsAt-workspace:GetServerTimeNow()
        if self.countRound~=data.roundId then self.countRound=data.roundId; self.countSpan=math.max(0.3,remaining) end
        call=tostring(4-math.clamp(math.floor((1-remaining/self.countSpan)*3)+1,1,3))
    elseif data.phase=="Fight" and sim.elapsed<0.8 then call="FIGHT!" end
    if call~=self.countText then self.countText=call; self.countAt=os.clock() end
    self.count.Visible=call~=nil
    if call then
        local age=os.clock()-(self.countAt or 0)
        self.count.Text=call
        self.count.Position=UDim2.fromOffset(width/2,headerHeight+(height-headerHeight-footerHeight)/2)
        self.count.TextSize=math.min(call=="FIGHT!" and 130 or 170,width*0.24)
        self.count.TextColor3=call=="FIGHT!" and Color3.fromRGB(255,112,92) or Color3.fromRGB(255,221,87)
        self.countScale.Scale=1+1.1*math.max(0,1-age/0.18)^2
        self.count.TextTransparency=math.clamp((age-0.45)/0.3,0,1)
        self.count.Edge.Transparency=self.count.TextTransparency
    end
    local inset=GuiService:GetGuiInset()
    local origin=self.root.AbsolutePosition+inset
    self.view:update(data,dt,{left=origin.X+10,right=origin.X+width-10,
        top=origin.Y+headerHeight+(short and config and 32 or 56),bottom=origin.Y+height-footerHeight-8})
    self.flash.BackgroundTransparency=1-math.min(0.7,self.view.screenFlash*0.7)
end
return BattleLab
