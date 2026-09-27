--!strict
-- Economia: quanto XP/CASH cada coisa vale e a curva de níveis.
-- O cliente pode LER (para mostrar), mas quem calcula e concede é SEMPRE o servidor.

local EconomyConfig = {
	MAX_LEVEL = 100,

	-- XP necessário para passar do nível N para N+1: BASE + (N-1) * STEP
	XP_BASE = 100,
	XP_STEP = 50,

	SHIFT_COMPLETE_XP = 60,
	SHIFT_COMPLETE_CASH = 40,
	SURVIVAL_BONUS_XP = 30,
	SURVIVAL_BONUS_CASH = 30,
	-- Evento visto pela primeira vez na vida.
	NEW_DISCOVERY_XP = 40,
	NEW_DISCOVERY_CASH = 20,
	-- Evento já conhecido, visto de novo.
	DISCOVERY_XP = 10,
	CUSTOMER_SERVED_CASH = 6,
	-- Turno fracassado: só uma parte das recompensas de tarefa.
	FAILED_TASK_MULTIPLIER = 0.3,

	-- Limite de segurança por concessão (anti-bug/anti-exploit).
	MAX_GRANT = 100000,
}

function EconomyConfig.xpForLevel(level: number): number
	return EconomyConfig.XP_BASE + (level - 1) * EconomyConfig.XP_STEP
end

return table.freeze(EconomyConfig)
