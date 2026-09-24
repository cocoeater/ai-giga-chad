local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Registry = require(game:GetService("ServerScriptService"):WaitForChild("CRAMRegistry"))
local RadarAPI = require(game:GetService("ServerScriptService"):WaitForChild("RadarAPI"))
RadarAPI.registerSystem("MasterCRAM", {})
local TOOL_NAME = "Master C-RAM"
local function getCiwsFolder()
	local f = workspace:FindFirstChild("Ciws")
	if not f or not f.Parent then
		f = Instance.new("Folder")
		f.Name = "Ciws"
		f.Parent = workspace
	end
	return f
end
local function getTemplatesFolder()
	return ReplicatedStorage:WaitForChild("CIWSTemplates", 10) or ReplicatedStorage:FindFirstChild("CIWSTemplates")
end
local traceStore = ReplicatedStorage:FindFirstChild("CRAM_TRACE_LOG")
if not traceStore then
	traceStore = Instance.new("StringValue")
	traceStore.Name = "CRAM_TRACE_LOG"
	traceStore.Value = ""
	traceStore.Parent = ReplicatedStorage
end
local debugFlag = ReplicatedStorage:FindFirstChild("CRAM_DEBUG")
if not debugFlag then
	debugFlag = Instance.new("BoolValue")
	debugFlag.Name = "CRAM_DEBUG"
	debugFlag.Value = true
	debugFlag.Parent = ReplicatedStorage
end
local function trace(...)
	if not debugFlag.Value then return end
	local args = {...}
	for i, v in ipairs(args) do args[i] = tostring(v) end
	local msg = table.concat(args, " ")
	pcall(function()
		local newVal = msg .. "\n" .. traceStore.Value
		if string.len(newVal) > 50000 then
			newVal = string.sub(newVal, 1, 50000)
		end
		traceStore.Value = newVal
	end)
end
RadarAPI.setLogger(trace)
local permFolder = ReplicatedStorage:FindFirstChild("CRAM_PermTargets")
if not permFolder then
	permFolder = Instance.new("Folder")
	permFolder.Name = "CRAM_PermTargets"
	permFolder.Parent = ReplicatedStorage
end
local activeSingleTargets = {}
local cachedDetectedVehicles = {}
local detectedDirty = true
local activePermTargets = {}
local hookedRemotes = {}
local stateCache = nil
local stateCacheTime = 0
local function hasToolOwned(player)
	if not player then return false end
	if player.Character and player.Character:FindFirstChild(TOOL_NAME) then return true end
	local bp = player:FindFirstChild("Backpack")
	if bp and bp:FindFirstChild(TOOL_NAME) then return true end
	return false
end
local hasToolEquipped = hasToolOwned
local function getEntry(unitId)
	local entry = Registry.getUnit(unitId)
	if entry then return entry end
	local folder = workspace:FindFirstChild("Ciws")
	if not folder then return nil end
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("CramUnitId") == unitId then
			local freshId = Registry.registerUnit(model)
			return freshId and Registry.getUnit(freshId) or nil
		end
	end
	return nil
end
local function getRemote(player)
	if not player then return nil end
	local char = player.Character
	if char then
		local t = char:FindFirstChild(TOOL_NAME)
		if t and t:FindFirstChild("MasterRemote") then
			return t.MasterRemote
		end
	end
	local bp = player:FindFirstChild("Backpack")
	if bp then
		local t = bp:FindFirstChild(TOOL_NAME)
		if t and t:FindFirstChild("MasterRemote") then
			return t.MasterRemote
		end
	end
	return nil
end
local function getCleanSignatureTokens(model)
	local tokens = {}
	local ignored = {
		Part = true, MeshPart = true, WedgePart = true, Model = true, Folder = true, Attachment = true, Script = true,
		LocalScript = true, Weld = true, WeldConstraint = true, Motor6D = true, BodyVelocity = true, BodyGyro = true,
		AlignPosition = true, AlignOrientation = true, PointLight = true, SpotLight = true, SurfaceLight = true,
		ParticleEmitter = true, Trail = true, Beam = true, Sound = true, EqualizerSoundEffect = true,
		CanBeTargetted = true, TargetPart = true, TargetType = true, VoidTag = true, MainModel = true, CRAMTarget = true,
		Mesh = true, Texture = true, Animation = true, Animator = true, a = true, e = true
	}
	for _, desc in ipairs(model:GetDescendants()) do
		local n = desc.Name
		if not ignored[n] and n ~= model.Name and string.len(n) > 1 then
			if not table.find(tokens, n) then
				table.insert(tokens, n)
			end
		end
	end
	table.sort(tokens)
	return tokens
end
local function cleanModelName(rawName)
	local n = string.gsub(rawName, "%s*#%d+", "")
	n = string.gsub(n, "%s*%(Clone%)", "")
	n = string.gsub(n, "%s*%(%d+%)", "")
	n = string.gsub(n, "_%d+$", "")
	return n
end

local function isWorldModel(model)
	if not model then return true end
	if model == workspace then return true end
	local node = model
	while node and node ~= workspace do
		local key = string.lower(node.Name or "")
		key = string.gsub(key, "[%s%-_]+", "")
		if key == "map" or key == "baseplate" or key == "terrain" or key == "scenery" 
			or key == "environment" or key == "smallcity" or key == "city" or key == "town" 
			or key == "world" or key == "buildings" or key == "building" or key == "roads" 
			or key == "ground" or key == "nature" or key == "props" or key == "spawns" 
			or key == "structure" or key == "structures"
			or string.find(key, "map", 1, true) == 1 
			or string.find(key, "scenery", 1, true) == 1 
			or string.find(key, "environment", 1, true) == 1 
			or string.find(key, "city", 1, true) == 1 
			or string.find(key, "town", 1, true) == 1
			or string.find(key, "terrain", 1, true) == 1 then
			return true
		end
		node = node.Parent
	end
	return false
end

local function getVehicleRootModel(part)
	if not part then return nil end
	if isWorldModel(part) then return nil end
	local cur = part:IsA("Model") and part or part:FindFirstAncestorOfClass("Model")
	if not cur or isWorldModel(cur) then return nil end
	local topModel = cur
	local node = cur
	while node and node.Parent and node.Parent ~= workspace do
		local p = node.Parent
		if isWorldModel(p) then
			if p.Parent == workspace and p.Name == "Model" and (p:IsA("Model") or p:IsA("Folder")) then
				topModel = node
				break
			end
			return nil
		end
		if Players:GetPlayerFromCharacter(p) then
			topModel = node
			break
		end
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
	if isWorldModel(topModel) then return nil end
	return topModel
