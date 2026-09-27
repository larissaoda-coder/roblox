--!strict
-- MAPA 01: POSTO DE GASOLINA "ROUTE 44" — gerado por código.
-- Usado quando ServerStorage > Maps > GasStation não existe. Quando você quiser editar o mapa à mão,
-- basta criar sua versão em ServerStorage > Maps > GasStation seguindo as mesmas pastas abaixo.
--
-- Estrutura (contrato usado pelos outros sistemas):
--   Spawns          Parts onde a equipe aparece
--   Zones           Parts invisíveis com atributos Zone, Indoor, SafeZone
--   SecurityCameras Parts com CameraId, LabelKey, Order (CFrame = direção da câmera)
--   EventAnchors    Parts nomeadas usadas por eventos
--   EntityNodes     Parts com atributo Kind ("Watch" | "Hide") para a entidade
--   NPCPath         Parts P1..Pn: caminho dos clientes da estrada até o caixa
--   Tags: "Interactable" (portas, tarefas, telefone, monitor, interruptores, documentos),
--         "ShiftLight" (luzes com atributo Zone), "EmergencyLight", "Product"

local CollectionService = game:GetService("CollectionService")

local ORIGIN = Vector3.new(0, 0, 600)

local WALL_HEIGHT = 12
local WALL_THICKNESS = 1
local DOOR_HEIGHT = 8

local COLORS = {
	Asphalt = Color3.fromRGB(34, 34, 36),
	Grass = Color3.fromRGB(28, 36, 26),
	Exterior = Color3.fromRGB(176, 172, 162),
	Interior = Color3.fromRGB(196, 196, 190),
	Floor = Color3.fromRGB(150, 150, 146),
	OfficeFloor = Color3.fromRGB(96, 88, 80),
	Accent = Color3.fromRGB(140, 18, 24),
	Metal = Color3.fromRGB(110, 112, 116),
	Dark = Color3.fromRGB(24, 24, 26),
	Wood = Color3.fromRGB(90, 70, 52),
	Light = Color3.fromRGB(226, 234, 238),
	WarmLight = Color3.fromRGB(255, 208, 150),
	Glass = Color3.fromRGB(150, 180, 190),
	Trunk = Color3.fromRGB(58, 44, 34),
	Foliage = Color3.fromRGB(22, 36, 24),
	Line = Color3.fromRGB(200, 196, 170),
	Dumpster = Color3.fromRGB(40, 70, 48),
	FuelRed = Color3.fromRGB(150, 30, 28),
}

local GasStationBuilder = {}

type Gap = { Center: number, Width: number, Bottom: number?, Top: number?, Glass: boolean?, Door: string? }

local function at(x: number, y: number, z: number): Vector3
	return ORIGIN + Vector3.new(x, y, z)
end

local function folder(parent: Instance, name: string): Folder
	local newFolder = Instance.new("Folder")
	newFolder.Name = name
	newFolder.Parent = parent
	return newFolder
end

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

local function invisible(target: BasePart)
	target.Transparency = 1
	target.CanCollide = false
	target.CanQuery = false
	target.CastShadow = false
end

local function interactable(target: Instance, attributes: { [string]: any })
	for key, value in attributes do
		target:SetAttribute(key, value)
	end
	CollectionService:AddTag(target, "Interactable")
end

local function taskPoint(target: Instance, taskId: string, pointName: string)
	interactable(target, { InteractionType = "Task", TaskId = taskId, Point = pointName, MaxDistance = 7 })
end

-- Luz de teto com SurfaceLight. Todas as luzes têm Zone para o LightingService controlar por área.
local function ceilingLight(
	parent: Instance,
	name: string,
	position: Vector3,
	zone: string,
	shadows: boolean?,
	color: Color3?
)
	local fixture =
		part(parent, name, Vector3.new(4, 0.3, 1.2), position, color or COLORS.Light, Enum.Material.Neon)
	fixture.CanCollide = false
	fixture.CastShadow = false
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Color = color or COLORS.Light
	light.Brightness = 1.3
	light.Range = 18
	light.Angle = 120
	light.Shadows = shadows == true
	light.Parent = fixture
	fixture:SetAttribute("Zone", zone)
	fixture:SetAttribute("BaseBrightness", light.Brightness)
	CollectionService:AddTag(fixture, "ShiftLight")
	return fixture
end

