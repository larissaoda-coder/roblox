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

	GetSettings = {
		Kind = "Function",
		Direction = "ClientToServer",
		RateLimit = { Max = 3, Per = 5 },
		Args = {},
	},
	UpdateSetting = {
		Kind = "Function",
		Direction = "ClientToServer",
		RateLimit = { Max = 10, Per = 2 },
		Args = { T.string(32), T.oneOfTypes({ "number", "boolean" }) },
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

	-- Tarefas ---------------------------------------------------------------
	RequestTasks = {
		Kind = "Function",
		Direction = "ClientToServer",
		RateLimit = { Max = 3, Per = 5 },
		Args = {},
	},
	-- ({ tarefas }) lista das tarefas liberadas e seu progresso.
	TasksChanged = {
		Kind = "Event",
		Direction = "ServerToClient",
	},
	-- (taskId, isNew) tarefa concluída (isNew = false) ou nova tarefa liberada (isNew = true).
	TaskNotice = {
		Kind = "Event",
		Direction = "ServerToClient",
	},

	-- Áudio -----------------------------------------------------------------
	-- (soundName, position | nil, options) toca um som (posicional ou 2D) no cliente.
	PlaySound = {
		Kind = "Event",
		Direction = "ServerToClient",
	},
	-- (soundName) para um som em loop.
	StopSound = {
		Kind = "Event",
		Direction = "ServerToClient",
	},

	-- Percepção (efeitos que só um jogador vê/ouve) ---------------------------
	-- (kind, data) kind = "Sound" | "Figure" | "FakeDoor"
	Perception = {
		Kind = "Event",
		Direction = "ServerToClient",
	},

	-- Câmeras de segurança ---------------------------------------------------
	-- ({ câmeras }) abre o monitor no cliente.
	CameraFeedOpened = {
		Kind = "Event",
		Direction = "ServerToClient",
	},
	-- () o servidor fechou o monitor (ex.: jogador se afastou).
	CameraFeedClosed = {
		Kind = "Event",
		Direction = "ServerToClient",
	},
	SetCameraView = {
		Kind = "Event",
		Direction = "ClientToServer",
		RateLimit = { Max = 8, Per = 2 },
		Args = { T.integer(1, 32) },
	},
	CloseCameraFeed = {
		Kind = "Event",
		Direction = "ClientToServer",
		RateLimit = { Max = 4, Per = 2 },
		Args = {},
	},
	-- (cameraId, anomalyType, data, duration) algo aparece numa câmera.
	CameraAnomaly = {
		Kind = "Event",
		Direction = "ServerToClient",
	},

	-- Diálogos e documentos -----------------------------------------------------
	-- ({ SpeakerKey, TextKey, Choices = { TextKey } } | nil) nó atual; nil = conversa encerrada.
	DialogueNode = {
		Kind = "Event",
		Direction = "ServerToClient",
	},
	DialogueChoice = {
		Kind = "Event",
		Direction = "ClientToServer",
		RateLimit = { Max = 6, Per = 2 },
		Args = { T.integer(1, 6) },
	},
	-- (documentId) abre o documento na tela.
	ShowDocument = {
		Kind = "Event",
		Direction = "ServerToClient",
	},

	-- Notificações -----------------------------------------------------------
	-- (textKey: string, ...args) mensagem curta na tela do jogador.
	Notify = {
		Kind = "Event",
		Direction = "ServerToClient",
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
