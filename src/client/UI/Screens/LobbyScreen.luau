--!strict
-- Interface do lobby: título, menu lateral, indicador do turno e janela central (Jogar / Turno / Perfil / Créditos).
-- Esta tela SÓ desenha. Ações (criar, entrar, pronto…) são repassadas ao LobbyController pelos callbacks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MapDefinitions = require(Shared.Definitions.MapDefinitions)
local Strings = require(Shared.Definitions.Strings)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

export type PanelName =
	"Play"
	| "Party"
	| "Profile"
	| "Credits"
	| "Shop"
	| "Inventory"
	| "Leaderboard"
	| "Settings"

export type Callbacks = {
	OnCreate: (mapId: string) -> (),
	OnJoin: (partyId: string) -> (),
	OnLeave: () -> (),
	OnSetReady: (ready: boolean) -> (),
	OnStart: () -> (),
	OnPanelOpened: (panel: PanelName) -> (),
	-- Painéis desenhados fora desta tela (Loja, Inventário, Ranking, Configurações).
	RenderExternal: (panel: PanelName, content: Frame) -> (),
}

export type PartyMember = { UserId: number, Name: string, Ready: boolean }

export type PartyInfo = {
	Id: string,
	MapId: string,
	HostUserId: number,
	MaxPlayers: number,
	Launching: boolean,
	Members: { PartyMember },
}

export type LobbyState = { Parties: { PartyInfo } }

export type LobbyScreen = {
	Gui: ScreenGui,
	SetLobbyState: (self: LobbyScreen, state: LobbyState) -> (),
	SetProfile: (self: LobbyScreen, profile: { [string]: any }?) -> (),
	OpenPanel: (self: LobbyScreen, panel: PanelName) -> (),
	ClosePanel: (self: LobbyScreen) -> (),
	GetOpenPanel: (self: LobbyScreen) -> PanelName?,
	ShowMessage: (self: LobbyScreen, text: string) -> (),
	SetVisible: (self: LobbyScreen, visible: boolean) -> (),
	SetTouchMode: (self: LobbyScreen, isTouch: boolean) -> (),
	SetViewportSize: (self: LobbyScreen, viewportSize: Vector2) -> (),
	GetFirstSelectable: (self: LobbyScreen) -> GuiObject?,
	Refresh: (self: LobbyScreen) -> (),
	Destroy: (self: LobbyScreen) -> (),
}

type MenuEntry = { Id: string, TextKey: string, Panel: PanelName? }

local MENU: { MenuEntry } = {
	{ Id = "Play", TextKey = "MENU_PLAY", Panel = "Play" },
	{ Id = "Profile", TextKey = "MENU_PROFILE", Panel = "Profile" },
	{ Id = "Shop", TextKey = "MENU_SHOP", Panel = "Shop" },
	{ Id = "Inventory", TextKey = "MENU_INVENTORY", Panel = "Inventory" },
	{ Id = "Leaderboard", TextKey = "MENU_LEADERBOARD", Panel = "Leaderboard" },
	{ Id = "Settings", TextKey = "MENU_SETTINGS", Panel = "Settings" },
	{ Id = "Credits", TextKey = "MENU_CREDITS", Panel = "Credits" },
}

local PANEL_TITLES: { [PanelName]: string } = {
	Play = "PLAY_TITLE",
	Party = "PARTY_TITLE",
	Profile = "PROFILE_TITLE",
	Credits = "CREDITS_TITLE",
	Shop = "SHOP_TITLE",
	Inventory = "INVENTORY_TITLE",
	Leaderboard = "LEADERBOARD_TITLE",
	Settings = "SETTINGS_TITLE",
}

local STAT_ORDER = {
	"ShiftsCompleted",
	"ShiftsSurvived",
	"TasksCompleted",
	"EventsDiscovered",
	"SecretsFound",
	"Deaths",
	"PlayTime",
	"CashEarned",
}

local TOAST_SECONDS = 3
local SIDE_BUTTON_WIDTH = 130

local function mapName(mapId: string): string
	local map = MapDefinitions.get(mapId)
	return if map then Strings.get(map.NameKey) else mapId
end

