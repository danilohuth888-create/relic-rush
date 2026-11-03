--!strict
-- "Forgotten Ruins": a short co-op expedition for 1-4 players.
-- Players gather at the ruins portal; after a short countdown the group is moved into its own
-- copy of ServerStorage.ExpeditionArena (built by tools/world/BuildExpedition.luau), placed far
-- from the island. Three rooms (pressure plates, light beam, riddle stones) lead to the crystal
-- guardian; beating it opens a chest with Expedition and Ruins relics for everyone.
-- The whole run is decided here: clients only trigger prompts and may ask to leave.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local Progress = require(script.Parent.Parent.Util.Progress)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local RelicSpawnService = require(script.Parent.RelicSpawnService)

local SETTINGS = Config.Expedition
local TICK = 0.15
local SLOT_ORIGIN = Vector3.new(2400, 220, 0)
local SLOT_SPACING = 500
local PROMPT_RANGE = 10
-- Same order as the Symbol attribute of the plates in BuildExpedition.luau.
local SYMBOLS = { "☀️", "🌙", "⭐", "🍀" }
local SYMBOL_COLORS = {
	Color3.fromRGB(255, 200, 80),
	Color3.fromRGB(120, 170, 255),
	Color3.fromRGB(200, 140, 255),
	Color3.fromRGB(110, 220, 130),
}
local FLOOR = Color3.fromRGB(70, 78, 120)
local CRYSTAL = Color3.fromRGB(120, 230, 255)
local DANGER = Color3.fromRGB(255, 70, 90)

type Run = {
	id: number,
	slot: number,
	arena: Model,
	origin: Vector3,
	members: { [Player]: boolean },
	checkpoint: string,
	active: boolean,
	startedAt: number,
	rng: Random,
	chest: Model,
	exit: BasePart,
	opened: { [Player]: boolean },
}

local ExpeditionService = {}

local template: Model? = nil
local folder: Folder
local portal: BasePart? = nil
local portalPrompt: ProximityPrompt? = nil
local runs: { [number]: Run } = {} -- slot -> run
local runOf: { [Player]: Run } = {}
local lobby: { members: { Player }, startsAt: number }? = nil
local nextRunId = 0
local promptLimiter = RateLimiter.new(6, 3)
local leaveLimiter = RateLimiter.new(2, 0.5)
local bumped: { [Player]: number } = {} -- hazard grace period per player
-- Every prompt's checked handler, so Studio tests can trigger one exactly like a player would.
local handlers: { [ProximityPrompt]: (Player) -> () } = setmetatable({}, { __mode = "k" }) :: any

-- Helpers -------------------------------------------------------------------------------

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function list(run: Run): { Player }
	local result = {}
	for player in run.members do
		table.insert(result, player)
	end
	return result
end

local function notify(target: Player | Run, kind: string, text: string, extra: { [string]: any }?)
	local message: { [string]: any } = { kind = kind, text = text }
	for k, v in extra or {} do
		message[k] = v
	end
	local remote = Net.event("Notify")
	if typeof(target) == "Instance" then
		remote:FireClient(target :: Player, message)
	else
		for player in (target :: Run).members do
			remote:FireClient(player, message)
		end
	end
end

local function setObjective(run: Run, text: string)
	for player in run.members do
		player:SetAttribute("ExpObjective", text)
	end
end

local function marker(run: Run, name: string): CFrame
	local part = (run.arena:FindFirstChild("Markers") :: Instance):FindFirstChild(name) :: BasePart
	local position = part.Position + Vector3.new(0, 3, 0)
	return CFrame.lookAt(position, position + Vector3.zAxis)
end

-- Streams the target area in first so the player never lands in a not-yet-loaded void.
local function teleport(player: Player, cf: CFrame)
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(cf.Position, 4)
		end)
		local character = player.Character
		if character and player.Parent then
			character:PivotTo(cf)
		end
	end)
end

local function toCheckpoint(run: Run, player: Player)
	teleport(player, marker(run, run.checkpoint))
end

local function portalReturn(player: Player)
	if not portal then
		return
	end
	local look = portal.CFrame.LookVector
	local position = Vector3.new(portal.Position.X, 3, portal.Position.Z) + Vector3.new(look.X, 0, look.Z).Unit * 12
	teleport(player, CFrame.lookAt(position, position + look))
