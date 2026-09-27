--!strict
-- Textos exibidos ao jogador, por chave. Nunca escreva texto de UI direto no código:
-- use Strings.get("CHAVE"). Idiomas: "en" (padrão) e "pt".

type StringTable = { [string]: string }

local LANGUAGES: { [string]: StringTable } = {
	en = {
		GAME_TITLE = "NIGHT SHIFT: 4AM",
		DEBUG_OVERLAY = "DEBUG · v%s · %d ms · %d FPS · %s · LVL %d · $%d",
		KICK_DATA_LOAD_FAILED = "We couldn't load your data. Please rejoin in a moment. Your progress is safe.",

		CLOSE = "CLOSE",
		COMING_SOON = "COMING SOON",
		LOBBY_SUBTITLE = "Your shift starts at 4 AM.",

		MENU_PLAY = "PLAY",
		MENU_PROFILE = "PROFILE",
		MENU_SHOP = "SHOP",
		MENU_INVENTORY = "INVENTORY",
		MENU_LEADERBOARD = "LEADERBOARD",
		MENU_SETTINGS = "SETTINGS",
		MENU_CREDITS = "CREDITS",

		MAP_GAS_STATION = "Gas Station",
		MAP_GAS_STATION_DESC = "A lonely gas station by the highway. Nothing ever happens here.",
		MAP_SUPERMARKET = "Supermarket",
		MAP_HOTEL = "Hotel",
		MAP_HOSPITAL = "Hospital",
		MAP_LOCKED_DESC = "Coming soon.",

		PLAY_TITLE = "SHIFTS",
		PLAY_SELECT_MAP = "CHOOSE A LOCATION",
		PLAY_CREATE = "CREATE SHIFT",
		PLAY_OPEN_SHIFTS = "OPEN SHIFTS",
		PLAY_NO_SHIFTS = "No open shifts. Create one.",
		PLAY_JOIN = "JOIN",
		PLAY_FULL = "FULL",
		PLAY_STARTING = "STARTING",
		PLAY_SHIFT_ROW = "%s · %s · %d/%d",

		PARTY_TITLE = "YOUR SHIFT",
		PARTY_READY = "READY",
		PARTY_NOT_READY = "NOT READY",
		PARTY_SET_READY = "I'M READY",
		PARTY_UNSET_READY = "NOT READY",
		PARTY_START = "START SHIFT",
		PARTY_LEAVE = "LEAVE",
		PARTY_HOST = "HOST",
		PARTY_WAITING = "Waiting for everyone to be ready…",
		PARTY_WAITING_HOST = "Waiting for the host to start…",
		PARTY_CHIP = "SHIFT · %s · %d/%d",

		PROFILE_TITLE = "PROFILE",
		PROFILE_LEVEL = "LEVEL %d",
		PROFILE_XP = "XP %d",
		PROFILE_CASH = "CASH %d",
		PROFILE_TOKENS = "NIGHT TOKENS %d",
		STAT_ShiftsCompleted = "Shifts completed",
		STAT_ShiftsSurvived = "Shifts survived",
		STAT_TasksCompleted = "Tasks completed",
		STAT_EventsDiscovered = "Events discovered",
		STAT_SecretsFound = "Secrets found",
		STAT_Deaths = "Deaths",
		STAT_PlayTime = "Time played (min)",
		STAT_CashEarned = "Cash earned",

		CREDITS_TITLE = "CREDITS",
		CREDITS_BODY = "NIGHT SHIFT: 4AM\nA cooperative horror game.\n\nThanks for working the night shift.",

		LOBBY_ERR_NotReady = "Still loading your data.",
		LOBBY_ERR_NotInLobby = "You can't do that right now.",
		LOBBY_ERR_AlreadyInParty = "You're already in a shift.",
		LOBBY_ERR_NotInParty = "You're not in a shift.",
		LOBBY_ERR_PartyNotFound = "That shift no longer exists.",
		LOBBY_ERR_PartyFull = "That shift is full.",
		LOBBY_ERR_PartyLaunching = "That shift is already starting.",
		LOBBY_ERR_InvalidMap = "Invalid location.",
		LOBBY_ERR_MapLocked = "That location is locked.",
		LOBBY_ERR_NotHost = "Only the host can start the shift.",
		LOBBY_ERR_NotAllReady = "Everyone must be ready.",
		LOBBY_ERR_TooManyParties = "Too many open shifts. Join one!",
		LOBBY_ERR_MatchUnavailable = "Shifts can't start yet. Coming in the next update.",
		LOBBY_ERR_ServerBusy = "A shift is already running on this server. Please wait.",
		LOBBY_ERR_RateLimited = "Slow down a little.",
		LOBBY_ERR_Unknown = "Something went wrong. Try again.",
	},
	pt = {
		GAME_TITLE = "NIGHT SHIFT: 4AM",
		DEBUG_OVERLAY = "DEBUG · v%s · %d ms · %d FPS · %s · NÍV %d · $%d",
		KICK_DATA_LOAD_FAILED = "Não conseguimos carregar seus dados. Entre novamente em instantes. Seu progresso está seguro.",

		CLOSE = "FECHAR",
		COMING_SOON = "EM BREVE",
		LOBBY_SUBTITLE = "Seu turno começa às 4 da manhã.",

		MENU_PLAY = "JOGAR",
		MENU_PROFILE = "PERFIL",
		MENU_SHOP = "LOJA",
		MENU_INVENTORY = "INVENTÁRIO",
		MENU_LEADERBOARD = "RANKING",
		MENU_SETTINGS = "CONFIGURAÇÕES",
		MENU_CREDITS = "CRÉDITOS",

		MAP_GAS_STATION = "Posto de Gasolina",
		MAP_GAS_STATION_DESC = "Um posto isolado na beira da estrada. Nunca acontece nada por aqui.",
		MAP_SUPERMARKET = "Supermercado",
		MAP_HOTEL = "Hotel",
		MAP_HOSPITAL = "Hospital",
		MAP_LOCKED_DESC = "Em breve.",

		PLAY_TITLE = "TURNOS",
		PLAY_SELECT_MAP = "ESCOLHA O LOCAL",
		PLAY_CREATE = "CRIAR TURNO",
		PLAY_OPEN_SHIFTS = "TURNOS ABERTOS",
		PLAY_NO_SHIFTS = "Nenhum turno aberto. Crie um.",
		PLAY_JOIN = "ENTRAR",
		PLAY_FULL = "CHEIO",
		PLAY_STARTING = "INICIANDO",
		PLAY_SHIFT_ROW = "%s · %s · %d/%d",

		PARTY_TITLE = "SEU TURNO",
		PARTY_READY = "PRONTO",
		PARTY_NOT_READY = "NÃO PRONTO",
		PARTY_SET_READY = "ESTOU PRONTO",
		PARTY_UNSET_READY = "NÃO ESTOU PRONTO",
		PARTY_START = "INICIAR TURNO",
		PARTY_LEAVE = "SAIR",
		PARTY_HOST = "LÍDER",
		PARTY_WAITING = "Esperando todos ficarem prontos…",
		PARTY_WAITING_HOST = "Esperando o líder iniciar…",
		PARTY_CHIP = "TURNO · %s · %d/%d",

		PROFILE_TITLE = "PERFIL",
		PROFILE_LEVEL = "NÍVEL %d",
		PROFILE_XP = "XP %d",
		PROFILE_CASH = "CASH %d",
		PROFILE_TOKENS = "NIGHT TOKENS %d",
		STAT_ShiftsCompleted = "Turnos concluídos",
		STAT_ShiftsSurvived = "Turnos sobrevividos",
		STAT_TasksCompleted = "Tarefas concluídas",
		STAT_EventsDiscovered = "Eventos descobertos",
		STAT_SecretsFound = "Segredos encontrados",
		STAT_Deaths = "Mortes",
		STAT_PlayTime = "Tempo jogado (min)",
		STAT_CashEarned = "Cash ganho",

		CREDITS_TITLE = "CRÉDITOS",
		CREDITS_BODY = "NIGHT SHIFT: 4AM\nUm jogo cooperativo de terror.\n\nObrigado por trabalhar no turno da noite.",

		LOBBY_ERR_NotReady = "Ainda carregando seus dados.",
		LOBBY_ERR_NotInLobby = "Você não pode fazer isso agora.",
		LOBBY_ERR_AlreadyInParty = "Você já está em um turno.",
		LOBBY_ERR_NotInParty = "Você não está em um turno.",
		LOBBY_ERR_PartyNotFound = "Esse turno não existe mais.",
		LOBBY_ERR_PartyFull = "Esse turno está cheio.",
		LOBBY_ERR_PartyLaunching = "Esse turno já está começando.",
		LOBBY_ERR_InvalidMap = "Local inválido.",
		LOBBY_ERR_MapLocked = "Esse local está bloqueado.",
		LOBBY_ERR_NotHost = "Só o líder pode iniciar o turno.",
		LOBBY_ERR_NotAllReady = "Todos precisam estar prontos.",
		LOBBY_ERR_TooManyParties = "Muitos turnos abertos. Entre em um!",
		LOBBY_ERR_MatchUnavailable = "Os turnos ainda não podem começar. Chega na próxima atualização.",
		LOBBY_ERR_ServerBusy = "Já existe um turno acontecendo neste servidor. Aguarde.",
		LOBBY_ERR_RateLimited = "Calma, vá mais devagar.",
		LOBBY_ERR_Unknown = "Algo deu errado. Tente de novo.",
	},
}

