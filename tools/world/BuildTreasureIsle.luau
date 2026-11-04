-- Builds the Treasure Isle (Workspace.TreasureIsle), the island a completed treasure map leads
-- to: a beach ring, a lagoon with a waterfall, the Eagle Rock with stepping stones, a hollow
-- ancient tree, a shipwreck, a ruined watchtower, a rock arch, palms and the return portal.
-- Run in Studio's Edit DataModel; it rebuilds Workspace.TreasureIsle from scratch.
--
-- Contract with the scripts (MapService, RelicSpawnService):
--   TreasureIsle.Arrival        part where visitors appear
--   TreasureIsle.ReturnPortal   part that gets the "back to Aetheria" prompt
--   TreasureIsle.DigSpots       parts named by id with attribute Tier = easy | hidden | secret
--   TreasureIsle.IsleSpawns     spirit spawn parts with SpawnId, Area = "Isle",
--                               Pool = easy | tricky | master, Trick ("" | dash | blink),
--                               RespawnSeconds
-- Treasures get harder to find with their value: easy ones lie in the open, hidden ones behind
-- rocks, ruins and bushes, secret ones behind the waterfall, on top of the Eagle Rock, inside
-- the hollow tree and in the shipwreck's hold.

local Workspace = game:GetService("Workspace")

local CENTER = Vector3.new(-1500, 0, 0)
local C = Color3.fromRGB
local PAL = {
	grass = C(140, 214, 120),
	grassDark = C(100, 180, 104),
	sand = C(250, 222, 160),
	sandDark = C(232, 198, 138),
	rock = C(196, 168, 140),
	rockDark = C(160, 132, 112),
	cliff = C(150, 120, 104),
	trunk = C(176, 132, 92),
	leaf = C(70, 184, 112),
	leafDark = C(48, 150, 96),
	wood = C(120, 82, 60),
	woodDark = C(88, 60, 46),
	water = C(90, 200, 240),
	foam = C(225, 245, 255),
	portal = C(120, 220, 255),
	gold = C(255, 200, 80),
	flower = C(255, 150, 190),
}
local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local SMOOTH, NEON, GLASS, SLATE, SAND, WOOD = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Glass, Enum.Material.Slate, Enum.Material.Sand, Enum.Material.Wood
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local HIDDEN = { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }
local rng = Random.new(11)
local count = 0

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(CENTER + Vector3.new(x, y, z))
end

