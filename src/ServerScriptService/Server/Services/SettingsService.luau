--!strict
-- Stores the player's settings (music and effect volume, Lumi hints) in their profile.
-- The client applies changes locally right away and sends the whole set here, debounced;
-- the server only accepts well-formed values and snaps volumes to the slider steps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SettingsService = {}

local limiter = RateLimiter.new(4, 1)

local function volume(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then
		return nil -- also rejects NaN
	end
	local steps = math.floor(1 / Config.SettingsStep + 0.5)
	return math.floor(value * steps + 0.5) / steps
end

-- Returns the cleaned settings, or nil and an error code when anything is malformed.
function SettingsService.sanitize(raw: any): (PlayerDataService.Settings?, string?)
	if type(raw) ~= "table" then
		return nil, "bad_settings"
	end
	local music, sfx = volume(raw.music), volume(raw.sfx)
	if music == nil or sfx == nil or type(raw.hints) ~= "boolean" then
		return nil, "bad_settings"
	end
	return { music = music, sfx = sfx, hints = raw.hints }, nil
end

function SettingsService.save(player: Player, raw: any): (boolean, string?)
	local data = PlayerDataService.get(player)
	if not data then
		return false, "not_loaded"
	end
	local clean, err = SettingsService.sanitize(raw)
	if not clean then
		return false, err
	end
	data.settings = clean
	return true, nil
end

function SettingsService.init()
	Net.func("SaveSettings").OnServerInvoke = function(player: Player, raw: any)
		if not limiter:allow(player) then
			return false, "rate"
		end
		return SettingsService.save(player, raw)
	end
end

return SettingsService
