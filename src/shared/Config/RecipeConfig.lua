--!strict
-- Recipe config

export type RecipeDefinition = {
	Inputs: {[string]: number},
	
	OutputItem: string,
	OutputAmount: number,
	
	ProductionInterval: number,
}

local RecipeConfig: {[string]: RecipeDefinition} = {
	BasicSkateboard = {
		Inputs = {
			BasicBearings = 1,
			BasicTrucks = 1,
			BasicWheels = 1,
			BasicDeck = 1,
		},
		
		OutputItem = "BasicSkateboard",
		OutputAmount = 1,
		
		ProductionInterval = 8,
	},
	
	MidSkateboard = {
		Inputs = {
			SteelBearings = 1,
			MidTrucks = 1,
			MidWheels = 1,
			MidDeck = 1,
		},

		OutputItem = "MidSkateboard",
		OutputAmount = 1,

		ProductionInterval = 8,
	},
	
	GoodSkateboard = {
		Inputs = {
			PrecisionBearings = 1,
			GoodTrucks = 1,
			GoodWheels = 1,
			GoodDeck = 1,
		},

		OutputItem = "GoodSkateboard",
		OutputAmount = 1,

		ProductionInterval = 8,
	},
}

return RecipeConfig
