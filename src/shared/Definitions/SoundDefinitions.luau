--!strict
-- Sons do jogo. NÃO inventamos IDs de áudio: todo SoundId abaixo vazio ("") precisa ser preenchido por você.
--
-- COMO PREENCHER:
--   1. No Studio: View > Toolbox > Audio (ou create.roblox.com > Creator Store > Audio).
--   2. Escolha um som, copie o ID numérico e cole aqui como "rbxassetid://NUMERO".
-- Enquanto o SoundId estiver vazio, o jogo funciona normalmente: o som não toca, mas a LEGENDA aparece
-- (se o jogador ativou legendas). Sons "rbxasset://" são arquivos que já vêm com o Roblox.
--
-- Group: "Effects" | "Ambience" | "Music" | "Voice" | "UI"

export type SoundDefinition = {
	Id: string,
	SoundId: string,
	Group: "Effects" | "Ambience" | "Music" | "Voice" | "UI",
	Volume: number,
	Looped: boolean,
	MaxDistance: number, -- até onde se ouve (studs)
	SubtitleKey: string?, -- texto mostrado nas legendas
}

local function sound(
	id: string,
	soundId: string,
	group: "Effects" | "Ambience" | "Music" | "Voice" | "UI",
	volume: number,
	maxDistance: number,
	subtitleKey: string?,
	looped: boolean?
): SoundDefinition
	return {
		Id = id,
		SoundId = soundId,
		Group = group,
		Volume = volume,
		Looped = looped == true,
		MaxDistance = maxDistance,
		SubtitleKey = subtitleKey,
	}
end

local SOUNDS: { SoundDefinition } = {
	-- Ambiente
	sound("NightAmbience", "", "Ambience", 0.5, 0, nil, true),
	sound("Rain", "", "Ambience", 0.6, 0, nil, true),
	sound("Thunder", "", "Ambience", 0.9, 0, "SUB_THUNDER"),
	sound("GeneratorHum", "", "Ambience", 0.4, 40, nil, true),
	sound("FridgeHum", "", "Ambience", 0.25, 18, nil, true),

	-- Mundo
	sound("DoorOpen", "", "Effects", 0.7, 50, "SUB_DOOR_OPEN"),
	sound("DoorClose", "", "Effects", 0.7, 50, "SUB_DOOR_CLOSE"),
	sound("DoorSlam", "", "Effects", 1, 90, "SUB_DOOR_SLAM"),
	sound("LightSwitch", "rbxasset://sounds/clickfast.wav", "Effects", 0.6, 20, nil),
	sound("LightBuzz", "", "Effects", 0.5, 30, "SUB_LIGHT_BUZZ"),
	sound("PowerDown", "", "Effects", 1, 200, "SUB_POWER_DOWN"),
	sound("PowerUp", "", "Effects", 0.8, 200, "SUB_POWER_UP"),
	sound("ProductFall", "", "Effects", 0.8, 45, "SUB_PRODUCT_FALL"),
	sound("PhoneRing", "", "Effects", 0.9, 80, "SUB_PHONE_RING", true),
	sound("PhonePickUp", "", "Effects", 0.6, 15, nil),
	sound("PhoneStatic", "", "Voice", 0.6, 15, "SUB_PHONE_STATIC"),
	sound("TaskComplete", "", "UI", 0.5, 0, nil),

	-- Estranho
	sound("Footsteps", "rbxasset://sounds/action_footsteps_plastic.mp3", "Effects", 0.8, 45, "SUB_FOOTSTEPS"),
	sound("StockroomNoise", "", "Effects", 0.9, 60, "SUB_STOCKROOM_NOISE"),
	sound("Knock", "", "Effects", 0.9, 60, "SUB_KNOCK"),
	sound("Whisper", "", "Voice", 0.5, 20, "SUB_WHISPER"),
	sound("DistantScream", "", "Effects", 0.7, 400, "SUB_DISTANT_SCREAM"),
	sound("EntityBreath", "", "Voice", 0.6, 25, "SUB_BREATHING"),
	sound("EntityStinger", "", "Effects", 0.9, 60, "SUB_STINGER"),
	sound("Heartbeat", "", "UI", 0.6, 0, nil, true),
	sound("CameraStatic", "", "UI", 0.4, 0, nil, true),
}

local byId: { [string]: SoundDefinition } = {}
for _, definition in SOUNDS do
	byId[definition.Id] = definition
end

local SoundDefinitions = {}

function SoundDefinitions.get(soundId: string): SoundDefinition?
	return byId[soundId]
end

function SoundDefinitions.getAll(): { SoundDefinition }
	return table.clone(SOUNDS)
end

return SoundDefinitions
