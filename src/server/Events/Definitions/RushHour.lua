--!strict
-- Rush Hour Event: faster customer arrivals and increased sale proceeds.

-- Types --
local EventTypes = require(script.Parent.Parent.EventTypes)

-- Event --
local RushHour: EventTypes.EventDefinition = {
	Id = "RushHour",
	Duration = 300,
	Priority = 30,

	OnStart = function(context)
		context:SetModifier("CustomerSpawnRate", 1.75)
		context:SetModifier("IncomeMultiplier", 1.25)
	end,
}

return RushHour
