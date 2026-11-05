--!strict
-- The treasury tycoon: everything a player can build on their plot, bought by stepping on the
-- glowing build pad that sits exactly where the build will appear. Data-driven like RelicDefs;
-- the server (TycoonService) charges and records, PlotService shows pads and results, and
-- both client and server read the helpers below.
--   pad       where its pad stands: plan units in the plot's local frame, Y = the floor top it
--             stands on (see Builds.toPlot); pedestal pads stand right beside their pedestal
--   pedestal  unlocks that display slot      boost  adds to the coin multiplier
--   tier      the treasury reaches this tier (names in Config.Tiers)
--   requires  ids that must be built first (the pad appears afterwards)

export type Build = {
	id: string,
	name: string,
	cost: number,
	requires: { string },
	pad: Vector3,
	pedestal: number?,
	boost: number?,
	tier: number?,
}

-- The house is laid out in plan units (pads here, Server/Util/Blueprints) and built SCALE times
-- larger around the yard's floor top, so rooms are roomy enough for the camera.
local SCALE = 1.3
local GROUND = 0.6 -- floor top of the yard and the ground floor
local CELLAR = -9.4 -- floor top of the cellar and the vault
local V = Vector3.new

local list: { Build } = {
	-- The relic hall (always there) and its cellar: every relic stands in these rooms.
	{ id = "lanterns", name = "Laternen", cost = 150, requires = {}, pad = V(-7.6, GROUND, 28), boost = 0.05 },
	{ id = "garden", name = "Vorgarten", cost = 200, requires = {}, pad = V(-13, GROUND, -9), boost = 0.05 },
	{ id = "cellar", name = "Schatzkeller", cost = 350, requires = {}, pad = V(0, GROUND, 40.4) },
	{ id = "ped5", name = "Podest 5", cost = 150, requires = { "cellar" }, pad = V(-11.2, CELLAR, 30), pedestal = 5 },
	{ id = "ped6", name = "Podest 6", cost = 220, requires = { "ped5" }, pad = V(-1.2, CELLAR, 30), pedestal = 6 },
	{ id = "ped7", name = "Podest 7", cost = 320, requires = { "ped6" }, pad = V(8.8, CELLAR, 30), pedestal = 7 },
	{ id = "ped8", name = "Podest 8", cost = 450, requires = { "ped7" }, pad = V(11.2, CELLAR, 30), pedestal = 8 },
	-- The house above ground, room by room
	{ id = "hall", name = "Eingangshalle", cost = 900, requires = { "ped6" }, pad = V(0, GROUND, 15), tier = 2 },
	{ id = "carpet", name = "Goldteppich", cost = 400, requires = { "hall" }, pad = V(0, GROUND, 7), boost = 0.05 },
	{ id = "ped9", name = "Podest 9", cost = 600, requires = { "ped8", "hall" }, pad = V(-11.2, CELLAR, 37), pedestal = 9 },
	{ id = "ped10", name = "Podest 10", cost = 800, requires = { "ped9" }, pad = V(-1.2, CELLAR, 37), pedestal = 10 },
	{ id = "living", name = "Wohnzimmer", cost = 1200, requires = { "hall" }, pad = V(-14, GROUND, 15) },
	{ id = "fireplace", name = "Kamin", cost = 900, requires = { "living" }, pad = V(-16.5, GROUND, 15), boost = 0.05 },
	{ id = "lounge", name = "Sofaecke", cost = 1100, requires = { "living" }, pad = V(-12, GROUND, 21), boost = 0.05 },
	{ id = "library", name = "Bibliothek", cost = 1500, requires = { "hall" }, pad = V(14, GROUND, 15) },
	{ id = "shelves", name = "Bücherregale", cost = 1400, requires = { "library" }, pad = V(16.5, GROUND, 15), boost = 0.1 },
	{ id = "desk", name = "Lesepult und Globus", cost = 1600, requires = { "library" }, pad = V(12, GROUND, 21), boost = 0.05 },
	{ id = "ped11", name = "Podest 11", cost = 1000, requires = { "ped10" }, pad = V(8.8, CELLAR, 37), pedestal = 11 },
	{ id = "ped12", name = "Podest 12", cost = 1300, requires = { "ped11" }, pad = V(11.2, CELLAR, 37), pedestal = 12 },
	{ id = "pond", name = "Teich mit Brunnen", cost = 2000, requires = { "garden", "hall" }, pad = V(13, GROUND, -9), boost = 0.1 },
	{ id = "statues", name = "Wächterstatuen", cost = 2400, requires = { "hall" }, pad = V(3.6, GROUND, 19.5), boost = 0.05 },
	{ id = "chandelier", name = "Kristalllüster", cost = 2500, requires = { "hall" }, pad = V(0, GROUND, 15), boost = 0.1 },
	{ id = "maproom", name = "Kartenraum", cost = 3000, requires = { "living" }, pad = V(-15, GROUND, 36) },
	{ id = "maptable", name = "Kartentisch", cost = 2000, requires = { "maproom" }, pad = V(-15, GROUND, 31), boost = 0.05 },
	{ id = "trophy", name = "Trophäenzimmer", cost = 3500, requires = { "library" }, pad = V(15, GROUND, 36) },
	{ id = "trophies", name = "Trophäenvitrinen", cost = 3200, requires = { "trophy" }, pad = V(15, GROUND, 31), boost = 0.15 },
	-- Below the hall: the vault with the last eight pedestals
	{ id = "vault", name = "Schatzgewölbe", cost = 6000, requires = { "ped12" }, pad = V(0, CELLAR, 28.6), tier = 3 },
	{ id = "ped13", name = "Podest 13", cost = 4000, requires = { "vault" }, pad = V(-11.2, CELLAR, 19), pedestal = 13 },
	{ id = "ped14", name = "Podest 14", cost = 5000, requires = { "ped13" }, pad = V(-1.2, CELLAR, 19), pedestal = 14 },
	{ id = "ped15", name = "Podest 15", cost = 6500, requires = { "ped14" }, pad = V(8.8, CELLAR, 19), pedestal = 15 },
	{ id = "ped16", name = "Podest 16", cost = 8000, requires = { "ped15" }, pad = V(11.2, CELLAR, 19), pedestal = 16 },
	{ id = "grotto", name = "Kristallgrotte", cost = 9000, requires = { "vault" }, pad = V(-17, CELLAR, 43), boost = 0.1 },
	{ id = "towers", name = "Ecktürme", cost = 8000, requires = { "maproom", "trophy" }, pad = V(-23.5, 0, 44), boost = 0.05 },
	{ id = "ped17", name = "Podest 17", cost = 10000, requires = { "ped16" }, pad = V(-11.2, CELLAR, 11), pedestal = 17 },
	{ id = "ped18", name = "Podest 18", cost = 12500, requires = { "ped17" }, pad = V(-1.2, CELLAR, 11), pedestal = 18 },
	{ id = "ped19", name = "Podest 19", cost = 15000, requires = { "ped18" }, pad = V(8.8, CELLAR, 11), pedestal = 19 },
	{ id = "ped20", name = "Podest 20", cost = 18000, requires = { "ped19" }, pad = V(11.2, CELLAR, 11), pedestal = 20 },
	{ id = "goldpile", name = "Goldhaufen", cost = 20000, requires = { "ped18" }, pad = V(-16, CELLAR, 6.5), boost = 0.1 },
	{ id = "crown", name = "Schatzkrone", cost = 30000, requires = { "goldpile", "towers" }, pad = V(0, GROUND, -5), boost = 0.25 },
}

