--!nocheck
-- FASES 12 e 13: progressão, economia, recompensas, tela de resultados e DataStore.

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

local FAST_MATCH = function(source)
	source = string.gsub(source, "BRIEFING_SECONDS = 10", "BRIEFING_SECONDS = 0.1")
	source = string.gsub(source, "RESULTS_SECONDS = 10", "RESULTS_SECONDS = 0.5")
	source = string.gsub(source, "SHIFT_GAME_MINUTES = 60", "SHIFT_GAME_MINUTES = 6")
	return (string.gsub(source, "REAL_SECONDS_PER_GAME_MINUTE = 15", "REAL_SECONDS_PER_GAME_MINUTE = 0.25"))
end

local function newSession(context, options)
	options = options or {}
	options.patches = options.patches or {}
	options.patches["src/shared/Config/MatchConfig.luau"] = options.patches["src/shared/Config/MatchConfig.luau"]
		or FAST_MATCH
	local session = Session.new(options)
	table.insert(context.sessions, session)
	Test.expectLog(session.Server, "servidor pronto")
	service(session, "DirectorService"):SetEnabled(false)
	return session
end

local function join(session, name, userId)
	local client = session:addClient(name, userId)
	Test.waitFor(function()
		return client.LocalPlayer:GetAttribute("Ready") == true
			and client.LocalPlayer.PlayerGui:FindFirstChild("Results")
	end, 5, `{name} pronto`)
	return client
end

local function startShift(session, client)
	invoke(session, client, "CreateParty", "GasStation")
	invoke(session, client, "SetReady", true)
	invoke(session, client, "StartParty")
	Test.waitFor(function()
		return service(session, "MatchService"):GetPhase() == "Shift"
	end, 3, "turno")
end

-- Economia e progressão ---------------------------------------------------------------------------

test("Fase12/Unit: economia recusa valores inválidos e gasto sem saldo", function(context)
	local session = newSession(context)
	local client = join(session, "Player1", 1)
	local Economy = service(session, "EconomyService")
	local player = client.ServerPlayer
	expect(not Economy:Grant(player, "Cash", -10, "teste"), "negativo")
	expect(not Economy:Grant(player, "Cash", 0 / 0, "teste"), "NaN")
	expect(not Economy:Grant(player, "Cash", 1.5, "teste"), "fração")
	expect(not Economy:Grant(player, "Cash", 1e9, "teste"), "valor absurdo")
	expect(Economy:Grant(player, "Cash", 100, "teste"), "válido")
	expect(not Economy:Spend(player, "Cash", 150, "teste"), "sem saldo")
	expect(Economy:Spend(player, "Cash", 60, "teste"), "com saldo")
	expectEqual(Economy:GetBalance(player, "Cash"), 40, "saldo")
	expectEqual(
		service(session, "DataService"):Get(player, "Stats").CashEarned,
		100,
		"CashEarned conta só ganhos"
	)
end)

test("Fase12/Unit: XP sobe vários níveis e respeita o nível máximo", function(context)
	local session = newSession(context)
	local client = join(session, "Player1", 1)
	local Progression = service(session, "ProgressionService")
	local gained, level = Progression:AddXP(client.ServerPlayer, 100 + 150 + 10) -- nível 1→2 (100), 2→3 (150)
	expectEqual(gained, 2, "dois níveis")
	expectEqual(level, 3, "nível 3")
	expectEqual(service(session, "DataService"):Get(client.ServerPlayer, "XP"), 10, "sobra de XP")
	expectEqual(client.LocalPlayer:GetAttribute("Level"), 3, "nível no cliente")
	Progression:AddXP(client.ServerPlayer, 99999)
	Progression:AddXP(client.ServerPlayer, 99999)
	expect(Progression:GetLevel(client.ServerPlayer) <= 100, "limite de nível")
end)

-- Recompensas ---------------------------------------------------------------------------------------

test(
	"Fase12/TESTE 1: turno completo dá XP, CASH, bônus de sobrevivência e mostra a tela",
	function(context)
		local session = newSession(context)
		local client = join(session, "Player1", 1)
		startShift(session, client)
		local results = client:require(client.LocalPlayer.PlayerScripts.Client.Controllers.ResultsController)
		Test.waitFor(function()
			return results:GetLastResult() ~= nil
		end, 5, "resultado recebido")
		local result = results:GetLastResult()
		expect(result.Completed and result.Survived, "completo e vivo")
		local keys = {}
		for _, line in result.Lines do
			keys[line.Key] = line
		end
		expect(keys.RESULT_SHIFT and keys.RESULT_SURVIVAL, "linhas de turno e sobrevivência")
		expectEqual(result.TotalXP, 90, "XP (60 turno + 30 sobrevivência, sem tarefas)")
		expectEqual(client.LocalPlayer:GetAttribute("Cash"), result.TotalCash, "CASH creditado")
		local stats = service(session, "DataService"):Get(client.ServerPlayer, "Stats")
		expectEqual(stats.ShiftsCompleted, 1, "turnos concluídos")
		expectEqual(stats.ShiftsSurvived, 1, "turnos sobrevividos")

		local gui = client.LocalPlayer.PlayerGui.Results
		expect(gui.Enabled, "tela de resultados")
		Test.waitFor(function()
			return gui.Panel:FindFirstChild("ContinueButton") ~= nil
		end, 4, "linhas aparecendo até o botão continuar")
		expectEqual(gui.Panel.Title.Text, "TURNO CONCLUÍDO", "título")
		expectEqual(gui.Panel.Total.Text, "XP +90      CASH +70", "total")
		gui.Panel.ContinueButton.Activated:Fire()
		task.wait(0.05)
		expect(not gui.Enabled, "tela fechada")
	end
)

