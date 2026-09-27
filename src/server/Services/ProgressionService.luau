--!strict
-- XP e níveis. "XP" no perfil é o progresso DENTRO do nível atual.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)

local DataService = require(script.Parent.DataService)

local log = Log.new("ProgressionService")

local ProgressionService = {}

-- (player, newLevel, oldLevel)
ProgressionService.LevelUp = Signal.new()

function ProgressionService:GetLevel(player: Player): number
	return DataService:Get(player, "Level") or 1
end

-- Adiciona XP e sobe de nível quantas vezes for preciso. Retorna (níveis ganhos, nível final).
function ProgressionService:AddXP(player: Player, amount: number): (number, number)
	local level = self:GetLevel(player)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount > EconomyConfig.MAX_GRANT then
		return 0, level
	end
	local xp = (DataService:Get(player, "XP") or 0) + math.floor(amount)
	local startLevel = level
	while level < EconomyConfig.MAX_LEVEL and xp >= EconomyConfig.xpForLevel(level) do
		xp -= EconomyConfig.xpForLevel(level)
		level += 1
	end
	if level >= EconomyConfig.MAX_LEVEL then
		xp = 0
	end
	DataService:Set(player, "XP", xp)
	if level ~= startLevel then
		DataService:Set(player, "Level", level)
		log:Info("%s subiu para o nível %d", player.Name, level)
		ProgressionService.LevelUp:Fire(player, level, startLevel)
	end
	return level - startLevel, level
end

function ProgressionService:Init() end

return ProgressionService
