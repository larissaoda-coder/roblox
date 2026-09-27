--!strict
-- Tensão de cada jogador durante o turno (0–100), calculada no servidor 1x por segundo.
-- Sobe: sozinho, no escuro, na floresta, testemunhando eventos.
-- Desce: perto da equipe, em área segura (loja iluminada), ao concluir tarefas.
-- O valor fica no atributo "Tension" do Player; o cliente usa só para efeitos visuais/sonoros.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local TensionConfig = require(script.Parent.Parent.ServerDefinitions.TensionConfig)

local LightingService = require(script.Parent.LightingService)
local MapService = require(script.Parent.MapService)
local MatchService = require(script.Parent.MatchService)
local TaskService = require(script.Parent.TaskService)

local PHANTOM_SOUNDS = { "Footsteps", "Knock", "Whisper", "DoorClose" }

local log = Log.new("TensionService")

local TensionService = {}

local tension: { [Player]: number } = {}
local running = false
local random = Random.new()

-- Só jogadores VIVOS: espectadores não recebem eventos nem tensão.
local function matchPlayers(): { Player }
	return MatchService:GetAlivePlayers()
end

local function setTension(player: Player, value: number)
	local clamped = math.clamp(value, 0, TensionConfig.MAX)
	tension[player] = clamped
	player:SetAttribute("Tension", math.floor(clamped + 0.5))
end

function TensionService:Get(player: Player): number
	return tension[player] or 0
end

function TensionService:Add(player: Player, amount: number, reason: string?)
	if not running or tension[player] == nil then
		return
	end
	setTension(player, tension[player] + amount)
	log:Debug("Tensão de %s %+.0f (%s) = %.0f", player.Name, amount, reason or "?", tension[player])
end

function TensionService:GetTeamAverage(): number
	local total, count = 0, 0
	for player, value in tension do
		total += value
		count += 1
	end
	return if count > 0 then total / count else 0
end

-- Quantos colegas estão perto deste jogador.
function TensionService:CountNearbyTeammates(player: Player, radius: number?): number
	local position = MapService:GetCharacterPosition(player)
	if not position then
		return 0
	end
	local limit = radius or TensionConfig.ALONE_RADIUS
	local count = 0
	for _, other in matchPlayers() do
		if other ~= player then
			local otherPosition = MapService:GetCharacterPosition(other)
			if otherPosition and (otherPosition - position).Magnitude <= limit then
				count += 1
			end
		end
	end
	return count
end

function TensionService:IsAlone(player: Player): boolean
	return self:CountNearbyTeammates(player) == 0
end

-- Jogador mais "vulnerável": sozinho e com mais tensão (alvo preferido de eventos perceptivos).
function TensionService:GetMostVulnerable(): Player?
	local best: Player? = nil
	local bestScore = -math.huge
	for _, player in matchPlayers() do
		if MapService:GetCharacterPosition(player) then
			local score = (tension[player] or 0) + (if self:IsAlone(player) then 50 else 0)
			if score > bestScore then
				best, bestScore = player, score
			end
		end
	end
	return best
end

local function tick(player: Player)
	local position = MapService:GetCharacterPosition(player)
	if not position then
		return
	end
	local zone, zonePart = MapService:GetZoneAt(position)
	local alone = TensionService:IsAlone(player)
	local dark = (LightingService :: any):IsDark(zone)
	local safe = zonePart ~= nil and zonePart:GetAttribute("SafeZone") == true and not dark
	local indoor = zonePart ~= nil and zonePart:GetAttribute("Indoor") == true

	local delta = 0
	if alone then
		delta += TensionConfig.GAIN_ALONE
	else
		delta -= TensionConfig.DECAY_WITH_TEAM
	end
	if dark then
		delta += TensionConfig.GAIN_DARK
	end
	if zone == "Forest" then
		delta += TensionConfig.GAIN_FOREST
	elseif not indoor then
		delta += TensionConfig.GAIN_OUTDOOR_NIGHT
	elseif not dark then
		delta -= TensionConfig.DECAY_LIT_INDOOR
	end
	if safe then
		delta -= TensionConfig.DECAY_SAFE_ZONE
	end
	setTension(player, (tension[player] or 0) + delta * TensionConfig.TICK_SECONDS)

	-- Sons falsos: só este jogador ouve. Nada acontece de verdade.
	if alone and tension[player] >= TensionConfig.PHANTOM_THRESHOLD then
		if random:NextNumber() < TensionConfig.PHANTOM_CHANCE_PER_SECOND * TensionConfig.TICK_SECONDS then
			local offset = Vector3.new(random:NextNumber(-10, 10), 0, random:NextNumber(-10, 10))
			Net.Server.fire("Perception", player, "Sound", {
				Sound = PHANTOM_SOUNDS[random:NextInteger(1, #PHANTOM_SOUNDS)],
				Position = position + offset,
			})
		end
	end
end

local function start()
	table.clear(tension)
	for _, player in matchPlayers() do
		setTension(player, 0)
	end
	running = true
	task.spawn(function()
		while running do
			task.wait(TensionConfig.TICK_SECONDS)
			if not running then
				break
			end
			for _, player in matchPlayers() do
				if tension[player] ~= nil then
					tick(player)
				end
			end
			-- Quem morreu não sente mais tensão.
			for player in tension do
				if not MatchService:IsAlive(player) then
					tension[player] = nil
					player:SetAttribute("Tension", nil)
				end
			end
		end
	end)
end

local function stop()
	running = false
	for player in tension do
		player:SetAttribute("Tension", nil)
	end
	table.clear(tension)
end

function TensionService:Init() end

function TensionService:Start()
	MatchService.MatchStarted:Connect(start)
	MatchService.MatchEnded:Connect(stop)
	TaskService.StepCompleted:Connect(function(_taskId: string, _point: string, player: Player)
		TensionService:Add(player, -TensionConfig.TASK_COMPLETED_RELIEF, "Task")
	end)
end

return TensionService
