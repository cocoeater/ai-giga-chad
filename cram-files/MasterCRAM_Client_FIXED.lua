local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

for _, g in ipairs(pgui:GetChildren()) do
	if g:IsA("ScreenGui") and g.Name == "MasterCRAMUI" and g ~= script.Parent then
		g:Destroy()
	end
end

local TARGET_CATEGORIES = {
	{
		id = "HELICOPTERS",
		category = "ROTARY WING / HELICOPTERS",
		categoryTag = "HELICOPTER",
		color = Color3.fromRGB(210, 215, 220),
		items = {
			"SA330 Helicopter",
			"OH-6 Loach (Scout)",
			"CH-178",
			"Mi-8",
			"NH-90",
			"UH-60M",
			"LAAT",
			"UH-1Y"
		}
	},
	{
		id = "JETS",
		category = "FIXED-WING / COMBAT JETS",
		categoryTag = "COMBAT_JET",
		color = Color3.fromRGB(210, 215, 220),
		items = {
			"F-16C",
			"A-10C",
			"SU-25"
		}
	},
	{
		id = "GROUND",
		category = "GROUND VEHICLES & COMBAT TRUCKS",
		categoryTag = "GROUND_VEHICLE",
		color = Color3.fromRGB(210, 215, 220),
		items = {
			"Humvee M1115",
			"MRAP L-ATV",
			"M939 Utility Truck",
			"HEMTT",
			"Lenco BEARCAT",
			'Gaz 233036 "Tigr-M"',
			"Kamaz 5350",
			"Typhoon",
			"Ural 4320",
			"B6 GMC Yukon Denali",
			"Toyota Land Cruiser",
			"Technical",
			"Mazda RX-7",
			"Nissan Skyline R34",
			"Dacia 1300",
			"Lexus LFA",
			"GT500 Shelby",
			"Dodge Charger Hellcat",
			"Dodge Challenger Hellcat",
			"Mercedes-AMG G36"
		}
	},
	{
		id = "MUNITIONS",
		category = "DRONES & INCOMING MUNITIONS",
		categoryTag = "AIR_DRONE",
		color = Color3.fromRGB(210, 215, 220),
		items = {
			"AIR_DRONE",
			"MISSILES",
			"ARTILLERY_SHELLS"
		}
	}
}

local ALL_PRESET_ITEMS = {}
local PRESET_CATALOG = {}
for _, cat in ipairs(TARGET_CATEGORIES) do
	table.insert(ALL_PRESET_ITEMS, cat.categoryTag)
	for _, it in ipairs(cat.items) do
		table.insert(ALL_PRESET_ITEMS, it)
		table.insert(PRESET_CATALOG, it)
	end
end

local PRESET_SET = {}
for _, item in ipairs(ALL_PRESET_ITEMS) do
	PRESET_SET[string.lower(string.gsub(string.gsub(string.gsub(tostring(item), "%s*#%d+", ""), "%s*%(Clone%)", ""), "_%d+$", ""))] = true
end

local function makeWhitelist(source)
	local list = table.clone(source or {})
	if #list > 0 then return list end
	for _, item in ipairs(ALL_PRESET_ITEMS) do
		table.insert(list, item)
	end
	return list
end

local cachedState = nil

local function cleanModelName(rawName)
	if not rawName then return "" end
	local n = tostring(rawName)
	n = string.gsub(n, "%s*#%d+", "")
	n = string.gsub(n, "%s*%(Clone%)", "")
	n = string.gsub(n, "%s*%(%d+%)", "")
	n = string.gsub(n, "_%d+$", "")
	return n
end

local function isVehicleOrTarget(m)
	if not m or not m:IsA("Model") then return false end
	if m == workspace or m.Name == "Map" or m.Name == "Baseplate" or m.Name == "Terrain" or m.Name == "Ciws" or m.Name == "Inserter" or m.Name == "Model" then
		local modelKey = string.lower(m.Name)
		if modelKey == "map" or modelKey == "small city" or modelKey == "city" or modelKey == "town" or modelKey == "terrain" or modelKey == "scenery" or modelKey == "environment" then return false end
		return false
	end
	local Players = game:GetService("Players")
	if Players:GetPlayerFromCharacter(m) then return false end
	local hasUnanchored = false
	for _, item in ipairs(m:GetDescendants()) do
		if item:IsA("BasePart") and not item.Anchored then
			hasUnanchored = true
			break
		end
	end
	local explicitTarget = m:FindFirstChild("A-Chassis Tune", true) or m:FindFirstChildWhichIsA("VehicleSeat", true) or m:FindFirstChild("DriveSeat", true) or m:FindFirstChild("Drive", true) or m:FindFirstChildOfClass("Humanoid") or m:FindFirstChildWhichIsA("Humanoid", true) or m:FindFirstChild("Durability", true) or m:FindFirstChild("Health", true) or m:FindFirstChild("Arsenal", true) or m:FindFirstChild("Damage", true) or m:FindFirstChild("CanBeTargetted", true)
	local structuralTarget = hasUnanchored and (m:FindFirstChild("Engine", true) or m:FindFirstChild("Chassis", true) or m:FindFirstChild("Body", true) or m:FindFirstChild("Fuselage", true) or m:FindFirstChild("Cockpit", true) or m:FindFirstChild("Hull", true))
	if explicitTarget or structuralTarget then return true end
	return false
end

local function getBestTargetPart(mdl, targetPart)
	if not mdl then return targetPart end
	local vehSeat = mdl:FindFirstChild("DriveSeat", true) or mdl:FindFirstChildWhichIsA("VehicleSeat", true)
	if vehSeat and vehSeat:IsA("BasePart") then return vehSeat end
	local hrp = mdl:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp end
	local dur = mdl:FindFirstChild("Durability", true) or mdl:FindFirstChild("Health", true) or mdl:FindFirstChild("Arsenal", true) or mdl:FindFirstChild("Damage", true)
	if dur and dur.Parent and dur.Parent:IsA("BasePart") then return dur.Parent end
	for _, pName in ipairs({"Engine", "Chassis", "Body", "Weight", "#Weight", "VehicleBase", "MAIN", "Fuselage", "Center", "Cockpit", "Hull"}) do
		local found = mdl:FindFirstChild(pName, true)
		if found and found:IsA("BasePart") then return found end
	end
	if mdl.PrimaryPart and mdl.PrimaryPart:IsA("BasePart") then return mdl.PrimaryPart end
	if targetPart and targetPart:IsA("BasePart") then return targetPart end
	return mdl:FindFirstChildWhichIsA("BasePart", true)
end

