--!strict
-- Mostra o HUD durante o turno, lendo o estado público da partida (ReplicatedStorage > MatchState).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Definitions.Strings)
local TaskDefinitions = require(Shared.Definitions.TaskDefinitions)
local GameClock = require(Shared.Modules.GameClock)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local HUDScreen = require(script.Parent.Parent.UI.Screens.HUDScreen)
local NotificationController = require(script.Parent.NotificationController)

local STATE_WAIT_TIMEOUT = 30

local log = Log.new("HUDController")

local HUDController = {}

local screen: HUDScreen.HUDScreen? = nil

type TaskInfo = { Id: string, Progress: number, Total: number, Completed: boolean }

local tasks: { TaskInfo } = {}

local function taskName(taskId: string): string
	local definition = TaskDefinitions.get(taskId)
	return if definition then Strings.get(definition.NameKey) else taskId
end

-- Primeira tarefa pendente vira o objetivo principal; se todas acabaram, avisa para aguardar.
local function currentObjective(): string
	for _, info in tasks do
		if not info.Completed then
			return string.upper(taskName(info.Id))
		end
	end
	if #tasks > 0 then
		return Strings.get("HUD_ALL_TASKS_DONE")
	end
	return Strings.get("HUD_OBJECTIVE_DEFAULT")
end

local function taskLines(): { HUDScreen.TaskLine }
	local lines = {}
	for _, info in tasks do
		local text = taskName(info.Id)
		if not info.Completed and info.Total > 1 then
			text ..= ` ({info.Progress}/{info.Total})`
		end
		table.insert(lines, { Text = text, Completed = info.Completed })
	end
	return lines
end

function HUDController:GetTasks(): { TaskInfo }
	return tasks
end

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
		hud:SetTasks(taskLines())

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
			hud:SetObjective(currentObjective())
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

	Net.Client.on("TasksChanged", function(list)
		tasks = if type(list) == "table" then list else {}
		refresh()
	end)
	Net.Client.on("TaskNotice", function(taskId: string, isNew: boolean)
		NotificationController:ShowKey(
			if isNew then "NOTIFY_NEW_TASK" else "NOTIFY_TASK_COMPLETE",
			taskName(taskId)
		)
	end)
	-- Ao voltar para o lobby, limpa a lista.
	player:GetAttributeChangedSignal("State"):Connect(function()
		if player:GetAttribute("State") == "Lobby" then
			tasks = {}
		end
	end)

	refresh()
	log:Debug("HUD pronto.")
end

return HUDController
