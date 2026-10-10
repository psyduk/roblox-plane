"""Run the real Pop Duel server/simulation with Roblox service doubles.

    python3 scripts/test_peg_server.py

Requires optional Lupa. These scenarios validate authoritative game rules,
not Roblox replication, rendered UI, or real character/network behavior.
"""
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError as error:
    raise SystemExit("Pop Duel server tests require lupa: python3 -m pip install lupa") from error

ROOT = Path(__file__).resolve().parents[1]


def make_runtime(studio=True):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.execute(r'''
    Harness={time=10,sent={},logs={},studio=true,storeRequests=0}
    math.clamp=function(v,lo,hi)return math.max(lo,math.min(hi,v))end
    math.round=function(v)return math.floor(v+0.5)end
    table.clone=function(t)local r={}for k,v in pairs(t)do r[k]=v end return r end
    table.clear=function(t)for k in pairs(t)do t[k]=nil end end
    table.find=function(t,v)for i,item in ipairs(t)do if item==v then return i end end end
    local vector={}
    vector.__index=function(t,k)if k=='Magnitude'then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z)end return vector[k]end
    Vector3={new=function(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vector)end}
    Vector3.zero=Vector3.new()
    vector.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
    vector.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
    CFrame={new=function(x,y,z)return {Position=type(x)=='table'and x or Vector3.new(x,y,z)}end}
    local function signal()
     local s={callbacks={}}
     function s:Connect(fn)table.insert(self.callbacks,fn)return {Disconnect=function()end}end
     function s:Fire(...)for _,fn in ipairs(self.callbacks)do fn(...)end end
     return s
    end
    local function obj(name,class)
     local o={Name=name,ClassName=class or name,children={},attributes={}}
     function o:WaitForChild(n)return self.children[n]end
     function o:FindFirstChild(n)return self.children[n]end
     function o:FindFirstChildOfClass(n)return self.children[n]end
     function o:SetAttribute(k,v)self.attributes[k]=v end
     function o:GetAttribute(k)return self.attributes[k]end
     function o:IsA(k)return self.ClassName==k or (k=='BasePart'and self.ClassName=='Part')end
     function o:IsDescendantOf(parent)local current=self.Parent;while current do if current==parent then return true end;current=current.Parent end;return false end
     return setmetatable(o,{__index=function(t,k)return t.children[k]end,__newindex=function(t,k,v)rawset(t,k,v)if k=='Parent'and v then v.children[t.Name]=t end end})
    end
    Instance={new=function(k)return obj(k,k)end}
    local players=obj('Players');players.players={};players.PlayerAdded=signal();players.PlayerRemoving=signal()
    function players:GetPlayers()return self.players end
    local run=obj('RunService');run.Heartbeat=signal();function run:IsStudio()return Harness.studio end
    local storage=obj('ServerStorage');local replicated=obj('ReplicatedStorage');local shared=obj('PegGame');shared.Parent=replicated
    local command=obj('Command');command.OnServerEvent=signal();command.Parent=shared
    local snapshots=obj('Snapshot');snapshots.Parent=shared
    function snapshots:FireClient(player,data)Harness.sent[player.UserId]=data end
    local prompts={PromptTriggered=signal()}
    workspace=obj('Workspace');function workspace:GetServerTimeNow()return Harness.time end
    local lobby=obj('PegLobby');lobby.Parent=workspace
    local world={LOBBY_SPAWN=Vector3.new(0,6,28),buildLobby=function()Harness.built=true end}
    shared.children.PegWorld={module=world}
    shared.children.PegPowers={};shared.children.PegSimulation={}
    local services={Players=players,RunService=run,ServerStorage=storage,ReplicatedStorage=replicated,ProximityPromptService=prompts}
    game={GetService=function(_,n)
     if n=='DataStoreService'then Harness.storeRequests=Harness.storeRequests+1;error('Pop Duel must never request legacy player data')end
     return assert(services[n],n)
    end}
    function game:BindToClose(fn)Harness.close=fn end
    script=obj('PegServer')
    require=function(module)return assert(module.module,'missing module')end
    print=function(...)table.insert(Harness.logs,{...})end
    warn=print
    task={defer=function(fn,...)fn(...)end,spawn=function(fn,...)fn(...)end}
    function Harness.character(player)
     local character=obj('Character');local root=obj('HumanoidRootPart','Part');root.Position=Vector3.new(0,6,28);root.Parent=character
     function character:PivotTo(cf)root.Position=cf.Position end
     player.Character=character
     return character
    end
    function Harness.add(id)
     local p=obj('Player'..id,'Player');p.UserId=id;p.DisplayName='Player'..id;p.Name='Player'..id;p.CharacterAdded=signal();p.Parent=players
     Harness.character(p);table.insert(players.players,p);players.PlayerAdded:Fire(p);return p
    end
    function Harness.respawn(p)p.CharacterAdded:Fire(Harness.character(p))end
    function Harness.remove(p)
     players.PlayerRemoving:Fire(p)
     for i=#players.players,1,-1 do if players.players[i]==p then table.remove(players.players,i)end end
    end
    function Harness.advance(seconds,dt)
     dt=dt or 1/60
     local elapsed=0
     while elapsed<seconds do local step=math.min(dt,seconds-elapsed);elapsed=elapsed+step;Harness.time=Harness.time+step;run.Heartbeat:Fire(step)end
    end
    function Harness.send(p,kind,extra)
     local payload=extra or {};payload.kind=kind;command.OnServerEvent:Fire(p,payload)
    end
    function Harness.raw(p,payload)command.OnServerEvent:Fire(p,payload)end
    function Harness.latest(p)return Harness.sent[p.UserId]end
    function Harness.debug(action,data)return assert(storage.PegDebug,'missing debug').OnInvoke(action,data)end
    function Harness.start(a,b)Harness.send(a,'join');Harness.send(b,'join');assert(Harness.latest(a).phase=='Aim')end
    function Harness.launch(a,b,angle)
     Harness.send(a,'ready',{angle=angle or 0});if b then Harness.send(b,'ready',{angle=angle or 0})end
     Harness.advance(2.2);assert(Harness.latest(a).phase=='Shot')
    end
    function Harness.prompt(p,kind,position,external)
     local part=obj('Arcade','Part');part.Position=position or Vector3.new(0,6,28);part.Parent=external and workspace or lobby
     local prompt=obj('PlayPrompt','ProximityPrompt');prompt.Parent=part;prompt.MaxActivationDistance=10;prompt:SetAttribute('PegCommand',kind)
     prompts.PromptTriggered:Fire(prompt,p)
    end
    Harness.shared=shared;Harness.services=services
    ''')
    runtime.globals().Harness.studio = studio
    powers = runtime.execute((ROOT / 'src/shared/PegPowers.luau').read_text())
    runtime.globals().Harness.shared.children.PegPowers.module = powers
    runtime.globals().script.Parent = runtime.globals().Harness.shared
    simulation = runtime.execute((ROOT / 'src/shared/PegSimulation.luau').read_text())
    runtime.globals().Harness.shared.children.PegSimulation.module = simulation
    runtime.execute((ROOT / 'src/server/PegServer.server.luau').read_text())
    return runtime


