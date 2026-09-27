--!nocheck
-- FASE 1: arquitetura base. Espelha os TESTES 1, 2 e 3 do guia da Fase 1.

local task = require("@lune/task")

local Mock = require("../harness/Mock")
local Session = require("../harness/Session")
local Test = require("../harness/Test")
local World = require("../harness/World")

local test, expect, expectEqual = Test.test, Test.expect, Test.expectEqual

local GAME_CONFIG = "src/shared/Config/GameConfig.luau"
local ADMIN_CONFIG = "src/server/ServerDefinitions/AdminConfig.luau"

local function replace(from, to)
	return function(source)
		local result, count = string.gsub(source, from, to)
		assert(count > 0, `patch não encontrou "{from}"`)
		return result
	end
end

local function newSession(context, options)
	local session = Session.new(options)
	table.insert(context.sessions, session)
	return session
end

-- Mundo isolado para testar módulos sozinhos.
local function sharedModule(path)
	local world = World.new("Server", "Unit", {})
	local shared = world:build("src/shared", "Shared")
	shared.Parent = world.game.ReplicatedStorage
	local target = shared
	for _, part in string.split(path, "/") do
		target = target[part]
	end
	return world:require(target), world
end

local function overlayOf(client)
	return client.LocalPlayer.PlayerGui:FindFirstChild("DebugOverlay")
end

-- Unidades ---------------------------------------------------------------------------

test("Fase1/Unit: validadores T rejeitam valores inválidos", function()
	local T = sharedModule("Modules/Net/T")
	expect(T.string(5)("abc"), "string curta")
	expect(not T.string(5)("abcdef"), "string longa")
	expect(not T.string()(42), "número como string")
	expect(T.number(0, 10)(5), "número no intervalo")
	expect(not T.number()(0 / 0), "NaN")
	expect(not T.number()(math.huge), "infinito")
	expect(not T.number(0, 10)(11), "acima do máximo")
	expect(T.integer()(3), "inteiro")
	expect(not T.integer()(1.5), "decimal como inteiro")
	expect(T.boolean()(false), "boolean")
	expect(not T.boolean()("true"), "string como boolean")
	expect(T.oneOf({ "A", "B" })("A"), "oneOf válido")
	expect(not T.oneOf({ "A", "B" })("C"), "oneOf inválido")
	expect(T.optional(T.string())(nil), "optional nil")
	expect(not T.optional(T.string())(1), "optional inválido")
	local folder = Mock.newInstance("Folder")
	expect(T.instance("Folder")(folder), "instance correta")
	expect(not T.instance("Part")(folder), "instance de classe errada")
	expect(not T.instance()({}), "tabela como instance")
end)

test("Fase1/Unit: RateLimiter bloqueia rajadas e recarrega com o tempo", function()
	local RateLimiter = sharedModule("Modules/RateLimiter")
	local limiter = RateLimiter.new(3, 1)
	local player = {}
	expect(limiter:Check(player) and limiter:Check(player) and limiter:Check(player), "3 primeiras chamadas")
	expect(not limiter:Check(player), "4ª chamada deve ser bloqueada")
	expect(limiter:Check({}), "outro jogador tem seu próprio limite")
	task.wait(0.4)
	expect(limiter:Check(player), "recarregou após 0.4s")
	limiter:Reset(player)
	expect(limiter:Check(player) and limiter:Check(player), "reset restaura o limite")
end)

test("Fase1/Unit: Strings escolhe idioma e formata", function()
	local Strings = sharedModule("Definitions/Strings")
	Strings.setLocale("pt-br")
	expectEqual(Strings.getLanguage(), "pt", "idioma pt-br")
	Strings.setLocale("fr-fr")
	expectEqual(Strings.getLanguage(), "en", "idioma sem tradução cai para en")
	expectEqual(Strings.get("CHAVE_INEXISTENTE"), "CHAVE_INEXISTENTE", "chave inexistente")
	Strings.setLocale("en-us")
	expectEqual(
		Strings.get("DEBUG_OVERLAY", "1.0", 10, 60, "Touch", 2, 50),
		"DEBUG · v1.0 · 10 ms · 60 FPS · Touch · LVL 2 · $50",
		"formatação"
	)
	expectEqual(
		Strings.getForLocale("pt-br", "DEBUG_OVERLAY", "1.0", 1, 2, "Gamepad", 3, 4),
		"DEBUG · v1.0 · 1 ms · 2 FPS · Gamepad · NÍV 3 · $4",
		"getForLocale"
	)
end)

