--!strict
-- Server Service Types

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Server Types --
local ClassTypes = require(ServerScriptService.Types.ClassTypes)

-- Shared Types --
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local WorkerTypes = require(ReplicatedStorage.Shared.Types.WorkerTypes)
local WorkerShopTypes = require(ReplicatedStorage.Shared.Types.WorkerShopTypes)
local WorkerDetailsTypes = require(ReplicatedStorage.Shared.Types.WorkerDetailsTypes)
local WorkerUpgradeTypes = require(ReplicatedStorage.Shared.Types.WorkerUpgradeTypes)

-- Shared server domain types
export type ProductionSource = "Manual" | "Worker" | "Assembler"

-- Player Data Service
export type PlayerDataService = {
	IsProfileLoaded: (self: any, plr: Player) -> boolean,

	LoadProfile: (self: any, plr: Player) -> (),

	UnloadProfile: (self: any, plr: Player) -> (),

	GetProfile: (self: any, plr: Player) -> PlayerDataTypes.PlayerData?,

	GetProfileByUserId: (self: any, userId: number) -> PlayerDataTypes.PlayerData?,

	RequireProfile: (self: any, plr: Player) -> PlayerDataTypes.PlayerData,

	RequireProfileByUserId: (self: any, userId: number) -> PlayerDataTypes.PlayerData,

	SaveProfileByUserId: (self: any, userId: number, releaseSession: boolean) -> boolean,

	Start: (self: any) -> (),
}

-- Economy Service
export type EconomyService = {
	GetCash: (self: any, plr: Player) -> number,

	AddCash: (self: any, plr: Player, amount: number) -> number,

	SpendCash: (self: any, plr: Player, amount: number) -> boolean,
}

-- Worker Inventory Service
export type WorkerInventoryService = {
	GetInventoryByUserId: (self: any, userId: number) -> { WorkerTypes.OwnedWorkerData },

	GetInventory: (self: any, plr: Player) -> { WorkerTypes.OwnedWorkerData },

	AddWorker: (self: any, plr: Player, workerType: string) -> WorkerTypes.OwnedWorkerData,

	GetWorkerByUserId: (self: any, userId: number, workerId: string) -> WorkerTypes.OwnedWorkerData?,

	GetWorker: (self: any, plr: Player, workerId: string) -> WorkerTypes.OwnedWorkerData?,

	GetFirstUnplacedWorker: (self: any, plr: Player) -> WorkerTypes.OwnedWorkerData?,

	UpdateWorkerState: (
		self: any,
		ownerUserId: number,
		workerId: string,
		state: WorkerTypes.WorkerLocationState,
		factoryId: string?,
		slotIndex: number?,
		carrierUserId: number?
	) -> boolean,

	SetWorkerPlacedByUserId: (
		self: any,
		userId: number,
		workerId: string,
		factoryId: string,
		slotIndex: number
	) -> boolean,

	SetWorkerPlaced: (
		self: any,
		plr: Player,
		workerId: string,
		factoryId: string,
		slotIndex: number
	) -> boolean,

	SetWorkerStoredByUserId: (self: any, userId: number, workerId: string) -> boolean,

	SetWorkerStored: (self: any, plr: Player, workerId: string) -> boolean,

	SetWorkerCarriedByUserId: (
		self: any,
		userId: number,
		workerId: string,
		carrierUserId: number
	) -> boolean,

	HasStoredWorkers: (self: any, plr: Player) -> boolean,

	TransferWorkerOwnership: (
		self: any,
		fromUserId: number,
		toUserId: number,
		workerId: string
	) -> WorkerTypes.OwnedWorkerData?,

	GetClientInventory: (self: any, plr: Player) -> { WorkerTypes.ClientWorkerData },
}

-- Worker Service
export type WorkerService = {
	CreateWorker: (self: any, workerType: string, ownerUserId: number) -> ClassTypes.Worker,

	CreateWorkerFromOwnedData: (
		self: any,
		workerData: WorkerTypes.OwnedWorkerData,
		ownerUserId: number
	) -> ClassTypes.Worker,

	DestroyWorker: (self: any, workerId: string) -> (),

	DestroyWorkersForOwner: (self: any, ownerUserId: number, preserveCarried: boolean?) -> (),

	GetWorker: (self: any, workerId: string) -> ClassTypes.Worker?,

	Start: (self: any) -> (),
}

