--!strict
-- Shows world text in this player's language: TextLabels and ProximityPrompts the server marked
-- with LFormat/LArgs (see Server/Util/WorldText) or LAction, and static texts from the world
-- builders whose German text has an English entry. German players need none of this.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Locale = require(ReplicatedStorage.Shared.Locale)

local LANG = Locale.of(Players.LocalPlayer)

local LocalizeController = {}

local MARK = "§" -- two bytes in UTF-8

local function arg(lang: string, raw: string): any
	if raw:sub(1, #MARK) == MARK then
		return Locale.text(lang, raw:sub(#MARK + 1))
	elseif raw:sub(1, 1) == "#" then
		return Locale.number(lang, tonumber(raw:sub(2)) or 0)
	end
	return tonumber(raw) or raw
end

local function formatted(source: string, rawArgs: any): string
	local args = {}
	if type(rawArgs) == "string" and rawArgs ~= "" then
		for _, raw in string.split(rawArgs, "\t") do
			table.insert(args, arg(LANG, raw))
		end
	end
	local ok, text = pcall(Locale.format, LANG, source, table.unpack(args))
	return if ok then text else source
end

local function applyLabel(label: TextLabel)
	local source = label:GetAttribute("LFormat")
	if type(source) == "string" then
		label.Text = formatted(source, label:GetAttribute("LArgs"))
	elseif Locale.has(label.Text) then
		label.Text = Locale.text(LANG, label.Text)
	end
end

local function applyPrompt(prompt: ProximityPrompt)
	local action = prompt:GetAttribute("LAction")
	if type(action) == "string" then
		prompt.ActionText = formatted(action, prompt:GetAttribute("LArgs"))
	elseif Locale.has(prompt.ActionText) then
		prompt.ActionText = Locale.text(LANG, prompt.ActionText)
	end
	if Locale.has(prompt.ObjectText) then
		prompt.ObjectText = Locale.text(LANG, prompt.ObjectText)
	end
end

local function watch(inst: Instance)
	if inst:IsA("TextLabel") then
		applyLabel(inst)
		inst:GetAttributeChangedSignal("LFormat"):Connect(function()
			applyLabel(inst)
		end)
		inst:GetAttributeChangedSignal("LArgs"):Connect(function()
			applyLabel(inst)
		end)
		-- Static texts the server rewrites later (e.g. a sign) are re-checked on change.
		inst:GetPropertyChangedSignal("Text"):Connect(function()
			if inst:GetAttribute("LFormat") == nil and Locale.has(inst.Text) then
				inst.Text = Locale.text(LANG, inst.Text)
			end
		end)
	elseif inst:IsA("ProximityPrompt") then
		applyPrompt(inst)
		for _, name in { "LAction", "LArgs" } do
			inst:GetAttributeChangedSignal(name):Connect(function()
				applyPrompt(inst)
			end)
		end
		inst:GetPropertyChangedSignal("ObjectText"):Connect(function()
			if Locale.has(inst.ObjectText) then
				inst.ObjectText = Locale.text(LANG, inst.ObjectText)
			end
		end)
	end
end

function LocalizeController.start()
	if LANG == "de" then
		return
	end
	Workspace.DescendantAdded:Connect(watch)
	for _, inst in Workspace:GetDescendants() do
		watch(inst)
	end
end

return LocalizeController
