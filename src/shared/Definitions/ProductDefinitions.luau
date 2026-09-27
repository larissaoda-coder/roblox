--!strict
-- GamePasses e Developer Products. NÃO inventamos IDs: troque os textos "..._ID_HERE" pelos números
-- reais depois de criar os produtos em create.roblox.com > seu jogo > Monetization.
-- Enquanto o ID for texto, o produto aparece como indisponível e nada é vendido.

export type GamePass = { Key: string, Id: string | number, NameKey: string, DescriptionKey: string }
export type DevProduct = { Key: string, Id: string | number, NameKey: string, NightTokens: number }

local ProductDefinitions = {}

ProductDefinitions.GamePasses = {
	VIP = {
		Key = "VIP",
		Id = "GAMEPASS_ID_HERE",
		NameKey = "PASS_VIP",
		DescriptionKey = "PASS_VIP_DESC", -- título VIP, itens exclusivos, tag no chat
	},
	-- Planejados (estrutura pronta, sem benefício ativo ainda):
	SecondLoadout = {
		Key = "SecondLoadout",
		Id = "GAMEPASS_ID_HERE",
		NameKey = "PASS_LOADOUT",
		DescriptionKey = "PASS_LOADOUT_DESC",
	},
} :: { [string]: GamePass }

ProductDefinitions.DevProducts = {
	Tokens100 = {
		Key = "Tokens100",
		Id = "PRODUCT_ID_HERE",
		NameKey = "PRODUCT_TOKENS_100",
		NightTokens = 100,
	},
	Tokens550 = {
		Key = "Tokens550",
		Id = "PRODUCT_ID_HERE",
		NameKey = "PRODUCT_TOKENS_550",
		NightTokens = 550,
	},
	Tokens1200 = {
		Key = "Tokens1200",
		Id = "PRODUCT_ID_HERE",
		NameKey = "PRODUCT_TOKENS_1200",
		NightTokens = 1200,
	},
} :: { [string]: DevProduct }

-- ID numérico ou nil (se ainda for o texto de exemplo).
function ProductDefinitions.numericId(id: string | number): number?
	return if type(id) == "number" then id else tonumber(id)
end

function ProductDefinitions.findProductById(productId: number): DevProduct?
	for _, product in ProductDefinitions.DevProducts do
		if ProductDefinitions.numericId(product.Id) == productId then
			return product
		end
	end
	return nil
end

return ProductDefinitions
