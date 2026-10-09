--!strict
-- Customer class

-- Services --
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Config --
local CustomerConfig = require(ReplicatedStorage.Shared.Config.CustomerConfig)

-- Types --
local CustomerTypes = require(ReplicatedStorage.Shared.Types.CustomerTypes)

-- Constants --
local ATTR = CustomerTypes.Attributes

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

	Status: CustomerTypes.Status,
}

export type Customer = typeof(setmetatable({} :: CustomerData, Customer))

function Customer.new(id: string, customerType: string): Customer
	local data: CustomerData = {
		Id = id,
		CustomerType = customerType,

		Model = nil,
		Humanoid = nil,

		DesiredItem = nil,

		HasPurchased = false,

		MaxWaitTime = 0,
		TimeWaited = 0,

		Status = "Queue",
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

function Customer.ChooseDesiredItem(self: Customer): string?
	local definition = CustomerConfig[self.CustomerType]
	if not definition then
		return nil
	end

	local items = definition.DesiredItems
	if #items == 0 then
		return nil
	end

	local item = items[math.random(1, #items)]
	self.DesiredItem = item
	return item
end

function Customer.InitializePatience(self: Customer): ()
	local definition = CustomerConfig[self.CustomerType]
	if not definition then
		return
	end

	self.MaxWaitTime = math.random(definition.MinWaitTime, definition.MaxWaitTime)
	self.TimeWaited = 0
end

function Customer.SetStatus(self: Customer, status: CustomerTypes.Status): ()
	self.Status = status

	local model = self.Model
	if model then
		model:SetAttribute(ATTR.Status, status)
	end
end

function Customer.SetQueueIndex(self: Customer, index: number): ()
	local model = self.Model
	if model then
		model:SetAttribute(ATTR.QueueIndex, index)
	end
end

function Customer.SetDesiredItem(self: Customer, itemId: string?): ()
	self.DesiredItem = itemId

	local model = self.Model
	if model then
		model:SetAttribute(ATTR.DesiredItem, itemId)
	end
end

function Customer.SetWaitEndTime(self: Customer, endTime: number): ()
	local model = self.Model
	if model then
		model:SetAttribute(ATTR.WaitEndTime, endTime)
	end
end

function Customer.Spawn(self: Customer, spawnCFrame: CFrame, ownerUserId: number, factoryId: string): boolean
	local definition = CustomerConfig[self.CustomerType]
	if not definition then
		return false
	end

	local template = ReplicatedStorage.Assets.Customers:FindFirstChild(definition.ModelName)
	if not template or not template:IsA("Model") then
		warn("Missing customer model:", definition.ModelName)

		return false
	end

	local humanoid = template:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(definition.ModelName, "does not contain a Humanoid.")

		return false
	end

	local model = template:Clone()

	local clonedHumanoid = model:FindFirstChildOfClass("Humanoid")

	if not clonedHumanoid then
		model:Destroy()
		return false
	end

	-- Hide default hum overhead UI
	clonedHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	clonedHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	-- Runtime data for client UI
	model:SetAttribute(ATTR.Type, self.CustomerType)
	model:SetAttribute(ATTR.OwnerUserId, ownerUserId)
	model:SetAttribute(ATTR.FactoryId, factoryId)
	model:SetAttribute(ATTR.Status, self.Status)
	model:SetAttribute(ATTR.QueueIndex, 0)
	model:SetAttribute(ATTR.DesiredItem, self.DesiredItem)
	model:SetAttribute(ATTR.WaitEndTime, 0)
	model:SetAttribute(ATTR.MaxWaitTime, self.MaxWaitTime)

	-- Spawn
	model:PivotTo(spawnCFrame)
	model.Parent = workspace

	self.Model = model
	self.Humanoid = clonedHumanoid

	-- Clients find customers through tag
	CollectionService:AddTag(model, CustomerTypes.Tag)

	return true
end

function Customer.GoTo(self: Customer, position: Vector3): boolean
	local humanoid = self.Humanoid
	local model = self.Model
	if not humanoid or not model then
		return false
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	humanoid:MoveTo(position)

	return true
end

function Customer.MoveTo(self: Customer, position: Vector3, reachDistance: number?, timeout: number?): boolean
	local humanoid = self.Humanoid
	local model = self.Model
	if not humanoid or not model then
		return false
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

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
		local horizontalDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude

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
