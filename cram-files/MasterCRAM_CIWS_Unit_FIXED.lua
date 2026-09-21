--!nocheck
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Registry = nil
pcall(function()
	Registry = require(ServerScriptService:WaitForChild("CRAMRegistry", 5))
end)
local RadarAPI = require(ServerScriptService:WaitForChild("RadarAPI"))
RadarAPI.registerSystem("CIWS", {})
local ciwsUnits = {}
local setupModels = {}
local traceStore = ReplicatedStorage:FindFirstChild("CRAM_TRACE_LOG")
if not traceStore then
	traceStore = Instance.new("StringValue")
	traceStore.Name = "CRAM_TRACE_LOG"
	traceStore.Value = ""
	traceStore.Parent = ReplicatedStorage
end
local function debugEnabled()
	local flag = ReplicatedStorage:FindFirstChild("CRAM_DEBUG")
	return flag and flag:IsA("BoolValue") and flag.Value == true
end
local function trace(...)
	if not debugEnabled() then return end
	local first = tostring(select(1, ...)):lower()
	if string.find(first, "tracer", 1, true) or string.find(first, "projectile", 1, true) or string.find(first, "bullet trail", 1, true) then return end
	local parts = {}
	for _, value in ipairs({...}) do table.insert(parts, tostring(value)) end
	local line = table.concat(parts, " ")

	local rows = string.split(traceStore.Value, "\n")
	if traceStore.Value == "" then rows = {} end
	table.insert(rows, line)
	while #rows > 180 do table.remove(rows, 1) end
	traceStore.Value = table.concat(rows, "\n")
end
RadarAPI.setLogger(trace)
local ciwsFolder = workspace:FindFirstChild("Ciws") or Instance.new("Folder", workspace); ciwsFolder.Name = "Ciws"
local containerFolder = workspace:FindFirstChild("Container") or Instance.new("Folder", workspace); containerFolder.Name = "Container"
local function getUnitConfig(unit)
	if not unit or not unit.model then return nil end
	if Registry then
		local id = Registry.findUnitByModel(unit.model)
		if id then
			return Registry.getEffectiveConfig(id)
		end
	end
	local enabled = unit.model:GetAttribute("CramEnabled")
	local mode = unit.model:GetAttribute("CramMode")
	if enabled ~= nil then
		return {
			enabled = enabled == true,
			mode = mode or "INDIVIDUAL",
			targetMode = mode or "INDIVIDUAL",
			maxRange = unit.maxRange and unit.maxRange.Value or 6000,
			damage = unit.damageAmount or 25,
			maxAmmo = unit.maxAmmo and unit.maxAmmo.Value or 1500,
			explosionRadius = unit.explosionRadius or 30,
		}
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

local function isBadTarget(model)
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
	if isBadTarget(part) then return nil end
	local cur = part:IsA("Model") and part or part:FindFirstAncestorOfClass("Model")
	if not cur or isBadTarget(cur) then return nil end
	local topModel = cur
	local node = cur
	while node and node.Parent and node.Parent ~= workspace do
		local p = node.Parent
		if isBadTarget(p) then
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
	if isBadTarget(topModel) then return nil end
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
local function isPermTargetMatch(model, permRuleFolder)
	if not model or not model:IsA("Model") or not permRuleFolder then return false end
	local cleanName = cleanModelName(model.Name)
	local ruleName = permRuleFolder.Name
	local ruleClean = cleanModelName(ruleName)
	local lowModel = string.lower(cleanName)
	local lowRule = string.lower(ruleClean)
	local normModel = string.gsub(lowModel, "[%s%-_]", "")
	local normRule = string.gsub(lowRule, "[%s%-_]", "")
	local function getVehClassification(m)
		local profileName = RadarAPI.classify(m)
		if profileName == "Helicopter" then return "HELI" end
		if profileName == "CombatJet" then return "PLANE" end
		if m:FindFirstChild("A-Chassis Tune", true) or m:FindFirstChildWhichIsA("VehicleSeat", true) or m:FindFirstChild("DriveSeat", true) then return "GROUND" end
		return "VEHICLE"
	end
	local vClass = getVehClassification(model)
	if (lowRule == "helicopter" or lowRule == "rotary wing / helicopters" or lowRule == "heli" or lowRule == "helicopters") and (vClass == "HELI") then
		return true
	end
	if (lowRule == "combat_jet" or lowRule == "combat jet" or lowRule == "fixed-wing / combat jets" or lowRule == "plane" or lowRule == "jets" or lowRule == "aircraft") and (vClass == "PLANE") then
		return true
	end
	if (lowRule == "ground_vehicle" or lowRule == "ground vehicle" or lowRule == "ground vehicles & combat trucks" or lowRule == "ground") and (vClass == "GROUND") then
		return true
	end
	if lowModel == lowRule or normModel == normRule or string.find(lowModel, lowRule, 1, true) or string.find(lowRule, lowModel, 1, true) or string.find(normModel, normRule, 1, true) or string.find(normRule, normModel, 1, true) then
		return true
	end
	local sigVal = permRuleFolder:FindFirstChild("Fingerprint")
	local sigString = sigVal and sigVal.Value or ""
	if sigString ~= "" then
		local regTokens = string.split(sigString, ",")
		if #regTokens > 0 then
			local modelTokens = getCleanSignatureTokens(model)
			local matches = 0
			for _, rt in ipairs(regTokens) do
				local rClean = string.gsub(rt, "^%s*(.-)%s*$", "%1")
				if table.find(modelTokens, rClean) then
					matches = matches + 1
				end
			end
			local matchRatio = matches / #regTokens
			if matchRatio >= 0.40 then return true end
		end
	end
	return false
end
local function isTagMatch(targetModel, filterTag)
	if not targetModel or not filterTag then return false end
	local lowFilter = string.lower(filterTag)
	local lowName = string.lower(targetModel.Name)
	if string.find(lowName, lowFilter, 1, true) or lowName == lowFilter then
		return true
	end
	if lowFilter == "ground_vehicle" or lowFilter == "groundvehicle" or lowFilter == "ground targets" or lowFilter == "all ground vehicles" then
		if targetModel:FindFirstChild("A-Chassis Tune", true) or targetModel:FindFirstChildWhichIsA("VehicleSeat", true) or targetModel:FindFirstChild("DriveSeat", true) or targetModel:FindFirstChild("CarRegenScript", true) then
			return true
		end
	end
	if lowFilter == "helicopter" or lowFilter == "helicopters" or lowFilter == "all helicopters" then
		if RadarAPI.classify(targetModel) == "Helicopter" then
			return true
		end
		for _, hName in ipairs({"sa330", "loach", "ch-178", "mi-8", "nh-90", "uh-60", "laat", "uh-1"}) do
			if string.find(lowName, hName, 1, true) then return true end
		end
	end
	if lowFilter == "combat_jet" or lowFilter == "combat jets" or lowFilter == "planes" or lowFilter == "all combat jets" or lowFilter == "air targets" then
		if RadarAPI.classify(targetModel) == "CombatJet" then
			return true
		end
		for _, pName in ipairs({"f-16", "a-10", "su-25", "plane", "jet"}) do
			if string.find(lowName, pName, 1, true) then return true end
		end
	end
	if RadarAPI.classify(targetModel) == "CombatJet" then
		for _, pName in ipairs({"f-16", "a-10", "su-25", "plane", "jet", "su25", "f16", "a10"}) do
			if string.find(lowFilter, pName, 1, true) or string.find(lowName, pName, 1, true) then
				return true
			end
		end
	end
	for _, child in ipairs(targetModel:GetDescendants()) do
		local cLow = string.lower(child.Name)
		if #cLow >= 3 and (string.find(cLow, lowFilter, 1, true) or string.find(lowFilter, cLow, 1, true)) then
			return true
		end
	end
	if lowFilter == "air_drone" or lowFilter == "air drone" or lowFilter == "drone" then
		if string.find(lowName, "drone", 1, true) or string.find(lowName, "uav", 1, true) then
			return true
		end
	end
	if lowFilter == "missiles" or lowFilter == "missile" then
		if string.find(lowName, "missile", 1, true) or targetModel:FindFirstChild("Missile", true) then
			return true
		end
	end
	for _, desc in ipairs(targetModel:GetDescendants()) do
		if desc:IsA("StringValue") and (desc.Name == "TargetType" or desc.Name == "VoidTag") then
			if string.lower(desc.Value) == lowFilter or string.find(string.lower(desc.Value), lowFilter, 1, true) then
				return true
			end
		end
	end
	return false
