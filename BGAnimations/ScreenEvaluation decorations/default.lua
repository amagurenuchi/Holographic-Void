--- Holographic Void: ScreenEvaluation Decorations
-- Full-featured evaluation screen ported from spawncamping-wallhack.
-- Features: Life/Combo graphs, Avatar+Player info, Grade+Score with rescoring (needs testing to ensure nothing breaks),
--   ClearType comparison, Tap/Hold/Mine judgments, Timing stats (mean/sd),
--   CB L/R breakdown, Paginated Local/Online Scoreboard, Full Offset Plot.

local song = GAMESTATE:GetCurrentSong()
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
local steps = GAMESTATE:GetCurrentSteps()
local pn = GAMESTATE:GetEnabledPlayers()[1]
local profile = PROFILEMAN:GetProfile(pn)

-- State variables (declared early for function visibility)
local curScore = pss:GetHighScore()
local judge = 4
local judges = HV.EmulateRidiculousEnabled() and {"Ridiculous","TapNoteScore_W1","TapNoteScore_W2","TapNoteScore_W3","TapNoteScore_W4","TapNoteScore_W5","TapNoteScore_Miss"} or {"TapNoteScore_W1","TapNoteScore_W2","TapNoteScore_W3","TapNoteScore_W4","TapNoteScore_W5","TapNoteScore_Miss"}

-- Rescoring/offset plot state
local nrv, dvt, ctt, ntt, totalTaps
local rescoredPercentage
local usingCustomWindows = false
local lastSnapshot = nil
local showRATally = false

local function roundTo(value, places)
	if value == nil then return 0 end
	if notShit and type(notShit.round) == "function" then
		return notShit.round(value, places)
	end
	local scale = 10 ^ (places or 0)
	return math.floor(value * scale + 0.5) / scale
end

local function getJudgeForScore(score)
	local playedJudge = 4
	local norm = PREFSMAN:GetPreference("SortBySSRNormPercent")
	if not norm and score and type(score.GetJudgeScale) == "function" then
		local scale = score:GetJudgeScale()
		if scale then
			scale = roundTo(scale, 2)
			for k, v in pairs(ms.JudgeScalers) do
				if roundTo(v, 2) == scale then
					playedJudge = k
					if playedJudge >= 4 then break end
				end
			end
		end
	else
		playedJudge = GetTimingDifficulty()
	end
	return math.max(4, math.min(9, playedJudge))
end

local function formatWifePercent(pct)
	local precision = pct >= 99 and 4 or 2
	local rounded = roundTo(pct, precision)
	return string.format("%." .. precision .. "f%%", rounded)
end

local evalModShorthands = {
	-- Turn
	["Mirror"] = "MIR", ["Back"] = "BAK", ["Left"] = "LFT", ["Right"] = "RGT",
	["Shuffle"] = "SHU", ["SoftShuffle"] = "SSH", ["SuperShuffle"] = "XSH",
	-- Appearance
	["Hidden"] = "HID", ["Sudden"] = "SUD", ["Stealth"] = "STL", ["Blink"] = "BLK", ["RandomVanish"] = "RVN",
	-- Hide
	["Dark"] = "DRK", ["Blind"] = "BLN", ["Cover"] = "COV",
	-- Remove
	["NoMines"] = "NOM", ["NoHolds"] = "NOH", ["NoRolls"] = "NOR", ["NoLifts"] = "NOL", ["NoFakes"] = "NOF",
	-- Other
	["Reverse"] = "REV", ["Mines"] = "MNS",
}

local function formatEvalSpeedMode(mode, speed)
	mode = mode or "C"
	speed = speed or 400
	if mode == "x" then
		return string.format("%.2fx", speed / 100)
	end
	return mode .. tostring(speed)
end

local function formatEvalRateValue(rate)
	local formatted = string.format("%.2f", tonumber(rate) or 1):gsub("%.?0+$", "") .. "x"
	if formatted == "1x" then formatted = "1.0x" end
	if formatted == "2x" then formatted = "2.0x" end
	return formatted
end

local function hasEvaluationAssistEnabled(po, modStr)
	local normalizedModStr = (modStr or ""):lower():gsub("[%s_]+", "")
	if po then
		if po.AssistClap and po:AssistClap() then return true end
		if po.AssistTick and po:AssistTick() then return true end
	end
	return string.find(normalizedModStr, "assistclap")
		or string.find(normalizedModStr, "assisttick")
		or string.find(normalizedModStr, "autoplay")
end

local function setDPTextActors(wholeActor, decimalActor, dp, precision)
	local roundedDp = roundTo(dp, precision)
	local format = "%0." .. precision .. "f"
	local formatted = string.format(format, roundedDp)
	local whole, decimal = formatted:match("^(%-?%d+)%.(%d+)$")
	if wholeActor and whole then
		wholeActor:settext(whole)
	end
	if decimalActor and decimal then
		decimalActor:settext("." .. decimal)
		decimalActor:x(wholeActor:GetWidth() * wholeActor:GetZoom() + 1)
	end
end

