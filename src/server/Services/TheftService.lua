--!strict
-- Theft service

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local WorkerInventoryService = require(ServerScriptService.Services.WorkerInventoryService)

local Factory = require(ServerScriptService.Classes.Factory)
local Worker = require(ServerScriptService.Classes.Worker)

local TemperConfig = require(ReplicatedStorage.Shared.Config.TemperConfig)

local GameEvents = require(ServerScriptService.Framework.GameEvents)

local workerRemotes = ReplicatedStorage.Remotes.Workers

local inventoryUpdated = workerRemotes.InventoryUpdated
assert(inventoryUpdated:IsA("RemoteEvent"), "InventoryUpdated must be a RemoteEvent!")

-- Helpers --
local function isPointInsidePart(
	part: BasePart,
	worldPosition: Vector3
): boolean
	-- Convert world position into part's local space
	local localPosition = part.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = part.Size * 0.5

	return
		math.abs(localPosition.X) <= halfSize.X and
		math.abs(localPosition.Y) <= halfSize.Y and
		math.abs(localPosition.Z) <= halfSize.Z
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
	PartStates: {[BasePart]: PartState},
	Weld: WeldConstraint?,
	DeathConnection: RBXScriptConnection?,
	CharacterRemovingConnection: RBXScriptConnection?,
}

type TheftServiceData = {
	Inventory: WorkerInventoryService.WorkerInventoryService,
	Factories: {[string]: Factory.Factory},
	CarriedWorkers: {[number]: CarriedWorkerData},
	CarriedFolder: Folder,
	Started: boolean,
}

export type TheftService = typeof(setmetatable({} :: TheftServiceData, TheftService))

-- Constructor --
function TheftService.new(
	inventory: WorkerInventoryService.WorkerInventoryService
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
		CarriedWorkers = {},
		CarriedFolder = carriedFolder,
		Started = false,
	}
	
	return setmetatable(
		data,
		TheftService
	)
end

-- Factory Registration --
function TheftService.RegisterFactory(
	self: TheftService,
	factory: Factory.Factory
): ()
	self.Factories[factory.Id] = factory
end

function TheftService.UnregisterFactory(
	self: TheftService,
	factoryId: string
): ()
	self.Factories[factoryId] = nil
end

-- Start --
function TheftService.Start(
	self: TheftService
): ()
	if self.Started then return end
	self.Started = true
	
	-- Theft prompts
	ProximityPromptService.PromptTriggered:Connect(function(
		prompt: ProximityPrompt,
		plr: Player
	)
		if prompt.Name ~= "StealPrompt" then return end
		
		local factoryId = prompt:GetAttribute("FactoryId")
		local slotIndex = prompt:GetAttribute("SlotIndex")
		local workerId = prompt:GetAttribute("WorkerId")
		
		if typeof(factoryId) ~= "string" then return end
		if typeof(slotIndex) ~= "number" then return end
		if typeof(workerId) ~= "string" then return end
		
		local factory = self.Factories[factoryId]
		if not factory then return end
		
		local worker = factory:GetWorkerInSlot(slotIndex)
		if not worker then return end
		
		-- Prevent stale/spoofed prompt data
		if worker.Id ~= workerId then return end
		
		self:TryGrabWorker(
			plr,
			factory,
			slotIndex
		)
	end)
	
	-- Territory detection
	local territoryElapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		territoryElapsed += dt
		if territoryElapsed < 0.1 then return end
		
		territoryElapsed = 0
		
		-- Snapshot players because ClaimCarriedWorker modifies CarriedWorkers
		local carriers: {Player} = {}
		
		for _, carriedData in self.CarriedWorkers do
			table.insert(
				carriers,
				carriedData.Carrier
			)
		end
		
		for _, carrier in carriers do
			self:CheckCarriedWorkerTerritory(
				carrier
			)
		end
	end)
	
	-- Carrier leaves server
	Players.PlayerRemoving:Connect(function(
		plr: Player
	)
		if self.CarriedWorkers[plr.UserId] then
			self:ReturnCarriedWorker(plr)
		end
	end)
end

