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
            sim.fighters[2].x,sim.fighters[2].y=10,-9
            for _,f in ipairs(sim.fighters) do f.vx,f.vy=0,0 end
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
        assert(math.abs(b.X-(deck.Position.X+10))<0.5 and math.abs(b.Z-(deck.Position.Z-9))<0.5,"Top 2 is not where the simulation put it")
        assert(math.abs(a.Y-ground)<0.6 and math.abs(b.Y-ground)<0.6,"A top is not standing on the deck")
        assert(math.abs(deck.Position.Y+deck.Size.X/2-ground)<0.3,"The deck's surface is not at ground level")
        assert(view.fighters[1].radius>view.fighters[2].radius,"Boulder is not drawn bigger than Bolt")
        assert(#cues==0,"A cue fired with both tops in the bowl")
    end)
    test("the stadium has a wall with three exits where the simulation has gaps",function(view)
        local stadium=view.folder.Stadium
        local deck=stadium.Deck
        assert(math.abs(deck.Size.Y/2-Simulation.RING_RADIUS)<0.01,"The deck is not the size of the simulation's bowl")
        local walls,exits=0,0
        for _,piece in ipairs(stadium:GetChildren()) do
            if piece.Name=="Wall" or piece.Name=="Exit" then
                local offset=piece.Position-deck.Position
                local open=Simulation.gapAt(math.atan2(offset.Z,offset.X))
                if piece.Name=="Wall" then walls+=1; assert(not open,"A wall piece blocks a gap") else exits+=1; assert(open,"An exit is painted where there is wall") end
            end
        end
        assert(walls>40 and exits>=9 and #named(stadium,"ExitPost")==6,"The wall or its exits are missing")
    end)
    test("tops spin the way they turn, and the two are painted apart",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight",{offenceId="Drifter"},{offenceId="Drifter",wildIds={"LeftSpin"}})
        view:update(s,1/60)
        local function heading(index)
            local right=named(view.fighters[index].model,"SpinStripe")[1].CFrame.RightVector
            return math.atan2(right.Z,right.X)
        end
        local a,b=heading(1),heading(2)
        view:update(s,1/60)
        local da=(heading(1)-a+math.pi)%(2*math.pi)-math.pi
        local db=(heading(2)-b+math.pi)%(2*math.pi)-math.pi
        assert(math.abs(da)>0.1 and da*db<0,"A left-spin top does not turn the other way")
        assert(view:accent(1)~=view:accent(2),"Both tops wear the same paint")
        assert(view.fighters[1].model.Layer.Color==view:accent(1),"The top is not in its pilot's paint")
        assert(#named(view.fighters[2].model,"LeftMark")==1,"Left Spin is not marked on the top")
    end)
    test("a top wobbles more and turns slower as its spin runs down",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight")
        local function tilt(index) return math.acos(math.clamp(view.fighters[index].model.PrimaryPart.CFrame.UpVector.Y,-1,1)) end
        advance(s,0.3)
        local fresh=tilt(1)
        s.simulation.fighters[1].spin=12
        advance(s,0.3)
        assert(tilt(1)>fresh+0.15,"A slowing top does not wobble")
        assert(tilt(2)<0.15,"A top at full spin is leaning")
        assert(view.fighters[1].label.Text=="WOBBLING!","The top does not say it is in trouble")
        view.reducedMotion=true;advance(s,0.1)
        assert(tilt(1)<0.1,"Reduced motion still wobbles")
    end)
    test("a top that runs out of spin falls on its side where it is",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight")
        advance(s,0.2)
        local where=at(view.fighters[2].model)
        local loser=s.simulation.fighters[2]
        loser.spin,loser.down=0,true
        s.simulation.finished=true;s.simulation.reason="spinout";s.simulation.winner=1
        s.phase="RoundOver"
        advance(s,1.2)
        local model=view.fighters[2].model
        assert(model.PrimaryPart.CFrame.UpVector.Y<0.5,"The stopped top is still upright")
        local now=at(model)
        assert(math.abs(now.X-where.X)<0.5 and math.abs(now.Z-where.Z)<0.5 and now.Y>where.Y-1,"The stopped top left the deck")
        assert(model:GetAttribute("Phase")=="Down")
        local topples=0
        for _,cue in ipairs(cues) do if cue.kind=="topple" and cue.actor==2 then topples+=1 end; assert(cue.kind~="crash","A stopped top was treated as a fall") end
        assert(topples==1,"Missing or duplicate topple cue")
    end)
    test("a top that goes out through a gap drops out of the sky once and the winner stays put",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight")
        advance(s,0.2)
        local winner=at(view.fighters[1].model)
        local loser=s.simulation.fighters[2]
        loser.x,loser.y,loser.vx,loser.vy,loser.out=0,Simulation.RING_RADIUS+1,0,30,true
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
    test("each type has its own shape and parts are drawn on the top",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight",{offenceId="Bolt",wildIds={"Spikes","Guard"}},{offenceId="Cyclone",wildIds={"Flywheel","Heavy"}})
        view:update(s,1/60)
        local a,b=view.fighters[1].model,view.fighters[2].model
        assert(#named(a,"Blade")==3 and #named(a,"Spike")==8,"Bolt's blades or the jagged rim are missing")
        assert(#named(a,"GuardRing")==1 and #named(b,"GuardRing")==0,"The guard ring is missing or on the wrong top")
        assert(#named(b,"Band")==1 and #named(b,"Flywheel")==1 and #named(b,"Blade")==0,"Cyclone's smooth rim or its flywheel is missing")
        local plain=snapshot(2,"Fight",{offenceId="Cyclone"},{offenceId="Boulder"})
        view:update(plain,1/60)
        assert(view.fighters[2].model.Tyre and #named(view.fighters[2].model,"Stud")==8,"Boulder's tyre is missing")
        assert(b.Parent==nil,"Old tops survived a new round")
        -- The guard ring tilts with the top but does not spin with it.
        view:update(s,1/60)
        local ring=view.fighters[1].model.GuardRing
        local before=ring.CFrame
        view:update(s,1/60)
        assert((ring.CFrame.UpVector-before.UpVector).Magnitude<0.05,"The free-spinning guard is turning with the top")
    end)
    test("a new round or a changed build makes new tops, and a pick puts them away",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight")
        view:update(s,1/60)
        local first=view.fighters[1].model
        view:update(s,1/60);assert(view.fighters[1].model==first,"A repeated snapshot rebuilt the top")
        local nextRound=snapshot(2,"Countdown",{offenceId="Drifter"},{offenceId="Bolt"})
        view:update(nextRound,1/60)
        assert(first.Parent==nil and view.fighters[1].model~=first and #named(view.fighters[1].model,"Blade")==4,"The old top survived a new round")
        nextRound.phase="Pick";view:update(nextRound,1/60)
        assert(at(view.fighters[1].model).Y<-1000,"A top is still in the bowl while pilots are picking")
        assert(view.folder:GetAttribute("Phase")=="Pick" and view.folder:GetAttribute("RoundId")=="2")
    end)
    test("the camera looks down on the whole stadium and big hits shake it unless motion is reduced",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight")
        view:update(s,1/60,{left=0,right=800,top=100,bottom=600})
        local camera=workspace.CurrentCamera
        local deck=view.folder.Stadium.Deck.Position
        assert(camera.CameraType==Enum.CameraType.Scriptable and camera.CFrame.Position.Y>deck.Y+60,"The camera is not above the stadium")
        assert(camera.CFrame.LookVector.Y<-0.5,"The camera is not looking down")
        local height=view.folder:GetAttribute("VisibleHeight")
        assert(height==height and height>40 and height<300,"The frame does not hold the stadium")
        s.simulation.elapsed=4.1
        s.simulation.events={{serial=5,kind="clash",at=4.1,x=0,y=0,actor=1,target=2,power=60,source="smash"}}
        view:update(s,1/60)
        assert(view.shake>0.5 and view.screenFlash>0.3,"A big hit did not land on screen")
        view.shake,view.screenFlash,view.reducedMotion=0,0,true
        s.simulation.elapsed=4.2
        s.simulation.events={{serial=6,kind="clash",at=4.2,x=0,y=0,actor=1,target=2,power=60,source="smash"}}
        view:update(s,1/60)
        assert(view.shake<0.5,"Reduced motion still shakes hard")
    end)
    test("an old event is not replayed and effects leave with the view",function(view,cues,advance,snapshot)
        local s=snapshot(1,"Fight")
        s.simulation.elapsed=10
        s.simulation.events={{serial=3,kind="clash",at=2,x=0,y=0,actor=1,target=2,power=60,source="smash"}}
        view:update(s,1/60)
        assert(view.shake==0 and view.lastEvent==3,"A stale event shook the screen or was not consumed")
        assert(Lighting:FindFirstChild("SkyboundBattleBloom") and Lighting:FindFirstChild("SkyboundBattleGrade"))
        view:destroy();view:destroy()
        assert(not Lighting:FindFirstChild("SkyboundBattleBloom") and not Lighting:FindFirstChild("SkyboundBattleGrade"),"Lighting effects outlived the view")
        view:update(s,1/60)
    end)
    return tostring(passed).." battle-view tests passed"
end
