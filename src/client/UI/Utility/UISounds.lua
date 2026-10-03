--!strict
-- UI Sounds Utility

-- Services --
local SoundService = game:GetService("SoundService")

-- Utility --
local UISounds = {}

local UPGRADE_SOUND_ID = "rbxassetid://9116394545"
local TIER_UNLOCK_SOUND_ID = "rbxassetid://9116395089"

-- Setup --
local folder = Instance.new("Folder")
folder.Name = "UISounds"
folder.Parent = SoundService

local upgradeSound = Instance.new("Sound")
upgradeSound.Name = "WorkerUpgrade"
upgradeSound.SoundId = UPGRADE_SOUND_ID
upgradeSound.Volume = 0.55
upgradeSound.Parent = folder

local unlockSound = Instance.new("Sound")
unlockSound.Name = "WorkerTierUnlock"
unlockSound.SoundId = TIER_UNLOCK_SOUND_ID
unlockSound.Volume = 0.7
unlockSound.Parent = folder

function UISounds.PlayWorkerUpgrade(unlockedProductionTier: boolean): ()
	local sound = if unlockedProductionTier then unlockSound else upgradeSound
	sound.TimePosition = 0
	sound:Play()
end

return UISounds
