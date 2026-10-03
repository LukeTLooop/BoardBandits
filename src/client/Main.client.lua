--!strict
-- Main Client Controller --

local Players = game:GetService("Players")

local plr = Players.LocalPlayer
assert(plr ~= nil, "Main.client.lua must be run on the client!")

local playerScripts = plr:WaitForChild("PlayerScripts")
local controllers = playerScripts:WaitForChild("Controllers")

require(controllers:WaitForChild("PromptVisibilityController"))

local UIController = require(controllers:WaitForChild("UIController"))

UIController.Start()
