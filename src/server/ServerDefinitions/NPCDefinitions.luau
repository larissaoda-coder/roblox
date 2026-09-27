--!strict
-- Clientes do posto. SpawnMode:
--   "Schedule" = aparecem sozinhos ao longo do turno (sorteados por Weight)
--   "Event"    = só aparecem quando um evento chama (raros/sobrenaturais; controlados pelo Director)

export type NPCDefinition = {
	Id: string,
	NameKey: string,
	DialogueId: string,
	SpawnMode: "Schedule" | "Event",
	Weight: number,
	MinMinute: number,
	Colors: { Skin: Color3, Shirt: Color3, Pants: Color3 },
	Height: number,
	WalkSpeed: number,
	NoCameraRecord: boolean, -- não aparece nas câmeras de segurança
}

local function npc(data: { [string]: any }): NPCDefinition
	return {
		Id = data.Id,
		NameKey = data.NameKey,
		DialogueId = data.DialogueId or data.Id,
		SpawnMode = data.SpawnMode or "Schedule",
		Weight = data.Weight or 10,
		MinMinute = data.MinMinute or 0,
		Colors = data.Colors,
		Height = data.Height or 1,
		WalkSpeed = data.WalkSpeed or 8,
		NoCameraRecord = data.NoCameraRecord == true,
	}
end

local SKIN = {
	Light = Color3.fromRGB(234, 200, 170),
	Medium = Color3.fromRGB(190, 140, 100),
	Dark = Color3.fromRGB(110, 75, 50),
	Pale = Color3.fromRGB(215, 215, 210),
}

local NPCS: { NPCDefinition } = {
	npc({
		Id = "Commuter",
		NameKey = "NPC_COMMUTER",
		Weight = 14,
		Colors = {
			Skin = SKIN.Light,
			Shirt = Color3.fromRGB(60, 80, 120),
			Pants = Color3.fromRGB(40, 40, 46),
		},
	}),
	npc({
		Id = "Driver",
		NameKey = "NPC_DRIVER",
		Weight = 12,
		Colors = {
			Skin = SKIN.Medium,
			Shirt = Color3.fromRGB(120, 40, 40),
			Pants = Color3.fromRGB(50, 60, 80),
		},
	}),
	npc({
		Id = "Trucker",
		NameKey = "NPC_TRUCKER",
		Weight = 9,
		MinMinute = 8,
		Height = 1.08,
		Colors = { Skin = SKIN.Dark, Shirt = Color3.fromRGB(90, 110, 70), Pants = Color3.fromRGB(60, 50, 40) },
	}),
	npc({
		Id = "Police",
		NameKey = "NPC_POLICE",
		Weight = 5,
		MinMinute = 15,
		Colors = {
			Skin = SKIN.Medium,
			Shirt = Color3.fromRGB(30, 40, 70),
			Pants = Color3.fromRGB(25, 30, 50),
		},
	}),
	npc({
		Id = "Delivery",
		NameKey = "NPC_DELIVERY",
		Weight = 6,
		MinMinute = 10,
		Colors = {
			Skin = SKIN.Light,
			Shirt = Color3.fromRGB(150, 110, 40),
			Pants = Color3.fromRGB(70, 60, 40),
		},
	}),
	npc({
		Id = "OldMan",
		NameKey = "NPC_OLDMAN",
		Weight = 1.5,
		MinMinute = 20,
		WalkSpeed = 5,
		Colors = {
			Skin = SKIN.Light,
			Shirt = Color3.fromRGB(100, 90, 80),
			Pants = Color3.fromRGB(70, 65, 60),
		},
	}),

	-- Só por evento.
	npc({
		Id = "Strange",
		NameKey = "NPC_STRANGE",
		SpawnMode = "Event",
		WalkSpeed = 5,
		Colors = { Skin = SKIN.Pale, Shirt = Color3.fromRGB(40, 40, 40), Pants = Color3.fromRGB(30, 30, 30) },
	}),
	npc({
		Id = "NoRecord",
		NameKey = "NPC_NORECORD",
		SpawnMode = "Event",
		WalkSpeed = 6,
		Height = 1.1,
		NoCameraRecord = true,
		Colors = { Skin = SKIN.Pale, Shirt = Color3.fromRGB(20, 20, 22), Pants = Color3.fromRGB(20, 20, 22) },
	}),
}

local byId: { [string]: NPCDefinition } = {}
for _, definition in NPCS do
	byId[definition.Id] = definition
end

local NPCDefinitions = {}

function NPCDefinitions.get(npcId: string): NPCDefinition?
	return byId[npcId]
end

function NPCDefinitions.getAll(): { NPCDefinition }
	return table.clone(NPCS)
end

return NPCDefinitions
