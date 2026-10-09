--!strict
-- Customer UI Controller

-- Services --
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

-- Shared --
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local sharedTypes = sharedFolder:WaitForChild("Types")
local CustomerTypes = require(sharedTypes:WaitForChild("CustomerTypes"))

-- UI --
local CustomerWorldUI = require(script.Parent.Parent.UI.World:WaitForChild("CustomerWorldUI"))

local e = React.createElement

local plr = Players.LocalPlayer

local ATTR = CustomerTypes.Attributes

-- Types --
type MountedCustomer = {
	UIPart: BasePart,

	Root: any,

	Connections: { RBXScriptConnection },
}

-- State --
local CustomerUIController = {}

local started = false
local mounted: { [Model]: MountedCustomer } = {}

-- Render --
local function renderCustomer(model: Model, entry: MountedCustomer): ()
	local status = model:GetAttribute(ATTR.Status)
	local customerType = model:GetAttribute(ATTR.Type)
	local desiredItem = model:GetAttribute(ATTR.DesiredItem)
	local queueIndex = model:GetAttribute(ATTR.QueueIndex)
	local waitEndTime = model:GetAttribute(ATTR.WaitEndTime)
	local maxWaitTime = model:GetAttribute(ATTR.MaxWaitTime)

	entry.Root:render(e(CustomerWorldUI, {
		Status = if typeof(status) == "string" then status else "Queue",

		CustomerType = if typeof(customerType) == "string" then customerType else "BasicCustomer",

		DesiredItem = if typeof(desiredItem) == "string" then desiredItem else nil,

		QueueIndex = if typeof(queueIndex) == "number" then queueIndex else 0,

		WaitEndTime = if typeof(waitEndTime) == "number" then waitEndTime else 0,

		MaxWaitTime = if typeof(maxWaitTime) == "number" then maxWaitTime else 0,
	}))
end

-- Cleanup --
local function cleanupCustomer(model: Model): ()
	local entry = mounted[model]
	if not entry then
		return
	end

	for _, connection in entry.Connections do
		connection:Disconnect()
	end

	entry.Root:unmount()
	entry.UIPart:Destroy()

	mounted[model] = nil
end

-- Mount --
local function mountCustomer(model: Model): ()
	if mounted[model] then
		return
	end

	-- Only the factory owner gets the UI
	local ownerUserId = model:GetAttribute(ATTR.OwnerUserId)
	if ownerUserId ~= plr.UserId then
		return
	end

	local head = model:FindFirstChild("Head", true)
	if not head or not head:IsA("BasePart") then
		return
	end

	local uiPart = Instance.new("Part")
	uiPart.Name = "CustomerUI"
	uiPart.Size = Vector3.new(8.75, 3.7, 0.05)
	uiPart.Anchored = true
	uiPart.CanCollide = false
	uiPart.CanTouch = false
	uiPart.CanQuery = false
	uiPart.CastShadow = false
	uiPart.Transparency = 1
	uiPart.Parent = workspace

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "CustomerStatus"
	surfaceGui.Adornee = uiPart
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.CanvasSize = Vector2.new(280, 112)
	surfaceGui.AlwaysOnTop = true
	surfaceGui.LightInfluence = 0
	surfaceGui.Parent = uiPart

	local root = ReactRoblox.createRoot(surfaceGui)
	local connections: { RBXScriptConnection } = {}
	local entry: MountedCustomer = {
		UIPart = uiPart,

		Root = root,

		Connections = connections,
	}

	mounted[model] = entry

	-- Reactively update when server data changes
	local watchedAttributes = {
		ATTR.Status,
		ATTR.Type,
		ATTR.DesiredItem,
		ATTR.QueueIndex,
		ATTR.WaitEndTime,
		ATTR.MaxWaitTime,
	}

	for _, attributeName in watchedAttributes do
		table.insert(
			connections,
			model:GetAttributeChangedSignal(attributeName):Connect(function()
				renderCustomer(model, entry)
			end)
		)
	end

	renderCustomer(model, entry)
end

-- Start --
function CustomerUIController.Start()
	if started then
		return
	end

	started = true

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		for model, entry in mounted do
			if not model.Parent then
				continue
			end

			local head = model:FindFirstChild("Head", true)
			if not head or not head:IsA("BasePart") then
				continue
			end

			local position = head.Position + Vector3.new(0, 3.55, 0)

			-- Face cam while remaining upright
			entry.UIPart.CFrame = CFrame.new(position) * camera.CFrame.Rotation * CFrame.Angles(0, math.pi, 0)
		end
	end)

	CollectionService:GetInstanceAddedSignal(CustomerTypes.Tag):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			task.defer(mountCustomer, instance)
		end
	end)

	CollectionService:GetInstanceRemovedSignal(CustomerTypes.Tag):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			cleanupCustomer(instance)
		end
	end)

	-- Customers that existed before controller startup
	for _, instance in CollectionService:GetTagged(CustomerTypes.Tag) do
		if instance:IsA("Model") then
			mountCustomer(instance)
		end
	end
end

return CustomerUIController
