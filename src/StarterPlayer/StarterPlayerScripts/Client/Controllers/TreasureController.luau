--!strict
-- Draws the dig mound of the player's open treasure map (only this player sees it) with a
-- "Graben" prompt. The server checks the map and the distance and pays the treasure.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)

local TreasureController = {}

local hud: any
local mound: Model? = nil
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

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Graben"
	prompt.ObjectText = "Schatz"
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
		if not (ok and success) then
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
