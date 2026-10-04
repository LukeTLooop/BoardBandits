--!strict
-- Theft Service

-- Services --
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local WorkerInventoryService = require(ServerScriptService.Services.WorkerInventoryService)
local EconomyService = require(ServerScriptService.Services.EconomyService)

-- Classes --
local Factory = require(ServerScriptService.Classes.Factory)
local Worker = require(ServerScriptService.Classes.Worker)

-- Config --
local TemperConfig = require(ReplicatedStorage.Shared.Config.TemperConfig)

-- Framework --
local GameEvents = require(ServerScriptService.Framework.GameEvents)

-- Remotes --
local workerRemotes = ReplicatedStorage.Remotes.Workers

local inventoryUpdated = workerRemotes.InventoryUpdated
assert(inventoryUpdated:IsA("RemoteEvent"), "InventoryUpdated must be a RemoteEvent!")

-- Helpers --
local function isPointInsidePart(part: BasePart, worldPosition: Vector3): boolean
	-- Convert world position into part's local space
	local localPosition = part.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = part.Size * 0.5

	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

local TheftService = {}
TheftService.__index = TheftService

-- Types --
type PartState = {
	Anchored: boolean,
	CanCollide: boolean,
	Massless: boolean,
}

type CarriedWorkerData = {
	Worker: Worker.Worker,
	Carrier: Player,
	OriginalOwnerUserId: number,
	OriginalFactory: Factory.Factory,
	OriginalSlotIndex: number,
	OriginalWalkSpeed: number,
	PartStates: { [BasePart]: PartState },
	Weld: WeldConstraint?,
	DeathConnection: RBXScriptConnection?,
	CharacterRemovingConnection: RBXScriptConnection?,
}

type TheftServiceData = {
	Inventory: WorkerInventoryService.WorkerInventoryService,
	Factories: { [string]: Factory.Factory },
	Economy: EconomyService.EconomyService,
	CarriedWorkers: { [number]: CarriedWorkerData },
	CarriedFolder: Folder,
	Started: boolean,
}

export type TheftService = typeof(setmetatable({} :: TheftServiceData, TheftService))

-- Constructor --
function TheftService.new(
	inventory: WorkerInventoryService.WorkerInventoryService,
	economy: EconomyService.EconomyService
): TheftService
	local existing = workspace:FindFirstChild("CarriedWorkers")
	local carriedFolder: Folder
	if existing and existing:IsA("Folder") then
		carriedFolder = existing
	else
		carriedFolder = Instance.new("Folder")
		carriedFolder.Name = "CarriedWorkers"
		carriedFolder.Parent = workspace
	end

	local data: TheftServiceData = {
		Inventory = inventory,
		Factories = {},
		Economy = economy,
		CarriedWorkers = {},
		CarriedFolder = carriedFolder,
		Started = false,
	}

	return setmetatable(data, TheftService)
end

-- Factory Registration --
function TheftService.RegisterFactory(self: TheftService, factory: Factory.Factory): ()
	self.Factories[factory.Id] = factory
end

function TheftService.UnregisterFactory(self: TheftService, factoryId: string): ()
	self.Factories[factoryId] = nil
end

-- Start --
function TheftService.Start(self: TheftService): ()
	if self.Started then
		return
	end
	self.Started = true

	-- Theft prompts
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, plr: Player)
		-- Factory cash theft
		if prompt.Name == "StealCashPrompt" then
			local factoryId = prompt:GetAttribute("FactoryId")
			if typeof(factoryId) ~= "string" then
				return
			end

			local factory = self.Factories[factoryId]
			if not factory then
				return
			end

			self:TryStealFactoryCash(plr, factory)

			return
		end

		-- Worker theft
		if prompt.Name ~= "StealPrompt" then
			return
		end

		local factoryId = prompt:GetAttribute("FactoryId")
		local slotIndex = prompt:GetAttribute("SlotIndex")
		local workerId = prompt:GetAttribute("WorkerId")

		if typeof(factoryId) ~= "string" then
			return
		end
		if typeof(slotIndex) ~= "number" then
			return
		end
		if typeof(workerId) ~= "string" then
			return
		end

		local factory = self.Factories[factoryId]
		if not factory then
			return
		end

		local worker = factory:GetWorkerInSlot(slotIndex)
		if not worker then
			return
		end

		-- Prevent stale/spoofed prompt data
		if worker.Id ~= workerId then
			return
		end

		self:TryGrabWorker(plr, factory, slotIndex)
	end)

	-- Territory detection
	local territoryElapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		territoryElapsed += dt
		if territoryElapsed < 0.1 then
			return
		end

		territoryElapsed = 0

		-- Snapshot players because ClaimCarriedWorker modifies CarriedWorkers
		local carriers: { Player } = {}

		for _, carriedData in self.CarriedWorkers do
			table.insert(carriers, carriedData.Carrier)
		end

		for _, carrier in carriers do
			self:CheckCarriedWorkerTerritory(carrier)
		end
	end)

	-- Carrier leaves server
	Players.PlayerRemoving:Connect(function(plr: Player)
		if self.CarriedWorkers[plr.UserId] then
			self:ReturnCarriedWorker(plr)
		end
	end)
