--!strict
-- Mensagens curtas na tela ("Está trancada.", "Tarefa concluída"…).
-- O servidor envia pelo Remote Notify (chave de texto); controllers do cliente podem chamar :Show direto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Definitions.Strings)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Net = require(Shared.Modules.Net)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)

local SHOW_SECONDS = 3

local NotificationController = {}

local label: TextLabel? = nil
local token = 0

function NotificationController:Show(text: string, duration: number?)
	local current = label
	if not current then
		return
	end
	token += 1
	local myToken = token
	current.Text = text
	current.Visible = true
	task.delay(duration or SHOW_SECONDS, function()
		if token == myToken then
			current.Visible = false
		end
	end)
end

function NotificationController:ShowKey(key: string, ...: any)
	self:Show(Strings.get(key, ...))
end

function NotificationController:Init() end

function NotificationController:Start()
	local playerGui = InstanceUtil.waitForChild(Players.LocalPlayer, "PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notifications"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = Theme.DisplayOrder.Popups

	local message = Components.label({
		Name = "Message",
		Text = "",
		Font = Theme.Fonts.Bold,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 0, 0, 0),
	})
	message.AutomaticSize = Enum.AutomaticSize.XY
	message.AnchorPoint = Vector2.new(0.5, 0)
	message.Position = UDim2.new(0.5, 0, 0.24, 0)
	message.BackgroundColor3 = Theme.Colors.Background
	message.BackgroundTransparency = 0.2
	message.Visible = false
	Components.corner(message)
	Components.padding(message, 12)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, math.huge)
	limit.Parent = message
	message.Parent = gui
	gui.Parent = playerGui
	label = message

	Net.Client.on("Notify", function(key: string, ...: any)
		if type(key) == "string" then
			NotificationController:ShowKey(key, ...)
		end
	end)
end

return NotificationController
