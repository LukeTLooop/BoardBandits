--!strict
-- Worker Placement service

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WorkerInventoryService = require(ServerScriptService.Services.WorkerInventoryService)
local WorkerService = require(ServerScriptService.Services.WorkerService)
local Factory = require(ServerScriptService.Classes.Factory)

local WorkerConfig = require(ReplicatedStorage.Shared.Config.WorkerConfig)

local GameEvents = require(ServerScriptService.Framework.GameEvents)

local WorkerPlacementService = {}
WorkerPlacementService.__index = WorkerPlacementService

type WorkerPlacementServiceData = {
	Inventory: WorkerInventoryService.WorkerInventoryService,
	Workers: WorkerService.WorkerService,
}

export type WorkerPlacementService = typeof(setmetatable({} :: WorkerPlacementServiceData, WorkerPlacementService))

function WorkerPlacementService.new(
	inventory: WorkerInventoryService.WorkerInventoryService,
	workers: WorkerService.WorkerService
): WorkerPlacementService
	local data: WorkerPlacementServiceData = {
		Inventory = inventory,
		Workers = workers,
	}

	return setmetatable(data, WorkerPlacementService)
end

function WorkerPlacementService.PlaceWorker(
	self: WorkerPlacementService,
	plr: Player,
	factory: Factory.Factory,
	workerId: string,
	slotIndex: number
): boolean
	-- Ensure player owns factory
	if factory.OwnerUserId ~= plr.UserId then
		return false
	end

	-- Slot exists and is empty
	if slotIndex < 1 or slotIndex > factory:GetSlotCount() then
		return false
	end

	if factory:IsSlotOccupied(slotIndex) then
		return false
	end

	-- Find ownership
	local ownedWorker = self.Inventory:GetWorker(plr, workerId)
	if not ownedWorker then
		return false
	end

	if ownedWorker.State ~= "Stored" then
		return false
	end

	-- Validate correct worker type for slot
	local definition = WorkerConfig[ownedWorker.WorkerType]
	if not definition then
		return false
	end

	local stationRole = factory:GetSlotStationRole(slotIndex)
	if not stationRole then
		return false
	end

	if definition.RoleName ~= stationRole then
		warn("[PLACEMENT]", plr.Name, "tried to place", ownedWorker.WorkerType, "into", stationRole)

		return false
	end

	-- Create same worker as runtime instance
	local runtimeWorker = self.Workers:CreateWorkerFromOwnedData(ownedWorker, plr.UserId)

	local placed = factory:PlaceWorkerInSlot(runtimeWorker, slotIndex)
	if not placed then
		-- Destroy if placement fails
		self.Workers:DestroyWorker(runtimeWorker.Id)
		return false
	end

	-- Update ownership data
	self.Inventory:SetWorkerPlaced(plr, ownedWorker.Id, factory.Id, slotIndex)

	local updatedWorker = self.Inventory:GetWorker(plr, ownedWorker.Id)

	if updatedWorker then
		GameEvents.WorkerPlaced:Fire(plr, updatedWorker, factory.Id, slotIndex)
	end

	return true
end

function WorkerPlacementService.PlaceFirstUnplacedWorker(
	self: WorkerPlacementService,
	plr: Player,
	factory: Factory.Factory,
	slotIndex: number
): boolean
	local workerData = self.Inventory:GetFirstUnplacedWorker(plr)
	if not workerData then
		return false
	end

	return self:PlaceWorker(plr, factory, workerData.Id, slotIndex)
end

function WorkerPlacementService.RemoveWorker(
	self: WorkerPlacementService,
	plr: Player,
	factory: Factory.Factory,
	slotIndex: number
): boolean
	-- Player must own factory
	if factory.OwnerUserId ~= plr.UserId then
		return false
	end

	local worker = factory:GetWorkerInSlot(slotIndex)
	if not worker then
		return false
	end

	-- Player must own worker
	local ownedWorker = self.Inventory:GetWorker(plr, worker.Id)
	if not ownedWorker then
		return false
	end

	local removedWorker = factory:RemoveWorkerFromSlot(slotIndex)
	if not removedWorker then
		return false
	end

	-- Update ownership record
	self.Inventory:SetWorkerStored(plr, worker.Id)

	local updatedWorker = self.Inventory:GetWorker(plr, worker.Id)

	if updatedWorker then
		GameEvents.WorkerRemoved:Fire(plr, updatedWorker)
	end

	return true
end

function WorkerPlacementService.GetWorkerInSlotData(
	self: WorkerPlacementService,
	plr: Player,
	factory: Factory.Factory,
	slotIndex: number
): WorkerInventoryService.OwnedWorkerData?
	if factory.OwnerUserId ~= plr.UserId then
		return nil
	end

	local worker = factory:GetWorkerInSlot(slotIndex)
	if not worker then
		return nil
	end

	return self.Inventory:GetWorker(plr, worker.Id)
end

return WorkerPlacementService
