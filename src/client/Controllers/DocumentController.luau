--!strict
-- Mostra documentos da história (bilhetes, escalas) numa folha de papel na tela.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DocumentDefinitions = require(Shared.Definitions.DocumentDefinitions)
local Strings = require(Shared.Definitions.Strings)
local InstanceUtil = require(Shared.Modules.InstanceUtil)
local Net = require(Shared.Modules.Net)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local InputController = require(script.Parent.InputController)

local PAPER = Color3.fromRGB(226, 222, 206)
local INK = Color3.fromRGB(30, 28, 26)

local DocumentController = {}

type Elements = { gui: ScreenGui, title: TextLabel, body: TextLabel }
local elements: Elements? = nil
local openId: string? = nil

local function close()
	openId = nil
	if elements then
		elements.gui.Enabled = false
	end
	InputController:UnbindAction("CloseDocument")
end

local function show(documentId: string)
	local document = DocumentDefinitions.get(documentId)
	local ui = elements
	if not document or not ui then
		return
	end
	openId = documentId
	ui.title.Text = Strings.get(document.TitleKey)
	ui.body.Text = Strings.get(document.BodyKey)
	ui.gui.Enabled = true
	InputController:BindAction(
		"CloseDocument",
		{ Keyboard = Enum.KeyCode.Backspace, Gamepad = Enum.KeyCode.ButtonB },
		close
	)
end

local function buildUI(parent: Instance): Elements
	local gui = Instance.new("ScreenGui")
	gui.Name = "Document"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = Theme.DisplayOrder.Popups
	gui.Enabled = false

	local paper = Components.panel("Paper", PAPER)
	paper.AnchorPoint = Vector2.new(0.5, 0.5)
	paper.Position = UDim2.fromScale(0.5, 0.5)
	paper.Size = UDim2.new(0.9, 0, 0, 0)
	paper.AutomaticSize = Enum.AutomaticSize.Y
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, math.huge)
	limit.Parent = paper
	Components.padding(paper, 24)
	Components.list(paper, 12)
	paper.Parent = gui

	local title = Components.label({
		Name = "Title",
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSizes.Heading,
		Color = INK,
		LayoutOrder = 1,
	})
	title.Parent = paper
	local body = Components.label({
		Name = "Body",
		Text = "",
		Font = Enum.Font.SpecialElite,
		TextSize = Theme.TextSizes.Body,
		Color = INK,
		LayoutOrder = 2,
	})
	body.Parent = paper
	Components.button({
		Name = "CloseButton",
		Text = Strings.get("CLOSE"),
		LayoutOrder = 3,
		OnActivated = close,
	}).Parent =
		paper

	gui.Parent = parent
	return { gui = gui, title = title, body = body }
end

function DocumentController:GetOpen(): string?
	return openId
end

function DocumentController:Init() end

function DocumentController:Start()
	elements = buildUI(InstanceUtil.waitForChild(Players.LocalPlayer, "PlayerGui"))
	Net.Client.on("ShowDocument", function(documentId: string)
		if type(documentId) == "string" then
			show(documentId)
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("State"):Connect(close)
end

return DocumentController
