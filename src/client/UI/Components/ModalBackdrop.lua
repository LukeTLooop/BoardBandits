--!strict
-- Modal Backdrop Component

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)

-- UI --
local e = React.createElement

local function ModalBackdrop()
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),

		BackgroundColor3 = Color3.new(0, 0, 0),

		BackgroundTransparency = 0.28,

		BorderSizePixel = 0,

		Active = false,

		ZIndex = 1,
	})
end

return ModalBackdrop
