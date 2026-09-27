--!strict
-- Lobby: grupos de jogadores ("turnos" na interface) que se formam antes da partida.
-- Fluxo: CreateParty → JoinParty → SetReady → StartParty → (MatchService, Fase 4).
--
-- O LobbyService NÃO inicia partidas sozinho: quem inicia é o handler registrado com
-- LobbyService:SetLaunchHandler (o MatchService fará isso na Fase 4).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local MapDefinitions = require(Shared.Definitions.MapDefinitions)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local LobbyBuilder = require(script.Parent.Parent.World.LobbyBuilder)

export type Party = {
	Id: string,
	MapId: string,
	Host: Player,
	Members: { Player },
	Ready: { [Player]: boolean },
	MaxPlayers: number,
	Launching: boolean,
	CreatedAt: number,
}

export type LaunchRequest = {
	PartyId: string,
	MapId: string,
	Players: { Player },
}

-- Retorna (true) se a partida começou, ou (false, códigoDeErro).
export type LaunchHandler = (request: LaunchRequest) -> (boolean, string?)

type ActionResult = { Success: boolean, Error: string?, PartyId: string? }

local MAX_PARTIES = 8

local log = Log.new("LobbyService")

local LobbyService = {}

-- (party) sempre que um grupo é criado, alterado ou removido.
LobbyService.PartyChanged = Signal.new()

local parties: { [string]: Party } = {}
local partyOf: { [Player]: Party } = {}
local partyCount = 0
local nextPartyNumber = 0
local launchHandler: LaunchHandler? = nil
local broadcastQueued = false

local function fail(code: string): ActionResult
	return { Success = false, Error = code }
end

local SUCCESS: ActionResult = table.freeze({ Success = true })

local function serializeParty(party: Party)
	local members = {}
	for _, member in party.Members do
		table.insert(members, {
			UserId = member.UserId,
			Name = member.DisplayName,
			Ready = party.Ready[member] == true,
		})
	end
	return {
		Id = party.Id,
		MapId = party.MapId,
		HostUserId = party.Host.UserId,
		MaxPlayers = party.MaxPlayers,
		Launching = party.Launching,
		Members = members,
	}
end

function LobbyService:GetSnapshot()
	local list = {}
	for _, party in parties do
		table.insert(list, party)
	end
	table.sort(list, function(a, b)
		return a.CreatedAt < b.CreatedAt
	end)
	local serialized = {}
	for _, party in list do
		table.insert(serialized, serializeParty(party))
	end
	return { Parties = serialized }
end

-- Agrupa várias mudanças no mesmo frame em uma única mensagem para os clientes.
local function queueBroadcast(party: Party?)
	if party then
		LobbyService.PartyChanged:Fire(party)
	end
	if broadcastQueued then
		return
	end
	broadcastQueued = true
	task.defer(function()
		broadcastQueued = false
		Net.Server.fireAll("LobbyStateChanged", LobbyService:GetSnapshot())
	end)
end

local function removeParty(party: Party)
	if parties[party.Id] == nil then
		return
	end
	parties[party.Id] = nil
	partyCount -= 1
	for _, member in party.Members do
		partyOf[member] = nil
	end
	log:Debug("Turno %s removido", party.Id)
end

local function removeMember(party: Party, player: Player)
	local index = table.find(party.Members, player)
	if not index then
		return
	end
	table.remove(party.Members, index)
	party.Ready[player] = nil
	partyOf[player] = nil

	if #party.Members == 0 then
		removeParty(party)
	elseif party.Host == player then
		party.Host = party.Members[1]
		log:Debug("Novo líder do turno %s: %s", party.Id, party.Host.Name)
	end
	queueBroadcast(party)
end

local function checkCanAct(player: Player): string?
	if not PlayerService:IsReady(player) then
		return "NotReady"
	end
	if PlayerService:GetState(player) ~= "Lobby" then
		return "NotInLobby"
	end
	return nil
end

local function isMapUnlocked(player: Player, mapId: string): boolean
	local unlocked = DataService:Get(player, "UnlockedMaps")
	return type(unlocked) == "table" and unlocked[mapId] == true
end

