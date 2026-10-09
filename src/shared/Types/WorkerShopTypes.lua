--!strict
-- Worker Shop Types

export type ShopState = {
	Cash: number,

	HasClaimedFactory: boolean,

	WorkerShopUnlocked: boolean,

	PartsSold: number,
	RequiredPartsSold: number,

	AvailableWorkers: { string },
}

export type PurchaseResult = {
	Success: boolean,

	Message: string,

	Cash: number,
}

return {}
