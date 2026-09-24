-- Modules/Tabs/FleetTab.lua
-- Fleet management cards, CIWS unit selection, and Individual vs Global configuration

local UiKit = require(script.Parent.Parent.UiKit)
local CRAMClientConfig = require(script.Parent.Parent.CRAMClientConfig)
local TargetMatrixTab = require(script.Parent.TargetMatrixTab)

local FleetTab = {}

local COLORS = CRAMClientConfig.COLORS
local expandedUnits = {}
local fleetCards = {}

function FleetTab.update(
	fleetScroll,
	statsLabel,
	cachedState,
	onSendServer,
	onSelectCIWS
)
	if not cachedState or not cachedState.units then return end

	local units = cachedState.units
	local ta, eg, uc = 0, 0, 0

	for id, card in pairs(fleetCards) do
		if not units[id] then
			card:Destroy()
			fleetCards[id] = nil
		end
	end

	for id, u in pairs(units) do
		uc = uc + 1
		ta = ta + (u.stats.currentAmmo or 0)
		if u.stats.status == "ENGAGING" then eg = eg + 1 end

		local isIndiv = (u.config.targetMode == "INDIVIDUAL" or u.config.mode == "INDIVIDUAL")

		local card = fleetCards[id]
		if not card or not card.Parent then
			card = Instance.new("Frame")
			card.Name = "UnitCard_" .. id
			card.Size = UDim2.new(1, -12, 0, 128)
			card.BackgroundColor3 = COLORS.BG_PANEL
			card.BorderSizePixel = 0
			card.LayoutOrder = uc
			card.Parent = fleetScroll
			UiKit.mkS(card, COLORS.BORDER, 1, 0.5)
			fleetCards[id] = card

			local sd = Instance.new("Frame")
			sd.Name = "StatusDot"
			sd.Size = UDim2.new(0, 10, 0, 10)
			sd.Position = UDim2.new(0, 12, 0, 12)
			sd.BackgroundColor3 = COLORS.ACCENT_GREEN
			sd.BorderSizePixel = 0
			sd.Parent = card

			local nl = UiKit.mkL(card, "", 12, COLORS.TEXT_MAIN, Enum.TextXAlignment.Left, true)
			nl.Name = "NameLabel"
			nl.Size = UDim2.new(0.55, 0, 0, 20)
			nl.Position = UDim2.new(0, 28, 0, 8)
			nl.TextTruncate = Enum.TextTruncate.AtEnd

			local modeBadge = Instance.new("Frame")
			modeBadge.Name = "ModeBadge"
			modeBadge.Size = UDim2.new(0, 135, 0, 20)
			modeBadge.Position = UDim2.new(1, -145, 0, 8)
			modeBadge.BackgroundColor3 = isIndiv and Color3.fromRGB(45, 35, 15) or Color3.fromRGB(15, 35, 45)
			modeBadge.BorderSizePixel = 0
			modeBadge.Parent = card
			UiKit.mkS(modeBadge, isIndiv and COLORS.ACCENT_AMBER or COLORS.ACCENT_CYAN, 1, 0)

			local bl = UiKit.mkL(modeBadge, isIndiv and "[MODE: INDIVIDUAL]" or "[MODE: GLOBAL]", 9, isIndiv and COLORS.ACCENT_AMBER or COLORS.ACCENT_CYAN, Enum.TextXAlignment.Center, true)
			bl.Name = "BadgeLabel"
			bl.Size = UDim2.new(1, 0, 1, 0)

			local actionRow = Instance.new("Frame")
			actionRow.Name = "ActionRow"
			actionRow.Size = UDim2.new(1, -24, 0, 28)
			actionRow.Position = UDim2.new(0, 12, 0, 48)
			actionRow.BackgroundTransparency = 1
			actionRow.Parent = card

			local modeBtn = UiKit.mkB(
				actionRow,
				isIndiv and "[SWITCH TO GLOBAL MODE]" or "[SWITCH TO INDIVIDUAL MODE]",
				UDim2.new(0.48, -4, 0, 26),
				UDim2.new(0, 0, 0, 0),
				Color3.fromRGB(20, 23, 28),
				COLORS.BORDER
			)
			modeBtn.Name = "ModeBtn"
			modeBtn.TextSize = 9
			modeBtn.MouseButton1Click:Connect(function()
				local curUnit = cachedState.units[id]
				if not curUnit then return end
				local nextM = isIndiv and "GLOBAL" or "INDIVIDUAL"
				curUnit.config.targetMode = nextM
				curUnit.config.mode = (nextM == "GLOBAL") and "OVERALL" or "INDIVIDUAL"
				onSendServer("SetUnitTargetMode", { unitId = id, mode = nextM })
				onSendServer("SetUnitMode", { unitId = id, mode = (nextM == "GLOBAL") and "OVERALL" or "INDIVIDUAL" })
			end)

			local locateBtn = UiKit.mkB(
				actionRow,
				"LOCATE UNIT",
				UDim2.new(0.48, -4, 0, 26),
				UDim2.new(0.52, 0, 0, 0),
				Color3.fromRGB(20, 23, 28),
				COLORS.BORDER
			)
			locateBtn.Name = "LocateBtn"
			locateBtn.TextSize = 9
			locateBtn.MouseButton1Click:Connect(function()
				onSelectCIWS(id)
			end)

			local cfgBtn = UiKit.mkB(
				card,
				"[+] CONFIGURE TARGETING & FIRE CONTROL",
				UDim2.new(1, -24, 0, 26),
				UDim2.new(0, 12, 0, 86),
				Color3.fromRGB(20, 23, 28),
				COLORS.BORDER
			)
			cfgBtn.Name = "ConfigBtn"
			cfgBtn.TextSize = 9

			local cfgPanel = Instance.new("Frame")
			cfgPanel.Name = "ConfigPanel"
			cfgPanel.Size = UDim2.new(1, -24, 0, 0)
			cfgPanel.Position = UDim2.new(0, 12, 0, 120)
			cfgPanel.BackgroundColor3 = COLORS.BG_CARD
			cfgPanel.BorderSizePixel = 0
			cfgPanel.Visible = false
			cfgPanel.AutomaticSize = Enum.AutomaticSize.Y
			cfgPanel.Parent = card

			local cfgPad = Instance.new("UIPadding")
			cfgPad.PaddingTop = UDim.new(0, 10)
			cfgPad.PaddingBottom = UDim.new(0, 10)
			cfgPad.PaddingLeft = UDim.new(0, 10)
			cfgPad.PaddingRight = UDim.new(0, 10)
			cfgPad.Parent = cfgPanel

			local cfgLayout = Instance.new("UIListLayout")
			cfgLayout.SortOrder = Enum.SortOrder.LayoutOrder
			cfgLayout.Padding = UDim.new(0, 6)
			cfgLayout.Parent = cfgPanel

			cfgBtn.MouseButton1Click:Connect(function()
				local curUnit = cachedState.units[id]
				local curIsIndiv = curUnit and (curUnit.config.targetMode == "INDIVIDUAL" or curUnit.config.mode == "INDIVIDUAL")
				if not curIsIndiv then
					local origText = cfgBtn.Text
					local origColor = cfgBtn.TextColor3
					cfgBtn.Text = "SWITCH TO INDIVIDUAL MODE FIRST"
					cfgBtn.TextColor3 = COLORS.ACCENT_AMBER
					task.delay(1.2, function()
						if cfgBtn and cfgBtn.Parent then
							cfgBtn.Text = origText
							cfgBtn.TextColor3 = origColor
						end
					end)
					return
				end
				expandedUnits[id] = not expandedUnits[id]
				local exp = expandedUnits[id]
				cfgPanel.Visible = exp
				card.Size = UDim2.new(1, -12, 0, exp and 420 or 128)
				cfgBtn.Text = exp and "[-] CONFIGURE TARGETING & FIRE CONTROL" or "[+] CONFIGURE TARGETING & FIRE CONTROL"
			end)
		end

		local isOnline = u.config.enabled
		local sc = isOnline and (u.stats.status == "ENGAGING" and Color3.fromRGB(240, 140, 20) or COLORS.ACCENT_GREEN) or Color3.fromRGB(80, 88, 95)
		local sd = card:FindFirstChild("StatusDot")
		if sd and sd:IsA("Frame") then sd.BackgroundColor3 = sc end

		local nn = (u.config.nickname and u.config.nickname ~= "") and u.config.nickname or u.modelName
		local nl = card:FindFirstChild("NameLabel")
		if nl and nl:IsA("TextLabel") then nl.Text = nn end

		local modeBadge = card:FindFirstChild("ModeBadge")
		if modeBadge and modeBadge:IsA("Frame") then
			modeBadge.BackgroundColor3 = isIndiv and Color3.fromRGB(45, 35, 15) or Color3.fromRGB(15, 35, 45)
			local bst = modeBadge:FindFirstChildWhichIsA("UIStroke")
			if bst then bst.Color = isIndiv and COLORS.ACCENT_AMBER or COLORS.ACCENT_CYAN end
			local bl = modeBadge:FindFirstChild("BadgeLabel")
			if bl and bl:IsA("TextLabel") then
				bl.Text = isIndiv and "[MODE: INDIVIDUAL]" or "[MODE: GLOBAL]"
				bl.TextColor3 = isIndiv and COLORS.ACCENT_AMBER or COLORS.ACCENT_CYAN
			end
		end

		local ar = card:FindFirstChild("ActionRow")
		local mb = ar and ar:FindFirstChild("ModeBtn")
		if mb and mb:IsA("TextButton") then
			mb.Text = isIndiv and "[SWITCH TO GLOBAL MODE]" or "[SWITCH TO INDIVIDUAL MODE]"
		end
	end

	if statsLabel then
		statsLabel.Text = string.format("FLEET UNITS: %d  •  TOTAL AMMO: %s  •  ENGAGING: %d", uc, UiKit.formatNum(ta), eg)
	end
end

return FleetTab
