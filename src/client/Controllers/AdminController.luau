--!strict
-- Painel de admin para testar o jogo (F4 no teclado). Só aparece se o SERVIDOR confirmar que você é admin
-- e DEBUG_MODE estiver ligado. Cada botão pede um comando; o servidor valida de novo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Net = require(Shared.Modules.Net)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local InputController = require(script.Parent.InputController)
local NotificationController = require(script.Parent.NotificationController)

local ZONES = { "Store", "Stockroom", "Office", "Bathroom", "Corridor", "Back", "Pumps", "Parking" }

local AdminController = {}

local gui: ScreenGui? = nil

local function run(command: string, argument: any)
	local ok, result = Net.Client.invoke("AdminCommand", command, argument)
	if ok and type(result) == "table" then
		NotificationController:Show(`[ADMIN] {tostring(result.Message)}`)
	end
end

local function build(parent: Instance, eventIds: { string }): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "AdminPanel"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = Theme.DisplayOrder.Debug
	screen.Enabled = false

	local panel = Instance.new("ScrollingFrame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 16, 0.5, 0)
	panel.Size = UDim2.new(0, 280, 0.8, 0)
	panel.BackgroundColor3 = Theme.Colors.Background
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.ScrollBarThickness = 4
	panel.CanvasSize = UDim2.new()
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Components.padding(panel, 10)
	Components.list(panel, 6)
	panel.Parent = screen

	local order = 0
	local function section(text: string)
		order += 1
		Components.label({
			Text = text,
			Font = Theme.Fonts.Bold,
			TextSize = Theme.TextSizes.Small,
			Color = Theme.Colors.TextDim,
			LayoutOrder = order,
		}).Parent =
			panel
	end
	local function button(name: string, text: string, command: string, argument: any)
		order += 1
		Components.button({
			Name = name,
			Text = text,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 40),
			OnActivated = function()
				run(command, argument)
			end,
		}).Parent =
			panel
	end

	section("ADMIN")
	button("Cash", "+1000 CASH", "GiveCash", 1000)
	button("Skip", "+5 MIN", "SkipMinutes", 5)
	button("EndShift", "END SHIFT", "EndShift", nil)
	button("DirectorOn", "DIRECTOR ON", "Director", true)
	button("DirectorOff", "DIRECTOR OFF", "Director", false)
	button("Blackout", "BLACKOUT", "Blackout", nil)
	button("Heal", "TENSION 0", "Heal", nil)
	section("ENTITY")
	for _, state in { "Watching", "Stalking", "Manifest", "Hunt" } do
		button(`Entity_{state}`, string.upper(state), "Entity", state)
	end
	section("TELEPORT")
	for _, zone in ZONES do
		button(`Teleport_{zone}`, zone, "Teleport", zone)
	end
	section("EVENTS")
	for _, eventId in eventIds do
		button(`Event_{eventId}`, eventId, "TriggerEvent", eventId)
	end

	screen.Parent = parent
	return screen
end

function AdminController:Init() end

function AdminController:Start()
	if not GameConfig.DEBUG_MODE then
		return
	end
	local player = Players.LocalPlayer
	local startedAt = os.clock()
	while player:GetAttribute("Ready") ~= true and os.clock() - startedAt < 30 do
		task.wait(0.1)
	end
	task.wait(5.1) -- respeita o limite do RequestDebugAccess (o painel de debug também pede)
	local ok, access = Net.Client.invoke("RequestDebugAccess")
	if not ok or type(access) ~= "table" or access.Admin ~= true or access.Granted ~= true then
		return
	end
	gui = build(InstanceUtil.waitForChild(player, "PlayerGui"), access.EventIds or {})
	InputController:BindAction("AdminPanel", { Keyboard = Enum.KeyCode.F4 }, function()
		if gui then
			gui.Enabled = not gui.Enabled
		end
	end)
end

return AdminController
