--!nocheck
-- FASE 7: mapa do posto de gasolina (GasStationBuilder).

local task = require("@lune/task")

local Mock = require("../harness/Mock")
local Session = require("../harness/Session")
local Test = require("../harness/Test")

local test, expect, expectEqual = Test.test, Test.expect, Test.expectEqual

local function buildMap()
	local session = Session.new({})
	Test.expectLog(session.Server, "servidor pronto")
	local builder =
		session.Server:require(session.Server.game.ServerScriptService.Server.World.GasStationBuilder)
	local map = builder.build("GasStation")
	return session, map
end

local function countTagged(map, tag, filter)
	local count = 0
	for _, descendant in map:GetDescendants() do
		if descendant:HasTag(tag) and (filter == nil or filter(descendant)) then
			count += 1
		end
	end
	return count
end

test("Fase7/TESTE 1: o posto tem todas as áreas, pastas e pontos obrigatórios", function(context)
	local session, map = buildMap()
	table.insert(context.sessions, session)
	for _, folderName in
		{
			"Spawns",
			"Zones",
			"SecurityCameras",
			"EventAnchors",
			"EntityNodes",
			"NPCPath",
			"Doors",
			"Store",
			"Stockroom",
			"Office",
			"Bathroom",
			"BackArea",
			"Pumps",
			"Parking",
			"Forest",
		}
	do
		expect(map:FindFirstChild(folderName), `pasta {folderName}`)
	end
	expectEqual(#map.Spawns:GetChildren(), 4, "4 spawns")
	expectEqual(#map.SecurityCameras:GetChildren(), 6, "6 câmeras")
	expectEqual(#map.Doors:GetChildren(), 5, "5 portas")
	local zones = {}
	for _, zone in map.Zones:GetChildren() do
		zones[zone:GetAttribute("Zone")] = true
	end
	for _, zoneName in
		{ "Store", "Stockroom", "Office", "Bathroom", "Corridor", "Back", "Pumps", "Parking", "Road" }
	do
		expect(zones[zoneName], `zona {zoneName}`)
	end
	expect(map.Zones.Store:GetAttribute("SafeZone") == true, "loja é área segura")
	expect(countTagged(map, "ShiftLight") >= 15, "luzes controláveis")
	expect(countTagged(map, "EmergencyLight") >= 2, "luzes de emergência")
	expect(countTagged(map, "Product") >= 10, "produtos nas prateleiras")
	for _, interactionType in { "Phone", "SecurityMonitor", "LightSwitch", "Document", "Door" } do
		expect(countTagged(map, "Interactable", function(instance)
			return instance:GetAttribute("InteractionType") == interactionType
		end) >= 1, `interativo {interactionType}`)
	end
end)

test("Fase7/TESTE 1: todos os pontos de todas as tarefas existem no mapa", function(context)
	local session, map = buildMap()
	table.insert(context.sessions, session)
	local TaskDefinitions =
		session.Server:require(session.Server.game.ReplicatedStorage.Shared.Definitions.TaskDefinitions)
	local found = {}
	for _, descendant in map:GetDescendants() do
		if descendant:GetAttribute("InteractionType") == "Task" then
			found[`{descendant:GetAttribute("TaskId")}/{descendant:GetAttribute("Point")}`] = true
		end
	end
	for _, definition in TaskDefinitions.getForMap("GasStation") do
		for _, step in definition.Steps do
			expect(found[`{definition.Id}/{step.Point}`], `ponto {definition.Id}/{step.Point}`)
		end
	end
end)

test(
	"Fase7/TESTE 1: turno no posto real — spawn na loja, tarefas sorteadas, portas funcionam",
	function(context)
		local session = Session.new({
			patches = {
				["src/shared/Config/MatchConfig.luau"] = function(source)
					source = string.gsub(source, "BRIEFING_SECONDS = 10", "BRIEFING_SECONDS = 0.2")
					return (
						string.gsub(
							source,
							"REAL_SECONDS_PER_GAME_MINUTE = 15",
							"REAL_SECONDS_PER_GAME_MINUTE = 5"
						)
					)
				end,
			},
		})
		table.insert(context.sessions, session)
		Test.expectLog(session.Server, "servidor pronto")
		local client = session:addClient("Player1", 1001)
		Test.waitFor(function()
			return client.LocalPlayer:GetAttribute("Ready") == true
		end, 3, "pronto")
		local remote = function(name, ...)
			return session:clientRemote(client, name):InvokeServer(...)
		end
		remote("CreateParty", "GasStation")
		remote("SetReady", true)
		local _, started = remote("StartParty")
		expect(started.Success, "turno iniciado")
		Test.expectLog(session.Server, "5 tarefas sorteadas")

		local map = session.Server.workspace.Runtime.ActiveMap
		expect(map:GetAttribute("Generated") == true, "posto gerado por código")
		local root = client.ServerPlayer.Character.HumanoidRootPart
		local store = map.Zones.Store
		local offset = root.Position - store.Position
		expect(math.abs(offset.X) < 16 and math.abs(offset.Z) < 10, "jogador começa dentro da loja")

		-- Porta da frente: o jogador está perto dela.
		local frontDoor = map.Doors.FrontDoor
		root.Position = frontDoor.Position + Mock.Vector3.new(0, 0, -3)
		local prompt = frontDoor.InteractionPrompt
		prompt.PromptButtonHoldBegan:Fire(client.ServerPlayer)
		prompt.Triggered:Fire(client.ServerPlayer)
		task.wait(0.05)
		expect(frontDoor:GetAttribute("Open") == true, "porta da frente abre")
		Test.expectNoErrors(session.Server)
	end
)
