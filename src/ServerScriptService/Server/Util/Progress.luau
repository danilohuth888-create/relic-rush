--!strict
-- Tiny progress bus. Gameplay services report what a player did ("collect", "place", ...);
-- quest/goal logic listens. Keeps services from requiring each other in circles.

local Progress = {}

type Listener = (player: Player, stat: string, amount: number, detail: any?) -> ()
local listeners: { Listener } = {}

function Progress.on(listener: Listener)
	table.insert(listeners, listener)
end

function Progress.bump(player: Player, stat: string, amount: number?, detail: any?)
	for _, listener in listeners do
		task.spawn(listener, player, stat, amount or 1, detail)
	end
end

return Progress
