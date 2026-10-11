--!strict
-- Environment Service

-- Services --
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")

-- Managers --
local GameStateManager = require(ServerScriptService.Managers.GameStateManager)

-- Shared --
local PriorityState = require(ServerScriptService.Shared.PriorityState)

-- Types --
type LightingProfile = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	FogColor: Color3,
	FogStart: number,
	FogEnd: number,
}

-- Constants --
local DEFAULT_PROFILE: LightingProfile = {
	ClockTime = Lighting.ClockTime,
	Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	FogColor = Lighting.FogColor,
	FogStart = Lighting.FogStart,
	FogEnd = Lighting.FogEnd,
}

local PRESETS: { [string]: LightingProfile } = {
	Halloween = {
		ClockTime = 20,
		Brightness = 1,
		Ambient = Color3.fromRGB(75, 50, 90),
		OutdoorAmbient = Color3.fromRGB(65, 45, 75),
		FogColor = Color3.fromRGB(65, 45, 80),
		FogStart = 0,
		FogEnd = 450,
	},

	Storm = {
		ClockTime = 16,
		Brightness = 1,
		Ambient = Color3.fromRGB(90, 95, 110),
		OutdoorAmbient = Color3.fromRGB(80, 85, 100),
		FogColor = Color3.fromRGB(100, 105, 120),
		FogStart = 0,
		FogEnd = 600,
	},
}

-- Service --
local EnvironmentService = {}

-- State --
local originalSky = Lighting:FindFirstChildOfClass("Sky")
local originalAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")

local skyTemplate: Instance? = if originalSky then originalSky:Clone() else nil
local atmosphereTemplate: Instance? = if originalAtmosphere then originalAtmosphere:Clone() else nil

-- Internal --
local function ValidatePreset(name: string)
	assert(name == "Default" or PRESETS[name] ~= nil, `Unknown environment preset: {name}`)
end

local function ApplyPreset(name: string)
	local profile = if name == "Default" then DEFAULT_PROFILE else PRESETS[name]
	assert(profile, "Environment profile not found!")

	-- Lighting
	Lighting.ClockTime = profile.ClockTime
	Lighting.Brightness = profile.Brightness
	Lighting.Ambient = profile.Ambient
	Lighting.OutdoorAmbient = profile.OutdoorAmbient
	Lighting.FogColor = profile.FogColor
	Lighting.FogStart = profile.FogStart
	Lighting.FogEnd = profile.FogEnd

	-- Skybox / Atmosphere
	local sourceSky = skyTemplate
	local sourceAtmosphere = atmosphereTemplate

	if name ~= "Default" then
		local presetsFolder = ServerStorage:FindFirstChild("EnvironmentPresets")
		local presetFolder = if presetsFolder then presetsFolder:FindFirstChild(name) else nil

		if presetFolder and presetFolder:IsA("Folder") then
			sourceSky = presetFolder:FindFirstChildOfClass("Sky") or skyTemplate
			sourceAtmosphere = presetFolder:FindFirstChildOfClass("Atmosphere") or atmosphereTemplate
		end
	end

	-- Remove currently applied environment objects
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	-- Apply selected environment objects
	if sourceSky then
		sourceSky:Clone().Parent = Lighting
	end

	if sourceAtmosphere then
		sourceAtmosphere:Clone().Parent = Lighting
	end
end

-- Game State --
GameStateManager.RegisterState("Environment/CurrentPreset", "Default")

local presetLayer = PriorityState.new("Default", function(newPreset: string, _oldPreset: string)
	ApplyPreset(newPreset)
	GameStateManager.SetState("Environment/CurrentPreset", newPreset)
end)

-- Methods --
function EnvironmentService.GetCurrentPreset(): string
	return presetLayer.Get()
end

function EnvironmentService.SetBasePreset(name: string)
	ValidatePreset(name)
	presetLayer.SetBase(name)
end

function EnvironmentService.SetOverride(owner: string, preset: string, priority: number?)
	ValidatePreset(preset)
	presetLayer.SetOverride(owner, preset, priority)
end

function EnvironmentService.RemoveOverride(owner: string): boolean
	return presetLayer.RemoveOverride(owner)
end

return EnvironmentService
