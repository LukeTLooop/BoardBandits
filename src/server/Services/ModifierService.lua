--!strict
-- Modifier Service

-- Services --
local ServerScriptService = game:GetService("ServerScriptService")

-- Managers --
local GameStateManager = require(ServerScriptService.Managers.GameStateManager)

-- Shared --
local PriorityState = require(ServerScriptService.Shared.PriorityState)

-- Constants --
local DEFAULT_MODIFIERS: { [string]: number } = {
	ProductionSpeed = 1,
	WorkerSpeed = 1,
	CustomerSpawnRate = 1,
	IncomeMultiplier = 1,
}

-- Service --
local ModifierService = {}

-- State --
local modifiers: { [string]: PriorityState.Layer<number> } = {}

-- Internal --
local function ValidateValue(value: number)
	assert(
		value >= 0 and value == value and math.abs(value) ~= math.huge,
		"Modifier value must be a finite, non-negative number!"
	)
end

local function GetLayer(name: string): PriorityState.Layer<number>
	local layer = modifiers[name]
	assert(layer ~= nil, `Unknown modifier: {name}`)

	return layer
end

-- Register Modifier --
function ModifierService.RegisterModifier(name: string, defaultValue: number)
	assert(name ~= "", "Modifier name cannot be empty!")
	assert(modifiers[name] == nil, "Modifier already registered!")

	ValidateValue(defaultValue)

	local stateKey = `Gameplay/Modifiers/{name}`

	GameStateManager.RegisterState(stateKey, defaultValue)

	modifiers[name] = PriorityState.new(defaultValue, function(newValue: number, _oldValue: number)
		GameStateManager.SetState(stateKey, newValue)
	end)
end

-- Get Modifier --
function ModifierService.GetModifier(name: string): number
	return GetLayer(name).Get()
end

-- Set Base Modifier --
function ModifierService.SetBaseModifier(name: string, value: number)
	ValidateValue(value)
	GetLayer(name).SetBase(value)
end

-- Set Override --
function ModifierService.SetOverride(name: string, owner: string, value: number, priority: number?)
	ValidateValue(value)
	GetLayer(name).SetOverride(owner, value, priority)
end

-- Remove Override --
function ModifierService.RemoveOverride(name: string, owner: string): boolean
	return GetLayer(name).RemoveOverride(owner)
end

-- Get Snapshot --
function ModifierService.GetSnapshot(): { [string]: number }
	local snapshot: { [string]: number } = {}

	for name, layer in modifiers do
		snapshot[name] = layer.Get()
	end

	return snapshot
end

-- Initialization --
for name, defaultValue in DEFAULT_MODIFIERS do
	ModifierService.RegisterModifier(name, defaultValue)
end

return ModifierService
