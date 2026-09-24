-- StarterPlayerScripts/MasterCRAM_Client.client.lua
-- Main client controller for Master C-RAM system. Runs once in StarterPlayerScripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

local Modules = script.Parent:WaitForChild("Modules")
local UiKit = require(Modules:WaitForChild("UiKit"))
local CRAMClientConfig = require(Modules:WaitForChild("CRAMClientConfig"))
local StateStore = require(Modules:WaitForChild("StateStore"))
local VehicleResolver = require(Modules:WaitForChild("VehicleResolver"))
local PlacementController = require(Modules:WaitForChild("PlacementController"))
local WorldOverlays = require(Modules:WaitForChild("WorldOverlays"))

local Tabs = Modules:WaitForChild("Tabs")
local TargetMatrixTab = require(Tabs:WaitForChild("TargetMatrixTab"))
local FleetTab = require(Tabs:WaitForChild("FleetTab"))
local LiveTargetsTab = require(Tabs:WaitForChild("LiveTargetsTab"))
local TraceTab = require(Tabs:WaitForChild("TraceTab"))

local TOOL_NAME = "Master C-RAM"
local COLORS = CRAMClientConfig.COLORS

-- Ensure clean UI instance
local existingUI = pgui:FindFirstChild("MasterCRAMUI")
if existingUI then
	existingUI:Destroy()
end

local sg = Instance.new("ScreenGui")
sg.Name = "MasterCRAMUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = 10
sg.Enabled = false
sg.Parent = pgui

-- Main window container
local mf = Instance.new("Frame")
mf.Name = "MainFrame"
mf.Size = UDim2.new(0, 1040, 0, 720)
mf.Position = UDim2.new(0.5, -520, 0.5, -360)
mf.BackgroundColor3 = COLORS.BG_DARK
mf.BorderSizePixel = 0
mf.Parent = sg
UiKit.mkS(mf, COLORS.BORDER_ACCENT, 1, 0.2)

-- Header bar
local hb = Instance.new("Frame")
hb.Name = "HeaderBar"
hb.Size = UDim2.new(1, 0, 0, 44)
hb.BackgroundColor3 = COLORS.BG_PANEL
hb.BorderSizePixel = 0
hb.Parent = mf
UiKit.mkS(hb, COLORS.BORDER, 1, 0)

local title = UiKit.mkL(hb, "MASTER C-RAM DEFENSE NETWORK", 12, COLORS.TEXT_MAIN, Enum.TextXAlignment.Left, true)
title.Position = UDim2.new(0, 14, 0, 4)
title.Size = UDim2.new(0.5, 0, 0, 18)

local subtitle = UiKit.mkL(hb, "TACTICAL AIR DEFENSE INTERCEPT SYSTEM // ACTIVE MONITORING", 9, COLORS.TEXT_MUTED, Enum.TextXAlignment.Left, false)
subtitle.Position = UDim2.new(0, 14, 0, 24)
subtitle.Size = UDim2.new(0.5, 0, 0, 16)

local closeBtn = UiKit.mkB(hb, "X", UDim2.new(0, 32, 0, 28), UDim2.new(1, -40, 0.5, -14), COLORS.BG_CARD, COLORS.BORDER)
closeBtn.MouseButton1Click:Connect(function()
	mf.Visible = false
end)

UiKit.makeWindowDraggable(mf, hb)

-- Tab Bar
local tb = Instance.new("Frame")
tb.Name = "TabBar"
tb.Size = UDim2.new(1, 0, 0, 36)
tb.Position = UDim2.new(0, 0, 0, 44)
tb.BackgroundColor3 = COLORS.BG_DARK
tb.BorderSizePixel = 0
tb.Parent = mf
UiKit.mkS(tb, COLORS.BORDER, 1, 0)

local tbLayout = Instance.new("UIListLayout")
tbLayout.FillDirection = Enum.FillDirection.Horizontal
tbLayout.SortOrder = Enum.SortOrder.LayoutOrder
tbLayout.Padding = UDim.new(0, 2)
tbLayout.Parent = tb

local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, 0, 1, -80)
contentArea.Position = UDim2.new(0, 0, 0, 80)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mf

-- Tabs
local tabFrames = {}
local tabButtons = {}

local function createTabFrame(tabName)
	local f = Instance.new("Frame")
	f.Name = "Tab_" .. tabName
	f.Size = UDim2.new(1, 0, 1, 0)
	f.BackgroundTransparency = 1
	f.Visible = false
	f.Parent = contentArea
	tabFrames[tabName] = f
	return f
