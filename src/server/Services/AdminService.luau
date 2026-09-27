--!strict
-- Autorização de administradores e comandos de admin/debug.
-- TODA ferramenta de admin passa por aqui, e a lista de admins só existe no servidor (AdminConfig).
--
-- Comandos (Remote AdminCommand):
--   TriggerEvent <EventId>   · GiveCash <n>        · SkipMinutes <n>     · EndShift
--   Entity <Watching|Stalking|Manifest|Hunt>       · Director <true|false>
--   Teleport <Zona>          · Blackout            · Heal

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local AdminConfig = require(script.Parent.Parent.ServerDefinitions.AdminConfig)

local log = Log.new("AdminService")

local AdminService = {}

-- Os serviços abaixo são carregados só quando um comando é usado (evita dependências circulares).
local Services = script.Parent
local function service(name: string): any
	local moduleScript: any = Services:FindFirstChild(name)
	return (require :: any)(moduleScript)
end

function AdminService:IsAdmin(player: Player): boolean
	if table.find(AdminConfig.ADMIN_USER_IDS, player.UserId) then
		return true
	end
	return AdminConfig.STUDIO_PLAYERS_ARE_ADMINS and RunService:IsStudio()
end

function AdminService:CanUseDebug(player: Player): boolean
	return GameConfig.DEBUG_MODE and self:IsAdmin(player)
end

type CommandResult = { Success: boolean, Message: string? }

local COMMANDS: { [string]: (player: Player, argument: any) -> CommandResult } = {
	TriggerEvent = function(_player, eventId)
		local ok = type(eventId) == "string" and service("EventService"):Trigger(eventId)
		return { Success = ok, Message = if ok then `Evento {eventId}` else "Evento indisponível agora" }
	end,
	GiveCash = function(player, amount)
		local value = math.clamp(math.floor(tonumber(amount) or 0), 1, 100000)
		local ok = service("EconomyService"):Grant(player, "Cash", value, "Admin")
		return { Success = ok, Message = `+{value} CASH` }
	end,
	SkipMinutes = function(_player, minutes)
		local value = math.clamp(math.floor(tonumber(minutes) or 1), 1, 60)
		local ok = service("ClockService"):Skip(value)
		return { Success = ok, Message = `+{value} min` }
	end,
	EndShift = function()
		service("MatchService"):AbortMatch()
		return { Success = true, Message = "Turno encerrado" }
	end,
	Entity = function(player, stateName)
		local allowed = { Watching = true, Stalking = true, Manifest = true, Hunt = true }
		if type(stateName) ~= "string" or not allowed[stateName] then
			return { Success = false, Message = "Estado inválido" }
		end
		service("EntityService"):Force(stateName, if stateName == "Hunt" then player else nil)
		return { Success = true, Message = `Entidade: {stateName}` }
	end,
	Director = function(_player, enabled)
		service("DirectorService"):SetEnabled(enabled == true)
		return { Success = true, Message = `Diretor: {tostring(enabled == true)}` }
	end,
	Teleport = function(player, zoneName)
		local zonePart = type(zoneName) == "string" and service("MapService"):GetZonePart(zoneName)
		local character = player.Character
		if not zonePart or not character then
			return { Success = false, Message = "Zona não encontrada (só durante o turno)" }
		end
		character:PivotTo(CFrame.new(zonePart.Position))
		return { Success = true, Message = `Teleportado: {zoneName}` }
	end,
	Blackout = function()
		service("LightingService"):Blackout(15)
		return { Success = true, Message = "Blackout 15s" }
	end,
	Heal = function(player)
		service("TensionService"):Add(player, -100, "Admin")
		return { Success = true, Message = "Tensão zerada" }
	end,
}

function AdminService:RunCommand(player: Player, command: string, argument: any): CommandResult
	if not self:IsAdmin(player) then
		log:Warn("%s tentou usar comando de admin: %s", player.Name, command)
		return { Success = false, Message = "Sem permissão" }
	end
	local handler = COMMANDS[command]
	if not handler then
		return { Success = false, Message = "Comando desconhecido" }
	end
	log:Info("Admin %s: %s %s", player.Name, command, tostring(argument))
	return handler(player, argument)
end

local function debugInfo(player: Player): { [string]: any }?
	if not AdminService:CanUseDebug(player) then
		return nil
	end
	local match = service("MatchService")
	local active = match:GetActiveMatch()
	return {
		Phase = match:GetPhase(),
		Minute = service("ClockService"):GetMinute(),
		Players = if active then #active.Players else 0,
		Alive = #match:GetAlivePlayers(),
		Events = service("EventService"):GetTriggeredCount(),
		Tasks = #service("TaskService"):GetActiveTaskIds(),
		Entity = service("EntityService"):GetState(),
		Temperament = service("EntityService"):GetTemperament(),
		Weather = service("WeatherService"):GetWeather(),
		Tension = math.floor(service("TensionService"):Get(player)),
		Saving = service("DataService"):GetBackendName(),
	}
end

function AdminService:Init()
	Net.Server.handle("RequestDebugAccess", function(player: Player)
		local granted = self:CanUseDebug(player)
		log:Debug("Acesso de debug para %s: %s", player.Name, tostring(granted))
		local eventIds = {}
		if granted then
			-- Só admins recebem a lista de eventos (para o painel de testes).
			for _, definition in
				(require :: any)(script.Parent.Parent.ServerDefinitions.EventDefinitions).getAll()
			do
				if not definition.DiscoveryOnly then
					table.insert(eventIds, definition.Id)
				end
			end
		end
		return { Granted = granted, Admin = self:IsAdmin(player), EventIds = eventIds }
	end)
	Net.Server.handle("GetDebugInfo", debugInfo)
	Net.Server.handle("AdminCommand", function(player: Player, command: string, argument: any)
		return AdminService:RunCommand(player, command, argument)
	end)
end

function AdminService:Start()
	if #AdminConfig.ADMIN_USER_IDS == 0 then
		log:Debug("ADMIN_USER_IDS está vazio. Adicione seu UserId em ServerDefinitions/AdminConfig.")
	end
end

return AdminService
