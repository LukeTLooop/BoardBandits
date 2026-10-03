--!strict
-- Factory class

-- Services --
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyService = require(ServerScriptService.Services.EconomyService)

-- Classes --
local Worker = require(ServerScriptService.Classes.Worker)

-- Config --
local WorkerConfig = require(ReplicatedStorage.Shared.Config.WorkerConfig)
local TemperConfig = require(ReplicatedStorage.Shared.Config.TemperConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)

-- Framework --
local GameEvents = require(ServerScriptService.Framework.GameEvents)

-- Class --
local Factory = {}
Factory.__index = Factory

-- Types --
export type ProductionCallback = (worker: Worker.Worker, itemId: string, amount: number) -> ()

type FactoryData = {
	Id: string,
	Model: Model,
	OwnerUserId: number,

	Economy: EconomyService.EconomyService,

	Inventory: { [string]: number },
	PendingCash: number,

	Spawns: { BasePart },
	Workers: { [number]: Worker.Worker? },

	SlotFolders: { Folder },
	SlotIds: { string },
	SlotIndexById: { [string]: number },

	CustomerSpawn: BasePart,
	CustomerCounter: BasePart,
	CustomerExit: BasePart,

	CustomerQueueSpots: { BasePart },

	ProductionCallback: ProductionCallback?,
}

export type Factory = typeof(setmetatable({} :: FactoryData, Factory))

