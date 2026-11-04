--!strict
-- Draws the dig mound of the player's open treasure map (only this player sees it) with a
-- "Graben" prompt. A golden light beam rises once the player is close. The server checks the
-- map and the distance and pays the treasure; this client then lets a chest burst open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Net = require(ReplicatedStorage.Shared.Net)
local Audio = require(script.Parent.Parent.Audio)
local ClientState = require(script.Parent.Parent.ClientState)
local FxController = require(script.Parent.FxController)

local GOLD = Color3.fromRGB(255, 205, 90)
local WOOD = Color3.fromRGB(140, 92, 60)
local BEAM_RANGE = 50 -- the beam shows from this distance, so the riddle still matters

local TreasureController = {}

local LANG = Locale.of(Players.LocalPlayer)
local function L(source: string, ...: any): string
	return Locale.format(LANG, source, ...)
end

local hud: any
local mound: Model? = nil
local beamConnection: RBXScriptConnection? = nil
local shownSpot = 0
local digging = false

local function part(parent: Instance, name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

-- A chest rises out of the ground, flips its lid open and showers gold.
local function chestReveal(position: Vector3)
	local model = Instance.new("Model")
	model.Name = "TreasureChest"
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local facing = if root then Vector3.new(root.Position.X, position.Y, root.Position.Z) else position + Vector3.new(0, 0, -1)
	local base = CFrame.lookAt(position, facing)
	local pieces: { { part: BasePart, offset: CFrame, lid: boolean } } = {}
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, lid: boolean)
		local p = part(model, name, Enum.PartType.Block, size, base * offset, color, material)
		table.insert(pieces, { part = p, offset = offset, lid = lid })
		return p
	end
	piece("Box", Vector3.new(3, 1.8, 2.2), CFrame.new(0, 0.9, 0), WOOD, Enum.Material.Wood, false)
	for _, x in { -1.1, 1.1 } do
		piece("Band", Vector3.new(0.3, 1.85, 2.3), CFrame.new(x, 0.9, 0), GOLD, Enum.Material.Metal, false)
	end
	piece("Lock", Vector3.new(0.5, 0.6, 0.2), CFrame.new(0, 1.3, -1.15), GOLD, Enum.Material.Metal, false)
	local glow = piece("Gold", Vector3.new(2.6, 0.3, 1.8), CFrame.new(0, 1.7, 0), GOLD, Enum.Material.Neon, false)
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 14
	light.Brightness = 2
	light.Parent = glow
	-- Lid pieces are given relative to the hinge on the back top edge.
	piece("Lid", Vector3.new(3, 0.8, 2.2), CFrame.new(0, 0.4, -1.1), WOOD, Enum.Material.Wood, true)
	piece("LidBand", Vector3.new(3.05, 0.25, 2.3), CFrame.new(0, 0.82, -1.1), GOLD, Enum.Material.Metal, true)
	model.Parent = Workspace

	local hinge = CFrame.new(0, 1.8, 1.1)
	local t0 = os.clock()
	local burst = false
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		local rise = math.clamp(t / 0.5, 0, 1)
		local lift = CFrame.new(0, -2.2 * (1 - rise) ^ 2, 0)
		local open = math.clamp((t - 0.6) / 0.35, 0, 1)
		local angle = math.rad(115) * (1 - (1 - open) ^ 3)
		local fade = math.clamp((t - 3.2) / 0.6, 0, 1)
		for _, info in pieces do
			local offset = if info.lid then hinge * CFrame.Angles(angle, 0, 0) * info.offset else info.offset
			info.part.CFrame = base * lift * offset
			info.part.LocalTransparencyModifier = fade
		end
		if open > 0 and not burst then
			burst = true
			Audio.play("claim")
			FxController.glitter(position + Vector3.new(0, 2, 0), GOLD, 60)
			FxController.cameraKick(3, false)
		end
		if fade >= 1 then
			connection:Disconnect()
			model:Destroy()
		end
	end)
end

-- A tall golden beam over the mound that fades in when the player gets close.
local function watchBeam(beam: BasePart, position: Vector3)
	if beamConnection then
		beamConnection:Disconnect()
	end
	beamConnection = RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local distance = if root then (Vector3.new(root.Position.X, position.Y, root.Position.Z) - position).Magnitude else math.huge
		local target = if distance < BEAM_RANGE then 0.45 else 1
		beam.Transparency += (target - beam.Transparency) * 0.08
	end)
end

local function build(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "TreasureMound"
	local base = CFrame.new(position)
	local dirt = part(model, "Dirt", Enum.PartType.Ball, Vector3.new(6, 2.2, 6), base * CFrame.new(0, 0.2, 0), Color3.fromRGB(150, 110, 70), Enum.Material.Ground)
	for i, offset in { Vector3.new(-1.2, 1, 0.6), Vector3.new(1, 0.9, -0.8), Vector3.new(0.2, 1.2, 1.1) } do
		part(model, "Stone" .. i, Enum.PartType.Block, Vector3.one * 0.7, base * CFrame.new(offset) * CFrame.Angles(i, i * 2, 0), Color3.fromRGB(120, 112, 130), Enum.Material.Slate)
	end
	-- A red X marks the spot.
	for _, angle in { 45, -45 } do
		part(model, "Mark", Enum.PartType.Block, Vector3.new(0.5, 0.1, 3.4), base * CFrame.new(0, 1.35, 0) * CFrame.Angles(0, math.rad(angle), 0), Color3.fromRGB(230, 60, 60), Enum.Material.Neon)
	end
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	sparkle.Size = NumberSequence.new(0.6, 0)
	sparkle.Lifetime = NumberRange.new(1, 1.6)
	sparkle.Rate = 5
	sparkle.Speed = NumberRange.new(1.5, 3)
	sparkle.SpreadAngle = Vector2.new(40, 40)
	sparkle.LightEmission = 1
	sparkle.Parent = dirt
	local beam = part(model, "Beam", Enum.PartType.Cylinder, Vector3.new(60, 1.6, 1.6), base * CFrame.new(0, 31, 0) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Neon)
	beam.Transparency = 1
	beam.CastShadow = false
	watchBeam(beam, position)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = L("Graben")
	prompt.ObjectText = L("Schatz")
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = Config.Maps.digRange
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = dirt
	prompt.Triggered:Connect(function()
		if digging then
			return
		end
		digging = true
		local ok, success, err = pcall(function()
			return Net.func("DigTreasure"):InvokeServer()
		end)
		digging = false
		if ok and success then
			chestReveal(position)
		else
			hud.showError(err)
		end
	end)
	model.PrimaryPart = dirt
	model.Parent = Workspace
	return model
end

local function refresh(state: any)
	local spot = if state and state.maps then state.maps.spot else 0
	if spot == shownSpot then
		return
	end
	shownSpot = spot
	if mound then
		mound:Destroy()
		mound = nil
	end
	if beamConnection then
		beamConnection:Disconnect()
		beamConnection = nil
	end
	local info = Config.Maps.spots[spot]
	if info then
		mound = build(info.position)
	end
end

function TreasureController.start(hudController: any)
	hud = hudController
	ClientState.Changed:Connect(refresh)
	refresh(ClientState.data)
end

return TreasureController
