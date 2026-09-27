--!strict
-- Ciclo de vida dos jogadores: entrar → carregar dados → pronto → sair (salvar).
-- Outros serviços devem usar PlayerService.PlayerReady em vez de Players.PlayerAdded,
-- porque só depois dele os dados do jogador estão disponíveis.
--
-- Atributos no Player (o cliente pode ler):
--   Ready = true quando os dados carregaram
--   State = "Loading" | "Lobby" | "InShift" | "Spectating"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Definitions.Strings)
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)

local DataService = require(script.Parent.DataService)

export type PlayerState = "Loading" | "Lobby" | "InShift" | "Spectating"

local VALID_STATES: { PlayerState } = { "Loading", "Lobby", "InShift", "Spectating" }

local log = Log.new("PlayerService")

local PlayerService = {}

-- (player) dados carregados, jogador pronto para jogar.
PlayerService.PlayerReady = Signal.new()
-- (player) jogador saindo. Disparado ANTES de salvar, para outros serviços registrarem o que precisarem.
PlayerService.PlayerLeaving = Signal.new()
-- (player, newState, oldState)
PlayerService.StateChanged = Signal.new()

local joinedAt: { [Player]: number } = {}
local handled: { [Player]: boolean } = {}

function PlayerService:IsReady(player: Player): boolean
	return player:GetAttribute("Ready") == true
end

function PlayerService:GetState(player: Player): PlayerState?
	return player:GetAttribute("State") :: PlayerState?
end

function PlayerService:SetState(player: Player, state: PlayerState)
	assert(table.find(VALID_STATES, state), `[PlayerService] estado inválido: {state}`)
	local oldState = self:GetState(player)
	if oldState == state then
		return
	end
	player:SetAttribute("State", state)
	log:Debug("%s: %s → %s", player.Name, tostring(oldState), state)
	PlayerService.StateChanged:Fire(player, state, oldState)
end

function PlayerService:GetReadyPlayers(): { Player }
	local ready = {}
	for _, player in Players:GetPlayers() do
		if self:IsReady(player) then
			table.insert(ready, player)
		end
	end
	return ready
end

local function onPlayerAdded(player: Player)
	if handled[player] then
		return
	end
	handled[player] = true
	joinedAt[player] = os.clock()
	PlayerService:SetState(player, "Loading")

	if not DataService:LoadProfile(player) then
		if player.Parent ~= nil then
			log:Error("Não foi possível carregar os dados de %s. Removendo do servidor.", player.Name)
			player:Kick(Strings.getForLocale(player.LocaleId, "KICK_DATA_LOAD_FAILED"))
		end
		return
	end

	PlayerService:SetState(player, "Lobby")
	player:SetAttribute("Ready", true)
	log:Info("%s está pronto", player.Name)
	PlayerService.PlayerReady:Fire(player)
end

local function onPlayerRemoving(player: Player)
	if not handled[player] then
		return
	end
	handled[player] = nil

	PlayerService.PlayerLeaving:Fire(player)

	local startedAt = joinedAt[player]
	joinedAt[player] = nil
	if startedAt and DataService:IsLoaded(player) then
		DataService:IncrementStat(player, "PlayTime", math.floor(os.clock() - startedAt))
	end
	DataService:ReleaseProfile(player)
end

function PlayerService:Init() end

function PlayerService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Jogadores que entraram antes deste serviço iniciar (comum no Studio).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerService
