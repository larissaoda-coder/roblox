--!strict
-- Clima do turno: sorteado a cada partida. Afeta neblina (visibilidade), sons e raios.
-- O estado fica em ReplicatedStorage > LightingState (atributos Weather e LightningAt);
-- chuva, raios e sons são desenhados no cliente (WeatherController).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Modules.Log)
local Rng = require(Shared.Modules.Rng)

local MatchService = require(script.Parent.MatchService)

export type Weather = "Clear" | "Fog" | "Rain" | "Storm"

type Preset = { Weight: number, Density: number, Haze: number, FogEnd: number }

local PRESETS: { [Weather]: Preset } = {
	Clear = { Weight = 45, Density = 0.25, Haze = 0.5, FogEnd = 900 },
	Fog = { Weight = 30, Density = 0.55, Haze = 2.5, FogEnd = 220 },
	Rain = { Weight = 20, Density = 0.42, Haze = 1.5, FogEnd = 420 },
	Storm = { Weight = 5, Density = 0.5, Haze = 2, FogEnd = 320 },
}
local ORDER: { Weather } = { "Clear", "Fog", "Rain", "Storm" }

local LOBBY_PRESET: Preset = { Weight = 0, Density = 0.3, Haze = 0.5, FogEnd = 1000 }
local LIGHTNING_MIN_SECONDS = 20
local LIGHTNING_MAX_SECONDS = 55

local log = Log.new("WeatherService")

local WeatherService = {}

local current: Weather = "Clear"
local matchToken = 0

local function stateFolder(): Instance?
	return ReplicatedStorage:FindFirstChild("LightingState")
end

local function getAtmosphere(): Atmosphere
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	return atmosphere :: Atmosphere
end

local function applyPreset(preset: Preset)
	local atmosphere = getAtmosphere()
	atmosphere.Density = preset.Density
	atmosphere.Haze = preset.Haze
	atmosphere.Color = Color3.fromRGB(40, 44, 52)
	atmosphere.Decay = Color3.fromRGB(20, 22, 28)
	Lighting.FogEnd = preset.FogEnd
	Lighting.FogColor = Color3.fromRGB(18, 20, 24)
end

function WeatherService:GetWeather(): Weather
	return current
end

function WeatherService:SetWeather(weather: Weather)
	current = weather
	applyPreset(PRESETS[weather])
	local folder = stateFolder()
	if folder then
		folder:SetAttribute("Weather", weather)
	end
	log:Debug("Clima: %s", weather)
end

local function runLightning(token: number)
	local random = Random.new()
	while matchToken == token and current == "Storm" do
		task.wait(random:NextNumber(LIGHTNING_MIN_SECONDS, LIGHTNING_MAX_SECONDS))
		if matchToken ~= token then
			return
		end
		local folder = stateFolder()
		if folder then
			folder:SetAttribute("LightningAt", workspace:GetServerTimeNow())
		end
	end
end

function WeatherService:Init()
	applyPreset(LOBBY_PRESET)
end

function WeatherService:Start()
	MatchService.MatchStarted:Connect(function()
		matchToken += 1
		local rng = Rng.new()
		local picked = rng:WeightedPick((ORDER :: any) :: { string }, function(name: string)
			return PRESETS[name :: Weather].Weight
		end)
		local weather: Weather = (picked or "Clear") :: Weather
		self:SetWeather(weather)
		if weather == "Storm" then
			task.spawn(runLightning, matchToken)
		end
	end)
	MatchService.MatchEnded:Connect(function()
		matchToken += 1
		current = "Clear"
		applyPreset(LOBBY_PRESET)
		local folder = stateFolder()
		if folder then
			folder:SetAttribute("Weather", "Clear")
		end
	end)
end

return WeatherService
