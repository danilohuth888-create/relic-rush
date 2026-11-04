--!strict
-- The treasury house. Every plot is a paved yard; this module builds the house on it at
-- runtime, in the yard's local frame (floor top at y = 0.6, local -Z faces the plaza):
--
--             z 34  +-------------------------------+
--                   |  gallery (upper floor 13-16)  |   hall2: great hall, pedestals 9-12,
--                   |  hall2: great hall  9-12      |   gallery: mezzanine with two stairs
--             z 12  +--------+-----------+----------+
--                   | west   |  base     |  east    |   base: starting room, pedestals 1-4
--                   | 5-6    |  1-4      |  7-8     |   (always there, even on free plots)
--             z -6  +--------+---door----+----------+
--                   |   yard: build buttons, spawn  |
--             z -20 +-------------------------------+
--                  x -20    -10         10         20
--
-- Builds live in PlotN.Builds.<id>. Rooms add their pedestals to PlotN.Pedestals with the
-- attributes Slot, Runtime and Room; they disappear again when the room is not owned. Roof
-- parts carry the "TreasuryRoof" tag so clients can fade them while the player is inside.

local TweenService = game:GetService("TweenService")

local C = Color3.fromRGB
local GOLD = C(255, 200, 80)
local STONE = C(222, 212, 196)
local STONE_DARK = C(184, 172, 158)
local PLASTER = C(238, 228, 214)
local WOOD = C(132, 94, 72)
local WARM = C(255, 190, 110)
local CRYSTAL = C(120, 230, 255)
local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)
local ON_CORNER = CFrame.Angles(math.rad(45), 0, math.atan(1 / math.sqrt(2)))
local GROUND = 0.6

type At = (x: number, y: number, z: number) -> CFrame
type Maker = (folder: Instance, at: At, accent: Color3, plot: Model) -> ()
type Opening = { c: number, w: number, bottom: number, top: number }

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

