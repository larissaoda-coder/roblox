--!strict
-- Monitor de câmeras de segurança: troca de câmera, efeito de monitor (estática, REC, relógio)
-- e aparições que existem SÓ nas câmeras (figuras criadas localmente, visíveis apenas naquela câmera).
-- PC: ← → trocam, Backspace sai. Controle: direcional esquerda/direita, B sai. Celular: botões na tela.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Definitions.Strings)
local FigureFactory = require(Shared.Modules.FigureFactory)
local GameClock = require(Shared.Modules.GameClock)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Net = require(Shared.Modules.Net)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local AudioController = require(script.Parent.AudioController)
local InputController = require(script.Parent.InputController)

type CameraInfo = { Id: string, LabelKey: string, CFrame: CFrame }
type Anomaly = { CameraId: string, Models: { Model }, EndsAt: number }

local SecurityCameraController = {}

local cameras: { CameraInfo } = {}
local index = 1
local isOpen = false
local anomalies: { Anomaly } = {}
local anomalyFolder: Folder? = nil

type Elements = { gui: ScreenGui, label: TextLabel, rec: TextLabel, clock: TextLabel, static: Frame }
local elements: Elements? = nil

local function currentCameraId(): string?
	local camera = cameras[index]
	return if camera then camera.Id else nil
end

-- Clientes com NoCameraRecord não aparecem nas câmeras (só enquanto o monitor está aberto).
local function refreshNoRecord()
	local runtime = workspace:FindFirstChild("Runtime")
	if not runtime then
		return
	end
	for _, model in runtime:GetDescendants() do
		if model:IsA("Model") and model:GetAttribute("NoCameraRecord") == true then
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = if isOpen then 1 else 0
				end
			end
		end
	end
end

local function refreshAnomalies()
	refreshNoRecord()
	local cameraId = currentCameraId()
	local now = os.clock()
	for position = #anomalies, 1, -1 do
		local anomaly = anomalies[position]
		if now >= anomaly.EndsAt then
			for _, model in anomaly.Models do
				model:Destroy()
			end
			table.remove(anomalies, position)
		else
			local visible = isOpen and anomaly.CameraId == cameraId
			for _, model in anomaly.Models do
				model.Parent = if visible then anomalyFolder else nil
			end
		end
	end
end

local function staticBurst()
	local ui = elements
	if not ui then
		return
	end
	ui.static.BackgroundTransparency = 0.1
	task.delay(0.2, function()
		if elements then
			elements.static.BackgroundTransparency = 0.9
		end
	end)
end

