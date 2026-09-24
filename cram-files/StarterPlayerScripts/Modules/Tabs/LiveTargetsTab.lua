-- Modules/Tabs/LiveTargetsTab.lua
-- Renders the live detected target inventory from server state

local UiKit = require(script.Parent.Parent.UiKit)
local CRAMClientConfig = require(script.Parent.Parent.CRAMClientConfig)

local LiveTargetsTab = {}

local COLORS = CRAMClientConfig.COLORS

function LiveTargetsTab.render(scroll, header, cachedState, onRefresh, onToggleDebug)
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local refresh = UiKit.mkB(scroll, "REFRESH LIVE INVENTORY", UDim2.new(0.62, -6, 0, 30), UDim2.new(0, 0, 0, 0), Color3.fromRGB(20, 23, 28), COLORS.BORDER)
	refresh.LayoutOrder = 1
	refresh.TextColor3 = COLORS.TEXT_MUTED
	refresh.MouseButton1Click:Connect(onRefresh)

	local isDebug = cachedState and cachedState.debug == true
	local debugButton = UiKit.mkB(scroll, isDebug and "DEBUG TRACE: ON" or "DEBUG TRACE: OFF", UDim2.new(0.38, -6, 0, 30), UDim2.new(0.62, 6, 0, 0), Color3.fromRGB(20, 23, 28), COLORS.BORDER)
	debugButton.LayoutOrder = 1
	debugButton.TextColor3 = COLORS.TEXT_MUTED
	debugButton.MouseButton1Click:Connect(function()
		onToggleDebug(not isDebug)
	end)

	local detected = (cachedState and cachedState.targets and cachedState.targets.detected) or {}
	local count = 0
	for _, item in ipairs(detected) do
		count = count + 1
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 38)
		row.BackgroundColor3 = COLORS.BG_CARD
		row.BorderSizePixel = 0
		row.LayoutOrder = count + 1
		row.Parent = scroll
		UiKit.mkS(row, COLORS.BORDER, 1, 0)

		local nameLabel = UiKit.mkL(row, tostring(item.name or "Unknown"), 10, COLORS.TEXT_MAIN)
		nameLabel.Size = UDim2.new(0.52, 0, 1, 0)
		nameLabel.Position = UDim2.new(0, 10, 0, 0)
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

		local typeLabel = UiKit.mkL(row, tostring(item.type or "TARGET CRAFT"), 9, COLORS.ACCENT_CYAN)
		typeLabel.Size = UDim2.new(0.25, 0, 1, 0)
		typeLabel.Position = UDim2.new(0.53, 0, 0, 0)

		local isPerm = item.isPerm == true
		local stateLabel = UiKit.mkL(row, isPerm and "TAGGED" or "READY", 9, isPerm and COLORS.ACCENT_AMBER or COLORS.ACCENT_GREEN, Enum.TextXAlignment.Right)
		stateLabel.Size = UDim2.new(0.2, 0, 1, 0)
		stateLabel.Position = UDim2.new(0.78, 0, 0, 0)
	end

	if count == 0 then
		local empty = UiKit.mkL(scroll, "NO TARGETABLE VEHICLES DETECTED", 11, Color3.fromRGB(80, 88, 95), Enum.TextXAlignment.Center)
		empty.Size = UDim2.new(1, -12, 0, 40)
		empty.LayoutOrder = 2
	end

	if header then
		header.Text = "LIVE TARGET INVENTORY  •  " .. tostring(count) .. " VEHICLES"
	end
end

return LiveTargetsTab
