--!strict
-- Builds and drives the HUD in code: coin counter, guide banner (Lumi), navigation, toasts
-- and one shared panel for the collection book, pedestal picker, daily quests and shop.
-- Sizes are touch-first and the HUD scales with the viewport so it stays readable on phones.
-- Visual language: warm white cards, violet headers, gold for coins, soft drop shadows and
-- a short press/pop animation on everything the player touches.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Credits = require(ReplicatedStorage.Shared.Credits)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local RelicVisuals = require(ReplicatedStorage.Shared.RelicVisuals)
local Audio = require(script.Parent.Parent.Audio)
local ClientState = require(script.Parent.Parent.ClientState)
local Settings = require(script.Parent.Parent.Settings)

local player = Players.LocalPlayer
local LANG = Locale.of(player)

-- Translates a German source text (and formats it) for this player.
local function L(source: string, ...: any): string
	return Locale.format(LANG, source, ...)
end

local C = Color3.fromRGB
local THEME = {
	panel = C(255, 250, 242),
	card = C(255, 255, 255),
	edge = C(228, 214, 250),
	text = C(48, 32, 78),
	subtle = C(125, 105, 155),
	violet = C(150, 92, 240),
	violetDeep = C(98, 52, 196),
	gold = C(255, 200, 74),
	goldLight = C(255, 228, 130),
	goldDeep = C(222, 142, 28),
	teal = C(70, 205, 210),
	tealDeep = C(28, 140, 168),
	pink = C(240, 120, 175),
	pinkDeep = C(196, 66, 132),
	amber = C(246, 170, 50),
	amberDeep = C(208, 112, 18),
	dark = C(36, 22, 60),
	locked = C(228, 222, 238),
	lockedDeep = C(196, 186, 214),
	white = Color3.new(1, 1, 1),
	shadow = C(30, 15, 55),
	lumi = C(110, 235, 240),
}
local TITLE = Enum.Font.FredokaOne
local BODY = Enum.Font.BuilderSansBold
local ROBUX = utf8.char(0xE002) -- Roblox fonts draw this private-use glyph as the Robux icon

local ERRORS: { [string]: string } = {
	too_far = "Geh etwas näher heran.",
	not_owned = "Dieses Relikt hast du gerade nicht im Inventar.",
	locked_slot = "Dieses Podest ist noch nicht gebaut – kauf es an einer Bau-Taste.",
	rate = "Nicht so schnell!",
	gone = "Dieses Relikt ist schon eingesammelt.",
	no_plot = "Du hast noch keine Schatzkammer.",
	not_loaded = "Deine Daten werden noch geladen …",
	no_coins = "Dafür fehlen dir noch Münzen.",
	max_tier = "Deine Schatzkammer ist schon voll ausgebaut.",
	luck_active = "Deine Glücksrune wirkt noch.",
	not_done = "Diese Aufgabe ist noch nicht erledigt.",
	claimed = "Diese Belohnung hast du schon abgeholt.",
	no_map = "Du hast gerade keine vollständige Schatzkarte.",
	bad_quest = "Diese Aufgabe gibt es nicht mehr.",
}
local NOTIFY_COLORS: { [string]: Color3 } = {
	upgrade = THEME.gold,
	build = THEME.gold,
	milestone = C(150, 230, 255),
	purchase = THEME.gold,
	visit = C(255, 200, 230),
	offline = THEME.gold,
	step = C(170, 240, 200),
	solved = THEME.gold,
	wrong = C(255, 190, 190),
	hit = C(150, 230, 255),
	expedition = C(205, 185, 255),
	reward = THEME.gold,
	map = C(255, 225, 160),
}
local NOTIFY_SOUNDS: { [string]: string } = {
	upgrade = "upgrade",
	build = "purchase",
	milestone = "claim",
	purchase = "purchase",
	visit = "sparkle",
	offline = "claim",
	step = "collect",
	solved = "upgrade",
	wrong = "error",
	hit = "sparkle",
	expedition = "whoosh",
	reward = "claim",
	map = "sparkle",
}
local QUEST_ICONS: { [string]: string } = {
	collect = "🔮",
	forest = "🌲",
	place = "🏛️",
	earn = "💰",
	uncommon = "💎",
	visit = "👋",
}
-- Icon and banner gradient for each shop item.
local SHOP_STYLE: { [string]: { icon: string, top: Color3, bottom: Color3 } } = {
	luck = { icon = "🍀", top = C(150, 235, 170), bottom = C(50, 170, 120) },
	wings = { icon = "✨", top = C(205, 170, 255), bottom = C(120, 80, 225) },
	aura = { icon = "🌟", top = C(255, 220, 130), bottom = C(232, 140, 50) },
	vip = { icon = "👑", top = C(255, 224, 110), bottom = C(214, 140, 30) },
	double_coins = { icon = "⚡", top = C(130, 220, 255), bottom = C(60, 130, 230) },
	coins_small = { icon = "👛", top = C(255, 190, 220), bottom = C(210, 90, 150) },
	coins_large = { icon = "💰", top = C(255, 210, 120), bottom = C(220, 130, 40) },
}

local Hud = {}

local gui: ScreenGui
local scales: { UIScale } = {}
local coinLabel: TextLabel
local rateLabel: TextLabel
local luckLabel: TextLabel
local navFrame: GuiObject
local sideFrame: GuiObject
local expFrame: Frame
local expLabel: TextLabel
local expTimer: TextLabel
local expLeave: TextButton
local guideFrame: Frame
local guideLabel: TextLabel
local skipButton: TextButton
local questBadge: Frame
local mapBadge: Frame
local toastStack: Frame
local panelHost: Frame
local panel: Frame
local panelPop: UIScale
local panelIcon: TextLabel
local panelTitle: TextLabel
local panelInfo: TextLabel
local returnButton: TextButton
local grid: ScrollingFrame
local gridLayout: UIGridLayout
local panelMode: { kind: string, slot: number? }? = nil
local guideText: string? = nil
local guideIsTutorial = false
local priceCache: { [string]: string } = {}

-- Generic helpers ----------------------------------------------------------------------

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function round(): UICorner
	return new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

local function stroke(color: Color3, thickness: number, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function textStroke(color: Color3, thickness: number): UIStroke
	return new("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

local function gradient(top: Color3, bottom: Color3): UIGradient
	return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 })
end

local function hpad(px: number): UIPadding
	return new("UIPadding", { PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px) })
end

local function hlist(padding: number): UIListLayout
	return new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or BODY
	props.TextColor3 = props.TextColor3 or THEME.text
	props.Parent = parent
	return new("TextLabel", props)
end

local function scaled(frame: GuiObject): GuiObject
	local scale = new("UIScale", { Parent = frame })
	table.insert(scales, scale)
	return frame
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function formatNumber(n: number): string
	return Locale.number(LANG, n)
end

local function formatRate(rate: number): string
	return Locale.decimal(LANG, rate)
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local vp = camera.ViewportSize
	local s = math.clamp(math.min(vp.X / 1100, vp.Y / 620), 0.62, 1.15)
	for _, scale in scales do
		scale.Scale = s
	end
end

