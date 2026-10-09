--!strict
-- Worker Inventory Service --

-- Services --
local HTTPService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

-- Config --
local TemperConfig = require(ReplicatedStorage.Shared.Config.TemperConfig)

-- Types --
local WorkerTypes = require(ReplicatedStorage.Shared.Types.WorkerTypes)

-- Service --
local WorkerInventoryService = {}
WorkerInventoryService.__index = WorkerInventoryService

--  Types --
export type OwnedWorkerData = WorkerTypes.OwnedWorkerData

type WorkerInventoryServiceData = {
	PlayerData: PlayerDataService.PlayerDataService,
}

export type WorkerInventoryService = typeof(setmetatable({} :: WorkerInventoryServiceData, WorkerInventoryService))

-- RNG --
local rng = Random.new()

-- Helpers --
local function rollTemper(): WorkerTypes.WorkerTemper
	local totalWeight = 0

	for _, definition in TemperConfig do
		totalWeight += definition.RollWeight
	end

	local roll = rng:NextNumber(0, totalWeight)

	local runningWeight = 0

	for temperName, definition in TemperConfig do
		runningWeight += definition.RollWeight

		if roll <= runningWeight then
			return temperName :: WorkerTypes.WorkerTemper
		end
	end

	return "Normal"
end

-- Constructor --
function WorkerInventoryService.new(playerData: PlayerDataService.PlayerDataService): WorkerInventoryService
	local data: WorkerInventoryServiceData = {
		PlayerData = playerData,
	}

	return setmetatable(data, WorkerInventoryService)
end

-- Inventory --
function WorkerInventoryService.GetInventoryByUserId(self: WorkerInventoryService, userId: number): { OwnedWorkerData }
	local profile = self.PlayerData:RequireProfileByUserId(userId)
	return profile.Workers
end

function WorkerInventoryService.GetInventory(self: WorkerInventoryService, plr: Player): { OwnedWorkerData }
	local profile = self.PlayerData:RequireProfile(plr)
	return profile.Workers
end

-- Add --
function WorkerInventoryService.AddWorker(
	self: WorkerInventoryService,
	plr: Player,
	workerType: string
): OwnedWorkerData
	local workerData: OwnedWorkerData = {
		Id = HTTPService:GenerateGUID(false),
		WorkerType = workerType,
		Level = 1,

		Temper = rollTemper(),

		State = "Stored",

		FactoryId = nil,
		SlotIndex = nil,
		CarrierUserId = nil,
	}

	local inventory = self:GetInventory(plr)
	table.insert(inventory, workerData)

	--print(
	--	"Created",
	--	workerType,
	--	"with temper",
	--	workerData.Temper
	--)

	return workerData
end

-- Find --
function WorkerInventoryService.GetWorkerByUserId(
	self: WorkerInventoryService,
	userId: number,
	workerId: string
): OwnedWorkerData?
	local inventory = self:GetInventoryByUserId(userId)
	for _, workerData in inventory do
		if workerData.Id == workerId then
			return workerData
		end
	end

	return nil
end

function WorkerInventoryService.GetWorker(self: WorkerInventoryService, plr: Player, workerId: string): OwnedWorkerData?
	return self:GetWorkerByUserId(plr.UserId, workerId)
end

function WorkerInventoryService.GetFirstUnplacedWorker(self: WorkerInventoryService, plr: Player): OwnedWorkerData?
	local inventory = self:GetInventory(plr)

	for _, workerData in inventory do
		if workerData.State ~= "Stored" then
			continue
		end

		return workerData
	end

	return nil
end

-- State --
function WorkerInventoryService.UpdateWorkerState(
	self: WorkerInventoryService,
	ownerUserId: number,
	workerId: string,
	state: WorkerTypes.WorkerLocationState,
	factoryId: string?,
	slotIndex: number?,
	carrierUserId: number?
): boolean
	local worker = self:GetWorkerByUserId(ownerUserId, workerId)

	if not worker then
		return false
	end

	worker.State = state
	worker.FactoryId = factoryId
	worker.SlotIndex = slotIndex
	worker.CarrierUserId = carrierUserId

	return true
end

function WorkerInventoryService.SetWorkerPlacedByUserId(
	self: WorkerInventoryService,
	userId: number,
	workerId: string,
	factoryId: string,
	slotIndex: number
): boolean
	return self:UpdateWorkerState(userId, workerId, "Placed", factoryId, slotIndex, nil)
end

function WorkerInventoryService.SetWorkerPlaced(
	self: WorkerInventoryService,
	plr: Player,
	workerId: string,
	factoryId: string,
	slotIndex: number
): boolean
	return self:SetWorkerPlacedByUserId(plr.UserId, workerId, factoryId, slotIndex)
