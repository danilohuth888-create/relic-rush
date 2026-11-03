--!strict
-- Client entry point: builds the HUD first so the player sees it immediately, then the
-- world controllers, then asks the server for the current state.

local Controllers = script.Parent.Controllers
local Audio = require(script.Parent.Audio)
local ClientState = require(script.Parent.ClientState)
local Settings = require(script.Parent.Settings)
local HudController = require(Controllers.HudController)
local RelicController = require(Controllers.RelicController)
local PlotController = require(Controllers.PlotController)
local LumiController = require(Controllers.LumiController)
local FxController = require(Controllers.FxController)

HudController.start()
FxController.start()
RelicController.start(HudController)
PlotController.start(HudController)
LumiController.start(HudController, RelicController, PlotController)
Settings.start()
ClientState.start()
Audio.start()