-- Style kit ----------------------------------------------------------------------------

-- Squashes the slot slightly while pressed so every button feels tactile.
local function pressable(button: GuiButton, target: GuiObject)
	local scale = new("UIScale", { Parent = target })
	local function to(value: number)
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = value }):Play()
	end
	button.MouseButton1Down:Connect(function()
		to(0.93)
	end)
	button.MouseButton1Up:Connect(function()
		to(1)
	end)
	button.MouseLeave:Connect(function()
		to(1)
	end)
	button.Activated:Connect(function()
		Audio.play("click")
	end)
end

-- A layout slot holding a soft drop shadow and the surface on top of it. Children render above
-- their parent, so the shadow has to be a sibling of the surface, not its child.
local function shadowed(className: string, slotProps: { [string]: any }, surfaceProps: { [string]: any }, radius: number): (Frame, any)
	slotProps.BackgroundTransparency = 1
	local slot = new("Frame", slotProps)
	new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.shadow,
		BackgroundTransparency = 0.8,
		Parent = slot,
	}, { corner(radius) })
	surfaceProps.Name = surfaceProps.Name or "Surface"
	surfaceProps.Size = UDim2.fromScale(1, 1)
	surfaceProps.Parent = slot
	local surface = new(className, surfaceProps, { corner(radius) })
	return slot, surface
end

local function coinIcon(parent: Instance, size: number, order: number?): Frame
	local coin = new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = THEME.white,
		LayoutOrder = order or 0,
		Parent = parent,
	}, { round(), stroke(THEME.goldDeep, math.max(2, size / 14)), gradient(THEME.goldLight, THEME.gold) })
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.52, 0.52),
		BackgroundColor3 = THEME.goldLight,
		Parent = coin,
	}, { round(), stroke(THEME.goldDeep, math.max(1, size / 20), 0.35) })
	return coin
end

-- Big gradient button with an icon. vertical = icon above a small caption (side menu).
local function bigButton(name: string, icon: string, text: string, top: Color3, bottom: Color3, size: Vector2, order: number, vertical: boolean, onClick: () -> ()): (Frame, TextButton)
	local slot, button = shadowed("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(size.X, size.Y),
		LayoutOrder = order,
	}, { Name = "Button", Text = "", AutoButtonColor = false, BackgroundColor3 = THEME.white }, 22)
	gradient(top, bottom).Parent = button
	stroke(THEME.white, 3, 0.15).Parent = button
	if vertical then
		label(button, { Position = UDim2.fromScale(0, 0.08), Size = UDim2.fromScale(1, 0.52), Text = icon, TextScaled = true, Font = TITLE })
		local caption = label(button, {
			Position = UDim2.new(0, 4, 0.62, 0),
			Size = UDim2.new(1, -8, 0.28, 0),
			Text = text,
			TextScaled = true,
			Font = TITLE,
			TextColor3 = THEME.white,
		})
		textStroke(bottom:Lerp(THEME.dark, 0.4), 1.5).Parent = caption
	else
		local layout = hlist(8)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local row = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = button }, { layout })
		label(row, { Size = UDim2.fromOffset(34, 34), Text = icon, TextScaled = true, Font = TITLE, LayoutOrder = 1 })
		local caption = label(row, {
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = text,
			Font = TITLE,
			TextSize = 25,
			TextColor3 = THEME.white,
			LayoutOrder = 2,
		})
		textStroke(bottom:Lerp(THEME.dark, 0.4), 1.5).Parent = caption
	end
	button.Activated:Connect(onClick)
	pressable(button, slot)
	return slot, button
end

-- Small rounded pill button used inside cards and rows. Disabled pills are grey and inert.
-- A UIGradient also tints its own object's text, so the gradient sits on a child fill and
-- the caption is a separate label above it.
local function pillButton(parent: Instance, name: string, text: string, top: Color3, bottom: Color3, enabled: boolean, props: { [string]: any }, onClick: () -> ()): TextButton
	local textSize = props.TextSize or 20
	local textColor = if enabled then props.TextColor3 or THEME.white else THEME.subtle
	props.TextSize = nil
	props.TextColor3 = nil
	props.Name = name
	props.Text = ""
	props.AutoButtonColor = false
	props.BackgroundTransparency = 1
	props.Parent = parent
	local button = new("TextButton", props)
	new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.white, Parent = button }, {
		round(),
		if enabled then gradient(top, bottom) else gradient(THEME.locked, THEME.lockedDeep),
	})
	label(button, { Name = "Caption", Size = UDim2.fromScale(1, 1), Text = text, Font = TITLE, TextSize = textSize, TextColor3 = textColor })
	if enabled then
		button.Activated:Connect(onClick)
		pressable(button, button)
	end
	return button
end

local function chip(parent: Instance, text: string, fill: Color3, textColor: Color3, props: { [string]: any }): TextLabel
	props.Text = text
	props.BackgroundColor3 = fill
	props.BackgroundTransparency = props.BackgroundTransparency or 0
	props.Font = props.Font or BODY
	props.TextSize = props.TextSize or 14
	props.TextColor3 = textColor
	props.AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.X
	props.Parent = parent
	return new("TextLabel", props, { round(), hpad(8) })
end

-- Toasts and guide ---------------------------------------------------------------------

