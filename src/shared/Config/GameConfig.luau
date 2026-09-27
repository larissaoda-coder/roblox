--!strict
-- Configuração global do jogo. Lida pelo servidor e pelo cliente.
-- NÃO coloque aqui nada secreto: este módulo é visível para qualquer jogador.

local GameConfig = {
	GAME_NAME = "NIGHT SHIFT: 4AM",
	GAME_VERSION = "0.21.0",

	-- true: mostra logs de debug e o painel de debug (somente para admins).
	-- Mude para false antes de publicar.
	DEBUG_MODE = true,

	-- "Local": lobby e mapa no mesmo place (Studio / MVP).
	-- "Teleport": places separados com servidores reservados (produção, Fase 21).
	LAUNCH_MODE = "Local" :: "Local" | "Teleport",

	-- IDs dos places para o modo "Teleport" (create.roblox.com > seu jogo > Places).
	-- Troque "PLACE_ID_HERE" pelos números. Enquanto forem texto, o jogo usa o modo Local.
	PLACE_IDS = {
		Lobby = "PLACE_ID_HERE",
		Shift = "PLACE_ID_HERE",
	},

	-- Quanto tempo o servidor do turno espera a equipe chegar pelo teleporte.
	TELEPORT_ARRIVAL_TIMEOUT = 25,

	MAX_PLAYERS_PER_SHIFT = 4,

	-- Tempo máximo (segundos) que o cliente espera pelos Remotes do servidor.
	REMOTES_WAIT_TIMEOUT = 20,
}

return table.freeze(GameConfig)
