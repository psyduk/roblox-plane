-- Local lobby movement: one extra jump per takeoff, with a cosmetic root-joint flip.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LobbyMovement = {}

function LobbyMovement.new(canMove)
    local player = Players.LocalPlayer
    local character, humanoid, root, joint, originalC0
    local stateConnection
    local poseProperty = "C0"
    local jumped, usedExtra, held = false, false, false
    local flipTime = nil
    local duration = 0.5

    local function stopFlip()
        if joint and joint.Parent and originalC0 then joint[poseProperty] = originalC0 end
        flipTime = nil
    end

    local function findFlipJoint()
        if joint and joint.Parent then return end
        if not character or not root then return end
        -- Resolve at jump time too: the rig may finish loading after CharacterAdded.
        -- Upgraded avatars use AnimationConstraints instead of Motor6Ds.
        for _, descendant in ipairs(character:GetDescendants()) do
            if descendant:IsA("AnimationConstraint") then
                local attachment = descendant.Attachment0
                if attachment and attachment.Parent == root then
                    joint, poseProperty = attachment, "CFrame"
                    originalC0 = attachment.CFrame
                    return
                end
            end
        end
        for _, descendant in ipairs(character:GetDescendants()) do
            if descendant:IsA("Motor6D") and descendant.Part0 == root then
                joint, poseProperty = descendant, "C0"
                originalC0 = descendant.C0
                return
            end
        end
    end

    local function bind(nextCharacter)
        stopFlip()
        if stateConnection then stateConnection:Disconnect() end
        character = nextCharacter
        humanoid, root, joint, originalC0 = nil, nil, nil, nil
        jumped, usedExtra, held = false, false, false
        local nextHumanoid = nextCharacter:WaitForChild("Humanoid", 10)
        local nextRoot = nextCharacter:WaitForChild("HumanoidRootPart", 10)
        if character ~= nextCharacter or not nextHumanoid or not nextRoot then return end
        humanoid, root = nextHumanoid, nextRoot
        findFlipJoint()
        stateConnection = humanoid.StateChanged:Connect(function(_, state)
            if state == Enum.HumanoidStateType.Jumping then
                jumped = true
            elseif state == Enum.HumanoidStateType.Landed
                or state == Enum.HumanoidStateType.Running then
                jumped, usedExtra = false, false
                stopFlip()
            elseif state == Enum.HumanoidStateType.Dead
                or state == Enum.HumanoidStateType.Seated
                or state == Enum.HumanoidStateType.Swimming
                or state == Enum.HumanoidStateType.Climbing then
                jumped, usedExtra = false, false
                stopFlip()
            end
        end)
    end

    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA
            or input.UserInputType == Enum.UserInputType.Touch then
            held = false
        end
    end)
    UserInputService.WindowFocusReleased:Connect(function() held = false end)
    UserInputService.JumpRequest:Connect(function()
        -- JumpRequest can repeat while held; require releasing the jump control.
        if held then return end
        held = true
        if not canMove() or UserInputService:GetFocusedTextBox() or not humanoid
            or humanoid.Health <= 0 or not root or root.Anchored or humanoid.Sit then return end
        local state = humanoid:GetState()
        if not jumped or usedExtra or humanoid.FloorMaterial ~= Enum.Material.Air
            or (state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall) then return end
        usedExtra = true
        local speed = humanoid.UseJumpPower and humanoid.JumpPower
            or math.sqrt(2 * workspace.Gravity * humanoid.JumpHeight)
        local velocity = root.AssemblyLinearVelocity
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        root.AssemblyLinearVelocity = Vector3.new(velocity.X, speed, velocity.Z)
        findFlipJoint()
        if joint then flipTime = 0 end
    end)

    RunService.PreSimulation:Connect(function(dt)
        if not canMove() or not humanoid or humanoid.Health <= 0 or not root or root.Anchored then
            stopFlip()
            return
        end
        if flipTime then
            flipTime = flipTime + dt
            if flipTime >= duration then
                stopFlip()
            elseif joint and joint.Parent then
                -- Rotate the visual torso, leaving the physical root/camera upright.
                joint[poseProperty] = CFrame.new(originalC0.Position)
                    * CFrame.Angles(-2 * math.pi * flipTime / duration, 0, 0)
                    * originalC0.Rotation
            end
        end
    end)
    player.CharacterAdded:Connect(bind)
    player.CharacterRemoving:Connect(function(removing)
        if removing ~= character then return end
        stopFlip()
        if stateConnection then stateConnection:Disconnect(); stateConnection = nil end
        character, humanoid, root, joint, originalC0 = nil, nil, nil, nil, nil
    end)
    if player.Character then task.spawn(bind, player.Character) end
end

return LobbyMovement
