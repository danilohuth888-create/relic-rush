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
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local RelicVisuals = require(ReplicatedStorage.Shared.RelicVisuals)
local ClientState = require(script.Parent.Parent.ClientState)

local player = Players.LocalPlayer

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
	locked_slot = "Dieses Podest ist noch gesperrt – baue deine Schatzkammer aus.",
	rate = "Nicht so schnell!",
	gone = "Dieses Relikt ist schon eingesammelt.",
	no_plot = "Du hast noch keine Schatzkammer.",
	not_loaded = "Deine Daten werden noch geladen …",
	no_coins = "Dafür fehlen dir noch Münzen.",
	max_tier = "Deine Schatzkammer ist schon voll ausgebaut.",
	luck_active = "Deine Glücksrune wirkt noch.",
	not_done = "Diese Aufgabe ist noch nicht erledigt.",
	claimed = "Diese Belohnung hast du schon abgeholt.",
}
local NOTIFY_COLORS: { [string]: Color3 } = {
	upgrade = THEME.gold,
	milestone = C(150, 230, 255),
	purchase = THEME.gold,
	visit = C(255, 200, 230),
	offline = THEME.gold,
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
local guideFrame: Frame
local guideLabel: TextLabel
local skipButton: TextButton
local questBadge: Frame
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
	local digits = tostring(math.floor(n))
	local out = digits:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then
		out = out:sub(2)
	end
	return out
end

local function formatRate(rate: number): string
	return (("%g"):format(math.floor(rate * 10 + 0.5) / 10):gsub("%.", ","))
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
	Hud.toast(ERRORS[tostring(code)] or "Das hat nicht geklappt.", C(255, 200, 200))
end

function Hud.relicCollected(def: RelicDefs.RelicDef, isNew: boolean?)
	local rarity = Config.Rarities[def.rarity]
	local text = ("%s gefunden! (%s)"):format(def.name, rarity.name)
	Hud.toast(if isNew then "Neu im Sammelbuch: " .. text else text, rarity.color)
end

local function claimableQuests(state: any): number
	local n = 0
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
		text = "Eine Aufgabe ist erledigt – hol dir deine Belohnung ab!"
	end
	guideFrame.Visible = text ~= nil and panelMode == nil
	guideLabel.Text = text or ""
	skipButton.Visible = guideIsTutorial and guideText ~= nil
	questBadge.Visible = state ~= nil and claimableQuests(state) > 0
end

-- Lumi sets the tutorial line here; nil hides it (quest hints may still show).
function Hud.setGuide(text: string?, isTutorial: boolean)
	if text == guideText and isTutorial == guideIsTutorial then
		return
	end
	guideText, guideIsTutorial = text, isTutorial
	refreshGuide()
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
	local parts = { kind, tostring(state.tier) }
	if kind == "quests" then
		for _, quest in state.quests or {} do
			table.insert(parts, ("%s:%d:%s"):format(quest.id, math.floor(quest.progress), tostring(quest.claimed)))
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
	label(card, { Position = UDim2.fromOffset(8, 102), Size = UDim2.new(1, -16, 0, 24), Text = def.name, Font = TITLE, TextScaled = true })
	label(card, { Position = UDim2.fromOffset(8, 126), Size = UDim2.new(1, -16, 0, 18), Text = line, TextColor3 = THEME.subtle, TextSize = 15 })
	local badge = chip(card, rarity.name, rarity.color:Lerp(THEME.white, 0.55), rarity.color:Lerp(THEME.dark, 0.55), {
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
	label(card, { Position = UDim2.fromOffset(8, 126), Size = UDim2.new(1, -16, 0, 18), Text = "Noch nicht entdeckt", TextColor3 = THEME.subtle, TextSize = 14 })
	chip(card, rarity.name, rarity.color:Lerp(THEME.white, 0.6), rarity.color:Lerp(THEME.dark, 0.5), {
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
	setHeader("📖", "Sammelbuch", if nextMilestone
		then ("%d von %d entdeckt · bei %d gibt es +%s Münzen"):format(discovered, #RelicDefs.list, nextMilestone.count, formatNumber(nextMilestone.reward))
		else ("Alle %d Relikte entdeckt!"):format(#RelicDefs.list))
	for _, def in RelicDefs.list do
		if state.discovered and state.discovered[def.id] then
			local shown = displayedCount[def.id] or 0
			relicCard(def, state.inventory[def.id] or 0, if shown > 0 then ("%d ausgestellt"):format(shown) else ("+%s/s"):format(formatRate(def.rate)), nil)
		else
			lockedCard(def)
		end
	end
end

local function renderPedestal(state: any, slot: number)
	setCells(UDim2.fromOffset(140, 172))
	local occupant = state.display[tostring(slot)]
	local def = occupant and RelicDefs.byId[occupant]
	setHeader("🏛️", "Podest " .. slot, if def then ("Ausgestellt: %s (+%s/s) – wähle ein Relikt zum Tauschen."):format(def.name, formatRate(def.rate))
		else "Wähle ein Relikt zum Ausstellen.")
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
				Hud.toast(("%s ausgestellt! +%s/s"):format(row.def.name, formatRate(row.def.rate)), THEME.gold)
				Hud.close()
			else
				Hud.showError(err)
			end
		end)
	end
	if #rows == 0 then
		emptyNote("Keine Relikte im Inventar. Halte Ausschau nach leuchtenden Lichtsäulen!")
	end
end

local function renderQuests(state: any)
	setCells(UDim2.new(1, -8, 0, 92))
	setHeader("📜", "Tägliche Aufgaben", "Jeden Tag gibt es neue Aufgaben. Belohnung: " .. formatNumber(Config.Quests.rewardByTier[state.tier]) .. " Münzen")
	local defs = {}
	for _, quest in Config.Quests.pool do
		defs[quest.id] = quest
	end
	local reward = formatNumber(Config.Quests.rewardByTier[state.tier])
	for index, quest in state.quests or {} do
		local def = defs[quest.id]
		local done = quest.progress >= quest.goal
		local row = cardSurface("Quest" .. index)
		if quest.claimed then
			row.BackgroundColor3 = C(246, 252, 248)
		end
		local icon = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(58, 58),
			BackgroundColor3 = THEME.white,
			Parent = row,
		}, { round(), gradient(THEME.teal:Lerp(THEME.white, 0.4), THEME.tealDeep) })
		label(icon, { Size = UDim2.fromScale(1, 1), Text = QUEST_ICONS[quest.id] or "⭐", TextScaled = true })
		new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = icon })

		label(row, {
			Position = UDim2.fromOffset(86, 12),
			Size = UDim2.new(1, -330, 0, 28),
			Text = if def then def.text:format(quest.goal) else quest.id,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Font = TITLE,
			TextSize = 21,
		})
		local fraction = math.clamp(quest.progress / quest.goal, 0, 1)
		local bar = new("Frame", { Position = UDim2.fromOffset(86, 48), Size = UDim2.new(1, -330, 0, 14), BackgroundColor3 = THEME.locked, Parent = row }, { round() })
		if fraction > 0 then
			new("Frame", { Size = UDim2.fromScale(fraction, 1), BackgroundColor3 = THEME.white, Parent = bar }, {
				round(),
				gradient(THEME.teal:Lerp(THEME.white, 0.25), THEME.tealDeep),
			})
		end
		label(row, {
			Position = UDim2.fromOffset(86, 64),
			Size = UDim2.new(1, -330, 0, 18),
			Text = ("%s / %s"):format(formatNumber(quest.progress), formatNumber(quest.goal)),
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
		label(rewardRow, { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Text = reward, Font = TITLE, TextSize = 18, TextColor3 = THEME.amberDeep, LayoutOrder = 2 })

		pillButton(row, "Claim", if quest.claimed then "✓ Erledigt" elseif done then "Abholen" else "Läuft …", THEME.goldLight, THEME.amberDeep, done and not quest.claimed, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(140, 48),
			TextColor3 = C(110, 58, 8),
		}, function()
			local ok, success, err = pcall(function()
				return Net.func("ClaimQuest"):InvokeServer(index)
			end)
			if ok and success then
				Hud.toast("+" .. reward .. " Münzen!", THEME.gold)
			else
				Hud.showError(err)
			end
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
	setHeader("🛒", "Shop", "Alles optional – Aetheria ist komplett ohne Käufe spielbar.")
	local luckCost = Config.LuckRune.costByTier[state.tier]
	local luck = player:GetAttribute("LuckUntil")
	local luckActive = type(luck) == "number" and luck > os.time()
	shopCard(
		"luck",
		"Glücksrune",
		("%d Minuten doppelte Chance auf seltene Relikte."):format(Config.LuckRune.seconds // 60),
		true,
		formatNumber(luckCost),
		if luckActive then "Wirkt gerade" else "Mit Münzen kaufen",
		not luckActive,
		function()
			local ok, success, err = pcall(function()
				return Net.func("BuyLuck"):InvokeServer()
			end)
			if ok and success then
				Hud.toast("Die Glücksrune leuchtet! Seltene Relikte erscheinen öfter.", THEME.gold)
				Hud.close()
			else
				Hud.showError(err)
			end
		end
	)
	for _, pass in Config.Shop.passes do
		local owned = player:GetAttribute("Pass_" .. pass.key) == true
		local live = pass.id ~= 0
		local priceLabel = shopCard(pass.key, pass.name, pass.text, false, if live then "…" else "Bald verfügbar", if owned then "✓ Besitzt du" elseif live then "Kaufen" else "Bald", live and not owned, function()
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end)
		if live then
			fetchPrice(pass.key, pass.id, true, priceLabel)
		end
	end
	for _, product in Config.Shop.products do
		local live = product.id ~= 0
		local text = ("%s +%s Münzen."):format(product.text, formatNumber(product.coinsByTier[state.tier]))
		local priceLabel = shopCard(product.key, product.name, text, false, if live then "…" else "Bald verfügbar", if live then "Kaufen" else "Bald", live, function()
			MarketplaceService:PromptProductPurchase(player, product.id)
		end)
		if live then
			fetchPrice(product.key, product.id, false, priceLabel)
		end
	end
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
	-- World prompts, chat and the player list would sit on top of the panel and steal taps.
	ProximityPromptService.Enabled = false
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat, false)
	grid.CanvasPosition = Vector2.zero
	renderPanel()
	if not wasOpen then
		panelPop.Scale = 0.9
		TweenService:Create(panelPop, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	local events = { collection = "CollectionOpened", quests = "QuestsOpened", shop = "ShopOpened" }
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

function Hud.close()
	panelMode = nil
	panelHost.Visible = false
	navFrame.Visible = true
	sideFrame.Visible = true
	refreshGuide()
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
		Text = "Überspringen",
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

local function buildNavigation()
	local navLayout = hlist(14)
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local nav = scaled(new("Frame", {
		Name = "Nav",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(410, 74),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { navLayout }))
	navFrame = nav
	bigButton("NavCollection", "📖", "Sammlung", THEME.violet, THEME.violetDeep, Vector2.new(190, 70), 1, false, Hud.openCollection).Parent = nav
	bigButton("NavHome", "🏛️", "Schatzkammer", THEME.amber, THEME.amberDeep, Vector2.new(206, 70), 2, false, function()
		Hud.close()
		local ok, success = pcall(function()
			return Net.func("GoHome"):InvokeServer()
		end)
		if not (ok and success) then
			Hud.toast("Gerade nicht möglich – versuch es gleich nochmal.")
		end
	end).Parent = nav

	-- Side menu, left middle (above the mobile thumbstick area).
	local side = scaled(new("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(96, 210),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }) }))
	sideFrame = side
	local quests = bigButton("NavQuests", "📜", "Aufgaben", THEME.teal, THEME.tealDeep, Vector2.new(96, 96), 1, true, Hud.openQuests)
	quests.Parent = side
	bigButton("NavShop", "🛒", "Shop", THEME.pink, THEME.pinkDeep, Vector2.new(96, 96), 2, true, Hud.openShop).Parent = side
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
	returnButton = pillButton(panel, "Return", "Ins Inventar", THEME.goldLight, THEME.amberDeep, true, {
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
			Hud.toast("Zurück im Inventar.")
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
	Net.event("Notify").OnClientEvent:Connect(function(message: any)
		if type(message) == "table" and type(message.text) == "string" then
			Hud.toast(message.text, NOTIFY_COLORS[message.kind])
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			refreshCoins()
		end
	end)
	refreshCoins()
	refreshGuide()
end

return Hud
