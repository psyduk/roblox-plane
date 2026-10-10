-- A browse -> preview -> buy -> equip flow. Only server snapshots grant ownership.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("FlightGame")
local Catalog = require(shared:WaitForChild("CosmeticCatalog"))
local World = require(shared:WaitForChild("World"))
local Shop = {}
Shop.__index = Shop
local C = { ink=Color3.fromRGB(23,39,77), panel=Color3.fromRGB(255,254,247), tile=Color3.fromRGB(214,236,253),
    white=Color3.fromRGB(255,254,247), muted=Color3.fromRGB(67,87,117), gold=Color3.fromRGB(255,217,65),
    teal=Color3.fromRGB(64,224,248), green=Color3.fromRGB(105,226,66), amber=Color3.fromRGB(153,79,12) }
local function create(kind, props, parent)
    local object=Instance.new(kind)
    for key,value in pairs(props) do object[key]=value end
    object.Parent=parent
    return object
end
local function box(parent,name,color)
    return create("Frame",{Name=name,BackgroundColor3=color or C.panel,BorderSizePixel=0},parent)
end
local function round(parent,radius)
    create("UICorner",{CornerRadius=UDim.new(0,radius or 10)},parent)
end
local function stroke(parent,tint,thickness)
    return create("UIStroke",{Name="Border",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=tint or C.ink,Thickness=thickness or 2},parent)
end
local function text(parent,name,value,size,color)
    return create("TextLabel",{Name=name,Text=value,BackgroundTransparency=1,TextSize=size or 14,
        TextColor3=color or C.ink,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center},parent)
end
local function display(parent,name,value,size,tint)
    local label=text(parent,name,value,size,tint or C.white)
    label.Font=Enum.Font.FredokaOne
    create("UIStroke",{Name="LetterOutline",ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual,Color=C.ink,Thickness=2},label)
    return label
end
local function button(parent,name,value,color)
    local object=create("TextButton",{Name=name,Text=value,TextSize=20,Font=Enum.Font.FredokaOne,
        TextColor3=C.ink,BackgroundColor3=color or C.tile,BorderSizePixel=0,Selectable=true,AutoButtonColor=true},parent)
    round(object,14); stroke(object)
    return object
end
local function place(object,x,y,w,h)
    object.Position=UDim2.fromOffset(x,y); object.Size=UDim2.fromOffset(w,h)
end
local function color(rgb) return Color3.fromRGB(rgb.r,rgb.g,rgb.b) end
local function viewport(parent,name)
    local view=create("ViewportFrame",{Name=name,BackgroundColor3=C.tile,BorderSizePixel=0,
        Ambient=Color3.fromRGB(200,220,235),LightColor=Color3.new(1,1,1),LightDirection=Vector3.new(-1,-1,-1)},parent)
    round(view,12)
    local world=create("WorldModel",{},view)
    local camera=create("Camera",{FieldOfView=38,CFrame=CFrame.lookAt(Vector3.new(13,17,35),Vector3.new(-7,0,0))},view)
    view.CurrentCamera=camera
    return view,world,camera
end
local function previewPlane(world,item,settings)
    world:ClearAllChildren()
    local plane=World.createPlane(world,"EffectPreviewPlane",settings.color or 2,settings.planeId,item.id)
    plane:ScaleTo(1.4); plane:PivotTo(CFrame.new(3,0,0))
    -- ViewportFrame does not render Trails. This taper uses the actual trail's catalog colors.
    for index=1,18 do
        local t=(index-1)/17
        create("Part",{Name="TrailColorSample",Anchored=true,CanCollide=false,CastShadow=false,
            Material=Enum.Material.Neon,Color=color(item.color):Lerp(color(item.secondaryColor),t),
            Size=Vector3.new(1.05,math.max(0.1,item.width*(1-t*0.8)),0.35),
            CFrame=CFrame.new(-3-index,math.sin(t*4)*0.35,0),Transparency=t*0.7},world)
    end
end

