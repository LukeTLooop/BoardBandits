--!strict
-- Prompt Visibility Controller --

-- Services --
local Players = game:GetService("Players")

-- Player --
local plr = Players.LocalPlayer

-- Helper Functions --
local function updatePrompt(prompt: ProximityPrompt): ()
	-- Normal prompts have no visibility rules
	local access = prompt:GetAttribute("PromptAccess")
	if typeof(access) ~= "string" then
		return
	end

	local claimedFactoryId = plr:GetAttribute("ClaimedFactoryId")
	local hasFactory = typeof(claimedFactoryId) == "string"

	-- Claim factory
	if access == "ClaimFactory" then
		local claimPart = prompt.Parent
		if not claimPart then
			prompt.Enabled = false

			return
		end

		local factoryModel = claimPart.Parent
		if not factoryModel or not factoryModel:IsA("Model") then
			prompt.Enabled = false

			return
		end

		local factoryOwnerUserId = factoryModel:GetAttribute("OwnerUserId")
		local factoryClaimed = typeof(factoryOwnerUserId) == "number"

		prompt.Enabled = not hasFactory and not factoryClaimed

		return
	end

	-- Remaining access types require ownership data
	local ownerUserId = prompt:GetAttribute("OwnerUserId")
	if typeof(ownerUserId) ~= "number" then
		prompt.Enabled = false

		return
	end

	-- Owner management
	if access == "Owner" then
		prompt.Enabled = hasFactory and ownerUserId == plr.UserId

		return
	end

	-- Theft
	if access == "Steal" then
		prompt.Enabled = hasFactory and ownerUserId ~= plr.UserId

		return
	end
end

-- Register prompt
local function registerPrompt(prompt: ProximityPrompt): ()
	prompt.ClickablePrompt = false

	updatePrompt(prompt)

	prompt:GetAttributeChangedSignal("PromptAccess"):Connect(function()
		updatePrompt(prompt)
	end)

	prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		updatePrompt(prompt)
	end)
end

-- Refresh
local function refreshAllPrompts(): ()
	for _, descendant in workspace:GetDescendants() do
		if not descendant:IsA("ProximityPrompt") then
			continue
		end

		updatePrompt(descendant)
	end
end

-- Register prompts
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
