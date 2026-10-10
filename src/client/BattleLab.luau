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
local MUTED=Color3.fromRGB(180,200,218)
local GOLD=Color3.fromRGB(255,221,87)
local GREEN=Color3.fromRGB(88,214,133)
local SIDES={Color3.fromRGB(87,224,248),Color3.fromRGB(255,141,119)}
local function make(class,parent,name)
    local item=Instance.new(class); item.Name=name; item.Parent=parent; return item
end
local function label(parent,name,size,color)
    local item=make("TextLabel",parent,name)
    item.BackgroundTransparency=1; item.TextColor3=color or WHITE
    item.TextSize=size; item.Font=Enum.Font.GothamBold; item.TextWrapped=true; item.Text=""
    return item
end
local function edge(item,color,thickness)
    local stroke=make("UIStroke",item,"Edge"); stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    stroke.Color=color; stroke.Thickness=thickness or 1; stroke.Transparency=0.2; return stroke
end
local function button(parent,name,text,callback)
    local item=make("TextButton",parent,name)
    item.BackgroundColor3=Color3.fromRGB(41,61,86); item.BorderSizePixel=0
    item.TextColor3=WHITE; item.Font=Enum.Font.GothamBold; item.TextSize=16; item.Text=text
    item.AutoButtonColor=true; item.Selectable=true; item.TextWrapped=true
    make("UICorner",item,"Corner").CornerRadius=UDim.new(0,12)
    edge(item,Color3.fromRGB(118,153,188),1)
    item.Activated:Connect(callback); return item
end
local function place(item,x,y,w,h)
    item.Position=UDim2.fromOffset(x,y); item.Size=UDim2.fromOffset(math.max(0,w),math.max(0,h))
end
local function enabled(item,value)
    item.Active=value; item.Selectable=value; item.AutoButtonColor=value
    item.TextTransparency=value and 0 or 0.35
