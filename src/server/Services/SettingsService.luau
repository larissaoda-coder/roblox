--!strict
-- Configurações do jogador (volume, legendas, acessibilidade). Salvas no perfil pelo DataService.
-- O cliente pede mudanças; o servidor valida e limita os valores (SettingsDefinitions).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SettingsDefinitions = require(Shared.Definitions.SettingsDefinitions)
local Net = require(Shared.Modules.Net)

local DataService = require(script.Parent.DataService)

local SettingsService = {}

function SettingsService:Get(player: Player): { [string]: any }
	local values = SettingsDefinitions.defaults()
	local saved = DataService:Get(player, "Settings")
	if type(saved) == "table" then
		for key, value in saved do
			local clean = SettingsDefinitions.sanitize(key, value)
			if clean ~= nil then
				values[key] = clean
			end
		end
	end
	return values
end

function SettingsService:Init()
	Net.Server.handle("GetSettings", function(player: Player)
		return SettingsService:Get(player)
	end)
	Net.Server.handle("UpdateSetting", function(player: Player, key: string, value: any)
		local clean = SettingsDefinitions.sanitize(key, value)
		if clean == nil then
			return { Success = false, Error = "InvalidSetting" }
		end
		local ok = DataService:Update(player, "Settings", function(settings)
			settings[key] = clean
			return settings
		end)
		return { Success = ok, Value = clean }
	end)
end

return SettingsService