local function lampPost(parent: Instance, name: string, x: number, z: number, zone: string)
	part(parent, `{name}Pole`, Vector3.new(0.6, 16, 0.6), at(x, 8, z), COLORS.Metal, Enum.Material.Metal)
	local head =
		part(parent, name, Vector3.new(3, 0.5, 1.4), at(x, 16, z), COLORS.WarmLight, Enum.Material.Neon)
	head.CanCollide = false
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Color = COLORS.WarmLight
	light.Brightness = 2
	light.Range = 34
	light.Angle = 100
	light.Shadows = false
	light.Parent = head
	head:SetAttribute("Zone", zone)
	head:SetAttribute("BaseBrightness", light.Brightness)
	CollectionService:AddTag(head, "ShiftLight")
end

local function emergencyLight(parent: Instance, name: string, position: Vector3, zone: string)
	local lamp =
		part(parent, name, Vector3.new(1, 0.4, 0.4), position, COLORS.Accent, Enum.Material.SmoothPlastic)
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = COLORS.Accent
	light.Brightness = 1.5
	light.Range = 16
	light.Enabled = false
	light.Parent = lamp
	lamp:SetAttribute("Zone", zone)
	CollectionService:AddTag(lamp, "EmergencyLight")
end

local function door(
	parent: Instance,
	name: string,
	position: Vector3,
	width: number,
	alongZ: boolean,
	attributes: { [string]: any }?
)
	local panel = Instance.new("Part")
	panel.Name = name
	panel.Anchored = true
	panel.Size = Vector3.new(width - 0.3, DOOR_HEIGHT - 0.1, 0.35)
	panel.CFrame = if alongZ
		then CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0)
		else CFrame.new(position)
	panel.Color = COLORS.Wood
	panel.Material = Enum.Material.WoodPlanks
	panel.Parent = parent
	local doorAttributes: { [string]: any } =
		{ InteractionType = "Door", Open = false, Hinge = "Left", RequiresShift = true }
	for key, value in (attributes or {}) :: { [string]: any } do
		doorAttributes[key] = value
	end
	interactable(panel, doorAttributes)
	return panel
end

-- Parede ao longo do eixo X (em z fixo), com vãos para portas e janelas.
local function wallAlongX(
	parent: Instance,
	name: string,
	z: number,
	x1: number,
	x2: number,
	color: Color3,
	gaps: { Gap }?
)
	local sortedGaps: { Gap } = table.clone(gaps or {})
	table.sort(sortedGaps, function(a: Gap, b: Gap)
		return a.Center < b.Center
	end)
	local cursor = x1
	local index = 0
	local function segment(from: number, to: number, bottom: number, top: number)
		if to - from > 0.05 and top - bottom > 0.05 then
			index += 1
			part(
				parent,
				`{name}_{index}`,
				Vector3.new(to - from, top - bottom, WALL_THICKNESS),
				at((from + to) / 2, (bottom + top) / 2, z),
				color,
				Enum.Material.Concrete
			)
		end
	end
	for _, gap in sortedGaps do
		local left, right = gap.Center - gap.Width / 2, gap.Center + gap.Width / 2
		local bottom = gap.Bottom or 0
		local top = gap.Top or DOOR_HEIGHT
		segment(cursor, left, 0, WALL_HEIGHT)
		segment(left, right, 0, bottom)
		segment(left, right, top, WALL_HEIGHT)
		if gap.Glass then
			local glass = part(
				parent,
				`{name}_Window`,
				Vector3.new(gap.Width, top - bottom, 0.2),
				at(gap.Center, (bottom + top) / 2, z),
				COLORS.Glass,
				Enum.Material.Glass
			)
			glass.Transparency = 0.6
			glass.CastShadow = false
		end
		cursor = right
	end
	segment(cursor, x2, 0, WALL_HEIGHT)
end

-- Parede ao longo do eixo Z (em x fixo).
local function wallAlongZ(
	parent: Instance,
	name: string,
	x: number,
	z1: number,
	z2: number,
	color: Color3,
	gaps: { Gap }?
)
	local sortedGaps: { Gap } = table.clone(gaps or {})
	table.sort(sortedGaps, function(a: Gap, b: Gap)
		return a.Center < b.Center
	end)
	local cursor = z1
	local index = 0
	local function segment(from: number, to: number, bottom: number, top: number)
		if to - from > 0.05 and top - bottom > 0.05 then
			index += 1
			part(
				parent,
				`{name}_{index}`,
				Vector3.new(WALL_THICKNESS, top - bottom, to - from),
				at(x, (bottom + top) / 2, (from + to) / 2),
				color,
				Enum.Material.Concrete
			)
		end
	end
	for _, gap in sortedGaps do
		local near, far = gap.Center - gap.Width / 2, gap.Center + gap.Width / 2
		local bottom = gap.Bottom or 0
		local top = gap.Top or DOOR_HEIGHT
		segment(cursor, near, 0, WALL_HEIGHT)
		segment(near, far, 0, bottom)
		segment(near, far, top, WALL_HEIGHT)
		if gap.Glass then
			local glass = part(
				parent,
				`{name}_Window`,
				Vector3.new(0.2, top - bottom, gap.Width),
				at(x, (bottom + top) / 2, gap.Center),
				COLORS.Glass,
				Enum.Material.Glass
			)
			glass.Transparency = 0.6
			glass.CastShadow = false
		end
		cursor = far
	end
	segment(cursor, z2, 0, WALL_HEIGHT)
