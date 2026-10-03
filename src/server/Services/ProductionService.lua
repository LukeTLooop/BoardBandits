--!strict
-- Production Service --

-- Services --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Config --
local ProductionStationConfig = require(ReplicatedStorage.Shared.Config.ProductionStationConfig)

-- Classes --
local Factory = require(ServerScriptService.Classes.Factory)

-- Framework --
local GameEvents = require(ServerScriptService.Framework.GameEvents)

-- Service --
local ProductionService = {}
ProductionService.__index = ProductionService

-- Types --
export type ProductionSource =
	"Manual" |
	"Worker" |
	"Assembler"

type ManualProductionJob = {
	Player: Player,

	Factory: Factory.Factory,

	StationId: string,
	SlotIndex: number,

	OutputItem: string,
	OutputAmount: number,

	StartedAt: number,
	Duration: number,
}

type ProductionServiceData = {
	ActiveJobs: {[number]: ManualProductionJob},

	Started: boolean,
}

export type ProductionService = typeof(setmetatable({} :: ProductionServiceData, ProductionService))

-- Constructor --
function ProductionService.new(): ProductionService
	local data: ProductionServiceData = {
		ActiveJobs = {},

		Started = false,
	}
	
	return setmetatable(
		data,
		ProductionService
	)
end

-- Add Production Output --
function ProductionService.AddProductionOutput(
	self: ProductionService,
	factory: Factory.Factory,
	itemId: string,
	amount: number,
	source: ProductionSource,
	workerId: string?
): boolean
	if amount <= 0 then
		return false
	end

	-- Add to factory inventory
	factory:AddItem(
		itemId,
		amount
	)

	-- Broadcast production
	GameEvents.ItemProduced:Fire(
		factory.OwnerUserId,
		factory.Id,
		itemId,
		amount
	)

	print(
		"[PRODUCTION]",
		source,
		"produced",
		amount,
		itemId,
		"in",
		factory.Id,
		workerId or ""
	)

	return true
end

-- Is Producing --
function ProductionService.IsProducing(
	self: ProductionService,
	plr: Player
): boolean
	return self.ActiveJobs[plr.UserId] ~= nil
end

-- Start Manual Production --
function ProductionService.StartManualProduction(
	self: ProductionService,
	plr: Player,
	factory: Factory.Factory,
	slotIndex: number,
	stationId: string
): boolean
	-- Must own factory
	if factory.OwnerUserId ~= plr.UserId then
		return false
	end

	-- Only one manual job at a time
	if self.ActiveJobs[plr.UserId] then
		return false
	end

	-- Valid slot
	if slotIndex < 1 or slotIndex > factory:GetSlotCount() then
		return false
	end

	-- Worker already automating station
	if factory:IsSlotOccupied(slotIndex) then
		return false
	end
	
	-- Valid station
	local definition = ProductionStationConfig[stationId]
	if not definition then
		warn(
			"[PRODUCTION] Unknown station:",
			stationId
		)

		return false
	end
	
	-- Start job
	local job: ManualProductionJob = {
		Player = plr,

		Factory = factory,
		StationId = stationId,
		SlotIndex = slotIndex,
		
		OutputItem = definition.OutputItem,
		OutputAmount = definition.OutputAmount,
		
		StartedAt = os.clock(),
		Duration = definition.ProductionTime,
	}
	
	self.ActiveJobs[plr.UserId] = job

	print(
		"[PRODUCTION]",
		plr.Name,
		"started",
		stationId
	)
	
	-- Complete async
	task.delay(job.Duration, function()
		self:CompleteManualProduction(
			plr,
			job
		)
	end)
	
	return true
end

-- Complete Production --
function ProductionService.CompleteManualProduction(
	self: ProductionService,
	plr: Player,
	expectedJob: ManualProductionJob
): boolean
	local currentJob = self.ActiveJobs[plr.UserId]
	if not currentJob then
		return false
	end

	-- Job was cancelled or replaced
	if currentJob ~= expectedJob then
		return false
	end
	
	-- Clear job
	self.ActiveJobs[plr.UserId] = nil

	-- Player left
	if plr.Parent ~= Players then
		return false
	end
	
	-- Still owns same factory
	local factory = expectedJob.Factory
	
	-- Ownership changed
	if factory.OwnerUserId ~= plr.UserId then
		return false
	end

	-- Station became automated while manually producing
	if factory:IsSlotOccupied(expectedJob.SlotIndex) then
		return false
	end
	
	-- Produce
	self:AddProductionOutput(
		factory,
		expectedJob.OutputItem,
		expectedJob.OutputAmount,
		"Manual",
		nil
	)

	return true
end

-- Cancel --
function ProductionService.CancelManualProduction(
	self: ProductionService,
	plr: Player
): ()
	local job = self.ActiveJobs[plr.UserId]
	if not job then return end

	self.ActiveManualJobs[plr.UserId] = nil

	print(
		"[PRODUCTION]",
		plr.Name,
		"cancelled",
		job.StationId
	)
end

-- Start --
function ProductionService.Start(
	self: ProductionService
): ()
	if self.Started then return end
	self.Started = true

	-- Leaving
	Players.PlayerRemoving:Connect(function(plr: Player)
		self:CancelManualProduction(plr)
	end)
end

return ProductionService
