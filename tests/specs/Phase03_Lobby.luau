--!nocheck
-- FASE 3: lobby (LobbyService, LobbyController, LobbyScreen, LobbyBuilder).

local task = require("@lune/task")

local Mock = require("../harness/Mock")
local Session = require("../harness/Session")
local Test = require("../harness/Test")

local test, expect, expectEqual = Test.test, Test.expect, Test.expectEqual

local function newSession(context, options)
	local session = Session.new(options)
	table.insert(context.sessions, session)
	Test.expectLog(session.Server, "servidor pronto")
	return session
end

local function lobbyService(session)
	return session.Server:require(session.Server.game.ServerScriptService.Server.Services.LobbyService)
end

local function joinLobby(session, name, userId, options)
	local client = session:addClient(name, userId, options)
	Test.waitFor(function()
		return client.LocalPlayer.PlayerGui:FindFirstChild("LobbyUI")
	end, 3, `LobbyUI de {name}`)
	return client
end

local function find(client, name)
	local gui = client.LocalPlayer.PlayerGui:FindFirstChild("LobbyUI")
	if not gui then
		return nil
	end
	for _, descendant in gui:GetDescendants() do
		if descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function waitFind(client, name, timeout)
	return Test.waitFor(function()
		return find(client, name)
	end, timeout or 2, `"{name}" na tela de {client.Name}`)
end

local function click(client, name)
	local button = waitFind(client, name)
	expect(button:GetAttribute("Disabled") ~= true, `botão {name} está desabilitado`)
	button.Activated:Fire()
	task.wait(0.05)
end

local function toastText(client)
	local toast = find(client, "Toast")
	return toast and toast.Visible and toast.Text or nil
end

local function invoke(session, client, remoteName, ...)
	return session:clientRemote(client, remoteName):InvokeServer(...)
end

-- TESTE 1 ----------------------------------------------------------------------------

test("Fase3/TESTE 1: lobby 3D é gerado com spawn", function(context)
	local session = newSession(context)
	local lobby = session.Server.workspace:FindFirstChild("Lobby")
	expect(lobby, "Workspace.Lobby")
	expect(lobby:FindFirstChild("SpawnLocation"), "SpawnLocation")
	expect(lobby:FindFirstChild("Floor") and lobby:FindFirstChild("Sign"), "chão e placa")
end)

test("Fase3/TESTE 1: lobby existente feito no Studio não é substituído", function(context)
	local session = Session.new({
		patches = {
			["src/server/World/LobbyBuilder.luau"] = function(source)
				-- Simula um Lobby criado à mão antes do jogo iniciar.
				return string.gsub(
					source,
					'local existing = workspace:FindFirstChild%("Lobby"%)',
					'local custom = Instance.new("Model"); custom.Name = "Lobby"; custom:SetAttribute("Custom", true); custom.Parent = workspace\n\tlocal existing = workspace:FindFirstChild("Lobby")'
				)
			end,
		},
	})
	table.insert(context.sessions, session)
	Test.expectLog(session.Server, "servidor pronto")
	expect(session.Server.workspace.Lobby:GetAttribute("Custom") == true, "manteve o lobby do usuário")
	expect(session.Server.workspace.Lobby:FindFirstChild("Floor") == nil, "não gerou outro")
end)

