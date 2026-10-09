--!strict
-- Progression Service

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Modules --
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local WorkerConfig = require(ReplicatedStorage.Shared.Config.WorkerConfig)

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local GameEvents = require(ServerScriptService.Framework.GameEvents)

-- Service --
local ProgressionService = {}
ProgressionService.__index = ProgressionService

-- Types --
type ProgressionServiceData = {
	PlayerData: PlayerDataService.PlayerDataService,

	Started: boolean,
}

export type ProgressionService = typeof(setmetatable({} :: ProgressionServiceData, ProgressionService))

-- Constructor --
function ProgressionService.new(playerData: PlayerDataService.PlayerDataService): ProgressionService
	local data: ProgressionServiceData = {
		PlayerData = playerData,

		Started = false,
	}

	return setmetatable(data, ProgressionService)
end

-- Get Progression --
function ProgressionService.GetProgression(self: ProgressionService, plr: Player): PlayerDataTypes.PlayerProgression?
	local profile = self.PlayerData:GetProfile(plr)
	if not profile then
		return nil
	end

	return profile.Progression
end

-- Get Progression by UserId --
function ProgressionService.GetProgressionByUserId(
	self: ProgressionService,
	userId: number
): PlayerDataTypes.PlayerProgression?
	local profile = self.PlayerData:GetProfileByUserId(userId)
	if not profile then
		return nil
	end

	return profile.Progression
end

-- Parts Sold --
function ProgressionService.GetPartsSold(self: ProgressionService, plr: Player): number
	local progression = self:GetProgression(plr)
	if not progression then
		return 0
	end

	return progression.PartsSold
end

-- Worker Shop Access --
function ProgressionService.CanPurchaseWorkers(self: ProgressionService, plr: Player): boolean
	local progression = self:GetProgression(plr)
	if not progression then
		return false
	end

	return progression.WorkerShopUnlocked
end

function ProgressionService.CanPurchaseWorkersByUserId(self: ProgressionService, userId: number): boolean
	local progression = self:GetProgressionByUserId(userId)
	if not progression then
		return false
	end

	return progression.WorkerShopUnlocked
end

function ProgressionService.IsWorkerUnlocked(self: ProgressionService, plr: Player, workerType: string): boolean
	local progression = self:GetProgression(plr)
	if not progression then
		return false
	end

	if not progression.WorkerShopUnlocked then
		return false
	end

	local definition = WorkerConfig[workerType]
	if not definition then
		return false
	end

	return progression.PartsSold >= definition.RequiredPartsSold
end

function ProgressionService.GetUnlockedWorkerTypes(self: ProgressionService, plr: Player): { string }
	local progression = self:GetProgression(plr)
	if not progression or not progression.WorkerShopUnlocked then
		return {}
	end

	local unlockedWorkers: { string } = {}
	for workerType, definition in WorkerConfig do
		if progression.PartsSold < definition.RequiredPartsSold then
			continue
		end

		table.insert(unlockedWorkers, workerType)
	end

	table.sort(unlockedWorkers, function(a: string, b: string): boolean
		return WorkerConfig[a].ShopOrder < WorkerConfig[b].ShopOrder
	end)

	return unlockedWorkers
end

-- Try Worker Shop Unlock --
function ProgressionService.TryUnlockWorkerShop(self: ProgressionService, plr: Player): boolean
	local progression = self:GetProgression(plr)
	if not progression then
		return false
	end

	-- Already unlocked
	if progression.WorkerShopUnlocked then
		return false
	end

	-- Requirements met?
	local requiredPartsSold = ProgressionConfig.WorkerShop.RequiredPartsSold
	if progression.PartsSold < requiredPartsSold then
		return false
	end

	-- Unlock
	progression.WorkerShopUnlocked = true

	print("[PROGRESSION]", plr.Name, "unlocked WorkerShop")

	-- Broadcast unlock
	GameEvents.ProgressionMilestoneUnlocked:Fire(plr, "WorkerShop")

	return true
end

-- Record Sold Part --
function ProgressionService.RecordPartSold(self: ProgressionService, userId: number, amount: number): ()
	if amount <= 0 then
		return
	end

	local profile = self.PlayerData:GetProfileByUserId(userId)
	if not profile then
		return
	end

	local previousPartsSold = profile.Progression.PartsSold
	local newPartsSold = previousPartsSold + amount
	profile.Progression.PartsSold = newPartsSold

	-- Player may have left between sale and event
	local plr = Players:GetPlayerByUserId(userId)
	if not plr then
		return
	end

	-- Worker depot unlock
	self:TryUnlockWorkerShop(plr)

	-- Worker unlocks
	for workerType, definition in WorkerConfig do
		local required = definition.RequiredPartsSold
		local crossedThreshold = previousPartsSold < required and newPartsSold >= required
		if not crossedThreshold then
			continue
		end

		-- Broadcast worker unlocked
		GameEvents.WorkerUnlocked:Fire(plr, workerType)
	end
end

-- Handle Sold Item --
function ProgressionService.HandleItemSold(
	self: ProgressionService,
	ownerUserId: number,
	itemId: string,
	cashEarned: number
): ()
	local definition = ItemConfig[itemId]
	if not definition then
		warn("[PROGRESSION] Unknown sold item:", itemId)

		return
	end

	-- Boards do not count toward worker shop requirement
	if definition.Category ~= "Part" then
		return
	end

	self:RecordPartSold(ownerUserId, 1)
end

-- Reconcile Loaded Progression --
function ProgressionService.ReconcilePlayer(
	self: ProgressionService,
	plr: Player,
	profile: PlayerDataTypes.PlayerData
): ()
	local progression = profile.Progression

	-- Preserve existing unlock
	if progression.WorkerShopUnlocked then
		return
	end

	-- Handles players who hit threshold before update/migration
	if progression.PartsSold >= ProgressionConfig.WorkerShop.RequiredPartsSold then
		self:TryUnlockWorkerShop(plr)
	end
end

-- Start --
function ProgressionService.Start(self: ProgressionService): ()
	if self.Started then
		return
	end
	self.Started = true

	-- Profile loaded
	GameEvents.ProfileLoaded:Connect(function(plr: Player, profile: PlayerDataTypes.PlayerData)
		self:ReconcilePlayer(plr, profile)
	end)

	-- Item sold
	GameEvents.ItemSold:Connect(function(ownerUserId: number, itemId: string, cashEarned: number)
		self:HandleItemSold(ownerUserId, itemId, cashEarned)
	end)
end

return ProgressionService
