--!strict
-- Customer Billboard

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)

-- Config --
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local sharedConfig = sharedFolder:WaitForChild("Config")

local ItemConfig = require(sharedConfig:WaitForChild("ItemConfig"))
local CustomerConfig = require(sharedConfig:WaitForChild("CustomerConfig"))

-- UI --
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))

local e = React.createElement

-- Props --
export type Props = {
	Status: string,

	CustomerType: string,

	DesiredItem: string?,

	QueueIndex: number,

	WaitEndTime: number,
	MaxWaitTime: number,
}

local function CustomerBillboard(props: Props)
	local remaining, setRemaining = React.useState(0)

	-- Client-side countdown
	React.useEffect(
		function()
			local alive = true

			if props.Status ~= "Waiting" then
				setRemaining(0)

				return function()
					alive = false
				end
			end

			task.spawn(function()
				while alive do
					local timeLeft = math.max(0, props.WaitEndTime - workspace:GetServerTimeNow())
					setRemaining(math.ceil(timeLeft))

					task.wait(0.1)
				end
			end)

			return function()
				alive = false
			end
		end,
		{
			props.Status,
			props.WaitEndTime,
		} :: { any }
	)

	-- Resolve presentation
	local customerDefinition = CustomerConfig[props.CustomerType]
	local customerName = if customerDefinition then customerDefinition.DisplayName else "Customer"

	local itemDefinition = if props.DesiredItem then ItemConfig[props.DesiredItem] else nil
	local itemName = if itemDefinition
		then itemDefinition.DisplayName
		elseif props.DesiredItem then props.DesiredItem
		else "Skateboard"

	local accent = Theme.Color.Bearings

	local headerText = "IN LINE"
	local mainText = if props.QueueIndex > 0 then `LINE #{props.QueueIndex}` else "WAITING"
	local detailText = string.upper(customerName)
	local badgeText: string? = nil

	-- State presentation
	if props.Status == "Ordering" then
		accent = Theme.Color.Yellow
		headerText = "AT THE COUNTER"
		mainText = "ORDERING..."
	elseif props.Status == "Waiting" then
		accent = Theme.Color.Assembler
		headerText = "WANTS"
		mainText = itemName
		badgeText = `{remaining}S`
	elseif props.Status == "Success" then
		accent = Theme.Color.Success
		headerText = "SOLD!"
		mainText = "THANKS!"
		detailText = string.upper(itemName)
	elseif props.Status == "Failed" then
		accent = Theme.Color.Danger
		headerText = "NO STOCK"
		mainText = itemName
		detailText = "LEAVING..."
	elseif props.Status == "Leaving" then
		accent = Theme.Color.Danger
		headerText = "LEAVING"
		mainText = "NEVERMIND"
	end

	if props.Status == "Queue" and props.QueueIndex > 0 then
		badgeText = `#{props.QueueIndex}`
	end

	-- Patience progress
	local progress = 0
	if props.Status == "Waiting" and props.MaxWaitTime > 0 then
		progress = math.clamp(remaining / props.MaxWaitTime, 0, 1)
	end

	-- Render
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),

		BackgroundTransparency = 1,
	}, {
		-- Chunky shadow
		Shadow = e("Frame", {
			Position = UDim2.fromOffset(5, 6),

			Size = UDim2.new(1, -8, 1, -14),

			BackgroundColor3 = Theme.Color.Ink,

			BackgroundTransparency = 0.12,

			BorderSizePixel = 0,

			ZIndex = 1,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 15),
			}),
		}),

		-- Speech-bubble tail
		Tail = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),

			Position = UDim2.new(0.5, -4, 1, -16),

			Size = UDim2.fromOffset(18, 18),

			BackgroundColor3 = Theme.Color.Cream,

			BorderSizePixel = 0,

			Rotation = 45,

			ZIndex = 4,
		}),

		-- Main sticker
		Panel = e("Frame", {
			Size = UDim2.new(1, -8, 1, -14),

			BackgroundColor3 = Theme.Color.Cream,

			BorderSizePixel = 0,

			ClipsDescendants = true,

			ZIndex = 3,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 15),
			}),

			Stroke = e("UIStroke", {
				Color = Theme.Color.Ink,

				Thickness = 3,
			}),

			-- Colored status header
			Header = e("Frame", {
				Position = UDim2.fromOffset(5, 5),

				Size = UDim2.new(1, -10, 0, 27),

				BackgroundColor3 = accent,

				BorderSizePixel = 0,

				ZIndex = 4,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 9),
				}),

				Label = e("TextLabel", {
					Position = UDim2.fromOffset(9, 0),

					Size = UDim2.new(1, -70, 1, 0),

					BackgroundTransparency = 1,

					Text = headerText,

					TextColor3 = Color3.new(1, 1, 1),

					TextSize = 14,

					Font = Enum.Font.FredokaOne,

					TextXAlignment = Enum.TextXAlignment.Left,

					ZIndex = 5,
				}, {
					Stroke = e("UIStroke", {
						Color = Theme.Color.Ink,

						Thickness = 2,
					}),
				}),

				Badge = if badgeText
					then e("TextLabel", {
						AnchorPoint = Vector2.new(1, 0.5),

						Position = UDim2.new(1, -5, 0.5, 0),

						Size = UDim2.fromOffset(48, 21),

						BackgroundColor3 = Theme.Color.Cream,

						Text = badgeText,

						TextColor3 = Theme.Color.Ink,

						TextSize = 12,

						Font = Enum.Font.FredokaOne,

						ZIndex = 5,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),

						Stroke = e("UIStroke", {
							Color = Theme.Color.Ink,

							Thickness = 2,
						}),
					})
					else nil,
			}),

			Main = e("TextLabel", {
				Position = UDim2.fromOffset(10, 36),

				Size = UDim2.new(1, -20, 0, 26),

				BackgroundTransparency = 1,

				Text = mainText,

				TextColor3 = Theme.Color.Ink,

				TextSize = 18,

				TextTruncate = Enum.TextTruncate.AtEnd,

				Font = Enum.Font.FredokaOne,

				TextXAlignment = Enum.TextXAlignment.Left,

				ZIndex = 4,
			}),

			Detail = e("TextLabel", {
				Position = UDim2.fromOffset(10, 62),

				Size = UDim2.new(1, -20, 0, 15),

				BackgroundTransparency = 1,

				Text = detailText,

				TextColor3 = Theme.Color.HUDMuted,

				TextSize = 10,

				Font = Enum.Font.GothamBold,

				TextXAlignment = Enum.TextXAlignment.Left,

				ZIndex = 4,
			}),

			-- Patience bar
			PatienceTrack = e("Frame", {
				Position = UDim2.new(0, 10, 1, -11),

				Size = UDim2.new(1, -20, 0, 6),

				BackgroundColor3 = Theme.Color.Ink,

				BackgroundTransparency = 0.78,

				BorderSizePixel = 0,

				Visible = props.Status == "Waiting",

				ZIndex = 4,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),

				Fill = e("Frame", {
					Size = UDim2.fromScale(progress, 1),

					BackgroundColor3 = accent,

					BorderSizePixel = 0,

					ZIndex = 5,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(1, 0),
					}),
				}),
			}),
		}),
	})
end

return CustomerBillboard
