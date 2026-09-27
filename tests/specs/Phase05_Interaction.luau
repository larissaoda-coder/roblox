--!nocheck
-- FASE 5: interação (InteractionService, DoorService, InteractionController, NotificationController).

local task = require("@lune/task")

local Mock = require("../harness/Mock")
local Session = require("../harness/Session")
local Test = require("../harness/Test")

local test, expect, expectEqual = Test.test, Test.expect, Test.expectEqual

local function newSession(context)
	local session = Session.new({})
	table.insert(context.sessions, session)
	Test.expectLog(session.Server, "servidor pronto")
	return session
end

local function service(session, name)
	return session.Server:require(session.Server.game.ServerScriptService.Server.Services[name])
end

local function joined(session, name, userId, options)
	local client = session:addClient(name, userId, options)
	Test.waitFor(function()
		return client.LocalPlayer:GetAttribute("Ready") == true
			and client.LocalPlayer.PlayerGui:FindFirstChild("InteractionUI") ~= nil
	end, 3, `{name} pronto`)
	return client
end

-- Cria uma porta interativa perto do spawn do lobby (personagem fica em 0, 3, 14).
local function makeDoor(session, attributes, position)
	local door = session.Server.newInstance("Part")
	door.Name = "TestDoor"
	door.Size = Mock.Vector3.new(4, 7, 0.4)
	door.Position = position or Mock.Vector3.new(0, 3, 18)
	door.CFrame = Mock.CFrame.new(door.Position)
	door:SetAttribute("InteractionType", "Door")
	door:SetAttribute("RequiresShift", false)
	for key, value in attributes or {} do
		door:SetAttribute(key, value)
	end
	door:AddTag("Interactable")
	door.Parent = session.Server.workspace
	return door,
		Test.waitFor(function()
			return door:FindFirstChild("InteractionPrompt")
		end, 1, "prompt criado")
end

local function press(prompt, player, holdSeconds)
	prompt.PromptButtonHoldBegan:Fire(player)
	if holdSeconds and holdSeconds > 0 then
		task.wait(holdSeconds)
	end
	prompt.Triggered:Fire(player)
	task.wait(0.05)
end

-- TESTE 1 ----------------------------------------------------------------------------

test("Fase5/TESTE 1: porta abre e fecha pelo prompt", function(context)
	local session = newSession(context)
	local client = joined(session, "Player1", 1001)
	local door, prompt = makeDoor(session)
	expectEqual(prompt.Style, Mock.Enum.ProximityPromptStyle.Custom, "estilo customizado")
	expectEqual(prompt.KeyboardKeyCode, Mock.Enum.KeyCode.E, "tecla E")
	expectEqual(prompt.GamepadKeyCode, Mock.Enum.KeyCode.ButtonX, "botão X")

	local changes = {}
	service(session, "DoorService").DoorChanged:Connect(function(_, open, cause)
		table.insert(changes, `{open}:{cause}`)
	end)
	press(prompt, client.ServerPlayer)
	expect(door:GetAttribute("Open") == true, "porta aberta")
	expectEqual(prompt:GetAttribute("PromptKey"), "PROMPT_CLOSE_DOOR", "texto muda para fechar")
	task.wait(0.4) -- cooldown
	press(prompt, client.ServerPlayer)
	expect(door:GetAttribute("Open") == false, "porta fechada")
	expectEqual(table.concat(changes, ","), "true:Player,false:Player", "eventos da porta")
end)

test(
	"Fase5/TESTE 1: aviso de interação aparece com a tecla certa (PC, controle, celular)",
	function(context)
		local session = newSession(context)
		local pc = joined(session, "PC", 1)
		local phone = joined(session, "Phone", 2, { device = "Touch" })
		local console = joined(session, "Console", 3, { device = "Gamepad" })

		local function show(client)
			local prompt = client.newInstance("ProximityPrompt")
			prompt.Style = Mock.Enum.ProximityPromptStyle.Custom
			prompt.HoldDuration = 0
			prompt:SetAttribute("PromptKey", "PROMPT_OPEN_DOOR")
			client.ProximityPromptService.PromptShown:Fire(
				prompt,
				Mock.Enum.ProximityPromptInputType.Keyboard
			)
			task.wait()
			return prompt, client.LocalPlayer.PlayerGui.InteractionUI.InteractButton
		end

		local _, pcPanel = show(pc)
		expect(pcPanel.Visible, "painel visível no PC")
		expectEqual(pcPanel.Key.Text, "E", "tecla E")
		expectEqual(pcPanel.Action.Text, "Abrir porta", "texto")

		local _, consolePanel = show(console)
		expectEqual(consolePanel.Key.Text, "X", "botão X")

		local phonePrompt, phonePanel = show(phone)
		expect(not phonePanel.Key.Visible, "sem tecla no celular")
		expectEqual(phonePanel.Action.Text, "INTERAGIR · Abrir porta", "texto no celular")
		phonePanel.MouseButton1Down:Fire()
		expect(phonePrompt.__holding == true, "tocar segura o prompt")
		phonePanel.MouseButton1Up:Fire()
		expect(phonePrompt.__holding == false, "soltar libera")

		phone.ProximityPromptService.PromptHidden:Fire(phonePrompt)
		task.wait()
		expect(not phonePanel.Visible, "painel some quando o prompt some")
	end
)

