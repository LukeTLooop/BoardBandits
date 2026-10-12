--!strict
-- Global Event Service

-- Services --
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Services --
local ServerEventService = require(script.Parent.ServerEventService)

-- Constants --
local ENVIRONMENT = if RunService:IsStudio() then "Dev" else "Live"

local DATASTORE_NAME = "BoardBandits_GlobalEvents_" .. ENVIRONMENT .. "_v1"
local REGISTRY_KEY = "ActiveEvents"
local MESSAGE_TOPIC = "BoardBandits_GlobalEvents_" .. ENVIRONMENT .. "_v1"

local SYNC_INTERVAL = 120
local SYNC_JITTER = 30
local SUBSCRIBE_RETRY_DELAY = 30

-- Types --
type GlobalEventRecord = {
	ActivationId: string,
	StartedAt: number,
	EndsAt: number?,
}

type GlobalSnapshot = {
	Revision: number,
	Events: { [string]: GlobalEventRecord },
}

type LocalActivation = {
	ActivationId: string,
	OwnerId: string,
}

export type GlobalEventInfo = {
	Id: string,
	ActivationId: string,
	StartedAt: number,
	EndsAt: number?,
}

-- Module --
local GlobalEventService = {}

-- DataStore --
local globalStore = DataStoreService:GetDataStore(DATASTORE_NAME)

local readOptions = Instance.new("DataStoreGetOptions")
readOptions.UseCache = false

-- State --
local scheduledWake: thread? = nil
local scheduledWakeVersion = 0
local initialized = false
local syncing = false
local syncPending = false
local hasSynchronized = false

local subscription: RBXScriptConnection? = nil

local lastRevision = -1

local lastSnapshot: GlobalSnapshot = {
	Revision = 0,
	Events = {},
}

local localActivations: { [string]: LocalActivation } = {}

local RequestSync: () -> ()

-- Helpers --
local function Now(): number
	return workspace:GetServerTimeNow()
end

local function IsValidDuration(value: number): boolean
	return value > 0 and value == value and value < math.huge
end

local function DecodeSnapshot(raw: any): GlobalSnapshot
	if raw == nil then
		return {
			Revision = 0,
			Events = {},
		}
	end

	assert(typeof(raw) == "table", "Invalid global event registry")

	assert(
		typeof(raw.Revision) == "number" and typeof(raw.Events) == "table",
		"Invalid global event registry structure"
	)

	return raw :: GlobalSnapshot
end

local function ReadSnapshot(): GlobalSnapshot
	local raw = globalStore:GetAsync(REGISTRY_KEY, readOptions)

	return DecodeSnapshot(raw)
end

local function CloneActiveEvents(snapshot: GlobalSnapshot, now: number): { [string]: GlobalEventRecord }
	local result: { [string]: GlobalEventRecord } = {}

	for id, record in snapshot.Events do
		if record.EndsAt == nil or record.EndsAt > now then
			result[id] = record
		end
	end

	return result
end

-- Local Synchronization --
local function ApplySnapshot(snapshot: GlobalSnapshot)
	-- Ignore stale responses that arrive out of order --
	if snapshot.Revision < lastRevision then
		return
	end

	lastRevision = snapshot.Revision
	lastSnapshot = snapshot
	hasSynchronized = true

	local now = Now()

	local desiredEvents = CloneActiveEvents(snapshot, now)

	-- Invalidate any previous wake-up, including queued
	scheduledWakeVersion += 1
	local wakeVersion = scheduledWakeVersion
	if scheduledWake then
		task.cancel(scheduledWake)
		scheduledWake = nil
	end

	local nextStartAt: number? = nil

	-- Exclude events that haven't started yet
	for id, record in desiredEvents do
		if record.StartedAt <= now then
			continue
		end

		if nextStartAt == nil or record.StartedAt < nextStartAt then
			nextStartAt = record.StartedAt
		end

		desiredEvents[id] = nil
	end

	-- Wake server when next global event is due
	if nextStartAt ~= nil then
		local delaySeconds = math.max(0, nextStartAt - Now())

		scheduledWake = task.delay(delaySeconds, function()
			if wakeVersion ~= scheduledWakeVersion then
				return
			end
			scheduledWake = nil
			RequestSync()
		end)
	end

	-- Stop local activations that no longer match --
	for id, owned in localActivations do
		local desired = desiredEvents[id]

		if desired ~= nil and desired.ActivationId == owned.ActivationId then
			continue
		end

		local currentOwner = ServerEventService:GetEventOwnerId(id)

		if currentOwner == owned.OwnerId then
			local success, err = ServerEventService:StopEvent(id, "Global")

			if not success then
				warn(`[GlobalEventService] Failed to stop '{id}': {tostring(err)}`)

				continue
			end
		end

		localActivations[id] = nil
	end

	-- Start missing global activations --
	for id, record in desiredEvents do
		if not ServerEventService:IsEventRegistered(id) then
			warn(`[GlobalEventService] Missing definition for '{id}'`)

			continue
		end

		local owned = localActivations[id]
		local currentOwner = ServerEventService:GetEventOwnerId(id)

		-- Already running the correct activation --
		if owned ~= nil and owned.ActivationId == record.ActivationId and owned.OwnerId == currentOwner then
			continue
		end

		-- Previous activation disappeared locally --
		if owned ~= nil and currentOwner ~= owned.OwnerId then
			localActivations[id] = nil
		end

		-- Do not take ownership of a server-local event --
		if currentOwner ~= nil then
			warn(`[GlobalEventService] Local event '{id}' conflicts with global activation`)

			continue
		end

		-- Use the remaining global duration --
		local remaining: number? = nil

		if record.EndsAt ~= nil then
			remaining = record.EndsAt - Now()

			if remaining <= 0 then
				continue
			end
		end

		local success, err = ServerEventService:StartEvent(id, remaining, record.EndsAt == nil)

		if not success then
			warn(`[GlobalEventService] Failed to start '{id}': {tostring(err)}`)

			continue
		end

		local ownerId = ServerEventService:GetEventOwnerId(id)

		if ownerId ~= nil then
			localActivations[id] = {
				ActivationId = record.ActivationId,
				OwnerId = ownerId,
			}
		end
	end
