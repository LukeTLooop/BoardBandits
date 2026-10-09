--!strict
-- HUD Drawer

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages:WaitForChild("React"))

-- UI --
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local components = script.Parent.Parent:WaitForChild("Components")
local CloseButton = require(components:WaitForChild("CloseButton"))

local e = React.createElement

-- Hooks --
local hooks = script.Parent.Parent:WaitForChild("Hooks")

local useOutsideClick = require(hooks:WaitForChild("useOutsideClick"))

-- Types --
export type Props = {
	Title: string,
	Icon: string,

	AccentColor: Color3,

	Side: "Left" | "Right",

	Mobile: boolean,

	Width: number,
	Height: number,

	Content: any,

	OnClose: () -> (),
}

-- Component --
local function HUDDrawer(props: Props)
	local panelRef = React.useRef(nil :: Frame?)
	useOutsideClick(panelRef, true, props.OnClose)

	local anchorPoint = if props.Mobile
		then Vector2.new(0.5, 0.5)
		elseif props.Side == "Left" then Vector2.new(0, 0.5)
		else Vector2.new(1, 0.5)

	local position = if props.Mobile
		then UDim2.fromScale(0.5, 0.5)
		elseif props.Side == "Left" then UDim2.new(0, 18, 0.43, 0)
		else UDim2.new(1, -18, 0.43, 0)

	return e("Frame", {
		AnchorPoint = anchorPoint,

		Position = position,

		Size = UDim2.fromOffset(props.Width, props.Height),

		BackgroundTransparency = 1,

		ClipsDescendants = false,

		ZIndex = 40,
	}, {
		Shadow = e("Frame", {
			Position = UDim2.fromOffset(7, 8),

			Size = UDim2.fromScale(1, 1),

			BackgroundColor3 = Theme.Color.Ink,

			BackgroundTransparency = 0.12,

			BorderSizePixel = 0,

			ZIndex = 1,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 18),
			}),
		}),

		Panel = e("Frame", {
			ref = panelRef,

			Size = UDim2.fromScale(1, 1),

			BackgroundColor3 = Theme.Color.Cream,

			BorderSizePixel = 0,

			ClipsDescendants = true,

			ZIndex = 2,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 18),
			}),

			Stroke = e("UIStroke", {
				Color = Theme.Color.Ink,

				Thickness = 4,
			}),

			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, 70),

				BackgroundColor3 = props.AccentColor,

				BorderSizePixel = 0,

				ZIndex = 3,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 18),
				}),

				Icon = e("ImageLabel", {
					Position = UDim2.fromOffset(10, 5),

					Size = UDim2.fromOffset(58, 58),

					BackgroundTransparency = 1,

					Image = props.Icon,

					ScaleType = Enum.ScaleType.Fit,

					ZIndex = 4,
				}),

				Title = e("TextLabel", {
					Position = UDim2.fromOffset(72, 0),

					Size = UDim2.new(1, -120, 1, 0),

					BackgroundTransparency = 1,

					Text = string.upper(props.Title),

					TextColor3 = Color3.new(1, 1, 1),

					TextSize = 25,

					Font = Enum.Font.FredokaOne,

					TextXAlignment = Enum.TextXAlignment.Left,

					ZIndex = 4,
				}, {
					Stroke = e("UIStroke", {
						Color = Theme.Color.Ink,

						Thickness = 3,
					}),
				}),
			}),

			Content = e("Frame", {
				Position = UDim2.fromOffset(12, 82),

				Size = UDim2.new(1, -24, 1, -94),

				BackgroundTransparency = 1,

				ZIndex = 3,
			}, {
				Content = props.Content,
			}),
		}),

		Close = e(CloseButton, {
			Position = UDim2.new(1, -32, 0, 32),

			BaseSize = 47,

			ZIndex = 55,

			OnActivated = props.OnClose,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),

			Stroke = e("UIStroke", {
				Color = Theme.Color.Ink,

				Thickness = 3,
			}),
		}),
	})
end

return HUDDrawer
