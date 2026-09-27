--!strict
-- Inventário: itens que o jogador possui, por categoria, com EQUIPAR.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ItemDefinitions = require(Shared.Definitions.ItemDefinitions)
local Strings = require(Shared.Definitions.Strings)

local PanelKit = require(script.Parent.PanelKit)

export type InventoryState = {
	Category: string,
	Inventory: { Owned: { [string]: boolean }, Equipped: { [string]: string } }?,
}

export type InventoryActions = {
	SelectCategory: (category: string) -> (),
	Equip: (itemId: string) -> (),
}

local InventoryPanel = {}

function InventoryPanel.render(content: Instance, state: InventoryState, actions: InventoryActions)
	local order = PanelKit.counter()
	PanelKit.tabs(
		content,
		(ItemDefinitions.CATEGORIES :: any) :: { string },
		"CATEGORY_",
		state.Category,
		order,
		actions.SelectCategory
	)
	local inventory = state.Inventory
	if not inventory then
		PanelKit.section(content, "…", order)
		return
	end
	for _, item in ItemDefinitions.getByCategory(state.Category :: ItemDefinitions.Category) do
		if inventory.Owned[item.Id] then
			local equipped = inventory.Equipped[item.Category] == item.Id
			PanelKit.row(content, `Owned_{item.Id}`, Strings.get(item.NameKey), nil, order, {
				Name = `Equip_{item.Id}`,
				Text = Strings.get(if equipped then "INVENTORY_EQUIPPED" else "INVENTORY_EQUIP"),
				Style = if equipped then "Secondary" else "Primary",
				Disabled = equipped,
				OnActivated = function()
					actions.Equip(item.Id)
				end,
			})
		end
	end
end

return InventoryPanel
