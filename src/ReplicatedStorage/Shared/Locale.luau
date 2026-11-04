--!strict
-- Languages: German is the source language, everyone else gets English.
-- Texts are written in German in the code and wrapped: Locale.format(lang, "…%d…", n). The
-- English table below is keyed by the German source text, so a missing entry simply shows
-- German. tools/i18n/check.py lists wrapped texts that have no English entry yet.
-- Server code translates per player (Locale.of(player)); world texts that several players
-- see are translated on each client by LocalizeController.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Strings = require(script.Parent.LocaleEN)

local Locale = {}

-- "de" for German clients, "en" for everyone else. In Studio, Workspace attribute
-- TestLanguage ("de"/"en") overrides it for language tests.
function Locale.of(player: Player?): string
	if RunService:IsStudio() then
		local test = Workspace:GetAttribute("TestLanguage")
		if test == "de" or test == "en" then
			return test
		end
	end
	local id = if player then player.LocaleId else "de-de"
	return if string.lower(id):sub(1, 2) == "de" then "de" else "en"
end

function Locale.text(lang: string, source: string): string
	if lang == "en" then
		return Strings[source] or source
	end
	return source
end

function Locale.format(lang: string, source: string, ...: any): string
	local text = Locale.text(lang, source)
	if select("#", ...) == 0 then
		return text
	end
	return string.format(text, ...)
end

-- Whole numbers with thousands separators: 12.500 in German, 12,500 in English.
function Locale.number(lang: string, n: number): string
	local digits = tostring(math.floor(n))
	local sep = if lang == "en" then "," else "."
	local out = digits:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
	if out:sub(1, 1) == sep then
		out = out:sub(2)
	end
	return out
end

-- One decimal: "1,5" in German, "1.5" in English.
function Locale.decimal(lang: string, n: number): string
	local text = ("%g"):format(math.floor(n * 10 + 0.5) / 10)
	return if lang == "en" then text else (text:gsub("%.", ","))
end

function Locale.has(source: string): boolean
	return Strings[source] ~= nil
end

return Locale
