-- Native DanOverlay REFORM estimate from Etterna MinaCalc skillset MSDs.
-- Calculation and calibration data adapted from:
-- https://github.com/acarranzao1a-png/Dan-Overlay
-- Structural-feature adjustments are omitted because the theme consumes the
-- engine's existing per-chart MSDs rather than reparsing chart note data.

HV = HV or {}

local danOrder = {
	"1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th",
	"Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa"
}

-- Each band is {lower, center, upper, sample count, dispersion, weak-anchor}.
local thresholds = {
	jack = {
		{6.416, 8.020, 9.620, 2, 0.000, true}, {9.620, 11.220, 11.948, 2, 0.000, true},
		{10.172, 10.900, 11.940, 3, 0.320, false}, {11.940, 12.980, 13.708, 3, 0.960, false},
		{11.692, 12.420, 14.100, 2, 0.000, true}, {14.100, 15.780, 16.508, 2, 0.000, true},
		{16.332, 17.060, 19.315, 3, 0.920, false}, {19.315, 21.570, 22.298, 3, 1.450, false},
		{18.932, 19.660, 22.280, 2, 0.280, true}, {22.280, 24.900, 25.628, 1, 0.000, true},
		{23.392, 24.120, 25.663, 3, 0.735, false}, {25.663, 27.205, 27.933, 2, 0.775, true},
		{26.262, 26.990, 29.595, 3, 0.760, false}, {29.595, 32.200, 33.555, 2, 0.030, true},
		{33.555, 34.910, 35.638, 2, 0.000, true}, {33.462, 34.190, 37.675, 2, 0.220, true},
		{37.675, 41.160, 41.888, 1, 0.000, true}, {40.342, 41.070, 43.460, 1, 0.000, true},
		{43.460, 45.850, 46.870, 1, 0.000, true}, {46.870, 47.890, 57.468, 1, 0.000, true}
	},
	speed = {
		{10.408, 13.010, 13.549, 2, 0.000, true}, {12.961, 13.500, 14.925, 2, 0.000, true},
		{14.925, 16.350, 16.895, 2, 0.000, true}, {16.895, 17.440, 19.047, 2, 0.000, true},
		{19.047, 20.655, 21.425, 2, 0.305, true}, {21.425, 22.195, 22.734, 2, 0.355, true},
		{22.216, 22.755, 23.562, 2, 0.475, true}, {23.562, 24.370, 24.909, 2, 0.130, true},
		{24.286, 24.825, 25.364, 2, 0.275, true}, {24.131, 24.670, 26.325, 2, 0.290, true},
		{26.325, 27.980, 28.519, 2, 0.000, true}, {27.751, 28.290, 29.725, 4, 0.575, false},
		{29.725, 31.160, 31.699, 2, 0.000, true}, {31.531, 32.070, 34.440, 2, 0.000, true},
		{34.440, 36.810, 38.530, 2, 0.000, true}, {38.530, 40.250, 41.470, 1, 0.000, true},
		{41.470, 42.690, 43.229, 1, 0.000, true}, {42.031, 42.570, 43.109, 1, 0.000, true},
		{41.751, 42.290, 44.750, 1, 0.000, true}, {44.750, 47.210, 56.652, 1, 0.000, true}
	},
	stamina = {
		{11.064, 13.830, 14.648, 2, 0.000, true}, {14.409, 15.227, 16.045, 2, 0.000, true},
		{13.562, 14.380, 16.064, 2, 0.087, true}, {16.064, 17.747, 19.107, 2, 0.000, true},
		{19.107, 20.466, 21.284, 2, 0.000, true}, {21.006, 21.824, 22.642, 2, 0.000, true},
		{21.492, 22.310, 23.128, 2, 0.374, true}, {20.510, 21.328, 22.932, 3, 0.406, false},
		{22.932, 24.537, 25.355, 3, 0.580, false}, {21.615, 22.433, 23.916, 1, 0.000, true},
		{23.916, 25.399, 26.217, 2, 0.246, true}, {24.443, 25.261, 27.526, 2, 1.046, true},
		{27.526, 29.792, 30.610, 2, 0.122, true}, {29.795, 30.613, 32.018, 2, 0.105, true},
		{32.018, 33.423, 34.591, 1, 0.000, true}, {34.591, 35.759, 36.577, 1, 0.000, true},
		{34.580, 35.398, 37.681, 1, 0.000, true}, {37.681, 39.963, 44.015, 1, 0.000, true},
		{44.015, 48.067, 49.390, 1, 0.000, true}, {49.390, 50.713, 60.856, 1, 0.000, true}
	},
	tech = {
		{11.040, 13.800, 14.550, 2, 0.000, true}, {14.550, 15.300, 15.937, 2, 0.000, true},
		{14.793, 15.430, 16.608, 2, 0.000, true}, {16.608, 17.785, 18.450, 2, 0.615, true},
		{18.450, 19.115, 19.752, 2, 0.165, true}, {19.573, 20.210, 21.755, 2, 0.000, true},
		{21.755, 23.300, 23.937, 2, 0.000, true}, {23.388, 24.025, 24.938, 2, 0.005, true},
		{24.938, 25.850, 26.760, 2, 0.480, true}, {26.760, 27.670, 28.307, 1, 0.000, true},
		{27.048, 27.685, 28.322, 2, 0.485, true}, {25.493, 26.130, 27.820, 2, 0.710, true},
		{27.820, 29.510, 30.925, 3, 0.215, false}, {30.925, 32.340, 33.190, 2, 0.000, true},
		{33.190, 34.040, 34.965, 1, 0.000, true}, {34.965, 35.890, 37.175, 1, 0.000, true},
		{37.175, 38.460, 40.800, 1, 0.000, true}, {40.800, 43.140, 43.885, 1, 0.000, true},
		{43.885, 44.630, 46.350, 1, 0.000, true}, {46.350, 48.070, 57.684, 1, 0.000, true}
	}
}

