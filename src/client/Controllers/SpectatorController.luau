--!strict
-- Modo espectador: depois de morrer, a câmera acompanha colegas VIVOS (sem câmera livre).
-- PC: ← → trocam. Controle: direcional. Celular: botões na tela.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Definitions.Strings)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Net = require(Shared.Modules.Net)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local InputController = require(script.Parent.InputController)

type Target = { UserId: number, Name: string }

local SpectatorController = {}

local targets: { Target } = {}
local index = 1
local active = false

type Elements = { gui: ScreenGui, label: TextLabel, died: TextLabel }
local elements: Elements? = nil

local function focus()
	local ui = elements
	local target = targets[index]
	if ui then
		ui.label.Text = if target
			then Strings.get("SPECTATING", target.Name)
			else Strings.get("SPECTATING_NONE")
	end
	if not target then
		return
	end
	local player = Players:GetPlayerByUserId(target.UserId)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		workspace.CurrentCamera.CameraSubject = humanoid
	end
end

local function cycle(delta: number)
	if #targets == 0 then
		return
	end
	index = ((index - 1 + delta) % #targets) + 1
	focus()
end

local function setActive(value: boolean)
	if active == value then
		return
	end
	active = value
	if elements then
		elements.gui.Enabled = value
		elements.died.Visible = value
	end
	if value then
		InputController:BindAction(
			"SpectatePrev",
			{ Keyboard = Enum.KeyCode.Left, Gamepad = Enum.KeyCode.DPadLeft },
			function()
				cycle(-1)
			end
		)
		InputController:BindAction(
			"SpectateNext",
			{ Keyboard = Enum.KeyCode.Right, Gamepad = Enum.KeyCode.DPadRight },
			function()
				cycle(1)
			end
		)
		task.delay(3, function()
			if elements then
				elements.died.Visible = false
			end
		end)
		focus()
	else
		InputController:UnbindAction("SpectatePrev")
		InputController:UnbindAction("SpectateNext")
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			workspace.CurrentCamera.CameraSubject = humanoid
		end
	end
end

local function buildUI(parent: Instance): Elements
	local gui = Instance.new("ScreenGui")
	gui.Name = "Spectator"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = Theme.DisplayOrder.HUD + 2
	gui.Enabled = false

	local died = Components.label({
		Name = "Died",
		Text = Strings.get("YOU_DIED"),
		Font = Theme.Fonts.Bold,
		TextSize = 40,
		Color = Theme.Colors.Danger,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 60),
	})
	died.AnchorPoint = Vector2.new(0.5, 0.5)
	died.Position = UDim2.new(0.5, 0, 0.4, 0)
	died.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -24)
	bar.Size = UDim2.new(0, 460, 0, Theme.Sizes.ButtonHeightTouch)
	bar.Parent = gui
	local layout = Components.list(bar, 12, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	Components.button({
		Name = "PrevButton",
		Text = "◀",
		Size = UDim2.new(0, 72, 1, 0),
		LayoutOrder = 1,
		OnActivated = function()
			cycle(-1)
		end,
	}).Parent =
		bar
	local label = Components.label({
		Name = "Target",
		Text = "",
		Font = Theme.Fonts.Bold,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 280, 1, 0),
		LayoutOrder = 2,
	})
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = bar
	Components.button({
		Name = "NextButton",
		Text = "▶",
		Size = UDim2.new(0, 72, 1, 0),
		LayoutOrder = 3,
		OnActivated = function()
			cycle(1)
		end,
	}).Parent =
		bar

	gui.Parent = parent
	return { gui = gui, label = label, died = died }
end

function SpectatorController:IsActive(): boolean
	return active
end

function SpectatorController:GetTargets(): { Target }
	return targets
end

function SpectatorController:Init() end

function SpectatorController:Start()
	local player = Players.LocalPlayer
	elements = buildUI(InstanceUtil.waitForChild(player, "PlayerGui"))
	Net.Client.on("SpectateTargets", function(list)
		targets = if type(list) == "table" then list else {}
		if index > #targets then
			index = 1
		end
		if active then
			focus()
		end
	end)
	player:GetAttributeChangedSignal("State"):Connect(function()
		setActive(player:GetAttribute("State") == "Spectating")
	end)
end

return SpectatorController
