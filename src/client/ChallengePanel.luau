-- Same-server invitations. A separate modal keeps PLAY the primary entry.
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local Panel={}; Panel.__index=Panel
local INK=Color3.fromRGB(20,34,55)
local CREAM=Color3.fromRGB(255,245,221)
local function make(kind,parent,name)
    local x=Instance.new(kind);x.Name=name;x.Parent=parent;return x
end
local function text(parent,name,size)
    local x=make("TextLabel",parent,name);x.BackgroundTransparency=1;x.TextColor3=CREAM
    x.Font=Enum.Font.GothamBold;x.TextSize=size;x.TextWrapped=true;return x
end
local function button(parent,name,caption,callback)
    local x=make("TextButton",parent,name);x.Text=caption;x.TextColor3=CREAM;x.BackgroundColor3=Color3.fromRGB(43,75,108)
    x.Font=Enum.Font.GothamBold;x.TextSize=16;x.BorderSizePixel=0;x.TextWrapped=true;x.Selectable=true
    make("UICorner",x,"Corner").CornerRadius=UDim.new(0,12)
    x.Activated:Connect(callback);return x
end
local function rect(x,a,b,w,h) x.Position=UDim2.fromOffset(a,b);x.Size=UDim2.fromOffset(w,h) end
function Panel.new(shared)
    local self=setmetatable({data={},open=false,rows={}},Panel)
    self.command=shared.BattleCommand
    self.gui=make("ScreenGui",Players.LocalPlayer:WaitForChild("PlayerGui"),"SkyBattleChallenges")
    self.gui.ResetOnSpawn=false;self.gui.DisplayOrder=40;self.gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    self.root=make("Frame",self.gui,"Root");self.root.Size=UDim2.fromScale(1,1);self.root.BackgroundTransparency=1
    self.toggle=button(self.root,"Challenge","Challenge a pilot",function()
        if not self.allowed then return end
        self.open=true;self.command:FireServer({kind="request"})
    end)
    self.shade=make("TextButton",self.root,"Shade");self.shade.Text="";self.shade.AutoButtonColor=false
    self.shade.Size=UDim2.fromScale(1,1);self.shade.BackgroundColor3=Color3.new();self.shade.BackgroundTransparency=0.22
    self.shade.Visible=false;self.shade.BorderSizePixel=0
    self.box=make("Frame",self.shade,"Card");self.box.BackgroundColor3=INK;self.box.BorderSizePixel=0
    make("UICorner",self.box,"Corner").CornerRadius=UDim.new(0,18)
    self.title=text(self.box,"Title",26);self.title.Font=Enum.Font.FredokaOne
    self.hint=text(self.box,"Hint",14)
    self.list=make("ScrollingFrame",self.box,"Pilots");self.list.BackgroundTransparency=1;self.list.BorderSizePixel=0
    self.list.ScrollBarThickness=5;self.list.AutomaticCanvasSize=Enum.AutomaticSize.None
    self.accept=button(self.box,"Accept","ACCEPT",function() self:respond("challengeAccept") end)
    self.accept.BackgroundColor3=Color3.fromRGB(55,151,98)
    self.close=button(self.box,"Close","Back",function() self:dismiss() end)
    self.inputConnection=UserInputService.InputBegan:Connect(function(input,processed)
        if not self:isOpen() or UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB then self:dismiss() end
    end)
    self.snapshotConnection=shared.BattleSnapshot.OnClientEvent:Connect(function(data)
        if type(data)~="table" then return end
        self.data=data
        if data.active then self.open=false end
        local c=data.challenge
        if c and c.direction=="incoming" and self.lastInvite~=c.inviteId then self.open=true;self.lastInvite=c.inviteId end
    end)
    return self
end
function Panel:dismiss()
    local c=self.data.challenge
    if c then self:respond(c.direction=="incoming" and "challengeDecline" or "challengeCancel") end
    self.open=false
end
function Panel:respond(kind)
    local c=self.data.challenge
    if c then self.command:FireServer({kind=kind,inviteId=c.inviteId}) end
end
function Panel:isOpen() return self.open and self.allowed==true end
function Panel:update(allowed)
    self.allowed=allowed
    local w,h=self.root.AbsoluteSize.X,self.root.AbsoluteSize.Y
    self.toggle.Visible=allowed and not self.open
    rect(self.toggle,12,w<600 and 118 or 66,math.min(180,w-24),44)
    self.shade.Visible=allowed and self.open
    if not self.shade.Visible then return end
    local width=math.max(1,math.min(480,w-24));local height=math.max(1,math.min(420,h-24))
    local compact=height<280
    local actionsY=height-58
    local listY=compact and 86 or 112
    rect(self.box,(w-width)/2,(h-height)/2,width,height)
    rect(self.title,16,compact and 7 or 12,width-32,compact and 28 or 38)
    self.title.TextSize=compact and 21 or 26
    rect(self.hint,16,compact and 38 or 55,width-32,compact and 38 or 48)
    self.hint.TextSize=compact and 12 or 14
    rect(self.list,16,listY,width-32,math.max(0,actionsY-listY-10))
    local c=self.data.challenge
    self.title.Text=c and (c.direction=="incoming" and "YOU'RE CHALLENGED!" or "INVITE SENT") or "CHALLENGE A PILOT"
    self.hint.Text=c and (c.name.." · "..math.max(0,math.ceil(c.expiresAt-workspace:GetServerTimeNow())).." seconds to respond")
        or "Choose someone in this server. They decide whether to accept."
    if not c and self.data.challengeFeedback and self.data.challengeFeedback.text then self.hint.Text=self.data.challengeFeedback.text end
    for _,row in ipairs(self.rows) do row.Visible=false end
    local candidates=c and {} or self.data.challengeCandidates or {}
    for i,pilot in ipairs(candidates) do
        local row=self.rows[i]
        if not row then
            row=button(self.list,"Pilot"..i,"",function()
                local current=(self.data.challengeCandidates or {})[i]
                if current and current.available then self.command:FireServer({kind="challenge",targetUserId=current.userId}) end
            end);self.rows[i]=row
        end
        rect(row,0,(i-1)*54,width-38,46);row.Visible=true
        row.Text=pilot.name..(pilot.available and "  ·  CHALLENGE" or "  ·  busy")
        row.Active=pilot.available==true;row.AutoButtonColor=row.Active;row.TextTransparency=row.Active and 0 or 0.4
    end
    self.list.CanvasSize=UDim2.fromOffset(0,#candidates*54)
    if not c and #candidates==0 then self.hint.Text="No other pilots here yet. Invite a friend to join this server, or use PLAY for a bot rival." end
    self.accept.Visible=c~=nil and c.direction=="incoming"
    rect(self.accept,16,actionsY,(width-40)/2,46)
    rect(self.close,self.accept.Visible and width/2+4 or 16,actionsY,self.accept.Visible and (width-40)/2 or width-32,46)
    self.close.Text=c and (c.direction=="incoming" and "Decline" or "Cancel invite") or "Back to hangar"
end
function Panel:destroy()
    if self.inputConnection then self.inputConnection:Disconnect() end
    if self.snapshotConnection then self.snapshotConnection:Disconnect() end
    self.gui:Destroy()
end
return Panel
