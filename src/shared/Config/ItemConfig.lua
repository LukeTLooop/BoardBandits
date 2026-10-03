--!strict
-- Item config

export type ItemDefinition = {
	DisplayName: string,
	Category: string,
	SellPrice: number,
}

local ItemConfig: {[string]: ItemDefinition} = {
	-- Bearings --
	BasicBearings = {
		DisplayName = "Basic Bearings",
		Category = "Part",
		SellPrice = 15,
	},
	SteelBearings = {
		DisplayName = "Steel Bearings",
		Category = "Part",
		SellPrice = 30,
	},
	PrecisionBearings = {
		DisplayName = "Precision Bearings",
		Category = "Part",
		SellPrice = 60,
	},
	
	-- Trucks --
	BasicTrucks = {
		DisplayName = "Basic Trucks",
		Category = "Part",
		SellPrice = 20,
	},
	MidTrucks = {
		DisplayName = "Mid Trucks",
		Category = "Part",
		SellPrice = 40,
	},
	GoodTrucks = {
		DisplayName = "Good Trucks",
		Category = "Part",
		SellPrice = 80,
	},

	-- Wheels --
	BasicWheels = {
		DisplayName = "Basic Wheels",
		Category = "Part",
		SellPrice = 15,
	},
	MidWheels = {
		DisplayName = "Mid Wheels",
		Category = "Part",
		SellPrice = 30,
	},
	GoodWheels = {
		DisplayName = "Good Wheels",
		Category = "Part",
		SellPrice = 60,
	},
	
	-- Decks --
	BasicDeck = {
		DisplayName = "Basic Deck",
		Category = "Part",
		SellPrice = 25,
	},
	MidDeck = {
		DisplayName = "Mid Deck",
		Category = "Part",
		SellPrice = 50,
	},
	GoodDeck = {
		DisplayName = "Good Deck",
		Category = "Part",
		SellPrice = 100,
	},
	
	-- Skateboards --
	BasicSkateboard = {
		DisplayName = "Basic Skateboard",
		Category = "Board",
		SellPrice = 100,
	},
	
	MidSkateboard = {
		DisplayName = "Mid Skateboard",
		Category = "Board",
		SellPrice = 200,
	},
	
	GoodSkateboard = {
		DisplayName = "Good Skateboard",
		Category = "Board",
		SellPrice = 400,
	},
}

return ItemConfig
