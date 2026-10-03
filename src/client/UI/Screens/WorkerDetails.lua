--!strict
-- Worker Details Gui Screen

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)

-- Config --
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local sharedConfig = sharedFolder:WaitForChild("Config")

local WorkerConfig = require(sharedConfig:WaitForChild("WorkerConfig"))
local ItemConfig = require(sharedConfig:WaitForChild("ItemConfig"))
local RecipeConfig = require(sharedConfig:WaitForChild("RecipeConfig"))

-- Types --
local sharedTypes = sharedFolder:WaitForChild("Types")

local WorkerDetailsTypes = require(sharedTypes:WaitForChild("WorkerDetailsTypes"))

-- UI --
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local components = script.Parent.Parent:WaitForChild("Components")
local Button = require(components:WaitForChild("Button"))
local CloseButton = require(components:WaitForChild("CloseButton"))
local WorkerViewport = require(components:WaitForChild("WorkerViewport"))
local ModalBackdrop = require(components:WaitForChild("ModalBackdrop"))

local e = React.createElement

-- Hooks --
local hooks = script.Parent.Parent:WaitForChild("Hooks")

local useResponsiveScale = require(hooks:WaitForChild("useResponsiveScale"))
local useOutsideClick = require(hooks:WaitForChild("useOutsideClick"))

-- Constants --
local REFERENCE_VIEWPORT = Vector2.new(1440, 900)
local WINDOW_SIZE = Vector2.new(1240, 720)

-- Props --
export type Props = {
	Visible: boolean,
	Data: WorkerDetailsTypes.DetailsData?,
	Busy: boolean,
	StatusMessage: string,

	OnClose: () -> (),
	OnUpgrade: () -> (),
	OnRemove: () -> (),
}

type ProductionInfo = {
	CurrentName: string,
	CurrentInterval: number?,
	NextName: string?,
	NextLevel: number?,
}

-- Helpers --
local function getProductionInfo(workerType: string, level: number): ProductionInfo
	local definition = WorkerConfig[workerType]
	if not definition then
		return {
			CurrentName = "UNKNOWN",

			CurrentInterval = nil,

			NextName = nil,

			NextLevel = nil,
		}
	end

	-- Producer
	if definition.WorkerType == "Producer" then
		local currentItem: string? = nil
		local nextItem: string? = nil
		local nextLevel: number? = nil

		for _, entry in definition.OutputProgression do
			if entry.RequiredLevel <= level then
				currentItem = entry.Item
			elseif not nextLevel then
				nextItem = entry.Item
				nextLevel = entry.RequiredLevel
			end
		end

		local currentDefinition = if currentItem then ItemConfig[currentItem] else nil

		local nextDefinition = if nextItem then ItemConfig[nextItem] else nil

		return {
			CurrentName = if currentDefinition then currentDefinition.DisplayName else currentItem or "UNKNOWN",

			CurrentInterval = definition.ProductionInterval,

			NextName = if nextDefinition then nextDefinition.DisplayName else nextItem,

			NextLevel = nextLevel,
		}
	end

	-- Assembler
	local currentRecipe: string? = nil
	local nextRecipe: string? = nil
	local nextLevel: number? = nil

	for _, entry in definition.RecipeProgression do
		if entry.RequiredLevel <= level then
			currentRecipe = entry.Recipe
		elseif not nextLevel then
			nextRecipe = entry.Recipe
			nextLevel = entry.RequiredLevel
		end
	end

	local currentRecipeDefinition = if currentRecipe then RecipeConfig[currentRecipe] else nil

	local nextRecipeDefinition = if nextRecipe then RecipeConfig[nextRecipe] else nil

	local currentOutputDefinition = if currentRecipeDefinition
		then ItemConfig[currentRecipeDefinition.OutputItem]
		else nil

	local nextOutputDefinition = if nextRecipeDefinition then ItemConfig[nextRecipeDefinition.OutputItem] else nil

	return {
		CurrentName = if currentOutputDefinition
			then currentOutputDefinition.DisplayName
			else currentRecipe or "UNKNOWN",

		CurrentInterval = if currentRecipeDefinition then currentRecipeDefinition.ProductionInterval else nil,

		NextName = if nextOutputDefinition then nextOutputDefinition.DisplayName else nextRecipe,

		NextLevel = nextLevel,
	}
end

