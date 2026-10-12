--!strict
-- Event Test

local ENABLE_EVENT_TESTS = false
if not ENABLE_EVENT_TESTS then
	return
end

-- Services --
local ServerEventService = require(script.Parent.Services.ServerEventService)
local ModifierService = require(script.Parent.Services.ModifierService)

-- Tests --
local success, err = ServerEventService:StartEvent("FactoryOverdrive")

assert(success, err)
assert(ModifierService.GetModifier("ProductionSpeed") == 1.5, "Invalid production speed")

success, err = ServerEventService:StartEvent("DoubleProduction", 5)

assert(success, err)
assert(ModifierService.GetModifier("ProductionSpeed") == 2, "Invalid production speed")

-- Wait for DoubleProduction to expire
task.wait(6)

assert(not ServerEventService:IsEventActive("DoubleProduction"), "dobule production is active")
assert(ModifierService.GetModifier("ProductionSpeed") == 1.5, "Invalid production speed")

-- Stop the remaining event
success, err = ServerEventService:StopEvent("FactoryOverdrive")

assert(success, err)
assert(ModifierService.GetModifier("ProductionSpeed") == 1, "Invalid production speed")

print("[EventTest] All lifecycle tests passed")
