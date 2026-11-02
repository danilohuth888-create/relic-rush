--!strict
-- Loads, holds and saves player profiles.
-- DataStore records carry a session lock ({ job, t }) so two servers never write the same
-- player at once. In an unpublished Studio place there is no DataStore access, so profiles
-- fall back to memory and nothing survives the session (logged as a warning).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local STORE_NAME = "RelicRush_Players_v1"
local SCHEMA_VERSION = 2
-- Autosave refreshes the lock every Config.AutosaveSeconds; a lock this old belongs to a
-- crashed server, so a rejoining player is not locked out for long.
local LOCK_STALE_SECONDS = 180
local MAX_ATTEMPTS = 5
local MAX_RECEIPTS = 50

export type Quest = { id: string, goal: number, progress: number, claimed: boolean }
export type Data = {
	version: number,
	coins: number,
	inventory: { [string]: number }, -- relicId -> count not on display
	display: { [string]: string }, -- tostring(slot) -> relicId
	tier: number,
	stats: { collected: number, placed: number, upgrades: number, coinsEarned: number, forestVisited: boolean },
	tutorial: { done: boolean },
	discovered: { [string]: boolean },
	milestones: number, -- how many Config.Milestones are already paid out
	quests: { day: number, list: { Quest } },
	receipts: { string }, -- last processed Developer Product purchase ids
	lastSeen: number,
}

local PlayerDataService = {}
PlayerDataService.persistent = false

local store: DataStore? = nil
local memory: { [number]: Data } = {}
local profiles: { [Player]: Data } = {}
local saving: { [number]: boolean } = {}

local function defaultData(): Data
	return {
		version = SCHEMA_VERSION,
		coins = 0,
		inventory = {},
		display = {},
		tier = 1,
		stats = { collected = 0, placed = 0, upgrades = 0, coinsEarned = 0, forestVisited = false },
		tutorial = { done = false },
		discovered = {},
		milestones = 0,
		quests = { day = 0, list = {} },
		receipts = {},
		lastSeen = 0,
	}
end

-- One function per schema bump; runs after missing fields were filled with defaults.
local MIGRATIONS: { [number]: (any) -> () } = {
	[2] = function(data)
		-- v1 had no collection book: everything the player owns counts as discovered.
		for relicId in data.inventory do
			data.discovered[relicId] = true
		end
		for _, relicId in data.display do
			data.discovered[relicId] = true
		end
		data.tutorial = { done = false }
	end,
}

local function reconcile(data: any): Data
	local fresh = defaultData() :: any
	for key, value in fresh do
		if data[key] == nil then
			data[key] = value
		end
	end
	for _, group in { "stats", "tutorial", "quests" } do
		for key, value in fresh[group] do
			if data[group][key] == nil then
				data[group][key] = value
			end
		end
	end
	while data.version < SCHEMA_VERSION do
		local migrate = MIGRATIONS[data.version + 1]
		if migrate then
			migrate(data)
		end
		data.version += 1
	end
	data.tier = math.clamp(math.floor(tonumber(data.tier) or 1), 1, #Config.Tiers)
	return data
end

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end

local function useMemory(reason: string)
	if store then
		warn("[PlayerData] Switching to in-memory profiles: " .. reason)
	end
	store = nil
	PlayerDataService.persistent = false
end

local function key(userId: number): string
	return "u_" .. userId
end

-- Returns the stored data, nil when another live server still holds the lock, or errors.
local function lockAndRead(userId: number): (boolean, any)
	local lockedByOther = false
	local ok, result = pcall(function()
		return (store :: DataStore):UpdateAsync(key(userId), function(record: any)
			record = record or { data = defaultData() }
			local lock = record.lock
			if lock and lock.job ~= game.JobId and os.time() - (lock.t or 0) < LOCK_STALE_SECONDS then
				lockedByOther = true
				return nil
			end
			record.lock = { job = game.JobId, t = os.time() }
			return record
		end)
	end)
	if not ok then
		return false, result
	end
	if lockedByOther then
		return true, nil
	end
	return true, result.data
end

local function writeRecord(userId: number, data: Data, release: boolean): boolean
	data.lastSeen = os.time()
	if not store then
		memory[userId] = deepCopy(data)
		return true
	end
	for attempt = 1, MAX_ATTEMPTS do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key(userId), function(record: any)
				record = record or {}
				if record.lock and record.lock.job ~= game.JobId then
					return nil -- another server owns this player now; never overwrite its data
				end
				record.data = data
				record.lock = if release then nil else { job = game.JobId, t = os.time() }
				return record
			end)
		end)
		if ok then
			return true
		end
		warn(("[PlayerData] Save for %d failed (attempt %d): %s"):format(userId, attempt, tostring(err)))
		task.wait(math.min(2 ^ attempt, 16))
	end
	return false