end

local function resolveVehicleModel(part)
	if not part then return nil end
	if RadarAPI and RadarAPI.scan then
		for _, entry in ipairs(RadarAPI.scan()) do
			if entry.model == part or entry.targetPart == part or (entry.model and part:IsDescendantOf(entry.model)) then
				return entry.model
			end
		end
	end
	return getVehicleRootModel(part)
end
local RADAR_PROFILE_LABELS = {
	Helicopter = "HELICOPTER",
	CombatJet = "COMBAT JET",
}

local function getVehicleClassification(model)
	if not model then return "UNCATEGORIZED" end
	local profileName = RadarAPI.classify(model)
	if RADAR_PROFILE_LABELS[profileName] then
		return RADAR_PROFILE_LABELS[profileName]
	end
	local lowName = string.lower(model.Name)
	if model:FindFirstChild("A-Chassis Tune", true) or model:FindFirstChildWhichIsA("VehicleSeat", true) or model:FindFirstChild("DriveSeat", true) or model:FindFirstChild("Drive", true) or model:FindFirstChild("CarRegenScript", true) then
		return "GROUND VEHICLE"
	end
	if string.find(lowName, "drone", 1, true) or string.find(lowName, "uav", 1, true) then
		return "AIR DRONE"
	end
	return "TARGET CRAFT"
