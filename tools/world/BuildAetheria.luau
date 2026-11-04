-- Builds the compact Aetheria island: plaza with the Aether crystal and spawn pads, eight
-- treasury plots, a Whisper Forest teaser, the sealed ruins portal and the relic spawn points.
-- Run in Studio's Edit DataModel (MCP execute_luau or the command bar). It rebuilds
-- Workspace.Aetheria from scratch; scripts rely only on the names documented in
-- PlotService.luau and RelicSpawnService.luau. Run BuildDecor.luau afterwards for the scenery.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local C = Color3.fromRGB
local PAL = {
	grass = C(126, 200, 112),
	grassDark = C(92, 166, 96),
	moss = C(78, 150, 104),
	rock = C(104, 94, 136),
	rockDark = C(74, 64, 104),
	stone = C(222, 212, 196),
	stoneDark = C(184, 172, 158),
	pad = C(176, 140, 240),
	path = C(226, 208, 172),
	lavender = C(200, 170, 255),
	violet = C(160, 90, 255),
	turquoise = C(80, 220, 230),
	gold = C(255, 196, 84),
	wood = C(132, 94, 72),
	leaf = C(98, 192, 122),
	leafDark = C(62, 150, 112),
	leafTeal = C(70, 180, 170),
	mushroom = C(120, 230, 255),
	ruin = C(52, 66, 120),
	ruinGlow = C(70, 110, 230),
}
local PLOT_COLORS = {
	C(160, 90, 255), C(80, 220, 230), C(255, 196, 84), C(120, 220, 120),
	C(255, 130, 170), C(110, 150, 255), C(255, 150, 80), C(200, 170, 255),
}
local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local SMOOTH, NEON, METAL = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Metal
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local ON_CORNER = CFrame.Angles(math.rad(45), 0, math.atan(1 / math.sqrt(2)))
local HIDDEN = { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }

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
	return p
end

local function cyl(parent, name, height, diameter, cf, color, material, extra)
	return P(parent, name, CYL, Vector3.new(height, diameter, diameter), cf * UPRIGHT, color, material, extra)
end

local function container(className, parent, name)
	local m = Instance.new(className)
	m.Name = name
	m.Parent = parent
	return m
end

