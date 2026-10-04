--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Services --
local EconomyService = require(ServerScriptService.Services.EconomyService)
local WorkerService = require(ServerScriptService.Services.WorkerService)
local WorkerInventoryService = require(ServerScriptService.Services.WorkerInventoryService)
local WorkerShopService = require(ServerScriptService.Services.WorkerShopService)
local WorkerPlacementService = require(ServerScriptService.Services.WorkerPlacementService)
local CustomerService = require(ServerScriptService.Services.CustomerService)
local WorkerUpgradeService = require(ServerScriptService.Services.WorkerUpgradeService)
local TheftService = require(ServerScriptService.Services.TheftService)
local FactoryService = require(ServerScriptService.Services.FactoryService)
local WorkerRemoteService = require(ServerScriptService.Services.WorkerRemoteService)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local StatsService = require(ServerScriptService.Services.StatsService)
local ProgressionService = require(ServerScriptService.Services.ProgressionService)
local ProductionService = require(ServerScriptService.Services.ProductionService)
local FactoryStateService = require(ServerScriptService.Services.FactoryStateService)

-- Construct --
local playerDataService: PlayerDataService.PlayerDataService = PlayerDataService.new()
local economyService: EconomyService.EconomyService = EconomyService.new(playerDataService)
local workerService: WorkerService.WorkerService = WorkerService.new()
local workerInventoryService: WorkerInventoryService.WorkerInventoryService =
	WorkerInventoryService.new(playerDataService)
local progressionService: ProgressionService.ProgressionService = ProgressionService.new(playerDataService)
local productionService: ProductionService.ProductionService = ProductionService.new()
local workerPlacementService: WorkerPlacementService.WorkerPlacementService =
	WorkerPlacementService.new(workerInventoryService, workerService)
local customerService: CustomerService.CustomerService = CustomerService.new()
local workerUpgradeService: WorkerUpgradeService.WorkerUpgradeService =
	WorkerUpgradeService.new(economyService, workerInventoryService, workerService)
local theftService: TheftService.TheftService = TheftService.new(workerInventoryService, economyService)
local factoryService: FactoryService.FactoryService = FactoryService.new(
	economyService,
	customerService,
	theftService,
	workerInventoryService,
	workerService,
	progressionService,
	productionService
)
local workerShopService: WorkerShopService.WorkerShopService =
	WorkerShopService.new(economyService, workerInventoryService, progressionService, factoryService)
local workerRemoteService: WorkerRemoteService.WorkerRemoteService = WorkerRemoteService.new(
	factoryService,
	workerInventoryService,
	workerPlacementService,
	workerUpgradeService,
	workerShopService
)
local statsService: StatsService.StatsService = StatsService.new(playerDataService)
local factoryStateService: FactoryStateService.FactoryStateService =
	FactoryStateService.new(playerDataService, factoryService, workerInventoryService, workerService)

-- Listener Services --
statsService:Start()
progressionService:Start()

-- Gameplay Services --
productionService:Start()
workerService:Start()
factoryStateService:Start()
theftService:Start()
workerShopService:Start()
workerRemoteService:Start()
factoryService:Start()

-- Start data saving last --
playerDataService:Start()

print("Server ready!")
