--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WorkerConfig = require(ReplicatedStorage.Shared.Config.WorkerConfig)

local EconomyService = require(ServerScriptService.Services.EconomyService)
local WorkerInventoryService = require(ServerScriptService.Services.WorkerInventoryService)
local WorkerService = require(ServerScriptService.Services.WorkerService)

local WorkerDetailsTypes = require(ReplicatedStorage.Shared.Types.WorkerDetailsTypes)
local WorkerUpgradeTypes = require(ReplicatedStorage.Shared.Types.WorkerUpgradeTypes)

local GameEvents = require(ServerScriptService.Framework.GameEvents)

local WorkerUpgradeService = {}
WorkerUpgradeService.__index = WorkerUpgradeService

type WorkerUpgradeServiceData = {
	Economy: EconomyService.EconomyService,
	Inventory: WorkerInventoryService.WorkerInventoryService,
	Workers: WorkerService.WorkerService,
}

export type WorkerUpgradeService = typeof(setmetatable({} :: WorkerUpgradeServiceData, WorkerUpgradeService))

local function getProductionTierId(definition: WorkerConfig.WorkerDefinition, level: number): string?
	local result: string? = nil

	if definition.WorkerType == "Producer" then
		for _, entry in definition.OutputProgression do
			if entry.RequiredLevel <= level then
				result = entry.Item
			else
				break
			end
		end

		return result
	end

	for _, entry in definition.RecipeProgression do
		if entry.RequiredLevel <= level then
			result = entry.Recipe
		else
			break
		end
	end

	return result
end

function WorkerUpgradeService.new(
	economy: EconomyService.EconomyService,
	inventory: WorkerInventoryService.WorkerInventoryService,
	workers: WorkerService.WorkerService
): WorkerUpgradeService
	local data: WorkerUpgradeServiceData = {
		Economy = economy,
		Inventory = inventory,
		Workers = workers,
	}

	return setmetatable(data, WorkerUpgradeService)
end

function WorkerUpgradeService.UpgradeWorker(
	self: WorkerUpgradeService,
	plr: Player,
	workerId: string
): WorkerUpgradeTypes.UpgradeResult
	local workerData = self.Inventory:GetWorker(plr, workerId)

	if not workerData then
		return {
			Success = false,
			UnlockedProductionTier = false,
		}
	end

	local definition = WorkerConfig[workerData.WorkerType]
	if not definition then
		return {
			Success = false,
			UnlockedProductionTier = false,
		}
	end

	if workerData.Level >= definition.MaxLevel then
		return {
			Success = false,
			UnlockedProductionTier = false,
		}
	end

	local upgradeCost = definition.UpgradeCosts[workerData.Level]
	if not upgradeCost then
		return {
			Success = false,
			UnlockedProductionTier = false,
		}
	end

	if not self.Economy:SpendCash(plr, upgradeCost) then
		return {
			Success = false,
			UnlockedProductionTier = false,
		}
	end

	-- Snapshot current production tier
	local previousLevel = workerData.Level
	local previousTier = getProductionTierId(definition, previousLevel)

	-- Upgrade
	workerData.Level += 1

	local newLevel = workerData.Level
	local newTier = getProductionTierId(definition, newLevel)

	local unlockedProductionTier = previousTier ~= newTier

	-- Runtime worker
	local runtimeWorker = self.Workers:GetWorker(workerData.Id)
	if runtimeWorker then
		runtimeWorker.Level = workerData.Level
	end

	-- Broadcast upgrade
	GameEvents.WorkerUpgraded:Fire(plr, workerData, previousLevel, newLevel)

	return {
		Success = true,
		UnlockedProductionTier = unlockedProductionTier,
	}
end

function WorkerUpgradeService.GetUpgradeState(
	self: WorkerUpgradeService,
	plr: Player,
	workerId: string
): WorkerDetailsTypes.UpgradeState?
	local workerData = self.Inventory:GetWorker(plr, workerId)
	if not workerData then
		return nil
	end

	local definition = WorkerConfig[workerData.WorkerType]
	if not definition then
		return nil
	end

	local cash = self.Economy:GetCash(plr)

	-- Max level
	if workerData.Level >= definition.MaxLevel then
		return {
			Cash = cash,

			MaxLevel = definition.MaxLevel,

			UpgradeCost = nil,
			CanUpgrade = false,

			BlockedReason = "MaxLevel",
		}
	end

	-- Cost
	local upgradeCost = definition.UpgradeCosts[workerData.Level]
	if not upgradeCost then
		return {
			Cash = cash,

			MaxLevel = definition.MaxLevel,

			UpgradeCost = nil,
			CanUpgrade = false,

			BlockedReason = "Unavailable",
		}
	end

	-- Affordability
	if cash < upgradeCost then
		return {
			Cash = cash,

			MaxLevel = definition.MaxLevel,

			UpgradeCost = upgradeCost,
			CanUpgrade = false,

			BlockedReason = "NotEnoughCash",
		}
	end

	return {
		Cash = cash,

		MaxLevel = definition.MaxLevel,

		UpgradeCost = upgradeCost,
		CanUpgrade = true,

		BlockedReason = nil,
	}
end

return WorkerUpgradeService
