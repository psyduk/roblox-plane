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
local GOLD=Color3.fromRGB(255,221,87)
local POWERS={
    {id="Meteor",icon="☄️",word="BOOOM!",promise="Charge up, then dive-bomb your rival.",color=Color3.fromRGB(255,128,86)},
    {id="Firework",icon="🎆",word="FWOOSH!",promise="Fire a big rocket on every pass.",color=Color3.fromRGB(160,128,255)},
}
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
    self.command=shared:WaitForChild("BattleCommand")
    self.gui=make("ScreenGui",Players.LocalPlayer:WaitForChild("PlayerGui"),"SkyboundBattleLab")
    self.gui.ResetOnSpawn=false; self.gui.DisplayOrder=30; self.gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    self.root=make("Frame",self.gui,"Root"); self.root.Size=UDim2.fromScale(1,1); self.root.BackgroundTransparency=1
    self.panel=make("Frame",self.root,"Lab"); self.panel.Size=UDim2.fromScale(1,1); self.panel.BackgroundTransparency=1; self.panel.Visible=false
    self.header=make("Frame",self.panel,"Header"); self.header.BackgroundColor3=NAVY; self.header.BorderSizePixel=0
    surface(self.header,Color3.fromRGB(67,111,147),1)
    self.title=label(self.header,"Title",20); self.title.Text="SKYBOUND CLASH"
    self.subtitle=label(self.header,"Subtitle",12,MUTED); self.subtitle.Text="VS PRACTICE BOT"
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
    for i=1,2 do
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
    -- Setup is one screen about your own plane: pick a power card, add a
    -- twist, FIGHT! The rival's build is rolled when the fight starts.
    self.picker=make("Frame",self.panel,"Picker"); self.picker.BorderSizePixel=0
    self.picker.BackgroundColor3=NAVY; self.picker.BackgroundTransparency=0.3
    self.pickTitle=label(self.picker,"Title",38,WHITE); self.pickTitle.Font=Enum.Font.FredokaOne
    self.pickTitle.Text="CHOOSE YOUR POWER"
    local titleEdge=make("UIStroke",self.pickTitle,"Edge"); titleEdge.Thickness=4; titleEdge.Color=NAVY
    self.powerCards={}
    for index,spec in ipairs(POWERS) do
        local card=make("TextButton",self.picker,spec.id)
        card.Text=""; card.AutoButtonColor=false; card.BorderSizePixel=0; card.BackgroundColor3=spec.color
        make("UICorner",card,"Corner").CornerRadius=UDim.new(0,22)
        local edge=make("UIStroke",card,"Edge"); edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; edge.Thickness=5
        local shade=make("UIGradient",card,"Shading"); shade.Rotation=90
        shade.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(200,196,214))
        local tag=label(card,"Tag",13,NAVY); tag.BackgroundColor3=WHITE; tag.BackgroundTransparency=0
        make("UICorner",tag,"Corner").CornerRadius=UDim.new(0,9)
        local icon=label(card,"Icon",60); icon.TextWrapped=false
        local word=label(card,"Word",20,WHITE); word.Font=Enum.Font.FredokaOne; word.Rotation=index==1 and -9 or 9
        word.TextWrapped=false; word.Text=spec.word
        local wordEdge=make("UIStroke",word,"Edge"); wordEdge.Thickness=3; wordEdge.Color=NAVY
        local name=label(card,"PowerName",30,NAVY); name.Font=Enum.Font.FredokaOne; name.Text=string.upper(spec.id)
        local promise=label(card,"Promise",14,NAVY); promise.Text=spec.promise
        local scale=make("UIScale",card,"Pop")
        card.Activated:Connect(function() self:choose("powerId",spec.id) end)
        self.powerCards[index]={spec=spec,button=card,edge=edge,tag=tag,icon=icon,word=word,name=name,promise=promise,scale=scale}
        icon.Text=spec.icon
    end
    self.twistTitle=label(self.picker,"TwistTitle",15,MUTED); self.twistTitle.Text="ADD A TWIST"
    self.chips={}
    for index,modifier in ipairs(self.modifiers.all()) do
        local chip=button(self.picker,"Twist"..modifier.id,modifier.id=="None" and "No twist" or modifier.name,function() self:choose("modifierId",modifier.id) end)
        chip.AutoButtonColor=false
        self.chips[index]={modifier=modifier,button=chip,color=Color3.fromRGB(modifier.color.r,modifier.color.g,modifier.color.b)}
    end
    self.twistHint=label(self.picker,"TwistHint",14,WHITE)
    self.fightButton=button(self.picker,"Fight","FIGHT!",function() self:fight() end)
    self.fightButton.Font=Enum.Font.FredokaOne; self.fightButton.TextSize=32
    self.fightButton.BackgroundColor3=Color3.fromRGB(74,201,96)
    self.fightButton.Edge.Color=WHITE; self.fightButton.Edge.Transparency=0.1; self.fightButton.Edge.Thickness=3
    self.replay=button(self.footer,"Replay","REMATCH",function() self:rematch() end)
    self.replay.BackgroundColor3=Color3.fromRGB(74,201,96); self.replay.Font=Enum.Font.FredokaOne; self.replay.TextSize=22
    self.edit=button(self.footer,"Edit","Change power",function() self.audio:ui(false); self:send("restart",{edit=true}) end)
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
function BattleLab:choose(key,value)
    if not self.data or self.data.phase~="Configure" or not self.settings[1] then return end
    self.settings[1][key]=value
    self.pickedAt=os.clock()
    self.audio:ui(false)
    self:send("configure",{settings=self.settings})
