--!strict
-- Eventos estranhos. Fica no SERVIDOR: jogadores não conseguem ler a lista nem as condições.
-- Para criar um evento:
--   1. Crie o módulo em ServerScriptService > Server > Events > <Module> (com Run e, opcionalmente, CanRun).
--   2. Adicione a definição aqui.
--
-- Campos:
--   Rarity       COMMON | UNCOMMON | RARE | VERY_RARE | LEGENDARY | SECRET (define o peso no sorteio)
--   Intensity    1 (sutil) a 5 (extremo). O Director só libera intensidades altas mais tarde no turno.
--   MinMinute    minuto mínimo do turno (0 = 04:00)
--   Cooldown     minutos do jogo até poder repetir
--   MaxPerShift  máximo de vezes por turno
--   Perceptual   acontece só para UM jogador (os outros não veem/ouvem)
--   CameraOnly   só aparece nas câmeras de segurança
--   SpecialMinute/SpecialChance  só pode acontecer naquele minuto exato (ex.: 44 = 04:44), com essa chance
--   Secret       conta como segredo (SecretsFound) e pode dar badge

export type Rarity = "COMMON" | "UNCOMMON" | "RARE" | "VERY_RARE" | "LEGENDARY" | "SECRET"

export type EventDefinition = {
	Id: string,
	Module: string,
	Rarity: Rarity,
	Intensity: number,
	MinMinute: number,
	MaxMinute: number,
	Cooldown: number,
	MaxPerShift: number,
	Perceptual: boolean,
	CameraOnly: boolean,
	SpecialMinute: number?,
	SpecialChance: number?,
	Secret: boolean,
	DiscoveryOnly: boolean, -- não é sorteado; só é "descoberto" por outro sistema (diálogo, câmera…)
	Tags: { string },
}

local RARITY_WEIGHTS: { [Rarity]: number } = {
	COMMON = 100,
	UNCOMMON = 40,
	RARE = 12,
	VERY_RARE = 4,
	LEGENDARY = 1,
	SECRET = 0.25,
}

type Partial = {
	Id: string,
	Rarity: Rarity,
	Intensity: number,
	MinMinute: number?,
	MaxMinute: number?,
	Cooldown: number?,
	MaxPerShift: number?,
	Perceptual: boolean?,
	CameraOnly: boolean?,
	SpecialMinute: number?,
	SpecialChance: number?,
	Secret: boolean?,
	DiscoveryOnly: boolean?,
	Tags: { string }?,
}

local function event(data: Partial): EventDefinition
	return {
		Id = data.Id,
		Module = data.Id,
		Rarity = data.Rarity,
		Intensity = data.Intensity,
		MinMinute = data.MinMinute or 0,
		MaxMinute = data.MaxMinute or 60,
		Cooldown = data.Cooldown or 8,
		MaxPerShift = data.MaxPerShift or 1,
		Perceptual = data.Perceptual == true,
		CameraOnly = data.CameraOnly == true,
		SpecialMinute = data.SpecialMinute,
		SpecialChance = data.SpecialChance,
		Secret = data.Secret == true,
		DiscoveryOnly = data.DiscoveryOnly == true,
		Tags = data.Tags or {},
	}
end

