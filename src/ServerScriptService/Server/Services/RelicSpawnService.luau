--!strict
-- Guardian spirits: every player has their own spirit at each spawn point, carrying a relic.
-- Spirits wander near home, flee when their player comes close, tire after a while and are
-- caught by touching them. Everything is simulated here (5 times a second): the client only
-- draws the spirits from the positions it is sent, so nothing about catching can be faked,
-- and a player standing still never catches anything (fresh spirits appear away from them).
-- Spawn points are parts in Workspace.Aetheria.RelicSpawns with attributes
--   SpawnId (string), Area (string), Starter (bool), RespawnSeconds (number)
-- The Treasure Isle adds Workspace.TreasureIsle.IsleSpawns (Area "Isle", plus Pool and Trick);
-- those spirits only exist while the player is visiting the isle (startIsle / stopIsle).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local RelicVisuals = require(ReplicatedStorage.Shared.RelicVisuals)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local Progress = require(script.Parent.Parent.Util.Progress)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SPIRITS = Config.Spirits
local ISLE = Config.Isle
local TICK = 0.2
local HOVER = 2.5 -- studs above the spawn point

type SpawnPoint = { id: string, position: Vector3, area: string, starter: boolean, respawn: number, pool: string?, trick: string? }
type Spirit = {
	relicId: string,
	pos: Vector3,
	stamina: number,
	tiredUntil: number,
	dodge: number, -- -1 / 1: which way it sidesteps when cornered
	dodgeAt: number,
	state: string, -- "idle" | "flee" | "tired"
	phase: number,
	starter: boolean,
	trickAt: number, -- isle spirits: next time a dash or blink is allowed
	dashUntil: number,
}
type PlayerSpawns = { active: { [string]: Spirit }, cooldown: { [string]: number }, isle: boolean }

local RelicSpawnService = {}

local points: { [string]: SpawnPoint } = {}
local states: { [Player]: PlayerSpawns } = {}
local poolsByArea: { [string]: { [string]: { string } } } = {} -- area -> rarity -> relic ids
local byRarity: { [string]: { string } } = {} -- every relic of a rarity, whatever its source
local rng = Random.new()

local function buildPools()
	for _, def in RelicDefs.list do
		byRarity[def.rarity] = byRarity[def.rarity] or {}
		table.insert(byRarity[def.rarity], def.id)
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

