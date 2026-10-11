-- Sky Battle's presentation consumes the recipient-only server snapshot. A tap
-- can select only this pilot's card; combat, rival choices and awards are server owned.
local Players=game:GetService("Players")
local GuiService=game:GetService("GuiService")
local BattleView=require(script.Parent:WaitForChild("BattleView"))
local BattleAudio=require(script.Parent:WaitForChild("BattleAudio"))
local PilotAvatar=require(script.Parent:WaitForChild("PilotAvatar"))
local BattleLab={}
BattleLab.__index=BattleLab
local NAVY=Color3.fromRGB(18,31,51)
local WHITE=Color3.fromRGB(255,245,221)
local MUTED=Color3.fromRGB(190,208,226)
local GOLD=Color3.fromRGB(255,221,87)
local GREEN=Color3.fromRGB(74,201,96)
local RED=Color3.fromRGB(255,96,84)
local EMPTY=Color3.fromRGB(36,44,62)
local function make(class,parent,name)
    local item=Instance.new(class); item.Name=name; item.Parent=parent; return item
end
local function corner(item,radius)
    make("UICorner",item,"Corner").CornerRadius=radius and UDim.new(0,radius) or UDim.new(1,0)
end
-- Chunky cartoon lettering: every floating word carries a thick navy outline
-- so it reads over bright sky without a panel behind it.
local function outline(item,thickness,color)
    local stroke=make("UIStroke",item,"Outline"); stroke.Thickness=thickness; stroke.Color=color or NAVY
    return stroke
end
-- A border plus top-lit shading gives buttons and chips a moulded look.
local function surface(item,color,thickness)
    local stroke=make("UIStroke",item,"Edge")
    stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    stroke.Color=color; stroke.Thickness=thickness or 1; stroke.Transparency=0.4
    local gradient=make("UIGradient",item,"Shading"); gradient.Rotation=90
    gradient.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(185,199,220))
    return stroke
end
local function label(parent,name,size,color,font)
    local item=make("TextLabel",parent,name)
    item.BackgroundTransparency=1; item.TextColor3=color or WHITE
    item.TextSize=size; item.Font=font or Enum.Font.GothamBold; item.TextWrapped=true; item.Text=""
    return item
end
local function button(parent,name,text,callback)
    local item=make("TextButton",parent,name)
    item.BackgroundColor3=Color3.fromRGB(44,63,86); item.BorderSizePixel=0
    item.TextColor3=WHITE; item.Font=Enum.Font.GothamBold; item.TextSize=16; item.Text=text
    item.AutoButtonColor=true; item.Selectable=true; item.TextWrapped=true
    corner(item,12); surface(item,Color3.fromRGB(132,169,201),2)
    item.Activated:Connect(callback); return item
end
local function place(item,x,y,w,h)
    item.Position=UDim2.fromOffset(x,y); item.Size=UDim2.fromOffset(math.max(0,w),math.max(0,h))
end
local function enabled(item,value)
    item.Active=value; item.Selectable=value; item.AutoButtonColor=value
    item.TextTransparency=value and 0 or 0.45
    item.BackgroundTransparency=value and 0 or 0.35
end
local function resultPhase(phase) return phase=="RoundOver" or phase=="MatchOver" or phase=="Results" end
local function tint(color) return Color3.fromRGB(color.r,color.g,color.b) end
-- Overshoots a little past one before settling: the pop on cards and words.
local function popIn(t)
    t=math.clamp(t,0,1); local s=t-1
    return 1+2.7*s*s*s+1.7*s*s
