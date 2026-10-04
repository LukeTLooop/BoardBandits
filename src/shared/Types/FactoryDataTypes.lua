--!strict
-- Factory Data Types

-- Types --

-- Future placement state
export type PlacementMetadataValue = string | number | boolean

export type FactoryPlacementData = {
	-- Permanent Id for placed object
	Id: string,

	PlacementType: string,

	-- Config/asset definition Id
	AssetId: string,

	-- Serialized CFrame
	Transform: { number },

	-- Placement metadata
	Metadata: {
		[string]: PlacementMetadataValue,
	},
}

-- Factory persistence
export type FactoryData = {
	Version: number,

	-- Factory cash
	PendingCash: number,

	-- Factory inventory
	Inventory: {
		[string]: number,
	},

	-- PersistentSlotId -> WorkerId
	WorkerAssignments: {
		[string]: string,
	},

	-- PersistentPlacementId -> Placement
	Placements: {
		[string]: FactoryPlacementData,
	},
}

return {}
