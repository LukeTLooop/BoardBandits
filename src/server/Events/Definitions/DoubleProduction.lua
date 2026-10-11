--!strict
-- Double Production Event

-- Types --
local EventTypes = require(script.Parent.Parent.EventTypes)

-- Event --
local DoubleProduction: EventTypes.EventDefinition = {
	Id = "DoubleProduction",

	Duration = 600,
	Priority = 50,

	OnStart = function(context)
		context:SetModifier("ProductionSpeed", 2)

		print("[DoubleProduction] Event started")
	end,

	OnStop = function(_context, reason)
		print("[DoubleProduction] Event stopped:", reason)
	end,
}

return DoubleProduction
