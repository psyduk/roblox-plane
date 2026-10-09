-- Independent two-pilot duels with fenced persistent personal statistics.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local shared = ReplicatedStorage:WaitForChild("FlightGame")
local PlaneCatalog = require(shared.PlaneCatalog)
local Simulation = require(shared.Simulation)
local World = require(shared.World)
local command, snapshots = shared.Command, shared.Snapshot
World.buildLobby()

local DURATIONS = {Voting=8, Configure=25, Aim=20, Countdown=3, Flight=45, Results=90}
local VARIANTS = {"Coast", "Skyline", "Storm"}
local GADGETS = {Shield=true, Magnet=true, Boost=true}
local profiles, matches, queues = {}, {}, {}
local shuttingDown = false
local serverSession = HttpService:GenerateGUID(false)
-- Local Studio deliberately never touches the live player-data store.
local sessionOnly = RunService:IsStudio() or (game.GameId or 0) == 0
local statsStore
if not sessionOnly then
    local ok, store = pcall(function() return game:GetService("DataStoreService"):GetDataStore(PlayerStats.DATASTORE_NAME) end)
    if ok then statsStore=store else warn("SKYBOUND_STATS_UNAVAILABLE", "DataStore initialization failed") end
end
local statsService
statsService=PlayerStats.new({store=statsStore,sessionId=serverSession,sessionOnly=sessionOnly,
    onChanged=function(userId)
        local p=profiles[userId]
        if p and p.statsHandle then
            local _,status=statsService:get(p.statsHandle)
            p.player:SetAttribute("StatsSaveStatus",status)
        end
    end})
-- Starter analytics run in published live servers; set this Script attribute to
-- false to opt out. Studio and unpublished sessions never submit events.
local telemetry=Telemetry.new({enabled=not sessionOnly and script:GetAttribute("AnalyticsEnabled")~=false})
local nextMatchId, broadcastAccumulator, queueAccumulator = 0, 0, 0
for _,station in ipairs(World.DUEL_STATIONS) do queues[station.id]={seats={false,false}} end
local function now() return workspace:GetServerTimeNow() end
local function copySettings(s)
    local plane=PlaneCatalog.get(s.planeId) or PlaneCatalog.get(PlaneCatalog.DEFAULT_ID)
    return {planeId=plane.id,angle=s.angle or plane.defaultAngle,speed=plane.speed,gadget=s.gadget,color=s.color or 1}
end
local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
local function safeSettings(input)
    if type(input)~="table" or not PlaneCatalog.isSelectable(input.planeId) or not finite(input.angle) then return nil end
    local plane=PlaneCatalog.get(input.planeId)
    -- Only the catalog can determine speed. Echoing a snapshot is allowed;
    -- obsolete power or fabricated speed cannot change the selected profile.
    if input.power~=nil or (input.speed~=nil and input.speed~=plane.speed)
        or (input.launchSpeed~=nil and input.launchSpeed~=plane.speed) then return nil end
    if type(input.gadget)~="string" or not GADGETS[input.gadget] or not finite(input.color) then return nil end
    return {planeId=plane.id,angle=math.clamp(math.round(input.angle),PlaneCatalog.MIN_ANGLE,PlaneCatalog.MAX_ANGLE),
        speed=plane.speed,gadget=input.gadget,
        color=math.clamp(math.round(input.color),1,4)}
end
local function safeAimSettings(input, locked)
    if type(input)~="table" or not finite(input.angle) then return nil end
    -- The aiming view can send just an angle or echo the whole settings object.
    -- Reject attempted loadout changes atomically, including a Ready payload.
    if (input.planeId~=nil and input.planeId~=locked.planeId)
        or (input.gadget~=nil and input.gadget~=locked.gadget)
        or (input.color~=nil and input.color~=locked.color)
        or input.power~=nil or (input.speed~=nil and input.speed~=locked.speed)
        or (input.launchSpeed~=nil and input.launchSpeed~=locked.speed) then return nil end
    local result=copySettings(locked)
    result.angle=math.clamp(math.round(input.angle),PlaneCatalog.MIN_ANGLE,PlaneCatalog.MAX_ANGLE)
    return result
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
    if p.queue then
        local q=queues[p.queue.stationId]
        if q and q.seats[p.queue.seat]==p.player.UserId then q.seats[p.queue.seat]=false; q.fullSince=nil end
        p.queue=nil
    end
