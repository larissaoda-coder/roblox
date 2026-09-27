--!strict
-- Configuração global do jogo. Lida pelo servidor e pelo cliente.
-- NÃO coloque aqui nada secreto: este módulo é visível para qualquer jogador.

local GameConfig = {
	GAME_NAME = "NIGHT SHIFT: 4AM",
	GAME_VERSION = "0.9.0",

	-- true: mostra logs de debug e o painel de debug (somente para admins).
	-- Mude para false antes de publicar.
	DEBUG_MODE = true,

	-- "Local": lobby e mapa no mesmo place (Studio / MVP).
	-- "Teleport": places separados com servidores reservados (produção, Fase 21).
	LAUNCH_MODE = "Local" :: "Local" | "Teleport",

	MAX_PLAYERS_PER_SHIFT = 4,

	-- Tempo máximo (segundos) que o cliente espera pelos Remotes do servidor.
	REMOTES_WAIT_TIMEOUT = 20,
}

return table.freeze(GameConfig)
