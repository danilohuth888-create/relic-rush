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
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

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
function RelicSpawnService.roll(area: string, random: Random?): string
	local r = random or rng
	local pool = poolsByArea[area] or poolsByArea.Plaza
	local total = 0
	for _, rarity in Config.RarityOrder do
		if pool[rarity] then
			total += Config.Rarities[rarity].weight
		end
	end
	local pick = r:NextNumber() * total
	for _, rarity in Config.RarityOrder do
		local ids = pool[rarity]
		if ids then
			pick -= Config.Rarities[rarity].weight
			if pick <= 0 then
				return ids[r:NextInteger(1, #ids)]
			end
		end
	end
	local fallback = pool[Config.RarityOrder[1]]
	return fallback[1]
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
			state.active[id] = RelicSpawnService.roll(point.area)
		end
	end
	states[player] = state
end

function RelicSpawnService.stopPlayer(player: Player)
	states[player] = nil
end

function RelicSpawnService.collect(player: Player, spawnId: any): (boolean, string?)
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
	data.inventory[relicId] = (data.inventory[relicId] or 0) + 1
	data.stats.collected += 1
	PlayerDataService.replicate(player)
	return true, relicId
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
						local relicId = RelicSpawnService.roll(points[id].area)
						state.active[id] = relicId
						spawnAdded:FireClient(player, entry(points[id], relicId))
					end
				end
			end
		end
	end)
end

return RelicSpawnService