local function sectionLabel(text: string, layoutOrder: number): TextLabel
	return Components.label({
		Text = text,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSizes.Small,
		Color = Theme.Colors.TextDim,
		LayoutOrder = layoutOrder,
	})
end

-- Botão alinhado à direita dentro de uma linha.
local function sideButton(row: Frame, props: Components.ButtonProps): TextButton
	local button = Components.button(props)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, 0, 0.5, 0)
	button.Size = UDim2.new(0, SIDE_BUTTON_WIDTH, 0, Components.getButtonHeight())
	button.Parent = row
	return button
end

local function rowText(row: Frame, title: string, subtitle: string?)
	local titleLabel = Components.label({
		Name = "Title",
		Text = title,
		Font = Theme.Fonts.Bold,
		Size = UDim2.new(1, -(SIDE_BUTTON_WIDTH + 12), 0, 22),
	})
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Parent = row
	if subtitle then
		local subtitleLabel = Components.label({
			Name = "Subtitle",
			Text = subtitle,
			TextSize = Theme.TextSizes.Small,
			Color = Theme.Colors.TextDim,
			Size = UDim2.new(1, -(SIDE_BUTTON_WIDTH + 12), 0, 20),
		})
		subtitleLabel.Position = UDim2.new(0, 0, 0, 24)
		subtitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
		subtitleLabel.Parent = row
	end
end

local LobbyScreen = {}