function Shop.new(send)
    local self=setmetatable({send=send,selected=Catalog.DEFAULT_ID,phase="Lobby",pendingUntil=0,cards={},connections={},onlyOwned=false},Shop)
    self.gui=create("ScreenGui",{Name="SkyboundEffects",ResetOnSpawn=false,IgnoreGuiInset=false,
        DisplayOrder=30,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},Players.LocalPlayer:WaitForChild("PlayerGui"))
    self.reducedMotion=false
    pcall(function() self.reducedMotion=GuiService.ReducedMotionEnabled end)
    self.openButton=button(self.gui,"OpenEffects","",C.panel)
    self.rewardScale=create("UIScale",{Scale=1},self.openButton)
    self.coin=box(self.openButton,"Coin",C.gold); round(self.coin,50); stroke(self.coin,C.amber,3)
    self.coinInner=box(self.coin,"Inset",C.gold); round(self.coinInner,50); stroke(self.coinInner,C.amber,1.5)
    self.coinInner.Position=UDim2.fromScale(0.17,0.17); self.coinInner.Size=UDim2.fromScale(0.66,0.66)
    self.coinMark=text(self.coin,"Mark","S",28,C.amber); self.coinMark.Font=Enum.Font.FredokaOne
    self.coinMark.Size=UDim2.fromScale(1,1); self.coinMark.TextXAlignment=Enum.TextXAlignment.Center
    self.wallet=display(self.openButton,"CoinBalance","0",42,C.gold)
    self.wallet.TextScaled=true
    create("UITextSizeConstraint",{MinTextSize=14,MaxTextSize=42},self.wallet)
    self.walletCaption=text(self.openButton,"CoinLabel","COINS",12,C.muted)
    self.browseLabel=text(self.openButton,"Browse","EFFECTS",15,C.ink)
    self.browseLabel.Font=Enum.Font.FredokaOne; self.browseLabel.TextXAlignment=Enum.TextXAlignment.Right
    self.overlay=box(self.gui,"ShopOverlay",C.ink)
    self.overlay.Size=UDim2.fromScale(1,1); self.overlay.BackgroundTransparency=0.18
    self.overlay.Visible=false; self.overlay.Active=true
    self.card=box(self.overlay,"EffectsShop",C.panel); round(self.card,20); stroke(self.card,C.ink,3)
    self.card.AnchorPoint=Vector2.new(0.5,0.5); self.card.Position=UDim2.fromScale(0.5,0.5)
    self.title=display(self.card,"Title","TRAIL COLLECTION",34)
    self.balance=display(self.card,"Balance","0 COINS",25,C.gold)
    self.closeButton=button(self.card,"Close","X")
    self.body=create("ScrollingFrame",{Name="Browse",BackgroundTransparency=1,BorderSizePixel=0,
        ScrollBarThickness=5,ScrollBarImageColor3=C.ink,CanvasSize=UDim2.fromOffset(0,400)},self.card)
    self.filter=button(self.body,"CollectionFilter","ALL EFFECTS")
    self.collection=text(self.body,"CollectionCount","1 / 6 OWNED",13,C.muted)
    self.preview,self.previewWorld,self.previewCamera=viewport(self.body,"PlanePreview")
    self.previewName=display(self.body,"SelectedName","CLASSIC",27)
    self.previewDetail=text(self.body,"SelectedDescription","",15,C.muted); self.previewDetail.TextWrapped=true
    self.previewNote=text(self.body,"PreviewNote","FLIGHT EFFECT · COSMETIC ONLY",12,C.muted)
    for _,item in ipairs(Catalog.all()) do
        local control=button(self.body,item.id,"",C.tile)
        local swatch=box(control,"Swatch",color(item.color)); round(swatch,5)
        create("UIGradient",{Color=ColorSequence.new(color(item.color),color(item.secondaryColor))},swatch)
        local name=text(control,"ItemName",item.name,17); name.Font=Enum.Font.FredokaOne
        name.TextTruncate=Enum.TextTruncate.AtEnd
        local price=text(control,"Price",tostring(item.price).." COINS",13,C.ink)
        local border=control:FindFirstChild("Border")
        self.cards[item.id]={button=control,swatch=swatch,name=name,price=price,border=border}
        table.insert(self.connections,control.Activated:Connect(function()
            self.selected=item.id; self:_preview(); self:_refresh()
            if self.card.AbsoluteSize.X<600 then self.body.CanvasPosition=Vector2.zero end
        end))
    end
    self.status=text(self.card,"Feedback","Finish flights. Earn coins. Make your plane yours.",14,C.muted)
    self.status.TextWrapped=true
    self.action=button(self.card,"PurchaseOrEquip","EQUIPPED",C.teal); self.action.TextColor3=C.ink
    self.action.TextWrapped=true
    self.goalAction=button(self.card,"SetGoal","SET GOAL",C.tile)
    self.goalAction.TextWrapped=true
    table.insert(self.connections,self.goalAction.Activated:Connect(function()
        if self.goalAction.Active then self.send("selectGoal",{itemId=self.selected}) end
    end))
    self.saveLabel=text(self.card,"SaveStatus","",11,C.muted)
    table.insert(self.connections,self.openButton.Activated:Connect(function() self:openAt(self.nextItemId) end))
    table.insert(self.connections,self.closeButton.Activated:Connect(function() self:close() end))
    table.insert(self.connections,self.filter.Activated:Connect(function()
        self.onlyOwned=not self.onlyOwned
        if self.onlyOwned and not (self.economy and self.economy.owned[self.selected]) then
            self.selected=self.economy and self.economy.equippedTrail or Catalog.DEFAULT_ID
            self:_preview()
        end
        self:_layout(); self:_refresh()
    end))
    table.insert(self.connections,self.action.Activated:Connect(function()
        if not self.action.Active or os.clock()<self.pendingUntil or not self.economy then return end
        local owned=self.economy.owned[self.selected]
        self.pendingUntil=os.clock()+3
        local item=Catalog.get(self.selected)
        self.send(owned and "equipCosmetic" or (item.earnedOnly and "claimStarter" or "buyCosmetic"),{itemId=self.selected})
        self:_refresh()
    end))
    table.insert(self.connections,UserInputService.InputBegan:Connect(function(input,processed)
        if self.overlay.Visible and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then self:close() end
    end))
    self:_preview(); self:_layout()
    return self
