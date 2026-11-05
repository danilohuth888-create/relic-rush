--!strict
-- Roblox badges for milestones players like to show off (they also appear on the game page).
-- Badge ids live in Config.Badges; an id of 0 means the badge is not created yet and is
-- skipped. Awarding listens to the progress bus, so no gameplay service needs to know.

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local Progress = require(script.Parent.Parent.Util.Progress)
local PlayerDataService = require(script.Parent.PlayerDataService)

local Badges = {}

local awarded: { [Player]: { [string]: boolean } } = {}

-- Awards once per session (Roblox ignores repeats anyway; this saves the web calls).
function Badges.award(player: Player, key: string)
	local id = Config.Badges[key]
	if type(id) ~= "number" or id == 0 then
		return
	end
	local mine = awarded[player] or {}
	awarded[player] = mine
	if mine[key] then
		return
	end
	mine[key] = true
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, id)
		if ok and not has then
			pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		end
	end)
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function onProgress(player: Player, stat: string, _amount: number, detail: any?)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	if stat == "spirit" then
		Badges.award(player, "firstSpirit")
	elseif stat == "place" then
		Badges.award(player, "firstRelic")
	elseif stat == "discover" then
		local found = count(data.discovered)
		if found >= 10 then
			Badges.award(player, "collector10")
		end
		if found >= #RelicDefs.list then
			Badges.award(player, "collectorAll")
		end
		local def = type(detail) == "string" and RelicDefs.byId[detail]
		if def and def.rarity == "Legendary" then
			Badges.award(player, "legendary")
		end
	elseif stat == "upgrade" then
		if data.builds.hall then
			Badges.award(player, "manor")
		end
		if data.builds.vault then
			Badges.award(player, "vault")
		end
	elseif stat == "treasure" then
		Badges.award(player, "treasure")
	elseif stat == "expedition" then
		Badges.award(player, "expedition")
	end
end

function Badges.startPlayer(player: Player)
	Badges.award(player, "welcome")
	player:GetAttributeChangedSignal("ExpRun"):Connect(function()
		if player:GetAttribute("ExpRun") == "isle" then
			Badges.award(player, "isle")
		end
	end)
end

function Badges.stopPlayer(player: Player)
	awarded[player] = nil
end

function Badges.init()
	Progress.on(onProgress)
end

return Badges
