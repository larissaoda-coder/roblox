--!nocheck
-- FASE 10: clientes (NPCService), diálogos (DialogueService/Controller) e documentos.

local task = require("@lune/task")

local Mock = require("../harness/Mock")
local Session = require("../harness/Session")
local Test = require("../harness/Test")

local test, expect, expectEqual = Test.test, Test.expect, Test.expectEqual

local function service(session, name)
	return session.Server:require(session.Server.game.ServerScriptService.Server.Services[name])
end

local function invoke(session, client, remoteName, ...)
	return session:clientRemote(client, remoteName):InvokeServer(...)
end

local function startShift(context, options)
	options = options or {}
	local session = Session.new({
		patches = {
			["src/shared/Config/MatchConfig.luau"] = function(source)
				source = string.gsub(source, "BRIEFING_SECONDS = 10", "BRIEFING_SECONDS = 0.1")
				return (
					string.gsub(
						source,
						"REAL_SECONDS_PER_GAME_MINUTE = 15",
						`REAL_SECONDS_PER_GAME_MINUTE = {options.secondsPerMinute or 30}`
					)
				)
			end,
			-- NPCs andando muito rápido para o teste não demorar.
			["src/server/ServerDefinitions/NPCDefinitions.luau"] = function(source)
				source = string.gsub(source, "WalkSpeed = data.WalkSpeed or 8", "WalkSpeed = 600")
				return source
			end,
		},
	})
	table.insert(context.sessions, session)
	Test.expectLog(session.Server, "servidor pronto")
	service(session, "DirectorService"):SetEnabled(false)
	local client = session:addClient("Player1", 1)
	Test.waitFor(function()
		return client.LocalPlayer:GetAttribute("Ready") == true
			and client.LocalPlayer.PlayerGui:FindFirstChild("Dialogue")
	end, 3, "pronto")
	invoke(session, client, "CreateParty", "GasStation")
	invoke(session, client, "SetReady", true)
	invoke(session, client, "StartParty")
	Test.waitFor(function()
		return service(session, "MatchService"):GetPhase() == "Shift"
	end, 3, "turno")
	return session, client, session.Server.workspace.Runtime.ActiveMap
end

local function press(client, target)
	local prompt = target:FindFirstChild("InteractionPrompt")
	prompt.PromptButtonHoldBegan:Fire(client.ServerPlayer)
	prompt.Triggered:Fire(client.ServerPlayer)
	task.wait(0.4)
end

local function waitWaiting(npc)
	Test.waitFor(function()
		return npc.State == "Waiting"
	end, 3, "cliente chegou ao caixa")
end

local function nearCounter(client, npc)
	client.ServerPlayer.Character.HumanoidRootPart.Position = npc.Model.PrimaryPart.Position
		+ Mock.Vector3.new(0, 0, 3)
end

local function dialogueText(client)
	return client.LocalPlayer.PlayerGui.Dialogue.Panel.Text.Text
end

test("Fase10/TESTE 1: cliente chega, é atendido, conversa com escolhas e vai embora", function(context)
	local session, client = startShift(context)
	local NPCs = service(session, "NPCService")
	local npc = NPCs:Spawn("Commuter")
	expect(npc, "cliente criado")
	waitWaiting(npc)
	local root = npc.Model.PrimaryPart
	expect(root:GetAttribute("Enabled") == true, "prompt de atender liberado")
	nearCounter(client, npc)
	press(client, root)

	local gui = client.LocalPlayer.PlayerGui.Dialogue
	Test.waitFor(function()
		return gui.Enabled and dialogueText(client) == "Bom dia. Ou boa noite. Sei lá que horas são."
	end, 1, "primeira fala")
	expectEqual(gui.Panel.Speaker.Text, "Cliente", "nome")
	expect(
		gui.Panel.Choices:FindFirstChild("Choice1") and gui.Panel.Choices:FindFirstChild("Choice2"),
		"duas escolhas"
	)

	local controller = client:require(client.LocalPlayer.PlayerScripts.Client.Controllers.DialogueController)
	controller:Choose(1)
	Test.waitFor(function()
		return dialogueText(client) == "Ótimo. Ainda tenho muita estrada pela frente."
	end, 1, "segunda fala")
	controller:Choose(1)
	Test.waitFor(function()
		return not gui.Enabled
	end, 1, "conversa encerrada")
	expectEqual(NPCs:GetServedCount(client.ServerPlayer), 1, "cliente atendido")
	Test.waitFor(function()
		return #NPCs:GetActive() == 0
	end, 3, "cliente foi embora")
end)

test("Fase10/TESTE 1: escolha condicional só aparece depois de certo horário", function(context)
	local session, client = startShift(context)
	local npc = service(session, "NPCService"):Spawn("Police")
	waitWaiting(npc)
	nearCounter(client, npc)
	press(client, npc.Model.PrimaryPart)
	local choices = client.LocalPlayer.PlayerGui.Dialogue.Panel.Choices
	Test.waitFor(function()
		return choices:FindFirstChild("Choice1") ~= nil
	end, 1, "escolhas")
	expect(choices:FindFirstChild("Choice2") == nil, "antes das 04:30 só existe 'nada fora do normal'")
end)

