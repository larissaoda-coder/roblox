--!strict
-- O servidor decide QUAIS sons tocam e PARA QUEM. O cliente (AudioController) toca e mostra legendas.
-- Sons "perceptivos" vão só para um jogador: outro jogador ao lado não ouve.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SoundDefinitions = require(Shared.Definitions.SoundDefinitions)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local MatchService = require(script.Parent.MatchService)

export type PlayOptions = {
	Volume: number?, -- multiplicador
	PlaybackSpeed: number?,
	Tag: string?, -- identificador para parar um loop depois
}

local log = Log.new("AudioService")

local AudioService = {}

local function check(soundName: string): boolean
	if not SoundDefinitions.get(soundName) then
		log:Warn("Som desconhecido: %s", soundName)
		return false
	end
	return true
end

local function matchPlayers(): { Player }
	local match = MatchService:GetActiveMatch()
	return if match then match.Players else {}
end

-- Som no mundo para todos os jogadores da partida (a distância é tratada no cliente).
function AudioService:PlayAt(soundName: string, position: Vector3?, options: PlayOptions?)
	if check(soundName) then
		Net.Server.fireList("PlaySound", matchPlayers(), soundName, position, options or {})
	end
end

-- Som só para um jogador (percepção individual).
function AudioService:PlayFor(player: Player, soundName: string, position: Vector3?, options: PlayOptions?)
	if check(soundName) then
		Net.Server.fire("PlaySound", player, soundName, position, options or {})
	end
end

function AudioService:PlayForList(
	players: { Player },
	soundName: string,
	position: Vector3?,
	options: PlayOptions?
)
	if check(soundName) then
		Net.Server.fireList("PlaySound", players, soundName, position, options or {})
	end
end

-- Para um som em loop (por Tag, ou pelo nome se não houver Tag).
function AudioService:Stop(tag: string, players: { Player }?)
	Net.Server.fireList("StopSound", players or matchPlayers(), tag)
end

-- Sons ambientes em loop presos a objetos do mapa (gerador, geladeira).
local AMBIENT_OBJECTS = { Generator = "GeneratorHum", Fridge = "FridgeHum" }

local function startAmbience(match)
	local runtime = workspace:FindFirstChild("Runtime")
	local map = runtime and runtime:FindFirstChild("ActiveMap")
	if not map then
		return
	end
	for objectName, soundName in AMBIENT_OBJECTS do
		local object = map:FindFirstChild(objectName, true)
		if object and object:IsA("BasePart") then
			Net.Server.fireList(
				"PlaySound",
				match.Players,
				soundName,
				object.Position,
				{ Tag = `Ambient_{objectName}` }
			)
		end
	end
end

function AudioService:Init() end

function AudioService:Start()
	MatchService.MatchStarted:Connect(startAmbience)
end

return AudioService
