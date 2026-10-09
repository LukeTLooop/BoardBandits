--!strict
-- Worker class

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HTTPService = game:GetService("HttpService")

-- Config --
local WorkerConfig = require(ReplicatedStorage.Shared.Config.WorkerConfig)
local RecipeConfig = require(ReplicatedStorage.Shared.Config.RecipeConfig)
local WorkerAnimationConfig = require(ReplicatedStorage.Shared.Config.WorkerAnimationConfig)
local TemperConfig = require(ReplicatedStorage.Shared.Config.TemperConfig)

-- Types --
local WorkerTypes = require(ReplicatedStorage.Shared.Types.WorkerTypes)

-- Class --
local Worker = {}
Worker.__index = Worker

type WorkerData = {
	Id: string,
	WorkerType: string,
	OwnerUserId: number,

	Temper: WorkerTypes.WorkerTemper,
	State: WorkerTypes.WorkerLocationState,

	Model: Model?,
	RootPart: BasePart?,
	Animator: Animator?,

	RootAttachment: Attachment?,
	PositionConstraint: AlignPosition?,
	OrientationConstraint: AlignOrientation?,

	StationCFrame: CFrame?,

	ActivityState: WorkerTypes.WorkerActivityState,
	AnimationTracks: {
		[WorkerTypes.WorkerActivityState]: AnimationTrack,
	},
	CurrentAnimationTrack: AnimationTrack?,

	FactoryId: string?,
	CarrierUserId: number?,

	IsWorking: boolean,
	IsProducing: boolean,
	CurrentProductionInterval: number,
	CurrentOutputItem: string?,
	CurrentOutputAmount: number,
	ProductionElapsed: number,

	Level: number,

	ProductionCallback: ((string, number) -> ())?,
	CanProduceCallback: (({ [string]: number }) -> boolean)?,
	ConsumeInputsCallback: (({ [string]: number }) -> boolean)?,
}

export type Worker = typeof(setmetatable({} :: WorkerData, Worker))

function Worker.new(
	workerType: string,
	ownerUserId: number,
	workerId: string?,
	level: number?,
	temper: WorkerTypes.WorkerTemper?,
	state: WorkerTypes.WorkerLocationState?
): Worker
	local data: WorkerData = {
		Id = workerId or HTTPService:GenerateGUID(false),
		WorkerType = workerType,
		OwnerUserId = ownerUserId,

		Temper = temper or "Normal",
		State = state or "Stored",

		Model = nil,
		RootPart = nil,
		Animator = nil,

		RootAttachment = nil,
		PositionConstraint = nil,
		OrientationConstraint = nil,

		StationCFrame = nil,

		ActivityState = "Idle",
		AnimationTracks = {},
		CurrentAnimationTrack = nil,

		FactoryId = nil,
		CarrierUserId = nil,

		IsWorking = false,
		IsProducing = false,

		CurrentProductionInterval = 0,
		CurrentOutputItem = nil,
		CurrentOutputAmount = 0,

		ProductionElapsed = 0,

		Level = level or 1,

		ProductionCallback = nil,
		CanProduceCallback = nil,
		ConsumeInputsCallback = nil,
	}

	return setmetatable(data, Worker)
end

-- Working --
function Worker.StartWorking(self: Worker)
	if self.IsWorking then
		return
	end

	self.IsWorking = true
	self.ProductionElapsed = 0

	local definition = WorkerConfig[self.WorkerType]
	if not definition then
		return
	end

	-- Producers continuously work
	-- Assemblers are idle until parts are available
	if definition.WorkerType == "Producer" then
		self:SetActivityState("Working")
	else
		self:SetActivityState("Idle")
	end
end

function Worker.StopWorking(self: Worker)
	self.IsWorking = false

	self:SetActivityState("Idle")
end

-- Update --
function Worker.Update(self: Worker, dt: number)
	if not self.IsWorking then
		return
	end

	local definition = WorkerConfig[self.WorkerType]
	if not definition then
		return
	end

	if definition.WorkerType == "Producer" then
		self:UpdateProducer(dt, definition)
	elseif definition.WorkerType == "Assembler" then
		self:UpdateAssembler(dt, definition)
	end
end

-- Producer --
function Worker.UpdateProducer(self: Worker, dt: number, definition: WorkerConfig.ProducerDefinition): ()
	self.ProductionElapsed += dt

	if self.ProductionElapsed < definition.ProductionInterval then
		return
	end
	self.ProductionElapsed -= definition.ProductionInterval

	local outputItem = self:GetOutputItem()
	if not outputItem then
		return
	end

	local callback = self.ProductionCallback
	if not callback then
		return
	end

	callback(outputItem, definition.OutputAmount)
end

