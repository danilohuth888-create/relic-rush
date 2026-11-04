--!strict
-- Central tuning values. Balancing changes should only ever touch this file and RelicDefs.

local Config = {}

Config.MaxPlots = 8

-- Treasury tiers, reached through the hall builds in Shared/Builds. Many rewards and prices
-- scale with the tier.
Config.Tiers = {
	{ name = "Kleine Schatzkammer" },
	{ name = "Runensaal" },
	{ name = "Aetherhalle" },
}
Config.MaxPedestals = 20

Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
Config.Rarities = {
	Common = { name = "Gewöhnlich", color = Color3.fromRGB(214, 220, 230), weight = 70 },
	Uncommon = { name = "Ungewöhnlich", color = Color3.fromRGB(110, 230, 150), weight = 22 },
	Rare = { name = "Selten", color = Color3.fromRGB(80, 190, 255), weight = 6.5 },
	Epic = { name = "Episch", color = Color3.fromRGB(190, 100, 255), weight = 1.3 },
	Legendary = { name = "Legendär", color = Color3.fromRGB(255, 190, 60), weight = 0.2 },
}

-- Interaction distances in studs. The server allows RangeTolerance extra for latency.
Config.PedestalRange = 10
Config.RangeTolerance = 8

Config.DefaultRespawnSeconds = 45

-- Guardian spirits carry the relics. Speeds and stamina by rarity rank (Common = 1 ...);
-- players run at 16 studs/s, so every spirit can be caught, rarer ones just take longer.
Config.Spirits = {
	speedByRank = { 6.5, 9, 11, 12.5, 13.5 },
	staminaByRank = { 2.5, 3.5, 4.5, 5.5, 6 }, -- seconds of fleeing before it tires
	tiredSeconds = 3.5,
	tiredSpeed = 0.3,
	starterSpeed = 3.5,
	alertRange = 18,
	catchRange = 4.5,
	leash = 22, -- how far a spirit may stray from its spawn point
}
Config.EconomyTickSeconds = 1
Config.AutosaveSeconds = 60

-- Every new player's first pickup is guaranteed to be this relic.
Config.StarterRelic = "moonstone"

-- Offline earnings: a share of the normal rate, capped, so returning players see progress.
Config.OfflineRate = 0.25
Config.OfflineCapSeconds = 2 * 60 * 60

-- Discovering this many different relics pays a one-time bonus.
Config.Milestones = {
	{ count = 3, reward = 150 },
	{ count = 6, reward = 400 },
	{ count = 10, reward = 1200 },
	{ count = 15, reward = 4000 },
	{ count = 20, reward = 12000 },
	{ count = 25, reward = 40000 },
}

-- Daily quests: perDay picked from the pool each UTC day; goal and reward scale with the tier.
Config.Quests = {
	perDay = 3,
	rewardByTier = { 250, 900, 3000 },
	pool = {
		{ id = "collect", text = "Sammle %d Relikte", stat = "collect", goals = { 6, 10, 15 } },
		{ id = "forest", text = "Sammle %d Relikte im Flüsterwald", stat = "collectForest", goals = { 3, 5, 8 } },
		{ id = "place", text = "Stelle %d Relikte aus", stat = "place", goals = { 2, 4, 6 } },
		{ id = "earn", text = "Verdiene %d Münzen", stat = "earn", goals = { 400, 2500, 10000 } },
		{ id = "uncommon", text = "Finde %d ungewöhnliche oder bessere Relikte", stat = "collectUncommon", goals = { 1, 2, 4 } },
		{ id = "visit", text = "Besuche %d fremde Schatzkammer(n)", stat = "visit", goals = { 1, 2, 3 }, social = true },
	},
}

-- Weekly goal: one bigger goal per week (Monday 00:00 UTC), on top of the daily quests.
-- Reward: coins by tier plus a treasure map piece. Never expires mid-progress within a week.
Config.Weekly = {
	rewardByTier = { 1500, 6000, 20000 },
	pool = {
		{ id = "spirits", text = "Fange %d Wächter-Geister", stat = "spirit", goals = { 40, 70, 100 } },
		{ id = "treasure", text = "Grabe %d Schätze aus", stat = "treasure", goals = { 2, 3, 4 } },
		{ id = "expedition", text = "Schließe %d Expeditionen ab", stat = "expedition", goals = { 1, 2, 3 } },
		{ id = "earn", text = "Verdiene %d Münzen", stat = "earn", goals = { 8000, 40000, 150000 } },
	},
	byId = {} :: { [string]: any },
}
for _, goal in Config.Weekly.pool do
	Config.Weekly.byId[goal.id] = goal
