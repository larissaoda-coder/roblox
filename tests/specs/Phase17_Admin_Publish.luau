--!nocheck
-- FASES 17–21: admin/debug, modo Teleport (publicação) e fluxo completo.

local task = require("@lune/task")

local Session = require("../harness/Session")
local Test = require("../harness/Test")

local test, expect, expectEqual = Test.test, Test.expect, Test.expectEqual

local function service(session, name)
	return session.Server:require(session.Server.game.ServerScriptService.Server.Services[name])
end

local function invoke(session, client, remoteName, ...)
	return session:clientRemote(client, remoteName):InvokeServer(...)
end

local FAST = function(source)
	source = string.gsub(source, "BRIEFING_SECONDS = 10", "BRIEFING_SECONDS = 0.1")
	source = string.gsub(source, "RESULTS_SECONDS = 10", "RESULTS_SECONDS = 0.2")
	source = string.gsub(source, "SHIFT_GAME_MINUTES = 60", "SHIFT_GAME_MINUTES = 3")
	return (string.gsub(source, "REAL_SECONDS_PER_GAME_MINUTE = 15", "REAL_SECONDS_PER_GAME_MINUTE = 0.2"))
end

local TELEPORT = function(source)
	source = string.gsub(source, 'LAUNCH_MODE = "Local"', 'LAUNCH_MODE = "Teleport"')
	source = string.gsub(source, 'Lobby = "PLACE_ID_HERE"', "Lobby = 100")
	source = string.gsub(source, 'Shift = "PLACE_ID_HERE"', "Shift = 200")
	return (string.gsub(source, "TELEPORT_ARRIVAL_TIMEOUT = 25", "TELEPORT_ARRIVAL_TIMEOUT = 1"))
end

local function newSession(context, options)
	options = options or {}
	options.patches = options.patches or {}
	options.patches["src/shared/Config/MatchConfig.luau"] = FAST
	local session = Session.new(options)
	table.insert(context.sessions, session)
	Test.expectLog(session.Server, "servidor pronto")
	return session
end

local function join(session, name, userId, clientOptions)
	local client = session:addClient(name, userId, clientOptions)
	Test.waitFor(function()
		return client.LocalPlayer:GetAttribute("Ready") == true
	end, 5, "pronto")
	return client
end

test("Fase17/TESTE 1: comandos de admin funcionam para admin", function(context)
	local session = newSession(context)
	service(session, "DirectorService"):SetEnabled(false)
	local client = join(session, "Admin", 1)
	local _, cash = invoke(session, client, "AdminCommand", "GiveCash", 500)
	expect(cash.Success, "dar cash")
	expectEqual(client.LocalPlayer:GetAttribute("Cash"), 500, "saldo")
	invoke(session, client, "CreateParty", "GasStation")
	invoke(session, client, "SetReady", true)
	invoke(session, client, "StartParty")
	Test.waitFor(function()
		return service(session, "MatchService"):GetPhase() == "Shift"
	end, 3, "turno")
	local _, event = invoke(session, client, "AdminCommand", "TriggerEvent", "Blackout")
	expect(event.Success and service(session, "LightingService"):IsBlackout(), "evento pelo painel")
	local _, teleport = invoke(session, client, "AdminCommand", "Teleport", "Stockroom")
	expect(teleport.Success, "teleporte")
	local position = client.ServerPlayer.Character.HumanoidRootPart.Position
	expectEqual(service(session, "MapService"):GetZoneAt(position), "Stockroom", "no estoque")
	local _, info = invoke(session, client, "GetDebugInfo")
	expectEqual(info.Phase, "Shift", "debug mostra a fase")
end)

test(
	"Fase17/TESTE 3: jogador comum não consegue usar comandos nem ver debug (jogo publicado)",
	function(context)
		local session = newSession(context, { studio = false })
		local client = join(session, "Player", 42)
		local _, result = invoke(session, client, "AdminCommand", "GiveCash", 99999)
		expect(not result.Success, "recusado")
		expectEqual(client.LocalPlayer:GetAttribute("Cash"), 0, "nada ganho")
		local _, info = invoke(session, client, "GetDebugInfo")
		expect(info == nil, "sem debug")
		Test.expectLog(session.Server, "tentou usar comando de admin")
	end
)

test("Fase21/TESTE 1: modo Teleport — o lobby manda a equipe para um servidor reservado", function(context)
	local session = newSession(context, {
		placeId = 100,
		patches = { ["src/shared/Config/GameConfig.luau"] = TELEPORT },
	})
	Test.expectLog(session.Server, "Papel do servidor: Lobby")
	local first = join(session, "Player1", 1)
	local second = join(session, "Player2", 2)
	local _, created = invoke(session, first, "CreateParty", "GasStation")
	invoke(session, second, "JoinParty", created.PartyId)
	invoke(session, first, "SetReady", true)
	invoke(session, second, "SetReady", true)
	local _, started = invoke(session, first, "StartParty")
	expect(started.Success, "enviado")
	local teleport = session.Server.Teleports[1]
	expectEqual(teleport.PlaceId, 200, "place do turno")
	expectEqual(teleport.AccessCode, "ACCESS-200", "servidor reservado")
	expectEqual(#teleport.Players, 2, "equipe inteira")
	expectEqual(teleport.Data.MapId, "GasStation", "mapa nos dados")
	expectEqual(service(session, "MatchService"):GetPhase(), "Idle", "o lobby não roda a partida")
end)

test(
	"Fase21/TESTE 1: modo Teleport — servidor do turno começa sozinho e devolve ao lobby",
	function(context)
		local session = newSession(context, {
			placeId = 200,
			patches = { ["src/shared/Config/GameConfig.luau"] = TELEPORT },
		})
		Test.expectLog(session.Server, "Papel do servidor: Shift")
		local data = { PartyId = "P1", MapId = "GasStation", UserIds = { 1, 2 } }
		join(session, "Player1", 1, { teleportData = data })
		join(session, "Player2", 2, { teleportData = data })
		Test.waitFor(function()
			return service(session, "MatchService"):GetPhase() ~= "Idle"
		end, 3, "turno começou sozinho")
		Test.waitFor(function()
			for _, teleport in session.Server.Teleports do
				if teleport.PlaceId == 100 then
					return #teleport.Players == 2
				end
			end
			return false
		end, 6, "todos voltaram ao lobby")
	end
)

test("Fase21/TESTE 3: modo Teleport sem IDs configurados cai para o modo Local", function(context)
	local session = newSession(context, {
		patches = {
			["src/shared/Config/GameConfig.luau"] = function(source)
				return (string.gsub(source, 'LAUNCH_MODE = "Local"', 'LAUNCH_MODE = "Teleport"'))
			end,
		},
	})
	Test.expectLog(session.Server, "PLACE_IDS não foram configurados")
	Test.expectLog(session.Server, "Papel do servidor: Local")
end)