end
function BattleLab.new(World,shared)
    local self=setmetatable({World=World,active=false,data=nil,outbox={},sending=false,lastSend=-math.huge,portraits={}},BattleLab)
    self.skills=require(shared:WaitForChild("SkillCatalog")); self.audio=BattleAudio.new()
    self.command=shared:WaitForChild("BattleCommand"); self.progressCommand=shared:WaitForChild("Command")
    self.cosmetics=require(shared:WaitForChild("CosmeticCatalog"))
    self.gui=make("ScreenGui",Players.LocalPlayer:WaitForChild("PlayerGui"),"SkyboundBattleLab")
    self.gui.ResetOnSpawn=false; self.gui.DisplayOrder=30; self.gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    self.root=make("Frame",self.gui,"Root"); self.root.Size=UDim2.fromScale(1,1); self.root.BackgroundTransparency=1
    self.panel=make("Frame",self.root,"Lab"); self.panel.Size=UDim2.fromScale(1,1); self.panel.BackgroundTransparency=1; self.panel.Visible=false
    -- One dim sheet sits behind the draft and the final result. It reaches up
    -- into the Roblox top bar so the whole sky dims, never a slab across it.
    self.scrim=make("Frame",self.panel,"Scrim"); self.scrim.BorderSizePixel=0; self.scrim.ZIndex=0
    self.scrim.BackgroundColor3=NAVY; self.scrim.BackgroundTransparency=1
    -- The top of the screen is a fighting-game bar with no backing: each
    -- pilot's face, name, build and chunky armor pips float over the sky at
    -- the edges, with the clock and round wins between them.
    self.header=make("Frame",self.panel,"Header"); self.header.BackgroundTransparency=1; self.header.BorderSizePixel=0
    self.exit=button(self.panel,"Exit","🏠",function() self.audio:ui("back"); self:send("exit") end)
    self.mute=button(self.panel,"Mute","🔊",function()
        local player=Players.LocalPlayer; local muted=player:GetAttribute("SkyboundSoundMuted")~=true
        player:SetAttribute("SkyboundSoundMuted",muted); self.audio:setMuted(muted); if not muted then self.audio:ui("tap") end
    end)
    self.motion=button(self.panel,"Motion","✨",function()
        local player=Players.LocalPlayer; player:SetAttribute("SkyboundReducedMotion",player:GetAttribute("SkyboundReducedMotion")~=true); self.audio:ui("tap")
    end)
    for _,item in ipairs({self.exit,self.mute,self.motion}) do item.ZIndex=30; item.TextSize=19 end
    self.clock=label(self.header,"Clock",52,WHITE,Enum.Font.FredokaOne); self.clock.TextWrapped=false
    outline(self.clock,5); self.clockScale=make("UIScale",self.clock,"Pulse")
    self.wins={}
    for side=1,2 do
        self.wins[side]={}
        for n=1,2 do
            local dot=make("Frame",self.header,"Win"..side..n); dot.BorderSizePixel=0; corner(dot)
            local edge=make("UIStroke",dot,"Edge"); edge.Thickness=3; edge.Color=NAVY
            self.wins[side][n]={frame=dot,scale=make("UIScale",dot,"Pop")}
        end
    end
    self.fighters={}
    for i=1,2 do
        local frame=make("Frame",self.header,"Fighter"..i); frame.BackgroundTransparency=1
        local ring=make("Frame",frame,"Portrait"); ring.BackgroundColor3=NAVY; ring.BorderSizePixel=0; corner(ring)
        local ringEdge=make("UIStroke",ring,"Edge"); ringEdge.Thickness=4
        local face=make("ImageLabel",ring,"Face"); face.BackgroundTransparency=1; face.Size=UDim2.fromScale(1,1); corner(face)
        local bot=label(ring,"Bot",28); bot.Size=UDim2.fromScale(1,1); bot.TextWrapped=false
        local name=label(frame,"PilotName",24,WHITE,Enum.Font.FredokaOne); name.TextWrapped=false; name.TextTruncate=Enum.TextTruncate.AtEnd
        outline(name,3)
        -- The offence pill doubles as a charge meter: it fills while the plane
        -- lines up and winds up, so the next attack never comes as a surprise.
        local power=make("Frame",frame,"Power"); power.BorderSizePixel=0; corner(power,8)
        local charge=make("Frame",power,"Charge"); charge.BorderSizePixel=0; corner(charge,8)
        local powerText=label(power,"Label",13,NAVY); powerText.TextWrapped=false; powerText.Size=UDim2.fromScale(1,1)
        local wilds={}
        for n=1,2 do
            local chip=label(frame,"Wild"..n,13); chip.BackgroundTransparency=0; chip.BackgroundColor3=NAVY; chip.TextWrapped=false; corner(chip)
            local edge=make("UIStroke",chip,"Edge"); edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; edge.Thickness=2
            wilds[n]={label=chip,edge=edge,scale=make("UIScale",chip,"Pulse")}
        end
        local pips={}
        for n=1,5 do
            local pip=make("Frame",frame,"Armor"..n); pip.BorderSizePixel=0; corner(pip,6)
            local edge=make("UIStroke",pip,"Edge"); edge.Thickness=3; edge.Color=NAVY
            pips[n]=pip
        end
        self.fighters[i]={frame=frame,ring=ring,ringEdge=ringEdge,face=face,bot=bot,name=name,power=power,charge=charge,powerText=powerText,wilds=wilds,pips=pips}
    end
    self.status=label(self.panel,"Status",22,WHITE,Enum.Font.FredokaOne); self.status.TextWrapped=false
    self.status.BackgroundColor3=Color3.fromRGB(31,49,69); self.status.BackgroundTransparency=0.08; corner(self.status,10)
    self.statusEdge=surface(self.status,Color3.fromRGB(118,154,187),2)
    self.statusScale=make("UIScale",self.status,"Pop")
    -- A first match gets one plain sentence at the bottom of the screen that
    -- says what to watch for right now.
    self.coach=label(self.panel,"Coach",16,WHITE); self.coach.Visible=false; self.coach.ZIndex=12
    self.coach.BackgroundColor3=NAVY; self.coach.BackgroundTransparency=0.1; corner(self.coach,12)
    self.coachEdge=make("UIStroke",self.coach,"Edge"); self.coachEdge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    self.coachEdge.Thickness=3; self.coachEdge.Color=GOLD
    self.coachScale=make("UIScale",self.coach,"Pop")
    self.experimental=label(self.panel,"ExperimentalRoster",11,GOLD); self.experimental.Text="EXPERIMENTAL ROSTER"
    self.experimental.BackgroundColor3=NAVY; self.experimental.BackgroundTransparency=0.08; corner(self.experimental,8)
    -- The draft: big illustrated cards for one slot of the plane at a time,
    -- one tap to choose, one to lock.
    self.picker=make("ScrollingFrame",self.panel,"Picker"); self.picker.BackgroundTransparency=1; self.picker.BorderSizePixel=0
    self.picker.ScrollBarThickness=3; self.picker.CanvasSize=UDim2.fromOffset(0,0); self.picker.ScrollingDirection=Enum.ScrollingDirection.Y
    self.pickTitle=label(self.picker,"Title",40,WHITE,Enum.Font.FredokaOne); self.pickTitle.TextWrapped=false; outline(self.pickTitle,4)
    self.pickHint=label(self.picker,"Hint",14,WHITE); outline(self.pickHint,2)
    self.cardList=make("ScrollingFrame",self.picker,"Cards"); self.cardList.BackgroundTransparency=1
    self.cardList.BorderSizePixel=0; self.cardList.ScrollBarThickness=4; self.cardList.ScrollBarImageColor3=GOLD
    self.cardList.ScrollingDirection=Enum.ScrollingDirection.Y; self.cardList.CanvasSize=UDim2.fromOffset(0,0)
    self.powerCards={}
    -- All catalog entries have one reusable card. Eligibility and visibility are
    -- resolved by the snapshot; catalog presence never grants access.
    for index,spec in ipairs(self.skills.all()) do
        local card=make("TextButton",self.cardList,spec.id)
        card.Text=""; card.AutoButtonColor=false; card.BorderSizePixel=0; card.Selectable=true; corner(card,22)
        local edge=make("UIStroke",card,"Edge"); edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; edge.Thickness=5
        local shade=make("UIGradient",card,"Shading"); shade.Rotation=90
        shade.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(200,196,214))
        local tag=label(card,"Tag",12,NAVY); tag.BackgroundColor3=WHITE; tag.BackgroundTransparency=0; tag.TextWrapped=false; corner(tag,9)
        local icon=label(card,"Icon",60); icon.TextWrapped=false
        local word=label(card,"Word",20,WHITE,Enum.Font.FredokaOne); word.Rotation=index%2==0 and 9 or -9
        word.TextWrapped=false; word.Text=spec.word or ""; outline(word,3)
        local name=label(card,"SkillName",30,NAVY,Enum.Font.FredokaOne); name.Text=string.upper(spec.name)
        local promise=label(card,"Promise",14,NAVY); promise.Text=spec.promise
        local scale=make("UIScale",card,"Pop")
        card.Activated:Connect(function() self:choose(spec.id) end)
        icon.Text=spec.icon
        self.powerCards[spec.id]={button=card,spec=spec,edge=edge,tag=tag,icon=icon,word=word,name=name,promise=promise,scale=scale,color=tint(spec.color)}
    end
    -- The loadout bar says what is on the plane: one tile for the attack and
    -- one for each wild card slot. Tapping a tile picks the slot to change.
    self.slotTiles={}
    for slot=0,2 do
        local tile=make("TextButton",self.picker,"Slot"..slot)
        tile.Text=""; tile.AutoButtonColor=false; tile.BorderSizePixel=0; tile.Selectable=true; corner(tile,12)
        local edge=make("UIStroke",tile,"Edge"); edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
        local caption=label(tile,"Caption",10,WHITE); caption.TextWrapped=false
        local value=label(tile,"Value",15,WHITE,Enum.Font.FredokaOne); value.TextWrapped=false
        tile.Activated:Connect(function() self:focusSlot(slot) end)
        self.slotTiles[slot]={button=tile,edge=edge,caption=caption,value=value,scale=make("UIScale",tile,"Pop")}
    end
    self.fightButton=button(self.picker,"Lock","LOCK IN",function() self:fight() end)
    self.fightButton.BackgroundColor3=GREEN; self.fightButton.Font=Enum.Font.FredokaOne
    self.fightButton.Edge.Color=WHITE; self.fightButton.Edge.Transparency=0.1; self.fightButton.Edge.Thickness=3
    -- Both picks slam in from the sides while the countdown runs.
    self.reveal=make("Frame",self.panel,"SimultaneousReveal"); self.reveal.BackgroundTransparency=1; self.reveal.Visible=false
    self.revealTitle=label(self.reveal,"Title",30,GOLD,Enum.Font.FredokaOne); self.revealTitle.TextWrapped=false; outline(self.revealTitle,4)
    self.revealVs=label(self.reveal,"Versus",34,WHITE,Enum.Font.FredokaOne); self.revealVs.Text="VS"; self.revealVs.TextWrapped=false
    self.revealVs.Rotation=-8; outline(self.revealVs,4)
    self.revealPersonality=label(self.reveal,"Personality",13,WHITE); outline(self.revealPersonality,2)
    self.reveals={}
    for side=1,2 do
        local frame=make("Frame",self.reveal,"Pilot"..side); frame.BorderSizePixel=0; corner(frame,18)
        local edge=make("UIStroke",frame,"Edge"); edge.Thickness=5; edge.Color=NAVY
        local shade=make("UIGradient",frame,"Shading"); shade.Rotation=90
        shade.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(200,196,214))
        local name=label(frame,"Identity",11,NAVY); name.BackgroundColor3=WHITE; name.BackgroundTransparency=0; name.TextWrapped=false
        name.TextTruncate=Enum.TextTruncate.AtEnd; corner(name,8)
        local icon=label(frame,"Icon",40); icon.TextWrapped=false
        local skill=label(frame,"Skill",26,NAVY,Enum.Font.FredokaOne); skill.TextWrapped=false; skill.TextXAlignment=Enum.TextXAlignment.Left
        self.reveals[side]={frame=frame,name=name,icon=icon,skill=skill}
    end
    self.search=make("Frame",self.panel,"Searching"); self.search.BackgroundTransparency=1
    self.searchTitle=label(self.search,"Title",46,WHITE,Enum.Font.FredokaOne); self.searchTitle.TextWrapped=false; outline(self.searchTitle,5)
    self.searchScale=make("UIScale",self.searchTitle,"Pulse")
    self.searchHint=label(self.search,"Hint",16,WHITE); outline(self.searchHint,2)
    self.cancel=button(self.search,"Cancel","Cancel search",function() self.audio:ui("back"); self:send("exit") end)
    -- The result is a moment of its own: a slammed-in banner, the winner's
    -- face under a crown, three numbers, and REMATCH as the obvious next tap.
    self.result=make("ScrollingFrame",self.panel,"Result"); self.result.BorderSizePixel=0; self.result.ScrollBarThickness=3
    self.result.CanvasSize=UDim2.fromOffset(0,0); self.result.ScrollingDirection=Enum.ScrollingDirection.Y
    self.result.BackgroundTransparency=1; self.result.ZIndex=20; self.result.Visible=false
    self.confetti={}
    for n=1,40 do
        local item=make("Frame",self.result,"Confetti"); item.BorderSizePixel=0; item.ZIndex=20
        item.BackgroundColor3=({GOLD,Color3.fromRGB(255,113,111),Color3.fromRGB(70,221,234),WHITE,Color3.fromRGB(160,128,255)})[n%5+1]
        self.confetti[n]={frame=item,x=math.random(),speed=120+math.random()*200,offset=math.random(),spin=(math.random()-0.5)*500,sway=math.random()*6}
    end
    self.banner=label(self.result,"Banner",96,GOLD,Enum.Font.FredokaOne); self.banner.TextWrapped=false
    self.banner.ZIndex=22; self.banner.Rotation=-3; outline(self.banner,8)
    self.bannerScale=make("UIScale",self.banner,"Slam")
    self.resultLine=label(self.result,"Line",18,WHITE); self.resultLine.ZIndex=22; outline(self.resultLine,3)
    -- Between rounds the facts sit on a plate so they read over the wreckage.
    self.roundPlate=make("Frame",self.result,"RoundPlate"); self.roundPlate.BackgroundColor3=NAVY; self.roundPlate.BackgroundTransparency=0.12
    self.roundPlate.BorderSizePixel=0; self.roundPlate.ZIndex=20; self.roundPlate.Visible=false; corner(self.roundPlate,18)
    self.roundPlateEdge=make("UIStroke",self.roundPlate,"Edge"); self.roundPlateEdge.Thickness=4
    self.winnerRing=make("Frame",self.result,"Winner"); self.winnerRing.BackgroundColor3=NAVY; self.winnerRing.BorderSizePixel=0
    self.winnerRing.ZIndex=21; corner(self.winnerRing)
    self.winnerEdge=make("UIStroke",self.winnerRing,"Edge"); self.winnerEdge.Thickness=6
    self.winnerFace=make("ImageLabel",self.winnerRing,"Face"); self.winnerFace.BackgroundTransparency=1
    self.winnerFace.Size=UDim2.fromScale(1,1); self.winnerFace.ZIndex=21; corner(self.winnerFace)
    self.winnerEmoji=label(self.winnerRing,"Emoji",48); self.winnerEmoji.Size=UDim2.fromScale(1,1); self.winnerEmoji.TextWrapped=false; self.winnerEmoji.ZIndex=22
    self.crown=label(self.result,"Crown",44); self.crown.Text="👑"; self.crown.TextWrapped=false; self.crown.ZIndex=23; self.crown.Rotation=-12
    self.stats={}
    for index=1,3 do
        local chip=make("Frame",self.result,"Stat"..index); chip.BackgroundColor3=Color3.fromRGB(30,46,72); chip.BorderSizePixel=0; chip.ZIndex=21
        corner(chip,12)
        local edge=make("UIStroke",chip,"Edge"); edge.Thickness=3
        local value=label(chip,"Value",28,WHITE,Enum.Font.FredokaOne); value.ZIndex=22; value.TextWrapped=false
        local caption=label(chip,"Caption",11,MUTED); caption.ZIndex=22; caption.TextWrapped=false
        self.stats[index]={frame=chip,value=value,caption=caption,edge=edge}
    end
    self.replay=button(self.result,"Replay","REMATCH",function() self:rematch() end)
    self.replay.BackgroundColor3=GREEN; self.replay.Font=Enum.Font.FredokaOne
    self.replay.Edge.Color=WHITE; self.replay.Edge.Transparency=0.1; self.replay.Edge.Thickness=3
    self.edit=button(self.result,"NextOpponent","Next rival",function() self.audio:ui("confirm"); self:send("again") end)
    self.leave=button(self.result,"Leave","Hangar",function()
        self.audio:ui("back"); self:send(self.data and self.data.rematchVotes and self.data.rematchVotes[2] and "rematchDecline" or "exit")
    end)
    for _,item in ipairs({self.replay,self.edit,self.leave}) do item.ZIndex=22 end
    self.resultHint=label(self.result,"Hint",13,WHITE); self.resultHint.ZIndex=22; outline(self.resultHint,2)
    self.rewardCard=make("Frame",self.result,"CosmeticRewards"); self.rewardCard.BackgroundColor3=Color3.fromRGB(24,38,62)
    self.rewardCard.BorderSizePixel=0; self.rewardCard.ZIndex=21; corner(self.rewardCard,16)
    local rewardEdge=make("UIStroke",self.rewardCard,"Edge"); rewardEdge.Thickness=3; rewardEdge.Color=GOLD
    self.rewardTitle=label(self.rewardCard,"Earned",22,GOLD,Enum.Font.FredokaOne); self.rewardTitle.ZIndex=22; self.rewardTitle.TextWrapped=false
    self.rewardStatus=label(self.rewardCard,"SaveStatus",11,MUTED); self.rewardStatus.ZIndex=22
    self.goalName=label(self.rewardCard,"Goal",14); self.goalName.ZIndex=22; self.goalName.TextWrapped=false
    self.goalPreview=make("Frame",self.rewardCard,"GoalProgress"); self.goalPreview.BorderSizePixel=0; self.goalPreview.ZIndex=22
    self.goalPreview.BackgroundColor3=NAVY; corner(self.goalPreview)
    self.goalFill=make("Frame",self.goalPreview,"Fill"); self.goalFill.BorderSizePixel=0; self.goalFill.ZIndex=23
    self.goalFill.BackgroundColor3=Color3.new(1,1,1); corner(self.goalFill)
    self.goalGradient=make("UIGradient",self.goalFill,"TrailColors")
    self.goalAction=button(self.rewardCard,"GoalAction","",function() self:goalActionRequested() end); self.goalAction.ZIndex=22
    self.starterTitle=label(self.rewardCard,"FirstMatchGift",15,GOLD,Enum.Font.FredokaOne); self.starterTitle.ZIndex=22
    self.starterCards={}
    for _,id in ipairs(self.cosmetics.STARTER_CHOICES or {}) do
        local item=self.cosmetics.get(id)
        local card=button(self.rewardCard,"Claim"..id,"",function() self:claimStarter(id) end)
        card.ZIndex=22; card.TextSize=13
        local swatch=make("Frame",card,"TrailPreview"); swatch.BorderSizePixel=0; swatch.ZIndex=23
        swatch.BackgroundColor3=Color3.new(1,1,1); corner(swatch)
        local gradient=make("UIGradient",swatch,"Colors"); gradient.Color=ColorSequence.new(tint(item.color),tint(item.secondaryColor))
        self.starterCards[#self.starterCards+1]={button=card,swatch=swatch,item=item}
    end
    -- Full-screen beats: a white impact flash and the 3-2-1-FIGHT call.
    self.flash=make("Frame",self.panel,"ImpactFlash"); self.flash.Size=UDim2.fromScale(1,1)
    self.flash.BorderSizePixel=0; self.flash.Active=false; self.flash.BackgroundColor3=Color3.new(1,1,1); self.flash.BackgroundTransparency=1; self.flash.ZIndex=40
    self.count=label(self.panel,"Countdown",150,GOLD,Enum.Font.FredokaOne)
    self.count.TextWrapped=false; self.count.ZIndex=41; self.count.AnchorPoint=Vector2.new(0.5,0.5)
    self.count.Size=UDim2.fromOffset(900,220); self.count.Visible=false
    self.countEdge=outline(self.count,8); self.countScale=make("UIScale",self.count,"Pop")
    self.snapshotConnection=shared:WaitForChild("BattleSnapshot").OnClientEvent:Connect(function(data) self:receive(data) end)
    self:send("request"); return self
end
function BattleLab:receive(data)
    if type(data)~="table" then return end
    local old=self.data
    self.active=data.active==true; self.data=data
    local feedback=data.cosmeticFeedback
    if feedback and feedback.id~=self.lastCosmeticFeedback then
        self.lastCosmeticFeedback=feedback.id
        if self.cosmeticPending then self.audio:ui(feedback.ok and "purchase" or "error"); self.cosmeticPending=nil end
        self.cosmeticMessage=feedback.message; self.cosmeticMessageAt=os.clock()
    end
    if data.phase=="Countdown" and (not old or old.roundId~=data.roundId or old.phase~="Countdown") then
        self.sameBuildReplay=old and old.matchId==data.matchId and self.revealedStage==data.stage
        self.revealedStage=data.stage; self.revealedAt=os.clock()
    end
    if self.active then
        if not self.view then self.view=BattleView.new(self.World,function(cue)
            if cue.kind=="crash" then self.audio:playCrash(cue.roundId,cue.actor) end
        end,{pilots=PilotAvatar,skills=self.skills}) end
        for i,identity in ipairs(data.players or {}) do
            if i>2 then break end
            local id=identity.userId
            if type(id)=="number" and id>0 and not self.portraits[id] then
                self.portraits[id]=""
                task.spawn(function()
                    local ok,image=pcall(function() return Players:GetUserThumbnailAsync(id,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100) end)
                    if ok then self.portraits[id]=image end
                end)
            end
        end
    elseif self.view then self.view:destroy(); self.view=nil end
    self.panel.Visible=self.active
    Players.LocalPlayer:SetAttribute("BattleLabPhase",self.active and data.phase or "Inactive")
end
function BattleLab:send(kind,payload)
    payload=payload or {}; payload.kind=kind
    if self.data and kind~="request" and kind~="enter" then
        payload.matchId=self.data.matchId; payload.stage=self.data.stage; payload.offerRevision=self.data.offerRevision
    end
    table.insert(self.outbox,payload)
    if self.sending then return end
    self.sending=true
    task.spawn(function()
        while #self.outbox>0 do
            local delay=0.08-(os.clock()-self.lastSend); if delay>0 then task.wait(delay) end
            self.command:FireServer(table.remove(self.outbox,1)); self.lastSend=os.clock()
        end
        self.sending=false
    end)
end
function BattleLab:isActive() return self.active end
function BattleLab:clockSeconds(serverTime)
    local data=self.data or {}
    local deadline=data.phase=="Fight" and data.fightDeadline or data.pickDeadline or data.endsAt
    if data.phase=="Fight" and deadline and data.matchDeadline then deadline=math.min(deadline,data.matchDeadline) end
    -- Simulation catch-up is bounded after a stall; the round deadline is not.
    return math.max(0,math.ceil((deadline or serverTime)-serverTime))
end
-- The pilot's working loadout for this pick. It starts as the plane that just
-- flew and opens on the slot that still needs a card.
function BattleLab:loadout()
    local data=self.data or {}
    local key=tostring(data.matchId)..":"..tostring(data.stage)
    if self.draftKey~=key or not self.draft then
        local source=data.draft or {}
        self.draftKey=key; self.draft={offenceId=source.offenceId,wildIds=table.clone(source.wildIds or {})}
        self.draftHeld=#self.draft.wildIds
        self.focus=(self.draft.offenceId and self.draftHeld<(data.slots or 0)) and self.draftHeld+1 or 0
    end
    return self.draft
end
function BattleLab:loadoutReady()
    local draft=self:loadout()
    return draft.offenceId~=nil and #draft.wildIds==((self.data or {}).slots or 0)
end
-- Slot 0 is the attack; slots 1 and 2 are the wild cards.
function BattleLab:focusSlot(slot)
    local data=self.data
    if not data or data.phase~="Pick" or (data.locked and data.locked[1]) then return end
    local draft=self:loadout()
    if slot<0 or slot>(data.slots or 0) or slot>#draft.wildIds+1 or slot==self.focus then return end
    self.focus=slot; self.audio:ui("tap")
end
function BattleLab:choose(skillId)
    local data=self.data
    if not data or data.phase~="Pick" or (data.locked and data.locked[1]) then return end
    local draft=self:loadout(); local offer=data.offer or {}
    if self.focus==0 then
        if not table.find(offer.offences or {},skillId) or draft.offenceId==skillId then return end
        draft.offenceId=skillId; self:send("pick",{slot="offence",skillId=skillId})
    else
        -- A wild card already on the plane cannot fill a second slot.
        if not table.find(offer.wilds or {},skillId) or table.find(draft.wildIds,skillId) then return end
        draft.wildIds[self.focus]=skillId; self:send("pick",{slot="wild",index=self.focus,skillId=skillId})
    end
    self.pickedAt=os.clock(); self.audio:ui(false)
end
function BattleLab:fight()
    local data=self.data
    if not data or data.phase~="Pick" or (data.locked and data.locked[1]) or not self:loadoutReady() then return end
    -- The lock carries the whole loadout the pilot is looking at.
    self.audio:ui(true); self:send("lock",{offenceId=self.draft.offenceId,wildIds=table.clone(self.draft.wildIds)})
end
function BattleLab:rematch()
    local data=self.data
    if not data or data.phase~="MatchOver" or data.rivalGone or (data.rematchVotes and data.rematchVotes[1]) then return end
    self.audio:ui(true); self:send("rematch")
end
function BattleLab:destroy()
    if self.snapshotConnection then self.snapshotConnection:Disconnect() end
    if self.view then self.view:destroy(); self.view=nil end
    self.audio:destroy(); self.gui:Destroy(); self.active=false; self.outbox={}
end
function BattleLab:cosmeticCommand(kind,itemId)
    local data=self.data
    if not data or data.phase~="MatchOver" or not data.economy or not data.economy.canShop then return end
    if self.cosmeticPending and os.clock()-self.cosmeticPending<3 then return end
    self.cosmeticPending=os.clock(); self.progressCommand:FireServer({kind=kind,itemId=itemId})
end
function BattleLab:claimStarter(itemId)
    local economy=self.data and self.data.economy
    if not economy or not economy.progression or not economy.progression.starterAvailable then return end
    if not table.find(economy.starterChoices or {},itemId) then return end
    self:cosmeticCommand("claimStarter",itemId)
end
function BattleLab:goalActionRequested()
    local economy=self.data and self.data.economy; local goal=economy and economy.goal
    if not goal or economy.equippedTrail==goal.id then return end
    if not goal.owned and (economy.credits or 0)<goal.price then self.audio:ui("error"); return end
    self:cosmeticCommand(goal.owned and "equipCosmetic" or "buyCosmetic",goal.id)
end
function BattleLab:showRewards(data,x,y,width)
    local reward=data.reward; local economy=data.economy
    self.rewardCard.Visible=data.phase=="MatchOver" and economy~=nil
    if not self.rewardCard.Visible then return y end
    local progression=economy.progression or {}; local gift=progression.starterAvailable==true
    local height=gift and 232 or 156; place(self.rewardCard,x,y,width,height)
    local bank=economy.credits or 0; local coins=reward and reward.coins or 0
    place(self.rewardTitle,12,8,width-24,28); self.rewardTitle.TextSize=width<450 and 18 or 22
    self.rewardTitle.Text=(coins>0 and ("+"..tostring(coins).." COINS   ·   ") or "")..tostring(bank).." IN YOUR BANK"
    local saves={saved="Saved",session_only="Studio session only · resets when Play stops",pending="Saving…",unavailable="Cloud save unavailable",loading="Loading…"}
    local status=data.saveStatus or (reward and reward.status) or "loading"
    place(self.rewardStatus,12,36,width-24,16)
    local message=saves[status] or status
    if self.cosmeticMessage and os.clock()-(self.cosmeticMessageAt or 0)<4 then message=self.cosmeticMessage.." · "..message end
    local noAward={early_departure="Match ended too early for a completion reward.",diagnostic="Test match · Rewards are disabled.",
        abandoned="Leaving early earns no completion reward.",uncompleted="Complete a match to earn coins."}
    if reward and reward.eligible==false then
        self.rewardStatus.Text=(noAward[reward.reason] or "No completion reward for this match.").." · "..message
    else
        self.rewardStatus.Text=(progression.title or "Rookie").." · "..tostring(progression.matches or 0)..((progression.matches or 0)==1 and " match · " or " matches · ")..message
    end
    local goal=economy.goal; local item=goal and self.cosmetics.get(goal.id)
    self.goalPreview.Visible=item~=nil; self.goalName.Visible=item~=nil; self.goalAction.Visible=item~=nil
    if item then
        -- The next unlock fills up in the trail's own colours.
        place(self.goalName,12,56,width-24,18); self.goalName.TextSize=width<450 and 12 or 14
        self.goalName.Text=string.upper(item.name).."  ·  "..(goal.owned and "OWNED" or (tostring(math.min(bank,item.price)).." / "..tostring(item.price).." COINS"))
        place(self.goalPreview,12,78,width-24,16)
        local fraction=goal.owned and 1 or math.clamp(bank/math.max(1,item.price),0,1)
        self.goalFill.Size=UDim2.new(math.max(fraction,0.04),0,1,0)
        self.goalGradient.Color=ColorSequence.new(tint(item.color),tint(item.secondaryColor))
        place(self.goalAction,12,102,width-24,44)
        local equipped=economy.equippedTrail==goal.id; local ready=goal.owned or bank>=goal.price
        local pending=self.cosmeticPending and os.clock()-self.cosmeticPending<3
        self.goalAction.Text=pending and "WORKING…" or (equipped and "EQUIPPED · COSMETIC ONLY" or (goal.owned and "EQUIP YOUR TRAIL" or (ready and "BUY TRAIL · "..tostring(goal.price).." COINS" or "EARN "..tostring(math.max(0,goal.price-bank)).." MORE · COSMETIC ONLY")))
        self.goalAction.TextSize=width<450 and 12 or 14
        local canAct=economy.canShop and ready and not equipped and not pending
        self.goalAction.BackgroundColor3=canAct and GREEN or Color3.fromRGB(44,63,86)
        enabled(self.goalAction,canAct)
    end
    self.starterTitle.Visible=gift
    place(self.starterTitle,8,154,width-16,22); self.starterTitle.Text="🎁 FIRST MATCH GIFT · CHOOSE ONE TRAIL"
    self.starterTitle.TextSize=width<450 and 12 or 15
    for index,card in ipairs(self.starterCards) do
        card.button.Visible=gift
        local cardWidth=(width-32)/2; place(card.button,12+(index-1)*(cardWidth+8),180,cardWidth,44)
        place(card.swatch,10,6,cardWidth-20,6)
        card.button.Text=card.item.name.." · Equip"; card.button.TextSize=width<450 and 11 or 13
        enabled(card.button,economy.canShop and not (self.cosmeticPending and os.clock()-self.cosmeticPending<3))
    end
    return y+height+10
end
function BattleLab:buildIcons(build)
    build=build or {}; local icons={}
    for _,id in ipairs({build.offenceId or "",(build.wildIds or {})[1] or "",(build.wildIds or {})[2] or ""}) do
        local skill=self.skills.get(id); icons[#icons+1]=skill and skill.icon or "○"
    end
    return table.concat(icons,"  ")
end
function BattleLab:buildText(build)
    build=build or {}; local names={}
    for _,id in ipairs({build.offenceId or "",(build.wildIds or {})[1] or "",(build.wildIds or {})[2] or ""}) do
        local skill=self.skills.get(id); names[#names+1]=skill and skill.name or "—"
    end
    return table.concat(names,"  ·  ")
end
-- Facts are authoritative records, never inferred from the appearance of an effect.
function BattleLab:factText(result)
    if not result then return "" end
    local facts={}
    for _,fact in ipairs(result.facts or {}) do
        if #facts>=2 then break end
        if type(fact)=="string" then facts[#facts+1]=fact
        elseif type(fact)=="table" then
            if type(fact.text)=="string" then facts[#facts+1]=fact.text
            else
                local actor=fact.actor==1 and "Your" or "Rival's"
                local skill=self.skills.get(fact.skillId or fact.skill or "")
                local name=skill and skill.name or "attack"
                if fact.outcome=="blocked" or fact.kind=="blocked" then facts[#facts+1]=actor.." "..name.." blocked a hit."
                elseif fact.kind=="hit" or fact.outcome=="hit" or fact.outcome=="knockout" then
                    facts[#facts+1]=actor.." "..name.." "..((fact.outcome=="knockout" or fact.final) and "landed the final hit." or "removed one armor.")
                elseif fact.kind=="second_wind" then facts[#facts+1]=actor.." Second Wind activated at the last armor." end
            end
        end
    end
    if #facts>0 then return table.concat(facts,"  ") end
    local reason=result.reason
    if reason=="timeout" then return "Time ran out. More armor wins; equal armor goes to sudden death." end
    if reason=="disconnect" or reason=="forfeit" or reason=="departure" then return "The rival left before the match finished." end
    if reason=="round_cap" then return "Five rounds played. Completed round wins decide the match." end
    if reason=="match_cap" or reason=="match_timeout" then return "The match clock ended. Only completed round wins count." end
    if result.winner==0 then return "No point awarded. Drawn rounds keep the same builds." end
    return "Three armor lost ends the round. First to two round wins takes the match."
end
-- Record an actual visible terminal reward summary once for each match.
-- Retransmitted snapshots and scrolling cannot inflate the replay funnel.
function BattleLab:reportRewardShown(data)
    if not data or data.phase~="MatchOver" or type(data.reward)~="table" or data.matchId==nil
        or not self.result or self.result.Visible~=true then return end
    self.rewardShownMatches=self.rewardShownMatches or {}
    if self.rewardShownMatches[data.matchId] then return end
    self.rewardShownMatches[data.matchId]=true
    self:send("rewardShown")
end
-- Waits for the knockout to play out in the arena, then takes the screen.
function BattleLab:showResult(data,accents,width,height,top,compact,short)
    local terminal=data.phase=="MatchOver" or data.phase=="Results"
    if not resultPhase(data.phase) then self.result.Visible=false; self.roundPlate.Visible=false; self.resultKey=nil; self.resultDim=1; return end
    local key=tostring(data.matchId)..":"..tostring(data.roundId)..":"..data.phase
    if self.resultKey~=key then self.resultKey=key; self.resultAt=os.clock(); self.resultSounded=false end
    local sim=data.simulation or {}
    local result=terminal and data.result or data.roundResult
    result=result or sim
    local winner=result.winner or 0
    local age=os.clock()-self.resultAt-(terminal and (sim.reason=="knockout" and 1.2 or 0.4) or 0.3)
    self.result.Visible=age>0
    if age<=0 then self.resultDim=1; return end
    local outcome=winner==1 and "win" or (winner==2 and "lose" or "draw")
    if terminal and not self.resultSounded then self.resultSounded=true; self.audio:result(outcome) end
    local area=height-top; place(self.result,0,top,width,area)
    -- Only the final result dims the sky; a round call floats over the crash.
    self.resultDim=terminal and 1-0.55*math.clamp(age/0.25,0,1) or 1
    local content=math.min(width-32,640); local x=(width-content)/2
    local bannerHeight=compact and 60 or (short and 66 or 104)
    local economy=terminal and data.phase=="MatchOver" and data.economy or nil
    local gift=economy and economy.progression and economy.progression.starterAvailable==true
    local face=(short or not terminal) and 0 or math.clamp(area*0.16,56,110)
    -- The crown sits above the portrait; leave it room under the result line.
    local crownGap=math.max(14,face*0.3)
    local lineHeight=compact and 36 or 30
    local statHeight=short and 46 or 62
    local buttonsHeight=compact and 112 or 64
    local total=bannerHeight+lineHeight
    if terminal then total=total+(face>0 and face+crownGap+8 or 0)+statHeight+16+buttonsHeight+30+(economy and (gift and 242 or 166) or 0)
    else total=total+statHeight+44 end
    local y=terminal and math.max(4,(area-total)/2) or math.max(8,area*0.3-bannerHeight/2)
    place(self.banner,0,y,width,bannerHeight)
    self.banner.Text=terminal and (outcome=="win" and "VICTORY!" or (outcome=="lose" and "DEFEAT" or "DRAW!"))
        or (outcome=="win" and "ROUND WON!" or (outcome=="lose" and "ROUND LOST" or "ROUND DRAW"))
    self.banner.TextColor3=outcome=="win" and GOLD or (outcome=="lose" and Color3.fromRGB(150,170,205) or WHITE)
    self.banner.TextSize=math.min(bannerHeight*0.95,width*(terminal and 0.17 or 0.12))
    self.bannerScale.Scale=self.reducedMotion and 1 or 1+1.6*math.max(0,1-age/0.2)^2
    y=y+bannerHeight
    place(self.resultLine,x,y,content,lineHeight); self.resultLine.TextSize=compact and (terminal and 13 or 14) or (terminal and 18 or 20)
    self.resultLine.Text=self:factText(result)
    local lineTop=y
    y=y+lineHeight
    local settled=age>0.3
    self.winnerRing.Visible=face>0 and settled; self.crown.Visible=face>0 and settled and outcome~="draw"
    local statWidth=math.min(170,(width-40)/3)
    local function showStats(top,values,captions)
        for index,stat in ipairs(self.stats) do
            stat.frame.Visible=settled
            place(stat.frame,width/2-statWidth*1.5-8+(index-1)*(statWidth+8),top,statWidth,statHeight)
            place(stat.value,0,2,statWidth,statHeight*0.6); stat.value.Text=values[index]; stat.value.TextSize=statHeight*0.46
            stat.value.TextColor3=index==3 and GOLD or WHITE
            place(stat.caption,0,statHeight*0.62,statWidth,statHeight*0.3); stat.caption.Text=captions[index]; stat.caption.TextSize=compact and 9 or 11
            stat.edge.Color=index<3 and accents[index] or GOLD
        end
    end
    self.roundPlate.Visible=not terminal
    for _,item in ipairs({self.replay,self.edit,self.leave}) do item.Visible=terminal and age>0.5 end
    self.resultHint.Visible=settled
    if not terminal then
        -- Who hit whom is the whole story of a round, so it gets real numbers.
        local fighters=sim.fighters or {}
        local taken=function(side) return tostring(3-math.clamp((fighters[side] or {}).armor or 3,0,3)) end
        showStats(y+4,{taken(2),taken(1),tostring(math.floor(sim.elapsed or 0)).."s"},{"YOUR HITS","RIVAL HITS","ROUND TIME"})
        y=y+statHeight+10
        place(self.resultHint,x,y,content,24); self.resultHint.TextSize=compact and 13 or 16
        self.resultHint.Text=winner==0 and "Same builds. Going again!"
            or (data.guided and ((data.stage or 1)<=1 and "Next: pick a trick for your plane!" or "Next: pick one more trick!")
                or "Next up: add a wild card. Swap anything you like!")
        local plateWidth=math.min(width-16,math.max(3*statWidth+48,compact and 0 or 560))
        place(self.roundPlate,(width-plateWidth)/2,lineTop-8,plateWidth,y+30-lineTop+8)
        self.roundPlateEdge.Color=outcome=="draw" and WHITE or accents[winner]
        self.lastRound={matchId=data.matchId,text=self.resultLine.Text,draw=winner==0}
        self.rewardCard.Visible=false; self.result.CanvasSize=UDim2.fromOffset(0,0)
        for _,piece in ipairs(self.confetti) do piece.frame.Visible=false end
        return
    end
    if face>0 then
        y=y+crownGap
        place(self.winnerRing,(width-face)/2,y,face,face)
        local champion=(data.players or {})[winner] or {}
        self.winnerEdge.Color=outcome=="draw" and WHITE or accents[winner]
        self.winnerFace.Image=outcome~="draw" and not champion.bot and self.portraits[champion.userId] or ""
        self.winnerEmoji.Text=outcome=="draw" and "🤝" or (champion.bot and (champion.portrait or "🤖") or "")
        self.winnerEmoji.TextSize=face*0.55
        place(self.crown,(width-face)/2-face*0.18,y-face*0.32,face*0.6,face*0.6)
        self.crown.TextSize=face*0.46
        y=y+face+8
    end
    local score=result.score or data.score or {0,0}
    local coins=data.reward and data.reward.coins or 0
    showStats(y,{tostring(score[1] or 0),tostring(score[2] or 0),coins>0 and "+"..tostring(coins) or "—"},{"YOUR ROUNDS","RIVAL ROUNDS","COINS"})
    y=y+statHeight+16
    local votes=data.rematchVotes or {}
    local waiting=votes[1]==true; local gone=data.rivalGone==true
    self.replay.Text=gone and "RIVAL LEFT" or (waiting and "WAITING FOR RIVAL…" or (votes[2] and "ACCEPT REMATCH" or "REMATCH"))
    enabled(self.replay,not waiting and not gone)
    if compact then
        place(self.replay,16,y,width-32,56)
        place(self.edit,16,y+62,(width-40)/2,44); place(self.leave,24+(width-40)/2,y+62,(width-40)/2,44)
    else
        local main=math.min(300,width*0.3); local sideWidth=math.min(170,width*0.16)
        local row=main+2*(sideWidth+10)
        place(self.replay,(width-row)/2+sideWidth+10,y,main,64)
        place(self.edit,(width-row)/2,y+10,sideWidth,46)
        place(self.leave,(width-row)/2+sideWidth+10+main+10,y+10,sideWidth,46)
    end
    -- A gentle pulse keeps the eye on the next fight.
    local pulse=(waiting or gone or self.reducedMotion) and 0 or 2*math.sin(os.clock()*5)
    self.replay.TextSize=((waiting or gone) and 18 or (compact and 26 or 30))+pulse
    y=y+buttonsHeight+4
    place(self.resultHint,x,y,content,22); self.resultHint.TextSize=compact and 11 or 13
    self.resultHint.Text=gone and "Choose Next rival to find a new match."
        or (data.guided and "Next match you pick your attack too!"..(gift and " Your gift is below ↓" or "")
            or (gift and "Your first-match gift is below ↓" or "Rematch keeps this rival. Both pilots start a fresh build."))
    local endY=self:showRewards(data,x,y+28,content)
    self.result.CanvasSize=UDim2.fromOffset(0,endY>area and endY+8 or 0)
    self:reportRewardShown(data)
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
-- The one sentence a first-time pilot needs at this moment, or nil. It only
-- reads the server snapshot, so it can never promise something untrue.
function BattleLab:coachText(data)
    if not data or data.guided~=true then return nil end
    local fighting=data.phase=="Fight"
    if not fighting and data.phase~="Countdown" then return nil end
    local build=(data.settings or {})[1] or {}
    local newest=self.skills.get((build.wildIds or {})[#(build.wildIds or {})] or "")
    if newest then return "Watch for your "..newest.icon.." "..newest.name..": "..(newest.when or newest.promise).."!" end
    if not fighting then return "Your plane flies and attacks by itself. Just watch this one!" end
    local fighters=(data.simulation or {}).fighters or {}
    if ((fighters[1] or {}).armor or 3)<3 or ((fighters[2] or {}).armor or 3)<3 then
        return "Each hit breaks one armor block. Break all 3 to win the round!"
    end
    local offence=self.skills.get(build.offenceId or "")
    return "You start on the left. Your "..(offence and offence.icon.." "..offence.name or "plane").." attacks by itself!"
end
-- Turns fresh authoritative combat events into the play-by-play and HUD
-- flashes. A louder call is never talked over by a quieter one.
function BattleLab:call(text,tone,weight,seconds)
    local now=os.clock()
    if now<(self.feedbackUntil or 0) and weight<(self.feedbackWeight or 0) then return end
    if text~=self.feedbackText or now>=(self.feedbackUntil or 0) then self.feedbackAt=now end
    self.feedbackText=text; self.feedbackTone=tone; self.feedbackWeight=weight; self.feedbackUntil=now+seconds
end
function BattleLab:feedback(data)
    local sim=data.simulation or {}
    if self.feedbackRound~=data.roundId then
        self.feedbackRound=data.roundId; self.eventSerial=0; self.feedbackUntil=0; self.hitTimes={}; self.wildTimes={{},{}}
    end
    if data.phase~="Fight" and not resultPhase(data.phase) then return end
    local builds=data.settings or {}
    local rival=string.upper(((data.players or {})[2] or {}).name or "RIVAL")
    local function attack(side,event)
        local skill=self.skills.get(event.source=="wake" and "FizzyFuel" or (builds[side] or {}).offenceId or "")
        return string.upper(skill and skill.name or "ATTACK")
    end
    for _,event in ipairs(sim.events or {}) do
        if (event.serial or 0)>(self.eventSerial or 0) then
            self.eventSerial=event.serial
            local recent=(sim.elapsed or 0)-(event.at or 0)<0.75
            local mine=event.actor==1
            if not recent then
                -- An old event is history, not news.
            elseif event.kind=="hit" or event.kind=="wake_hit" then
                local name=attack(event.target==1 and 2 or 1,event)
                -- A hit that breaks more than one armor says so.
                local extra=(event.amount or 1)>1 and "  −"..tostring(event.amount).." ARMOR!" or ""
                if event.target==1 then self:call(rival.."'S "..name.." HIT YOU!"..extra,"bad",3,1.3)
                else self:call("YOUR "..name.." HIT!"..extra,"good",3,1.3) end
                self.hitTimes[event.target]=os.clock()
                if event.source=="wake" then self.wildTimes[event.target==1 and 2 or 1].FizzyFuel=os.clock() end
            elseif event.kind=="blocked" then
                self:call(mine and "YOUR BUMPER BLOCKED IT!" or rival.."'S BUMPER BLOCKED YOUR HIT","good",3,1.3)
                self.wildTimes[mine and 1 or 2].SpringBumper=os.clock()
            elseif event.kind=="skill" then
                local skill=self.skills.get(event.skillId or "")
                if skill and skill.id=="Gambler" then
                    local roll=event.roll or 0
                    local outcome=roll==1 and "LOSE 1 ARMOR" or (roll==6 and "JACKPOT! +1 ARMOR, DOUBLE HITS" or (roll>=4 and "+1 ARMOR" or "NOTHING"))
                    self:call((mine and "YOU ROLLED " or rival.." ROLLED ")..tostring(roll)..": "..outcome,mine and "you" or "rival",2,2.2)
                    self.wildTimes[mine and 1 or 2].Gambler=os.clock()
                elseif skill and skill.id=="Swap" then
                    self:call("SWAP! YOU TRADED ARMOR","good",3,1.6)
                    self.wildTimes[mine and 1 or 2].Swap=os.clock()
                elseif skill then
                    self:call((mine and "YOUR " or rival.."'S ")..string.upper(skill.name)..": "..skill.word,mine and "you" or "rival",2,1)
                    self.wildTimes[mine and 1 or 2][skill.id]=os.clock()
                end
            elseif event.kind=="sudden_death" then
                self:call("SUDDEN DEATH! NEXT HIT WINS","good",3,2)
            elseif event.kind=="miss" then
                local name=attack(mine and 1 or 2,event)
                self:call(mine and "YOUR "..name.." MISSED" or "YOU DODGED "..rival.."'S "..name.."!",mine and "you" or "rival",1,0.9)
            end
        end
    end
end
function BattleLab:update(dt)
    local player=Players.LocalPlayer
    local muted=player:GetAttribute("SkyboundSoundMuted")==true
    if self.muted~=muted then self.audio:setMuted(muted); self.muted=muted end
    self.audio:update(self.data or {active=false})
    if not self.active or not self.data or not self.view then return end
    local data=self.data; local width,height=self.root.AbsoluteSize.X,self.root.AbsoluteSize.Y
    local now=os.clock()
    self.reducedMotion=player:GetAttribute("SkyboundReducedMotion")==true
    self.view.reducedMotion=self.reducedMotion
    local compact=width<600; local short=height<500
    local searching=data.phase=="Searching"; local pick=data.phase=="Pick"
    local fighting=data.phase=="Fight"; local countdown=data.phase=="Countdown"; local results=resultPhase(data.phase)
    local landscapeDraft=short and width>height
    -- The HUD wears the same paint as the two planes.
    local accents={self.view:accent(1),self.view:accent(2)}
    local sim=data.simulation or {}; local builds=data.settings or {}; local identities=data.players or {}
    local locked=data.locked and data.locked[1]; local rivalLocked=data.locked and data.locked[2]
    self:feedback(data)
    local headerHeight=(short or compact) and 62 or 98
    place(self.header,0,0,width,headerHeight)
    place(self.exit,12,headerHeight+4,40,40); place(self.mute,58,headerHeight+4,40,40); place(self.motion,104,headerHeight+4,40,40)
    self.mute.Text=muted and "🔇" or "🔊"
    self.motion.TextTransparency=self.reducedMotion and 0.6 or 0
    local portrait=headerHeight-18
    local plateWidth=math.min(460,(width-124)/2)
    -- Phones in either orientation get the tight plate; text sizes follow width.
    local tight=compact or short
    for i,fighter in ipairs(self.fighters) do
        local right=i==2; local identity=identities[i] or {}; local state=(sim.fighters or {})[i] or {}
        local flash=math.max(0,1-(now-((self.hitTimes or {})[i] or -100))/0.35)
        place(fighter.frame,right and width-12-plateWidth or 12,8,plateWidth,portrait+4)
        place(fighter.ring,right and plateWidth-portrait or 0,2,portrait,portrait)
        fighter.ringEdge.Color=accents[i]:Lerp(WHITE,flash); fighter.ringEdge.Thickness=4+flash*4
        fighter.face.Image=self.portraits[identity.userId] or ""
        fighter.bot.Visible=identity.bot==true or (right and searching)
        fighter.bot.Text=identity.bot and (identity.portrait or "🤖") or "❓"; fighter.bot.TextSize=portrait*0.55
        local textWidth=plateWidth-portrait-12
        local textLeft=right and 0 or portrait+12
        local align=right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
        place(fighter.name,textLeft,0,textWidth,tight and 18 or 28)
        fighter.name.TextXAlignment=align; fighter.name.TextSize=compact and 14 or (short and 16 or 24)
        fighter.name.Text=string.upper(identity.name or (i==1 and player.DisplayName or "???"))..(identity.bot and " · BOT" or "")
        -- Row two is the build: the offence as a paint-coloured pill, then a
        -- round chip for each wild card as it is drafted.
        local build=builds[i] or {}
        -- While picking, the pilot's own plate shows the plane being built.
        if pick and i==1 then build=self:loadout() end
        local offence=self.skills.get(build.offenceId or "")
        local rowTwo=tight and 19 or 31; local rowHeight=tight and 14 or 19
        local powerWidth=math.min(textWidth,tight and 86 or 112)
        place(fighter.power,right and textLeft+textWidth-powerWidth or textLeft,rowTwo,powerWidth,rowHeight)
        fighter.powerText.TextSize=tight and 10 or 13
        local pillText=(right and searching) and "SEARCHING" or ((right and pick and rivalLocked) and ((identity.bot and not locked) and "PICKING…" or "LOCKED IN!")
            or (offence and string.upper(offence.name) or (i==1 and "YOU" or "RIVAL")))
        -- In a fight the pill is a meter: half for lining up, half for the
        -- windup, a white flash on the attack, then empty while banking away.
        local fill,striking=1,false
        if fighting and offence and state.phase then
            if fighter.meterPhase~=state.phase then fighter.meterPhase=state.phase; fighter.meterSpan=math.max(0.1,state.phaseLeft or 0.1) end
            local done=1-math.clamp((state.phaseLeft or 0)/fighter.meterSpan,0,1)
            if state.phase=="Approach" then fill=0.5*done
            elseif state.phase=="Windup" then fill=0.5+0.5*done; pillText=offence.windupTell or pillText
            elseif state.phase=="Attack" then striking=true; pillText=offence.attackTell or pillText
            else fill=0 end
        else fighter.meterPhase=nil end
        fighter.powerText.Text=pillText
        fighter.power.BackgroundColor3=fill<1 and accents[i]:Lerp(NAVY,0.62) or accents[i]
        fighter.charge.Visible=fill>0.02 and fill<1
        fighter.charge.BackgroundColor3=accents[i]
        fighter.charge.AnchorPoint=Vector2.new(right and 1 or 0,0); fighter.charge.Position=UDim2.fromScale(right and 1 or 0,0)
        fighter.charge.Size=UDim2.new(fill,0,1,0)
        if striking then fighter.power.BackgroundColor3=accents[i]:Lerp(WHITE,self.reducedMotion and 0.5 or 0.5+0.5*math.sin(now*24)) end
        fighter.powerText.TextColor3=(fill<0.5 and not striking) and WHITE or NAVY
        local chipSize=rowHeight+4
        -- A wild card carries its name whenever the plate has room for two.
        local nameWidth=math.min(132,(textWidth-powerWidth-10)/2-5)
        local named=nameWidth>=78
        for n,chip in ipairs(fighter.wilds) do
            local wild=self.skills.get((build.wildIds or {})[n] or "")
            -- With no room beside the pill, the chips ride on the portrait's rim.
            local badge=not named and textWidth<powerWidth+2*(chipSize+5)
            chip.label.Visible=wild~=nil
            if chip.label.Visible then
                local chipWidth=named and nameWidth or chipSize
                local offset=powerWidth+5+(n-1)*(chipWidth+5)
                if badge then
                    local step=(n-1)*(chipSize+2)-2
                    place(chip.label,right and plateWidth-chipSize-step or step,portrait-chipSize+6,chipSize,chipSize)
                else
                    place(chip.label,right and textLeft+textWidth-offset-chipWidth or textLeft+offset,rowTwo-2,chipWidth,chipSize)
                end
                chip.label.Text=named and wild.icon.." "..string.upper(wild.name) or wild.icon
                chip.label.TextSize=named and math.clamp((chipWidth-8)/(utf8.len(chip.label.Text)*0.62),8,chipSize*0.58) or chipSize*0.58
                -- A chip jumps and glows the moment its wild card does something,
                -- and a spent Spring Bumper goes dark.
                local fired=math.max(0,1-(now-(((self.wildTimes or {})[i] or {})[wild.id] or -100))/0.9)
                local spent=wild.id=="SpringBumper" and fighting and state.bumperReady==false and fired<=0
                -- Second Wind stays lit for as long as it is helping.
                if wild.id=="SecondWind" and fighting and state.secondWind==true then fired=math.max(fired,0.45) end
                chip.edge.Color=accents[i]:Lerp(GOLD,fired); chip.edge.Thickness=2+fired*2
                chip.label.BackgroundColor3=NAVY:Lerp(WHITE,fired*0.8); chip.label.TextTransparency=spent and 0.6 or 0
                chip.scale.Scale=self.reducedMotion and 1 or 1+(named and 0.22 or 0.6)*fired*fired
            end
        end
        local pipHeight=tight and 9 or 18
        -- A Giant has more armor to show and a Vampire can grow past three.
        local armor=state.armor or 3
        local pipCount=math.clamp(math.max(state.maxArmor or 3,armor),1,#fighter.pips)
        local pipWidth=math.min(compact and 30 or (short and 44 or 62),(textWidth-(pipCount-1)*6)/pipCount)
        for n,pip in ipairs(fighter.pips) do
            pip.Visible=n<=pipCount
            local offset=(n-1)*(pipWidth+6)
            place(pip,right and textLeft+textWidth-offset-pipWidth or textLeft+offset,portrait-pipHeight+1,pipWidth,pipHeight)
            local full=n<=armor
            pip.BackgroundColor3=(full and accents[i] or EMPTY):Lerp(WHITE,flash*0.7)
            pip.BackgroundTransparency=full and 0 or 0.35
        end
    end
    -- The clock is the centre of the bar and gets loud in the last ten seconds.
    local left=self:clockSeconds(workspace:GetServerTimeNow())
    -- The clock counts down to the armor check; sudden death then runs on
    -- what is left before the hard stop.
    local suddenDeath=fighting and sim.suddenDeath==true
    if fighting and not suddenDeath and sim.regulationTime and sim.maxTime then left=math.max(0,left-(sim.maxTime-sim.regulationTime)) end
    local urgent=suddenDeath or (fighting and left<=5) or (pick and not locked and left<=3)
    local clockHeight=headerHeight-(short and 14 or 26)
    place(self.clock,width/2-60,2,120,clockHeight)
    self.clock.Text=(fighting or pick) and tostring(left) or (results and (sim.reason=="timeout" and "TIME!" or (sim.reason=="knockout" and "K.O." or (sim.reason=="sudden_death" and "HIT!" or "VS"))) or "VS")
    self.clock.TextSize=(compact and 26 or (short and 40 or 52))*(#self.clock.Text>2 and 0.7 or 1)
    self.clock.TextColor3=urgent and RED or (results and GOLD or WHITE)
    self.clockScale.Scale=(urgent and not self.reducedMotion) and 1+0.14*math.abs(math.sin(now*math.pi)) or 1
    -- Round wins sit under the clock: two to fill, inner dot first.
    local score=data.score or {0,0}
    local dot=(compact or short) and 9 or 14
    for side,row in ipairs(self.wins) do
        for n,win in ipairs(row) do
            local offset=8+(n-1)*(dot+6)
            place(win.frame,side==1 and width/2-offset-dot or width/2+offset,clockHeight+(short and 1 or 4),dot,dot)
            local won=n<=(score[side] or 0)
            if won and not win.won then win.wonAt=now end
            win.won=won
            win.frame.BackgroundColor3=won and accents[side] or EMPTY
            win.frame.BackgroundTransparency=won and 0 or 0.35
            win.scale.Scale=(won and not self.reducedMotion) and 1+1.2*math.max(0,1-(now-(win.wonAt or 0))/0.35)^2 or 1
        end
    end
    -- One status call under the bar, and only while planes are in the air.
    local wide=width>=1180
    local statusWidth=math.min(width-24,wide and 620 or (compact and 300 or 420))
    -- The pill shares the button row when it clears the buttons, else drops below.
    local statusTop=headerHeight+((width-statusWidth)/2>=152 and 10 or 48)
    local contentTop=headerHeight+(wide and 4 or 48)
    local statusHeight=(compact or short) and 30 or 40
    place(self.status,(width-statusWidth)/2,statusTop,statusWidth,statusHeight)
    self.status.Visible=fighting or countdown
    self.status.TextColor3=WHITE; self.statusEdge.Color=Color3.fromRGB(118,154,187); self.statusEdge.Transparency=0.4
    self.statusScale.Scale=1
    if countdown then
        self.status.Text=data.matchPoint and "MATCH POINT · GET READY" or ("ROUND "..tostring(math.max(1,data.roundNumber or 1)).." · GET READY")
    elseif now<(self.feedbackUntil or 0) then
        -- The colour says whose news it is: gold is good for you, red is bad.
        local tones={good=GOLD,bad=RED,you=accents[1],rival=accents[2]}
        local tone=tones[self.feedbackTone] or GOLD
        self.status.Text=self.feedbackText; self.status.TextColor3=tone:Lerp(WHITE,0.25)
        self.statusEdge.Color=tone; self.statusEdge.Transparency=0.1
        if not self.reducedMotion then self.statusScale.Scale=1+0.25*math.max(0,1-(now-(self.feedbackAt or 0))/0.18)^2 end
    else
        -- Nothing just happened, so say what is about to: an attack in the
        -- air outranks a windup, and yours outranks the rival's.
        local fighters=sim.fighters or {}; local line,side
        local rivalName=string.upper((identities[2] or {}).name or "RIVAL")
        for _,phase in ipairs({"Attack","Windup"}) do
            for index=1,2 do
                local skill=self.skills.get((builds[index] or {}).offenceId or "")
                if not line and skill and (fighters[index] or {}).phase==phase then
                    side=index
                    line=(index==1 and "YOU: " or rivalName..": ")..(phase=="Attack" and skill.attackTell or skill.windupTell)
                end
            end
        end
        -- A Swap on its way outranks everything: both pilots can still change it.
        local swapIn
        for index=1,2 do
            local left=((fighters[index] or {}).swapAt or -1)-(sim.elapsed or 0)
            if not sim.swapped and left>0 and left<=3 then swapIn=math.ceil(left) end
        end
        if swapIn then
            self.status.Text="ARMOR SWAP IN "..tostring(swapIn).."…"; self.status.TextColor3=GOLD
            self.statusEdge.Color=GOLD; self.statusEdge.Transparency=0.1
        elseif suddenDeath and not (line and side==1) then
            self.status.Text="SUDDEN DEATH · NEXT HIT WINS"; self.status.TextColor3=GOLD
            self.statusEdge.Color=GOLD; self.statusEdge.Transparency=0.1
        elseif line then
            self.status.Text=line; self.status.TextColor3=accents[side]:Lerp(WHITE,0.35)
            self.statusEdge.Color=accents[side]; self.statusEdge.Transparency=0.1
        else
            self.status.Text=(sim.pressure or 0)>0 and "WIND CLOSING IN" or (data.matchPoint and "MATCH POINT" or "LINING UP…")
            if data.matchPoint then self.status.TextColor3=GOLD end
        end
    end
    if data.experimental and self.status.Visible then self.status.Text="EXPERIMENTAL · "..self.status.Text end
    self.status.TextSize=math.min(compact and 17 or (short and 19 or 26),statusWidth/(utf8.len(self.status.Text) or 20)/0.62)
    self.experimental.Visible=data.experimental==true and not self.status.Visible
    place(self.experimental,width-12-170,headerHeight+8,170,24)
    self.picker.Visible=pick; self.search.Visible=searching
    if searching then
        local area=height-contentTop; place(self.search,0,contentTop,width,area)
        local y=math.max(14,(area-200)/2)
        place(self.searchTitle,0,y,width,60); self.searchTitle.TextSize=math.min(compact and 30 or 46,width*0.075)
        self.searchTitle.Text="FINDING YOUR RIVAL"..string.rep(".",math.floor(now*2.5)%4)
        self.searchScale.Scale=self.reducedMotion and 1 or 1+0.03*math.sin(now*4)
        place(self.searchHint,24,y+66,width-48,44); self.searchHint.TextSize=compact and 13 or 16
        self.searchHint.Text="Looking for another pilot…\nA named bot joins after about 8 seconds."
        place(self.cancel,math.max(16,width/2-130),y+124,math.min(width-32,260),48)
    elseif pick then
        local area=height-contentTop; place(self.picker,0,contentTop,width,area)
        self.picker.ScrollingEnabled=not landscapeDraft
        self.picker.ScrollBarThickness=landscapeDraft and 0 or 3
        if landscapeDraft then self.picker.CanvasPosition=Vector2.zero end
        local panel=math.min(width-24,880); local x=(width-panel)/2; local y=2
        local titleHeight=short and 30 or 50
        place(self.pickTitle,x,y,panel,titleHeight); self.pickTitle.TextSize=math.min(short and 24 or (compact and 28 or 40),panel*0.085)
        local draft=self:loadout(); local slots=data.slots or 0; local offer=data.offer or {}
        local focus=self.focus or 0
        local complete=draft.offenceId~=nil and #draft.wildIds==slots
        local held=focus==0 and draft.offenceId or draft.wildIds[focus]
        self.pickTitle.Text=locked and "LOCKED IN!" or (focus==0 and (slots==0 and "PICK YOUR ATTACK" or "CHANGE YOUR ATTACK?")
            or (focus<=(self.draftHeld or 0) and "CHANGE THIS WILD CARD?"
                or (data.guided and ((data.stage or 2)<=2 and "PICK A WILD CARD" or "PICK ONE MORE") or "ADD A WILD CARD")))
        self.pickTitle.TextColor3=locked and GOLD or WHITE
        y=y+titleHeight
        self.pickHint.Visible=not landscapeDraft
        place(self.pickHint,x,y,panel,short and 18 or (compact and 32 or 22)); self.pickHint.TextSize=short and 11 or (compact and 12 or 14)
        self.pickHint.Text=locked and (rivalLocked and "Both locked. Revealing together…" or "Waiting for your rival. Picks stay hidden until both lock.")
            or (slots==0 and "Your plane fights on its own. Win 2 rounds to win the match!"
                or focus==0 and "Tap another attack to swap, or keep the one you have."
                or focus<=(self.draftHeld or 0) and "Tap another wild card to swap, or keep the one you have."
                or data.guided and ((data.stage or 2)<=2 and "A wild card gives your plane a trick. Tap one, then tap LOCK IN!"
                    or "Your plane keeps both tricks. Tap one, then tap LOCK IN!")
                or "Your plane keeps everything on it. Tap a slot above the cards to swap it.")
        y=y+(landscapeDraft and 2 or short and 22 or (compact and 36 or 30))
        -- The loadout bar appears once there is more than the attack to show.
        local tiles=slots>0 and slots+1 or 0
        local barHeight=tiles>0 and (short and 36 or 48) or 0
        local tileWidth=tiles>0 and math.min(250,(panel-(tiles-1)*8)/tiles) or 0
        local barLeft=x+(panel-(tiles*tileWidth+(tiles-1)*8))/2
        for slot,tile in pairs(self.slotTiles) do
            tile.button.Visible=slot<tiles
            if slot<tiles then
                local skill=self.skills.get((slot==0 and draft.offenceId or draft.wildIds[slot]) or "")
                local focused=slot==focus and not locked
                place(tile.button,barLeft+slot*(tileWidth+8),y,tileWidth,barHeight)
                tile.button.BackgroundColor3=skill and tint(skill.color):Lerp(NAVY,focused and 0 or 0.55) or NAVY
                tile.edge.Color=focused and GOLD or MUTED; tile.edge.Thickness=focused and 4 or 2
                tile.edge.Transparency=focused and 0 or 0.5
                tile.button.Active=not locked; tile.button.Selectable=not locked
                local ink=(skill and focused) and NAVY or WHITE
                local captionHeight=short and 12 or 15
                place(tile.caption,4,3,tileWidth-8,captionHeight); tile.caption.TextSize=short and 9 or 11
                tile.caption.TextColor3=ink; tile.caption.TextTransparency=0.15
                tile.caption.Text=(slot==0 and "ATTACK" or (tileWidth<130 and "WILD " or "WILD CARD ")..tostring(slot))
                    ..((focused or locked or tileWidth<170) and "" or " · TAP TO SWAP")
                place(tile.value,4,captionHeight+2,tileWidth-8,barHeight-captionHeight-5)
                tile.value.Text=skill and skill.icon.." "..string.upper(skill.name) or "＋ PICK ONE"
                tile.value.TextColor3=skill and ink or GOLD
                tile.value.TextSize=math.clamp((tileWidth-8)/((utf8.len(tile.value.Text) or 12)*0.62),9,short and 16 or 20)
                -- An empty slot breathes until it gets its card.
                tile.scale.Scale=(skill or locked or self.reducedMotion) and 1 or 1+0.03*math.sin(now*6)
            end
        end
        y=y+barHeight+(tiles>0 and 6 or 0)
        local bottom=landscapeDraft and 54 or (short and 55 or 72)
        local listHeight=landscapeDraft and math.max(0,area-y-bottom) or math.max(62,area-y-bottom)
        local choices=(focus==0 and offer.offences or offer.wilds) or {}
        local stackedCards=compact and not landscapeDraft
        -- One row while each card keeps a readable width, then even rows.
        local fit=math.max(1,math.floor(panel/((landscapeDraft and 120 or 150)+12)))
        local rows=stackedCards and #choices or math.max(1,math.ceil(#choices/fit))
        local cols=stackedCards and 1 or math.max(1,math.ceil(#choices/rows))
        -- Stacked cards squeeze so the whole roster shows without scrolling.
        local gap=stackedCards and 8 or 12
        local cardHeight
        if landscapeDraft then cardHeight=math.max(80,listHeight/rows-gap)
        elseif stackedCards then cardHeight=math.clamp(listHeight/math.max(1,#choices)-gap,54,104)
        else cardHeight=math.clamp(listHeight/math.max(1,rows)-gap,98,290) end
        -- A short hand sits centred under the title, never stretched to fill.
        local used=rows*(cardHeight+gap)
        local listTop=y+((not stackedCards and used<listHeight) and (listHeight-used)/2 or 0)
        place(self.cardList,x,listTop,panel,math.min(listHeight,used+12))
        local cardWidth=(panel-(cols-1)*gap-12)/cols
        local selected=held
        local offerKey=tostring(data.matchId)..":"..tostring(data.stage)..":"..tostring(focus)
        if self.offerKey~=offerKey then self.offerKey=offerKey; self.offerAt=now end
        for _,card in pairs(self.powerCards) do card.button.Visible=false end
        for index,id in ipairs(choices) do
            local card=self.powerCards[id]
            if card then
                local chosen=selected==id; card.button.Visible=true
                -- A wild card in the other slot is already on the plane.
                local taken=focus>0 and not chosen and table.find(draft.wildIds,id)~=nil
                local row,col=math.floor((index-1)/cols),(index-1)%cols
                place(card.button,6+col*(cardWidth+gap),6+row*(cardHeight+gap),cardWidth,cardHeight)
                card.button.BackgroundColor3=taken and card.color:Lerp(NAVY,0.75) or ((chosen or not selected) and card.color or card.color:Lerp(NAVY,0.45))
                card.edge.Color=chosen and GOLD or NAVY; card.edge.Thickness=chosen and 6 or 4
                card.button.Active=not locked and not taken; card.button.Selectable=card.button.Active
                -- Cards deal in one after another; the chosen one pops forward.
                local deal=self.reducedMotion and 1 or popIn((now-self.offerAt-(index-1)*0.07)/0.26)
                local bounce=chosen and math.max(0,1-(now-(self.pickedAt or 0))/0.2) or 0
                card.scale.Scale=math.max(0.01,deal)*((chosen and 1.03 or (selected and 0.95 or 1))+bounce*0.07)
                card.button.ZIndex=chosen and 3 or 2
                local roomy=not stackedCards and cardHeight>=150 and cardWidth>=120
                card.tag.Visible=roomy; card.word.Visible=roomy and cardWidth>=190; card.promise.Visible=true
                -- A stacked card has no tag, so its trigger leads the promise.
                card.promise.Text=(stackedCards and card.spec.when) and (card.spec.when..": "..card.spec.promise) or card.spec.promise
                -- Only a roomy card has a tag to say why it cannot be tapped.
                if taken and not roomy then card.promise.Text="Already on your plane." end
                if roomy then
                    place(card.tag,12,10,math.min(cardWidth-24,card.spec.when and 160 or 132),22)
                    card.tag.Text=chosen and "✓ YOUR PICK" or (taken and "ON YOUR PLANE" or (card.spec.when or "TAP TO PICK"))
                    card.tag.TextSize=cardWidth<150 and 9 or 12
                    card.tag.BackgroundTransparency=chosen and 0 or 0.45
                    place(card.icon,0,34,cardWidth,cardHeight*0.36); card.icon.TextSize=math.clamp(cardHeight*0.3,28,84)
                    place(card.word,cardWidth-math.min(150,cardWidth*0.5),40,math.min(140,cardWidth*0.46),28)
                    card.word.TextSize=math.clamp(cardWidth*0.075,14,22)
                    local nameTop=34+cardHeight*0.36
                    place(card.name,8,nameTop,cardWidth-16,36); card.name.TextSize=math.clamp(cardWidth*0.115,18,32)
                    -- A narrow card shrinks its longest name to stay on one line.
                    if cardWidth<190 then card.name.TextSize=math.clamp((cardWidth-16)/(#card.spec.name*0.62),11,20) end
                    card.name.TextXAlignment=Enum.TextXAlignment.Center
                    place(card.promise,14,nameTop+38,cardWidth-28,cardHeight-nameTop-46); card.promise.TextSize=math.clamp(cardWidth*0.085,11,15)
                    card.promise.TextXAlignment=Enum.TextXAlignment.Center; card.promise.TextYAlignment=Enum.TextYAlignment.Top
                elseif not stackedCards and cardWidth<170 then
                    -- A short, narrow card (a phone on its side) stacks icon, name
                    -- and promise so no word has to break.
                    local iconBox=math.clamp(cardHeight*0.36,20,44)
                    place(card.icon,0,3,cardWidth,iconBox); card.icon.TextSize=iconBox*0.8
                    place(card.name,4,iconBox+4,cardWidth-8,16)
                    card.name.TextSize=math.clamp((cardWidth-8)/(#card.spec.name*0.62),9,15)
                    card.name.TextXAlignment=Enum.TextXAlignment.Center
                    place(card.promise,6,iconBox+21,cardWidth-12,cardHeight-iconBox-24); card.promise.TextSize=11
                    card.promise.TextXAlignment=Enum.TextXAlignment.Center; card.promise.TextYAlignment=Enum.TextYAlignment.Top
                else
                    local iconBox=math.min(cardHeight-12,64)
                    place(card.icon,6,(cardHeight-iconBox)/2,iconBox,iconBox); card.icon.TextSize=iconBox*0.62
                    place(card.name,iconBox+14,8,cardWidth-iconBox-24,24)
                    card.name.TextSize=math.clamp((cardWidth-iconBox-24)/(#card.spec.name*0.66),12,20)
                    card.name.TextXAlignment=Enum.TextXAlignment.Left
                    place(card.promise,iconBox+14,34,cardWidth-iconBox-24,cardHeight-40); card.promise.TextSize=compact and 12 or 11
                    card.promise.TextXAlignment=Enum.TextXAlignment.Left; card.promise.TextYAlignment=Enum.TextYAlignment.Top
                end
            end
        end
        self.cardList.CanvasSize=UDim2.fromOffset(0,(stackedCards or used>listHeight) and used+12 or 0)
        y=y+listHeight+(landscapeDraft and 4 or 8)
        local ready=not locked and complete
        if landscapeDraft then
            place(self.fightButton,(width-math.min(panel,360))/2,y,math.min(panel,360),44)
            self.fightButton.TextSize=20
        else
            local lockWidth=math.min(panel,440)
            place(self.fightButton,(width-lockWidth)/2,y,lockWidth,short and 46 or 58)
            self.fightButton.TextSize=(short and 22 or 30)+((ready and not self.reducedMotion) and 2*math.sin(now*5) or 0)
        end
        self.fightButton.Text=locked and "WAITING FOR RIVAL…" or (complete and "LOCK IN!" or landscapeDraft and "CHOOSE A CARD" or "TAP A CARD")
        self.fightButton.BackgroundColor3=ready and GREEN or Color3.fromRGB(58,96,84)
        enabled(self.fightButton,ready)
        self.picker.CanvasSize=UDim2.fromOffset(0,landscapeDraft and 0 or (y+(short and 50 or 62)>area and y+(short and 50 or 62) or 0))
    end
    -- A phone on its side has no height to spare: the result starts beside the
    -- three small buttons instead of under them, so REMATCH stays on screen.
    self:showResult(data,accents,width,height,(short and not compact) and headerHeight+6 or contentTop,compact,short)
    self.reveal.Visible=countdown
    if countdown then
        local stacked=compact and not short
        local revealWidth=math.min(width-28,short and 560 or 720); local rowHeight=short and 52 or 84
        local titleHeight=short and 0 or 40; local middle=stacked and 0 or (short and 44 or 64)
        local cardWidth=stacked and revealWidth or (revealWidth-middle)/2
        local revealHeight=titleHeight+(stacked and 2*rowHeight+34 or rowHeight)
        place(self.reveal,(width-revealWidth)/2,statusTop+statusHeight+8,revealWidth,revealHeight)
        -- On a short screen the status pill already makes the call.
        self.revealTitle.Visible=not short; place(self.revealTitle,0,0,revealWidth,titleHeight)
        self.revealTitle.Text=self.sameBuildReplay and "DRAW · SAME BUILDS!" or (data.matchPoint and "MATCH POINT!"
            or ((data.guided and data.stage==1) and "YOUR FIRST BATTLE!" or "PLANES REVEALED!"))
        self.revealTitle.TextSize=short and 20 or 30
        local slide=self.reducedMotion and 1 or popIn((now-(self.revealedAt or 0))/0.32)
        for side,item in ipairs(self.reveals) do
            local identity=identities[side] or {}; local build=builds[side] or {}
            -- Each side shows its whole plane: the attack by name, then its wild cards.
            local skill=self.skills.get(build.offenceId or "")
            local extras={}
            for _,wildId in ipairs(build.wildIds or {}) do
                local wild=self.skills.get(wildId); if wild then extras[#extras+1]=wild.icon end
            end
            local restX=stacked and 0 or (side-1)*(cardWidth+middle)
            local restY=titleHeight+(stacked and (side-1)*(rowHeight+34) or 0)
            place(item.frame,restX+(1-slide)*(side==1 and -1 or 1)*width*0.6,restY,cardWidth,rowHeight)
            item.frame.BackgroundColor3=skill and tint(skill.color) or accents[side]
            -- A named build is shouted on its own card.
            local combo=((((data.simulation or {}).fighters or {})[side]) or {}).combo
            local tagWidth=math.min(cardWidth-20,combo and 400 or (side==1 and 56 or 150))
            place(item.name,10,6,tagWidth,18)
            item.name.Text=(side==1 and "YOU" or (string.upper(identity.name or "RIVAL")..(identity.bot and " · BOT" or "")))..(type(combo)=="string" and " · "..combo or "")
            local iconBox=rowHeight-30
            place(item.icon,8,26,iconBox+8,iconBox); item.icon.TextSize=iconBox*0.8; item.icon.Text=skill and skill.icon or "✈️"
            place(item.skill,iconBox+24,26,cardWidth-iconBox-32,iconBox)
            item.skill.Text=(skill and string.upper(skill.name) or "PLANE")..(#extras>0 and "  + "..table.concat(extras," ") or "")
            item.skill.TextSize=math.min(short and 20 or 30,(cardWidth-iconBox-32)*0.13,(cardWidth-iconBox-32)/((utf8.len(item.skill.Text) or 12)*0.62))
        end
        self.revealVs.Visible=slide>0.6
        if stacked then place(self.revealVs,0,titleHeight+rowHeight,revealWidth,34); self.revealVs.TextSize=26
        else place(self.revealVs,cardWidth,titleHeight,middle,rowHeight); self.revealVs.TextSize=short and 24 or 36 end
        self.revealPersonality.Visible=not short and (data.roundNumber or 1)==1 and identities[2]~=nil and identities[2].bot==true
        place(self.revealPersonality,0,revealHeight+6,revealWidth,22)
        self.revealPersonality.Text=identities[2] and identities[2].personality or ""
    end
    -- Three evenly spaced beats across the server countdown, then FIGHT!
    local call=nil
    if countdown then
        local remaining=(data.endsAt or 0)-workspace:GetServerTimeNow()
        if self.countRound~=data.roundId then self.countRound=data.roundId; self.countSpan=math.max(0.3,remaining) end
        call=tostring(4-math.clamp(math.floor((1-remaining/self.countSpan)*3)+1,1,3))
    elseif fighting and (sim.elapsed or 0)<0.8 then call="FIGHT!" end
    if call~=self.countText then self.countText=call; self.countAt=now end
    self.count.Visible=call~=nil
    if call then
        local age=now-(self.countAt or 0)
        self.count.Text=call
        self.count.Position=UDim2.fromOffset(width/2,contentTop+(height-contentTop)*(countdown and 0.6 or 0.5))
        self.count.TextSize=math.min(short and 90 or (call=="FIGHT!" and 130 or 170),width*0.24)
        self.count.TextColor3=call=="FIGHT!" and RED or GOLD
        self.countScale.Scale=self.reducedMotion and 1 or 1+1.1*math.max(0,1-age/0.18)^2
        self.count.TextTransparency=math.clamp((age-0.45)/0.3,0,1)
        self.countEdge.Transparency=self.count.TextTransparency
    end
    local coaching=self:coachText(data)
    local coachHeight=compact and 50 or (short and 34 or 44)
    self.coach.Visible=coaching~=nil
    if coaching then
        local coachWidth=math.min(width-24,compact and 420 or 660)
        place(self.coach,(width-coachWidth)/2,height-coachHeight-10,coachWidth,coachHeight)
        if coaching~=self.coachLine then self.coachLine=coaching; self.coachAt=now end
        self.coach.Text=coaching; self.coach.TextSize=compact and 14 or (short and 15 or 18)
        self.coachEdge.Color=accents[1]
        self.coachScale.Scale=self.reducedMotion and 1 or 1+0.18*math.max(0,1-(now-(self.coachAt or 0))/0.25)^2
    end
    local inset=GuiService:GetGuiInset(); place(self.scrim,-inset.X,-inset.Y,width+inset.X*2,height+inset.Y)
    self.scrim.BackgroundTransparency=pick and 0.3 or (searching and 0.45 or (self.result.Visible and (self.resultDim or 1) or 1))
    local origin=self.root.AbsolutePosition+inset
    self.view:update(data,dt,{left=origin.X+10,right=origin.X+width-10,
        top=origin.Y+((pick or searching) and headerHeight+8 or statusTop+statusHeight+8),bottom=origin.Y+height-8-(coaching and coachHeight+10 or 0)})
    self.flash.BackgroundTransparency=self.reducedMotion and 1 or (1-math.min(0.7,self.view.screenFlash*0.7))
end
return BattleLab
