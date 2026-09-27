--!strict
-- A entidade. Quase sempre só observa. Estados:
--   Watching  aparece longe (borda da floresta, estrada) olhando para o posto; some se alguém chega perto
--   Stalking  segue um jogador SOZINHO à distância (só ele ouve a respiração)
--   Manifest  aparece por 1–2 s perto de alguém e some (as luzes da zona piscam)
--   Hunt      persegue um jogador; se alcançar, ele morre (vira espectador).
--             Escapa quem voltar para a loja iluminada junto da equipe.
-- Quando pode agir quem decide é o DirectorService (intensidade permitida) + temperamento da partida.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local FigureFactory = require(Shared.Modules.FigureFactory)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Rng = require(Shared.Modules.Rng)
local Signal = require(Shared.Modules.Signal)

local EntityDefinitions = require(script.Parent.Parent.ServerDefinitions.EntityDefinitions)

local AudioService = require(script.Parent.AudioService)
local ClockService = require(script.Parent.ClockService)
local DirectorService = require(script.Parent.DirectorService)
local EventService = require(script.Parent.EventService)
local LightingService: any = require(script.Parent.LightingService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local SpectatorService = require(script.Parent.SpectatorService)
local TensionService = require(script.Parent.TensionService)

export type EntityState = "Dormant" | "Watching" | "Stalking" | "Manifest" | "Hunt" | "Retreat"

local CONFIG = EntityDefinitions.Watcher
local STEP_SECONDS = 0.15

local log = Log.new("EntityService")

local EntityService = {}

-- (newState, oldState)
EntityService.StateChanged = Signal.new()

local state: EntityState = "Dormant"
local model: Model? = nil
local rng = Rng.new()
local temperament = CONFIG.TEMPERAMENTS[1]
local cooldownUntilMinute = 0
local huntsThisShift = 0
local matchToken = 0
local huntTarget: Player? = nil

local function setState(newState: EntityState)
	local old = state
	state = newState
	log:Debug("Entidade: %s → %s", old, newState)
	EntityService.StateChanged:Fire(newState, old)
end

local function alivePlayers(): { Player }
	return MatchService:GetAlivePlayers()
end

local function despawnModel()
	if model then
		model:Destroy()
		model = nil
	end
end

local function spawnModel(position: Vector3): Model
	despawnModel()
	local figure = FigureFactory.build(position, { Name = "Entity", Eyes = true, Scale = CONFIG.Scale })
	figure.Parent = MapService:GetActiveMap() or workspace
	model = figure
	return figure
end

local function moveModel(position: Vector3, lookAt: Vector3?)
	local current = model
	if not current then
		return
	end
	local target = lookAt or position
	local flatTarget = Vector3.new(target.X, position.Y, target.Z)
	if (flatTarget - position).Magnitude > 0.1 then
		current:PivotTo(CFrame.lookAt(position, flatTarget))
	else
		current:PivotTo(CFrame.new(position))
	end
end

local function nodes(kind: string): { BasePart }
	local list = {}
	local folder = MapService:GetFolder("EntityNodes")
	if folder then
		for _, node in folder:GetChildren() do
			if node:IsA("BasePart") and node:GetAttribute("Kind") == kind then
				table.insert(list, node)
			end
		end
	end
	return list
end

local function nearestPlayer(position: Vector3, players: { Player }): (Player?, number)
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in players do
		local playerPosition = MapService:GetCharacterPosition(player)
		if playerPosition then
			local distance = (playerPosition - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best, bestDistance
end

local function isProtected(player: Player): boolean
	-- A loja iluminada com colegas é segura: a entidade desiste.
	local position = MapService:GetCharacterPosition(player)
	if not position then
		return true
	end
	local zone, zonePart = MapService:GetZoneAt(position)
	return zonePart ~= nil
		and zonePart:GetAttribute("SafeZone") == true
		and not LightingService:IsDark(zone)
		and not TensionService:IsAlone(player)
end

local function isActive(token: number): boolean
	return matchToken == token and MatchService:GetPhase() == "Shift"
end

-- Estados ------------------------------------------------------------------------------------

local function watch(token: number)
	local candidates = nodes("Watch")
	local node = rng:Pick(candidates)
	if not node then
		return
	end
	setState("Watching")
	spawnModel(node.Position - Vector3.new(0, 3, 0))
	local witnesses = {}
	for _, player in alivePlayers() do
		local position = MapService:GetCharacterPosition(player)
		if position then
			local _, zonePart = MapService:GetZoneAt(position)
			if
				not zonePart
				or zonePart:GetAttribute("Indoor") ~= true
				or (position - node.Position).Magnitude < 150
			then
				table.insert(witnesses, player)
			end
		end
	end
	for _, player in witnesses do
		EventService:Discover(player, "EntitySighting")
	end
	local duration = rng:Number(CONFIG.WATCH_SECONDS_MIN, CONFIG.WATCH_SECONDS_MAX)
	local startedAt = os.clock()
	while os.clock() - startedAt < duration and isActive(token) do
		local target, distance = nearestPlayer(node.Position, alivePlayers())
		if target and distance < CONFIG.VANISH_DISTANCE then
			break -- alguém chegou perto: some
		end
		if target then
			moveModel(node.Position - Vector3.new(0, 3, 0), MapService:GetCharacterPosition(target))
		end
		task.wait(0.5)
	end
end

local function stalk(token: number)
	local lonely = {}
	for _, player in alivePlayers() do
		if TensionService:IsAlone(player) then
			table.insert(lonely, player)
		end
	end
	local target = rng:Pick(lonely)
	if not target then
		return
	end
	setState("Stalking")
	EventService:Discover(target, "EntityStalked")
	local startedAt = os.clock()
	while os.clock() - startedAt < CONFIG.STALK_SECONDS and isActive(token) do
		local position = MapService:GetCharacterPosition(target)
		if not position or not TensionService:IsAlone(target) then
			break
		end
		-- Só o alvo ouve a respiração, sempre a uma distância segura.
		local angle = rng:Number(0, math.pi * 2)
		local distance = CONFIG.STALK_MIN_DISTANCE + rng:Number(0, 10)
		Net.Server.fire("Perception", target, "Sound", {
			Sound = "EntityBreath",
			Position = position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance),
		})
		TensionService:Add(target, 3, "Stalked")
		task.wait(3)
	end
end

local function manifest(token: number)
	-- Escolhe alguém que tenha um esconderijo por perto (senão não há onde "aparecer").
	local players = alivePlayers()
	local options = {}
	for _, player in players do
		local position = MapService:GetCharacterPosition(player)
		if position then
			for _, node in nodes("Hide") do
				local distance = (node.Position - position).Magnitude
				if distance < CONFIG.MANIFEST_RADIUS then
					table.insert(options, { Node = node, Position = position, Distance = distance })
				end
			end
		end
	end
	local choice = rng:Pick(options)
	if not choice then
		return
	end
	local best: BasePart = choice.Node
	local targetPosition: Vector3 = choice.Position
	setState("Manifest")
	spawnModel(best.Position - Vector3.new(0, 3, 0))
	moveModel(best.Position - Vector3.new(0, 3, 0), targetPosition)
	AudioService:PlayAt("EntityStinger", best.Position)
	local zone = MapService:GetZoneAt(best.Position)
	if LightingService:GetZoneState(zone) ~= nil then
		LightingService:Flicker(zone, CONFIG.MANIFEST_SECONDS + 0.5)
	end
	for _, player in players do
		local position = MapService:GetCharacterPosition(player)
		if position and (position - best.Position).Magnitude < 60 then
			EventService:Discover(player, "EntityManifest")
		end
	end
	task.wait(CONFIG.MANIFEST_SECONDS)
	if not isActive(token) then
		return
	end
end

local function computeWaypoints(from: Vector3, to: Vector3): { Vector3 }
	local ok, waypoints = pcall(function(): { Vector3 }?
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 8, AgentCanJump = false })
		path:ComputeAsync(from, to)
		if path.Status ~= Enum.PathStatus.Success then
			return nil
		end
		local points = {}
		for _, waypoint in path:GetWaypoints() do
			table.insert(points, waypoint.Position)
		end
		return points
	end)
	if ok and waypoints and #waypoints > 0 then
		return waypoints
	end
	return { to } -- sem caminho: vai em linha reta (é sobrenatural, atravessa paredes)
