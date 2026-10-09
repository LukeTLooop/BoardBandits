--!strict
-- HUD Button

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))

-- UI --
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local e = React.createElement

-- Types --
export type Props = {
	Text: string,
	Icon: string,

	Color: Color3,

	Badge: string?,

	Size: UDim2?,

	OnActivated: () -> (),
}

-- Component --
local function HUDButton(props: Props)
	local scaleRef = React.useRef(nil :: UIScale?)

	local function animate(target: number)
		local scale = scaleRef.current
		if not scale then
			return
		end

		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = target,
		}):Play()
	end

	return e("Frame", {
		Size = props.Size or UDim2.fromOffset(200, 72),

		BackgroundTransparency = 1,
	}, {
		Scale = e("UIScale", {
			ref = scaleRef,

			Scale = 1,
		}),

		Shadow = e("Frame", {
			Position = UDim2.fromOffset(5, 6),

			Size = UDim2.fromScale(1, 1),

			BackgroundColor3 = Theme.Color.Ink,

			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 14),
			}),
		}),

		Button = e("TextButton", {
			Size = UDim2.fromScale(1, 1),

			BackgroundColor3 = props.Color,

			AutoButtonColor = false,

			Text = "",

			Active = true,

			Selectable = true,

			[ReactRoblox.Event.MouseEnter] = function()
				animate(1.035)
			end,

			[ReactRoblox.Event.MouseLeave] = function()
				animate(1)
			end,

			[ReactRoblox.Event.MouseButton1Down] = function()
				animate(0.96)
			end,

			[ReactRoblox.Event.MouseButton1Up] = function()
				animate(1.035)
			end,

			[ReactRoblox.Event.Activated] = props.OnActivated,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 14),
			}),

			Stroke = e("UIStroke", {
				Color = Theme.Color.Ink,

				Thickness = 4,
			}),

			Highlight = e("Frame", {
				Position = UDim2.fromOffset(6, 5),

				Size = UDim2.new(1, -12, 0, 7),

				BackgroundColor3 = Color3.new(1, 1, 1),

				BackgroundTransparency = 0.6,

				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),

			Icon = e("ImageLabel", {
				AnchorPoint = Vector2.new(0, 0.5),

				Position = UDim2.new(0, 7, 0.5, 0),

				Size = UDim2.fromOffset(58, 58),

				BackgroundTransparency = 1,

				Image = props.Icon,

				ScaleType = Enum.ScaleType.Fit,
			}),

			Label = e("TextLabel", {
				Position = UDim2.fromOffset(69, 0),

				Size = UDim2.new(1, -77, 1, 0),

				BackgroundTransparency = 1,

				Text = string.upper(props.Text),

				TextColor3 = Color3.new(1, 1, 1),

				TextSize = 22,

				Font = Enum.Font.FredokaOne,

				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				Stroke = e("UIStroke", {
					Color = Theme.Color.Ink,

					Thickness = 3,
				}),
			}),

			Badge = if props.Badge
				then e("Frame", {
					AnchorPoint = Vector2.new(1, 0),

					Position = UDim2.new(1, 10, 0, -10),

					Size = UDim2.fromOffset(38, 38),

					BackgroundTransparency = 1,

					ZIndex = 6,
				}, {
					Shadow = e("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),

						Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(3, 4),

						Size = UDim2.fromScale(1, 1),

						BackgroundColor3 = Theme.Color.Ink,

						BackgroundTransparency = 0.18,

						BorderSizePixel = 0,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),
					}),

					Main = e("TextLabel", {
						Size = UDim2.fromScale(1, 1),

						BackgroundColor3 = Theme.Color.Danger,

						Text = props.Badge,

						TextColor3 = Color3.new(1, 1, 1),

						TextSize = 15,

						Font = Enum.Font.FredokaOne,

						ZIndex = 7,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),

						Stroke = e("UIStroke", {
							Color = Theme.Color.Ink,

							Thickness = 3,
						}),

						Highlight = e("Frame", {
							Position = UDim2.fromOffset(4, 3),

							Size = UDim2.new(1, -8, 0, 7),

							BackgroundColor3 = Color3.new(1, 1, 1),

							BackgroundTransparency = 0.55,

							BorderSizePixel = 0,

							ZIndex = 8,
						}, {
							Corner = e("UICorner", {
								CornerRadius = UDim.new(1, 0),
							}),
						}),
					}),
				})
				else nil,
		}),
	})
end

return HUDButton
