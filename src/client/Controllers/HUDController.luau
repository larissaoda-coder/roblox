--!strict
-- Mostra o HUD durante o turno, lendo o estado público da partida (ReplicatedStorage > MatchState).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Definitions.Strings)
local GameClock = require(Shared.Modules.GameClock)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Log = require(Shared.Modules.Log)

local HUDScreen = require(script.Parent.Parent.UI.Screens.HUDScreen)

local STATE_WAIT_TIMEOUT = 30

local log = Log.new("HUDController")

local HUDController = {}

local screen: HUDScreen.HUDScreen? = nil

function HUDController:GetScreen(): HUDScreen.HUDScreen?
	return screen
end

function HUDController:Init() end

function HUDController:Start()
	local player = Players.LocalPlayer
	local playerGui = InstanceUtil.waitForChild(player, "PlayerGui")
	local matchState = InstanceUtil.waitForChild(ReplicatedStorage, "MatchState", STATE_WAIT_TIMEOUT)

	local hud = HUDScreen.new(playerGui)
	screen = hud

	local function refresh()
		local inShift = player:GetAttribute("State") == "InShift"
		hud:SetVisible(inShift)
		if not inShift then
			return
		end

		local phase = matchState:GetAttribute("Phase")
		hud:SetClock(GameClock.format(tonumber(matchState:GetAttribute("GameMinute")) or 0))

		if phase == "Loading" then
			hud:SetBanner(Strings.get("HUD_LOADING"))
			hud:SetObjective(nil)
		elseif phase == "Briefing" then
			hud:SetBanner(Strings.get("HUD_BRIEFING"))
			hud:SetObjective(Strings.get("HUD_OBJECTIVE_BRIEFING"))
		elseif phase == "Shift" then
			hud:SetBanner(nil)
			hud:SetObjective(Strings.get("HUD_OBJECTIVE_DEFAULT"))
		elseif phase == "Results" then
			hud:SetBanner(Strings.get("HUD_SHIFT_COMPLETE"))
			hud:SetObjective(nil)
		else
			hud:SetBanner(nil)
			hud:SetObjective(nil)
		end
	end

	matchState:GetAttributeChangedSignal("Phase"):Connect(refresh)
	matchState:GetAttributeChangedSignal("GameMinute"):Connect(refresh)
	player:GetAttributeChangedSignal("State"):Connect(refresh)

	local camera = workspace.CurrentCamera
	hud:SetViewportSize(camera.ViewportSize)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		hud:SetViewportSize(camera.ViewportSize)
	end)

	refresh()
	log:Debug("HUD pronto.")
end

return HUDController
