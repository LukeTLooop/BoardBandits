--!strict
-- Number Format Utility

-- Utility --
local NumberFormatUtil = {}

type SuffixDefinition = {
	Threshold: number,
	Suffix: string,
}

local SUFFIXES: { SuffixDefinition } = {
	{ Threshold = 1e33, Suffix = "Dc" },
	{ Threshold = 1e30, Suffix = "No" },
	{ Threshold = 1e27, Suffix = "Oc" },
	{ Threshold = 1e24, Suffix = "Sp" },
	{ Threshold = 1e21, Suffix = "Sx" },
	{ Threshold = 1e18, Suffix = "Qi" },
	{ Threshold = 1e15, Suffix = "Qa" },
	{ Threshold = 1e12, Suffix = "T" },
	{ Threshold = 1e9, Suffix = "B" },
	{ Threshold = 1e6, Suffix = "M" },
	{ Threshold = 1e3, Suffix = "K" },
}

function NumberFormatUtil.Format(value: number): string
	local absolute = math.abs(value)

	for _, entry in SUFFIXES do
		local threshold = entry.Threshold
		local suffix = entry.Suffix

		if absolute >= threshold then
			local scaled = value / threshold

			if math.abs(scaled) >= 100 then
				return string.format("%.0f%s", scaled, suffix)
			elseif math.abs(scaled) >= 10 then
				return string.format("%.1f%s", scaled, suffix)
			else
				return string.format("%.2f%s", scaled, suffix)
			end
		end
	end

	return tostring(math.floor(value))
end

return NumberFormatUtil