end

function Shop:_preview()
    local item=Catalog.get(self.selected)
    previewPlane(self.previewWorld,item,self.settings or {})
    self.previewName.Text=string.upper(item.name)
    self.previewDetail.Text=item.description
end

function Shop:_layout()
    local size=self.gui.AbsoluteSize
    if size.X<1 then size=Vector2.new(960,660) end
    self.lastSize=size
    local portrait=size.X<600
    local short=not portrait and size.Y<500
    -- The wallet is a compact pill; the next unlock lives on its stand in the hangar.
    local rw=portrait and size.X-24 or (short and 190 or 214)
    local rh=short and 44 or 46
    self.openButton.AnchorPoint=portrait and Vector2.zero or Vector2.new(1,0)
    self.openButton.Position=portrait and UDim2.fromOffset(12,64) or UDim2.new(1,-16,0,short and 6 or 10)
    self.openButton.Size=UDim2.fromOffset(rw,rh)
    local coinSize=rh-14
    place(self.coin,10,7,coinSize,coinSize)
    self.coinMark.TextSize=22
    place(self.wallet,coinSize+18,2,rw-coinSize-108,rh-16)
    place(self.walletCaption,coinSize+19,rh-16,rw-coinSize-108,12)
    self.walletCaption.TextSize=9
    place(self.browseLabel,rw-96,0,84,rh)
    self.rewardBaseScale=1
    if not self.rewardTween or self.rewardTween.PlaybackState~=Enum.PlaybackState.Playing then
        self.rewardScale.Scale=self.rewardBaseScale
    end

    local w=math.min(920,size.X-20)
    local h=math.min(630,size.Y-16)
    self.card.Size=UDim2.fromOffset(w,h)
    local narrow=w<600
    local compact=not narrow and h<420
    self.previewCamera.FieldOfView=compact and 28 or 38
    self.filter.Parent=compact and self.card or self.body
    self.preview.Parent=compact and self.card or self.body
    self.previewName.Parent=compact and self.card or self.body
    self.collection.Visible=not compact
    self.previewDetail.Visible=not compact
    self.previewNote.Visible=not compact
    place(self.title,20,10,w-90,38); self.title.TextSize=narrow and (w<350 and 24 or 29) or 34
    place(self.balance,22,49,w-90,29); self.balance.TextSize=narrow and 22 or 25
    place(self.closeButton,w-66,14,48,48)
    local bodyY=compact and 82 or 92
    local footerHeight=compact and 100 or 132
    local bodyHeight=math.max(70,h-bodyY-footerHeight)
    place(self.body,16,bodyY,w-32,bodyHeight)
    local inner=w-40
    local listWidth=narrow and inner or math.floor(inner*0.49)
    if compact then self.body.Size=UDim2.fromOffset(listWidth,bodyHeight) end
    local listTop=narrow and 298 or 0
    place(self.filter,0,listTop,math.min(186,listWidth*0.57),46)
    self.filter.TextSize=narrow and 17 or 18
    if compact then place(self.filter,w-248,15,166,46) end
    place(self.collection,math.min(198,listWidth*0.6),listTop,listWidth-math.min(198,listWidth*0.6),46)
    local cellWidth=(listWidth-10)/2
    local cellHeight=compact and 76 or 94
    local rowStep=cellHeight+10
    local count=0
    for _,item in ipairs(Catalog.all()) do
        local card=self.cards[item.id]
        local visible=not self.onlyOwned or (self.economy and self.economy.owned[item.id])
        card.button.Visible=visible==true
        if visible then
            local row=math.floor(count/2); local col=count%2
            place(card.button,col*(cellWidth+10),listTop+(compact and 2 or 58)+row*rowStep,cellWidth,cellHeight)
            place(card.swatch,10,10,cellWidth-20,compact and 8 or 13)
            place(card.name,10,compact and 23 or 31,cellWidth-20,26)
            place(card.price,10,compact and 51 or 63,cellWidth-20,22)
            card.name.TextSize=cellWidth<150 and 15 or 18
            card.price.TextSize=cellWidth<150 and 12 or 14
            count+=1
        end
    end
    local listBottom=listTop+(compact and 2 or 58)+math.ceil(count/2)*rowStep
    local x=narrow and 0 or listWidth+20
    local previewWidth=narrow and inner or inner-x
    place(self.preview,x,0,previewWidth,narrow and 176 or 208)
    place(self.previewName,x,narrow and 183 or 218,previewWidth,34)
    place(self.previewDetail,x,narrow and 220 or 258,previewWidth,44)
    place(self.previewNote,x,narrow and 271 or 308,previewWidth,18)
    self.previewNote.TextSize=narrow and 11 or 12
    self.body.CanvasSize=UDim2.fromOffset(0,compact and listBottom or math.max(listBottom,narrow and 298 or 336))
    self.previewName.TextSize=compact and 20 or (narrow and 25 or 27)
    if compact then
        place(self.preview,16+x,bodyY,previewWidth,bodyHeight-30)
        place(self.previewName,16+x,bodyY+bodyHeight-27,previewWidth,27)
    end
    place(self.status,20,h-126,w-40,40)
    self.status.TextSize=narrow and 13 or 14
    place(self.action,20,h-78,w-40,52)
    self.action.TextSize=narrow and 17 or 22
    place(self.saveLabel,20,h-22,w-40,17)
    self.saveLabel.TextSize=narrow and 10 or 11
    if compact then
        place(self.status,20,h-97,w-40,27); self.status.TextSize=12
        place(self.action,20,h-66,w-40,46); self.action.TextSize=19
        place(self.saveLabel,20,h-18,w-40,16); self.saveLabel.TextSize=10
    end
    local goalWidth=math.min(150,math.floor((w-48)*0.32))
    local actionY=compact and h-66 or h-78
    local actionHeight=compact and 46 or 52
    place(self.action,20,actionY,w-48-goalWidth,actionHeight)
    self.action.TextSize=narrow and 14 or (compact and 15 or 19)
    place(self.goalAction,w-20-goalWidth,actionY,goalWidth,actionHeight)
    self.goalAction.TextSize=narrow and 13 or 15