local DEFAULT_LANGUAGE = "en"

local Strings = {}

local currentLanguage = DEFAULT_LANGUAGE

local function resolveLanguage(localeId: string): string
	local language = string.lower(string.sub(localeId, 1, 2))
	return if LANGUAGES[language] then language else DEFAULT_LANGUAGE
end

-- Aceita códigos do Roblox como "pt-br", "en-us".
function Strings.setLocale(localeId: string)
	currentLanguage = resolveLanguage(localeId)
end

function Strings.getLanguage(): string
	return currentLanguage
end

local function lookup(language: string, key: string, ...: any): string
	local text = LANGUAGES[language][key] or LANGUAGES[DEFAULT_LANGUAGE][key]
	if not text then
		return key
	end
	if select("#", ...) == 0 then
		return text
	end
	local ok, formatted = pcall(string.format, text, ...)
	return if ok then formatted else text
end

function Strings.has(key: string): boolean
	return LANGUAGES[DEFAULT_LANGUAGE][key] ~= nil
end

-- Texto no idioma atual (cliente).
function Strings.get(key: string, ...: any): string
	return lookup(currentLanguage, key, ...)
end

-- Texto no idioma de um jogador específico (servidor), ex.: Strings.getForLocale(player.LocaleId, "KEY").
function Strings.getForLocale(localeId: string, key: string, ...: any): string
	return lookup(resolveLanguage(localeId), key, ...)
end

return Strings
