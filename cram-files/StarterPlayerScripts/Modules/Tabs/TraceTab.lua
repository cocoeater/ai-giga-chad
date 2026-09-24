-- Modules/Tabs/TraceTab.lua
-- Real-time trace log display and debug stream viewer

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TraceTab = {}

function TraceTab.render(traceBox, header, isDebugEnabled)
	traceBox.TextEditable = false
	traceBox.ShowNativeInput = false
	traceBox.Active = true
	traceBox.Selectable = true
	traceBox.MultiLine = true
	traceBox.TextWrapped = true

	local store = ReplicatedStorage:FindFirstChild("CRAM_TRACE_LOG")
	local logText = store and store:IsA("StringValue") and store.Value or ""
	traceBox.Text = logText ~= "" and logText or "TRACE IDLE\nEnable debug and run a target test."

	if header then
		header.Text = "C-RAM TRACE CONSOLE  •  " .. (isDebugEnabled and "ENABLED" or "DISABLED")
	end
end

return TraceTab
