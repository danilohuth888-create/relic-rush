--!strict
-- Adds local prompts to the player's own plot: "Ausstellen" on each unlocked pedestal and
-- "Ausbauen" on the upgrade stone. The prompts only exist on this client, so visitors never
-- see buttons for someone else's treasury.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local ClientState = require(script.Parent.Parent.ClientState)

local player = Players.LocalPlayer
local PlotController = {}

local prompts: { [number]: ProximityPrompt } = {}
local upgradePrompt: ProximityPrompt? = nil
local currentPlot: Instance? = nil

local function refresh()
	local state = ClientState.data
	if not state then
		return
	end
	local unlocked = Config.Tiers[state.tier].pedestals
	for slot, prompt in prompts do
		local occupant = state.display[tostring(slot)]
		local def = occupant and RelicDefs.byId[occupant]
		prompt.Enabled = slot <= unlocked
		prompt.ActionText = if def then "Tauschen" else "Ausstellen"
		prompt.ObjectText = if def then def.name else "Podest " .. slot
	end
	if upgradePrompt then
		local nextTier = Config.Tiers[state.tier + 1]
		upgradePrompt.Enabled = nextTier ~= nil
		if nextTier then
			upgradePrompt.ActionText = ("Ausbauen (%d Münzen)"):format(nextTier.cost)
			upgradePrompt.ObjectText = nextTier.name
		end
	end
end

local function clear()
	for _, prompt in prompts do
		prompt:Destroy()
	end
	table.clear(prompts)
	if upgradePrompt then
		upgradePrompt:Destroy()
		upgradePrompt = nil
	end
	currentPlot = nil
end

local function newPrompt(parent: Instance, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = Config.PedestalRange
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = parent
	return prompt
end

-- Persistent plot models stream in shortly after the client starts; wait quietly for them.
local function waitFor(parent: Instance, name: string, stillWanted: () -> boolean): Instance?
	while stillWanted() do
		local child = parent:WaitForChild(name, 3)
		if child then
			return child
		end
	end
	return nil
end

local function setup(hud: any, index: number)
	clear()
	local function wanted()
		return player:GetAttribute("PlotIndex") == index
	end
	local plots = waitFor(Workspace, "Aetheria", wanted)
	plots = plots and waitFor(plots, "Plots", wanted)
	local plot = plots and waitFor(plots, "Plot" .. index, wanted)
	local pedestals = plot and waitFor(plot, "Pedestals", wanted)
	if not plot or not pedestals then
		return
	end
	currentPlot = plot
	for slot = 1, Config.MaxPedestals do
		local pedestal = pedestals:WaitForChild("Pedestal" .. slot, 10)
		local anchor = pedestal and pedestal:FindFirstChild("Base")
		if anchor then
			local prompt = newPrompt(anchor, 0)
			prompt.Triggered:Connect(function()
				hud.openPedestal(slot)
			end)
			prompts[slot] = prompt
		end
	end
	local stone = plot:WaitForChild("UpgradeStone", 10)
	local stonePart = stone and stone:FindFirstChild("Stone")
	if stonePart then
		local prompt = newPrompt(stonePart, 0.6)
		prompt.Triggered:Connect(function()
			local ok, success, err = pcall(function()
				return Net.func("Upgrade"):InvokeServer()
			end)
			if not (ok and success) then
				hud.showError(err)
			end
		end)
		upgradePrompt = prompt
	end
	refresh()
end

-- World position of the own plot's pieces, for Lumi's guidance.
function PlotController.target(name: string): Vector3?
	local plot = currentPlot
	if not plot then
		return nil
	end
	local target: Instance? = nil
	if name == "pedestal" then
		local pedestals = plot:FindFirstChild("Pedestals")
		target = pedestals and pedestals:FindFirstChild("Pedestal1")
	elseif name == "upgrade" then
		target = plot:FindFirstChild("UpgradeStone")
	end
	return if target and target:IsA("Model") then target:GetPivot().Position else nil
end

function PlotController.start(hud: any)
	ClientState.Changed:Connect(refresh)
	local function onIndex()
		local index = player:GetAttribute("PlotIndex")
		if type(index) == "number" then
			task.spawn(setup, hud, index)
		else
			clear()
		end
	end
	player:GetAttributeChangedSignal("PlotIndex"):Connect(onIndex)
	onIndex()
end

return PlotController
