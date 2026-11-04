--!strict
-- Treasure maps and the Treasure Isle. Caught spirits sometimes drop a map piece; three pieces
-- make a complete map, and each complete map is one timed visit to the Treasure Isle
-- (Workspace.TreasureIsle, built by tools/world/BuildTreasureIsle.luau). A visit hides a few
-- treasures for this player only: easy ones in the open, hidden ones behind things, one secret
-- one in a tricky place. The client draws the mounds; the server picks the spots, checks
-- distance and pays. Isle spirits run in RelicSpawnService while the player is there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local Progress = require(script.Parent.Parent.Util.Progress)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local RelicSpawnService = require(script.Parent.RelicSpawnService)

local MAPS = Config.Maps
local ISLE = Config.Isle
local TIERS = { "easy", "hidden", "secret" }
local LEASH = 260 -- leaving the isle this far (by teleport) ends the visit

type Spot = { id: string, tier: string, position: Vector3, dug: boolean }
type Visit = { endsAt: number, spots: { [string]: Spot }, found: number, total: number }

local MapService = {}

local rng = Random.new()
local digLimiter = RateLimiter.new(3, 0.5)
local travelLimiter = RateLimiter.new(2, 2)
local visits: { [Player]: Visit } = {}
local isle: Model? = nil
local spotParts: { [string]: { BasePart } } = {} -- tier -> spot parts

local function notify(player: Player, message: { [string]: any })
	Net.event("Notify"):FireClient(player, message)
end

local function text(player: Player, source: string, ...: any): string
	return Locale.format(Locale.of(player), source, ...)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Adds one piece; three make a complete map (up to MAPS.maxCharts). Returns pieces now held,
-- or nil at the cap.
function MapService.addPiece(player: Player): number?
	local data = PlayerDataService.get(player)
	if not data or data.maps.charts >= MAPS.maxCharts then
		return nil
	end
	data.maps.pieces += 1
	if data.maps.pieces >= MAPS.piecesNeeded then
		data.maps.pieces = 0
		data.maps.charts += 1
		notify(player, { kind = "map", text = text(player, "Eine Schatzkarte ist vollständig! Öffne „Karte“ und reise zur Schatzinsel.") })
		Analytics.custom(player, "MapCompleted")
	else
		notify(player, { kind = "map", text = text(player, "Ein Kartenteil! (%d von %d)", data.maps.pieces, MAPS.piecesNeeded) })
	end
	PlayerDataService.replicate(player)
	return data.maps.pieces
end

local function onProgress(player: Player, stat: string)
	if stat ~= "spirit" then
		return
	end
	local data = PlayerDataService.get(player)
	if not data or data.maps.charts >= MAPS.maxCharts or not data.tutorial.done then
		return
	end
	local chance = if data.maps.visits == 0 then MAPS.firstMapChance else MAPS.pieceChance
	if rng:NextNumber() < chance then
		MapService.addPiece(player)
	end
end

-- The bar at the top (shared with the expedition): what is left to find and the time.
local function setObjective(player: Player, visit: Visit)
	if visit.found >= visit.total then
		player:SetAttribute("ExpObjective", text(player, "Schatzinsel: alle %d Schätze gefunden! Jage noch Geister oder kehr zurück.", visit.total))
	else
		player:SetAttribute("ExpObjective", text(player, "Schatzinsel: %d von %d Schätzen gefunden", visit.found, visit.total))
	end
end