end

local function inRange(player: Player, part: BasePart): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= PROMPT_RANGE + Config.RangeTolerance
end

-- A server prompt inside the run; only members in range get through, and only while it runs.
local function prompt(run: Run, parent: BasePart, action: string, object: string, hold: number, onTrigger: (Player) -> ()): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = PROMPT_RANGE
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = parent
	handlers[p] = function(player: Player)
		if p.Enabled and run.active and run.members[player] and promptLimiter:allow(player) and inRange(player, parent) then
			onTrigger(player)
		end
	end
	p.Triggered:Connect(handlers[p])
	return p
end

local function openDoor(run: Run, name: string)
	local door = run.arena:FindFirstChild(name) :: BasePart?
	if door then
		door.CanCollide = false
		TweenService:Create(door, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { Position = door.Position - Vector3.new(0, 14.6, 0) }):Play()
	end
end

local function sleep(run: Run, seconds: number)
	local untilTime = os.clock() + seconds
	while run.active and os.clock() < untilTime do
		task.wait(TICK)
	end
end

local function label(part: Instance): TextLabel?
	local gui = part:FindFirstChild("SurfaceGui")
	return gui and gui:FindFirstChild("Text") :: TextLabel?
end

-- Room 1: step on the plates in the order shown on the tablet ----------------------------

local function platesStage(run: Run)
	local plates: { BasePart } = {}
	for i = 1, 4 do
		plates[i] = (run.arena:FindFirstChild("Plates") :: Instance):FindFirstChild("Plate" .. i) :: BasePart
	end
	local order = { 1, 2, 3, 4 }
	for i = #order, 2, -1 do
		local j = run.rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local glyphs = {}
	for _, symbol in order do
		table.insert(glyphs, SYMBOLS[symbol])
	end
	local tablet = label(run.arena:FindFirstChild("Tablet") :: Instance)
	if tablet then
		tablet.Text = table.concat(glyphs, "  →  ")
	end
	setObjective(run, "Raum 1 von 3: Tritt in der Reihenfolge der Tafel auf die Platten.")

	local function light(i: number, on: boolean)
		plates[i].Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		plates[i].Color = if on then SYMBOL_COLORS[i] else SYMBOL_COLORS[i]:Lerp(FLOOR, 0.55)
	end
	local nextIndex, lit, occupied = 1, {}, {}
	while run.active and nextIndex <= #order do
		task.wait(TICK)
		local now = {}
		for player in run.members do
			local root = rootOf(player)
			if root then
				for i, plate in plates do
					local rel = plate.CFrame:PointToObjectSpace(root.Position)
					if math.abs(rel.X) < 3.8 and math.abs(rel.Z) < 3.8 and rel.Y > -1 and rel.Y < 6 then
						now[i] = true
					end
				end
			end
		end
		for i in now do
			if not occupied[i] and not lit[i] then
				if order[nextIndex] == i then
					lit[i] = true
					light(i, true)
					nextIndex += 1
					notify(run, "step", ("Richtig! %d von 4"):format(nextIndex - 1))
				else
					for k in lit do
						light(k, false)
					end
					table.clear(lit)
					nextIndex = 1
					notify(run, "wrong", "Falsche Reihenfolge – die Platten erlöschen. Nochmal!")
					break
				end
			end
		end
		occupied = now
	end
end

-- Room 2: turn the mirrors until the light beam reaches the crystal ------------------------

