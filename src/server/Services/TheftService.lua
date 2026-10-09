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
local WorkerConfig = require(ReplicatedStorage.Shared.Config.WorkerConfig)

-- Framework --
local GameEvents = require(ServerScriptService.Framework.GameEvents)

-- Remotes --
local workerRemotes = ReplicatedStorage.Remotes.Workers

local inventoryUpdated = workerRemotes.InventoryUpdated
assert(inventoryUpdated:IsA("RemoteEvent"), "InventoryUpdated must be a RemoteEvent!")

local bonkCarrier = workerRemotes.BonkCarrier
assert(bonkCarrier:IsA("RemoteEvent"), "BonkCarrier must be a RemoteEvent!")

local carryPoseChanged = workerRemotes.CarryPoseChanged
assert(carryPoseChanged:IsA("RemoteEvent"), "CarryPoseChanged must be a RemoteEvent!")

local bonkVisual = workerRemotes.BonkVisual
assert(bonkVisual:IsA("RemoteEvent"), "BonkVisual must be a RemoteEvent!")

-- Constants --
local DEFAULT_CARRY_OFFSET = CFrame.new(0, 0.3, -1.7)

local BONK_DISTANCE = 9
local BONK_COOLDOWN = 0.8
local BONK_IMPACT_DELAY = 0.24

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

type DroppedWorkerData = {
	Worker: Worker.Worker,
	OriginalOwnerUserId: number,
	OriginalFactory: Factory.Factory,
	OriginalSlotIndex: number,
	PartStates: {
		[BasePart]: PartState,
	},
	Prompt: ProximityPrompt,
}

