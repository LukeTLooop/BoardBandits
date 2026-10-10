--!strict
-- Game State Manager

-- Types --
export type StateValue = string | number | boolean

export type StateCallback = (newValue: StateValue, oldValue: StateValue?) -> ()

-- Manager --
local GameStateManager = {}

-- State --
local states: { [string]: StateValue } = {}

-- Events --
local stateChanged = Instance.new("BindableEvent")
stateChanged.Name = "GameStateChanged"

-- Register State --
function GameStateManager.RegisterState(key: string, initialValue: StateValue)
	assert(key ~= "", "State key cannot be empty")
	assert(states[key] == nil, `State {key} is already registered`)

	states[key] = initialValue

	stateChanged:Fire(key, initialValue, nil)
end

-- Get State --
function GameStateManager.GetState(key: string): StateValue?
	return states[key]
end

-- Set State --
function GameStateManager.SetState(key: string, newValue: StateValue): boolean
	local oldValue = states[key]

	assert(oldValue ~= nil, `State {key} is not registered`)
	assert(typeof(oldValue) == typeof(newValue), `Invalid value type for state '{key}'`)

	if oldValue == newValue then
		return false
	end

	states[key] = newValue

	stateChanged:Fire(key, newValue, oldValue)

	return true
end

-- Observe State --
function GameStateManager.ObserveState(
	key: string,
	callback: StateCallback,
	fireImmediately: boolean?
): RBXScriptConnection
	local connection = stateChanged.Event:Connect(
		function(changedKey: string, newValue: StateValue, oldValue: StateValue?)
			if changedKey ~= key then
				return
			end

			callback(newValue, oldValue)
		end
	)

	if fireImmediately then
		local currentValue = states[key]
		if currentValue ~= nil then
			callback(currentValue, nil)
		end
	end

	return connection
end

-- Get Snapshot --
function GameStateManager.GetSnapshot(): { [string]: StateValue }
	return table.clone(states)
end

return GameStateManager
