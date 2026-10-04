--!strict
-- Server Class Types

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Types --
local WorkerTypes = require(ReplicatedStorage.Shared.Types.WorkerTypes)

-- Worker
export type Worker = {
	Id: string,
	WorkerType: string,
	OwnerUserId: number,
	Level: number,
	Temper: WorkerTypes.WorkerTemper,
	State: WorkerTypes.WorkerLocationState,
	FactoryId: string?,
	CarrierUserId: number?,
	Model: Model?,

	StartWorking: (self: any) -> (),
	StopWorking: (self: any) -> (),
	Update: (self: any, dt: number) -> (),
	Spawn: (self: any, spawnCFrame: CFrame) -> (),
	GetRootPart: (self: any) -> BasePart?,

	SetProductionCallback: (self: any, callback: ((string, number) -> ())?) -> (),
	SetCanProduceCallback: (self: any, callback: (({ [string]: number }) -> boolean)?) -> (),
	SetConsumeInputsCallback: (self: any, callback: (({ [string]: number }) -> boolean)?) -> (),
	ClearFactoryCallbacks: (self: any) -> (),

	GetOutputItem: (self: any) -> string?,
	GetRecipeId: (self: any) -> string?,
}

-- Factory
export type ProductionCallback = (worker: Worker, itemId: string, amount: number) -> ()

export type Factory = {
	Id: string,
	Model: Model,
	OwnerUserId: number,
	Inventory: { [string]: number },
	PendingCash: number,
	Spawns: { BasePart },
	Workers: { [number]: Worker? },
	SlotFolders: { Folder },
	SlotIds: { string },
	SlotIndexById: { [string]: number },
	CustomerSpawn: BasePart,
	CustomerCounter: BasePart,
	CustomerExit: BasePart,
	CustomerQueueSpots: { BasePart },
	ProductionCallback: ProductionCallback?,

	PlaceWorker: (self: any, worker: Worker) -> boolean,
	PlaceWorkerInSlot: (self: any, worker: Worker, slotIndex: number) -> boolean,
	DetachWorkerFromSlot: (self: any, slotIndex: number) -> Worker?,
	RemoveWorkerFromSlot: (self: any, slotIndex: number) -> Worker?,
	ConfigureStealPrompt: (self: any, worker: Worker, slotIndex: number) -> (),
	Collect: (self: any, plr: Player) -> boolean,
	TrySellItem: (self: any, itemId: string) -> boolean,
	LoadPendingCash: (self: any, amount: number) -> (),
	LoadInventory: (self: any, inventory: { [string]: number }) -> (),
	AddPendingCash: (self: any, amount: number) -> number,
	TakePendingCash: (self: any, amount: number) -> number,
	AddItem: (self: any, itemId: string, amount: number) -> (),
	RemoveItem: (self: any, itemId: string, amount: number) -> boolean,
	HasItem: (self: any, itemId: string, amount: number) -> boolean,
	HasItems: (self: any, items: { [string]: number }) -> boolean,
	RemoveItems: (self: any, items: { [string]: number }) -> boolean,
	GetAvailableSellableItems: (self: any) -> { string },
	GetSlotId: (self: any, slotIndex: number) -> string?,
	GetSlotIndexById: (self: any, slotId: string) -> number?,
	GetSlotStationRole: (self: any, slotIndex: number) -> string?,
	IsSlotOccupied: (self: any, slotIndex: number) -> boolean,
	GetSlotCount: (self: any) -> number,
	GetWorkerInSlot: (self: any, slotIndex: number) -> Worker?,
	SetProductionCallback: (self: any, callback: ProductionCallback) -> (),
}

-- Customer
export type Customer = {
	Id: string,
	CustomerType: string,
	Model: Model?,
	Humanoid: Humanoid?,
	DesiredItem: string?,
	HasPurchased: boolean,
	MaxWaitTime: number,
	TimeWaited: number,
	StatusGui: BillboardGui?,
	StatusLabel: TextLabel?,

	Destroy: (self: any) -> (),
	ChooseDesiredItem: (self: any) -> (),
	InitializePatience: (self: any) -> (),
	CreateStatusGui: (self: any) -> (),
	SetStatus: (self: any, text: string) -> (),
	Spawn: (self: any, spawnCFrame: CFrame) -> boolean,
	GoTo: (self: any, position: Vector3) -> boolean,
	MoveTo: (self: any, position: Vector3, reachDistance: number?, timeout: number?) -> boolean,
}

return {}