end

function PlayerDataService.init()
	if game.PlaceId == 0 then
		warn("[PlayerData] Place is not published: profiles live in memory only and are not saved.")
	else
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			store = result
			PlayerDataService.persistent = true
		else
			warn("[PlayerData] DataStore unavailable: " .. tostring(result))
		end
	end

	Net.func("GetState").OnServerInvoke = function(player: Player)
		local deadline = os.clock() + 30
		while not profiles[player] and player.Parent and os.clock() < deadline do
			task.wait(0.2)
		end
		return PlayerDataService.snapshot(player)
	end

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for player, data in profiles do
				task.spawn(writeRecord, player.UserId, data, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, data in profiles do
			pending += 1
			task.spawn(function()
				writeRecord(player.UserId, data, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

-- Yields. Returns nil when the player left or their data could not be loaded (they are kicked).
function PlayerDataService.load(player: Player): Data?
	local userId = player.UserId
	while saving[userId] do
		task.wait(0.1)
	end

	local raw: any = nil
	if store then
		local loaded = false
		for attempt = 1, MAX_ATTEMPTS do
			local ok, result = lockAndRead(userId)
			if ok and result ~= nil then
				raw, loaded = result, true
				break
			end
			if not ok then
				warn(("[PlayerData] Load for %d failed (attempt %d): %s"):format(userId, attempt, tostring(result)))
				if RunService:IsStudio() then
					useMemory("Studio has no DataStore access (" .. tostring(result) .. ")")
					break
				end
			end
			if not player.Parent then
				return nil
			end
			task.wait(attempt * 2)
		end
		if store and not loaded then
			player:Kick("Deine Spieldaten konnten gerade nicht geladen werden. Bitte tritt erneut bei.")
			return nil
		end
	end
	if not store then
		raw = if memory[userId] then deepCopy(memory[userId]) else nil
	end

	local data = reconcile(raw or defaultData())
	if not player.Parent then
		writeRecord(userId, data, true)
		return nil
	end
	profiles[player] = data
	return data
end

function PlayerDataService.get(player: Player): Data?
	return profiles[player]
end

function PlayerDataService.snapshot(player: Player): any
	local data = profiles[player]
	if not data then
		return nil
	end
	return {
		inventory = data.inventory,
		display = data.display,
		tier = data.tier,
		collected = data.stats.collected,
		forestVisited = data.stats.forestVisited,
		tutorialDone = data.tutorial.done,
		discovered = data.discovered,
		milestones = data.milestones,
		quests = data.quests.list,
		persistent = PlayerDataService.persistent,
	}
end

-- Saves immediately (yields). Used after purchases so a grant is on disk before Roblox is told.
function PlayerDataService.saveNow(player: Player): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	return writeRecord(player.UserId, data, false)
end

-- Remembers a processed purchase id; returns false if it was already processed.
function PlayerDataService.recordReceipt(data: Data, purchaseId: string): boolean
	if table.find(data.receipts, purchaseId) then
		return false
	end
	table.insert(data.receipts, purchaseId)
	while #data.receipts > MAX_RECEIPTS do
		table.remove(data.receipts, 1)
	end
	return true
end

-- Pushes the player's inventory/display/tier to their client (coins travel as an attribute).
function PlayerDataService.replicate(player: Player)
	local snap = PlayerDataService.snapshot(player)
	if snap then
		Net.event("State"):FireClient(player, snap)
	end
end

function PlayerDataService.release(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	profiles[player] = nil
	local userId = player.UserId
	saving[userId] = true
	writeRecord(userId, data, true)
	saving[userId] = nil
end

return PlayerDataService