end
local function isTargetAllowed(unit, targetModel)
	local cfg = getUnitConfig(unit)
	if cfg and cfg.enabled == false then return false end
	if not targetModel or isBadTarget(targetModel) then return false end
	local manualMark = targetModel:FindFirstChild("CRAM_ManualTarget", true)
	local targetMark = targetModel:FindFirstChild("CanBeTargetted", true)
	if targetMark and targetMark:GetAttribute("CRAMDisabled") == true then return false end
	local targetPart = targetMark and targetMark.Parent
	local manualTarget = targetPart and targetPart:IsA("BasePart") and targetPart:GetAttribute("ManualTarget") == true
	if manualMark or manualTarget then
		return true
	end
	local isIndiv = (cfg and (cfg.targetMode == "INDIVIDUAL" or cfg.mode == "INDIVIDUAL"))
	if isIndiv then
		local whitelist = cfg and cfg.targetWhitelist or {}
		local isWhitelisted = false
		local cleanTargName = string.lower(cleanModelName(targetModel.Name))
		for _, w in ipairs(whitelist) do
			local cleanW = string.lower(cleanModelName(tostring(w)))
			if isTagMatch(targetModel, w) or cleanTargName == cleanW or string.find(cleanTargName, cleanW, 1, true) or string.find(cleanW, cleanTargName, 1, true) then
				isWhitelisted = true
				break
			end
		end
		if isWhitelisted then
			return true
		end
		return false
	else
		local permFolder = game:GetService("ReplicatedStorage"):FindFirstChild("CRAM_PermTargets") or ServerScriptService:FindFirstChild("PermanentTargets")
		if permFolder and #permFolder:GetChildren() > 0 then
			for _, rule in ipairs(permFolder:GetChildren()) do
				if isPermTargetMatch(targetModel, rule) or cleanModelName(targetModel.Name) == cleanModelName(rule.Name) then
					return true
				end
			end
		end
		return false
	end
end
local function getLargestPart(model)
	local largestPart = nil
	local maxVol = 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local vol = part.Size.X * part.Size.Y * part.Size.Z
			if vol > maxVol then
				maxVol = vol
				largestPart = part
			end
		end
	end
	return largestPart
end
local function getTargetMainPart(model)
	if not model then return nil end
	local _, radarProfile = RadarAPI.classify(model)
	local radarPart = radarProfile.getBestTargetPart(model)
	if radarPart then return radarPart end
	local vehSeat = model:FindFirstChild("DriveSeat", true) or model:FindFirstChildWhichIsA("VehicleSeat", true)
	if vehSeat and vehSeat:IsA("BasePart") then
		return vehSeat
	end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") and model.PrimaryPart.CanQuery ~= false then
		return model.PrimaryPart
	end
	for _, name in ipairs({"Fuselage", "MAIN", "Main", "Body", "Center", "Cockpit", "Engine", "Hull", "Chassis", "Weight"}) do
		local found = model:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	for _, seatName in ipairs({"DriveSeat", "PilotSeat", "DriverSeat", "Seat"}) do
		local foundSeat = model:FindFirstChild(seatName, true)
		if foundSeat and foundSeat:IsA("BasePart") then
			return foundSeat
		end
	end
	local anySeat = model:FindFirstChildWhichIsA("Seat", true)
	if anySeat then return anySeat end
	local largest = getLargestPart(model)
	if largest then return largest end
	return model:FindFirstChildWhichIsA("BasePart")
end
local function findTargetTag(part, model)
	if part then
		local direct = part:FindFirstChild("CanBeTargetted")
		if direct and direct:IsA("BoolValue") then
			return direct
		end
	end
	if model then
		local nested = model:FindFirstChild("CanBeTargetted", true)
		if nested and nested:IsA("BoolValue") then
			return nested
		end
	end
	return nil
end
local function traceTargetSnapshot(unit, model, part, hum)
	if not debugEnabled() or not model or unit.lastTraceTarget == model then return end
	unit.lastTraceTarget = model
	local values = {}
	local damageParts = {}
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("Humanoid") then
			table.insert(values, desc.Name.." Health="..tostring(desc.Health).." Max="..tostring(desc.MaxHealth))
		elseif desc:IsA("NumberValue") or desc:IsA("IntValue") then
			local low = string.lower(desc.Name)
			if string.find(low, "durability", 1, true) or string.find(low, "health", 1, true) or string.find(low, "damage", 1, true) or string.find(low, "armor", 1, true) or string.find(low, "integrity", 1, true) or string.find(low, "hull", 1, true) then
				table.insert(values, desc:GetFullName().."="..tostring(desc.Value))
			end
		elseif desc:IsA("BasePart") then
			local direct = desc:FindFirstChild("Durability") or desc:FindFirstChild("Health")
			if direct or desc == part or string.find(string.lower(desc.Name), "hitbox", 1, true) or string.find(string.lower(desc.Name), "main", 1, true) then
				table.insert(damageParts, desc.Name)
			end
		end
	end
	trace("CRAM TRACE target snapshot", unit.model and unit.model.Name or "unknown", model.Name, "part", part and part.Name or "none", "values", table.concat(values, " | "), "damageParts", table.concat(damageParts, ", "))
end
local function clearTarget(unit, reason)
	if unit.target == nil then
		return
	end
	trace("CRAM TRACE clear", unit.model and unit.model.Name or "unknown", unit.targetModel and unit.targetModel.Name or "none", reason or "unspecified")
	if unit.target then
		RadarAPI.releaseTarget(unit.target)
	end
	unit.target = nil
	unit.lastTraceTarget = nil
	unit.targetHum = nil
	unit.targetModel = nil
	unit.targetMainPart = nil
	unit.isOnTarget = false
	unit.hasLOS = false
	unit.losBlockedTime = 0
	unit.interceptPos = nil
	unit.prevTargetPos = nil
	unit.prevTargetVel = nil
	unit.smoothedVel = Vector3.zero
end
local function checkLineOfSight(unit, targetPos, targetModel)
	if not unit or not unit.model or not targetPos then return false end
	local muzzle = (unit.gunBarrel and unit.gunBarrel:FindFirstChild("Muzzle")) or unit.verticalComponent
	if not muzzle then return false end
	local origin = muzzle.Position
	local diff = targetPos - origin
	local dist = diff.Magnitude
	if dist < 2 then return true end
	local filter = {unit.model}
	if targetModel then
		table.insert(filter, targetModel)
	end
	local vVal = unit.model:FindFirstChild("VehicleMount")
	local vehPart = vVal and vVal.Value
	local vehModel = vehPart and vehPart:FindFirstAncestorOfClass("Model")
	if vehModel then
		table.insert(filter, vehModel)
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = filter
	rayParams.IgnoreWater = true
	local result = workspace:Raycast(origin, diff, rayParams)
	if result and result.Instance then
		if result.Instance:IsA("Terrain") or result.Instance.CanCollide or result.Instance.Transparency < 0.9 then
			return false, result.Instance
		end
	end
	return true