end

local function buildTerrain(map: Model)
	local ground = folder(map, "Ground")
	part(ground, "Grass", Vector3.new(420, 1, 420), at(0, -0.55, 0), COLORS.Grass, Enum.Material.Grass)
	part(ground, "Lot", Vector3.new(170, 1, 130), at(0, -0.5, 0), COLORS.Asphalt, Enum.Material.Asphalt)
	part(
		ground,
		"Road",
		Vector3.new(420, 1, 24),
		at(0, -0.48, 70),
		Color3.fromRGB(28, 28, 30),
		Enum.Material.Asphalt
	)
	for index = 0, 20 do
		local line = part(
			ground,
			`RoadLine{index}`,
			Vector3.new(8, 0.05, 0.4),
			at(-200 + index * 20, 0.03, 70),
			COLORS.Line,
			Enum.Material.SmoothPlastic
		)
		line.CanCollide = false
	end
	for index = 0, 5 do
		local line = part(
			ground,
			`ParkingLine{index}`,
			Vector3.new(0.3, 0.05, 10),
			at(34 + index * 7, 0.03, 12),
			COLORS.Line,
			Enum.Material.SmoothPlastic
		)
		line.CanCollide = false
	end

	-- Floresta ao redor (determinística: sempre o mesmo formato).
	local forest = folder(map, "Forest")
	local random = Random.new(44)
	local placed = 0
	while placed < 70 do
		local x = random:NextNumber(-190, 190)
		local z = random:NextNumber(-190, 190)
		local insideLot = math.abs(x) < 95 and z > -75 and z < 95
		local onRoad = z > 55 and z < 86
		if not insideLot and not onRoad then
			placed += 1
			local height = random:NextNumber(18, 30)
			local trunk = part(
				forest,
				`Trunk{placed}`,
				Vector3.new(1.6, height, 1.6),
				at(x, height / 2, z),
				COLORS.Trunk,
				Enum.Material.Wood
			)
			trunk.CastShadow = false
			local crown = part(
				forest,
				`Crown{placed}`,
				Vector3.new(12, 14, 12),
				at(x, height, z),
				COLORS.Foliage,
				Enum.Material.Grass
			)
			crown.Shape = Enum.PartType.Ball
			crown.CanCollide = false
			crown.CastShadow = false
		end
	end

	-- Limites invisíveis: ninguém sai correndo pela floresta.
	local bounds = folder(map, "Bounds")
	for index, data in
		{
			{ Vector3.new(2, 60, 300), at(-110, 30, 10) },
			{ Vector3.new(2, 60, 300), at(110, 30, 10) },
			{ Vector3.new(220, 60, 2), at(0, 30, -110) },
			{ Vector3.new(220, 60, 2), at(0, 30, 110) },
		}
	do
		local wall = part(bounds, `Bound{index}`, data[1], data[2], COLORS.Dark, Enum.Material.SmoothPlastic)
		wall.Transparency = 1
		wall.CastShadow = false
	end
end

