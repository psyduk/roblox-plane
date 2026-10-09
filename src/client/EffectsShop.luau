-- A browse -> preview -> buy -> equip flow. Only server snapshots grant ownership.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("FlightGame")
local Catalog = require(shared:WaitForChild("CosmeticCatalog"))
local World = require(shared:WaitForChild("World"))
local Shop = {}
Shop.__index = Shop
local C = { ink=Color3.fromRGB(19,32,49), panel=Color3.fromRGB(29,46,63), tile=Color3.fromRGB(42,62,79),
    white=Color3.fromRGB(242,246,238), muted=Color3.fromRGB(180,199,204), gold=Color3.fromRGB(255,207,94), teal=Color3.fromRGB(86,224,205) }
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
local function text(parent,name,value,size,color)
    return create("TextLabel",{Name=name,Text=value,BackgroundTransparency=1,TextSize=size or 14,
        TextColor3=color or C.white,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center},parent)
end
local function button(parent,name,value,color)
    local object=create("TextButton",{Name=name,Text=value,TextSize=14,Font=Enum.Font.GothamBold,
        TextColor3=C.white,BackgroundColor3=color or C.tile,BorderSizePixel=0,Selectable=true,AutoButtonColor=true},parent)
    round(object)
    return object
end
local function place(object,x,y,w,h)
    object.Position=UDim2.fromOffset(x,y); object.Size=UDim2.fromOffset(w,h)
end
local function color(rgb) return Color3.fromRGB(rgb.r,rgb.g,rgb.b) end

function Shop.new(send)
    local self=setmetatable({send=send,selected=Catalog.DEFAULT_ID,phase="Lobby",pendingUntil=0,cards={},connections={},onlyOwned=false},Shop)
    self.gui=create("ScreenGui",{Name="SkyboundEffects",ResetOnSpawn=false,IgnoreGuiInset=false,
        DisplayOrder=30,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},Players.LocalPlayer:WaitForChild("PlayerGui"))
    self.openButton=button(self.gui,"OpenEffects","FLIGHT EFFECTS  /  0 C",C.ink)
    self.openButton.AnchorPoint=Vector2.new(0,1)
    self.openButton.Position=UDim2.new(0,16,1,-88); self.openButton.Size=UDim2.fromOffset(228,48)
    self.goal=text(self.gui,"NextUnlock","Complete flights to earn your first trail.",11,C.white)
    self.goal.AnchorPoint=Vector2.new(0,1); self.goal.Position=UDim2.new(0,20,1,-140)
    self.goal.Size=UDim2.fromOffset(300,32); self.goal.TextWrapped=true
    self.goal.TextStrokeColor3=C.ink; self.goal.TextStrokeTransparency=0.15
    self.overlay=box(self.gui,"ShopOverlay",C.ink)
    self.overlay.Size=UDim2.fromScale(1,1); self.overlay.BackgroundTransparency=0.18
    self.overlay.Visible=false; self.overlay.Active=true
    self.card=box(self.overlay,"EffectsShop",C.panel); round(self.card,16)
    self.card.AnchorPoint=Vector2.new(0.5,0.5); self.card.Position=UDim2.fromScale(0.5,0.5)
    self.title=text(self.card,"Title","FLIGHT EFFECTS",24)
    self.balance=text(self.card,"Balance","0 CREDITS",13,C.gold)
    self.closeButton=button(self.card,"Close","X")
    self.body=create("ScrollingFrame",{Name="Browse",BackgroundTransparency=1,BorderSizePixel=0,
        ScrollBarThickness=4,ScrollBarImageColor3=C.teal,CanvasSize=UDim2.fromOffset(0,400)},self.card)
    self.filter=button(self.body,"CollectionFilter","ALL EFFECTS")
    self.collection=text(self.body,"CollectionCount","1 / 6 OWNED",11,C.muted)
    self.preview=create("ViewportFrame",{Name="PlanePreview",BackgroundColor3=C.ink,BorderSizePixel=0,
        Ambient=Color3.fromRGB(200,220,235),LightColor=Color3.new(1,1,1),LightDirection=Vector3.new(-1,-1,-1)},self.body)
    round(self.preview,12)
    self.previewWorld=create("WorldModel",{},self.preview)
    self.previewCamera=create("Camera",{FieldOfView=38,CFrame=CFrame.lookAt(Vector3.new(13,17,35),Vector3.new(-7,0,0))},self.preview)
    self.preview.CurrentCamera=self.previewCamera
    self.previewName=text(self.body,"SelectedName","CLASSIC",20)
    self.previewDetail=text(self.body,"SelectedDescription","",12,C.muted); self.previewDetail.TextWrapped=true
    self.previewNote=text(self.body,"PreviewNote","TRAIL COLOR PREVIEW  /  COSMETIC ONLY",10,C.muted)
    for _,item in ipairs(Catalog.all()) do
        local control=button(self.body,item.id,"",C.tile)
        local swatch=box(control,"Swatch",color(item.color)); round(swatch,5)
        create("UIGradient",{Color=ColorSequence.new(color(item.color),color(item.secondaryColor))},swatch)
        local name=text(control,"ItemName",item.name,13)
        name.TextTruncate=Enum.TextTruncate.AtEnd
        local price=text(control,"Price",tostring(item.price).." C",11,C.gold)
        local border=create("UIStroke",{Color=C.teal,Thickness=2,Enabled=false},control)
        self.cards[item.id]={button=control,swatch=swatch,name=name,price=price,border=border}
        table.insert(self.connections,control.Activated:Connect(function()
            self.selected=item.id; self:_preview(); self:_refresh()
            if self.card.AbsoluteSize.X<560 then self.body.CanvasPosition=Vector2.zero end
        end))
    end
    self.status=text(self.card,"Feedback","Finish flights. Earn credits. Make your plane yours.",12,C.muted)
    self.status.TextWrapped=true
    self.action=button(self.card,"PurchaseOrEquip","EQUIPPED",C.teal); self.action.TextColor3=C.ink
    self.saveLabel=text(self.card,"SaveStatus","",10,C.muted)
    table.insert(self.connections,self.openButton.Activated:Connect(function() self:open() end))
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
        self.send(owned and "equipCosmetic" or "buyCosmetic",{itemId=self.selected})
        self:_refresh()
    end))
    table.insert(self.connections,UserInputService.InputBegan:Connect(function(input,processed)
        if self.overlay.Visible and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then self:close() end
    end))
    self:_preview(); self:_layout()
    return self
