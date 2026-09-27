--!strict
-- Loja com moeda do jogo (CASH) e moeda premium (NIGHT TOKENS).
-- O preço vem SEMPRE das definições do servidor; o cliente só diz QUAL item quer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ItemDefinitions = require(Shared.Definitions.ItemDefinitions)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local EconomyService: any = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local PlayerService = require(script.Parent.PlayerService)
local ProgressionService = require(script.Parent.ProgressionService)

local log = Log.new("ShopService")

local ShopService = {}

function ShopService:Purchase(player: Player, itemId: string): (boolean, string?)
	if not PlayerService:IsReady(player) then
		return false, "NotReady"
	end
	local definition = ItemDefinitions.get(itemId)
	if not definition then
		return false, "ItemNotFound"
	end
	if InventoryService:Owns(player, itemId) then
		return false, "AlreadyOwned"
	end
	if definition.VipOnly then
		return false, "VipOnly"
	end
	local price = definition.Price
	if not price then
		return false, "NotForSale"
	end
	if ProgressionService:GetLevel(player) < definition.RequiredLevel then
		return false, "LevelTooLow"
	end
	if not EconomyService:Spend(player, price.Currency, price.Amount, `Shop:{itemId}`) then
		return false, "NotEnough"
	end
	InventoryService:Grant(player, itemId)
	log:Info("%s comprou %s por %d %s", player.Name, itemId, price.Amount, price.Currency)
	return true, nil
end

function ShopService:Init()
	Net.Server.handle("PurchaseItem", function(player: Player, itemId: string)
		local ok, err = ShopService:Purchase(player, itemId)
		return { Success = ok, Error = err, Inventory = InventoryService:GetSnapshot(player) }
	end)
end

return ShopService
