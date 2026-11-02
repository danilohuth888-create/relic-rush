--!strict
-- Server entry point: boots the services in dependency order and wires the player lifecycle.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Services = script.Parent.Services
local PlayerDataService = require(Services.PlayerDataService)
local PlotService = require(Services.PlotService)
local EconomyService = require(Services.EconomyService)
local DisplayService = require(Services.DisplayService)
local RelicSpawnService = require(Services.RelicSpawnService)

PlayerDataService.init()
PlotService.init()
EconomyService.init()
DisplayService.init()
RelicSpawnService.init()

local function onPlayerAdded(player: Player)
	local data = PlayerDataService.load(player)
	if not data or not player.Parent then
		return
	end
	PlotService.assign(player)
	PlotService.applyTier(player, data.tier)
	PlotService.renderAll(player, data.display)
	EconomyService.setup(player)
	RelicSpawnService.startPlayer(player)
	player:SetAttribute("Loaded", true)
	PlayerDataService.replicate(player)
end

local function onPlayerRemoving(player: Player)
	RelicSpawnService.stopPlayer(player)
	EconomyService.forget(player)
	PlotService.release(player)
	PlayerDataService.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Studio-only test hook: lets the command bar / MCP read real server profiles. Lives in
-- ServerStorage, so clients can never reach it, and is not created on live servers.
if RunService:IsStudio() then
	local inspect = Instance.new("BindableFunction")
	inspect.Name = "DevInspect"
	inspect.OnInvoke = function(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		local data = player and PlayerDataService.get(player)
		if not data then
			return nil
		end
		return {
			data = data,
			plotIndex = PlotService.getIndex(player),
			rate = player:GetAttribute("CoinRate"),
			persistent = PlayerDataService.persistent,
		}
	end
	inspect.Parent = ServerStorage
end
