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
-- Roof parts never block the camera or clicks; the owner's client fades them while inside.
local ROOF = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
local ROOF_TAG = "TreasuryRoof"

-- The treasury building: walls 12 studs high (top at y = 12.6), a gabled roof with its ridge
-- along local Z at y = 20, eaves overhanging the side walls.
local WALL_TOP = 12.6
local RIDGE = 20
local SLOPE = math.atan((RIDGE - WALL_TOP) / 20)
local WINDOW_Z = { -10, 0, 10 }

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = Enum.Material.SmoothPlastic
	w.Anchored = true
	w.Parent = parent
	return w
end

local function roofColor(accent: Color3): Color3
	return accent:Lerp(C(60, 50, 90), 0.45)
end

local function tagRoof(part: BasePart)
	part:AddTag(ROOF_TAG)
end

local MAKERS: { [string]: Maker } = {
	-- Warm lamp posts in the four corners of the hall.
	lanterns = function(folder, at)
		for i, pos in { { -17.6, -16 }, { 17.6, -16 }, { -17.6, 15 }, { 17.6, 15 } } do
			P(folder, "Post", BLOCK, Vector3.new(0.5, 5, 0.5), at(pos[1], 3.1, pos[2]), WOOD)
			P(folder, "Foot", BLOCK, Vector3.new(1.2, 0.4, 1.2), at(pos[1], 0.8, pos[2]), WOOD)
			P(folder, "Cap", BLOCK, Vector3.new(1.4, 0.3, 1.4), at(pos[1], 6.95, pos[2]), WOOD)
			local lamp = P(folder, "Lamp", BALL, Vector3.one * 1.1, at(pos[1], 6.2, pos[2]), WARM, Enum.Material.Neon, DECOR)
			if i <= 2 then
				light(lamp, WARM, 16, 1.1)
			end
		end
	end,
	-- The side walls rise to full height with three window openings each.
	walls = function(folder, at)
		for _, side in { -1, 1 } do
			local x = side * 19.2
			P(folder, "WallBand", BLOCK, Vector3.new(1.6, 1.4, 36.2), at(x, 4.3, 0.3), STONE_DARK)
			P(folder, "WallTop", BLOCK, Vector3.new(1.6, 2.6, 36.2), at(x, 11.3, 0.3), STONE_DARK)
			P(folder, "Trim", BLOCK, Vector3.new(2.1, 0.4, 36.8), at(x, 12.8, 0.3), STONE)
			for _, range in { { -17.8, -12 }, { -8, -2 }, { 2, 8 }, { 12, 18.4 } } do
				P(folder, "Pier", BLOCK, Vector3.new(1.6, 5, range[2] - range[1]), at(x, 7.5, (range[1] + range[2]) / 2), STONE_DARK)
			end
			for _, z in WINDOW_Z do
				P(folder, "Sill", BLOCK, Vector3.new(2.1, 0.3, 4.6), at(x, 5.15, z), STONE)
			end
			P(folder, "CornerCap", BLOCK, Vector3.new(2.6, 3.4, 2.6), at(side * 19, 11.3, -19), STONE_DARK)
		end
		P(folder, "BackTrim", BLOCK, Vector3.new(40.4, 0.4, 2.1), at(0, 12.8, 19.2), STONE)
	end,
	-- A stone front with a wide doorway, a keystone and two hanging banners.
	gate = function(folder, at, accent)
		for _, side in { -1, 1 } do
			P(folder, "Facade", BLOCK, Vector3.new(8.3, 12, 1.2), at(side * 13.65, 6.6, -19.6), STONE_DARK)
			P(folder, "Plinth", BLOCK, Vector3.new(8.3, 1, 1.6), at(side * 13.65, 1.1, -19.6), STONE)
			P(folder, "DoorTrim", BLOCK, Vector3.new(0.4, 11, 0.3), at(side * 9.6, 6.1, -20.3), GOLD, Enum.Material.Metal, DECOR)
			P(folder, "Banner", BLOCK, Vector3.new(3.4, 5, 0.2), at(side * 15.4, 9.2, -20.3), accent, nil, DECOR)
			P(folder, "BannerRod", BLOCK, Vector3.new(4, 0.3, 0.3), at(side * 15.4, 11.8, -20.35), GOLD, Enum.Material.Metal, DECOR)
		end
		P(folder, "Lintel", BLOCK, Vector3.new(19.4, 1.2, 1.4), at(0, 12, -19.6), STONE)
		P(folder, "Keystone", BLOCK, Vector3.new(2, 1.6, 0.4), at(0, 12, -20.4), accent, Enum.Material.Neon, DECOR)
	end,
	-- The rune hall: gables front and back and a tiled roof with a golden ridge.
	hall2 = function(folder, at, accent)
		local roof = roofColor(accent)
		local rise = RIDGE - WALL_TOP
		for _, z in { -19.6, 19.2 } do
			for _, side in { -1, 1 } do
				wedge(folder, "Gable", Vector3.new(1.2, rise, 20), at(side * 10, WALL_TOP + rise / 2, z) * CFrame.Angles(0, -side * math.pi / 2, 0), STONE_DARK)
			end
		end
		local face = CFrame.Angles(0, math.pi / 2, 0)
		P(folder, "RoseRing", CYL, Vector3.new(0.3, 4.4, 4.4), at(0, 15.4, -20.25) * face, GOLD, Enum.Material.Metal, DECOR)
		P(folder, "RoseWindow", CYL, Vector3.new(0.3, 3.6, 3.6), at(0, 15.4, -20.4) * face, accent, Enum.Material.Neon, DECOR)
		local run = 21.6
		for _, side in { -1, 1 } do
			local slab = at(side * run / 2, RIDGE - run / 2 * math.tan(SLOPE) + 0.45, 0) * CFrame.Angles(0, 0, -side * SLOPE)
			tagRoof(P(folder, "Roof", BLOCK, Vector3.new(run / math.cos(SLOPE), 0.9, 43.4), slab, roof, nil, ROOF))
			for _, d in { -7.5, -2.5, 2.5, 7.5 } do
				tagRoof(P(folder, "Tiles", BLOCK, Vector3.new(0.6, 0.25, 43.4), slab * CFrame.new(d, 0.55, 0), roof:Lerp(Color3.new(0, 0, 0), 0.18), nil, ROOF))
			end
		end
		tagRoof(P(folder, "Ridge", CYL, Vector3.new(43.8, 1.2, 1.2), at(0, RIDGE + 0.6, 0) * face, GOLD, Enum.Material.Metal, ROOF))
	end,
	-- Stained glass in the six wall windows.
	windows = function(folder, at, accent)
		for _, side in { -1, 1 } do
			for _, z in WINDOW_Z do
				P(folder, "Glass", BLOCK, Vector3.new(0.3, 4.8, 3.8), at(side * 19.2, 7.6, z), accent:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Material.Glass, { Transparency = 0.25 })
				P(folder, "MullionV", BLOCK, Vector3.new(0.5, 4.8, 0.25), at(side * 19.2, 7.6, z), GOLD, Enum.Material.Metal, DECOR)
				P(folder, "MullionH", BLOCK, Vector3.new(0.5, 0.25, 3.8), at(side * 19.2, 7.6, z), GOLD, Enum.Material.Metal, DECOR)
			end
		end
	end,
	-- Two round towers at the back corners with pointed roofs and flags.
	towers = function(folder, at, accent)
		local roof = roofColor(accent)
		for _, side in { -1, 1 } do
			local base = at(side * 20.5, 0.6, 19.5)
			cyl(folder, "Tower", 22, 6, base * CFrame.new(0, 11, 0), STONE)
			cyl(folder, "Band", 0.8, 6.5, base * CFrame.new(0, 12, 0), STONE_DARK)
			cyl(folder, "Crown", 1.2, 7, base * CFrame.new(0, 21.6, 0), STONE_DARK)
			local out = (base.Position - at(0, 0.6, 0).Position) * Vector3.new(1, 0, 1)
			for _, y in { 7, 16 } do
				local p = base.Position + Vector3.new(0, y, 0) + out.Unit * 2.95
				P(folder, "Slit", BLOCK, Vector3.new(0.8, 2.2, 0.3), CFrame.lookAt(p, p + out), accent, Enum.Material.Neon, DECOR)
			end
			for i, d in { 7.4, 6, 4.6, 3.2, 1.8 } do
				cyl(folder, "Cone", 1.8, d, base * CFrame.new(0, 22.2 + 0.9 + (i - 1) * 1.8, 0), roof)
			end
			P(folder, "Pole", BLOCK, Vector3.new(0.25, 4, 0.25), base * CFrame.new(0, 33.2, 0), GOLD, Enum.Material.Metal, DECOR)
			P(folder, "Flag", BLOCK, Vector3.new(0.15, 1.6, 2.6), base * CFrame.new(0, 34.3, 1.4), accent, nil, DECOR)
		end
	end,
	-- The aether hall: a glass cupola with a crystal on the ridge and golden eaves.
	hall3 = function(folder, at, accent)
		tagRoof(P(folder, "CupolaBase", BLOCK, Vector3.new(6, 2.4, 6), at(0, RIDGE + 1, 2), STONE, nil, ROOF))
		tagRoof(P(folder, "Dome", BALL, Vector3.one * 6.4, at(0, RIDGE + 2.4, 2), accent:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Glass, { Transparency = 0.35, CanCollide = false, CanQuery = false, CastShadow = false }))
		local crystal = P(folder, "Crystal", BLOCK, Vector3.one * 2.2, at(0, RIDGE + 3, 2) * ON_CORNER, CRYSTAL, Enum.Material.Neon, ROOF)
		tagRoof(crystal)
		light(crystal, CRYSTAL, 20, 1)
		tagRoof(P(folder, "Finial", BLOCK, Vector3.new(0.5, 3, 0.5), at(0, RIDGE + 6.8, 2), GOLD, Enum.Material.Metal, ROOF))
		for _, side in { -1, 1 } do
			tagRoof(P(folder, "Eave", BLOCK, Vector3.new(0.6, 0.6, 43.6), at(side * 21.4, 12, 0), GOLD, Enum.Material.Metal, ROOF))
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
	-- The treasury crown floating above the front gable.
	crown = function(folder, at, accent)
		local c = at(0, 22.4, -20)
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
