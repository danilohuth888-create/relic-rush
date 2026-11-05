-- Dresses Aetheria with scenery: rim rocks, waterfalls, meadow patches, grass tufts, flowers,
-- bushes, blossom trees, path lamps, plot hedges, a denser Whisper Forest, overgrown ruins and
-- floating particles. Purely visual: nothing here has a name that scripts look up.
-- Run in Studio's Edit DataModel after BuildAetheria.luau. It rebuilds Workspace.Aetheria.Decor
-- from scratch and reads the live layout (plots, paths, spawns) so it never covers gameplay spots.

local Workspace = game:GetService("Workspace")

local C = Color3.fromRGB
local PAL = {
	grass = C(126, 200, 112),
	grassLight = C(150, 214, 118),
	grassDark = C(92, 166, 96),
	grassDeep = C(70, 140, 92),
	rock = C(104, 94, 136),
	rockDark = C(74, 64, 104),
	rockLight = C(138, 128, 168),
	stone = C(222, 212, 196),
	stoneDark = C(184, 172, 158),
	wood = C(132, 94, 72),
	woodDark = C(96, 66, 56),
	leaf = C(98, 192, 122),
	leafDark = C(62, 150, 112),
	leafTeal = C(70, 180, 170),
	blossom = C(255, 176, 214),
	lilac = C(200, 170, 255),
	water = C(110, 200, 255),
	foam = C(225, 245, 255),
	lamp = C(255, 214, 140),
	ruin = C(96, 104, 140),
	ruinLight = C(130, 138, 170),
	ruinGlow = C(90, 140, 255),
	vine = C(60, 150, 100),
	mushroom = C(120, 230, 255),
}
local FLOWERS = { C(255, 140, 190), C(255, 220, 110), C(250, 250, 255), C(190, 150, 255), C(120, 210, 255) }
local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local SMOOTH, NEON, GLASS, SLATE = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Glass, Enum.Material.Slate
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local ON_CORNER = CFrame.Angles(math.rad(45), 0, math.atan(1 / math.sqrt(2)))
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local ISLAND_R = 210
local FOREST = Vector3.new(0, 0, 140)
local FOREST_R = 62
local RUINS = Vector3.new(140, 0, 118)
local WATERFALLS = { 25, 150, 210, 300 } -- degrees, measured from +Z towards +X; between the plots
local DIG_SPOTS = {
	Vector3.new(-150, 0, 40), Vector3.new(150, 0, -35), Vector3.new(-42, 0, 172), Vector3.new(46, 0, 178),
	Vector3.new(55, 0, -172), Vector3.new(-95, 0, -150), Vector3.new(95, 0, 72), Vector3.new(-125, 0, 118),
}
local HILLS = { Vector3.new(-122, 0, 145), Vector3.new(171, 0, -99), Vector3.new(-60, 0, 195), Vector3.new(0, 0, -198) }
-- The houses are planned in plan units and built this much larger (Shared/Builds.Scale).
local S = require(game:GetService("ReplicatedStorage").Shared.Builds).Scale

local root = Workspace:WaitForChild("Aetheria")
local rng = Random.new(7)
local count = 0

local function P(parent, name, shape, size, cf, color, material, solid)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or SMOOTH
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanTouch = false
	p.CanQuery = solid == true
	p.CastShadow = solid == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	count += 1
	return p
end

local function cyl(parent, name, height, diameter, cf, color, material, solid)
	return P(parent, name, CYL, Vector3.new(height, diameter, diameter), cf * UPRIGHT, color, material, solid)
end

local function wedge(parent, size, cf, color)
	local w = Instance.new("WedgePart")
	w.Name = "Blade"
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = SMOOTH
	w.Anchored = true
	w.CanCollide = false
	w.CanTouch = false
	w.CanQuery = false
	w.CastShadow = false
	w.Parent = parent
	count += 1
	return w
end

local function folder(parent, name)
	local f = Instance.new("Model")
	f.Name = name
	f.Parent = parent
	return f
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rimPoint(deg: number, r: number): Vector3
	local a = math.rad(deg)
	return Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

