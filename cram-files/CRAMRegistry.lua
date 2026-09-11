local HttpService = game:GetService("HttpService")

local Registry = {}
Registry._units = {}
Registry._globalConfig = {
    enabled = false,
    maxRange = 6000,
    damage = 25,
    bulletSpeed = 3500,
    maxAmmo = 1500,
    explosionRadius = 30,
    fireRate = 1.0,
    burstDuration = 1.6,
    evalPause = 0.75,
    slewRate = 165,
    leadCompensation = 1.0,
    spreadAngle = 0.35,
    tracerCaliber = 1.0,
    tracerLum = 1.0,
    continuousFire = false,
    infiniteAmmo = false,
    thermalOverride = false,
    autoReload = true,
    friendlyFire = false,
    priorityMode = "CLOSEST",
    targetWhitelist = {},
    targetWhitelist = {},
    showEngagementLines = false,
}

Registry._configLimits = {
    maxRange = {1000, 40000},
    damage = {5, 500},
    bulletSpeed = {1000, 15000},
    maxAmmo = {100, 10000},
    explosionRadius = {5, 100},
    fireRate = {0.25, 3.0},
    burstDuration = {0.5, 8.0},
    evalPause = {0.1, 3.0},
    slewRate = {60, 360},
    leadCompensation = {0.0, 2.5},
    spreadAngle = {0.0, 3.0},
    tracerCaliber = {0.5, 4.0},
    tracerLum = {1.0, 5.0},
}

function Registry.generateId()
    return HttpService:GenerateGUID(false)
end

function Registry.clampValue(key, value)
    local limits = Registry._configLimits[key]
    if limits and type(value) == "number" then
        return math.clamp(value, limits[1], limits[2])
    end
    return value
end

function Registry.getDefaultUnitConfig()
    return {
        mode = "INDIVIDUAL",
        enabled = false,
        nickname = "",
        maxRange = 6000,
        damage = 25,
        bulletSpeed = 3500,
        maxAmmo = 1500,
        explosionRadius = 30,
        fireRate = 1.0,
        burstDuration = 1.6,
        evalPause = 0.75,
        slewRate = 165,
        leadCompensation = 1.0,
        spreadAngle = 0.35,
        tracerCaliber = 1.0,
        tracerLum = 1.0,
        continuousFire = false,
        infiniteAmmo = false,
        thermalOverride = false,
        autoReload = true,
        friendlyFire = false,
        priorityMode = "CLOSEST",
        targetWhitelist = {},
        targetWhitelist = {},
    }
end

function Registry.registerUnit(model)
    if not model or not model:IsA("Model") then return nil end
    if not model:IsDescendantOf(workspace) then return nil end

    local existingId = Registry.findUnitByModel(model)
    if existingId then
        return existingId
    end

    local id = Registry.generateId()
    model:SetAttribute("CramUnitId",id)
    model:SetAttribute("CramRegistered",true)
    local config = Registry.getDefaultUnitConfig()
    config.nickname = model.Name

    local configs = model:FindFirstChild("Configurations")
    if configs then
        for key, _ in pairs(config) do
            local val = configs:FindFirstChild(key)
            if val and val:IsA("ValueBase") then
                config[key] = val.Value
            end
        end
    end
    config.enabled = false

    local entry = {
        id = id,
        model = model,
        config = config,
        stats = {
            status = "IDLE",
            currentTarget = nil,
            currentAmmo = config.maxAmmo,
            heat = 0,
            kills = 0,
        },
    }
    Registry._units[id] = entry
    model:SetAttribute("CramEnabled", config.enabled == true)
    model:SetAttribute("CramMode", config.mode)
    return id
end

function Registry.unregisterUnit(id)
    if not id then return nil end
    local entry = Registry._units[id]
    Registry._units[id] = nil
    if entry and entry.model and entry.model.Parent then
        entry.model:SetAttribute("CramRegistered",nil)
    end
    return entry
end

function Registry.getUnit(id)
    return Registry._units[id]
end

function Registry.findUnitByModel(model)
    for id, entry in pairs(Registry._units) do
        if entry.model == model then
            return id
        end
    end
    return nil
