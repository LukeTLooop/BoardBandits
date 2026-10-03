--!strict
-- UI Controller

-- Services --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages --
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))

-- UI --
local App = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("App"))

local e = React.createElement

-- Controller --
local UIController = {}

local root: any = nil

-- Start --
function UIController.Start()
    if root then return end

    local plr = Players.LocalPlayer
    assert(plr ~= nil)

    local playerGui = plr.PlayerGui
    assert(playerGui:IsA("PlayerGui"))

    -- React root GUI
    local existing = playerGui:FindFirstChild("FactoryReactGui")
    if existing then
        existing:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FactoryReactGui"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 50
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- Mount
    root = ReactRoblox.createRoot(
        screenGui
    )
    
    root:render(
        e(App)
    )
end

return UIController
