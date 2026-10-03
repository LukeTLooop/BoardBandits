--!strict
-- Worker Service

local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local WorkerInventoryService = require(ServerScriptService.Services.WorkerInventoryService)
local Worker = require(ServerScriptService.Classes.Worker)

local WorkerService = {}
WorkerService.__index = WorkerService

type WorkerServiceData = {
	Workers: { [string]: Worker.Worker },
	Started: boolean,
}

export type WorkerService = typeof(setmetatable({} :: WorkerServiceData, WorkerService))

function WorkerService.new(): WorkerService
	local data: WorkerServiceData = {
		Workers = {},
		Started = false,
	}

	return setmetatable(data, WorkerService)
end

function WorkerService.CreateWorker(self: WorkerService, workerType: string, ownerUserId: number): Worker.Worker
	local worker = Worker.new(workerType, ownerUserId, nil, nil, nil, nil)

	self.Workers[worker.Id] = worker

	return worker
end

function WorkerService.CreateWorkerFromOwnedData(
	self: WorkerService,
	workerData: WorkerInventoryService.OwnedWorkerData,
	ownerUserId: number
): Worker.Worker
	-- Don't create two runtime versions of same worker
	local existing = self.Workers[workerData.Id]
	if existing then
		return existing
	end

	local worker = Worker.new(
		workerData.WorkerType,
		ownerUserId,
		workerData.Id,
		workerData.Level,
		workerData.Temper,
		workerData.State
	)

	self.Workers[worker.Id] = worker

	return worker
end

function WorkerService.DestroyWorker(self: WorkerService, workerId: string): ()
	local worker = self.Workers[workerId]
	if not worker then
		return
	end

	worker:StopWorking()

	if worker.Model then
		worker.Model:Destroy()
		worker.Model = nil
	end

	self.Workers[workerId] = nil
end

function WorkerService.DestroyWorkersForOwner(
	self: WorkerService,
	ownerUserId: number,
	preserveCarried: boolean?
): ()
	local workerIds: { string } = {}

	-- Snapshot first because DestroyWorker mutates self.Workers.
	for workerId, worker in self.Workers do
		if worker.OwnerUserId ~= ownerUserId then
			continue
		end

		if preserveCarried and worker.State == "Carried" then
			continue
		end

		table.insert(workerIds, workerId)
	end

	for _, workerId in workerIds do
		self:DestroyWorker(workerId)
	end
end

function WorkerService.GetWorker(self: WorkerService, workerId: string): Worker.Worker?
	return self.Workers[workerId]
end

function WorkerService.Start(self: WorkerService)
	if self.Started then
		return
	end
	self.Started = true

	RunService.Heartbeat:Connect(function(dt)
		for _, worker in self.Workers do
			worker:Update(dt)
		end
	end)
end

return WorkerService
