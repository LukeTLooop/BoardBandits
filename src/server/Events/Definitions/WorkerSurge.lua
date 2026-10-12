--!strict
-- Worker Surge Event: increases automated worker production rate.

-- Types --
local EventTypes = require(script.Parent.Parent.EventTypes)

-- Event --
local WorkerSurge: EventTypes.EventDefinition = {
	Id = "WorkerSurge",
	Duration = 300,
	Priority = 30,

	OnStart = function(context)
		context:SetModifier("WorkerSpeed", 1.5)
	end,
}

return WorkerSurge
