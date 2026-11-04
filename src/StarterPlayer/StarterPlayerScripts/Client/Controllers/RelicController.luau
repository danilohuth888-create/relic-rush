--!strict
-- Draws the local player's guardian spirits (each carries a relic), moves them smoothly to the
-- positions the server sends, and plays the catch feedback the server reports. The server
-- simulates and catches; this client never decides anything. Also animates every floating
-- relic and slowly spinning decoration in the world.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local RelicVisuals = require(ReplicatedStorage.Shared.RelicVisuals)
local Audio = require(script.Parent.Parent.Audio)
local FxController = require(script.Parent.FxController)

type Spirit = {
	model: Model,
	body: BasePart,
	relic: Model,
	status: TextLabel,
	target: Vector3,
	current: Vector3,
	facing: Vector3,
	state: string,
	phase: number,
}

local RelicController = {}

local hud: any
local folder: Folder
local spirits: { [string]: Spirit } = {}
local floating: { [Model]: CFrame } = {}
local spinning: { [Instance]: CFrame } = {}

local STATUS_TEXT = { idle = "", flee = "!", tired = "💤" }

local function ghostPart(parent: Instance, name: string, size: number, color: Color3, material: Enum.Material, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * size
	p.Color = color
	p.Material = material
	p.Transparency = transparency
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function build(def: RelicDefs.RelicDef): (Model, BasePart, Model, TextLabel)
	local rarity = Config.Rarities[def.rarity]
	local tint = rarity.color:Lerp(Color3.new(1, 1, 1), 0.45)
	local model = Instance.new("Model")
	model.Name = "Spirit_" .. def.id
	local body = ghostPart(model, "Body", 2.8, tint, Enum.Material.ForceField, 0)
	local core = ghostPart(model, "Core", 1.5, rarity.color, Enum.Material.Neon, 0.35)
	core:SetAttribute("Offset", Vector3.zero)
	for _, x in { -0.45, 0.45 } do
		local eye = ghostPart(model, "Eye", 0.42, Color3.fromRGB(40, 30, 70), Enum.Material.SmoothPlastic, 0)
		eye:SetAttribute("Offset", Vector3.new(x, 0.25, -1.2))
	end
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.6, 0.6)
	top.Parent = body
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.6, 0.6)
	bottom.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(tint, rarity.color)
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.Lifetime = 0.45
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = body
	if RelicVisuals.rarityRank(def.rarity) >= 2 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 9
		light.Brightness = 1.2
		light.Parent = core
	end
	model.PrimaryPart = body

	local relic = RelicVisuals.build(def, { effects = true })
	relic:ScaleTo(0.7)
	relic.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(40, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	local status = Instance.new("TextLabel")
	status.Size = UDim2.fromScale(1, 1)
	status.BackgroundTransparency = 1
	status.Text = ""
	status.TextScaled = true
	status.Font = Enum.Font.FredokaOne
	status.TextColor3 = Color3.fromRGB(255, 230, 120)
	status.TextStrokeTransparency = 0.2
	status.Parent = gui
	gui.Parent = body
	return model, body, relic, status
end

local function remove(id: string)
	local spirit = spirits[id]
	if spirit then
		spirits[id] = nil
		spirit.model:Destroy()
	end
end

-- The spirit dissolves upwards when caught.
local function burst(spirit: Spirit)
	local model = spirit.model
	local start = model:GetPivot()
	local t0 = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local a = math.min((os.clock() - t0) / 0.4, 1)
		model:PivotTo(start * CFrame.new(0, a * 3, 0))
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

local function add(info: any)
	local def = RelicDefs.byId[info.relicId]
	if not def or typeof(info.position) ~= "Vector3" then
		return
	end
	local existing = spirits[info.id]
	if existing then
		-- Same spirit, new relic (luck rune): rebuild the look, keep the position.
		info.position = existing.current
		remove(info.id)
	end
	local model, body, relic, status = build(def)
	model.Parent = folder
	spirits[info.id] = {
		model = model,
		body = body,
		relic = relic,
		status = status,
		target = info.position,
		current = info.position,
		facing = Vector3.new(0, 0, -1),
		state = "idle",
		phase = math.random() * math.pi * 2,
	}
end

local function onCaught(id: any, relicId: any, isNew: any, position: any)
	local spirit = spirits[id]
	local def = RelicDefs.byId[relicId]
	if spirit then
		spirits[id] = nil
		burst(spirit)
	end
	if not def then
		return
	end
	-- Feedback grows with rarity: brighter chime, then glitter, then a camera kick.
	local rank = RelicVisuals.rarityRank(def.rarity)
	Audio.collect(rank)
	local where = if typeof(position) == "Vector3" then position else Vector3.zero
	FxController.glitter(where, Config.Rarities[def.rarity].color, if rank >= 3 then 30 + rank * 15 else 18)
	if rank >= 4 then
		FxController.cameraKick(5, rank >= 5)
	end
	hud.relicCollected(def, isNew == true)
end

local function onPositions(batch: any)
	if type(batch) ~= "table" then
		return
	end
	for id, info in batch do
		local spirit = spirits[id]
		if spirit and type(info) == "table" and typeof(info[1]) == "Vector3" then
			spirit.target = info[1]
			local state = if type(info[2]) == "string" then info[2] else "idle"
			if state ~= spirit.state then
				spirit.state = state
				spirit.status.Text = STATUS_TEXT[state] or ""
			end
		end
	end
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

local function step(dt: number)
	local t = os.clock()
	local blend = 1 - math.exp(-10 * dt)
	for _, spirit in spirits do
		local previous = spirit.current
		spirit.current = previous:Lerp(spirit.target, blend)
		local moved = Vector3.new(spirit.current.X - previous.X, 0, spirit.current.Z - previous.Z)
		if moved.Magnitude > 0.01 then
			spirit.facing = spirit.facing:Lerp(moved.Unit, 0.2)
		end
		local bob = math.sin(t * 3 + spirit.phase) * 0.25
		local cf = CFrame.lookAt(spirit.current, spirit.current + spirit.facing) * CFrame.new(0, bob, 0)
		if spirit.state == "tired" then
			cf *= CFrame.Angles(0, 0, math.sin(t * 6) * 0.2)
		end
		for _, part in spirit.model:GetChildren() do
			if part:IsA("BasePart") then
				part.CFrame = cf * CFrame.new(part:GetAttribute("Offset") :: Vector3? or Vector3.zero)
			end
		end
		spirit.relic:PivotTo(cf * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, t * 1.5 + spirit.phase, 0))
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
end

-- Nearest spirit to a position, for Lumi's guidance.
function RelicController.nearest(position: Vector3): Vector3?
	local best, bestDistance = nil, math.huge
	for _, spirit in spirits do
		local distance = (spirit.current - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = spirit.current, distance
		end
	end
	return best
end

function RelicController.start(hudController: any)
	hud = hudController
	folder = Instance.new("Folder")
	folder.Name = "LocalRelics"
	folder.Parent = Workspace

	track("FloatingRelic", floating)
	track("SpinSlow", spinning)
	RunService.Heartbeat:Connect(step)

	Net.event("SpawnAdded").OnClientEvent:Connect(add)
	Net.event("Spirits").OnClientEvent:Connect(onPositions)
	Net.event("Caught").OnClientEvent:Connect(onCaught)
	task.spawn(function()
		local ok, list = pcall(function()
			return Net.func("GetSpawns"):InvokeServer()
		end)
		if ok and type(list) == "table" then
			for _, info in list do
				if not spirits[info.id] then
					add(info)
				end
			end
		end
	end)
end

return RelicController
