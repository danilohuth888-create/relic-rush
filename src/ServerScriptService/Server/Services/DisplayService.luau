--!strict
-- Moves relics between a player's inventory and the pedestals of their own plot.
-- Clients only send (slot, relicId); ownership, tier, range and counts are checked here, and
-- each move is applied without yielding so a relic can never exist twice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local Progress = require(script.Parent.Parent.Util.Progress)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)

local DisplayService = {}

local limiter = RateLimiter.new(6, 3)

local function validSlot(slot: any): boolean
	return type(slot) == "number" and slot % 1 == 0 and slot >= 1 and slot <= Config.MaxPedestals
end

local function inRange(player: Player, pedestal: Model): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local distance = (root.Position - pedestal:GetPivot().Position).Magnitude
	return distance <= Config.PedestalRange + Config.RangeTolerance
end

-- Shared checks for both actions. Returns the profile and pedestal or an error code.
local function check(player: Player, slot: any): (PlayerDataService.Data?, Model?, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return nil, nil, "not_loaded"
	end
	if not validSlot(slot) then
		return nil, nil, "bad_slot"
	end
	if slot > Config.Tiers[data.tier].pedestals then
		return nil, nil, "locked_slot"
	end
	local pedestal = PlotService.getPedestal(player, slot)
	if not pedestal then
		return nil, nil, "no_plot"
	end
	if not inRange(player, pedestal) then
		return nil, nil, "too_far"
	end
	return data, pedestal, nil
end

local function addToInventory(data: PlayerDataService.Data, relicId: string)
	data.inventory[relicId] = (data.inventory[relicId] or 0) + 1
end

local function takeFromInventory(data: PlayerDataService.Data, relicId: string)
	local left = (data.inventory[relicId] or 0) - 1
	data.inventory[relicId] = if left > 0 then left else nil
end

local function changed(player: Player, slot: number, relicId: string?)
	PlotService.renderSlot(player, slot, relicId)
	EconomyService.recompute(player)
	PlayerDataService.replicate(player)
end

function DisplayService.place(player: Player, slot: any, relicId: any): (boolean, string?)
	if type(relicId) ~= "string" or not RelicDefs.byId[relicId] then
		return false, "bad_relic"
	end
	local data, _, err = check(player, slot)
	if not data then
		return false, err
	end
	if (data.inventory[relicId] or 0) < 1 then
		return false, "not_owned"
	end
	local key = tostring(slot)
	local previous = data.display[key]
	if previous == relicId then
		return true, nil
	end
	takeFromInventory(data, relicId)
	if previous then
		addToInventory(data, previous)
	end
	data.display[key] = relicId
	data.stats.placed += 1
	if data.stats.placed == 1 then
		Analytics.onboarding(player, Analytics.Onboarding.FirstDisplay)
	end
	Progress.bump(player, "place", 1)
	changed(player, slot, relicId)
	return true, nil
end

function DisplayService.unplace(player: Player, slot: any): (boolean, string?)
	local current = PlayerDataService.get(player)
	if current and validSlot(slot) and not current.display[tostring(slot)] then
		return false, "empty"
	end
	local data, _, err = check(player, slot)
	if not data then
		return false, err
	end
	local key = tostring(slot)
	local previous = data.display[key]
	if not previous then
		return false, "empty"
	end
	data.display[key] = nil
	addToInventory(data, previous)
	changed(player, slot, nil)
	return true, nil
end

function DisplayService.init()
	Net.func("Place").OnServerInvoke = function(player: Player, slot: any, relicId: any)
		if not limiter:allow(player) then
			return false, "rate"
		end
		return DisplayService.place(player, slot, relicId)
	end
	Net.func("Unplace").OnServerInvoke = function(player: Player, slot: any)
		if not limiter:allow(player) then
			return false, "rate"
		end
		return DisplayService.unplace(player, slot)
	end
end

return DisplayService
