--!strict
-- Event Admin Service

-- Services --
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Services --
local ServerEventService = require(script.Parent.ServerEventService)
local GlobalEventService = require(script.Parent.GlobalEventService)

-- Config --
local Config = require(script.Parent.Parent.Config.EventAdminConfig)

-- Types --
type LocalSchedule = {
	Token: string,
	StartsAt: number,
	Timer: thread,
}

-- Service --
local EventAdminService = {}

-- State --
local localSchedules: { [string]: LocalSchedule } = {}
local lastCommands: { [number]: number } = {}

-- Helpers --
local function Now(): number
	return workspace:GetServerTimeNow()
end

local function Tokenize(input: string): { string }
	local result: { string } = {}

	for word in input:gmatch("%S+") do
		table.insert(result, word)
	end

	return result
end

local function IsPositiveInteger(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge and value >= 1 and value % 1 == 0
end

local function ParseDuration(raw: string?): (number?, boolean, string?)
	if raw == nil or raw:lower() == "default" then
		return nil, false, nil
	end

	if raw:lower() == "infinite" then
		return nil, true, nil
	end

	local duration = tonumber(raw)

	if duration == nil or not IsPositiveInteger(duration) or duration > Config.MaxDuration then
		return nil, false, "Invalid duration (1-86400 seconds)"
	end

	return duration, false, nil
end

local function ParseDelay(raw: string?): (number?, string?)
	if raw == nil then
		return nil, "Missing schedule delay"
	end

	local delaySeconds = tonumber(raw)

	if delaySeconds == nil or not IsPositiveInteger(delaySeconds) or delaySeconds > Config.MaxScheduleDelay then
		return nil, "Invalid schedule delay (1-604800 seconds)"
	end

	return delaySeconds, nil
end

local function DurationLabel(endsAt: number?): string
	if endsAt == nil then
		return "indefinite"
	end

	return `{math.max(0, math.ceil(endsAt - Now()))}s remaining`
end

local function Help(): { string }
	return {
		"start <server|global> <id> [seconds|default|infinite]",
		"stop <server|global> <id>",
		"schedule <server|global> <id> <delay> [duration]",
		"cancel <server|global> <id>",
		"list <server|global|scheduled|definitions>",
		"All times are in seconds.",
	}
end

-- Authorization --
function EventAdminService:IsAuthorized(userId: number): boolean
	return Config.AllowedUserIds[userId] == true
end

-- Local Scheduling --
function EventAdminService:ScheduleLocalEvent(
	id: string,
	delaySeconds: number,
	duration: number?,
	indefinitely: boolean
): (boolean, string?)
	if localSchedules[id] ~= nil then
		return false, "Event already has a local schedule"
	end

	if not ServerEventService:IsEventRegistered(id) then
		return false, "Unknown event"
	end

	local token = HttpService:GenerateGUID(false)

	local timer = task.delay(delaySeconds, function()
		local pending = localSchedules[id]

		if pending == nil or pending.Token ~= token then
			return
		end

		localSchedules[id] = nil

		local success, err = ServerEventService:StartEvent(id, duration, indefinitely)

		if not success then
			warn(`[EventAdminService] Scheduled event '{id}' failed: {tostring(err)}`)
		end
	end)

	localSchedules[id] = {
		Token = token,
		StartsAt = Now() + delaySeconds,
		Timer = timer,
	}

	return true, nil
end

function EventAdminService:CancelLocalSchedule(id: string): boolean
	local pending = localSchedules[id]

	if pending == nil then
		return false
	end

	localSchedules[id] = nil
	task.cancel(pending.Timer)

	return true
end

-- Inspection --
local function ListLocalEvents(): { string }
	local result = { "Server events:" }
	local events = ServerEventService:GetActiveEvents()

	if #events == 0 then
		table.insert(result, "No active server events.")
	end

	for _, event in events do
		table.insert(result, `{event.Id}: {DurationLabel(event.EndsAt)}`)
	end

	return result
end

local function ListGlobalEvents(): { string }
	GlobalEventService:Initialize()

	if not GlobalEventService:HasSynchronized() then
		return { "Global state is still synchronizing. Try again." }
	end

	local result = { "Active global events:" }
	local events = GlobalEventService:GetActiveGlobalEvents()

	if #events == 0 then
		table.insert(result, "No active global events.")
	end

	for _, event in events do
		table.insert(result, `{event.Id}: {DurationLabel(event.EndsAt)}`)
	end

	return result
end

local function ListSchedules(): { string }
	local result = { "Scheduled events:" }
	local count = 0

	local ids: { string } = {}

	for id in localSchedules do
		table.insert(ids, id)
	end

	table.sort(ids)

	for _, id in ids do
		local schedule = localSchedules[id]
		count += 1

		table.insert(result, `[Server] {id}: starts in {math.max(0, math.ceil(schedule.StartsAt - Now()))}s`)
	end

	GlobalEventService:Initialize()

	if GlobalEventService:HasSynchronized() then
		for _, event in GlobalEventService:GetScheduledGlobalEvents() do
			count += 1

			table.insert(result, `[Global] {event.Id}: starts in {math.max(0, math.ceil(event.StartedAt - Now()))}s`)
		end
	else
		table.insert(result, "Global schedules: synchronizing.")
	end

	if count == 0 and GlobalEventService:HasSynchronized() then
		table.insert(result, "No known pending schedules.")
	end

	return result
end

-- Command Execution --
function EventAdminService:Execute(player: Player, rawCommand: string): { string }
	-- Always authorize on the server --
	if not self:IsAuthorized(player.UserId) then
		return { "You are not authorized to manage events." }
	end

	if #rawCommand > 200 then
		return { "Command is too long." }
	end

	local now = os.clock()
	local lastUse = lastCommands[player.UserId] or -math.huge

	if now - lastUse < Config.CommandCooldown then
		return { "Please wait before issuing another command." }
	end

	lastCommands[player.UserId] = now

	local args = Tokenize(rawCommand)

	if #args == 0 or args[1]:lower() ~= "/event" then
		return { "Invalid event command." }
	end

	local action = (args[2] or "help"):lower()

	if action == "help" and #args <= 2 then
		return Help()
	end

	if action == "list" and #args == 3 then
		local target = args[3]:lower()

		if target == "server" then
			return ListLocalEvents()
		elseif target == "global" then
			return ListGlobalEvents()
		elseif target == "scheduled" then
			return ListSchedules()
		elseif target == "definitions" then
			local ids = ServerEventService:GetRegisteredEventIds()
			return {
				if #ids > 0 then "Registered: " .. table.concat(ids, ", ") else "No registered events.",
			}
		end
	end

	if action ~= "start" and action ~= "stop" and action ~= "schedule" and action ~= "cancel" then
		return Help()
	end

	local scope = (args[3] or ""):lower()
	local id = args[4]

	if scope ~= "server" and scope ~= "global" then
		return { "Scope must be 'server' or 'global'." }
	end

	if id == nil or not ServerEventService:IsEventRegistered(id) then
		return { "Unknown event ID. Use /event list definitions." }
	end

	if action == "stop" or action == "cancel" then
		if #args ~= 4 then
			return { "Unexpected arguments. Use /event help." }
		end

		if scope == "server" then
			if action == "cancel" then
				local canceled = self:CancelLocalSchedule(id)

				return {
					if canceled then `Canceled local schedule: {id}` else `No pending local schedule for {id}`,
				}
			end

			if GlobalEventService:IsLocallyManaged(id) then
				return { "This event is globally managed. Use 'stop global'." }
			end

			local success, err = ServerEventService:StopEvent(id)

			if not success then
				return { `Stop failed: {tostring(err)}` }
			end

			print(`[EventAdmin] {player.UserId} stopped server event {id}`)
			return { `Stopped server event: {id}` }
		end

		local success: boolean
		local err: string?
		if action == "cancel" then
			success, err = GlobalEventService:CancelScheduledGlobalEvent(id)
		else
			success, err = GlobalEventService:StopGlobalEvent(id)
		end

		if not success then
			warn(`[EventAdmin] Global stop/cancel failed: {tostring(err)}`)
			return {
				if action == "cancel"
					then `Cancel failed: {tostring(err)}`
					else "Global operation failed. Check server logs.",
			}
		end

		print(`[EventAdmin] {player.UserId} {action} global event {id}`)

		return { if action == "cancel" then `Cancelled global schedule: {id}` else `Stopped global event: {id}` }
	end

	if action == "start" and #args ~= 4 and #args ~= 5 then
		return { "Usage: /event start <scope> <id> [duration]" }
	end

	if action == "schedule" and #args ~= 5 and #args ~= 6 then
		return { "Usage: /event schedule <scope> <id> <delay> [duration]" }
	end

	local durationArgument = if action == "start" then args[5] else args[6]

	local duration, indefinitely, durationError = ParseDuration(durationArgument)

	if durationError ~= nil then
		return { durationError }
	end

	if action == "start" then
		local success: boolean
		local err: string?

		if scope == "server" then
			success, err = ServerEventService:StartEvent(id, duration, indefinitely)
		else
			success, err = GlobalEventService:StartGlobalEvent(id, duration, indefinitely)
		end

		if not success then
			warn(`[EventAdmin] Start failed for {id}: {tostring(err)}`)
			return { "Event start failed. Check server logs." }
		end

		print(`[EventAdmin] {player.UserId} started {scope} event {id}`)
		return { `Started {scope} event: {id}` }
	end

	-- Scheduling --
	local delaySeconds, delayError = ParseDelay(args[5])

	if delayError ~= nil or delaySeconds == nil then
		return { delayError or "Invalid delay" }
	end

	local success: boolean
	local err: string?

	if scope == "server" then
		success, err = self:ScheduleLocalEvent(id, delaySeconds, duration, indefinitely)
	else
		success, err = GlobalEventService:ScheduleGlobalEvent(id, Now() + delaySeconds, duration, indefinitely)
	end

	if not success then
		warn(`[EventAdmin] Schedule failed for {id}: {tostring(err)}`)
		return { "Scheduling failed. Check server logs." }
	end

	print(`[EventAdmin] {player.UserId} scheduled {scope} event {id}`)

	return { `Scheduled {scope} event {id} in {delaySeconds}s` }
end

-- Cleanup --
Players.PlayerRemoving:Connect(function(player)
	lastCommands[player.UserId] = nil
end)

return EventAdminService
