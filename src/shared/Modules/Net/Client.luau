--!strict
local Modules = script.Parent.Parent
local Shared = Modules.Parent

local GameConfig = require(Shared.Config.GameConfig)
local InstanceUtil = require(Modules.InstanceUtil)
local RemoteSchema = require(Modules.RemoteSchema)

local REMOTE_WAIT_TIMEOUT = 5

local NetClient = {}

local remotes: { [string]: RemoteEvent | RemoteFunction } = {}
local initialized = false

local function getRemote(name: string, kind: "Event" | "Function"): RemoteEvent | RemoteFunction
	assert(initialized, "[Net] Net.Client.init() ainda não foi chamado")
	local spec = RemoteSchema[name]
	if not spec then
		error(`[Net] Remote "{name}" não existe no RemoteSchema.`, 3)
	end
	if spec.Kind ~= kind then
		error(`[Net] {name} é do tipo {spec.Kind}, não {kind}.`, 3)
	end
	return remotes[name]
end

-- Espera o servidor publicar os Remotes (com timeout). Chamado uma vez pelo ClientMain.
function NetClient.init()
	if initialized then
		return
	end
	local folder = InstanceUtil.waitForChild(Shared, "Remotes", GameConfig.REMOTES_WAIT_TIMEOUT)
	for name in RemoteSchema do
		remotes[name] = InstanceUtil.waitForChild(folder, name, REMOTE_WAIT_TIMEOUT) :: any
	end
	initialized = true
end

function NetClient.fire(name: string, ...: any)
	local remote = getRemote(name, "Event") :: RemoteEvent
	remote:FireServer(...)
end

-- Retorna (true, resultado) em caso de sucesso ou (false, motivo) em caso de rejeição/erro.
function NetClient.invoke(name: string, ...: any): (boolean, any)
	local remote = getRemote(name, "Function") :: RemoteFunction
	local ok, serverOk, result = pcall(remote.InvokeServer, remote, ...)
	if not ok then
		return false, "InvokeFailed"
	end
	return serverOk == true, result
end

function NetClient.on(name: string, handler: (...any) -> ()): RBXScriptConnection
	local remote = getRemote(name, "Event") :: RemoteEvent
	return remote.OnClientEvent:Connect(handler)
end

return NetClient