end

function Shop:_preview()
    self.previewWorld:ClearAllChildren()
    local item=Catalog.get(self.selected)
    local settings=self.settings or {}
    local plane=World.createPlane(self.previewWorld,"EffectPreviewPlane",settings.color or 2,settings.planeId,item.id)
    plane:ScaleTo(1.4)
    plane:PivotTo(CFrame.new(3,0,0))
    -- ViewportFrame does not render Trails. A taper shows the same catalog colors.
    for index=1,18 do
        local t=(index-1)/17
        create("Part",{Name="TrailColorSample",Anchored=true,CanCollide=false,CastShadow=false,
            Material=Enum.Material.Neon,Color=color(item.color):Lerp(color(item.secondaryColor),t),
            Size=Vector3.new(1.05,math.max(0.1,item.width*(1-t*0.8)),0.35),
            CFrame=CFrame.new(-3-index,math.sin(t*4)*0.35,0),Transparency=t*0.7},self.previewWorld)
    end
    self.previewName.Text=string.upper(item.name)
    self.previewDetail.Text=item.description
end

function Shop:_layout()
    local size=self.gui.AbsoluteSize
    if size.X<1 then size=Vector2.new(960,660) end
    self.lastSize=size
    local w=math.min(790,size.X-20)
    local h=math.min(526,size.Y-16)
    self.card.Size=UDim2.fromOffset(w,h)
    local narrow=w<560
    local compact=not narrow and h<390
    self.previewCamera.FieldOfView=compact and 26 or 38
    self.filter.Parent=compact and self.card or self.body
    self.preview.Parent=compact and self.card or self.body
    self.previewName.Parent=compact and self.card or self.body
    self.collection.Visible=not compact
    self.previewDetail.Visible=not compact
    self.previewNote.Visible=not compact
    place(self.title,18,10,w-85,29); self.title.TextSize=narrow and 20 or 24
    place(self.balance,18,40,w-85,20)
    place(self.closeButton,w-58,12,44,44)
    local bodyHeight=math.max(70,h-(compact and 166 or 181))
    place(self.body,14,68,w-28,bodyHeight)
    local inner=w-34
    local listWidth=narrow and inner or math.floor(inner*0.48)
    if compact then self.body.Size=UDim2.fromOffset(listWidth,bodyHeight) end
    local listTop=narrow and 298 or 0
    place(self.filter,0,listTop,150,44)
    if compact then place(self.filter,w-224,12,150,44) end
    place(self.collection,160,listTop,listWidth-160,44)
    local cellWidth=(listWidth-8)/2
    local count=0
    for _,item in ipairs(Catalog.all()) do
        local card=self.cards[item.id]
        local visible=not self.onlyOwned or (self.economy and self.economy.owned[item.id])
        card.button.Visible=visible==true
        if visible then
            local row=math.floor(count/2); local col=count%2
            place(card.button,col*(cellWidth+8),listTop+(compact and 0 or 54)+row*85,cellWidth,77)
            place(card.swatch,10,10,cellWidth-20,9)
            place(card.name,10,24,cellWidth-20,22)
            place(card.price,10,49,cellWidth-20,19)
            card.name.TextSize=cellWidth<150 and 12 or 13
            count+=1
        end
    end
    local listBottom=listTop+(compact and 0 or 54)+math.ceil(count/2)*85
    local x=narrow and 0 or listWidth+18
    local y=0
    local previewWidth=narrow and inner or inner-x
    place(self.preview,x,y,previewWidth,172)
    place(self.previewName,x,y+180,previewWidth,27)
    place(self.previewDetail,x,y+209,previewWidth,48)
    place(self.previewNote,x,y+264,previewWidth,17)
    self.previewNote.TextSize=narrow and 9 or 10
    self.body.CanvasSize=UDim2.fromOffset(0,compact and listBottom or math.max(listBottom,y+285))
    self.previewName.TextSize=compact and 15 or 20
    if compact then
        place(self.preview,14+x,68,previewWidth,bodyHeight-25)
        place(self.previewName,14+x,68+bodyHeight-23,previewWidth,23)
    end
    place(self.status,18,h-109,w-36,35)
    place(self.action,18,h-70,w-36,44)
    place(self.saveLabel,18,h-23,w-36,17)
    if compact then
        place(self.status,18,h-92,w-36,26)
        place(self.action,18,h-64,w-36,44)
        place(self.saveLabel,18,h-19,w-36,17)
    end
    self.goal.Size=UDim2.fromOffset(math.min(300,size.X-40),32)
