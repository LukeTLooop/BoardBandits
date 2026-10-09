--!strict
-- Theft Combat Controller

-- Services --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Player --
local plr = Players.LocalPlayer

-- Remotes --
local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Workers")

local bonkCarrier = remotes:WaitForChild("BonkCarrier")
assert(bonkCarrier:IsA("RemoteEvent"), "BonkCarrier must be a RemoteEvent!")

-- Constants --
local RAY_DISTANCE = 100

-- Find player under cursor/tap
local function getTargetPlayer(screenPosition: Vector2): Player?
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end

	local ray = cam:ViewportPointToRay(screenPosition.X, screenPosition.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local excluded: { Instance } = {}
	if plr.Character then
		table.insert(excluded, plr.Character)
	end

	-- Ignore worker held in front to ensure ray hits player
	local carriedFolder = workspace:FindFirstChild("CarriedWorkers")
	if carriedFolder then
		table.insert(excluded, carriedFolder)
	end

	params.FilterDescendantsInstances = excluded

	local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_DISTANCE, params)
	if not result then
		return nil
	end

	local char = result.Instance:FindFirstAncestorOfClass("Model")
	if not char then
		return nil
	end

	return Players:GetPlayerFromCharacter(char)
end

local function tryBonk(screenPosition: Vector2): ()
	local target = getTargetPlayer(screenPosition)
	if not target or target == plr then
		return
	end

	bonkCarrier:FireServer(target.UserId)
end

-- Mouse --
UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
	if gpe then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		tryBonk(UserInputService:GetMouseLocation())

		return
	end

	-- Controller
	if input.KeyCode == Enum.KeyCode.ButtonR2 then
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end

		tryBonk(cam.ViewportSize * 0.5)
	end
end)

-- Mobile tap
UserInputService.TouchTap:Connect(function(touchPositions: { Vector2 }, gpe: boolean)
	if gpe then
		return
	end

	local position = touchPositions[1]
	if position then
		tryBonk(position)
	end
end)

return {}
