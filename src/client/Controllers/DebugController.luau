--!strict
-- Painel de debug. Aparece somente se:
--   1. GameConfig.DEBUG_MODE = true, E
--   2. o SERVIDOR confirmar que o jogador é admin (AdminService).
-- F3 (teclado) ou DPadDown (controle) mostra/esconde o painel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Strings = require(Shared.Definitions.Strings)
local Trove = require(Shared.Modules.Trove)

local Theme = require(script.Parent.Parent.UI.Theme)
local InputController = require(script.Parent.InputController)

local REFRESH_SECONDS = 1

local log = Log.new("DebugController")

local DebugController = {}

local trove = Trove.new()

local function createOverlay(): (ScreenGui, TextLabel)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DebugOverlay"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = Theme.DisplayOrder.Debug

	local label = Instance.new("TextLabel")
	label.Name = "Stats"
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -12, 0, 64)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.BackgroundColor3 = Theme.Colors.Background
	label.BackgroundTransparency = 0.3
	label.BorderSizePixel = 0
	label.Font = Theme.Fonts.Mono
	label.TextSize = Theme.TextSizes.Small
	label.TextColor3 = Theme.Colors.Text
	label.Text = "DEBUG"
	label.Parent = screenGui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = label

	return screenGui, label
end

local function measurePing(): number
	local startedAt = os.clock()
	local ok = Net.Client.invoke("Ping")
	if not ok then
		return -1
	end
	return math.floor((os.clock() - startedAt) * 1000)
end

function DebugController:Init() end

function DebugController:Start()
	if not GameConfig.DEBUG_MODE then
		return
	end

	local ok, access = Net.Client.invoke("RequestDebugAccess")
	if not ok or type(access) ~= "table" or access.Granted ~= true then
		log:Debug("Painel de debug não autorizado pelo servidor.")
		return
	end

	local screenGui, label = createOverlay()
	trove:Add(screenGui)
	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frames = 0
	trove:Connect(RunService.RenderStepped, function()
		frames += 1
	end)

	InputController:BindAction(
		"ToggleDebug",
		{ Keyboard = Enum.KeyCode.F3, Gamepad = Enum.KeyCode.DPadDown },
		function()
			screenGui.Enabled = not screenGui.Enabled
		end
	)
	trove:Add(function()
		InputController:UnbindAction("ToggleDebug")
	end)

	local localPlayer = Players.LocalPlayer

	log:Info("Painel de debug ativo (F3 para esconder).")

	while screenGui.Parent do
		local sampleStart = os.clock()
		frames = 0
		task.wait(REFRESH_SECONDS)
		local fps = math.floor(frames / (os.clock() - sampleStart) + 0.5)
		local text = Strings.get(
			"DEBUG_OVERLAY",
			GameConfig.GAME_VERSION,
			measurePing(),
			fps,
			InputController:GetInputType(),
			localPlayer:GetAttribute("Level") or 0,
			localPlayer:GetAttribute("Cash") or 0
		)
		-- Estado da partida (só admins recebem isto do servidor).
		local infoOk, info = Net.Client.invoke("GetDebugInfo")
		if infoOk and type(info) == "table" then
			text ..= `\n{info.Phase} · min {info.Minute} · jogadores {info.Alive}/{info.Players} · eventos {info.Events} · tarefas {info.Tasks}`
			text ..= `\nentidade {info.Entity} ({info.Temperament}) · clima {info.Weather} · tensão {info.Tension} · save {info.Saving}`
		end
		label.Text = text
	end
end

return DebugController
