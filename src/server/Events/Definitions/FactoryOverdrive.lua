--!strict
-- Factory Overdrive Event

-- Types --
local EventTypes = require(script.Parent.Parent.EventTypes)

-- Event --
local FactoryOverdrive: EventTypes.EventDefinition = {
	Id = "FactoryOverdrive",

	Priority = 25,

	OnStart = function(context)
		context:SetModifier("ProductionSpeed", 1.5)
	end,
}

return FactoryOverdrive
