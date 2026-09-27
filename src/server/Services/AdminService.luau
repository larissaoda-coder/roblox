--!strict
-- Autorização de administradores. Toda ferramenta de admin/debug DEVE perguntar a este serviço.
-- Comandos de admin (dar moeda, disparar evento…) serão adicionados em fases futuras.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local AdminConfig = require(script.Parent.Parent.ServerDefinitions.AdminConfig)

local log = Log.new("AdminService")

local AdminService = {}

function AdminService:IsAdmin(player: Player): boolean
	if table.find(AdminConfig.ADMIN_USER_IDS, player.UserId) then
		return true
	end
	return AdminConfig.STUDIO_PLAYERS_ARE_ADMINS and RunService:IsStudio()
end

function AdminService:CanUseDebug(player: Player): boolean
	return GameConfig.DEBUG_MODE and self:IsAdmin(player)
end

function AdminService:Init()
	Net.Server.handle("RequestDebugAccess", function(player: Player)
		local granted = self:CanUseDebug(player)
		log:Debug("Acesso de debug para %s: %s", player.Name, tostring(granted))
		return { Granted = granted }
	end)
end

function AdminService:Start()
	if #AdminConfig.ADMIN_USER_IDS == 0 then
		log:Debug("ADMIN_USER_IDS está vazio. Adicione seu UserId em ServerDefinitions/AdminConfig.")
	end
end

return AdminService
