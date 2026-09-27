--!strict
-- Conquistas (e badges do Roblox, quando os IDs forem configurados).
-- Checadas quando as estatísticas mudam ou quando um evento é descoberto.

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BadgeDefinitions = require(Shared.Definitions.BadgeDefinitions)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)

local DataService = require(script.Parent.DataService)
local EconomyService: any = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local InventoryService = require(script.Parent.InventoryService)
local PlayerService = require(script.Parent.PlayerService)

type BadgeDefinition = BadgeDefinitions.BadgeDefinition

local log = Log.new("AchievementService")

local AchievementService = {}

-- (player, achievementId)
AchievementService.Unlocked = Signal.new()

local function has(player: Player, achievementId: string): boolean
	local badges = DataService:Get(player, "Badges")
	return type(badges) == "table" and badges[achievementId] ~= nil
end

local function qualifies(player: Player, badge: BadgeDefinition): boolean
	if badge.Stat then
		local stats = DataService:Get(player, "Stats")
		if type(stats) == "table" and (stats[badge.Stat.Name] or 0) >= badge.Stat.AtLeast then
			return true
		end
	end
	local discoveries = DataService:Get(player, "Discoveries")
	if type(discoveries) ~= "table" then
		return false
	end
	if badge.Discover then
		for _, eventId in badge.Discover do
			if discoveries[eventId] then
				return true
			end
		end
	end
	if badge.DiscoverAll then
		for _, eventId in badge.DiscoverAll do
			if not discoveries[eventId] then
				return false
			end
		end
		return true
	end
	return false
end

local function unlock(player: Player, badge: BadgeDefinition)
	DataService:Update(player, "Badges", function(badges)
		badges[badge.Id] = true
		return badges
	end)
	if badge.RewardItem then
		InventoryService:Grant(player, badge.RewardItem)
	end
	if badge.RewardTokens then
		EconomyService:Grant(player, "NightTokens", badge.RewardTokens, `Achievement:{badge.Id}`)
	end
	local robloxId = if type(badge.BadgeId) == "number" then badge.BadgeId else tonumber(badge.BadgeId)
	if robloxId then
		task.spawn(pcall, function()
			BadgeService:AwardBadge(player.UserId, robloxId)
		end)
	end
	log:Info("%s desbloqueou %s", player.Name, badge.Id)
	Net.Server.fire("Notify", player, "NOTIFY_ACHIEVEMENT", badge.NameKey)
	AchievementService.Unlocked:Fire(player, badge.Id)
end

function AchievementService:Check(player: Player)
	if not DataService:IsLoaded(player) then
		return
	end
	for _, badge in BadgeDefinitions.getAll() do
		if not has(player, badge.Id) and qualifies(player, badge) then
			unlock(player, badge)
		end
	end
end

function AchievementService:Has(player: Player, achievementId: string): boolean
	return has(player, achievementId)
end

function AchievementService:Init() end

function AchievementService:Start()
	DataService.Changed:Connect(function(player: Player, key: string)
		if key == "Stats" or key == "Discoveries" then
			task.defer(AchievementService.Check, AchievementService, player)
		end
	end)
	PlayerService.PlayerReady:Connect(function(player: Player)
		AchievementService:Check(player)
	end)
	EventService.EventDiscovered:Connect(function(player: Player)
		task.defer(AchievementService.Check, AchievementService, player)
	end)
end

return AchievementService
