--!strict
-- Janela de conversa com NPCs: nome, fala e botões de resposta (grandes no celular).
-- Teclado: 1–4 escolhem. Controle: o primeiro botão já vem selecionado.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Definitions.Strings)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Net = require(Shared.Modules.Net)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local InputController = require(script.Parent.InputController)

local NUMBER_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

local DialogueController = {}

type Elements = { gui: ScreenGui, speaker: TextLabel, text: TextLabel, choices: Frame }
local elements: Elements? = nil
local currentNode: { [string]: any }? = nil

local function choose(index: number)
	local node = currentNode
	if node and node.Choices[index] then
		Net.Client.fire("DialogueChoice", index)
	end
end

local function bindKeys(count: number)
	for index, keyCode in NUMBER_KEYS do
		InputController:UnbindAction(`DialogueChoice{index}`)
		if index <= count then
			InputController:BindAction(`DialogueChoice{index}`, { Keyboard = keyCode }, function()
				choose(index)
			end)
		end
	end
end

local function render(node: { [string]: any }?)
	currentNode = node
	local ui = elements
	if not ui then
		return
	end
	for _, child in ui.choices:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	if not node then
		ui.gui.Enabled = false
		bindKeys(0)
		return
	end
	ui.gui.Enabled = true
	ui.speaker.Text = Strings.get(node.SpeakerKey)
	ui.text.Text = Strings.get(node.TextKey)
	local first: TextButton? = nil
	for index, choiceKey in node.Choices do
		local button = Components.button({
			Name = `Choice{index}`,
			Text = `{index}. {Strings.get(choiceKey)}`,
			LayoutOrder = index,
			OnActivated = function()
				choose(index)
			end,
		})
		button.TextXAlignment = Enum.TextXAlignment.Left
		Components.padding(button, 12)
		button.Parent = ui.choices
		first = first or button
	end
	bindKeys(#node.Choices)
	if first and InputController:GetInputType() == "Gamepad" then
		GuiService.SelectedObject = first
	end
end

local function buildUI(parent: Instance): Elements
	local gui = Instance.new("ScreenGui")
	gui.Name = "Dialogue"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = Theme.DisplayOrder.Menus + 2
	gui.Enabled = false

	local panel = Components.panel("Panel", Theme.Colors.Background)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.new(0.94, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundTransparency = 0.1
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(720, math.huge)
	limit.Parent = panel
	Components.padding(panel)
	Components.list(panel)
	panel.Parent = gui

	local speaker = Components.label({
		Name = "Speaker",
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSizes.Small,
		Color = Theme.Colors.TextDim,
		LayoutOrder = 1,
	})
	speaker.Parent = panel
	local text =
		Components.label({ Name = "Text", Text = "", TextSize = Theme.TextSizes.Body, LayoutOrder = 2 })
	text.Parent = panel
	local choices = Instance.new("Frame")
	choices.Name = "Choices"
	choices.BackgroundTransparency = 1
	choices.Size = UDim2.new(1, 0, 0, 0)
	choices.AutomaticSize = Enum.AutomaticSize.Y
	choices.LayoutOrder = 3
	Components.list(choices)
	choices.Parent = panel

	gui.Parent = parent
	return { gui = gui, speaker = speaker, text = text, choices = choices }
end

function DialogueController:IsOpen(): boolean
	return currentNode ~= nil
end

function DialogueController:Choose(index: number)
	choose(index)
end

function DialogueController:Init() end

function DialogueController:Start()
	elements = buildUI(InstanceUtil.waitForChild(Players.LocalPlayer, "PlayerGui"))
	Net.Client.on("DialogueNode", function(node)
		render(if type(node) == "table" then node else nil)
	end)
end

return DialogueController
