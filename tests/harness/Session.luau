--!nocheck
-- Uma "partida simulada": 1 servidor + N clientes conectados por Remotes simulados.

local task = require("@lune/task")

local Mock = require("./Mock")
local World = require("./World")

local SRC = "src"

local Session = {}
Session.__index = Session

-- Simula a serialização da rede: tabelas são copiadas, funções viram nil.
local function copyAcrossNetwork(value, seen)
	if type(value) == "function" then
		return nil
	end
	if type(value) ~= "table" or Mock.isInstance(value) or rawget(value, "__mockType") then
		return value
	end
	seen = seen or {}
	if seen[value] then
		error("Tabelas com referência cíclica não podem ser enviadas pela rede")
	end
	seen[value] = true
	local copy = {}
	for key, item in value do
		copy[copyAcrossNetwork(key, seen)] = copyAcrossNetwork(item, seen)
	end
	seen[value] = nil
	return copy
end

local function copyArgs(...)
	local args = table.pack(...)
	for index = 1, args.n do
		args[index] = copyAcrossNetwork(args[index])
	end
	return table.unpack(args, 1, args.n)
end

function Session.new(options)
	options = options or {}
	local self = setmetatable({}, Session)
	self.Options = options
	self.Clients = {}

	self.Server = World.new("Server", "Server", {
		verbose = options.verbose,
		studio = options.studio,
		onCreate = function(_, instance)
			self:_setupServerRemote(instance)
		end,
	})

	local server = self.Server
	local shared = server:build(SRC .. "/shared", "Shared", options.patches)
	shared.Parent = server.game.ReplicatedStorage
	server:build(SRC .. "/server", "Server", options.patches).Parent = server.game.ServerScriptService
	server:build(SRC .. "/client", "Client", options.patches).Parent =
		server.game.StarterPlayer.StarterPlayerScripts

	shared.ChildAdded:Connect(function(child)
		if child.Name == "Remotes" then
			for _, client in self.Clients do
				self:_replicateRemotes(client)
			end
		end
	end)

	for _, descendant in server.game.ServerScriptService:GetDescendants() do
		if descendant.ClassName == "Script" then
			server:runScript(descendant)
		end
	end
	server:startFrames()
	return self
end

function Session:_clientFor(serverPlayer)
	for _, client in self.Clients do
		if client.ServerPlayer == serverPlayer then
			return client
		end
	end
	return nil
end

function Session:_setupServerRemote(instance)
	if instance.ClassName == "RemoteEvent" then
		instance.OnServerEvent = Mock.newSignal()
		instance.FireClient = function(_, player, ...)
			if not Mock.isInstance(player) or player.ClassName ~= "Player" then
				error("FireClient: argument 1 must be a Player")
			end
			local client = self:_clientFor(player)
			local proxy = client and client.Proxies[instance]
			if proxy then
				proxy.OnClientEvent:Fire(copyArgs(...))
			end
		end
		instance.FireAllClients = function(_, ...)
			for _, client in self.Clients do
				local proxy = client.Proxies[instance]
				if proxy then
					proxy.OnClientEvent:Fire(copyArgs(...))
				end
			end
		end
	end
end

function Session:_replicateRemotes(client)
	local serverFolder = self.Server.game.ReplicatedStorage.Shared:FindFirstChild("Remotes")
	if not serverFolder or client.RemotesReplicated then
		return
	end
	client.RemotesReplicated = true

	local folder = Mock.newInstance("Folder", "Remotes")
	for _, remote in serverFolder:GetChildren() do
		local proxy = Mock.newInstance(remote.ClassName, remote.Name)
		if remote.ClassName == "RemoteEvent" then
			proxy.OnClientEvent = Mock.newSignal()
			proxy.FireServer = function(_, ...)
				remote.OnServerEvent:Fire(client.ServerPlayer, copyArgs(...))
			end
		else
			proxy.InvokeServer = function(_, ...)
				local startedAt = os.clock()
				while remote.OnServerInvoke == nil do
					if os.clock() - startedAt > 5 then
						error("InvokeServer: servidor não definiu OnServerInvoke (simulado)")
					end
					task.wait(0.02)
				end
				return copyArgs(remote.OnServerInvoke(client.ServerPlayer, copyArgs(...)))
			end
		end
		client.Proxies[remote] = proxy
		proxy.Parent = folder
	end
	folder.Parent = client.game.ReplicatedStorage.Shared
end

-- Conecta um novo jogador. Retorna o mundo do cliente.
function Session:addClient(name, userId, clientOptions)
	clientOptions = clientOptions or {}
	local serverPlayer = Mock.newInstance("Player", name)
	serverPlayer.UserId = userId
	serverPlayer.DisplayName = name
	serverPlayer.Kick = function(_, message)
		self.Server:log("kick", name, message)
	end
	serverPlayer.Parent = self.Server.Players
	self.Server.Players.PlayerAdded:Fire(serverPlayer)

	local client = World.new("Client", name, {
		verbose = self.Options.verbose,
		studio = self.Options.studio,
		locale = clientOptions.locale,
	})
	client.ServerPlayer = serverPlayer
	client.Proxies = {}
	table.insert(self.Clients, client)

	local localPlayer = Mock.newInstance("Player", name)
	localPlayer.UserId = userId
	localPlayer.DisplayName = name
	Mock.newInstance("PlayerGui", "PlayerGui").Parent = localPlayer
	local playerScripts = Mock.newInstance("PlayerScripts", "PlayerScripts")
	playerScripts.Parent = localPlayer
	localPlayer.Parent = client.Players
	client.Players.LocalPlayer = localPlayer
	client.LocalPlayer = localPlayer

	client:build(SRC .. "/shared", "Shared", self.Options.patches).Parent = client.game.ReplicatedStorage
	client:build(SRC .. "/client", "Client", self.Options.patches).Parent = playerScripts

	self:_replicateRemotes(client)

	for _, descendant in playerScripts:GetDescendants() do
		if descendant.ClassName == "LocalScript" then
			client:runScript(descendant)
		end
	end
	client:startFrames()
	return client
end

function Session:removeClient(client)
	local index = table.find(self.Clients, client)
	if index then
		table.remove(self.Clients, index)
	end
	client.Running = false
	self.Server.Players.PlayerRemoving:Fire(client.ServerPlayer)
	task.wait()
	client.ServerPlayer.Parent = nil
end

-- Remote do lado do cliente (como se fosse usado pela Command Bar do Studio).
function Session:clientRemote(client, remoteName)
	return client.game.ReplicatedStorage.Shared.Remotes:FindFirstChild(remoteName)
end

function Session:stop()
	self.Server.Running = false
	for _, client in self.Clients do
		client.Running = false
	end
end

return Session
