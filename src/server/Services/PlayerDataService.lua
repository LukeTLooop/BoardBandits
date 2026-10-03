--!strict
-- Player Data Service

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local PlayerDataSchema = require(ServerScriptService.Data.PlayerDataSchema)
local PlayerDataStore = require(ServerScriptService.Data.PlayerDataStore)

local GameEvents = require(ServerScriptService.Framework.GameEvents)

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

type PlayerDataServiceData = {
	Profiles: {
		[number]: PlayerDataTypes.PlayerData
	},
	
	LoadingProfiles: {
		[number]: boolean
	},
	
	UnloadingProfiles: {
		[number]: boolean
	},
	
	SavingProfiles: {
		[number]: boolean
	},
	
	AutosaveInterval: number,
	
	Started: boolean,
}

export type PlayerDataService = typeof(setmetatable({} :: PlayerDataServiceData, PlayerDataService))

function PlayerDataService.new(): PlayerDataService
	local data: PlayerDataServiceData = {
		Profiles = {},
		
		LoadingProfiles = {},
		UnloadingProfiles = {},
		SavingProfiles = {},
		AutosaveInterval = 60,
		
		Started = false,
	}
	
	return setmetatable(data, PlayerDataService)
end

-- Start --
function PlayerDataService.Start(
	self: PlayerDataService
): ()
	if self.Started then return end
	self.Started = true

	Players.PlayerAdded:Connect(function(plr: Player)
		task.spawn(function()
			self:LoadProfile(plr)
		end)
	end)

	Players.PlayerRemoving:Connect(function(plr: Player)
		task.spawn(function()
			self:UnloadProfile(plr)
		end)
	end)
	
	-- Players already existing
	for _, plr in Players:GetPlayers() do
		task.spawn(function()
			self:LoadProfile(plr)
		end)
	end
	
	self:StartAutosave()
	
	-- Server shutdown
	game:BindToClose(function()
		self.Started = false
		
		local remaining = 0
		local finished = Instance.new("BindableEvent")
		
		for userId in self.Profiles do
			remaining += 1
			
			task.spawn(function()
				self:SaveProfileByUserId(
					userId,
					true
				)
				
				remaining -= 1
				
				if remaining == 0 then
					finished:Fire()
				end
			end)
		end
		
		if remaining > 0 then
			finished.Event:Wait()
		end
		
		finished:Destroy()
	end)
end

-- Profiles --
function PlayerDataService.CreateProfile(
	self: PlayerDataService,
	plr: Player
): PlayerDataTypes.PlayerData
	local existing = self.Profiles[plr.UserId]
	if existing then
		return existing
	end
	
	local profile = PlayerDataSchema.CreateDefault()
	
	self.Profiles[plr.UserId] = profile
	
	-- Broadcast readiness
	GameEvents.ProfileLoaded:Fire(
		plr,
		profile
	)
	
	return profile
end

function PlayerDataService.LoadProfile(
	self: PlayerDataService,
	plr: Player
): ()
	local userId = plr.UserId
	if self:IsProfileLoaded(plr) then return end
	
	if self.LoadingProfiles[userId] then return end
	self.LoadingProfiles[userId] = true
	
	print(
		"[DATA] Loading profile:",
		plr.Name
	)
	
	local profile, loadError = PlayerDataStore.Load(userId)
	self.LoadingProfiles[userId] = nil
	
	-- Load failure
	if not profile then
		warn(
			"[DATA] Failed to load:",
			plr.Name,
			loadError
		)
		
		if plr.Parent == Players then
			plr:Kick(
				"Your data could not be loaded safely. Please rejoin."
			)
		end
		
		return
	end
	
	-- Player left while DataStore was loading
	if plr.Parent ~= Players then
		PlayerDataStore.Save(
			userId,
			profile,
			true
		)
		
		return
	end
	
	-- Publish profile
	self.Profiles[userId] = profile
	
	print(
		"[DATA] Profile loaded:",
		plr.Name
	)
	
	GameEvents.ProfileLoaded:Fire(
		plr,
		profile
	)