function Hud.toast(text: string, color: Color3?)
	local accent = color or THEME.white
	local toast = new("Frame", {
		Size = UDim2.fromOffset(0, 50),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.dark,
		BackgroundTransparency = 0.08,
		Parent = toastStack,
	}, { round(), hpad(22) })
	local edge = stroke(accent, 2, 0.3)
	edge.Parent = toast
	local text_ = label(toast, {
		Size = UDim2.fromOffset(0, 50),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = text,
		TextColor3 = accent,
		Font = TITLE,
		TextSize = 23,
	})
	local pop = new("UIScale", { Scale = 0.75, Parent = toast })
	TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local toasts = {}
	for _, c in toastStack:GetChildren() do
		if c:IsA("Frame") then
			table.insert(toasts, c)
		end
	end
	if #toasts > 3 then
		toasts[1]:Destroy()
	end
	task.delay(2.6, function()
		if toast.Parent then
			local fade = TweenInfo.new(0.35)
			TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(text_, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(edge, fade, { Transparency = 1 }):Play()
			task.wait(0.35)
			toast:Destroy()
		end
	end)
end

function Hud.showError(code: any)
	Audio.play("error")
	Hud.toast(L(ERRORS[tostring(code)] or "Das hat nicht geklappt."), C(255, 200, 200))
end

function Hud.relicCollected(def: RelicDefs.RelicDef, isNew: boolean?)
	local rarity = Config.Rarities[def.rarity]
	local text = L("%s gefunden! (%s)", L(def.name), L(rarity.name))
	Hud.toast(if isNew then L("Neu im Sammelbuch: %s", text) else text, rarity.color)
end

local function claimableQuests(state: any): number
	local n = 0
	local weekly = state.weekly
	if weekly and weekly.goal > 0 and not weekly.claimed and weekly.progress >= weekly.goal then
		n += 1
	end
	for _, quest in state.quests or {} do
		if not quest.claimed and quest.progress >= quest.goal then
			n += 1
		end
	end
	return n
end

local function refreshGuide()
	local state = ClientState.data
	local text = guideText
	if not text and state and claimableQuests(state) > 0 then
		text = L("Eine Aufgabe ist erledigt – hol dir deine Belohnung ab!")
	end
	local inExpedition = player:GetAttribute("ExpObjective") ~= nil
	guideFrame.Visible = text ~= nil and panelMode == nil and not inExpedition
	guideLabel.Text = text or ""
	skipButton.Visible = guideIsTutorial and guideText ~= nil
	questBadge.Visible = state ~= nil and claimableQuests(state) > 0
	mapBadge.Visible = state ~= nil and state.maps ~= nil and state.maps.spot ~= 0
end

-- Lumi sets the tutorial line here; nil hides it (quest hints may still show).
function Hud.setGuide(text: string?, isTutorial: boolean)
	if text == guideText and isTutorial == guideIsTutorial then
		return
	end
	guideText, guideIsTutorial = text, isTutorial
	refreshGuide()
end

-- Expedition bar: the server's current objective, the time left and a way out.
local function refreshExpedition()
	local objective = player:GetAttribute("ExpObjective")
	expFrame.Visible = type(objective) == "string" and panelMode == nil
	expLabel.Text = if type(objective) == "string" then objective else ""
	local inRun = player:GetAttribute("ExpRun") ~= nil
	expLeave.Visible = inRun
	local ends = player:GetAttribute("ExpEnds")
	local left = if type(ends) == "number" and inRun then math.max(0, ends - os.time()) else 0
	expTimer.Visible = left > 0
	expTimer.Text = ("⏳ %d:%02d"):format(left // 60, left % 60)
end

local function refreshCoins()
	coinLabel.Text = formatNumber(player:GetAttribute("Coins") :: number? or 0)
	rateLabel.Text = "+" .. formatRate(player:GetAttribute("CoinRate") :: number? or 0) .. "/s"
	local luck = player:GetAttribute("LuckUntil")
	local left = if type(luck) == "number" then luck - os.time() else 0
	luckLabel.Visible = left > 0
	if left > 0 then
		luckLabel.Text = ("🍀 %d:%02d"):format(left // 60, left % 60)
	end
end

-- Panel content ------------------------------------------------------------------------

local function clearGrid()
	for _, c in grid:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- What the open panel shows, so state pushes that change nothing visible skip the rebuild.
local lastSignature = ""
local function signature(kind: string, state: any): string
	if kind == "settings" or kind == "credits" then
		return kind
	end
	if kind == "map" then
		local maps = state.maps or {}
		return ("map|%s|%s|%s"):format(tostring(maps.pieces), tostring(maps.spot), tostring(maps.found))
	end
	local parts = { kind, tostring(state.tier) }
	if kind == "quests" then
		for _, quest in state.quests or {} do
			table.insert(parts, ("%s:%d:%s"):format(quest.id, math.floor(quest.progress), tostring(quest.claimed)))
		end
		local weekly = state.weekly
		if weekly then
			table.insert(parts, ("weekly:%s:%d:%s"):format(weekly.id, math.floor(weekly.progress), tostring(weekly.claimed)))
		end
	elseif kind ~= "shop" then
		for id, n in state.inventory do
			table.insert(parts, id .. n)
		end
		for slot, id in state.display do
			table.insert(parts, slot .. id)
		end
		table.insert(parts, tostring(count(state.discovered or {})))
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

local function viewport(def: RelicDefs.RelicDef, parent: Instance)
	local frame = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = C(200, 190, 220),
		LightColor = THEME.white,
		LightDirection = Vector3.new(-1, -1, -0.6),
		Parent = parent,
	})
	local model = RelicVisuals.build(def)
	model:PivotTo(CFrame.Angles(0, math.rad(-25), 0))
	model.Parent = frame
	frame.CurrentCamera = new("Camera", { FieldOfView = 36, CFrame = CFrame.lookAt(Vector3.new(0, 1, 4.6), Vector3.zero), Parent = frame })
end

-- Coloured art area at the top of a card (relic preview, "?" or shop icon).
local function cardArt(card: Instance, top: Color3, bottom: Color3, height: number): Frame
	return new("Frame", {
		Name = "Art",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, height),
		BackgroundColor3 = THEME.white,
		ClipsDescendants = true,
		Parent = card,
	}, { corner(14), gradient(top, bottom) })
end

local function cardSurface(name: string): Frame
	return new("Frame", { Name = name, BackgroundColor3 = THEME.card, Parent = grid }, { corner(18), stroke(THEME.edge, 2) })
end

local function relicCard(def: RelicDefs.RelicDef, held: number, line: string, onPick: (() -> ())?)
	local rarity = Config.Rarities[def.rarity]
	local card = cardSurface("Card_" .. def.id)
	card:FindFirstChildOfClass("UIStroke").Color = rarity.color:Lerp(THEME.edge, 0.3)
	local art = cardArt(card, rarity.color:Lerp(THEME.white, 0.35), rarity.color:Lerp(THEME.dark, 0.45), 92)
	viewport(def, art)
	if held > 0 then
		chip(card, "x" .. held, THEME.dark, THEME.white, {
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(0, 22),
			TextSize = 15,
			BackgroundTransparency = 0.15,
		})
	end
	label(card, { Position = UDim2.fromOffset(8, 102), Size = UDim2.new(1, -16, 0, 24), Text = L(def.name), Font = TITLE, TextScaled = true })
	label(card, { Position = UDim2.fromOffset(8, 126), Size = UDim2.new(1, -16, 0, 18), Text = line, TextColor3 = THEME.subtle, TextSize = 15 })
	local badge = chip(card, L(rarity.name), rarity.color:Lerp(THEME.white, 0.55), rarity.color:Lerp(THEME.dark, 0.55), {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 146),
		Size = UDim2.fromOffset(0, 18),
		TextSize = 13,
	})
	badge.Name = "Rarity"
	if onPick then
		-- A ViewportFrame swallows taps even when inactive, so a clear button covers the card.
		local hit = new("TextButton", {
			Name = "Pick",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 3,
			Parent = card,
		})
		hit.Activated:Connect(onPick)
		pressable(hit, card)
	end
end

local function lockedCard(def: RelicDefs.RelicDef)
	local rarity = Config.Rarities[def.rarity]
	local card = cardSurface("Locked_" .. def.id)
	card.BackgroundColor3 = C(248, 245, 252)
	local art = cardArt(card, THEME.locked, THEME.lockedDeep, 92)
	label(art, { Size = UDim2.fromScale(1, 1), Text = "?", Font = TITLE, TextSize = 58, TextColor3 = THEME.white })
	label(card, { Position = UDim2.fromOffset(8, 102), Size = UDim2.new(1, -16, 0, 24), Text = "???", Font = TITLE, TextSize = 22, TextColor3 = THEME.subtle })
	label(card, { Position = UDim2.fromOffset(8, 126), Size = UDim2.new(1, -16, 0, 18), Text = L("Noch nicht entdeckt"), TextColor3 = THEME.subtle, TextSize = 14 })
	chip(card, L(rarity.name), rarity.color:Lerp(THEME.white, 0.6), rarity.color:Lerp(THEME.dark, 0.5), {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 146),
		Size = UDim2.fromOffset(0, 18),
		TextSize = 13,
	})
