--!nocheck
-- FASE 2: sistema de jogadores (PlayerService, DataService em memória, InputController).

local task = require("@lune/task")

local Mock = require("../harness/Mock")
local Session = require("../harness/Session")
local Test = require("../harness/Test")

local test, expect, expectEqual = Test.test, Test.expect, Test.expectEqual

local MEMORY_BACKEND = "src/server/Data/MemoryBackend.luau"

local function newSession(context, options)
	local session = Session.new(options)
	table.insert(context.sessions, session)
	Test.expectLog(session.Server, "servidor pronto")
	return session
end

local function serverModule(session, path)
	local target = session.Server.game.ServerScriptService.Server
	for _, part in string.split(path, "/") do
		target = target[part]
	end
	return session.Server:require(target)
end

local function clientModule(client, path)
	local target = client.LocalPlayer.PlayerScripts.Client
	for _, part in string.split(path, "/") do
		target = target[part]
	end
	return client:require(target)
end

local function waitReady(client)
	Test.waitFor(function()
		return client.LocalPlayer:GetAttribute("Ready") == true
	end, 3, `{client.Name} pronto`)
end

-- TESTE 1 ----------------------------------------------------------------------------

test("Fase2/TESTE 1: jogador novo recebe dados iniciais e fica pronto no Lobby", function(context)
	local session = newSession(context)
	local client = session:addClient("Player1", 1001)
	waitReady(client)
	local localPlayer = client.LocalPlayer
	expectEqual(localPlayer:GetAttribute("State"), "Lobby", "State")
	expectEqual(localPlayer:GetAttribute("Level"), 1, "Level")
	expectEqual(localPlayer:GetAttribute("Cash"), 0, "Cash")
	expectEqual(localPlayer:GetAttribute("NightTokens"), 0, "NightTokens")
	Test.expectLog(session.Server, "Player1 está pronto")

	local DataService = serverModule(session, "Services/DataService")
	local stats = DataService:Get(client.ServerPlayer, "Stats")
	expectEqual(stats.Deaths, 0, "Stats.Deaths")
	expect(DataService:Get(client.ServerPlayer, "UnlockedMaps").GasStation, "posto desbloqueado")
	expect(DataService:Get(client.ServerPlayer, "FirstJoin") > 0, "FirstJoin preenchido")
	Test.expectNoErrors(session.Server)
	Test.expectNoErrors(client)
end)

test("Fase2/TESTE 1: moeda dada pelo servidor aparece no cliente e no painel", function(context)
	local session = newSession(context)
	local client = session:addClient("Player1", 1001)
	waitReady(client)
	local DataService = serverModule(session, "Services/DataService")
	expectEqual(DataService:Increment(client.ServerPlayer, "Cash", 150), 150, "novo saldo")
	expectEqual(client.LocalPlayer:GetAttribute("Cash"), 150, "atributo no cliente")
	local label = Test.waitFor(function()
		local overlay = client.LocalPlayer.PlayerGui:FindFirstChild("DebugOverlay")
		return overlay and string.find(overlay.Stats.Text, "$150", 1, true) and overlay.Stats
	end, 3, "painel mostrando $150")
	expect(string.find(label.Text, "KeyboardMouse", 1, true), `tipo de controle no painel: {label.Text}`)
end)

test("Fase2/TESTE 1: dados continuam após sair e voltar (mesmo servidor)", function(context)
	local session = newSession(context)
	local client = session:addClient("Player1", 1001)
	waitReady(client)
	local DataService = serverModule(session, "Services/DataService")
	DataService:Increment(client.ServerPlayer, "Cash", 75)
	DataService:IncrementStat(client.ServerPlayer, "Deaths", 2)
	task.wait(1.1)
	session:removeClient(client)
	expect(not DataService:IsLoaded(client.ServerPlayer), "perfil liberado ao sair")

	local again = session:addClient("Player1", 1001)
	waitReady(again)
	expectEqual(again.LocalPlayer:GetAttribute("Cash"), 75, "Cash preservado")
	local stats = DataService:Get(again.ServerPlayer, "Stats")
	expectEqual(stats.Deaths, 2, "Stats.Deaths preservado")
	expect(stats.PlayTime >= 1, `PlayTime contado ({stats.PlayTime})`)
end)