local byId: { [string]: Build } = {}
local bySlot: { [number]: Build } = {}
for _, build in list do
	assert(byId[build.id] == nil, "duplicate build id " .. build.id)
	byId[build.id] = build
	if build.pedestal then
		bySlot[build.pedestal] = build
	end
end

local Builds = {}
Builds.list = list
Builds.byId = byId
Builds.FreePedestals = 4 -- slots every new treasury starts with
Builds.MaxPedestals = 20
Builds.CellarFloor = CELLAR
Builds.Scale = SCALE

-- Plot-local position of a point given in plan units.
function Builds.toPlot(p: Vector3): Vector3
	return Vector3.new(p.X * SCALE, GROUND + (p.Y - GROUND) * SCALE, p.Z * SCALE)
end

function Builds.slotUnlocked(owned: { [string]: boolean }, slot: number): boolean
	if slot <= Builds.FreePedestals then
		return true
	end
	local build = bySlot[slot]
	return build ~= nil and owned[build.id] == true
end

function Builds.unlockedSlots(owned: { [string]: boolean }): number
	local n = 0
	for slot = 1, Builds.MaxPedestals do
		if Builds.slotUnlocked(owned, slot) then
			n += 1
		end
	end
	return n
end

function Builds.multiplier(owned: { [string]: boolean }): number
	local m = 1
	for id in owned do
		local build = byId[id]
		if build and build.boost then
			m += build.boost
		end
	end
	return m
end

function Builds.canBuild(owned: { [string]: boolean }, build: Build): boolean
	if owned[build.id] then
		return false
	end
	for _, required in build.requires do
		if not owned[required] then
			return false
		end
	end
	return true
end

-- Builds whose requirements are met, cheapest first (the pads that are showing).
function Builds.available(owned: { [string]: boolean }): { Build }
	local result = {}
	for _, build in list do
		if Builds.canBuild(owned, build) then
			table.insert(result, build)
		end
	end
	table.sort(result, function(a, b)
		return a.cost < b.cost
	end)
	return result
end

-- The treasury tier follows the hall and the vault (Config.Tiers holds the names).
function Builds.tier(owned: { [string]: boolean }): number
	local tier = 1
	for _, build in list do
		if build.tier and owned[build.id] then
			tier = math.max(tier, build.tier)
		end
	end
	return tier
end

function Builds.count(owned: { [string]: boolean }): number
	local n = 0
	for id in owned do
		if byId[id] then
			n += 1
		end
	end
	return n
end

return Builds
