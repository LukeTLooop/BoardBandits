--!strict
-- Owned Worker Card Component

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

-- Config --
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local sharedConfig = sharedFolder:WaitForChild("Config")

local WorkerConfig = require(sharedConfig:WaitForChild("WorkerConfig"))

-- Types --
local sharedTypes = sharedFolder:WaitForChild("Types")

local WorkerTypes = require(sharedTypes:WaitForChild("WorkerTypes"))

-- UI --
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local components = script.Parent.Parent:WaitForChild("Components")
local WorkerViewport = require(components:WaitForChild("WorkerViewport"))

local e = React.createElement

-- Constants --
local NORMAL_SCALE = 1
local SELECTED_SCALE = 1.02
local HOVER_SCALE = 1.035
local SELECTED_HOVER_SCALE = 1.05
local PRESSED_SCALE = 0.975

-- Types --
export type Props = {
	Worker: WorkerTypes.ClientWorkerData,
	LayoutOrder: number,
	Selected: boolean,
	FiltersActive: boolean,
	FilterMatches: boolean,
	FilterLabel: string?,
	Disabled: boolean?,

	OnActivated: () -> (),
}

-- Component --
local function OwnedWorkerCard(props: Props)
	local worker = props.Worker
	local disabled = props.Disabled == true

	local hovered = React.useRef(false)
	local scaleRef = React.useRef(nil :: UIScale?)

	local definition = WorkerConfig[worker.WorkerType]
	if not definition then
		return nil
	end

	local roleName = definition.RoleName
	local roleColor = Theme.RoleColors[roleName] or Theme.Color.Yellow

	-- Animation
	local function animateScale(target: number): ()
		local scale = scaleRef.current
		if not scale then
			return
		end

		TweenService:Create(scale, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = target,
		}):Play()
	end

	React.useEffect(function()
		if disabled then
			animateScale(NORMAL_SCALE)

			return nil
		end

		animateScale(if props.Selected then SELECTED_SCALE else NORMAL_SCALE)

		return nil
	end, {
		props.Selected,
		disabled,
	})

	-- Render
	return e("Frame", {
		LayoutOrder = props.LayoutOrder,

		BackgroundTransparency = 1,

		ClipsDescendants = false,
	}, {
		e("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),

			Position = UDim2.fromScale(0.5, 0.5),

			Size = UDim2.fromScale(1, 1),

			BackgroundColor3 = if props.Selected and not disabled
				then Theme.Color.SurfaceSelected
				else Theme.Color.Surface,

			BackgroundTransparency = if disabled then 0.2 else 0,

			AutoButtonColor = false,

			Active = not disabled,

			Selectable = not disabled,

			Text = "",

			-- Hover
			[ReactRoblox.Event.MouseEnter] = function()
				if disabled then
					return
				end

				hovered.current = true

				animateScale(if props.Selected then SELECTED_HOVER_SCALE else HOVER_SCALE)
			end,

			[ReactRoblox.Event.MouseLeave] = function()
				if disabled then
					return
				end

				hovered.current = false

				animateScale(if props.Selected then SELECTED_SCALE else NORMAL_SCALE)
			end,

			-- Click
			[ReactRoblox.Event.MouseButton1Down] = function()
				if disabled then
					return
				end

				animateScale(PRESSED_SCALE)
			end,

			[ReactRoblox.Event.MouseButton1Up] = function()
				if disabled then
					return
				end

				animateScale(
					if props.Selected then SELECTED_HOVER_SCALE elseif hovered.current then HOVER_SCALE else NORMAL_SCALE
				)
			end,

			[ReactRoblox.Event.Activated] = function()
				if disabled then
					return
				end

				if props.OnActivated then
					props.OnActivated()
				end
			end,
		}, {
			Scale = e("UIScale", {
				ref = scaleRef,

				Scale = if props.Selected and not disabled then SELECTED_SCALE else NORMAL_SCALE,
			}),

			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 14),
			}),

			Stroke = e("UIStroke", {
				Color = if props.Selected and not disabled then roleColor else Color3.fromRGB(47, 50, 58),

				Thickness = if props.Selected and not disabled then 4 else 2,

				Transparency = if props.Selected and not disabled then 0.7 else 0,
			}),

			RoleBar = e("Frame", {
				Size = UDim2.new(1, 0, 0, 10),

				BackgroundColor3 = roleColor,

				BackgroundTransparency = if disabled then 0.6 else 0,

				BorderSizePixel = 0,
			}),

			-- Worker
			Worker = e("Frame", {
				Position = UDim2.fromOffset(12, 16),

				Size = UDim2.new(1, -24, 0, 120),

				BackgroundTransparency = 1,
			}, {
				Viewport = e(WorkerViewport, {
					ModelName = definition.ModelName,
				}),
			}),

			Name = e("TextLabel", {
				BackgroundTransparency = 1,

				Position = UDim2.fromOffset(14, 138),

				Size = UDim2.new(1, -28, 0, 30),

				Text = string.upper(definition.DisplayName),

				TextColor3 = if disabled then Theme.Color.DisabledText else Theme.Color.Text,

				TextSize = 20,

				Font = Enum.Font.GothamBlack,

				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Role = e("TextLabel", {
				BackgroundTransparency = 1,

				Position = UDim2.fromOffset(14, 169),

				Size = UDim2.new(1, -28, 0, 20),

				Text = string.upper(roleName),

				TextColor3 = if disabled then Theme.Color.DisabledText else roleColor,

				TextSize = 12,

				Font = Enum.Font.GothamBlack,

				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Level = e("TextLabel", {
				BackgroundTransparency = 1,

				Position = UDim2.new(0, 14, 1, -42),

				Size = UDim2.new(0.5, -14, 0, 26),

				Text = `LV.{worker.Level}`,

				TextColor3 = if disabled then Theme.Color.DisabledText else Theme.Color.Text,

				TextSize = 15,

				Font = Enum.Font.GothamBlack,

				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Temper = e("TextLabel", {
				BackgroundTransparency = 1,

				AnchorPoint = Vector2.new(1, 0),

				Position = UDim2.new(1, -14, 1, -42),

				Size = UDim2.new(0.5, -14, 0, 26),

				Text = string.upper(worker.Temper),

				TextColor3 = Theme.Color.Muted,

				TextSize = 11,

				Font = Enum.Font.GothamBold,

				TextXAlignment = Enum.TextXAlignment.Right,
			}),

			-- Disabled overlay
			DisabledOverlay = if disabled
				then e("Frame", {
					Size = UDim2.fromScale(1, 1),

					BackgroundColor3 = Theme.Color.Background,

					BackgroundTransparency = 0.48,

					BorderSizePixel = 0,

					ZIndex = 10,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(0, 14),
					}),

					Message = e("TextLabel", {
						AnchorPoint = Vector2.new(0.5, 0.5),

						Position = UDim2.fromScale(0.5, 0.5),

						Size = UDim2.new(1, -24, 0, 28),

						BackgroundColor3 = Theme.Color.Surface,

						BackgroundTransparency = 0.08,

						Text = "WRONG STATION",

						TextColor3 = Theme.Color.DisabledText,

						TextSize = 12,

						Font = Enum.Font.GothamBlack,

						ZIndex = 11,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(0, 8),
						}),
					}),
				})
				else nil,

			Selected = if props.Selected and not disabled
				then e("TextLabel", {
					AnchorPoint = Vector2.new(1, 0),

					Position = UDim2.new(1, -10, 0, 15),

					Size = UDim2.fromOffset(72, 22),

					BackgroundColor3 = roleColor,

					Text = "SELECTED",

					TextColor3 = Theme.Color.Ink,

					TextSize = 9,

					Font = Enum.Font.GothamBlack,

					ZIndex = 12,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(1, 0),
					}),
				})
				else nil,

			FilterHighlight = if props.FiltersActive
					and props.FilterMatches
					and not disabled
				then e("Frame", {
					Size = UDim2.fromScale(1, 1),

					BackgroundTransparency = 1,

					ZIndex = 20,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(0, 14),
					}),

					Stroke = e("UIStroke", {
						Color = Theme.Color.Yellow,

						Thickness = 3,

						Transparency = 0.1,
					}),

					Badge = e("TextLabel", {
						AnchorPoint = Vector2.new(1, 0),

						Position = UDim2.new(1, -10, 0, 42),

						Size = UDim2.fromOffset(90, 22),

						BackgroundColor3 = Theme.Color.Yellow,

						Text = props.FilterLabel or "MATCH",

						TextColor3 = Theme.Color.Ink,

						TextSize = 9,

						Font = Enum.Font.GothamBlack,

						ZIndex = 21,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),
					}),
				})
				else nil,

			FilterNonMatch = if props.FiltersActive
					and not props.FilterMatches
					and not disabled
				then e("Frame", {
					Size = UDim2.fromScale(1, 1),

					BackgroundColor3 = Theme.Color.Background,

					BackgroundTransparency = 0.82,

					BorderSizePixel = 0,

					ZIndex = 15,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(0, 14),
					}),
				})
				else nil,
		}),
	})
end

return OwnedWorkerCard
