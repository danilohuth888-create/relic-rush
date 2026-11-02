--!strict
-- Adds local "Ausstellen" prompts to the pedestals of the player's own plot. The prompts only
-- exist on this client, so visitors never see buttons for someone else's treasury.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local ClientState = require(script.Parent.Parent.ClientState)

local player = Players.LocalPlayer
local PlotController = {}

local prompts: { [number]: ProximityPrompt } = {}

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
end

local function clear()
	for _, prompt in prompts do
		prompt:Destroy()
	end
	table.clear(prompts)
end

local function setup(hud: any, index: number)
	clear()
	local plot = Workspace:WaitForChild("Aetheria"):WaitForChild("Plots"):WaitForChild("Plot" .. index)
	local pedestals = plot:WaitForChild("Pedestals")
	for slot = 1, Config.MaxPedestals do
		local pedestal = pedestals:WaitForChild("Pedestal" .. slot, 10)
		local anchor = pedestal and pedestal:FindFirstChild("Base")
		if anchor then
			local prompt = Instance.new("ProximityPrompt")
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = Config.PedestalRange
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.Triggered:Connect(function()
				hud.openPedestal(slot)
			end)
			prompt.Parent = anchor
			prompts[slot] = prompt
		end
	end
	refresh()
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
