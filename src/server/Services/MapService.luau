--!strict
-- Carrega e descarrega o mapa da partida.
-- Mapas ficam em ServerStorage > Maps > <MapId> (não são enviados aos jogadores até serem carregados).
-- Durante a partida, o mapa fica em Workspace > Runtime > ActiveMap.
--
-- Formato obrigatório de um mapa:
--   Model <MapId>
--   └── Spawns (Folder) → Parts onde os jogadores aparecem (NÃO use SpawnLocation dentro do mapa)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local MapDefinitions = require(Shared.Definitions.MapDefinitions)
local Log = require(Shared.Modules.Log)

local World = script.Parent.Parent.World
local PlaceholderMapBuilder = require(World.PlaceholderMapBuilder)

-- Mapas gerados por código enquanto não existe uma versão feita à mão em ServerStorage > Maps.
local BUILDERS: { [string]: { build: (mapId: string) -> Model } } = {
	GasStation = require(World.GasStationBuilder),
}

local ACTIVE_MAP_NAME = "ActiveMap"
local SPAWN_HEIGHT_OFFSET = 3

local log = Log.new("MapService")

local MapService = {}

local activeMap: Model? = nil

type ZoneBox = { Name: string, Part: BasePart, Min: Vector3, Max: Vector3 }
local zoneBoxes: { ZoneBox } = {}

local function cacheZones(map: Model)
	table.clear(zoneBoxes)
	local zones = map:FindFirstChild("Zones")
	if not zones then
		return
	end
	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			local half = zonePart.Size / 2
			table.insert(zoneBoxes, {
				Name = tostring(zonePart:GetAttribute("Zone") or zonePart.Name),
				Part = zonePart,
				Min = zonePart.Position - half,
				Max = zonePart.Position + half,
			})
		end
	end
end

local function getSource(mapId: string): Model
	local maps = ServerStorage:FindFirstChild("Maps")
	local source = maps and maps:FindFirstChild(mapId)
	if source and source:IsA("Model") then
		return source:Clone()
	end
	local builder = BUILDERS[mapId]
	if builder then
		log:Debug("Gerando o mapa %s por código.", mapId)
		return builder.build(mapId)
	end
	log:Warn("ServerStorage > Maps > %s não existe. Usando área de teste temporária.", mapId)
	return PlaceholderMapBuilder.build(mapId)
end

function MapService:GetActiveMap(): Model?
	return activeMap
end

function MapService:Load(mapId: string): Model
	assert(MapDefinitions.get(mapId), `[MapService] mapa desconhecido: {mapId}`)
	self:Unload()

	local map = getSource(mapId)
	map.Name = ACTIVE_MAP_NAME
	map:SetAttribute("MapId", mapId)
	local spawns = map:FindFirstChild("Spawns")
	if not spawns or #spawns:GetChildren() == 0 then
		error(`[MapService] O mapa {mapId} precisa de uma pasta "Spawns" com pelo menos uma Part.`)
	end
	map.Parent = workspace:FindFirstChild("Runtime") or workspace
	activeMap = map
	cacheZones(map)
	log:Info("Mapa %s carregado", mapId)
	return map
end

function MapService:Unload()
	table.clear(zoneBoxes)
	if activeMap then
		activeMap:Destroy()
		activeMap = nil
		log:Debug("Mapa descarregado")
	end
end

-- Zona em que uma posição está (Store, Back, Pumps…). Fora de qualquer zona = "Forest".
-- Zonas são caixas alinhadas aos eixos (Parts sem rotação), então o teste é barato.
function MapService:GetZoneAt(position: Vector3): (string, BasePart?)
	for _, box in zoneBoxes do
		if
			position.X >= box.Min.X
			and position.X <= box.Max.X
			and position.Y >= box.Min.Y
			and position.Y <= box.Max.Y
			and position.Z >= box.Min.Z
			and position.Z <= box.Max.Z
		then
			return box.Name, box.Part
		end
	end
	return "Forest", nil
end

function MapService:GetZonePart(zoneName: string): BasePart?
	for _, box in zoneBoxes do
		if box.Name == zoneName then
			return box.Part
		end
	end
	return nil
end

-- Busca uma pasta padrão do mapa ativo (ex.: "EventAnchors", "SecurityCameras").
function MapService:GetFolder(folderName: string): Instance?
	local map = activeMap
	return if map then map:FindFirstChild(folderName) else nil
end

-- Posição do personagem do jogador (ou nil).
function MapService:GetCharacterPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

-- Pontos de spawn do mapa ativo (em ordem de nome, para ser previsível).
function MapService:GetSpawnPoints(): { BasePart }
	local map = activeMap
	if not map then
		return {}
	end
	local points: { BasePart } = {}
	for _, child in (map :: any).Spawns:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(points, child)
		end
	end
	table.sort(points, function(a, b)
		return a.Name < b.Name
	end)
	return points
end

-- Coloca o personagem do jogador no ponto de spawn de número `index` (repete se houver mais jogadores que pontos).
function MapService:PlaceCharacter(player: Player, index: number): boolean
	local character = player.Character
	local points = self:GetSpawnPoints()
	if not character or #points == 0 then
		return false
	end
	local point: BasePart = points[((index - 1) % #points) + 1]
	character:PivotTo(CFrame.new(point.Position + Vector3.new(0, SPAWN_HEIGHT_OFFSET, 0)))
	return true
end

function MapService:Init() end

return MapService