-- Filter the module-level dvt by tap note type, mirroring getRescoreElementsFromScore.
-- Without this, mine-hit offsets pass through wife3() giving ~+2 pts each while
-- minesHit*-7 is ALSO applied, netting -5 per mine instead of the correct -7.
local function getFilteredDvt()
	if not dvt then return {} end
	if ntt and #ntt == #dvt then
		local out = {}
		for i = 1, #dvt do
			local ty = ntt[i]
			if ty == "TapNoteType_Tap" or ty == "TapNoteType_HoldHead" or ty == "TapNoteType_Lift" then
				out[#out + 1] = dvt[i]
			end
		end
		return out
	end
	return dvt -- no type vector: return as-is (PSS path, already clean)
end

local function refreshRescoredPercentage()
	local rst = getRescoreElements(pss, curScore)
	if not rst then
		rescoredPercentage = nil
		return
	end
	rst.dvt = getFilteredDvt()
	rescoredPercentage = getRescoredWife3Judge(3, judge, rst)
end

local function calculateCustomWindowScore(configName, rst)
	if not customWindowsConfig or not rst then return 0 end
	local config = customWindowsConfig:get_data().customWindowConfigs[configName]
	if not config then return 0 end
	
	local pts = 0
	local dvt = rst.dvt
	
	local curveFunc = config.customWindowCurveFunction
	local worths = config.customWindowWorths
	local windows = config.customWindowWindows
	
	local function getCurveWorth(offset)
		if curveFunc then return curveFunc(offset / 1000) end
		if worths and windows then
			local ms = math.abs(offset)
			if ms <= (windows.W1 or 22.5) then return worths.W1 or 2
			elseif ms <= (windows.W2 or 45) then return worths.W2 or 2
			elseif ms <= (windows.W3 or 90) then return worths.W3 or 1
			elseif ms <= (windows.W4 or 135) then return worths.W4 or 0
			elseif ms <= (windows.W5 or 180) then return worths.W5 or -4
			else return worths.Miss or -8 end
		end
		return 0
	end
	
	-- Calculate tap/hit points
	if dvt then
		for i=1, #dvt do
			pts = pts + getCurveWorth(dvt[i])
		end
	end
	
	-- Penalty for unplayed notes
	local missWorth = 0
	if worths and worths.Miss then missWorth = worths.Miss
	elseif curveFunc then missWorth = curveFunc(1.000) end
	if not missWorth or missWorth == 0 then missWorth = -8 end
	
	local maxNotes = math.max(0, tonumber(rst.totalNotes) or 0)
	maxNotes = math.max(maxNotes, tonumber(rst.notesPassed) or 0)
	local unplayed = math.max(0, maxNotes - (tonumber(rst.notesPassed) or 0))
	pts = pts + (unplayed * missWorth)
	
	-- Hold/Roll scoring
	local holdWorths = config.customWindowHoldWorths or {}
	local heldWorth = holdWorths.Held or 0
	local letGoWorth = holdWorths.LetGo or -4.5
	local missedHoldWorth = holdWorths.Missed or -4.5
	
	local totalHolds = rst.totalHolds or 0
	local totalRolls = rst.totalRolls or 0
	local totalLongNotes = totalHolds + totalRolls
	local longNotesMissed = (rst.holdsMissed or 0) + (rst.rollsMissed or 0)
	
	-- Penalize missed long notes
	pts = pts + (longNotesMissed * missedHoldWorth)
	-- Reward successfully held long notes
	pts = pts + (totalLongNotes - longNotesMissed) * heldWorth
	
	-- Mine penalties
	local mineHitWorth = config.customWindowMineHitWorth or -2
	pts = pts + (rst.minesHit or 0) * mineHitWorth
	
	-- Max points calculation
	local tapTypeWorths = config.customWindowTapNoteTypeWorths or {}
	local tapWorth = tapTypeWorths.Tap or 2
	local holdHeadWorth = tapTypeWorths.HoldHead or 2
	local liftWorth = tapTypeWorths.Lift or tapWorth
	local mineWorth = tapTypeWorths.Mine or 0
	
	-- RadarCategory_Notes = Taps + HoldHeads + RollHeads + Lifts
	-- We approximate RollHeads as using HoldHead worth
	local others = maxNotes - totalLongNotes
	if others < 0 then others = 0 end
	
	local maxPts = (others * tapWorth) + (totalLongNotes * holdHeadWorth)
	-- Plus completion points for every long note
	maxPts = maxPts + (totalLongNotes * heldWorth)
	-- Plus mine points if hit (usually 0)
	local totalMines = rst.totalMines or 0
	maxPts = maxPts + (totalMines * mineWorth)
	
	if maxPts <= 0 then return 0 end
	return math.max(0, math.min(100, (pts / maxPts) * 100))
end

local function updateVectors()
	local replay = curScore and curScore:GetReplay() or nil
	local hasReplay = replay and replay:LoadAllData()

	if hasReplay then
		nrv = replay:GetNoteRowVector()
		ctt = replay:GetTrackVector()
		ntt = replay:GetTapNoteTypeVector()
		dvt = replay:GetOffsetVector()
		totalTaps = 0
		if ntt then
			for _, typ in ipairs(ntt) do
				if typ == "TapNoteType_Tap" or typ == "TapNoteType_HoldHead" or typ == "TapNoteType_Lift" then
					totalTaps = totalTaps + 1
				end
			end
		end
	else
		nrv = pss:GetNoteRowVector()
		ctt = pss:GetTrackVector()
		ntt = pss:GetTapNoteTypeVector()
		dvt = pss:GetOffsetVector()
		totalTaps = pss:GetTotalTaps()
	end
	songTotalNotes = steps:GetRadarValues(pn):GetValue("RadarCategory_Notes")
end
judge = getJudgeForScore(curScore)
updateVectors()
refreshRescoredPercentage()

-- Local timing helpers (to avoid nil global issues if scripts haven't reloaded)
local function localWifeMean(dvt) return wifeMean(dvt) end
local function localWifeAbsMean(dvt) return wifeAbsMean(dvt) end
local function localWifeSd(dvt) return wifeSd(dvt) end
local function localWifeMax(dvt) return wifeMax(dvt) end

local function getKeycountLabelForSteps(curSteps)
	if not curSteps then return nil end

	local st = tostring(curSteps:GetStepsType() or ""):lower()
	local stepsTypeToKeys = {
		stepstype_dance_single = 4,
		stepstype_dance_double = 8,
		stepstype_pump_single = 5,
		stepstype_pump_halfdouble = 6,
		stepstype_pump_double = 10,
		stepstype_kb7_single = 7,
		stepstype_beat_single5 = 5,
		stepstype_beat_single7 = 7,
		stepstype_popn_five = 5,
		stepstype_popn_nine = 9,
	}

	local keys = stepsTypeToKeys[st]
	if not keys then
		local style = GAMESTATE:GetCurrentStyle()
		if style and style.ColumnsPerPlayer then
			keys = tonumber(style:ColumnsPerPlayer())
		end
	end

	if not keys or keys <= 0 then return nil end
	return tostring(math.floor(keys + 0.5)) .. "K"
end

-- LA/RA Ratio calculation (ported from Til Death)
-- Calculates Ludicrous Attack and Ridiculous Attack ratios from replay offsets
local function calculateRatios(score)
	local replay = score:GetReplay()
	if not replay then return -1, -1, -1, -1 end
	pcall(function() replay:LoadAllData() end)
	local offsetTable = replay:GetOffsetVector()
	local typeTable = replay:GetTapNoteTypeVector()
	if not offsetTable or #offsetTable == 0 or not typeTable or #typeTable == 0 then
		return -1, -1, -1, -1
	end

	-- Define judgment windows based on current judge
	local marvWindow = 22.5 * (ms.JudgeScalers[judge] or 1)
	local raThreshold = marvWindow / 2
	local laThreshold = raThreshold / 2

	local ludic = 0
	local ridicLA = 0
	local ridic = 0
	local marvRA = 0

	for i, o in ipairs(offsetTable) do
		if typeTable[i] == "TapNoteType_Tap" or typeTable[i] == "TapNoteType_HoldHead" then
			local off = math.abs(o) -- Already ms
			if off <= raThreshold then
				ridic = ridic + 1
			elseif off <= marvWindow then
				marvRA = marvRA + 1
			end
			if off <= laThreshold then
				ludic = ludic + 1
			elseif off <= raThreshold then
				ridicLA = ridicLA + 1
			end
		end
	end

	local ra = marvRA > 0 and (ridic / marvRA) or -1
	local la = ridicLA > 0 and (ludic / ridicLA) or -1
	return ra, la, ridic, marvRA, ludic, ridicLA
end

local hjudges = {"HoldNoteScore_Held","HoldNoteScore_LetGo","HoldNoteScore_MissedHold"}
local rate = getCurRate()

-- Cache for RA/LA ratios to avoid repeated replay loading
local cachedRatios = nil
local function clearRatioCache() cachedRatios = nil end
local function getRatios()
	if not cachedRatios then
		local ra, la, ridic, marvRA, ludic, ridicLA = calculateRatios(curScore)
		cachedRatios = {ra, la, ridic, marvRA, ludic, ridicLA}
	end
	return unpack(cachedRatios)
end

-- a helper to get the radar value for a score and fall back to playerstagestats if that fails
local function gatherRadarValue(radar, score)
    local n = score:GetRadarValues():GetValue(radar)
    if n == -1 then
        return pss:GetRadarActual():GetValue(radar)
    end
    return n
end

local songTotalNotes = steps:GetRadarValues(pn):GetValue("RadarCategory_Notes")
local songMaxPoints = songTotalNotes * 2

local function getRunningWife(wife, judged)
	if judged == 0 then return 0 end
	return wife * (songTotalNotes / judged)
end

local function clampJudge()
	if judge < 4 then judge = 4 end
	if judge > 9 then judge = 9 end
end
clampJudge()

local hsTable = getScoreTable(pn, rate)
local scoreIndex = 0
if hsTable then
	scoreIndex = getHighScoreIndex(hsTable, curScore)
end
local recScore = getBestScore(pn, scoreIndex, rate, true)
local clearType = getClearType(pn, steps, curScore)

local tracks = pss:GetTrackVector()
local devianceTable = pss:GetOffsetVector()
local cbl, cbr, cbm = 0, 0, 0
local tst = ms.JudgeScalers
local ncol = steps and steps:GetNumColumns() or 4
local middleCol = (ncol - 1) / 2
local showMiddle = middleCol == math.floor(middleCol)

local function recountCBs()
	local tso = tst[judge] or 1
	cbl, cbr, cbm = 0, 0, 0
	if not ctt or not dvt then return end
	for i = 1, #dvt do
		if ctt[i] then
			if math.abs(dvt[i]) > tso * 90 then
				if ctt[i] < middleCol then cbl = cbl + 1
				elseif ctt[i] > middleCol then cbr = cbr + 1
				else cbm = cbm + 1 end
			end
		end
	end
end
recountCBs()

local function getStatInfo()
	return {
		wifeMean(dvt),
		wifeAbsMean(dvt),
		wifeSd(dvt),
		wifeMax(dvt),
		cbl, cbr, cbm
	}
end

local accentColor = HVColor.Accent
local brightText = color("1,1,1,1")
local dimText = brightText
local subText = brightText
local mainText = brightText
local bgCard = color("0.06,0.06,0.06,0.7")
local dividerColor = color("0.2,0.2,0.2,1")

local judgmentColors = {
	HV.EmulateRidiculousEnabled() and HVColor.GetJudgmentColor("Ridiculous") or nil,
	HVColor.GetJudgmentColor("W1"), HVColor.GetJudgmentColor("W2"), HVColor.GetJudgmentColor("W3"),
	HVColor.GetJudgmentColor("W4"), HVColor.GetJudgmentColor("W5"), HVColor.GetJudgmentColor("Miss")
}
if not HV.EmulateRidiculousEnabled() then table.remove(judgmentColors, 1) end

local ridiculousCount = nil
if HV.EmulateRidiculousEnabled() then
	local ok, offsets = pcall(function() return pss:GetOffsetVector() end)
	ridiculousCount = ok and HV.GetRidiculousCountFromOffsets(offsets, ms.JudgeScalers[getJudgeForScore(curScore)] or 1) or nil
end

local function getEvaluationJudgeCount(judgeName, judgeIndex)
	if judgeName == "Ridiculous" then return ridiculousCount or 0 end
	if judgeName == "TapNoteScore_W1" and ridiculousCount then return pss:GetTapNoteScores(judgeName) - ridiculousCount end
	return pss:GetTapNoteScores(judgeName)
end

local function getEvaluationRescoredJudgeCount(offsetVector, judgeScale, judgeName, judgeIndex)
	local ridiculousScale = ms.JudgeScalers[judgeScale] or judgeScale
	if judgeName == "Ridiculous" then return HV.GetRidiculousCountFromOffsets(offsetVector, ridiculousScale) end
	local index = HV.EmulateRidiculousEnabled() and judgeIndex - 1 or judgeIndex
	local count = getRescoredJudge(offsetVector, judgeScale, index)
	if judgeName == "TapNoteScore_W1" and HV.EmulateRidiculousEnabled() then
		count = count - HV.GetRidiculousCountFromOffsets(offsetVector, ridiculousScale)
	end
	return count
end

local function getRATallyCount(rowIndex)
	local ra, la, ridic, marvRA, ludic, ridicLA = getRatios()
	if rowIndex == 1 then return ludic
	elseif rowIndex == 2 then return ridicLA
	elseif rowIndex == 3 then return marvRA
	elseif rowIndex == 4 then return pss:GetTapNoteScores("TapNoteScore_W2")
	elseif rowIndex == 5 then return pss:GetTapNoteScores("TapNoteScore_W3")
	elseif rowIndex == 6 then return pss:GetTapNoteScores("TapNoteScore_Miss")
	end
	return 0
end

-- Combo Graph Configuration
local comboConfig = {
 	{ name = "8ms FA+",  window = 8.0,  judgment = 4, color = color("#c3f1ff") },
 	{ name = "10ms FA+", window = 10.0,  judgment = 4, color = color("#86e3ff") },
 	{ name = "15ms FA+", window = 15.0,  judgment = 4, color = color("#39d1ff") },
	{ name = "Marvelous", window = 22.5,  judgment = 4, color = HVColor.GetJudgmentColor("W1") },
 	{ name = "J6 Perfect", window = 45.0,  judgment = 6, color = color("#feffafff") },
	{ name = "Perfect", window = 45.0, judgment = 4, color = HVColor.GetJudgmentColor("W2") },
 }

-- Life Difficulty Color Helper (1-7 scale)
local function getLifeDifficultyColor(diff)
	local c1 = color("#A0CFAB") -- Easy / Green
	local c2 = color("#CFD198") -- Normal / Gold
	local c3 = color("#CF9898") -- Hard / Red
	if diff <= 4 then
		return HV.LerpColor((diff - 1) / 3, c1, c2)
	else
		return HV.LerpColor((diff - 4) / 3, c2, c3)
	end
end

-- Combo Graph Calculation Logic (custom)
local function calculateMaxStreaks(dvt, nrv, config)
	local results = {}
	for i = 1, #config do
		results[i] = { max = 0, startRow = 0, endRow = 0 }
	end
	if not dvt or not nrv then return results end

	local currentStreaks = {}
	local startRows = {}
	for i = 1, #config do currentStreaks[i] = 0 startRows[i] = 1 end

	for idx = 1, #dvt do
		local off = dvt[idx]
		local row = nrv[idx] or 0
		local absOff = math.abs(off)
		
		for i, conf in ipairs(config) do
			local threshold = conf.window * (ms.JudgeScalers[conf.judgment] or 1)
			if absOff <= threshold then
				if currentStreaks[i] == 0 then
					startRows[i] = row
				end
				currentStreaks[i] = currentStreaks[i] + 1
				if currentStreaks[i] > results[i].max then
					results[i].max = currentStreaks[i]
					results[i].startRow = startRows[i]
					results[i].endRow = row
				end
			else
				currentStreaks[i] = 0
			end
		end
	end
	return results
end

-- Scroll support
local function scroller(event)
	if event.type == "InputEventType_FirstPress" then
		if event.DeviceInput.button == "DeviceButton_mousewheel up" then
			MESSAGEMAN:Broadcast("WheelUpSlow")
		elseif event.DeviceInput.button == "DeviceButton_mousewheel down" then
			MESSAGEMAN:Broadcast("WheelDownSlow")
		elseif event.DeviceInput.button == "DeviceButton_left mouse button" then
			MESSAGEMAN:Broadcast("MouseLeftClick", {event=event})
		end
	end
end

local function isOver(actor)
	if not actor or not actor.GetVisible or not actor:GetVisible() then return false end
	if actor.IsVisible and not actor:IsVisible() then return false end
	local x = actor:GetTrueX()
	local y = actor:GetTrueY()
	local w = actor:GetZoomedWidth()
	local h = actor:GetZoomedHeight()
	local ha = actor.GetHAlign and actor:GetHAlign() or 0
	local va = actor.GetVAlign and actor:GetVAlign() or 0
	local mx = INPUTFILTER:GetMouseX()
	local my = INPUTFILTER:GetMouseY()
	return mx >= x - w * ha and mx <= x + w * (1 - ha) and my >= y - h * va and my <= y + h * (1 - va)
end

local showGraphs = false

local t = Def.ActorFrame {
	Name = "EvalDecorations",
	OnCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(scroller)
		SCREENMAN:SetSystemCursorVisible(true)
		if INPUTFILTER and INPUTFILTER.SetMouseVisible then
			INPUTFILTER:SetMouseVisible(true)
		end
		self:sleep(0):queuecommand("RefreshJudgeDisplay")
	end,

	RefreshJudgeDisplayCommand = function(self)
		judge = getJudgeForScore(curScore)
		updateVectors()
		clearRatioCache()
		refreshRescoredPercentage()
		recountCBs()
		self:RunCommandsOnChildren(function(self) self:playcommand("SetJudge") end)
	end,

	-- Dedicated actor for logging session grades
	Def.Actor {
		Name = "SessionGradeLogger",
		OnCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if not screen then 
				-- Retry next frame if screen is not yet available
				-- Use sleep with a slightly longer duration to be safe
				self:sleep(0.05):queuecommand("On")
				return 
			end

			-- Only log once per screen entry AND only if we just came from gameplay
			if not screen.HV_GradeCounted then
				if HV.GameplaySessionValid and GRADECOUNTERSTORAGE and GRADECOUNTERSTORAGE.incrementSession then
					GRADECOUNTERSTORAGE:incrementSession(pss:GetWifeGrade())
					-- Clear the flag after a short delay to allow other actors (like XP display) to see it first
					self:sleep(0.5):queuecommand("ClearFlag")
				end
				screen.HV_GradeCounted = true
			end
		end,
		ClearFlagCommand = function(self)
			HV.GameplaySessionValid = false
		end
	},
	ScoreChangedMessageCommand = function(self)
		pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		
		local mss = SCOREMAN:GetMostRecentScore()
		if mss and mss:GetScore() > 0 then
			curScore = mss
		else
			curScore = pss:GetHighScore()
		end
		hsTable = getScoreTable(pn, rate)
		scoreIndex = 0
		if hsTable then
			scoreIndex = getHighScoreIndex(hsTable, curScore)
		end
		recScore = getBestScore(pn, scoreIndex, rate, true)
		clearType = getClearType(pn, steps, curScore)

		judge = getJudgeForScore(curScore)
		updateVectors()
		clearRatioCache()
		refreshRescoredPercentage()
		self:RunCommandsOnChildren(function(self) self:playcommand("SetJudge") end)
		self:RunCommandsOnChildren(function(self) self:playcommand("On") end)
	end
}

-- Rescore data + rescore delegate to the corrected global functions in 08 EtternaUtils.lua.

------------------------------------------------------------
-- LEFT PANEL: SCORE CARD
------------------------------------------------------------
local function scoreBoard(pn)
	local frameX = 10
	local frameY = 10
	local frameW = SCREEN_CENTER_X - 20
	local frameH = SCREEN_HEIGHT - 20
	local pad = 12
	local modIconsY = 8
	local topHeaderY = pad + 10

	local board = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(frameX - 55, frameY):diffusealpha(0)
		end,
		OnCommand = function(self)
			self:sleep(0.25):linear(0.4):x(frameX):diffusealpha(1)
		end,
		OffsetPlotModificationMessageCommand = function(self, params)
			if params.Name == "Coin" then
				self:playcommand("ToggleCustomWindows")
				return
			end

			if usingCustomWindows then
				if params.Name == "PrevJudge" then
					self:playcommand("MoveCustomWindowIndex", {direction=-1})
				elseif params.Name == "NextJudge" then
					self:playcommand("MoveCustomWindowIndex", {direction=1})
				end
				return
			end

			if params.Name == "PrevJudge" and judge > 1 then
				judge = judge - 1
				clampJudge()
				refreshRescoredPercentage()
			elseif params.Name == "NextJudge" and judge < 9 then
				judge = judge + 1
				clampJudge()
				refreshRescoredPercentage()
			end
			if params.Name == "ResetJudge" then
				judge = getJudgeForScore(curScore)
				clampJudge()
				refreshRescoredPercentage()
				self:RunCommandsOnChildren(function(self) self:playcommand("ResetJudge") end)
				self:RunCommandsOnChildren(function(self) self:playcommand("SetJudge") end)
			elseif params.Name ~= "ToggleHands" then
				refreshRescoredPercentage()
				self:RunCommandsOnChildren(function(self) self:playcommand("SetJudge") end)
			end
			recountCBs()
			pcall(function()
				local tso = tst[judge]
				if tso then
					local screen = SCREENMAN:GetTopScreen()
					if screen and screen.GetStageStats then
						local stats = screen:GetStageStats()
						if stats and stats.GetPlayerStageStats then
							local ppss = stats:GetPlayerStageStats()
							if ppss and screen.SetPlayerStageStatsFromReplayData then
								screen:SetPlayerStageStatsFromReplayData(ppss, tso, pss:GetHighScore())
							end
						end
					end
				end
			end)
		end,
		ToggleCustomWindowsMessageCommand = function(self)
			if inMulti then return end
			usingCustomWindows = not usingCustomWindows

			if not usingCustomWindows then
				unloadCustomWindowConfig()
				MESSAGEMAN:Broadcast("UnloadedCustomWindow")
				self:RunCommandsOnChildren(function(self) self:playcommand("SetJudge") end)
				pcall(function()
					local tso = tst[judge]
					local screen = SCREENMAN:GetTopScreen()
					screen:RescoreReplay(pss, tso, curScore or pss:GetHighScore(), false)
				end)
			else
				loadCurrentCustomWindowConfig()
				pcall(function()
					local tso = tst[judge]
					local screen = SCREENMAN:GetTopScreen()
					local success = screen:RescoreReplay(pss, tso, curScore or pss:GetHighScore(), currentCustomWindowConfigUsesOldestNoteFirst())
					if success then
						lastSnapshot = REPLAYS:GetActiveReplay():GetLastReplaySnapshot()
					end
				end)
				if lastSnapshot then
					MESSAGEMAN:Broadcast("LoadedCustomWindow")
				end
			end
			self:RunCommandsOnChildren(function(self) self:playcommand("UpdateCustomWindowVisibility") end)
		end,
		MoveCustomWindowIndexMessageCommand = function(self, params)
			if not usingCustomWindows then return end
			moveCustomWindowConfigIndex(params.direction)
			loadCurrentCustomWindowConfig()
			pcall(function()
				local tso = tst[judge]
				local screen = SCREENMAN:GetTopScreen()
				local success = screen:RescoreReplay(pss, tso, curScore or pss:GetHighScore(), currentCustomWindowConfigUsesOldestNoteFirst())
				if success then
					lastSnapshot = REPLAYS:GetActiveReplay():GetLastReplaySnapshot()
				end
			end)
			if lastSnapshot then
				MESSAGEMAN:Broadcast("LoadedCustomWindow")
			end
		end,
		ResetJudgeMessageCommand = function(self) recountCBs() end,
		SetJudgeMessageCommand = function(self) recountCBs() end,

		-- Main BG
		Def.Quad {
			InitCommand = function(self) self:halign(0):valign(0):zoomto(frameW, frameH):diffuse(bgCard):diffusealpha(0) end,
			OnCommand = function(self)
				self:sleep(0.05):linear(0.35):diffusealpha(0.7):x(0)
			end
		},

		Def.ActorFrame {
			Name = "ModIcons",
			InitCommand = function(self)
				self:xy(20, modIconsY):diffusealpha(0)
			end,
			OnCommand = function(self)
				self:playcommand("Update")
				self:sleep(0.12):linear(0.25):diffusealpha(1)
			end,
			UpdateCommand = function(self)
				local ps = GAMESTATE:GetPlayerState(pn)
				if not ps then return end

				local po = ps:GetPlayerOptions("ModsLevel_Current")
				local modStr = (curScore and curScore.GetModifiers and curScore:GetModifiers())
					or ps:GetPlayerOptionsString("ModsLevel_Current")
					or ""
				if modStr == "" then
					modStr = ps:GetPlayerOptionsString("ModsLevel_Preferred") or ""
				end
				local normalizedModStr = modStr:lower():gsub("[%s_]+", "")

				local speed, mode = 400, "C"
				if GetSpeedModeAndValueFromPoptions then
					speed, mode = GetSpeedModeAndValueFromPoptions(pn)
				end

				local rate = (curScore and curScore.GetMusicRate and curScore:GetMusicRate())
					or (getCurRateValue and getCurRateValue())
					or 1
				local life = GetLifeDifficulty()
				local playedJudge = curScore and getJudgeForScore(curScore) or GetTimingDifficulty()
				local fail = po and po:FailSetting() or "FailType_Immediate"
				local assist = hasEvaluationAssistEnabled(po, modStr)

				local accent = accentColor or (HVColor and HVColor.Accent) or color("#5ABAFF")
				local dim = (HVColor and HVColor.TextDim) or color("0.4,0.4,0.4,1")
				local warn = color("#CF9898")

				self:GetChild("Speed"):settext(formatEvalSpeedMode(mode, speed)):diffuse(accent)
				self:GetChild("Rate"):settext(formatEvalRateValue(rate)):diffuse(accent)

				local lifeKey = "L7"
				if life <= 1 then
					lifeKey = "L1"
				elseif life == 2 then
					lifeKey = "L2"
				elseif life == 3 then
					lifeKey = "L3"
				elseif life == 4 then
					lifeKey = "L4"
				elseif life == 5 then
					lifeKey = "L5"
				elseif life == 6 then
					lifeKey = "L6"
				end
				local lifeColor = (HVColor and HVColor.GetLifeBarColor and HVColor.GetLifeBarColor(lifeKey))
					or color("#FFFFFF")
				self:GetChild("Life"):settext(string.format("L%d", life)):diffuse(lifeColor)
				self:GetChild("Judge"):settext(string.format("J%d", playedJudge)):diffuse(accent)

				local failText = "F:IMM"
				if fail == "FailType_Off" then
					failText = "F:OFF"
				elseif fail == "FailType_EndOfSong" then
					failText = "F:END"
				end
				self:GetChild("Fail"):settext(failText):diffuse(fail == "FailType_Immediate" and accent or warn)
				self:GetChild("Assist"):settext("AST"):diffuse(assist and accent or dim)

				local active = {}
				for mod, short in pairs(evalModShorthands) do
					local normalizedMod = mod:lower()
					local matched = string.find(normalizedModStr, normalizedMod)
					if mod == "Mines" then
						matched = string.find(normalizedModStr, "mines") and not string.find(normalizedModStr, "nomines")
					elseif mod == "Shuffle" then
						matched = string.find(normalizedModStr, "shuffle")
							and not string.find(normalizedModStr, "softshuffle")
							and not string.find(normalizedModStr, "supershuffle")
					end
					if matched then
						table.insert(active, short)
					end
				end

				local receptorSize = tonumber(ThemePrefs.Get("HV_Mini")) or 100
				if math.abs(receptorSize - 100) > 0.001 then
					table.insert(active, "MN" .. math.round(receptorSize))
				end

				self:GetChild("Separator"):visible(#active > 0)
				self:GetChild("Mods"):settext(table.concat(active, "  ")):diffuse(accent)
			end,
			ScoreChangedMessageCommand = function(self)
				self:finishtweening():sleep(0):queuecommand("Update")
			end,
			LoadFont("Common Normal") .. { Name = "Speed", InitCommand = function(self) self:zoom(0.4):halign(0) end },
			LoadFont("Common Normal") .. { Name = "Rate", InitCommand = function(self) self:x(42):zoom(0.4):halign(0) end },
			LoadFont("Common Normal") .. { Name = "Life", InitCommand = function(self) self:x(82):zoom(0.4):halign(0) end },
			LoadFont("Common Normal") .. { Name = "Judge", InitCommand = function(self) self:x(110):zoom(0.4):halign(0):diffuse(accentColor or (HVColor and HVColor.Accent) or color("#5ABAFF")) end },
			LoadFont("Common Normal") .. { Name = "Fail", InitCommand = function(self) self:x(138):zoom(0.4):halign(0):diffuse(color("#CF9898")) end },
			LoadFont("Common Normal") .. { Name = "Assist", InitCommand = function(self) self:x(182):zoom(0.4):halign(0):diffuse(accentColor or (HVColor and HVColor.Accent) or color("#5ABAFF")) end },
			LoadFont("Common Normal") .. {
				Name = "Separator",
				InitCommand = function(self) self:x(217):zoom(0.4):halign(0):settext("|"):diffuse(color("0.4,0.4,0.4,1")) end
			},
			LoadFont("Common Normal") .. {
				Name = "Mods",
				InitCommand = function(self) self:x(232):zoom(0.4):halign(0):diffuse(accentColor or (HVColor and HVColor.Accent) or color("#5ABAFF")) end
			}
		},

		-- Banner + Profile Display
		Def.ActorFrame {
			Name = "TopHeader",
			InitCommand = function(self) self:xy(20, topHeaderY) end,

			Def.Sprite {
				Name = "Banner",
				InitCommand = function(self) self:halign(0):valign(0):xy(pad -20, 0):diffusealpha(0) end,
				OnCommand = function(self)
					if song then
						local bpath = song:GetBannerPath()
						if not bpath then bpath = THEME:GetPathG("Common", "fallback banner") end
						self:LoadBackground(bpath)
						self:scaletoclipped((frameW - pad * 3) * 0.5, 60)
					end
					self:stoptweening():sleep(0.05):linear(0.25):diffusealpha(1)
				end
			},

			Def.ActorFrame {
				Name = "ProfileDisplay",
				InitCommand = function(self) 
					self:xy(pad + (frameW - pad * 3) * 0.5 + pad - 20, 0):diffusealpha(0) 
				end,
				OnCommand = function(self)
					self:sleep(0.1):linear(0.25):diffusealpha(1)
				end,

				-- Avatar
				Def.Sprite {
					Name = "Avatar",
					InitCommand = function(self) self:halign(0):valign(0):zoomto(60, 60) end,
					BeginCommand = function(self)
						self:Load(getAvatarPath(pn))
						self:zoomto(60, 60)
					end
				},

				-- Name (cycles between online and offline with fade)
				LoadFont("Common Normal") .. {
					Name = "PlayerName",
					InitCommand = function(self)
						self:xy(65, 8):zoom(0.45):halign(0):maxwidth(((frameW - pad * 3) * 0.5 - 65) / 0.45)
						self.showOnline = true
						self.transitionDuration = 0.25
						self.displayDuration = 3
						self.onlineName = DLMAN:IsLoggedIn() and DLMAN:GetUsername() or nil
						self.offlineName = profile and profile:GetDisplayName() or nil
						if self.offlineName == "" then self.offlineName = nil end
					end,
					OnCommand = function(self)
						if not self.onlineName then
							self:settext(self.offlineName or "Player 1")
							return
						elseif not self.offlineName or self.onlineName == self.offlineName then
							self:settext(self.onlineName)
							return
						end
						self:playcommand("UpdateName")
					end,
					UpdateNameCommand = function(self)
						self:stoptweening():linear(self.transitionDuration * 0.5):diffusealpha(0):queuecommand("SwapName")
					end,
					SwapNameCommand = function(self)
						local nextName = self.showOnline and self.onlineName or self.offlineName
						self:settext(nextName)
						self.showOnline = not self.showOnline
						self:stoptweening():linear(self.transitionDuration * 0.5):diffusealpha(1):sleep(self.displayDuration):queuecommand("UpdateName")
					end
				},

				-- Level Badge
				Def.ActorFrame {
					Name = "PlayerLevelBadge",
					InitCommand = function(self) self:xy(65, 23) end,
					
					-- Badge Quad
					Def.Quad {
						Name = "BadgeQuad",
						InitCommand = function(self)
							self:halign(0):zoomto(38, 14):diffusealpha(0.8)
						end,
						OnCommand = function(self)
							if profile and HV.GetLevelColor then
								local steps = GAMESTATE:GetCurrentSteps()
								local msd = (steps and steps:GetMSD(getCurRateValue(), 1)) or 0
								local gain = HV.CalculateXPGain(pss, msd)
								local xpOld = HV.GetXP(profile)
								local xpNew = xpOld
								
								local timeDiff = os.time() - (HV.LastGameplayTime or 0)
								local pc = GAMESTATE:GetPlayerState(PLAYER_1):GetPlayerController()
								local isHuman = (pc == "PlayerController_Human")
								local isRealPlay = HV.GameplaySessionValid and timeDiff >= 0 and timeDiff < 86400 and isHuman and not GAMESTATE:IsPracticeMode()
								
								if isRealPlay and gain > 0 then
									xpNew = xpOld + gain
									HV.SetXP(profile, xpNew)
									
									local levelOld = HV.GetLevelFromXP(HV.LastTotalXP)
									local levelNew = HV.GetLevelFromXP(xpNew)
									
									self:diffuse(HV.GetLevelColor(levelNew))
									
									-- Level Up Animation
									if levelNew > levelOld and HV.LastTotalXP > 0 then
										self:GetParent():stoptweening():zoom(1.5):smooth(0.5):zoom(1)
										self:GetParent():glow(1,1,1,1):linear(0.5):glow(1,1,1,0)
										MESSAGEMAN:Broadcast("HVLevelUp", {newLevel = levelNew})
									end
									
									-- Update global state
									HV.LastTotalXP = xpNew
									HV.GameplaySessionValid = false -- Only once per play
									
									-- Broadcast gain for other actors (e.g. Floating XP)
									MESSAGEMAN:Broadcast("HVXPCalculated", {gain = gain})
								else
									-- Non-earning state: just show current level color
									local level = HV.GetLevel(profile)
									self:diffuse(HV.GetLevelColor(level))
								end
							else
								self:diffuse(color("#666666"))
							end
						end
					},
					
					-- Level Text
					LoadFont("Common Normal") .. {
						InitCommand = function(self)
							self:halign(0):x(4):zoom(0.32):diffuse(color("#FFFFFF"))
						end,
						OnCommand = function(self)
							if profile then
								self:settextf("Lv. %d", HV.GetLevel(profile))
							end
						end
					},

					-- Level Up Text
					LoadFont("Common Normal") .. {
						InitCommand = function(self)
							self:halign(0):y(-12):zoom(0.4):diffusealpha(0):settext("LEVEL UP!")
						end,
						HVLevelUpMessageCommand = function(self)
							self:stoptweening():diffusealpha(0):y(-12)
								:sleep(0.2):linear(0.3):diffusealpha(1):y(-18):sleep(1):linear(0.5):diffusealpha(0)
						end
					}
				},

				-- Progress Bar
				Def.ActorFrame {
					Name = "LevelProgress",
					InitCommand = function(self) self:xy(65, 34) end,
					
					-- Bar BG
					Def.Quad {
						InitCommand = function(self)
							self:halign(0):zoomto(frameW * 0.18, 4):diffuse(0,0,0,0.5)
						end
					},
					-- Bar Fill
					Def.Quad {
						InitCommand = function(self)
							self:halign(0):zoomto(0, 4):diffuse(color("#FF4081"))
						end,
						OnCommand = function(self)
							if profile and HV.GetLevelProgress then
								local progress = HV.GetLevelProgress(profile)
								self:smooth(0.8):zoomx(frameW * 0.18 * progress)
							end
						end
					},
					-- Progress Numbers
					LoadFont("Common Normal") .. {
						Name = "ProgressText",
						InitCommand = function(self)
							self:halign(0):xy(0, 8):zoom(0.22):diffuse(subText)
						end,
						OnCommand = function(self)
							if profile and HV.GetLevelProgress then
								local _, cur, total = HV.GetLevelProgress(profile)
								self:settextf("%d / %d XP", cur, total)
							else
								self:settext("")
							end
						end
					},
					-- Floating +XP Gain Animation
					LoadFont("Common Normal") .. {
						InitCommand = function(self)
							self:halign(0):xy(50, 8):zoom(0.22):diffuse(color("#00FF00")):diffusealpha(0)
						end,
						HVXPCalculatedMessageCommand = function(self, params)
							if params.gain and params.gain > 0 then
								local progressText = self:GetParent():GetChild("ProgressText")
								local startX = (progressText and progressText:GetZoomedWidth() or 80) + 10
								self:stoptweening():x(startX):settextf("+ %d XP", params.gain)
								self:diffusealpha(0):sleep(0.5):linear(0.5):x(startX + 15):diffusealpha(1):linear(0.8):x(startX + 30):diffusealpha(0)
							end
						end
					}
				},

				-- Rating (Player SSR - cycles between online and offline with fade)
				LoadFont("Common Large") .. {
					Name = "PlayerRating",
					InitCommand = function(self)
						self:xy(65, 53):zoom(0.45):halign(0)
						self.showOnline = true
						self.transitionDuration = 0.25
						self.onlineRating = DLMAN:IsLoggedIn() and DLMAN:GetSkillsetRating("Overall") or nil
						self.offlineRating = profile and profile:GetPlayerRating() or nil
					end,
					OnCommand = function(self)
						if not HV.ShowMSD() then self:visible(false); return end
						if not profile then return end

						if not self.onlineRating or self.onlineRating <= 0 then
							self:settextf("%.2f", self.offlineRating)
							self:diffuse(HVColor.GetMSDRatingColor(self.offlineRating))
							return
						elseif not self.offlineRating or self.offlineRating <= 0 or math.abs(self.onlineRating - self.offlineRating) < 0.01 then
							self:settextf("%.2f", self.onlineRating)
							self:diffuse(HVColor.GetMSDRatingColor(self.onlineRating))
							return
						end
						self:playcommand("UpdateRating")
					end,
					UpdateRatingCommand = function(self)
						self:stoptweening():linear(self.transitionDuration * 0.5):diffusealpha(0):queuecommand("SwapRating")
					end,
					SwapRatingCommand = function(self)
						local val = self.showOnline and self.onlineRating or self.offlineRating
						self:settextf("%.2f", val)
						self:diffuse(HVColor.GetMSDRatingColor(val))
						self.showOnline = not self.showOnline
						self:stoptweening():linear(self.transitionDuration * 0.5):diffusealpha(1):sleep(3):queuecommand("UpdateRating")
					end
				}
			}
		},

		-- Song Title
		LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad - 10, pad + 80):zoom(0.55):diffuse(brightText):diffusealpha(0)
				self:maxwidth((frameW - pad*2 - 105) / 0.5)
			end,
			OnCommand = function(self) 
				if song then self:settext(song:GetDisplayMainTitle()) end 
				self:sleep(0.1):linear(0.25):xy(pad, pad + 80):diffusealpha(1)
			end
		},
		-- Artist
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad - 10, pad + 104):zoom(0.5):diffuse(subText):diffusealpha(0)
				self:maxwidth((frameW - pad*2) / 0.5)
			end,
			OnCommand = function(self) 
				if song then self:settext("// " .. song:GetDisplayArtist()) end 
				self:sleep(0.15):linear(0.25):xy(pad, pad + 104):diffusealpha(1)
			end
		},
		-- Pack Name
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad - 10, pad + 120):zoom(0.4):diffuse(subText):diffusealpha(0)
				self:maxwidth((frameW - pad*2) / 0.4)
			end,
			OnCommand = function(self) 
				if song then self:settext(song:GetGroupName()) end 
				self:sleep(0.2):linear(0.25):xy(pad, pad + 120):diffusealpha(1)
			end
		},
		-- Compact Difficulty + MSD
		Def.ActorFrame {
			InitCommand = function(self) self:xy(frameW - pad + 10, pad + 80):diffusealpha(0) end,
			OnCommand = function(self)
				self:sleep(0.2):linear(0.25):xy(frameW - pad, pad + 80):diffusealpha(1)
			end,
			
			-- Shorthand (colored by difficulty type)
			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:halign(1):valign(1):xy(-51, 14):zoom(0.55)
				end,
				OnCommand = function(self)
					if steps then
						local diff = ToEnumShortString(steps:GetDifficulty())
						local diffShort = {
							Beginner = "BG", Easy = "EZ", Medium = "NM", Hard = "HD", Challenge = "IN", Edit = "ED"
						}
						local diffLabel = diffShort[diff] or diff:sub(1,2):upper()
						local keyLabel = getKeycountLabelForSteps(steps)
						self:settext((keyLabel and (keyLabel .. " " .. diffLabel)) or diffLabel)
						self:diffuse(HVColor.GetDifficultyColor(diff))
					end
				end
			},
			-- MSD (Common Large, 2 decimal points)
			LoadFont("Common Large") .. {
				InitCommand = function(self)
					self:halign(1):valign(0):xy(0, -2):zoom(0.6)
				end,
				OnCommand = function(self)
					if steps then
						local msd = steps:GetMSD(getCurRateValue(), 1)
						if HV.ShowMSD() and msd > 0 then
							self:settextf("%.2f", msd)
							self:diffuse(HVColor.GetMSDRatingColor(msd))
							self:diffuse(HVColor.GetMSDRatingColor(msd))
						else
							self:settext(tostring(steps:GetMeter()))
							self:diffuse(brightText)
						end
					end
				end
			}
		},
		-- Rate
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(1):valign(0):xy(frameW - pad + 10, pad + 100):zoom(0.65):diffuse(brightText):diffusealpha(0)
			end,
			OnCommand = function(self) 
				self:settextf(rate) 
				self:sleep(0.25):linear(0.25):xy(frameW - pad, pad + 100):diffusealpha(1)
			end
		},
		-- Timing judge display
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(1):valign(0):xy(frameW - pad, pad + 114):zoom(0.5):diffuse(dimText)
			end,
			OnCommand = function(self) self:settextf("Judge: %d", judge) end,
			SetJudgeCommand = function(self) self:settextf("Judge: %d", judge) end,
			ResetJudgeCommand = function(self) self:settextf("Judge: %d", judge) end
		},



		-- Separator
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, pad + 135):zoomto(frameW - pad*2, 1):diffuse(dividerColor)
			end
		},
	}

	-- ============================================================
	-- GRADE + SCORE AREA
	-- ============================================================
	board[#board + 1] = Def.ActorFrame {
		Name = "GradeScore",
		InitCommand = function(self) self:xy(pad, pad + 145) end,

		-- Menacing CC Indicator
		LoadFont("Common Normal") .. {
			Name = "ChordCohesionIndicator",
			InitCommand = function(self) self:xy(0, -25):halign(0):zoom(0.6):diffuse(color("#FF0000")):visible(false) end,
			OnCommand = function(self)
				if curScore and curScore:GetChordCohesion() then
					self:visible(true):pulse():effectmagnitude(1, 1.1, 1):effecttiming(0.25, 0.25, 0.25, 0.25)
					self:settext("Chord Cohesion ON")
				end
			end,
			ScoreChangedMessageCommand = function(self) self:playcommand("On") end
		},

		-- Grade
		LoadFont("Common Large") .. {
			Name = "GradeScoreLabel",
			InitCommand = function(self) self:halign(0):valign(0):xy(0, 0):zoom(0.85):diffuse(mainText):diffusealpha(0) end,
			OnCommand = function(self)
				local grade = rescoredPercentage and GetGradeFromPercent(rescoredPercentage / 100) or pss:GetWifeGrade()
				if grade and not tostring(grade):find("^Grade_") then grade = "Grade_" .. grade end
				self:settext(HV.GetGradeName(ToEnumShortString(grade)))
				self:diffuse(HVColor.GetGradeColor(ToEnumShortString(grade)))
				self:stoptweening():sleep(0.3):linear(0.2):zoom(0.7):diffusealpha(1)
			end,
			SetJudgeCommand = function(self)
				if usingCustomWindows then return end
				if rescoredPercentage then
					local grade = GetGradeFromPercent(rescoredPercentage / 100)
					if grade and not grade:find("^Grade_") then grade = "Grade_" .. grade end
					self:settext(HV.GetGradeName(ToEnumShortString(grade)))
					self:diffuse(HVColor.GetGradeColor(ToEnumShortString(grade)))
				end
			end
		},
		-- SSR
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(10, 45):zoom(0.8):diffuse(subText):diffusealpha(0) end,
			OnCommand = function(self)
				if HV.ShowMSD() then
					local ssr = curScore:GetSkillsetSSR("Overall")
					self:settextf("%.2f", ssr)
					self:diffuse(HVColor.GetMSDRatingColor(ssr))
					self:sleep(0.4):linear(0.2):diffusealpha(1)
				else
					self:settext("")
					self:visible(false)
				end
			end
		},

		-- Custom Scoring Label
		LoadFont("Common Normal") .. {
			Name = "CustomScoringLabel",
			InitCommand = function(self) self:halign(0):valign(0):xy(110, -5):zoom(0.45):diffuse(accentColor):visible(false) end,
			OnCommand = function(self)
				if usingCustomWindows then
					self:visible(true)
					self:settext(getCurrentCustomWindowConfigName())
				end
			end,
			LoadedCustomWindowMessageCommand = function(self)
				self:visible(true)
				self:settext(getCurrentCustomWindowConfigName())
			end,
			UnloadedCustomWindowMessageCommand = function(self)
				self:visible(false)
			end
		},

		-- Wife Score Wrapper
		Def.ActorFrame {
			Name = "WifeScoreWrapper",
			InitCommand = function(self) self:xy(110, 5) end,
			OnCommand = function(self)
				local label = self:GetChild("WifeScoreLabel")
				local wife = rescoredPercentage or (pss:GetWifeScore() * 100)
				label:sleep(0.35):linear(0.15):diffusealpha(1)
				
				-- Incremental counting
				local val = math.max(0, wife)
				local duration = 0.8 -- Return to fast fixed duration, well under 2s limit
				local curTime = 0
				local targetWife = wife
				self:SetUpdateFunction(function(self, delta)
					curTime = curTime + delta
					local progress = math.min(1, curTime / duration)
					local currentWifeDisplay = targetWife * math.sin(progress * (math.pi / 2)) -- Ease out Sine
					label:settext(formatWifePercent(currentWifeDisplay))
					
					if progress >= 1 then
						self:SetUpdateFunction(nil)
					end
				end)
			end,
			ResetJudgeMessageCommand = function(self) 
				self:SetUpdateFunction(nil)
				self:playcommand("On") 
			end,

			LoadFont("Common Normal") .. {
				Name = "J4WifeScoreLabel",
				InitCommand = function(self) self:halign(0):valign(0):xy(2,-10):zoom(0.4):diffuse(color("#FF6666")):diffusealpha(0) end,
				OnCommand = function(self)
					self:playcommand("SetJudge")
					self:sleep(0.35):linear(0.15):diffusealpha(1)
				end,
				SetJudgeCommand = function(self)
					if usingCustomWindows then return end
					local playedJudge = getJudgeForScore(curScore)

					if playedJudge > 4 then
						local rst = getRescoreElements(pss, curScore)
						local j4Pct = nil
						if rst then
							rst.dvt = getFilteredDvt()
							j4Pct = getRescoredWife3Judge(3, 4, rst)
						end
						if j4Pct then
							self:settext("J4: " .. formatWifePercent(j4Pct))
							self:visible(judge ~= 4)
						else
							self:visible(false)
						end
					else
						self:visible(false)
					end
				end,
			},

			LoadFont("Common Large") .. {
				Name = "WifeScoreLabel",
				InitCommand = function(self) self:halign(0):valign(0):xy(0,0):zoom(0.65):diffuse(mainText):diffusealpha(0) end,
				SetJudgeCommand = function(self)
					if usingCustomWindows then return end
					if rescoredPercentage then
						self:settext(formatWifePercent(rescoredPercentage))
					end
				end,
				LoadedCustomWindowMessageCommand = function(self)
					if not lastSnapshot then return end
					local wife = lastSnapshot:GetWifePercent() * 100
					self:settext(formatWifePercent(wife))
				end,
			},

			-- CC indicator below Wife%
			LoadFont("Common Normal") .. {
				Name = "CCBelowWife",
				InitCommand = function(self) self:halign(0):valign(0):xy(0, 24):zoom(0.35):diffuse(color("#FF0000")):settext("Chord Cohesion ON"):visible(false) end,
				OnCommand = function(self)
					if curScore and curScore:GetChordCohesion() then
						self:visible(true)
					else
						self:visible(false)
					end
				end,
				ScoreChangedMessageCommand = function(self) self:playcommand("On") end
			},
			
			-- Hover detection for Tooltip
			Def.ActorFrame {
				OnCommand = function(self)
					self:SetUpdateFunction(function(self)
						local wrapper = self:GetParent()
						local label = wrapper and wrapper:GetChild("WifeScoreLabel")
						if isOver(label) then
							MESSAGEMAN:Broadcast("ShowScoreTooltip")
						else
							MESSAGEMAN:Broadcast("HideScoreTooltip")
						end
					end)
				end,
				ResetJudgeMessageCommand = function(self)
					self:SetUpdateFunction(nil)
					self:playcommand("On")
				end
			}
		},

		-- Chart Progress (Percentage completion on fail)
		Def.ActorFrame {
			Name = "ChartProgressWrapper",
			InitCommand = function(self) self:xy(110, 29):visible(false) end,
			OnCommand = function(self)
				local grade = pss:GetWifeGrade()
				if grade == "Grade_Failed" then
					local totalNotes = songTotalNotes or steps:GetRadarValues(pn):GetValue("RadarCategory_Notes")
					local encounteredNotes = 0
					for _, j in ipairs(judges) do
						encounteredNotes = encounteredNotes + pss:GetTapNoteScores(j)
					end
					
					local progress = (totalNotes > 0) and (encounteredNotes / totalNotes) or 0
					local targetProgress = progress * 100
					local duration = 0.8
					local curTime = 0

					self:visible(true):stoptweening():diffusealpha(0):sleep(0.4):linear(0.2):diffusealpha(1)
					
					local label = self:GetChild("ProgressLabel")
					self:SetUpdateFunction(function(self, delta)
						curTime = curTime + delta
						local animProgress = math.min(1, curTime / duration)
						local displayPct = targetProgress * math.sin(animProgress * (math.pi / 2)) -- Ease out Sine
						
						label:settextf("%.2f%% completed", math.min(displayPct, 100))
						
						if animProgress >= 1 then
							self:SetUpdateFunction(nil)
						end
					end)
				end
			end,

			LoadFont("Common Normal") .. {
				Name = "ProgressLabel",
				InitCommand = function(self) self:halign(0):valign(0):zoom(0.4):diffuse(accentColor) end,
			}
		},
		-- DP (WifeDP)
		Def.ActorFrame {
			Name = "WifeDPDisplay",
			InitCommand = function(self) self:xy(110, 45):diffusealpha(0) end,
			OnCommand = function(self)
				local wholePart = self:GetChild("WholeDP")
				local decimalPart = self:GetChild("DecimalDP")
				local displayPct = rescoredPercentage or (pss:GetWifeScore() * 100)
				local dp = (displayPct / 100) * songMaxPoints
				local targetDP = dp
				
				local duration = 0.8
				local curTime = 0

				self:stoptweening():sleep(0.4):linear(0.15):diffusealpha(1)
				
				self:SetUpdateFunction(function(self, delta)
					curTime = curTime + delta
					local progress = math.min(1, curTime / duration)
					local currentDP = targetDP * math.sin(progress * (math.pi / 2))
					local precision = (displayPct >= 99) and 4 or 2
					setDPTextActors(wholePart, decimalPart, currentDP, precision)
					
					if progress >= 1 then
						self:SetUpdateFunction(nil)
					end
				end)
			end,
			ResetJudgeMessageCommand = function(self) 
				self:SetUpdateFunction(nil)
				self:playcommand("On") 
			end,
			
			-- Whole part
			LoadFont("Common Normal") .. {
				Name = "WholeDP",
				InitCommand = function(self) self:halign(0):valign(1):xy(0, 5):zoom(0.8):diffuse(color("#55b0ff")) end,
				SetJudgeCommand = function(self)
					self:GetParent():SetUpdateFunction(nil)
					if rescoredPercentage then
						local dp = (rescoredPercentage / 100) * songMaxPoints
						local decimalPart = self:GetParent():GetChild("DecimalDP")
						local precision = (rescoredPercentage >= 99) and 4 or 2
						setDPTextActors(self, decimalPart, dp, precision)
					end
				end,
			},
			-- Decimal part
			LoadFont("Common Normal") .. {
				Name = "DecimalDP",
				InitCommand = function(self) self:halign(0):valign(1):xy(0, 5):zoom(0.35):diffuse(color("#55b0ff")) end,
				OnCommand = function(self)
					-- Handled by WholeDP UpdateFunction
				end,
				SetJudgeCommand = function(self)
					-- Handled by WholeDP SetJudgeCommand
				end,
				ResetJudgeMessageCommand = function(self) self:playcommand("On") end
			},
		},
		-- DP slash (Total Score)
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(110, 52):zoom(0.35):diffuse(subText) end,
			OnCommand = function(self)
				self:settextf("/ %.2f", songMaxPoints)
			end
		},
		-- Personal Best / Record Comparison (Pacemaker Text)
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(110, 70):zoom(0.45):diffuse(subText):diffusealpha(0) end,
			OnCommand = function(self)
				if recScore then
					local pbDp = recScore.GetWifePoints and recScore:GetWifePoints() or (recScore:GetWifeScore() * songMaxPoints)
					local curDp = pss:GetWifeScore() * songMaxPoints
					local diff = curDp - pbDp
					
					self:settextf("PB: %.2f (%+5.2f)", pbDp, diff)
				else
					self:settext("PB: New!"):diffuse(accentColor)
				end
				self:stoptweening():sleep(0.5):linear(0.2):diffusealpha(1)
			end
		},

		-- CC Indicator for Best Score
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(110, 84):zoom(0.35):diffuse(color("#FF0000")):settext("Beat with Chord Cohesion ON"):visible(false) end,
			OnCommand = function(self)
				if recScore and recScore:GetChordCohesion() then
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- MF (Manip Factor)
		LoadActor("manipfactor") .. {
			InitCommand = function(self) self:xy(280, 10) end
		},

		-- Clear Type Display Area
		Def.ActorFrame {
			InitCommand = function(self) self:xy(280, 45):diffusealpha(0) end,
			OnCommand = function(self)
				self:stoptweening():sleep(0.55):linear(0.2):diffusealpha(1)
			end,

			-- Current Clear Type
			LoadFont("Common Normal") .. {
				InitCommand = function(self) self:halign(0):valign(0):zoom(0.5) end,
				OnCommand = function(self)
					local currentCT = clearType or "Clear"
					self:settext(getClearTypeText(currentCT)):diffuse(getClearTypeColor(currentCT))
				end
			},
			-- Best Clear Type Comparison (Below)
			Def.ActorFrame {
				InitCommand = function(self) self:xy(0, 15) end,
				
				LoadFont("Common Normal") .. {
					Name = "BestLabel",
					InitCommand = function(self) self:halign(0):valign(0):zoom(0.4) end,
					OnCommand = function(self)
						if hsTable then
							local recCT = getHighestClearType(pn, steps, hsTable, scoreIndex) or "Clear"
							self:settextf("Best: %s", getClearTypeText(recCT))
							self:diffuse(getClearTypeColor(recCT)):diffusealpha(0.6)
						end
					end
				},
				LoadFont("Common Normal") .. {
					Name = "BestArrow",
					InitCommand = function(self) self:halign(0):valign(0):zoom(0.4):visible(false) end,
					OnCommand = function(self)
						self:settext("")
					end
				}
			}
		},
	}


	-- ============================================================
	-- TWO-COLUMN STATS AREA
	-- ============================================================
	local statsStartY = pad + 230
	local col1X = pad
	local col2X = (frameW / 2) + 5
	local rowH = 18
	
	-- Separator
	board[#board + 1] = Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(pad, statsStartY):zoomto(frameW - pad*2, 1):diffuse(dividerColor)
		end
	}

	-- Judgment Tally Frame (Column 1)
	local tallyFrame = Def.ActorFrame {
		Name = "JudgmentTally",
		InitCommand = function(self) self:diffusealpha(0) end,
		OnCommand = function(self)
			self:stoptweening():sleep(0.6):linear(0.3):diffusealpha(1)
			
			-- Handle hover logic via direct update function to avoid command overhead
			self:SetUpdateFunction(function(self)
				if usingCustomWindows then
					if showRATally then 
						showRATally = false 
						self:playcommand("RATallyChanged") 
					end
					return
				end
				local over = isOver(self:GetChild("HoverArea"))
				if over ~= showRATally then
					showRATally = over
					self:playcommand("RATallyChanged")
				end
			end)
		end,

		Def.Quad {
			Name = "HoverArea",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(col1X, statsStartY + 20):zoomto(col2X - pad - 5, rowH * #judges + 4):diffusealpha(0)
			end
		},

		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(col1X, statsStartY + 8):zoom(0.45):diffuse(subText)
							:settext(THEME:GetString("ScreenEvaluation", "CategoryJudgment"))
					end,
		}
	}
	board[#board + 1] = tallyFrame

	local raLabels = {"Ludicrous", "Ridiculous", "Marvelous", "Perfect", "Great", "Miss"}
	local raColors = {
		color("#FF69B4"), color("#FFD700"), 
		HVColor.GetJudgmentColor("W1"), HVColor.GetJudgmentColor("W2"), HVColor.GetJudgmentColor("W3"), HVColor.GetJudgmentColor("Miss")
	}
	
	for k, v in ipairs(judges) do
		local jy = statsStartY + 28 + (k - 1) * rowH
		
		-- Backdrop
		tallyFrame[#tallyFrame + 1] = Def.Quad {
			InitCommand = function(self)
				self:halign(0):xy(col1X - 2, jy):zoomto(0, rowH - 2):diffuse(judgmentColors[k]):diffusealpha(0.2)
			end,
			OnCommand = function(self)
				local count = getEvaluationJudgeCount(v, k)
				local pct = count / songTotalNotes
				self:zoomto((col2X - pad - col1X) * pct, rowH - 2)
			end,
			SetJudgeCommand = function(self)
				local count = getEvaluationRescoredJudgeCount(dvt, judge, v, k)
				local pct = count / songTotalNotes
				self:finishtweening():linear(0.2):zoomto((col2X - pad - col1X) * pct, rowH - 2)
			end,
			RATallyChangedCommand = function(self)
				local count = 0
				if showRATally then
					count = getRATallyCount(k)
					self:diffuse(raColors[k] or judgmentColors[k]):diffusealpha(k <= #raLabels and 0.2 or 0)
				else
					count = getEvaluationRescoredJudgeCount(dvt, judge, v, k)
					self:diffuse(judgmentColors[k]):diffusealpha(0.2)
				end
				local pct = count / songTotalNotes
				self:finishtweening():linear(0.2):zoomto((col2X - pad - col1X) * pct, rowH - 2)
			end,
			ResetJudgeMessageCommand = function(self) self:playcommand("On") end
		}
		-- Label
		tallyFrame[#tallyFrame + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):xy(col1X, jy):zoom(0.45):diffuse(judgmentColors[k])
					self:settext(v == "Ridiculous" and THEME:GetString("TapNoteScore", "Ridiculous") or getJudgeStrings(v))
			end,
			RATallyChangedCommand = function(self)
				if showRATally then
					self:settext(raLabels[k] or ""):diffuse(raColors[k] or judgmentColors[k])
				elseif usingCustomWindows then
					if getCustomWindowConfigJudgmentName then self:settext(getCustomWindowConfigJudgmentName(v)) end
					self:diffuse(judgmentColors[k])
				else
					self:settext(v == "Ridiculous" and THEME:GetString("TapNoteScore", "Ridiculous") or getJudgeStrings(v)):diffuse(judgmentColors[k])
				end
			end,
			LoadedCustomWindowMessageCommand = function(self)
				if getCustomWindowConfigJudgmentName then self:settext(getCustomWindowConfigJudgmentName(v)) end
			end,
			UnloadedCustomWindowMessageCommand = function(self) self:settext(getJudgeStrings(v)) end
		}
		-- Count
		tallyFrame[#tallyFrame + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):xy(col2X - pad - 40, jy):zoom(0.55):diffuse(brightText) end,
			OnCommand = function(self) self:settext(getEvaluationJudgeCount(v, k)) end,
			SetJudgeCommand = function(self) 
				local count = getEvaluationRescoredJudgeCount(dvt, judge, v, k)
				self:settext(count)
			end,
			RATallyChangedCommand = function(self)
				if showRATally then
					self:settext(k <= #raLabels and getRATallyCount(k) or "")
				else
					self:playcommand("SetJudge")
				end
			end,
			LoadedCustomWindowMessageCommand = function(self)
				if lastSnapshot then
					local jName = v:gsub("TapNoteScore_", "")
					self:settext(lastSnapshot:GetJudgments()[jName] or 0)
				end
			end,
			ResetJudgeMessageCommand = function(self) self:playcommand("On") end
		}
		-- Percentage
		tallyFrame[#tallyFrame + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):xy(col2X - pad - 5, jy):zoom(0.35):diffuse(dimText) end,
			OnCommand = function(self)
				local pct = songTotalNotes > 0 and getEvaluationJudgeCount(v, k) / songTotalNotes or 0
				self:settextf("%.1f%%", pct * 100)
			end,
			SetJudgeCommand = function(self)
				if totalTaps > 0 then
					local count = getEvaluationRescoredJudgeCount(dvt, judge, v, k)
					self:settextf("%.1f%%", count / totalTaps * 100)
				end
			end,
			RATallyChangedCommand = function(self)
				if showRATally then
					local count = getRATallyCount(k)
					if k <= #raLabels and totalTaps > 0 then self:settextf("%.1f%%", count / totalTaps * 100)
					else self:settext("") end
				else
					self:playcommand("SetJudge")
				end
			end,
			ResetJudgeMessageCommand = function(self) self:playcommand("On") end
		}
	end

	-- Ratios (Bottom Column 1 - 2x2 Grid)
	local ratioStartY = statsStartY + 28 + (#judges * rowH) + 12
	local ratioLabels = {"LA", "RA", "MA", "PA"}
	local ratioColors = {color("#FF69B4"), color("#FFD700"), color("#FFFFFF"), color("#E0E0A0")}
	for ri, rlabel in ipairs(ratioLabels) do
		local col = (ri - 1) % 2
		local row = math.floor((ri - 1) / 2)
		local rx = col1X + col * 75
		if col == 1 then rx = rx + 35 end
		local ry = ratioStartY + row * 26
		
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(col == 1 and 1 or 0):xy(col == 1 and rx + 30 or rx, ry):zoom(0.48):diffuse(ratioColors[ri]):settext(rlabel .. ":"):diffusealpha(0) end,
			OnCommand = function(self)
				self:stoptweening():sleep(0.65 + ri * 0.05):linear(0.2):diffusealpha(1)
			end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(col == 1 and 1 or 0):xy(col == 1 and rx + 75 or rx + 40, ry):zoom(0.5):diffuse(mainText):diffusealpha(0) end,
			OnCommand = function(self)
				if ri == 1 then
					local ra, la, ridic, marvRA, ludic, ridicLA = getRatios()
					if ridicLA == 0 then self:settext(ludic > 0 and "No Ridics" or "N/A"):diffuse(ludic > 0 and color("#FFFFFF") or dimText)
					else self:settextf("%.2f:1", la):rainbow() end
				elseif ri == 2 then
					local ra, la, ridic, marvRA, ludic, ridicLA = getRatios()
					if marvRA == 0 then self:settext(ridic > 0 and "No Marvs" or "N/A"):diffuse(ridic > 0 and ratioColors[2] or dimText)
					else self:settextf("%.2f:1", ra):diffuse(ratioColors[2]) end
				elseif ri == 3 then
					local w1 = pss:GetTapNoteScores("TapNoteScore_W1")
					local w2 = pss:GetTapNoteScores("TapNoteScore_W2")
					if w2 == 0 then self:settext(w1 > 0 and "No Perfs" or "N/A"):diffuse(w1 > 0 and color("#FFFFFF") or dimText)
					else self:settextf("%.2f:1", w1 / w2):diffuse(ratioColors[3]) end
				elseif ri == 4 then
					local w3 = pss:GetTapNoteScores("TapNoteScore_W3")
					if w3 == 0 then self:settext(pss:GetTapNoteScores("TapNoteScore_W2") > 0 and "No Greats" or "N/A"):diffuse(dimText)
					else self:settextf("%.2f:1", pss:GetTapNoteScores("TapNoteScore_W2") / w3):diffuse(ratioColors[4]) end
				end
				self:sleep(0.7 + ri * 0.05):linear(0.2):diffusealpha(1)
			end,
			SetJudgeCommand = function(self)
				self:stoptweening()
				if ri == 3 or ri == 4 then
					local w1 = getRescoredJudge(dvt, judge, 1)
					local w2 = getRescoredJudge(dvt, judge, 2)
					local w3 = getRescoredJudge(dvt, judge, 3)
					if ri == 3 then
						if w2 == 0 then self:settext(w1 > 0 and "No Perfs" or "N/A")
						else self:settextf("%.2f:1", w1 / w2) end
					else
						if w3 == 0 then self:settext(w2 > 0 and "No Greats" or "N/A")
						else self:settextf("%.2f:1", w2 / w3) end
					end
				else
					self:playcommand("On")
				end
			end,
			ResetJudgeMessageCommand = function(self) self:playcommand("On") end
		}
	end

	-- Column 2: Holds / Mines
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(col2X, statsStartY + 8):zoom(0.45):diffuse(subText):settext("Holds & Stats"):diffusealpha(0) end,
		OnCommand = function(self)
			self:stoptweening():sleep(0.6):linear(0.2):diffusealpha(1)
		end
	}
	local holdLabels = {"Hold OK", "Hold NG", "Mines Hit"}
	for i, label in ipairs(holdLabels) do
		local hy = statsStartY + 28 + (i - 1) * rowH
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):xy(col2X, hy):zoom(0.42):diffuse(subText):settext(label .. ":"):diffusealpha(0) end,
			OnCommand = function(self)
				self:stoptweening():sleep(0.65 + i * 0.05):linear(0.2):diffusealpha(1)
			end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):xy(frameW - pad, hy):zoom(0.45):diffuse(mainText):diffusealpha(0) end,
			OnCommand = function(self)
				if i == 1 then self:settext(pss:GetHoldNoteScores("HoldNoteScore_Held"))
				elseif i == 2 then self:settext(pss:GetHoldNoteScores("HoldNoteScore_LetGo"))
				elseif i == 3 then self:settext(pss:GetTapNoteScores("TapNoteScore_HitMine")) end
				self:stoptweening():sleep(0.65 + i * 0.05):linear(0.2):diffusealpha(1)
			end
		}
	end

	-- Column 2: Timing Stats
	local timingStartY = statsStartY + 28 + (3 * rowH)
	local tStatLabels = {"Mean", "Std Dev", "Largest"}
	for i, label in ipairs(tStatLabels) do
		local ty = timingStartY + (i - 1) * rowH
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):xy(col2X, ty):zoom(0.42):diffuse(subText):settext(label .. ":"):diffusealpha(0) end,
			OnCommand = function(self)
				self:stoptweening():sleep(0.75 + i * 0.05):linear(0.2):diffusealpha(1)
			end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):xy(frameW - pad, ty):zoom(0.45):diffuse(mainText):diffusealpha(0) end,
			OnCommand = function(self)
				if i == 1 then self:settextf("%.2fms", wifeMean(dvt))
				elseif i == 2 then self:settextf("%.2fms", wifeSd(dvt))
				elseif i == 3 then self:settextf("%.2fms", wifeMax(dvt)) end
				self:stoptweening():sleep(0.75 + i * 0.05):linear(0.2):diffusealpha(1)
			end,
			SetJudgeCommand = function(self) self:playcommand("UpdateText") end,
			UpdateTextCommand = function(self)
				if i == 1 then self:settextf("%.2fms", wifeMean(dvt))
				elseif i == 2 then self:settextf("%.2fms", wifeSd(dvt))
				elseif i == 3 then self:settextf("%.2fms", wifeMax(dvt)) end
			end
		}
	end

	-- Column 2: Note Types
	local ntStartY = statsStartY + 20 + (7 * rowH)
	local noteTypeLabels = {"Taps", "Holds", "Rolls", "Lifts", "Mines"}
	local noteTypeRadars = {"RadarCategory_Notes", "RadarCategory_Holds", "RadarCategory_Rolls", "RadarCategory_Lifts", "RadarCategory_Mines"}
	for ni, nlabel in ipairs(noteTypeLabels) do
		local ny = ntStartY + (ni - 1) * 16
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):xy(col2X, ny - 7):zoom(0.32):diffuse(subText):settext(nlabel .. ":"):diffusealpha(0) end,
			OnCommand = function(self)
				self:sleep(0.8 + ni * 0.03):linear(0.15):diffusealpha(1)
			end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):xy(frameW - pad, ny -7):zoom(0.35):diffuse(mainText):diffusealpha(0) end,
			OnCommand = function(self)
				if steps then
					local possible = steps:GetRadarValues(pn):GetValue(noteTypeRadars[ni])
					local actual = pss:GetRadarActual():GetValue(noteTypeRadars[ni])
					self:settextf("%d/%d", actual, possible)
				end
				self:sleep(0.8 + ni * 0.03):linear(0.15):diffusealpha(1)
			end
		}
	end

	return board
