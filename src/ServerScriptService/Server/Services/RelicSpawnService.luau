--!strict
-- Personal relic spawns: every player has their own relic at each spawn point, so nobody
-- competes for the first reward and nobody can grief another player's pickups.
-- The server decides which relic sits where; clients render it and ask to collect by spawn id.
-- Spawn points are parts in Workspace.Aetheria.RelicSpawns with attributes
--   SpawnId (string), Area (string), Starter (bool), RespawnSeconds (number)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local Progress = require(script.Parent.Parent.Util.Progress)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RelicVisuals = require(ReplicatedStorage.Shared.RelicVisuals)

type SpawnPoint = { id: string, position: Vector3, area: string, starter: boolean, respawn: number }
type PlayerSpawns = { active: { [string]: string }, cooldown: { [string]: number } }

local RelicSpawnService = {}

local points: { [string]: SpawnPoint } = {}
local states: { [Player]: PlayerSpawns } = {}
local poolsByArea: { [string]: { [string]: { string } } } = {} -- area -> rarity -> relic ids
local rng = Random.new()
local limiter = RateLimiter.new(5, 3)

local function buildPools()
	for _, def in RelicDefs.list do
		for _, area in def.sources do
			local pool = poolsByArea[area] or {}
			poolsByArea[area] = pool
			pool[def.rarity] = pool[def.rarity] or {}
			table.insert(pool[def.rarity], def.id)
		end
	end
end

-- Picks a rarity by weight among the rarities this area offers, then a relic of that rarity.
-- luck multiplies the weight of every rarity above Common (luck rune).
function RelicSpawnService.roll(area: string, random: Random?, luck: number?): string
	local r = random or rng
	local pool = poolsByArea[area] or poolsByArea.Plaza
	local function weight(rarity: string): number
		local w = Config.Rarities[rarity].weight
		return if rarity ~= Config.RarityOrder[1] then w * (luck or 1) else w
	end
	local total = 0
	for _, rarity in Config.RarityOrder do
		if pool[rarity] then
			total += weight(rarity)
		end
	end
	local pick = r:NextNumber() * total
	for _, rarity in Config.RarityOrder do
		local ids = pool[rarity]
		if ids then
			pick -= weight(rarity)
			if pick <= 0 then
				return ids[r:NextInteger(1, #ids)]
			end
		end
	end
	local fallback = pool[Config.RarityOrder[1]]
	return fallback[1]
end

local function luckFor(player: Player): number
	local untilTime = player:GetAttribute("LuckUntil")
	return if type(untilTime) == "number" and untilTime > os.time() then Config.LuckRune.multiplier else 1
end

local function entry(point: SpawnPoint, relicId: string)
	return { id = point.id, relicId = relicId, position = point.position }
end

function RelicSpawnService.list(player: Player): { any }
	local state = states[player]
	local result = {}
	if state then
		for id, relicId in state.active do
			table.insert(result, entry(points[id], relicId))
		end
	end
	return result
end

function RelicSpawnService.startPlayer(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local state: PlayerSpawns = { active = {}, cooldown = {} }
	for id, point in points do
		if point.starter and data.stats.collected == 0 then
			state.active[id] = Config.StarterRelic
		else
			state.active[id] = RelicSpawnService.roll(point.area, nil, luckFor(player))
		end
	end
	states[player] = state
end

function RelicSpawnService.stopPlayer(player: Player)
	states[player] = nil
end

-- Re-rolls every relic currently waiting for the player (used when a luck rune starts).
function RelicSpawnService.reroll(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local spawnAdded = Net.event("SpawnAdded")
	for id in state.active do
		local relicId = RelicSpawnService.roll(points[id].area, nil, luckFor(player))
		state.active[id] = relicId
		spawnAdded:FireClient(player, entry(points[id], relicId))
	end
end

function RelicSpawnService.collect(player: Player, spawnId: any): (boolean, string?, boolean?)
	if type(spawnId) ~= "string" then
		return false, "bad_spawn"
	end
	local state = states[player]
	local point = points[spawnId]
	local data = PlayerDataService.get(player)
	if not state or not point or not data then
		return false, "unknown"
	end
	local relicId = state.active[spawnId]
	if not relicId then
		return false, "gone"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - point.position).Magnitude > Config.CollectRange + Config.RangeTolerance then
		return false, "too_far"
	end
	state.active[spawnId] = nil
	state.cooldown[spawnId] = os.clock() + point.respawn
	local isNew = RelicSpawnService.grant(player, relicId, point.area)
	return true, relicId, isNew
end

-- Puts a relic into the player's inventory and reports it like any find (quests, collection
-- book, analytics). Used by pickups and by expedition rewards. Returns whether it was new.
function RelicSpawnService.grant(player: Player, relicId: string, area: string): boolean
	local data = PlayerDataService.get(player)
	local def = RelicDefs.byId[relicId]
	if not data or not def then
		return false
	end
	data.inventory[relicId] = (data.inventory[relicId] or 0) + 1
	data.stats.collected += 1
	local isNew = not data.discovered[relicId]
	data.discovered[relicId] = true

	if data.stats.collected == 1 then
		Analytics.onboarding(player, Analytics.Onboarding.FirstRelic)
	end
	Progress.bump(player, "collect", 1)
	if area == "Forest" then
		Progress.bump(player, "collectForest", 1)
	end
	if RelicVisuals.rarityRank(def.rarity) >= 2 then
		Progress.bump(player, "collectUncommon", 1)
	end
	if isNew then
		Progress.bump(player, "discover", 1, relicId)
	end
	PlayerDataService.replicate(player)
	return isNew
end

-- Relic ids an area can produce, grouped by rarity (read-only).
function RelicSpawnService.pool(area: string): { [string]: { string } }
	return poolsByArea[area] or {}
end

function RelicSpawnService.init()
	buildPools()
	local folder = Workspace:WaitForChild("Aetheria"):WaitForChild("RelicSpawns")
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			local id = part:GetAttribute("SpawnId") :: string? or part.Name
			points[id] = {
				id = id,
				position = part.Position,
				area = part:GetAttribute("Area") :: string? or "Plaza",
				starter = part:GetAttribute("Starter") == true,
				respawn = part:GetAttribute("RespawnSeconds") :: number? or Config.DefaultRespawnSeconds,
			}
		end
	end

	Net.func("GetSpawns").OnServerInvoke = function(player: Player)
		local deadline = os.clock() + 30
		while not states[player] and player.Parent and os.clock() < deadline do
			task.wait(0.2)
		end
		return RelicSpawnService.list(player)
	end
	Net.func("Collect").OnServerInvoke = function(player: Player, spawnId: any)
		if not limiter:allow(player) then
			return false, "rate"
		end
		return RelicSpawnService.collect(player, spawnId)
	end

	local spawnAdded = Net.event("SpawnAdded")
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, state in states do
				for id, readyAt in state.cooldown do
					if now >= readyAt then
						state.cooldown[id] = nil
						local relicId = RelicSpawnService.roll(points[id].area, nil, luckFor(player))
						state.active[id] = relicId
						spawnAdded:FireClient(player, entry(points[id], relicId))
					end
				end
			end
		end
	end)
end

return RelicSpawnService
