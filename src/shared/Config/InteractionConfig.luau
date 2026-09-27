--!strict
-- Configuração do sistema de interação.
--
-- Para tornar QUALQUER objeto interativo no Studio:
--   1. Selecione a Part (ou Model) → Properties → Tags → adicione a tag "Interactable".
--   2. Adicione os atributos (Properties → Attributes → +):
--        InteractionType (string)  ex.: "Door", "Task", "Phone"   (obrigatório)
--        PromptKey       (string)  chave de texto em Strings, ex.: "PROMPT_OPEN_DOOR"
--        HoldDuration    (number)  segundos segurando o botão (0 = toque rápido)
--        MaxDistance     (number)  distância máxima em studs
--        RequiresShift   (boolean) false = funciona também no lobby

local InteractionConfig = {
	TAG = "Interactable",

	DEFAULT_MAX_DISTANCE = 8,
	DEFAULT_HOLD_DURATION = 0,
	DEFAULT_PROMPT_KEY = "PROMPT_INTERACT",

	-- Tolerância extra de distância no servidor (latência/movimento).
	SERVER_DISTANCE_TOLERANCE = 6,
	-- Aceita segurar um pouco menos que o tempo exigido (latência).
	HOLD_TOLERANCE = 0.8,
	-- Tempo mínimo entre duas interações do mesmo jogador.
	PLAYER_COOLDOWN = 0.35,

	KEYBOARD_KEY = Enum.KeyCode.E,
	GAMEPAD_KEY = Enum.KeyCode.ButtonX,
}

return table.freeze(InteractionConfig)