end

local fleetFrame = createTabFrame("FLEET")
local targetsFrame = createTabFrame("TARGETS")
local liveFrame = createTabFrame("LIVE")
local traceFrame = createTabFrame("TRACE")

local TAB_NAMES = { "FLEET", "TARGETS", "LIVE", "TRACE" }

local function getTool()
	local char = player.Character
	if char then
		local t = char:FindFirstChild(TOOL_NAME)
		if t and t:IsA("Tool") then return t end
	end
	local bp = player:FindFirstChild("Backpack")
	if bp then
		local t = bp:FindFirstChild(TOOL_NAME)
		if t and t:IsA("Tool") then return t end
	end
	return nil
end

local function sendServer(action, data)
	local tool = getTool()
	if tool then
		local remote = tool:FindFirstChild("MasterRemote")
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer(action, data or {})
		end
	end
end

-- Setup Tab buttons
for idx, tabName in ipairs(TAB_NAMES) do
	local btn = UiKit.mkB(tb, tabName, UDim2.new(0, 120, 1, 0), nil, COLORS.BG_DARK, COLORS.BORDER)
	btn.LayoutOrder = idx
	btn.TextSize = 10
	tabButtons[tabName] = btn

	btn.MouseButton1Click:Connect(function()
		StateStore.setActiveTab(tabName)
	end)
end

local function switchTab(tabName)
	for name, frame in pairs(tabFrames) do
		frame.Visible = (name == tabName)
	end
	for name, btn in pairs(tabButtons) do
		local active = (name == tabName)
		btn.BackgroundColor3 = active and COLORS.BG_PANEL or COLORS.BG_DARK
		btn.TextColor3 = active and COLORS.ACCENT_CYAN or COLORS.TEXT_MUTED
	end
	if tabName == "FLEET" then
		FleetTab.update(fleetFrame:FindFirstChild("Scroll"), nil, StateStore.getCachedState(), sendServer, function(id) end)
	elseif tabName == "LIVE" then
		LiveTargetsTab.render(liveFrame:FindFirstChild("Scroll"), nil, StateStore.getCachedState(), function()
			sendServer("RequestFullState")
		end, function(val)
			sendServer("SetDebug", val)
		end)
	elseif tabName == "TRACE" then
		TraceTab.render(traceFrame:FindFirstChild("TraceBox"), nil, StateStore.getCachedState().debug == true)
	end
end

StateStore.subscribe("TabChanged", function(newTab)
	switchTab(tostring(newTab))
end)

-- Populate Fleet Tab
local fleetScroll = Instance.new("ScrollingFrame")
fleetScroll.Name = "Scroll"
fleetScroll.Size = UDim2.new(1, -20, 1, -20)
fleetScroll.Position = UDim2.new(0, 10, 0, 10)
fleetScroll.BackgroundTransparency = 1
fleetScroll.ScrollBarThickness = 4
fleetScroll.Parent = fleetFrame

local fsLayout = Instance.new("UIListLayout")
fsLayout.SortOrder = Enum.SortOrder.LayoutOrder
fsLayout.Padding = UDim.new(0, 8)
fsLayout.Parent = fleetScroll

-- Populate Targets Tab
local targetsScroll = Instance.new("ScrollingFrame")
targetsScroll.Name = "Scroll"
targetsScroll.Size = UDim2.new(1, -20, 1, -20)
targetsScroll.Position = UDim2.new(0, 10, 0, 10)
targetsScroll.BackgroundTransparency = 1
targetsScroll.ScrollBarThickness = 4
targetsScroll.Parent = targetsFrame

local tsLayout = Instance.new("UIListLayout")
tsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tsLayout.Padding = UDim.new(0, 8)
tsLayout.Parent = targetsScroll

-- Populate Live Tab
local liveScroll = Instance.new("ScrollingFrame")
liveScroll.Name = "Scroll"
liveScroll.Size = UDim2.new(1, -20, 1, -20)
liveScroll.Position = UDim2.new(0, 10, 0, 10)
liveScroll.BackgroundTransparency = 1
liveScroll.ScrollBarThickness = 4
liveScroll.Parent = liveFrame

local lsLayout = Instance.new("UIListLayout")
lsLayout.SortOrder = Enum.SortOrder.LayoutOrder
lsLayout.Padding = UDim.new(0, 4)
lsLayout.Parent = liveScroll