end

local function setCells(size: UDim2)
	gridLayout.CellSize = size
end

local function emptyNote(text: string)
	setCells(UDim2.new(1, -8, 0, 120))
	local note = cardSurface("Empty")
	label(note, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 50), Text = "🔍", TextScaled = true })
	label(note, {
		Position = UDim2.fromOffset(16, 68),
		Size = UDim2.new(1, -32, 0, 40),
		Text = text,
		TextWrapped = true,
		TextColor3 = THEME.subtle,
		TextSize = 19,
	})
end

local function setHeader(icon: string, title: string, info: string)
	panelIcon.Text = icon
	panelTitle.Text = title
	panelInfo.Text = info
end

local function renderCollection(state: any)
	setCells(UDim2.fromOffset(140, 172))
	local displayedCount: { [string]: number } = {}
	for _, id in state.display do
		displayedCount[id] = (displayedCount[id] or 0) + 1
	end
	local discovered = count(state.discovered or {})
	local nextMilestone = Config.Milestones[(state.milestones or 0) + 1]
	setHeader("📖", L("Sammelbuch"), if nextMilestone
		then L("%d von %d entdeckt · bei %d gibt es +%s Münzen", discovered, #RelicDefs.list, nextMilestone.count, formatNumber(nextMilestone.reward))
		else L("Alle %d Relikte entdeckt!", #RelicDefs.list))
	for _, def in RelicDefs.list do
		if state.discovered and state.discovered[def.id] then
			local shown = displayedCount[def.id] or 0
			relicCard(def, state.inventory[def.id] or 0, if shown > 0 then L("%d ausgestellt", shown) else ("+%s/s"):format(formatRate(def.rate)), nil)
		else
			lockedCard(def)
		end
	end
end

local function renderPedestal(state: any, slot: number)
	setCells(UDim2.fromOffset(140, 172))
	local occupant = state.display[tostring(slot)]
	local def = occupant and RelicDefs.byId[occupant]
	setHeader("🏛️", L("Podest %d", slot), if def then L("Ausgestellt: %s (+%s/s) – wähle ein Relikt zum Tauschen.", L(def.name), formatRate(def.rate))
		else L("Wähle ein Relikt zum Ausstellen."))
	returnButton.Visible = def ~= nil
	local rows = {}
	for id, n in state.inventory do
		local rowDef = RelicDefs.byId[id]
		if rowDef and n > 0 then
			table.insert(rows, { def = rowDef, count = n })
		end
	end
	table.sort(rows, function(a, b)
		return a.def.rate > b.def.rate
	end)
	for _, row in rows do
		relicCard(row.def, row.count, ("+%s/s"):format(formatRate(row.def.rate)), function()
			local ok, success, err = pcall(function()
				return Net.func("Place"):InvokeServer(slot, row.def.id)
			end)
			if ok and success then
				Audio.play("place")
				Hud.toast(L("%s ausgestellt! +%s/s", L(row.def.name), formatRate(row.def.rate)), THEME.gold)
				Hud.close()
			else
				Hud.showError(err)
			end
		end)
	end
	if #rows == 0 then
		emptyNote(L("Keine Relikte im Inventar. Fang Wächter-Geister auf dem Platz und im Flüsterwald!"))
	end
end

-- One goal row: icon, text, progress bar, coin reward and the claim button.
local function questRow(name: string, icon: string, text: string, progress: number, goal: number, reward: number, claimed: boolean, weekly: boolean, onClaim: () -> ())
	local done = progress >= goal
	local top, bottom = THEME.teal, THEME.tealDeep
	if weekly then
		top, bottom = THEME.violet, THEME.violetDeep
	end
	local row = cardSurface(name)
	if claimed then
		row.BackgroundColor3 = C(246, 252, 248)
	elseif weekly then
		row.BackgroundColor3 = C(250, 245, 255)
		row:FindFirstChildOfClass("UIStroke").Color = THEME.violet:Lerp(THEME.white, 0.4)
	end
	local bubble = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(58, 58),
		BackgroundColor3 = THEME.white,
		Parent = row,
	}, { round(), gradient(top:Lerp(THEME.white, 0.4), bottom) })
	label(bubble, { Size = UDim2.fromScale(1, 1), Text = icon, TextScaled = true })
	new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = bubble })

	label(row, {
		Position = UDim2.fromOffset(86, 12),
		Size = UDim2.new(1, -330, 0, 28),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = TITLE,
		TextSize = 21,
	})
	local fraction = math.clamp(progress / goal, 0, 1)
	local bar = new("Frame", { Position = UDim2.fromOffset(86, 48), Size = UDim2.new(1, -330, 0, 14), BackgroundColor3 = THEME.locked, Parent = row }, { round() })
	if fraction > 0 then
		new("Frame", { Size = UDim2.fromScale(fraction, 1), BackgroundColor3 = THEME.white, Parent = bar }, {
			round(),
			gradient(top:Lerp(THEME.white, 0.25), bottom),
		})
	end
	label(row, {
		Position = UDim2.fromOffset(86, 64),
		Size = UDim2.new(1, -330, 0, 18),
		Text = ("%s / %s"):format(formatNumber(progress), formatNumber(goal)),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.subtle,
		TextSize = 15,
	})
	local rewardRow = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -164, 0.5, 0),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = row,
	}, { hlist(4) })
	coinIcon(rewardRow, 20, 1)
	label(rewardRow, { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Text = formatNumber(reward), Font = TITLE, TextSize = 18, TextColor3 = THEME.amberDeep, LayoutOrder = 2 })
	if weekly then
		label(rewardRow, { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Text = "+ 🗺️", Font = TITLE, TextSize = 18, LayoutOrder = 3 })
	end

	pillButton(row, "Claim", if claimed then L("✓ Erledigt") elseif done then L("Abholen") else L("Läuft …"), THEME.goldLight, THEME.amberDeep, done and not claimed, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(140, 48),
		TextColor3 = C(110, 58, 8),
	}, onClaim)
end

local function claim(remote: string, arg: any, reward: number)
	local ok, success, err = pcall(function()
		return Net.func(remote):InvokeServer(arg)
	end)
	if ok and success then
		Audio.play("claim")
		Hud.toast(L("+%s Münzen!", formatNumber(reward)), THEME.gold)
	else
		Hud.showError(err)
	end
end

