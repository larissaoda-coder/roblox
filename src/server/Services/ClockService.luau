--!strict
-- Relógio do turno (04:00 → 05:00). O minuto atual fica no atributo GameMinute de ReplicatedStorage > MatchState,
-- que todos os clientes leem para mostrar a hora no HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MatchConfig = require(Shared.Config.MatchConfig)
local GameClock = require(Shared.Modules.GameClock)
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)

local log = Log.new("ClockService")

local ClockService = {}

-- (gameMinute) a cada minuto do jogo.
ClockService.MinuteChanged = Signal.new()
-- (gameMinute) nos horários especiais (04:17, 04:33, 04:44).
ClockService.SpecialTime = Signal.new()

local currentMinute = 0
local running = false

function ClockService:GetMinute(): number
	return currentMinute
end

function ClockService:IsRunning(): boolean
	return running
end

-- Roda o relógio do minuto 0 até o fim do turno. Bloqueia (espera) até terminar.
-- `shouldStop` é consultado a cada minuto; se retornar true, o relógio para antes do fim.
-- Retorna true se o turno chegou ao fim normalmente.
function ClockService:Run(state: Instance, shouldStop: () -> boolean): boolean
	assert(not running, "[ClockService] relógio já está rodando")
	running = true
	currentMinute = 0
	state:SetAttribute("GameMinute", 0)
	state:SetAttribute("ShiftGameMinutes", MatchConfig.SHIFT_GAME_MINUTES)
	ClockService.MinuteChanged:Fire(0)

	local completed = false
	while not shouldStop() do
		-- Espera o minuto em pedaços curtos para reagir rápido se a partida for encerrada.
		local deadline = os.clock() + MatchConfig.REAL_SECONDS_PER_GAME_MINUTE
		while os.clock() < deadline and not shouldStop() do
			task.wait(math.min(0.25, deadline - os.clock()))
		end
		if shouldStop() then
			break
		end
		currentMinute += 1
		state:SetAttribute("GameMinute", currentMinute)
		ClockService.MinuteChanged:Fire(currentMinute)
		if table.find(MatchConfig.SPECIAL_MINUTES, currentMinute) then
			log:Debug("Horário especial: %s", GameClock.format(currentMinute))
			ClockService.SpecialTime:Fire(currentMinute)
		end
		if currentMinute >= MatchConfig.SHIFT_GAME_MINUTES then
			completed = true
			break
		end
	end

	running = false
	return completed
end

function ClockService:Init() end

return ClockService
