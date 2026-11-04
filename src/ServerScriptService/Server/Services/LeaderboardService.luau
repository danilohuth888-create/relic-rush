--!strict
-- "Größte Sammlung": an OrderedDataStore ranking by discovered relics (ties broken by how many
-- relics a player owns), shown on a board at the Crystal Plaza. Writes are sparse: at most
-- once per WRITE_SECONDS per player while their collection changes, plus once when they
-- leave. Studio uses its own store so tests never touch the live ranking.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Progress = require(script.Parent.Parent.Util.Progress)
local PlayerDataService = require(script.Parent.PlayerDataService)

local STORE_NAME = if RunService:IsStudio() then "RelicRush_Collection_Studio_v1" else "RelicRush_Collection_v1"
local WRITE_SECONDS = 90
local REFRESH_SECONDS = 120
local ROWS = 10
local BOARD_CFRAME = CFrame.lookAt(Vector3.new(30, 0, -24), Vector3.new(0, 0, 0))

local LeaderboardService = {}

local store: OrderedDataStore? = nil
local dirty: { [Player]: boolean } = {}
local lastWrite: { [Player]: number } = {}
local names: { [number]: string } = {}
local rowLabels: { TextLabel } = {}

function LeaderboardService.score(data: PlayerDataService.Data): number
	local discovered, owned = 0, 0
	for _ in data.discovered do
		discovered += 1
	end
	for _, n in data.inventory do
		owned += n
	end
	for _ in data.display do
		owned += 1
	end
	return discovered * 10000 + math.min(owned, 9999)
end

local function write(userId: number, score: number)
	if not store then
		return
	end
	local ok, err = pcall(function()
		(store :: OrderedDataStore):SetAsync("u_" .. userId, score)
	end)
	if not ok then
		warn("[Leaderboard] write failed: " .. tostring(err))
	end
end

local function flush(player: Player)
	local data = PlayerDataService.get(player)
	if data then
		dirty[player] = nil
		lastWrite[player] = os.clock()
		task.spawn(write, player.UserId, LeaderboardService.score(data))
	end
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	local ok, name = pcall(function()
		return if player then player.DisplayName else Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and name then name else "Spieler " .. userId
	return names[userId]
end

local function buildBoard()
	local aetheria = Workspace:WaitForChild("Aetheria")
	local model = Instance.new("Model")
	model.Name = "Leaderboard"
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.Parent = model
		return p
	end
	local wood = Color3.fromRGB(132, 94, 72)
	for _, x in { -6.6, 6.6 } do
		part("Post", Vector3.new(0.8, 12, 0.8), BOARD_CFRAME * CFrame.new(x, 6, 0.3), wood)
	end
	local board = part("Board", Vector3.new(14, 10, 0.5), BOARD_CFRAME * CFrame.new(0, 7.2, 0), Color3.fromRGB(58, 42, 92))
	part("Crest", Vector3.new(15, 1, 0.8), BOARD_CFRAME * CFrame.new(0, 12.5, 0), Color3.fromRGB(255, 196, 84), Enum.Material.Metal)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 24)
	padding.PaddingRight = UDim.new(0, 24)
	padding.Parent = gui
	local function line(order: number, height: number, color: Color3, size: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, height)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextSize = size
		l.TextColor3 = color
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.LayoutOrder = order
		l.Text = ""
		l.Parent = gui
		return l
	end
	local title = line(0, 56, Color3.fromRGB(255, 215, 110), 44)
	title.Name = "Title"
	title.Text = "🏆 Größte Sammlung"
	title.TextXAlignment = Enum.TextXAlignment.Center
	for i = 1, ROWS do
		local row = line(i, 30, if i <= 3 then Color3.fromRGB(255, 240, 200) else Color3.fromRGB(225, 215, 245), 26)
		row.Name = "Row" .. i
		rowLabels[i] = row
	end
	gui.Parent = board
	model.Parent = aetheria
end

function LeaderboardService.refresh(): { { userId: number, score: number } }
	local result = {}
	if not store then
		return result
	end
	local ok, pages = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(false, ROWS)
	end)
	if not ok then
		warn("[Leaderboard] read failed: " .. tostring(pages))
		return result
	end
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber((entry.key :: string):sub(3))
		if userId then
			table.insert(result, { userId = userId, score = entry.value :: number })
		end
	end
	for i, label in rowLabels do
		local entry = result[i]
		label.Text = if entry
			then ("%d.  %s  –  %d Relikte"):format(i, nameOf(entry.userId), entry.score // 10000)
			else ""
	end
	return result
end

-- New and returning players show up on the board soon after joining.
function LeaderboardService.startPlayer(player: Player)
	dirty[player] = true
	lastWrite[player] = 0
end

-- Studio DevTools only: writes test entries (negative user ids) or removes them again.
function LeaderboardService.testEntries(entries: { { userId: number, score: number } }, remove: boolean)
	assert(RunService:IsStudio(), "Studio only")
	for _, entry in entries do
		if remove then
			pcall(function()
				(store :: OrderedDataStore):RemoveAsync("u_" .. entry.userId)
			end)
		else
			write(entry.userId, entry.score)
		end
	end
end

function LeaderboardService.stopPlayer(player: Player)
	if dirty[player] then
		flush(player)
	end
	dirty[player] = nil
	lastWrite[player] = nil
end

function LeaderboardService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(STORE_NAME)
	end)
	if ok and game.PlaceId ~= 0 then
		store = result
	else
		warn("[Leaderboard] OrderedDataStore unavailable; the board stays empty.")
	end
	buildBoard()
	Progress.on(function(player: Player, stat: string)
		if stat == "collect" or stat == "discover" then
			dirty[player] = true
		end
	end)
	task.spawn(function()
		while true do
			LeaderboardService.refresh()
			for _ = 1, REFRESH_SECONDS / 10 do
				task.wait(10)
				local now = os.clock()
				for player in dirty do
					if player.Parent and now - (lastWrite[player] or 0) >= WRITE_SECONDS then
						flush(player)
					end
				end
			end
		end
	end)
end

return LeaderboardService