-- Keep-out zones read from the live layout -------------------------------------------------
local plotCenters = {}
for _, plot in root.Plots:GetChildren() do
	local floor = plot:FindFirstChild("Floor")
	if floor then
		table.insert(plotCenters, { cf = floor.CFrame, pos = flat(floor.Position) })
	end
end
local pathParts = {}
for _, p in root.Paths:GetChildren() do
	if p:IsA("BasePart") then
		table.insert(pathParts, p)
	end
end
local spawnSpots = {}
for _, s in root.RelicSpawns:GetChildren() do
	table.insert(spawnSpots, flat(s.Position))
end
local forestTrees = {}
for _, m in root.WhisperForest:GetChildren() do
	local trunk = m:FindFirstChild("Trunk") or m:FindFirstChild("Stem")
	if trunk then
		table.insert(forestTrees, flat(trunk.Position))
	end
end
local placed = {} -- solid decor already put down, so pieces do not overlap

local function onPath(pos: Vector3, margin: number): boolean
	for _, p in pathParts do
		local rel = p.CFrame:PointToObjectSpace(Vector3.new(pos.X, p.Position.Y, pos.Z))
		if math.abs(rel.X) < p.Size.X / 2 + margin and math.abs(rel.Z) < p.Size.Z / 2 + margin then
			return true
		end
	end
	return false
end

-- True when a piece of radius r at pos keeps clear of every gameplay area.
local function free(pos: Vector3, r: number, opts: { forest: boolean?, ruins: boolean?, rim: boolean? }?): boolean
	opts = opts or {}
	pos = flat(pos)
	local dist = pos.Magnitude
	if dist + r > ISLAND_R - (if opts.rim then -2 else 12) then
		return false
	end
	if dist < 58 + r then
		return false -- plaza
	end
	for _, plot in plotCenters do
		local rel = plot.cf:PointToObjectSpace(Vector3.new(pos.X, plot.cf.Position.Y, pos.Z))
		if math.abs(rel.X) < 24 * S + r and rel.Z > -26 * S - r and rel.Z < 52 * S + r then
			return false -- yard and house (plan units: the house reaches z = 46, towers 50)
		end
	end
	if onPath(pos, r + 1.5) then
		return false
	end
	local fd = (pos - FOREST).Magnitude
	if not opts.forest and fd < FOREST_R + 4 + r then
		return false
	end
	if opts.forest then
		if fd > FOREST_R - r or fd < 15 + r then
			return false
		end
		if math.abs(pos.X) < 7 + r and pos.Z < 128 then
			return false -- path into the forest
		end
		for _, t in forestTrees do
			if (t - pos).Magnitude < 4 + r then
				return false
			end
		end
	end
	local rd = (pos - RUINS).Magnitude
	if not opts.ruins and rd < 36 + r then
		return false
	end
	if opts.ruins then
		if rd > 34 - r or rd < 15 + r then
			return false
		end
		local toCenter = (Vector3.zero - RUINS).Unit
		if (pos - RUINS).Unit:Dot(toCenter) > 0.75 then
			return false -- keep the approach to the portal open
		end
	end
	for _, d in DIG_SPOTS do
		if (d - pos).Magnitude < 9 + r then
			return false
		end
	end
	for _, s in spawnSpots do
		if (s - pos).Magnitude < 6 + r then
			return false
		end
	end
	for _, h in HILLS do
		if (h - pos).Magnitude < 18 + r then
			return false
		end
	end
	for _, w in WATERFALLS do
		if (rimPoint(w, 196) - pos).Magnitude < 14 + r then
			return false
		end
	end
	for _, q in placed do
		if (q.pos - pos).Magnitude < q.r + r then
			return false
		end
	end
	return true
end

local function claim(pos: Vector3, r: number)
	table.insert(placed, { pos = flat(pos), r = r })
end

