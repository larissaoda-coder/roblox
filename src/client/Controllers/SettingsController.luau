--!strict
-- Configurações no cliente: carrega do servidor, avisa quem precisa (áudio, luz, câmera) e salva mudanças.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SettingsDefinitions = require(Shared.Definitions.SettingsDefinitions)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local SettingsController = {}

-- (key, value)
SettingsController.Changed = Signal.new()

local values: { [string]: any } = SettingsDefinitions.defaults()

function SettingsController:Get(key: string): any
	return values[key]
end

function SettingsController:GetAll(): { [string]: any }
	return table.clone(values)
end

-- Aplica na hora (local) e salva no servidor.
function SettingsController:Set(key: string, value: any): boolean
	local clean = SettingsDefinitions.sanitize(key, value)
	if clean == nil then
		return false
	end
	values[key] = clean
	SettingsController.Changed:Fire(key, clean)
	task.spawn(function()
		Net.Client.invoke("UpdateSetting", key, clean)
	end)
	return true
end

function SettingsController:Init() end

function SettingsController:Start()
	local player = Players.LocalPlayer
	local startedAt = os.clock()
	while player:GetAttribute("Ready") ~= true and os.clock() - startedAt < 30 do
		task.wait(0.1)
	end
	local ok, saved = Net.Client.invoke("GetSettings")
	if ok and type(saved) == "table" then
		for key, value in saved do
			local clean = SettingsDefinitions.sanitize(key, value)
			if clean ~= nil and values[key] ~= clean then
				values[key] = clean
				SettingsController.Changed:Fire(key, clean)
			end
		end
	end
end

return SettingsController
