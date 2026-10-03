--!strict
-- Worker config

export type OutputProgressionEntry = {
	RequiredLevel: number,
	Item: string,
}

export type RecipeProgressionEntry = {
	RequiredLevel: number,
	Recipe: string,
}

type BaseWorkerDefinition = {
	DisplayName: string,
	ModelName: string,
	Rarity: string,

	RoleName: string,
	MaxLevel: number,

	Price: number,
	UpgradeCosts: {number},
}

type ProducerSpecificDefinition = {
	WorkerType: "Producer",
	
	OutputProgression: {OutputProgressionEntry},
	
	ProductionInterval: number,
	OutputAmount: number,
}

type AssemblerSpecificDefinition = {
	WorkerType: "Assembler",
	
	RecipeProgression: {RecipeProgressionEntry},
}

export type ProducerDefinition = BaseWorkerDefinition & ProducerSpecificDefinition

export type AssemblerDefinition = BaseWorkerDefinition & AssemblerSpecificDefinition

export type WorkerDefinition = BaseWorkerDefinition & (ProducerSpecificDefinition | AssemblerSpecificDefinition)

local WorkerConfig: {[string]: WorkerDefinition} = {
	-- Bearing creatures
	Gloop = {
		DisplayName = "Gloop",
		ModelName = "Gloop",
		Rarity = "Common",
		
		RoleName = "Bearings",
		
		MaxLevel = 5,
		Price = 100,
		
		UpgradeCosts = {
			150, -- 1 -> 2
			250, -- 2 -> 3
			400, -- 3 -> 4
			650, -- 4 -> 5
		},
		
		WorkerType = "Producer",
		
		OutputProgression = {
			{
				RequiredLevel = 1,
				Item = "BasicBearings",
			},
			{
				RequiredLevel = 3,
				Item = "SteelBearings",
			},
			{
				RequiredLevel = 5,
				Item = "PrecisionBearings",
			},
		},
		
		ProductionInterval = 4,
		OutputAmount = 1,
	},
	
	-- Trucks creatures
	Bonk = {
		DisplayName = "Bonk",
		ModelName = "Bonk",
		Rarity = "Common",
		
		RoleName = "Trucks",
		
		MaxLevel = 5,
		Price = 100,

		UpgradeCosts = {
			150, -- 1 -> 2
			250, -- 2 -> 3
			400, -- 3 -> 4
			650, -- 4 -> 5
		},

		WorkerType = "Producer",

		OutputProgression = {
			{
				RequiredLevel = 1,
				Item = "BasicTrucks",
			},
			{
				RequiredLevel = 3,
				Item = "MidTrucks",
			},
			{
				RequiredLevel = 5,
				Item = "GoodTrucks",
			},
		},

		ProductionInterval = 4,
		OutputAmount = 1,
	},
	
	-- Wheels creatures
	Squish = {
		DisplayName = "Squish",
		ModelName = "Squish",
		Rarity = "Common",
		
		RoleName = "Wheels",
		
		MaxLevel = 5,
		Price = 100,

		UpgradeCosts = {
			150, -- 1 -> 2
			250, -- 2 -> 3
			400, -- 3 -> 4
			650, -- 4 -> 5
		},

		WorkerType = "Producer",

		OutputProgression = {
			{
				RequiredLevel = 1,
				Item = "BasicWheels",
			},
			{
				RequiredLevel = 3,
				Item = "MidWheels",
			},
			{
				RequiredLevel = 5,
				Item = "GoodWheels",
			},
		},

		ProductionInterval = 4,
		OutputAmount = 1,
	},
	
	-- Deck creatures
	Plank = {
		DisplayName = "Plank",
		ModelName = "Plank",
		Rarity = "Common",
		
		RoleName = "Decks",
		
		MaxLevel = 5,
		Price = 100,

		UpgradeCosts = {
			150, -- 1 -> 2
			250, -- 2 -> 3
			400, -- 3 -> 4
			650, -- 4 -> 5
		},

		WorkerType = "Producer",

		OutputProgression = {
			{
				RequiredLevel = 1,
				Item = "BasicDeck",
			},
			{
				RequiredLevel = 3,
				Item = "MidDeck",
			},
			{
				RequiredLevel = 5,
				Item = "GoodDeck",
			},
		},

		ProductionInterval = 4,
		OutputAmount = 1,
	},
	
	-- Assembly creatures
	Patch = {
		DisplayName = "Patch",
		ModelName = "Patch",
		Rarity = "Common",
		
		RoleName = "Assembler",
		
		MaxLevel = 5,
		Price = 250,

		UpgradeCosts = {
			300, -- 1 -> 2
			450, -- 2 -> 3
			600, -- 3 -> 4
			900, -- 4 -> 5
		},

		WorkerType = "Assembler",

		RecipeProgression = {
			{
				RequiredLevel = 1,
				Recipe = "BasicSkateboard",
			},
			{
				RequiredLevel = 3,
				Recipe = "MidSkateboard",
			},
			{
				RequiredLevel = 5,
				Recipe = "GoodSkateboard",
			},
		},
	},
	
}

return WorkerConfig
