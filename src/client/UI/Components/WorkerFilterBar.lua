--!strict
-- Worker Filter Bar Component

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)

-- Config --
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local sharedConfig = sharedFolder:WaitForChild("Config")

local WorkerFilterConfig = require(sharedConfig:WaitForChild("WorkerFilterConfig"))

-- Types --
local sharedTypes = sharedFolder:WaitForChild("Types")

local WorkerFilterTypes = require(sharedTypes:WaitForChild("WorkerFilterTypes"))

-- Utils --
local sharedUtils = sharedFolder:WaitForChild("Utility")

local WorkerFilterUtil = require(sharedUtils:WaitForChild("WorkerFilterUtil"))

-- UI --
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local components = script.Parent
local TabButton = require(components:WaitForChild("TabButton"))

local e = React.createElement

-- Props --
export type Props = {
	Filters: WorkerFilterTypes.FilterState,

	OnToggle: (string, string) -> (),
	OnClearCategory: (string) -> (),
	OnClearAll: () -> (),
}

-- Component --
local function WorkerFilterBar(props: Props)
	local children: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,

			VerticalAlignment = Enum.VerticalAlignment.Center,

			Padding = UDim.new(0, 8),

			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local layoutOrder = 0

	-- Categories
	for _, filterId in WorkerFilterConfig.Order do
		local definition = WorkerFilterConfig.Definitions[filterId]
		if not definition then
			continue
		end

		layoutOrder += 1

		children[`Label_{filterId}`] = e("TextLabel", {
			LayoutOrder = layoutOrder,

			Size = UDim2.fromOffset(85, 42),

			BackgroundTransparency = 1,

			Text = string.upper(definition.DisplayName),

			TextColor3 = Theme.Color.Ink,

			TextSize = 12,

			Font = Enum.Font.GothamBlack,
		})

		for _, option in definition.Options do
			layoutOrder += 1

			children[`{filterId}_{option.Value}`] = e(TabButton, {
				Text = option.DisplayName,

				Selected = WorkerFilterUtil.IsSelected(props.Filters, filterId, option.Value),

				Disabled = false,

				LayoutOrder = layoutOrder,

				OnActivated = function()
					props.OnToggle(filterId, option.Value)
				end,
			})
		end

		-- Clear category
		if WorkerFilterUtil.IsCategoryActive(props.Filters, filterId) then
			layoutOrder += 1

			children[`Clear_{filterId}`] = e(TabButton, {
				Text = `CLEAR {string.upper(definition.DisplayName)}`,

				Selected = false,

				Disabled = false,

				LayoutOrder = layoutOrder,

				OnActivated = function()
					props.OnClearCategory(filterId)
				end,
			})
		end
	end

	-- Clear all
	if WorkerFilterUtil.HasActiveFilters(props.Filters) then
		layoutOrder += 1

		children.ClearAll = e(TabButton, {
			Text = "CLEAR ALL",

			Selected = false,

			Disabled = false,

			LayoutOrder = layoutOrder,

			OnActivated = props.OnClearAll,
		})
	end

	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),

		BackgroundTransparency = 1,

		BorderSizePixel = 0,

		ScrollBarThickness = 0,

		ScrollingDirection = Enum.ScrollingDirection.X,

		AutomaticCanvasSize = Enum.AutomaticSize.X,

		CanvasSize = UDim2.new(),
	}, children)
end

return WorkerFilterBar
