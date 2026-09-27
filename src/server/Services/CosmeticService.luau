--!strict
-- Aplica no personagem os cosméticos equipados: título acima da cabeça, colete (uniforme),
-- boné e efeito de entrada no começo do turno. Tudo é visual: nenhuma vantagem de jogo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Modules.Log)

local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)
local PlayerService = require(script.Parent.PlayerService)

local EFFECT_SECONDS = 3

local log = Log.new("CosmeticService")

local CosmeticService = {}

local function findPart(character: Model, names: { string }): BasePart?
	for _, name in names do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function attach(
	character: Model,
	name: string,
	anchorNames: { string },
	size: Vector3,
	offset: Vector3,
	color: Color3
): BasePart?
	local anchor = findPart(character, anchorNames)
	local existing = character:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	if not anchor then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Fabric
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = anchor.CFrame * CFrame.new(offset)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	part.Parent = character
	return part
end

local function applyTitle(player: Player, character: Model)
	local head = findPart(character, { "Head" })
	if not head then
		return
	end
	local old = head:FindFirstChild("NS_Title")
	if old then
		old:Destroy()
	end
	local title = InventoryService:GetEquipped(player, "TITLES")
	if not title or not title.Data.Text then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NS_Title"
	billboard.Size = UDim2.new(0, 200, 0, 24)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.MaxDistance = 40
	billboard.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.TextColor3 = if title.VipOnly then Color3.fromRGB(200, 170, 255) else Color3.fromRGB(220, 220, 220)
	label.TextStrokeTransparency = 0.5
	label.Text = title.Data.Text
	label.Parent = billboard
	billboard.Parent = head
end

function CosmeticService:Apply(player: Player)
	local character = player.Character
	if not character then
		return
	end
	applyTitle(player, character)
	local outfit = InventoryService:GetEquipped(player, "OUTFITS")
	if outfit and outfit.Data.Color then
		attach(
			character,
			"NS_Vest",
			{ "UpperTorso", "Torso" },
			Vector3.new(2.1, 1.8, 1.1),
			Vector3.new(0, 0.1, 0),
			outfit.Data.Color
		)
	end
	local cosmetic = InventoryService:GetEquipped(player, "COSMETICS")
	local cap = character:FindFirstChild("NS_Cap")
	if cap then
		cap:Destroy()
	end
	if cosmetic and cosmetic.Data.Color then
		attach(
			character,
			"NS_Cap",
			{ "Head" },
			Vector3.new(1.3, 0.35, 1.3),
			Vector3.new(0, 0.7, 0),
			cosmetic.Data.Color
		)
	end
end

-- Efeito de entrada no começo do turno (partículas por alguns segundos).
function CosmeticService:PlayEntryEffect(player: Player)
	local effect = InventoryService:GetEquipped(player, "EFFECTS")
	local character = player.Character
	local root = character and findPart(character, { "HumanoidRootPart" })
	if not effect or not effect.Data.Color or not root then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "NS_EntryEffect"
	emitter.Color = ColorSequence.new(effect.Data.Color)
	emitter.Rate = 40
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.Size = NumberSequence.new(0.3)
	emitter.Parent = root
	task.delay(EFFECT_SECONDS, function()
		emitter:Destroy()
	end)
end

function CosmeticService:Init() end

function CosmeticService:Start()
	PlayerService.PlayerReady:Connect(function(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(CosmeticService.Apply, CosmeticService, player)
		end)
		CosmeticService:Apply(player)
	end)
	InventoryService.Equipped:Connect(function(player: Player)
		CosmeticService:Apply(player)
	end)
	MatchService.MatchStarted:Connect(function(match)
		for _, player in match.Players do
			CosmeticService:PlayEntryEffect(player)
		end
	end)
	log:Debug("Cosméticos prontos.")
end

return CosmeticService