-- Progression Service
export type ProgressionService = {
	GetProgression: (self: any, plr: Player) -> PlayerDataTypes.PlayerProgression?,

	GetProgressionByUserId: (self: any, userId: number) -> PlayerDataTypes.PlayerProgression?,

	GetPartsSold: (self: any, plr: Player) -> number,

	CanPurchaseWorkers: (self: any, plr: Player) -> boolean,

	TryUnlockWorkerShop: (self: any, plr: Player) -> boolean,

	RecordPartSold: (self: any, userId: number, amount: number) -> (),

	HandleItemSold: (self: any, ownerUserId: number, itemId: string, cashEarned: number) -> (),

	ReconcilePlayer: (self: any, plr: Player, profile: PlayerDataTypes.PlayerData) -> (),

	Start: (self: any) -> (),
}

-- Production Service
export type ProductionService = {
	AddProductionOutput: (
		self: any,
		factory: ClassTypes.Factory,
		itemId: string,
		amount: number,
		source: ProductionSource,
		workerId: string?
	) -> boolean,

	IsProducing: (self: any, plr: Player) -> boolean,

	StartManualProduction: (
		self: any,
		plr: Player,
		factory: ClassTypes.Factory,
		slotIndex: number,
		stationId: string
	) -> boolean,

	CompleteManualProduction: (self: any, plr: Player) -> (),

	CancelManualProduction: (self: any, plr: Player) -> (),

	Start: (self: any) -> (),
}

-- Factory Service
export type FactoryService = {
	GetFactoryForPlayer: (self: any, plr: Player) -> ClassTypes.Factory?,

	GetFactoryByUserId: (self: any, userId: number) -> ClassTypes.Factory?,

	GetFactoryById: (self: any, factoryId: string) -> ClassTypes.Factory?,

	ClaimFactory: (self: any, plr: Player, factoryModel: Model) -> ClassTypes.Factory?,

	ReleaseFactory: (self: any, plr: Player) -> boolean,

	Start: (self: any) -> (),
}

-- Customer Service
export type CustomerService = {
	StartFactory: (self: any, factory: ClassTypes.Factory, customerType: string) -> (),

	StopFactory: (self: any, factoryId: string) -> (),
}

-- Theft Service
export type TheftService = {
	RegisterFactory: (self: any, factory: ClassTypes.Factory) -> (),

	UnregisterFactory: (self: any, factoryId: string) -> (),

	GetCarriedWorker: (self: any, plr: Player) -> ClassTypes.Worker?,

	TryStealFactoryCash: (self: any, thief: Player, factory: ClassTypes.Factory) -> number,

	TryGrabWorker: (self: any, thief: Player, factory: ClassTypes.Factory, slotIndex: number) -> boolean,

	ReturnCarriedWorker: (self: any, carrier: Player) -> boolean,

	ReturnWorkersOwnedByUserId: (self: any, ownerUserId: number) -> (),

	ClaimCarriedWorker: (self: any, carrier: Player, factory: ClassTypes.Factory) -> boolean,

	GetFactoryOwnedByUserId: (self: any, userId: number) -> ClassTypes.Factory?,

	Start: (self: any) -> (),
}

-- Worker Placement Service
export type WorkerPlacementService = {
	PlaceWorker: (
		self: any,
		plr: Player,
		factory: ClassTypes.Factory,
		workerId: string,
		slotIndex: number
	) -> boolean,

	RemoveWorker: (self: any, plr: Player, factory: ClassTypes.Factory, slotIndex: number) -> boolean,
}

-- Worker Upgrade Service
export type WorkerUpgradeService = {
	UpgradeWorker: (self: any, plr: Player, workerId: string) -> WorkerUpgradeTypes.UpgradeResult,

	GetUpgradeState: (self: any, plr: Player, workerId: string) -> WorkerDetailsTypes.UpgradeState?,
}

-- Worker Shop Service
export type WorkerShopService = {
	GetShopState: (self: any, plr: Player) -> WorkerShopTypes.ShopState,

	BuyWorker: (self: any, plr: Player, workerType: string) -> WorkerShopTypes.PurchaseResult,

	Start: (self: any) -> (),
}

-- Worker Remote Service
export type WorkerRemoteService = {
	Start: (self: any) -> (),
}

-- Stats Service
export type StatsService = {
	Start: (self: any) -> (),
}

-- Factory State Service
export type FactoryStateService = {
	HydrateFactory: (self: any, plr: Player) -> (),

	Start: (self: any) -> (),
}

return {}
