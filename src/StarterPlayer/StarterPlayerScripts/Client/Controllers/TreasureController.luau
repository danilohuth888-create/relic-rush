--!strict
-- Draws the treasures of the player's Treasure Isle visit (only this player sees them) with a
-- "Graben" prompt each. How easy a treasure is to spot depends on its tier: easy ones glitter
-- under a small light beam, hidden ones only show up close, secret ones barely shimmer until the
-- player stands next to them. The server picks the spots, checks the distance and pays; this
-- client then lets a chest burst open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Net = require(ReplicatedStorage.Shared.Net)
local Audio = require(script.Parent.Parent.Audio)
local FxController = require(script.Parent.FxController)

local GOLD = Color3.fromRGB(255, 205, 90)
local WOOD = Color3.fromRGB(140, 92, 60)
local DIRT = Color3.fromRGB(150, 110, 70)

-- Per tier: mound size, sparkle rate, and the distance from which the mound fades in
-- (nil = always visible).
local LOOK = {
	easy = { size = 6, sparkle = 6, showFrom = nil, beam = true, mark = true },
	hidden = { size = 4.4, sparkle = 2, showFrom = 30, beam = false, mark = false },
	secret = { size = 3.4, sparkle = 1, showFrom = 11, beam = false, mark = false },
}

local TreasureController = {}

local LANG = Locale.of(Players.LocalPlayer)
local function L(source: string, ...: any): string
	return Locale.format(LANG, source, ...)
end

type Mound = { model: Model, position: Vector3, fade: { BasePart }, showFrom: number?, emitter: ParticleEmitter }

local hud: any
local mounds: { [string]: Mound } = {}
local digging = false
local folder: Folder

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

local function removeMound(id: string)
	local mound = mounds[id]
	if mound then
		mounds[id] = nil
		mound.model:Destroy()
	end
end

local function build(id: string, tier: string, position: Vector3): Mound
	local look = LOOK[tier] or LOOK.easy
	local model = Instance.new("Model")
	model.Name = "Treasure_" .. id
	local base = CFrame.new(position - Vector3.new(0, 0.5, 0))
	local s = look.size
	local fade = {}
	local dirt = part(model, "Dirt", Enum.PartType.Ball, Vector3.new(s, s * 0.36, s), base * CFrame.new(0, 0.2, 0), DIRT, Enum.Material.Ground)
	table.insert(fade, dirt)
	for i, offset in { Vector3.new(-0.2, 0.17, 0.1), Vector3.new(0.17, 0.15, -0.13), Vector3.new(0.03, 0.2, 0.18) } do
		table.insert(fade, part(model, "Stone" .. i, Enum.PartType.Block, Vector3.one * s * 0.12, base * CFrame.new(offset * s) * CFrame.Angles(i, i * 2, 0), Color3.fromRGB(120, 112, 130), Enum.Material.Slate))
	end
	if look.mark then
		-- A red X marks the easy spots.
		for _, angle in { 45, -45 } do
			table.insert(fade, part(model, "Mark", Enum.PartType.Block, Vector3.new(0.5, 0.1, 3.4), base * CFrame.new(0, s * 0.22 + 0.1, 0) * CFrame.Angles(0, math.rad(angle), 0), Color3.fromRGB(230, 60, 60), Enum.Material.Neon))
		end
	end
	if look.beam then
		local beam = part(model, "Beam", Enum.PartType.Cylinder, Vector3.new(16, 0.9, 0.9), base * CFrame.new(0, 8.5, 0) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Neon)
		beam.Transparency = 0.55
		beam.CastShadow = false
	end
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	sparkle.Size = NumberSequence.new(if tier == "secret" then 0.35 else 0.6, 0)
	sparkle.Lifetime = NumberRange.new(1, 1.6)
	sparkle.Rate = look.sparkle
	sparkle.Speed = NumberRange.new(1, 2.5)
	sparkle.SpreadAngle = Vector2.new(40, 40)
	sparkle.LightEmission = 1
	sparkle.Parent = dirt

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = L("Graben")
	prompt.ObjectText = L("Schatz")
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = Config.Isle.digRange
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = dirt
	prompt.Triggered:Connect(function()
		if digging then
			return
		end
		digging = true
		local ok, success, err = pcall(function()
			return Net.func("DigTreasure"):InvokeServer(id)
		end)
		digging = false
		if ok and success then
			removeMound(id)
			chestReveal(position - Vector3.new(0, 0.5, 0))
		else
			hud.showError(if ok then err else "rate")
		end
	end)
	model.PrimaryPart = dirt
	model.Parent = folder
	return { model = model, position = position, fade = fade, showFrom = look.showFrom, emitter = sparkle }
end

local function onIsle(payload: any)
	for id in mounds do
		removeMound(id)
	end
	if type(payload) ~= "table" or type(payload.spots) ~= "table" then
		return
	end
	for _, spot in payload.spots do
		if type(spot) == "table" and type(spot.id) == "string" and typeof(spot.position) == "Vector3" then
			mounds[spot.id] = build(spot.id, tostring(spot.tier), spot.position)
		end
	end
end

-- Hidden and secret treasures fade in as the player gets close.
local function step()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, mound in mounds do
		local showFrom = mound.showFrom
		if showFrom then
			local distance = if root then (root.Position - mound.position).Magnitude else math.huge
			local visible = math.clamp((showFrom - distance) / (showFrom * 0.4), 0, 1)
			for _, p in mound.fade do
				p.LocalTransparencyModifier = 1 - visible
			end
			mound.emitter.Enabled = distance < showFrom * 1.6
		end
	end
end

function TreasureController.start(hudController: any)
	hud = hudController
	folder = Instance.new("Folder")
	folder.Name = "IsleTreasures"
	folder.Parent = Workspace
	Net.event("Isle").OnClientEvent:Connect(onIsle)
	RunService.Heartbeat:Connect(step)
end

return TreasureController
