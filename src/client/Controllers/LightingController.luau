--!strict
-- Aplica localmente o estado de luz de cada zona (ReplicatedStorage > LightingState).
-- Piscadas usam uma seed vinda do servidor: todos veem um padrão parecido, sem tráfego de rede.
-- Com "Redução de flashes" ativa, as piscadas viram pulsos lentos (acessibilidade).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local InstanceUtil = require(Shared.Modules.InstanceUtil)

local SettingsController = require(script.Parent.SettingsController)

local STATE_WAIT_TIMEOUT = 30

local LightingController = {}

local stateFolder: Instance
local flickerThreads: { [string]: number } = {}

local function lightOf(fixture: Instance): Light?
	return fixture:FindFirstChildWhichIsA("Light") :: Light?
end

local function setFixture(fixture: BasePart, level: number)
	local light = lightOf(fixture)
	local base = fixture:GetAttribute("BaseBrightness")
	local baseBrightness = if type(base) == "number" then base else 1
	if light then
		light.Enabled = level > 0
		light.Brightness = baseBrightness * level
	end
	fixture.Material = if level > 0.5 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

local function fixturesInZone(zone: string): { BasePart }
	local list = {}
	local runtime = workspace:FindFirstChild("Runtime")
	for _, fixture in CollectionService:GetTagged("ShiftLight") do
		if
			fixture:IsA("BasePart")
			and fixture:GetAttribute("Zone") == zone
			and (not runtime or fixture:IsDescendantOf(runtime))
		then
			table.insert(list, fixture)
		end
	end
	return list
end

local function zoneLevel(state: string?): number
	if stateFolder:GetAttribute("Blackout") == true or state == "Off" then
		return 0
	elseif state == "Dim" then
		return 0.35
	end
	return 1
end

local function startFlicker(zone: string)
	flickerThreads[zone] = (flickerThreads[zone] or 0) + 1
	local token = flickerThreads[zone]
	local seed = tonumber(stateFolder:GetAttribute("FlickerSeed")) or 1
	local random = Random.new(seed + #zone)
	task.spawn(function()
		while flickerThreads[zone] == token do
			local reduced = SettingsController:Get("ReducedFlashes") == true
			local level = if reduced
				then random:NextNumber(0.45, 1)
				else (if random:NextNumber() < 0.45 then 0 else 1)
			for _, fixture in fixturesInZone(zone) do
				setFixture(fixture, level)
			end
			task.wait(if reduced then random:NextNumber(0.6, 1.2) else random:NextNumber(0.04, 0.25))
		end
	end)
end

local function applyZone(zone: string)
	local state = stateFolder:GetAttribute(`Zone_{zone}`)
	flickerThreads[zone] = (flickerThreads[zone] or 0) + 1
	if state == "Flicker" and stateFolder:GetAttribute("Blackout") ~= true then
		startFlicker(zone)
		return
	end
	local level = zoneLevel(if type(state) == "string" then state else nil)
	for _, fixture in fixturesInZone(zone) do
		setFixture(fixture, level)
	end
end

local function applyEmergency()
	local on = stateFolder:GetAttribute("Blackout") == true
	for _, lamp in CollectionService:GetTagged("EmergencyLight") do
		local light = lightOf(lamp)
		if light then
			light.Enabled = on
		end
		if lamp:IsA("BasePart") then
			lamp.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

local function applyAll()
	for name in stateFolder:GetAttributes() do
		local zone = string.match(name, "^Zone_(.+)$")
		if zone then
			applyZone(zone)
		end
	end
	applyEmergency()
end

function LightingController:Init() end

function LightingController:Start()
	stateFolder = InstanceUtil.waitForChild(ReplicatedStorage, "LightingState", STATE_WAIT_TIMEOUT)
	stateFolder.AttributeChanged:Connect(function(name: string)
		local zone = string.match(name, "^Zone_(.+)$")
		if zone then
			applyZone(zone)
		elseif name == "Blackout" then
			applyAll()
		end
	end)
	-- Luzes de um mapa recém-carregado recebem o estado atual.
	CollectionService:GetInstanceAddedSignal("ShiftLight"):Connect(function(fixture: Instance)
		local zone = fixture:GetAttribute("Zone")
		if type(zone) == "string" then
			task.defer(applyZone, zone)
		end
	end)
	applyAll()
end

return LightingController
