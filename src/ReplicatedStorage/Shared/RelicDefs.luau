--!strict
-- Data-driven relic catalogue. Adding a relic means adding a row here; no system code changes.
--   rate    coins per second while the relic stands on a pedestal
--   shape   procedural model used by RelicVisuals (see BUILDERS there)
--   sources areas whose spawn points may roll this relic (Plaza, Forest, Ruins, Expedition)

export type RelicDef = {
	id: string,
	name: string,
	rarity: string,
	rate: number,
	shape: string,
	color: Color3,
	sources: { string },
}

local C = Color3.fromRGB

local list: { RelicDef } = {
	-- Common
	{ id = "moonstone", name = "Mondstein", rarity = "Common", rate = 1, shape = "orb", color = C(200, 210, 255), sources = { "Plaza", "Forest" } },
	{ id = "forest_lantern", name = "Waldlaterne", rarity = "Common", rate = 1.2, shape = "lantern", color = C(150, 230, 120), sources = { "Forest" } },
	{ id = "rune_shard", name = "Runensplitter", rarity = "Common", rate = 1.1, shape = "shard", color = C(170, 140, 255), sources = { "Plaza", "Forest" } },
	{ id = "sun_pebble", name = "Sonnenkiesel", rarity = "Common", rate = 1, shape = "orb", color = C(255, 200, 90), sources = { "Plaza" } },
	{ id = "moss_amulet", name = "Moosamulett", rarity = "Common", rate = 1.3, shape = "amulet", color = C(110, 190, 100), sources = { "Forest" } },
	{ id = "stardust", name = "Sternenstaub", rarity = "Common", rate = 1.2, shape = "gem", color = C(230, 230, 255), sources = { "Plaza", "Forest" } },
	{ id = "crystal_bloom", name = "Kristallblüte", rarity = "Common", rate = 1.4, shape = "bloom", color = C(120, 230, 240), sources = { "Forest" } },
	{ id = "glow_shell", name = "Leuchtmuschel", rarity = "Common", rate = 1.5, shape = "shell", color = C(255, 170, 200), sources = { "Plaza" } },
	-- Uncommon
	{ id = "fairy_wing", name = "Feenflügel", rarity = "Uncommon", rate = 3, shape = "feather", color = C(220, 170, 255), sources = { "Forest" } },
	{ id = "rune_compass", name = "Runenkompass", rarity = "Uncommon", rate = 3.2, shape = "amulet", color = C(230, 190, 90), sources = { "Plaza", "Forest" } },
	{ id = "mist_orb", name = "Nebelkugel", rarity = "Uncommon", rate = 3.4, shape = "orb", color = C(180, 200, 230), sources = { "Forest" } },
	{ id = "wind_feather", name = "Windfeder", rarity = "Uncommon", rate = 3, shape = "feather", color = C(170, 240, 230), sources = { "Plaza" } },
	{ id = "silver_chalice", name = "Silberkelch", rarity = "Uncommon", rate = 3.6, shape = "chalice", color = C(210, 215, 225), sources = { "Plaza", "Forest" } },
	{ id = "dream_crystal", name = "Traumkristall", rarity = "Uncommon", rate = 3.8, shape = "gem", color = C(150, 120, 255), sources = { "Forest" } },
	{ id = "moon_lantern", name = "Mondlaterne", rarity = "Uncommon", rate = 4, shape = "lantern", color = C(170, 190, 255), sources = { "Forest" } },
	-- Rare
	{ id = "frost_crown", name = "Frostkrone", rarity = "Rare", rate = 8, shape = "crown", color = C(150, 220, 255), sources = { "Forest" } },
	{ id = "star_feather", name = "Sternenfeder", rarity = "Rare", rate = 8.5, shape = "feather", color = C(255, 240, 150), sources = { "Forest" } },
	{ id = "aether_cube", name = "Aetherwürfel", rarity = "Rare", rate = 9, shape = "cube", color = C(170, 90, 255), sources = { "Forest" } },
	{ id = "shadow_mask", name = "Schattenmaske", rarity = "Rare", rate = 9.5, shape = "mask", color = C(80, 70, 120), sources = { "Ruins" } },
	{ id = "magic_mirror", name = "Zauberspiegel", rarity = "Rare", rate = 10, shape = "mirror", color = C(200, 230, 255), sources = { "Ruins" } },
	-- Epic
	{ id = "dragon_heart", name = "Drachenherz", rarity = "Epic", rate = 22, shape = "gem", color = C(255, 70, 70), sources = { "Expedition" } },
	{ id = "time_mirror", name = "Zeitenspiegel", rarity = "Epic", rate = 24, shape = "mirror", color = C(255, 210, 120), sources = { "Expedition" } },
	{ id = "sky_globe", name = "Himmelsglobus", rarity = "Epic", rate = 26, shape = "globe", color = C(90, 170, 255), sources = { "Expedition" } },
	-- Legendary
	{ id = "phoenix_egg", name = "Phönix-Ei", rarity = "Legendary", rate = 60, shape = "egg", color = C(255, 120, 40), sources = { "Expedition" } },
	{ id = "aether_crown", name = "Aetherkrone", rarity = "Legendary", rate = 70, shape = "crown", color = C(200, 120, 255), sources = { "Expedition" } },
}

local byId: { [string]: RelicDef } = {}
for _, def in list do
	assert(byId[def.id] == nil, "duplicate relic id " .. def.id)
	byId[def.id] = def
end

return {
	list = list,
	byId = byId,
}
