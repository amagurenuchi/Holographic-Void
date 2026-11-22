-- Native ISOR Celestial estimator for the theme Dan calculator.
-- Calibration profiles: Dan-Overlay config/celestial_profiles.json
-- https://github.com/acarranzao1a-png/Dan-Overlay
HV = HV or {}

local celestialProfiles = {
	["Beginner"] = {
		["I"] = {mean=0.3521,jack=nil,speed=nil,stamina=nil,tech=0.3521},
		["II"] = {mean=0.4778,jack=nil,speed=nil,stamina=nil,tech=0.4778},
		["III"] = {mean=1.1373,jack=nil,speed=nil,stamina=nil,tech=1.1373},
		["IV"] = {mean=1.864,jack=nil,speed=nil,stamina=nil,tech=1.864},
		["V"] = {mean=2.1939,jack=nil,speed=nil,stamina=nil,tech=2.1939}
	},
	["Intermediate"] = {
		["I"] = {mean=2.3688,jack=nil,speed=nil,stamina=nil,tech=2.3688},
		["II"] = {mean=2.7081,jack=2.7967,speed=nil,stamina=nil,tech=2.1528},
		["III"] = {mean=2.9057,jack=nil,speed=2.9057,stamina=2.8724,tech=3.631},
		["IV"] = {mean=3.2388,jack=3.0486,speed=nil,stamina=nil,tech=3.7676},
		["V"] = {mean=3.6187,jack=3.469,speed=nil,stamina=3.6187,tech=4.2963}
	},
	["Expert"] = {
		["I"] = {mean=3.768,jack=nil,speed=3.8478,stamina=3.6882,tech=nil},
		["II"] = {mean=4.3309,jack=4.1304,speed=nil,stamina=3.6289,tech=nil},
		["III"] = {mean=4.5624,jack=3.0951,speed=4.6468,stamina=nil,tech=nil},
		["IV"] = {mean=4.5416,jack=3.8645,speed=4.7518,stamina=nil,tech=4.3314},
		["V"] = {mean=4.6808,jack=4.6597,speed=4.702,stamina=5.4944,tech=nil}
	},
	["Mastery"] = {
		["I"] = {mean=5.1045,jack=4.9478,speed=5.2316,stamina=5.5663,tech=nil},
		["II"] = {mean=5.3629,jack=5.3149,speed=5.3629,stamina=5.4269,tech=4.9421},
		["III"] = {mean=5.7535,jack=5.7741,speed=5.6907,stamina=5.1821,tech=nil},
		["IV"] = {mean=5.7191,jack=5.6524,speed=5.7724,stamina=5.3931,tech=6.1456},
		["V"] = {mean=5.9995,jack=5.9995,speed=6.1113,stamina=6.024,tech=5.8842}
	},
	["Ascension"] = {
		["I"] = {mean=6.0801,jack=5.9512,speed=5.9928,stamina=nil,tech=6.2434},
		["II"] = {mean=6.5801,jack=6.5801,speed=6.4538,stamina=6.669,tech=nil},
		["III"] = {mean=6.8393,jack=6.331,speed=7.0912,stamina=nil,tech=6.8812},
		["IV"] = {mean=6.9687,jack=6.9359,speed=7.1789,stamina=6.9562,tech=nil},
		["V"] = {mean=7.3377,jack=7.2674,speed=7.1728,stamina=7.3377,tech=7.5575}
	},
	["Transcendence"] = {
		["I"] = {mean=7.4964,jack=7.4623,speed=7.2348,stamina=7.4442,tech=7.5486},
		["II"] = {mean=7.8092,jack=7.7266,speed=nil,stamina=8.1408,tech=7.8092},
		["III"] = {mean=8.03,jack=8.1206,speed=7.829,stamina=8.0896,tech=8.0278},
		["IV"] = {mean=8.3215,jack=8.223,speed=nil,stamina=8.2926,tech=8.3929},
		["V"] = {mean=8.5645,jack=8.3699,speed=nil,stamina=8.7317,tech=8.4411}
	},
	["Singularity"] = {
		["I"] = {mean=8.8056,jack=8.8264,speed=8.9994,stamina=8.9081,tech=8.6619},
		["II"] = {mean=8.9126,jack=8.9126,speed=9.1579,stamina=8.8426,tech=8.6205},
		["III"] = {mean=9.4519,jack=9.466,speed=nil,stamina=9.5368,tech=9.3209},
		["IV"] = {mean=9.8404,jack=9.8187,speed=nil,stamina=9.8355,tech=9.8412},
		["V"] = {mean=10.0878,jack=10.2698,speed=nil,stamina=10.1021,tech=10.0276}
	}
}

