--!nocheck
-- FASE 4: partida (MatchService, MapService, ClockService, HUD).

local task = require("@lune/task")

local Mock = require("../harness/Mock")
local Session = require("../harness/Session")
local Test = require("../harness/Test")

local test, expect, expectEqual = Test.test, Test.expect, Test.expectEqual

local MATCH_CONFIG = "src/shared/Config/MatchConfig.luau"

-- Partida acelerada: 5 minutos de jogo, 0.1 s por minuto, briefing/resultado curtos.
local function fastMatch(minutes, secondsPerMinute)
	return function(source)
		source = string.gsub(source, "SHIFT_GAME_MINUTES = 60", `SHIFT_GAME_MINUTES = {minutes or 5}`)
		source = string.gsub(
			source,
			"REAL_SECONDS_PER_GAME_MINUTE = 15",
			`REAL_SECONDS_PER_GAME_MINUTE = {secondsPerMinute or 0.1}`
		)
		source = string.gsub(source, "BRIEFING_SECONDS = 10", "BRIEFING_SECONDS = 0.2")
		source = string.gsub(source, "RESULTS_SECONDS = 10", "RESULTS_SECONDS = 0.3")
		return source
	end
end

local function newSession(context, minutes, secondsPerMinute)
	local session = Session.new({ patches = { [MATCH_CONFIG] = fastMatch(minutes, secondsPerMinute) } })
	table.insert(context.sessions, session)
	Test.expectLog(session.Server, "servidor pronto")
	return session
end

local function service(session, name)
	return session.Server:require(session.Server.game.ServerScriptService.Server.Services[name])
end

local function ready(client)
	Test.waitFor(function()
		return client.LocalPlayer:GetAttribute("Ready") == true
			and client.LocalPlayer.PlayerGui:FindFirstChild("HUD") ~= nil
	end, 3, `{client.Name} pronto`)
end

local function invoke(session, client, remoteName, ...)
	return session:clientRemote(client, remoteName):InvokeServer(...)
end

-- Cria um grupo com todos os clientes e inicia.
local function startShift(session, clients)
	for _, client in clients do
		ready(client)
	end
	local _, created = invoke(session, clients[1], "CreateParty", "GasStation")
	for index = 2, #clients do
		invoke(session, clients[index], "JoinParty", created.PartyId)
	end
	for _, client in clients do
		invoke(session, client, "SetReady", true)
	end
	local _, result = invoke(session, clients[1], "StartParty")
	expect(result.Success, `início do turno: {tostring(result.Error)}`)
end

local function matchState(world)
	return world.game.ReplicatedStorage.MatchState
end

local function waitPhase(session, phase, timeout)
	Test.waitFor(function()
		return matchState(session.Server):GetAttribute("Phase") == phase
	end, timeout or 3, `fase {phase}`)
end

local function hud(client)
	return client.LocalPlayer.PlayerGui.HUD
end

local function distance(a, b)
	return (a - b).Magnitude
end

-- TESTE 1 ----------------------------------------------------------------------------

test("Fase4/Unit: relógio formata horários", function()
	local session = Session.new({})
	local GameClock = session.Server:require(session.Server.game.ReplicatedStorage.Shared.Modules.GameClock)
	session:stop()
	expectEqual(GameClock.format(0), "04:00 AM", "início")
	expectEqual(GameClock.format(17), "04:17 AM", "04:17")
	expectEqual(GameClock.format(60), "05:00 AM", "fim")
	expectEqual(GameClock.format(-3), "04:00 AM", "negativo")
end)

test("Fase4/Unit: StateMachine recusa transições inválidas", function()
	local session = Session.new({})
	local StateMachine =
		session.Server:require(session.Server.game.ReplicatedStorage.Shared.Modules.StateMachine)
	session:stop()
	local machine = StateMachine.new("A", { A = { "B" }, B = { "A" } })
	machine:Transition("B")
	expectEqual(machine.Current, "B", "estado")
	local ok = pcall(machine.Transition, machine, "C")
	expect(not ok, "C não é permitido")
end)

