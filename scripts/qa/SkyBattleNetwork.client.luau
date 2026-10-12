-- Opt-in QA only. Install temporarily as a StarterPlayerScripts LocalScript.
-- Not included by build.py. Programmatic inputs use the production remotes.
local RunService=game:GetService("RunService")
if not RunService:IsStudio() then return end
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
-- GetTestArgs is server-side test context. This remote exists only after the
-- server has checked the exact opt-in argument; normal Play quietly returns.
local qa=ReplicatedStorage:WaitForChild("SkyBattleNetworkQA",60)
if not qa or not qa:IsA("RemoteEvent") or qa:GetAttribute("TestId")~="SkyBattleNetworkV1" then return end
qa:FireServer({kind="boot",reason="server QA marker observed",clientUserId=player.UserId})
local shared=ReplicatedStorage:WaitForChild("FlightGame",20)
if not shared then qa:FireServer({kind="startupFailure",reason="FlightGame not replicated within 20 seconds"});return end
for _,name in ipairs({"BattleCommand","BattleSnapshot","Command","Snapshot"})do
    if not shared:WaitForChild(name,20) then
        qa:FireServer({kind="startupFailure",reason=name.." not replicated within 20 seconds"});return
    end
end
local battle, lobby={},{}
local automatic=false
local autoKeys={}
local sequence=0
local function summary()
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local sim=battle.simulation
    local p=battle.economy and battle.economy.progression or {}
    return {clientUserId=player.UserId,active=battle.active==true,phase=battle.phase,matchId=battle.matchId,
        stage=battle.stage,slot=battle.slot,roundId=battle.roundId,roundNumber=battle.roundNumber,
        settings=battle.settings,score=battle.score,offer=battle.offer,offerRevision=battle.offerRevision,selected=battle.selected,locked=battle.locked,
        resources=battle.resources,players=battle.players,rematchVotes=battle.rematchVotes,mode=battle.mode,
        result=battle.result and {winner=battle.result.winner,score=battle.result.score,reason=battle.result.reason},
        reward=battle.reward and {coins=battle.reward.coins,eligible=battle.reward.eligible,status=battle.reward.status,confirmed=battle.reward.confirmed},
        credits=battle.economy and battle.economy.credits,owned=battle.economy and battle.economy.owned,
        equippedTrail=battle.economy and battle.economy.equippedTrail,matches=p.matches,starterAvailable=p.starterAvailable,
        challenge=battle.challenge,challengeFeedback=battle.challengeFeedback,
        lobbyPhase=lobby.phase,anchored=root and root.Anchored,flying=player:GetAttribute("SkyboundFlying"),
        privateOfferLeak=battle.offers~=nil or battle.rivalOffer~=nil or battle.rivalSelected~=nil,
        simulation=sim and {seed=sim.seed,elapsed=sim.elapsed,winner=sim.winner,
            armor={sim.fighters[1].armor,sim.fighters[2].armor}}}
end
local function report(kind,extra)
    sequence=sequence+1
    local packet=extra or {};packet.kind=kind;packet.sequence=sequence;packet.state=summary()
    qa:FireServer(packet)
end
local function autoPick()
    if not automatic or battle.phase~="Pick" or (battle.locked and battle.locked[1]) then return end
    local key=tostring(battle.matchId)..":"..tostring(battle.stage)
    if autoKeys[key] then return end
    local pick=(battle.offer or {})[1]
    if not pick then return end
    for _,preferred in ipairs({"Spikes","Turbo","Claws"}) do
        if table.find(battle.offer,preferred) then pick=preferred;break end
    end
    autoKeys[key]=true
    local matchId,stage,slot,offerRevision=battle.matchId,battle.stage,battle.slot,battle.offerRevision
    task.spawn(function()
        shared.BattleCommand:FireServer({kind="pick",matchId=matchId,stage=stage,slot=slot,skillId=pick,offerRevision=offerRevision})
        task.wait(.12)
        shared.BattleCommand:FireServer({kind="lock",matchId=matchId,stage=stage,slot=slot,skillId=pick,offerRevision=offerRevision})
    end)
end
shared.BattleSnapshot.OnClientEvent:Connect(function(data)
    battle=data
    autoPick()
end)
shared.Snapshot.OnClientEvent:Connect(function(data) lobby=data end)
qa.OnClientEvent:Connect(function(packet)
    if type(packet)~="table" then return end
    if packet.op=="send" then
        local remote=packet.channel=="main" and shared.Command or shared.BattleCommand
        remote:FireServer(packet.payload)
    elseif packet.op=="auto" then automatic=packet.enabled==true;autoPick()
    end
    report("ack",{ack=packet.id})
end)
game:GetService("ScriptContext").Error:Connect(function(message,stack,source)
    local name=source and source:GetFullName() or "unknown"
    if string.find(name,"Flight") or string.find(name,"Battle") or string.find(name,"Challenge") then
        report("error",{message=string.sub(tostring(message),1,900),source=name})
    end
end)
shared.BattleCommand:FireServer({kind="request"})
shared.Command:FireServer({kind="request"})
report("ready",{reason="production remotes connected and initial snapshots requested"})
task.spawn(function()
    while script.Parent do task.wait(.1);report("state") end
end)
