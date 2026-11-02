--!strict
-- Coin sinks: treasury tier upgrades (permanent) and the luck rune (repeatable, temporary).
-- Prices come from Config; the client only asks, the server checks and charges.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local Progress = require(script.Parent.Parent.Util.Progress)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)
local RelicSpawnService = require(script.Parent.RelicSpawnService)

local UpgradeService = {}

local limiter = RateLimiter.new(3, 1)

function UpgradeService.upgrade(player: Player): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "not_loaded"
	end
	local nextTier = Config.Tiers[data.tier + 1]
	if not nextTier then
		return false, "max_tier"
	end
	if not EconomyService.trySpend(player, nextTier.cost, "tier_" .. (data.tier + 1)) then
		return false, "no_coins"
	end
	data.tier += 1
	data.stats.upgrades += 1
	if data.stats.upgrades == 1 then
		Analytics.onboarding(player, Analytics.Onboarding.FirstUpgrade)
	end
	PlotService.applyTier(player, data.tier)
	PlayerDataService.replicate(player)
	Progress.bump(player, "upgrade", 1)
	Net.event("Notify"):FireClient(player, {
		kind = "upgrade",
		text = ("%s freigeschaltet! Jetzt %d Podeste."):format(nextTier.name, nextTier.pedestals),
	})
	return true, nil
end

function UpgradeService.buyLuck(player: Player): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "not_loaded"
	end
	local current = player:GetAttribute("LuckUntil")
	if type(current) == "number" and current > os.time() then
		return false, "luck_active"
	end
	if not EconomyService.trySpend(player, Config.LuckRune.costByTier[data.tier], "luck_rune") then
		return false, "no_coins"
	end
	player:SetAttribute("LuckUntil", os.time() + Config.LuckRune.seconds)
	RelicSpawnService.reroll(player)
	return true, nil
end

function UpgradeService.init()
	Net.func("Upgrade").OnServerInvoke = function(player: Player)
		if not limiter:allow(player) then
			return false, "rate"
		end
		return UpgradeService.upgrade(player)
	end
	Net.func("BuyLuck").OnServerInvoke = function(player: Player)
		if not limiter:allow(player) then
			return false, "rate"
		end
		return UpgradeService.buyLuck(player)
	end
end

return UpgradeService
