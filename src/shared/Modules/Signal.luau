--!strict
-- Evento interno simples para comunicação entre módulos do MESMO lado (servidor↔servidor ou cliente↔cliente).
-- Para servidor↔cliente use o Net.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, callback: (...any) -> ()) -> Connection,
	Once: (self: Signal, callback: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	Wait: (self: Signal) -> ...any,
	DisconnectAll: (self: Signal) -> (),
}

type Listener = {
	callback: (...any) -> (),
	connection: Connection,
}

local Signal = {}

function Signal.new(): Signal
	local listeners: { Listener } = {}
	local self = {} :: Signal

	local function removeListener(listener: Listener)
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end

	function self:Connect(callback: (...any) -> ()): Connection
		local listener: Listener
		local connection = {} :: Connection
		connection.Connected = true
		function connection:Disconnect()
			if connection.Connected then
				connection.Connected = false
				removeListener(listener)
			end
		end
		listener = { callback = callback, connection = connection }
		table.insert(listeners, listener)
		return connection
	end

	function self:Once(callback: (...any) -> ()): Connection
		local connection: Connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			callback(...)
		end)
		return connection
	end

	function self:Fire(...: any)
		-- Copia a lista para que conectar/desconectar durante o Fire seja seguro.
		for _, listener in table.clone(listeners) do
			if listener.connection.Connected then
				task.spawn(listener.callback, ...)
			end
		end
	end

	function self:Wait(): ...any
		local thread = coroutine.running()
		self:Once(function(...)
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end

	function self:DisconnectAll()
		for _, listener in listeners do
			listener.connection.Connected = false
		end
		table.clear(listeners)
	end

	return self
end

return Signal