-- Component --
local function WorkerDetails(props: Props)
	local uiScale = useResponsiveScale(REFERENCE_VIEWPORT, 0.94)

	local windowRef = React.useRef(nil :: Frame?)
	useOutsideClick(windowRef, props.Visible, props.OnClose)

	local levelFillRef = React.useRef(nil :: Frame?)
	local levelTextScaleRef = React.useRef(nil :: UIScale?)

	local previousProgressRef = React.useRef(0)
	local previousLevelRef = React.useRef(-1)
	local initializedLevelRef = React.useRef(false)

	-- Loading
	local data = props.Data

	local currentLevel = if data then data.Level else 0
	local maxLevel = if data then math.max(data.Upgrade.MaxLevel, 1) else 1

	local levelProgress = math.clamp(currentLevel / maxLevel, 0, 1)

	-- Outside click hook
	useOutsideClick(windowRef, props.Visible, props.OnClose)

	-- Level animation
	React.useEffect(function()
		if not data then
			return nil
		end

		local fill = levelFillRef.current

		-- Data render
		if not initializedLevelRef.current then
			initializedLevelRef.current = true
			previousLevelRef.current = levelProgress
			previousLevelRef.current = data.Level

			if fill then
				fill.Size = UDim2.fromScale(levelProgress, 1)
			end

			return nil
		end

		-- Level change
		local previousProgress = previousProgressRef.current
		local previousLevel = previousLevelRef.current
		local levelChanged = previousLevel ~= data.Level

		if fill and levelChanged then
			fill.Size = UDim2.fromScale(previousProgress, 1)

			TweenService:Create(fill, TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(levelProgress, 1),
			}):Play()
		end

		-- Level text pulse
		if levelChanged then
			local textScale = levelTextScaleRef.current
			if textScale then
				textScale.Scale = 1

				local grow = TweenService:Create(
					textScale,
					TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{
						Scale = 1.16,
					}
				)

				local settle = TweenService:Create(
					textScale,
					TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Scale = 1,
					}
				)

				grow.Completed:Once(function()
					settle:Play()
				end)

				grow:Play()
			end
		end

		-- Track new state
		previousProgressRef.current = levelProgress
		previousLevelRef.current = data.Level

		return nil
	end, {
		currentLevel,
		maxLevel,
	})

	if not props.Visible then
		return nil
	end

	if not data then
		return e("Frame", {
			Size = UDim2.fromScale(1, 1),

			BackgroundTransparency = 1,
		}, {
			Backdrop = e(ModalBackdrop),

			Loading = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),

				Position = UDim2.fromScale(0.5, 0.5),

				Size = UDim2.fromOffset(520, 130),

				BackgroundColor3 = Theme.Color.Surface,
			}, {
				Scale = e("UIScale", {
					Scale = uiScale,
				}),

				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 16),
				}),

				Text = e("TextLabel", {
					Size = UDim2.fromScale(1, 1),

					BackgroundTransparency = 1,

					Text = "LOADING WORKER...",

					TextColor3 = Theme.Color.Text,

					TextSize = 24,

					Font = Enum.Font.GothamBlack,
				}),
			}),
		})
	end

	local definition = WorkerConfig[data.WorkerType]
	if not definition then
		return nil
	end

	local roleName = definition.RoleName
	local roleColor = Theme.RoleColors[roleName] or Theme.Color.Yellow

	local production = getProductionInfo(data.WorkerType, data.Level)

	-- Upgrade button
	local upgradeText: string

	if props.Busy then
		upgradeText = "UPGRADING..."
	elseif data.Upgrade.BlockedReason == "MaxLevel" then
		upgradeText = "MAX LEVEL"
	elseif data.Upgrade.BlockedReason == "NotEnoughCash" then
		local cost = data.Upgrade.UpgradeCost or 0
		local missing = math.max(cost - data.Upgrade.Cash, 0)

		upgradeText = `NEED ${missing} MORE`
	elseif not data.Upgrade.UpgradeCost then
		upgradeText = "UPGRADE UNAVAILABLE"
	else
		upgradeText = `UPGRADE - ${data.Upgrade.UpgradeCost}`
	end

	local canUpgrade = data.Upgrade.CanUpgrade and not props.Busy

	-- Next output
	local nextOutputText = if production.NextName and production.NextLevel
		then `{string.upper(production.NextName)}`
		else "MAX PRODUCTION TIER"

	-- Render
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),

		BackgroundTransparency = 1,
	}, {
		-- Backdrop
		Backdrop = e(ModalBackdrop),

		-- Main Gui
		Window = e("Frame", {
			ref = windowRef,

			AnchorPoint = Vector2.new(0.5, 0.5),

			Position = UDim2.fromScale(0.5, 0.5),

			Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),

			BackgroundColor3 = Theme.Color.Cream,

			ClipsDescendants = true,

			ZIndex = 2,
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
				Position = UDim2.fromOffset(20, 20),

				Size = UDim2.fromOffset(1184, 78),

				BackgroundTransparency = 1,
			}, {
				Name = e("TextLabel", {
					BackgroundTransparency = 1,

					Position = UDim2.fromOffset(0, 0),

					Size = UDim2.fromOffset(700, 46),

					Text = string.upper(definition.DisplayName),

					TextColor3 = Theme.Color.Ink,

					TextSize = 38,

					Font = Enum.Font.GothamBlack,

					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				Role = e("TextLabel", {
					BackgroundTransparency = 1,

					Position = UDim2.fromOffset(2, 45),

					Size = UDim2.fromOffset(500, 22),

					Text = string.upper(roleName),

					TextColor3 = roleColor,

					TextSize = 13,

					Font = Enum.Font.GothamBlack,

					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				Cash = e("TextLabel", {
					AnchorPoint = Vector2.new(1, 0),

					Position = UDim2.fromOffset(1090, 9),

					Size = UDim2.fromOffset(100, 38),

					BackgroundTransparency = 1,

					Text = `${data.Upgrade.Cash}`,

					TextColor3 = Theme.Color.Ink,

					TextSize = 25,

					Font = Enum.Font.GothamBlack,

					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			}),

			-- Status bar
			Status = e("Frame", {
				Position = UDim2.fromOffset(28, 105),

				Size = UDim2.fromOffset(1184, 54),

				BackgroundColor3 = Theme.Color.Surface,

				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 10),
				}),

				Level = e("TextLabel", {
					BackgroundTransparency = 1,

					Position = UDim2.fromOffset(18, 0),

					Size = UDim2.fromOffset(190, 54),

					Text = `LEVEL {data.Level} / {maxLevel}`,

					TextColor3 = Theme.Color.Text,

					TextSize = 16,

					Font = Enum.Font.GothamBlack,

					TextXAlignment = Enum.TextXAlignment.Left,
				}, {
					Scale = e("UIScale", {
						ref = levelTextScaleRef,

						Scale = 1,
					}),
				}),

				Temper = e("TextLabel", {
					BackgroundTransparency = 1,

					Position = UDim2.fromOffset(220, 0),

					Size = UDim2.fromOffset(220, 54),

					Text = `{string.upper(data.Temper)} TEMPER`,

					TextColor3 = Theme.Color.Yellow,

					TextSize = 14,

					Font = Enum.Font.GothamBlack,
				}),

				-- Level bar
				LevelTrack = e("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),

					Position = UDim2.new(1, -18, 0.5, 0),

					Size = UDim2.fromOffset(560, 14),

					BackgroundColor3 = Theme.Color.SurfaceRaised,

					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(1, 0),
					}),

					Fill = e("Frame", {
						ref = levelFillRef,

						Size = UDim2.fromScale(levelProgress, 1),

						BackgroundColor3 = roleColor,

						BorderSizePixel = 0,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),
					}),
				}),
			}),

			-- Main area
			Content = e("Frame", {
				Position = UDim2.fromOffset(28, 177),

				Size = UDim2.fromOffset(1184, 515),

				BackgroundTransparency = 1,
			}, {
				-- Left worker showcase
				WorkerPanel = e("Frame", {
					Size = UDim2.fromOffset(430, 515),

					BackgroundColor3 = Theme.Color.Surface,

					ClipsDescendants = true,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(0, 16),
					}),

					RoleBar = e("Frame", {
						Size = UDim2.new(1, 0, 0, 12),

						BackgroundColor3 = roleColor,

						BorderSizePixel = 0,
					}),

					ViewportBackground = e("Frame", {
						Position = UDim2.fromOffset(18, 28),

						Size = UDim2.fromOffset(394, 335),

						BackgroundColor3 = Theme.Color.SurfaceRaised,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(0, 14),
						}),

						Viewport = e(WorkerViewport, {
							ModelName = definition.ModelName,
						}),
					}),

					Name = e("TextLabel", {
						Position = UDim2.fromOffset(20, 383),

						Size = UDim2.new(1, -40, 0, 38),

						BackgroundTransparency = 1,

						Text = string.upper(definition.DisplayName),

						TextColor3 = Theme.Color.Text,

						TextSize = 28,

						Font = Enum.Font.GothamBlack,

						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					Role = e("TextLabel", {
						Position = UDim2.fromOffset(20, 423),

						Size = UDim2.new(1, -40, 0, 22),

						BackgroundTransparency = 1,

						Text = string.upper(roleName),

						TextColor3 = roleColor,

						TextSize = 13,

						Font = Enum.Font.GothamBlack,

						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					Temper = e("TextLabel", {
						Position = UDim2.fromOffset(20, 456),

						Size = UDim2.new(1, -40, 0, 24),

						BackgroundTransparency = 1,

						Text = `TEMPER: {string.upper(data.Temper)}`,

						TextColor3 = Theme.Color.Muted,

						TextSize = 12,

						Font = Enum.Font.GothamBlack,

						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				}),

				-- Right information
				Info = e("Frame", {
					Position = UDim2.fromOffset(450, 0),

					Size = UDim2.fromOffset(734, 515),

					BackgroundTransparency = 1,
				}, {
					-- Current output
					Current = e("Frame", {
						Size = UDim2.fromOffset(352, 175),

						BackgroundColor3 = Theme.Color.Surface,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(0, 14),
						}),

						Label = e("TextLabel", {
							Position = UDim2.fromOffset(18, 16),

							Size = UDim2.new(1, -36, 0, 22),

							BackgroundTransparency = 1,

							Text = "CURRENT OUTPUT",

							TextColor3 = Theme.Color.Muted,

							TextSize = 14,

							Font = Enum.Font.GothamBlack,

							TextXAlignment = Enum.TextXAlignment.Left,
						}),

						Value = e("TextLabel", {
							Position = UDim2.fromOffset(18, 48),

							Size = UDim2.new(1, -36, 0, 68),

							BackgroundTransparency = 1,

							Text = string.upper(production.CurrentName),

							TextColor3 = roleColor,

							TextSize = 30,

							TextWrapped = true,

							Font = Enum.Font.GothamBlack,

							TextXAlignment = Enum.TextXAlignment.Left,

							TextYAlignment = Enum.TextYAlignment.Top,
						}),

						Interval = e("TextLabel", {
							Position = UDim2.new(0, 18, 1, -52),

							Size = UDim2.new(1, -36, 0, 30),

							BackgroundTransparency = 1,

							Text = if production.CurrentInterval
								then `⚙  EVERY {production.CurrentInterval} SECONDS`
								else "",

							TextColor3 = Theme.Color.Text,

							TextSize = 15,

							Font = Enum.Font.GothamBlack,

							TextXAlignment = Enum.TextXAlignment.Left,
						}),
					}),

					-- Next unlock
					Info = e("Frame", {
						Position = UDim2.fromOffset(370, 0),

						Size = UDim2.fromOffset(364, 175),

						BackgroundColor3 = Theme.Color.Surface,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(0, 14),
						}),

						Label = e("TextLabel", {
							Position = UDim2.fromOffset(18, 16),

							Size = UDim2.new(1, -36, 0, 22),

							BackgroundTransparency = 1,

							Text = "NEXT UNLOCK",

							TextColor3 = Theme.Color.Muted,

							TextSize = 12,

							Font = Enum.Font.GothamBlack,

							TextXAlignment = Enum.TextXAlignment.Left,
						}),

						Value = e("TextLabel", {
							Position = UDim2.fromOffset(18, 50),

							Size = UDim2.new(1, -36, 0, 55),

							BackgroundTransparency = 1,

							Text = nextOutputText,

							TextColor3 = if production.NextName then roleColor else Theme.Color.Muted,

							TextSize = 22,

							TextWrapped = true,

							Font = Enum.Font.GothamBlack,

							TextXAlignment = Enum.TextXAlignment.Left,

							TextYAlignment = Enum.TextYAlignment.Top,
						}),

						UnlockBadge = e("TextLabel", {
							Position = UDim2.new(0, 18, 1, -54),

							Size = UDim2.fromOffset(180, 30),

							BackgroundColor3 = if production.NextLevel then roleColor else Theme.Color.SurfaceRaised,

							Text = if production.NextLevel then `UNLOCKS AT LV.{production.NextLevel}` else "MAX TIER",

							TextColor3 = if production.NextLevel then Theme.Color.Ink else Theme.Color.Muted,

							TextSize = 12,

							Font = Enum.Font.GothamBlack,
						}, {
							Corner = e("UICorner", {
								CornerRadius = UDim.new(1, 0),
							}),
						}),
					}),

					-- Upgrade information
					UpgradeInfo = e("Frame", {
						Position = UDim2.fromOffset(0, 195),

						Size = UDim2.fromOffset(734, 125),

						BackgroundColor3 = Theme.Color.Surface,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(0, 14),
						}),

						Title = e("TextLabel", {
							Position = UDim2.fromOffset(18, 14),

							Size = UDim2.new(0.5, -18, 0, 24),

							BackgroundTransparency = 1,

							Text = "WORKER UPGRADE",

							TextColor3 = Theme.Color.Text,

							TextSize = 15,

							Font = Enum.Font.GothamBlack,

							TextXAlignment = Enum.TextXAlignment.Left,
						}),

						Level = e("TextLabel", {
							Position = UDim2.fromOffset(18, 52),

							Size = UDim2.new(0.5, -18, 0, 28),

							BackgroundTransparency = 1,

							Text = if data.Level >= maxLevel
								then `LEVEL {data.Level} / {maxLevel}`
								else `LEVEL {data.Level} -> {data.Level + 1}`,

							TextColor3 = if data.Level >= maxLevel then roleColor else Theme.Color.Yellow,

							TextSize = 30,

							Font = Enum.Font.GothamBlack,

							TextXAlignment = Enum.TextXAlignment.Left,
						}),

						CostLabel = if data.Upgrade.UpgradeCost
							then e("TextLabel", {
								AnchorPoint = Vector2.new(1, 0),

								Position = UDim2.new(1, -18, 0, 22),

								Size = UDim2.fromOffset(200, 20),

								BackgroundTransparency = 1,

								Text = "UPGRADE COST",

								TextColor3 = Theme.Color.Muted,

								TextSize = 11,

								Font = Enum.Font.GothamBlack,

								TextXAlignment = Enum.TextXAlignment.Right,
							})
							else nil,

						Cost = e("TextLabel", {
							AnchorPoint = Vector2.new(1, 0),

							Position = UDim2.new(1, -18, 0, 47),

							Size = UDim2.fromOffset(200, 38),

							BackgroundTransparency = 1,

							Text = if data.Upgrade.UpgradeCost then `${data.Upgrade.UpgradeCost}` else "MAX",

							TextColor3 = if canUpgrade then Theme.Color.Success else Theme.Color.DisabledText,

							TextSize = 27,

							Font = Enum.Font.GothamBlack,

							TextXAlignment = Enum.TextXAlignment.Right,
						}),
					}),

					-- Status
					Message = e("TextLabel", {
						Position = UDim2.fromOffset(10, 337),

						Size = UDim2.new(1, -20, 0, 34),

						BackgroundTransparency = 1,

						Text = props.StatusMessage,

						TextColor3 = Theme.Color.Ink,

						TextSize = 13,

						Font = Enum.Font.GothamBold,
					}),

					-- Upgrade button
					Upgrade = e("Frame", {
						Position = UDim2.fromOffset(0, 380),

						Size = UDim2.fromOffset(734, 58),

						BackgroundTransparency = 1,
					}, {
						Button = e(Button, {
							Text = upgradeText,

							Color = Theme.Color.Success,

							TextColor = Theme.Color.Text,

							Disabled = not canUpgrade,

							OnActivated = props.OnUpgrade,
						}),
					}),

					-- Remove button
					Remove = e("Frame", {
						Position = UDim2.fromOffset(0, 452),

						Size = UDim2.fromOffset(734, 50),

						BackgroundTransparency = 1,
					}, {
						Button = e(Button, {
							Text = if props.Busy then "PLEASE WAIT..." else "REMOVE FROM STATION",

							Color = Theme.Color.Danger,

							TextColor = Theme.Color.Text,

							Disabled = props.Busy,

							OnActivated = props.OnRemove,
						}),
					}),
				}),
			}),

			-- Close
			Close = e(CloseButton, {
				Position = UDim2.new(1, -42, 0, 42),

				ZIndex = 100,

				OnActivated = props.OnClose,
			}),
		}),
	})
end

return WorkerDetails
