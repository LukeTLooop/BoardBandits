--!strict
-- Prompt Visibility Controller --

-- Services --
local Players = game:GetService("Players")

-- Player --
local plr = Players.LocalPlayer
assert(plr ~= nil, "PromptVisibilityController must be run on client!")

-- Helper Functions --
local function updatePrompt(
	prompt: ProximityPrompt
): ()
	-- Normal prompts have no visibility rules
	local access = prompt:GetAttribute("PromptAccess")
	if access == nil or typeof(access) ~= "string" then return end
	
	local claimedFactoryId = plr:GetAttribute("ClaimedFactoryId")
	if typeof(claimedFactoryId) ~= "string" then return end
	
	local hasFactory = typeof(claimedFactoryId) == "string"
	
	local ownerUserId = prompt:GetAttribute("OwnerUserId")
	if typeof(ownerUserId) ~= "number" then return end
	
	-- Claim factory
	if access == "ClaimFactory" then
		prompt.Enabled = not hasFactory
	-- Owner management
	elseif access == "Owner" then
		prompt.Enabled = ownerUserId == plr.UserId
	-- Theft
	elseif access == "Steal" then
		prompt.Enabled = ownerUserId ~= plr.UserId
	end
end

local function registerPrompt(
	prompt: ProximityPrompt
): ()
	prompt.ClickablePrompt = false

	updatePrompt(prompt)
	
	prompt:GetAttributeChangedSignal("PromptAccess"):Connect(function()
		updatePrompt(prompt)
	end)
	
	prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		updatePrompt(prompt)
	end)
end

local function refreshAllPrompts(): ()
	for _, descendant in workspace:GetDescendants() do
		if not descendant:IsA("ProximityPrompt") then continue end
		
		updatePrompt(descendant)
	end
end

-- Register Prompts --
for _, descendant in workspace:GetDescendants() do
	if descendant:IsA("ProximityPrompt") then
		registerPrompt(descendant)
	end
end

workspace.DescendantAdded:Connect(function(descendant: Instance)
	if descendant:IsA("ProximityPrompt") then
		registerPrompt(descendant)
	end
end)

-- Refresh Prompts --
plr:GetAttributeChangedSignal("ClaimedFactoryId"):Connect(function()
	refreshAllPrompts()
end)

return {}
