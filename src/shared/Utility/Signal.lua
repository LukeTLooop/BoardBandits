--!strict
-- Signal

local Signal = {}
Signal.__index = Signal

-- Public Types --
export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (
		self: Signal<T...>,
		callback: (T...) -> ()
	) -> Connection,
	
	Once: (
		self: Signal<T...>,
		callback: (T...) -> ()
	) -> Connection,
	
	Fire: (
		self: Signal<T...>,
		T...
	) -> (),
	
	Wait: (
		self: Signal<T...>
	) -> T...,
	
	Destroy: (
		self: Signal<T...>
	) -> (),
}

-- Internal Types --
type SignalData = {
	Connections: {ConnectionData},
	Destroyed: boolean,
}

type ConnectionData = {
	Connected: boolean,
	Callback: (...any) -> (),
	Signal: SignalData?,
}

-- Connection --
local Connection = {}
Connection.__index = Connection

function Connection.Disconnect(
	self: ConnectionData
): ()
	if not self.Connected then return end
	self.Connected = false
	
	local signal = self.Signal
	self.Signal = nil
	
	if not signal then return end
	
	local index = table.find(
		signal.Connections,
		self
	)
	
	if index then
		table.remove(
			signal.Connections,
			index
		)
	end
end

-- Constructor --
function Signal.new<T...>(): Signal<T...>
	local data: SignalData = {
		Connections = {},
		Destroyed = false,
	}
	
	return setmetatable(
		data,
		Signal
	) :: any
end

-- Connect --
function Signal.Connect<T...>(
	self: Signal<T...>,
	callback: (T...) -> ()
): Connection
	local internalSelf = self :: any
	
	assert(
		not internalSelf.Destroyed,
		"Cannot connect to destroyed Signal!"
	)
	
	local connection: ConnectionData = {
		Connected = true,
		Callback = callback :: any,
		Signal = internalSelf,
	}
	
	table.insert(
		internalSelf.Connections,
		connection
	)
	
	return setmetatable(
		connection,
		Connection
	) :: any
end

-- Once --
function Signal.Once<T...>(
	self: Signal<T...>,
	callback: (T...) -> ()
): Connection
	local connection: Connection?
	
	connection = self:Connect(function(
		...: T...
	)
		if connection then
			connection:Disconnect()
		end
		
		callback(...)
	end)
	
	return connection
end

-- Fire --
function Signal.Fire<T...>(
	self: Signal<T...>,
	...: T...
): ()
	local internalSelf = self :: any
	if internalSelf.Destroyed then return end
	
	-- Snapshot connections
	local connections = table.clone(internalSelf.Connections)
	
	for _, connection in connections do
		if not connection.Connected then continue end
		
		connection.Callback(...)
	end
end

-- Wait --
function Signal.Wait<T...>(
	self: Signal<T...>
): T...
	local thread = coroutine.running()
	
	local connection: Connection?
	
	connection = self:Connect(function(
		...: T...
	)
		if connection then
			connection:Disconnect()
		end
		
		task.spawn(
			thread,
			...
		)
	end)
	
	return coroutine.yield()
end

-- Destroy --
function Signal.Destroy<T...>(
	self: Signal<T...>
): ()
	local internalSelf = self :: any
	
	if internalSelf.Destroyed then return end
	internalSelf.Destroyed = true
	
	local connections = table.clone(internalSelf.Connections)
	
	for _, connection in connections do
		connection:Disconnect()
	end
	
	table.clear(internalSelf.Connections)
end

return Signal