end
local function release(p, message)
    clearQueue(p)
    p.matchId=nil; p.ready=false; p.queueCooldown=now()+2
    p.message=message or "Walk onto a 1v1 pad with another pilot."
    moveCharacter(p,false)
end
local function voteCounts(m)
    local counts={Coast=0,Skyline=0,Storm=0}
    for _,variant in pairs(m.votes) do counts[variant]+=1 end
    return counts
end
local function publicFlight(s)
    if not s then return nil end
    local used={}
    for id in pairs(s.used) do table.insert(used,id) end
    table.sort(used)
    return {x=s.x,y=s.y,vx=s.vx,vy=s.vy,alive=s.alive,distance=s.distance,
        elapsed=s.elapsed,pickups=s.pickups,hits=s.hits,shield=s.shield,nearMisses=s.nearMisses or 0,
        usedIds=used,lastEvent=s.lastEvent,recentEvents=s.recentEvents,finishReason=s.finishReason}
end
local function queueSnapshot()
    local result={}
    for _,station in ipairs(World.DUEL_STATIONS) do
        local names={false,false}
        for seat,id in ipairs(queues[station.id].seats) do
            if id and profiles[id] then names[seat]=profiles[id].player.DisplayName end
        end
        table.insert(result,{id=station.id,name=station.name,seats=names})
    end
    return result
end
local function canRematch(m)
    for _,e in ipairs(m.entrants) do
        if not e.bot and (not profiles[e.userId] or profiles[e.userId].matchId~=m.id) then return false end
    end
    return true
end
local function snapshot(p)
    local m=p.matchId and matches[p.matchId]
    local list={}
    if m then
        for _,e in ipairs(m.entrants) do
            local profile=profiles[e.userId]
            local attached=profile and profile.matchId==m.id
            table.insert(list,{userId=e.userId,name=e.name,bot=e.bot or false,
                settings=copySettings(attached and profile.settings or e.settings),
                ready=e.bot or (attached and profile.ready) or false,
                rematchReady=m.rematchVotes[e.userId] or e.bot or false,
                left=not e.bot and not attached,flight=publicFlight(e.flight),best=profile and profile.best or 0})
        end
    else
        table.insert(list,{userId=p.player.UserId,name=p.player.DisplayName,settings=copySettings(p.settings),ready=false,best=p.best})
    end
    local personalStats,saveStatus=statsService:get(p.statsHandle)
    return {phase=m and m.phase or (p.queue and "Queued" or "Lobby"),
        matchId=m and m.id or 0,roundId=m and m.round or 0,
        endsAt=m and m.endsAt or 0,courseName=m and m.courseName or "Coast",
        courseSeed=m and m.course.seed or 104729,votes=m and voteCounts(m) or {},players=list,
        results=m and m.results or {},message=m and m.message or p.message,
        elapsed=m and m.elapsed or 0,serverTime=now(),prototype=true,stats=personalStats,saveStatus=saveStatus,
        queue=p.queue,queues=queueSnapshot(),canRematch=m and canRematch(m) or false}
end
local function broadcast()
    for _,p in pairs(profiles) do snapshots:FireClient(p.player,snapshot(p)) end
    local count=0
    for _ in pairs(matches) do count+=1 end
    shared:SetAttribute("ActiveDuels",count)
end
local function setPhase(m, phase, message)
    m.phase=phase; m.endsAt=now()+DURATIONS[phase]
    if message then m.message=message end
end
local function beginVoting(m)
    m.round+=1; m.votes={}; m.results={}; m.rematchVotes={}; m.elapsed=0; m.accumulator=0; m.finished=false; m.aborted=false
    for _,e in ipairs(m.entrants) do
        e.flight=nil; e.forfeit=false
        local p=profiles[e.userId]
        if p then p.ready=false end
    end
    setPhase(m,"Voting","Pick the landscape for your duel. Both pilots face the same course.")