test("Fase2/TESTE 1: tipo de controle é detectado e ações respondem", function(context)
	local session = newSession(context)
	local client = session:addClient("Player1", 1001)
	waitReady(client)
	local InputController = clientModule(client, "Controllers/InputController")
	expectEqual(InputController:GetInputType(), "KeyboardMouse", "inicial")

	local changes = {}
	InputController.InputTypeChanged:Connect(function(inputType)
		table.insert(changes, inputType)
	end)
	local uis = client.UserInputService
	uis.LastInputTypeChanged:Fire(Mock.Enum.UserInputType.Touch)
	expectEqual(InputController:GetInputType(), "Touch", "toque")
	uis.LastInputTypeChanged:Fire(Mock.Enum.UserInputType.Focus)
	expectEqual(InputController:GetInputType(), "Touch", "Focus não muda o tipo")
	uis.LastInputTypeChanged:Fire(Mock.Enum.UserInputType.Gamepad1)
	expectEqual(InputController:GetInputType(), "Gamepad", "controle")
	task.wait()
	expectEqual(table.concat(changes, ","), "Touch,Gamepad", "eventos de troca")

	local presses = 0
	InputController:BindAction(
		"TestAction",
		{ Keyboard = Mock.Enum.KeyCode.E, Gamepad = Mock.Enum.KeyCode.ButtonX },
		function()
			presses += 1
		end
	)
	uis.InputBegan:Fire({ KeyCode = Mock.Enum.KeyCode.E }, false)
	uis.InputBegan:Fire({ KeyCode = Mock.Enum.KeyCode.ButtonX }, false)
	uis.InputBegan:Fire({ KeyCode = Mock.Enum.KeyCode.E }, true)
	uis.InputBegan:Fire({ KeyCode = Mock.Enum.KeyCode.Q }, false)
	task.wait()
	expectEqual(presses, 2, "E e ButtonX acionam; digitando no chat e outras teclas não")
	InputController:UnbindAction("TestAction")
	uis.InputBegan:Fire({ KeyCode = Mock.Enum.KeyCode.E }, false)
	task.wait()
	expectEqual(presses, 2, "ação removida não dispara")
end)

test("Fase2/TESTE 1: celular começa em Touch e controle começa em Gamepad", function(context)
	local session = newSession(context)
	local phone = session:addClient("Phone", 1001, { device = "Touch" })
	local console = session:addClient("Console", 1002, { device = "Gamepad" })
	waitReady(phone)
	waitReady(console)
	expectEqual(clientModule(phone, "Controllers/InputController"):GetInputType(), "Touch", "celular")
	expectEqual(clientModule(console, "Controllers/InputController"):GetInputType(), "Gamepad", "controle")
end)

-- TESTE 2 ----------------------------------------------------------------------------