test("Fase5/TESTE 1: prompts de outros estilos são ignorados pela nossa UI", function(context)
	local session = newSession(context)
	local client = joined(session, "Player1", 1001)
	local prompt = client.newInstance("ProximityPrompt")
	prompt.Style = Mock.Enum.ProximityPromptStyle.Default
	client.ProximityPromptService.PromptShown:Fire(prompt)
	task.wait()
	expect(not client.LocalPlayer.PlayerGui.InteractionUI.InteractButton.Visible, "painel continua escondido")
end)

-- TESTE 2 ----------------------------------------------------------------------------

test("Fase5/TESTE 2: dois jogadores usam a mesma porta; cada um tem seu cooldown", function(context)
	local session = newSession(context)
	local first = joined(session, "Player1", -1)
	local second = joined(session, "Player2", -2)
	local door, prompt = makeDoor(session)
	press(prompt, first.ServerPlayer)
	press(prompt, second.ServerPlayer)
	expect(door:GetAttribute("Open") == false, "abriu e fechou (dois jogadores, sem esperar)")
end)

-- TESTE 3 ----------------------------------------------------------------------------

test("Fase5/TESTE 3: longe demais é recusado", function(context)
	local session = newSession(context)
	local client = joined(session, "Player1", 1001)
	local door, prompt = makeDoor(session, nil, Mock.Vector3.new(0, 3, 200))
	local reasons = {}
	service(session, "InteractionService").Rejected:Connect(function(_, _, reason)
		table.insert(reasons, reason)
	end)
	press(prompt, client.ServerPlayer)
	expect(door:GetAttribute("Open") ~= true, "porta não abriu")
	expectEqual(reasons[1], "TooFar", "motivo")
end)

test("Fase5/TESTE 3: objeto de partida não funciona no lobby", function(context)
	local session = newSession(context)
	local client = joined(session, "Player1", 1001)
	local door, prompt = makeDoor(session, { RequiresShift = true })
	press(prompt, client.ServerPlayer)
	expect(door:GetAttribute("Open") ~= true, "recusado fora do turno")
end)

test("Fase5/TESTE 3: segurar exige o tempo certo (anti-exploit)", function(context)
	local session = newSession(context)
	local client = joined(session, "Player1", 1001)
	local door, prompt = makeDoor(session, { HoldDuration = 0.5 })
	expectEqual(prompt.HoldDuration, 0.5, "tempo de segurar no prompt")
	local reasons = {}
	service(session, "InteractionService").Rejected:Connect(function(_, _, reason)
		table.insert(reasons, reason)
	end)

	prompt.Triggered:Fire(client.ServerPlayer) -- sem segurar
	task.wait(0.05)
	press(prompt, client.ServerPlayer, 0.1) -- segurou pouco
	expect(door:GetAttribute("Open") ~= true, "ainda fechada")
	expectEqual(table.concat(reasons, ","), "NoHold,HoldTooShort", "motivos")

	press(prompt, client.ServerPlayer, 0.45)
	expect(door:GetAttribute("Open") == true, "abriu segurando o tempo certo")
end)

test("Fase5/TESTE 3: cliques repetidos respeitam o cooldown", function(context)
	local session = newSession(context)
	local client = joined(session, "Player1", 1001)
	local door, prompt = makeDoor(session)
	for _ = 1, 5 do
		prompt.PromptButtonHoldBegan:Fire(client.ServerPlayer)
		prompt.Triggered:Fire(client.ServerPlayer)
	end
	task.wait(0.05)
	expect(door:GetAttribute("Open") == true, "só a primeira contou (abriu uma vez)")
end)

test("Fase5/TESTE 3: porta trancada avisa o jogador", function(context)
	local session = newSession(context)
	local client = joined(session, "Player1", 1001)
	local door, prompt = makeDoor(session, { Locked = true })
	press(prompt, client.ServerPlayer)
	expect(door:GetAttribute("Open") ~= true, "continua fechada")
	Test.waitFor(function()
		local message = client.LocalPlayer.PlayerGui.Notifications.Message
		return message.Visible and message.Text == "Está trancada."
	end, 2, "aviso 'Está trancada.'")
end)

test(
	"Fase5/TESTE 3: objetos mal configurados geram aviso claro; guardados no ServerStorage são ignorados",
	function(context)
		local session = newSession(context)
		local broken = session.Server.newInstance("Part")
		broken.Name = "SemTipo"
		broken:AddTag("Interactable")
		broken.Parent = session.Server.workspace
		Test.expectLog(session.Server, "não tem o atributo InteractionType")
		expect(broken:FindFirstChild("InteractionPrompt") == nil, "sem prompt")

		local stored = session.Server.newInstance("Part")
		stored:SetAttribute("InteractionType", "Door")
		stored:AddTag("Interactable")
		stored.Parent = session.Server.game.ServerStorage
		task.wait(0.05)
		expect(stored:FindFirstChild("InteractionPrompt") == nil, "ServerStorage ignorado")
	end
)

test("Fase5/TESTE 3: objeto removido do mundo perde o prompt; tipo sem handler é recusado", function(context)
	local session = newSession(context)
	local client = joined(session, "Player1", 1001)
	local door, prompt = makeDoor(session, { InteractionType = "Inexistente" })
	local reasons = {}
	service(session, "InteractionService").Rejected:Connect(function(_, _, reason)
		table.insert(reasons, reason)
	end)
	press(prompt, client.ServerPlayer)
	expectEqual(reasons[1], "NoHandler", "tipo sem handler")
	door.Parent = nil
	task.wait(0.05)
	expect(prompt.Parent == nil, "prompt destruído")
end)
