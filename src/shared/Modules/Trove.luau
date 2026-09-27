--!strict
-- Guarda conexões, instâncias e funções de limpeza para destruí-las de uma vez.
-- Uso: local trove = Trove.new(); trove:Connect(evento, fn); trove:Add(parte); ... trove:Clean()

type Cleanable =
	RBXScriptConnection
	| Instance
	| () -> () | { Destroy: (any) -> () } | { Disconnect: (any) -> () }

export type Trove = {
	Add: <T>(self: Trove, object: T) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, callback: (...any) -> ()) -> RBXScriptConnection,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
}

local function cleanObject(object: any)
	local objectType = typeof(object)
	if objectType == "RBXScriptConnection" then
		object:Disconnect()
	elseif objectType == "Instance" then
		object:Destroy()
	elseif objectType == "function" then
		object()
	elseif objectType == "table" then
		if type(object.Destroy) == "function" then
			object:Destroy()
		elseif type(object.Disconnect) == "function" then
			object:Disconnect()
		end
	end
end

local Trove = {}

function Trove.new(): Trove
	local objects: { Cleanable } = {}
	local self = {} :: Trove

	function self:Add<T>(object: T): T
		table.insert(objects, object :: any)
		return object
	end

	function self:Connect(signal: RBXScriptSignal, callback: (...any) -> ()): RBXScriptConnection
		return self:Add(signal:Connect(callback))
	end

	function self:Clean()
		-- Limpa na ordem inversa de criação.
		for index = #objects, 1, -1 do
			local object = objects[index]
			objects[index] = nil
			local ok, err = pcall(function()
				cleanObject(object)
			end)
			if not ok then
				warn(`[Trove] Falha ao limpar objeto: {err}`)
			end
		end
	end

	self.Destroy = self.Clean

	return self
end

return Trove
