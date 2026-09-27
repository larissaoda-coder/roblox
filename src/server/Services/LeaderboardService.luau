--!strict
-- Rankings (nível, turnos concluídos, eventos descobertos, cash ganho, tempo jogado).
-- Só para exibição: não dão recompensas (não afetam a economia).
-- Escrita no fim do turno/saída (com limite de frequência) e leitura em cache a cada 2 minutos.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local RewardService = require(script.Parent.RewardService)

type Entry = { Rank: number, UserId: number, Name: string, Value: number }

local BOARDS: { [string]: (data: { [string]: any }) -> number } = {
	Level = function(data)
		return data.Level
	end,
	ShiftsCompleted = function(data)
		return data.Stats.ShiftsCompleted
	end,
	EventsDiscovered = function(data)
		return data.Stats.EventsDiscovered
	end,
	CashEarned = function(data)
		return data.Stats.CashEarned
	end,
	PlayTime = function(data)
		return math.floor(data.Stats.PlayTime / 60)
	end,
}

local TOP_COUNT = 10
local REFRESH_SECONDS = 120
local WRITE_COOLDOWN = 60

local log = Log.new("LeaderboardService")

local LeaderboardService = {}

local cache: { [string]: { Entry } } = {}
local lastWrite: { [Player]: number } = {}
local names: { [number]: string } = {}
local available = true

local function store(board: string): OrderedDataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(`NightShift_LB_{board}`)
	end)
	return if ok then result else nil
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and type(name) == "string" then name else `#{userId}`
	return names[userId]
end

function LeaderboardService:Write(player: Player, force: boolean?)
	if not available or not DataService:IsLoaded(player) then
		return
	end
	if not force and os.clock() - (lastWrite[player] or -math.huge) < WRITE_COOLDOWN then
		return
	end
	lastWrite[player] = os.clock()
	local data = {
		Level = DataService:Get(player, "Level"),
		Stats = DataService:Get(player, "Stats"),
	}
	for board, getter in BOARDS do
		local orderedStore = store(board)
		local value = math.floor(getter(data) or 0)
		if orderedStore then
			local ok, err = pcall(function()
				orderedStore:SetAsync(tostring(player.UserId), value)
			end)
			if not ok then
				log:Debug("Falha ao gravar ranking %s: %s", board, tostring(err))
			end
		end
	end
end

function LeaderboardService:Refresh()
	for board in BOARDS do
		local orderedStore = store(board)
		if orderedStore then
			local ok, entries = pcall(function()
				local pages = orderedStore:GetSortedAsync(false, TOP_COUNT)
				local list = {}
				for rank, item in pages:GetCurrentPage() do
					local userId = tonumber(item.key) or 0
					table.insert(
						list,
						{ Rank = rank, UserId = userId, Name = nameOf(userId), Value = item.value }
					)
				end
				return list
			end)
			if ok then
				cache[board] = entries
			end
		end
	end
end

function LeaderboardService:Get(board: string): { Entry }
	return cache[board] or {}
end

function LeaderboardService:Init()
	Net.Server.handle("GetLeaderboard", function(_player: Player, board: string)
		if BOARDS[board] == nil then
			return {}
		end
		return LeaderboardService:Get(board)
	end)
end

function LeaderboardService:Start()
	available = store("Level") ~= nil
	RewardService.Rewarded:Connect(function(player: Player)
		LeaderboardService:Write(player, true)
	end)
	PlayerService.PlayerLeaving:Connect(function(player: Player)
		LeaderboardService:Write(player, true)
		lastWrite[player] = nil
	end)
	task.spawn(function()
		while true do
			LeaderboardService:Refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LeaderboardService
