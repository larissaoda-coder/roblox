--!strict
-- A entidade principal ("Watcher", nome provisório). Rara de propósito: quase sempre observa;
-- só caça no fim do turno ou quando um segredo a desperta.
--
-- Estados: Dormant → Watching | Stalking | Manifest | Hunt → Retreat → Dormant
-- Temperamento: sorteado a cada partida, muda o que ela prefere fazer.

export type Temperament = {
	Name: string,
	Weight: number,
	Watch: number,
	Stalk: number,
	Manifest: number,
	Hunt: number,
	HuntMinMinute: number,
}

local EntityDefinitions = {
	Watcher = {
		Id = "Watcher",
		Scale = 1.15,

		COOLDOWN_MIN_MINUTES = 4,
		COOLDOWN_MAX_MINUTES = 8,
		APPEAR_CHANCE_PER_MINUTE = 0.35,
		MAX_HUNTS_PER_SHIFT = 2,

		WATCH_SECONDS_MIN = 12,
		WATCH_SECONDS_MAX = 20,
		VANISH_DISTANCE = 35, -- some se alguém chega perto enquanto observa

		STALK_SECONDS = 15,
		STALK_MIN_DISTANCE = 22,

		MANIFEST_SECONDS = 1.6,
		MANIFEST_RADIUS = 24,

		HUNT_SECONDS = 14,
		HUNT_SPEED = 15, -- jogador anda a 16: dá para fugir
		KILL_DISTANCE = 4.5,
		HUNT_START_DISTANCE = 45,

		TEMPERAMENTS = {
			{
				Name = "Shy",
				Weight = 40,
				Watch = 0.7,
				Stalk = 0.2,
				Manifest = 0.1,
				Hunt = 0.05,
				HuntMinMinute = 52,
			},
			{
				Name = "Curious",
				Weight = 40,
				Watch = 0.4,
				Stalk = 0.4,
				Manifest = 0.2,
				Hunt = 0.1,
				HuntMinMinute = 45,
			},
			{
				Name = "Aggressive",
				Weight = 20,
				Watch = 0.3,
				Stalk = 0.3,
				Manifest = 0.2,
				Hunt = 0.25,
				HuntMinMinute = 35,
			},
		} :: { Temperament },
	},
}

return EntityDefinitions