local function sign(parent, cf, width, title, subtitle, titleName)
	local s = container("Model", parent, "Sign")
	P(s, "Post", BLOCK, Vector3.new(0.8, 5, 0.8), cf * CFrame.new(0, 2.5, 0.3), PAL.wood)
	local board = P(s, "Board", BLOCK, Vector3.new(width, 3.2, 0.5), cf * CFrame.new(0, 5.2, 0), PAL.wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local function label(name, text, y, h)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.Size = UDim2.new(0.92, 0, h, 0)
		l.Position = UDim2.new(0.04, 0, y, 0)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextScaled = true
		l.Font = Enum.Font.FredokaOne
		l.TextColor3 = C(255, 244, 222)
		l.Parent = gui
	end
	label(titleName or "Title", title, 0.06, if subtitle then 0.56 else 0.88)
	if subtitle then
		label("Subtitle", subtitle, 0.64, 0.3)
	end
	gui.Parent = board
	return s
end

local old = Workspace:FindFirstChild("Aetheria")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "Aetheria"
root.Parent = Workspace

-- Island body ---------------------------------------------------------------------------
local island = container("Model", root, "Island")
cyl(island, "GrassTop", 8, 420, CFrame.new(0, -4, 0), PAL.grass)
cyl(island, "GrassEdge", 6, 428, CFrame.new(0, -5.5, 0), PAL.grassDark)
local layers = { { 410, 20, -14 }, { 340, 26, -36 }, { 250, 28, -62 }, { 150, 28, -88 }, { 70, 26, -112 }, { 24, 20, -132 } }
for i, layer in layers do
	cyl(island, "Rock" .. i, layer[2], layer[1], CFrame.new(0, layer[3], 0), if i % 2 == 0 then PAL.rockDark else PAL.rock)
end
for i, hill in { { -175, -21, 30, 52 }, { 175, -21, -20, 48 }, { -60, -27, 195, 60 }, { 60, -25, -185, 54 } } do
	P(island, "Hill" .. i, BALL, Vector3.one * hill[4], CFrame.new(hill[1], hill[2], hill[3]), PAL.grassDark)
end
for i = 1, 4 do
	local a = math.rad(30 + (i - 1) * 90)
	local pos = Vector3.new(math.sin(a) * 280, 10 + i * 6, math.cos(a) * 280)
	local isle = container("Model", island, "FloatingIsle" .. i)
	cyl(isle, "Top", 4, 36, CFrame.new(pos), PAL.grass)
	cyl(isle, "Rock", 10, 28, CFrame.new(pos - Vector3.new(0, 7, 0)), PAL.rock)
	cyl(isle, "Root", 8, 14, CFrame.new(pos - Vector3.new(0, 15, 0)), PAL.rockDark)
	P(isle, "Crystal", BLOCK, Vector3.one * 5, CFrame.new(pos + Vector3.new(0, 6, 0)) * ON_CORNER, if i % 2 == 0 then PAL.turquoise else PAL.violet, NEON)
end
task.wait()

-- Plaza ---------------------------------------------------------------------------------
local plaza = container("Model", root, "Plaza")
plaza.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
cyl(plaza, "Border", 0.8, 104, CFrame.new(0, -0.15, 0), PAL.stoneDark)
cyl(plaza, "Floor", 1, 100, CFrame.new(0, 0, 0), PAL.stone)
for i = 0, 23 do
	local a = i / 24 * math.pi * 2
	P(plaza, "Rune" .. i, BLOCK, Vector3.new(1.2, 0.12, 3), CFrame.new(math.sin(a) * 40, 0.55, math.cos(a) * 40) * CFrame.Angles(0, a, 0), PAL.lavender, NEON)
end
cyl(plaza, "Dais", 1.2, 20, CFrame.new(0, 0.6, 0), PAL.stoneDark)
cyl(plaza, "DaisGlow", 0.1, 10, CFrame.new(0, 1.25, 0), PAL.violet, NEON)
for i = 0, 3 do
	local a = math.rad(45 + i * 90)
	P(plaza, "DaisPillar" .. i, BLOCK, Vector3.new(1.6, 6, 1.6), CFrame.new(math.sin(a) * 8.5, 4, math.cos(a) * 8.5), PAL.stone)
	P(plaza, "DaisGem" .. i, BLOCK, Vector3.one * 1.4, CFrame.new(math.sin(a) * 8.5, 7.8, math.cos(a) * 8.5) * ON_CORNER, PAL.turquoise, NEON)
end

local crystal = container("Model", plaza, "AetherCrystal")
P(crystal, "Core", BLOCK, Vector3.one * 11, CFrame.new(0, 24, 0) * ON_CORNER, PAL.violet, NEON, { CastShadow = false })
for ring = 0, 1 do
	local tilt = CFrame.new(0, 24, 0) * CFrame.Angles(math.rad(ring * 70 + 10), 0, math.rad(ring * 25))
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		P(crystal, "Ring" .. ring .. "_" .. i, BLOCK, Vector3.new(6.1, 0.7, 0.7), tilt * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 11.5), PAL.gold, METAL, { CanCollide = false, CastShadow = false })
	end
end
for i = 0, 3 do
	local a = i / 4 * math.pi * 2
	P(crystal, "Shard" .. i, BLOCK, Vector3.new(1.4, 3.4, 1.4), CFrame.new(math.sin(a) * 16, 22 + (i % 2) * 4, math.cos(a) * 16) * CFrame.Angles(0, a, math.rad(15)), PAL.turquoise, NEON, { CanCollide = false, CastShadow = false })