end

-- Remote Synchronization --
RequestSync = function()
	if syncing then
		syncPending = true
		return
	end

	syncing = true

	repeat
		syncPending = false

		local success, err = pcall(function(): boolean
			ApplySnapshot(ReadSnapshot())
			return true
		end)

		if not success then
			warn(`[GlobalEventService] Synchronization failed: {tostring(err)}`)
		end
	until not syncPending

	syncing = false
end

-- Messaging --
local function PublishChange(revision: number)
	task.spawn(function()
		local success, err = pcall(function(): boolean
			MessagingService:PublishAsync(MESSAGE_TOPIC, {
				Revision = revision,
			})

			return true
		end)

		if not success then
			warn(`[GlobalEventService] Publish failed: {tostring(err)}`)
		end
	end)
end

-- Initialization --
function GlobalEventService:Initialize()
	if initialized then
		return
	end

	initialized = true

	-- Subscribe to cross-server notifications --
	task.spawn(function()
		while subscription == nil do
			local success, result = pcall(function(): RBXScriptConnection
				return MessagingService:SubscribeAsync(MESSAGE_TOPIC, function(_message)
					task.defer(RequestSync)
				end)
			end)

			if success then
				subscription = result
				break
			end

			warn(`[GlobalEventService] Subscription failed: {tostring(result)}`)

			task.wait(SUBSCRIBE_RETRY_DELAY)
		end
	end)

	-- Load existing events for this server --
	task.spawn(RequestSync)

	-- Reconcile periodically in case messages are missed --
	task.spawn(function()
		while true do
			task.wait(SYNC_INTERVAL + math.random(0, SYNC_JITTER))

			RequestSync()
		end
	end)
end

-- Global Activation --
function GlobalEventService:StartGlobalEvent(
	id: string,
	durationOverride: number?,
	indefinitely: boolean?,
	scheduledStartAt: number?
): (boolean, string?)
	self:Initialize()

	if not ServerEventService:IsEventRegistered(id) then
		return false, `Unknown event: {id}`
	end

	local duration: number?

	if indefinitely then
		duration = nil
	elseif durationOverride ~= nil then
		duration = durationOverride
	else
		duration = ServerEventService:GetDefaultDuration(id)
	end

	if duration ~= nil and not IsValidDuration(duration) then
		return false, "Invalid event duration"
	end

	local now = Now()
	local startedAt = scheduledStartAt or now

	if scheduledStartAt ~= nil then
		if
			startedAt ~= startedAt
			or startedAt == math.huge
			or startedAt == -math.huge
			or startedAt <= now
			or startedAt - now > 604800 -- 7 days
		then
			return false, "Invalid scheduled start time"
		end
	end

	local activationId = HttpService:GenerateGUID(false)

	local record: GlobalEventRecord = {
		ActivationId = activationId,
		StartedAt = startedAt,
		EndsAt = if duration ~= nil then startedAt + duration else nil,
	}

	-- Atomic modification of the authoritative record --
	local success, result = pcall(function(): GlobalSnapshot?
		return globalStore:UpdateAsync(REGISTRY_KEY, function(raw: any): GlobalSnapshot?
			local current = DecodeSnapshot(raw)

			local events = CloneActiveEvents(current, Now())

			-- Only one global activation per event ID --
			if events[id] ~= nil then
				return nil
			end

			events[id] = record

			return {
				Revision = current.Revision + 1,
				Events = events,
			}
		end) :: GlobalSnapshot?
	end)

	if not success then
		task.spawn(RequestSync)
		return false, `DataStore update failed: {tostring(result)}`
	end

	if result == nil then
		task.spawn(RequestSync)
		return false, `Global event '{id}' is already active`
	end

	ApplySnapshot(result)
	PublishChange(result.Revision)

	return true, nil