end
-- The rival's build is a surprise revealed by the countdown. Firework mirrors
-- still trade into draws, so the bot never copies a Firework pick.
function BattleLab:fight()
    if not self.data or self.data.phase~="Configure" or not self.settings[2] then return end
    local twists=self.modifiers.all()
    local rival=self.settings[2]
    rival.powerId=self.settings[1].powerId=="Firework" and "Meteor" or POWERS[math.random(#POWERS)].id
    rival.modifierId=twists[math.random(#twists)].id
    rival.angle=math.random(4,10)*5
    self.audio:ui(true)
    self.launchHide=os.clock()+1.5
    self:send("launch",{settings=self.settings})
end
-- One tap from results to a fresh fight against a newly rolled rival.
function BattleLab:rematch()
    self.rematchUntil=os.clock()+1.5
    self.audio:ui(true)
    self:send("restart",{edit=true})
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
                local victim=event.target==1 and "YOU" or "RIVAL"
                self.lastHit={target=event.target,source=attack}
                if recent then
                    self.feedbackText=attack.." · "..victim.." −1"; self.feedbackUntil=os.clock()+0.7
                    self.hitTimes[event.target]=os.clock()
                end
            elseif event.kind=="blocked" and recent then
                self.feedbackText=(event.actor==1 and "YOUR BUMPER" or "RIVAL BUMPER").." SAVED A HIT!"
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
    local footerHeight=config and 0 or (results and 108 or (plainFight and 0 or 54))
    self.footer.Visible=not plainFight and not config
    place(self.header,0,0,width,headerHeight)
    place(self.title,12,4,width-184,26); self.title.TextXAlignment=Enum.TextXAlignment.Left
    self.title.TextSize=compact and 16 or 22
    self.title.Text=short and "VS PRACTICE BOT" or "SKYBOUND CLASH"
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
    self.help.Visible=not config; self.status.Visible=not config
    place(self.footer,0,height,width,footerHeight)
    for i=1,2 do
        self.scorePlates[i].BackgroundColor3=NAVY:Lerp(accents[i],0.14)
        self.scorePlates[i].Edge.Color=accents[i]
    end
    -- A rematch passes through setup for a moment; roll the rival and go.
    local rematching=config and self.rematchUntil~=nil and os.clock()<self.rematchUntil
    if rematching then self.rematchUntil=nil; self:fight() end
    -- Hide setup the moment a fight is requested; return if nothing started.
    self.picker.Visible=config and os.clock()>(self.launchHide or 0)
    if self.picker.Visible then
        local top=headerHeight
        local area=height-top
        place(self.picker,0,top,width,area)
        local panelWidth=math.min(width-24,760)
        local x0=(width-panelWidth)/2
        local showTitle=area>=380
        local chipRows=compact and 2 or 1
        local chipHeight=short and 36 or 42
        local fightHeight=short and 48 or 62
        local fixed=(showTitle and 54 or 8)+(showTitle and 26 or 0)+chipRows*(chipHeight+6)+(showTitle and 26 or 0)+fightHeight+34
        local cardHeight=math.clamp(area-fixed,72,230)
        local y=math.max(6,(area-fixed-cardHeight)/2)
        self.pickTitle.Visible=showTitle; self.twistTitle.Visible=showTitle; self.twistHint.Visible=showTitle
        if showTitle then
            place(self.pickTitle,x0,y,panelWidth,46); self.pickTitle.TextSize=compact and 26 or 38; y=y+54
        else y=y+8 end
        local cardWidth=(panelWidth-14)/2
        for index,card in ipairs(self.powerCards) do
            local chosen=self.settings[1].powerId==card.spec.id
            place(card.button,x0+(index-1)*(cardWidth+14),y,cardWidth,cardHeight)
            card.button.BackgroundColor3=chosen and card.spec.color or card.spec.color:Lerp(NAVY,0.45)
            card.edge.Color=chosen and GOLD or NAVY; card.edge.Thickness=chosen and 6 or 4
            -- The chosen card pops forward with a little bounce.
            local bounce=chosen and math.max(0,1-(os.clock()-(self.pickedAt or 0))/0.2) or 0
            card.scale.Scale=(chosen and 1.03 or 0.95)+bounce*0.07
            card.button.ZIndex=chosen and 3 or 2
            local roomy=cardHeight>=150
            place(card.tag,12,10,math.min(cardWidth-24,150),22)
            card.tag.Text=chosen and "✓ YOUR POWER" or "TAP TO PICK"
            card.tag.BackgroundTransparency=chosen and 0 or 0.45
            place(card.icon,0,roomy and 34 or 4,roomy and cardWidth or cardHeight,roomy and cardHeight*0.4 or cardHeight-8)
            card.icon.TextSize=math.clamp((roomy and cardHeight*0.34 or cardHeight*0.5),28,84)
            place(card.word,cardWidth-math.min(150,cardWidth*0.5),roomy and 40 or 6,math.min(140,cardWidth*0.46),28)
            card.word.TextSize=compact and 15 or 22; card.word.Visible=roomy or cardWidth>300
            if roomy then
                place(card.name,8,34+cardHeight*0.4,cardWidth-16,36)
                place(card.promise,14,34+cardHeight*0.4+36,cardWidth-28,cardHeight-(34+cardHeight*0.4+36)-8)
            else
                place(card.name,cardHeight,cardHeight/2-16,cardWidth-cardHeight-8,32)
            end
            card.name.TextSize=math.clamp(cardWidth*0.12,18,34)
            card.promise.Visible=roomy; card.promise.TextSize=compact and 12 or 15
        end
        y=y+cardHeight+12
        if showTitle then place(self.twistTitle,x0,y,panelWidth,20); y=y+26 end
        local perRow=#self.chips/chipRows
        local chipWidth=(panelWidth-(perRow-1)*8)/perRow
        local chosenTwist=self.modifiers.get(self.settings[1].modifierId) or self.modifiers.get("None")
        for index,chip in ipairs(self.chips) do
            local row,column=math.floor((index-1)/perRow),(index-1)%perRow
            local chosen=chip.modifier.id==chosenTwist.id
            place(chip.button,x0+column*(chipWidth+8),y+row*(chipHeight+6),chipWidth,chipHeight)
            chip.button.BackgroundColor3=chosen and chip.color or Color3.fromRGB(40,58,84)
            chip.button.TextColor3=chosen and NAVY or WHITE
            chip.button.TextSize=compact and 13 or 16
            chip.button.Edge.Color=chosen and GOLD or chip.color; chip.button.Edge.Transparency=chosen and 0 or 0.35
            chip.button.Edge.Thickness=chosen and 3 or 1
        end
        y=y+chipRows*(chipHeight+6)
        if showTitle then
            place(self.twistHint,x0,y,panelWidth,22); self.twistHint.TextSize=compact and 12 or 15
            self.twistHint.Text=chosenTwist.id=="None" and "No twist: just your power." or chosenTwist.description
            y=y+26
        end
        local fightWidth=math.min(panelWidth,440)
        place(self.fightButton,(width-fightWidth)/2,y+8,fightWidth,fightHeight)
        self.fightButton.TextSize=short and 26 or 34
    end
    self.replay.Visible=results; self.edit.Visible=results
    local buttonWidth=math.min(260,(width-36)/2)
    place(self.replay,width/2-buttonWidth-6,footerHeight-54,buttonWidth,44)
    place(self.edit,width/2+6,footerHeight-54,buttonWidth,44)
    self.footerHint.Visible=not config
    self.footerHint.TextSize=compact and 12 or 13
    place(self.footerHint,12,results and 5 or 7,width-24,results and 40 or 40)
    local sim=data.simulation
    self:feedback(data)
    for i,f in ipairs(sim.fighters) do
        self["score"..i].Text=i==1 and ("YOU · "..string.upper(f.powerId)) or (config and "RIVAL · ???" or ("RIVAL · "..string.upper(f.powerId)))
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
        self.status.Text=""; self.help.Text=""
    elseif data.phase=="Countdown" then
        self.status.Text="GET READY"
        self.help.Text="Watch the windup. The attack is committed."
        self.footerHint.Text="Meteor dives into a ram · Firework sends a rocket"
    elseif results then
        self.status.Text=sim.winner==0 and "DRAW!" or (sim.winner==1 and "YOU WIN!" or "RIVAL WINS")
        self.status.TextColor3=sim.winner==0 and WHITE or accents[sim.winner]
        self.statusEdge.Color=self.status.TextColor3; self.statusEdge.Transparency=0.1
        self.help.Text=string.format("%.1f seconds · %s",sim.elapsed,sim.reason=="timeout" and "armor at the time limit" or "armor depleted")
        self.footerHint.Text=string.format("You landed %d hits · Rival landed %d",sim.fighters[1].hits,sim.fighters[2].hits)
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
            effects[i]=(i==1 and "YOU: " or "RIVAL: ")..name
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
        top=origin.Y+headerHeight+(config and 8 or 56),bottom=origin.Y+height-footerHeight-8})
    self.flash.BackgroundTransparency=1-math.min(0.7,self.view.screenFlash*0.7)
end
return BattleLab
