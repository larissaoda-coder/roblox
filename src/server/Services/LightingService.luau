--!strict
-- Iluminação por ZONA. O servidor guarda o estado em ReplicatedStorage > LightingState (atributos)
-- e cada cliente aplica nas luzes com a tag "ShiftLight" (LightingController).
-- Assim uma piscada não gera dezenas de mudanças de propriedade pela rede.
--
-- Estados de zona: "On" | "Off" | "Dim" | "Flicker"
-- Atributos: Zone_<Nome>, Blackout (boolean), FlickerSeed (number)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)

local AudioService = require(script.Parent.AudioService)
local InteractionService = require(script.Parent.InteractionService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)

export type ZoneState = "On" | "Off" | "Dim" | "Flicker"

local VALID_STATES: { ZoneState } = { "On", "Off", "Dim", "Flicker" }

local log = Log.new("LightingService")

local LightingService = {}

-- (zone, newState)
LightingService.ZoneChanged = Signal.new()
-- (isBlackout)
LightingService.BlackoutChanged = Signal.new()

local stateFolder: Folder
local zoneStates: { [string]: ZoneState } = {}
local flickerTokens: { [string]: number } = {}
local blackoutToken = 0

local function setAttribute(zone: string, state: ZoneState)
	zoneStates[zone] = state
	stateFolder:SetAttribute(`Zone_{zone}`, state)
	LightingService.ZoneChanged:Fire(zone, state)
end

function LightingService:GetZones(): { string }
	local zones = {}
	for zone in zoneStates do
		table.insert(zones, zone)
	end
	table.sort(zones)
	return zones
end

function LightingService:GetZoneState(zone: string): ZoneState?
	return zoneStates[zone]
end

function LightingService:IsBlackout(): boolean
	return stateFolder:GetAttribute("Blackout") == true
end

-- Uma zona está escura se houver blackout, se a luz estiver apagada, ou se for a floresta.
function LightingService:IsDark(zone: string): boolean
	if zone == "Forest" or self:IsBlackout() then
		return true
	end
	local state = zoneStates[zone]
	return state == "Off"
end

function LightingService:SetZone(zone: string, state: ZoneState)
	assert(table.find(VALID_STATES, state), `[LightingService] estado inválido: {state}`)
	if zoneStates[zone] == nil then
		log:Warn("Zona sem luzes: %s", zone)
	end
	flickerTokens[zone] = (flickerTokens[zone] or 0) + 1
	setAttribute(zone, state)
end

-- Faz a zona piscar por `duration` segundos e depois volta ao estado anterior.
function LightingService:Flicker(zone: string, duration: number)
	local previous: ZoneState = zoneStates[zone] or "On"
	if previous == "Flicker" then
		previous = "On"
	end
	stateFolder:SetAttribute("FlickerSeed", math.random(1, 1000000))
	self:SetZone(zone, "Flicker")
	local token = flickerTokens[zone]
	task.delay(duration, function()
		if flickerTokens[zone] == token then
			self:SetZone(zone, previous)
		end
	end)
end

-- Apaga tudo (luzes de emergência acendem) por `duration` segundos.
function LightingService:Blackout(duration: number)
	blackoutToken += 1
	local token = blackoutToken
	stateFolder:SetAttribute("Blackout", true)
	LightingService.BlackoutChanged:Fire(true)
	AudioService:PlayAt("PowerDown", nil)
	log:Debug("Blackout por %.1fs", duration)
	task.delay(duration, function()
		if blackoutToken == token then
			self:EndBlackout()
		end
	end)
end

function LightingService:EndBlackout()
	if not self:IsBlackout() then
		return
	end
	blackoutToken += 1
	stateFolder:SetAttribute("Blackout", false)
	LightingService.BlackoutChanged:Fire(false)
	AudioService:PlayAt("PowerUp", nil)
end

local function resetForMap()
	for zone in zoneStates do
		stateFolder:SetAttribute(`Zone_{zone}`, nil)
	end
	table.clear(zoneStates)
	table.clear(flickerTokens)
	blackoutToken += 1
	stateFolder:SetAttribute("Blackout", false)
	local map = MapService:GetActiveMap()
	if not map then
		return
	end
	for _, light in CollectionService:GetTagged("ShiftLight") do
		if light:IsDescendantOf(map) then
			local zone = light:GetAttribute("Zone")
			if type(zone) == "string" and zoneStates[zone] == nil then
				setAttribute(zone, "On")
			end
		end
	end
end

function LightingService:Init()
	local folder = Instance.new("Folder")
	folder.Name = "LightingState"
	folder:SetAttribute("Blackout", false)
	folder:SetAttribute("FlickerSeed", 1)
	folder.Parent = ReplicatedStorage
	stateFolder = folder

	InteractionService:RegisterHandler("LightSwitch", {
		CanInteract = function(_player: Player, target: Instance)
			if LightingService:IsBlackout() then
				return false, "NOTIFY_NO_POWER"
			end
			return type(target:GetAttribute("Zone")) == "string", nil
		end,
		OnInteract = function(_player: Player, target: Instance)
			local zone = target:GetAttribute("Zone") :: string
			local current = zoneStates[zone] or "On"
			LightingService:SetZone(zone, if current == "Off" then "On" else "Off")
			if target:IsA("BasePart") then
				AudioService:PlayAt("LightSwitch", target.Position)
			end
		end,
	})
end

function LightingService:Start()
	MatchService.MatchStarted:Connect(resetForMap)
	MatchService.MatchEnded:Connect(function()
		blackoutToken += 1
		stateFolder:SetAttribute("Blackout", false)
	end)
end

return LightingService