end
local light = Instance.new("PointLight")
light.Color = PAL.violet
light.Range = 40
light.Brightness = 0.9
light.Parent = crystal.Core
crystal.WorldPivot = CFrame.new(0, 24, 0)
crystal:AddTag("SpinSlow")

local pads = container("Folder", root, "SpawnPads")
for i, x in { -18, -6, 6, 18 } do
	local pad = Instance.new("SpawnLocation")
	pad.Name = "SpawnPad" .. i
	pad.Size = Vector3.new(6, 1, 6)
	pad.CFrame = CFrame.new(x, 0.1, 26)
	pad.Color = PAL.pad
	pad.Material = SMOOTH
	pad.Anchored = true
	pad.Neutral = true
	pad.Duration = 0
	pad.AllowTeamChangeOnTouch = false
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.Parent = pads
end
sign(plaza, CFrame.new(-24, 0.5, 6) * CFrame.Angles(0, math.rad(200), 0), 13, "Kristallplatz", "Willkommen in Aetheria!")
task.wait()

-- Paths ---------------------------------------------------------------------------------
local paths = container("Model", root, "Paths")
local function path(name, from, to, width)
	local mid = (from + to) / 2
	local length = (to - from).Magnitude
	P(paths, name, BLOCK, Vector3.new(width, 0.3, length), CFrame.lookAt(mid, to), PAL.path)
end

-- Treasury plots ------------------------------------------------------------------------
-- Each plot is a paved yard; the house itself (starting room with pedestals 1-4 and every
-- room built later) is created at runtime by Server/Util/Blueprints.luau. The plot carries its
-- accent colour as an attribute. cf is the yard's CFrame (local -Z faces the plaza).
local plots = container("Folder", root, "Plots")
local PLOT_R = 120
for i = 1, 8 do
	local theta = math.rad(-78.75 + (i - 1) * 22.5)
	local pos = Vector3.new(math.sin(theta) * PLOT_R, 0, -math.cos(theta) * PLOT_R)
	local cf = CFrame.lookAt(pos, Vector3.new(0, 0, 0)) -- local -Z faces the plaza
	local accent = PLOT_COLORS[i]
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local dir = (Vector3.new(0, 0, 0) - pos).Unit
	path("PlotPath" .. i, dir * -50 + Vector3.new(0, 0.05, 0), pos + dir * 21 + Vector3.new(0, 0.05, 0), 9)

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. i
	plot:SetAttribute("PlotIndex", i)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("Accent", accent)
	plot.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	P(plot, "Floor", BLOCK, Vector3.new(40, 1.2, 40), at(0, 0, 0), PAL.stone)
	P(plot, "YardPath", BLOCK, Vector3.new(6, 0.1, 14), at(0, 0.62, -13), PAL.stoneDark)
	sign(plot, at(-12, 0.6, -21.5), 13, "Freie Schatzkammer", "Schatzkammer " .. i, "OwnerLabel")
	P(plot, "SpawnPoint", BLOCK, Vector3.new(4, 1, 4), at(0, 0.2, -11) * CFrame.Angles(0, math.pi, 0), accent, SMOOTH, HIDDEN)
	container("Folder", plot, "Pedestals")
	plot.Parent = plots
	task.wait()
end

-- Whisper Forest ------------------------------------------------------------------------
local FOREST = Vector3.new(0, 0, 140)
path("ForestPath", Vector3.new(0, 0.05, 50), Vector3.new(0, 0.05, 96), 9)
local forest = container("Model", root, "WhisperForest")
cyl(forest, "Moss", 0.3, 124, CFrame.new(FOREST + Vector3.new(0, 0.05, 0)), PAL.moss)
sign(forest, CFrame.new(10, 0.2, 92), 11, "Flüsterwald")

