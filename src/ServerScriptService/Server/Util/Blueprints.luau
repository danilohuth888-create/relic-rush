--!strict
-- The treasury house. Every plot is a paved yard with a cellar dug out below (see
-- tools/world/BuildAetheria.luau); this module builds the house on it at runtime, in the
-- yard's local frame (floor top at y = 0.6, cellar floor at y = -9.4, local -Z faces the plaza):
--
--   ground floor                                   below ground (y = -9.4)
--   z 46 +--------+-----------+--------+           z 46 +-----------------------------+
--        | map    |  RELIC    | trophy |                |  cellar: pedestals 5-12,    |
--        | room   |  HALL 1-4 | room   |                |  stairs up into relic hall  |
--   z 26 +--------+---door----+--------+           z 26 +------------arch-------------+
--        | living | entrance  | library|                |  vault: pedestals 13-20     |
--        | room   | hall      |        |                |                             |
--   z 4  +--------+---door----+--------+           z 4  +-----------------------------+
--        |  yard: garden, chest, pond  |
--   z -20+-----------------------------+
--       x -20                      20
--
-- Relics only ever stand in the relic hall, the cellar and the vault; every other room is
-- built on its foundation from a pad that stands where the build appears (Shared/Builds).
-- Builds live in PlotN.Builds.<id>. Rooms add their pedestals to PlotN.Pedestals with the
-- attributes Slot, Runtime and Room; they disappear again when the room is not owned. Parts
-- with a HideWhen attribute (foundations, the stair cover, the vault's barred door) vanish once
-- that build is owned. Roof parts carry the "TreasuryRoof" tag so clients can fade them while
-- the player is inside. The yard holds the treasure chest (ChestZone, PendingLabel), and
-- PlotN.Preview shows a see-through version of the build the owner is standing next to.

local TweenService = game:GetService("TweenService")

local C = Color3.fromRGB
local GOLD = C(255, 200, 80)
local STONE = C(222, 212, 196)
local STONE_DARK = C(184, 172, 158)
local PLASTER = C(226, 212, 194)
local WOOD = C(132, 94, 72)
local WARM = C(255, 190, 110)
local CRYSTAL = C(120, 230, 255)
local BEAM = C(110, 76, 58) -- timber framing
local PLINTH = C(150, 142, 150)
local VAULT = C(120, 128, 150)
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

-- Timber framing and a stone plinth on a wall built by wall(), plus shutters and a flower box
-- at every window on the outside (outward = +1 or -1 along the wall's normal).
local function facade(parent: Instance, at: At, alongX: boolean, fixed: number, a: number, b: number, height: number, openings: { Opening }, outward: number, accent: Color3)
	local top = GROUND + height
	local function box(name: string, u0: number, u1: number, y0: number, y1: number, depth: number, color: Color3, material: Enum.Material?, normalOffset: number?)
		if u1 - u0 < 0.05 then
			return
		end
		local u, y, n = (u0 + u1) / 2, (y0 + y1) / 2, fixed + (normalOffset or 0)
		if alongX then
			P(parent, name, BLOCK, Vector3.new(u1 - u0, y1 - y0, depth), at(u, y, n), color, material, DECOR)
		else
			P(parent, name, BLOCK, Vector3.new(depth, y1 - y0, u1 - u0), at(n, y, u), color, material, DECOR)
		end
	end
	-- Plinth and the low beam run along the wall except across doors.
	local cursor = a
	local posts = { a + 0.3, b - 0.3 }
	for _, o in openings do
		local left, right = o.c - o.w / 2, o.c + o.w / 2
		if o.bottom <= GROUND + 0.01 then
			box("Plinth", cursor, left, GROUND, GROUND + 1.2, 1.5, PLINTH, Enum.Material.Slate)
			box("Beam", cursor, left, GROUND + 3, GROUND + 3.5, 1.3, BEAM, Enum.Material.Wood)
			cursor = right
		end
		table.insert(posts, left - 0.3)
		table.insert(posts, right + 0.3)
	end
	box("Plinth", cursor, b, GROUND, GROUND + 1.2, 1.5, PLINTH, Enum.Material.Slate)
	box("Beam", cursor, b, GROUND + 3, GROUND + 3.5, 1.3, BEAM, Enum.Material.Wood)
	box("Beam", a, b, top - 0.8, top - 0.2, 1.3, BEAM, Enum.Material.Wood)
	-- Posts at the ends, beside every opening and in long blank stretches.
	table.sort(posts)
	local filled = {}
	for i, u in posts do
		table.insert(filled, u)
		local nextU = posts[i + 1]
		if nextU and nextU - u > 9 then
			table.insert(filled, (u + nextU) / 2)
		end
	end
	for _, u in filled do
		box("Post", u - 0.3, u + 0.3, GROUND + 1.2, top - 0.2, 1.3, BEAM, Enum.Material.Wood)
	end
	-- Shutters and flower boxes on the outside of windows.
	for _, o in openings do
		if o.bottom > GROUND + 0.01 then
			local h = o.top - o.bottom
			for _, side in { -1, 1 } do
				local u = o.c + side * (o.w / 2 + o.w * 0.22)
				box("Shutter", u - o.w * 0.2, u + o.w * 0.2, o.bottom, o.top, 0.25, accent:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Wood, outward * 0.65)
			end
			box("FlowerBox", o.c - o.w / 2 - 0.3, o.c + o.w / 2 + 0.3, o.bottom - 0.7, o.bottom - 0.1, 0.9, BEAM, Enum.Material.Wood, outward * 0.9)
			for k = 0, 3 do
				local u = o.c - o.w / 2 + (k + 0.5) * o.w / 4
				local n = fixed + outward * 0.9
				local cf = if alongX then at(u, o.bottom + 0.1, n) else at(n, o.bottom + 0.1, u)
				P(parent, "Bloom", BALL, Vector3.one * 0.7, cf, if k % 2 == 0 then C(255, 140, 180) else C(255, 220, 110), nil, DECOR)
			end
			if h > 0 then
				box("Sill", o.c - o.w / 2 - 0.2, o.c + o.w / 2 + 0.2, o.bottom - 0.15, o.bottom, 1.4, STONE)
			end
		end
	end
end

-- Interior pieces -------------------------------------------------------------------------------
local function rug(parent: Instance, cf: CFrame, w: number, d: number, accent: Color3)
	P(parent, "Rug", BLOCK, Vector3.new(w, 0.06, d), cf * CFrame.new(0, GROUND + 0.1, 0), accent:Lerp(C(120, 40, 60), 0.5), Enum.Material.Fabric, DECOR)
	P(parent, "RugInner", BLOCK, Vector3.new(w - 1.2, 0.07, d - 1.2), cf * CFrame.new(0, GROUND + 0.11, 0), accent:Lerp(C(240, 220, 190), 0.55), Enum.Material.Fabric, DECOR)
end

-- A framed painting on a wall; face points into the room.
local function painting(parent: Instance, cf: CFrame, w: number, h: number, color: Color3)
	P(parent, "Frame", BLOCK, Vector3.new(w + 0.5, h + 0.5, 0.2), cf, GOLD, Enum.Material.Metal, DECOR)
	P(parent, "Canvas", BLOCK, Vector3.new(w, h, 0.22), cf, color, nil, DECOR)
	P(parent, "Hill", BALL, Vector3.new(w * 0.8, h * 0.5, 0.24), cf * CFrame.new(-w * 0.15, -h * 0.35, 0), color:Lerp(C(60, 140, 90), 0.6), nil, DECOR)
	P(parent, "Sun", BALL, Vector3.new(h * 0.25, h * 0.25, 0.24), cf * CFrame.new(w * 0.25, h * 0.2, 0), C(255, 230, 140), Enum.Material.Neon, DECOR)
end

local function plant(parent: Instance, cf: CFrame)
	P(parent, "Pot", CYL, Vector3.new(1.4, 1.6, 1.6), cf * CFrame.new(0, GROUND + 0.7, 0) * UPRIGHT, C(190, 110, 80), nil, DECOR)
	P(parent, "Leaves", BALL, Vector3.new(2.2, 2, 2.2), cf * CFrame.new(0, GROUND + 2.2, 0), C(80, 170, 100), nil, DECOR)
	P(parent, "LeavesTop", BALL, Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(0.3, GROUND + 3, 0.2), C(110, 200, 120), nil, DECOR)
end

local function bookshelf(parent: Instance, cf: CFrame, w: number, h: number)
	P(parent, "Shelf", BLOCK, Vector3.new(w, h, 1), cf * CFrame.new(0, GROUND + h / 2, 0), BEAM, Enum.Material.Wood)
	local colors = { C(190, 70, 70), C(70, 120, 190), C(90, 160, 90), C(220, 180, 80), C(150, 90, 170) }
	local rows = math.floor(h / 1.6)
	for r = 1, rows - 1 do
		local y = GROUND + r * 1.6
		P(parent, "Board", BLOCK, Vector3.new(w - 0.2, 0.15, 0.9), cf * CFrame.new(0, y - 0.6, -0.1), WOOD, Enum.Material.Wood, DECOR)
		local x = -w / 2 + 0.4
		local k = r
		while x < w / 2 - 0.5 do
			local bw = 0.3 + ((k * 7) % 3) * 0.1
			P(parent, "Book", BLOCK, Vector3.new(bw, 1.1 - (k % 3) * 0.12, 0.7), cf * CFrame.new(x + bw / 2, y - 0.05, -0.2), colors[k % #colors + 1], nil, DECOR)
			x += bw + 0.04
			k += 1
		end
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

-- While a preview is being built, pedestals go into the preview instead of the plot.
local previewTarget: Instance? = nil

-- A pedestal in a room; PlotService ghosts it until its slot is unlocked.
local function pedestal(plot: Model, room: string, slot: number, base: CFrame)
	local folder = previewTarget or plot:FindFirstChild("Pedestals") :: Instance
	if not previewTarget and folder:FindFirstChild("Pedestal" .. slot) then
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

local CF = -9.4 -- cellar floor top (Shared/Builds.CellarFloor)
local RELIC_H = 10
local HALL_H = 11
local ROOM_H = 9
local CELLAR_H = 8.6
local STONE_CELLAR = C(128, 132, 146)
local VELVET = C(70, 26, 44)

-- Footprints of the rooms that are built on foundations (x0, x1, z0, z1).
local ROOMS: { [string]: { number } } = {
	hall = { -8, 8, 4, 26 },
	living = { -20, -8, 4, 26 },
	library = { 8, 20, 4, 26 },
	maproom = { -20, -10, 26, 46 },
	trophy = { 10, 20, 26, 46 },
}

local function hideWhen(part: Instance, id: string): Instance
	part:SetAttribute("HideWhen", id)
	return part
end

-- A plain stone box for cellar walls and floors (any height, unlike wall()).
local function slab(parent: Instance, name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, at: At, color: Color3, material: Enum.Material?, extra: { [string]: any }?): Part
	return P(parent, name, BLOCK, Vector3.new(x1 - x0, y1 - y0, z1 - z0), at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, material, extra)
end

local function glassPane(parent: Instance, cf: CFrame, w: number, h: number, accent: Color3)
	P(parent, "Glass", BLOCK, Vector3.new(w, h, 0.3), cf, accent:Lerp(Color3.new(1, 1, 1), 0.55), Enum.Material.Glass, { Transparency = 0.35 })
	P(parent, "MullionV", BLOCK, Vector3.new(0.25, h, 0.45), cf, GOLD, Enum.Material.Metal, DECOR)
	P(parent, "MullionH", BLOCK, Vector3.new(w, 0.25, 0.45), cf, GOLD, Enum.Material.Metal, DECOR)
end

local function torch(parent: Instance, cf: CFrame, color: Color3)
	P(parent, "Bracket", BLOCK, Vector3.new(0.4, 1.2, 0.8), cf, BEAM, Enum.Material.Wood, DECOR)
	local flame = P(parent, "Flame", BALL, Vector3.new(0.7, 1, 0.7), cf * CFrame.new(0, 0.9, -0.2), color, Enum.Material.Neon, DECOR)
	light(flame, color, 18, 1.1)
end

local function crystalCluster(parent: Instance, base: CFrame, color: Color3, scale: number)
	for k = 0, 4 do
		local h = (2 + (k % 3) * 1.2) * scale
		local a = k * 1.3
		P(parent, "Crystal", BLOCK, Vector3.new(0.9 * scale, h, 0.9 * scale), base * CFrame.new(math.cos(a) * 0.9 * scale, h / 2 - 0.2, math.sin(a) * 0.9 * scale) * CFrame.Angles(math.cos(a) * 0.3, a, math.sin(a) * 0.3), color, Enum.Material.Neon, DECOR)
	end
end

local MAKERS: { [string]: Maker } = {
	-- The relic hall every treasury starts with: pedestals 1-4, the owner's banner and build plan
	-- board, the yard's treasure chest and the foundations of the rooms still to come.
	base = function(folder, at, accent, plot)
		local x0, x1, z0, z1 = -10, 10, 26, 46
		wall(folder, at, true, z0, x0, x1, RELIC_H, { door(0, 5, 8) }, PLASTER)
		wall(folder, at, true, z1, x0, x1, RELIC_H, {}, PLASTER)
		for _, x in { x0, x1 } do
			wall(folder, at, false, x, z0, z1, RELIC_H, {}, PLASTER)
			for _, z in { z0, z1 } do
				P(folder, "Corner", BLOCK, Vector3.new(1.6, RELIC_H + 0.8, 1.6), at(x, GROUND + (RELIC_H + 0.8) / 2, z), STONE_DARK)
			end
		end
		facade(folder, at, true, z0, x0, x1, RELIC_H, { door(0, 5, 8) }, -1, accent)
		facade(folder, at, true, z1, x0, x1, RELIC_H, {}, 1, accent)
		for _, x in { x0, x1 } do
			facade(folder, at, false, x, z0, z1, RELIC_H, {}, if x < 0 then -1 else 1, accent)
		end
		roofAlongZ(folder, at, 0, 10, z0, z1, GROUND + RELIC_H, GROUND + RELIC_H + 4.6, accent)
		-- A golden archway and the open doors.
		P(folder, "ArchTop", BLOCK, Vector3.new(6.4, 1, 1.6), at(0, GROUND + 8.5, z0), GOLD, Enum.Material.Metal)
		for _, side in { -1, 1 } do
			P(folder, "ArchPost", BLOCK, Vector3.new(0.7, 8, 1.6), at(side * 2.85, GROUND + 4, z0), GOLD, Enum.Material.Metal, DECOR)
			P(folder, "DoorLeaf", BLOCK, Vector3.new(0.3, 7.6, 2.4), at(side * 2.35, GROUND + 3.8, z0 + 1.3), BEAM, Enum.Material.Wood, DECOR)
		end
		-- Inside: velvet floor, a rune circle, crystal sconces.
		P(folder, "Velvet", BLOCK, Vector3.new(19, 0.08, 19), at(0, GROUND + 0.05, 36), accent:Lerp(VELVET, 0.8), Enum.Material.Fabric, DECOR)
		P(folder, "RuneRing", CYL, Vector3.new(0.1, 13, 13), at(0, GROUND + 0.1, 34.2) * UPRIGHT, accent, Enum.Material.Neon, DECOR)
		P(folder, "RuneInner", CYL, Vector3.new(0.11, 12.4, 12.4), at(0, GROUND + 0.1, 34.2) * UPRIGHT, accent:Lerp(VELVET, 0.8), Enum.Material.Fabric, DECOR)
		for _, x in { -9.4, 9.4 } do
			for _, z in { 31, 38 } do
				local sconce = P(folder, "Sconce", BLOCK, Vector3.one * 0.9, at(x, GROUND + 6, z) * ON_CORNER, CRYSTAL, Enum.Material.Neon, DECOR)
				if z == 31 then
					light(sconce, accent:Lerp(CRYSTAL, 0.5), 16, 0.9)
				end
			end
		end
		painting(folder, at(0, GROUND + 6.5, 45.4) * CFrame.Angles(0, math.pi, 0), 6, 3.4, accent:Lerp(C(120, 160, 255), 0.5))

		local banner = P(folder, "Banner", BLOCK, Vector3.new(3.6, 5.6, 0.3), at(6, 5.6, z0 - 0.65), accent)
		banner:SetAttribute("BaseColor", accent)
		local board = P(folder, "PlanBoard", BLOCK, Vector3.new(4.6, 3, 0.4), at(-6, 5.4, z0 - 0.7), WOOD)
		boardLabel(board, "UpgradeLabel", "Bauplan")
		local accents = Instance.new("Folder")
		accents.Name = "Accents"
		P(accents, "RuneStrip", BLOCK, Vector3.new(20.4, 0.4, 0.3), at(0, GROUND + RELIC_H - 0.6, z0 - 0.6), accent)
		for _, x in { -10, 10 } do
			P(accents, "Crystal", BLOCK, Vector3.one * 1.4, at(x, GROUND + RELIC_H + 1.8, z0 - 1) * ON_CORNER, accent, nil, DECOR)
		end
		accents.Parent = folder

		for i, pos in { { -4.5, 31 }, { 4.5, 31 }, { -4.5, 37.5 }, { 4.5, 37.5 } } do
			pedestal(plot, "base", i, at(pos[1], GROUND, pos[2]))
		end

		-- Foundations: a stone curb around every room that is not built yet.
		for id, r in ROOMS do
			local curb = Instance.new("Model")
			curb.Name = "Foundation_" .. id
			local h = if id == "hall" then 0.3 else 0.26
			for _, edge in { { r[1], r[2], r[3], r[3] }, { r[1], r[2], r[4], r[4] }, { r[1], r[1], r[3], r[4] }, { r[2], r[2], r[3], r[4] } } do
				local w = math.max(edge[2] - edge[1], 0.6)
				local d = math.max(edge[4] - edge[3], 0.6)
				hideWhen(P(curb, "Curb", BLOCK, Vector3.new(w, h, d), at((edge[1] + edge[2]) / 2, GROUND + h / 2, (edge[3] + edge[4]) / 2), PLINTH, Enum.Material.Slate, DECOR), id)
			end
			hideWhen(P(curb, "Plot", BLOCK, Vector3.new(r[2] - r[1] - 1, 0.05, r[4] - r[3] - 1), at((r[1] + r[2]) / 2, GROUND + 0.03, (r[3] + r[4]) / 2), C(200, 190, 175), Enum.Material.Concrete, DECOR), id)
			curb.Parent = folder
		end

		-- The treasure chest in the yard: the relics' coins pile up here until the owner walks in.
		local chest = Instance.new("Model")
		chest.Name = "TreasureChest"
		-- beside the path, so it is not in the way of the camera at the spawn
		local c = at(-6.5, GROUND, -13.5)
		P(chest, "ChestZone", CYL, Vector3.new(0.3, 6.4, 6.4), c * CFrame.new(0, 0.15, 0) * UPRIGHT, STONE_DARK, nil, { CanCollide = false })
		P(chest, "Ring", CYL, Vector3.new(0.12, 7, 7), c * CFrame.new(0, 0.05, 0) * UPRIGHT, accent, Enum.Material.Neon, DECOR)
		local box = c * CFrame.new(0, 1.4, 0)
		P(chest, "Box", BLOCK, Vector3.new(4, 2, 2.8), box, WOOD, Enum.Material.Wood, DECOR)
		for _, x in { -1.5, 1.5 } do
			P(chest, "Band", BLOCK, Vector3.new(0.35, 2.05, 2.9), box * CFrame.new(x, 0, 0), GOLD, Enum.Material.Metal, DECOR)
		end
		P(chest, "Lock", BLOCK, Vector3.new(0.6, 0.7, 0.2), box * CFrame.new(0, 0.3, -1.45), GOLD, Enum.Material.Metal, DECOR)
		P(chest, "Lid", BLOCK, Vector3.new(4, 0.6, 2.8), box * CFrame.new(0, 1.2, 1.6) * CFrame.Angles(math.rad(-55), 0, 0) * CFrame.new(0, 0, -1.2), WOOD, Enum.Material.Wood, DECOR)
		local pile = P(chest, "GoldPile", BALL, Vector3.new(3.4, 1.2, 2.2), box * CFrame.new(0, 1, 0), GOLD, Enum.Material.Neon, DECOR)
		light(pile, GOLD, 12, 0.9)
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(GOLD)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.5, 0)
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Rate = 5
		sparkle.Speed = NumberRange.new(1.5, 3)
		sparkle.SpreadAngle = Vector2.new(30, 30)
		sparkle.Parent = pile
		local gui = Instance.new("BillboardGui")
		gui.Name = "ChestTag"
		gui.Size = UDim2.fromScale(4.6, 1)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
		gui.MaxDistance = 60
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "PendingLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = ""
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = C(255, 220, 110)
		label.TextStrokeColor3 = C(110, 60, 10)
		label.TextStrokeTransparency = 0.2
		label.Parent = gui
		gui.Parent = pile
		chest.Parent = folder
	end,

	-- Warm lamp posts in the corners of the relic hall.
	lanterns = function(folder, at)
		for i, pos in { { -8.4, 27.6 }, { 8.4, 27.6 }, { -8.4, 40 }, { 8.4, 40 } } do
			P(folder, "Post", BLOCK, Vector3.new(0.5, 5, 0.5), at(pos[1], 3.1, pos[2]), WOOD)
			P(folder, "Foot", BLOCK, Vector3.new(1.2, 0.4, 1.2), at(pos[1], 0.8, pos[2]), WOOD)
			P(folder, "Cap", BLOCK, Vector3.new(1.4, 0.3, 1.4), at(pos[1], 6.95, pos[2]), WOOD)
			local lamp = P(folder, "Lamp", BALL, Vector3.one * 1.1, at(pos[1], 6.2, pos[2]), WARM, Enum.Material.Neon, DECOR)
			if i <= 2 then
				light(lamp, WARM, 16, 1.1)
			end
		end
	end,

	-- The treasure cellar below the relic hall: stairs down from the hall's back, pedestals 5-12,
	-- stone walls, beams and torches. A barred door in its front wall leads to the vault later.
	cellar = function(folder, at, accent, plot)
		local top = CF + CELLAR_H
		slab(folder, "CellarFloor", -20, 20, CF - 0.6, CF, 26, 46, at, STONE_CELLAR, Enum.Material.Slate)
		slab(folder, "FloorInlay", -18, 18, CF, CF + 0.05, 28, 40, at, accent:Lerp(VELVET, 0.8), Enum.Material.Fabric, DECOR)
		for _, x in { -19.6, 19.6 } do
			slab(folder, "Wall", x - 0.4, x + 0.4, CF, top, 26, 46, at, STONE_CELLAR, Enum.Material.Slate)
		end
		slab(folder, "Wall", -20, 20, CF, top, 45.2, 46, at, STONE_CELLAR, Enum.Material.Slate)
		-- Front wall with an archway towards the vault.
		slab(folder, "Wall", -20, -3, CF, top, 26, 26.8, at, STONE_CELLAR, Enum.Material.Slate)
		slab(folder, "Wall", 3, 20, CF, top, 26, 26.8, at, STONE_CELLAR, Enum.Material.Slate)
		slab(folder, "Wall", -3, 3, CF + 7, top, 26, 26.8, at, STONE_CELLAR, Enum.Material.Slate)
		hideWhen(slab(folder, "SealedDoor", -3, 3, CF, CF + 7, 26.1, 26.6, at, BEAM, Enum.Material.Wood), "vault")
		for _, x in { -2.2, -0.7, 0.7, 2.2 } do
			hideWhen(slab(folder, "Bar", x - 0.12, x + 0.12, CF, CF + 7, 26.65, 26.8, at, C(90, 90, 100), Enum.Material.Metal, DECOR), "vault")
		end
		for _, z in { 30.5, 36, 41.5 } do
			slab(folder, "Beam", -19.2, 19.2, top - 0.9, top - 0.3, z - 0.4, z + 0.4, at, BEAM, Enum.Material.Wood, DECOR)
		end
		for _, pos in { { -19.1, 33.5, math.pi / 2 }, { 19.1, 33.5, -math.pi / 2 }, { -19.1, 41, math.pi / 2 }, { 19.1, 41, -math.pi / 2 } } do
			torch(folder, at(pos[1], CF + 5.2, pos[2]) * CFrame.Angles(0, pos[3], 0), WARM)
		end
		-- Stairs from the relic hall floor (x = -8) down to the cellar (x = 8).
		local steps = 13
		local rise = (GROUND - CF) / steps
		local run = 16 / steps
		for k = 0, steps - 1 do
			local stepTop = GROUND - rise * (k + 1)
			slab(folder, "Step", -8 + run * k, -8 + run * (k + 1), CF, stepTop, 42, 45.4, at, STONE_DARK, Enum.Material.Slate)
		end
		-- Railing around the stairwell up in the relic hall (the top end stays open).
		slab(folder, "Rail", -6, 8.6, GROUND + 2.6, GROUND + 2.9, 41.7, 41.95, at, GOLD, Enum.Material.Metal)
		slab(folder, "Rail", 8.4, 8.6, GROUND + 2.6, GROUND + 2.9, 41.7, 45.4, at, GOLD, Enum.Material.Metal)
		for x = -6, 8, 2 do
			slab(folder, "Baluster", x - 0.1, x + 0.1, GROUND, GROUND + 2.6, 41.75, 41.9, at, GOLD, Enum.Material.Metal, DECOR)
		end
		for i, pos in { { -15, 30 }, { -5, 30 }, { 5, 30 }, { 15, 30 }, { -15, 37 }, { -5, 37 }, { 5, 37 }, { 15, 37 } } do
			pedestal(plot, "cellar", 4 + i, at(pos[1], CF, pos[2]))
		end
	end,

	-- The vault under the entrance hall: gold floor, pillars, and pedestals 13-20.
	vault = function(folder, at, accent, plot)
		local top = CF + CELLAR_H
		slab(folder, "VaultFloor", -20, 20, CF - 0.6, CF, 4, 26, at, STONE_CELLAR, Enum.Material.Slate)
		slab(folder, "GoldInlay", -18, 18, CF, CF + 0.05, 6, 24, at, C(235, 200, 120), Enum.Material.Metal, DECOR)
		for _, x in { -19.6, 19.6 } do
			slab(folder, "Wall", x - 0.4, x + 0.4, CF, top, 4, 26, at, C(130, 130, 150), Enum.Material.Slate)
		end
		slab(folder, "Wall", -20, 20, CF, top, 4, 4.8, at, C(130, 130, 150), Enum.Material.Slate)
		-- Golden frame around the archway from the cellar.
		slab(folder, "ArchFrame", -3.5, 3.5, CF + 7, CF + 7.6, 25.7, 26.2, at, GOLD, Enum.Material.Metal, DECOR)
		for _, x in { -3.3, 3.3 } do
			slab(folder, "ArchFrame", x - 0.25, x + 0.25, CF, CF + 7, 25.7, 26.2, at, GOLD, Enum.Material.Metal, DECOR)
		end
		-- The heavy round vault door stands open beside the arch.
		local doorCf = at(-6.5, CF + 3.6, 24.6) * CFrame.Angles(0, math.rad(15), 0)
		P(folder, "VaultDoor", CYL, Vector3.new(0.8, 7, 7), doorCf * CFrame.Angles(0, math.pi / 2, 0), C(170, 175, 190), Enum.Material.Metal, DECOR)
		P(folder, "VaultWheel", CYL, Vector3.new(0.4, 3, 3), doorCf * CFrame.new(0, 0, -0.5) * CFrame.Angles(0, math.pi / 2, 0), GOLD, Enum.Material.Metal, DECOR)
		for _, x in { -10, 0, 10 } do
			for _, z in { 7, 15 } do
				if not (x == 0 and z == 15) then
					slab(folder, "Pillar", x - 0.7, x + 0.7, CF, top, z - 0.7, z + 0.7, at, C(200, 195, 210), Enum.Material.Marble)
					slab(folder, "PillarCap", x - 0.9, x + 0.9, top - 0.6, top, z - 0.9, z + 0.9, at, GOLD, Enum.Material.Metal, DECOR)
				end
			end
		end
		for _, pos in { { -19.1, 9, math.pi / 2 }, { 19.1, 9, -math.pi / 2 }, { -19.1, 21, math.pi / 2 }, { 19.1, 21, -math.pi / 2 } } do
			torch(folder, at(pos[1], CF + 5.2, pos[2]) * CFrame.Angles(0, pos[3], 0), accent:Lerp(WARM, 0.5))
		end
		for i, pos in { { -15, 19 }, { -5, 19 }, { 5, 19 }, { 15, 19 }, { -15, 11 }, { -5, 11 }, { 5, 11 }, { 15, 11 } } do
			pedestal(plot, "vault", 12 + i, at(pos[1], CF, pos[2]))
		end
	end,

	-- The entrance hall: tall room between the yard and the relic hall, side doors to the wings.
	hall = function(folder, at, accent)
		local x0, x1, z0, z1 = -8, 8, 4, 26
		local front = { door(0, 6, 8.5), window(-5, 2.6, 3.6, 8.2), window(5, 2.6, 3.6, 8.2) }
		wall(folder, at, true, z0, x0, x1, HALL_H, front, PLASTER)
		for _, x in { x0, x1 } do
			wall(folder, at, false, x, z0, z1, HALL_H, { door(15, 4, 8) }, PLASTER)
			for _, z in { z0, z1 } do
				P(folder, "Corner", BLOCK, Vector3.new(1.6, HALL_H + 0.8, 1.6), at(x, GROUND + (HALL_H + 0.8) / 2, z), STONE_DARK)
			end
		end
		facade(folder, at, true, z0, x0, x1, HALL_H, front, -1, accent)
		slab(folder, "Filler", x0, x1, GROUND + RELIC_H, GROUND + HALL_H, 25.1, 25.6, at, PLASTER)
		roofAlongZ(folder, at, 0, 8, z0, 25.4, GROUND + HALL_H, GROUND + HALL_H + 4.8, accent)
		for _, x in { -5, 5 } do
			glassPane(folder, at(x, 5.9, z0), 2.6, 4.6, accent)
		end
		-- Marble floor with a border, plants by the door.
		slab(folder, "Marble", x0 + 0.5, x1 - 0.5, GROUND, GROUND + 0.06, z0 + 0.5, z1 - 0.5, at, C(235, 232, 238), Enum.Material.Marble, DECOR)
		slab(folder, "Border", x0 + 0.5, x1 - 0.5, GROUND, GROUND + 0.07, z0 + 1.2, z0 + 1.6, at, accent, nil, DECOR)
		for _, x in { -5.8, 5.8 } do
			plant(folder, at(x, 0, z0 + 2))
		end
		painting(folder, at(-7.4, GROUND + 5.8, 9) * CFrame.Angles(0, -math.pi / 2, 0), 3.2, 2.4, accent:Lerp(C(255, 200, 150), 0.5))
		painting(folder, at(7.4, GROUND + 5.8, 9) * CFrame.Angles(0, math.pi / 2, 0), 3.2, 2.4, accent:Lerp(C(150, 220, 200), 0.5))
		local lamp = P(folder, "HallGlow", BALL, Vector3.one * 0.6, at(0, GROUND + HALL_H - 0.6, 15), WARM, Enum.Material.Neon, DECOR)
		light(lamp, WARM, 22, 0.8)
	end,

	-- A red runner from the yard through the hall into the relic hall.
	carpet = function(folder, at)
		P(folder, "Runner", BLOCK, Vector3.new(3, 0.1, 47), at(0, 0.7, 16.5), C(190, 40, 70), Enum.Material.Fabric, DECOR)
		for _, x in { -1.65, 1.65 } do
			P(folder, "Border", BLOCK, Vector3.new(0.3, 0.12, 47), at(x, 0.71, 16.5), GOLD, Enum.Material.Metal, DECOR)
		end
	end,

	-- Guardian statues flanking the door to the relic hall.
	statues = function(folder, at, accent)
		for _, x in { -4.6, 4.6 } do
			P(folder, "Plinth", BLOCK, Vector3.new(2.6, 1.2, 2.6), at(x, 1.2, 23.6), STONE_DARK)
			P(folder, "Body", BLOCK, Vector3.new(1.8, 3.4, 1.4), at(x, 3.5, 23.6), STONE)
			P(folder, "Head", BLOCK, Vector3.new(1.4, 1.4, 1.4), at(x, 5.9, 23.6), STONE)
			P(folder, "Eyes", BLOCK, Vector3.new(1, 0.25, 0.1), at(x, 6, 22.88), accent, Enum.Material.Neon, DECOR)
			P(folder, "Spear", BLOCK, Vector3.new(0.25, 6.5, 0.25), at(x + (if x < 0 then 1.2 else -1.2), 4.4, 23.4), GOLD, Enum.Material.Metal)
		end
	end,

	-- A crystal chandelier in the entrance hall.
	chandelier = function(folder, at, accent)
		local c = at(0, 9.6, 15)
		cyl(folder, "Ring", 0.5, 8, c, GOLD, Enum.Material.Metal, DECOR)
		P(folder, "Chain", BLOCK, Vector3.new(0.2, 2.4, 0.2), c * CFrame.new(0, 1.4, 0), GOLD, Enum.Material.Metal, DECOR)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			P(folder, "Drop", BLOCK, Vector3.new(0.5, 1.6, 0.5), c * CFrame.new(math.sin(a) * 3.7, -1.1, math.cos(a) * 3.7) * ON_CORNER, if i % 2 == 0 then CRYSTAL else accent, Enum.Material.Neon, DECOR)
		end
		local heart = P(folder, "Heart", BLOCK, Vector3.one * 1.8, c * CFrame.new(0, -1.4, 0) * ON_CORNER, CRYSTAL, Enum.Material.Neon, DECOR)
		light(heart, CRYSTAL, 24, 1.2)
	end,

	-- The living room (west): fireplace wall, windows to the garden.
	living = function(folder, at, accent)
		local x0, x1, z0, z1 = -20, -8, 4, 26
		local outer = { window(9.5, 3.6, 3.6, 8), window(20.5, 3.6, 3.6, 8) }
		wall(folder, at, false, x0, z0, z1, ROOM_H, outer, PLASTER)
		wall(folder, at, true, z0, x0, x1, ROOM_H, { window(-14, 3.6, 3.6, 7.6) }, PLASTER)
		wall(folder, at, true, z1, x0, -10, ROOM_H, { door(-15, 3.6, 7.5) }, PLASTER)
		facade(folder, at, false, x0, z0, z1, ROOM_H, outer, -1, accent)
		facade(folder, at, true, z0, x0, x1, ROOM_H, { window(-14, 3.6, 3.6, 7.6) }, -1, accent)
		roofAlongZ(folder, at, -14, 6, z0, z1, GROUND + ROOM_H, GROUND + ROOM_H + 3.4, accent)
		for _, z in { 9.5, 20.5 } do
			glassPane(folder, at(x0, 5.8, z) * ALONG_Z, 3.6, 4.4, accent)
		end
		glassPane(folder, at(-14, 5.6, z0), 3.6, 4, accent)
		slab(folder, "Planks", x0 + 0.5, x1 - 0.5, GROUND, GROUND + 0.06, z0 + 0.5, z1 - 0.5, at, C(170, 120, 85), Enum.Material.WoodPlanks, DECOR)
		plant(folder, at(-18.6, 0, 5.8))
		painting(folder, at(-13, GROUND + 5.6, 25.4) * CFrame.Angles(0, math.pi, 0), 3.4, 2.4, accent:Lerp(C(255, 170, 120), 0.5))
	end,
	fireplace = function(folder, at)
		local c = at(-19.4, 0, 15) * CFrame.Angles(0, -math.pi / 2, 0)
		P(folder, "Hearth", BLOCK, Vector3.new(4.4, 4.6, 1.2), c * CFrame.new(0, GROUND + 2.3, 0), PLINTH, Enum.Material.Slate)
		P(folder, "Mantel", BLOCK, Vector3.new(4.8, 0.5, 1.6), c * CFrame.new(0, GROUND + 4.8, -0.2), BEAM, Enum.Material.Wood)
		P(folder, "Opening", BLOCK, Vector3.new(2.6, 2.2, 0.3), c * CFrame.new(0, GROUND + 1.4, -0.5), C(40, 30, 30), nil, DECOR)
		local fire = P(folder, "Fire", BALL, Vector3.new(1.6, 1.2, 0.8), c * CFrame.new(0, GROUND + 0.9, -0.7), C(255, 150, 60), Enum.Material.Neon, DECOR)
		light(fire, C(255, 160, 80), 16, 1.2)
		local flames = Instance.new("ParticleEmitter")
		flames.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		flames.Color = ColorSequence.new(C(255, 220, 120), C(255, 100, 40))
		flames.LightEmission = 1
		flames.Size = NumberSequence.new(0.5, 0)
		flames.Lifetime = NumberRange.new(0.4, 0.8)
		flames.Rate = 14
		flames.Speed = NumberRange.new(1, 2)
		flames.SpreadAngle = Vector2.new(15, 15)
		flames.Parent = fire
		local chimney = P(folder, "Chimney", BLOCK, Vector3.new(2.4, 7, 2.4), at(-18.6, GROUND + ROOM_H + 2.2, 15), PLINTH, Enum.Material.Slate, { CanCollide = false })
		roofPart(chimney)
		local cap = roofPart(P(folder, "ChimneyCap", BLOCK, Vector3.new(2.9, 0.4, 2.9), at(-18.6, GROUND + ROOM_H + 5.9, 15), STONE_DARK, nil, ROOF))
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(C(230, 230, 240))
		smoke.Transparency = NumberSequence.new(0.5, 1)
		smoke.Size = NumberSequence.new(1, 3)
		smoke.Lifetime = NumberRange.new(2, 3)
		smoke.Rate = 3
		smoke.Speed = NumberRange.new(2, 3)
		smoke.Parent = cap
	end,
	lounge = function(folder, at, accent)
		rug(folder, at(-14, 0, 15), 7, 8, accent)
		local sofa = at(-10.2, 0, 15)
		P(folder, "SofaSeat", BLOCK, Vector3.new(2.4, 1.2, 6), sofa * CFrame.new(0, GROUND + 0.9, 0), accent:Lerp(C(80, 60, 120), 0.4), Enum.Material.Fabric)
		P(folder, "SofaBack", BLOCK, Vector3.new(0.8, 2.4, 6), sofa * CFrame.new(1, GROUND + 1.8, 0), accent:Lerp(C(80, 60, 120), 0.5), Enum.Material.Fabric, DECOR)
		for _, z in { -3.1, 3.1 } do
			P(folder, "SofaArm", BLOCK, Vector3.new(2.4, 1.8, 0.6), sofa * CFrame.new(0, GROUND + 1.2, z), accent:Lerp(C(80, 60, 120), 0.5), Enum.Material.Fabric, DECOR)
		end
		P(folder, "Table", BLOCK, Vector3.new(2.4, 0.3, 3.4), at(-14, GROUND + 1.3, 15), BEAM, Enum.Material.Wood)
		P(folder, "TableLegs", BLOCK, Vector3.new(2, 1.1, 3), at(-14, GROUND + 0.6, 15), WOOD, Enum.Material.Wood, DECOR)
		P(folder, "Teapot", BALL, Vector3.new(0.8, 0.7, 0.8), at(-14, GROUND + 1.8, 14.2), C(240, 240, 250), nil, DECOR)
		local lamp = P(folder, "FloorLampShade", CYL, Vector3.new(1, 1.4, 1.4), at(-10.4, GROUND + 4.6, 19.4) * UPRIGHT, C(255, 230, 180), Enum.Material.Fabric, DECOR)
		P(folder, "FloorLamp", BLOCK, Vector3.new(0.25, 4, 0.25), at(-10.4, GROUND + 2, 19.4), BEAM, nil, DECOR)
		light(lamp, WARM, 12, 0.8)
	end,

	-- The library (east): tall shelves, a reading desk and a globe.
	library = function(folder, at, accent)
		local x0, x1, z0, z1 = 8, 20, 4, 26
		local outer = { window(9.5, 3.6, 3.6, 8), window(20.5, 3.6, 3.6, 8) }
		wall(folder, at, false, x1, z0, z1, ROOM_H, outer, PLASTER)
		wall(folder, at, true, z0, x0, x1, ROOM_H, { window(14, 3.6, 3.6, 7.6) }, PLASTER)
		wall(folder, at, true, z1, 10, x1, ROOM_H, { door(15, 3.6, 7.5) }, PLASTER)
		facade(folder, at, false, x1, z0, z1, ROOM_H, outer, 1, accent)
		facade(folder, at, true, z0, x0, x1, ROOM_H, { window(14, 3.6, 3.6, 7.6) }, -1, accent)
		roofAlongZ(folder, at, 14, 6, z0, z1, GROUND + ROOM_H, GROUND + ROOM_H + 3.4, accent)
		for _, z in { 9.5, 20.5 } do
			glassPane(folder, at(x1, 5.8, z) * ALONG_Z, 3.6, 4.4, accent)
		end
		glassPane(folder, at(14, 5.6, z0), 3.6, 4, accent)
		slab(folder, "Planks", x0 + 0.5, x1 - 0.5, GROUND, GROUND + 0.06, z0 + 0.5, z1 - 0.5, at, C(150, 105, 75), Enum.Material.WoodPlanks, DECOR)
		plant(folder, at(18.6, 0, 5.8))
	end,
	shelves = function(folder, at)
		bookshelf(folder, at(19.1, 0, 15) * CFrame.Angles(0, math.pi / 2, 0), 4.6, 7.2)
		bookshelf(folder, at(13.5, 0, 25.1), 5, 7.2)
		P(folder, "Ladder", BLOCK, Vector3.new(0.3, 7, 1.4), at(18.2, GROUND + 3.5, 17.6) * CFrame.Angles(0, 0, 0.18), BEAM, Enum.Material.Wood, DECOR)
	end,
	desk = function(folder, at, accent)
		P(folder, "Desk", BLOCK, Vector3.new(3.4, 0.3, 2), at(12, GROUND + 2.6, 23), BEAM, Enum.Material.Wood)
		P(folder, "DeskBody", BLOCK, Vector3.new(3, 2.4, 1.6), at(12, GROUND + 1.25, 23), WOOD, Enum.Material.Wood, DECOR)
		P(folder, "OpenBook", BLOCK, Vector3.new(1.4, 0.15, 1), at(12, GROUND + 2.85, 23) * CFrame.Angles(0, 0.3, 0), C(250, 240, 220), nil, DECOR)
		local flame = P(folder, "CandleFlame", BALL, Vector3.new(0.25, 0.4, 0.25), at(13.3, GROUND + 3.75, 22.6), WARM, Enum.Material.Neon, DECOR)
		P(folder, "Candle", BLOCK, Vector3.new(0.3, 0.8, 0.3), at(13.3, GROUND + 3.15, 22.6), C(250, 240, 220), nil, DECOR)
		light(flame, WARM, 9, 0.7)
		P(folder, "GlobeStand", BLOCK, Vector3.new(0.4, 2.6, 0.4), at(16.5, GROUND + 1.3, 21), BEAM, Enum.Material.Wood)
		local globe = P(folder, "Globe", BALL, Vector3.one * 2.2, at(16.5, GROUND + 3.4, 21), C(80, 150, 220), nil, DECOR)
		globe:AddTag("SpinSlow")
		P(folder, "GlobeRing", CYL, Vector3.new(0.15, 2.7, 2.7), at(16.5, GROUND + 3.4, 21), GOLD, Enum.Material.Metal, DECOR)
	end,

	-- The map room (behind the living room): a big table with the island drawn on it.
	maproom = function(folder, at, accent)
		local x0, x1, z0, z1 = -20, -10, 26, 46
		wall(folder, at, false, x0, z0, z1, ROOM_H, { window(36, 3.6, 3.6, 8) }, PLASTER)
		wall(folder, at, true, z1, x0, x1, ROOM_H, { window(-15, 3.4, 3.6, 7.6) }, PLASTER)
		facade(folder, at, false, x0, z0, z1, ROOM_H, { window(36, 3.6, 3.6, 8) }, -1, accent)
		facade(folder, at, true, z1, x0, x1, ROOM_H, { window(-15, 3.4, 3.6, 7.6) }, 1, accent)
		roofAlongZ(folder, at, -15, 5, z0, z1, GROUND + ROOM_H, GROUND + ROOM_H + 3, accent)
		glassPane(folder, at(x0, 5.8, 36) * ALONG_Z, 3.6, 4.4, accent)
		glassPane(folder, at(-15, 5.6, z1), 3.4, 4, accent)
		slab(folder, "Planks", x0 + 0.5, x1 - 0.5, GROUND, GROUND + 0.06, z0 + 0.5, z1 - 0.5, at, C(160, 115, 80), Enum.Material.WoodPlanks, DECOR)
		for _, z in { 30, 42 } do
			painting(folder, at(-10.6, GROUND + 5.5, z) * CFrame.Angles(0, math.pi / 2, 0), 3, 2.2, C(240, 220, 170))
		end
	end,
	maptable = function(folder, at)
		P(folder, "Table", BLOCK, Vector3.new(5, 0.4, 7), at(-15, GROUND + 2.8, 37), BEAM, Enum.Material.Wood)
		for _, x in { -2, 2 } do
			for _, z in { -3, 3 } do
				P(folder, "Leg", BLOCK, Vector3.new(0.4, 2.6, 0.4), at(-15 + x, GROUND + 1.3, 37 + z), WOOD, Enum.Material.Wood, DECOR)
			end
		end
		P(folder, "Parchment", BLOCK, Vector3.new(4.2, 0.06, 6), at(-15, GROUND + 3.03, 37), C(244, 228, 190), nil, DECOR)
		P(folder, "IsleSketch", CYL, Vector3.new(0.08, 3, 3), at(-15, GROUND + 3.08, 37.5) * UPRIGHT, C(160, 210, 140), nil, DECOR)
		P(folder, "MapX", BLOCK, Vector3.new(0.9, 0.1, 0.2), at(-14.5, GROUND + 3.13, 37) * CFrame.Angles(0, 0.8, 0), C(220, 40, 40), Enum.Material.Neon, DECOR)
		P(folder, "MapX", BLOCK, Vector3.new(0.9, 0.1, 0.2), at(-14.5, GROUND + 3.13, 37) * CFrame.Angles(0, -0.8, 0), C(220, 40, 40), Enum.Material.Neon, DECOR)
		P(folder, "Compass", CYL, Vector3.new(0.2, 1, 1), at(-16.5, GROUND + 3.15, 34.5) * UPRIGHT, GOLD, Enum.Material.Metal, DECOR)
		local lamp = P(folder, "MapLamp", BALL, Vector3.one * 0.7, at(-15, GROUND + 6.5, 37), WARM, Enum.Material.Neon, DECOR)
		light(lamp, WARM, 12, 0.8)
	end,

	-- The trophy room (behind the library): display cases with expedition trophies.
	trophy = function(folder, at, accent)
		local x0, x1, z0, z1 = 10, 20, 26, 46
		wall(folder, at, false, x1, z0, z1, ROOM_H, { window(36, 3.6, 3.6, 8) }, PLASTER)
		wall(folder, at, true, z1, x0, x1, ROOM_H, { window(15, 3.4, 3.6, 7.6) }, PLASTER)
		facade(folder, at, false, x1, z0, z1, ROOM_H, { window(36, 3.6, 3.6, 8) }, 1, accent)
		facade(folder, at, true, z1, x0, x1, ROOM_H, { window(15, 3.4, 3.6, 7.6) }, 1, accent)
		roofAlongZ(folder, at, 15, 5, z0, z1, GROUND + ROOM_H, GROUND + ROOM_H + 3, accent)
		glassPane(folder, at(x1, 5.8, 36) * ALONG_Z, 3.6, 4.4, accent)
		glassPane(folder, at(15, 5.6, z1), 3.4, 4, accent)
		slab(folder, "Planks", x0 + 0.5, x1 - 0.5, GROUND, GROUND + 0.06, z0 + 0.5, z1 - 0.5, at, C(140, 95, 70), Enum.Material.WoodPlanks, DECOR)
		rug(folder, at(15, 0, 36), 6, 12, accent)
	end,
	trophies = function(folder, at, accent)
		for i, z in { 30.5, 36, 41.5 } do
			local c = at(18.4, 0, z)
			P(folder, "Plinth", BLOCK, Vector3.new(2.4, 2.4, 3.4), c * CFrame.new(0, GROUND + 1.2, 0), WOOD, Enum.Material.Wood)
			P(folder, "Case", BLOCK, Vector3.new(2.2, 3, 3.2), c * CFrame.new(0, GROUND + 3.9, 0), C(220, 240, 255), Enum.Material.Glass, { Transparency = 0.6 })
			P(folder, "CaseTop", BLOCK, Vector3.new(2.4, 0.3, 3.4), c * CFrame.new(0, GROUND + 5.55, 0), GOLD, Enum.Material.Metal)
			local color = ({ GOLD, CRYSTAL, accent })[i]
			local trophy = P(folder, "Trophy", BLOCK, Vector3.one * 1.2, c * CFrame.new(0, GROUND + 3.8, 0) * ON_CORNER, color, Enum.Material.Neon, DECOR)
			if i == 2 then
				light(trophy, CRYSTAL, 12, 0.8)
			end
		end
	end,

	-- Front garden (west yard): picket fence, flower beds, a bench and two little trees.
	garden = function(folder, at, accent)
		local function fence(x0: number, z0: number, x1: number, z1: number)
			local length = (Vector3.new(x1, 0, z1) - Vector3.new(x0, 0, z0)).Magnitude
			local dir = CFrame.lookAt(at((x0 + x1) / 2, 0, (z0 + z1) / 2).Position, at(x1, 0, z1).Position)
			for _, y in { 0.9, 1.8 } do
				P(folder, "Rail", BLOCK, Vector3.new(0.25, 0.3, length), dir * CFrame.new(0, GROUND + y, 0), C(245, 240, 230), nil, DECOR)
			end
			for t = 0, length, 1.2 do
				P(folder, "Picket", BLOCK, Vector3.new(0.3, 2.4, 0.5), dir * CFrame.new(0, GROUND + 1.2, -length / 2 + t), C(250, 248, 240), nil, DECOR)
			end
		end
		fence(-19.7, -19.7, -4.6, -19.7)
		fence(4.6, -19.7, 19.7, -19.7)
		fence(-19.7, -19.7, -19.7, 3.5)
		fence(19.7, -19.7, 19.7, 3.5)
		for _, x in { -4.6, 4.6 } do
			P(folder, "GatePost", BLOCK, Vector3.new(0.7, 3.4, 0.7), at(x, GROUND + 1.7, -19.7), BEAM, Enum.Material.Wood)
			local lamp = P(folder, "GateLamp", BALL, Vector3.one * 0.9, at(x, GROUND + 3.8, -19.7), WARM, Enum.Material.Neon, DECOR)
			light(lamp, WARM, 12, 0.8)
		end
		P(folder, "Bed", BLOCK, Vector3.new(12, 0.5, 1.4), at(-12, GROUND + 0.25, -18.8), C(120, 84, 62), nil, DECOR)
		for k = 0, 9 do
			local color = ({ C(255, 140, 180), C(255, 220, 110), C(190, 150, 255), C(255, 255, 255) })[k % 4 + 1]
			P(folder, "Flower", BALL, Vector3.one * 0.8, at(-17.4 + k * 1.2, GROUND + 0.9, -18.8), color, nil, DECOR)
		end
		P(folder, "Lawn", BLOCK, Vector3.new(13, 0.06, 18), at(-12.5, GROUND + 0.03, -6), C(120, 200, 110), Enum.Material.Grass, DECOR)
		for _, pos in { { -17, -2 }, { -8.5, 1 } } do
			P(folder, "Trunk", CYL, Vector3.new(4, 0.8, 0.8), at(pos[1], GROUND + 2, pos[2]) * UPRIGHT, BEAM)
			P(folder, "Crown", BALL, Vector3.one * 4.4, at(pos[1], GROUND + 5, pos[2]), C(255, 170, 210), nil, DECOR)
		end
		P(folder, "BenchSeat", BLOCK, Vector3.new(4, 0.4, 1.4), at(-12, GROUND + 1.2, -14), BEAM, Enum.Material.Wood)
		P(folder, "BenchLegs", BLOCK, Vector3.new(3.6, 1, 1.2), at(-12, GROUND + 0.5, -14), WOOD, Enum.Material.Wood, DECOR)
	end,
	-- A pond with a coin fountain in the east yard.
	pond = function(folder, at, accent)
		local c = at(13, 0, -9)
		cyl(folder, "Rim", 0.8, 11, c * CFrame.new(0, GROUND + 0.4, 0), STONE_DARK)
		cyl(folder, "Water", 0.2, 10, c * CFrame.new(0, GROUND + 0.75, 0), C(100, 190, 240), Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
		cyl(folder, "Column", 3.2, 1.2, c * CFrame.new(0, GROUND + 2.2, 0), STONE)
		cyl(folder, "Bowl", 0.6, 3.4, c * CFrame.new(0, GROUND + 3.9, 0), STONE)
		local coin = P(folder, "Coin", CYL, Vector3.new(0.4, 1.8, 1.8), c * CFrame.new(0, GROUND + 5.1, 0), GOLD, Enum.Material.Neon, DECOR)
		coin:AddTag("SpinSlow")
		for k = 0, 3 do
			local a = k * 1.6
			P(folder, "LilyPad", CYL, Vector3.new(0.05, 1.2, 1.2), c * CFrame.new(math.cos(a) * 3.4, GROUND + 0.88, math.sin(a) * 3.4) * UPRIGHT, C(90, 180, 100), nil, DECOR)
		end
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
		P(folder, "Lawn", BLOCK, Vector3.new(13, 0.06, 18), at(12.5, GROUND + 0.03, -6), C(120, 200, 110), Enum.Material.Grass, DECOR)
	end,

	-- Crystal clusters glowing in the cellar's corners.
	grotto = function(folder, at, accent)
		for i, pos in { { -18, 43.5 }, { 18, 43.5 }, { -18.2, 27.8 }, { 18.2, 27.8 } } do
			local color = if i % 2 == 0 then CRYSTAL else accent:Lerp(CRYSTAL, 0.3)
			crystalCluster(folder, at(pos[1], CF, pos[2]), color, 1.1)
			if i <= 2 then
				local glow = P(folder, "GrottoGlow", BALL, Vector3.one * 0.4, at(pos[1], CF + 2, pos[2]), color, Enum.Material.Neon, DECOR)
				light(glow, color, 14, 1)
			end
		end
	end,
	-- Heaps of gold coins in the vault's corners.
	goldpile = function(folder, at)
		for _, pos in { { -17, 6.6 }, { 17, 6.6 }, { -17, 23.4 }, { 17, 23.4 } } do
			local c = at(pos[1], CF, pos[2])
			P(folder, "Heap", BALL, Vector3.new(3.4, 2, 3.4), c * CFrame.new(0, 0.5, 0), GOLD, Enum.Material.Metal, DECOR)
			P(folder, "HeapTop", BALL, Vector3.new(2, 1.6, 2), c * CFrame.new(0.3, 1.4, -0.2), C(255, 215, 110), Enum.Material.Metal, DECOR)
			for k = 0, 4 do
				P(folder, "Coin", CYL, Vector3.new(0.15, 0.8, 0.8), c * CFrame.new(math.cos(k) * 1.8, 0.1, math.sin(k) * 1.8) * CFrame.Angles(0, k, math.rad(90)), GOLD, Enum.Material.Neon, DECOR)
			end
		end
	end,

	-- Two round towers at the back corners of the house.
	towers = function(folder, at, accent)
		local roof = roofColor(accent)
		for _, side in { -1, 1 } do
			local base = at(side * 21, GROUND, 47)
			cyl(folder, "Tower", 22, 6, base * CFrame.new(0, 11, 0), STONE)
			cyl(folder, "Band", 0.8, 6.5, base * CFrame.new(0, 12, 0), STONE_DARK)
			cyl(folder, "Crown", 1.2, 7, base * CFrame.new(0, 21.6, 0), STONE_DARK)
			local out = (base.Position - at(0, GROUND, 26).Position) * Vector3.new(1, 0, 1)
			for _, y in { 8, 16 } do
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

	-- The treasury crown floating above the entrance hall's front gable.
	crown = function(folder, at, accent)
		local c = at(0, GROUND + HALL_H + 7, 3.4)
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

-- A freshly bought build rises into place piece by piece, from the ground up, like it is being
-- built. Parts that a client animates itself (spinning, floating) keep their spot.
local function animateIn(folder: Instance)
	local parts = {}
	local low, high = math.huge, -math.huge
	for _, part in folder:GetDescendants() do
		if part:IsA("BasePart") and not part:HasTag("SpinSlow") and not part:HasTag("FloatingRelic") then
			table.insert(parts, part)
			low = math.min(low, part.Position.Y)
			high = math.max(high, part.Position.Y)
		end
	end
	local span = math.max(high - low, 1)
	for _, part in parts do
		local cf, transparency = part.CFrame, part.Transparency
		local delay = (part.Position.Y - low) / span * 1.1
		part.CFrame = cf - Vector3.new(0, 4, 0)
		part.Transparency = 1
		TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay), { CFrame = cf, Transparency = transparency }):Play()
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
	-- Foundations, the stair cover and the like vanish once their build exists.
	for _, part in plot:GetDescendants() do
		local id = part:GetAttribute("HideWhen")
		if type(id) == "string" and part:IsA("BasePart") then
			if part:GetAttribute("BaseTransparency") == nil then
				part:SetAttribute("BaseTransparency", part.Transparency)
				part:SetAttribute("BaseCollide", part.CanCollide)
			end
			local hidden = has(id)
			part.Transparency = if hidden then 1 else part:GetAttribute("BaseTransparency") :: number
			part.CanCollide = not hidden and part:GetAttribute("BaseCollide") == true
			part.CanQuery = not hidden
		end
	end
end

-- Shows a see-through hologram of a build next to its button (nil clears the preview).
function Blueprints.preview(plot: Model, id: string?)
	local old = plot:FindFirstChild("Preview")
	if old then
		old:Destroy()
	end
	local maker = id and MAKERS[id]
	local floor = plot:FindFirstChild("Floor") :: BasePart?
	if not maker or not floor or id == "base" then
		return
	end
	local cf = floor.CFrame
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local folder = Instance.new("Model")
	folder.Name = "Preview"
	previewTarget = folder
	local ok = pcall(maker, folder, at, (plot:GetAttribute("Accent") :: Color3?) or C(200, 170, 255), plot)
	previewTarget = nil
	if not ok then
		folder:Destroy()
		return
	end
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			d.Material = Enum.Material.Neon
			d.Color = C(120, 210, 255)
			d.Transparency = 0.72
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			for _, tag in d:GetTags() do
				d:RemoveTag(tag)
			end
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	folder.Parent = plot
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
