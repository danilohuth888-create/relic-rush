--!strict
-- Renders the local player's personal relic pickups, collects them (prompt tap, key or simply
-- walking into them) and animates every floating relic in the world.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local RelicVisuals = require(ReplicatedStorage.Shared.RelicVisuals)

type Pickup = { model: Model, beacon: BasePart, base: CFrame, phase: number, busy: boolean }

local player = Players.LocalPlayer
local RelicController = {}

local hud: any
local folder: Folder
local pickups: { [string]: Pickup } = {}
local floating: { [Model]: CFrame } = {}
local spinning: { [Instance]: CFrame } = {}

local collectSound = Instance.new("Sound")
collectSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
collectSound.Volume = 0.6
collectSound.Parent = SoundService

local function burst(model: Model)
	local start = model:GetPivot()
	local t0 = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local a = math.min((os.clock() - t0) / 0.35, 1)
		model:PivotTo(start * CFrame.new(0, a * 3, 0))
		model:ScaleTo(1 + a * 0.8)
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = a
			end
		end
		if a >= 1 then
			connection:Disconnect()
			model:Destroy()
		end
	end)
end

local function remove(id: string, collected: boolean)
	local pickup = pickups[id]
	if not pickup then
		return
	end
	pickups[id] = nil
	pickup.beacon:Destroy()
	if collected then
		burst(pickup.model)
	else
		pickup.model:Destroy()
	end
end

local function tryCollect(id: string)
	local pickup = pickups[id]
	if not pickup or pickup.busy then
		return
	end
	pickup.busy = true
	local ok, success, relicId = pcall(function()
		return Net.func("Collect"):InvokeServer(id)
	end)
	if ok and success == true then
		local def = RelicDefs.byId[relicId] or RelicDefs.byId[pickup.model.Name]
		remove(id, true)
		SoundService:PlayLocalSound(collectSound)
		if def then
			hud.relicCollected(def)
		end
	else
		pickup.busy = false
	end
end

local function add(info: any)
	remove(info.id, false)
	local def = RelicDefs.byId[info.relicId]
	if not def then
		return
	end
	local model = RelicVisuals.build(def, { effects = true })
	local base = CFrame.new(info.position + Vector3.new(0, 2.5, 0))
	model:PivotTo(base)

	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(16, 0.7, 0.7)
	beacon.CFrame = CFrame.new(info.position + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Color = Config.Rarities[def.rarity].color
	beacon.Material = Enum.Material.Neon
	beacon.Transparency = 0.65
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.CastShadow = false
	beacon.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Einsammeln"
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.CollectRange
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function()
		tryCollect(info.id)
	end)

	model.Parent = folder
	pickups[info.id] = { model = model, beacon = beacon, base = base, phase = math.random() * math.pi * 2, busy = false }
end

local function track(tag: string, store: { [any]: CFrame })
	local function added(inst: Instance)
		if inst:IsA("Model") then
			store[inst] = inst:GetPivot()
		elseif inst:IsA("BasePart") then
			store[inst] = inst.CFrame
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(added)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
		store[inst] = nil
	end)
	for _, inst in CollectionService:GetTagged(tag) do
		added(inst)
	end
end

local lastAutoCheck = 0
local function step()
	local t = os.clock()
	for _, pickup in pickups do
		local bob = math.sin(t * 2 + pickup.phase) * 0.4
		pickup.model:PivotTo(pickup.base * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * 1.2 + pickup.phase, 0))
	end

	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for model, base in floating do
		if (base.Position - eye).Magnitude < 90 then
			model:PivotTo(base * CFrame.new(0, math.sin(t * 1.6) * 0.3, 0) * CFrame.Angles(0, t * 0.8, 0))
		end
	end
	for inst, base in spinning do
		local cf = base * CFrame.new(0, math.sin(t * 0.7) * 1.2, 0) * CFrame.Angles(0, t * 0.25, 0)
		if inst:IsA("Model") then
			inst:PivotTo(cf)
		elseif inst:IsA("BasePart") then
			inst.CFrame = cf
		end
	end

	-- Walking into a relic collects it too, which is the easiest input on every device.
	if t - lastAutoCheck > 0.15 then
		lastAutoCheck = t
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			for id, pickup in pickups do
				if not pickup.busy and (pickup.base.Position - root.Position).Magnitude < Config.AutoCollectRange + 2.5 then
					task.spawn(tryCollect, id)
				end
			end
		end
	end
end

function RelicController.start(hudController: any)
	hud = hudController
	folder = Instance.new("Folder")
	folder.Name = "LocalRelics"
	folder.Parent = Workspace

	track("FloatingRelic", floating)
	track("SpinSlow", spinning)
	RunService.RenderStepped:Connect(step)

	Net.event("SpawnAdded").OnClientEvent:Connect(add)
	task.spawn(function()
		local ok, list = pcall(function()
			return Net.func("GetSpawns"):InvokeServer()
		end)
		if ok and type(list) == "table" then
			for _, info in list do
				add(info)
			end
		end
	end)
end

return RelicController
