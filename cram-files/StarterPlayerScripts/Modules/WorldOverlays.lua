-- Modules/WorldOverlays.lua
-- 3D Billboard indicators over CIWS turrets and targets in workspace

local CollectionService = game:GetService("CollectionService")

local WorldOverlays = {}

local worldGuis = {}

function WorldOverlays.clear()
	for _, g in ipairs(worldGuis) do
		g:Destroy()
	end
	worldGuis = {}
end

function WorldOverlays.update(cachedState, onSelectCIWS)
	WorldOverlays.clear()

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
				local adorneePart = mdl.PrimaryPart or (baseComp and baseComp:IsA("BasePart") and baseComp) or mdl:FindFirstChildWhichIsA("BasePart")
				if adorneePart and adorneePart:IsA("BasePart") then
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
					clickBtn.BackgroundColor3 = Color3.fromRGB(24, 27, 32)
					clickBtn.BorderSizePixel = 0
					clickBtn.Text = ""
					clickBtn.Parent = bg

					local s = Instance.new("UIStroke")
					s.Color = Color3.fromRGB(70, 130, 240)
					s.Thickness = 1
					s.Transparency = 0.4
					s.Parent = clickBtn

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
					local stCol = isOnline and Color3.fromRGB(50, 205, 90) or Color3.fromRGB(80, 88, 95)
					local st = mdl:FindFirstChild("Status")
					if st then
						local tgt = st:FindFirstChild("Target")
						if tgt and tgt:IsA("ObjectValue") and tgt.Value and isOnline then
							stxt = "SYS_ENGAGING"
							stCol = Color3.fromRGB(240, 140, 20)
						end
					end

					local titleLbl = Instance.new("TextLabel")
					titleLbl.BackgroundTransparency = 1
					titleLbl.Text = mdl.Name
					titleLbl.Font = Enum.Font.RobotoMono
					titleLbl.TextSize = 10
					titleLbl.TextColor3 = Color3.fromRGB(240, 242, 245)
					titleLbl.Size = UDim2.new(1, -12, 0, 16)
					titleLbl.Position = UDim2.new(0, 6, 0, 4)
					titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
					titleLbl.TextXAlignment = Enum.TextXAlignment.Left
					titleLbl.Parent = clickBtn

					local sl2 = Instance.new("TextLabel")
					sl2.BackgroundTransparency = 1
					sl2.Text = stxt .. " • Configure"
					sl2.Font = Enum.Font.RobotoMono
					sl2.TextSize = 9
					sl2.TextColor3 = stCol
					sl2.Size = UDim2.new(1, -12, 0, 16)
					sl2.Position = UDim2.new(0, 6, 0, 22)
					sl2.TextXAlignment = Enum.TextXAlignment.Left
					sl2.Parent = clickBtn

					clickBtn.MouseButton1Click:Connect(function()
						onSelectCIWS(mdl)
					end)

					table.insert(worldGuis, bg)
				end
			end
		end
	end

	local tagged = CollectionService:GetTagged("CRAMTarget")
	for _, tag in ipairs(tagged) do
		if tag:IsA("BoolValue") and tag.Value == true then
			local partVal = tag:FindFirstChild("TargetPart")
			local part = partVal and partVal:IsA("ObjectValue") and partVal.Value
			if not part and tag.Parent and tag.Parent:IsA("BasePart") then
				part = tag.Parent
			end
			if part and part:IsA("BasePart") and part:IsDescendantOf(workspace) and (not cf or not part:IsDescendantOf(cf)) then
				local bg = Instance.new("BillboardGui")
				bg.Adornee = part
				bg.Size = UDim2.new(0, 36, 0, 36)
				bg.StudsOffsetWorldSpace = Vector3.new(0, math.max(part.Size.Y * 0.5 + 4, 6), 0)
				bg.AlwaysOnTop = true
				bg.LightInfluence = 0
				bg.Parent = workspace.CurrentCamera

				local diamond = Instance.new("TextLabel")
				diamond.BackgroundTransparency = 1
				diamond.Text = "[X]"
				diamond.Font = Enum.Font.RobotoMono
				diamond.TextSize = 12
				diamond.TextColor3 = Color3.fromRGB(240, 70, 70)
				diamond.TextXAlignment = Enum.TextXAlignment.Center
				diamond.Size = UDim2.new(1, 0, 1, 0)
				diamond.Parent = bg

				table.insert(worldGuis, bg)
			end
		end
	end
end

return WorldOverlays