end

t[#t + 1] = scoreBoard(PLAYER_1)

------------------------------------------------------------
-- RIGHT PANEL: OFFSET PLOT + SCOREBOARD
------------------------------------------------------------
local inMulti = Var("LoadingScreen") == "ScreenNetEvaluation"
local rightX = SCREEN_CENTER_X + 10
local rightW = SCREEN_CENTER_X - 20
local offsetPlotHeight = 160

t[#t + 1] = Def.ActorFrame {
	Name = "RightPanel",
	InitCommand = function(self) self:x(rightX + 50):diffusealpha(0) end,
	OnCommand = function(self)
		self:sleep(0.25):linear(0.4):x(rightX):diffusealpha(1)
		SCREENMAN:GetTopScreen():AddInputCallback(scroller)
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type == "InputEventType_FirstPress" then
				-- Judge cycling
				if event.button == "EffectUp" then
					if usingCustomWindows then
						MESSAGEMAN:Broadcast("MoveCustomWindowIndex", {direction = 1})
					else
						MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "NextJudge"})
					end
				elseif event.button == "EffectDown" then
					if usingCustomWindows then
						MESSAGEMAN:Broadcast("MoveCustomWindowIndex", {direction = -1})
					else
						MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "PrevJudge"})
					end
				elseif event.button == "MenuUp" then
					if usingCustomWindows then
						MESSAGEMAN:Broadcast("ToggleCustomWindows")
					else
						MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "ResetJudge"})
					end
				elseif event.button == "MenuDown" or event.DeviceInput.button == "DeviceButton_down" or event.button == "Down" then
					if not usingCustomWindows then
						MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "ToggleHands"})
					end
				elseif event.button == "Coin" then
					MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "Coin"})
				end
			end
		end)
	end,

	-- BG
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(0, 10):zoomto(rightW, SCREEN_HEIGHT - 20):diffuse(bgCard)
		end
	},

	-- Toggle Offset Plot / Graphs
	Def.Quad {
		InitCommand = function(self)
			self:xy(rightW, 22):zoomto(110, 24):halign(1):diffuse(accentColor):diffusealpha(0.2)
		end,
		UpdateToggleMessageCommand = function(self)
			self:diffusealpha(showGraphs and 0.4 or 0.2)
		end,
		MouseLeftClickMessageCommand = function(self)
			if isOver(self) then
				showGraphs = not showGraphs
				MESSAGEMAN:Broadcast("ToggleGraphs")
				MESSAGEMAN:Broadcast("UpdateToggle")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(rightW - 55, 22):zoom(0.42):settext("Toggle Graphs"):diffuse(brightText)
		end
	},

	-- ============================================================
	-- GRAPHS AREA
	-- ============================================================
	Def.ActorFrame {
		Name = "Graphs",
		InitCommand = function(self) self:xy(0, 40) self:visible(showGraphs) end,
		ToggleGraphsMessageCommand = function(self) self:visible(showGraphs) end,

		-- Graph Area Label
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(10, -15):zoom(0.45):halign(0):diffuse(subText)
				self:settext("Combo & Life Graph")
			end,
		},

		-- Life Graph Background (Markers)
		Def.ActorFrame {
			Name = "LifeGraphMarkers",
			InitCommand = function(self) self:diffusealpha(0.2) end,
			-- 20% Line
			Def.Quad { InitCommand = function(self) self:xy(0, 80 * 0.8):zoomto(rightW, 1):halign(0):diffuse(color("1,1,1,1")) end },
			-- 50% Line
			Def.Quad { InitCommand = function(self) self:xy(0, 80 * 0.5):zoomto(rightW, 1):halign(0):diffuse(color("1,1,1,1")) end },
			-- 100% Line (Top)
			Def.Quad { InitCommand = function(self) self:xy(0, 0):zoomto(rightW, 1):halign(0):diffuse(color("1,1,1,1")) end },
		},

		-- Life Graph
		Def.GraphDisplay {
			InitCommand = function(self) 
				self:Load("GraphDisplay") 
				self:xy(0, 0):zoomto(rightW, 80):halign(0):valign(0)
			end,
			BeginCommand = function(self)
				pcall(function()
					local ss = SCREENMAN:GetTopScreen():GetStageStats()
					self:Set(ss, pss)
					local lifeDiff = GetLifeDifficulty()
					local c = getLifeDifficultyColor(lifeDiff)
					self:diffuse(c):diffusealpha(0.6)
					-- Apply gradient: Top is whiter
					self:diffusebottomedge(c):diffusetopedge(color("1,1,1,1"))
					pcall(function() self:GetChild("Line"):diffusealpha(0) end)
				end)
			end
		},

		-- Custom 6-Column Combo Graph (Timeline View)
		(function()
			local results = calculateMaxStreaks(dvt, nrv, comboConfig)
			local overallMax = 0
			for _, r in ipairs(results) do if r.max > overallMax then overallMax = r.max end end
			
			local graphW = rightW
			local graphH = 80
			local laneH = graphH / #comboConfig
			local af = Def.ActorFrame {
				Name = "ComboGraph",
				-- Position -2px X, +5px Y from the original (0, 80) relative to Graphs AF
				InitCommand = function(self) self:xy(-2, 85) end,
			}

			local lastRow = nrv and nrv[#nrv] or 1
			if lastRow == 0 then lastRow = 1 end

			for i, conf in ipairs(comboConfig) do
				local res = results[i]
				local val = res.max
				local startX = (res.startRow / lastRow) * graphW
				local endX = (res.endRow / lastRow) * graphW
				local barW = math.max(2, endX - startX)
				local cy = (i - 1) * laneH + laneH/2
				local isHighest = val == overallMax and overallMax > 0

				af[#af + 1] = Def.ActorFrame {
					Name = "Lane_" .. i,
					InitCommand = function(self) self:y(cy):zbuffer(true) end,

					-- 0. Depth Clearance (Initializes depth buffer to 0 / Near)
					Def.Quad {
						InitCommand = function(self)
							self:halign(0):zoomto(graphW, laneH):diffusealpha(0)
							self:blend("BlendMode_NoEffect")
							-- Force write 0 to depth buffer
							self:ztest(false):zwrite(true):z(0)
						end
					},

					-- 1. Label - Base (Judgment Color) - Always visible
					LoadFont("Common Normal") .. {
						InitCommand = function(self)
							self:zoom(0.32):settext(conf.name):halign(0):x(5)
							self:diffuse(conf.color):ztest(false)
						end
					},

					-- 2. Combo Number - Base (Judgment Color) - Always visible
					LoadFont("Common Normal") .. {
						InitCommand = function(self)
							self:zoom(0.35):settext(val):ztest(false)
							if barW > 30 then
								self:xy(startX + barW/2, 0):diffuse(conf.color)
							else
								self:xy(startX + barW + 5, 0):halign(0):diffuse(conf.color)
							end
						end
					},

					-- 3. The Horizontal Bar (Timeline) - Writes 1 to Depth Buffer
					Def.Quad {
						InitCommand = function(self)
							self:halign(0):xy(startX, 0):zoomto(barW, laneH - 2)
							self:diffuse(conf.color):diffusealpha(0.6)
							self:ztest(false):zwrite(true):z(1)
							if isHighest then
								self:glow(color("1,1,1,0.2")):diffusealpha(0.8)
							end
						end
					},

					-- 4. Label - Over (Black, only where depth is at least 1)
					LoadFont("Common Normal") .. {
						InitCommand = function(self)
							self:zoom(0.32):settext(conf.name):halign(0):x(5)
							self:diffuse(color("0,0,0,1")):ztest(true):z(1)
						end
					},

					-- 5. Combo Number - Over (Black, only where depth is at least 1)
					LoadFont("Common Normal") .. {
						InitCommand = function(self)
							self:zoom(0.35):settext(val):ztest(true):z(1)
							if barW > 30 then
								self:xy(startX + barW/2, 0):diffuse(color("0,0,0,1"))
							else
								self:xy(startX + barW + 5, 0):halign(0):diffuse(conf.color)
							end
						end
					},
				}
			end
			return af
		end)(),
	},

	-- ============================================================
	-- OFFSET PLOT
	-- ============================================================
	Def.ActorFrame {
		Name = "OffsetPlotWrapper",
		InitCommand = function(self) self:xy(0, 50) self:visible(not showGraphs) end,
		ToggleGraphsMessageCommand = function(self) self:visible(not showGraphs) end,
		
		LoadActor(THEME:GetPathG("", "OffsetGraph")) .. {
			InitCommand = function(self)
				self:xy(10, 20)
			end,
			OnCommand = function(self)
				self:RunCommandsOnChildren(function(child)
					child:playcommand("Update", {
						width = rightW - 20,
						height = 100,
						song = song,
						steps = steps,
						nrv = nrv,
						dvt = dvt,
						ctt = ctt,
						ntt = ntt,
						columns = steps and steps:GetNumColumns() or 4,
						cbl = cbl,
						cbr = cbr,
						cbm = cbm,
						showMiddle = showMiddle
					})
				end)
			end,
			SetJudgeMessageCommand = function(self, params)
				self:RunCommandsOnChildren(function(child)
					child:playcommand("Update", {
						width = rightW - 20,
						height = 100,
						song = song,
						steps = steps,
						nrv = nrv,
						dvt = dvt,
						ctt = ctt,
						ntt = ntt,
						columns = steps and steps:GetNumColumns() or 4,
						cbl = cbl,
						cbr = cbr,
						cbm = cbm,
						showMiddle = showMiddle
					})
				end)
			end,
		},
		-- Offset Plot Label
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(10, -10):zoom(0.55):halign(0):diffuse(subText)
				self:settext(THEME:GetString("ScreenEvaluation", "CategoryOffset"))
			end,
		},
	},
}

