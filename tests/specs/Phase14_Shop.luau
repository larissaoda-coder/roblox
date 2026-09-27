--!nocheck
-- FASES 14–16: inventário, loja, cosméticos, lanterna, monetização, conquistas e rankings.

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

local PRODUCT_PATCH = function(source)
	-- Troca os IDs de exemplo por números de teste (VIP = 5555, 100 tokens = 1001).
	source = string.gsub(source, 'Key = "VIP",(%s+)Id = "GAMEPASS_ID_HERE"', 'Key = "VIP",%1Id = 5555')
	return (
		string.gsub(source, 'Key = "Tokens100",(%s+)Id = "PRODUCT_ID_HERE"', 'Key = "Tokens100",%1Id = 1001')
	)
end

local function newSession(context, options)
	options = options or {}
	options.patches = options.patches or {}
	options.patches["src/shared/Definitions/ProductDefinitions.luau"] = PRODUCT_PATCH
	options.patches["src/shared/Config/MatchConfig.luau"] = function(source)
		source = string.gsub(source, "BRIEFING_SECONDS = 10", "BRIEFING_SECONDS = 0.1")
		source = string.gsub(source, "RESULTS_SECONDS = 10", "RESULTS_SECONDS = 0.3")
		source = string.gsub(source, "SHIFT_GAME_MINUTES = 60", "SHIFT_GAME_MINUTES = 4")
		return (
			string.gsub(source, "REAL_SECONDS_PER_GAME_MINUTE = 15", "REAL_SECONDS_PER_GAME_MINUTE = 0.2")
		)
	end
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
			and client.LocalPlayer.PlayerGui:FindFirstChild("LobbyUI")
	end, 5, "pronto")
	return client
end

local function find(client, name)
	for _, descendant in client.LocalPlayer.PlayerGui.LobbyUI:GetDescendants() do
		if descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function click(client, name)
	local button = Test.waitFor(function()
		return find(client, name)
	end, 2, name)
	button.Activated:Fire()
	task.wait(0.1)
end

test("Fase15/TESTE 1: comprar e equipar pela interface", function(context)
	local session = newSession(context)
	local client = join(session, "Player1", 1)
	service(session, "EconomyService"):Grant(client.ServerPlayer, "Cash", 400, "teste")
	click(client, "Menu_Shop")
	Test.waitFor(function()
		return find(client, "Buy_Flashlight_Cold") ~= nil
	end, 2, "lanternas na loja")
	expect(find(client, "Buy_Flashlight_Amber"):GetAttribute("Disabled") == true, "âmbar exige nível 5")
	click(client, "Buy_Flashlight_Cold")
	Test.waitFor(function()
		return service(session, "InventoryService"):Owns(client.ServerPlayer, "Flashlight_Cold")
	end, 2, "comprado")
	expectEqual(client.LocalPlayer:GetAttribute("Cash"), 100, "300 CASH descontados")
	Test.waitFor(function()
		return client.LocalPlayer.PlayerGui.Notifications.Message.Text == "Comprado!"
	end, 1, "aviso")

	click(client, "CloseButton")
	click(client, "Menu_Inventory")
	click(client, "Equip_Flashlight_Cold")
	local equipped = service(session, "InventoryService"):GetEquipped(client.ServerPlayer, "FLASHLIGHTS")
	expectEqual(equipped.Id, "Flashlight_Cold", "equipado")
end)

test("Fase15/TESTE 3: loja recusa compras inválidas", function(context)
	local session = newSession(context)
	local client = join(session, "Player1", 1)
	local function buy(itemId)
		local _, result = invoke(session, client, "PurchaseItem", itemId)
		task.wait(1.1) -- limite de 3 compras a cada 3 s
		return result.Error
	end
	expectEqual(buy("Flashlight_Cold"), "NotEnough", "sem dinheiro")
	service(session, "EconomyService"):Grant(client.ServerPlayer, "Cash", 5000, "teste")
	expectEqual(buy("Flashlight_Amber"), "LevelTooLow", "nível")
	expectEqual(buy("Title_Survivor"), "NotForSale", "prêmio de conquista")
	expectEqual(buy("Flashlight_VIP"), "VipOnly", "VIP")
	expectEqual(buy("Flashlight_Standard"), "AlreadyOwned", "padrão já é seu")
	expectEqual(buy("ItemInventado"), "ItemNotFound", "inexistente")
	local _, equip = invoke(session, client, "EquipItem", "Outfit_Crimson")
	expectEqual(equip.Error, "NotOwned", "não equipa o que não tem")
	expectEqual(client.LocalPlayer:GetAttribute("Cash"), 5000, "nada foi cobrado")
end)

