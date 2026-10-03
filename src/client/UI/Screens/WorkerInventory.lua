--!strict
-- Worker Inventory Gui Screen

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)

-- Config --
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local sharedConfig = sharedFolder:WaitForChild("Config")

local WorkerConfig = require(sharedConfig:WaitForChild("WorkerConfig"))

-- Types --
local sharedTypes = sharedFolder:WaitForChild("Types")

local WorkerTypes = require(sharedTypes:WaitForChild("WorkerTypes"))
local WorkerFilterTypes = require(sharedTypes:WaitForChild("WorkerFilterTypes"))

-- Utils --
local sharedUtils = sharedFolder:WaitForChild("Utility")

local WorkerFilterUtil = require(sharedUtils:WaitForChild("WorkerFilterUtil"))

-- UI --
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local components = script.Parent.Parent:WaitForChild("Components")
local ModalBackdrop = require(components:WaitForChild("ModalBackdrop"))
local Button = require(components:WaitForChild("Button"))
local CloseButton = require(components:WaitForChild("CloseButton"))
local OwnedWorkerCard = require(components:WaitForChild("OwnedWorkerCard"))
local WorkerViewport = require(components:WaitForChild("WorkerViewport"))
local WorkerFilterBar = require(components:WaitForChild("WorkerFilterBar"))

local e = React.createElement

-- Hooks --
local hooks = script.Parent.Parent:WaitForChild("Hooks")

local useResponsiveScale = require(hooks:WaitForChild("useResponsiveScale"))
local useOutsideClick = require(hooks:WaitForChild("useOutsideClick"))

-- Virtual Design --
local REFERENCE_VIEWPORT = Vector2.new(1440, 900)
local WINDOW_SIZE = Vector2.new(1240, 720)

-- Props --
export type Props = {
	Visible: boolean,
	Workers: { WorkerTypes.ClientWorkerData },
	StationRole: string?,
	Placing: boolean,
	StatusMessage: string,

	OnClose: () -> (),
	OnPlace: (string) -> (),
}

