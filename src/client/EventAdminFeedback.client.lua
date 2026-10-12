--!strict
-- Event Admin Feedback Controller

-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

-- Remotes --
local feedback = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminEvents"):WaitForChild("Feedback")
assert(feedback:IsA("RemoteEvent"))

-- Internal --
local function EscapeRichText(value: string): string
	return value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function DisplayFeedback(messages: { string })
	if #messages == 0 then
		return
	end

	-- Escape all message content --
	local formattedMessages: { string } = {}

	for _, message in messages do
		local escapedMessage = EscapeRichText(message)
		table.insert(formattedMessages, escapedMessage)
	end

	-- Combine messages into one chat entry --
	local formattedText = "[Board Bandits Events]\n" .. table.concat(formattedMessages, "\n")

	-- Find chat channel --
	local channels = TextChatService:FindFirstChild("TextChannels")

	local channel: TextChannel? = nil

	if channels then
		local candidate = channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral")

		if candidate and candidate:IsA("TextChannel") then
			channel = candidate
		end
	end

	-- Display feedback --
	if channel then
		channel:DisplaySystemMessage(formattedText, "BoardBanditsEventFeedback")
	else
		print(formattedText)
	end
end

-- Events --
feedback.OnClientEvent:Connect(function(messages: { string })
	DisplayFeedback(messages)
end)