test("Fase4/TESTE 1: turno completo, do lobby ao lobby", function(context)
	local session = newSession(context)
	local client = session:addClient("Player1", 1001)
	startShift(session, { client })

	-- Loading/Briefing: jogador no mapa, HUD visível, lobby escondido.
	waitPhase(session, "Briefing")
	local runtime = session.Server.workspace.Runtime
	local map = runtime:FindFirstChild("ActiveMap")
	expect(map and map:GetAttribute("MapId") == "GasStation", "mapa carregado em Workspace.Runtime.ActiveMap")
	Test.expectLog(session.Server, "Usando área de teste temporária")
	local spawnPoint = map.Spawns.Spawn1
	local root = client.ServerPlayer.Character.HumanoidRootPart
	expect(distance(root.Position, spawnPoint.Position) < 5, "personagem levado ao spawn do mapa")
	expect(hud(client).Enabled, "HUD visível")
	expect(not client.LocalPlayer.PlayerGui.LobbyUI.Enabled, "lobby escondido")
	expectEqual(hud(client).Banner.Text, "SEU TURNO COMEÇOU", "aviso de início")
	expectEqual(hud(client).Top.Clock.Text, "04:00 AM", "relógio no início")

	-- Turno: relógio anda.
	waitPhase(session, "Shift")
	Test.waitFor(function()
		return hud(client).Top.Clock.Text == "04:02 AM"
	end, 2, "relógio em 04:02")
	expect(not hud(client).Banner.Visible, "aviso some durante o turno")
	expectEqual(hud(client).Top.Objective.Text, "OBJETIVO: MANTENHA O POSTO FUNCIONANDO", "objetivo")

	-- Fim: resultado e volta ao lobby.
	waitPhase(session, "Results")
	expectEqual(hud(client).Banner.Text, "TURNO CONCLUÍDO", "turno concluído")
	expectEqual(hud(client).Top.Clock.Text, "04:05 AM", "relógio no fim")
	waitPhase(session, "Idle")
	Test.waitFor(function()
		return client.LocalPlayer:GetAttribute("State") == "Lobby"
	end, 2, "de volta ao lobby")
	expect(runtime:FindFirstChild("ActiveMap") == nil, "mapa descarregado")
	expect(not hud(client).Enabled, "HUD escondido")
	expect(client.LocalPlayer.PlayerGui.LobbyUI.Enabled, "lobby visível")
	expectEqual(client.ServerPlayer.LoadCount, 2, "personagem renasceu no lobby")
	Test.expectLog(session.Server, "Partida M1 encerrada")
	Test.expectNoErrors(session.Server)
	Test.expectNoErrors(client)
end)

test("Fase4/TESTE 1: MatchEnded informa turno completo", function(context)
	local session = newSession(context, 3)
	local MatchService = service(session, "MatchService")
	local ended
	MatchService.MatchEnded:Connect(function(match, result)
		ended = result
	end)
	local client = session:addClient("Player1", 1001)
	startShift(session, { client })
	Test.waitFor(function()
		return ended
	end, 4, "MatchEnded")
	expect(ended.Completed, "completo")
	expectEqual(ended.MapId, "GasStation", "mapa")
	expectEqual(ended.Players[1], client.ServerPlayer, "jogador")
end)

test("Fase4/TESTE 1: horários especiais 04:17, 04:33 e 04:44 são avisados", function(context)
	local session = newSession(context, 60, 0.01)
	local ClockService = service(session, "ClockService")
	local special = {}
	ClockService.SpecialTime:Connect(function(minute)
		table.insert(special, minute)
	end)
	local client = session:addClient("Player1", 1001)
	startShift(session, { client })
	waitPhase(session, "Results", 5)
	expectEqual(table.concat(special, ","), "17,33,44", "horários especiais")
end)

test(
	"Fase4/TESTE 1: mapa feito no Studio (ServerStorage > Maps) é usado no lugar da área de teste",
	function(context)
		local session = newSession(context)
		local server = session.Server
		local maps = Mock.newInstance("Folder", "Maps")
		maps.Parent = server.game.ServerStorage
		local custom = Mock.newInstance("Model", "GasStation")
		local spawns = Mock.newInstance("Folder", "Spawns")
		spawns.Parent = custom
		local point = Mock.newInstance("Part", "A")
		point.Position = Mock.Vector3.new(500, 10, 500)
		point.Parent = spawns
		custom.Parent = maps

		local client = session:addClient("Player1", 1001)
		startShift(session, { client })
		waitPhase(session, "Briefing")
		local map = server.workspace.Runtime.ActiveMap
		expect(map:GetAttribute("Placeholder") == nil, "não usou a área de teste")
		expect(
			distance(client.ServerPlayer.Character.HumanoidRootPart.Position, point.Position) < 5,
			"spawn do mapa do usuário"
		)
		expect(maps:FindFirstChild("GasStation"), "original continua no ServerStorage (foi clonado)")
	end
)

-- TESTE 2 ----------------------------------------------------------------------------

