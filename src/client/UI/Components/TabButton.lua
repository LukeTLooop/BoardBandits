--!strict
-- Tab Button Component

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
local NORMAL_SCALE = 1
local HOVER_SCALE = 1.055
local SELECTED_SCALE = 1.025
local SELECTED_HOVER_SCALE = 1.075
local PRESSED_SCALE = 0.97

-- Props --
export type Props = {
	Text: string,
	Selected: boolean,
	Disabled: boolean?,
	LayoutOrder: number,

	OnActivated: () -> (),
}

-- Component --
local function TabButton(props: Props)
	local disabled = props.Disabled == true

	local hovered, setHovered = React.useState(false)
	local scaleRef = React.useRef(nil :: UIScale?)
	local buttonRef = React.useRef(nil :: TextButton?)

	-- Helpers
	local function animateScale(target: number): ()
		local scale = scaleRef.current
		if not scale then
			return
		end

		TweenService:Create(scale, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = target,
		}):Play()
	end

	local function animateColor(target: Color3): ()
		local button = buttonRef.current
		if not button then
			return
		end

		TweenService:Create(button, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = target,
		}):Play()
	end

	-- Selected state changed
	React.useEffect(function()
		local targetScale = if props.Selected then SELECTED_SCALE else NORMAL_SCALE

		animateScale(targetScale)
		animateColor(if props.Selected then Theme.Color.Yellow else Theme.Color.Surface)

		return nil
	end, {
		props.Selected,
	})

	-- Render
	return e("Frame", {
		LayoutOrder = props.LayoutOrder,

		Size = UDim2.fromOffset(100, 42),

		BackgroundTransparency = 1,

		ClipsDescendants = false,
	}, {
		Button = e("TextButton", {
			ref = buttonRef,

			AnchorPoint = Vector2.new(0.5, 0.5),

			Position = UDim2.fromScale(0.5, 0.5),

			Size = UDim2.fromScale(1, 1),

			BackgroundColor3 = if props.Selected then Theme.Color.Yellow else Theme.Color.Surface,

			AutoButtonColor = false,

			Active = not disabled,

			Selectable = not disabled,

			Text = string.upper(props.Text),

			TextColor3 = if props.Selected then Theme.Color.Ink else Theme.Color.Text,

			TextSize = 13,

			TextTruncate = Enum.TextTruncate.AtEnd,

			Font = Enum.Font.GothamBold,

			[ReactRoblox.Event.MouseEnter] = function()
				if disabled then
					return
				end

				setHovered(true)

				if props.Selected then
					animateScale(SELECTED_HOVER_SCALE)
					animateColor(Theme.Color.Yellow:Lerp(Color3.new(1, 1, 1), 0.08))
				else
					animateScale(HOVER_SCALE)
					animateColor(Theme.Color.SurfaceHover)
				end
			end,

			[ReactRoblox.Event.MouseLeave] = function()
				if disabled then
					return
				end

				setHovered(false)

				animateScale(if props.Selected then SELECTED_SCALE else NORMAL_SCALE)
				animateColor(if props.Selected then Theme.Color.Yellow else Theme.Color.Surface)
			end,

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
					if props.Selected then SELECTED_HOVER_SCALE elseif hovered then HOVER_SCALE else NORMAL_SCALE
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

				Scale = if props.Selected then SELECTED_SCALE else NORMAL_SCALE,
			}),

			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 9),
			}),

			Stroke = e("UIStroke", {
				Color = if props.Selected then Theme.Color.Ink else Color3.fromRGB(47, 50, 58),

				Thickness = if props.Selected then 2 else 1,

				Transparency = if props.Selected then 0.15 else 0.45,
			}),

			-- Selection marker
			Accent = if props.Selected
				then e("Frame", {
					AnchorPoint = Vector2.new(0.5, 1),

					Position = UDim2.fromScale(0.5, 1),

					Size = UDim2.new(0.42, 0, 0, 3),

					BackgroundColor3 = Theme.Color.Ink,

					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(1, 0),
					}),
				})
				else nil,
		}),
	})
end

return TabButton
