--!strict
-- Client entry point: builds the HUD first so the player sees it immediately, then the
-- world controllers, then asks the server for the current state.

local Controllers = script.Parent.Controllers
local ClientState = require(script.Parent.ClientState)
local HudController = require(Controllers.HudController)
local RelicController = require(Controllers.RelicController)
local PlotController = require(Controllers.PlotController)

HudController.start()
RelicController.start(HudController)
PlotController.start(HudController)
ClientState.start()
