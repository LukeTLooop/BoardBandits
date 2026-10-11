--!strict
-- Event Context

-- Services --
local HttpService = game:GetService("HttpService")

-- Types --
local EventTypes = require(script.Parent.EventTypes)

export type Scope = {
	Context: EventTypes.EventContext,
	Cleanup: () -> (),
}

-- Module --
local EventContext = {}

-- Constructors --
function EventContext.new(eventId: string, defaultPriority: number): Scope
	local ownerId = `ServerEvent/{eventId}/{HttpService:GenerateGUID(false)}`

	-- State
	local closed = false
	local cleanups: { () -> () } = {}

	local ownedModifiers: { [string]: boolean } = {}
	local ownsEnvironment = false
	local ownsMusic = false

	-- Internal --
	local function AssertOpen()
		assert(not closed, `Event context '{eventId}' is closed!`)
	end

	local function TrackCleanup(callback: () -> ())
		table.insert(cleanups, callback)
	end

	-- Public Context
	local context: EventTypes.EventContext = {
		EventId = eventId,
		OwnerId = ownerId,

		AddCleanup = function(_self: EventTypes.EventContext, callback: () -> ())
			AssertOpen()
			TrackCleanup(callback)
		end,

		SetModifier = function(_self: EventTypes.EventContext, name: string, value: number, priority: number?)
			AssertOpen()

			if not ownedModifiers[name] then
				ownedModifiers[name] = true

				TrackCleanup(function()
					local ModifierService = require(script.Parent.Parent.Services.ModifierService)
					ModifierService.RemoveOverride(name, ownerId)
				end)
			end

			local ModifierService = require(script.Parent.Parent.Services.ModifierService)
			ModifierService.SetOverride(name, ownerId, value, if priority ~= nil then priority else defaultPriority)
		end,

		SetEnvironment = function(_self: EventTypes.EventContext, preset: string, priority: number?)
			AssertOpen()

			if not ownsEnvironment then
				ownsEnvironment = true

				TrackCleanup(function()
					local EnvironmentService = require(script.Parent.Parent.Services.EnvironmentService)
					EnvironmentService.RemoveOverride(ownerId)
				end)
			end

			local EnvironmentService = require(script.Parent.Parent.Services.EnvironmentService)
			EnvironmentService.SetOverride(ownerId, preset, if priority ~= nil then priority else defaultPriority)
		end,

		SetMusic = function(_self: EventTypes.EventContext, track: string, priority: number?)
			AssertOpen()

			if not ownsMusic then
				ownsMusic = true

				TrackCleanup(function()
					local MusicService = require(script.Parent.Parent.Services.MusicService)
					MusicService.RemoveOverride(ownerId)
				end)
			end

			local MusicService = require(script.Parent.Parent.Services.MusicService)
			MusicService.SetOverride(ownerId, track, if priority ~= nil then priority else defaultPriority)
		end,
	}

	-- Cleanup --
	local function Cleanup()
		if closed then
			return
		end

		closed = true

		-- Reverse cleanup order
		for index = #cleanups, 1, -1 do
			local callback = cleanups[index]

			local success, err = pcall(function(): boolean
				callback()
				return true
			end)

			if not success then
				warn(`[EventContext] Cleanup failed for '{eventId}': {tostring(err)}`)
			end
		end

		table.clear(cleanups)
	end

	return {
		Context = context,
		Cleanup = Cleanup,
	}
end

return EventContext
