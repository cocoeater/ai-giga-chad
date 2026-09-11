local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = {
	RecordFPS = 30,
	HistoryFrames = 26,
	NoiseFrequency = 0.12,
	ScrollSpeed = 5,
	JitterStuds = 6,
	RotationJitter = 0.35,
	PulseIn = 0.2,
	PulseHold = 0.7,
	PulseOut = 0.5,
	AutoDemoPulse = true,
}

local HISTORY = Config.HistoryFrames
local entries = {}
local lookup = {}
local warpActive = false

local function isRootPart(part)
	return part.Name == "HumanoidRootPart"
end

local function register(inst)
	if not inst:IsA("BasePart") then
		return
	end
	if lookup[inst] or warpActive then
		return
	end
	local entry = {
		part = inst,
		rest = inst.CFrame,
		ring = nil,
		index = 1,
	}
	lookup[inst] = entry
	entries[#entries + 1] = entry
end

local function scanWorkspace()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		register(descendant)
	end
end

local function unregister(inst)
	local entry = lookup[inst]
	if not entry then
		return
	end
	lookup[inst] = nil
	local at = table.find(entries, entry)
	if at then
		entries[at] = entries[#entries]
		entries[#entries] = nil
	end
end

local recorderAccumulator = 0

local function record(entry)
	local part = entry.part
	local current = part.CFrame
	local ring = entry.ring
	if ring then
		ring[entry.index] = current
		entry.index = (entry.index % HISTORY) + 1
	elseif not warpActive and current ~= entry.rest then
		entry.ring = table.create(HISTORY, current)
		entry.index = 2
	end
end

RunService.Heartbeat:Connect(function(dt)
	recorderAccumulator = recorderAccumulator + dt
	local interval = 1 / Config.RecordFPS
	if recorderAccumulator < interval then
		return
	end
	recorderAccumulator = recorderAccumulator % interval
	for i = #entries, 1, -1 do
		local entry = entries[i]
		if entry.part.Parent then
			record(entry)
		else
			unregister(entry.part)
		end
	end
end)

local function noiseField(x, y, z)
	local f = Config.NoiseFrequency
	local coarse = math.noise(x * f, y * f, z * f)
	local fine = math.noise(x * f * 3.3 + 17.1, y * f * 3.3 - 9.2, z * f * 3.3 + 4.7)
	return coarse * 0.78 + fine * 0.22
end

local function pulseEnvelope(t)
	local inTime, holdTime, outTime = Config.PulseIn, Config.PulseHold, Config.PulseOut
	if t < inTime then
		local u = t / inTime
		return u * u * (3 - 2 * u)
	elseif t < inTime + holdTime then
		return 1
	elseif t < inTime + holdTime + outTime then
		local u = 1 - (t - inTime - holdTime) / outTime
		return u * u * (3 - 2 * u)
	end
	return 0
end

local continuous = false
local pulseTime = nil
local partsOut = {}
local cframesOut = {}
local refreshHud

local function restoreStaticParts()
	local written = 0
	for i = 1, #entries do
		local entry = entries[i]
		local part = entry.part
		if part.Parent and not entry.ring and not isRootPart(part) then
			written = written + 1
			partsOut[written] = part
			cframesOut[written] = entry.rest
		end
	end
	for kill = written + 1, #partsOut do
		partsOut[kill] = nil
		cframesOut[kill] = nil
	end
	if written > 0 then
		workspace:BulkMoveTo(partsOut, cframesOut, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

RunService:BindToRenderStep("NightcrawlerWarpRender", Enum.RenderPriority.Character.Value + 1, function(dt)
	local amount = 0
	if continuous then
		amount = 1
	elseif pulseTime then
		pulseTime = pulseTime + dt
		amount = pulseEnvelope(pulseTime)
		if pulseTime >= Config.PulseIn + Config.PulseHold + Config.PulseOut then
			pulseTime = nil
			amount = 0
		end
	end
	local active = amount > 0
	if active ~= warpActive then
		warpActive = active
		if active then
			if refreshHud then
				refreshHud()
			end
		else
			restoreStaticParts()
			scanWorkspace()
			if refreshHud then
				refreshHud()
			end
		end
	end
	if amount <= 0 then
		return
	end

	local scroll = os.clock() * Config.ScrollSpeed
	local written = 0

	for i = 1, #entries do
		local entry = entries[i]
		local part = entry.part
		if part.Parent and not isRootPart(part) then
			local base = part.CFrame
			local target

			if entry.ring then
				local position = base.Position
				local u = (noiseField(position.X + scroll, position.Y, position.Z - scroll * 0.4) + 1) * 0.5
				local framesBack = math.clamp(math.floor(u * HISTORY * amount), 0, HISTORY - 1)
				local slot = ((entry.index - 1 - framesBack) % HISTORY) + 1
				target = entry.ring[slot]
			else
				local rest = entry.rest
				local p = rest.Position
				local jitter = Vector3.new(
					noiseField(p.X + scroll, p.Y, p.Z),
					noiseField(p.X, p.Y + scroll, p.Z),
					noiseField(p.X, p.Y, p.Z + scroll)
				) * (Config.JitterStuds * amount)
				local spin = CFrame.Angles(
					noiseField(p.X + 31.4, p.Y, p.Z) * Config.RotationJitter * amount,
					noiseField(p.X, p.Y - 17.6, p.Z) * Config.RotationJitter * amount,
					noiseField(p.X, p.Y, p.Z + 11.8) * Config.RotationJitter * amount
				)
				target = CFrame.new(p + jitter) * rest.Rotation * spin
			end

			written = written + 1
			partsOut[written] = part
			cframesOut[written] = base:Lerp(target, amount)
		end
	end

	for kill = written + 1, #partsOut do
		partsOut[kill] = nil
		cframesOut[kill] = nil
	end
	if written > 0 then
		workspace:BulkMoveTo(partsOut, cframesOut, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

scanWorkspace()
workspace.DescendantAdded:Connect(register)
workspace.DescendantRemoving:Connect(unregister)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NightcrawlerWarpHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(360, 58)
label.Position = UDim2.fromOffset(14, 14)
label.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
label.BackgroundTransparency = 0.3
label.TextColor3 = Color3.fromRGB(235, 235, 245)
label.Font = Enum.Font.Code
label.TextSize = 15
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.RichText = true
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 10)
padding.Parent = label
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = label
label.Parent = screenGui
screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

function refreshHud()
	if continuous or pulseTime then
		label.Text = "<b>WARP ACTIVE</b>\nT: pulse   Y: constant off"
		label.TextColor3 = Color3.fromRGB(150, 235, 255)
	else
		label.Text = "<b>Nightcrawler Warp</b>\nT: warp pulse   Y: constant on/off"
		label.TextColor3 = Color3.fromRGB(235, 235, 245)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.T then
		pulseTime = 0
		refreshHud()
	elseif input.KeyCode == Enum.KeyCode.Y then
		continuous = not continuous
		warpActive = continuous
		refreshHud()
	end
end)

refreshHud()

if Config.AutoDemoPulse then
	task.delay(2, function()
		if not continuous and not pulseTime then
			pulseTime = 0
			refreshHud()
		end
	end)
end