end

function Shop:open()
    if self.phase~="Lobby" and self.phase~="Queued" then return end
    self.overlay.Visible=true
    self.openButton.Visible=false; self.openButton.Active=false; self.openButton.Selectable=false
    local hud=Players.LocalPlayer.PlayerGui:FindFirstChild("SkyboundHUD")
    if hud and hud:FindFirstChild("PersonalStats") then hud.PersonalStats.Visible=false end
    self:_layout(); self:_preview(); self:_refresh()
    if UserInputService.GamepadEnabled then GuiService.SelectedObject=self.cards[self.selected].button end
end

-- Open on a particular effect, defaulting to the trail currently equipped.
function Shop:openAt(itemId)
    self.selected=Catalog.get(itemId) and itemId or (self.economy and self.economy.equippedTrail) or Catalog.DEFAULT_ID
    self.onlyOwned=false
    self:open()
end

function Shop:close()
    self.overlay.Visible=false
    if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.overlay) then GuiService.SelectedObject=nil end
end

function Shop:isOpen() return self.overlay.Visible end

function Shop:_refresh()
    local economy=self.economy or {credits=0,owned={classic=true},equippedTrail=Catalog.DEFAULT_ID,canShop=false}
    local item=Catalog.get(self.selected)
    local count=0
    local nextItem
    for _,entry in ipairs(Catalog.all()) do
        local owned=economy.owned[entry.id]==true
        if owned then count+=1 elseif not nextItem and not entry.earnedOnly then nextItem=entry end
        local card=self.cards[entry.id]
        local selected=self.selected==entry.id
        card.border.Color=selected and C.ink or C.muted
        card.border.Thickness=selected and 3 or 1
        card.button.BackgroundColor3=selected and C.teal or C.tile
        card.price.Text=economy.equippedTrail==entry.id and "EQUIPPED" or (owned and "OWNED" or (entry.earnedOnly and "FIRST MATCH GIFT" or tostring(entry.price).." COINS"))
        card.price.TextColor3=C.ink
    end
    if economy.goal and not economy.goal.owned then nextItem=Catalog.get(economy.goal.id) end
    local credits=economy.credits or 0
    self.balance.Text=self.economy and (tostring(credits).." COINS") or "LOADING COINS…"
    self.wallet.Text=self.economy and tostring(credits) or "…"
    if economy.goal and not economy.goal.owned then
        self.wallet.Text=tostring(credits).." / "..tostring(economy.goal.price)
        self.walletCaption.Text=string.upper(economy.goal.name).." GOAL"
        self.walletCaption.TextScaled=true
    else self.walletCaption.Text="COINS";self.walletCaption.TextScaled=false end
    self.collection.Text=tostring(count).." / "..#Catalog.ORDER.." OWNED"
    self.filter.Text=self.onlyOwned and "MY COLLECTION" or "ALL EFFECTS"
    self.nextItemId=nextItem and nextItem.id or nil
    local canAfford=nextItem and credits>=nextItem.price
    if self.lastNextId~=self.nextItemId then self.pendingRewardPulse=nil end
    if self.lastNextId==self.nextItemId and self.lastAffordable==false and canAfford then
        self.pendingRewardPulse=self.nextItemId
    end
    self.lastNextId=self.nextItemId; self.lastAffordable=canAfford==true
    self.browseLabel.Text=canAfford and "NEW!" or "EFFECTS"
    self.openButton.BackgroundColor3=canAfford and C.gold or C.panel
    if self.pendingRewardPulse==self.nextItemId and canAfford and self.openButton.Visible and not self.overlay.Visible then
        self.pendingRewardPulse=false
        if not self.reducedMotion then
            if self.rewardTween then self.rewardTween:Cancel() end
            self.rewardScale.Scale=self.rewardBaseScale or 1
            self.rewardTween=TweenService:Create(self.rewardScale,TweenInfo.new(0.24,Enum.EasingStyle.Back,Enum.EasingDirection.Out,0,true),{Scale=(self.rewardBaseScale or 1)*1.06})
            self.rewardTween:Play()
        end
    end
    local pending=os.clock()<self.pendingUntil
    local equipped=economy.equippedTrail==item.id
    local owned=economy.owned[item.id]==true
    local affordable=credits>=item.price
    local gift=item.earnedOnly==true
    local giftReady=gift and economy.progression and economy.progression.starterAvailable==true
    local enabled=self.phase=="Lobby" and economy.canShop and not equipped and (owned or (gift and giftReady) or (not gift and affordable)) and not pending
    local isGoal=economy.goal and economy.goal.id==item.id
    local canGoal=not gift and item.price>0 and not owned and economy.canShop and not isGoal
    self.goalAction.Active=canGoal;self.goalAction.Selectable=canGoal;self.goalAction.AutoButtonColor=canGoal
    self.goalAction.Text=isGoal and "YOUR GOAL" or (gift and "FIRST MATCH GIFT" or "SET GOAL")
    self.goalAction.TextColor3=canGoal and C.ink or C.muted
    self.action.Active=enabled==true; self.action.Selectable=enabled==true; self.action.AutoButtonColor=enabled==true
    self.action.BackgroundColor3=enabled and (owned and C.teal or C.gold) or C.tile
    self.action.TextColor3=enabled and C.ink or C.muted
    self.action.Text=pending and "WORKING…" or (equipped and "EQUIPPED FOR YOUR NEXT FLIGHT"
        or (owned and ("EQUIP "..string.upper(item.name))
        or (affordable and ("BUY "..string.upper(item.name).." · "..item.price.." COINS")
        or ("EARN "..(item.price-credits).." MORE COINS"))))
    if gift and not owned then self.action.Text=giftReady and "CLAIM + EQUIP" or "COMPLETE YOUR FIRST MATCH" end
    local feedback=self.feedback
    if self.phase=="Queued" then self.status.Text="Leave the queue to buy or change your trail."
    elseif feedback and os.clock()<(self.feedbackUntil or 0) then
        self.status.Text=feedback.message:gsub("CREDITS","COINS"):gsub("credits","coins")
    elseif not economy.canShop then self.status.Text="Your collection is loading or saving is unavailable. Try again when ready."
    elseif owned then self.status.Text=equipped and "Your equipped trail follows your plane into every flight." or "Owned. Equip this trail for your next flight."
    elseif gift then self.status.Text="Your first completed battle grants one starter trail of your choice."
    elseif shared:GetAttribute("DistanceModeEnabled")==true then self.status.Text="Finish a practice flight: +25 coins. Finish a duel: +40, plus result bonuses."
    else self.status.Text="Complete a match: 50 coins. Win: 75. Cosmetic trails never change combat." end
    self.status.TextColor3=feedback and not feedback.ok and os.clock()<(self.feedbackUntil or 0) and C.amber or C.muted
    local saves={session_only="STUDIO SESSION · Purchases reset when Play stops.",loading="Loading your collection…",
        saved="Collection saved.",pending="Saving your collection…",unavailable="Cloud save unavailable. Purchases are disabled."}
    self.saveLabel.Text=saves[self.saveStatus] or "Loading your collection…"
