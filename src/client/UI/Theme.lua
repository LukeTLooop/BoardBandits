--!strict
-- UI Theme

local Theme = {}

Theme.Color = {
	Background = Color3.fromRGB(21, 23, 29),
	Surface = Color3.fromRGB(34, 37, 45),
	SurfaceRaised = Color3.fromRGB(48, 51, 60),
	SurfaceHover = Color3.fromRGB(44, 48, 58),
	SurfaceSelected = Color3.fromRGB(50, 54, 65),
	Cream = Color3.fromRGB(246, 239, 219),
	SurfaceLight = Color3.fromRGB(247, 241, 225),

	Ink = Color3.fromRGB(24, 24, 25),
	Text = Color3.fromRGB(247, 247, 242),
	Muted = Color3.fromRGB(170, 173, 183),
	MutedText = Color3.fromRGB(165, 169, 180),
	Disabled = Color3.fromRGB(74, 77, 84),
	DisabledText = Color3.fromRGB(137, 140, 148),

	Yellow = Color3.fromRGB(255, 194, 38),
	Orange = Color3.fromRGB(255, 116, 435),

	Success = Color3.fromRGB(126, 225, 73),
	Danger = Color3.fromRGB(236, 66, 55),

	Bearings = Color3.fromRGB(73, 151, 255),
	Trucks = Color3.fromRGB(255, 127, 47),
	Wheels = Color3.fromRGB(55, 211, 185),
	Decks = Color3.fromRGB(96, 157, 79),
	Assembler = Color3.fromRGB(159, 91, 255),
}

Theme.Corner = {
	Small = UDim.new(0, 6),
	Medium = UDim.new(0, 10),
	Large = UDim.new(0, 16),
}

Theme.Stroke = {
	Thin = 2,
	Thick = 4,
}

Theme.RoleColors = {
	Bearings = Theme.Color.Bearings,
	Trucks = Theme.Color.Trucks,
	Wheels = Theme.Color.Wheels,
	Decks = Theme.Color.Decks,
	Assembler = Theme.Color.Assembler,
}

return Theme
