--!strict
-- Modo "Teleport" (produção): o lobby manda cada equipe para um SERVIDOR RESERVADO do place de turno,
-- e no fim o turno devolve todos ao lobby. Cada turno tem seu próprio servidor (luz e clima independentes).
-- Não funciona dentro do Studio (o Roblox não permite teleporte no Studio).

local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Modules.Log)

local log = Log.new("TeleportLauncher")

local TeleportLauncher = {}

export type Role = "Local" | "Lobby" | "Shift"

export type ShiftData = { PartyId: string, MapId: string, UserIds: { number } }

function TeleportLauncher.placeId(name: "Lobby" | "Shift"): number?
	return tonumber(GameConfig.PLACE_IDS[name])
end

-- Qual é o papel deste servidor.
function TeleportLauncher.getRole(): Role
	if GameConfig.LAUNCH_MODE ~= "Teleport" then
		return "Local"
	end
	local lobbyId = TeleportLauncher.placeId("Lobby")
	local shiftId = TeleportLauncher.placeId("Shift")
	if not lobbyId or not shiftId then
		log:Warn("LAUNCH_MODE = Teleport, mas PLACE_IDS não foram configurados. Usando modo Local.")
		return "Local"
	end
	return if game.PlaceId == shiftId then "Shift" else "Lobby"
end

-- Lobby → servidor reservado do turno. Retorna (true) ou (false, códigoDeErro).
function TeleportLauncher.sendParty(partyId: string, mapId: string, players: { Player }): (boolean, string?)
	local shiftId = TeleportLauncher.placeId("Shift") :: number
	local userIds = {}
	for _, player in players do
		table.insert(userIds, player.UserId)
	end
	local ok, err = pcall(function()
		local accessCode = TeleportService:ReserveServer(shiftId)
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = accessCode
		options:SetTeleportData({ PartyId = partyId, MapId = mapId, UserIds = userIds } :: ShiftData)
		TeleportService:TeleportAsync(shiftId, players, options)
	end)
	if not ok then
		log:Error("Falha ao teleportar o turno %s: %s", partyId, tostring(err))
		return false, "TeleportFailed"
	end
	log:Info("Turno %s enviado para um servidor reservado (%d jogadores)", partyId, #players)
	return true, nil
end

-- Dados do turno que vieram com o jogador (no servidor do turno).
function TeleportLauncher.readShiftData(player: Player): ShiftData?
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local data: any = ok and type(joinData) == "table" and (joinData :: any).TeleportData or nil
	if type(data) == "table" and type(data.MapId) == "string" and type(data.UserIds) == "table" then
		return data
	end
	return nil
end

-- Turno → lobby.
function TeleportLauncher.returnToLobby(players: { Player })
	local lobbyId = TeleportLauncher.placeId("Lobby")
	if not lobbyId or #players == 0 then
		return
	end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(lobbyId, players)
	end)
	if not ok then
		log:Error("Falha ao devolver jogadores ao lobby: %s", tostring(err))
	end
end

return TeleportLauncher
