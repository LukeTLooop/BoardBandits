--!strict
-- Player Data Schema

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

local PlayerDataSchema = {}

-- Version --
PlayerDataSchema.CurrentVersion = 2

-- Utility --
local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local result = {}

	for key, childValue in value do
		result[deepCopy(key)] = deepCopy(childValue)
	end

	return result
end

local function reconcileTable(target: { [any]: any }, defaults: { [any]: any }): ()
	for key, defaultValue in defaults do
		local currentValue = target[key]

		if currentValue == nil then
			target[key] = deepCopy(defaultValue)

			continue
		end

		if type(defaultValue) == "table" and type(currentValue) == "table" then
			reconcileTable(currentValue, defaultValue)
		end
	end
end

function PlayerDataSchema.CreateDefault(): PlayerDataTypes.PlayerData
	return {
		Version = PlayerDataSchema.CurrentVersion,

		Cash = 0,

		Workers = {},

		Factory = {
			Version = 1,
			PendingCash = 0,
			WorkerAssignments = {},
			Placements = {},
		},

		Stats = {
			WorkersPurchased = 0,
			WorkersStolen = 0,
			WorkersLost = 0,

			ItemsProduced = 0,
			ItemsSold = 0,
		},

		Progression = {
			PartsSold = 0,

			WorkerShopUnlocked = false,
		},
	}
end

-- Migrations --
local Migrations: { [number]: (any) -> () } = {
	-- Version 1 -> Version 2
	[1] = function(data: any)
		data.Progression = {
			PartsSold = 0,

			WorkerShopUnlocked = false,
		}
	end,
}

-- Reconcile Loaded Data --
function PlayerDataSchema.Reconcile(rawData: any): PlayerDataTypes.PlayerData
	local data: any

	if type(rawData) == "table" then
		data = deepCopy(rawData)
	else
		data = PlayerDataSchema.CreateDefault()
	end

	local version = if type(data.Version) == "number" then data.Version else 1

	while version < PlayerDataSchema.CurrentVersion do
		local migration = Migrations[version]

		assert(migration ~= nil, `Missing migration from data version {version}`)

		migration(data)

		version += 1

		data.Version = version
	end

	reconcileTable(data, PlayerDataSchema.CreateDefault())

	data.Version = PlayerDataSchema.CurrentVersion

	return data :: PlayerDataTypes.PlayerData
end

-- Persistent Snapshot --
function PlayerDataSchema.CreateSaveSnapshot(profile: PlayerDataTypes.PlayerData): PlayerDataTypes.PlayerData
	local snapshot = deepCopy(profile) :: PlayerDataTypes.PlayerData

	-- Worker placement/carrying is currently session-only
	-- All owned workers return to storage next time the player joins.
	for _, worker in snapshot.Workers do
		worker.State = "Stored"
		worker.FactoryId = nil
		worker.SlotIndex = nil
		worker.CarrierUserId = nil
	end

	return snapshot
end

return PlayerDataSchema
