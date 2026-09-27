--!strict
-- Tarefas do turno: sorteio, liberação ao longo do tempo, passos e conclusão.
-- As tarefas são da EQUIPE: qualquer jogador pode fazer qualquer passo.
-- O cliente nunca informa "concluí a tarefa": ele só interage com o ponto, e o servidor decide.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Shared
local InteractionConfig = require(Shared.Config.InteractionConfig)
local TaskConfig = require(Shared.Config.TaskConfig)
local TaskDefinitions = require(Shared.Definitions.TaskDefinitions)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Rng = require(Shared.Modules.Rng)
local Signal = require(Shared.Modules.Signal)

local ClockService = require(script.Parent.ClockService)
local DataService = require(script.Parent.DataService)
local InteractionService = require(script.Parent.InteractionService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)

type TaskDefinition = TaskDefinitions.TaskDefinition

type ActiveTask = {
	Definition: TaskDefinition,
	Revealed: boolean,
	Completed: boolean,
	DoneSteps: { [string]: Player },
	CompletedBy: Player?,
}

export type TaskSummary = {
	Total: number,
	Completed: number,
	CompletedIds: { string },
	StepsByPlayer: { [Player]: number },
	TasksByPlayer: { [Player]: number },
	RewardByPlayer: { [Player]: { Cash: number, XP: number } },
}

local log = Log.new("TaskService")

local TaskService = {}

-- (taskId, pointName, player)
TaskService.StepCompleted = Signal.new()
-- (taskId, player)
TaskService.TaskCompleted = Signal.new()
-- (taskId)
TaskService.TaskRevealed = Signal.new()

local tasks: { ActiveTask } = {}
local tasksById: { [string]: ActiveTask } = {}
local points: { [string]: { [string]: Instance } } = {}
local blockedPoints: { [Instance]: boolean? } = {}
local matchActive = false
local summary: TaskSummary = {
	Total = 0,
	Completed = 0,
	CompletedIds = {},
	StepsByPlayer = {},
	TasksByPlayer = {},
	RewardByPlayer = {},
}

local function matchPlayers(): { Player }
	local match = MatchService:GetActiveMatch()
	return if match then match.Players else {}
end

local function snapshot()
	local list = {}
	for _, activeTask in tasks do
		if activeTask.Revealed then
			local done = 0
			for _ in activeTask.DoneSteps do
				done += 1
			end
			table.insert(list, {
				Id = activeTask.Definition.Id,
				Progress = done,
				Total = #activeTask.Definition.Steps,
				Completed = activeTask.Completed,
			})
		end
	end
	return list
end

local function broadcast()
	Net.Server.fireList("TasksChanged", matchPlayers(), snapshot())
end

-- Um passo está disponível se a tarefa foi liberada, não terminou, o passo não foi feito,
-- é a vez dele (tarefas em ordem) e o ponto não está bloqueado por um evento.
local function isStepAvailable(activeTask: ActiveTask, pointName: string): boolean
	if
		not matchActive
		or not activeTask.Revealed
		or activeTask.Completed
		or activeTask.DoneSteps[pointName]
	then
		return false
	end
	local pointInstance = points[activeTask.Definition.Id] and points[activeTask.Definition.Id][pointName]
	if not pointInstance or blockedPoints[pointInstance] then
		return false
	end
	if activeTask.Definition.Ordered then
		for _, step in activeTask.Definition.Steps do
			if not activeTask.DoneSteps[step.Point] then
				return step.Point == pointName
			end
		end
		return false
	end
	return true
end

local function refreshPoints(activeTask: ActiveTask)
	local taskPoints = points[activeTask.Definition.Id]
	if not taskPoints then
		return
	end
	for _, step in activeTask.Definition.Steps do
		local pointInstance = taskPoints[step.Point]
		if pointInstance then
			InteractionService:SetEnabled(pointInstance, isStepAvailable(activeTask, step.Point))
		end
	end
end

