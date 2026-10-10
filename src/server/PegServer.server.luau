-- POP DUEL: the server owns matchmaking, launch settings, physics, and scores.
-- Statistics are deliberately session-only; no persistent stores are accessed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local shared = ReplicatedStorage:WaitForChild("PegGame")
local Simulation = require(shared:WaitForChild("PegSimulation"))
local Powers = require(shared:WaitForChild("PegPowers"))
local World = require(shared:WaitForChild("PegWorld"))
local command, snapshots = shared:WaitForChild("Command"), shared:WaitForChild("Snapshot")
World.buildLobby()

local DURATIONS = {Aim=15, Countdown=2, Shot=25, Results=90}
local FIXED_DT = Simulation.FIXED_DT or 1/120
local profiles, matches, queue = {}, {}, {}
local nextMatchId, broadcastAccumulator = 0, 0
local shuttingDown, debugClock = false, nil
local function now() return debugClock or workspace:GetServerTimeNow() end
local function finite(value)
    return type(value)=="number" and value==value and value>-math.huge and value<math.huge
end
local function clone(value)
    if type(value)~="table" then return value end
    local result={}
    for key,item in pairs(value) do result[key]=clone(item) end
    return result
end
local function entrant(m, userId)
    for _,entry in ipairs(m.players) do
        if entry.userId==userId then return entry end
    end
    return nil
end
local function moveCharacter(p, inMatch)
    local character=p.player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    root.Anchored=inMatch
    root.AssemblyLinearVelocity=Vector3.zero
    root.AssemblyAngularVelocity=Vector3.zero
    character:PivotTo(CFrame.new(inMatch and Vector3.new(0,1000,-3500) or World.LOBBY_SPAWN))
end
local function clearQueue(p)
    for index=#queue,1,-1 do
        if queue[index]==p.player.UserId then table.remove(queue,index) end
    end
    p.queued=false
end
local function release(p, message)
    clearQueue(p)
    p.matchId=nil
    p.message=message or "One shot. Make it count."
    moveCharacter(p,false)
end
local function canRematch(m)
    for _,entry in ipairs(m.players) do
        if not entry.isGhost then
            local p=profiles[entry.userId]
            if not p or p.matchId~=m.id then return false end
        end
    end
    return true
end
local function publicShot(shot)
    if not shot then return nil end
    local result={}
    for _,key in ipairs({"elapsed","done","score","subtotal","hitCount","orangeHits","multiplier",
        "powerId","powerUsed","returnArmed","returnUsed","bucketCaught","catchBonus","eventSerial","finishReason","angle"}) do
        result[key]=shot[key]
    end
    result.balls=clone(shot.balls or {})
    result.recentEvents=clone(shot.recentEvents or {})
    result.hit=clone(shot.hit or {})
    result.removed=clone(shot.removed or {})
    result.hitIds={}; result.removedIds={}
    for id,value in pairs(shot.hit or {}) do if value then table.insert(result.hitIds,id) end end
    for id,value in pairs(shot.removed or {}) do if value then table.insert(result.removedIds,id) end end
    table.sort(result.hitIds); table.sort(result.removedIds)
    return result
