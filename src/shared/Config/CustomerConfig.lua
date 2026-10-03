--!strict
-- Customer config

export type CustomerDefinition = {
	DisplayName: string,
	ModelName: string,
	
	DesiredItems: {string},
	
	MinWaitTime: number,
	MaxWaitTime: number,
	
	RetryInterval: number,
}

local CustomerConfig: {[string]: CustomerDefinition} = {
	BasicCustomer = {
		DisplayName = "Skater",
		ModelName = "BasicCustomer",
		
		DesiredItems = {
			"BasicSkateboard",
		},
		
		MinWaitTime = 5,
		MaxWaitTime = 8,
		
		RetryInterval = 1,
	},
}

return CustomerConfig
