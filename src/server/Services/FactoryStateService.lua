--!strict
-- Factory State Service

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local FactoryService = require(ServerScriptService.Services.FactoryService)
local WorkerInventoryService = require(ServerScriptService.Services.WorkerInventoryService)
local WorkerService = require(ServerScriptService.Services.WorkerService)

-- Config --
local WorkerConfig = require(ReplicatedStorage.Shared.Config.WorkerConfig)

-- Framework --
local GameEvents = require(ServerScriptService.Framework.GameEvents)

-- Service --
local FactoryStateService = {}
FactoryStateService.__index = FactoryStateService

-- Types --
type FactoryStateServiceData = {
	PlayerData: PlayerDataService.PlayerDataService,
	Factories: FactoryService.FactoryService,
	Inventory: WorkerInventoryService.WorkerInventoryService,
	Workers: WorkerService.WorkerService,

	HydratedFactories: {
		[number]: string,
	},

	Started: boolean,
}

export type FactoryStateService = typeof(setmetatable({} :: FactoryStateServiceData, FactoryStateService))

-- Constructor --
function FactoryStateService.new(
	playerData: PlayerDataService.PlayerDataService,
	factories: FactoryService.FactoryService,
	inventory: WorkerInventoryService.WorkerInventoryService,
	workers: WorkerService.WorkerService
): FactoryStateService
	local data: FactoryStateServiceData = {
		PlayerData = playerData,
		Factories = factories,
		Inventory = inventory,
		Workers = workers,

		HydratedFactories = {},

		Started = false,
	}

	return setmetatable(data, FactoryStateService)
end

-- Hydrate claimed factory from profile data --
function FactoryStateService.HydrateFactory(self: FactoryStateService, plr: Player): ()
	local factory = self.Factories:GetFactoryForPlayer(plr)
	if not factory then
		return
	end

	-- Do not restore runtime factory twice
	if self.HydratedFactories[plr.UserId] == factory.Id then
		return
	end

	local profile = self.PlayerData:GetProfileByUserId(plr.UserId)
	if not profile then
		return
	end

	local factoryData = profile.Factory

	-- Restore factory cash
	factory:LoadPendingCash(factoryData.PendingCash)

	-- Restore factory inventory
	factory:LoadInventory(factoryData.Inventory)

	-- Restore saved worker assignments
	local staleAssignments: { string } = {}
	for slotId, workerId in factoryData.WorkerAssignments do
		local slotIndex = factory:GetSlotIndexById(slotId)
		if not slotIndex then
			table.insert(staleAssignments, slotId)

			continue
		end

		-- Runtime slot already occupied
		if factory:IsSlotOccupied(slotIndex) then
			continue
		end

		-- Exact owned worker
		local workerData = self.Inventory:GetWorkerByUserId(plr.UserId, workerId)
		if not workerData then
			table.insert(staleAssignments, slotId)

			continue
		end

		-- Validate worker definition
		local definition = WorkerConfig[workerData.WorkerType]
		if not definition then
			table.insert(staleAssignments, slotId)

			self.Inventory:SetWorkerStoredByUserId(plr.UserId, workerId)

			continue
		end

		-- Validate station compatibility
		local stationRole = factory:GetSlotStationRole(slotIndex)
		if not stationRole or stationRole ~= definition.RoleName then
			table.insert(staleAssignments, slotId)

			self.Inventory:SetWorkerStoredByUserId(plr.UserId, workerId)

			continue
		end

		-- Recreate exact runtime worker
		local runtimeWorker = self.Workers:CreateWorkerFromOwnedData(workerData, plr.UserId)
		local placed = factory:PlaceWorkerInSlot(runtimeWorker, slotIndex)
		if not placed then
			table.insert(staleAssignments, slotId)

			self.Inventory:SetWorkerStoredByUserId(plr.UserId, workerId)

			continue
		end

		-- Sync owned worker runtime state
		self.Inventory:SetWorkerPlacedByUserId(plr.UserId, workerData.Id, factory.Id, slotIndex)
	end

	-- Remove broken saved references
	for _, slotId in staleAssignments do
		factoryData.WorkerAssignments[slotId] = nil
	end

	self.HydratedFactories[plr.UserId] = factory.Id
end

-- Start --
function FactoryStateService.Start(self: FactoryStateService): ()
	if self.Started then
		return
	end

	self.Started = true

	-- ProfileLoaded OR FactoryClaimed may happen first,
	-- Second one will successfully hydrate
	GameEvents.ProfileLoaded:Connect(function(plr: Player, _data)
		self:HydrateFactory(plr)
	end)

	GameEvents.FactoryClaimed:Connect(function(plr: Player, _factoryId: string)
		self:HydrateFactory(plr)
	end)

	GameEvents.FactoryReleased:Connect(function(ownerUserId: number, _factoryId: string)
		self.HydratedFactories[ownerUserId] = nil
	end)

	-- Runtime cash -> profile cash
	GameEvents.FactoryCashChanged:Connect(function(ownerUserId: number, newPendingCash: number)
		local profile = self.PlayerData:GetProfileByUserId(ownerUserId)
		if not profile then
			return
		end

		profile.Factory.PendingCash = newPendingCash
	end)

	-- Runtime inventory -> profile inventory
	GameEvents.FactoryInventoryChanged:Connect(function(ownerUserId: number, itemId: string, newAmount: number)
		local profile = self.PlayerData:GetProfileByUserId(ownerUserId)
		if not profile then
			return
		end

		if newAmount <= 0 then
			profile.Factory.Inventory[itemId] = nil
		else
			profile.Factory.Inventory[itemId] = newAmount
		end
	end)

	-- Runtime placement -> profile assignment
	GameEvents.FactoryWorkerAssigned:Connect(function(ownerUserId: number, slotId: string, workerId: string)
		local profile = self.PlayerData:GetProfileByUserId(ownerUserId)
		if not profile then
			return
		end

		profile.Factory.WorkerAssignments[slotId] = workerId
	end)

	-- Runtime removal -> remove saved assignment
	GameEvents.FactoryWorkerUnassigned:Connect(function(ownerUserId: number, slotId: string, _workerId: string)
		local profile = self.PlayerData:GetProfileByUserId(ownerUserId)
		if not profile then
			return
		end

		profile.Factory.WorkerAssignments[slotId] = nil
	end)
end

return FactoryStateService
