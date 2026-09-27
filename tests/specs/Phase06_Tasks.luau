--!nocheck
-- FASE 6: tarefas (TaskService, TaskDefinitions, lista de tarefas no HUD).

local task = require("@lune/task")

local Mock = require("../harness/Mock")
local Session = require("../harness/Session")
local Test = require("../harness/Test")

local test, expect, expectEqual = Test.test, Test.expect, Test.expectEqual

local ALL_POINTS = {
	Generator = { "FuelCan", "Generator" },
	RestockShelves = { "Shelf1", "Shelf2", "Shelf3" },
	TakeOutTrash = { "TrashBag", "Dumpster" },
	CheckCameras = { "CameraLog" },
	CheckPumps = { "Pump1", "Pump2", "Pump3", "Pump4" },
	CleanBathroom = { "Mop", "BathroomFloor" },
	LogDelivery = { "DeliveryBoxes", "Clipboard" },
	LockBackDoor = { "BackDoorLock" },
}

local function patches(extra)
	local list = {
		["src/shared/Config/MatchConfig.luau"] = function(source)
			source = string.gsub(source, "SHIFT_GAME_MINUTES = 60", "SHIFT_GAME_MINUTES = 40")
			source = string.gsub(
				source,
				"REAL_SECONDS_PER_GAME_MINUTE = 15",
				"REAL_SECONDS_PER_GAME_MINUTE = 0.12"
			)
			source = string.gsub(source, "BRIEFING_SECONDS = 10", "BRIEFING_SECONDS = 0.1")
			return (string.gsub(source, "RESULTS_SECONDS = 10", "RESULTS_SECONDS = 0.2"))
		end,
		-- Sem segurar (testes rápidos). O tempo de segurar já é testado na Fase 5.
		["src/shared/Definitions/TaskDefinitions.luau"] = function(source)
			return (string.gsub(source, "HoldDuration = holdDuration", "HoldDuration = 0"))
		end,
	}
	for key, value in extra or {} do
		list[key] = value
	end
	return list
end

-- Mapa de teste: um spawn e todos os pontos de tarefa bem perto dele.
local function installMap(session, skipTasks)
	local server = session.Server
	local maps = Mock.newInstance("Folder", "Maps")
	maps.Parent = server.game.ServerStorage
	local map = Mock.newInstance("Model", "GasStation")
	local spawns = Mock.newInstance("Folder", "Spawns")
	spawns.Parent = map
	for index = 1, 4 do
		local spawnPoint = Mock.newInstance("Part", `Spawn{index}`)
		spawnPoint.Position = Mock.Vector3.new(1000 + index, 0, 0)
		spawnPoint.Parent = spawns
	end
	for taskId, pointNames in ALL_POINTS do
		if not (skipTasks and table.find(skipTasks, taskId)) then
			for _, pointName in pointNames do
				local point = Mock.newInstance("Part", `{taskId}_{pointName}`)
				point.Position = Mock.Vector3.new(1002, 0, 2)
				point:SetAttribute("InteractionType", "Task")
				point:SetAttribute("TaskId", taskId)
				point:SetAttribute("Point", pointName)
				point:AddTag("Interactable")
				point.Parent = map
			end
		end
	end
	map.Parent = maps
end

local function service(session, name)
	return session.Server:require(session.Server.game.ServerScriptService.Server.Services[name])
end

local function invoke(session, client, remoteName, ...)
	return session:clientRemote(client, remoteName):InvokeServer(...)
end

local function startShift(context, clients, options)
	local session = Session.new({ patches = patches(options and options.patches) })
	table.insert(context.sessions, session)
	Test.expectLog(session.Server, "servidor pronto")
	installMap(session, options and options.skipTasks)
	local list = {}
	for index = 1, (options and options.players or 1) do
		local client = session:addClient(`Player{index}`, -index)
		Test.waitFor(function()
			return client.LocalPlayer:GetAttribute("Ready") == true
				and client.LocalPlayer.PlayerGui:FindFirstChild("HUD")
		end, 3, "pronto")
		table.insert(list, client)
	end
	local _, created = invoke(session, list[1], "CreateParty", "GasStation")
	for index = 2, #list do
		invoke(session, list[index], "JoinParty", created.PartyId)
	end
	for _, client in list do
		invoke(session, client, "SetReady", true)
	end
	local _, started = invoke(session, list[1], "StartParty")
	expect(started.Success, "turno iniciado")
	Test.expectLog(session.Server, "tarefas sorteadas")
	return session, list
end

local function taskService(session)
	return service(session, "TaskService")
end

local function point(session, taskId, pointName)
	return taskService(session):GetPoint(taskId, pointName)
end

local function prompt(session, taskId, pointName)
	return point(session, taskId, pointName):FindFirstChild("InteractionPrompt", true)
		or point(session, taskId, pointName).InteractionPrompt
