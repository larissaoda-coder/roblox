--!strict
-- ÚNICO LocalScript do cliente. Não coloque lógica aqui: ela pertence aos Controllers.

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Loader = require(Shared.Modules.Loader)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Strings = require(Shared.Definitions.Strings)

local log = Log.new("ClientMain")

Strings.setLocale(LocalizationService.RobloxLocaleId)

Net.Client.init()

local controllers = Loader.load(script.Parent.Controllers)
Loader.init(controllers)
local count = Loader.start(controllers)

log:Info(
	"%s v%s: cliente pronto (%d controllers, idioma %s)",
	GameConfig.GAME_NAME,
	GameConfig.GAME_VERSION,
	count,
	Strings.getLanguage()
)
