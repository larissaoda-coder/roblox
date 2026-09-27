--!strict
-- Mapas do jogo. Para adicionar um mapa: crie uma entrada aqui e o modelo em ServerStorage > Maps > <Id> (Fase 7).
-- Available = false aparece no lobby como "EM BREVE".

export type MapDefinition = {
	Id: string,
	NameKey: string,
	DescriptionKey: string,
	Order: number,
	Available: boolean,
	MinPlayers: number,
	MaxPlayers: number,
}

local MAPS: { MapDefinition } = {
	{
		Id = "GasStation",
		NameKey = "MAP_GAS_STATION",
		DescriptionKey = "MAP_GAS_STATION_DESC",
		Order = 1,
		Available = true,
		MinPlayers = 1,
		MaxPlayers = 4,
	},
	{
		Id = "Supermarket",
		NameKey = "MAP_SUPERMARKET",
		DescriptionKey = "MAP_LOCKED_DESC",
		Order = 2,
		Available = false,
		MinPlayers = 1,
		MaxPlayers = 4,
	},
	{
		Id = "Hotel",
		NameKey = "MAP_HOTEL",
		DescriptionKey = "MAP_LOCKED_DESC",
		Order = 3,
		Available = false,
		MinPlayers = 1,
		MaxPlayers = 4,
	},
	{
		Id = "Hospital",
		NameKey = "MAP_HOSPITAL",
		DescriptionKey = "MAP_LOCKED_DESC",
		Order = 4,
		Available = false,
		MinPlayers = 1,
		MaxPlayers = 4,
	},
}

local byId: { [string]: MapDefinition } = {}
for _, map in MAPS do
	byId[map.Id] = table.freeze(map)
end
table.sort(MAPS, function(a, b)
	return a.Order < b.Order
end)

local MapDefinitions = {}

function MapDefinitions.get(mapId: string): MapDefinition?
	return byId[mapId]
end

function MapDefinitions.getAll(): { MapDefinition }
	return table.clone(MAPS)
end

return MapDefinitions
