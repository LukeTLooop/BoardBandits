--!strict
-- Worker Shop Types

export type ShopState = {
    Cash: number,

    HasClaimedFactory: boolean,

    WorkerShopUnlocked: boolean,

    PartsSold: number,
    RequiredPartsSold: number,
}

export type PurchaseResult = {
    Success: boolean,

    Message: string,

    Cash: number,
}

return {}