-- A relic by rarity weights (e.g. Config.Isle.spirits.easy), from all relics of that rarity.
function RelicSpawnService.rollWeighted(weights: { [string]: number }, random: Random?): string
	local r = random or rng
	local total = 0
	for _, w in weights do
		total += w
	end
	local pick = r:NextNumber() * total
	local chosen = Config.RarityOrder[2]
	for _, rarity in Config.RarityOrder do
		local w = weights[rarity]
		if w then
			pick -= w
			chosen = rarity
			if pick <= 0 then
				break
			end
		end
	end
	local ids = byRarity[chosen]
	return ids[r:NextInteger(1, #ids)]
end

local function luckFor(player: Player): number
	local untilTime = player:GetAttribute("LuckUntil")
	return if type(untilTime) == "number" and untilTime > os.time() then Config.LuckRune.multiplier else 1
end

local function rollFor(point: SpawnPoint, player: Player): string
	if point.area == "Isle" then
		return RelicSpawnService.rollWeighted(ISLE.spirits[point.pool or "easy"] or ISLE.spirits.easy)
	end
	return RelicSpawnService.roll(point.area, nil, luckFor(player))
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- A new spirit at its home, or on the far side of the leash when its player is standing there.
local function newSpirit(player: Player, point: SpawnPoint, relicId: string, starter: boolean): Spirit
	local home = point.position + Vector3.new(0, HOVER, 0)
	local pos = home
	local root = rootOf(player)
	if root and not starter and (flat(root.Position) - flat(home)).Magnitude < SPIRITS.alertRange then
		local away = flat(home - root.Position)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
		pos = home + away * SPIRITS.leash * 0.9
	end
	return {
		relicId = relicId,
		pos = pos,
		stamina = SPIRITS.staminaByRank[RelicVisuals.rarityRank(RelicDefs.byId[relicId].rarity)],
		tiredUntil = 0,
		dodge = if rng:NextNumber() < 0.5 then -1 else 1,
		dodgeAt = 0,
		state = "idle",
		phase = rng:NextNumber() * math.pi * 2,
		starter = starter,
		trickAt = 0,
		dashUntil = 0,
	}
end

local function entry(point: SpawnPoint, spirit: Spirit)
	return { id = point.id, relicId = spirit.relicId, position = spirit.pos, home = point.position }
end

function RelicSpawnService.list(player: Player): { any }
	local state = states[player]
	local result = {}
	if state then
		for id, spirit in state.active do
			table.insert(result, entry(points[id], spirit))
		end
	end
	return result
end

function RelicSpawnService.startPlayer(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local state: PlayerSpawns = { active = {}, cooldown = {}, isle = false }
	for id, point in points do
		if point.area == "Isle" then
			continue
		elseif point.starter and data.stats.collected == 0 then
			state.active[id] = newSpirit(player, point, Config.StarterRelic, true)
		else
			state.active[id] = newSpirit(player, point, rollFor(point, player), false)
		end
	end
	states[player] = state
end

-- The Treasure Isle's spirits appear for the player while visiting and vanish afterwards.
function RelicSpawnService.startIsle(player: Player)
	local state = states[player]
	if not state or state.isle then
		return
	end
	state.isle = true
	local spawnAdded = Net.event("SpawnAdded")
	for id, point in points do
		if point.area == "Isle" then
			local spirit = newSpirit(player, point, rollFor(point, player), false)
			state.active[id] = spirit
			spawnAdded:FireClient(player, entry(point, spirit))
		end
	end
end

function RelicSpawnService.stopIsle(player: Player)
	local state = states[player]
	if not state or not state.isle then
		return
	end
	state.isle = false
	local removed = {}
	for id, point in points do
		if point.area == "Isle" then
			if state.active[id] then
				table.insert(removed, id)
			end
			state.active[id] = nil
			state.cooldown[id] = nil
		end
	end
	if #removed > 0 and player.Parent then
		Net.event("SpawnRemoved"):FireClient(player, removed)
	end
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
	for id, spirit in state.active do
		if not spirit.starter and points[id].area ~= "Isle" then
			spirit.relicId = rollFor(points[id], player)
			spawnAdded:FireClient(player, entry(points[id], spirit))
		end
	end
end

-- Puts a relic into the player's inventory and reports it like any find (quests, collection
-- book, analytics). Used by caught spirits and by expedition rewards. Returns whether it was new.
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

-- Studio DevTools: the player's spirits as plain data.
function RelicSpawnService.debug(player: Player): { any }
	local result = {}
	local state = states[player]
	for id, spirit in (if state then state.active else {}) do
		table.insert(result, { id = id, relic = spirit.relicId, pos = spirit.pos, state = spirit.state, stamina = spirit.stamina, tired = spirit.tiredUntil - os.clock() })
	end
	return result
end

-- Relic ids an area can produce, grouped by rarity (read-only).
function RelicSpawnService.pool(area: string): { [string]: { string } }
	return poolsByArea[area] or {}
end

local function catch(player: Player, state: PlayerSpawns, id: string, spirit: Spirit)
	local point = points[id]
	state.active[id] = nil
	state.cooldown[id] = os.clock() + point.respawn
	local isNew = RelicSpawnService.grant(player, spirit.relicId, point.area)
	Progress.bump(player, "spirit", 1, point.area)
	Net.event("Caught"):FireClient(player, id, spirit.relicId, isNew, spirit.pos)
end

-- One simulation step for one spirit; returns true when the player touched it.
local function move(spirit: Spirit, point: SpawnPoint, rootPos: Vector3?, now: number, dt: number): boolean
	local home = point.position + Vector3.new(0, HOVER, 0)
	local rank = RelicVisuals.rarityRank(RelicDefs.byId[spirit.relicId].rarity)
	local speed = if spirit.starter then SPIRITS.starterSpeed else SPIRITS.speedByRank[rank]
	local distance = if rootPos then (flat(rootPos) - flat(spirit.pos)).Magnitude else math.huge
	if rootPos and distance < SPIRITS.catchRange and math.abs(rootPos.Y - spirit.pos.Y) < 7 then
		return true
	end

	local goal: Vector3
	if now < spirit.tiredUntil then
		spirit.state = "tired"
		speed *= SPIRITS.tiredSpeed
		local away = flat(spirit.pos - (rootPos or home))
		goal = spirit.pos + (if away.Magnitude > 0.1 then away.Unit * speed * dt else Vector3.zero)
	elseif rootPos and distance < SPIRITS.alertRange then
		spirit.state = "flee"
		spirit.stamina -= dt
		if spirit.stamina <= 0 then
			spirit.tiredUntil = now + SPIRITS.tiredSeconds
			spirit.stamina = SPIRITS.staminaByRank[rank]
		end
		local away = flat(spirit.pos - rootPos)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
		-- Rarer spirits sidestep when the player gets close.
		if distance < 8 and now > spirit.dodgeAt then
			spirit.dodgeAt = now + 0.7
			if rng:NextNumber() < 0.5 then
				spirit.dodge = -spirit.dodge
			end
		end
		local side = Vector3.new(-away.Z, 0, away.X) * spirit.dodge * (if distance < 8 then (rank - 1) * 0.3 else 0)
		-- Isle tricks: a short sprint, or a hop a few studs away. Both have a cooldown and stop
		-- while the spirit is tired, so every spirit stays catchable.
		if point.trick == "dash" and distance < 10 and now > spirit.trickAt then
			spirit.trickAt = now + ISLE.trickCooldown
			spirit.dashUntil = now + ISLE.dashSeconds
		end
		if now < spirit.dashUntil then
			speed *= ISLE.dashSpeed
		end
		if point.trick == "blink" and distance < ISLE.blinkRange and now > spirit.trickAt then
			spirit.trickAt = now + ISLE.trickCooldown
			goal = spirit.pos + (away + side * 2).Unit * ISLE.blinkDistance
		else
			goal = spirit.pos + (away + side).Unit * speed * dt
		end
	else
		spirit.state = "idle"
		spirit.stamina = math.min(SPIRITS.staminaByRank[rank], spirit.stamina + dt * 0.5)
		spirit.phase += dt * 0.6
		local wander = home + Vector3.new(math.cos(spirit.phase), 0, math.sin(spirit.phase)) * 4
		local toward = flat(wander - spirit.pos)
		goal = spirit.pos + (if toward.Magnitude > 0.2 then toward.Unit * math.min(toward.Magnitude, 3 * dt) else Vector3.zero)
	end
	-- Stay on the leash: slide along its edge instead of leaving it.
	local offset = flat(goal - home)
	if offset.Magnitude > SPIRITS.leash then
		goal = home + offset.Unit * SPIRITS.leash
	end
	spirit.pos = Vector3.new(goal.X, home.Y + math.sin(now * 2 + spirit.phase) * 0.4, goal.Z)
	return false
end

local function step(dt: number)
	local now = os.clock()
	local spawnAdded = Net.event("SpawnAdded")
	local positions = Net.event("Spirits")
	for player, state in states do
		local root = rootOf(player)
		local rootPos = root and root.Position
		local batch = {}
		for id, spirit in state.active do
			local point = points[id]
			if move(spirit, point, rootPos, now, dt) then
				catch(player, state, id, spirit)
			elseif rootPos and (flat(rootPos) - flat(spirit.pos)).Magnitude < 120 then
				batch[id] = { spirit.pos, spirit.state }
			end
		end
		for id, readyAt in state.cooldown do
			if now >= readyAt and (state.isle or points[id].area ~= "Isle") then
				state.cooldown[id] = nil
				local spirit = newSpirit(player, points[id], rollFor(points[id], player), false)
				state.active[id] = spirit
				spawnAdded:FireClient(player, entry(points[id], spirit))
			end
		end
		if next(batch) then
			positions:FireClient(player, batch)
		end
	end
end

function RelicSpawnService.init()
	buildPools()
	local folders = { Workspace:WaitForChild("Aetheria"):WaitForChild("RelicSpawns") }
	local isle = Workspace:FindFirstChild("TreasureIsle")
	local isleSpawns = isle and isle:FindFirstChild("IsleSpawns")
	if isleSpawns then
		table.insert(folders, isleSpawns)
	end
	for _, folder in folders do
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") then
				local id = part:GetAttribute("SpawnId") :: string? or part.Name
				local trick = part:GetAttribute("Trick") :: string?
				points[id] = {
					id = id,
					position = part.Position,
					area = part:GetAttribute("Area") :: string? or "Plaza",
					starter = part:GetAttribute("Starter") == true,
					respawn = part:GetAttribute("RespawnSeconds") :: number? or Config.DefaultRespawnSeconds,
					pool = part:GetAttribute("Pool") :: string?,
					trick = if trick and trick ~= "" then trick else nil,
				}
			end
		end
	end

	Net.func("GetSpawns").OnServerInvoke = function(player: Player)
		local deadline = os.clock() + 30
		while not states[player] and player.Parent and os.clock() < deadline do
			task.wait(0.2)
		end
		return RelicSpawnService.list(player)
	end

	task.spawn(function()
		while true do
			local dt = task.wait(TICK)
			step(math.min(dt, 0.5))
		end
	end)
end

return RelicSpawnService
