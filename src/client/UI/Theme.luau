--!strict
-- Identidade visual: preto, branco, cinza e vermelho escuro só quando necessário.
-- Toda UI deve usar estes valores em vez de cores/fontes soltas no código.

local Theme = {
	Colors = {
		Background = Color3.fromRGB(8, 8, 10),
		Panel = Color3.fromRGB(18, 18, 22),
		Border = Color3.fromRGB(60, 60, 66),
		Text = Color3.fromRGB(235, 235, 235),
		TextDim = Color3.fromRGB(150, 150, 156),
		Danger = Color3.fromRGB(140, 18, 24),
	},
	Fonts = {
		Body = Enum.Font.BuilderSans,
		Bold = Enum.Font.BuilderSansBold,
		Mono = Enum.Font.RobotoMono,
	},
	TextSizes = {
		Small = 14,
		Body = 18,
		Title = 28,
	},
	DisplayOrder = {
		HUD = 10,
		Menus = 20,
		Popups = 30,
		Debug = 100,
	},
}

return table.freeze(Theme)
