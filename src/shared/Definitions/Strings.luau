--!strict
-- Textos exibidos ao jogador, por chave. Nunca escreva texto de UI direto no código:
-- use Strings.get("CHAVE"). Idiomas: "en" (padrão) e "pt".

type StringTable = { [string]: string }

local LANGUAGES: { [string]: StringTable } = {
	en = {
		GAME_TITLE = "NIGHT SHIFT: 4AM",
		DEBUG_OVERLAY = "DEBUG · v%s · %d ms · %d FPS",
	},
	pt = {
		GAME_TITLE = "NIGHT SHIFT: 4AM",
		DEBUG_OVERLAY = "DEBUG · v%s · %d ms · %d FPS",
	},
}

local DEFAULT_LANGUAGE = "en"

local Strings = {}

local currentLanguage = DEFAULT_LANGUAGE

-- Aceita códigos do Roblox como "pt-br", "en-us".
function Strings.setLocale(localeId: string)
	local language = string.lower(string.sub(localeId, 1, 2))
	currentLanguage = if LANGUAGES[language] then language else DEFAULT_LANGUAGE
end

function Strings.getLanguage(): string
	return currentLanguage
end

function Strings.get(key: string, ...: any): string
	local text = LANGUAGES[currentLanguage][key] or LANGUAGES[DEFAULT_LANGUAGE][key]
	if not text then
		return key
	end
	if select("#", ...) == 0 then
		return text
	end
	local ok, formatted = pcall(string.format, text, ...)
	return if ok then formatted else text
end

return Strings
