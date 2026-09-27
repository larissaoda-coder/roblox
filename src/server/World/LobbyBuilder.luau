--!strict
-- Gera um lobby simples caso Workspace > Lobby não exista.
-- Quando você construir o seu próprio lobby no Studio, basta criar um Model chamado "Lobby" no Workspace
-- (com um SpawnLocation dentro) e este gerador será ignorado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Modules.Log)

local ROOM_SIZE = 72
local WALL_HEIGHT = 18
local WALL_THICKNESS = 2

local FLOOR_COLOR = Color3.fromRGB(38, 38, 42)
local WALL_COLOR = Color3.fromRGB(24, 24, 28)
local LIGHT_COLOR = Color3.fromRGB(214, 226, 235)
local SIGN_COLOR = Color3.fromRGB(150, 20, 26)

local log = Log.new("LobbyBuilder")

local LobbyBuilder = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local newPart = Instance.new("Part")
	newPart.Name = name
	newPart.Anchored = true
	newPart.Size = size
	newPart.Position = position
	newPart.Color = color
	newPart.Material = material
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	newPart.Parent = parent
	return newPart
end

local function buildShell(model: Model)
	local half = ROOM_SIZE / 2
	part(
		model,
		"Floor",
		Vector3.new(ROOM_SIZE, 1, ROOM_SIZE),
		Vector3.new(0, -0.5, 0),
		FLOOR_COLOR,
		Enum.Material.Concrete
	)
	part(
		model,
		"Ceiling",
		Vector3.new(ROOM_SIZE, 1, ROOM_SIZE),
		Vector3.new(0, WALL_HEIGHT + 0.5, 0),
		WALL_COLOR,
		Enum.Material.SmoothPlastic
	)

	local wallY = WALL_HEIGHT / 2
	local wallLength = ROOM_SIZE + WALL_THICKNESS * 2
	part(
		model,
		"WallNorth",
		Vector3.new(wallLength, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(0, wallY, -half - 1),
		WALL_COLOR,
		Enum.Material.Concrete
	)
	part(
		model,
		"WallSouth",
		Vector3.new(wallLength, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(0, wallY, half + 1),
		WALL_COLOR,
		Enum.Material.Concrete
	)
	part(
		model,
		"WallWest",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ROOM_SIZE),
		Vector3.new(-half - 1, wallY, 0),
		WALL_COLOR,
		Enum.Material.Concrete
	)
	part(
		model,
		"WallEast",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ROOM_SIZE),
		Vector3.new(half + 1, wallY, 0),
		WALL_COLOR,
		Enum.Material.Concrete
	)
end

local function buildLights(model: Model)
	-- 4 luminárias frias no teto. Sem sombras nas luzes secundárias (performance em celular).
	local offsets =
		{ Vector3.new(-16, 0, -16), Vector3.new(16, 0, -16), Vector3.new(-16, 0, 16), Vector3.new(16, 0, 16) }
	for index, offset in offsets do
		local fixture = part(
			model,
			`CeilingLight{index}`,
			Vector3.new(10, 0.3, 2),
			Vector3.new(offset.X, WALL_HEIGHT - 0.15, offset.Z),
			LIGHT_COLOR,
			Enum.Material.Neon
		)
		fixture.CanCollide = false
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Color = LIGHT_COLOR
		light.Brightness = 1.4
		light.Range = 26
		light.Angle = 110
		light.Shadows = index == 1
		light.Parent = fixture
	end
end

local function buildSign(model: Model)
	local half = ROOM_SIZE / 2
	local sign = part(
		model,
		"Sign",
		Vector3.new(34, 6, 0.4),
		Vector3.new(0, 11, -half + 0.2),
		Color3.fromRGB(10, 10, 12),
		Enum.Material.SmoothPlastic
	)
	sign.CanCollide = false

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Back -- a face "Back" aponta para dentro da sala
	surfaceGui.PixelsPerStud = 40
	surfaceGui.LightInfluence = 0
	surfaceGui.Parent = sign

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.BuilderSansBold
	title.TextScaled = true
	title.TextColor3 = SIGN_COLOR
	title.Text = "NIGHT SHIFT: 4AM"
	title.Parent = surfaceGui

	local glow = Instance.new("PointLight")
	glow.Color = SIGN_COLOR
	glow.Brightness = 0.8
	glow.Range = 14
	glow.Parent = sign
end

local function buildSpawn(model: Model)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- sem campo de força
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, -0.45, 14)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = model
end

-- Retorna o lobby existente ou cria um novo.
function LobbyBuilder.ensure(): Instance
	local existing = workspace:FindFirstChild("Lobby")
	if existing then
		log:Debug("Usando o Lobby existente em Workspace.")
		return existing
	end

	local model = Instance.new("Model")
	model.Name = "Lobby"
	buildShell(model)
	buildLights(model)
	buildSign(model)
	buildSpawn(model)
	model.Parent = workspace
	log:Debug("Lobby gerado automaticamente.")
	return model
end

return LobbyBuilder