function Factory.new(model: Model, ownerUserId: number, economy: EconomyService.EconomyService): Factory
	-- Configure customer data prior to assigning data
	local customerSpawn = model:WaitForChild("CustomerSpawn")
	local customerCounter = model:WaitForChild("CustomerCounter")
	local customerExit = model:WaitForChild("CustomerExit")
	local customerQueueFolder = model:WaitForChild("CustomerQueueSpots")

	assert(customerSpawn:IsA("BasePart"), "CustomerSpawn must be a BasePart!")
	assert(customerCounter:IsA("BasePart"), "CustomerCounter must be a BasePart!")
	assert(customerExit:IsA("BasePart"), "CustomerExit must be a BasePart!")
	assert(customerQueueFolder:IsA("Folder"), "CustomerQueueFolder must be a Folder!")

	local customerQueueSpots: { BasePart } = {}

	for _, child in customerQueueFolder:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end

		table.insert(customerQueueSpots, child)
	end

	table.sort(customerQueueSpots, function(a: BasePart, b: BasePart)
		return a.Name < b.Name
	end)

	assert(#customerQueueSpots > 0, "Factory must have at least one CustomerQueueSpot!")

	local data: FactoryData = {
		Id = model.Name,
		Model = model,
		OwnerUserId = ownerUserId,

		Economy = economy,

		Inventory = {},
		PendingCash = 0,

		Spawns = {},
		Workers = {},

		SlotFolders = {},
		SlotIds = {},
		SlotIndexById = {},

		CustomerSpawn = customerSpawn,
		CustomerCounter = customerCounter,
		CustomerExit = customerExit,

		CustomerQueueSpots = customerQueueSpots,

		ProductionCallback = nil,
	}

	local self: Factory = setmetatable(data, Factory)

	local slotsFolder = model:WaitForChild("WorkerSlots")
	assert(slotsFolder:IsA("Folder"), "WorkerSlots must be a Folder!")

	-- Gather worker spawn points
	local slotFolders: { Folder } = {}

	for _, child in slotsFolder:GetChildren() do
		if not child:IsA("Folder") then
			continue
		end

		table.insert(slotFolders, child)
	end

	assert(#slotFolders > 0, "Factory has no Slots!")

	-- Sort slots by name
	table.sort(slotFolders, function(a: Folder, b: Folder): boolean
		return a.Name < b.Name
	end)

	-- Get worker spawns
	for _, slotFolder in slotFolders do
		local workerSpawn = slotFolder:FindFirstChild("WorkerSpawn")

		if not workerSpawn or not workerSpawn:IsA("BasePart") then
			warn("[FACTORY]", slotFolder:GetFullName(), "is missing WorkerSpawn!")

			continue
		end

		-- Current starter factories use stable folder name as persistent identity.
		-- Future placed slots will have GUID stored in SlotId attribute.
		local slotIdAttribute = slotFolder:GetAttribute("SlotId")
		local slotId = if typeof(slotIdAttribute) == "string" and slotIdAttribute ~= ""
			then slotIdAttribute
			else slotFolder.Name

		assert(self.SlotIndexById[slotId] == nil, `Duplicate factory SlotId: {slotId}`)

		-- Use valid slot count rather than original folder index
		local slotIndex = #self.Spawns + 1

		table.insert(self.SlotFolders, slotFolder)
		table.insert(self.Spawns, workerSpawn)
		table.insert(self.SlotIds, slotId)
		self.SlotIndexById[slotId] = slotIndex
	end

	assert(#self.Spawns > 0, "Factory has no Worker Spawnpoints!")

	local collector = model:WaitForChild("MoneyCollector")
	assert(collector:IsA("BasePart"), "MoneyCollector must be a BasePart!")

	-- Create collection interaction
	local existingPrompt = collector:FindFirstChildOfClass("ProximityPrompt")
	local prompt: ProximityPrompt

	if existingPrompt then
		prompt = existingPrompt
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = collector
	end

	prompt.ActionText = "Collect"
	prompt.ObjectText = "Factory Cash"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.ClickablePrompt = false
	prompt.RequiresLineOfSight = false

	prompt:SetAttribute("PromptAccess", "Owner")
	prompt:SetAttribute("OwnerUserId", self.OwnerUserId)

	prompt.Triggered:Connect(function(plr)
		self:Collect(plr)
	end)

	return self
end

-- Workers --
function Factory.PlaceWorker(self: Factory, worker: Worker.Worker): boolean
	for slotIndex = 1, #self.Spawns do
		if self.Workers[slotIndex] ~= nil then
			continue
		end

		return self:PlaceWorkerInSlot(worker, slotIndex)
	end

	return false
end

function Factory.PlaceWorkerInSlot(self: Factory, worker: Worker.Worker, slotIndex: number): boolean
	-- Worker already assigned somewhere else
	if worker.FactoryId ~= nil then
		return false
	end

	-- Invalid slot
	local spawnpoint = self.Spawns[slotIndex]
	if not spawnpoint then
		return false
	end

	-- Slot occupied
	if self.Workers[slotIndex] ~= nil then
		return false
	end

	-- Persistent slot identity
	local slotId = self:GetSlotId(slotIndex)
	if not slotId then
		return false
	end

	-- Spawn/reposition model
	if worker.Model then
		worker.Model:PivotTo(spawnpoint.CFrame)
	else
		worker:Spawn(spawnpoint.CFrame)
	end

	local model = worker.Model
	if not model then
		return false
	end

	model.Parent = self.Model

	-- Runtime assignment
	worker.OwnerUserId = self.OwnerUserId
	worker.FactoryId = self.Id
	worker.CarrierUserId = nil
	worker.State = "Placed"

	self.Workers[slotIndex] = worker

	-- Production output
	worker:SetProductionCallback(function(itemId: string, amount: number)
		local productionCallback = self.ProductionCallback
		if productionCallback then
			productionCallback(worker, itemId, amount)

			return
		end

		warn("[FACTORY]", self.Id, "has no ProductionCallback configured; adding output directly!")

		self:AddItem(itemId, amount)
	end)

	-- Assemblers require inventory access
	if worker.WorkerType == "Assembler" then
		worker:SetCanProduceCallback(function(inputs: { [string]: number })
			return self:HasItems(inputs)
		end)

		worker:SetConsumeInputsCallback(function(inputs: { [string]: number })
			return self:RemoveItems(inputs)
		end)
	end

	-- Theft prompt
	self:ConfigureStealPrompt(worker, slotIndex)

	-- Start production
	worker:StartWorking()

	-- Persist SlotId -> WorkerId
	GameEvents.FactoryWorkerAssigned:Fire(self.OwnerUserId, slotId, worker.Id)

	return true
end

function Factory.DetachWorkerFromSlot(self: Factory, slotIndex: number): Worker.Worker?
	local worker = self.Workers[slotIndex]
	if not worker then
		return nil
	end

	local slotId = self:GetSlotId(slotIndex)

	-- Stop production
	worker:StopWorking()
	worker:ClearFactoryCallbacks()

	-- Disable theft prompt while detached
	if worker.Model then
		local stealPrompt = worker.Model:FindFirstChild("StealPrompt", true)
		if stealPrompt and stealPrompt:IsA("ProximityPrompt") then
			stealPrompt.Enabled = false
		end
	end

	-- Runtime assignment removed
	self.Workers[slotIndex] = nil
	worker.FactoryId = nil

	-- Persist removal from this SlotId
	if slotId then
		GameEvents.FactoryWorkerUnassigned:Fire(self.OwnerUserId, slotId, worker.Id)
	end

	return worker
end

function Factory.RemoveWorkerFromSlot(self: Factory, slotIndex: number): Worker.Worker?
	local worker = self:DetachWorkerFromSlot(slotIndex)

	if not worker then
		return nil
	end

	worker.State = "Stored"
	worker.CarrierUserId = nil

	-- Remove model but not worker object
	if worker.Model then
		worker.Model:Destroy()
		worker.Model = nil
	end

	return worker
end

-- Theft --
function Factory.ConfigureStealPrompt(self: Factory, worker: Worker.Worker, slotIndex: number): ()
	local root = worker:GetRootPart()
	if not root then
		warn(worker.WorkerType, "has no root part for steal prompt!")

		return
	end

	local definition = WorkerConfig[worker.WorkerType]
	if not definition then
		return
	end

	local temperDefinition = TemperConfig[worker.Temper]
	if not temperDefinition then
		return
	end

	local existing = root:FindFirstChild("StealPrompt")
	local prompt: ProximityPrompt

	if existing and existing:IsA("ProximityPrompt") then
		prompt = existing
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StealPrompt"
		prompt.Parent = root
	end

	prompt.ActionText = "Grab"
	prompt.ObjectText = definition.DisplayName
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = true
	prompt.ClickablePrompt = false
	prompt.HoldDuration = temperDefinition.GrabHoldDuration
	prompt.Enabled = true

	prompt:SetAttribute("FactoryId", self.Id)
	prompt:SetAttribute("SlotIndex", slotIndex)
	prompt:SetAttribute("WorkerId", worker.Id)

	prompt:SetAttribute("PromptAccess", "Steal")
	prompt:SetAttribute("OwnerUserId", worker.OwnerUserId)
end

-- Cash --
function Factory.Collect(self: Factory, plr: Player): boolean
	-- Collector does not trust client
	if plr.UserId ~= self.OwnerUserId then
		return false
	end

	if self.PendingCash <= 0 then
		return false
	end

	local amount = self:TakePendingCash(self.PendingCash)
	if amount <= 0 then
		return false
	end

	self.Economy:AddCash(plr, amount)

	return true
end

function Factory.TrySellItem(self: Factory, itemId: string): boolean
	local itemDefinition = ItemConfig[itemId]
	if not itemDefinition then
		return false
	end

	if itemDefinition.SellPrice <= 0 then
		return false
	end

	if not self:RemoveItem(itemId, 1) then
		return false
	end

	local cashEarned = itemDefinition.SellPrice

	self:AddPendingCash(cashEarned)

	GameEvents.ItemSold:Fire(
		self.OwnerUserId,
		itemId,
		cashEarned
	)

	return true
end

function Factory.LoadPendingCash(self: Factory, amount: number): ()
	self.PendingCash = math.max(0, math.floor(amount))
end

function Factory.AddPendingCash(self: Factory, amount: number): number
	amount = math.max(0, math.floor(amount))

	if amount <= 0 then
		return self.PendingCash
	end

	self.PendingCash += amount

	-- Broadcast new pending cash
	GameEvents.FactoryCashChanged:Fire(self.OwnerUserId, self.PendingCash)

	return self.PendingCash
end

function Factory.TakePendingCash(self: Factory, amount: number): number
	amount = math.max(0, math.floor(amount))

	local taken = math.min(amount, self.PendingCash)
	if taken <= 0 then
		return 0
	end

	self.PendingCash -= taken

	-- Broadcast new pending cash
	GameEvents.FactoryCashChanged:Fire(self.OwnerUserId, self.PendingCash)

	return taken
end

-- Inventory --
function Factory.AddItem(self: Factory, itemId: string, amount: number): ()
	if amount <= 0 then
		return
	end

	local currentAmount = self.Inventory[itemId] or 0
	self.Inventory[itemId] = currentAmount + amount
end

function Factory.RemoveItem(self: Factory, itemId: string, amount: number): boolean
	if amount <= 0 then
		return false
	end

	local currentAmount = self.Inventory[itemId] or 0

	if currentAmount < amount then
		return false
	end

	self.Inventory[itemId] = currentAmount - amount

	return true
end

function Factory.HasItem(self: Factory, itemId: string, amount: number): boolean
	return (self.Inventory[itemId] or 0) >= amount
end

function Factory.HasItems(self: Factory, items: { [string]: number }): boolean
	for itemId, amount in items do
		if not self:HasItem(itemId, amount) then
			return false
		end
	end

	return true
end

function Factory.RemoveItems(self: Factory, items: { [string]: number }): boolean
	if not self:HasItems(items) then
		return false
	end

	for itemId, amount in items do
		self:RemoveItem(itemId, amount)
	end

	return true
end

function Factory.GetAvailableSellableItems(self: Factory): { string }
	local result: { string } = {}

	for itemId, amount in self.Inventory do
		if amount <= 0 then
			continue
		end

		local definition = ItemConfig[itemId]
		if not definition then
			continue
		end

		if definition.SellPrice <= 0 then
			continue
		end

		table.insert(result, itemId)
	end

	return result
end

-- Slots --
function Factory.GetSlotId(self: Factory, slotIndex: number): string?
	return self.SlotIds[slotIndex]
end

function Factory.GetSlotIndexById(self: Factory, slotId: string): number?
	return self.SlotIndexById[slotId]
end

function Factory.GetSlotStationRole(self: Factory, slotIndex: number): string?
	local slotFolder = self.SlotFolders[slotIndex]
	if not slotFolder then
		return nil
	end

	local stationRole = slotFolder:GetAttribute("StationId")
	if typeof(stationRole) ~= "string" then
		return nil
	end

	return stationRole
end

function Factory.IsSlotOccupied(self: Factory, slotIndex: number): boolean
	return self.Workers[slotIndex] ~= nil
end

function Factory.GetSlotCount(self: Factory): number
	return #self.Spawns
end

function Factory.GetWorkerInSlot(self: Factory, slotIndex: number): Worker.Worker?
	return self.Workers[slotIndex]
end

function Factory.SetProductionCallback(self: Factory, callback: (Worker.Worker, string, number) -> ()): ()
	self.ProductionCallback = callback
end

return Factory