--!strict
-- Clientes do posto. Chegam pela estrada (NPCPath), vão até o caixa, esperam ser atendidos,
-- conversam (DialogueService) e vão embora. Clientes raros/sobrenaturais só aparecem por evento.
--
-- Performance: modelos de Parts ancoradas movidos com PivotTo (10x por segundo), sem Humanoid
-- nem Pathfinding; no máximo MAX_ACTIVE clientes ao mesmo tempo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Modules.Log)
local Rng = require(Shared.Modules.Rng)
local Signal = require(Shared.Modules.Signal)

local Server = script.Parent.Parent
local NPCDefinitions = require(Server.ServerDefinitions.NPCDefinitions)
local NPCBuilder = require(Server.World.NPCBuilder)

local ClockService = require(script.Parent.ClockService)
local DialogueService = require(script.Parent.DialogueService)
local InteractionService = require(script.Parent.InteractionService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local TensionService = require(script.Parent.TensionService)

type NPCDefinition = NPCDefinitions.NPCDefinition

export type ActiveNPC = {
	Id: number,
	Definition: NPCDefinition,
	Model: Model,
	State: "Arriving" | "Waiting" | "Talking" | "Leaving",
	ServedBy: Player?,
}

local MAX_ACTIVE = 2
local FIRST_CUSTOMER_MINUTE = 5
local INTERVAL_MIN = 6
local INTERVAL_MAX = 12
local WAIT_SECONDS = 45
local STEP_SECONDS = 0.1
local IGNORED_TENSION = 4

local log = Log.new("NPCService")

local NPCService = {}

-- (npc) chegou ao caixa.
NPCService.CustomerArrived = Signal.new()
-- (npc, player?) foi embora (player = quem atendeu).
NPCService.CustomerLeft = Signal.new()

local active: { ActiveNPC } = {}
local nextId = 0
local nextCustomerMinute = math.huge
local matchToken = 0
local rng = Rng.new()
local servedByPlayer: { [Player]: number } = {}

local function pathNodes(): { Vector3 }
	local folder = MapService:GetFolder("NPCPath")
	local nodes: { BasePart } = {}
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(nodes, child)
			end
		end
	end
	table.sort(nodes, function(a, b)
		return (tonumber(string.match(a.Name, "%d+")) or 0) < (tonumber(string.match(b.Name, "%d+")) or 0)
	end)
	local positions = {}
	for _, node in nodes do
		table.insert(positions, node.Position - Vector3.new(0, 3, 0))
	end
	return positions
end

local function isActiveNPC(npc: ActiveNPC): boolean
	return table.find(active, npc) ~= nil
end

-- Caminha em linha reta entre os pontos. Retorna false se a partida acabar no meio.
local function walk(npc: ActiveNPC, points: { Vector3 }, token: number): boolean
	local speed = npc.Definition.WalkSpeed
	for index = 2, #points do
		local from, to = points[index - 1], points[index]
		local distance = (to - from).Magnitude
		local steps = math.max(1, math.ceil(distance / (speed * STEP_SECONDS)))
		for step = 1, steps do
			if matchToken ~= token or not isActiveNPC(npc) then
				return false
			end
			local position = from + (to - from) * (step / steps)
			if (to - from).Magnitude > 0.05 then
				npc.Model:PivotTo(CFrame.lookAt(position, to))
			end
			task.wait(STEP_SECONDS)
		end
	end
	return true
end

local function despawn(npc: ActiveNPC)
	local index = table.find(active, npc)
	if index then
		table.remove(active, index)
	end
	npc.Model:Destroy()
	NPCService.CustomerLeft:Fire(npc, npc.ServedBy)
end

local function leave(npc: ActiveNPC, token: number)
	if npc.State == "Leaving" then
		return
	end
	npc.State = "Leaving"
	local root = npc.Model.PrimaryPart
	if root then
		InteractionService:SetEnabled(root, false)
	end
	task.spawn(function()
		local points = pathNodes()
		local reversed = {}
		for index = #points, 1, -1 do
			table.insert(reversed, points[index])
		end
		-- O cliente sem registro some assim que sai pela porta.
		if npc.Definition.NoCameraRecord and #reversed > 3 then
			reversed = { reversed[1], reversed[2], reversed[3] }
		end
		walk(npc, reversed, token)
		if isActiveNPC(npc) then
			despawn(npc)
		end
	end)
end

local function run(npc: ActiveNPC, token: number)
	local points = pathNodes()
	if #points < 2 then
		despawn(npc)
		return
	end
	if not walk(npc, points, token) then
		return
	end
	npc.State = "Waiting"
	local root = npc.Model.PrimaryPart :: BasePart
	InteractionService:SetEnabled(root, true)
	log:Debug("Cliente %s esperando no caixa", npc.Definition.Id)
	NPCService.CustomerArrived:Fire(npc)

	local startedAt = os.clock()
	while npc.State == "Waiting" and os.clock() - startedAt < WAIT_SECONDS do
		if matchToken ~= token then
			return
		end
		task.wait(0.5)
	end
	if npc.State == "Waiting" then
		-- Ninguém atendeu: a equipe sente o clima pesar um pouco.
		local match = MatchService:GetActiveMatch()
		if match then
			for _, player in match.Players do
				TensionService:Add(player, IGNORED_TENSION, "CustomerIgnored")
			end
		end
		leave(npc, token)
	end
end

local function onTalk(player: Player, target: Instance)
	for _, npc in active do
		if npc.Model.PrimaryPart == target and npc.State == "Waiting" then
			npc.State = "Talking"
			InteractionService:SetEnabled(target, false)
			local token = matchToken
			local started = DialogueService:Begin(player, npc.Definition.DialogueId, {
				SpeakerKey = npc.Definition.NameKey,
				Anchor = target :: BasePart,
				OnAction = function(action: string)
					if action == "Serve" and npc.ServedBy == nil then
						npc.ServedBy = player
						servedByPlayer[player] = (servedByPlayer[player] or 0) + 1
					end
				end,
				OnEnd = function()
					leave(npc, token)
				end,
			})
			if not started then
				npc.State = "Waiting"
				InteractionService:SetEnabled(target, true)
			end
			return
		end
	end
end

-- API ---------------------------------------------------------------------------------

function NPCService:Spawn(npcId: string): ActiveNPC?
	local definition = NPCDefinitions.get(npcId)
	local points = pathNodes()
	if not definition or #points < 2 or #active >= MAX_ACTIVE or not MatchService:GetActiveMatch() then
		return nil
	end
	local map = MapService:GetActiveMap() :: Model
	nextId += 1
	local model = NPCBuilder.build(definition.Id, definition.Colors, definition.Height, points[1])
	if definition.NoCameraRecord then
		model:SetAttribute("NoCameraRecord", true)
	end
	model.Parent = map
	local npc: ActiveNPC = { Id = nextId, Definition = definition, Model = model, State = "Arriving" }
	table.insert(active, npc)
	log:Info("Cliente: %s", definition.Id)
	task.spawn(run, npc, matchToken)
	return npc
end

function NPCService:GetActive(): { ActiveNPC }
	return active
end

function NPCService:HasActive(npcId: string): boolean
	for _, npc in active do
		if npc.Definition.Id == npcId then
			return true
		end
	end
	return false
end

function NPCService:GetServedCount(player: Player): number
	return servedByPlayer[player] or 0
end

local function scheduleNext(minute: number)
	nextCustomerMinute = minute + rng:Integer(INTERVAL_MIN, INTERVAL_MAX)
end

local function onMinute(minute: number)
	if MatchService:GetPhase() ~= "Shift" or minute < nextCustomerMinute then
		return
	end
	scheduleNext(minute)
	local candidates = {}
	for _, definition in NPCDefinitions.getAll() do
		if definition.SpawnMode == "Schedule" and minute >= definition.MinMinute then
			table.insert(candidates, definition)
		end
	end
	local pick = rng:WeightedPick(candidates, function(definition: NPCDefinition)
		return definition.Weight
	end)
	if pick then
		NPCService:Spawn(pick.Id)
	end
end

function NPCService:Init()
	InteractionService:RegisterHandler("NPC", {
		CanInteract = function(player: Player)
			return MatchService:IsPlayerInMatch(player) and not DialogueService:IsTalking(player), nil
		end,
		OnInteract = onTalk,
	})
end

function NPCService:Start()
	MatchService.MatchStarted:Connect(function()
		matchToken += 1
		rng = Rng.new()
		table.clear(servedByPlayer)
		nextCustomerMinute = FIRST_CUSTOMER_MINUTE
	end)
	MatchService.MatchEnded:Connect(function()
		matchToken += 1
		nextCustomerMinute = math.huge
		for _, npc in table.clone(active) do
			despawn(npc)
		end
	end)
	ClockService.MinuteChanged:Connect(onMinute)
end

return NPCService
