--!strict
-- Treasure maps: caught spirits sometimes drop a map piece. Once enough pieces are together,
-- the map points to one hidden spot (Config.Maps.spots); digging there yields a treasure with
-- a rarer relic and coins. The spot is personal; the client draws the dig mound, the server
-- checks map, spot and distance before paying.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local Progress = require(script.Parent.Parent.Util.Progress)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local RelicSpawnService = require(script.Parent.RelicSpawnService)

local MAPS = Config.Maps

local MapService = {}

local rng = Random.new()
local digLimiter = RateLimiter.new(3, 0.5)

local function notify(player: Player, message: { [string]: any })
	Net.event("Notify"):FireClient(player, message)
end

-- Adds one piece; completing the map picks a random spot. Returns the number of pieces now
-- held, or the open spot's index when the map is complete.
function MapService.addPiece(player: Player): number?
	local data = PlayerDataService.get(player)
	if not data or data.maps.spot ~= 0 then
		return nil -- an open map has to be dug up first
	end
	data.maps.pieces += 1
	if data.maps.pieces >= MAPS.piecesNeeded then
		data.maps.pieces = 0
		data.maps.spot = rng:NextInteger(1, #MAPS.spots)
		notify(player, { kind = "map", text = "Die Schatzkarte ist vollständig! Öffne sie unten bei „Karte“." })
		Analytics.custom(player, "MapCompleted")
	else
		notify(player, { kind = "map", text = ("Ein Kartenteil! (%d von %d)"):format(data.maps.pieces, MAPS.piecesNeeded) })
	end
	PlayerDataService.replicate(player)
	return if data.maps.spot ~= 0 then data.maps.spot else data.maps.pieces
end

local function onProgress(player: Player, stat: string)
	if stat ~= "spirit" then
		return
	end
	local data = PlayerDataService.get(player)
	if not data or data.maps.spot ~= 0 or not data.tutorial.done then
		return
	end
	local chance = if data.maps.found == 0 then MAPS.firstMapChance else MAPS.pieceChance
	if rng:NextNumber() < chance then
		MapService.addPiece(player)
	end
end

function MapService.dig(player: Player): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "not_loaded"
	end
	local spot = MAPS.spots[data.maps.spot]
	if not spot then
		return false, "no_map"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local flat = if root then Vector3.new(root.Position.X - spot.position.X, 0, root.Position.Z - spot.position.Z) else nil
	if not flat or flat.Magnitude > MAPS.digRange + Config.RangeTolerance then
		return false, "too_far"
	end
	data.maps.spot = 0
	data.maps.found += 1
	-- A rarer roll from the island's pools; prefer areas evenly.
	local area = if rng:NextNumber() < 0.5 then "Plaza" else "Forest"
	-- A treasure is never a plain common find.
	local relicId = RelicSpawnService.roll(area, rng, MAPS.luck)
	for _ = 1, 20 do
		if RelicDefs.byId[relicId].rarity ~= Config.RarityOrder[1] then
			break
		end
		relicId = RelicSpawnService.roll(area, rng, MAPS.luck)
	end
	local isNew = RelicSpawnService.grant(player, relicId, "Map")
	local coins = MAPS.coinsByTier[data.tier]
	EconomyService.grant(player, coins, "treasure_map")
	Progress.bump(player, "treasure", 1)
	Analytics.custom(player, "TreasureFound")
	notify(player, {
		kind = "reward",
		text = ("Schatz ausgegraben: %s und %d Münzen!"):format(RelicDefs.byId[relicId].name, coins),
		relics = { { id = relicId, new = isNew } },
	})
	return true, nil
end

function MapService.init()
	Progress.on(onProgress)
	Net.func("DigTreasure").OnServerInvoke = function(player: Player)
		if not digLimiter:allow(player) then
			return false, "rate"
		end
		return MapService.dig(player)
	end
end

return MapService
