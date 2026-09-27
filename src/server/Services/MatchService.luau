--!strict
-- Conduz a partida: Idle → Loading → Briefing → Shift → Results → Cleanup → Idle.
-- Modo "Local" (MVP): uma partida por servidor; lobby e mapa no mesmo place.
--
-- O estado público da partida fica em ReplicatedStorage > MatchState (atributos):
--   Phase, MatchId, MapId, GameMinute, ShiftGameMinutes, Completed

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local MatchConfig = require(Shared.Config.MatchConfig)
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)
local StateMachine = require(Shared.Modules.StateMachine)

local ClockService = require(script.Parent.ClockService)
local LobbyService = require(script.Parent.LobbyService)
local MapService = require(script.Parent.MapService)
local PlayerService = require(script.Parent.PlayerService)

export type Match = {
	Id: string,
	MapId: string,
	Players: { Player },
	StartedAt: number,
	Aborted: boolean,
	Ended: boolean,
}

export type MatchResult = {
	MatchId: string,
	MapId: string,
	Completed: boolean,
	DurationSeconds: number,
	Players: { Player },
}

local PHASE_TRANSITIONS = {
	Idle = { "Loading" },
	Loading = { "Briefing", "Cleanup" },
	Briefing = { "Shift", "Cleanup" },
	Shift = { "Results", "Cleanup" },
	Results = { "Cleanup" },
	Cleanup = { "Idle" },
}

local STATE_FOLDER_NAME = "MatchState"

local log = Log.new("MatchService")

local MatchService = {}

-- (match) jogadores já estão no mapa.
MatchService.MatchStarted = Signal.new()
-- (match, result) o turno terminou (completo ou abortado). Recompensas usarão isto (Fase 12).
MatchService.MatchEnded = Signal.new()
-- (newPhase, oldPhase)
MatchService.PhaseChanged = Signal.new()

local phase = StateMachine.new("Idle", PHASE_TRANSITIONS)
local stateFolder: Folder
local activeMatch: Match? = nil
local matchCounter = 0

local function setPhase(newPhase: string)
	local oldPhase = phase.Current
	phase:Transition(newPhase)
	stateFolder:SetAttribute("Phase", newPhase)
	log:Debug("Fase da partida: %s → %s", oldPhase, newPhase)
	MatchService.PhaseChanged:Fire(newPhase, oldPhase)
end

local function waitUnlessAborted(match: Match, seconds: number)
	local deadline = os.clock() + seconds
	while not match.Aborted do
		local remaining = deadline - os.clock()
		if remaining <= 0 then
			return
		end
		task.wait(math.min(remaining, 0.25))
	end
end

local function buildResult(match: Match, completed: boolean): MatchResult
	return {
		MatchId = match.Id,
		MapId = match.MapId,
		Completed = completed,
		DurationSeconds = os.clock() - match.StartedAt,
		Players = table.clone(match.Players),
	}
end

local function cleanup(match: Match)
	match.Ended = true
	if phase.Current ~= "Cleanup" and phase:CanTransition("Cleanup") then
		setPhase("Cleanup")
	end
	for _, player in match.Players do
		if player.Parent then
			PlayerService:SetState(player, "Lobby")
			-- Renasce no SpawnLocation do lobby.
			task.spawn(function()
				local ok, err = pcall(function()
					player:LoadCharacter()
				end)
				if not ok then
					log:Warn("Falha ao recarregar personagem de %s: %s", player.Name, tostring(err))
				end
			end)
		end
	end
	MapService:Unload()
	activeMatch = nil
	stateFolder:SetAttribute("MatchId", "")
	stateFolder:SetAttribute("MapId", "")
	stateFolder:SetAttribute("GameMinute", 0)
	if phase.Current == "Cleanup" then
		setPhase("Idle")
	end
	log:Info("Partida %s encerrada", match.Id)
end