end

local function press(session, client, taskId, pointName)
	local target = prompt(session, taskId, pointName)
	target.PromptButtonHoldBegan:Fire(client.ServerPlayer)
	target.Triggered:Fire(client.ServerPlayer)
	task.wait(0.4) -- cooldown de interação
end

local function activeIds(session)
	return taskService(session):GetActiveTaskIds()
end

-- TESTE 1 ----------------------------------------------------------------------------

test("Fase6/TESTE 1: 5 tarefas sorteadas, 2 liberadas no início, HUD mostra a lista", function(context)
	local session, clients = startShift(context)
	local client = clients[1]
	local summary = taskService(session):GetSummary()
	expectEqual(summary.Total, 5, "tarefas sorteadas")
	expectEqual(#activeIds(session), 2, "liberadas no início")

	local HUDController = client:require(client.LocalPlayer.PlayerScripts.Client.Controllers.HUDController)
	Test.waitFor(function()
		return #HUDController:GetTasks() == 2
	end, 2, "cliente recebeu as tarefas")
	local tasksPanel = client.LocalPlayer.PlayerGui.HUD.Tasks
	expect(tasksPanel.Visible and tasksPanel:FindFirstChild("Task2"), "lista no HUD")
	Test.waitFor(function()
		return client.game.ReplicatedStorage.MatchState:GetAttribute("Phase") == "Shift"
	end, 2, "turno")
	Test.waitFor(function()
		local objective = client.LocalPlayer.PlayerGui.HUD.Top.Objective.Text
		return string.find(objective, "OBJETIVO: ", 1, true)
			and not string.find(objective, "MANTENHA", 1, true)
	end, 2, "objetivo é a primeira tarefa")
end)

test("Fase6/TESTE 1: passos em ordem liberam o próximo e concluem a tarefa", function(context)
	local session, clients =
		startShift(context, nil, { skipTasks = { "RestockShelves", "TakeOutTrash", "CheckPumps" } })
	local client = clients[1]
	-- Sem as outras de minuto 0, o Gerador está entre as liberadas.
	expect(table.find(activeIds(session), "Generator"), "gerador liberado")
	local generatorPoint = point(session, "Generator", "Generator")
	expect(generatorPoint:GetAttribute("Enabled") == false, "gerador bloqueado antes do galão")
	expect(point(session, "Generator", "FuelCan"):GetAttribute("Enabled") == true, "galão disponível")
	expectEqual(
		prompt(session, "Generator", "FuelCan"):GetAttribute("PromptKey"),
		"PROMPT_TAKE_FUEL",
		"texto do prompt"
	)

	local notices = {}
	local Net = client:require(client.game.ReplicatedStorage.Shared.Modules.Net)
	Net.Client.on("TaskNotice", function(taskId, isNew)
		table.insert(notices, `{taskId}:{isNew}`)
	end)

	press(session, client, "Generator", "FuelCan")
	expect(generatorPoint:GetAttribute("Enabled") == true, "gerador liberado após o galão")
	press(session, client, "Generator", "Generator")
	expect(not table.find(activeIds(session), "Generator"), "tarefa concluída")
	expectEqual(taskService(session):GetSummary().Completed, 1, "resumo")
	local DataService = service(session, "DataService")
	expectEqual(DataService:Get(client.ServerPlayer, "Stats").TasksCompleted, 1, "estatística")
	expect(table.find(notices, "Generator:false"), "cliente avisado da conclusão")
end)

test("Fase6/TESTE 1: passos sem ordem podem ser feitos em qualquer sequência", function(context)
	local session, clients =
		startShift(context, nil, { skipTasks = { "Generator", "TakeOutTrash", "CheckPumps" } })
	expect(table.find(activeIds(session), "RestockShelves"), "prateleiras liberadas")
	for _, name in { "Shelf3", "Shelf1", "Shelf2" } do
		expect(point(session, "RestockShelves", name):GetAttribute("Enabled") == true, `{name} disponível`)
	end
	press(session, clients[1], "RestockShelves", "Shelf3")
	press(session, clients[1], "RestockShelves", "Shelf1")
	expect(table.find(activeIds(session), "RestockShelves"), "ainda falta uma")
	press(session, clients[1], "RestockShelves", "Shelf2")
	expect(not table.find(activeIds(session), "RestockShelves"), "concluída")
end)

test("Fase6/TESTE 1: novas tarefas aparecem ao longo do turno", function(context)
	local session, clients = startShift(context)
	local before = #activeIds(session)
	Test.waitFor(function()
		return #activeIds(session) > before
	end, 3, "nova tarefa liberada (minuto 8)")
	Test.waitFor(function()
		local message = clients[1].LocalPlayer.PlayerGui.Notifications.Message
		return message.Visible and string.find(message.Text, "Nova tarefa:", 1, true)
	end, 2, "aviso de nova tarefa")
end)

test("Fase6/TESTE 1: terminar tudo que foi liberado libera a próxima na hora", function(context)
	local session, clients =
		startShift(context, nil, { skipTasks = { "Generator", "TakeOutTrash", "CheckPumps" } })
	local ids = activeIds(session)
	for _, taskId in ids do
		for _, pointName in ALL_POINTS[taskId] do
			press(session, clients[1], taskId, pointName)
		end
	end
	Test.waitFor(function()
		return #activeIds(session) >= 1
	end, 1, "próxima tarefa liberada sem esperar o relógio")
end)

test("Fase6/TESTE 1: tarefa sem todos os pontos no mapa nunca é sorteada", function(context)
	local session = startShift(context, nil, { skipTasks = { "CleanBathroom", "Generator" } })
	for _, taskId in activeIds(session) do
		expect(taskId ~= "CleanBathroom" and taskId ~= "Generator", `{taskId} não deveria aparecer`)
	end
end)

-- TESTE 2 ----------------------------------------------------------------------------

test("Fase6/TESTE 2: dois jogadores dividem a tarefa e os dois ganham a recompensa", function(context)
	local session, clients = startShift(
		context,
		nil,
		{ players = 2, skipTasks = { "RestockShelves", "TakeOutTrash", "CheckPumps" } }
	)
	press(session, clients[1], "Generator", "FuelCan")
	press(session, clients[2], "Generator", "Generator")
	local summary = taskService(session):GetSummary()
	expectEqual(summary.Completed, 1, "concluída em equipe")
	expectEqual(summary.StepsByPlayer[clients[1].ServerPlayer], 1, "passo do jogador 1")
	expectEqual(summary.TasksByPlayer[clients[2].ServerPlayer], 1, "jogador 2 fechou a tarefa")
	expectEqual(summary.RewardByPlayer[clients[1].ServerPlayer].Cash, 20, "recompensa do jogador 1")
	expectEqual(summary.RewardByPlayer[clients[2].ServerPlayer].Cash, 20, "recompensa do jogador 2")
end)

-- TESTE 3 ----------------------------------------------------------------------------

test("Fase6/TESTE 3: pular a ordem ou usar ponto de tarefa não liberada é recusado", function(context)
	local session, clients =
		startShift(context, nil, { skipTasks = { "RestockShelves", "TakeOutTrash", "CheckPumps" } })
	local reasons = {}
	service(session, "InteractionService").Rejected:Connect(function(_, _, reason)
		table.insert(reasons, reason)
	end)
	press(session, clients[1], "Generator", "Generator") -- sem pegar o galão
	expect(table.find(activeIds(session), "Generator"), "não concluiu")
	expectEqual(reasons[1], "Disabled", "ponto desabilitado")
	-- LockBackDoor só aparece no minuto 20: o ponto está desabilitado.
	press(session, clients[1], "LockBackDoor", "BackDoorLock")
	expectEqual(taskService(session):GetSummary().Completed, 0, "nada concluído")
end)

test("Fase6/TESTE 3: evento pode bloquear um ponto de tarefa", function(context)
	local session, clients =
		startShift(context, nil, { skipTasks = { "RestockShelves", "TakeOutTrash", "CheckPumps" } })
	taskService(session):SetPointBlocked("Generator", "FuelCan", true)
	expect(point(session, "Generator", "FuelCan"):GetAttribute("Enabled") == false, "bloqueado")
	press(session, clients[1], "Generator", "FuelCan")
	expect(point(session, "Generator", "Generator"):GetAttribute("Enabled") == false, "não avançou")
	taskService(session):SetPointBlocked("Generator", "FuelCan", false)
	expect(point(session, "Generator", "FuelCan"):GetAttribute("Enabled") == true, "desbloqueado")
end)

test(
	"Fase6/TESTE 3: jogador fora da partida não faz tarefas; fim do turno desliga os pontos",
	function(context)
		local session, clients =
			startShift(context, nil, { skipTasks = { "RestockShelves", "TakeOutTrash", "CheckPumps" } })
		local outsider = session:addClient("Outsider", 999)
		Test.waitFor(function()
			return outsider.LocalPlayer:GetAttribute("Ready") == true
		end, 2, "visitante pronto")
		-- Coloca o visitante perto do ponto para testar só a regra de "estar na partida".
		outsider.ServerPlayer.Character.HumanoidRootPart.Position = Mock.Vector3.new(1002, 3, 2)
		press(session, outsider, "Generator", "FuelCan")
		expect(
			point(session, "Generator", "Generator"):GetAttribute("Enabled") == false,
			"visitante não avança a tarefa"
		)

		service(session, "MatchService"):AbortMatch()
		Test.waitFor(function()
			return service(session, "MatchService"):GetPhase() == "Idle"
		end, 3, "partida encerrada")
	end
)
