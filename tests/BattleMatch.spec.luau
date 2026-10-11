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
        -- These cases use a ten-second pick; the public clock is checked below.
        if not options.publicDraft then t.lab.PICK_SECONDS=10 end
        function t.player(id)
            local p={UserId=id,Name="Pilot"..id,DisplayName="Pilot"..id}
            function p:GetAttribute(key)if key=="SkyboundColor"then return id end return nil end
            t.players[id]=p;return p
        end
        function t.send(p,kind,extra)
            local s=t.lab:snapshot(p);local payload=extra or {}
            payload.kind=kind;if payload.matchId==nil then payload.matchId=s.matchId end;if payload.stage==nil then payload.stage=s.stage end
            if payload.offerRevision==nil then payload.offerRevision=s.offerRevision end
            -- A friendly lock sends the draft as it stands, with any gap filled
            -- by the first offered card that is not already on the plane.
            if kind=="lock" and s.draft and payload.offenceId==nil and payload.wildIds==nil then
                payload.offenceId=s.draft.offenceId or s.offer.offences[1];payload.wildIds={}
                for _,id in ipairs(s.draft.wildIds)do payload.wildIds[#payload.wildIds+1]=id end
                for _,id in ipairs(s.offer.wilds)do
                    if #payload.wildIds<s.slots and not table.find(payload.wildIds,id)then payload.wildIds[#payload.wildIds+1]=id end
                end
            end
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
            t.send(p,"lock")
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
        assert(s.slots==0 and s.draft.offenceId==nil and #s.offer.offences==4)
    end)
    test("offers and drafts stay private until simultaneous reveal",function()
        local t=harness();local a,b,m=t.pair();local sa=t.lab:snapshot(a);local sb=t.lab:snapshot(b)
        assert(#sa.offer.offences==4 and #sb.offer.offences==4 and sa.offers==nil and sa.drafts==nil and sa.settings[2].offenceId==nil)
        t.send(a,"pick",{slot="offence",skillId=sa.offer.offences[2]});assert(t.lab:snapshot(a).draft.offenceId==sa.offer.offences[2])
        t.send(a,"lock")
        sb=t.lab:snapshot(b);assert(sb.settings[2].offenceId==nil and sb.draft.offenceId==nil and sb.locked[2])
        t.lock(b);sa=t.lab:snapshot(a);sb=t.lab:snapshot(b)
        assert(sa.phase=="Countdown" and sa.draft==nil and sa.settings[1].offenceId==sb.settings[2].offenceId)
        assert(sa.settings[1].offenceId==sa.offer.offences[2] or sa.settings[1].offenceId=="Firework")
        assert(sa.settings[1].offenceId==sa.simulation.fighters[1].settings.offenceId)
        assert(sb.players[1].userId==2 and sb.players[2].userId==1)
    end)
    test("reject inactive wrong-kind wrong-slot cross-player stale and wrong-phase commands",function()
        local t=harness();local a,b,m=t.pair();local s=t.lab:snapshot(a);local first=s.offer.offences[1]
        for _,extra in ipairs({{slot="offence",skillId="Copycat"},{slot="offence",skillId="Afterburner"},
            {slot="wild",index=1,skillId="Afterburner"},{slot="wild",skillId=first},
            {slot="offence",skillId=first,side=2},{slot="offence",skillId=first,userId=2},
            {slot="offence",skillId=first,matchId=999},{slot="offence",skillId=first,stage=2}})do
            t.advance(.1);t.send(a,"pick",extra);assert(t.lab:snapshot(a).draft.offenceId==nil and #m.drafts[1].wildIds==0)
        end
        t.lock(a);local chosen=m.drafts[1].offenceId;t.advance(.1);t.send(a,"pick",{slot="offence",skillId=s.offer.offences[3]});assert(m.drafts[1].offenceId==chosen)
        t.lock(b);t.advance(.1)
        t.send(a,"configure",{settings={{offenceId="Copycat"},{offenceId="Copycat"}}});assert(m.settings[1].offenceId==chosen)
        t.send(a,"pick",{slot="offence",skillId=s.offer.offences[3]});assert(m.settings[1].offenceId==chosen and m.phase=="Countdown")
    end)
    test("the public draft shows the whole roster in order before every round",function()
        local t=harness({publicDraft=true});local a,b,m=t.pair();local s=t.lab:snapshot(a)
        assert(table.concat(s.offer.offences,",")=="Meteor,Firework,MachineGun,Pinball" and #s.offer.wilds==5 and s.slots==0)
        t.advance(19.9);assert(m.phase=="Pick");t.advance(.2);assert(m.phase~="Pick","The 20-second deadline did not lock")
        t.advance(2.5);assert(m.phase=="Fight");t.finish(m,1);t.advance(3.6);s=t.lab:snapshot(a)
        assert(s.phase=="Pick" and s.slots==1 and #s.offer.wilds==5 and s.offer.wilds[1]=="Afterburner","Wild pick hid part of the roster")
        assert(#s.offer.offences==4 and s.draft.offenceId=="Meteor" and #s.draft.wildIds==0,"The second pick did not start from the plane that flew")
    end)
    test("bare partial and stale locks never fill a gap",function()
        local t=harness();local a,b,m=t.pair()
        -- Raw commands intentionally bypass the friendly packet helper.
        for _,packet in ipairs({{},{offenceId="Meteor"},{offenceId="Copycat",wildIds={}},{wildIds={}},
            {offenceId="Meteor",wildIds={"Afterburner"}},{offenceId="Meteor",wildIds="Afterburner"},
            {offenceId="Meteor",wildIds={},offerRevision=2},{offenceId="Meteor",wildIds={},stage=2}})do
            packet.kind="lock";packet.matchId=m.id;packet.stage=packet.stage or 1;packet.offerRevision=packet.offerRevision or 1
            t.advance(.1);t.lab:command(a,packet)
            assert(not m.locked[1] and m.drafts[1].offenceId==nil,"A broken lock was accepted")
        end
        t.advance(.2)
        t.send(a,"lock",{offenceId="Firework",wildIds={}});t.lock(b)
        assert(m.phase=="Countdown" and m.settings[1].offenceId=="Firework","Explicit loadout not preserved")
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
    test("timeout keeps a tapped card fills gaps with the first offer and ignores late picks",function()
        local t=harness();local a,b,m=t.pair();local s=t.lab:snapshot(a)
        t.send(a,"pick",{slot="offence",skillId=s.offer.offences[2]});t.advance(10.1)
        assert(m.phase=="Countdown" and m.settings[1].offenceId==s.offer.offences[2] and m.settings[2].offenceId==s.offer.offences[1])
        t.send(a,"pick",{slot="offence",skillId=s.offer.offences[3]});assert(m.settings[1].offenceId==s.offer.offences[2])
        t.advance(2.5);t.finish(m,1);t.advance(2.1);assert(m.phase=="Pick" and m.stage==2)
        t.advance(10.1);assert(m.phase=="Countdown" and m.settings[1].offenceId==s.offer.offences[2])
        assert(#m.settings[1].wildIds==1 and m.settings[1].wildIds[1]==m.roster.wilds[1],"The deadline did not add the first wild card")
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
    test("2-1 keeps the plane between rounds while any slot can be swapped",function()
        local t=harness();local a,b,m=t.pair();t.fight(a,b);t.finish(m,1);t.advance(2.1);t.fight(a,b);t.finish(m,2);t.advance(2.1)
        assert(m.stage==3 and m.score[1]==1 and m.score[2]==1)
        local attack,first=m.settings[1].offenceId,m.settings[1].wildIds[1]
        local s=t.lab:snapshot(a)
        assert(s.slots==2 and s.draft.offenceId==attack and #s.draft.wildIds==1 and s.draft.wildIds[1]==first,"The plane was not carried into the pick")
        assert(#s.offer.wilds==5 and #s.offer.offences==4)
        t.send(a,"pick",{stage=2,slot="wild",index=2,skillId="Magnet"});assert(#m.drafts[1].wildIds==1)
        t.send(a,"pick",{slot="wild",index=2,skillId=first});assert(#m.drafts[1].wildIds==1,"One wild card filled two slots")
        t.send(a,"pick",{slot="wild",index=3,skillId="Magnet"});t.send(a,"pick",{slot="wild",index=0,skillId="Magnet"})
        t.send(a,"pick",{slot="wild",index=1.5,skillId="Magnet"});assert(#m.drafts[1].wildIds==1 and m.drafts[1].wildIds[1]==first)
        t.advance(.5);t.send(a,"lock",{offenceId=attack,wildIds={first,first}});assert(not m.locked[1],"A doubled wild card locked")
        t.send(a,"lock",{offenceId=attack,wildIds={first}});assert(not m.locked[1],"A short loadout locked")
        -- Swap the attack and the old wild card, then add a new one.
        local swap=attack=="Pinball" and "Meteor" or "Pinball"
        local one=first=="Magnet" and "FizzyFuel" or "Magnet";local two=first=="SecondWind" and "FizzyFuel" or "SecondWind"
        t.advance(.5);t.send(a,"pick",{slot="offence",skillId=swap});t.send(a,"pick",{slot="wild",index=1,skillId=one})
        t.send(a,"pick",{slot="wild",index=2,skillId=two});s=t.lab:snapshot(a)
        assert(s.draft.offenceId==swap and s.draft.wildIds[1]==one and s.draft.wildIds[2]==two)
        assert(m.settings[1].offenceId==attack,"A draft changed the plane before the reveal")
        t.fight(a,b)
        assert(m.settings[1].offenceId==swap and m.settings[1].wildIds[1]==one and m.settings[1].wildIds[2]==two and #m.settings[1].wildIds==2)
        assert(#m.settings[2].wildIds==2 and m.settings[2].wildIds[1]~=m.settings[2].wildIds[2])
        t.finish(m,2);assert(m.phase=="MatchOver" and m.score[2]==2)
    end)
    test("a bot keeps its plane and adds one wild card each round",function()
        local t=harness();local a=t.player(1);t.send(a,"enter");t.advance(8.1)
        local m=t.lab.sessions[1].match;t.fight(a);local attack=m.settings[2].offenceId
        t.finish(m,1);t.advance(2.1);t.fight(a);local first=m.settings[2].wildIds[1]
        assert(m.settings[2].offenceId==attack and #m.settings[2].wildIds==1)
        t.finish(m,2);t.advance(2.1);t.fight(a)
        assert(m.settings[2].offenceId==attack and m.settings[2].wildIds[1]==first and #m.settings[2].wildIds==2 and m.settings[2].wildIds[2]~=first)
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
        assert(nextMatch.id~=m.id and nextMatch.phase=="Pick" and nextMatch.settings[1].offenceId==nil and nextMatch.drafts[1].offenceId==nil)
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
        s.offer.offences[1]="Copycat";s.draft.offenceId="Copycat";s.draft.wildIds[1]="Copycat";s.settings[1].wildIds[1]="Copycat"
        assert(m.offers[1].offences[1]~="Copycat" and m.drafts[1].offenceId==nil and #m.drafts[1].wildIds==0 and #m.settings[1].wildIds==0)
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
        assert(s.phase=="Pick" and s.slots==1 and table.concat(s.offer.wilds,",")=="SpringBumper,Afterburner")
        assert(table.concat(s.offer.offences,",")=="Meteor,Firework" and s.draft.offenceId=="Meteor" and #s.draft.wildIds==0)
        assert(s.locked[2] and s.pickDeadline-s.serverTime>39)
        t.send(a,"lock",{offenceId="Meteor",wildIds={"Magnet"}});assert(not t.lab:snapshot(a).locked[1],"A card outside the guided hand was accepted")
        t.send(a,"lock",{offenceId="Pinball",wildIds={"Afterburner"}});assert(not t.lab:snapshot(a).locked[1],"An attack outside the guided hand was accepted")
        t.send(a,"lock",{offenceId="Meteor",wildIds={"Afterburner"}});assert(m.phase=="Countdown" and m.settings[1].wildIds[1]=="Afterburner")
        assert(m.settings[2].offenceId=="Firework" and #m.settings[2].wildIds==1)
        t.advance(2.5);t.finish(m,1);t.advance(2.1);s=t.lab:snapshot(a)
        assert(table.concat(s.offer.wilds,",")=="SpringBumper,Afterburner,FizzyFuel" and s.slots==2 and s.draft.wildIds[1]=="Afterburner","The second guided hand was wrong")
        t.lock(a);assert(table.concat(m.settings[1].wildIds,",")=="Afterburner,SpringBumper")
        t.advance(2.5);t.finish(m,1)
        assert(m.phase=="MatchOver" and t.terminal[1].result.mode=="practice" and t.terminal[1].result.outcome=="win")
        local accepted;for _,e in ipairs(t.events)do if e.name=="match_accepted" then accepted=e end end
        assert(accepted.data.guided==true and accepted.data.mode=="practice")
        first[1]=nil;t.send(a,"rematch");local again=t.lab.sessions[1].match;s=t.lab:snapshot(a)
        assert(again~=m and s.phase=="Pick" and not s.guided and s.mode=="public" and #s.offer.offences==4,"The rematch was guided again")
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
