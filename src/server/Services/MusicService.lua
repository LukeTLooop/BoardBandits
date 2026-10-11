--!strict
-- Music Service

-- Services --
local ServerScriptService = game:GetService("ServerScriptService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

-- Managers --
local GameStateManager = require(ServerScriptService.Managers.GameStateManager)

-- Shared --
local PriorityState = require(ServerScriptService.Shared.PriorityState)

-- Constants --
local TRANSITION_TIME = 1
local NO_TRACK = "None"

-- Service --
local MusicService = {}

-- Folders --
local tracksFolder = SoundService:FindFirstChild("MusicTracks")
if not tracksFolder then
	tracksFolder = Instance.new("Folder")
	tracksFolder.Name = "MusicTracks"
	tracksFolder.Parent = SoundService
end

assert(tracksFolder:IsA("Folder", "MusicTracks must be a Folder!"))

local runtimeFolder = Instance.new("Folder")
runtimeFolder.Name = "RuntimeMusic"
runtimeFolder.Parent = SoundService

-- State --
local activeSound: Sound? = nil

-- Internal --
local function GetTrackTemplate(name: string): Sound
	local sound = tracksFolder:FindFirstChild(name)
	assert(sound and sound:IsA("Sound"), `Music track not found: {name}`)

	return sound
end

local function ValidateTrack(name: string)
	if name ~= NO_TRACK then
		GetTrackTemplate(name)
	end
end

local function TransitionTo(name: string)
	local outgoing = activeSound
	local incoming: Sound? = nil

	if name ~= NO_TRACK then
		local template = GetTrackTemplate(name)
		local sound = template:Clone()

		local targetVolume = sound.Volume

		sound.Name = "CurrentMusic"
		sound.Volume = 0
		sound.Looped = true
		sound.Parent = runtimeFolder

		sound:Play()

		local fadeIn = TweenService:Create(sound, TweenInfo.new(TRANSITION_TIME), {
			Volume = targetVolume,
		})

		fadeIn:Play()
		incoming = sound
	end

	activeSound = incoming

	if outgoing then
		local fadeOut = TweenService:Create(outgoing, TweenInfo.new(TRANSITION_TIME), {
			Volume = 0,
		})

		fadeOut.Completed:Once(function()
			outgoing:Stop()
			outgoing:Destroy()
		end)

		fadeOut:Play()
	end
end

-- Game State --
GameStateManager.RegisterState("Music/CurrentTrack", NO_TRACK)

local trackLayer = PriorityState.new(NO_TRACK, function(newTrack: string, _oldTrack: string)
	TransitionTo(newTrack)

	GameStateManager.SetState("Music/CurrentTrack", newTrack)
end)

-- Methods --
function MusicService.GetCurrentTrack(): string
	return trackLayer.Get()
end

function MusicService.SetBaseTrack(name: string)
	ValidateTrack(name)
	trackLayer.SetBase(name)
end

function MusicService.SetOverride(owner: string, trackName: string, priority: number?)
	ValidateTrack(trackName)
	trackLayer.SetOverride(owner, trackName, priority)
end

function MusicService.RemoveOverride(owner: string): boolean
	return trackLayer.RemoveOverride(owner)
end

return MusicService
