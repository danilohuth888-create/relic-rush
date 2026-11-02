--!strict
-- Robux shop: game passes (permanent cosmetics, double coins) and developer products (coins).
-- Ownership is checked on the server. ProcessReceipt is idempotent: each purchase id is
-- recorded in the profile, and PurchaseGranted is only returned once that grant is saved.
-- Items with id 0 in Config.Shop are not live yet and can never be prompted or granted.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Analytics = require(script.Parent.Parent.Util.Analytics)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)

local ShopService = {}

local passById: { [number]: any } = {}
local productById: { [number]: any } = {}
for _, pass in Config.Shop.passes do
	if pass.id ~= 0 then
		passById[pass.id] = pass
	end
end
for _, product in Config.Shop.products do
	if product.id ~= 0 then
		productById[product.id] = product
	end
end

local TRACKABLE = { ShopOpened = true, QuestsOpened = true, CollectionOpened = true }
local trackLimiter = RateLimiter.new(5, 0.5)

local function cosmeticPart(folder: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, anchor: BasePart): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = 0.25
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	return p
end

-- Rebuilds the visible cosmetics a player owns on their current character.
function ShopService.applyCosmetics(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("RelicCosmetics")
	if old then
		old:Destroy()
	end
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	if not torso then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "RelicCosmetics"

	if player:GetAttribute("Pass_wings") then
		local lavender = Color3.fromRGB(200, 160, 255)
		for _, side in { -1, 1 } do
			local base = torso.CFrame * CFrame.new(side * 1.1, 0.5, 0.6) * CFrame.Angles(0, math.rad(-side * 20), math.rad(side * 18))
			cosmeticPart(folder, "Wing", Vector3.new(2.4, 1.5, 0.12), base * CFrame.new(side * 0.6, 0.3, 0), lavender, torso)
			cosmeticPart(folder, "WingTip", Vector3.new(1.6, 0.9, 0.1), base * CFrame.new(side * 1.2, -0.6, 0.05) * CFrame.Angles(0, 0, math.rad(side * -25)), Color3.fromRGB(120, 220, 240), torso)
		end
	end
	if player:GetAttribute("Pass_aura") then
		local core = cosmeticPart(folder, "AuraCore", Vector3.one, torso.CFrame, Color3.new(1, 1, 1), torso)
		core.Transparency = 1
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 210, 110), Color3.fromRGB(190, 120, 255))
		sparkles.LightEmission = 1
		sparkles.Rate = 6
		sparkles.Lifetime = NumberRange.new(1, 1.6)
		sparkles.Speed = NumberRange.new(0.5, 1.2)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.35, 0)
		sparkles.Parent = core
	end
	if player:GetAttribute("Pass_vip") and head then
		local tag = Instance.new("BillboardGui")
		tag.Name = "VipTag"
		tag.Adornee = head
		tag.Size = UDim2.fromOffset(220, 40)
		tag.StudsOffset = Vector3.new(0, 2.6, 0)
		tag.MaxDistance = 60
		tag.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "★ VIP · " .. player.DisplayName
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = Color3.fromRGB(255, 205, 90)
		label.TextStrokeTransparency = 0.3
		label.Parent = tag
		tag.Parent = folder
	end
	folder.Parent = character
end

-- Re-applies everything that depends on pass ownership.
function ShopService.refresh(player: Player)
	PlotService.setVip(player, player:GetAttribute("Pass_vip") == true)
	EconomyService.recompute(player)
	ShopService.applyCosmetics(player)
end

function ShopService.startPlayer(player: Player)
	for _, pass in Config.Shop.passes do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				player:SetAttribute("Pass_" .. pass.key, true)
			end
		end
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		ShopService.applyCosmetics(player)
	end)
	ShopService.refresh(player)
end

-- Grants one developer product purchase. Returns true when it is safe to tell Roblox
-- PurchaseGranted (the grant is saved). Calling it again with the same purchase id never
-- grants twice.
function ShopService.handleReceipt(player: Player, product: any, purchaseId: string): boolean
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end
	if PlayerDataService.recordReceipt(data, purchaseId) then
		local amount = product.coinsByTier[data.tier]
		EconomyService.grant(player, amount, product.key, true)
		Net.event("Notify"):FireClient(player, { kind = "purchase", text = ("Danke! +%d Münzen"):format(amount) })
	end
	return PlayerDataService.saveNow(player)
end

function ShopService.init()
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local product = productById[receipt.ProductId]
		if not player or not product then
			if not product then
				warn("[Shop] Unknown developer product " .. tostring(receipt.ProductId))
			end
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, saved = pcall(ShopService.handleReceipt, player, product, receipt.PurchaseId)
		if ok and saved then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local pass = passById[passId]
		if purchased and pass then
			player:SetAttribute("Pass_" .. pass.key, true)
			ShopService.refresh(player)
			Analytics.custom(player, "PassPurchased_" .. pass.key)
			Net.event("Notify"):FireClient(player, { kind = "purchase", text = "Danke für deinen Kauf: " .. pass.name .. "!" })
		end
	end)

	Net.event("Track").OnServerEvent:Connect(function(player: Player, name: any)
		if type(name) == "string" and TRACKABLE[name] and trackLimiter:allow(player) then
			Analytics.custom(player, name)
		end
	end)
end

return ShopService
