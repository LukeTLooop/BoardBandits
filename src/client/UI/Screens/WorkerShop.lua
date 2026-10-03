--!strict
-- Worker Shop UI

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages:WaitForChild("React"))

-- Config --
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local sharedConfig = sharedFolder:WaitForChild("Config")

local WorkerConfig = require(sharedConfig:WaitForChild("WorkerConfig"))

-- Types --
local sharedTypes = sharedFolder:WaitForChild("Types")

local WorkerShopTypes = require(sharedTypes:WaitForChild("WorkerShopTypes"))

-- UI --
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local components = script.Parent.Parent:WaitForChild("Components")
local ModalBackdrop = require(components:WaitForChild("ModalBackdrop"))
local Button = require(components:WaitForChild("Button"))
local CloseButton = require(components:WaitForChild("CloseButton"))
local TabButton = require(components:WaitForChild("TabButton"))
local WorkerCard = require(components:WaitForChild("WorkerCard"))
local WorkerViewport = require(components:WaitForChild("WorkerViewport"))

local e = React.createElement

-- Hooks --
local hooks = script.Parent.Parent:WaitForChild("Hooks")
local useResponsiveScale = require(hooks:WaitForChild("useResponsiveScale"))
local useOutsideClick = require(hooks:WaitForChild("useOutsideClick"))

-- Virtual Design Resolution --
local REFERENCE_VIEWPORT = Vector2.new(1440, 900)
local WINDOW_SIZE = Vector2.new(1240, 720)

-- Types --
export type Props = {
	Visible: boolean,

	State: WorkerShopTypes.ShopState?,
	StatusMessage: string,
	Purchasing: boolean,

	OnClose: () -> (),
	OnBuy: (string) -> (),
}

-- Constants --
local ROLE_ORDER = {
	"All",
	"Bearings",
	"Trucks",
	"Wheels",
	"Decks",
	"Assembler",
}

-- Helpers --
local function getWorkerRole(definition: WorkerConfig.WorkerDefinition): string
	return definition.RoleName or definition.WorkerType
end

local function getWorkerNames(): { string }
	local names: { string } = {}

	for workerName in WorkerConfig do
		table.insert(names, workerName)
	end

	table.sort(names)

	return names
end

