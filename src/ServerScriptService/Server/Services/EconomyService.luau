--!strict
-- Server-side coin production: every displayed relic adds its catalogue rate per second.
-- Coins are published as the player attribute "Coins" (whole number) and in leaderstats.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EconomyService = {}

local rates: { [Player]: number } = {}

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

function EconomyService.recompute(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		rates[player] = nil
		return
	end
	local rate = EconomyService.rateFor(data.display)
	rates[player] = rate
	player:SetAttribute("CoinRate", rate)
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
end

function EconomyService.forget(player: Player)
	rates[player] = nil
end

-- Atomic check-and-subtract; callers must not yield between deciding and calling this.
function EconomyService.trySpend(player: Player, amount: number): boolean
	local data = PlayerDataService.get(player)
	if not data or amount < 0 or data.coins < amount then
		return false
	end
	data.coins -= amount
	publish(player, data.coins)
	return true
end

function EconomyService.init()
	task.spawn(function()
		while true do
			local dt = task.wait(Config.EconomyTickSeconds)
			for player, rate in rates do
				local data = PlayerDataService.get(player)
				if data and rate > 0 then
					data.coins += rate * dt
					publish(player, data.coins)
				end
			end
		end
	end)
end

return EconomyService
