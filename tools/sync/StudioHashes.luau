-- Prints a JSON map { "Service.Path.Script": fnv1a-hash } for every script RELIC RUSH owns in
-- Studio. Compare it with the repo via: node tools/sync/manifest.mjs <saved-output.json>

local HttpService = game:GetService("HttpService")

local ROOTS = {
	game.ReplicatedStorage:FindFirstChild("Shared"),
	game.ServerScriptService:FindFirstChild("Server"),
	game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Client"),
}

local function fnv1a(text: string): string
	text = text:gsub("\r\n", "\n")
	local h = 2166136261
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		-- h * 16777619 mod 2^32 without losing precision: 16777619 = 2^24 + 403
		h = (bit32.lshift(h, 24) + h * 403) % 4294967296
	end
	return string.format("%08x", h)
end

local result = {}
for _, rootFolder in ROOTS do
	if rootFolder then
		for _, s in rootFolder:GetDescendants() do
			if s:IsA("LuaSourceContainer") then
				local path = s:GetFullName():gsub("^StarterPlayer%.", "StarterPlayer.")
				result[path] = fnv1a((s :: any).Source)
			end
		end
	end
end
return HttpService:JSONEncode(result)
