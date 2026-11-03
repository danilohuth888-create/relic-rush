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

PlayerDataService.init()
PlotService.init()
EconomyService.init()
DisplayService.init()
RelicSpawnService.init()
UpgradeService.init()
QuestService.init()
ShopService.init()
SettingsService.init()

local function onPlayerAdded(player: Player)
	Analytics.onboarding(player, Analytics.Onboarding.Joined)
	local data = PlayerDataService.load(player)
	if not data or not player.Parent then
		return
	end
	PlotService.assign(player)
	PlotService.applyTier(player, data.tier)
	PlotService.renderAll(player, data.display)
	ShopService.startPlayer(player)
	EconomyService.setup(player)
	RelicSpawnService.startPlayer(player)
	QuestService.startPlayer(player)
	player:SetAttribute("Loaded", true)
	PlayerDataService.replicate(player)
end

local function onPlayerRemoving(player: Player)
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
		elseif action == "save" then
			return PlayerDataService.saveNow(player)
		elseif action == "showcase" then
			-- Fills the treasury for screenshots without ever saving the result.
			PlayerDataService.setNoSave(userId)
			data.tier = #Config.Tiers
			table.clear(data.display)
			for slot, relicId in args[1] do
				data.display[tostring(slot)] = relicId
				data.discovered[relicId] = true
			end
			PlotService.applyTier(player, data.tier)
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
