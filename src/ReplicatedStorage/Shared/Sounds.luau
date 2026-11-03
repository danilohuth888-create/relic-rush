--!strict
-- Every audio asset the game plays, in one place. All of them come from the licensed catalogue
-- Roblox provides for experiences (APM Music and Pro Sound Effects), see docs/CREDITS.md.
-- Swapping a sound means changing an id here; volumes are the mix before the player's sliders.

export type Sound = { id: number, volume: number, credit: string }

local Sounds = {}

-- One looping track per area; AudioController cross-fades between them.
Sounds.music = {
	Plaza = { id = 1847463663, volume = 0.32, credit = "„Enchanted Feeling“ – APM Music" },
	Forest = { id = 9044806373, volume = 0.38, credit = "„View of the Fens“ – APM Music (KPM)" },
	Treasury = { id = 1838892274, volume = 0.3, credit = "„Charming Music Box“ – APM Music" },
	Ruins = { id = 9043602315, volume = 0.3, credit = "„Mystery Mansion“ – APM Music (KPM)" },
} :: { [string]: Sound }

Sounds.sfx = {
	collect = { id = 9116224180, volume = 0.45, credit = "Triangle – Pro Sound Effects" },
	sparkle = { id = 9119447936, volume = 0.5, credit = "Sparkle Bell Tree – Pro Sound Effects" },
	epic = { id = 1837769221, volume = 0.55, credit = "„Lost Princess“ (Sting) – APM Music" },
	click = { id = 9120232166, volume = 0.35, credit = "Click – Pro Sound Effects" },
	place = { id = 9113559651, volume = 0.5, credit = "Ceramic Slide – Pro Sound Effects" },
	upgrade = { id = 1844219718, volume = 0.6, credit = "„Chrome Bells“ (Link) – APM Music" },
	claim = { id = 1844124801, volume = 0.5, credit = "„Kaleidoscope“ (Link) – APM Music" },
	purchase = { id = 1841324020, volume = 0.5, credit = "„Summer Town“ (Sting) – APM Music" },
	error = { id = 9120885468, volume = 0.45, credit = "Wood Knock – Pro Sound Effects" },
	whoosh = { id = 9120733724, volume = 0.3, credit = "Airy Whoosh – Pro Sound Effects" },
} :: { [string]: Sound }

-- Collect sound pitch per rarity rank (Common = 1 … Legendary = 5): rarer finds ring brighter.
Sounds.collectPitch = { 1, 1.12, 1.26, 1.34, 1.42 }

return Sounds