local function buildBuilding(map: Model)
	local building = folder(map, "Building")
	local doors = folder(map, "Doors")

	part(
		building,
		"Floor",
		Vector3.new(48, 0.2, 32),
		at(0, 0.1, -4),
		COLORS.Floor,
		Enum.Material.SmoothPlastic
	)
	part(
		building,
		"OfficeFloor",
		Vector3.new(16, 0.22, 12),
		at(-16, 0.11, -14),
		COLORS.OfficeFloor,
		Enum.Material.WoodPlanks
	)
	part(
		building,
		"Roof",
		Vector3.new(50, 1, 34),
		at(0, WALL_HEIGHT + 0.5, -4),
		COLORS.Exterior,
		Enum.Material.Concrete
	)
	local stripe = part(
		building,
		"Stripe",
		Vector3.new(50, 1.2, 0.3),
		at(0, WALL_HEIGHT - 1, 12.7),
		COLORS.Accent,
		Enum.Material.SmoothPlastic
	)
	stripe.CanCollide = false

	-- Paredes externas.
	local frontGaps: { Gap } = {
		{ Center = -15, Width = 12, Bottom = 3, Top = 9, Glass = true },
		{ Center = -4, Width = 5 },
		{ Center = 3, Width = 6, Bottom = 3, Top = 9, Glass = true },
	}
	wallAlongX(building, "FrontWall", 12, -24, 24, COLORS.Exterior, frontGaps)
	wallAlongX(building, "BackWall", -20, -24, 24, COLORS.Exterior, { { Center = 14, Width = 4 } })
	wallAlongZ(
		building,
		"LeftWall",
		-24,
		-20,
		12,
		COLORS.Exterior,
		{ { Center = 2, Width = 8, Bottom = 4, Top = 8, Glass = true } }
	)
	wallAlongZ(building, "RightWall", 24, -20, 12, COLORS.Exterior)

	-- Paredes internas.
	wallAlongX(building, "InnerWall", -8, -24, 24, COLORS.Interior, {
		{ Center = -12, Width = 4 },
		{ Center = -2, Width = 4 },
		{ Center = 16, Width = 5 },
	})
	wallAlongZ(building, "StockroomWall", 8, -8, 12, COLORS.Interior, { { Center = 2, Width = 4 } })
	wallAlongZ(building, "OfficeWall", -8, -20, -8, COLORS.Interior)
	wallAlongZ(building, "BathroomWall", 4, -20, -8, COLORS.Interior)

	-- Portas.
	local front = door(doors, "FrontDoor", at(-4, DOOR_HEIGHT / 2, 12), 5, false)
	front.Material = Enum.Material.Glass
	front.Color = COLORS.Glass
	front.Transparency = 0.5
	door(doors, "StockroomDoor", at(8, DOOR_HEIGHT / 2, 2), 4, true)
	door(doors, "OfficeDoor", at(-12, DOOR_HEIGHT / 2, -8), 4, false)
	door(doors, "BathroomDoor", at(-2, DOOR_HEIGHT / 2, -8), 4, false)
	door(doors, "BackDoor", at(14, DOOR_HEIGHT / 2, -20), 4, false, { Hinge = "Right" })

	return building
end

