-- Regression checks for the two-pilot event mix. No real sound is emitted.
return function(Audio)
    local passed=0
    local function test(name,body)
        local ok,problem=pcall(body)
        assert(ok,name..": "..tostring(problem)); passed+=1
    end
    local function fixture(realEvents)
        local calls,attributes={},{}
        local mix=setmetatable({voices={},tweens={},tracks={},played=0,ghostPlayed=0,humanPlayed=0,
            group={Volume=.75},folder={SetAttribute=function(_,key,value) attributes[key]=value end}},Audio)
        if realEvents then
            mix.voice=function(_,name,volume,pitch) table.insert(calls,{name=name,volume=volume,pitch=pitch}) end
        else
            mix.playEvent=function(_,event,gain,pitch,track,pilot)
                table.insert(calls,{kind=event.kind,serial=event.serial,gain=gain,userId=pilot.userId})
            end
        end
        return mix,calls,attributes
    end
    local function pilot(id,bot,elapsed,serial,kind)
        return {userId=id,bot=bot,flight={elapsed=elapsed,
            recentEvents={{serial=serial,kind=kind or "fuel",at=elapsed,value=10}}}}
    end

    test("ghost contacts play while the camera follows the human",function()
        local mix,calls=fixture()
        mix:update({pilot(1,false,0,1,"launch"),pilot(-1,true,0,1,"launch")},"round1",1,true)
        mix:update({pilot(1,false,.3,2),pilot(-1,true,.3,2)},"round1",1,true)
        assert(#calls==4 and calls[4].userId==-1 and calls[4].gain==.65)
    end)
    test("camera switches preserve both cursors and update the mix",function()
        local mix,calls=fixture()
        local players={pilot(1,false,0,1),pilot(-1,true,0,1)}
        mix:update(players,"round1",1,true)
        mix:update(players,"round1",-1,true)
        assert(#calls==2,"camera replayed history")
        players[2]=pilot(-1,true,.2,2,"missile")
        mix:update(players,"round1",-1,true)
        assert(#calls==3 and calls[3].gain==1 and calls[3].kind=="missile")
    end)
    test("independent serials cannot suppress a rival event",function()
        local mix,calls=fixture()
        mix:update({pilot(1,false,0,10),pilot(-1,true,0,1)},"round1",1,true)
        mix:update({pilot(1,false,.2,10),pilot(-1,true,.2,2)},"round1",1,true)
        assert(#calls==3 and calls[3].userId==-1)
    end)
    test("late entry skips history but plays the next contact",function()
        local mix,calls=fixture()
        local players={pilot(1,false,12,20),pilot(-1,true,12,22)}
        mix:update(players,"round1",1,true);assert(#calls==0)
        players[2]=pilot(-1,true,12.2,23)
        mix:update(players,"round1",1,true);assert(#calls==1 and calls[1].serial==23)
    end)
    test("stale events are not replayed and round changes reset cursors",function()
        local mix,calls=fixture()
        local players={pilot(1,false,0,1)}
        mix:update(players,"round1",1,true)
        players[1].flight.elapsed=2
        players[1].flight.recentEvents={{kind="fuel",at=.1,serial=2}}
        mix:update(players,"round1",1,true);assert(#calls==1)
        mix:update({pilot(1,false,0,1)},"round2",1,true);assert(#calls==2)
    end)
    test("cooldowns do not mute simultaneous own and ghost pickups",function()
        local mix,calls,attrs=fixture(true)
        mix:update({pilot(1,false,0,1),pilot(-1,true,0,1)},"round1",1,true)
        assert(#calls==4,"one pilot suppressed the other")
        assert(attrs.GhostEvents==1 and attrs.HumanEvents==1)
        assert(calls[3].volume>0 and calls[3].volume<calls[1].volume)
        assert(calls[3].pitch<calls[1].pitch,"ghost voice should be distinguishable")
    end)
    test("leaving stops voices and retires cursors",function()
        local mix=fixture()
        local stopped,cancelled=0,0
        mix.voices={test={{Stop=function() stopped+=1 end}}}
        mix.tweens={test={Cancel=function() cancelled+=1 end}}
        mix:update({pilot(1,false,0,1),pilot(-1,true,0,1)},"round1",1,true)
        stopped,cancelled=0,0
        mix:update({},"round1",1,false)
        assert(mix.key==nil and next(mix.tracks)==nil and stopped==1 and cancelled==1)
    end)
    test("the mix retains at most two pilots",function()
        local mix,calls=fixture()
        mix:update({pilot(1,false,0,1),pilot(-1,true,0,1),pilot(3,false,0,1)},"round1",1,true)
        assert(#calls==2 and mix.tracks["3"]==nil)
        mix:update({pilot(1,false,.1,1)},"round1",1,true)
        assert(mix.tracks["-1"]==nil)
    end)
    test("power cues mix both pilots and do not replay on camera switches",function()
        local mix,calls,attrs=fixture(true)
        local players={pilot(1,false,0,1,"pinball"),pilot(-1,true,0,1,"munch")}
        mix:update(players,"round1",1,true)
        assert(#calls==6 and attrs.PlayedEvents==2)
        assert(calls[1].name=="boing" and calls[4].name=="land","powers lost their distinct cues")
        mix:update(players,"round1",-1,true)
        assert(#calls==6,"power history replayed after switching cameras")
        players[1]=pilot(1,false,.2,2,"meteorDive")
        players[2]=pilot(-1,true,.2,2,"meteorBoost")
        mix:update(players,"round1",-1,true)
        assert(#calls==11 and attrs.GhostEvents==2 and attrs.HumanEvents==2)
        assert(calls[7].name=="jump" and calls[9].name=="boom")
    end)
    test("mute silences active voices and consumes power event history",function()
        local mix,calls=fixture(true)
        local stopped,cancelled=0,0
        mix.voices={test={{Stop=function() stopped+=1 end}}}
        mix.tweens={test={Cancel=function() cancelled+=1 end}}
        mix:update({pilot(1,false,0,1,"pinball")},"round1",1,true)
        local before=#calls
        mix:setMuted(true)
        assert(stopped>=1 and cancelled>=1 and mix.group.Volume==0)
        local players={pilot(1,false,.2,2,"munch")}
        mix:update(players,"round1",1,true)
        mix:playSelection("Meteor",true)
        assert(#calls==before,"muted action emitted a voice")
        mix:setMuted(false)
        mix:update(players,"round1",1,true)
        assert(#calls==before,"unmute replayed a muted event")
        players[1]=pilot(1,false,.3,3,"meteorBoost")
        mix:update(players,"round1",1,true)
        assert(#calls==before+3 and mix.group.Volume==.75)
    end)
    test("selection is explicit and rapid duplicate callbacks are suppressed",function()
        local mix,calls,attrs=fixture(true)
        mix:playSelection("unknown",true);assert(#calls==0)
        mix:playSelection("Pinball",false);assert(#calls==1)
        mix:playSelection("Pinball",false);assert(#calls==1)
        mix:playSelection("Pinball",true);assert(#calls==3)
        mix:playSelection("Pinball",true);assert(#calls==3)
        mix:playSelection("Muncher",false);assert(#calls==5)
        assert(attrs.LastSelection=="Muncher" and attrs.SelectionConfirmed==false)
        assert(mix.key==nil and next(mix.tracks)==nil,"selection changed flight cursors")
    end)
    return tostring(passed).." flight-audio tests passed"
end
