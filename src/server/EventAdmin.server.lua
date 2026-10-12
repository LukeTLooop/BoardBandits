--!strict
-- Event Admin Command Handler

-- Services --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

-- Game Services --
local EventAdminService = require(script.Parent.Services.EventAdminService)

-- Remotes --
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local adminRemotes = remotesFolder:FindFirstChild("AdminEvents")

if not adminRemotes then
	adminRemotes = Instance.new("Folder")
	adminRemotes.Name = "AdminEvents"
	adminRemotes.Parent = remotesFolder
end

local feedback = adminRemotes:FindFirstChild("Feedback")

if not feedback then
	feedback = Instance.new("RemoteEvent")
	feedback.Name = "Feedback"
	feedback.Parent = adminRemotes
end

assert(feedback:IsA("RemoteEvent"))

-- Command --
local command = TextChatService:FindFirstChild("BoardBanditsEventCommand")

if not command then
	command = Instance.new("TextChatCommand")
	command.Name = "BoardBanditsEventCommand"
	command.Parent = TextChatService
end

assert(command:IsA("TextChatCommand"))

command.PrimaryAlias = "/event"
command.AutocompleteVisible = false
command.Enabled = true

-- Events --
command.Triggered:Connect(function(textSource: TextSource, unfilteredText: string)
	local player = Players:GetPlayerByUserId(textSource.UserId)

	if not player then
		return
	end

	local success, result = pcall(function(): { string }
		return EventAdminService:Execute(player, unfilteredText)
	end)

	if not success then
		warn(`[EventAdmin] Command execution failed: {tostring(result)}`)

		feedback:FireClient(player, { "Command failed. Check the server logs." })

		return
	end

	-- Reply only to the developer who issued the command --
	feedback:FireClient(player, result)
end)
