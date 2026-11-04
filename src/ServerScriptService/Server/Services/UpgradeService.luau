--!strict
-- The luck rune: the repeatable coin sink (permanent building is TycoonService).
-- Prices come from Config; the client only asks, the server checks and charges.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local RelicSpawnService = require(script.Parent.RelicSpawnService)

local UpgradeService = {}

local limiter = RateLimiter.new(3, 1)

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
	Net.func("BuyLuck").OnServerInvoke = function(player: Player)
		if not limiter:allow(player) then
			return false, "rate"
		end
		return UpgradeService.buyLuck(player)
	end
end

return UpgradeService