-- Tries random spots from sample() until n pieces are placed (or the tries run out).
local function scatter(n: number, r: number, sample: () -> Vector3, opts, build: (Vector3) -> ())
	local done, tries = 0, 0
	while done < n and tries < n * 40 do
		tries += 1
		local pos = sample()
		if free(pos, r, opts) then
			claim(pos, r)
			build(pos)
			done += 1
		end
	end
	return done
end

local function meadowSample(): Vector3
	local a = rng:NextNumber() * math.pi * 2
	local r = 60 + math.sqrt(rng:NextNumber()) * 135
	return Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
end

local function forestSample(): Vector3
	local a = rng:NextNumber() * math.pi * 2
	local r = 15 + rng:NextNumber() * 46
	return FOREST + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
end

local function ruinsSample(): Vector3
	local a = rng:NextNumber() * math.pi * 2
	local r = 15 + rng:NextNumber() * 18
	return RUINS + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
end

-- Builders --------------------------------------------------------------------------------
local function rock(parent, pos: Vector3, size: number, palette)
	local m = folder(parent, "Rock")
	local yaw = CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	local base = CFrame.new(pos) * yaw
	P(m, "Big", BLOCK, Vector3.new(size, size * 0.7, size * 0.85), base * CFrame.new(0, size * 0.2, 0) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.3, 0.3)), pick(palette), SLATE, true)
	if size > 3 then
		local s = size * rng:NextNumber(0.4, 0.6)
		P(m, "Small", BLOCK, Vector3.new(s, s * 0.8, s), base * CFrame.new(size * 0.55, s * 0.2, size * 0.2) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber() * 3, rng:NextNumber(-0.4, 0.4)), pick(palette), SLATE, false)
	end
end

local function tuft(parent, pos: Vector3, color: Color3, scale: number)
	local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	for i = 0, 2 do
		local h = rng:NextNumber(1.1, 1.8) * scale
		wedge(parent, Vector3.new(0.15, h, 0.7 * scale), base * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(0, h / 2, 0.25 * scale) * CFrame.Angles(-0.25, 0, 0), color:Lerp(PAL.grassLight, rng:NextNumber(0, 0.35)))
	end
end

local function flowerPatch(parent, pos: Vector3, n: number)
	local color = pick(FLOWERS)
	for _ = 1, n do
		local off = Vector3.new(rng:NextNumber(-2.2, 2.2), 0, rng:NextNumber(-2.2, 2.2))
		local h = rng:NextNumber(0.5, 0.9)
		P(parent, "Stem", BLOCK, Vector3.new(0.12, h, 0.12), CFrame.new(pos + off + Vector3.new(0, h / 2, 0)), PAL.grassDark)
		P(parent, "Bloom", BALL, Vector3.one * rng:NextNumber(0.55, 0.8), CFrame.new(pos + off + Vector3.new(0, h + 0.15, 0)), color)
	end
end

local function bush(parent, pos: Vector3, size: number, color: Color3)
	local yaw = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	P(parent, "Bush", BALL, Vector3.new(size, size * 0.75, size * 0.9), yaw * CFrame.new(0, size * 0.22, 0), color)
	P(parent, "Bush", BALL, Vector3.new(size * 0.7, size * 0.6, size * 0.7), yaw * CFrame.new(size * 0.42, size * 0.12, size * 0.1), color:Lerp(PAL.grassLight, 0.2))
	P(parent, "Bush", BALL, Vector3.new(size * 0.6, size * 0.55, size * 0.6), yaw * CFrame.new(-size * 0.3, size * 0.4, -size * 0.15), color:Lerp(PAL.grassDeep, 0.25))
end

