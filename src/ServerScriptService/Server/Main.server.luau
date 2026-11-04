--!strict
-- Server entry point: boots the services in dependency order and wires the player lifecycle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Services = script.Parent.Services
local Analytics = require(script.Parent.Util.Analytics)
local PlayerDataService = require(Services.PlayerDataService)
local PlotService = require(Services.PlotService)
local EconomyService = require(Services.EconomyService)
local DisplayService = require(Services.DisplayService)
local RelicSpawnService = require(Services.RelicSpawnService)
local UpgradeService = require(Services.UpgradeService)
local QuestService = require(Services.QuestService)
local ShopService = require(Services.ShopService)
local SettingsService = require(Services.SettingsService)
local TycoonService = require(Services.TycoonService)
local MapService = require(Services.MapService)
local LeaderboardService = require(Services.LeaderboardService)
local ExpeditionService = require(Services.ExpeditionService)

PlayerDataService.init()
PlotService.init()
EconomyService.init()
DisplayService.init()
RelicSpawnService.init()
UpgradeService.init()
QuestService.init()
ShopService.init()
SettingsService.init()
TycoonService.init()
MapService.init()
LeaderboardService.init()
ExpeditionService.init()

local function onPlayerAdded(player: Player)
	Analytics.onboarding(player, Analytics.Onboarding.Joined)
	local data = PlayerDataService.load(player)
	if not data or not player.Parent then
		return
	end
	PlotService.assign(player)
	PlotService.applyBuilds(player, data.builds)
	PlotService.renderAll(player, data.display)
	ShopService.startPlayer(player)
	EconomyService.setup(player)
	RelicSpawnService.startPlayer(player)
	QuestService.startPlayer(player)
	LeaderboardService.startPlayer(player)
	player:SetAttribute("Loaded", true)
	PlayerDataService.replicate(player)
end

local function onPlayerRemoving(player: Player)
	ExpeditionService.stopPlayer(player)
	MapService.stopPlayer(player)
	LeaderboardService.stopPlayer(player)
	RelicSpawnService.stopPlayer(player)
	QuestService.stopPlayer(player)
	EconomyService.forget(player)
	PlotService.release(player)
	PlayerDataService.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Studio-only test hook for the command bar / MCP. Lives in ServerStorage, so clients can
-- never reach it, and is not created on live servers.
if RunService:IsStudio() then
	local Builds = require(ReplicatedStorage.Shared.Builds)
	local Config = require(ReplicatedStorage.Shared.Config)
	local tools = Instance.new("BindableFunction")
	tools.Name = "DevTools"
	tools.OnInvoke = function(action: string, userId: number, ...: any)
		local player = Players:GetPlayerByUserId(userId)
		local data = player and PlayerDataService.get(player)
		if not player or not data then
			return nil
		end
		local args = { ... }
		if action == "grant" then
			EconomyService.grant(player, args[1], "devtools")
		elseif action == "setPass" then
			player:SetAttribute("Pass_" .. args[1], args[2] == true or nil)
			ShopService.refresh(player)
		elseif action == "receipt" then
			for _, product in Config.Shop.products do
				if product.key == args[1] then
					return ShopService.handleReceipt(player, product, args[2])
				end
			end
			return "unknown product"
		elseif action == "prompt" then
			-- Triggers an expedition prompt as this player (range, membership and rate checks apply).
			return ExpeditionService.trigger(args[1], player)
		elseif action == "expedition" then
			local data_ = PlayerDataService.get(player)
			if data_ and args[1] == "clearCooldown" then
				data_.expedition.cooldownUntil = 0
			end
			return data_ and data_.expedition
		elseif action == "leaderboard" then
			-- args: entries {{userId, score}}, remove flag; returns the refreshed top list.
			if args[1] then
				LeaderboardService.testEntries(args[1], args[2] == true)
			end
			return LeaderboardService.refresh()
		elseif action == "weeklydone" then
			data.weekly.progress = data.weekly.goal
			PlayerDataService.replicate(player)
		elseif action == "mappiece" then
			return MapService.addPiece(player)
		elseif action == "isle" then
			-- args: "travel" starts a visit (needs a complete map), otherwise lists its spots.
			if args[1] == "travel" then
				return MapService.travel(player)
			end
			return MapService.debug(player)
		elseif action == "spirits" then
			return RelicSpawnService.debug(player)
		elseif action == "nosave" then
			-- Everything after this stays in this Studio session only (free testing).
			PlayerDataService.setNoSave(userId)
		elseif action == "build" then
			-- Buys a build as if the player stepped on its button (all checks apply).
			return TycoonService.buy(player, args[1])
		elseif action == "save" then
			return PlayerDataService.saveNow(player)
		elseif action == "showcase" then
			-- Fills the treasury for screenshots without ever saving the result.
			PlayerDataService.setNoSave(userId)
			for _, build in Builds.list do
				data.builds[build.id] = true
			end
			data.tier = #Config.Tiers
			table.clear(data.display)
			for slot, relicId in args[1] do
				data.display[tostring(slot)] = relicId
				data.discovered[relicId] = true
			end
			PlotService.applyBuilds(player, data.builds)
			PlotService.renderAll(player, data.display)
			EconomyService.recompute(player)
			PlayerDataService.replicate(player)
		end
		return {
			data = data,
			plotIndex = PlotService.getIndex(player),
			rate = player:GetAttribute("CoinRate"),
			persistent = PlayerDataService.persistent,
		}
	end
	tools.Parent = ServerStorage
end