local function renderQuests(state: any)
	setCells(UDim2.new(1, -8, 0, 92))
	setHeader("📜", L("Aufgaben"), L("Jeden Tag neue Aufgaben, dazu ein Wochenziel ganz ohne Eile."))
	local weekly = state.weekly
	local weeklyDef = weekly and Config.Weekly.byId[weekly.id]
	if weeklyDef then
		local reward = Config.Weekly.rewardByTier[state.tier]
		questRow("Weekly", "🏆", L("Woche: %s", L(weeklyDef.text, weekly.goal)), weekly.progress, weekly.goal, reward, weekly.claimed, true, function()
			claim("ClaimWeekly", nil, reward)
		end)
	end
	local defs = {}
	for _, quest in Config.Quests.pool do
		defs[quest.id] = quest
	end
	local reward = Config.Quests.rewardByTier[state.tier]
	for index, quest in state.quests or {} do
		local def = defs[quest.id]
		questRow("Quest" .. index, QUEST_ICONS[quest.id] or "⭐", if def then L(def.text, quest.goal) else quest.id, quest.progress, quest.goal, reward, quest.claimed, false, function()
			claim("ClaimQuest", index, reward)
		end)
	end
end

local function fetchPrice(key: string, id: number, isPass: boolean, target: TextLabel)
	if priceCache[key] then
		target.Text = priceCache[key]
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product)
		end)
		if ok and info and info.PriceInRobux then
			priceCache[key] = ("%s %d"):format(ROBUX, info.PriceInRobux)
			if target.Parent then
				target.Text = priceCache[key]
			end
		end
	end)
end

-- Shop card: icon banner, name, description, price row and a buy button.
local function shopCard(key: string, title: string, text: string, coins: boolean, price: string, buttonText: string, enabled: boolean, onClick: () -> ()): TextLabel
	local style = SHOP_STYLE[key] or SHOP_STYLE.wings
	local card = cardSurface("Item_" .. key)
	local art = cardArt(card, style.top, style.bottom, 64)
	label(art, { Size = UDim2.fromScale(1, 1), Text = style.icon, TextScaled = true })
	new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = art })
	label(card, { Position = UDim2.fromOffset(12, 76), Size = UDim2.new(1, -24, 0, 26), Text = title, Font = TITLE, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left })
	label(card, {
		Position = UDim2.fromOffset(12, 102),
		Size = UDim2.new(1, -24, 0, 50),
		Text = text,
		TextWrapped = true,
		TextColor3 = THEME.subtle,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local priceRow = new("Frame", { Position = UDim2.fromOffset(12, 154), Size = UDim2.new(1, -24, 0, 24), BackgroundTransparency = 1, Parent = card }, { hlist(5) })
	if coins then
		coinIcon(priceRow, 20, 1)
	end
	local priceLabel = label(priceRow, {
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = price,
		Font = TITLE,
		TextSize = 19,
		TextColor3 = if coins then THEME.amberDeep else THEME.text,
		LayoutOrder = 2,
	})
	pillButton(card, "Buy", buttonText, THEME.violet, THEME.violetDeep, enabled, {
		Position = UDim2.new(0, 12, 1, -54),
		Size = UDim2.new(1, -24, 0, 44),
	}, onClick)
	return priceLabel
end

local function renderShop(state: any)
	setCells(UDim2.fromOffset(204, 236))
	setHeader("🛒", L("Shop"), L("Alles optional – Aetheria ist komplett ohne Käufe spielbar."))
	local luckCost = Config.LuckRune.costByTier[state.tier]
	local luck = player:GetAttribute("LuckUntil")
	local luckActive = type(luck) == "number" and luck > os.time()
	shopCard(
		"luck",
		L("Glücksrune"),
		L("%d Minuten doppelte Chance auf seltene Relikte.", Config.LuckRune.seconds // 60),
		true,
		formatNumber(luckCost),
		if luckActive then L("Wirkt gerade") else L("Mit Münzen kaufen"),
		not luckActive,
		function()
			local ok, success, err = pcall(function()
				return Net.func("BuyLuck"):InvokeServer()
			end)
			if ok and success then
				Audio.play("purchase")
				Hud.toast(L("Die Glücksrune leuchtet! Seltene Relikte erscheinen öfter."), THEME.gold)
				Hud.close()
			else
				Hud.showError(err)
			end
		end
	)
	for _, pass in Config.Shop.passes do
		local owned = player:GetAttribute("Pass_" .. pass.key) == true
		local live = pass.id ~= 0
		local priceLabel = shopCard(pass.key, L(pass.name), L(pass.text), false, if live then "…" else L("Bald verfügbar"), if owned then L("✓ Besitzt du") elseif live then L("Kaufen") else L("Bald"), live and not owned, function()
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end)
		if live then
			fetchPrice(pass.key, pass.id, true, priceLabel)
		end
	end
	for _, product in Config.Shop.products do
		local live = product.id ~= 0
		local text = L("%s +%s Münzen.", L(product.text), formatNumber(product.coinsByTier[state.tier]))
		local priceLabel = shopCard(product.key, L(product.name), text, false, if live then "…" else L("Bald verfügbar"), if live then L("Kaufen") else L("Bald"), live, function()
			MarketplaceService:PromptProductPurchase(player, product.id)
		end)
		if live then
			fetchPrice(product.key, product.id, false, priceLabel)
		end
	end
end

-- Settings row: icon bubble, title and subtitle on the left, controls on the right.
local function settingsRow(name: string, icon: string, title: string, subtitle: string): Frame
	local row = cardSurface(name)
	local bubble = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(54, 54),
		BackgroundColor3 = THEME.white,
		Parent = row,
	}, { round(), gradient(THEME.violet:Lerp(THEME.white, 0.45), THEME.violetDeep) })
	label(bubble, { Size = UDim2.fromScale(1, 1), Text = icon, TextScaled = true })
	new("UIPadding", { PaddingTop = UDim.new(0, 11), PaddingBottom = UDim.new(0, 11), PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11), Parent = bubble })
	label(row, { Position = UDim2.fromOffset(82, 12), Size = UDim2.new(0.5, -82, 0, 28), Text = title, Font = TITLE, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left })
	label(row, {
		Name = "Subtitle",
		Position = UDim2.fromOffset(82, 42),
		Size = UDim2.new(0.5, -82, 0, 20),
		Text = subtitle,
		TextColor3 = THEME.subtle,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	return row
end

-- − [■■■■■□□□□□] + for a 0..1 volume in Config.SettingsStep steps.
local function volumeRow(key: string, icon: string, title: string)
	local value = (Settings.values :: any)[key] :: number
	local row = settingsRow("Setting_" .. key, icon, L(title), if value <= 0 then L("Stumm") else ("%d %%"):format(math.floor(value * 100 + 0.5)))
	local steps = math.floor(1 / Config.SettingsStep + 0.5)
	local filled = math.floor(value / Config.SettingsStep + 0.5)
	local controls = new("Frame", {
		Name = "Controls",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(300, 48),
		BackgroundTransparency = 1,
		Parent = row,
	}, { hlist(10) })
	local function step(delta: number)
		Settings.set(key, value + delta * Config.SettingsStep)
	end
	pillButton(controls, "Minus", "−", THEME.violet, THEME.violetDeep, true, { Size = UDim2.fromOffset(48, 48), TextSize = 30, LayoutOrder = 1 }, function()
		step(-1)
	end)
	local bar = new("Frame", { Name = "Bar", Size = UDim2.fromOffset(184, 22), BackgroundTransparency = 1, LayoutOrder = 2, Parent = controls }, { hlist(3) })
	for i = 1, steps do
		new("Frame", {
			Size = UDim2.fromOffset(15.7, 22),
			BackgroundColor3 = if i <= filled then THEME.white else THEME.locked,
			LayoutOrder = i,
			Parent = bar,
		}, { corner(5), if i <= filled then gradient(THEME.teal:Lerp(THEME.white, 0.2), THEME.tealDeep) else nil :: any })
	end
	pillButton(controls, "Plus", "+", THEME.violet, THEME.violetDeep, true, { Size = UDim2.fromOffset(48, 48), TextSize = 30, LayoutOrder = 3 }, function()
		step(1)
	end)
end

local function renderSettings()
	setCells(UDim2.new(1, -8, 0, 78))
	setHeader("⚙️", L("Einstellungen"), L("Wird in deinem Profil gespeichert."))
	volumeRow("music", "🎵", "Musik")
	volumeRow("sfx", "🔔", "Effekte")
	local hints = Settings.values.hints
	local lumi = settingsRow("Setting_hints", "✨", L("Lumi-Hinweise"), if hints then L("Lumi zeigt dir den Weg.") else L("Lumi ist ausgeblendet."))
	local top, bottom = THEME.teal, THEME.tealDeep
	if not hints then
		top, bottom = THEME.locked, THEME.lockedDeep
	end
	pillButton(lumi, "Toggle", if hints then L("An") else L("Aus"), top, bottom, true, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(120, 48),
		TextColor3 = if hints then THEME.white else THEME.subtle,
	}, function()
		Settings.set("hints", not Settings.values.hints)
	end)
	local credits = settingsRow("Setting_credits", "📜", L("Credits"), L("Musik, Sounds und Mitwirkende"))
	pillButton(credits, "Open", L("Ansehen"), THEME.goldLight, THEME.amberDeep, true, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(120, 48),
		TextColor3 = C(110, 58, 8),
	}, function()
		Hud.openCredits()
	end)