local function createParty(player: Player, mapId: string): ActionResult
	local blocked = checkCanAct(player)
	if blocked then
		return fail(blocked)
	end
	if partyOf[player] then
		return fail("AlreadyInParty")
	end
	if partyCount >= MAX_PARTIES then
		return fail("TooManyParties")
	end
	local map = MapDefinitions.get(mapId)
	if not map then
		return fail("InvalidMap")
	end
	if not map.Available or not isMapUnlocked(player, mapId) then
		return fail("MapLocked")
	end

	nextPartyNumber += 1
	local party: Party = {
		Id = `P{nextPartyNumber}`,
		MapId = mapId,
		Host = player,
		Members = { player },
		Ready = {},
		MaxPlayers = math.min(map.MaxPlayers, GameConfig.MAX_PLAYERS_PER_SHIFT),
		Launching = false,
		CreatedAt = os.clock(),
	}
	parties[party.Id] = party
	partyCount += 1
	partyOf[player] = party
	log:Debug("%s criou o turno %s (%s)", player.Name, party.Id, mapId)
	queueBroadcast(party)
	return { Success = true, PartyId = party.Id }
end

local function joinParty(player: Player, partyId: string): ActionResult
	local blocked = checkCanAct(player)
	if blocked then
		return fail(blocked)
	end
	if partyOf[player] then
		return fail("AlreadyInParty")
	end
	local party = parties[partyId]
	if not party then
		return fail("PartyNotFound")
	end
	if party.Launching then
		return fail("PartyLaunching")
	end
	if #party.Members >= party.MaxPlayers then
		return fail("PartyFull")
	end
	if not isMapUnlocked(player, party.MapId) then
		return fail("MapLocked")
	end

	table.insert(party.Members, player)
	partyOf[player] = party
	log:Debug("%s entrou no turno %s", player.Name, party.Id)
	queueBroadcast(party)
	return { Success = true, PartyId = party.Id }
end

local function leaveParty(player: Player): ActionResult
	local party = partyOf[player]
	if not party then
		return fail("NotInParty")
	end
	if party.Launching then
		return fail("PartyLaunching")
	end
	removeMember(party, player)
	return SUCCESS
end

local function setReady(player: Player, ready: boolean): ActionResult
	local party = partyOf[player]
	if not party then
		return fail("NotInParty")
	end
	if party.Launching then
		return fail("PartyLaunching")
	end
	party.Ready[player] = ready
	queueBroadcast(party)
	return SUCCESS
end

local function startParty(player: Player): ActionResult
	local party = partyOf[player]
	if not party then
		return fail("NotInParty")
	end
	if party.Host ~= player then
		return fail("NotHost")
	end
	if party.Launching then
		return fail("PartyLaunching")
	end
	local map = MapDefinitions.get(party.MapId)
	if not map or #party.Members < map.MinPlayers then
		return fail("NotAllReady")
	end
	for _, member in party.Members do
		if not party.Ready[member] then
			return fail("NotAllReady")
		end
	end
	local handler = launchHandler
	if not handler then
		return fail("MatchUnavailable")
	end

	party.Launching = true
	queueBroadcast(party)

	local request: LaunchRequest =
		{ PartyId = party.Id, MapId = party.MapId, Players = table.clone(party.Members) }
	local ok, started, errorCode = pcall(handler, request)
	if not ok then
		log:Error("Erro ao iniciar o turno %s: %s", party.Id, tostring(started))
	end
	if not ok or not started then
		party.Launching = false
		queueBroadcast(party)
		return fail(if ok and errorCode then errorCode else "Unknown")
	end
	log:Info("Turno %s iniciado (%d jogadores, %s)", party.Id, #request.Players, party.MapId)
	return SUCCESS
end

-- API para outros serviços ---------------------------------------------------------------

function LobbyService:SetLaunchHandler(handler: LaunchHandler)
	launchHandler = handler
end

function LobbyService:GetParty(partyId: string): Party?
	return parties[partyId]
end

function LobbyService:GetPartyOf(player: Player): Party?
	return partyOf[player]
end

-- Remove o grupo (ex.: quando a partida começa e os jogadores vão para o mapa).
function LobbyService:DisbandParty(partyId: string)
	local party = parties[partyId]
	if party then
		removeParty(party)
		queueBroadcast(party)
	end
end

function LobbyService:Init()
	LobbyBuilder.ensure()

	Net.Server.handle("RequestLobbyState", function()
		return LobbyService:GetSnapshot()
	end)
	Net.Server.handle("CreateParty", createParty)
	Net.Server.handle("JoinParty", joinParty)
	Net.Server.handle("LeaveParty", leaveParty)
	Net.Server.handle("SetReady", setReady)
	Net.Server.handle("StartParty", startParty)
end

function LobbyService:Start()
	PlayerService.PlayerLeaving:Connect(function(player: Player)
		local party = partyOf[player]
		if party then
			removeMember(party, player)
		end
	end)
end

return LobbyService