function LobbyScreen.new(parent: Instance, userId: number, callbacks: Callbacks): LobbyScreen
	local lobbyState: LobbyState = { Parties = {} }
	local profile: { [string]: any }? = nil
	local openPanel: PanelName? = nil
	local toastToken = 0
	local menuButtons: { TextButton } = {}

	-- Estrutura ------------------------------------------------------------------------
	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = Theme.DisplayOrder.Menus

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	-- Cada bloco tem seu próprio UIScale (escala a partir do seu ponto de ancoragem).
	-- A janela central não é escalada: ela já usa tamanho proporcional à tela.
	local uiScales: { UIScale } = {}
	local function addScale(target: GuiObject)
		local uiScale = Instance.new("UIScale")
		uiScale.Name = "Scale"
		uiScale.Parent = target
		table.insert(uiScales, uiScale)
	end

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.new(0, 24, 0, 64)
	header.Size = UDim2.new(0, 420, 0, 0)
	header.AutomaticSize = Enum.AutomaticSize.Y
	header.Parent = root
	Components.list(header, 2)
	Components.label({
		Name = "Title",
		Text = Strings.get("GAME_TITLE"),
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSizes.Title,
		LayoutOrder = 1,
	}).Parent =
		header
	Components.label({
		Name = "Subtitle",
		Text = Strings.get("LOBBY_SUBTITLE"),
		Color = Theme.Colors.TextDim,
		LayoutOrder = 2,
	}).Parent =
		header

	-- Menu à direita: fica longe do joystick do celular (canto inferior esquerdo).
	local menu = Instance.new("ScrollingFrame")
	menu.Name = "Menu"
	menu.AnchorPoint = Vector2.new(1, 0.5)
	menu.Position = UDim2.new(1, -24, 0.5, 0)
	menu.Size = UDim2.new(0, 240, 0.62, 0)
	menu.BackgroundTransparency = 1
	menu.BorderSizePixel = 0
	menu.ScrollBarThickness = 4
	menu.CanvasSize = UDim2.new()
	menu.AutomaticCanvasSize = Enum.AutomaticSize.Y
	menu.Parent = root
	Components.list(menu)
	addScale(menu)

	local chip = Components.button({
		Name = "PartyChip",
		Text = "",
		Size = UDim2.new(0, 340, 0, 40),
	})
	-- Embaixo, no centro: entre o joystick (esquerda) e o botão de pulo (direita) do celular.
	chip.AnchorPoint = Vector2.new(0.5, 1)
	chip.Position = UDim2.new(0.5, 0, 1, -24)
	chip.Visible = false
	chip.Parent = root
	addScale(chip)

	local modal = Components.panel("Modal", Theme.Colors.Panel)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.fromScale(0.92, 0.84)
	modal.Visible = false
	modal.Parent = root
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(Theme.Sizes.ModalMaxWidth, Theme.Sizes.ModalMaxHeight)
	sizeLimit.Parent = modal

	local modalTitle = Components.label({
		Name = "ModalTitle",
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSizes.Heading,
		Size = UDim2.new(1, -88, 0, 36),
	})
	modalTitle.Position = UDim2.new(0, 16, 0, 12)
	modalTitle.Parent = modal

	local closeButton = Components.button({
		Name = "CloseButton",
		Text = "✕",
		Size = UDim2.new(0, 44, 0, 44),
	})
	closeButton.Position = UDim2.new(1, -56, 0, 8)
	closeButton.Parent = modal

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.new(0, 0, 0, 60)
	body.Size = UDim2.new(1, 0, 1, -60)
	body.ScrollBarThickness = 4
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent = modal

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Parent = body
	Components.padding(content)
	Components.list(content)

	local toast = Components.label({
		Name = "Toast",
		Text = "",
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 0, 0, 0),
	})
	toast.AutomaticSize = Enum.AutomaticSize.XY
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -120)
	toast.BackgroundColor3 = Theme.Colors.Background
	toast.BackgroundTransparency = 0.1
	toast.Visible = false
	Components.corner(toast)
	Components.padding(toast, 12)
	local toastLimit = Instance.new("UISizeConstraint")
	toastLimit.MaxSize = Vector2.new(560, math.huge)
	toastLimit.Parent = toast
	toast.Parent = root
	addScale(toast)

	local screen = { Gui = gui } :: LobbyScreen

	-- Helpers -------------------------------------------------------------------------
	local function myParty(): PartyInfo?
		for _, party in lobbyState.Parties do
			for _, member in party.Members do
				if member.UserId == userId then
					return party
				end
			end
		end
		return nil
	end

	local function clearContent()
		for _, child in content:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function renderPlay()
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end

		sectionLabel(Strings.get("PLAY_SELECT_MAP"), nextOrder()).Parent = content
		for _, map in MapDefinitions.getAll() do
			local row = Components.row(`Map_{map.Id}`, nextOrder())
			row.Parent = content
			rowText(row, Strings.get(map.NameKey), Strings.get(map.DescriptionKey))
			sideButton(row, {
				Name = `CreateMap_{map.Id}`,
				Text = Strings.get(if map.Available then "PLAY_CREATE" else "COMING_SOON"),
				Style = if map.Available then "Primary" else "Secondary",
				Disabled = not map.Available,
				OnActivated = function()
					callbacks.OnCreate(map.Id)
				end,
			})
		end

		sectionLabel(Strings.get("PLAY_OPEN_SHIFTS"), nextOrder()).Parent = content
		if #lobbyState.Parties == 0 then
			Components.label({
				Name = "NoShifts",
				Text = Strings.get("PLAY_NO_SHIFTS"),
				Color = Theme.Colors.TextDim,
				LayoutOrder = nextOrder(),
			}).Parent =
				content
			return
		end

		for _, party in lobbyState.Parties do
			local hostName = "?"
			for _, member in party.Members do
				if member.UserId == party.HostUserId then
					hostName = member.Name
				end
			end
			local isFull = #party.Members >= party.MaxPlayers
			local row = Components.row(`Party_{party.Id}`, nextOrder())
			row.Parent = content
			rowText(
				row,
				Strings.get(
					"PLAY_SHIFT_ROW",
					mapName(party.MapId),
					hostName,
					#party.Members,
					party.MaxPlayers
				)
			)
			local textKey = if party.Launching
				then "PLAY_STARTING"
				elseif isFull then "PLAY_FULL"
				else "PLAY_JOIN"
			sideButton(row, {
				Name = `Join_{party.Id}`,
				Text = Strings.get(textKey),
				Style = "Primary",
				Disabled = party.Launching or isFull,
				OnActivated = function()
					callbacks.OnJoin(party.Id)
				end,
			})
		end
	end

	local function renderParty(party: PartyInfo)
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end

		local isHost = party.HostUserId == userId
		local myReady = false
		local allReady = true
		for _, member in party.Members do
			if member.UserId == userId then
				myReady = member.Ready
			end
			allReady = allReady and member.Ready
		end

		sectionLabel(`{mapName(party.MapId)} · {#party.Members}/{party.MaxPlayers}`, nextOrder()).Parent =
			content

		for _, member in party.Members do
			local row = Components.row(`Member_{member.UserId}`, nextOrder(), 48)
			row.Parent = content
			local name = member.Name
			if member.UserId == party.HostUserId then
				name ..= ` · {Strings.get("PARTY_HOST")}`
			end
			local nameLabel = Components.label({
				Name = "Name",
				Text = name,
				Font = Theme.Fonts.Bold,
				Size = UDim2.new(0.6, 0, 1, 0),
			})
			nameLabel.Parent = row
			local status = Components.label({
				Name = "Status",
				Text = Strings.get(if member.Ready then "PARTY_READY" else "PARTY_NOT_READY"),
				Font = Theme.Fonts.Bold,
				TextSize = Theme.TextSizes.Small,
				Color = if member.Ready then Theme.Colors.Success else Theme.Colors.TextDim,
				AlignX = Enum.TextXAlignment.Right,
				Size = UDim2.new(0.4, 0, 1, 0),
			})
			status.Position = UDim2.new(0.6, 0, 0, 0)
			status.Parent = row
		end

		if party.Launching then
			sectionLabel(Strings.get("PLAY_STARTING"), nextOrder()).Parent = content
			return
		end

		Components.button({
			Name = "ReadyButton",
			Text = Strings.get(if myReady then "PARTY_UNSET_READY" else "PARTY_SET_READY"),
			Style = if myReady then "Secondary" else "Primary",
			LayoutOrder = nextOrder(),
			OnActivated = function()
				callbacks.OnSetReady(not myReady)
			end,
		}).Parent =
			content

		if isHost then
			Components.button({
				Name = "StartButton",
				Text = Strings.get("PARTY_START"),
				Style = "Primary",
				Disabled = not allReady,
				LayoutOrder = nextOrder(),
				OnActivated = callbacks.OnStart,
			}).Parent =
				content
		end

		local waitingKey = if not allReady
			then "PARTY_WAITING"
			elseif not isHost then "PARTY_WAITING_HOST"
			else nil
		if waitingKey then
			Components.label({
				Name = "Waiting",
				Text = Strings.get(waitingKey),
				Color = Theme.Colors.TextDim,
				LayoutOrder = nextOrder(),
			}).Parent =
				content
		end

		Components.button({
			Name = "LeaveButton",
			Text = Strings.get("PARTY_LEAVE"),
			Style = "Danger",
			LayoutOrder = nextOrder(),
			OnActivated = callbacks.OnLeave,
		}).Parent =
			content
	end

	local function renderProfile()
		local data = profile
		if not data then
			Components.label({ Name = "Loading", Text = "…", Color = Theme.Colors.TextDim }).Parent =
				content
			return
		end
		local lines = {
			Strings.get("PROFILE_LEVEL", data.Level or 0),
			Strings.get("PROFILE_XP", data.XP or 0),
			Strings.get("PROFILE_CASH", data.Cash or 0),
			Strings.get("PROFILE_TOKENS", data.NightTokens or 0),
		}
		for index, line in lines do
			Components.label({
				Name = `Line{index}`,
				Text = line,
				Font = Theme.Fonts.Bold,
				LayoutOrder = index,
			}).Parent =
				content
		end
		local stats = data.Stats or {}
		for index, statName in STAT_ORDER do
			local value = stats[statName] or 0
			if statName == "PlayTime" then
				value = math.floor(value / 60)
			end
			local row = Components.row(`Stat_{statName}`, #lines + index, 40)
			row.Parent = content
			Components.label({
				Name = "Name",
				Text = Strings.get(`STAT_{statName}`),
				Color = Theme.Colors.TextDim,
				Size = UDim2.new(0.7, 0, 1, 0),
			}).Parent =
				row
			local valueLabel = Components.label({
				Name = "Value",
				Text = tostring(value),
				Font = Theme.Fonts.Bold,
				AlignX = Enum.TextXAlignment.Right,
				Size = UDim2.new(0.3, 0, 1, 0),
			})
			valueLabel.Position = UDim2.new(0.7, 0, 0, 0)
			valueLabel.Parent = row
		end
	end

	local function renderCredits()
		Components.label({ Name = "Body", Text = Strings.get("CREDITS_BODY") }).Parent = content
	end

	local function render()
		local current = openPanel
		if not current then
			return
		end
		local panel: PanelName = current :: PanelName
		local party = myParty()
		-- Quem está em um turno vê o painel do turno no lugar da lista (e vice-versa).
		if panel == "Play" and party then
			panel = "Party"
		elseif panel == "Party" and not party then
			panel = "Play"
		end
		openPanel = panel
		modalTitle.Text = Strings.get(PANEL_TITLES[panel])
		clearContent()
		if panel == "Play" then
			renderPlay()
		elseif panel == "Party" and party then
			renderParty(party)
		elseif panel == "Profile" then
			renderProfile()
		elseif panel == "Credits" then
			renderCredits()
		else
			callbacks.RenderExternal(panel, content)
		end
	end

	local function updateChip()
		local party = myParty()
		chip.Visible = party ~= nil
		if party then
			chip.Text = Strings.get("PARTY_CHIP", mapName(party.MapId), #party.Members, party.MaxPlayers)
		end
	end

	local function buildMenu()
		for _, button in menuButtons do
			button:Destroy()
		end
		table.clear(menuButtons)
		for index, entry in MENU do
			local panel: PanelName? = entry.Panel
			local text = Strings.get(entry.TextKey)
			if not panel then
				text ..= ` · {Strings.get("COMING_SOON")}`
			end
			local button = Components.button({
				Name = `Menu_{entry.Id}`,
				Text = text,
				Style = if entry.Id == "Play" then "Primary" else "Secondary",
				Disabled = panel == nil,
				LayoutOrder = index,
				OnActivated = function()
					if panel then
						screen:OpenPanel(panel)
					end
				end,
			})
			button.Parent = menu
			table.insert(menuButtons, button)
		end
	end

	-- API ------------------------------------------------------------------------------
	function screen:SetLobbyState(state: LobbyState)
		lobbyState = state
		updateChip()
		if openPanel == "Play" or openPanel == "Party" then
			render()
		end
	end

	function screen:SetProfile(newProfile: { [string]: any }?)
		profile = newProfile
		if openPanel == "Profile" then
			render()
		end
	end

	function screen:OpenPanel(panel: PanelName)
		openPanel = panel
		modal.Visible = true
		render()
		callbacks.OnPanelOpened(openPanel :: PanelName)
	end

	function screen:ClosePanel()
		openPanel = nil
		modal.Visible = false
		clearContent()
	end

	function screen:GetOpenPanel(): PanelName?
		return openPanel
	end

	function screen:ShowMessage(text: string)
		toastToken += 1
		local token = toastToken
		toast.Text = text
		toast.Visible = true
		task.delay(TOAST_SECONDS, function()
			if toastToken == token then
				toast.Visible = false
			end
		end)
	end

	function screen:SetVisible(visible: boolean)
		gui.Enabled = visible
	end

	function screen:SetTouchMode(isTouch: boolean)
		Components.setTouchMode(isTouch)
		buildMenu()
		render()
	end

	function screen:SetViewportSize(viewportSize: Vector2)
		local scale =
			math.clamp(viewportSize.Y / Theme.Scale.REFERENCE_HEIGHT, Theme.Scale.MIN, Theme.Scale.MAX)
		for _, uiScale in uiScales do
			uiScale.Scale = scale
		end
	end

	function screen:GetFirstSelectable(): GuiObject?
		local containers: { Instance } = if modal.Visible then { content } else { menu }
		for _, container in containers do
			for _, descendant in container:GetDescendants() do
				if descendant:IsA("TextButton") and descendant:GetAttribute("Disabled") ~= true then
					return descendant
				end
			end
		end
		return nil
	end

	function screen:Refresh()
		if openPanel then
			render()
		end
	end

	function screen:Destroy()
		gui:Destroy()
	end

	closeButton.Activated:Connect(function()
		screen:ClosePanel()
	end)
	chip.Activated:Connect(function()
		screen:OpenPanel("Party")
	end)

	buildMenu()
	gui.Parent = parent
	return screen
end

return LobbyScreen
