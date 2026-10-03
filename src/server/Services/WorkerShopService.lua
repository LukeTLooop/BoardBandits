--!strict
-- Worker Shop service

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EconomyService = require(ServerScriptService.Services.EconomyService)
local WorkerInventoryService = require(ServerScriptService.Services.WorkerInventoryService)
local ProgressionService = require(ServerScriptService.Services.ProgressionService)
local FactoryService = require(ServerScriptService.Services.FactoryService)

-- Config --
local WorkerConfig = require(ReplicatedStorage.Shared.Config.WorkerConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)

-- Types --
local WorkerTypes = require(ReplicatedStorage.Shared.Types.WorkerTypes)
local WorkerShopTypes = require(ReplicatedStorage.Shared.Types.WorkerShopTypes)

-- Framework --
local GameEvents = require(ServerScriptService.Framework.GameEvents)

-- Remotes --
local openWorkerShop = ReplicatedStorage.Remotes.Workers.OpenWorkerShop
assert(openWorkerShop:IsA("RemoteEvent"), "OpenWorkerShop must be a RemoteEvent!")

-- Service --
local WorkerShopService = {}
WorkerShopService.__index = WorkerShopService

-- Types --
type WorkerShopServiceData = {
	Economy: EconomyService.EconomyService,
	Inventory: WorkerInventoryService.WorkerInventoryService,
	Progression: ProgressionService.ProgressionService,
	Factories: FactoryService.FactoryService,

	OpenWorkerShop: RemoteEvent,

	Started: boolean,
}

export type WorkerShopService = typeof(setmetatable({} :: WorkerShopServiceData, WorkerShopService))

-- Constructor --
function WorkerShopService.new(
	economy: EconomyService.EconomyService,
	inventory: WorkerInventoryService.WorkerInventoryService,
	progression: ProgressionService.ProgressionService,
	factories: FactoryService.FactoryService
): WorkerShopService
	local data: WorkerShopServiceData = {
		Economy = economy,
		Inventory = inventory,
		Progression = progression,
		Factories = factories,

		OpenWorkerShop = openWorkerShop,

		Started = false,
	}
	
	return setmetatable(data, WorkerShopService)
end

-- State --
function WorkerShopService.GetShopState(
	self: WorkerShopService,
	plr: Player
): WorkerShopTypes.ShopState
	local hasFactory = self.Factories:GetFactoryForPlayer(plr) ~= nil
	local partsSold = self.Progression:GetPartsSold(plr)
	local unlocked = self.Progression:CanPurchaseWorkers(plr)

	return {
		Cash = self.Economy:GetCash(plr),
		HasClaimedFactory = hasFactory,
		WorkerShopUnlocked = unlocked,
		PartsSold = partsSold,
		RequiredPartsSold = ProgressionConfig.WorkerShop.RequiredPartsSold,
	}
end

-- Buy Worker --
function WorkerShopService.BuyWorker(
	self: WorkerShopService,
	plr: Player,
	workerType: string
): WorkerShopTypes.PurchaseResult
	-- Factory required
	local factory = self.Factories:GetFactoryForPlayer(plr)
	if not factory then
		return {
			Success = false,
			Message = "Claim a factory first.",
			Cash = self.Economy:GetCash(plr),
		}
	end

	-- Progression required
	if not self.Progression:CanPurchaseWorkers(plr) then
		local partsSold = self.Progression:GetPartsSold(plr)
		local required = ProgressionConfig.WorkerShop.RequiredPartsSold
		local remaining = math.max(
			required - partsSold,
			0
		)

		return {
			Success = false,
			Message = `Sell {remaining} more parts to unlock workers.`,
			Cash = self.Economy:GetCash(plr),
		}
	end

	-- Worker validation
	local definition = WorkerConfig[workerType]
	if not definition then
		return {
			Success = false,
			Message = "Invalid worker.",
			Cash = self.Economy:GetCash(plr),
		}
	end

	-- Payment
	if not self.Economy:SpendCash(plr, definition.Price) then
		return {
			Success = false,
			Message = "Not enough cash.",
			Cash = self.Economy:GetCash(plr),
		}
	end

	-- Add worker
	local workerData = self.Inventory:AddWorker(
		plr,
		workerType
	)

	if not workerData then
		-- Roll back payment if inventory creation fails
		self.Economy:AddCash(
			plr,
			definition.Price
		)

		return {
			Success = false,
			Message = "Could not create worker.",
			Cash = self.Economy:GetCash(plr),
		}
	end

	-- Broadcast worker purchased
	GameEvents.WorkerPurchased:Fire(
		plr,
		workerData
	)

	return {
		Success = true,
		Message = `Purchased {definition.DisplayName}!`,
		Cash = self.Economy:GetCash(plr),
	}
end

-- Setup World Shop --
function WorkerShopService.SetupWorldShop(
	self: WorkerShopService
): ()
	local shop = workspace:WaitForChild("WorkerShop")
	assert(
		shop:IsA("Model"),
		"workspace.WorkerShop must be a Model!"
	)

	local interactionPart = shop:WaitForChild("InteractionPart")
	assert(
		interactionPart:IsA("BasePart"),
		"WorkerShop.InteractionPart must be a BasePart!"
	)

	-- Prompt
	local existing = interactionPart:FindFirstChild("WorkerShopPrompt")
	local prompt: ProximityPrompt

	if existing and existing:IsA("ProximityPrompt") then
		prompt = existing
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = interactionPart
	end

	prompt.ActionText = "Browse Workers"
	prompt.ObjectText = "Worker Depot"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = false

	-- Open UI
	prompt.Triggered:Connect(function(
		plr: Player
	)
		self.OpenWorkerShop:FireClient(
			plr
		)
	end)
end

-- Start --
function WorkerShopService.Start(
	self: WorkerShopService
): ()
	if self.Started then return end
	self.Started = true

	self:SetupWorldShop()
end

return WorkerShopService