local celestialTiers = {"Beginner", "Intermediate", "Expert", "Mastery", "Ascension", "Transcendence", "Singularity"}
local celestialCategories = {"I", "II", "III", "IV", "V"}
local familyRole = {jack = "jack", speed = "speed", stamina = "stamina", tech = "tech"}
local celestialPalettes = {
	Beginner = {"#8A82FF", "#C8C5FF"},
	Intermediate = {"#4CAF50", "#B2DFB4"},
	Expert = {"#FFC107", "#FFEB96"},
	Mastery = {"#FF7043", "#FFC8AF"},
	Ascension = {"#E53935", "#FFA09E"},
	Transcendence = {"#AB47BC", "#E6B4EE"},
	Singularity = {"#DCDCDC", "#FFFFFF"},
}
local celestialTierShort = {
	Beginner = "Beg", Intermediate = "Int", Expert = "Exp", Mastery = "Mas",
	Ascension = "Asc", Transcendence = "Tra", Singularity = "Sin",
}

local function celestialClamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function getCelestialRuler(role)
	local means = {}
	for _, tier in ipairs(celestialTiers) do
		for _, category in ipairs(celestialCategories) do
			local slot = celestialProfiles[tier][category]
			local mean = role and tonumber(slot[role]) or nil
			mean = mean or slot.mean
			if #means > 0 and mean <= means[#means] then mean = means[#means] + 0.001 end
			means[#means + 1] = mean
		end
	end
	return means
end

function HV.EstimateCelestialFromISORSR(modulatedSR, role)
	local sr = tonumber(modulatedSR)
	if not sr or sr <= 0 then return nil end
	role = familyRole[role]
	local means = getCelestialRuler(role)
	local boundaries = {}
	for i, mean in ipairs(means) do
		local lower = i > 1 and (means[i - 1] + mean) / 2 or mean - (means[2] - mean) / 2
		local upper = i < #means and (mean + means[i + 1]) / 2 or mean + (mean - means[i - 1]) / 2
		boundaries[i] = {lower, upper}
	end
	local index, position
	if sr < boundaries[1][1] then
		index, position = 1, 0
	elseif sr >= boundaries[#means][2] then
		index, position = #means, 0.99
	else
		for i, boundary in ipairs(boundaries) do
			if sr >= boundary[1] and sr < boundary[2] then
				index = i
				position = (sr - boundary[1]) / math.max(boundary[2] - boundary[1], 0.000001)
				break
			end
		end
	end
	if not index then return nil end
	position = celestialClamp(position, 0, 0.999)
	local dp = index + position
	local tierIndex = math.floor((index - 1) / 5) + 1
	local categoryIndex = (index - 1) % 5 + 1
	local tier, category = celestialTiers[tierIndex], celestialCategories[categoryIndex]
	local sublevel = position < 0.20 and "Low" or position < 0.40 and "Mid-Low"
		 or position < 0.60 and "Mid" or position < 0.80 and "Mid-High" or "High"
	local confidence = math.max(0.1, math.min(1, 0.5 * (1 + math.cos(math.pi * (position - 0.5) * 2))))
	return {celestial = true, dan = category, danLabel = celestialTierShort[tier] .. " " .. category,
		tierShort = celestialTierShort[tier], tier = tier, category = category,
		group = tier, dp = dp, position = position, sublevel = sublevel, confidence = confidence, mod_sr = sr}
end

function HV.GetCelestialDanGradient(tier)
	local palette = celestialPalettes[tier]
	if not palette then return nil end
	return {color(palette[1]), color(palette[2])}
end

function HV.GetDanCalculatorEstimate(reformEstimate)
	if type(reformEstimate) ~= "table" then return nil end
	local mode = ThemePrefs and ThemePrefs.Get and ThemePrefs.Get("HV_DanCalculatorMode")
	if mode == "Celestial" then
		return HV.EstimateCelestialFromISORSR(reformEstimate.mod_sr, reformEstimate.sk_key)
	end
	return reformEstimate
end

function HV.GetDanCalculatorText(estimate)
	if type(estimate) ~= "table" then return "" end
	local label = estimate.danLabel or estimate.dan or ""
	if label == "∞" or label == "0" or estimate.sublevel == "" then return label end
	return label .. " " .. tostring(estimate.sublevel or "")
end