end

local function renderCredits()
	setHeader("📜", L("Credits"), L("Danke an alle, deren Werke Aetheria lebendig machen."))
	local lines = {}
	for _, section in Credits.sections() do
		table.insert(lines, ('<font color="#%s"><b>%s</b></font>'):format(THEME.violetDeep:ToHex(), L(section.title)))
		for _, line in section.lines do
			table.insert(lines, "   " .. L(line))
		end
		table.insert(lines, "")
	end
	setCells(UDim2.new(1, -8, 0, 64 + #lines * 21))
	local card = cardSurface("CreditsText")
	pillButton(card, "Back", L("‹ Zurück"), THEME.violet, THEME.violetDeep, true, {
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.fromOffset(130, 38),
		TextSize = 18,
	}, function()
		Hud.openSettings()
	end)
	label(card, {
		Position = UDim2.fromOffset(18, 58),
		Size = UDim2.new(1, -36, 1, -64),
		Text = table.concat(lines, "\n"),
		RichText = true,
		TextWrapped = true,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end

-- Treasure map: a drawn island with the plaza, forest, ruins and plots, the player's
-- position and - once the map is complete - the red X of the hidden treasure.
local MAP_SIZE = 300
local MAP_SCALE = MAP_SIZE / 470

local function mapPoint(position: Vector3): UDim2
	return UDim2.fromOffset(MAP_SIZE / 2 + position.X * MAP_SCALE, MAP_SIZE / 2 + position.Z * MAP_SCALE)
end

local function mapDot(parent: Instance, position: Vector3, size: number, color: Color3, name: string?): Frame
	return new("Frame", {
		Name = name or "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = mapPoint(position),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		Parent = parent,
	}, { round() })
end

local function renderMap(state: any)
	local maps = state.maps or { pieces = 0, spot = 0, found = 0 }
	local spot = Config.Maps.spots[maps.spot]
	setCells(UDim2.new(1, -8, 0, MAP_SIZE + 28))
	setHeader("🗺️", L("Schatzkarte"), if spot then L("Die Karte ist vollständig – grab den Schatz aus!") else L("Wächter-Geister verlieren manchmal ein Kartenteil."))
	local card = cardSurface("MapCard")
	local paper = new("Frame", {
		Name = "Paper",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(MAP_SIZE, MAP_SIZE),
		BackgroundColor3 = C(244, 228, 190),
		ClipsDescendants = true,
		Parent = card,
	}, { corner(18), stroke(C(170, 130, 80), 3) })
	mapDot(paper, Vector3.zero, 214 * 2 * MAP_SCALE, C(160, 210, 140), "Island")
	mapDot(paper, Vector3.new(0, 0, 140), 124 * MAP_SCALE, C(80, 150, 100), "Forest")
	mapDot(paper, Vector3.zero, 100 * MAP_SCALE, C(225, 215, 200), "Plaza")
	mapDot(paper, Vector3.zero, 9, C(170, 110, 240), "Crystal")
	mapDot(paper, Vector3.new(140, 0, 118), 14, C(90, 100, 170), "Ruins")
	for i = 1, Config.MaxPlots do
		local theta = math.rad(-78.75 + (i - 1) * 22.5)
		local plot = mapDot(paper, Vector3.new(math.sin(theta) * 120, 0, -math.cos(theta) * 120), 12, C(200, 175, 140), "Plot")
		plot:FindFirstChildOfClass("UICorner"):Destroy()
		if i == player:GetAttribute("PlotIndex") then
			plot.BackgroundColor3 = THEME.gold
		end
	end
	label(paper, { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(60, 20), Text = L("N ↑"), Font = TITLE, TextSize = 16, TextColor3 = C(130, 90, 50) })
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local me = mapDot(paper, root.Position, 12, C(60, 140, 255), "You")
		stroke(THEME.white, 2).Parent = me
	end
	if spot then
		-- Two crossed bars (the title font has no "✕" glyph).
		local mark = new("Frame", {
			Name = "X",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = mapPoint(spot.position),
			Size = UDim2.fromOffset(30, 30),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Parent = paper,
		})
		for _, angle in { 45, -45 } do
			new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(30, 7),
				Rotation = angle,
				BackgroundColor3 = C(220, 40, 40),
				ZIndex = 5,
				Parent = mark,
			}, { corner(3), stroke(THEME.white, 2) })
		end
	else
		-- Torn, unreadable map until all pieces are together.
		new("Frame", { Name = "Fog", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(244, 228, 190), BackgroundTransparency = 0.25, Parent = paper })
		label(paper, { Size = UDim2.fromScale(1, 1), Text = "?", Font = TITLE, TextSize = 90, TextColor3 = C(170, 130, 80) })
	end

	local dots = {}
	for i = 1, Config.Maps.piecesNeeded do
		table.insert(dots, if spot or i <= maps.pieces then "●" else "○")
	end
	local lines = {
		L("<b>Kartenteile:</b> %s", table.concat(dots, " ")),
		"",
		if spot then L("<b>Hinweis:</b> %s", L(spot.hint)) else L("Fang Wächter-Geister auf dem Platz und im Flüsterwald. Mit %d Teilen wird die Karte lesbar.", Config.Maps.piecesNeeded),
		"",
		if spot then L("Am Ziel erscheint ein Erdhügel mit rotem Kreuz – halte dort E (oder tippe), um zu graben.") else "",
		"",
		L("Gefundene Schätze: %d", maps.found),
	}
	label(card, {
		Name = "Info",
		Position = UDim2.fromOffset(MAP_SIZE + 34, 18),
		Size = UDim2.new(1, -(MAP_SIZE + 52), 1, -36),
		Text = table.concat(lines, "\n"),
		RichText = true,
		TextWrapped = true,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end

local function renderPanel()
	local mode = panelMode
	local state = ClientState.data
	if not mode or not state then
		return
	end
	lastSignature = signature(mode.kind, state)
	clearGrid()
	returnButton.Visible = false
	if mode.kind == "pedestal" then
		renderPedestal(state, mode.slot :: number)
	elseif mode.kind == "quests" then
		renderQuests(state)
	elseif mode.kind == "shop" then
		renderShop(state)
	elseif mode.kind == "settings" then
		renderSettings()
	elseif mode.kind == "credits" then
		renderCredits()
	elseif mode.kind == "map" then
		renderMap(state)
	else
		renderCollection(state)
	end
	panelInfo.Size = UDim2.new(1, if returnButton.Visible then -260 else -44, 0, 24)
end

local function open(kind: string, slot: number?)
	if panelMode and panelMode.kind == kind and kind ~= "pedestal" then
		Hud.close()
		return
	end
	local wasOpen = panelMode ~= nil
	panelMode = { kind = kind, slot = slot }
	panelHost.Visible = true
	-- The panel takes the screen: navigation and the guide step aside (small phones need the room).
	navFrame.Visible = false
	sideFrame.Visible = false
	refreshGuide()
	refreshExpedition()
	-- World prompts, chat and the player list would sit on top of the panel and steal taps.
	ProximityPromptService.Enabled = false
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat, false)
	grid.CanvasPosition = Vector2.zero
	renderPanel()
	if not wasOpen then
		Audio.play("whoosh")
		panelPop.Scale = 0.9
		TweenService:Create(panelPop, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	local events = { collection = "CollectionOpened", quests = "QuestsOpened", shop = "ShopOpened", map = "MapOpened" }
	if events[kind] then
		Net.event("Track"):FireServer(events[kind])
	end
end

function Hud.openCollection()
	open("collection")
end

function Hud.openPedestal(slot: number)
	open("pedestal", slot)
end

function Hud.openQuests()
	open("quests")
end

function Hud.openShop()
	open("shop")
end

function Hud.openMap()
	open("map")
end

function Hud.openSettings()
	open("settings")
end

function Hud.openCredits()
	open("credits")
end

function Hud.close()
	panelMode = nil
	panelHost.Visible = false
	navFrame.Visible = true
	sideFrame.Visible = true
	refreshGuide()
	refreshExpedition()
	ProximityPromptService.Enabled = true
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, true)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat, true)
end

-- Layout -------------------------------------------------------------------------------

local function buildCoins()
	local coins = scaled(new("Frame", {
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(0, 58),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.white,
		Parent = gui,
	}, {
		round(),
		stroke(THEME.goldDeep, 3),
		gradient(C(255, 253, 246), C(255, 240, 214)),
		new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 18) }),
		hlist(10),
	}))
	coinIcon(coins, 42, 1)
	coinLabel = label(coins, { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Text = "0", Font = TITLE, TextSize = 32, LayoutOrder = 2 })
	rateLabel = chip(coins, "+0/s", C(255, 232, 180), THEME.amberDeep, { Size = UDim2.fromOffset(0, 26), TextSize = 17, LayoutOrder = 3, Font = TITLE })
	luckLabel = chip(coins, "", C(205, 245, 215), C(30, 130, 80), { Size = UDim2.fromOffset(0, 26), TextSize = 17, LayoutOrder = 4, Font = TITLE, Visible = false })
