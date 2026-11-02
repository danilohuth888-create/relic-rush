--!strict
-- Builds and drives the HUD in code: coin counter, objective hint, bottom navigation, toasts
-- and the relic panel (collection view and pedestal picker). Sizes are touch-first and the
-- whole HUD scales with the viewport so it stays readable on small phones.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
	dark = Color3.fromRGB(40, 26, 66),
	white = Color3.new(1, 1, 1),
}
local TITLE = Enum.Font.FredokaOne
local BODY = Enum.Font.BuilderSansBold

local ERRORS: { [string]: string } = {
	too_far = "Geh etwas näher heran.",
	not_owned = "Dieses Relikt hast du gerade nicht im Inventar.",
	locked_slot = "Dieses Podest ist noch gesperrt.",
	rate = "Nicht so schnell!",
	gone = "Dieses Relikt ist schon eingesammelt.",
	no_plot = "Du hast noch keine Schatzkammer.",
	not_loaded = "Deine Daten werden noch geladen …",
}

local Hud = {}

local gui: ScreenGui
local scales: { UIScale } = {}
local coinLabel: TextLabel
local rateLabel: TextLabel
local objective: TextLabel
local toastStack: Frame
local panel: Frame
local panelTitle: TextLabel
local panelInfo: TextLabel
local returnButton: TextButton
local grid: ScrollingFrame
local panelMode: { kind: string, slot: number? }? = nil

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

local function padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return new("UIPadding", { PaddingLeft = u, PaddingRight = u, PaddingTop = u, PaddingBottom = u })
end

local function scaled(frame: GuiObject): GuiObject
	local scale = new("UIScale", { Parent = frame })
	table.insert(scales, scale)
	return frame
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
	local label = new("TextLabel", {
		Size = UDim2.fromOffset(0, 46),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.dark,
		BackgroundTransparency = 0.1,
		Text = text,
		TextColor3 = color or THEME.white,
		Font = TITLE,
		TextSize = 24,
		Parent = toastStack,
	}, { corner(23), new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }) })
	local children = toastStack:GetChildren()
	local labels = 0
	for _, c in children do
		if c:IsA("TextLabel") then
			labels += 1
		end
	end
	if labels > 3 then
		for _, c in children do
			if c:IsA("TextLabel") and c ~= label then
				c:Destroy()
				break
			end
		end
	end
	task.delay(2.4, function()
		if label.Parent then
			local fade = TweenInfo.new(0.4)
			TweenService:Create(label, fade, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.wait(0.4)
			label:Destroy()
		end
	end)
end

function Hud.showError(code: any)
	Hud.toast(ERRORS[tostring(code)] or "Das hat nicht geklappt.", Color3.fromRGB(255, 200, 200))
end

function Hud.relicCollected(def: RelicDefs.RelicDef)
	local rarity = Config.Rarities[def.rarity]
	Hud.toast(("%s gefunden! (%s)"):format(def.name, rarity.name), rarity.color)
end

local function objectiveText(): string?
	local s = ClientState.data
	if not s then
		return "Deine Schatzkammer wird vorbereitet …"
	end
	local displayed, held = 0, 0
	for _ in s.display do
		displayed += 1
	end
	for _, count in s.inventory do
		held += count
	end
	local capacity = Config.Tiers[s.tier].pedestals
	if s.collected == 0 then
		return "Sammle das leuchtende Relikt vor dir ein!"
	elseif displayed == 0 then
		return "Tippe auf »Schatzkammer« und stelle dein Relikt auf ein Podest."
	elseif held > 0 and displayed < capacity then
		return "Stelle weitere Relikte aus – jedes erzeugt Münzen."
	elseif displayed < capacity then
		return "Erkunde Aetheria und finde weitere Relikte!"
	end
	return "Alle Podeste belegt! Tausche gegen seltenere Relikte."
end

local function refreshHud()
	coinLabel.Text = formatNumber(player:GetAttribute("Coins") :: number? or 0)
	rateLabel.Text = "+" .. formatRate(player:GetAttribute("CoinRate") :: number? or 0) .. "/s"
	local text = objectiveText()
	objective.Visible = text ~= nil
	objective.Text = text or ""
end

local function viewport(def: RelicDefs.RelicDef): ViewportFrame
	local frame = new("ViewportFrame", {
		Size = UDim2.new(1, 0, 0, 88),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 180, 210),
		LightColor = THEME.white,
		LightDirection = Vector3.new(-1, -1, -0.6),
	})
	local model = RelicVisuals.build(def)
	model:PivotTo(CFrame.Angles(0, math.rad(-25), 0))
	model.Parent = frame
	local camera = new("Camera", { FieldOfView = 38, CFrame = CFrame.lookAt(Vector3.new(0, 1, 4.6), Vector3.zero), Parent = frame })
	frame.CurrentCamera = camera
	return frame