end

function Shop:open()
    if self.phase~="Lobby" and self.phase~="Queued" then return end
    self.overlay.Visible=true
    local hud=Players.LocalPlayer.PlayerGui:FindFirstChild("SkyboundHUD")
    if hud and hud:FindFirstChild("PersonalStats") then hud.PersonalStats.Visible=false end
    self:_layout(); self:_preview(); self:_refresh()
    if UserInputService.GamepadEnabled then GuiService.SelectedObject=self.cards[self.selected].button end
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
        if owned then count+=1 elseif not nextItem then nextItem=entry end
        local card=self.cards[entry.id]
        card.border.Enabled=self.selected==entry.id
        card.price.Text=economy.equippedTrail==entry.id and "EQUIPPED" or (owned and "OWNED" or tostring(entry.price).." CREDITS")
        card.price.TextColor3=owned and C.teal or C.gold
    end
    local credits=economy.credits or 0
    self.balance.Text=tostring(credits).." CREDITS  /  "..count.." EFFECTS OWNED"
    self.collection.Text=tostring(count).." / "..#Catalog.ORDER.." OWNED"
    self.filter.Text=self.onlyOwned and "MY COLLECTION" or "ALL EFFECTS"
    self.openButton.Text="FLIGHT EFFECTS  /  "..tostring(credits).." C"
    self.goal.Text=nextItem and ("NEXT: "..nextItem.name.."  /  "..math.min(credits,nextItem.price).." of "..nextItem.price.." credits")
        or "COMPLETE COLLECTION  /  Fly your signature trail."
    local pending=os.clock()<self.pendingUntil
    local equipped=economy.equippedTrail==item.id
    local owned=economy.owned[item.id]==true
    local affordable=credits>=item.price
    local enabled=economy.canShop and not equipped and (owned or affordable) and not pending
    self.action.Active=enabled==true; self.action.Selectable=enabled==true; self.action.AutoButtonColor=enabled==true
    self.action.BackgroundColor3=enabled and C.teal or C.tile
    self.action.TextColor3=enabled and C.ink or C.muted
    self.action.Text=pending and "WORKING…" or (equipped and "EQUIPPED FOR YOUR NEXT FLIGHT"
        or (owned and ("EQUIP "..string.upper(item.name))
        or (affordable and ("BUY "..string.upper(item.name).."  /  "..item.price.." CREDITS")
        or ("EARN "..(item.price-credits).." MORE CREDITS"))))
    local feedback=self.feedback
    if self.phase=="Queued" then self.status.Text="Leave the queue to buy or change your trail."
    elseif feedback and os.clock()<(self.feedbackUntil or 0) then
        self.status.Text=feedback.message
    elseif not economy.canShop then self.status.Text="Your collection is loading or saving is unavailable. Try again when ready."
    elseif owned then self.status.Text=equipped and "Your equipped trail follows your plane into every flight." or "Owned. Equip this trail for your next flight."
    else self.status.Text="Earn 25 credits per practice flight. Duels earn 40, plus result bonuses." end
    self.status.TextColor3=feedback and not feedback.ok and os.clock()<(self.feedbackUntil or 0) and C.gold or C.muted
    local saves={session_only="STUDIO SESSION  /  Purchases reset when Play stops.",loading="Loading your collection…",
        saved="Collection saved.",pending="Saving your collection…",unavailable="Cloud save unavailable. Purchases are disabled."}
    self.saveLabel.Text=saves[self.saveStatus] or "Loading your collection…"
end

function Shop:update(snapshot,settings)
    self.phase=snapshot.phase; self.economy=snapshot.economy; self.saveStatus=snapshot.saveStatus; self.settings=settings
    local inHub=self.phase=="Lobby" or self.phase=="Queued"
    self.openButton.Visible=inHub; self.goal.Visible=inHub
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
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self.gui:Destroy()
end

return Shop
