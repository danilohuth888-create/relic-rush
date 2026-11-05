--!strict
-- Reasons to come back and to stay: the daily bonus (a 7-day streak; missing a day starts it
-- again at day 1) and playtime gifts that open after some minutes in one session. The client
-- only asks; the server checks the day or the session time and pays.
-- Player attributes for the HUD: SessionStart (os.time of joining), GiftsClaimed ("1,2,...").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Net = require(ReplicatedStorage.Shared.Net)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local MapService = require(script.Parent.MapService)
local RelicSpawnService = require(script.Parent.RelicSpawnService)

type Reward = { coins: number, mapPiece: boolean?, luck: boolean? }
type Session = { start: number, claimed: { [number]: boolean } }

local RewardsService = {}

local limiter = RateLimiter.new(3, 1)
local sessions: { [Player]: Session } = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

-- The streak day the player can claim today, or nil when today's bonus is already taken.
-- Pure so it can be checked with any record.
function RewardsService.dailyDay(daily: { last: number, streak: number }, day: number?): number?
	local now = day or today()
	if daily.last == now then
		return nil
	end
	if daily.last == now - 1 then
		return daily.streak % #Config.Daily.days + 1
	end
	return 1
end

local function notify(player: Player, text: string)
	Net.event("Notify"):FireClient(player, { kind = "reward", text = text })
end

-- Pays a reward (coins scale with the treasury tier); returns the coins paid.
local function pay(player: Player, tier: number, reward: Reward, sku: string): number
	local coins = reward.coins * (Config.Daily.tierFactor[tier] or 1)
	EconomyService.grant(player, coins, sku)
	if reward.mapPiece then
		MapService.addPiece(player)
	end
	if reward.luck then
		local current = player:GetAttribute("LuckUntil")
		local from = if type(current) == "number" and current > os.time() then current else os.time()
		player:SetAttribute("LuckUntil", from + Config.LuckRune.seconds)
		RelicSpawnService.reroll(player)
	end
	return coins
end

function RewardsService.claimDaily(player: Player): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "not_loaded"
	end
	local day = RewardsService.dailyDay(data.daily)
	if not day then
		return false, "claimed"
	end
	data.daily.last = today()
	data.daily.streak = day
	local coins = pay(player, data.tier, Config.Daily.days[day], "daily_bonus")
	notify(player, Locale.format(Locale.of(player), "Tagesbonus Tag %d: +%d Münzen!", day, coins))
	Analytics.custom(player, "DailyBonus")
	PlayerDataService.replicate(player)
	return true, nil
end

local function encode(claimed: { [number]: boolean }): string
	local list = {}
	for index in claimed do
		table.insert(list, tostring(index))
	end
	table.sort(list)
	return table.concat(list, ",")
end

function RewardsService.claimGift(player: Player, index: any): (boolean, string?)
	if type(index) ~= "number" or index % 1 ~= 0 then
		return false, "bad_gift"
	end
	local gift = Config.Gifts[index]
	local session = sessions[player]
	local data = PlayerDataService.get(player)
	if not gift or not session or not data then
		return false, "bad_gift"
	end
	if session.claimed[index] then
		return false, "claimed"
	end
	if os.time() - session.start < gift.minutes * 60 then
		return false, "not_ready"
	end
	session.claimed[index] = true
	player:SetAttribute("GiftsClaimed", encode(session.claimed))
	local coins = pay(player, data.tier, gift, "playtime_gift")
	notify(player, Locale.format(Locale.of(player), "Geschenk geöffnet: +%d Münzen!", coins))
	Analytics.custom(player, "GiftClaimed")
	return true, nil
end

function RewardsService.startPlayer(player: Player)
	local session = { start = os.time(), claimed = {} }
	sessions[player] = session
	player:SetAttribute("SessionStart", session.start)
	player:SetAttribute("GiftsClaimed", "")
end

function RewardsService.stopPlayer(player: Player)
	sessions[player] = nil
end

-- Studio DevTools: pretend the session started this many seconds earlier.
function RewardsService.skipTime(player: Player, seconds: number)
	local session = sessions[player]
	if session then
		session.start -= seconds
		player:SetAttribute("SessionStart", session.start)
	end
end

function RewardsService.init()
	Net.func("ClaimDaily").OnServerInvoke = function(player: Player)
		if not limiter:allow(player) then
			return false, "rate"
		end
		return RewardsService.claimDaily(player)
	end
	Net.func("ClaimGift").OnServerInvoke = function(player: Player, index: any)
		if not limiter:allow(player) then
			return false, "rate"
		end
		return RewardsService.claimGift(player, index)
	end
end

return RewardsService
