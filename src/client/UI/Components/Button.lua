--!strict
-- UI Button

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

-- Constants --
local NORMAL_SCALE = 1
local HOVER_SCALE = 1.045
local PRESSED_SCALE = 0.97

-- Types --
export type Props = {
	Text: string,
	Color: Color3?,
	TextColor: Color3?,
	Disabled: boolean?,

	OnActivated: (() -> ())?,
}

-- Component --
local function Button(props: Props)
	local disabled = props.Disabled == true

	local buttonRef = React.useRef(nil :: TextButton?)
	local scaleRef = React.useRef(nil :: UIScale?)
	local hoveredRef = React.useRef(false)

	local baseColor = props.Color or Theme.Color.Yellow

	-- Animate
	local function animateScale(target: number): ()
		local scale = scaleRef.current
		if not scale then
			return
		end

		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = target,
		}):Play()
	end

	local function animateColor(target: Color3): ()
		local button = buttonRef.current
		if not button then
			return
		end

		TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = target,
		}):Play()
	end

	-- Reset visual state on disabled
	React.useEffect(function()
		hoveredRef.current = false

		animateScale(NORMAL_SCALE)
		animateColor(if disabled then Theme.Color.Disabled else baseColor)

		return nil
	end, {
		disabled,
		baseColor,
	})

	-- Render
	return e("TextButton", {
		ref = buttonRef,

		AnchorPoint = Vector2.new(0.5, 0.5),

		Position = UDim2.fromScale(0.5, 0.5),

		Size = UDim2.fromScale(1, 1),

		BackgroundColor3 = if disabled then Theme.Color.Disabled else baseColor,

		AutoButtonColor = false,

		Active = not disabled,

		Selectable = not disabled,

		Text = props.Text,

		TextColor3 = if disabled then Theme.Color.DisabledText else props.TextColor or Theme.Color.Text,

		TextSize = 19,

		Font = Enum.Font.GothamBlack,

		-- Hover
		[ReactRoblox.Event.MouseEnter] = function()
			if disabled then
				return
			end

			hoveredRef.current = true

			animateScale(HOVER_SCALE)
			animateColor(baseColor:Lerp(Color3.new(1, 1, 1), 0.08))
		end,

		[React.Event.MouseLeave] = function()
			hoveredRef.current = false

			animateScale(NORMAL_SCALE)
			animateColor(baseColor)
		end,

		-- Press
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

			animateScale(if hoveredRef.current then HOVER_SCALE else NORMAL_SCALE)
		end,

		-- Activate
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

			Scale = NORMAL_SCALE,
		}),

		Corner = e("UICorner", {
			CornerRadius = Theme.Corner.Medium,
		}),

		Stroke = e("UIStroke", {
			Color = if disabled then Color3.fromRGB(91, 94, 102) else Theme.Color.Ink,

			Thickness = 2,

			Transparency = if disabled then 0.35 else 0,
		}),
	})
end

return Button
