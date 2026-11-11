-- Theme-native ISOR building blocks.
-- ISOR source: https://github.com/acarranzao1a-png/Dan-Overlay
-- The theme supplies rate-scaled {time, column, endTime?} note events.

HV = HV or {}
local isorRidge

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function sigmoid(x, k, x0)
	return 1 / (1 + math.exp(-clamp(k * (x - x0), -50, 50)))
end

-- Exact ISOR 10-second window and per-column repetition measurements.
function HV.ISORChokeMetrics(events, drainSeconds)
	if type(events) ~= "table" or #events == 0 or (tonumber(drainSeconds) or 0) <= 0 then return nil end
	local times, byColumn = {}, {}
	for _, e in ipairs(events) do
		local t, c = tonumber(e.time), tonumber(e.column)
		if t and c then
			times[#times + 1] = t
			byColumn[c] = byColumn[c] or {}
			byColumn[c][#byColumn[c] + 1] = t
		end
	end
	if #times == 0 then return nil end
	table.sort(times)
	local maxWindow, left, right = 0, 1, 1
	local start, last = times[1], times[#times]
	while start <= last do
		while left <= #times and times[left] < start do left = left + 1 end
		while right <= #times and times[right] <= start + 10000 do right = right + 1 end
		maxWindow = math.max(maxWindow, right - left)
		start = start + 250
	end
	local totalDeltas, jackBursts, minDelta = 0, 0, math.huge
	for _, colTimes in pairs(byColumn) do
		table.sort(colTimes)
		for i = 2, #colTimes do
			local dt = colTimes[i] - colTimes[i - 1]
			totalDeltas = totalDeltas + 1
			minDelta = math.min(minDelta, dt)
			if dt <= 120 then jackBursts = jackBursts + 1 end
		end
	end
	local mean = #times / math.max(drainSeconds, 1)
	local choke = maxWindow / 10
	return {
		choke_10s_nps = math.floor(choke * 100 + 0.5) / 100,
		mean_nps = math.floor(mean * 100 + 0.5) / 100,
		burst_ratio = math.floor((choke / math.max(mean, 1)) * 1000 + 0.5) / 1000,
		min_col_delta_ms = minDelta == math.huge and 9999 or math.floor(minDelta * 10 + 0.5) / 10,
		jack_burst_density = math.floor((jackBursts / math.max(#times, 1)) * 1000 + 0.5) / 1000,
	}
end

-- Basic ISOR structural statistics derived from the same native event stream.
function HV.ISORStructuralFeatures(events, keyCount, drainSeconds, bpm)
	if type(events) ~= "table" or #events == 0 or tonumber(keyCount) ~= 4 then return nil end
	local rows, colTimes, noteTimes, colCounts = {}, {}, {}, {}
	local rowTimes = {}
	for _, e in ipairs(events) do
		local t, c = tonumber(e.time), tonumber(e.column)
		if t and c and c >= 1 and c <= 4 then
			-- Dan-Overlay's parser coalesces note heads within a 2 ms row
			-- tolerance. Etterna can report slightly different elapsed times
			-- for heads that belong to the same chart row, so mirror that rule.
			local rowTime = rowTimes[#rowTimes]
			if not rowTime or math.abs(t - rowTime) > 2 then
				rowTime = t
				rowTimes[#rowTimes + 1] = rowTime
				rows[rowTime] = {time = rowTime, columns = {}}
			end
			local row = rows[rowTime]
			row.columns[#row.columns + 1] = c
			noteTimes[#noteTimes + 1] = t
			colCounts[c] = (colCounts[c] or 0) + 1
			colTimes[c] = colTimes[c] or {}
			colTimes[c][#colTimes[c] + 1] = t
		end
	end
	local rowList, singles, doubles, triples, quads = {}, 0, 0, 0, 0
	for _, r in pairs(rows) do rowList[#rowList + 1] = r end
	table.sort(rowList, function(a,b) return a.time < b.time end)
	for _, r in ipairs(rowList) do
		local n = #r.columns
		if n == 1 then singles = singles + 1 elseif n == 2 then doubles = doubles + 1 elseif n == 3 then triples = triples + 1 else quads = quads + 1 end
	end
	local totalRows, totalNotes = #rowList, #events
	local strict, broad, vibro, totalPairs = 0, 0, 0, 0
	for _, ts in pairs(colTimes) do
		table.sort(ts)
		for i = 2, #ts do
			local d = ts[i] - ts[i - 1]
			totalPairs = totalPairs + 1
			if d <= 180 then broad = broad + 1 end
			if d <= 120 then strict = strict + 1 end
			if d <= 80 then vibro = vibro + 1 end
		end
	end
	local transitions, transitionCount = 0, 0
	for i = 2, #rowList do
		local a, b = {}, {}
		for _, c in ipairs(rowList[i - 1].columns) do a[c] = true end
		for _, c in ipairs(rowList[i].columns) do b[c] = true end
		local union, intersection = 0, 0
		for c = 1, 4 do
			if a[c] or b[c] then union = union + 1 end
			if a[c] and b[c] then intersection = intersection + 1 end
		end
		if union > 0 then transitions = transitions + 1 - intersection / union; transitionCount = transitionCount + 1 end
	end
	-- Match upstream feature_extractor._nps_windows: centered 500ms windows,
	-- sampled every 250ms, including all-zero windows between the first/last row.
	table.sort(noteTimes)
	local windowNPS, left, right = {}, 1, 1
	local t, tMax = noteTimes[1], noteTimes[#noteTimes]
	while t <= tMax do
		local lo, hi = t - 250, t + 250
		while left <= #noteTimes and noteTimes[left] < lo do left = left + 1 end
		while right <= #noteTimes and noteTimes[right] <= hi do right = right + 1 end
		windowNPS[#windowNPS + 1] = (right - left) * 2
		t = t + 250
	end
	local sum, sumSq, active, activeSum, activeSq = 0, 0, 0, 0, 0
	for _, nps in ipairs(windowNPS) do
		sum, sumSq = sum + nps, sumSq + nps*nps
		if nps > 2 then active = active + 1; activeSum = activeSum + nps; activeSq = activeSq + nps*nps end
	end
	local avgNPS = sum / math.max(#windowNPS, 1)
	local cv = avgNPS > 0 and math.sqrt(math.max(0, sumSq / math.max(#windowNPS, 1) - avgNPS*avgNPS)) / avgNPS or 0
	table.sort(windowNPS)
	local function percentile(p)
		return windowNPS[math.max(1, math.min(#windowNPS, math.floor(#windowNPS * p) + 1))] or 0
	end
	local topStart = math.max(1, math.floor(#windowNPS * 0.70))
	local topSum = 0
	for i = topStart, #windowNPS do topSum = topSum + windowNPS[i] end
	local activeAvg = activeSum / math.max(active, 1)
	local activeCV = active > 0 and math.sqrt(math.max(0, activeSq / active - activeAvg*activeAvg)) / math.max(activeAvg, 1e-6) or 0
	local rowGapSum, rowGapSq = 0, 0
	for i = 2, #rowList do
		local gap = rowList[i].time - rowList[i - 1].time
		rowGapSum, rowGapSq = rowGapSum + gap, rowGapSq + gap*gap
	end
	local rowGapN = math.max(#rowList - 1, 0)
	local rowGapMean = rowGapSum / math.max(rowGapN, 1)
	local timingIrregularity = rowGapN >= 2 and rowGapMean > 0
		and math.sqrt(math.max(0, rowGapSq / rowGapN - rowGapMean*rowGapMean)) / rowGapMean or 0
	local entropyValues, entropyLeft, entropyRight = {}, 1, 1
	local entropyTime, entropyEnd = noteTimes[1], noteTimes[#noteTimes]
	while entropyTime <= entropyEnd do
		while entropyLeft <= #noteTimes and noteTimes[entropyLeft] < entropyTime do entropyLeft = entropyLeft + 1 end
		if entropyRight < entropyLeft then entropyRight = entropyLeft end
		while entropyRight <= #noteTimes and noteTimes[entropyRight] <= entropyTime + 2000 do entropyRight = entropyRight + 1 end
		local counts, count = {0,0,0,0}, 0
		for i=entropyLeft,entropyRight-1 do local c=tonumber(events[i].column); if c and c>=1 and c<=4 then counts[c]=counts[c]+1; count=count+1 end end
		if count>=4 then
			local h=0
			for _,n in ipairs(counts) do if n>0 then local p=n/count; h=h-p*math.log(p)/math.log(2) end end
			entropyValues[#entropyValues+1]=h
		end
		entropyTime=entropyTime+1000
	end
	local patternIrregularity=0
	if #entropyValues>=2 then
		local mean=0; for _,v in ipairs(entropyValues) do mean=mean+v end; mean=mean/#entropyValues
		local variance=0; for _,v in ipairs(entropyValues) do variance=variance+(v-mean)^2 end
		patternIrregularity=mean>1e-6 and math.sqrt(variance/#entropyValues)/mean or 0
	end
	local maxColumnCount = 0
	for _, n in pairs(colCounts) do maxColumnCount = math.max(maxColumnCount, n) end
	local usedColumns = 0
	for _ in pairs(colCounts) do usedColumns = usedColumns + 1 end
	local anchorRatio = math.max(0, (maxColumnCount - totalNotes / math.max(usedColumns, 1)) / math.max(totalNotes, 1))
	return {
		stream_purity = math.floor(singles / math.max(totalRows, 1)*10000+0.5)/10000,
		jump_ratio = math.floor(doubles / math.max(totalRows, 1)*10000+0.5)/10000,
		hand_ratio = math.floor(triples / math.max(totalRows, 1)*10000+0.5)/10000,
		quad_ratio = math.floor(quads / math.max(totalRows, 1)*10000+0.5)/10000,
		jack_ratio = math.floor(broad / math.max(totalPairs, 1)*10000+0.5)/10000,
		jack_density = math.floor(strict / math.max(totalPairs, 1)*10000+0.5)/10000,
		vibro_density = math.floor(vibro / math.max(totalPairs, 1)*10000+0.5)/10000,
		transition_var = math.floor((transitionCount > 0 and transitions / transitionCount or 0)*10000+0.5)/10000,
		anchor_ratio = math.floor(anchorRatio*10000+0.5)/10000,
		timing_irregularity = math.floor(timingIrregularity*10000+0.5)/10000,
		pattern_irregularity = math.floor(patternIrregularity*10000+0.5)/10000,
		density_cv = math.floor(cv*10000+0.5)/10000,
		duration_s = math.floor((tonumber(drainSeconds) or 0)*100+0.5)/100,
		bpm = math.floor((tonumber(bpm) or 0)*100+0.5)/100,
		nps_p90 = math.floor(percentile(0.90)*1000+0.5)/1000,
		nps_sustained_top30 = math.floor((topSum / math.max(#windowNPS - topStart + 1, 1))*1000+0.5)/1000,
		nps_active_ratio = math.floor(active / math.max(#windowNPS, 1)*10000+0.5)/10000,
		nps_active_cv = math.floor(activeCV*10000+0.5)/10000,
		avg_nps = totalNotes / math.max(tonumber(drainSeconds) or 0, 1),
	}
end


-- Upstream ISOR ruler calibration.
local isorDanOrder = {"1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th", "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa"}
local isorSRMeans = {
	["jack"] = {
		["1st"] = 2.34,
		["2nd"] = 2.35,
		["3rd"] = 3.17,
		["4th"] = 3.48,
		["5th"] = 3.98,
		["6th"] = 4.75,
		["7th"] = 4.97,
		["8th"] = 5.84,
		["9th"] = 5.85,
		["10th"] = 6.3,
		["Alpha"] = 6.45,
		["Beta"] = 6.78,
		["Gamma"] = 6.95,
		["Delta"] = 7.85,
		["Epsilon"] = 8.76,
		["Zeta"] = 9.35,
		["Eta"] = 10.38,
		["Theta"] = 10.96,
		["Iota"] = 12.27,
		["Kappa"] = 13.13,
	},
	["speed"] = {
		["1st"] = 2.94,
		["2nd"] = 3.5,
		["3rd"] = 3.78,
		["4th"] = 4.16,
		["5th"] = 4.86,
		["6th"] = 5.1,
		["7th"] = 5.25,
		["8th"] = 5.45,
		["9th"] = 5.7,
		["10th"] = 6.0,
		["Alpha"] = 6.55,
		["Beta"] = 6.8,
		["Gamma"] = 7.45,
		["Delta"] = 7.76,
		["Epsilon"] = 9.16,
		["Zeta"] = 9.55,
		["Eta"] = 10.05,
		["Theta"] = 10.67,
		["Iota"] = 11.16,
		["Kappa"] = 12.05,
	},
	["stamina"] = {
		["1st"] = 3.38,
		["2nd"] = 3.48,
		["3rd"] = 3.79,
		["4th"] = 4.69,
		["5th"] = 5.23,
		["6th"] = 5.65,
		["7th"] = 5.75,
		["8th"] = 6.15,
		["9th"] = 6.26,
		["10th"] = 6.45,
		["Alpha"] = 6.58,
		["Beta"] = 6.88,
		["Gamma"] = 7.35,
		["Delta"] = 7.85,
		["Epsilon"] = 8.92,
		["Zeta"] = 9.6,
		["Eta"] = 9.96,
		["Theta"] = 10.81,
		["Iota"] = 11.66,
		["Kappa"] = 12.41,
	},
	["tech"] = {
		["1st"] = 2.84,
		["2nd"] = 3.08,
		["3rd"] = 3.09,
		["4th"] = 3.9,
		["5th"] = 4.18,
		["6th"] = 4.5,
		["7th"] = 5.43,
		["8th"] = 5.69,
		["9th"] = 6.31,
		["10th"] = 6.55,
		["Alpha"] = 6.62,
		["Beta"] = 6.85,
		["Gamma"] = 7.3,
		["Delta"] = 8.17,
		["Epsilon"] = 9.22,
		["Zeta"] = 9.6,
		["Eta"] = 10.25,
		["Theta"] = 10.64,
		["Iota"] = 11.69,
		["Kappa"] = 12.1,
	},
	["general"] = {
		["1st"] = 2.94,
		["2nd"] = 3.23,
		["3rd"] = 3.51,
		["4th"] = 4.16,
		["5th"] = 4.71,
		["6th"] = 5.12,
		["7th"] = 5.36,
		["8th"] = 5.8,
		["9th"] = 6.0,
		["10th"] = 6.25,
		["Alpha"] = 6.5,
		["Beta"] = 6.8,
		["Gamma"] = 7.35,
		["Delta"] = 7.85,
		["Epsilon"] = 9.0,
		["Zeta"] = 9.4,
		["Eta"] = 10.13,
		["Theta"] = 10.74,
		["Iota"] = 11.68,
		["Kappa"] = 12.25,
	},
}
local isorChokeMeans = {
	["speed"] = {
		["1st"] = 11.5,
		["2nd"] = 13.0,
		["3rd"] = 14.5,
		["4th"] = 16.0,
		["5th"] = 18.0,
		["6th"] = 18.5,
		["7th"] = 19.2,
		["8th"] = 19.8,
		["9th"] = 20.4,
		["10th"] = 21.0,
		["Alpha"] = 25.2,
		["Beta"] = 26.5,
		["Gamma"] = 28.0,
		["Delta"] = 30.0,
		["Epsilon"] = 31.8,
		["Zeta"] = 35.0,
		["Eta"] = 36.5,
		["Theta"] = 41.5,
		["Iota"] = 45.0,
		["Kappa"] = 49.0,
	},
	["stamina"] = {
		["1st"] = 12.9,
		["2nd"] = 15.4,
		["3rd"] = 15.5,
		["4th"] = 17.8,
		["5th"] = 23.0,
		["6th"] = 20.6,
		["7th"] = 22.3,
		["8th"] = 23.5,
		["9th"] = 24.5,
		["10th"] = 24.0,
		["Alpha"] = 24.4,
		["Beta"] = 25.5,
		["Gamma"] = 28.5,
		["Delta"] = 31.4,
		["Epsilon"] = 34.0,
		["Zeta"] = 38.6,
		["Eta"] = 42.7,
		["Theta"] = 40.3,
		["Iota"] = 45.9,
		["Kappa"] = 50.0,
	},
	["jack"] = {
		["1st"] = 10.5,
		["2nd"] = 12.0,
		["3rd"] = 10.5,
		["4th"] = 13.1,
		["5th"] = 14.3,
		["6th"] = 14.4,
		["7th"] = 17.9,
		["8th"] = 19.5,
		["9th"] = 20.5,
		["10th"] = 24.8,
		["Alpha"] = 24.8,
		["Beta"] = 26.5,
		["Gamma"] = 27.2,
		["Delta"] = 31.0,
		["Epsilon"] = 34.0,
		["Zeta"] = 35.2,
		["Eta"] = 39.1,
		["Theta"] = 45.0,
		["Iota"] = 49.3,
		["Kappa"] = 53.7,
	},
	["tech"] = {
		["1st"] = 10.5,
		["2nd"] = 12.0,
		["3rd"] = 10.5,
		["4th"] = 13.1,
		["5th"] = 14.3,
		["6th"] = 14.4,
		["7th"] = 17.9,
		["8th"] = 19.5,
		["9th"] = 20.5,
		["10th"] = 21.8,
		["Alpha"] = 22.5,
		["Beta"] = 23.8,
		["Gamma"] = 26.0,
		["Delta"] = 26.8,
		["Epsilon"] = 29.8,
		["Zeta"] = 36.0,
		["Eta"] = 39.2,
		["Theta"] = 39.3,
		["Iota"] = 42.4,
		["Kappa"] = 46.6,
	},
	["general"] = {
		["1st"] = 11.5,
		["2nd"] = 13.5,
		["3rd"] = 14.5,
		["4th"] = 16.0,
		["5th"] = 18.5,
		["6th"] = 19.5,
		["7th"] = 20.5,
		["8th"] = 21.5,
		["9th"] = 22.5,
		["10th"] = 22.8,
		["Alpha"] = 24.2,
		["Beta"] = 25.0,
		["Gamma"] = 27.0,
		["Delta"] = 30.0,
		["Epsilon"] = 32.5,
		["Zeta"] = 35.5,
		["Eta"] = 38.5,
		["Theta"] = 42.0,
		["Iota"] = 46.0,
		["Kappa"] = 50.5,
	},
}
local isorMSDMeans = {
	["1st"] = 13.5,
	["2nd"] = 15.5,
	["3rd"] = 16.8,
	["4th"] = 18.5,
	["5th"] = 20.5,
	["6th"] = 22.0,
	["7th"] = 23.5,
	["8th"] = 24.8,
	["9th"] = 25.8,
	["10th"] = 26.8,
	["Alpha"] = 27.5,
	["Beta"] = 28.5,
	["Gamma"] = 30.5,
	["Delta"] = 33.0,
	["Epsilon"] = 36.0,
	["Zeta"] = 37.8,
	["Eta"] = 40.5,
	["Theta"] = 43.5,
	["Iota"] = 46.5,
	["Kappa"] = 50.0,
}

local function isotonicRuler(means)
	local blocks = {}
	for i, dan in ipairs(isorDanOrder) do blocks[i] = {means[dan]} end
	local changed = true
	while changed do
		changed = false
		local i = 1
		while i < #blocks do
			local function avg(b) local s = 0; for _,v in ipairs(b) do s = s + v end; return s / #b end
			if avg(blocks[i]) > avg(blocks[i + 1]) then
				for _,v in ipairs(blocks[i + 1]) do blocks[i][#blocks[i] + 1] = v end
				table.remove(blocks, i + 1); changed = true
			else i = i + 1 end
		end
	end
	local result, flatIndex = {}, 1
	for _,b in ipairs(blocks) do
		local mean = 0; for _,v in ipairs(b) do mean = mean + v end; mean = mean / #b
		for _ = 1, #b do
			local value = flatIndex > 1 and math.max(mean, result[flatIndex - 1] + 0.005) or mean
			result[flatIndex] = value; flatIndex = flatIndex + 1
		end
	end
	local mapped = {}
	for i, dan in ipairs(isorDanOrder) do mapped[dan] = result[i] end
	return mapped
end

local cleanChokeMeans = {}
for family, ruler in pairs(isorChokeMeans) do cleanChokeMeans[family] = isotonicRuler(ruler) end

local function interpolateRuler(value, means)
	local first, second = means[isorDanOrder[1]], means[isorDanOrder[2]]
	local last, beforeLast = means[isorDanOrder[#isorDanOrder]], means[isorDanOrder[#isorDanOrder - 1]]
	if value < first - (second - first) / 2 then
		return 1 + clamp((value - (first - (second - first) / 2 - 1)), 0, 1) * 0.20
	end
	if value >= last + (last - beforeLast) / 2 then return 20.99 end
	for i, dan in ipairs(isorDanOrder) do
		local mean = means[dan]
		local lo = i == 1 and (mean - (means[isorDanOrder[2]] - mean) / 2)
			or (means[isorDanOrder[i - 1]] + mean) / 2
		local hi = i == #isorDanOrder and (mean + (mean - means[isorDanOrder[i - 1]]) / 2)
			or (mean + means[isorDanOrder[i + 1]]) / 2
		if value >= lo and value < hi then return i + (value - lo) / math.max(hi - lo, 1e-6) end
	end
	return 20
end

-- Ports ISOR's modulated SR + three-signal DP triangulation. The ridge stage
-- is applied separately once feature-vector inputs are available.
function HV.ISORTriangulate(rawSR, sunny, choke, msds, family, features)
	if type(rawSR) ~= "number" or rawSR <= 0 or type(choke) ~= "table" or type(msds) ~= "table" then return nil end
	sunny, features = sunny or {}, features or {}
	local chokeNPS = tonumber(choke.choke_10s_nps) or 0
	local burst = tonumber(choke.burst_ratio) or 1
	local jbar = tonumber(sunny.jbar_max) or 0
	local burstDelta = 0.08 * sigmoid(burst, 5, 1.35) * sigmoid(jbar, 0.08, 60)
	local jackDelta = 0
	if (family == "jack" or family == "tech" or family == "hybrid") and jbar > 55 then
		jackDelta = 0.05 * sigmoid(jbar, 0.10, 70) * math.min(1, (tonumber(choke.jack_burst_density) or 0) * 2)
	end
	local fatigueSpike = 0
	if burst < 1.15 and rawSR > 9.5 and (family == "tech" or family == "jack") then
		fatigueSpike = math.min(0.06, sigmoid(rawSR, 2, 9.7) * (1.15 - burst) * 0.40)
	end
	local marathon = 0.08 * sigmoid(tonumber(features.duration_s) or 0, 0.02, 200)
		* (1 - math.min(1, (tonumber(features.density_cv) or 0) / 0.4))
	local fatigue = math.min(0.12, fatigueSpike + marathon)
	local bpmDelta = 0.06 * sigmoid(tonumber(features.stream_purity) or 0, 20, 0.85)
		* sigmoid(tonumber(features.bpm) or 0, 0.08, 200)
	local taper = math.max(0.25, 1 - math.max(0, rawSR - 9) * 0.12)
	burstDelta, jackDelta, bpmDelta = burstDelta * taper, jackDelta * taper, bpmDelta * taper
	local modSR = rawSR * (1 + burstDelta + jackDelta + bpmDelta - fatigue)

	local jump = tonumber(features.jump_ratio) or 0
	local jackDensity = tonumber(features.jack_density) or 0
	local sk
	if (family and family:find("jack", 1, true)) or jbar > 55 then sk = "jack"
	elseif family and (family:find("tech", 1, true) or family:find("ln", 1, true)) then sk = "tech"
	elseif jackDensity >= 0.15 then sk = "jack"
	elseif family == "stream" or family == "speed" then sk = jump >= 0.35 and "stamina" or "speed"
	elseif family == "chordstream" or family == "stamina" then sk = jump >= 0.25 and "stamina" or "speed"
	else sk = jump >= 0.35 and "stamina" or "general" end
	local srMeans = isorSRMeans[sk] or isorSRMeans.general
	local chokeMeans = cleanChokeMeans[sk] or cleanChokeMeans.general
	local dpSR = interpolateRuler(modSR, srMeans)
	local dpChoke = interpolateRuler(chokeNPS, chokeMeans)
	local msd = tonumber(msds.overall) or tonumber(msds[1]) or 0
	local hasMSD = msd > 0
	local dpMSD = hasMSD and interpolateRuler(msd, isorMSDMeans) or dpSR
	local wSR, wChoke, wMSD
	if hasMSD then
		wSR = math.min(0.80, 0.50 + 0.25 * sigmoid(13 - chokeNPS, 1, 0) * sigmoid(rawSR - 3, 2, 0))
		wMSD = math.min(0.35, 0.20 + 0.15 * sigmoid(math.abs(dpSR - dpChoke) - 1.2, 2, 0))
		wChoke = math.max(0.05, 1 - wSR - wMSD)
		local total = wSR + wChoke + wMSD
		wSR, wChoke, wMSD = wSR / total, wChoke / total, wMSD / total
	else wSR, wChoke, wMSD = 0.60, 0.40, 0 end
	local dp = wSR * dpSR + wChoke * dpChoke + wMSD * dpMSD
	if dp <= 4.5 and chokeNPS < 18 then dp = math.max(1, dp - 0.20 * sigmoid(16 - chokeNPS, 0.5, 2) * math.max(0, dp - 1.5)) end
	local hand = tonumber(features.hand_ratio) or 0
	if dp >= 9.8 and dp <= 12.8 then
		dp = dp + 0.20 * sigmoid(chokeNPS, 3, 25.2) * sigmoid(hand, 20, 0.15)
			+ 0.25 * sigmoid(chokeNPS, 3, 27.2)
			+ 0.35 * (sigmoid(hand, 25, 0.12) - 0.5)
	end
	dp = math.floor(dp * 100 + 0.5) / 100
	local tierIndex = clamp(math.floor(dp) - 1, 0, #isorDanOrder - 1)
	local frac = math.floor((dp - math.floor(dp)) * 100 + 0.5) / 100
	local sublevel = frac < 0.20 and "Low" or frac < 0.40 and "Mid-Low" or frac < 0.60 and "Mid" or frac < 0.80 and "Mid-High" or "High"
	return {dp = dp, dan = isorDanOrder[tierIndex + 1], sublevel = sublevel, family = family or "hybrid",
		confidence = 0, sk_key = sk, mod_sr = modSR, dp_sr = dpSR, dp_choke = dpChoke, dp_msd = dpMSD,
		weights = {w_sr = wSR, w_choke = wChoke, w_msd = wMSD}}
end

-- ISOR's score-based family classifier. The full tech subtype model is only
-- descriptive and is omitted; its family label and confidence are preserved.
function HV.ISORClassifyFamily(sunny, features, noteCount)
	if type(features) ~= "table" or type(sunny) ~= "table" then return nil end
	local function f(t, k, d) return tonumber(t[k]) or d or 0 end
	local bpm, drain = f(features, "bpm"), f(features, "duration_s")
	local jbar, pbar, xbar = f(sunny, "jbar_max"), f(sunny, "pbar_max"), f(sunny, "xbar_max")
	local total = jbar + pbar + 1
	local jackDom, streamDom = jbar / total, pbar / total
	local techDom = xbar / math.max(xbar + total, 1e-9)
	local purity, jackRatio = f(features, "stream_purity"), f(features, "jack_ratio")
	local jackDensity, vibro = f(features, "jack_density"), f(features, "vibro_density")
	-- Match upstream's get_f(k, default) behavior: an explicit zero falls
	-- through to the broad jack ratio for this classifier signal.
	if jackDensity == 0 then jackDensity = f(features, "jack_ratio") end
	local densityCV, transVar = math.min(2, f(features, "density_cv")), f(features, "transition_var")
	local jump, hand, quad = f(features, "jump_ratio"), f(features, "hand_ratio"), f(features, "quad_ratio")
	local npsSustain, activeRatio, activeCV = f(features, "nps_sustained_top30"), f(features, "nps_active_ratio"), f(features, "nps_active_cv")
	local chord = jump + hand + quad
	local repetition = math.min(1, math.max(0, 0.83 - transVar) * 12)
	local jackBaseline = bpm > 0 and math.min(0.9, math.max(0, 1 - (60000 / bpm) / 250)) or 0.3
	local jackExcess = math.max(0, jackRatio - jackBaseline)
	local bpmSignal = math.min(1.5, math.max(0, bpm - 140) / 80)
	local scoreJack = repetition * 50 + jackDensity * 45 + chord * 20 + jackExcess * 15 + vibro * 20 + f(features, "anchor_ratio") * 15 + jackDom * 10
	local scoreStream = purity * 45 + math.max(0, 1 - chord * 3) * 15 - chord * 12 + streamDom * 20 + math.max(0, 1 - densityCV) * 15 + math.max(0, 0.5 - jackDensity) * 10
	local scoreTech = densityCV * 55 + f(features, "pattern_irregularity") * 25 + activeCV * 20 + techDom * 20 + transVar * 12 + chord * 8
	local peakRatio = f(sunny, "d83") > 0.1 and f(sunny, "d93") / f(sunny, "d83") or 1
	local speedRaw = bpmSignal * 42 + purity * 22 + math.max(0, 1 - densityCV) * 10 + math.max(0, peakRatio - 1.02) * 12
	local scoreSpeed = speedRaw * math.max(0.25, 1 - chord * 1.8) * math.max(0.5, 1 - math.max(0, densityCV - 0.30) * 2.5)
	local drainGate = math.max(0, drain - 60) / 120
	local shortPenalty = math.max(0, 1 - drain / 90)
	local chordReq = math.min(1, math.max(0, chord - 0.15) / 0.20)
	local staminaRaw = drainGate * 28 + chord * 25 - purity * 20 + activeRatio * 12 + math.max(0, 1 - densityCV) * 8 + npsSustain * 0.3 + math.min(1, drain / 150) * 12
	local scoreStamina = staminaRaw * chordReq * math.max(0.4, 1 - shortPenalty * 0.5)
	if repetition > 0.15 then scoreStamina = scoreStamina * math.max(0.3, 1 - repetition * 0.7) end
	local scores = {stream = scoreStream, jack = scoreJack, tech = scoreTech, speed = scoreSpeed, stamina = scoreStamina}
	local family, top, second, sum = "hybrid", -math.huge, -math.huge, 0
	for _,name in ipairs({"stream", "jack", "tech", "speed", "stamina"}) do
		local v = scores[name]; sum = sum + v
		if v > top then family, second, top = name, top, v elseif v > second then second = v end
	end
	local confidence = math.min(1, (top - second) / math.max(sum * 0.10, 1))
	if confidence < 0.15 then family, confidence = "hybrid", math.max(0.1, confidence) end
	if (family == "hybrid" or family == "stream") and densityCV > 0.35 and scoreTech > 0 and scoreStream > 0 and scoreTech / scoreStream > 0.75 then family, confidence = "tech", math.max(confidence, 0.3) end
	if family == "stream" and bpm >= 155 and purity > 0.70 and chord < 0.30 and scoreSpeed > 0 and scoreStream > 0 and scoreSpeed / scoreStream > 0.35 then family, confidence = "speed", math.max(confidence, 0.25) end
	if family == "jack" and (tonumber(noteCount) or 0) > 15000 then family, confidence = scoreStamina > scoreTech and "stamina" or "hybrid", math.min(confidence, 0.5) end
	if (family == "stream" or family == "tech") and drain > 120 and chord > 0.25 and scoreStamina > math.max(scoreStream, scoreTech) * 0.85 then family, confidence = "stamina", math.max(confidence, 0.35) end
	local timing = f(features, "timing_irregularity")
	-- A low-margin result is labeled "hybrid", which has no direct score
	-- entry. Compare its tech score to the leading family score in that case.
	local familyScore = scores[family] or top
	if family ~= "tech" and family ~= "jack" and timing > 0.4 and jackDensity > 0.08 and chord > 0.15 and chord < 0.55 and purity > 0.40 and purity < 0.85 and scoreTech > familyScore * 0.75 then family, confidence = "tech", math.max(confidence, 0.35) end
	return {family = family, confidence = math.floor(confidence * 1000 + 0.5) / 1000, scores = scores}
end

-- Upstream uses its parsed rhythm-profile classifier below 7 SR, then falls
-- back to the Sunny/feature classifier when parsed confidence is under 0.10.
-- ISOR is calibrated for 4K rice, so this port focuses on its rice textures
-- (linear streams, chord flow, anchors, and trills); LN-only profile types are
-- intentionally not synthesized from Etterna hold-head/endTime records.
function HV.ISORClassifyParsedFamily(events, bpm, drainSeconds)
	if type(events) ~= "table" or #events < 5 then return nil end
	local rows, lastRowTime = {}, nil
	for _, event in ipairs(events) do
		local t, c = tonumber(event.time), tonumber(event.column)
		if t and c and c >= 1 and c <= 4 then
			if not lastRowTime or t - lastRowTime > 2 then
				lastRowTime = t
				rows[#rows + 1] = {time = t, cols = {}}
			end
			rows[#rows].cols[c] = true
		end
	end
	if #rows < 6 then return nil end
	local frames, previousCols = {}, rows[1].cols
	for i = 2, #rows do
		local cols, count, jacks = {}, 0, 0
		for c = 1, 4 do
			if rows[i].cols[c] then
				cols[#cols + 1] = c
				count = count + 1
				if previousCols and previousCols[c] then jacks = jacks + 1 end
			end
		end
		frames[#frames + 1] = {time = rows[i].time, cols = cols, count = count, jacks = jacks,
			gap = rows[i].time - rows[i - 1].time}
		previousCols = rows[i].cols
	end
	local scores = {stream = 0, speed = 0, jack = 0, tech = 0, stamina = 0}
	local hits = 0
	local function add(family, first, last, weight)
		local duration = math.max(1, (frames[math.min(last, #frames)].time - frames[first].time) / 1000)
		local localBpm = tonumber(bpm) or 0
		if localBpm <= 0 then localBpm = 60000 / math.max(1, frames[first].gap * 4) end
		scores[family] = scores[family] + duration * localBpm * weight
		hits = hits + 1
	end
	for i = 1, #frames do
		if i + 4 <= #frames then
			local a, b, c, d, e = frames[i], frames[i + 1], frames[i + 2], frames[i + 3], frames[i + 4]
			if a.count == 1 and b.count == 1 and c.count == 1 and d.count == 1 and e.count == 1
				and a.jacks == 0 and b.jacks == 0 and c.jacks == 0 and d.jacks == 0 and e.jacks == 0
				and a.cols[1] ~= e.cols[1] then add("stream", i, i + 4, 1 / 3) end
		end
		if i + 3 <= #frames then
			local a, b, c, d = frames[i], frames[i + 1], frames[i + 2], frames[i + 3]
			if a.count > 1 and a.jacks == 0 and b.jacks == 0 and c.jacks == 0 and d.jacks == 0
				and (b.count > 1 or c.count > 1 or d.count > 1) then
				local family = (a.count >= 3 or b.count >= 3 or c.count >= 3 or d.count >= 3) and "stamina" or "speed"
				add(family, i, i + 3, 0.65)
			end
		end
		if frames[i].jacks > 1 and frames[i].gap * 4 < 2000 then add("jack", i, i, 0.90) end
		if i + 3 <= #frames then
			local a, b, c, d = frames[i], frames[i + 1], frames[i + 2], frames[i + 3]
			if a.count == 1 and b.count == 1 and c.count == 1 and d.count == 1
				and a.cols[1] == c.cols[1] and b.cols[1] == d.cols[1] and a.cols[1] ~= b.cols[1] then
				add("tech", i, i + 3, 0.75)
			end
		end
	end
	if hits == 0 then return nil end
	local ranked = {}
	local total = 0
	for family, score in pairs(scores) do total = total + score; ranked[#ranked + 1] = {family = family, score = score} end
	table.sort(ranked, function(a, b) return a.score > b.score end)
	if not ranked[1] or ranked[1].score <= 0 then return nil end
	local family, top = ranked[1].family, ranked[1].score
	local confidence = math.min(1, top / math.max(total, 1))
	if (family == "stream" or family == "speed") and (tonumber(bpm) or 0) > 200 and (tonumber(drainSeconds) or 0) > 100 then
		family = "stamina"
	end
	return {family = family, confidence = math.floor(confidence * 100 + 0.5) / 100,
		scores = scores}
end

local ridgeStreamNames = {"speed", "hand", "jack", "chordjack", "tech", "stamina", "course"}
local ridgeStatKeys = {"chord_rate", "three_rate", "overlap_rate", "rotation_rate", "fast_jack_rate", "anchor_rate", "hand_bias", "avg_nps", "active_duration_s"}
local ridgeSustainKeys = {"nps1k_q50", "nps1k_q75", "nps1k_q90", "nps4k_q50", "nps4k_q75", "nps4k_q90", "nps1k_flatness", "log_nps1k_mean", "dt_row_q25", "dt_row_q50", "dt_row_q75", "dt_hand_q25", "dt_hand_median", "dt_same_q25", "dt_same_median"}

function HV.ISORApplyRidge(base, features, msds, sunny, purity, sub)
	if not isorRidge or type(features) ~= "table" or type(msds) ~= "table" then return base, 0 end
	sunny, sub = sunny or {}, sub or {}
	local bio = features.ridgeBio or {}
	local summaries, streams, streamsQ97 = bio.summaries or {}, bio.streams or {}, bio.streams_q97 or {}
	local stats = bio.stats or features.ridgeStats or {}
	local function num(t,k,d) return tonumber(t and t[k]) or d or 0 end
	local values = {}
	for _,k in ipairs(ridgeStreamNames) do local s=summaries[k]; values[#values+1]=type(s)=="table" and num(s,"aggregate") or num(streams,k) end
	local logRaw=math.log(1+math.max(0,num(bio,"raw_agg"))); values[#values+1]=logRaw
	for _,k in ipairs(ridgeStatKeys) do values[#values+1]=num(stats,k) end
	for _,k in ipairs(ridgeStreamNames) do local s=summaries[k]; values[#values+1]=type(s)=="table" and num(s,"q97") or num(streamsQ97,k) end
	local roleMSD={jack=math.max(num(msds,"jackspeed"),num(msds,"chordjack")),speed=math.max(num(msds,"stream"),num(msds,"jumpstream")),stamina=0.7*num(msds,"stamina")+0.3*num(msds,"handstream"),tech=num(msds,"technical")}
	local roleTotal=roleMSD.jack+roleMSD.speed+roleMSD.stamina+roleMSD.tech
	for _,k in ipairs({"jack","speed","stamina","tech"}) do values[#values+1]=roleMSD[k]/math.max(roleTotal,1) end
	for _,k in ipairs({"jbar_max","pbar_max","xbar_max","abar_mean"}) do values[#values+1]=num(sunny,k) end
	for _,k in ipairs({"overall","stream","jumpstream","handstream","stamina","jackspeed","chordjack","technical"}) do values[#values+1]=num(msds,k) end
	local jackAgg=num(summaries.jack,"aggregate",num(streams,"jack")); local chordAgg=num(summaries.chordjack,"aggregate",num(streams,"chordjack"))
	local speedAgg=num(summaries.speed,"aggregate",num(streams,"speed")); local staminaAgg=num(summaries.stamina,"aggregate",num(streams,"stamina"))
	local chordRate,fastJack,overlap,rotation=num(stats,"chord_rate"),num(stats,"fast_jack_rate"),num(stats,"overlap_rate"),num(stats,"rotation_rate")
	values[#values+1]=chordRate*fastJack; values[#values+1]=overlap*rotation; values[#values+1]=jackAgg/(chordAgg+1e-6); values[#values+1]=speedAgg*(tonumber(purity) or 0)
	values[#values+1]=num(stats,"anchor_imbalance"); values[#values+1]=num(stats,"peak_to_sustain_gap"); values[#values+1]=num(stats,"break_density")
	values[#values+1]=fastJack*(100/(num(stats,"same_hand_q10")+10)); values[#values+1]=rotation*num(sub,"ti")
	values[#values+1]=num(sub,"burst_ratio",1)*num(stats,"peak_to_sustain_gap"); values[#values+1]=num(stats,"avg_nps")*num(sub,"dur",120)/60
	values[#values+1]=num(sub,"quad")*num(sub,"hand"); values[#values+1]=rotation*(1-overlap); values[#values+1]=num(sub,"choke")/(num(stats,"avg_nps")+1)
	local dpSR,dpChoke,dpMSD,modSR,rawSR=num(sub,"dp_sr"),num(sub,"dp_choke"),num(sub,"dp_msd"),num(sub,"mod_sr"),num(sub,"raw_sr")
	values[#values+1]=math.abs(dpSR-dpMSD)
	values[#values+1]=math.sqrt(math.max(0,logRaw)); values[#values+1]=logRaw^2; values[#values+1]=rawSR/(dpSR+1e-6); values[#values+1]=dpChoke/(dpMSD+1e-6)
	values[#values+1]=modSR-rawSR; values[#values+1]=(dpSR+dpChoke+dpMSD)/3; values[#values+1]=math.max(0,dpMSD-dpSR); values[#values+1]=math.max(0,dpSR-dpMSD)
	values[#values+1]=math.max(0,dpChoke-dpSR); local jbar,pbar=num(sunny,"jbar_max"),num(sunny,"pbar_max")
	values[#values+1]=math.abs(jbar-pbar); values[#values+1]=jbar/(pbar+1e-6); values[#values+1]=num(msds,"overall")/(rawSR*3.5+1e-6)
	local bpm,dur=num(sub,"bpm",180),num(sub,"dur",120); local bpmExcess=math.max(0,bpm-240)/100
	values[#values+1]=bpmExcess; values[#values+1]=bpmExcess*staminaAgg; values[#values+1]=bpmExcess*speedAgg
	values[#values+1]=staminaAgg/(dpChoke+1e-6); values[#values+1]=jackAgg/(dpChoke+1e-6); values[#values+1]=speedAgg/(dpSR+1e-6)
	values[#values+1]=(dpChoke-dpSR)*(tonumber(purity) or 0); values[#values+1]=(dpMSD-dpSR)*(tonumber(purity) or 0)
	values[#values+1]=math.log(1+math.max(0,dur))/math.log(181); values[#values+1]=bpm/(num(stats,"avg_nps")*12+1e-6)
	for _,v in ipairs({dpSR,dpChoke,dpMSD,modSR,rawSR}) do values[#values+1]=v end
	values[#values+1]=clamp((num(stats,"same_hand_q10")-60)/40,0,1)
	for _,k in ipairs(ridgeSustainKeys) do values[#values+1]=num(stats,k) end
	if #values~=98 then return base,0 end
	local function predict(model)
		local result=0
		for i=1,98 do result=result+(values[i]-model.mean[i])/model.scale[i]*model.beta[i] end
		return clamp(result,-1,1)
	end
	local gate=sigmoid(base,4,10)
	local correction=gate*predict(isorRidge.high)+(1-gate)*predict(isorRidge.low)
	return math.floor((base+correction)*100+0.5)/100, math.floor(correction*1000+0.5)/1000
end

function HV.ISORFinalizeDP(triang, features, msds, sunny, purity, sub, lnRatio, familyConfidence)
	if type(triang)~="table" then return nil end
	local base=triang.dp
	local coef=isorRidge and (isorRidge.lin_base[triang.sk_key] or isorRidge.lin_base.general)
	if coef then
		local linear=coef[1]+coef[2]*triang.dp_sr+coef[3]*triang.dp_choke+coef[4]*triang.dp_msd
		local gate=sigmoid(base,isorRidge.lin_blend.k,isorRidge.lin_blend.x0)
		base=gate*linear+(1-gate)*base
	end
	if base>18.8 then
		local t=clamp((base-18.8)/0.4,0,1); t=0.5*(1-math.cos(math.pi*t))
		local lift=math.min(0.6,math.max(0,20.2-triang.dp_sr))
		base=t*(triang.dp_sr+lift)+(1-t)*base
	end
	local correction=0
	if (tonumber(lnRatio) or 0)<=0.18 and (base>=10.5 or base>=1.2) then
		triang.dp,correction=HV.ISORApplyRidge(base,features,msds,sunny,purity,sub)
	else triang.dp=base end
	triang.dp=math.min(20.5,triang.dp)
	triang.ridge_correction=correction
	triang.dp=math.floor(triang.dp*100+0.5)/100
	local index=clamp(math.floor(triang.dp)-1,0,#isorDanOrder-1)
	local frac=math.floor((triang.dp-math.floor(triang.dp))*100+0.5)/100
	triang.dan=isorDanOrder[index+1]
	triang.sublevel=frac<0.20 and "Low" or frac<0.40 and "Mid-Low" or frac<0.60 and "Mid" or frac<0.80 and "Mid-High" or "High"
	triang.confidence=tonumber(familyConfidence) or 0
	return triang
end

-- Exact upstream VSRG dual-band ridge calibration (sustain_v1, 98 features).
isorRidge = {feature_set="sustain_v1", dual=true, lin_blend={k=8.0,x0=11.0}, lin_base={
  ["jack"]={1.95936532589,0.496902749854,0.117875047712,0.247417756615},
  ["speed"]={1.98999787101,0.623165534831,0.0408025413683,0.197725336956},
  ["tech"]={2.13620078185,0.186231507633,0.41708736949,0.242376038651},
  ["general"]={1.88760414464,0.505558623427,0.121907664518,0.239234483453},
  ["stamina"]={1.88760414464,0.505558623427,0.121907664518,0.239234483453},
}, high={mean={29.4818408535,26.7749679046,18.4825082542,5.63779766073,11.6808548055,2555.54782363,6793.66084774,6.19970332496,0.501144943609,0.211669420768,0.380946711988,0.477671159172,0.467069722706,0.892630388848,0.0135375774207,13.8524701552,161.935374494,31.267308655,28.4761610379,19.5177215422,6.31341619346,12.1894781618,2775.40499009,7464.85907725,0.244176768059,0.257094656359,0.256180670637,0.242547904945,51.4454176113,35.4172959514,15.2509868421,0.872894534413,32.8496172146,25.9390437874,25.9125828239,23.4643722227,30.8953762105,20.4038062571,27.1091291619,27.262894081,0.245914469529,0.13080001511,5.4713517594,18.0935223952,0.0277491060865,0.163000648058,0.755141233598,0.717759414379,0.515993432168,0.231810578211,38.0817051242,0.0173842280364,0.346871144062,2.28239751258,0.859696356275,2.48531470542,38.9982188912,0.549114179997,1.04338407516,0.16608097166,14.6367948718,0.108461538462,0.751234817814,0.312429149798,16.0281216599,1.4543927653,1.14947587874,0.097475708502,279.325419412,3.06488127585,172.314909615,1.24828661782,1.97982168747,-0.122405981781,-0.176637004049,0.96517586638,1.29384595712,14.8891497976,14.7748582996,14.2463765182,8.34603360324,8.17995263158,0.287145748988,17.7975708502,18.6538461538,19.4825910931,16.8960020243,18.0723684211,18.7279352227,0.858296576029,0.867758549332,61.5344129555,64.9767206478,74.8755060729,70.7636639676,90.8127530364,105.824392713,140.755060729},scale={14.4309309582,13.5303246021,5.36948598335,3.28989596819,4.07383677761,1433.24459315,8352.62959465,0.749598274848,0.266618688174,0.196033684455,0.223496080843,0.231504762944,0.131260782613,0.0596954335162,0.0115559510402,4.05724345012,78.5159743846,15.1232486239,14.2042054618,5.86794553452,3.57096015386,4.22344412691,1566.57359304,9170.47687157,0.0480562746806,0.0289971202152,0.017613360311,0.0259092956149,10.66917978,5.6019015487,2.41832783641,0.0446958496756,3.60358364718,6.68097062081,4.25840991028,5.85676651874,3.52972285926,3.51265671893,5.03204477961,4.92557902176,0.162631527645,0.032807433544,5.18339960761,14.8970662761,0.0173862299469,0.0583505450011,1.20147435592,0.32011097598,0.440227163634,0.0983586159252,22.8674030309,0.0265891785369,0.234990936993,0.759730734911,0.714222000288,0.151374172198,9.31056057572,0.0157279335549,0.110805853508,0.183727567752,1.52814280383,0.278599849338,0.771657539208,0.57829584387,7.79987724116,0.20977189939,0.0555627074602,0.223598898173,714.181106725,7.49676623166,89.8315467419,0.309071860487,0.918076596995,0.670298335023,0.37229585615,0.0784519051925,0.394523111617,1.5683847921,1.70247399172,1.70917719033,1.06974936173,0.940570886135,0.386996703336,6.33570901116,6.74008609075,6.96624456409,5.96415430695,6.5605210074,6.71145155473,0.14388926014,0.0926186317591,25.3585987852,23.9965408391,26.4124467892,21.1272398505,15.9197080553,17.9118301987,33.3174481756},beta={-0.0392781148699,-0.0500561406538,0.0249568305591,-0.0217259781529,0.046382903976,0.0565523692015,0.00985057652946,0.0333741455076,-0.0198380491904,-0.0563002287701,-0.0398118193236,-0.00183400902576,-0.060689102212,-0.0159086813829,0.0197062541195,0.0419727280499,0.0126601859378,-0.0310732255277,-0.0529101927562,-0.030596780288,-0.130801202205,0.0453731935672,0.0546447215997,0.0299737914832,0.00813469018059,0.0568287564704,-0.0989733380665,-0.0114067216903,0.0733697388393,0.0570745531132,-0.0301920256879,-0.141593386761,-0.0456121845117,-0.0128201441095,-0.0476549155866,0.0986835321528,0.0267241749059,0.0750371845555,0.095665820926,0.0859316059908,-0.0363797004892,-0.0213337102439,-0.00940612034542,-0.0739782781846,0.011052017403,-0.0701013958481,0.0212806503044,-0.00322971817868,-0.0214192176331,0.0785549355073,-0.0802090574085,-0.00154256245686,0.00117163010563,0.0045876309581,-0.0253142505664,0.0613214780461,-0.0113679535648,0.0602447718439,0.0691427008297,-0.145845044945,0.0001508086255,-0.0117665251825,-0.0191818802774,0.00751429667406,0.0593687429042,0.000155621314629,-0.0482336978849,-0.0667481914988,-0.0584829465722,0.0955075902554,0.00865050035023,-0.00466362554486,-0.0824629946595,-0.0643932772424,-0.00883481852529,-7.7487956098e-05,0.0212343626775,-0.0172227776753,0.0253698830854,-0.00906181774613,-0.0469119882712,-0.0248660834383,-0.0222402599564,-0.0253209373163,-0.0243591576535,-0.0546742085953,-0.0714506057832,0.0140147947903,-0.0950737056657,0.00514832381389,-0.053214420821,-0.0856493475018,0.0470013079198,-0.0287240519583,0.0377388450761,-0.110833988233,0.0671246148997,0.000255383817372}}, low={mean={16.6062177397,14.8023658574,8.762204444,1.96241497745,8.02307192646,872.895100692,1880.67749252,4.96694343213,0.381325742578,0.0841119742009,0.286283621322,0.553911928336,0.125405794549,0.597865319629,0.0217675234891,9.80533446021,157.200867725,18.0454451022,16.1035816311,9.53358557348,2.26165461095,8.47326532596,955.752656236,2078.35410936,0.200431427507,0.272244779525,0.251027700248,0.276296092721,27.9690079365,22.2442296296,8.69778518519,0.9652,21.7347044444,18.7226052593,19.0701290423,14.8432116212,20.6066986984,12.0233862635,15.1660477937,20.6259380688,0.0591431947492,0.142564642917,6.05608183588,11.0645596893,0.0424043634239,0.175705531095,0.767288129067,0.141348736761,0.505398629889,0.243351223185,26.3877411003,0.00252272148148,0.41134728542,1.77680293135,0.935026455026,2.22032030839,25.3895606453,0.842657712918,1.13850956004,0.0149920634921,6.9923633157,0.328941798942,0.606084656085,0.688253968254,5.82329047619,1.25347725191,1.26386288058,0.00932698412698,6.64341200132,0.149116302017,120.059600506,1.28894115554,2.64543913874,0.222412058201,-0.118281851852,0.949919752817,1.50624997299,6.93063492063,7.39296296296,6.65349206349,5.00160634921,4.98661428571,0.510582010582,11.9735449735,13.3544973545,14.2645502646,11.2010582011,12.498015873,13.3611111111,0.796269925238,0.768108405388,82.0330687831,89.5529100529,121.099206349,100.55026455,152.468253968,182.365079365,245.105820106},scale={7.54611444899,6.72662869223,3.38478520201,1.25982751225,2.35974089387,516.751901215,2954.96007795,0.847958482107,0.182935294405,0.101239803846,0.120011456703,0.136321449958,0.116740490324,0.209227677737,0.0199331514589,2.58075666882,110.125899571,8.20641108018,7.25522532625,3.84892839775,1.39894909206,2.48630420585,567.13152237,3266.15064794,0.0242967570063,0.0158219760195,0.0143092558668,0.0191971708123,7.45180027811,4.56589753744,2.27283960618,0.0313153663449,3.93735869158,4.31459979449,3.84117587518,4.63881843381,3.71204284703,2.7585297137,3.90739335584,3.41779395103,0.083145128903,0.0223671908582,4.37152546193,6.91936982798,0.0282128245632,0.0750845158471,1.23739912783,0.121796634219,0.369315191823,0.117176726796,20.0615804695,0.00798649105778,0.149016686145,0.363266808967,0.732617705904,0.192668524391,8.45144606265,0.355539167873,0.307639261749,0.0349625270368,2.81827899122,0.590865155119,0.765728558719,0.902678916617,4.53888008666,0.214790635326,0.100835195266,0.0487204221698,37.0026272034,0.814350508034,48.3560674373,0.438893059856,1.03271915235,0.719583533919,0.63730765428,0.0921020488543,0.490962802027,2.97320976664,3.04837483004,2.72425291466,1.14572132699,1.13806943631,0.399595271294,3.58041980104,4.12583079801,4.282839195,3.43667951313,3.81730227497,4.05935894714,0.13016661988,0.0770760495416,26.9047512395,29.9172996705,51.5175884273,31.2659925205,43.5299452681,54.824385796,64.7338010052},beta={0.00113283174195,0.0139079156745,0.00596694180969,-0.0018012658494,0.0191203596202,0.00606273609754,-0.0400967340703,0.0280844414207,-0.0743707488683,0.0764993913371,-0.0327871775506,0.0164187617926,-0.0213973561635,0.0754907238675,-0.033320295229,-0.118984397704,-0.0465252938307,0.00213362139229,0.0189564716756,0.00320738625705,-0.00529621201565,0.0406914284762,0.00206357197356,-0.0411110410051,-0.0352347338707,-0.0527843570279,-0.0842379708207,0.150888133707,0.061429282841,0.123669867713,0.0626489066231,-0.0613527721783,-0.0149715281552,-0.0365776332432,-0.0890749602876,0.00430225488818,0.0190173542015,0.0744260569694,-0.000986519274139,0.0991617815072,-0.0279601057033,0.0990051255069,0.0224500530391,0.0158293844897,0.0348005006181,-0.0227863954715,0.0621572854373,-0.0852807262926,-0.0360195023178,-0.0166903811984,-0.0532642286171,-0.0140970121006,0.000159464530714,-0.0149989994544,0.0732861352555,0.0271647207721,0.0263072863713,0.0261085062748,-0.0353573786197,-0.0569049145767,-0.0873251200683,0.0990408659087,-0.00630651195876,-0.0347648849697,-0.0231587925518,0.0850268555481,-0.0459314205028,0.0383344994757,7.55840132051e-05,0.0108011058181,0.0640084417511,0.101839961651,0.00494545586476,-0.0162233930089,0.0636311142415,0.00831351612914,-0.0795279163105,-0.0926582575965,-0.0822351803431,-0.0778721984266,0.00693033408775,0.00872510135595,0.045840459978,-0.000436070911573,-0.0241090494414,-0.0179296756188,-0.0333164719216,-0.0123179570503,-0.0415224656172,0.0273005574302,-0.048599138752,0.0883433919289,0.0584325065388,0.174782355281,-0.0364248843069,-0.0632956916553,0.0169617446091,-0.0592687393437}}}
