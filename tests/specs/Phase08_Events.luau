--!nocheck
-- FASES 8 e 9: eventos, diretor, tensão, câmeras, percepção, luz, clima, áudio e configurações.

local task = require("@lune/task")

local Mock = require("../harness/Mock")
local Session = require("../harness/Session")
local Test = require("../harness/Test")

local test, expect, expectEqual = Test.test, Test.expect, Test.expectEqual

local ORIGIN_Z = 600
local function at(x, y, z)
	return Mock.Vector3.new(x, y, ORIGIN_Z + z)
end

local function service(session, name)
	return session.Server:require(session.Server.game.ServerScriptService.Server.Services[name])
end

local function clientModule(client, name)
	return client:require(client.LocalPlayer.PlayerScripts.Client.Controllers[name])
end

local function invoke(session, client, remoteName, ...)
	return session:clientRemote(client, remoteName):InvokeServer(...)
end

-- Turno no posto real com o relógio quase parado e o diretor desligado (eventos só quando o teste manda).
local function startShift(context, options)
	options = options or {}
	local patches = {
		["src/shared/Config/MatchConfig.luau"] = function(source)
			source = string.gsub(source, "BRIEFING_SECONDS = 10", "BRIEFING_SECONDS = 0.1")
			source = string.gsub(source, "RESULTS_SECONDS = 10", "RESULTS_SECONDS = 0.2")
			local seconds = options.secondsPerMinute or 30
			return (
				string.gsub(
					source,
					"REAL_SECONDS_PER_GAME_MINUTE = 15",
					`REAL_SECONDS_PER_GAME_MINUTE = {seconds}`
				)
			)
		end,
	}
	for path, patch in options.patches or {} do
		patches[path] = patch
	end
	local session = Session.new({ patches = patches })
	table.insert(context.sessions, session)
	Test.expectLog(session.Server, "servidor pronto")
	if not options.director then
		service(session, "DirectorService"):SetEnabled(false)
	end
	local clients = {}
	for index = 1, options.players or 1 do
		local client = session:addClient(`Player{index}`, -index)
		Test.waitFor(function()
			return client.LocalPlayer:GetAttribute("Ready") == true
				and client.LocalPlayer.PlayerGui:FindFirstChild("CameraFeed")
		end, 3, "pronto")
		table.insert(clients, client)
	end
	local _, created = invoke(session, clients[1], "CreateParty", "GasStation")
	for index = 2, #clients do
		invoke(session, clients[index], "JoinParty", created.PartyId)
	end
	for _, client in clients do
		invoke(session, client, "SetReady", true)
	end
	invoke(session, clients[1], "StartParty")
	Test.waitFor(function()
		return service(session, "MatchService"):GetPhase() == "Shift"
	end, 3, "turno começou")
	return session, clients, session.Server.workspace.Runtime.ActiveMap
end

local function moveTo(client, position)
	client.ServerPlayer.Character.HumanoidRootPart.Position = position
end

local function press(client, target)
	local prompt = target:FindFirstChild("InteractionPrompt")
	prompt.PromptButtonHoldBegan:Fire(client.ServerPlayer)
	prompt.Triggered:Fire(client.ServerPlayer)
	task.wait(0.4)
end

local function discoveries(session, client)
	return service(session, "DataService"):Get(client.ServerPlayer, "Discoveries")
end

-- Definições ------------------------------------------------------------------------------

