--!strict
-- GamePasses (VIP) e Developer Products (NIGHT TOKENS).
--
-- Segurança:
--   * Só o ProcessReceipt concede produtos pagos. Nenhum Remote dá tokens.
--   * Cada compra tem um PurchaseId salvo no perfil: a mesma compra NUNCA é entregue duas vezes.
--   * "PurchaseGranted" só é respondido depois de salvar; se salvar falhar, o Roblox tenta de novo.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProductDefinitions = require(Shared.Definitions.ProductDefinitions)
local Log = require(Shared.Modules.Log)

local DataService = require(script.Parent.DataService)
local EconomyService: any = require(script.Parent.EconomyService)
local PlayerService = require(script.Parent.PlayerService)

local log = Log.new("MonetizationService")

local MonetizationService = {}

function MonetizationService:IsVip(player: Player): boolean
	return player:GetAttribute("VIP") == true
end

-- Servidor privado: o dono pode ganhar pequenos benefícios no futuro (ex.: escolher o clima).
function MonetizationService:IsPrivateServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
end

local function checkGamePasses(player: Player)
	local vipId = ProductDefinitions.numericId(ProductDefinitions.GamePasses.VIP.Id)
	if not vipId then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, vipId)
	end)
	if ok and owns then
		player:SetAttribute("VIP", true)
	end
end

-- Chamado pelo Roblox para cada compra de Developer Product (inclusive compras antigas pendentes).
function MonetizationService.ProcessReceipt(receiptInfo): Enum.ProductPurchaseDecision
	local product = ProductDefinitions.findProductById(receiptInfo.ProductId)
	if not product then
		log:Warn("Produto desconhecido: %s", tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not DataService:IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- o Roblox tenta de novo quando o jogador voltar
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	local purchases = DataService:Get(player, "Purchases")
	if type(purchases) == "table" and purchases[purchaseId] ~= nil then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- já entregue antes
	end

	DataService:Update(player, "Purchases", function(current)
		current[purchaseId] = os.time()
		return current
	end)
	EconomyService:Grant(player, "NightTokens", product.NightTokens, `Purchase:{product.Key}`)

	if not DataService:SaveNow(player) then
		log:Warn(
			"Compra %s de %s entregue mas não salva ainda; o Roblox vai confirmar depois.",
			purchaseId,
			player.Name
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	log:Info("Compra %s: %s recebeu %d NIGHT TOKENS", purchaseId, player.Name, product.NightTokens)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService:Init()
	MarketplaceService.ProcessReceipt = MonetizationService.ProcessReceipt
end

function MonetizationService:Start()
	PlayerService.PlayerReady:Connect(checkGamePasses)
	for _, player in PlayerService:GetReadyPlayers() do
		task.spawn(checkGamePasses, player)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if purchased and passId == ProductDefinitions.numericId(ProductDefinitions.GamePasses.VIP.Id) then
				player:SetAttribute("VIP", true)
			end
		end
	)
	for key, product in ProductDefinitions.DevProducts do
		if not ProductDefinitions.numericId(product.Id) then
			log:Debug("Produto %s sem ID real (PRODUCT_ID_HERE). Ele fica indisponível na loja.", key)
		end
	end
end

return MonetizationService