local function runMatch(match: Match)
	local ok, err = xpcall(function()
		setPhase("Loading")
		MapService:Load(match.MapId)
		for index, player in match.Players do
			MapService:PlaceCharacter(player, index)
		end
		MatchService.MatchStarted:Fire(match)

		if not match.Aborted then
			setPhase("Briefing")
			waitUnlessAborted(match, MatchConfig.BRIEFING_SECONDS)
		end

		local completed = false
		if not match.Aborted then
			setPhase("Shift")
			completed = ClockService:Run(stateFolder, function()
				return match.Aborted
			end)
		end

		stateFolder:SetAttribute("Completed", completed)
		MatchService.MatchEnded:Fire(match, buildResult(match, completed))

		if completed then
			setPhase("Results")
			waitUnlessAborted(match, MatchConfig.RESULTS_SECONDS)
		end
	end, debug.traceback)

	if not ok then
		log:Error("Erro na partida %s:\n%s", match.Id, tostring(err))
	end
	cleanup(match)
end

-- Chamado pelo LobbyService quando o líder aperta INICIAR TURNO.
local function launch(request): (boolean, string?)
	if GameConfig.LAUNCH_MODE ~= "Local" then
		return false, "MatchUnavailable" -- modo Teleport chega na Fase 21
	end
	if activeMatch then
		return false, "ServerBusy"
	end

	local players = {}
	for _, player in request.Players do
		if player.Parent and PlayerService:GetState(player) == "Lobby" then
			table.insert(players, player)
		end
	end
	if #players == 0 then
		return false, "Unknown"
	end

	matchCounter += 1
	local match: Match = {
		Id = `M{matchCounter}`,
		MapId = request.MapId,
		Players = players,
		StartedAt = os.clock(),
		Aborted = false,
		Ended = false,
	}
	activeMatch = match
	stateFolder:SetAttribute("MatchId", match.Id)
	stateFolder:SetAttribute("MapId", match.MapId)
	stateFolder:SetAttribute("Completed", false)

	-- Marca como "em turno" imediatamente para ninguém criar/entrar em outro grupo no meio do caminho.
	for _, player in players do
		PlayerService:SetState(player, "InShift")
	end
	LobbyService:DisbandParty(request.PartyId)

	task.spawn(runMatch, match)
	return true
end

-- API para outros serviços ---------------------------------------------------------------

function MatchService:GetActiveMatch(): Match?
	return activeMatch
end

function MatchService:GetPhase(): string
	return phase.Current
end

function MatchService:IsPlayerInMatch(player: Player): boolean
	local match = activeMatch
	return match ~= nil and not match.Ended and table.find(match.Players, player) ~= nil
end

-- Encerra a partida atual antes do fim (ex.: comando de admin no futuro).
function MatchService:AbortMatch()
	local match = activeMatch
	if match then
		match.Aborted = true
	end
end

local function onPlayerLeaving(player: Player)
	local match = activeMatch
	if not match then
		return
	end
	local index = table.find(match.Players, player)
	if not index then
		return
	end
	table.remove(match.Players, index)
	log:Debug("%s saiu da partida %s (%d restantes)", player.Name, match.Id, #match.Players)
	if #match.Players == 0 then
		log:Info("Todos saíram da partida %s. Encerrando.", match.Id)
		match.Aborted = true
	end
end

-- Se o personagem renascer durante a partida, volta para o mapa (morte/espectador chegam na Fase 11).
local function watchCharacter(player: Player)
	player.CharacterAdded:Connect(function()
		local match = activeMatch
		if not match or match.Ended or not MatchService:IsPlayerInMatch(player) then
			return
		end
		task.defer(function()
			if MatchService:IsPlayerInMatch(player) then
				MapService:PlaceCharacter(player, table.find(match.Players, player) or 1)
			end
		end)
	end)
end

function MatchService:Init()
	local folder = Instance.new("Folder")
	folder.Name = STATE_FOLDER_NAME
	folder:SetAttribute("Phase", "Idle")
	folder:SetAttribute("MatchId", "")
	folder:SetAttribute("MapId", "")
	folder:SetAttribute("GameMinute", 0)
	folder:SetAttribute("ShiftGameMinutes", MatchConfig.SHIFT_GAME_MINUTES)
	folder:SetAttribute("Completed", false)
	folder.Parent = ReplicatedStorage
	stateFolder = folder
end

function MatchService:Start()
	LobbyService:SetLaunchHandler(launch)
	PlayerService.PlayerLeaving:Connect(onPlayerLeaving)
	PlayerService.PlayerReady:Connect(watchCharacter)
	for _, player in PlayerService:GetReadyPlayers() do
		watchCharacter(player)
	end
end

return MatchService
