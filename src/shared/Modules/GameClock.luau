--!strict
-- Converte "minutos desde o início do turno" em texto de relógio (ex.: 17 → "04:17 AM").

local MatchConfig = require(script.Parent.Parent.Config.MatchConfig)

local GameClock = {}

function GameClock.format(gameMinute: number): string
	local totalMinutes = MatchConfig.START_HOUR * 60 + math.max(0, math.floor(gameMinute))
	local hour24 = (totalMinutes // 60) % 24
	local minute = totalMinutes % 60
	local suffix = if hour24 < 12 then "AM" else "PM"
	local hour12 = hour24 % 12
	if hour12 == 0 then
		hour12 = 12
	end
	return string.format("%02d:%02d %s", hour12, minute, suffix)
end

return GameClock