end
local function isBoreClear(unit, maxDist)
	if not unit or not unit.gunBarrel then return true end
	local muzzle = unit.gunBarrel:FindFirstChild("Muzzle")
	local direction = unit.gunBarrel:FindFirstChild("Direction")
	if not muzzle or not direction then return true end
	local origin = muzzle.Position
	local aimDir = (direction.Position - muzzle.Position).Unit
	local checkDist = math.clamp(maxDist or 150, 5, 250)
	local filter = {unit.model}
	if unit.targetModel then
		table.insert(filter, unit.targetModel)
	end
	local vVal = unit.model:FindFirstChild("VehicleMount")
	local vehPart = vVal and vVal.Value
	local vehModel = vehPart and vehPart:FindFirstAncestorOfClass("Model")
	if vehModel then
		table.insert(filter, vehModel)
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = filter
	rayParams.IgnoreWater = true
	local result = workspace:Raycast(origin, aimDir * checkDist, rayParams)
	if result and result.Instance then
		if result.Instance:IsA("Terrain") or result.Instance.CanCollide or result.Instance.Transparency < 0.9 then
			return false, result.Instance
		end
	end
	return true
end
local function CalculateIntercept(origin, targetPos, targetVel, bulletSpeed, targetAcc, leadComp)
	leadComp = leadComp or 1.0
	local rel = targetPos - origin
	local effectiveVel = targetVel * leadComp
	local vDotV = effectiveVel:Dot(effectiveVel)
	local a = vDotV - (bulletSpeed * bulletSpeed)
	local b = 2 * rel:Dot(effectiveVel)
	local c = rel:Dot(rel)
	local t = nil
	if math.abs(a) > 0.0001 then
		local det = (b * b) - (4 * a * c)
		if det >= 0 then
			local sqrtDet = math.sqrt(det)
			local t1 = (-b - sqrtDet) / (2 * a)
			local t2 = (-b + sqrtDet) / (2 * a)
			if t1 > 0 and t2 > 0 then
				t = math.min(t1, t2)
			elseif t1 > 0 then
				t = t1
			elseif t2 > 0 then
				t = t2
			end
		end
	end
	if not t or t <= 0 or t > 5 then
		t = rel.Magnitude / bulletSpeed
	end
	local leadPos = targetPos + (effectiveVel * t)
	if targetAcc and targetAcc.Magnitude > 2 and leadComp > 0 then
		local accOffset = 0.5 * targetAcc * (t * t) * leadComp
		if accOffset.Magnitude > 120 then
			accOffset = accOffset.Unit * 120
		end
		leadPos = leadPos + accOffset
	end
	return leadPos
end
local function fireUp(unit)
	if not unit.isOnTarget then return end
	local sound = unit.baseComponent:FindFirstChild("CIWS Firing")
	local s2 = unit.baseComponent:FindFirstChild("CIWS FiringDist")
	if s2 then
		s2.TimePosition = 0
		s2:Play()
	end
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end
local function fireDown(unit)
	local sound = unit.baseComponent:FindFirstChild("CIWS Firing")
	local s2 = unit.baseComponent:FindFirstChild("CIWS FiringDist")
	if s2 then
		s2:Stop()
		s2.TimePosition = 0.9
		s2:Play()
	end
	if sound then
		sound:Stop()
		sound.TimePosition = 0.9
		sound:Play()
	end
