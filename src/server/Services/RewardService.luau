--!strict
-- Recompensas do fim do turno. Calculadas UMA vez por jogador por partida, sempre no servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local MatchService = require(script.Parent.MatchService)
local NPCService = require(script.Parent.NPCService)
local ProgressionService = require(script.Parent.ProgressionService)
local TaskService = require(script.Parent.TaskService)

export type ShiftResult = {
	Completed: boolean,
	Survived: boolean,
	TasksCompleted: number,
	TasksTotal: number,
	EventsDiscovered: number,
	NewDiscoveries: { string },
	CustomersServed: number,
	Lines: { { Key: string, XP: number, Cash: number } },
	TotalXP: number,
	TotalCash: number,
	OldLevel: number,
	NewLevel: number,
}

local log = Log.new("RewardService")

local RewardService = {}

-- (player, result)
RewardService.Rewarded = Signal.new()

local rewarded: { [string]: { [Player]: boolean } } = {}

local function compute(player: Player, matchResult): ShiftResult
	local summary = TaskService:GetSummary()
	local survived = table.find(matchResult.Survivors, player) ~= nil
	local completed = matchResult.Completed
	local lines = {}

	local taskReward = summary.RewardByPlayer[player] or { Cash = 0, XP = 0 }
	local taskMultiplier = if completed then 1 else EconomyConfig.FAILED_TASK_MULTIPLIER
	table.insert(lines, {
		Key = "RESULT_TASKS",
		XP = math.floor(taskReward.XP * taskMultiplier),
		Cash = math.floor(taskReward.Cash * taskMultiplier),
	})
	if completed then
		table.insert(lines, {
			Key = "RESULT_SHIFT",
			XP = EconomyConfig.SHIFT_COMPLETE_XP,
			Cash = EconomyConfig.SHIFT_COMPLETE_CASH,
		})
	end
	if completed and survived then
		table.insert(lines, {
			Key = "RESULT_SURVIVAL",
			XP = EconomyConfig.SURVIVAL_BONUS_XP,
			Cash = EconomyConfig.SURVIVAL_BONUS_CASH,
		})
	end

	local discovered = EventService:GetShiftDiscoveries(player)
	local newDiscoveries = EventService:GetNewDiscoveries(player)
	local knownCount = #discovered - #newDiscoveries
	local discoveryXP = #newDiscoveries * EconomyConfig.NEW_DISCOVERY_XP
		+ knownCount * EconomyConfig.DISCOVERY_XP
	local discoveryCash = #newDiscoveries * EconomyConfig.NEW_DISCOVERY_CASH
	if discoveryXP > 0 or discoveryCash > 0 then
		table.insert(lines, { Key = "RESULT_DISCOVERIES", XP = discoveryXP, Cash = discoveryCash })
	end

	local served = NPCService:GetServedCount(player)
	if served > 0 then
		table.insert(
			lines,
			{ Key = "RESULT_CUSTOMERS", XP = 0, Cash = served * EconomyConfig.CUSTOMER_SERVED_CASH }
		)
	end

	local totalXP, totalCash = 0, 0
	for _, line in lines do
		totalXP += line.XP
		totalCash += line.Cash
	end
	return {
		Completed = completed,
		Survived = survived,
		TasksCompleted = summary.Completed,
		TasksTotal = summary.Total,
		EventsDiscovered = #discovered,
		NewDiscoveries = newDiscoveries,
		CustomersServed = served,
		Lines = lines,
		TotalXP = totalXP,
		TotalCash = totalCash,
		OldLevel = ProgressionService:GetLevel(player),
		NewLevel = ProgressionService:GetLevel(player),
	}
end

local function reward(matchId: string, player: Player, matchResult)
	rewarded[matchId] = rewarded[matchId] or {}
	if rewarded[matchId][player] or player.Parent == nil or not DataService:IsLoaded(player) then
		return
	end
	rewarded[matchId][player] = true

	local result = compute(player, matchResult)
	if result.TotalCash > 0 then
		EconomyService:Grant(player, "Cash", result.TotalCash, "Shift")
	end
	if result.TotalXP > 0 then
		local _, newLevel = ProgressionService:AddXP(player, result.TotalXP)
		result.NewLevel = newLevel
	end
	if result.Completed then
		DataService:IncrementStat(player, "ShiftsCompleted", 1)
		if result.Survived then
			DataService:IncrementStat(player, "ShiftsSurvived", 1)
		end
	end
	log:Info("%s: +%d XP, +%d CASH (turno %s)", player.Name, result.TotalXP, result.TotalCash, matchId)
	Net.Server.fire("ShiftResults", player, result)
	RewardService.Rewarded:Fire(player, result)
end

function RewardService:Init() end

function RewardService:Start()
	MatchService.MatchEnded:Connect(function(match, matchResult)
		for _, player in matchResult.Players do
			reward(match.Id, player, matchResult)
		end
	end)
end

return RewardService
