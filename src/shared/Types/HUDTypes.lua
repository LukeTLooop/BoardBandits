--!strict
-- HUD Types

-- Types
export type WorkerSummary = {
	Id: string,
	WorkerType: string,

	RoleName: string,
	Level: number,

	OutputItem: string?,
	OutputPerMinute: number?,
}

export type HUDState = {
	PlayerCash: number,

	HasFactory: boolean,
	FactoryId: string?,

	FactoryCash: number,
	FactoryInventory: {
		[string]: number,
	},

	TotalWorkers: number,
	PlacedWorkers: number,

	Workers: { WorkerSummary },

	PartsSold: number,
	WorkerShopUnlocked: boolean,
}

return {}