local function getUncategorizedDetectedTargets()
	local uncategorized = {}
	local seen = {}

	if cachedState and cachedState.targets and cachedState.targets.detected then
		for _, item in ipairs(cachedState.targets.detected) do
			local cName = cleanModelName(item.cleanName or item.name)
			local low = string.lower(cName)
			if cName ~= "" and not PRESET_SET[low] then
				local uniqueKey = item.part or (item.name .. tostring(#uncategorized + 1))
				if not seen[uniqueKey] then
					seen[uniqueKey] = true
					table.insert(uncategorized, {
						name = item.name or cName,
						cleanName = cName,
						type = item.type or "Detected Vehicle",
						part = item.part,
						isPerm = item.isPerm
					})
				end
			end
		end
	end

	local permRules = (cachedState and cachedState.targets and (cachedState.targets.permRules or cachedState.targets.perm)) or {}
	for _, rule in ipairs(permRules) do
		local rName = type(rule) == "table" and rule.name or rule
		if rName then
			local cName = cleanModelName(rName)
			local low = string.lower(cName)
			if cName ~= "" and not PRESET_SET[low] and not seen[low] then
				seen[low] = true
				table.insert(uncategorized, {
					name = rName,
					cleanName = cName,
					type = "Permanent Target",
					isPerm = true
				})
			end
		end
	end

	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and isVehicleOrTarget(m) and not game:GetService("Players"):GetPlayerFromCharacter(m) then
			local cName = cleanModelName(m.Name)
			local low = string.lower(cName)
			if cName ~= "" and not PRESET_SET[low] and not seen[low] then
				seen[low] = true
				table.insert(uncategorized, {
					name = m.Name,
					cleanName = cName,
					type = "Detected Vehicle",
					part = getBestTargetPart(m)
				})
			end
		end
	end

	table.sort(uncategorized, function(a, b) return a.cleanName < b.cleanName end)
	return uncategorized
end



local function formatNum(n)
	if not n then return "0" end
	local formatted = tostring(math.floor(tonumber(n) or 0))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

local mouse = player:GetMouse()
local sg = script.Parent
local mf = sg:WaitForChild("MainFrame")
local hb = mf:WaitForChild("HeaderBar")
local tb = mf:WaitForChild("TabBar")
local ca = mf:WaitForChild("ContentArea")
local dec = mf:WaitForChild("Decorations")

local targetsTab = ca:WaitForChild("TARGETS_TAB")
local deployTab = ca:WaitForChild("DEPLOY_TAB")
local fleetTab = ca:WaitForChild("FLEET_TAB")
local globalTab = ca:WaitForChild("GLOBAL_TAB")
local liveTab = ca:WaitForChild("LIVETAB")
local traceTab = ca:WaitForChild("TRACETAB")

local tabsMap = {
	TARGETS = targetsTab,
	DEPLOY = deployTab,
	FLEET = fleetTab,
	GLOBAL = globalTab,
	LIVE = liveTab,
	TRACE = traceTab,
}

local tabDefaultSizes = {
	TARGETS = UDim2.new(0, 1040, 0, 720),
	DEPLOY = UDim2.new(0, 1040, 0, 720),
	FLEET = UDim2.new(0, 1040, 0, 720),
	GLOBAL = UDim2.new(0, 1040, 0, 720),
	LIVE = UDim2.new(0, 1040, 0, 720),
	TRACE = UDim2.new(0, 1040, 0, 720),
}

local TOOL_NAME = "Master C-RAM"

local BG_DARK = Color3.fromRGB(6, 9, 10)
local BG_PANEL = Color3.fromRGB(12, 16, 17)
local BG_CARD = Color3.fromRGB(18, 23, 24)
local BG_CARD_HOVER = Color3.fromRGB(26, 33, 33)
local BG_INPUT = Color3.fromRGB(10, 14, 15)

local BORDER = Color3.fromRGB(47, 58, 57)
local BORDER_ACCENT = Color3.fromRGB(76, 91, 89)
local DIVIDER = Color3.fromRGB(39, 49, 49)

local TEXT_PRIMARY = Color3.fromRGB(205, 215, 211)
local TEXT_SECONDARY = Color3.fromRGB(139, 153, 151)
local TEXT_DIM = Color3.fromRGB(82, 99, 97)

local SUCCESS = Color3.fromRGB(105, 140, 110)
local SUCCESS_BG = Color3.fromRGB(18, 30, 22)
local SUCCESS_BORDER = Color3.fromRGB(45, 70, 50)

local ACCENT = Color3.fromRGB(190, 105, 95)
local ACCENT_BG = Color3.fromRGB(45, 24, 23)
local ACCENT_BORDER = Color3.fromRGB(100, 52, 46)
local ACCENT_HOVER = Color3.fromRGB(58, 30, 28)
local ACCENT_DIM = Color3.fromRGB(32, 20, 19)

local AMBER = Color3.fromRGB(190, 156, 75)
local AMBER_BG = Color3.fromRGB(42, 35, 18)
local AMBER_BORDER = Color3.fromRGB(105, 84, 42)
local AMBER_DIM = Color3.fromRGB(29, 26, 17)
local WARNING = AMBER
local WARNING_BG = AMBER_BG
local WARNING_BORDER = AMBER_BORDER

local CYAN = Color3.fromRGB(112, 164, 174)
local CYAN_BG = Color3.fromRGB(17, 32, 36)
local CYAN_BORDER = Color3.fromRGB(52, 82, 88)
local CYAN_DIM = Color3.fromRGB(14, 25, 28)

local TEXT_MUTED = Color3.fromRGB(104, 119, 117)

local FONT = Enum.Font.Code
local FONT_MEDIUM = Enum.Font.Code
local FONT_BOLD = Enum.Font.Code

local currentTab = "TARGETS"
local currentMode = "SINGLE"
local hoverHighlight = nil
local placementMode = false
local placementGhost = nil
local placementTemplate = nil
local placementRotation = 0
local connections = {}
local worldGuis = {}
local expandedUnits = {}
local fleetCards = {}
local globalSlidersBuilt = false
local renderSteppedConn = nil
local equipSession = 0
local previewAngle = 0
local activePreviews = {}

local detachedWindows = {}
local windowTopZ = 40
local isTearingOff = false
local tabMouseDownPos = nil
local tabMouseDownName = nil

local function playSound(name)
	local box = sg:FindFirstChild("Sounds")
	local snd = box and box:FindFirstChild(name, true)
	if snd and snd:IsA("Sound") then
		snd:Play()
	end
end

local function addButtonSound(btn)
	if not btn or btn:GetAttribute("SoundHooked") then return end
	btn:SetAttribute("SoundHooked", true)
	btn.MouseEnter:Connect(function() playSound("UI_Hover") end)
	btn.MouseButton1Click:Connect(function() playSound("UI_Click") end)
end

local function cleanText(obj)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		obj.TextStrokeTransparency = 1
		obj.TextStrokeColor3 = Color3.new(0, 0, 0)
	end
end

local function conn(c)
	if #connections >= 128 then
		local active = {}
		for _, item in ipairs(connections) do
			if item.Connected then
				table.insert(active, item)
			end
		end
		connections = active
	end
	table.insert(connections, c)
	return c
end

local function tw(inst, props, dur, sty, dir)
	local i = TweenInfo.new(dur or 0.22, sty or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local t = TweenService:Create(inst, i, props)
	t:Play()
	return t
end

local function mkC(p, r)
	return nil
end

local function mkS(p, col, th, tr)
	local s = Instance.new("UIStroke")
	s.Color = col or BORDER
	s.Thickness = th or 1
	s.Transparency = tr or 0
	s.Parent = p
	return s
end

local function mkP(p, t, r, b, l)
	local pd = Instance.new("UIPadding")
	pd.PaddingTop = UDim.new(0, t or 6)
	pd.PaddingRight = UDim.new(0, r or 6)
	pd.PaddingBottom = UDim.new(0, b or 6)
	pd.PaddingLeft = UDim.new(0, l or 6)
	pd.Parent = p
	return pd
end

local function mkL(p, txt, sz, col, xa, isBold)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = txt or ""
	l.Font = isBold and FONT_BOLD or FONT
	l.TextSize = sz or 11
	l.TextColor3 = col or TEXT_PRIMARY
	l.TextStrokeTransparency = 1
	l.TextXAlignment = xa or Enum.TextXAlignment.Left
	l.Parent = p
	return l
end

local function mkB(p, txt, sz, pos, bgCol, strokeCol)
	local b = Instance.new("TextButton")
	b.Text = txt or ""
	b.Font = FONT_BOLD
	b.TextSize = 10
	b.TextColor3 = TEXT_PRIMARY
	b.BackgroundColor3 = bgCol or BG_CARD
	b.BorderSizePixel = 0
	b.Size = sz or UDim2.new(0, 100, 0, 26)
	if pos then b.Position = pos end
	b.AutoButtonColor = false
	b.TextStrokeTransparency = 1
	b.Parent = p
	if strokeCol then mkS(b, strokeCol, 1, 0) end
	addButtonSound(b)
	b.MouseEnter:Connect(function()
		tw(b, {BackgroundColor3 = BG_CARD_HOVER}, 0.15)
	end)
	b.MouseLeave:Connect(function()
		tw(b, {BackgroundColor3 = bgCol or BG_CARD}, 0.15)
	end)
	return b
end

conn(sg.DescendantAdded:Connect(function(obj)
	cleanText(obj)
	if obj:IsA("GuiButton") then addButtonSound(obj) end
end))
for _, obj in ipairs(sg:GetDescendants()) do
	cleanText(obj)
	if obj:IsA("GuiButton") then addButtonSound(obj) end
end

local function renderTargetMatrix(parentContainer, whitelist, onToggleCallback)
	for _, c in ipairs(parentContainer:GetChildren()) do
		if c:IsA("Frame") or c:IsA("TextLabel") or c:IsA("TextButton") then
			c:Destroy()
		end
	end

	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 28)
	topBar.BackgroundTransparency = 1
	topBar.LayoutOrder = 1
	topBar.Parent = parentContainer

	local authAllGlobalBtn = mkB(topBar, "ENGAGE ALL (Shoot)", UDim2.new(0.5, -4, 0, 24), UDim2.new(0, 0, 0, 2), SUCCESS_BG, SUCCESS_BORDER)
	authAllGlobalBtn.TextSize = 9
	authAllGlobalBtn.TextColor3 = SUCCESS

	local filtAllGlobalBtn = mkB(topBar, "IGNORE ALL (Safe)", UDim2.new(0.5, -4, 0, 24), UDim2.new(0.5, 4, 0, 2), ACCENT_BG, ACCENT_BORDER)
	filtAllGlobalBtn.TextSize = 9
	filtAllGlobalBtn.TextColor3 = ACCENT

	local itemRefs = {}

	local function isItemAllowed(name)
		for _, w in ipairs(whitelist) do
			if w == name then return true end
		end
		return false
	end

	local function setItemAllowed(name, allowed)
		local idx = table.find(whitelist, name)
		if allowed and not idx then
			table.insert(whitelist, name)
		elseif not allowed and idx then
			table.remove(whitelist, idx)
		end
		if onToggleCallback then onToggleCallback(whitelist) end
	end

	local layoutOrder = 2

	for _, cat in ipairs(TARGET_CATEGORIES) do
		local catBox = Instance.new("Frame")
		catBox.Name = "CatBox_" .. cat.id
		catBox.Size = UDim2.new(1, 0, 0, 34 + (#cat.items * 30))
		catBox.BackgroundColor3 = BG_CARD
		catBox.BorderSizePixel = 0
		catBox.LayoutOrder = layoutOrder
		catBox.Parent = parentContainer
		mkS(catBox, BORDER, 1, 0)
		layoutOrder = layoutOrder + 1

		local catHeader = Instance.new("Frame")
		catHeader.Size = UDim2.new(1, 0, 0, 28)
		catHeader.BackgroundColor3 = BG_PANEL
		catHeader.BorderSizePixel = 0
		catHeader.Parent = catBox
		mkS(catHeader, BORDER, 1, 0)

		local catTitle = mkL(catHeader, cat.category .. " (" .. tostring(#cat.items) .. ")", 10, Color3.fromRGB(210, 215, 220), Enum.TextXAlignment.Left, false)
		catTitle.Size = UDim2.new(0.55, 0, 1, 0)
		catTitle.Position = UDim2.new(0, 8, 0, 0)

		local catAuth = mkB(catHeader, "ENGAGE ALL", UDim2.new(0, 75, 0, 20), UDim2.new(1, -165, 0.5, -10), SUCCESS_BG, SUCCESS_BORDER)
		catAuth.TextSize = 8
		catAuth.TextColor3 = SUCCESS

		local catFilt = mkB(catHeader, "IGNORE ALL", UDim2.new(0, 75, 0, 20), UDim2.new(1, -82, 0.5, -10), ACCENT_BG, ACCENT_BORDER)
		catFilt.TextSize = 8
		catFilt.TextColor3 = ACCENT

		conn(catAuth.MouseButton1Click:Connect(function()
			for _, item in ipairs(cat.items) do
				if not table.find(whitelist, item) then table.insert(whitelist, item) end
				local refs = itemRefs[item]
				if refs then
					refs.dot.BackgroundColor3 = SUCCESS
					refs.btn.Text = "ENGAGE (Shoot)"
					refs.btn.BackgroundColor3 = SUCCESS_BG
					refs.btn.TextColor3 = SUCCESS
					local st = refs.btn:FindFirstChildWhichIsA("UIStroke")
					if st then st.Color = SUCCESS_BORDER end
				end
			end
			if not table.find(whitelist, cat.categoryTag) then table.insert(whitelist, cat.categoryTag) end
			if onToggleCallback then onToggleCallback(whitelist) end
		end))

		conn(catFilt.MouseButton1Click:Connect(function()
			for _, item in ipairs(cat.items) do
				local idx = table.find(whitelist, item)
				if idx then table.remove(whitelist, idx) end
				local refs = itemRefs[item]
				if refs then
					refs.dot.BackgroundColor3 = TEXT_DIM
					refs.btn.Text = "IGNORE (Safe)"
					refs.btn.BackgroundColor3 = BG_PANEL
					refs.btn.TextColor3 = TEXT_SECONDARY
					local st = refs.btn:FindFirstChildWhichIsA("UIStroke")
					if st then st.Color = BORDER end
				end
			end
			if onToggleCallback then onToggleCallback(whitelist) end
		end))

		local itemContainer = Instance.new("Frame")
		itemContainer.Size = UDim2.new(1, -12, 0, #cat.items * 30)
		itemContainer.Position = UDim2.new(0, 6, 0, 32)
		itemContainer.BackgroundTransparency = 1
		itemContainer.Parent = catBox

		local itLy = Instance.new("UIListLayout")
		itLy.SortOrder = Enum.SortOrder.LayoutOrder
		itLy.Padding = UDim.new(0, 2)
		itLy.Parent = itemContainer

		for idx, item in ipairs(cat.items) do
			local allowed = isItemAllowed(item)

			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 28)
			row.BackgroundColor3 = BG_PANEL
			row.BorderSizePixel = 0
			row.LayoutOrder = idx
			row.Parent = itemContainer
			mkS(row, BORDER, 1, 0)

			local dot = Instance.new("Frame")
			dot.Size = UDim2.new(0, 6, 0, 6)
			dot.Position = UDim2.new(0, 8, 0.5, -3)
			dot.BackgroundColor3 = allowed and SUCCESS or TEXT_DIM
			dot.BorderSizePixel = 0
			dot.Parent = row

			local nLbl = mkL(row, item, 9, TEXT_PRIMARY, Enum.TextXAlignment.Left, false)
			nLbl.Size = UDim2.new(0.65, 0, 1, 0)
			nLbl.Position = UDim2.new(0, 20, 0, 0)
			nLbl.TextTruncate = Enum.TextTruncate.AtEnd

			local toggleBtn = mkB(row, allowed and "ENGAGE (Shoot)" or "IGNORE (Safe)", UDim2.new(0, 95, 0, 20), UDim2.new(1, -100, 0.5, -10), allowed and SUCCESS_BG or BG_CARD, allowed and SUCCESS_BORDER or BORDER)
			toggleBtn.TextSize = 8
			toggleBtn.TextColor3 = allowed and SUCCESS or TEXT_SECONDARY

			itemRefs[item] = {dot = dot, btn = toggleBtn}

			conn(toggleBtn.MouseButton1Click:Connect(function()
				local nextAllowed = not isItemAllowed(item)
				setItemAllowed(item, nextAllowed)
				toggleBtn.Text = nextAllowed and "ENGAGE (Shoot)" or "IGNORE (Safe)"
				toggleBtn.BackgroundColor3 = nextAllowed and SUCCESS_BG or BG_CARD
				toggleBtn.TextColor3 = nextAllowed and SUCCESS or TEXT_SECONDARY
				local st = toggleBtn:FindFirstChildWhichIsA("UIStroke")
				if st then st.Color = nextAllowed and SUCCESS_BORDER or BORDER end
				dot.BackgroundColor3 = nextAllowed and SUCCESS or TEXT_DIM
			end))
		end
	end

	local uncategorizedList = getUncategorizedDetectedTargets()
	local uncatBox = Instance.new("Frame")
	uncatBox.Name = "CatBox_UNCATEGORIZED"
	local uncatCount = math.max(1, #uncategorizedList)
	uncatBox.Size = UDim2.new(1, 0, 0, 34 + (uncatCount * 30))
	uncatBox.BackgroundColor3 = BG_CARD
	uncatBox.BorderSizePixel = 0
	uncatBox.LayoutOrder = layoutOrder
	uncatBox.Parent = parentContainer
	mkS(uncatBox, BORDER, 1, 0)
	layoutOrder = layoutOrder + 1

	local uncatHeader = Instance.new("Frame")
	uncatHeader.Size = UDim2.new(1, 0, 0, 28)
	uncatHeader.BackgroundColor3 = BG_PANEL
	uncatHeader.BorderSizePixel = 0
	uncatHeader.Parent = uncatBox
	mkS(uncatHeader, BORDER, 1, 0)

	local uncatTitle = mkL(uncatHeader, "UNCATEGORIZED DETECTED TARGETS (" .. tostring(#uncategorizedList) .. ")", 10, Color3.fromRGB(210, 215, 220), Enum.TextXAlignment.Left, false)
	uncatTitle.Size = UDim2.new(0.55, 0, 1, 0)
	uncatTitle.Position = UDim2.new(0, 8, 0, 0)

	local uncatAuth = mkB(uncatHeader, "ENGAGE ALL", UDim2.new(0, 75, 0, 20), UDim2.new(1, -165, 0.5, -10), SUCCESS_BG, SUCCESS_BORDER)
	uncatAuth.TextSize = 8
	uncatAuth.TextColor3 = SUCCESS

	local uncatFilt = mkB(uncatHeader, "IGNORE ALL", UDim2.new(0, 75, 0, 20), UDim2.new(1, -82, 0.5, -10), ACCENT_BG, ACCENT_BORDER)
	uncatFilt.TextSize = 8
	uncatFilt.TextColor3 = ACCENT

	conn(uncatAuth.MouseButton1Click:Connect(function()
		for _, itm in ipairs(uncategorizedList) do
			if not table.find(whitelist, itm.cleanName) then table.insert(whitelist, itm.cleanName) end
			local refs = itemRefs[itm.cleanName]
			if refs then
				refs.dot.BackgroundColor3 = SUCCESS
				refs.btn.Text = "ENGAGE (Shoot)"
				refs.btn.BackgroundColor3 = SUCCESS_BG
				refs.btn.TextColor3 = SUCCESS
				local st = refs.btn:FindFirstChildWhichIsA("UIStroke")
				if st then st.Color = SUCCESS_BORDER end
			end
		end
		if not table.find(whitelist, "UNCATEGORIZED") then table.insert(whitelist, "UNCATEGORIZED") end
		if onToggleCallback then onToggleCallback(whitelist) end
	end))

	conn(uncatFilt.MouseButton1Click:Connect(function()
		for _, itm in ipairs(uncategorizedList) do
			local idx = table.find(whitelist, itm.cleanName)
			if idx then table.remove(whitelist, idx) end
			local refs = itemRefs[itm.cleanName]
			if refs then
				refs.dot.BackgroundColor3 = TEXT_DIM
				refs.btn.Text = "IGNORE (Safe)"
				refs.btn.BackgroundColor3 = BG_PANEL
				refs.btn.TextColor3 = TEXT_SECONDARY
				local st = refs.btn:FindFirstChildWhichIsA("UIStroke")
				if st then st.Color = BORDER end
			end
		end
		local uIdx = table.find(whitelist, "UNCATEGORIZED")
		if uIdx then table.remove(whitelist, uIdx) end
		if onToggleCallback then onToggleCallback(whitelist) end
	end))

	local uncatContainer = Instance.new("Frame")
	uncatContainer.Size = UDim2.new(1, -12, 0, uncatCount * 30)
	uncatContainer.Position = UDim2.new(0, 6, 0, 32)
	uncatContainer.BackgroundTransparency = 1
	uncatContainer.Parent = uncatBox

	local uncatLy = Instance.new("UIListLayout")
	uncatLy.SortOrder = Enum.SortOrder.LayoutOrder
	uncatLy.Padding = UDim.new(0, 2)
	uncatLy.Parent = uncatContainer

	if #uncategorizedList == 0 then
		local emptyRow = Instance.new("Frame")
		emptyRow.Size = UDim2.new(1, 0, 0, 28)
		emptyRow.BackgroundColor3 = BG_PANEL
		emptyRow.BorderSizePixel = 0
		emptyRow.Parent = uncatContainer
		mkS(emptyRow, BORDER, 1, 0)
		local emptyLbl = mkL(emptyRow, "NO UNLISTED VEHICLES DETECTED IN AIRSPACE", 9, TEXT_DIM, Enum.TextXAlignment.Center, false)
		emptyLbl.Size = UDim2.new(1, 0, 1, 0)
	else
		for uIdx, itm in ipairs(uncategorizedList) do
			local allowed = isItemAllowed(itm.cleanName)
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 28)
			row.BackgroundColor3 = BG_PANEL
			row.BorderSizePixel = 0
			row.LayoutOrder = uIdx
			row.Parent = uncatContainer
			mkS(row, BORDER, 1, 0)

			local dot = Instance.new("Frame")
			dot.Size = UDim2.new(0, 6, 0, 6)
			dot.Position = UDim2.new(0, 8, 0.5, -3)
			dot.BackgroundColor3 = allowed and SUCCESS or TEXT_DIM
			dot.BorderSizePixel = 0
			dot.Parent = row

			local nLbl = mkL(row, itm.cleanName, 9, TEXT_PRIMARY, Enum.TextXAlignment.Left, false)
			nLbl.Size = UDim2.new(0.65, 0, 1, 0)
			nLbl.Position = UDim2.new(0, 20, 0, 0)
			nLbl.TextTruncate = Enum.TextTruncate.AtEnd

			local toggleBtn = mkB(row, allowed and "ENGAGE (Shoot)" or "IGNORE (Safe)", UDim2.new(0, 95, 0, 20), UDim2.new(1, -100, 0.5, -10), allowed and SUCCESS_BG or BG_CARD, allowed and SUCCESS_BORDER or BORDER)
			toggleBtn.TextSize = 8
			toggleBtn.TextColor3 = allowed and SUCCESS or TEXT_SECONDARY

			itemRefs[itm.cleanName] = {dot = dot, btn = toggleBtn}

			conn(toggleBtn.MouseButton1Click:Connect(function()
				local nextAllowed = not isItemAllowed(itm.cleanName)
				setItemAllowed(itm.cleanName, nextAllowed)
				toggleBtn.Text = nextAllowed and "ENGAGE (Shoot)" or "IGNORE (Safe)"
				toggleBtn.BackgroundColor3 = nextAllowed and SUCCESS_BG or BG_CARD
				toggleBtn.TextColor3 = nextAllowed and SUCCESS or TEXT_SECONDARY
				local st = toggleBtn:FindFirstChildWhichIsA("UIStroke")
				if st then st.Color = nextAllowed and SUCCESS_BORDER or BORDER end
				dot.BackgroundColor3 = nextAllowed and SUCCESS or TEXT_DIM
			end))
		end
	end

	conn(authAllGlobalBtn.MouseButton1Click:Connect(function()
		table.clear(whitelist)
		for _, cat in ipairs(TARGET_CATEGORIES) do
			for _, item in ipairs(cat.items) do
				table.insert(whitelist, item)
			end
			table.insert(whitelist, cat.categoryTag)
		end
		for item, refs in pairs(itemRefs) do
			refs.dot.BackgroundColor3 = SUCCESS
			refs.btn.Text = "ENGAGE (Shoot)"
			refs.btn.BackgroundColor3 = SUCCESS_BG
			refs.btn.TextColor3 = SUCCESS
			local st = refs.btn:FindFirstChildWhichIsA("UIStroke")
			if st then st.Color = SUCCESS_BORDER end
		end
		if onToggleCallback then onToggleCallback(whitelist) end
	end))

	conn(filtAllGlobalBtn.MouseButton1Click:Connect(function()
		table.clear(whitelist)
		for item, refs in pairs(itemRefs) do
			refs.dot.BackgroundColor3 = TEXT_DIM
			refs.btn.Text = "IGNORE (Safe)"
			refs.btn.BackgroundColor3 = BG_CARD
			refs.btn.TextColor3 = TEXT_SECONDARY
			local st = refs.btn:FindFirstChildWhichIsA("UIStroke")
			if st then st.Color = BORDER end
		end
		if onToggleCallback then onToggleCallback(whitelist) end
	end))

	local totalH = 36
	for _, cat in ipairs(TARGET_CATEGORIES) do
		totalH = totalH + 38 + (#cat.items * 30)
	end
	local uncatH = 34 + (math.max(1, #uncategorizedList) * 30) + 6
	totalH = totalH + uncatH
	parentContainer.Size = UDim2.new(1, 0, 0, totalH)
	return totalH
end

local function getTool()
	local char = player.Character
	if char then
		local t = char:FindFirstChild(TOOL_NAME)
		if t then return t end
	end
	return player.Backpack:FindFirstChild(TOOL_NAME)
end

local function getRemote()
	local tool = getTool()
	if tool then
		return tool:FindFirstChild("MasterRemote")
	end
	return nil
end

local function sendServer(action, data)
	local remote = getRemote()
	if remote then
		remote:FireServer(action, data)
	end
end

local function getTemplatesFolder()
	local rep = ReplicatedStorage:FindFirstChild("CIWSTemplates")
	if rep then return rep end
	return nil
end

local function isCursorOverTabBar(cursorPos)
	local absPos = tb.AbsolutePosition
	local absSize = tb.AbsoluteSize
	local minX = absPos.X
	local maxX = absPos.X + absSize.X
	local minY = absPos.Y - 10
	local maxY = absPos.Y + absSize.Y + 20
	return cursorPos.X >= minX and cursorPos.X <= maxX and cursorPos.Y >= minY and cursorPos.Y <= maxY
end

local dropIndicator = tb:FindFirstChild("DropIndicator")
if not dropIndicator then
	dropIndicator = Instance.new("Frame")
	dropIndicator.Name = "DropIndicator"
	dropIndicator.Size = UDim2.new(1, 0, 1, 0)
	dropIndicator.Position = UDim2.new(0, 0, 0, 0)
	dropIndicator.BackgroundColor3 = Color3.fromRGB(20, 50, 70)
	dropIndicator.BackgroundTransparency = 0.5
	dropIndicator.BorderSizePixel = 0
	dropIndicator.Visible = false
	dropIndicator.ZIndex = tb.ZIndex + 10
	dropIndicator.Parent = tb
	mkC(dropIndicator, 4)
	mkS(dropIndicator, CYAN, 2, 0.2)

	local dLbl = mkL(dropIndicator, "[ RELEASE TO DOCK TAB ]", 11, CYAN, Enum.TextXAlignment.Center)
	dLbl.Size = UDim2.new(1, 0, 1, 0)
	dLbl.Position = UDim2.new(0, 0, 0, 0)
end

local function makeWindowDraggable(win, dragBar, onDragCallback, onReleaseCallback)
	local dragging = false
	local dragStart = nil
	local startPos = nil

	dragBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			windowTopZ = windowTopZ + 1
			win.ZIndex = windowTopZ
			for _, d in ipairs(win:GetDescendants()) do
				if d:IsA("GuiObject") then
					d.ZIndex = win.ZIndex + (d:GetAttribute("RelZ") or 1)
				end
			end
			dragging = true
			dragStart = input.Position
			startPos = win.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			win.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
			if onDragCallback then
				onDragCallback(input.Position)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				if onReleaseCallback then
					onReleaseCallback(input.Position)
				end
			end
		end
	end)
end

local function clampMainFramePosition()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local targetW = math.clamp(1040, 680, math.max(680, vp.X - 32))
	local targetH = math.clamp(720, 480, math.max(480, vp.Y - 48))
	mf.Size = UDim2.new(0, targetW, 0, targetH)
	local posX = math.floor((vp.X - targetW) * 0.5)
	local posY = math.clamp(math.floor((vp.Y - targetH) * 0.5), 18, math.max(18, vp.Y - targetH - 12))
	mf.AnchorPoint = Vector2.new(0, 0)
	mf.Position = UDim2.new(0, posX, 0, posY)
end

clampMainFramePosition()

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		clampMainFramePosition()
	end)
end

local mainDragHandle = hb:FindFirstChild("DragHandle")
if not mainDragHandle then
	mainDragHandle = Instance.new("Frame")
	mainDragHandle.Name = "DragHandle"
	mainDragHandle.Size = UDim2.new(1, -44, 1, 0)
	mainDragHandle.Position = UDim2.new(0, 0, 0, 0)
	mainDragHandle.BackgroundTransparency = 1
	mainDragHandle.ZIndex = hb.ZIndex + 1
	mainDragHandle.Parent = hb
end
makeWindowDraggable(mf, mainDragHandle)

local switchTab = nil
local dockTab = nil
local detachTab = nil

switchTab = function(name)
	if detachedWindows[name] then
		local win = detachedWindows[name]
		windowTopZ = windowTopZ + 1
		win.ZIndex = windowTopZ
		win.Visible = true
		tw(win, {Size = tabDefaultSizes[name]}, 0.15)
		return
	end

	playSound("UI_SlideIn")
	currentTab = name
	for tabName, tabFrame in pairs(tabsMap) do
		if not detachedWindows[tabName] then
			tabFrame.Visible = (tabName == name)
			local tabBtn = tb:FindFirstChild("TabBtn_" .. tabName)
			if tabBtn then
				local ul = tabBtn:FindFirstChild("Underline")
				local tl = tabBtn:FindFirstChild("TitleLabel")
				local dot = tabBtn:FindFirstChild("TabDot")
				if tabName == name then
					tabBtn.BackgroundColor3 = BG_PANEL
					tabBtn.TextColor3 = TEXT_PRIMARY
					if tl then tl.TextColor3 = TEXT_PRIMARY end
					if ul then
						ul.Visible = true
						ul.BackgroundColor3 = CYAN
					end
					if dot then dot.BackgroundColor3 = CYAN end
				else
					tabBtn.BackgroundColor3 = BG_DARK
					tabBtn.TextColor3 = TEXT_SECONDARY
					if tl then tl.TextColor3 = TEXT_SECONDARY end
					if ul then ul.Visible = false end
					if dot then dot.BackgroundColor3 = TEXT_DIM end
				end
			end
		end
	end
end

dockTab = function(tabName)
	dropIndicator.Visible = false
	local win = detachedWindows[tabName]
	if not win then return end

	local tabFrame = tabsMap[tabName]
	if tabFrame then
		tabFrame.Parent = ca
		tabFrame.Size = UDim2.new(1, 0, 1, 0)
		tabFrame.Position = UDim2.new(0, 0, 0, 0)
		tabFrame.Visible = true
	end

	win:Destroy()
	detachedWindows[tabName] = nil

	local tabBtn = tb:FindFirstChild("TabBtn_" .. tabName)
	if tabBtn then
		tabBtn.Text = tabName
		local dot = tabBtn:FindFirstChild("TabDot")
		if dot then dot.BackgroundColor3 = (currentTab == tabName) and CYAN or TEXT_DIM end
	end

	switchTab(tabName)
end

detachTab = function(tabName, initialPos)
	dropIndicator.Visible = false
	if detachedWindows[tabName] then
		local win = detachedWindows[tabName]
		windowTopZ = windowTopZ + 1
		win.ZIndex = windowTopZ
		win.Visible = true
		tw(win, {Size = tabDefaultSizes[tabName]}, 0.15)
		return win
	end

	local tabFrame = tabsMap[tabName]
	if not tabFrame then return nil end

	windowTopZ = windowTopZ + 2
	local defSize = tabDefaultSizes[tabName] or UDim2.new(0, 720, 0, 640)

	local startPos = initialPos
	if not startPos then
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local posX = math.clamp(vp.X * 0.5 - defSize.X.Offset * 0.5 + 40, 20, vp.X - defSize.X.Offset - 20)
		local posY = math.clamp(vp.Y * 0.5 - defSize.Y.Offset * 0.5 + 40, 20, vp.Y - defSize.Y.Offset - 20)
		startPos = UDim2.new(0, posX, 0, posY)
	end

	local win = Instance.new("Frame")
	win.Name = "Detached_" .. tabName
	win.Size = defSize
	win.Position = startPos
	win.BackgroundColor3 = BG_PANEL
	win.BorderSizePixel = 0
	win.ZIndex = windowTopZ
	win.Parent = sg
	mkC(win, 4)
	mkS(win, BORDER, 1, 0.4)

	local wHb = Instance.new("Frame")
	wHb.Name = "HeaderBar"
	wHb.Size = UDim2.new(1, 0, 0, 38)
	wHb.BackgroundColor3 = BG_DARK
	wHb.BorderSizePixel = 0
	wHb.ZIndex = windowTopZ + 1
	wHb.Parent = win
	mkC(wHb, 4)

	local wPill = Instance.new("Frame")
	wPill.Name = "AccentPill"
	wPill.Size = UDim2.new(0, 3, 0, 20)
	wPill.Position = UDim2.new(0, 10, 0, 9)
	wPill.BackgroundColor3 = CYAN
	wPill.BorderSizePixel = 0
	wPill.ZIndex = windowTopZ + 2
	wPill.Parent = wHb
	mkC(wPill, 1)

	local wTitle = mkL(wHb, "C2 MONITOR • " .. tabName, 11, TEXT_PRIMARY)
	wTitle.Size = UDim2.new(1, -200, 0, 22)
	wTitle.Position = UDim2.new(0, 22, 0, 8)
	wTitle.ZIndex = windowTopZ + 2

	local dragHandle = Instance.new("Frame")
	dragHandle.Name = "DragHandle"
	dragHandle.Size = UDim2.new(1, -190, 1, 0)
	dragHandle.Position = UDim2.new(0, 0, 0, 0)
	dragHandle.BackgroundTransparency = 1
	dragHandle.ZIndex = windowTopZ + 3
	dragHandle.Parent = wHb

	local wControls = Instance.new("Frame")
	wControls.Name = "WindowControls"
	wControls.Size = UDim2.new(0, 175, 0, 28)
	wControls.Position = UDim2.new(1, -180, 0, 5)
	wControls.BackgroundTransparency = 1
	wControls.ZIndex = windowTopZ + 4
	wControls.Parent = wHb

	local isMin = false
	local minBtn = mkB(wControls, "[_]", UDim2.new(0, 28, 0, 26), UDim2.new(0, 0, 0, 1), BG_INPUT, BORDER)
	minBtn.TextSize = 10
	minBtn.ZIndex = windowTopZ + 5

	local dockBtn = mkB(wControls, "[DOCK]", UDim2.new(0, 80, 0, 26), UDim2.new(0, 34, 0, 1), Color3.fromRGB(25, 48, 65), CYAN)
	dockBtn.TextSize = 10
	dockBtn.TextColor3 = CYAN
	dockBtn.ZIndex = windowTopZ + 5

	local closeBtn = mkB(wControls, "[X]", UDim2.new(0, 28, 0, 26), UDim2.new(0, 120, 0, 1), Color3.fromRGB(55, 25, 25), ACCENT)
	closeBtn.TextSize = 10
	closeBtn.ZIndex = windowTopZ + 5

	local bodyContainer = Instance.new("Frame")
	bodyContainer.Name = "BodyContainer"
	bodyContainer.Size = UDim2.new(1, 0, 1, -38)
	bodyContainer.Position = UDim2.new(0, 0, 0, 38)
	bodyContainer.BackgroundTransparency = 1
	bodyContainer.ClipsDescendants = true
	bodyContainer.ZIndex = windowTopZ + 1
	bodyContainer.Parent = win

	tabFrame.Parent = bodyContainer
	tabFrame.Size = UDim2.new(1, 0, 1, 0)
	tabFrame.Position = UDim2.new(0, 0, 0, 0)
	tabFrame.Visible = true

	minBtn.MouseButton1Click:Connect(function()
		isMin = not isMin
		if isMin then
			tw(win, {Size = UDim2.new(defSize.X.Scale, defSize.X.Offset, 0, 38)}, 0.2)
			bodyContainer.Visible = false
			minBtn.Text = "[+]"
		else
			bodyContainer.Visible = true
			tw(win, {Size = defSize}, 0.2)
			minBtn.Text = "[_]"
		end
	end)

	dockBtn.MouseButton1Click:Connect(function()
		dockTab(tabName)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		dockTab(tabName)
	end)

	local function onFloatingDrag(pos)
		if mf.Visible and isCursorOverTabBar(pos) then
			dropIndicator.Visible = true
		else
			dropIndicator.Visible = false
		end
	end

	local function onFloatingRelease(pos)
		if mf.Visible and isCursorOverTabBar(pos) then
			dockTab(tabName)
		else
			dropIndicator.Visible = false
		end
	end

	makeWindowDraggable(win, dragHandle, onFloatingDrag, onFloatingRelease)

	detachedWindows[tabName] = win

	local tabBtn = tb:FindFirstChild("TabBtn_" .. tabName)
	if tabBtn then
		tabBtn.Text = tabName .. " [FLOAT]"
		local dot = tabBtn:FindFirstChild("TabDot")
		if dot then dot.BackgroundColor3 = WARNING end
	end

	if currentTab == tabName then
		for _, otherName in ipairs({"TARGETS", "DEPLOY", "FLEET", "GLOBAL", "LIVE", "TRACE"}) do
			if otherName ~= tabName and not detachedWindows[otherName] then
				switchTab(otherName)
				break
			end
		end
	end

	return win
end

local function renderLiveTargets()
	local scroll = liveTab:FindFirstChild("LiveScroll")
	if not scroll then return end
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local refresh = mkB(scroll, "REFRESH LIVE INVENTORY", UDim2.new(0.62, -6, 0, 30), UDim2.new(0, 0, 0, 0), BG_INPUT, BORDER)
	refresh.LayoutOrder = 1
	refresh.TextColor3 = TEXT_SECONDARY
	refresh.MouseButton1Click:Connect(function() sendServer("RequestFullState") end)
	local debugButton = mkB(scroll, cachedState and cachedState.debug and "DEBUG TRACE: ON" or "DEBUG TRACE: OFF", UDim2.new(0.38, -6, 0, 30), UDim2.new(0.62, 6, 0, 0), BG_INPUT, BORDER)
	debugButton.LayoutOrder = 1
	debugButton.TextColor3 = TEXT_SECONDARY
	debugButton.MouseButton1Click:Connect(function()
		sendServer("SetDebug", not (cachedState and cachedState.debug == true))
	end)
	local detected = cachedState and cachedState.targets and cachedState.targets.detected or {}
	local count = 0
	for _, item in ipairs(detected) do
		count = count + 1
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 38)
		row.BackgroundColor3 = BG_CARD
		row.BorderSizePixel = 0
		row.LayoutOrder = count + 1
		row.Parent = scroll
		mkS(row, BORDER, 1, 0)
		local nameLabel = mkL(row, tostring(item.name or "Unknown"), 10, TEXT_PRIMARY)
		nameLabel.Size = UDim2.new(0.52, 0, 1, 0)
		nameLabel.Position = UDim2.new(0, 10, 0, 0)
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		local typeLabel = mkL(row, tostring(item.type or "TARGET CRAFT"), 9, CYAN)
		typeLabel.Size = UDim2.new(0.25, 0, 1, 0)
		typeLabel.Position = UDim2.new(0.53, 0, 0, 0)
		local stateLabel = mkL(row, item.isPerm and "TAGGED" or "READY", 9, item.isPerm and AMBER or SUCCESS, Enum.TextXAlignment.Right)
		stateLabel.Size = UDim2.new(0.2, 0, 1, 0)
		stateLabel.Position = UDim2.new(0.78, 0, 0, 0)
	end
	if count == 0 then
		local empty = mkL(scroll, "NO TARGETABLE VEHICLES DETECTED", 11, TEXT_DIM, Enum.TextXAlignment.Center)
		empty.Size = UDim2.new(1, -12, 0, 40)
		empty.LayoutOrder = 2
	end
	local header = liveTab:FindFirstChild("LiveHeader")
	if header then header.Text = "LIVE TARGET INVENTORY  •  "..tostring(count).." VEHICLES" end
end

local function renderTrace()
	local box = traceTab:FindFirstChild("TraceBox")
	if not box then return end
	box.TextEditable = false
	box.ShowNativeInput = false
	box.Active = true
	box.Selectable = true
	box.MultiLine = true
	box.TextWrapped = true
	local store = ReplicatedStorage:FindFirstChild("CRAM_TRACE_LOG")
	local log = store and store:IsA("StringValue") and store.Value or ""
	box.Text = log ~= "" and log or "TRACE IDLE\nEnable debug and run a target test."
	local head = traceTab:FindFirstChild("TraceHeader")
	if head then
		local enabled = cachedState and cachedState.debug == true
		head.Text = "C-RAM TRACE CONSOLE  •  "..(enabled and "ENABLED" or "DISABLED")
	end
end

local tabOrder = {}
local tabButtons = {}
local tabDragChip = nil
local tabDragMode = nil
local tabDragStartPos = nil
local tabDragName = nil

local function relayoutTabs()
	local count = #tabOrder
	local totalW = tb.AbsoluteSize.X > 0 and tb.AbsoluteSize.X or 736
	local tabW = math.max(120, math.floor((totalW - (count - 1) * 6) / count))
	for idx, name in ipairs(tabOrder) do
		local btn = tabButtons[name]
		if btn then
			btn.LayoutOrder = idx
			btn.Size = UDim2.new(0, tabW, 1, 0)
		end
	end
end

local tbLayout = tb:FindFirstChildWhichIsA("UIListLayout")
if not tbLayout then
	tbLayout = Instance.new("UIListLayout")
	tbLayout.FillDirection = Enum.FillDirection.Horizontal
	tbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	tbLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tbLayout.Padding = UDim.new(0, 6)
	tbLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tbLayout.Parent = tb
else
	tbLayout.Padding = UDim.new(0, 6)
	tbLayout.SortOrder = Enum.SortOrder.LayoutOrder
end

local function createDragChip(name, initPos)
	if tabDragChip then
		tabDragChip:Destroy()
		tabDragChip = nil
	end
	tabDragChip = Instance.new("Frame")
	tabDragChip.Name = "TabDragChip"
	tabDragChip.Size = UDim2.new(0, 180, 0, 40)
	tabDragChip.Position = UDim2.new(0, initPos.X - 90, 0, initPos.Y - 20)
	tabDragChip.BackgroundColor3 = BG_CARD
	tabDragChip.BorderSizePixel = 0
	tabDragChip.ZIndex = 9999
	tabDragChip.Parent = sg
	mkC(tabDragChip, 6)
	mkS(tabDragChip, CYAN, 2, 0.2)

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 8, 0, 8)
	dot.Position = UDim2.new(0, 12, 0.5, -4)
	dot.BackgroundColor3 = CYAN
	dot.BorderSizePixel = 0
	dot.ZIndex = 10000
	dot.Parent = tabDragChip
	mkC(dot, 4)

	local tl = mkL(tabDragChip, name, 11, TEXT_PRIMARY, Enum.TextXAlignment.Center)
	tl.Size = UDim2.new(1, -30, 1, 0)
	tl.Position = UDim2.new(0, 20, 0, 0)
	tl.ZIndex = 10000

	tw(tabDragChip, {Size = UDim2.new(0, 192, 0, 44)}, 0.15)
end

local buildTabButton = nil
local tabService = {}

function tabService.registerTab(name, tabFrame, tabSize)
	if not name or not tabFrame then return nil end
	tabsMap[name] = tabFrame
	tabDefaultSizes[name] = tabSize or tabDefaultSizes[name] or UDim2.new(0, 1040, 0, 720)
	if not table.find(tabOrder, name) then
		table.insert(tabOrder, name)
	end
	if buildTabButton then
		buildTabButton(name)
		relayoutTabs()
	end
	return tabButtons[name]
end

function tabService.openTab(name)
	if tabsMap[name] then switchTab(name) end
end

function tabService.removeTab(name)
	local idx = table.find(tabOrder, name)
	if idx then table.remove(tabOrder, idx) end
	local button = tabButtons[name]
	if button then button:Destroy() end
	tabButtons[name] = nil
	tabsMap[name] = nil
	tabDefaultSizes[name] = nil
	relayoutTabs()
end

buildTabButton = function(tabName)
	local tabBtn = tb:FindFirstChild("TabBtn_" .. tabName)
	if not tabBtn then
		tabBtn = Instance.new("TextButton")
		tabBtn.Name = "TabBtn_" .. tabName
		tabBtn.Parent = tb
	end
	tabBtn.Text = tabName
	tabBtn.Font = FONT
	tabBtn.TextSize = 11
	tabBtn.TextColor3 = (currentTab == tabName) and TEXT_PRIMARY or TEXT_SECONDARY
	tabBtn.AutoButtonColor = false
	tabBtn.BorderSizePixel = 0
	tabBtn.BackgroundColor3 = BG_DARK
	tabBtn.Size = UDim2.new(0, 120, 1, 0)
	mkC(tabBtn, 4)
	if not tabBtn:FindFirstChildWhichIsA("UIStroke") then
		mkS(tabBtn, BORDER, 1, 0.4)
	end

	local dot = tabBtn:FindFirstChild("TabDot")
	if not dot then
		dot = Instance.new("Frame")
		dot.Name = "TabDot"
		dot.Size = UDim2.new(0, 6, 0, 6)
		dot.Position = UDim2.new(0, 14, 0.5, -3)
		dot.BackgroundColor3 = TEXT_DIM
		dot.BorderSizePixel = 0
		dot.Parent = tabBtn
		mkC(dot, 3)
	end

	local ul = tabBtn:FindFirstChild("Underline")
	if not ul then
		ul = Instance.new("Frame")
		ul.Name = "Underline"
		ul.Size = UDim2.new(1, 0, 0, 2)
		ul.Position = UDim2.new(0, 0, 1, -2)
		ul.BackgroundColor3 = CYAN
		ul.BorderSizePixel = 0
		ul.Visible = false
		ul.Parent = tabBtn
	end

	tabButtons[tabName] = tabBtn
	if not tabBtn:GetAttribute("TabBound") then
		tabBtn:SetAttribute("TabBound", true)
		conn(tabBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				tabDragName = tabName
				tabDragStartPos = input.Position
				tabDragMode = nil
			end
		end))
		conn(tabBtn.MouseButton1Click:Connect(function()
			if not isTearingOff and tabDragMode == nil then
				if detachedWindows[tabName] then
					local win = detachedWindows[tabName]
					windowTopZ = windowTopZ + 1
					win.ZIndex = windowTopZ
					win.Visible = true
				else
					switchTab(tabName)
				end
			end
		end))
	end
	return tabBtn
end

tabService.registerTab("TARGETS", targetsTab)
tabService.registerTab("DEPLOY", deployTab)
tabService.registerTab("FLEET", fleetTab)
tabService.registerTab("GLOBAL", globalTab)
tabService.registerTab("LIVE", liveTab)
tabService.registerTab("TRACE", traceTab)

relayoutTabs()
renderLiveTargets()

conn(tb:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	relayoutTabs()
end))

conn(UserInputService.InputChanged:Connect(function(input)
	if tabDragName and input.UserInputType == Enum.UserInputType.MouseMovement then
		local deltaX = input.Position.X - tabDragStartPos.X
		local deltaY = input.Position.Y - tabDragStartPos.Y
		local dist = math.sqrt(deltaX * deltaX + deltaY * deltaY)

		if not tabDragMode and dist > 14 then
			if deltaY > 32 or not isCursorOverTabBar(input.Position) then
				tabDragMode = "TEAR_OFF"
				isTearingOff = true
				createDragChip(tabDragName, input.Position)
			else
				tabDragMode = "REORDER"
			end
		end

		if tabDragMode == "REORDER" then
			if deltaY > 36 or not isCursorOverTabBar(input.Position) then
				tabDragMode = "TEAR_OFF"
				isTearingOff = true
				createDragChip(tabDragName, input.Position)
			else
				local totalW = tb.AbsoluteSize.X > 0 and tb.AbsoluteSize.X or 736
				local count = #tabOrder
				local slotW = totalW / count
				local relX = input.Position.X - tb.AbsolutePosition.X
				local targetIdx = math.clamp(math.floor(relX / slotW) + 1, 1, count)

				local currentIdx = table.find(tabOrder, tabDragName)
				if currentIdx and currentIdx ~= targetIdx then
					table.remove(tabOrder, currentIdx)
					table.insert(tabOrder, targetIdx, tabDragName)
					relayoutTabs()
				end
			end
		elseif tabDragMode == "TEAR_OFF" then
			if tabDragChip then
				tabDragChip.Position = UDim2.new(0, input.Position.X - 96, 0, input.Position.Y - 22)
			end
			if mf.Visible and isCursorOverTabBar(input.Position) then
				dropIndicator.Visible = true
			else
				dropIndicator.Visible = false
			end
		end
	end
end))

conn(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local droppedName = tabDragName
		local finalMode = tabDragMode
		local dropPos = input.Position

		tabDragName = nil
		tabDragStartPos = nil
		tabDragMode = nil

		if tabDragChip then
			tabDragChip:Destroy()
			tabDragChip = nil
		end
		dropIndicator.Visible = false

		if finalMode == "TEAR_OFF" and droppedName then
			if mf.Visible and isCursorOverTabBar(dropPos) then
				dockTab(droppedName)
			else
				local win = detachTab(droppedName, UDim2.new(0, dropPos.X - 330, 0, dropPos.Y - 20))
				if win then
					win.Size = UDim2.new(0, 220, 0, 48)
					local defSize = tabDefaultSizes[droppedName] or UDim2.new(0, 680, 0, 500)
					tw(win, {Size = defSize}, 0.2)
				end
			end
		end

		task.delay(0.1, function()
			isTearingOff = false
		end)
	end
end))

local function createSlider(parent, labelText, minVal, maxVal, curVal, isFloat, onValChanged)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 46)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local lbl = mkL(row, labelText, 11, TEXT_SECONDARY)
	lbl.Size = UDim2.new(0.65, 0, 0, 16)
	lbl.Position = UDim2.new(0, 0, 0, 0)

	local formatStr = isFloat and "%.2f" or "%d"
	local valLbl = mkL(row, string.format(formatStr, curVal), 11, TEXT_PRIMARY, Enum.TextXAlignment.Right)
	valLbl.Size = UDim2.new(0.35, 0, 0, 16)
	valLbl.Position = UDim2.new(0.65, 0, 0, 0)

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 8)
	track.Position = UDim2.new(0, 0, 0, 26)
	track.BackgroundColor3 = BG_INPUT
	track.BorderSizePixel = 0
	track.Active = true
	track.Parent = row

	local tst = Instance.new("UIStroke")
	tst.Color = BORDER
	tst.Thickness = 1
	tst.Parent = track

	local pct = math.clamp((curVal - minVal) / (maxVal - minVal), 0, 1)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(pct, 0, 1, 0)
	fill.BackgroundColor3 = CYAN
	fill.BorderSizePixel = 0
	fill.Parent = track

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 10, 0, 18)
	knob.Position = UDim2.new(pct, -5, 0.5, -9)
	knob.BackgroundColor3 = TEXT_PRIMARY
	knob.BorderSizePixel = 0
	knob.ZIndex = track.ZIndex + 2
	knob.Parent = track

	local isDown = false
	local function updateFromInput(input)
		local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local raw = minVal + rel * (maxVal - minVal)
		local v = isFloat and math.floor(raw * 100 + 0.5) / 100 or math.floor(raw + 0.5)
		fill.Size = UDim2.new(rel, 0, 1, 0)
		knob.Position = UDim2.new(rel, -5, 0.5, -9)
		valLbl.Text = string.format(formatStr, v)
		onValChanged(v)
	end

	conn(track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDown = true
			updateFromInput(input)
		end
	end))

	conn(UserInputService.InputChanged:Connect(function(input)
		if isDown and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateFromInput(input)
		end
	end))

	conn(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDown = false
		end
	end))

	return {
		row = row,
		setValue = function(v)
			local p = math.clamp((v - minVal) / (maxVal - minVal), 0, 1)
			fill.Size = UDim2.new(p, 0, 1, 0)
			knob.Position = UDim2.new(p, -5, 0.5, -9)
			valLbl.Text = string.format(formatStr, v)
		end
	}
