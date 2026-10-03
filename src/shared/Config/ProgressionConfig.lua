--!strict
-- Progression Config

export type MilestoneDefinition = {
	DisplayName: string,
	RequiredPartsSold: number,
}

local ProgressionConfig = {}

ProgressionConfig.WorkerShop = {
	DisplayName = "Worker Shop",
	RequiredPartsSold = 5,
} :: MilestoneDefinition

return ProgressionConfig
