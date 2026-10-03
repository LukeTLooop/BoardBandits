--!strict
-- Worker Filter Utility

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config --
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local sharedConfig = sharedFolder:WaitForChild("Config")

local WorkerFilterConfig = require(sharedConfig:WaitForChild("WorkerFilterConfig"))

-- Types --
local sharedTypes = sharedFolder:WaitForChild("Types")

local WorkerFilterTypes = require(sharedTypes:WaitForChild("WorkerFilterTypes"))
local WorkerTypes = require(sharedTypes:WaitForChild("WorkerTypes"))

-- Utility --
local WorkerFilterUtil = {}

-- Active --
function WorkerFilterUtil.HasActiveFilters(filters: WorkerFilterTypes.FilterState): boolean
	for _, selectedValues in filters do
		for _, selected in selectedValues do
			if selected then
				return true
			end
		end
	end

	return false
end

-- Category Active --
function WorkerFilterUtil.IsCategoryActive(filters: WorkerFilterTypes.FilterState, filterId: string): boolean
	local selectedValues = filters[filterId]
	if not selectedValues then
		return false
	end

	for _, selected in selectedValues do
		if selected then
			return true
		end
	end

	return false
end

-- Selected --
function WorkerFilterUtil.IsSelected(filters: WorkerFilterTypes.FilterState, filterId: string, value: string): boolean
	local category = filters[filterId]
	if not category then
		return false
	end

	return category[value] == true
end

-- Toggle --
function WorkerFilterUtil.Toggle(
	filters: WorkerFilterTypes.FilterState,
	filterId: string,
	value: string
): WorkerFilterTypes.FilterState
	local result: WorkerFilterTypes.FilterState = {}

	-- Copy existing categories
	for existingId, values in filters do
		result[existingId] = table.clone(values)
	end

	local category = result[filterId]
	if not category then
		category = {}

		result[filterId] = category
	end

	category[value] = not (category[value] == true)

	return result
end

-- Clear Category --
function WorkerFilterUtil.ClearCategory(
	filters: WorkerFilterTypes.FilterState,
	filterId: string
): WorkerFilterTypes.FilterState
	local result: WorkerFilterTypes.FilterState = {}

	for existingId, values in filters do
		if existingId == filterId then
			continue
		end

		result[existingId] = table.clone(values)
	end

	return result
end

-- Match --
function WorkerFilterUtil.Matches(worker: WorkerTypes.ClientWorkerData, filters: WorkerFilterTypes.FilterState): boolean
	for filterId, selectedValues in filters do
		local definition = WorkerFilterConfig.Definitions[filterId]
		if not definition then
			continue
		end

		local categoryActive = false
		for _, selected in selectedValues do
			if selected then
				categoryActive = true

				break
			end
		end

		if not categoryActive then
			continue
		end

		local workerValue = definition.GetValue(worker)
		if not workerValue then
			return false
		end

		if selectedValues[workerValue] ~= true then
			return false
		end
	end

	return true
end

-- Highlight Label --
function WorkerFilterUtil.GetHighlightLabel(
	worker: WorkerTypes.ClientWorkerData,
	filters: WorkerFilterTypes.FilterState
): string?
	local matches: { string } = {}

	for _, filterId in WorkerFilterConfig.Order do
		local selectedValues = filters[filterId]
		if not selectedValues then
			continue
		end

		local definition = WorkerFilterConfig.Definitions[filterId]
		if not definition then
			continue
		end

		local value = definition.GetValue(worker)
		if value and selectedValues[value] then
			table.insert(matches, string.upper(value))
		end
	end

	if #matches == 0 then
		return nil
	end

	if #matches == 1 then
		return `{matches[1]} MATCH`
	end

	return "FILTER MATCH"
end

return WorkerFilterUtil
