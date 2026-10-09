--!strict
-- Main Client Controller --

local Players = game:GetService("Players")

local plr = Players.LocalPlayer

local playerScripts = plr:WaitForChild("PlayerScripts")
local controllers = playerScripts:WaitForChild("Controllers")

require(controllers:WaitForChild("PromptVisibilityController"))
require(controllers:WaitForChild("TheftCombatController"))
require(controllers:WaitForChild("TheftVisualController"))

local CustomerUIController = require(controllers:WaitForChild("CustomerUIController"))
local UIController = require(controllers:WaitForChild("UIController"))

CustomerUIController.Start()
UIController.Start()
