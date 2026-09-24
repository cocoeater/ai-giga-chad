-- Modules/Tabs/TargetMatrixTab.lua
-- Whitelist matrix renderer and category filtering grid

local UiKit = require(script.Parent.Parent.UiKit)
local CRAMClientConfig = require(script.Parent.Parent.CRAMClientConfig)

local TargetMatrixTab = {}

local TARGET_CATEGORIES = CRAMClientConfig.TARGET_CATEGORIES
local COLORS = CRAMClientConfig.COLORS

function TargetMatrixTab.render(parentContainer, whitelist, onToggleCallback)
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

	local authAllGlobalBtn = UiKit.mkB(topBar, "ENGAGE ALL (Shoot)", UDim2.new(0.5, -4, 0, 24), UDim2.new(0, 0, 0, 2), Color3.fromRGB(15, 45, 25), Color3.fromRGB(50, 205, 90))
	authAllGlobalBtn.TextSize = 9
	authAllGlobalBtn.TextColor3 = Color3.fromRGB(50, 205, 90)

	local filtAllGlobalBtn = UiKit.mkB(topBar, "IGNORE ALL (Safe)", UDim2.new(0.5, -4, 0, 24), UDim2.new(0.5, 4, 0, 2), Color3.fromRGB(45, 15, 15), Color3.fromRGB(240, 70, 70))
	filtAllGlobalBtn.TextSize = 9
	filtAllGlobalBtn.TextColor3 = Color3.fromRGB(240, 70, 70)

	local itemRefs = {}

	local function isItemAllowed(name)
		return table.find(whitelist, name) ~= nil
	end

	local layoutOrder = 2

	for _, cat in ipairs(TARGET_CATEGORIES) do
		local catBox = Instance.new("Frame")
		catBox.Name = "CatBox_" .. cat.id
		catBox.Size = UDim2.new(1, 0, 0, 34 + (#cat.items * 30))
		catBox.BackgroundColor3 = COLORS.BG_CARD
		catBox.BorderSizePixel = 0
		catBox.LayoutOrder = layoutOrder
		catBox.Parent = parentContainer
		UiKit.mkS(catBox, COLORS.BORDER, 1, 0)
		layoutOrder = layoutOrder + 1

		local catHeader = Instance.new("Frame")
		catHeader.Size = UDim2.new(1, 0, 0, 28)
		catHeader.BackgroundColor3 = COLORS.BG_PANEL
		catHeader.BorderSizePixel = 0
		catHeader.Parent = catBox
		UiKit.mkS(catHeader, COLORS.BORDER, 1, 0)

		local catTitle = UiKit.mkL(catHeader, cat.category .. " (" .. tostring(#cat.items) .. ")", 10, Color3.fromRGB(210, 215, 220), Enum.TextXAlignment.Left, false)
		catTitle.Size = UDim2.new(0.55, 0, 1, 0)
		catTitle.Position = UDim2.new(0, 8, 0, 0)

		local catAuth = UiKit.mkB(catHeader, "ENGAGE ALL", UDim2.new(0, 75, 0, 20), UDim2.new(1, -165, 0.5, -10), Color3.fromRGB(15, 45, 25), Color3.fromRGB(50, 205, 90))
		catAuth.TextSize = 8
		catAuth.TextColor3 = Color3.fromRGB(50, 205, 90)

		local catFilt = UiKit.mkB(catHeader, "IGNORE ALL", UDim2.new(0, 75, 0, 20), UDim2.new(1, -82, 0.5, -10), Color3.fromRGB(45, 15, 15), Color3.fromRGB(240, 70, 70))
		catFilt.TextSize = 8
		catFilt.TextColor3 = Color3.fromRGB(240, 70, 70)

		catAuth.MouseButton1Click:Connect(function()
			for _, item in ipairs(cat.items) do
				if not table.find(whitelist, item) then table.insert(whitelist, item) end
				local refs = itemRefs[item]
				if refs then
					refs.dot.BackgroundColor3 = Color3.fromRGB(50, 205, 90)
					refs.btn.Text = "ENGAGE (Shoot)"
					refs.btn.BackgroundColor3 = Color3.fromRGB(15, 45, 25)
					refs.btn.TextColor3 = Color3.fromRGB(50, 205, 90)
				end
			end
			if not table.find(whitelist, cat.categoryTag) then table.insert(whitelist, cat.categoryTag) end
			if onToggleCallback then onToggleCallback(whitelist) end
		end)

		catFilt.MouseButton1Click:Connect(function()
			for _, item in ipairs(cat.items) do
				local idx = table.find(whitelist, item)
				if idx then table.remove(whitelist, idx) end
				local refs = itemRefs[item]
				if refs then
					refs.dot.BackgroundColor3 = Color3.fromRGB(80, 88, 95)
					refs.btn.Text = "IGNORE (Safe)"
					refs.btn.BackgroundColor3 = COLORS.BG_PANEL
					refs.btn.TextColor3 = COLORS.TEXT_MUTED
				end
			end
			local catIdx = table.find(whitelist, cat.categoryTag)
			if catIdx then table.remove(whitelist, catIdx) end
			if onToggleCallback then onToggleCallback(whitelist) end
		end)

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
			row.BackgroundColor3 = COLORS.BG_PANEL
			row.BorderSizePixel = 0
			row.LayoutOrder = idx
			row.Parent = itemContainer
			UiKit.mkS(row, COLORS.BORDER, 1, 0)

			local dot = Instance.new("Frame")
			dot.Size = UDim2.new(0, 6, 0, 6)
			dot.Position = UDim2.new(0, 10, 0.5, -3)
			dot.BackgroundColor3 = allowed and Color3.fromRGB(50, 205, 90) or Color3.fromRGB(80, 88, 95)
			dot.BorderSizePixel = 0
			dot.Parent = row

			local nameLbl = UiKit.mkL(row, item, 10, COLORS.TEXT_MAIN, Enum.TextXAlignment.Left, false)
			nameLbl.Size = UDim2.new(0.6, 0, 1, 0)
			nameLbl.Position = UDim2.new(0, 24, 0, 0)

			local toggleBtn = UiKit.mkB(
				row,
				allowed and "ENGAGE (Shoot)" or "IGNORE (Safe)",
				UDim2.new(0, 120, 0, 22),
				UDim2.new(1, -126, 0.5, -11),
				allowed and Color3.fromRGB(15, 45, 25) or COLORS.BG_CARD,
				allowed and Color3.fromRGB(50, 205, 90) or COLORS.BORDER
			)
			toggleBtn.TextSize = 8
			toggleBtn.TextColor3 = allowed and Color3.fromRGB(50, 205, 90) or COLORS.TEXT_MUTED

			itemRefs[item] = { dot = dot, btn = toggleBtn }

			toggleBtn.MouseButton1Click:Connect(function()
				local curIdx = table.find(whitelist, item)
				if curIdx then
					table.remove(whitelist, curIdx)
					dot.BackgroundColor3 = Color3.fromRGB(80, 88, 95)
					toggleBtn.Text = "IGNORE (Safe)"
					toggleBtn.BackgroundColor3 = COLORS.BG_CARD
					toggleBtn.TextColor3 = COLORS.TEXT_MUTED
				else
					table.insert(whitelist, item)
					dot.BackgroundColor3 = Color3.fromRGB(50, 205, 90)
					toggleBtn.Text = "ENGAGE (Shoot)"
					toggleBtn.BackgroundColor3 = Color3.fromRGB(15, 45, 25)
					toggleBtn.TextColor3 = Color3.fromRGB(50, 205, 90)
				end
				if onToggleCallback then onToggleCallback(whitelist) end
			end)
		end
	end

	authAllGlobalBtn.MouseButton1Click:Connect(function()
		for _, cat in ipairs(TARGET_CATEGORIES) do
			for _, item in ipairs(cat.items) do
				if not table.find(whitelist, item) then table.insert(whitelist, item) end
				local refs = itemRefs[item]
				if refs then
					refs.dot.BackgroundColor3 = Color3.fromRGB(50, 205, 90)
					refs.btn.Text = "ENGAGE (Shoot)"
					refs.btn.BackgroundColor3 = Color3.fromRGB(15, 45, 25)
					refs.btn.TextColor3 = Color3.fromRGB(50, 205, 90)
				end
			end
			if not table.find(whitelist, cat.categoryTag) then table.insert(whitelist, cat.categoryTag) end
		end
		if onToggleCallback then onToggleCallback(whitelist) end
	end)

	filtAllGlobalBtn.MouseButton1Click:Connect(function()
		table.clear(whitelist)
		for _, cat in ipairs(TARGET_CATEGORIES) do
			for _, item in ipairs(cat.items) do
				local refs = itemRefs[item]
				if refs then
					refs.dot.BackgroundColor3 = Color3.fromRGB(80, 88, 95)
					refs.btn.Text = "IGNORE (Safe)"
					refs.btn.BackgroundColor3 = COLORS.BG_CARD
					refs.btn.TextColor3 = COLORS.TEXT_MUTED
				end
			end
		end
		if onToggleCallback then onToggleCallback(whitelist) end
	end)
end

return TargetMatrixTab