local function light(part: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = part
end

local DECOR = { CanCollide = false, CastShadow = false }
-- Roof parts never block the camera or clicks; the client fades them while inside.
local ROOF = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

local function roofColor(accent: Color3): Color3
	return accent:Lerp(C(60, 50, 90), 0.45)
end

local function roofPart(part: BasePart): BasePart
	part:AddTag("TreasuryRoof")
	return part
end

-- A straight wall from u = a to u = b with rectangular openings (doors, windows). alongX walls
-- run along local X at z = fixed, the others along local Z at x = fixed.
local function wall(parent: Instance, at: At, alongX: boolean, fixed: number, a: number, b: number, height: number, openings: { Opening }, color: Color3)
	local top = GROUND + height
	local function piece(u0: number, u1: number, y0: number, y1: number)
		if u1 - u0 < 0.05 or y1 - y0 < 0.05 then
			return
		end
		local u, y = (u0 + u1) / 2, (y0 + y1) / 2
		if alongX then
			P(parent, "Wall", BLOCK, Vector3.new(u1 - u0, y1 - y0, 1), at(u, y, fixed), color)
		else
			P(parent, "Wall", BLOCK, Vector3.new(1, y1 - y0, u1 - u0), at(fixed, y, u), color)
		end
	end
	table.sort(openings, function(x, y)
		return x.c < y.c
	end)
	local cursor = a
	for _, o in openings do
		local left, right = o.c - o.w / 2, o.c + o.w / 2
		piece(cursor, left, GROUND, top)
		piece(left, right, GROUND, o.bottom)
		piece(left, right, o.top, top)
		cursor = right
	end
	piece(cursor, b, GROUND, top)
	-- A light stone trim along the top edge.
	local mid, length = (a + b) / 2, b - a
	if alongX then
		P(parent, "Trim", BLOCK, Vector3.new(length + 0.4, 0.4, 1.4), at(mid, top + 0.2, fixed), STONE)
	else
		P(parent, "Trim", BLOCK, Vector3.new(1.4, 0.4, length + 0.4), at(fixed, top + 0.2, mid), STONE)
	end
end

local function door(c: number, w: number, h: number): Opening
	return { c = c, w = w, bottom = GROUND, top = GROUND + h }
end

local function window(c: number, w: number, bottom: number, top: number): Opening
	return { c = c, w = w, bottom = bottom, top = top }
end

-- A gabled roof whose ridge runs along local Z (x = cx), over x = cx ± half and z = z0..z1.
local function roofAlongZ(parent: Instance, at: At, cx: number, half: number, z0: number, z1: number, eave: number, ridge: number, accent: Color3)
	local color = roofColor(accent)
	local slope = math.atan((ridge - eave) / half)
	local run = half + 1
	local length = z1 - z0 + 2
	for _, side in { -1, 1 } do
		local slab = at(cx + side * run / 2, ridge - run / 2 * math.tan(slope) + 0.45, (z0 + z1) / 2) * CFrame.Angles(0, 0, -side * slope)
		roofPart(P(parent, "Roof", BLOCK, Vector3.new(run / math.cos(slope), 0.9, length), slab, color, nil, ROOF))
		for _, d in { -0.3, 0, 0.3 } do
			roofPart(P(parent, "Tiles", BLOCK, Vector3.new(0.5, 0.25, length), slab * CFrame.new(d * run / math.cos(slope), 0.55, 0), color:Lerp(Color3.new(0, 0, 0), 0.18), nil, ROOF))
		end
		-- Gable triangles front and back.
		for _, z in { z0, z1 } do
			wedge(parent, "Gable", Vector3.new(1, ridge - eave, half), at(cx + side * half / 2, eave + (ridge - eave) / 2, z) * CFrame.Angles(0, -side * math.pi / 2, 0), PLASTER)
		end
	end
	roofPart(P(parent, "Ridge", CYL, Vector3.new(length + 0.4, 1, 1), at(cx, ridge + 0.5, (z0 + z1) / 2) * ALONG_Z, GOLD, Enum.Material.Metal, ROOF))
end

-- A gabled roof whose ridge runs along local X (z = cz), over x = x0..x1 and z = cz ± half.
local function roofAlongX(parent: Instance, at: At, cz: number, half: number, x0: number, x1: number, eave: number, ridge: number, accent: Color3)
	local color = roofColor(accent)
	local slope = math.atan((ridge - eave) / half)
	local run = half + 1
	local length = x1 - x0 + 2
	for _, side in { -1, 1 } do
		local slab = at((x0 + x1) / 2, ridge - run / 2 * math.tan(slope) + 0.45, cz + side * run / 2) * CFrame.Angles(side * slope, 0, 0)
		roofPart(P(parent, "Roof", BLOCK, Vector3.new(length, 0.9, run / math.cos(slope)), slab, color, nil, ROOF))
		for _, d in { -0.3, 0, 0.3 } do
			roofPart(P(parent, "Tiles", BLOCK, Vector3.new(length, 0.25, 0.5), slab * CFrame.new(0, 0.55, d * run / math.cos(slope)), color:Lerp(Color3.new(0, 0, 0), 0.18), nil, ROOF))
		end
		for _, x in { x0, x1 } do
			wedge(parent, "Gable", Vector3.new(1, ridge - eave, half), at(x, eave + (ridge - eave) / 2, cz + side * half / 2) * CFrame.Angles(0, if side < 0 then 0 else math.pi, 0), PLASTER)
		end
	end
	roofPart(P(parent, "Ridge", CYL, Vector3.new(length + 0.4, 1, 1), at((x0 + x1) / 2, ridge + 0.5, cz), GOLD, Enum.Material.Metal, ROOF))
end

-- A pedestal in a room; PlotService ghosts it until its slot is unlocked.
local function pedestal(plot: Model, room: string, slot: number, base: CFrame)
	local folder = plot:FindFirstChild("Pedestals") :: Instance
	if folder:FindFirstChild("Pedestal" .. slot) then
		return
	end
	local ped = Instance.new("Model")
	ped.Name = "Pedestal" .. slot
	ped:SetAttribute("Slot", slot)
	ped:SetAttribute("Runtime", true)
	ped:SetAttribute("Room", room)
	cyl(ped, "Foot", 0.6, 4.6, base * CFrame.new(0, 0.3, 0), STONE_DARK)
	cyl(ped, "Base", 2.6, 3.6, base * CFrame.new(0, 1.3, 0), STONE)
	cyl(ped, "Rim", 0.35, 4, base * CFrame.new(0, 2.75, 0), GOLD, Enum.Material.Metal)
	P(ped, "Top", BLOCK, Vector3.one, base * CFrame.new(0, 3.4, 0), GOLD, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	ped.Parent = folder
end

local function boardLabel(board: BasePart, name: string, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromScale(0.92, 0.84)
	label.Position = UDim2.fromScale(0.04, 0.08)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = C(255, 244, 222)
	label.Parent = gui
	gui.Parent = board
end

local WING_H = 9
local BASE_H = 10
local HALL_H = 14

local MAKERS: { [string]: Maker } = {
	-- The starting room every treasury has: four pedestals, a front door with the owner's
	-- banner and the build plan board, side doors to the wings and a back door to the hall.
	base = function(folder, at, accent, plot)
		P(folder, "RoomFloor", BLOCK, Vector3.new(20, 0.1, 18), at(0, GROUND + 0.03, 3), accent:Lerp(STONE, 0.75))
		wall(folder, at, true, -6, -10, 10, BASE_H, { door(0, 5, 8) }, PLASTER)
		wall(folder, at, true, 12, -10, 10, BASE_H, { door(0, 5, 8) }, PLASTER)
		for _, x in { -10, 10 } do
			wall(folder, at, false, x, -6, 12, BASE_H, { door(3.5, 3.6, 7.5) }, PLASTER)
		end
		for _, x in { -10, 10 } do
			for _, z in { -6, 12 } do
				P(folder, "Corner", BLOCK, Vector3.new(1.6, BASE_H + 0.8, 1.6), at(x, GROUND + (BASE_H + 0.8) / 2, z), STONE_DARK)
			end
		end
		P(folder, "DoorFrame", BLOCK, Vector3.new(6.2, 0.8, 1.4), at(0, GROUND + 8.4, -6), STONE_DARK)
		roofAlongZ(folder, at, 0, 10, -6, 12, GROUND + BASE_H, GROUND + BASE_H + 4.6, accent)

		local banner = P(folder, "Banner", BLOCK, Vector3.new(4, 6, 0.3), at(6, 5.6, -6.65), accent)
		banner:SetAttribute("BaseColor", accent)
		local board = P(folder, "PlanBoard", BLOCK, Vector3.new(5, 3, 0.4), at(-6, 5.4, -6.7), WOOD)
		boardLabel(board, "UpgradeLabel", "Bauplan")
		local accents = Instance.new("Folder")
		accents.Name = "Accents"
		P(accents, "RuneStrip", BLOCK, Vector3.new(20.4, 0.4, 0.3), at(0, GROUND + BASE_H - 0.6, -6.6), accent)
		for _, x in { -10, 10 } do
			P(accents, "Crystal", BLOCK, Vector3.one * 1.4, at(x, GROUND + BASE_H + 1, -8) * ON_CORNER, accent, nil, DECOR)
		end
		accents.Parent = folder

		for i, pos in { { -5, -1 }, { 5, -1 }, { -5, 8 }, { 5, 8 } } do
			pedestal(plot, "base", i, at(pos[1], GROUND, pos[2]))
		end
	end,
	-- Side rooms with two pedestals each and a window to the outside.
	roomWest = function(folder, at, accent, plot)
		local x0, x1 = -20, -10
		wall(folder, at, false, x0, -6, 12, WING_H, { window(3.5, 4, 3.6, 8) }, PLASTER)
		wall(folder, at, true, -6, x0, x1, WING_H, { window(-15, 3.4, 3.6, 7.6) }, PLASTER)
		wall(folder, at, true, 12, x0, x1, WING_H, {}, PLASTER)
		roofAlongZ(folder, at, -15, 5, -6, 12, GROUND + WING_H, GROUND + WING_H + 3, accent)
		P(folder, "RoomFloor", BLOCK, Vector3.new(9, 0.1, 17), at(-15, GROUND + 0.03, 3), accent:Lerp(STONE, 0.8))
		pedestal(plot, "roomWest", 5, at(-15, GROUND, -1))
		pedestal(plot, "roomWest", 6, at(-15, GROUND, 8))
	end,
	roomEast = function(folder, at, accent, plot)
		local x0, x1 = 10, 20
		wall(folder, at, false, x1, -6, 12, WING_H, { window(3.5, 4, 3.6, 8) }, PLASTER)
		wall(folder, at, true, -6, x0, x1, WING_H, { window(15, 3.4, 3.6, 7.6) }, PLASTER)
		wall(folder, at, true, 12, x0, x1, WING_H, {}, PLASTER)
		roofAlongZ(folder, at, 15, 5, -6, 12, GROUND + WING_H, GROUND + WING_H + 3, accent)
		P(folder, "RoomFloor", BLOCK, Vector3.new(9, 0.1, 17), at(15, GROUND + 0.03, 3), accent:Lerp(STONE, 0.8))
		pedestal(plot, "roomEast", 7, at(15, GROUND, -1))
		pedestal(plot, "roomEast", 8, at(15, GROUND, 8))
	end,
	-- The great hall behind the house: tall walls, a cross roof and four pedestals.
	hall2 = function(folder, at, accent, plot)
		P(folder, "HallFloor", BLOCK, Vector3.new(40, 1.2, 14.4), at(0, 0, 27.2), STONE)
		P(folder, "HallInlay", BLOCK, Vector3.new(36, 0.1, 19), at(0, GROUND + 0.03, 23), accent:Lerp(STONE, 0.7))
		local lower, upper = function(c: number): Opening
			return window(c, 3.6, 3.6, 8)
		end, function(c: number): Opening
			return window(c, 3.6, 10, 13)
		end
		for _, x in { -20, 20 } do
			wall(folder, at, false, x, 12, 34, HALL_H, { lower(16.5), lower(22.5), upper(30.5) }, PLASTER)
		end
		wall(folder, at, true, 34, -20, 20, HALL_H, { upper(-10), upper(10) }, PLASTER)
		-- Above the lower rooms the hall's front wall continues up to its own height.
		for _, span in { { -20, -10, GROUND + WING_H }, { 10, 20, GROUND + WING_H }, { -10, 10, GROUND + BASE_H } } do
			local h = GROUND + HALL_H - span[3]
			P(folder, "Wall", BLOCK, Vector3.new(span[2] - span[1], h, 1), at((span[1] + span[2]) / 2, span[3] + h / 2, 12.6), PLASTER)
		end
		for _, x in { -20, 20 } do
			P(folder, "Corner", BLOCK, Vector3.new(1.8, HALL_H + 0.8, 1.8), at(x, GROUND + (HALL_H + 0.8) / 2, 34), STONE_DARK)
		end
		local face = CFrame.Angles(0, math.pi / 2, 0)
		P(folder, "RoseRing", CYL, Vector3.new(0.3, 4.6, 4.6), at(0, 11.4, 34.6) * face, GOLD, Enum.Material.Metal, DECOR)
		P(folder, "RoseWindow", CYL, Vector3.new(0.3, 3.8, 3.8), at(0, 11.4, 34.75) * face, accent, Enum.Material.Neon, DECOR)
		roofAlongX(folder, at, 23, 11, -20, 20, GROUND + HALL_H, GROUND + HALL_H + 7.4, accent)
		local lamp = P(folder, "HallGlow", BALL, Vector3.one * 0.8, at(0, GROUND + HALL_H - 1, 23), WARM, Enum.Material.Neon, DECOR)
		light(lamp, WARM, 30, 0.8)
		for i, x in { -12.5, -5, 5, 12.5 } do
			pedestal(plot, "hall2", 8 + i, at(x, GROUND, 24))
		end
	end,
	-- Upper floor: a mezzanine along the back of the hall, reached by two stairs.
	gallery = function(folder, at, accent, plot)
		local floorTop = GROUND + 7.5
		P(folder, "Mezzanine", BLOCK, Vector3.new(39, 1, 6.6), at(0, floorTop - 0.5, 30.4), STONE)
		P(folder, "MezzanineEdge", BLOCK, Vector3.new(31, 0.2, 0.3), at(0, floorTop - 0.4, 27.05), accent, Enum.Material.Neon, DECOR)
		for _, x in { -8.75, 0, 8.75 } do
			P(folder, "Column", BLOCK, Vector3.new(0.9, floorTop - 1 - GROUND, 0.9), at(x, GROUND + (floorTop - 1 - GROUND) / 2, 27.6), STONE_DARK)
		end
		-- Railing with gaps at both ends where the stairs arrive.
		P(folder, "Rail", BLOCK, Vector3.new(31, 0.3, 0.3), at(0, floorTop + 1.2, 27.3), GOLD, Enum.Material.Metal)
		for x = -15, 15, 2.5 do
			P(folder, "Baluster", BLOCK, Vector3.new(0.2, 1.2, 0.2), at(x, floorTop + 0.6, 27.3), GOLD, Enum.Material.Metal, DECOR)
		end
		for _, side in { -1, 1 } do
			for k = 0, 9 do
				local top = GROUND + 0.75 * (k + 1)
				P(folder, "Step", BLOCK, Vector3.new(3.6, top - GROUND, 1.2), at(side * 17.6, GROUND + (top - GROUND) / 2, 15.6 + 1.2 * k), STONE_DARK)
			end
			P(folder, "StairRail", BLOCK, Vector3.new(0.25, 0.25, 13), at(side * 15.7, GROUND + 4.9, 21) * CFrame.Angles(-math.atan(0.75 / 1.2), 0, 0), GOLD, Enum.Material.Metal, DECOR)
		end
		for i, x in { -10.5, -3.5, 3.5, 10.5 } do
			pedestal(plot, "gallery", 12 + i, at(x, floorTop, 31))
		end
	end,
	-- Warm lamp posts in the corners of the starting room.
	lanterns = function(folder, at)
		for i, pos in { { -8.5, -4.5 }, { 8.5, -4.5 }, { -8.5, 10.5 }, { 8.5, 10.5 } } do
			P(folder, "Post", BLOCK, Vector3.new(0.5, 5, 0.5), at(pos[1], 3.1, pos[2]), WOOD)
			P(folder, "Foot", BLOCK, Vector3.new(1.2, 0.4, 1.2), at(pos[1], 0.8, pos[2]), WOOD)
			P(folder, "Cap", BLOCK, Vector3.new(1.4, 0.3, 1.4), at(pos[1], 6.95, pos[2]), WOOD)
			local lamp = P(folder, "Lamp", BALL, Vector3.one * 1.1, at(pos[1], 6.2, pos[2]), WARM, Enum.Material.Neon, DECOR)
			if i <= 2 then
				light(lamp, WARM, 16, 1.1)
			end
		end
	end,
	-- A red runner with gold edges from the yard through the house to the hall.
	carpet = function(folder, at)
		P(folder, "Runner", BLOCK, Vector3.new(3, 0.1, 32), at(0, 0.67, -4), C(190, 40, 70), Enum.Material.Fabric, DECOR)
		for _, x in { -1.65, 1.65 } do
			P(folder, "Border", BLOCK, Vector3.new(0.3, 0.12, 32), at(x, 0.68, -4), GOLD, Enum.Material.Metal, DECOR)
		end
	end,
	-- A coin fountain in the middle of the great hall.
	fountain = function(folder, at, accent)
		local c = at(0, 0, 17.5)
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
	-- Two guardian statues flanking the front door.
	statues = function(folder, at, accent)
		for _, x in { -4.8, 4.8 } do
			P(folder, "Plinth", BLOCK, Vector3.new(2.6, 1.2, 2.6), at(x, 1.2, -8.4), STONE_DARK)
			P(folder, "Body", BLOCK, Vector3.new(1.8, 3.4, 1.4), at(x, 3.5, -8.4), STONE)
			P(folder, "Head", BLOCK, Vector3.new(1.4, 1.4, 1.4), at(x, 5.9, -8.4), STONE)
			P(folder, "Eyes", BLOCK, Vector3.new(1, 0.25, 0.1), at(x, 6, -9.12), accent, Enum.Material.Neon, DECOR)
			P(folder, "Spear", BLOCK, Vector3.new(0.25, 6.5, 0.25), at(x + (if x < 0 then 1.2 else -1.2), 4.4, -8.6), GOLD, Enum.Material.Metal)
		end
	end,
	-- Glass display cases with crystals under the gallery.
	vitrines = function(folder, at, accent)
		for _, x in { -12, 12 } do
			local c = at(x, 0, 31)
			P(folder, "Plinth", BLOCK, Vector3.new(6, 1.4, 3.6), c * CFrame.new(0, 1.3, 0), WOOD)
			P(folder, "Glass", BLOCK, Vector3.new(5.6, 3.2, 3.2), c * CFrame.new(0, 3.6, 0), C(220, 240, 255), Enum.Material.Glass, { Transparency = 0.55 })
			P(folder, "Frame", BLOCK, Vector3.new(6, 0.3, 3.6), c * CFrame.new(0, 5.35, 0), GOLD, Enum.Material.Metal)
			for i, dx in { -1.6, 0, 1.6 } do
				P(folder, "Crystal", BLOCK, Vector3.one * (0.9 + i * 0.15), c * CFrame.new(dx, 3.2, 0) * ON_CORNER, if i == 2 then accent else CRYSTAL, Enum.Material.Neon, DECOR)
			end
		end
	end,
	-- Stained glass in every window of the wings and the hall.
	windows = function(folder, at, accent)
		local glass = accent:Lerp(Color3.new(1, 1, 1), 0.35)
		local function pane(cf: CFrame, w: number, h: number)
			P(folder, "Glass", BLOCK, Vector3.new(w, h, 0.3), cf, glass, Enum.Material.Glass, { Transparency = 0.25 })
			P(folder, "MullionV", BLOCK, Vector3.new(0.25, h, 0.5), cf, GOLD, Enum.Material.Metal, DECOR)
			P(folder, "MullionH", BLOCK, Vector3.new(w, 0.25, 0.5), cf, GOLD, Enum.Material.Metal, DECOR)
		end
		for _, side in { -1, 1 } do
			pane(at(side * 20, 5.8, 3.5) * ALONG_Z, 4, 4.4)
			pane(at(side * 15, 5.6, -6), 3.4, 4)
			for _, z in { 16.5, 22.5 } do
				pane(at(side * 20, 5.8, z) * ALONG_Z, 3.6, 4.4)
			end
			pane(at(side * 20, 11.5, 30.5) * ALONG_Z, 3.6, 3)
			pane(at(side * 10, 11.5, 34), 3.6, 3)
		end
	end,
	-- Two round towers at the back corners of the hall.
	towers = function(folder, at, accent)
		local roof = roofColor(accent)
		for _, side in { -1, 1 } do
			local base = at(side * 21, GROUND, 35)
			cyl(folder, "Tower", 24, 6, base * CFrame.new(0, 12, 0), STONE)
			cyl(folder, "Band", 0.8, 6.5, base * CFrame.new(0, 13, 0), STONE_DARK)
			cyl(folder, "Crown", 1.2, 7, base * CFrame.new(0, 23.6, 0), STONE_DARK)
			local out = (base.Position - at(0, GROUND, 14).Position) * Vector3.new(1, 0, 1)
			for _, y in { 8, 17 } do
				local p = base.Position + Vector3.new(0, y, 0) + out.Unit * 2.95
				P(folder, "Slit", BLOCK, Vector3.new(0.8, 2.2, 0.3), CFrame.lookAt(p, p + out), accent, Enum.Material.Neon, DECOR)
			end
			for i, d in { 7.4, 6, 4.6, 3.2, 1.8 } do
				cyl(folder, "Cone", 1.8, d, base * CFrame.new(0, 24.2 + 0.9 + (i - 1) * 1.8, 0), roof)
			end
			P(folder, "Pole", BLOCK, Vector3.new(0.25, 4, 0.25), base * CFrame.new(0, 35.2, 0), GOLD, Enum.Material.Metal, DECOR)
			P(folder, "Flag", BLOCK, Vector3.new(0.15, 1.6, 2.6), base * CFrame.new(0, 36.3, 1.4), accent, nil, DECOR)
		end
	end,
	-- The aether hall: a glass cupola with a crystal on the hall's ridge and golden eaves.
	hall3 = function(folder, at, accent)
		local ridge = GROUND + HALL_H + 7.4
		roofPart(P(folder, "CupolaBase", BLOCK, Vector3.new(6, 2.4, 6), at(0, ridge + 1, 23), STONE, nil, ROOF))
		roofPart(P(folder, "Dome", BALL, Vector3.one * 6.4, at(0, ridge + 2.4, 23), accent:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Glass, { Transparency = 0.35, CanCollide = false, CanQuery = false, CastShadow = false }))
		local crystal = roofPart(P(folder, "Crystal", BLOCK, Vector3.one * 2.2, at(0, ridge + 3, 23) * ON_CORNER, CRYSTAL, Enum.Material.Neon, ROOF))
		light(crystal, CRYSTAL, 20, 1)
		roofPart(P(folder, "Finial", BLOCK, Vector3.new(0.5, 3, 0.5), at(0, ridge + 6.8, 23), GOLD, Enum.Material.Metal, ROOF))
		for _, z in { 11.2, 34.8 } do
			roofPart(P(folder, "Eave", BLOCK, Vector3.new(42.4, 0.6, 0.6), at(0, GROUND + HALL_H - 0.4, z), GOLD, Enum.Material.Metal, ROOF))
		end
	end,
	-- A crystal chandelier hanging in the great hall.
	chandelier = function(folder, at, accent)
		local c = at(0, 13.5, 21)
		cyl(folder, "Ring", 0.5, 9, c, GOLD, Enum.Material.Metal, DECOR)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			P(folder, "Drop", BLOCK, Vector3.new(0.5, 1.6, 0.5), c * CFrame.new(math.sin(a) * 4.2, -1.1, math.cos(a) * 4.2) * ON_CORNER, if i % 2 == 0 then CRYSTAL else accent, Enum.Material.Neon, DECOR)
		end
		local heart = P(folder, "Heart", BLOCK, Vector3.one * 2, c * CFrame.new(0, -1.5, 0) * ON_CORNER, CRYSTAL, Enum.Material.Neon, DECOR)
		light(heart, CRYSTAL, 26, 1.3)
	end,
	-- The treasury crown floating above the front gable.
	crown = function(folder, at, accent)
		local c = at(0, GROUND + BASE_H + 7, -6.5)
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

-- Creates the visuals of every owned build that is missing (plus the starting room, which every
-- plot has) and removes those not owned, together with their rooms' pedestals.
function Blueprints.sync(plot: Model, owned: { [string]: boolean }, animate: boolean)
	local floor = plot:FindFirstChild("Floor") :: BasePart?
	if not floor then
		return
	end
	local cf = floor.CFrame
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local accent = (plot:GetAttribute("Accent") :: Color3?) or C(200, 170, 255)
	local root = plot:FindFirstChild("Builds") or Instance.new("Folder")
	root.Name = "Builds"
	root.Parent = plot
	local function has(id: string): boolean
		return id == "base" or owned[id] == true
	end
	for id, maker in MAKERS do
		local existing = root:FindFirstChild(id)
		if has(id) and not existing then
			local folder = Instance.new("Model")
			folder.Name = id
			maker(folder, at, accent, plot)
			folder.Parent = root
			if animate and id ~= "base" then
				animateIn(folder)
			end
		elseif not has(id) and existing then
			existing:Destroy()
		end
	end
	local pedestals = plot:FindFirstChild("Pedestals")
	for _, ped in (if pedestals then pedestals:GetChildren() else {}) do
		local room = ped:GetAttribute("Room")
		if type(room) == "string" and not has(room) then
			ped:Destroy()
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
