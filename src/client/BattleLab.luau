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
local function tint(color) return Color3.fromRGB(color.r,color.g,color.b) end
local function copyBuild(build)
    local wildIds={}
    for index,id in ipairs(build.wildIds or {}) do wildIds[index]=id end
    return {offenceId=build.offenceId,angle=build.angle,wildIds=wildIds}
end
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
    local self=setmetatable({World=World,active=false,data=nil,settings={},outbox={},sending=false,lastSend=-math.huge},BattleLab)
    self.skills=require(shared:WaitForChild("SkillCatalog"))
    self.audio=BattleAudio.new()
    self.command=shared:WaitForChild("BattleCommand")
    self.gui=make("ScreenGui",Players.LocalPlayer:WaitForChild("PlayerGui"),"SkyboundBattleLab")
    self.gui.ResetOnSpawn=false; self.gui.DisplayOrder=30; self.gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    self.root=make("Frame",self.gui,"Root"); self.root.Size=UDim2.fromScale(1,1); self.root.BackgroundTransparency=1
    self.panel=make("Frame",self.root,"Lab"); self.panel.Size=UDim2.fromScale(1,1); self.panel.BackgroundTransparency=1; self.panel.Visible=false
    -- One dim sheet sits behind setup and results. It reaches over the fighter
    -- bar and up into the Roblox top bar so the whole sky dims, not a slab.
    self.scrim=make("Frame",self.panel,"Scrim"); self.scrim.BorderSizePixel=0; self.scrim.ZIndex=0
    self.scrim.BackgroundColor3=NAVY; self.scrim.BackgroundTransparency=1
    -- The top of the screen is a fighting-game bar: each pilot's face, name,
    -- power and three chunky armor pips at the edges, the clock between them.
    self.header=make("Frame",self.panel,"Header"); self.header.BackgroundTransparency=1; self.header.BorderSizePixel=0
    self.exit=button(self.panel,"Exit","🏠",function() self:send("exit") end)
    self.mute=button(self.panel,"Mute","🔊",function()
        local p=Players.LocalPlayer
        p:SetAttribute("SkyboundSoundMuted",p:GetAttribute("SkyboundSoundMuted")~=true)
    end)
    self.exit.ZIndex=10; self.mute.ZIndex=10; self.exit.TextSize=20; self.mute.TextSize=18
    self.clock=label(self.header,"Clock",40,WHITE); self.clock.Font=Enum.Font.FredokaOne; self.clock.TextWrapped=false
    local clockEdge=make("UIStroke",self.clock,"Edge"); clockEdge.Thickness=5; clockEdge.Color=NAVY
    self.clockScale=make("UIScale",self.clock,"Pulse")
    self.status=label(self.panel,"Status",22)
    self.status.BackgroundColor3=Color3.fromRGB(31,49,69); self.status.BackgroundTransparency=0.08
    make("UICorner",self.status,"Corner").CornerRadius=UDim.new(0,10)
    self.statusEdge=surface(self.status,Color3.fromRGB(118,154,187),1)
    self.help=label(self.panel,"Help",14,MUTED)
    self.footer=make("Frame",self.panel,"Controls"); self.footer.BackgroundColor3=NAVY; self.footer.BorderSizePixel=0
    surface(self.footer,Color3.fromRGB(67,111,147),1)
    self.footer.AnchorPoint=Vector2.new(0,1)
    self.fighters={}
    for i=1,2 do
        local plate=make("Frame",self.header,"Fighter"..i); plate.BackgroundTransparency=1
        local ring=make("Frame",plate,"Portrait"); ring.BackgroundColor3=NAVY; ring.BorderSizePixel=0
        make("UICorner",ring,"Corner").CornerRadius=UDim.new(1,0)
        local ringEdge=make("UIStroke",ring,"Edge"); ringEdge.Thickness=4; ringEdge.Color=ACCENTS[i]
        local face=make("ImageLabel",ring,"Face"); face.BackgroundTransparency=1; face.Size=UDim2.fromScale(1,1)
        make("UICorner",face,"Corner").CornerRadius=UDim.new(1,0)
        local bot=label(ring,"Bot",30); bot.Size=UDim2.fromScale(1,1); bot.Text="🤖"; bot.TextWrapped=false; bot.Visible=i==2
        local name=label(plate,"PilotName",20,WHITE); name.Font=Enum.Font.FredokaOne; name.TextWrapped=false
        name.TextTruncate=Enum.TextTruncate.AtEnd
        local nameEdge=make("UIStroke",name,"Edge"); nameEdge.Thickness=3; nameEdge.Color=NAVY
        local power=label(plate,"Power",12,NAVY); power.BackgroundTransparency=0; power.BackgroundColor3=ACCENTS[i]; power.TextWrapped=false
        make("UICorner",power,"Corner").CornerRadius=UDim.new(0,8)
        local pips={}
        for pip=1,3 do
            local bar=make("Frame",plate,"Armor"..pip); bar.BorderSizePixel=0; bar.BackgroundColor3=ACCENTS[i]
            make("UICorner",bar,"Corner").CornerRadius=UDim.new(0,6)
            local edge=make("UIStroke",bar,"Edge"); edge.Thickness=3; edge.Color=NAVY
            pips[pip]=bar
        end
        self.fighters[i]={frame=plate,ring=ring,ringEdge=ringEdge,face=face,name=name,power=power,pips=pips}
    end
    self.fighters[1].name.Text=string.upper(Players.LocalPlayer.DisplayName)
    self.fighters[2].name.Text="RIVAL BOT"
    task.spawn(function()
        local ok,image=pcall(function()
            return Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100)
        end)
        if ok and self.fighters[1].face.Parent then self.fighters[1].face.Image=image end
    end)
    -- Setup is one screen about your own plane: pick a power card, add up to
    -- two wild cards, FIGHT! The rival's build is rolled when the fight starts.
    self.picker=make("Frame",self.panel,"Picker"); self.picker.BorderSizePixel=0
    self.picker.BackgroundTransparency=1
    self.pickTitle=label(self.picker,"Title",38,WHITE); self.pickTitle.Font=Enum.Font.FredokaOne
    self.pickTitle.Text="CHOOSE YOUR POWER"
    local titleEdge=make("UIStroke",self.pickTitle,"Edge"); titleEdge.Thickness=4; titleEdge.Color=NAVY
    self.powerCards={}
    for index,spec in ipairs(self.skills.all("offence")) do
        spec.color=tint(spec.color)
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
        local name=label(card,"PowerName",30,NAVY); name.Font=Enum.Font.FredokaOne; name.Text=string.upper(spec.name)
        local promise=label(card,"Promise",14,NAVY); promise.Text=spec.promise
        local scale=make("UIScale",card,"Pop")
        card.Activated:Connect(function() self:choose(spec.id) end)
        self.powerCards[index]={spec=spec,button=card,edge=edge,tag=tag,icon=icon,word=word,name=name,promise=promise,scale=scale}
        icon.Text=spec.icon
    end
    self.twistTitle=label(self.picker,"TwistTitle",15,MUTED); self.twistTitle.Text="ADD UP TO "..self.skills.MAX_WILD.." WILD CARDS"
    self.chips={}
    for index,wild in ipairs(self.skills.all("wild")) do
        local chip=button(self.picker,"Wild"..wild.id,wild.icon.." "..wild.name,function() self:toggleWild(wild.id) end)
        chip.AutoButtonColor=false
        self.chips[index]={wild=wild,button=chip,color=tint(wild.color)}
    end
    self.twistHint=label(self.picker,"TwistHint",14,WHITE)
    self.fightButton=button(self.picker,"Fight","FIGHT!",function() self:fight() end)
    self.fightButton.Font=Enum.Font.FredokaOne; self.fightButton.TextSize=32
    self.fightButton.BackgroundColor3=Color3.fromRGB(74,201,96)
    self.fightButton.Edge.Color=WHITE; self.fightButton.Edge.Transparency=0.1; self.fightButton.Edge.Thickness=3
    -- The result is a moment of its own: a slammed-in banner, the winner's
    -- face under a crown, three numbers, and REMATCH as the obvious next tap.
    self.result=make("Frame",self.panel,"Result"); self.result.BorderSizePixel=0; self.result.ZIndex=20
    self.result.BackgroundTransparency=1; self.result.Visible=false; self.result.ClipsDescendants=true
    self.confetti={}
    for index=1,40 do
        local piece=make("Frame",self.result,"Confetti"); piece.BorderSizePixel=0; piece.ZIndex=20
        piece.BackgroundColor3=({GOLD,ACCENTS[1],ACCENTS[2],WHITE,Color3.fromRGB(160,128,255)})[index%5+1]
        self.confetti[index]={frame=piece,x=math.random(),speed=120+math.random()*200,offset=math.random(),spin=(math.random()-0.5)*500,sway=math.random()*6}
    end
    self.banner=label(self.result,"Banner",96,GOLD); self.banner.Font=Enum.Font.FredokaOne; self.banner.TextWrapped=false
    self.banner.ZIndex=22; self.banner.Rotation=-3
    local bannerEdge=make("UIStroke",self.banner,"Edge"); bannerEdge.Thickness=8; bannerEdge.Color=NAVY
    self.bannerScale=make("UIScale",self.banner,"Slam")
    self.resultLine=label(self.result,"Line",18,WHITE); self.resultLine.ZIndex=22
    self.winnerRing=make("Frame",self.result,"Winner"); self.winnerRing.BackgroundColor3=NAVY; self.winnerRing.BorderSizePixel=0; self.winnerRing.ZIndex=21
    make("UICorner",self.winnerRing,"Corner").CornerRadius=UDim.new(1,0)
    self.winnerEdge=make("UIStroke",self.winnerRing,"Edge"); self.winnerEdge.Thickness=6
    self.winnerFace=make("ImageLabel",self.winnerRing,"Face"); self.winnerFace.BackgroundTransparency=1
    self.winnerFace.Size=UDim2.fromScale(1,1); self.winnerFace.ZIndex=21
    make("UICorner",self.winnerFace,"Corner").CornerRadius=UDim.new(1,0)
    self.winnerEmoji=label(self.winnerRing,"Emoji",48); self.winnerEmoji.Size=UDim2.fromScale(1,1); self.winnerEmoji.TextWrapped=false; self.winnerEmoji.ZIndex=22
    self.crown=label(self.result,"Crown",44); self.crown.Text="👑"; self.crown.TextWrapped=false; self.crown.ZIndex=23; self.crown.Rotation=-12
    self.stats={}
    for index,caption in ipairs({"YOUR HITS","RIVAL HITS","TIME"}) do
        local chip=make("Frame",self.result,"Stat"..index); chip.BackgroundColor3=Color3.fromRGB(30,46,72); chip.BorderSizePixel=0; chip.ZIndex=21
        make("UICorner",chip,"Corner").CornerRadius=UDim.new(0,12)
        local edge=make("UIStroke",chip,"Edge"); edge.Thickness=2; edge.Color=Color3.fromRGB(86,118,160)
        local value=label(chip,"Value",28,WHITE); value.Font=Enum.Font.FredokaOne; value.ZIndex=22; value.TextWrapped=false
        local name=label(chip,"Caption",11,MUTED); name.Text=caption; name.ZIndex=22; name.TextWrapped=false
        self.stats[index]={frame=chip,value=value,caption=name,edge=edge}
    end
    self.replay=button(self.result,"Replay","REMATCH",function() self:rematch() end)
    self.replay.BackgroundColor3=Color3.fromRGB(74,201,96); self.replay.Font=Enum.Font.FredokaOne; self.replay.TextSize=30
    self.replay.Edge.Color=WHITE; self.replay.Edge.Transparency=0.1; self.replay.Edge.Thickness=3
    self.edit=button(self.result,"Edit","Change power",function() self.audio:ui(false); self:send("restart",{edit=true}) end)
    self.leave=button(self.result,"Leave","Hangar",function() self.audio:ui(false); self:send("exit") end)
    for _,item in ipairs({self.replay,self.edit,self.leave}) do item.ZIndex=22 end
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
            self.settings={copyBuild(data.settings[1]),copyBuild(data.settings[2])}
            end
            if not self.view then
                self.view=BattleView.new(World,function(cue)
                    if cue.kind=="crash" then self.audio:playCrash(cue.roundId,cue.actor) end
                end,{pilots=PilotAvatar,skills=self.skills})
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
        payload.settings={copyBuild(payload.settings[1]),copyBuild(payload.settings[2])}
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
function BattleLab:choose(offenceId)
    if not self.data or self.data.phase~="Configure" or not self.settings[1] then return end
    self.settings[1].offenceId=offenceId
    self.pickedAt=os.clock()
    self.audio:ui(false)
    self:send("configure",{settings=self.settings})
