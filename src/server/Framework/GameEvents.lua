--!strict
-- Central server-side gameplay event hub

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Utility.Signal)

local WorkerTypes = require(ReplicatedStorage.Shared.Types.WorkerTypes)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

-- Types --
type GameEventsType = {
	-- Player lifecycle
	ProfileLoaded: Signal.Signal<Player, PlayerDataTypes.PlayerData>,

	ProfileRemoving: Signal.Signal<Player, PlayerDataTypes.PlayerData>,

	-- Factory lifecycle
	FactoryClaimed: Signal.Signal<Player, string>,

	FactoryReleased: Signal.Signal<number, string>,

	FactoryCashChanged: Signal.Signal<number, number>,

	FactoryWorkerAssigned: Signal.Signal<number, string, string>,

	FactoryWorkerUnassigned: Signal.Signal<number, string, string>,

	FactoryCashStolen: Signal.Signal<Player, number, number>,

	-- Worker lifecycle
	WorkerPurchased: Signal.Signal<Player, WorkerTypes.OwnedWorkerData>,

	WorkerPlaced: Signal.Signal<Player, WorkerTypes.OwnedWorkerData, string, number>,

	WorkerRemoved: Signal.Signal<Player, WorkerTypes.OwnedWorkerData>,

	WorkerUpgraded: Signal.Signal<Player, WorkerTypes.OwnedWorkerData, number, number>,

	-- Theft
	WorkerGrabbed: Signal.Signal<Player, number, WorkerTypes.OwnedWorkerData>,

	WorkerStolen: Signal.Signal<Player, number, WorkerTypes.OwnedWorkerData>,

	WorkerRecovered: Signal.Signal<number, WorkerTypes.OwnedWorkerData>,

	-- Production
	ItemProduced: Signal.Signal<number, string, string, number>,

	ItemSold: Signal.Signal<number, string, number>,

	-- Progression
	ProgressionMilestoneUnlocked: Signal.Signal<Player, string>,
}

local GameEvents: GameEventsType = {
	-- Player lifecycle
	ProfileLoaded = Signal.new(),
	ProfileRemoving = Signal.new(),

	-- Factory lifecycle
	FactoryClaimed = Signal.new(),
	FactoryReleased = Signal.new(),

	FactoryCashChanged = Signal.new(),
	FactoryWorkerAssigned = Signal.new(),
	FactoryWorkerUnassigned = Signal.new(),

	FactoryCashStolen = Signal.new(),

	-- Worker lifecycle
	WorkerPurchased = Signal.new(),
	WorkerPlaced = Signal.new(),
	WorkerRemoved = Signal.new(),
	WorkerUpgraded = Signal.new(),

	-- Theft
	WorkerGrabbed = Signal.new(),
	WorkerStolen = Signal.new(),
	WorkerRecovered = Signal.new(),

	-- Production
	ItemProduced = Signal.new(),
	ItemSold = Signal.new(),

	-- Progression
	ProgressionMilestoneUnlocked = Signal.new(),
}

return GameEvents
