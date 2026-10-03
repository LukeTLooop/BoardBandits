--!strict
-- Economy service

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local EconomyService = {}
EconomyService.__index = EconomyService

type EconomyServiceData = {
	PlayerData: PlayerDataService.PlayerDataService
}

export type EconomyService = typeof(setmetatable({} :: EconomyServiceData, EconomyService))

function EconomyService.new(
	playerData: PlayerDataService.PlayerDataService
): EconomyService
	local data: EconomyServiceData = {
		PlayerData = playerData,
	}
	
	return setmetatable(data, EconomyService)
end

function EconomyService.GetCash(
	self: EconomyService,
	plr: Player
): number
	local profile = self.PlayerData:RequireProfile(plr)
	
	return profile.Cash
end

function EconomyService.AddCash(
	self: EconomyService,
	plr: Player,
	amount: number
): number
	assert(amount >= 0, "Cash amount cannot be negative!")
	
	local profile = self.PlayerData:RequireProfile(plr)
	profile.Cash += amount
	
	return profile.Cash
end

function EconomyService.SpendCash(
	self: EconomyService,
	plr: Player,
	amount: number
): boolean
	if amount < 0 then return false end
	
	local profile = self.PlayerData:RequireProfile(plr)
	
	if profile.Cash < amount then return false end
	profile.Cash -= amount
	
	return true
end

return EconomyService