local function tree(parent, pos: Vector3, leaves: Color3, scale: number)
	local m = folder(parent, "Tree")
	local h = rng:NextNumber(7, 10) * scale
	cyl(m, "Trunk", h, 1.6 * scale, CFrame.new(pos + Vector3.new(0, h / 2, 0)), PAL.wood, SMOOTH, true)
	local d = rng:NextNumber(8, 11) * scale
	P(m, "Canopy", BALL, Vector3.one * d, CFrame.new(pos + Vector3.new(0, h + d * 0.2, 0)), leaves, SMOOTH, false).CastShadow = true
	P(m, "CanopyTop", BALL, Vector3.one * d * 0.6, CFrame.new(pos + Vector3.new(d * 0.15, h + d * 0.6, -d * 0.1)), leaves:Lerp(Color3.new(1, 1, 1), 0.15))
	P(m, "CanopySide", BALL, Vector3.one * d * 0.55, CFrame.new(pos + Vector3.new(-d * 0.35, h + d * 0.05, d * 0.15)), leaves:Lerp(PAL.grassDeep, 0.2))
end

local function lamp(parent, pos: Vector3, lit: boolean)
	local m = folder(parent, "Lamp")
	cyl(m, "Post", 7, 0.6, CFrame.new(pos + Vector3.new(0, 3.5, 0)), PAL.woodDark, SMOOTH, true)
	cyl(m, "Foot", 0.6, 1.4, CFrame.new(pos + Vector3.new(0, 0.3, 0)), PAL.stoneDark)
	local glow = P(m, "Lantern", BLOCK, Vector3.new(1.2, 1.5, 1.2), CFrame.new(pos + Vector3.new(0, 7.6, 0)), PAL.lamp, NEON)
	P(m, "Cap", BLOCK, Vector3.new(1.7, 0.4, 1.7), CFrame.new(pos + Vector3.new(0, 8.55, 0)), PAL.woodDark)
	if lit then
		local light = Instance.new("PointLight")
		light.Color = PAL.lamp
		light.Range = 14
		light.Brightness = 0.7
		light.Shadows = false
		light.Parent = glow
	end
end

local function emitter(parent, name, size: Vector3, cf: CFrame, props)
	local holder = P(parent, name, BLOCK, size, cf, PAL.foam, SMOOTH)
	holder.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	for k, v in props do
		e[k] = v
	end
	e.Parent = holder
	return e
end

-- Build -----------------------------------------------------------------------------------
local old = root:FindFirstChild("Decor")
if old then
	old:Destroy()
end
local decor = folder(root, "Decor")

-- Meadow colour patches, so the big lawn is not one flat green.
local patches = folder(decor, "MeadowPatches")
for i = 1, 14 do
	local pos = meadowSample()
	local d = rng:NextNumber(26, 46)
	if pos.Magnitude + d / 2 < ISLAND_R - 14 then
		cyl(patches, "Patch" .. i, 0.1, d, CFrame.new(pos + Vector3.new(0, 0.03, 0)), pick({ PAL.grassLight, PAL.grassDark, C(140, 206, 106), C(112, 190, 118) }))
	end
end
task.wait()