end

local function createToggle(parent, labelText, curVal, onToggled)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local lbl = mkL(row, labelText, 11, TEXT_SECONDARY)
	lbl.Size = UDim2.new(0.7, 0, 1, 0)
	lbl.Position = UDim2.new(0, 0, 0, 0)

	local btn = mkB(row, curVal and "[ACTIVE]" or "[STANDBY]", UDim2.new(0, 88, 0, 26), UDim2.new(1, -88, 0, 4), curVal and Color3.fromRGB(24, 48, 62) or BG_INPUT, curVal and CYAN or BORDER)
	btn.TextSize = 10

	local state = curVal
	conn(btn.MouseButton1Click:Connect(function()
		state = not state
		btn.Text = state and "[ACTIVE]" or "[STANDBY]"
		btn.BackgroundColor3 = state and Color3.fromRGB(24, 48, 62) or BG_INPUT
		onToggled(state)
	end))

	return {
		row = row,
		setState = function(s)
			state = s
			btn.Text = state and "[ACTIVE]" or "[STANDBY]"
			btn.BackgroundColor3 = state and Color3.fromRGB(24, 48, 62) or BG_INPUT
		end
	}
end

local function selectCIWSInFleet(model)
	if not model then return end
	switchTab("FLEET")
	if not cachedState or not cachedState.units then return end
	for id, u in pairs(cachedState.units) do
		if u.modelName == model.Name or (model.PrimaryPart and u.position and (Vector3.new(u.position.x, u.position.y, u.position.z) - model.PrimaryPart.Position).Magnitude < 5) then
			local card = fleetCards[id]
			if card then
				expandedUnits[id] = true
				local cfgPanel = card:FindFirstChild("ConfigPanel")
				local cfgBtn = card:FindFirstChild("CfgBtn")
				local cfgLy = cfgPanel and cfgPanel:FindFirstChildWhichIsA("UIListLayout")
				if cfgPanel and cfgBtn and cfgLy then
					cfgPanel.Visible = true
					local h = cfgLy.AbsoluteContentSize.Y + 24
					cfgPanel.Size = UDim2.new(1, -20, 0, h)
					card.Size = UDim2.new(1, -12, 0, 126 + h)
					cfgBtn.Text = "[-] FIRE CONTROL CONFIGURATION"
				end
				local fleetScroll = fleetTab:FindFirstChild("FleetScroll")
				if fleetScroll then
					fleetScroll.CanvasPosition = Vector2.new(0, math.max(0, card.Position.Y.Offset - 20))
				end
			end
			break
		end
	end
