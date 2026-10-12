--!strict
-- Storm Warning Event: use the built-in Storm environment preset.

-- Types --
local EventTypes = require(script.Parent.Parent.EventTypes)

-- Event --
local StormWarning: EventTypes.EventDefinition = {
	Id = "StormWarning",
	Duration = 180,
	Priority = 30,

	OnStart = function(context)
		context:SetEnvironment("Storm")
	end,
}

return StormWarning
