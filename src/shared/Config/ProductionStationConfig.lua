--!strict
-- Production Station Config

export type StationDefinition = {
	DisplayName: string,
	
	OutputItem: string,
	OutputAmount: number,
	
	ProductionTime: number,
}

local ProductionStationConfig: {[string]: StationDefinition} = {
	Bearings = {
		DisplayName = "Bearing Station",
		
		OutputItem = "BasicBearings",
		OutputAmount = 1,

		ProductionTime = 3,
	},
	Trucks = {
		DisplayName = "Trucks Station",

		OutputItem = "BasicTrucks",
		OutputAmount = 1,
		
		ProductionTime = 4,
	},
	Wheels = {
		DisplayName = "Wheels Station",

		OutputItem = "BasicWheels",
		OutputAmount = 1,
		
		ProductionTime = 3,
	},
	Decks = {
		DisplayName = "Deck Station",

		OutputItem = "BasicDeck",
		OutputAmount = 1,
		
		ProductionTime = 5,
	},
}

return ProductionStationConfig