type TheftServiceData = {
	Inventory: WorkerInventoryService.WorkerInventoryService,
	Factories: { [string]: Factory.Factory },
	Economy: EconomyService.EconomyService,

	CarriedWorkers: {
		[number]: CarriedWorkerData,
	},
	DroppedWorkers: {
		[string]: DroppedWorkerData,
	},

	LastBonkAt: {
		[number]: number,
	},
	BonkPending: {
		[number]: boolean,
	},

	DroppedFolder: Folder,
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

	local droppedExisting = workspace:FindFirstChild("DroppedWorkers")
	local droppedFolder: Folder

	if droppedExisting and droppedExisting:IsA("Folder") then
		droppedFolder = droppedExisting
	else
		droppedFolder = Instance.new("Folder")
		droppedFolder.Name = "DroppedWorkers"
		droppedFolder.Parent = workspace
	end

	local data: TheftServiceData = {
		Inventory = inventory,
		Factories = {},
		Economy = economy,

		CarriedWorkers = {},
		DroppedWorkers = {},

		LastBonkAt = {},
		BonkPending = {},

		DroppedFolder = droppedFolder,
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
		-- Dropped worker pickup
		if prompt.Name == "DroppedWorkerPrompt" then
			local workerId = prompt:GetAttribute("WorkerId")
			if typeof(workerId) ~= "string" then
				return
			end

			self:TryPickupDroppedWorker(plr, workerId)

			return
		end

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

	-- Listen for bonk
	bonkCarrier.OnServerEvent:Connect(function(attacker: Player, targetUserId: number)
		if typeof(targetUserId) ~= "number" then
			return
		end

		local target = Players:GetPlayerByUserId(targetUserId)
		if not target then
			return
		end

		self:TryBonkCarrier(attacker, target)
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
function TheftService.BeginCarryWorker(
	self: TheftService,
	carrier: Player,
	worker: Worker.Worker,
	originalOwnerUserId: number,
	originalFactory: Factory.Factory,
	originalSlotIndex: number,
	existingPartStates: { [BasePart]: PartState }?
): boolean
	if self.CarriedWorkers[carrier.UserId] then
		return false
	end

	local char = carrier.Character
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

	local workerModel = worker.Model
	local workerRoot = worker:GetRootPart()
	if not workerModel or not workerRoot then
		return false
	end

	-- Preserve original physics
	local partStates: { [BasePart]: PartState } = existingPartStates or {}
	if not existingPartStates then
		for _, descendant in workerModel:GetDescendants() do
			if not descendant:IsA("BasePart") then
				continue
			end

			partStates[descendant] = {
				Anchored = descendant.Anchored,
				CanCollide = descendant.CanCollide,
				Massless = descendant.Massless,
			}
		end
	end

	-- Carry physics
	worker:SetStationLocked(false)
	worker:SetUprightLocked(false)

	for _, descendant in workerModel:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end

		descendant.Anchored = false
		descendant.CanCollide = false
		descendant.Massless = true
	end

	workerModel.Parent = self.CarriedFolder
	workerRoot.AssemblyLinearVelocity = Vector3.zero
	workerRoot.AssemblyAngularVelocity = Vector3.zero
	workerRoot.CFrame = root.CFrame * DEFAULT_CARRY_OFFSET

	-- Weld
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = workerRoot
	weld.Parent = workerRoot

	-- Temper movement modifiers
	local originalWalkSpeed = hum.WalkSpeed
	local temperDefinition = TemperConfig[worker.Temper]

	if temperDefinition then
		hum.WalkSpeed = originalWalkSpeed * temperDefinition.CarrierSpeedMultiplier
	end

	-- Register carry
	local carriedData: CarriedWorkerData = {
		Worker = worker,
		Carrier = carrier,
		OriginalOwnerUserId = originalOwnerUserId,
		OriginalFactory = originalFactory,
		OriginalSlotIndex = originalSlotIndex,
		OriginalWalkSpeed = originalWalkSpeed,
		PartStates = partStates,
		Weld = weld,
		DeathConnection = nil,
		CharacterRemovingConnection = nil,
	}

	self.CarriedWorkers[carrier.UserId] = carriedData
	self.BonkPending[carrier.UserId] = nil
	self.LastBonkAt[originalOwnerUserId] = nil

	-- Send carry pose to clients
	workerModel:SetAttribute("CarrierUserId", carrier.UserId)
	carryPoseChanged:FireAllClients(carrier, workerRoot, true)

	worker.State = "Carried"
	worker.FactoryId = nil
	worker.CarrierUserId = carrier.UserId
	worker:SetActivityState("Carried")

	-- Persistent state
	if not self.Inventory:SetWorkerCarriedByUserId(originalOwnerUserId, worker.Id, carrier.UserId) then
		self:ReturnCarriedWorker(carrier)

		return false
	end

	-- Recovery listeners
	carriedData.DeathConnection = hum.Died:Connect(function()
		self:ReturnCarriedWorker(carrier)
	end)

	carriedData.CharacterRemovingConnection = carrier.CharacterRemoving:Connect(function()
		self:ReturnCarriedWorker(carrier)
	end)

	local originalOwner = Players:GetPlayerByUserId(originalOwnerUserId)
	if originalOwner then
		inventoryUpdated:FireClient(originalOwner, worker.Id, "Carried")
	end

	-- Broadcast worker grabbed
	local ownedWorker = self.Inventory:GetWorkerByUserId(originalOwnerUserId, worker.Id)
	if ownedWorker then
		GameEvents.WorkerGrabbed:Fire(carrier, originalOwnerUserId, ownedWorker)
	end

	return true
end

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

	local carried = self:BeginCarryWorker(thief, worker, originalOwnerUserId, factory, slotIndex, nil)

	if carried then
		return true
	end

	-- Carry failed after worker detached, put back safely
	local restored = factory:PlaceWorkerInSlot(worker, slotIndex)
	if restored then
		return false
	end

	-- Last resort fallback, loose runtime worker still exists
	worker:DestroyModel()
	self.Inventory:SetWorkerStoredByUserId(originalOwnerUserId, worker.Id)

	return false
end

-- Drop worker --
function TheftService.DropCarriedWorker(self: TheftService, carrier: Player): boolean
	local carriedData = self.CarriedWorkers[carrier.UserId]
	if not carriedData then
		return false
	end

	local worker = carriedData.Worker
	local workerModel = worker.Model
	local workerRoot = worker:GetRootPart()

	if not workerModel or not workerRoot then
		return false
	end

	local char = carrier.Character
	local carrierRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not carrierRoot or not carrierRoot:IsA("BasePart") then
		return false
	end

	-- Determine ground position
	local forward = Vector3.new(carrierRoot.CFrame.LookVector.X, 0, carrierRoot.CFrame.LookVector.Z).Unit

	local rayOrigin = carrierRoot.Position + forward * 2 + Vector3.new(0, 3, 0)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local excludedInstances: { Instance } = { workerModel }
	if char then
		table.insert(excludedInstances, char)
	end

	rayParams.FilterDescendantsInstances = excludedInstances

	local result = workspace:Raycast(rayOrigin, Vector3.new(0, -12, 0), rayParams)

	local groundPosition = if result then result.Position else carrierRoot.Position + forward * 2
	local _boundsCFrame, boundsSize = workerModel:GetBoundingBox()
	local workerPosition = groundPosition + Vector3.new(0, boundsSize.Y * 0.5 + 0.1, 0)
	local dropCFrame = CFrame.lookAt(workerPosition, workerPosition + forward)

	-- End carry
	self:CleanupCarry(carrier, carriedData)
	self:RestoreWorkerPartStates(carriedData)

	-- Drop into world
	workerModel.Parent = self.DroppedFolder
	workerRoot.CFrame = dropCFrame
	workerRoot.AssemblyLinearVelocity = Vector3.zero
	workerRoot.AssemblyAngularVelocity = Vector3.zero

	worker:SetStationCFrame(dropCFrame)
	worker:SetUprightLocked(true)
	worker:SetActivityState("Idle")
	worker.State = "Dropped"
	worker.FactoryId = nil
	worker.CarrierUserId = nil

	self.Inventory:SetWorkerDroppedByUserId(carriedData.OriginalOwnerUserId, worker.Id)

	-- Instant pickup
	local definition = WorkerConfig[worker.WorkerType]

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DroppedWorkerPrompt"
	prompt.ActionText = "Grab"
	prompt.ObjectText = if definition then definition.DisplayName else worker.WorkerType
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt:SetAttribute("WorkerId", worker.Id)
	prompt.Parent = workerRoot

	self.DroppedWorkers[worker.Id] = {
		Worker = worker,
		OriginalOwnerUserId = carriedData.OriginalOwnerUserId,
		OriginalFactory = carriedData.OriginalFactory,
		OriginalSlotIndex = carriedData.OriginalSlotIndex,
		PartStates = carriedData.PartStates,
		Prompt = prompt,
	}

	local owner = Players:GetPlayerByUserId(carriedData.OriginalOwnerUserId)
	if owner then
		inventoryUpdated:FireClient(owner, worker.Id, "Dropped")
	end

	return true
end

function TheftService.TryPickupDroppedWorker(self: TheftService, plr: Player, workerId: string): boolean
	local droppedData = self.DroppedWorkers[workerId]
	if not droppedData then
		return false
	end

	local worker = droppedData.Worker
	local workerRoot = worker:GetRootPart()
	if not workerRoot then
		return false
	end

	local char = plr.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return false
	end

	if (root.Position - workerRoot.Position).Magnitude > 10 then
		return false
	end

	-- Original owner instantly recovers worker
	if plr.UserId == droppedData.OriginalOwnerUserId then
		return self:RecoverDroppedWorker(workerId)
	end

	-- Other players must have somewhere to steal it to
	if not self:GetFactoryOwnedByUserId(plr.UserId) then
		return false
	end

	if self.CarriedWorkers[plr.UserId] then
		return false
	end

	droppedData.Prompt.Enabled = false

	worker:SetUprightLocked(false)

	local success = self:BeginCarryWorker(
		plr,
		worker,
		droppedData.OriginalOwnerUserId,
		droppedData.OriginalFactory,
		droppedData.OriginalSlotIndex,
		droppedData.PartStates
	)

	if not success then
		if droppedData.Prompt.Parent then
			droppedData.Prompt.Enabled = true
		end

		return false
	end

	droppedData.Prompt:Destroy()

	self.DroppedWorkers[workerId] = nil

	return true
end

function TheftService.RecoverDroppedWorker(self: TheftService, workerId: string): boolean
	local droppedData = self.DroppedWorkers[workerId]
	if not droppedData then
		return false
	end

	droppedData.Prompt:Destroy()
	self.DroppedWorkers[workerId] = nil

	local worker = droppedData.Worker
	worker:SetUprightLocked(false)
	worker.State = "Stored"
	worker.FactoryId = nil
	worker.CarrierUserId = nil

	local factory = droppedData.OriginalFactory
	local slotIndex = droppedData.OriginalSlotIndex

	-- Put back where stolen from
	if not factory:IsSlotOccupied(slotIndex) then
		if worker.Model then
			worker.Model.Parent = factory.Model
		end

		local placed = factory:PlaceWorkerInSlot(worker, slotIndex)
		if placed then
			local updated = self.Inventory:SetWorkerPlacedByUserId(
				droppedData.OriginalOwnerUserId,
				worker.Id,
				factory.Id,
				slotIndex
			)
			if updated then
				local ownedWorker = self.Inventory:GetWorkerByUserId(droppedData.OriginalOwnerUserId, worker.Id)
				local owner = Players:GetPlayerByUserId(droppedData.OriginalOwnerUserId)
				if owner then
					inventoryUpdated:FireClient(owner, worker.Id, "Placed")
				end

				-- Broadcast worker recovered
				if ownedWorker then
					GameEvents.WorkerRecovered:Fire(droppedData.OriginalOwnerUserId, ownedWorker)
				end

				return true
			end
		end
	end

	-- Safety fallback if original slot is occupied
	worker:DestroyModel()
	self.Inventory:SetWorkerStoredByUserId(droppedData.OriginalOwnerUserId, worker.Id)

	return true
end

-- Bonk player --
function TheftService.TryBonkCarrier(self: TheftService, attacker: Player, target: Player): boolean
	if attacker == target then
		return false
	end

	local carriedData = self.CarriedWorkers[target.UserId]
	if not carriedData then
		return false
	end

	-- Only original owner can bonk someone carrying their worker
	if carriedData.OriginalOwnerUserId ~= attacker.UserId then
		return false
	end

	if self.BonkPending[target.UserId] then
		return false
	end

	local now = os.clock()
	local lastBonk = self.LastBonkAt[attacker.UserId] or 0

	if now - lastBonk < BONK_COOLDOWN then
		return false
	end

	local attackerChar = attacker.Character
	local targetChar = target.Character
	if not attackerChar or not targetChar then
		return false
	end

	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	if not attackerRoot or not attackerRoot:IsA("BasePart") or not targetRoot or not targetRoot:IsA("BasePart") then
		return false
	end

	if (attackerRoot.Position - targetRoot.Position).Magnitude > BONK_DISTANCE then
		return false
	end

	self.LastBonkAt[attacker.UserId] = now
	self.BonkPending[target.UserId] = true

	-- Play bonk animation
	bonkVisual:FireAllClients(attacker, target)

	-- Server is authoritative over impact
	task.delay(BONK_IMPACT_DELAY, function()
		local currentCarry = self.CarriedWorkers[target.UserId]
		if currentCarry ~= carriedData then
			self.BonkPending[target.UserId] = nil

			return
		end

		local dropped = self:DropCarriedWorker(target)
		if dropped then
			local direction = targetRoot.Position - attackerRoot.Position
			if direction.Magnitude > 0 then
				direction = direction.Unit
			end

			targetRoot.AssemblyLinearVelocity += direction * 13 + Vector3.new(0, 5, 0)
		end

		self.BonkPending[target.UserId] = nil
	end)

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

	worker:DestroyModel()

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

	local droppedWorkerIds: { string } = {}

	for workerId, droppedData in self.DroppedWorkers do
		if droppedData.OriginalOwnerUserId ~= ownerUserId then
			continue
		end

		table.insert(droppedWorkerIds, workerId)
	end

	for _, workerId in droppedWorkerIds do
		self:RecoverDroppedWorker(workerId)
	end
end

function TheftService.CleanupCarry(self: TheftService, carrier: Player, carriedData: CarriedWorkerData): ()
	-- Clear carry state first
	self.CarriedWorkers[carrier.UserId] = nil
	self.BonkPending[carrier.UserId] = nil

	-- Disconnect listeners
	if carriedData.DeathConnection then
		carriedData.DeathConnection:Disconnect()
		carriedData.DeathConnection = nil
	end

	if carriedData.CharacterRemovingConnection then
		carriedData.CharacterRemovingConnection:Disconnect()
		carriedData.CharacterRemovingConnection = nil
	end

	-- Stop procedural carry pose
	local workerModel = carriedData.Worker.Model
	if workerModel then
		workerModel:SetAttribute("CarrierUserId", nil)
	end

	carryPoseChanged:FireAllClients(carrier, nil, false)

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

function TheftService.RestoreWorkerPartStates(_self: TheftService, carriedData: CarriedWorkerData): ()
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
	worker:DestroyModel()

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
