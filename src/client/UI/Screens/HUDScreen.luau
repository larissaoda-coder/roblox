--!strict
-- HUD da partida. Minimalista: título + relógio no topo, objetivo logo abaixo e um aviso central
-- para momentos importantes (início do turno, turno concluído).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage.Shared.Definitions.Strings)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

export type TaskLine = { Text: string, Completed: boolean }

export type HUDScreen = {
	SetTasks: (self: HUDScreen, lines: { TaskLine }) -> (),
	Gui: ScreenGui,
	SetVisible: (self: HUDScreen, visible: boolean) -> (),
	SetClock: (self: HUDScreen, text: string) -> (),
	SetObjective: (self: HUDScreen, text: string?) -> (),
	SetBanner: (self: HUDScreen, text: string?) -> (),
	SetViewportSize: (self: HUDScreen, viewportSize: Vector2) -> (),
	Destroy: (self: HUDScreen) -> (),
}

local HUDScreen = {}

function HUDScreen.new(parent: Instance): HUDScreen
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = Theme.DisplayOrder.HUD
	gui.Enabled = false

	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BackgroundTransparency = 1
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 56)
	top.Size = UDim2.new(0, 420, 0, 0)
	top.AutomaticSize = Enum.AutomaticSize.Y
	top.Parent = gui
	local topList = Components.list(top, 2)
	topList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local topScale = Instance.new("UIScale")
	topScale.Name = "Scale"
	topScale.Parent = top

	Components.label({
		Name = "Title",
		Text = Strings.get("HUD_TITLE"),
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSizes.Small,
		Color = Theme.Colors.TextDim,
		AlignX = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
	}).Parent =
		top

	local clock = Components.label({
		Name = "Clock",
		Text = "04:00 AM",
		Font = Theme.Fonts.Mono,
		TextSize = Theme.TextSizes.Title,
		AlignX = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
	})
	clock.Parent = top

	local objective = Components.label({
		Name = "Objective",
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSizes.Body,
		AlignX = Enum.TextXAlignment.Center,
		LayoutOrder = 3,
	})
	objective.Visible = false
	objective.Parent = top

	-- Lista de tarefas (canto esquerdo, abaixo do chat).
	local taskPanel = Instance.new("Frame")
	taskPanel.Name = "Tasks"
	taskPanel.BackgroundTransparency = 1
	taskPanel.Position = UDim2.new(0, 16, 0.32, 0)
	taskPanel.Size = UDim2.new(0, 280, 0, 0)
	taskPanel.AutomaticSize = Enum.AutomaticSize.Y
	taskPanel.Visible = false
	taskPanel.Parent = gui
	Components.list(taskPanel, 4)
	local taskScale = Instance.new("UIScale")
	taskScale.Name = "Scale"
	taskScale.Parent = taskPanel
	Components.label({
		Name = "Header",
		Text = Strings.get("HUD_TASKS"),
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSizes.Small,
		Color = Theme.Colors.TextDim,
		LayoutOrder = 0,
	}).Parent =
		taskPanel

	local banner = Components.label({
		Name = "Banner",
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = 40,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -48, 0, 60),
	})
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.new(0.5, 0, 0.4, 0)
	banner.Visible = false
	banner.Parent = gui

	local screen = { Gui = gui } :: HUDScreen

	function screen:SetVisible(visible: boolean)
		gui.Enabled = visible
	end

	function screen:SetClock(text: string)
		clock.Text = text
	end

	function screen:SetObjective(text: string?)
		objective.Visible = text ~= nil
		objective.Text = if text then `{Strings.get("HUD_OBJECTIVE_LABEL")}: {text}` else ""
	end

	function screen:SetBanner(text: string?)
		banner.Visible = text ~= nil
		banner.Text = text or ""
	end

	function screen:SetTasks(lines: { TaskLine })
		for _, child in taskPanel:GetChildren() do
			if child:IsA("TextLabel") and child.Name ~= "Header" then
				child:Destroy()
			end
		end
		taskPanel.Visible = #lines > 0
		for index, line in lines do
			Components.label({
				Name = `Task{index}`,
				Text = (if line.Completed then "✓  " else "•  ") .. line.Text,
				TextSize = Theme.TextSizes.Small,
				Color = if line.Completed then Theme.Colors.TextDim else Theme.Colors.Text,
				LayoutOrder = index,
			}).Parent =
				taskPanel
		end
	end

	function screen:SetViewportSize(viewportSize: Vector2)
		local scale =
			math.clamp(viewportSize.Y / Theme.Scale.REFERENCE_HEIGHT, Theme.Scale.MIN, Theme.Scale.MAX)
		topScale.Scale = scale
		taskScale.Scale = scale
	end

	function screen:Destroy()
		gui:Destroy()
	end

	gui.Parent = parent
	return screen
end

return HUDScreen