end

-- Query --
function TheftService.GetCarriedWorker(self: TheftService, plr: Player): Worker.Worker?
	local data = self.CarriedWorkers[plr.UserId]
	if not data then
		return nil
	end

	return data.Worker
end

-- Theft --
function TheftService.TryStealFactoryCash(self: TheftService, thief: Player, factory: Factory.Factory): number
	-- Can't steal from self
	if factory.OwnerUserId == thief.UserId then
		return 0
	end

	-- Player must own factory before they can steal
	local thiefFactory = self:GetFactoryOwnedByUserId(thief.UserId)
	if not thiefFactory then
		return 0
	end

	-- Validate character
	local char = thief.Character
	if not char then
		return 0
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return 0
	end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return 0
	end

	-- Validate proximity server-side
	local collector = factory.Model:FindFirstChild("MoneyCollector")
	if not collector or not collector:IsA("BasePart") then
		return 0
	end

	if (root.Position - collector.Position).Magnitude > 12 then
		return 0
	end

	-- Steal whatever is currently uncollected
	local amount = factory:TakePendingCash(factory.PendingCash)
	if amount <= 0 then
		return 0
	end

	-- Award thief
	self.Economy:AddCash(thief, amount)

	-- Broadcast theft
	GameEvents.FactoryCashStolen:Fire(thief, factory.OwnerUserId, amount)

	return amount
end

-- Grab --
function TheftService.TryGrabWorker(
	self: TheftService,
	thief: Player,
	factory: Factory.Factory,
	slotIndex: number
): boolean
	-- Can't carry more than one worker
	if self.CarriedWorkers[thief.UserId] then
		return false
	end

	local thiefFactory = self:GetFactoryOwnedByUserId(thief.UserId)
	if not thiefFactory then
		return false
	end

	-- Can't rob self
	if factory.OwnerUserId == thief.UserId then
		return false
	end

	local worker = factory:GetWorkerInSlot(slotIndex)
	if not worker then
		return false
	end

	-- Persistent worker
	local originalOwnerUserId = worker.OwnerUserId
	local ownedWorker = self.Inventory:GetWorkerByUserId(originalOwnerUserId, worker.Id)
	if not ownedWorker then
		return false
	end

	if ownedWorker.State ~= "Placed" then
		return false
	end

	if ownedWorker.FactoryId ~= factory.Id then
		return false
	end

	if ownedWorker.SlotIndex ~= slotIndex then
		return false
	end

	-- Validate thief character
	local char = thief.Character
	if not char then
		return false
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local carryPart: BasePart
	local upperTorso = char:FindFirstChild("UpperTorso")
	if not upperTorso or not upperTorso:IsA("BasePart") then
		carryPart = root
	else
		carryPart = upperTorso
	end

	-- Worker physical validation
	local workerModel = worker.Model
	if not workerModel then
		return false
	end

	local workerRoot = worker:GetRootPart()
	if not workerRoot then
		return false
	end

	-- Server-side distance check
	local distance = (root.Position - workerRoot.Position).Magnitude
	if distance > 11 then
		return false
	end

	-- Detach from factory
	local detachedWorker = factory:DetachWorkerFromSlot(slotIndex)
	if detachedWorker ~= worker then
		return false
	end

	-- Save physical state
	local partStates: { [BasePart]: PartState } = {}

	for _, descendant in workerModel:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end

		partStates[descendant] = {
			Anchored = descendant.Anchored,
			CanCollide = descendant.CanCollide,
			Massless = descendant.Massless,
		}

		descendant.Anchored = false
		descendant.CanCollide = false
		descendant.Massless = true
	end

	-- Move worker into carried folder
	workerModel.Parent = self.CarriedFolder
	workerModel:PivotTo(carryPart.CFrame * CFrame.new(0, 0, -2.5))

	-- Weld to player
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = carryPart
	weld.Part1 = workerRoot
	weld.Parent = workerRoot

	-- Temper movement modifiers
	local originalWalkSpeed = hum.WalkSpeed
	local temperDefinition = TemperConfig[worker.Temper]

	if temperDefinition then
		hum.WalkSpeed = originalWalkSpeed * temperDefinition.CarrierSpeedMultiplier
	end

	-- Register carry before updating persistent state
	local carriedData: CarriedWorkerData = {
		Worker = worker,
		Carrier = thief,
		OriginalOwnerUserId = originalOwnerUserId,
		OriginalFactory = factory,
		OriginalSlotIndex = slotIndex,
		OriginalWalkSpeed = originalWalkSpeed,
		PartStates = partStates,
		Weld = weld,
		DeathConnection = nil,
		CharacterRemovingConnection = nil,
	}

	self.CarriedWorkers[thief.UserId] = carriedData

	-- Runtime state
	worker.State = "Carried"
	worker.FactoryId = nil
	worker.CarrierUserId = thief.UserId

	-- Persistent state
	local stateUpdated = self.Inventory:SetWorkerCarriedByUserId(originalOwnerUserId, worker.Id, thief.UserId)
	if not stateUpdated then
		warn("[THEFT] Failed to enter carried state!")

		self:ReturnCarriedWorker(thief)

		return false
	end

	-- Carrier dies
	carriedData.DeathConnection = hum.Died:Connect(function()
		self:ReturnCarriedWorker(thief)
	end)

	-- Carrier resets/char disappears
	carriedData.CharacterRemovingConnection = thief.CharacterRemoving:Connect(function()
		self:ReturnCarriedWorker(thief)
	end)

	-- Tell original owner client worker has left factory
	local originalOwnerPlayer = Players:GetPlayerByUserId(originalOwnerUserId)
	if originalOwnerPlayer then
		inventoryUpdated:FireClient(originalOwnerPlayer, worker.Id, "Carried")
	end

	GameEvents.WorkerGrabbed:Fire(thief, originalOwnerUserId, ownedWorker)

	return true
