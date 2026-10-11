-- Native Roblox engine checks. require(thisModule)(World) uses the packaged
-- templates, so a missing mesh/template cannot masquerade as a passing fallback.
return function(World)
	local fixture = Instance.new("Folder")
	fixture.Name, fixture.Parent = "MountVisualsFixture", workspace
	local passed = 0
	local function closePose(a, b)
		return (a.Position - b.Position).Magnitude < 0.001
			and (a.LookVector - b.LookVector).Magnitude < 0.001
			and (a.UpVector - b.UpVector).Magnitude < 0.001
	end
	local ok, failure = pcall(function()
		for _, id in ipairs({ "stormcrown", "ironwing", "phoenix", "riftmanta" }) do
			local model = World.createParkedPlane(fixture, id, 1, id, Vector3.new(0, 40, 0), 0.3, 1.5)
			assert(model:GetAttribute("PlaneId") == id and model:GetAttribute("MountVisualLoaded") == true,
				id .. " did not load its actual packaged template")
			assert(model:FindFirstChild("MainWing") == nil and model:FindFirstChild("Cockpit") == nil,
				id .. " still contains the stock airframe")
			assert(model:FindFirstChild("LandingWheel") == nil and model:FindFirstChild("TailWheel") == nil,
				id .. " has aircraft wheels")
			assert(model.Fuselage.Transparency == 1 and model.Fuselage:GetAttribute("CosmeticShell") == true,
				id .. " has a visible compatibility fuselage")
			for _, piece in ipairs(model.Propeller:GetChildren()) do
				if piece:IsA("BasePart") then assert(piece.Transparency == 1, id .. " has a visible propeller") end
			end
			local visual = model:FindFirstChild("MountVisual")
			local visible = 0
			for _, piece in ipairs(visual:GetDescendants()) do
				if piece:IsA("BasePart") then
					assert(piece.Anchored and not piece.CanCollide and not piece.CanTouch and not piece.CanQuery,
						id .. " cosmetic geometry can affect physics or hit queries")
					if piece.Transparency < 1 then visible = visible + 1 end
				end
			end
			assert(visible >= 3, id .. " is missing visible body or wing geometry")
			for _, name in ipairs({ "Nose", "Belly", "WingLeft", "WingRight", "Tail", "Centre", "Top" }) do
				assert(model.PrimaryPart:FindFirstChild(name):IsA("Attachment"), id .. " lost " .. name .. " battle mount")
			end
			local wing = visual.WingLeft
			local before = model:GetPivot():ToObjectSpace(wing:GetPivot())
			local rootMount = model.PrimaryPart.WingLeft.CFrame
			local bodyBefore = model:GetPivot():ToObjectSpace(visual.Body:GetPivot())
			for _ = 1, 9 do World.animateCosmetic(model, 1 / 60, true, false, false) end
			local after = model:GetPivot():ToObjectSpace(wing:GetPivot())
			assert(not closePose(before, after), id .. " wings never flap")
			assert((before.Position - after.Position).Magnitude < 0.001, id .. " wing hinge drifted")
			assert(closePose(bodyBefore, model:GetPivot():ToObjectSpace(visual.Body:GetPivot())), id .. " flapping moved the saddle/body")
			assert(closePose(rootMount, model.PrimaryPart.WingLeft.CFrame), id .. " animation changed a battle attachment")
			local frozen = after
			model:PivotTo(CFrame.new(23, 51, -12) * CFrame.Angles(0.2, 1.1, -0.4))
			World.animateCosmetic(model, 0.1, true, true, false)
			assert(closePose(frozen, model:GetPivot():ToObjectSpace(wing:GetPivot())), id .. " wings moved during knockout")
			local normalizedHinge = frozen.Position / model:GetScale()
			model:ScaleTo(0.75)
			World.animateCosmetic(model, 1 / 60, true, false, false)
			local scaledHinge = model:GetPivot():ToObjectSpace(wing:GetPivot()).Position
			assert((scaledHinge - normalizedHinge * 0.75).Magnitude < 0.001, id .. " wing hinge did not follow model scale")
			local cockpit = model:GetPivot():ToObjectSpace(World.getCockpitCFrame(model))
			local expectedSeat = Vector3.new(model:GetAttribute("CockpitX"), model:GetAttribute("CockpitY"), model:GetAttribute("CockpitZ")) * 0.75
			assert((cockpit.Position - expectedSeat).Magnitude < 0.001, id .. " rider seat ignored template scale")
			assert(World.getPilotScale(model) == model:GetAttribute("PilotScale"), id .. " rider size ignored template")
			passed = passed + 1
		end
		local standard = World.createPlane(fixture, "DefaultFallback", 1, "not-a-skin")
		assert(standard:GetAttribute("PlaneId") == "cruiser" and standard.Fuselage.Transparency == 0,
			"Unknown ID did not preserve the visible default plane")
		assert(World.getPilotScale(standard) == 0.9 and standard:FindFirstChild("MountVisual") == nil,
			"Standard plane inherited mount rider settings")
		passed = passed + 1
	end)
	fixture:Destroy()
	assert(ok, tostring(failure))
	return string.format("MountVisuals: %d native template and animation contracts passed", passed)
end