local function collectPoints(map: Instance)
	table.clear(points)
	for _, instance in map:GetDescendants() do
		if
			CollectionService:HasTag(instance, InteractionConfig.TAG)
			and instance:GetAttribute("InteractionType") == "Task"
		then
			local taskId = instance:GetAttribute("TaskId")
			local pointName = instance:GetAttribute("Point")
			if type(taskId) == "string" and type(pointName) == "string" then
				points[taskId] = points[taskId] or {}
				points[taskId][pointName] = instance
				InteractionService:SetEnabled(instance, false)
			else
				log:Warn("%s é um ponto de tarefa sem TaskId/Point.", instance:GetFullName())
			end
		end
	end
end

local function hasAllPoints(definition: TaskDefinition): boolean
	local taskPoints = points[definition.Id]
	if not taskPoints then
		return false
	end
	for _, step in definition.Steps do
		if not taskPoints[step.Point] then
			return false
		end
	end
	return true
end

local function reveal(activeTask: ActiveTask, announce: boolean)
	activeTask.Revealed = true
	refreshPoints(activeTask)
	log:Debug("Tarefa liberada: %s", activeTask.Definition.Id)
	TaskService.TaskRevealed:Fire(activeTask.Definition.Id)
	if announce then
		Net.Server.fireList("TaskNotice", matchPlayers(), activeTask.Definition.Id, true)
	end
end

local function revealNext(minute: number, announce: boolean): boolean
	for _, activeTask in tasks do
		if not activeTask.Revealed and activeTask.Definition.MinMinute <= minute then
			reveal(activeTask, announce)
			return true
		end
	end
	return false
end

local function allRevealedDone(): boolean
	for _, activeTask in tasks do
		if activeTask.Revealed and not activeTask.Completed then
			return false
		end
	end
	return true
end

local function selectTasks(mapId: string, rng: Rng.Rng): { ActiveTask }
	local candidates = {}
	for _, definition in TaskDefinitions.getForMap(mapId) do
		if hasAllPoints(definition) then
			table.insert(candidates, definition)
		end
	end

	local selected: { TaskDefinition } = {}
	while #selected < TaskConfig.TASKS_PER_SHIFT and #candidates > 0 do
		local pick = rng:WeightedPick(candidates, function(definition: TaskDefinition)
			return definition.Weight
		end)
		if not pick then
			break
		end
		table.insert(selected, pick)
		table.remove(candidates, table.find(candidates, pick) :: number)
	end

	-- Ordem de liberação: primeiro as que podem aparecer mais cedo.
	table.sort(selected, function(a, b)
		return a.MinMinute < b.MinMinute
	end)

	local result = {}
	for _, definition in selected do
		table.insert(result, { Definition = definition, Revealed = false, Completed = false, DoneSteps = {} })
	end
	return result
end

local function resetSummary(total: number)
	summary = {
		Total = total,
		Completed = 0,
		CompletedIds = {},
		StepsByPlayer = {},
		TasksByPlayer = {},
		RewardByPlayer = {},
	}
end

local function completeTask(activeTask: ActiveTask, player: Player)
	activeTask.Completed = true
	activeTask.CompletedBy = player
	local definition = activeTask.Definition
	summary.Completed += 1
	table.insert(summary.CompletedIds, definition.Id)
	summary.TasksByPlayer[player] = (summary.TasksByPlayer[player] or 0) + 1

	-- A recompensa da tarefa é dividida entre todos da equipe (cooperação, não competição).
	for _, member in matchPlayers() do
		local reward = summary.RewardByPlayer[member] or { Cash = 0, XP = 0 }
		reward.Cash += definition.Reward.Cash
		reward.XP += definition.Reward.XP
		summary.RewardByPlayer[member] = reward
	end

	DataService:IncrementStat(player, "TasksCompleted", 1)
	log:Info("Tarefa %s concluída por %s", definition.Id, player.Name)
	TaskService.TaskCompleted:Fire(definition.Id, player)
	Net.Server.fireList("TaskNotice", matchPlayers(), definition.Id, false)

	if allRevealedDone() then
		revealNext(ClockService:GetMinute(), true)
	end
end