test("Fase3/TESTE 1: jogador abre JOGAR, cria turno, fica pronto e inicia", function(context)
	local session = newSession(context)
	local client = joinLobby(session, "Player1", 1001)
	local gui = client.LocalPlayer.PlayerGui.LobbyUI
	expect(gui.Enabled, "lobby visível")
	expectEqual(find(client, "Title").Text, "NIGHT SHIFT: 4AM", "título")
	expect(find(client, "Menu_Shop"):GetAttribute("Disabled") ~= true, "LOJA disponível")

	click(client, "Menu_Play")
	expect(find(client, "Modal").Visible, "janela aberta")
	expectEqual(find(client, "ModalTitle").Text, "TURNOS", "título da janela")
	waitFind(client, "NoShifts")
	expect(find(client, "CreateMap_Hotel"):GetAttribute("Disabled") == true, "Hotel em breve")

	click(client, "CreateMap_GasStation")
	local party = Test.waitFor(function()
		return lobbyService(session):GetPartyOf(client.ServerPlayer)
	end, 2, "turno criado no servidor")
	expectEqual(party.MapId, "GasStation", "mapa")

	-- A janela troca sozinha para o painel do turno.
	Test.waitFor(function()
		return find(client, "ModalTitle").Text == "SEU TURNO"
	end, 2, "painel do turno")
	local chip = find(client, "PartyChip")
	expect(
		chip.Visible and string.find(chip.Text, "Posto de Gasolina · 1/4", 1, true),
		`indicador: {chip.Text}`
	)
	expect(
		waitFind(client, "StartButton"):GetAttribute("Disabled") == true,
		"INICIAR bloqueado antes do pronto"
	)

	click(client, "ReadyButton")
	Test.waitFor(function()
		local start = find(client, "StartButton")
		return start and start:GetAttribute("Disabled") ~= true
	end, 2, "INICIAR liberado")
	expect(party.Ready[client.ServerPlayer], "pronto no servidor")

	-- A partir da Fase 4, iniciar leva o jogador para a partida e esconde o lobby.
	click(client, "StartButton")
	Test.waitFor(function()
		return client.LocalPlayer:GetAttribute("State") == "InShift"
	end, 2, "jogador em turno")
	expect(not gui.Enabled, "lobby escondido durante o turno")
	expect(lobbyService(session):GetPartyOf(client.ServerPlayer) == nil, "grupo desfeito ao iniciar")
	Test.expectNoErrors(session.Server)
	Test.expectNoErrors(client)
end)

test("Fase3/TESTE 1: com um sistema de partida registrado, o turno inicia", function(context)
	local session = newSession(context)
	local launched
	lobbyService(session):SetLaunchHandler(function(request)
		launched = request
		return true
	end)
	local client = joinLobby(session, "Player1", 1001)
	click(client, "Menu_Play")
	click(client, "CreateMap_GasStation")
	click(client, "ReadyButton")
	Test.waitFor(function()
		local start = find(client, "StartButton")
		return start and start:GetAttribute("Disabled") ~= true
	end, 2, "INICIAR liberado")
	click(client, "StartButton")
	Test.waitFor(function()
		return launched
	end, 2, "handler chamado")
	expectEqual(launched.MapId, "GasStation", "mapa enviado")
	expectEqual(launched.Players[1], client.ServerPlayer, "jogadores enviados")
	Test.waitFor(function()
		for _, descendant in client.LocalPlayer.PlayerGui.LobbyUI:GetDescendants() do
			if descendant.ClassName == "TextLabel" and descendant.Text == "INICIANDO" then
				return true
			end
		end
		return false
	end, 2, "cliente mostra INICIANDO")
end)

test("Fase3/TESTE 1: perfil mostra nível, cash e estatísticas", function(context)
	local session = newSession(context)
	local client = joinLobby(session, "Player1", 1001)
	local DataService =
		session.Server:require(session.Server.game.ServerScriptService.Server.Services.DataService)
	DataService:Increment(client.ServerPlayer, "Cash", 85)
	DataService:IncrementStat(client.ServerPlayer, "TasksCompleted", 7)
	click(client, "Menu_Profile")
	Test.waitFor(function()
		local line = find(client, "Line3")
		return line and line.Text == "CASH 85"
	end, 2, "CASH 85")
	expectEqual(find(client, "Stat_TasksCompleted").Value.Text, "7", "tarefas concluídas")
	click(client, "CloseButton")
	expect(not find(client, "Modal").Visible, "janela fechada")
end)

test("Fase3/TESTE 1: celular usa botões maiores e escala para telas pequenas", function(context)
	local session = newSession(context)
	local client =
		joinLobby(session, "Phone", 1001, { device = "Touch", viewportWidth = 812, viewportHeight = 375 })
	local menuButton = waitFind(client, "Menu_Play")
	expectEqual(menuButton.Size.Y.Offset, 56, "altura do botão no celular")
	local scale = find(client, "Scale").Scale
	expect(scale >= 0.7 and scale <= 0.75, `escala limitada no celular ({scale})`)

	client.Camera.ViewportSize = Mock.Vector2.new(1920, 1080)
	expect(find(client, "Scale").Scale > 1.2, "escala aumenta em telas grandes")
end)

