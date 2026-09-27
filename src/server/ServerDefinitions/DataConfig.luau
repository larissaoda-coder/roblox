--!strict
-- Estrutura dos dados salvos de cada jogador.
-- Para adicionar um campo novo: adicione aqui com o valor inicial. Perfis antigos recebem o campo automaticamente.
-- NUNCA renomeie ou remova um campo sem uma migração (isso apagaria dados de jogadores).

local TableUtil = require(game:GetService("ReplicatedStorage").Shared.Modules.TableUtil)

local DataConfig = {
	SCHEMA_VERSION = 1,

	-- "Memory": dados ficam só enquanto o servidor estiver aberto (Fase 2).
	-- "DataStore": salvamento real (Fase 13).
	BACKEND = "Memory" :: "Memory" | "DataStore",

	AUTOSAVE_INTERVAL = 180,

	-- Campos copiados para atributos do Player (o cliente pode ler, mas não alterar).
	PUBLIC_ATTRIBUTES = { "Level", "XP", "Cash", "NightTokens" },

	TEMPLATE = {
		SchemaVersion = 1,

		Level = 1,
		XP = 0,
		Cash = 0,
		NightTokens = 0,

		Stats = {
			ShiftsCompleted = 0,
			ShiftsSurvived = 0,
			TasksCompleted = 0,
			EventsDiscovered = 0,
			SecretsFound = 0,
			Deaths = 0,
			PlayTime = 0,
			CashEarned = 0,
		},

		Discoveries = {} :: { [string]: number }, -- EventId → os.time() da primeira descoberta
		Inventory = {
			Owned = {} :: { [string]: boolean },
			Equipped = {} :: { [string]: string },
		},
		Titles = {} :: { [string]: boolean },
		Badges = {} :: { [string]: boolean },
		UnlockedMaps = { GasStation = true } :: { [string]: boolean },

		Settings = {
			MasterVolume = 1,
			MusicVolume = 0.6,
			EffectsVolume = 1,
			Sensitivity = 0.5,
			ReducedEffects = false,
			ReducedFlashes = false,
			CameraShake = true,
			Subtitles = true,
		},

		Purchases = {} :: { [string]: number }, -- PurchaseId → os.time() (evita entregar a mesma compra duas vezes)

		FirstJoin = 0,
		LastJoin = 0,
	},
}

TableUtil.deepFreeze(DataConfig)

return DataConfig