-- Component --
local function WorkerShop(props: Props)
	local selectedWorker, setSelectedWorker = React.useState("Gloop")
	local selectedRole, setSelectedRole = React.useState("All")

	local windowRef = React.useRef(nil :: Frame?)
	useOutsideClick(windowRef, props.Visible, props.OnClose)

	local uiScale = useResponsiveScale(REFERENCE_VIEWPORT, 0.94)

	if not props.Visible then
		return nil
	end

	local shopState = props.State

	local shopLoaded = shopState ~= nil
	local hasFactory = shopState ~= nil and shopState.HasClaimedFactory
	local progressionUnlocked = shopState ~= nil and shopState.WorkerShopUnlocked
	local shopLocked = not shopLoaded or not hasFactory or not progressionUnlocked

	-- Worker cards
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

	for _, workerName in getWorkerNames() do
		local definition = WorkerConfig[workerName]
		local role = getWorkerRole(definition)

		if selectedRole ~= "All" and role ~= selectedRole then
			continue
		end

		cardChildren[workerName] = e(WorkerCard, {
			WorkerId = workerName,
			DisplayName = definition.DisplayName,
			ModelName = definition.ModelName,
			RoleName = role,
			Rarity = definition.Rarity,
			Price = definition.Price,
			Selected = selectedWorker == workerName,
			Disabled = shopLocked,

			OnActivated = function()
				setSelectedWorker(workerName)
			end,
		})
	end

	-- Tabs
	local tabChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,

			HorizontalFlex = Enum.UIFlexAlignment.Fill,

			VerticalAlignment = Enum.VerticalAlignment.Center,

			Padding = UDim.new(0, 9),

			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, roleName in ROLE_ORDER do
		tabChildren[roleName] = e(TabButton, {
			Text = roleName,

			Selected = selectedRole == roleName,

			Disabled = shopLocked,

			LayoutOrder = index,

			OnActivated = function()
				setSelectedRole(roleName)
			end,
		})
	end

	-- Selected definition
	local definition = WorkerConfig[selectedWorker]
	if not definition then
		return nil
	end

	local role = getWorkerRole(definition)
	local roleColor = Theme.RoleColors[role] or Theme.Color.Yellow

	-- Lock message
	local lockTitle = ""
	local lockText = ""

	if not shopState then
		lockTitle = "LOADING WORKER DEPOT"
		lockText = "Checking your factory..."
	elseif not shopState.HasClaimedFactory then
		lockTitle = "CLAIM A FACTORY"
		lockText = "Claim a factory to hire workers."
	elseif not shopState.WorkerShopUnlocked then
		local remaining = math.max(shopState.RequiredPartsSold - shopState.PartsSold, 0)

		lockTitle = "WORKER DEPOT LOCKED"

		lockText = if remaining == 1
			then "Sell 1 more part to unlock workers."
			else `Sell {remaining} more parts to unlock workers.`
	else
		lockTitle = "WORKER DEPOT OPEN"
		lockText = ""
	end

	local canAfford = shopState ~= nil and shopState.Cash >= definition.Price
	local purchaseAllowed = shopState ~= nil and not shopLocked and canAfford and not props.Purchasing

	local buyButtonText: string

	if props.Purchasing then
		buyButtonText = "HIRING..."
	elseif shopLocked then
		buyButtonText = "LOCKED"
	elseif not canAfford then
		local missing = definition.Price - (if shopState then shopState.Cash else 0)

		buyButtonText = `NEED ${missing} MORE`
	else
		buyButtonText = `HIRE - ${definition.Price}`
	end

	if shopState then
		if not shopState.HasClaimedFactory then
			lockText = "CLAIM A FACTORY TO HIRE WORKERS"
		elseif not shopState.WorkerShopUnlocked then
			local remaining = math.max(shopState.RequiredPartsSold - shopState.PartsSold, 0)

			lockText = `SELL {remaining} MORE PARTS TO UNLOCK WORKERS`
		end
	end

	-- UI
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

			Header = e("Frame", {
				Position = UDim2.fromOffset(28, 20),

				Size = UDim2.fromOffset(1184, 78),

				BackgroundTransparency = 1,

				ZIndex = 100,
			}, {
				Title = e("TextLabel", {
					BackgroundTransparency = 1,

					Position = UDim2.fromOffset(0, 0),

					Size = UDim2.fromOffset(650, 46),

					Text = "WORKER DEPOT",

					TextColor3 = Theme.Color.Ink,

					TextSize = 38,

					Font = Enum.Font.GothamBlack,

					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				Subtitle = e("TextLabel", {
					BackgroundTransparency = 1,

					Position = UDim2.fromOffset(2, 45),

					Size = UDim2.fromOffset(500, 22),

					Text = "AUTOMATE THE FACTORY",

					TextColor3 = Theme.Color.SurfaceRaised,

					TextSize = 13,

					Font = Enum.Font.GothamBold,

					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				Cash = e("TextLabel", {
					BackgroundTransparency = 1,

					AnchorPoint = Vector2.new(1, 0),

					Position = UDim2.fromOffset(1095, 8),

					Size = UDim2.fromOffset(160, 42),

					Text = if shopState then `${shopState.Cash}` else "...",

					TextColor3 = Theme.Color.Ink,

					TextSize = 26,

					Font = Enum.Font.GothamBlack,

					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			}),

			Tabs = e("Frame", {
				Position = UDim2.fromOffset(28, 105),

				Size = UDim2.fromOffset(1184, 42),

				BackgroundTransparency = 1,
			}, tabChildren),

			StatusBanner = e("Frame", {
				Position = UDim2.fromOffset(28, 160),

				Size = UDim2.fromOffset(1184, 46),

				BackgroundColor3 = if shopLocked then Theme.Color.Yellow else Color3.fromRGB(226, 221, 204),

				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 10),
				}),

				Text = e("TextLabel", {
					Size = UDim2.fromScale(1, 1),

					BackgroundTransparency = 1,

					Text = string.upper(lockTitle),

					TextColor3 = Theme.Color.Ink,

					TextSize = 14,

					Font = Enum.Font.GothamBlack,
				}),
			}),

			Catalog = e("Frame", {
				Position = UDim2.fromOffset(28, 220),

				Size = UDim2.fromOffset(1184, 470),

				BackgroundTransparency = 1,
			}, {
				-- Cards
				Workers = e("ScrollingFrame", {
					Position = UDim2.fromOffset(0, 0),

					Size = UDim2.fromOffset(760, 470),

					BackgroundTransparency = 1,

					BorderSizePixel = 0,

					ScrollBarThickness = 5,

					ScrollBarImageColor3 = Theme.Color.SurfaceRaised,

					AutomaticCanvasSize = Enum.AutomaticSize.Y,

					CanvasSize = UDim2.new(),
				}, cardChildren),

				-- Divider
				Divider = e("Frame", {
					Position = UDim2.fromOffset(777, 0),

					Size = UDim2.fromOffset(3, 470),

					BackgroundColor3 = Theme.Color.Ink,

					BackgroundTransparency = 0.88,

					BorderSizePixel = 0,
				}),

				-- Details
				Details = e("Frame", {
					Position = UDim2.fromOffset(802, 0),

					Size = UDim2.fromOffset(382, 470),

					BackgroundColor3 = Theme.Color.Surface,

					ClipsDescendants = true,
				}, {
					Corner = e("UICorner", {
						CornerRadius = Theme.Corner.Large,
					}),

					RoleBar = e("Frame", {
						Size = UDim2.new(1, 0, 0, 10),

						BackgroundColor3 = roleColor,

						BorderSizePixel = 0,

						ZIndex = 2,
					}),

					-- Main content
					Content = e("Frame", {
						Position = UDim2.fromOffset(14, 20),

						Size = UDim2.new(1, -28, 1, -92),

						BackgroundTransparency = 1,
					}, {
						Padding = e("UIPadding", {
							PaddingTop = UDim.new(0, 4),

							PaddingBottom = UDim.new(0, 4),
						}),

						Layout = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Vertical,

							HorizontalAlignment = Enum.HorizontalAlignment.Left,

							VerticalAlignment = Enum.VerticalAlignment.Top,

							Padding = UDim.new(0, 5),

							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						-- Worker preview
						WorkerRender = e("Frame", {
							LayoutOrder = 1,

							Size = UDim2.fromScale(1, 0.46),

							BackgroundColor3 = Theme.Color.SurfaceRaised,
						}, {
							Corner = e("UICorner", {
								CornerRadius = UDim.new(0, 12),
							}),

							Viewport = e(WorkerViewport, {
								ModelName = definition.ModelName,

								Size = UDim2.new(1, -12, 1, -12),

								Position = UDim2.fromOffset(6, 6),
							}),
						}),

						-- Name
						Name = e("TextLabel", {
							LayoutOrder = 2,

							Size = UDim2.new(1, 0, 0, 32),

							BackgroundTransparency = 1,

							Text = string.upper(definition.DisplayName),

							TextColor3 = Theme.Color.Text,

							TextSize = 25,

							TextTruncate = Enum.TextTruncate.AtEnd,

							Font = Enum.Font.GothamBlack,

							TextXAlignment = Enum.TextXAlignment.Left,
						}),

						-- Role
						Role = e("TextLabel", {
							LayoutOrder = 3,

							Size = UDim2.new(1, 0, 0, 20),

							BackgroundTransparency = 1,

							Text = string.upper(role),

							TextColor3 = roleColor,

							TextSize = 14,

							TextTruncate = Enum.TextTruncate.AtEnd,

							Font = Enum.Font.GothamBlack,

							TextXAlignment = Enum.TextXAlignment.Left,
						}),

						-- Rarity
						Rarity = e("TextLabel", {
							LayoutOrder = 4,

							Size = UDim2.new(1, 0, 0, 18),

							BackgroundTransparency = 1,

							Text = `RARITY: {string.upper(definition.Rarity)}`,

							TextColor3 = Theme.Color.Muted,

							TextSize = 12,

							TextTruncate = Enum.TextTruncate.AtEnd,

							Font = Enum.Font.GothamBold,

							TextXAlignment = Enum.TextXAlignment.Left,
						}),

						-- Description
						Description = e("TextLabel", {
							LayoutOrder = 5,

							Size = UDim2.new(1, 0, 0, 22),

							BackgroundTransparency = 1,

							Text = `AUTOMATES ${string.upper(role)} PRODUCTION`,

							TextColor3 = Theme.Color.Muted,

							TextSize = 12,

							TextWrapped = true,

							Font = Enum.Font.GothamBold,

							TextXAlignment = Enum.TextXAlignment.Left,

							TextYAlignment = Enum.TextYAlignment.Top,
						}),

						-- Price
						Price = e("TextLabel", {
							LayoutOrder = 6,

							Size = UDim2.new(1, 0, 0, 34),

							BackgroundTransparency = 1,

							Text = `${definition.Price}`,

							TextColor3 = Theme.Color.Yellow,

							TextSize = 29,

							Font = Enum.Font.GothamBlack,

							TextXAlignment = Enum.TextXAlignment.Left,
						}),
					}),

					-- Hire button pinned to bottom
					Buy = e("Frame", {
						AnchorPoint = Vector2.new(0, 1),

						Position = UDim2.new(0, 14, 1, -14),

						Size = UDim2.new(1, -28, 0, 52),

						BackgroundTransparency = 1,
					}, {
						Button = e(Button, {
							Text = buyButtonText,

							Color = Theme.Color.Success,

							TextColor = Theme.Color.Text,

							Disabled = not purchaseAllowed,

							OnActivated = function()
								props.OnBuy(selectedWorker)
							end,
						}),
					}),
				}),
			}),

			-- Locked veil
			LockedOverlay = if shopLocked
				then e("Frame", {
					Position = UDim2.fromScale(0, 0),

					Size = UDim2.fromScale(1, 1),

					BackgroundColor3 = Color3.fromRGB(25, 28, 34),

					BackgroundTransparency = 0.43,

					BorderSizePixel = 0,

					Active = true,

					Selectable = false,

					Interactable = false,

					ZIndex = 50,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(0, 20),
					}),

					-- Unlock message
					Message = e("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),

						Position = UDim2.fromScale(0.5, 0.5),

						Size = UDim2.fromOffset(520, 140),

						BackgroundColor3 = Theme.Color.Surface,

						BorderSizePixel = 0,

						ZIndex = 51,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(0, 16),
						}),

						Stroke = e("UIStroke", {
							Color = Theme.Color.Yellow,

							Thickness = 3,
						}),

						-- Yellow accent
						Accent = e("Frame", {
							AnchorPoint = Vector2.new(0.5, 0),

							Position = UDim2.new(0.5, 0, 0, 10),

							Size = UDim2.new(1, -30, 0, 6),

							BackgroundColor3 = Theme.Color.Yellow,

							BorderSizePixel = 0,

							ZIndex = 52,
						}, {
							Corner = e("UICorner", {
								CornerRadius = UDim.new(1, 0),
							}),
						}),

						-- Title
						Title = e("TextLabel", {
							Position = UDim2.fromOffset(24, 31),

							Size = UDim2.new(1, -48, 0, 36),

							BackgroundTransparency = 1,

							Text = string.upper(lockTitle),

							TextColor3 = Theme.Color.Text,

							TextSize = 24,

							Font = Enum.Font.GothamBlack,

							ZIndex = 52,
						}),

						-- Explanation
						Description = e("TextLabel", {
							Position = UDim2.fromOffset(24, 75),

							Size = UDim2.new(1, -48, 0, 42),

							BackgroundTransparency = 1,

							Text = lockText,

							TextColor3 = Theme.Color.Muted,

							TextSize = 15,

							TextWrapped = true,

							Font = Enum.Font.GothamBold,

							ZIndex = 52,
						}),
					}),
				})
				else nil,

			Close = e(CloseButton, {
				Position = UDim2.new(1, -42, 0, 42),

				ZIndex = 100,

				OnActivated = props.OnClose,
			}),
		}),
	})
end

return WorkerShop