end

-- Luck rune: the repeatable coin sink. Doubles the odds of every rarity above Common for
-- relics that spawn while it is active.
Config.LuckRune = {
	seconds = 5 * 60,
	costByTier = { 300, 1500, 6000 },
	multiplier = 2,
}

-- Treasure maps: caught spirits sometimes drop a map piece; three pieces make a complete map.
-- Each complete map is one visit to the Treasure Isle (Config.Isle).
Config.Maps = {
	piecesNeeded = 3,
	pieceChance = 0.2,
	firstMapChance = 0.45, -- until the first visit, pieces drop more often
	maxCharts = 3, -- complete maps a player can hold; pieces stop dropping at the cap
}

-- The Treasure Isle: a timed visit with treasures and spirits. The more valuable a find, the
-- harder it is to get: easy treasures lie in the open, hidden ones behind rocks and ruins,
-- the secret one in a tricky place; spirits get faster ("dash") or sneakier ("blink").
-- Every visit has a few easy finds, so it never ends empty-handed.
Config.Isle = {
	visitSeconds = 4 * 60,
	digRange = 9,
	finds = {
		-- tier = how many spots a visit hides, rarity weights, coins by treasury tier
		easy = { count = 5, rarity = { Uncommon = 75, Rare = 25 }, coinsByTier = { 120, 450, 1600 } },
		hidden = { count = 3, rarity = { Rare = 70, Epic = 30 }, coinsByTier = { 300, 1100, 4000 } },
		secret = { count = 1, rarity = { Epic = 65, Legendary = 35 }, coinsByTier = { 800, 3000, 10000 } },
	},
	spirits = {
		easy = { Uncommon = 65, Rare = 35 },
		tricky = { Rare = 60, Epic = 40 },
		master = { Epic = 70, Legendary = 30 },
	},
	dashSpeed = 1.7, -- speed multiplier during a dash
	dashSeconds = 0.6,
	blinkDistance = 7, -- studs a blinking spirit jumps away when the player gets close
	blinkRange = 9, -- how close the player must be (catching happens at Config.Spirits.catchRange)
	trickCooldown = 3,
}

-- "Forgotten Ruins" expedition: a 3-5 minute co-op run for 1-4 players. Relic rewards are
-- limited by a per-player cooldown; players on cooldown may still help and earn coins.
Config.Expedition = {
	maxPlayers = 4,
	maxRuns = 3, -- arenas that can run at the same time on one server
	lobbySeconds = 8,
	portalRange = 24,
	maxRunSeconds = 8 * 60,
	rewardSeconds = 40, -- time at the chest before everyone returns
	cooldownSeconds = 10 * 60,
	coinsByTier = { 600, 2500, 9000 },
	helperShare = 0.25,
	legendaryChance = 0.2,
	guardianHits = 5,
	extraHitsPerPlayer = 1,
}

-- Player settings (stored in the profile). Volumes are 0..1 in steps of SettingsStep.
Config.DefaultSettings = { music = 0.6, sfx = 0.8, hints = true }
Config.SettingsStep = 0.1

-- Areas for music and ambience, as horizontal circles (y is ignored). Plots are found by name.
Config.Zones = {
	Forest = { center = Vector3.new(0, 0, 140), radius = 66 },
	Ruins = { center = Vector3.new(140, 0, 118), radius = 34 },
}
Config.PlotZoneRadius = 27

-- Robux catalogue. An id of 0 means "not created yet": the shop shows the item as coming soon
-- and no purchase can be prompted. Prices are set in the Creator Dashboard, not here.
Config.Shop = {
	passes = {
		{ key = "wings", name = "Magische Flügel", text = "Leuchtende Aether-Flügel auf deinem Rücken.", id = 2066634532 },
		{ key = "aura", name = "Sternenaura", text = "Funkelnde Sterne umkreisen deinen Charakter.", id = 2068344480 },
		{ key = "vip", name = "VIP-Paket", text = "Goldenes Namensschild und goldene Akzente in deiner Schatzkammer.", id = 2066952546 },
		{ key = "double_coins", name = "Doppelte Münzen", text = "Deine Relikte erzeugen dauerhaft doppelt so viele Münzen.", id = 2066916613 },
	},
	products = {
		{ key = "coins_small", name = "Münzbeutel", text = "Münzen passend zu deiner Ausbaustufe.", coinsByTier = { 500, 3000, 12000 }, id = 3727480713 },
		{ key = "coins_large", name = "Münzschatz", text = "Ein großer Haufen Münzen.", coinsByTier = { 2500, 15000, 60000 }, id = 3727481266 },
	},
}

return Config