-- Waterfalls pouring over the rim into the clouds.
local falls = folder(decor, "Waterfalls")
for i, deg in WATERFALLS do
	local m = folder(falls, "Waterfall" .. i)
	local out = rimPoint(deg, 1).Unit
	local face = CFrame.lookAt(rimPoint(deg, 194), rimPoint(deg, 300)) -- local -Z points off the island
	cyl(m, "Pond", 0.3, 15, CFrame.new(rimPoint(deg, 194) + Vector3.new(0, 0.1, 0)), PAL.water, GLASS).Transparency = 0.15
	cyl(m, "PondRim", 0.25, 17, CFrame.new(rimPoint(deg, 194) + Vector3.new(0, 0.02, 0)), PAL.stoneDark)
	P(m, "Stream", BLOCK, Vector3.new(6, 0.2, 21), face * CFrame.new(0, 0.12, -10.5), PAL.water, GLASS).Transparency = 0.15
	for s = 0, 3 do
		local sheet = P(m, "Sheet" .. s, BLOCK, Vector3.new(7 + s * 1.5, 40, 0.6), face * CFrame.new(0, -20 - s * 40, -21.3 - s * 0.6), PAL.water:Lerp(PAL.foam, s * 0.15), GLASS)
		sheet.Transparency = 0.2 + s * 0.2
	end
	for _, side in { -1, 1 } do
		rock(m, rimPoint(deg, 200) + face.RightVector * side * 6.5, rng:NextNumber(3.5, 5), { PAL.rock, PAL.rockLight })
	end
	emitter(m, "Mist", Vector3.new(6, 1, 1), face * CFrame.new(0, -1, -21.5), {
		Texture = SMOKE,
		Color = ColorSequence.new(PAL.foam),
		LightEmission = 0.3,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(2.5, 3.5),
		Rate = 14,
		Speed = NumberRange.new(10, 16),
		EmissionDirection = Enum.NormalId.Bottom,
		Acceleration = Vector3.new(0, -14, 0) + out * 2,
		SpreadAngle = Vector2.new(8, 8),
	})
	emitter(m, "Sparkle", Vector3.new(14, 1, 14), CFrame.new(rimPoint(deg, 194) + Vector3.new(0, 0.6, 0)), {
		Texture = SPARKLE,
		Color = ColorSequence.new(PAL.foam),
		LightEmission = 1,
		Size = NumberSequence.new(0.35),
		Lifetime = NumberRange.new(1, 2),
		Rate = 4,
		Speed = NumberRange.new(0.5, 1),
	})
end
task.wait()

-- Crystals growing out of the cliff and vines hanging over the edge.
local cliff = folder(decor, "Cliff")
for i = 1, 22 do
	local deg = rng:NextNumber() * 360
	local upper = i % 2 == 0
	local r = if upper then 204 else 169
	local y = if upper then rng:NextNumber(-20, -8) else rng:NextNumber(-44, -28)
	local base = CFrame.lookAt(rimPoint(deg, r) + Vector3.new(0, y, 0), rimPoint(deg, r + 10) + Vector3.new(0, y - 4, 0))
	local color = if i % 3 == 0 then PAL.lilac else C(110, 230, 240)
	local h = rng:NextNumber(4, 7)
	P(cliff, "Crystal", BLOCK, Vector3.new(1.6, 1.6, h), base * CFrame.new(0, 0, -h / 2) * CFrame.Angles(0, 0, math.rad(45)), color, NEON)
	P(cliff, "CrystalSmall", BLOCK, Vector3.new(1, 1, h * 0.6), base * CFrame.Angles(math.rad(20), math.rad(25), 0) * CFrame.new(0, 0, -h * 0.3) * CFrame.Angles(0, 0, math.rad(45)), color, NEON)
