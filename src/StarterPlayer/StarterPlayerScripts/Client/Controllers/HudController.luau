--!strict
-- Builds and drives the HUD in code: coin counter, guide banner (Lumi), navigation, toasts
-- and one shared panel for the collection book, pedestal picker, daily quests and shop.
-- Sizes are touch-first and the HUD scales with the viewport so it stays readable on phones.

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

local THEME = {
	panel = Color3.fromRGB(255, 249, 238),
	edge = Color3.fromRGB(214, 190, 255),
	text = Color3.fromRGB(52, 36, 82),
	subtle = Color3.fromRGB(120, 100, 150),
	violet = Color3.fromRGB(140, 80, 230),
	gold = Color3.fromRGB(255, 190, 70),
	amber = Color3.fromRGB(230, 160, 40),
	teal = Color3.fromRGB(60, 190, 200),
	dark = Color3.fromRGB(40, 26, 66),
	locked = Color3.fromRGB(220, 214, 230),
	white = Color3.new(1, 1, 1),
}
local TITLE = Enum.Font.FredokaOne
local BODY = Enum.Font.BuilderSansBold

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
	milestone = Color3.fromRGB(150, 230, 255),
	purchase = THEME.gold,
	visit = Color3.fromRGB(255, 200, 230),
	offline = THEME.gold,
}

local Hud = {}

local gui: ScreenGui
local scales: { UIScale } = {}
local coinLabel: TextLabel
local rateLabel: TextLabel
local luckLabel: TextLabel
local guideFrame: Frame
local guideLabel: TextLabel
local skipButton: TextButton
local questBadge: Frame
local toastStack: Frame
local panel: Frame
local panelTitle: TextLabel
local panelInfo: TextLabel
local returnButton: TextButton
local grid: ScrollingFrame
local gridLayout: UIGridLayout
local panelMode: { kind: string, slot: number? }? = nil
local guideText: string? = nil
local guideIsTutorial = false
local priceCache: { [string]: string } = {}

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

local function stroke(color: Color3, thickness: number): UIStroke
	return new("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function hpad(px: number): UIPadding
	return new("UIPadding", { PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px) })
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

function Hud.toast(text: string, color: Color3?)
	local toast = new("TextLabel", {
		Size = UDim2.fromOffset(0, 46),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.dark,
		BackgroundTransparency = 0.1,
		Text = text,
		TextColor3 = color or THEME.white,
		Font = TITLE,
		TextSize = 24,
		Parent = toastStack,
	}, { corner(23), hpad(18) })
	local toasts = {}
	for _, c in toastStack:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(toasts, c)
		end
	end
	if #toasts > 3 then
		toasts[1]:Destroy()
	end
	task.delay(2.6, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

function Hud.showError(code: any)
	Hud.toast(ERRORS[tostring(code)] or "Das hat nicht geklappt.", Color3.fromRGB(255, 200, 200))
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
	guideFrame.Visible = text ~= nil
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
		luckLabel.Text = ("Glück %d:%02d"):format(left // 60, left % 60)
	end
end

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
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 80),
		BackgroundColor3 = Config.Rarities[def.rarity].color:Lerp(THEME.dark, 0.55),
		Ambient = Color3.fromRGB(190, 180, 210),
		LightColor = THEME.white,
		LightDirection = Vector3.new(-1, -1, -0.6),
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = frame })
	local model = RelicVisuals.build(def)
	model:PivotTo(CFrame.Angles(0, math.rad(-25), 0))
	model.Parent = frame
	frame.CurrentCamera = new("Camera", { FieldOfView = 38, CFrame = CFrame.lookAt(Vector3.new(0, 1, 4.6), Vector3.zero), Parent = frame })
end

local function relicCard(def: RelicDefs.RelicDef, line: string, onPick: (() -> ())?)
	local rarity = Config.Rarities[def.rarity]
	local card = new("Frame", { Name = "Card_" .. def.id, BackgroundColor3 = THEME.white, Parent = grid }, { corner(16), stroke(rarity.color, 3) })
	viewport(def, card)
	label(card, { Position = UDim2.fromOffset(6, 88), Size = UDim2.new(1, -12, 0, 26), Text = def.name, Font = TITLE, TextScaled = true })
	label(card, { Position = UDim2.fromOffset(6, 114), Size = UDim2.new(1, -12, 0, 20), Text = line, TextColor3 = THEME.subtle, TextSize = 16 })
	label(card, { Position = UDim2.fromOffset(6, 134), Size = UDim2.new(1, -12, 0, 18), Text = rarity.name, TextColor3 = rarity.color:Lerp(THEME.text, 0.35), TextSize = 15 })
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
	end
end

