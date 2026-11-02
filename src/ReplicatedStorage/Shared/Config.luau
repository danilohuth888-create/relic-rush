--!strict
-- Central tuning values. Balancing changes should only ever touch this file and RelicDefs.

local Config = {}

Config.MaxPlots = 8

-- Treasury tiers: pedestal count and coin cost to unlock (tier 1 is free).
Config.Tiers = {
	{ pedestals = 4, cost = 0, name = "Kleine Schatzkammer" },
	{ pedestals = 8, cost = 500, name = "Runensaal" },
	{ pedestals = 12, cost = 5000, name = "Aetherhalle" },
}
Config.MaxPedestals = 12

Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
Config.Rarities = {
	Common = { name = "Gewöhnlich", color = Color3.fromRGB(214, 220, 230), weight = 70 },
	Uncommon = { name = "Ungewöhnlich", color = Color3.fromRGB(110, 230, 150), weight = 22 },
	Rare = { name = "Selten", color = Color3.fromRGB(80, 190, 255), weight = 6.5 },
	Epic = { name = "Episch", color = Color3.fromRGB(190, 100, 255), weight = 1.3 },
	Legendary = { name = "Legendär", color = Color3.fromRGB(255, 190, 60), weight = 0.2 },
}

-- Interaction distances in studs. The server allows RangeTolerance extra for latency.
Config.CollectRange = 12
Config.AutoCollectRange = 4
Config.PedestalRange = 10
Config.RangeTolerance = 8

Config.DefaultRespawnSeconds = 45
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

-- Luck rune: the repeatable coin sink. Doubles the odds of every rarity above Common for
-- relics that spawn while it is active.
Config.LuckRune = {
	seconds = 5 * 60,
	costByTier = { 300, 1500, 6000 },
	multiplier = 2,
}

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
