--!strict
-- Temper config

export type TemperDefinition = {
	RollWeight: number,
	
	GrabHoldDuration: number,
	CarrierSpeedMultiplier: number,
	
	AlarmVolume: number,
	StruggleStrength: number,
}

local TemperConfig: {[string]: TemperDefinition} = {
	Mild = {
		RollWeight = 25,

		GrabHoldDuration = 0.75,
		CarrierSpeedMultiplier = 1.25,
		
		AlarmVolume = 0,
		StruggleStrength = 0,
	},
	
	Normal = {
		RollWeight = 45,

		GrabHoldDuration = 1,
		CarrierSpeedMultiplier = 1,
		
		AlarmVolume = 0.4,
		StruggleStrength = 0.25,
	},
	
	Feisty = {
		RollWeight = 25,

		GrabHoldDuration = 1.5,
		CarrierSpeedMultiplier = 0.75,
		
		AlarmVolume = 0.75,
		StruggleStrength = 0.65,
	},
	
	Wild = {
		RollWeight = 5,

		GrabHoldDuration = 2,
		CarrierSpeedMultiplier = 0.6,
		
		AlarmVolume = 1,
		StruggleStrength = 1,
	},
}

return TemperConfig
