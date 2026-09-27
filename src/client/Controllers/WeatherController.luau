--!strict
-- Efeitos de clima no cliente: chuva ao redor da câmera, raios e sons de ambiente.
-- Performance: a chuva é UM emissor que acompanha a câmera; desliga com "efeitos reduzidos".

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local InstanceUtil = require(Shared.Modules.InstanceUtil)

local AudioController = require(script.Parent.AudioController)
local SettingsController = require(script.Parent.SettingsController)

local STATE_WAIT_TIMEOUT = 30
local RAIN_HEIGHT = 30

local WeatherController = {}

local stateFolder: Instance
local rainPart: Part? = nil
local rainEmitter: ParticleEmitter? = nil

local function inShift(): boolean
	return Players.LocalPlayer:GetAttribute("State") == "InShift"
end

local function currentWeather(): string
	local weather = stateFolder:GetAttribute("Weather")
	return if type(weather) == "string" then weather else "Clear"
end

local function ensureRain(): (Part, ParticleEmitter)
	if rainPart and rainEmitter then
		return rainPart, rainEmitter
	end
	local part = Instance.new("Part")
	part.Name = "NS_Rain"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(80, 1, 80)
	local emitter = Instance.new("ParticleEmitter")
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Speed = NumberRange.new(60, 70)
	emitter.Lifetime = NumberRange.new(0.6, 0.8)
	emitter.Rate = 0
	emitter.Size = NumberSequence.new(0.08)
	emitter.Transparency = NumberSequence.new(0.35)
	emitter.Color = ColorSequence.new(Color3.fromRGB(170, 180, 190))
	emitter.LightEmission = 0.2
	emitter.Parent = part
	part.Parent = workspace
	rainPart, rainEmitter = part, emitter
	return part, emitter
end

local function refresh()
	local weather = currentWeather()
	local rainy = inShift() and (weather == "Rain" or weather == "Storm")
	local reduced = SettingsController:Get("ReducedEffects") == true
	local _, emitter = ensureRain()
	emitter.Rate = if rainy then (if reduced then 120 else 400) else 0
	if rainy then
		AudioController:Play("Rain", nil, { Tag = "WeatherRain" })
	else
		AudioController:Stop("WeatherRain")
	end
	if inShift() then
		AudioController:Play("NightAmbience", nil, { Tag = "NightAmbience" })
	else
		AudioController:Stop("NightAmbience")
	end
end

local function lightning()
	if not inShift() then
		return
	end
	AudioController:Play("Thunder", nil)
	local reduced = SettingsController:Get("ReducedFlashes") == true
	local original = Lighting.Brightness
	-- Clarão curto; com "redução de flashes" é bem mais suave.
	Lighting.Brightness = original + (if reduced then 0.6 else 3)
	task.delay(if reduced then 0.35 else 0.12, function()
		Lighting.Brightness = original
	end)
end

function WeatherController:Init() end

function WeatherController:Start()
	stateFolder = InstanceUtil.waitForChild(ReplicatedStorage, "LightingState", STATE_WAIT_TIMEOUT)
	stateFolder:GetAttributeChangedSignal("Weather"):Connect(refresh)
	stateFolder:GetAttributeChangedSignal("LightningAt"):Connect(lightning)
	Players.LocalPlayer:GetAttributeChangedSignal("State"):Connect(refresh)
	SettingsController.Changed:Connect(refresh)

	local part = ensureRain()
	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if camera and rainEmitter and rainEmitter.Rate > 0 then
			part.Position = camera.CFrame.Position + Vector3.new(0, RAIN_HEIGHT, 0)
		end
	end)
	refresh()
end

return WeatherController