SCENARIOS = {
    "FIFO queue pairs distinct players, isolates duels, and cancels cleanly": r'''
        local a,b,c,d,e=Harness.add(101),Harness.add(102),Harness.add(103),Harness.add(104),Harness.add(105)
        Harness.send(a,'join');Harness.advance(.1);Harness.send(a,'join')
        assert(Harness.latest(a).phase=='Queued' and Harness.latest(a).queuedCount==1)
        Harness.send(b,'join');Harness.send(c,'join');Harness.send(d,'join');Harness.send(e,'join')
        local sa,sc=Harness.latest(a),Harness.latest(c)
        assert(sa.phase=='Aim' and sa.matchId~=sc.matchId and #sa.players==2)
        assert(sa.players[1].userId==101 and sa.players[2].userId==102)
        assert(sc.players[1].userId==103 and sc.players[2].userId==104)
        assert(sa.seed==Harness.latest(b).seed and sa.board==Harness.latest(b).board)
        assert(Harness.latest(e).phase=='Queued' and Harness.latest(e).queuedCount==1)
        Harness.send(e,'cancel');assert(Harness.latest(e).phase=='Lobby' and Harness.latest(e).queuedCount==0)
        assert(a.Character.HumanoidRootPart.Anchored and not e.Character.HumanoidRootPart.Anchored)
    ''',
    "practice clears queue, has one honest ghost, and uses real simulation": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.send(a,'join');Harness.send(a,'practice')
        local s=Harness.latest(a)
        assert(s.practice and s.phase=='Aim' and s.queuedCount==0 and #s.players==2)
        assert(s.players[2].isGhost and s.players[2].ready and s.players[2].name=='Practice Ghost')
        assert(Harness.latest(b).phase=='Lobby')
        local sim=Harness.shared.PegSimulation.module
        local ghost=sim.newShot(s.board,{angle=s.players[2].angle,powerId=s.players[2].powerId})
        while not ghost.done do sim.step(ghost,s.board,sim.FIXED_DT or 1/120)end
        -- Find an actual winning shot without treating any tuning-specific angle
        -- as a gameplay promise. The server must account for that real win.
        local winningAngle
        for angle=-60,60,5 do
            local candidate=sim.newShot(s.board,{angle=angle,powerId='pulse'})
            while not candidate.done do sim.step(candidate,s.board,sim.FIXED_DT or 1/120)end
            if candidate.score>ghost.score then winningAngle=angle;break end
        end
        assert(winningAngle,'candidate set has no winning practice shot')
        Harness.launch(a,nil,winningAngle)
        Harness.advance(26)
        local result=Harness.latest(a)
        assert(result.phase=='Results' and result.players[2].shot.score==ghost.score)
        assert(result.stats.rounds==1 and result.statsSessionOnly and Harness.storeRequests==0)
        assert(result.result.winnerId==a.UserId and result.stats.wins==0)
        assert(result.stats.practiceRounds==1 and result.stats.practiceWins==1)
        assert(result.stats.bestScore==result.players[1].shot.score)
    ''',
    "identical human choices simulate independent but equal shots and record one draw": r'''
        local a,b=Harness.add(101),Harness.add(102);Harness.start(a,b);Harness.launch(a,b,12)
        Harness.advance(26)
        local s=Harness.latest(a)
        assert(s.phase=='Results' and s.result.draw and s.result.winnerId==0)
        assert(s.players[1].shot.score==s.players[2].shot.score and s.players[1].shot.done)
        assert(s.stats.rounds==1 and s.stats.wins==0 and s.stats.bestScore==s.players[1].shot.score)
        Harness.advance(1);Harness.send(a,'ready');Harness.advance(.1)
        assert(Harness.latest(a).stats.rounds==1)
        assert(Harness.latest(b).stats.bestScore==s.stats.bestScore)
    ''',
    "aim and power changes unready, atomic ready rejects malformed and spoofed settings": r'''
        local a,b=Harness.add(101),Harness.add(102);Harness.start(a,b)
        Harness.send(a,'ready',{angle=11});assert(Harness.latest(a).players[1].ready)
        Harness.send(a,'aim',{angle=22});assert(not Harness.latest(a).players[1].ready)
        for _,bad in ipairs({{angle=0/0},{angle=math.huge},{angle='9'},{powerId={id='pulse'}},{angle=44,powerId='invented'},
            {angle=20,ready=1},{angle=34,score=999999},{angle=33,userId=102},{angle=55,speed=999}})do
            Harness.advance(.1);Harness.send(a,'ready',bad)
            local own=Harness.latest(a).players[1];assert(not own.ready and own.angle==22)
        end
        Harness.advance(.1);Harness.send(a,'ready',{angle=1000,powerId='pulse'})
        assert(Harness.latest(a).players[1].angle==65 and Harness.latest(a).players[1].ready)
        Harness.send(a,'power',{powerId='pulse'});assert(not Harness.latest(a).players[1].ready)
        Harness.advance(.1);Harness.send(a,'aim',{angle=-999});assert(Harness.latest(a).players[1].angle==-65)
        Harness.raw(a,'ready');Harness.raw(a,{kind={}});Harness.raw(a,{kind='score',score=999})
        assert(Harness.latest(a).players[2].angle==0)
    ''',
    "countdown locks settings and phase deadlines auto-launch unready players": r'''
        local a,b=Harness.add(101),Harness.add(102);Harness.start(a,b)
        Harness.advance(14.9);assert(Harness.latest(a).phase=='Aim')
        Harness.advance(.3);assert(Harness.latest(a).phase=='Countdown')
        Harness.send(a,'aim',{angle=60});Harness.send(a,'power',{powerId='split'});Harness.send(a,'ready',{ready=false})
        Harness.advance(2.1)
        local own=Harness.latest(a).players[1]
        assert(Harness.latest(a).phase=='Shot' and own.angle==0 and own.powerId=='pulse' and own.ready)
        assert(own.shot.powerId=='pulse')
        Harness.advance(26);assert(Harness.latest(a).phase=='Results')
        Harness.advance(90.2);assert(Harness.latest(a).phase=='Lobby' and Harness.latest(b).phase=='Lobby')
        assert(not a.Character.HumanoidRootPart.Anchored and a.Character.HumanoidRootPart.Position.Z==28)
    ''',
    "stale match and round identifiers cannot alter a current round": r'''
        local a=Harness.add(101);Harness.send(a,'practice')
        local old=Harness.latest(a)
        Harness.send(a,'ready',{angle=31,matchId=old.matchId+1,roundId=old.roundId})
        assert(not Harness.latest(a).players[1].ready)
        Harness.advance(.1);Harness.launch(a);Harness.advance(26)
        Harness.send(a,'rematch',{matchId=old.matchId,roundId=old.roundId})
        local current=Harness.latest(a);assert(current.phase=='Aim' and current.roundId==old.roundId+1)
        Harness.advance(.1);Harness.send(a,'ready',{angle=51,matchId=old.matchId,roundId=old.roundId})
        Harness.send(a,'returnLobby',{matchId=old.matchId,roundId=old.roundId})
        assert(Harness.latest(a).phase=='Aim' and not Harness.latest(a).players[1].ready)
        Harness.advance(.1);Harness.send(a,'ready',{angle=23,matchId=current.matchId,roundId=current.roundId})
        assert(Harness.latest(a).players[1].angle==23 and Harness.latest(a).players[1].ready)
    ''',
    "shot departure forfeits regardless of points and attached survivor cannot rematch": r'''
        local a,b=Harness.add(101),Harness.add(102);Harness.start(a,b)
        Harness.send(a,'ready',{angle=-15});Harness.send(b,'ready',{angle=0});Harness.advance(2.2)
        local before=Harness.latest(a)
        for _=1,100 do
            if before.phase~='Shot' or before.players[1].shot.score~=before.players[2].shot.score then break end
            Harness.advance(.1);before=Harness.latest(a)
        end
        assert(before.phase=='Shot' and before.players[1].shot.score~=before.players[2].shot.score)
        local ahead=before.players[1].shot.score>before.players[2].shot.score
        local leaver= ahead and a or b;local survivor=ahead and b or a
        Harness.send(leaver,'returnLobby')
        local s=Harness.latest(survivor)
        assert(Harness.latest(leaver).phase=='Lobby' and s.phase=='Results' and s.result.winnerId==survivor.UserId)
        assert(s.result.reason=='forfeit' and s.players[ahead and 1 or 2].forfeit and not s.canRematch)
        assert(s.stats.wins==1 and s.stats.rounds==1 and s.stats.bestScore==0)
        assert(Harness.latest(leaver).stats.wins==0 and Harness.latest(leaver).stats.rounds==1)
        Harness.send(survivor,'rematch');assert(Harness.latest(survivor).phase=='Results')
        Harness.send(leaver,'practice');assert(Harness.latest(leaver).phase=='Aim' and Harness.latest(leaver).matchId~=s.matchId)
        assert(Harness.latest(survivor).matchId==s.matchId)
    ''',
    "disconnect cancels prelaunch matches without counting a round": r'''
        for _,phase in ipairs({'Aim','Countdown'})do
            local a,b=Harness.add(101),Harness.add(102);Harness.start(a,b)
            if phase=='Countdown'then Harness.send(a,'ready');Harness.send(b,'ready');Harness.advance(.2)end
            assert(Harness.latest(b).phase==phase)
            Harness.remove(a);Harness.advance(.2)
            assert(Harness.latest(b).phase=='Lobby' and Harness.latest(b).stats.rounds==0)
            assert(not b.Character.HumanoidRootPart.Anchored and Harness.shared:GetAttribute('ActiveDuels')==0)
            Harness.remove(b)
        end
    ''',
    "queued disconnect leaves no phantom opponent, shot disconnect awards win": r'''
        local a,b=Harness.add(101),Harness.add(102);Harness.send(a,'join');Harness.remove(a);Harness.send(b,'join')
        assert(Harness.latest(b).phase=='Queued' and Harness.latest(b).queuedCount==1)
        local c=Harness.add(103);Harness.send(c,'join');Harness.launch(b,c)
        Harness.remove(c);Harness.advance(.2)
        local s=Harness.latest(b);assert(s.phase=='Results' and s.result.winnerId==b.UserId and s.stats.wins==1)
        assert(not s.canRematch)
    ''',
    "human rematch requires both votes and resets shots, flags, board and readiness": r'''
        local a,b=Harness.add(101),Harness.add(102);Harness.start(a,b);Harness.launch(a,b);Harness.advance(26)
        local old=Harness.latest(a);assert(old.phase=='Results')
        Harness.send(a,'rematch');assert(Harness.latest(a).phase=='Results' and Harness.latest(a).rematchReady)
        Harness.send(b,'rematch');local fresh=Harness.latest(a)
        assert(fresh.phase=='Aim' and fresh.roundId==old.roundId+1 and fresh.seed~=old.seed and fresh.result==nil)
        assert(not fresh.rematchReady and not fresh.players[1].ready and not fresh.players[2].ready)
        assert(not fresh.players[1].shot and fresh.stats.rounds==1)
        Harness.send(a,'returnLobby');assert(Harness.latest(b).phase=='Lobby')
    ''',
    "respawns remain frozen in match and restore correctly after leaving": r'''
        local a=Harness.add(101);Harness.send(a,'practice');Harness.respawn(a)
        assert(a.Character.HumanoidRootPart.Anchored and a.Character.HumanoidRootPart.Position.Y==1000)
        Harness.send(a,'returnLobby');Harness.respawn(a)
        assert(not a.Character.HumanoidRootPart.Anchored and a.Character.HumanoidRootPart.Position.Z==28)
    ''',
    "lobby prompts require the right ancestry, distance, and valid command": r'''
        local a=Harness.add(101)
        Harness.prompt(a,'practice',Vector3.new(100,6,28));assert(Harness.latest(a).phase=='Lobby')
        Harness.prompt(a,'practice',nil,true);assert(Harness.latest(a).phase=='Lobby')
        Harness.prompt(a,'ready');assert(Harness.latest(a).phase=='Lobby')
        Harness.prompt(a,'practice');assert(Harness.latest(a).phase=='Aim')
    ''',
    "command spam is bounded and session stats reset after rejoin": r'''
        local a=Harness.add(101);Harness.send(a,'practice')
        for index=1,100 do Harness.send(a,'aim',{angle=index})end
        assert(Harness.latest(a).players[1].angle==1)
        Harness.send(a,'ready');assert(not Harness.latest(a).players[1].ready)
        Harness.advance(2);Harness.send(a,'ready');assert(Harness.latest(a).players[1].ready)
        Harness.advance(29);assert(Harness.latest(a).stats.rounds==1)
        Harness.remove(a);local b=Harness.add(101)
        assert(Harness.latest(b).stats.rounds==0 and Harness.latest(b).stats.bestScore==0 and Harness.storeRequests==0)
    ''',
    "Studio diagnostics run normal simulation without leaking virtual deadlines": r'''
        local a=Harness.add(101)
        assert(Harness.debug('start',{userId=a.UserId}))
        local s=Harness.debug('launch',{userId=a.UserId});assert(s.phase=='Shot')
        local final=Harness.debug('advance',{userId=a.UserId,seconds=26})
        assert(final.phase=='Results' and final.stats.rounds==1)
        assert(final.phaseEndsAt>Harness.time and final.phaseEndsAt<=Harness.time+90)
        assert(Harness.debug('snapshots')['101'].matchId==final.matchId)
    ''',
}


def main():
    for name, scenario in SCENARIOS.items():
        runtime = make_runtime()
        try:
            runtime.execute(scenario)
        except Exception as error:
            raise AssertionError(f"FAILED: {name}\n{error}") from error
        print(f"PASS: {name}")
    runtime = make_runtime(studio=False)
    runtime.execute('assert(not Harness.services.ServerStorage.PegDebug); local a=Harness.add(1); Harness.send(a,"practice"); assert(Harness.latest(a).phase=="Aim" and Harness.storeRequests==0)')
    print('PASS: published servers omit Studio diagnostics and never open player stores')
    print(f'{len(SCENARIOS)+1} Pop Duel server scenarios passed')


if __name__ == '__main__':
    main()
