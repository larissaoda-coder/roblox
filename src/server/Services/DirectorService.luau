--!strict
-- O "diretor" do terror: decide QUANDO algo pode acontecer.
-- A cada minuto do jogo ele olha a fase do turno e a tensão da equipe e, às vezes,
-- pede um evento ao EventService com um limite de intensidade.
-- É isso que faz o começo parecer um turno normal e o final ficar pesado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)

local DirectorConfig = require(script.Parent.Parent.ServerDefinitions.DirectorConfig)

local ClockService = require(script.Parent.ClockService)
local EventService = require(script.Parent.EventService)
local MatchService = require(script.Parent.MatchService)
local TensionService = require(script.Parent.TensionService)

type Stage = DirectorConfig.Stage

local log = Log.new("DirectorService")

local DirectorService = {}

-- (minute, decision) para debug: "Quiet" | "Cooldown" | "Breathing" | "Skipped" | "<EventId>" | "None"
DirectorService.Decision = Signal.new()

local lastEventMinute = -math.huge
local enabled = true
local random = Random.new()

function DirectorService:GetStage(minute: number): Stage
	for _, stage in DirectorConfig.STAGES do
		if minute <= stage.UntilMinute then
			return stage
		end
	end
	return DirectorConfig.STAGES[#DirectorConfig.STAGES]
end

-- Nível máximo de "presença" permitido para a entidade neste momento (usado pelo EntityService).
function DirectorService:GetAllowedIntensity(): number
	return self:GetStage(ClockService:GetMinute()).MaxIntensity
end

-- Liga/desliga o diretor (admin/testes).
function DirectorService:SetEnabled(value: boolean)
	enabled = value
end

local function decide(minute: number): string
	if minute < DirectorConfig.QUIET_MINUTES then
		return "Quiet"
	end
	local stage = DirectorService:GetStage(minute)
	if minute - lastEventMinute < stage.MinGapMinutes then
		return "Cooldown"
	end
	local teamTension = TensionService:GetTeamAverage()
	if teamTension >= DirectorConfig.HIGH_TENSION and minute < 50 then
		return "Breathing"
	end
	local chance = stage.Chance
	if teamTension <= DirectorConfig.LOW_TENSION then
		chance *= DirectorConfig.LOW_TENSION_MULTIPLIER
	end
	if random:NextNumber() > chance then
		return "Skipped"
	end
	local eventId = EventService:TryRandom({ MaxIntensity = stage.MaxIntensity })
	if eventId then
		lastEventMinute = minute
		return eventId
	end
	return "None"
end

local function onMinute(minute: number)
	if not enabled or MatchService:GetPhase() ~= "Shift" then
		return
	end
	local decision = decide(minute)
	log:Debug("Minuto %d: %s", minute, decision)
	DirectorService.Decision:Fire(minute, decision)
end

function DirectorService:Init() end

function DirectorService:Start()
	MatchService.MatchStarted:Connect(function()
		lastEventMinute = -math.huge
	end)
	ClockService.MinuteChanged:Connect(onMinute)
	ClockService.SpecialTime:Connect(function(minute: number)
		if enabled then
			local triggered = EventService:TrySpecial(minute)
			if #triggered > 0 then
				lastEventMinute = minute
			end
		end
	end)
end

return DirectorService