end

-- Settings gear, a small round button under the side menu (the top corners belong to Roblox).
local function buildGear(parent: Instance)
	local holder = new("Frame", { Name = "GearSlot", Size = UDim2.fromOffset(96, 64), BackgroundTransparency = 1, LayoutOrder = 3, Parent = parent })
	local slot, button = shadowed("TextButton", {
		Name = "Gear",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(64, 64),
		Parent = holder,
	}, {
		Name = "Button",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = THEME.white,
	}, 30)
	gradient(C(190, 180, 215), C(120, 105, 160)).Parent = button
	stroke(THEME.white, 3, 0.15).Parent = button
	label(button, { Size = UDim2.fromScale(1, 1), Text = "⚙️", TextScaled = true, Font = TITLE })
	new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = button })
	button.Activated:Connect(Hud.openSettings)
	pressable(button, slot)
end

local function buildGuide()
	guideFrame = scaled(new("Frame", {
		Name = "Guide",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(0, 48),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.dark,
		BackgroundTransparency = 0.12,
		Visible = false,
		Parent = gui,
	}, {
		round(),
		stroke(THEME.lumi, 2, 0.55),
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		hlist(10),
	})) :: Frame
	new("Frame", { Size = UDim2.fromOffset(32, 32), BackgroundColor3 = THEME.white, LayoutOrder = 1, Parent = guideFrame }, {
		round(),
		gradient(C(220, 255, 255), THEME.lumi),
		stroke(THEME.white, 2, 0.4),
	})
	guideLabel = label(guideFrame, { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Text = "", TextColor3 = THEME.white, TextSize = 20, LayoutOrder = 2 })
	skipButton = new("TextButton", {
		Name = "Skip",
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C(255, 255, 255),
		BackgroundTransparency = 0.85,
		Text = L("Überspringen"),
		TextColor3 = C(225, 215, 245),
		Font = BODY,
		TextSize = 15,
		LayoutOrder = 3,
		Visible = false,
		Parent = guideFrame,
	}, { round(), hpad(12) })
	skipButton.Activated:Connect(function()
		pcall(function()
			Net.func("SkipTutorial"):InvokeServer()
		end)
	end)
end

local function buildExpedition()
	expFrame = scaled(new("Frame", {
		Name = "Expedition",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(0, 52),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C(40, 30, 80),
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = gui,
	}, {
		round(),
		stroke(C(200, 170, 255), 2, 0.4),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8) }),
		hlist(10),
	})) :: Frame
	expTimer = chip(expFrame, "", C(255, 228, 160), C(130, 70, 10), { Name = "Timer", Size = UDim2.fromOffset(0, 30), TextSize = 17, Font = TITLE, LayoutOrder = 1 })
	expLabel = label(expFrame, {
		Name = "Objective",
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		TextColor3 = THEME.white,
		TextSize = 19,
		LayoutOrder = 2,
	})
	expLeave = pillButton(expFrame, "Leave", L("Verlassen"), C(255, 160, 170), C(200, 70, 100), true, {
		Size = UDim2.fromOffset(120, 38),
		TextSize = 17,
		LayoutOrder = 3,
	}, function()
		pcall(function()
			Net.func("LeaveExpedition"):InvokeServer()
		end)
	end)
end

