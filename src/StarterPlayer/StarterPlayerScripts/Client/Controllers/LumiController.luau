--!strict
-- Lumi, the tutorial spirit: floats beside the player, says the next step in the HUD banner
-- and draws a soft beam towards where to go. Steps follow the player's real progress, so
-- nothing has to be clicked through; the server stores when the tutorial is done or skipped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ClientState = require(script.Parent.Parent.ClientState)
local Settings = require(script.Parent.Parent.Settings)

local player = Players.LocalPlayer
local LumiController = {}

local TURQUOISE = Color3.fromRGB(110, 235, 240)
local LAVENDER = Color3.fromRGB(205, 170, 255)
local FOREST_ENTRANCE = Vector3.new(0, 1, 100)

local hud: any
local relics: any
local plots: any
local model: Model
local core: Part
local glow: Part
local wingL: Part
local wingR: Part
local targetPart: Part
local beam: Beam
local smoothed: CFrame? = nil
local target: Vector3? = nil
local visible = false
local farewellUntil = 0
local wasActive = false

local function part(name: string, shape: Enum.PartType, size: Vector3, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = transparency
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

local function build()
	model = Instance.new("Model")
	model.Name = "Lumi"
	core = part("Core", Enum.PartType.Ball, Vector3.one * 1.1, TURQUOISE, 0)
	glow = part("Glow", Enum.PartType.Ball, Vector3.one * 1.9, TURQUOISE, 0.75)
	wingL = part("WingL", Enum.PartType.Block, Vector3.new(0.9, 0.5, 0.08), LAVENDER, 0.3)
	wingR = part("WingR", Enum.PartType.Block, Vector3.new(0.9, 0.5, 0.08), LAVENDER, 0.3)
	model.PrimaryPart = core
	local light = Instance.new("PointLight")
	light.Color = TURQUOISE
	light.Range = 8
	light.Brightness = 1.2
	light.Parent = core

	targetPart = Instance.new("Part")
	targetPart.Name = "LumiTarget"
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.CanTouch = false
	targetPart.Transparency = 1
	targetPart.Size = Vector3.one * 0.2
	targetPart.Parent = model

	local a0 = Instance.new("Attachment")
	a0.Parent = core
	local a1 = Instance.new("Attachment")
	a1.Parent = targetPart
	beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(TURQUOISE, LAVENDER)
	beam.Transparency = NumberSequence.new(0.25, 0.8)
	beam.Width0 = 0.35
	beam.Width1 = 0.15
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Segments = 12
	beam.CurveSize0 = 6
	beam.CurveSize1 = -2
	beam.Parent = core
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- The current tutorial line and where it points, derived only from server-confirmed state.
local function step(state: any, coins: number, rootPos: Vector3): (string?, Vector3?)
	local displayed, held = count(state.display), 0
	for _, n in state.inventory do
		held += n
	end
	local capacity = Config.Tiers[state.tier].pedestals
	local nextTier = Config.Tiers[state.tier + 1]
	if state.collected == 0 then
		return "Hallo, ich bin Lumi! Lauf zum leuchtenden Relikt vor dir.", relics.nearest(rootPos)
	elseif displayed == 0 then
		return "Super! Tippe auf »Schatzkammer« und stelle dein Relikt auf ein Podest.", plots.target("pedestal")
	elseif state.tier == 1 and nextTier and coins >= nextTier.cost then
		return "Genug Münzen! Halte E am Ausbau-Stein deiner Schatzkammer.", plots.target("upgrade")
	elseif held > 0 and displayed < capacity then
		return "Stelle auch dein neues Relikt aus – jedes erzeugt Münzen.", plots.target("pedestal")
	elseif state.tier == 1 and nextTier then
		return ("Sammle mehr Relikte. Bei %d Münzen kannst du ausbauen."):format(nextTier.cost), relics.nearest(rootPos)
	elseif not state.forestVisited then
		return "Toll! Im Flüsterwald im Süden warten seltenere Relikte.", FOREST_ENTRANCE
	end
	return nil, nil
end

local function evaluate()
	local state = ClientState.data
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not state or not root then
		return
	end
	local active = not state.tutorialDone
	if wasActive and not active then
		farewellUntil = os.clock() + 6
		hud.setGuide("Du bist jetzt ein echter Reliktjäger! Viel Spaß in Aetheria.", false)
	end
	wasActive = active

	if active then
		local text, where = step(state, player:GetAttribute("Coins") :: number? or 0, root.Position)
		target = where
		hud.setGuide(text, true)
	else
		target = nil
		if os.clock() > farewellUntil then
			hud.setGuide(nil, false)
		end
	end
	-- With hints switched off Lumi stays hidden; the tutorial still completes on the server.
	if not Settings.values.hints or player:GetAttribute("ExpRun") ~= nil then
		target = nil
		hud.setGuide(nil, false)
	end
	local show = (active or os.clock() < farewellUntil) and Settings.values.hints
	if show ~= visible then
		visible = show
		model.Parent = if show then Workspace else nil
	end
end

local function animate()
	if not visible then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local t = os.clock()
	local goal = root.CFrame * CFrame.new(2.4, 2 + math.sin(t * 2.2) * 0.35, 0.8)
	smoothed = if smoothed then smoothed:Lerp(goal, 0.12) else goal
	local cf = CFrame.new((smoothed :: CFrame).Position)
	core.CFrame = cf
	glow.CFrame = cf
	local flap = math.sin(t * 12) * 0.5
	wingL.CFrame = cf * CFrame.new(-0.6, 0.15, 0.2) * CFrame.Angles(0, math.rad(20), math.rad(20) + flap)
	wingR.CFrame = cf * CFrame.new(0.6, 0.15, 0.2) * CFrame.Angles(0, math.rad(-20), math.rad(-20) - flap)

	local where = target
	if where and (where - root.Position).Magnitude > 9 then
		targetPart.CFrame = CFrame.new(where + Vector3.new(0, 2, 0))
		beam.Enabled = true
	else
		beam.Enabled = false
	end
end

function LumiController.start(hudController: any, relicController: any, plotController: any)
	hud, relics, plots = hudController, relicController, plotController
	build()
	RunService.RenderStepped:Connect(animate)
	task.spawn(function()
		while true do
			evaluate()
			task.wait(0.3)
		end
	end)
end

return LumiController