local function pickSpots(): { [string]: Spot }
	local result = {}
	for _, tier in TIERS do
		local pool = table.clone(spotParts[tier] or {})
		for _ = 1, math.min(ISLE.finds[tier].count, #pool) do
			local part = table.remove(pool, rng:NextInteger(1, #pool)) :: BasePart
			result[part.Name] = { id = part.Name, tier = tier, position = part.Position, dug = false }
		end
	end
	return result
end

local function sendSpots(player: Player, visit: Visit?)
	if not player.Parent then
		return
	end
	if not visit then
		Net.event("Isle"):FireClient(player, nil)
		return
	end
	local list = {}
	for _, spot in visit.spots do
		if not spot.dug then
			table.insert(list, { id = spot.id, tier = spot.tier, position = spot.position })
		end
	end
	Net.event("Isle"):FireClient(player, { spots = list, endsAt = visit.endsAt })
end

-- Ends a visit; sendHome brings the player back to their treasury.
function MapService.endVisit(player: Player, sendHome: boolean)
	local visit = visits[player]
	if not visit then
		return
	end
	visits[player] = nil
	RelicSpawnService.stopIsle(player)
	for _, name in { "ExpRun", "ExpObjective", "ExpEnds", "MusicArea" } do
		player:SetAttribute(name, nil)
	end
	sendSpots(player, nil)
	if sendHome and player.Parent then
		PlotService.teleportHome(player)
		notify(player, { kind = "reward", text = text(player, "Zurück von der Schatzinsel: %d von %d Schätzen gefunden.", visit.found, visit.total) })
	end
end

function MapService.travel(player: Player): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "not_loaded"
	end
	if not isle then
		return false, "closed"
	end
	if visits[player] or player:GetAttribute("ExpRun") ~= nil then
		return false, "busy"
	end
	if data.maps.charts <= 0 then
		return false, "no_map"
	end
	local root = rootOf(player)
	local arrival = isle:FindFirstChild("Arrival") :: BasePart?
	if not root or not arrival then
		return false, "no_character"
	end
	data.maps.charts -= 1
	data.maps.visits += 1
	local visit: Visit = { endsAt = os.time() + ISLE.visitSeconds, spots = pickSpots(), found = 0, total = 0 }
	for _ in visit.spots do
		visit.total += 1
	end
	visits[player] = visit
	player:SetAttribute("ExpRun", "isle")
	player:SetAttribute("ExpEnds", visit.endsAt)
	player:SetAttribute("MusicArea", "Forest")
	setObjective(player, visit)
	pcall(function()
		player:RequestStreamAroundAsync(arrival.Position, 5)
	end)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.lookAt(arrival.Position + Vector3.new(0, 4, 0), arrival.Position + Vector3.new(0, 4, -10)))
	end
	RelicSpawnService.startIsle(player)
	sendSpots(player, visit)
	notify(player, { kind = "map", text = text(player, "Willkommen auf der Schatzinsel! Je wertvoller ein Schatz, desto besser ist er versteckt.") })
	Analytics.custom(player, "IsleVisit")
	PlayerDataService.replicate(player)
	return true, nil
end

function MapService.dig(player: Player, spotId: any): (boolean, string?)
	local visit = visits[player]
	if not visit then
		return false, "no_map"
	end
	if type(spotId) ~= "string" or #spotId > 20 then
		return false, "bad_spot"
	end
	local spot = visit.spots[spotId]
	if not spot or spot.dug then
		return false, "bad_spot"
	end
	local data = PlayerDataService.get(player)
	local root = rootOf(player)
	if not data or not root then
		return false, "not_loaded"
	end
	if (root.Position - spot.position).Magnitude > ISLE.digRange + Config.RangeTolerance + 3 then
		return false, "too_far"
	end
	spot.dug = true
	visit.found += 1
	data.maps.found += 1
	local find = ISLE.finds[spot.tier]
	local relicId = RelicSpawnService.rollWeighted(find.rarity, rng)
	local isNew = RelicSpawnService.grant(player, relicId, "Isle")
	local coins = find.coinsByTier[data.tier]
	EconomyService.grant(player, coins, "treasure_isle")
	Progress.bump(player, "treasure", 1)
	Analytics.custom(player, "TreasureFound")
	notify(player, {
		kind = "reward",
		text = text(player, "Schatz ausgegraben: %s und %d Münzen!", Locale.text(Locale.of(player), RelicDefs.byId[relicId].name), coins),
		relics = { { id = relicId, new = isNew } },
	})
	setObjective(player, visit)
	return true, nil
end

-- Studio DevTools: the open visit's spots as plain data.
function MapService.debug(player: Player): { any }?
	local visit = visits[player]
	if not visit then
		return nil
	end
	local list = {}
	for _, spot in visit.spots do
		table.insert(list, { id = spot.id, tier = spot.tier, position = spot.position, dug = spot.dug })
	end
	return list
end

function MapService.stopPlayer(player: Player)
	MapService.endVisit(player, false)
end

function MapService.init()
	isle = Workspace:FindFirstChild("TreasureIsle") :: Model?
	local spots = isle and isle:FindFirstChild("DigSpots")
	for _, part in (if spots then spots:GetChildren() else {}) do
		local tier = part:GetAttribute("Tier")
		if part:IsA("BasePart") and type(tier) == "string" then
			spotParts[tier] = spotParts[tier] or {}
			table.insert(spotParts[tier], part)
		end
	end
	if not isle then
		warn("[Maps] Workspace.TreasureIsle is missing - run tools/world/BuildTreasureIsle.luau")
	end
	local arrival = isle and isle:FindFirstChild("Arrival") :: BasePart?
	local arrivalPos = arrival and arrival.Position

	-- The portal arch on the isle takes the player home.
	local portal = isle and isle:FindFirstChild("ReturnPortal") :: BasePart?
	if portal then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Zurück nach Aetheria"
		prompt.ObjectText = "Portal"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("LAction", "Zurück nach Aetheria")
		prompt.Parent = portal
		prompt.Triggered:Connect(function(player)
			MapService.endVisit(player, true)
		end)
	end

	Progress.on(onProgress)
	Net.func("DigTreasure").OnServerInvoke = function(player: Player, spotId: any)
		if not digLimiter:allow(player) then
			return false, "rate"
		end
		return MapService.dig(player, spotId)
	end
	Net.func("TravelIsle").OnServerInvoke = function(player: Player)
		if not travelLimiter:allow(player) then
			return false, "rate"
		end
		return MapService.travel(player)
	end
	Net.func("LeaveIsle").OnServerInvoke = function(player: Player)
		if not travelLimiter:allow(player) then
			return false, "rate"
		end
		MapService.endVisit(player, true)
		return true
	end

	-- Visits end when the time is up, or quietly when the player left the isle another way.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for player, visit in visits do
				local root = rootOf(player)
				if not player.Parent then
					visits[player] = nil
				elseif now >= visit.endsAt then
					MapService.endVisit(player, true)
				elseif arrivalPos and root and (root.Position - arrivalPos).Magnitude > LEASH then
					MapService.endVisit(player, false)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		visits[player] = nil
	end)
end

return MapService
