--!strict
-- Tensão interna de cada jogador (0 a 100). Não aparece como barra: muda sons, cores e eventos.
-- Valores por segundo.

local TensionConfig = {
	TICK_SECONDS = 1,
	MAX = 100,

	ALONE_RADIUS = 28, -- sem colegas dentro deste raio = sozinho

	GAIN_ALONE = 1.2,
	GAIN_DARK = 1.0,
	GAIN_FOREST = 1.5,
	GAIN_OUTDOOR_NIGHT = 0.3,

	DECAY_WITH_TEAM = 1.2,
	DECAY_SAFE_ZONE = 1.6,
	DECAY_LIT_INDOOR = 0.3,

	TASK_COMPLETED_RELIEF = 6,

	-- Sons falsos (só o próprio jogador ouve) quando a tensão está alta e ele está sozinho.
	PHANTOM_THRESHOLD = 60,
	PHANTOM_CHANCE_PER_SECOND = 0.025,
}

return table.freeze(TensionConfig)
