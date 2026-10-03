--!strict
-- Customer class

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CustomerConfig = require(ReplicatedStorage.Shared.Config.CustomerConfig)

local Customer = {}
Customer.__index = Customer

type CustomerData = {
	Id: string,
	CustomerType: string,
	
	Model: Model?,
	Humanoid: Humanoid?,
	
	DesiredItem: string?,
	
	HasPurchased: boolean,

	MaxWaitTime: number,
	TimeWaited: number,
	
	StatusGui: BillboardGui?,
	StatusLabel: TextLabel?,
}

export type Customer = typeof(setmetatable({} :: CustomerData, Customer))

function Customer.new(
	id: string,
	customerType: string
): Customer
	local data: CustomerData = {
		Id = id,
		CustomerType = customerType,
		
		Model = nil,
		Humanoid = nil,
		
		DesiredItem = nil,
		
		HasPurchased = false,
		
		MaxWaitTime = 0,
		TimeWaited = 0,
		
		StatusGui = nil,
		StatusLabel = nil,
	}
	
	return setmetatable(data, Customer)
end

function Customer.Destroy(self: Customer): ()
	if self.Model then
		self.Model:Destroy()
	end
	
	self.Model = nil
	self.Humanoid = nil
end

function Customer.ChooseDesiredItem(
	self: Customer
): string?
	local definition = CustomerConfig[self.CustomerType]
	if not definition then return nil end
	
	local items = definition.DesiredItems
	if #items == 0 then return nil end
	
	local item = items[math.random(1, #items)]
	self.DesiredItem = item
	return item
end

function Customer.InitializePatience(self: Customer): ()
	local definition = CustomerConfig[self.CustomerType]
	if not definition then return end
	
	self.MaxWaitTime = math.random(definition.MinWaitTime, definition.MaxWaitTime)
	self.TimeWaited = 0
end

function Customer.CreateStatusGui(self: Customer): ()
	local model = self.Model
	if not model then return end
	
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		warn("Customer has no valid Head!")
		return
	end
	
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CustomerStatus"
	billboard.Adornee = head
	
	billboard.Size = UDim2.fromOffset(220, 70)
	billboard.StudsOffset = Vector3.yAxis * 3
	
	billboard.AlwaysOnTop = true
	
	local label = Instance.new("TextLabel")
	label.Name = "Status"
	
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	
	label.TextScaled = true
	label.TextWrapped = true
	
	label.Font = Enum.Font.GothamBold
	
	label.Text = ""
	
	label.Parent = billboard
	billboard.Parent = head
	
	self.StatusGui = billboard
	self.StatusLabel = label
end

function Customer.SetStatus(
	self: Customer,
	text: string
): ()
	local label = self.StatusLabel
	if not label then return end
	
	label.Text = text
end

function Customer.Spawn(
	self: Customer,
	spawnCFrame: CFrame
): boolean
	local definition = CustomerConfig[self.CustomerType]
	if not definition then return false end
	
	local template = ReplicatedStorage.Assets.Customers:FindFirstChild(definition.ModelName)
	if not template or not template:IsA("Model") then
		warn(
			"Missing customer model:",
			definition.ModelName
		)
		
		return false
	end
	
	local humanoid = template:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(
			definition.ModelName,
			"does not contain a Humanoid."
		)
		
		return false
	end
	
	local model = template:Clone()
	
	local clonedHumanoid = model:FindFirstChildOfClass("Humanoid")
	
	if not clonedHumanoid then
		model:Destroy()
		return false
	end
	
	model:PivotTo(spawnCFrame)
	model.Parent = workspace
	
	self.Model = model
	self.Humanoid = clonedHumanoid
	
	self:CreateStatusGui()
	
	return true
end

function Customer.GoTo(
	self: Customer,
	position: Vector3
): boolean
	local humanoid = self.Humanoid
	local model = self.Model
	if not humanoid or not model then return false end
	
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return false end

	humanoid:MoveTo(position)
	
	return true
end

function Customer.MoveTo(
	self: Customer,
	position: Vector3,
	reachDistance: number?,
	timeout: number?
): boolean
	local humanoid = self.Humanoid
	local model = self.Model
	if not humanoid or not model then return false end
	
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return false end
	
	local maxDistance = reachDistance or 3
	local maxTime = timeout or 10
	
	local elapsed = 0
	local moveRefreshElapsed = 0
	
	if not self:GoTo(position) then
		return false
	end
	
	while elapsed < maxTime do
		local dt = RunService.Heartbeat:Wait()
		
		elapsed += dt
		moveRefreshElapsed += dt
		
		local offset = root.Position - position
		local horizontalDistance = Vector3.new(
			offset.X,
			0,
			offset.Z
		).Magnitude
		
		if horizontalDistance <= maxDistance then
			return true
		end
		
		if moveRefreshElapsed >= 2 then
			moveRefreshElapsed = 0
			self:GoTo(position)
		end
	end
	
	return false
end

return Customer
