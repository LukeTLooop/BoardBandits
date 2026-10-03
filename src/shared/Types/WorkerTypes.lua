--!strict
-- Shared worker types

export type WorkerTemper = 
	"Mild" |
	"Normal" |
	"Feisty" |
	"Wild"

export type WorkerLocationState = 
	"Stored" |
	"Placed" |
	"Carried"

export type OwnedWorkerData = {
	Id: string,
	WorkerType: string,
	Level: number,
	
	Temper: WorkerTemper,
	State: WorkerLocationState,
	
	FactoryId: string?,
	SlotIndex: number?,
	CarrierUserId: number?,
}

export type ClientWorkerData = {
	Id: string,
	WorkerType: string,
	Level: number,
	
	Temper: WorkerTemper,
	State: WorkerLocationState,
	
	IsPlaced: boolean,
}

return {}
