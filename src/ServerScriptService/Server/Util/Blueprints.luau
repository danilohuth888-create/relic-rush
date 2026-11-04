--!strict
-- What each tycoon build looks like on a plot. Builds are created at runtime in the plot's
-- local frame (plot floor centre, floor top at y = 0.6, local -Z faces the plaza) and live in
-- PlotN.Builds.<id>; the gallery also adds Pedestal13-16 to PlotN.Pedestals.
-- Layout: buttons stand on the side strips (x = ±16.5), pedestals in the 4×3 grid, the gallery
-- dais along the back wall, decoration in the front strip around the spawn point.

local TweenService = game:GetService("TweenService")

local C = Color3.fromRGB
local GOLD = C(255, 200, 80)
local STONE = C(222, 212, 196)
local STONE_DARK = C(184, 172, 158)
local WOOD = C(132, 94, 72)
local WARM = C(255, 190, 110)
local CRYSTAL = C(120, 230, 255)
local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local ON_CORNER = CFrame.Angles(math.rad(45), 0, math.atan(1 / math.sqrt(2)))

type At = (x: number, y: number, z: number) -> CFrame
type Maker = (folder: Instance, at: At, accent: Color3, plot: Model) -> ()

local function P(parent: Instance, name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, extra: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in extra or {} do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function cyl(parent: Instance, name: string, height: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?, extra: { [string]: any }?): Part
	return P(parent, name, CYL, Vector3.new(height, diameter, diameter), cf * UPRIGHT, color, material, extra)
end

local function light(part: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = part
end

local DECOR = { CanCollide = false, CastShadow = false }

local MAKERS: { [string]: Maker } = {
	-- Warm lanterns on the side walls.
	lanterns = function(folder, at)
		for i, pos in { { -19.2, -8 }, { 19.2, -8 }, { -19.2, 12 }, { 19.2, 12 } } do
			P(folder, "Post", BLOCK, Vector3.new(0.5, 4, 0.5), at(pos[1], 5.6, pos[2]), WOOD)
			P(folder, "Cap", BLOCK, Vector3.new(1.4, 0.3, 1.4), at(pos[1], 8.9, pos[2]), WOOD)
			local lamp = P(folder, "Lamp", BALL, Vector3.one * 1.1, at(pos[1], 8.1, pos[2]), WARM, Enum.Material.Neon, DECOR)
			if i <= 2 then
				light(lamp, WARM, 16, 1.1)
			end
		end
	end,
	-- Gold border around the carpet and a runner from the entrance to the pedestals.
	carpet = function(folder, at)
		for _, z in { -12, 18 } do
			P(folder, "Border", BLOCK, Vector3.new(33, 0.12, 0.6), at(0, 0.68, z), GOLD, Enum.Material.Metal, DECOR)
		end
		for _, x in { -16.3, 16.3 } do
			P(folder, "Border", BLOCK, Vector3.new(0.6, 0.12, 30), at(x, 0.68, 3), GOLD, Enum.Material.Metal, DECOR)
		end
		P(folder, "Runner", BLOCK, Vector3.new(5, 0.1, 9), at(0, 0.66, -16.5), C(190, 40, 70), Enum.Material.Fabric, DECOR)
		P(folder, "RunnerTrim", BLOCK, Vector3.new(5.6, 0.08, 9.2), at(0, 0.64, -16.5), GOLD, Enum.Material.Metal, DECOR)
	end,
	-- A coin fountain in the front-left corner.
	fountain = function(folder, at, accent)
		local c = at(-11, 0, -15)
		cyl(folder, "Basin", 1.2, 7, c * CFrame.new(0, 1.2, 0), STONE_DARK)
		cyl(folder, "Water", 0.2, 6, c * CFrame.new(0, 1.75, 0), C(110, 200, 255), Enum.Material.Glass, { Transparency = 0.3, CanCollide = false })
		cyl(folder, "Column", 3.2, 1.2, c * CFrame.new(0, 3.2, 0), STONE)
		cyl(folder, "Bowl", 0.6, 3.4, c * CFrame.new(0, 4.9, 0), STONE)
		local coin = P(folder, "Coin", CYL, Vector3.new(0.4, 1.8, 1.8), c * CFrame.new(0, 6.1, 0), GOLD, Enum.Material.Neon, DECOR)
		coin:AddTag("SpinSlow")
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(GOLD, accent)
		sparkle.Size = NumberSequence.new(0.4, 0)
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Rate = 6
		sparkle.Speed = NumberRange.new(2, 4)
		sparkle.SpreadAngle = Vector2.new(30, 30)
		sparkle.LightEmission = 1
		sparkle.Parent = coin
	end,
	-- Two guardian statues flanking the entrance.
	statues = function(folder, at, accent)
		for _, x in { -6.5, 6.5 } do
			P(folder, "Plinth", BLOCK, Vector3.new(2.6, 1.2, 2.6), at(x, 1.2, -18.4), STONE_DARK)
			P(folder, "Body", BLOCK, Vector3.new(1.8, 3.4, 1.4), at(x, 3.5, -18.4), STONE)
			P(folder, "Head", BLOCK, Vector3.new(1.4, 1.4, 1.4), at(x, 5.9, -18.4), STONE)
			P(folder, "Eyes", BLOCK, Vector3.new(1, 0.25, 0.1), at(x, 6, -19.12), accent, Enum.Material.Neon, DECOR)
			P(folder, "Spear", BLOCK, Vector3.new(0.25, 6.5, 0.25), at(x + (if x < 0 then 1.2 else -1.2), 4.4, -18.6), GOLD, Enum.Material.Metal)
		end
	end,
	-- A glass display case with crystals in the front-right corner.
	vitrines = function(folder, at, accent)
		local c = at(10.5, 0, -15)
		P(folder, "Plinth", BLOCK, Vector3.new(6, 1.4, 3.6), c * CFrame.new(0, 1.3, 0), WOOD)
		P(folder, "Glass", BLOCK, Vector3.new(5.6, 3.2, 3.2), c * CFrame.new(0, 3.6, 0), C(220, 240, 255), Enum.Material.Glass, { Transparency = 0.55 })
		P(folder, "Frame", BLOCK, Vector3.new(6, 0.3, 3.6), c * CFrame.new(0, 5.35, 0), GOLD, Enum.Material.Metal)
		for i, x in { -1.6, 0, 1.6 } do
			P(folder, "Crystal", BLOCK, Vector3.one * (0.9 + i * 0.15), c * CFrame.new(x, 3.2, 0) * ON_CORNER, if i == 2 then accent else CRYSTAL, Enum.Material.Neon, DECOR)
		end
	end,
	-- A crystal chandelier floating above the pedestals.
	chandelier = function(folder, at, accent)
		local c = at(0, 14, 2)
		cyl(folder, "Ring", 0.5, 9, c, GOLD, Enum.Material.Metal, DECOR)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			P(folder, "Drop", BLOCK, Vector3.new(0.5, 1.6, 0.5), c * CFrame.new(math.sin(a) * 4.2, -1.1, math.cos(a) * 4.2) * ON_CORNER, if i % 2 == 0 then CRYSTAL else accent, Enum.Material.Neon, DECOR)
		end
		local heart = P(folder, "Heart", BLOCK, Vector3.one * 2, c * CFrame.new(0, -1.5, 0) * ON_CORNER, CRYSTAL, Enum.Material.Neon, DECOR)
		light(heart, CRYSTAL, 26, 1.3)
	end,
	-- A raised gallery along the back wall with four extra pedestals (slots 13-16).
	gallery = function(folder, at, accent, plot)
		P(folder, "Step", BLOCK, Vector3.new(30, 0.7, 1.4), at(0, 0.95, 12.2), STONE_DARK)
		P(folder, "Dais", BLOCK, Vector3.new(30, 1.4, 5.6), at(0, 1.3, 15.7), STONE)
		P(folder, "Edge", BLOCK, Vector3.new(30, 0.15, 0.3), at(0, 2.05, 13.0), accent, Enum.Material.Neon, DECOR)
		local pedestals = plot:FindFirstChild("Pedestals") :: Instance
		for i, x in { -10.5, -3.5, 3.5, 10.5 } do
			local slot = 12 + i
			local ped = Instance.new("Model")
			ped.Name = "Pedestal" .. slot
			ped:SetAttribute("Slot", slot)
			ped:SetAttribute("Runtime", true)
			local base = at(x, 2, 15.8)
			cyl(ped, "Foot", 0.6, 4.6, base * CFrame.new(0, 0.3, 0), STONE_DARK)
			cyl(ped, "Base", 2.6, 3.6, base * CFrame.new(0, 1.3, 0), STONE)
			cyl(ped, "Rim", 0.35, 4, base * CFrame.new(0, 2.75, 0), GOLD, Enum.Material.Metal)
			P(ped, "Top", BLOCK, Vector3.one, base * CFrame.new(0, 3.4, 0), GOLD, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
			ped.Parent = pedestals
		end
	end,
	-- The treasury crown floating above the golden arch.
	crown = function(folder, at, accent)
		local c = at(0, 18.5, -20)
		cyl(folder, "Band", 1.4, 6, c, GOLD, Enum.Material.Metal, DECOR)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			P(folder, "Spike", BLOCK, Vector3.new(0.7, 2.2, 0.7), c * CFrame.new(math.sin(a) * 2.7, 1.6, math.cos(a) * 2.7), GOLD, Enum.Material.Metal, DECOR)
			P(folder, "Jewel", BALL, Vector3.one * 0.7, c * CFrame.new(math.sin(a) * 2.7, 2.9, math.cos(a) * 2.7), if i % 2 == 0 then accent else CRYSTAL, Enum.Material.Neon, DECOR)
		end
		local gem = P(folder, "Gem", BLOCK, Vector3.one * 1.6, c * CFrame.new(0, 1, 0) * ON_CORNER, accent, Enum.Material.Neon, DECOR)
		light(gem, GOLD, 22, 1.2)
	end,
}

-- Grows a freshly bought build into place.
local function animateIn(folder: Instance)
	for _, part in folder:GetDescendants() do
		if part:IsA("BasePart") then
			local size, transparency = part.Size, part.Transparency
			part.Size = size * 0.2
			part.Transparency = 1
			TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = size, Transparency = transparency }):Play()
		end
	end
end

local Blueprints = {}

-- Creates the visuals of every owned build that is missing and removes those not owned.
function Blueprints.sync(plot: Model, owned: { [string]: boolean }, animate: boolean)
	local floor = plot:FindFirstChild("Floor") :: BasePart?
	if not floor then
		return
	end
	local cf = floor.CFrame
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	-- The banner carries the plot's accent colour (its original colour, before any VIP gold).
	local banner = plot:FindFirstChild("Banner") :: BasePart?
	local accent = if banner then (banner:GetAttribute("BaseColor") :: Color3?) or banner.Color else C(200, 170, 255)
	local root = plot:FindFirstChild("Builds") or Instance.new("Folder")
	root.Name = "Builds"
	root.Parent = plot
	for id, maker in MAKERS do
		local existing = root:FindFirstChild(id)
		if owned[id] and not existing then
			local folder = Instance.new("Model")
			folder.Name = id
			maker(folder, at, accent, plot)
			folder.Parent = root
			if animate then
				animateIn(folder)
			end
		elseif not owned[id] and existing then
			existing:Destroy()
		end
	end
	if not owned.gallery then
		local pedestals = plot:FindFirstChild("Pedestals")
		for _, ped in (if pedestals then pedestals:GetChildren() else {}) do
			if ped:GetAttribute("Runtime") then
				ped:Destroy()
			end
		end
	end
end

-- World position of a build's visuals, for effects (nil for builds without own visuals).
function Blueprints.position(plot: Model, id: string): Vector3?
	local root = plot:FindFirstChild("Builds")
	local folder = root and root:FindFirstChild(id)
	if folder and folder:IsA("Model") then
		return folder:GetPivot().Position
	end
	return nil
end

return Blueprints
