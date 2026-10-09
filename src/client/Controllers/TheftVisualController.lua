--!strict
-- Theft Visual Controller

-- Services --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Remotes --
local workerRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Workers")

local carryPoseChanged = workerRemotes:WaitForChild("CarryPoseChanged")
assert(carryPoseChanged:IsA("RemoteEvent"))

local bonkVisual = workerRemotes:WaitForChild("BonkVisual")
assert(bonkVisual:IsA("RemoteEvent"))

-- Constants --
local LEFT_CARRY_SHOULDER = CFrame.Angles(math.rad(62), math.rad(-8), math.rad(28))
local RIGHT_CARRY_SHOULDER = CFrame.Angles(math.rad(62), math.rad(8), math.rad(-28))
local LEFT_CARRY_ELBOW = CFrame.Angles(math.rad(52), 0, 0)
local RIGHT_CARRY_ELBOW = CFrame.Angles(math.rad(52), 0, 0)

-- Types --
type CarryPose = {
	LeftShoulder: Motor6D,
	LeftElbow: Motor6D,

	RightShoulder: Motor6D,
	RightElbow: Motor6D,
}

type BonkPose = {
	RightShoulder: Motor6D,
	RightElbow: Motor6D,

	StartedAt: number,

	Board: BasePart?,
}

-- State --
local activeCarryPoses: { [number]: CarryPose } = {}
local activeBonkPoses: { [number]: BonkPose } = {}

-- Cleanup Carry Pose --
local function cleanupCarryPose(carrier: Player): ()
	activeCarryPoses[carrier.UserId] = nil
end

-- Grip Targets --
local function createCarryGripTargets(workerRoot: BasePart): (Attachment, Attachment, { Instance })
	local created: { Instance } = {}

	local workerModel = workerRoot:FindFirstAncestorOfClass("Model")
	if not workerModel then
		error("Worker root has no Model ancestor")
	end

	local existingLeft = workerModel:FindFirstChild("CarryLeftGrip", true)
	local existingRight = workerModel:FindFirstChild("CarryRightGrip", true)
	local leftGrip: Attachment
	local rightGrip: Attachment

	local boundsCFrame, boundsSize = workerModel:GetBoundingBox()
	local center = workerRoot.CFrame:PointToObjectSpace(boundsCFrame.Position)
	local gripDistance = math.clamp(boundsSize.X * 0.32, 0.35, 0.9)

	if existingLeft and existingLeft:IsA("Attachment") then
		leftGrip = existingLeft
	else
		leftGrip = Instance.new("Attachment")
		leftGrip.Name = "LocalCarryLeftGrip"
		leftGrip.Position = center + Vector3.new(-gripDistance, 0, 0)
		leftGrip.Parent = workerRoot

		table.insert(created, leftGrip)
	end

	if existingRight and existingRight:IsA("Attachment") then
		rightGrip = existingRight
	else
		rightGrip = Instance.new("Attachment")
		rightGrip.Name = "LocalCarryRightGrip"
		rightGrip.Position = center + Vector3.new(gripDistance, 0, 0)
		rightGrip.Parent = workerRoot

		table.insert(created, rightGrip)
	end

	return leftGrip, rightGrip, created
end

-- Arm Poles --
local function createArmPole(char: Model, side: "Left" | "Right"): Attachment?
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	local pole = Instance.new("Attachment")
	pole.Name = `Local{side}ArmPole`

	-- Push elbows out and slightly back
	local sideDirection = if side == "Left" then -1 else 1
	pole.Position = Vector3.new(2 * sideDirection, 0.6, 0.5)
	pole.Parent = root

	return pole
end

-- Get Motor --
local function getMotor(character: Model, name: string): Motor6D?
	local motor = character:FindFirstChild(name, true)

	if motor and motor:IsA("Motor6D") then
		return motor
	end

	return nil
end

-- Carry Pose --
local function startCarryPose(carrier: Player, _workerRoot: BasePart): ()
	cleanupCarryPose(carrier)

	local character = carrier.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end

	local leftShoulder = getMotor(character, "LeftShoulder")
	local leftElbow = getMotor(character, "LeftElbow")
	local rightShoulder = getMotor(character, "RightShoulder")
	local rightElbow = getMotor(character, "RightElbow")

	if not leftShoulder or not leftElbow or not rightShoulder or not rightElbow then
		warn("[CARRY POSE] Missing R15 arm Motor6D")

		return
	end

	activeCarryPoses[carrier.UserId] = {
		LeftShoulder = leftShoulder,
		LeftElbow = leftElbow,
		RightShoulder = rightShoulder,
		RightElbow = rightElbow,
	}