end
local findDamageValue
local findDamageAttribute
local function setupCIWS(model)
	if not model:IsA("Model") then return end
	if setupModels[model] then return end
	if not model:FindFirstChild("BaseComponent") or not model:FindFirstChild("Configurations") then
		task.delay(0.5, function()
			if model.Parent and not setupModels[model] then
				setupCIWS(model)
			end
		end)
		return
	end
	setupModels[model] = true
	local mc = model:FindFirstChild("MainController")
	if mc and mc:IsA("Script") then
		mc.Disabled = true
	end
	if Registry and not Registry.findUnitByModel(model) then
		Registry.registerUnit(model)
	end
	local modules = model:WaitForChild("Modules")
	local externalFunctions = require(modules:WaitForChild("ExternalFunctions"))
	local unit = {
		model = model,
		target = nil,
		targetHum = nil,
		targetModel = nil,
		targetValue = model.Status.Target,
		ammo = model.Status.Ammo,
		maxAmmo = model.Configurations.MaxAmmo,
		damageAmount = model.Configurations.Damage.Value,
		explosionRadius = model.Configurations.ExplosionRadius.Value,
		blastPressure = model.Configurations:FindFirstChild("BlastPressure") and model.Configurations.BlastPressure.Value or 500000,
		bulletSpeed = model.Configurations:FindFirstChild("BulletSpeed") and model.Configurations.BulletSpeed.Value or 3500,
		maxRange = model.Configurations.MaxRange,
		baseComponent = model:WaitForChild("BaseComponent"),
		horizontalComponent = model:WaitForChild("HorizontalComponent"),
		verticalComponent = model.HorizontalComponent:WaitForChild("VerticalComponent"),
		gunBarrel = model.HorizontalComponent.VerticalComponent:WaitForChild("GunBarrel"),
		clientConnector = model.Remotes.ClientConnector,
		damageConnector = model.Remotes.DamageConnector,
		externalFunctions = externalFunctions,
		currentYaw = 0,
		currentPitch = 0,
		barrelRoll = 0,
		canLerp = true,
		canBreak = false,
		hasStarted = false,
		canFire = false,
		canCancel = false,
		lastEngageTime = 0,
		smoothedVel = Vector3.zero,
		isOnTarget = false,
		hasLOS = false,
		losBlockedTime = 0,
		interceptPos = nil,
		prevTargetPos = nil,
		prevTargetVel = nil,
		burstActive = true,
		burstTimer = 0,
		evalTimer = 0,
		barrelHeat = 0,
		isOverheated = false,
		overheatCoolTimer = 0,
		isReloading = false,
		isFiring = false,
		barrelRollSpeed = 0,
		TargetUi = model.StatsDisplay.SurfaceGui.Target,
		AmmoUi = model.StatsDisplay.SurfaceGui.Amunition,
		AmmUiM = model.AmmoDisplayMoveable.SurfaceGui.Amunition,
		AngleUi = model.StatsDisplay.SurfaceGui.Angle,
		DisabledUi = model.StatsDisplay.SurfaceGui.Disabled,
		RangeUi = model.StatsDisplay.SurfaceGui:FindFirstChild("Range"),
	}
	unit.cachedAmmoText = -1
	unit.cachedTargetText = ""
	unit.cachedDisabledText = ""
	unit.lastAngleUiUpdate = 0
	unit.DisabledUi.Text = "Disabled: False"
	unit.AmmoUi.Text = "Ammunition: "..tostring(unit.ammo.Value).."/"..tostring(unit.maxAmmo.Value)
	unit.AmmUiM.Text = tostring(unit.ammo.Value).."/"..tostring(unit.maxAmmo.Value)
	if unit.RangeUi then
		unit.RangeUi.Text = "Range: "..tostring(unit.maxRange.Value).." Stds"
		unit.maxRange.Changed:Connect(function(value)
			if unit.RangeUi and unit.RangeUi.Parent then
				unit.RangeUi.Text = "Range: "..tostring(value).." Stds"
			end
		end)
	end
	unit.originalDurabilities = {}
	unit.originalCFrames = {}
	unit.originalTransparencies = {}
	unit.originalCanCollide = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			unit.originalCFrames[p] = p.CFrame
			unit.originalTransparencies[p] = p.Transparency
			unit.originalCanCollide[p] = p.CanCollide
		end
		if p:IsA("NumberValue") or p:IsA("IntValue") then
			if p.Name == "Durability" or p.Name == "Disabled_Durability" then
				unit.originalDurabilities[p] = p.Value
				p.Changed:Connect(function()
					if unit.isBroken then return end
					local isDead = false
					for d, _ in pairs(unit.originalDurabilities) do
						if d.Value <= 0 then
							isDead = true
							break
						end
					end
					if isDead then
						unit.isBroken = true
						unit.model:SetAttribute("CramEnabled", false)
						unit.model:SetAttribute("CramBroken", true)
						if unit.DisabledUi then unit.DisabledUi.Text = "Disabled: BROKEN" end

						local center = unit.baseComponent.Position
						local exp = Instance.new("Explosion")
						exp.Position = center
						exp.BlastRadius = 15
						exp.BlastPressure = 0
						exp.DestroyJointRadiusPercent = 0
						exp.Parent = workspace

						exp.Hit:Connect(function(hitPart, dist)
							local hum = hitPart.Parent:FindFirstChildOfClass("Humanoid")
							if hum and hum.Health > 0 then
								if not exp:GetAttribute(tostring(hum)) then
									exp:SetAttribute(tostring(hum), true)
									hum:TakeDamage(100)
								end
							end
						end)

						local basePos = center

						local debrisFolder = workspace:FindFirstChild("CRAM_Debris")
						if not debrisFolder then
							debrisFolder = Instance.new("Folder")
							debrisFolder.Name = "CRAM_Debris"
							debrisFolder.Parent = workspace
						end

						local sndPart = Instance.new("Part")
						sndPart.Name = "ExplosionSoundEmitter"
						sndPart.Anchored = true
						sndPart.CanCollide = false
						sndPart.Transparency = 1
						sndPart.Size = Vector3.new(1, 1, 1)
						sndPart.Position = center
						sndPart.Parent = debrisFolder

						local snd = Instance.new("Sound")
						snd.SoundId = "rbxassetid://107446906998691"
						snd.Volume = 5
						snd.RollOffMode = Enum.RollOffMode.LinearSquare
						snd.RollOffMinDistance = 1
						snd.RollOffMaxDistance = 250
						snd.Parent = sndPart
						snd:Play()

						task.delay(10, function()
							if sndPart then sndPart:Destroy() end
						end)

						local parts = {}
						for _, pt in ipairs(model:GetDescendants()) do
							if pt:IsA("BasePart") then
								table.insert(parts, pt)
							end
						end

						for _, pt in ipairs(parts) do
							pt.Parent = debrisFolder
							pt.Anchored = false
							for _, w in ipairs(pt:GetJoints()) do
								w:Destroy()
							end
							local dir = (pt.Position - basePos).Unit
							if dir.Magnitude ~= dir.Magnitude then dir = Vector3.new(0, 1, 0) end
							pt.AssemblyLinearVelocity = dir * math.random(50, 120) + Vector3.new(0, math.random(30, 80), 0)
							pt.AssemblyAngularVelocity = Vector3.new(math.random(-10,10), math.random(-10,10), math.random(-10,10))

							task.delay(5, function()
								if pt.Parent then
									pt.Anchored = true
									pt.CanCollide = false
									local ts = game:GetService("TweenService")
									local tw = ts:Create(pt, TweenInfo.new(2), {Transparency = 1})
									tw:Play()
									tw.Completed:Connect(function()
										pt:Destroy()
									end)
								end
							end)
						end

						if _G.DecommissionCRAM then
							_G.DecommissionCRAM(unit.model)
						end
					end
				end)
			end
		end
	end

	unit.horizParts = { unit.horizontalComponent, unit.horizontalComponent:WaitForChild("RotationalComponent") }
	unit.vertParts = { unit.verticalComponent, unit.verticalComponent:WaitForChild("RotatePart"), model:WaitForChild("AmmoDisplayMoveable") }
	unit.spinParts = { unit.gunBarrel, unit.gunBarrel:WaitForChild("Direction"), unit.gunBarrel:WaitForChild("Muzzle") }
	unit.originBaseC0 = unit.baseComponent.CFrame:ToObjectSpace(unit.horizontalComponent.CFrame)
	unit.originVertC0 = unit.horizontalComponent.CFrame:ToObjectSpace(unit.verticalComponent.CFrame)
	local function createWeld(part0, part1)
		if not part0 or not part1 then return end
		local w = Instance.new("Weld")
		w.Part0 = part0
		w.Part1 = part1
		w.C0 = part0.CFrame:Inverse() * part1.CFrame
		w.Parent = part0
		part1.Anchored = false
		return w
	end

	for _, p in pairs(unit.horizParts) do
		if p ~= unit.horizontalComponent then createWeld(unit.horizontalComponent, p) end
	end
	for _, p in pairs(unit.vertParts) do
		if p ~= unit.verticalComponent then createWeld(unit.verticalComponent, p) end
	end
	for _, p in pairs(unit.spinParts) do
		if p ~= unit.gunBarrel then createWeld(unit.gunBarrel, p) end
	end

	unit.yawWeld = Instance.new("Weld")
	unit.yawWeld.Part0 = unit.baseComponent
	unit.yawWeld.Part1 = unit.horizontalComponent
	unit.yawWeld.C0 = unit.originBaseC0
	unit.yawWeld.Parent = unit.baseComponent
	unit.horizontalComponent.Anchored = false

	unit.pitchWeld = Instance.new("Weld")
	unit.pitchWeld.Part0 = unit.horizontalComponent
	unit.pitchWeld.Part1 = unit.verticalComponent
	unit.pitchWeld.C0 = unit.originVertC0
	unit.pitchWeld.Parent = unit.horizontalComponent
	unit.verticalComponent.Anchored = false

	unit.originSpinC0 = unit.verticalComponent.CFrame:Inverse() * unit.gunBarrel.CFrame
	unit.spinWeld = Instance.new("Weld")
	unit.spinWeld.Part0 = unit.verticalComponent
	unit.spinWeld.Part1 = unit.gunBarrel
	unit.spinWeld.C0 = unit.originSpinC0
	unit.spinWeld.Parent = unit.verticalComponent
	unit.gunBarrel.Anchored = false
	local lastHitTime = 0
	local lastTraceDamage = 0
	unit.damageConnector.OnServerEvent:Connect(function(player, hitPosition, isFlak)
		local muzz = unit.gunBarrel and unit.gunBarrel:FindFirstChild("Muzzle")
		if muzz then
			local dMax = (getUnitConfig(unit) and getUnitConfig(unit).maxRange) or unit.maxRange.Value
			if (hitPosition - muzz.Position).Magnitude > dMax * 1.5 then return end
		end
		local now = os.clock()
		if now - lastHitTime < 0.05 then return end
		lastHitTime = now
		local cfg = getUnitConfig(unit)
		local baseExpRadius = (cfg and cfg.explosionRadius) or unit.explosionRadius
		local baseDamage = (cfg and cfg.damage) or unit.damageAmount
		local radius = math.min(25, isFlak and (baseExpRadius * 1.5) or baseExpRadius)
		local damage = isFlak and (baseDamage * 0.85) or baseDamage
		local traceDamage = now - lastTraceDamage >= 0.25
		if traceDamage then
			lastTraceDamage = now
			trace("CRAM TRACE damage event", unit.model.Name, tostring(hitPosition), "radius", radius, "damage", damage)
		end
		local hitCache = {}
		local modelsChecked = {}
		local parts = workspace:GetPartBoundsInRadius(hitPosition, radius)
		for _, hitPart in ipairs(parts) do
			local directDur = findDamageValue(nil, hitPart)
			if directDur and not hitCache[directDur] then
				hitCache[directDur] = true
				directDur.Value = math.max(0, directDur.Value - damage)
			end
			local mdl = resolveVehicleModel(hitPart) or hitPart:FindFirstAncestorOfClass("Model")
			if mdl and mdl ~= workspace and not modelsChecked[mdl] then
				modelsChecked[mdl] = true
				local wasAlive = RadarAPI.isAlive(mdl)
				if wasAlive then
					RadarAPI.damage(mdl, damage)
				end
				local dur = findDamageValue(mdl, hitPart)
				if dur and not hitCache[dur] then
					hitCache[dur] = true
					local beforeDur = dur.Value
					dur.Value = math.max(0, dur.Value - damage)
					trace("CRAM TRACE damage durability", mdl.Name, dur.Name, beforeDur, dur.Value)
				end
				local hum = mdl:FindFirstChildOfClass("Humanoid")
				if hum and not hitCache[hum] then
					hitCache[hum] = true
					local Players = game:GetService("Players")
					if Players:GetPlayerFromCharacter(mdl) then
						hum:TakeDamage(10)
					else
						hum:TakeDamage(damage)
					end
				end
				local isDead = (dur and dur.Value <= 0) or (hum and hum.Health <= 0) or not RadarAPI.isAlive(mdl)
				if isDead then
					local cbt = mdl:FindFirstChild("CanBeTargetted", true)
					if cbt and cbt:IsA("BoolValue") and cbt.Value ~= false then
						cbt.Value = false
					end
					local statusMain = mdl:FindFirstChild("StatusMain")
					if statusMain and not hitCache[statusMain] then
						hitCache[statusMain] = true
						for _, b in ipairs(statusMain:GetChildren()) do
							if b:IsA("BoolValue") and b.Value == true then
								b.Value = false
							end
						end
					end
					local CollectionService = game:GetService("CollectionService")
					CollectionService:RemoveTag(mdl, "CRAM_Vehicle")
					for _, desc in ipairs(mdl:GetDescendants()) do
						CollectionService:RemoveTag(desc, "CRAM_Vehicle")
					end
				end
			end
		end
	end)
	local bSmoke = Instance.new("ParticleEmitter")
	bSmoke.Name = "BarrelHeatSmoke"
	bSmoke.Texture = "rbxassetid://83532853335218"
	bSmoke.Color = ColorSequence.new(Color3.fromRGB(180, 180, 180))
	bSmoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.5, 0.85),
		NumberSequenceKeypoint.new(1, 1)
	})
	bSmoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 2.0)
	})
	bSmoke.Lifetime = NumberRange.new(0.8, 1.4)
	bSmoke.Speed = NumberRange.new(2, 5)
	bSmoke.Rate = 0
	bSmoke.Enabled = false
	bSmoke.Parent = unit.gunBarrel.Muzzle
	unit.barrelSmokeEmitter = bSmoke
	task.spawn(function()
		local wasFiring = false
		local loopTimer = 0
		while unit.model and unit.model.Parent do
			local dt = task.wait(0.03)
			local sound = unit.baseComponent:FindFirstChild("CIWS Firing")
			local s2 = unit.baseComponent:FindFirstChild("CIWS FiringDist")
			if not sound or not s2 then break end
			if unit.isFiring == true then
				if not wasFiring then
					wasFiring = true
					loopTimer = 0.48
					sound.TimePosition = 0
					sound:Play()
					s2.TimePosition = 0
					s2:Play()
				else
					loopTimer = loopTimer - dt
					if loopTimer <= 0 then
						loopTimer = 0.47
						sound.TimePosition = 0.5
						sound:Play()
						s2.TimePosition = 0.5
						s2:Play()
					end
				end
			else
				if wasFiring then
					wasFiring = false
					loopTimer = 0
					fireDown(unit)
				end
			end
		end
	end)
	table.insert(ciwsUnits, unit)
	model.Destroying:Connect(function() setupModels[model] = nil end)
