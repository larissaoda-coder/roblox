--!strict
-- Quantas tarefas por turno e quando elas aparecem.

local TaskConfig = {
	TASKS_PER_SHIFT = 5,
	-- Tarefas liberadas no início; as demais aparecem ao longo do turno.
	INITIAL_TASKS = 2,
	-- A cada quantos minutos do jogo uma nova tarefa aparece.
	REVEAL_EVERY_MINUTES = 8,
}

return table.freeze(TaskConfig)