test("Fase12/TESTE 1: subir de nível aparece na tela", function(context)
	local session = newSession(context)
	local client = join(session, "Player1", 1)
	service(session, "ProgressionService"):AddXP(client.ServerPlayer, 50)
	startShift(session, client)
	local gui = client.LocalPlayer.PlayerGui.Results
	Test.waitFor(function()
		return gui.Panel:FindFirstChild("NewLevel") ~= nil
	end, 8, "novo nível")
	expectEqual(gui.Panel.NewLevel.Text, "NOVO NÍVEL! 2", "texto")
end)

test("Fase12/TESTE 1: turno fracassado paga menos e não conta como concluído", function(context)
	local session = newSession(context, {
		patches = {
			["src/shared/Config/MatchConfig.luau"] = function(source)
				source = FAST_MATCH(source)
				return (string.gsub(source, "SHIFT_GAME_MINUTES = 6", "SHIFT_GAME_MINUTES = 60"))
			end,
		},
	})
	local client = join(session, "Player1", 1)
	startShift(session, client)
	service(session, "SpectatorService"):Kill(client.ServerPlayer, "Teste")
	local results = client:require(client.LocalPlayer.PlayerScripts.Client.Controllers.ResultsController)
	Test.waitFor(function()
		return results:GetLastResult() ~= nil
	end, 3, "resultado")
	local result = results:GetLastResult()
	expect(not result.Completed and not result.Survived, "fracasso")
	expectEqual(result.TotalXP, 0, "sem XP de conclusão")
	expectEqual(
		service(session, "DataService"):Get(client.ServerPlayer, "Stats").ShiftsCompleted,
		0,
		"não conta"
	)
end)

test("Fase12/TESTE 3: recompensa não é paga duas vezes pela mesma partida", function(context)
	local session = newSession(context)
	local client = join(session, "Player1", 1)
	local MatchService = service(session, "MatchService")
	local captured
	MatchService.MatchEnded:Connect(function(match, result)
		captured = { match, result }
	end)
	startShift(session, client)
	Test.waitFor(function()
		return captured ~= nil
	end, 5, "fim")
	task.wait(0.2)
	local cash = client.LocalPlayer:GetAttribute("Cash")
	MatchService.MatchEnded:Fire(captured[1], captured[2]) -- repetição maliciosa/bug
	task.wait(0.2)
	expectEqual(client.LocalPlayer:GetAttribute("Cash"), cash, "saldo igual")
end)

-- DataStore ------------------------------------------------------------------------------------------

test("Fase13/TESTE 1: dados continuam depois de trocar de servidor (DataStore)", function(context)
	local shared = {}
	local first = newSession(context, { dataStores = shared, jobId = "ServerA" })
	Test.expectLog(first.Server, "Salvamento: DataStore")
	local client = join(first, "Player1", 777)
	service(first, "EconomyService"):Grant(client.ServerPlayer, "Cash", 250, "teste")
	first:removeClient(client)
	task.wait(0.2)

	local second = newSession(context, { dataStores = shared, jobId = "ServerB" })
	local again = join(second, "Player1", 777)
	expectEqual(again.LocalPlayer:GetAttribute("Cash"), 250, "CASH veio do DataStore")
end)

test("Fase13/TESTE 3: trava de sessão impede o mesmo jogador em dois servidores", function(context)
	local shared = {}
	local patches = {
		["src/server/Data/DataStoreBackend.luau"] = function(source)
			source = string.gsub(source, "LOCKED_RETRY_SECONDS = 6", "LOCKED_RETRY_SECONDS = 0.1")
			return (string.gsub(source, "LOCKED_MAX_WAITS = 5", "LOCKED_MAX_WAITS = 2"))
		end,
	}
	local first = newSession(context, { dataStores = shared, jobId = "ServerA", patches = patches })
	local client = join(first, "Player1", 888)
	service(first, "EconomyService"):Grant(client.ServerPlayer, "Cash", 10, "teste")
	service(first, "DataService"):SaveNow(client.ServerPlayer)

	local second = newSession(context, { dataStores = shared, jobId = "ServerB", patches = patches })
	local duplicate = second:addClient("Player1", 888)
	Test.waitFor(function()
		return duplicate.KickMessage ~= nil
	end, 3, "segundo servidor recusou (trava)")
	Test.expectLog(second.Server, "em uso em outro servidor")

	-- Saindo do primeiro servidor, a trava é liberada.
	first:removeClient(client)
	task.wait(0.2)
	local third = newSession(context, { dataStores = shared, jobId = "ServerC", patches = patches })
	local ok = join(third, "Player1", 888)
	expectEqual(ok.LocalPlayer:GetAttribute("Cash"), 10, "carregou depois de liberar")
end)

test("Fase13/TESTE 3: falhas temporárias do DataStore são repetidas", function(context)
	local shared = { NightShift_Players_v1 = { Data = {}, FailNext = 0 } }
	local session = newSession(context, {
		dataStores = shared,
		patches = {
			["src/server/Data/DataStoreBackend.luau"] = function(source)
				return (string.gsub(source, "task.wait%(2 %^ %(attempt %- 1%)%)", "task.wait(0.01)"))
			end,
		},
	})
	shared.NightShift_Players_v1.FailNext = 2
	local client = join(session, "Player1", 999)
	expect(client.LocalPlayer:GetAttribute("Ready") == true, "carregou após repetir")
	Test.expectLog(session.Server, "tentativa 1/4")
end)

test("Fase13/TESTE 3: sem acesso ao DataStore, o jogo usa memória e avisa", function(context)
	local session = newSession(context, { dataStoreUnavailable = true })
	Test.expectLog(session.Server, "Salvamento: Memory")
	Test.expectLog(session.Server, "Enable Studio Access to API Services")
end)