end

function GlobalEventService:ScheduleGlobalEvent(
	id: string,
	startsAt: number,
	durationOverride: number?,
	indefinitely: boolean?
): (boolean, string?)
	return self:StartGlobalEvent(id, durationOverride, indefinitely, startsAt)
end

-- Global Termination --
function GlobalEventService:StopGlobalEvent(id: string): (boolean, string?)
	self:Initialize()

	if not ServerEventService:IsEventRegistered(id) then
		return false, `Unknown event: {id}`
	end

	local success, result = pcall(function(): GlobalSnapshot?
		return globalStore:UpdateAsync(REGISTRY_KEY, function(raw: any): GlobalSnapshot?
			local current = DecodeSnapshot(raw)

			local events = CloneActiveEvents(current, Now())

			if events[id] == nil then
				return nil
			end

			events[id] = nil

			return {
				Revision = current.Revision + 1,
				Events = events,
			}
		end) :: GlobalSnapshot?
	end)

	if not success then
		task.spawn(RequestSync)
		return false, `DataStore update failed: {tostring(result)}`
	end

	if result == nil then
		task.spawn(RequestSync)
		return false, `Global event '{id}' is not active`
	end

	ApplySnapshot(result)
	PublishChange(result.Revision)

	return true, nil
end

-- Cancellation --
function GlobalEventService:CancelScheduledGlobalEvent(id: string): (boolean, string?)
	self:Initialize()

	if not ServerEventService:IsEventRegistered(id) then
		return false, `Unknown event: {id}`
	end

	local success, result = pcall(function(): GlobalSnapshot?
		return globalStore:UpdateAsync(REGISTRY_KEY, function(raw: any): GlobalSnapshot?
			local current = DecodeSnapshot(raw)
			local now = Now()
			local events = CloneActiveEvents(current, now)
			local record = events[id]

			if record == nil or record.StartedAt <= now then
				return nil
			end

			events[id] = nil
			return {
				Revision = current.Revision + 1,
				Events = events,
			}
		end) :: GlobalSnapshot?
	end)

	if not success then
		task.spawn(RequestSync)
		return false, `DataStore update failed: {tostring(result)}`
	end

	if result == nil then
		task.spawn(RequestSync)
		return false, `No pending global schedule for '{id}'`
	end

	ApplySnapshot(result)
	PublishChange(result.Revision)
	return true, nil
end

-- Queries --
function GlobalEventService:IsGlobalEventActive(id: string): boolean
	local record = lastSnapshot.Events[id]

	if record == nil then
		return false
	end

	local now = Now()
	return record.StartedAt <= now and (record.EndsAt == nil or record.EndsAt > now)
end

function GlobalEventService:IsLocallyManaged(id: string): boolean
	local owned = localActivations[id]
	if not owned then
		return false
	end

	return ServerEventService:GetEventOwnerId(id) == owned.OwnerId
end

function GlobalEventService:GetActiveGlobalEvents(): { GlobalEventInfo }
	local result: { GlobalEventInfo } = {}

	for id, record in lastSnapshot.Events do
		if record.StartedAt > Now() then
			continue
		end

		if record.EndsAt ~= nil and record.EndsAt <= Now() then
			continue
		end

		table.insert(result, {
			Id = id,
			ActivationId = record.ActivationId,
			StartedAt = record.StartedAt,
			EndsAt = record.EndsAt,
		})
	end

	table.sort(result, function(a, b)
		return a.Id < b.Id
	end)

	return result
end

function GlobalEventService:GetScheduledGlobalEvents(): { GlobalEventInfo }
	local result: { GlobalEventInfo } = {}
	local now = Now()

	for id, record in lastSnapshot.Events do
		if record.StartedAt <= now then
			continue
		end

		table.insert(result, {
			Id = id,
			ActivationId = record.ActivationId,
			StartedAt = record.StartedAt,
			EndsAt = record.EndsAt,
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

function GlobalEventService:HasSynchronized(): boolean
	return hasSynchronized
end

function GlobalEventService:Synchronize()
	self:Initialize()
	RequestSync()
end

return GlobalEventService
