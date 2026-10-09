"""Exercise the real server and Simulation modules with in-memory Roblox service doubles.

Run: python3 scripts/test_server.py
Requires the optional test dependency: python3 -m pip install lupa

Only Luau compound assignment, generic iteration, and the single match-loop
continue are translated for Lua. This validates matchmaking/control flow, not
Roblox replication, character physics, UI, or real network timing.
"""
from pathlib import Path
import re
from lua_modules import load_simulation

try:
    from lupa import LuaRuntime
except ImportError as error:
    raise SystemExit("Server tests require lupa: python3 -m pip install lupa") from error

ROOT = Path(__file__).resolve().parents[1]


def make_runtime(studio=True, published=False):
    L=LuaRuntime(unpack_returned_tuples=True)
    L.execute(r'''
    Harness={time=10,sent={},logs={},delays={}}
    math.clamp=function(v,lo,hi)return math.max(lo,math.min(hi,v))end
    math.round=function(v)return math.floor(v+0.5)end
    table.clone=function(t)local r={}for k,v in pairs(t)do r[k]=v end return r end
    table.find=function(t,v)for i,a in ipairs(t)do if a==v then return i end end end
    table.clear=function(t)for k in pairs(t)do t[k]=nil end end
    local vector={};vector.__index=function(t,k)if k=='Magnitude'then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z)end return vector[k]end
    Vector3={new=function(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vector)end};Vector3.zero=Vector3.new(0,0,0)
    vector.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
    vector.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
    CFrame={new=function(x,y,z)return {Position=type(x)=='table'and x or Vector3.new(x,y,z)}end}
    local function signal()local s={callbacks={}};function s:Connect(fn)table.insert(self.callbacks,fn)return {Disconnect=function()end}end;function s:Fire(...)for _,fn in ipairs(self.callbacks)do fn(...)end end;return s end
    local function obj(name)
     local o={Name=name,children={},attributes={}}
     function o:WaitForChild(n)return self.children[n]end
     function o:FindFirstChild(n)return self.children[n]end
     function o:FindFirstChildOfClass(n)return self.children[n]end
     function o:SetAttribute(k,v)self.attributes[k]=v end
     function o:GetAttribute(k)return self.attributes[k]end
     function o:GetChildren()local r={}for _,v in pairs(self.children)do table.insert(r,v)end return r end
     return setmetatable(o,{__index=function(t,k)return t.children[k]end,__newindex=function(t,k,v)rawset(t,k,v)if k=='Parent'and v then v.children[t.Name]=t end end})
    end
    Instance={new=function(k)local o=obj(k);o.ClassName=k;function o:Destroy()if self.Parent then self.Parent.children[self.Name]=nil end self.Parent=nil end;return o end}
    local players=obj('Players');players.players={};players.PlayerAdded=signal();players.PlayerRemoving=signal()
    function players:GetPlayers()return self.players end
    function players:GetPlayerByUserId(id)for _,p in ipairs(self.players)do if p.UserId==id then return p end end end
    local run=obj('RunService');run.Heartbeat=signal();function run:IsStudio()return true end
    local storage=obj('ServerStorage');local replicated=obj('ReplicatedStorage');local shared=obj('FlightGame');replicated.children.FlightGame=shared
    local command=obj('Command');command.OnServerEvent=signal();shared.children.Command=command
    local snapshots=obj('Snapshot');shared.children.Snapshot=snapshots
    function snapshots:FireClient(player,data)Harness.sent[player.UserId]=data end
    function snapshots:FireAllClients(data)for _,p in ipairs(players.players)do Harness.sent[p.UserId]=data end end
    workspace=obj('Workspace');function workspace:GetServerTimeNow()return Harness.time end
    local world={LOBBY_SPAWN=Vector3.new(0,7,0),DUEL_STATIONS={},buildLobby=function()end,updateLobbyQueues=function(counts)Harness.queueCounts=counts end}
    for index,x in ipairs({-81,-27,27,81})do table.insert(world.DUEL_STATIONS,{id='duel'..index,name='DUEL '..index,seats={Vector3.new(x-8,4.3,-47),Vector3.new(x+8,4.3,-47)}})end
    shared.World={module=world}
    shared.Simulation={}
    local function deepCopy(value)if type(value)~='table'then return value end local result={}for k,v in pairs(value)do result[k]=deepCopy(v)end return result end
    Harness.store={values={},calls=0,getCalls=0,failures=0}
    function Harness.store:UpdateAsync(key,transform)
     self.calls=self.calls+1
     if self.failures>0 then self.failures=self.failures-1;error('mock store failure')end
     local value=transform(deepCopy(self.values[key]))
     if value~=nil then self.values[key]=deepCopy(value)end
     return deepCopy(value)
    end
    Harness.analytics={}
    local analytics={LogCustomEvent=function(_,player,name,value,fields)table.insert(Harness.analytics,{player=player,name=name,value=value,fields=fields})end}
    local datastore={GetDataStore=function()Harness.store.getCalls=Harness.store.getCalls+1;return Harness.store end}
    local services={Players=players,RunService=run,ServerStorage=storage,ReplicatedStorage=replicated,
     HttpService={JSONEncode=function()return '{}'end,GenerateGUID=function()return 'mock-server-session' end},
     AnalyticsService=analytics,DataStoreService=datastore,Workspace=workspace,ServerScriptService=obj('ServerScriptService')}
    game={GameId=0,GetService=function(_,n)return assert(services[n],n)end}
    Harness.closeCallbacks={}
    function game:BindToClose(callback)table.insert(Harness.closeCallbacks,callback)end
    function Harness.shutdown()for _,callback in ipairs(Harness.closeCallbacks)do callback()end end
    script=obj('FlightServer');script.Parent=services.ServerScriptService
    require=function(o)return assert(o.module,'missing mock module')end
    print=function(...)table.insert(Harness.logs,{...})end
    warn=print
    task={defer=function(fn,...)fn(...)end,spawn=function(fn,...)fn(...)end,
     wait=function(seconds)Harness.time=Harness.time+(seconds or 0);return seconds end,
     delay=function(seconds,fn,...)table.insert(Harness.delays,{at=Harness.time+seconds,fn=fn,args={...}})end}
    function Harness.add(id,x,z)
     local p=obj('Player'..id);p.UserId=id;p.DisplayName='Pilot'..id;p.Name='Pilot'..id;p.CharacterAdded=signal();p.Parent=players
     local character=obj('Character');local root=obj('HumanoidRootPart');root.Position=Vector3.new(x or 0,7,z or 0);character.children.HumanoidRootPart=root
     local humanoid=obj('Humanoid');humanoid.Health=100;humanoid.WalkSpeed=16;character.children.Humanoid=humanoid
     function character:PivotTo(cf)root.Position=cf.Position end
     p.Character=character;table.insert(players.players,p);players.PlayerAdded:Fire(p);return p
    end
    function Harness.move(p,station,seat)local v=world.DUEL_STATIONS[station].seats[seat];p.Character.children.HumanoidRootPart.Position=Vector3.new(v.X,v.Y+3,v.Z)end
    function Harness.remove(p)players.PlayerRemoving:Fire(p);for i=#players.players,1,-1 do if players.players[i]==p then table.remove(players.players,i)end end;p.Parent=nil end
    function Harness.advance(seconds,dt)
     dt=dt or 1/60
     for _=1,math.ceil(seconds/dt)do
      Harness.time=Harness.time+dt
      for i=#Harness.delays,1,-1 do local d=Harness.delays[i];if Harness.time>=d.at then table.remove(Harness.delays,i);d.fn(table.unpack(d.args))end end
      run.Heartbeat:Fire(dt)
     end
    end
    function Harness.send(p,kind,extra)local payload=extra or {};payload.kind=kind;command.OnServerEvent:Fire(p,payload)end
    function Harness.latest(p)return Harness.sent[p.UserId]end
    function Harness.readyDuel(a,b)
     assert(Harness.latest(a).phase=='Configure')
     Harness.send(a,'ready',{ready=true});if b then Harness.send(b,'ready',{ready=true})end
     Harness.advance(1.2)
     assert(Harness.latest(a).phase=='Aim' and not Harness.latest(a).players[1].ready)
     Harness.send(a,'ready',{ready=true});if b then Harness.send(b,'ready',{ready=true})end
     Harness.advance(4.3)
     assert(Harness.latest(a).phase=='Flight')
    end
    function Harness.debug(action,data)return assert(storage.children.FlightDebug,'missing debug').OnInvoke(action,data)end
    Harness.services=services;Harness.shared=shared
    ''')
    L.globals().Harness.studio = studio
    L.globals().game.GameId = 123 if published else 0
    L.execute('function Harness.services.RunService:IsStudio()return Harness.studio end')
    simulation, catalog = load_simulation(L)
    L.globals().Harness.shared.Simulation.module=simulation
    L.globals().Harness.shared.PlaneCatalog=L.table_from({'module':catalog})
    L.globals().Harness.shared.PowerCatalog=L.table_from({'module':L.execute((ROOT/'src/shared/PowerCatalog.luau').read_text())})
    L.globals().Harness.services.ServerStorage.children.SimulationTests=L.table_from({'module':L.execute((ROOT/'tests/Simulation.spec.luau').read_text())})
    for name in ('PlayerStats', 'Telemetry'):
        module=L.execute((ROOT/f'src/server/{name}.luau').read_text())
        L.globals().Harness.services.ServerScriptService.children[name]=L.table_from({'module':module})
    source=(ROOT/'src/server/Main.server.luau').read_text()
    source=re.sub(r'([\w.\[\]]+)\s*([+\-])=\s*(.+?)(?=\s+end|;|$)',lambda m:f'{m[1]} = {m[1]} {m[2]} ({m[3]})',source,flags=re.M)
    source=re.sub(r'for\s+([\w_, ]+)\s+in\s+([\w.]+)\s+do',r'for \1 in pairs(\2) do',source)
    source=source.replace('for id,m in pairs(matches) do\n', 'for id,m in pairs(matches) do\n do\n').replace('continue end', 'goto continue_match end').replace('    end\n    broadcastAccumulator', ' end\n ::continue_match::\n    end\n    broadcastAccumulator')
    L.execute(source)
    return L