end

local function card(def: RelicDefs.RelicDef, count: number, onPick: (() -> ())?)
	local rarity = Config.Rarities[def.rarity]
	local button = new("TextButton", {
		Name = "Card_" .. def.id,
		Text = "",
		AutoButtonColor = onPick ~= nil,
		BackgroundColor3 = THEME.white,
		Parent = grid,
	}, { corner(16), stroke(rarity.color, 3) })
	viewport(def).Parent = button
	new("TextLabel", {
		Position = UDim2.fromOffset(6, 88),
		Size = UDim2.new(1, -12, 0, 26),
		BackgroundTransparency = 1,
		Text = def.name,
		TextColor3 = THEME.text,
		Font = TITLE,
		TextScaled = true,
		Parent = button,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(6, 114),
		Size = UDim2.new(1, -12, 0, 20),
		BackgroundTransparency = 1,
		Text = ("x%d  ·  +%s/s"):format(count, formatRate(def.rate)),
		TextColor3 = THEME.subtle,
		Font = BODY,
		TextSize = 17,
		Parent = button,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(6, 134),
		Size = UDim2.new(1, -12, 0, 18),
		BackgroundTransparency = 1,
		Text = rarity.name,
		TextColor3 = rarity.color:Lerp(THEME.text, 0.35),
		Font = BODY,
		TextSize = 15,
		Parent = button,
	})
	if onPick then
		button.Activated:Connect(onPick)
	end
end

local function sortedInventory(inventory: { [string]: number }): { { def: RelicDefs.RelicDef, count: number } }
	local rows = {}
	for id, count in inventory do
		local def = RelicDefs.byId[id]
		if def and count > 0 then
			table.insert(rows, { def = def, count = count })
		end
	end
	table.sort(rows, function(a, b)
		local ra, rb = RelicVisuals.rarityRank(a.def.rarity), RelicVisuals.rarityRank(b.def.rarity)
		if ra ~= rb then
			return ra > rb
		end
		return a.def.name < b.def.name
	end)
	return rows
end

local function renderPanel()
	local mode = panelMode
	local state = ClientState.data
	if not mode or not state then
		return
	end
	for _, c in grid:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local rows = sortedInventory(state.inventory)
	returnButton.Visible = false

	if mode.kind == "pedestal" then
		local slot = mode.slot :: number
		local occupant = state.display[tostring(slot)]
		local def = occupant and RelicDefs.byId[occupant]
		panelTitle.Text = "Podest " .. slot
		panelInfo.Text = if def then ("Ausgestellt: %s (+%s/s). Wähle ein Relikt zum Tauschen."):format(def.name, formatRate(def.rate))
			else "Wähle ein Relikt zum Ausstellen."
		returnButton.Visible = def ~= nil
		for _, row in rows do
			card(row.def, row.count, function()
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
	else
		local displayed = 0
		for _ in state.display do
			displayed += 1
		end
		panelTitle.Text = "Sammlung"
		local discovered: { [string]: boolean } = {}
		for id in state.inventory do
			discovered[id] = true
		end
		for _, id in state.display do
			discovered[id] = true
		end
		local count = 0
		for _ in discovered do
			count += 1
		end
		panelInfo.Text = ("%d ausgestellt · %d von %d Relikten entdeckt"):format(displayed, count, #RelicDefs.list)
		for _, row in rows do
			card(row.def, row.count, nil)
		end
	end

	if #rows == 0 then
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundTransparency = 1,
			Text = "Noch keine Relikte im Inventar. Halte Ausschau nach leuchtenden Lichtsäulen!",
			TextWrapped = true,
			TextColor3 = THEME.subtle,
			Font = BODY,
			TextSize = 20,
			Parent = grid,
		})
	end