end

-- Return worker --
function TheftService.ReturnCarriedWorker(self: TheftService, carrier: Player): boolean
	local carriedData = self.CarriedWorkers[carrier.UserId]
	if not carriedData then
		return false
	end

	local worker = carriedData.Worker
	local originalFactory = carriedData.OriginalFactory
	local originalSlotIndex = carriedData.OriginalSlotIndex
	local originalOwnerUserId = carriedData.OriginalOwnerUserId

	-- Finish carry state
	self:CleanupCarry(carrier, carriedData)
	self:RestoreWorkerPartStates(carriedData)

	worker.CarrierUserId = nil
	worker.FactoryId = nil
	worker.State = "Stored"

	-- Try original slot first
	if not originalFactory:IsSlotOccupied(originalSlotIndex) then
		if worker.Model then
			worker.Model.Parent = originalFactory.Model
		end

		local placed = originalFactory:PlaceWorkerInSlot(worker, originalSlotIndex)

		if placed then
			local stateUpdated = self.Inventory:SetWorkerPlacedByUserId(
				originalOwnerUserId,
				worker.Id,
				originalFactory.Id,
				originalSlotIndex
			)

			if stateUpdated then
				local ownedWorker = self.Inventory:GetWorkerByUserId(originalOwnerUserId, worker.Id)
				local ownerPlayer = Players:GetPlayerByUserId(originalOwnerUserId)

				if ownerPlayer then
					inventoryUpdated:FireClient(ownerPlayer, worker.Id, "Placed")
				end

				if ownedWorker then
					GameEvents.WorkerRecovered:Fire(originalOwnerUserId, ownedWorker)
				end

				return true
			end
		end
	end

	-- Original slot unavailable, return to storage
	worker:StopWorking()
	worker:ClearFactoryCallbacks()

	worker.State = "Stored"
	worker.FactoryId = nil
	worker.CarrierUserId = nil

	if worker.Model then
		worker.Model:Destroy()
		worker.Model = nil
	end

	local stateUpdated = self.Inventory:SetWorkerStoredByUserId(originalOwnerUserId, worker.Id)
	if not stateUpdated then
		warn("[THEFT] Failed to return worker to storage:", worker.Id)

		return false
	end

	local ownedWorker = self.Inventory:GetWorkerByUserId(originalOwnerUserId, worker.Id)
	local ownerPlayer = Players:GetPlayerByUserId(originalOwnerUserId)

	if ownerPlayer then
		inventoryUpdated:FireClient(ownerPlayer, worker.Id, "Stored")
	end

	if ownedWorker then
		GameEvents.WorkerRecovered:Fire(originalOwnerUserId, ownedWorker)
	end

	return true
end

