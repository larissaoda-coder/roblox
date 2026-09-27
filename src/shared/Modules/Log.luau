--!strict
-- Logger central. Debug só aparece com GameConfig.DEBUG_MODE = true.
-- Uso: local log = Log.new("TaskService"); log:Info("Tarefa %s concluída", taskId)

local RunService = game:GetService("RunService")

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local Signal = require(script.Parent.Signal)

export type Level = "Debug" | "Info" | "Warn" | "Error"

export type Entry = {
	Time: number,
	Level: Level,
	Source: string,
	Message: string,
}

export type Logger = {
	Source: string,
	Debug: (self: Logger, message: string, ...any) -> (),
	Info: (self: Logger, message: string, ...any) -> (),
	Warn: (self: Logger, message: string, ...any) -> (),
	Error: (self: Logger, message: string, ...any) -> (),
}

local HISTORY_SIZE = 200
local SIDE = if RunService:IsServer() then "Server" else "Client"

local Log = {}

-- Últimas mensagens (para o painel de debug/admin no futuro).
Log.History = {} :: { Entry }
Log.Added = Signal.new()

local function format(message: string, ...: any): string
	if select("#", ...) == 0 then
		return message
	end
	local ok, formatted = pcall(string.format, message, ...)
	return if ok then formatted else message
end

local function write(source: string, level: Level, message: string, ...: any)
	if level == "Debug" and not GameConfig.DEBUG_MODE then
		return
	end

	local text = format(message, ...)
	local line = `[NS][{SIDE}][{source}] {text}`

	if level == "Warn" then
		warn(line)
	elseif level == "Error" then
		warn(`{line} (ERRO)`)
	else
		print(line)
	end

	local entry: Entry = { Time = os.time(), Level = level, Source = source, Message = text }
	table.insert(Log.History, entry)
	if #Log.History > HISTORY_SIZE then
		table.remove(Log.History, 1)
	end
	Log.Added:Fire(entry)
end

function Log.new(source: string): Logger
	local logger = { Source = source } :: Logger

	function logger:Debug(message: string, ...: any)
		write(source, "Debug", message, ...)
	end
	function logger:Info(message: string, ...: any)
		write(source, "Info", message, ...)
	end
	function logger:Warn(message: string, ...: any)
		write(source, "Warn", message, ...)
	end
	function logger:Error(message: string, ...: any)
		write(source, "Error", message, ...)
	end

	return logger
end

return Log
