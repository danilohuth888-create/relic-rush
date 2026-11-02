--!strict
-- Hands each player one of the treasury plots in Workspace.Aetheria.Plots and keeps the plot's
-- visuals (owner sign, active pedestals, displayed relics) in sync with the owner's data.
-- Plot layout contract (built by tools/world/BuildAetheria.luau):
--   PlotN (Model, attrs PlotIndex, OwnerUserId)
--     Sign.Board.SurfaceGui.OwnerLabel   SpawnPoint (Part)   Accents (Folder of Neon parts)
--     Pedestals.PedestalK (Model, attrs Slot, RequiredTier) with Base + Top parts

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local RelicVisuals = require(ReplicatedStorage.Shared.RelicVisuals)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local PlotService = {}

local plotsFolder: Instance
local owners: { [number]: Player } = {}
local homeLimiter = RateLimiter.new(2, 0.5)

local function plotModel(index: number): Model?
	return plotsFolder:FindFirstChild("Plot" .. index) :: Model?
end

local function setSign(plot: Model, text: string)
	local label = plot:FindFirstChild("OwnerLabel", true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function setAccents(plot: Model, claimed: boolean)
	local accents = plot:FindFirstChild("Accents")
	if not accents then
		return
	end
	for _, p in accents:GetChildren() do
		if p:IsA("BasePart") then
			p.Material = if claimed then Enum.Material.Neon else Enum.Material.SmoothPlastic
			p.Transparency = if claimed then 0 else 0.35
		end
	end
end

-- Locked pedestals stay as faint ghosts so players can see what the next upgrade brings.
local function setPedestalVisible(pedestal: Instance, visible: boolean)
	for _, p in pedestal:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Top" then
			if p:GetAttribute("BaseTransparency") == nil then
				p:SetAttribute("BaseTransparency", p.Transparency)
			end
			p.Transparency = if visible then p:GetAttribute("BaseTransparency") :: number else 0.82
			p.CanCollide = visible
			p.CanQuery = visible
		end
	end
	pedestal:SetAttribute("Active", visible)
end

-- Decor2 / Decor3 folders hold the extra decoration that appears with each tier.
local function setDecor(plot: Model, tier: number)
	for level = 2, #Config.Tiers do
		local decor = plot:FindFirstChild("Decor" .. level)
		if decor then
			for _, p in decor:GetDescendants() do
				if p:IsA("BasePart") then
					if p:GetAttribute("BaseTransparency") == nil then
						p:SetAttribute("BaseTransparency", p.Transparency)
					end
					local shown = tier >= level
					p.Transparency = if shown then p:GetAttribute("BaseTransparency") :: number else 1
					p.CanCollide = shown and p:GetAttribute("Solid") == true
				elseif p:IsA("Light") then
					p.Enabled = tier >= level
				end
			end
		end
	end
end

local function setUpgradeLabel(plot: Model, tier: number, owned: boolean)
	local label = plot:FindFirstChild("UpgradeLabel", true)
	if not (label and label:IsA("TextLabel")) then
		return
	end
	local nextTier = Config.Tiers[tier + 1]
	if not owned then
		label.Text = "Ausbau-Stein"
	elseif nextTier then
		label.Text = ("%s\n%d Münzen"):format(nextTier.name, nextTier.cost)
	else
		label.Text = "Voll ausgebaut!"
	end
end

local GOLD = Color3.fromRGB(255, 200, 80)
local function setVipLook(plot: Model, vip: boolean)
	local accents = plot:FindFirstChild("Accents")
	local banner = plot:FindFirstChild("Banner") :: BasePart?
	for _, p in (if accents then accents:GetChildren() else {}) do
		if p:IsA("BasePart") then
			if p:GetAttribute("BaseColor") == nil then
				p:SetAttribute("BaseColor", p.Color)
			end
			p.Color = if vip then GOLD else p:GetAttribute("BaseColor") :: Color3
		end
	end
	if banner then
		if banner:GetAttribute("BaseColor") == nil then
			banner:SetAttribute("BaseColor", banner.Color)
		end
		banner.Color = if vip then GOLD else banner:GetAttribute("BaseColor") :: Color3
		banner.Material = if vip then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

local function clearDisplay(pedestal: Instance)
	local old = pedestal:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
end

local function applyTierTo(plot: Model, tier: number)
	local pedestals = plot:FindFirstChild("Pedestals")
	if not pedestals then
		return
	end
	for _, pedestal in pedestals:GetChildren() do
		local required = pedestal:GetAttribute("RequiredTier") :: number? or 1
		setPedestalVisible(pedestal, required <= tier)
	end
	setDecor(plot, tier)
	setUpgradeLabel(plot, tier, (plot:GetAttribute("OwnerUserId") :: number? or 0) ~= 0)
	plot:SetAttribute("Tier", tier)
end

local function resetPlot(plot: Model)
	plot:SetAttribute("OwnerUserId", 0)
	setSign(plot, "Freie Schatzkammer")
	setAccents(plot, false)
	setVipLook(plot, false)
	local pedestals = plot:FindFirstChild("Pedestals")
	if pedestals then
		for _, pedestal in pedestals:GetChildren() do
			clearDisplay(pedestal)
		end
	end
	applyTierTo(plot, 1)
end

-- Lowest free index; kept pure so assignment logic is testable without real players.
function PlotService.pickFreeIndex(taken: { [number]: any }, max: number): number?
	for i = 1, max do
		if taken[i] == nil then
			return i
		end
	end
	return nil
end

function PlotService.init()
	plotsFolder = Workspace:WaitForChild("Aetheria"):WaitForChild("Plots")
	for i = 1, Config.MaxPlots do
		local plot = plotModel(i)
		assert(plot, "missing Plot" .. i)
		resetPlot(plot)
	end

	Net.func("GoHome").OnServerInvoke = function(player: Player)
		if not homeLimiter:allow(player) then
			return false
		end
		return PlotService.teleportHome(player)
	end
end

function PlotService.assign(player: Player): number?
	local index = PlotService.pickFreeIndex(owners, Config.MaxPlots)
	if not index then
		warn("[Plots] No free plot for " .. player.Name)
		return nil
	end
	owners[index] = player
	local plot = plotModel(index) :: Model
	plot:SetAttribute("OwnerUserId", player.UserId)
	setSign(plot, "Schatzkammer von " .. player.DisplayName)
	setAccents(plot, true)
	player:SetAttribute("PlotIndex", index)
	return index
end

function PlotService.release(player: Player)
	local index = PlotService.getIndex(player)
	if index then
		owners[index] = nil
		resetPlot(plotModel(index) :: Model)
	end
	player:SetAttribute("PlotIndex", nil)
end

function PlotService.getIndex(player: Player): number?
	local index = player:GetAttribute("PlotIndex")
	if type(index) == "number" and owners[index] == player then
		return index
	end
	return nil
end

function PlotService.getPlot(player: Player): Model?
	local index = PlotService.getIndex(player)
	return if index then plotModel(index) else nil
end

function PlotService.getPedestal(player: Player, slot: number): Model?
	local plot = PlotService.getPlot(player)
	local pedestals = plot and plot:FindFirstChild("Pedestals")
	return if pedestals then pedestals:FindFirstChild("Pedestal" .. slot) :: Model? else nil
end

function PlotService.applyTier(player: Player, tier: number)
	local plot = PlotService.getPlot(player)
	if plot then
		applyTierTo(plot, tier)
	end
end

function PlotService.setVip(player: Player, vip: boolean)
	local plot = PlotService.getPlot(player)
	if plot then
		setVipLook(plot, vip)
	end
end

-- Every claimed plot keyed by its owner, for visit detection.
function PlotService.ownedPlots(): { [Player]: Model }
	local result = {}
	for index, owner in owners do
		local plot = plotModel(index)
		if plot then
			result[owner] = plot
		end
	end
	return result
end

-- Puts the relic model on the pedestal (visible to every player) or clears it.
function PlotService.renderSlot(player: Player, slot: number, relicId: string?)
	local pedestal = PlotService.getPedestal(player, slot)
	if not pedestal then
		return
	end
	clearDisplay(pedestal)
	local def = relicId and RelicDefs.byId[relicId]
	local top = pedestal:FindFirstChild("Top") :: BasePart?
	if not def or not top then
		return
	end
	local model = RelicVisuals.build(def, { effects = true })
	model.Name = "Display"
	model:PivotTo(top.CFrame * CFrame.new(0, 1.6, 0))

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(160, 40)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	tag.MaxDistance = 40
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = def.name
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Config.Rarities[def.rarity].color
	label.TextStrokeTransparency = 0.4
	label.Parent = tag
	tag.Parent = model.PrimaryPart

	CollectionService:AddTag(model, "FloatingRelic")
	model.Parent = pedestal
end

function PlotService.renderAll(player: Player, display: { [string]: string })
	for slot = 1, Config.MaxPedestals do
		PlotService.renderSlot(player, slot, display[tostring(slot)])
	end
end

function PlotService.teleportHome(player: Player): boolean
	local plot = PlotService.getPlot(player)
	local character = player.Character
	local spawnPoint = plot and plot:FindFirstChild("SpawnPoint") :: BasePart?
	if not spawnPoint or not character or not character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	character:PivotTo(spawnPoint.CFrame * CFrame.new(0, 3, 0))
	return true
end

return PlotService
