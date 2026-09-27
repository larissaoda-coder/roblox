--!strict
-- Itens cosméticos (sem vantagem de jogo). Categorias: COSMETICS, EMOTES, FLASHLIGHTS, OUTFITS, TITLES, EFFECTS.
-- Um item por categoria pode estar equipado.
--
-- Price = nil → não está à venda (padrão, prêmio de conquista ou VIP).
-- Emotes precisam de uma animação sua: troque "ANIMATION_ID_HERE" por "rbxassetid://NUMERO".

export type Category = "COSMETICS" | "EMOTES" | "FLASHLIGHTS" | "OUTFITS" | "TITLES" | "EFFECTS"

export type ItemDefinition = {
	Id: string,
	Category: Category,
	NameKey: string,
	Price: { Currency: "Cash" | "NightTokens", Amount: number }?,
	RequiredLevel: number,
	VipOnly: boolean,
	Default: boolean,
	Data: { [string]: any },
}

local CATEGORIES: { Category } = { "FLASHLIGHTS", "OUTFITS", "TITLES", "COSMETICS", "EFFECTS", "EMOTES" }

local function item(data: { [string]: any }): ItemDefinition
	return {
		Id = data.Id,
		Category = data.Category,
		NameKey = data.NameKey or `ITEM_{data.Id}`,
		Price = data.Price,
		RequiredLevel = data.RequiredLevel or 1,
		VipOnly = data.VipOnly == true,
		Default = data.Default == true,
		Data = data.Data or {},
	}
end

local function cash(amount: number)
	return { Currency = "Cash", Amount = amount }
end

local function tokens(amount: number)
	return { Currency = "NightTokens", Amount = amount }
end

local ITEMS: { ItemDefinition } = {
	-- Lanternas (só a cor muda; alcance e brilho são iguais para todos)
	item({
		Id = "Flashlight_Standard",
		Category = "FLASHLIGHTS",
		Default = true,
		Data = { Color = Color3.fromRGB(255, 244, 220) },
	}),
	item({
		Id = "Flashlight_Cold",
		Category = "FLASHLIGHTS",
		Price = cash(300),
		Data = { Color = Color3.fromRGB(190, 220, 255) },
	}),
	item({
		Id = "Flashlight_Amber",
		Category = "FLASHLIGHTS",
		Price = cash(500),
		RequiredLevel = 5,
		Data = { Color = Color3.fromRGB(255, 190, 110) },
	}),
	item({
		Id = "Flashlight_Red",
		Category = "FLASHLIGHTS",
		Price = tokens(80),
		Data = { Color = Color3.fromRGB(255, 90, 80) },
	}),
	item({
		Id = "Flashlight_VIP",
		Category = "FLASHLIGHTS",
		VipOnly = true,
		Data = { Color = Color3.fromRGB(190, 150, 255) },
	}),

	-- Uniformes (colete de trabalho)
	item({
		Id = "Outfit_Standard",
		Category = "OUTFITS",
		Default = true,
		Data = { Color = Color3.fromRGB(70, 80, 96) },
	}),
	item({
		Id = "Outfit_HighVis",
		Category = "OUTFITS",
		Price = cash(350),
		Data = { Color = Color3.fromRGB(220, 210, 40) },
	}),
	item({
		Id = "Outfit_Crimson",
		Category = "OUTFITS",
		Price = cash(900),
		RequiredLevel = 8,
		Data = { Color = Color3.fromRGB(120, 20, 26) },
	}),
	item({
		Id = "Outfit_Black",
		Category = "OUTFITS",
		Price = tokens(120),
		Data = { Color = Color3.fromRGB(18, 18, 20) },
	}),

	-- Títulos (aparecem acima da cabeça)
	item({ Id = "Title_Rookie", Category = "TITLES", Default = true, Data = { Text = "NIGHT ROOKIE" } }),
	item({
		Id = "Title_Regular",
		Category = "TITLES",
		Price = cash(400),
		RequiredLevel = 3,
		Data = { Text = "REGULAR" },
	}),
	item({
		Id = "Title_NightOwl",
		Category = "TITLES",
		Price = cash(800),
		RequiredLevel = 10,
		Data = { Text = "NIGHT OWL" },
	}),
	item({
		Id = "Title_Graveyard",
		Category = "TITLES",
		Price = tokens(150),
		Data = { Text = "GRAVEYARD SHIFT" },
	}),
	item({ Id = "Title_Survivor", Category = "TITLES", Data = { Text = "SURVIVOR" } }), -- prêmio de conquista
	item({ Id = "Title_DontAnswer", Category = "TITLES", Data = { Text = "DON'T ANSWER" } }), -- prêmio secreto
	item({ Id = "Title_VIP", Category = "TITLES", VipOnly = true, Data = { Text = "VIP" } }),

	-- Acessórios
	item({ Id = "Cosmetic_None", Category = "COSMETICS", Default = true, Data = {} }),
	item({
		Id = "Cosmetic_Cap",
		Category = "COSMETICS",
		Price = cash(250),
		Data = { Color = Color3.fromRGB(140, 18, 24) },
	}),
	item({
		Id = "Cosmetic_GreyCap",
		Category = "COSMETICS",
		Price = cash(250),
		Data = { Color = Color3.fromRGB(90, 90, 96) },
	}),

	-- Efeitos de entrada (no começo do turno)
	item({ Id = "Effect_None", Category = "EFFECTS", Default = true, Data = {} }),
	item({
		Id = "Effect_Fog",
		Category = "EFFECTS",
		Price = cash(600),
		Data = { Color = Color3.fromRGB(200, 200, 210) },
	}),
	item({
		Id = "Effect_Static",
		Category = "EFFECTS",
		Price = tokens(100),
		Data = { Color = Color3.fromRGB(240, 240, 240) },
	}),
	item({
		Id = "Effect_Embers",
		Category = "EFFECTS",
		VipOnly = true,
		Data = { Color = Color3.fromRGB(255, 120, 60) },
	}),

	-- Emotes (precisam de AnimationId)
	item({
		Id = "Emote_Wave",
		Category = "EMOTES",
		Price = cash(200),
		Data = { AnimationId = "ANIMATION_ID_HERE" },
	}),
	item({
		Id = "Emote_Shrug",
		Category = "EMOTES",
		Price = tokens(60),
		Data = { AnimationId = "ANIMATION_ID_HERE" },
	}),
}

local byId: { [string]: ItemDefinition } = {}
local defaults: { [Category]: ItemDefinition } = {}
for _, definition in ITEMS do
	assert(byId[definition.Id] == nil, `[ItemDefinitions] Id repetido: {definition.Id}`)
	byId[definition.Id] = definition
	if definition.Default then
		defaults[definition.Category] = definition
	end
end

local ItemDefinitions = {}

ItemDefinitions.CATEGORIES = CATEGORIES

function ItemDefinitions.get(itemId: string): ItemDefinition?
	return byId[itemId]
end

function ItemDefinitions.getAll(): { ItemDefinition }
	return table.clone(ITEMS)
end

function ItemDefinitions.getByCategory(category: Category): { ItemDefinition }
	local list = {}
	for _, definition in ITEMS do
		if definition.Category == category then
			table.insert(list, definition)
		end
	end
	return list
end

function ItemDefinitions.getDefault(category: Category): ItemDefinition?
	return defaults[category]
end

return ItemDefinitions
