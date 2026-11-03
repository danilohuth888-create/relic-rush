--!strict
-- In-game credits, shown in the settings panel. Audio credits come straight from Sounds so
-- they can never drift from what actually plays; third-party models are listed in MODELS
-- (CC-BY requires attribution, see docs/CREDITS.md for the full licence details).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

export type Section = { title: string, lines: { string } }

-- { title, author, licence } for every imported model; filled when models are added.
local MODELS: { { title: string, author: string, licence: string } } = {}

local function sorted(map: { [string]: Sounds.Sound }): { string }
	local seen, lines = {}, {}
	for _, info in map do
		if not seen[info.credit] then
			seen[info.credit] = true
			table.insert(lines, info.credit)
		end
	end
	table.sort(lines)
	return lines
end

local Credits = {}

function Credits.sections(): { Section }
	local sections: { Section } = {
		{ title = "Idee, Code und Welt", lines = { "RELIC RUSH-Team" } },
		{ title = "Musik (Roblox-Audiobibliothek)", lines = sorted(Sounds.music) },
		{ title = "Soundeffekte (Roblox-Audiobibliothek)", lines = sorted(Sounds.sfx) },
	}
	if #MODELS > 0 then
		local lines = {}
		for _, model in MODELS do
			table.insert(lines, ("„%s“ von %s (%s)"):format(model.title, model.author, model.licence))
		end
		table.insert(sections, { title = "3D-Modelle", lines = lines })
	end
	return sections
end

return Credits
