--!strict
-- HUD Service

-- Services --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local FactoryService = require(ServerScriptService.Services.FactoryService)

-- Config --
local WorkerConfig = require(ReplicatedStorage.Shared.Config.WorkerConfig)
local RecipeConfig = require(ReplicatedStorage.Shared.Config.RecipeConfig)

-- Types --
local HUDTypes = require(ReplicatedStorage.Shared.Types.HUDTypes)

-- Framework --
local GameEvents = require(ServerScriptService.Framework.GameEvents)

-- Service --
local HUDService = {}
HUDService.__index = HUDService

type HUDServiceData = {
	PlayerData: PlayerDataService.PlayerDataService,
	Factories: FactoryService.FactoryService,

	PendingPushes: {
		[number]: boolean,
	},

	RequestState: RemoteFunction,
	StateUpdated: RemoteEvent,

	Started: boolean,
}

export type HUDService = typeof(setmetatable({} :: HUDServiceData, HUDService))

-- Constructor --
function HUDService.new(
	playerData: PlayerDataService.PlayerDataService,
	factories: FactoryService.FactoryService
): HUDService
	local remotes = ReplicatedStorage.Remotes.HUD

	local requestState = remotes.RequestState
	local stateUpdated = remotes.StateUpdated

	assert(requestState:IsA("RemoteFunction"))
	assert(stateUpdated:IsA("RemoteEvent"))

	local data: HUDServiceData = {
		PlayerData = playerData,
		Factories = factories,

		PendingPushes = {},

		RequestState = requestState,
		StateUpdated = stateUpdated,

		Started = false,
	}

	return setmetatable(data, HUDService)
end

-- Get HUD State
function HUDService.GetState(self: HUDService, plr: Player): HUDTypes.HUDState?
	local profile = self.PlayerData:GetProfile(plr)
	if not profile then
		return nil
	end

	local factory = self.Factories:GetFactoryForPlayer(plr)
	local workerSummaries: { HUDTypes.WorkerSummary } = {}
	local placedWorkers = 0

	if factory then
		for _, worker in factory.Workers do
			if not worker then
				continue
			end

			local definition = WorkerConfig[worker.WorkerType]
			if not definition then
				continue
			end

			placedWorkers += 1

			local outputItem: string? = nil
			local outputPerMinute: number? = nil

			if definition.WorkerType == "Producer" then
				local producerDefinition = definition :: WorkerConfig.ProducerDefinition

				outputItem = worker:GetOutputItem()
				outputPerMinute = (producerDefinition.OutputAmount / producerDefinition.ProductionInterval) * 60
			else
				local recipeId = worker:GetRecipeId()
				local recipe = if recipeId then RecipeConfig[recipeId] else nil
				if recipe then
					outputItem = recipe.OutputItem
					outputPerMinute = (recipe.OutputAmount / recipe.ProductionInterval) * 60
				end
			end

			table.insert(workerSummaries, {
				Id = worker.Id,
				WorkerType = worker.WorkerType,

				RoleName = definition.RoleName,
				Level = worker.Level,

				OutputItem = outputItem,
				OutputPerMinute = outputPerMinute,
			})
		end
	end

	return {
		PlayerCash = profile.Cash,
		HasFactory = factory ~= nil,
		FactoryId = if factory then factory.Id else nil,
		FactoryCash = if factory then factory.PendingCash else 0,
		FactoryInventory = if factory then table.clone(factory.Inventory) else {},
		TotalWorkers = #profile.Workers,
		PlacedWorkers = placedWorkers,
		Workers = workerSummaries,
		PartsSold = profile.Progression.PartsSold,
		WorkerShopUnlocked = profile.Progression.WorkerShopUnlocked,
	}
end

-- Push HUD State
function HUDService.PushState(self: HUDService, plr: Player): ()
	if plr.Parent ~= Players then
		return
	end

	local state = self:GetState(plr)
	if not state then
		return
	end

	self.StateUpdated:FireClient(plr, state)
end

-- Queue State Push
function HUDService.QueuePush(self: HUDService, plr: Player): ()
	if self.PendingPushes[plr.UserId] then
		return
	end

	self.PendingPushes[plr.UserId] = true

	task.defer(function()
		self.PendingPushes[plr.UserId] = nil
		self:PushState(plr)
	end)
end

-- Start
function HUDService.Start(self: HUDService): ()
	if self.Started then
		return
	end

	self.Started = true

	self.RequestState.OnServerInvoke = function(plr: Player)
		return self:GetState(plr)
	end

	local function pushPlayer(plr: Player)
		self:QueuePush(plr)
	end

	local function pushUserId(userId: number)
		local plr = Players:GetPlayerByUserId(userId)
		if plr then
			self:QueuePush(plr)
		end
	end

	GameEvents.ProfileLoaded:Connect(function(plr: Player)
		pushPlayer(plr)
	end)

	GameEvents.FactoryClaimed:Connect(function(plr: Player)
		pushPlayer(plr)
	end)

	GameEvents.PlayerCashChanged:Connect(function(plr: Player)
		pushPlayer(plr)
	end)

	GameEvents.FactoryCashChanged:Connect(function(ownerUserId: number)
		pushUserId(ownerUserId)
	end)

	GameEvents.FactoryInventoryChanged:Connect(function(ownerUserId: number)
		pushUserId(ownerUserId)
	end)

	GameEvents.FactoryWorkerAssigned:Connect(function(ownerUserId: number)
		pushUserId(ownerUserId)
	end)

	GameEvents.FactoryWorkerUnassigned:Connect(function(ownerUserId: number)
		pushUserId(ownerUserId)
	end)

	GameEvents.WorkerUpgraded:Connect(function(plr: Player)
		pushPlayer(plr)
	end)

	GameEvents.WorkerPurchased:Connect(function(plr: Player)
		pushPlayer(plr)
	end)

	GameEvents.WorkerStolen:Connect(function(thief: Player, originalOwnerUserId: number)
		pushPlayer(thief)
		pushUserId(originalOwnerUserId)
	end)

	GameEvents.WorkerRecovered:Connect(function(ownerUserId: number)
		pushUserId(ownerUserId)
	end)

	GameEvents.ProgressionMilestoneUnlocked:Connect(function(plr: Player)
		pushPlayer(plr)
	end)
end

return HUDService