-- Populate Trace Tab
local traceBox = Instance.new("TextBox")
traceBox.Name = "TraceBox"
traceBox.Size = UDim2.new(1, -20, 1, -20)
traceBox.Position = UDim2.new(0, 10, 0, 10)
traceBox.BackgroundColor3 = COLORS.BG_PANEL
traceBox.TextColor3 = COLORS.TEXT_MAIN
traceBox.Font = Enum.Font.RobotoMono
traceBox.TextSize = 10
traceBox.ClearTextOnFocus = false
traceBox.TextXAlignment = Enum.TextXAlignment.Left
traceBox.TextYAlignment = Enum.TextYAlignment.Top
traceBox.Parent = traceFrame
UiKit.mkS(traceBox, COLORS.BORDER, 1, 0)

-- Initial tab selection
switchTab("FLEET")

-- Remote listener wiring
local hookedRemotes = {}
local function hookRemote()
	local tool = getTool()
	if not tool then return end
	local remote = tool:FindFirstChild("MasterRemote")
	if remote and remote:IsA("RemoteEvent") and not hookedRemotes[remote] then
		hookedRemotes[remote] = true
		remote.OnClientEvent:Connect(function(action, data)
			if action == "FullState" then
				StateStore.setCachedState(data)
				local curTab = StateStore.getActiveTab()
				if curTab == "FLEET" then
					FleetTab.update(fleetScroll, nil, data, sendServer, function(id) end)
				elseif curTab == "TARGETS" then
					local wl = (data.targets and data.targets.whitelist) or {}
					TargetMatrixTab.render(targetsScroll, wl, function(updatedWl)
						sendServer("SetTargetWhitelist", { whitelist = updatedWl })
					end)
				elseif curTab == "LIVE" then
					LiveTargetsTab.render(liveScroll, nil, data, function()
						sendServer("RequestFullState")
					end, function(val)
						sendServer("SetDebug", val)
					end)
				elseif curTab == "TRACE" then
					TraceTab.render(traceBox, nil, data.debug == true)
				end
			end
		end)
	end
end

-- Tool lifecycle wiring
local syncThread = nil
local overlayThread = nil

local function onEquip()
	hookRemote()
	sg.Enabled = true
	mf.Visible = true
	sendServer("RequestFullState")

	if syncThread then task.cancel(syncThread) end
	syncThread = task.spawn(function()
		while sg.Enabled do
			sendServer("RequestFullState")
			task.wait(3)
		end
	end)

	if overlayThread then task.cancel(overlayThread) end
	overlayThread = task.spawn(function()
		while sg.Enabled do
			WorldOverlays.update(StateStore.getCachedState(), function(mdl)
				StateStore.setSelectedCIWS(mdl)
				StateStore.setActiveTab("FLEET")
			end)
			task.wait(1)
		end
	end)
end

local function onUnequip()
	sg.Enabled = false
	mf.Visible = false
	PlacementController.stopPlacement()
	WorldOverlays.clear()
	if syncThread then
		task.cancel(syncThread)
		syncThread = nil
	end
	if overlayThread then
		task.cancel(overlayThread)
		overlayThread = nil
	end
end

-- Watch Character and Backpack for tool equipping
local function setupTool(tool)
	if tool.Name ~= TOOL_NAME then return end
	if tool:GetAttribute("MasterCRAM_Hooked") then return end
	tool:SetAttribute("MasterCRAM_Hooked", true)
	tool.Equipped:Connect(onEquip)
	tool.Unequipped:Connect(onUnequip)
end

local function checkContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") and child.Name == TOOL_NAME then
			setupTool(child)
		end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == TOOL_NAME then
			setupTool(child)
		end
	end)
end

if player.Character then
	checkContainer(player.Character)
end
player.CharacterAdded:Connect(function(char)
	checkContainer(char)
end)

local bp = player:WaitForChild("Backpack", 5)
if bp then
	checkContainer(bp)
end

hookRemote()

-- Listen to trace store changes if present
local traceStore = ReplicatedStorage:FindFirstChild("CRAM_TRACE_LOG")
if traceStore and traceStore:IsA("StringValue") then
	traceStore.Changed:Connect(function()
		if StateStore.getActiveTab() == "TRACE" then
			TraceTab.render(traceBox, nil, StateStore.getCachedState().debug == true)
		end
	end)
end