local function mirrorsStage(run: Run)
	local arena = run.arena
	local source = arena:FindFirstChild("BeamSource") :: BasePart
	local receiver = arena:FindFirstChild("Receiver") :: BasePart
	local glass: { BasePart } = {}
	for i = 1, 3 do
		glass[i] = ((arena:FindFirstChild("Mirrors") :: Instance):FindFirstChild("Mirror" .. i) :: Instance):FindFirstChild("Glass") :: BasePart
	end
	-- 1 = "/" (turns +X into +Z), 2 = "\" (turns +X into -Z); the solution is 1, 2, 2.
	local states = { 2, 1, 1 }
	local beams = Instance.new("Folder")
	beams.Name = "Beam"
	beams.Parent = arena
	local minX, maxX = run.origin.X - 22, run.origin.X + 22
	local minZ, maxZ = run.origin.Z + 65, run.origin.Z + 135
	local height = source.Position.Y

	local function orient(i: number)
		local p = glass[i].Position
		local yaw = if states[i] == 1 then -45 else 45
		TweenService:Create(glass[i], TweenInfo.new(0.35, Enum.EasingStyle.Back), { CFrame = CFrame.new(p) * CFrame.Angles(0, math.rad(yaw), 0) }):Play()
	end

	-- Follows the beam across the floor plan; returns the corner points and whether it lands.
	local function trace(): ({ Vector3 }, boolean)
		local pos = Vector3.new(source.Position.X, height, source.Position.Z)
		local dir = Vector3.new(1, 0, 0)
		local points = { pos }
		local last = 0
		for _ = 1, 8 do
			local bestT, best = math.huge, nil
			for i, g in glass do
				if i ~= last then
					local rel = Vector3.new(g.Position.X, height, g.Position.Z) - pos
					local t = rel:Dot(dir)
					if t > 0.5 and (rel - dir * t).Magnitude < 1.6 and t < bestT then
						bestT, best = t, i
					end
				end
			end
			local rel = Vector3.new(receiver.Position.X, height, receiver.Position.Z) - pos
			local t = rel:Dot(dir)
			if t > 0.5 and (rel - dir * t).Magnitude < 1.6 and t < bestT then
				table.insert(points, pos + dir * t)
				return points, true
			end
			if not best then
				local wall = if dir.X > 0 then maxX - pos.X elseif dir.X < 0 then pos.X - minX elseif dir.Z > 0 then maxZ - pos.Z else pos.Z - minZ
				table.insert(points, pos + dir * math.max(wall, 0))
				return points, false
			end
			pos = Vector3.new(glass[best].Position.X, height, glass[best].Position.Z)
			table.insert(points, pos)
			dir = if states[best] == 1 then Vector3.new(dir.Z, 0, dir.X) else Vector3.new(-dir.Z, 0, -dir.X)
			last = best
		end
		return points, false
	end

	local function draw(): boolean
		beams:ClearAllChildren()
		local points, hit = trace()
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local length = (b - a).Magnitude
			if length > 0.1 then
				local beam = Instance.new("Part")
				beam.Anchored = true
				beam.CanCollide = false
				beam.CanQuery = false
				beam.CanTouch = false
				beam.CastShadow = false
				beam.Material = Enum.Material.Neon
				beam.Color = CRYSTAL
				beam.Transparency = 0.2
				beam.Size = Vector3.new(0.45, 0.45, length)
				beam.CFrame = CFrame.lookAt((a + b) / 2, b)
				beam.Parent = beams
			end
		end
		return hit
	end

	for i = 1, 3 do
		orient(i)
	end
	local solved = draw()
	for i = 1, 3 do
		prompt(run, glass[i], "Drehen", "Spiegel", 0, function()
			if solved then
				return
			end
			states[i] = if states[i] == 1 then 2 else 1
			orient(i)
			solved = draw()
		end)
	end

	-- The wisp drifts across the hall; touching it sends a player back to the hall entrance.
	local wisp = arena:FindFirstChild("Wisp") :: BasePart
	local wispB = arena:FindFirstChild("WispB") :: BasePart
	local drift = TweenService:Create(wisp, TweenInfo.new(3.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = wispB.Position })
	drift:Play()
	setObjective(run, "Raum 2 von 3: Dreh die Spiegel, bis der Lichtstrahl den Kristall trifft. Vorsicht vor dem Irrlicht!")
	while run.active and not solved do
		task.wait(TICK)
		local now = os.clock()
		for player in run.members do
			local root = rootOf(player)
			if root and (root.Position - wisp.Position).Magnitude < 4.2 and now > (bumped[player] or 0) then
				bumped[player] = now + 2
				toCheckpoint(run, player)
				notify(player, "wrong", "Das Irrlicht hat dich zurückgeschickt!")
			end
		end
	end
	drift:Cancel()
	TweenService:Create(wisp, TweenInfo.new(0.8), { Transparency = 1 }):Play()
	receiver.Material = Enum.Material.Neon
	receiver.Color = CRYSTAL