-- ============================================================
-- SCOREBOARD (loaded from external files)
-- ============================================================
local scoreboardFrame = Def.ActorFrame {
	Name = "ScoreboardContainer",
	InitCommand = function(self) self:xy(rightX + 10, offsetPlotHeight + 110) end,
}

if inMulti then
	scoreboardFrame[#scoreboardFrame + 1] = LoadActor("MPscoreboard")
else
	scoreboardFrame[#scoreboardFrame + 1] = LoadActor("online_leaderboard")
end

t[#t + 1] = scoreboardFrame
t[#t + 1] = LoadActor("../_cursor")

t[#t + 1] = Def.ActorFrame {
	Name = "GlobalScoreTooltip",
	InitCommand = function(self) self:diffusealpha(0):z(100) end,
	ShowScoreTooltipMessageCommand = function(self)
		self:diffusealpha(1)
		self:playcommand("UpdateScores")
		local mx = INPUTFILTER:GetMouseX()
		local my = INPUTFILTER:GetMouseY()
		
		local bg = self:GetChild("BG")
		local w = bg and bg:GetZoomedWidth() or 260
		local h = bg and bg:GetZoomedHeight() or 120
		local cx = mx + 15
		local cy = my + 15
		if cx + w > SCREEN_WIDTH then cx = mx - w - 5 end
		if cy + h > SCREEN_HEIGHT then cy = my - h - 5 end
		
		self:xy(cx, cy)
	end,
	HideScoreTooltipMessageCommand = function(self) self:diffusealpha(0) end,
	SetJudgeMessageCommand = function(self) self:playcommand("UpdateScores") end,
	ScoreChangedMessageCommand = function(self) self:playcommand("UpdateScores") end,
	UpdateScoresCommand = function(self)
		if self:GetDiffuseAlpha() == 0 then return end
		local rst = getRescoreElements(pss, curScore)
		if rst then rst.dvt = getFilteredDvt() end
		
		local numCustoms = customWindowsConfig and #customWindowsConfig:get_data().customWindowOrder or 0
		local rows = math.max(6, numCustoms)
		local bg = self:GetChild("BG")
		if bg then
			bg:zoomto(260, rows * 16 + 12)
		end
		
		self:RunCommandsOnChildren(function(child)
			child:playcommand("UpdateData", {rst = rst})
		end)
	end,
	Def.Quad {
		Name = "Border",
		InitCommand = function(self) self:halign(0):valign(0):diffuse(color("0.3,0.3,0.3,1")):diffusealpha(0.8) end,
		UpdateDataCommand = function(self)
			local bg = self:GetParent():GetChild("BG")
			if bg then self:zoomto(bg:GetZoomedWidth()+2, bg:GetZoomedHeight()+2):xy(-1, -1) end
		end
	},
	Def.Quad {
		Name = "BG",
		InitCommand = function(self) self:halign(0):valign(0):diffuse(color("0.05,0.05,0.05,0.95")) end
	},
	(function()
		local col = Def.ActorFrame { Name = "LeftCol", InitCommand = function(self) self:xy(8, 8) end }
		for i = 4, 9 do
			local yOff = (i - 4) * 16
			col[#col+1] = LoadFont("Common Normal") .. {
				InitCommand = function(self) self:halign(0):valign(0):xy(0, yOff):zoom(0.35):settext("J"..i..":") end
			}
			col[#col+1] = LoadFont("Common Normal") .. {
				InitCommand = function(self) self:halign(1):valign(0):xy(100, yOff):zoom(0.35) end,
				UpdateDataCommand = function(self, params)
					local pct = params.rst and getRescoredWife3Judge(3, i, params.rst) or 0
					self:settext(formatWifePercent(pct))
				end
			}
		end
		return col
	end)(),
	(function()
		local col = Def.ActorFrame { Name = "RightCol", InitCommand = function(self) self:xy(120, 8) end }
		for i = 1, 15 do
			local yOff = (i - 1) * 16
			col[#col+1] = LoadFont("Common Normal") .. {
				InitCommand = function(self) self:halign(0):valign(0):xy(0, yOff):zoom(0.35) end,
				UpdateDataCommand = function(self, params)
					if not customWindowsConfig then self:settext(""); return end
					local order = customWindowsConfig:get_data().customWindowOrder
					local configName = order[i]
					if not configName then self:settext(""); return end
					local conf = customWindowsConfig:get_data().customWindowConfigs[configName]
					local dispName = conf and conf.displayName or configName
					if dispName:len() > 16 then dispName = dispName:sub(1,15).."." end
					self:settext(dispName..":")
				end
			}
			col[#col+1] = LoadFont("Common Normal") .. {
				InitCommand = function(self) self:halign(1):valign(0):xy(130, yOff):zoom(0.35) end,
				UpdateDataCommand = function(self, params)
					if not customWindowsConfig then self:settext(""); return end
					local order = customWindowsConfig:get_data().customWindowOrder
					local configName = order[i]
					if not configName then self:settext(""); return end
					local pct = params.rst and calculateCustomWindowScore(configName, params.rst) or 0
					self:settext(formatWifePercent(pct))
				end
			}
		end
		return col
	end)()
}

t[#t + 1] = Def.Actor {
	BeginCommand = function(self)
		updateDiscordStatus(true)
    end
}

return t
