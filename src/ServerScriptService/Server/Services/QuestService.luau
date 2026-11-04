--!strict
-- Goals that bring players back: three daily quests, collection-book milestones, visits to
-- other treasuries and the first-session tutorial flags. Listens to the Progress bus and a
-- light 2-second presence check; never trusts the client for progress.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local Progress = require(script.Parent.Parent.Util.Progress)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)

local FOREST_RADIUS = 60
local VISIT_RADIUS = 24

local QuestService = {}

local poolById: { [string]: any } = {}
for _, quest in Config.Quests.pool do
	poolById[quest.id] = quest
end
local claimLimiter = RateLimiter.new(4, 1)
local visited: { [Player]: { [number]: boolean } } = {}
local dirty: { [Player]: boolean } = {}
local forestCenter: Vector3? = nil

local function today(): number
	return math.floor(os.time() / 86400)
end

local function notify(player: Player, kind: string, text: string)
	Net.event("Notify"):FireClient(player, { kind = kind, text = text })
end

-- Deterministic per player and day, so a rejoin shows the same quests.
function QuestService.generate(userId: number, day: number, tier: number, social: boolean): { PlayerDataService.Quest }
	local rng = Random.new(userId * 7919 + day)
	local candidates = {}
	for _, quest in Config.Quests.pool do
		if social or not quest.social then
			table.insert(candidates, quest)
		end
	end
	local list = {}
	for _ = 1, math.min(Config.Quests.perDay, #candidates) do
		local quest = table.remove(candidates, rng:NextInteger(1, #candidates))
		table.insert(list, { id = quest.id, goal = quest.goals[math.min(tier, #quest.goals)], progress = 0, claimed = false })
	end
	return list
end

local function refreshDay(player: Player, data: PlayerDataService.Data)
	local day = today()
	if data.quests.day ~= day then
		data.quests.day = day
		data.quests.list = QuestService.generate(player.UserId, day, data.tier, #Players:GetPlayers() >= 2)
		return true
	end
	return false
end

local function checkMilestones(player: Player, data: PlayerDataService.Data)
	local count = 0
	for _ in data.discovered do
		count += 1
	end
	while data.milestones < #Config.Milestones and count >= Config.Milestones[data.milestones + 1].count do
		data.milestones += 1
		local milestone = Config.Milestones[data.milestones]
		EconomyService.grant(player, milestone.reward, "milestone_" .. milestone.count)
		notify(player, "milestone", ("Sammelbuch: %d Relikte entdeckt! +%d Münzen"):format(milestone.count, milestone.reward))
	end
end

local function finishTutorial(player: Player, data: PlayerDataService.Data)
	if not data.tutorial.done and data.stats.upgrades >= 1 and data.stats.forestVisited then
		data.tutorial.done = true
		Analytics.onboarding(player, Analytics.Onboarding.TutorialDone)
		PlayerDataService.replicate(player)
	end
end

function QuestService.claim(player: Player, index: any): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "not_loaded"
	end
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #data.quests.list then
		return false, "bad_quest"
	end
	local quest = data.quests.list[index]
	if quest.claimed then
		return false, "claimed"
	end
	if quest.progress < quest.goal then
		return false, "not_done"
	end
	quest.claimed = true
	local reward = Config.Quests.rewardByTier[data.tier]
	EconomyService.grant(player, reward, "quest_" .. quest.id)
	PlayerDataService.replicate(player)
	return true, nil
end

function QuestService.skipTutorial(player: Player): boolean
	local data = PlayerDataService.get(player)
	if not data or data.tutorial.done then
		return false
	end
	data.tutorial.done = true
	Analytics.custom(player, "TutorialSkipped")
	PlayerDataService.replicate(player)
	return true
end

function QuestService.startPlayer(player: Player)
	local data = PlayerDataService.get(player)
	if data then
		refreshDay(player, data)
		checkMilestones(player, data)
	end
end

function QuestService.stopPlayer(player: Player)
	visited[player] = nil
	dirty[player] = nil
end

local function onProgress(player: Player, stat: string, amount: number)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	if stat == "discover" then
		checkMilestones(player, data)
	elseif stat == "upgrade" then
		finishTutorial(player, data)
	end
	local changed = false
	for _, quest in data.quests.list do
		local def = poolById[quest.id]
		if def and def.stat == stat and not quest.claimed and quest.progress < quest.goal then
			quest.progress = math.min(quest.goal, quest.progress + amount)
			changed = true
		end
	end
	if changed then
		-- coin income ticks every second; batch those updates into the presence loop
		if stat == "earn" then
			dirty[player] = true
		else
			PlayerDataService.replicate(player)
		end
	end
end

local function presence()
	for _, player in Players:GetPlayers() do
		local data = PlayerDataService.get(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if data and root then
			if refreshDay(player, data) then
				dirty[player] = true
			end
			if not data.stats.forestVisited and forestCenter and (root.Position - forestCenter).Magnitude < FOREST_RADIUS then
				data.stats.forestVisited = true
				Analytics.onboarding(player, Analytics.Onboarding.ForestVisited)
				Progress.bump(player, "visitForest", 1)
				finishTutorial(player, data)
				dirty[player] = true
			end
			for owner, plot in PlotService.ownedPlots() do
				if owner ~= player and (root.Position - plot:GetPivot().Position).Magnitude < VISIT_RADIUS then
					local seen = visited[player] or {}
					visited[player] = seen
					if not seen[owner.UserId] then
						seen[owner.UserId] = true
						Progress.bump(player, "visit", 1)
						notify(owner, "visit", player.DisplayName .. " bewundert deine Schatzkammer!")
					end
				end
			end
		end
	end
	for player in dirty do
		dirty[player] = nil
		PlayerDataService.replicate(player)
	end
end

function QuestService.init()
	local forest = Workspace:WaitForChild("Aetheria"):FindFirstChild("WhisperForest")
	local moss = forest and forest:FindFirstChild("Moss") :: BasePart?
	forestCenter = if moss then moss.Position else nil

	Progress.on(onProgress)
	Net.func("ClaimQuest").OnServerInvoke = function(player: Player, index: any)
		if not claimLimiter:allow(player) then
			return false, "rate"
		end
		return QuestService.claim(player, index)
	end
	Net.func("SkipTutorial").OnServerInvoke = function(player: Player)
		return QuestService.skipTutorial(player)
	end
	task.spawn(function()
		while true do
			task.wait(2)
			presence()
		end
	end)
end

return QuestService