end
local function isPermTargetMatch(model, permRuleFolder)
	if not model or not model:IsA("Model") or not permRuleFolder then return false end
	local cleanName = cleanModelName(model.Name)
	local ruleName = permRuleFolder.Name
	local ruleClean = cleanModelName(ruleName)

	local lowModel = string.lower(cleanName)
	local lowRule = string.lower(ruleClean)
	local normModel = string.gsub(lowModel, "[%s%-_]", "")
	local normRule = string.gsub(lowRule, "[%s%-_]", "")

	local nameMatches = (lowModel == lowRule) 
		or (normModel == normRule) 
		or (string.find(lowModel, lowRule, 1, true) ~= nil) 
		or (string.find(lowRule, lowModel, 1, true) ~= nil)
		or (string.find(normModel, normRule, 1, true) ~= nil)

	local sigVal = permRuleFolder:FindFirstChild("Fingerprint")
	local sigString = sigVal and sigVal.Value or ""
	if sigString == "" then
		return nameMatches
	end

	local regTokens = string.split(sigString, ",")
	if #regTokens == 0 then return nameMatches end

	local modelTokens = getCleanSignatureTokens(model)
	local matches = 0
	for _, rt in ipairs(regTokens) do
		local rClean = string.gsub(rt, "^%s*(.-)%s*$", "%1")
		if table.find(modelTokens, rClean) then
			matches = matches + 1
		end
	end

	local matchRatio = matches / #regTokens
	if nameMatches then
		return (#regTokens <= 2) or (matchRatio >= 0.35)
	else
		return (#regTokens >= 4) and (matchRatio >= 0.7)
	end
end
local function applyTag(targetPart, isPerm)
	local mdl = resolveVehicleModel(targetPart) or targetPart
	if mdl == targetPart then
		local current = targetPart
		for i = 1, 10 do
			if current and current.Parent and current.Parent:IsA("Model") then
				current = current.Parent
				if current.Name == "Map" or current.Name == "Workspace" or current == workspace then break end
				if current:FindFirstChildOfClass("Humanoid") or current:FindFirstChild("Durability") or current:FindFirstChild("Health") or current:FindFirstChild("Arsenal") or current:FindFirstChild("Damage", true) then
					mdl = current
					break
				end
			else
				break
			end
		end
	end
	if mdl == targetPart then
		local current = targetPart
		for i = 1, 10 do
			if current and current.Parent and current.Parent:IsA("Model") then
				current = current.Parent
				if current.Name == "Map" or current.Name == "Workspace" or current == workspace then break end
				if current:FindFirstChild("Durability", true) or current:FindFirstChild("Health", true) or current:FindFirstChild("Arsenal", true) or current:FindFirstChild("Damage", true) then
					mdl = current
					break
				end
			else
				break
			end
		end
	end
	if mdl == targetPart then return false end
	local bestPart = targetPart
	if mdl:IsA("Model") then
		local hrp = mdl:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			bestPart = hrp
		else
			local dur = mdl:FindFirstChild("Durability", true) or mdl:FindFirstChild("Health", true) or mdl:FindFirstChild("Arsenal", true) or mdl:FindFirstChild("Damage", true)
			if dur and dur.Parent and dur.Parent:IsA("BasePart") then
				bestPart = dur.Parent
			elseif mdl.PrimaryPart then
				bestPart = mdl.PrimaryPart
			end
		end
	end
	targetPart = bestPart
	targetPart:SetAttribute("ManualTarget", isPerm ~= true)
	local existingTag = targetPart:FindFirstChild("CanBeTargetted")
	if existingTag and existingTag:IsA("BoolValue") then
		existingTag.Value = true
		existingTag:SetAttribute("CRAMDisabled", nil)
		if existingTag:GetAttribute("CRAMCreated") == nil then existingTag:SetAttribute("CRAMCreated", false) end
		local vt = existingTag:FindFirstChild("VoidTag")
		if not vt then
			vt = Instance.new("StringValue")
			vt.Name = "VoidTag"
			vt.Value = "Enemy"
			vt.Parent = existingTag
		end
		local tt = existingTag:FindFirstChild("TargetType")
		if not tt then
			tt = Instance.new("StringValue")
			tt.Name = "TargetType"
			local className = getVehicleClassification(mdl)
			tt.Value = string.find(className, "GROUND", 1, true) and "GroundVehicle" or "Aircraft"
			tt.Parent = existingTag
		end
		local mm = existingTag:FindFirstChild("MainModel")
		if not mm then
			mm = Instance.new("ObjectValue")
			mm.Name = "MainModel"
			mm.Value = mdl
			mm.Parent = existingTag
		end
		local tp = existingTag:FindFirstChild("TargetPart")
		if not tp then
			tp = Instance.new("ObjectValue")
			tp.Name = "TargetPart"
			tp.Value = targetPart
			tp.Parent = existingTag
		end
		CollectionService:AddTag(existingTag, "CRAMTarget")
		if isPerm then
			activePermTargets[targetPart] = mdl.Name
		else
			activeSingleTargets[targetPart] = mdl.Name
		end
		return true
	end
	local tag = Instance.new("BoolValue")
	tag.Name = "CanBeTargetted"
	tag.Value = true
	tag:SetAttribute("CRAMCreated", true)
	local tType = Instance.new("StringValue")
	tType.Name = "TargetType"
	local className = getVehicleClassification(mdl)
	tType.Value = string.find(className, "GROUND", 1, true) and "GroundVehicle" or "Aircraft"
	tType.Parent = tag
	local vTag = Instance.new("StringValue")
	vTag.Name = "VoidTag"
	vTag.Value = "Enemy"
	vTag.Parent = tag
	local mModel = Instance.new("ObjectValue")
	mModel.Name = "MainModel"
	mModel.Value = mdl
	mModel.Parent = tag
	local tPart = Instance.new("ObjectValue")
	tPart.Name = "TargetPart"
	tPart.Value = targetPart
	tPart.Parent = tag
	tag.Parent = targetPart
	CollectionService:AddTag(tag, "CRAMTarget")
	if isPerm then
		activePermTargets[targetPart] = mdl.Name
	else
		activeSingleTargets[targetPart] = mdl.Name
	end
	return true
end
local function removeTag(targetPart)
	if not targetPart then return end
	local model = resolveVehicleModel(targetPart) or (targetPart:IsA("Model") and targetPart or targetPart:FindFirstAncestorOfClass("Model")) or targetPart
	for _, tag in ipairs(CollectionService:GetTagged("CRAMTarget")) do
		if tag:IsDescendantOf(model) then
			if tag:GetAttribute("CRAMCreated") == true then
				tag:Destroy()
			else
				tag:SetAttribute("CRAMDisabled", true)
				CollectionService:RemoveTag(tag, "CRAMTarget")
			end
		end
	end
	activeSingleTargets[targetPart] = nil
	activePermTargets[targetPart] = nil
	targetPart:SetAttribute("ManualTarget", nil)
end
local function clearPermTargets(items)
	local names = {}
	for _, item in ipairs(items) do
		if type(item) == "string" then
			names[cleanModelName(item)] = true
		end
	end
	for cleanName in pairs(names) do
		local rule = permFolder:FindFirstChild(cleanName)
		if rule then
			rule:Destroy()
		end
	end
	local parts = {}
	for part, targetName in pairs(activePermTargets) do
		if names[cleanModelName(targetName)] then
			table.insert(parts, part)
		end
	end
	for _, part in ipairs(parts) do
		removeTag(part)
	end
	for _, tag in ipairs(CollectionService:GetTagged("CRAMTarget")) do
		local modelValue = tag:FindFirstChild("MainModel")
		local model = modelValue and modelValue.Value
		local part = tag.Parent
		if model and part and part:IsA("BasePart") and names[cleanModelName(model.Name)] then
			removeTag(part)
		end
	end
end
local function removePermTarget(name)
	clearPermTargets({name})
end
local function removePermBatch(items)
	clearPermTargets(items)
end
local function isLiveCIWSModel(m)
	if not m or not m:IsA("Model") then return false end
	if not m:FindFirstChild("Configurations") or not m:FindFirstChild("BaseComponent") then return false end
	return true
end
local function getNextUnitNumber(baseName)
	local used = {}
	local cleanBase = cleanModelName(baseName)
	local f = getCiwsFolder()
	for _, ch in ipairs(f:GetChildren()) do
		if ch:IsA("Model") and cleanModelName(ch.Name) == cleanBase then
			local num = ch.Name:match("#(%d+)$")
			if num then
				used[tonumber(num)] = true
			end
		end
	end
	local n = 1
	while used[n] do
		n = n + 1
	end
	return n
end
local function registerLiveUnit(m)
	if not isLiveCIWSModel(m) then return end
	local cleanBase = cleanModelName(m.Name)
	local duplicate = false
	local folder = getCiwsFolder()
	for index,item in ipairs(folder:GetChildren()) do
		if item ~= m and item:IsA("Model") and item.Name == m.Name then
			duplicate = true
			break
		end
	end
	if duplicate or not m.Name:match("#%d+$") or m.Name:match("#%d+%s+#%d+$") then
		m.Name = cleanBase .. " #" .. getNextUnitNumber(cleanBase)
	end
	Registry.registerUnit(m)
end
local function scanAllLiveUnits()
	local f = getCiwsFolder()
	for _, child in ipairs(f:GetChildren()) do
		registerLiveUnit(child)
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model") and child.Name ~= "Ciws" and isLiveCIWSModel(child) then
			child.Parent = f
			registerLiveUnit(child)
		end
	end
end
local function getBestTargetPart(model: Model)
	if not model or not model:IsA("Model") then return nil end
	local _, profile = RadarAPI.classify(model)
	local radarPart = profile.getBestTargetPart(model)
	if radarPart then return radarPart end
	local hBox = model:FindFirstChild("DamageHBox", true) or model:FindFirstChild("BulletHitbox", true) or model:FindFirstChild("RotorHitbox", true)
	if hBox and hBox:IsA("BasePart") then return hBox end
	local vSeat = model:FindFirstChildWhichIsA("VehicleSeat", true)
	if vSeat then return vSeat end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then return model.PrimaryPart end
	for _, name in ipairs({"Fuselage", "MAIN", "Main", "Body", "Center", "Cockpit", "Engine", "Hull", "Chassis"}) do
		local found = model:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then return found end
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function registerPermTarget(cleanName, modelToFingerprint, scanNow)
	local ruleFolder = permFolder:FindFirstChild(cleanName)
	if not ruleFolder then
		ruleFolder = Instance.new("Folder")
		ruleFolder.Name = cleanName
		ruleFolder.Parent = permFolder
	end
	local tokens = {}
	local vType = "VEHICLE"
	if modelToFingerprint then
		tokens = getCleanSignatureTokens(modelToFingerprint)
		vType = getVehicleClassification(modelToFingerprint)
	end
	local fp = ruleFolder:FindFirstChild("Fingerprint")
	if not fp then
		fp = Instance.new("StringValue")
		fp.Name = "Fingerprint"
		fp.Parent = ruleFolder
	end
	if #tokens > 0 then
		fp.Value = table.concat(tokens, ",")
	end
	local dn = ruleFolder:FindFirstChild("DisplayName")
	if not dn then
		dn = Instance.new("StringValue")
		dn.Name = "DisplayName"
		dn.Parent = ruleFolder
	end
	dn.Value = cleanName .. " [" .. vType .. "]"
	if scanNow ~= false then
		for _, desc in ipairs(workspace:GetDescendants()) do
			if desc:IsA("Model") and desc.Name ~= "Ciws" and not isWorldModel(desc) and not Players:GetPlayerFromCharacter(desc) then
				local descClean = cleanModelName(desc.Name)
				if isPermTargetMatch(desc, ruleFolder) or descClean == cleanName or string.find(string.lower(desc.Name), string.lower(cleanName), 1, true) or string.find(string.lower(cleanName), string.lower(descClean), 1, true) then
					local prim = getBestTargetPart(desc)
					if prim then applyTag(prim, true) end
				end
			end
		end
	end
	return ruleFolder
end
local function getAllWorkspaceCandidateModels()
	local candidates = {}
	for _, entry in ipairs(RadarAPI.scan()) do
		table.insert(candidates, entry.model)
	end
	return candidates
end
local tokenCache = {}
local function debugPrintWorkspaceVehicles()
	traceStore.Value = ""
	trace("--- MANUAL CRAM DIAGNOSTIC ---")
	local candidates = getAllWorkspaceCandidateModels()
	trace("Total candidates found: " .. tostring(#candidates))
	for i, c in ipairs(candidates) do
		trace("Candidate " .. tostring(i) .. ": " .. c.Name .. " (Parent: " .. tostring(c.Parent) .. ")")
	end
	trace("--- END DIAGNOSTIC ---")
end
game.ReplicatedStorage:WaitForChild("CRAM_DEBUG").Changed:Connect(function(val)
	if val == true then debugPrintWorkspaceVehicles() end
end)

local function getCachedTokens(model)
	if not model then return {} end
	if tokenCache[model] then return tokenCache[model] end
	local tokens = getCleanSignatureTokens(model)
	tokenCache[model] = tokens
	return tokens
end
local function scanWorkspaceVehicles()
	local detected = {}
	local nameSeen = {}
	local allCandidates = getAllWorkspaceCandidateModels()
	for _, desc in ipairs(allCandidates) do
		local cName = cleanModelName(desc.Name)
		nameSeen[cName] = (nameSeen[cName] or 0) + 1
		local displayName = cName
		if nameSeen[cName] > 1 or string.lower(desc.Name) ~= string.lower(cName) then
			displayName = cName .. " #" .. tostring(nameSeen[cName])
		end
		local vType = getVehicleClassification(desc)
		local isPerm = false
		for _, pRule in ipairs(permFolder:GetChildren()) do
			if isPermTargetMatch(desc, pRule) then
				isPerm = true
				local prim = getBestTargetPart(desc)
				if prim then
					applyTag(prim, true)
				end
				break
			end
		end
		local sigTokens = getCachedTokens(desc)
		local sigSummary = ""
		if #sigTokens > 0 then
			local showCount = math.min(4, #sigTokens)
			local subT = {}
			for i = 1, showCount do
				table.insert(subT, sigTokens[i])
			end
			sigSummary = table.concat(subT, ", ")
		end
		local targetPart = getBestTargetPart(desc)
		if targetPart then
			CollectionService:AddTag(targetPart, "CRAM_Vehicle")
		end
		table.insert(detected, {
			name = displayName,
			cleanName = cName,
			path = desc:GetFullName() .. " [" .. tostring(nameSeen[cName]) .. "]",
			model = desc,
			type = vType,
			sigSummary = sigSummary,
			tokens = sigTokens,
			isPerm = isPerm,
			count = nameSeen[cName],
			part = targetPart,
		})
	end
	table.sort(detected, function(a, b)
		return tostring(a.path or a.name) < tostring(b.path or b.name)
	end)

	for _, oldItem in ipairs(cachedDetectedVehicles or {}) do
		local found = false
		for _, newItem in ipairs(detected) do
			if newItem.model == oldItem.model then found = true break end
		end
		if not found then
			local m = oldItem.model
			if not m or not m.Parent then
				trace("[CRAM DEBUG] REMOVED " .. oldItem.name .. ": Model was destroyed or despawned")
			else
				local isPlayer = Players:GetPlayerFromCharacter(m)
				local hasUnanchored = false
				for _, item in ipairs(m:GetDescendants()) do
					if item:IsA("BasePart") and not item.Anchored then hasUnanchored = true break end
				end
				local explicitTarget = m:FindFirstChild("FlightAI", true) or m:FindFirstChild("Burner", true) or m:FindFirstChildWhichIsA("VehicleSeat", true) or m:FindFirstChild("DriveSeat", true) or m:FindFirstChild("PilotSeat", true) or m:FindFirstChild("CanBeTargetted", true) or m:FindFirstChild("Durability", true) or m:FindFirstChild("Health", true) or m:FindFirstChild("Crashed", true) or m:FindFirstChild("StatusMain", true) or m:FindFirstChildOfClass("Humanoid")
				local structuralTarget = hasUnanchored and (m:FindFirstChild("Engine", true) or m:FindFirstChild("Fuselage", true) or m:FindFirstChild("Chassis", true) or m:FindFirstChild("Cockpit", true) or m:FindFirstChild("Turret", true))
				local isVehicle = explicitTarget or structuralTarget

				local reason = ""
				if not m:IsDescendantOf(workspace) then
					reason = "Reparented outside of workspace (now in " .. m.Parent.Name .. ")"
				elseif isWorldModel(m) then
					reason = "Parented to a blocked map/terrain folder"
				elseif m:GetAttribute("CramRegistered") or m:FindFirstChild("MainController") then
					reason = "Became a C-RAM unit"
				elseif isPlayer then
					reason = "Became a Player Character"
				elseif not isVehicle then
					reason = "No longer classified as vehicle (explicitTarget: " .. tostring(explicitTarget) .. ", hasUnanchored: " .. tostring(hasUnanchored) .. ")"
				else
					reason = "Unknown/Recursive Limit (Current parent: " .. m.Parent.Name .. ")"
				end
				trace("[CRAM DEBUG] REMOVED " .. oldItem.name .. " from Live: " .. reason)
			end
		end
	end

	cachedDetectedVehicles = detected
	detectedDirty = false
	return detected
end
local lastBroadcastTime = 0
local broadcastScheduled = false
local function performBroadcast()
	scanAllLiveUnits()
	if detectedDirty then
		scanWorkspaceVehicles()
	end
	local singleList = {}
	for part, name in pairs(activeSingleTargets) do
		if part.Parent then
			table.insert(singleList, {part = part, name = name})
		else
			activeSingleTargets[part] = nil
		end
	end
	local permList = {}
	local permRulesList = {}
	for _, child in ipairs(permFolder:GetChildren()) do
		table.insert(permList, child.Name)
		local fp = child:FindFirstChild("Fingerprint") and child.Fingerprint.Value or ""
		local dn = child:FindFirstChild("DisplayName") and child.DisplayName.Value or child.Name
		local subTokens = {}
		if fp ~= "" then
			local sp = string.split(fp, ",")
			for i = 1, math.min(4, #sp) do table.insert(subTokens, sp[i]) end
		end
		table.insert(permRulesList, {
			name = child.Name,
			displayName = dn,
			sigSummary = table.concat(subTokens, ", "),
		})
	end
	if detectedDirty then
		scanWorkspaceVehicles()
	end
	local detectedVehicles = cachedDetectedVehicles
	local templateNames = {}
	local templatesFolder = getTemplatesFolder()
	if templatesFolder then
		for _, t in ipairs(templatesFolder:GetChildren()) do
			if t:IsA("Model") then
				table.insert(templateNames, t.Name)
			end
		end
	end
	local state = Registry.getSerializableState()
	state.debug = debugFlag.Value
	state.traceLog = traceStore.Value
	state.targets = {
		single = singleList,
		perm = permList,
		permRules = permRulesList,
		detected = detectedVehicles,
	}
	state.templates = templateNames
	stateCache = state
	stateCacheTime = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local remote = getRemote(player)
		if remote then
			remote:FireClient(player, "FullState", state)
		end
	end
end
local function broadcastFullState()
	local now = os.clock()
	if now - lastBroadcastTime < 0.25 then
		if not broadcastScheduled then
			broadcastScheduled = true
			task.delay(0.25, function()
				broadcastScheduled = false
				lastBroadcastTime = os.clock()
				performBroadcast()
			end)
		end
		return
	end
	lastBroadcastTime = now
	performBroadcast()
end
local function unregisterLater(model)
	task.delay(0.3, function()
		if model and model.Parent and model:IsDescendantOf(workspace) then
			return
		end
		local id = Registry.findUnitByModel(model)
		if id then
			Registry.unregisterUnit(id)
			broadcastFullState()
		end
	end)
end
local function sendStateTo(player)
	local remote = getRemote(player)
	if not remote then return end
	local now = os.clock()
	if stateCache and now - stateCacheTime < 1 and not detectedDirty then
		remote:FireClient(player, "FullState", stateCache)
		return
	end
	scanAllLiveUnits()
	if detectedDirty then
		scanWorkspaceVehicles()
	end
	local singleList = {}
	for part, name in pairs(activeSingleTargets) do
		if part.Parent then
			table.insert(singleList, {part = part, name = name})
		end
	end
	local permList = {}
	local permRulesList = {}
	for _, child in ipairs(permFolder:GetChildren()) do
		table.insert(permList, child.Name)
		local fp = child:FindFirstChild("Fingerprint") and child.Fingerprint.Value or ""
		local dn = child:FindFirstChild("DisplayName") and child.DisplayName.Value or child.Name
		local subTokens = {}
		if fp ~= "" then
			local sp = string.split(fp, ",")
			for i = 1, math.min(4, #sp) do table.insert(subTokens, sp[i]) end
		end
		table.insert(permRulesList, {
			name = child.Name,
			displayName = dn,
			sigSummary = table.concat(subTokens, ", "),
		})
	end
	local detectedVehicles = cachedDetectedVehicles
	local templateNames = {}
	local templatesFolder = getTemplatesFolder()
	if templatesFolder then
		for _, t in ipairs(templatesFolder:GetChildren()) do
			if t:IsA("Model") then
				table.insert(templateNames, t.Name)
			end
		end
	end
	local state = Registry.getSerializableState()
	state.debug = debugFlag.Value
	state.traceLog = traceStore.Value
	state.targets = {
		single = singleList,
		perm = permList,
		permRules = permRulesList,
		detected = detectedVehicles,
	}
	state.templates = templateNames
	stateCache = state
	stateCacheTime = os.clock()
	remote:FireClient(player, "FullState", state)
end
scanAllLiveUnits()
workspace.ChildAdded:Connect(function(child)
	if child.Name == "Ciws" then
		task.wait(0.2)
		scanAllLiveUnits()
		child.ChildAdded:Connect(function(c)
			task.wait(0.2)
			registerLiveUnit(c)
			broadcastFullState()
		end)
		child.ChildRemoved:Connect(function(c)
			unregisterLater(c)
		end)
		broadcastFullState()
	end
end)
detectedDirty = true
task.spawn(function()
	while workspace.Parent do
		task.wait(1)
		scanAllLiveUnits()
	end
end)
local currentCiws = workspace:FindFirstChild("Ciws")
if currentCiws then
	currentCiws.ChildAdded:Connect(function(child)
		task.wait(0.2)
		registerLiveUnit(child)
		broadcastFullState()
	end)
	currentCiws.ChildRemoved:Connect(function(child)
		unregisterLater(child)
	end)
end
workspace.DescendantAdded:Connect(function(descendant)
	if isLiveCIWSModel(descendant) then
		task.wait(0.2)
		registerLiveUnit(descendant)
		broadcastFullState()
	elseif descendant:IsA("Model") then
		detectedDirty = true
		broadcastFullState()
	end
end)
workspace.DescendantRemoving:Connect(function(descendant)
	if descendant:IsA("Model") then
		detectedDirty = true
		unregisterLater(descendant)
		broadcastFullState()
	end
end)
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
local function onRemoteEvent(player, action, data)
	if action == "ToggleCanBreak" and data and data.unitId then
		local entry = Registry.getUnit(data.unitId)
		if entry and entry.model then
			local nextState = data.canBreak
			for _, d in ipairs(entry.model:GetDescendants()) do
				if d:IsA("NumberValue") or d:IsA("IntValue") then
					if nextState == true and d.Name == "Disabled_Durability" then
						d.Name = "Durability"
					elseif nextState == false and d.Name == "Durability" then
						d.Name = "Disabled_Durability"
					end
				end
			end
		end
		return
	end
	if action == "RequestFullState" then
		detectedDirty = true
		stateCache = nil
		RadarAPI.invalidateCache()
		scanWorkspaceVehicles()
		sendStateTo(player)
		return
	end
	if action == "ClearTrace" then
		traceStore.Value = ""
		broadcastFullState()
		return
	end
	if action == "SetDebug" then
		debugFlag.Value = data == true or (type(data) == "table" and data.enabled == true)
		broadcastFullState()
		return
	end
	if not hasToolEquipped(player) then return end
	if action == "SpawnCIWS" then
		local templatesFolder = getTemplatesFolder()
		if not templatesFolder then return end
		local templateName = data.templateName
		local pos = data.position
		local normData = data.normal
		local rot = data.rotation or 0
		local targetPart = data.targetPart
		if targetPart and (not targetPart:IsA("BasePart") or not targetPart:IsDescendantOf(workspace)) then
			targetPart = nil
		end
		local template = templatesFolder:FindFirstChild(templateName)
		if not template or not template:IsA("Model") then return end
		if type(pos) ~= "table" or not pos.x or not pos.y or not pos.z then return end
		local hitPosition = Vector3.new(
			math.clamp(pos.x, -50000, 50000),
			math.clamp(pos.y, -500, 5000),
			math.clamp(pos.z, -50000, 50000)
		)
		local normal = Vector3.new(0, 1, 0)
		if type(normData) == "table" and normData.x and normData.y and normData.z then
			local rawN = Vector3.new(normData.x, normData.y, normData.z)
			if rawN.Magnitude > 0.01 then
				normal = rawN.Unit
			end
		end
		local clone = template:Clone()
		local cleanBase = cleanModelName(templateName)
		local unitNum = getNextUnitNumber(cleanBase)
		clone.Name = cleanBase .. " #" .. unitNum
		local baseComp = clone:FindFirstChild("BaseComponent")
		local statsDisplay = clone:FindFirstChild("StatsDisplay")
		if baseComp then
			clone.PrimaryPart = baseComp
			local halfHeight = baseComp.Size.Y * 0.5

			if data.relativePos and data.relativeNorm and targetPart and targetPart:IsA("BasePart") and not targetPart.Anchored then
				hitPosition = targetPart.CFrame:PointToWorldSpace(Vector3.new(data.relativePos.x, data.relativePos.y, data.relativePos.z))
				normal = targetPart.CFrame:VectorToWorldSpace(Vector3.new(data.relativeNorm.x, data.relativeNorm.y, data.relativeNorm.z))
				if normal.Magnitude > 0.01 then
					normal = normal.Unit
				else
					normal = Vector3.new(0, 1, 0)
				end
			end

			local surfacePos = hitPosition + normal * halfHeight
			local rotCF = getSurfaceRotation(normal, rot, targetPart)
			local targetCF = CFrame.new(surfacePos) * rotCF
			local primary = clone.PrimaryPart
			if primary then
				local offset = clone:GetPivot():ToObjectSpace(primary.CFrame)
				clone:PivotTo(targetCF * offset:Inverse())
			end

			local isVehicle = targetPart and targetPart:IsA("BasePart") and (not targetPart.Anchored)
			if isVehicle then
				baseComp.Anchored = false
				baseComp.Massless = true
				baseComp.CanCollide = true
				for _, p in ipairs(clone:GetDescendants()) do
					if p:IsA("BasePart") then
						p.Massless = true
						p.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0.5, 0.5)
					end
				end
				local weld = Instance.new("WeldConstraint")
				weld.Name = "VehicleMountWeld"
				weld.Part0 = baseComp
				weld.Part1 = targetPart
				weld.Parent = baseComp
				if statsDisplay then
					statsDisplay.Anchored = false
					statsDisplay.Massless = true
					statsDisplay.CanCollide = false
					local sw = Instance.new("WeldConstraint")
					sw.Name = "StatsWeld"
					sw.Part0 = baseComp
					sw.Part1 = statsDisplay
					sw.Parent = baseComp
				end
				for _, part in ipairs(clone:GetDescendants()) do
					if part:IsA("BasePart") and part ~= baseComp and part ~= statsDisplay then
						part.CanCollide = true
						part.CanTouch = true
						part.CanQuery = true
					end
				end
				local vVal = Instance.new("ObjectValue")
				vVal.Name = "VehicleMount"
				vVal.Value = targetPart
				vVal.Parent = clone
				targetPart.Destroying:Connect(function()
					if clone and clone.Parent then
						clone:Destroy()
					end
				end)
			else
				baseComp.Anchored = true
				baseComp.CanCollide = true
				for _, part in ipairs(clone:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = true
					end
				end
			end
		end
		clone.Parent = getCiwsFolder()
		Registry.registerUnit(clone)
		broadcastFullState()
	elseif action == "DestroyCIWS" then
		local unitId = data.unitId
		local entry = getEntry(unitId)
		if entry then
			if entry.model and entry.model.Parent then
				entry.model:Destroy()
			end
			Registry.unregisterUnit(unitId)
			broadcastFullState()
		end
	end

	_G.DecommissionCRAM = function(model)
		local unitId = nil
		for id, entry in pairs(Registry.getAllUnits()) do
			if entry.model == model then
				unitId = id
				break
			end
		end
		if unitId then
			local entry = getEntry(unitId)
			if entry then
				if entry.model and entry.model.Parent then
					entry.model:Destroy()
				end
				Registry.unregisterUnit(unitId)
				broadcastFullState()
			end
		end
	end

	if action == "UpdateUnitConfig" then
		if type(data) == "table" then
			local entry = getEntry(data.unitId)
			if entry then
				Registry.setUnitConfig(entry.id, data.key, data.value)
				if data.key == "maxRange" and type(data.value) == "number" then
					local cfgs = entry.model and entry.model:FindFirstChild("Configurations")
					local maxVal = cfgs and cfgs:FindFirstChild("MaxRange")
					if maxVal and maxVal:IsA("NumberValue") then
						maxVal.Value = math.clamp(data.value :: number, 1000, 40000)
					end
				end
			end
		end
		broadcastFullState()
	elseif action == "SetUnitTargetMode" then
		local unitId = data.unitId
		local mode = data.mode
		local entry = getEntry(unitId)
		if entry and (mode == "GLOBAL" or mode == "INDIVIDUAL") then
			entry.config.targetMode = mode
			entry.config.mode = (mode == "GLOBAL") and "OVERALL" or "INDIVIDUAL"
			if entry.model then
				entry.model:SetAttribute("CramMode", entry.config.mode)
			end
			broadcastFullState()
		end
	elseif action == "ApplyUnitConfig" then
		local unitId = type(data) == "table" and data.unitId or nil
		local config = type(data) == "table" and data.config or nil
		local entry = getEntry(unitId)
		if entry and type(config) == "table" then
			Registry.applyUnitConfig(entry.id, config)
			if config.maxRange then
				entry.config.maxRange = math.clamp(config.maxRange, 1000, 40000)
			end
			if config.targetMode == "GLOBAL" then
				entry.config.mode = "OVERALL"
			elseif config.targetMode == "INDIVIDUAL" then
				entry.config.mode = "INDIVIDUAL"
			end
			if entry.model then
				local cfgs = entry.model:FindFirstChild("Configurations")
				if cfgs then
					if config.maxAmmo and cfgs:FindFirstChild("MaxAmmo") then
						cfgs.MaxAmmo.Value = config.maxAmmo
					end
					if config.maxRange and cfgs:FindFirstChild("MaxRange") then
						cfgs.MaxRange.Value = config.maxRange
					end
				end
			end
		end
		broadcastFullState()
	elseif action == "ResetUnitConfig" then
		Registry.resetUnitConfig(data.unitId)
		broadcastFullState()
	elseif action == "UpdateGlobalConfig" then
		Registry.setGlobalConfig(data.key, data.value)
		broadcastFullState()
	elseif action == "ApplyGlobalConfig" then
		local config = type(data) == "table" and (data.config or data) or {}
		for k, v in pairs(config) do
			Registry.setGlobalConfig(k, v)
		end
		for _, entry in pairs(Registry.getAllUnits()) do
			if entry.model then
				local cfgs = entry.model:FindFirstChild("Configurations")
				if cfgs then
					if config.maxAmmo and cfgs:FindFirstChild("MaxAmmo") then
						cfgs.MaxAmmo.Value = config.maxAmmo
					end
					if config.maxRange and cfgs:FindFirstChild("MaxRange") then
						cfgs.MaxRange.Value = config.maxRange
					end
				end
			end
		end
		broadcastFullState()
	elseif action == "ResetGlobalConfig" then
		Registry.resetGlobalConfig()
		broadcastFullState()
	elseif action == "SetUnitMode" then
		local entry = getEntry(data.unitId)
		if entry then
			if data.mode == "OVERALL" or data.mode == "INDIVIDUAL" then
				entry.config.mode = data.mode
				entry.config.targetMode = (data.mode == "OVERALL") and "GLOBAL" or "INDIVIDUAL"
				if entry.model then
					entry.model:SetAttribute("CramMode", data.mode)
				end
			end
		end
		broadcastFullState()
	elseif action == "ToggleUnit" then
		local entry = getEntry(data.unitId)
		if entry then
			entry.config.enabled = (data.enabled == true)
			if entry.model then
				entry.model:SetAttribute("CramEnabled", entry.config.enabled)
			end
		end
		broadcastFullState()
	elseif action == "SetNickname" then
		if type(data) == "table" and data.unitId then
			local entry = Registry.getUnit(data.unitId)
			local rawNick = data.nickname or (data :: any).name
			if entry and type(rawNick) == "string" then
				entry.config.nickname = string.sub(rawNick, 1, 32)
			end
		end
		broadcastFullState()
	elseif action == "ReloadUnit" then
		local entry = getEntry(data.unitId)
		if entry then
			entry.stats.status = "CYCLING DRUM"
			local ammoVal = entry.model and entry.model:FindFirstChild("Status") and entry.model.Status:FindFirstChild("Ammo")
			if ammoVal then ammoVal.Value = 0 end
			entry.stats.currentAmmo = 0
			broadcastFullState()
			task.spawn(function()
				task.wait(2.5)
				local currentEntry = getEntry(data.unitId)
				if currentEntry then
					local eff = Registry.getEffectiveConfig(data.unitId)
					local maxAmmoVal = eff and eff.maxAmmo or 1500
					currentEntry.stats.currentAmmo = maxAmmoVal
					currentEntry.stats.status = "IDLE"
					local aVal = currentEntry.model and currentEntry.model:FindFirstChild("Status") and currentEntry.model.Status:FindFirstChild("Ammo")
					if aVal then aVal.Value = maxAmmoVal end
					broadcastFullState()
				end
			end)
		end
	elseif action == "RefillAmmo" then
		local entry = getEntry(data.unitId)
		if entry then
			local eff = Registry.getEffectiveConfig(data.unitId)
			entry.stats.currentAmmo = eff.maxAmmo
			local ammoVal = entry.model and entry.model:FindFirstChild("Status") and entry.model.Status:FindFirstChild("Ammo")
			if ammoVal then ammoVal.Value = eff.maxAmmo end
		end
		broadcastFullState()
	elseif action == "TagTarget" then
		local targetPart = data
		if targetPart and targetPart:IsA("BasePart") and targetPart:IsDescendantOf(workspace) then
			local targetModel = resolveVehicleModel(targetPart) or targetPart:FindFirstAncestorOfClass("Model")
			if targetModel and not isWorldModel(targetModel) and applyTag(targetPart) then
				broadcastFullState()
			end
		end
	elseif action == "UntagTarget" then
		local targetPart = data
		if targetPart then
			removeTag(targetPart)
			local cf = workspace:FindFirstChild("Ciws")
			if cf then
				for _, uMdl in ipairs(cf:GetChildren()) do
					local st = uMdl:FindFirstChild("Status")
					if st and st:FindFirstChild("Target") and st.Target.Value == targetPart then
						st.Target.Value = nil
					end
				end
			end
			broadcastFullState()
		end
	elseif action == "DesignatePerm" then
		local targetName = type(data) == "table" and (data.cleanName or data.modelName) or data
		if targetName and type(targetName) == "string" then
			local cleanName = cleanModelName(targetName)
			local foundModel = nil
			for _, desc in ipairs(workspace:GetDescendants()) do
				if desc:IsA("Model") and cleanModelName(desc.Name) == cleanName then
					foundModel = desc
					break
				end
			end
			if not foundModel then
				for _, container in ipairs({game:GetService("ReplicatedStorage"), game:GetService("ServerStorage")}) do
					for _, desc in ipairs(container:GetDescendants()) do
						if desc:IsA("Model") and cleanModelName(desc.Name) == cleanName then
							foundModel = desc
							break
						end
					end
					if foundModel then break end
				end
			end
			registerPermTarget(cleanName, foundModel)
			broadcastFullState()
		end
	elseif action == "TagPerm" then
		local targetPart = data
		if targetPart and targetPart:IsA("BasePart") and targetPart:IsDescendantOf(workspace) then
			local mdl = resolveVehicleModel(targetPart) or targetPart:FindFirstAncestorOfClass("Model")
			if mdl and not isWorldModel(mdl) then
				local cleanName = cleanModelName(mdl.Name)
				registerPermTarget(cleanName, mdl)
				broadcastFullState()
			end
		end
	elseif action == "UntagPerm" then
		local name = type(data) == "table" and (data.cleanName or data.name) or data
		if name and type(name) == "string" then
			removePermTarget(name)
			broadcastFullState()
		end
	elseif action == "TargetAllPresets" or action == "TargetBatch" then
		local items = type(data) == "table" and (data.items or data.catalog) or nil
		if type(items) == "table" then
			for _, item in ipairs(items) do
				if type(item) == "string" then
					registerPermTarget(cleanModelName(item), nil, false)
				end
			end
			scanWorkspaceVehicles()
			broadcastFullState()
		end
	elseif action == "DisengageAllPerm" then
		local names = {}
		for _, rule in ipairs(permFolder:GetChildren()) do
			table.insert(names, rule.Name)
		end
		removePermBatch(names)
		broadcastFullState()
	elseif action == "DisengageBatch" then
		local items = type(data) == "table" and data.items or nil
		if type(items) == "table" then
			removePermBatch(items)
			broadcastFullState()
		end
	elseif action == "MasterToggleAll" then
		local enabled = not not data.enabled
		for _, entry in pairs(Registry.getAllUnits()) do
			entry.config.enabled = enabled
			if entry.model then
				entry.model:SetAttribute("CramEnabled", enabled)
			end
		end
		broadcastFullState()
	elseif action == "SetAllMode" then
		if data.mode == "OVERALL" or data.mode == "INDIVIDUAL" then
			for _, entry in pairs(Registry.getAllUnits()) do
				entry.config.mode = data.mode
				entry.config.targetMode = (data.mode == "OVERALL") and "GLOBAL" or "INDIVIDUAL"
				if entry.model then
					entry.model:SetAttribute("CramMode", data.mode)
				end
			end
		end
		broadcastFullState()
	elseif action == "RecallAll" then
		for id, entry in pairs(Registry.getAllUnits()) do
			if entry.model then
				entry.model:Destroy()
			end
			Registry.unregisterUnit(id)
		end
		broadcastFullState()
	elseif action == "RefillAll" then
		for id, entry in pairs(Registry.getAllUnits()) do
			local eff = Registry.getEffectiveConfig(id)
			entry.stats.currentAmmo = eff.maxAmmo
			local ammoVal = entry.model and entry.model:FindFirstChild("Status") and entry.model.Status:FindFirstChild("Ammo")
			if ammoVal then ammoVal.Value = eff.maxAmmo end
		end
		broadcastFullState()
	end
end
local function hookRemoteForTool(tool)
	if not tool or not tool:IsA("Tool") or tool.Name ~= TOOL_NAME then return end
	local remote = tool:WaitForChild("MasterRemote", 5)
	if remote and not hookedRemotes[remote] then
		hookedRemotes[remote] = true
		remote.OnServerEvent:Connect(function(plr, action, data)
			onRemoteEvent(plr, action, data)
		end)
	end
end
local function hookPlayerTools(player)
	local function checkContainer(container)
		if not container then return end
		for _, child in ipairs(container:GetChildren()) do
			hookRemoteForTool(child)
		end
		container.ChildAdded:Connect(function(child)
			hookRemoteForTool(child)
		end)
	end
	local bp = player:WaitForChild("Backpack", 5)
	checkContainer(bp)
	if player.Character then
		checkContainer(player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		checkContainer(char)
		local newBp = player:WaitForChild("Backpack", 5)
		checkContainer(newBp)
	end)
end
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		hookPlayerTools(p)
	end)
end
task.spawn(function()
	for i = 1, 8 do
		task.wait(0.5)
		scanAllLiveUnits()
	end
	while true do
		task.wait(5)
		scanWorkspaceVehicles()
	end
end)
Players.PlayerAdded:Connect(function(p)
	hookPlayerTools(p)
end)
workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("Model") then
		task.delay(0.5, function()
			if desc.Parent and permFolder:FindFirstChild(desc.Name) then
				if desc:FindFirstChildOfClass("Humanoid") or desc:FindFirstChild("Durability", true) or desc:FindFirstChild("Health", true) or desc:FindFirstChild("Arsenal", true) then
					local prim = desc.PrimaryPart or desc:FindFirstChildWhichIsA("BasePart")
					if prim then
						if applyTag(prim) then
							broadcastFullState()
						end
					end
				end
			end
		end)
	end
end)
task.spawn(function()
	while true do
		task.wait(2)
		scanAllLiveUnits()
		for id, entry in pairs(Registry.getAllUnits()) do
			if entry.model and entry.model.Parent then
				local status = entry.model:FindFirstChild("Status")
				if status then
					local ammo = status:FindFirstChild("Ammo")
					if ammo then
						entry.stats.currentAmmo = ammo.Value
					end
					local target = status:FindFirstChild("Target")
					if target then
						entry.stats.currentTarget = target.Value and tostring(target.Value) or nil

					end
				end
			end
		end
	end
end)

