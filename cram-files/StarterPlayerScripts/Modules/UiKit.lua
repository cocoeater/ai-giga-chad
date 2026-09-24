-- Modules/UiKit.lua
-- Pure UI element factory, styling, tweening, and control builders for Master C-RAM

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UiKit = {}

local FONT = Enum.Font.RobotoMono
local FONT_BOLD = Enum.Font.RobotoMono

UiKit.FONT = FONT
UiKit.FONT_BOLD = FONT_BOLD

local connections = {}

function UiKit.conn(c)
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

function UiKit.tw(inst, props, dur, sty, dir)
	local i = TweenInfo.new(dur or 0.22, sty or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local t = TweenService:Create(inst, i, props)
	t:Play()
	return t
end

function UiKit.mkS(parent, col, th, tr)
	local s = Instance.new("UIStroke")
	s.Color = col or Color3.fromRGB(50, 56, 68)
	s.Thickness = th or 1
	s.Transparency = tr or 0
	s.Parent = parent
	return s
end

function UiKit.mkP(parent, t, r, b, l)
	local pd = Instance.new("UIPadding")
	pd.PaddingTop = UDim.new(0, t or 6)
	pd.PaddingRight = UDim.new(0, r or 6)
	pd.PaddingBottom = UDim.new(0, b or 6)
	pd.PaddingLeft = UDim.new(0, l or 6)
	pd.Parent = parent
	return pd
end

function UiKit.mkL(parent, txt, sz, col, xa, isBold)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = txt or ""
	l.Font = isBold and FONT_BOLD or FONT
	l.TextSize = sz or 11
	l.TextColor3 = col or Color3.fromRGB(240, 242, 245)
	l.TextStrokeTransparency = 1
	l.TextXAlignment = xa or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

function UiKit.mkB(parent, txt, sz, pos, bgCol, strokeCol)
	local b = Instance.new("TextButton")
	b.Text = txt or ""
	b.Font = FONT_BOLD
	b.TextSize = 10
	b.TextColor3 = Color3.fromRGB(240, 242, 245)
	b.BackgroundColor3 = bgCol or Color3.fromRGB(32, 36, 44)
	b.BorderSizePixel = 0
	b.Size = sz or UDim2.new(0, 100, 0, 26)
	if pos then b.Position = pos end
	b.AutoButtonColor = false
	b.TextStrokeTransparency = 1
	b.Parent = parent
	if strokeCol then UiKit.mkS(b, strokeCol, 1, 0) end
	b.MouseEnter:Connect(function()
		UiKit.tw(b, { BackgroundColor3 = Color3.fromRGB(45, 52, 64) }, 0.15)
	end)
	b.MouseLeave:Connect(function()
		UiKit.tw(b, { BackgroundColor3 = bgCol or Color3.fromRGB(32, 36, 44) }, 0.15)
	end)
	return b
end

function UiKit.formatNum(n)
	local left, num, right = string.match(tostring(math.floor(n)), "^([^%d]*%d)(%d*)(.-)$")
	return left .. (num:gsub("(%d%d%d)", ",%1")) .. right
end

function UiKit.createSlider(parent, labelText, minVal, maxVal, curVal, isFloat, onValChanged)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 46)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local lbl = UiKit.mkL(row, labelText, 11, Color3.fromRGB(160, 165, 175))
	lbl.Size = UDim2.new(0.65, 0, 0, 16)
	lbl.Position = UDim2.new(0, 0, 0, 0)

	local formatStr = isFloat and "%.2f" or "%d"
	local valLbl = UiKit.mkL(row, string.format(formatStr, curVal), 11, Color3.fromRGB(240, 242, 245), Enum.TextXAlignment.Right)
	valLbl.Size = UDim2.new(0.35, 0, 0, 16)
	valLbl.Position = UDim2.new(0.65, 0, 0, 0)

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 8)
	track.Position = UDim2.new(0, 0, 0, 26)
	track.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
	track.BorderSizePixel = 0
	track.Active = true
	track.Parent = row

	local tst = Instance.new("UIStroke")
	tst.Color = Color3.fromRGB(50, 56, 68)
	tst.Thickness = 1
	tst.Parent = track

	local pct = math.clamp((curVal - minVal) / (maxVal - minVal), 0, 1)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(pct, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 210, 255)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 10, 0, 18)
	knob.Position = UDim2.new(pct, -5, 0.5, -9)
	knob.BackgroundColor3 = Color3.fromRGB(240, 242, 245)
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

	UiKit.conn(track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDown = true
			updateFromInput(input)
		end
	end))

	UiKit.conn(UserInputService.InputChanged:Connect(function(input)
		if isDown and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateFromInput(input)
		end
	end))

	UiKit.conn(UserInputService.InputEnded:Connect(function(input)
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
		end,
	}
end

function UiKit.createToggle(parent, labelText, curVal, onToggled)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local lbl = UiKit.mkL(row, labelText, 11, Color3.fromRGB(160, 165, 175))
	lbl.Size = UDim2.new(0.7, 0, 1, 0)
	lbl.Position = UDim2.new(0, 0, 0, 0)

	local btn = UiKit.mkB(row, curVal and "[ACTIVE]" or "[STANDBY]", UDim2.new(0, 88, 0, 26), UDim2.new(1, -88, 0, 4), curVal and Color3.fromRGB(24, 48, 62) or Color3.fromRGB(20, 23, 28), curVal and Color3.fromRGB(0, 210, 255) or Color3.fromRGB(50, 56, 68))
	btn.TextSize = 10

	local state = curVal
	UiKit.conn(btn.MouseButton1Click:Connect(function()
		state = not state
		btn.Text = state and "[ACTIVE]" or "[STANDBY]"
		btn.BackgroundColor3 = state and Color3.fromRGB(24, 48, 62) or Color3.fromRGB(20, 23, 28)
		onToggled(state)
	end))

	return {
		row = row,
		setState = function(s)
			state = s
			btn.Text = state and "[ACTIVE]" or "[STANDBY]"
			btn.BackgroundColor3 = state and Color3.fromRGB(24, 48, 62) or Color3.fromRGB(20, 23, 28)
		end,
	}
end

function UiKit.makeWindowDraggable(win, dragBar, onDragCallback, onReleaseCallback)
	local dragging = false
	local dragStart = Vector3.zero
	local startPos = UDim2.new()

	dragBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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

return UiKit
