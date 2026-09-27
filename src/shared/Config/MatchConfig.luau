--!strict
-- Ritmo da partida. O relógio do jogo vai de 04:00 até 05:00.
-- 60 minutos do jogo × 15 segundos = 15 minutos reais.

local MatchConfig = {
	START_HOUR = 4,
	SHIFT_GAME_MINUTES = 60,
	REAL_SECONDS_PER_GAME_MINUTE = 15,

	BRIEFING_SECONDS = 10,
	RESULTS_SECONDS = 10,

	-- Horários especiais (minutos depois das 04:00). Eventos poderão exigir estes horários (Fase 8).
	SPECIAL_MINUTES = { 17, 33, 44 },
}

return table.freeze(MatchConfig)