local function buildStore(map: Model)
	local store = folder(map, "Store")

	-- Caixa: balcão, registradora e telefone.
	part(store, "Counter", Vector3.new(8, 3.5, 2), at(-18, 1.75, 6), COLORS.Wood, Enum.Material.Wood)
	part(store, "Register", Vector3.new(1.6, 1, 1.2), at(-20, 4, 6), COLORS.Dark, Enum.Material.SmoothPlastic)
	local phone = part(
		store,
		"Phone",
		Vector3.new(1, 0.5, 0.8),
		at(-15.5, 3.75, 6),
		COLORS.Dark,
		Enum.Material.SmoothPlastic
	)
	interactable(
		phone,
		{ InteractionType = "Phone", PromptKey = "PROMPT_ANSWER_PHONE", Enabled = false, MaxDistance = 7 }
	)
	local schedule = part(
		store,
		"ShiftSchedule",
		Vector3.new(1.4, 0.05, 1),
		at(-22, 3.53, 6.3),
		Color3.fromRGB(230, 226, 210),
		Enum.Material.SmoothPlastic
	)
	interactable(schedule, {
		InteractionType = "Document",
		DocumentId = "ShiftSchedule",
		PromptKey = "PROMPT_READ",
		MaxDistance = 6,
	})

	-- Prateleiras com produtos (alguns podem cair em eventos).
	local productColors = {
		Color3.fromRGB(170, 40, 40),
		Color3.fromRGB(40, 90, 160),
		Color3.fromRGB(200, 170, 40),
		Color3.fromRGB(60, 130, 70),
	}
	for index, x in { -8, -2, 4 } do
		part(store, `Shelf{index}`, Vector3.new(1.5, 5, 10), at(x, 2.5, 0), COLORS.Metal, Enum.Material.Metal)
		for row = 0, 1 do
			for slot = 0, 1 do
				local product = part(
					store,
					`Product{index}_{row}_{slot}`,
					Vector3.new(0.8, 1, 0.8),
					at(x + 1.1, 1.6 + row * 2, -3 + slot * 6),
					productColors[(index + row + slot) % #productColors + 1],
					Enum.Material.SmoothPlastic
				)
				product:SetAttribute("Zone", "Store")
				CollectionService:AddTag(product, "Product")
			end
		end
		local point = part(
			store,
			`RestockPoint{index}`,
			Vector3.new(1, 1, 1),
			at(x, 2, 5.6),
			COLORS.Metal,
			Enum.Material.SmoothPlastic
		)
		invisible(point)
		taskPoint(point, "RestockShelves", `Shelf{index}`)
	end

	local fridge =
		part(store, "Fridge", Vector3.new(10, 7, 2), at(-17, 3.5, -6.9), COLORS.Glass, Enum.Material.Glass)
	fridge.Transparency = 0.3
	local fridgeLight = Instance.new("SurfaceLight")
	fridgeLight.Face = Enum.NormalId.Front
	fridgeLight.Color = COLORS.Light
	fridgeLight.Brightness = 0.6
	fridgeLight.Range = 8
	fridgeLight.Parent = fridge

	-- Interruptor da loja (ao lado da porta).
	local storeSwitch = part(
		store,
		"StoreLightSwitch",
		Vector3.new(0.4, 0.7, 0.2),
		at(-7, 4.5, 11.4),
		Color3.fromRGB(220, 220, 214),
		Enum.Material.SmoothPlastic
	)
	interactable(storeSwitch, {
		InteractionType = "LightSwitch",
		Zone = "Store",
		PromptKey = "PROMPT_LIGHT_SWITCH",
		MaxDistance = 6,
	})

	for index, position in
		{
			at(-16, 11.8, 4),
			at(-6, 11.8, 4),
			at(4, 11.8, 4),
			at(-16, 11.8, -4),
			at(-6, 11.8, -4),
			at(4, 11.8, -4),
		}
	do
		ceilingLight(store, `StoreLight{index}`, position, "Store", index == 2)
	end
	emergencyLight(store, "StoreEmergency", at(-4, 10.5, 11.2), "Store")
end

local function buildStockroom(map: Model)
	local stockroom = folder(map, "Stockroom")
	for index = 0, 2 do
		part(
			stockroom,
			`StockShelf{index}`,
			Vector3.new(2, 8, 6),
			at(22.5, 4, 8 - index * 7),
			COLORS.Metal,
			Enum.Material.Metal
		)
	end
	local boxes = part(
		stockroom,
		"DeliveryBoxes",
		Vector3.new(4, 3, 3),
		at(16, 1.5, 6),
		Color3.fromRGB(150, 120, 80),
		Enum.Material.Cardboard
	)
	taskPoint(boxes, "LogDelivery", "DeliveryBoxes")
	part(stockroom, "Table", Vector3.new(4, 3, 2.5), at(12, 1.5, -6), COLORS.Wood, Enum.Material.Wood)
	local clipboard = part(
		stockroom,
		"Clipboard",
		Vector3.new(0.9, 0.1, 1.2),
		at(12, 3.05, -6),
		Color3.fromRGB(120, 90, 60),
		Enum.Material.Wood
	)
	taskPoint(clipboard, "LogDelivery", "Clipboard")
	local note = part(
		stockroom,
		"DeliveryNote",
		Vector3.new(1, 0.05, 0.8),
		at(13.4, 3.03, -6.3),
		Color3.fromRGB(230, 226, 210),
		Enum.Material.SmoothPlastic
	)
	interactable(note, {
		InteractionType = "Document",
		DocumentId = "DeliveryNote",
		PromptKey = "PROMPT_READ",
		MaxDistance = 6,
	})
	local trash = part(
		stockroom,
		"TrashBag",
		Vector3.new(1.6, 1.6, 1.6),
		at(20, 0.8, 9.5),
		COLORS.Dark,
		Enum.Material.Plastic
	)
	trash.Shape = Enum.PartType.Ball
	taskPoint(trash, "TakeOutTrash", "TrashBag")
	local stockSwitch = part(
		stockroom,
		"StockroomLightSwitch",
		Vector3.new(0.2, 0.7, 0.4),
		at(8.6, 4.5, 5),
		Color3.fromRGB(220, 220, 214),
		Enum.Material.SmoothPlastic
	)
	interactable(stockSwitch, {
		InteractionType = "LightSwitch",
		Zone = "Stockroom",
		PromptKey = "PROMPT_LIGHT_SWITCH",
		MaxDistance = 6,
	})
	ceilingLight(stockroom, "StockroomLight1", at(16, 11.8, 6), "Stockroom", true)
	ceilingLight(stockroom, "StockroomLight2", at(16, 11.8, -4), "Stockroom")
end

local function buildOfficeAndBathroom(map: Model)
	local office = folder(map, "Office")
	part(office, "Desk", Vector3.new(6, 3, 2.5), at(-16, 1.5, -17.5), COLORS.Wood, Enum.Material.Wood)
	local monitor = part(
		office,
		"SecurityMonitor",
		Vector3.new(3, 2, 0.3),
		at(-17, 4, -18),
		COLORS.Dark,
		Enum.Material.SmoothPlastic
	)
	interactable(
		monitor,
		{ InteractionType = "SecurityMonitor", PromptKey = "PROMPT_VIEW_CAMERAS", MaxDistance = 7 }
	)
	local screenLight = Instance.new("SurfaceLight")
	screenLight.Face = Enum.NormalId.Back
	screenLight.Color = Color3.fromRGB(150, 190, 200)
	screenLight.Brightness = 0.5
	screenLight.Range = 6
	screenLight.Parent = monitor
	local recorder = part(
		office,
		"Recorder",
		Vector3.new(1.6, 0.8, 1.4),
		at(-13.5, 3.4, -17.5),
		COLORS.Dark,
		Enum.Material.SmoothPlastic
	)
	taskPoint(recorder, "CheckCameras", "CameraLog")
	local note = part(
		office,
		"PreviousShiftNote",
		Vector3.new(1, 0.05, 0.8),
		at(-19, 3.03, -17),
		Color3.fromRGB(230, 226, 210),
		Enum.Material.SmoothPlastic
	)
	interactable(note, {
		InteractionType = "Document",
		DocumentId = "PreviousShiftNote",
		PromptKey = "PROMPT_READ",
		MaxDistance = 6,
	})
	part(office, "Chair", Vector3.new(2, 2.5, 2), at(-16, 1.25, -15), COLORS.Dark, Enum.Material.Fabric)
	ceilingLight(office, "OfficeLight", at(-16, 11.8, -14), "Office", false, COLORS.WarmLight)

	local bathroom = folder(map, "Bathroom")
	local mirror = part(
		bathroom,
		"Mirror",
		Vector3.new(4, 3, 0.2),
		at(-2, 5.5, -19.4),
		Color3.fromRGB(200, 205, 210),
		Enum.Material.Glass
	)
	mirror.Reflectance = 0.5
	part(
		bathroom,
		"Sink",
		Vector3.new(2.5, 1, 1.6),
		at(-2, 3, -18.8),
		Color3.fromRGB(220, 220, 220),
		Enum.Material.SmoothPlastic
	)
	part(
		bathroom,
		"Toilet",
		Vector3.new(1.8, 2.5, 2.4),
		at(2, 1.25, -18),
		Color3.fromRGB(220, 220, 220),
		Enum.Material.SmoothPlastic
	)
	local mop =
		part(bathroom, "Mop", Vector3.new(0.4, 5, 0.4), at(-6.8, 2.5, -9.5), COLORS.Wood, Enum.Material.Wood)
	taskPoint(mop, "CleanBathroom", "Mop")
	local floorPoint = part(
		bathroom,
		"BathroomFloorPoint",
		Vector3.new(1, 0.2, 1),
		at(-2, 0.3, -14),
		COLORS.Floor,
		Enum.Material.SmoothPlastic
	)
	invisible(floorPoint)
	taskPoint(floorPoint, "CleanBathroom", "BathroomFloor")
	ceilingLight(bathroom, "BathroomLight", at(-2, 11.8, -14), "Bathroom")

	local corridor = folder(map, "Corridor")
	ceilingLight(corridor, "CorridorLight", at(14, 11.8, -14), "Corridor")
	emergencyLight(corridor, "CorridorEmergency", at(14, 10.5, -19.2), "Corridor")
	local lock = part(
		corridor,
		"BackDoorLock",
		Vector3.new(0.4, 0.8, 0.3),
		at(16.6, 4, -19.3),
		COLORS.Metal,
		Enum.Material.Metal
	)
	taskPoint(lock, "LockBackDoor", "BackDoorLock")
end

local function buildOutside(map: Model)
	local back = folder(map, "BackArea")
	local generator = part(
		back,
		"Generator",
		Vector3.new(6, 4, 4),
		at(10, 2, -34),
		Color3.fromRGB(90, 96, 90),
		Enum.Material.DiamondPlate
	)
	taskPoint(generator, "Generator", "Generator")
	local fuelCan = part(
		back,
		"FuelCan",
		Vector3.new(1.2, 1.6, 0.8),
		at(20, 0.8, -23),
		COLORS.FuelRed,
		Enum.Material.SmoothPlastic
	)
	taskPoint(fuelCan, "Generator", "FuelCan")
	local dumpster =
		part(back, "Dumpster", Vector3.new(8, 5, 4), at(-8, 2.5, -36), COLORS.Dumpster, Enum.Material.Metal)
	taskPoint(dumpster, "TakeOutTrash", "Dumpster")
	local backLamp = part(
		back,
		"BackDoorLamp",
		Vector3.new(1.4, 0.6, 0.8),
		at(14, 9.5, -20.9),
		COLORS.WarmLight,
		Enum.Material.Neon
	)
	backLamp.CanCollide = false
	local backLight = Instance.new("SpotLight")
	backLight.Face = Enum.NormalId.Bottom
	backLight.Color = COLORS.WarmLight
	backLight.Brightness = 1.6
	backLight.Range = 26
	backLight.Angle = 110
	backLight.Parent = backLamp
	backLamp:SetAttribute("Zone", "Back")
	backLamp:SetAttribute("BaseBrightness", backLight.Brightness)
	CollectionService:AddTag(backLamp, "ShiftLight")

	-- Bombas e cobertura.
	local pumps = folder(map, "Pumps")
	part(
		pumps,
		"Canopy",
		Vector3.new(48, 1, 24),
		at(0, 14, 40),
		Color3.fromRGB(220, 220, 214),
		Enum.Material.SmoothPlastic
	)
	local canopyStripe = part(
		pumps,
		"CanopyStripe",
		Vector3.new(48.2, 1.2, 24.2),
		at(0, 13.4, 40),
		COLORS.Accent,
		Enum.Material.SmoothPlastic
	)
	canopyStripe.CanCollide = false
	for index, position in { at(-18, 7, 32), at(18, 7, 32), at(-18, 7, 48), at(18, 7, 48) } do
		part(pumps, `Column{index}`, Vector3.new(1.2, 14, 1.2), position, COLORS.Metal, Enum.Material.Metal)
	end
	for index, x in { -12, -4, 4, 12 } do
		part(
			pumps,
			`Island{index}`,
			Vector3.new(3, 0.5, 8),
			at(x, 0.25, 40),
			COLORS.Exterior,
			Enum.Material.Concrete
		)
		local pump = part(
			pumps,
			`Pump{index}`,
			Vector3.new(2, 5, 1.5),
			at(x, 3, 40),
			COLORS.Accent,
			Enum.Material.SmoothPlastic
		)
		taskPoint(pump, "CheckPumps", `Pump{index}`)
	end
	for index, x in { -12, 12 } do
		for row, z in { 34, 46 } do
			ceilingLight(pumps, `CanopyLight{index}_{row}`, at(x, 13.35, z), "Pumps", false)
		end
	end

	-- Estacionamento, carro parado, postes e placa.
	local parking = folder(map, "Parking")
	part(
		parking,
		"CarBody",
		Vector3.new(5, 2, 10),
		at(44, 1.5, 12),
		Color3.fromRGB(60, 64, 72),
		Enum.Material.SmoothPlastic
	)
	part(
		parking,
		"CarCabin",
		Vector3.new(4.6, 1.6, 5),
		at(44, 3.3, 11),
		Color3.fromRGB(40, 44, 50),
		Enum.Material.Glass
	)
	lampPost(parking, "ParkingLamp1", 38, 26, "Parking")
	lampPost(parking, "ParkingLamp2", 62, 0, "Parking")
	lampPost(parking, "RoadLamp1", -30, 58, "Road")
	lampPost(parking, "RoadLamp2", 30, 58, "Road")

	part(parking, "SignPole", Vector3.new(1, 18, 1), at(-40, 9, 54), COLORS.Metal, Enum.Material.Metal)
	local board = part(
		parking,
		"SignBoard",
		Vector3.new(12, 6, 1),
		at(-40, 20, 54),
		COLORS.Dark,
		Enum.Material.SmoothPlastic
	)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.PixelsPerStud = 30
		surface.LightInfluence = 0
		surface.Parent = board
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
		text.TextScaled = true
		text.TextColor3 = COLORS.Accent
		text.Text = "ROUTE 44\nOPEN 24H"
		text.Parent = surface
	end
end

local function zone(
	parent: Instance,
	name: string,
	x1: number,
	x2: number,
	z1: number,
	z2: number,
	indoor: boolean,
	safe: boolean
)
	local area = part(
		parent,
		name,
		Vector3.new(x2 - x1, 16, z2 - z1),
		at((x1 + x2) / 2, 8, (z1 + z2) / 2),
		COLORS.Dark,
		Enum.Material.SmoothPlastic
	)
	invisible(area)
	area:SetAttribute("Zone", name)
	area:SetAttribute("Indoor", indoor)
	area:SetAttribute("SafeZone", safe)
end

local function buildMarkers(map: Model)
	local spawns = folder(map, "Spawns")
	for index, position in { at(-10, 0.5, 8), at(-6, 0.5, 8), at(-10, 0.5, 5), at(-6, 0.5, 5) } do
		local spawnPoint = part(
			spawns,
			`Spawn{index}`,
			Vector3.new(2, 1, 2),
			position,
			COLORS.Dark,
			Enum.Material.SmoothPlastic
		)
		invisible(spawnPoint)
	end

	local zones = folder(map, "Zones")
	zone(zones, "Store", -24, 8, -8, 12, true, true)
	zone(zones, "Stockroom", 8, 24, -8, 12, true, false)
	zone(zones, "Office", -24, -8, -20, -8, true, false)
	zone(zones, "Bathroom", -8, 4, -20, -8, true, false)
	zone(zones, "Corridor", 4, 24, -20, -8, true, false)
	zone(zones, "Back", -40, 40, -60, -20, false, false)
	zone(zones, "Pumps", -26, 26, 20, 56, false, false)
	zone(zones, "Parking", 26, 80, -10, 50, false, false)
	zone(zones, "Road", -110, 110, 56, 84, false, false)

	-- Câmeras de segurança: CFrame aponta para o que a câmera enxerga.
	local cameras = folder(map, "SecurityCameras")
	local cameraData: { { any } } = {
		{ "CAM01", "CAM_ENTRANCE", at(-10, 10, 24), at(-4, 3, 12) },
		{ "CAM02", "CAM_COUNTER", at(-23, 10.5, 11), at(-12, 2, 0) },
		{ "CAM03", "CAM_STOCKROOM", at(23, 10.5, 11), at(14, 2, -4) },
		{ "CAM04", "CAM_PUMPS", at(22, 12, 26), at(0, 2, 42) },
		{ "CAM05", "CAM_GENERATOR", at(22, 9, -22), at(10, 2, -34) },
		{ "CAM06", "CAM_BACK", at(-20, 9, -22), at(0, 2, -40) },
	}
	for order, data in cameraData do
		local camera = Instance.new("Part")
		camera.Name = data[1]
		camera.Anchored = true
		camera.CanCollide = false
		camera.Size = Vector3.new(0.8, 0.8, 1.4)
		camera.Color = COLORS.Dark
		camera.Material = Enum.Material.SmoothPlastic
		camera.CFrame = CFrame.lookAt(data[3], data[4])
		camera:SetAttribute("CameraId", data[1])
		camera:SetAttribute("LabelKey", data[2])
		camera:SetAttribute("Order", order)
		camera:SetAttribute("FieldOfView", 70)
		camera.Parent = cameras
	end

	local anchors = folder(map, "EventAnchors")
	local function anchor(name: string, position: Vector3)
		invisible(
			part(anchors, name, Vector3.new(1, 1, 1), position, COLORS.Dark, Enum.Material.SmoothPlastic)
		)
	end
	anchor("StockroomNoise", at(20, 3, 2))
	anchor("BackFootsteps", at(14, 1, -14))
	anchor("RoofSteps", at(-4, 13, 0))
	anchor("BathroomVoice", at(0, 4, -16))
	anchor("ForestWatch", at(-30, 3, -80))
	anchor("RoadFigure", at(20, 3, 92))
	anchor("CameraFigure", at(16, 0.5, 0))
	anchor("ImpossibleCamera", at(12, 0.5, -34))
	anchor("PhoneSpot", at(-15.5, 3.75, 6))

	local entityNodes = folder(map, "EntityNodes")
	local function entityNode(name: string, position: Vector3, kind: string)
		local node =
			part(entityNodes, name, Vector3.new(1, 1, 1), position, COLORS.Dark, Enum.Material.SmoothPlastic)
		invisible(node)
		node:SetAttribute("Kind", kind)
	end
	entityNode("WatchForestBack", at(-30, 3, -76), "Watch")
	entityNode("WatchForestSide", at(-88, 3, 10), "Watch")
	entityNode("WatchParking", at(76, 3, -6), "Watch")
	entityNode("WatchRoad", at(24, 3, 92), "Watch")
	entityNode("HideDumpster", at(-14, 3, -38), "Hide")
	entityNode("HideAisle", at(4, 3, -6), "Hide")
	entityNode("HideCorridor", at(22, 3, -18), "Hide")
	entityNode("HideBathroom", at(2, 3, -12), "Hide")

	local path = folder(map, "NPCPath")
	for index, position in
		{ at(-105, 3, 70), at(-30, 3, 64), at(-4, 3, 26), at(-4, 3, 16), at(-4, 3, 7), at(-12, 3, 3.5) }
	do
		local node =
			part(path, `P{index}`, Vector3.new(1, 1, 1), position, COLORS.Dark, Enum.Material.SmoothPlastic)
		invisible(node)
	end
end

function GasStationBuilder.build(mapId: string): Model
	local map = Instance.new("Model")
	map.Name = mapId
	map:SetAttribute("Generated", true)
	buildTerrain(map)
	buildBuilding(map)
	buildStore(map)
	buildStockroom(map)
	buildOfficeAndBathroom(map)
	buildOutside(map)
	buildMarkers(map)
	return map
end

return GasStationBuilder
