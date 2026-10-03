--!strict
-- Worker Filter Config

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Types --
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local sharedTypes = sharedFolder:WaitForChild("Types")

local WorkerTypes = require(sharedTypes:WaitForChild("WorkerTypes"))

export type FilterOption = {
	Value: string,
	DisplayName: string,
}

export type FilterDefinition = {
	Id: string,
	DisplayName: string,

	Options: { FilterOption },

	GetValue: (WorkerTypes.ClientWorkerData) -> string?,
}

-- Definitions
local Definitions: { [string]: FilterDefinition } = {
	Temper = {
		Id = "Temper",
		DisplayName = "Temper",

		Options = {
			{
				Value = "Mild",
				DisplayName = "Mild",
			},

			{
				Value = "Normal",
				DisplayName = "Normal",
			},

			{
				Value = "Feisty",
				DisplayName = "Feisty",
			},

			{
				Value = "Wild",
				DisplayName = "Wild",
			},
		},

		GetValue = function(worker: WorkerTypes.ClientWorkerData): string?
			return worker.Temper
		end,
	},
}

-- Public --
return {
	Order = {
		"Temper",
	},

	Definitions = Definitions,
}
