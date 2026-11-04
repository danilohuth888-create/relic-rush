--!strict
-- Text in the world that several players read (signs, build buttons, the leaderboard): the
-- server writes the German text and stores the source format plus arguments as attributes,
-- and each client's LocalizeController shows it in that player's language.
-- Argument prefixes: "§text" is translated too, "#123" is a number shown with the local
-- thousands separator; everything else is used as is.

local WorldText = {}

local MARK = "§"

local function render(arg: any): string
	local text = tostring(arg)
	if text:sub(1, #MARK) == MARK then
		return text:sub(#MARK + 1)
	elseif text:sub(1, 1) == "#" then
		local digits = tostring(math.floor(tonumber(text:sub(2)) or 0))
		local out = digits:reverse():gsub("(%d%d%d)", "%1."):reverse()
		return if out:sub(1, 1) == "." then out:sub(2) else out
	end
	return text
end

function WorldText.set(label: TextLabel, source: string, ...: any)
	local args = { ... }
	local raw, shown = {}, {}
	for i, arg in args do
		raw[i] = tostring(arg)
		shown[i] = render(arg)
	end
	label.Text = if #args > 0 then string.format(source, table.unpack(shown)) else source
	label:SetAttribute("LArgs", table.concat(raw, "\t"))
	label:SetAttribute("LFormat", source)
end

return WorldText
