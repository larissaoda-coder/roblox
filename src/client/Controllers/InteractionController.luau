--!strict
-- Desenha o aviso de interação ("[E] Abrir porta") e o botão INTERAGIR no celular.
-- A detecção e as teclas (E / X do controle) são do próprio ProximityPrompt; aqui só cuidamos do visual
-- e do toque na tela. Quem valida a interação é sempre o servidor (InteractionService).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Definitions.Strings)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Log = require(Shared.Modules.Log)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local InputController = require(script.Parent.InputController)

local log = Log.new("InteractionController")

local InteractionController = {}

local currentPrompt: ProximityPrompt? = nil
local holdStartedAt: number? = nil

type Elements = {
	gui: ScreenGui,
	panel: TextButton,
	key: TextLabel,
	action: TextLabel,
	fill: Frame,
}

local elements: Elements? = nil

local function keyText(): string?
	local inputType = InputController:GetInputType()
	if inputType == "Gamepad" then
		return "X"
	elseif inputType == "KeyboardMouse" then
		return "E"
	end
	return nil
end

local function buildUI(parent: Instance): Elements
	local gui = Instance.new("ScreenGui")
	gui.Name = "InteractionUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = Theme.DisplayOrder.HUD + 1

	-- O painel inteiro é um botão: no celular, tocar e segurar aciona a interação.
	local panel = Instance.new("TextButton")
	panel.Name = "InteractButton"
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -150)
	panel.Size = UDim2.new(0, 300, 0, 64)
	panel.BackgroundColor3 = Theme.Colors.Background
	panel.BackgroundTransparency = 0.2
	panel.Visible = false
	Components.corner(panel)
	Components.stroke(panel)
	panel.Parent = gui

	local key = Components.label({
		Name = "Key",
		Text = "E",
		Font = Theme.Fonts.Bold,
		Color = Theme.Colors.TextOnLight,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 36, 0, 36),
	})
	key.AnchorPoint = Vector2.new(0, 0.5)
	key.Position = UDim2.new(0, 14, 0.5, 0)
	key.BackgroundTransparency = 0
	key.BackgroundColor3 = Theme.Colors.Text
	Components.corner(key)
	key.Parent = panel

	local action = Components.label({
		Name = "Action",
		Text = "",
		Font = Theme.Fonts.Bold,
		Size = UDim2.new(1, -70, 1, 0),
	})
	action.Position = UDim2.new(0, 62, 0, 0)
	action.TextYAlignment = Enum.TextYAlignment.Center
	action.TextTruncate = Enum.TextTruncate.AtEnd
	action.Parent = panel

	local bar = Instance.new("Frame")
	bar.Name = "HoldBar"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 0, 1, 0)
	bar.Size = UDim2.new(1, 0, 0, 4)
	bar.BackgroundColor3 = Theme.Colors.Border
	bar.BorderSizePixel = 0
	bar.Parent = panel

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Theme.Colors.Text
	fill.BorderSizePixel = 0
	fill.Parent = bar

	gui.Parent = parent
	return { gui = gui, panel = panel, key = key, action = action, fill = fill }
end

local function render()
	local ui = elements
	if not ui then
		return
	end
	local prompt = currentPrompt
	ui.panel.Visible = prompt ~= nil
	if not prompt then
		return
	end
	local promptKey = prompt:GetAttribute("PromptKey")
	local actionText = Strings.get(if type(promptKey) == "string" then promptKey else "PROMPT_INTERACT")
	local keyLabel = keyText()
	ui.key.Visible = keyLabel ~= nil
	ui.key.Text = keyLabel or ""
	-- No celular não há tecla: mostra "INTERAGIR · Abrir porta" e o painel fica maior.
	if keyLabel then
		ui.action.Text = actionText
		ui.action.Position = UDim2.new(0, 62, 0, 0)
		ui.panel.Size = UDim2.new(0, 300, 0, 64)
	else
		ui.action.Text = `{Strings.get("INTERACT_BUTTON")} · {actionText}`
		ui.action.Position = UDim2.new(0, 16, 0, 0)
		ui.panel.Size = UDim2.new(0, 320, 0, 72)
	end
	ui.fill.Size = UDim2.new(0, 0, 1, 0)
end

local function updateHold()
	local ui = elements
	local prompt = currentPrompt
	local startedAt = holdStartedAt
	if not ui or not prompt or not startedAt or prompt.HoldDuration <= 0 then
		return
	end
	local progress = math.clamp((os.clock() - startedAt) / prompt.HoldDuration, 0, 1)
	ui.fill.Size = UDim2.new(progress, 0, 1, 0)
end

function InteractionController:GetCurrentPrompt(): ProximityPrompt?
	return currentPrompt
end

function InteractionController:Init() end

function InteractionController:Start()
	local playerGui = InstanceUtil.waitForChild(Players.LocalPlayer, "PlayerGui")
	local ui = buildUI(playerGui)
	elements = ui

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		currentPrompt = prompt
		holdStartedAt = nil
		render()
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		if currentPrompt == prompt then
			currentPrompt = nil
			holdStartedAt = nil
			render()
		end
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
		if prompt == currentPrompt then
			holdStartedAt = os.clock()
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
		if prompt == currentPrompt then
			holdStartedAt = nil
			ui.fill.Size = UDim2.new(0, 0, 1, 0)
		end
	end)

	-- Toque/clique no painel = segurar o botão do prompt.
	ui.panel.MouseButton1Down:Connect(function()
		local prompt = currentPrompt
		if prompt then
			prompt:InputHoldBegin()
		end
	end)
	ui.panel.MouseButton1Up:Connect(function()
		local prompt = currentPrompt
		if prompt then
			prompt:InputHoldEnd()
		end
	end)

	InputController.InputTypeChanged:Connect(render)
	RunService.RenderStepped:Connect(updateHold)
	log:Debug("Interação pronta.")
end

return InteractionController
