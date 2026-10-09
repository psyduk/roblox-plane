-- Decorative, client-only seated pilots. The real character is never reparented
-- or posed; only its Archivable flag is temporarily changed while cloning.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World = require(ReplicatedStorage:WaitForChild("FlightGame"):WaitForChild("World"))

local PilotAvatar = {}
local active = setmetatable({}, { __mode = "k" })

local function neutralPracticePilot()
	local rig = Instance.new("Model")
	rig.Name = "PilotAvatar"
	local function part(name, size, position, color)
		local object = Instance.new("Part")
		object.Name, object.Size, object.CFrame = name, size, CFrame.new(position)
		object.Color = color
		object.Material = Enum.Material.SmoothPlastic
		object.TopSurface, object.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		object.Parent = rig
		return object
	end
	local function motor(name, parent, child, c0, c1)
		local joint = Instance.new("Motor6D")
		joint.Name, joint.Part0, joint.Part1 = name, parent, child
		joint.C0, joint.C1 = c0, c1 or CFrame.identity
		joint.Parent = parent
	end
	local grey = Color3.fromRGB(193, 209, 217)
	local navy = Color3.fromRGB(32, 49, 66)
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, navy)
	root.Transparency = 1
	rig.PrimaryPart = root
	local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.zero, navy)
	local head = part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), grey)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType, mesh.Scale, mesh.Parent = Enum.MeshType.Head, Vector3.new(1.12, 1.12, 1.12), head
	local leftArm = part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), grey)
	local rightArm = part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), grey)
	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), navy)
	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), navy)
	local goggles = part("PracticeGoggles", Vector3.new(1.7, 0.28, 0.18), Vector3.new(0, 1.58, -0.58), Color3.fromRGB(72, 220, 225))
	motor("RootJoint", root, torso, CFrame.identity)
	motor("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
	motor("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
	motor("Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
	motor("Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))
	motor("Goggles", head, goggles, CFrame.new(0, 0.08, -0.58))
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = rig
	return rig
end

local function cloneCharacter(player)
	local character = player and player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Head") then
		return nil
	end
	local wasArchivable = character.Archivable
	local success, result = pcall(function()
		character.Archivable = true
		return character:Clone()
	end)
	-- No yielding occurs between the temporary change and its restoration.
	character.Archivable = wasArchivable
	if success and result and result:FindFirstChild("HumanoidRootPart") and result:FindFirstChild("Head") then
		return result
	end
	if success and result then result:Destroy() end
	return nil
end

local function stripAndFreeze(rig, connections, alive)
	for _, object in ipairs(rig:GetDescendants()) do
		if object.Parent then
			if object:IsA("LuaSourceContainer") or object:IsA("Tool") or object:IsA("Sound")
				or object:IsA("GuiBase2d") or object:IsA("Animator") or object:IsA("AnimationController")
				or object:IsA("Animation") or object:IsA("ForceField") or object:IsA("BodyMover")
				or object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
				or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("Sparkles") then
				object:Destroy()
			elseif object:IsA("BasePart") then
				object.Anchored = true
				object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
				object.Massless, object.CastShadow = true, false
				object.AssemblyLinearVelocity, object.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
				object.LocalTransparencyModifier = 0
				-- Humanoid initialization can restore torso collision after parenting.
				-- Preserve Humanoid for clothing, but enforce a purely visual proxy.
				for property, value in pairs({ Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false }) do
					table.insert(connections, object:GetPropertyChangedSignal(property):Connect(function()
						if alive() and object.Parent and object[property] ~= value then
							object[property] = value
						end
					end))
				end
			elseif object:IsA("Constraint") then
				object.Enabled = false
			elseif object:IsA("Bone") then
				object.Transform = CFrame.identity
			end
		end
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = false
		humanoid.AutomaticScalingEnabled = false
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.Sit, humanoid.PlatformStand = true, true
		-- Prevent an anchored visual rig from starting its own character state loop.
		humanoid.EvaluateStateMachine = false
	end
end

local function bendForPart(name)
	local normalized = string.lower((string.gsub(name, "[%s_]", "")))
	if normalized == "leftupperleg" or normalized == "rightupperleg" then return 84 end
	if normalized == "leftlowerleg" or normalized == "rightlowerleg" then return -84 end
	if normalized == "leftleg" or normalized == "rightleg" then return 78 end
	if normalized == "leftupperarm" or normalized == "rightupperarm"
		or normalized == "leftarm" or normalized == "rightarm" then return 52 end
	if normalized == "leftlowerarm" or normalized == "rightlowerarm" then return 18 end
	if normalized == "uppertorso" then return -4 end
	return 0
end

local function seatRig(rig, planeScale)
	local root = rig:FindFirstChild("HumanoidRootPart")
	assert(root and root:IsA("BasePart"), "Avatar has no HumanoidRootPart")
	rig.PrimaryPart = root
	rig:ScaleTo(rig:GetScale() * planeScale * 0.9)
	root.Transparency = 1
	local originalRoot = root.CFrame
	local originalOffsets, joints, parts = {}, {}, {}
	for _, object in ipairs(rig:GetDescendants()) do
		if object:IsA("BasePart") then
			originalOffsets[object] = originalRoot:ToObjectSpace(object.CFrame)
			table.insert(parts, object)
		elseif object:IsA("JointInstance") and object.Part0 and object.Part1
			and object.Part0:IsDescendantOf(rig) and object.Part1:IsDescendantOf(rig) then
			table.insert(joints, object)
			if object:IsA("Motor6D") then object.Transform = CFrame.identity end
		end
	end
	-- Bake the pose through the joint graph, independently of Motor6D update timing.
	-- Rotating about rig +X also supports R6's rotated hip/shoulder joint bases.
	local posed = { [root] = CFrame.identity }
	for _ = 1, #joints + 1 do
		local progressed = false
		for _, joint in ipairs(joints) do
			local parentPose = posed[joint.Part0]
			if parentPose and not posed[joint.Part1] then
				local jointPose = parentPose * joint.C0
				local restPose = jointPose * joint.C1:Inverse()
				local bend = bendForPart(joint.Part1.Name)
				local position = jointPose.Position
				posed[joint.Part1] = CFrame.new(position) * CFrame.Angles(math.rad(bend), 0, 0)
					* CFrame.new(-position) * restPose
				progressed = true
			elseif posed[joint.Part1] and not posed[joint.Part0] then
				-- AccessoryWeld often points from its Handle back to the head.
				local jointPose = posed[joint.Part1] * joint.C1
				local restPose = jointPose * joint.C0:Inverse()
				local position = jointPose.Position
				posed[joint.Part0] = CFrame.new(position) * CFrame.Angles(math.rad(bendForPart(joint.Part0.Name)), 0, 0)
					* CFrame.new(-position) * restPose
				progressed = true
			end
		end
		if not progressed then break end
	end
	for _, part in ipairs(parts) do
		part.CFrame = posed[part] or originalOffsets[part]
	end
	-- Store the baked relation so no remaining joint can restore the standing pose.
	for _, joint in ipairs(joints) do
		joint.C0 = joint.Part0.CFrame:ToObjectSpace(joint.Part1.CFrame) * joint.C1
	end
	rig:SetAttribute("Pose", "Seated")
	rig:SetAttribute("PosePartCount", #parts)
	return root
end

function PilotAvatar.attach(model, userId, isGhost)
	assert(typeof(model) == "Instance" and model:IsA("Model"), "PilotAvatar.attach needs a plane Model")
	if active[model] then active[model].cancel() end
	local state = { cancelled = false, avatar = nil, connections = {} }
	active[model] = state
	model:SetAttribute("PilotAvatarLoaded", false)
	model:SetAttribute("PilotAvatarSource", "Loading")
	model:SetAttribute("PilotAvatarError", nil)
	local function alive()
		return not state.cancelled and active[model] == state and model.Parent ~= nil
	end
	local function cancel()
		if state.cancelled then return end
		state.cancelled = true
		for _, connection in ipairs(state.connections) do connection:Disconnect() end
		table.clear(state.connections)
		if state.avatar then state.avatar:Destroy(); state.avatar = nil end
		if state.canopy and state.canopy.Parent then state.canopy.Transparency = state.canopyTransparency end
		if active[model] == state then
			active[model] = nil
			if model.Parent then
				model:SetAttribute("PilotAvatarLoaded", false)
				model:SetAttribute("PilotAvatarSource", "Cancelled")
			end
		end
	end
	state.cancel = cancel
	table.insert(state.connections, model.Destroying:Connect(cancel))
	table.insert(state.connections, model.AncestryChanged:Connect(function(_, parent)
		if not parent then cancel() end
	end))

	task.spawn(function()
		local rig, source
		local success, failure = pcall(function()
			if not alive() then return end
			if isGhost then
				rig, source = neutralPracticePilot(), "PracticeDummy"
			else
				local player = Players:GetPlayerByUserId(userId)
				local deadline = os.clock() + 8
				while player and not rig and alive() do
					rig = cloneCharacter(player)
					if rig or os.clock() >= deadline then break end
					task.wait(0.1)
				end
				if not alive() then return end
				if rig then
					source = "CharacterClone"
				else
					assert(type(userId) == "number" and userId > 0, "Local test character is not available to clone")
					local description = Players:GetHumanoidDescriptionFromUserIdAsync(userId)
					if not alive() then description:Destroy(); return end
					local rigType = Enum.HumanoidRigType.R15
					local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then rigType = humanoid.RigType end
					local created, result = pcall(function()
						return Players:CreateHumanoidModelFromDescriptionAsync(description, rigType)
					end)
					description:Destroy()
					if not created then error(result) end
					rig, source = result, "HumanoidDescription"
				end
			end
			if not alive() then return end
			stripAndFreeze(rig, state.connections, alive)
			seatRig(rig, model:GetScale())
			if not alive() then return end
			rig.Name = "PilotAvatar"
			rig:SetAttribute("UserId", userId)
			rig:SetAttribute("IsGhost", isGhost == true)
			rig:SetAttribute("Source", source)
			rig:SetAttribute("Loaded", true)
			rig:PivotTo(World.getCockpitCFrame(model))
			rig.Parent = model
			state.avatar = rig
			-- Parenting initializes Humanoid and can change torso collision without
			-- firing property signals. Finalize the static state after that step.
			local humanoid = rig:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Physics) end
			for _, body in ipairs(rig:GetDescendants()) do
				if body:IsA("BasePart") then
					body.Anchored = true
					body.CanCollide, body.CanTouch, body.CanQuery = false, false, false
				end
			end
			local canopy = model:FindFirstChild("Cockpit")
			if canopy and canopy:IsA("BasePart") then
				state.canopy, state.canopyTransparency = canopy, canopy.Transparency
				canopy.Transparency = math.max(canopy.Transparency, 0.72)
			end
			model:SetAttribute("PilotAvatarLoaded", true)
			model:SetAttribute("PilotAvatarSource", source)
		end)
		if not success or not alive() then
			if rig then rig:Destroy() end
			state.avatar = nil
			if not success and alive() then
				model:SetAttribute("PilotAvatarSource", "Unavailable")
				model:SetAttribute("PilotAvatarError", string.sub(tostring(failure), 1, 240))
			end
		end
	end)
	return { cancel = cancel, Destroy = cancel }
end

return PilotAvatar