end
local hookedFolders = {}
local function hookFolder(folder)
	if not folder or not folder:IsA("Folder") or hookedFolders[folder] then return end
	hookedFolders[folder] = true
	for _, child in ipairs(folder:GetChildren()) do
		task.defer(function()
			setupCIWS(child)
		end)
	end
	folder.ChildAdded:Connect(function(child)
		task.defer(function()
			setupCIWS(child)
		end)
	end)
end
hookFolder(ciwsFolder)
workspace.ChildAdded:Connect(function(child)
	if child.Name == "Ciws" and child:IsA("Folder") then
		hookFolder(child)
	end
end)
findDamageValue = function(model, part)
	local names = {"durability", "health", "hitpoints", "armor", "integrity", "hull", "damage"}
	local function valid(item)
		return item and (item:IsA("NumberValue") or item:IsA("IntValue")) and item.Value > 0
	end
	if part then
		for _, name in ipairs(names) do
			local item = part:FindFirstChild(name:gsub("^%l", string.upper))
			if valid(item) then return item end
		end
		for _, item in ipairs(part:GetChildren()) do
			if valid(item) then
				local low = string.lower(item.Name)
				for _, name in ipairs(names) do
					if string.find(low, name, 1, true) then return item end
				end
			end
		end
	end
	if model and model:IsA("Model") then
		for _, item in ipairs(model:GetDescendants()) do
			if valid(item) and string.lower(item.Name) ~= "maxhealth" then
				local low = string.lower(item.Name)
				for _, name in ipairs(names) do
					if string.find(low, name, 1, true) then return item end
				end
			end
		end
	end
	return nil
end
findDamageAttribute = function(model, part)
	local names = {"durability", "health", "hitpoints", "armor", "integrity", "hull", "damage"}
	local function read(owner)
		if not owner then return nil end
		for key, value in pairs(owner:GetAttributes()) do
			if type(value) == "number" then
				local low = string.lower(key)
				for _, name in ipairs(names) do
					if string.find(low, name, 1, true) then
						return owner, key, value
					end
				end
			end
		end
		return nil
	end
	local owner, key, value = read(part)
	if owner then return owner, key, value end
	return read(model)
end
local function applyShotDamage(unit, model, part)
	if not unit or not model or not model.Parent or not part or not part.Parent then return end
	local cfg = getUnitConfig(unit)
	local amount = (cfg and cfg.damage) or unit.damageAmount or 25
	RadarAPI.damage(model, amount)
end
local function isVehicleAlive(model)
	if not model or not model.Parent or not model:IsDescendantOf(workspace) then
		return false
	end
	if model:FindFirstChild("Destroyed") or model:FindFirstChild("Dead") or model:FindFirstChild("Exploded") or model:FindFirstChild("Wreck") then
		return false
	end
	return RadarAPI.isAlive(model)
end
local function getValidTargets()
	local targets = {}
	local rawTags = CollectionService:GetTagged("CRAMTarget")
	local seenTargets = {}
	for _, isTag in ipairs(rawTags) do
		if isTag:IsA("BoolValue") and isTag.Name == "CanBeTargetted" and isTag.Value == true and isTag:GetAttribute("CRAMDisabled") ~= true and isTag:IsDescendantOf(workspace) then
			local targPart = isTag:FindFirstChild("TargetPart") and isTag.TargetPart.Value or (isTag.Parent:IsA("BasePart") and isTag.Parent)
			local model = isTag:FindFirstChild("MainModel") and isTag.MainModel.Value or resolveVehicleModel(targPart or isTag.Parent)

			local isPlayer = false
			if model then
				if Players:GetPlayerFromCharacter(model) then
					isPlayer = true
				elseif not RadarAPI.classify(model) then
					for _, pl in ipairs(Players:GetPlayers()) do
						if pl.Character and (model == pl.Character or model:IsDescendantOf(pl.Character)) then
							isPlayer = true
							break
						end
					end
				end
			end
			if not isPlayer and model and not isBadTarget(model) and targPart and model:IsDescendantOf(workspace) and targPart:IsDescendantOf(workspace) then
				local alive = isVehicleAlive(model)
				if alive then
					if not seenTargets[targPart] then
						seenTargets[targPart] = true
						table.insert(targets, {part = targPart, model = model, hum = nil})
					end
				else
					isTag.Value = false
				end
			end
		end
	end
	local vehicleTags = CollectionService:GetTagged("CRAM_Vehicle")
	for _, part in ipairs(vehicleTags) do
		if part:IsDescendantOf(workspace) then
			local model = resolveVehicleModel(part)
			if model and not isBadTarget(model) then
				local isPlayer = false
				if Players:GetPlayerFromCharacter(model) then
					isPlayer = true
				elseif not RadarAPI.classify(model) then
					for _, pl in ipairs(Players:GetPlayers()) do
						if pl.Character and (model == pl.Character or model:IsDescendantOf(pl.Character)) then
							isPlayer = true
							break
						end
					end
				end
				if not isPlayer then
					local alive = isVehicleAlive(model)
					if alive and not seenTargets[part] then
						seenTargets[part] = true
						table.insert(targets, {part = part, model = model, hum = nil})
					end
				end
			end
		end
	end
	return targets
end
workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("BoolValue") and desc.Name == "CanBeTargetted" and desc.Value == true then
		CollectionService:AddTag(desc, "CRAMTarget")
	end