local spawnSpots = {}
local function addSpawn(id, pos, area, respawn, starter)
	table.insert(spawnSpots, { id = id, pos = pos, area = area, respawn = respawn, starter = starter })
end
addSpawn("Plaza_Start", Vector3.new(0, 0.5, 13), "Plaza", 30, true)
addSpawn("Plaza_W", Vector3.new(-30, 0.5, -6), "Plaza", 40)
addSpawn("Plaza_E", Vector3.new(30, 0.5, -6), "Plaza", 40)
addSpawn("Plaza_N", Vector3.new(0, 0.5, -36), "Plaza", 40)
addSpawn("Path_S", Vector3.new(0, 0.2, 72), "Plaza", 45)
addSpawn("Forest_1", Vector3.new(-22, 0.2, 118), "Forest", 60)
addSpawn("Forest_2", Vector3.new(24, 0.2, 112), "Forest", 60)
addSpawn("Forest_3", Vector3.new(-34, 0.2, 152), "Forest", 60)
addSpawn("Forest_4", Vector3.new(30, 0.2, 160), "Forest", 60)
addSpawn("Forest_5", Vector3.new(-6, 0.2, 184), "Forest", 60)
addSpawn("Forest_6", Vector3.new(13, 0.2, 140), "Forest", 60)

local rng = Random.new(42)
local function clear(pos, radius)
	if math.abs(pos.X) < 8 and pos.Z < 126 then
		return false -- forest path
	end
	if (pos - FOREST).Magnitude < 15 then
		return false -- ruin clearing
	end
	for _, s in spawnSpots do
		if (Vector3.new(s.pos.X, 0, s.pos.Z) - pos).Magnitude < radius then
			return false
		end
	end
	return true
end
local trees = 0
while trees < 18 do
	local a = rng:NextNumber() * math.pi * 2
	local r = 18 + rng:NextNumber() * 40
	local pos = FOREST + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
	if clear(pos, 8) then
		trees += 1
		local tree = container("Model", forest, "Tree" .. trees)
		local h = rng:NextNumber(8, 12)
		cyl(tree, "Trunk", h, 2, CFrame.new(pos + Vector3.new(0, h / 2, 0)), PAL.wood)
		local leaves = ({ PAL.leaf, PAL.leafDark, PAL.leafTeal })[rng:NextInteger(1, 3)]
		local d = rng:NextNumber(9, 13)
		P(tree, "Canopy", BALL, Vector3.one * d, CFrame.new(pos + Vector3.new(0, h + d * 0.25, 0)), leaves)
		P(tree, "CanopyTop", BALL, Vector3.one * d * 0.6, CFrame.new(pos + Vector3.new(d * 0.15, h + d * 0.65, -d * 0.1)), leaves:Lerp(PAL.grass, 0.3))
	end
end
local mushrooms = 0
while mushrooms < 10 do
	local a = rng:NextNumber() * math.pi * 2
	local r = 10 + rng:NextNumber() * 48
	local pos = FOREST + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
	if clear(pos, 4) then
		mushrooms += 1
		local s = if mushrooms <= 2 then 2 else 1
		local m = container("Model", forest, "Mushroom" .. mushrooms)
		cyl(m, "Stem", 1.6 * s, 0.8 * s, CFrame.new(pos + Vector3.new(0, 0.8 * s, 0)), C(245, 240, 230))
		local cap = cyl(m, "Cap", 0.7 * s, 2.6 * s, CFrame.new(pos + Vector3.new(0, 1.9 * s, 0)), PAL.mushroom, NEON)
		if mushrooms <= 4 then
			local glow = Instance.new("PointLight")
			glow.Color = PAL.mushroom
			glow.Range = 10
			glow.Brightness = 1
			glow.Parent = cap
		end
	end
