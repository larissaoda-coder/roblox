--!strict
-- Gerador de números aleatórios com seed. Cada partida usa sua própria seed, o que permite
-- reproduzir uma partida para depurar ("seed 12345 gerou tal combinação").

export type Rng = {
	Seed: number,
	Integer: (self: Rng, min: number, max: number) -> number,
	Number: (self: Rng, min: number?, max: number?) -> number,
	Chance: (self: Rng, probability: number) -> boolean,
	Pick: <T>(self: Rng, list: { T }) -> T?,
	WeightedPick: <T>(self: Rng, list: { T }, weightOf: (T) -> number) -> T?,
	Shuffle: <T>(self: Rng, list: { T }) -> { T },
}

local Rng = {}

function Rng.new(seed: number?): Rng
	local actualSeed = seed or math.floor(os.clock() * 1000) % 2147483647
	local random = Random.new(actualSeed)
	local rng = { Seed = actualSeed } :: Rng

	function rng:Integer(min: number, max: number): number
		return random:NextInteger(min, max)
	end

	function rng:Number(min: number?, max: number?): number
		return random:NextNumber(min or 0, max or 1)
	end

	function rng:Chance(probability: number): boolean
		return random:NextNumber() < probability
	end

	function rng:Pick<T>(list: { T }): T?
		if #list == 0 then
			return nil
		end
		return list[random:NextInteger(1, #list)]
	end

	function rng:WeightedPick<T>(list: { T }, weightOf: (T) -> number): T?
		local total = 0
		for _, item in list do
			total += math.max(0, weightOf(item))
		end
		if total <= 0 then
			return nil
		end
		local roll = random:NextNumber() * total
		for _, item in list do
			roll -= math.max(0, weightOf(item))
			if roll <= 0 then
				return item
			end
		end
		return list[#list]
	end

	-- Retorna uma cópia embaralhada.
	function rng:Shuffle<T>(list: { T }): { T }
		local copy = table.clone(list)
		for index = #copy, 2, -1 do
			local other = random:NextInteger(1, index)
			copy[index], copy[other] = copy[other], copy[index]
		end
		return copy
	end

	return rng
end

return Rng
