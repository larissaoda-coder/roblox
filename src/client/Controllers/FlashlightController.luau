--!strict
-- Liga/desliga a lanterna. PC: F. Controle: Y. Celular: botão na tela (só durante o turno).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Definitions.Strings)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Net = require(Shared.Modules.Net)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local InputController = require(script.Parent.InputController)

local FlashlightController = {}

local button: TextButton? = nil

local function toggle()
	local player = Players.LocalPlayer
	if player:GetAttribute("State") ~= "InShift" then
		return
	end
	Net.Client.fire("SetFlashlight", player:GetAttribute("FlashlightOn") ~= true)
end

local function refresh()
	local player = Players.LocalPlayer
	local current = button
	if current then
		current.Visible = player:GetAttribute("State") == "InShift" and InputController:IsTouch()
		current.Text = Strings.get(
			if player:GetAttribute("FlashlightOn") == true then "FLASHLIGHT_OFF" else "FLASHLIGHT_ON"
		)
	end
end

function FlashlightController:Toggle()
	toggle()
end

function FlashlightController:Init() end

function FlashlightController:Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Flashlight"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = Theme.DisplayOrder.HUD
	local newButton = Components.button({
		Name = "FlashlightButton",
		Text = "",
		Size = UDim2.new(0, 120, 0, Theme.Sizes.ButtonHeightTouch),
		OnActivated = toggle,
	})
	-- À direita, acima do botão de pular do celular.
	newButton.AnchorPoint = Vector2.new(1, 1)
	newButton.Position = UDim2.new(1, -24, 1, -190)
	newButton.Parent = gui
	gui.Parent = InstanceUtil.waitForChild(player, "PlayerGui")
	button = newButton

	InputController:BindAction(
		"Flashlight",
		{ Keyboard = Enum.KeyCode.F, Gamepad = Enum.KeyCode.ButtonY },
		toggle
	)
	player:GetAttributeChangedSignal("State"):Connect(refresh)
	player:GetAttributeChangedSignal("FlashlightOn"):Connect(refresh)
	InputController.InputTypeChanged:Connect(refresh)
	refresh()
end

return FlashlightController
