--!strict
-- Factory service

-- Services --
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyService = require(ServerScriptService.Services.EconomyService)
local CustomerService = require(ServerScriptService.Services.CustomerService)
local TheftService = require(ServerScriptService.Services.TheftService)
local WorkerInventoryService = require(ServerScriptService.Services.WorkerInventoryService)
local WorkerService = require(ServerScriptService.Services.WorkerService)
local ProgressionService = require(ServerScriptService.Services.ProgressionService)
local ProductionService = require(ServerScriptService.Services.ProductionService)

-- Classes --
local Factory = require(ServerScriptService.Classes.Factory)

-- Types --
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

-- Framework --
local GameEvents = require(ServerScriptService.Framework.GameEvents)

-- Service --
local FactoryService = {}
FactoryService.__index = FactoryService

-- Types --
type FactoryServiceData = {
	Economy: EconomyService.EconomyService,
	Customers: CustomerService.CustomerService,
	Theft: TheftService.TheftService,
	WorkerInventory: WorkerInventoryService.WorkerInventoryService,
	Workers: WorkerService.WorkerService,
	Progression: ProgressionService.ProgressionService,
	Production: ProductionService.ProductionService,

	FactoriesByOwner: { [number]: Factory.Factory },
	FactoriesById: { [string]: Factory.Factory },

	FactoryModels: { Model },
	ClaimedModels: { [Model]: boolean },

	OpenInventory: RemoteEvent,
	OpenWorkerDetails: RemoteEvent,

	Started: boolean,
}

export type FactoryService = typeof(setmetatable({} :: FactoryServiceData, FactoryService))

-- Constructor --
function FactoryService.new(
	economy: EconomyService.EconomyService,
	customers: CustomerService.CustomerService,
	theft: TheftService.TheftService,
	workerInventory: WorkerInventoryService.WorkerInventoryService,
	workers: WorkerService.WorkerService,
	progression: ProgressionService.ProgressionService,
	production: ProductionService.ProductionService
): FactoryService
	-- Remotes
	local workerRemotes = ReplicatedStorage.Remotes.Workers

	local openInventory = workerRemotes.OpenInventory
	local openWorkerDetails = workerRemotes.OpenWorkerDetails

	assert(openInventory:IsA("RemoteEvent"), "OpenInventory must be a RemoteEvent!")
	assert(openWorkerDetails:IsA("RemoteEvent"), "OpenWorkerDetails must be a RemoteEvent!")

	-- Data
	local data: FactoryServiceData = {
		Economy = economy,
		Customers = customers,
		Theft = theft,
		WorkerInventory = workerInventory,
		Workers = workers,
		Progression = progression,
		Production = production,

		FactoriesByOwner = {},
		FactoriesById = {},

		FactoryModels = {},
		ClaimedModels = {},

		OpenInventory = openInventory,
		OpenWorkerDetails = openWorkerDetails,

		Started = false,
	}

	return setmetatable(data, FactoryService)
end

-- Factory discovery --
function FactoryService.LoadFactoryModels(self: FactoryService): ()
	local factoriesFolder = workspace.Factories
	local models: { Model } = {}

	for _, child in factoriesFolder:GetChildren() do
		if not child:IsA("Model") then
			continue
		end

		-- Disable spawns until claimed
		local spawnpoint = child:FindFirstChild("PlayerSpawn")
		if spawnpoint and spawnpoint:IsA("SpawnLocation") then
			spawnpoint.Enabled = false
			--spawnpoint.Neutral = false
		end

		table.insert(models, child)
	end

	table.sort(models, function(a: Model, b: Model)
		return a.Name < b.Name
	end)

	self.FactoryModels = models
end

-- Lookup --
function FactoryService.GetFactoryForPlayer(self: FactoryService, plr: Player): Factory.Factory?
	return self.FactoriesByOwner[plr.UserId]
end

function FactoryService.GetFactoryByUserId(self: FactoryService, userId: number): Factory.Factory?
	return self.FactoriesByOwner[userId]
end

function FactoryService.GetFactoryById(self: FactoryService, factoryId: string): Factory.Factory?
	return self.FactoriesById[factoryId]
end