test("Fase4/TESTE 2: dois jogadores vão juntos, em pontos diferentes", function(context)
	local session = newSession(context)
	local first = session:addClient("Player1", -1)
	local second = session:addClient("Player2", -2)
	startShift(session, { first, second })
	waitPhase(session, "Briefing")
	local a = first.ServerPlayer.Character.HumanoidRootPart.Position
	local b = second.ServerPlayer.Character.HumanoidRootPart.Position
	expect(distance(a, b) > 1, "spawns diferentes")
	for _, client in { first, second } do
		expectEqual(client.LocalPlayer:GetAttribute("State"), "InShift", `{client.Name} em turno`)
		expect(hud(client).Enabled, `HUD de {client.Name}`)
	end
end)

test("Fase4/TESTE 2: jogador que fica no lobby não entra na partida dos outros", function(context)
	local session = newSession(context)
	local playing = session:addClient("Player1", -1)
	local waiting = session:addClient("Player2", -2)
	startShift(session, { playing })
	ready(waiting)
	waitPhase(session, "Briefing")
	expectEqual(waiting.LocalPlayer:GetAttribute("State"), "Lobby", "continua no lobby")
	expect(not hud(waiting).Enabled, "sem HUD")
	expect(waiting.LocalPlayer.PlayerGui.LobbyUI.Enabled, "lobby visível")
end)

-- TESTE 3 ----------------------------------------------------------------------------

test(
	"Fase4/TESTE 3: segundo grupo não inicia enquanto há partida (um turno por servidor)",
	function(context)
		local session = newSession(context, 30)
		local first = session:addClient("Player1", -1)
		local second = session:addClient("Player2", -2)
		startShift(session, { first })
		ready(second)
		local _, created = invoke(session, second, "CreateParty", "GasStation")
		expect(created.Success, "pode criar o grupo e esperar")
		invoke(session, second, "SetReady", true)
		local _, result = invoke(session, second, "StartParty")
		expectEqual(result.Error, "ServerBusy", "servidor ocupado")
		expect(service(session, "LobbyService"):GetParty(created.PartyId), "grupo continua esperando")
	end
)

test("Fase4/TESTE 3: se todos saem, a partida termina e o mapa é removido", function(context)
	local session = newSession(context, 30)
	local client = session:addClient("Player1", 1001)
	startShift(session, { client })
	waitPhase(session, "Shift")
	session:removeClient(client)
	waitPhase(session, "Idle", 3)
	expect(session.Server.workspace.Runtime:FindFirstChild("ActiveMap") == nil, "mapa removido")
	Test.expectLog(session.Server, "Todos saíram da partida")
	Test.expectNoErrors(session.Server)
end)

test("Fase4/TESTE 3: um jogador sai e o outro continua", function(context)
	local session = newSession(context, 4)
	local first = session:addClient("Player1", -1)
	local second = session:addClient("Player2", -2)
	startShift(session, { first, second })
	waitPhase(session, "Shift")
	session:removeClient(first)
	task.wait(0.2)
	expectEqual(matchState(session.Server):GetAttribute("Phase"), "Shift", "partida continua")
	waitPhase(session, "Results", 3)
	waitPhase(session, "Idle", 3)
	expectEqual(second.LocalPlayer:GetAttribute("State"), "Lobby", "quem ficou volta ao lobby")
end)

test("Fase4/TESTE 3: personagem que renasce durante o turno volta para o mapa", function(context)
	local session = newSession(context, 30)
	local client = session:addClient("Player1", 1001)
	startShift(session, { client })
	waitPhase(session, "Shift")
	client.ServerPlayer.LoadCharacter() -- simula morte + renascimento no lobby
	local map = session.Server.workspace.Runtime.ActiveMap
	Test.waitFor(function()
		local root = client.ServerPlayer.Character.HumanoidRootPart
		return distance(root.Position, map.Spawns.Spawn1.Position) < 5
	end, 2, "de volta ao mapa")
end)

test("Fase4/TESTE 3: erro ao carregar o mapa devolve todos ao lobby", function(context)
	local session = newSession(context)
	local maps = Mock.newInstance("Folder", "Maps")
	maps.Parent = session.Server.game.ServerStorage
	local broken = Mock.newInstance("Model", "GasStation") -- sem pasta Spawns
	broken.Parent = maps
	local client = session:addClient("Player1", 1001)
	startShift(session, { client })
	Test.expectLog(session.Server, 'precisa de uma pasta "Spawns"')
	waitPhase(session, "Idle", 3)
	Test.waitFor(function()
		return client.LocalPlayer:GetAttribute("State") == "Lobby"
	end, 2, "de volta ao lobby")
end)
