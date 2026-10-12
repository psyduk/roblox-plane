-- Opt-in QA only. Install temporarily in ServerScriptService, then from Edit:
-- StudioTestService:ExecuteMultiplayerTestAsync(2,"SkyBattleNetworkV1")
-- Not included in build.py. Does not change match seeds, timers or awards.
local RunService=game:GetService("RunService")
local StudioTestService=game:GetService("StudioTestService")
local ok,args=pcall(function()return StudioTestService:GetTestArgs()end)
if not RunService:IsStudio() or not ok or args~="SkyBattleNetworkV1" then return end
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local HttpService=game:GetService("HttpService")
local qa=Instance.new("RemoteEvent");qa.Name="SkyBattleNetworkQA";qa:SetAttribute("TestId","SkyBattleNetworkV1");qa.Parent=ReplicatedStorage
local started=os.clock()
local report={test="SkyBattleNetworkV1",version=1,checks={},errors={},input="programmatic production remotes from two real Studio clients",
    limits="No UI-click, unfamiliar-human, physical-phone, published network or cloud-persistence claim."}
local states,ready,acks={},{},{}
local startup={}
local commandId=0
local ended=false
local function finish(success,problem)
    if ended then return end;ended=true
    report.ok=success;report.error=problem;report.elapsed=math.floor((os.clock()-started)*100)/100
    report.startup=startup;report.players={};report.joinedCount=#Players:GetPlayers();report.readyCount=0
    for _,player in ipairs(Players:GetPlayers())do
        table.insert(report.players,{userId=player.UserId,name=player.Name,ready=ready[player.UserId]==true})
        if ready[player.UserId] then report.readyCount=report.readyCount+1 end
    end
    local encoded=HttpService:JSONEncode(report)
    print("SKY_BATTLE_NETWORK_QA",encoded)
    StudioTestService:EndTest(encoded)
end
qa.OnServerEvent:Connect(function(player,packet)
    if type(packet)~="table" then return end
    if type(packet.state)=="table" then states[player.UserId]=packet.state end
    if packet.kind=="ready" then ready[player.UserId]=true end
    if packet.kind=="boot" or packet.kind=="ready" or packet.kind=="startupFailure" then
        table.insert(startup,{userId=player.UserId,kind=packet.kind,reason=packet.reason,elapsed=math.floor((os.clock()-started)*100)/100})
    end
    if packet.kind=="ack" then acks[packet.ack]=player.UserId end
    if packet.kind=="error" and #report.errors<10 then table.insert(report.errors,{side=player.UserId,message=packet.message,source=packet.source}) end
end)
Players.PlayerAdded:Connect(function(player)
    table.insert(startup,{userId=player.UserId,kind="joined",elapsed=math.floor((os.clock()-started)*100)/100})
end)
for _,player in ipairs(Players:GetPlayers())do table.insert(startup,{userId=player.UserId,kind="alreadyJoined",elapsed=0})end
game:GetService("ScriptContext").Error:Connect(function(message,stack,source)
    local name=source and source:GetFullName() or "unknown"
    if string.find(name,"FlightServer") or string.find(name,"BattleLab") or string.find(name,"PlayerStats") then
        if #report.errors<10 then table.insert(report.errors,{side="server",message=string.sub(tostring(message),1,900),source=name}) end
    end
end)
local function check(name,details)
    table.insert(report.checks,{name=name,passed=true,details=details})
end
local function waitFor(label,condition,seconds)
    local deadline=os.clock()+(seconds or 10)
    while not ended and os.clock()<deadline do
        local yes=condition()
        if yes then return yes end
        task.wait(.05)
    end
    error("Timed out: "..label)
end
local function send(player,op,payload,channel)
    commandId=commandId+1;local id=commandId
    qa:FireClient(player,{id=id,op=op,payload=payload,channel=channel,enabled=payload==true})
    waitFor("client acknowledged "..op,function()return acks[id]==player.UserId end,5)
end
local function battleCommand(player,kind,extra)
    local s=assert(states[player.UserId]);local payload=extra or {}
    payload.kind=kind;payload.matchId=payload.matchId or s.matchId;payload.stage=payload.stage or s.stage
    payload.offerRevision=payload.offerRevision or s.offerRevision
    if kind=="lock" then payload.slot=payload.slot or s.slot;payload.skillId=payload.skillId or s.selected or s.offer[1] end
    send(player,"send",payload,"battle")
