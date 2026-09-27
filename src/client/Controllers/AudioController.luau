--!strict
-- Toca os sons pedidos pelo servidor, com SoundGroups (volume por categoria) e legendas.
-- Performance: sons posicionais usam um pequeno conjunto de emissores reaproveitados (sem criar/destruir a cada som).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage.Shared
local SoundDefinitions = require(Shared.Definitions.SoundDefinitions)
local Strings = require(Shared.Definitions.Strings)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Net = require(Shared.Modules.Net)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local SettingsController = require(script.Parent.SettingsController)

local SUBTITLE_SECONDS = 3
local MAX_SUBTITLES = 3
local EMITTER_POOL_SIZE = 12

local GROUP_SETTINGS: { [string]: string } = {
	Effects = "EffectsVolume",
	Ambience = "EffectsVolume",
	Voice = "EffectsVolume",
	UI = "EffectsVolume",
	Music = "MusicVolume",
}

local AudioController = {}

local groups: { [string]: SoundGroup } = {}
local emitters: { Part } = {}
local nextEmitter = 1
local loops: { [string]: Sound } = {}
local subtitleFrame: Frame? = nil
local subtitleCount = 0

-- Últimas legendas mostradas (usado pelos testes e pelo debug).
AudioController.RecentSubtitles = {} :: { string }

local function applyVolumes()
	local master = SettingsController:Get("MasterVolume") or 1
	for groupName, group in groups do
		local key = GROUP_SETTINGS[groupName]
		group.Volume = master * ((key and SettingsController:Get(key)) or 1)
	end
end

local function createGroups()
	for groupName in GROUP_SETTINGS do
		local group = Instance.new("SoundGroup")
		group.Name = `NS_{groupName}`
		group.Parent = SoundService
		groups[groupName] = group
	end
	applyVolumes()
end

local function getEmitter(position: Vector3): Part
	local emitter = emitters[nextEmitter]
	nextEmitter = nextEmitter % EMITTER_POOL_SIZE + 1
	emitter.Position = position
	return emitter
end

local function showSubtitle(key: string)
	table.insert(AudioController.RecentSubtitles, key)
	if #AudioController.RecentSubtitles > 20 then
		table.remove(AudioController.RecentSubtitles, 1)
	end
	local frame = subtitleFrame
	if not frame or SettingsController:Get("Subtitles") ~= true then
		return
	end
	if subtitleCount >= MAX_SUBTITLES then
		return
	end
	subtitleCount += 1
	local label = Components.label({
		Name = "Subtitle",
		Text = `[{Strings.get(key)}]`,
		TextSize = Theme.TextSizes.Body,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 0, 0, 0),
	})
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.BackgroundColor3 = Theme.Colors.Background
	label.BackgroundTransparency = 0.35
	Components.padding(label, 6)
	label.Parent = frame
	task.delay(SUBTITLE_SECONDS, function()
		subtitleCount -= 1
		label:Destroy()
	end)
end

local function isInRange(position: Vector3?, maxDistance: number): boolean
	if not position or maxDistance <= 0 then
		return true
	end
	local camera = workspace.CurrentCamera
	local listener = if camera then camera.CFrame.Position else position
	return (listener - position).Magnitude <= maxDistance
end

-- Toca um som localmente. Pode ser chamado por outros controllers (efeitos perceptivos, UI).
function AudioController:Play(soundName: string, position: Vector3?, options: { [string]: any }?)
	local definition = SoundDefinitions.get(soundName)
	if not definition then
		return
	end
	local settings: { [string]: any } = options or {}
	local tag = settings.Tag or soundName
	if definition.SubtitleKey and isInRange(position, definition.MaxDistance) then
		showSubtitle(definition.SubtitleKey)
	end
	if definition.SoundId == "" then
		return -- sem arquivo de áudio configurado: só a legenda
	end

	if definition.Looped and loops[tag] then
		loops[tag]:Destroy()
		loops[tag] = nil
	end

	local sound = Instance.new("Sound")
	sound.Name = soundName
	sound.SoundId = definition.SoundId
	sound.Volume = definition.Volume * (settings.Volume or 1)
	sound.PlaybackSpeed = settings.PlaybackSpeed or 1
	sound.Looped = definition.Looped
	sound.SoundGroup = groups[definition.Group]
	if position then
		sound.RollOffMaxDistance = math.max(definition.MaxDistance, 10)
		sound.RollOffMinDistance = 6
		sound.Parent = getEmitter(position)
	else
		sound.Parent = SoundService
	end
	sound:Play()
	if definition.Looped then
		loops[tag] = sound
	else
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
end

function AudioController:Stop(tag: string)
	local sound = loops[tag]
	if sound then
		loops[tag] = nil
		sound:Destroy()
	end
end

function AudioController:StopAll()
	for tag in loops do
		self:Stop(tag)
	end
end

function AudioController:Init() end

function AudioController:Start()
	createGroups()
	SettingsController.Changed:Connect(applyVolumes)

	local emitterFolder = Instance.new("Folder")
	emitterFolder.Name = "NS_AudioEmitters"
	for index = 1, EMITTER_POOL_SIZE do
		local emitter = Instance.new("Part")
		emitter.Name = `Emitter{index}`
		emitter.Anchored = true
		emitter.CanCollide = false
		emitter.CanQuery = false
		emitter.CanTouch = false
		emitter.Transparency = 1
		emitter.Size = Vector3.new(0.2, 0.2, 0.2)
		emitter.Parent = emitterFolder
		emitters[index] = emitter
	end
	emitterFolder.Parent = workspace

	local playerGui = InstanceUtil.waitForChild(Players.LocalPlayer, "PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "Subtitles"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = Theme.DisplayOrder.Popups
	local frame = Instance.new("Frame")
	frame.Name = "List"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -230)
	frame.Size = UDim2.new(0.8, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	local layout = Components.list(frame, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	frame.Parent = gui
	gui.Parent = playerGui
	subtitleFrame = frame

	Net.Client.on("PlaySound", function(soundName: string, position: Vector3?, options)
		AudioController:Play(soundName, position, options)
	end)
	Net.Client.on("StopSound", function(tag: string)
		AudioController:Stop(tag)
	end)

	-- Ao voltar ao lobby, para os loops da partida.
	Players.LocalPlayer:GetAttributeChangedSignal("State"):Connect(function()
		if Players.LocalPlayer:GetAttribute("State") == "Lobby" then
			AudioController:StopAll()
		end
	end)
end

return AudioController
