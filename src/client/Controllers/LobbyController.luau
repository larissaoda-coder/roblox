--!strict
-- Liga a tela do lobby (LobbyScreen) ao servidor (LobbyService).
-- O cliente só PEDE ações; quem decide se são válidas é sempre o servidor.

local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ProductDefinitions = require(Shared.Definitions.ProductDefinitions)
local Strings = require(Shared.Definitions.Strings)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Log = require(Shared.Modules.Log)
local Net = require(Shared.Modules.Net)

local InputController = require(script.Parent.InputController)
local NotificationController = require(script.Parent.NotificationController)
local SettingsController = require(script.Parent.SettingsController)
local LobbyScreen = require(script.Parent.Parent.UI.Screens.LobbyScreen)
local Panels = script.Parent.Parent.UI.Panels
local InventoryPanel = require(Panels.InventoryPanel)
local LeaderboardPanel = require(Panels.LeaderboardPanel)
local SettingsPanel = require(Panels.SettingsPanel)
local ShopPanel = require(Panels.ShopPanel)

local READY_TIMEOUT = 30

local log = Log.new("LobbyController")

local LobbyController = {}

local screen: LobbyScreen.LobbyScreen? = nil
local busy = false

-- Estado dos painéis da loja/inventário/ranking.
local shopCategory = "FLASHLIGHTS"
local inventoryCategory = "FLASHLIGHTS"
local board = "Level"
local inventory: { [string]: any }? = nil
local leaderboards: { [string]: { any } } = {}

local function errorMessage(code: any): string
	local key = `LOBBY_ERR_{tostring(code)}`
	return Strings.get(if Strings.has(key) then key else "LOBBY_ERR_Unknown")
end

-- Envia uma ação ao servidor e mostra o erro, se houver. Ignora cliques repetidos enquanto espera.
local function perform(remoteName: string, ...: any): any
	local current = screen
	if busy or not current then
		return nil
	end
	busy = true
	local ok, result = Net.Client.invoke(remoteName, ...)
	busy = false
	if not ok then
		current:ShowMessage(errorMessage(result))
		return nil
	elseif type(result) == "table" and result.Success == false then
		local key = `SHOP_ERR_{tostring(result.Error)}`
		current:ShowMessage(if Strings.has(key) then Strings.get(key) else errorMessage(result.Error))
	end
	return result
end

local function refreshInventory()
	local ok, snapshot = Net.Client.invoke("GetInventory")
	if ok and type(snapshot) == "table" then
		inventory = snapshot
		if screen then
			screen:Refresh()
		end
	end
end

local function refreshLeaderboard(boardName: string)
	local ok, entries = Net.Client.invoke("GetLeaderboard", boardName)
	if ok and type(entries) == "table" then
		leaderboards[boardName] = entries
		if screen then
			screen:Refresh()
		end
	end
end

local function applyInventoryResult(result: any, successKey: string?)
	if type(result) == "table" and type(result.Inventory) == "table" then
		inventory = result.Inventory
	end
	if type(result) == "table" and result.Success and successKey then
		NotificationController:ShowKey(successKey)
	end
	if screen then
		screen:Refresh()
	end
end

local function renderExternal(panel: string, content: Frame)
	local player = Players.LocalPlayer
	if panel == "Shop" then
		ShopPanel.render(content, {
			Category = shopCategory,
			Level = tonumber(player:GetAttribute("Level")) or 1,
			Cash = tonumber(player:GetAttribute("Cash")) or 0,
			Tokens = tonumber(player:GetAttribute("NightTokens")) or 0,
			Vip = player:GetAttribute("VIP") == true,
			Inventory = inventory :: any,
		}, {
			SelectCategory = function(category: string)
				shopCategory = category
				if screen then
					screen:Refresh()
				end
			end,
			Buy = function(itemId: string)
				applyInventoryResult(perform("PurchaseItem", itemId), "SHOP_BOUGHT")
			end,
			BuyProduct = function(productKey: string)
				local product = ProductDefinitions.DevProducts[productKey]
				local id = product and ProductDefinitions.numericId(product.Id)
				if id then
					pcall(function()
						MarketplaceService:PromptProductPurchase(player, id)
					end)
				end
			end,
			BuyPass = function(passKey: string)
				local pass = ProductDefinitions.GamePasses[passKey]
				local id = pass and ProductDefinitions.numericId(pass.Id)
				if id then
					pcall(function()
						MarketplaceService:PromptGamePassPurchase(player, id)
					end)
				end
			end,
		})
	elseif panel == "Inventory" then
		InventoryPanel.render(content, { Category = inventoryCategory, Inventory = inventory :: any }, {
			SelectCategory = function(category: string)
				inventoryCategory = category
				if screen then
					screen:Refresh()
				end
			end,
			Equip = function(itemId: string)
				applyInventoryResult(perform("EquipItem", itemId), nil)
			end,
		})
	elseif panel == "Leaderboard" then
		LeaderboardPanel.render(content, { Board = board, Entries = leaderboards[board] :: any }, {
			SelectBoard = function(boardName: string)
				board = boardName
				if screen then
					screen:Refresh()
				end
				task.spawn(refreshLeaderboard, boardName)
			end,
		})
	elseif panel == "Settings" then
		SettingsPanel.render(content, SettingsController:GetAll(), {
			Set = function(key: string, value: any)
				SettingsController:Set(key, value)
				if screen then
					screen:Refresh()
				end
			end,
		})
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
		RenderExternal = renderExternal,
		OnPanelOpened = function(panel)
			if panel == "Profile" then
				task.spawn(refreshProfile)
			elseif panel == "Shop" or panel == "Inventory" then
				task.spawn(refreshInventory)
			elseif panel == "Leaderboard" then
				task.spawn(refreshLeaderboard, board)
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

	-- Saldo/nível/VIP mudaram: atualiza a loja se estiver aberta.
	for _, attribute in { "Cash", "NightTokens", "Level", "VIP" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if newScreen:GetOpenPanel() == "Shop" then
				newScreen:Refresh()
			end
		end)
	end

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
