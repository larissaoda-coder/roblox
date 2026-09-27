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

		HUD_TITLE = "NIGHT SHIFT",
		HUD_OBJECTIVE_LABEL = "OBJECTIVE",
		HUD_LOADING = "PREPARING SHIFT…",
		HUD_BRIEFING = "YOUR SHIFT STARTS NOW",
		HUD_OBJECTIVE_BRIEFING = "Keep the station running until 5 AM.",
		HUD_OBJECTIVE_DEFAULT = "KEEP THE STATION RUNNING",
		HUD_SHIFT_COMPLETE = "SHIFT COMPLETE",

		INTERACT_BUTTON = "INTERACT",
		PROMPT_INTERACT = "Interact",
		PROMPT_OPEN_DOOR = "Open door",
		PROMPT_CLOSE_DOOR = "Close door",
		NOTIFY_DOOR_LOCKED = "It's locked.",

		LOC_STORE = "Store",
		LOC_STOCKROOM = "Stockroom",
		LOC_BACK = "Back of the station",
		LOC_OFFICE = "Office",
		LOC_PUMPS = "Fuel pumps",
		LOC_BATHROOM = "Bathroom",
		LOC_PARKING = "Parking lot",

		TASK_GENERATOR = "Refuel the generator",
		TASK_GENERATOR_DESC = "Grab the fuel can and refuel the generator out back.",
		TASK_RESTOCK = "Restock the shelves",
		TASK_RESTOCK_DESC = "Three shelves in the store are almost empty.",
		TASK_TRASH = "Take out the trash",
		TASK_TRASH_DESC = "Take the trash bag to the dumpster behind the station.",
		TASK_CAMERAS = "Check the recordings",
		TASK_CAMERAS_DESC = "Review the security recordings in the office.",
		TASK_PUMPS = "Check the fuel pumps",
		TASK_PUMPS_DESC = "Make sure all four pumps are working.",
		TASK_BATHROOM = "Clean the bathroom",
		TASK_BATHROOM_DESC = "Someone left a mess in the bathroom.",
		TASK_DELIVERY = "Log the delivery",
		TASK_DELIVERY_DESC = "Count the boxes in the stockroom and sign the delivery sheet.",
		TASK_BACKDOOR = "Lock the back door",
		TASK_BACKDOOR_DESC = "The back door should stay locked after 4:20.",

		PROMPT_TAKE_FUEL = "Take fuel can",
		PROMPT_REFUEL = "Refuel generator",
		PROMPT_RESTOCK = "Restock shelf",
		PROMPT_TAKE_TRASH = "Take trash bag",
		PROMPT_THROW_TRASH = "Throw away",
		PROMPT_CHECK_RECORDINGS = "Check recordings",
		PROMPT_CHECK_PUMP = "Check pump",
		PROMPT_TAKE_MOP = "Take mop",
		PROMPT_CLEAN = "Clean",
		PROMPT_COUNT_BOXES = "Count boxes",
		PROMPT_SIGN = "Sign",
		PROMPT_LOCK = "Lock",

		HUD_TASKS = "TASKS",
		HUD_ALL_TASKS_DONE = "ALL DONE. WAIT FOR THE END OF THE SHIFT",
		NOTIFY_TASK_COMPLETE = "Task complete: %s",
		NOTIFY_NEW_TASK = "New task: %s",
		NOTIFY_TASK_NOT_NOW = "You can't do this right now.",

		NOTIFY_NO_POWER = "There's no power.",
		PROMPT_LIGHT_SWITCH = "Light switch",
		PROMPT_ANSWER_PHONE = "Answer phone",
		PROMPT_VIEW_CAMERAS = "View cameras",
		PROMPT_READ = "Read",

		SUB_THUNDER = "thunder",
		SUB_DOOR_OPEN = "door opening",
		SUB_DOOR_CLOSE = "door closing",
		SUB_DOOR_SLAM = "door slams",
		SUB_LIGHT_BUZZ = "lights buzzing",
		SUB_POWER_DOWN = "power goes out",
		SUB_POWER_UP = "power returns",
		SUB_PRODUCT_FALL = "something falls",
		SUB_PHONE_RING = "phone ringing",
		SUB_PHONE_STATIC = "static on the line",
		SUB_FOOTSTEPS = "footsteps",
		SUB_STOCKROOM_NOISE = "something moving in the stockroom",
		SUB_KNOCK = "knocking",
		SUB_WHISPER = "whispering",
		SUB_DISTANT_SCREAM = "distant scream",
		SUB_BREATHING = "breathing",
		SUB_STINGER = "…",

		CAM_ENTRANCE = "ENTRANCE",
		CAM_COUNTER = "COUNTER",
		CAM_STOCKROOM = "STOCKROOM",
		CAM_PUMPS = "PUMPS",
		CAM_GENERATOR = "GENERATOR",
		CAM_BACK = "BACK",
		CAM_EXIT = "EXIT",
		CAM_NO_SIGNAL = "NO SIGNAL",

		SETTING_MASTER = "Master volume",
		SETTING_MUSIC = "Music",
		SETTING_EFFECTS = "Effects",
		SETTING_SENSITIVITY = "Camera sensitivity",
		SETTING_SUBTITLES = "Subtitles",
		SETTING_REDUCED_FLASHES = "Reduce flashes",
		SETTING_REDUCED_EFFECTS = "Reduced effects",
		SETTING_CAMERA_SHAKE = "Camera shake",

		PHONE_LINE_WRONG_NUMBER = '"Is this Route 44? …Sorry. Wrong number."',
		PHONE_LINE_MANAGER = '"It\'s the manager. Did you lock the back door? …Good. Keep it locked."',
		PHONE_LINE_SILENCE = "(silence… then slow breathing)",
		PHONE_LINE_COUNT = '"How many of you are working tonight? …Are you sure?"',
		PHONE_LINE_DONT_ANSWER = '"You weren\'t supposed to answer."',
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

		HUD_TITLE = "NIGHT SHIFT",
		HUD_OBJECTIVE_LABEL = "OBJETIVO",
		HUD_LOADING = "PREPARANDO TURNO…",
		HUD_BRIEFING = "SEU TURNO COMEÇOU",
		HUD_OBJECTIVE_BRIEFING = "Mantenha o posto funcionando até as 5h.",
		HUD_OBJECTIVE_DEFAULT = "MANTENHA O POSTO FUNCIONANDO",
		HUD_SHIFT_COMPLETE = "TURNO CONCLUÍDO",

		INTERACT_BUTTON = "INTERAGIR",
		PROMPT_INTERACT = "Interagir",
		PROMPT_OPEN_DOOR = "Abrir porta",
		PROMPT_CLOSE_DOOR = "Fechar porta",
		NOTIFY_DOOR_LOCKED = "Está trancada.",

		LOC_STORE = "Loja",
		LOC_STOCKROOM = "Estoque",
		LOC_BACK = "Fundos do posto",
		LOC_OFFICE = "Escritório",
		LOC_PUMPS = "Bombas de combustível",
		LOC_BATHROOM = "Banheiro",
		LOC_PARKING = "Estacionamento",

		TASK_GENERATOR = "Abastecer o gerador",
		TASK_GENERATOR_DESC = "Pegue o galão e abasteça o gerador nos fundos.",
		TASK_RESTOCK = "Repor as prateleiras",
		TASK_RESTOCK_DESC = "Três prateleiras da loja estão quase vazias.",
		TASK_TRASH = "Recolher o lixo",
		TASK_TRASH_DESC = "Leve o saco de lixo até a caçamba atrás do posto.",
		TASK_CAMERAS = "Verificar as gravações",
		TASK_CAMERAS_DESC = "Revise as gravações de segurança no escritório.",
		TASK_PUMPS = "Conferir as bombas",
		TASK_PUMPS_DESC = "Confira se as quatro bombas estão funcionando.",
		TASK_BATHROOM = "Limpar o banheiro",
		TASK_BATHROOM_DESC = "Alguém fez bagunça no banheiro.",
		TASK_DELIVERY = "Registrar a entrega",
		TASK_DELIVERY_DESC = "Conte as caixas no estoque e assine a folha de entrega.",
		TASK_BACKDOOR = "Trancar a porta dos fundos",
		TASK_BACKDOOR_DESC = "A porta dos fundos deve ficar trancada depois das 4:20.",

		PROMPT_TAKE_FUEL = "Pegar galão",
		PROMPT_REFUEL = "Abastecer gerador",
		PROMPT_RESTOCK = "Repor prateleira",
		PROMPT_TAKE_TRASH = "Pegar saco de lixo",
		PROMPT_THROW_TRASH = "Jogar fora",
		PROMPT_CHECK_RECORDINGS = "Verificar gravações",
		PROMPT_CHECK_PUMP = "Conferir bomba",
		PROMPT_TAKE_MOP = "Pegar esfregão",
		PROMPT_CLEAN = "Limpar",
		PROMPT_COUNT_BOXES = "Contar caixas",
		PROMPT_SIGN = "Assinar",
		PROMPT_LOCK = "Trancar",

		HUD_TASKS = "TAREFAS",
		HUD_ALL_TASKS_DONE = "TUDO EM ORDEM. AGUARDE O FIM DO TURNO",
		NOTIFY_TASK_COMPLETE = "Tarefa concluída: %s",
		NOTIFY_NEW_TASK = "Nova tarefa: %s",
		NOTIFY_TASK_NOT_NOW = "Você não pode fazer isso agora.",

		NOTIFY_NO_POWER = "Está sem energia.",
		PROMPT_LIGHT_SWITCH = "Interruptor",
		PROMPT_ANSWER_PHONE = "Atender telefone",
		PROMPT_VIEW_CAMERAS = "Ver câmeras",
		PROMPT_READ = "Ler",

		SUB_THUNDER = "trovão",
		SUB_DOOR_OPEN = "porta abrindo",
		SUB_DOOR_CLOSE = "porta fechando",
		SUB_DOOR_SLAM = "porta batendo",
		SUB_LIGHT_BUZZ = "lâmpadas zumbindo",
		SUB_POWER_DOWN = "a energia cai",
		SUB_POWER_UP = "a energia volta",
		SUB_PRODUCT_FALL = "algo cai",
		SUB_PHONE_RING = "telefone tocando",
		SUB_PHONE_STATIC = "chiado na linha",
		SUB_FOOTSTEPS = "passos",
		SUB_STOCKROOM_NOISE = "algo se mexendo no estoque",
		SUB_KNOCK = "batidas",
		SUB_WHISPER = "sussurros",
		SUB_DISTANT_SCREAM = "grito distante",
		SUB_BREATHING = "respiração",
		SUB_STINGER = "…",

		CAM_ENTRANCE = "ENTRADA",
		CAM_COUNTER = "CAIXA",
		CAM_STOCKROOM = "ESTOQUE",
		CAM_PUMPS = "BOMBAS",
		CAM_GENERATOR = "GERADOR",
		CAM_BACK = "FUNDOS",
		CAM_EXIT = "SAIR",
		CAM_NO_SIGNAL = "SEM SINAL",

		SETTING_MASTER = "Volume geral",
		SETTING_MUSIC = "Música",
		SETTING_EFFECTS = "Efeitos",
		SETTING_SENSITIVITY = "Sensibilidade da câmera",
		SETTING_SUBTITLES = "Legendas",
		SETTING_REDUCED_FLASHES = "Reduzir flashes",
		SETTING_REDUCED_EFFECTS = "Efeitos reduzidos",
		SETTING_CAMERA_SHAKE = "Tremor de câmera",

		PHONE_LINE_WRONG_NUMBER = '"É do posto Rota 44? …Desculpa. Número errado."',
		PHONE_LINE_MANAGER = '"É o gerente. Você trancou a porta dos fundos? …Ótimo. Mantenha trancada."',
		PHONE_LINE_SILENCE = "(silêncio… depois, uma respiração lenta)",
		PHONE_LINE_COUNT = '"Quantos de vocês estão trabalhando hoje? …Tem certeza?"',
		PHONE_LINE_DONT_ANSWER = '"Você não devia ter atendido."',
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