-- Worker slots --
function FactoryService.SetupWorkerSlots(self: FactoryService, factory: Factory.Factory): ()
	local slotsFolder = factory.Model:FindFirstChild("WorkerSlots")
	if not slotsFolder or not slotsFolder:IsA("Folder") then
		warn(factory.Id, "has invalid WorkerSlots")

		return
	end

	local slotFolders: { Folder } = {}
	for _, child in slotsFolder:GetChildren() do
		if not child:IsA("Folder") then
			continue
		end

		table.insert(slotFolders, child)
	end

	table.sort(slotFolders, function(a: Folder, b: Folder)
		return a.Name < b.Name
	end)

	local slotIndex = 0
	for _, slot in slotFolders do
		-- Only count slots Factory would validate
		local spawnpoint = slot:FindFirstChild("WorkerSpawn")
		if not spawnpoint or not spawnpoint:IsA("BasePart") then
			continue
		end

		slotIndex += 1
		local currentSlotIndex = slotIndex

		local placementPart = slot:FindFirstChild("PlacementPart")
		if not placementPart or not placementPart:IsA("BasePart") then
			warn(slot:GetFullName(), "is missing PlacementPart")

			continue
		end

		-- Prompt
		local prompt: ProximityPrompt
		local existing = placementPart:FindFirstChildOfClass("ProximityPrompt")
		if existing then
			prompt = existing
		else
			prompt = Instance.new("ProximityPrompt")
			prompt.Parent = placementPart
		end

		-- Generic text means constant refresh is not required
		prompt.ActionText = "Use Station"
		prompt.ObjectText = `Slot {currentSlotIndex}`
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.ClickablePrompt = false

		prompt:SetAttribute("PromptAccess", "Owner")
		prompt:SetAttribute("OwnerUserId", factory.OwnerUserId)

		-- Interaction
		prompt.Triggered:Connect(function(plr: Player)
			-- Owner only
			if factory.OwnerUserId ~= plr.UserId then
				return
			end

			-- Occupied, manage existing worker
			if factory:IsSlotOccupied(currentSlotIndex) then
				self.OpenWorkerDetails:FireClient(plr, currentSlotIndex)

				return
			end

			-- Empty station
			local hasStoredWorkers = self.WorkerInventory:HasStoredWorkers(plr)
			local canPurchaseWorkers = self.Progression:CanPurchaseWorkers(plr)

			-- Player hasn't reached automation yet or no worker available
			-- Manual production
			local stationId = slot:GetAttribute("StationId")

			if typeof(stationId) ~= "string" then
				warn("[FACTORY]", slot:GetFullName(), "is missing StationId!")

				return
			end

			if not canPurchaseWorkers or not hasStoredWorkers then
				self.Production:StartManualProduction(plr, factory, currentSlotIndex, stationId)

				return
			end

			-- Automation unlocked + worker in storage
			-- Offer placement
			self.OpenInventory:FireClient(plr, factory.Id, currentSlotIndex, stationId)
		end)
	end
end

-- Start --
function FactoryService.Start(self: FactoryService): ()
	if self.Started then
		return
	end
	self.Started = true

	self:LoadFactoryModels()

	for _, factoryModel in self.FactoryModels do
		self:SetupClaimPrompt(factoryModel)
	end

	GameEvents.ProfileLoaded:Connect(function(plr: Player, _profile: PlayerDataTypes.PlayerData)
		print("[FactoryService]", plr.Name, "profile ready")
	end)

	GameEvents.ProfileRemoving:Connect(function(plr: Player, _profile: PlayerDataTypes.PlayerData)
		self:ReleaseFactory(plr)
	end)
end

-- Setup Claim --
function FactoryService.SetupClaimPrompt(self: FactoryService, factoryModel: Model): ()
	local claimPart = factoryModel:FindFirstChild("ClaimPart")
	if not claimPart or not claimPart:IsA("BasePart") then
		warn(factoryModel.Name, "is missing ClaimPart")

		return
	end

	local prompt: ProximityPrompt
	local existing = claimPart:FindFirstChildOfClass("ProximityPrompt")
	if existing then
		prompt = existing
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = claimPart
	end

	prompt.Name = "ClaimFactoryPrompt"

	prompt.ActionText = "Claim Factory"
	prompt.ObjectText = factoryModel.Name

	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 100
	prompt.ClickablePrompt = false
	prompt.Enabled = true

	prompt:SetAttribute("PromptAccess", "ClaimFactory")

	prompt.Triggered:Connect(function(plr: Player)
		self:ClaimFactory(plr, factoryModel)
	end)
end

