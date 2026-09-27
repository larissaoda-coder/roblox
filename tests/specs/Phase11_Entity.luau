--!nocheck
-- FASE 11: entidade (EntityService), morte e espectador (SpectatorService/Controller).

local task = require("@lune/task")

local Mock = require("../harness/Mock")
local Session = require("../harness/Session")
local Test = require("../harness/Test")

local test, expect, expectEqual = Test.test, Test.expect, Test.expectEqual

local function at(x, y, z)
	return Mock.Vector3.new(x, y, 600 + z)
end

local function service(session, name)
	return session.Server:require(session.Server.game.ServerScriptService.Server.Services[name])
end

local function invoke(session, client, remoteName, ...)
	return session:clientRemote(client, remoteName):InvokeServer(...)
end

local function startShift(context, players)
	local session = Session.new({
		patches = {
			["src/shared/Config/MatchConfig.luau"] = function(source)
				source = string.gsub(source, "BRIEFING_SECONDS = 10", "BRIEFING_SECONDS = 0.1")
				source = string.gsub(source, "RESULTS_SECONDS = 10", "RESULTS_SECONDS = 0.5")
				return (
					string.gsub(
						source,
						"REAL_SECONDS_PER_GAME_MINUTE = 15",
						"REAL_SECONDS_PER_GAME_MINUTE = 60"
					)
				)
			end,
		},
	})
	table.insert(context.sessions, session)
	Test.expectLog(session.Server, "servidor pronto")
	service(session, "DirectorService"):SetEnabled(false)
	local clients = {}
	for index = 1, players or 1 do
		local client = session:addClient(`Player{index}`, -index)
		Test.waitFor(function()
			return client.LocalPlayer:GetAttribute("Ready") == true
				and client.LocalPlayer.PlayerGui:FindFirstChild("Spectator")
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
	end, 3, "turno")
	return session, clients, session.Server.workspace.Runtime.ActiveMap
end

local function moveTo(client, position)
	client.ServerPlayer.Character.HumanoidRootPart.Position = position
end

local function discovered(session, client, eventId)
	return service(session, "DataService"):Get(client.ServerPlayer, "Discoveries")[eventId] ~= nil
end

test("Fase11/TESTE 1: entidade observando de longe some quando alguém se aproxima", function(context)
	local session, clients, map = startShift(context)
	local Entity = service(session, "EntityService")
	moveTo(clients[1], at(0, 3, 40)) -- lado de fora, nas bombas
	Entity:Force("Watching")
	Test.waitFor(function()
		return Entity:GetState() == "Watching" and map:FindFirstChild("Entity")
	end, 1, "entidade observando")
	expect(discovered(session, clients[1], "EntitySighting"), "avistamento registrado")
	local figure = map.Entity
	moveTo(clients[1], figure.Root.Position)
	Test.waitFor(function()
		return Entity:GetState() == "Dormant" and map:FindFirstChild("Entity") == nil
	end, 2, "sumiu ao se aproximar")
end)

test("Fase11/TESTE 1: aparição rápida perto de alguém e seguir quem está sozinho", function(context)
	local session, clients, map = startShift(context, 2)
	local Entity = service(session, "EntityService")
	moveTo(clients[1], at(4, 3, -2)) -- perto do fim do corredor (nó HideAisle)
	moveTo(clients[2], at(0, 3, 40))
	Entity:Force("Manifest")
	Test.waitFor(function()
		return map:FindFirstChild("Entity") ~= nil
	end, 1, "apareceu")
	expect(discovered(session, clients[1], "EntityManifest"), "aparição registrada")
	Test.waitFor(function()
		return map:FindFirstChild("Entity") == nil and Entity:GetState() == "Dormant"
	end, 3, "sumiu")

	-- Seguir: só quem está sozinho ouve a respiração.
	moveTo(clients[1], at(0, 3, -90))
	moveTo(clients[2], at(0, 3, 40))
	local perception1 =
		clients[1]:require(clients[1].LocalPlayer.PlayerScripts.Client.Controllers.PerceptionController)
	local perception2 =
		clients[2]:require(clients[2].LocalPlayer.PlayerScripts.Client.Controllers.PerceptionController)
	table.clear(perception1.Recent)
	table.clear(perception2.Recent)
	Entity:Force("Stalking")
	Test.waitFor(function()
		return Entity:GetState() == "Stalking"
	end, 1, "seguindo")
	-- Os dois estão sozinhos: a entidade escolhe um deles. Só UM ouve.
	Test.waitFor(function()
		return table.find(perception1.Recent, "Sound") or table.find(perception2.Recent, "Sound")
	end, 2, "respiração ouvida")
	local heard1 = table.find(perception1.Recent, "Sound") ~= nil
	local heard2 = table.find(perception2.Recent, "Sound") ~= nil
	expect(heard1 ~= heard2, "só o jogador seguido ouve")
end)

