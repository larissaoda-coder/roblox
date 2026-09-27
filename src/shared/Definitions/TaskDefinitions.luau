--!strict
-- Tarefas do turno. Para adicionar uma tarefa:
--   1. Adicione uma entrada aqui (e os textos em Strings).
--   2. No mapa, coloque as Parts de cada passo com:
--        Tag "Interactable", InteractionType = "Task", TaskId = "<Id>", Point = "<nome do passo>"
-- Uma tarefa só é sorteada se TODOS os seus pontos existirem no mapa.

export type TaskStep = {
	Point: string, -- nome do ponto no mapa (atributo Point)
	PromptKey: string, -- texto do botão de interação
	HoldDuration: number, -- segundos segurando
}

export type TaskDefinition = {
	Id: string,
	NameKey: string,
	DescriptionKey: string,
	LocationKey: string,
	Zone: string, -- zona do mapa (eventos podem acontecer perto de tarefas ativas)
	Steps: { TaskStep },
	Ordered: boolean, -- true = passos em ordem; false = qualquer ordem
	Reward: { Cash: number, XP: number },
	Difficulty: number, -- 1 fácil · 2 média · 3 difícil
	Weight: number, -- chance relativa de ser sorteada
	MinMinute: number, -- só aparece a partir deste minuto do turno
	Maps: { string },
	EventTags: { string }, -- eventos associados (Fase 8)
}

local function step(point: string, promptKey: string, holdDuration: number): TaskStep
	return { Point = point, PromptKey = promptKey, HoldDuration = holdDuration }
end

local TASKS: { TaskDefinition } = {
	{
		Id = "Generator",
		NameKey = "TASK_GENERATOR",
		DescriptionKey = "TASK_GENERATOR_DESC",
		LocationKey = "LOC_BACK",
		Zone = "Back",
		Steps = { step("FuelCan", "PROMPT_TAKE_FUEL", 1.5), step("Generator", "PROMPT_REFUEL", 4) },
		Ordered = true,
		Reward = { Cash = 20, XP = 25 },
		Difficulty = 2,
		Weight = 10,
		MinMinute = 0,
		Maps = { "GasStation" },
		EventTags = { "Generator", "Blackout" },
	},
	{
		Id = "RestockShelves",
		NameKey = "TASK_RESTOCK",
		DescriptionKey = "TASK_RESTOCK_DESC",
		LocationKey = "LOC_STORE",
		Zone = "Store",
		Steps = {
			step("Shelf1", "PROMPT_RESTOCK", 2),
			step("Shelf2", "PROMPT_RESTOCK", 2),
			step("Shelf3", "PROMPT_RESTOCK", 2),
		},
		Ordered = false,
		Reward = { Cash = 15, XP = 20 },
		Difficulty = 1,
		Weight = 10,
		MinMinute = 0,
		Maps = { "GasStation" },
		EventTags = { "Products" },
	},
	{
		Id = "TakeOutTrash",
		NameKey = "TASK_TRASH",
		DescriptionKey = "TASK_TRASH_DESC",
		LocationKey = "LOC_BACK",
		Zone = "Back",
		Steps = { step("TrashBag", "PROMPT_TAKE_TRASH", 1.5), step("Dumpster", "PROMPT_THROW_TRASH", 1) },
		Ordered = true,
		Reward = { Cash = 12, XP = 15 },
		Difficulty = 1,
		Weight = 8,
		MinMinute = 0,
		Maps = { "GasStation" },
		EventTags = { "Outside" },
	},
	{
		Id = "CheckCameras",
		NameKey = "TASK_CAMERAS",
		DescriptionKey = "TASK_CAMERAS_DESC",
		LocationKey = "LOC_OFFICE",
		Zone = "Office",
		Steps = { step("CameraLog", "PROMPT_CHECK_RECORDINGS", 5) },
		Ordered = true,
		Reward = { Cash = 15, XP = 20 },
		Difficulty = 1,
		Weight = 8,
		MinMinute = 5,
		Maps = { "GasStation" },
		EventTags = { "Cameras" },
	},
	{
		Id = "CheckPumps",
		NameKey = "TASK_PUMPS",
		DescriptionKey = "TASK_PUMPS_DESC",
		LocationKey = "LOC_PUMPS",
		Zone = "Pumps",
		Steps = {
			step("Pump1", "PROMPT_CHECK_PUMP", 1.5),
			step("Pump2", "PROMPT_CHECK_PUMP", 1.5),
			step("Pump3", "PROMPT_CHECK_PUMP", 1.5),
			step("Pump4", "PROMPT_CHECK_PUMP", 1.5),
		},
		Ordered = false,
		Reward = { Cash = 18, XP = 22 },
		Difficulty = 2,
		Weight = 9,
		MinMinute = 0,
		Maps = { "GasStation" },
		EventTags = { "Outside", "Customer" },
	},
	{
		Id = "CleanBathroom",
		NameKey = "TASK_BATHROOM",
		DescriptionKey = "TASK_BATHROOM_DESC",
		LocationKey = "LOC_BATHROOM",
		Zone = "Bathroom",
		Steps = { step("Mop", "PROMPT_TAKE_MOP", 1), step("BathroomFloor", "PROMPT_CLEAN", 4) },
		Ordered = true,
		Reward = { Cash = 16, XP = 20 },
		Difficulty = 2,
		Weight = 6,
		MinMinute = 10,
		Maps = { "GasStation" },
		EventTags = { "Mirror", "Bathroom" },
	},
	{
		Id = "LogDelivery",
		NameKey = "TASK_DELIVERY",
		DescriptionKey = "TASK_DELIVERY_DESC",
		LocationKey = "LOC_STOCKROOM",
		Zone = "Stockroom",
		Steps = { step("DeliveryBoxes", "PROMPT_COUNT_BOXES", 3), step("Clipboard", "PROMPT_SIGN", 1.5) },
		Ordered = true,
		Reward = { Cash = 18, XP = 24 },
		Difficulty = 2,
		Weight = 6,
		MinMinute = 15,
		Maps = { "GasStation" },
		EventTags = { "Stockroom" },
	},
	{
		Id = "LockBackDoor",
		NameKey = "TASK_BACKDOOR",
		DescriptionKey = "TASK_BACKDOOR_DESC",
		LocationKey = "LOC_BACK",
		Zone = "Back",
		Steps = { step("BackDoorLock", "PROMPT_LOCK", 1.5) },
		Ordered = true,
		Reward = { Cash = 8, XP = 10 },
		Difficulty = 1,
		Weight = 5,
		MinMinute = 20,
		Maps = { "GasStation" },
		EventTags = { "Doors" },
	},
}

local byId: { [string]: TaskDefinition } = {}
for _, definition in TASKS do
	assert(byId[definition.Id] == nil, `[TaskDefinitions] Id repetido: {definition.Id}`)
	assert(#definition.Steps > 0, `[TaskDefinitions] {definition.Id} precisa de pelo menos um passo`)
	byId[definition.Id] = definition
end

local TaskDefinitions = {}

function TaskDefinitions.get(taskId: string): TaskDefinition?
	return byId[taskId]
end

function TaskDefinitions.getAll(): { TaskDefinition }
	return table.clone(TASKS)
end

function TaskDefinitions.getForMap(mapId: string): { TaskDefinition }
	local list = {}
	for _, definition in TASKS do
		if table.find(definition.Maps, mapId) then
			table.insert(list, definition)
		end
	end
	return list
end

return TaskDefinitions
