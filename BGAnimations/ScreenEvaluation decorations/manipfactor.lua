--Version: 09.16.24 19:34
--For Til Death, tailored for Holographic Void
local t = Def.ActorFrame {}

-- Do not expose replay-derived analysis for CPU/autoplay evaluations.
if HV.EvaluationScoringVoided then return t end

local score = SCOREMAN:GetMostRecentScore()
if not score then
    score = SCOREMAN:GetTempReplayScore()
end

local aspectRatio = GetScreenAspectRatio()

local mfDisplayX = 0
local mfDisplayY = 0
local mfDisplayZoom = 0.45

local td = {} -- chart timing data
local dvt = {} -- offset vector
local ctt = {} -- track vector
local nrt = {} -- noterow vector
local wuab = {} -- note timing vector
local ntt = {} -- note type vector

-- key data
local key0Data
local key1Data
local key2Data
local key3Data

-- deviations
local k0to1 = {}
local k1to0 = {}
local k2to3 = {}
local k3to2 = {}

local mf = {} -- manip factor

-- filter table by percentiles
local function FilterTable(low, high, x, eps)
    local y = {}
    for i = 1, #x do
        if x[i] > (low - eps) and x[i] < (high + eps) and x[i] ~= 0 then
            table.insert(y, x[i])
        end
    end
    return y
end

-- filter deviations table by time
local function FilterTableByTime(x, time)
    local y = {}
    for i = 1, #x do
        if x[i][1] <= time then
            table.insert(y, x[i])
        end
    end
    return y
end

-- Helper function to calculate Arithmetic Mean
local function ArithmeticMean(x)
    local sum = 0
    for i = 1, #x do
        sum = sum + x[i]
    end
    return sum / #x
end

local function ArithmeticMeanForDeviatons(x)
    local sum = 0
    for i = 1, #x do
        sum = sum + x[i][2]
    end
    return sum / #x
end

-- Helper function to calculate Weighted Mean
local function WeightedMean(x, w)
    local sump = 0
    local sum = 0
    for i = 1, #x do
        sump = sump + (x[i] * w[i])
        sum = sum + w[i]
    end
    return sump / sum
end

