-- Cursor, mixing and lifecycle checks without loading or playing real sounds.
return function(Audio)
    local passed=0
    local function test(name,body)
        local ok,problem=pcall(body)
        assert(ok,name..": "..tostring(problem)); passed=passed+1
    end
    local function fixture()
        local calls,attributes={},{}
        local folder={Parent=true,destroyed=0}
        function folder:SetAttribute(key,value) attributes[key]=value end
        function folder:Destroy() self.destroyed=self.destroyed+1; self.Parent=nil end
        local mix=setmetatable({voices={},nextVoice={},tweens={},lastAt={},lastSerial=0,
            key=nil,started=false,muted=false,destroyed=false,played=0,
            folder=folder,group={Volume=0.7}},Audio)
        mix._voice=function(_,name,volume,pitch,duration,finishPitch,swell)
            calls[#calls+1]={name=name,volume=volume,pitch=pitch,duration=duration,finishPitch=finishPitch,swell=swell}
        end
        return mix,calls,attributes
    end
    local function event(serial,kind,at,actor)
        return {serial=serial,kind=kind,at=at,actor=actor or 1,target=2}
    end
    local function snapshot(phase,elapsed,events,roundId)
        return {active=true,phase=phase,roundId=roundId or 1,
            simulation={elapsed=elapsed,events=events or {},fighters={{id=1,offenceId="Meteor",armor=3},{id=2,offenceId="Firework",armor=3}}}}
    end
    local function results(roundId,armorA,armorB,reason)
        local s=snapshot("Results",5,{},roundId)
        s.simulation.finished=true; s.simulation.reason=reason or "knockout"
        s.simulation.fighters[1].armor=armorA; s.simulation.fighters[2].armor=armorB
        return s
    end

    test("setup and countdown defer launch cues until Fight",function()
        local mix,calls=fixture()
        local launches={event(1,"launch",0),event(2,"launch",0,2)}
        mix:update(snapshot("Configure",0,launches))
        mix:update(snapshot("Countdown",0,launches)); assert(#calls==0)
        mix:update(snapshot("Fight",0.05,launches)); assert(#calls==2)
        mix:update(snapshot("Fight",0.1,launches)); assert(#calls==2)
    end)
    test("fresh events from both fighters play once across repeated snapshots",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        local s=snapshot("Fight",0.2,{event(3,"rocket",0.2),event(4,"hit",0.2,2)})
        mix:update(s); local count=#calls
        assert(count==4 and mix.lastSerial==4)
        for _=1,10 do mix:update(s) end
        assert(#calls==count)
    end)
    test("late join consumes history and only future events sound",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",12,{event(18,"rocket",11.9),event(19,"hit",12)}))
        assert(#calls==0 and mix.lastSerial==19)
        mix:update(snapshot("Fight",12.2,{event(19,"hit",12),event(20,"hit",12.2,2)}))
        assert(#calls==2 and mix.lastSerial==20)
    end)
    test("late Results entry and stale delivery do not replay the past",function()
        local mix,calls=fixture()
        mix:update(snapshot("Results",35,{event(25,"finish",35)})); assert(#calls==0)
        mix:update(snapshot("Fight",0,{},2))
        mix:update(snapshot("Fight",3,{event(2,"hit",1),event(3,"rocket",1.2)} ,2))
        assert(#calls==0 and mix.lastSerial==3)
        mix:update(snapshot("Fight",3.1,{event(4,"windup",3.1)},2)); assert(#calls==2)
    end)
    test("mute stops existing voices and consumes events without replay on unmute",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        local stopped,cancelled=0,0
        mix.voices={test={{Stop=function() stopped=stopped+1 end}}}
        mix.tweens={test={Cancel=function() cancelled=cancelled+1 end}}
        mix:setMuted(true)
        assert(stopped==1 and cancelled==1 and next(mix.tweens)==nil and mix.group.Volume==0)
        local s=snapshot("Fight",0.2,{event(2,"hit",0.2)})
        mix:update(s); assert(#calls==0 and mix.lastSerial==2)
        mix:setMuted(false); mix:update(s); assert(#calls==0 and mix.group.Volume==0.7)
        mix:update(snapshot("Fight",0.4,{event(3,"hit",0.4)})); assert(#calls==2)
    end)
    test("retry resets serials and exit stops all voices",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0.05,{event(1,"launch",0)}))
        mix:update(snapshot("Configure",0,{event(1,"launch",0)},2)); assert(#calls==1)
        mix:update(snapshot("Fight",0.05,{event(1,"launch",0)},2)); assert(#calls==2)
        local stopped,cancelled=0,0
        mix.voices={test={{Stop=function() stopped=stopped+1 end}}}
        mix.tweens={test={Cancel=function() cancelled=cancelled+1 end}}
        mix:update({active=false})
        assert(stopped==1 and cancelled==1 and mix.key==nil and mix.lastSerial==0)
        mix:update({active=false}); assert(stopped==1)
    end)
    test("a delivery batch is bounded and keeps the newest finish",function()
        local mix,calls,attrs=fixture()
        mix:update(snapshot("Fight",0,{}))
        local events={}
        for i=1,12 do events[i]=event(i,"hit",1+i*0.02,i%2+1) end
        events[13]=event(13,"finish",1.28)
        local s=snapshot("Results",1.3,events); s.simulation.reason="knockout"
        mix:update(s)
        assert(mix.played<=Audio.MAX_EVENTS_PER_UPDATE and #calls<=Audio.MAX_EVENTS_PER_UPDATE*2)
        assert(attrs.LastEvent=="finish" and mix.lastSerial==13)
        local count=#calls; mix:update(s); assert(#calls==count)
    end)
    test("bumps blocks damage and modifiers have distinct mixes",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        mix:update(snapshot("Fight",0.2,{event(1,"bump",0.2)}))
        assert(#calls==1 and calls[1].name=="land" and calls[1].volume<0.1)
        local block=event(2,"blocked",0.4); block.skillId="SpringBumper"
        mix:update(snapshot("Fight",0.4,{block}))
        assert(calls[2].name=="jump" and calls[3].name=="chime")
        mix:update(snapshot("Fight",0.6,{event(3,"wake_hit",0.6)}))
        assert(calls[4].name=="land" and calls[5].name=="boom")
        local boost=event(4,"skill",0.8); boost.skillId="Afterburner"
        mix:update(snapshot("Fight",0.8,{boost}))
        assert(calls[6].name=="jump" and calls[6].finishPitch>calls[6].pitch)
        local wake=event(5,"skill",1); wake.skillId="FizzyFuel"
        mix:update(snapshot("Fight",1,{wake}))
        assert(#calls==6,"wake emission sounded like an armor hit")
    end)
    test("Meteor charge and committed dive differ from Firework arming and ignition",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        mix:update(snapshot("Fight",0.2,{event(1,"windup",0.2)}))
        assert(calls[1].name=="jump" and calls[1].swell and calls[1].finishPitch>calls[1].pitch)
        assert(calls[2].name~="boom","charge sounded like damage")
        mix:update(snapshot("Fight",0.85,{event(2,"dive",0.85)}))
        assert(calls[3].name=="jump" and calls[3].finishPitch<calls[3].pitch)
        assert(calls[4].name~="boom","committing to a dive claimed a hit")
        mix:update(snapshot("Fight",1.2,{event(3,"windup",1.2,2)}))
        assert(calls[5].name=="chime" and calls[5].pitch>calls[1].pitch)
        mix:update(snapshot("Fight",2.25,{event(4,"rocket",2.25,2)}))
        assert(calls[7].name=="jump" and calls[7].finishPitch>calls[7].pitch)
        assert(calls[8].name=="boom" and calls[8].volume<0.15)
        local count=#calls
        mix:update(snapshot("Fight",2.3,{event(2,"dive",0.85),event(4,"rocket",2.25,2)}))
        assert(#calls==count,"commit cue replayed")
    end)
    test("damage source changes the impact and aerial knockout leaves room for the landing",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        local meteor=event(1,"hit",0.2); meteor.source="meteor"
        mix:update(snapshot("Fight",0.2,{meteor}))
        local rocket=event(2,"hit",0.4); rocket.source="rocket"
        mix:update(snapshot("Fight",0.4,{rocket}))
        assert(calls[1].name=="boom" and calls[3].name=="boom")
        assert(calls[1].pitch<calls[3].pitch and calls[2].pitch<calls[4].pitch)
        local ending=snapshot("Results",0.5,{event(3,"finish",0.5)})
        ending.simulation.reason="knockout"; mix:update(ending)
        assert(calls[5].volume<calls[1].volume and calls[5].duration<calls[1].duration)
        assert(calls[6].name=="chime" and not calls[6].swell)
    end)
    test("Meteor charge follows remaining authoritative windup time",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        local charge=snapshot("Fight",0.4,{event(1,"windup",0.2)})
        charge.simulation.fighters[1].windupDuration=1.15
        mix:update(charge)
        assert(math.abs(calls[1].duration-0.95)<0.0001 and calls[1].swell)
        mix:update(charge); assert(#calls==2)
        mix:update(snapshot("Fight",1.35,{event(2,"dive",1.35)}))
        assert(#calls==4 and calls[3].finishPitch<calls[3].pitch)
        local legacy=snapshot("Fight",2,{event(3,"windup",2)})
        legacy.simulation.fighters[1].windupDuration=0/0
        mix:update(legacy)
        assert(math.abs(calls[5].duration-0.65)<0.0001,"old snapshots lost their charge fallback")
    end)
    test("release stops its own charge and Results interrupts remaining charges",function()
        local mix=fixture()
        mix:update(snapshot("Fight",0,{}))
        local stopped,cancelled={0,0},{0,0}
        local a={Stop=function() stopped[1]=stopped[1]+1 end}
        local b={Stop=function() stopped[2]=stopped[2]+1 end}
        mix.charging={[a]=1,[b]=2}
        mix.tweens={[a]={Cancel=function()cancelled[1]=cancelled[1]+1 end},
            [b]={Cancel=function()cancelled[2]=cancelled[2]+1 end}}
        mix:update(snapshot("Fight",0.2,{event(1,"dive",0.2)}))
        assert(stopped[1]==1 and stopped[2]==0 and mix.charging[b]==2)
        mix:update(results(1,1,0))
        assert(stopped[2]==1 and cancelled[1]==1 and cancelled[2]==1)
        assert(next(mix.charging)==nil and next(mix.tweens)==nil)
        mix:update(results(1,1,0)); assert(stopped[2]==1)
    end)
    test("ground crash needs a defeated plane in current Results and plays only once",function()
        local mix,calls,attrs=fixture()
        assert(not mix:playCrash(1,2))
        mix:update(snapshot("Fight",0,{}))
        assert(not mix:playCrash(1,2))
        mix:update(results(1,2,0))
        assert(not mix:playCrash(1,1),"surviving plane crashed")
        assert(not mix:playCrash(1,0) and not mix:playCrash(1,3))
        assert(mix:playCrash(1,2) and #calls==2 and attrs.LastEvent=="crash")
        assert(calls[1].name=="land" and calls[2].name=="boom" and calls[1].pitch<0.7)
        for _=1,8 do mix:update(results(1,2,0)); assert(not mix:playCrash(1,2)) end
        assert(#calls==2)
    end)
    test("a simultaneous knockout has one landing per plane",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{})); mix:update(results(1,0,0))
        assert(mix:playCrash(1,1) and mix:playCrash(1,2))
        assert(not mix:playCrash(1,1) and not mix:playCrash(1,2) and #calls==4)
    end)
    test("muted ground landings are consumed instead of replayed on unmute",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{})); mix:update(results(1,1,0))
        mix:setMuted(true); assert(not mix:playCrash(1,2))
        mix:setMuted(false); assert(not mix:playCrash(1,2) and #calls==0)
    end)
    test("restart and exit invalidate old crash callbacks but permit the next landing",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{})); mix:update(results(1,1,0))
        mix:update(snapshot("Configure",0,{},2))
        assert(not mix:playCrash(1,2) and not mix:playCrash(2,2))
        mix:update(snapshot("Fight",0,{},2)); mix:update(results(2,1,0))
        assert(not mix:playCrash(1,2) and mix:playCrash(2,2) and #calls==2)
        mix:update({active=false}); assert(not mix:playCrash(2,2))
        mix:destroy(); assert(not mix:playCrash(2,2) and #calls==2)
    end)
    test("late Results entry and delayed presentation callbacks stay silent",function()
        local mix,calls=fixture()
        mix:update(results(1,1,0)); assert(not mix:playCrash(1,2))
        mix:update(results(1,1,0)); assert(not mix:playCrash(1,2))
        mix:update(snapshot("Fight",0,{},2)); mix:update(results(2,1,0))
        mix.resultsAt=os.clock()-Audio.MAX_CRASH_AGE-1
        mix:update(results(2,1,0))
        assert(not mix:playCrash(2,2) and #calls==0,"a repeated Results snapshot refreshed stale crash eligibility")
    end)
    test("timeouts and unfinished Results cannot claim a knockout crash",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{})); mix:update(results(1,2,1,"timeout"))
        assert(not mix:playCrash(1,2))
        mix:update(results(1,1,0,"timeout")); assert(not mix:playCrash(1,2))
        local invalid=results(1,1,0); invalid.simulation.finished=false
        mix:update(invalid); assert(not mix:playCrash(1,2) and #calls==0)
    end)
    test("duplicate commit bursts are limited per actor without silencing the rival",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        mix:update(snapshot("Fight",0.2,{event(1,"dive",0.2)}))
        mix:update(snapshot("Fight",0.23,{event(2,"dive",0.23),event(3,"dive",0.23,2)}))
        assert(#calls==4 and mix.played==2 and mix.lastSerial==3)
    end)
    test("missing timestamps are supported after initialization and unknown events are consumed",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        mix:update(snapshot("Fight",0.1,{event(1,"miss",0.1),event(2,"rocket",nil)}))
        assert(#calls==2 and mix.lastSerial==2)
        mix:update(snapshot("Fight",0.2,{event(1,"hit",0.2),event(2,"rocket",nil)}))
        assert(#calls==2)
    end)
    test("destroy is idempotent and later input cannot resurrect the mix",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{})); mix:destroy(); mix:destroy()
        mix:setMuted(false); mix:update(snapshot("Fight",0.1,{event(1,"hit",0.1)}))
        assert(#calls==0 and mix.folder.destroyed==1 and next(mix.voices)==nil)
    end)
    test("new skills have distinct lightweight cues and connection ticks do not break armor",function()
        local mix,calls,attributes=fixture()
        mix:update(snapshot("Fight",0,{}))
        mix:update(snapshot("Fight",0.1,{event(1,"burst",0.1)}))
        assert(attributes.LastEvent=="burst" and #calls==1)
        mix:update(snapshot("Fight",0.2,{event(2,"tracer_hit",0.2)}))
        assert(attributes.LastEvent=="tracer_hit" and #calls==2 and calls[2].name=="chime")
        mix:update(snapshot("Fight",0.3,{event(3,"ricochet",0.3)}))
        assert(attributes.LastEvent=="ricochet")
        local magnet=event(4,"skill",0.4);magnet.skillId="Magnet"
        mix:update(snapshot("Fight",0.4,{magnet}));assert(attributes.LastEvent=="magnet")
        local wind=event(5,"skill",0.5);wind.skillId="SecondWind"
        mix:update(snapshot("Fight",0.5,{wind}));assert(attributes.LastEvent=="secondwind")
    end)
    test("RoundOver and MatchOver use result crash eligibility and reset on next Pick",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        local s=results(1,0,2);s.phase="RoundOver";mix:update(s)
        assert(mix:playCrash(1,1),"RoundOver crash was silent")
        mix:update(snapshot("Pick",0,{},2));assert(not mix:playCrash(1,1),"Old crash survived next draft")
        mix:update(snapshot("Fight",0,{},2));s=results(2,2,0);s.phase="MatchOver";mix:update(s)
        assert(mix:playCrash(2,2),"MatchOver crash was silent")
    end)
    test("quiet UI vocabulary suppresses duplicate action pulses and obeys mute",function()
        local mix,calls,attributes=fixture();local shots={}
        mix._shot=function(_,name,volume,pitch)shots[#shots+1]={name=name,volume=volume,pitch=pitch}end
        mix:ui("select");local count=#shots;local voices=#calls
        mix:ui("select");assert(#shots==count and #calls==voices,"Double helper/callback sound")
        mix:ui("confirm");assert(attributes.LastUI=="confirm")
        mix:ui("back");assert(attributes.LastUI=="back")
        mix:ui("error");assert(shots[#shots].name=="beep")
        mix:ui("purchase");assert(attributes.LastUI=="purchase")
        for _,shot in ipairs(shots)do assert(shot.volume<=0.22,"UI louder than intended")end
        mix:setMuted(true);count=#shots;voices=#calls;mix:ui("tap")
        assert(#shots==count and #calls==voices,"Mute allowed UI sound")
        mix:setMuted(false);mix:ui("tap");assert(#shots==count+1,"Unmute did not restore tap")
    end)
    return tostring(passed).." battle-audio tests passed"
end