test("Fase10/TESTE 1: conversa com o senhor revela uma parte da história (descoberta)", function(context)
	local session, client = startShift(context)
	local npc = service(session, "NPCService"):Spawn("OldMan")
	waitWaiting(npc)
	nearCounter(client, npc)
	press(client, npc.Model.PrimaryPart)
	local controller = client:require(client.LocalPlayer.PlayerScripts.Client.Controllers.DialogueController)
	for _ = 1, 3 do
		task.wait(0.1)
		controller:Choose(1)
	end
	Test.waitFor(function()
		return service(session, "DataService"):Get(client.ServerPlayer, "Discoveries").OldManStory ~= nil
	end, 2, "história descoberta")
end)

test("Fase10/TESTE 1: cliente sem registro — some das câmeras e conta como descoberta", function(context)
	local session, client, map = startShift(context)
	expect(service(session, "EventService"):Trigger("CustomerNoRecord"), "evento")
	local NPCs = service(session, "NPCService")
	local npc = NPCs:GetActive()[1]
	waitWaiting(npc)
	expect(npc.Model:GetAttribute("NoCameraRecord") == true, "marcado como sem registro")
	local monitor = map.Office.SecurityMonitor
	client.ServerPlayer.Character.HumanoidRootPart.Position = monitor.Position + Mock.Vector3.new(0, -1, 3)
	press(client, monitor)
	local cameras =
		client:require(client.LocalPlayer.PlayerScripts.Client.Controllers.SecurityCameraController)
	Test.waitFor(function()
		return cameras:IsOpen()
	end, 1, "monitor")
	cameras:Next() -- CAM02 = caixa
	Test.waitFor(function()
		return service(session, "DataService"):Get(client.ServerPlayer, "Discoveries").CustomerNoRecord ~= nil
	end, 1, "descoberto pela câmera do caixa")
end)

test("Fase10/TESTE 1: clientes aparecem sozinhos ao longo do turno", function(context)
	local session = startShift(context, { secondsPerMinute = 0.1 })
	Test.waitFor(function()
		return Test.findLog(session.Server, "Cliente: ") ~= nil
	end, 4, "algum cliente chegou")
end)

test("Fase10/TESTE 1: documento é lido e fica registrado", function(context)
	local session, client, map = startShift(context)
	local schedule = map.Store.ShiftSchedule
	client.ServerPlayer.Character.HumanoidRootPart.Position = schedule.Position + Mock.Vector3.new(0, 0, 3)
	press(client, schedule)
	local gui = client.LocalPlayer.PlayerGui.Document
	Test.waitFor(function()
		return gui.Enabled and gui.Paper.Title.Text == "ESCALA DO TURNO DA NOITE — ROTA 44"
	end, 1, "documento aberto")
	expect(
		service(session, "DataService"):Get(client.ServerPlayer, "Documents").ShiftSchedule,
		"salvo no perfil"
	)
	gui.Paper.CloseButton.Activated:Fire()
	task.wait(0.05)
	expect(not gui.Enabled, "fechado")
end)

test("Fase10/TESTE 3: escolha inválida é ignorada; afastar-se encerra a conversa", function(context)
	local session, client = startShift(context)
	local npc = service(session, "NPCService"):Spawn("Driver")
	waitWaiting(npc)
	nearCounter(client, npc)
	press(client, npc.Model.PrimaryPart)
	local dialogue = service(session, "DialogueService")
	Test.waitFor(function()
		return dialogue:IsTalking(client.ServerPlayer)
	end, 1, "conversando")
	local choiceRemote = session:clientRemote(client, "DialogueChoice")
	choiceRemote:FireServer(5) -- só existem 2 escolhas
	task.wait(0.1)
	expect(dialogue:IsTalking(client.ServerPlayer), "escolha inexistente não faz nada")
	client.ServerPlayer.Character.HumanoidRootPart.Position = Mock.Vector3.new(0, 3, 900)
	choiceRemote:FireServer(1)
	Test.waitFor(function()
		return not dialogue:IsTalking(client.ServerPlayer)
	end, 1, "conversa encerrada à distância")
	expectEqual(
		service(session, "NPCService"):GetServedCount(client.ServerPlayer),
		0,
		"não conta como atendido"
	)
end)

test("Fase10/TESTE 3: fim do turno remove os clientes", function(context)
	local session = startShift(context)
	service(session, "NPCService"):Spawn("Trucker")
	service(session, "MatchService"):AbortMatch()
	Test.waitFor(function()
		return #service(session, "NPCService"):GetActive() == 0
	end, 3, "clientes removidos")
end)
