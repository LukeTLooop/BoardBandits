--!strict
-- HUD Stat Display

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages:WaitForChild("React"))

-- UI --
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local e = React.createElement

-- Types --
export type Props = {
	Icon: string,

	Value: string,
	Label: string,

	AccentColor: Color3,

	AlignRight: boolean?,
	Compact: boolean?,

	Size: UDim2?,
	LayoutOrder: number?,
}

-- Component --
local function StatDisplay(props: Props)
	local scaleRef = React.useRef(nil :: UIScale?)

	local compact = props.Compact == true
	local alignRight = props.AlignRight == true

	local iconSize = if compact then 48 else 66
	local valueSize = if compact then 25 else 34
	local labelSize = if compact then 9 else 11

	-- Pop when value changes
	React.useEffect(function()
		local scale = scaleRef.current
		if not scale then
			return nil
		end

		scale.Scale = 1.12

		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()

		return nil
	end, {
		props.Value,
	})

	local iconPosition = if alignRight then UDim2.fromScale(1, 0.5) else UDim2.fromScale(0, 0.5)
	local iconAnchor = if alignRight then Vector2.new(1, 0.5) else Vector2.new(0, 0.5)
	local textPosition = if alignRight then UDim2.new(1, -(iconSize + 8), 0, 0) else UDim2.fromOffset(iconSize + 8, 0)
	local textAnchor = if alignRight then Vector2.new(1, 0) else Vector2.zero
	local textAlignment = if alignRight then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left

	return e("Frame", {
		Size = props.Size or UDim2.fromOffset(300, 70),

		BackgroundTransparency = 1,

		LayoutOrder = props.LayoutOrder or 0,
	}, {
		Scale = e("UIScale", {
			ref = scaleRef,

			Scale = 1,
		}),

		Icon = e("ImageLabel", {
			AnchorPoint = iconAnchor,

			Position = iconPosition,

			Size = UDim2.fromOffset(iconSize, iconSize),

			BackgroundTransparency = 1,

			Image = props.Icon,

			ScaleType = Enum.ScaleType.Fit,
		}),

		Value = e("TextLabel", {
			AnchorPoint = textAnchor,

			Position = textPosition,

			Size = UDim2.new(1, -(iconSize + 12), 0, if compact then 32 else 43),

			BackgroundTransparency = 1,

			Text = props.Value,

			TextColor3 = props.AccentColor,

			TextSize = valueSize,

			TextXAlignment = textAlignment,

			TextYAlignment = Enum.TextYAlignment.Bottom,

			Font = Enum.Font.FredokaOne,
		}, {
			Stroke = e("UIStroke", {
				Color = Theme.Color.Ink,

				Thickness = if compact then 3 else 4,

				LineJoinMode = Enum.LineJoinMode.Round,
			}),
		}),

		Label = e("TextLabel", {
			AnchorPoint = textAnchor,

			Position = if alignRight
				then UDim2.new(1, -(iconSize + 8), 0, if compact then 31 else 45)
				else UDim2.fromOffset(iconSize + 8, if compact then 31 else 45),

			Size = UDim2.new(1, -(iconSize + 12), 0, 20),

			BackgroundTransparency = 1,

			Text = string.upper(props.Label),

			TextColor3 = Color3.fromRGB(250, 247, 232),

			TextSize = labelSize,

			TextXAlignment = textAlignment,

			Font = Enum.Font.GothamBold,
		}, {
			Stroke = e("UIStroke", {
				Color = Theme.Color.Ink,

				Thickness = 2,
			}),
		}),
	})
end

return StatDisplay