test("Fase11/TESTE 1: caçada alcança quem ficou sozinho; ele vira espectador dos colegas", function(context)
	local session, clients = startShift(context, 2)
	local Entity = service(session, "EntityService")
	local victim, survivor = clients[1], clients[2]
	moveTo(victim, at(0, 3, -90)) -- sozinho na floresta
	moveTo(survivor, at(-10, 3, 8)) -- na loja
	Entity:Force("Hunt", victim.ServerPlayer)
	Test.waitFor(function()
		return Entity:GetState() == "Hunt"
	end, 1, "caçando")
	Test.waitFor(function()
		return victim.LocalPlayer:GetAttribute("State") == "Spectating"
	end, 8, "vítima alcançada")
	expectEqual(service(session, "DataService"):Get(victim.ServerPlayer, "Stats").Deaths, 1, "morte contada")
	expect(service(session, "MatchService"):IsAlive(survivor.ServerPlayer), "colega vivo")

	local spectator = victim:require(victim.LocalPlayer.PlayerScripts.Client.Controllers.SpectatorController)
	Test.waitFor(function()
		return spectator:IsActive() and #spectator:GetTargets() == 1
	end, 1, "espectador com 1 colega")
	expectEqual(spectator:GetTargets()[1].Name, "Player2", "assiste o colega vivo")
	expect(victim.LocalPlayer.PlayerGui.Spectator.Enabled, "tela de espectador")

	-- Espectador renasce no lobby, não no mapa, e não interage com nada.
	victim.ServerPlayer.LoadCharacter()
	task.wait(0.1)
	local position = victim.ServerPlayer.Character.HumanoidRootPart.Position
	expect(position.Z < 400, "renasceu longe do mapa")
end)

test("Fase11/TESTE 1: quem volta para a loja iluminada com a equipe fica protegido", function(context)
	local session, clients = startShift(context, 2)
	local Entity = service(session, "EntityService")
	moveTo(clients[1], at(-10, 3, 8))
	moveTo(clients[2], at(-8, 3, 8))
	Entity:Force("Hunt", clients[1].ServerPlayer)
	task.wait(0.3)
	expectEqual(Entity:GetState(), "Dormant", "não caça quem está protegido")
	expectEqual(clients[1].LocalPlayer:GetAttribute("State"), "InShift", "vivo")
end)

test("Fase11/TESTE 1: equipe inteira morre — turno fracassado e volta ao lobby", function(context)
	local session, clients = startShift(context)
	local client = clients[1]
	service(session, "SpectatorService"):Kill(client.ServerPlayer, "Teste")
	Test.waitFor(function()
		return service(session, "MatchService"):GetPhase() == "Results"
	end, 2, "resultado")
	Test.waitFor(function()
		return client.LocalPlayer.PlayerGui.HUD.Banner.Text == "TURNO FRACASSADO"
	end, 1, "aviso de fracasso")
	Test.waitFor(function()
		return service(session, "MatchService"):GetPhase() == "Idle"
	end, 3, "fim")
	Test.waitFor(function()
		return client.LocalPlayer:GetAttribute("State") == "Lobby"
	end, 2, "de volta ao lobby")
	expect(not client.LocalPlayer.PlayerGui.Spectator.Enabled, "tela de espectador fechada")
end)

test("Fase11/TESTE 3: morte por outro motivo (queda) também vira espectador", function(context)
	local session, clients = startShift(context, 2)
	local humanoid = clients[1].ServerPlayer.Character.Humanoid
	humanoid.Health = 0
	humanoid.Died:Fire()
	Test.waitFor(function()
		return clients[1].LocalPlayer:GetAttribute("State") == "Spectating"
	end, 1, "espectador")
	expectEqual(service(session, "SpectatorService"):GetDeathCause(clients[1].ServerPlayer), "Fall", "causa")
	-- Espectador não recebe eventos perceptivos nem entra no sorteio de alvos.
	expect(
		service(session, "TensionService"):GetMostVulnerable() == clients[2].ServerPlayer,
		"alvo é o vivo"
	)
end)

test("Fase11/TESTE 3: temperamento sorteado e segredo das 04:44 desperta a caçada", function(context)
	local session, clients, map = startShift(context)
	local Entity = service(session, "EntityService")
	local temperament = Entity:GetTemperament()
	expect(
		temperament == "Shy" or temperament == "Curious" or temperament == "Aggressive",
		`temperamento {temperament}`
	)
	moveTo(clients[1], map.Store.Phone.Position + Mock.Vector3.new(0, 0, 3))
	service(session, "EventService"):Trigger("DontAnswer")
	local prompt = map.Store.Phone.InteractionPrompt
	prompt.PromptButtonHoldBegan:Fire(clients[1].ServerPlayer)
	prompt.Triggered:Fire(clients[1].ServerPlayer)
	moveTo(clients[1], at(0, 3, -90)) -- sai sozinho para a floresta
	Test.waitFor(function()
		return Entity:GetState() == "Hunt" and Entity:GetHuntTarget() == clients[1].ServerPlayer
	end, 9, "caçada depois do segredo")
end)