-- Assembler --
function Worker.UpdateAssembler(self: Worker, dt: number, definition: WorkerConfig.AssemblerDefinition): ()
	-- Start new assembly job
	if not self.IsProducing then
		local recipeId = self:GetRecipeId()
		if not recipeId then
			return
		end

		local recipe = RecipeConfig[recipeId]
		if not recipe then
			return
		end

		local canProduce = self.CanProduceCallback
		if not canProduce then
			return
		end
		if not canProduce(recipe.Inputs) then
			return
		end

		local consumeInputs = self.ConsumeInputsCallback
		if not consumeInputs then
			return
		end
		if not consumeInputs(recipe.Inputs) then
			return
		end

		-- Ingredients committed to production
		self.IsProducing = true
		self.ProductionElapsed = 0

		self:SetActivityState("Working")

		self.CurrentProductionInterval = recipe.ProductionInterval
		self.CurrentOutputItem = recipe.OutputItem
		self.CurrentOutputAmount = recipe.OutputAmount

		return
	end

	-- Continue assembly
	self.ProductionElapsed += dt

	if self.ProductionElapsed < self.CurrentProductionInterval then
		return
	end

	self.ProductionElapsed -= self.CurrentProductionInterval
	self.IsProducing = false

	self:SetActivityState("Idle")

	local outputItem = self.CurrentOutputItem
	local outputAmount = self.CurrentOutputAmount

	self.CurrentOutputItem = nil
	self.CurrentOutputAmount = 0
	self.CurrentProductionInterval = 0

	if not outputItem then
		return
	end

	local callback = self.ProductionCallback
	if not callback then
		return
	end

	callback(outputItem, outputAmount)
end

function Worker.SetActivityState(self: Worker, state: WorkerTypes.WorkerActivityState): ()
	-- Already playing correct state
	if self.ActivityState == state then
		local currentTrack = self.CurrentAnimationTrack
		if currentTrack and currentTrack.IsPlaying then
			return
		end
	end

	self.ActivityState = state

	-- Stop previous animation
	local currentTrack = self.CurrentAnimationTrack
	if currentTrack then
		currentTrack:Stop(0.15)
	end

	-- Find target animation
	-- Missing animation fallback to Idle
	local nextTrack = self.AnimationTracks[state]
	if not nextTrack and state ~= "Idle" then
		nextTrack = self.AnimationTracks.Idle
	end

	self.CurrentAnimationTrack = nextTrack

	if nextTrack then
		nextTrack:Play(0.15)

		local animationSpeed = 1
		if state == "Carried" then
			local temperDefinition = TemperConfig[self.Temper]
			if temperDefinition then
				animationSpeed = temperDefinition.CarryAnimationSpeed
			end
		end

		nextTrack:AdjustSpeed(animationSpeed)
	end
end

local function getOrCreateAnimator(model: Model): Animator
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			return animator
		end

		local newAnimator = Instance.new("Animator")
		newAnimator.Parent = hum

		return newAnimator
	end

	local animationController: AnimationController
	local existing = model:FindFirstChildOfClass("AnimationController")
	if not existing then
		animationController = Instance.new("AnimationController")
		animationController.Name = "AnimationController"
		animationController.Parent = model
	else
		animationController = existing
	end

	local animator = animationController:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end

	local newAnimator = Instance.new("Animator")
	newAnimator.Parent = animationController

	return newAnimator
end

function Worker.SetupModelController(self: Worker, rootPart: BasePart): ()
	local attachment = Instance.new("Attachment")
	attachment.Name = "WorkerRootAttachment"
	attachment.Parent = rootPart

	-- Hold worker at it's station position
	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Name = "WorkerPosition"
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.ApplyAtCenterOfMass = true
	alignPosition.MaxForce = math.huge
	alignPosition.MaxVelocity = math.huge
	alignPosition.Responsiveness = 45
	alignPosition.RigidityEnabled = false
	alignPosition.Enabled = false
	alignPosition.Parent = rootPart

	-- Keep worker upright and facing station direction
	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "WorkerOrientation"
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxTorque = math.huge
	alignOrientation.MaxAngularVelocity = math.huge
	alignOrientation.Responsiveness = 45
	alignOrientation.RigidityEnabled = false
	alignOrientation.Enabled = false
	alignOrientation.Parent = rootPart

	self.RootAttachment = attachment
	self.PositionConstraint = alignPosition
	self.OrientationConstraint = alignOrientation
end

function Worker.SetStationCFrame(self: Worker, stationCFrame: CFrame): ()
	self.StationCFrame = stationCFrame

	local positionConstraint = self.PositionConstraint
	local orientationConstraint = self.OrientationConstraint

	if positionConstraint then
		positionConstraint.Position = stationCFrame.Position
	end

	if orientationConstraint then
		orientationConstraint.CFrame = stationCFrame.Rotation
	end
end

function Worker.SetStationLocked(self: Worker, enabled: boolean): ()
	local positionConstraint = self.PositionConstraint
	if positionConstraint then
		positionConstraint.Enabled = enabled
	end

	local orientationConstraint = self.OrientationConstraint
	if orientationConstraint then
		orientationConstraint.Enabled = enabled
	end
end

function Worker.SetUprightLocked(self: Worker, enabled: boolean): ()
	if self.PositionConstraint then
		self.PositionConstraint.Enabled = false
	end

	if self.OrientationConstraint then
		self.OrientationConstraint.Enabled = enabled
	end
end

