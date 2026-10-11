--!nonstrict
-- Client-safe cosmetic geometry only. The flight pivot and battle attachments
-- stay owned by World; wing motion never enters simulation or collision.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MountVisuals = {}
local active = setmetatable({}, { __mode = "k" })
local warned = {}
local STYLES = {
	stormcrown = { amplitude = math.rad(29), frequency = 0.95 },
	ironwing = { amplitude = math.rad(24), frequency = 1.1 },
	phoenix = { amplitude = math.rad(32), frequency = 0.85 },
	riftmanta = { amplitude = math.rad(16), frequency = 0.65 },
}

local function numberAttribute(object, name, fallback, minimum, maximum)
	local value = object:GetAttribute(name)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(value, minimum, maximum)
end

local function hasGeometry(group)
	if not group or not group:IsA("Model") then return false end
	for _, object in ipairs(group:GetDescendants()) do
		if object:IsA("BasePart") and object.Transparency < 1 then return true end
	end
	return false
end

local function fallback(model, id, reason)
	model:SetAttribute("MountVisualLoaded", false)
	model:SetAttribute("MountVisualStatus", reason)
	if not warned[id] then
		warned[id] = true
		warn("Legendary mount " .. id .. ": " .. reason .. "; using visible Cruiser fallback")
	end
	return false
end

function MountVisuals.attach(model, id)
	local style = STYLES[id]
	if not style then return false end
	if active[model] then return true end
	local shared = ReplicatedStorage:FindFirstChild("FlightGame")
	local templates = shared and shared:FindFirstChild("MountTemplates")
	local template = templates and templates:FindFirstChild(id)
	if not template or not template:IsA("Model") then return fallback(model, id, "MissingTemplate") end
	for _, name in ipairs({ "Body", "WingLeft", "WingRight" }) do
		if not hasGeometry(template:FindFirstChild(name)) then return fallback(model, id, "InvalidTemplate:" .. name) end
	end
	local visual = template:Clone()
	if not visual then return fallback(model, id, "TemplateNotArchivable") end
	visual.Name = "MountVisual"
	for _, object in ipairs(visual:GetDescendants()) do
		if object:IsA("LuaSourceContainer") or object:IsA("JointInstance") or object:IsA("Constraint") then
			object:Destroy()
		elseif object:IsA("BasePart") then
			object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
			object.Massless, object.CastShadow = true, false
			object.LocalTransparencyModifier = 0
			object:SetAttribute("MountGeometry", true)
		end
	end
	-- Templates use an origin pivot and +X forward. Attach while the plane is
	-- at base scale; every later ScaleTo also scales these nested models.
	visual:PivotTo(model:GetPivot())
	visual.Parent = model
	local data = {
		visual = visual, phase = 0, amplitude = 0,
		frequency = numberAttribute(template, "FlapFrequency", style.frequency, 0.1, 3),
		flightAmplitude = numberAttribute(template, "FlapAmplitude", style.amplitude, 0, math.rad(65)),
		idleAmplitude = numberAttribute(template, "IdleFlapAmplitude", style.amplitude * 0.3, 0, math.rad(35)),
		wings = {},
	}
	local base = model:GetPivot()
	for _, name in ipairs({ "WingLeft", "WingRight" }) do
		local wing = visual:FindFirstChild(name)
		table.insert(data.wings, { model = wing, rest = base:ToObjectSpace(wing:GetPivot()),
			direction = name == "WingLeft" and 1 or -1 })
	end
	active[model] = data
	model:SetAttribute("MountVisualLoaded", true)
	model:SetAttribute("MountVisualStatus", "Ready")
	model:SetAttribute("PilotScale", numberAttribute(template, "PilotScale", 0.45, 0.2, 1.2))
	model:SetAttribute("CockpitX", numberAttribute(template, "CockpitX", 0.15, -12, 12))
	model:SetAttribute("CockpitY", numberAttribute(template, "CockpitY", 1.25, -12, 12))
	model:SetAttribute("CockpitZ", numberAttribute(template, "CockpitZ", 0, -12, 12))
	model:SetAttribute("CockpitYaw", numberAttribute(template, "CockpitYaw", -math.pi / 2, -math.pi * 2, math.pi * 2))
	return true
end

-- Call after the owning plane's PivotTo. Knockout freezes the current wing
-- pose, so the crash's floor-contact geometry remains valid throughout its fall.
function MountVisuals.update(model, dt, moving, frozen, reducedMotion)
	local data = active[model]
	if not data or not model.Parent or frozen then return end
	dt = math.clamp(type(dt) == "number" and dt or 0, 0, 0.1)
	local amplitude = moving and data.flightAmplitude or data.idleAmplitude
	if reducedMotion then amplitude = amplitude * 0.25 end
	data.amplitude = data.amplitude + (amplitude - data.amplitude) * (1 - math.exp(-8 * dt))
	data.phase = (data.phase + dt * math.pi * 2 * data.frequency * (moving and 1 or 0.55)) % (math.pi * 2)
	local angle = math.sin(data.phase) * data.amplitude
	local pose, scale = model:GetPivot(), model:GetScale()
	for _, wing in ipairs(data.wings) do
		wing.model:PivotTo(pose * CFrame.new(wing.rest.Position * scale) * wing.rest.Rotation
			* CFrame.Angles(angle * wing.direction, 0, 0))
	end
end

function MountVisuals.getCockpitOffset(model)
	if model:GetAttribute("MountVisualLoaded") ~= true then return nil end
	return CFrame.new(model:GetAttribute("CockpitX"), model:GetAttribute("CockpitY"), model:GetAttribute("CockpitZ"))
		* CFrame.Angles(0, model:GetAttribute("CockpitYaw"), 0)
end

function MountVisuals.getPilotScale(model)
	return model:GetAttribute("MountVisualLoaded") == true
		and numberAttribute(model, "PilotScale", 0.45, 0.2, 1.2) or 0.9
end

return MountVisuals