end

local function getHoverCIWS()
	local cf = workspace:FindFirstChild("Ciws")
	if not cf then return nil end
	local ray = mouse.UnitRay
	local cp = RaycastParams.new()
	cp.FilterType = Enum.RaycastFilterType.Include
	cp.FilterDescendantsInstances = {cf}
	local r = workspace:Raycast(ray.Origin, ray.Direction * 15000, cp)
	if r and r.Instance then
		local cur = r.Instance
		while cur and cur.Parent do
			if cur.Parent == cf and cur:IsA("Model") then
				return cur
			end
			cur = cur.Parent
		end
	end
	return nil
end

local function isTaggedAsVehicle(m)
	if not m then return false end
	if CollectionService:HasTag(m, "CRAM_Vehicle") then return true end
	for _, d in ipairs(m:GetDescendants()) do
		if CollectionService:HasTag(d, "CRAM_Vehicle") then return true end
	end
	return false
end

local function getVehicleRootModel(part)
	if not part then return nil end
	local cur = part:IsA("Model") and part or part:FindFirstAncestorOfClass("Model")
	if not cur then return nil end
	local topModel = cur
	local node = cur
	while node and node.Parent and node.Parent ~= workspace do
		local p = node.Parent
		if p.Parent == workspace and p.Name == "Model" and (p:IsA("Model") or p:IsA("Folder")) then
			topModel = node
			break
		end
		if p.Parent == workspace and p:IsA("Folder") then
			topModel = node
			break
		end
		if p:IsA("Model") then
			topModel = p
		end
		node = p
	end
	return topModel
end

local function getHoverTarget()
	local ray = mouse.UnitRay
	local cp = RaycastParams.new()
	cp.FilterType = Enum.RaycastFilterType.Exclude
	local ign = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(ign, p.Character) end
	end
	local cf = workspace:FindFirstChild("Ciws")
	if cf then table.insert(ign, cf) end
	if placementGhost then table.insert(ign, placementGhost) end
	cp.FilterDescendantsInstances = ign
	local r = workspace:Raycast(ray.Origin, ray.Direction * 15000, cp)
	if r and r.Instance then
		local hitPart = r.Instance
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character and hitPart:IsDescendantOf(p.Character) then return nil end
		end
		local root = getVehicleRootModel(hitPart)
		if root and root ~= workspace and root.Name ~= "Map" and root.Name ~= "Baseplate" and root.Name ~= "Terrain" then
			if not Players:GetPlayerFromCharacter(root) then
				if isTaggedAsVehicle(root) or root:FindFirstChildOfClass("Humanoid") or root:FindFirstChild("Durability", true) or root:FindFirstChild("Health", true) or root:FindFirstChild("Arsenal", true) or isVehicleOrTarget(root) then
					return root
				end
			end
		end
		local cur = hitPart
		for i = 1, 10 do
			if cur and cur.Parent and cur.Parent:IsA("Model") then
				cur = cur.Parent
				if cur.Name == "Map" or cur.Name == "Workspace" or cur == workspace then break end
				if Players:GetPlayerFromCharacter(cur) then return nil end
				if isTaggedAsVehicle(cur) or cur:FindFirstChildOfClass("Humanoid") or cur:FindFirstChild("Durability", true) or cur:FindFirstChild("Health", true) or cur:FindFirstChild("Arsenal", true) or isVehicleOrTarget(cur) then
					return cur
				end
			else
				break
			end
		end
	end
	return nil
end

local radarFrame = targetsTab:FindFirstChild("SingleHeader")
if radarFrame then
	local oldSweep = radarFrame:FindFirstChild("RadarSweepBar")
	if oldSweep then oldSweep:Destroy() end
end


