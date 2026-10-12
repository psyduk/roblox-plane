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
    local function event(serial,kind,at,actor,extra)
        local entry={serial=serial,kind=kind,at=at,actor=actor or 1,target=actor==2 and 1 or 2}
        for key,value in pairs(extra or {}) do entry[key]=value end
        return entry
    end
    -- A light touch and one that throws a top across the ring.
    local function bump(serial,at,actor) return event(serial,"clash",at,actor,{power=14,source="smash"}) end
    local function smash(serial,at,actor) return event(serial,"clash",at,actor,{power=60,source="smash"}) end
    local function snapshot(phase,elapsed,events,roundId)
        return {active=true,phase=phase,roundId=roundId or 1,
            simulation={elapsed=elapsed,events=events or {},maxTime=40,fighters={{id=1,offenceId="Boulder"},{id=2,offenceId="Bolt"}}}}
    end
    -- A finished round. `out` lists which tops went over the edge.
    local function results(roundId,outA,outB,reason)
        local s=snapshot("Results",5,{},roundId)
        s.simulation.finished=true; s.simulation.reason=reason or "ringout"
        s.simulation.fighters[1].out=outA==true; s.simulation.fighters[2].out=outB==true
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
    test("fresh events from both tops play once across repeated snapshots",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        local s=snapshot("Fight",0.2,{bump(3,0.2),smash(4,0.2,2)})
        mix:update(s); local count=#calls
        assert(count==2 and mix.lastSerial==4)
        for _=1,10 do mix:update(s) end
        assert(#calls==count)
    end)
    test("late join consumes history and only future events sound",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",12,{bump(18,11.9),smash(19,12)}))
        assert(#calls==0 and mix.lastSerial==19)
        mix:update(snapshot("Fight",12.2,{smash(19,12),smash(20,12.2,2)}))
        assert(#calls==1 and mix.lastSerial==20)
    end)
    test("late Results entry and stale delivery do not replay the past",function()
        local mix,calls=fixture()
        mix:update(snapshot("Results",40,{event(25,"finish",40)})); assert(#calls==0)
        mix:update(snapshot("Fight",0,{},2))
        mix:update(snapshot("Fight",3,{smash(2,1),bump(3,1.2)},2))
        assert(#calls==0 and mix.lastSerial==3)
        mix:update(snapshot("Fight",3.1,{event(4,"wall",3.1,1,{power=20})},2)); assert(#calls==1)
    end)
    test("mute stops existing voices and consumes events without replay on unmute",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        local stopped,cancelled=0,0
        mix.voices={test={{Stop=function() stopped=stopped+1 end}}}
        mix.tweens={test={Cancel=function() cancelled=cancelled+1 end}}
        mix:setMuted(true)
        assert(stopped==1 and cancelled==1 and next(mix.tweens)==nil and mix.group.Volume==0)
        local s=snapshot("Fight",0.2,{smash(2,0.2)})
        mix:update(s); assert(#calls==0 and mix.lastSerial==2)
        mix:setMuted(false); mix:update(s); assert(#calls==0 and mix.group.Volume==0.7)
        mix:update(snapshot("Fight",0.4,{smash(3,0.4)})); assert(#calls==1)
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
        for i=1,12 do events[i]=smash(i,1+i*0.02,i%2+1) end
        events[13]=event(13,"finish",1.28)
        local s=snapshot("Results",1.3,events); s.simulation.reason="ringout"
        mix:update(s)
        assert(mix.played<=Audio.MAX_EVENTS_PER_UPDATE and #calls<=Audio.MAX_EVENTS_PER_UPDATE*2)
        assert(attrs.LastEvent=="finish" and mix.lastSerial==13)
        local count=#calls; mix:update(s); assert(#calls==count)
    end)
    test("a bump, a grind, a big hit and the wall each sound different",function()
        local mix,calls,attrs=fixture()
        mix:update(snapshot("Fight",0,{}))
        mix:update(snapshot("Fight",0.2,{bump(1,0.2)}))
        assert(#calls==1 and calls[1].name=="land" and calls[1].volume<0.2 and attrs.LastEvent=="bump")
        mix:update(snapshot("Fight",0.5,{smash(2,0.5)}))
        assert(calls[2].name=="boom" and attrs.LastEvent=="big_hit","A throw sounded like a bump")
        mix:update(snapshot("Fight",0.8,{event(3,"clash",0.8,1,{power=14,source="grind"})}))
        assert(calls[3].name=="land" and calls[3].pitch<calls[1].pitch and attrs.LastEvent=="grind","Opposite spins did not grind")
        mix:update(snapshot("Fight",1.1,{event(4,"wall",1.1,1,{power=25})}))
        assert(calls[4].name=="land" and attrs.LastEvent=="wall")
        mix:update(snapshot("Fight",1.4,{event(5,"close",1.4)}))
        assert(calls[5].name=="chime" and attrs.LastEvent=="close")
        mix:update(snapshot("Fight",1.7,{event(6,"blocked",1.7,2,{skillId="Other"}),event(7,"miss",1.7)}))
        assert(#calls==5 and mix.lastSerial==7,"An unknown event made a sound or was not consumed")
    end)
    test("a harder bump is louder, and bumps cannot machine-gun",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        mix:update(snapshot("Fight",0.2,{event(1,"clash",0.2,1,{power=6,source="smash"})}))
        mix:update(snapshot("Fight",0.6,{event(2,"clash",0.6,1,{power=30,source="smash"})}))
        assert(#calls==2 and calls[2].volume>calls[1].volume)
        mix:update(snapshot("Fight",0.65,{event(3,"clash",0.65,1,{power=30,source="smash"}),event(4,"clash",0.65,2,{power=30,source="smash"})}))
        assert(#calls==3 and mix.lastSerial==4,"A repeat bump from the same top was not limited, or the rival was silenced")
    end)
    test("running out of spin has its own ending, and a win on the clock gets the whistle",function()
        local mix,calls,attrs=fixture();local shots={}
        mix._shot=function(_,name)shots[#shots+1]=name end
        mix:update(snapshot("Fight",0,{}))
        local ending=snapshot("Results",0.5,{event(1,"spinout",0.5,1),event(2,"finish",0.5)})
        ending.simulation.reason="spinout"; ending.simulation.finished=true
        mix:update(ending)
        assert(calls[1].name=="chime" and calls[1].finishPitch<calls[1].pitch,"A stopping top does not wind down")
        assert(attrs.LastEvent=="finish" and not table.find(shots,"whistle"),"A spin-out was whistled like a timeout")
        mix:update(snapshot("Fight",0,{},2))
        local timed=snapshot("Results",0.5,{event(1,"finish",0.5)},2)
        timed.simulation.reason="timeout"; timed.simulation.finished=true
        mix:update(timed)
        assert(table.find(shots,"whistle"),"A win on the clock had no whistle")
    end)
    test("Results interrupts any sound still swelling",function()
        local mix=fixture()
        mix:update(snapshot("Fight",0,{}))
        local stopped,cancelled={0,0},{0,0}
        local a={Stop=function() stopped[1]=stopped[1]+1 end}
        local b={Stop=function() stopped[2]=stopped[2]+1 end}
        mix.charging={[a]=1,[b]=2}
        mix.tweens={[a]={Cancel=function()cancelled[1]=cancelled[1]+1 end},
            [b]={Cancel=function()cancelled[2]=cancelled[2]+1 end}}
        mix:update(results(1,false,true))
        assert(stopped[1]==1 and stopped[2]==1 and cancelled[1]==1 and cancelled[2]==1)
        assert(next(mix.charging)==nil and next(mix.tweens)==nil)
        mix:update(results(1,false,true)); assert(stopped[2]==1)
    end)
    test("the fall needs a top that went over the edge in current Results and plays only once",function()
        local mix,calls,attrs=fixture()
        assert(not mix:playCrash(1,2))
        mix:update(snapshot("Fight",0,{}))
        assert(not mix:playCrash(1,2))
        mix:update(results(1,false,true))
        assert(not mix:playCrash(1,1),"The top still on the ring fell")
        assert(not mix:playCrash(1,0) and not mix:playCrash(1,3))
        assert(mix:playCrash(1,2) and #calls==1 and attrs.LastEvent=="crash")
        assert(calls[1].name=="chime" and calls[1].finishPitch<calls[1].pitch,"The fall does not drop in pitch")
        for _=1,8 do mix:update(results(1,false,true)); assert(not mix:playCrash(1,2)) end
        assert(#calls==1)
    end)
    test("two tops going over together each get one fall",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{})); mix:update(results(1,true,true))
        assert(mix:playCrash(1,1) and mix:playCrash(1,2))
        assert(not mix:playCrash(1,1) and not mix:playCrash(1,2) and #calls==2)
    end)
    test("muted falls are consumed instead of replayed on unmute",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{})); mix:update(results(1,false,true))
        mix:setMuted(true); assert(not mix:playCrash(1,2))
        mix:setMuted(false); assert(not mix:playCrash(1,2) and #calls==0)
    end)
    test("restart and exit invalidate old fall callbacks but permit the next one",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{})); mix:update(results(1,false,true))
        mix:update(snapshot("Configure",0,{},2))
        assert(not mix:playCrash(1,2) and not mix:playCrash(2,2))
        mix:update(snapshot("Fight",0,{},2)); mix:update(results(2,false,true))
        assert(not mix:playCrash(1,2) and mix:playCrash(2,2) and #calls==1)
        mix:update({active=false}); assert(not mix:playCrash(2,2))
        mix:destroy(); assert(not mix:playCrash(2,2) and #calls==1)
    end)
    test("late Results entry and delayed presentation callbacks stay silent",function()
        local mix,calls=fixture()
        mix:update(results(1,false,true)); assert(not mix:playCrash(1,2))
        mix:update(results(1,false,true)); assert(not mix:playCrash(1,2))
        mix:update(snapshot("Fight",0,{},2)); mix:update(results(2,false,true))
        mix.resultsAt=os.clock()-Audio.MAX_CRASH_AGE-1
        mix:update(results(2,false,true))
        assert(not mix:playCrash(2,2) and #calls==0,"a repeated Results snapshot refreshed stale fall eligibility")
    end)
    test("a round won on the clock or still unfinished cannot claim a fall",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{})); mix:update(results(1,false,false,"timeout"))
        assert(not mix:playCrash(1,2))
        mix:update(results(1,false,true,"timeout")); assert(not mix:playCrash(1,2))
        local invalid=results(1,false,true); invalid.simulation.finished=false
        mix:update(invalid); assert(not mix:playCrash(1,2) and #calls==0)
    end)
    test("going over the edge is the finishing sound and the finish adds only a chime",function()
        local mix,calls,attrs=fixture()
        mix:update(snapshot("Fight",0,{}))
        local ending=snapshot("Results",0.5,{event(1,"ringout",0.5,1),event(2,"finish",0.5)})
        ending.simulation.reason="ringout"; ending.simulation.finished=true
        mix:update(ending)
        assert(#calls==2 and calls[1].name=="boom" and calls[2].name=="chime" and attrs.LastEvent=="finish")
    end)
    test("missing timestamps are supported after initialization and unknown events are consumed",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        mix:update(snapshot("Fight",0.1,{event(1,"miss",0.1),event(2,"wall",nil)}))
        assert(#calls==1 and mix.lastSerial==2)
        mix:update(snapshot("Fight",0.2,{event(1,"wall",0.2),event(2,"wall",nil)}))
        assert(#calls==1)
    end)
    test("destroy is idempotent and later input cannot resurrect the mix",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{})); mix:destroy(); mix:destroy()
        mix:setMuted(false); mix:update(snapshot("Fight",0.1,{smash(1,0.1)}))
        assert(#calls==0 and mix.folder.destroyed==1 and next(mix.voices)==nil)
    end)
    test("RoundOver and MatchOver use result fall eligibility and reset on next Pick",function()
        local mix,calls=fixture()
        mix:update(snapshot("Fight",0,{}))
        local s=results(1,true,false);s.phase="RoundOver";mix:update(s)
        assert(mix:playCrash(1,1),"RoundOver fall was silent")
        mix:update(snapshot("Pick",0,{},2));assert(not mix:playCrash(1,1),"Old fall survived next draft")
        mix:update(snapshot("Fight",0,{},2));s=results(2,false,true);s.phase="MatchOver";mix:update(s)
        assert(mix:playCrash(2,2),"MatchOver fall was silent")
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
