--!strict
-- Stats Service

local ServerScriptService = game:GetService("ServerScriptService")

local GameEvents = require(ServerScriptService.Framework.GameEvents)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local StatsService = {}
StatsService.__index = StatsService

type StatsServiceData = {
	PlayerData: PlayerDataService.PlayerDataService,
	Started: boolean,
}

export type StatsService = typeof(setmetatable({} :: StatsServiceData, StatsService))

function StatsService.new(
	playerData: PlayerDataService.PlayerDataService
): StatsService
	local data: StatsServiceData = {
		PlayerData = playerData,
		
		Started = false,
	}
	
	return setmetatable(
		data,
		StatsService
	)
end

function StatsService.Start(
	self: StatsService
): ()
	if self.Started then return end
	self.Started = true
	
	-- Worker purchased
	GameEvents.WorkerPurchased:Connect(function(
		plr,
		worker
	)
		local profile = self.PlayerData:GetProfile(plr)
		if not profile then return end
		
		profile.Stats.WorkersPurchased += 1
	end)
	
	-- Worker stolen
	GameEvents.WorkerStolen:Connect(function(
		thief,
		originalOwnerUserId,
		worker
	)
		local thiefProfile = self.PlayerData:GetProfile(thief)
		if thiefProfile then
			thiefProfile.Stats.WorkersStolen += 1
		end
		
		local victimProfile = self.PlayerData:GetProfileByUserId(originalOwnerUserId)
		if victimProfile then
			victimProfile.Stats.WorkersLost += 1
		end
	end)
	
	-- Production
	GameEvents.ItemProduced:Connect(function(
		ownerUserId: number,
		factoryId: string,
		itemId: string,
		amount: number
	)
		local profile = self.PlayerData:GetProfileByUserId(ownerUserId)
		if profile then
			profile.Stats.ItemsProduced += amount
		end
	end)
	
	-- Sales
	GameEvents.ItemSold:Connect(function(
		ownerUserId: number,
		itemId: string,
		cashEarned: number
	)
		local profile = self.PlayerData:GetProfileByUserId(ownerUserId)
		if not profile then return end
		
		profile.Stats.ItemsSold += 1
	end)
end

return StatsService