-- Helper function to calculate the 5th and 95th percentiles
local function Percentile(sortedArray, p)
    local index = (p / 100) * (#sortedArray - 1) + 1
    local lowerBound = math.floor(index)
    local upperBound = math.ceil(index)
    local fracPart = index - lowerBound

    if fracPart == 0 then
        return sortedArray[lowerBound]
    else
        return sortedArray[lowerBound] + fracPart * (sortedArray[upperBound] - sortedArray[lowerBound])
    end
end

-- mf value to theme-appropriate color
local function byMF(x)
    if x > 0.4 then
        x = 0.4
    end
    local p = x / 0.4
    -- Lerp between W3 and Miss
    return HV.LerpColor(p, HVColor.GetJudgmentColor("W3"), HVColor.GetJudgmentColor("Miss"))
end

-- Generate key data
local function GenerateKeyData(offsetVector, timingVector, trackVector, trackNum, tntypeVector)
    local keyData = {}
    for i = 1, #offsetVector do
        if trackVector[i] == trackNum and tntypeVector[i] ~= "TapNoteType_Mine" and tntypeVector[i] ~= "TapNoteType_HoldTail" then
            table.insert(keyData, {timingVector[i], offsetVector[i]})
        end
    end
    if #keyData >= 2 then -- Throw out tracks(keys) which have less than 2 notes to avoid nil values
        return keyData
    else
        return false
    end
end

-- Function to calculate deviations
local function CalculateDeviations(keyAData, keyBData)
    if keyAData and keyBData then
        local eps = 0.1
        local deviations = {}

        -- Extract time values from key data
        local timesA = {}
        local timesB = {}
        for i = 1, #keyAData do
            table.insert(timesA, keyAData[i][1])
        end
        for i = 1, #keyBData do
            table.insert(timesB, keyBData[i][1])
        end

        -- Sort the note times for both keys
        table.sort(timesA)
        table.sort(timesB)

        -- Compute differences between sorted note times
        local diffA = {}
        local diffB = {}
        for i = 2, #timesA do
            local diff = timesA[i] - timesA[i - 1]
            if diff ~= 0 then
                table.insert(diffA, diff)
            end
        end
        for i = 2, #timesB do
            local diff = timesB[i] - timesB[i - 1]
            if diff ~= 0 then
                table.insert(diffB, diff)
            end
        end

        -- Calculate percentiles (5th and 95th) for both columns
        table.sort(diffA)
        table.sort(diffB)

        local lowerPercentileA = Percentile(diffA, 5)
        local upperPercentileA = Percentile(diffA, 95)
        local lowerPercentileB = Percentile(diffB, 5)
        local upperPercentileB = Percentile(diffB, 95)

        -- Filter differences outside the 5th and 95th percentiles
        local filteredDiffA = FilterTable(lowerPercentileA, upperPercentileA, diffA, eps)
        local filteredDiffB = FilterTable(lowerPercentileB, upperPercentileB, diffB, eps)

        -- Calculate arithmetic mean of filtered differences for A and B columns
        local k0AvgInterval = ArithmeticMean(filteredDiffA)
        local k1AvgInterval = ArithmeticMean(filteredDiffB)

        -- Average of averages
        local avgInterval = (k0AvgInterval + k1AvgInterval) / 2
        -- Halve the interval (for trills)
        avgInterval = avgInterval / 2

        table.sort(keyAData, function(a, b) return a[1] < b[1] end)
        table.sort(keyBData, function(a, b) return a[1] < b[1] end)
        -- Calculate deviations
        local finder = 1
        for i = 1, #keyAData do
            local timeA, errorA = keyAData[i][1], keyAData[i][2]

            -- Find the closest previous note in keyBData
            local lastKeyBItem
            for j = finder, #keyBData do
                if keyBData[j][1] < (timeA - eps) then
                    lastKeyBItem = keyBData[j]
                    finder = j
                else
                    break
                end
            end

            -- Add deviations if conditions are met
            if lastKeyBItem then
                local errorB = lastKeyBItem[2]
                local deviation = (errorB - errorA) / avgInterval
                local absDeviation = math.abs(deviation)
                if absDeviation <= 1.5 then
                    table.insert(deviations, {timeA, absDeviation})
                end
            end
        end

        return deviations
    else
        return {0}
    end
end

-- Get manip factor based on key comparisons
local function GetManipFactor()
    -- Generate data for all keys
    key0Data = GenerateKeyData(dvt, wuab, ctt, 0, ntt)
    key1Data = GenerateKeyData(dvt, wuab, ctt, 1, ntt)
    key2Data = GenerateKeyData(dvt, wuab, ctt, 2, ntt)
    key3Data = GenerateKeyData(dvt, wuab, ctt, 3, ntt)

    -- Calculate deviations between keys
    k0to1 = CalculateDeviations(key0Data, key1Data)
    k1to0 = CalculateDeviations(key1Data, key0Data)
    k2to3 = CalculateDeviations(key2Data, key3Data)
    k3to2 = CalculateDeviations(key3Data, key2Data)

    local mfk0to1
    local mfk1to0
    local mfk2to3
    local mfk3to2

    -- Calculate the mean manip factors
    if key0Data ~= false and key1Data ~= false then
        mfk0to1 = ArithmeticMeanForDeviatons(k0to1)
        mfk1to0 = ArithmeticMeanForDeviatons(k1to0)
    else
        mfk0to1 = 0
        mfk1to0 = 0
    end
    if key2Data ~= false and key3Data ~= false then
        mfk2to3 = ArithmeticMeanForDeviatons(k2to3)
        mfk3to2 = ArithmeticMeanForDeviatons(k3to2)
    else
        mfk2to3 = 0
        mfk3to2 = 0
    end

    -- Final manip factor
    local mftotal = WeightedMean({mfk0to1, mfk1to0, mfk2to3, mfk3to2}, {#k0to1, #k1to0, #k2to3, #k3to2})

    -- Right/Left mf
    local mfleft = WeightedMean({mfk0to1, mfk1to0}, {#k0to1, #k1to0})
    local mfright = WeightedMean({mfk2to3, mfk3to2}, {#k2to3, #k3to2})

    if mftotal ~= mftotal then -- x ~= x means that x == NaN
        mftotal, mfleft, mfright = 0, 0, 0
    end

    return {mftotal, mfleft, mfright}
end

-- Get manip factor based on key comparisons and row time
function GetManipFactorForRow(time)
    local tk0to1 = {}
    local tk1to0 = {}
    local tk2to3 = {}
    local tk3to2 = {}

    if key0Data ~= false and key1Data ~= false then
        tk0to1 = FilterTableByTime(k0to1, time)
        tk1to0 = FilterTableByTime(k1to0, time)
    end
    if key2Data ~= false and key3Data ~= false then
        tk2to3 = FilterTableByTime(k2to3, time)
        tk3to2 = FilterTableByTime(k3to2, time)
    end

    local mfk0to1
    local mfk1to0
    local mfk2to3
    local mfk3to2

    -- Calculate the mean manip factors
    if key0Data ~= false and key1Data ~= false then
        mfk0to1 = ArithmeticMeanForDeviatons(tk0to1)
        mfk1to0 = ArithmeticMeanForDeviatons(tk1to0)
    else
        mfk0to1 = 0
        mfk1to0 = 0
    end
    if key2Data ~= false and key3Data ~= false then
        mfk2to3 = ArithmeticMeanForDeviatons(tk2to3)
        mfk3to2 = ArithmeticMeanForDeviatons(tk3to2)
    else
        mfk2to3 = 0
        mfk3to2 = 0
    end

    -- Final manip factor
    local mftotal = WeightedMean({mfk0to1, mfk1to0, mfk2to3, mfk3to2}, {#tk0to1, #tk1to0, #tk2to3, #tk3to2})

    if mftotal ~= mftotal then -- x ~= x means that x == NaN
        mftotal = 0
    end

    return mftotal
end

-- Manip factor display
t[#t + 1] = Def.ActorFrame {
    -- First Text Element (MF label)
    LoadFont("Common Normal") .. {
        Name = "MFText",
        InitCommand = function(self)
            self:xy(mfDisplayX, mfDisplayY)
            self:zoom(mfDisplayZoom)
            self:halign(0)
            self:settext("MF:")
            self:diffuse(HVColor.TextSub)
        end,
        MouseOverCommand = function(self)
            local mfd = self:GetParent():GetChild("ManipFactor")
            if aspectRatio < 1.6 then
                mfd:settextf("(L: %2.1f%% R: %2.1f%%) %2.1f%%", mf[2] * 100, mf[3] * 100, mf[1] * 100)
            else
                mfd:settextf("%2.1f%% (L: %2.1f%% R: %2.1f%%)", mf[1] * 100, mf[2] * 100, mf[3] * 100)
            end
        end,
        MouseOutCommand = function(self)
            self:GetParent():GetChild("ManipFactor"):settextf("%2.1f%%", mf[1] * 100)
        end
    },
    -- Second Text Element (Value)
    LoadFont("Common Normal") .. {
        Name = "ManipFactor",
        InitCommand = function(self)
            self:xy(mfDisplayX + 35, mfDisplayY)
            self:zoom(mfDisplayZoom)
            self:halign(0)
            self:maxwidth(480)
            self:queuecommand("Set")
        end,
        GetScoreMessageCommand = function(self, params)
            if params.score then
                score = params.score
            end
            self:queuecommand("Set")
        end,
        SetCommand = function(self)
            -- Get replay data
            local replay
            if score["GetReplay"] == nil then -- for better compatibility
                replay = score
            else
                replay = score:GetReplay()
            end
            local rate = SCREENMAN:GetTopScreen():GetReplayRate()
            td = GAMESTATE:GetCurrentSteps():GetTimingData()
            dvt = replay:GetOffsetVector()
            ctt = replay:GetTrackVector()
            nrt = replay:GetNoteRowVector()
            ntt = replay:GetTapNoteTypeVector()
            -- Convert noterows to timing in ms
            for i = 1, #nrt do
                wuab[i] = td:GetElapsedTimeFromNoteRow(nrt[i]) / rate * 1000
            end
            --------------------

            mf = GetManipFactor()

            self:diffuse(byMF(mf[1]))
            self:settextf("%2.1f%%", mf[1] * 100)
        end,
        MouseOverCommand = function(self)
            if aspectRatio < 1.6 then
                self:settextf("(L: %2.1f%% R: %2.1f%%) %2.1f%%", mf[2] * 100, mf[3] * 100, mf[1] * 100)
            else
                self:settextf("%2.1f%% (L: %2.1f%% R: %2.1f%%)", mf[1] * 100, mf[2] * 100, mf[3] * 100)
            end
        end,
        MouseOutCommand = function(self)
            self:settextf("%2.1f%%", mf[1] * 100)
        end
    }
}

return t
