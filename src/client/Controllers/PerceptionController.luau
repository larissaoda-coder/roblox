--!strict
-- Efeitos que SÓ este jogador percebe (enviados pelo servidor) e o efeito visual da tensão.
-- Tensão alta: cores mais frias e dessaturadas, bordas escuras, batimento cardíaco.
-- "Efeitos reduzidos" diminui tudo pela metade.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local FigureFactory = require(Shared.Modules.FigureFactory)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Net = require(Shared.Modules.Net)

local Theme = require(script.Parent.Parent.UI.Theme)
local AudioController = require(script.Parent.AudioController)
local SettingsController = require(script.Parent.SettingsController)

local HEARTBEAT_THRESHOLD = 75
local MAX_FIGURE_SECONDS = 3

local PerceptionController = {}

local colorCorrection: ColorCorrectionEffect? = nil
local vignetteEdges: { Frame } = {}
local heartbeatOn = false

-- Últimas percepções recebidas (para testes/debug).
PerceptionController.Recent = {} :: { string }

local function applyTension()
	local player = Players.LocalPlayer
	local raw = tonumber(player:GetAttribute("Tension")) or 0
	local inShift = player:GetAttribute("State") == "InShift"
	local strength = if inShift then math.clamp(raw / 100, 0, 1) else 0
	if SettingsController:Get("ReducedEffects") == true then
		strength *= 0.5
	end
	local effect = colorCorrection
	if effect then
		effect.Saturation = -0.45 * strength
		effect.Contrast = 0.12 * strength
		effect.TintColor = Color3.new(1 - 0.08 * strength, 1 - 0.04 * strength, 1)
	end
	for _, edge in vignetteEdges do
		edge.BackgroundTransparency = 1 - 0.65 * strength
	end
	local shouldBeat = inShift and raw >= HEARTBEAT_THRESHOLD
	if shouldBeat ~= heartbeatOn then
		heartbeatOn = shouldBeat
		if shouldBeat then
			AudioController:Play("Heartbeat", nil, { Tag = "Heartbeat" })
		else
			AudioController:Stop("Heartbeat")
		end
	end
end

local function buildVignette(parent: Instance)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TensionVignette"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = Theme.DisplayOrder.HUD - 1
	local sides = {
		{ Name = "Top", Size = UDim2.new(1, 0, 0.18, 0), Position = UDim2.new(0, 0, 0, 0), Rotation = 90 },
		{
			Name = "Bottom",
			Size = UDim2.new(1, 0, 0.18, 0),
			Position = UDim2.new(0, 0, 0.82, 0),
			Rotation = -90,
		},
		{ Name = "Left", Size = UDim2.new(0.14, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0), Rotation = 0 },
		{
			Name = "Right",
			Size = UDim2.new(0.14, 0, 1, 0),
			Position = UDim2.new(0.86, 0, 0, 0),
			Rotation = 180,
		},
	}
	for _, side in sides do
		local edge = Instance.new("Frame")
		edge.Name = side.Name
		edge.Size = side.Size
		edge.Position = side.Position
		edge.BackgroundColor3 = Color3.new(0, 0, 0)
		edge.BackgroundTransparency = 1
		edge.BorderSizePixel = 0
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = side.Rotation
		gradient.Transparency = NumberSequence.new(0, 1)
		gradient.Parent = edge
		edge.Parent = gui
		table.insert(vignetteEdges, edge)
	end
	gui.Parent = parent
end

local function perceive(kind: string, data: { [string]: any })
	table.insert(PerceptionController.Recent, kind)
	if #PerceptionController.Recent > 20 then
		table.remove(PerceptionController.Recent, 1)
	end
	if kind == "Sound" and type(data.Sound) == "string" then
		AudioController:Play(data.Sound, if typeof(data.Position) == "Vector3" then data.Position else nil)
	elseif kind == "FakeDoor" and typeof(data.Position) == "Vector3" then
		AudioController:Play("DoorSlam", data.Position)
	elseif kind == "Figure" and typeof(data.Position) == "Vector3" then
		local figure = FigureFactory.build(data.Position, { Name = "Perception", Eyes = true })
		figure.Parent = workspace
		local duration = math.clamp(tonumber(data.Duration) or 1, 0.1, MAX_FIGURE_SECONDS)
		task.delay(duration, function()
			figure:Destroy()
		end)
	end
end

function PerceptionController:Init() end

function PerceptionController:Start()
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "NS_Tension"
	effect.Parent = Lighting
	colorCorrection = effect
	buildVignette(InstanceUtil.waitForChild(Players.LocalPlayer, "PlayerGui"))

	Net.Client.on("Perception", function(kind: string, data)
		if type(kind) == "string" and type(data) == "table" then
			perceive(kind, data)
		end
	end)
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("Tension"):Connect(applyTension)
	player:GetAttributeChangedSignal("State"):Connect(applyTension)
	SettingsController.Changed:Connect(applyTension)
	applyTension()
end

return PerceptionController
