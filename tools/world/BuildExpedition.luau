-- Builds the "Forgotten Ruins" expedition arena template as ServerStorage.ExpeditionArena.
-- Run in Studio's Edit DataModel (MCP execute_luau or the command bar), like BuildAetheria.
-- ExpeditionService clones the template far away from the island for every run, so the arena
-- is built around the local origin: floor top at y = 0, the run moves along +Z.
-- Name contract (read by ExpeditionService.luau):
--   Markers/Spawn, Checkpoint2..4, ChestSpot   hidden parts
--   Room1: Plates/Plate1..4 (attr Symbol), Tablet (SurfaceGui.Text), Door1
--   Room2: BeamSource, Receiver, Mirrors/Mirror1..3 (Model: Base, Glass), WispA, WispB, Wisp, Door2
--   Room3: Stones/Stone1..3 (SurfaceGui.Text), Riddle (SurfaceGui.Text), Door3
--   Boss: Guardian (Model: Body, Head, Core, ArmL, ArmR), Pillars/Pillar1..4 (Model: Column, Gem)
--   Chest (Model: Base, Lid), ExitPortal

local ServerStorage = game:GetService("ServerStorage")

local C = Color3.fromRGB
local PAL = {
	floor = C(70, 78, 120),
	floorDark = C(50, 56, 92),
	wall = C(58, 66, 110),
	wallDark = C(40, 46, 82),
	rock = C(74, 64, 104),
	glow = C(140, 160, 255),
	lavender = C(200, 170, 255),
	gold = C(255, 196, 84),
	moss = C(78, 150, 104),
	crystal = C(120, 230, 255),
	door = C(96, 84, 140),
	torch = C(255, 170, 90),
}
-- Plate / stone symbols, index = Symbol attribute (ExpeditionService uses the same order).
local SYMBOLS = {
	{ glyph = "☀️", color = C(255, 200, 80) },
	{ glyph = "🌙", color = C(120, 170, 255) },
	{ glyph = "⭐", color = C(200, 140, 255) },
	{ glyph = "🍀", color = C(110, 220, 130) },
}
local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local SMOOTH, NEON, SLATE = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Slate
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local ON_CORNER = CFrame.Angles(math.rad(45), 0, math.atan(1 / math.sqrt(2)))
local HIDDEN = { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }
local GHOST = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

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

