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
    test("every equipped skin keeps its geometry under every active offence",function(view,cues,advance,snapshot)
        for skinIndex,skin in ipairs({"cruiser","skyhopper","dart"}) do
            local s=snapshot(100+skinIndex,"Pick",3,3)
            s.players={{userId=1,name="You",planeId=skin,color=1},{userId=2,name="Rival",planeId=skin,color=1}}
            s.simulation.finished=false; s.simulation.fighters[1].offenceId=""
            s.simulation.fighters[2].offenceId=""
            view:update(s,1/60)
            local fighter=view.fighters[1]; local bodySize=fighter.body.Size
            local geometry={}
            for _,piece in ipairs(fighter.model:GetChildren()) do
                if piece:IsA("BasePart") and piece.Transparency<0.5 then geometry[piece]=piece.Size end
            end
            for _,name in ipairs({"Nose","Belly","WingLeft","WingRight","Tail","Centre","Top"}) do
                assert(fighter.model.PrimaryPart:FindFirstChild(name):IsA("Attachment"),"Missing "..skin.." "..name)
            end
            for _,offence in ipairs({"Meteor","Firework","MachineGun","Pinball"}) do
                view:_setSignature(fighter,offence)
                assert(fighter.body.Size==bodySize,"Skill reshaped equipped fuselage")
                for piece,size in pairs(geometry) do assert(piece.Size==size and piece.Transparency<0.5,"Skill hid or reshaped "..piece.Name) end
                assert(fighter.model:GetAttribute("PlaneId")==skin,"Wrong equipped skin")
            end
            assert(view.fighters[2].model:GetAttribute("PlaneId")==skin,"Mirror replaced rival skin")
            assert(view.fighters[1].color==view.fighters[2].color,"Mirror replaced rival paint")
            assert(view.fighters[1].sideColor~=view.fighters[2].sideColor,"Mirror lost side identity")
        end
    end)
    test("match phases retain authoritative crash and clear new-skill effects",function(view,cues,advance,snapshot)
        local s=snapshot(200,"Fight",1,2)
        s.simulation.fighters[1].offenceId="MachineGun"; s.simulation.fighters[1].magnetLeft=1
        s.simulation.fighters[1].secondWind=true
        view:update(s,1/60)
        assert(view.fighters[1].magnetRing[1].Transparency<1,"Magnet missing its cue")
        assert(view.fighters[1].windRing[1].Transparency<1,"Second Wind missing its cue")
        s.phase="RoundOver";s.simulation.finished=true;s.simulation.reason="knockout";s.simulation.fighters[1].armor=0
        advance(s,2.5)
        assert(#cues==1,"RoundOver did not land the authoritative knockout")
        local nextRound=snapshot(201,"Pick",3,3)
        advance(nextRound,0.1)
        assert(view.fighters[1].magnetRing[1].Transparency==1 and view.fighters[1].windRing[1].Transparency==1,"Pick retained old cues")
    end)
    test("reduced motion suppresses afterimages and flashes while preserving skill tells",function(view,cues,advance,snapshot)
        view.reducedMotion=true
        local s=snapshot(202,"Fight",3,3)
        s.simulation.fighters[1].offenceId="Meteor";s.simulation.fighters[1].phase="Attack";s.simulation.fighters[1].armed=true
        view:update(s,1/60)
        local fighter=view.fighters[1]
        assert(fighter.chargeShell.Transparency<1,"Reduced motion hid commitment cue")
        for _,ghost in ipairs(fighter.afterimages) do for _,piece in ipairs(ghost.pieces) do assert(piece.Transparency==1,"Reduced motion left afterimage") end end
        assert(view.screenFlash==0,"Reduced motion flashed")
    end)
    test("storm follows every authoritative boundary and resets grade on results",function(view,cues,advance,snapshot)
        for index,pressure in ipairs({0.1,0.5,1}) do
            local s=snapshot(300+index,"Fight",3,3)
            s.simulation.pressure=pressure
            s.simulation.bounds={left=-72+24*pressure,right=72-24*pressure,bottom=8+10*pressure,top=96-14*pressure}
            view:update(s,1/60)
            local bounds=s.simulation.bounds
            local origin=Vector3.new(0,80,-4000)
            assert(math.abs(view.edges[1].Position.X-origin.X-bounds.left)<0.001)
            assert(math.abs(view.edges[2].Position.X-origin.X-bounds.right)<0.001)
            assert(math.abs(view.edges[3].Position.Y-origin.Y-bounds.top)<0.001)
            assert(math.abs(view.edges[4].Position.Y-origin.Y-bounds.bottom)<0.001)
            assert(view.windStreaks[1][1].Transparency<1,"Closing wind did not track pressure")
            assert(view.grade.Brightness>=0 and math.abs(view.grade.Saturation-0.14)<0.001,"Closing wind darkened the sky")
            view.reducedMotion=true;view:update(s,1/60)
            s.phase="MatchOver";view:update(s,1/60)
            assert(math.abs(view.grade.Brightness)<0.001 and math.abs(view.grade.Saturation-0.14)<0.001,"Result kept storm grade")
            view.reducedMotion=false
        end
        view:_resetRound(400)
        for side=1,4 do assert(view.windStreaks[side][1].Transparency==1,"Round reset left closing wind") end
    end)
    test("generic non-aircraft contract supports equipment and crash without plane parts",function(view,cues,advance,snapshot)
        local originalWorld=view.World
        view.World={trailLook=originalWorld.trailLook,createPlane=function(parent,name,colorIndex,planeId)
            local model=Instance.new("Model");model.Name=name;model:SetAttribute("PlaneId",planeId);model:SetAttribute("BattleVisualSize",8)
            local body=Instance.new("Part");body.Name="BroomBody";body.Size=Vector3.new(8,1,1);body.Anchored=true;body.CanCollide=false;body.Parent=model;model.PrimaryPart=body
            for mountName,position in pairs({Nose=Vector3.new(4,0,0),Tail=Vector3.new(-4,0,0),Belly=Vector3.new(0,-0.5,0),Centre=Vector3.zero,Top=Vector3.new(0,1,0),WingLeft=Vector3.new(0,0,-1),WingRight=Vector3.new(0,0,1)}) do
                local attachment=Instance.new("Attachment");attachment.Name=mountName;attachment.Position=position;attachment.Parent=body
            end
            model.Parent=parent;return model
        end}
        local s=snapshot(410,"Fight",2,3);s.simulation.fighters[1].offenceId="Firework"
        view:update(s,1/60);assert(view.fighters[1].propeller==nil and view.fighters[1].body.Name=="BroomBody")
        s.phase="MatchOver";s.simulation.finished=true;s.simulation.reason="knockout";s.simulation.fighters[1].armor=0
        advance(s,2.5)
        assert(#cues==1 and view.fighters[1].crashLanded,"Generic skin failed to land once")
        assert(#view.fighters[1].debris==5,"Generic fallback grew unbounded debris")
    end)
    test("bounce stays bounded after one ground cue and cleanup cancels the sequence",function(view,cues,advance,snapshot)
        local s=snapshot(420,"Fight",1,3);view:update(s,1/60)
        s.phase="MatchOver";s.simulation.finished=true;s.simulation.reason="knockout";s.simulation.fighters[1].armor=0
        local landed=false;local bounced=false
        for frame=1,180 do
            view:update(s,1/60)
            if view.fighters[1].crashLanded then
                landed=true
                local gap=view.fighters[1].crashContactY-view.groundY
                assert(gap>=-0.002 and gap<=0.81,"Bounce left bounded floor region")
                if gap>0.05 then bounced=true end
            end
            if frame%12==0 then task.wait() end
        end
        assert(landed and bounced and #cues==1,"Bounce failed or repeated first contact")
        assert(math.abs(view.fighters[1].crashContactY-view.groundY)<0.002,"Bounce did not settle")
        advance(snapshot(421,"Pick",3,3),0.1);assert(view.fighters[1].crash==nil,"Next draft kept old fall")
    end)
    test("the load gauge fills while circling and lights fully only when the attack is loaded",function(view,cues,advance,snapshot)
        local s=snapshot(430,"Fight",3,3);local f=s.simulation.fighters[1]
        f.vx=20;f.phase,f.phaseLeft,f.circling="Approach",3,true
        advance(s,0.1)
        local ring=view.fighters[1].loadRing
        local function lit() local n=0;for _,piece in ipairs(ring) do if piece.Transparency<0.8 then n=n+1 end end;return n end
        assert(#ring==10 and lit()==0 and view.fighters[1].model:GetAttribute("AttackLoaded")==false,"An empty attack looked loaded")
        f.phaseLeft=1.5;advance(s,0.1)
        assert(lit()>=4 and lit()<=6,"Half-loaded gauge did not show about half")
        f.circling=false;advance(s,0.1)
        assert(lit()==10 and view.fighters[1].model:GetAttribute("AttackLoaded")==true,"A loaded attack did not light the whole gauge")
        f.phase,f.phaseLeft="Windup",1;advance(s,0.1);assert(lit()==10,"Gauge went dark during the windup")
        f.phase,f.phaseLeft="Recover",2;advance(s,0.1)
        assert(lit()==0 and view.fighters[1].model:GetAttribute("AttackLoaded")==false,"Gauge stayed lit while banking away")
    end)
    test("each power shows its own equipment: ball, beam, jet and aura",function(view,cues,advance,snapshot)
        local s=snapshot(440,"Fight",3,3);local sim=s.simulation;local f=sim.fighters[1]
        f.vx=20;f.phase,f.phaseLeft="Recover",2
        sim.projectiles={{id=1,owner=1,x=0,y=50,vx=60,vy=0,life=2,radius=3.2,source="pinball",bounces=3}}
        advance(s,0.1)
        local ball;for _,rocket in pairs(view.rockets) do ball=rocket end
        assert(ball and ball.ball.Transparency<0.5 and ball.body.Transparency==1 and ball.nose.Transparency==1,"Pinball's ball looked like a rocket")
        sim.projectiles={{id=2,owner=1,x=0,y=50,vx=60,vy=0,life=2,radius=3.5}}
        advance(s,0.1)
        local rocket;for _,item in pairs(view.rockets) do rocket=item end
        assert(rocket.ball.Transparency==1 and rocket.body.Transparency==0,"A rocket looked like Pinball's ball")
        local me=view.fighters[1]
        assert(me.magnetBeam.Transparency==1 and me.burnerFlames[1].Transparency==1 and me.windAura.Transparency==1,"A power effect showed with no power active")
        f.magnetLeft=0.5;advance(s,0.1)
        assert(me.magnetBeam.Transparency<0.5 and me.magnetBeam.Size.X>20,"Magnet drew no beam to the rival")
        f.magnetLeft=0;f.boostLeft=0.8;advance(s,0.1)
        assert(me.magnetBeam.Transparency==1 and me.burnerFlames[1].Transparency<0.5 and me.burnerFlames[1].Size.X>15,"Afterburner drew no jet")
        f.boostLeft=0;f.secondWind=true;advance(s,0.1)
        assert(me.burnerFlames[1].Transparency==1 and me.windAura.Transparency<0.6,"Second Wind drew no aura")
    end)
    return string.format("BattleView: %d native presentation tests passed",passed)
end