end

-- Room 3: set the riddle stones to the symbols on the tablet -----------------------------

local function stonesStage(run: Run)
	local stones: { BasePart } = {}
	local target, state = {}, {}
	for i = 1, 3 do
		stones[i] = (run.arena:FindFirstChild("Stones") :: Instance):FindFirstChild("Stone" .. i) :: BasePart
		target[i] = run.rng:NextInteger(1, 4)
		state[i] = (target[i] + run.rng:NextInteger(0, 2)) % 4 + 1 -- never starts solved
	end
	local riddle = label(run.arena:FindFirstChild("Riddle") :: Instance)
	if riddle then
		riddle.Text = ("%s   %s   %s"):format(SYMBOLS[target[1]], SYMBOLS[target[2]], SYMBOLS[target[3]])
	end
	local function show(i: number)
		local text = label(stones[i])
		if text then
			text.Text = SYMBOLS[state[i]]
		end
		stones[i].Color = SYMBOL_COLORS[state[i]]:Lerp(Color3.fromRGB(74, 64, 104), 0.6)
	end
	local solved = false
	for i = 1, 3 do
		show(i)
		prompt(run, stones[i], "Drehen", "Rätselstein", 0, function()
			if solved then
				return
			end
			state[i] = state[i] % 4 + 1
			show(i)
			solved = state[1] == target[1] and state[2] == target[2] and state[3] == target[3]
		end)
	end
	setObjective(run, "Raum 3 von 3: Dreh die Rätselsteine, bis sie der Tafel über dem Tor gleichen.")
	while run.active and not solved do
		task.wait(TICK)
	end
end

-- Boss: the crystal guardian -------------------------------------------------------------

