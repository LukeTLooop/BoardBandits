--!strict
-- Player Data Types

-- Servies --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Types --
local sharedTypes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types")

local WorkerTypes = require(sharedTypes:WaitForChild("WorkerTypes"))
local FactoryDataTypes = require(sharedTypes:WaitForChild("FactoryDataTypes"))

-- Factory
export type FactoryData = {
	FactoryId: string?,
	Upgrades: { [string]: boolean },
}

-- Stats
export type PlayerStats = {
	WorkersPurchased: number,
	WorkersStolen: number,
	WorkersLost: number,

	ItemsProduced: number,
	ItemsSold: number,
}

-- Progression
export type PlayerProgression = {
	PartsSold: number,

	WorkerShopUnlocked: boolean,
}

-- Player Data
export type PlayerData = {
	Version: number,

	Cash: number,

	Workers: { WorkerTypes.OwnedWorkerData },

	Factory: FactoryDataTypes.FactoryData,

	Stats: PlayerStats,

	Progression: PlayerProgression,
}

return {}
