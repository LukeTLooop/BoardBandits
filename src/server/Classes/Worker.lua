--!strict
-- Worker class

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HTTPService = game:GetService("HttpService")

local WorkerConfig = require(ReplicatedStorage.Shared.Config.WorkerConfig)
local RecipeConfig = require(ReplicatedStorage.Shared.Config.RecipeConfig)

local WorkerTypes = require(ReplicatedStorage.Shared.Types.WorkerTypes)

local Worker = {}
Worker.__index = Worker

type WorkerData = {
	Id: string,
	WorkerType: string,
	OwnerUserId: number,

	Temper: WorkerTypes.WorkerTemper,
	State: WorkerTypes.WorkerLocationState,

	Model: Model?,
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
end

function Worker.StopWorking(self: Worker)
	self.IsWorking = false
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

function Worker.Spawn(self: Worker, spawnCFrame: CFrame): ()
	local definition = WorkerConfig[self.WorkerType]
	if not definition then
		return
	end

	local template = ReplicatedStorage.Assets.Workers:FindFirstChild(definition.ModelName)
	if not template or not template:IsA("Model") then
		warn("Missing worker model:", definition.ModelName)
		return
	end

	local model = template:Clone()
	model:PivotTo(spawnCFrame)
	model.Parent = workspace

	self.Model = model
end

function Worker.GetRootPart(self: Worker): BasePart?
	local model = self.Model
	if not model then
		return nil
	end

	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local humanoidRoot = model:FindFirstChild("HumanoidRootPart", true)
	if humanoidRoot and humanoidRoot:IsA("BasePart") then
		return humanoidRoot
	end

	local firstPart = model:FindFirstChildWhichIsA("BasePart", true)
	if firstPart and firstPart:IsA("BasePart") then
		return firstPart
	end

	return nil
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
