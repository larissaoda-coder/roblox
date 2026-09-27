--!strict
-- Ritmo do terror. O Director roda a cada minuto do jogo e decide se algo acontece.
-- Começo calmo (parece um trabalho normal), escalada no meio, pico perto das 05:00.

export type Stage = {
	UntilMinute: number,
	MaxIntensity: number, -- evento mais forte permitido
	Chance: number, -- chance por minuto de tentar um evento
	MinGapMinutes: number, -- intervalo mínimo entre eventos
}

local DirectorConfig = {
	-- Nenhum evento nos primeiros minutos: o jogador precisa sentir que é um turno normal.
	QUIET_MINUTES = 3,

	STAGES = {
		{ UntilMinute = 10, MaxIntensity = 1, Chance = 0.3, MinGapMinutes = 3 },
		{ UntilMinute = 25, MaxIntensity = 2, Chance = 0.4, MinGapMinutes = 2.5 },
		{ UntilMinute = 45, MaxIntensity = 4, Chance = 0.5, MinGapMinutes = 2 },
		{ UntilMinute = 60, MaxIntensity = 5, Chance = 0.6, MinGapMinutes = 1.5 },
	} :: { Stage },

	-- Tensão média da equipe acima disto = pausa para respirar (sem eventos novos).
	HIGH_TENSION = 70,
	-- Abaixo disto = a equipe está tranquila demais, chance aumenta.
	LOW_TENSION = 20,
	LOW_TENSION_MULTIPLIER = 1.4,
}

return table.freeze(DirectorConfig)
