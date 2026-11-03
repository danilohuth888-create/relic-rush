--!strict
-- Music and sound effects for the local player. Two SoundGroups carry the player's volume
-- settings; one looping track per area cross-fades as the player walks between areas.
-- Required by the HUD and the controllers; start() begins the music once the HUD exists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local player = Players.LocalPlayer
local FADE = TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local Audio = {}
Audio.settings = table.clone(Config.DefaultSettings)
Audio.area = "Plaza"

local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Music"
musicGroup.Parent = SoundService
local effectsGroup = Instance.new("SoundGroup")
effectsGroup.Name = "Effects"
effectsGroup.Parent = SoundService

local templates: { [string]: Sound } = {}
for key, info in Sounds.sfx do
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = "rbxassetid://" .. info.id
	sound.Volume = info.volume
	sound.SoundGroup = effectsGroup
	sound.Parent = effectsGroup
	templates[key] = sound
end

local tracks: { [string]: Sound } = {}
local current: string? = nil

local lastPlayed: { [string]: number } = {}

-- Plays a one-shot effect. pitch shifts it (rarer finds ring higher); rapid repeats of the
-- same effect within 50 ms are dropped so spam never turns into noise.
function Audio.play(key: string, pitch: number?)
	local template = templates[key]
	if not template or Audio.settings.sfx <= 0 then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[key] or 0) < 0.05 then
		return
	end
	lastPlayed[key] = now
	local sound = template:Clone()
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = effectsGroup
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(8, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Collect feedback graded by rarity rank (1 = Common … 5 = Legendary).
function Audio.collect(rank: number)
	Audio.play("collect", Sounds.collectPitch[rank] or 1)
	if rank >= 3 then
		Audio.play("sparkle")
	end
	if rank >= 4 then
		Audio.play("epic")
	end
end

-- Applies a settings table (from the server or the settings panel) to both groups.
function Audio.apply(settings: any)
	if type(settings) ~= "table" then
		return
	end
	for key, default in Config.DefaultSettings do
		local value = settings[key]
		Audio.settings[key] = if type(value) == type(default) then value else default
	end
	musicGroup.Volume = Audio.settings.music
	effectsGroup.Volume = Audio.settings.sfx
end

local function track(area: string): Sound?
	local info = Sounds.music[area]
	if not info then
		return nil
	end
	local sound = tracks[area]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Music_" .. area
		sound.SoundId = "rbxassetid://" .. info.id
		sound.Looped = true
		sound.Volume = 0
		sound.SoundGroup = musicGroup
		sound.Parent = musicGroup
		tracks[area] = sound
	end
	return sound
end

-- Cross-fades to the area's track. A track that fades out pauses, so it resumes where it
-- stopped when the player comes back.
function Audio.setArea(area: string)
	if area == current or not Sounds.music[area] then
		return
	end
	current = area
	Audio.area = area
	for name, sound in tracks do
		if name ~= area then
			local fade = TweenService:Create(sound, FADE, { Volume = 0 })
			fade.Completed:Once(function(state)
				if state == Enum.PlaybackState.Completed and current ~= name then
					sound:Pause()
				end
			end)
			fade:Play()
		end
	end
	local sound = track(area) :: Sound
	if not sound.IsPlaying then
		sound:Resume()
		if not sound.IsPlaying then
			sound:Play()
		end
	end
	TweenService:Create(sound, FADE, { Volume = Sounds.music[area].volume }):Play()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Which area the position belongs to: any treasury plot, then the configured zones, else Plaza.
function Audio.areaAt(position: Vector3): string
	local aetheria = Workspace:FindFirstChild("Aetheria")
	local plots = aetheria and aetheria:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			if plot:IsA("Model") and (flat(plot:GetPivot().Position) - flat(position)).Magnitude < Config.PlotZoneRadius then
				return "Treasury"
			end
		end
	end
	for name, zone in Config.Zones do
		if (flat(zone.center) - flat(position)).Magnitude < zone.radius then
			return name
		end
	end
	return "Plaza"
end

function Audio.start()
	Audio.setArea("Plaza")
	task.spawn(function()
		while true do
			task.wait(0.5)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				-- An explicit override (e.g. the expedition) wins over the position.
				local forced = player:GetAttribute("MusicArea")
				Audio.setArea(if type(forced) == "string" then forced else Audio.areaAt(root.Position))
			end
		end
	end)
end

Audio.apply(Config.DefaultSettings)

return Audio
