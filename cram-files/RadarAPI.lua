--[[
	RadarAPI

	A shared, reusable detection + damage + coordination layer for air-defense
	systems (C-RAM, SAM sites, flak batteries, whatever you build next).

	Each vehicle TYPE (helicopter, jet, ...) gets a "profile": a small table of
	functions that know how to recognize that type, find its best target part,
	check if it's alive, and apply damage to it correctly. Adding a new vehicle
	type later means adding one profile — nothing else needs to change.

	Multiple defense systems (e.g. two separate CIWS batteries, or a CIWS and a
	SAM site) can all `require` this same module. They share one detection
	cache (so they're not all re-scanning the workspace every 0.15s), and can
	register themselves + "claim" a target for a tick so two systems don't
	double-lock the same thing without you wanting that.

	USAGE (from a CIWS/SAM controller script)
	-------------------------------------------
	local RadarAPI = require(path.to.RadarAPI)

	-- once, at startup:
	RadarAPI.registerSystem("CIWS_Alpha", { maxRange = 6000 })

	-- every scan tick:
	local detected = RadarAPI.scan()
	for _, entry in ipairs(detected) do
		-- entry.model, entry.name, entry.profile, entry.targetPart
	end

	-- when you want to claim a target so another system backs off it:
	if RadarAPI.claimTarget("CIWS_Alpha", entry.targetPart) then
		-- go ahead and engage
	end

	-- when a shot lands:
	local destroyed = RadarAPI.damage(entry.model, 25)

	-- when the target dies or goes out of range:
	RadarAPI.releaseTarget(entry.targetPart)
--]]

local Players = game:GetService("Players")

local RadarAPI = {}

RadarAPI._systems = {}
RadarAPI._claims = {}
RadarAPI._logger = nil
RadarAPI._knownRaw = setmetatable({}, { __mode = "k" })
RadarAPI._watched = setmetatable({}, { __mode = "k" })

-- Register a logging function (e.g. your existing trace()/console function)
-- so RadarAPI can report detection reasoning into YOUR log instead of print().
-- The function receives a single already-formatted string.
function RadarAPI.setLogger(fn)
	RadarAPI._logger = fn
end

local function log(message)
	if RadarAPI._logger then
		RadarAPI._logger(message)
	end
end

local buildDiagnosticReport

-- Continuously watches a model for the rest of its lifetime: reparenting
-- (e.g. something moving it out from under the container scan() checks),
-- and changes to any damage/status value (Durability, Health, Crashed,
-- CanBeTargetted, engine/APU status bools). Every change gets logged via
-- whatever logger you registered with RadarAPI.setLogger(). Safe to call
-- repeatedly on the same model — it only hooks once.
local function watchModel(model)
	if RadarAPI._watched[model] then return end
	RadarAPI._watched[model] = true

	model.AncestryChanged:Connect(function(_, newParent)
		if not model.Parent then
			log("[RadarAPI] " .. model.Name .. " removed from game (no longer parented anywhere).")
			return
		end
		local pName = newParent and newParent.Name or "nil"
		local stillScannable = newParent and newParent.Name == "Model"
		log("[RadarAPI] " .. model.Name .. " reparented -> now under '" .. pName .. "'. Still under a 'Model' container: " .. tostring(stillScannable))
	end)

	local function hookValueIfRelevant(v)
		if not (v:IsA("NumberValue") or v:IsA("IntValue") or v:IsA("BoolValue")) then return end
		local lname = string.lower(v.Name)
		local relevant = string.find(lname, "durability", 1, true)
			or string.find(lname, "health", 1, true)
			or lname == "crashed"
			or lname == "canbetargetted"
			or lname == "apu"
			or string.find(lname, "engine", 1, true)
		if not relevant then return end
		v.Changed:Connect(function(newVal)
			log("[RadarAPI] " .. model.Name .. " -> " .. v:GetFullName() .. " changed to " .. tostring(newVal))
		end)
	end

	for _, d in ipairs(model:GetDescendants()) do
		hookValueIfRelevant(d)
	end
	model.DescendantAdded:Connect(hookValueIfRelevant)
end
RadarAPI.watchModel = watchModel
RadarAPI._cache = nil
RadarAPI._cacheTime = 0
RadarAPI._cacheTTL = 0.2

RadarAPI.Profiles = {}

RadarAPI.Profiles.Helicopter = {
	match = function(model)
		return model:FindFirstChild("Rotors", true) ~= nil
			or model:FindFirstChild("PilotSeat", true) ~= nil
			or model:FindFirstChild("RotorHitbox", true) ~= nil
			or model:FindFirstChild("BulletHitbox", true) ~= nil
	end,

	-- Collect every Durability-bearing hitbox part found on the model.
	getHitboxes = function(model)
		local hitboxes = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("NumberValue") and d.Name == "Durability" and d.Parent and d.Parent:IsA("BasePart") then
				table.insert(hitboxes, { part = d.Parent, tracker = d })
			end
		end
		return hitboxes
	end,

	getBestTargetPart = function(model)
		return model:FindFirstChild("BulletHitbox", true)
			or model:FindFirstChild("RotorHitbox", true)
			or model:FindFirstChild("PilotSeat", true)
			or model:FindFirstChildWhichIsA("VehicleSeat", true)
			or model.PrimaryPart
			or model:FindFirstChildWhichIsA("BasePart", true)
	end,

	-- Reduce every Durability value found by the hit amount. Falls back to a
	-- single generic Health value if no Durability values exist.
	applyDamage = function(model, amount)
		local hitboxes = RadarAPI.Profiles.Helicopter.getHitboxes(model)
		if #hitboxes > 0 then
			local anyLeft = false
			for _, hb in ipairs(hitboxes) do
				hb.tracker.Value = math.max(0, hb.tracker.Value - amount)
				if hb.tracker.Value > 0 then
					anyLeft = true
				end
			end
			return not anyLeft -- returns true if destroyed
		end
		local health = model:FindFirstChild("Health", true)
		if health and (health:IsA("NumberValue") or health:IsA("IntValue")) then
			health.Value = math.max(0, health.Value - amount)
			return health.Value <= 0
		end
		return false
	end,

	isAlive = function(model)
		local hitboxes = RadarAPI.Profiles.Helicopter.getHitboxes(model)
		if #hitboxes > 0 then
			for _, hb in ipairs(hitboxes) do
				if hb.tracker.Value > 0 then
					return true
				end
			end
			return false
		end
		local health = model:FindFirstChild("Health", true)
		if health then
			return health.Value > 0
		end
		return true -- no tracker found; assume alive rather than instantly despawn it
	end,
}

RadarAPI.Profiles.CombatJet = {
	match = function(model)
		return model:FindFirstChild("Afterburner", true) ~= nil
			or model:FindFirstChild("MainParts", true) ~= nil
	end,

	getBestTargetPart = function(model)
		return model:FindFirstChild("DamageHBox", true)
			or model:FindFirstChild("Cockpit", true)
			or model:FindFirstChildWhichIsA("VehicleSeat", true)
			or model.PrimaryPart
			or model:FindFirstChildWhichIsA("BasePart", true)
	end,

	-- On a hit: small chance to knock out a still-running engine or the APU
	-- (StatusMain bools: true = running fine, false = damaged/failed), then
	-- drain Health. When Health reaches zero, set Crashed = true.
	applyDamage = function(model, amount)
		local plane = model:FindFirstChild("Plane", true) or model

		local statusMain = plane:FindFirstChild("StatusMain", true)
		if statusMain then
			local candidates = {}
			for _, subsystemName in ipairs({ "ENGINE_LEFT", "ENGINE_RIGHT", "APU" }) do
				local v = statusMain:FindFirstChild(subsystemName)
				if v and v:IsA("BoolValue") and v.Value == true then
					table.insert(candidates, v)
				end
			end
			if #candidates > 0 and math.random() < 0.15 then
				candidates[math.random(1, #candidates)].Value = false
			end
		end

		local health = plane:FindFirstChild("Health", true)
		if health and (health:IsA("NumberValue") or health:IsA("IntValue")) then
			health.Value = math.max(0, health.Value - amount)
			if health.Value <= 0 then
				local crashed = plane:FindFirstChild("Crashed", true)
				if crashed and crashed:IsA("BoolValue") then
					crashed.Value = true
				end
				if statusMain then
					for _, subsystemName in ipairs({ "ENGINE_LEFT", "ENGINE_RIGHT", "APU" }) do
						local v = statusMain:FindFirstChild(subsystemName)
						if v and v:IsA("BoolValue") then
							v.Value = false
						end
					end
				end
				return true
			end
		end
		return false
	end,

	isAlive = function(model)
		local plane = model:FindFirstChild("Plane", true) or model
		local crashed = plane:FindFirstChild("Crashed", true)
		if crashed and crashed:IsA("BoolValue") and crashed.Value == true then
			return false
		end
		local health = plane:FindFirstChild("Health", true)
		if health then
			return health.Value > 0
		end
		return true
	end,
}

-- Fallback profile for anything that doesn't match a more specific one.
RadarAPI.Profiles.Generic = {
	match = function()
		return true
	end,

	getBestTargetPart = function(model)
		return model:FindFirstChildWhichIsA("VehicleSeat", true)
			or model.PrimaryPart
			or model:FindFirstChildWhichIsA("BasePart", true)
	end,

	applyDamage = function(model, amount)
		local tracker = model:FindFirstChild("Health", true) or model:FindFirstChild("Durability", true)
		if tracker and (tracker:IsA("NumberValue") or tracker:IsA("IntValue")) then
			tracker.Value = math.max(0, tracker.Value - amount)
			return tracker.Value <= 0
		end
		return false
	end,

	isAlive = function(model)
		local tracker = model:FindFirstChild("Health", true) or model:FindFirstChild("Durability", true)
		if tracker then
			return tracker.Value > 0
		end
		return true
	end,
}

-- Order matters: first matching profile wins. Put more specific profiles first.
RadarAPI.ProfileOrder = { "Helicopter", "CombatJet", "Generic" }

function RadarAPI.classify(model)
	for _, name in ipairs(RadarAPI.ProfileOrder) do
		local profile = RadarAPI.Profiles[name]
		if profile.match(model) then
			return name, profile
		end
	end
	return "Generic", RadarAPI.Profiles.Generic
end

-- ===========================================================================
-- DETECTION
-- ===========================================================================
-- Scans the Adonis `:insert` container (`Workspace.Model`) directly. This is
-- the single source of truth every registered system should call instead of
-- re-scanning the workspace themselves.

function RadarAPI.scan()
	local now = os.clock()
	if RadarAPI._cache and (now - RadarAPI._cacheTime) < RadarAPI._cacheTTL then
		return RadarAPI._cache
	end

	local detected = {}
	local seen = {}

	local function tryAddCandidate(child)
		if not child:IsA("Model") then return end
		if child.Name == "Model" then return end -- this is the staging container itself, not a vehicle
		if seen[child] then return end
		if Players:GetPlayerFromCharacter(child) then return end
		seen[child] = true

		if not RadarAPI._knownRaw[child] then
			RadarAPI._knownRaw[child] = true
			log(buildDiagnosticReport(child).summary)
			watchModel(child)
		end

		local profileName, profile = RadarAPI.classify(child)
		if profile.isAlive(child) then
			local targetPart = profile.getBestTargetPart(child)
			if targetPart then
				table.insert(detected, {
					model = child,
					name = child.Name,
					profile = profileName,
					targetPart = targetPart,
				})
			end
		end
	end

	-- Scan every "Model"-named staging container's children (right after insert).
	for _, container in ipairs(workspace:GetChildren()) do
		if container.Name == "Model" and (container:IsA("Model") or container:IsA("Folder")) then
			for _, child in ipairs(container:GetChildren()) do
				tryAddCandidate(child)
			end
		end
	end

	-- ALSO scan workspace's own direct children: vehicles get reparented out
	-- of the "Model" staging container to workspace root once they finish
	-- loading/settling, so they have to be findable here too.
	for _, child in ipairs(workspace:GetChildren()) do
		tryAddCandidate(child)
	end

	RadarAPI._cache = detected
	RadarAPI._cacheTime = now
	return detected
end

-- Force the next .scan() call to actually rescan instead of using the cache.
function RadarAPI.invalidateCache()
	RadarAPI._cache = nil
end

-- ===========================================================================
-- DAMAGE
-- ===========================================================================

function RadarAPI.damage(model, amount)
	local _, profile = RadarAPI.classify(model)
	return profile.applyDamage(model, amount)
end

function RadarAPI.isAlive(model)
	local _, profile = RadarAPI.classify(model)
	return profile.isAlive(model)
end

-- ===========================================================================
-- MULTI-SYSTEM COOPERATION
-- ===========================================================================
-- Any number of defense systems can register themselves here. This doesn't
-- force any particular behavior — it's just a shared registry + a simple
-- claim system so systems CAN coordinate if you want them to.

-- settings is any table you want — maxRange, whitelist, priority, whatever
-- your systems care about. Other systems can read RadarAPI.getSystems() to
-- see what else is active and adjust their own behavior.
function RadarAPI.registerSystem(name, settings)
	RadarAPI._systems[name] = settings or {}
end

function RadarAPI.unregisterSystem(name)
	RadarAPI._systems[name] = nil
end

function RadarAPI.updateSystemSettings(name, settings)
	if RadarAPI._systems[name] then
		for k, v in pairs(settings) do
			RadarAPI._systems[name][k] = v
		end
	end
end

function RadarAPI.getSystems()
	return RadarAPI._systems
end

-- Claim a target for a tick so a second system knows not to also lock onto
-- it. Returns true if the claim succeeded (either nobody held it, or you
-- already held it). Returns false if another system currently holds it.
function RadarAPI.claimTarget(systemName, targetPart)
	local currentOwner = RadarAPI._claims[targetPart]
	if currentOwner and currentOwner ~= systemName then
		return false
	end
	RadarAPI._claims[targetPart] = systemName
	return true
end

-- Release a claim. Call this when a system loses/kills/drops a target.
function RadarAPI.releaseTarget(targetPart)
	RadarAPI._claims[targetPart] = nil
end

-- Who (if anyone) currently holds a claim on this target.
function RadarAPI.getClaimOwner(targetPart)
	return RadarAPI._claims[targetPart]
end

-- Clean up claims on targets that no longer exist / aren't in the latest scan.
-- Call this occasionally (e.g. once per scan cycle) to avoid stale claims
-- piling up after a target dies or despawns.
function RadarAPI.pruneClaims()
	local stillDetected = {}
	for _, entry in ipairs(RadarAPI.scan()) do
		stillDetected[entry.targetPart] = true
	end
	for part in pairs(RadarAPI._claims) do
		if not part.Parent or not stillDetected[part] then
			RadarAPI._claims[part] = nil
		end
	end
end


-- ===========================================================================
-- DIAGNOSTICS
-- ===========================================================================
-- Pass any model (e.g. one you just inserted) and get back a precise report
-- of what RadarAPI sees for it, instead of guessing why it isn't detected.
--
-- Usage from a command bar or debug script:
--   local report = RadarAPI.debugModel(workspace.Model["SA330 Helicopter"])
--   print(report.summary)
buildDiagnosticReport = function(model)
	local report = {
		modelName = model.Name,
		fullPath = model:GetFullName(),
		isModelClass = model:IsA("Model"),
	}

	report.parentName = model.Parent and model.Parent.Name or "nil"
	report.parentIsNamedModel = model.Parent and model.Parent.Name == "Model"
	report.parentIsDirectWorkspaceChild = model.Parent == workspace

	local isPlayerChar = Players:GetPlayerFromCharacter(model)
	report.isPlayerCharacter = isPlayerChar ~= nil

	local profileName, profile = RadarAPI.classify(model)
	report.profile = profileName

	local ok, aliveResult = pcall(profile.isAlive, model)
	report.isAliveOk = ok
	report.isAlive = ok and aliveResult or nil
	if not ok then
		report.isAliveError = tostring(aliveResult)
	end

	local ok2, targetPartResult = pcall(profile.getBestTargetPart, model)
	report.targetPartOk = ok2
	report.targetPart = ok2 and targetPartResult or nil
	if not ok2 then
		report.targetPartError = tostring(targetPartResult)
	end

	local wouldBeScanned = (report.parentIsNamedModel or report.parentIsDirectWorkspaceChild)
		and report.isModelClass
		and report.modelName ~= "Model"
		and not report.isPlayerCharacter
	report.wouldBeScannedByContainerCheck = wouldBeScanned

	local lines = {}
	table.insert(lines, "[RadarAPI] Model: " .. report.fullPath)
	table.insert(lines, "[RadarAPI] Parent: '" .. report.parentName .. "' (named 'Model': " .. tostring(report.parentIsNamedModel) .. ")")
	table.insert(lines, "[RadarAPI] Is a Model instance: " .. tostring(report.isModelClass))
	table.insert(lines, "[RadarAPI] Detected as player character: " .. tostring(report.isPlayerCharacter))
	table.insert(lines, "[RadarAPI] Classified as: " .. report.profile)
	table.insert(lines, "[RadarAPI] isAlive() result: " .. tostring(report.isAlive) .. (report.isAliveError and (" (ERROR: " .. report.isAliveError .. ")") or ""))
	table.insert(lines, "[RadarAPI] Target part found: " .. (report.targetPart and report.targetPart:GetFullName() or "NONE") .. (report.targetPartError and (" (ERROR: " .. report.targetPartError .. ")") or ""))
	table.insert(lines, "[RadarAPI] Would scan() find this via container check: " .. tostring(report.wouldBeScannedByContainerCheck))
	if not wouldBeScanned then
		table.insert(lines, "[RadarAPI] >>> NOT SCANNED: parent isn't a 'Model'-named staging container and isn't workspace directly.")
	elseif not report.isAlive then
		table.insert(lines, "[RadarAPI] >>> NOT IN detected list: isAlive() returned false.")
	elseif not report.targetPart then
		table.insert(lines, "[RadarAPI] >>> NOT IN detected list: no target part was found.")
	else
		table.insert(lines, "[RadarAPI] >>> Detected normally.")
	end

	report.summary = table.concat(lines, "\n")
	return report
end

-- Pass any model (e.g. one you just inserted) and get back a precise report
-- of what RadarAPI sees for it. Usage:
--   local report = RadarAPI.debugModel(workspace.Model["SA330 Helicopter"])
--   print(report.summary) -- or feed it to your own logger
function RadarAPI.debugModel(model)
	if not model then
		return { summary = "No model passed to debugModel." }
	end
	return buildDiagnosticReport(model)
end

return RadarAPI
