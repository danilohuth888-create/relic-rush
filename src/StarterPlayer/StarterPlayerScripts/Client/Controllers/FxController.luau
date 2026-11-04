--!strict
-- Local visual feedback: "+X" coin numbers over the relics in the player's own treasury,
-- a spark shower when the treasury is upgraded, glitter on rare finds and a short camera
-- kick. Everything here is cosmetic and client-only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local ClientState = require(script.Parent.Parent.ClientState)

local player = Players.LocalPlayer
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local GOLD = Color3.fromRGB(255, 210, 80)
local VIOLET = Color3.fromRGB(190, 130, 255)
local POP_INTERVAL = 3 -- seconds between "+X" pops; each shows the coins of that interval
local POP_RANGE = 70

local FxController = {}

local fxFolder: Folder

-- An invisible anchored part that hosts emitters for a few seconds, then cleans itself up.
local function host(position: Vector3, lifetime: number): Part
	local part = Instance.new("Part")
	part.Name = "Fx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.Position = position
	part.Parent = fxFolder
	task.delay(lifetime, function()
		part:Destroy()
	end)
	return part
end

local function emitter(parent: Instance, color: ColorSequence, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLES
	e.Color = color
	e.LightEmission = 1
	e.Enabled = false
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- Glitter burst in the relic's colour (rare finds).
function FxController.glitter(position: Vector3, color: Color3, amount: number)
	local part = host(position, 3)
	local e = emitter(part, ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.5), color), {
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.7, 1.4),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Acceleration = Vector3.new(0, 4, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-180, 180),
	})
	e:Emit(amount)
end

-- Gold and violet sparks raining down over the whole plot (treasury upgrade).
function FxController.sparkRain(center: Vector3)
	local part = host(center + Vector3.new(0, 22, 0), 5)
	part.Size = Vector3.new(34, 0.2, 34)
	local colors = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, VIOLET),
	})
	local e = emitter(part, colors, {
		Shape = Enum.ParticleEmitterShape.Box,
		EmissionDirection = Enum.NormalId.Bottom,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(0.8, 0.8), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(4, 9),
		Acceleration = Vector3.new(0, -6, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
	})
	e:Emit(140)
	task.delay(0.5, function()
		e:Emit(80)
	end)
end

-- A quick field-of-view kick, optionally with a small shake (bigger moments only).
function FxController.cameraKick(strength: number, shake: boolean?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local base = camera.FieldOfView
	local out = TweenService:Create(camera, TweenInfo.new(0.09, Enum.EasingStyle.Quad), { FieldOfView = base + strength })
	out.Completed:Once(function()
		TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Back), { FieldOfView = base }):Play()
	end)
	out:Play()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if shake and humanoid then
		task.spawn(function()
			for i = 8, 1, -1 do
				local m = i * 0.035
				humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * m, (math.random() - 0.5) * m, 0)
				RunService.RenderStepped:Wait()
				RunService.RenderStepped:Wait()
			end
			humanoid.CameraOffset = Vector3.zero
		end)
	end
end

local function ownPlot(): Model?
	local index = player:GetAttribute("PlotIndex")
	local aetheria = Workspace:FindFirstChild("Aetheria")
	local plots = aetheria and aetheria:FindFirstChild("Plots")
	return if type(index) == "number" and plots then plots:FindFirstChild("Plot" .. index) :: Model? else nil
end

local function formatAmount(n: number): string
	if n >= 10 then
		return tostring(math.floor(n + 0.5))
	end
	return (("%g"):format(math.floor(n * 10 + 0.5) / 10):gsub("%.", ","))
end

-- A gold "+X" that rises from the relic and fades.
local function pop(adornee: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CoinPop"
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = POP_RANGE
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = GOLD
	label.TextStrokeColor3 = Color3.fromRGB(110, 60, 10)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = fxFolder
	local rise = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, rise, { StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.8), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.5, function()
		gui:Destroy()
	end)
end

local popIndex = 0
local function popCoins()
	local state = ClientState.data
	local plot = ownPlot()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not state or not plot or not root or (plot:GetPivot().Position - root.Position).Magnitude > POP_RANGE then
		return
	end
	local pedestals = plot:FindFirstChild("Pedestals")
	if not pedestals then
		return
	end
	local multiplier = if player:GetAttribute("Pass_double_coins") then 2 else 1
	-- Stagger the pops across the interval so a full treasury twinkles instead of flashing.
	local slots = {}
	for slot, relicId in state.display do
		table.insert(slots, { slot = slot, def = RelicDefs.byId[relicId] })
	end
	popIndex += 1
	for i, entry in slots do
		local pedestal = pedestals:FindFirstChild("Pedestal" .. entry.slot)
		local display = pedestal and pedestal:FindFirstChild("Display")
		local primary = display and display:IsA("Model") and display.PrimaryPart
		if entry.def and primary then
			task.delay((i - 1) / #slots * POP_INTERVAL * 0.8, function()
				if primary.Parent then
					pop(primary, "+" .. formatAmount(entry.def.rate * multiplier * POP_INTERVAL))
				end
			end)
		end
	end
end

function FxController.start()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "LocalFx"
	fxFolder.Parent = Workspace

	Net.event("Notify").OnClientEvent:Connect(function(message: any)
		if type(message) == "table" and message.kind == "reward" and type(message.relics) == "table" and #message.relics > 0 then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				FxController.glitter(root.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 200, 90), 90)
			end
			FxController.cameraKick(6, true)
		elseif type(message) == "table" and message.kind == "build" and typeof(message.position) == "Vector3" then
			FxController.glitter(message.position + Vector3.new(0, 3, 0), Color3.fromRGB(255, 210, 90), 60)
			FxController.cameraKick(3)
		elseif type(message) == "table" and message.kind == "upgrade" then
			local plot = ownPlot()
			if plot then
				FxController.sparkRain(plot:GetPivot().Position)
			end
			FxController.cameraKick(6, true)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(POP_INTERVAL)
			popCoins()
		end
	end)
end

return FxController
