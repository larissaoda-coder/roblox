--!strict
-- Identidade visual: preto, branco, cinza e vermelho escuro só quando necessário.
-- Toda UI deve usar estes valores em vez de cores/fontes soltas no código.

local Theme = {
	Colors = {
		Background = Color3.fromRGB(8, 8, 10),
		Panel = Color3.fromRGB(18, 18, 22),
		PanelRaised = Color3.fromRGB(28, 28, 33),
		Border = Color3.fromRGB(60, 60, 66),
		Text = Color3.fromRGB(235, 235, 235),
		TextDim = Color3.fromRGB(150, 150, 156),
		TextOnLight = Color3.fromRGB(12, 12, 14),
		Danger = Color3.fromRGB(140, 18, 24),
		Success = Color3.fromRGB(170, 200, 170),
	},
	Fonts = {
		Body = Enum.Font.BuilderSans,
		Bold = Enum.Font.BuilderSansBold,
		Mono = Enum.Font.RobotoMono,
	},
	TextSizes = {
		Small = 14,
		Body = 18,
		Button = 18,
		Heading = 22,
		Title = 32,
	},
	Sizes = {
		ButtonHeight = 48,
		ButtonHeightTouch = 56, -- alvo de toque confortável no celular
		CornerRadius = 6,
		Padding = 16,
		Gap = 8,
		ModalMaxWidth = 720,
		ModalMaxHeight = 560,
	},
	-- UIScale = altura da tela / REFERENCE_HEIGHT, limitado entre MIN e MAX.
	Scale = {
		REFERENCE_HEIGHT = 720,
		MIN = 0.7,
		MAX = 1.25,
	},
	DisplayOrder = {
		HUD = 10,
		Menus = 20,
		Popups = 30,
		Debug = 100,
	},
}

return table.freeze(Theme)
