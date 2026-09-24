-- Modules/PlacementController.lua
-- Ghost model preview, surface raycast alignment, and deployment positioning

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local PlacementController = {}

local placementMode = false
local placementTemplate = nil
local placementRotation = 0
local placementGhost = nil
local placementConn = nil

local function getTemplatesFolder()
	local rep = ReplicatedStorage:FindFirstChild("CIWSTemplates")
	if rep and rep:IsA("Folder") then
		return rep
	end
	return nil
end

function PlacementController.getSurfaceRotation(norm, rotDeg, hitPart)
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

function PlacementController.stopPlacement()
	placementMode = false
	placementTemplate = nil
	placementRotation = 0
	if placementConn then
		placementConn:Disconnect()
		placementConn = nil
	end
	if placementGhost then
		placementGhost:Destroy()
		placementGhost = nil
	end
end

function PlacementController.isPlacing()
	return placementMode
end

function PlacementController.startPlacement(templateName, onDeploy)
	PlacementController.stopPlacement()
	local tmplFolder = getTemplatesFolder()
	local tmpl = tmplFolder and tmplFolder:FindFirstChild(templateName)
	if not tmpl or not tmpl:IsA("Model") then return end

	placementMode = true
	placementTemplate = templateName
	placementRotation = 0

	placementGhost = tmpl:Clone()
	placementGhost.Name = "PlacementGhost"
	local bc = placementGhost:FindFirstChild("BaseComponent")
	if bc and bc:IsA("BasePart") then
		placementGhost.PrimaryPart = bc
	end

	for _, p in ipairs(placementGhost:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.CastShadow = false
			p.Anchored = true
			p.Transparency = 0.4
			p.Color = Color3.fromRGB(50, 205, 90)
			p.Material = Enum.Material.Neon
		elseif p:IsA("GuiBase3d") or p:IsA("ParticleEmitter") or p:IsA("Light") or p:IsA("Sound") or p:IsA("LuaSourceContainer") then
			p:Destroy()
		end
	end
	placementGhost.Parent = workspace

	local mouse = player:GetMouse()
	placementConn = RunService.RenderStepped:Connect(function()
		if not placementMode or not placementGhost then return end
		local ray = mouse.UnitRay
		local cp = RaycastParams.new()
		cp.FilterType = Enum.RaycastFilterType.Exclude
		local ign = { placementGhost }
		if player.Character then table.insert(ign, player.Character) end
		cp.FilterDescendantsInstances = ign

		local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, cp)
		if hit and hit.Instance then
			local rotCF = PlacementController.getSurfaceRotation(hit.Normal, placementRotation, hit.Instance)
			local targetCF = CFrame.new(hit.Position) * rotCF
			if placementGhost.PrimaryPart then
				placementGhost:SetPrimaryPartCFrame(targetCF)
			else
				placementGhost:PivotTo(targetCF)
			end
		end
	end)

	local inputConn = nil
	inputConn = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if not placementMode then
			if inputConn then inputConn:Disconnect() end
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			placementRotation = (placementRotation + 45) % 360
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then
			PlacementController.stopPlacement()
			if inputConn then inputConn:Disconnect() end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			local ray = mouse.UnitRay
			local cp = RaycastParams.new()
			cp.FilterType = Enum.RaycastFilterType.Exclude
			local ign = { placementGhost }
			if player.Character then table.insert(ign, player.Character) end
			cp.FilterDescendantsInstances = ign

			local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, cp)
			if hit and hit.Instance and placementTemplate then
				local rotCF = PlacementController.getSurfaceRotation(hit.Normal, placementRotation, hit.Instance)
				local targetCF = CFrame.new(hit.Position) * rotCF
				onDeploy(placementTemplate, targetCF, hit.Instance)
				PlacementController.stopPlacement()
				if inputConn then inputConn:Disconnect() end
			end
		end
	end)
end

return PlacementController
