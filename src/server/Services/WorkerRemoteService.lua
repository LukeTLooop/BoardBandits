--!strict
-- Worker Remote Service

-- Services --
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactoryService = require(ServerScriptService.Services.FactoryService)
local WorkerInventoryService = require(ServerScriptService.Services.WorkerInventoryService)
local WorkerPlacementService = require(ServerScriptService.Services.WorkerPlacementService)
local WorkerUpgradeService = require(ServerScriptService.Services.WorkerUpgradeService)
local WorkerShopService = require(ServerScriptService.Services.WorkerShopService)

-- Types --
local WorkerShopTypes = require(ReplicatedStorage.Shared.Types.WorkerShopTypes)
local WorkerDetailsTypes = require(ReplicatedStorage.Shared.Types.WorkerDetailsTypes)
local WorkerUpgradeTypes = require(ReplicatedStorage.Shared.Types.WorkerUpgradeTypes)

-- Service --
local WorkerRemoteService = {}
WorkerRemoteService.__index = WorkerRemoteService

-- Types --
type WorkerRemoteServiceData = {
	Factories: FactoryService.FactoryService,
	Inventory: WorkerInventoryService.WorkerInventoryService,
	Placement: WorkerPlacementService.WorkerPlacementService,
	Upgrade: WorkerUpgradeService.WorkerUpgradeService,
	Shop: WorkerShopService.WorkerShopService,

	Started: boolean,
}

export type WorkerRemoteService = typeof(setmetatable({} :: WorkerRemoteServiceData, WorkerRemoteService))

-- Constructor --
function WorkerRemoteService.new(
	factories: FactoryService.FactoryService,
	inventory: WorkerInventoryService.WorkerInventoryService,
	placement: WorkerPlacementService.WorkerPlacementService,
	upgrade: WorkerUpgradeService.WorkerUpgradeService,
	shop: WorkerShopService.WorkerShopService
): WorkerRemoteService
	local data: WorkerRemoteServiceData = {
		Factories = factories,
		Inventory = inventory,
		Placement = placement,
		Upgrade = upgrade,
		Shop = shop,

		Started = false,
	}

	return setmetatable(data, WorkerRemoteService)
end

-- Start --
function WorkerRemoteService.Start(self: WorkerRemoteService): ()
	if self.Started then
		return
	end
	self.Started = true

	-- Get remotes
	local remotes = ReplicatedStorage.Remotes.Workers

	local requestInventory = remotes.RequestInventory
	local placeWorker = remotes.PlaceWorker
	local removeWorker = remotes.RemoveWorker
	local upgradeWorker = remotes.UpgradeWorker
	local requestWorkerDetails = remotes.RequestWorkerDetails
	local requestWorkerShopState = remotes.RequestWorkerShopState
	local buyWorker = remotes.BuyWorker

	assert(requestInventory:IsA("RemoteFunction"), "RequestInventory must be a RemoteFunction!")
	assert(placeWorker:IsA("RemoteFunction"), "PlaceWorker must be a RemoteFunction!")
	assert(removeWorker:IsA("RemoteFunction"), "RemoveWorker must be a RemoteFunction!")
	assert(upgradeWorker:IsA("RemoteFunction"), "UpgradeWorker must be a RemoteFunction!")
	assert(requestWorkerDetails:IsA("RemoteFunction"), "RequestWorkerDetails must be a RemoteFunction!")
	assert(requestWorkerShopState:IsA("RemoteFunction"), "RequestWorkerShopState must be a RemoteFunction!")
	assert(buyWorker:IsA("RemoteFunction"), "BuyWorker must be a RemoteFunction!")

	-- Inventory
	requestInventory.OnServerInvoke = function(plr: Player)
		return self.Inventory:GetClientInventory(plr)
	end

	-- Placement
	placeWorker.OnServerInvoke = function(plr: Player, workerId: string, slotIndex: number): boolean
		if typeof(workerId) ~= "string" then
			return false
		end

		if typeof(slotIndex) ~= "number" then
			return false
		end

		local factory = self.Factories:GetFactoryForPlayer(plr)
		if not factory then
			return false
		end

		return self.Placement:PlaceWorker(plr, factory, workerId, slotIndex)
	end

	-- Remove
	removeWorker.OnServerInvoke = function(plr: Player, slotIndex: number): boolean
		if typeof(slotIndex) ~= "number" then
			return false
		end

		local factory = self.Factories:GetFactoryForPlayer(plr)
		if not factory then
			return false
		end

		return self.Placement:RemoveWorker(plr, factory, slotIndex)
	end

	-- Upgrade
	upgradeWorker.OnServerInvoke = function(plr: Player, workerId: string): WorkerUpgradeTypes.UpgradeResult
		if typeof(workerId) ~= "string" then
			return {
				Success = false,
				UnlockedProductionTier = false,
			}
		end

		return self.Upgrade:UpgradeWorker(plr, workerId)
	end

	requestWorkerDetails.OnServerInvoke = function(plr: Player, slotIndex: number): WorkerDetailsTypes.DetailsData?
		if typeof(slotIndex) ~= "number" then
			return nil
		end

		local factory = self.Factories:GetFactoryForPlayer(plr)
		if not factory then
			return nil
		end

		local runtimeWorker = factory:GetWorkerInSlot(slotIndex)
		if not runtimeWorker then
			return nil
		end

		local ownedWorker = self.Inventory:GetWorker(plr, runtimeWorker.Id)
		if not ownedWorker then
			return nil
		end

		local upgradeState = self.Upgrade:GetUpgradeState(plr, ownedWorker.Id)
		if not upgradeState then
			return nil
		end

		return {
			Id = ownedWorker.Id,
			WorkerType = ownedWorker.WorkerType,
			Level = ownedWorker.Level,
			Temper = ownedWorker.Temper,
			Upgrade = upgradeState,
		}
	end

	-- Shop
	requestWorkerShopState.OnServerInvoke = function(plr: Player): WorkerShopTypes.ShopState
		return self.Shop:GetShopState(plr)
	end

	buyWorker.OnServerInvoke = function(plr: Player, workerType): WorkerShopTypes.PurchaseResult
		if typeof(workerType) ~= "string" then
			return {
				Success = false,
				Message = "Invalid worker.",
				Cash = self.Shop:GetShopState(plr).Cash,
			}
		end

		return self.Shop:BuyWorker(plr, workerType)
	end
end

return WorkerRemoteService
