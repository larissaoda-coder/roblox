--!strict
-- Área de teste temporária, usada enquanto o mapa real não existe em ServerStorage > Maps (Fase 7).
-- Segue o mesmo formato que todo mapa deve ter:
--   Model (nome = MapId)
--   └── Spawns (Folder) com Parts onde os jogadores aparecem

local ORIGIN = Vector3.new(0, 0, 600) -- longe do lobby
local GROUND_COLOR = Color3.fromRGB(30, 30, 32)
local BUILDING_COLOR = Color3.fromRGB(70, 70, 74)
local LAMP_COLOR = Color3.fromRGB(255, 214, 160)

local PlaceholderMapBuilder = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local newPart = Instance.new("Part")
	newPart.Name = name
	newPart.Anchored = true
	newPart.Size = size
	newPart.Position = ORIGIN + offset
	newPart.Color = color
	newPart.Material = material
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	newPart.Parent = parent
	return newPart
end

function PlaceholderMapBuilder.build(mapId: string): Model
	local model = Instance.new("Model")
	model.Name = mapId
	model:SetAttribute("Placeholder", true)

	part(
		model,
		"Ground",
		Vector3.new(160, 1, 160),
		Vector3.new(0, -0.5, 0),
		GROUND_COLOR,
		Enum.Material.Asphalt
	)

	-- "Loja" provisória: quatro paredes com uma abertura na frente.
	part(
		model,
		"BackWall",
		Vector3.new(30, 12, 1),
		Vector3.new(0, 6, -10),
		BUILDING_COLOR,
		Enum.Material.Concrete
	)
	part(
		model,
		"LeftWall",
		Vector3.new(1, 12, 20),
		Vector3.new(-15, 6, 0),
		BUILDING_COLOR,
		Enum.Material.Concrete
	)
	part(
		model,
		"RightWall",
		Vector3.new(1, 12, 20),
		Vector3.new(15, 6, 0),
		BUILDING_COLOR,
		Enum.Material.Concrete
	)
	part(
		model,
		"FrontLeft",
		Vector3.new(11, 12, 1),
		Vector3.new(-9.5, 6, 10),
		BUILDING_COLOR,
		Enum.Material.Concrete
	)
	part(
		model,
		"FrontRight",
		Vector3.new(11, 12, 1),
		Vector3.new(9.5, 6, 10),
		BUILDING_COLOR,
		Enum.Material.Concrete
	)
	part(
		model,
		"Roof",
		Vector3.new(32, 1, 22),
		Vector3.new(0, 12.5, 0),
		BUILDING_COLOR,
		Enum.Material.Concrete
	)

	local lamp =
		part(model, "Lamp", Vector3.new(4, 0.4, 4), Vector3.new(0, 11.8, 0), LAMP_COLOR, Enum.Material.Neon)
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = LAMP_COLOR
	light.Range = 30
	light.Brightness = 1.2
	light.Parent = lamp

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	for index, offset in
		{
			Vector3.new(-6, 0.5, 20),
			Vector3.new(-2, 0.5, 20),
			Vector3.new(2, 0.5, 20),
			Vector3.new(6, 0.5, 20),
		}
	do
		local spawnPart = part(
			spawns,
			`Spawn{index}`,
			Vector3.new(2, 1, 2),
			offset,
			GROUND_COLOR,
			Enum.Material.SmoothPlastic
		)
		spawnPart.Transparency = 1
		spawnPart.CanCollide = false
	end

	return model
end

return PlaceholderMapBuilder
