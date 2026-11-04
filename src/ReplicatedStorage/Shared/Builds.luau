--!strict
-- The treasury tycoon: everything a player can build on their plot, bought by stepping on the
-- glowing build buttons. Data-driven like RelicDefs; the server (TycoonService) charges and
-- records, PlotService shows the result, and both client and server read the helpers below.
--   pedestal  unlocks that display slot      boost  adds to the coin multiplier
--   tier      the treasury reaches this tier (names in Config.Tiers)
--   requires  ids that must be built first (the button appears afterwards)

export type Build = {
	id: string,
	name: string,
	cost: number,
	requires: { string },
	pedestal: number?,
	boost: number?,
	tier: number?,
}

local list: { Build } = {
	-- Stage 1: the small treasury grows
	{ id = "ped5", name = "Podest 5", cost = 120, requires = {}, pedestal = 5 },
	{ id = "lanterns", name = "Laternen", cost = 220, requires = {}, boost = 0.05 },
	{ id = "walls", name = "Steinmauern", cost = 260, requires = {} },
	{ id = "ped6", name = "Podest 6", cost = 200, requires = { "ped5" }, pedestal = 6 },
	{ id = "ped7", name = "Podest 7", cost = 320, requires = { "ped6" }, pedestal = 7 },
	{ id = "carpet", name = "Goldteppich", cost = 380, requires = { "lanterns" }, boost = 0.05 },
	{ id = "ped8", name = "Podest 8", cost = 450, requires = { "ped7" }, pedestal = 8 },
	{ id = "gate", name = "Eingangsportal", cost = 520, requires = { "walls" } },
	{ id = "hall2", name = "Runensaal", cost = 900, requires = { "ped8", "carpet", "gate" }, tier = 2 },
	-- Stage 2: the rune hall gets its roof
	{ id = "ped9", name = "Podest 9", cost = 1100, requires = { "hall2" }, pedestal = 9 },
	{ id = "windows", name = "Buntglasfenster", cost = 1500, requires = { "hall2" }, boost = 0.05 },
	{ id = "fountain", name = "Münzbrunnen", cost = 1800, requires = { "hall2" }, boost = 0.1 },
	{ id = "ped10", name = "Podest 10", cost = 1400, requires = { "ped9" }, pedestal = 10 },
	{ id = "ped11", name = "Podest 11", cost = 2000, requires = { "ped10" }, pedestal = 11 },
	{ id = "statues", name = "Wächterstatuen", cost = 2400, requires = { "fountain" }, boost = 0.05 },
	{ id = "ped12", name = "Podest 12", cost = 2600, requires = { "ped11" }, pedestal = 12 },
	{ id = "towers", name = "Ecktürme", cost = 2800, requires = { "windows" }, boost = 0.05 },
	{ id = "vitrines", name = "Glasvitrinen", cost = 3200, requires = { "statues" }, boost = 0.15 },
	{ id = "hall3", name = "Aetherhalle", cost = 6000, requires = { "ped12", "vitrines", "towers" }, tier = 3 },
	-- Stage 3: the aether hall and its gallery
	{ id = "chandelier", name = "Kristalllüster", cost = 8000, requires = { "hall3" }, boost = 0.1 },
	{ id = "gallery", name = "Galerie", cost = 10000, requires = { "hall3" } },
	{ id = "ped13", name = "Galerie-Podest 13", cost = 12000, requires = { "gallery" }, pedestal = 13 },
	{ id = "ped14", name = "Galerie-Podest 14", cost = 14000, requires = { "ped13" }, pedestal = 14 },
	{ id = "ped15", name = "Galerie-Podest 15", cost = 16000, requires = { "ped14" }, pedestal = 15 },
	{ id = "ped16", name = "Galerie-Podest 16", cost = 18000, requires = { "ped15" }, pedestal = 16 },
	{ id = "crown", name = "Schatzkrone", cost = 30000, requires = { "chandelier", "ped16" }, boost = 0.25 },
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

function Builds.slotUnlocked(owned: { [string]: boolean }, slot: number): boolean
	if slot <= Builds.FreePedestals then
		return true
	end
	local build = bySlot[slot]
	return build ~= nil and owned[build.id] == true
end

function Builds.unlockedSlots(owned: { [string]: boolean }): number
	local n = 0
	for slot = 1, 16 do
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

-- Builds whose requirements are met, cheapest first (what the buttons offer).
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

-- The treasury tier follows the two hall builds (Config.Tiers holds the names).
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