test("Fase1/Unit: Signal conecta, desconecta, Once e Wait", function()
	local Signal = sharedModule("Modules/Signal")
	local signal = Signal.new()
	local received = {}
	local connection = signal:Connect(function(value)
		table.insert(received, value)
	end)
	signal:Once(function(value)
		table.insert(received, "once:" .. value)
	end)
	signal:Fire("a")
	connection:Disconnect()
	signal:Fire("b")
	expectEqual(table.concat(received, ","), "a,once:a", "eventos recebidos")
	task.delay(0.05, function()
		signal:Fire("waited")
	end)
	expectEqual(signal:Wait(), "waited", "Wait")
end)

test("Fase1/Unit: Trove limpa tudo na ordem inversa", function()
	local Trove, world = sharedModule("Modules/Trove")
	local trove = Trove.new()
	local order = {}
	local part = world.newInstance("Part")
	part.Parent = world.workspace
	local signal = Mock.newSignal()
	local connection = trove:Connect(signal, function() end)
	trove:Add(part)
	trove:Add(function()
		table.insert(order, "fn")
	end)
	trove:Clean()
	expectEqual(order[1], "fn", "função chamada")
	expect(part.Parent == nil, "instância destruída")
	expect(not connection.Connected, "conexão desconectada")
end)

test("Fase1/Unit: InstanceUtil.waitForChild dá erro claro no timeout", function()
	local InstanceUtil, world = sharedModule("Modules/InstanceUtil")
	local ok, err = pcall(InstanceUtil.waitForChild, world.workspace, "NaoExiste", 0.1)
	expect(not ok, "deveria falhar")
	expect(string.find(err, "Objeto não encontrado: Workspace.NaoExiste", 1, true), `mensagem: {err}`)
	local folder = InstanceUtil.getOrCreate(world.workspace, "Folder", "Runtime")
	expect(
		InstanceUtil.getOrCreate(world.workspace, "Folder", "Runtime") == folder,
		"getOrCreate reaproveita"
	)
end)

-- TESTE 1 ----------------------------------------------------------------------------

test("Fase1/TESTE 1: servidor e cliente iniciam e o painel de debug aparece", function(context)
	local session = newSession(context)
	local server = session.Server
	Test.expectLog(server, "servidor pronto %(%d+ serviços, modo Local%)")
	expect(server.workspace:FindFirstChild("Runtime"), "Workspace.Runtime criado")
	local remotes = server.game.ReplicatedStorage.Shared:FindFirstChild("Remotes")
	expect(remotes and remotes:FindFirstChild("Ping"), "Remote Ping")
	expect(remotes:FindFirstChild("RequestDebugAccess"), "Remote RequestDebugAccess")

	local client = session:addClient("Player1", 1001)
	Test.expectLog(client, "cliente pronto %(%d+ controllers, idioma pt%)")
	Test.expectLog(client, "Painel de debug ativo")
	local overlay = Test.waitFor(function()
		return overlayOf(client)
	end, 3, "DebugOverlay")
	local label = overlay.Stats
	Test.waitFor(function()
		return string.match(label.Text, "^DEBUG · v%d+%.%d+%.%d+ · %d+ ms · %d+ FPS · ")
	end, 3, "texto do painel atualizado")
	local fps = tonumber(string.match(label.Text, "(%d+) FPS"))
	expect(fps and fps > 20, `FPS plausível ({label.Text})`)
	Test.expectNoErrors(server)
	Test.expectNoErrors(client)
end)

test("Fase1/TESTE 1: F3 esconde e mostra o painel", function(context)
	local session = newSession(context)
	local client = session:addClient("Player1", 1001)
	local overlay = Test.waitFor(function()
		return overlayOf(client)
	end, 3, "DebugOverlay")
	local input = { KeyCode = Mock.Enum.KeyCode.F3 }
	client.UserInputService.InputBegan:Fire(input, false)
	expect(overlay.Enabled == false, "F3 esconde")
	client.UserInputService.InputBegan:Fire(input, true)
	expect(overlay.Enabled == false, "F3 digitado no chat é ignorado")
	client.UserInputService.InputBegan:Fire(input, false)
	expect(overlay.Enabled == true, "F3 mostra de novo")
end)

-- TESTE 2 ----------------------------------------------------------------------------