end
-- Tap a wild card to add it, tap again to drop it. With a full hand, a new
-- card pushes out the one picked longest ago.
function BattleLab:toggleWild(id)
    if not self.data or self.data.phase~="Configure" or not self.settings[1] then return end
    local wildIds=self.settings[1].wildIds
    local held=table.find(wildIds,id)
    if held then table.remove(wildIds,held)
    else
        if #wildIds>=self.skills.MAX_WILD then table.remove(wildIds,1) end
        table.insert(wildIds,id)
    end
    self.audio:ui(false)
    self:send("configure",{settings=self.settings})
end
-- The rival's build is a surprise revealed by the countdown. Firework mirrors
-- still trade into draws, so the bot never copies a Firework pick. It brings
-- as many wild cards as the pilot did, so neither side starts a card ahead.
function BattleLab:fight()
    if not self.data or self.data.phase~="Configure" or not self.settings[2] then return end
    local offences,wilds=self.skills.all("offence"),self.skills.all("wild")
    local rival=self.settings[2]
    rival.offenceId=self.settings[1].offenceId=="Firework" and "Meteor" or offences[math.random(#offences)].id
    rival.wildIds={}
    for _=1,math.min(#self.settings[1].wildIds,#wilds) do
        rival.wildIds[#rival.wildIds+1]=table.remove(wilds,math.random(#wilds)).id
    end
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
-- Waits for the knockout to play out in the arena, then takes the screen.
function BattleLab:showResult(data,results,accents,width,height,headerHeight,compact,short)
    if not results then self.result.Visible=false; self.resultRound=nil; return end
    local sim=data.simulation
    if self.resultRound~=data.roundId then
        self.resultRound,self.resultAt,self.resultSounded=data.roundId,os.clock(),false
    end
    local age=os.clock()-self.resultAt-(sim.reason=="knockout" and 1.8 or 0.6)
    self.result.Visible=age>0
    if age<=0 then return end
    local outcome=sim.winner==1 and "win" or (sim.winner==2 and "lose" or "draw")
    if not self.resultSounded then self.resultSounded=true; self.audio:result(outcome) end
    local area=height-headerHeight
    place(self.result,0,headerHeight,width,area)
    self.resultDim=1-0.55*math.clamp(age/0.25,0,1)
    local bannerHeight=compact and 60 or (short and 70 or 104)
    local face=short and 0 or math.clamp(area*0.2,56,124)
    -- The crown sits above the portrait; leave it room under the result line.
    local crownGap=math.max(14,face*0.3)
    local statHeight=short and 48 or 64
    local stacked=compact
    local buttonsHeight=stacked and 112 or 64
    local total=bannerHeight+26+(face>0 and face+crownGap+8 or 0)+statHeight+18+buttonsHeight+10
    local y=math.max(4,(area-total)/2)
    local tint=outcome=="win" and GOLD or (outcome=="lose" and Color3.fromRGB(150,170,205) or WHITE)
    place(self.banner,0,y,width,bannerHeight)
    self.banner.Text=outcome=="win" and "VICTORY!" or (outcome=="lose" and "DEFEAT" or "DRAW!")
    self.banner.TextColor3=tint
    self.banner.TextSize=math.min(bannerHeight*0.95,width*0.17)
    self.bannerScale.Scale=1+1.6*math.max(0,1-age/0.2)^2
    y=y+bannerHeight
    place(self.resultLine,12,y,width-24,22)
    self.resultLine.TextSize=compact and 13 or 18
    self.resultLine.Text=sim.reason=="timeout"
        and (outcome=="draw" and "Time ran out with armor level" or (outcome=="win" and "Time! You had more armor left" or "Time! The rival had more armor left"))
        or (outcome=="draw" and "Both planes went down" or (outcome=="win" and "You knocked the rival out of the sky" or "You got knocked out of the sky"))
    y=y+26
    local settled=age>0.3
    self.winnerRing.Visible=face>0 and settled; self.crown.Visible=face>0 and settled and outcome~="draw"
    if face>0 then
        y=y+crownGap
        place(self.winnerRing,(width-face)/2,y,face,face)
        self.winnerEdge.Color=outcome=="draw" and WHITE or accents[sim.winner]
        self.winnerFace.Image=outcome=="win" and self.fighters[1].face.Image or ""
        self.winnerEmoji.Text=outcome=="lose" and "🤖" or (outcome=="draw" and "🤝" or "")
        self.winnerEmoji.TextSize=face*0.55
        place(self.crown,(width-face)/2-face*0.18,y-face*0.32,face*0.6,face*0.6)
        self.crown.TextSize=face*0.46
        y=y+face+8
    end
    local statWidth=math.min(170,(width-40)/3)
    local values={tostring(sim.fighters[1].hits),tostring(sim.fighters[2].hits),string.format("%.1fs",sim.elapsed)}
    for index,stat in ipairs(self.stats) do
        stat.frame.Visible=settled
        place(stat.frame,width/2-statWidth*1.5-8+(index-1)*(statWidth+8),y,statWidth,statHeight)
        place(stat.value,0,2,statWidth,statHeight*0.6); stat.value.Text=values[index]; stat.value.TextSize=statHeight*0.46
        place(stat.caption,0,statHeight*0.62,statWidth,statHeight*0.3); stat.caption.TextSize=compact and 9 or 11
        stat.edge.Color=index<3 and accents[index] or Color3.fromRGB(86,118,160)
    end
    y=y+statHeight+18
    for _,item in ipairs({self.replay,self.edit,self.leave}) do item.Visible=age>0.5 end
    if stacked then
        place(self.replay,16,y,width-32,56)
        place(self.edit,16,y+62,(width-40)/2,44); place(self.leave,24+(width-40)/2,y+62,(width-40)/2,44)
    else
        local main=math.min(300,width*0.3)
        local sideWidth=math.min(170,width*0.16)
        local row=main+2*(sideWidth+10)
        place(self.replay,(width-row)/2+sideWidth+10,y,main,64)
        place(self.edit,(width-row)/2,y+10,sideWidth,46)
        place(self.leave,(width-row)/2+sideWidth+10+main+10,y+10,sideWidth,46)
    end
    -- A gentle pulse keeps the eye on the next fight.
    self.replay.TextSize=(stacked and 26 or 30)+2*math.sin(os.clock()*5)
    for _,piece in ipairs(self.confetti) do
        piece.frame.Visible=outcome=="win" and not self.reducedMotion
        if piece.frame.Visible then
            local fall=(age*piece.speed+piece.offset*area)%(area+40)-20
            piece.frame.Size=UDim2.fromOffset(8,14)
            piece.frame.Position=UDim2.fromOffset(piece.x*width+math.sin(age*2+piece.sway)*18,fall)
            piece.frame.Rotation=age*piece.spin
        end
    end
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
    local headerHeight=(short or compact) and 62 or 98
    local plainFight=data.phase=="Fight" and #(data.settings[1].wildIds or {})==0
        and #(data.settings[2].wildIds or {})==0
    local quiet=config or plainFight or data.phase=="Countdown"
    quiet=quiet or results
    local footerHeight=quiet and 0 or 54
    self.footer.Visible=not quiet
    place(self.header,0,0,width,headerHeight)
    place(self.exit,12,headerHeight+4,40,40)
    place(self.mute,58,headerHeight+4,40,40); self.mute.Text=muted and "🔇" or "🔊"
    local portrait=headerHeight-18
    local plateWidth=math.min(340,(width-124)/2)
    local sim=data.simulation
    for i,fighter in ipairs(self.fighters) do
        local right=i==2
        local f=sim.fighters[i]
        local flash=math.max(0,1-(os.clock()-((self.hitTimes or {})[i] or -100))/0.35)
        place(fighter.frame,right and width-12-plateWidth or 12,8,plateWidth,portrait+4)
        place(fighter.ring,right and plateWidth-portrait or 0,2,portrait,portrait)
        fighter.ringEdge.Color=accents[i]:Lerp(WHITE,flash); fighter.ringEdge.Thickness=4+flash*4
        local textWidth=plateWidth-portrait-12
        local textLeft=right and 0 or portrait+12
        local side=right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
        place(fighter.name,textLeft,0,textWidth,compact and 18 or 28)
        fighter.name.TextXAlignment=side; fighter.name.TextSize=compact and 14 or 24
        local powerWidth=math.min(textWidth,compact and 86 or 112)
        local rowTwo=compact and 19 or 31
        place(fighter.power,right and textLeft+textWidth-powerWidth or textLeft,rowTwo,powerWidth,compact and 14 or 19)
        fighter.power.Text=(right and config) and "???" or string.upper((self.skills.get(f.offenceId) or {name="?"}).name)
        fighter.power.TextSize=compact and 10 or 13; fighter.power.BackgroundColor3=accents[i]
        local pipHeight=compact and 9 or 18
        local pipWidth=math.min(compact and 30 or 62,(textWidth-12)/3)
        for pip,bar in ipairs(fighter.pips) do
            local offset=(pip-1)*(pipWidth+6)
            place(bar,right and textLeft+textWidth-offset-pipWidth or textLeft+offset,portrait-pipHeight+1,pipWidth,pipHeight)
            local full=pip<=f.armor
            bar.BackgroundColor3=(full and accents[i] or Color3.fromRGB(36,44,62)):Lerp(WHITE,flash*0.7)
            bar.BackgroundTransparency=full and 0 or 0.35
        end
    end
    -- The clock is the centre of the bar and gets loud in the last ten seconds.
    local left=math.max(0,math.ceil(35-sim.elapsed))
    local urgent=data.phase=="Fight" and left<=10
    place(self.clock,width/2-60,4,120,headerHeight-12)
    self.clock.Text=data.phase=="Fight" and tostring(left) or (results and (sim.reason=="timeout" and "TIME!" or "K.O.") or "VS")
    self.clock.TextSize=(compact and 26 or 52)*(#self.clock.Text>2 and 0.7 or 1)
    self.clock.TextColor3=urgent and Color3.fromRGB(255,96,84) or (results and GOLD or WHITE)
    self.clockScale.Scale=urgent and 1+0.14*math.abs(math.sin(os.clock()*math.pi)) or 1
    local statusWidth=math.min(width-24,620)
    local statusTop=headerHeight+(compact and 48 or 6)
    place(self.status,(width-statusWidth)/2,statusTop,statusWidth,28)
    self.status.TextSize=compact and 17 or 22
    place(self.help,12,statusTop+28,width-24,22)
    self.help.TextSize=compact and 11 or 14
    self.help.Visible=not config and not results; self.status.Visible=not config and not results
    place(self.footer,0,height,width,footerHeight)
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
        local chipRows=math.ceil(#self.chips/(compact and 3 or 5))
        local chipHeight=short and 36 or 42
        local fightHeight=short and 48 or 62
        local fixed=(showTitle and 54 or 8)+(showTitle and 26 or 0)+chipRows*(chipHeight+6)+(showTitle and 26 or 0)+fightHeight+34
        local cardHeight=math.clamp(area-fixed,72,230)
        local y=math.max(6,(area-fixed-cardHeight)/2)
        self.pickTitle.Visible=showTitle; self.twistTitle.Visible=showTitle; self.twistHint.Visible=showTitle
        if showTitle then
            place(self.pickTitle,x0,y,panelWidth,46); self.pickTitle.TextSize=compact and 26 or 38; y=y+54
        else y=y+8 end
        local cardWidth=(panelWidth-14*(#self.powerCards-1))/#self.powerCards
        for index,card in ipairs(self.powerCards) do
            local chosen=self.settings[1].offenceId==card.spec.id
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
        local perRow=math.ceil(#self.chips/chipRows)
        local chipWidth=(panelWidth-(perRow-1)*8)/perRow
        local held=self.settings[1].wildIds
        for index,chip in ipairs(self.chips) do
            local row,column=math.floor((index-1)/perRow),(index-1)%perRow
            local chosen=table.find(held,chip.wild.id)~=nil
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
            local last=self.skills.get(held[#held])
            self.twistHint.Text=last and (last.name..": "..last.promise) or "No wild cards: just your power."
            y=y+26
        end
        local fightWidth=math.min(panelWidth,440)
        place(self.fightButton,(width-fightWidth)/2,y+8,fightWidth,fightHeight)
        self.fightButton.TextSize=short and 26 or 34
    end
    self.footerHint.Visible=not config
    self.footerHint.TextSize=compact and 12 or 13
    place(self.footerHint,12,7,width-24,40)
    self:showResult(data,results,accents,width,height,headerHeight,compact,short)
    self:feedback(data)
    self.status.TextColor3=WHITE
    self.statusEdge.Color=Color3.fromRGB(118,154,187)
    self.statusEdge.Transparency=0.6
    if config then
        self.status.Text=""; self.help.Text=""
    elseif data.phase=="Countdown" then
        self.status.Text="GET READY"
        self.help.Text="Watch the windup. The attack is committed."
        self.footerHint.Text=""
    elseif results then
        self.status.Text=""; self.help.Text=""
    else
        self.status.Text=sim.pressure>0 and "WIND CLOSING IN" or "BATTLE!"
        if os.clock()<(self.feedbackUntil or 0) then
            self.status.Text=self.feedbackText; self.status.TextColor3=Color3.fromRGB(255,213,94)
            self.statusEdge.Color=self.status.TextColor3; self.statusEdge.Transparency=0.15
        end
        self.help.Text=""
        local effects={}
        for i,f in ipairs(sim.fighters) do
            local names={}
            for _,id in ipairs(f.wildIds or {}) do
                local wild=self.skills.get(id)
                local name=wild and wild.name or id
                if id=="SpringBumper" then name=f.bumperReady and "Bumper ready" or "Bumper spent" end
                if id=="Afterburner" and (f.boostLeft or 0)>0 then name="Afterburner firing!" end
                names[#names+1]=name
            end
            effects[i]=(i==1 and "YOU: " or "RIVAL: ")..(#names>0 and table.concat(names," + ") or "No wild cards")
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
    place(self.scrim,-inset.X,-inset.Y,width+inset.X*2,height+inset.Y)
    self.scrim.BackgroundTransparency=self.picker.Visible and 0.3 or (self.result.Visible and self.resultDim or 1)
    local origin=self.root.AbsolutePosition+inset
    self.view:update(data,dt,{left=origin.X+10,right=origin.X+width-10,
        top=origin.Y+(config and headerHeight+8 or statusTop+50),bottom=origin.Y+height-footerHeight-8})
    self.flash.BackgroundTransparency=1-math.min(0.7,self.view.screenFlash*0.7)
end
return BattleLab
