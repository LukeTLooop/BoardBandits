--!strict
-- Worker Viewport Component

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)

-- UI --
local e = React.createElement

-- Assets --
local workerAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Workers")

-- Props --
export type Props = {
	ModelName: string,

	Size: UDim2?,

	Position: UDim2?,

	AnchorPoint: Vector2?,

	BackgroundTransparency: number?,
}

-- Component --
local function WorkerViewport(props: Props)
	local viewportRef = React.useRef(nil :: ViewportFrame?)

	-- Build model
	React.useEffect(function()
		local viewport = viewportRef.current
		if not viewport then
			return
		end

		-- Clear previous preview
		local oldWorld = viewport:FindFirstChild("WorkerWorld")
		if oldWorld then
			oldWorld:Destroy()
		end

		local oldCamera = viewport:FindFirstChild("WorkerCamera")
		if oldCamera then
			oldCamera:Destroy()
		end

		local asset = workerAssets:FindFirstChild(props.ModelName)
		if not asset or not asset:IsA("Model") then
			warn("[UI] Missing worker model:", props.ModelName)

			return
		end

		-- World
		local worldModel = Instance.new("WorldModel")
		worldModel.Name = "WorkerWorld"
		worldModel.Parent = viewport

		-- Camera
		local camera = Instance.new("Camera")
		camera.Name = "WorkerCamera"
		camera.FieldOfView = 32
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		-- Clone worker
		local model = asset:Clone()
		model.Name = "PreviewWorker"

		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end

		model.Parent = worldModel

		-- Normalize position
		model:PivotTo(CFrame.new())

		local boundingCFrame, boundingSize = model:GetBoundingBox()
		local center = boundingCFrame.Position

		-- Camera target
		local lookOffset = Vector3.new(0, boundingSize.Y * 0.04, 0)
		local lookTarget = center + lookOffset

		-- Camera distance
		local largestDimension = math.max(boundingSize.X, boundingSize.Y, boundingSize.Z)
		local distance = largestDimension * 1.65

		-- Characters face -Z, so cam sits on -Z
		local cameraPosition = lookTarget + Vector3.new(0, -distance, -boundingSize.Z * 0.05)

		camera.CFrame = CFrame.lookAt(cameraPosition, lookTarget)

		-- Lighting
		viewport.Ambient = Color3.fromRGB(190, 190, 190)
		viewport.LightColor = Color3.fromRGB(255, 248, 230)
		viewport.LightDirection = Vector3.one * -1
	end, {
		props.ModelName,
	})

	-- Render
	return e("ViewportFrame", {
		ref = viewportRef,

		Size = props.Size or UDim2.fromScale(1, 1),

		Position = props.Position or UDim2.new(),

		AnchorPoint = props.AnchorPoint or Vector2.zero,

		BackgroundTransparency = props.BackgroundTransparency or 1,

		BorderSizePixel = 0,
	})
end

return WorkerViewport
