--!strict
-- Builds a small low-poly model for a relic from its catalogue row. Pickups, pedestals and UI
-- previews all use this, so a new relic needs no hand-made model (def.shape picks the builder).

local Config = require(script.Parent.Config)
local RelicDefs = require(script.Parent.RelicDefs)

local GOLD = Color3.fromRGB(255, 196, 84)
local DARK = Color3.fromRGB(30, 20, 45)
local METAL = Enum.Material.Metal
local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X
local ON_CORNER = CFrame.Angles(math.rad(45), 0, math.atan(1 / math.sqrt(2)))

local function piece(model: Model, name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Each builder adds parts around the origin (about 2 studs across) and returns the core part.
local BUILDERS: { [string]: (Model, Color3, Enum.Material) -> Part } = {
	orb = function(m, c, mat)
		return piece(m, "Core", BALL, Vector3.one * 1.6, CFrame.identity, c, mat)
	end,
	gem = function(m, c, mat)
		return piece(m, "Core", BLOCK, Vector3.one * 1.3, ON_CORNER, c, mat)
	end,
	cube = function(m, c, mat)
		piece(m, "Rim", BLOCK, Vector3.new(1.7, 0.2, 1.7), CFrame.new(0, -0.9, 0), GOLD, METAL)
		return piece(m, "Core", BLOCK, Vector3.one * 1.4, CFrame.Angles(math.rad(25), math.rad(45), 0), c, mat)
	end,
	shard = function(m, c, mat)
		piece(m, "Small", BLOCK, Vector3.new(0.4, 1.1, 0.4), CFrame.new(0.5, -0.4, 0.2) * CFrame.Angles(0, math.rad(45), math.rad(-25)), c, mat)
		return piece(m, "Core", BLOCK, Vector3.new(0.6, 1.9, 0.6), CFrame.Angles(0, math.rad(45), math.rad(8)), c, mat)
	end,
	lantern = function(m, c, mat)
		piece(m, "CapTop", CYL, Vector3.new(0.25, 1.2, 1.2), CFrame.new(0, 0.8, 0) * UPRIGHT, GOLD, METAL)
		piece(m, "CapBottom", CYL, Vector3.new(0.25, 1.2, 1.2), CFrame.new(0, -0.8, 0) * UPRIGHT, GOLD, METAL)
		piece(m, "Handle", BLOCK, Vector3.new(0.15, 0.5, 0.7), CFrame.new(0, 1.15, 0), GOLD, METAL)
		local glass = piece(m, "Glass", CYL, Vector3.new(1.35, 1, 1), UPRIGHT, c, Enum.Material.Glass)
		glass.Transparency = 0.4
		return piece(m, "Core", BALL, Vector3.one * 0.65, CFrame.identity, c, Enum.Material.Neon)
	end,
	amulet = function(m, c, mat)
		piece(m, "Disc", CYL, Vector3.new(0.25, 1.7, 1.7), CFrame.identity, GOLD, METAL)
		piece(m, "Loop", CYL, Vector3.new(0.15, 0.5, 0.5), CFrame.new(0, 0.95, 0), GOLD, METAL)
		return piece(m, "Core", BALL, Vector3.one * 0.85, CFrame.new(0.12, 0, 0), c, mat)
	end,
	bloom = function(m, c, mat)
		for i = 0, 4 do
			local cf = CFrame.Angles(0, i * math.pi * 2 / 5, 0) * CFrame.new(0, 0, -0.55) * CFrame.Angles(math.rad(35), 0, 0)
			piece(m, "Petal" .. i, BLOCK, Vector3.new(0.55, 0.12, 1.1), cf, c, mat)
		end
		piece(m, "Stem", CYL, Vector3.new(0.8, 0.15, 0.15), CFrame.new(0, -0.6, 0) * UPRIGHT, Color3.fromRGB(110, 190, 100), Enum.Material.SmoothPlastic)
		return piece(m, "Core", BALL, Vector3.one * 0.6, CFrame.new(0, 0.1, 0), GOLD, Enum.Material.Neon)
	end,
	shell = function(m, c, mat)
		local core
		for i = -2, 2 do
			local cf = CFrame.new(0, -0.7, 0) * CFrame.Angles(0, 0, math.rad(i * 22)) * CFrame.new(0, 0.75, 0)
			local p = piece(m, if i == 0 then "Core" else "Rib" .. i, BLOCK, Vector3.new(0.4, 1.5, 0.25), cf, c, mat)
			if i == 0 then
				core = p
			end
		end
		return core :: Part
	end,
	feather = function(m, c, mat)
		local tilt = CFrame.Angles(0, 0, math.rad(20))
		piece(m, "Spine", BLOCK, Vector3.new(0.08, 2.4, 0.16), tilt, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		return piece(m, "Core", BLOCK, Vector3.new(0.55, 2.1, 0.1), tilt * CFrame.new(0.2, 0.05, 0), c, mat)
	end,
	chalice = function(m, c, mat)
		piece(m, "Foot", CYL, Vector3.new(0.2, 1, 1), CFrame.new(0, -0.9, 0) * UPRIGHT, c, METAL)
		piece(m, "Stem", CYL, Vector3.new(0.8, 0.25, 0.25), CFrame.new(0, -0.4, 0) * UPRIGHT, GOLD, METAL)
		piece(m, "Glow", CYL, Vector3.new(0.05, 0.9, 0.9), CFrame.new(0, 0.72, 0) * UPRIGHT, Color3.fromRGB(180, 140, 255), Enum.Material.Neon)
		return piece(m, "Core", CYL, Vector3.new(0.7, 1.1, 1.1), CFrame.new(0, 0.35, 0) * UPRIGHT, c, if mat == Enum.Material.Neon then METAL else mat)
	end,
	crown = function(m, c, mat)
		local band = piece(m, "Core", CYL, Vector3.new(0.5, 1.5, 1.5), CFrame.new(0, -0.3, 0) * UPRIGHT, c, mat)
		for i = 0, 4 do
			local cf = CFrame.Angles(0, i * math.pi * 2 / 5, 0) * CFrame.new(0, 0.2, -0.62) * CFrame.Angles(0, math.rad(45), 0)
			piece(m, "Spike" .. i, BLOCK, Vector3.new(0.22, 0.7, 0.22), cf, GOLD, METAL)
		end
		piece(m, "Jewel", BALL, Vector3.one * 0.35, CFrame.new(0, -0.3, -0.75), GOLD, Enum.Material.Neon)
		return band
	end,
	mask = function(m, c, mat)
		local face = piece(m, "Core", BLOCK, Vector3.new(1.5, 1, 0.25), CFrame.identity, c, mat)
		piece(m, "EyeL", BLOCK, Vector3.new(0.35, 0.16, 0.3), CFrame.new(-0.35, 0.1, -0.05), DARK, Enum.Material.SmoothPlastic)
		piece(m, "EyeR", BLOCK, Vector3.new(0.35, 0.16, 0.3), CFrame.new(0.35, 0.1, -0.05), DARK, Enum.Material.SmoothPlastic)
		piece(m, "Brow", BLOCK, Vector3.new(1.6, 0.14, 0.3), CFrame.new(0, 0.45, 0), GOLD, METAL)
		return face
	end,
	mirror = function(m, c, mat)
		piece(m, "Frame", CYL, Vector3.new(0.2, 1.8, 1.8), CFrame.identity, GOLD, METAL)
		piece(m, "Handle", BLOCK, Vector3.new(0.2, 0.8, 0.25), CFrame.new(0, -1.2, 0), GOLD, METAL)
		return piece(m, "Core", CYL, Vector3.new(0.24, 1.45, 1.45), CFrame.identity, c, mat)
	end,
	globe = function(m, c, mat)
		piece(m, "Ring", CYL, Vector3.new(0.12, 1.9, 1.9), CFrame.Angles(0, 0, math.rad(23)), GOLD, METAL)
		piece(m, "Stand", CYL, Vector3.new(0.25, 0.8, 0.8), CFrame.new(0, -0.95, 0) * UPRIGHT, GOLD, METAL)
		return piece(m, "Core", BALL, Vector3.one * 1.4, CFrame.identity, c, mat)
	end,
	egg = function(m, c, mat)
		local egg = piece(m, "Core", BLOCK, Vector3.new(1.1, 1.45, 1.1), CFrame.identity, c, mat)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = egg
		piece(m, "Nest", CYL, Vector3.new(0.25, 1.2, 1.2), CFrame.new(0, -0.7, 0) * UPRIGHT, GOLD, METAL)
		return egg
	end,
}

local function rarityRank(rarity: string): number
	return table.find(Config.RarityOrder, rarity) or 1
end

local RelicVisuals = {}

export type BuildOptions = { effects: boolean? }

-- effects adds light and particles; leave it off for UI previews (ViewportFrames ignore them).
function RelicVisuals.build(def: RelicDefs.RelicDef, opts: BuildOptions?): Model
	local model = Instance.new("Model")
	model.Name = def.id
	local rank = rarityRank(def.rarity)
	local material = if rank == 1 then Enum.Material.SmoothPlastic else Enum.Material.Neon
	local builder = BUILDERS[def.shape] or BUILDERS.orb
	local core = builder(model, def.color, material)
	model.PrimaryPart = core
	-- Pivot at the build origin, not the (often rotated) core, so PivotTo keeps the design.
	core.PivotOffset = core.CFrame:Inverse()
	model:SetAttribute("RelicId", def.id)

	if opts and opts.effects and rank >= 2 then
		local light = Instance.new("PointLight")
		light.Color = def.color
		light.Brightness = 0.8 + rank * 0.4
		light.Range = 6 + rank * 2
		light.Shadows = false
		light.Parent = core
	end
	if opts and opts.effects and rank >= 4 then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(def.color, Config.Rarities[def.rarity].color)
		sparkles.LightEmission = 1
		sparkles.Rate = if rank >= 5 then 8 else 4
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.3, 0)
		sparkles.Parent = core
	end
	return model
end

function RelicVisuals.rarityRank(rarity: string): number
	return rarityRank(rarity)
end

return RelicVisuals
