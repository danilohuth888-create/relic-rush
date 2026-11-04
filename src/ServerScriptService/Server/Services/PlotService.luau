--!strict
-- Hands each player one of the treasury plots in Workspace.Aetheria.Plots and keeps the plot's
-- visuals (owner sign, active pedestals, displayed relics) in sync with the owner's data.
-- Plot layout contract (built by tools/world/BuildAetheria.luau):
--   PlotN (Model, attrs PlotIndex, OwnerUserId)
--     Sign.Board.SurfaceGui.OwnerLabel   SpawnPoint (Part)   Accents (Folder of Neon parts)
--     Pedestals.PedestalK (Model, attrs Slot, RequiredTier) with Base + Top parts
-- At runtime each plot also gets Buttons.Pad1..6 (tycoon build buttons, see TycoonService)
-- and Builds.<id> (bought decoration, see Util/Blueprints).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Builds = require(ReplicatedStorage.Shared.Builds)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local RelicVisuals = require(ReplicatedStorage.Shared.RelicVisuals)
local Blueprints = require(script.Parent.Parent.Util.Blueprints)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local PlotService = {}

local plotsFolder: Instance
local owners: { [number]: Player } = {}
local homeLimiter = RateLimiter.new(2, 0.5)
-- Build buttons on the side strips of every plot (plot-local x, z).
local BUTTON_SPOTS = { { -16.5, -5 }, { 16.5, -5 }, { -16.5, 1 }, { 16.5, 1 }, { -16.5, 7 }, { 16.5, 7 } }
local BUTTON_READY = Color3.fromRGB(90, 230, 130)
local BUTTON_LOCKED = Color3.fromRGB(150, 140, 165)

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

-- The old upgrade stone now shows how much of the building plan is done.
local function setPlanLabel(plot: Model, owned: { [string]: boolean }?)
	local label = plot:FindFirstChild("UpgradeLabel", true)
	if not (label and label:IsA("TextLabel")) then
		return
	end
	if not owned then
		label.Text = "Bauplan"
	else
		label.Text = ("Bauplan\n%d / %d gebaut"):format(Builds.count(owned), #Builds.list)
	end
end

local function formatCost(n: number): string
	local digits = tostring(math.floor(n))
	local out = digits:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return if out:sub(1, 1) == "." then out:sub(2) else out
end

local function tagLabel(gui: Instance, name: string, y: number, h: number, color: Color3)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = UDim2.fromScale(0, y)
	l.Size = UDim2.fromScale(1, h)
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.3
	l.Parent = gui
end

-- Six glowing pads offering the cheapest builds whose requirements are met.
local function createButtons(plot: Model)
	local floor = plot:FindFirstChild("Floor") :: BasePart?
	if not floor or plot:FindFirstChild("Buttons") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Buttons"
	for i, spot in BUTTON_SPOTS do
		local pad = Instance.new("Part")
		pad.Name = "Pad" .. i
		pad.Size = Vector3.new(3.4, 0.3, 3.4)
		pad.CFrame = floor.CFrame * CFrame.new(spot[1], 0.75, spot[2])
		pad.Anchored = true
		pad.CanCollide = false
		pad.CanQuery = false
		pad.CanTouch = false
		pad.CastShadow = false
		pad.Material = Enum.Material.Neon
		pad.Transparency = 1
		local gui = Instance.new("BillboardGui")
		gui.Name = "Tag"
		gui.Size = UDim2.fromOffset(170, 64)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
		gui.MaxDistance = 70
		gui.LightInfluence = 0
		gui.Enabled = false
		tagLabel(gui, "BuildName", 0, 0.55, Color3.new(1, 1, 1))
		tagLabel(gui, "Cost", 0.55, 0.45, Color3.fromRGB(255, 215, 90))
		gui.Parent = pad
		pad.Parent = folder
	end
	folder.Parent = plot
end

local function setButtons(plot: Model, owned: { [string]: boolean }?)
	local folder = plot:FindFirstChild("Buttons")
	if not folder then
		return
	end
	local offers = if owned then Builds.available(owned) else {}
	for i = 1, #BUTTON_SPOTS do
		local pad = folder:FindFirstChild("Pad" .. i) :: BasePart?
		if pad then
			local build = offers[i]
			local gui = pad:FindFirstChild("Tag") :: BillboardGui
			pad:SetAttribute("BuildId", if build then build.id else nil)
			pad.Transparency = if build then 0.2 else 1
			gui.Enabled = build ~= nil
			if build then
				(gui:FindFirstChild("BuildName") :: TextLabel).Text = build.name
				local boost = if build.boost then (" · +%d %%"):format(math.floor(build.boost * 100 + 0.5)) else ""
				(gui:FindFirstChild("Cost") :: TextLabel).Text = formatCost(build.cost) .. " Münzen" .. boost
			end
		end
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

-- owned = nil means a free plot: only the starter pedestals, no buttons.
local function applyBuildsTo(plot: Model, owned: { [string]: boolean }?, animate: boolean)
	local builds = owned or {}
	Blueprints.sync(plot, builds, animate)
	local pedestals = plot:FindFirstChild("Pedestals")
	for _, pedestal in (if pedestals then pedestals:GetChildren() else {}) do
		local slot = pedestal:GetAttribute("Slot") :: number? or 1
		setPedestalVisible(pedestal, Builds.slotUnlocked(builds, slot))
	end
	local tier = Builds.tier(builds)
	setDecor(plot, tier)
	setButtons(plot, owned)
	setPlanLabel(plot, owned)
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
	applyBuildsTo(plot, nil, false)
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
		createButtons(plot)
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

function PlotService.applyBuilds(player: Player, owned: { [string]: boolean }, animate: boolean?)
	local plot = PlotService.getPlot(player)
	if plot then
		applyBuildsTo(plot, owned, animate == true)
	end
end

-- Colours the owner's buttons green when affordable, grey otherwise.
function PlotService.tintButtons(player: Player, coins: number)
	local plot = PlotService.getPlot(player)
	local folder = plot and plot:FindFirstChild("Buttons")
	for _, pad in (if folder then folder:GetChildren() else {}) do
		local id = pad:GetAttribute("BuildId")
		local build = type(id) == "string" and Builds.byId[id]
		if build and pad:IsA("BasePart") then
			local color = if coins >= build.cost then BUTTON_READY else BUTTON_LOCKED
			if pad.Color ~= color then
				pad.Color = color
			end
		end
	end
end

-- The owner's active build buttons (pads with a BuildId).
function PlotService.buttons(player: Player): { BasePart }
	local plot = PlotService.getPlot(player)
	local folder = plot and plot:FindFirstChild("Buttons")
	local result = {}
	for _, pad in (if folder then folder:GetChildren() else {}) do
		if pad:IsA("BasePart") and pad:GetAttribute("BuildId") then
			table.insert(result, pad)
		end
	end
	return result
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
	-- Displayed relics are the treasury's showpieces, so they stand larger than pickups.
	model:ScaleTo(1.6)
	model:PivotTo(top.CFrame * CFrame.new(0, 1, 0))

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(160, 40)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
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