function TheftService.ReturnWorkersOwnedByUserId(self: TheftService, ownerUserId: number): ()
	local carriers: { Player } = {}

	-- Snapshot
	for _, carriedData in self.CarriedWorkers do
		if carriedData.OriginalOwnerUserId ~= ownerUserId then
			continue
		end

		table.insert(carriers, carriedData.Carrier)
	end

	for _, carrier in carriers do
		self:ReturnCarriedWorker(carrier)
	end
end

function TheftService.CleanupCarry(self: TheftService, carrier: Player, carriedData: CarriedWorkerData): ()
	-- Clear carry state first
	self.CarriedWorkers[carrier.UserId] = nil

	-- Disconnect listeners
	if carriedData.DeathConnection then
		carriedData.DeathConnection:Disconnect()
		carriedData.DeathConnection = nil
	end

	if carriedData.CharacterRemovingConnection then
		carriedData.CharacterRemovingConnection:Disconnect()
		carriedData.CharacterRemovingConnection = nil
	end

	-- Destroy carried weld
	if carriedData.Weld then
		carriedData.Weld:Destroy()
		carriedData.Weld = nil
	end

	-- Restore carrier movement
	local char = carrier.Character
	if not char then
		return
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end

	hum.WalkSpeed = carriedData.OriginalWalkSpeed
end

function TheftService.RestoreWorkerPartStates(self: TheftService, carriedData: CarriedWorkerData): ()
	for part, state in carriedData.PartStates do
		if not part.Parent then
			continue
		end

		part.Anchored = state.Anchored
		part.CanCollide = state.CanCollide
		part.Massless = state.Massless
	end
end

function TheftService.ClaimCarriedWorker(self: TheftService, carrier: Player, factory: Factory.Factory): boolean
	-- Must own destination factory
	if factory.OwnerUserId ~= carrier.UserId then
		return false
	end

	local carriedData = self.CarriedWorkers[carrier.UserId]
	if not carriedData then
		return false
	end

	local worker = carriedData.Worker
	local originalOwnerUserId = carriedData.OriginalOwnerUserId

	-- Can't steal own worker
	if originalOwnerUserId == carrier.UserId then
		return false
	end

	-- Validate persistent carry state
	local ownedWorker = self.Inventory:GetWorkerByUserId(originalOwnerUserId, worker.Id)
	if not ownedWorker then
		return false
	end

	if ownedWorker.State ~= "Carried" then
		return false
	end

	if ownedWorker.CarrierUserId ~= carrier.UserId then
		return false
	end

	-- Transfer ownership
	local transferredWorker = self.Inventory:TransferWorkerOwnership(originalOwnerUserId, carrier.UserId, worker.Id)
	if not transferredWorker then
		self:ReturnCarriedWorker(carrier)

		return false
	end

	-- Carry finished
	self:CleanupCarry(carrier, carriedData)

	-- Runtime worker has now been stolen, but is stored
	worker.OwnerUserId = carrier.UserId
	worker.State = "Stored"
	worker.FactoryId = nil
	worker.CarrierUserId = nil

	worker:StopWorking()
	worker:ClearFactoryCallbacks()

	-- No world model necessary for stored worker
	if worker.Model then
		worker.Model:Destroy()
		worker.Model = nil
	end

	-- Client inventory updates
	local originalOwner = Players:GetPlayerByUserId(originalOwnerUserId)
	if originalOwner then
		inventoryUpdated:FireClient(originalOwner, worker.Id, "Removed")
	end

	inventoryUpdated:FireClient(carrier, worker.Id, "Stored")

	-- Broadcast worker stolen
	GameEvents.WorkerStolen:Fire(carrier, originalOwnerUserId, transferredWorker)

	return true
end

function TheftService.CheckCarriedWorkerTerritory(self: TheftService, carrier: Player): ()
	local carriedData = self.CarriedWorkers[carrier.UserId]
	if not carriedData then
		return
	end

	-- Character
	local char = carrier.Character
	if not char then
		return
	end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	-- Find carrier's factory
	for _, factory in self.Factories do
		if factory.OwnerUserId ~= carrier.UserId then
			continue
		end

		local territory = factory.Model:FindFirstChild("Territory")
		if not territory or not territory:IsA("BasePart") then
			return
		end

		-- Check if player is inside
		if not isPointInsidePart(territory, root.Position) then
			return
		end

		-- Theft complete
		self:ClaimCarriedWorker(carrier, factory)

		return
	end
end

function TheftService.GetFactoryOwnedByUserId(self: TheftService, userId: number): Factory.Factory?
	for _, factory in self.Factories do
		if factory.OwnerUserId ~= userId then
			continue
		end

		return factory
	end

	return nil
end

return TheftService