end
local function configure(m)
    local counts=voteCounts(m)
    local highest,tied=-1,{}
    for _,name in ipairs(VARIANTS) do
        if counts[name]>highest then highest=counts[name]; tied={name}
        elseif counts[name]==highest then table.insert(tied,name) end
    end
    m.courseName=tied[(m.round-1)%#tied+1]
    m.course=Simulation.makeCourse(104729+m.id*7919+m.round*3571,m.courseName)
    for _,e in ipairs(m.entrants) do
        if e.bot then
            local plane=PlaneCatalog.get(PlaneCatalog.ORDER[m.course.seed % #PlaneCatalog.ORDER + 1])
            e.settings=copySettings({planeId=plane.id,angle=plane.defaultAngle,gadget="Magnet",color=2})
        end
    end
    m.readyAt=now()+1
    setPhase(m,"Configure","Choose your plane, gadget and color. Aim your jet next.")
end
local function beginAim(m)
    for _,e in ipairs(m.entrants) do
        local p=profiles[e.userId]
        if p then
            e.settings=copySettings(p.settings)
            p.ready=false
        end
    end
    m.readyAt=now()+1
    setPhase(m,"Aim","Point ahead of your jet to aim. Ready locks your launch angle.")
end
local function checkedMatchSettings(p, m, input)
    if m and m.phase=="Aim" then
        for _,e in ipairs(m.entrants) do
            if e.userId==p.player.UserId then return safeAimSettings(input,e.settings) end
        end
        return nil
    end
    return safeSettings(input)
end
local function launch(m)
    m.elapsed=0; m.accumulator=0; m.finished=false; m.aborted=false
    for _,e in ipairs(m.entrants) do
        local p=profiles[e.userId]
        if p then e.settings=copySettings(p.settings); telemetry:matchStart(p.player,m.practice) end
        e.flight=Simulation.newFlight(e.settings,m.course)
    end
    setPhase(m,"Flight",m.practice and "Practice · one ghost opponent · distance to touchdown" or "Hands off. Fuel lifts you; missiles bring you down.")
end
local function finish(m)
    if m.finished then return end
    m.finished=true
    m.results={}
    local forfeited=false
    for _,e in ipairs(m.entrants) do
        local f=e.flight
        if f then
            f.alive=false; f.finishReason=f.finishReason or (m.aborted and "aborted" or "time_limit")
            local distance=math.floor(f.distance*10+0.5)/10
            local completed=not e.forfeit and (f.finishReason=="landed" or f.finishReason=="timeout" or f.finishReason=="time_limit")
            table.insert(m.results,{userId=e.userId,name=e.name,distance=distance,bot=e.bot or false,
                forfeit=e.forfeit or false,completed=completed})
            forfeited=forfeited or e.forfeit
        end
    end
    table.sort(m.results,function(a,b)
        if a.forfeit~=b.forfeit then return not a.forfeit end
        if a.distance==b.distance then return a.userId>b.userId end
        return a.distance>b.distance
    end)
    local rank=1
    for i,r in ipairs(m.results) do
        if i>1 and (r.distance~=m.results[i-1].distance or r.forfeit~=m.results[i-1].forfeit) then rank=i end
        r.rank=rank
    end
    local sharedWin=m.results[2] and m.results[2].rank==1
    local resultId=serverSession..":duel:"..tostring(m.id)..":"..tostring(m.round)
    for _,r in ipairs(m.results) do
        local p=profiles[r.userId]
        if p and not r.bot then
            local outcome=r.forfeit and "loss" or (sharedWin and "draw" or (r.rank==1 and "win" or "loss"))
            statsService:recordFlight(p.statsHandle,resultId,{distance=r.distance,practice=m.practice,
                outcome=outcome,forfeit=r.forfeit,completed=r.completed})
            if r.completed and not r.forfeit then
                p.best=math.max(p.best,r.distance); p.player:SetAttribute("SessionBest",p.best)
            end
            telemetry:matchComplete(p.player,r.forfeit and "forfeit" or (outcome=="draw" and "tie" or outcome),m.practice)
            task.spawn(function() statsService:save(p.statsHandle,false) end)
        end
    end
    local winner=m.results[1]
    local message="Duel complete. Rematch or return to the hub."
    if winner then
        message=forfeited and (winner.name.." wins · opponent left the duel")
            or (m.results[2] and m.results[2].rank==1 and string.format("Shared win · %.1f m",winner.distance))
            or string.format("%s flew furthest · %.1f m",winner.name,winner.distance)
    end
    setPhase(m,"Results",message)
    print("SKYBOUND_DUEL_COMPLETE",m.id,m.round,message)
end
local function createMatch(ids, practice)
    for _,id in ipairs(ids) do if not profiles[id] or profiles[id].matchId then return nil end end
    if #ids~=(practice and 1 or 2) or (#ids==2 and ids[1]==ids[2]) then return nil end
    nextMatchId+=1
    local m={id=nextMatchId,round=0,entrants={},votes={},rematchVotes={},results={},elapsed=0,accumulator=0,
        practice=practice or false,courseName="Coast",course=Simulation.makeCourse(104729,"Coast")}
    matches[m.id]=m
    for _,id in ipairs(ids) do
        local p=profiles[id]
        clearQueue(p); p.matchId=m.id; moveCharacter(p,true)
        table.insert(m.entrants,{userId=id,name=p.player.DisplayName,settings=copySettings(p.settings)})
    end
    if practice then
        table.insert(m.entrants,{userId=-100001,name="Practice · Skipper",bot=true,
            settings=copySettings({planeId=PlaneCatalog.DEFAULT_ID,gadget="Magnet",color=2})})
    end
    beginVoting(m)
    return m
end
local function leaveMatch(p)
    local m=p.matchId and matches[p.matchId]
    local abandonedPhase=m and m.phase or (p.queue and "Queued" or "Lobby")
    release(p)
    if not m then
        if abandonedPhase=="Queued" then telemetry:phaseAbandoned(p.player,abandonedPhase) end
        return
    end
    if m.phase=="Flight" then
        m.aborted=true
        for _,e in ipairs(m.entrants) do
            if e.userId==p.player.UserId then e.forfeit=true; e.flight.finishReason="forfeit" end
        end
        finish(m)
    elseif m.phase~="Results" then
        for _,e in ipairs(m.entrants) do
            local other=profiles[e.userId]
            if other and other.matchId==m.id then
                telemetry:phaseAbandoned(other.player,abandonedPhase)
                release(other,"Your opponent left. Join another 1v1 pad.")
            end
        end
    end
    if abandonedPhase~="Results" then telemetry:phaseAbandoned(p.player,abandonedPhase) end
end
local function onPad(p, position)
    if p.matchId or now()<(p.queueCooldown or 0) then return false end
    local character=p.player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health<=0 then return false end
    local d=root.Position-position
    return math.abs(d.X)<=6 and math.abs(d.Z)<=6 and d.Y>=0 and d.Y<=8
end
local function scanQueues()
    for _,station in ipairs(World.DUEL_STATIONS) do
        local q=queues[station.id]
        for seat,id in ipairs(q.seats) do
            if id and (not profiles[id] or not onPad(profiles[id],station.seats[seat])) then
                if profiles[id] then profiles[id].queue=nil; telemetry:phaseAbandoned(profiles[id].player,"Queued") end
                q.seats[seat]=false; q.fullSince=nil
            end
        end
        for seat,position in ipairs(station.seats) do
            if not q.seats[seat] then
                for id,p in pairs(profiles) do
                    if not p.queue and onPad(p,position) then
                        q.seats[seat]=id; p.queue={stationId=station.id,stationName=station.name,seat=seat}
                        telemetry:queueStart(p.player); break
                    end
                end
            end
        end
        if q.seats[1] and q.seats[2] then
            q.fullSince=q.fullSince or now()
            if now()-q.fullSince>=1.5 then createMatch({q.seats[1],q.seats[2]},false) end
        else q.fullSince=nil end
    end
    local counts={}
    for id,q in pairs(queues) do counts[id]=(q.seats[1] and 1 or 0)+(q.seats[2] and 1 or 0) end
    World.updateLobbyQueues(counts)
end
local function joined(player)
    if shuttingDown then return end
    local p={player=player,settings=copySettings({planeId=PlaneCatalog.DEFAULT_ID,gadget="Shield",color=1}),ready=false,best=0,
        lastCommand={},message="Walk onto a 1v1 pad with another pilot."}
    profiles[player.UserId]=p
    p.statsHandle=statsService:open(player.UserId)
    player:SetAttribute("SessionBest",0)
    player:SetAttribute("StatsSaveStatus",p.statsHandle.status)
    player:SetAttribute("PrototypeSaveStatus",sessionOnly and "Session only · local Studio" or "Persistent player statistics")
    telemetry:sessionStart(player)
    task.spawn(function() statsService:load(p.statsHandle) end)
    local function placeCharacter(character)
        if character:WaitForChild("HumanoidRootPart",10) then moveCharacter(p,p.matchId~=nil) end
    end
    player.CharacterAdded:Connect(placeCharacter)
    if player.Character then task.spawn(placeCharacter,player.Character) end
    task.defer(broadcast)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
    local p=profiles[player.UserId]
    if p then
        if not shuttingDown then leaveMatch(p) end
        telemetry:sessionEnd(player)
        profiles[player.UserId]=nil
        task.spawn(function() statsService:close(p.statsHandle) end)
    end
    broadcast()
end)
for _,player in ipairs(Players:GetPlayers()) do joined(player) end

local ALLOWED={request=true,vote=true,configure=true,ready=true,practice=true,leaveQueue=true,returnLobby=true,rematch=true}
local function handleCommand(p,payload)
    if shuttingDown then return end
    if type(payload)~="table" or type(payload.kind)~="string" or not ALLOWED[payload.kind] then return end
    if now()-(p.lastCommand[payload.kind] or 0)<0.04 then return end
    p.lastCommand[payload.kind]=now()
    local m=p.matchId and matches[p.matchId]
    if payload.kind=="request" then snapshots:FireClient(p.player,snapshot(p)); return end
    if payload.kind=="practice" and not m then createMatch({p.player.UserId},true)
    elseif payload.kind=="leaveQueue" and not m then leaveMatch(p)
    elseif payload.kind=="returnLobby" then leaveMatch(p)
    elseif m and payload.kind=="rematch" and m.phase=="Results" and canRematch(m) then
        m.rematchVotes[p.player.UserId]=true
        telemetry:rematch(p.player)
        local ready=true
        for _,e in ipairs(m.entrants) do if not e.bot and not m.rematchVotes[e.userId] then ready=false end end
        if ready then beginVoting(m) end
    elseif m and payload.kind=="vote" and m.phase=="Voting" and table.find(VARIANTS,payload.variant) then
        m.votes[p.player.UserId]=payload.variant
    elseif payload.kind=="configure" and (not m or m.phase=="Configure" or m.phase=="Voting" or m.phase=="Aim") then
        local checked=checkedMatchSettings(p,m,payload.settings)
        if not checked then return end
        p.settings=checked; p.ready=false
    elseif m and payload.kind=="ready" and (m.phase=="Configure" or m.phase=="Aim") and type(payload.ready)=="boolean" then
        if payload.settings then
            local checked=checkedMatchSettings(p,m,payload.settings)
            if not checked then return end
            p.settings=checked
        end
        p.ready=payload.ready
    else return end
    broadcast()
end
command.OnServerEvent:Connect(function(player,payload)
    local p=profiles[player.UserId]
    if p then handleCommand(p,payload) end
end)
RunService.Heartbeat:Connect(function(dt)
    if shuttingDown then return end
    statsService:step()
    queueAccumulator+=dt
    if queueAccumulator>=0.15 then queueAccumulator=0; scanQueues() end
    for id,m in pairs(matches) do
        local attached=false
        for _,e in ipairs(m.entrants) do if profiles[e.userId] and profiles[e.userId].matchId==id then attached=true end end
        if not attached then matches[id]=nil; continue end
        if m.phase=="Flight" then
            m.accumulator+=dt
            local steps=0
            while m.accumulator>=1/60 and steps<120 do
                m.accumulator-=1/60; steps+=1; m.elapsed+=1/60
                local alive=false
                for _,e in ipairs(m.entrants) do
                    if e.flight.alive then Simulation.step(e.flight,m.course,1/60) end
                    alive=alive or e.flight.alive
                end
                if not alive or m.elapsed>=Simulation.MAX_FLIGHT_TIME then finish(m); break end
            end
        elseif (m.phase=="Configure" or m.phase=="Aim") and now()>=m.readyAt then
            local allReady=true
            for _,e in ipairs(m.entrants) do if not e.bot and not profiles[e.userId].ready then allReady=false end end
            if allReady then
                if m.phase=="Configure" then beginAim(m)
                else setPhase(m,"Countdown","Both flight plans locked. Get ready!") end
            end
        end
        if now()>=m.endsAt then
            if m.phase=="Voting" then configure(m)
            elseif m.phase=="Configure" then beginAim(m)
            elseif m.phase=="Aim" then setPhase(m,"Countdown","Flight plans locked. Get ready!")
            elseif m.phase=="Countdown" then launch(m)
            elseif m.phase=="Flight" then finish(m)
            elseif m.phase=="Results" then
                for _,e in ipairs(m.entrants) do
                    local p=profiles[e.userId]
                    if p and p.matchId==m.id then release(p) end
                end
                matches[id]=nil
            end
        end
    end
    broadcastAccumulator+=dt
    if broadcastAccumulator>=0.1 then broadcastAccumulator=0; broadcast() end
end)

game:BindToClose(function()
    shuttingDown=true
    for _,p in pairs(profiles) do
        local m=p.matchId and matches[p.matchId]
        local phase=m and m.phase or (p.queue and "Queued" or "Lobby")
        if phase~="Lobby" and phase~="Results" then telemetry:phaseAbandoned(p.player,phase) end
        telemetry:sessionEnd(p.player)
    end
    statsService:shutdown(25)
end)

-- Studio diagnostics exercise the same command and match code used by players.
if RunService:IsStudio() then
    local debugFunction=Instance.new("BindableFunction")
    debugFunction.Name="FlightDebug"; debugFunction.Parent=ServerStorage
    debugFunction.OnInvoke=function(action,data)
        data=data or {}
        local p=profiles[data.userId or (Players:GetPlayers()[1] and Players:GetPlayers()[1].UserId)]
        if action=="snapshot" then return p and snapshot(p) end
        if action=="snapshots" then local all={}; for id,profile in pairs(profiles) do all[tostring(id)]=snapshot(profile) end; return all end
        if action=="validateSettings" then return safeSettings(data) end
        if action=="tests" then return require(ServerStorage.SimulationTests)(Simulation) end
        if action=="forcePair" then local m=createMatch(data.ids,false); broadcast(); return m and m.id end
        if not p then return nil end
        if action=="command" then handleCommand(p,data.payload); return snapshot(p) end
        if action=="queueMove" then
            local station
            for _,s in ipairs(World.DUEL_STATIONS) do if s.id==data.stationId then station=s end end
            if station and (data.seat==1 or data.seat==2) and not p.matchId and p.player.Character then
                p.queueCooldown=0; p.player.Character:PivotTo(CFrame.new(station.seats[data.seat]+Vector3.new(0,3,0)))
            end
            return snapshot(p)
        end
        if action=="practice" and not p.matchId then createMatch({p.player.UserId},true) end
        local m=p.matchId and matches[p.matchId]
        if action=="launch" and m then if m.phase=="Voting" then configure(m) end; launch(m) end
        if action=="configure" and m then
            m.results={}; m.elapsed=0
            for _,e in ipairs(m.entrants) do e.flight=nil; if profiles[e.userId] then profiles[e.userId].ready=false end end
            configure(m)
        end
        if action=="aim" and m and m.phase=="Configure" then beginAim(m) end
        broadcast(); return snapshot(p)
    end
end
print("SKYBOUND_SERVER_READY","walkable hub · independent 1v1 duels")