local function lockedCard(def: RelicDefs.RelicDef)
	local rarity = Config.Rarities[def.rarity]
	local card = new("Frame", { Name = "Locked_" .. def.id, BackgroundColor3 = THEME.locked, Parent = grid }, { corner(16), stroke(rarity.color, 2) })
	label(card, { Size = UDim2.new(1, 0, 0, 88), Text = "?", Font = TITLE, TextSize = 56, TextColor3 = THEME.subtle })
	label(card, { Position = UDim2.fromOffset(6, 92), Size = UDim2.new(1, -12, 0, 26), Text = "???", Font = TITLE, TextSize = 22, TextColor3 = THEME.subtle })
	label(card, { Position = UDim2.fromOffset(6, 128), Size = UDim2.new(1, -12, 0, 18), Text = rarity.name, TextColor3 = rarity.color:Lerp(THEME.text, 0.35), TextSize = 15 })
end

local function actionButton(parent: Instance, text: string, color: Color3, enabled: boolean, onClick: () -> ()): TextButton
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(150, 48),
		BackgroundColor3 = if enabled then color else THEME.locked,
		AutoButtonColor = enabled,
		Text = text,
		TextColor3 = if enabled then THEME.white else THEME.subtle,
		Font = TITLE,
		TextSize = 20,
		Parent = parent,
	}, { corner(24) })
	if enabled then
		button.Activated:Connect(onClick)
	end
	return button
end

local function setCells(size: UDim2)
	gridLayout.CellSize = size
end