local function slam(run: Run, center: Vector3)
	local disk = Instance.new("Part")
	disk.Name = "Telegraph"
	disk.Shape = Enum.PartType.Cylinder
	disk.Anchored = true
	disk.CanCollide = false
	disk.CanQuery = false
	disk.CanTouch = false
	disk.CastShadow = false
	disk.Material = Enum.Material.Neon
	disk.Color = DANGER
	disk.Transparency = 0.8
	disk.Size = Vector3.new(0.3, 18, 18)
	disk.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	disk.Parent = run.arena
	TweenService:Create(disk, TweenInfo.new(1.6), { Transparency = 0.3 }):Play()
	sleep(run, 1.6)
	if not run.active then
		return
	end
	for player in run.members do
		local root = rootOf(player)
		if root then
			local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
			if flat.Magnitude < 9 then
				local out = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(1, 0, 0)
				local target = root.Position + out * 14 + Vector3.new(0, 3, 0)
				local x = math.clamp(target.X, run.origin.X - 31, run.origin.X + 31)
				local z = math.clamp(target.Z, run.origin.Z + 189, run.origin.Z + 261)
				teleport(player, CFrame.lookAt(Vector3.new(x, target.Y, z), Vector3.new(center.X, target.Y, center.Z)))
				notify(player, "wrong", "Der Wächter hat dich umgeworfen!")
			end
		end
	end
	disk.Color = Color3.new(1, 1, 1)
	TweenService:Create(disk, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	task.delay(0.5, function()
		disk:Destroy()
	end)
end

local function guardianStage(run: Run)
	local arena = run.arena
	local guardian = arena:FindFirstChild("Guardian") :: Model
	local core = guardian:FindFirstChild("Core") :: BasePart
	local home = guardian:GetPivot()
	local gems: { BasePart } = {}
	local prompts: { ProximityPrompt } = {}
	local needed = SETTINGS.guardianHits + (math.max(#list(run), 1) - 1) * SETTINGS.extraHitsPerPlayer
	local hits, charged, last = 0, 0, 0
	local nextCharge, chargeEnds = os.clock() + 2, 0
	local nextSlam = os.clock() + 4
	local nextTurn = 0

	local function charge(i: number, on: boolean)
		gems[i].Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		gems[i].Color = if on then CRYSTAL else Color3.fromRGB(50, 56, 92)
		prompts[i].Enabled = on
	end
	for i = 1, 4 do
		local pillar = (arena:FindFirstChild("Pillars") :: Instance):FindFirstChild("Pillar" .. i) :: Instance
		gems[i] = pillar:FindFirstChild("Gem") :: BasePart
		prompts[i] = prompt(run, pillar:FindFirstChild("Column") :: BasePart, "Rune entfesseln", "Runensäule", 0.3, function()
			if charged ~= i or hits >= needed then
				return
			end
			charged = 0
			charge(i, false)
			hits += 1
			nextCharge = os.clock() + 1.2
			-- A short crystal beam from the pillar to the guardian's core.
			local a, b = gems[i].Position, core.Position
			local ray = Instance.new("Part")
			ray.Anchored = true
			ray.CanCollide = false
			ray.CanQuery = false
			ray.CanTouch = false
			ray.Material = Enum.Material.Neon
			ray.Color = CRYSTAL
			ray.Size = Vector3.new(0.8, 0.8, (b - a).Magnitude)
			ray.CFrame = CFrame.lookAt((a + b) / 2, b)
			ray.Parent = arena
			TweenService:Create(ray, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			task.delay(0.7, function()
				ray:Destroy()
			end)
			core.Color = Color3.new(1, 1, 1)
			task.delay(0.25, function()
				core.Color = CRYSTAL
			end)
			notify(run, "hit", ("Treffer! %d von %d"):format(hits, needed))
		end)
		charge(i, false)
	end

	setObjective(run, ("Kristallwächter: Lauf zur leuchtenden Runensäule und entfessle sie! (0 von %d)"):format(needed))
	while run.active and hits < needed do
		task.wait(TICK)
		local now = os.clock()
		if charged == 0 and now >= nextCharge then
			local pick = run.rng:NextInteger(1, 4)
			if pick == last then
				pick = pick % 4 + 1
			end
			charged, last, chargeEnds = pick, pick, now + 10
			charge(pick, true)
			setObjective(run, ("Kristallwächter: Lauf zur leuchtenden Runensäule und entfessle sie! (%d von %d)"):format(hits, needed))
		elseif charged ~= 0 and now > chargeEnds then
			charge(charged, false)
			charged = 0
			nextCharge = now + 0.8
		end

		-- Pick a target among the members standing in the hall; turn to face and slam them.
		local targets = {}
		for player in run.members do
			local root = rootOf(player)
			if root and root.Position.Z > run.origin.Z + 186 then
				table.insert(targets, root)
			end
		end
		if #targets > 0 and now >= nextTurn then
			nextTurn = now + 0.45
			local t = targets[run.rng:NextInteger(1, #targets)].Position
			guardian:PivotTo(CFrame.lookAt(home.Position, Vector3.new(t.X, home.Position.Y, t.Z)))
		end
		if #targets > 0 and now >= nextSlam then
			nextSlam = now + (if hits * 2 >= needed then 3.6 else 5.2)
			local t = targets[run.rng:NextInteger(1, #targets)].Position
			task.spawn(slam, run, Vector3.new(t.X, run.origin.Y + 0.2, t.Z))
		end
	end
	for i = 1, 4 do
		charge(i, false)
	end
	if not run.active then
		return
	end
	-- The guardian shatters into fading shards.
	for _, part in guardian:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
				Transparency = 1,
				Size = part.Size * 0.3,
				Position = part.Position + Vector3.new(run.rng:NextNumber(-4, 4), run.rng:NextNumber(2, 8), run.rng:NextNumber(-4, 4)),
			}):Play()
		end
	end
	task.delay(1.3, function()
		guardian:Destroy()
	end)
	notify(run, "solved", "Der Kristallwächter ist besiegt!")
end

-- Rewards --------------------------------------------------------------------------------

-- Prefers relics the player has not discovered yet, so every run moves the collection on.
local function pick(ids: { string }, discovered: { [string]: boolean }, rng: Random): string?
	local fresh = {}
	for _, id in ids do
		if not discovered[id] then
			table.insert(fresh, id)
		end
	end
	local from = if #fresh > 0 then fresh else ids
	return if #from > 0 then from[rng:NextInteger(1, #from)] else nil
end

local function reward(run: Run, player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local now = os.time()
	local coins = SETTINGS.coinsByTier[data.tier]
	if data.expedition.cooldownUntil > now then
		local left = data.expedition.cooldownUntil - now
		coins = math.floor(coins * SETTINGS.helperShare)
		EconomyService.grant(player, coins, "expedition_helper")
		notify(player, "reward", ("Danke fürs Helfen! +%d Münzen. Neue Relikte gibt es für dich in %d:%02d."):format(coins, left // 60, left % 60), { relics = {} })
		return
	end
	local rarity = if run.rng:NextNumber() < SETTINGS.legendaryChance then "Legendary" else "Epic"
	local expeditionPool = RelicSpawnService.pool("Expedition")
	local ruinsPool = RelicSpawnService.pool("Ruins")
	local ruinsIds = {}
	for _, ids in ruinsPool do
		for _, id in ids do
			table.insert(ruinsIds, id)
		end
	end
	local relics = {}
	for _, relicId in { pick(expeditionPool[rarity] or {}, data.discovered, run.rng), pick(ruinsIds, data.discovered, run.rng) } do
		if relicId then
			local isNew = RelicSpawnService.grant(player, relicId, "Expedition")
			table.insert(relics, { id = relicId, new = isNew })
		end
	end
	EconomyService.grant(player, coins, "expedition")
	data.expedition.cooldownUntil = now + SETTINGS.cooldownSeconds
	data.expedition.wins += 1
	Progress.bump(player, "expedition", 1)
	Analytics.custom(player, "ExpeditionCompleted")
	local names = {}
	for _, relic in relics do
		table.insert(names, RelicDefs.byId[relic.id].name)
	end
	notify(player, "reward", ("Schatz geborgen: %s und %d Münzen!"):format(table.concat(names, " und "), coins), { relics = relics })
	task.spawn(PlayerDataService.saveNow, player)
end

local function rewardStage(run: Run)
	run.chest.Parent = run.arena
	run.exit.Parent = run.arena
	local lid = run.chest:FindFirstChild("Lid") :: BasePart
	local lidOpen = false
	prompt(run, run.chest:FindFirstChild("Base") :: BasePart, "Öffnen", "Schatztruhe", 0.5, function(player)
		if run.opened[player] then
			return
		end
		run.opened[player] = true
		if not lidOpen then
			lidOpen = true
			TweenService:Create(lid, TweenInfo.new(0.6, Enum.EasingStyle.Back), {
				CFrame = lid.CFrame * CFrame.new(0, 0.8, 1.6) * CFrame.Angles(math.rad(-70), 0, 0),
			}):Play()
		end
		reward(run, player)
	end)
	prompt(run, run.exit, "Zurück nach Aetheria", "Portal", 0, function(player)
		ExpeditionService.leave(player)
	end)
	setObjective(run, "Geschafft! Öffne die Schatztruhe – danach bringt dich das Portal zurück.")
	local deadline = os.clock() + SETTINGS.rewardSeconds
	while run.active and os.clock() < deadline do
		task.wait(0.5)
		local waiting = false
		for player in run.members do
			if not run.opened[player] then
				waiting = true
			end
		end
		if not waiting then
			-- Everyone has their loot: a short moment to look around, then home.
			deadline = math.min(deadline, os.clock() + 6)
		end
	end
end

-- Run lifecycle --------------------------------------------------------------------------

local function clearPlayer(player: Player)
	for _, name in { "ExpRun", "ExpObjective", "ExpEnds", "MusicArea" } do
		player:SetAttribute(name, nil)
	end
end

local function finish(run: Run, outcome: string)
	if not run.active then
		return
	end
	run.active = false
	for _, player in list(run) do
		run.members[player] = nil
		runOf[player] = nil
		clearPlayer(player)
		if player.Parent then
			portalReturn(player)
			if outcome == "timeout" then
				notify(player, "wrong", "Die Zeit ist um – die Ruinen schicken euch zurück. Versucht es gleich nochmal!")
				Analytics.custom(player, "ExpeditionFailed")
			end
		end
	end
	runs[run.slot] = nil
	task.delay(2, function()
		run.arena:Destroy()
	end)
end

function ExpeditionService.leave(player: Player)
	local run = runOf[player]
	if not run then
		return false
	end
	run.members[player] = nil
	runOf[player] = nil
	clearPlayer(player)
	if player.Parent then
		portalReturn(player)
	end
	if next(run.members) == nil then
		finish(run, "abandoned")
	end
	return true
end

local function flow(run: Run)
	platesStage(run)
	if not run.active then
		return
	end
	openDoor(run, "Door1")
	notify(run, "solved", "Das Tor öffnet sich!")
	run.checkpoint = "Checkpoint2"
	mirrorsStage(run)
	if not run.active then
		return
	end
	openDoor(run, "Door2")
	notify(run, "solved", "Der Kristall leuchtet – das Tor öffnet sich!")
	run.checkpoint = "Checkpoint3"
	stonesStage(run)
	if not run.active then
		return
	end
	openDoor(run, "Door3")
	notify(run, "solved", "Die Steine rasten ein. Der Kristallwächter erwacht …")
	run.checkpoint = "Checkpoint4"
	guardianStage(run)
	if not run.active then
		return
	end
	rewardStage(run)
	finish(run, "done")
end

-- Watchdog: time limit, falls and respawns (a respawned character appears on the island).
local function watch(run: Run)
	while run.active do
		task.wait(0.5)
		if os.clock() - run.startedAt > SETTINGS.maxRunSeconds then
			finish(run, "timeout")
			return
		end
		for player in run.members do
			local root = rootOf(player)
			if root then
				local offset = root.Position - run.origin
				if offset.Y < -30 or math.abs(offset.X) > 150 or offset.Z < -60 or offset.Z > 320 then
					toCheckpoint(run, player)
				end
			end
		end
	end
end

local function startRun(group: { Player }, slot: number)
	local source = template :: Model
	nextRunId += 1
	local origin = SLOT_ORIGIN + Vector3.new((slot - 1) * SLOT_SPACING, 0, 0)
	local arena = source:Clone()
	arena.Name = "Expedition" .. nextRunId
	arena:PivotTo(CFrame.new(origin))
	local chest = arena:FindFirstChild("Chest") :: Model
	local exit = arena:FindFirstChild("ExitPortal") :: BasePart
	chest.Parent = nil
	exit.Parent = nil
	arena.Parent = folder

	local run: Run = {
		id = nextRunId,
		slot = slot,
		arena = arena,
		origin = origin,
		members = {},
		checkpoint = "Spawn",
		active = true,
		startedAt = os.clock(),
		rng = Random.new(),
		chest = chest,
		exit = exit,
		opened = {},
	}
	runs[slot] = run
	local spawnCf = marker(run, "Spawn")
	for _, player in group do
		local data = PlayerDataService.get(player)
		if data and player.Parent then
			run.members[player] = true
			runOf[player] = run
			data.expedition.runs += 1
			player:SetAttribute("ExpRun", run.id)
			player:SetAttribute("MusicArea", "Ruins")
			player:SetAttribute("ExpEnds", os.time() + SETTINGS.maxRunSeconds)
			teleport(player, spawnCf)
			Analytics.custom(player, "ExpeditionStarted")
		end
	end
	if next(run.members) == nil then
		finish(run, "abandoned")
		return
	end
	notify(run, "expedition", "Willkommen in den Vergessenen Ruinen!")
	task.spawn(watch, run)
	task.spawn(flow, run)
end

-- Lobby at the portal --------------------------------------------------------------------

local function freeSlot(): number?
	for slot = 1, SETTINGS.maxRuns do
		if not runs[slot] then
			return slot
		end
	end
	return nil
end

local function refreshPortalPrompt()
	if portalPrompt then
		portalPrompt.ActionText = if lobby then ("Beitreten (%d/%d)"):format(#lobby.members, SETTINGS.maxPlayers) else "Expedition starten"
	end
end

local function nearPortal(player: Player, range: number): boolean
	local root = rootOf(player)
	return portal ~= nil and root ~= nil and (root.Position - portal.Position).Magnitude <= range
end

local function runLobby()
	while lobby and os.clock() < lobby.startsAt do
		local current = lobby
		for i = #current.members, 1, -1 do
			local player = current.members[i]
			if not player.Parent or not nearPortal(player, SETTINGS.portalRange * 1.6) then
				table.remove(current.members, i)
				if player.Parent then
					player:SetAttribute("ExpObjective", nil)
					notify(player, "wrong", "Du hast das Portal verlassen – die Gruppe startet ohne dich.")
				end
			end
		end
		if #current.members == 0 then
			lobby = nil
			refreshPortalPrompt()
			return
		end
		local left = math.max(0, math.ceil(current.startsAt - os.clock()))
		for _, player in current.members do
			player:SetAttribute("ExpObjective", ("Die Expedition startet in %d s … (%d/%d Spieler, Freunde können am Portal beitreten)"):format(left, #current.members, SETTINGS.maxPlayers))
		end
		refreshPortalPrompt()
		task.wait(0.5)
	end
	local current = lobby
	lobby = nil
	refreshPortalPrompt()
	if not current then
		return
	end
	local slot = freeSlot()
	if not slot then
		for _, player in current.members do
			player:SetAttribute("ExpObjective", nil)
			notify(player, "wrong", "Alle Ruinen sind gerade belegt – gleich wieder frei!")
		end
		return
	end
	startRun(current.members, slot)
end

function ExpeditionService.join(player: Player): (boolean, string?)
	if not template then
		return false, "closed"
	end
	local data = PlayerDataService.get(player)
	if not data then
		return false, "not_loaded"
	end
	if runOf[player] then
		return false, "in_run"
	end
	if not nearPortal(player, SETTINGS.portalRange) then
		return false, "too_far"
	end
	if lobby and table.find(lobby.members, player) then
		return false, "joined"
	end
	if lobby and #lobby.members >= SETTINGS.maxPlayers then
		notify(player, "wrong", "Diese Gruppe ist voll – die nächste startet gleich danach.")
		return false, "full"
	end
	if not lobby and not freeSlot() then
		notify(player, "wrong", "Alle Ruinen sind gerade belegt – gleich wieder frei!")
		return false, "busy"
	end
	if lobby then
		table.insert(lobby.members, player)
	else
		lobby = { members = { player }, startsAt = os.clock() + SETTINGS.lobbySeconds }
		task.spawn(runLobby)
	end
	refreshPortalPrompt()
	local left = data.expedition.cooldownUntil - os.time()
	if left > 0 then
		notify(player, "expedition", ("Du bist als Begleiter dabei – neue Relikte gibt es für dich in %d:%02d."):format(left // 60, left % 60))
	else
		notify(player, "expedition", "Du bist dabei! Die Expedition startet gleich.")
	end
	return true, nil
end

-- Studio DevTools only: runs a prompt's handler for the player, with all the usual checks.
function ExpeditionService.trigger(promptInstance: ProximityPrompt, player: Player): boolean
	local handler = handlers[promptInstance]
	if handler then
		handler(player)
	end
	return handler ~= nil
end

function ExpeditionService.stopPlayer(player: Player)
	bumped[player] = nil
	if lobby then
		local i = table.find(lobby.members, player)
		if i then
			table.remove(lobby.members, i)
		end
	end
	if runOf[player] then
		ExpeditionService.leave(player)
	end
end

function ExpeditionService.init()
	template = ServerStorage:FindFirstChild("ExpeditionArena") :: Model?
	folder = Instance.new("Folder")
	folder.Name = "Expeditions"
	folder.Parent = Workspace

	local ruins = Workspace:WaitForChild("Aetheria"):FindFirstChild("ForgottenRuins")
	portal = ruins and ruins:FindFirstChild("Portal") :: BasePart?
	local subtitle = ruins and ruins:FindFirstChild("Subtitle", true)
	if not template or not portal then
		warn("[Expedition] Arena template or portal missing: the expedition stays closed.")
		return
	end
	if subtitle and subtitle:IsA("TextLabel") then
		subtitle.Text = "Expedition · 1–4 Spieler"
	end
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Expedition starten"
	p.ObjectText = "Vergessene Ruinen"
	p.HoldDuration = 0.4
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = portal
	handlers[p] = function(player: Player)
		if promptLimiter:allow(player) then
			ExpeditionService.join(player)
		end
	end
	p.Triggered:Connect(handlers[p])
	portalPrompt = p

	Net.func("LeaveExpedition").OnServerInvoke = function(player: Player)
		if not leaveLimiter:allow(player) then
			return false
		end
		return ExpeditionService.leave(player)
	end
end

return ExpeditionService
