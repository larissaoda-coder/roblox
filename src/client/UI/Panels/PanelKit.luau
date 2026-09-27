--!strict
-- Peças compartilhadas pelos painéis do lobby (abas, linhas com botão à direita, contador de ordem).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage.Shared.Definitions.Strings)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local PanelKit = {}

export type Order = () -> number

function PanelKit.counter(): Order
	local value = 0
	return function(): number
		value += 1
		return value
	end
end

function PanelKit.section(content: Instance, text: string, order: Order)
	Components.label({
		Text = text,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSizes.Small,
		Color = Theme.Colors.TextDim,
		LayoutOrder = order(),
	}).Parent =
		content
end

-- Linha de abas horizontais. `selected` é o id atual; onSelect(id) troca.
function PanelKit.tabs(
	content: Instance,
	ids: { string },
	labelKeyPrefix: string,
	selected: string,
	order: Order,
	onSelect: (string) -> ()
)
	local bar = Instance.new("ScrollingFrame")
	bar.Name = "Tabs"
	bar.BackgroundTransparency = 1
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, 0, 0, Components.getButtonHeight() + 8)
	bar.CanvasSize = UDim2.new()
	bar.AutomaticCanvasSize = Enum.AutomaticSize.X
	bar.ScrollingDirection = Enum.ScrollingDirection.X
	bar.ScrollBarThickness = 3
	bar.LayoutOrder = order()
	Components.list(bar, 6, Enum.FillDirection.Horizontal)
	for index, id in ids do
		local button = Components.button({
			Name = `Tab_{id}`,
			Text = Strings.get(`{labelKeyPrefix}{id}`),
			Style = if id == selected then "Primary" else "Secondary",
			Size = UDim2.new(0, 150, 0, Components.getButtonHeight()),
			LayoutOrder = index,
			OnActivated = function()
				onSelect(id)
			end,
		})
		button.Parent = bar
	end
	bar.Parent = content
end

-- Linha com título/subtítulo à esquerda e um botão à direita.
function PanelKit.row(
	content: Instance,
	name: string,
	title: string,
	subtitle: string?,
	order: Order,
	button: {
		Name: string,
		Text: string,
		Style: Components.ButtonStyle?,
		Disabled: boolean?,
		OnActivated: (() -> ())?,
	}?
): Frame
	local row = Components.row(name, order())
	row.Parent = content
	local titleLabel = Components.label({
		Name = "Title",
		Text = title,
		Font = Theme.Fonts.Bold,
		Size = UDim2.new(1, -152, 0, 22),
	})
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Parent = row
	if subtitle then
		local subtitleLabel = Components.label({
			Name = "Subtitle",
			Text = subtitle,
			TextSize = Theme.TextSizes.Small,
			Color = Theme.Colors.TextDim,
			Size = UDim2.new(1, -152, 0, 20),
		})
		subtitleLabel.Position = UDim2.new(0, 0, 0, 24)
		subtitleLabel.Parent = row
	end
	if button then
		local newButton = Components.button({
			Name = button.Name,
			Text = button.Text,
			Style = button.Style or "Primary",
			Disabled = button.Disabled,
			OnActivated = button.OnActivated,
		})
		newButton.AnchorPoint = Vector2.new(1, 0.5)
		newButton.Position = UDim2.new(1, 0, 0.5, 0)
		newButton.Size = UDim2.new(0, 140, 0, Components.getButtonHeight())
		newButton.Parent = row
	end
	return row
end

return PanelKit
