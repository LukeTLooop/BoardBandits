--!strict
-- Event Types

-- Types --
export type StopReason = "Manual" | "Expired" | "Shutdown"

export type EventContext = {
	EventId: string,
	OwnerId: string,

	AddCleanup: (self: EventContext, callback: () -> ()) -> (),
	SetModifier: (self: EventContext, preset: string, priority: number) -> (),
	SetMusic: (self: EventContext, track: string, priority: number?) -> (),
}

export type EventDefinition = {
	Id: string,
	Duration: number?,
	Priority: number?,

	OnStart: (context: EventContext) -> (),
	OnStop: ((context: EventContext, reason: StopReason) -> ())?,
}

export type ActiveEventInfo = {
	Id: string,
	OwnerId: string,
	StartedAt: number,
	EndsAt: number?,
}

return {}
