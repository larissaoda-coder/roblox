--!strict
-- Tela de fim de turno: SHIFT COMPLETE / FAILED, linhas de recompensa aparecendo uma a uma,
-- estatísticas e destaques (NOVO NÍVEL, NOVO EVENTO DESCOBERTO).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage.Shared.Definitions.Strings)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

export type ResultsScreen = {
	Gui: ScreenGui,
	Show: (self: ResultsScreen, result: { [string]: any }) -> (),
	Hide: (self: ResultsScreen) -> (),
	IsVisible: (self: ResultsScreen) -> boolean,
}

local LINE_DELAY = 0.3

local ResultsScreen = {}

function ResultsScreen.new(parent: Instance, onContinue: () -> ()): ResultsScreen
	local gui = Instance.new("ScreenGui")
	gui.Name = "Results"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = Theme.DisplayOrder.Popups + 5
	gui.Enabled = false

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.Colors.Background
	backdrop.BackgroundTransparency = 0.25
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local panel = Components.panel("Panel", Theme.Colors.Panel)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.92, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, math.huge)
	limit.Parent = panel
	Components.padding(panel, 24)
	Components.list(panel, 10)
	panel.Parent = gui

	local screen = { Gui = gui } :: ResultsScreen
	local showToken = 0

	local function clear()
		for _, child in panel:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function add(instance: GuiObject, order: number)
		instance.LayoutOrder = order
		instance.Parent = panel
	end

	function screen:Show(result: { [string]: any })
		showToken += 1
		local token = showToken
		clear()
		gui.Enabled = true
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end

		local titleKey = if result.Completed then "HUD_SHIFT_COMPLETE" else "HUD_SHIFT_FAILED"
		add(
			Components.label({
				Name = "Title",
				Text = Strings.get(titleKey),
				Font = Theme.Fonts.Bold,
				TextSize = Theme.TextSizes.Title,
				Color = if result.Completed then Theme.Colors.Text else Theme.Colors.Danger,
				AlignX = Enum.TextXAlignment.Center,
			}),
			nextOrder()
		)

		task.spawn(function()
			for index, line in result.Lines or {} do
				task.wait(LINE_DELAY)
				if showToken ~= token then
					return
				end
				local parts = {}
				if line.XP > 0 then
					table.insert(parts, `XP +{line.XP}`)
				end
				if line.Cash > 0 then
					table.insert(parts, `CASH +{line.Cash}`)
				end
				add(
					Components.label({
						Name = `Line{index}`,
						Text = `{Strings.get(line.Key)}   {table.concat(parts, "   ")}`,
					}),
					nextOrder()
				)
			end
			task.wait(LINE_DELAY)
			if showToken ~= token then
				return
			end
			for _, stat in
				{
					Strings.get("RESULT_STAT_TASKS", result.TasksCompleted or 0, result.TasksTotal or 0),
					Strings.get("RESULT_STAT_EVENTS", result.EventsDiscovered or 0),
				}
			do
				add(
					Components.label({
						Name = "Stat",
						Text = stat,
						Color = Theme.Colors.TextDim,
						TextSize = Theme.TextSizes.Small,
					}),
					nextOrder()
				)
			end
			add(
				Components.label({
					Name = "Total",
					Text = `XP +{result.TotalXP or 0}      CASH +{result.TotalCash or 0}`,
					Font = Theme.Fonts.Bold,
					TextSize = Theme.TextSizes.Heading,
					AlignX = Enum.TextXAlignment.Center,
				}),
				nextOrder()
			)
			if (result.NewLevel or 0) > (result.OldLevel or 0) then
				add(
					Components.label({
						Name = "NewLevel",
						Text = Strings.get("RESULT_NEW_LEVEL", result.NewLevel),
						Font = Theme.Fonts.Bold,
						TextSize = Theme.TextSizes.Heading,
						AlignX = Enum.TextXAlignment.Center,
					}),
					nextOrder()
				)
			end
			for index, eventId in result.NewDiscoveries or {} do
				add(
					Components.label({
						Name = `NewEvent{index}`,
						Text = `{Strings.get("RESULT_NEW_EVENT")}  {Strings.get(`EVENT_NAME_{eventId}`)}`,
						Font = Theme.Fonts.Bold,
						Color = Theme.Colors.Danger,
						AlignX = Enum.TextXAlignment.Center,
					}),
					nextOrder()
				)
			end
			add(
				Components.button({
					Name = "ContinueButton",
					Text = Strings.get("RESULT_CONTINUE"),
					Style = "Primary",
					OnActivated = onContinue,
				}),
				nextOrder()
			)
		end)
	end

	function screen:Hide()
		showToken += 1
		gui.Enabled = false
		clear()
	end

	function screen:IsVisible(): boolean
		return gui.Enabled
	end

	gui.Parent = parent
	return screen
end

return ResultsScreen