local function view(newIndex: number)
	if #cameras == 0 then
		return
	end
	index = ((newIndex - 1) % #cameras) + 1
	local camera = cameras[index]
	local worldCamera = workspace.CurrentCamera
	worldCamera.CameraType = Enum.CameraType.Scriptable
	worldCamera.CFrame = camera.CFrame
	worldCamera.FieldOfView = 70
	if elements then
		elements.label.Text = `{camera.Id} — {Strings.get(camera.LabelKey)}`
	end
	staticBurst()
	refreshAnomalies()
	Net.Client.fire("SetCameraView", index)
end

local function close(notifyServer: boolean)
	if not isOpen then
		return
	end
	isOpen = false
	InputController:UnbindAction("CameraPrev")
	InputController:UnbindAction("CameraNext")
	InputController:UnbindAction("CameraExit")
	local worldCamera = workspace.CurrentCamera
	worldCamera.CameraType = Enum.CameraType.Custom
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		worldCamera.CameraSubject = humanoid
	end
	AudioController:Stop("CameraStatic")
	if elements then
		elements.gui.Enabled = false
	end
	refreshAnomalies()
	if notifyServer then
		Net.Client.fire("CloseCameraFeed")
	end
end

local function open(list: { CameraInfo })
	cameras = list
	isOpen = true
	if elements then
		elements.gui.Enabled = true
	end
	InputController:BindAction(
		"CameraPrev",
		{ Keyboard = Enum.KeyCode.Left, Gamepad = Enum.KeyCode.DPadLeft },
		function()
			view(index - 1)
		end
	)
	InputController:BindAction(
		"CameraNext",
		{ Keyboard = Enum.KeyCode.Right, Gamepad = Enum.KeyCode.DPadRight },
		function()
			view(index + 1)
		end
	)
	InputController:BindAction(
		"CameraExit",
		{ Keyboard = Enum.KeyCode.Backspace, Gamepad = Enum.KeyCode.ButtonB },
		function()
			close(true)
		end
	)
	AudioController:Play("CameraStatic", nil, { Tag = "CameraStatic" })
	view(1)

	-- Efeito de monitor: REC piscando, relógio e ruído leve (atualiza 5x por segundo).
	task.spawn(function()
		local matchState = ReplicatedStorage:FindFirstChild("MatchState")
		local blink = false
		while isOpen do
			blink = not blink
			local ui = elements
			if ui then
				ui.rec.TextTransparency = if blink then 0 else 0.7
				local minute = if matchState then tonumber(matchState:GetAttribute("GameMinute")) else 0
				ui.clock.Text = GameClock.format(minute or 0)
				if ui.static.BackgroundTransparency > 0.5 then
					ui.static.BackgroundTransparency = 0.86 + math.random() * 0.08
				end
			end
			refreshAnomalies()
			task.wait(0.2)
		end
	end)
end

local function buildUI(parent: Instance): Elements
	local gui = Instance.new("ScreenGui")
	gui.Name = "CameraFeed"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = Theme.DisplayOrder.Menus + 5
	gui.Enabled = false

	local static = Instance.new("Frame")
	static.Name = "Static"
	static.Size = UDim2.fromScale(1, 1)
	static.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	static.BackgroundTransparency = 0.9
	static.BorderSizePixel = 0
	static.Parent = gui

	-- Linhas horizontais leves (efeito de monitor antigo).
	for line = 0, 11 do
		local scanline = Instance.new("Frame")
		scanline.Name = "Scanline"
		scanline.BackgroundColor3 = Color3.new(0, 0, 0)
		scanline.BackgroundTransparency = 0.82
		scanline.BorderSizePixel = 0
		scanline.Position = UDim2.new(0, 0, line / 12, 0)
		scanline.Size = UDim2.new(1, 0, 0, 3)
		scanline.Parent = gui
	end

	local label = Components.label({
		Name = "CameraLabel",
		Text = "",
		Font = Theme.Fonts.Mono,
		TextSize = Theme.TextSizes.Heading,
		Size = UDim2.new(0.6, 0, 0, 32),
	})
	label.Position = UDim2.new(0, 24, 0, 64)
	label.Parent = gui

	local rec = Components.label({
		Name = "Rec",
		Text = "● REC",
		Font = Theme.Fonts.Mono,
		TextSize = Theme.TextSizes.Body,
		Color = Color3.fromRGB(200, 40, 40),
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 160, 0, 26),
	})
	rec.AnchorPoint = Vector2.new(1, 0)
	rec.Position = UDim2.new(1, -24, 0, 64)
	rec.Parent = gui

	local clock = Components.label({
		Name = "Clock",
		Text = "",
		Font = Theme.Fonts.Mono,
		TextSize = Theme.TextSizes.Body,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 160, 0, 26),
	})
	clock.AnchorPoint = Vector2.new(1, 0)
	clock.Position = UDim2.new(1, -24, 0, 92)
	clock.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Controls"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -24)
	bar.Size = UDim2.new(0, 420, 0, Theme.Sizes.ButtonHeightTouch)
	bar.Parent = gui
	local layout = Components.list(bar, 12, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	Components.button({
		Name = "PrevButton",
		Text = "◀",
		Size = UDim2.new(0, 96, 1, 0),
		LayoutOrder = 1,
		OnActivated = function()
			view(index - 1)
		end,
	}).Parent =
		bar
	Components.button({
		Name = "ExitButton",
		Text = Strings.get("CAM_EXIT"),
		Style = "Danger",
		Size = UDim2.new(0, 180, 1, 0),
		LayoutOrder = 2,
		OnActivated = function()
			close(true)
		end,
	}).Parent =
		bar
	Components.button({
		Name = "NextButton",
		Text = "▶",
		Size = UDim2.new(0, 96, 1, 0),
		LayoutOrder = 3,
		OnActivated = function()
			view(index + 1)
		end,
	}).Parent =
		bar

	gui.Parent = parent
	return { gui = gui, label = label, rec = rec, clock = clock, static = static }
end

function SecurityCameraController:IsOpen(): boolean
	return isOpen
end

function SecurityCameraController:GetCurrentCameraId(): string?
	return if isOpen then currentCameraId() else nil
end

function SecurityCameraController:Next()
	view(index + 1)
end

function SecurityCameraController:Close()
	close(true)
end

function SecurityCameraController:Init() end

function SecurityCameraController:Start()
	local playerGui = InstanceUtil.waitForChild(Players.LocalPlayer, "PlayerGui")
	elements = buildUI(playerGui)
	local folder = Instance.new("Folder")
	folder.Name = "NS_CameraAnomalies"
	folder.Parent = workspace
	anomalyFolder = folder

	Net.Client.on("CameraFeedOpened", open)
	Net.Client.on("CameraFeedClosed", function()
		close(false)
	end)
	Net.Client.on("CameraAnomaly", function(cameraId: string, anomalyType: string, data, duration: number)
		if type(data) ~= "table" or typeof(data.Position) ~= "Vector3" then
			return
		end
		local models = {}
		local count = math.clamp(tonumber(data.Count) or 1, 1, 6)
		for figureIndex = 1, count do
			local offset = Vector3.new((figureIndex - (count + 1) / 2) * 3, 0, 0)
			local figure = FigureFactory.build(data.Position + offset, {
				Name = `Anomaly_{anomalyType}`,
				Eyes = anomalyType == "Figure",
				Color = if anomalyType == "Team" then Color3.fromRGB(70, 70, 76) else nil,
			})
			table.insert(models, figure)
		end
		table.insert(
			anomalies,
			{ CameraId = cameraId, Models = models, EndsAt = os.clock() + (tonumber(duration) or 10) }
		)
		refreshAnomalies()
	end)
	-- Voltar ao lobby fecha o monitor.
	Players.LocalPlayer:GetAttributeChangedSignal("State"):Connect(function()
		if Players.LocalPlayer:GetAttribute("State") ~= "InShift" then
			close(false)
		end
	end)
end

return SecurityCameraController