test("Fase14/TESTE 1: cosméticos aparecem no personagem e lanterna usa a cor equipada", function(context)
	local session = newSession(context, { patches = {
		["src/shared/Config/MatchConfig.luau"] = nil,
	} })
	local client = join(session, "Player1", 1)
	local Inventory = service(session, "InventoryService")
	Inventory:Grant(client.ServerPlayer, "Cosmetic_Cap")
	Inventory:Equip(client.ServerPlayer, "Cosmetic_Cap")
	local character = client.ServerPlayer.Character
	Test.waitFor(function()
		return character:FindFirstChild("NS_Cap") and character.Head:FindFirstChild("NS_Title")
	end, 1, "boné e título")
	expectEqual(character.Head.NS_Title.TextLabel.Text, "NIGHT ROOKIE", "título padrão")
	expect(character:FindFirstChild("NS_Vest"), "colete")

	-- Lanterna só funciona no turno.
	session:clientRemote(client, "SetFlashlight"):FireServer(true)
	task.wait(0.05)
	expect(client.ServerPlayer:GetAttribute("FlashlightOn") ~= true, "no lobby não liga")
	invoke(session, client, "CreateParty", "GasStation")
	invoke(session, client, "SetReady", true)
	invoke(session, client, "StartParty")
	Test.waitFor(function()
		return service(session, "MatchService"):GetPhase() == "Shift"
	end, 3, "turno")
	Inventory:Grant(client.ServerPlayer, "Flashlight_Red")
	Inventory:Equip(client.ServerPlayer, "Flashlight_Red")
	session:clientRemote(client, "SetFlashlight"):FireServer(true)
	local light = Test.waitFor(function()
		return client.ServerPlayer.Character.Head:FindFirstChild("NS_Flashlight")
	end, 1, "lanterna criada")
	expect(light.Enabled, "acesa")
	expectEqual(light.Color.R, 1, "cor vermelha")
end)

test(
	"Fase16/TESTE 1: VIP (GamePass) libera itens VIP; compra de tokens é entregue uma vez só",
	function(context)
		local session = newSession(context, { ownedPasses = { ["7:5555"] = true } })
		local client = join(session, "Player1", 7)
		Test.waitFor(function()
			return client.LocalPlayer:GetAttribute("VIP") == true
		end, 2, "VIP detectado")
		expect(service(session, "InventoryService"):Owns(client.ServerPlayer, "Title_VIP"), "título VIP")

		local processReceipt = session.Server.Marketplace.ProcessReceipt
		expect(processReceipt, "ProcessReceipt registrado")
		local receipt = { ProductId = 1001, PlayerId = 7, PurchaseId = "PURCHASE-1" }
		expectEqual(processReceipt(receipt), Mock.Enum.ProductPurchaseDecision.PurchaseGranted, "entregue")
		expectEqual(client.LocalPlayer:GetAttribute("NightTokens"), 100, "100 tokens")
		expectEqual(
			processReceipt(receipt),
			Mock.Enum.ProductPurchaseDecision.PurchaseGranted,
			"repetido: confirma"
		)
		expectEqual(client.LocalPlayer:GetAttribute("NightTokens"), 100, "sem entregar de novo")
		local purchases = service(session, "DataService"):Get(client.ServerPlayer, "Purchases")
		expect(purchases["PURCHASE-1"], "compra registrada no perfil")
	end
)

test("Fase16/TESTE 3: recibo de jogador ausente ou produto desconhecido não é confirmado", function(context)
	local session = newSession(context)
	join(session, "Player1", 7)
	local processReceipt = session.Server.Marketplace.ProcessReceipt
	expectEqual(
		processReceipt({ ProductId = 1001, PlayerId = 999, PurchaseId = "X" }),
		Mock.Enum.ProductPurchaseDecision.NotProcessedYet,
		"jogador fora do servidor"
	)
	expectEqual(
		processReceipt({ ProductId = 424242, PlayerId = 7, PurchaseId = "Y" }),
		Mock.Enum.ProductPurchaseDecision.NotProcessedYet,
		"produto desconhecido"
	)
end)

test("Fase16/TESTE 1: conquistas ao concluir o turno (com prêmio) e ranking", function(context)
	local session = newSession(context)
	local client = join(session, "Player1", 7)
	invoke(session, client, "CreateParty", "GasStation")
	invoke(session, client, "SetReady", true)
	invoke(session, client, "StartParty")
	local Achievements = service(session, "AchievementService")
	Test.waitFor(function()
		return Achievements:Has(client.ServerPlayer, "FirstShift")
			and Achievements:Has(client.ServerPlayer, "Survivor")
	end, 6, "conquistas")
	expect(
		service(session, "InventoryService"):Owns(client.ServerPlayer, "Title_Survivor"),
		"título de prêmio"
	)

	local Leaderboard = service(session, "LeaderboardService")
	Leaderboard:Refresh()
	local entries = Leaderboard:Get("ShiftsCompleted")
	expectEqual(entries[1].UserId, 7, "no ranking")
	expectEqual(entries[1].Value, 1, "1 turno")
	local _, invalid = invoke(session, client, "GetLeaderboard", "Hackeado")
	expectEqual(#invalid, 0, "ranking inexistente")
end)

test("Fase17/TESTE 1: configurações pela interface são salvas no servidor", function(context)
	local session = newSession(context)
	local client = join(session, "Player1", 1)
	click(client, "Menu_Settings")
	click(client, "Toggle_Subtitles")
	Test.waitFor(function()
		local saved = service(session, "DataService"):Get(client.ServerPlayer, "Settings")
		return saved.Subtitles == false
	end, 2, "legendas desligadas e salvas")
	click(client, "Decrease_MasterVolume")
	Test.waitFor(function()
		return service(session, "DataService"):Get(client.ServerPlayer, "Settings").MasterVolume == 0.9
	end, 2, "volume 90%")
end)
