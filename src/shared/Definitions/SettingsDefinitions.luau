--!strict
-- Configurações do jogador (salvas no perfil). O servidor valida cada valor com estas regras.

export type SettingDefinition = {
	Key: string,
	Kind: "number" | "boolean",
	Default: number | boolean,
	Min: number?,
	Max: number?,
	LabelKey: string,
}

local SETTINGS: { SettingDefinition } = {
	{ Key = "MasterVolume", Kind = "number", Default = 1, Min = 0, Max = 1, LabelKey = "SETTING_MASTER" },
	{ Key = "MusicVolume", Kind = "number", Default = 0.6, Min = 0, Max = 1, LabelKey = "SETTING_MUSIC" },
	{ Key = "EffectsVolume", Kind = "number", Default = 1, Min = 0, Max = 1, LabelKey = "SETTING_EFFECTS" },
	{
		Key = "Sensitivity",
		Kind = "number",
		Default = 0.5,
		Min = 0.1,
		Max = 1,
		LabelKey = "SETTING_SENSITIVITY",
	},
	{ Key = "Subtitles", Kind = "boolean", Default = true, LabelKey = "SETTING_SUBTITLES" },
	{ Key = "ReducedFlashes", Kind = "boolean", Default = false, LabelKey = "SETTING_REDUCED_FLASHES" },
	{ Key = "ReducedEffects", Kind = "boolean", Default = false, LabelKey = "SETTING_REDUCED_EFFECTS" },
	{ Key = "CameraShake", Kind = "boolean", Default = true, LabelKey = "SETTING_CAMERA_SHAKE" },
}

local byKey: { [string]: SettingDefinition } = {}
for _, setting in SETTINGS do
	byKey[setting.Key] = setting
end

local SettingsDefinitions = {}

function SettingsDefinitions.get(key: string): SettingDefinition?
	return byKey[key]
end

function SettingsDefinitions.getAll(): { SettingDefinition }
	return table.clone(SETTINGS)
end

function SettingsDefinitions.defaults(): { [string]: any }
	local values = {}
	for _, setting in SETTINGS do
		values[setting.Key] = setting.Default
	end
	return values
end

-- Retorna o valor limpo (dentro dos limites) ou nil se for inválido.
function SettingsDefinitions.sanitize(key: string, value: any): any
	local setting = byKey[key]
	if not setting or type(value) ~= setting.Kind then
		return nil
	end
	if setting.Kind == "number" then
		if value ~= value then
			return nil
		end
		return math.clamp(value, setting.Min or -math.huge, setting.Max or math.huge)
	end
	return value
end

return SettingsDefinitions
