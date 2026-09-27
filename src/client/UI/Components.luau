--!strict
-- Peças de interface reutilizáveis. Todas as telas devem montar a UI com estas funções,
-- para manter o mesmo visual e o mesmo tamanho de toque em todo o jogo.

local Theme = require(script.Parent.Theme)

export type ButtonStyle = "Primary" | "Secondary" | "Danger"

export type ButtonProps = {
	Name: string,
	Text: string,
	Style: ButtonStyle?,
	LayoutOrder: number?,
	Size: UDim2?,
	Disabled: boolean?,
	OnActivated: (() -> ())?,
}

export type LabelProps = {
	Name: string?,
	Text: string,
	TextSize: number?,
	Font: Enum.Font?,
	Color: Color3?,
	LayoutOrder: number?,
	Size: UDim2?,
	AlignX: Enum.TextXAlignment?,
}

local Components = {}

-- Altura atual dos botões (maior no celular). Atualizada pelo UIController/telas.
local buttonHeight = Theme.Sizes.ButtonHeight

function Components.setTouchMode(isTouch: boolean)
	buttonHeight = if isTouch then Theme.Sizes.ButtonHeightTouch else Theme.Sizes.ButtonHeight
end

function Components.getButtonHeight(): number
	return buttonHeight
end

function Components.corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.Sizes.CornerRadius)
	corner.Parent = parent
end

function Components.stroke(parent: Instance, color: Color3?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Colors.Border
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

function Components.padding(parent: Instance, pixels: number?)
	local value = UDim.new(0, pixels or Theme.Sizes.Padding)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = value
	padding.PaddingRight = value
	padding.PaddingTop = value
	padding.PaddingBottom = value
	padding.Parent = parent
end

function Components.list(parent: Instance, gap: number?, direction: Enum.FillDirection?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction or Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap or Theme.Sizes.Gap)
	layout.Parent = parent
	return layout
end

local function applyButtonStyle(button: TextButton, style: ButtonStyle, disabled: boolean)
	if style == "Primary" then
		button.BackgroundColor3 = Theme.Colors.Text
		button.TextColor3 = Theme.Colors.TextOnLight
	elseif style == "Danger" then
		button.BackgroundColor3 = Theme.Colors.Danger
		button.TextColor3 = Theme.Colors.Text
	else
		button.BackgroundColor3 = Theme.Colors.PanelRaised
		button.TextColor3 = Theme.Colors.Text
	end
	button.BackgroundTransparency = if disabled then 0.6 else 0
	button.TextTransparency = if disabled then 0.5 else 0
	button.AutoButtonColor = not disabled
end

function Components.button(props: ButtonProps): TextButton
	local style: ButtonStyle = props.Style or "Secondary"
	local button = Instance.new("TextButton")
	button.Name = props.Name
	button.Text = props.Text
	button.Font = Theme.Fonts.Bold
	button.TextSize = Theme.TextSizes.Button
	button.Size = props.Size or UDim2.new(1, 0, 0, buttonHeight)
	button.LayoutOrder = props.LayoutOrder or 0
	button.BorderSizePixel = 0
	button:SetAttribute("Style", style)
	Components.corner(button)
	if style == "Secondary" then
		Components.stroke(button)
	end
	Components.setDisabled(button, props.Disabled == true)

	local onActivated = props.OnActivated
	if onActivated then
		button.Activated:Connect(function()
			if button:GetAttribute("Disabled") ~= true then
				onActivated()
			end
		end)
	end
	return button
end

function Components.setDisabled(button: TextButton, disabled: boolean)
	button:SetAttribute("Disabled", disabled)
	button.Selectable = not disabled
	applyButtonStyle(button, (button:GetAttribute("Style") or "Secondary") :: ButtonStyle, disabled)
end

function Components.label(props: LabelProps): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "Label"
	label.Text = props.Text
	label.BackgroundTransparency = 1
	label.Font = props.Font or Theme.Fonts.Body
	label.TextSize = props.TextSize or Theme.TextSizes.Body
	label.TextColor3 = props.Color or Theme.Colors.Text
	label.TextXAlignment = props.AlignX or Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.LayoutOrder = props.LayoutOrder or 0
	label.Size = props.Size or UDim2.new(1, 0, 0, 0)
	if props.Size == nil then
		label.AutomaticSize = Enum.AutomaticSize.Y
	end
	return label
end

function Components.panel(name: string, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = color or Theme.Colors.Panel
	frame.BorderSizePixel = 0
	Components.corner(frame)
	Components.stroke(frame)
	return frame
end

-- Linha horizontal com texto à esquerda e um elemento (normalmente botão) à direita.
function Components.row(name: string, layoutOrder: number, height: number?): Frame
	local row = Components.panel(name, Theme.Colors.PanelRaised)
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, height or (buttonHeight + 24))
	Components.padding(row, 12)
	return row
end

return Components
