--!strict
-- Mostra a tela de resultados quando o servidor envia as recompensas do turno.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Net = require(Shared.Modules.Net)

local ResultsScreen = require(script.Parent.Parent.UI.Screens.ResultsScreen)
local AudioController = require(script.Parent.AudioController)

local ResultsController = {}

local screen: ResultsScreen.ResultsScreen? = nil
local lastResult: { [string]: any }? = nil

function ResultsController:GetLastResult(): { [string]: any }?
	return lastResult
end

function ResultsController:GetScreen(): ResultsScreen.ResultsScreen?
	return screen
end

function ResultsController:Init() end

function ResultsController:Start()
	local results = ResultsScreen.new(InstanceUtil.waitForChild(Players.LocalPlayer, "PlayerGui"), function()
		if screen then
			screen:Hide()
		end
	end)
	screen = results
	Net.Client.on("ShiftResults", function(result)
		if type(result) ~= "table" then
			return
		end
		lastResult = result
		AudioController:Play("TaskComplete", nil)
		results:Show(result)
	end)
end

return ResultsController