test("Fase3/TESTE 1: controle seleciona o primeiro botão ao abrir uma janela", function(context)
	local session = newSession(context)
	local client = joinLobby(session, "Console", 1001, { device = "Gamepad" })
	click(client, "Menu_Play")
	local selected = client.game.GuiService.SelectedObject
	expect(selected and selected.Name == "CreateMap_GasStation", "primeiro botão selecionado")
end)

test("Fase3/TESTE 1: lobby some quando o jogador sai do estado Lobby", function(context)
	local session = newSession(context)
	local client = joinLobby(session, "Player1", 1001)
	local PlayerService =
		session.Server:require(session.Server.game.ServerScriptService.Server.Services.PlayerService)
	PlayerService:SetState(client.ServerPlayer, "InShift")
	expect(not client.LocalPlayer.PlayerGui.LobbyUI.Enabled, "escondido durante o turno")
	PlayerService:SetState(client.ServerPlayer, "Lobby")
	expect(client.LocalPlayer.PlayerGui.LobbyUI.Enabled, "visível de novo")
end)

-- TESTE 2 ----------------------------------------------------------------------------

test("Fase3/TESTE 2: segundo jogador vê o turno, entra, e ambos precisam estar prontos", function(context)
	local session = newSession(context)
	local host = joinLobby(session, "Player1", -1)
	local guest = joinLobby(session, "Player2", -2)

	click(host, "Menu_Play")
	click(host, "CreateMap_GasStation")
	local party = Test.waitFor(function()
		return lobbyService(session):GetPartyOf(host.ServerPlayer)
	end, 2, "turno criado")

	click(guest, "Menu_Play")
	click(guest, `Join_{party.Id}`)
	Test.waitFor(function()
		return #party.Members == 2
	end, 2, "convidado entrou")
	Test.waitFor(function()
		local chip = find(host, "PartyChip")
		return chip and string.find(chip.Text, "2/4", 1, true)
	end, 2, "líder vê 2/4")
	expect(find(guest, "StartButton") == nil, "convidado não tem botão INICIAR")

	click(host, "ReadyButton")
	local ok, result = invoke(session, host, "StartParty")
	expect(ok and result.Error == "NotAllReady", "precisa de todos prontos")
	local _, guestStart = invoke(session, guest, "StartParty")
	expectEqual(guestStart.Error, "NotHost", "convidado não pode iniciar")

	click(guest, "ReadyButton")
	Test.waitFor(function()
		local start = find(host, "StartButton")
		return start and start:GetAttribute("Disabled") ~= true
	end, 2, "INICIAR liberado para o líder")
end)

test("Fase3/TESTE 2: se o líder sai, o próximo vira líder; turno vazio some", function(context)
	local session = newSession(context)
	local host = joinLobby(session, "Player1", -1)
	local guest = joinLobby(session, "Player2", -2)
	local _, created = invoke(session, host, "CreateParty", "GasStation")
	invoke(session, guest, "JoinParty", created.PartyId)
	local party = lobbyService(session):GetParty(created.PartyId)

	session:removeClient(host)
	Test.waitFor(function()
		return party.Host == guest.ServerPlayer
	end, 2, "convidado virou líder")
	click(guest, "Menu_Play")
	waitFind(guest, "StartButton")

	click(guest, "LeaveButton")
	Test.waitFor(function()
		return lobbyService(session):GetParty(created.PartyId) == nil
	end, 2, "turno removido")
	Test.waitFor(function()
		return find(guest, "NoShifts")
	end, 2, "lista vazia de novo")
	expect(not find(guest, "PartyChip").Visible, "indicador escondido")
end)

-- TESTE 3 ----------------------------------------------------------------------------