function Worker.LoadAnimations(self: Worker): ()
	local animator = self.Animator
	if not animator then
		return
	end

	-- Clear previously loaded tracks
	for _, track in self.AnimationTracks do
		track:Stop(0)
		track:Destroy()
	end

	table.clear(self.AnimationTracks)

	self.CurrentAnimationTrack = nil

	-- Worker animation set
	local animationSet = WorkerAnimationConfig[self.WorkerType]
	if not animationSet then
		return
	end

	local function load(state: WorkerTypes.WorkerActivityState, definition: WorkerAnimationConfig.AnimationDefinition?)
		if not definition then
			return
		end

		if definition.Id == "" then
			return
		end

		local animation = Instance.new("Animation")
		animation.AnimationId = definition.Id

		local success, result = pcall(function()
			return animator:LoadAnimation(animation)
		end)

		animation:Destroy()

		if not success then
			warn("[WORKER]", self.WorkerType, "failed to load", state, "animation:", result)

			return
		end

		local track = result :: AnimationTrack
		track.Looped = definition.Looped
		track.Priority = definition.Priority

		self.AnimationTracks[state] = track
	end

	load("Idle", animationSet.Idle)
	load("Working", animationSet.Working)
	load("Carried", animationSet.Carried)
end

function Worker.Spawn(self: Worker, spawnCFrame: CFrame): boolean
	local definition = WorkerConfig[self.WorkerType]
	if not definition then
		return false
	end

	local template = ReplicatedStorage.Assets.Workers:FindFirstChild(definition.ModelName)
	if not template or not template:IsA("Model") then
		warn("Missing worker model:", definition.ModelName)
		return false
	end

	local model = template:Clone()

	-- Root
	local root: BasePart?
	if model.PrimaryPart then
		root = model.PrimaryPart
	else
		local humanoidRoot = model:FindFirstChild("HumanoidRootPart", true)
		if humanoidRoot and humanoidRoot:IsA("BasePart") then
			root = humanoidRoot
		else
			root = model:FindFirstChildWhichIsA("BasePart", true)
		end
	end

	if not root then
		model:Destroy()

		warn("[WORKER]", definition.ModelName, "has no BasePart root!")

		return false
	end

	-- Standardize runtime physics
	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end

		descendant.Anchored = false
	end

	-- Cache runtime body
	self.Model = model
	self.RootPart = root
	self.Animator = getOrCreateAnimator(model)
	self:LoadAnimations()

	self:SetupModelController(root)
	self:SetStationCFrame(spawnCFrame)

	-- Initial placement
	model:PivotTo(spawnCFrame)
	model.Parent = workspace

	-- Server owns physics while stationed
	local canSetOwnership = root:CanSetNetworkOwnership()
	if canSetOwnership then
		root:SetNetworkOwner(nil)
	end

	self:SetStationLocked(true)
	self:SetActivityState("Idle")

	return true
end

function Worker.GetRootPart(self: Worker): BasePart?
	return self.RootPart
end

function Worker.DestroyModel(self: Worker): ()
	self:SetStationLocked(false)

	if self.CurrentAnimationTrack then
		self.CurrentAnimationTrack:Stop(0)
	end

	for _, track in self.AnimationTracks do
		track:Stop(0)
		track:Destroy()
	end

	table.clear(self.AnimationTracks)
	self.CurrentAnimationTrack = nil

	local model = self.Model
	if model then
		model:Destroy()
	end

	self.Model = nil
	self.RootPart = nil
	self.Animator = nil
	self.RootAttachment = nil
	self.PositionConstraint = nil
	self.OrientationConstraint = nil
	self.StationCFrame = nil
end

-- Callbacks --
function Worker.SetProductionCallback(self: Worker, callback: ((string, number) -> ())?): ()
	self.ProductionCallback = callback
end

function Worker.SetCanProduceCallback(self: Worker, callback: (({ [string]: number }) -> boolean)?): ()
	self.CanProduceCallback = callback
end

function Worker.SetConsumeInputsCallback(self: Worker, callback: (({ [string]: number }) -> boolean)?): ()
	self.ConsumeInputsCallback = callback
end

function Worker.ClearFactoryCallbacks(self: Worker): ()
	self.ProductionCallback = nil
	self.CanProduceCallback = nil
	self.ConsumeInputsCallback = nil
end

-- Progression --
function Worker.GetOutputItem(self: Worker): string?
	local definition = WorkerConfig[self.WorkerType]
	if not definition then
		return nil
	end

	if definition.WorkerType ~= "Producer" then
		return nil
	end

	local outputItem: string? = nil

	for _, output in definition.OutputProgression do
		if self.Level >= output.RequiredLevel then
			outputItem = output.Item
		else
			break
		end
	end

	return outputItem
end

function Worker.GetRecipeId(self: Worker): string?
	local definition = WorkerConfig[self.WorkerType]
	if not definition then
		return nil
	end

	if definition.WorkerType ~= "Assembler" then
		return nil
	end

	local recipeId: string? = nil

	for _, progression in definition.RecipeProgression do
		if self.Level >= progression.RequiredLevel then
			recipeId = progression.Recipe
		else
			break
		end
	end

	return recipeId
end

return Worker