local maxAnchors = {jack = 47.890, speed = 47.210, stamina = 50.713, tech = 48.070}
local roleOrder = {"jack", "speed", "tech", "stamina"}

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function round(value, places)
	local scale = 10 ^ (places or 0)
	return math.floor(value * scale + 0.5) / scale
end

local function danIndex(dan)
	for i, name in ipairs(danOrder) do
		if name == dan then return i - 1 end
	end
	return 0
end

local function bandPosition(value, lower, center, upper)
	if value <= center then
		return 0.5 * (value - lower) / math.max(center - lower, 0.001)
	end
	return 0.5 + 0.5 * (value - center) / math.max(upper - center, 0.001)
end

local function bandConfidence(value, lower, center, upper)
	local halfWidth = math.max((upper - lower) / 2, 0.001)
	return clamp(1 - math.abs(value - center) / halfWidth, 0, 1)
end

local function anchorQuality(sampleCount, dispersion, weak)
	if sampleCount < 2 or weak then return 0.65 end
	if dispersion > 3 then return 0.80 end
	return 1
end

local function lookupRole(value, role)
	local bands = thresholds[role]
	local containing = {}
	for index, band in ipairs(bands) do
		if band[1] <= value and value <= band[3] then
			containing[#containing + 1] = {index = index, band = band}
		end
	end

	local selected, overlap = nil, false
	if #containing > 0 then
		selected = containing[1]
		if #containing > 1 then
			overlap = true
			for i = 2, #containing do
				if math.abs(value - containing[i].band[2]) < math.abs(value - selected.band[2]) then
					selected = containing[i]
				end
			end
		end
	else
		local bestDistance = math.huge
		for index, band in ipairs(bands) do
			local distance = math.abs(value - band[2])
			if distance < bestDistance then
				bestDistance = distance
				selected = {index = index, band = band}
			end
		end
	end

	local band = selected.band
	local position = clamp(bandPosition(value, band[1], band[2], band[3]), 0, 1)
	local confidence = bandConfidence(value, band[1], band[2], band[3])
	if #containing == 0 then confidence = confidence * 0.5 end
	confidence = confidence * anchorQuality(band[4], band[5], band[6])
	if overlap then confidence = confidence * 0.70 end
	return {
		dan = danOrder[selected.index],
		position = round(position, 3),
		confidence = round(confidence, 3)
	}
end

local function compositeDan(estimates)
	local lowestIndex, highestIndex = math.huge, -math.huge
	local bottomRole, bestEstimate = "jack", nil
	local totalWeight, weightedIndex = 0, 0
	for _, role in ipairs(roleOrder) do
		local estimate = estimates[role]
		if estimate then
			local index = danIndex(estimate.dan)
			if index < lowestIndex then lowestIndex, bottomRole = index, role end
			if index > highestIndex then highestIndex = index end
			if not bestEstimate or estimate.confidence > bestEstimate.confidence then bestEstimate = estimate end
			local weight = math.max(estimate.confidence, 0.05)
			totalWeight = totalWeight + weight
			weightedIndex = weightedIndex + (index + estimate.position) * weight
		end
	end

	if not bestEstimate then return "1st", "jack" end
	local spread = highestIndex - lowestIndex
	local index
	if spread <= 2 then
		index = round(weightedIndex / totalWeight, 0)
	else
		index = danIndex(bestEstimate.dan)
		if spread >= 5 then index = math.max(0, index - 1) end
	end
	return danOrder[clamp(index + 1, 1, #danOrder)], bottomRole
end

local function primaryRole(roleScores, estimates)
	local combined = {}
	for _, role in ipairs(roleOrder) do
		local estimate = estimates[role]
		if estimate then
			local normalized = roleScores[role] / maxAnchors[role]
			combined[role] = normalized * (0.1 + 0.9 * estimate.confidence)
		end
	end

	local leader
	for _, role in ipairs(roleOrder) do
		if combined[role] and (not leader or combined[role] > combined[leader]) then leader = role end
	end
	if not leader then return nil end

	local rawLeader, rawBest, rawSecond = nil, -math.huge, -math.huge
	for _, role in ipairs(roleOrder) do
		local score = roleScores[role]
		if score > rawBest then
			rawSecond, rawBest, rawLeader = rawBest, score, role
		elseif score > rawSecond then
			rawSecond = score
		end
	end

	local override
	if (rawLeader == "tech" or rawLeader == "jack") and rawBest - rawSecond >= 2.7 and leader ~= rawLeader then
		override = rawLeader
	elseif (leader == "tech" or leader == "jack") and estimates[leader].confidence < 0.6 then
		for _, candidate in ipairs({"tech", "jack"}) do
			if candidate ~= leader and rawLeader then
				if roleScores[candidate] - roleScores[leader] >= 4 then
					override = candidate
					break
				end
			end
		end
	end
	return override or leader
end

--- Estimate a Reform Dan result from a 1-indexed Etterna skillset MSD table.
-- Expected indices: 2 Stream, 3 Jumpstream, 4 Handstream, 5 Stamina,
-- 6 JackSpeed, 7 Chordjack, 8 Technical.
function HV.EstimateReformFromMSDs(msds)
	if type(msds) ~= "table" then return nil end
	local function read(index)
		local value = tonumber(msds[index])
		if not value or value <= 0 then return 0 end
		return value
	end

	local roleScores = {
		jack = math.max(read(6), read(7)),
		speed = math.max(read(2), read(3)),
		tech = read(8),
		stamina = 0.7 * read(5) + 0.3 * read(4)
	}
	local estimates, validRoles = {}, 0
	for _, role in ipairs(roleOrder) do
		if roleScores[role] > 0 then
			estimates[role] = lookupRole(roleScores[role], role)
			validRoles = validRoles + 1
		end
	end
	if validRoles == 0 then return nil end

	local primary = primaryRole(roleScores, estimates)
	if not primary then return nil end
	local primaryEstimate = estimates[primary]
	local finalDan, finalPosition = primaryEstimate.dan, primaryEstimate.position
	local groupDan = compositeDan(estimates)
	if primaryEstimate.confidence < 0.5 and danIndex(groupDan) == 7 and danIndex(finalDan) <= 5 then
		finalDan, finalPosition = groupDan, 0.5
	end

	local finalIndex = danIndex(finalDan)
	local agreeing = 0
	for _, role in ipairs(roleOrder) do
		if estimates[role] and math.abs(danIndex(estimates[role].dan) - finalIndex) <= 1 then
			agreeing = agreeing + 1
		end
	end
	local confidence = round(agreeing / validRoles, 3)
	local sublevel = finalPosition < 0.20 and "Low"
		or finalPosition < 0.40 and "Mid-Low"
		or finalPosition < 0.60 and "Mid"
		or finalPosition < 0.80 and "Mid-High"
		or "High"

	return {
		dan = finalDan,
		dp = math.floor((1 + finalIndex + finalPosition) * 100 + 0.5) / 100,
		position = finalPosition,
		sublevel = sublevel,
		role = primary,
		confidence = confidence,
		roleEstimates = estimates
	}
end