end

function Hud.openCollection()
	panelMode = { kind = "collection" }
	panel.Visible = true
	renderPanel()
end

function Hud.openPedestal(slot: number)
	panelMode = { kind = "pedestal", slot = slot }
	panel.Visible = true
	renderPanel()
end

function Hud.close()
	panelMode = nil
	panel.Visible = false
end

local function navButton(name: string, text: string, color: Color3, order: number, onClick: () -> ()): TextButton
	local button = new("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(170, 72),
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
	coinLabel = new("TextLabel", {
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "0",
		TextColor3 = THEME.text,
		Font = TITLE,
		TextSize = 32,
		LayoutOrder = 2,
		Parent = coins,
	})
	rateLabel = new("TextLabel", {
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "+0/s",
		TextColor3 = THEME.subtle,
		Font = BODY,
		TextSize = 20,
		LayoutOrder = 3,
		Parent = coins,
	})

	objective = scaled(new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(0, 42),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.dark,
		BackgroundTransparency = 0.2,
		TextColor3 = THEME.white,
		Font = BODY,
		TextSize = 21,
		Text = "",
		Parent = gui,
	}, { corner(21), new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }) })) :: TextLabel

	toastStack = scaled(new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.26, 0),
		Size = UDim2.fromOffset(600, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
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
		navButton("NavCollection", "Sammlung", THEME.violet, 1, function()
			if panelMode and panelMode.kind == "collection" then
				Hud.close()
			else
				Hud.openCollection()
			end
		end),
		navButton("NavHome", "Schatzkammer", Color3.fromRGB(230, 160, 40), 2, function()
			Hud.close()
			local ok, success = pcall(function()
				return Net.func("GoHome"):InvokeServer()
			end)
			if not (ok and success) then
				Hud.toast("Gerade nicht möglich – versuch es gleich nochmal.")
			end
		end),
	}))

	panel = scaled(new("Frame", {
		Name = "RelicPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -10),
		Size = UDim2.fromOffset(660, 430),
		BackgroundColor3 = THEME.panel,
		Visible = false,
		Parent = gui,
	}, { corner(26), stroke(THEME.edge, 4) })) :: Frame
	panelTitle = new("TextLabel", {
		Position = UDim2.fromOffset(22, 12),
		Size = UDim2.new(1, -100, 0, 40),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		TextColor3 = THEME.text,
		Font = TITLE,
		TextSize = 32,
		Parent = panel,
	})
	panelInfo = new("TextLabel", {
		Position = UDim2.fromOffset(22, 52),
		Size = UDim2.new(1, -44, 0, 24),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		TextColor3 = THEME.subtle,
		Font = BODY,
		TextSize = 19,
		Parent = panel,
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
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(140, 158),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		padding(4),
	})

	gui.Parent = player:WaitForChild("PlayerGui")
end

function Hud.start()
	build()
	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	player:GetAttributeChangedSignal("Coins"):Connect(refreshHud)
	player:GetAttributeChangedSignal("CoinRate"):Connect(refreshHud)
	ClientState.Changed:Connect(function()
		refreshHud()
		if panelMode then
			renderPanel()
		end
	end)
	refreshHud()
end

return Hud
