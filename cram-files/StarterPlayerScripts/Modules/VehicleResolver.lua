-- Modules/VehicleResolver.lua
-- Client-side vehicle identification, root model discovery, and target picking

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local VehicleResolver = {}

function VehicleResolver.cleanModelName(rawName)
	if not rawName then return "" end
	local n = tostring(rawName)
	n = string.gsub(n, "%s*#%d+", "")
	n = string.gsub(n, "%s*%(Clone%)", "")
	n = string.gsub(n, "%s*%(%d+%)", "")
	n = string.gsub(n, "_%d+$", "")
	return n
end

function VehicleResolver.isWorldModel(instance)
	if not instance then return true end
	if instance == workspace then return true end
	local node = instance
	while node and node ~= workspace do
		local rawName = node.Name or ""
		local key = string.lower(rawName)
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

function VehicleResolver.isTaggedAsVehicle(m)
	if not m then return false end
	if CollectionService:HasTag(m, "CRAM_Vehicle") then return true end
	for _, d in ipairs(m:GetDescendants()) do
		if CollectionService:HasTag(d, "CRAM_Vehicle") then return true end
	end
	return false
end

function VehicleResolver.getVehicleRootModel(part)
	if not part then return nil end
	if VehicleResolver.isWorldModel(part) then return nil end
	local cur = part:IsA("Model") and part or part:FindFirstAncestorOfClass("Model")
	if not cur or VehicleResolver.isWorldModel(cur) then return nil end
	local topModel = cur
	local node = cur
	while node and node.Parent and node.Parent ~= workspace do
		local p = node.Parent
		if VehicleResolver.isWorldModel(p) then
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
	if VehicleResolver.isWorldModel(topModel) then return nil end
	return topModel
end

function VehicleResolver.isVehicleOrTarget(m)
	if not m or not m:IsA("Model") or VehicleResolver.isWorldModel(m) then return false end
	if m == workspace or m.Name == "Ciws" or m.Name == "Inserter" or m.Name == "Model" then
		return false
	end
	if Players:GetPlayerFromCharacter(m) then return false end
	local hasUnanchored = false
	for _, item in ipairs(m:GetDescendants()) do
		if item:IsA("BasePart") and not item.Anchored then
			hasUnanchored = true
			break
		end
	end
	if not hasUnanchored then return false end
	local explicitVehicle = m:FindFirstChild("A-Chassis Tune", true)
		or m:FindFirstChildWhichIsA("VehicleSeat", true)
		or m:FindFirstChild("DriveSeat", true)
		or m:FindFirstChild("Drive", true)
		or m:FindFirstChild("CarRegenScript", true)
		or m:FindFirstChild("CanBeTargetted", true)
		or m:FindFirstChild("Durability", true)
		or m:FindFirstChild("Arsenal", true)
		or m:FindFirstChild("Crashed", true)
		or m:FindFirstChild("StatusMain", true)
		or m:FindFirstChild("Plane", true)
	local structuralVehicle = m:FindFirstChild("Engine", true)
		or m:FindFirstChild("Fuselage", true)
		or m:FindFirstChild("Cockpit", true)
		or m:FindFirstChild("RotorHitbox", true)
		or m:FindFirstChild("BulletHitbox", true)
	if explicitVehicle or structuralVehicle then return true end
	return false
end

function VehicleResolver.getBestTargetPart(mdl, fallbackPart)
	if not mdl then return fallbackPart end
	local vehSeat = mdl:FindFirstChild("DriveSeat", true) or mdl:FindFirstChildWhichIsA("VehicleSeat", true)
	if vehSeat and vehSeat:IsA("BasePart") then return vehSeat end
	local hrp = mdl:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp end
	local dur = mdl:FindFirstChild("Durability", true)
		or mdl:FindFirstChild("Health", true)
		or mdl:FindFirstChild("Arsenal", true)
		or mdl:FindFirstChild("Damage", true)
	if dur and dur.Parent and dur.Parent:IsA("BasePart") then return dur.Parent end
	for _, pName in ipairs({ "Engine", "Chassis", "Body", "Weight", "#Weight", "VehicleBase", "MAIN", "Fuselage", "Center", "Cockpit", "Hull" }) do
		local found = mdl:FindFirstChild(pName, true)
		if found and found:IsA("BasePart") then return found end
	end
	if mdl.PrimaryPart then return mdl.PrimaryPart end
	return mdl:FindFirstChildWhichIsA("BasePart", true) or fallbackPart
end

return VehicleResolver
