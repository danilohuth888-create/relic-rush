--!strict
-- Latest copy of the local player's data as sent by the server, plus a change signal.
-- Read-only on the client: the server is the only source of truth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local ClientState = {}
ClientState.data = nil :: any

local changed = Instance.new("BindableEvent")
ClientState.Changed = changed.Event

local function set(data: any)
	if data then
		ClientState.data = data
		changed:Fire(data)
	end
end

function ClientState.start()
	Net.event("State").OnClientEvent:Connect(set)
	task.spawn(function()
		local ok, data = pcall(function()
			return Net.func("GetState"):InvokeServer()
		end)
		if ok and ClientState.data == nil then
			set(data)
		end
	end)
end

return ClientState