SCENARIOS = {
    "power identity is validated and locks before launch": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.debug('forcePair',{ids={a.UserId,b.UserId}});Harness.debug('configure',{userId=a.UserId})
        for _,bad in ipairs({'Unknown','',42,false,{}})do
            local result=Harness.debug('validateSettings',{planeId='cruiser',angle=35,gadget='Shield',color=1,powerId=bad})
            assert(result==nil,'invalid power identity accepted')
        end
        Harness.send(a,'configure',{settings={planeId='cruiser',angle=25,gadget='Magnet',color=1,powerId='Muncher',powerCharges=999,powerPhase='spent'}})
        Harness.send(b,'configure',{settings={planeId='cruiser',angle=55,gadget='Shield',color=2,powerId='Meteor'}})
        Harness.advance(0.2)
        assert(Harness.latest(a).players[1].settings.powerId=='Muncher')
        assert(Harness.latest(a).players[1].settings.powerCharges==nil)
        Harness.debug('aim',{userId=a.UserId})
        for _,kind in ipairs({'configure','ready'})do
            Harness.send(a,kind,{ready=true,settings={angle=45,powerId='Pinball'}});Harness.advance(0.1)
            local own=Harness.latest(a).players[1]
            assert(own.settings.powerId=='Muncher' and own.settings.angle==25 and not own.ready)
        end
        Harness.send(a,'ready',{ready=true,settings={angle=25,powerId='Muncher'}})
        Harness.send(b,'ready',{ready=true});Harness.advance(4.2)
        local s=Harness.latest(a)
        assert(s.phase=='Flight')
        assert(s.players[1].flight.powerId=='Muncher' and s.players[2].flight.powerId=='Meteor')
        assert(s.players[1].flight.powerCharges==3 and s.players[2].flight.powerCharges==1)
        for _,p in ipairs(s.players)do assert(p.flight.shield==0 and p.flight.powerPhase=='armed' and p.flight.powerUses==0)end
        Harness.send(a,'configure',{settings={planeId='cruiser',angle=25,gadget='Shield',color=1,powerId='Pinball'}})
        Harness.advance(0.2);assert(Harness.latest(a).players[1].flight.powerId=='Muncher')
    ''',
    "each round starts with fresh power charges for both pilots": r'''
        local a=Harness.add(101)
        Harness.send(a,'configure',{settings={planeId='dart',angle=15,gadget='Boost',color=1,powerId='Pinball'}})
        Harness.send(a,'practice');Harness.debug('launch',{userId=a.UserId})
        Harness.advance(46)
        local first=Harness.latest(a)
        assert(first.phase=='Results' and first.players[1].flight.powerUses>0)
        Harness.send(a,'rematch');Harness.debug('configure',{userId=a.UserId})
        Harness.send(a,'configure',{settings={planeId='dart',angle=15,gadget='Boost',color=1,powerId='Muncher'}})
        Harness.debug('launch',{userId=a.UserId})
        local second=Harness.debug('snapshot',{userId=a.UserId})
        assert(second.players[1].flight.powerId=='Muncher' and second.players[1].flight.powerCharges==3)
        assert(second.players[1].flight.powerUses==0 and second.players[1].flight.shield==0)
        for _,p in ipairs(second.players)do assert(p.flight.powerUses==0 and p.flight.powerPhase=='armed')end
    ''',
    "aim locks the loadout while accepting only bounded angle changes": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.send(a,'configure',{settings={planeId='dart',angle=24,gadget='Magnet',color=3}})
        Harness.debug('forcePair',{ids={a.UserId,b.UserId}});Harness.debug('configure',{userId=a.UserId})
        Harness.debug('aim',{userId=a.UserId})
        for _,bad in ipairs({
            {planeId='skyhopper',angle=55,gadget='Magnet',color=3},
            {planeId='dart',angle=55,gadget='Boost',color=3},
            {planeId='dart',angle=55,gadget='Magnet',color=4},
            {angle=55,speed=999},{angle=55,power=100},{angle=0/0}
        })do
            for _,command in ipairs({'configure','ready'})do
                Harness.send(a,command,{ready=true,settings=bad});Harness.advance(0.1)
                local s=Harness.latest(a)
                local own=s.players[1]
                assert(s.phase=='Aim' and not own.ready and own.settings.angle==24)
                assert(own.settings.planeId=='dart' and own.settings.gadget=='Magnet' and own.settings.color==3 and own.settings.speed==81)
            end
        end
        Harness.send(a,'configure',{settings={angle=31.6}});Harness.advance(0.1)
        assert(Harness.latest(a).players[1].settings.angle==32)
        Harness.send(a,'ready',{ready=true,settings={planeId='dart',angle=41,gadget='Magnet',color=3,speed=81}});Harness.advance(0.1)
        assert(Harness.latest(a).players[1].ready and Harness.latest(a).players[1].settings.angle==41)
        Harness.send(a,'configure',{settings={angle=-99}});Harness.advance(0.1)
        assert(not Harness.latest(a).players[1].ready and Harness.latest(a).players[1].settings.angle==15)
        assert(Harness.latest(a).players[2].settings.angle==35)
        Harness.send(a,'ready',{ready=true,settings={angle=999}})
        Harness.send(b,'ready',{ready=true});Harness.advance(0.2)
        assert(Harness.latest(a).phase=='Countdown' and Harness.latest(a).players[1].settings.angle==60)
    ''',
    "configuration readiness resets for aiming and the new phase observes its guard": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.debug('forcePair',{ids={a.UserId,b.UserId}});Harness.debug('configure',{userId=a.UserId})
        Harness.send(a,'ready',{ready=true});Harness.advance(1.2)
        assert(Harness.latest(a).phase=='Configure')
        Harness.send(b,'ready',{ready=true});Harness.advance(0.1)
        assert(Harness.latest(a).phase=='Aim')
        for _,entry in ipairs(Harness.latest(a).players)do assert(not entry.ready and not entry.flight)end
        Harness.send(a,'ready',{ready=true});Harness.send(b,'ready',{ready=true});Harness.advance(0.3)
        assert(Harness.latest(a).phase=='Aim','Aim skipped its minimum visibility guard')
        Harness.advance(0.8)
        assert(Harness.latest(a).phase=='Countdown')
        Harness.advance(3)
        assert(Harness.latest(a).phase=='Flight')
    ''',
    "plane catalog is free and server rejects unknown IDs speed spoofing and obsolete power": r'''
        local catalog=Harness.shared.PlaneCatalog.module
        assert(#catalog.ORDER==3 and catalog.DEFAULT_ID=='cruiser')
        local a=Harness.add(101)
        assert(Harness.latest(a).players[1].settings.planeId=='cruiser')
        for _,bad in ipairs({
            {planeId='paid_plane',angle=35,gadget='Shield',color=1},
            {planeId='dart',angle=35,speed=999,gadget='Shield',color=1},
            {planeId='dart',angle=35,launchSpeed=999,gadget='Shield',color=1},
            {planeId='dart',angle=35,power=100,gadget='Shield',color=1},
            {planeId='dart',angle=0/0,gadget='Shield',color=1},
            {planeId='dart',angle=math.huge,gadget='Shield',color=1},
            {planeId='dart',gadget='Shield',color=1}
        })do
            assert(not Harness.debug('validateSettings',bad))
            Harness.send(a,'configure',{settings=bad});Harness.advance(0.1)
            assert(Harness.latest(a).players[1].settings.planeId=='cruiser')
        end
        for _,id in ipairs(catalog.ORDER)do
            assert(catalog.get(id).free and catalog.isSelectable(id))
            local checked=Harness.debug('validateSettings',{planeId=id,angle=27.6,gadget='Shield',color=2})
            assert(checked.planeId==id and checked.angle==28 and checked.speed==catalog.get(id).speed and checked.power==nil)
        end
        local low=Harness.debug('validateSettings',{planeId='dart',angle=-999,gadget='Shield',color=1})
        local high=Harness.debug('validateSettings',{planeId='dart',angle=999,gadget='Shield',color=1})
        assert(low.angle==15 and high.angle==60)
        Harness.send(a,'configure',{settings=high});Harness.advance(0.1)
        assert(Harness.latest(a).players[1].settings.planeId=='dart' and Harness.latest(a).players[1].settings.angle==60)
    ''',
    "human planes and chosen angles launch independently at catalog speed": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.send(a,'configure',{settings={planeId='skyhopper',angle=52,gadget='Shield',color=2}})
        Harness.send(b,'configure',{settings={planeId='dart',angle=23,gadget='Boost',color=4}})
        Harness.debug('forcePair',{ids={a.UserId,b.UserId}})
        local s=Harness.debug('launch',{userId=a.UserId})
        assert(s.players[1].settings.planeId=='skyhopper' and s.players[2].settings.planeId=='dart')
        for _,entry in ipairs(s.players)do
            local plane=Harness.shared.PlaneCatalog.module.get(entry.settings.planeId)
            local f=entry.flight
            assert(math.abs(math.sqrt(f.vx*f.vx+f.vy*f.vy)-plane.speed)<0.0000001)
            assert(math.abs(f.vy/f.vx-math.tan(math.rad(entry.settings.angle)))<0.0000001)
        end
        assert(s.players[1].settings.angle==52 and s.players[2].settings.angle==23)
        Harness.advance(1)
        assert(Harness.latest(a).players[1].flight.x~=Harness.latest(a).players[2].flight.x)
    ''',
    "practice ghost plane is deterministic per course and changes on rematch": r'''
        local a=Harness.add(101)
        Harness.send(a,'practice')
        local first=Harness.debug('configure',{userId=a.UserId})
        local catalog=Harness.shared.PlaneCatalog.module
        local firstId=first.players[2].settings.planeId
        assert(firstId==catalog.ORDER[first.courseSeed % #catalog.ORDER+1])
        local repeated=Harness.debug('configure',{userId=a.UserId})
        assert(repeated.players[2].settings.planeId==firstId and repeated.courseSeed==first.courseSeed)
        Harness.debug('launch',{userId=a.UserId});Harness.advance(46)
        Harness.send(a,'rematch')
        local second=Harness.debug('configure',{userId=a.UserId})
        assert(second.players[2].settings.planeId~=firstId)
        assert(second.players[2].settings.planeId==catalog.ORDER[second.courseSeed % #catalog.ORDER+1])
        assert(second.players[1].settings.planeId=='cruiser')
    ''',
    "unpublished Studio explicitly uses session-only stats and no analytics": r'''
        local a=Harness.add(101)
        assert(Harness.latest(a).saveStatus=='session_only')
        assert(Harness.latest(a).stats.totalFlights==0 and Harness.latest(a).stats.bestStreak==0)
        Harness.send(a,'practice');Harness.debug('launch',{userId=a.UserId});Harness.advance(46)
        assert(Harness.latest(a).stats.practiceFlights==1 and Harness.latest(a).stats.totalFlights==1)
        assert(Harness.latest(a).stats.wins==0 and Harness.latest(a).stats.losses==0)
        assert(Harness.latest(a).stats.bestDistance>0 and Harness.latest(a).saveStatus=='session_only')
        assert(Harness.store.getCalls==0 and Harness.store.calls==0 and #Harness.analytics==0)
    ''',
    "pads require two different pilots and clear seats on launch": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.move(a,1,1);Harness.advance(0.3)
        assert(Harness.latest(a).phase=='Queued' and Harness.latest(b).phase=='Lobby')
        Harness.move(b,1,1);Harness.advance(2)
        assert(Harness.latest(a).matchId==0 and Harness.latest(b).matchId==0)
        Harness.move(b,1,2);Harness.advance(2)
        local sa,sb=Harness.latest(a),Harness.latest(b)
        assert(sa.phase=='Voting' and sa.matchId==sb.matchId and sa.matchId~=0)
        assert(#sa.players==2 and sa.players[1].userId~=sa.players[2].userId)
        assert(a.Character.HumanoidRootPart.Anchored and b.Character.HumanoidRootPart.Anchored)
        assert(Harness.queueCounts.duel1==0)
    ''',
    "walking off or leaving a queue removes membership": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.move(a,1,1);Harness.advance(0.3)
        a.Character:PivotTo(CFrame.new(0,7,0));Harness.advance(0.3)
        assert(Harness.latest(a).phase=='Lobby' and Harness.queueCounts.duel1==0)
        Harness.move(a,1,1);Harness.advance(0.3)
        Harness.send(a,'leaveQueue');Harness.advance(0.3)
        assert(Harness.latest(a).phase=='Lobby' and Harness.queueCounts.duel1==0)
        Harness.move(b,1,2);Harness.advance(2)
        assert(Harness.latest(b).phase=='Queued' and Harness.latest(b).matchId==0)
    ''',
    "simultaneous duels isolate snapshots votes and settings": r'''
        local a,b,c,d,e=Harness.add(101),Harness.add(102),Harness.add(103),Harness.add(104),Harness.add(105)
        Harness.move(a,1,1);Harness.move(b,1,2);Harness.move(c,2,1);Harness.move(d,2,2);Harness.advance(2)
        local sa,sc,se=Harness.latest(a),Harness.latest(c),Harness.latest(e)
        assert(sa.matchId~=sc.matchId and #sa.players==2 and #sc.players==2)
        assert(se.phase=='Lobby' and #se.players==1 and se.players[1].userId==e.UserId)
        for _,entry in ipairs(sa.players)do assert(entry.userId==a.UserId or entry.userId==b.UserId)end
        Harness.send(a,'vote',{variant='Storm',matchId=sc.matchId,userId=c.UserId})
        assert(Harness.latest(a).votes.Storm==1 and Harness.latest(c).votes.Storm==0)
        Harness.send(a,'configure',{settings={planeId='skyhopper',angle=60,gadget='Boost',color=4},userId=c.UserId})
        assert(Harness.latest(a).players[1].settings.planeId=='skyhopper')
        assert(Harness.latest(a).players[2].settings.planeId=='cruiser')
        for _,entry in ipairs(Harness.latest(c).players)do assert(entry.settings.angle==35)end
        Harness.debug('configure',{userId=a.UserId})
        Harness.send(a,'ready',{ready=true});Harness.send(b,'ready',{ready=true});Harness.advance(1.2)
        assert(Harness.latest(a).phase=='Aim' and Harness.latest(c).phase=='Voting')
        Harness.send(a,'configure',{settings={angle=28}})
        assert(Harness.latest(a).players[1].settings.angle==28 and Harness.latest(c).players[1].settings.angle==35)
        Harness.debug('launch',{userId=a.UserId});Harness.advance(0.3)
        assert(Harness.latest(a).phase=='Flight' and Harness.latest(c).phase=='Voting')
        assert(Harness.latest(a).elapsed>0 and Harness.latest(c).elapsed==0)
    ''',
    "configuration locks at countdown and rejects malformed commands": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.debug('forcePair',{ids={a.UserId,b.UserId}})
        Harness.debug('configure',{userId=a.UserId})
        Harness.send(a,'ready',{ready=true,settings={planeId='dart',angle=45,gadget='Magnet',color=3}})
        Harness.send(b,'ready',{ready=true});Harness.advance(1.2)
        assert(Harness.latest(a).phase=='Aim')
        Harness.send(a,'ready',{ready=true});Harness.send(b,'ready',{ready=true});Harness.advance(1.2)
        assert(Harness.latest(a).phase=='Countdown')
        Harness.send(a,'configure',{settings={planeId='skyhopper',angle=15,gadget='Boost',color=1}})
        Harness.send(a,'ready',{ready=false})
        Harness.send(a,'unrecognized',{settings={angle=60}})
        Harness.advance(3)
        local own
        for _,entry in ipairs(Harness.latest(a).players)do if entry.userId==a.UserId then own=entry end end
        assert(Harness.latest(a).phase=='Flight' and own.settings.angle==45 and own.settings.planeId=='dart' and own.settings.speed==81)
        assert(own.settings.gadget=='Magnet' and own.flight)
        Harness.send(a,'configure',{settings={planeId='cruiser',angle=15,gadget='Shield',color=1}})
        assert(Harness.latest(a).players[1].settings.planeId=='dart' and Harness.latest(a).players[1].settings.angle==45)
    ''',
    "disconnect cancels either preflight participant without an orphan match": r'''
        for _,phase in ipairs({'Voting','Configure','Aim','Countdown'})do
            local a,b=Harness.add(101),Harness.add(102)
            Harness.debug('forcePair',{ids={a.UserId,b.UserId}})
            if phase~='Voting'then Harness.debug('configure',{userId=a.UserId})end
            if phase=='Aim' or phase=='Countdown'then Harness.debug('aim',{userId=a.UserId})end
            if phase=='Countdown'then
                Harness.send(a,'ready',{ready=true});Harness.send(b,'ready',{ready=true});Harness.advance(1.2)
            end
            assert(Harness.latest(b).phase==phase)
            Harness.remove(a);Harness.advance(0.2)
            assert(Harness.latest(b).phase=='Lobby' and Harness.latest(b).matchId==0)
            assert(not b.Character.HumanoidRootPart.Anchored)
            assert(Harness.shared:GetAttribute('ActiveDuels')==0)
            Harness.remove(b)
        end
    ''',
    "queued disconnect cannot leave a phantom opponent": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.move(a,1,1);Harness.advance(0.3);Harness.remove(a)
        Harness.move(b,1,2);Harness.advance(2)
        assert(Harness.latest(b).phase=='Queued' and Harness.queueCounts.duel1==1)
        local c=Harness.add(103);Harness.move(c,1,1);Harness.advance(2)
        assert(Harness.latest(b).phase=='Voting' and Harness.latest(c).matchId==Harness.latest(b).matchId)
        for _,entry in ipairs(Harness.latest(b).players)do assert(entry.userId~=a.UserId)end
    ''',
    "leaving a flight forfeits even when ahead and permits a new match": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.send(a,'configure',{settings={planeId='dart',angle=15,gadget='Shield',color=1}})
        Harness.debug('forcePair',{ids={a.UserId,b.UserId}});Harness.debug('launch',{userId=a.UserId});Harness.advance(1)
        Harness.send(a,'returnLobby');Harness.advance(0.2)
        local result=Harness.latest(b)
        assert(Harness.latest(a).phase=='Lobby' and result.phase=='Results')
        assert(result.results[1].userId==b.UserId and result.results[2].forfeit)
        assert(result.results[2].distance>result.results[1].distance)
        assert(not result.canRematch and not a.Character.HumanoidRootPart.Anchored)
        local oldId=result.matchId
        Harness.send(a,'practice');Harness.advance(0.2)
        assert(Harness.latest(a).matchId~=oldId and Harness.latest(a).phase=='Voting')
        assert(Harness.latest(b).matchId==oldId and Harness.latest(b).phase=='Results')
        Harness.send(b,'rematch');Harness.advance(0.2)
        assert(Harness.latest(b).phase=='Results' and not Harness.latest(b).canRematch)
    ''',
    "disconnect during flight awards the attached opponent a win": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.debug('forcePair',{ids={a.UserId,b.UserId}});Harness.debug('launch',{userId=a.UserId});Harness.advance(1)
        Harness.remove(b);Harness.advance(0.2)
        local s=Harness.latest(a)
        assert(s.phase=='Results' and s.results[1].userId==a.UserId and s.results[2].forfeit)
        assert(not s.canRematch)
        Harness.send(a,'returnLobby');Harness.advance(0.2)
        assert(Harness.latest(a).phase=='Lobby' and Harness.shared:GetAttribute('ActiveDuels')==0)
    ''',
    "rematch requires both humans and clears flight ready and vote state": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.debug('forcePair',{ids={a.UserId,b.UserId}});Harness.debug('launch',{userId=a.UserId});Harness.advance(46)
        local old=Harness.latest(a)
        assert(old.phase=='Results' and old.canRematch and #old.results==2)
        Harness.send(a,'rematch');Harness.advance(0.2)
        assert(Harness.latest(a).phase=='Results')
        Harness.send(b,'rematch');Harness.advance(0.2)
        local nextRound=Harness.latest(a)
        assert(nextRound.phase=='Voting' and nextRound.matchId==old.matchId and nextRound.roundId==old.roundId+1)
        assert(#nextRound.results==0 and nextRound.elapsed==0)
        for _,entry in ipairs(nextRound.players)do assert(not entry.flight and not entry.ready and not entry.rematchReady)end
        Harness.send(a,'rematch');Harness.advance(0.2)
        assert(Harness.latest(a).roundId==nextRound.roundId)
    ''',
    "results departure prevents a pending rematch and cleans abandoned matches": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.debug('forcePair',{ids={a.UserId,b.UserId}});Harness.debug('launch',{userId=a.UserId});Harness.advance(46)
        Harness.send(a,'rematch');Harness.remove(b);Harness.advance(0.2)
        assert(Harness.latest(a).phase=='Results' and not Harness.latest(a).canRematch)
        Harness.send(a,'rematch');Harness.advance(0.2)
        assert(Harness.latest(a).phase=='Results')
        Harness.advance(91)
        assert(Harness.latest(a).phase=='Lobby' and not a.Character.HumanoidRootPart.Anchored)
        assert(Harness.shared:GetAttribute('ActiveDuels')==0)
    ''',
    "practice has exactly one ghost and supports a one-human rematch": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.send(a,'practice');Harness.advance(0.2)
        local s=Harness.latest(a)
        assert(s.phase=='Voting' and #s.players==2 and s.players[2].bot)
        assert(Harness.latest(b).phase=='Lobby')
        Harness.debug('launch',{userId=a.UserId});Harness.advance(46)
        assert(Harness.latest(a).phase=='Results')
        Harness.send(a,'rematch');Harness.advance(0.2)
        assert(Harness.latest(a).phase=='Voting' and Harness.latest(a).roundId==2)
    ''',
    "unready human duel follows phase deadlines and returns both to hub": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.move(a,1,1);Harness.move(b,1,2);Harness.advance(2)
        assert(Harness.latest(a).phase=='Voting')
        Harness.advance(8)
        assert(Harness.latest(a).phase=='Configure')
        Harness.advance(25)
        assert(Harness.latest(a).phase=='Aim')
        for _,entry in ipairs(Harness.latest(a).players)do assert(not entry.ready and not entry.flight)end
        Harness.advance(19)
        assert(Harness.latest(a).phase=='Aim')
        Harness.advance(1)
        assert(Harness.latest(a).phase=='Countdown')
        Harness.advance(3)
        assert(Harness.latest(a).phase=='Flight')
        Harness.advance(46)
        assert(Harness.latest(a).phase=='Results' and #Harness.latest(a).results==2)
        Harness.advance(91)
        assert(Harness.latest(a).phase=='Lobby' and Harness.latest(b).phase=='Lobby')
        assert(Harness.shared:GetAttribute('ActiveDuels')==0)
    ''',
    "duplicate or busy participants cannot form another match": r'''
        local a,b,c=Harness.add(101),Harness.add(102),Harness.add(103)
        assert(not Harness.debug('forcePair',{ids={a.UserId,a.UserId}}))
        local match=Harness.debug('forcePair',{ids={a.UserId,b.UserId}})
        assert(match and not Harness.debug('forcePair',{ids={a.UserId,c.UserId}}))
        Harness.send(a,'practice');Harness.advance(0.2)
        assert(Harness.latest(a).matchId==match and Harness.latest(c).phase=='Lobby')
        assert(Harness.shared:GetAttribute('ActiveDuels')==1)
    ''',
}

LIVE_SCENARIOS = {
    "published practice statistics survive leave and rejoin": r'''
        local a=Harness.add(101)
        assert(Harness.latest(a).saveStatus=='saved' and Harness.store.getCalls==1)
        Harness.send(a,'practice');Harness.advance(8.2)
        Harness.readyDuel(a);Harness.advance(46)
        local before=Harness.latest(a).stats
        assert(before.practiceFlights==1 and before.totalFlights==1 and before.bestDistance>0)
        assert(before.wins==0 and before.losses==0 and before.currentStreak==0)
        Harness.remove(a)
        assert(Harness.store.values.player_101.lease==nil)
        local nextPlayer=Harness.add(101)
        assert(Harness.latest(nextPlayer).stats.bestDistance==before.bestDistance)
        assert(Harness.latest(nextPlayer).stats.totalFlights==1 and Harness.latest(nextPlayer).saveStatus=='saved')
        assert(#Harness.analytics>0)
        for _,event in ipairs(Harness.analytics)do
            for key,value in pairs(event.fields or {})do
                assert(key=='CustomField01' or key=='CustomField02' or key=='CustomField03')
                assert(value~='101' and value~='Pilot101')
            end
        end
        Harness.shutdown();assert(Harness.store.values.player_101.lease==nil)
    ''',
    "human forfeit records a loss without an aborted best and tie preserves streak": r'''
        local a,b=Harness.add(101),Harness.add(102)
        Harness.move(a,1,1);Harness.move(b,1,2);Harness.advance(2);Harness.advance(8)
        Harness.readyDuel(a,b)
        assert(Harness.latest(a).phase=='Flight')
        Harness.send(a,'returnLobby');Harness.advance(0.2)
        assert(Harness.latest(a).stats.losses==1 and Harness.latest(a).stats.bestDistance==0)
        assert(Harness.latest(b).stats.wins==1 and Harness.latest(b).stats.currentStreak==1)
        assert(Harness.latest(b).stats.bestDistance==0)
        Harness.send(b,'returnLobby');Harness.advance(2.2)
        Harness.move(a,1,1);Harness.move(b,1,2);Harness.advance(2);Harness.advance(8)
        Harness.readyDuel(a,b);Harness.advance(46)
        assert(Harness.latest(a).phase=='Results' and Harness.latest(a).stats.draws==1)
        assert(Harness.latest(b).stats.draws==1 and Harness.latest(b).stats.currentStreak==1 and Harness.latest(b).stats.bestStreak==1)
        assert(Harness.latest(a).stats.totalFlights==2 and Harness.latest(b).stats.totalFlights==2)
        assert(Harness.latest(a).stats.bestDistance>0 and Harness.latest(b).stats.bestDistance>0)
        Harness.shutdown()
        assert(Harness.store.values.player_101.lease==nil and Harness.store.values.player_102.lease==nil)
    ''',
    "live load failure is visible and cannot replace durable history": r'''
        local a=Harness.add(101)
        Harness.send(a,'practice');Harness.advance(8.2);Harness.readyDuel(a);Harness.advance(46)
        local oldBest=Harness.latest(a).stats.bestDistance
        Harness.remove(a);Harness.store.failures=3
        local b=Harness.add(101)
        assert(Harness.latest(b).saveStatus=='unavailable')
        local calls=Harness.store.calls
        Harness.send(b,'practice');Harness.advance(8.2);Harness.readyDuel(b);Harness.advance(46)
        Harness.remove(b);Harness.shutdown()
        assert(Harness.store.calls==calls and Harness.store.values.player_101.stats.bestDistance==oldBest)
        assert(Harness.store.values.player_101.stats.totalFlights==1)
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
    for name, scenario in LIVE_SCENARIOS.items():
        runtime = make_runtime(studio=False, published=True)
        try:
            runtime.execute(scenario)
        except Exception as error:
            raise AssertionError(f"FAILED: {name}\n{error}") from error
        print(f"PASS: {name}")
    print(f"{len(SCENARIOS) + len(LIVE_SCENARIOS)} server scenarios passed")


if __name__ == "__main__":
    main()
