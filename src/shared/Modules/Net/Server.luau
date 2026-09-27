--!strict
local Players = game:GetService("Players")

local Modules = script.Parent.Parent
local Shared = Modules.Parent

local Log = require(Modules.Log)
local RateLimiter = require(Modules.RateLimiter)
local RemoteSchema = require(Modules.RemoteSchema)
local Signal = require(Modules.Signal)
local T = require(script.Parent.T)

type RemoteSpec = RemoteSchema.RemoteSpec
type ServerHandler = (player: Player, ...any) -> ...any

local FOLDER_NAME = "Remotes"

local log = Log.new("Net")

local NetServer = {}

-- Disparado a cada chamada rejeitada: (player, nomeDoRemote, motivo). Base para o anti-abuso.
NetServer.Violation = Signal.new()

local folder: Folder? = nil
local remotes: { [string]: RemoteEvent | RemoteFunction } = {}
local limiters: { [string]: RateLimiter.RateLimiter } = {}
local boundHandlers: { [string]: boolean } = {}

local function getSpec(name: string): RemoteSpec
	local spec = RemoteSchema[name]
	if not spec then
		error(`[Net] Remote "{name}" não existe no RemoteSchema.`, 3)
	end
	return spec
end

local function reject(player: Player, name: string, reason: string)
	if reason == "RateLimited" then
		log:Debug("Rejeitado %s de %s: %s", name, player.Name, reason)
	else
		log:Warn("Rejeitado %s de %s: %s", name, player.Name, reason)
	end
	NetServer.Violation:Fire(player, name, reason)
end

local function validate(
	player: Player,
	name: string,
	spec: RemoteSpec,
	argCount: number,
	args: { any }
): (boolean, string?)
	local limiter = limiters[name]
	if limiter and not limiter:Check(player) then
		return false, "RateLimited"
	end

	local validators: { T.Validator } = spec.Args or {}
	if argCount > #validators then
		return false, "TooManyArgs"
	end
	for index, validator in validators do
		local ok, reason = validator(args[index])
		if not ok then
			return false, `Arg{index}: {reason}`
		end
	end
	return true, nil
end

function NetServer.init()
	assert(folder == nil, "[Net] init() chamado duas vezes")

	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME

	for name, spec in RemoteSchema do
		local remote = Instance.new(if spec.Kind == "Function" then "RemoteFunction" else "RemoteEvent")
		remote.Name = name
		remote.Parent = newFolder
		remotes[name] = remote :: any

		if spec.Direction == "ClientToServer" then
			assert(spec.RateLimit, `[Net] {name} precisa de RateLimit no RemoteSchema`)
			limiters[name] = RateLimiter.new(spec.RateLimit.Max, spec.RateLimit.Per)
		elseif remote:IsA("RemoteEvent") then
			-- Cliente nunca deveria disparar um evento servidor → cliente.
			remote.OnServerEvent:Connect(function(player: Player)
				reject(player, name, "WrongDirection")
			end)
		end
	end

	folder = newFolder

	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:Reset(player)
		end
	end)

	NetServer.handle("Ping", function()
		return workspace:GetServerTimeNow()
	end)
end

-- Torna os Remotes visíveis aos clientes. Chamado DEPOIS do Init de todos os serviços,
-- para que nenhum cliente consiga chamar um Remote antes do handler existir.
function NetServer.publish()
	assert(folder, "[Net] publish() antes de init()")
	folder.Parent = Shared
end

-- Recebe um RemoteEvent cliente → servidor.
function NetServer.on(name: string, handler: ServerHandler)
	local spec = getSpec(name)
	assert(
		spec.Kind == "Event" and spec.Direction == "ClientToServer",
		`[Net] {name} não é um evento cliente → servidor`
	)
	assert(not boundHandlers[name], `[Net] {name} já possui handler`)
	boundHandlers[name] = true

	local remote = remotes[name] :: RemoteEvent
	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		local ok, reason = validate(player, name, spec, select("#", ...), { ... })
		if not ok then
			reject(player, name, reason :: string)
			return
		end
		local success, err = xpcall(handler, debug.traceback, player, ...)
		if not success then
			log:Error("Erro no handler de %s:\n%s", name, tostring(err))
		end
	end)
end

-- Responde uma RemoteFunction. O cliente recebe (true, resultado) ou (false, motivo).
function NetServer.handle(name: string, handler: ServerHandler)
	local spec = getSpec(name)
	assert(spec.Kind == "Function", `[Net] {name} não é uma RemoteFunction`)
	assert(not boundHandlers[name], `[Net] {name} já possui handler`)
	boundHandlers[name] = true

	local remote = remotes[name] :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, ...: any)
		local ok, reason = validate(player, name, spec, select("#", ...), { ... })
		if not ok then
			reject(player, name, reason :: string)
			return false, reason
		end
		local success, result = xpcall(handler, debug.traceback, player, ...)
		if not success then
			log:Error("Erro no handler de %s:\n%s", name, tostring(result))
			return false, "ServerError"
		end
		return true, result
	end
end

local function getServerToClientEvent(name: string): RemoteEvent
	local spec = getSpec(name)
	assert(
		spec.Kind == "Event" and spec.Direction == "ServerToClient",
		`[Net] {name} não é um evento servidor → cliente`
	)
	return remotes[name] :: RemoteEvent
end

function NetServer.fire(name: string, player: Player, ...: any)
	getServerToClientEvent(name):FireClient(player, ...)
end

function NetServer.fireAll(name: string, ...: any)
	getServerToClientEvent(name):FireAllClients(...)
end

function NetServer.fireList(name: string, players: { Player }, ...: any)
	local remote = getServerToClientEvent(name)
	for _, player in players do
		remote:FireClient(player, ...)
	end
end

return NetServer