local function renderCollection(state: any)
	setCells(UDim2.fromOffset(140, 158))
	local displayedCount: { [string]: number } = {}
	for _, id in state.display do
		displayedCount[id] = (displayedCount[id] or 0) + 1
	end
	local discovered = count(state.discovered or {})
	local nextMilestone = Config.Milestones[(state.milestones or 0) + 1]
	panelTitle.Text = "Sammelbuch"
	panelInfo.Text = if nextMilestone
		then ("%d von %d entdeckt · bei %d gibt es +%s Münzen"):format(discovered, #RelicDefs.list, nextMilestone.count, formatNumber(nextMilestone.reward))
		else ("Alle %d Relikte entdeckt!"):format(#RelicDefs.list)
	for _, def in RelicDefs.list do
		if state.discovered and state.discovered[def.id] then
			local held = state.inventory[def.id] or 0
			local shown = displayedCount[def.id] or 0
			relicCard(def, ("x%d · %d ausgestellt"):format(held, shown), nil)
		else
			lockedCard(def)
		end
	end
end

local function renderPedestal(state: any, slot: number)
	setCells(UDim2.fromOffset(140, 158))
	local occupant = state.display[tostring(slot)]
	local def = occupant and RelicDefs.byId[occupant]
	panelTitle.Text = "Podest " .. slot
	panelInfo.Text = if def then ("Ausgestellt: %s (+%s/s). Wähle ein Relikt zum Tauschen."):format(def.name, formatRate(def.rate))
		else "Wähle ein Relikt zum Ausstellen."
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
		relicCard(row.def, ("x%d · +%s/s"):format(row.count, formatRate(row.def.rate)), function()
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
		label(grid, {
			Text = "Keine Relikte im Inventar. Halte Ausschau nach leuchtenden Lichtsäulen!",
			TextWrapped = true,
			TextColor3 = THEME.subtle,
			TextSize = 20,
		})
	end
end

local function renderQuests(state: any)
	setCells(UDim2.new(1, -8, 0, 84))
	panelTitle.Text = "Tägliche Aufgaben"
	panelInfo.Text = "Jeden Tag gibt es neue Aufgaben. Belohnung: " .. formatNumber(Config.Quests.rewardByTier[state.tier]) .. " Münzen"
	local defs = {}
	for _, quest in Config.Quests.pool do
		defs[quest.id] = quest
	end
	for index, quest in state.quests or {} do
		local def = defs[quest.id]
		local row = new("Frame", { Name = "Quest" .. index, BackgroundColor3 = THEME.white, Parent = grid }, { corner(16), stroke(THEME.edge, 2) })
		label(row, {
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -190, 0, 30),
			Text = if def then def.text:format(quest.goal) else quest.id,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = TITLE,
			TextSize = 22,
		})
		local fraction = math.clamp(quest.progress / quest.goal, 0, 1)
		local bar = new("Frame", { Position = UDim2.fromOffset(14, 46), Size = UDim2.new(1, -190, 0, 14), BackgroundColor3 = THEME.locked, Parent = row }, { corner(7) })
		new("Frame", { Size = UDim2.fromScale(fraction, 1), BackgroundColor3 = THEME.teal, Parent = bar }, { corner(7) })
		label(row, {
			Position = UDim2.fromOffset(14, 60),
			Size = UDim2.new(1, -190, 0, 20),
			Text = ("%s / %s"):format(formatNumber(quest.progress), formatNumber(quest.goal)),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.subtle,
			TextSize = 16,
		})
		local done = quest.progress >= quest.goal
		local button = actionButton(row, if quest.claimed then "Erledigt" elseif done then "Abholen" else "Läuft …", THEME.gold, done and not quest.claimed, function()
			local ok, success, err = pcall(function()
				return Net.func("ClaimQuest"):InvokeServer(index)
			end)
			if ok and success then
				Hud.toast("+" .. formatNumber(Config.Quests.rewardByTier[state.tier]) .. " Münzen!", THEME.gold)
			else
				Hud.showError(err)
			end
		end)
		button.Name = "Claim"
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
			priceCache[key] = ("%d Robux"):format(info.PriceInRobux)
			if target.Parent then
				target.Text = priceCache[key]
			end
		end
	end)
end

local function shopCard(name: string, title: string, text: string, price: string, buttonText: string, enabled: boolean, onClick: () -> ()): TextLabel
	local card = new("Frame", { Name = name, BackgroundColor3 = THEME.white, Parent = grid }, { corner(16), stroke(THEME.edge, 2) })
	label(card, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 30), Text = title, Font = TITLE, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left })
	label(card, {
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 60),
		Text = text,
		TextWrapped = true,
		TextColor3 = THEME.subtle,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local priceLabel = label(card, { Position = UDim2.fromOffset(12, 104), Size = UDim2.new(1, -24, 0, 22), Text = price, TextColor3 = THEME.amber, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left })
	local button = new("TextButton", {
		Name = "Buy",
		Position = UDim2.new(0, 12, 1, -56),
		Size = UDim2.new(1, -24, 0, 46),
		BackgroundColor3 = if enabled then THEME.violet else THEME.locked,
		AutoButtonColor = enabled,
		Text = buttonText,
		TextColor3 = if enabled then THEME.white else THEME.subtle,
		Font = TITLE,
		TextSize = 20,
		Parent = card,
	}, { corner(23) })
	if enabled then
		button.Activated:Connect(onClick)
	end
	return priceLabel
end

local function renderShop(state: any)
	setCells(UDim2.fromOffset(196, 196))
	panelTitle.Text = "Shop"
	panelInfo.Text = "Alles optional – Aetheria ist komplett ohne Käufe spielbar."
	local luckCost = Config.LuckRune.costByTier[state.tier]
	local luck = player:GetAttribute("LuckUntil")
	local luckActive = type(luck) == "number" and luck > os.time()
	shopCard(
		"Item_luck",
		"Glücksrune",
		("%d Minuten doppelte Chance auf seltene Relikte."):format(Config.LuckRune.seconds // 60),
		formatNumber(luckCost) .. " Münzen",
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
		local priceLabel = shopCard("Item_" .. pass.key, pass.name, pass.text, if live then "…" else "Bald verfügbar", if owned then "Besitzt du" elseif live then "Kaufen" else "Bald", live and not owned, function()
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end)
		if live then
			fetchPrice(pass.key, pass.id, true, priceLabel)
		end
	end
	for _, product in Config.Shop.products do
		local live = product.id ~= 0
		local text = ("%s +%s Münzen."):format(product.text, formatNumber(product.coinsByTier[state.tier]))
		local priceLabel = shopCard("Item_" .. product.key, product.name, text, if live then "…" else "Bald verfügbar", if live then "Kaufen" else "Bald", live, function()
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
end

local function open(kind: string, slot: number?)
	if panelMode and panelMode.kind == kind and kind ~= "pedestal" then
		Hud.close()
		return
	end
	panelMode = { kind = kind, slot = slot }
	panel.Visible = true
	-- World prompts, chat and the player list would sit on top of the panel and steal taps.
	ProximityPromptService.Enabled = false
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat, false)
	grid.CanvasPosition = Vector2.zero
	renderPanel()
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
	panel.Visible = false
	ProximityPromptService.Enabled = true
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, true)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat, true)
end

local function navButton(name: string, text: string, color: Color3, size: Vector2, order: number, onClick: () -> ()): TextButton
	local button = new("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(size.X, size.Y),
		LayoutOrder = order,
		BackgroundColor3 = color,
		Text = text,
		TextColor3 = THEME.white,
		Font = TITLE,
		TextSize = 26,
	}, { corner(22), stroke(THEME.white, 3) })
	button.Activated:Connect(onClick)
	return button
end