local EVENTS: { EventDefinition } = {
	event({
		Id = "LightsFlicker",
		Rarity = "COMMON",
		Intensity = 1,
		MinMinute = 3,
		Cooldown = 4,
		MaxPerShift = 5,
		Tags = { "Lights" },
	}),
	event({
		Id = "ProductFall",
		Rarity = "COMMON",
		Intensity = 1,
		MinMinute = 4,
		Cooldown = 5,
		MaxPerShift = 3,
		Tags = { "Products" },
	}),
	event({
		Id = "DoorOpened",
		Rarity = "COMMON",
		Intensity = 2,
		MinMinute = 6,
		Cooldown = 6,
		MaxPerShift = 3,
		Tags = { "Doors" },
	}),
	event({
		Id = "PhantomFootsteps",
		Rarity = "COMMON",
		Intensity = 2,
		MinMinute = 8,
		Cooldown = 5,
		MaxPerShift = 4,
		Perceptual = true,
		Tags = { "Sound" },
	}),
	event({
		Id = "StockroomNoise",
		Rarity = "UNCOMMON",
		Intensity = 2,
		MinMinute = 10,
		Cooldown = 10,
		MaxPerShift = 2,
		Tags = { "Stockroom" },
	}),
	event({
		Id = "PhoneRing",
		Rarity = "UNCOMMON",
		Intensity = 2,
		MinMinute = 8,
		Cooldown = 12,
		MaxPerShift = 2,
		Tags = { "Phone" },
	}),
	event({
		Id = "MissingObject",
		Rarity = "UNCOMMON",
		Intensity = 2,
		MinMinute = 12,
		Cooldown = 15,
		MaxPerShift = 2,
		Tags = { "Tasks" },
	}),
	event({
		Id = "CameraFigure",
		Rarity = "UNCOMMON",
		Intensity = 3,
		MinMinute = 14,
		Cooldown = 15,
		MaxPerShift = 1,
		CameraOnly = true,
		Tags = { "Cameras" },
	}),
	event({
		Id = "DoorsSlam",
		Rarity = "UNCOMMON",
		Intensity = 4,
		MinMinute = 25,
		Cooldown = 15,
		MaxPerShift = 1,
		Tags = { "Doors" },
	}),
	event({
		Id = "Blackout",
		Rarity = "RARE",
		Intensity = 4,
		MinMinute = 20,
		Cooldown = 25,
		MaxPerShift = 1,
		Tags = { "Lights", "Generator" },
	}),
	event({
		Id = "Reflection",
		Rarity = "RARE",
		Intensity = 3,
		MinMinute = 15,
		Cooldown = 20,
		MaxPerShift = 1,
		Perceptual = true,
		Tags = { "Mirror" },
	}),
	event({
		Id = "ImpossibleCamera",
		Rarity = "VERY_RARE",
		Intensity = 4,
		MinMinute = 20,
		MaxPerShift = 1,
		CameraOnly = true,
		Tags = { "Cameras" },
	}),

	-- Clientes (NPCs) estranhos
	event({
		Id = "OddCustomer",
		Rarity = "UNCOMMON",
		Intensity = 2,
		MinMinute = 15,
		Cooldown = 20,
		MaxPerShift = 1,
		Tags = { "Customer" },
	}),
	event({
		Id = "CustomerNoRecord",
		Rarity = "VERY_RARE",
		Intensity = 3,
		MinMinute = 25,
		MaxPerShift = 1,
		Tags = { "Customer", "Cameras" },
	}),
	event({ Id = "OldManStory", Rarity = "RARE", Intensity = 1, DiscoveryOnly = true, Tags = { "Lore" } }),

	-- Entidade (controlada pelo EntityService; aqui só para contar descobertas)
	event({
		Id = "EntitySighting",
		Rarity = "RARE",
		Intensity = 3,
		DiscoveryOnly = true,
		Tags = { "Entity" },
	}),
	event({ Id = "EntityStalked", Rarity = "RARE", Intensity = 3, DiscoveryOnly = true, Tags = { "Entity" } }),
	event({
		Id = "EntityManifest",
		Rarity = "VERY_RARE",
		Intensity = 4,
		DiscoveryOnly = true,
		Tags = { "Entity" },
	}),
	event({
		Id = "EntityHunt",
		Rarity = "VERY_RARE",
		Intensity = 5,
		DiscoveryOnly = true,
		Tags = { "Entity" },
	}),

	-- Horários especiais
	event({
		Id = "KnockBackDoor",
		Rarity = "UNCOMMON",
		Intensity = 2,
		SpecialMinute = 17,
		SpecialChance = 0.6,
		Tags = { "Doors" },
	}),
	event({
		Id = "RoadFigure",
		Rarity = "RARE",
		Intensity = 3,
		SpecialMinute = 33,
		SpecialChance = 0.45,
		Tags = { "Outside" },
	}),
	event({
		Id = "DontAnswer",
		Rarity = "SECRET",
		Intensity = 5,
		SpecialMinute = 44,
		SpecialChance = 0.3,
		Secret = true,
		Tags = { "Phone" },
	}),
}

local byId: { [string]: EventDefinition } = {}
for _, definition in EVENTS do
	assert(byId[definition.Id] == nil, `[EventDefinitions] Id repetido: {definition.Id}`)
	byId[definition.Id] = definition
end

local EventDefinitions = {}

EventDefinitions.RARITY_WEIGHTS = RARITY_WEIGHTS

function EventDefinitions.get(eventId: string): EventDefinition?
	return byId[eventId]
end

function EventDefinitions.getAll(): { EventDefinition }
	return table.clone(EVENTS)
end

function EventDefinitions.weightOf(definition: EventDefinition): number
	return RARITY_WEIGHTS[definition.Rarity]
end

return EventDefinitions
