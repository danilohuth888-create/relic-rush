--!strict
-- The player's settings on the client. Changes apply immediately (volumes, Lumi) and are sent
-- to the server once the player stops fiddling; until then server pushes don't overwrite them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Audio = require(script.Parent.Audio)
local ClientState = require(script.Parent.ClientState)

local SAVE_DELAY = 0.8

local Settings = {}
Settings.values = table.clone(Config.DefaultSettings)

local changed = Instance.new("BindableEvent")
Settings.Changed = changed.Event

local dirty = false
local token = 0

local function adopt(raw: any)
	if type(raw) ~= "table" then
		return
	end
	for key, default in Config.DefaultSettings do
		local value = raw[key]
		Settings.values[key] = if type(value) == type(default) then value else default
	end
	Audio.apply(Settings.values)
	changed:Fire()
end

function Settings.set(key: string, value: any)
	local default = (Config.DefaultSettings :: any)[key]
	if default == nil or type(value) ~= type(default) then
		return
	end
	if type(value) == "number" then
		local steps = math.floor(1 / Config.SettingsStep + 0.5)
		value = math.clamp(math.floor(value * steps + 0.5) / steps, 0, 1)
	end
	if (Settings.values :: any)[key] == value then
		return
	end
	(Settings.values :: any)[key] = value
	dirty = true
	Audio.apply(Settings.values)
	changed:Fire()

	token += 1
	local mine = token
	task.delay(SAVE_DELAY, function()
		if mine ~= token then
			return
		end
		pcall(function()
			Net.func("SaveSettings"):InvokeServer(Settings.values)
		end)
		if mine == token then
			dirty = false
		end
	end)
end

function Settings.start()
	ClientState.Changed:Connect(function(state)
		if not dirty then
			adopt(state.settings)
		end
	end)
	if ClientState.data then
		adopt(ClientState.data.settings)
	end
end

return Settings