test("Fase8/Unit: 15 eventos definidos, com módulos e raridades", function(context)
	local session = Session.new({})
	table.insert(context.sessions, session)
	Test.expectLog(session.Server, "servidor pronto")
	local EventDefinitions = session.Server:require(
		session.Server.game.ServerScriptService.Server.ServerDefinitions.EventDefinitions
	)
	local all = EventDefinitions.getAll()
	expect(#all >= 15, `eventos: {#all}`)
	local rarities = {}
	for _, definition in all do
		rarities[definition.Rarity] = true
		expect(
			definition.DiscoveryOnly
				or session.Server.game.ServerScriptService.Server.Events:FindFirstChild(definition.Module),
			`módulo {definition.Module}`
		)
	end
	for _, rarity in { "COMMON", "UNCOMMON", "RARE", "VERY_RARE", "SECRET" } do
		expect(rarities[rarity], `raridade {rarity}`)
	end
	local weights = EventDefinitions.RARITY_WEIGHTS
	expect(
		weights.COMMON > weights.UNCOMMON
			and weights.UNCOMMON > weights.RARE
			and weights.RARE > weights.SECRET,
		"pesos"
	)
end)

-- Luz ---------------------------------------------------------------------------------------

test("Fase9/TESTE 1: zona apagada, piscar, blackout e interruptor", function(context)
	local session, clients, map = startShift(context)
	local client = clients[1]
	local Lighting = service(session, "LightingService")
	-- O simulador não replica o Workspace: copiamos o mapa para o cliente, como o Roblox faria.
	local clientMap = map:Clone()
	clientMap.Parent = client.workspace
	local storeLight = clientMap.Store.StoreLight1
	local clientLight = function()
		return storeLight:FindFirstChildWhichIsA("Light")
	end

	Lighting:SetZone("Store", "Off")
	Test.waitFor(function()
		return clientLight().Enabled == false
	end, 1, "luz apagada no cliente")
	expect(Lighting:IsDark("Store"), "zona escura")

	Lighting:SetZone("Store", "On")
	Lighting:Blackout(0.4)
	Test.waitFor(function()
		return clientLight().Enabled == false
			and clientMap.Store.StoreEmergency:FindFirstChildWhichIsA("Light").Enabled
	end, 1, "blackout com emergência")
	Test.waitFor(function()
		return not Lighting:IsBlackout() and clientLight().Enabled == true
	end, 2, "energia voltou")

	-- Interruptor da loja.
	local switch = map.Store.StoreLightSwitch
	moveTo(client, switch.Position + Mock.Vector3.new(0, 0, -2))
	press(client, switch)
	expectEqual(Lighting:GetZoneState("Store"), "Off", "interruptor apaga")
	Lighting:Blackout(5)
	press(client, switch)
	expectEqual(Lighting:GetZoneState("Store"), "Off", "sem energia o interruptor não funciona")
	Test.waitFor(function()
		return client.LocalPlayer.PlayerGui.Notifications.Message.Text == "Está sem energia."
	end, 1, "aviso sem energia")
end)

test("Fase9/TESTE 1: clima sorteado e raios na tempestade", function(context)
	local session, clients = startShift(context, {
		patches = {
			["src/server/Services/WeatherService.luau"] = function(source)
				source = string.gsub(source, "Clear = { Weight = 45", "Clear = { Weight = 0")
				source = string.gsub(source, "Fog = { Weight = 30", "Fog = { Weight = 0")
				source = string.gsub(source, "Rain = { Weight = 20", "Rain = { Weight = 0")
				source = string.gsub(source, "LIGHTNING_MIN_SECONDS = 20", "LIGHTNING_MIN_SECONDS = 0.1")
				return (string.gsub(source, "LIGHTNING_MAX_SECONDS = 55", "LIGHTNING_MAX_SECONDS = 0.2"))
			end,
		},
	})
	local state = session.Server.game.ReplicatedStorage.LightingState
	expectEqual(state:GetAttribute("Weather"), "Storm", "tempestade")
	Test.waitFor(function()
		return state:GetAttribute("LightningAt") ~= nil
	end, 2, "raio")
	local audio = clientModule(clients[1], "AudioController")
	Test.waitFor(function()
		return table.find(audio.RecentSubtitles, "SUB_THUNDER")
	end, 2, "legenda do trovão")
	expect(session.Server.game.Lighting.FogEnd < 900, "neblina da tempestade")
end)

-- Configurações -------------------------------------------------------------------------------

test("Fase9/TESTE 3: configurações são validadas no servidor", function(context)
	local session = Session.new({})
	table.insert(context.sessions, session)
	Test.expectLog(session.Server, "servidor pronto")
	local client = session:addClient("Player1", 1)
	Test.waitFor(function()
		return client.LocalPlayer:GetAttribute("Ready") == true
	end, 2, "pronto")
	local _, ok = invoke(session, client, "UpdateSetting", "MasterVolume", 5)
	expectEqual(ok.Value, 1, "volume limitado a 1")
	local _, bad = invoke(session, client, "UpdateSetting", "Admin", true)
	expectEqual(bad.Error, "InvalidSetting", "chave inventada")
	local _, wrongType = invoke(session, client, "UpdateSetting", "Subtitles", 1)
	expectEqual(wrongType.Error, "InvalidSetting", "tipo errado")
	local rejected = invoke(session, client, "UpdateSetting", "MasterVolume", 0 / 0)
	expect(rejected == false, "NaN barrado pelo Net")
	local _, settings = invoke(session, client, "GetSettings")
	expectEqual(settings.MasterVolume, 1, "salvo")
end)

-- Tensão --------------------------------------------------------------------------------------

test("Fase8/TESTE 1: tensão sobe sozinho na floresta e desce com a equipe na loja", function(context)
	local session, clients = startShift(context, {
		players = 2,
		patches = {
			["src/server/ServerDefinitions/TensionConfig.luau"] = function(source)
				return (string.gsub(source, "TICK_SECONDS = 1,", "TICK_SECONDS = 0.1,"))
			end,
		},
	})
	local Tension = service(session, "TensionService")
	local alone, teammate = clients[1], clients[2]
	moveTo(alone, at(0, 3, -90))
	moveTo(teammate, at(-10, 3, 8))
	Test.waitFor(function()
		return Tension:Get(alone.ServerPlayer) > 10
	end, 3, "tensão subindo na floresta")
	expect(Tension:Get(teammate.ServerPlayer) < 5, "quem está na loja fica calmo")
	Test.waitFor(function()
		return (alone.LocalPlayer:GetAttribute("Tension") or 0) > 10
	end, 1, "atributo replicado")
	moveTo(alone, at(-8, 3, 8))
	local before = Tension:Get(alone.ServerPlayer)
	Test.waitFor(function()
		return Tension:Get(alone.ServerPlayer) < before - 3
	end, 3, "tensão cai com a equipe na loja")
	expectEqual(Tension:GetMostVulnerable(), alone.ServerPlayer, "mais vulnerável") -- ainda com mais tensão
end)

test("Fase8/TESTE 1: tensão alta gera sons falsos só para o jogador", function(context)
	local session, clients = startShift(context, {
		players = 3,
		patches = {
			["src/server/ServerDefinitions/TensionConfig.luau"] = function(source)
				source = string.gsub(source, "TICK_SECONDS = 1,", "TICK_SECONDS = 0.1,")
				source = string.gsub(source, "PHANTOM_THRESHOLD = 60", "PHANTOM_THRESHOLD = 0")
				return (
					string.gsub(source, "PHANTOM_CHANCE_PER_SECOND = 0.025", "PHANTOM_CHANCE_PER_SECOND = 20")
				)
			end,
		},
	})
	moveTo(clients[1], at(0, 3, -90))
	moveTo(clients[2], at(-10, 3, 8))
	moveTo(clients[3], at(-8, 3, 8))
	local perception = clientModule(clients[1], "PerceptionController")
	local other = clientModule(clients[2], "PerceptionController")
	Test.waitFor(function()
		return #perception.Recent > 0
	end, 2, "som falso recebido")
	expectEqual(#other.Recent, 0, "o colega na loja não ouviu nada")
end)

-- Eventos forçados ------------------------------------------------------------------------------

test("Fase8/TESTE 1: luzes piscando, produto caindo, porta aberta e blackout", function(context)
	local session, clients, map = startShift(context)
	local Events = service(session, "EventService")
	local Lighting = service(session, "LightingService")
	moveTo(clients[1], at(-10, 3, 8))

	expect(Events:Trigger("LightsFlicker"), "LightsFlicker")
	Test.waitFor(function()
		return Lighting:GetZoneState("Store") == "Flicker"
	end, 1, "loja piscando")

	expect(Events:Trigger("ProductFall"), "ProductFall")
	Test.waitFor(function()
		for _, child in map.Store:GetChildren() do
			if string.find(child.Name, "^Product") and child.Anchored == false then
				return true
			end
		end
		return false
	end, 1, "produto caiu")

	expect(Events:Trigger("DoorOpened"), "DoorOpened")
	Test.waitFor(function()
		for _, door in map.Doors:GetChildren() do
			if door:GetAttribute("Open") == true then
				return true
			end
		end
		return false
	end, 1, "alguma porta abriu sozinha")

	expect(Events:Trigger("Blackout"), "Blackout")
	Test.waitFor(function()
		return Lighting:IsBlackout()
	end, 1, "blackout")
	expect(discoveries(session, clients[1]).Blackout, "blackout descoberto")
	expectEqual(
		service(session, "DataService"):Get(clients[1].ServerPlayer, "Stats").EventsDiscovered >= 2,
		true,
		"estatística"
	)
end)

test("Fase8/TESTE 1: telefone toca; quem atende ouve a ligação e descobre o evento", function(context)
	local session, clients, map = startShift(context)
	local client = clients[1]
	local phone = map.Store.Phone
	expect(phone:GetAttribute("Enabled") == false, "telefone mudo antes")
	expect(service(session, "EventService"):Trigger("PhoneRing"), "PhoneRing")
	expect(phone:GetAttribute("Enabled") == true, "telefone tocando pode ser atendido")
	moveTo(client, phone.Position + Mock.Vector3.new(0, 0, 3))
	press(client, phone)
	expect(phone:GetAttribute("Enabled") == false, "atendido")
	Test.waitFor(function()
		local text = client.LocalPlayer.PlayerGui.Notifications.Message.Text
		return string.find(text, '"', 1, true) or string.find(text, "(", 1, true)
	end, 1, "fala da ligação")
	expect(discoveries(session, client).PhoneRing, "descoberta")
end)

test("Fase8/TESTE 1: passos fantasmas e reflexo só para o jogador-alvo", function(context)
	local session, clients, map = startShift(context, { players = 2 })
	local Events = service(session, "EventService")
	local target, other = clients[1], clients[2]
	moveTo(target, map.Bathroom.Mirror.Position + Mock.Vector3.new(0, -2, 4))
	moveTo(other, at(0, 3, 40)) -- nas bombas, longe do banheiro
	service(session, "TensionService"):Add(target.ServerPlayer, 40, "teste")

	expect(Events:Trigger("PhantomFootsteps"), "PhantomFootsteps")
	local targetPerception = clientModule(target, "PerceptionController")
	local otherPerception = clientModule(other, "PerceptionController")
	Test.waitFor(function()
		return table.find(targetPerception.Recent, "Sound")
	end, 2, "alvo ouviu passos")
	expect(Events:Trigger("Reflection"), "Reflection")
	Test.waitFor(function()
		return table.find(targetPerception.Recent, "Figure")
	end, 1, "alvo viu a figura")
	expectEqual(#otherPerception.Recent, 0, "o outro jogador não percebeu nada")
	expect(discoveries(session, target).Reflection, "reflexo descoberto pelo alvo")
	expect(discoveries(session, other).Reflection == nil, "o outro não descobriu")
end)

test("Fase8/TESTE 1: objeto de tarefa some e volta", function(context)
	local session, clients = startShift(context, {
		patches = {
			["src/server/Events/MissingObject.luau"] = function(source)
				return (string.gsub(source, "ctx.Rng:Number%(40, 70%)", "0.3"))
			end,
		},
	})
	local Tasks = service(session, "TaskService")
	local before = #Tasks:GetAvailablePoints()
	expect(service(session, "EventService"):Trigger("MissingObject"), "MissingObject")
	Test.waitFor(function()
		return #Tasks:GetAvailablePoints() == before - 1
	end, 1, "ponto bloqueado")
	Test.waitFor(function()
		return #Tasks:GetAvailablePoints() == before
	end, 2, "objeto voltou")
end)

test("Fase8/TESTE 1: câmeras — monitor, troca, figura só na câmera e fechamento", function(context)
	local session, clients, map = startShift(context)
	local client = clients[1]
	local monitor = map.Office.SecurityMonitor
	moveTo(client, monitor.Position + Mock.Vector3.new(0, -1, 3))
	press(client, monitor)
	local cameraController = clientModule(client, "SecurityCameraController")
	Test.waitFor(function()
		return cameraController:IsOpen()
	end, 1, "monitor aberto")
	local feed = client.LocalPlayer.PlayerGui.CameraFeed
	expect(feed.Enabled, "tela das câmeras")
	expectEqual(feed.CameraLabel.Text, "CAM01 — ENTRADA", "primeira câmera")
	expectEqual(
		client.Camera.CameraType,
		Mock.Enum.CameraType.Scriptable,
		"câmera do jogador presa na câmera de segurança"
	)

	expect(service(session, "EventService"):Trigger("CameraFigure"), "CameraFigure")
	local anomalies = client.workspace.NS_CameraAnomalies
	task.wait(0.1)
	expectEqual(#anomalies:GetChildren(), 0, "figura não aparece na CAM01")
	cameraController:Next()
	cameraController:Next()
	Test.waitFor(function()
		return feed.CameraLabel.Text == "CAM03 — ESTOQUE" and #anomalies:GetChildren() == 1
	end, 1, "figura aparece na CAM03")
	Test.waitFor(function()
		return discoveries(session, client).CameraFigure ~= nil
	end, 1, "quem viu na câmera descobriu")

	-- Afastar-se do monitor fecha as câmeras.
	moveTo(client, at(-10, 3, 8))
	Test.waitFor(function()
		return not cameraController:IsOpen()
	end, 3, "fechou ao se afastar")
	expectEqual(client.Camera.CameraType, Mock.Enum.CameraType.Custom, "câmera do jogador voltou")
	expectEqual(#anomalies:GetChildren(), 0, "figura escondida fora do monitor")
end)

test("Fase8/TESTE 1: figura na estrada às 04:33 some quando alguém se aproxima", function(context)
	local session, clients, map = startShift(context)
	moveTo(clients[1], at(-4, 3, 30)) -- lado de fora (bombas)
	expect(service(session, "EventService"):Trigger("RoadFigure"), "RoadFigure")
	local figure = Test.waitFor(function()
		return map:FindFirstChild("RoadFigure")
	end, 1, "figura na estrada")
	expect(discoveries(session, clients[1]).RoadFigure, "quem estava fora viu")
	moveTo(clients[1], at(20, 3, 80))
	Test.waitFor(function()
		return map:FindFirstChild("RoadFigure") == nil
	end, 2, "sumiu ao se aproximar")
end)

test("Fase8/TESTE 1: segredo das 04:44 — quem atende descobre o segredo", function(context)
	local session, clients, map = startShift(context)
	local client = clients[1]
	local Events = service(session, "EventService")
	local secret
	Events.SecretTriggered:Connect(function(id, player)
		secret = `{id}:{player.Name}`
	end)
	expect(Events:Trigger("DontAnswer"), "DontAnswer")
	moveTo(client, map.Store.Phone.Position + Mock.Vector3.new(0, 0, 3))
	press(client, map.Store.Phone)
	Test.waitFor(function()
		return secret == "DontAnswer:Player1"
	end, 4, "segredo disparado")
	local stats = service(session, "DataService"):Get(client.ServerPlayer, "Stats")
	expectEqual(stats.SecretsFound, 1, "segredo contado")
	expect(service(session, "LightingService"):IsBlackout(), "blackout depois da ligação")
end)

test("Fase8/TESTE 1: eventos de horário especial respeitam o minuto certo", function(context)
	local session = startShift(context, {
		patches = {
			["src/server/ServerDefinitions/EventDefinitions.luau"] = function(source)
				return (string.gsub(source, "SpecialChance = %d%.%d+", "SpecialChance = 1"))
			end,
		},
	})
	local Events = service(session, "EventService")
	expectEqual(#Events:TrySpecial(20), 0, "nada no minuto 20")
	local triggered = Events:TrySpecial(17)
	expectEqual(triggered[1], "KnockBackDoor", "04:17 = batidas")
	expectEqual(#Events:TrySpecial(17), 0, "não repete no mesmo turno")
end)

-- Diretor ---------------------------------------------------------------------------------------

test("Fase8/TESTE 1: diretor — começo calmo e escalada ao longo do turno", function(context)
	local session = startShift(context, { director = true, secondsPerMinute = 0.05 })
	local decisions = {}
	service(session, "DirectorService").Decision:Connect(function(minute, decision)
		table.insert(decisions, { minute, decision })
	end)
	Test.waitFor(function()
		return service(session, "MatchService"):GetPhase() == "Results"
			or service(session, "MatchService"):GetPhase() == "Idle"
	end, 8, "fim do turno")
	local events = 0
	for _, item in decisions do
		local minute, decision = item[1], item[2]
		if minute < 3 then
			expectEqual(decision, "Quiet", `minuto {minute} deveria ser calmo`)
		end
		if
			decision ~= "Quiet"
			and decision ~= "Cooldown"
			and decision ~= "Breathing"
			and decision ~= "Skipped"
			and decision ~= "None"
		then
			events += 1
		end
	end
	expect(events >= 3 and events <= 30, `eventos no turno: {events}`)
end)

test("Fase8/TESTE 3: evento que não pode acontecer (sem alvo) é recusado sem erro", function(context)
	local session = startShift(context)
	local Events = service(session, "EventService")
	expect(not Events:Trigger("Reflection"), "ninguém perto do espelho")
	expect(not Events:Trigger("EventoInventado"), "id inexistente")
	Test.expectNoErrors(session.Server)
end)