test("Fase3/TESTE 3: pedidos inválidos são recusados pelo servidor", function(context)
	local session = newSession(context)
	local client = joinLobby(session, "Player1", 1001)

	local _, locked = invoke(session, client, "CreateParty", "Hotel")
	expectEqual(locked.Error, "MapLocked", "mapa em breve")
	local _, invalid = invoke(session, client, "CreateParty", "MapaFalso")
	expectEqual(invalid.Error, "InvalidMap", "mapa inexistente")
	local ok, reason = invoke(session, client, "CreateParty", 12345)
	expect(not ok and string.find(reason, "Arg1", 1, true), "tipo errado barrado pelo Net")
	local _, missing = invoke(session, client, "JoinParty", "P999")
	expectEqual(missing.Error, "PartyNotFound", "turno inexistente")
	local _, notIn = invoke(session, client, "SetReady", true)
	expectEqual(notIn.Error, "NotInParty", "pronto sem turno")
	local okReady, readyReason = invoke(session, client, "SetReady", "sim")
	expect(not okReady and string.find(readyReason, "Arg1", 1, true), "boolean falso barrado")

	task.wait(1.8) -- CreateParty permite 3 pedidos a cada 5 s; espera recarregar 1
	local _, first = invoke(session, client, "CreateParty", "GasStation")
	expect(first.Success, "primeiro turno")
	local _, twice = invoke(session, client, "JoinParty", first.PartyId)
	expectEqual(twice.Error, "AlreadyInParty", "não entra em dois turnos")
end)

test("Fase3/TESTE 3: turno cheio recusa o quinto jogador", function(context)
	local session = newSession(context)
	local players = {}
	for index = 1, 5 do
		players[index] = session:addClient(`Player{index}`, 1000 + index)
	end
	Test.waitFor(function()
		for _, client in players do
			if client.LocalPlayer:GetAttribute("Ready") ~= true then
				return false
			end
		end
		return true
	end, 3, "todos prontos")
	local _, created = invoke(session, players[1], "CreateParty", "GasStation")
	for index = 2, 4 do
		local _, joined = invoke(session, players[index], "JoinParty", created.PartyId)
		expect(joined.Success, `Player{index} entrou`)
	end
	local _, fifth = invoke(session, players[5], "JoinParty", created.PartyId)
	expectEqual(fifth.Error, "PartyFull", "quinto jogador")
end)

test("Fase3/TESTE 3: jogador fora do lobby não mexe em turnos; saída remove do turno", function(context)
	local session = newSession(context)
	local client = joinLobby(session, "Player1", 1001)
	local other = joinLobby(session, "Player2", 1002)
	local PlayerService =
		session.Server:require(session.Server.game.ServerScriptService.Server.Services.PlayerService)
	PlayerService:SetState(client.ServerPlayer, "InShift")
	local _, blocked = invoke(session, client, "CreateParty", "GasStation")
	expectEqual(blocked.Error, "NotInLobby", "fora do lobby")

	local _, created = invoke(session, other, "CreateParty", "GasStation")
	session:removeClient(other)
	Test.waitFor(function()
		return lobbyService(session):GetParty(created.PartyId) == nil
	end, 2, "turno removido quando o jogador sai do jogo")
end)

test("Fase3/TESTE 3: erro no sistema de partida não trava o turno", function(context)
	local session = newSession(context)
	lobbyService(session):SetLaunchHandler(function()
		error("falha simulada")
	end)
	local client = joinLobby(session, "Player1", 1001)
	local _, created = invoke(session, client, "CreateParty", "GasStation")
	invoke(session, client, "SetReady", true)
	local _, result = invoke(session, client, "StartParty")
	expectEqual(result.Error, "Unknown", "erro genérico para o jogador")
	expect(not lobbyService(session):GetParty(created.PartyId).Launching, "turno destravado")
	Test.expectLog(session.Server, "Erro ao iniciar o turno")
end)

test("Fase3/TESTE 3: spam de cliques não gera pedidos duplicados", function(context)
	local session = newSession(context)
	local client = joinLobby(session, "Player1", 1001)
	click(client, "Menu_Play")
	local button = waitFind(client, "CreateMap_GasStation")
	for _ = 1, 10 do
		button.Activated:Fire()
	end
	task.wait(0.3)
	local count = 0
	for _, party in lobbyService(session):GetSnapshot().Parties do
		count += 1
	end
	expectEqual(count, 1, "apenas um turno criado")
	Test.expectNoErrors(session.Server)
end)
