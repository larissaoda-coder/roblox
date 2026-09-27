--!strict
-- Liga a tela do lobby (LobbyScreen) ao servidor (LobbyService).
-- O cliente só PEDE ações; quem decide se são válidas é sempre o servidor.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Definitions.Strings)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local InputController = require(script.Parent.InputController)
local LobbyScreen = require(script.Parent.Parent.UI.Screens.LobbyScreen)

local READY_TIMEOUT = 30

local log = Log.new("LobbyController")

local LobbyController = {}

local screen: LobbyScreen.LobbyScreen? = nil
local busy = false

local function errorMessage(code: any): string
	local key = `LOBBY_ERR_{tostring(code)}`
	return Strings.get(if Strings.has(key) then key else "LOBBY_ERR_Unknown")
end

-- Envia uma ação ao servidor e mostra o erro, se houver. Ignora cliques repetidos enquanto espera.
local function perform(remoteName: string, ...: any)
	local current = screen
	if busy or not current then
		return
	end
	busy = true
	local ok, result = Net.Client.invoke(remoteName, ...)
	busy = false
	if not ok then
		current:ShowMessage(errorMessage(result))
	elseif type(result) == "table" and result.Success == false then
		current:ShowMessage(errorMessage(result.Error))
	end
end

local function refreshProfile()
	local current = screen
	if not current then
		return
	end
	local ok, profile = Net.Client.invoke("GetMyProfile")
	if ok then
		current:SetProfile(profile)
	end
end

local function waitForReady(player: Player): boolean
	local startedAt = os.clock()
	while player:GetAttribute("Ready") ~= true do
		if os.clock() - startedAt > READY_TIMEOUT then
			return false
		end
		task.wait(0.1)
	end
	return true
end

function LobbyController:GetScreen(): LobbyScreen.LobbyScreen?
	return screen
end

function LobbyController:Init() end

function LobbyController:Start()
	local player = Players.LocalPlayer
	if not waitForReady(player) then
		log:Error("Dados do jogador não ficaram prontos em %ds.", READY_TIMEOUT)
		return
	end
	local playerGui = InstanceUtil.waitForChild(player, "PlayerGui")

	local newScreen = LobbyScreen.new(playerGui, player.UserId, {
		OnCreate = function(mapId: string)
			perform("CreateParty", mapId)
		end,
		OnJoin = function(partyId: string)
			perform("JoinParty", partyId)
		end,
		OnLeave = function()
			perform("LeaveParty")
		end,
		OnSetReady = function(ready: boolean)
			perform("SetReady", ready)
		end,
		OnStart = function()
			perform("StartParty")
		end,
		OnPanelOpened = function(panel)
			if panel == "Profile" then
				task.spawn(refreshProfile)
			end
			-- No controle, seleciona o primeiro botão para navegar com o direcional.
			local current = screen
			if current and InputController:GetInputType() == "Gamepad" then
				GuiService.SelectedObject = current:GetFirstSelectable()
			end
		end,
	})
	screen = newScreen

	newScreen:SetTouchMode(InputController:IsTouch())
	InputController.InputTypeChanged:Connect(function(inputType)
		newScreen:SetTouchMode(inputType == "Touch")
	end)

	local camera = workspace.CurrentCamera
	newScreen:SetViewportSize(camera.ViewportSize)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		newScreen:SetViewportSize(camera.ViewportSize)
	end)

	local function updateVisibility()
		newScreen:SetVisible(player:GetAttribute("State") == "Lobby")
	end
	updateVisibility()
	player:GetAttributeChangedSignal("State"):Connect(updateVisibility)

	Net.Client.on("LobbyStateChanged", function(state)
		newScreen:SetLobbyState(state)
	end)
	local ok, state = Net.Client.invoke("RequestLobbyState")
	if ok then
		newScreen:SetLobbyState(state)
	end
	log:Debug("Lobby pronto.")
end

return LobbyController
