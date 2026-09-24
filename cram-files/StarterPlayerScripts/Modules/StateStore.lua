-- Modules/StateStore.lua
-- Central state store for Master C-RAM Client

local StateStore = {}

local state = {
	activeTab = "FLEET",
	selectedCIWS = nil,
	toolEquipped = false,
	cachedState = {
		fleet = {},
		targets = {
			detected = {},
			whitelist = {},
			blacklist = {},
			priorities = {},
		},
		globalConfig = {
			enabled = true,
			range = 2500,
			rpm = 4500,
			damage = 35,
			spread = 0.25,
			reloadSec = 4,
			maxAmmo = 1550,
			engagementMode = "ALL",
			coordination = true,
		},
		unitConfigs = {},
		traceLogs = "",
	},
}

local listeners = {}

function StateStore.getState()
	return state
end

function StateStore.getCachedState()
	return state.cachedState
end

function StateStore.setCachedState(newState)
	if type(newState) == "table" then
		for k, v in pairs(newState) do
			state.cachedState[k] = v
		end
		StateStore.dispatch("StateUpdated", state.cachedState)
	end
end

function StateStore.getActiveTab()
	return state.activeTab
end

function StateStore.setActiveTab(tabName)
	if state.activeTab ~= tabName then
		state.activeTab = tabName
		StateStore.dispatch("TabChanged", tabName)
	end
end

function StateStore.getSelectedCIWS()
	return state.selectedCIWS
end

function StateStore.setSelectedCIWS(unit)
	state.selectedCIWS = unit
	StateStore.dispatch("SelectedCIWSChanged", unit)
end

function StateStore.isToolEquipped()
	return state.toolEquipped
end

function StateStore.setToolEquipped(equipped)
	state.toolEquipped = equipped
	StateStore.dispatch("ToolEquippedChanged", equipped)
end

function StateStore.subscribe(event, callback)
	if not listeners[event] then
		listeners[event] = {}
	end
	table.insert(listeners[event], callback)
	return function()
		local list = listeners[event]
		if list then
			for i, cb in ipairs(list) do
				if cb == callback then
					table.remove(list, i)
					break
				end
			end
		end
	end
end

function StateStore.dispatch(event, payload)
	local list = listeners[event]
	if list then
		for _, cb in ipairs(list) do
			task.spawn(cb, payload)
		end
	end
end

return StateStore
