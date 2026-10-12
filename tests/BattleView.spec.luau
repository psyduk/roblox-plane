-- Native Roblox engine checks for the ring's presentation, not subjective feel.
-- require(thisModule)(BattleView, World, BattleSimulation). Fixtures are destroyed.
return function(View, World, Simulation)
    local Lighting=game:GetService("Lighting")
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
        -- Two tops standing still at known places, mid-fight.
        local function snapshot(roundId,phase,a,b)
            local sim=Simulation.newRound(731,a or {offenceId="Boulder"},b or {offenceId="Bolt"})
            sim.fighters[1].x,sim.fighters[1].y=-12,6
            sim.fighters[2].x,sim.fighters[2].y=15,-9
            for _,f in ipairs(sim.fighters) do f.vx,f.vy,f.moveLeft=0,0,1000 end
            sim.events={}; sim.elapsed=4
            return {roundId=roundId,phase=phase,active=true,simulation=sim,
                players={{userId=1,name="Ada",color=1,trailId="classic"},{userId=0,name="Comet",bot=true,color=2,trailId="classic"}}}
        end
        local ok,err=pcall(body,view,cues,advance,snapshot)
        view:destroy()
        assert(view.folder.Parent==nil,"Fixture cleanup failed")
        assert(ok,name..": "..tostring(err))
        passed=passed+1
    end
    local function at(model) return model.PrimaryPart.Position end
    local function named(model,name)
        local found={}
        for _,piece in ipairs(model:GetChildren()) do if piece.Name==name then found[#found+1]=piece end end
        return found
    end
    test("each top stands on the deck where the simulation says it is",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight")
        advance(s,0.3)
        local ground=view.folder:GetAttribute("GroundY")
        local deck=view.folder.Stadium.Deck
        local a,b=at(view.fighters[1].model),at(view.fighters[2].model)
        assert(math.abs(a.X-(deck.Position.X-12))<0.5 and math.abs(a.Z-(deck.Position.Z+6))<0.5,"Top 1 is not where the simulation put it")
        assert(math.abs(b.X-(deck.Position.X+15))<0.5 and math.abs(b.Z-(deck.Position.Z-9))<0.5,"Top 2 is not where the simulation put it")
        assert(math.abs(a.Y-ground)<0.2 and math.abs(b.Y-ground)<0.2,"A top is not standing on the deck")
        assert(math.abs(deck.Position.Y+deck.Size.X/2-ground)<0.3,"The deck's surface is not at ground level")
        assert(view.fighters[1].radius>view.fighters[2].radius,"Boulder is not drawn bigger than Bolt")
        assert(#cues==0,"A cue fired with both tops on the ring")
    end)
    test("tops spin, and the two are painted apart",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight")
        view:update(s,1/60)
        local stripe=named(view.fighters[1].model,"SpinStripe")[1]
        local before=stripe.CFrame.RightVector
        advance(s,0.1)
        assert((stripe.CFrame.RightVector-before).Magnitude>0.2,"The top is not spinning")
        assert(view:accent(1)~=view:accent(2),"Both tops wear the same paint")
        assert(view.fighters[1].model.AttackRing.Color==view:accent(1),"The top is not in its pilot's paint")
    end)
    test("the platform closes in with the simulation's ring",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight")
        view:update(s,1/60)
        local deck=view.folder.Stadium.Deck
        local full=deck.Size.Y
        s.simulation.ring=20;s.simulation.pressure=0.6
        view:update(s,1/60)
        assert(deck.Size.Y<full*0.6 and deck.Size.Y>10,"The deck did not shrink with the ring")
        assert(view.folder.Stadium.DangerBand.Size.Y>deck.Size.Y,"The danger band is not outside the deck")
        assert(view.folder.Stadium.LostRing.Transparency<1,"The lost part of the ring leaves no trace")
    end)
    test("a top that leaves the ring drops out of the sky once and the winner stays put",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight")
        advance(s,0.2)
        local winner=at(view.fighters[1].model)
        local loser=s.simulation.fighters[2]
        loser.x,loser.y,loser.vx,loser.out,loser.phase=41,0,30,true,"Out"
        s.simulation.finished=true;s.simulation.reason="ringout";s.simulation.winner=1
        s.phase="RoundOver"
        advance(s,1.5)
        local ground=view.folder:GetAttribute("GroundY")
        assert(at(view.fighters[2].model).Y<ground-20,"The fallen top did not drop")
        assert((at(view.fighters[1].model)-winner).Magnitude<0.5,"The winner moved")
        assert(#cues==1 and cues[1].kind=="crash" and cues[1].actor==2 and cues[1].roundId==1,"Missing or duplicate fall cue")
        assert(view.fighters[2].model:GetAttribute("Phase")=="Out")
        advance(s,1);assert(#cues==1,"The fall cue repeated")
    end)
    test("upgrades are drawn on the top, and one-shot upgrades show when they are spent",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight",{offenceId="Cyclone",wildIds={"Spikes","Bumper"}},{offenceId="Pogo",wildIds={"Jetpack","Heavy"}})
        view:update(s,1/60)
        local a,b=view.fighters[1].model,view.fighters[2].model
        assert(#named(a,"Spike")==6 and #named(a,"Fin")==3,"Spikes or Cyclone's fins are missing")
        assert(a.BumperShield.Transparency<1,"A loaded bumper is invisible")
        assert(#named(b,"JetTank")==2 and #named(b,"HeavyBand")==1 and #named(b,"Spring")==3,"Pogo's upgrades are missing")
        s.simulation.fighters[1].bumperReady=false
        view:update(s,1/60)
        assert(a.BumperShield.Transparency==1,"A spent bumper is still drawn")
        s.simulation.fighters[2].jetReady=false
        view:update(s,1/60)
        assert(named(b,"JetTank")[1].Transparency>0.5,"An empty jetpack looks full")
    end)
    test("a jumping top leaves the deck, its halo stays, and its landing is marked",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight",{offenceId="Pogo"},{offenceId="Bolt"})
        local pogo=s.simulation.fighters[1]
        pogo.phase,pogo.flying,pogo.z,pogo.lockX,pogo.lockY="Air","jump",12,10,-4
        advance(s,0.3)
        local ground=view.folder:GetAttribute("GroundY")
        local fighter=view.fighters[1]
        assert(at(fighter.model).Y>ground+8,"The jump has no height")
        assert(math.abs(fighter.halo.Position.Y-ground)<1,"The halo left the deck")
        assert(fighter.target.Transparency<1 and math.abs(fighter.target.Position.X-(view.folder.Stadium.Deck.Position.X+10))<0.5,"The landing is not marked")
        pogo.phase,pogo.flying,pogo.z="Roam",nil,0
        advance(s,0.3)
        assert(fighter.target.Transparency==1 and at(fighter.model).Y<ground+1,"The top did not come down")
    end)
    test("a charging dash shows where it will go",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight",{offenceId="Bolt"},{offenceId="Boulder"})
        local bolt=s.simulation.fighters[1]
        bolt.phase,bolt.phaseLeft,bolt.lockX,bolt.lockY="Windup",0.3,15,-9
        advance(s,0.1)
        local fighter=view.fighters[1]
        assert(fighter.line.Transparency<1 and fighter.line.Size.Z>20,"No aim line while charging")
        assert(fighter.label.Text=="CHARGING...","The top does not say what it is doing")
        bolt.phase="Roam";advance(s,0.1)
        assert(fighter.line.Transparency==1 and fighter.label.Text=="YOU","The aim line outlived the charge")
    end)
    test("a new round or a changed build makes new tops, and a pick puts them away",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight")
        view:update(s,1/60)
        local first=view.fighters[1].model
        view:update(s,1/60);assert(view.fighters[1].model==first,"A repeated snapshot rebuilt the top")
        local nextRound=snapshot(2,"Countdown",{offenceId="Pogo"},{offenceId="Bolt"})
        view:update(nextRound,1/60)
        assert(first.Parent==nil and view.fighters[1].model~=first and view.fighters[1].model.Head,"The old top survived a new round")
        nextRound.phase="Pick";view:update(nextRound,1/60)
        assert(at(view.fighters[1].model).Y<-1000,"A top is still on the ring while pilots are picking")
        assert(view.folder:GetAttribute("Phase")=="Pick" and view.folder:GetAttribute("RoundId")=="2")
    end)
    test("the camera looks down on the whole ring and big hits shake it unless motion is reduced",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight")
        view:update(s,1/60,{left=0,right=800,top=100,bottom=600})
        local camera=workspace.CurrentCamera
        local deck=view.folder.Stadium.Deck.Position
        assert(camera.CameraType==Enum.CameraType.Scriptable and camera.CFrame.Position.Y>deck.Y+60,"The camera is not above the ring")
        assert(camera.CFrame.LookVector.Y<-0.5,"The camera is not looking down")
        local height=view.folder:GetAttribute("VisibleHeight")
        assert(height==height and height>60 and height<400,"The frame does not hold the ring")
        s.simulation.elapsed=4.1
        s.simulation.events={{serial=5,kind="clash",at=4.1,x=0,y=0,actor=1,target=2,power=60,source="bump"}}
        view:update(s,1/60)
        assert(view.shake>0.5 and view.screenFlash>0.3,"A big hit did not land on screen")
        view.shake,view.screenFlash,view.reducedMotion=0,0,true
        s.simulation.elapsed=4.2
        s.simulation.events={{serial=6,kind="clash",at=4.2,x=0,y=0,actor=1,target=2,power=60,source="bump"}}
        view:update(s,1/60)
        assert(view.shake<0.5,"Reduced motion still shakes hard")
    end)
    test("an old event is not replayed and effects leave with the view",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight")
        s.simulation.elapsed=10
        s.simulation.events={{serial=3,kind="clash",at=2,x=0,y=0,actor=1,target=2,power=60,source="bump"}}
        view:update(s,1/60)
        assert(view.shake==0 and view.lastEvent==3,"A stale event shook the screen or was not consumed")
        assert(Lighting:FindFirstChild("SkyboundBattleBloom") and Lighting:FindFirstChild("SkyboundBattleGrade"))
        view:destroy();view:destroy()
        assert(not Lighting:FindFirstChild("SkyboundBattleBloom") and not Lighting:FindFirstChild("SkyboundBattleGrade"),"Lighting effects outlived the view")
        view:update(s,1/60)
    end)
    return tostring(passed).." battle-view tests passed"
end
