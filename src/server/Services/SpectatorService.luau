--!strict
-- Morte e modo espectador. Quem morre no turno vira espectador: o corpo fica no lobby (fora do mapa)
-- e a câmera acompanha apenas colegas vivos (sem câmera livre, para não revelar segredos do mapa).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)
local PlayerService = require(script.Parent.PlayerService)

local log = Log.new("SpectatorService")

local SpectatorService = {}

-- (player, cause)
SpectatorService.PlayerDied = Signal.new()

local deadPlayers: { [Player]: string } = {}

local function broadcastTargets()
	local targets = {}
	for _, player in MatchService:GetAlivePlayers() do
		table.insert(targets, { UserId = player.UserId, Name = player.DisplayName })
	end
	local spectators = {}
	for player in deadPlayers do
		if player.Parent then
			table.insert(spectators, player)
		end
	end
	Net.Server.fireList("SpectateTargets", spectators, targets)
end

function SpectatorService:IsDead(player: Player): boolean
	return deadPlayers[player] ~= nil
end

function SpectatorService:GetDeathCause(player: Player): string?
	return deadPlayers[player]
end

-- Mata o jogador no turno (ex.: a entidade o alcançou). Seguro chamar duas vezes.
function SpectatorService:Kill(player: Player, cause: string)
	if deadPlayers[player] or not MatchService:IsPlayerInMatch(player) then
		return
	end
	deadPlayers[player] = cause
	MatchService:MarkDead(player)
	PlayerService:SetState(player, "Spectating")
	DataService:IncrementStat(player, "Deaths", 1)
	log:Info("%s morreu (%s)", player.Name, cause)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
	SpectatorService.PlayerDied:Fire(player, cause)
	broadcastTargets()
end

local function watchHumanoid(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		if MatchService:IsPlayerInMatch(player) and not deadPlayers[player] then
			SpectatorService:Kill(player, "Fall")
		end
	end)
end

function SpectatorService:Init() end

function SpectatorService:Start()
	MatchService.MatchStarted:Connect(function()
		table.clear(deadPlayers)
	end)
	MatchService.MatchEnded:Connect(function()
		table.clear(deadPlayers)
	end)
	-- Quando um colega sai ou morre, a lista de quem pode ser assistido muda.
	PlayerService.PlayerLeaving:Connect(function(player: Player)
		deadPlayers[player] = nil
		task.defer(broadcastTargets)
	end)
	PlayerService.PlayerReady:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			watchHumanoid(player, character)
		end)
		if player.Character then
			watchHumanoid(player, player.Character)
		end
	end)
end

return SpectatorService
