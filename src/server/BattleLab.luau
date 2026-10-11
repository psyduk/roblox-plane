-- Authoritative, same-server Sky Battle rivalry. The public combat pool never
-- reads account ownership. Only recipient-owned draft data crosses the remote.
local BattleLab = {}
BattleLab.__index = BattleLab
BattleLab.ROSTER_VERSION = "sky-battle-public-v1"
BattleLab.QUEUE_SECONDS = 8
-- Before every round each pilot sets up a loadout: one attack, plus one
-- wild card slot for each decisive round played. Everything already on the
-- plane stays there unless the pilot swaps it, and every pick shows the
-- whole roster.
BattleLab.PICK_SECONDS = 20
BattleLab.MAX_WILDS = 2
-- Long enough to read who hit whom before the next pick takes the screen.
BattleLab.ROUND_OVER_SECONDS = 3.5
BattleLab.MATCH_SECONDS = 240
BattleLab.MAX_ROUNDS = 5
-- A pilot's first match is guided: it starts at once against a bot, the first
-- round has no pick, and each later pick offers a small hand with a longer
-- clock. Everything after that match is the normal draft.
BattleLab.GUIDE_INTRO_SECONDS = 5
BattleLab.GUIDE_PICK_SECONDS = 40
local GUIDE = {offences={"Meteor","Firework"},wilds={"SpringBumper","Afterburner","FizzyFuel","Magnet"},hand={[2]=2,[3]=3}}
local PUBLIC = {offences={"Meteor","Firework","MachineGun","Pinball"},
    wilds={"Afterburner","SpringBumper","FizzyFuel","Magnet","SecondWind","Squadron","Giant","Eject","Vampire","Chicken"}}
-- A pick shows this many wild cards: the ones already on the plane, then a
-- fresh random deal from the rest of the roster.
local HAND = 5
local function finite(value)
    return type(value)=="number" and value==value and value>-math.huge and value<math.huge
end
local function copy(value)
    if type(value)~="table" then return value end
    local result={}; for key,item in pairs(value) do result[key]=copy(item) end; return result
end
local function contains(list,value)
    for _,item in ipairs(list or {}) do if item==value then return true end end
    return false
end
local function seat(index,side)
    return side==2 and (index==1 and 2 or index==2 and 1 or index) or index
end
local function pair(values,side)
    return {copy(values[side]),copy(values[3-side])}
end
-- Everything seen by client 2 uses its own seat as 1, including event emphasis,
-- projectile ownership and the left-hand opening. Never mutate the shared sim.
local function perspective(value,side)
    local result=copy(value)
    if side~=2 or not result then return result end
    local function visit(item)
        if type(item)~="table" then return end
        for key,v in pairs(item) do
            if type(v)=="table" then visit(v)
            elseif key=="actor" or key=="target" or key=="owner" or key=="winner" then item[key]=seat(v,side)
            elseif key=="x" or key=="vx" or key=="lockX" or key=="_knockX" or key=="_chargeX" or key=="_recoverX" then
                if type(v)=="number" then item[key]=-v end
            elseif key=="heading" or key=="_attackHeading" then
                if type(v)=="number" then item[key]=(math.pi-v+math.pi)%(2*math.pi)-math.pi end
            end
        end
    end
    visit(result)
    if result.fighters then
        result.fighters={result.fighters[2],result.fighters[1]}
        for index,fighter in ipairs(result.fighters) do fighter.id=index end
    end
    return result
end
function BattleLab.new(deps)
    return setmetatable({deps=deps,sessions={},matches={},queue={},throttle={},sequence=0,roundSequence=0,
        queueSequence=0,broadcastTime=0,lobbyBroadcastTime=0,seed=math.floor(deps.now()*1000)+7919,seedBase=math.floor(deps.now()*1000)+7919,previous={},invitations={},userInvites={},inviteSequence=0,inviteCooldown={},challengeFeedback={}},BattleLab)
end
function BattleLab:random(maximum)
    self.seed=(self.seed*16807)%2147483647
    return math.floor((self.seed/2147483647)*maximum)+1