-- Component --
local function WorkerInventory(props: Props)
	local selectedWorkerId, setSelectedWorkerId = React.useState("")
	local activeFilters, setActiveFilters = React.useState({} :: WorkerFilterTypes.FilterState)

	local windowRef = React.useRef(nil :: Frame?)
	useOutsideClick(windowRef, props.Visible, props.OnClose)

	local uiScale = useResponsiveScale(REFERENCE_VIEWPORT, 0.94)

	local selectionResetKey = `{props.Visible}:{props.StationRole or ""}`

	-- Reset selection when target changes
	React.useEffect(function()
		setSelectedWorkerId("")

		return nil
	end, {
		selectionResetKey,
	})

	if not props.Visible then
		return nil
	end

	-- Stored workers only
	local storedWorkers: { WorkerTypes.ClientWorkerData } = {}

	for _, worker in props.Workers do
		if worker.State ~= "Stored" then
			continue
		end

		table.insert(storedWorkers, worker)
	end

	-- Sort stored workers by compatability
	local function isWorkerCompatible(worker: WorkerTypes.ClientWorkerData): boolean
		local definition = WorkerConfig[worker.WorkerType]
		if not definition then
			return false
		end

		local stationRole = props.StationRole
		if not stationRole then
			return false
		end

		return definition.RoleName == stationRole
	end

	-- Filters
	local function toggleFilter(filterId: string, value: string): ()
		setActiveFilters(WorkerFilterUtil.Toggle(activeFilters, filterId, value))
	end

	local function clearFilterCategory(filterId: string): ()
		setActiveFilters(WorkerFilterUtil.ClearCategory(activeFilters, filterId))
	end

	local function clearAllFilters()
		setActiveFilters({})
	end

	local filtersActive = WorkerFilterUtil.HasActiveFilters(activeFilters)

	table.sort(storedWorkers, function(a: WorkerTypes.ClientWorkerData, b: WorkerTypes.ClientWorkerData): boolean
		local aCompatible = isWorkerCompatible(a)
		local bCompatible = isWorkerCompatible(b)

		-- Compatible always comes first
		if aCompatible ~= bCompatible then
			return aCompatible
		end

		-- Filter matches next
		if filtersActive then
			local aMatches = WorkerFilterUtil.Matches(a, activeFilters)
			local bMatches = WorkerFilterUtil.Matches(b, activeFilters)

			if aMatches ~= bMatches then
				return aMatches
			end
		end

		-- Then level
		local aLevel = a.Level
		local bLevel = b.Level

		if aLevel ~= bLevel then
			return aLevel > bLevel
		end

		-- Then alphabetically
		local aDefinition = WorkerConfig[a.WorkerType]
		local bDefinition = WorkerConfig[b.WorkerType]

		local aName = if aDefinition then aDefinition.DisplayName else a.WorkerType
		local bName = if bDefinition then bDefinition.DisplayName else b.WorkerType

		if aName ~= bName then
			return aName < bName
		end

		-- Fallback
		return a.Id < b.Id
	end)

	-- Cards
	local cardChildren: { [string]: any } = {
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 10),

			PaddingRight = UDim.new(0, 10),

			PaddingTop = UDim.new(0, 10),

			PaddingBottom = UDim.new(0, 10),
		}),

		Grid = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(236, 268),

			CellPadding = UDim2.fromOffset(16, 16),

			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local compatibleCount = 0

	for index, worker in storedWorkers do
		local definition = WorkerConfig[worker.WorkerType]
		if not definition then
			continue
		end

		local compatible = isWorkerCompatible(worker)

		if compatible then
			compatibleCount += 1
		end

		local filterMatches = if filtersActive then WorkerFilterUtil.Matches(worker, activeFilters) else false

		local filterLabel = if filtersActive then WorkerFilterUtil.GetHighlightLabel(worker, activeFilters) else nil

		cardChildren[worker.Id] = e(OwnedWorkerCard, {
			Worker = worker,

			LayoutOrder = index,

			Selected = worker.Id == selectedWorkerId,

			Disabled = not compatible,

			FiltersActive = filtersActive,

			FilterMatches = filterMatches,

			FilterLabel = filterLabel,

			OnActivated = function()
				if not compatible then
					return
				end

				setSelectedWorkerId(worker.Id)
			end,
		})
	end

	-- Selected worker
	local selectedWorker: WorkerTypes.ClientWorkerData? = nil

	for _, worker in storedWorkers do
		if worker.Id == selectedWorkerId then
			selectedWorker = worker

			break
		end
	end

	-- Details
	local selectedDefinition = if selectedWorker then WorkerConfig[selectedWorker.WorkerType] else nil

	local roleColor = if selectedDefinition
		then Theme.RoleColors[selectedDefinition.RoleName] or Theme.Color.Yellow
		else Theme.Color.Yellow

	local canPlace = selectedWorker ~= nil and isWorkerCompatible(selectedWorker) and not props.Placing

	local assignText = if props.Placing
		then "ASSIGNING..."
		elseif selectedWorker == nil then "SELECT A WORKER"
		elseif not canPlace then "UNAVAILABLE"
		else "ASSIGN WORKER"

	-- Empty state
	local emptyText = if #storedWorkers == 0
		then "NO WORKERS IN STORAGE"
		elseif compatibleCount == 0 then `NO {string.upper(props.StationRole or "")} WORKERS AVAILABLE`
		else ""

	-- Render
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),

		BackgroundTransparency = 1,
	}, {
		Backdrop = e(ModalBackdrop),

		Window = e("Frame", {
			ref = windowRef,

			AnchorPoint = Vector2.new(0.5, 0.5),

			Position = UDim2.fromScale(0.5, 0.5),

			Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),

			BackgroundColor3 = Theme.Color.Cream,

			ZIndex = 2,

			ClipsDescendants = true,
		}, {
			Scale = e("UIScale", {
				Scale = uiScale,
			}),

			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 20),
			}),

			Stroke = e("UIStroke", {
				Color = Theme.Color.Ink,

				Thickness = 5,
			}),

			-- Header
			Header = e("Frame", {
				Position = UDim2.fromOffset(28, 20),

				Size = UDim2.fromOffset(1184, 78),

				BackgroundTransparency = 1,
			}, {
				Title = e("TextLabel", {
					BackgroundTransparency = 1,

					Position = UDim2.fromOffset(0, 0),

					Size = UDim2.fromOffset(700, 46),

					Text = "WORKER STORAGE",

					TextColor3 = Theme.Color.Ink,

					TextSize = 38,

					Font = Enum.Font.GothamBlack,

					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				Subtitle = e("TextLabel", {
					BackgroundTransparency = 1,

					Position = UDim2.fromOffset(2, 45),

					Size = UDim2.fromOffset(650, 22),

					Text = "ASSIGN A WORKER TO THIS STATION",

					TextColor3 = Theme.Color.SurfaceRaised,

					TextSize = 13,

					Font = Enum.Font.GothamBold,

					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				-- Station badge
				Station = e("TextLabel", {
					AnchorPoint = Vector2.new(1, 0),

					Position = UDim2.fromOffset(1080, 8),

					Size = UDim2.fromOffset(235, 38),

					BackgroundColor3 = Theme.RoleColors[props.StationRole or ""] or Theme.Color.Yellow,

					Text = `{string.upper(props.StationRole or "UNKNOWN")} STATION`,

					TextColor3 = Theme.Color.Ink,

					TextSize = 13,

					Font = Enum.Font.GothamBlack,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(0, 9),
					}),
				}),
			}),

			-- Status strip
			Status = e("Frame", {
				Position = UDim2.fromOffset(28, 105),

				Size = UDim2.fromOffset(1184, 46),

				BackgroundColor3 = Color3.fromRGB(226, 221, 204),

				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 10),
				}),

				Text = e("TextLabel", {
					Size = UDim2.fromScale(1, 1),

					BackgroundTransparency = 1,

					Text = if compatibleCount > 0
						then `{compatibleCount} COMPATIBLE WORKER{if compatibleCount == 1 then "" else "S"} AVAILABLE`
						else emptyText,

					TextColor3 = Theme.Color.Ink,

					TextSize = 13,

					Font = Enum.Font.GothamBlack,
				}),
			}),

			Filters = e("Frame", {
				Position = UDim2.fromOffset(28, 163),

				Size = UDim2.fromOffset(1184, 48),

				BackgroundTransparency = 1,
			}, {
				Bar = e(WorkerFilterBar, {
					Filters = activeFilters,

					OnToggle = toggleFilter,

					OnClearCategory = clearFilterCategory,

					OnClearAll = clearAllFilters,
				}),
			}),

			-- Catalog
			Catalog = e("Frame", {
				Position = UDim2.fromOffset(28, 225),

				Size = UDim2.fromOffset(1184, 467),

				BackgroundTransparency = 1,
			}, {
				Workers = e(
					"ScrollingFrame",
					{
						Position = UDim2.fromOffset(0, 0),

						Size = UDim2.fromOffset(760, 467),

						BackgroundTransparency = 1,

						BorderSizePixel = 0,

						ScrollBarThickness = 5,

						ScrollBarImageColor3 = Theme.Color.SurfaceRaised,

						AutomaticCanvasSize = Enum.AutomaticSize.Y,

						CanvasSize = UDim2.new(),
					},
					if #storedWorkers > 0
						then cardChildren
						else {
							Empty = e("TextLabel", {
								Size = UDim2.fromScale(1, 1),

								BackgroundTransparency = 1,

								Text = emptyText,

								TextColor3 = Theme.Color.SurfaceRaised,

								TextSize = 24,

								Font = Enum.Font.GothamBlack,
							}),
						}
				),

				Divider = e("Frame", {
					Position = UDim2.fromOffset(777, 0),

					Size = UDim2.fromOffset(3, 467),

					BackgroundColor3 = Theme.Color.Ink,

					BackgroundTransparency = 0.88,

					BorderSizePixel = 0,
				}),

				-- Details
				Details = e("Frame", {
					Position = UDim2.fromOffset(802, 0),

					Size = UDim2.fromOffset(382, 467),

					BackgroundColor3 = Theme.Color.Surface,

					ClipsDescendants = true,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(0, 16),
					}),

					RoleBar = e("Frame", {
						Size = UDim2.new(1, 0, 0, 10),

						BackgroundColor3 = roleColor,

						BorderSizePixel = 0,
					}),

					Preview = if selectedDefinition
						then e("Frame", {
							Position = UDim2.fromOffset(14, 22),

							Size = UDim2.fromOffset(354, 205),

							BackgroundColor3 = Theme.Color.SurfaceRaised,
						}, {
							Corner = e("UICorner", {
								CornerRadius = UDim.new(0, 12),
							}),

							Viewport = e(WorkerViewport, {
								ModelName = selectedDefinition.ModelName,
							}),
						})
						else nil,

					Name = e("TextLabel", {
						Position = UDim2.fromOffset(20, 240),

						Size = UDim2.new(1, -40, 0, 38),

						BackgroundTransparency = 1,

						Text = if selectedDefinition
							then string.upper(selectedDefinition.DisplayName)
							else "SELECT A WORKER",

						TextColor3 = Theme.Color.Text,

						TextSize = 27,

						Font = Enum.Font.GothamBlack,

						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					Role = e("TextLabel", {
						Position = UDim2.fromOffset(20, 279),

						Size = UDim2.new(1, -40, 0, 22),

						BackgroundTransparency = 1,

						Text = if selectedDefinition
							then string.upper(selectedDefinition.RoleName)
							else string.upper(props.StationRole or ""),

						TextColor3 = roleColor,

						TextSize = 14,

						Font = Enum.Font.GothamBlack,

						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					Level = if selectedWorker
						then e("TextLabel", {
							Position = UDim2.fromOffset(20, 320),

							Size = UDim2.new(0.5, -20, 0, 25),

							BackgroundTransparency = 1,

							Text = `LEVEL {selectedWorker.Level}`,

							TextColor3 = Theme.Color.Yellow,

							TextSize = 16,

							Font = Enum.Font.GothamBlack,

							TextXAlignment = Enum.TextXAlignment.Left,
						})
						else nil,

					Temper = if selectedWorker
						then e("TextLabel", {
							AnchorPoint = Vector2.new(1, 0),

							Position = UDim2.new(1, -20, 0, 320),

							Size = UDim2.new(0.5, -20, 0, 25),

							BackgroundTransparency = 1,

							Text = `{string.upper(selectedWorker.Temper)} TEMPER`,

							TextColor3 = Theme.Color.Muted,

							TextSize = 13,

							Font = Enum.Font.GothamBold,

							TextXAlignment = Enum.TextXAlignment.Right,
						})
						else nil,

					StationMatch = if selectedDefinition
						then e("TextLabel", {
							Position = UDim2.fromOffset(20, 363),

							Size = UDim2.new(1, -40, 0, 26),

							BackgroundTransparency = 1,

							Text = `READY FOR {string.upper(props.StationRole or "")} PRODUCTION`,

							TextColor3 = Theme.Color.Muted,

							TextSize = 12,

							Font = Enum.Font.GothamBold,

							TextXAlignment = Enum.TextXAlignment.Left,
						})
						else nil,

					Message = e("TextLabel", {
						Position = UDim2.new(0, 20, 1, -126),

						Size = UDim2.new(1, -40, 0, 38),

						BackgroundTransparency = 1,

						Text = props.StatusMessage,

						TextColor3 = Theme.Color.Text,

						TextSize = 13,

						TextWrapped = true,

						Font = Enum.Font.GothamBold,
					}),

					Assign = e("Frame", {
						AnchorPoint = Vector2.new(0, 1),

						Position = UDim2.new(0, 14, 1, -14),

						Size = UDim2.new(1, -28, 0, 54),

						BackgroundTransparency = 1,
					}, {
						Button = e(Button, {
							Text = assignText,

							Color = Theme.Color.Success,

							TextColor = Theme.Color.Text,

							Disabled = not canPlace,

							OnActivated = function()
								if selectedWorker then
									props.OnPlace(selectedWorker.Id)
								end
							end,
						}),
					}),
				}),
			}),

			Close = e(CloseButton, {
				Position = UDim2.new(1, -42, 0, 42),

				ZIndex = 100,

				OnActivated = props.OnClose,
			}),
		}),
	})
end

return WorkerInventory
