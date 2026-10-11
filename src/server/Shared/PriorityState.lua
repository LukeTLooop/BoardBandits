--!strict
-- Priority State

-- Types --
type OverrideEntry<T> = {
	Value: T,
	Priority: number,
	Order: number,
}

export type Layer<T> = {
	Get: () -> T,
	SetBase: (value: T) -> (),
	SetOverride: (owner: string, value: T, priority: number?) -> (),
	RemoveOverride: (owner: string) -> boolean,
}

-- Module --
local PriorityState = {}

-- Constructor --
function PriorityState.new<T>(initialValue: T, onChanged: (newValue: T, oldValue: T) -> ()): Layer<T>
	local baseValue = initialValue
	local currentValue = initialValue

	local overrides: { [string]: OverrideEntry<T> } = {}
	local sequence = 0

	-- Internal
	local function Resolve(): T
		local winner: OverrideEntry<T>? = nil

		for _, entry in overrides do
			if
				winner == nil
				or entry.Priority > winner.Priority
				or (entry.Priority == winner.Priority and entry.Order > winner.Order)
			then
				winner = entry
			end
		end

		if winner then
			return winner.Value
		end

		return baseValue
	end

	local function Refresh()
		local nextValue = Resolve()
		if nextValue == currentValue then
			return
		end

		local oldValue = currentValue
		currentValue = nextValue

		onChanged(nextValue, oldValue)
	end

	-- Interface
	local layer: Layer<T> = {
		Get = function(): T
			return currentValue
		end,

		SetBase = function(value: T)
			baseValue = value
			Refresh()
		end,

		SetOverride = function(owner: string, value: T, priority: number?)
			assert(owner ~= "", "Override owner cannot be empty!")

			local rank = priority or 0

			assert(rank == rank and math.abs(rank) ~= math.huge, "Override priority must be finite!")

			sequence += 1

			overrides[owner] = {
				Value = value,
				Priority = rank,
				Order = sequence,
			}

			Refresh()
		end,

		RemoveOverride = function(owner: string): boolean
			if overrides[owner] == nil then
				return false
			end

			overrides[owner] = nil
			Refresh()

			return true
		end,
	}

	return layer
end

return PriorityState
