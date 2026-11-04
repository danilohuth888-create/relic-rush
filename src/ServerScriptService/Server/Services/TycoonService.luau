--!strict
-- The treasury tycoon: owners buy builds (Shared/Builds) by stepping on the glowing buttons of
-- their own plot. The server watches the owners' positions itself, so there is no remote to
-- abuse; a button fires once per step and the owner has to step off before it fires again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builds = require(ReplicatedStorage.Shared.Builds)
local Config = require(ReplicatedStorage.Shared.Config)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Net = require(ReplicatedStorage.Shared.Net)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local Blueprints = require(script.Parent.Parent.Util.Blueprints)
local Progress = require(script.Parent.Parent.Util.Progress)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)

local TycoonService = {}

local standingOn: { [Player]: BasePart } = {}
local lastTint = 0

local function notify(player: Player, message: { [string]: any })
	Net.event("Notify"):FireClient(player, message)
end

function TycoonService.buy(player: Player, id: any): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "not_loaded"
	end
	local build = type(id) == "string" and Builds.byId[id]
	if not build then
		return false, "bad_build"
	end
	if not Builds.canBuild(data.builds, build) then
		return false, if data.builds[build.id] then "owned" else "locked_build"
	end
	if not EconomyService.trySpend(player, build.cost, "build_" .. build.id) then
		return false, "no_coins"
	end
	data.builds[build.id] = true
	data.stats.upgrades += 1
	if data.stats.upgrades == 1 then
		Analytics.onboarding(player, Analytics.Onboarding.FirstUpgrade)
	end
	if build.tier and build.tier > data.tier then
		data.tier = build.tier
	end
	PlotService.applyBuilds(player, data.builds, true)
	EconomyService.recompute(player)
	PlayerDataService.replicate(player)
	Progress.bump(player, "upgrade", 1)

	local plot = PlotService.getPlot(player)
	local position = plot and (Blueprints.position(plot, build.id) or plot:GetPivot().Position)
	local lang = Locale.of(player)
	local name = Locale.text(lang, build.name)
	local text
	if build.tier then
		text = Locale.format(lang, "%s freigeschaltet! Neue Bau-Tasten sind erschienen.", Locale.text(lang, Config.Tiers[build.tier].name))
	elseif build.pedestal then
		text = Locale.format(lang, "%s gebaut – stell ein Relikt darauf!", name)
	elseif build.boost then
		text = Locale.format(lang, "%s gebaut! Deine Relikte bringen jetzt +%d %% mehr.", name, math.floor((Builds.multiplier(data.builds) - 1) * 100 + 0.5))
	else
		text = Locale.format(lang, "%s gebaut!", name)
	end
	notify(player, { kind = if build.tier then "upgrade" else "build", text = text, position = position })
	return true, nil
end

local function onButton(player: Player, pad: BasePart)
	local id = pad:GetAttribute("BuildId")
	local build = type(id) == "string" and Builds.byId[id]
	if not build then
		return
	end
	local ok, err = TycoonService.buy(player, id)
	if not ok and err == "no_coins" then
		local coins = player:GetAttribute("Coins") :: number? or 0
		notify(player, { kind = "wrong", text = Locale.format(Locale.of(player), "Dir fehlen noch %d Münzen für %s.", math.max(0, build.cost - coins), Locale.text(Locale.of(player), build.name)) })
	end
end

local function step()
	local now = os.clock()
	local tint = now - lastTint > 0.5
	if tint then
		lastTint = now
	end
	for owner in PlotService.ownedPlots() do
		local character = owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local on: BasePart? = nil
		if root then
			for _, pad in PlotService.buttons(owner) do
				local rel = pad.CFrame:PointToObjectSpace(root.Position)
				if math.abs(rel.X) < 2.2 and math.abs(rel.Z) < 2.2 and rel.Y > -1 and rel.Y < 6 then
					on = pad
					break
				end
			end
		end
		if on and standingOn[owner] ~= on then
			standingOn[owner] = on
			task.spawn(onButton, owner, on)
		elseif not on then
			standingOn[owner] = nil
		end
		if tint then
			PlotService.tintButtons(owner, owner:GetAttribute("Coins") :: number? or 0)
		end
	end
	for player in standingOn do
		if not player.Parent then
			standingOn[player] = nil
		end
	end
end

function TycoonService.init()
	task.spawn(function()
		while true do
			task.wait(0.2)
			step()
		end
	end)
end

return TycoonService
