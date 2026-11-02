--!strict
-- Names every remote in one place. The server creates them on first require, clients wait.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = { "State", "SpawnAdded" }
local FUNCTIONS = { "GetState", "GetSpawns", "Collect", "Place", "Unplace", "GoHome" }

local folder: Instance
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Net = {}

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