-- Query --
function TheftService.GetCarriedWorker(
	self: TheftService,
	plr: Player
): Worker.Worker?
	local data = self.CarriedWorkers[plr.UserId]
	if not data then
		return nil
	end
	
	return data.Worker
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
	
	local thiefFactory = self:GetFactoryOwnedByUserId(
		thief.UserId
	)
	
	if not thiefFactory then
		warn(
			"[THEFT]",
			thief.Name,
			"tried to steal without owning a factory"
		)
		
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
	
	-- Validate ownership data
	local ownedWorker = self.Inventory:GetWorkerByUserId(
		worker.OwnerUserId,
		worker.Id
	)
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
	
	-- Save original position information
	local originalOwnerUserId = worker.OwnerUserId
	
	-- Detach from factory
	local detachedWorker = factory:DetachWorkerFromSlot(slotIndex)
	if detachedWorker ~= worker then
		return false
	end
	
	-- Save original part properties
	local partStates: {[BasePart]: PartState} = {}
	
	for _, descendant in workerModel:GetDescendants() do
		if not descendant:IsA("BasePart") then continue end
		
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
	workerModel:PivotTo(
		carryPart.CFrame * CFrame.new(
			0,
			0,
			-2.5
		)
	)
	
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
	
	-- Update owned worker state
	local stateUpdated = self.Inventory:SetWorkerCarriedByUserId(
		originalOwnerUserId,
		worker.Id,
		thief.UserId
	)
	
	if not stateUpdated then
		warn("[THEFT] Failed to set inventory worker carried state")
		
		return false
	end

	-- Update state
	worker.State = "Carried"
	worker.CarrierUserId = thief.UserId
	
	-- Verify synchronization
	local updatedOwnedWorker = self.Inventory:GetWorkerByUserId(
		originalOwnerUserId,
		worker.Id
	)
	
	if not updatedOwnedWorker then
		warn("[THEFT] Worker disappeared from owner's inventory after grab")
		
		return false
	end
	
	print(
		"[THEFT] Carry state synchronized",
		"Worker:",
		worker.Id,
		"Runtime Carrier:",
		worker.CarrierUserId,
		"Inventory Carrier:",
		updatedOwnedWorker.CarrierUserId,
		"Thief:",
		thief.UserId
	)
	
	local success = self.Inventory:SetWorkerCarriedByUserId(
		originalOwnerUserId,
		worker.Id,
		thief.UserId
	)
	
	if not success then
		warn(
			"[THEFT] Failed to mark owned worker as Carried"
		)

		-- This is a bad partial state.
		-- Return it immediately.
		self:ReturnCarriedWorker(
			thief
		)

		return false
	end
	
	-- Tell original owner client worker has left factory
	local originalOwnerPlayer = Players:GetPlayerByUserId(
		originalOwnerUserId
	)
	
	if originalOwnerPlayer then
		inventoryUpdated:FireClient(
			originalOwnerPlayer,
			worker.Id,
			"Carried"
		)
	end
	
	-- Register carried worker
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
	
	-- Carrier dies
	carriedData.DeathConnection = hum.Died:Connect(function()
		self:ReturnCarriedWorker(thief)
	end)
	
	-- Carrier resets/char disappears
	carriedData.CharacterRemovingConnection = thief.CharacterRemoving:Connect(function()
		self:ReturnCarriedWorker(thief)
	end)
	
	GameEvents.WorkerGrabbed:Fire(
		thief,
		originalOwnerUserId,
		ownedWorker
	)
	
	return true
end

-- Return worker --
function TheftService.ReturnCarriedWorker(
	self: TheftService,
	carrier: Player
): boolean
	local carriedData = self.CarriedWorkers[carrier.UserId]
	if not carriedData then
		return false
	end
	
	local worker = carriedData.Worker
	local originalFactory = carriedData.OriginalFactory
	local originalSlotIndex = carriedData.OriginalSlotIndex
	local originalOwnerUserId = carriedData.OriginalOwnerUserId
	
	-- Finish carry state
	self:CleanupCarry(
		carrier,
		carriedData
	)
	
	self:RestoreWorkerPartStates(
		carriedData
	)
	
	worker.CarrierUserId = nil
	worker.FactoryId = nil
	worker.State = "Stored"
	
	-- Try original slot first
	if not originalFactory:IsSlotOccupied(originalSlotIndex) then
		if worker.Model then
			worker.Model.Parent = originalFactory.Model
		end
		
		local placed = originalFactory:PlaceWorkerInSlot(
			worker,
			originalSlotIndex
		)
		
		if placed then
			self.Inventory:SetWorkerPlacedByUserId(
				originalOwnerUserId,
				worker.Id,
				originalFactory.Id,
				originalSlotIndex
			)

			local ownerPlayer = Players:GetPlayerByUserId(
				originalOwnerUserId
			)

			if ownerPlayer then
				inventoryUpdated:FireClient(
					ownerPlayer,
					worker.Id,
					"Placed"
				)
			end
			
			return true
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
	
	self.Inventory:SetWorkerStoredByUserId(
		originalOwnerUserId,
		worker.Id
	)

	local ownerPlayer = Players:GetPlayerByUserId(
		originalOwnerUserId
	)

	if ownerPlayer then
		inventoryUpdated:FireClient(
			ownerPlayer,
			worker.Id,
			"Stored"
		)
	end
	
	GameEvents.WorkerRecovered:Fire(
		originalOwnerUserId,
		worker
	)
	
	return true