local function P(parent, name, shape, size, cf, color, material, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or SMOOTH
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in extra or {} do
		p[k] = v
	end
	p.Parent = parent
	count += 1
	return p
end

local function cyl(parent, name, height, diameter, cf, color, material, extra)
	return P(parent, name, CYL, Vector3.new(height, diameter, diameter), cf * UPRIGHT, color, material, extra)
end

local function wedge(parent, name, size, cf, color, material)
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material or SMOOTH
	w.Anchored = true
	w.Parent = parent
	count += 1
	return w
end

local function folder(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local DECOR = { CanCollide = false, CastShadow = false, CanQuery = false }

local old = Workspace:FindFirstChild("TreasureIsle")
if old then
	old:Destroy()
end
local root = folder(Workspace, "TreasureIsle")

-- Island body ------------------------------------------------------------------------------
local body = folder(root, "Island")
cyl(body, "GrassTop", 8, 224, at(0, -4, 0), PAL.grass)
cyl(body, "Beach", 7.4, 256, at(0, -4, 0), PAL.sand, SAND)
cyl(body, "BeachEdge", 6, 262, at(0, -5.6, 0), PAL.sandDark, SAND)
for i, layer in { { 250, 18, -16 }, { 200, 24, -36 }, { 140, 26, -60 }, { 80, 24, -84 }, { 30, 18, -102 } } do
	cyl(body, "Rock" .. i, layer[2], layer[1], at(0, layer[3], 0), if i % 2 == 0 then PAL.rockDark else PAL.cliff, SLATE)
end
for i = 1, 8 do
	local a = i / 8 * math.pi * 2
	P(body, "Patch", CYL, Vector3.new(0.1, rng:NextNumber(24, 40), rng:NextNumber(24, 40)), at(math.sin(a) * 60, 0.03, math.cos(a) * 60) * UPRIGHT, PAL.grass:Lerp(PAL.grassDark, 0.5), SMOOTH, DECOR)
end
task.wait()

-- Helpers for scenery -----------------------------------------------------------------------
local scenery = folder(root, "Scenery")

local function palm(pos: Vector3, height: number, lean: number)
	local m = folder(scenery, "Palm")
	local yaw = rng:NextNumber() * math.pi * 2
	local p = CENTER + pos
	local dir = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	local segments = 5
	local prev = p
	for s = 1, segments do
		local t = s / segments
		local nextPoint = p + Vector3.new(0, height * t, 0) + dir * lean * t * t
		local mid = (prev + nextPoint) / 2
		local seg = P(m, "Trunk", CYL, Vector3.new((nextPoint - prev).Magnitude + 0.3, 1.5 - t * 0.4, 1.5 - t * 0.4), CFrame.lookAt(mid, nextPoint) * CFrame.Angles(0, math.rad(90), 0), PAL.trunk, WOOD)
		seg.CanCollide = s <= 2
		prev = nextPoint
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + yaw
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		wedge(m, "Leaf", Vector3.new(0.3, 1.2, 6), CFrame.lookAt(prev + out * 3 + Vector3.new(0, -0.6, 0), prev + out * 6 + Vector3.new(0, -2.2, 0)), if k % 2 == 0 then PAL.leaf else PAL.leafDark).CanCollide = false
	end
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		P(m, "Coconut", BALL, Vector3.one * 0.9, CFrame.new(prev + Vector3.new(math.cos(a) * 0.7, -0.7, math.sin(a) * 0.7)), PAL.woodDark, SMOOTH, DECOR)
	end
end

local function boulder(pos: Vector3, size: number)
	local yaw = CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber() * 3, rng:NextNumber(-0.2, 0.2))
	P(scenery, "Boulder", BLOCK, Vector3.new(size, size * 0.75, size * 0.9), CFrame.new(CENTER + pos + Vector3.new(0, size * 0.3, 0)) * yaw, if rng:NextNumber() < 0.5 then PAL.rock else PAL.rockDark, SLATE)
end

local function bush(pos: Vector3, size: number)
	local p = CENTER + pos
	P(scenery, "Bush", BALL, Vector3.new(size, size * 0.75, size), CFrame.new(p + Vector3.new(0, size * 0.25, 0)), PAL.leafDark, SMOOTH, DECOR)
	P(scenery, "Bush", BALL, Vector3.one * size * 0.65, CFrame.new(p + Vector3.new(size * 0.35, size * 0.2, size * 0.15)), PAL.leaf, SMOOTH, DECOR)
end

local function flowers(pos: Vector3)
	for _ = 1, 4 do
		local off = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		P(scenery, "Flower", BALL, Vector3.one * 0.7, CFrame.new(CENTER + pos + off + Vector3.new(0, 0.5, 0)), if rng:NextNumber() < 0.5 then PAL.flower else C(255, 230, 120), SMOOTH, DECOR)
	end
end

-- Arrival and return portal (south beach) -----------------------------------------------------
local arrival = P(root, "Arrival", CYL, Vector3.new(0.4, 12, 12), at(0, 0.1, 96) * UPRIGHT, PAL.portal, NEON, { Transparency = 0.4, CanCollide = false })
arrival.CastShadow = false
local portal = folder(root, "PortalArch")
local face = CFrame.lookAt(CENTER + Vector3.new(0, 0, 110), CENTER)
for _, x in { -6, 6 } do
	P(portal, "Pillar", BLOCK, Vector3.new(2.4, 14, 2.4), face * CFrame.new(x, 7, 0), PAL.rock, SLATE)
end
P(portal, "Lintel", BLOCK, Vector3.new(15, 2.4, 2.8), face * CFrame.new(0, 15, 0), PAL.rock, SLATE)
P(portal, "Keystone", BLOCK, Vector3.new(2, 2, 0.6), face * CFrame.new(0, 15, -1.5), PAL.gold, NEON)
P(root, "ReturnPortal", BLOCK, Vector3.new(9.6, 12.6, 0.4), face * CFrame.new(0, 7.3, 0), PAL.portal, NEON, { Transparency = 0.35, CanCollide = false })
for _, x in { -11, 11 } do
	local torch = face * CFrame.new(x, 0, 2)
	P(portal, "TorchPost", BLOCK, Vector3.new(0.8, 5, 0.8), torch * CFrame.new(0, 2.5, 0), PAL.wood, WOOD)
	local flame = P(portal, "Flame", BALL, Vector3.one * 1.2, torch * CFrame.new(0, 5.4, 0), C(255, 190, 90), NEON, DECOR)
	local light = Instance.new("PointLight")
	light.Color = C(255, 190, 110)
	light.Range = 14
	light.Parent = flame
end
task.wait()

-- Lagoon with a waterfall from the cliff (north-east) ------------------------------------------
local lagoon = folder(root, "Lagoon")
cyl(lagoon, "SandRim", 0.2, 30, at(40, 0.04, -2), PAL.sand, SAND)
cyl(lagoon, "Water", 0.3, 26, at(40, 0.1, -2), PAL.water, GLASS, { Transparency = 0.2, CanCollide = false })
P(lagoon, "Cliff", BLOCK, Vector3.new(30, 16, 14), at(42, 8, -24), PAL.cliff, SLATE)
P(lagoon, "CliffTop", BLOCK, Vector3.new(26, 4, 10), at(42, 17.5, -25), PAL.rock, SLATE)
P(lagoon, "CliffGrass", BLOCK, Vector3.new(30.4, 0.6, 14.4), at(42, 16.3, -24), PAL.grass)
-- The sheet stands two studs in front of the cliff: there is room to walk behind it.
for s = 0, 2 do
	local sheet = P(lagoon, "Fall" .. s, BLOCK, Vector3.new(9 - s, 5.4, 0.4), at(40, 13.6 - s * 5.2, -14.6), PAL.water:Lerp(PAL.foam, s * 0.15), GLASS, { Transparency = 0.25 + s * 0.05, CanCollide = false, CanQuery = false })
	sheet.CastShadow = false
end
local mist = P(lagoon, "Mist", BLOCK, Vector3.new(9, 1, 2), at(40, 0.6, -13), PAL.foam, SMOOTH, HIDDEN)
local spray = Instance.new("ParticleEmitter")
spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
spray.Color = ColorSequence.new(PAL.foam)
spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
spray.Lifetime = NumberRange.new(1.5, 2.5)
spray.Rate = 10
spray.Speed = NumberRange.new(2, 4)
spray.Shape = Enum.ParticleEmitterShape.Box
spray.Parent = mist
task.wait()

-- Eagle Rock: a tall pillar with stepping stones spiralling up (secret on top) -----------------
local eagle = folder(root, "EagleRock")
cyl(eagle, "Pillar", 26, 10, at(-55, 13, -30), PAL.cliff, SLATE)
cyl(eagle, "Top", 0.6, 11, at(-55, 26.2, -30), PAL.grass)
for k = 0, 9 do
	local a = math.rad(200 + k * 40)
	local y = 2 + k * 2.4
	P(eagle, "Step" .. k, BLOCK, Vector3.new(4, 1, 4), at(-55 + math.cos(a) * 7.5, y, -30 + math.sin(a) * 7.5) * CFrame.Angles(0, -a, 0), PAL.rock, SLATE)
end
task.wait()

-- The hollow ancient tree (secret inside) --------------------------------------------------------
local tree = folder(root, "HollowTree")
local treeCenter = Vector3.new(-30, 0, 45)
for k = 0, 9 do
	if k ~= 2 and k ~= 3 then -- the opening faces the arrival beach
		local a = k / 10 * math.pi * 2
		local p = CENTER + treeCenter + Vector3.new(math.cos(a) * 5.6, 8, math.sin(a) * 5.6)
		P(tree, "Bark", BLOCK, Vector3.new(3.8, 16, 1.6), CFrame.lookAt(p, CENTER + treeCenter + Vector3.new(0, 8, 0)), PAL.woodDark, WOOD)
	end
end
P(tree, "Roof", CYL, Vector3.new(1.2, 13, 13), at(treeCenter.X, 16.4, treeCenter.Z) * UPRIGHT, PAL.woodDark, WOOD)
for k, offset in { Vector3.new(0, 21, 0), Vector3.new(6, 19, 3), Vector3.new(-5, 19.5, -4), Vector3.new(2, 24, -3) } do
	P(tree, "Canopy", BALL, Vector3.one * (if k == 1 then 18 else 11), at(treeCenter.X + offset.X, offset.Y, treeCenter.Z + offset.Z), if k % 2 == 0 then PAL.leaf else PAL.leafDark, SMOOTH, { CanCollide = false })
end
local glow = P(tree, "InnerGlow", BALL, Vector3.one * 0.6, at(treeCenter.X, 10, treeCenter.Z), C(180, 255, 200), NEON, DECOR)
local inner = Instance.new("PointLight")
inner.Color = C(180, 255, 200)
inner.Range = 9
inner.Brightness = 0.8
inner.Parent = glow
task.wait()

-- Shipwreck on the west beach (secret in the hold) -------------------------------------------
local wreck = folder(root, "Shipwreck")
local hull = CFrame.new(CENTER + Vector3.new(-104, 0, 24)) * CFrame.Angles(0, math.rad(25), math.rad(-6))
P(wreck, "Keel", BLOCK, Vector3.new(7, 1, 20), hull * CFrame.new(0, 0.2, 0), PAL.woodDark, WOOD)
for _, side in { -1, 1 } do
	for k = -2, 2 do
		if not (side == 1 and k == 0) then -- a broken gap on the starboard side is the way in
			P(wreck, "Plank", BLOCK, Vector3.new(0.8, 5, 3.9), hull * CFrame.new(side * 3.6, 2.6, k * 4) * CFrame.Angles(0, 0, side * math.rad(-12)), PAL.wood, WOOD)
		end
	end
end
wedge(wreck, "Bow", Vector3.new(7.6, 5, 5), hull * CFrame.new(0, 2.6, -12.4) * CFrame.Angles(0, math.pi, 0), PAL.wood, WOOD)
P(wreck, "Stern", BLOCK, Vector3.new(7.6, 6, 1), hull * CFrame.new(0, 3, 10.4), PAL.woodDark, WOOD)
P(wreck, "DeckPart", BLOCK, Vector3.new(7.4, 0.5, 6), hull * CFrame.new(0, 5.3, 7), PAL.wood, WOOD)
P(wreck, "Mast", CYL, Vector3.new(14, 1, 1), hull * CFrame.new(0.5, 6, -2) * CFrame.Angles(0, 0, math.rad(70)), PAL.woodDark, WOOD)
P(wreck, "Sail", BLOCK, Vector3.new(0.2, 5, 6), hull * CFrame.new(-4.5, 3.5, -4) * CFrame.Angles(0, 0.3, 0.6), C(235, 225, 205), Enum.Material.Fabric, DECOR)
task.wait()

-- Ruined watchtower on the south-east meadow ----------------------------------------------
local tower = folder(root, "Watchtower")
for k = 0, 7 do
	local a = k / 8 * math.pi * 2
	local h = ({ 12, 9, 6, 10, 4, 11, 7, 8 })[k + 1]
	local p = CENTER + Vector3.new(62 + math.cos(a) * 5, h / 2, 62 + math.sin(a) * 5)
	P(tower, "Wall", BLOCK, Vector3.new(4, h, 1.6), CFrame.lookAt(p, CENTER + Vector3.new(62, h / 2, 62)), PAL.rock, SLATE)
end
for _ = 1, 6 do
	local s = rng:NextNumber(1.2, 2.4)
	P(tower, "Rubble", BLOCK, Vector3.new(s, s * 0.7, s), at(62 + rng:NextNumber(-10, 10), s * 0.3, 62 + rng:NextNumber(-10, 2)) * CFrame.Angles(rng:NextNumber(), rng:NextNumber(), 0), PAL.rockDark, SLATE)
end

-- Rock arch on the east shore --------------------------------------------------------------
local arch = folder(root, "RockArch")
P(arch, "Left", BLOCK, Vector3.new(5, 14, 6), at(88, 7, 2) * CFrame.Angles(0, 0, 0.08), PAL.cliff, SLATE)
P(arch, "Right", BLOCK, Vector3.new(5, 14, 6), at(88, 7, 18) * CFrame.Angles(0, 0, -0.08), PAL.cliff, SLATE)
P(arch, "Top", BLOCK, Vector3.new(6, 4, 22), at(88, 15, 10), PAL.rock, SLATE)
task.wait()

-- Boulder pocket (west), bush ring (north), palm grove (north-west) --------------------------
for _, b in { { -70, 58, 7 }, { -82, 56, 6 }, { -86, 68, 7 }, { -74, 72, 6 } } do
	boulder(Vector3.new(b[1], 0, b[2]), b[3])
end
for k = 0, 11 do
	if k ~= 3 then -- one gap lets the player in
		local a = k / 12 * math.pi * 2
		bush(Vector3.new(10 + math.cos(a) * 7, 0, -88 + math.sin(a) * 7), 4.5)
	end
end
for _, b in { { 70, -55, 6 }, { 76, -48, 5 }, { -10, -100, 5 }, { 100, -30, 6 }, { -110, -40, 5 } } do
	boulder(Vector3.new(b[1], 0, b[2]), b[3])
end
local palms = {
	{ -95, -55 }, { -102, -46 }, { -88, -42 }, { 18, 114 }, { 32, 100 }, { -32, 104 }, { 105, 40 }, { 110, -10 },
	{ -115, 0 }, { -60, 95 }, { 70, 95 }, { 40, -100 }, { -40, -105 }, { 25, 30 }, { -15, -20 }, { 60, 20 },
}
for _, p in palms do
	palm(Vector3.new(p[1], 0, p[2]), rng:NextNumber(11, 15), rng:NextNumber(2, 5))
end
for _, b in { { -45, 15 }, { 15, 75 }, { 50, 45 }, { -80, -5 }, { 30, -60 }, { -20, -45 }, { 80, -20 }, { -55, 80 } } do
	bush(Vector3.new(b[1], 0, b[2]), rng:NextNumber(3, 4.5))
	flowers(Vector3.new(b[1] + 4, 0, b[2] + 3))
end
task.wait()

-- Dig spots -----------------------------------------------------------------------------------
local spots = folder(root, "DigSpots")
local SPOTS = {
	easy = {
		{ -20, 0, 70 }, { 25, 0, 60 }, { -60, 0, 10 }, { 55, 0, 32 }, { 0, 0, 18 },
		{ -35, 0, -55 }, { 18, 0, -48 }, { 72, 0, -18 }, { -88, 0, -14 }, { 92, 0, 42 },
	},
	hidden = {
		{ -79, 0, 64 }, -- inside the boulder pocket
		{ 70, 0, 70 }, -- behind the watchtower
		{ -95, 0, -49 }, -- under the palm grove
		{ 95, 0, 10 }, -- behind the rock arch
		{ -112, 0, 6 }, -- beside the wreck's bow
		{ 42, 0, -36 }, -- behind the cliff
		{ 10, 0, -88 }, -- inside the bush ring
	},
	secret = {
		{ 40, 0, -15.6 }, -- behind the waterfall
		{ -55, 26.5, -30 }, -- on top of the Eagle Rock
		{ -30, 0, 45 }, -- inside the hollow tree
		{ -104, 0.8, 24 }, -- in the shipwreck's hold
	},
}
for tier, list in SPOTS do
	for i, pos in list do
		local part = P(spots, tier .. i, BLOCK, Vector3.one, at(pos[1], pos[2] + 0.5, pos[3]), PAL.gold, SMOOTH, HIDDEN)
		part:SetAttribute("Tier", tier)
	end
end

-- Spirit spawn points -------------------------------------------------------------------------
local spawns = folder(root, "IsleSpawns")
local SPAWNS = {
	{ "Isle_1", -10, 40, "easy", "" },
	{ "Isle_2", 45, 22, "easy", "" },
	{ "Isle_3", -50, -2, "easy", "" },
	{ "Isle_4", 62, -45, "tricky", "dash" },
	{ "Isle_5", -62, 36, "tricky", "dash" },
	{ "Isle_6", -15, -68, "master", "blink" },
}
for _, s in SPAWNS do
	local part = P(spawns, s[1], BLOCK, Vector3.one, at(s[2], 0.5, s[3]), PAL.gold, SMOOTH, HIDDEN)
	part:SetAttribute("SpawnId", s[1])
	part:SetAttribute("Area", "Isle")
	part:SetAttribute("Pool", s[4])
	part:SetAttribute("Trick", s[5])
	part:SetAttribute("RespawnSeconds", 25)
end

-- A soft sparkle over the whole island.
local motes = P(root, "Motes", BLOCK, Vector3.new(220, 12, 220), at(0, 8, 0), PAL.foam, SMOOTH, HIDDEN)
local sparkle = Instance.new("ParticleEmitter")
sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparkle.Color = ColorSequence.new(C(255, 240, 180))
sparkle.LightEmission = 1
sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 0) })
sparkle.Lifetime = NumberRange.new(4, 7)
sparkle.Rate = 10
sparkle.Speed = NumberRange.new(0.3, 0.8)
sparkle.SpreadAngle = Vector2.new(180, 180)
sparkle.Shape = Enum.ParticleEmitterShape.Box
sparkle.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
sparkle.Parent = motes

return ("Treasure Isle built: %d parts, %d dig spots, %d spirit spawns"):format(count, #spots:GetChildren(), #spawns:GetChildren())
