local hookedTurrets = {}
local hookedFolders = {}

local function hookupCIWS(turret)
	if not turret or not turret:IsA("Model") then
		return
	end
	if hookedTurrets[turret] then
		return
	end
	local remotes = turret:FindFirstChild("Remotes") or turret:WaitForChild("Remotes", 5)
	local modules = turret:FindFirstChild("Modules") or turret:WaitForChild("Modules", 5)
	if not remotes or not modules then
		task.delay(0.5, function()
			if turret.Parent and not hookedTurrets[turret] then
				hookupCIWS(turret)
			end
		end)
		return
	end
	local clientConnector = remotes:FindFirstChild("ClientConnector")
	local weaponFunctionsMod = modules:FindFirstChild("WeaponFunctions")
	if not clientConnector or not weaponFunctionsMod then
		task.delay(0.5, function()
			if turret.Parent and not hookedTurrets[turret] then
				hookupCIWS(turret)
			end
		end)
		return
	end
	hookedTurrets[turret] = true
	local weaponFunctions = (require :: any)(weaponFunctionsMod)
	clientConnector.OnClientEvent:Connect(function(origin, direction, customSpeed, customRange, customRadius, tracerCaliber, tracerLum)
		task.spawn(function()
			weaponFunctions.FireBullet(origin, direction, customSpeed, customRange, customRadius, tracerCaliber, tracerLum)
		end)
	end)
end

local function hookFolder(folder)
	if not folder or not folder:IsA("Folder") then
		return
	end
	if hookedFolders[folder] then
		return
	end
	hookedFolders[folder] = true
	for _, child in ipairs(folder:GetChildren()) do
		hookupCIWS(child)
	end
	folder.ChildAdded:Connect(function(child)
		task.defer(function()
			hookupCIWS(child)
		end)
	end)
end

local foundFolder = workspace:FindFirstChild("Ciws")
if foundFolder then
	hookFolder(foundFolder)
end

for _, child in ipairs(workspace:GetChildren()) do
	if child:IsA("Model") then
		hookupCIWS(child)
	end
end

workspace.ChildAdded:Connect(function(child)
	if child:IsA("Folder") and child.Name == "Ciws" then
		hookFolder(child)
	elseif child:IsA("Model") then
		task.defer(function()
			hookupCIWS(child)
		end)
	end
end)