end)
task.spawn(function()
	while true do
		task.wait(0.15)
		for i = #ciwsUnits, 1, -1 do
			if not ciwsUnits[i].model or not ciwsUnits[i].model.Parent then
				table.remove(ciwsUnits, i)
			end
		end
		local targets = getValidTargets()
		local assignedTargets = {}
		for _, unit in ipairs(ciwsUnits) do
			local cfg = getUnitConfig(unit)
			if cfg and cfg.enabled == false then
				clearTarget(unit, "unit disabled")
				continue
			end
			local effectiveRange = (cfg and cfg.maxRange) or unit.maxRange.Value
			if unit.target and unit.target.Parent then
				local isStillValid = false
				for _, t in ipairs(targets) do
					if t.part == unit.target and isTargetAllowed(unit, t.model) then
						isStillValid = true
						local origin = unit.baseComponent.Position
						local distFromBase = (t.part.Position - origin).Magnitude
						if distFromBase > effectiveRange then
							isStillValid = false
						end
						if isStillValid then
							assignedTargets[t.part] = true
						end
						break
					end
				end
			end
		end
		for _, t in ipairs(targets) do
			if not assignedTargets[t.part] then
				local bestUnit = nil
				local bestDist = math.huge
				for _, unit in ipairs(ciwsUnits) do
					local cfg = getUnitConfig(unit)
					if (not cfg or cfg.enabled ~= false) and isTargetAllowed(unit, t.model) then
						local effectiveRange = (cfg and cfg.maxRange) or unit.maxRange.Value
						if unit.ammo.Value > 0 and unit.target == nil then
							local dist = (unit.baseComponent.Position - t.part.Position).Magnitude
							if dist < effectiveRange and dist < bestDist then
								local origin = unit.baseComponent.Position
								if checkLineOfSight(unit, t.part.Position, t.model) then
									bestUnit = unit
									bestDist = dist
								end
							end
						end
					end
				end
				if bestUnit and RadarAPI.claimTarget(bestUnit.model.Name, t.part) then
					bestUnit.target = t.part
					bestUnit.targetHum = t.hum
					bestUnit.targetModel = t.model
					traceTargetSnapshot(bestUnit, t.model, t.part, t.hum)
					assignedTargets[t.part] = true
				end
			end
		end
		for _, unit in ipairs(ciwsUnits) do
			local cfg = getUnitConfig(unit)
			if (not cfg or cfg.enabled ~= false) then
				local effectiveRange = (cfg and cfg.maxRange) or unit.maxRange.Value
				if unit.ammo.Value > 0 and unit.target == nil then
					local bestTarget, bestHum, bestModel, bestDist = nil, nil, nil, math.huge
					for _, t in ipairs(targets) do
						if not assignedTargets[t.part] and isTargetAllowed(unit, t.model) then
							local dist = (unit.baseComponent.Position - t.part.Position).Magnitude
							if dist < effectiveRange and dist < bestDist then
								local origin = unit.baseComponent.Position
								if checkLineOfSight(unit, t.part.Position, t.model) then
									bestTarget, bestHum, bestModel, bestDist = t.part, t.hum, t.model, dist
								end
							end
						end
					end
					if bestTarget and RadarAPI.claimTarget(unit.model.Name, bestTarget) then
						unit.target = bestTarget
						unit.targetHum = bestHum
						unit.targetModel = bestModel
						assignedTargets[bestTarget] = true
					end
				end
			end
		end
	end
end)
RunService.Heartbeat:Connect(function(dt)
	local maxSlewRate = math.rad(165)
	for _, unit in ipairs(ciwsUnits) do
		local cfg = getUnitConfig(unit)
		if cfg and cfg.enabled == false then
			unit.isOnTarget = false
			unit.isFiring = false
			unit.hasLOS = false
			unit.barrelRollSpeed = math.max(0, (unit.barrelRollSpeed or 0) - (dt * 120))
			unit.barrelRoll = unit.barrelRoll + math.rad((unit.barrelRollSpeed or 0) * dt * 60)
			if unit.yawWeld then unit.yawWeld.C0 = unit.originBaseC0 * CFrame.Angles(0, unit.currentYaw, 0) end
			if unit.pitchWeld then unit.pitchWeld.C0 = unit.originVertC0 * CFrame.Angles(unit.currentPitch, 0, 0) end
			if unit.spinWeld then unit.spinWeld.C0 = unit.originSpinC0 * CFrame.Angles(0, 0, unit.barrelRoll) end
			continue
		end

		local effectiveRange = (cfg and cfg.maxRange) or unit.maxRange.Value
		local effectiveSpeed = (cfg and cfg.bulletSpeed) or unit.bulletSpeed or 3500
		local effectiveLead = (cfg and cfg.leadCompensation) or 1.0
		local targetIsValid = false

		if unit.target ~= nil then
			local tag = unit.targetModel and unit.targetModel:FindFirstChild("CanBeTargetted", true)
			local tagValid = false
			if tag and tag:IsA("BoolValue") and tag.Value == true and tag:GetAttribute("CRAMDisabled") ~= true then
				tagValid = true
			elseif unit.target and CollectionService:HasTag(unit.target, "CRAM_Vehicle") then
				tagValid = true
			end

			local isTargetDead = unit.targetModel and not RadarAPI.isAlive(unit.targetModel)

			if isTargetDead then
				tagValid = false
			end

			if not unit.target.Parent or not tagValid or not isTargetAllowed(unit, unit.targetModel) then
				clearTarget(unit, "tag or authorization invalid")
				unit.TargetUi.Text = "Target: None"
				unit.targetValue.Value = nil
				fireDown(unit)
				if unit.externalFunctions then
					unit.externalFunctions.InitiateMuzzle(false)
					unit.externalFunctions.RotateBarrel("Stop")
				end
			else
				if not unit.targetMainPart or not unit.targetMainPart.Parent then
					if unit.targetModel and unit.targetModel.Parent then
						unit.targetMainPart = getTargetMainPart(unit.targetModel)
					end
					if not unit.targetMainPart or not unit.targetMainPart.Parent then
						unit.targetMainPart = unit.target
					end
				end

				local targetPos = unit.targetMainPart.Position
				local rawVel = unit.targetMainPart.AssemblyLinearVelocity or Vector3.zero
				local targetVel = rawVel
				if rawVel.Magnitude < 5 and unit.prevTargetPos and dt > 0.0001 then
					targetVel = (targetPos - unit.prevTargetPos) / dt
				end
				unit.prevTargetPos = targetPos

				if not unit.filteredVel then
					unit.filteredVel = targetVel
					unit.targetAcc = Vector3.zero
				else
					local filterFactor = math.clamp(dt * 14, 0.2, 0.5)
					local prevF = unit.filteredVel
					unit.filteredVel = unit.filteredVel:Lerp(targetVel, filterFactor)
					if dt > 0.0001 then
						local rawAcc = (unit.filteredVel - prevF) / dt
						unit.targetAcc = (unit.targetAcc or Vector3.zero):Lerp(rawAcc, 0.25)
					end
				end
				local effectiveAimVel = unit.filteredVel

				local muzzle = unit.gunBarrel:FindFirstChild("Muzzle")
				local originPos = muzzle and muzzle.Position or unit.verticalComponent.Position
				local dist = (unit.verticalComponent.Position - targetPos).Magnitude

				if dist > effectiveRange then
					unit.outOfRangeTime = (unit.outOfRangeTime or 0) + dt
					trace("CRAM TRACE range", unit.model.Name, unit.targetModel and unit.targetModel.Name or "none", "distance", dist, "limit", effectiveRange, "time", unit.outOfRangeTime)
					if unit.outOfRangeTime >= 1.5 then
						clearTarget(unit, "out of range")
						unit.TargetUi.Text = "Target: None"
					end
				else
					unit.outOfRangeTime = 0
					targetIsValid = true
					if dist > 5 then
						local interceptPos = CalculateIntercept(originPos, targetPos, effectiveAimVel, effectiveSpeed, unit.targetAcc, effectiveLead)
						local maxRangeVal = effectiveRange * 1.5
						local drift = interceptPos - targetPos
						if drift.Magnitude > maxRangeVal then
							interceptPos = targetPos + drift.Unit * maxRangeVal
						end
						unit.interceptPos = interceptPos

						local relativeIntercept = unit.baseComponent.CFrame:PointToObjectSpace(interceptPos)
						local targetYaw = math.atan2(-relativeIntercept.X, -relativeIntercept.Z)
						local diffY = targetYaw - unit.currentYaw
						while diffY < -math.pi do diffY = diffY + math.pi * 2 end
						while diffY > math.pi do diffY = diffY - math.pi * 2 end
						local maxStep = maxSlewRate * dt
						unit.currentYaw = unit.currentYaw + math.clamp(diffY, -maxStep, maxStep)

						local targetPitch = math.atan2(relativeIntercept.Y, math.sqrt(relativeIntercept.X ^ 2 + relativeIntercept.Z ^ 2))
						local diffP = targetPitch - unit.currentPitch
						local pitchStep = math.clamp(diffP, -maxStep, maxStep)
						unit.currentPitch = math.clamp(unit.currentPitch + pitchStep, math.rad(-15), math.rad(85))

						local direction = unit.gunBarrel:FindFirstChild("Direction")
						local angleOnTarget = math.abs(diffY) < 0.05 and math.abs(diffP) < 0.05

						local hasLOS, blocker = checkLineOfSight(unit, interceptPos, unit.targetModel)
						local boreClear = isBoreClear(unit, math.min(dist, 100))

						if not hasLOS or not boreClear then
							unit.hasLOS = false
							unit.isOnTarget = false
							unit.losBlockedTime = (unit.losBlockedTime or 0) + dt
							unit.TargetUi.Text = not hasLOS and "LOS BLOCKED" or "BORE OBSTRUCTED"
							if unit.isFiring then
								unit.isFiring = false
								fireDown(unit)
								if unit.externalFunctions then unit.externalFunctions.InitiateMuzzle(false) end
							end
							if unit.losBlockedTime >= 1.5 then
								clearTarget(unit, "los blocked timeout")
								unit.TargetUi.Text = "Target: None"
								targetIsValid = false
							end
						else
							unit.hasLOS = true
							unit.losBlockedTime = 0
							unit.isOnTarget = angleOnTarget
							unit.AngleUi.Text = angleOnTarget and "LOCKED" or "SLEWING..."
						end
					else
						unit.isOnTarget = false
					end
				end
			end
		end

		if not targetIsValid then
			unit.isOnTarget = false
			if unit.AngleUi and unit.target == nil then unit.AngleUi.Text = "IDLE" end
		end

		local maxHeat = (cfg and cfg.overheatThreshold) or 100
		if unit.isFiring then
			unit.barrelHeat = math.min(maxHeat, unit.barrelHeat + (dt * 10))
			if unit.barrelHeat >= maxHeat and not unit.isOverheated then
				unit.isOverheated = true
				unit.burstActive = false
				unit.overheatCoolTimer = 2.5
				fireDown(unit)
				unit.externalFunctions.InitiateMuzzle(false)
			end
		else
			local coolRate = unit.isOverheated and 28 or 15
			unit.barrelHeat = math.max(0, unit.barrelHeat - (dt * coolRate))
		end

		if unit.barrelSmokeEmitter then
			if unit.barrelHeat > (maxHeat * 0.35) or unit.isOverheated then
				unit.barrelSmokeEmitter.Enabled = true
				unit.barrelSmokeEmitter.Rate = math.clamp((unit.barrelHeat - (maxHeat * 0.35)) * 0.5, 4, 24)
			else
				unit.barrelSmokeEmitter.Enabled = false
				unit.barrelSmokeEmitter.Rate = 0
			end
		end

		local burstDur = (cfg and cfg.burstDuration) or 1.6
		local evalPauseTime = (cfg and cfg.evalPause) or 0.75
		if unit.isOverheated then
			unit.overheatCoolTimer = unit.overheatCoolTimer - dt
			if unit.overheatCoolTimer <= 0 or unit.barrelHeat <= (maxHeat * 0.15) then
				unit.isOverheated = false
				unit.burstActive = true
				unit.burstTimer = 0
				unit.barrelHeat = 0
				if unit.target ~= nil and unit.canFire == true and unit.isOnTarget == true and unit.hasLOS == true then fireUp(unit) end
			end
		elseif unit.target ~= nil and unit.canFire == true and not unit.isReloading then
			if unit.burstActive then
				unit.burstTimer = unit.burstTimer + dt
				if unit.burstTimer >= burstDur then
					unit.burstActive = false
					unit.evalTimer = evalPauseTime
					fireDown(unit)
					unit.externalFunctions.InitiateMuzzle(false)
				end
			else
				unit.evalTimer = unit.evalTimer - dt
				unit.TargetUi.Text = "RADAR EVAL..."
				if unit.evalTimer <= 0 then
					unit.burstActive = true
					unit.burstTimer = 0
					if unit.isOnTarget == true and unit.hasLOS == true then fireUp(unit) end
				end
			end
		end

		if unit.canFire and unit.burstActive and not unit.isOverheated and not unit.isReloading and unit.isOnTarget and unit.hasLOS then
			unit.barrelRollSpeed = 100
		else
			unit.barrelRollSpeed = math.max(0, (unit.barrelRollSpeed or 0) - (dt * 120))
		end
		unit.barrelRoll = unit.barrelRoll + math.rad((unit.barrelRollSpeed or 0) * dt * 60)

		if unit.yawWeld then unit.yawWeld.C0 = unit.originBaseC0 * CFrame.Angles(0, unit.currentYaw, 0) end
		if unit.pitchWeld then unit.pitchWeld.C0 = unit.originVertC0 * CFrame.Angles(unit.currentPitch, 0, 0) end
		if unit.spinWeld then unit.spinWeld.C0 = unit.originSpinC0 * CFrame.Angles(0, 0, unit.barrelRoll) end
	end
end)
task.spawn(function()
	while true do
		task.wait(0.04)
		for _, unit in ipairs(ciwsUnits) do
			local cfg = getUnitConfig(unit)
			local effectiveRange = (cfg and cfg.maxRange) or unit.maxRange.Value
			local effectiveSpread = (cfg and cfg.spreadAngle) or 0.35
			local reloadTimeSec = (cfg and cfg.reloadTime) or 4.0
			local targetDist = (unit.target and unit.target.Parent) and (unit.baseComponent.Position - unit.target.Position).Magnitude or math.huge
			local tag = findTargetTag(unit.target, unit.targetModel)
			local isTagActive = false
			if tag and tag:IsA("BoolValue") and tag.Value == true and tag:GetAttribute("CRAMDisabled") ~= true then
				isTagActive = true
			elseif unit.target and CollectionService:HasTag(unit.target, "CRAM_Vehicle") then
				isTagActive = true
			end
			local targetAlive = unit.targetModel and RadarAPI.isAlive(unit.targetModel)
			unit.debugTimer = (unit.debugTimer or 0) - 0.04
			if debugEnabled() and unit.debugTimer <= 0 then
				local gateKey = table.concat({tostring(targetAlive == true), tostring(isTagActive == true), tostring(unit.targetModel and isTargetAllowed(unit, unit.targetModel) == true), tostring(targetDist <= effectiveRange), tostring(unit.canFire == true), tostring(unit.isOnTarget == true), tostring(unit.hasLOS == true), tostring(unit.burstActive == true)}, "|")
				if unit.targetModel or gateKey ~= unit.lastGateKey then
					trace("CRAM TRACE gate", unit.model.Name, unit.targetModel and unit.targetModel.Name or "none", "alive", targetAlive == true, "tag", isTagActive == true, "allow", unit.targetModel and isTargetAllowed(unit, unit.targetModel) == true, "range", targetDist <= effectiveRange, "fire", unit.canFire == true, "aim", unit.isOnTarget == true, "los", unit.hasLOS == true, "burst", unit.burstActive == true)
					unit.lastGateKey = gateKey
				end
				unit.debugTimer = 1			
			end
			if (not cfg or cfg.enabled ~= false) and unit.target ~= nil and targetAlive and isTagActive and isTargetAllowed(unit, unit.targetModel) and targetDist <= effectiveRange and unit.canFire == true and unit.isOnTarget == true and unit.hasLOS == true and unit.burstActive == true and not unit.isOverheated and not unit.isReloading then
				if unit.ammo.Value > 0 then
					unit.ammo.Value -= 1
					unit.isFiring = true
					local muzzle = unit.gunBarrel:FindFirstChild("Muzzle")
					local direction = unit.gunBarrel:FindFirstChild("Direction")
					if muzzle and direction then
						local aimDir = (direction.Position - muzzle.Position).Unit
						local spreadRad = math.rad(effectiveSpread)
						local rx = (math.random() - 0.5) * spreadRad
						local ry = (math.random() - 0.5) * spreadRad
						local bulletDir = (CFrame.lookAt(Vector3.zero, aimDir) * CFrame.Angles(rx, ry, 0)).LookVector
						unit.clientConnector:FireAllClients(muzzle.Position, bulletDir)
						local shotPart = unit.targetMainPart or unit.target
						local shotModel = unit.targetModel
						if shotPart and shotModel and shotPart.Parent and shotModel.Parent then
							applyShotDamage(unit, shotModel, shotPart)
						end
						if unit.baseComponent and not unit.baseComponent.Anchored then
							local recoilDir = -aimDir
							local safeY = math.clamp(recoilDir.Y, -0.6, 0.4)
							local safeDir = Vector3.new(recoilDir.X, safeY, recoilDir.Z).Unit
							local impulse = safeDir * 1000
							unit.baseComponent:ApplyImpulseAtPosition(impulse, muzzle.Position)
						end
					end
					unit.externalFunctions.InitiateMuzzle(true)
				else
					unit.isFiring = false
					unit.isReloading = true
					unit.burstActive = false
					unit.TargetUi.Text = "RELOADING DRUM..."
					fireDown(unit)
					unit.externalFunctions.InitiateMuzzle(false)
					task.spawn(function()
						task.wait(reloadTimeSec)
						if not unit.model or not unit.model.Parent then return end
						local currentCfg = getUnitConfig(unit)
						local maxAmmoVal = (currentCfg and currentCfg.maxAmmo) or unit.maxAmmo.Value
						unit.ammo.Value = maxAmmoVal
						unit.isReloading = false
						unit.burstActive = true
						unit.burstTimer = 0
						unit.barrelHeat = 0
					end)
				end
			else
				unit.isFiring = false
				if unit.externalFunctions then
					unit.externalFunctions.InitiateMuzzle(false)
				end
			end
		end
	end
end)
task.spawn(function()
	while true do
		task.wait(0.2)
		for _, unit in ipairs(ciwsUnits) do
			local cfg = getUnitConfig(unit)
			local maxAmmoVal = (cfg and cfg.maxAmmo) or unit.maxAmmo.Value
			local maxHeatVal = (cfg and cfg.overheatThreshold) or 100
			local reloadTimeSec = (cfg and cfg.reloadTime) or 4.0
			if unit.cachedAmmoText ~= unit.ammo.Value then
				unit.cachedAmmoText = unit.ammo.Value
				unit.AmmoUi.Text = "Ammunition: "..tostring(unit.ammo.Value).."/"..tostring(maxAmmoVal)
				unit.AmmUiM.Text = tostring(unit.ammo.Value).."/"..tostring(maxAmmoVal)
			end
			if unit.targetValue.Value ~= unit.target then
				unit.targetValue.Value = unit.target
			end
			local newStatus = "Target: None"
			local newDisabled = "Disabled: False"
			if cfg and cfg.enabled == false then
				newStatus = "DISABLED"
				newDisabled = "Disabled: True"
			elseif unit.isReloading then
				newStatus = "RELOADING DRUM..."
			elseif unit.isOverheated then
				newStatus = "OVERHEAT ["..tostring(math.ceil((unit.barrelHeat / maxHeatVal) * 100)).."%]"
			elseif unit.target == nil then
				newStatus = "Target: None"
			elseif not unit.burstActive then
				newStatus = "RADAR EVAL..."
			else
				newStatus = "ENGAGING: "..tostring(unit.target.Name)
			end
			if Registry then
				local eId = Registry.findUnitByModel(unit.model)
				if eId then
					local e = Registry.getUnit(eId)
					if e then e.stats.status = string.gsub(newStatus, "Target: None", "IDLE") end
				end
			end
			if unit.cachedTargetText ~= newStatus then
				unit.cachedTargetText = newStatus
				unit.TargetUi.Text = newStatus
			end
			if unit.cachedDisabledText ~= newDisabled then
				unit.cachedDisabledText = newDisabled
				unit.DisabledUi.Text = newDisabled
			end
			if unit.target ~= nil and (not cfg or cfg.enabled ~= false) then
				if unit.ammo.Value <= 0 and not unit.isReloading then
					unit.isReloading = true
					unit.burstActive = false
					fireDown(unit)
					unit.externalFunctions.InitiateMuzzle(false)
					task.spawn(function()
						task.wait(reloadTimeSec)
						if not unit.model or not unit.model.Parent then return end
						local cCfg = getUnitConfig(unit)
						local mAmmo = (cCfg and cCfg.maxAmmo) or unit.maxAmmo.Value
						unit.ammo.Value = mAmmo
						unit.isReloading = false
						unit.burstActive = true
						unit.burstTimer = 0
						unit.barrelHeat = 0
					end)
				else
					if unit.hasStarted == false and unit.canBreak == false then
						unit.hasStarted = true
						unit.canBreak = true
						local now = os.clock()
						local needsWindUp = (now - unit.lastEngageTime > 20)
						unit.lastEngageTime = now
						if needsWindUp then
							local wnd = unit.baseComponent:FindFirstChild("FireWindUp")
							if wnd then wnd:Play() end
							task.spawn(function()
								local alarmDuration = wnd and wnd.TimeLength or 3.8
								if not alarmDuration or alarmDuration <= 0 then alarmDuration = 3.8 end
								task.wait(math.max(0, alarmDuration - 0.4))
								if unit.target == nil then
									unit.hasStarted = false
									unit.canBreak = false
									return
								end
								unit.externalFunctions.RotateBarrel("Start")
								task.wait(0.4)
								if not unit.model or not unit.model.Parent or unit.target == nil then
									unit.hasStarted = false
									unit.canBreak = false
									return
								end
								unit.canFire = true
								unit.hasStarted = false
							end)
						else
							unit.externalFunctions.RotateBarrel("Start")
							unit.canFire = true
							unit.hasStarted = false
						end
					end
				end
				local isDead = false
				if not unit.target or not unit.target.Parent or not unit.target:IsDescendantOf(workspace) then
					isDead = true
				elseif unit.targetModel and not RadarAPI.isAlive(unit.targetModel) then
					isDead = true
				end
				if isDead then
					unit.canCancel = false
					clearTarget(unit, "target dead or removed")
					unit.targetValue.Value = nil
					unit.lastEngageTime = os.clock()
					unit.TargetUi.Text = "Target: None"
					fireDown(unit)
					unit.externalFunctions.InitiateMuzzle(false)
					unit.canBreak = false
					unit.canFire = false
				end
			else
				if unit.canCancel == true then
					unit.canCancel = false
					unit.targetValue.Value = nil
					unit.lastEngageTime = os.clock()
					unit.TargetUi.Text = "Target: None"
					fireDown(unit)
					unit.externalFunctions.InitiateMuzzle(false)
					unit.canBreak = false
					unit.canFire = false
					unit.externalFunctions.RotateBarrel("Stop")
				end
			end
		end
	end
end)
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, unit in ipairs(ciwsUnits) do
			if unit.target ~= nil and unit.canLerp == false then
				unit.canLerp = true
			elseif unit.target == nil and unit.canLerp == true then
				unit.canLerp = false
			end
		end
	end
end)

