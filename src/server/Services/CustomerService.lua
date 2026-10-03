--!strict
-- Customer service

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HTTPService = game:GetService("HttpService")

local CustomerConfig = require(ReplicatedStorage.Shared.Config.CustomerConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Customer = require(ServerScriptService.Classes.Customer)
local Factory = require(ServerScriptService.Classes.Factory)

local MIN_SPAWN_INTERVAL = 2
local MAX_SPAWN_INTERVAL = 4

local rng = Random.new()

local CustomerService = {}
CustomerService.__index = CustomerService

type FactoryQueueState = {
	Factory: Factory.Factory,

	CustomerType: string,

	Waiting: {Customer.Customer},
	ActiveCustomer: Customer.Customer?,

	Running: boolean,
	Processing: boolean,
}

type CustomerServiceData = {
	Customers: {[string]: Customer.Customer},
	
	FactoryQueues: {[string]: FactoryQueueState},
}

export type CustomerService = typeof(setmetatable({} :: CustomerServiceData, CustomerService))

function CustomerService.new(): CustomerService
	local data: CustomerServiceData = {
		Customers = {},
		FactoryQueues = {},
	}
	
	return setmetatable(data, CustomerService)
end

function CustomerService.StartFactory(
	self: CustomerService,
	factory: Factory.Factory,
	customerType: string
): ()
	if self.FactoryQueues[factory.Id] then return end
	
	local state: FactoryQueueState = {
		Factory = factory,
		
		CustomerType = customerType,
		
		Waiting = {},
		ActiveCustomer = nil,
		
		Running = true,
		Processing = false,
	}
	
	self.FactoryQueues[factory.Id] = state
	
	task.spawn(function()
		while state.Running do
			self:TrySpawnCustomer(state)
			
			local waitTime = math.random(
				MIN_SPAWN_INTERVAL * 100,
				MAX_SPAWN_INTERVAL * 100
			) / 100
			
			task.wait(waitTime)
		end
	end)
end

function CustomerService.StopFactory(
	self: CustomerService,
	factoryId: string
): ()
	local state = self.FactoryQueues[factoryId]
	if not state then
		return
	end

	state.Running = false
	state.Processing = false

	local customersToDestroy: {Customer.Customer} = {}

	if state.ActiveCustomer then
		table.insert(customersToDestroy, state.ActiveCustomer)
	end

	for _, customer in state.Waiting do
		table.insert(customersToDestroy, customer)
	end

	table.clear(state.Waiting)
	state.ActiveCustomer = nil

	self.FactoryQueues[factoryId] = nil

	for _, customer in customersToDestroy do
		self:DestroyCustomer(customer)
	end
end

function CustomerService.RepositionQueue(
	self: CustomerService,
	state: FactoryQueueState
): ()
	for index, customer in state.Waiting do
		local queueSpot = state.Factory.CustomerQueueSpots[index]
		if not queueSpot then continue end
		
		customer:SetStatus(
			`Waiting in line...\n#{index}`
		)
		
		customer:GoTo(queueSpot.Position)
	end
end

function CustomerService.ProcessCustomerAtCounter(
	self: CustomerService,
	state: FactoryQueueState,
	customer: Customer.Customer
): ()
	local factory = state.Factory

	customer:SetStatus("Ordering...")

	-- Walk to counter
	local reachedCounter = customer:MoveTo(
		factory.CustomerCounter.Position
	)

	if not state.Running then
		self:DestroyCustomer(customer)

		return
	end

	if not reachedCounter then
		print('didnt reach counter')
		customer:Destroy()
		self.Customers[customer.Id] = nil
		return
	end

	-- Try to purchase
	local customerDefinition = CustomerConfig[customer.CustomerType]
	if not customerDefinition then
		print('no customer definition')
		customer:Destroy()
		self.Customers[customer.Id] = nil
		return
	end
	
	-- Choose desired item
	local desiredItem = self:ChooseDesiredItemForFactory(
		factory
	)
	
	if not desiredItem then
		customer:ChooseDesiredItem()
		desiredItem = customer.DesiredItem
	end
	
	-- Double check new item is valid
	if not desiredItem then
		customer:SetStatus("Nevermind...")
		
		task.wait(0.75)
		
		customer:MoveTo(
			factory.CustomerExit.Position
		)
		
		self:DestroyCustomer(
			customer
		)
		
		return
	end
	
	customer.DesiredItem = desiredItem

	local itemDefinition = ItemConfig[desiredItem]
	if not itemDefinition then
		customer:SetStatus("Nevermind...")

		task.wait(0.75)

		customer:MoveTo(
			factory.CustomerExit.Position
		)

		self:DestroyCustomer(
			customer
		)
		
		return
	end

	local displayName = if itemDefinition then itemDefinition.DisplayName else desiredItem

	customer:SetStatus(
		`Looking for:\n{displayName}`
	)
	
	-- Try to purchase until patience expires
	while state.Running and customer.TimeWaited < customer.MaxWaitTime do
		if factory:TrySellItem(desiredItem) then
			customer.HasPurchased = true
			customer:SetStatus("Thanks! 🛹")

			break
		end

		local remaining = customer.MaxWaitTime - customer.TimeWaited

		customer:SetStatus(
			`Waiting for {displayName}...\n{math.ceil(remaining)}s`
		)

		task.wait(customerDefinition.RetryInterval)

		customer.TimeWaited += customerDefinition.RetryInterval
	end
	
	if not state.Running then
		self:DestroyCustomer(customer)

		return
	end

	-- Purchase failed because patience expired
	if not customer.HasPurchased then
		customer:SetStatus(`No {displayName}?\nNevermind...`)
	end

	-- Leave factory
	task.spawn(function()
		customer:MoveTo(
			factory.CustomerExit.Position
		)
		
		self:DestroyCustomer(customer)
	end)
end

function CustomerService.ProcessQueue(
	self: CustomerService,
	state: FactoryQueueState
): ()
	while state.Running do
		local customer = table.remove(
			state.Waiting,
			1
		)
		
		if not customer then break end
		
		state.ActiveCustomer = customer
		
		-- Everyone behind moves forward
		self:RepositionQueue(state)
		
		self:ProcessCustomerAtCounter(
			state,
			customer
		)
		
		state.ActiveCustomer = nil
	end
	
	state.Processing = false
	
	-- Protect against customer joining when previous loop ending
	if state.Running and #state.Waiting > 0 then
		self:EnsureQueueProcessing(state)
	end
end

function CustomerService.EnsureQueueProcessing(
	self: CustomerService,
	state: FactoryQueueState
): ()
	if state.Processing then return end
	state.Processing = true
	
	task.spawn(function()
		self:ProcessQueue(state)
	end)
end

function CustomerService.CreateCustomer(
	self: CustomerService,
	customerType: string
): Customer.Customer
	local id = HTTPService:GenerateGUID(false)
	
	local customer = Customer.new(id, customerType)
	self.Customers[id] = customer
	
	customer:ChooseDesiredItem()
	customer:InitializePatience()
	
	return customer
end

function CustomerService.DestroyCustomer(
	self: CustomerService,
	customer: Customer.Customer
): ()
	customer:Destroy()

	self.Customers[customer.Id] = nil
end

function CustomerService.TrySpawnCustomer(
	self: CustomerService,
	state: FactoryQueueState
): boolean
	local factory = state.Factory
	
	-- All waiting positions occupied
	if #state.Waiting >= #factory.CustomerQueueSpots then
		return false
	end
	
	local customer = self:CreateCustomer(state.CustomerType)
	local spawned = customer:Spawn(CFrame.new(factory.CustomerSpawn.Position))
	
	if not spawned then
		self.Customers[customer.Id] = nil
		return false
	end
	
	customer:SetStatus("Waiting in line...")
	
	table.insert(state.Waiting, customer)
	
	self:RepositionQueue(state)
	self:EnsureQueueProcessing(state)
	
	return true
end

function CustomerService.ChooseDesiredItemForFactory(
	self: CustomerService,
	factory: Factory.Factory
): string?
	local availableItems = factory:GetAvailableSellableItems()
	if #availableItems == 0 then
		return nil
	end
	
	local index = rng:NextInteger(
		1,
		#availableItems
	)
	
	return availableItems[index]
end

return CustomerService
