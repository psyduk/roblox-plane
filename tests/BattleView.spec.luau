-- Native Roblox engine checks for post-result presentation, not subjective feel.
-- require(thisModule)(BattleView, World, BattleSimulation). Fixtures are destroyed.
return function(View, World, Simulation)
    local passed=0
    local function test(name,body)
        local cues={}
        local view=View.new(World,function(cue) cues[#cues+1]=cue end)
        view.folder.Name="BattlePresentationFixture"
        local function advance(snapshot,seconds)
            for i=1,math.ceil(seconds*60) do
                view:update(snapshot,1/60)
                if i%12==0 then task.wait() end
            end
        end
        local function snapshot(roundId,phase,armor1,armor2,reason)
            local sim=Simulation.newRound(731)
            sim.fighters[1].x,sim.fighters[1].y=-20,70
            sim.fighters[2].x,sim.fighters[2].y=30,60
            for i,f in ipairs(sim.fighters) do
                f.armor=i==1 and armor1 or armor2
                f.vx,f.vy,f.armed=0,0,false
            end
            sim.finished=phase=="Results"; sim.reason=reason
            sim.winner=armor1==armor2 and 0 or (armor1>armor2 and 1 or 2)
            sim.events={}; sim.elapsed=20
            return {roundId=roundId,phase=phase,active=true,simulation=sim}
        end
        local ok,err=pcall(body,view,cues,advance,snapshot)
        view:destroy()
        assert(view.folder.Parent==nil,"Fixture cleanup failed")
        assert(ok,name..": "..tostring(err))
        passed=passed+1
    end
    local function lowestSolid(model)
        local lowest=math.huge
        for _,p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency<0.5 and not string.find(p.Name,"Smoke") then
                local c,s=p.CFrame,p.Size
                local extent=(math.abs(c.RightVector.Y)*s.X+math.abs(c.UpVector.Y)*s.Y+math.abs(c.LookVector.Y)*s.Z)/2
                lowest=math.min(lowest,p.Position.Y-extent)
            end
        end
        return lowest
    end
    test("KO falls onto the visible floor once without moving the winner or simulation",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight",1,2)
        view:update(s,1/60)
        local start=view.fighters[1].model:GetPivot().Position
        local winner=view.fighters[2].model:GetPivot().Position
        s.phase="Results";s.simulation.finished=true;s.simulation.reason="knockout";s.simulation.fighters[1].armor=0
        advance(s,0.25)
        assert(view.fighters[1].model:GetPivot().Position.Y<start.Y,"Defeated plane did not descend")
        assert(#cues==0,"Ground sound played before landing")
        advance(s,2)
        assert(#cues==1 and cues[1].kind=="crash" and cues[1].actor==1 and cues[1].roundId==1,"Missing or duplicate landing cue")
        assert(view.fighters[1].model:GetAttribute("CrashState")=="Landed","KO did not settle")
        local lip=view.folder.Stadium.FloorLip
        local ground=lip.Position.Y+lip.Size.Y/2
        assert(math.abs(lowestSolid(view.fighters[1].model)-ground)<0.8,"Wreck floats above or penetrates the floor")
        assert((view.fighters[2].model:GetPivot().Position-winner).Magnitude<0.01,"Winner fell or moved")
        assert(s.simulation.fighters[1].y==70 and s.simulation.winner==2,"Presentation changed authoritative result")
        advance(s,1)
        assert(#cues==1,"Ground cue repeated on Results snapshots")
    end)
    test("simultaneous knockout crashes both planes",function(view,cues,advance,snapshot)
        local s=snapshot(2,"Results",0,0,"knockout")
        advance(s,2.5)
        assert(#cues==2 and cues[1].actor~=cues[2].actor,"Double KO did not land both planes once")
        for _,f in pairs(view.fighters) do assert(f.model:GetAttribute("CrashState")=="Landed") end
        assert(s.simulation.winner==0,"Crash changed the draw")
    end)
    test("timeout survivors do not crash",function(view,cues,advance,snapshot)
        local s=snapshot(3,"Results",1,2,"timeout")
        view:update(s,1/60)
        local y=view.fighters[1].model:GetPivot().Position.Y
        advance(s,2)
        assert(#cues==0 and view.fighters[1].model:GetAttribute("CrashState")==nil,"Timeout survivor crashed")
        assert(math.abs(view.fighters[1].model:GetPivot().Position.Y-y)<0.01,"Timeout survivor fell")
    end)
    test("retry during a fall cancels the old landing",function(view,cues,advance,snapshot)
        advance(snapshot(4,"Results",0,2,"knockout"),0.2)
        local nextRound=snapshot(5,"Configure",3,3)
        advance(nextRound,2)
        assert(#cues==0,"Old crash sounded after retry")
        for _,f in pairs(view.fighters) do assert(f.model:GetAttribute("CrashState")==nil,"Retry kept crash state") end
    end)
    test("destroy during a fall cancels pending presentation",function(view,cues,advance,snapshot)
        local s=snapshot(6,"Results",0,2,"knockout")
        advance(s,0.2)
        view:destroy()
        advance(s,2)
        assert(#cues==0,"Destroyed view emitted a delayed landing")
    end)
    test("near-floor knockout reaches first contact and cues in the same update",function(view,cues,advance,snapshot)
        for sample,height in ipairs({8,10,14}) do
            local s=snapshot(20+sample,"Fight",1,2)
            s.simulation.fighters[1].y=height
            view:update(s,1/60)
            s.phase="Results";s.simulation.finished=true;s.simulation.reason="knockout";s.simulation.fighters[1].armor=0
            local before=#cues
            local previousBottom=math.huge
            local landed=false
            for frame=1,90 do
                view:update(s,1/60)
                local fighter=view.fighters[1]
                local bottom=lowestSolid(fighter.model)
                local gap=bottom-view.groundY
                assert(gap>=-0.002,"Near-floor crash penetrated the floor")
                assert(bottom<=previousBottom+0.002,"Near-floor wreck lifted away from the floor")
                previousBottom=bottom
                if fighter.model:GetAttribute("CrashState")=="Landed" then
                    assert(math.abs(gap)<0.002,"Landing cue happened before actual contact")
                    assert(#cues==before+1 and cues[#cues].roundId==s.roundId,"Contact did not emit exactly one current-round cue")
                    landed=true
                    break
                end
                assert(gap>0.002 and #cues==before,"Wreck touched the floor before landing cue")
                if frame%12==0 then task.wait() end
            end
            assert(landed,"Near-floor crash did not settle")
            advance(s,0.25)
            assert(#cues==before+1,"Near-floor landing cue repeated")
        end
    end)
    return string.format("BattleView: %d native crash tests passed",passed)
end
