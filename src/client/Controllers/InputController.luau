--!strict
-- Detecta o tipo de controle do jogador (teclado/mouse, toque ou controle) e centraliza os atalhos.
-- Nenhum outro módulo deve ouvir UserInputService.InputBegan para ações do jogo: use BindAction.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Modules.Log)
local Signal = require(Shared.Modules.Signal)

export type InputType = "KeyboardMouse" | "Touch" | "Gamepad"

export type ActionBindings = {
	Keyboard: Enum.KeyCode?,
	Gamepad: Enum.KeyCode?,
}

type Action = {
	bindings: ActionBindings,
	callback: () -> (),
}

local log = Log.new("InputController")

local InputController = {}

-- (newInputType) quando o jogador troca de teclado para controle, toque etc.
InputController.InputTypeChanged = Signal.new()

local currentInputType: InputType = "KeyboardMouse"
local actions: { [string]: Action } = {}

local function classify(userInputType: Enum.UserInputType): InputType?
	if userInputType == Enum.UserInputType.Touch then
		return "Touch"
	end
	if string.match(userInputType.Name, "^Gamepad") then
		return "Gamepad"
	end
	if
		userInputType == Enum.UserInputType.Keyboard
		or userInputType == Enum.UserInputType.MouseMovement
		or userInputType == Enum.UserInputType.MouseButton1
		or userInputType == Enum.UserInputType.MouseButton2
		or userInputType == Enum.UserInputType.MouseButton3
		or userInputType == Enum.UserInputType.MouseWheel
	then
		return "KeyboardMouse"
	end
	return nil -- Ex.: Focus, Accelerometer: não mudam o tipo de controle.
end

local function detectInitialInputType(): InputType
	local fromLastInput: InputType? = classify(UserInputService:GetLastInputType())
	if fromLastInput ~= nil then
		return fromLastInput
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Gamepad"
	end
	return "KeyboardMouse"
end

function InputController:GetInputType(): InputType
	return currentInputType
end

function InputController:IsTouch(): boolean
	return currentInputType == "Touch"
end

-- Registra uma ação. Ex.:
-- InputController:BindAction("Interact", { Keyboard = Enum.KeyCode.E, Gamepad = Enum.KeyCode.ButtonX }, fn)
-- No celular, ações são acionadas por botões na tela (UI), não por aqui.
function InputController:BindAction(actionName: string, bindings: ActionBindings, callback: () -> ())
	if actions[actionName] then
		log:Warn("Ação %s já registrada; substituindo.", actionName)
	end
	actions[actionName] = { bindings = bindings, callback = callback }
end

function InputController:UnbindAction(actionName: string)
	actions[actionName] = nil
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	-- gameProcessed = true quando o jogador está digitando no chat ou clicando em um botão da UI.
	if gameProcessed then
		return
	end
	for actionName, action in actions do
		local bindings = action.bindings
		if input.KeyCode == bindings.Keyboard or input.KeyCode == bindings.Gamepad then
			local ok, err = pcall(function()
				action.callback()
			end)
			if not ok then
				log:Error("Erro na ação %s: %s", actionName, tostring(err))
			end
		end
	end
end

function InputController:Init()
	currentInputType = detectInitialInputType()
end

function InputController:Start()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.LastInputTypeChanged:Connect(function(userInputType: Enum.UserInputType)
		local inputType: InputType? = classify(userInputType)
		if inputType ~= nil and inputType ~= currentInputType then
			currentInputType = inputType
			log:Debug("Tipo de controle: %s", inputType)
			InputController.InputTypeChanged:Fire(inputType)
		end
	end)
	log:Debug("Tipo de controle inicial: %s", currentInputType)
end

return InputController
