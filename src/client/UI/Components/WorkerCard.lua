--!strict
-- Worker Card Component

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

-- UI --
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local WorkerViewport = require(script.Parent:WaitForChild("WorkerViewport"))

local e = React.createElement

-- Props --
export type Props = {
	WorkerId: string,
	DisplayName: string,
	ModelName: string,
	RoleName: string,
	Rarity: string,
	Price: number,
	Selected: boolean,
	Disabled: boolean?,

	OnActivated: () -> (),
}

-- Component --
local function WorkerCard(props: Props)
	local disabled = props.Disabled == true

	local hovered, setHovered = React.useState(false)

	local scaleRef = React.useRef(nil :: UIScale?)

	local roleColor = Theme.RoleColors[props.RoleName] or Theme.Color.Yellow

	-- Scale
	local function animateScale(target: number)
		local scale = scaleRef.current
		if not scale then
			return
		end

		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = target,
		}):Play()
	end

	-- Selected state
	React.useEffect(function()
		if props.Selected then
			animateScale(1.025)
		elseif not hovered then
			animateScale(1)
		end

		return nil
	end, {
		props.Selected,
	})

	-- Render
	return e("Frame", {
		BackgroundTransparency = 1,

		ClipsDescendants = false,
	}, {
		Card = e("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),

			Position = UDim2.fromScale(0.5, 0.5),

			Size = UDim2.fromScale(1, 1),

			BackgroundColor3 = if hovered
				then Theme.Color.SurfaceHover
				elseif props.Selected then Theme.Color.SurfaceSelected
				else Theme.Color.Surface,

			AutoButtonColor = false,

			Active = not disabled,

			Selectable = not disabled,

			Text = "",

			[ReactRoblox.Event.MouseEnter] = function()
				if disabled then
					return
				end

				setHovered(true)

				animateScale(if props.Selected then 1.04 else 1.025)
			end,

			[ReactRoblox.Event.MouseLeave] = function()
				if disabled then
					return
				end

				setHovered(false)

				animateScale(if props.Selected then 1.025 else 1)
			end,

			[ReactRoblox.Event.MouseButton1Down] = function()
				if disabled then
					return
				end

				animateScale(0.98)
			end,

			[ReactRoblox.Event.MouseButton1Up] = function()
				if disabled then
					return
				end

				animateScale(if props.Selected then 1.04 else 1.025)
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

				Scale = if props.Selected then 1.025 else 1,
			}),

			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 14),
			}),

			Stroke = e("UIStroke", {
				Color = if props.Selected then roleColor else Color3.fromRGB(35, 37, 44),

				Thickness = if props.Selected then 4 else 2,
			}),

			-- Role strip
			RoleBar = e("Frame", {
				Size = UDim2.new(1, 0, 0, 10),

				BackgroundColor3 = roleColor,

				BorderSizePixel = 0,
			}),

			-- Worker render
			WorkerRender = e("Frame", {
				Position = UDim2.fromOffset(10, 16),

				Size = UDim2.new(1, -20, 0, 105),

				BackgroundTransparency = 1,
			}, {
				Viewport = e(WorkerViewport, {
					ModelName = props.ModelName,
				}),
			}),

			-- Selected badge
			Selected = if props.Selected
				then e("TextLabel", {
					AnchorPoint = Vector2.new(1, 0),

					Position = UDim2.new(1, -10, 0, 16),

					Size = UDim2.fromOffset(72, 22),

					BackgroundColor3 = roleColor,

					Text = "SELECTED",

					TextColor3 = Theme.Color.Ink,

					TextSize = 10,

					Font = Enum.Font.GothamBlack,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(1, 0),
					}),
				})
				else nil,

			Name = e("TextLabel", {
				BackgroundTransparency = 1,

				Position = UDim2.fromOffset(14, 120),

				Size = UDim2.new(1, -28, 0, 29),

				Text = string.upper(props.DisplayName),

				TextColor3 = Theme.Color.Text,

				TextSize = 20,

				Font = Enum.Font.GothamBlack,

				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Role = e("TextLabel", {
				BackgroundTransparency = 1,

				Position = UDim2.fromOffset(14, 150),

				Size = UDim2.new(1, -28, 0, 21),

				Text = string.upper(props.RoleName),

				TextColor3 = roleColor,

				TextSize = 12,

				Font = Enum.Font.GothamBlack,

				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Rarity = e("TextLabel", {
				BackgroundTransparency = 1,

				Position = UDim2.new(0, 14, 1, -54),

				Size = UDim2.new(1, -28, 0, 18),

				Text = string.upper(props.Rarity),

				TextColor3 = Theme.Color.Muted,

				TextSize = 11,

				Font = Enum.Font.GothamBold,

				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Price = e("TextLabel", {
				BackgroundTransparency = 1,

				Position = UDim2.new(0, 14, 1, -35),

				Size = UDim2.new(1, -28, 0, 26),

				Text = `${props.Price}`,

				TextColor3 = Theme.Color.Yellow,

				TextSize = 20,

				Font = Enum.Font.GothamBlack,

				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),
	})
end

return WorkerCard
