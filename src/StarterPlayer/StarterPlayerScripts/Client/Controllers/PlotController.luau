--!strict
-- Adds local "Ausstellen" prompts to the unlocked pedestals of the player's own plot. The
-- prompts only exist on this client, so visitors never see buttons for someone else's treasury.
-- Building happens by stepping on the plot's build buttons (TycoonService, server-side);
-- gallery pedestals appear later, so new pedestals are picked up as they are added.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Builds = require(ReplicatedStorage.Shared.Builds)
local Config = require(ReplicatedStorage.Shared.Config)
local RelicDefs = require(ReplicatedStorage.Shared.RelicDefs)
local ClientState = require(script.Parent.Parent.ClientState)

local player = Players.LocalPlayer
local PlotController = {}

local prompts: { [number]: ProximityPrompt } = {}
local connections: { RBXScriptConnection } = {}
local currentPlot: Instance? = nil

local function refresh()
	local state = ClientState.data
	if not state then
		return
	end
	for slot, prompt in prompts do
		local occupant = state.display[tostring(slot)]
		local def = occupant and RelicDefs.byId[occupant]
		prompt.Enabled = Builds.slotUnlocked(state.builds or {}, slot)
		prompt.ActionText = if def then "Tauschen" else "Ausstellen"
		prompt.ObjectText = if def then def.name else "Podest " .. slot
	end
end

local function clear()
	for _, prompt in prompts do
		prompt:Destroy()
	end
	table.clear(prompts)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	currentPlot = nil
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

local function addPedestal(hud: any, pedestal: Instance)
	local slot = pedestal:GetAttribute("Slot")
	if type(slot) ~= "number" or prompts[slot] then
		return
	end
	local anchor = pedestal:WaitForChild("Base", 5)
	if not anchor or not pedestal.Parent then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.PedestalRange
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = anchor
	prompt.Triggered:Connect(function()
		hud.openPedestal(slot)
	end)
	prompts[slot] = prompt
	refresh()
end

local function setup(hud: any, index: number)
	clear()
	local function wanted()
		return player:GetAttribute("PlotIndex") == index
	end
	local aetheria = waitFor(Workspace, "Aetheria", wanted)
	local plots = aetheria and waitFor(aetheria, "Plots", wanted)
	local plot = plots and waitFor(plots, "Plot" .. index, wanted)
	local pedestals = plot and waitFor(plot, "Pedestals", wanted)
	if not plot or not pedestals then
		return
	end
	currentPlot = plot
	table.insert(connections, pedestals.ChildAdded:Connect(function(child)
		addPedestal(hud, child)
	end))
	table.insert(connections, pedestals.ChildRemoved:Connect(function(child)
		local slot = child:GetAttribute("Slot")
		if type(slot) == "number" and prompts[slot] then
			prompts[slot]:Destroy()
			prompts[slot] = nil
		end
	end))
	for _, pedestal in pedestals:GetChildren() do
		task.spawn(addPedestal, hud, pedestal)
	end
end

-- World position of the own plot's pieces, for Lumi's guidance.
function PlotController.target(name: string): Vector3?
	local plot = currentPlot
	if not plot then
		return nil
	end
	if name == "pedestal" then
		local pedestals = plot:FindFirstChild("Pedestals")
		local first = pedestals and pedestals:FindFirstChild("Pedestal1")
		return if first and first:IsA("Model") then first:GetPivot().Position else nil
	elseif name == "button" then
		local buttons = plot:FindFirstChild("Buttons")
		local best: BasePart? = nil
		for _, pad in (if buttons then buttons:GetChildren() else {}) do
			if pad:IsA("BasePart") and pad:GetAttribute("BuildId") and (not best or pad.Name < best.Name) then
				best = pad
			end
		end
		return if best then best.Position else nil
	end
	return nil
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