end

function TheftService.CleanupCarry(
	self: TheftService,
	carrier: Player,
	carriedData: CarriedWorkerData
): ()
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
	if not char then return end
	
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	
	hum.WalkSpeed = carriedData.OriginalWalkSpeed
end

function TheftService.RestoreWorkerPartStates(
	self: TheftService,
	carriedData: CarriedWorkerData
): ()
	for part, state in carriedData.PartStates do
		if not part.Parent then continue end
		
		part.Anchored = state.Anchored
		part.CanCollide = state.CanCollide
		part.Massless = state.Massless
	end
end

function TheftService.ClaimCarriedWorker(
	self: TheftService,
	carrier: Player,
	factory: Factory.Factory
): boolean

	print(
		"[THEFT] Claim attempt:",
		carrier.Name,
		"Factory:",
		factory.Id
	)

	-- Must own destination factory
	if factory.OwnerUserId ~= carrier.UserId then
		warn(
			"[THEFT] Failed: destination factory not owned by carrier"
		)

		return false
	end
	
	local carriedData = self.CarriedWorkers[carrier.UserId]
	if not carriedData then
		warn(
			"[THEFT] Failed: carrier has no CarriedWorkers entry"
		)

		return false
	end
	
	local worker = carriedData.Worker
	local originalOwnerUserId = carriedData.OriginalOwnerUserId
	
	-- Can't steal own worker
	if originalOwnerUserId == carrier.UserId then
		warn(
			"[THEFT] Failed: original owner is carrier"
		)

		return false
	end
	
	-- Validate original ownership state
	local ownedWorker = self.Inventory:GetWorkerByUserId(
		originalOwnerUserId,
		worker.Id
	)
	
	if not ownedWorker then
		warn(
			"[THEFT] Failed: original owner's inventory record missing"
		)

		return false
	end

	print(
		"[THEFT] Owned worker state:",
		ownedWorker.State,
		"Carrier:",
		ownedWorker.CarrierUserId
	)

	
	if ownedWorker.State ~= "Carried" then
		warn(
			"[THEFT] Failed: owned worker isn't in Carried state"
		)

		return false
	end
	
	if ownedWorker.CarrierUserId ~= carrier.UserId then
		warn(
			"[THEFT] Failed: CarrierUserId mismatch"
		)

		return false
	end
	
	-- Transfer ownership
	local transferred = self.Inventory:TransferWorkerOwnership(
		originalOwnerUserId,
		carrier.UserId,
		worker.Id
	)
	
	if not transferred then
		warn(
			"[THEFT] Failed: TransferWorkerOwnership returned nil"
		)

		self:ReturnCarriedWorker(
			carrier
		)
		
		return false
	end

	print(
		"[THEFT] Ownership transferred successfully"
	)

	-- Carry is finished
	self:CleanupCarry(
		carrier,
		carriedData
	)
	
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
	
	print(
		carrier.Name,
		"stole",
		worker.WorkerType,
		"from user",
		originalOwnerUserId
	)
	
	local originalOwner = Players:GetPlayerByUserId(
		originalOwnerUserId
	)
	
	if originalOwner then
		inventoryUpdated:FireClient(
			originalOwner,
			worker.Id,
			"Removed"
		)
	end
	
	inventoryUpdated:FireClient(
		carrier,
		worker.Id,
		"Stored"
	)
	
	GameEvents.WorkerStolen:Fire(
		carrier,
		originalOwnerUserId,
		worker
	)
	
	return true
end

function TheftService.CheckCarriedWorkerTerritory(
	self: TheftService,
	carrier: Player
): ()
	local carriedData = self.CarriedWorkers[carrier.UserId]
	if not carriedData then return end
	
	-- Character
	local char = carrier.Character
	if not char then return end
	
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	
	-- Find carrier's factory
	for _, factory in self.Factories do
		if factory.OwnerUserId ~= carrier.UserId then continue end
		
		local territory = factory.Model:FindFirstChild("Territory")
		if not territory or not territory:IsA("BasePart") then return end
		
		-- Check if player is inside
		if not isPointInsidePart(territory, root.Position) then return end
		
		-- Theft complete
		self:ClaimCarriedWorker(
			carrier,
			factory
		)
		
		return
	end
end

function TheftService.GetFactoryOwnedByUserId(
	self: TheftService,
	userId: number
): Factory.Factory?
	for _, factory in self.Factories do
		if factory.OwnerUserId ~= userId then continue end
		
		return factory
	end
	
	return nil
end

return TheftService