local singleRowCache = {}
local permRowCache = {}
local function updateTargetsUI()
	if not cachedState or not cachedState.targets then return end

	local singleList = cachedState.targets.single or {}
	local permList = cachedState.targets.perm or {}

	local ss = targetsTab:FindFirstChild("SingleScroll")
	if ss then
		local validSingleNames = {}
		for _, t in ipairs(singleList) do
			local isPlayerPart = false
			for _, pl in ipairs(Players:GetPlayers()) do
				if pl.Character and t.part and t.part:IsDescendantOf(pl.Character) then
					isPlayerPart = true
					break
				end
			end
			if not isPlayerPart then
				local distStr = ""
				local minDist = math.huge
				if t.part and t.part.Parent then
					local tPos = t.part.Position
					if cachedState and cachedState.units then
						for _, u in pairs(cachedState.units) do
							if u.position then
								local d = (tPos - Vector3.new(u.position.x, u.position.y, u.position.z)).Magnitude
								if d < minDist then minDist = d end
							end
						end
					end
					if minDist == math.huge and player.Character and player.Character.PrimaryPart then
						minDist = (tPos - player.Character.PrimaryPart.Position).Magnitude
					end
					if minDist < 100000 then
						distStr = " • " .. tostring(math.floor(minDist)) .. " studs"
					end
				end

				local idStr = (t.name or "UNKNOWN TARGET") .. (t.part and t.part:GetFullName() or "nil")
				validSingleNames[idStr] = true

				local row = ss:FindFirstChild(idStr)
				if not row then
					row = Instance.new("Frame")
					row.Name = idStr
					row.Size = UDim2.new(1, 0, 0, 32)
					row.BackgroundColor3 = BG_CARD
					row.BorderSizePixel = 0
					row.Parent = ss
					mkS(row, BORDER, 1, 0)

					local dot = Instance.new("Frame")
					dot.Size = UDim2.new(0, 6, 0, 6)
					dot.Position = UDim2.new(0, 10, 0.5, -3)
					dot.BackgroundColor3 = ACCENT
					dot.BorderSizePixel = 0
					dot.Parent = row

					local nl = mkL(row, (t.name or "UNKNOWN TARGET") .. distStr, 10, TEXT_PRIMARY)
					nl.Name = "TextLabel"
					nl.Size = UDim2.new(0.7, 0, 1, 0)
					nl.Position = UDim2.new(0, 24, 0, 0)

					local ub = mkB(row, "DISENGAGE", UDim2.new(0, 90, 0, 22), UDim2.new(1, -96, 0.5, -11), ACCENT_BG, ACCENT_BORDER)
					ub.TextSize = 9
					ub.TextColor3 = ACCENT
					local p = t.part
					conn(ub.MouseButton1Click:Connect(function()
						ub.Text = "DISENGAGING..."
						ub.TextColor3 = TEXT_MUTED
						sendServer("UntagTarget", p)
						task.delay(0.1, function()
							if row and row.Parent then row:Destroy() end
						end)
					end))
				else
					local nl = row:FindFirstChild("TextLabel")
					if nl then nl.Text = (t.name or "UNKNOWN TARGET") .. distStr end
				end
			end
		end

		for _, c in ipairs(ss:GetChildren()) do
			if c:IsA("Frame") and not validSingleNames[c.Name] then
				c:Destroy()
			end
		end
		if #ss:GetChildren() == 0 then
			local emptyCard = ss:FindFirstChild("EmptyCard") or Instance.new("Frame")
			emptyCard.Name = "EmptyCard"
			emptyCard.Size = UDim2.new(1, 0, 0, 50)
			emptyCard.BackgroundColor3 = BG_CARD
			emptyCard.BorderSizePixel = 0
			emptyCard.Parent = ss
			mkS(emptyCard, BORDER, 1, 0)
			if not emptyCard:FindFirstChild("EmptyTitle") then
				local eTitle = mkL(emptyCard, "NO ACTIVE TARGET TRACKS IN PERIMETER", 10, TEXT_DIM, Enum.TextXAlignment.Center)
				eTitle.Name = "EmptyTitle"
				eTitle.Size = UDim2.new(1, 0, 1, 0)
				eTitle.Position = UDim2.new(0, 0, 0, 0)
			end
		else
			local eCard = ss:FindFirstChild("EmptyCard")
			if eCard then eCard:Destroy() end
		end
	end

	local ps = targetsTab:FindFirstChild("PermScroll")
	if ps then
		for _, c in ipairs(ps:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
		end

		local permRules = (cachedState and cachedState.targets and (cachedState.targets.permRules or cachedState.targets.perm)) or {}
		local activeRuleMap = {}
		for _, rule in ipairs(permRules) do
			local rName = type(rule) == "table" and rule.name or rule
			if rName then
				activeRuleMap[string.lower(cleanModelName(rName))] = rName
			end
		end

		local h1 = mkL(ps, "Target Catalog", 11, TEXT_PRIMARY, Enum.TextXAlignment.Left, true)
		h1.Size = UDim2.new(1, -8, 0, 22)
		h1.LayoutOrder = 1

		local subH = mkL(ps, "Select vehicles for C-RAM units in Global Mode to automatically engage.", 9, TEXT_SECONDARY, Enum.TextXAlignment.Left, false)
		subH.Size = UDim2.new(1, -8, 0, 16)
		subH.LayoutOrder = 2

		local barRow = Instance.new("Frame")
		barRow.Size = UDim2.new(1, -8, 0, 28)
		barRow.BackgroundTransparency = 1
		barRow.LayoutOrder = 3
		barRow.Parent = ps

		local targetAllBtn = mkB(barRow, "Target All", UDim2.new(0.5, -4, 0, 24), UDim2.new(0, 0, 0, 2), SUCCESS_BG, SUCCESS_BORDER)
		targetAllBtn.TextSize = 9
		targetAllBtn.TextColor3 = SUCCESS
		conn(targetAllBtn.MouseButton1Click:Connect(function()
			sendServer("TargetAllPresets", {catalog = PRESET_CATALOG})
			targetAllBtn.Text = "All Targeted"
			task.delay(1.5, function()
				if targetAllBtn and targetAllBtn.Parent then
					targetAllBtn.Text = "Target All"
				end
			end)
		end))

		local clearAllBtn = mkB(barRow, "Disengage All", UDim2.new(0.5, -4, 0, 24), UDim2.new(0.5, 4, 0, 2), ACCENT_BG, ACCENT_BORDER)
		clearAllBtn.TextSize = 9
		clearAllBtn.TextColor3 = ACCENT
		conn(clearAllBtn.MouseButton1Click:Connect(function()
			sendServer("DisengageAllPerm")
			clearAllBtn.Text = "All Disengaged"
			task.delay(1.5, function()
				if clearAllBtn and clearAllBtn.Parent then
					clearAllBtn.Text = "Disengage All"
				end
			end)
		end))

		local curOrder = 4

		for _, cat in ipairs(TARGET_CATEGORIES) do
			local catSection = Instance.new("Frame")
			catSection.Name = "CatSection_" .. cat.id
			catSection.Size = UDim2.new(1, -8, 0, 32 + (#cat.items * 34))
			catSection.BackgroundColor3 = BG_CARD
			catSection.BorderSizePixel = 0
			catSection.LayoutOrder = curOrder
			catSection.Parent = ps
			mkS(catSection, BORDER, 1, 0)
			curOrder = curOrder + 1

			local catHdr = Instance.new("Frame")
			catHdr.Size = UDim2.new(1, 0, 0, 28)
			catHdr.BackgroundColor3 = BG_PANEL
			catHdr.BorderSizePixel = 0
			catHdr.Parent = catSection
			mkS(catHdr, BORDER, 1, 0)

			local cTitle = mkL(catHdr, cat.category .. " (" .. tostring(#cat.items) .. ")", 10, Color3.fromRGB(210, 215, 220), Enum.TextXAlignment.Left, false)
			cTitle.Size = UDim2.new(0.55, 0, 1, 0)
			cTitle.Position = UDim2.new(0, 8, 0, 0)

			local cTargAll = mkB(catHdr, "[TARGET ALL]", UDim2.new(0, 80, 0, 20), UDim2.new(1, -172, 0.5, -10), SUCCESS_BG, SUCCESS_BORDER)
			cTargAll.TextSize = 8
			cTargAll.TextColor3 = SUCCESS
			conn(cTargAll.MouseButton1Click:Connect(function()
				sendServer("TargetBatch", {items = cat.items})
			end))

			local cDisAll = mkB(catHdr, "[DISENGAGE]", UDim2.new(0, 80, 0, 20), UDim2.new(1, -86, 0.5, -10), ACCENT_BG, ACCENT_BORDER)
			cDisAll.TextSize = 8
			cDisAll.TextColor3 = ACCENT
			conn(cDisAll.MouseButton1Click:Connect(function()
				sendServer("DisengageBatch", {items = cat.items})
			end))

			local itList = Instance.new("Frame")
			itList.Size = UDim2.new(1, -8, 0, #cat.items * 32)
			itList.Position = UDim2.new(0, 4, 0, 30)
			itList.BackgroundTransparency = 1
			itList.Parent = catSection

			local itLy = Instance.new("UIListLayout")
			itLy.SortOrder = Enum.SortOrder.LayoutOrder
			itLy.Padding = UDim.new(0, 2)
			itLy.Parent = itList

			for idx, itemName in ipairs(cat.items) do
				local cleanN = cleanModelName(itemName)
				local isActive = activeRuleMap[string.lower(cleanN)] ~= nil
				local matchedRuleId = activeRuleMap[string.lower(cleanN)]

				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 28)
				row.BackgroundColor3 = isActive and Color3.fromRGB(32, 14, 14) or BG_PANEL
				row.BorderSizePixel = 0
				row.LayoutOrder = idx
				row.Parent = itList
				mkS(row, isActive and ACCENT_BORDER or BORDER, 1, 0)

				local dot = Instance.new("Frame")
				dot.Size = UDim2.new(0, 6, 0, 6)
				dot.Position = UDim2.new(0, 8, 0.5, -3)
				dot.BackgroundColor3 = isActive and ACCENT or TEXT_DIM
				dot.BorderSizePixel = 0
				dot.Parent = row

				local titleStr = itemName .. (isActive and " [LOCKED AS HOSTILE]" or " [STANDBY]")
				local nl = mkL(row, titleStr, 10, isActive and Color3.fromRGB(220, 150, 150) or Color3.fromRGB(210, 215, 220), Enum.TextXAlignment.Left, false)
				nl.Size = UDim2.new(1, -120, 1, 0)
				nl.Position = UDim2.new(0, 20, 0, 0)

				if isActive then
					local db = mkB(row, "[DISENGAGE]", UDim2.new(0, 90, 0, 22), UDim2.new(1, -96, 0.5, -11), ACCENT_BG, ACCENT_BORDER)
					db.TextSize = 9
					db.TextColor3 = ACCENT
					local ruleToUntag = matchedRuleId or cleanN
					conn(db.MouseButton1Click:Connect(function()
						db.Text = "DISENGAGING..."
						sendServer("UntagPerm", ruleToUntag)
					end))
				else
					local tb = mkB(row, "[TARGET]", UDim2.new(0, 90, 0, 22), UDim2.new(1, -96, 0.5, -11), SUCCESS_BG, SUCCESS_BORDER)
					tb.TextSize = 9
					tb.TextColor3 = SUCCESS
					conn(tb.MouseButton1Click:Connect(function()
						tb.Text = "TARGETING..."
						sendServer("DesignatePerm", {cleanName = cleanN})
					end))
				end
			end
		end
		local uncatList = getUncategorizedDetectedTargets()
		local uncatSection = Instance.new("Frame")
		uncatSection.Name = "CatSection_UNCATEGORIZED"
		local uncatSecCount = math.max(1, #uncatList)
		uncatSection.Size = UDim2.new(1, -8, 0, 32 + (uncatSecCount * 34))
		uncatSection.BackgroundColor3 = BG_CARD
		uncatSection.BorderSizePixel = 0
		uncatSection.LayoutOrder = curOrder
		uncatSection.Parent = ps
		mkS(uncatSection, BORDER, 1, 0)
		curOrder = curOrder + 1

		local uncatHdr = Instance.new("Frame")
		uncatHdr.Size = UDim2.new(1, 0, 0, 28)
		uncatHdr.BackgroundColor3 = BG_PANEL
		uncatHdr.BorderSizePixel = 0
		uncatHdr.Parent = uncatSection
		mkS(uncatHdr, BORDER, 1, 0)

		local uTitle = mkL(uncatHdr, "UNCATEGORIZED DETECTED TARGETS (" .. tostring(#uncatList) .. ")", 10, Color3.fromRGB(210, 215, 220), Enum.TextXAlignment.Left, false)
		uTitle.Size = UDim2.new(0.55, 0, 1, 0)
		uTitle.Position = UDim2.new(0, 8, 0, 0)

		local uTargAll = mkB(uncatHdr, "[TARGET ALL]", UDim2.new(0, 80, 0, 20), UDim2.new(1, -172, 0.5, -10), SUCCESS_BG, SUCCESS_BORDER)
		uTargAll.TextSize = 8
		uTargAll.TextColor3 = SUCCESS
		conn(uTargAll.MouseButton1Click:Connect(function()
			local names = {}
			for _, itm in ipairs(uncatList) do table.insert(names, itm.cleanName) end
			sendServer("TargetBatch", {items = names})
		end))

		local uDisAll = mkB(uncatHdr, "[DISENGAGE]", UDim2.new(0, 80, 0, 20), UDim2.new(1, -86, 0.5, -10), ACCENT_BG, ACCENT_BORDER)
		uDisAll.TextSize = 8
		uDisAll.TextColor3 = ACCENT
		conn(uDisAll.MouseButton1Click:Connect(function()
			local names = {}
			for _, itm in ipairs(uncatList) do table.insert(names, itm.cleanName) end
			sendServer("DisengageBatch", {items = names})
		end))

		local uItList = Instance.new("Frame")
		uItList.Size = UDim2.new(1, -8, 0, uncatSecCount * 32)
		uItList.Position = UDim2.new(0, 4, 0, 30)
		uItList.BackgroundTransparency = 1
		uItList.Parent = uncatSection

		local uItLy = Instance.new("UIListLayout")
		uItLy.SortOrder = Enum.SortOrder.LayoutOrder
		uItLy.Padding = UDim.new(0, 2)
		uItLy.Parent = uItList

		if #uncatList == 0 then
			local emptyRow = Instance.new("Frame")
			emptyRow.Size = UDim2.new(1, 0, 0, 28)
			emptyRow.BackgroundColor3 = BG_PANEL
			emptyRow.BorderSizePixel = 0
			emptyRow.Parent = uItList
			mkS(emptyRow, BORDER, 1, 0)
			local el = mkL(emptyRow, "NO UNLISTED VEHICLES DETECTED IN AIRSPACE", 9, TEXT_DIM, Enum.TextXAlignment.Center, false)
			el.Size = UDim2.new(1, 0, 1, 0)
		else
			for uIdx, itm in ipairs(uncatList) do
				local cleanN = itm.cleanName
				local isActive = activeRuleMap[string.lower(cleanN)] ~= nil
				local matchedRuleId = activeRuleMap[string.lower(cleanN)]

				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 28)
				row.BackgroundColor3 = isActive and Color3.fromRGB(32, 14, 14) or BG_PANEL
				row.BorderSizePixel = 0
				row.LayoutOrder = uIdx
				row.Parent = uItList
				mkS(row, isActive and ACCENT_BORDER or BORDER, 1, 0)

				local dot = Instance.new("Frame")
				dot.Size = UDim2.new(0, 6, 0, 6)
				dot.Position = UDim2.new(0, 8, 0.5, -3)
				dot.BackgroundColor3 = isActive and ACCENT or TEXT_DIM
				dot.BorderSizePixel = 0
				dot.Parent = row

				local titleStr = itm.cleanName .. (isActive and " [LOCKED AS HOSTILE]" or " [STANDBY]")
				local nl = mkL(row, titleStr, 10, isActive and Color3.fromRGB(220, 150, 150) or Color3.fromRGB(210, 215, 220), Enum.TextXAlignment.Left, false)
				nl.Size = UDim2.new(1, -120, 1, 0)
				nl.Position = UDim2.new(0, 20, 0, 0)

				if isActive then
					local db = mkB(row, "[DISENGAGE]", UDim2.new(0, 90, 0, 22), UDim2.new(1, -96, 0.5, -11), ACCENT_BG, ACCENT_BORDER)
					db.TextSize = 9
					db.TextColor3 = ACCENT
					local ruleToUntag = matchedRuleId or cleanN
					conn(db.MouseButton1Click:Connect(function()
						db.Text = "DISENGAGING..."
						sendServer("UntagPerm", ruleToUntag)
					end))
				else
					local tb = mkB(row, "[TARGET]", UDim2.new(0, 90, 0, 22), UDim2.new(1, -96, 0.5, -11), SUCCESS_BG, SUCCESS_BORDER)
					tb.TextSize = 9
					tb.TextColor3 = SUCCESS
					conn(tb.MouseButton1Click:Connect(function()
						tb.Text = "TARGETING..."
						sendServer("DesignatePerm", {cleanName = cleanN})
					end))
				end
			end
		end

		ps.AutomaticCanvasSize = Enum.AutomaticSize.Y
		ps.CanvasSize = UDim2.new(0, 0, 0, 0)
		local psLy = ps:FindFirstChildOfClass("UIListLayout")
		if psLy then
			local function updatePs()
				ps.CanvasSize = UDim2.new(0, 0, 0, psLy.AbsoluteContentSize.Y + 100)
			end
			psLy:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updatePs)
			task.defer(updatePs)
		end
		local spacer = ps:FindFirstChild("BottomSpacer")
		if not spacer then
			spacer = Instance.new("Frame")
			spacer.Name = "BottomSpacer"
			spacer.Size = UDim2.new(1, 0, 0, 60)
			spacer.BackgroundTransparency = 1
			spacer.LayoutOrder = 9999
			spacer.Parent = ps
		end

	end
end

local function stopPlacement()
	placementMode = false
	placementTemplate = nil
	placementRotation = 0
	if placementGhost then
		placementGhost:Destroy()
		placementGhost = nil
	end
end

local function getSurfaceRotation(norm, rotDeg, hitPart)
	local toUp = norm.Unit
	local forward
	if hitPart and (not hitPart.Anchored) then
		local vLook = hitPart.CFrame.LookVector
		forward = vLook - toUp * vLook:Dot(toUp)
		if forward.Magnitude < 0.001 then
			local vRight = hitPart.CFrame.RightVector
			forward = vRight - toUp * vRight:Dot(toUp)
		end
	else
		local wLook = Vector3.new(0, 0, -1)
		forward = wLook - toUp * wLook:Dot(toUp)
		if forward.Magnitude < 0.001 then
			local wRight = Vector3.new(1, 0, 0)
			forward = wRight - toUp * wRight:Dot(toUp)
		end
	end

	if forward.Magnitude < 0.001 then
		forward = Vector3.new(0, 0, -1)
	else
		forward = forward.Unit
	end

	local right = forward:Cross(toUp).Unit
	forward = toUp:Cross(right).Unit

	local baseCF = CFrame.fromMatrix(Vector3.zero, right, toUp, -forward)
	if rotDeg and rotDeg ~= 0 then
		baseCF = baseCF * CFrame.Angles(0, math.rad(rotDeg), 0)
	end
	return baseCF
end

local function startPlacement(templateName)
	stopPlacement()
	local tmplFolder = getTemplatesFolder()
	local tmpl = tmplFolder and tmplFolder:FindFirstChild(templateName)
	if not tmpl then return end

	placementMode = true
	mf.Visible = false
	placementTemplate = templateName
	placementRotation = 0

	placementGhost = tmpl:Clone()
	placementGhost.Name = "PlacementGhost"
	local bc = placementGhost:FindFirstChild("BaseComponent")
	if bc then
		placementGhost.PrimaryPart = bc
	end

	for _, p in ipairs(placementGhost:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.CastShadow = false
			p.Anchored = true
			p.Transparency = 0.4
			p.Color = SUCCESS
			p.Material = Enum.Material.Neon
		elseif p:IsA("GuiBase3d") or p:IsA("ParticleEmitter") or p:IsA("Light") or p:IsA("Sound") or p:IsA("LuaSourceContainer") then
			p:Destroy()
		end
	end
	placementGhost.Parent = workspace
end

local deployCardsCache = {}
local function updateDeployUI()
	activePreviews = {}
	if not cachedState or not cachedState.templates then return end
	local tg = deployTab:FindFirstChild("TemplateGrid")
	if not tg then return end

	local tmpls = cachedState.templates
	local tmplFolder = getTemplatesFolder()

	for _, c in ipairs(tg:GetChildren()) do
		if c:IsA("Frame") and not table.find(tmpls, c.Name) then
			c:Destroy()
			deployCardsCache[c.Name] = nil
		end
	end

	for _, tName in ipairs(tmpls) do
		local card = tg:FindFirstChild(tName)
		if not card then
			card = Instance.new("Frame")
			card.Name = tName
			card.Size = UDim2.new(0, 290, 0, 330)
			card.BackgroundColor3 = BG_CARD
			card.BorderSizePixel = 0
			card.Parent = tg
			mkC(card, 4)
			mkS(card, BORDER, 1, 0.4)

			local vf = Instance.new("ViewportFrame")
			vf.Name = "VF"
			vf.Size = UDim2.new(1, -16, 0, 200)
			vf.Position = UDim2.new(0, 8, 0, 8)
			vf.BackgroundColor3 = BG_DARK
			vf.BorderSizePixel = 0
			vf.Parent = card
			mkC(vf, 3)
			mkS(vf, Color3.fromRGB(30, 42, 54), 1, 0.5)

			local tmpl = tmplFolder and tmplFolder:FindFirstChild(tName)
			if tmpl then
				local previewModel = tmpl:Clone()
				local pbc = previewModel:FindFirstChild("BaseComponent")
				if pbc then
					previewModel.PrimaryPart = pbc
				end

				for _, d in ipairs(previewModel:GetDescendants()) do
					if d:IsA("BasePart") then
						d.CanCollide = false
						d.CanTouch = false
						d.CanQuery = false
						d.Anchored = true
					elseif d:IsA("GuiBase3d") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Sound") or d:IsA("LuaSourceContainer") then
						d:Destroy()
					end
				end

				local cf, sz = previewModel:GetBoundingBox()
				local center = cf.Position
				for _, part in ipairs(previewModel:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CFrame = CFrame.new(-center) * part.CFrame
					end
				end

				previewModel.Parent = vf

				local maxDim = math.max(sz.X, sz.Y, sz.Z, 8)
				local dist = maxDim * 1.35

				local cam = Instance.new("Camera")
				cam.FieldOfView = 50
				cam.CFrame = CFrame.lookAt(Vector3.new(0, maxDim * 0.4, dist), Vector3.zero)
				cam.Parent = vf
				vf.CurrentCamera = cam
				vf.LightColor = Color3.fromRGB(255, 255, 255)
				vf.Ambient = Color3.fromRGB(150, 165, 180)
				vf.LightDirection = Vector3.new(-1, -2, -1).Unit

				deployCardsCache[tName] = {
					camera = cam,
					radius = dist,
					height = maxDim * 0.4,
				}
			end

			local nl = mkL(card, tName, 12, TEXT_PRIMARY)
			nl.Size = UDim2.new(1, -16, 0, 18)
			nl.Position = UDim2.new(0, 8, 0, 218)
			nl.TextTruncate = Enum.TextTruncate.AtEnd

			local spec = mkL(card, "20mm Gatling • 360° Radar", 9, TEXT_DIM)
			spec.Size = UDim2.new(1, -16, 0, 14)
			spec.Position = UDim2.new(0, 8, 0, 240)

			local sb = mkB(card, "[DEPLOY CIWS MOUNT]", UDim2.new(1, -16, 0, 34), UDim2.new(0, 8, 1, -42), BG_INPUT, BORDER)
			sb.TextSize = 11
			conn(sb.MouseButton1Click:Connect(function()
				startPlacement(tName)
			end))
		end
		if deployCardsCache[tName] then
			table.insert(activePreviews, deployCardsCache[tName])
		end
	end
end

local function buildGlobalSlidersOnce()
	if globalSlidersBuilt or not cachedState or not cachedState.globalConfig then return end
	globalSlidersBuilt = true

	local gs = globalTab:FindFirstChild("GlobalScroll")
	if not gs then return end

	gs.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gs.CanvasSize = UDim2.new(0, 0, 0, 0)
	mkP(gs, 8, 8, 50, 8)

	local oldH = gs:FindFirstChild("Header_GlobalConfig")
	if oldH then oldH.Visible = false end

	local cfg = cachedState.globalConfig
	local pending = {
		maxRange = cfg.maxRange or 6000,
		maxAmmo = cfg.maxAmmo or 1500,
		bulletSpeed = cfg.bulletSpeed or 3500,
		damage = cfg.damage or 25,
		burstDuration = cfg.burstDuration or 1.6,
		slewRate = cfg.slewRate or 165,
		leadCompensation = cfg.leadCompensation or 1.0,
		targetWhitelist = table.clone(cfg.targetWhitelist or {}),
	}

	local gsOrd = 4

	local h1 = mkL(gs, "Global Fire Control: Engagement Range", 11, Color3.fromRGB(210, 215, 220), Enum.TextXAlignment.Left, false)
	h1.Size = UDim2.new(1, 0, 0, 24)
	h1.LayoutOrder = gsOrd
	gsOrd = gsOrd + 1

	local sub1 = mkL(gs, "Adjust radar perimeter & engagement distance. Ballistics are factory-calibrated to standard 20mm HEIT.", 9, TEXT_SECONDARY, Enum.TextXAlignment.Left, false)
	sub1.Size = UDim2.new(1, 0, 0, 16)
	sub1.LayoutOrder = gsOrd
	gsOrd = gsOrd + 1

	local function addGSlider(name, minVal, maxVal, curVal, isFloat, cb)
		local s = createSlider(gs, name, minVal, maxVal, curVal, isFloat, cb)
		s.row.LayoutOrder = gsOrd
		gsOrd = gsOrd + 1
		return s
	end

	addGSlider("Max Range (Studs)", 1000, 40000, pending.maxRange, false, function(v) pending.maxRange = v end)

	local depBtn = mkB(gs, "Apply to All Global Units", UDim2.new(1, 0, 0, 32), nil, BG_CARD, BORDER)
	depBtn.TextSize = 10
	depBtn.TextColor3 = TEXT_PRIMARY
	depBtn.LayoutOrder = gsOrd
	gsOrd = gsOrd + 1

	conn(depBtn.MouseButton1Click:Connect(function()
		sendServer("ApplyGlobalConfig", pending)
		depBtn.Text = "Settings Applied"
		task.delay(1.5, function()
			if depBtn and depBtn.Parent then
				depBtn.Text = "Apply to All Global Units"
			end
		end)
	end))

	local h0 = mkL(gs, "Global Target List", 11, Color3.fromRGB(210, 215, 220), Enum.TextXAlignment.Left, false)
	h0.Size = UDim2.new(1, 0, 0, 28)
	h0.LayoutOrder = gsOrd
	gsOrd = gsOrd + 1

	local sub0 = mkL(gs, "Vehicles and craft authorized for C-RAMs under Global Mode:", 9, TEXT_SECONDARY, Enum.TextXAlignment.Left, false)
	sub0.Size = UDim2.new(1, 0, 0, 16)
	sub0.LayoutOrder = gsOrd
	gsOrd = gsOrd + 1

	local permContainer = Instance.new("Frame")
	permContainer.Name = "GlobalPermContainer"
	permContainer.Size = UDim2.new(1, 0, 0, 0)
	permContainer.AutomaticSize = Enum.AutomaticSize.Y
	permContainer.BackgroundColor3 = BG_CARD
	permContainer.BorderSizePixel = 0
	permContainer.LayoutOrder = gsOrd
	permContainer.Parent = gs
	mkS(permContainer, BORDER, 1, 0)
	gsOrd = gsOrd + 1

	local pcLy = Instance.new("UIListLayout")
	pcLy.SortOrder = Enum.SortOrder.LayoutOrder
	pcLy.Padding = UDim.new(0, 6)
	pcLy.Parent = permContainer
	mkP(permContainer, 6, 6, 6, 6)

	renderTargetMatrix(permContainer, pending.targetWhitelist, function(updatedList)
		pending.targetWhitelist = updatedList
	end)

	local endSpacer = Instance.new("Frame")
	endSpacer.Name = "GlobalEndSpacer"
	endSpacer.Size = UDim2.new(1, 0, 0, 100)
	endSpacer.BackgroundTransparency = 1
	endSpacer.LayoutOrder = 99999
	endSpacer.Parent = gs

	local gsLy = gs:FindFirstChildOfClass("UIListLayout")
	if gsLy then
		local function updateGs()
			gs.CanvasSize = UDim2.new(0, 0, 0, gsLy.AbsoluteContentSize.Y + 100)
		end
		gsLy:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateGs)
		task.defer(updateGs)
	end
end

local function updateFleetUI()
	if not cachedState or not cachedState.units then return end
	local fs = fleetTab:FindFirstChild("FleetScroll")
	if fs then
		fs.AutomaticCanvasSize = Enum.AutomaticSize.Y
		fs.CanvasSize = UDim2.new(0, 0, 0, 0)
		local fsLy = fs:FindFirstChildOfClass("UIListLayout")
		if fsLy then
			local function updateFs()
				fs.CanvasSize = UDim2.new(0, 0, 0, fsLy.AbsoluteContentSize.Y + 100)
			end
			fsLy:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateFs)
			task.defer(updateFs)
		end
	end
	local sl = fleetTab:FindFirstChild("StatsBar") and fleetTab.StatsBar:FindFirstChild("StatsLabel")
	if not fs then return end

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
			card.BackgroundColor3 = BG_PANEL
			card.BorderSizePixel = 0
			card.LayoutOrder = uc
			card.Parent = fs
			mkC(card, 4)
			mkS(card, BORDER, 1, 0.5)
			fleetCards[id] = card

			local sd = Instance.new("Frame")
			sd.Name = "StatusDot"
			sd.Size = UDim2.new(0, 10, 0, 10)
			sd.Position = UDim2.new(0, 12, 0, 12)
			sd.BackgroundColor3 = SUCCESS
			sd.BorderSizePixel = 0
			sd.Parent = card
			mkC(sd, 5)

			local nl = mkL(card, "", 12, TEXT_PRIMARY, Enum.TextXAlignment.Left, true)
			nl.Name = "NameLabel"
			nl.Size = UDim2.new(0.55, 0, 0, 20)
			nl.Position = UDim2.new(0, 28, 0, 8)
			nl.TextTruncate = Enum.TextTruncate.AtEnd

			local modeBadge = Instance.new("Frame")
			modeBadge.Name = "ModeBadge"
			modeBadge.Size = UDim2.new(0, 135, 0, 20)
			modeBadge.Position = UDim2.new(1, -145, 0, 8)
			modeBadge.BackgroundColor3 = isIndiv and AMBER_DIM or CYAN_DIM
			modeBadge.BorderSizePixel = 0
			modeBadge.Parent = card
			mkC(modeBadge, 3)
			local mbStroke = mkS(modeBadge, isIndiv and AMBER or CYAN, 1, 0.3)

			local mbLbl = mkL(modeBadge, isIndiv and "[MODE: INDIVIDUAL]" or "[MODE: GLOBAL]", 9, isIndiv and AMBER or CYAN, Enum.TextXAlignment.Center, true)
			mbLbl.Name = "BadgeLabel"
			mbLbl.Size = UDim2.new(1, 0, 1, 0)

			local stl = mkL(card, "", 10, SUCCESS, Enum.TextXAlignment.Right, true)
			stl.Name = "StatusLabel"
			stl.Size = UDim2.new(0, 140, 0, 16)
			stl.Position = UDim2.new(1, -150, 0, 30)

			local tgtLbl = mkL(card, "", 10, TEXT_SECONDARY, Enum.TextXAlignment.Left, false)
			tgtLbl.Name = "TargetLabel"
			tgtLbl.Size = UDim2.new(0.6, 0, 0, 16)
			tgtLbl.Position = UDim2.new(0, 28, 0, 30)

			local ab = Instance.new("Frame")
			ab.Name = "AmmoBar"
			ab.Size = UDim2.new(0.6, 0, 0, 5)
			ab.Position = UDim2.new(0, 28, 0, 50)
			ab.BackgroundColor3 = BG_INPUT
			ab.BorderSizePixel = 0
			ab.Parent = card
			mkC(ab, 2)

			local af = Instance.new("Frame")
			af.Name = "AmmoFill"
			af.Size = UDim2.new(1, 0, 1, 0)
			af.BackgroundColor3 = SUCCESS
			af.BorderSizePixel = 0
			af.Parent = ab
			mkC(af, 2)

			local ar = Instance.new("Frame")
			ar.Name = "ActionRow"
			ar.Size = UDim2.new(1, -24, 0, 26)
			ar.Position = UDim2.new(0, 12, 0, 62)
			ar.BackgroundColor3 = BG_CARD
			ar.BackgroundTransparency = 0
			ar.Parent = card

			local mb = mkB(ar, isIndiv and "[SWITCH TO GLOBAL MODE]" or "[SWITCH TO INDIVIDUAL MODE]", UDim2.new(0, 175, 0, 26), UDim2.new(0, 0, 0, 0), BG_INPUT, BORDER)
			mb.Name = "ModeBtn"
			mb.TextSize = 9
			mb.TextColor3 = isIndiv and CYAN or AMBER
			conn(mb.MouseButton1Click:Connect(function()
				local curUnit = cachedState and cachedState.units and cachedState.units[id]
				local curIsIndiv = curUnit and (curUnit.config.targetMode == "INDIVIDUAL" or curUnit.config.mode == "INDIVIDUAL")
				local nextM = curIsIndiv and "GLOBAL" or "INDIVIDUAL"
				local wireMode = (nextM == "GLOBAL") and "OVERALL" or "INDIVIDUAL"
				if curUnit and curUnit.config then
					curUnit.config.targetMode = nextM
					curUnit.config.mode = wireMode
				end
				sendServer("SetUnitTargetMode", {unitId = id, mode = nextM})
				sendServer("SetUnitMode", {unitId = id, mode = wireMode})
				if nextM == "GLOBAL" then
					expandedUnits[id] = false
					local panel = card:FindFirstChild("ConfigPanel")
					local panelBtn = card:FindFirstChild("CfgBtn")
					if panel then
						panel.Visible = false
						panel.Size = UDim2.new(1, -24, 0, 0)
					end
					if panelBtn then
						panelBtn.Text = "[+] CONFIGURE TARGETING & FIRE CONTROL"
					end
				end
				updateFleetUI()
			end))

			local tb2 = mkB(ar, u.config.enabled and "ONLINE" or "STANDBY", UDim2.new(0, 90, 0, 26), UDim2.new(0, 183, 0, 0), BG_INPUT, BORDER)
			tb2.Name = "ToggleBtn"
			tb2.TextSize = 9
			tb2.TextColor3 = Color3.fromRGB(240, 240, 240)
			conn(tb2.MouseButton1Click:Connect(function()
				local curUnit = cachedState and cachedState.units and cachedState.units[id]
				local curEnabled = true
				if curUnit and curUnit.config and curUnit.config.enabled ~= nil then
					curEnabled = curUnit.config.enabled
				end
				local nextState = not curEnabled
				if curUnit and curUnit.config then curUnit.config.enabled = nextState end
				tb2.Text = nextState and "Online" or "Standby"
				tb2.BackgroundColor3 = nextState and Color3.fromRGB(20, 60, 35) or Color3.fromRGB(40, 48, 58)
				tb2.TextColor3 = Color3.fromRGB(240, 240, 240)
				sendServer("ToggleUnit", {unitId = id, enabled = nextState})
			end))

			local rb = mkB(ar, "Resupply", UDim2.new(0, 90, 0, 26), UDim2.new(0, 281, 0, 0), Color3.fromRGB(45, 38, 20), Color3.fromRGB(110, 85, 35))
			rb.TextSize = 9
			rb.TextColor3 = Color3.fromRGB(240, 240, 240)
			conn(rb.MouseButton1Click:Connect(function()
				sendServer("RefillAmmo", {unitId = id})
			end))

			local rel = mkB(ar, "Cycle Drum", UDim2.new(0, 100, 0, 26), UDim2.new(0, 379, 0, 0), Color3.fromRGB(26, 34, 42), Color3.fromRGB(50, 70, 95))
			rel.TextSize = 9
			rel.TextColor3 = Color3.fromRGB(240, 240, 240)
			conn(rel.MouseButton1Click:Connect(function()
				sendServer("ReloadUnit", {unitId = id})
				rel.Text = "Cycling..."
				task.delay(2.7, function()
					if rel and rel.Parent then
						rel.Text = "Cycle Drum"
					end
				end)
			end))

			local del = mkB(ar, "Decommission", UDim2.new(0, 110, 0, 26), UDim2.new(0, 487, 0, 0), Color3.fromRGB(48, 20, 20), Color3.fromRGB(125, 45, 45))
			del.TextSize = 9
			del.TextColor3 = Color3.fromRGB(240, 240, 240)
			conn(del.MouseButton1Click:Connect(function()
				sendServer("DestroyCIWS", {unitId = id})
				if cachedState and cachedState.units then
					cachedState.units[id] = nil
				end
				if card and card.Parent then
					card:Destroy()
				end
				fleetCards[id] = nil
				updateFleetUI()
			end))

			local canBreakState = true
			if u.model and u.model:FindFirstChild("Disabled_Durability", true) then
				canBreakState = false
			end

			local cbBtn = mkB(ar, canBreakState and "Can Break" or "Invincible", UDim2.new(0, 85, 0, 26), UDim2.new(0, 688, 0, 0), canBreakState and SUCCESS_BG or ACCENT_BG, canBreakState and SUCCESS_BORDER or ACCENT_BORDER)
			cbBtn.TextSize = 9
			cbBtn.TextColor3 = canBreakState and SUCCESS or ACCENT
			conn(cbBtn.MouseButton1Click:Connect(function()
				canBreakState = not canBreakState
				cbBtn.Text = canBreakState and "Can Break" or "Invincible"
				cbBtn.BackgroundColor3 = canBreakState and SUCCESS_BG or ACCENT_BG
				cbBtn.TextColor3 = canBreakState and SUCCESS or ACCENT
				local st = cbBtn:FindFirstChildWhichIsA("UIStroke")
				if st then st.Color = canBreakState and SUCCESS_BORDER or ACCENT_BORDER end
				sendServer("ToggleCanBreak", {unitId = id, canBreak = canBreakState})
			end))

			local cfgBtn = mkB(card, "[+] CONFIGURE TARGETING & FIRE CONTROL", UDim2.new(1, -24, 0, 26), UDim2.new(0, 12, 0, 96), BG_CARD, BORDER)
			cfgBtn.Name = "CfgBtn"
			cfgBtn.TextSize = 9
			cfgBtn.TextColor3 = TEXT_PRIMARY

			card.AutomaticSize = Enum.AutomaticSize.Y
			card.Size = UDim2.new(1, -12, 0, 128)

			local cfgPanel = Instance.new("Frame")
			cfgPanel.Name = "ConfigPanel"
			cfgPanel.Size = UDim2.new(1, -24, 0, 0)
			cfgPanel.Position = UDim2.new(0, 12, 0, 128)
			cfgPanel.BackgroundColor3 = BG_CARD
			cfgPanel.BorderSizePixel = 0
			cfgPanel.AutomaticSize = Enum.AutomaticSize.Y
			cfgPanel.Visible = false
			cfgPanel.Parent = card
			mkS(cfgPanel, BORDER, 1, 0)

			local cfgLy = Instance.new("UIListLayout")
			cfgLy.SortOrder = Enum.SortOrder.LayoutOrder
			cfgLy.Padding = UDim.new(0, 6)
			cfgLy.Parent = cfgPanel
			mkP(cfgPanel, 8, 10, 14, 10)

			local baseConfig = (u.config.mode == "OVERALL" and cachedState.globalConfig) or u.config
			local pending = {
				maxRange = baseConfig.maxRange or 6000,
				bulletSpeed = baseConfig.bulletSpeed or 3500,
				damage = baseConfig.damage or 25,
				explosionRadius = baseConfig.explosionRadius or 30,
				fireRate = baseConfig.fireRate or 1.0,
				burstDuration = baseConfig.burstDuration or 1.6,
				evalPause = baseConfig.evalPause or 0.75,
				slewRate = baseConfig.slewRate or 165,
				leadCompensation = baseConfig.leadCompensation or 1.0,
				spreadAngle = baseConfig.spreadAngle or 0.35,
				tracerCaliber = baseConfig.tracerCaliber or 1.0,
				tracerLum = baseConfig.tracerLum or 1.0,
				continuousFire = baseConfig.continuousFire or false,
				infiniteAmmo = baseConfig.infiniteAmmo or false,
				thermalOverride = baseConfig.thermalOverride or false,
				targetMode = u.config.targetMode or (isIndiv and "INDIVIDUAL" or "GLOBAL"),
				mode = u.config.mode or (isIndiv and "INDIVIDUAL" or "OVERALL"),
				targetWhitelist = table.clone(baseConfig.targetWhitelist or {}),
			}

			local function rebuildConfigPanel()
				cfgPanel.BackgroundColor3 = BG_CARD
				cfgPanel.BackgroundTransparency = 0
				for _, child in ipairs(cfgPanel:GetChildren()) do
					if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
						child:Destroy()
					end
				end

				local curIndiv = (u.config.targetMode == "INDIVIDUAL" or u.config.mode == "INDIVIDUAL")

				local modeBar = Instance.new("Frame")
				modeBar.Size = UDim2.new(1, 0, 0, 42)
				modeBar.BackgroundColor3 = BG_PANEL
				modeBar.BorderSizePixel = 0
				modeBar.LayoutOrder = 1
				modeBar.Parent = cfgPanel
				mkS(modeBar, BORDER, 1, 0)

				local mbTitle = mkL(modeBar, curIndiv and "Mode: Individual Mode (Custom Unit Settings)" or "Mode: Global Mode (Inheriting Global defaults)", 10, Color3.fromRGB(210, 215, 220), Enum.TextXAlignment.Left, false)
				mbTitle.Position = UDim2.new(0, 10, 0, 4)
				mbTitle.Size = UDim2.new(1, -150, 0, 18)

				local mbSub = mkL(modeBar, curIndiv and "Operating under custom unit parameters." or "Sliders below can be customized and saved for this C-RAM.", 8, TEXT_SECONDARY, Enum.TextXAlignment.Left, false)
				mbSub.Position = UDim2.new(0, 10, 0, 22)
				mbSub.Size = UDim2.new(1, -150, 0, 16)

				local switchBtn = mkB(modeBar, curIndiv and "REVERT TO GLOBAL" or "SWITCH TO INDIVIDUAL", UDim2.new(0, 130, 0, 24), UDim2.new(1, -138, 0.5, -12), BG_INPUT, BORDER)
				switchBtn.TextSize = 9
				switchBtn.TextColor3 = curIndiv and CYAN or AMBER
				conn(switchBtn.MouseButton1Click:Connect(function()
					local nextM = curIndiv and "GLOBAL" or "INDIVIDUAL"
					u.config.targetMode = nextM
					u.config.mode = (nextM == "GLOBAL") and "OVERALL" or "INDIVIDUAL"
					pending.targetMode = nextM
					pending.mode = (nextM == "GLOBAL") and "OVERALL" or "INDIVIDUAL"
					sendServer("SetUnitTargetMode", {unitId = id, mode = nextM})
					sendServer("SetUnitMode", {unitId = id, mode = (nextM == "GLOBAL") and "OVERALL" or "INDIVIDUAL"})
					updateFleetUI()
					rebuildConfigPanel()
				end))

				local cfgOrd = 2
				local sHead = mkL(cfgPanel, "Unit Fire Control: Engagement Range", 10, Color3.fromRGB(210, 215, 220), Enum.TextXAlignment.Left, false)
				sHead.Size = UDim2.new(1, 0, 0, 22)
				sHead.LayoutOrder = cfgOrd
				cfgOrd = cfgOrd + 1

				local subS = mkL(cfgPanel, "Configure maximum engagement range for this C-RAM unit. Ballistics locked to standard 20mm HEIT.", 8, TEXT_SECONDARY, Enum.TextXAlignment.Left, false)
				subS.Size = UDim2.new(1, 0, 0, 16)
				subS.LayoutOrder = cfgOrd
				cfgOrd = cfgOrd + 1

				local function addCSlider(name, minVal, maxVal, curVal, isFloat, cb)
					local s = createSlider(cfgPanel, name, minVal, maxVal, curVal, isFloat, cb)
					s.row.LayoutOrder = cfgOrd
					cfgOrd = cfgOrd + 1
					return s
				end

				addCSlider("Max Range (Studs)", 1000, 40000, pending.maxRange, false, function(v) pending.maxRange = v end)

				local saveBtn = mkB(cfgPanel, "Save Unit Settings", UDim2.new(1, 0, 0, 30), nil, BG_CARD, BORDER)
				saveBtn.TextSize = 10
				saveBtn.TextColor3 = TEXT_PRIMARY
				saveBtn.LayoutOrder = 20
				saveBtn.Active = true
				saveBtn.Selectable = true
				saveBtn.ZIndex = 10
				conn(saveBtn.MouseButton1Click:Connect(function()
					playSound("UI_Click")
					local range = math.clamp(math.floor((tonumber(pending.maxRange) or 6000) + 0.5), 1000, 40000)
					pending.maxRange = range
					sendServer("UpdateUnitConfig", {unitId = id, key = "maxRange", value = range})
					sendServer("ApplyUnitConfig", {unitId = id, config = pending})
					for key, value in pairs(pending) do
						if u.config[key] ~= nil then
							u.config[key] = value
						end
					end
					saveBtn.Text = "SETTINGS SAVED"
					saveBtn.TextColor3 = SUCCESS
					task.delay(1.5, function()
						if saveBtn and saveBtn.Parent then
							saveBtn.Text = "Save Unit Settings"
							saveBtn.TextColor3 = TEXT_PRIMARY
						end
					end)
					updateFleetUI()
				end))

				if not curIndiv then
					local syncBox = Instance.new("Frame")
					syncBox.Size = UDim2.new(1, 0, 0, 36)
					syncBox.BackgroundColor3 = BG_PANEL
					syncBox.BorderSizePixel = 0
					syncBox.LayoutOrder = 30
					syncBox.Parent = cfgPanel
					mkS(syncBox, BORDER, 1, 0)
					local sbL = mkL(syncBox, "Target List: Synchronized with Global Tab (Switch to Individual to filter targets)", 9, TEXT_SECONDARY, Enum.TextXAlignment.Center, false)
					sbL.Size = UDim2.new(1, 0, 1, 0)
				else
					local tHead = mkL(cfgPanel, "Individual Target Authorization", 10, Color3.fromRGB(210, 215, 220), Enum.TextXAlignment.Left, false)
					tHead.Size = UDim2.new(1, 0, 0, 22)
					tHead.LayoutOrder = 30

					local uPermContainer = Instance.new("Frame")
					uPermContainer.Name = "UnitPermContainer"
					uPermContainer.Size = UDim2.new(1, 0, 0, 0)
					uPermContainer.AutomaticSize = Enum.AutomaticSize.Y
					uPermContainer.BackgroundColor3 = BG_CARD
					uPermContainer.BorderSizePixel = 0
					uPermContainer.LayoutOrder = 31
					uPermContainer.Parent = cfgPanel
					mkS(uPermContainer, BORDER, 1, 0)

					local uPcLy = Instance.new("UIListLayout")
					uPcLy.SortOrder = Enum.SortOrder.LayoutOrder
					uPcLy.Padding = UDim.new(0, 6)
					uPcLy.Parent = uPermContainer

					renderTargetMatrix(uPermContainer, pending.targetWhitelist, function(updatedList)
						pending.targetWhitelist = updatedList
					end)
				end

				local endGap = Instance.new("Frame")
				endGap.Size = UDim2.new(1, 0, 0, 20)
				endGap.BackgroundTransparency = 1
				endGap.LayoutOrder = 99
				endGap.Parent = cfgPanel
			end

			rebuildConfigPanel()

			conn(cfgBtn.MouseButton1Click:Connect(function()
				local curUnit = cachedState and cachedState.units and cachedState.units[id]
				local curIsIndiv = curUnit and (curUnit.config.targetMode == "INDIVIDUAL" or curUnit.config.mode == "INDIVIDUAL")
				if not curIsIndiv then
					local origText = cfgBtn.Text
					local origColor = cfgBtn.TextColor3
					cfgBtn.Text = "SWITCH TO INDIVIDUAL MODE FIRST"
					cfgBtn.TextColor3 = AMBER
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
				if exp then
					rebuildConfigPanel()
					cfgPanel.Visible = true
					cfgBtn.Text = "[-] CONFIGURE TARGETING & FIRE CONTROL"
				else
					cfgPanel.Visible = false
					cfgBtn.Text = "[+] CONFIGURE TARGETING & FIRE CONTROL"
				end
			end))
		end

		local isOnline = u.config.enabled
		local sc = isOnline and (u.stats.status == "ENGAGING" and Color3.fromRGB(240, 140, 20) or SUCCESS) or Color3.fromRGB(80, 88, 95)
		local sd = card:FindFirstChild("StatusDot")
		if sd then sd.BackgroundColor3 = sc end

		local nn = u.config.nickname ~= "" and u.config.nickname or u.modelName
		local nl = card:FindFirstChild("NameLabel")
		if nl then nl.Text = nn end

		local modeBadge = card:FindFirstChild("ModeBadge")
		if modeBadge then
			modeBadge.BackgroundColor3 = isIndiv and AMBER_DIM or CYAN_DIM
			local bst = modeBadge:FindFirstChildWhichIsA("UIStroke")
			if bst then bst.Color = isIndiv and AMBER or CYAN end
			local bl = modeBadge:FindFirstChild("BadgeLabel")
			if bl then
				bl.Text = isIndiv and "[MODE: INDIVIDUAL]" or "[MODE: GLOBAL]"
				bl.TextColor3 = isIndiv and AMBER or CYAN
			end
		end

		local ar = card:FindFirstChild("ActionRow")
		local mb = ar and ar:FindFirstChild("ModeBtn")
		if mb then
			mb.Text = isIndiv and "[SWITCH TO GLOBAL MODE]" or "[SWITCH TO INDIVIDUAL MODE]"
			mb.TextColor3 = TEXT_SECONDARY
			mb.BackgroundColor3 = BG_INPUT
			local mbs = mb:FindFirstChildWhichIsA("UIStroke")
			if mbs then mbs.Color = BORDER end
		end

		local cfgBtnRef = card:FindFirstChild("CfgBtn")
		if cfgBtnRef and not expandedUnits[id] then
			if isIndiv then
				cfgBtnRef.Text = "[+] CONFIGURE TARGETING & FIRE CONTROL"
				cfgBtnRef.TextColor3 = TEXT_PRIMARY
			else
				cfgBtnRef.Text = "[LOCKED] SWITCH TO INDIVIDUAL TO CONFIGURE"
				cfgBtnRef.TextColor3 = TEXT_DIM
			end
		end

		local stl = card:FindFirstChild("StatusLabel")
		if stl then
			if not isOnline then
				stl.Text = "STANDBY"
				stl.TextColor3 = Color3.fromRGB(80, 88, 95)
			elseif u.stats.status == "ENGAGING" then
				stl.Text = "ENGAGING"
				stl.TextColor3 = Color3.fromRGB(240, 140, 20)
			else
				stl.Text = "ONLINE [IDLE]"
				stl.TextColor3 = SUCCESS
			end
		end

		local tgtLbl = card:FindFirstChild("TargetLabel")
		if tgtLbl then tgtLbl.Text = "TARGET: " .. (u.stats.currentTarget or "NONE") end

		local am = u.config.maxAmmo or 1500
		local ap = am > 0 and math.clamp((u.stats.currentAmmo or 0) / am, 0, 1) or 0
		local ab = card:FindFirstChild("AmmoBar")
		local af = ab and ab:FindFirstChild("AmmoFill")
		if af then
			af.Size = UDim2.new(ap, 0, 1, 0)
			af.BackgroundColor3 = (ap > 0.3) and SUCCESS or ACCENT
		end
	end

	if sl then
		sl.Text = string.format("Units: %d  •  Active: %d  •  Engaging: %d  •  Ammo: %s", uc, uc, eg, formatNum(ta))
	end
end

local function updateWorldOverlays()
	for _, g in ipairs(worldGuis) do
		g:Destroy()
	end
	worldGuis = {}

	local cf = workspace:FindFirstChild("Ciws")
	if cf then
		for _, mdl in ipairs(cf:GetChildren()) do
			if mdl:IsA("Model") then
				local highestY = -math.huge
				local baseComp = mdl:FindFirstChild("BaseComponent")
				for _, part in ipairs(mdl:GetDescendants()) do
					if part:IsA("BasePart") then
						local tipY = part.Position.Y + (part.Size.Y * 0.5)
						if tipY > highestY then highestY = tipY end
					end
				end
				local adorneePart = mdl.PrimaryPart or baseComp or mdl:FindFirstChildWhichIsA("BasePart")
				if adorneePart then
					local anchorY = adorneePart.Position.Y
					local topClearance = math.max(0, highestY - anchorY) + 5
					local bg = Instance.new("BillboardGui")
					bg.Adornee = adorneePart
					bg.Size = UDim2.new(0, 170, 0, 50)
					bg.StudsOffsetWorldSpace = Vector3.new(0, topClearance, 0)
					bg.AlwaysOnTop = true
					bg.LightInfluence = 0
					bg.Parent = workspace.CurrentCamera

					local clickBtn = Instance.new("TextButton")
					clickBtn.Size = UDim2.new(1, 0, 1, 0)
					clickBtn.BackgroundColor3 = BG_PANEL
					clickBtn.BorderSizePixel = 0
					clickBtn.Text = ""
					clickBtn.Parent = bg
					mkC(clickBtn, 3)
					mkS(clickBtn, BORDER_ACCENT, 1, 0.4)

					local unitEntry = nil
					if cachedState and cachedState.units then
						for _, u in pairs(cachedState.units) do
							if u.modelName == mdl.Name then
								unitEntry = u
								break
							end
						end
					end

					local isOnline = true
					if unitEntry and unitEntry.config and unitEntry.config.enabled ~= nil then
						isOnline = unitEntry.config.enabled
					end

					local stxt = isOnline and "SYS_ONLINE [IDLE]" or "SYS_STANDBY"
					local stCol = isOnline and SUCCESS or Color3.fromRGB(80, 88, 95)
					local st = mdl:FindFirstChild("Status")
					if st then
						local tgt = st:FindFirstChild("Target")
						if tgt and tgt.Value and isOnline then
							stxt = "SYS_ENGAGING"
							stCol = Color3.fromRGB(240, 140, 20)
						end
					end

					local titleLbl = mkL(clickBtn, mdl.Name, 10, TEXT_PRIMARY)
					titleLbl.Size = UDim2.new(1, -12, 0, 16)
					titleLbl.Position = UDim2.new(0, 6, 0, 4)
					titleLbl.TextTruncate = Enum.TextTruncate.AtEnd

					local sl2 = mkL(clickBtn, stxt .. " • Configure", 9, stCol)
					sl2.Size = UDim2.new(1, -12, 0, 16)
					sl2.Position = UDim2.new(0, 6, 0, 22)

					conn(clickBtn.MouseButton1Click:Connect(function()
						selectCIWSInFleet(mdl)
					end))

					table.insert(worldGuis, bg)
				end
			end
		end
	end

	local tagged = CollectionService:GetTagged("CRAMTarget")
	for _, tag in ipairs(tagged) do
		if tag:IsA("BoolValue") and tag.Value == true then
			local part = tag:FindFirstChild("TargetPart") and tag.TargetPart.Value or (tag.Parent:IsA("BasePart") and tag.Parent)
			if part and part:IsDescendantOf(workspace) and (not cf or not part:IsDescendantOf(cf)) then
				local bg = Instance.new("BillboardGui")
				bg.Adornee = part
				bg.Size = UDim2.new(0, 36, 0, 36)
				bg.StudsOffsetWorldSpace = Vector3.new(0, math.max(part.Size.Y * 0.5 + 4, 6), 0)
				bg.AlwaysOnTop = true
				bg.LightInfluence = 0
				bg.Parent = workspace.CurrentCamera
				local diamond = mkL(bg, "[X]", 12, ACCENT, Enum.TextXAlignment.Center)
				diamond.Size = UDim2.new(1, 0, 1, 0)
				table.insert(worldGuis, bg)
			end
		end
	end
end

local toggleBtn = sg:FindFirstChild("TogglePanelBtn")
if not toggleBtn then
	toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "TogglePanelBtn"
	toggleBtn.AnchorPoint = Vector2.new(1, 0)
	toggleBtn.Position = UDim2.new(1, -20, 0, 68)
	toggleBtn.Size = UDim2.new(0, 164, 0, 32)
	toggleBtn.BackgroundColor3 = BG_PANEL
	toggleBtn.BorderSizePixel = 0
	toggleBtn.AutoButtonColor = false
	toggleBtn.Text = ""
	toggleBtn.Parent = sg
	mkC(toggleBtn, 4)
	mkS(toggleBtn, BORDER, 1, 0.35)

	local dot = Instance.new("Frame")
	dot.Name = "StatusDot"
	dot.Size = UDim2.new(0, 8, 0, 8)
	dot.Position = UDim2.new(0, 10, 0.5, -4)
	dot.BackgroundColor3 = SUCCESS
	dot.BorderSizePixel = 0
	dot.Parent = toggleBtn
	mkC(dot, 4)

	local title = mkL(toggleBtn, "C2 TERMINAL [OPEN]", 10, TEXT_PRIMARY)
	title.Name = "TitleLabel"
	title.Size = UDim2.new(1, -50, 1, 0)
	title.Position = UDim2.new(0, 24, 0, 0)

	local badge = mkL(toggleBtn, "[M]", 9, TEXT_DIM, Enum.TextXAlignment.Right)
	badge.Name = "Badge"
	badge.Size = UDim2.new(0, 24, 1, 0)
	badge.Position = UDim2.new(1, -28, 0, 0)
end

local function updateToggleBtnState()
	if not toggleBtn then return end
	local dot = toggleBtn:FindFirstChild("StatusDot")
	local tl = toggleBtn:FindFirstChild("TitleLabel")
	if mf.Visible then
		if dot then dot.BackgroundColor3 = SUCCESS end
		if tl then tl.Text = "C-RAM Panel" end
	else
		if dot then dot.BackgroundColor3 = TEXT_DIM end
		if tl then tl.Text = "C-RAM Panel" end
	end
end

local function toggleMainFrame()
	mf.Visible = not mf.Visible
	playSound(mf.Visible and "UI_SlideIn" or "UI_SlideOut")
	updateToggleBtnState()
end

if toggleBtn then
	conn(toggleBtn.MouseButton1Click:Connect(function()
		toggleMainFrame()
	end))
	conn(toggleBtn.MouseEnter:Connect(function()
		tw(toggleBtn, {BackgroundColor3 = ACCENT_DIM}, 0.15)
	end))
	conn(toggleBtn.MouseLeave:Connect(function()
		tw(toggleBtn, {BackgroundColor3 = BG_PANEL}, 0.15)
	end))
end

local closeBtn = hb:FindFirstChild("CloseBtn")
if closeBtn then
	conn(closeBtn.MouseButton1Click:Connect(function()
		mf.Visible = false
		playSound("UI_SlideOut")
		updateToggleBtnState()
	end))
end

local function updateSegmentedModeSwitch(newMode)
	currentMode = newMode
	local mb = targetsTab:FindFirstChild("ModeBar")
	if not mb then return end
	local sBtn = mb:FindFirstChild("BtnSingle")
	local pBtn = mb:FindFirstChild("BtnPerm")
	if sBtn then
		local active = (currentMode == "SINGLE")
		sBtn.BackgroundColor3 = active and Color3.fromRGB(25, 48, 65) or BG_INPUT
		local stroke = sBtn:FindFirstChildWhichIsA("UIStroke")
		if stroke then stroke.Color = active and CYAN or BORDER end
		local l = sBtn:FindFirstChildWhichIsA("TextLabel")
		if l then l.TextColor3 = active and CYAN or TEXT_SECONDARY end
	end
	if pBtn then
		local active = (currentMode == "PERM")
		pBtn.BackgroundColor3 = active and Color3.fromRGB(55, 35, 20) or BG_INPUT
		local stroke = pBtn:FindFirstChildWhichIsA("UIStroke")
		if stroke then stroke.Color = active and WARNING or BORDER end
		local l = pBtn:FindFirstChildWhichIsA("TextLabel")
		if l then l.TextColor3 = active and WARNING or TEXT_SECONDARY end
	end
end

local modeBar = targetsTab:FindFirstChild("ModeBar")
if modeBar then
	local sBtn = modeBar:FindFirstChild("BtnSingle")
	if sBtn then
		sBtn.Text = "Single Target"
		sBtn.Font = FONT_MEDIUM
		sBtn.TextSize = 11
		sBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
		sBtn.BackgroundColor3 = Color3.fromRGB(28, 46, 62)
		local st = sBtn:FindFirstChildWhichIsA("UIStroke")
		if st then
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			st.Color = Color3.fromRGB(55, 110, 155)
		end
		for _, ch in ipairs(sBtn:GetChildren()) do
			if ch:IsA("TextLabel") then ch:Destroy() end
		end
		conn(sBtn.MouseButton1Click:Connect(function()
			updateSegmentedModeSwitch("SINGLE")
		end))
	end

	local pBtn = modeBar:FindFirstChild("BtnPerm")
	if pBtn then
		pBtn.Text = "Target List"
		pBtn.Font = FONT_MEDIUM
		pBtn.TextSize = 11
		pBtn.TextColor3 = Color3.fromRGB(160, 170, 180)
		pBtn.BackgroundColor3 = BG_INPUT
		local st = pBtn:FindFirstChildWhichIsA("UIStroke")
		if st then
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			st.Color = BORDER
		end
		for _, ch in ipairs(pBtn:GetChildren()) do
			if ch:IsA("TextLabel") then ch:Destroy() end
		end
		conn(pBtn.MouseButton1Click:Connect(function()
			updateSegmentedModeSwitch("PERM")
		end))
	end

	local cyclePill = modeBar:FindFirstChild("CyclePill")
	if cyclePill then
		cyclePill.Text = "[R] Switch"
		cyclePill.Font = FONT_MEDIUM
		cyclePill.TextSize = 10
		cyclePill.TextColor3 = Color3.fromRGB(180, 185, 190)
		cyclePill.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
		local st = cyclePill:FindFirstChildWhichIsA("UIStroke")
		if st then
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			st.Color = BORDER
		end
		for _, ch in ipairs(cyclePill:GetChildren()) do
			if ch:IsA("TextLabel") then ch:Destroy() end
		end
		conn(cyclePill.MouseButton1Click:Connect(function()
			local nextM = (currentMode == "SINGLE") and "PERM" or "SINGLE"
			updateSegmentedModeSwitch(nextM)
		end))
	end

	local oldModeLabel = modeBar:FindFirstChild("ModeLabel")
	if oldModeLabel then oldModeLabel:Destroy() end
	local oldToggleBtn = modeBar:FindFirstChild("ModeToggleBtn")
	if oldToggleBtn then oldToggleBtn:Destroy() end
end

local gmb = globalTab:FindFirstChild("GlobalScroll") and globalTab.GlobalScroll:FindFirstChild("MasterControls")
if gmb then
	local bOn = gmb:FindFirstChild("BtnAllOn")
	if bOn then conn(bOn.MouseButton1Click:Connect(function() sendServer("MasterToggleAll", {enabled = true}) end)) end
	local bOff = gmb:FindFirstChild("BtnAllOff")
	if bOff then conn(bOff.MouseButton1Click:Connect(function() sendServer("MasterToggleAll", {enabled = false}) end)) end
	local bOver = gmb:FindFirstChild("BtnAllOverall")
	if bOver then conn(bOver.MouseButton1Click:Connect(function() sendServer("SetAllMode", {mode = "OVERALL"}) end)) end
	local bInd = gmb:FindFirstChild("BtnAllIndiv")
	if bInd then conn(bInd.MouseButton1Click:Connect(function() sendServer("SetAllMode", {mode = "INDIVIDUAL"}) end)) end
	local bRec = gmb:FindFirstChild("BtnRecallAll")
	if bRec then conn(bRec.MouseButton1Click:Connect(function() sendServer("RecallAll", {}) end)) end
	local bRef = gmb:FindFirstChild("BtnRefillAll")
	if bRef then conn(bRef.MouseButton1Click:Connect(function() sendServer("RefillAll", {}) end)) end
end

local hookedClientRemotes = {}
local function hookRemoteListener()
	local remote = getRemote()
	if remote and not hookedClientRemotes[remote] then
		hookedClientRemotes[remote] = true
		conn(remote.OnClientEvent:Connect(function(action, data)
			if action == "FullState" then
				cachedState = data
				renderLiveTargets()
				renderTrace()
				updateTargetsUI()
				updateDeployUI()
				updateFleetUI()
				buildGlobalSlidersOnce()
			end
		end))
	end
end

hookRemoteListener()

local function onEquip()
	hookRemoteListener()
	sg.Enabled = true
	mf.Visible = true
	playSound("Ui_Start/Loading")
	updateToggleBtnState()
	mouse.Icon = "rbxasset://textures/GunCursor.png"
	sendServer("RequestFullState")

	equipSession = equipSession + 1
	local curSession = equipSession

	if renderSteppedConn then
		renderSteppedConn:Disconnect()
		renderSteppedConn = nil
	end

	if hoverHighlight then
		hoverHighlight:Destroy()
		hoverHighlight = nil
	end

	hoverHighlight = Instance.new("Highlight")
	hoverHighlight.FillColor = ACCENT
	hoverHighlight.OutlineColor = Color3.fromRGB(240, 245, 250)
	hoverHighlight.FillTransparency = 0.7
	hoverHighlight.OutlineTransparency = 0.2
	hoverHighlight.Parent = workspace.CurrentCamera

	renderSteppedConn = RunService.RenderStepped:Connect(function(dt)
		if not sg.Enabled or equipSession ~= curSession then return end
		previewAngle = (previewAngle + dt * 25) % 360
		for _, item in ipairs(activePreviews) do
			if item.camera and item.camera.Parent then
				local rad = math.rad(previewAngle)
				local camPos = Vector3.new(math.sin(rad) * item.radius, item.height, math.cos(rad) * item.radius)
				item.camera.CFrame = CFrame.lookAt(camPos, Vector3.zero)
			end
		end

		if placementMode and placementGhost then
			local ray = mouse.UnitRay
			local cp = RaycastParams.new()
			cp.FilterType = Enum.RaycastFilterType.Exclude
			cp.FilterDescendantsInstances = {player.Character, placementGhost}
			local r = workspace:Raycast(ray.Origin, ray.Direction * 5000, cp)
			if r then
				local bc = placementGhost:FindFirstChild("BaseComponent") or placementGhost.PrimaryPart
				if bc then
					local halfHeight = bc.Size.Y * 0.5
					local norm = r.Normal.Unit
					local targetPos = r.Position + norm * halfHeight
					local rotCF = getSurfaceRotation(norm, placementRotation, r.Instance)
					local targetBaseCF = CFrame.new(targetPos) * rotCF
					placementGhost:SetPrimaryPartCFrame(targetBaseCF)
					local isVehicle = r.Instance and (not r.Instance.Anchored)
					local ghostCol = isVehicle and CYAN or SUCCESS
					for _, p in ipairs(placementGhost:GetDescendants()) do
						if p:IsA("BasePart") and p.Color ~= ghostCol then
							p.Color = ghostCol
						end
					end
				end
			end
			if hoverHighlight then hoverHighlight.Adornee = nil end
		else
			local hoverCIWS = getHoverCIWS()
			if hoverCIWS then
				if hoverHighlight then
					hoverHighlight.Adornee = hoverCIWS
					hoverHighlight.FillColor = SUCCESS
				end
			else
				local model = getHoverTarget()
				if hoverHighlight then
					hoverHighlight.Adornee = model
					hoverHighlight.FillColor = ACCENT
				end
			end
		end
	end)

	task.spawn(function()
		while sg.Enabled and equipSession == curSession do
			updateWorldOverlays()
			task.wait(1)
		end
	end)

	task.spawn(function()
		while sg.Enabled and equipSession == curSession do
			sendServer("RequestFullState")
			task.wait(3)
		end
	end)
end

local function onUnequip()
	equipSession = equipSession + 1
	if renderSteppedConn then
		renderSteppedConn:Disconnect()
		renderSteppedConn = nil
	end
	sg.Enabled = false
	mouse.Icon = ""
	stopPlacement()
	if hoverHighlight then
		hoverHighlight:Destroy()
		hoverHighlight = nil
	end
	for _, g in ipairs(worldGuis) do
		g:Destroy()
	end
	worldGuis = {}
end


local function setupTool(t)
	if not t or not t:IsA("Tool") or t.Name ~= TOOL_NAME then return end
	if t:GetAttribute("CRAM_ToolHooked") then return end
	t:SetAttribute("CRAM_ToolHooked", true)
	t.Equipped:Connect(onEquip)
	t.Unequipped:Connect(onUnequip)
	if t.Parent == player.Character then
		onEquip()
	end
end

local bpack = player:WaitForChild("Backpack", 5)
if bpack then
	conn(bpack.ChildAdded:Connect(setupTool))
	for _, ch in ipairs(bpack:GetChildren()) do
		setupTool(ch)
	end
end

conn(player.CharacterAdded:Connect(function(char)
	conn(char.ChildAdded:Connect(setupTool))
	for _, ch in ipairs(char:GetChildren()) do
		setupTool(ch)
	end
	hookRemoteListener()
end))
if player.Character then
	conn(player.Character.ChildAdded:Connect(setupTool))
	for _, ch in ipairs(player.Character:GetChildren()) do
		setupTool(ch)
	end
end

conn(mouse.Button1Down:Connect(function()
	if not sg.Enabled then return end
	if placementMode and placementGhost then
		local ray = mouse.UnitRay
		local cp = RaycastParams.new()
		cp.FilterType = Enum.RaycastFilterType.Exclude
		cp.FilterDescendantsInstances = {player.Character, placementGhost}
		local r = workspace:Raycast(ray.Origin, ray.Direction * 5000, cp)
		if r then
			local hitPart = r.Instance
			local isVehicle = hitPart and (not hitPart.Anchored)
			local relPos = nil
			local relNorm = nil
			if isVehicle then
				relPos = hitPart.CFrame:PointToObjectSpace(r.Position)
				relNorm = hitPart.CFrame:VectorToObjectSpace(r.Normal)
			end

			sendServer("SpawnCIWS", {
				templateName = placementTemplate,
				position = {x = r.Position.X, y = r.Position.Y, z = r.Position.Z},
				normal = {x = r.Normal.X, y = r.Normal.Y, z = r.Normal.Z},
				relativePos = relPos and {x = relPos.X, y = relPos.Y, z = relPos.Z} or nil,
				relativeNorm = relNorm and {x = relNorm.X, y = relNorm.Y, z = relNorm.Z} or nil,
				rotation = placementRotation,
				targetPart = hitPart,
			})
		end
		stopPlacement()
		mf.Visible = true
		return
	end

	local hoverCIWS = getHoverCIWS()
	if hoverCIWS then
		selectCIWSInFleet(hoverCIWS)
		return
	end

	local model = getHoverTarget()
	if model then
		local targetPart = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
		if targetPart then
			if currentMode == "SINGLE" then
				sendServer("TagTarget", targetPart)
			else
				sendServer("TagPerm", targetPart)
			end
		end
	end
end))

conn(UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.G then
		toggleMainFrame()
	elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.T then
		if placementMode and placementGhost then
			placementRotation = (placementRotation + ((input.KeyCode == Enum.KeyCode.T) and -45 or 45)) % 360
			local bc = placementGhost:FindFirstChild("BaseComponent") or placementGhost.PrimaryPart
			if bc then
				local ray = mouse.UnitRay
				local cp = RaycastParams.new()
				cp.FilterType = Enum.RaycastFilterType.Exclude
				cp.FilterDescendantsInstances = {player.Character, placementGhost}
				local r = workspace:Raycast(ray.Origin, ray.Direction * 5000, cp)
				if r then
					local halfHeight = bc.Size.Y * 0.5
					local norm = r.Normal.Unit
					local targetPos = r.Position + norm * halfHeight
					local rotCF = getSurfaceRotation(norm, placementRotation, r.Instance)
					placementGhost:SetPrimaryPartCFrame(CFrame.new(targetPos) * rotCF)
				end
			end
		else
			local nextM = (currentMode == "SINGLE") and "PERM" or "SINGLE"
			updateSegmentedModeSwitch(nextM)
		end
	elseif input.KeyCode == Enum.KeyCode.Q then
		if placementMode then
			stopPlacement()
			mf.Visible = true
		end
	end
end))

renderLiveTargets()
renderTrace()
local traceClear = traceTab:FindFirstChild("TraceClear")
if traceClear then
	conn(traceClear.MouseButton1Click:Connect(function()
		local box = traceTab:FindFirstChild("TraceBox")
		if box then box.Text = "" end
		sendServer("ClearTrace", {})
	end))
end
local traceStore = ReplicatedStorage:FindFirstChild("CRAM_TRACE_LOG")
if traceStore and traceStore:IsA("StringValue") then
	conn(traceStore.Changed:Connect(renderTrace))
end
switchTab("TARGETS")
updateSegmentedModeSwitch("SINGLE")



