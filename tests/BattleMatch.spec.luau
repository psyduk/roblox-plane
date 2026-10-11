-- Deterministic service doubles exercise orchestration, never replication/UI.
return function(BattleLab, Skills)
    local count=0
    local function test(name,fn)
        local ok,err=pcall(fn); assert(ok,name..": "..tostring(err)); count=count+1
    end
    local function harness(options)
        options=options or {}
        local t={time=0,emitted={},terminal={},events={},entered={},players={}}
        local simulation={FIXED_DT=1/60}
        function simulation.newRound(seed,a,b)
            return {seed=seed,elapsed=0,events={},projectiles={},wakes={},fighters={
                {id=1,x=-52,vx=20,heading=.3,armor=3,settings=a},{id=2,x=52,vx=-20,heading=2.8,armor=3,settings=b}}}
        end
        function simulation.step(s,dt)
            if s.finished then return end
            s.elapsed=s.elapsed+dt
            if s.elapsed>=35-0.000001 then s.elapsed=35;s.finished=true;s.reason="timeout";s.winner=s.fighters[1].armor==s.fighters[2].armor and 0 or s.fighters[1].armor>s.fighters[2].armor and 1 or 2 end
        end
        local deps={skills=Skills,simulation=simulation,now=function()return t.time end,
            getPlayers=function()local result={}for _,p in pairs(t.players)do result[#result+1]=p end return result end,
            emit=function(p,s)t.emitted[p.UserId]=s end,
            canEnter=function(p)return not t.entered[p.UserId]end,
            entered=function(p)t.entered[p.UserId]=true end,exited=function(p)t.entered[p.UserId]=nil end,
            onTerminal=function(p,result)t.terminal[#t.terminal+1]={id=p.UserId,result=result}end,
            onEvent=function(p,name,data)t.events[#t.events+1]={id=p.UserId,name=name,data=data}end}
        for key,value in pairs(options)do deps[key]=value end
        t.lab=BattleLab.new(deps)
        -- These cases step through transitions with a two-second round pause.
        t.lab.ROUND_OVER_SECONDS=2
        -- The dealt-hand draft stays covered here; the public default deals
        -- the whole roster and is checked on its own below.
        if not options.publicDraft then t.lab.PICK_SECONDS=10;t.lab.OFFER_SIZE=3;t.lab.REROLLS=1;t.lab.PICK_ANYS=1 end
        function t.player(id)
            local p={UserId=id,Name="Pilot"..id,DisplayName="Pilot"..id}
            function p:GetAttribute(key)if key=="SkyboundColor"then return id end return nil end
            t.players[id]=p;return p
        end
        function t.send(p,kind,extra)
            local s=t.lab:snapshot(p);local payload=extra or {}
            payload.kind=kind;if payload.matchId==nil then payload.matchId=s.matchId end;if payload.stage==nil then payload.stage=s.stage end
            if payload.offerRevision==nil then payload.offerRevision=s.offerRevision end
            if kind=="lock" then payload.slot=payload.slot or s.slot;payload.skillId=payload.skillId or s.selected or s.offer[1] end
            t.lab:command(p,payload)
        end
        function t.advance(seconds)
            local target=t.time+seconds
            while t.time<target-0.000001 do local dt=math.min(.1,target-t.time);t.time=t.time+dt;t.lab:step(dt)end
        end
        function t.pair()
            local a,b=t.player(1),t.player(2);t.send(a,"enter");t.send(b,"enter");return a,b,t.lab.sessions[1].match
        end
        function t.lock(p)
            local s=t.lab:snapshot(p);t.send(p,"pick",{slot=s.slot,skillId=s.offer[1]});t.send(p,"lock")
        end
        function t.fight(a,b)
            t.lock(a);if b then t.lock(b)end;t.advance(2.5)
            assert(t.lab:snapshot(a).phase=="Fight")
        end
        function t.finish(m,winner,reason)
            m.simulation.finished=true;m.simulation.winner=winner;m.simulation.reason=reason or "knockout"
            t.advance(.1)
        end
        return t
    end
    test("pair oldest compatible users and isolate independent matches",function()
        local t=harness();local a,b,m=t.pair();assert(t.lab:snapshot(a).phase=="Pick")
        assert(t.lab:snapshot(a).matchId==t.lab:snapshot(b).matchId)
        assert(not t.lab:snapshot(a).simulatedOpponent)
        local c,d=t.player(3),t.player(4);t.send(c,"enter");t.send(d,"enter")
        assert(t.lab:snapshot(c).matchId~=m.id)
        t.send(a,"exit");assert(t.lab:snapshot(b).result.winner==1 and t.lab:snapshot(c).phase=="Pick")
    end)
    test("eight-second named bot fallback and cancellation remove queue reservations",function()
        local t=harness();local a=t.player(1);t.send(a,"enter");t.advance(7.8)
        assert(t.lab:snapshot(a).phase=="Searching");t.send(a,"exit");t.advance(10);assert(not t.lab:snapshot(a).active)
        t.send(a,"enter");t.advance(8.1);local s=t.lab:snapshot(a)
        assert(s.phase=="Pick" and s.simulatedOpponent and s.players[2].bot and s.players[2].name=="Comet")
        assert(s.resources.reroll==1 and s.resources.pickAny==1)
    end)
    test("offers and selection stay private until simultaneous reveal",function()
        local t=harness();local a,b,m=t.pair();local sa=t.lab:snapshot(a);local sb=t.lab:snapshot(b)
        assert(#sa.offer==3 and #sb.offer==3 and sa.offers==nil and sa.settings[2].offenceId==nil)
        t.send(a,"pick",{slot="offence",skillId=sa.offer[2]});t.send(a,"lock")
        sb=t.lab:snapshot(b);assert(sb.settings[2].offenceId==nil and sb.selected==nil and sb.locked[2])
        t.lock(b);sa=t.lab:snapshot(a);sb=t.lab:snapshot(b)
        assert(sa.phase=="Countdown" and sa.settings[1].offenceId==sb.settings[2].offenceId)
        assert(sa.settings[1].offenceId==sa.simulation.fighters[1].settings.offenceId)
        assert(sb.players[1].userId==2 and sb.players[2].userId==1)
    end)
    test("reject outside-offer inactive wrong-kind cross-player stale and wrong-phase commands",function()
        local t=harness();local a,b,m=t.pair();local s=t.lab:snapshot(a)
        local outside;for _,id in ipairs(s.eligible)do local found=false;for _,o in ipairs(s.offer)do if o==id then found=true end end;if not found then outside=id end end
        for _,extra in ipairs({{slot="offence",skillId=outside},{slot="wild",skillId=s.offer[1]},
            {slot="offence",skillId="Copycat"},{slot="offence",skillId="Afterburner"},
            {slot="offence",skillId=s.offer[1],side=2},{slot="offence",skillId=s.offer[1],userId=2},
            {slot="offence",skillId=s.offer[1],matchId=999},{slot="offence",skillId=s.offer[1],stage=2}})do
            t.advance(.1);t.send(a,"pick",extra);assert(t.lab:snapshot(a).selected==nil)
        end
        t.lock(a);local chosen=m.selected[1];t.advance(.1);t.send(a,"pick",{slot="offence",skillId=s.offer[3]});assert(m.selected[1]==chosen)
        t.lock(b);t.advance(.1);t.send(a,"pickAny");assert(m.resources[1].pickAny==1)
        t.send(a,"configure",{settings={{offenceId="Copycat"},{offenceId="Copycat"}}});assert(m.settings[1].offenceId==chosen)
    end)
    test("the public draft deals the whole roster in order with nothing to reroll",function()
        local t=harness({publicDraft=true});local a,b,m=t.pair();local s=t.lab:snapshot(a)
        assert(table.concat(s.offer,",")=="Meteor,Firework,MachineGun,Pinball" and s.resources.reroll==0 and s.resources.pickAny==0)
        t.send(a,"reroll");t.send(a,"pickAny");assert(t.lab:snapshot(a).offerRevision==s.offerRevision)
        t.advance(14.9);assert(m.phase=="Pick");t.advance(.2);assert(m.phase~="Pick","The 15-second deadline did not lock")
        t.advance(2.5);assert(m.phase=="Fight");t.finish(m,1);t.advance(3.6);s=t.lab:snapshot(a)
        assert(s.phase=="Pick" and #s.offer==5 and s.offer[1]=="Afterburner","Wild pick hid part of the roster")
    end)
    test("reroll changes set once and Pick Any consumes once for the entire match",function()
        local t=harness();local a,b,m=t.pair();local old=t.lab:snapshot(a).offer;t.send(a,"reroll")
        local s=t.lab:snapshot(a);local changed=false
        for _,id in ipairs(s.offer)do local found=false;for _,o in ipairs(old)do if o==id then found=true end end;if not found then changed=true end end
        assert(changed and s.resources.reroll==0 and s.selected==nil)
        local nextOffer=table.concat(s.offer,",");t.send(a,"reroll");assert(table.concat(t.lab:snapshot(a).offer,",")==nextOffer)
        t.send(a,"pickAny");assert(#t.lab:snapshot(a).offer==4 and t.lab:snapshot(a).resources.pickAny==0)
        t.fight(a,b);t.finish(m,0,"timeout");t.advance(4.7)
        assert(m.phase=="Fight" and m.stage==1 and m.resources[1].reroll==0 and m.resources[1].pickAny==0)
    end)
    test("stale offer and bare locks never auto-pick a replacement card",function()
        local t=harness();local a,b,m=t.pair();local old=t.lab:snapshot(a)
        -- Raw commands intentionally bypass the friendly packet helper.
        t.lab:command(a,{kind="lock",matchId=m.id,stage=1})
        assert(not m.locked[1] and m.selected[1]==nil,"Bare lock auto-picked")
        t.send(a,"reroll");local current=t.lab:snapshot(a)
        assert(current.offerRevision==old.offerRevision+1)
        local removed;for _,id in ipairs(old.offer)do if not table.find(current.offer,id)then removed=id end end
        assert(removed)
        t.advance(.1)
        t.lab:command(a,{kind="pick",matchId=m.id,stage=1,slot="offence",skillId=removed,offerRevision=old.offerRevision})
        t.lab:command(a,{kind="lock",matchId=m.id,stage=1,slot="offence",skillId=removed,offerRevision=old.offerRevision})
        assert(not m.locked[1] and m.selected[1]==nil,"Stale offer locked a different card")
        -- Even a card shared by both offers needs the current revision.
        t.advance(.1)
        t.lab:command(a,{kind="lock",matchId=m.id,stage=1,slot="offence",skillId=current.offer[1],offerRevision=old.offerRevision})
        t.lab:command(a,{kind="lock",matchId=m.id,stage=1,slot="offence",offerRevision=current.offerRevision})
        t.lab:command(a,{kind="lock",matchId=m.id,stage=1,slot="offence",skillId=removed,offerRevision=current.offerRevision})
        assert(not m.locked[1] and m.selected[1]==nil,"Invalid lock fell back to the first offer")
        t.advance(.2)
        t.send(a,"lock",{slot="offence",skillId=current.offer[2]});t.lock(b)
        assert(m.phase=="Countdown" and m.settings[1].offenceId==current.offer[2],"Explicit current card not preserved")
    end)
    test("terminal armor win explains the deciding round instead of the rival's last hit",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b)
        t.finish(m,1,"timeout");t.advance(2.1);t.fight(a,b)
        m.roundEvents={{kind="hit",actor=2,target=1,skillId="Pinball"}}
        m.simulation.fighters[1].armor=2;m.simulation.fighters[2].armor=1
        t.finish(m,1,"timeout")
        for _,player in ipairs({a,b})do
            local result=t.lab:snapshot(player).result
            assert(result.reason=="first_to_two" and result.decidingRoundReason=="timeout")
            assert(result.facts[1]=="Time ran out: the plane with more armor won.","Last hit misrepresented the armor win")
        end
    end)
    test("draw and terminal caps explain the actual deciding rule",function()
        local t=harness();local a,b,m=t.pair()
        assert(t.lab:facts(m,{winner=0,reason="knockout"},1)[1]=="Both planes lost their final armor together.")
        assert(t.lab:facts(m,{winner=0,reason="timeout"},1)[1]=="Equal armor: this round gave neither pilot a point.")
        for _,reason in ipairs({"wall_cap","round_cap"})do
            assert(string.find(t.lab:facts(m,{winner=0,reason=reason},1)[1],"Match drawn.",1,true))
            assert(string.find(t.lab:facts(m,{winner=1,reason=reason,decidingRoundReason="timeout"},1)[1],"completed round wins",1,true))
        end
    end)
    test("Pick Any revisions reject queued old selections and stale resource requests",function()
        local t=harness();local a,b,m=t.pair();local old=t.lab:snapshot(a)
        t.send(a,"pickAny");local current=t.lab:snapshot(a)
        assert(current.offerRevision==old.offerRevision+1)
        t.send(a,"pick",{slot=old.slot,skillId=old.offer[1],offerRevision=old.offerRevision})
        t.send(a,"lock",{slot=old.slot,skillId=old.offer[1],offerRevision=old.offerRevision})
        t.send(a,"reroll",{offerRevision=old.offerRevision})
        assert(not m.locked[1] and m.selected[1]==nil and m.resources[1].reroll==1)
        t.advance(.1);t.send(a,"lock",{skillId=current.offer[#current.offer]});t.lock(b)
        assert(m.settings[1].offenceId==current.offer[#current.offer])
    end)
    test("eligible pools below equal and above three and disabled reroll does not consume",function()
        for count=2,4 do
            local roster={version="test",offences={"Meteor","Firework","MachineGun","Pinball"},wilds={"Afterburner","SpringBumper"}}
            while #roster.offences>count do table.remove(roster.offences)end
            local t=harness({allowExperimental=true,resolveRoster=function()return roster end})
            local a,b=t.pair();local s=t.lab:snapshot(a);assert(#s.offer==math.min(3,count))
            t.send(a,"reroll");assert(t.lab:snapshot(a).resources.reroll==(count>3 and 0 or 1))
        end
    end)
    test("timeout takes first offer and late picks cannot change the committed round",function()
        local t=harness();local a,b,m=t.pair();local s=t.lab:snapshot(a);local first=s.offer[1]
        t.send(a,"pick",{slot="offence",skillId=s.offer[2]});t.advance(10.1)
        assert(m.phase=="Countdown" and m.settings[1].offenceId==first)
        t.send(a,"pick",{slot="offence",skillId=s.offer[3]});assert(m.settings[1].offenceId==first)
    end)
    test("2-0 ends immediately and draft advances both players after decisive rounds",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b);t.finish(m,1);t.advance(2.1)
        assert(m.stage==2 and m.phase=="Pick" and #m.settings[1].wildIds==0)
        assert(t.lab:snapshot(a).matchPoint and t.lab:snapshot(b).matchPoint)
        t.fight(a,b);t.finish(m,1)
        assert(m.phase=="MatchOver" and m.score[1]==2 and m.roundNumber==2 and #m.settings[1].wildIds==1)
        assert(#t.terminal==2 and t.lab:snapshot(b).result.winner==2)
        t.advance(10);assert(#t.terminal==2)
    end)
    test("2-1 accumulates distinct second wild cards and rejects previous-stage packets",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b);t.finish(m,1);t.advance(2.1);t.fight(a,b);t.finish(m,2);t.advance(2.1)
        assert(m.stage==3 and m.score[1]==1 and m.score[2]==1)
        local first=m.settings[1].wildIds[1]
        for _,id in ipairs(t.lab:snapshot(a).eligible)do assert(id~=first)end
        t.send(a,"pick",{stage=2,slot="wild",skillId=t.lab:snapshot(a).offer[1]});assert(m.selected[1]==nil)
        t.send(a,"pick",{slot="wild",skillId=first});assert(m.selected[1]==nil)
        t.fight(a,b);assert(#m.settings[1].wildIds==2 and m.settings[1].wildIds[2]~=first)
        t.finish(m,2);assert(m.phase=="MatchOver" and m.score[2]==2)
    end)
    test("draw gives no point no pick and a new seed; five drawn rounds end honestly",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b)
        local seeds={}
        for index=1,5 do
            assert(not seeds[m.simulation.seed]);seeds[m.simulation.seed]=true
            t.finish(m,0,"timeout")
            if index<5 then t.advance(4.7);assert(m.phase=="Fight" and m.stage==1 and m.score[1]==0)end
        end
        assert(m.phase=="MatchOver" and m.result.reason=="round_cap" and m.result.winner==0 and m.roundNumber==5)
    end)
    test("five-round cap compares completed wins without inventing an extra point",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b);t.finish(m,1);t.advance(2.1);t.fight(a,b)
        for index=2,5 do t.finish(m,0,"timeout");if index<5 then t.advance(4.7)end end
        assert(m.result.reason=="round_cap" and m.result.winner==1 and m.score[1]==1 and m.score[2]==0)
    end)
    test("wall-clock cap stops unfinished fight without awarding its armor leader a point",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b);m.simulation.fighters[1].armor=3;m.simulation.fighters[2].armor=1
        t.time=m.startedAt+240;t.lab:step(.1)
        assert(m.phase=="MatchOver" and m.result.reason=="wall_cap" and m.result.winner==0 and m.completedRounds==0)
        assert(m.score[1]==0 and m.score[2]==0)
        t.send(a,"again");t.advance(8.1);assert(t.lab:snapshot(a).phase=="Pick")
    end)
    test("35-second physical cap compares armor and equal armor draws",function()
        for _,armor in ipairs({3,2})do
            local t=harness();local a,b,m=t.pair();t.fight(a,b);m.simulation.fighters[2].armor=armor;t.advance(35)
            assert(m.roundResult.winner==(armor==3 and 0 or 1) and m.simulation.elapsed==35)
        end
    end)
    test("exit disconnect both leave and repeat departures clear reservations exactly once",function()
        for _,inFight in ipairs({false,true})do
            local t=harness();local a,b,m=t.pair();if inFight then t.fight(a,b)end
            t.lab:remove(a);assert(t.lab:snapshot(b).phase=="MatchOver" and t.lab:snapshot(b).rivalGone)
            assert(t.terminal[1].result.abandoned and not t.terminal[2].result.abandoned)
            assert(not t.entered[1] and t.lab.sessions[1]==nil)
            t.lab:remove(a);assert(#t.terminal==2)
            t.send(b,"exit");assert(t.lab.matches[m.id]==nil and not t.entered[2])
            t.send(a,"enter");t.send(b,"enter");assert(t.lab:snapshot(a).phase=="Pick")
        end
    end)
    test("mutual rematch resets builds and resources while one vote cannot start",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b);t.finish(m,1);t.advance(2.1);t.fight(a,b);t.finish(m,1)
        t.send(a,"rematch");assert(m.phase=="MatchOver" and t.lab:snapshot(a).rematchVotes[1])
        t.send(b,"rematch");local nextMatch=t.lab.sessions[1].match
        assert(nextMatch.id~=m.id and nextMatch.phase=="Pick" and nextMatch.settings[1].offenceId==nil and nextMatch.resources[1].reroll==1)
        t.send(a,"lock",{matchId=m.id,stage=1});assert(not nextMatch.locked[1])
    end)
    test("declined rematch stays terminal with unavailable rival and allows requeue",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b);t.finish(m,1);t.advance(2.1);t.fight(a,b);t.finish(m,1)
        t.send(a,"rematch");t.send(b,"exit");assert(t.lab:snapshot(a).rematchStatus=="unavailable")
        t.advance(.1);t.send(a,"again");assert(t.lab:snapshot(a).phase=="Searching")
    end)
    test("bot rematch accepts immediately and fixed seed is server-only",function()
        local t=harness({allowFixedSeed=true,fixedSeed=731});local a=t.player(1);t.send(a,"enter");t.advance(8.1)
        local m=t.lab.sessions[1].match;t.fight(a);assert(m.simulation.seed==731)
        t.finish(m,1);t.advance(2.1);t.fight(a);assert(m.simulation.seed==731);t.finish(m,1)
        local identity=m.identities[2]
        t.send(a,"rematch");assert(t.lab:snapshot(a).phase=="Pick" and t.lab:snapshot(a).matchId~=m.id)
        local sameBot=t.lab:snapshot(a).players[2]
        assert(sameBot.name==identity.name and sameBot.planeId==identity.planeId and sameBot.portrait==identity.portrait and sameBot.color==identity.color)
    end)
    test("public ignores experimental requests; authorized pools freeze and never mix",function()
        local roster={version="experiment",offences={"Meteor","Firework"},wilds={"Afterburner","SpringBumper"}}
        local t=harness({resolveRoster=function()return roster end});local a,b,m=t.pair();assert(m.roster.mode=="public" and #m.roster.offences==4)
        local x=harness({allowExperimental=true,resolveRoster=function(p)if p.UserId==1 then return roster end end})
        local c,d=x.player(1),x.player(2);x.send(c,"enter");x.send(d,"enter");assert(x.lab:snapshot(c).phase=="Searching")
        x.advance(8.1);local old=x.lab.sessions[1].match;roster.offences={"Pinball"}
        assert(#old.roster.offences==2 and x.lab:snapshot(d).mode=="public" and x.lab:snapshot(c).experimental)
    end)
    test("perspective mirrors complete event identities owners coordinates and results",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b)
        m.simulation.events={{serial=1,kind="hit",actor=1,target=2,x=12,heading=.3,skillId="Meteor"}}
        m.simulation.projectiles={{id=7,owner=1,x=9,vx=2}};m.simulation.wakes={{id=8,owner=2,x=-7}}
        local view=t.lab:snapshot(b).simulation
        assert(view.fighters[1].id==1 and view.fighters[1].x==-52 and view.fighters[1].vx==20)
        assert(view.events[1].actor==2 and view.events[1].target==1 and view.events[1].x==-12)
        assert(view.projectiles[1].id==7 and view.projectiles[1].owner==2 and view.projectiles[1].vx==-2 and view.wakes[1].owner==1)
        assert(m.simulation.events[1].actor==1 and m.simulation.fighters[1].x==-52)
        t.finish(m,1);local result=t.lab:snapshot(b).roundResult
        assert(result.winner==2 and result.events[1].actor==2 and string.find(result.facts[1],"Rival's Meteor"))
    end)
    test("snapshot mutation cannot change the server offer build roster or simulation",function()
        local t=harness();local a,b,m=t.pair();local s=t.lab:snapshot(a)
        s.offer[1]="Copycat";s.eligible[1]="Copycat";s.resources.reroll=99;s.settings[1].wildIds[1]="Copycat"
        assert(m.offers[1][1]~="Copycat" and m.resources[1].reroll==1 and #m.settings[1].wildIds==0)
        t.fight(a,b);s=t.lab:snapshot(a);s.simulation.fighters[1].armor=99;assert(m.simulation.fighters[1].armor==3)
    end)
    test("challenge explicitly accepts into one isolated shared-roster match",function()
        local t=harness();local a,b=t.player(1),t.player(2)
        t.send(a,"challenge",{targetUserId=2});local incoming=t.lab:snapshot(b).challenge
        assert(incoming.direction=="incoming" and incoming.name=="Pilot1" and incoming.expiresAt==25)
        assert(not t.entered[1] and not t.entered[2] and not t.lab:snapshot(a).active)
        t.send(a,"challengeAccept",{inviteId=incoming.inviteId});assert(t.lab:snapshot(b).challenge)
        t.send(b,"challengeAccept",{inviteId=incoming.inviteId})
        local m=t.lab.sessions[1].match
        assert(m==t.lab.sessions[2].match and m.mode=="challenge" and m.phase=="Pick" and t.entered[1] and t.entered[2])
        t.send(b,"challengeAccept",{inviteId=incoming.inviteId});assert(t.lab.sequence==1 and t.lab.sessions[1].match==m)
        t.fight(a,b);assert(m.phase=="Fight")
    end)
    test("crossing challenge requires explicit recipient acceptance and never creates two matches",function()
        local t=harness();local a,b=t.player(1),t.player(2)
        t.send(a,"challenge",{targetUserId=2});t.send(b,"challenge",{targetUserId=1})
        assert(t.lab:snapshot(b).challenge.direction=="incoming" and t.lab.sequence==0)
        local id=t.lab:snapshot(b).challenge.inviteId
        t.send(b,"challengeAccept",{inviteId=id});t.send(a,"enter");t.send(b,"enter")
        assert(t.lab.sequence==1 and #t.lab.queue==0)
    end)
    test("challenge decline cancel expiry departure and stale acceptance release both players",function()
        for _,action in ipairs({"challengeDecline","challengeCancel","expire","depart"})do
            local t=harness({challengeSeconds=5});local a,b=t.player(1),t.player(2)
            t.send(a,"challenge",{targetUserId=2});local id=t.lab:snapshot(b).challenge.inviteId
            if action=="expire" then t.advance(5.1)
            elseif action=="depart" then t.lab:remove(a)
            else t.send(action=="challengeDecline" and b or a,action,{inviteId=id})end
            assert(not t.lab:snapshot(a).challenge and not t.lab:snapshot(b).challenge and not t.entered[1] and not t.entered[2])
            t.send(b,"challengeAccept",{inviteId=id});assert(t.lab.sequence==0)
            t.advance(.2);t.send(a,"enter");t.send(b,"enter");assert(t.lab.sequence==1)
        end
    end)
    test("public queue assignment cancels challenge atomically and never interrupts active match",function()
        local t=harness();local a,b,c=t.player(1),t.player(2),t.player(3)
        t.send(a,"challenge",{targetUserId=2});local id=t.lab:snapshot(b).challenge.inviteId
        t.send(a,"enter");t.send(c,"enter");local m=t.lab.sessions[1].match
        t.send(b,"challengeAccept",{inviteId=id});assert(t.lab:snapshot(b).active==false and t.lab.sessions[1].match==m)
        t.send(b,"challenge",{targetUserId=1});assert(t.lab:snapshot(b).challenge==nil)
        t.send(b,"challenge",{targetUserId=2});assert(t.lab:snapshot(b).challenge==nil)
        assert(m==t.lab.sessions[3].match and t.lab.sequence==1)
    end)
    test("challenge rematch decline returns both users to available hangar controls",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b);t.finish(m,1);t.advance(2.1);t.fight(a,b);t.finish(m,1)
        t.send(a,"rematch");t.send(b,"rematchDecline")
        assert(not t.lab:snapshot(a).active and not t.lab:snapshot(b).active)
        assert(not t.entered[1] and not t.entered[2] and t.lab.matches[m.id]==nil)
        t.send(a,"challenge",{targetUserId=2});assert(t.lab:snapshot(b).challenge.direction=="incoming")
    end)
    test("stale exit cannot forfeit a new rematch",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b);t.finish(m,1);t.advance(2.1);t.fight(a,b);t.finish(m,1)
        t.send(a,"rematch");t.send(b,"rematch");local nextMatch=t.lab.sessions[1].match
        t.send(a,"exit",{matchId=m.id});assert(t.lab.sessions[1].match==nextMatch and nextMatch.phase=="Pick")
    end)
    test("server stall cannot stretch a physical round beyond35 wall-clock seconds",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b)
        local deadline=m.fightDeadline
        t.time=deadline-2.2;t.lab:step(30)
        local snapshot=t.lab:snapshot(a)
        assert(snapshot.fightDeadline==deadline and t.lab:snapshot(b).fightDeadline==deadline)
        assert(snapshot.simulation.elapsed<1 and math.ceil(snapshot.fightDeadline-snapshot.serverTime)==3,"Stale simulation obscured the authoritative deadline")
        m.simulation.fighters[1].armor=1;m.simulation.fighters[2].armor=2
        t.time=m.fightDeadline+.1;t.lab:step(35)
        assert(m.phase=="RoundOver" and m.roundResult.winner==2 and m.simulation.reason=="timeout" and m.simulation.elapsed==35)
        assert(m.fightSeconds==35 and m.completedRounds==1)
    end)
    test("shutdown aborts active matches clears reservations and preserves prior terminal results",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b);t.finish(m,1);t.advance(2.1)
        local c=t.player(3);t.send(c,"enter")
        t.lab:shutdown()
        assert(next(t.lab.sessions)==nil and next(t.lab.matches)==nil and #t.lab.queue==0)
        assert(not t.entered[1] and not t.entered[2] and not t.entered[3])
        assert(#t.terminal==2 and t.terminal[1].result.reason=="shutdown" and t.terminal[1].result.winner==0)
        t.lab:remove(a);t.lab:remove(b);assert(#t.terminal==2)
    end)
    test("a first match is guided: no queue, a dealt first round, then small hands",function()
        local first={[1]=true}
        local t=harness({publicDraft=true,firstMatch=function(p)return first[p.UserId]==true end})
        local a=t.player(1);t.send(a,"enter");local m=t.lab.sessions[1].match;local s=t.lab:snapshot(a)
        assert(m and #t.lab.queue==0 and s.phase=="Countdown" and s.guided and s.simulatedOpponent and s.mode=="practice")
        assert(s.settings[1].offenceId=="Meteor" and s.settings[2].offenceId=="Firework" and s.stage==1)
        t.advance(4.9);assert(m.phase=="Countdown");t.advance(.2);assert(m.phase=="Fight")
        t.finish(m,0,"timeout");t.advance(2.1);assert(m.phase=="Countdown" and m.stage==1,"A drawn first round asked for a pick")
        t.advance(2.5);t.finish(m,2);t.advance(2.1);s=t.lab:snapshot(a)
        assert(s.phase=="Pick" and s.slot=="wild" and table.concat(s.offer,",")=="SpringBumper,Afterburner")
        assert(s.locked[2] and s.pickDeadline-s.serverTime>39)
        t.send(a,"lock",{slot="wild",skillId="Magnet"});assert(not t.lab:snapshot(a).locked[1],"A card outside the guided hand was accepted")
        t.send(a,"lock",{slot="wild",skillId="Afterburner"});assert(m.phase=="Countdown" and m.settings[1].wildIds[1]=="Afterburner")
        t.advance(2.5);t.finish(m,1);t.advance(2.1);s=t.lab:snapshot(a)
        assert(#s.offer==3 and s.offer[1]=="SpringBumper" and s.offer[3]=="Magnet","The second guided hand was not three unused cards")
        t.lock(a);t.advance(2.5);t.finish(m,1)
        assert(m.phase=="MatchOver" and t.terminal[1].result.mode=="practice" and t.terminal[1].result.outcome=="win")
        local accepted;for _,e in ipairs(t.events)do if e.name=="match_accepted" then accepted=e end end
        assert(accepted.data.guided==true and accepted.data.mode=="practice")
        first[1]=nil;t.send(a,"rematch");local again=t.lab.sessions[1].match;s=t.lab:snapshot(a)
        assert(again~=m and s.phase=="Pick" and not s.guided and s.mode=="public" and #s.offer==4,"The rematch was guided again")
    end)
    test("guidance never applies to challenges, returning pilots or test rosters",function()
        local t=harness({publicDraft=true,firstMatch=function(p)return p.UserId==1 end})
        local a,b=t.player(1),t.player(2);t.send(b,"enter");assert(t.lab:snapshot(b).phase=="Searching")
        t.send(a,"enter");assert(t.lab:snapshot(a).guided and t.lab:snapshot(b).phase=="Searching","A first-timer took a queued human")
        t.send(a,"exit");t.send(b,"exit");t.advance(4)
        t.send(a,"challenge",{targetUserId=2});t.send(b,"challengeAccept",{inviteId=t.lab:snapshot(b).challenge.inviteId})
        local s=t.lab:snapshot(a);assert(s.phase=="Pick" and not s.guided and s.mode=="challenge")
        local e=harness({publicDraft=true,allowExperimental=true,firstMatch=function()return true end,
            resolveRoster=function()return {version="x",offences={"Meteor","Firework"},wilds={"Afterburner","Magnet"}}end})
        local c=e.player(1);e.send(c,"enter");assert(e.lab:snapshot(c).phase=="Searching")
    end)
    return "BattleLab: "..count.." orchestration cases passed"
end