local function onInteract(player: Player, pointInstance: Instance)
	local taskId = pointInstance:GetAttribute("TaskId") :: string
	local pointName = pointInstance:GetAttribute("Point") :: string
	local activeTask = tasksById[taskId]
	if not activeTask then
		return
	end
	activeTask.DoneSteps[pointName] = player
	summary.StepsByPlayer[player] = (summary.StepsByPlayer[player] or 0) + 1
	TaskService.StepCompleted:Fire(taskId, pointName, player)

	local finished = true
	for _, step in activeTask.Definition.Steps do
		if not activeTask.DoneSteps[step.Point] then
			finished = false
			break
		end
	end
	if finished then
		completeTask(activeTask, player)
	end
	refreshPoints(activeTask)
	broadcast()
end

local function canInteract(player: Player, pointInstance: Instance): (boolean, string?)
	if not MatchService:IsPlayerInMatch(player) then
		return false, nil
	end
	local taskId = pointInstance:GetAttribute("TaskId")
	local pointName = pointInstance:GetAttribute("Point")
	local activeTask = if type(taskId) == "string" then tasksById[taskId] else nil
	if not activeTask or type(pointName) ~= "string" then
		return false, nil
	end
	if not isStepAvailable(activeTask, pointName) then
		return false, "NOTIFY_TASK_NOT_NOW"
	end
	return true, nil
end

local function startForMatch(match)
	local map = MapService:GetActiveMap()
	table.clear(tasks)
	table.clear(tasksById)
	table.clear(blockedPoints)
	if not map then
		resetSummary(0)
		return
	end
	collectPoints(map)

	local rng = Rng.new()
	tasks = selectTasks(match.MapId, rng)
	for _, activeTask in tasks do
		tasksById[activeTask.Definition.Id] = activeTask
		for _, step in activeTask.Definition.Steps do
			local pointInstance = points[activeTask.Definition.Id][step.Point]
			InteractionService:SetPromptKey(pointInstance, step.PromptKey)
			InteractionService:SetHoldDuration(pointInstance, step.HoldDuration)
		end
	end
	resetSummary(#tasks)
	matchActive = true
	log:Info("%d tarefas sorteadas (seed %d)", #tasks, rng.Seed)

	for _ = 1, TaskConfig.INITIAL_TASKS do
		revealNext(0, false)
	end
	broadcast()
end

local function onMinute(minute: number)
	if not matchActive or minute <= 0 then
		return
	end
	if minute % TaskConfig.REVEAL_EVERY_MINUTES == 0 or allRevealedDone() then
		if revealNext(minute, true) then
			broadcast()
		end
	end
end

local function finish()
	matchActive = false
	for _, activeTask in tasks do
		refreshPoints(activeTask)
	end
end

-- API ---------------------------------------------------------------------------------

function TaskService:GetSummary(): TaskSummary
	return summary
end

function TaskService:GetActiveTaskIds(): { string }
	local ids = {}
	for _, activeTask in tasks do
		if activeTask.Revealed and not activeTask.Completed then
			table.insert(ids, activeTask.Definition.Id)
		end
	end
	return ids
end

function TaskService:GetPoint(taskId: string, pointName: string): Instance?
	return points[taskId] and points[taskId][pointName]
end

-- Bloqueia/desbloqueia um ponto (ex.: evento "objeto desaparecido").
function TaskService:SetPointBlocked(taskId: string, pointName: string, blocked: boolean)
	local pointInstance = self:GetPoint(taskId, pointName)
	local activeTask = tasksById[taskId]
	if not pointInstance or not activeTask then
		return
	end
	blockedPoints[pointInstance] = if blocked then true else nil
	refreshPoints(activeTask)
end

function TaskService:Init()
	InteractionService:RegisterHandler("Task", {
		CanInteract = canInteract,
		OnInteract = onInteract,
	})
	Net.Server.handle("RequestTasks", function(player: Player)
		return if MatchService:IsPlayerInMatch(player) then snapshot() else {}
	end)
end

function TaskService:Start()
	MatchService.MatchStarted:Connect(startForMatch)
	MatchService.MatchEnded:Connect(finish)
	ClockService.MinuteChanged:Connect(onMinute)
end

return TaskService
