-- Pure command/presentation contract checks. Native Studio client supplies the module.
return function(Client,Skills)
    local passed=0
    local function test(name,callback)
        local commands={}
        local ui=setmetatable({skills=Skills,audio={ui=function() end},data={active=true,phase="Pick",matchId=10,stage=1,
            slots=0,offerRevision=1,offer={offences={"Boulder","Cyclone","Pogo"},wilds={"Turbo","Bumper","Claws"}},
            draft={wildIds={}},locked={false,false}}},Client)
        function ui:send(kind,payload) commands[#commands+1]={kind=kind,payload=payload} end
        local ok,problem=pcall(callback,ui,commands);assert(ok,name..": "..tostring(problem));passed=passed+1
    end
    test("ordinary selection sends only the local offered skill, never rival settings",function(ui,commands)
        ui:choose("Bolt");assert(#commands==0,"Off-offer choice sent")
        ui:choose("Turbo");assert(#commands==0,"An upgrade filled the top slot")
        ui:fight();assert(#commands==0,"An empty loadout locked")
        ui:choose("Boulder");ui:fight()
        assert(#commands==2 and commands[1].kind=="pick" and commands[2].kind=="lock")
        assert(commands[1].payload.skillId=="Boulder" and commands[1].payload.slot=="offence")
        assert(commands[2].payload.offenceId=="Boulder" and #commands[2].payload.wildIds==0,"Lock omitted the visible loadout")
        assert(commands[1].payload.settings==nil and commands[2].payload.settings==nil,"Client supplied builds")
    end)
    test("locked or inactive drafts cannot send new picks",function(ui,commands)
        ui.data.locked[1]=true;ui:choose("Boulder");ui:fight();ui:focusSlot(0);assert(#commands==0)
        ui.data.locked[1]=false;ui.data.phase="Fight";ui:choose("Boulder");assert(#commands==0)
    end)
    test("a later pick opens on the new slot and keeps the top that fought",function(ui,commands)
        ui.data.stage=2;ui.data.slots=1;ui.data.draft={offenceId="Boulder",wildIds={}}
        local draft=ui:loadout()
        assert(draft.offenceId=="Boulder" and ui.focus==1,"The pick did not open on the empty upgrade slot")
        ui:fight();assert(#commands==0,"A build with an empty slot locked")
        ui:choose("Boulder");assert(#commands==0,"A top filled an upgrade slot")
        ui:choose("Claws")
        assert(commands[1].kind=="pick" and commands[1].payload.slot=="wild" and commands[1].payload.index==1 and commands[1].payload.skillId=="Claws")
        ui:choose("Bumper");assert(#commands==2 and ui.draft.wildIds[1]=="Bumper","A second tap did not swap the card")
        ui:focusSlot(2);assert(ui.focus==1,"A slot that is not open took focus")
        ui:focusSlot(0);assert(ui.focus==0);ui:choose("Pogo");ui:choose("Pogo")
        assert(#commands==3 and commands[3].payload.slot=="offence","The top was not swapped once")
        ui:fight()
        local lock=commands[4].payload
        assert(commands[4].kind=="lock" and lock.offenceId=="Pogo" and #lock.wildIds==1 and lock.wildIds[1]=="Bumper")
        assert(lock.wildIds~=ui.draft.wildIds,"The lock shared the live draft table")
    end)
    test("the third pick keeps the first upgrade and never doubles one",function(ui,commands)
        ui.data.stage=3;ui.data.slots=2;ui.data.draft={offenceId="Boulder",wildIds={"Claws"}}
        ui:loadout();assert(ui.focus==2 and ui.draftHeld==1)
        ui:choose("Claws");assert(#commands==0,"One upgrade filled both slots")
        ui:choose("Turbo");ui:focusSlot(1);ui:choose("Turbo");assert(#commands==1,"A held card swapped into the other slot")
        ui:choose("Bumper");ui:fight()
        local lock=commands[3].payload
        assert(lock.offenceId=="Boulder" and lock.wildIds[1]=="Bumper" and lock.wildIds[2]=="Turbo")
        -- A new stage starts again from the server's build, not the old draft.
        ui.data.stage=4;ui.data.draft={offenceId="Pogo",wildIds={"Claws","Turbo"}}
        assert(ui:loadout().offenceId=="Pogo" and ui.focus==0 and ui:loadoutReady())
    end)
    test("real outbox preserves explicit choice and revision while spacing queued packets",function(ui)
        local sent={};ui.send=Client.send;ui.outbox={};ui.sending=true;ui.lastSend=-math.huge
        ui.command={FireServer=function(_,payload)sent[#sent+1]={payload=payload,at=os.clock()}end}
        ui:choose("Pogo");ui:fight()
        assert(#ui.outbox==2 and #sent==0)
        -- A later snapshot cannot rewrite already queued packets. The server
        -- rejects their stale revision instead of choosing a replacement.
        ui.data.offerRevision=2;ui.sending=false;ui:send("request")
        local deadline=os.clock()+2
        while ui.sending and os.clock()<deadline do task.wait(.02) end
        assert(#sent==3 and sent[1].payload.kind=="pick" and sent[2].payload.kind=="lock")
        for index=1,2 do
            local p=sent[index].payload
            assert((index==1 and p.skillId or p.offenceId)=="Pogo" and p.offerRevision==1 and p.matchId==10 and p.stage==1)
        end
        assert(sent[2].at-sent[1].at>=.079 and sent[3].at-sent[2].at>=.079,"Outbox pacing bypassed")
    end)
    test("clock follows server deadlines even when simulation time is stale",function(ui)
        ui.data.phase="Fight";ui.data.fightDeadline=135;ui.data.matchDeadline=340
        ui.data.simulation={elapsed=1}
        assert(ui:clockSeconds(132.2)==3,"Stale simulation extended the visible round")
        assert(ui:clockSeconds(135)==0 and ui:clockSeconds(139)==0,"Expired timer was not clamped")
        ui.data.matchDeadline=133
        assert(ui:clockSeconds(132.2)==1,"Match hard cap was hidden by the round timer")
        ui.data.phase="Pick";ui.data.pickDeadline=142
        assert(ui:clockSeconds(132.2)==10,"Pick timer stopped using its own deadline")
    end)
    test("rematch is mutual and not repeated while waiting",function(ui,commands)
        ui.data.phase="MatchOver";ui:rematch();assert(#commands==1 and commands[1].kind=="rematch")
        ui.data.rematchVotes={true,false};ui:rematch();assert(#commands==1)
        ui.data.rematchVotes={false,false};ui.data.rivalGone=true;ui:rematch();assert(#commands==1)
    end)
    test("round facts preserve authoritative strings with bounded fallbacks",function(ui)
        assert(ui:factText({facts={"Your Boulder knocked the rival off the ring."}})=="Your Boulder knocked the rival off the ring.")
        assert(string.find(ui:factText({reason="timeout",winner=0}),"nearer the middle",1,true))
        assert(string.find(ui:factText({reason="ringout",winner=1}),"off the ring",1,true))
        assert(string.find(ui:factText({reason="round_cap"}),"Five rounds",1,true))
        assert(string.find(ui:factText({reason="disconnect"}),"left",1,true))
    end)
    test("starter claim and goal purchase use current server economy without inventing ownership",function(ui)
        local sent={};ui.progressCommand={FireServer=function(_,payload)sent[#sent+1]=payload end}
        ui.data.phase="MatchOver";ui.data.economy={canShop=true,credits=250,starterChoices={"rookieblue","rookiecoral"},
            progression={starterAvailable=true},goal={id="aurora",price=250,owned=false},equippedTrail="classic"}
        ui:claimStarter("Copycat");assert(#sent==0)
        ui:claimStarter("rookieblue");assert(#sent==1 and sent[1].kind=="claimStarter")
        assert(ui.data.economy.equippedTrail=="classic","Client guessed claim success")
        ui:goalActionRequested();assert(#sent==1,"Double request while pending")
        ui.cosmeticPending=nil;ui:goalActionRequested();assert(#sent==2 and sent[2].kind=="buyCosmetic")
        ui.cosmeticPending=nil;ui.data.economy.goal.owned=true;ui:goalActionRequested()
        assert(#sent==3 and sent[3].kind=="equipCosmetic")
        ui.cosmeticPending=nil;ui.data.phase="Fight";ui:goalActionRequested();assert(#sent==3,"Mid-fight equip sent")
    end)
    test("reward shown reports only visible terminal rewards once per match",function(ui,commands)
        ui.result={Visible=true};ui.data.phase="RoundOver";ui.data.reward={coins=50}
        ui:reportRewardShown(ui.data);assert(#commands==0,"Round reward reported")
        ui.data.phase="MatchOver";ui.data.reward=nil
        ui:reportRewardShown(ui.data);assert(#commands==0,"Missing reward reported")
        ui.data.reward={coins=50};ui.result.Visible=false
        ui:reportRewardShown(ui.data);assert(#commands==0,"Hidden result reported")
        ui.result.Visible=true;ui:reportRewardShown(ui.data);ui:reportRewardShown(ui.data)
        assert(#commands==1 and commands[1].kind=="rewardShown","Reward summary was not deduplicated")
        ui.data.matchId=11;ui:reportRewardShown(ui.data)
        assert(#commands==2,"New match reward was not reported")
        ui.data.matchId=10;ui:reportRewardShown(ui.data);assert(#commands==2,"Old reward retransmission repeated")
    end)
    test("first-match coaching follows the snapshot and stays silent otherwise",function(ui)
        local data={phase="Countdown",settings={{offenceId="Boulder",wildIds={}},{offenceId="Bolt",wildIds={}}},
            simulation={pressure=0,fighters={{},{}}}}
        assert(ui:coachText(data)==nil,"A normal match was coached")
        data.guided=true;assert(string.find(ui:coachText(data),"by itself",1,true))
        data.phase="Fight";assert(string.find(ui:coachText(data),"Boulder",1,true) and string.find(ui:coachText(data),"left",1,true))
        data.simulation.pressure=0.2;assert(string.find(ui:coachText(data),"shrinking",1,true))
        data.settings[1].wildIds={"Bumper"};assert(string.find(ui:coachText(data),"Spring Bumper: FIRST HIT ON YOU",1,true))
        data.settings[1].wildIds={"Bumper","Turbo"};assert(string.find(ui:coachText(data),"Turbo",1,true))
        for _,phase in ipairs({"Pick","RoundOver","MatchOver","Searching"}) do data.phase=phase;assert(ui:coachText(data)==nil,phase.." was coached") end
    end)
    test("the wall of powers counts what was met and keeps unmet cards secret",function(ui)
        local count,total=ui:found({Boulder=true,Jetpack=true,Nope=true,Meteor=true,Heavy=false})
        assert(count==2 and total==#Skills.all(),"Found count is wrong")
        assert(select(1,ui:found(nil))==0)
        local known=ui:powerLine("Jetpack",{Jetpack=true})
        assert(string.find(known,"JETPACK",1,true) and string.find(known,Skills.get("Jetpack").promise,1,true))
        local secret=ui:powerLine("Pogo",{Jetpack=true})
        assert(string.find(secret,"???",1,true) and string.find(secret,Skills.get("Pogo").teaser,1,true))
        assert(not string.find(string.upper(secret),"POGO",1,true) and not string.find(secret,"shockwave",1,true),"An unmet card gave itself away")
        assert(string.find(ui:powerLine(nil,{}),"Tap a tile",1,true) and string.find(ui:powerLine("Nope",{}),"Tap a tile",1,true))
    end)
    return string.format("BattleClient: %d command and feedback tests passed",passed)
end
