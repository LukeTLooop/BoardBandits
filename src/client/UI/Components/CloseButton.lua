--!strict
-- Close Button Component

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

-- UI --
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local e = React.createElement

-- Props --
export type Props = {
	Position: UDim2,

	OnActivated: () -> (),

	ZIndex: number?,

	BaseSize: number?,
}

-- Component --
local function CloseButton(props: Props)
	local groupRef = React.useRef(nil :: Frame?)
	local buttonRef = React.useRef(nil :: TextButton?)
	local hoveredRef = React.useRef(false)

	local baseZIndex = props.ZIndex or 10

	local baseSize = props.BaseSize or 54
	local textSize = math.floor(baseSize * 0.7)
	local cornerRadius = math.floor(baseSize * 0.2)
	local strokeThickness = if baseSize <= 44 then 2 else 3
	local highlightHeight = math.max(5, math.floor(baseSize * 0.14))

	local normalSize = UDim2.fromOffset(baseSize, baseSize)
	local hoverSize = UDim2.fromOffset(baseSize + 5, baseSize + 5)
	local pressedSize = UDim2.fromOffset(baseSize - 4, baseSize - 4)

	local function animate(size: UDim2, rotation: number, color: Color3, duration: number): ()
		local group = groupRef.current

		local button = buttonRef.current

		if not group or not button then
			return
		end

		TweenService:Create(group, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = size,

			Rotation = rotation,
		}):Play()

		TweenService:Create(button, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = color,
		}):Play()
	end

	return e("Frame", {
		ref = groupRef,

		AnchorPoint = Vector2.new(0.5, 0.5),

		Position = props.Position,

		Size = normalSize,

		BackgroundTransparency = 1,

		ZIndex = baseZIndex,
	}, {
		-- Shadow is now a SIBLING of Button
		Shadow = e("Frame", {
			Position = UDim2.fromOffset(4, 5),

			Size = UDim2.fromScale(1, 1),

			BackgroundColor3 = Theme.Color.Ink,

			BackgroundTransparency = 0.18,

			BorderSizePixel = 0,

			ZIndex = baseZIndex,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, cornerRadius),
			}),
		}),

		-- Actual button
		Button = e("TextButton", {
			ref = buttonRef,

			Size = UDim2.fromScale(1, 1),

			BackgroundColor3 = Theme.Color.Danger,

			AutoButtonColor = false,

			Text = "X",

			TextColor3 = Color3.new(1, 1, 1),

			TextSize = textSize,

			Font = Enum.Font.GothamBlack,

			Selectable = true,

			ZIndex = baseZIndex + 1,

			-- Hover
			[ReactRoblox.Event.MouseEnter] = function()
				hoveredRef.current = true

				animate(hoverSize, 5, Theme.Color.Danger:Lerp(Color3.new(1, 1, 1), 0.08), 0.11)
			end,

			[ReactRoblox.Event.MouseLeave] = function()
				hoveredRef.current = false

				animate(normalSize, 0, Theme.Color.Danger, 0.11)
			end,

			-- Press
			[ReactRoblox.Event.MouseButton1Down] = function()
				animate(pressedSize, -3, Theme.Color.Danger, 0.06)
			end,

			[ReactRoblox.Event.MouseButton1Up] = function()
				if hoveredRef.current then
					animate(hoverSize, 5, Theme.Color.Danger:Lerp(Color3.new(1, 1, 1), 0.08), 0.08)
				else
					animate(normalSize, 0, Theme.Color.Danger, 0.08)
				end
			end,

			[ReactRoblox.Event.Activated] = props.OnActivated,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, cornerRadius),
			}),

			Stroke = e("UIStroke", {
				Color = Theme.Color.Ink,

				Thickness = strokeThickness,

				Transparency = 0,
			}),

			Highlight = e("Frame", {
				Position = UDim2.fromOffset(6, 5),

				Size = UDim2.new(1, -12, 0, highlightHeight),

				BackgroundColor3 = Color3.new(1, 1, 1),

				BackgroundTransparency = 0.58,

				BorderSizePixel = 0,

				ZIndex = baseZIndex + 2,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),
		}),
	})
end

return CloseButton
