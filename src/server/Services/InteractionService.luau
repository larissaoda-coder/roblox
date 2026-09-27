--!strict
-- Sistema ÚNICO de interação. Todo objeto com a tag "Interactable" ganha um ProximityPrompt
-- (que já funciona com teclado, toque e controle). O visual é desenhado pelo InteractionController.
--
-- Cada tipo de objeto (InteractionType) tem um "handler" registrado pelo serviço dono dele:
--   InteractionService:RegisterHandler("Door", { CanInteract = fn?, OnInteract = fn })
--
-- O servidor valida TUDO: tipo registrado, objeto no mundo, habilitado, estado do jogador,
-- distância, tempo segurando e cooldown.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local InteractionConfig = require(Shared.Config.InteractionConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local PlayerService = require(script.Parent.PlayerService)

export type Handler = {
	-- Retorna (true) ou (false, chaveDeTextoDoMotivo).
	CanInteract: ((player: Player, target: Instance) -> (boolean, string?))?,
	OnInteract: (player: Player, target: Instance) -> (),
}

local PROMPT_NAME = "InteractionPrompt"

local log = Log.new("InteractionService")

local InteractionService = {}

-- (player, target, interactionType) após uma interação válida.
InteractionService.Interacted = Signal.new()
-- (player, target, reason) interação recusada (útil para debug/anti-abuso).
InteractionService.Rejected = Signal.new()

local handlers: { [string]: Handler } = {}
local prompts: { [Instance]: ProximityPrompt } = {}
local holdStarts: { [Player]: { prompt: ProximityPrompt, at: number } } = {}
local lastInteraction: { [Player]: number } = {}

local function getPromptParent(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") and target.PrimaryPart then
		return target.PrimaryPart
	end
	return target:FindFirstChildWhichIsA("BasePart", true)
end

local function numberAttribute(target: Instance, name: string, default: number): number
	local value = target:GetAttribute(name)
	return if type(value) == "number" then value else default
end

local function reject(player: Player, target: Instance, reason: string, notifyKey: string?)
	log:Debug("Interação de %s com %s recusada: %s", player.Name, target.Name, reason)
	InteractionService.Rejected:Fire(player, target, reason)
	if notifyKey then
		Net.Server.fire("Notify", player, notifyKey)
	end
end

local function validate(player: Player, target: Instance, prompt: ProximityPrompt): (boolean, string?)
	if not target:IsDescendantOf(workspace) then
		return false, "NotInWorld"
	end
	if target:GetAttribute("Enabled") == false or not prompt.Enabled then
		return false, "Disabled"
	end
	if not PlayerService:IsReady(player) then
		return false, "NotReady"
	end
	local requiresShift = target:GetAttribute("RequiresShift") ~= false
	if requiresShift and PlayerService:GetState(player) ~= "InShift" then
		return false, "NotInShift"
	end

	local now = os.clock()
	if now - (lastInteraction[player] or 0) < InteractionConfig.PLAYER_COOLDOWN then
		return false, "Cooldown"
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local promptParent = prompt.Parent :: BasePart
	if not root then
		return false, "NoCharacter"
	end
	local maxDistance = prompt.MaxActivationDistance + InteractionConfig.SERVER_DISTANCE_TOLERANCE
	if (root.Position - promptParent.Position).Magnitude > maxDistance then
		return false, "TooFar"
	end

	if prompt.HoldDuration > 0 then
		local hold = holdStarts[player]
		if not hold or hold.prompt ~= prompt then
			return false, "NoHold"
		end
		if now - hold.at < prompt.HoldDuration * InteractionConfig.HOLD_TOLERANCE then
			return false, "HoldTooShort"
		end
	end
	return true, nil
end

local function onTriggered(target: Instance, prompt: ProximityPrompt, player: Player)
	local interactionType = target:GetAttribute("InteractionType")
	local handler = if type(interactionType) == "string" then handlers[interactionType] else nil
	if not handler then
		reject(player, target, "NoHandler")
		return
	end

	local ok, reason = validate(player, target, prompt)
	holdStarts[player] = nil
	if not ok then
		reject(player, target, reason :: string)
		return
	end

	local canInteract = handler.CanInteract
	if canInteract then
		local allowed, messageKey = canInteract(player, target)
		if not allowed then
			reject(player, target, "HandlerDenied", messageKey)
			return
		end
	end

	lastInteraction[player] = os.clock()
	local success, err = xpcall(function()
		handler.OnInteract(player, target)
	end, debug.traceback)
	if not success then
		log:Error("Erro no handler %s:\n%s", tostring(interactionType), tostring(err))
		return
	end
	InteractionService.Interacted:Fire(player, target, interactionType)
end

local function setup(target: Instance)
	-- Só objetos no mundo (mapas guardados em ServerStorage também têm tags, mas são ignorados).
	if prompts[target] or not target:IsDescendantOf(workspace) then
		return
	end
	local promptParent = getPromptParent(target)
	if not promptParent then
		log:Warn("%s tem a tag Interactable mas nenhuma Part para o prompt.", target:GetFullName())
		return
	end
	if type(target:GetAttribute("InteractionType")) ~= "string" then
		log:Warn("%s tem a tag Interactable mas não tem o atributo InteractionType.", target:GetFullName())
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = InteractionConfig.KEYBOARD_KEY
	prompt.GamepadKeyCode = InteractionConfig.GAMEPAD_KEY
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance =
		numberAttribute(target, "MaxDistance", InteractionConfig.DEFAULT_MAX_DISTANCE)
	prompt.HoldDuration = numberAttribute(target, "HoldDuration", InteractionConfig.DEFAULT_HOLD_DURATION)
	prompt.Enabled = target:GetAttribute("Enabled") ~= false
	-- O cliente traduz a chave com Strings.get.
	local promptKey = target:GetAttribute("PromptKey")
	prompt:SetAttribute(
		"PromptKey",
		if type(promptKey) == "string" then promptKey else InteractionConfig.DEFAULT_PROMPT_KEY
	)
	prompt.Parent = promptParent
	prompts[target] = prompt

	prompt.PromptButtonHoldBegan:Connect(function(player: Player)
		holdStarts[player] = { prompt = prompt, at = os.clock() }
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player: Player)
		local hold = holdStarts[player]
		-- Mantém o registro se o Triggered ainda vai chegar logo depois; só limpa se for de outro prompt.
		if hold and hold.prompt ~= prompt then
			holdStarts[player] = nil
		end
	end)
	prompt.Triggered:Connect(function(player: Player)
		onTriggered(target, prompt, player)
	end)
end

local function teardown(target: Instance)
	local prompt = prompts[target]
	if prompt then
		prompts[target] = nil
		prompt:Destroy()
	end
end

-- API ---------------------------------------------------------------------------------

function InteractionService:RegisterHandler(interactionType: string, handler: Handler)
	assert(
		handlers[interactionType] == nil,
		`[InteractionService] handler "{interactionType}" já registrado`
	)
	handlers[interactionType] = handler
end

-- Liga/desliga a interação de um objeto (para todos os jogadores).
function InteractionService:SetEnabled(target: Instance, enabled: boolean)
	target:SetAttribute("Enabled", enabled)
	local prompt = prompts[target]
	if prompt then
		prompt.Enabled = enabled
	end
end

-- Troca o texto do prompt (chave de Strings).
function InteractionService:SetPromptKey(target: Instance, promptKey: string)
	target:SetAttribute("PromptKey", promptKey)
	local prompt = prompts[target]
	if prompt then
		prompt:SetAttribute("PromptKey", promptKey)
	end
end

function InteractionService:GetPrompt(target: Instance): ProximityPrompt?
	return prompts[target]
end

-- Registra manualmente um objeto (equivale a adicionar a tag).
function InteractionService:Register(target: Instance)
	if not CollectionService:HasTag(target, InteractionConfig.TAG) then
		CollectionService:AddTag(target, InteractionConfig.TAG)
	else
		setup(target)
	end
end

function InteractionService:Init()
	CollectionService:GetInstanceAddedSignal(InteractionConfig.TAG):Connect(setup)
	CollectionService:GetInstanceRemovedSignal(InteractionConfig.TAG):Connect(teardown)
end

function InteractionService:Start()
	for _, target in CollectionService:GetTagged(InteractionConfig.TAG) do
		setup(target)
	end
	PlayerService.PlayerLeaving:Connect(function(player: Player)
		holdStarts[player] = nil
		lastInteraction[player] = nil
	end)
end

return InteractionService
