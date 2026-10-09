--!strict
-- Customer Types

local CustomerTypes = {}

export type Status = "Queue" | "Ordering" | "Waiting" | "Success" | "Failed" | "Leaving"

CustomerTypes.Tag = "FactoryCustomer"

CustomerTypes.Attributes = {
	Id = "CustomerId",
	Type = "CustomerType",

	OwnerUserId = "CustomerOwnerUserId",
	FactoryId = "CustomerFactoryId",

	Status = "CustomerStatus",
	QueueIndex = "CustomerQueueIndex",

	DesiredItem = "CustomerDesiredItem",

	WaitEndTime = "CustomerWaitEndTime",
	MaxWaitTime = "CustomerMaxWaitTime",
}

return CustomerTypes