end
local function state(player)return states[player.UserId] or {} end
local function empty(build)return build and build.offenceId==nil and #(build.wildIds or {})==0 end
local function sameScore(a,b)return a and b and a[1]==b[2] and a[2]==b[1] end
local function lobby(a,b)
    return not state(a).active and not state(b).active and state(a).lobbyPhase=="Lobby" and state(b).lobbyPhase=="Lobby"
        and state(a).anchored==false and state(b).anchored==false and state(a).flying==false and state(b).flying==false
end
task.delay(240,function()finish(false,"240-second watchdog; last states: "..HttpService:JSONEncode(states))end)
task.spawn(function()
    local success,problem=xpcall(function()
        local server=game:GetService("ServerScriptService"):WaitForChild("FlightServer",15)
        assert(server:GetAttribute("BattleFixedSeed")==nil and server:GetAttribute("BattleExperimental")~=true,"Diagnostic roster/seed flag must be off")
        waitFor("two client scripts ready",function()
            local found=0;for _,p in ipairs(Players:GetPlayers())do if ready[p.UserId] then found=found+1 end end
            return found==2
        end,65)
        local participants=Players:GetPlayers();table.sort(participants,function(a,b)return a.UserId<b.UserId end)
        local a,b=participants[1],participants[2];assert(a and b)
        report.participants={a.UserId,b.UserId}
        waitFor("both usable lobbies",function()return lobby(a,b)end,10)
        send(a,"send",{kind="play"},"main");send(b,"send",{kind="play"},"main")
        waitFor("same human draft",function()return state(a).phase=="Pick" and state(b).phase=="Pick" and state(a).matchId==state(b).matchId end)
        local first=state(a).matchId
        assert(state(a).players[1].userId==a.UserId and state(b).players[1].userId==b.UserId,"Local identity mapping")
        assert(state(a).players[2].userId==b.UserId and state(b).players[2].userId==a.UserId,"Rival identity mapping")
        assert(not state(a).players[2].bot and not state(b).players[2].bot,"Unexpected bot fallback")
        assert(not state(a).privateOfferLeak and not state(b).privateOfferLeak,"Private offers crossed network")
        check("two real clients paired",{matchId=first})
        battleCommand(a,"pickAny")
        waitFor("A free Pick Any",function()return state(a).resources.pickAny==0 end)
        battleCommand(a,"pick",{slot="offence",skillId="Bolt"})
        waitFor("A selected own card",function()return state(a).selected=="Bolt" end)
        battleCommand(a,"lock")
        waitFor("B sees only rival lock",function()return state(b).locked[2]==true end)
        assert(empty(state(b).settings[2]) and state(b).selected==nil and empty(state(a).settings[1]),"Unrevealed choice leaked")
        check("private selection hidden until mutual reveal",{firstLocker=a.UserId})
        battleCommand(b,"pickAny")
        waitFor("B free Pick Any",function()return state(b).resources.pickAny==0 end)
        battleCommand(b,"pick",{slot="offence",skillId="Bolt"})
        waitFor("B selected own card",function()return state(b).selected=="Bolt" end)
        battleCommand(b,"lock")
        waitFor("simultaneous revealed countdown",function()return state(a).phase=="Countdown" and state(b).phase=="Countdown" end)
        assert(state(a).settings[1].offenceId=="Bolt" and state(b).settings[2].offenceId=="Bolt")
        assert(state(a).simulation.seed==state(b).simulation.seed,"Shared seed disagreement")
        local seeds={state(a).simulation.seed}
        check("simultaneous reveal and shared simulation seed",{seed=seeds[1]})
        send(a,"auto",true);send(b,"auto",true)
        waitFor("full automatic match terminal",function()return state(a).phase=="MatchOver" and state(b).phase=="MatchOver" end,125)
        local sa,sb=state(a),state(b)
        assert(sa.matchId==first and sb.matchId==first and sameScore(sa.score,sb.score),"Terminal score disagreement")
        assert(sa.result.winner==0 and sb.result.winner==0 or sa.result.winner+sb.result.winner==3,"Terminal winner disagreement")
        assert(sa.result.reason==sb.result.reason and sa.roundNumber==sb.roundNumber,"Terminal rule disagreement")
        assert(sa.reward.eligible and sb.reward.eligible,"Normal completion did not qualify")
        assert(sa.reward.coins==(sa.result.winner==1 and 75 or 50) and sb.reward.coins==(sb.result.winner==1 and 75 or 50),"Award amount disagreement")
        assert(sa.matches==1 and sb.matches==1 and sa.starterAvailable and sb.starterAvailable,"First-match progression disagreement")
        local balanceA,balanceB=sa.credits,sb.credits
        report.normalMatch={matchId=first,rounds=sa.roundNumber,scoreA=sa.score,winnerA=sa.result.winner,
            reason=sa.result.reason,coins={sa.reward.coins,sb.reward.coins},saveStatus=sa.reward.status}
        check("normal terminal outcome and both rewards agree",report.normalMatch)
        send(a,"send",{kind="claimStarter",itemId="rookieblue"},"main")
        waitFor("first gift authoritative claim",function()return state(a).owned and state(a).owned.rookieblue and state(a).equippedTrail=="rookieblue" end)
        assert(state(a).credits==balanceA and not state(a).starterAvailable,"Gift changed coin balance or remained claimable")
        check("first gift claimed through client production remote",{itemId="rookieblue",input="programmatic"})
        send(a,"auto",false);send(b,"auto",false)
        battleCommand(a,"rematch")
        waitFor("first rematch vote",function()return state(a).rematchVotes[1]==true end)
        assert(state(a).phase=="MatchOver" and state(b).phase=="MatchOver","One vote restarted match")
        battleCommand(b,"rematch")
        waitFor("mutual rematch draft",function()return state(a).phase=="Pick" and state(b).phase=="Pick" and state(a).matchId~=first end)
        sa,sb=state(a),state(b)
        assert(sa.matchId==sb.matchId and sa.players[2].userId==b.UserId and sb.players[2].userId==a.UserId)
        assert(empty(sa.settings[1]) and empty(sa.settings[2]) and sa.resources.pickAny==1 and sb.resources.pickAny==1 and sa.resources.reroll==1)
        assert(sa.score[1]==0 and sa.score[2]==0 and sa.credits==balanceA and sb.credits==balanceB)
        check("mutual rematch resets shared draft without duplicating rewards",{matchId=sa.matchId})
        battleCommand(a,"exit")
        waitFor("draft departure result",function()return not state(a).active and state(b).phase=="MatchOver" end)
        assert(state(b).reward.coins==0 and state(b).credits==balanceB,"Instant forfeit generated reward")
        battleCommand(b,"exit")
        waitFor("both controls restored",function()return lobby(a,b)end)
        check("draft departure cleanup and preserved earned grants")
        battleCommand(a,"challenge",{targetUserId=b.UserId})
        waitFor("incoming challenge",function()return state(b).challenge and state(b).challenge.direction=="incoming" end)
        local invitation=state(b).challenge.inviteId
        battleCommand(b,"challengeDecline",{inviteId=invitation})
        waitFor("challenge decline release",function()return not state(a).challenge and not state(b).challenge and lobby(a,b)end)
        check("challenge declined without reserving controls")
        task.wait(3.1)
        battleCommand(a,"challenge",{targetUserId=b.UserId})
        waitFor("second incoming challenge",function()return state(b).challenge and state(b).challenge.direction=="incoming" end)
        invitation=state(b).challenge.inviteId
        battleCommand(b,"challengeAccept",{inviteId=invitation})
        waitFor("accepted challenge draft",function()return state(a).phase=="Pick" and state(b).phase=="Pick" and state(a).mode=="challenge" and state(a).matchId==state(b).matchId end)
        check("same-server challenge explicitly accepted",{matchId=state(a).matchId})
        battleCommand(a,"exit")
        waitFor("challenge departure cleanup",function()return state(b).phase=="MatchOver" end)
        battleCommand(b,"exit")
        waitFor("final controls restored",function()return lobby(a,b)end)
        assert(state(a).credits==balanceA and state(b).credits==balanceB,"Incomplete follow-up changed awards")
        assert(#report.errors==0,"Game script errors were reported")
        check("final lobby usable and awards unchanged")
    end,debug.traceback)
    finish(success,not success and string.sub(tostring(problem),1,3500) or nil)
end)
