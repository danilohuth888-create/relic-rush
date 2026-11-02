--!strict
-- Token bucket per player. Each remote gets its own limiter so spam on one action
-- cannot starve another.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, t: number }
export type RateLimiter = typeof(setmetatable({} :: { capacity: number, refill: number, buckets: { [Player]: Bucket } }, RateLimiter))

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	return setmetatable({
		capacity = capacity,
		refill = refillPerSecond,
		buckets = setmetatable({}, { __mode = "k" }) :: any,
	}, RateLimiter)
end

function RateLimiter.allow(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local bucket = self.buckets[player]
	if not bucket then
		bucket = { tokens = self.capacity, t = now }
		self.buckets[player] = bucket
	end
	bucket.tokens = math.min(self.capacity, bucket.tokens + (now - bucket.t) * self.refill)
	bucket.t = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

return RateLimiter