end
local function snapshot(p)
    local m=p.matchId and matches[p.matchId]
    local players={}
    if m then
        for _,entry in ipairs(m.players) do
            local attached=entry.isGhost or (profiles[entry.userId] and profiles[entry.userId].matchId==m.id)
            table.insert(players,{userId=entry.userId,name=entry.name,isGhost=entry.isGhost,
                angle=entry.angle,powerId=entry.powerId,ready=entry.ready,shot=publicShot(entry.shot),
                left=not attached,forfeit=entry.forfeit or false,rematchReady=entry.isGhost or m.rematchVotes[entry.userId] or false})
        end
    else
        table.insert(players,{userId=p.player.UserId,name=p.player.DisplayName,isGhost=false,
            angle=p.angle,powerId=p.powerId,ready=false})
    end
    return {phase=m and m.phase or (p.queued and "Queued" or "Lobby"),serverTime=now(),
        phaseEndsAt=m and m.phaseEndsAt or 0,matchId=m and m.id or 0,roundId=m and m.roundId or 0,
        seed=m and m.seed,board=m and m.board,localUserId=p.player.UserId,players=players,
        result=m and clone(m.result),stats=clone(p.stats),message=m and m.message or p.message,
        practice=m and m.practice or false,rematchReady=m and m.rematchVotes[p.player.UserId] or false,
        canRematch=m and canRematch(m) or false,queuedCount=#queue,statsSessionOnly=true}
end
local function broadcast()
    for _,p in pairs(profiles) do snapshots:FireClient(p.player,snapshot(p)) end
    local count=0
    for _ in pairs(matches) do count=count+1 end
    shared:SetAttribute("ActiveDuels",count)
    shared:SetAttribute("QueuedPlayers",#queue)
end
local function setPhase(m, phase, message)
    m.phase=phase
    m.phaseEndsAt=now()+DURATIONS[phase]
    m.message=message
end
local function beginAim(m)
    m.roundId=m.roundId+1
    m.seed=104729+m.id*7919+m.roundId*3571
    m.board=Simulation.makeBoard(m.seed)
    m.rematchVotes={}; m.result=nil; m.elapsed=0; m.accumulator=0; m.finished=false
    for _,entry in ipairs(m.players) do
        entry.shot=nil; entry.forfeit=false; entry.ready=entry.isGhost
        if entry.isGhost then
            -- The ghost has the exact same physics and scoring as a human.
            -- This deterministic bank angle is a baseline, not a fabricated score.
            local ghostAngles={-24,-15,-7,9,17,26}
            entry.angle=ghostAngles[m.seed%#ghostAngles+1]
            entry.powerId=Powers.DEFAULT_ID
        else
            local p=profiles[entry.userId]
            entry.angle=p.angle; entry.powerId=p.powerId
        end
    end
    setPhase(m,"Aim","Drag to aim. Choose a power. Lock your shot.")
end
local function createMatch(ids, practice)
    if type(ids)~="table" or #ids~=(practice and 1 or 2) then return nil end
    if #ids==2 and ids[1]==ids[2] then return nil end
    for _,id in ipairs(ids) do if not profiles[id] or profiles[id].matchId then return nil end end
    nextMatchId=nextMatchId+1
    local m={id=nextMatchId,roundId=0,players={},practice=practice or false,rematchVotes={}}
    matches[m.id]=m
    for _,id in ipairs(ids) do
        local p=profiles[id]
        clearQueue(p); p.matchId=m.id; moveCharacter(p,true)
        table.insert(m.players,{userId=id,name=p.player.DisplayName,isGhost=false})
    end
    if practice then table.insert(m.players,{userId=-100001,name="Practice Ghost",isGhost=true}) end
    beginAim(m)
    return m
end
local function launch(m)
    if m.phase~="Countdown" then return end
    m.elapsed=0; m.accumulator=0
    for _,entry in ipairs(m.players) do
        entry.shot=Simulation.newShot(m.board,{angle=entry.angle,powerId=entry.powerId})
    end
    setPhase(m,"Shot",m.practice and "Practice · same board, honest ghost." or "Same board. Biggest score wins!")
end
local function finish(m, reason)
    if m.finished then return end
    m.finished=true
    local first,second=m.players[1],m.players[2]
    for _,entry in ipairs(m.players) do
        if entry.shot then
            entry.shot.done=true
            for _,ball in ipairs(entry.shot.balls or {}) do ball.alive=false end
        end
    end
    local score1=first.shot and first.shot.score or 0
    local score2=second.shot and second.shot.score or 0
    local draw=not first.forfeit and not second.forfeit and score1==score2
    local winner
    if first.forfeit then winner=second
    elseif second.forfeit then winner=first
    elseif not draw then winner=score1>score2 and first or second end
    m.result={winnerId=winner and winner.userId or 0,draw=draw,reason=reason or "score"}
    for _,entry in ipairs(m.players) do
        local p=profiles[entry.userId]
        if p and not entry.isGhost then
            p.stats.rounds=p.stats.rounds+1
            if m.practice then p.stats.practiceRounds=p.stats.practiceRounds+1 end
            if winner and winner.userId==entry.userId then
                if m.practice then p.stats.practiceWins=p.stats.practiceWins+1
                else p.stats.wins=p.stats.wins+1 end
            end
            -- Abandoned shots cannot establish a best; complete rounds can.
            if reason~="forfeit" and entry.shot then p.stats.bestScore=math.max(p.stats.bestScore,entry.shot.score) end
            p.player:SetAttribute("PegBestScore",p.stats.bestScore)
            p.player:SetAttribute("PegWins",p.stats.wins)
        end
    end
    local message=draw and "Perfect tie. Settle it with a rematch!" or ((winner and winner.name or "Nobody").." wins!")
    if reason=="forfeit" then message=message.." Opponent left the round." end
    setPhase(m,"Results",message)
end
local function leaveMatch(p)
    local m=p.matchId and matches[p.matchId]
    if m and m.phase=="Shot" then
        entrant(m,p.player.UserId).forfeit=true
        finish(m,"forfeit")
    end
    release(p)
    if m and m.phase~="Results" then
        for _,entry in ipairs(m.players) do
            local other=profiles[entry.userId]
            if other and other.matchId==m.id then release(other,"Opponent left. Join a new duel or try practice.") end
        end
        matches[m.id]=nil
    end
end
local function matchQueuedPlayers()
    for index=#queue,1,-1 do
        local p=profiles[queue[index]]
        if not p or not p.queued or p.matchId then table.remove(queue,index) end
    end
    while #queue>=2 do
        local first,second=queue[1],queue[2]
        if not createMatch({first,second},false) then
            table.remove(queue,1)
            if profiles[first] then profiles[first].queued=false end
        end
    end
end

-- Only these fields cross the trust boundary. Numerical tuning and scores never do.
local COMMAND_FIELDS={
    request={},join={},cancel={},practice={},returnLobby={},rematch={},
    aim={angle=true},power={powerId=true},ready={angle=true,powerId=true,ready=true},
}
local function validPayload(payload)
    if type(payload)~="table" or type(payload.kind)~="string" or not COMMAND_FIELDS[payload.kind] then return false end
    for key in pairs(payload) do
        if key~="kind" and key~="matchId" and key~="roundId" and not COMMAND_FIELDS[payload.kind][key] then return false end
    end
    for _,key in ipairs({"matchId","roundId"}) do
        if payload[key]~=nil and (not finite(payload[key]) or payload[key]%1~=0 or payload[key]<0) then return false end
    end
    return true
end
local function consumeCommand(p, kind)
    local stamp=now()
    local elapsed=math.max(0,stamp-p.tokenAt)
    p.tokens=math.min(45,p.tokens+elapsed*30); p.tokenAt=stamp
    if p.tokens<1 then return false end
    p.tokens=p.tokens-1
    local gap=kind=="aim" and 0.025 or (kind=="request" and 0.2 or 0.08)
    if stamp-(p.lastCommand[kind] or -math.huge)<gap then return false end
    p.lastCommand[kind]=stamp
    return true
end
local function handleCommand(p, payload)
    if shuttingDown or not validPayload(payload) or not consumeCommand(p,payload.kind) then return end
    local kind=payload.kind
    local m=p.matchId and matches[p.matchId]
    if kind=="request" then snapshots:FireClient(p.player,snapshot(p)); return end
    if payload.matchId~=nil and payload.matchId~=(m and m.id or 0) then return end
    if payload.roundId~=nil and payload.roundId~=(m and m.roundId or 0) then return end
    if kind=="returnLobby" then leaveMatch(p)
    elseif kind=="cancel" and not m then clearQueue(p); p.message="Queue cancelled."
    elseif kind=="join" and not m and not p.queued then
        p.queued=true; p.message="Finding another player. Practice is ready while you wait."
        table.insert(queue,p.player.UserId); matchQueuedPlayers()
    elseif kind=="practice" and not m then createMatch({p.player.UserId},true)
    elseif kind=="rematch" and m and m.phase=="Results" and canRematch(m) then
        m.rematchVotes[p.player.UserId]=true
        local allReady=true
        for _,entry in ipairs(m.players) do
            if not entry.isGhost and not m.rematchVotes[entry.userId] then allReady=false end
        end
        if allReady then beginAim(m) end
    elseif m and m.phase=="Aim" and (kind=="aim" or kind=="power" or kind=="ready") then
        local entry=entrant(m,p.player.UserId)
        -- An atomic Ready validates both optional choices before changing either.
        if (kind=="aim" or payload.angle~=nil) and not finite(payload.angle) then return end
        if (kind=="power" or payload.powerId~=nil) and (type(payload.powerId)~="string" or not Powers.isValid(payload.powerId)) then return end
        if payload.ready~=nil and type(payload.ready)~="boolean" then return end
        local angle=payload.angle~=nil and math.clamp(payload.angle,-65,65) or entry.angle
        local powerId=payload.powerId or entry.powerId
        entry.angle=angle; entry.powerId=powerId
        p.angle=angle; p.powerId=powerId
        entry.ready=kind=="ready" and payload.ready~=false
    else return end
    broadcast()
end

local function stepMatches(dt)
    if shuttingDown or not finite(dt) or dt<=0 then return end
    matchQueuedPlayers()
    for id,m in pairs(matches) do
        local attached=false
        for _,entry in ipairs(m.players) do
            if not entry.isGhost and profiles[entry.userId] and profiles[entry.userId].matchId==id then attached=true end
        end
        if not attached then
            matches[id]=nil
        elseif m.phase=="Shot" then
            -- Fixed time steps preserve equal boards under variable server frame rate.
            -- Keep accumulated time, while capping work in any single heartbeat.
            m.accumulator=m.accumulator+math.min(dt,1)
            local steps=0
            while m.accumulator>=FIXED_DT and steps<120 and m.phase=="Shot" do
                m.accumulator=m.accumulator-FIXED_DT; steps=steps+1; m.elapsed=m.elapsed+FIXED_DT
                local active=false
                for _,entry in ipairs(m.players) do
                    if not entry.shot.done then Simulation.step(entry.shot,m.board,FIXED_DT) end
                    active=active or not entry.shot.done
                end
                if not active or m.elapsed>=math.min(DURATIONS.Shot,Simulation.MAX_SHOT_TIME or DURATIONS.Shot) then
                    finish(m,"score")
                end
            end
            -- A server hitch cannot leave a match stuck indefinitely.
            if m.phase=="Shot" and now()>=m.phaseEndsAt+2 then finish(m,"time_limit") end
        elseif m.phase=="Aim" then
            local allReady=true
            for _,entry in ipairs(m.players) do if not entry.ready then allReady=false end end
            if allReady or now()>=m.phaseEndsAt then
                for _,entry in ipairs(m.players) do entry.ready=true end
                setPhase(m,"Countdown","Shots locked. Here we go!")
            end
        elseif m.phase=="Countdown" and now()>=m.phaseEndsAt then
            launch(m)
        elseif m.phase=="Results" and now()>=m.phaseEndsAt then
            for _,entry in ipairs(m.players) do
                local p=profiles[entry.userId]
                if p and p.matchId==id then release(p) end
            end
            matches[id]=nil
        end
    end
    broadcastAccumulator=broadcastAccumulator+dt
    if broadcastAccumulator>=0.1 then broadcastAccumulator=0; broadcast() end
end
local function joined(player)
    if shuttingDown or profiles[player.UserId] then return end
    local p={player=player,angle=0,powerId=Powers.DEFAULT_ID,queued=false,
        stats={wins=0,bestScore=0,rounds=0,practiceRounds=0,practiceWins=0},tokens=45,tokenAt=now(),lastCommand={},message="One shot. Make it count."}
    profiles[player.UserId]=p
    player:SetAttribute("PegBestScore",0); player:SetAttribute("PegWins",0)
    local function placeCharacter(character)
        if character:WaitForChild("HumanoidRootPart",10) and profiles[player.UserId]==p then moveCharacter(p,p.matchId~=nil) end
    end
    player.CharacterAdded:Connect(placeCharacter)
    if player.Character then task.spawn(placeCharacter,player.Character) end
    task.defer(broadcast)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
    local p=profiles[player.UserId]
    if p then leaveMatch(p); profiles[player.UserId]=nil end
    stepMatches(FIXED_DT)
    broadcast()
end)
for _,player in ipairs(Players:GetPlayers()) do joined(player) end
command.OnServerEvent:Connect(function(player,payload)
    local p=profiles[player.UserId]
    if p then handleCommand(p,payload) end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt,player)
    local p=profiles[player.UserId]
    local lobby=workspace:FindFirstChild("PegLobby")
    if not p or not lobby or not prompt:IsDescendantOf(lobby) then return end
    local kind=prompt:GetAttribute("PegCommand")
    if kind~="join" and kind~="practice" then return end
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local target=prompt.Parent
    if target and target:IsA("Attachment") then target=target.Parent end
    if not root or not target or not target:IsA("BasePart") then return end
    if (root.Position-target.Position).Magnitude>(prompt.MaxActivationDistance or 10)+3 then return end
    handleCommand(p,{kind=kind})
end)
RunService.Heartbeat:Connect(stepMatches)
game:BindToClose(function() shuttingDown=true end)

-- Test access exists only inside Studio; no client can invoke this BindableFunction.
if RunService:IsStudio() then
    local debugFunction=Instance.new("BindableFunction")
    debugFunction.Name="PegDebug"; debugFunction.Parent=ServerStorage
    debugFunction.OnInvoke=function(action,data)
        data=type(data)=="table" and data or {}
        local first=Players:GetPlayers()[1]
        local p=profiles[data.userId or (first and first.UserId)]
        if action=="snapshots" then
            local result={}
            for id,profile in pairs(profiles) do result[tostring(id)]=snapshot(profile) end
            return result
        end
        if action=="start" then
            local ids=data.ids or (p and {p.player.UserId})
            local m=ids and createMatch(ids,data.practice==true or #ids==1)
            broadcast(); return m and m.id
        end
        if not p then return nil end
        if action=="command" then handleCommand(p,data.payload)
        elseif action=="launch" then
            local m=p.matchId and matches[p.matchId]
            if m and m.phase=="Aim" then setPhase(m,"Countdown","Studio test launch") end
            if m then launch(m) end
        elseif action=="advance" and finite(data.seconds) then
            local seconds=math.clamp(data.seconds,0,120)
            local base=now(); debugClock=base
            local elapsed=0
            while elapsed<seconds do
                local dt=math.min(1/60,seconds-elapsed)
                elapsed=elapsed+dt; debugClock=base+elapsed; stepMatches(dt)
            end
            -- Return deadlines to the real clock after the offline test interval.
            for _,m in pairs(matches) do m.phaseEndsAt=m.phaseEndsAt-seconds end
            debugClock=nil
        end
        broadcast(); return snapshot(p)
    end
end
print("POP_DUEL_SERVER_READY","one shot · identical boards · server scores · session statistics")
