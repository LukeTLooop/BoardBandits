--!strict
-- Use Responsive Scale Hook

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages:WaitForChild("React"))

-- Hook --
local function useResponsiveScale(referenceViewport: Vector2, paddingScale: number?): number
	local padding = paddingScale or 0.94

	local scale, setScale = React.useState(1)

	React.useEffect(function()
		local viewportConnection: RBXScriptConnection? = nil
		local cameraConnection: RBXScriptConnection? = nil

		-- Recalculate
		local function updateScale()
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end

			local viewport = camera.ViewportSize
			local widthScale = viewport.X / referenceViewport.X
			local heightScale = viewport.Y / referenceViewport.Y

			-- Uniform scale
			-- Never stretch X/Y independently
			local newScale = math.min(widthScale, heightScale) * padding

			setScale(newScale)
		end

		-- Bind current camera
		local function bindCamera()
			if viewportConnection then
				viewportConnection:Disconnect()
				viewportConnection = nil
			end

			local camera = workspace.CurrentCamera
			if camera then
				camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
			end

			updateScale()
		end

		bindCamera()

		-- Roblox may replace CurrentCamera
		cameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)

		-- Cleanup
		return function()
			if viewportConnection then
				viewportConnection:Disconnect()
			end

			if cameraConnection then
				cameraConnection:Disconnect()
			end
		end
	end, {})

	return scale
end

return useResponsiveScale