end

function PlayerDataService.IsProfileLoaded(
	self: PlayerDataService,
	plr: Player
): boolean
	return self.Profiles[plr.UserId] ~= nil
end

function PlayerDataService.UnloadProfile(
	self: PlayerDataService,
	plr: Player
): ()
	local userId = plr.UserId
	
	if self.UnloadingProfiles[userId] then return end
	
	local profile = self.Profiles[userId]
	if not profile then return end
	
	self.UnloadingProfiles[userId] = true
	
	-- Give listeners final synchronous cleanup opportunity before snapshot
	GameEvents.ProfileRemoving:Fire(
		plr,
		profile
	)
	
	self:SaveProfileByUserId(
		userId,
		true
	)
	
	self.Profiles[userId] = nil
	self.UnloadingProfiles[userId] = nil
	
	print(
		"[DATA] Profile unloaded:",
		plr.Name
	)
end

function PlayerDataService.WaitForProfile(
	self: PlayerDataService,
	plr: Player,
	timeout: number?
): PlayerDataTypes.PlayerData?
	local startTime = os.clock()
	local maxWait = timeout or 15
	
	while plr.Parent == Players do
		local profile = self:GetProfile(plr)
		if profile then
			return profile
		end
		
		if os.clock() - startTime >= maxWait then
			warn(`Timed out waiting for profile for {plr.Name}`)
			
			return nil
		end
		
		task.wait()
	end
	
	return nil
end

function PlayerDataService.GetProfile(
	self: PlayerDataService,
	plr: Player
): PlayerDataTypes.PlayerData?
	return self.Profiles[plr.UserId]
end

function PlayerDataService.GetProfileByUserId(
	self: PlayerDataService,
	userId: number
): PlayerDataTypes.PlayerData?
	return self.Profiles[userId]
end

function PlayerDataService.RequireProfile(
	self: PlayerDataService,
	plr: Player
): PlayerDataTypes.PlayerData
	local profile = self:GetProfile(plr)
	assert(profile ~= nil, `No profile loaded for {plr.Name}`)
	
	return profile
end

function PlayerDataService.RequireProfileByUserId(
	self: PlayerDataService,
	userId: number
): PlayerDataTypes.PlayerData
	local profile = self:GetProfileByUserId(userId)
	assert(profile ~= nil, `No profile loaded for UserId {userId}`)
	
	return profile
end

function PlayerDataService.RemoveProfile(
	self: PlayerDataService,
	plr: Player
): ()
	local profile = self.Profiles[plr.UserId]
	if not profile then return end
	
	-- Other systems can react before removing
	GameEvents.ProfileRemoving:Fire(
		plr,
		profile
	)
	
	self.Profiles[plr.UserId] = nil
end

-- Save --
function PlayerDataService.SaveProfileByUserId(
	self: PlayerDataService,
	userId: number,
	releaseSession: boolean
): boolean
	-- Serialize saves for player
	while self.SavingProfiles[userId] do
		task.wait()
	end
	
	local profile = self.Profiles[userId]
	if not profile then
		return false
	end
	
	self.SavingProfiles[userId] = true
	
	local success, saveError = PlayerDataStore.Save(
		userId,
		profile,
		releaseSession
	)
	
	self.SavingProfiles[userId] = nil
	
	if not success then
		warn(
			"[DATA] Failed to save user",
			userId,
			saveError
		)
		
		return false
	end
	
	return true
end

-- Autosave --
function PlayerDataService.StartAutosave(
	self: PlayerDataService
): ()
	task.spawn(function()
		while self.Started do
			task.wait(self.AutosaveInterval)
			
			if not self.Started then break end
			
			for userId in self.Profiles do
				if self.UnloadingProfiles[userId] then continue end
				
				task.spawn(function()
					self:SaveProfileByUserId(
						userId,
						false
					)
				end)
				
				-- Spread requests slightly for each player
				task.wait(.1)
			end
		end
	end)
end

return PlayerDataService