end

local function hunt(token: number, forcedTarget: Player?)
	local target = forcedTarget or TensionService:GetMostVulnerable()
	local targetPosition = target and MapService:GetCharacterPosition(target)
	if not target or not targetPosition or isProtected(target) then
		return
	end
	huntsThisShift += 1
	huntTarget = target
	setState("Hunt")
	-- Começa a uma distância que dá para reagir.
	local angle = rng:Number(0, math.pi * 2)
	local start = targetPosition
		+ Vector3.new(
			math.cos(angle) * CONFIG.HUNT_START_DISTANCE,
			0,
			math.sin(angle) * CONFIG.HUNT_START_DISTANCE
		)
	spawnModel(start - Vector3.new(0, 3, 0))
	AudioService:PlayAt("EntityStinger", start)
	for _, player in alivePlayers() do
		EventService:Discover(player, "EntityHunt")
	end

	local position = start
	local startedAt = os.clock()
	local waypoints: { Vector3 } = {}
	local repathAt = 0
	while os.clock() - startedAt < CONFIG.HUNT_SECONDS and isActive(token) do
		local current = MapService:GetCharacterPosition(target)
		if not current or not MatchService:IsAlive(target) or isProtected(target) then
			break
		end
		if (current - position).Magnitude <= CONFIG.KILL_DISTANCE then
			SpectatorService:Kill(target, "Entity")
			break
		end
		if os.clock() >= repathAt or #waypoints == 0 then
			waypoints = computeWaypoints(position, current)
			repathAt = os.clock() + 1
		end
		local nextPoint = waypoints[1]
		local offset = nextPoint - position
		local step = CONFIG.HUNT_SPEED * STEP_SECONDS
		if offset.Magnitude <= step then
			position = nextPoint
			table.remove(waypoints, 1)
		else
			position += offset.Unit * step
		end
		moveModel(position - Vector3.new(0, 3, 0), current)
		local zone = MapService:GetZoneAt(position)
		if LightingService:GetZoneState(zone) == "On" then
			LightingService:Flicker(zone, 1)
		end
		task.wait(STEP_SECONDS)
	end
	huntTarget = nil
