-- Modules/CRAMClientConfig.lua
-- Central configuration, categories, presets, and color palettes for Master C-RAM Client

local CRAMClientConfig = {}

CRAMClientConfig.TARGET_CATEGORIES = {
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
			"UH-1Y",
		},
	},
	{
		id = "JETS",
		category = "FIXED-WING / COMBAT JETS",
		categoryTag = "COMBAT_JET",
		color = Color3.fromRGB(210, 215, 220),
		items = {
			"F-16C",
			"A-10C",
			"SU-25",
		},
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
			"Mercedes-AMG G36",
		},
	},
	{
		id = "MUNITIONS",
		category = "DRONES & INCOMING MUNITIONS",
		categoryTag = "AIR_DRONE",
		color = Color3.fromRGB(210, 215, 220),
		items = {
			"AIR_DRONE",
			"MISSILES",
			"ARTILLERY_SHELLS",
		},
	},
}

local ALL_PRESET_ITEMS = {}
local PRESET_CATALOG = {}
for _, cat in ipairs(CRAMClientConfig.TARGET_CATEGORIES) do
	table.insert(ALL_PRESET_ITEMS, cat.categoryTag)
	for _, it in ipairs(cat.items) do
		table.insert(ALL_PRESET_ITEMS, it)
		table.insert(PRESET_CATALOG, it)
	end
end

local PRESET_SET = {}
for _, item in ipairs(ALL_PRESET_ITEMS) do
	local clean = string.lower(string.gsub(string.gsub(string.gsub(tostring(item), "%s*#%d+", ""), "%s*%(Clone%)", ""), "_%d+$", ""))
	PRESET_SET[clean] = true
end

CRAMClientConfig.ALL_PRESET_ITEMS = ALL_PRESET_ITEMS
CRAMClientConfig.PRESET_CATALOG = PRESET_CATALOG
CRAMClientConfig.PRESET_SET = PRESET_SET

CRAMClientConfig.COLORS = {
	BG_DARK = Color3.fromRGB(15, 17, 20),
	BG_PANEL = Color3.fromRGB(24, 27, 32),
	BG_CARD = Color3.fromRGB(32, 36, 44),
	BORDER = Color3.fromRGB(50, 56, 68),
	BORDER_ACCENT = Color3.fromRGB(70, 130, 240),
	TEXT_MAIN = Color3.fromRGB(240, 242, 245),
	TEXT_MUTED = Color3.fromRGB(160, 165, 175),
	ACCENT_CYAN = Color3.fromRGB(0, 210, 255),
	ACCENT_GREEN = Color3.fromRGB(50, 205, 90),
	ACCENT_RED = Color3.fromRGB(240, 70, 70),
	ACCENT_AMBER = Color3.fromRGB(255, 180, 50),
}

CRAMClientConfig.SLIDER_CONFIGS = {
	{ id = "range", label = "ENGAGEMENT RANGE (STUDS)", min = 50, max = 5000, default = 2500, isFloat = false },
	{ id = "rpm", label = "FIRE RATE (RPM)", min = 300, max = 6000, default = 4500, isFloat = false },
	{ id = "damage", label = "DAMAGE PER SHOT", min = 5, max = 250, default = 35, isFloat = false },
	{ id = "spread", label = "CONE SPREAD (DEGREES)", min = 0.05, max = 2.0, default = 0.25, isFloat = true },
	{ id = "reloadSec", label = "RELOAD TIME (SECONDS)", min = 1, max = 15, default = 4, isFloat = false },
	{ id = "maxAmmo", label = "MAGAZINE CAPACITY", min = 100, max = 5000, default = 1550, isFloat = false },
}

return CRAMClientConfig
