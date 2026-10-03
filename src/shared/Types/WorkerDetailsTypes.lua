--!strict
-- Worker Details Types

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Types --
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local sharedTypes = sharedFolder:WaitForChild("Types")

local WorkerTypes = require(sharedTypes:WaitForChild("WorkerTypes"))

-- Public --
export type UpgradeBlockedReason = "MaxLevel" | "NotEnoughCash" | "Unavailable"

export type UpgradeState = {
	Cash: number,

	MaxLevel: number,

	UpgradeCost: number?,
	CanUpgrade: boolean,

	BlockedReason: UpgradeBlockedReason?,
}

export type DetailsData = {
	Id: string,
	WorkerType: string,

	Level: number,
	Temper: WorkerTypes.WorkerTemper,

	Upgrade: UpgradeState,
}

return {}