end
for i = 1, 40 do
	local deg = rng:NextNumber() * 360
	local nearFall = false
	for _, w in WATERFALLS do
		if math.abs(((deg - w + 180) % 360) - 180) < 5 then
			nearFall = true
		end
	end
	if not nearFall then
		local len = rng:NextNumber(5, 14)
		P(cliff, "Vine", CYL, Vector3.new(len, 0.45, 0.45), CFrame.new(rimPoint(deg, 213.4) + Vector3.new(0, -8 - len / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), pick({ PAL.vine, PAL.leafDark }))
		P(cliff, "VineLeaf", BALL, Vector3.one * 1.2, CFrame.new(rimPoint(deg, 213.6) + Vector3.new(0, -8 - len, 0)), PAL.leaf)
	end
end
task.wait()

-- Rocks along the rim, plus a few boulders on the meadow.
local rocks = folder(decor, "Rocks")
local rimRocks = 0
for deg = 0, 359, 7 do
	local pos = rimPoint(deg + rng:NextNumber(-2, 2), rng:NextNumber(201, 206))
	local size = rng:NextNumber(3, 7)
	if free(pos, size * 0.5, { rim = true }) then
		claim(pos, size * 0.5)
		rock(rocks, pos, size, { PAL.rock, PAL.rockDark, PAL.rockLight })
		rimRocks += 1
	end
end
scatter(14, 3, meadowSample, nil, function(pos)
	rock(rocks, pos, rng:NextNumber(2.5, 5), { PAL.rock, PAL.rockLight, PAL.stoneDark })
end)
task.wait()

-- Blossom and leaf trees on the open meadow.
local trees = folder(decor, "MeadowTrees")
scatter(16, 6, meadowSample, nil, function(pos)
	tree(trees, pos, pick({ PAL.leaf, PAL.leafDark, PAL.blossom, PAL.lilac, PAL.leafTeal }), rng:NextNumber(0.9, 1.2))
end)
task.wait()

-- Bushes, flowers and grass tufts on the meadow.
local plants = folder(decor, "MeadowPlants")
scatter(26, 2.5, meadowSample, nil, function(pos)
	bush(plants, pos, rng:NextNumber(3, 4.5), pick({ PAL.leaf, PAL.leafDark, PAL.grassDark }))
end)
scatter(22, 2.5, meadowSample, nil, function(pos)
	flowerPatch(plants, pos, rng:NextInteger(4, 6))
end)
task.wait()
scatter(90, 0.8, meadowSample, nil, function(pos)
	tuft(plants, pos, pick({ PAL.grassDark, PAL.grassDeep, PAL.grass }), rng:NextNumber(0.9, 1.3))
end)
task.wait()

-- Lamps along the paths (outside the plaza) -------------------------------------------------
local lamps = folder(decor, "PathLamps")
local lampCount = 0
for _, p in pathParts do
	local half = p.Size.Z / 2
	local step = if p.Name == "RuinsPath" or p.Name == "ForestPath" then 15 else 22
	local z = -half + 6
	local side = 1
	while z < half - 4 do
		local pos = flat((p.CFrame * CFrame.new(side * (p.Size.X / 2 + 1.6), 0, z)).Position)
		local nearPlot = false
		for _, plot in plotCenters do
			local rel = plot.cf:PointToObjectSpace(Vector3.new(pos.X, plot.cf.Position.Y, pos.Z))
			if math.abs(rel.X) < 24 * S and math.abs(rel.Z) < 30 * S then
				nearPlot = true -- keeps the owner sign at the plot entrance readable
			end
		end
		if pos.Magnitude > 60 and (pos - FOREST).Magnitude > 20 and not nearPlot then
			lamp(lamps, pos, lampCount % 3 == 0)
			lampCount += 1
		end
		side = -side
		z += step
	end
end
task.wait()

-- Hedges framing every treasury plot (outside its walls) -------------------------------------
local hedges = folder(decor, "PlotHedges")
for _, plot in plotCenters do
	local function at(x, z) -- plan units
		return (plot.cf * CFrame.new(x * S, 0, z * S)).Position * Vector3.new(1, 0, 1)
	end
	for x = -14, 14, 7 do
		bush(hedges, at(x, 51), 4.4, PAL.leafDark)
	end
	for _, x in { -23, 23 } do
		for _, z in { 8, 16, 24, 32 } do
			bush(hedges, at(x, z), 4, PAL.leafDark)
		end
	end
end
task.wait()

-- Plaza: flower beds and benches between the paths ------------------------------------------
local plaza = folder(decor, "PlazaGarden")
for deg = 0, 359, 30 do
	local pos = rimPoint(deg, 56)
	if not onPath(pos, 4) and (pos - Vector3.new(30, 0, -24)).Magnitude > 10 then
		local face = CFrame.lookAt(pos, Vector3.zero)
		P(plaza, "Bed", BLOCK, Vector3.new(7, 0.8, 3), face * CFrame.new(0, 0.4, 0), PAL.stoneDark, SMOOTH, true)
		P(plaza, "Soil", BLOCK, Vector3.new(6.2, 0.1, 2.2), face * CFrame.new(0, 0.82, 0), C(110, 84, 70))
		local color = pick(FLOWERS)
		for k = -2, 2 do
			P(plaza, "Bloom", BALL, Vector3.one * 0.9, face * CFrame.new(k * 1.2, 1.3, rng:NextNumber(-0.4, 0.4)), color)
			P(plaza, "Leaves", BALL, Vector3.new(1.1, 0.6, 1.1), face * CFrame.new(k * 1.2 + 0.5, 1, 0.3), PAL.leaf)
		end
	end
end
task.wait()

-- Whisper Forest: undergrowth, logs, glowing flowers and fireflies ---------------------------
local forest = folder(decor, "ForestUndergrowth")
local forestOpts = { forest = true }
scatter(10, 4, forestSample, forestOpts, function(pos)
	tree(forest, pos, pick({ PAL.leafDark, PAL.leafTeal, PAL.leaf }), rng:NextNumber(1, 1.3))
end)
scatter(22, 2.2, forestSample, forestOpts, function(pos)
	bush(forest, pos, rng:NextNumber(2.8, 4), pick({ PAL.leafDark, PAL.leafTeal }))
end)
scatter(8, 2.5, forestSample, forestOpts, function(pos)
	rock(forest, pos, rng:NextNumber(2, 4), { PAL.rock, PAL.rockLight })
end)
scatter(3, 4, forestSample, forestOpts, function(pos)
	P(forest, "Log", CYL, Vector3.new(7, 1.8, 1.8), CFrame.new(pos + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, rng:NextNumber() * 3, 0), PAL.woodDark, SMOOTH, true)
end)
scatter(12, 1.5, forestSample, forestOpts, function(pos)
	for k = 1, 3 do
		local off = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		P(forest, "GlowStem", BLOCK, Vector3.new(0.12, 0.8, 0.12), CFrame.new(pos + off + Vector3.new(0, 0.4, 0)), PAL.leafDark)
		P(forest, "GlowBloom", BALL, Vector3.one * 0.5, CFrame.new(pos + off + Vector3.new(0, 0.9, 0)), if k == 2 then PAL.lilac else PAL.mushroom, NEON)
	end
end)
scatter(60, 0.8, forestSample, forestOpts, function(pos)
	tuft(forest, pos, pick({ PAL.grassDeep, PAL.leafDark }), rng:NextNumber(1, 1.5))
end)
emitter(forest, "Fireflies", Vector3.new(110, 8, 110), CFrame.new(FOREST + Vector3.new(0, 5, 0)), {
	Texture = SPARKLE,
	Color = ColorSequence.new(C(220, 255, 140)),
	LightEmission = 1,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) }),
	Lifetime = NumberRange.new(4, 7),
	Rate = 12,
	Speed = NumberRange.new(0.3, 1),
	SpreadAngle = Vector2.new(180, 180),
	RotSpeed = NumberRange.new(-30, 30),
})
task.wait()