end

local function appear(forcedState: EntityState?, forcedTarget: Player?)
	if state ~= "Dormant" then
		return
	end
	local token = matchToken
	local intensity = DirectorService:GetAllowedIntensity()
	local minute = ClockService:GetMinute()
	local choice: EntityState? = forcedState
	if not choice then
		local options: { { State: EntityState, Weight: number } } = {}
		if intensity >= 2 then
			table.insert(options, { State = "Watching", Weight = temperament.Watch })
		end
		if intensity >= 3 then
			table.insert(options, { State = "Stalking", Weight = temperament.Stalk })
		end
		if intensity >= 4 then
			table.insert(options, { State = "Manifest", Weight = temperament.Manifest })
		end
		if
			intensity >= 5
			and minute >= temperament.HuntMinMinute
			and huntsThisShift < CONFIG.MAX_HUNTS_PER_SHIFT
		then
			table.insert(options, { State = "Hunt", Weight = temperament.Hunt })
		end
		local picked = rng:WeightedPick(options, function(option)
			return option.Weight
		end)
		choice = picked and picked.State
	end
	if not choice then
		return
	end

	task.spawn(function()
		local ok, err = xpcall(function()
			if choice == "Watching" then
				watch(token)
			elseif choice == "Stalking" then
				stalk(token)
			elseif choice == "Manifest" then
				manifest(token)
			elseif choice == "Hunt" then
				hunt(token, forcedTarget)
			end
		end, debug.traceback)
		if not ok then
			log:Error("Erro na entidade:\n%s", tostring(err))
		end
		despawnModel()
		if matchToken == token and state ~= "Dormant" then
			setState("Retreat")
			cooldownUntilMinute = ClockService:GetMinute()
				+ rng:Integer(CONFIG.COOLDOWN_MIN_MINUTES, CONFIG.COOLDOWN_MAX_MINUTES)
			setState("Dormant")
		end
	end)
end

-- API ---------------------------------------------------------------------------------

function EntityService:GetState(): EntityState
	return state
end

function EntityService:GetModel(): Model?
	return model
end

function EntityService:GetTemperament(): string
	return temperament.Name
end

function EntityService:GetHuntTarget(): Player?
	return huntTarget
end

-- Força um comportamento (admin/testes/segredos).
function EntityService:Force(forcedState: EntityState, target: Player?)
	appear(forcedState, target)
end

function EntityService:Init() end

function EntityService:Start()
	MatchService.MatchStarted:Connect(function()
		matchToken += 1
		rng = Rng.new()
		temperament = rng:WeightedPick(CONFIG.TEMPERAMENTS, function(item)
			return item.Weight
		end) or CONFIG.TEMPERAMENTS[1]
		cooldownUntilMinute = 10
		huntsThisShift = 0
		huntTarget = nil
		state = "Dormant"
		despawnModel()
		log:Debug("Temperamento da entidade: %s", temperament.Name)
	end)
	MatchService.MatchEnded:Connect(function()
		matchToken += 1
		despawnModel()
		state = "Dormant"
	end)
	ClockService.MinuteChanged:Connect(function(minute: number)
		if MatchService:GetPhase() ~= "Shift" or state ~= "Dormant" or minute < cooldownUntilMinute then
			return
		end
		if rng:Chance(CONFIG.APPEAR_CHANCE_PER_MINUTE) then
			appear(nil, nil)
		end
	end)
	-- Quem atende o telefone às 04:44 é caçado.
	EventService.SecretTriggered:Connect(function(secretId: string, player: Player?)
		if secretId == "DontAnswer" and player then
			task.delay(4, function()
				if MatchService:IsAlive(player) then
					appear("Hunt", player)
				end
			end)
		end
	end)
end

return EntityService