end
function BattleLab:roster(player)
    local requested=self.deps.allowExperimental and self.deps.resolveRoster and self.deps.resolveRoster(player)
    local source=requested or PUBLIC
    local result={mode=requested and "experimental" or "public",version=requested and requested.version or self.ROSTER_VERSION,
        offences={},wilds={}}
    for _,kind in ipairs({"offences","wilds"}) do
        local validKind=kind=="offences" and "offence" or "wild"
        for _,id in ipairs(source[kind] or {}) do
            if self.deps.skills.valid(id,validKind) and id~="Copycat" and not contains(result[kind],id) then
                result[kind][#result[kind]+1]=id
            end
        end
    end
    if #result.offences==0 or #result.wilds<2 then return nil end
    -- Fingerprinting the actual pools isolates stale or changed experiments too.
    result.key=result.mode..":"..tostring(result.version)..":"..table.concat(result.offences,",")..":"..table.concat(result.wilds,",")
    return result
end
function BattleLab:identity(player)
    if not player then
        local personas={{"Comet","Bold dives. Same cards as you.","☄️","cruiser",1},{"Pip","Patient aim. Same cards as you.","🐦","skyhopper",2},{"Fizz","Loves a comeback. Same cards as you.","⚡","dart",4}}
        local persona=personas[(self.sequence-1)%#personas+1]
        return {userId=0,name=persona[1],bot=true,portrait=persona[3],personality=persona[2],planeId=persona[4],color=persona[5],trailId="classic"}
    end
    local extra=self.deps.identity and self.deps.identity(player) or {}
    return {userId=player.UserId,name=extra.name or player.DisplayName or player.Name,bot=false,
        planeId=extra.planeId or player:GetAttribute("SkyboundPlane") or "cruiser",
        color=extra.color or player:GetAttribute("SkyboundColor") or 1,
        trailId=extra.trailId or player:GetAttribute("SkyboundTrail") or "classic"}
end
function BattleLab:event(player,name,m,extra)
    if not self.deps.onEvent or not player then return end
    local data={guided=m and m.guided==true,matchId=m and m.id or 0,roundId=m and m.roundId or 0,roundNumber=m and m.roundNumber or 0,
        stage=m and m.stage or 0,mode=m and m.mode or "public",rosterVersion=m and m.roster.version or self.ROSTER_VERSION,
        opponentType=m and (m.participants[2].player and "human" or "bot") or "unknown",
        elapsed=m and self.deps.now()-m.startedAt or 0,queueSeconds=m and m.queueSeconds or 0,
        fightSeconds=m and m.fightSeconds or 0,draftSeconds=m and m.draftSeconds or 0,transitionSeconds=m and m.transitionSeconds or 0}
    for key,value in pairs(extra or {}) do data[key]=value end
    self.deps.onEvent(player,name,data)
end
function BattleLab:slots(m)
    return math.max(0,math.min(self.MAX_WILDS,m.stage-1))
end
-- A complete loadout is one offered attack and one distinct offered wild card
-- for every open slot.
function BattleLab:validBuild(m,side,offenceId,wildIds)
    local offer,slots=m.offers[side],self:slots(m)
    if not offer or not contains(offer.offences,offenceId) or type(wildIds)~="table" or #wildIds~=slots then return false end
    for index=1,slots do
        if not contains(offer.wilds,wildIds[index]) then return false end
        for other=1,index-1 do if wildIds[other]==wildIds[index] then return false end end
    end
    return true
end
-- Fills whatever a draft still lacks: the first offered card for a pilot who
-- ran out of time, a random one for a bot.
function BattleLab:fillDraft(m,side,random)
    local offer,draft=m.offers[side],m.drafts[side]
    if not contains(offer.offences,draft.offenceId) then
        draft.offenceId=offer.offences[random and self:random(#offer.offences) or 1]
    end
    while #draft.wildIds<self:slots(m) do
        local free={}
        for _,id in ipairs(offer.wilds) do if not contains(draft.wildIds,id) then free[#free+1]=id end end
        if #free==0 then break end
        draft.wildIds[#draft.wildIds+1]=free[random and self:random(#free) or 1]
    end
end
function BattleLab:hand(m,side)
    local pool=copy(m.roster.wilds)
    if #pool<=HAND then return pool end
    local held,hand={},{}
    for _,id in ipairs(m.settings[side].wildIds) do held[id]=true end
    for index=#pool,1,-1 do if held[pool[index]] then table.remove(pool,index) end end
    local dealt=0
    for _ in pairs(held) do dealt=dealt+1 end
    while dealt<HAND and #pool>0 do held[table.remove(pool,self:random(#pool))]=true; dealt=dealt+1 end
    -- Shown in roster order, so a card keeps its place between picks.
    for _,id in ipairs(m.roster.wilds) do if held[id] then hand[#hand+1]=id end end
    return hand
end
function BattleLab:changePhase(m,phase,endsAt)
    local elapsed=math.max(0,self.deps.now()-(m.phaseAt or self.deps.now()))
    if m.phase=="Pick" then m.draftSeconds=m.draftSeconds+elapsed
    elseif m.phase=="Fight" then m.fightSeconds=m.fightSeconds+math.min(35,elapsed)
    elseif m.phase then m.transitionSeconds=m.transitionSeconds+elapsed end
    m.phase=phase; m.phaseAt=self.deps.now(); m.endsAt=endsAt or 0
end
function BattleLab:startPick(m)
    self:changePhase(m,"Pick",self.deps.now()+(m.guided and self.GUIDE_PICK_SECONDS or self.PICK_SECONDS))
    m.locked={false,false}; m.offers={}; m.drafts={}; m.offerRevision={1,1}
    for side,participant in ipairs(m.participants) do
        local offer={offences=copy(m.roster.offences),wilds=self:hand(m,side)}
        if m.guided then
            -- The first cards a pilot ever reads: the plainest ones, in a fixed order.
            offer.offences=copy(GUIDE.offences); offer.wilds={}
            for _,id in ipairs(GUIDE.wilds) do
                if #offer.wilds<(GUIDE.hand[m.stage] or 3) and contains(m.roster.wilds,id) then offer.wilds[#offer.wilds+1]=id end
            end
        end
        m.offers[side]=offer
        -- Each draft starts as the plane that just flew.
        m.drafts[side]={offenceId=m.settings[side].offenceId,wildIds=copy(m.settings[side].wildIds)}
        if not participant.player then self:fillDraft(m,side,true); m.locked[side]=true end
    end
end
function BattleLab:startRound(m,countdown)
    self.roundSequence=self.roundSequence+1
    m.roundId=self.roundSequence; m.roundNumber=m.roundNumber+1
    local seed
    if self.deps.allowFixedSeed and finite(self.deps.fixedSeed) then seed=self.deps.fixedSeed
    else seed=(self.seedBase+self.roundSequence*7919)%2147483646+1 end
    m.simulation=self.deps.simulation.newRound(seed,m.settings[1],m.settings[2])
    m.roundEvents={}; m.eventSerial=0; m.accumulator=0
    self:changePhase(m,"Countdown",self.deps.now()+(countdown or 2.4))
end
function BattleLab:reveal(m)
    for side=1,2 do
        m.settings[side].offenceId=m.drafts[side].offenceId
        m.settings[side].wildIds=copy(m.drafts[side].wildIds)
    end
    self:startRound(m)
end
function BattleLab:createMatch(a,b,mode,botIdentity)
    if not a or not self.sessions[a.player.UserId] then return nil end
    self.sequence=self.sequence+1
    local guided=a.guided==true and not b
    if guided then mode="practice" end
    local m={id=self.sequence,participants={{player=a.player},{player=b and b.player}},identities={self:identity(a.player),copy(botIdentity) or self:identity(b and b.player)},
        roster=copy(a.roster),guided=guided,mode=mode or a.roster.mode,diagnostic=a.roster.mode=="experimental" or (self.deps.allowFixedSeed and finite(self.deps.fixedSeed)),startedAt=self.deps.now(),score={0,0},stage=1,
        roundNumber=0,roundId=0,settings={{wildIds={},angle=35},{wildIds={},angle=35}},
        votes={false,false},rewards={},rounds={},completedRounds=0,decisiveRounds=0,fightSeconds=0,draftSeconds=0,transitionSeconds=0,
        queueSeconds=math.max(0,self.deps.now()-a.queuedAt)}
    -- A bot never flies the pilot's own paint; two planes must read apart at a glance.
    local own,rival=m.identities[1],m.identities[2]
    if rival.bot and rival.color==own.color then rival.color=own.color%4+1 end
    self.matches[m.id]=m
    for side,p in ipairs(m.participants) do
        if p.player then
            self.sessions[p.player.UserId]={player=p.player,match=m,side=side}
            self:event(p.player,"match_accepted",m)
        end
    end
    if guided then
        -- Round one is dealt, not picked, so the first thing a new pilot does
        -- is watch a fight. The round winner still earns the first wild card.
        m.settings[1].offenceId=GUIDE.offences[1]; m.settings[2].offenceId=GUIDE.offences[2]
        m.locked={true,true}; m.offers={}; m.drafts={}; m.offerRevision={0,0}
        self:startRound(m,self.GUIDE_INTRO_SECONDS)
    else self:startPick(m) end
    self:emitMatch(m)
    return m
end
function BattleLab:compactQueue()
    local result={}
    for _,entry in ipairs(self.queue) do if self.sessions[entry.player.UserId]==entry then result[#result+1]=entry end end
    self.queue=result
end
function BattleLab:matchQueue()
    self:compactQueue()
    local index=1
    while index<=#self.queue do
        local a=self.queue[index]; local partner
        for other=index+1,#self.queue do if self.queue[other].roster.key==a.roster.key then partner=other; break end end
        if partner then
            local b=table.remove(self.queue,partner); table.remove(self.queue,index); self:createMatch(a,b)
        elseif self.deps.now()>=a.queuedAt+self.QUEUE_SECONDS then table.remove(self.queue,index); self:createMatch(a,nil)
        else index=index+1 end
    end
end
function BattleLab:enter(player)
    if self.sessions[player.UserId] or not self.deps.canEnter(player) then return end
    local roster=self:roster(player); if not roster then return end
    self:cancelInviteFor(player,"unavailable","A pilot entered matchmaking.")
    self.queueSequence=self.queueSequence+1
    local entry={player=player,queuedAt=self.deps.now(),queueId=self.queueSequence,roster=roster}
    entry.guided=roster.mode=="public" and self.deps.firstMatch~=nil and self.deps.firstMatch(player)==true
        and contains(roster.offences,GUIDE.offences[1]) and contains(roster.offences,GUIDE.offences[2])
    self.sessions[player.UserId]=entry
    self.deps.entered(player); self:event(player,"queue",nil,{queueId=entry.queueId,mode=roster.mode,rosterVersion=roster.version})
    -- A first-timer never waits in the queue or meets a human before learning the game.
    if entry.guided then self:createMatch(entry,nil); return end
    table.insert(self.queue,entry)
    self:matchQueue()
end
function BattleLab:facts(m,result,side)
    if result.reason=="disconnect" or result.reason=="exit" then return {"The rival left the match."} end
    if result.reason=="wall_cap" then return {result.winner==0 and "Time limit: completed round wins were tied. Match drawn." or "Time limit: completed round wins decide the match."} end
    if result.reason=="round_cap" then return {result.winner==0 and "Five rounds played: completed round wins were tied. Match drawn." or "Five rounds played: completed round wins decide the match."} end
    if result.reason=="shutdown" then return {"Server closed: the match ended without a winner."} end
    local reason=result.decidingRoundReason or result.reason
    if result.winner==0 then
        return {reason=="knockout" and "Both planes lost their final armor together." or "Equal armor: this round gave neither pilot a point."}
    end
    if reason=="timeout" or reason=="time" then return {"Time ran out: the plane with more armor won."} end
    local facts={}
    for index=#(result.events or {}),1,-1 do
        local event=result.events[index]
        if event.kind=="hit" or event.kind=="wake_hit" then
            local skill=self.deps.skills.get(event.skillId or "")
            facts[1]=(event.actor==side and "Your " or "Rival's ")..(skill and skill.name or "attack").." landed the final hit."
            break
        end
    end
    for index=#(result.events or {}),1,-1 do
        local event=result.events[index]
        if event.kind=="blocked" then
            facts[#facts+1]=(event.actor==side and "Your " or "Rival's ").."Spring Bumper blocked an attack."
            break
        end
    end
    if #facts==0 then facts[1]="The round ended with more armor on the winning plane." end
    if reason=="sudden_death" then facts[1]="Sudden death! "..facts[1] end
    return facts
end
function BattleLab:viewResult(m,result,side)
    if not result then return nil end
    local value=perspective(result,side)
    value.score=pair(result.score or m.score,side)
    value.facts=self:facts(m,result,side)
    return value
end
function BattleLab:snapshot(player)
    local session=self.sessions[player.UserId]
    if not session then return self:lobbySnapshot(player) end
    if not session.match then return {active=true,phase="Searching",serverTime=self.deps.now(),endsAt=session.queuedAt+self.QUEUE_SECONDS,
        queuedAt=session.queuedAt,queueId=session.queueId,rosterVersion=session.roster.version,mode=session.roster.mode} end
    local m,side=session.match,session.side
    local picking=m.phase=="Pick"
    return {active=true,phase=m.phase,matchId=m.id,roundId=m.roundId,roundNumber=m.roundNumber,stage=m.stage,
        slots=self:slots(m),score=pair(m.score,side),settings=pair(m.settings,side),players=pair(m.identities,side),
        simulation=perspective(m.simulation,side),endsAt=m.endsAt,pickDeadline=m.phase=="Pick" and m.endsAt or 0,
        fightDeadline=m.phase=="Fight" and m.fightDeadline or 0,
        matchDeadline=m.startedAt+self.MATCH_SECONDS,serverTime=self.deps.now(),simulatedOpponent=m.identities[3-side].bot,
        guided=m.guided==true,offer=picking and copy(m.offers[side]) or {offences={},wilds={}},offerRevision=m.offerRevision[side],
        draft=picking and copy(m.drafts[side]) or nil,locked=pair(m.locked or {false,false},side),
        matchPoint=m.score[1]==1 or m.score[2]==1,
        result=self:viewResult(m,m.result,side),roundResult=self:viewResult(m,m.roundResult,side),reward=copy(m.rewards[side]),
        rematchVotes=pair(m.votes,side),rivalGone=m.participants[3-side].gone==true,
        rematchStatus=m.participants[3-side].gone and "unavailable" or m.votes[side] and "waiting" or "ready",
        rosterVersion=m.roster.version,mode=m.mode,experimental=m.roster.mode=="experimental"}
end
function BattleLab:emit(player) self.deps.emit(player,self:snapshot(player)) end
function BattleLab:emitMatch(m)
    for _,participant in ipairs(m.participants) do if participant.player and not participant.gone then self:emit(participant.player) end end
end
function BattleLab:terminal(m,winner,reason,leaver)
    if m.phase=="MatchOver" then return end
    self:changePhase(m,"MatchOver")
    m.result={winner=winner,reason=reason,score=copy(m.score),events=copy(m.roundResult and m.roundResult.events or {}),
        decidingRoundReason=reason=="first_to_two" and m.roundResult and m.roundResult.reason or nil}
    for side,p in ipairs(m.participants) do
        if p.player then
            local result={matchId=m.id,winner=seat(winner,side),reason=reason,score=pair(m.score,side),abandoned=side==leaver,
                completedRounds=m.completedRounds,decisiveRounds=m.decisiveRounds,fightSeconds=m.fightSeconds,
                elapsed=self.deps.now()-m.startedAt,opponentType=m.identities[3-side].bot and "bot" or "human",mode=m.mode,
                rosterVersion=m.roster.version,diagnostic=m.diagnostic==true,outcome=side==leaver and "abandoned" or winner==0 and "draw" or winner==side and "win" or "loss",offenceId=m.settings[side].offenceId,wildIds=copy(m.settings[side].wildIds),rounds=copy(m.rounds)}
            self.previous[p.player.UserId]={matchId=m.id,result=result.winner,endedAt=self.deps.now(),requested=false}
            self:event(p.player,"terminal_result",m,result)
            if self.deps.onTerminal then m.rewards[side]=self.deps.onTerminal(p.player,result) end
        end
    end
end
function BattleLab:roundEnded(m)
    local sim=m.simulation; local winner=sim.winner or 0
    m.completedRounds=m.completedRounds+1
    if winner>0 then m.score[winner]=m.score[winner]+1; m.decisiveRounds=m.decisiveRounds+1 end
    local result={winner=winner,reason=sim.reason or "knockout",score=copy(m.score),events=copy(m.roundEvents),roundNumber=m.roundNumber}
    m.roundResult=result
    m.rounds[#m.rounds+1]={seed=sim.seed,settings=copy(m.settings),winner=winner,reason=result.reason,duration=sim.elapsed,roundNumber=m.roundNumber}
    if m.score[1]>=2 or m.score[2]>=2 then self:terminal(m,m.score[1]>=2 and 1 or 2,"first_to_two")
    elseif m.roundNumber>=self.MAX_ROUNDS then self:terminal(m,m.score[1]==m.score[2] and 0 or m.score[1]>m.score[2] and 1 or 2,"round_cap")
    else self:changePhase(m,"RoundOver",self.deps.now()+self.ROUND_OVER_SECONDS) end
end
function BattleLab:leave(player,reason)
    local session=self.sessions[player.UserId]; if not session then return end
    local m=session.match
    if m then
        local side=session.side
        if m.phase~="MatchOver" then
            self:event(player,"abandoned",m,{phase=m.phase,reason=reason or "exit"})
            self:terminal(m,3-side,reason or "exit",side)
        end
        m.participants[side].gone=true; m.votes[side]=false
        self.sessions[player.UserId]=nil
        self:emitMatch(m)
        if (m.participants[1].gone or not m.participants[1].player) and (m.participants[2].gone or not m.participants[2].player) then self.matches[m.id]=nil end
    else
        self:event(player,"abandoned",nil,{phase="Searching",queueId=session.queueId,elapsed=self.deps.now()-session.queuedAt})
        self.sessions[player.UserId]=nil; self:compactQueue()
    end
    self.deps.exited(player)
end
-- Invitations are offers, not reservations: walking/queueing stays usable.
-- Acceptance checks both players and freezes their shared pool before reserving
-- either one. No yielding callbacks occur until both records are installed.
function BattleLab:available(player)
    return player~=nil and self.sessions[player.UserId]==nil and self.deps.canEnter(player)
end
function BattleLab:lobbySnapshot(player)
    local candidates={}
    for _,other in ipairs(self.deps.getPlayers and self.deps.getPlayers() or {}) do
        if other.UserId~=player.UserId then
            candidates[#candidates+1]={userId=other.UserId,name=other.DisplayName or other.Name,available=self:available(other) and not self.userInvites[other.UserId]}
        end
    end
    table.sort(candidates,function(a,b)return a.userId<b.userId end)
    local invite=self.userInvites[player.UserId]; local view
    if invite then
        local incoming=invite.to.UserId==player.UserId; local other=incoming and invite.from or invite.to
        view={inviteId=invite.id,direction=incoming and "incoming" or "outgoing",name=other.DisplayName or other.Name,
            userId=other.UserId,expiresAt=invite.expiresAt}
    end
    return {active=false,serverTime=self.deps.now(),challenge=view,challengeCandidates=candidates,
        challengeFeedback=copy(self.challengeFeedback[player.UserId])}
end
function BattleLab:clearInvite(invite,code,message,silent)
    if not invite or self.invitations[invite.id]~=invite then return end
    self.invitations[invite.id]=nil
    for _,player in ipairs({invite.from,invite.to}) do
        if self.userInvites[player.UserId]==invite then self.userInvites[player.UserId]=nil end
        self.challengeFeedback[player.UserId]={ok=code=="accepted",code=code,text=message}
    end
    if not silent then self:emit(invite.from); self:emit(invite.to) end
end
function BattleLab:cancelInviteFor(player,code,message)
    self:clearInvite(self.userInvites[player.UserId],code,message)
end
function BattleLab:challengeCommand(player,payload)
    local kind=payload.kind;local invite=self.userInvites[player.UserId]
    local function refuse(code,message)
        self.challengeFeedback[player.UserId]={ok=false,code=code,text=message};self:emit(player)
    end
    if kind=="challenge" then
        if not self:available(player) then refuse("busy","Return to the hangar to challenge a pilot.");return end
        if invite then refuse("pending","Answer or cancel the current challenge first.");return end
        if self.deps.now()<(self.inviteCooldown[player.UserId] or 0) then refuse("cooldown","Wait a moment before challenging again.");return end
        local target
        for _,other in ipairs(self.deps.getPlayers and self.deps.getPlayers() or {}) do if other.UserId==payload.targetUserId then target=other end end
        if not target or target.UserId==player.UserId or not self:available(target) or self.userInvites[target.UserId] then
            refuse("unavailable","That pilot is unavailable. Choose another pilot.");return
        end
        local a,b=self:roster(player),self:roster(target)
        if not a or not b or a.key~=b.key then refuse("roster","These pilots are in different test pools.");return end
        self.inviteSequence=self.inviteSequence+1
        local duration=finite(self.deps.challengeSeconds) and math.max(5,math.min(60,self.deps.challengeSeconds)) or 25
        invite={id=self.inviteSequence,from=player,to=target,expiresAt=self.deps.now()+duration}
        self.invitations[invite.id]=invite;self.userInvites[player.UserId]=invite;self.userInvites[target.UserId]=invite
        self.inviteCooldown[player.UserId]=self.deps.now()+3
        self.challengeFeedback[player.UserId]={ok=true,code="sent",text="Challenge sent."}
        self.challengeFeedback[target.UserId]=nil;self:emit(player);self:emit(target)
    elseif invite and payload.inviteId==invite.id then
        if self.deps.now()>=invite.expiresAt then self:clearInvite(invite,"expired","Challenge expired.");return end
        if kind=="challengeCancel" and invite.from==player then self:clearInvite(invite,"cancelled","Challenge cancelled.")
        elseif kind=="challengeDecline" and invite.to==player then self:clearInvite(invite,"declined","Challenge declined.")
        elseif kind=="challengeAccept" and invite.to==player then
            local a,b=invite.from,invite.to
            local rosterA,rosterB=self:roster(a),self:roster(b)
            if not self:available(a) or not self:available(b) or not rosterA or not rosterB or rosterA.key~=rosterB.key then
                self:clearInvite(invite,"unavailable","A pilot is no longer available.");return
            end
            local entryA={player=a,queuedAt=self.deps.now(),roster=rosterA}
            local entryB={player=b,queuedAt=self.deps.now(),roster=rosterB}
            self.sessions[a.UserId]=entryA;self.sessions[b.UserId]=entryB
            self:clearInvite(invite,"accepted","Challenge accepted.",true)
            self.deps.entered(a);self.deps.entered(b)
            self:createMatch(entryA,entryB,"challenge")
        end
    else refuse("expired","That challenge is no longer available.") end
end
function BattleLab:command(player,payload)
    if type(payload)~="table" or type(payload.kind)~="string" then return end
    local kind=payload.kind; local time=self.deps.now()
    if kind=="exit" then
        local current=self.sessions[player.UserId]
        if current and current.match and payload.matchId~=nil and payload.matchId~=current.match.id then return end
        if current and not current.match and payload.queueId~=nil and payload.queueId~=current.queueId then return end
        self:cancelInviteFor(player,"cancelled","Challenge cancelled.")
        self:leave(player,"exit"); self:emit(player); return
    end
    local budget=self.throttle[player.UserId] or {time=time,tokens=8}
    budget.tokens=math.min(8,budget.tokens+math.max(0,time-budget.time)*15); budget.time=time; self.throttle[player.UserId]=budget
    if budget.tokens<1 then return end; budget.tokens=budget.tokens-1
    local session=self.sessions[player.UserId]; local m=session and session.match
    if kind=="request" then self:emit(player); return end
    if kind=="challenge" or kind=="challengeAccept" or kind=="challengeDecline" or kind=="challengeCancel" then
        self:challengeCommand(player,payload); return
    end
    if kind=="enter" and not session then self:enter(player)
    elseif m and payload.matchId==m.id then
        local side=session.side
        if kind=="rematchDecline" and m.phase=="MatchOver" then
            local players={m.participants[1].player,m.participants[2].player}
            for _,participant in ipairs(players) do
                if participant and self.sessions[participant.UserId] then self:leave(participant); self:emit(participant) end
            end
        elseif kind=="again" and m.phase=="MatchOver" then
            self:event(player,"replay_requested",m,{route="queue"})
            if self.previous[player.UserId] then self.previous[player.UserId].requested=true end
            self:leave(player); self:enter(player)
        elseif kind=="rematch" and m.phase=="MatchOver" and not m.participants[3-side].gone and not m.votes[side] then
            m.votes[side]=true
            self:event(player,"replay_requested",m,{route="rematch"})
            if self.previous[player.UserId] then self.previous[player.UserId].requested=true end
            if not m.participants[3-side].player then m.votes[3-side]=true end
            if m.votes[1] and m.votes[2] then
                local a={player=m.participants[1].player,queuedAt=time,roster=m.roster}
                local b=m.participants[2].player and {player=m.participants[2].player,queuedAt=time,roster=m.roster} or nil
                self.matches[m.id]=nil; self:createMatch(a,b,not m.guided and m.mode or nil,not b and m.identities[2] or nil)
            end
        elseif m.phase=="Pick" and time<m.endsAt and payload.stage==m.stage and payload.offerRevision==m.offerRevision[side] and not m.locked[side]
            and payload.side==nil and payload.userId==nil and payload.playerId==nil and payload.settings==nil then
            local draft,offer,index=m.drafts[side],m.offers[side],payload.index
            if kind=="pick" and payload.slot=="offence" and contains(offer.offences,payload.skillId) then
                draft.offenceId=payload.skillId
            elseif kind=="pick" and payload.slot=="wild" and contains(offer.wilds,payload.skillId) and not contains(draft.wildIds,payload.skillId)
                and type(index)=="number" and index%1==0 and index>=1 and index<=self:slots(m) and index<=#draft.wildIds+1 then
                draft.wildIds[index]=payload.skillId
            elseif kind=="lock" and self:validBuild(m,side,payload.offenceId,payload.wildIds) then
                -- Lock exactly the loadout the pilot saw. Only the deadline
                -- may fill a gap: an incomplete or stale lock cannot.
                draft.offenceId=payload.offenceId; draft.wildIds={}
                for slot=1,self:slots(m) do draft.wildIds[slot]=payload.wildIds[slot] end
                m.locked[side]=true
                if m.locked[1] and m.locked[2] then self:reveal(m) end
            end
        end
        self:emitMatch(m)
    end
    self:emit(player)
end
function BattleLab:step(dt)
    if not finite(dt) or dt<=0 then return end
    for _,invite in pairs(self.invitations) do
        if self.deps.now()>=invite.expiresAt then self:clearInvite(invite,"expired","Challenge expired.") end
    end
    self:matchQueue()
    self.lobbyBroadcastTime=self.lobbyBroadcastTime+dt
    if self.lobbyBroadcastTime>=.5 then
        self.lobbyBroadcastTime=0
        for _,player in ipairs(self.deps.getPlayers and self.deps.getPlayers() or {}) do
            if not self.sessions[player.UserId] then self:emit(player) end
        end
    end
    self.broadcastTime=self.broadcastTime+dt
    local emit=self.broadcastTime>=1/20; if emit then self.broadcastTime=0 end
    local time=self.deps.now()
    for _,m in pairs(self.matches) do
        if m.phase~="MatchOver" and time>=m.startedAt+self.MATCH_SECONDS then
            self:terminal(m,m.score[1]==m.score[2] and 0 or m.score[1]>m.score[2] and 1 or 2,"wall_cap")
        elseif m.phase=="Pick" and time>=m.endsAt then
            for side=1,2 do if not m.locked[side] then self:fillDraft(m,side,false); m.locked[side]=true end end
            self:reveal(m)
        elseif m.phase=="Countdown" and time>=m.endsAt then
            self:changePhase(m,"Fight"); m.accumulator=0; m.fightDeadline=time+35
            for _,p in ipairs(m.participants) do
                if p.player then
                    self:event(p.player,m.roundNumber==1 and "first_launch" or "round_launch",m,{seed=m.simulation.seed})
                end
            end
        elseif m.phase=="RoundOver" and time>=m.endsAt then
            if m.roundResult.winner>0 then m.stage=m.stage+1; self:startPick(m) else self:startRound(m) end
        end
        if m.phase=="Fight" and time>=m.fightDeadline then
            local sim=m.simulation;local a,b=sim.fighters[1],sim.fighters[2]
            sim.finished=true;sim.elapsed=35;sim.reason="timeout"
            sim.winner=a.armor==b.armor and 0 or a.armor>b.armor and 1 or 2
            a.armed=false;b.armed=false
            self:roundEnded(m)
        end
        if m.phase=="Fight" then
            m.accumulator=math.min(m.accumulator+dt,0.25)
            while m.accumulator+0.000000001>=self.deps.simulation.FIXED_DT do
                m.accumulator=m.accumulator-self.deps.simulation.FIXED_DT
                self.deps.simulation.step(m.simulation,self.deps.simulation.FIXED_DT)
                for _,event in ipairs(m.simulation.events or {}) do
                    if event.serial>m.eventSerial then
                        m.eventSerial=event.serial
                        if event.kind=="hit" or event.kind=="wake_hit" or event.kind=="blocked" or event.kind=="finish" or event.kind=="revive" then
                            local recorded=copy(event); recorded.roundNumber=m.roundNumber; recorded.outcome=event.kind
                            local sourceSkills={meteor="Meteor",rocket="Firework",machinegun="MachineGun",pinball="Pinball",wake="FizzyFuel"}
                            recorded.skillId=recorded.skillId or sourceSkills[recorded.source]
                            m.roundEvents[#m.roundEvents+1]=recorded
                        end
                    end
                end
                if m.simulation.finished then self:roundEnded(m); break end
            end
        end
        if emit then self:emitMatch(m) end
    end
    if emit then for _,entry in ipairs(self.queue) do self:emit(entry.player) end end
end
function BattleLab:shutdown()
    for _,m in pairs(self.matches) do
        if m.phase~="MatchOver" then self:terminal(m,0,"shutdown") end
    end
    local players={}
    for _,session in pairs(self.sessions) do players[#players+1]=session.player end
    for _,player in ipairs(players) do self:leave(player,"shutdown");self:emit(player) end
    for _,invite in pairs(self.invitations) do self:clearInvite(invite,"shutdown","Server closing.") end
    self.queue={}
end
function BattleLab:remove(player)
    self:cancelInviteFor(player,"departed","The other pilot left the server.")
    self:leave(player,"disconnect"); self.throttle[player.UserId]=nil; self.previous[player.UserId]=nil
    self.inviteCooldown[player.UserId]=nil; self.challengeFeedback[player.UserId]=nil
end
return BattleLab