local function buildNavigation()
	local navLayout = hlist(14)
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local nav = scaled(new("Frame", {
		Name = "Nav",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(580, 74),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { navLayout }))
	navFrame = nav
	bigButton("NavCollection", "📖", L("Sammlung"), THEME.violet, THEME.violetDeep, Vector2.new(190, 70), 1, false, Hud.openCollection).Parent = nav
	bigButton("NavHome", "🏛️", L("Schatzkammer"), THEME.amber, THEME.amberDeep, Vector2.new(206, 70), 2, false, function()
		Hud.close()
		local ok, success = pcall(function()
			return Net.func("GoHome"):InvokeServer()
		end)
		if not (ok and success) then
			Hud.toast(L("Gerade nicht möglich – versuch es gleich nochmal."))
		end
	end).Parent = nav
	local map = bigButton("NavMap", "🗺️", L("Karte"), THEME.teal, THEME.tealDeep, Vector2.new(150, 70), 3, false, Hud.openMap)
	map.Parent = nav
	mapBadge = new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = C(255, 76, 92),
		Visible = false,
		ZIndex = 5,
		Parent = map,
	}, { round(), stroke(THEME.white, 2) })
	label(mapBadge, { Size = UDim2.fromScale(1, 1), Text = "!", Font = TITLE, TextSize = 18, TextColor3 = THEME.white, ZIndex = 5 })

	-- Side menu, left middle (above the mobile thumbstick area).
	local side = scaled(new("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(96, 288),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }) }))
	sideFrame = side
	local quests = bigButton("NavQuests", "📜", L("Aufgaben"), THEME.teal, THEME.tealDeep, Vector2.new(96, 96), 1, true, Hud.openQuests)
	quests.Parent = side
	bigButton("NavShop", "🛒", L("Shop"), THEME.pink, THEME.pinkDeep, Vector2.new(96, 96), 2, true, Hud.openShop).Parent = side
	buildGear(side)
	questBadge = new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = C(255, 76, 92),
		Visible = false,
		ZIndex = 5,
		Parent = quests,
	}, { round(), stroke(THEME.white, 2) })
	label(questBadge, { Size = UDim2.fromScale(1, 1), Text = "!", Font = TITLE, TextSize = 18, TextColor3 = THEME.white, ZIndex = 5 })
end

local function buildPanel()
	panelHost = scaled(new("Frame", {
		Name = "PanelHost",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -6),
		Size = UDim2.fromOffset(700, 470),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})) :: Frame
	panel = new("Frame", { Name = "RelicPanel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = panelHost })
	panelPop = new("UIScale", { Parent = panel })
	new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.shadow,
		BackgroundTransparency = 0.72,
		Parent = panel,
	}, { corner(30) })
	new("Frame", { Name = "Surface", Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.panel, Parent = panel }, {
		corner(30),
		stroke(THEME.edge, 3),
	})
	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 68), BackgroundColor3 = THEME.white, Parent = panel }, {
		corner(30),
		gradient(THEME.violet, THEME.violetDeep),
	})
	-- squares off the header's lower corners so it meets the body with a straight edge
	new("Frame", { Name = "Fill", Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = THEME.violetDeep, BorderSizePixel = 0, Parent = header })
	panelIcon = label(header, { Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(44, 44), Text = "", TextScaled = true, ZIndex = 2 })
	panelTitle = label(header, {
		Position = UDim2.fromOffset(72, 10),
		Size = UDim2.new(1, -150, 0, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Font = TITLE,
		TextSize = 32,
		TextColor3 = THEME.white,
		ZIndex = 2,
	})
	textStroke(THEME.violetDeep:Lerp(THEME.dark, 0.5), 1.5).Parent = panelTitle

	local closeButton = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, 34),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = THEME.white,
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		Text = "X",
		TextColor3 = THEME.violetDeep,
		Font = TITLE,
		TextSize = 26,
		ZIndex = 2,
		Parent = panel,
	}, { round() })
	closeButton.Activated:Connect(Hud.close)
	pressable(closeButton, closeButton)

	panelInfo = label(panel, {
		Position = UDim2.fromOffset(22, 78),
		Size = UDim2.new(1, -44, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		TextColor3 = THEME.subtle,
		TextSize = 18,
	})
	returnButton = pillButton(panel, "Return", L("Ins Inventar"), THEME.goldLight, THEME.amberDeep, true, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 74),
		Size = UDim2.fromOffset(200, 34),
		TextSize = 18,
		TextColor3 = C(110, 58, 8),
		Visible = false,
	}, function()
		local mode = panelMode
		if not mode or mode.kind ~= "pedestal" then
			return
		end
		local ok, success, err = pcall(function()
			return Net.func("Unplace"):InvokeServer(mode.slot)
		end)
		if ok and success then
			Audio.play("place", 0.85)
			Hud.toast(L("Zurück im Inventar."))
			Hud.close()
		else
			Hud.showError(err)
		end
	end)

	gridLayout = new("UIGridLayout", {
		CellSize = UDim2.fromOffset(140, 172),
		CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	grid = new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(16, 112),
		Size = UDim2.new(1, -32, 1, -124),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = THEME.violet,
		ScrollBarImageTransparency = 0.3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, { gridLayout, new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10) }) })
end

local function build()
	gui = new("ScreenGui", {
		Name = "RelicHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	buildCoins()
	buildGuide()
	buildExpedition()
	toastStack = scaled(new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.27, 0),
		Size = UDim2.fromOffset(640, 220),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})) :: Frame
	buildNavigation()
	buildPanel()
	gui.Parent = player:WaitForChild("PlayerGui")
end

function Hud.start()
	build()
	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	for _, attribute in { "Coins", "CoinRate", "LuckUntil" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshCoins)
	end
	for _, attribute in { "ExpObjective", "ExpRun", "ExpEnds" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			refreshExpedition()
			refreshGuide()
		end)
	end
	player.AttributeChanged:Connect(function(name)
		if name:sub(1, 5) == "Pass_" and panelMode and panelMode.kind == "shop" then
			renderPanel()
		end
	end)
	ClientState.Changed:Connect(function(state)
		refreshGuide()
		if panelMode and signature(panelMode.kind, state) ~= lastSignature then
			renderPanel()
		end
	end)
	Settings.Changed:Connect(function()
		if panelMode and panelMode.kind == "settings" then
			renderPanel()
		end
	end)
	Net.event("Notify").OnClientEvent:Connect(function(message: any)
		if type(message) == "table" and type(message.text) == "string" then
			local sound = NOTIFY_SOUNDS[message.kind]
			if sound then
				Audio.play(sound)
			end
			Hud.toast(message.text, NOTIFY_COLORS[message.kind])
			if message.kind == "reward" and type(message.relics) == "table" then
				local best = 0
				for _, relic in message.relics do
					local def = type(relic) == "table" and RelicDefs.byId[relic.id]
					if def then
						best = math.max(best, RelicVisuals.rarityRank(def.rarity))
						Hud.relicCollected(def, relic.new == true)
					end
				end
				if best > 0 then
					Audio.collect(best)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			refreshCoins()
			refreshExpedition()
		end
	end)
	refreshCoins()
	refreshGuide()
end

return Hud