test("Fase2/TESTE 2: dois jogadores têm dados separados", function(context)
	local session = newSession(context)
	local first = session:addClient("Player1", -1)
	local second = session:addClient("Player2", -2)
	waitReady(first)
	waitReady(second)
	local DataService = serverModule(session, "Services/DataService")
	DataService:Increment(first.ServerPlayer, "Cash", 40)
	expectEqual(first.LocalPlayer:GetAttribute("Cash"), 40, "Player1")
	expectEqual(second.LocalPlayer:GetAttribute("Cash"), 0, "Player2 não recebeu")
	local PlayerService = serverModule(session, "Services/PlayerService")
	expectEqual(#PlayerService:GetReadyPlayers(), 2, "dois prontos")
	session:removeClient(first)
	expectEqual(#PlayerService:GetReadyPlayers(), 1, "um pronto após saída")
	expect(DataService:IsLoaded(second.ServerPlayer), "Player2 continua carregado")
end)

-- TESTE 3 ----------------------------------------------------------------------------

test("Fase2/TESTE 3: valores inválidos são rejeitados pelo DataService", function(context)
	local session = newSession(context)
	local client = session:addClient("Player1", 1001)
	waitReady(client)
	local DataService = serverModule(session, "Services/DataService")
	local player = client.ServerPlayer

	expectEqual(DataService:Increment(player, "Cash", 0 / 0), nil, "NaN")
	expectEqual(DataService:Increment(player, "Cash", math.huge), nil, "infinito")
	expectEqual(DataService:Increment(player, "Stats", 1), nil, "Increment em tabela")
	expectEqual(DataService:Increment(player, "CampoFalso", 1), nil, "campo inexistente")
	expectEqual(DataService:Set(player, "Cash", "999999"), false, "string no Cash")
	expectEqual(DataService:Set(player, "Admin", true), false, "campo inventado")
	expectEqual(DataService:IncrementStat(player, "Inventada", 1), nil, "stat inexistente")
	expectEqual(client.LocalPlayer:GetAttribute("Cash"), 0, "Cash intacto")
	Test.expectLog(session.Server, "Set rejeitado para Player1")
end)

test("Fase2/TESTE 3: Get devolve cópia (não dá para alterar dados por fora)", function(context)
	local session = newSession(context)
	local client = session:addClient("Player1", 1001)
	waitReady(client)
	local DataService = serverModule(session, "Services/DataService")
	local stats = DataService:Get(client.ServerPlayer, "Stats")
	stats.Deaths = 999
	expectEqual(DataService:Get(client.ServerPlayer, "Stats").Deaths, 0, "dado original intacto")

	local changed = {}
	DataService.Changed:Connect(function(_, key, value)
		changed[key] = value
	end)
	DataService:Update(client.ServerPlayer, "Titles", function(titles)
		titles.FirstShift = true
		return titles
	end)
	task.wait()
	expect(changed.Titles and changed.Titles.FirstShift, "Changed disparado com o novo valor")
end)

test("Fase2/TESTE 3: jogador que sai durante o carregamento não quebra nada", function(context)
	local session = newSession(context, {
		patches = {
			[MEMORY_BACKEND] = function(source)
				return (string.gsub(source, "LATENCY_SECONDS = 0", "LATENCY_SECONDS = 0.3"))
			end,
		},
	})
	local client = session:addClient("Player1", 1001)
	task.wait(0.05)
	session:removeClient(client)
	task.wait(0.5)
	local DataService = serverModule(session, "Services/DataService")
	expect(not DataService:IsLoaded(client.ServerPlayer), "sem perfil fantasma")
	Test.expectLog(session.Server, "saiu antes de terminar de carregar")
	Test.expectNoErrors(session.Server)
end)

test("Fase2/TESTE 3: dados de perfis antigos ganham campos novos sem perder os antigos", function(context)
	local session = newSession(context)
	local backend = serverModule(session, "Data/MemoryBackend")
	backend:Save(2002, { Cash = 500, Level = 7, Stats = { Deaths = 3 } })
	local client = session:addClient("Veteran", 2002)
	waitReady(client)
	local DataService = serverModule(session, "Services/DataService")
	expectEqual(client.LocalPlayer:GetAttribute("Cash"), 500, "Cash antigo")
	expectEqual(client.LocalPlayer:GetAttribute("Level"), 7, "Level antigo")
	local stats = DataService:Get(client.ServerPlayer, "Stats")
	expectEqual(stats.Deaths, 3, "stat antiga")
	expectEqual(stats.TasksCompleted, 0, "stat nova adicionada")
	expectEqual(DataService:Get(client.ServerPlayer, "Settings").Subtitles, true, "Settings adicionadas")
end)

test("Fase2/TESTE 3: fechar o servidor salva todos os jogadores", function(context)
	local session = newSession(context)
	local client = session:addClient("Player1", 1001)
	waitReady(client)
	local DataService = serverModule(session, "Services/DataService")
	DataService:Increment(client.ServerPlayer, "Cash", 33)
	session:shutdown()
	local backend = serverModule(session, "Data/MemoryBackend")
	local ok, saved = backend:Load(1001)
	expect(ok and saved and saved.Cash == 33, "Cash salvo no BindToClose")
end)

test("Fase2/TESTE 3: estado inválido de jogador gera erro claro", function(context)
	local session = newSession(context)
	local client = session:addClient("Player1", 1001)
	waitReady(client)
	local PlayerService = serverModule(session, "Services/PlayerService")
	local ok, err = pcall(PlayerService.SetState, PlayerService, client.ServerPlayer, "Voando")
	expect(not ok and string.find(err, "estado inválido", 1, true), "deveria rejeitar")
	PlayerService:SetState(client.ServerPlayer, "InShift")
	expectEqual(client.LocalPlayer:GetAttribute("State"), "InShift", "estado replicado")
end)
