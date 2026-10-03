--!strict
-- Player Data Store

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local PlayerDataSchema = require(ServerScriptService.Data.PlayerDataSchema)

local PlayerDataStore = {}

-- Configuration --
local STORE_NAME =
	if RunService:IsStudio()
		then "BoardBandits_PlayerData_DEV_v1"
		else "BoardBandits_PlayerData_v1"

local SESSION_TIMEOUT = 100
local MAX_ATTEMPTS = 5

local Store = DataStoreService:GetDataStore(STORE_NAME)

-- Utility --
local function getKey(
	userId: number
): string
	return `Player_{userId}`
end

local function getRetryDelay(
	attempt: number
): number
	return math.min(
		2 ^ (attempt - 1),
		8
	)
end

-- Load + acquire session --
function PlayerDataStore.Load(
	userId: number
): (
	PlayerDataTypes.PlayerData?,
	string?
)
	local key = getKey(userId)
	
	for attempt = 1, MAX_ATTEMPTS do
		local sessionLocked = false
		
		local success, result = pcall(function()
			return Store:UpdateAsync(key, function(
				current: any
			): any
				local now = os.time()
				
				local envelope: any
				
				-- New profile
				if current == nil then
					envelope = {
						Data = PlayerDataSchema.CreateDefault(),
						Session = nil,
					}
				-- Normal envelope
				elseif typeof(current) == "table" and current.Data ~= nil then
					envelope = current
				-- Compatability with old raw profiles
				else
					envelope = {
						Data = current,
						Session = nil,
					}
				end
				
				-- Session lock
				local session = envelope.Session
				
				if type(session) == "table" then
					local jobId = session.JobId
					local updatedAt = session.UpdatedAt
					
					if type(jobId) == "string" and
						jobId ~= game.JobId and
						type(updatedAt) ~= "number" and
						now - updatedAt < SESSION_TIMEOUT then
						sessionLocked = true
						return nil
					end
				end
				
				-- Reconcile/migrate
				envelope.Data = PlayerDataSchema.Reconcile(envelope.Data)
				
				-- Claim session
				envelope.Session = {
					JobId = game.JobId,
					PlaceId = game.PlaceId,
					UpdatedAt = now,
				}
				
				return envelope
			end)
		end)
		
		if success then
			if sessionLocked then
				if attempt < MAX_ATTEMPTS then
					task.wait(getRetryDelay(attempt))
					
					continue
				end
				
				return nil, "Profile is locked by another server!"
			end
			
			if type(result) ~= "table" or type(result.Data) ~= "table" then
				return nil, "DataStore returned malformed profile data!"
			end
			
			local profile = PlayerDataSchema.Reconcile(result.Data)
			return profile, nil
		end
		
		warn(
			`[DATA] Load attempt {attempt} failed for {userId}:`,
			result
		)
		
		if attempt < MAX_ATTEMPTS then
			task.wait(getRetryDelay(attempt))
		end
	end
	
	return nil, "DataStore load failed after retries!"
end

-- Save --
function PlayerDataStore.Save(
	userId: number,
	profile: PlayerDataTypes.PlayerData,
	releaseSession: boolean
): (boolean, string?)
	local key = getKey(userId)
	local snapshot = PlayerDataSchema.CreateSaveSnapshot(profile)
	
	for attempt = 1, MAX_ATTEMPTS do
		local sessionMismatch = false
		
		local success, result = pcall(function()
			return Store:UpdateAsync(key, function(
				current: any
			): any
				local envelope: any
				
				if current == nil then
					envelope = {
						Data = nil,
						Session = nil,
					}
				elseif type(current) == "table" and current.Data ~= nil then
					envelope = current
				else
					envelope = {
						Data = current,
						Session = nil,
					}
				end
				
				-- Never overwrite another live server
				local session = envelope.Session
				
				if type(session) == "table" then
					local jobId = session.JobId
					
					if type(jobId) == "string" and jobId ~= game.JobId then
						sessionMismatch = true
						return nil
					end
				end
				
				-- Save profile
				envelope.Data = snapshot
				
				if releaseSession then
					envelope.Session = nil
				else
					envelope.Session = {
						JobId = game.JobId,
						PlaceId = game.PlaceId,
						UpdatedAt = os.time(),
					}
				end
				
				return envelope
			end)
		end)
		
		if success then
			if sessionMismatch then
				return false, "Session ownership was lost!"
			end
			
			if result == nil then
				return false, "Save was cancelled!"
			end
			
			return true, nil
		end
		
		warn(
			`[DATA] Save attempt {attempt} failed for {userId}:`,
			result
		)
		
		if attempt < MAX_ATTEMPTS then
			task.wait(getRetryDelay(attempt))
		end
	end
	
	return false, "DataStore save failed after retries!"
end

return PlayerDataStore
