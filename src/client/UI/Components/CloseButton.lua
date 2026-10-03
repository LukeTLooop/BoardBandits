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

-- Constants --
local NORMAL_SIZE = UDim2.fromOffset(54, 54)
local HOVER_SIZE = UDim2.fromOffset(60, 60)
local PRESSED_SIZE = UDim2.fromOffset(49, 49)

-- Props --
export type Props = {
	Position: UDim2,

	OnActivated: () -> (),

	ZIndex: number?,
}

-- Component --
local function CloseButton(props: Props)
	local buttonRef = React.useRef(nil :: TextButton?)
	local hoveredRef = React.useRef(false)

	local function animate(size: UDim2, rotation: number, color: Color3, duration: number): ()
		local button = buttonRef.current
		if not button then
			return
		end

		TweenService:Create(button, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = size,
			Rotation = rotation,
			BackgroundColor3 = color,
		}):Play()
	end

	return e("TextButton", {
		ref = buttonRef,

		AnchorPoint = Vector2.new(0.5, 0.5),

		Position = props.Position,

		Size = NORMAL_SIZE,

		BackgroundColor3 = Theme.Color.Danger,

		AutoButtonColor = false,

		Text = "X",

		TextColor3 = Theme.Color.Text,

		TextSize = 38,

		Font = Enum.Font.GothamBlack,

		ZIndex = props.ZIndex or 10,

		-- Hover
		[ReactRoblox.Event.MouseEnter] = function()
			hoveredRef.current = true

			animate(HOVER_SIZE, 5, Theme.Color.Danger:Lerp(Color3.new(1, 1, 1), 0.08), 0.11)
		end,

		[ReactRoblox.Event.MouseLeave] = function()
			hoveredRef.current = false

			animate(NORMAL_SIZE, 0, Theme.Color.Danger, 0.11)
		end,

		-- Press
		[ReactRoblox.Event.MouseButton1Down] = function()
			animate(PRESSED_SIZE, -3, Theme.Color.Danger, 0.06)
		end,

		[ReactRoblox.Event.MouseButton1Up] = function()
			if hoveredRef.current then
				animate(HOVER_SIZE, 5, Theme.Color.Danger:Lerp(Color3.new(1, 1, 1), 0.08), 0.08)
			else
				animate(NORMAL_SIZE, 0, Theme.Color.Danger, 0.08)
			end
		end,

		-- Activate
		[ReactRoblox.Event.Activated] = props.OnActivated,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 11),
		}),

		Stroke = e("UIStroke", {
			Color = Theme.Color.Ink,

			Thickness = 2,

			Transparency = 0.15,
		}),
	})
end

return CloseButton