function FactoryService.ClaimFactory(self: FactoryService, plr: Player, factoryModel: Model): Factory.Factory?
	-- Player already owns a factory
	if self.FactoriesByOwner[plr.UserId] then
		return nil
	end

	-- Factory already claimed
	if self.ClaimedModels[factoryModel] then
		return nil
	end

	-- Reserve factory
	self.ClaimedModels[factoryModel] = true

	-- Create
	local factory = Factory.new(factoryModel, plr.UserId, self.Economy)

	-- Set production callback
	factory:SetProductionCallback(function(worker, itemId: string, amount: number)
		local source: ProductionService.ProductionSource

		if worker.WorkerType == "Assembler" then
			source = "Assembler"
		else
			source = "Worker"
		end

		self.Production:AddProductionOutput(factory, itemId, amount, source, worker.Id)
	end)

	self.FactoriesByOwner[plr.UserId] = factory
	self.FactoriesById[factory.Id] = factory

	plr:SetAttribute("ClaimedFactoryId", factory.Id)

	factoryModel:SetAttribute("OwnerUserId", plr.UserId)

	-- Disable claim prompt
	local claimPart = factoryModel:FindFirstChild("ClaimPart")
	if claimPart and claimPart:IsA("BasePart") then
		local prompt = claimPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = false
		end
	end

	-- Factory systems
	self:SetupWorkerSlots(factory)
	self:SetupTerritory(factory)

	self.Theft:RegisterFactory(factory)

	-- Customers
	local customerType: string
	local customerTypeAttribute = factoryModel:GetAttribute("CustomerType")
	if typeof(customerTypeAttribute) ~= "string" then
		customerType = "BasicCustomer"
	else
		customerType = customerTypeAttribute
	end

	self.Customers:StartFactory(factory, customerType)

	-- Spawn
	local spawnpoint = factoryModel:FindFirstChild("PlayerSpawn")
	if spawnpoint and spawnpoint:IsA("SpawnLocation") then
		spawnpoint.Enabled = true
		--spawnpoint.Neutral = false

		plr.RespawnLocation = spawnpoint

		task.defer(function()
			if plr.Parent == Players then
				plr:LoadCharacterAsync()
			end
		end)
	else
		warn(factory.Id, "is missing PlayerSpawn SpawnLocation!")
	end

	GameEvents.FactoryClaimed:Fire(plr, factory.Id)

	print(plr.Name, "claimed", factory.Id)

	return factory
end

function FactoryService.CleanupFactoryInteractions(self: FactoryService, factory: Factory.Factory): ()
	for _, slotFolder in factory.SlotFolders do
		local placementPart = slotFolder:FindFirstChild("PlacementPart")
		if not placementPart or not placementPart:IsA("BasePart") then
			continue
		end

		local prompt = placementPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt:Destroy()
		end
	end

	local collector = factory.Model:FindFirstChild("MoneyCollector")
	if collector and collector:IsA("BasePart") then
		for _, child in collector:GetChildren() do
			if not child:IsA("ProximityPrompt") then
				continue
			end

			child:Destroy()
		end
	end
end

function FactoryService.ReleaseFactory(self: FactoryService, plr: Player): boolean
	local factory = self.FactoriesByOwner[plr.UserId]
	if not factory then
		return false
	end

	-- Stop gameplay systems before removing runtime state.
	self.Production:CancelManualProduction(plr)
	self.Customers:StopFactory(factory.Id)
	self.Theft:ReturnWorkersOwnedByUserId(plr.UserId)
	self.Theft:UnregisterFactory(factory.Id)

	-- Destroy runtime workers without calling Factory removal methods.
	-- Persistent SlotId -> WorkerId assignments must remain intact for save/hydration.
	-- Carried workers are preserved for the dedicated theft lifecycle cleanup pass.
	self.Workers:DestroyWorkersForOwner(plr.UserId, true)

	table.clear(factory.Workers)

	self:CleanupFactoryInteractions(factory)

	-- Remove runtime lookup state.
	self.FactoriesByOwner[plr.UserId] = nil
	self.FactoriesById[factory.Id] = nil
	self.ClaimedModels[factory.Model] = nil

	plr:SetAttribute("ClaimedFactoryId", nil)

	local factoryModel = factory.Model
	factoryModel:SetAttribute("OwnerUserId", nil)

	local territory = factoryModel:FindFirstChild("Territory")
	if territory and territory:IsA("BasePart") then
		territory:SetAttribute("FactoryId", nil)
		territory:SetAttribute("OwnerUserId", nil)
	end

	local spawnpoint = factoryModel:FindFirstChild("PlayerSpawn")
	if spawnpoint and spawnpoint:IsA("SpawnLocation") then
		spawnpoint.Enabled = false

		if plr.RespawnLocation == spawnpoint then
			plr.RespawnLocation = nil
		end
	end

	local claimPart = factoryModel:FindFirstChild("ClaimPart")
	if claimPart and claimPart:IsA("BasePart") then
		local prompt = claimPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = true
		end
	end

	GameEvents.FactoryReleased:Fire(plr.UserId, factory.Id)

	print(plr.Name, "released", factory.Id)

	return true
end

function FactoryService.SetupTerritory(self: FactoryService, factory: Factory.Factory): ()
	local territory = factory.Model:FindFirstChild("Territory")
	if not territory or not territory:IsA("BasePart") then
		warn(factory.Id, "is missing Territory!")

		return
	end

	territory.Transparency = 1
	territory.CanCollide = false
	territory.CanTouch = true
	territory.Anchored = true

	territory:SetAttribute("FactoryId", factory.Id)
	territory:SetAttribute("OwnerUserId", factory.OwnerUserId)
end

return FactoryService
