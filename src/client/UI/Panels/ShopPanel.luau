--!strict
-- Loja: abas por categoria + aba de NIGHT TOKENS (Robux). O servidor valida preço, nível e saldo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ItemDefinitions = require(Shared.Definitions.ItemDefinitions)
local ProductDefinitions = require(Shared.Definitions.ProductDefinitions)
local Strings = require(Shared.Definitions.Strings)

local PanelKit = require(script.Parent.PanelKit)

export type ShopState = {
	Category: string,
	Level: number,
	Cash: number,
	Tokens: number,
	Vip: boolean,
	Inventory: { Owned: { [string]: boolean }, Equipped: { [string]: string } }?,
}

export type ShopActions = {
	SelectCategory: (category: string) -> (),
	Buy: (itemId: string) -> (),
	BuyProduct: (productKey: string) -> (),
	BuyPass: (passKey: string) -> (),
}

local ShopPanel = {}

local function priceText(price: any): string
	return Strings.get(if price.Currency == "Cash" then "PRICE_CASH" else "PRICE_TOKENS", price.Amount)
end

function ShopPanel.render(content: Instance, state: ShopState, actions: ShopActions)
	local order = PanelKit.counter()
	local tabs: { string } = table.clone(ItemDefinitions.CATEGORIES :: any)
	table.insert(tabs, "TOKENS")
	PanelKit.tabs(content, tabs, "CATEGORY_", state.Category, order, actions.SelectCategory)
	PanelKit.section(content, Strings.get("SHOP_BALANCE", state.Cash, state.Tokens), order)

	if state.Category == "TOKENS" then
		for key, product in ProductDefinitions.DevProducts do
			local available = ProductDefinitions.numericId(product.Id) ~= nil
			PanelKit.row(content, `Product_{key}`, Strings.get(product.NameKey), nil, order, {
				Name = `BuyProduct_{key}`,
				Text = Strings.get(if available then "SHOP_BUY" else "COMING_SOON"),
				Disabled = not available,
				OnActivated = function()
					actions.BuyProduct(key)
				end,
			})
		end
		local vip = ProductDefinitions.GamePasses.VIP
		local vipAvailable = ProductDefinitions.numericId(vip.Id) ~= nil
		PanelKit.row(content, "Pass_VIP", Strings.get(vip.NameKey), Strings.get(vip.DescriptionKey), order, {
			Name = "BuyPass_VIP",
			Text = Strings.get(
				if state.Vip then "SHOP_OWNED" elseif vipAvailable then "SHOP_BUY" else "COMING_SOON"
			),
			Disabled = state.Vip or not vipAvailable,
			OnActivated = function()
				actions.BuyPass("VIP")
			end,
		})
		return
	end

	local owned = if state.Inventory then state.Inventory.Owned else {}
	for _, item in ItemDefinitions.getByCategory(state.Category :: ItemDefinitions.Category) do
		local isOwned = owned[item.Id] == true
		local price = item.Price
		local subtitle: string
		local buttonText: string
		local disabled = false
		if isOwned then
			subtitle = Strings.get("SHOP_OWNED")
			buttonText = Strings.get("SHOP_OWNED")
			disabled = true
		elseif item.VipOnly then
			subtitle = Strings.get("SHOP_VIP_ONLY")
			buttonText = "VIP"
			disabled = true
		elseif not price then
			subtitle = Strings.get("SHOP_NOT_FOR_SALE")
			buttonText = "—"
			disabled = true
		elseif state.Level < item.RequiredLevel then
			subtitle = priceText(price)
			buttonText = Strings.get("SHOP_LEVEL", item.RequiredLevel)
			disabled = true
		else
			subtitle = priceText(price)
			buttonText = Strings.get("SHOP_BUY")
		end
		PanelKit.row(content, `Item_{item.Id}`, Strings.get(item.NameKey), subtitle, order, {
			Name = `Buy_{item.Id}`,
			Text = buttonText,
			Disabled = disabled,
			OnActivated = function()
				actions.Buy(item.Id)
			end,
		})
	end
end

return ShopPanel
