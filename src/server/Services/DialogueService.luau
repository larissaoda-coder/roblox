--!strict
-- Conversas com NPCs. O servidor guarda em que ponto da conversa cada jogador está,
-- envia só a fala atual e valida cada escolha (índice, condição, distância).
-- Ações ("Serve", "Leave", "Tension:n", "Discover:Id") são repassadas por sinal e callback.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local DialogueDefinitions = require(script.Parent.Parent.ServerDefinitions.DialogueDefinitions)

local ClockService = require(script.Parent.ClockService)
local MapService = require(script.Parent.MapService)
local TensionService = require(script.Parent.TensionService)

type Choice = DialogueDefinitions.Choice

export type DialogueOptions = {
	SpeakerKey: string,
	Anchor: BasePart?, -- o jogador precisa ficar perto disto
	OnAction: ((action: string) -> ())?,
	OnEnd: (() -> ())?,
}

type Session = {
	DialogueId: string,
	NodeId: string,
	Options: DialogueOptions,
	VisibleChoices: { Choice },
	StartedAt: number,
}

local MAX_DISTANCE = 16
local TIMEOUT_SECONDS = 45

local log = Log.new("DialogueService")

local DialogueService = {}

-- (player, action) ações do diálogo que outros sistemas podem tratar (ex.: "Discover:<EventId>").
DialogueService.ActionTriggered = Signal.new()

local sessions: { [Player]: Session } = {}
local random = Random.new()

local function conditionMet(condition: string?): boolean
	if not condition then
		return true
	end
	local afterMinute = string.match(condition, "^AfterMinute:(%d+)$")
	if afterMinute then
		return ClockService:GetMinute() >= tonumber(afterMinute) :: number
	end
	local chance = string.match(condition, "^Chance:([%d%.]+)$")
	if chance then
		return random:NextNumber() < (tonumber(chance) :: number)
	end
	return false
end

local function runAction(player: Player, session: Session, action: string?)
	if not action then
		return
	end
	local tension = string.match(action, "^Tension:(%-?%d+)$")
	if tension then
		TensionService:Add(player, tonumber(tension) :: number, "Dialogue")
	end
	if session.Options.OnAction then
		session.Options.OnAction(action)
	end
	DialogueService.ActionTriggered:Fire(player, action)
end

local function finish(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	Net.Server.fire("DialogueNode", player, nil)
	if session.Options.OnEnd then
		session.Options.OnEnd()
	end
end

local function sendNode(player: Player, session: Session)
	local dialogue = DialogueDefinitions.get(session.DialogueId) :: DialogueDefinitions.Dialogue
	local node = dialogue.Nodes[session.NodeId]
	runAction(player, session, node.Action)
	local visible = {}
	local choiceKeys = {}
	for _, choice in node.Choices do
		if conditionMet(choice.Condition) then
			table.insert(visible, choice)
			table.insert(choiceKeys, choice.TextKey)
		end
	end
	session.VisibleChoices = visible
	Net.Server.fire("DialogueNode", player, {
		SpeakerKey = session.Options.SpeakerKey,
		TextKey = node.TextKey,
		Choices = choiceKeys,
	})
end

-- API ---------------------------------------------------------------------------------

function DialogueService:IsTalking(player: Player): boolean
	return sessions[player] ~= nil
end

-- Inicia uma conversa. (Não confundir com Start(), que é o ciclo de vida do serviço.)
function DialogueService:Begin(player: Player, dialogueId: string, options: DialogueOptions): boolean
	local dialogue = DialogueDefinitions.get(dialogueId)
	if not dialogue or sessions[player] then
		return false
	end
	local startNode = dialogue.Start
	local variants: { { Node: string, Chance: number } } = dialogue.StartVariants or {}
	for _, variant in variants do
		if random:NextNumber() < variant.Chance then
			startNode = variant.Node
			break
		end
	end
	local session: Session = {
		DialogueId = dialogueId,
		NodeId = startNode,
		Options = options,
		VisibleChoices = {},
		StartedAt = os.clock(),
	}
	sessions[player] = session
	sendNode(player, session)
	return true
end

function DialogueService:Cancel(player: Player)
	finish(player)
end

local function onChoice(player: Player, index: number)
	local session = sessions[player]
	if not session then
		return
	end
	local anchor = session.Options.Anchor
	local position = MapService:GetCharacterPosition(player)
	if anchor and (not position or (position - anchor.Position).Magnitude > MAX_DISTANCE) then
		log:Debug("%s se afastou da conversa", player.Name)
		finish(player)
		return
	end
	local choice = session.VisibleChoices[index]
	if not choice then
		return -- índice fora das escolhas visíveis: ignorado
	end
	runAction(player, session, choice.Action)
	if choice.Next and sessions[player] == session then
		session.NodeId = choice.Next
		sendNode(player, session)
	else
		finish(player)
	end
end

function DialogueService:Init()
	Net.Server.on("DialogueChoice", onChoice)
end

function DialogueService:Start()
	-- Conversas abandonadas terminam sozinhas.
	task.spawn(function()
		while true do
			task.wait(2)
			for player, session in sessions do
				if player.Parent == nil or os.clock() - session.StartedAt > TIMEOUT_SECONDS then
					finish(player)
				end
			end
		end
	end)
end

return DialogueService