test("Fase1/TESTE 2: dois jogadores recebem o painel", function(context)
	local session = newSession(context)
	local first = session:addClient("Player1", -1)
	local second = session:addClient("Player2", -2)
	for _, client in { first, second } do
		Test.waitFor(function()
			return overlayOf(client)
		end, 3, `DebugOverlay de {client.Name}`)
	end
	Test.expectLog(session.Server, "Acesso de debug para Player1: true")
	Test.expectLog(session.Server, "Acesso de debug para Player2: true")
	Test.expectNoErrors(session.Server)
end)

-- TESTE 3 ----------------------------------------------------------------------------

test("Fase1/TESTE 3A: argumento falso ('999999 CASH') é rejeitado", function(context)
	local session = newSession(context)
	local client = session:addClient("Player1", 1001)
	local ping = Test.waitFor(function()
		return session:clientRemote(client, "Ping")
	end, 3, "Remote Ping no cliente")
	local ok, reason = ping:InvokeServer("999999 CASH")
	expectEqual(ok, false, "resposta")
	expectEqual(reason, "TooManyArgs", "motivo")
	Test.expectLog(session.Server, "Rejeitado Ping de Player1: TooManyArgs")
end)

test("Fase1/TESTE 3B: spam de chamadas é limitado", function(context)
	local session = newSession(context)
	local client = session:addClient("Player1", 1001)
	local ping = Test.waitFor(function()
		return session:clientRemote(client, "Ping")
	end, 3, "Remote Ping no cliente")
	local accepted, limited = 0, 0
	for _ = 1, 6 do
		local ok, result = ping:InvokeServer()
		if ok then
			accepted += 1
			expect(type(result) == "number", "Ping devolve o horário do servidor")
		elseif result == "RateLimited" then
			limited += 1
		end
	end
	expect(accepted >= 1 and accepted <= 2, `aceitas: {accepted}`)
	expectEqual(limited, 6 - accepted, "bloqueadas")
	Test.expectLog(session.Server, "Rejeitado Ping de Player1: RateLimited")
end)

test("Fase1/TESTE 3: violações disparam o sinal Net.Server.Violation", function(context)
	local session = newSession(context)
	local server = session.Server
	Test.expectLog(server, "servidor pronto")
	local Net = server:require(server.game.ReplicatedStorage.Shared.Modules.Net)
	local violations = {}
	Net.Server.Violation:Connect(function(player, remoteName, reason)
		table.insert(violations, `{player.Name}:{remoteName}:{reason}`)
	end)
	local client = session:addClient("Player1", 1001)
	local ping = Test.waitFor(function()
		return session:clientRemote(client, "Ping")
	end, 3, "Remote no cliente")
	ping:InvokeServer({ Granted = true })
	Test.waitFor(function()
		return table.find(violations, "Player1:Ping:TooManyArgs")
	end, 2, "violação registrada")
end)

test("Fase1/TESTE 3C: DEBUG_MODE = false esconde o painel e os logs de debug", function(context)
	local session = newSession(context, {
		patches = { [GAME_CONFIG] = replace("DEBUG_MODE = true", "DEBUG_MODE = false") },
	})
	local client = session:addClient("Player1", 1001)
	Test.expectLog(client, "cliente pronto")
	task.wait(0.5)
	expect(overlayOf(client) == nil, "painel não deveria existir")
	expect(Test.findLog(session.Server, "Acesso de debug") == nil, "log de debug não deveria aparecer")
end)

test("Fase1/TESTE 3D: sem admin no Studio, só quem está em ADMIN_USER_IDS vê o painel", function(context)
	local session = newSession(context, {
		patches = {
			[ADMIN_CONFIG] = function(source)
				source =
					replace("STUDIO_PLAYERS_ARE_ADMINS = true", "STUDIO_PLAYERS_ARE_ADMINS = false")(source)
				return replace("ADMIN_USER_IDS = {", "ADMIN_USER_IDS = { 123456,")(source)
			end,
		},
	})
	local admin = session:addClient("Admin", 123456)
	local visitor = session:addClient("Visitor", 999)
	Test.waitFor(function()
		return overlayOf(admin)
	end, 3, "painel do admin")
	Test.expectLog(session.Server, "Acesso de debug para Visitor: false")
	task.wait(0.3)
	expect(overlayOf(visitor) == nil, "visitante não deveria ver o painel")
end)

test("Fase1/TESTE 3: jogo publicado (fora do Studio) não dá admin a ninguém por padrão", function(context)
	local session = newSession(context, { studio = false })
	local client = session:addClient("Player1", 1001)
	Test.expectLog(session.Server, "Acesso de debug para Player1: false")
	task.wait(0.3)
	expect(overlayOf(client) == nil, "painel não deveria existir")
end)