local function build()
	gui = new("ScreenGui", {
		Name = "RelicHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- Coin counter, top centre (clear of the Roblox menu buttons in the top-left corner).
	local coins = scaled(new("Frame", {
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(0, 56),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.panel,
		Parent = gui,
	}, {
		corner(28),
		stroke(THEME.gold, 3),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 18) }),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		new("Frame", { Size = UDim2.fromOffset(38, 38), BackgroundColor3 = THEME.gold, LayoutOrder = 1 }, {
			corner(19),
			stroke(Color3.fromRGB(220, 150, 40), 3),
		}),
	}))
	coinLabel = label(coins, { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Text = "0", Font = TITLE, TextSize = 32, LayoutOrder = 2 })
	rateLabel = label(coins, { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Text = "+0/s", TextColor3 = THEME.subtle, TextSize = 20, LayoutOrder = 3 })
	luckLabel = label(coins, { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Text = "", TextColor3 = THEME.amber, TextSize = 20, LayoutOrder = 4, Visible = false })

	-- Guide banner: Lumi's tutorial line or a quest hint.
	guideFrame = scaled(new("Frame", {
		Name = "Guide",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(0, 46),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.dark,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, {
		corner(23),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		new("Frame", { Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Color3.fromRGB(110, 235, 240), LayoutOrder = 1 }, { corner(13) }),
	})) :: Frame
	guideLabel = label(guideFrame, { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Text = "", TextColor3 = THEME.white, TextSize = 21, LayoutOrder = 2 })
	skipButton = new("TextButton", {
		Name = "Skip",
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(90, 70, 130),
		Text = "Überspringen",
		TextColor3 = Color3.fromRGB(220, 210, 240),
		Font = BODY,
		TextSize = 16,
		LayoutOrder = 3,
		Visible = false,
		Parent = guideFrame,
	}, { corner(17), hpad(12) })
	skipButton.Activated:Connect(function()
		pcall(function()
			Net.func("SkipTutorial"):InvokeServer()
		end)
	end)

	toastStack = scaled(new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.27, 0),
		Size = UDim2.fromOffset(600, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})) :: Frame

	-- Bottom navigation, centred between the mobile thumbstick and jump button.
	scaled(new("Frame", {
		Name = "Nav",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(360, 72),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		navButton("NavCollection", "Sammlung", THEME.violet, Vector2.new(170, 72), 1, Hud.openCollection),
		navButton("NavHome", "Schatzkammer", THEME.amber, Vector2.new(170, 72), 2, function()
			Hud.close()
			local ok, success = pcall(function()
				return Net.func("GoHome"):InvokeServer()
			end)
			if not (ok and success) then
				Hud.toast("Gerade nicht möglich – versuch es gleich nochmal.")
			end
		end),
	}))

	-- Side menu, left middle (above the mobile thumbstick area).
	local side = scaled(new("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(130, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		navButton("NavQuests", "Aufgaben", THEME.teal, Vector2.new(130, 64), 1, Hud.openQuests),
		navButton("NavShop", "Shop", Color3.fromRGB(230, 110, 160), Vector2.new(130, 64), 2, Hud.openShop),
	}))
	questBadge = new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Color3.fromRGB(255, 80, 90),
		Visible = false,
		Parent = side:FindFirstChild("NavQuests"),
	}, { corner(11), stroke(THEME.white, 2) })

	panel = scaled(new("Frame", {
		Name = "RelicPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -10),
		Size = UDim2.fromOffset(680, 440),
		BackgroundColor3 = THEME.panel,
		Visible = false,
		Parent = gui,
	}, { corner(26), stroke(THEME.edge, 4) })) :: Frame
	panelTitle = label(panel, {
		Position = UDim2.fromOffset(22, 12),
		Size = UDim2.new(1, -300, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Font = TITLE,
		TextSize = 32,
	})
	panelInfo = label(panel, {
		Position = UDim2.fromOffset(22, 52),
		Size = UDim2.new(1, -44, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		TextColor3 = THEME.subtle,
		TextSize = 19,
	})
	local closeButton = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = THEME.violet,
		Text = "X",
		TextColor3 = THEME.white,
		Font = TITLE,
		TextSize = 28,
		Parent = panel,
	}, { corner(26) })
	closeButton.Activated:Connect(Hud.close)
	returnButton = new("TextButton", {
		Name = "Return",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -74, 0, 12),
		Size = UDim2.fromOffset(200, 52),
		BackgroundColor3 = THEME.gold,
		Text = "Ins Inventar",
		TextColor3 = THEME.dark,
		Font = TITLE,
		TextSize = 22,
		Visible = false,
		Parent = panel,
	}, { corner(26) })
	returnButton.Activated:Connect(function()
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
		CellSize = UDim2.fromOffset(140, 158),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	grid = new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(16, 86),
		Size = UDim2.new(1, -32, 1, -100),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = THEME.edge,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, { gridLayout, new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }) })

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
