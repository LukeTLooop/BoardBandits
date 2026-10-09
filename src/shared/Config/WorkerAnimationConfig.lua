--!strict
-- Worker Animation Config

export type AnimationDefinition = {
	Id: string,
	Looped: boolean,
	Priority: Enum.AnimationPriority,
}

export type AnimationSet = {
	Idle: AnimationDefinition?,
	Working: AnimationDefinition?,
	Carried: AnimationDefinition?,
}

local WorkerAnimationConfig: { [string]: AnimationSet } = {
	Gloop = {
		Idle = {
			Id = "rbxassetid://139190214155601",
			Looped = true,
			Priority = Enum.AnimationPriority.Idle,
		},

		Working = {
			Id = "rbxassetid://104117012145499",
			Looped = true,
			Priority = Enum.AnimationPriority.Action,
		},

		Carried = {
			Id = "rbxassetid://104117012145499",
			Looped = true,
			Priority = Enum.AnimationPriority.Action2,
		},
	},

	Bonk = {
		Idle = {
			Id = "rbxassetid://139190214155601",
			Looped = true,
			Priority = Enum.AnimationPriority.Idle,
		},

		Working = {
			Id = "rbxassetid://104117012145499",
			Looped = true,
			Priority = Enum.AnimationPriority.Action,
		},

		Carried = {
			Id = "rbxassetid://104117012145499",
			Looped = true,
			Priority = Enum.AnimationPriority.Action2,
		},
	},

	Squish = {
		Idle = {
			Id = "rbxassetid://139190214155601",
			Looped = true,
			Priority = Enum.AnimationPriority.Idle,
		},

		Working = {
			Id = "rbxassetid://104117012145499",
			Looped = true,
			Priority = Enum.AnimationPriority.Action,
		},

		Carried = {
			Id = "rbxassetid://104117012145499",
			Looped = true,
			Priority = Enum.AnimationPriority.Action2,
		},
	},

	Plank = {
		Idle = {
			Id = "rbxassetid://139190214155601",
			Looped = true,
			Priority = Enum.AnimationPriority.Idle,
		},

		Working = {
			Id = "rbxassetid://104117012145499",
			Looped = true,
			Priority = Enum.AnimationPriority.Action,
		},

		Carried = {
			Id = "rbxassetid://104117012145499",
			Looped = true,
			Priority = Enum.AnimationPriority.Action2,
		},
	},

	Patch = {
		Idle = {
			Id = "rbxassetid://139190214155601",
			Looped = true,
			Priority = Enum.AnimationPriority.Idle,
		},

		Working = {
			Id = "rbxassetid://104117012145499",
			Looped = true,
			Priority = Enum.AnimationPriority.Action,
		},

		Carried = {
			Id = "rbxassetid://104117012145499",
			Looped = true,
			Priority = Enum.AnimationPriority.Action2,
		},
	},
}

return WorkerAnimationConfig
