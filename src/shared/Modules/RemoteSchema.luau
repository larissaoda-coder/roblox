--!strict
-- LISTA ÚNICA de todos os Remotes do jogo. O servidor cria os objetos a partir daqui.
-- Nunca crie RemoteEvents/RemoteFunctions manualmente no Explorer.
--
-- Kind:
--   "Event"    → RemoteEvent. Direction diz quem envia.
--   "Function" → RemoteFunction, SEMPRE cliente → servidor (o servidor nunca espera resposta do cliente).
-- RateLimit: máximo de chamadas por jogador (Max a cada Per segundos). Obrigatório para cliente → servidor.
-- Args: validadores de cada argumento, em ordem. Argumentos extras são rejeitados.

local T = require(script.Parent.Net.T)

export type RemoteSpec = {
	Kind: "Event" | "Function",
	Direction: "ClientToServer" | "ServerToClient",
	RateLimit: { Max: number, Per: number }?,
	Args: { T.Validator }?,
}

local RemoteSchema: { [string]: RemoteSpec } = {
	-- Núcleo --------------------------------------------------------------
	Ping = {
		Kind = "Function",
		Direction = "ClientToServer",
		RateLimit = { Max = 2, Per = 1 },
		Args = {},
	},

	-- Jogador ---------------------------------------------------------------
	GetMyProfile = {
		Kind = "Function",
		Direction = "ClientToServer",
		RateLimit = { Max = 3, Per = 3 },
		Args = {},
	},

	-- Lobby -----------------------------------------------------------------
	RequestLobbyState = {
		Kind = "Function",
		Direction = "ClientToServer",
		RateLimit = { Max = 4, Per = 5 },
		Args = {},
	},
	LobbyStateChanged = {
		Kind = "Event",
		Direction = "ServerToClient",
	},
	CreateParty = {
		Kind = "Function",
		Direction = "ClientToServer",
		RateLimit = { Max = 3, Per = 5 },
		Args = { T.string(32) }, -- mapId
	},
	JoinParty = {
		Kind = "Function",
		Direction = "ClientToServer",
		RateLimit = { Max = 5, Per = 5 },
		Args = { T.string(16) }, -- partyId
	},
	LeaveParty = {
		Kind = "Function",
		Direction = "ClientToServer",
		RateLimit = { Max = 5, Per = 5 },
		Args = {},
	},
	SetReady = {
		Kind = "Function",
		Direction = "ClientToServer",
		RateLimit = { Max = 6, Per = 5 },
		Args = { T.boolean() },
	},
	StartParty = {
		Kind = "Function",
		Direction = "ClientToServer",
		RateLimit = { Max = 3, Per = 5 },
		Args = {},
	},

	-- Admin / Debug -------------------------------------------------------
	RequestDebugAccess = {
		Kind = "Function",
		Direction = "ClientToServer",
		RateLimit = { Max = 1, Per = 5 },
		Args = {},
	},
}

return table.freeze(RemoteSchema)