-- Forgotten Ruins: broken columns, rubble, vines, blue torches -------------------------------
local ruins = folder(decor, "RuinsOvergrowth")
local ruinOpts = { ruins = true }
-- Dusky slate ground with broken floor tiles sets the ruins apart from the meadow.
cyl(ruins, "Ground", 0.2, 72, CFrame.new(RUINS + Vector3.new(0, 0.06, 0)), C(176, 160, 136))
cyl(ruins, "GroundEdge", 0.16, 78, CFrame.new(RUINS + Vector3.new(0, 0.04, 0)), C(110, 168, 110))
for ring = 0, 1 do
	local r = 17 + ring * 6
	for k = 0, 13 + ring * 4 do
		local a = k / (14 + ring * 4) * math.pi * 2 + ring * 0.2
		local pos = RUINS + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
		if rng:NextNumber() < 0.75 and not onPath(pos, 2) then
			P(ruins, "Tile", BLOCK, Vector3.new(rng:NextNumber(3, 4.5), 0.25, rng:NextNumber(3, 4.5)), CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, a + rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.03, 0.03)), pick({ C(150, 156, 180), C(128, 136, 166) }), SLATE)
		end
	end
end
scatter(6, 2.5, ruinsSample, ruinOpts, function(pos)
	local h = rng:NextNumber(3, 9)
	local yaw = CFrame.Angles(0, rng:NextNumber() * 3, 0)
	P(ruins, "Column", BLOCK, Vector3.new(2.6, h, 2.6), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * yaw, PAL.ruin, SLATE, true)
	P(ruins, "ColumnCap", BLOCK, Vector3.new(3.2, 0.8, 3.2), CFrame.new(pos + Vector3.new(0, h + 0.2, 0)) * yaw * CFrame.Angles(0.1, 0, 0.08), PAL.ruinLight, SLATE)
	P(ruins, "Vine", BLOCK, Vector3.new(0.3, h * 0.8, 1.2), CFrame.new(pos + Vector3.new(0, h * 0.45, 0)) * yaw * CFrame.new(1.35, 0, 0), PAL.vine)
end)
scatter(10, 1.6, ruinsSample, ruinOpts, function(pos)
	local s = rng:NextNumber(1.2, 2.6)
	P(ruins, "Rubble", BLOCK, Vector3.new(s, s * 0.7, s * 1.2), CFrame.new(pos + Vector3.new(0, s * 0.3, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber() * 3, rng:NextNumber(-0.4, 0.4)), pick({ PAL.ruin, PAL.ruinLight }), SLATE)
end)
scatter(25, 0.8, ruinsSample, ruinOpts, function(pos)
	tuft(ruins, pos, PAL.grassDeep, 1.1)
end)
local face = CFrame.lookAt(RUINS, Vector3.zero)
for _, side in { -1, 1 } do
	local base = face * CFrame.new(side * 11, 0, -4)
	P(ruins, "TorchStand", BLOCK, Vector3.new(1, 5, 1), base * CFrame.new(0, 2.5, 0), PAL.ruinLight, SLATE, true)
	P(ruins, "TorchBowl", BLOCK, Vector3.new(1.8, 0.6, 1.8), base * CFrame.new(0, 5.2, 0), PAL.ruin, SLATE)
	local flame = P(ruins, "Flame", BLOCK, Vector3.new(1.2, 0.4, 1.2), base * CFrame.new(0, 5.7, 0), PAL.ruinGlow, NEON)
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = SPARKLE
	fire.Color = ColorSequence.new(C(140, 190, 255), PAL.ruinGlow)
	fire.LightEmission = 1
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	fire.Lifetime = NumberRange.new(0.6, 1.1)
	fire.Rate = 18
	fire.Speed = NumberRange.new(2, 4)
	fire.SpreadAngle = Vector2.new(12, 12)
	fire.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = PAL.ruinGlow
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = flame
end
emitter(ruins, "Wisps", Vector3.new(50, 10, 50), CFrame.new(RUINS + Vector3.new(0, 6, 0)), {
	Texture = SPARKLE,
	Color = ColorSequence.new(C(130, 170, 255)),
	LightEmission = 1,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.6), NumberSequenceKeypoint.new(1, 0) }),
	Lifetime = NumberRange.new(4, 6),
	Rate = 6,
	Speed = NumberRange.new(0.5, 1.5),
	SpreadAngle = Vector2.new(180, 180),
	Acceleration = Vector3.new(0, 0.4, 0),
})
task.wait()

-- Floating motes over the plaza.
emitter(decor, "PlazaMotes", Vector3.new(100, 14, 100), CFrame.new(0, 9, 0), {
	Texture = SPARKLE,
	Color = ColorSequence.new(C(230, 210, 255), C(160, 240, 255)),
	LightEmission = 1,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 0) }),
	Lifetime = NumberRange.new(5, 8),
	Rate = 8,
	Speed = NumberRange.new(0.3, 0.8),
	SpreadAngle = Vector2.new(180, 180),
	Acceleration = Vector3.new(0, 0.3, 0),
})

local lights = 0
for _, d in decor:GetDescendants() do
	if d:IsA("Light") then
		lights += 1
	end
end
return ("Decor built: %d parts, %d rim rocks, %d lamps, %d lights"):format(count, rimRocks, lampCount, lights)