end

function Registry.getAllUnits()
    return Registry._units
end

function Registry.getGlobalConfig()
    return Registry._globalConfig
end

function Registry.setGlobalConfig(key, value)
    if Registry._globalConfig[key] ~= nil then
        Registry._globalConfig[key] = Registry.clampValue(key, value)
    end
end

function Registry.resetGlobalConfig()
    Registry._globalConfig = {
        enabled = false,
        maxRange = 6000,
        damage = 25,
        bulletSpeed = 3500,
        maxAmmo = 1500,
        explosionRadius = 30,
        fireRate = 1.0,
        burstDuration = 1.6,
        evalPause = 0.75,
        slewRate = 165,
        leadCompensation = 1.0,
        spreadAngle = 0.35,
        tracerCaliber = 1.0,
        tracerLum = 1.0,
        continuousFire = false,
        infiniteAmmo = false,
        thermalOverride = false,
        autoReload = true,
        friendlyFire = false,
        priorityMode = "CLOSEST",
        targetWhitelist = {},
        targetWhitelist = {},
        showEngagementLines = false,
    }
end

function Registry.getEffectiveConfig(unitId)
    local unit = Registry.getUnit(unitId)
    if not unit then return Registry.getGlobalConfig() end
    if unit.config.mode == "OVERALL" then
        local eff = table.clone(Registry.getGlobalConfig())
        eff.mode = "OVERALL"
        eff.nickname = unit.config.nickname
        eff.enabled = unit.config.enabled
        return eff
    end
    return unit.config
end

function Registry.setUnitConfig(unitId, key, value)
    local unit = Registry.getUnit(unitId)
    if unit and unit.config[key] ~= nil then
        unit.config[key] = Registry.clampValue(key, value)
    end
end

function Registry.applyUnitConfig(unitId, newConfig)
    local unit = Registry.getUnit(unitId)
    if not unit or type(newConfig) ~= "table" then return end
    for k, v in pairs(newConfig) do
        if k == "targetMode" then
            if v == "OVERALL" or v == "INDIVIDUAL" then
                unit.config.mode = v
                unit.config.targetMode = v
            end
        elseif k == "mode" then
            if v == "OVERALL" or v == "INDIVIDUAL" then
                unit.config.mode = v
                unit.config.targetMode = v
            end
        elseif unit.config[k] ~= nil then
            unit.config[k] = Registry.clampValue(k, v)
        end
    end
    unit.model:SetAttribute("CramEnabled", unit.config.enabled == true)
    unit.model:SetAttribute("CramMode", unit.config.mode)
end

function Registry.resetUnitConfig(unitId)
    local unit = Registry.getUnit(unitId)
    if not unit then return end
    local def = Registry.getDefaultUnitConfig()
    def.nickname = unit.model and unit.model.Name or unit.config.nickname
    def.enabled = unit.config.enabled
    unit.config = def
    unit.model:SetAttribute("CramEnabled", unit.config.enabled == true)
    unit.model:SetAttribute("CramMode", unit.config.mode)
end

function Registry.getSerializableState()
    local unitsData = {}
    local toRemove = {}

    for id, entry in pairs(Registry._units) do
        if not entry.model or not entry.model.Parent or not entry.model:IsDescendantOf(workspace) then
            table.insert(toRemove, id)
        else
            local pos = nil
            if entry.model.PrimaryPart then
                local p = entry.model.PrimaryPart.Position
                pos = {x = p.X, y = p.Y, z = p.Z}
            elseif entry.model:FindFirstChild("BaseComponent") then
                local p = entry.model.BaseComponent.Position
                pos = {x = p.X, y = p.Y, z = p.Z}
            end
            unitsData[id] = {
                id = id,
                modelName = entry.model.Name,
                position = pos,
                config = table.clone(entry.config),
                stats = table.clone(entry.stats),
            }
        end
    end

    for _, id in ipairs(toRemove) do
        Registry._units[id] = nil
    end

    return {
        units = unitsData,
        globalConfig = table.clone(Registry._globalConfig),
    }
end

return Registry



