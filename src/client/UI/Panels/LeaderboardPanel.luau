--!strict
-- Rankings: top 10 por categoria (só exibição).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage.Shared.Definitions.Strings)

local PanelKit = require(script.Parent.PanelKit)

export type LeaderboardState = { Board: string, Entries: { { Rank: number, Name: string, Value: number } }? }
export type LeaderboardActions = { SelectBoard: (board: string) -> () }

local BOARDS = { "Level", "ShiftsCompleted", "EventsDiscovered", "CashEarned", "PlayTime" }

local LeaderboardPanel = {}

LeaderboardPanel.BOARDS = BOARDS

function LeaderboardPanel.render(content: Instance, state: LeaderboardState, actions: LeaderboardActions)
	local order = PanelKit.counter()
	PanelKit.tabs(content, BOARDS, "BOARD_", state.Board, order, actions.SelectBoard)
	local entries = state.Entries
	if not entries then
		PanelKit.section(content, "…", order)
		return
	end
	if #entries == 0 then
		PanelKit.section(content, Strings.get("LEADERBOARD_EMPTY"), order)
		return
	end
	for _, entry in entries do
		PanelKit.row(
			content,
			`Rank{entry.Rank}`,
			`{entry.Rank}. {entry.Name}`,
			tostring(entry.Value),
			order,
			nil
		)
	end
end

return LeaderboardPanel
