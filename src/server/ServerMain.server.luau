--!strict
-- ÚNICO Script do servidor. Não coloque lógica de jogo aqui: ela pertence aos Services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Loader = require(Shared.Modules.Loader)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local log = Log.new("ServerMain")

-- Pasta onde tudo que é criado durante a partida fica (mapa ativo, NPCs, entidades).
InstanceUtil.getOrCreate(workspace, "Folder", "Runtime")

Net.Server.init()

local services = Loader.load(script.Parent.Services)
Loader.init(services)

Net.Server.publish()

local count = Loader.start(services)
log:Info(
	"%s v%s: servidor pronto (%d serviços, modo %s)",
	GameConfig.GAME_NAME,
	GameConfig.GAME_VERSION,
	count,
	GameConfig.LAUNCH_MODE
)
