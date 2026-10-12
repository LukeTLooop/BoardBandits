--!strict
-- Global Events Initialization

-- Services --
local GlobalEventService = require(script.Parent.Services.GlobalEventService)
local ServerEventService = require(script.Parent.Services.ServerEventService)

-- Initialization --
GlobalEventService:Initialize()

game:BindToClose(function()
	ServerEventService.StopAll("Shutdown")
end)
