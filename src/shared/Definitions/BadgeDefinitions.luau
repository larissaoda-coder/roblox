--!strict
-- Conquistas. Funcionam mesmo sem badges do Roblox (ficam salvas no perfil).
-- Para dar a badge oficial: crie em create.roblox.com > seu jogo > Badges e troque "BADGE_ID_HERE".
-- Secret = true: o nome aparece como "???" até ser conquistada.

export type BadgeDefinition = {
	Id: string,
	BadgeId: string | number,
	NameKey: string,
	DescriptionKey: string,
	Secret: boolean,
	-- Condições (qualquer uma satisfeita concede):
	Stat: { Name: string, AtLeast: number }?,
	Discover: { string }?, -- descobrir QUALQUER um destes eventos
	DiscoverAll: { string }?, -- descobrir TODOS
	RewardItem: string?,
	RewardTokens: number?,
}

local BADGES: { BadgeDefinition } = {
	{
		Id = "FirstShift",
		BadgeId = "BADGE_ID_HERE",
		NameKey = "BADGE_FIRST_SHIFT",
		DescriptionKey = "BADGE_FIRST_SHIFT_DESC",
		Secret = false,
		Stat = { Name = "ShiftsCompleted", AtLeast = 1 },
	},
	{
		Id = "Survivor",
		BadgeId = "BADGE_ID_HERE",
		NameKey = "BADGE_SURVIVOR",
		DescriptionKey = "BADGE_SURVIVOR_DESC",
		Secret = false,
		Stat = { Name = "ShiftsSurvived", AtLeast = 1 },
		RewardItem = "Title_Survivor",
	},
	{
		Id = "NightOwl",
		BadgeId = "BADGE_ID_HERE",
		NameKey = "BADGE_NIGHT_OWL",
		DescriptionKey = "BADGE_NIGHT_OWL_DESC",
		Secret = false,
		Stat = { Name = "ShiftsCompleted", AtLeast = 10 },
		RewardTokens = 25,
	},
	{
		Id = "CameraMan",
		BadgeId = "BADGE_ID_HERE",
		NameKey = "BADGE_CAMERA_MAN",
		DescriptionKey = "BADGE_CAMERA_MAN_DESC",
		Secret = false,
		Discover = { "CameraFigure", "ImpossibleCamera", "CustomerNoRecord" },
	},
	{
		Id = "DontAnswer",
		BadgeId = "BADGE_ID_HERE",
		NameKey = "BADGE_DONT_ANSWER",
		DescriptionKey = "BADGE_DONT_ANSWER_DESC",
		Secret = false,
		Discover = { "DontAnswer" },
		RewardItem = "Title_DontAnswer",
	},
	{
		Id = "Watched",
		BadgeId = "BADGE_ID_HERE",
		NameKey = "BADGE_SECRET",
		DescriptionKey = "BADGE_WATCHED_DESC",
		Secret = true,
		DiscoverAll = { "EntitySighting", "EntityStalked", "EntityManifest", "EntityHunt" },
		RewardTokens = 50,
	},
}

local BadgeDefinitions = {}

function BadgeDefinitions.getAll(): { BadgeDefinition }
	return table.clone(BADGES)
end

return BadgeDefinitions