end
local ruin = container("Model", forest, "Ruin")
for i, h in { 6, 9, 4, 7 } do
	local a = math.rad(i * 90 + 20)
	P(ruin, "Pillar" .. i, BLOCK, Vector3.new(2.2, h, 2.2), CFrame.new(FOREST + Vector3.new(math.sin(a) * 9, h / 2, math.cos(a) * 9)) * CFrame.Angles(0, a, 0), PAL.stoneDark)
end
P(ruin, "Fallen", BLOCK, Vector3.new(2.2, 2.2, 7), CFrame.new(FOREST + Vector3.new(-3, 1.1, -10)) * CFrame.Angles(0, math.rad(60), math.rad(8)), PAL.stoneDark)
P(ruin, "RuneStone", BLOCK, Vector3.new(3, 4, 1.2), CFrame.new(FOREST + Vector3.new(0, 2, 0)), PAL.rock)
P(ruin, "RuneGlyph", BLOCK, Vector3.new(1.6, 2.2, 0.1), CFrame.new(FOREST + Vector3.new(0, 2.2, -0.62)), PAL.lavender, NEON)
task.wait()

-- Forgotten Ruins portal: ExpeditionService adds the prompt; the arena is BuildExpedition.luau --
local RUINS = Vector3.new(140, 0, 118)
path("RuinsPath", Vector3.new(36, 0.05, 30), RUINS + (Vector3.zero - RUINS).Unit * 14 + Vector3.new(0, 0.05, 0), 8)
local ruins = container("Model", root, "ForgottenRuins")
local face = CFrame.lookAt(RUINS, Vector3.new(0, 0, 0))
cyl(ruins, "Base", 1, 26, CFrame.new(RUINS), PAL.ruin)
P(ruins, "PillarL", BLOCK, Vector3.new(3, 16, 3), face * CFrame.new(-7, 8.5, 0), PAL.ruin)
P(ruins, "PillarR", BLOCK, Vector3.new(3, 16, 3), face * CFrame.new(7, 8.5, 0), PAL.ruin)
P(ruins, "Lintel", BLOCK, Vector3.new(18, 3, 3.4), face * CFrame.new(0, 17.5, 0), PAL.ruin)
P(ruins, "Portal", BLOCK, Vector3.new(11, 15, 0.4), face * CFrame.new(0, 8.5, 0), PAL.ruinGlow, NEON, { Transparency = 0.35, CanCollide = true })
sign(ruins, face * CFrame.new(-11, 0.5, -6), 13, "Vergessene Ruinen", "Expedition · 1–4 Spieler")

-- Relic spawn points --------------------------------------------------------------------
local spawns = container("Folder", root, "RelicSpawns")
for _, s in spawnSpots do
	local marker = P(spawns, s.id, BLOCK, Vector3.one, CFrame.new(s.pos), PAL.gold, SMOOTH, HIDDEN)
	marker:SetAttribute("SpawnId", s.id)
	marker:SetAttribute("Area", s.area)
	marker:SetAttribute("RespawnSeconds", s.respawn)
	marker:SetAttribute("Starter", s.starter == true)
end

-- Lighting: soft, slightly violet daylight ------------------------------------------------
Lighting.ClockTime = 14.5
Lighting.Brightness = 2
Lighting.ExposureCompensation = -0.25
Lighting.OutdoorAmbient = C(150, 140, 185)
Lighting.Ambient = C(80, 70, 110)
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.15
	atmosphere.Color = C(205, 195, 255)
	atmosphere.Decay = C(120, 100, 190)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.4
end
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 2
end
local grade = Lighting:FindFirstChild("AetheriaGrade") or Instance.new("ColorCorrectionEffect")
grade.Name = "AetheriaGrade"
grade.Saturation = 0.12
grade.Contrast = 0.05
grade.Parent = Lighting
if not Workspace.Terrain:FindFirstChildOfClass("Clouds") then
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Parent = Workspace.Terrain
end

local count = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
return ("Aetheria built: %d parts, %d plots, %d relic spawns"):format(count, #plots:GetChildren(), #spawnSpots)
