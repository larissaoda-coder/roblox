--!strict
-- Textos exibidos ao jogador, por chave. Nunca escreva texto de UI direto no código:
-- use Strings.get("CHAVE"). Idiomas: "en" (padrão) e "pt".

type StringTable = { [string]: string }

local LANGUAGES: { [string]: StringTable } = {
	en = {
		GAME_TITLE = "NIGHT SHIFT: 4AM",
		DEBUG_OVERLAY = "DEBUG · v%s · %d ms · %d FPS · %s · LVL %d · $%d",
		KICK_DATA_LOAD_FAILED = "We couldn't load your data. Please rejoin in a moment. Your progress is safe.",
	},
	pt = {
		GAME_TITLE = "NIGHT SHIFT: 4AM",
		DEBUG_OVERLAY = "DEBUG · v%s · %d ms · %d FPS · %s · NÍV %d · $%d",
		KICK_DATA_LOAD_FAILED = "Não conseguimos carregar seus dados. Entre novamente em instantes. Seu progresso está seguro.",
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

-- Texto no idioma atual (cliente).
function Strings.get(key: string, ...: any): string
	return lookup(currentLanguage, key, ...)
end

-- Texto no idioma de um jogador específico (servidor), ex.: Strings.getForLocale(player.LocaleId, "KEY").
function Strings.getForLocale(localeId: string, key: string, ...: any): string
	return lookup(resolveLanguage(localeId), key, ...)
end

return Strings