end
local function resultPhase(phase) return phase=="RoundOver" or phase=="MatchOver" or phase=="Results" end
local function tint(color) return Color3.fromRGB(color.r,color.g,color.b) end
function BattleLab.new(World,shared)
    local self=setmetatable({World=World,active=false,data=nil,outbox={},sending=false,lastSend=-math.huge,portraits={}},BattleLab)
    self.skills=require(shared:WaitForChild("SkillCatalog")); self.audio=BattleAudio.new()
    self.command=shared:WaitForChild("BattleCommand"); self.progressCommand=shared:WaitForChild("Command")
    self.cosmetics=require(shared:WaitForChild("CosmeticCatalog"))
    self.gui=make("ScreenGui",Players.LocalPlayer:WaitForChild("PlayerGui"),"SkyboundBattleLab")
    self.gui.ResetOnSpawn=false; self.gui.DisplayOrder=30; self.gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    self.root=make("Frame",self.gui,"Root"); self.root.Size=UDim2.fromScale(1,1); self.root.BackgroundTransparency=1
    self.panel=make("Frame",self.root,"Lab"); self.panel.Size=UDim2.fromScale(1,1); self.panel.BackgroundTransparency=1; self.panel.Visible=false
    self.scrim=make("Frame",self.panel,"Scrim"); self.scrim.BorderSizePixel=0; self.scrim.ZIndex=0
    self.scrim.BackgroundColor3=NAVY; self.scrim.BackgroundTransparency=1
    self.header=make("Frame",self.panel,"Header"); self.header.BackgroundColor3=NAVY; self.header.BackgroundTransparency=0.12; self.header.BorderSizePixel=0
    self.exit=button(self.panel,"Exit","⌂",function() self.audio:ui("back"); self:send("exit") end)
    self.mute=button(self.panel,"Mute","🔊",function()
        local player=Players.LocalPlayer; local muted=player:GetAttribute("SkyboundSoundMuted")~=true
        player:SetAttribute("SkyboundSoundMuted",muted); self.audio:setMuted(muted); if not muted then self.audio:ui("tap") end
    end)
    self.motion=button(self.panel,"Motion","Motion on",function()
        local player=Players.LocalPlayer; player:SetAttribute("SkyboundReducedMotion",player:GetAttribute("SkyboundReducedMotion")~=true); self.audio:ui("tap")
    end)
    for _,item in ipairs({self.exit,self.mute,self.motion}) do item.ZIndex=30 end
    self.clock=label(self.header,"Clock",32); self.clock.Font=Enum.Font.FredokaOne
    self.score=label(self.header,"Score",18,GOLD); self.score.TextWrapped=false
    self.round=label(self.header,"Round",10,MUTED); self.round.TextWrapped=false
    self.fighters={}
    for i=1,2 do
        local frame=make("Frame",self.header,"Fighter"..i); frame.BackgroundTransparency=1
        local ring=make("Frame",frame,"Portrait"); ring.BackgroundColor3=NAVY; ring.BorderSizePixel=0
        make("UICorner",ring,"Corner").CornerRadius=UDim.new(1,0); edge(ring,SIDES[i],3)
        local face=make("ImageLabel",ring,"Face"); face.BackgroundTransparency=1; face.Size=UDim2.fromScale(1,1)
        make("UICorner",face,"Corner").CornerRadius=UDim.new(1,0)
        local bot=label(ring,"Bot",28); bot.Size=UDim2.fromScale(1,1); bot.TextWrapped=false
        local name=label(frame,"PilotName",16); name.TextWrapped=false; name.TextTruncate=Enum.TextTruncate.AtEnd
        local role=label(frame,"Role",12,SIDES[i]); role.TextWrapped=false
        local build=label(frame,"Build",11,MUTED); build.TextWrapped=false; build.TextTruncate=Enum.TextTruncate.AtEnd
        local slots={}
        for n=1,3 do local pip=make("Frame",frame,"Armor"..n); pip.BorderSizePixel=0
            make("UICorner",pip,"Corner").CornerRadius=UDim.new(0,3); slots[n]=pip end
        self.fighters[i]={frame=frame,ring=ring,face=face,bot=bot,name=name,role=role,build=build,pips=slots}
    end
    self.status=label(self.panel,"Status",23); self.status.Font=Enum.Font.FredokaOne
    self.status.BackgroundColor3=NAVY; self.status.BackgroundTransparency=0.08
    make("UICorner",self.status,"Corner").CornerRadius=UDim.new(0,8)
    self.help=label(self.panel,"Help",13,WHITE)
    self.experimental=label(self.panel,"ExperimentalRoster",12,GOLD); self.experimental.Text="EXPERIMENTAL ROSTER"; self.experimental.BackgroundColor3=NAVY; self.experimental.BackgroundTransparency=0.08
    make("UICorner",self.experimental,"Corner").CornerRadius=UDim.new(0,8)
    self.help.BackgroundColor3=NAVY; self.help.BackgroundTransparency=0.08
    make("UICorner",self.help,"Corner").CornerRadius=UDim.new(0,6)
    self.picker=make("ScrollingFrame",self.panel,"Picker"); self.picker.BackgroundTransparency=1; self.picker.BorderSizePixel=0
    self.picker.ScrollBarThickness=3; self.picker.CanvasSize=UDim2.fromOffset(0,0); self.picker.ScrollingDirection=Enum.ScrollingDirection.Y
    self.pickTitle=label(self.picker,"Title",34); self.pickTitle.Font=Enum.Font.FredokaOne
    self.pickHint=label(self.picker,"Hint",14,MUTED)
    self.draftBuilds=label(self.picker,"RevealedBuilds",13,WHITE)
    self.cardList=make("ScrollingFrame",self.picker,"Cards"); self.cardList.BackgroundTransparency=1
    self.cardList.BorderSizePixel=0; self.cardList.ScrollBarThickness=4; self.cardList.ScrollBarImageColor3=GOLD
    self.cardList.ScrollingDirection=Enum.ScrollingDirection.Y; self.cardList.CanvasSize=UDim2.fromOffset(0,0)
    self.powerCards={}
    -- All catalog entries have one reusable card. Eligibility and visibility are
    -- resolved by the snapshot; catalog presence never grants access.
    for _,spec in ipairs(self.skills.all()) do
        local card=button(self.cardList,spec.id,"",function() self:choose(spec.id) end)
        card.AutoButtonColor=false
        local icon=label(card,"Icon",40); icon.Text=spec.icon
        local name=label(card,"SkillName",22,NAVY); name.Font=Enum.Font.FredokaOne; name.Text=string.upper(spec.name)
        local promise=label(card,"Promise",13,NAVY); promise.Text=spec.promise
        local tag=label(card,"Tag",10,NAVY)
        self.powerCards[spec.id]={button=card,spec=spec,icon=icon,name=name,promise=promise,tag=tag,color=tint(spec.color)}
    end
    self.reroll=button(self.picker,"Reroll","Reroll · 1 free",function() self:changeOffer("reroll") end)
    self.pickAny=button(self.picker,"PickAny","Pick Any · 1 free",function() self:changeOffer("pickAny") end)
    self.resourceHint=label(self.picker,"ResourceHint",11,MUTED)
    self.fightButton=button(self.picker,"Lock","LOCK IN",function() self:fight() end)
    self.fightButton.BackgroundColor3=GREEN; self.fightButton.TextColor3=NAVY; self.fightButton.Font=Enum.Font.FredokaOne
    self.fightButton.Edge.Color=WHITE; self.fightButton.Edge.Thickness=2
    self.reveal=make("Frame",self.panel,"SimultaneousReveal"); self.reveal.BackgroundTransparency=1; self.reveal.Visible=false
    self.revealTitle=label(self.reveal,"Title",24,GOLD); self.revealTitle.Font=Enum.Font.FredokaOne
    self.revealPersonality=label(self.reveal,"Personality",12,MUTED)
    self.reveals={}
    for side=1,2 do
        local frame=make("Frame",self.reveal,"Pilot"..side); frame.BackgroundColor3=NAVY; frame.BackgroundTransparency=0.06; frame.BorderSizePixel=0
        make("UICorner",frame,"Corner").CornerRadius=UDim.new(0,16); edge(frame,SIDES[side],2)
        local name=label(frame,"Identity",13,SIDES[side]); local skill=label(frame,"Skill",22); skill.Font=Enum.Font.FredokaOne
        self.reveals[side]={frame=frame,name=name,skill=skill}
    end
    self.search=make("Frame",self.panel,"Searching"); self.search.BackgroundTransparency=1
    self.searchTitle=label(self.search,"Title",38); self.searchTitle.Font=Enum.Font.FredokaOne
    self.searchHint=label(self.search,"Hint",16,MUTED)
    self.cancel=button(self.search,"Cancel","Cancel search",function() self.audio:ui("back"); self:send("exit") end)
    self.result=make("ScrollingFrame",self.panel,"Result"); self.result.BorderSizePixel=0; self.result.ScrollBarThickness=3; self.result.CanvasSize=UDim2.fromOffset(0,0); self.result.ScrollingDirection=Enum.ScrollingDirection.Y; self.result.BackgroundTransparency=1; self.result.ZIndex=20; self.result.Visible=false
    self.banner=label(self.result,"Banner",64,GOLD); self.banner.Font=Enum.Font.FredokaOne; self.banner.ZIndex=22
    self.resultLine=label(self.result,"Line",19); self.resultLine.ZIndex=22
    self.resultFact=label(self.result,"TurningPoint",15,MUTED); self.resultFact.ZIndex=22
    self.resultBuilds=label(self.result,"Builds",14); self.resultBuilds.ZIndex=22
    self.resultHint=label(self.result,"Hint",13,MUTED); self.resultHint.ZIndex=22
    self.replay=button(self.result,"Replay","REMATCH",function() self:rematch() end)
    self.replay.BackgroundColor3=GREEN; self.replay.TextColor3=NAVY; self.replay.Font=Enum.Font.FredokaOne
    self.edit=button(self.result,"NextOpponent","Next opponent",function() self.audio:ui("confirm"); self:send("again") end)
    self.leave=button(self.result,"Leave","Hangar",function()
        self.audio:ui("back"); self:send(self.data and self.data.rematchVotes and self.data.rematchVotes[2] and "rematchDecline" or "exit")
    end)
    for _,item in ipairs({self.replay,self.edit,self.leave}) do item.ZIndex=22 end
    self.rewardCard=make("Frame",self.result,"CosmeticRewards"); self.rewardCard.BackgroundColor3=NAVY; self.rewardCard.BackgroundTransparency=0.08
    self.rewardCard.BorderSizePixel=0; self.rewardCard.ZIndex=21; make("UICorner",self.rewardCard,"Corner").CornerRadius=UDim.new(0,14)
    edge(self.rewardCard,Color3.fromRGB(111,144,175),1)
    self.rewardTitle=label(self.rewardCard,"Earned",20,GOLD); self.rewardTitle.ZIndex=22
    self.rewardStatus=label(self.rewardCard,"SaveStatus",11,MUTED); self.rewardStatus.ZIndex=22
    self.goalPreview=make("Frame",self.rewardCard,"GoalPreview"); self.goalPreview.BorderSizePixel=0; self.goalPreview.ZIndex=22; self.goalPreview.BackgroundColor3=Color3.new(1,1,1)
    make("UICorner",self.goalPreview,"Corner").CornerRadius=UDim.new(1,0)
    self.goalGradient=make("UIGradient",self.goalPreview,"TrailColors")
    self.goalName=label(self.rewardCard,"Goal",14); self.goalName.ZIndex=22
    self.goalAction=button(self.rewardCard,"GoalAction","",function() self:goalActionRequested() end); self.goalAction.ZIndex=22
    self.starterTitle=label(self.rewardCard,"FirstMatchGift",14,GREEN); self.starterTitle.ZIndex=22
    self.starterCards={}
    for _,id in ipairs(self.cosmetics.STARTER_CHOICES or {}) do
        local item=self.cosmetics.get(id)
        local card=button(self.rewardCard,"Claim"..id,item.name.." · Claim + equip",function() self:claimStarter(id) end)
        card.ZIndex=22; card.TextSize=13
        local swatch=make("Frame",card,"TrailPreview"); swatch.BorderSizePixel=0; swatch.ZIndex=23
        swatch.BackgroundColor3=tint(item.color); make("UICorner",swatch,"Corner").CornerRadius=UDim.new(1,0)
        local gradient=make("UIGradient",swatch,"Colors"); gradient.Color=ColorSequence.new(tint(item.color),tint(item.secondaryColor))
        self.starterCards[#self.starterCards+1]={button=card,swatch=swatch,item=item}
    end
    self.confetti={}
    for n=1,28 do
        local item=make("Frame",self.result,"Confetti"); item.BorderSizePixel=0; item.ZIndex=20
        item.BackgroundColor3=({GOLD,SIDES[1],SIDES[2],GREEN})[n%4+1]
        self.confetti[n]={frame=item,x=(n*0.618)%1,speed=95+n*4,offset=(n*0.31)%1}
    end
    self.flash=make("Frame",self.panel,"ImpactFlash"); self.flash.Size=UDim2.fromScale(1,1)
    self.flash.BorderSizePixel=0; self.flash.Active=false; self.flash.BackgroundColor3=Color3.new(1,1,1); self.flash.BackgroundTransparency=1; self.flash.ZIndex=40
    self.count=label(self.panel,"Countdown",120,GOLD); self.count.Font=Enum.Font.FredokaOne
    self.count.TextWrapped=false; self.count.ZIndex=41; self.count.AnchorPoint=Vector2.new(0.5,0.5); self.count.Visible=false
    local stroke=make("UIStroke",self.count,"Edge"); stroke.Thickness=5; stroke.Color=NAVY
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
    self:syncDraft(old,data)
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
function BattleLab:syncDraft(old,data)
    if not old or old.matchId~=data.matchId or old.stage~=data.stage or old.offerRevision~=data.offerRevision or data.phase~="Pick" or (data.locked and data.locked[1]) then
        self.pendingSelection=nil; self.pendingOfferChange=nil
    elseif data.selected==self.pendingSelection then self.pendingSelection=nil end
    local eligible=data.pickAnyActive and data.eligible or data.offer
    if self.pendingSelection and not table.find(eligible or {},self.pendingSelection) then self.pendingSelection=nil end
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
function BattleLab:changeOffer(kind)
    local data=self.data
    if self.pendingOfferChange or not data or data.phase~="Pick" or (data.locked and data.locked[1]) then return end
    local resources=data.resources or {}
    if kind=="reroll" then
        if (resources.reroll or 0)<=0 or #(data.eligible or {})<=3 or data.pickAnyActive then return end
    elseif kind=="pickAny" then
        if (resources.pickAny or 0)<=0 or data.pickAnyActive then return end
    else return end
    -- Keep the old cards inert until the replacement offer is acknowledged.
    -- A normal snapshot of the old revision must not reopen them.
    self.pendingOfferChange=true; self.pendingSelection=nil
    self.audio:ui("select"); self:send(kind)
end
function BattleLab:choose(skillId)
    local data=self.data
    if self.pendingOfferChange or not data or data.phase~="Pick" or (data.locked and data.locked[1]) then return end
    local choices=data.pickAnyActive and data.eligible or data.offer
    if not table.find(choices or {},skillId) then return end
    self.pendingSelection=skillId; self.audio:ui(false)
    self:send("pick",{slot=data.slot,skillId=skillId})
end
function BattleLab:fight()
    local data=self.data
    if self.pendingOfferChange or not data or data.phase~="Pick" or (data.locked and data.locked[1]) then return end
    local selected=self.pendingSelection or data.selected
    if not selected or not table.find(data.pickAnyActive and data.eligible or data.offer or {},selected) then return end
    self.audio:ui(true); self:send("lock",{slot=data.slot,skillId=selected})
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
    local height=gift and 234 or 160; place(self.rewardCard,x,y,width,height)
    local bank=economy.credits or 0; local coins=reward and reward.coins or 0
    place(self.rewardTitle,10,8,width-20,27); self.rewardTitle.TextSize=width<450 and 17 or 20
    self.rewardTitle.Text=(coins>0 and ("+"..tostring(coins).." COINS  ·  ") or "")..tostring(bank).." IN YOUR BANK"
    local saves={saved="Saved",session_only="Studio session only · resets when Play stops",pending="Saving…",unavailable="Cloud save unavailable",loading="Loading…"}
    local status=data.saveStatus or (reward and reward.status) or "loading"
    place(self.rewardStatus,10,37,width-20,30)
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
        place(self.goalPreview,16,77,math.min(74,width*0.18),12)
        self.goalGradient.Color=ColorSequence.new(tint(item.color),tint(item.secondaryColor))
        local left=math.min(100,width*0.25)
        place(self.goalName,left,71,width-left-12,28); self.goalName.TextSize=width<450 and 12 or 14
        self.goalName.Text=item.name.." · "..(goal.owned and "Owned" or (tostring(math.min(bank,item.price)).." / "..tostring(item.price).." coins"))
        place(self.goalAction,12,107,width-24,44)
        local equipped=economy.equippedTrail==goal.id; local ready=goal.owned or bank>=goal.price
        local pending=self.cosmeticPending and os.clock()-self.cosmeticPending<3
        self.goalAction.Text=pending and "WORKING…" or (equipped and "EQUIPPED · COSMETIC ONLY" or (goal.owned and "EQUIP YOUR TRAIL" or (ready and "BUY TRAIL · "..tostring(goal.price).." COINS" or "EARN "..tostring(math.max(0,goal.price-bank)).." MORE · COSMETIC ONLY")))
        self.goalAction.TextSize=width<450 and 12 or 14
        enabled(self.goalAction,economy.canShop and ready and not equipped and not pending)
    end
    self.starterTitle.Visible=gift
    place(self.starterTitle,8,155,width-16,22); self.starterTitle.Text="FIRST MATCH GIFT · CHOOSE ONE TRAIL"
    self.starterTitle.TextSize=width<450 and 12 or 14
    for index,card in ipairs(self.starterCards) do
        card.button.Visible=gift
        local cardWidth=(width-32)/2; place(card.button,12+(index-1)*(cardWidth+8),183,cardWidth,44)
        place(card.swatch,8,7,cardWidth-16,4)
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
    if reason=="timeout" then return "The 35-second clock ended. More armor wins; equal armor draws." end
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
function BattleLab:showResult(data,width,height,top)
    local terminal=data.phase=="MatchOver" or data.phase=="Results"
    local visible=resultPhase(data.phase)
    self.result.Visible=visible; if not visible then self.resultKey=nil; return end
    local key=tostring(data.matchId)..":"..tostring(data.roundId)..":"..data.phase
    if self.resultKey~=key then self.resultKey=key; self.resultAt=os.clock(); self.resultSounded=false end
    local result=terminal and data.result or data.roundResult
    result=result or data.simulation or {}
    local winner=result.winner or 0
    local age=os.clock()-self.resultAt
    -- Controls are immediately available. The arena crash continues underneath.
    local area=height-top; place(self.result,0,top,width,area)
    local short=area<350; local compact=width<600
    local content=math.min(width-32,760); local x=(width-content)/2
    local bannerHeight=short and 36 or 70
    local y=short and 4 or (terminal and data.economy and 6 or math.max(12,(area-(terminal and 370 or 260))/2))
    place(self.banner,x,y,content,bannerHeight)
    self.banner.Text=terminal and (winner==1 and "VICTORY!" or (winner==2 and "DEFEAT" or "MATCH DRAW"))
        or (winner==1 and "ROUND WON!" or (winner==2 and "ROUND LOST" or "ROUND DRAW"))
    self.banner.TextColor3=winner==1 and GOLD or (winner==2 and SIDES[2] or WHITE)
    self.banner.TextSize=math.min(bannerHeight*0.8,content*0.13)
    if terminal and not self.resultSounded then self.resultSounded=true; self.audio:result(winner==1 and "win" or (winner==2 and "lose" or "draw")) end
    local score=result.score or data.score or {0,0}; y=y+bannerHeight
    place(self.resultLine,x,y,content,28)
    self.resultLine.Text=string.format("YOU  %d — %d  RIVAL",score[1] or 0,score[2] or 0)
    if terminal and data.reward and (data.reward.coins or 0)>0 then self.resultLine.Text=self.resultLine.Text.."  ·  +"..tostring(data.reward.coins).." COINS" end
    self.resultLine.TextSize=short and 15 or (compact and 17 or 23)
    y=y+(short and 26 or 32); place(self.resultFact,x,y,content,short and 36 or 46)
    self.resultFact.Text=self:factText(result); self.resultFact.TextSize=short and 12 or 15; y=y+(short and 38 or 54)
    place(self.resultBuilds,x,y,content,short and 34 or 48)
    self.resultBuilds.Text="YOU: "..self:buildText((data.settings or {})[1]).."\nRIVAL: "..self:buildText((data.settings or {})[2])
    self.resultBuilds.TextSize=compact and 11 or 14; self.resultBuilds.Visible=not short; y=y+(short and 0 or 56)
    self.replay.Visible=terminal; self.edit.Visible=terminal; self.leave.Visible=terminal
    local votes=data.rematchVotes or {}
    local waiting=votes[1]==true; local gone=data.rivalGone==true
    self.replay.Text=gone and "RIVAL LEFT" or (waiting and "WAITING FOR RIVAL…" or (votes[2] and "ACCEPT REMATCH" or "REMATCH"))
    enabled(self.replay,not waiting and not gone)
    if terminal then
        local primary=short and 48 or 56
        place(self.replay,x,y,content,primary); self.replay.TextSize=short and 22 or 28; y=y+primary+8
        place(self.edit,x,y,(content-8)/2,44); place(self.leave,x+(content+8)/2,y,(content-8)/2,44); y=y+50
    end
    place(self.resultHint,x,y,content,26)
    self.resultHint.Text=terminal and (gone and "Choose Next opponent to find a new match." or (data.economy and data.economy.progression and data.economy.progression.starterAvailable and "Your first-match gift is below ↓ · Replay whenever you like." or "Rematch keeps this rival. Both pilots start a fresh build."))
        or (winner==0 and "Same builds. New round starts shortly." or "Next pick starts shortly. Both pilots add a wild card.")
    self.resultHint.TextSize=short and 11 or 13
    local endY=self:showRewards(data,x,y+34,content)
    self.result.CanvasSize=UDim2.fromOffset(0,math.max(y+30,endY))
    self:reportRewardShown(data)
    for _,piece in ipairs(self.confetti) do
        piece.frame.Visible=terminal and winner==1 and not self.reducedMotion
        if piece.frame.Visible then
            place(piece.frame,piece.x*width,(age*piece.speed+piece.offset*area)%(area+30)-15,7,11)
            piece.frame.Rotation=age*90
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
    self.reducedMotion=player:GetAttribute("SkyboundReducedMotion")==true
    self.view.reducedMotion=self.reducedMotion
    local compact=width<600; local short=height<500; local searching=data.phase=="Searching"; local pick=data.phase=="Pick"
    local landscapeDraft=short and width>height
    local headerHeight=short and 74 or (compact and 100 or 108)
    local controlsHeight=48; local contentTop=headerHeight+controlsHeight
    place(self.header,0,0,width,headerHeight)
    place(self.exit,8,headerHeight+3,44,44); place(self.mute,56,headerHeight+3,44,44)
    place(self.motion,104,headerHeight+3,94,44); self.motion.TextSize=11
    self.mute.Text=muted and "🔇" or "🔊"; self.motion.Text=self.reducedMotion and "Motion reduced" or "Motion on"
    local sim=data.simulation or {}; local builds=data.settings or {}; local identities=data.players or {}
    local score=data.score or {0,0}; local center=compact and 72 or 112
    local plate=(width-center)/2-12; local face=(compact or short) and 32 or 46
    for i,fighter in ipairs(self.fighters) do
        local identity=identities[i] or {}; local right=i==2; local x=right and width-plate-8 or 8
        local align=right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
        place(fighter.frame,x,5,plate,headerHeight-10)
        place(fighter.ring,right and plate-face or 0,0,face,face)
        local tx=right and 0 or face+8; local tw=math.max(20,plate-face-8)
        place(fighter.name,tx,0,tw,21); fighter.name.TextSize=compact and 12 or 17; fighter.name.TextXAlignment=align
        fighter.name.Text=identity.name or (i==1 and player.DisplayName or "Finding rival…")
        place(fighter.role,tx,23,tw,16); fighter.role.TextXAlignment=align
        fighter.role.Text=i==1 and "YOU" or (identity.bot and "RIVAL · BOT" or "RIVAL · PLAYER")
        if searching then fighter.role.Text=i==1 and "YOU" or "SEARCHING" end
        fighter.face.Image=self.portraits[identity.userId] or ""
        fighter.bot.Text=identity.bot and (identity.portrait or "🤖") or ""
        fighter.bot.Visible=identity.bot==true
        place(fighter.build,0,face+3,plate,compact and 24 or 20); fighter.build.TextWrapped=compact; fighter.build.TextXAlignment=align
        fighter.build.Text=self:buildIcons(builds[i]); fighter.build.TextSize=short and 14 or 18
        local state=(sim.fighters or {})[i] or {}; local pipY=short and headerHeight-17 or headerHeight-23; local gap=5
        local pipWidth=math.min(46,(plate-2*gap)/3)
        for n,pip in ipairs(fighter.pips) do
            place(pip,right and plate-n*pipWidth-(n-1)*gap or (n-1)*(pipWidth+gap),pipY,pipWidth,8)
            pip.BackgroundColor3=n<=(state.armor or 3) and SIDES[i] or Color3.fromRGB(52,66,83)
        end
    end
    local left=self:clockSeconds(workspace:GetServerTimeNow())
    place(self.clock,width/2-center/2,3,center,short and 30 or 40); self.clock.TextSize=short and 25 or 32
    self.clock.Text=(data.phase=="Fight" or pick) and tostring(left) or "VS"
    self.clock.TextColor3=data.phase=="Fight" and left<=5 and SIDES[2] or WHITE
    place(self.score,width/2-center/2,short and 33 or 43,center,short and 20 or 24); self.score.Text=tostring(score[1] or 0).." — "..tostring(score[2] or 0)
    place(self.round,width/2-center/2,short and 54 or 68,center,15); self.round.Text=searching and "FINDING RIVAL" or ("ROUND "..tostring(math.max(1,data.roundNumber or 1)).." / 5")
    self.picker.Visible=pick; self.search.Visible=searching
    self.experimental.Visible=data.experimental==true and (pick or searching or resultPhase(data.phase))
    place(self.experimental,202,headerHeight+3,math.max(0,width-210),38)
    self.status.Visible=not pick and not searching and not resultPhase(data.phase)
    self.help.Visible=self.status.Visible
    place(self.status,202,headerHeight+3,math.max(0,width-210),22); self.status.TextSize=compact and 13 or 20
    place(self.help,202,headerHeight+24,math.max(0,width-210),17); self.help.TextSize=compact and 11 or 12
    self.status.Text=data.matchPoint and "MATCH POINT" or ((sim.pressure or 0)>0 and "WIND CLOSING IN" or "FIRST TO TWO")
    if data.experimental then self.status.Text="EXPERIMENTAL · "..self.status.Text end
    self.help.Text=compact and "Automatic combat" or "Your pilot fights automatically"
    if searching then
        place(self.search,0,contentTop,width,height-contentTop)
        local area=height-contentTop; local y=math.max(14,(area-180)/2)
        place(self.searchTitle,16,y,width-32,55); self.searchTitle.Text="FINDING YOUR RIVAL"; self.searchTitle.TextSize=compact and 28 or 38
        place(self.searchHint,24,y+62,width-48,50)
        self.searchHint.Text="Looking for another pilot…\nA named bot joins after about 8 seconds."
        place(self.cancel,math.max(16,width/2-130),y+124,math.min(width-32,260),48)
    elseif pick then
        local area=height-contentTop; place(self.picker,0,contentTop,width,area)
        self.picker.ScrollingEnabled=not landscapeDraft
        self.picker.ScrollBarThickness=landscapeDraft and 0 or 3
        if landscapeDraft then self.picker.CanvasPosition=Vector2.zero end
        local panel=math.min(width-24,880); local x=(width-panel)/2; local y=2
        local locked=data.locked and data.locked[1]; local rivalLocked=data.locked and data.locked[2]
        local titleHeight=short and 26 or 38
        place(self.pickTitle,x,y,panel,titleHeight); self.pickTitle.TextSize=short and 23 or (compact and 28 or 34)
        self.pickTitle.Text=locked and "PICK LOCKED" or (data.slot=="offence" and "CHOOSE YOUR OFFENCE" or "ADD A WILD CARD")
        y=y+titleHeight
        self.pickHint.Visible=not landscapeDraft
        place(self.pickHint,x,y,panel,short and 28 or 34); self.pickHint.TextSize=short and 10 or 13
        self.pickHint.Text=locked and (rivalLocked and "Both locked. Revealing together…" or "Waiting for your rival. Picks stay hidden until both lock.")
            or "Pick skills; your pilot fights automatically. First to two wins."
        y=y+(landscapeDraft and 0 or short and 30 or 38)
        self.draftBuilds.Visible=not short; place(self.draftBuilds,x,y,panel,short and 26 or 40); self.draftBuilds.TextSize=short and 10 or 12
        self.draftBuilds.Text="YOU: "..self:buildText(builds[1]).."\nRIVAL: "..self:buildText(builds[2])..(rivalLocked and "  🔒" or "")
        y=y+(short and 0 or 44)
        local bottom=landscapeDraft and 50 or short and 112 or 126
        local listHeight=landscapeDraft and math.max(0,area-y-bottom) or math.max(62,area-y-bottom)
        place(self.cardList,x,y,panel,listHeight)
        local choices=data.pickAnyActive and data.eligible or data.offer or {}
        local rows=compact and not landscapeDraft and #choices or math.ceil(#choices/3)
        local gap=8
        local cardHeight=landscapeDraft and math.max(80,listHeight) or compact and math.max(78,math.min(100,(listHeight-gap*2)/3)) or math.max(98,listHeight/math.max(1,rows)-gap)
        local cols=compact and not landscapeDraft and 1 or math.min(3,math.max(1,#choices)); local cardWidth=(panel-(cols-1)*gap)/cols
        local selected=self.pendingSelection or data.selected
        for _,card in pairs(self.powerCards) do card.button.Visible=false end
        for index,id in ipairs(choices) do
            local card=self.powerCards[id]
            if card then
                local chosen=selected==id; card.button.Visible=true
                local row,col=math.floor((index-1)/cols),(index-1)%cols
                place(card.button,col*(cardWidth+gap)+2,row*(cardHeight+gap)+3,cardWidth-4,cardHeight-6)
                card.button.BackgroundColor3=card.color:Lerp(NAVY,chosen and 0 or 0.13)
                card.button.Edge.Color=chosen and GOLD or card.color; card.button.Edge.Thickness=chosen and 3 or 1
                enabled(card.button,not locked and not self.pendingOfferChange)
                local horizontal=compact or cardHeight<145
                if landscapeDraft then
                    place(card.icon,6,5,30,24); card.icon.TextSize=23
                    place(card.name,40,5,cardWidth-52,24); card.name.TextSize=16; card.name.TextXAlignment=Enum.TextXAlignment.Left
                    place(card.promise,8,32,cardWidth-20,cardHeight-43); card.promise.TextSize=11; card.promise.TextXAlignment=Enum.TextXAlignment.Left
                    card.tag.Visible=false
                elseif horizontal then
                    place(card.icon,4,12,54,cardHeight-28); card.icon.TextSize=34
                    place(card.name,62,6,cardWidth-74,23); card.name.TextSize=compact and 19 or 18; card.name.TextXAlignment=Enum.TextXAlignment.Left
                    place(card.promise,62,31,cardWidth-76,cardHeight-38); card.promise.TextSize=11; card.promise.TextXAlignment=Enum.TextXAlignment.Left
                    card.tag.Visible=false
                else
                    place(card.icon,0,10,cardWidth,44); card.icon.TextSize=40
                    place(card.name,8,58,cardWidth-16,30); card.name.TextSize=22; card.name.TextXAlignment=Enum.TextXAlignment.Center
                    place(card.promise,12,92,cardWidth-24,cardHeight-121); card.promise.TextSize=13; card.promise.TextXAlignment=Enum.TextXAlignment.Center
                    place(card.tag,8,cardHeight-28,cardWidth-16,18); card.tag.Visible=true; card.tag.Text=chosen and "✓ SELECTED" or "TAP TO SELECT"
                end
            end
        end
        self.cardList.CanvasSize=UDim2.fromOffset(0,rows*(cardHeight+gap)-(landscapeDraft and gap or 0))
        y=y+listHeight+(landscapeDraft and 6 or 8)
        local resources=data.resources or {}; local reroll=(resources.reroll or 0)>0; local any=(resources.pickAny or 0)>0
        local canReroll=reroll and not locked and not self.pendingOfferChange and #((data.eligible) or {})>3 and not data.pickAnyActive
        self.reroll.Text=reroll and "Reroll · 1 free" or "Reroll used"
        self.pickAny.Text=data.pickAnyActive and "All eligible shown" or (any and "Pick Any · 1 free" or "Pick Any used")
        enabled(self.reroll,canReroll); enabled(self.pickAny,any and not locked and not self.pendingOfferChange and not data.pickAnyActive)
        self.reroll.TextSize=short and 12 or 14; self.pickAny.TextSize=short and 12 or 14
        self.resourceHint.Visible=not landscapeDraft
        if landscapeDraft then
            local actionWidth=(panel-16)/3
            place(self.reroll,x,y,actionWidth,44); place(self.pickAny,x+actionWidth+8,y,actionWidth,44)
            place(self.fightButton,x+2*(actionWidth+8),y,actionWidth,44); self.fightButton.TextSize=18
        else
            place(self.reroll,x,y,(panel-8)/2,40); place(self.pickAny,x+(panel+8)/2,y,(panel-8)/2,40); y=y+43
            place(self.resourceHint,x,y,panel,short and 16 or 20); self.resourceHint.TextSize=short and 9 or 10
            self.resourceHint.Text=self.pendingOfferChange and "Updating your cards…" or data.rerollReason or "One of each per match · Same skill access for every pilot"
            y=y+(short and 18 or 23)
            place(self.fightButton,x,y,panel,short and 44 or 50); self.fightButton.TextSize=short and 22 or 27
        end
        self.fightButton.Text=self.pendingOfferChange and "UPDATING CARDS…" or locked and "WAITING FOR RIVAL…" or (selected and "LOCK IN" or landscapeDraft and "CHOOSE A CARD" or "TAP A CARD TO CHOOSE")
        enabled(self.fightButton,not locked and not self.pendingOfferChange and selected~=nil)
        self.picker.CanvasSize=UDim2.fromOffset(0,landscapeDraft and area or y+(short and 48 or 54))
    end
    self:showResult(data,width,height,contentTop)
    local call=nil
    self.reveal.Visible=data.phase=="Countdown"
    if self.reveal.Visible then
        local area=height-contentTop; local revealWidth=math.min(width-28,780); local revealHeight=short and 100 or (compact and 190 or 132)
        place(self.reveal,(width-revealWidth)/2,contentTop+math.max(6,area*0.1),revealWidth,revealHeight)
        place(self.revealTitle,0,0,revealWidth,short and 26 or 34)
        self.revealTitle.Text=self.sameBuildReplay and "DRAW REPLAY · SAME BUILDS" or (data.matchPoint and "MATCH POINT · REVEAL!" or "PICKS REVEALED!")
        self.revealTitle.TextSize=short and 17 or 24
        self.revealPersonality.Visible=not short and (data.roundNumber or 1)==1 and identities[2] and identities[2].bot==true
        place(self.revealPersonality,0,revealHeight+6,revealWidth,28)
        self.revealPersonality.Text=identities[2] and identities[2].personality or ""
        for side,item in ipairs(self.reveals) do
            local stacked=compact and not short; local rowHeight=short and 66 or 72
            local cardWidth=stacked and revealWidth or (revealWidth-12)/2
            place(item.frame,stacked and 0 or (side-1)*(cardWidth+12),(short and 30 or 40)+(stacked and (side-1)*(rowHeight+8) or 0),cardWidth,rowHeight)
            local identity=identities[side] or {}; place(item.name,8,5,cardWidth-16,18)
            item.name.Text=side==1 and "YOU" or ((identity.name or "Rival")..(identity.bot and " · BOT" or ""))
            local build=builds[side] or {}; local id=data.stage==1 and build.offenceId or (build.wildIds or {})[math.max(1,(data.stage or 2)-1)]
            local skill=self.skills.get(id or "")
            place(item.skill,8,25,cardWidth-16,rowHeight-30); item.skill.TextSize=short and 18 or 23
            item.skill.Text=skill and (skill.icon.." "..skill.name) or "SAME BUILD"
        end
    end
    if data.phase=="Countdown" then
        local remaining=(data.endsAt or 0)-workspace:GetServerTimeNow()
        if self.countRound~=data.roundId then self.countRound=data.roundId; self.countSpan=math.max(0.3,remaining) end
        call=tostring(4-math.clamp(math.floor((1-remaining/self.countSpan)*3)+1,1,3))
    elseif data.phase=="Fight" and (sim.elapsed or 0)<0.65 then call="FIGHT!" end
    self.count.Visible=call~=nil
    if call then
        self.count.Text=call; place(self.count,width/2,contentTop+(height-contentTop)*(data.phase=="Countdown" and 0.74 or 0.5),width,short and 80 or 140)
        self.count.TextSize=math.min(short and 64 or (call=="FIGHT!" and 110 or 130),width*0.24)
    end
    local inset=GuiService:GetGuiInset(); place(self.scrim,-inset.X,-inset.Y,width+inset.X*2,height+inset.Y)
    self.scrim.BackgroundTransparency=(pick or searching) and 0.12 or (self.result.Visible and 0.3 or 1)
    local origin=self.root.AbsolutePosition+inset
    self.view:update(data,dt,{left=origin.X+10,right=origin.X+width-10,top=origin.Y+contentTop+8,bottom=origin.Y+height-8})
    self.flash.BackgroundTransparency=self.reducedMotion and 1 or (1-math.min(0.6,self.view.screenFlash*0.6))
end
return BattleLab
