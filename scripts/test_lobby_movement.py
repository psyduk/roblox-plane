"""Offline input/lifecycle checks with Roblox mocks; does not verify Studio physics."""
from pathlib import Path
from lupa import LuaRuntime

runtime = LuaRuntime()
runtime.execute(r'''
function signal()
    local listeners = {}
    return {
        Connect = function(_, fn)
            local connection = {active = true}
            function connection:Disconnect() self.active = false end
            table.insert(listeners, {connection, fn})
            return connection
        end,
        Fire = function(_, ...)
            for _, entry in ipairs(listeners) do
                if entry[1].active then entry[2](...) end
            end
        end,
    }
end
Enum = {HumanoidStateType = {}, Material = {Air = 'Air', Ground = 'Ground'},
    KeyCode = {Space = 'Space', ButtonA = 'ButtonA'}, UserInputType = {Touch = 'Touch'}}
for _, name in ipairs({'Jumping', 'Freefall', 'Running', 'Landed', 'Dead', 'Seated', 'Swimming', 'Climbing'}) do
    Enum.HumanoidStateType[name] = name
end
Vector3 = {new = function(x,y,z) return {X=x,Y=y,Z=z} end}
local frameMeta = {__mul = function(a,b) return {a=a,b=b} end}
CFrame = {new = function() return setmetatable({},frameMeta) end,
    Angles = function() return {} end}
-- Products must also support the second multiplication in the flip pose.
frameMeta.__mul = function(a,b) return setmetatable({a=a,b=b},frameMeta) end
workspace = {Gravity = 196.2}
task = {spawn = function(fn,...) fn(...) end}
input = {InputEnded=signal(),WindowFocusReleased=signal(),JumpRequest=signal()}
function input:GetFocusedTextBox() return self.focused end
run = {PreSimulation=signal()}
player = {CharacterAdded=signal(),CharacterRemoving=signal()}
game = {GetService = function(_,name)
    return ({Players={LocalPlayer=player},UserInputService=input,RunService=run})[name]
end}
allowed = true
function spawn()
    humanoid = {StateChanged=signal(),Health=100,Sit=false,UseJumpPower=true,
        JumpPower=50,JumpHeight=7.2,FloorMaterial='Ground',state='Running'}
    function humanoid:GetState() return self.state end
    function humanoid:ChangeState(state)
        local old = self.state; self.state = state; self.StateChanged:Fire(old,state)
    end
    root = {Anchored=false,AssemblyLinearVelocity=Vector3.new(8,-10,3)}
    original = {Position={},Rotation={}}
    joint = {Part0=root,C0=original,Parent=true,IsA=function(_,kind) return kind=='Motor6D' end}
    character = {WaitForChild=function(_,name) return name=='Humanoid' and humanoid or root end,
        GetDescendants=function() return {joint} end}
    player.Character = character
    player.CharacterAdded:Fire(character)
end
function release()
    input.InputEnded:Fire({KeyCode='Space'})
end
function takeoff()
    input.JumpRequest:Fire()
    humanoid.FloorMaterial='Air'
    humanoid:ChangeState('Jumping')
end
function land()
    humanoid.FloorMaterial='Ground'; humanoid:ChangeState('Landed'); release()
end
''')
module = runtime.execute((Path(__file__).resolve().parents[1] / 'src/client/LobbyMovement.luau').read_text(encoding='utf-8'))
module.new(runtime.eval('function() return allowed end'))
runtime.execute(r'''
spawn()
takeoff()
input.JumpRequest:Fire()
assert(root.AssemblyLinearVelocity.Y == -10, 'Holding jump must not double jump')
release(); input.JumpRequest:Fire()
assert(root.AssemblyLinearVelocity.Y == 50, 'Second press must boost')
assert(root.AssemblyLinearVelocity.X == 8 and root.AssemblyLinearVelocity.Z == 3, 'Preserve horizontal movement')
run.PreSimulation:Fire(0.1)
assert(joint.C0 ~= original, 'Second jump starts flip')
root.AssemblyLinearVelocity.Y = 5
release(); input.JumpRequest:Fire()
assert(root.AssemblyLinearVelocity.Y == 5, 'Third jump forbidden')
run.PreSimulation:Fire(0.5)
assert(joint.C0 == original, 'Completed flip restores pose')
land(); takeoff(); release(); input.JumpRequest:Fire()
assert(root.AssemblyLinearVelocity.Y == 50, 'Landing recharges jump')
run.PreSimulation:Fire(0.1); land()
assert(joint.C0 == original, 'Landing cancels flip')
takeoff(); release(); allowed=false; root.AssemblyLinearVelocity.Y=-10
input.JumpRequest:Fire()
assert(root.AssemblyLinearVelocity.Y == -10, 'Menu/battle gate blocks boost')
allowed=true; release(); input.JumpRequest:Fire(); run.PreSimulation:Fire(0.1)
allowed=false; run.PreSimulation:Fire(0.1)
assert(joint.C0 == original, 'Leaving lobby restores pose')
allowed=true; land(); takeoff(); release(); input.focused=true
root.AssemblyLinearVelocity.Y=-10; input.JumpRequest:Fire()
assert(root.AssemblyLinearVelocity.Y == -10, 'Typing cannot boost')
input.focused=false
player.CharacterRemoving:Fire(character); spawn()
humanoid.UseJumpPower=false
takeoff(); release(); input.JumpRequest:Fire()
assert(math.abs(root.AssemblyLinearVelocity.Y-math.sqrt(2*196.2*7.2))<0.001, 'Respawn and JumpHeight mode work')
run.PreSimulation:Fire(0.1); player.CharacterRemoving:Fire(character)
assert(joint.C0 == original, 'Removing character restores pose')
-- Reproduce a rig whose joint is absent at CharacterAdded and appears later.
spawn()
player.CharacterRemoving:Fire(character)
character.GetDescendants = function() return {} end
player.CharacterAdded:Fire(character)
character.GetDescendants = function() return {joint} end
takeoff(); release(); input.JumpRequest:Fire(); run.PreSimulation:Fire(0.1)
assert(joint.C0 ~= original, 'Late-loading rig must front flip')
player.CharacterRemoving:Fire(character)
-- Modern avatar root attachment must animate even without a Motor6D.
spawn()
player.CharacterRemoving:Fire(character)
attachment = {Parent=root,CFrame=original}
constraint = {Attachment0=attachment,IsA=function(_,kind) return kind=='AnimationConstraint' end}
character.GetDescendants = function() return {constraint} end
player.CharacterAdded:Fire(character)
takeoff(); release(); input.JumpRequest:Fire(); run.PreSimulation:Fire(0.1)
assert(attachment.CFrame ~= original, 'Constraint-based rig must front flip')
run.PreSimulation:Fire(0.5)
assert(attachment.CFrame == original, 'Constraint pose must reset after flip')
''')
print('Lobby movement input, boost, flip cleanup, gates, landing, and respawn checks passed.')