end

-- Bonk Visual
local function playBonkVisual(attacker: Player, _target: Player): ()
	local character = attacker.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end

	local rightShoulder = getMotor(character, "RightShoulder")
	local rightElbow = getMotor(character, "RightElbow")
	local rightHand = character:FindFirstChild("RightHand")
	if not rightShoulder or not rightElbow or not rightHand or not rightHand:IsA("BasePart") then
		return
	end

	-- Temporary skateboard
	local board = Instance.new("Part")
	board.Name = "BonkSkateboard"
	board.Size = Vector3.new(0.32, 2.8, 0.82)
	board.Material = Enum.Material.SmoothPlastic
	board.Color = Color3.fromRGB(255, 194, 38)
	board.CanCollide = false
	board.CanTouch = false
	board.CanQuery = false
	board.Massless = true
	board.CFrame = rightHand.CFrame * CFrame.new(0, -1.05, 0) * CFrame.Angles(0, 0, math.rad(90))
	board.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rightHand
	weld.Part1 = board
	weld.Parent = board

	-- Begin procedural swing
	activeBonkPoses[attacker.UserId] = {
		RightShoulder = rightShoulder,
		RightElbow = rightElbow,
		StartedAt = os.clock(),
		Board = board,
	}
end

-- Tick --
RunService.PreSimulation:Connect(function()
	-- Carry poses
	for userId, pose in activeCarryPoses do
		if
			not pose.LeftShoulder.Parent
			or not pose.LeftElbow.Parent
			or not pose.RightShoulder.Parent
			or not pose.RightElbow.Parent
		then
			activeCarryPoses[userId] = nil

			continue
		end

		pose.LeftShoulder.Transform = LEFT_CARRY_SHOULDER
		pose.LeftElbow.Transform = LEFT_CARRY_ELBOW
		pose.RightShoulder.Transform = RIGHT_CARRY_SHOULDER
		pose.RightElbow.Transform = RIGHT_CARRY_ELBOW
	end

	-- Bonk poses
	for userId, pose in activeBonkPoses do
		if not pose.RightShoulder.Parent or not pose.RightElbow.Parent then
			activeBonkPoses[userId] = nil

			continue
		end

		local elapsed = os.clock() - pose.StartedAt

		-- Windup
		if elapsed < 0.16 then
			local alpha = math.clamp(elapsed / 0.16, 0, 1)
			local shoulder = CFrame.Angles(math.rad(-95), 0, math.rad(-25))
			local elbow = CFrame.Angles(math.rad(45), 0, 0)

			pose.RightShoulder.Transform = CFrame.identity:Lerp(shoulder, alpha)
			pose.RightElbow.Transform = CFrame.identity:Lerp(elbow, alpha)

		-- BONK
		elseif elapsed < 0.32 then
			local alpha = math.clamp((elapsed - 0.16) / 0.16, 0, 1)
			local windupShoulder = CFrame.Angles(math.rad(-95), 0, math.rad(-25))
			local strikeShoulder = CFrame.Angles(math.rad(85), 0, math.rad(-12))
			local windupElbow = CFrame.Angles(math.rad(45), 0, 0)
			local strikeElbow = CFrame.Angles(math.rad(10), 0, 0)

			pose.RightShoulder.Transform = windupShoulder:Lerp(strikeShoulder, alpha)
			pose.RightElbow.Transform = windupElbow:Lerp(strikeElbow, alpha)

		-- Finished
		else
			if pose.Board and pose.Board.Parent then
				pose.Board:Destroy()
			end

			activeBonkPoses[userId] = nil
		end
	end
end)

-- Remotes --
carryPoseChanged.OnClientEvent:Connect(function(carrier: Player, workerRoot: BasePart?, enabled: boolean)
	if enabled then
		if workerRoot then
			startCarryPose(carrier, workerRoot)
		end
	else
		cleanupCarryPose(carrier)
	end
end)

bonkVisual.OnClientEvent:Connect(playBonkVisual)

-- Late-join/current carry recovery
task.defer(function()
	local carriedFolder = workspace:FindFirstChild("CarriedWorkers")
	if not carriedFolder or not carriedFolder:IsA("Folder") then
		return
	end

	for _, model in carriedFolder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end

		local carrierUserId = model:GetAttribute("CarrierUserId")
		if typeof(carrierUserId) ~= "number" then
			continue
		end

		local carrier = Players:GetPlayerByUserId(carrierUserId)
		local root = model.PrimaryPart
		if carrier and root then
			startCarryPose(carrier, root)
		end
	end
end)

return {}
