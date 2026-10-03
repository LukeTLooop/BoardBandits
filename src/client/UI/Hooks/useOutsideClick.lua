--!strict
-- Use Outside Click Hook

-- Services --
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)

local function isPointInsideGui(gui: GuiObject, point: Vector2): boolean
	local position = gui.AbsolutePosition
	local size = gui.AbsoluteSize

	return point.X >= position.X
		and point.X <= position.X + size.X
		and point.Y >= position.Y
		and point.Y <= position.Y + size.Y
end

local function useOutsideClick(windowRef: { current: Frame? }, enabled: boolean, onOutsideClick: () -> ())
	React.useEffect(function()
		if not enabled then
			return nil
		end

		local connection = UserInputService.InputBegan:Connect(function(input: InputObject)
			local inputType = input.UserInputType
			if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
				return
			end

			local window = windowRef.current
			if not window then
				return
			end

			local point = Vector2.new(input.Position.X, input.Position.Y)

			if isPointInsideGui(window, point) then
				return
			end

			onOutsideClick()
		end)

		return function()
			connection:Disconnect()
		end
	end, {
		enabled,
		onOutsideClick,
	})
end

return useOutsideClick
