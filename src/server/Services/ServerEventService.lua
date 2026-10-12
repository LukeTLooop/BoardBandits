--!strict
-- Server Event Service

-- Managers --
local GameStateManager = require(script.Parent.Parent.Managers.GameStateManager)

-- Events --
local eventsFolder = script.Parent.Parent.Events

local EventTypes = require(eventsFolder.EventTypes)
local EventContext = require(eventsFolder.EventContext)

-- Types --
type EventDefinition = EventTypes.EventDefinition
type StopReason = EventTypes.StopReason
type ActiveEventInfo = EventTypes.ActiveEventInfo

type RuntimeStatus = "Starting" | "Active" | "Stopping"

type EventRuntime = {
	Definition: EventDefinition,
	Scope: EventContext.Scope,

	Status: RuntimeStatus,

	StartedAt: number,
	EndsAt: number?,

	Timer: thread?,
}

-- Service --
local ServerEventService = {}

-- State --
local definitions: { [string]: EventDefinition } = {}
local activeEvents: { [string]: EventRuntime } = {}

-- Internal --
local function GetStatusKey(id: string): string
	return `Events/{id}/Status`
end

local function IsValidDuration(value: number): boolean
	return value > 0 and value == value and value < math.huge
end

local function IsValidPriority(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

local function SetStatus(id: string, status: string)
	GameStateManager.SetState(GetStatusKey(id), status)
end

-- Registration --
function ServerEventService:RegisterEvent(definition: EventDefinition)
	assert(typeof(definition) == "table", "Event definition must be a table")
	assert(
		typeof(definition.Id) == "string" and definition.Id:match("^[%w_%-]+$") ~= nil,
		"Event definition requires a valid Id"
	)
	assert(definitions[definition.Id] == nil, string.format("Event '%s' is already registered", definition.Id))
	assert(typeof(definition.OnStart) == "function", "Event requires an OnStart callback")
	assert(definition.OnStop == nil or typeof(definition.OnStop) == "function", "Event OnStop must be a function")

	if definition.Duration ~= nil then
		assert(IsValidDuration(definition.Duration), "Event duration must be a positive finite number")
	end

	if definition.Priority ~= nil then
		assert(IsValidPriority(definition.Priority), "Event priority must be finite")
	end

	definitions[definition.Id] = definition

	GameStateManager.RegisterState(GetStatusKey(definition.Id), "Inactive")
end

-- Activation --
function ServerEventService:StartEvent(
	id: string,
	durationOverride: number?,
	indefinitely: boolean?
): (boolean, string?)
	local definition = definitions[id]
	if not definition then
		return false, `Unknown event: {id}`
	end

	if activeEvents[id] ~= nil then
		return false, `Event '{id}' is already running`
	end

	local duration: number?
	if indefinitely then
		duration = nil
	elseif durationOverride ~= nil then
		duration = durationOverride
	else
		duration = definition.Duration
	end

	if duration ~= nil and not IsValidDuration(duration) then
		return false, "Event duration must be positive and finite"
	end

	local priority = if definition.Priority ~= nil then definition.Priority else 0
	local scope = EventContext.new(id, priority)
	local startedAt = workspace:GetServerTimeNow()
	local runtime: EventRuntime = {
		Definition = definition,
		Scope = scope,

		Status = "Starting",

		StartedAt = startedAt,
		EndsAt = if duration ~= nil then startedAt + duration else nil,

		Timer = nil,
	}

	activeEvents[id] = runtime
	SetStatus(id, "Starting")

	-- Invoke the event --
	local success, err = pcall(function(): boolean
		definition.OnStart(scope.Context)
		return true
	end)

	if not success then
		-- Roll back anything OnStart already applied
		scope.Cleanup()

		activeEvents[id] = nil

		SetStatus(id, "Inactive")

		warn(`[ServerEventService] Failed to start '{id}': {tostring(err)}`)

		return false, tostring(err)
	end

	-- Mark as active
	runtime.Status = "Active"
	SetStatus(id, "Active")

	-- Schedule automatic expiration --
	if duration ~= nil and activeEvents[id] == runtime then
		runtime.Timer = task.delay(duration, function()
			-- Prevent old timers from stopping new activations
			if activeEvents[id] ~= runtime then
				return
			end

			-- Timer is already executing
			runtime.Timer = nil
			ServerEventService:StopEvent(id, "Expired")
		end)
	end

	return true, nil
end

-- Termination --
function ServerEventService:StopEvent(id: string, reason: StopReason?): (boolean, string?)
	local runtime = activeEvents[id]
	if not runtime then
		return false, `Event {id} is not running`
	end

	if runtime.Status == "Starting" then
		return false, "Event is still starting"
	end

	if runtime.Status == "Stopping" then
		return false, "Event is already stopping"
	end

	runtime.Status = "Stopping"
	SetStatus(id, "Stopping")

	-- Cancel pending expiration --
	local timer = runtime.Timer
	runtime.Timer = nil

	if timer then
		task.cancel(timer)
	end

	-- Invoke optional OnStop --
	local onStop = runtime.Definition.OnStop
	if onStop then
		local success, err = pcall(function(): boolean
			onStop(runtime.Scope.Context, reason or "Manual")
			return true
		end)

		if not success then
			warn(`[ServerEventService] OnStop failed for '{id}': {tostring(err)}`)
		end
	end

	-- Always clean up event-owned resources --
	runtime.Scope.Cleanup()

	-- Remove runtime --
	activeEvents[id] = nil
	SetStatus(id, "Inactive")

	return true, nil
end

function ServerEventService.StopAll(reason: StopReason?)
	local ids: { string } = {}

	for id in activeEvents do
		table.insert(ids, id)
	end

	for _, id in ids do
		ServerEventService:StopEvent(id, reason or "Manual")
	end
end

-- Queries --
function ServerEventService:IsEventActive(id: string): boolean
	local runtime = activeEvents[id]
	return runtime ~= nil and runtime.Status == "Active"
end

function ServerEventService:IsEventRegistered(id: string): boolean
	return definitions[id] ~= nil
end

function ServerEventService:GetEventOwnerId(id: string): string?
	local runtime = activeEvents[id]
	if not runtime then
		return nil
	end

	return runtime.Scope.Context.OwnerId
end

function ServerEventService:GetDefaultDuration(id: string): number?
	local definition = definitions[id]
	assert(definition ~= nil, `Unknown event: {id}`)

	return definition.Duration
end

function ServerEventService:GetActiveEvents(): { ActiveEventInfo }
	local result: { ActiveEventInfo } = {}

	for id, runtime in activeEvents do
		if runtime.Status ~= "Active" then
			continue
		end

		table.insert(result, {
			Id = id,
			OwnerId = runtime.Scope.Context.OwnerId,
			StartedAt = runtime.StartedAt,
			EndsAt = runtime.EndsAt,
		})
	end

	table.sort(result, function(a, b)
		if a.StartedAt == b.StartedAt then
			return a.Id < b.Id
		end

		return a.StartedAt < b.StartedAt
	end)

	return result
end

function ServerEventService:GetRegisteredEventIds(): { string }
	local ids: { string } = {}

	for id in definitions do
		table.insert(ids, id)
	end

	table.sort(ids)

	return ids
end

-- Automatic Registration --
local definitionsFolder = eventsFolder:WaitForChild("Definitions")
assert(definitionsFolder:IsA("Folder"), "Events/Definitions must be a Folder")

local modules: { ModuleScript } = {}
for _, child in definitionsFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		table.insert(modules, child)
	end
end

table.sort(modules, function(a, b)
	return a.Name < b.Name
end)

for _, moduleScript in modules do
	local definition = require(moduleScript) :: EventDefinition

	assert(
		definition.Id == moduleScript.Name,
		`Event definition '{moduleScript.Name}' must have Id '{moduleScript.Name}'`
	)

	ServerEventService:RegisterEvent(definition)
end

return ServerEventService
