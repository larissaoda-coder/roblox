--!strict
-- Limite de chamadas por chave (normalmente um Player), no formato "Max chamadas a cada Per segundos".
-- Usa "token bucket": permite pequenas rajadas, mas não um fluxo constante acima do limite.

export type RateLimiter = {
	Check: (self: RateLimiter, key: any) -> boolean,
	Reset: (self: RateLimiter, key: any) -> (),
}

type Bucket = { tokens: number, updatedAt: number }

local RateLimiter = {}

function RateLimiter.new(maxCalls: number, perSeconds: number): RateLimiter
	assert(maxCalls >= 1 and perSeconds > 0, "RateLimiter: valores inválidos")

	local refillPerSecond = maxCalls / perSeconds
	local buckets: { [any]: Bucket } = {}
	local self = {} :: RateLimiter

	function self:Check(key: any): boolean
		local now = os.clock()
		local bucket = buckets[key]
		if not bucket then
			bucket = { tokens = maxCalls, updatedAt = now }
			buckets[key] = bucket
		end

		bucket.tokens = math.min(maxCalls, bucket.tokens + (now - bucket.updatedAt) * refillPerSecond)
		bucket.updatedAt = now

		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end

	function self:Reset(key: any)
		buckets[key] = nil
	end

	return self
end

return RateLimiter