-- A SurfaceGui with one big label named "Text" on the given face.
local function face(part, faceId, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SurfaceGui"
	gui.Face = faceId
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(0.9, 0.84)
	label.Position = UDim2.fromScale(0.05, 0.08)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or C(255, 244, 222)
	label.Parent = gui
	gui.Parent = part
	return gui
end

local function L(x, y, z)
	return CFrame.new(x, y, z)
end

local old = ServerStorage:FindFirstChild("ExpeditionArena")
if old then
	old:Destroy()
end
local arena = Instance.new("Model")
arena.Name = "ExpeditionArena"
arena.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

local markers = container("Folder", arena, "Markers")
local function marker(name, x, z)
	P(markers, name, BLOCK, Vector3.new(4, 1, 4), L(x, 0.5, z), PAL.gold, SMOOTH, HIDDEN)
end

local shell = container("Model", arena, "Shell")
-- Floor slab with a darker border and a rocky underside, so each room reads as a floating ruin.
local function room(name, zFrom, zTo, halfWidth)
	local length = zTo - zFrom
	local mid = (zFrom + zTo) / 2
	P(shell, name .. "Floor", BLOCK, Vector3.new(halfWidth * 2, 2, length), L(0, -1, mid), PAL.floor, SLATE)
	P(shell, name .. "Trim", BLOCK, Vector3.new(halfWidth * 2 + 2, 1.6, length), L(0, -1.6, mid), PAL.floorDark, SLATE)
	P(shell, name .. "Under", BLOCK, Vector3.new(halfWidth * 2 - 6, 10, length - 6), L(0, -7, mid), PAL.rock, SLATE)
	for _, side in { -1, 1 } do
		P(shell, name .. "Wall", BLOCK, Vector3.new(2, 16, length), L(side * (halfWidth + 1), 8, mid), PAL.wall, SLATE)
		P(shell, name .. "WallCap", BLOCK, Vector3.new(2.6, 1, length), L(side * (halfWidth + 1), 16.5, mid), PAL.wallDark, SLATE)
		P(shell, name .. "RuneLine", BLOCK, Vector3.new(0.2, 0.5, length - 4), L(side * halfWidth, 5, mid), PAL.lavender, NEON, GHOST)
	end
end

-- Wall across the run with a 12-wide doorway; the door slab itself is returned.
local function gate(name, z, halfWidth)
	local side = (halfWidth * 2 - 12) / 2
	for _, s in { -1, 1 } do
		P(shell, name .. "Wall", BLOCK, Vector3.new(side, 16, 2), L(s * (6 + side / 2), 8, z), PAL.wall, SLATE)
	end
	P(shell, name .. "Lintel", BLOCK, Vector3.new(14, 2, 2.4), L(0, 15, z), PAL.wallDark, SLATE)
	return P(arena, name, BLOCK, Vector3.new(12, 14, 1.6), L(0, 7, z), PAL.door, SLATE)
end

local torches = 0
local function torch(x, z)
	torches += 1
	local t = container("Model", shell, "Torch" .. torches)
	P(t, "Bracket", BLOCK, Vector3.new(0.6, 2, 0.6), L(x, 7, z), PAL.wallDark)
	local flame = P(t, "Flame", BALL, Vector3.one * 1.2, L(x, 8.4, z), PAL.torch, NEON, GHOST)
	local light = Instance.new("PointLight")
	light.Color = PAL.torch
	light.Range = 18
	light.Brightness = 1.4
	light.Parent = flame
end

-- Start ----------------------------------------------------------------------------------
room("Start", -15, 15, 22)
P(shell, "BackWall", BLOCK, Vector3.new(46, 16, 2), L(0, 8, -16), PAL.wall, SLATE)
marker("Spawn", 0, 0)
cyl(shell, "SpawnRing", 0.2, 12, L(0, 0.1, 0), PAL.glow, NEON, GHOST)
local welcome = P(shell, "WelcomeBoard", BLOCK, Vector3.new(16, 5, 0.6), L(0, 7, -14.6), PAL.wallDark)
face(welcome, Enum.NormalId.Back, "Vergessene Ruinen", PAL.lavender)
torch(-20, -8)
torch(20, -8)

-- Room 1: pressure plates ---------------------------------------------------------------
room("Room1", 15, 65, 22)
local plates = container("Folder", arena, "Plates")
for i, x in { -15, -5, 5, 15 } do
	local plate = P(plates, "Plate" .. i, BLOCK, Vector3.new(7, 0.4, 7), L(x, 0.2, 40), SYMBOLS[i].color:Lerp(PAL.floor, 0.55), SMOOTH)
	plate:SetAttribute("Symbol", i)
	face(plate, Enum.NormalId.Top, SYMBOLS[i].glyph)
	P(shell, "PlateRim" .. i, BLOCK, Vector3.new(8, 0.2, 8), L(x, 0.1, 40), PAL.floorDark, SLATE)
end
gate("Door1", 65, 22)
local tablet = P(arena, "Tablet", BLOCK, Vector3.new(18, 4, 0.6), L(0, 18.5, 64.2), PAL.wallDark)
face(tablet, Enum.NormalId.Front, "", PAL.gold)
torch(-20, 28)
torch(20, 52)

-- Room 2: mirror hall --------------------------------------------------------------------
room("Room2", 65, 135, 22)
marker("Checkpoint2", 0, 72)
local source = P(arena, "BeamSource", BLOCK, Vector3.new(2, 3, 3), L(-20.5, 4, 85), PAL.crystal, NEON)
cyl(shell, "SourcePedestal", 2.5, 3.5, L(-20, 1.25, 85), PAL.wallDark)
source:SetAttribute("Direction", Vector3.new(1, 0, 0))
local receiver = P(arena, "Receiver", BLOCK, Vector3.one * 3, L(-15, 4, 131) * ON_CORNER, PAL.wallDark, SMOOTH)
cyl(shell, "ReceiverPedestal", 2.5, 3.5, L(-15, 1.25, 131), PAL.wallDark)
local mirrors = container("Folder", arena, "Mirrors")
for i, pos in { Vector3.new(5, 0, 85), Vector3.new(5, 0, 115), Vector3.new(-15, 0, 115) } do
	local m = container("Model", mirrors, "Mirror" .. i)
	cyl(m, "Base", 1.2, 4.5, L(pos.X, 0.6, pos.Z), PAL.wallDark, SLATE)
	P(m, "Glass", BLOCK, Vector3.new(6, 6, 0.5), L(pos.X, 4.2, pos.Z), C(210, 235, 255), Enum.Material.Glass, { Transparency = 0.15, Reflectance = 0.4 })
	m.PrimaryPart = m.Base
end
P(arena, "WispA", BLOCK, Vector3.one, L(-18, 3.5, 100), PAL.glow, SMOOTH, HIDDEN)
P(arena, "WispB", BLOCK, Vector3.one, L(18, 3.5, 100), PAL.glow, SMOOTH, HIDDEN)
local wisp = P(arena, "Wisp", BALL, Vector3.one * 3.4, L(-18, 3.5, 100), C(255, 120, 150), NEON, GHOST)
local wispLight = Instance.new("PointLight")
wispLight.Color = wisp.Color
wispLight.Range = 12
wispLight.Parent = wisp
P(shell, "WispTrack", BLOCK, Vector3.new(40, 0.1, 1), L(0, 0.05, 100), C(255, 120, 150), NEON, GHOST)
gate("Door2", 135, 22)
torch(-20, 120)
torch(20, 75)

-- Room 3: riddle stones -----------------------------------------------------------------
room("Room3", 135, 185, 22)
marker("Checkpoint3", 0, 142)
local stones = container("Folder", arena, "Stones")
for i, x in { -12, 0, 12 } do
	local stone = P(stones, "Stone" .. i, BLOCK, Vector3.new(5, 7, 5), L(x, 3.5, 162), PAL.rock, SLATE)
	face(stone, Enum.NormalId.Front, "")
	cyl(shell, "StoneBase" .. i, 0.6, 7.5, L(x, 0.3, 162), PAL.floorDark)
end
gate("Door3", 185, 22)
local riddle = P(arena, "Riddle", BLOCK, Vector3.new(18, 4, 0.6), L(0, 18.5, 184.2), PAL.wallDark)
face(riddle, Enum.NormalId.Front, "", PAL.gold)
torch(-20, 150)
torch(20, 172)

-- Boss arena -----------------------------------------------------------------------------
room("Boss", 185, 265, 34)
P(shell, "EndWall", BLOCK, Vector3.new(70, 16, 2), L(0, 8, 266), PAL.wall, SLATE)
-- Room 3 is narrower than the boss hall: close the gap beside the doorway.
for _, s in { -1, 1 } do
	P(shell, "Shoulder", BLOCK, Vector3.new(12, 16, 2), L(s * 29, 8, 185), PAL.wall, SLATE)
end
marker("Checkpoint4", 0, 194)
marker("ChestSpot", 0, 230)
cyl(shell, "ArenaRing", 0.2, 30, L(0, 0.1, 230), PAL.lavender, NEON, GHOST)
cyl(shell, "ArenaDais", 0.6, 26, L(0, 0.3, 230), PAL.floorDark, SLATE)

local guardian = container("Model", arena, "Guardian")
local g0 = L(0, 0, 230)
P(guardian, "Body", BLOCK, Vector3.new(7, 9, 5), g0 * L(0, 7.5, 0), PAL.rock, SLATE)
P(guardian, "Head", BLOCK, Vector3.new(4.5, 4, 4), g0 * L(0, 14, 0), PAL.rock, SLATE)
P(guardian, "Eye", BLOCK, Vector3.new(3, 0.8, 0.3), g0 * L(0, 14.4, -2.05), PAL.crystal, NEON, GHOST)
P(guardian, "Core", BLOCK, Vector3.one * 3, g0 * L(0, 8, -2.4) * ON_CORNER, PAL.crystal, NEON)
for _, s in { -1, 1 } do
	P(guardian, if s < 0 then "ArmL" else "ArmR", BLOCK, Vector3.new(2.6, 8, 2.6), g0 * L(s * 5.2, 7, 0) * CFrame.Angles(0, 0, math.rad(s * 10)), PAL.rock, SLATE)
	P(guardian, "Shard", BLOCK, Vector3.new(1.4, 3.6, 1.4), g0 * L(s * 3, 13, 1.5) * CFrame.Angles(math.rad(-20), 0, math.rad(s * -25)), PAL.crystal, NEON, GHOST)
	P(guardian, "Leg", BLOCK, Vector3.new(2.6, 3, 2.8), g0 * L(s * 2, 1.5, 0), PAL.rock, SLATE)
end
guardian.PrimaryPart = guardian.Body
local coreLight = Instance.new("PointLight")
coreLight.Color = PAL.crystal
coreLight.Range = 16
coreLight.Brightness = 2
coreLight.Parent = guardian.Core

local pillars = container("Folder", arena, "Pillars")
for i, pos in { Vector3.new(-24, 0, 208), Vector3.new(24, 0, 208), Vector3.new(-24, 0, 252), Vector3.new(24, 0, 252) } do
	local pillar = container("Model", pillars, "Pillar" .. i)
	P(pillar, "Column", BLOCK, Vector3.new(3, 9, 3), L(pos.X, 4.5, pos.Z), PAL.wallDark, SLATE)
	P(pillar, "Gem", BLOCK, Vector3.one * 2.2, L(pos.X, 10.5, pos.Z) * ON_CORNER, PAL.floorDark, SMOOTH)
	pillar.PrimaryPart = pillar.Column
end
torch(-32, 196)
torch(32, 196)

-- Reward chest and the way home (ExpeditionService shows them after the guardian falls).
local chest = container("Model", arena, "Chest")
P(chest, "Base", BLOCK, Vector3.new(6, 3.4, 4), L(0, 1.7, 230), C(150, 100, 60))
P(chest, "Band", BLOCK, Vector3.new(6.2, 0.6, 4.2), L(0, 2.6, 230), PAL.gold, Enum.Material.Metal)
P(chest, "Lid", BLOCK, Vector3.new(6, 1.4, 4), L(0, 4.1, 230), C(170, 115, 70))
P(chest, "Lock", BLOCK, Vector3.new(1, 1.2, 0.4), L(0, 3.2, 227.9), PAL.gold, NEON)
chest.PrimaryPart = chest.Base
local exitPortal = P(arena, "ExitPortal", BLOCK, Vector3.new(10, 13, 0.4), L(0, 6.5, 262), PAL.glow, NEON, { Transparency = 0.35 })
face(exitPortal, Enum.NormalId.Front, "Zurück nach Aetheria", PAL.lavender)

arena.WorldPivot = CFrame.new()
arena.Parent = ServerStorage

local count = 0
for _, d in arena:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
return ("ExpeditionArena built: %d parts, %d lights"):format(count, torches + 2)