end

function Shop:update(snapshot,settings)
    self.phase=snapshot.phase; self.economy=snapshot.economy; self.saveStatus=snapshot.saveStatus; self.settings=settings
    local inHub=self.phase=="Lobby" or self.phase=="Queued"
    local hud=Players.LocalPlayer.PlayerGui:FindFirstChild("SkyboundHUD")
    local stats=hud and hud:FindFirstChild("PersonalStats")
    self.openButton.Visible=inHub and not self.overlay.Visible and not (stats and stats.Visible)
    self.openButton.Active=self.openButton.Visible
    self.openButton.Selectable=self.openButton.Visible
    if not inHub then self:close() end
    local ownedKey=""
    for _,id in ipairs(Catalog.ORDER) do
        if self.economy and self.economy.owned[id] then ownedKey=ownedKey..id..":" end
    end
    if ownedKey~=self.ownedKey then self.ownedKey=ownedKey; self:_layout() end
    local feedback=snapshot.cosmeticFeedback
    if feedback and feedback.id~=self.lastFeedback then
        self.lastFeedback=feedback.id; self.feedback=feedback; self.feedbackUntil=os.clock()+5; self.pendingUntil=0
        if self.onlyOwned then self:_layout() end
    end
    if self.gui.AbsoluteSize~=self.lastSize then self:_layout() end
    self:_refresh()
end

function Shop:destroy()
    if self.rewardTween then self.rewardTween:Cancel() end
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self.gui:Destroy()
end

return Shop
