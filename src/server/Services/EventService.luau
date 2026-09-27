--!strict
-- Gerenciador de eventos estranhos. Quem decide QUANDO tentar é o DirectorService;
-- aqui ficam as regras de QUAL evento pode acontecer, a execução e o registro de descobertas.
--
-- Cada evento é um ModuleScript em Server > Events com:
--   Run(ctx)            obrigatório (pode esperar)
--   CanRun(ctx) -> bool opcional (condições extras)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Shared
local InteractionConfig = require(Shared.Config.InteractionConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Rng = require(Shared.Modules.Rng)
local Signal = require(Shared.Modules.Signal)

local Server = script.Parent.Parent
local EventDefinitions = require(Server.ServerDefinitions.EventDefinitions)

local AudioService = require(script.Parent.AudioService)
local ClockService = require(script.Parent.ClockService)
local DataService = require(script.Parent.DataService)
local DialogueService = require(script.Parent.DialogueService)
local DoorService = require(script.Parent.DoorService)
local InteractionService = require(script.Parent.InteractionService)
local LightingService = require(script.Parent.LightingService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local NPCService = require(script.Parent.NPCService)
local SecurityCameraService = require(script.Parent.SecurityCameraService)
local TaskService = require(script.Parent.TaskService)
local TensionService = require(script.Parent.TensionService)

type EventDefinition = EventDefinitions.EventDefinition

export type Budget = { MaxIntensity: number }

export type EventContext = {
	Definition: EventDefinition,
	Minute: number,
	Rng: Rng.Rng,
	Players: { Player },
	Target: Player?,
	Map: Model,
	Services: { [string]: any },
	Witness: (players: { Player }) -> (),
	WitnessNear: (position: Vector3, radius: number) -> (),
	WitnessZone: (zone: string) -> (),
	WitnessAll: () -> (),
	Perceive: (player: Player, kind: string, data: { [string]: any }) -> (),
	IsActive: () -> boolean,
}

export type EventModule = {
	CanRun: ((ctx: EventContext) -> boolean)?,
	Run: (ctx: EventContext) -> (),
}

export type PhoneCall = {
	LineKey: string,
	RingSeconds: number,
	OnAnswer: ((player: Player) -> ())?,
	OnMissed: (() -> ())?,
}

local TENSION_PER_INTENSITY = 4

local log = Log.new("EventService")

local EventService = {}

-- (eventId)
EventService.EventTriggered = Signal.new()
-- (player, eventId, isFirstTimeEver)
EventService.EventDiscovered = Signal.new()
-- (eventId, player?) usado por segredos que desencadeiam outras coisas (ex.: a entidade).
EventService.SecretTriggered = Signal.new()

local modules: { [string]: EventModule } = {}
local counts: { [string]: number } = {}
local lastMinute: { [string]: number } = {}
local shiftDiscoveries: { [Player]: { [string]: boolean } } = {}
local newDiscoveries: { [Player]: { string } } = {}
local rng = Rng.new()
local matchToken = 0
local activeCall: PhoneCall? = nil
local callToken = 0

local SERVICES = {
	Audio = AudioService,
	Doors = DoorService,
	Lighting = LightingService,
	Map = MapService,
	Match = MatchService,
	Cameras = SecurityCameraService,
	Tasks = TaskService,
	Tension = TensionService,
	Events = EventService,
	Interaction = InteractionService,
	NPCs = NPCService,
}

-- Só jogadores VIVOS: espectadores não recebem eventos nem tensão.
local function matchPlayers(): { Player }
	return MatchService:GetAlivePlayers()
end

local function recordDiscovery(player: Player, definition: EventDefinition)
	local mine = shiftDiscoveries[player]
	if not mine then
		mine = {}
		shiftDiscoveries[player] = mine
	end
	if mine[definition.Id] then
		return
	end
	mine[definition.Id] = true

	local discoveries = DataService:Get(player, "Discoveries")
	local firstTime = type(discoveries) == "table" and discoveries[definition.Id] == nil
	if firstTime then
		DataService:Update(player, "Discoveries", function(current)
			current[definition.Id] = os.time()
			return current
		end)
		DataService:IncrementStat(player, "EventsDiscovered", 1)
		if definition.Secret then
			DataService:IncrementStat(player, "SecretsFound", 1)
		end
		newDiscoveries[player] = newDiscoveries[player] or {}
		table.insert(newDiscoveries[player], definition.Id)
	end
	EventService.EventDiscovered:Fire(player, definition.Id, firstTime)
end

local function witness(definition: EventDefinition, players: { Player })
	for _, player in players do
		if table.find(matchPlayers(), player) then
			TensionService:Add(player, definition.Intensity * TENSION_PER_INTENSITY, definition.Id)
			recordDiscovery(player, definition)
		end
	end
end

local function playersNear(position: Vector3, radius: number): { Player }
	local list = {}
	for _, player in matchPlayers() do
		local playerPosition = MapService:GetCharacterPosition(player)
		if playerPosition and (playerPosition - position).Magnitude <= radius then
			table.insert(list, player)
		end
	end
	return list
end

local function playersInZone(zone: string): { Player }
	local list = {}
	for _, player in matchPlayers() do
		local position = MapService:GetCharacterPosition(player)
		if position and MapService:GetZoneAt(position) == zone then
			table.insert(list, player)
		end
	end
	return list
end

local function buildContext(definition: EventDefinition): EventContext?
	local map = MapService:GetActiveMap()
	if not map then
		return nil
	end
	local token = matchToken
	local ctx = {
		Definition = definition,
		Minute = ClockService:GetMinute(),
		Rng = rng,
		Players = table.clone(matchPlayers()),
		Target = if definition.Perceptual then TensionService:GetMostVulnerable() else nil,
		Map = map,
		Services = SERVICES,
	} :: EventContext
	ctx.Witness = function(players: { Player })
		witness(definition, players)
	end
	ctx.WitnessNear = function(position: Vector3, radius: number)
		witness(definition, playersNear(position, radius))
	end
	ctx.WitnessZone = function(zone: string)
		witness(definition, playersInZone(zone))
	end
	ctx.WitnessAll = function()
		witness(definition, matchPlayers())
	end
	ctx.Perceive = function(player: Player, kind: string, data: { [string]: any })
		Net.Server.fire("Perception", player, kind, data)
	end
	ctx.IsActive = function()
		return matchToken == token and MatchService:GetActiveMatch() ~= nil
	end
	return ctx
end

local function isEligible(
	definition: EventDefinition,
	budget: Budget?,
	minute: number,
	special: boolean
): boolean
	if special then
		if definition.SpecialMinute ~= minute then
			return false
		end
	else
		if definition.SpecialMinute ~= nil then
			return false
		end
		if minute < definition.MinMinute or minute > definition.MaxMinute then
			return false
		end
		if budget and definition.Intensity > budget.MaxIntensity then
			return false
		end
	end
	if (counts[definition.Id] or 0) >= definition.MaxPerShift then
		return false
	end
	local last = lastMinute[definition.Id]
	if last and minute - last < definition.Cooldown then
		return false
	end
	return true
end

local function run(definition: EventDefinition, ctx: EventContext): boolean
	local module = modules[definition.Module]
	if not module then
		return false
	end
	if definition.Perceptual and not ctx.Target then
		return false
	end
	if module.CanRun then
		local ok, allowed = pcall(module.CanRun, ctx)
		if not ok then
			log:Error("CanRun de %s falhou: %s", definition.Id, tostring(allowed))
			return false
		end
		if not allowed then
			return false
		end
	end
	counts[definition.Id] = (counts[definition.Id] or 0) + 1
	lastMinute[definition.Id] = ctx.Minute
	log:Info("Evento: %s (minuto %d)", definition.Id, ctx.Minute)
	EventService.EventTriggered:Fire(definition.Id)
	task.spawn(function()
		local ok, err = xpcall(function()
			module.Run(ctx)
		end, debug.traceback)
		if not ok then
			log:Error("Evento %s falhou:\n%s", definition.Id, tostring(err))
		end
	end)
	return true
end

-- API ---------------------------------------------------------------------------------

-- Tenta um evento aleatório dentro do orçamento do Director. Retorna o Id ou nil.
function EventService:TryRandom(budget: Budget): string?
	local minute = ClockService:GetMinute()
	local candidates = {}
	for _, definition in EventDefinitions.getAll() do
		if isEligible(definition, budget, minute, false) then
			table.insert(candidates, definition)
		end
	end
	-- Tenta em ordem sorteada por peso; se o escolhido não puder rodar (CanRun), tenta outro.
	while #candidates > 0 do
		local pick = rng:WeightedPick(candidates, EventDefinitions.weightOf)
		if not pick then
			return nil
		end
		table.remove(candidates, table.find(candidates, pick) :: number)
		local ctx = buildContext(pick)
		if ctx and run(pick, ctx) then
			return pick.Id
		end
	end
	return nil
end

-- Eventos de horário especial (04:17, 04:33, 04:44). Cada um rola sua própria chance.
function EventService:TrySpecial(minute: number): { string }
	local triggered = {}
	for _, definition in EventDefinitions.getAll() do
		if isEligible(definition, nil, minute, true) and rng:Chance(definition.SpecialChance or 1) then
			local ctx = buildContext(definition)
			if ctx and run(definition, ctx) then
				table.insert(triggered, definition.Id)
			end
		end
	end
	return triggered
end

-- Força um evento (admin/testes). Ignora raridade e horário, mas respeita CanRun.
function EventService:Trigger(eventId: string): boolean
	local definition = EventDefinitions.get(eventId)
	if not definition then
		return false
	end
	local ctx = buildContext(definition)
	return ctx ~= nil and run(definition, ctx)
end

-- Registra que o jogador presenciou um evento (usado por diálogos, câmeras etc.).
function EventService:Discover(player: Player, eventId: string): boolean
	local definition = EventDefinitions.get(eventId)
	if not definition or not MatchService:IsPlayerInMatch(player) then
		return false
	end
	witness(definition, { player })
	return true
end

function EventService:GetShiftDiscoveries(player: Player): { string }
	local list = {}
	for eventId in (shiftDiscoveries[player] or {}) :: { [string]: boolean } do
		table.insert(list, eventId)
	end
	table.sort(list)
	return list
end

-- Eventos vistos pela PRIMEIRA VEZ (na vida do jogador) neste turno.
function EventService:GetNewDiscoveries(player: Player): { string }
	return table.clone(newDiscoveries[player] or {})
end

function EventService:GetTriggeredCount(): number
	local total = 0
	for _, count in counts do
		total += count
	end
	return total
end

-- Telefone --------------------------------------------------------------------------------

local function findPhone(): BasePart?
	local map = MapService:GetActiveMap()
	if not map then
		return nil
	end
	for _, instance in CollectionService:GetTagged(InteractionConfig.TAG) do
		if
			instance:IsDescendantOf(map)
			and instance:GetAttribute("InteractionType") == "Phone"
			and instance:IsA("BasePart")
		then
			return instance
		end
	end
	return nil
end

local function endCall()
	activeCall = nil
	callToken += 1
	AudioService:Stop("Phone")
	local phone = findPhone()
	if phone then
		InteractionService:SetEnabled(phone, false)
	end
end

function EventService:IsPhoneRinging(): boolean
	return activeCall ~= nil
end

-- Faz o telefone tocar. Quem atender ouve a linha (LineKey). Retorna false se não houver telefone.
function EventService:StartPhoneCall(call: PhoneCall): boolean
	local phone = findPhone()
	if not phone or activeCall then
		return false
	end
	activeCall = call
	callToken += 1
	local token = callToken
	InteractionService:SetEnabled(phone, true)
	AudioService:PlayAt("PhoneRing", phone.Position, { Tag = "Phone" })
	task.delay(call.RingSeconds, function()
		if callToken == token then
			endCall()
			if call.OnMissed then
				call.OnMissed()
			end
		end
	end)
	return true
end

local function answerPhone(player: Player, target: Instance)
	local call = activeCall
	if not call then
		return
	end
	endCall()
	local position = if target:IsA("BasePart") then target.Position else nil
	AudioService:PlayFor(player, "PhonePickUp", position)
	AudioService:PlayFor(player, "PhoneStatic", position)
	Net.Server.fire("Notify", player, call.LineKey)
	if call.OnAnswer then
		call.OnAnswer(player)
	end
end

function EventService:Init()
	local eventsFolder = Server:FindFirstChild("Events")
	for _, definition in EventDefinitions.getAll() do
		if definition.DiscoveryOnly then
			continue
		end
		local moduleScript = eventsFolder and eventsFolder:FindFirstChild(definition.Module)
		assert(
			moduleScript and moduleScript:IsA("ModuleScript"),
			`[EventService] módulo do evento {definition.Id} não encontrado em Server > Events`
		)
		modules[definition.Module] = require(moduleScript) :: any
	end

	InteractionService:RegisterHandler("Phone", {
		CanInteract = function(player: Player)
			return activeCall ~= nil and MatchService:IsPlayerInMatch(player), nil
		end,
		OnInteract = answerPhone,
	})
end

function EventService:Start()
	-- Diálogos podem revelar eventos ("Discover:<EventId>").
	DialogueService.ActionTriggered:Connect(function(player: Player, action: string)
		local eventId = string.match(action, "^Discover:(.+)$")
		if eventId then
			EventService:Discover(player, eventId)
		end
	end)
	-- Olhar as câmeras enquanto o cliente sem registro está no caixa: a câmera mostra o caixa vazio.
	SecurityCameraService.ViewChanged:Connect(function(player: Player, cameraId: string)
		if cameraId == "CAM02" and NPCService:HasActive("NoRecord") then
			EventService:Discover(player, "CustomerNoRecord")
		end
	end)

	MatchService.MatchStarted:Connect(function()
		matchToken += 1
		rng = Rng.new()
		table.clear(counts)
		table.clear(lastMinute)
		table.clear(shiftDiscoveries)
		table.clear(newDiscoveries)
		endCall()
	end)
	MatchService.MatchEnded:Connect(function()
		matchToken += 1
		endCall()
	end)
end

return EventService