end

function WorkerInventoryService.SetWorkerStoredByUserId(
	self: WorkerInventoryService,
	userId: number,
	workerId: string
): boolean
	return self:UpdateWorkerState(userId, workerId, "Stored", nil, nil, nil)
end

function WorkerInventoryService.SetWorkerStored(self: WorkerInventoryService, plr: Player, workerId: string): boolean
	return self:SetWorkerStoredByUserId(plr.UserId, workerId)
end

function WorkerInventoryService.SetWorkerCarriedByUserId(
	self: WorkerInventoryService,
	userId: number,
	workerId: string,
	carrierUserId: number
): boolean
	return self:UpdateWorkerState(userId, workerId, "Carried", nil, nil, carrierUserId)
end

function WorkerInventoryService.SetWorkerDropped(self: WorkerInventoryService, plr: Player, workerId: string): boolean
	return self:SetWorkerDroppedByUserId(plr.UserId, workerId)
end

function WorkerInventoryService.SetWorkerDroppedByUserId(
	self: WorkerInventoryService,
	userId: number,
	workerId: string
): boolean
	return self:UpdateWorkerState(userId, workerId, "Dropped", nil, nil, nil)
end

function WorkerInventoryService.HasStoredWorkers(self: WorkerInventoryService, plr: Player): boolean
	return self:GetFirstUnplacedWorker(plr) ~= nil
end

-- Backwards-compatible placement helper --
function WorkerInventoryService.SetWorkerPlacement(
	self: WorkerInventoryService,
	plr: Player,
	workerId: string,
	factoryId: string?,
	slotIndex: number?
): boolean
	if factoryId and slotIndex then
		return self:SetWorkerPlaced(plr, workerId, factoryId, slotIndex)
	end

	return self:SetWorkerStored(plr, workerId)
end

-- Transfer worker to other player --
function WorkerInventoryService.TransferWorker(
	self: WorkerInventoryService,
	fromUserId: number,
	toUserId: number,
	workerId: string
): OwnedWorkerData?
	if fromUserId == toUserId then
		return nil
	end

	local fromInventory = self:GetInventoryByUserId(fromUserId)
	local toInventory = self:GetInventoryByUserId(toUserId)

	local foundIndex: number? = nil
	local workerData: OwnedWorkerData? = nil

	for index, currentWorker in fromInventory do
		if currentWorker.Id == workerId then
			foundIndex = index
			workerData = currentWorker

			break
		end
	end

	if not foundIndex or not workerData then
		return nil
	end

	-- Normalize transferred state
	workerData.State = "Stored"
	workerData.FactoryId = nil
	workerData.SlotIndex = nil
	workerData.CarrierUserId = nil

	-- Remove old ownership
	table.remove(fromInventory, foundIndex)

	-- Add new ownership
	table.insert(toInventory, workerData)

	return workerData
end

function WorkerInventoryService.TransferWorkerOwnership(
	self: WorkerInventoryService,
	fromUserId: number,
	toUserId: number,
	workerId: string
): OwnedWorkerData?
	if fromUserId == toUserId then
		return nil
	end

	local oldInventory = self:GetInventoryByUserId(fromUserId)

	local workerIndex: number? = nil
	local workerData: OwnedWorkerData

	for index, currentWorker in oldInventory do
		if currentWorker.Id ~= workerId then
			continue
		end

		workerIndex = index
		workerData = currentWorker

		break
	end

	if not workerIndex or not workerData then
		return nil
	end

	-- Remove exact worker from old owner
	table.remove(oldInventory, workerIndex)

	-- Convert worker to stored
	workerData.State = "Stored"
	workerData.FactoryId = nil
	workerData.SlotIndex = nil
	workerData.CarrierUserId = nil

	-- Give same worker to new owner
	local newInventory = self:GetInventoryByUserId(toUserId)

	table.insert(newInventory, workerData)

	return workerData
end

-- Client --
function WorkerInventoryService.GetClientInventory(
	self: WorkerInventoryService,
	plr: Player
): { WorkerTypes.ClientWorkerData }
	local inventory = self:GetInventory(plr)
	local result: { WorkerTypes.ClientWorkerData } = {}

	for _, workerData in inventory do
		table.insert(result, {
			Id = workerData.Id,
			WorkerType = workerData.WorkerType,
			Level = workerData.Level,
			Temper = workerData.Temper,
			State = workerData.State,
			IsPlaced = workerData.State == "Placed",
		})
	end

	return result
end

return WorkerInventoryService
