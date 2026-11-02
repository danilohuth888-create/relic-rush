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
Config.AutosaveSeconds = 120

-- Every new player's first pickup is guaranteed to be this relic.
Config.StarterRelic = "moonstone"

return Config
