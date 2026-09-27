--!strict
-- O que cada jogador possui e tem equipado. Itens padrão e itens VIP (para quem tem o VIP)
-- contam como possuídos sem precisar comprar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ItemDefinitions = require(Shared.Definitions.ItemDefinitions)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local DataService = require(script.Parent.DataService)

local log = Log.new("InventoryService")

local InventoryService: any = {}

-- (player, category, itemId)
InventoryService.Equipped = Signal.new()

function InventoryService:IsVip(player: Player): boolean
	return player:GetAttribute("VIP") == true
end

function InventoryService:Owns(player: Player, itemId: string): boolean
	local definition = ItemDefinitions.get(itemId)
	if not definition then
		return false
	end
	if definition.Default or (definition.VipOnly and self:IsVip(player)) then
		return true
	end
	local inventory = DataService:Get(player, "Inventory")
	return type(inventory) == "table" and inventory.Owned[itemId] == true
end

-- Dá um item ao jogador (compra, conquista, evento). Retorna false se já tinha.
function InventoryService:Grant(player: Player, itemId: string): boolean
	if not ItemDefinitions.get(itemId) or self:Owns(player, itemId) then
		return false
	end
	local ok = DataService:Update(player, "Inventory", function(inventory)
		inventory.Owned[itemId] = true
		return inventory
	end)
	if ok then
		log:Debug("%s ganhou %s", player.Name, itemId)
	end
	return ok
end

function InventoryService:GetEquipped(
	player: Player,
	category: ItemDefinitions.Category
): ItemDefinitions.ItemDefinition?
	local inventory = DataService:Get(player, "Inventory")
	local itemId = type(inventory) == "table" and inventory.Equipped[category] or nil
	if itemId and self:Owns(player, itemId) then
		return ItemDefinitions.get(itemId)
	end
	return ItemDefinitions.getDefault(category)
end

function InventoryService:Equip(player: Player, itemId: string): (boolean, string?)
	local definition = ItemDefinitions.get(itemId)
	if not definition then
		return false, "ItemNotFound"
	end
	if not self:Owns(player, itemId) then
		return false, "NotOwned"
	end
	local ok = DataService:Update(player, "Inventory", function(inventory)
		inventory.Equipped[definition.Category] = itemId
		return inventory
	end)
	if ok then
		InventoryService.Equipped:Fire(player, definition.Category, itemId)
	end
	return ok, nil
end

-- Resumo para a interface: o que possui e o que está equipado em cada categoria.
function InventoryService:GetSnapshot(player: Player)
	local owned = {}
	local equipped = {}
	for _, definition in ItemDefinitions.getAll() do
		if self:Owns(player, definition.Id) then
			owned[definition.Id] = true
		end
	end
	for _, category in ItemDefinitions.CATEGORIES do
		local current = self:GetEquipped(player, category)
		equipped[category] = if current then current.Id else nil
	end
	return { Owned = owned, Equipped = equipped }
end

function InventoryService:Init()
	Net.Server.handle("GetInventory", function(player: Player)
		return InventoryService:GetSnapshot(player)
	end)
	Net.Server.handle("EquipItem", function(player: Player, itemId: string)
		local ok, err = InventoryService:Equip(player, itemId)
		return { Success = ok, Error = err, Inventory = InventoryService:GetSnapshot(player) }
	end)
end

return InventoryService
