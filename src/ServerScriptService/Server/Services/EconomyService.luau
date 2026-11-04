--!strict
-- Server-side coin production: every displayed relic adds its catalogue rate per second.
-- Production flows into the treasure chest in the plot's yard (player attribute "Pending");
-- the owner collects it by walking into the chest (TycoonService), and it is paid out
-- automatically when the player leaves. Coins are published as the player attribute "Coins"
-- (whole number) and in leaderstats. All coin changes go through grant/trySpend so analytics
-- and quests see every flow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builds = require(ReplicatedStorage.Shared.Builds)
local Config = require(ReplicatedStorage.Shared.Config)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local Progress = require(script.Parent.Parent.Util.Progress)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EconomyService = {}

local rates: { [Player]: number } = {}
local pending: { [Player]: number } = {}

local function publishPending(player: Player)
	local whole = math.floor(pending[player] or 0)
	if player:GetAttribute("Pending") ~= whole then
		player:SetAttribute("Pending", whole)
	end
end

local function publish(player: Player, coins: number)
	local whole = math.floor(coins)
	if player:GetAttribute("Coins") ~= whole then
		player:SetAttribute("Coins", whole)
		local stats = player:FindFirstChild("leaderstats")
		local value = stats and stats:FindFirstChild("Münzen")
		if value and value:IsA("IntValue") then
			value.Value = whole
		end
	end
end

-- Pure so balancing tests can call it with any display table.
function EconomyService.rateFor(display: { [string]: string }): number
	local total = 0
	for _, relicId in display do
		local def = RelicDefs.byId[relicId]
		if def then
			total += def.rate
		end
	end
	return total
end

local function multiplier(player: Player): number
	return if player:GetAttribute("Pass_double_coins") then 2 else 1
end

function EconomyService.recompute(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		rates[player] = nil
		return
	end
	local rate = EconomyService.rateFor(data.display) * multiplier(player) * Builds.multiplier(data.builds)
	rates[player] = rate
	player:SetAttribute("CoinRate", rate)
end

-- Adds coins from gameplay (sku names the reason, e.g. "quest") or a purchase.
function EconomyService.grant(player: Player, amount: number, sku: string, isPurchase: boolean?)
	local data = PlayerDataService.get(player)
	if not data or amount <= 0 then
		return
	end
	data.coins += amount
	publish(player, data.coins)
	if not isPurchase then
		data.stats.coinsEarned += amount
		Progress.bump(player, "earn", amount)
	end
	Analytics.coins(player, "source", amount, data.coins, sku, isPurchase)
end

-- Atomic check-and-subtract; callers must not yield between deciding and calling this.
function EconomyService.trySpend(player: Player, amount: number, sku: string): boolean
	local data = PlayerDataService.get(player)
	if not data or amount < 0 or data.coins < amount then
		return false
	end
	data.coins -= amount
	publish(player, data.coins)
	Analytics.coins(player, "sink", amount, data.coins, sku)
	return true
end

function EconomyService.setup(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local value = Instance.new("IntValue")
	value.Name = "Münzen"
	value.Parent = stats
	stats.Parent = player
	publish(player, data.coins)
	EconomyService.recompute(player)

	-- Offline earnings for returning players, at a reduced and capped rate.
	if data.lastSeen > 0 then
		local away = math.clamp(os.time() - data.lastSeen, 0, Config.OfflineCapSeconds)
		local earned = math.floor(away * EconomyService.rateFor(data.display) * Builds.multiplier(data.builds) * Config.OfflineRate)
		if earned > 0 then
			EconomyService.grant(player, earned, "offline")
			Net.event("Notify"):FireClient(player, {
				kind = "offline",
				text = Locale.format(Locale.of(player), "Willkommen zurück! Deine Relikte haben %d Münzen erzeugt.", earned),
			})
		end
	end
end

-- Moves the chest's coins into the balance; returns how many whole coins were collected.
function EconomyService.collect(player: Player): number
	local amount = math.floor(pending[player] or 0)
	if amount < 1 then
		return 0
	end
	pending[player] -= amount
	EconomyService.grant(player, amount, "income")
	publishPending(player)
	return amount
end

function EconomyService.pending(player: Player): number
	return pending[player] or 0
end

-- Pays out what is still in the chest (the player is leaving) and forgets the player.
function EconomyService.forget(player: Player)
	local rest = pending[player] or 0
	if rest > 0 then
		pending[player] = 0
		EconomyService.grant(player, rest, "income")
	end
	pending[player] = nil
	rates[player] = nil
end

function EconomyService.init()
	task.spawn(function()
		while true do
			local dt = task.wait(Config.EconomyTickSeconds)
			for player, rate in rates do
				local data = PlayerDataService.get(player)
				if data and rate > 0 then
					pending[player] = (pending[player] or 0) + rate * dt
					publishPending(player)
				end
			end
		end
	end)
end

return EconomyService
