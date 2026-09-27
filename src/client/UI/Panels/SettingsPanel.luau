--!strict
-- Configurações: volumes e sensibilidade com − / + (fácil no toque e no controle), liga/desliga para o resto.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SettingsDefinitions = require(Shared.Definitions.SettingsDefinitions)
local Strings = require(Shared.Definitions.Strings)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)
local PanelKit = require(script.Parent.PanelKit)

export type SettingsActions = { Set: (key: string, value: any) -> () }

local STEP = 0.1

local SettingsPanel = {}

function SettingsPanel.render(content: Instance, values: { [string]: any }, actions: SettingsActions)
	local order = PanelKit.counter()
	for _, setting in SettingsDefinitions.getAll() do
		local value = values[setting.Key]
		if setting.Kind == "boolean" then
			PanelKit.row(content, `Setting_{setting.Key}`, Strings.get(setting.LabelKey), nil, order, {
				Name = `Toggle_{setting.Key}`,
				Text = Strings.get(if value then "SETTING_ON" else "SETTING_OFF"),
				Style = if value then "Primary" else "Secondary",
				OnActivated = function()
					actions.Set(setting.Key, not value)
				end,
			})
		else
			local row = PanelKit.row(
				content,
				`Setting_{setting.Key}`,
				Strings.get(setting.LabelKey),
				`{math.floor((value or 0) * 100 + 0.5)}%`,
				order,
				nil
			)
			for index, delta in { -STEP, STEP } do
				local button = Components.button({
					Name = if delta < 0 then `Decrease_{setting.Key}` else `Increase_{setting.Key}`,
					Text = if delta < 0 then "−" else "+",
					Size = UDim2.new(0, 64, 0, Components.getButtonHeight()),
					OnActivated = function()
						actions.Set(setting.Key, math.floor(((value or 0) + delta) * 10 + 0.5) / 10)
					end,
				})
				button.AnchorPoint = Vector2.new(1, 0.5)
				button.Position = UDim2.new(1, if index == 1 then -72 else 0, 0.5, 0)
				button.Parent = row
			end
			local subtitle = row:FindFirstChild("Subtitle")
			if subtitle and subtitle:IsA("TextLabel") then
				subtitle.TextColor3 = Theme.Colors.Text
			end
		end
	end
end

return SettingsPanel
