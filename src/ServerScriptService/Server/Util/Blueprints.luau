--!strict
-- The treasury house. Every plot is a paved yard; this module builds the house on it at
-- runtime, in the yard's local frame (floor top at y = 0.6, local -Z faces the plaza):
--
--             z 48       +-----------+                 vault: pedestals 17-20 behind the hall
--                        |  vault    |
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
-- The yard holds the treasure chest (ChestZone, PendingLabel) where the relics' coins pile up,
-- and PlotN.Preview shows a see-through version of the build the owner is standing next to.

local TweenService = game:GetService("TweenService")

local C = Color3.fromRGB
local GOLD = C(255, 200, 80)
local STONE = C(222, 212, 196)
local STONE_DARK = C(184, 172, 158)
local PLASTER = C(238, 228, 214)
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
		facade(folder, at, true, -6, -10, 10, BASE_H, { door(0, 5, 8) }, -1, accent)
		facade(folder, at, true, 12, -10, 10, BASE_H, { door(0, 5, 8) }, 1, accent)
		for _, x in { -10, 10 } do
			facade(folder, at, false, x, -6, 12, BASE_H, { door(3.5, 3.6, 7.5) }, if x < 0 then -1 else 1, accent)
		end
		-- The front door stands wide open.
		for _, side in { -1, 1 } do
			P(folder, "DoorLeaf", BLOCK, Vector3.new(0.3, 7.6, 2.4), at(side * 2.35, GROUND + 3.8, -4.7), BEAM, Enum.Material.Wood, DECOR)
			P(folder, "DoorKnob", BALL, Vector3.one * 0.35, at(side * 2.15, GROUND + 3.6, -3.8), GOLD, Enum.Material.Metal, DECOR)
		end
		-- Inside: a rug, plants by the door, paintings on the walls.
		rug(folder, at(0, 0, 3.5), 13, 13, accent)
		for _, x in { -3.9, 3.9 } do
			plant(folder, at(x, 0, -4.6))
		end
		painting(folder, at(6, GROUND + 6, 11.4) * CFrame.Angles(0, math.pi, 0), 3.6, 2.6, accent:Lerp(C(150, 200, 255), 0.5))
		for _, x in { -9.4, 9.4 } do
			painting(folder, at(x, GROUND + 5.6, 8.5) * CFrame.Angles(0, if x < 0 then math.pi / 2 else -math.pi / 2, 0), 3, 2.2, accent:Lerp(C(255, 200, 150), 0.5))
		end

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

		-- The treasure chest in the yard: the relics' coins pile up here until the owner walks in.
		local chest = Instance.new("Model")
		chest.Name = "TreasureChest"
		local c = at(0, GROUND, -17.5)
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
		gui.Size = UDim2.fromScale(8, 1.6)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
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
	-- Side rooms with two pedestals each and a window to the outside.
	roomWest = function(folder, at, accent, plot)
		local x0, x1 = -20, -10
		wall(folder, at, false, x0, -6, 12, WING_H, { window(3.5, 4, 3.6, 8) }, PLASTER)
		wall(folder, at, true, -6, x0, x1, WING_H, { window(-15, 3.4, 3.6, 7.6) }, PLASTER)
		wall(folder, at, true, 12, x0, x1, WING_H, {}, PLASTER)
		roofAlongZ(folder, at, -15, 5, -6, 12, GROUND + WING_H, GROUND + WING_H + 3, accent)
		facade(folder, at, false, x0, -6, 12, WING_H, { window(3.5, 4, 3.6, 8) }, -1, accent)
		facade(folder, at, true, -6, x0, x1, WING_H, { window(-15, 3.4, 3.6, 7.6) }, -1, accent)
		rug(folder, at(-15, 0, 3.5), 7, 12, accent)
		painting(folder, at(-19.4, GROUND + 5.4, 9.2) * CFrame.Angles(0, -math.pi / 2, 0), 3, 2.2, accent:Lerp(C(120, 220, 200), 0.5))
		plant(folder, at(-18.2, 0, -4.4))
		P(folder, "Bench", BLOCK, Vector3.new(1.4, 0.4, 3.6), at(-18.7, GROUND + 1.2, 3.5), BEAM, Enum.Material.Wood)
		P(folder, "BenchLegs", BLOCK, Vector3.new(1.2, 1, 3.2), at(-18.7, GROUND + 0.5, 3.5), WOOD, Enum.Material.Wood, DECOR)
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
		facade(folder, at, false, x1, -6, 12, WING_H, { window(3.5, 4, 3.6, 8) }, 1, accent)
		facade(folder, at, true, -6, x0, x1, WING_H, { window(15, 3.4, 3.6, 7.6) }, -1, accent)
		rug(folder, at(15, 0, 3.5), 7, 12, accent)
		painting(folder, at(19.4, GROUND + 5.4, 9.2) * CFrame.Angles(0, math.pi / 2, 0), 3, 2.2, accent:Lerp(C(255, 170, 200), 0.5))
		plant(folder, at(18.2, 0, -4.4))
		P(folder, "Bench", BLOCK, Vector3.new(1.4, 0.4, 3.6), at(18.7, GROUND + 1.2, 3.5), BEAM, Enum.Material.Wood)
		P(folder, "BenchLegs", BLOCK, Vector3.new(1.2, 1, 3.2), at(18.7, GROUND + 0.5, 3.5), WOOD, Enum.Material.Wood, DECOR)
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
		wall(folder, at, true, 34, -20, 20, HALL_H, { upper(-10), upper(10), door(0, 5, 8) }, PLASTER)
		for _, x in { -20, 20 } do
			facade(folder, at, false, x, 12, 34, HALL_H, { lower(16.5), lower(22.5), upper(30.5) }, if x < 0 then -1 else 1, accent)
		end
		facade(folder, at, true, 34, -20, 20, HALL_H, { upper(-10), upper(10), door(0, 5, 8) }, 1, accent)
		rug(folder, at(0, 0, 18), 4, 11, accent)
		for _, x in { -8, 8 } do
			plant(folder, at(x, 0, 13.6))
		end
		for _, x in { -19.4, 19.4 } do
			-- Long banners between the windows.
			local face = CFrame.Angles(0, if x < 0 then math.pi / 2 else -math.pi / 2, 0)
			P(folder, "HallBanner", BLOCK, Vector3.new(2.2, 6, 0.2), at(x, GROUND + 9.5, 19.5) * face, accent, Enum.Material.Fabric, DECOR)
			P(folder, "BannerRod", BLOCK, Vector3.new(3.2, 0.3, 0.3), at(x, GROUND + 12.6, 19.5) * face, GOLD, Enum.Material.Metal, DECOR)
		end
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
	-- A front garden: a low picket fence with a gate, flower beds and lanterns.
	garden = function(folder, at, accent)
		local function fence(x0: number, z0: number, x1: number, z1: number)
			local a, b = Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z1)
			local length = (b - a).Magnitude
			local mid = at((x0 + x1) / 2, 0, (z0 + z1) / 2)
			local dir = CFrame.lookAt(mid.Position, (at(x1, 0, z1)).Position)
			P(folder, "Rail", BLOCK, Vector3.new(0.25, 0.3, length), dir * CFrame.new(0, GROUND + 1.8, 0), C(245, 240, 230), nil, DECOR)
			P(folder, "Rail", BLOCK, Vector3.new(0.25, 0.3, length), dir * CFrame.new(0, GROUND + 0.9, 0), C(245, 240, 230), nil, DECOR)
			for t = 0, length, 1.2 do
				P(folder, "Picket", BLOCK, Vector3.new(0.3, 2.4, 0.5), dir * CFrame.new(0, GROUND + 1.2, -length / 2 + t), C(250, 248, 240), nil, DECOR)
			end
		end
		fence(-19.7, -19.7, -4.6, -19.7)
		fence(4.6, -19.7, 19.7, -19.7)
		fence(-19.7, -19.7, -19.7, -6.5)
		fence(19.7, -19.7, 19.7, -6.5)
		for _, x in { -12, 12 } do
			P(folder, "Bed", BLOCK, Vector3.new(13, 0.5, 1.2), at(x, GROUND + 0.25, -18.9), C(120, 84, 62), nil, DECOR)
			for k = 0, 9 do
				local color = ({ C(255, 140, 180), C(255, 220, 110), C(190, 150, 255), C(255, 255, 255) })[k % 4 + 1]
				P(folder, "Flower", BALL, Vector3.one * 0.8, at(x - 5.8 + k * 1.3, GROUND + 0.9, -18.9), color, nil, DECOR)
			end
		end
		for _, x in { -18.9, 18.9 } do
			P(folder, "SideBed", BLOCK, Vector3.new(1.2, 0.5, 4.5), at(x, GROUND + 0.25, -9.5), C(120, 84, 62), nil, DECOR)
			for k = 0, 3 do
				P(folder, "Flower", BALL, Vector3.one * 0.8, at(x, GROUND + 0.9, -11.3 + k * 1.2), accent:Lerp(Color3.new(1, 1, 1), 0.3), nil, DECOR)
			end
		end
		for _, x in { -4.6, 4.6 } do
			P(folder, "GatePost", BLOCK, Vector3.new(0.7, 3.4, 0.7), at(x, GROUND + 1.7, -19.7), BEAM, Enum.Material.Wood)
			local lamp = P(folder, "GateLamp", BALL, Vector3.one * 0.9, at(x, GROUND + 3.8, -19.7), WARM, Enum.Material.Neon, DECOR)
			if x < 0 then
				light(lamp, WARM, 12, 0.8)
			end
		end
	end,
	-- A stone fireplace with a crackling fire, and its chimney through the roof.
	fireplace = function(folder, at)
		local c = at(-6, 0, 11)
		P(folder, "Hearth", BLOCK, Vector3.new(4.4, 4.6, 1.2), c * CFrame.new(0, GROUND + 2.3, 0), PLINTH, Enum.Material.Slate)
		P(folder, "Mantel", BLOCK, Vector3.new(4.4, 0.5, 1.6), c * CFrame.new(0, GROUND + 4.8, -0.2), BEAM, Enum.Material.Wood)
		P(folder, "Opening", BLOCK, Vector3.new(2.6, 2.2, 0.3), c * CFrame.new(0, GROUND + 1.4, -0.5), C(40, 30, 30), nil, DECOR)
		local fire = P(folder, "Fire", BALL, Vector3.new(1.6, 1.2, 0.8), c * CFrame.new(0, GROUND + 0.9, -0.7), C(255, 150, 60), Enum.Material.Neon, DECOR)
		light(fire, C(255, 160, 80), 14, 1.2)
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
		-- Chimney through the starting room's roof.
		local chimney = P(folder, "Chimney", BLOCK, Vector3.new(2.4, 7.5, 2.4), at(-6, GROUND + BASE_H + 2.6, 10.6), PLINTH, Enum.Material.Slate, { CanCollide = false })
		chimney:AddTag("TreasuryRoof")
		local cap = P(folder, "ChimneyCap", BLOCK, Vector3.new(2.9, 0.4, 2.9), at(-6, GROUND + BASE_H + 6.5, 10.6), STONE_DARK, nil, ROOF)
		cap:AddTag("TreasuryRoof")
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
	-- Bookshelves in both wings and the hall, and a reading table.
	library = function(folder, at)
		for _, x in { -15, 15 } do
			bookshelf(folder, at(x, 0, 11.1) * CFrame.Angles(0, math.pi, 0), 5, 6.5)
		end
		for _, x in { -12.5, 12.5 } do
			bookshelf(folder, at(x, 0, 13.4), 4.6, 8)
		end
		P(folder, "Table", BLOCK, Vector3.new(3.4, 0.3, 2), at(4.5, GROUND + 2.6, 30.5), BEAM, Enum.Material.Wood)
		P(folder, "TableLeg", BLOCK, Vector3.new(3, 2.4, 1.6), at(4.5, GROUND + 1.25, 30.5), WOOD, Enum.Material.Wood, DECOR)
		P(folder, "OpenBook", BLOCK, Vector3.new(1.4, 0.15, 1), at(4.5, GROUND + 2.85, 30.5) * CFrame.Angles(0, 0.3, 0), C(250, 240, 220), nil, DECOR)
		P(folder, "Candle", BLOCK, Vector3.new(0.3, 0.8, 0.3), at(5.8, GROUND + 3.15, 30.1), C(250, 240, 220), nil, DECOR)
		local flame = P(folder, "CandleFlame", BALL, Vector3.new(0.25, 0.4, 0.25), at(5.8, GROUND + 3.75, 30.1), WARM, Enum.Material.Neon, DECOR)
		light(flame, WARM, 8, 0.7)
	end,
	-- The vault behind the hall: thick steel-grey walls, an open round vault door and four more
	-- pedestals (17-20).
	vault = function(folder, at, accent, plot)
		P(folder, "VaultFloor", BLOCK, Vector3.new(18, 1.2, 14), at(0, 0, 41), STONE)
		P(folder, "VaultInlay", BLOCK, Vector3.new(16, 0.1, 12), at(0, GROUND + 0.03, 41), C(240, 210, 130), Enum.Material.Metal, DECOR)
		wall(folder, at, false, -9, 34, 48, 10, {}, VAULT)
		wall(folder, at, false, 9, 34, 48, 10, {}, VAULT)
		wall(folder, at, true, 48, -9, 9, 10, {}, VAULT)
		for _, x in { -9, 9 } do
			for _, z in { 34, 48 } do
				P(folder, "Corner", BLOCK, Vector3.new(1.8, 11, 1.8), at(x, GROUND + 5.5, z), STONE_DARK)
			end
		end
		-- Flat roof with a golden rim.
		roofPart(P(folder, "VaultRoof", BLOCK, Vector3.new(19, 0.8, 15), at(0, GROUND + 10.4, 41), VAULT, nil, ROOF))
		roofPart(P(folder, "VaultRim", BLOCK, Vector3.new(19.6, 0.4, 15.6), at(0, GROUND + 10.9, 41), GOLD, Enum.Material.Metal, ROOF))
		-- The open vault door leaning beside the doorway, inside the hall.
		local doorCf = at(-5.9, GROUND + 3.6, 32.6) * CFrame.Angles(0, math.rad(12), 0)
		P(folder, "VaultDoor", CYL, Vector3.new(0.8, 7, 7), doorCf * CFrame.Angles(0, math.pi / 2, 0), C(170, 175, 190), Enum.Material.Metal, DECOR)
		P(folder, "VaultWheel", CYL, Vector3.new(0.4, 3, 3), doorCf * CFrame.new(0, 0, -0.5) * CFrame.Angles(0, math.pi / 2, 0), GOLD, Enum.Material.Metal, DECOR)
		for _, x in { -6.2, 6.2 } do
			local glow = P(folder, "VaultLamp", BLOCK, Vector3.new(0.6, 1.4, 0.6), at(x, GROUND + 6.5, 47.3), accent, Enum.Material.Neon, DECOR)
			light(glow, accent, 14, 1)
		end
		for i, pos in { { -4, 38 }, { 4, 38 }, { -4, 44.5 }, { 4, 44.5 } } do
			pedestal(plot, "vault", 16 + i, at(pos[1], GROUND, pos[2]))
		end
	end,
	-- Heaps of gold coins in the vault's corners.
	goldpile = function(folder, at)
		for _, pos in { { -7, 46.2 }, { 7, 46.2 }, { -7, 35.8 }, { 7, 35.8 } } do
			local c = at(pos[1], GROUND, pos[2])
			P(folder, "Heap", BALL, Vector3.new(3.4, 2, 3.4), c * CFrame.new(0, 0.5, 0), GOLD, Enum.Material.Metal, DECOR)
			P(folder, "HeapTop", BALL, Vector3.new(2, 1.6, 2), c * CFrame.new(0.3, 1.4, -0.2), C(255, 215, 110), Enum.Material.Metal, DECOR)
			for k = 0, 4 do
				P(folder, "Coin", CYL, Vector3.new(0.15, 0.8, 0.8), c * CFrame.new(math.cos(k) * 1.8, 0.1, math.sin(k) * 1.8) * CFrame.Angles(0, k, math.rad(90)), GOLD, Enum.Material.Neon, DECOR)
			end
		end
		local glow = P(folder, "GoldGlow", BALL, Vector3.one * 0.5, at(0, GROUND + 8, 41), GOLD, Enum.Material.Neon, DECOR)
		light(glow, GOLD, 18, 1.2)
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
