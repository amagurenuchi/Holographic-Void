-- is this messy? yep
-- am i going to clean it up? nope
hoverAlpha = 0.6
statsOverlayActive = false

firstPlayedYear = 2010
firstPlayedMonth = 1

statsOverlayInputRedirect = false
settingsOverlayActive = false
settingsOverlayInputRedirect = false
quickMenuActive = false
quickMenuInputRedirect = false
pendingMenuMusicRestore = false
settingsOverlayPanelX = SCREEN_WIDTH - 430
settingsOverlayPanelY = 52
settingsOverlayPanelWidth = 360
settingsOverlayPanelHeight = 208
settingsOverlayItemX = SCREEN_WIDTH - 430 + 18
settingsOverlayItemY = 52 + 58
settingsOverlayItemWidth = 360 - 36
settingsOverlayItemHeight = 32
settingsOverlayItemGap = 12
quickMenuPanelX = 34
quickMenuPanelY = 50
quickMenuPanelWidth = 262
quickMenuPanelHeight = 214
quickMenuItemX = 34 + 18
quickMenuItemY = 50 + 58
musicWheelSettingsButtonX = SCREEN_WIDTH - 34
musicWheelSettingsButtonY = 100
musicWheelSettingsButtonWidth = 24
musicWheelSettingsButtonHeight = 24
quickMenuItemWidth = 262 - 36
quickMenuItemHeight = 38
quickMenuItemGap = 14
sessionRowCount = 12
overallBestScoreRowCount = 16
leaderboardRowCount = 16
leaderboardScrollStep = 4
skillPredictionPointCount = 0
skillPredictionAxisTickCount = 9
overallMostPlayedRowsPerColumn = math.floor(overallBestScoreRowCount / 2)
overallMostPlayedColumnGap = 18
breakdownJudgeBarLeft = 16
breakdownJudgeBarTop = 280
breakdownJudgeBarStepY = 24
breakdownJudgeBarWidth = 272
breakdownJudgeBarHeight = 20
sessionPanelX = 280
sessionPanelY = 56
sessionPanelWidth = SCREEN_WIDTH - 280
sessionPanelHeight = SCREEN_HEIGHT - 56
sessionCardWidth = SCREEN_WIDTH - 280 - 32
skillPredictionGraphLeft = sessionPanelX + 36
skillPredictionGraphTop = sessionPanelY + 108
skillPredictionGraphWidth = sessionPanelWidth - 72
skillPredictionGraphHeight = 290
overallMostPlayedColumnWidth = math.floor((sessionCardWidth - overallMostPlayedColumnGap) / 2)
overlayCloseButtonX = SCREEN_WIDTH - 24
overlayCloseButtonY = 28
overlayCloseButtonHalfWidth = 14
overlayCloseButtonHalfHeight = 14
activityColumnCount = 7
activityCellCount = 42
activityCellSize = 20
activityCellStepX = 28
activityCellStepY = 26
activityGridX = 32
activityGridY = 210
activityPrevButtonX = 34
activityPrevButtonY = 188
activityNextButtonX = 214
activityNextButtonY = 188
activityButtonWidth = 20
activityButtonHeight = 20
selectedYear = tonumber(os.date("%Y"))
selectedMonth = tonumber(os.date("%m"))
selectedDay = tonumber(os.date("%d"))
hoveredActivityDay = nil
activityMonthCounts = {}
activityMonthMaxCount = 0
activityMonthDayCount = 31
selectedScoresForDisplay = {}
overallBestScoresForDisplay = {}
leaderboardEntriesForDisplay = {}
overallOverviewRowsForDisplay = {}
overallTimelineDaysForDisplay = {}
overallRatingTimelineDaysForDisplay = {}
overallWifeTimelineDaysForDisplay = {}
overallMsdGradePointsForDisplay = {}
overallMostPlayedChartsForDisplay = {}
overallMostPlayedFoldersForDisplay = {}
breakdownJudgeRowsForDisplay = {}
breakdownSelectedJudge = "J4"
overallProfileSummary = nil
leaderboardStatus = {state = "loading", title = "", detail = ""}
sessionScoreOffset = 0
overallBestScoreOffset = 0
leaderboardScoreOffset = 0
leaderboardSelectedScoreCount = 0
breakdownAaCounter = {state = "loading", title = "", detail = ""}
skillPredictionSsrPointsForDisplay = {}
skillPredictionAaPointsForDisplay = {}
skillPredictionMaxMsd = 1
skillPredictionMaxSsr = 1
overallTimelineHoveredIndex = nil
overallTimelineMaxValue = 1
overallTimelineMinValue = 0
overallLocalScoreEntries = nil
overallDerivedDataDirty = true
sessionChartLengthSecondsCache = {}
lastSessionDisplayKey = nil
statsOverlayTabs = {
	Sessions = 1,
	Overall = 2,
	Leaderboards = 3
}
overallSubviewTabs = {
	WifeTimeline = 1,
	Rating = 2,
	MsdGrade = 3,
	MostPlayed = 4
}
breakdownSubviewTabs = {
	JudgeBreakdown = 1,
	SkillPrediction = 2,
	PerHandBreakdown = 3
}
skillPredictionModes = {
	Ssr = 1,
	AaProbability = 2
}
perHandModes = {
	Ratio = 1,
	Graph = 2
}
statsOverlayTab = statsOverlayTabs.Sessions
overallSubviewTab = overallSubviewTabs.WifeTimeline
breakdownSubviewTab = breakdownSubviewTabs.JudgeBreakdown
skillPredictionMode = skillPredictionModes.Ssr
perHandMode = perHandModes.Ratio

perHandOverallLeftRatio = 50
perHandOverallRightRatio = 50
perHandOverallDelta = 0
perHandValidScoreCount = 0
perHandMsdPointsForDisplay = {}
perHandMaxMsd = 1
perHandMaxDelta = 1
perHandDeltaCache = {}

function isCurrentKeymodeOdd()
	local steps = GAMESTATE:GetCurrentSteps()
	if not steps then return false end
	local cols = steps:GetNumColumns() or 4
	return (cols % 2 ~= 0)
end

function getDeltaScoreForScore(score, steps)
	if not score or type(score.HasReplayData) ~= "function" then return nil end
	local hasReplay = false
	local okHas, errHas = pcall(function() hasReplay = score:HasReplayData() end)
	if not okHas or not hasReplay then return nil end

	if type(score.GetReplay) ~= "function" then return nil end
	local replay = score:GetReplay()
	if not replay then return nil end
	local okLoad = pcall(function() replay:LoadAllData() end)
	if not okLoad then return nil end

	local okDvt, dvt = pcall(function() return replay:GetOffsetVector() end)
	local okCtt, ctt = pcall(function() return replay:GetTrackVector() end)
	if not okDvt or not okCtt or type(dvt) ~= "table" or type(ctt) ~= "table" then
		return nil
	end

	local okTvt, tvt = pcall(function() return replay:GetTapNoteTypeVector() end)
	local filteredDvt = {}
	local filteredCtt = {}
	if okTvt and type(tvt) == "table" and #tvt > 0 then
		for i = 1, #dvt do
			local ty = tvt[i]
			if ty == "TapNoteType_Tap" or ty == "TapNoteType_HoldHead" or ty == "TapNoteType_Lift" then
				filteredDvt[#filteredDvt + 1] = dvt[i]
				filteredCtt[#filteredCtt + 1] = ctt[i]
			end
		end
	else
		filteredDvt = dvt
		filteredCtt = ctt
	end

	if #filteredDvt == 0 or #filteredCtt == 0 then return nil end

	local columns = steps and steps:GetNumColumns() or 4
	local middleColumn = (columns - 1) / 2.0

	local leftPts, rightPts = 0, 0
	local leftTaps, rightTaps = 0, 0

	for i = 1, math.min(#filteredDvt, #filteredCtt) do
		local offset = filteredDvt[i]
		local col = filteredCtt[i]
		if offset and col then
			local pts = wife3(math.abs(offset), 1.0)
			if col < middleColumn then
				leftPts = leftPts + pts
				leftTaps = leftTaps + 1
			elseif col > middleColumn then
				rightPts = rightPts + pts
				rightTaps = rightTaps + 1
			end
		end
	end

	local leftScore = leftTaps > 0 and (leftPts / (leftTaps * 2)) or 0
	local rightScore = rightTaps > 0 and (rightPts / (rightTaps * 2)) or 0

	return (leftScore - rightScore) * 100
end

function calculatePerHandBreakdownData()
	perHandOverallLeftRatio = 50
	perHandOverallRightRatio = 50
	perHandOverallDelta = 0
	perHandValidScoreCount = 0
	perHandMsdPointsForDisplay = {}
	perHandMaxMsd = 1
	perHandMaxDelta = 1

	local msdBuckets = {}
	local totalDelta = 0
	local validCount = 0

	for _, entry in ipairs(overallLocalScoreEntries or {}) do
		local score = entry.score
		local steps = entry.steps

		local scoreKey = score:GetDate() .. "_" .. score:GetChartKey()
		local delta = perHandDeltaCache[scoreKey]
		if delta == nil then
			delta = getDeltaScoreForScore(score, steps)
			if delta ~= nil then
				perHandDeltaCache[scoreKey] = delta
			else
				perHandDeltaCache[scoreKey] = false
			end
		end

		if delta and delta ~= false then
			totalDelta = totalDelta + delta
			validCount = validCount + 1

			local rate = score and score.GetMusicRate and score:GetMusicRate() or 1
			local chartMsd = steps and steps.GetMSD and steps:GetMSD(rate, 1) or 0
			if chartMsd and chartMsd > 0 then
				perHandMaxMsd = math.max(perHandMaxMsd, chartMsd)
				local intervalStart = math.floor(chartMsd / 0.5) * 0.5
				local bucketKey = string.format("%.1f", intervalStart)
				if not msdBuckets[bucketKey] then
					msdBuckets[bucketKey] = {start = intervalStart, total = 0, count = 0}
				end
				msdBuckets[bucketKey].total = msdBuckets[bucketKey].total + delta
				msdBuckets[bucketKey].count = msdBuckets[bucketKey].count + 1
			end
		end
	end

	perHandValidScoreCount = validCount
	if validCount > 0 then
		perHandOverallDelta = totalDelta / validCount
		perHandOverallLeftRatio = 50 + (perHandOverallDelta / 2)
		perHandOverallRightRatio = 50 - (perHandOverallDelta / 2)
	end

	for _, bucket in pairs(msdBuckets) do
		if bucket.count > 0 then
			local avgDelta = bucket.total / bucket.count
			perHandMsdPointsForDisplay[#perHandMsdPointsForDisplay + 1] = {
				x = bucket.start + 0.25,
				y = avgDelta,
				count = bucket.count
			}
			perHandMaxDelta = math.max(perHandMaxDelta, math.abs(avgDelta))
		end
	end

	table.sort(perHandMsdPointsForDisplay, function(a, b)
		return a.x < b.x
	end)

	perHandMsdPointsForDisplay = smoothSkillPredictionPoints(perHandMsdPointsForDisplay, 1)

	perHandMaxDelta = 1
	for _, pt in ipairs(perHandMsdPointsForDisplay) do
		perHandMaxDelta = math.max(perHandMaxDelta, math.abs(pt.y))
	end

	perHandMaxMsd = math.max(1, math.ceil(perHandMaxMsd * 2) / 2)
	perHandMaxDelta = math.max(0.5, math.ceil(perHandMaxDelta * 10) / 10)
end

function setPerHandMode(mode)
	if not mode then return end
	if perHandMode == mode then return end
	perHandMode = mode
	MESSAGEMAN:Broadcast("StatsOverlayPerHandModeChanged", {mode = mode})
	MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
end

statsOverlayTabTop = 0
statsOverlayTabHeight = 56
statsOverlayTabButtons = {
	{tab = statsOverlayTabs.Sessions, left = 280, width = 140, label = "SESSIONS"},
	{tab = statsOverlayTabs.Overall, left = 420, width = 140, label = "GRAPHS"},
	{tab = statsOverlayTabs.Leaderboards, left = 560, width = 160, label = "BREAKDOWN"}
}
overviewRowCount = 10
timelineGraphLeft = 280 + 40
timelineGraphTop = 56 + 40
timelineGraphWidth = SCREEN_WIDTH - 280 - 80
timelineGraphHeight = 240
timelineYAxisTickCount = 5
timelineXAxisTickCount = 3
timelineSkillsetColors = {
	["Overall"] = color("#FFFFFF"),
	["Stream"] = color("#FF6B6B"),
	["Jumpstream"] = color("#4D96FF"),
	["Handstream"] = color("#2ED573"),
	["Stamina"] = color("#FF9F43"),
	["JackSpeed"] = color("#9B5DE5"),
	["Chordjack"] = color("#FFD166"),
	["Technical"] = color("#00D1B2")
}
overallSubviewButtons = {
	{tab = overallSubviewTabs.WifeTimeline, left = 16, top = SCREEN_CENTER_Y + 10, width = 240, label = "Wife% over time"},
	{tab = overallSubviewTabs.Rating, left = 16, top = SCREEN_CENTER_Y + 38, width = 240, label = "Rating"},
	{tab = overallSubviewTabs.MsdGrade, left = 16, top = SCREEN_CENTER_Y + 66, width = 240, label = "MSD/Grade distribution"},
	{tab = overallSubviewTabs.MostPlayed, left = 16, top = SCREEN_CENTER_Y + 94, width = 240, label = "Most played charts/folders"}
}
breakdownSubviewButtons = {
	{tab = breakdownSubviewTabs.JudgeBreakdown, left = 16, top = 88, width = 240, label = "Judge Breakdown"},
	{tab = breakdownSubviewTabs.SkillPrediction, left = 16, top = 116, width = 240, label = "Skill Prediction"},
	{tab = breakdownSubviewTabs.PerHandBreakdown, left = 16, top = 144, width = 240, label = "Per-hand Breakdown"}
}
skillPredictionModeButtons = {
	{mode = skillPredictionModes.Ssr, left = sessionPanelX + 16, top = sessionPanelY + 46, width = 132, label = "SSR vs MSD"},
	{mode = skillPredictionModes.AaProbability, left = sessionPanelX + 164, top = sessionPanelY + 46, width = 220, label = "AA Probability vs MSD"}
}
perHandModeButtons = {
	{mode = perHandModes.Ratio, left = sessionPanelX + 16, top = sessionPanelY + 46, width = 180, label = "Hand Distribution"},
	{mode = perHandModes.Graph, left = sessionPanelX + 208, top = sessionPanelY + 46, width = 180, label = "Distribution by MSD"}
}
function getPerHandModeAtPosition(mouseX, mouseY)
	if not isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) then return nil end
	for _, button in ipairs(perHandModeButtons) do
		if pointInRect(mouseX, mouseY, button.left, button.top, button.width, 24) then
			return button.mode
		end
	end
	return nil
end

function mapPerHandY(delta)
	local maxDelta = math.max(0.1, perHandMaxDelta)
	local clamped = math.max(-maxDelta, math.min(delta or 0, maxDelta))
	local normalized = (clamped + maxDelta) / (2 * maxDelta)
	return skillPredictionGraphTop + skillPredictionGraphHeight - (normalized * skillPredictionGraphHeight)
end

function perHandModeButton(button)
	return Def.ActorFrame {
		Name = "PerHandModeButton" .. tostring(button.mode),
		InitCommand = function(self)
			self:xy(button.left, button.top):visible(false)
		end,
		SetCommand = function(self)
			local activeTab = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown)
			local activeMode = perHandMode == button.mode
			self:visible(activeTab)
			self:GetChild("BG"):diffusealpha(activeMode and 0.26 or 0.1)
			self:GetChild("Border"):diffusealpha(activeMode and 0.55 or 0.2)
			self:GetChild("Label"):diffuse(activeMode and color("#FFFFFF") or color("#B8B8B8"))
		end,
		StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end,
		Def.Quad {
			Name = "BG",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(button.width, 24):diffuse(getMainColor("highlight")):diffusealpha(0.1)
			end
		},
		Def.Quad {
			Name = "Border",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(button.width, 1):diffuse(getMainColor("highlight")):diffusealpha(0.2)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(8, 12):halign(0):valign(0.5):zoom(0.28):settext(button.label)
			end
		}
	}
end

function perHandCenterLine()
	return Def.Quad {
		Name = "PerHandCenterLine",
		InitCommand = function(self)
			self:halign(0):valign(0.5):zoomto(skillPredictionGraphWidth, 1.5):diffuse(color("#FFFFFF")):diffusealpha(0.3):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Graph
			self:visible(active)
			if not active then return end
			self:xy(skillPredictionGraphLeft, mapPerHandY(0))
		end,
		StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
	}
end

function perHandCurveLine()
	return Def.ActorMultiVertex {
		Name = "PerHandCurveLine",
		InitCommand = function(self)
			self:visible(false)
		end,
		SetCommand = function(self)
			local points = perHandMsdPointsForDisplay
			local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Graph and #points > 1
			if not active then
				self:visible(false)
				self:SetVertices({})
				self:SetDrawState {Mode = "DrawMode_LineStrip", First = 1, Num = 0}
				return
			end
			local verts = {}
			for _, point in ipairs(points) do
				local lineColor = getMainColor("highlight")
				verts[#verts + 1] = {{mapSkillPredictionX(point.x), mapPerHandY(point.y), 0}, lineColor}
			end
			self:visible(true)
			self:SetVertices(verts)
			self:SetDrawState {Mode = "DrawMode_LineStrip", First = 1, Num = #verts}
		end,
		StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
	}
end

function perHandHorizontalGridline(i)
	return Def.Quad {
		Name = "PerHandHorizontalGridline" .. i,
		InitCommand = function(self)
			self:halign(0):valign(0.5):zoomto(skillPredictionGraphWidth, 1):diffuse(color("#FFFFFF")):diffusealpha(0.06):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Graph
			self:visible(active)
			if not active then return end
			local fraction = (i - 1) / math.max(1, skillPredictionAxisTickCount - 1)
			self:xy(skillPredictionGraphLeft, skillPredictionGraphTop + (skillPredictionGraphHeight * fraction))
		end,
		StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end
	}
end

function perHandVerticalGridline(i)
	return Def.Quad {
		Name = "PerHandVerticalGridline" .. i,
		InitCommand = function(self)
			self:halign(0.5):valign(0):zoomto(1, skillPredictionGraphHeight):diffuse(color("#FFFFFF")):diffusealpha(0.06):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Graph
			self:visible(active)
			if not active then return end
			local fraction = (i - 1) / math.max(1, skillPredictionAxisTickCount - 1)
			self:xy(skillPredictionGraphLeft + (skillPredictionGraphWidth * fraction), skillPredictionGraphTop)
		end,
		StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end
	}
end

function perHandYAxisLabel(i)
	return LoadFont("Common Normal") .. {
		Name = "PerHandYAxisLabel" .. i,
		InitCommand = function(self)
			self:halign(1):valign(0.5):zoom(0.3):diffuse(color("#9A9A9A")):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Graph
			self:visible(active)
			if not active then return end
			local fraction = (i - 1) / math.max(1, skillPredictionAxisTickCount - 1)
			local yValue = perHandMaxDelta * (1 - 2 * fraction)
			self:xy(skillPredictionGraphLeft - 8, skillPredictionGraphTop + (skillPredictionGraphHeight * fraction))
			self:settext(string.format("%+.2f%%", yValue))
		end,
		StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
	}
end

function perHandXAxisLabel(i)
	return LoadFont("Common Normal") .. {
		Name = "PerHandXAxisLabel" .. i,
		InitCommand = function(self)
			self:halign(0.5):valign(0):zoom(0.3):diffuse(color("#9A9A9A")):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Graph
			self:visible(active)
			if not active then return end
			local fraction = (i - 1) / math.max(1, skillPredictionAxisTickCount - 1)
			local xValue = perHandMaxMsd * fraction
			self:xy(skillPredictionGraphLeft + (skillPredictionGraphWidth * fraction), skillPredictionGraphTop + skillPredictionGraphHeight + 8)
			self:settext(string.format("%.1f", xValue))
		end,
		StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end,
		StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
	}
end

musicWheelDisplayOptions = {
	{key = "OnlyShowGrades", label = "Only show grades:"},
	{key = "ShowPBTimestamps", label = "Show PB timestamps:"},
	{key = "ShowNativeMetadata", label = "Show native metadata:"}
}
formatPercent = nil
formatRate = nil
formatJudge = nil
formatChartMeter = nil
formatDateKey = nil
parseScoreTime = nil
getScoreDateParts = nil
setSettingsOverlayActive = nil
setQuickMenuActive = nil
getGradeColor = getGradeColor or function(grade)
	if HVColor and HVColor.GetGradeColor then
		return HVColor.GetGradeColor(grade)
	end
	return color("#FFFFFF")
end
getClearTypeFromScore = function(player, score, mode)
	local clearType = "NoPlay"
	if score then
		local chartKey = score:GetChartKey()
		local steps = chartKey and SONGMAN:GetStepsByChartKey(chartKey) or nil
		if getClearType and steps then
			clearType = getClearType(player, steps, score) or clearType
		end
	end
	if mode == 2 then
		return getClearTypeColor and getClearTypeColor(clearType) or color("#FFFFFF")
	end
	return getClearTypeText and getClearTypeText(clearType) or THEME:GetString("ClearTypes", clearType)
end

function pointInBox(x, y, centerX, centerY, halfWidth, halfHeight)
	return x >= centerX - halfWidth and x <= centerX + halfWidth and y >= centerY - halfHeight and y <= centerY + halfHeight
end

function pointInRect(x, y, left, top, width, height)
	return x >= left and x <= left + width and y >= top and y <= top + height
end

function isStatsOverlaySessionTab()
	return statsOverlayTab == statsOverlayTabs.Sessions
end

function getStatsOverlayTitle()
	if statsOverlayTab == statsOverlayTabs.Overall then
		return "Stats"
	elseif statsOverlayTab == statsOverlayTabs.Leaderboards then
		return "Breakdown"
	end
	return "Sessions"
end

function getStatsOverlayTabAtPosition(mouseX, mouseY)
	if mouseY < statsOverlayTabTop or mouseY > statsOverlayTabTop + statsOverlayTabHeight then return nil end
	for _, button in ipairs(statsOverlayTabButtons) do
		if pointInRect(mouseX, mouseY, button.left, statsOverlayTabTop, button.width, statsOverlayTabHeight) then
			return button.tab
		end
	end
	return nil
end

function isStatsOverlayOverallTab()
	return statsOverlayTab == statsOverlayTabs.Overall
end

function isStatsOverlayLeaderboardsTab()
	return statsOverlayTab == statsOverlayTabs.Leaderboards
end

function isStatsOverlayOverallSubview(tab)
	return statsOverlayTab == statsOverlayTabs.Overall and overallSubviewTab == tab
end

function isStatsOverlayBreakdownSubview(tab)
	return statsOverlayTab == statsOverlayTabs.Leaderboards and breakdownSubviewTab == tab
end

function isStatsOverlayOverallTimelineSubview()
	return isStatsOverlayOverallSubview(overallSubviewTabs.Rating) or isStatsOverlayOverallSubview(overallSubviewTabs.WifeTimeline)
end

function getOverallSubviewTabAtPosition(mouseX, mouseY)
	if not isStatsOverlayOverallTab() then return nil end
	for _, button in ipairs(overallSubviewButtons) do
		if pointInRect(mouseX, mouseY, button.left, button.top, button.width, 24) then
			return button.tab
		end
	end
	return nil
end

function getBreakdownSubviewTabAtPosition(mouseX, mouseY)
	if not isStatsOverlayLeaderboardsTab() then return nil end
	for _, button in ipairs(breakdownSubviewButtons) do
		if pointInRect(mouseX, mouseY, button.left, button.top, button.width, 24) then
			return button.tab
		end
	end
	return nil
end

function getSkillPredictionModeAtPosition(mouseX, mouseY)
	if not isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction) then return nil end
	for _, button in ipairs(skillPredictionModeButtons) do
		if pointInRect(mouseX, mouseY, button.left, button.top, button.width, 24) then
			return button.mode
		end
	end
	return nil
end

function getSettingsOverlayItemTop(index)
	return settingsOverlayItemY + ((index - 1) * (settingsOverlayItemHeight + settingsOverlayItemGap))
end

function pointInSettingsOverlayItem(mouseX, mouseY, index)
	return pointInRect(mouseX, mouseY, settingsOverlayItemX, getSettingsOverlayItemTop(index), settingsOverlayItemWidth, settingsOverlayItemHeight)
end

function pointInMusicWheelSettingsButton(mouseX, mouseY)
	return pointInRect(
		mouseX,
		mouseY,
		musicWheelSettingsButtonX - (musicWheelSettingsButtonWidth / 2),
		musicWheelSettingsButtonY - (musicWheelSettingsButtonHeight / 2),
		musicWheelSettingsButtonWidth,
		musicWheelSettingsButtonHeight
	)
end

function getMusicWheelDisplayOptionValue(key)
	if getMusicWheelDisplaySetting then
		return getMusicWheelDisplaySetting(key)
	end
	return false
end

function refreshMusicWheelDisplay()
	local top = SCREENMAN:GetTopScreen()
	if top and top.GetMusicWheel then
		local wheel = top:GetMusicWheel()
		if wheel and wheel.RebuildWheelItems then
			wheel:RebuildWheelItems()
		end
	end
	MESSAGEMAN:Broadcast("MusicWheelDisplayRefresh")
end

function toggleMusicWheelDisplayOption(key)
	local nextValue = not getMusicWheelDisplayOptionValue(key)
	if setMusicWheelDisplaySetting then
		setMusicWheelDisplaySetting(key, nextValue)
	end
	refreshMusicWheelDisplay()
end

function setOverallSubviewTab(tab)
	if not tab then return end
	if overallSubviewTab == tab then return end
	overallSubviewTab = tab
	if tab == overallSubviewTabs.WifeTimeline then
		overallTimelineDaysForDisplay = overallWifeTimelineDaysForDisplay
		overallTimelineMinValue = 80
		overallTimelineMaxValue = 100
	elseif tab == overallSubviewTabs.Rating then
		overallTimelineDaysForDisplay = overallRatingTimelineDaysForDisplay
		setOverallTimelineRatingBounds()
	end
	MESSAGEMAN:Broadcast("StatsOverlayOverallSubviewChanged", {tab = tab})
	MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
end

function setBreakdownSubviewTab(tab)
	if not tab then return end
	if breakdownSubviewTab == tab then return end
	breakdownSubviewTab = tab
	MESSAGEMAN:Broadcast("StatsOverlayBreakdownSubviewChanged", {tab = tab})
	MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
end

function setSkillPredictionMode(mode)
	if not mode then return end
	if skillPredictionMode == mode then return end
	skillPredictionMode = mode
	MESSAGEMAN:Broadcast("StatsOverlaySkillPredictionModeChanged", {mode = mode})
	MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
end

function getSkillPredictionYMax()
	if skillPredictionMode == skillPredictionModes.AaProbability then
		return 100
	end
	return math.max(1, skillPredictionMaxSsr)
end

function mapSkillPredictionX(msd)
	local maxMsd = math.max(0.5, skillPredictionMaxMsd)
	local clamped = math.max(0, math.min(msd or 0, maxMsd))
	return skillPredictionGraphLeft + ((clamped / maxMsd) * skillPredictionGraphWidth)
end

function mapSkillPredictionY(value)
	local maxY = getSkillPredictionYMax()
	if maxY <= 0 then
		return skillPredictionGraphTop + skillPredictionGraphHeight
	end
	local clamped = math.max(0, math.min(value or 0, maxY))
	return skillPredictionGraphTop + skillPredictionGraphHeight - ((clamped / maxY) * skillPredictionGraphHeight)
end

function getSkillPredictionProfileRating()
	if overallProfileSummary and (overallProfileSummary.rating or 0) > 0 then
		return overallProfileSummary.rating
	end
	local profile = GetPlayerOrMachineProfile(PLAYER_1)
	if profile and profile.GetPlayerRating then
		return profile:GetPlayerRating() or 0
	end
	return 0
end

function getExpectedAaChanceFromRating(profileRating, chartMsd)
	local diff = (chartMsd or 0) - (profileRating or 0)
	local chance = 100 / (1 + math.exp(diff * 2.2))
	return math.max(2, math.min(98, chance))
end

function smoothSkillPredictionPoints(points, radius)
	radius = radius or 1
	if not points or #points <= 2 or radius <= 0 then
		return points or {}
	end
	local smoothed = {}
	for i = 1, #points do
		local weightedTotal = 0
		local totalWeight = 0
		local startIndex = math.max(1, i - radius)
		local endIndex = math.min(#points, i + radius)
		for j = startIndex, endIndex do
			local distance = math.abs(i - j)
			local weight = (radius - distance) + 1
			weightedTotal = weightedTotal + ((points[j].y or 0) * weight)
			totalWeight = totalWeight + weight
		end
		smoothed[#smoothed + 1] = {
			x = points[i].x,
			y = weightedTotal / math.max(1, totalWeight),
			count = points[i].count
		}
	end
	return smoothed
end

function formatInteger(value)
	value = math.floor(tonumber(value) or 0)
	local formatted = tostring(value)
	while true do
		formatted, count = formatted:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
		if count == 0 then break end
	end
	return formatted
end

function formatStepsTypeLabel(stepsType)
	if not stepsType or stepsType == "" then return "Unknown" end
	local label = tostring(stepsType):gsub("^StepsType_", ""):gsub("_", " ")
	return label:gsub("(%a)([%w']*)", function(first, rest)
		return string.upper(first) .. string.lower(rest)
	end)
end

function getOverallTimelineSkillsetCount()
	return math.min(#ms.SkillSets, 8)
end

function fitOverallTimelineX(index)
	if #overallTimelineDaysForDisplay <= 1 then
		return timelineGraphWidth / 2
	end
	return ((index - 1) / (#overallTimelineDaysForDisplay - 1)) * timelineGraphWidth
end

function fitOverallTimelineY(value)
	local range = overallTimelineMaxValue - overallTimelineMinValue
	if range <= 0 then
		return timelineGraphHeight
	end
	local normalized = (value - overallTimelineMinValue) / range
	return timelineGraphHeight - (normalized * timelineGraphHeight)
end

function getOverallTimelineGridFraction(index, count)
	if count <= 1 then return 0 end
	return (index - 1) / (count - 1)
end

function getOverallTimelineGridX(index, count)
	return timelineGraphLeft + (timelineGraphWidth * getOverallTimelineGridFraction(index, count))
end

function getOverallTimelineGridY(index, count)
	return timelineGraphTop + (timelineGraphHeight * getOverallTimelineGridFraction(index, count))
end

function getOverallTimelineYAxisLabel(index)
	local fraction = getOverallTimelineGridFraction(index, timelineYAxisTickCount)
	local range = overallTimelineMaxValue - overallTimelineMinValue
	if range <= 0 then
		return overallTimelineMaxValue
	end
	local value = overallTimelineMinValue + (range * (1 - fraction))
	return value
end

function getOverallTimelineXAxisDisplay(index)
	local dayCount = #overallTimelineDaysForDisplay
	if dayCount == 0 then return nil, nil, nil end
	if dayCount == 1 then
		if index ~= 2 then return nil, nil, nil end
		local day = overallTimelineDaysForDisplay[1]
		return timelineGraphLeft + (timelineGraphWidth / 2), day, 0.5
	end
	local dayIndex = 1
	if index == timelineXAxisTickCount then
		dayIndex = dayCount
	elseif index == 2 then
		dayIndex = math.max(1, math.floor((dayCount + 1) / 2))
	end
	local day = overallTimelineDaysForDisplay[dayIndex]
	if not day then return nil, nil, nil end
	return getOverallTimelineGridX(index, timelineXAxisTickCount), day, getOverallTimelineGridFraction(index, timelineXAxisTickCount)
end

function getOverallProfileSummary()
	local profile = GetPlayerOrMachineProfile(PLAYER_1)
	if not profile then return nil end
	local summary = {
		name = HV.GetPlayerName(),
		rating = profile:GetPlayerRating() or 0,
		playTimeSeconds = profile:GetTotalSessionSeconds() or 0,
		songsPlayed = SCOREMAN:GetTotalNumberOfScores() or 0,
		notesHit = profile:GetTotalTapsAndHolds() or 0,
		skillsets = {}
	}
	for i = 1, math.min(#ms.SkillSets, 8) do
		local skillset = ms.SkillSets[i]
		if skillset then
			summary.skillsets[#summary.skillsets + 1] = {
				name = skillset,
				rating = profile:GetPlayerSkillsetRating(skillset) or 0
			}
		end
	end
	return summary
end

function getProfileRatingMinMax()
	local profile = GetPlayerOrMachineProfile(PLAYER_1)
	if not profile then return 0, 30 end
	local minRating = math.huge
	local maxRating = 0
	for i = 1, math.min(#ms.SkillSets, 8) do
		local skillset = ms.SkillSets[i]
		if skillset then
			local rating = profile:GetPlayerSkillsetRating(skillset) or 0
			if rating < minRating then minRating = rating end
			if rating > maxRating then maxRating = rating end
		end
	end
	if minRating == math.huge then minRating = 0 end
	if maxRating == 0 then maxRating = 30 end
	local padding = (maxRating - minRating) * 0.1
	if padding == 0 then padding = 5 end
	return math.max(0, minRating - padding), maxRating + padding
end

function getOverallTimelineRatingMinMax(days)
	local minRating = math.huge
	local maxRating = -math.huge
	local skillsetCount = getOverallTimelineSkillsetCount()
	for _, day in ipairs(days or {}) do
		local values = day and day.values
		if values then
			for i = 1, skillsetCount do
				local skillset = ms.SkillSets[i]
				local rating = tonumber(values[skillset])
				if rating then
					if rating < minRating then minRating = rating end
					if rating > maxRating then maxRating = rating end
				end
			end
		end
	end
	if minRating == math.huge or maxRating == -math.huge then
		return nil, nil
	end
	if maxRating <= minRating then
		local padding = math.max(0.2, math.abs(minRating) * 0.05)
		return minRating - padding, maxRating + padding
	end
	return minRating, maxRating
end

function setOverallTimelineRatingBounds()
	local minRating, maxRating = getOverallTimelineRatingMinMax(overallRatingTimelineDaysForDisplay)
	if not minRating or not maxRating then
		minRating, maxRating = getProfileRatingMinMax()
	end
	overallTimelineMinValue = minRating
	overallTimelineMaxValue = maxRating
end

function isScoreValidForOverallDerivedData(score)
	if not score then return false end
	local okValid, valid = pcall(function() return score:GetEtternaValid() end)
	if okValid and not valid then
		return false
	end
	local okChord, chordCohesion = pcall(function() return score:GetChordCohesion() end)
	if okChord and chordCohesion then
		return false
	end
	local okTopScore, topScore = pcall(function() return score:GetTopScore() end)
	if okTopScore and tonumber(topScore or 0) == 0 then
		return false
	end
	return true
end

function collectOverallLocalScoreEntries()
	local entries = {}
	local songs = SONGMAN:GetAllSongs() or {}
	for _, song in ipairs(songs) do
		local allSteps = song:GetAllSteps()
		if allSteps then
			for _, steps in ipairs(allSteps) do
				local okChartKey, chartKey = pcall(function() return steps:GetChartKey() end)
				if okChartKey and chartKey and chartKey ~= "" then
					local scoresByRate = SCOREMAN:GetScoresByKey(chartKey)
					if scoresByRate then
						for _, highScoreList in pairs(scoresByRate) do
							local okScores, scores = pcall(function() return highScoreList:GetScores() end)
							if okScores and scores then
								for _, score in ipairs(scores) do
									if isScoreValidForOverallDerivedData(score) then
										entries[#entries + 1] = {
											score = score,
											song = song,
											steps = steps,
											chartKey = chartKey
										}
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return entries
end

function buildOverallOverviewRows(entries)
	local buckets = {}
	for _, entry in ipairs(entries) do
		local stepsType = entry.steps and entry.steps:GetStepsType() or nil
		local key = stepsType or "Unknown"
		if not buckets[key] then
			buckets[key] = {
				label = formatStepsTypeLabel(stepsType),
				scoreCount = 0,
				totalWife = 0,
				bestSSR = 0,
				chartSet = {}
			}
		end
		local bucket = buckets[key]
		bucket.scoreCount = bucket.scoreCount + 1
		bucket.totalWife = bucket.totalWife + (entry.score:GetWifeScore() or 0)
		bucket.bestSSR = math.max(bucket.bestSSR, entry.score:GetSkillsetSSR("Overall") or 0)
		bucket.chartSet[entry.chartKey] = true
	end
	local rows = {}
	for _, bucket in pairs(buckets) do
		local chartCount = 0
		for _ in pairs(bucket.chartSet) do
			chartCount = chartCount + 1
		end
		rows[#rows + 1] = {
			label = bucket.label,
			scoreCount = bucket.scoreCount,
			chartCount = chartCount,
			averagePercent = string.format("%.2f%%", ((bucket.totalWife / math.max(1, bucket.scoreCount)) * 100)),
			bestSSR = bucket.bestSSR
		}
	end
	table.sort(rows, function(a, b)
		if a.scoreCount == b.scoreCount then
			return a.bestSSR > b.bestSSR
		end
		return a.scoreCount > b.scoreCount
	end)
	return rows
end

function erfcApprox(value)
	local sign = value < 0 and -1 or 1
	local x = math.abs(value)
	local t = 1 / (1 + (0.3275911 * x))
	local polynomial = (((((1.061405429 * t) - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592
	local erf = 1 - (polynomial * t * math.exp(-x * x))
	if sign < 0 then
		erf = -erf
	end
	return 1 - erf
end

function calculateAggregateRating(values, finalMultiplier, deltaMultiplier)
	if not values or #values == 0 then return 0 end
	local rating = 0
	local resolution = 10.24
	for iteration = 1, 11 do
		local sum = 0
		repeat
			rating = rating + resolution
			sum = 0
			for _, currentValue in ipairs(values) do
				local erfcValue = erfcApprox(deltaMultiplier * (currentValue - rating))
				if erfcValue < 1e-12 then
					erfcValue = 1e-12
				end
				local contribution = (2 / erfcValue) - 2
				if contribution > 0 then
					sum = sum + contribution
				end
			end
		until math.pow(2, rating * 0.1) >= sum
		if iteration == 11 then
			return rating * finalMultiplier
		end
		rating = rating - resolution
		resolution = resolution / 2
	end
	return rating * finalMultiplier
end

function calculatePlayerSkillsetRatingFromScores(values)
	return calculateAggregateRating(values, 1.05, 0.1)
end

function calculatePlayerOverallFromSkillsets(values)
	return calculateAggregateRating(values, 1.125, 0.1)
end

function getOverallTimelineRateKey(score)
	local rate = score and score.GetMusicRate and score:GetMusicRate() or 1
	return string.format("%.3f", tonumber(rate) or 1)
end

function getOverallTimelinePBMetric(score)
	if not score then return 0 end
	local okNorm, normPercent = pcall(function() return score:GetSSRNormPercent() end)
	if okNorm and normPercent then
		return tonumber(normPercent) or 0
	end
	return tonumber(score:GetWifeScore() or 0) or 0
end

function getOverallMsdGradeChartMSD(entry, score)
	if not entry or not entry.steps then return 0 end
	local rate = score and score.GetMusicRate and score:GetMusicRate() or 1
	local okMsd, msd = pcall(function() return entry.steps:GetMSD(rate, 1) end)
	if okMsd and msd then
		return tonumber(msd) or 0
	end
	return 0
end

function isOverallTimelineRatingEntry(entry)
	if not entry or not entry.score or not entry.steps then return false end
	local okStepsType, stepsType = pcall(function() return entry.steps:GetStepsType() end)
	if not okStepsType or not stepsType then
		return false
	end
	local stepsTypeLabel = tostring(stepsType)
	if stepsTypeLabel ~= "StepsType_dance_single" and stepsTypeLabel ~= "dance_single" then
		return false
	end
	return isScoreValidForOverallDerivedData(entry.score)
end

function applyOverallTimelineRatings(day, pbByBucket, skillsetCount)
	local specificSkillsetRatings = {}
	for i = 1, skillsetCount do
		local skillset = ms.SkillSets[i]
		if skillset ~= "Overall" then
			local values = {}
			for _, pbEntry in pairs(pbByBucket) do
				values[#values + 1] = pbEntry.score:GetSkillsetSSR(skillset) or 0
			end
			local rating = calculatePlayerSkillsetRatingFromScores(values)
			day.values[skillset] = rating
			specificSkillsetRatings[#specificSkillsetRatings + 1] = rating
		end
	end
	for i = 1, skillsetCount do
		local skillset = ms.SkillSets[i]
		if skillset == "Overall" then
			day.values[skillset] = calculatePlayerOverallFromSkillsets(specificSkillsetRatings)
		end
	end
end

function updateOverallTimelineMaxValue(day, skillsetCount, currentMax)
	local maxValue = currentMax
	for i = 1, skillsetCount do
		local skillset = ms.SkillSets[i]
		local value = day.values[skillset] or 0
		if value > maxValue then
			maxValue = value
		end
	end
	return maxValue
end

-- Weekly grouping helpers for the Overall timeline graph
function getWeekStartTime(year, month, day)
	local t = os.time({year = year, month = month, day = day, hour = 0, min = 0, sec = 0})
	local weekday = tonumber(os.date("%w", t)) -- 0=Sun, 1=Mon, ..., 6=Sat
	local daysToMonday = (weekday + 6) % 7
	return t - daysToMonday * 86400
end

function formatWeekKey(weekStartT)
	-- Zero-padded ISO week: "YYYY-WNN" (sorts correctly within a year)
	return os.date("%Y-W", weekStartT) .. string.format("%02d", tonumber(os.date("%V", weekStartT)))
end

function formatWeekLabel(weekStartT)
	local weekEndT = weekStartT + 6 * 86400
	local sd = os.date("%d", weekStartT)
	local sm = os.date("%b", weekStartT)
	local ed = os.date("%d", weekEndT)
	local em = os.date("%b", weekEndT)
	local ey = os.date("%Y", weekEndT)
	if sm == em then
		return string.format("%s-%s %s %s", sd, ed, em, ey)
	else
		return string.format("%s %s - %s %s %s", sd, sm, ed, em, ey)
	end
end

function buildOverallTimelineDataFallback(entries)
	local datedEntries = {}
	local maxValue = 1
	local skillsetCount = getOverallTimelineSkillsetCount()
	for _, entry in ipairs(entries) do
		if entry and entry.score and isScoreValidForOverallDerivedData(entry.score) then
			local year, month, day = getScoreDateParts(entry.score)
			if year and month and day then
				local scoreTime = parseScoreTime(entry.score) or os.time({year = year, month = month, day = day, hour = 0, min = 0, sec = 0})
				local weekStartT = getWeekStartTime(year, month, day)
				datedEntries[#datedEntries + 1] = {
					score = entry.score,
					key = formatWeekKey(weekStartT),
					dayTimestamp = weekStartT,
					scoreTimestamp = scoreTime,
					label = formatWeekLabel(weekStartT)
				}
			end
		end
	end
	table.sort(datedEntries, function(a, b)
		if a.scoreTimestamp == b.scoreTimestamp then
			return a.key < b.key
		end
		return a.scoreTimestamp < b.scoreTimestamp
	end)
	local days = {}
	local accumulatedValues = {}
	local currentDay = nil
	for i = 1, skillsetCount do
		local skillset = ms.SkillSets[i]
		accumulatedValues[skillset] = {}
	end
	for _, entry in ipairs(datedEntries) do
		for i = 1, skillsetCount do
			local skillset = ms.SkillSets[i]
			if skillset ~= "Overall" then
				accumulatedValues[skillset][#accumulatedValues[skillset] + 1] = entry.score:GetSkillsetSSR(skillset) or 0
			end
		end
		if not currentDay or currentDay.key ~= entry.key then
			currentDay = {
				key = entry.key,
				timestamp = entry.dayTimestamp,
				label = entry.label,
				values = {}
			}
			days[#days + 1] = currentDay
		end
		local specificSkillsetRatings = {}
		for i = 1, skillsetCount do
			local skillset = ms.SkillSets[i]
			if skillset ~= "Overall" then
				local rating = calculatePlayerSkillsetRatingFromScores(accumulatedValues[skillset])
				currentDay.values[skillset] = rating
				specificSkillsetRatings[#specificSkillsetRatings + 1] = rating
			end
		end
		for i = 1, skillsetCount do
			local skillset = ms.SkillSets[i]
			if skillset == "Overall" then
				currentDay.values[skillset] = calculatePlayerOverallFromSkillsets(specificSkillsetRatings)
			end
		end
		maxValue = updateOverallTimelineMaxValue(currentDay, skillsetCount, maxValue)
	end
	return days, maxValue
end

function buildOverallTimelineData(entries)
	local datedEntries = {}
	local maxValue = 1
	local skillsetCount = getOverallTimelineSkillsetCount()
	for _, entry in ipairs(entries) do
		if isOverallTimelineRatingEntry(entry) then
			local score = entry.score
			local year, month, day = getScoreDateParts(score)
			if year and month and day then
				local scoreTime = parseScoreTime(score) or os.time({year = year, month = month, day = day, hour = 0, min = 0, sec = 0})
				local weekStartT = getWeekStartTime(year, month, day)
				datedEntries[#datedEntries + 1] = {
					score = score,
					chartKey = entry.chartKey,
					key = formatWeekKey(weekStartT),
					dayTimestamp = weekStartT,
					scoreTimestamp = scoreTime,
					label = formatWeekLabel(weekStartT)
				}
			end
		end
	end
	table.sort(datedEntries, function(a, b)
		if a.scoreTimestamp == b.scoreTimestamp then
			return a.key < b.key
		end
		return a.scoreTimestamp < b.scoreTimestamp
	end)
	local days = {}
	local pbByBucket = {}
	local currentDay = nil
	for _, entry in ipairs(datedEntries) do
		if not currentDay or currentDay.key ~= entry.key then
			local previousDay = days[#days]
			currentDay = {
				key = entry.key,
				timestamp = entry.dayTimestamp,
				label = entry.label,
				values = {}
			}
			if previousDay and previousDay.values then
				for i = 1, skillsetCount do
					local skillset = ms.SkillSets[i]
					currentDay.values[skillset] = previousDay.values[skillset] or 0
				end
			end
			days[#days + 1] = currentDay
		end
		local bucketKey = string.format("%s@%s", entry.chartKey or "", getOverallTimelineRateKey(entry.score))
		local metric = getOverallTimelinePBMetric(entry.score)
		local previousPB = pbByBucket[bucketKey]
		if not previousPB or metric > previousPB.metric then
			pbByBucket[bucketKey] = {score = entry.score, metric = metric}
			applyOverallTimelineRatings(currentDay, pbByBucket, skillsetCount)
			maxValue = updateOverallTimelineMaxValue(currentDay, skillsetCount, maxValue)
		end
	end
	if #days == 0 and #entries > 0 then
		return buildOverallTimelineDataFallback(entries)
	end
	return days, maxValue
end

function getEstimatedSessionRatingGain(scores)
	if not scores or #scores == 0 then return 0 end
	local profileRating = getSkillPredictionProfileRating()
	local positiveDeltaSum = 0
	for _, score in ipairs(scores) do
		local ssr = score and score.GetSkillsetSSR and (score:GetSkillsetSSR("Overall") or 0) or 0
		if ssr > profileRating then
			positiveDeltaSum = positiveDeltaSum + (ssr - profileRating)
		end
	end
	local normalizedDelta = positiveDeltaSum / math.max(1, #scores)
	local gain = normalizedDelta * 0.02
	if gain < 0 then gain = 0 end
	if gain > 0.35 then gain = 0.35 end
	return gain
end

function formatEstimatedSessionRatingGain(scores)
	local gain = getEstimatedSessionRatingGain(scores)
	return string.format("+%.3f", gain)
end

function buildOverallWifeTimelineData(entries)
	local buckets = {}
	local totalWife = 0
	local totalCount = 0
	for _, entry in ipairs(entries) do
		local score = entry.score
		if score and isScoreValidForOverallDerivedData(score) and score:GetWifeGrade() ~= "Grade_Failed" then
			local year, month, day = getScoreDateParts(score)
			if year and month and day then
				local weekStartT = getWeekStartTime(year, month, day)
				local key = formatWeekKey(weekStartT)
				if not buckets[key] then
					buckets[key] = {key = key, timestamp = weekStartT, label = formatWeekLabel(weekStartT), total = 0, count = 0}
				end
				buckets[key].total = buckets[key].total + ((score:GetWifeScore() or 0) * 100)
				buckets[key].count = buckets[key].count + 1
				totalWife = totalWife + ((score:GetWifeScore() or 0) * 100)
				totalCount = totalCount + 1
			end
		end
	end
	local days = {}
	for _, bucket in pairs(buckets) do
		days[#days + 1] = {
			key = bucket.key,
			timestamp = bucket.timestamp,
			label = bucket.label,
			values = {
				Overall = bucket.total / math.max(1, bucket.count),
				Average = totalWife / math.max(1, totalCount)
			}
		}
	end
	table.sort(days, function(a, b) return (a.timestamp or 0) < (b.timestamp or 0) end)
	return days, 100
end

function buildOverallMsdGradePoints(entries)
	local points = {}
	local bestByChart = {}
	for _, entry in ipairs(entries) do
		local score = entry.score
		if score and entry and isScoreValidForOverallDerivedData(score) then
			local chartKey = entry.chartKey or ""
			if chartKey == "" then
				chartKey = tostring(entry.steps or "")
			end
			if chartKey ~= "" then
				local metric = tonumber(score:GetWifeScore() or 0) or 0
				local previousBest = bestByChart[chartKey]
				if not previousBest or metric > previousBest.metric then
					bestByChart[chartKey] = {
						entry = entry,
						score = score,
						metric = metric
					}
				end
			end
		end
	end
	for _, best in pairs(bestByChart) do
		local score = best.score
		local entry = best.entry
		local chartMSD = getOverallMsdGradeChartMSD(entry, score)
		if chartMSD > 0 then
			points[#points + 1] = {
				x = chartMSD,
				y = (score:GetWifeScore() or 0) * 100,
				grade = score:GetWifeGrade(),
				songName = entry.song and entry.song:GetDisplayMainTitle() or "Unknown"
			}
		end
	end
	table.sort(points, function(a, b)
		if a.x == b.x then return a.y > b.y end
		return a.x < b.x
	end)
	return points
end

function buildOverallMostPlayed(entries)
	local chartBuckets = {}
	local folderBuckets = {}
	for _, entry in ipairs(entries) do
		local song = entry.song
		local chartKey = entry.chartKey or ""
		if chartKey ~= "" then
			if not chartBuckets[chartKey] then
				chartBuckets[chartKey] = {
					title = song and song:GetDisplayMainTitle() or chartKey,
					meta = song and song:GetDisplayArtist() or "Unknown Artist",
					count = 0
				}
			end
			chartBuckets[chartKey].count = chartBuckets[chartKey].count + 1
		end
		if song and song.GetGroupName then
			local group = song:GetGroupName() or "Unknown Folder"
			if not folderBuckets[group] then
				folderBuckets[group] = {title = group, meta = "Folder", count = 0}
			end
			folderBuckets[group].count = folderBuckets[group].count + 1
		end
	end
	local charts = {}
	for _, bucket in pairs(chartBuckets) do charts[#charts + 1] = bucket end
	local folders = {}
	for _, bucket in pairs(folderBuckets) do folders[#folders + 1] = bucket end
	table.sort(charts, function(a, b)
		if a.count == b.count then return a.title < b.title end
		return a.count > b.count
	end)
	table.sort(folders, function(a, b)
		if a.count == b.count then return a.title < b.title end
		return a.count > b.count
	end)
	return charts, folders
end

function refreshOverallDerivedData()
	if not overallDerivedDataDirty and overallLocalScoreEntries then return end
	overallLocalScoreEntries = collectOverallLocalScoreEntries()
	overallOverviewRowsForDisplay = buildOverallOverviewRows(overallLocalScoreEntries)
	local ratingMaxValue
	overallRatingTimelineDaysForDisplay, ratingMaxValue = buildOverallTimelineData(overallLocalScoreEntries)
	overallWifeTimelineDaysForDisplay = buildOverallWifeTimelineData(overallLocalScoreEntries)
	overallMsdGradePointsForDisplay = buildOverallMsdGradePoints(overallLocalScoreEntries)
	overallMostPlayedChartsForDisplay, overallMostPlayedFoldersForDisplay = buildOverallMostPlayed(overallLocalScoreEntries)
	overallTimelineDaysForDisplay = overallRatingTimelineDaysForDisplay
	if overallSubviewTab == overallSubviewTabs.WifeTimeline then
		overallTimelineMinValue = 80
		overallTimelineMaxValue = 100
		overallTimelineDaysForDisplay = overallWifeTimelineDaysForDisplay
	elseif overallSubviewTab == overallSubviewTabs.Rating then
		overallTimelineDaysForDisplay = overallRatingTimelineDaysForDisplay
		setOverallTimelineRatingBounds()
	end
	overallDerivedDataDirty = false
end

function getOverallBestScores()
	local scores = {}
	SCOREMAN:SortSSRsForGame("Overall")
	for i = 1, overallBestScoreRowCount do
		local rank = overallBestScoreOffset + i
		local score = SCOREMAN:GetTopSSRHighScoreForGame(rank, "Overall")
		if not score then break end
		local chartKey = score:GetChartKey()
		local song = SONGMAN:GetSongByChartKey(chartKey)
		local steps = SONGMAN:GetStepsByChartKey(chartKey)
		scores[#scores + 1] = {
			rank = rank,
			score = score,
			title = song and song:GetDisplayMainTitle() or chartKey,
			artist = song and song:GetDisplayArtist() or "Unknown Artist",
			chart = formatChartMeter(steps),
			ssr = score:GetSkillsetSSR("Overall") or 0,
			percent = formatPercent(score),
			rate = formatRate(score),
			clearType = getClearTypeFromScore(PLAYER_1, score, 0),
			clearColor = getClearTypeFromScore(PLAYER_1, score, 2),
			gradeColor = getGradeColor(score:GetWifeGrade())
		}
	end
	return scores
end

function refreshLeaderboardData()
	if isCurrentKeymodeOdd() and breakdownSubviewTab == breakdownSubviewTabs.PerHandBreakdown then
		breakdownSubviewTab = breakdownSubviewTabs.JudgeBreakdown
	end
	leaderboardEntriesForDisplay = {}
	leaderboardSelectedScoreCount = 0
	skillPredictionSsrPointsForDisplay = {}
	skillPredictionAaPointsForDisplay = {}
	skillPredictionMaxMsd = 1
	skillPredictionMaxSsr = 1
	breakdownAaCounter = {
		state = "empty",
		title = "No MSD probability data",
		detail = "Play local scores to calculate weighted AA chance by 0.5 MSD interval."
	}
	refreshOverallDerivedData()
	local profileRating = getSkillPredictionProfileRating()
	local buckets = {}
	local ssrMsdBuckets = {}
	for _, entry in ipairs(overallLocalScoreEntries or {}) do
		local score = entry.score
		local steps = entry.steps
		local judge = formatJudge(score)
		local rate = score and score.GetMusicRate and score:GetMusicRate() or 1
		local chartMsd = steps and steps.GetMSD and steps:GetMSD(rate, 1) or 0
		local ssr = score and score.GetSkillsetSSR and (score:GetSkillsetSSR("Overall") or 0) or 0
		if chartMsd and chartMsd > 0 then
			skillPredictionMaxMsd = math.max(skillPredictionMaxMsd, chartMsd)
			if ssr and ssr > 0 then
				local intervalStart = math.floor(chartMsd / 0.5) * 0.5
				local key = string.format("%.1f", intervalStart)
				if not ssrMsdBuckets[key] then
					ssrMsdBuckets[key] = {start = intervalStart, total = 0, count = 0}
				end
				ssrMsdBuckets[key].total = ssrMsdBuckets[key].total + ssr
				ssrMsdBuckets[key].count = ssrMsdBuckets[key].count + 1
			end
		end
		if score and judge ~= "" then
			if not buckets[judge] then
				buckets[judge] = {judge = judge, scores = {}, total = 0, msdBuckets = {}}
			end
			buckets[judge].scores[#buckets[judge].scores + 1] = entry
			local wife = score:GetWifeScore() or 0
			buckets[judge].total = buckets[judge].total + (wife * 100)
			if chartMsd and chartMsd > 0 then
				local intervalStart = math.floor(chartMsd / 0.5) * 0.5
				local key = string.format("%.1f", intervalStart)
				if not buckets[judge].msdBuckets[key] then
					buckets[judge].msdBuckets[key] = {start = intervalStart, count = 0, aa = 0}
				end
				local msdBucket = buckets[judge].msdBuckets[key]
				msdBucket.count = msdBucket.count + 1
				if wife >= 0.93 then
					msdBucket.aa = msdBucket.aa + 1
				end
			end
		end
	end
	local allMsdBuckets = {}
	for _, entry in ipairs(overallLocalScoreEntries or {}) do
		local score = entry.score
		local steps = entry.steps
		local rate = score and score.GetMusicRate and score:GetMusicRate() or 1
		local chartMsd = steps and steps.GetMSD and steps:GetMSD(rate, 1) or 0
		if chartMsd and chartMsd > 0 and score then
			local intervalStart = math.floor(chartMsd / 0.5) * 0.5
			local key = string.format("%.1f", intervalStart)
			if not allMsdBuckets[key] then
				allMsdBuckets[key] = {start = intervalStart, count = 0, aa = 0}
			end
			allMsdBuckets[key].count = allMsdBuckets[key].count + 1
			if (score:GetWifeScore() or 0) >= 0.93 then
				allMsdBuckets[key].aa = allMsdBuckets[key].aa + 1
			end
		end
	end
	for _, bucket in pairs(ssrMsdBuckets) do
		if bucket.count > 0 then
			local averageSsr = bucket.total / bucket.count
			skillPredictionMaxSsr = math.max(skillPredictionMaxSsr, averageSsr)
			skillPredictionSsrPointsForDisplay[#skillPredictionSsrPointsForDisplay + 1] = {
				x = bucket.start + 0.25,
				y = averageSsr,
				count = bucket.count
			}
		end
	end
	for _, bucket in pairs(allMsdBuckets) do
		if bucket.count > 0 then
			local midMsd = bucket.start + 0.25
			local aaChance = (bucket.aa / bucket.count) * 100
			if profileRating > 0 then
				local expectedChance = getExpectedAaChanceFromRating(profileRating, midMsd)
				local sampleWeight = bucket.count / (bucket.count + 12)
				aaChance = (aaChance * sampleWeight) + (expectedChance * (1 - sampleWeight))
			end
			skillPredictionAaPointsForDisplay[#skillPredictionAaPointsForDisplay + 1] = {
				x = midMsd,
				y = aaChance,
				count = bucket.count
			}
		end
	end
	table.sort(skillPredictionSsrPointsForDisplay, function(a, b)
		if a.x == b.x then return a.y > b.y end
		return a.x < b.x
	end)
	table.sort(skillPredictionAaPointsForDisplay, function(a, b)
		return a.x < b.x
	end)
	skillPredictionSsrPointsForDisplay = smoothSkillPredictionPoints(skillPredictionSsrPointsForDisplay, 1)
	skillPredictionAaPointsForDisplay = smoothSkillPredictionPoints(skillPredictionAaPointsForDisplay, 1)
	skillPredictionMaxSsr = 1
	for _, point in ipairs(skillPredictionSsrPointsForDisplay) do
		skillPredictionMaxSsr = math.max(skillPredictionMaxSsr, point.y or 0)
	end
	skillPredictionMaxMsd = math.max(1, math.ceil(skillPredictionMaxMsd * 2) / 2)
	skillPredictionMaxSsr = math.max(1, math.ceil(skillPredictionMaxSsr * 2) / 2)
	breakdownJudgeRowsForDisplay = {}
	for _, bucket in pairs(buckets) do
		breakdownJudgeRowsForDisplay[#breakdownJudgeRowsForDisplay + 1] = {
			judge = bucket.judge,
			count = #bucket.scores,
			average = bucket.total / math.max(1, #bucket.scores)
		}
	end
	table.sort(breakdownJudgeRowsForDisplay, function(a, b)
		return a.judge < b.judge
	end)
	if not buckets[breakdownSelectedJudge] and breakdownJudgeRowsForDisplay[1] then
		breakdownSelectedJudge = breakdownJudgeRowsForDisplay[1].judge
	end
	local selected = buckets[breakdownSelectedJudge]
	if not selected then
		leaderboardStatus = {
			state = "empty",
			title = "No local scores found",
			detail = "Play history is required to build judge difficulty breakdowns."
		}
		return
	end
	leaderboardSelectedScoreCount = #selected.scores
	clampLeaderboardScoreOffset()
	table.sort(selected.scores, function(a, b)
		local aw = a.score and a.score:GetWifeScore() or 0
		local bw = b.score and b.score:GetWifeScore() or 0
		if aw == bw then
			return (a.song and a.song:GetDisplayMainTitle() or "") < (b.song and b.song:GetDisplayMainTitle() or "")
		end
		return aw > bw
	end)
	for i = 1, math.min(#selected.scores - leaderboardScoreOffset, leaderboardRowCount) do
		local sourceIndex = leaderboardScoreOffset + i
		local entry = selected.scores[sourceIndex]
		local score = entry.score
		local song = entry.song
		local steps = entry.steps
		leaderboardEntriesForDisplay[#leaderboardEntriesForDisplay + 1] = {
			rank = sourceIndex,
			name = song and song:GetDisplayMainTitle() or score:GetChartKey(),
			metric = formatPercent(score),
			activity = string.format("%s - %s - %.2f", formatChartMeter(steps), formatRate(score), score:GetSkillsetSSR("Overall") or 0),
			gradeColor = getGradeColor(score:GetWifeGrade())
		}
	end
	local bestCounterBucket = nil
	for _, msdBucket in pairs(selected.msdBuckets or {}) do
		if msdBucket.count > 0 then
			local rawChance = msdBucket.aa / msdBucket.count
			local sampleWeight = msdBucket.count / (msdBucket.count + 6)
			local weightedChance = rawChance * sampleWeight
			if not bestCounterBucket
				or weightedChance > bestCounterBucket.weightedChance
				or (weightedChance == bestCounterBucket.weightedChance and msdBucket.count > bestCounterBucket.count) then
				bestCounterBucket = {
					start = msdBucket.start,
					count = msdBucket.count,
					rawChance = rawChance,
					weightedChance = weightedChance
				}
			end
		end
	end
	if bestCounterBucket then
		breakdownAaCounter = {
			state = "ready",
			title = string.format("%s  %.1f-%.1f MSD", breakdownSelectedJudge, bestCounterBucket.start, bestCounterBucket.start + 0.5),
			detail = string.format("Weighted AA chance %.1f%% (raw %.1f%% from %d scores)", bestCounterBucket.weightedChance * 100, bestCounterBucket.rawChance * 100, bestCounterBucket.count)
		}
	end
	local firstVisible = #selected.scores > 0 and (leaderboardScoreOffset + 1) or 0
	local lastVisible = math.min(#selected.scores, leaderboardScoreOffset + leaderboardRowCount)
	leaderboardStatus = {
		state = "ready",
		title = string.format("%s scores", breakdownSelectedJudge),
		detail = string.format("%d scores - %.2f%% average - showing %d to %d", #selected.scores, selected.total / math.max(1, #selected.scores), firstVisible, lastVisible)
	}
	calculatePerHandBreakdownData()
end

function skillPredictionModeButton(button)
	return Def.ActorFrame {
		Name = "SkillPredictionModeButton" .. tostring(button.mode),
		InitCommand = function(self)
			self:xy(button.left, button.top):visible(false)
		end,
		SetCommand = function(self)
			local activeTab = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction)
			local activeMode = skillPredictionMode == button.mode
			self:visible(activeTab)
			self:GetChild("BG"):diffusealpha(activeMode and 0.26 or 0.1)
			self:GetChild("Border"):diffusealpha(activeMode and 0.55 or 0.2)
			self:GetChild("Label"):diffuse(activeMode and color("#FFFFFF") or color("#B8B8B8"))
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlaySkillPredictionModeChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		Def.Quad {
			Name = "BG",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(button.width, 24):diffuse(getMainColor("highlight")):diffusealpha(0.1)
			end
		},
		Def.Quad {
			Name = "Border",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(button.width, 1):diffuse(getMainColor("highlight")):diffusealpha(0.2)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(8, 12):halign(0):valign(0.5):zoom(0.28):settext(button.label)
			end
		}
	}
end

function skillPredictionHorizontalGridline(i)
	return Def.Quad {
		Name = "SkillPredictionHorizontalGridline" .. i,
		InitCommand = function(self)
			self:halign(0):valign(0.5):zoomto(skillPredictionGraphWidth, 1):diffuse(color("#FFFFFF")):diffusealpha(0.08):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction)
			self:visible(active)
			if not active then return end
			local fraction = (i - 1) / math.max(1, skillPredictionAxisTickCount - 1)
			self:xy(skillPredictionGraphLeft, skillPredictionGraphTop + (skillPredictionGraphHeight * fraction))
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function skillPredictionVerticalGridline(i)
	return Def.Quad {
		Name = "SkillPredictionVerticalGridline" .. i,
		InitCommand = function(self)
			self:halign(0.5):valign(0):zoomto(1, skillPredictionGraphHeight):diffuse(color("#FFFFFF")):diffusealpha(0.06):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction)
			self:visible(active)
			if not active then return end
			local fraction = (i - 1) / math.max(1, skillPredictionAxisTickCount - 1)
			self:xy(skillPredictionGraphLeft + (skillPredictionGraphWidth * fraction), skillPredictionGraphTop)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function skillPredictionYAxisLabel(i)
	return LoadFont("Common Normal") .. {
		Name = "SkillPredictionYAxisLabel" .. i,
		InitCommand = function(self)
			self:halign(1):valign(0.5):zoom(0.3):diffuse(color("#9A9A9A")):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction)
			self:visible(active)
			if not active then return end
			local fraction = (i - 1) / math.max(1, skillPredictionAxisTickCount - 1)
			local yValue = getSkillPredictionYMax() * (1 - fraction)
			self:xy(skillPredictionGraphLeft - 8, skillPredictionGraphTop + (skillPredictionGraphHeight * fraction))
			if skillPredictionMode == skillPredictionModes.AaProbability then
				self:settext(string.format("%.0f%%", yValue))
			else
				self:settext(string.format("%.1f", yValue))
			end
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlaySkillPredictionModeChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function skillPredictionXAxisLabel(i)
	return LoadFont("Common Normal") .. {
		Name = "SkillPredictionXAxisLabel" .. i,
		InitCommand = function(self)
			self:halign(0.5):valign(0):zoom(0.3):diffuse(color("#9A9A9A")):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction)
			self:visible(active)
			if not active then return end
			local fraction = (i - 1) / math.max(1, skillPredictionAxisTickCount - 1)
			local xValue = skillPredictionMaxMsd * fraction
			self:xy(skillPredictionGraphLeft + (skillPredictionGraphWidth * fraction), skillPredictionGraphTop + skillPredictionGraphHeight + 8)
			self:settext(string.format("%.1f", xValue))
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function skillPredictionPoint(i)
	return Def.Quad {
		Name = "SkillPredictionPoint" .. i,
		InitCommand = function(self)
			self:halign(0.5):valign(0.5):zoomto(4, 4):visible(false)
		end,
		SetCommand = function(self)
			self:visible(false)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlaySkillPredictionModeChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function skillPredictionCurveLine()
	return Def.ActorMultiVertex {
		Name = "SkillPredictionCurveLine",
		InitCommand = function(self)
			self:visible(false)
		end,
		SetCommand = function(self)
			local points = skillPredictionMode == skillPredictionModes.AaProbability and skillPredictionAaPointsForDisplay or skillPredictionSsrPointsForDisplay
			local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction) and #points > 1
			if not active then
				self:visible(false)
				self:SetVertices({})
				self:SetDrawState {Mode = "DrawMode_LineStrip", First = 1, Num = 0}
				return
			end
			local verts = {}
			for _, point in ipairs(points) do
				local lineColor = skillPredictionMode == skillPredictionModes.Ssr and color("#7CE0FF") or getMainColor("highlight")
				verts[#verts + 1] = {{mapSkillPredictionX(point.x), mapSkillPredictionY(point.y), 0}, lineColor}
			end
			self:visible(true)
			self:SetVertices(verts)
			self:SetDrawState {Mode = "DrawMode_LineStrip", First = 1, Num = #verts}
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlaySkillPredictionModeChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function setStatsOverlayTab(tab)
	if not tab then return end
	if statsOverlayTab == tab then return end
	statsOverlayTab = tab
	hoveredActivityDay = nil
	if tab == statsOverlayTabs.Overall then
		overallBestScoreOffset = 0
	elseif tab == statsOverlayTabs.Leaderboards then
		leaderboardScoreOffset = 0
		breakdownSubviewTab = breakdownSubviewTabs.JudgeBreakdown
		skillPredictionMode = skillPredictionModes.Ssr
	end
	MESSAGEMAN:Broadcast("StatsOverlayTabChanged", {tab = tab})
	MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
end

formatPercent = function(score)
	if not score then return "" end
	local percent = score:GetWifeScore() * 100
	return string.format(percent >= 99.7 and "%.4f%%" or "%.2f%%", percent)
end

formatRate = function(score)
	if not score then return "" end
	return string.format("%.2f", score:GetMusicRate()):gsub("%.?0+$", "") .. "x"
end

function getRecentScoreCount()
	local count = 0
	for i = 1, 64 do
		if SCOREMAN:GetRecentScoreForGame(i) then
			count = count + 1
		else
			break
		end
	end
	return count
end

formatDateKey = function(year, month, day)
	return string.format("%04d-%02d-%02d", year, month, day)
end

function getTodayDateParts()
	local now = os.time()
	return tonumber(os.date("%Y", now)), tonumber(os.date("%m", now)), tonumber(os.date("%d", now))
end

function daysInMonth(year, month)
	local nextMonth = os.time({year = year, month = month + 1, day = 1, hour = 0, min = 0, sec = 0})
	return tonumber(os.date("%d", nextMonth - 86400))
end

function shiftSelectedMonth(offset)
	local nextMonth = selectedMonth + offset
	local nextYear = selectedYear
	while nextMonth < 1 do nextMonth = nextMonth + 12 nextYear = nextYear - 1 end
	while nextMonth > 12 do nextMonth = nextMonth - 12 nextYear = nextYear + 1 end
	
	local firstTime = os.time({year = firstPlayedYear, month = firstPlayedMonth, day = 1, hour = 0, min = 0, sec = 0})
	local currentTime = os.time({year = tonumber(os.date("%Y")), month = tonumber(os.date("%m")), day = 1, hour = 0, min = 0, sec = 0})
	local targetTime = os.time({year = nextYear, month = nextMonth, day = 1, hour = 0, min = 0, sec = 0})
	
	if targetTime < firstTime or targetTime > currentTime then
		return
	end

	local shifted = os.time({year = selectedYear, month = selectedMonth + offset, day = 1, hour = 0, min = 0, sec = 0})
	selectedYear = tonumber(os.date("%Y", shifted))
	selectedMonth = tonumber(os.date("%m", shifted))
	selectedDay = math.min(selectedDay, daysInMonth(selectedYear, selectedMonth))
end

function shiftSelectedDay(offset)
	local t = os.time({year = selectedYear, month = selectedMonth, day = selectedDay, hour = 0, min = 0, sec = 0})
	local shifted = t + (offset * 24 * 3600)
	
	local firstTime = os.time({year = firstPlayedYear, month = firstPlayedMonth, day = 1, hour = 0, min = 0, sec = 0})
	local currentTime = os.time({year = tonumber(os.date("%Y")), month = tonumber(os.date("%m")), day = 31, hour = 23, min = 59, sec = 59})
	
	if shifted < firstTime or shifted > os.time() then
		return
	end
	
	selectedYear = tonumber(os.date("%Y", shifted))
	selectedMonth = tonumber(os.date("%m", shifted))
	selectedDay = tonumber(os.date("%d", shifted))
end

parseScoreTime = function(score)
	if not score then return nil end
	local d = score:GetDate()
	if not d or d == "" then return nil end
	d = tostring(d):gsub("T", " "):gsub("/", "-")
	local year, month, day, hour, min, sec = d:match("^(%d+)%-(%d+)%-(%d+)%s+(%d+):(%d+):(%d+)")
	if not year then
		year, month, day, hour, min = d:match("^(%d+)%-(%d+)%-(%d+)%s+(%d+):(%d+)")
		sec = 0
	end
	if not year then
		year, month, day = d:match("^(%d+)%-(%d+)%-(%d+)")
		hour, min, sec = 0, 0, 0
	end
	if not year then return nil end
	return os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec)})
end

getScoreDateParts = function(score)
	local t = parseScoreTime(score)
	if t then
		return tonumber(os.date("%Y", t)), tonumber(os.date("%m", t)), tonumber(os.date("%d", t))
	end
	if not score then return nil end
	local d = score:GetDate()
	if not d or d == "" then return nil end
	d = tostring(d):gsub("/", "-")
	local year, month, day = d:match("^(%d+)%-(%d+)%-(%d+)")
	if not year then return nil end
	year, month, day = tonumber(year), tonumber(month), tonumber(day)
	if not year or not month or not day then return nil end
	return year, month, day
end

function getScoreDateKey(score)
	local year, month, day = getScoreDateParts(score)
	if not year then return nil end
	return formatDateKey(year, month, day)
end

function getScoresForSelectedDate()
	local selectedKey = formatDateKey(selectedYear, selectedMonth, selectedDay)
	local scores = {}
	for i = 1, 512 do
		local score = SCOREMAN:GetRecentScoreForGame(i)
		if not score then break end
		if getScoreDateKey(score) == selectedKey then
			scores[#scores + 1] = score
		end
	end
	return scores
end

function getSelectedMonthActivity()
	local counts = {}
	local monthDays = daysInMonth(selectedYear, selectedMonth)
	for day = 1, monthDays do
		counts[day] = 0
	end
	local maxCount = 0
	for i = 1, 512 do
		local score = SCOREMAN:GetRecentScoreForGame(i)
		if not score then break end
		local year, month, day = getScoreDateParts(score)
		if year == selectedYear and month == selectedMonth and day and day >= 1 and day <= monthDays then
			counts[day] = counts[day] + 1
			if counts[day] > maxCount then
				maxCount = counts[day]
			end
		end
	end
	return counts, maxCount, monthDays
end

function getSelectedSessionSeconds(scores)
	if not scores or #scores == 0 then return 0 end
	local getChartLengthSeconds = function(chartKey)
		if not chartKey or chartKey == "" then return 0 end
		if sessionChartLengthSecondsCache[chartKey] ~= nil then
			return sessionChartLengthSecondsCache[chartKey]
		end
		local seconds = 0
		local song = SONGMAN:GetSongByChartKey(chartKey)
		if song then
			local okLastSecond, lastSecond = pcall(function() return song:GetLastSecond() end)
			if okLastSecond and lastSecond and tonumber(lastSecond) and tonumber(lastSecond) > 0 then
				seconds = tonumber(lastSecond)
			end
			if seconds <= 0 then
				local okMusicLength, musicLength = pcall(function() return song:GetMusicLengthSeconds() end)
				if okMusicLength and musicLength and tonumber(musicLength) and tonumber(musicLength) > 0 then
					seconds = tonumber(musicLength)
				end
			end
		end
		sessionChartLengthSecondsCache[chartKey] = seconds
		return seconds
	end
	local totalPlaySeconds = 0
	for _, score in ipairs(scores) do
		local chartKey = score and score.GetChartKey and score:GetChartKey() or ""
		local chartLength = getChartLengthSeconds(chartKey)
		if chartLength > 0 then
			local rate = score and score.GetMusicRate and score:GetMusicRate() or 1
			if not rate or rate <= 0 then rate = 1 end
			totalPlaySeconds = totalPlaySeconds + (chartLength / rate)
		end
	end
	if totalPlaySeconds > 0 then
		return math.floor(totalPlaySeconds + 0.5)
	end
	local earliest = nil
	local latest = nil
	for _, score in ipairs(scores) do
		local scoreTime = parseScoreTime(score)
		if scoreTime then
			if not earliest or scoreTime < earliest then earliest = scoreTime end
			if not latest or scoreTime > latest then latest = scoreTime end
		end
	end
	if earliest and latest and latest > earliest then
		return latest - earliest
	end
	return 0
end

formatJudge = function(score)
	if not score then return "" end
	local j = table.find(ms.JudgeScalers, notShit.round(score:GetJudgeScale(), 2))
	if not j then j = 4 end
	if j < 4 then j = 4 end
	return "J" .. j
end

formatChartMeter = function(steps)
	if not steps then return "" end
	local parts = {}
	local style = GAMESTATE:GetCurrentStyle()
	local keymode = nil
	if style then
		local ok, columns = pcall(function() return style:ColumnsPerPlayer() end)
		if ok and columns then
			keymode = tostring(columns) .. "K"
		end
	end
	if keymode then parts[#parts + 1] = keymode end
	parts[#parts + 1] = getShortDifficulty(steps:GetDifficulty())
	parts[#parts + 1] = tostring(steps:GetMeter())
	return table.concat(parts, " ")
end

function getMonthStartWeekday(year, month)
	local t = os.time({year = year, month = month, day = 1, hour = 0, min = 0, sec = 0})
	local wday = tonumber(os.date("%w", t)) -- 0=Sunday, 1=Monday...
	if wday == 0 then wday = 7 end
	return wday -- 1=Monday, 7=Sunday
end

function getActivityDayAtPosition(mouseX, mouseY)
	local offset = getMonthStartWeekday(selectedYear, selectedMonth) - 1
	for day = 1, activityMonthDayCount do
		local index = day - 1 + offset
		local col = index % activityColumnCount
		local row = math.floor(index / activityColumnCount)
		local cellX = activityGridX + (col * activityCellStepX)
		local cellY = activityGridY + (row * activityCellStepY)
		if pointInRect(mouseX, mouseY, cellX, cellY, activityCellSize, activityCellSize) then
			return day
		end
	end
	return nil
end

function isOverSessionPanel(mouseX, mouseY)
	if not isStatsOverlaySessionTab() then return false end
	return pointInRect(mouseX, mouseY, sessionPanelX, sessionPanelY, sessionPanelWidth, sessionPanelHeight)
end

function getOverallTimelineHoverIndex(mouseX, mouseY)
	if not isStatsOverlayOverallSubview(overallSubviewTabs.Rating) and not isStatsOverlayOverallSubview(overallSubviewTabs.WifeTimeline) then return nil end
	if not pointInRect(mouseX, mouseY, timelineGraphLeft, timelineGraphTop, timelineGraphWidth, timelineGraphHeight) then return nil end
	if #overallTimelineDaysForDisplay == 0 then return nil end
	if #overallTimelineDaysForDisplay == 1 then return 1 end
	local relative = (mouseX - timelineGraphLeft) / timelineGraphWidth
	local index = math.floor((relative * (#overallTimelineDaysForDisplay - 1)) + 0.5) + 1
	if index < 1 then index = 1 end
	if index > #overallTimelineDaysForDisplay then index = #overallTimelineDaysForDisplay end
	return index
end

function isOverOverallBestScoresPanel(mouseX, mouseY)
	if not isStatsOverlayOverallSubview(overallSubviewTabs.MostPlayed) then return false end
	return pointInRect(mouseX, mouseY, sessionPanelX, sessionPanelY + 72, sessionPanelWidth, sessionPanelHeight - 90)
end

function isOverLeaderboardScoresPanel(mouseX, mouseY)
	if not isStatsOverlayBreakdownSubview(breakdownSubviewTabs.JudgeBreakdown) then return false end
	return pointInRect(mouseX, mouseY, sessionPanelX, sessionPanelY + 72, sessionPanelWidth, sessionPanelHeight - 90)
end

function getBreakdownJudgeAtPosition(mouseX, mouseY)
	if not isStatsOverlayBreakdownSubview(breakdownSubviewTabs.JudgeBreakdown) then return nil end
	for i, entry in ipairs(breakdownJudgeRowsForDisplay) do
		if entry and pointInRect(mouseX, mouseY, breakdownJudgeBarLeft, breakdownJudgeBarTop + ((i - 1) * breakdownJudgeBarStepY), breakdownJudgeBarWidth, breakdownJudgeBarHeight) then
			return entry.judge
		end
	end
	return nil
end

function clampSessionScoreOffset()
	local maxOffset = math.max(0, #selectedScoresForDisplay - sessionRowCount)
	if sessionScoreOffset < 0 then
		sessionScoreOffset = 0
	elseif sessionScoreOffset > maxOffset then
		sessionScoreOffset = maxOffset
	end
end

function pageSessionScores(direction)
	sessionScoreOffset = sessionScoreOffset + (direction * sessionRowCount)
	clampSessionScoreOffset()
	MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
end

function clampOverallBestScoreOffset()
	if overallBestScoreOffset < 0 then
		overallBestScoreOffset = 0
	end
end

function clampLeaderboardScoreOffset()
	local maxOffset = math.max(0, leaderboardSelectedScoreCount - leaderboardRowCount)
	if leaderboardScoreOffset < 0 then
		leaderboardScoreOffset = 0
	elseif leaderboardScoreOffset > maxOffset then
		leaderboardScoreOffset = maxOffset
	end
end

function pageOverallBestScores(direction)
	local nextOffset = overallBestScoreOffset + (direction * overallBestScoreRowCount)
	if nextOffset < 0 then
		nextOffset = 0
	end
	if direction > 0 then
		local nextScore = SCOREMAN:GetTopSSRHighScoreForGame(nextOffset + 1, "Overall")
		if not nextScore then
			return
		end
		local pageStartScore = SCOREMAN:GetTopSSRHighScoreForGame(nextOffset, "Overall")
		if nextOffset > 0 and not pageStartScore then
			return
		end
	end
	overallBestScoreOffset = nextOffset
	clampOverallBestScoreOffset()
	MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
end

function pageLeaderboardScores(direction)
	leaderboardScoreOffset = leaderboardScoreOffset + (direction * leaderboardScrollStep)
	clampLeaderboardScoreOffset()
	MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
end

function getQuickMenuItemTop(index)
	return quickMenuItemY + ((index - 1) * (quickMenuItemHeight + quickMenuItemGap))
end

function pointInQuickMenuItem(mouseX, mouseY, index)
	return pointInRect(mouseX, mouseY, quickMenuItemX, getQuickMenuItemTop(index), quickMenuItemWidth, quickMenuItemHeight)
end

function setStatsOverlayActive(active)
	if statsOverlayActive == active then return end
	statsOverlayActive = active
	setenv("StatsOverlayActive", active)
	if active then
		if settingsOverlayActive then
			setSettingsOverlayActive(false)
		end

		local profile = PROFILEMAN:GetProfile(PLAYER_1)
		if profile and profile.GetFirstPlayedDate then
			local firstDate = profile:GetFirstPlayedDate()
			if firstDate and firstDate ~= "" then
				firstPlayedYear = tonumber(firstDate:sub(1, 4))
				firstPlayedMonth = tonumber(firstDate:sub(6, 7))
			end
		else
			firstPlayedYear = 2017
			firstPlayedMonth = 1
		end

		selectedYear, selectedMonth, selectedDay = getTodayDateParts()
		hoveredActivityDay = nil
		sessionScoreOffset = 0
		overallBestScoreOffset = 0
		leaderboardScoreOffset = 0
		leaderboardSelectedScoreCount = 0
		overallTimelineHoveredIndex = nil
		overallLocalScoreEntries = nil
		overallOverviewRowsForDisplay = {}
		overallTimelineDaysForDisplay = {}
		overallDerivedDataDirty = true
		lastSessionDisplayKey = nil
		statsOverlayTab = statsOverlayTabs.Sessions
		overallSubviewTab = overallSubviewTabs.WifeTimeline
		breakdownSubviewTab = breakdownSubviewTabs.JudgeBreakdown
		skillPredictionMode = skillPredictionModes.Ssr
		statsOverlayInputRedirect = SCREENMAN:get_input_redirected(PLAYER_1)
		SCREENMAN:set_input_redirected(PLAYER_1, true)
	else
		hoveredActivityDay = nil
		sessionScoreOffset = 0
		overallBestScoreOffset = 0
		leaderboardScoreOffset = 0
		leaderboardSelectedScoreCount = 0
		overallTimelineHoveredIndex = nil
		overallLocalScoreEntries = nil
		overallOverviewRowsForDisplay = {}
		overallTimelineDaysForDisplay = {}
		overallDerivedDataDirty = true
		lastSessionDisplayKey = nil
		breakdownSubviewTab = breakdownSubviewTabs.JudgeBreakdown
		skillPredictionMode = skillPredictionModes.Ssr
		SCREENMAN:set_input_redirected(PLAYER_1, statsOverlayInputRedirect)
	end
	MESSAGEMAN:Broadcast("StatsOverlayStateChanged", {active = active})
end

setSettingsOverlayActive = function(active)
	if settingsOverlayActive == active then return end
	settingsOverlayActive = active
	setenv("MusicWheelSettingsOverlayActive", active)
	if active then
		if statsOverlayActive then
			setStatsOverlayActive(false)
		end
		if quickMenuActive then
			setQuickMenuActive(false)
		end
		settingsOverlayInputRedirect = SCREENMAN:get_input_redirected(PLAYER_1)
		SCREENMAN:set_input_redirected(PLAYER_1, true)
	else
		SCREENMAN:set_input_redirected(PLAYER_1, settingsOverlayInputRedirect)
	end
	MESSAGEMAN:Broadcast("MusicWheelSettingsOverlayStateChanged", {active = active})
end

setQuickMenuActive = function(active)
	if quickMenuActive == active then return end
	quickMenuActive = active
	setenv("QuickMenuActive", active)
	if active then
		if settingsOverlayActive then
			setSettingsOverlayActive(false)
		end
		if statsOverlayActive then
			setStatsOverlayActive(false)
		end
		quickMenuInputRedirect = SCREENMAN:get_input_redirected(PLAYER_1)
		SCREENMAN:set_input_redirected(PLAYER_1, true)
	else
		SCREENMAN:set_input_redirected(PLAYER_1, quickMenuInputRedirect)
	end
	MESSAGEMAN:Broadcast("QuickMenuStateChanged", {active = active})
end

function openServiceMenu()
	setQuickMenuActive(false)
	SCREENMAN:SetNewScreen("ScreenOptionsService")
end

function openNoteskinOptions()
	setQuickMenuActive(false)
	setenv("NewOptions", "Main")
	local top = SCREENMAN:GetTopScreen()
	if top and top.OpenOptions then
		top:OpenOptions()
	end
end

function openKeyConfig()
	setQuickMenuActive(false)
	SCREENMAN:SetNewScreen("ScreenMapControllers")
end

function input(event)
	local deviceButton = event.DeviceInput and event.DeviceInput.button or nil
	if deviceButton == "DeviceButton_left mouse button" then
		local mouseX = INPUTFILTER:GetMouseX()
		local mouseY = INPUTFILTER:GetMouseY()
		if pointInMusicWheelSettingsButton(mouseX, mouseY) then
			if event.type == "InputEventType_FirstPress" then
				MESSAGEMAN:Broadcast("ToggleMusicWheelSettingsOverlay")
			end
			return true
		end
	end
	if settingsOverlayActive and event.type == "InputEventType_FirstPress" then
		if event.button == "Back" or deviceButton == "DeviceButton_right mouse button" then
			setSettingsOverlayActive(false)
			return true
		end
	end
	if settingsOverlayActive and deviceButton == "DeviceButton_left mouse button" then
		if event.type == "InputEventType_FirstPress" then
			local mouseX = INPUTFILTER:GetMouseX()
			local mouseY = INPUTFILTER:GetMouseY()
			local handled = false
			for index, option in ipairs(musicWheelDisplayOptions) do
				if pointInSettingsOverlayItem(mouseX, mouseY, index) then
					toggleMusicWheelDisplayOption(option.key)
					handled = true
					break
				end
			end
			if not handled and not pointInRect(mouseX, mouseY, settingsOverlayPanelX, settingsOverlayPanelY, settingsOverlayPanelWidth, settingsOverlayPanelHeight) then
				setSettingsOverlayActive(false)
			end
		end
		return true
	end
	if settingsOverlayActive and deviceButton == "DeviceButton_right mouse button" then
		return true
	end
	if quickMenuActive and event.type == "InputEventType_FirstPress" then
		if event.button == "Back" or deviceButton == "DeviceButton_right mouse button" then
			setQuickMenuActive(false)
			return true
		end
	end
	if quickMenuActive and deviceButton == "DeviceButton_left mouse button" then
		if event.type == "InputEventType_FirstPress" then
			local mouseX = INPUTFILTER:GetMouseX()
			local mouseY = INPUTFILTER:GetMouseY()
			if pointInQuickMenuItem(mouseX, mouseY, 1) then
				openServiceMenu()
			elseif pointInQuickMenuItem(mouseX, mouseY, 2) then
				openNoteskinOptions()
			elseif pointInQuickMenuItem(mouseX, mouseY, 3) then
				openKeyConfig()
			elseif not pointInRect(mouseX, mouseY, quickMenuPanelX, quickMenuPanelY, quickMenuPanelWidth, quickMenuPanelHeight) then
				setQuickMenuActive(false)
			end
		end
		return true
	end
	if quickMenuActive and deviceButton == "DeviceButton_right mouse button" then
		return true
	end
	if statsOverlayActive and event.type == "InputEventType_FirstPress" then
		if event.button == "Back" or deviceButton == "DeviceButton_right mouse button" then
			setStatsOverlayActive(false)
			return true
		elseif deviceButton == "DeviceButton_mousewheel up" then
			MESSAGEMAN:Broadcast("StatsOverlayMouseWheel", {direction = "up"})
			return true
		elseif deviceButton == "DeviceButton_mousewheel down" then
			MESSAGEMAN:Broadcast("StatsOverlayMouseWheel", {direction = "down"})
			return true
		elseif event.button == "MenuLeft" or event.button == "MenuRight" then
			if isStatsOverlaySessionTab() then
				shiftSelectedDay(event.button == "MenuLeft" and -1 or 1)
				sessionScoreOffset = 0
				lastSessionDisplayKey = nil
				MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
				return true
			end
		end
	end
	if statsOverlayActive and deviceButton == "DeviceButton_left mouse button" then
		if event.type == "InputEventType_FirstPress" then
			MESSAGEMAN:Broadcast("MouseDown", {event = event})
			local mouseX = INPUTFILTER:GetMouseX()
			local mouseY = INPUTFILTER:GetMouseY()
			if pointInBox(mouseX, mouseY, overlayCloseButtonX, overlayCloseButtonY, overlayCloseButtonHalfWidth, overlayCloseButtonHalfHeight) then
				setStatsOverlayActive(false)
			else
				local selectedTab = getStatsOverlayTabAtPosition(mouseX, mouseY)
				if selectedTab then
					setStatsOverlayTab(selectedTab)
				elseif isStatsOverlayOverallTab() then
					local subviewTab = getOverallSubviewTabAtPosition(mouseX, mouseY)
					if subviewTab then
						setOverallSubviewTab(subviewTab)
					elseif pointInRect(mouseX, mouseY, 225, 162, 80, 24) then
						SCREENMAN:SetNewScreen("ScreenAssetSettings")
					end
				elseif isStatsOverlayLeaderboardsTab() then
					local breakdownSubview = getBreakdownSubviewTabAtPosition(mouseX, mouseY)
					if breakdownSubview then
						if breakdownSubview == breakdownSubviewTabs.PerHandBreakdown and isCurrentKeymodeOdd() then
							-- Disabled for odd keymodes
						else
							setBreakdownSubviewTab(breakdownSubview)
						end
					else
						local predictionMode = getSkillPredictionModeAtPosition(mouseX, mouseY)
						if predictionMode then
							setSkillPredictionMode(predictionMode)
						else
							local phMode = getPerHandModeAtPosition(mouseX, mouseY)
							if phMode then
								setPerHandMode(phMode)
							else
								local selectedJudge = getBreakdownJudgeAtPosition(mouseX, mouseY)
								if selectedJudge and selectedJudge ~= breakdownSelectedJudge then
									breakdownSelectedJudge = selectedJudge
									leaderboardScoreOffset = 0
									MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
								end
							end
						end
					end
				elseif isStatsOverlaySessionTab() and pointInRect(mouseX, mouseY, activityPrevButtonX, activityPrevButtonY, activityButtonWidth, activityButtonHeight) then
					shiftSelectedMonth(-1)
					sessionScoreOffset = 0
					lastSessionDisplayKey = nil
					MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
				elseif isStatsOverlaySessionTab() and pointInRect(mouseX, mouseY, activityNextButtonX, activityNextButtonY, activityButtonWidth, activityButtonHeight) then
					shiftSelectedMonth(1)
					sessionScoreOffset = 0
					lastSessionDisplayKey = nil
					MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
				elseif isStatsOverlaySessionTab() then
					local day = getActivityDayAtPosition(mouseX, mouseY)
					if day then
						selectedDay = day
						sessionScoreOffset = 0
						lastSessionDisplayKey = nil
						MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
					end
				end
			end
		elseif event.type == "InputEventType_Release" then
			MESSAGEMAN:Broadcast("MouseLeftClick")
			MESSAGEMAN:Broadcast("MouseUp", {event = event})
		end
		return true
	end
	if statsOverlayActive and deviceButton == "DeviceButton_right mouse button" then
		return true
	end
	if deviceButton == "DeviceButton_left mouse button" then 
		if event.type == "InputEventType_Release" then
			MESSAGEMAN:Broadcast("MouseLeftClick")
			MESSAGEMAN:Broadcast("MouseUp", {event = event})
		elseif event.type == "InputEventType_FirstPress" then
			MESSAGEMAN:Broadcast("MouseDown", {event = event})
		end
	elseif deviceButton == "DeviceButton_right mouse button" then
		if event.type == "InputEventType_Release" then
			MESSAGEMAN:Broadcast("MouseRightClick")
			MESSAGEMAN:Broadcast("MouseUp", {event = event})
		elseif event.type == "InputEventType_FirstPress" then
			MESSAGEMAN:Broadcast("MouseDown", {event = event})
		end
	end
	return false
end

function sessionRow(i)
	return Def.ActorFrame {
		Name = "Row" .. i,
		InitCommand = function(self)
			self:xy(sessionPanelX + 16, sessionPanelY + 64 + ((i - 1) * 54))
			self:visible(false)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Update")
		end,
		UpdateCommand = function(self)
			if not isStatsOverlaySessionTab() then
				self:visible(false)
				return
			end
			local score = selectedScoresForDisplay[sessionScoreOffset + i]
			if not score then
				self:visible(false)
				return
			end
			local chartKey = score:GetChartKey()
			local song = SONGMAN:GetSongByChartKey(chartKey)
			local steps = SONGMAN:GetStepsByChartKey(chartKey)
			local ssr = score:GetSkillsetSSR("Overall")
			local meta = song and song:GetDisplayArtist() or "Unknown Artist"
			local subtitle = song and song:GetDisplaySubTitle() or ""
			if subtitle ~= "" then
				meta = meta .. " - " .. subtitle
			end
			self:visible(true)
			self:GetChild("Title"):settext(song and song:GetDisplayMainTitle() or chartKey)
			self:GetChild("Meta"):settext(meta)
			self:GetChild("Chart"):settext(formatChartMeter(steps))
			self:GetChild("Rate"):settext(formatRate(score))
			self:GetChild("Percent"):settext(string.format("%s [%s]", formatPercent(score), formatJudge(score)))
			self:GetChild("Percent"):diffuse(getGradeColor(score:GetWifeGrade()))
			self:GetChild("ClearType"):settext(getClearTypeFromScore(PLAYER_1, score, 0))
			self:GetChild("ClearType"):diffuse(getClearTypeFromScore(PLAYER_1, score, 2))
			if ssr and ssr > 0 then
				self:GetChild("SSR"):settext(string.format("%.2f", ssr))
				self:GetChild("SSR"):diffuse(HVColor.GetMSDRatingColor(ssr))
			else
				self:GetChild("SSR"):settext("--")
				self:GetChild("SSR"):diffuse(color("#888888"))
			end
		end,
		Def.Quad {
			InitCommand = function(self)
				self:xy(-8, 0):halign(0):valign(0):zoomto(sessionCardWidth + 16, 42):diffuse(color("#000000")):diffusealpha(0.3)
			end
		},
		LoadFont("Common Large") .. {
			Name = "Title",
			InitCommand = function(self)
				self:xy(0, 4):halign(0):valign(0):zoom(0.38):maxwidth(1200)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Meta",
			InitCommand = function(self)
				self:xy(0, 22):halign(0):valign(0):zoom(0.28):diffuse(color("#888888")):maxwidth(1200)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Chart",
			InitCommand = function(self)
				self:xy(0, 36):halign(0):valign(0):zoom(0.24):diffuse(color("#666666")):maxwidth(1200)
			end
		},
		LoadFont("Common Large") .. {
			Name = "Percent",
			InitCommand = function(self)
				self:xy(sessionCardWidth, 4):halign(1):valign(0):zoom(0.38)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Rate",
			InitCommand = function(self)
				self:xy(sessionCardWidth, 26):halign(1):valign(0):zoom(0.3):diffuse(color("#AAAAAA"))
			end
		},
		LoadFont("Common Large") .. {
			Name = "ClearType",
			InitCommand = function(self)
				self:xy(sessionCardWidth - 300, 4):halign(1):valign(0):zoom(0.34)
			end
		},
		LoadFont("Common Large") .. {
			Name = "SSR",
			InitCommand = function(self)
				self:xy(sessionCardWidth - 300, 26):halign(1):valign(0):zoom(0.34)
			end
		}
	}
end

function statsOverlayTabButton(button)
	return Def.ActorFrame {
		Name = "TabButton" .. tostring(button.tab),
		InitCommand = function(self)
			self:xy(button.left, statsOverlayTabTop)
			self:queuecommand("Set")
		end,
		SetCommand = function(self)
			local active = statsOverlayTab == button.tab
			self:GetChild("Label"):diffuse(active and color("#FFFFFF") or color("#BBBBBB"))
			self:GetChild("ActiveLine"):visible(active)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(button.width, statsOverlayTabHeight):diffusealpha(0)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(12, 17):halign(0):valign(0.5):zoom(0.42):settext(button.label)
			end
		},
		Def.Quad {
			Name = "ActiveLine",
			InitCommand = function(self)
				self:xy(0, statsOverlayTabHeight - 6):halign(0):valign(1):zoomto(button.width, 2):diffuse(color("#FFFFFF")):visible(false)
			end
		}
	}
end

function overallSubviewButton(button)
	return Def.ActorFrame {
		Name = "OverallSubviewButton" .. tostring(button.tab),
		InitCommand = function(self)
			self:xy(button.left, button.top):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayOverallSubview(button.tab)
			self:visible(isStatsOverlayOverallTab())
			self:GetChild("Label"):diffuse(active and color("#FFFFFF") or color("#AFAFAF"))
			self:GetChild("Underline"):visible(active)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(button.width, 24):diffusealpha(0)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(0, 12):halign(0):valign(0.5):zoom(0.392):settext(button.label)
			end
		},
		Def.Quad {
			Name = "Underline",
			InitCommand = function(self)
				self:xy(0, 24):halign(0):valign(1):zoomto(button.width, 2):diffuse(color("#FFFFFF")):visible(false)
			end
		}
	}
end

function breakdownSubviewButton(button)
	return Def.ActorFrame {
		Name = "BreakdownSubviewButton" .. tostring(button.tab),
		InitCommand = function(self)
			self:xy(button.left, button.top):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayBreakdownSubview(button.tab)
			self:visible(isStatsOverlayLeaderboardsTab())
			self:GetChild("Label"):diffuse(active and color("#FFFFFF") or color("#AFAFAF"))
			self:GetChild("Underline"):visible(active)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(button.width, 24):diffusealpha(0)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(0, 12):halign(0):valign(0.5):zoom(0.392):settext(button.label)
			end
		},
		Def.Quad {
			Name = "Underline",
			InitCommand = function(self)
				self:xy(0, 24):halign(0):valign(1):zoomto(button.width, 2):diffuse(color("#FFFFFF")):visible(false)
			end
		}
	}
end

function overallSkillsetRow(i)
	return Def.ActorFrame {
		Name = "OverallSkillset" .. i,
		InitCommand = function(self)
			self:xy(16, 284 + ((i - 1) * 18))
		end,
		SetCommand = function(self)
			local entry = overallProfileSummary and overallProfileSummary.skillsets and overallProfileSummary.skillsets[i] or nil
			self:visible(entry ~= nil and isStatsOverlayOverallTab())
			if not entry then return end
			self:GetChild("Name"):settext(entry.name)
			self:GetChild("Rating"):settext(string.format("%05.2f", entry.rating or 0))
			self:GetChild("Rating"):diffuse(HVColor.GetMSDRatingColor(entry.rating or 0))
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(272, 16):diffuse(color("#000000")):diffusealpha(0.4)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Name",
			InitCommand = function(self)
				self:xy(8, 8):halign(0):valign(0.5):zoom(0.24):maxwidth(400)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Rating",
			InitCommand = function(self)
				self:xy(264, 8):halign(1):valign(0.5):zoom(0.24)
			end
		}
	}
end

function overallBestScoreRow(i)
	local isChartColumn = i <= overallMostPlayedRowsPerColumn
	local rowIndex = isChartColumn and i or (i - overallMostPlayedRowsPerColumn)
	local columnOffsetX = isChartColumn and 0 or (overallMostPlayedColumnWidth + overallMostPlayedColumnGap)
	return Def.ActorFrame {
		Name = "OverallBestScoreRow" .. i,
		InitCommand = function(self)
			self:xy(sessionPanelX + 16 + columnOffsetX, sessionPanelY + 104 + ((rowIndex - 1) * 38))
			self:visible(false)
		end,
		SetCommand = function(self)
			local entry = isChartColumn and overallMostPlayedChartsForDisplay[rowIndex] or overallMostPlayedFoldersForDisplay[rowIndex]
			local active = isStatsOverlayOverallSubview(overallSubviewTabs.MostPlayed)
			self:visible(active and entry ~= nil)
			if not entry then return end
			self:GetChild("Rank"):settext(string.format("%s%d", isChartColumn and "C" or "F", rowIndex))
			self:GetChild("Title"):settext(entry.title)
			self:GetChild("Meta"):settext(entry.meta or "")
			self:GetChild("Percent"):settext(formatInteger(entry.count or 0))
			self:GetChild("Percent"):diffuse(color("#FFFFFF"))
			self:GetChild("Rate"):settext("plays")
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(overallMostPlayedColumnWidth, 28):diffuse(color("#111111")):diffusealpha(0.82)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Rank",
			InitCommand = function(self)
				self:xy(6, 6):halign(0):valign(0):zoom(0.336):diffuse(color("#BBBBBB"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Title",
			InitCommand = function(self)
				self:xy(40, 3):halign(0):valign(0):zoom(0.336):maxwidth(560)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Meta",
			InitCommand = function(self)
				self:xy(40, 17):halign(0):valign(0):zoom(0.252):diffuse(color("#AFAFAF")):maxwidth(760)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Percent",
			InitCommand = function(self)
				self:xy(overallMostPlayedColumnWidth - 56, 6):halign(1):valign(0):zoom(0.308)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Rate",
			InitCommand = function(self)
				self:xy(overallMostPlayedColumnWidth - 10, 6):halign(1):valign(0):zoom(0.28):diffuse(color("#DDDDDD"))
			end
		}
	}
end

function overallMostPlayedHeader(label, alignLeft)
	local columnOffsetX = alignLeft and 0 or (overallMostPlayedColumnWidth + overallMostPlayedColumnGap)
	return LoadFont("Common Normal") .. {
		Name = "OverallMostPlayedHeader" .. label,
		InitCommand = function(self)
			self:xy(sessionPanelX + 16 + columnOffsetX, sessionPanelY + 84):halign(0):valign(0):zoom(0.364)
			self:diffuse(color("#DADADA"))
		end,
		SetCommand = function(self)
			self:visible(isStatsOverlayOverallSubview(overallSubviewTabs.MostPlayed))
			self:settext(label)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function overallOverviewRow(i)
	return Def.ActorFrame {
		Name = "OverallOverviewRow" .. i,
		InitCommand = function(self)
			self:xy(sessionPanelX + 16, sessionPanelY + 96 + ((i - 1) * 32))
			self:visible(false)
		end,
		SetCommand = function(self)
			local entry = overallOverviewRowsForDisplay[i]
			local active = isStatsOverlayOverallSubview(overallSubviewTabs.WifeTimeline) -- Show on overview subview
			self:visible(active and entry ~= nil)
			if not entry then return end
			self:GetChild("Label"):settext(entry.label)
			self:GetChild("Scores"):settext(formatInteger(entry.scoreCount))
			self:GetChild("Charts"):settext(formatInteger(entry.chartCount))
			self:GetChild("Average"):settext(entry.averagePercent)
			self:GetChild("Best"):settext(string.format("%.2f", entry.bestSSR or 0))
			self:GetChild("Best"):diffuse(HVColor.GetMSDRatingColor(entry.bestSSR or 0))
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(sessionCardWidth, 26):diffuse(color("#000000")):diffusealpha(0.3)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(12, 13):halign(0):valign(0.5):zoom(0.26):maxwidth(600)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Scores",
			InitCommand = function(self)
				self:xy(350, 13):halign(1):valign(0.5):zoom(0.26)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Charts",
			InitCommand = function(self)
				self:xy(450, 13):halign(1):valign(0.5):zoom(0.26)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Average",
			InitCommand = function(self)
				self:xy(550, 13):halign(1):valign(0.5):zoom(0.26):diffuse(color("#DDDDDD"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Best",
			InitCommand = function(self)
				self:xy(sessionCardWidth - 12, 13):halign(1):valign(0.5):zoom(0.26)
			end
		}
	}
end

function overallTimelineLine(i)
	return Def.ActorMultiVertex {
		Name = "OverallTimelineLine" .. i,
		InitCommand = function(self)
			self:visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayOverallTimelineSubview()
			if not active or #overallTimelineDaysForDisplay == 0 then
				self:visible(false)
				self:SetVertices({})
				self:SetDrawState {Mode = "DrawMode_LineStrip", First = 1, Num = 0}
				return
			end
			local key, lineColor
			if overallSubviewTab == overallSubviewTabs.WifeTimeline then
				if i == 1 then
					key = "Overall"
					lineColor = timelineSkillsetColors["Overall"]
				elseif i == 2 then
					key = "Average"
					lineColor = color("#B8B8B8")
				else
					self:visible(false)
					self:SetVertices({})
					self:SetDrawState {Mode = "DrawMode_LineStrip", First = 1, Num = 0}
					return
				end
			else
				local skillset = ms.SkillSets[i]
				if not skillset then
					self:visible(false)
					self:SetVertices({})
					self:SetDrawState {Mode = "DrawMode_LineStrip", First = 1, Num = 0}
					return
				end
				key = skillset
				lineColor = timelineSkillsetColors[skillset] or color("#FFFFFF")
			end
			local verts = {}
			for index, day in ipairs(overallTimelineDaysForDisplay) do
				local x = timelineGraphLeft + fitOverallTimelineX(index)
				local y = timelineGraphTop + fitOverallTimelineY(day.values[key] or 0)
				-- Clamp y to graph bounds
				if y < timelineGraphTop then y = timelineGraphTop end
				if y > timelineGraphTop + timelineGraphHeight then y = timelineGraphTop + timelineGraphHeight end
				verts[#verts + 1] = {{x, y, 0}, lineColor}
			end
			self:visible(#verts > 1)
			self:SetVertices(verts)
			self:SetDrawState {Mode = "DrawMode_LineStrip", First = 1, Num = #verts}
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function overallTimelineDot(i)
	return Def.Quad {
		Name = "OverallTimelineDot" .. i,
		InitCommand = function(self)
			self:halign(0.5):valign(0.5):zoomto(5, 5):visible(false)
		end,
		SetCommand = function(self)
			local day = overallTimelineDaysForDisplay[overallTimelineHoveredIndex or 0]
			if not isStatsOverlayOverallTimelineSubview() or not day then
				self:visible(false)
				return
			end
			local key, lineColor
			if overallSubviewTab == overallSubviewTabs.WifeTimeline then
				if i == 1 then
					key = "Overall"
					lineColor = timelineSkillsetColors["Overall"]
				elseif i == 2 then
					key = "Average"
					lineColor = color("#B8B8B8")
				else
					self:visible(false)
					return
				end
			else
				local skillset = ms.SkillSets[i]
				if not skillset then
					self:visible(false)
					return
				end
				key = skillset
				lineColor = timelineSkillsetColors[skillset] or color("#FFFFFF")
			end
			local x = timelineGraphLeft + fitOverallTimelineX(overallTimelineHoveredIndex)
			local y = timelineGraphTop + fitOverallTimelineY(day.values[key] or 0)
			if y < timelineGraphTop then y = timelineGraphTop end
			if y > timelineGraphTop + timelineGraphHeight then y = timelineGraphTop + timelineGraphHeight end
			self:visible(true)
			self:xy(x, y)
			self:diffuse(lineColor)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function overallTimelineLegend(i)
	return Def.ActorFrame {
		Name = "OverallTimelineLegend" .. i,
		InitCommand = function(self)
			local column = math.floor((i - 1) / 4)
			local row = (i - 1) % 4
			self:xy(timelineGraphLeft + (column * 210), timelineGraphTop + timelineGraphHeight + 52 + (row * 18))
			self:visible(false)
		end,
		SetCommand = function(self)
			local day = overallTimelineDaysForDisplay[overallTimelineHoveredIndex or 0]
			if not isStatsOverlayOverallTimelineSubview() or not day then
				self:visible(false)
				return
			end
			local label, value, lineColor
			if overallSubviewTab == overallSubviewTabs.WifeTimeline then
				if i == 1 then
					label = "Overall"
					value = day.values.Overall or 0
					lineColor = timelineSkillsetColors["Overall"]
				elseif i == 2 then
					label = "Average"
					value = day.values.Average or 0
					lineColor = color("#B8B8B8")
				else
					self:visible(false)
					return
				end
			else
				local skillset = ms.SkillSets[i]
				if not skillset then
					self:visible(false)
					return
				end
				label = skillset
				value = day.values[skillset] or 0
				lineColor = timelineSkillsetColors[skillset] or color("#FFFFFF")
			end
			self:visible(true)
			self:GetChild("Swatch"):diffuse(lineColor)
			self:GetChild("Label"):settext(label)
			self:GetChild("Value"):settext(string.format("%.2f", value))
			self:GetChild("Value"):diffuse(lineColor)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		Def.Quad {
			Name = "Swatch",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(13, 13)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(20, 0):halign(0):valign(0):zoom(0.39):maxwidth(240)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Value",
			InitCommand = function(self)
				self:xy(178, 0):halign(1):valign(0):zoom(0.39)
			end
		}
	}
end

function overallTimelineHorizontalGridline(i)
	return Def.Quad {
		Name = "OverallTimelineHorizontalGridline" .. i,
		InitCommand = function(self)
			self:halign(0):valign(0.5):zoomto(timelineGraphWidth, 1):diffuse(color("#FFFFFF")):diffusealpha(0.08):visible(false)
		end,
		SetCommand = function(self)
			local activeTimeline = isStatsOverlayOverallTimelineSubview() and #overallTimelineDaysForDisplay > 0
			local activeMsd = isStatsOverlayOverallSubview(overallSubviewTabs.MsdGrade) and #overallMsdGradePointsForDisplay > 0
			self:visible(activeTimeline or activeMsd)
			if not (activeTimeline or activeMsd) then return end
			
			if activeMsd then
				local yPositions = {
					timelineGraphTop, -- 100%
					timelineGraphTop + (timelineGraphHeight / 4), -- 99.955%
					timelineGraphTop + (2 * timelineGraphHeight / 4), -- 99.7%
					timelineGraphTop + (3 * timelineGraphHeight / 4), -- 93%
					timelineGraphTop + timelineGraphHeight -- 80%
				}
				
				local midYPositions = {
					timelineGraphTop + (timelineGraphHeight / 4) - ((99.9935 - 99.955) / 0.045) * (timelineGraphHeight / 4),
					timelineGraphTop + (timelineGraphHeight / 4) - ((99.98 - 99.955) / 0.045) * (timelineGraphHeight / 4),
					timelineGraphTop + (timelineGraphHeight / 4) - ((99.97 - 99.955) / 0.045) * (timelineGraphHeight / 4),
					timelineGraphTop + (2 * timelineGraphHeight / 4) - ((99.9 - 99.7) / 0.255) * (timelineGraphHeight / 4),
					timelineGraphTop + (2 * timelineGraphHeight / 4) - ((99.8 - 99.7) / 0.255) * (timelineGraphHeight / 4),
					timelineGraphTop + (3 * timelineGraphHeight / 4) - ((99 - 93) / 6.7) * (timelineGraphHeight / 4),
					timelineGraphTop + (3 * timelineGraphHeight / 4) - ((96.5 - 93) / 6.7) * (timelineGraphHeight / 4)
				}
				
				if i <= 5 then
					self:xy(timelineGraphLeft, yPositions[i])
					self:diffusealpha(0.12)
					self:visible(true)
				elseif i <= 12 then
					self:xy(timelineGraphLeft, midYPositions[i - 5])
					self:diffusealpha(0.04)
					self:visible(true)
				else
					self:visible(false)
				end
			else
				-- Normal timeline
				if i <= timelineYAxisTickCount then
					self:xy(timelineGraphLeft, getOverallTimelineGridY(i, timelineYAxisTickCount))
					self:diffusealpha(0.08)
					self:visible(true)
				else
					self:visible(false)
				end
			end
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function overallTimelineVerticalGridline(i)
	return Def.Quad {
		Name = "OverallTimelineVerticalGridline" .. i,
		InitCommand = function(self)
			self:halign(0.5):valign(0):zoomto(1, timelineGraphHeight):diffuse(color("#FFFFFF")):diffusealpha(0.06):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayOverallTimelineSubview() and #overallTimelineDaysForDisplay > 0
			self:visible(active)
			if not active then return end
			self:xy(getOverallTimelineGridX(i, timelineXAxisTickCount), timelineGraphTop)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function overallTimelineYAxisLabel(i)
	return LoadFont("Common Normal") .. {
		Name = "OverallTimelineYAxisLabel" .. i,
		InitCommand = function(self)
			self:halign(1):valign(0.5):zoom(0.29):diffuse(color("#9A9A9A")):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayOverallTimelineSubview() and #overallTimelineDaysForDisplay > 0 and i <= timelineYAxisTickCount
			self:visible(active)
			if not active then return end
			self:xy(timelineGraphLeft - 6, getOverallTimelineGridY(i, timelineYAxisTickCount))
			local labelValue = getOverallTimelineYAxisLabel(i)
			local label
			if overallSubviewTab == overallSubviewTabs.WifeTimeline then
				label = string.format("%.0f%%", labelValue)
			else
				label = string.format("%.2f", labelValue)
			end
			self:settext(label)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function overallTimelineXAxisLabel(i)
	return LoadFont("Common Normal") .. {
		Name = "OverallTimelineXAxisLabel" .. i,
		InitCommand = function(self)
			self:valign(0):zoom(0.29):diffuse(color("#9A9A9A")):visible(false)
		end,
		SetCommand = function(self)
			local x, day, fraction = getOverallTimelineXAxisDisplay(i)
			local active = isStatsOverlayOverallTimelineSubview() and day ~= nil
			self:visible(active)
			if not active then return end
			if fraction == 0 then
				self:halign(0)
			elseif fraction == 1 then
				self:halign(1)
			else
				self:halign(0.5)
			end
			self:xy(x, timelineGraphTop + timelineGraphHeight + 12)
			self:settext(day.label or os.date("%d %b %y", day.timestamp or os.time()))
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function overallMsdGradeLabel(i)
	return LoadFont("Common Normal") .. {
		Name = "OverallMsdGradeLabel" .. i,
		InitCommand = function(self)
			self:halign(1):valign(0.5):zoom(0.36):diffuse(color("#9A9A9A")):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayOverallSubview(overallSubviewTabs.MsdGrade) and #overallMsdGradePointsForDisplay > 0
			self:visible(active)
			if not active then return end
			-- Show gridline thresholds instead of section labels
			local labels = {"100%", "99.955% (AAAA)", "99.7% (AAA)", "93% (AA)", "80%"}
			local yPositions = {
				timelineGraphTop, -- 100%
				timelineGraphTop + (timelineGraphHeight / 4), -- 99.955%
				timelineGraphTop + (2 * timelineGraphHeight / 4), -- 99.7%
				timelineGraphTop + (3 * timelineGraphHeight / 4), -- 93%
				timelineGraphTop + timelineGraphHeight -- 80%
			}
			
			-- Add mid-grade thresholds as smaller, slightly offset labels
			local midLabels = {"99.9935% (AAAAA)", "99.98% (AAAA:)", "99.97% (AAAA.)", "99.9% (AAA.)", "99.8% (AAA:)", "99% (AA.)", "96.5% (AA:)"}
			local midYPositions = {
				timelineGraphTop + (timelineGraphHeight / 4) - ((99.9935 - 99.955) / 0.045) * (timelineGraphHeight / 4),
				timelineGraphTop + (timelineGraphHeight / 4) - ((99.98 - 99.955) / 0.045) * (timelineGraphHeight / 4),
				timelineGraphTop + (timelineGraphHeight / 4) - ((99.97 - 99.955) / 0.045) * (timelineGraphHeight / 4),
				timelineGraphTop + (2 * timelineGraphHeight / 4) - ((99.9 - 99.7) / 0.255) * (timelineGraphHeight / 4),
				timelineGraphTop + (2 * timelineGraphHeight / 4) - ((99.8 - 99.7) / 0.255) * (timelineGraphHeight / 4),
				timelineGraphTop + (3 * timelineGraphHeight / 4) - ((99 - 93) / 6.7) * (timelineGraphHeight / 4),
				timelineGraphTop + (3 * timelineGraphHeight / 4) - ((96.5 - 93) / 6.7) * (timelineGraphHeight / 4)
			}

			if i <= 5 then
				self:xy(timelineGraphLeft - 6, yPositions[i])
				self:settext(labels[i])
				self:diffuse(color("#DDDDDD"))
				self:zoom(0.36)
			elseif i <= 12 then
				self:xy(timelineGraphLeft - 6, midYPositions[i - 5])
				self:settext(midLabels[i - 5])
				self:diffuse(color("#888888"))
				self:zoom(0.26)
			else
				self:visible(false)
			end
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end

function overallMsdGradePoint(i)
	return Def.Quad {
		Name = "OverallMsdGradePoint" .. i,
		InitCommand = function(self)
			self:halign(0.5):valign(0.5):zoomto(2, 2):visible(false)
		end,
		SetCommand = function(self)
			local point = overallMsdGradePointsForDisplay[i]
			if not isStatsOverlayOverallSubview(overallSubviewTabs.MsdGrade) or not point then
				self:visible(false)
				return
			end
			local maxX = 1
			for _, candidate in ipairs(overallMsdGradePointsForDisplay) do
				if (candidate.x or 0) > maxX then maxX = candidate.x end
			end
			-- Map actual grade thresholds to 4 equal height sections
			-- Section 1 (bottom 1/4): 80% -> 93% (AA threshold)
			-- Section 2 (second 1/4): 93% -> 99.7% (AAA threshold)
			-- Section 3 (third 1/4): 99.7% -> 99.955% (AAAA threshold)
			-- Section 4 (top 1/4): 99.955% -> 100%
			local percent = point.y or 0
			local yPosition
			if percent < 93 then
				-- Below AA: maps to bottom 1/4 (80-93%)
				yPosition = timelineGraphTop + timelineGraphHeight - ((percent - 80) / 13) * (timelineGraphHeight / 4)
			elseif percent < 99.7 then
				-- AA to AAA: maps to second 1/4 (93-99.7%)
				yPosition = timelineGraphTop + (3 * timelineGraphHeight / 4) - ((percent - 93) / 6.7) * (timelineGraphHeight / 4)
			elseif percent < 99.955 then
				-- AAA to AAAA: maps to third 1/4 (99.7-99.955%)
				yPosition = timelineGraphTop + (2 * timelineGraphHeight / 4) - ((percent - 99.7) / 0.255) * (timelineGraphHeight / 4)
			else
				-- AAAA and above: maps to top 1/4 (99.955-100%)
				local cappedPercent = math.min(percent, 100)
				yPosition = timelineGraphTop + (timelineGraphHeight / 4) - ((cappedPercent - 99.955) / 0.045) * (timelineGraphHeight / 4)
			end
			-- Clamp to graph bounds
			yPosition = math.max(timelineGraphTop, math.min(timelineGraphTop + timelineGraphHeight, yPosition))
			self:visible(true)
			self:xy(timelineGraphLeft + ((point.x or 0) / maxX * timelineGraphWidth), yPosition)
			self:diffuse(getGradeColor(point.grade))
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end
function overallMsdGradeXAxisLabel(i)
	return LoadFont("Common Normal") .. {
		Name = "OverallMsdGradeXAxisLabel" .. i,
		InitCommand = function(self)
			self:valign(0):zoom(0.36):diffuse(color("#9A9A9A")):visible(false)
		end,
		SetCommand = function(self)
			local active = isStatsOverlayOverallSubview(overallSubviewTabs.MsdGrade) and #overallMsdGradePointsForDisplay > 0
			self:visible(active)
			if not active then return end

			local maxX = 1
			for _, candidate in ipairs(overallMsdGradePointsForDisplay) do
				if (candidate.x or 0) > maxX then maxX = candidate.x end
			end

			-- Make 5 nice round numbers for the X axis (0 to maxX)
			-- E.g. if max is 28, show 0, 7, 14, 21, 28
			if i <= 5 then
				local fraction = (i - 1) / 4
				local val = maxX * fraction
				
				if fraction == 0 then
					self:halign(0)
				elseif fraction == 1 then
					self:halign(1)
				else
					self:halign(0.5)
				end
				
				self:xy(timelineGraphLeft + (fraction * timelineGraphWidth), timelineGraphTop + timelineGraphHeight + 12)
				self:settext(string.format("%.0f", val))
				self:visible(true)
			else
				self:visible(false)
			end
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayOverallSubviewChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
end
function overallMsdGradeTooltip()
	return Def.ActorFrame {
		Name = "OverallMsdGradeTooltip",
		InitCommand = function(self)
			self:visible(false)
			self:z(100)
			self:SetUpdateFunction(function(self)
				self:playcommand("HoverUpdate")
			end)
		end,
		HoverUpdateCommand = function(self)
			local active = isStatsOverlayOverallSubview(overallSubviewTabs.MsdGrade) and statsOverlayActive
			if not active then
				self:visible(false)
				return
			end
			
			local mouseX = INPUTFILTER:GetMouseX()
			local mouseY = INPUTFILTER:GetMouseY()
			
			if not pointInRect(mouseX, mouseY, timelineGraphLeft, timelineGraphTop, timelineGraphWidth, timelineGraphHeight) then
				self:visible(false)
				return
			end
			
			local maxX = 1
			for _, candidate in ipairs(overallMsdGradePointsForDisplay) do
				if (candidate.x or 0) > maxX then maxX = candidate.x end
			end
			
			local minDistance = 15 -- Max hover distance
			local hoveredPoint = nil
			
			for _, point in ipairs(overallMsdGradePointsForDisplay) do
				local px = timelineGraphLeft + ((point.x or 0) / maxX * timelineGraphWidth)
				local percent = point.y or 0
				local py
				if percent < 93 then
					py = timelineGraphTop + timelineGraphHeight - ((percent - 80) / 13) * (timelineGraphHeight / 4)
				elseif percent < 99.7 then
					py = timelineGraphTop + (3 * timelineGraphHeight / 4) - ((percent - 93) / 6.7) * (timelineGraphHeight / 4)
				elseif percent < 99.955 then
					py = timelineGraphTop + (2 * timelineGraphHeight / 4) - ((percent - 99.7) / 0.255) * (timelineGraphHeight / 4)
				else
					local cappedPercent = math.min(percent, 100)
					py = timelineGraphTop + (timelineGraphHeight / 4) - ((cappedPercent - 99.955) / 0.045) * (timelineGraphHeight / 4)
				end
				py = math.max(timelineGraphTop, math.min(timelineGraphTop + timelineGraphHeight, py))
				
				local dist = math.sqrt((mouseX - px)^2 + (mouseY - py)^2)
				if dist < minDistance then
					minDistance = dist
					hoveredPoint = point
					hoveredPoint.px = px
					hoveredPoint.py = py
				end
			end
			
			if hoveredPoint then
				self:visible(true)
				self:xy(hoveredPoint.px, hoveredPoint.py - 30)
				
				local songText = hoveredPoint.songName or "Unknown"
				local scoreText = string.format("%.2f%% (%.2f MSD)", hoveredPoint.y, hoveredPoint.x or 0)
				
				self:GetChild("SongName"):settext(songText)
				self:GetChild("Score"):settext(scoreText)
				
				local songWidth = self:GetChild("SongName"):GetZoomedWidth()
				local scoreWidth = self:GetChild("Score"):GetZoomedWidth()
				local w = math.max(songWidth, scoreWidth) + 16
				local h = 42
				
				self:GetChild("BG"):zoomto(w, h)
				
				local leftBound = hoveredPoint.px - w/2
				local rightBound = hoveredPoint.px + w/2
				if rightBound > SCREEN_WIDTH then
					self:addx(SCREEN_WIDTH - rightBound - 10)
				elseif leftBound < 0 then
					self:addx(-leftBound + 10)
				end
			else
				self:visible(false)
			end
		end,
		Def.Quad {
			Name = "BG",
			InitCommand = function(self)
				self:diffuse(color("#111111")):diffusealpha(0.95)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "SongName",
			InitCommand = function(self)
				self:y(-9):zoom(0.33):diffuse(color("#FFFFFF"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Score",
			InitCommand = function(self)
				self:y(9):zoom(0.29):diffuse(getMainColor("highlight"))
			end
		}
	}
end
function breakdownJudgeBar(i)
	return Def.ActorFrame {
		Name = "BreakdownJudgeBar" .. i,
		InitCommand = function(self)
			self:xy(breakdownJudgeBarLeft, breakdownJudgeBarTop + ((i - 1) * breakdownJudgeBarStepY)):visible(false)
		end,
		SetCommand = function(self)
			local entry = breakdownJudgeRowsForDisplay[i]
			local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.JudgeBreakdown) and entry ~= nil
			self:visible(active)
			if not entry then return end
			local maxCount = 1
			for _, row in ipairs(breakdownJudgeRowsForDisplay) do
				if (row.count or 0) > maxCount then maxCount = row.count end
			end
			self:GetChild("Label"):settext(entry.judge)
			self:GetChild("Bar"):zoomto(180 * ((entry.count or 0) / maxCount), 12)
			self:GetChild("Label"):diffuse(entry.judge == breakdownSelectedJudge and getMainColor("highlight") or color("#DDDDDD"))
			self:GetChild("Bar"):diffusealpha(entry.judge == breakdownSelectedJudge and 0.9 or 0.6)
			self:GetChild("Count"):settext(string.format("%d", entry.count or 0))
			self:GetChild("Average"):settext(string.format("%.2f%%", entry.average or 0))
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(0, 0):halign(0):zoom(0.24):diffuse(color("#DDDDDD"))
			end
		},
		Def.Quad {
			Name = "Bar",
			InitCommand = function(self)
				self:xy(48, 2):halign(0):valign(0):zoomto(0, 12):diffuse(getMainColor("highlight")):diffusealpha(0.6)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Count",
			InitCommand = function(self)
				self:xy(240, 0):halign(1):zoom(0.24):diffuse(color("#FFFFFF"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Average",
			InitCommand = function(self)
				self:xy(272, 0):halign(1):zoom(0.22):diffuse(color("#AFAFAF"))
			end
		}
	}
end
function leaderboardRow(i)
	return Def.ActorFrame {
		Name = "LeaderboardRow" .. i,
		InitCommand = function(self)
			self:xy(sessionPanelX + 16, sessionPanelY + 80 + ((i - 1) * 38))
			self:visible(false)
		end,
		SetCommand = function(self)
			local entry = leaderboardEntriesForDisplay[i]
			local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.JudgeBreakdown) and leaderboardStatus.state == "ready"
			self:visible(active and entry ~= nil)
			if not entry then return end
			self:GetChild("Rank"):settext(string.format("#%d", entry.rank))
			self:GetChild("Name"):settext(entry.name)
			self:GetChild("Metric"):settext(entry.metric)
			self:GetChild("Metric"):diffuse(entry.gradeColor or color("#FFFFFF"))
			self:GetChild("Activity"):settext(entry.activity)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(sessionCardWidth, 32):diffuse(color("#000000")):diffusealpha(0.3)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Rank",
			InitCommand = function(self)
				self:xy(12, 16):halign(0):valign(0.5):zoom(0.28):diffuse(color("#BBBBBB"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Name",
			InitCommand = function(self)
				self:xy(60, 16):halign(0):valign(0.5):zoom(0.32):maxwidth(1200)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Metric",
			InitCommand = function(self)
				self:xy(sessionCardWidth - 240, 16):halign(1):valign(0.5):zoom(0.32)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Activity",
			InitCommand = function(self)
				self:xy(sessionCardWidth - 12, 16):halign(1):valign(0.5):zoom(0.26):diffuse(color("#DDDDDD")):maxwidth(700)
			end
		}
	}
end

local statsOverlay = Def.ActorFrame {
	Name = "StatsOverlay",
	InitCommand = function(self)
		self:diffusealpha(0):visible(false):draworder(11000)
		self:SetUpdateFunction(function(actor)
			if not statsOverlayActive then return end
			if isStatsOverlaySessionTab() then
				if overallTimelineHoveredIndex ~= nil then
					overallTimelineHoveredIndex = nil
					actor:playcommand("Update")
				end
				local hovered = getActivityDayAtPosition(INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY())
				if hoveredActivityDay ~= hovered then
					hoveredActivityDay = hovered
					actor:playcommand("Update")
				end
				return
			end
			if hoveredActivityDay ~= nil then
				hoveredActivityDay = nil
				actor:playcommand("Update")
			end
			if isStatsOverlayOverallTimelineSubview() then
				local hoveredTimeline = getOverallTimelineHoverIndex(INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY())
				if overallTimelineHoveredIndex ~= hoveredTimeline then
					overallTimelineHoveredIndex = hoveredTimeline
					actor:playcommand("Update")
				end
			elseif overallTimelineHoveredIndex ~= nil then
				overallTimelineHoveredIndex = nil
				actor:playcommand("Update")
			end
		end)
	end,
	StatsOverlayStateChangedMessageCommand = function(self, params)
		if params.active then
			self:visible(true):stoptweening():linear(0.15):diffusealpha(1):queuecommand("Refresh")
		else
			self:stoptweening():linear(0.15):diffusealpha(0):queuecommand("HideIfClosed")
		end
	end,
	HideIfClosedCommand = function(self)
		if not statsOverlayActive then
			self:visible(false)
		end
	end,
	StatsOverlayDataChangedMessageCommand = function(self)
		if statsOverlayActive then
			self:queuecommand("Update")
		end
	end,
	StatsOverlayTabChangedMessageCommand = function(self)
		if statsOverlayActive then
			self:queuecommand("Update")
		end
	end,
	StatsOverlayOverallSubviewChangedMessageCommand = function(self)
		if statsOverlayActive then
			self:queuecommand("Update")
		end
	end,
	StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
		if statsOverlayActive then
			self:queuecommand("Update")
		end
	end,
	StatsOverlaySkillPredictionModeChangedMessageCommand = function(self)
		if statsOverlayActive then
			self:queuecommand("Update")
		end
	end,
	CurrentRateChangedMessageCommand = function(self)
		if statsOverlayActive then
			self:queuecommand("Update")
		end
	end,
	StatsOverlayMouseWheelMessageCommand = function(self, params)
		if not statsOverlayActive then return end
		local mouseX = INPUTFILTER:GetMouseX()
		local mouseY = INPUTFILTER:GetMouseY()
		if isStatsOverlaySessionTab() then
			if not isOverSessionPanel(mouseX, mouseY) then return end
			if params and params.direction == "up" then
				pageSessionScores(-1)
			elseif params and params.direction == "down" then
				pageSessionScores(1)
			end
		elseif isStatsOverlayOverallSubview(overallSubviewTabs.MostPlayed) then
			if not isOverOverallBestScoresPanel(mouseX, mouseY) then return end
			if params and params.direction == "up" then
				pageOverallBestScores(-1)
			elseif params and params.direction == "down" then
				pageOverallBestScores(1)
			end
		elseif isStatsOverlayLeaderboardsTab() then
			if not isOverLeaderboardScoresPanel(mouseX, mouseY) then return end
			if params and params.direction == "up" then
				pageLeaderboardScores(-1)
			elseif params and params.direction == "down" then
				pageLeaderboardScores(1)
			end
		end
	end,
	RefreshCommand = function(self)
		SCOREMAN:SortRecentScoresForGame()
		self:playcommand("Update")
	end,
	UpdateCommand = function(self)
		self:GetChild("Title"):settext(getStatsOverlayTitle())
		self:GetChild("RightPaneSessions"):visible(isStatsOverlaySessionTab())
		self:GetChild("RightPaneOverall"):visible(statsOverlayTab == statsOverlayTabs.Overall)
		self:GetChild("RightPaneLeaderboards"):visible(statsOverlayTab == statsOverlayTabs.Leaderboards)
		self:GetChild("LeftPaneOverall"):visible(isStatsOverlayOverallTab())
		self:GetChild("LeftPaneLeaderboards"):visible(isStatsOverlayLeaderboardsTab())
		for i = 1, 8 do
			self:GetChild("OverallSkillset" .. i):playcommand("Set")
		end
		if isStatsOverlayOverallTab() then
			refreshOverallDerivedData()
			if overallSubviewTab == overallSubviewTabs.WifeTimeline then
				overallTimelineDaysForDisplay = overallWifeTimelineDaysForDisplay
				overallTimelineMaxValue = 100
				overallTimelineMinValue = 80
			elseif overallSubviewTab == overallSubviewTabs.Rating then
				overallTimelineDaysForDisplay = overallRatingTimelineDaysForDisplay
				setOverallTimelineRatingBounds()
			end
			overallBestScoresForDisplay = getOverallBestScores()
			local rightPaneOverall = self:GetChild("RightPaneOverall")
			rightPaneOverall:GetChild("OverallOverviewHeader"):playcommand("Set")
			rightPaneOverall:GetChild("OverallOverviewEmpty"):playcommand("Set")
			rightPaneOverall:GetChild("OverallTimelineGraphBackdrop"):playcommand("Set")
			rightPaneOverall:GetChild("OverallTimelineHoverLine"):playcommand("Set")
			rightPaneOverall:GetChild("OverallTimelineHoverDate"):playcommand("Set")
			rightPaneOverall:GetChild("OverallTimelineEmpty"):playcommand("Set")
			for i = 1, math.max(timelineYAxisTickCount, 11) do
				local horizontal = self:GetChild("OverallTimelineHorizontalGridline" .. i)
				if horizontal then horizontal:playcommand("Set") end
				local yLabel = self:GetChild("OverallTimelineYAxisLabel" .. i)
				if yLabel then yLabel:playcommand("Set") end
			end
			for i = 1, timelineXAxisTickCount do
				local vertical = self:GetChild("OverallTimelineVerticalGridline" .. i)
				if vertical then vertical:playcommand("Set") end
				local xLabel = self:GetChild("OverallTimelineXAxisLabel" .. i)
				if xLabel then xLabel:playcommand("Set") end
			end
-- for i = 1, overviewRowCount do
-- 	self:GetChild("OverallOverviewRow" .. i):playcommand("Set")
-- end
			for i = 1, getOverallTimelineSkillsetCount() do
				self:GetChild("OverallTimelineLine" .. i):playcommand("Set")
				self:GetChild("OverallTimelineDot" .. i):playcommand("Set")
				self:GetChild("OverallTimelineLegend" .. i):playcommand("Set")
			end
			for i = 1, overallBestScoreRowCount do
				self:GetChild("OverallBestScoreRow" .. i):playcommand("Set")
			end
		elseif isStatsOverlayLeaderboardsTab() then
			refreshLeaderboardData()
			self:GetChild("LeftPaneLeaderboards"):playcommand("Set")
			local rightPaneLeaderboards = self:GetChild("RightPaneLeaderboards")
			rightPaneLeaderboards:GetChild("LeaderboardHeader"):playcommand("Set")
			rightPaneLeaderboards:GetChild("LeaderboardStatusTitle"):playcommand("Set")
			rightPaneLeaderboards:GetChild("LeaderboardStatusDetail"):playcommand("Set")
			rightPaneLeaderboards:GetChild("PredictionHeader"):playcommand("Set")
			rightPaneLeaderboards:GetChild("SkillPredictionGraphBackdrop"):playcommand("Set")
			rightPaneLeaderboards:GetChild("SkillPredictionYAxisTitle"):playcommand("Set")
			rightPaneLeaderboards:GetChild("SkillPredictionXAxisTitle"):playcommand("Set")
			rightPaneLeaderboards:GetChild("SkillPredictionEmpty"):playcommand("Set")
			for i = 1, #skillPredictionModeButtons do
				rightPaneLeaderboards:GetChild("SkillPredictionModeButton" .. tostring(skillPredictionModeButtons[i].mode)):playcommand("Set")
			end
			for i = 1, skillPredictionAxisTickCount do
				self:GetChild("SkillPredictionHorizontalGridline" .. i):playcommand("Set")
				self:GetChild("SkillPredictionVerticalGridline" .. i):playcommand("Set")
				self:GetChild("SkillPredictionYAxisLabel" .. i):playcommand("Set")
				self:GetChild("SkillPredictionXAxisLabel" .. i):playcommand("Set")
			end
			self:GetChild("SkillPredictionCurveLine"):playcommand("Set")
			for i = 1, skillPredictionPointCount do
				self:GetChild("SkillPredictionPoint" .. i):playcommand("Set")
			end
			for i = 1, 12 do
				self:GetChild("BreakdownJudgeBar" .. i):playcommand("Set")
			end
			for i = 1, leaderboardRowCount do
				self:GetChild("LeaderboardRow" .. i):playcommand("Set")
			end

			rightPaneLeaderboards:GetChild("PerHandHeader"):playcommand("Set")
			for i = 1, #perHandModeButtons do
				rightPaneLeaderboards:GetChild("PerHandModeButton" .. tostring(perHandModeButtons[i].mode)):playcommand("Set")
			end
			rightPaneLeaderboards:GetChild("PerHandRatioTitle"):playcommand("Set")
			rightPaneLeaderboards:GetChild("PerHandRatioDesc"):playcommand("Set")
			rightPaneLeaderboards:GetChild("RatioBarBackdrop"):playcommand("Set")
			rightPaneLeaderboards:GetChild("LeftHandFill"):playcommand("Set")
			rightPaneLeaderboards:GetChild("RightHandFill"):playcommand("Set")
			rightPaneLeaderboards:GetChild("PerfectEvenLine"):playcommand("Set")
			rightPaneLeaderboards:GetChild("RatioSplitLine"):playcommand("Set")
			rightPaneLeaderboards:GetChild("LeftHandPercentage"):playcommand("Set")
			rightPaneLeaderboards:GetChild("RightHandPercentage"):playcommand("Set")
			rightPaneLeaderboards:GetChild("PerHandDeltaText"):playcommand("Set")
			rightPaneLeaderboards:GetChild("PerHandGraphBackdrop"):playcommand("Set")
			rightPaneLeaderboards:GetChild("PerHandYAxisTitle"):playcommand("Set")
			rightPaneLeaderboards:GetChild("PerHandXAxisTitle"):playcommand("Set")

			for i = 1, skillPredictionAxisTickCount do
				self:GetChild("PerHandHorizontalGridline" .. i):playcommand("Set")
				self:GetChild("PerHandVerticalGridline" .. i):playcommand("Set")
				self:GetChild("PerHandYAxisLabel" .. i):playcommand("Set")
				self:GetChild("PerHandXAxisLabel" .. i):playcommand("Set")
			end
			self:GetChild("PerHandCenterLine"):playcommand("Set")
			self:GetChild("PerHandCurveLine"):playcommand("Set")
		end
		if not isStatsOverlaySessionTab() then
			self:GetChild("EmptyState"):visible(false)
			for i = 1, sessionRowCount do
				self:GetChild("Row" .. i):playcommand("Update")
			end
			return
		end
		local displayDay = hoveredActivityDay or selectedDay
		local selectedDateTime = os.time({year = selectedYear, month = selectedMonth, day = displayDay, hour = 0, min = 0, sec = 0})
		local selectedKey = formatDateKey(selectedYear, selectedMonth, displayDay)
		if lastSessionDisplayKey ~= selectedKey then
			sessionScoreOffset = 0
			lastSessionDisplayKey = selectedKey
		end
		selectedScoresForDisplay = {}
		for i = 1, 512 do
			local score = SCOREMAN:GetRecentScoreForGame(i)
			if not score then break end
			if getScoreDateKey(score) == selectedKey then
				selectedScoresForDisplay[#selectedScoresForDisplay + 1] = score
			end
		end
		clampSessionScoreOffset()
		activityMonthCounts, activityMonthMaxCount, activityMonthDayCount = getSelectedMonthActivity()
		self:GetChild("Title"):settext("Session on " .. os.date("%d/%m/%Y", selectedDateTime))
		self:GetChild("MonthLabel"):settext(os.date("%B %Y", os.time({year = selectedYear, month = selectedMonth, day = 1, hour = 0, min = 0, sec = 0})))
		self:GetChild("SelectedDateLabel"):settext(os.date("%A, %d %B %Y", selectedDateTime))
		self:GetChild("SessionTime"):settext("Session time: " .. SecondsToHHMMSS(getSelectedSessionSeconds(selectedScoresForDisplay)) .. "\nCharts played: " .. #selectedScoresForDisplay .. "\nEst. rating gained: " .. formatEstimatedSessionRatingGain(selectedScoresForDisplay))
		self:GetChild("SongsPlayed"):settext("")
		self:GetChild("EmptyState"):visible(#selectedScoresForDisplay == 0)
		for i = 1, sessionRowCount do
			self:GetChild("Row" .. i):playcommand("Update")
		end
		for i = 1, activityCellCount do
			self:GetChild("Activity" .. i):playcommand("Update")
		end
	end,
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("#050505")):diffusealpha(0.98)
		end
	},
	-- Sidebar background
	Def.Quad {
		InitCommand = function(self)
			self:xy(0, 0):halign(0):valign(0):zoomto(280, SCREEN_HEIGHT):diffuse(color("#0A0A0A")):diffusealpha(1)
		end
	},
	-- Header bar background
	Def.Quad {
		InitCommand = function(self)
			self:xy(280, 0):halign(0):valign(0):zoomto(SCREEN_WIDTH - 280, 56):diffuse(color("#0E0E0E")):diffusealpha(1)
		end
	},
	-- Sidebar border
	Def.Quad {
		InitCommand = function(self)
			self:xy(280, 0):halign(1):valign(0):zoomto(1, SCREEN_HEIGHT):diffuse(color("#1A1A1A")):diffusealpha(1)
		end
	},
	LoadFont("Common Large") .. {
		Name = "Title",
		InitCommand = function(self)
			self:xy(16, 28):zoom(0.44):halign(0):valign(0.5):diffuse(getMainColor("highlight"))
		end
	},
	statsOverlayTabButton(statsOverlayTabButtons[1]),
	statsOverlayTabButton(statsOverlayTabButtons[2]),
	statsOverlayTabButton(statsOverlayTabButtons[3]),
	UIElements.TextToolTip(1, 1, "Common Large") .. {
		InitCommand = function(self)
			self:xy(overlayCloseButtonX, overlayCloseButtonY):zoom(0.42):halign(0.5):valign(0.5):settext("X"):diffuse(color("#666666"))
		end,
		MouseOverCommand = function(self)
			self:diffuse(color("#FFFFFF"))
		end,
		MouseOutCommand = function(self)
			self:diffuse(color("#666666"))
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				setStatsOverlayActive(false)
			end
		end
	},
	Def.ActorFrame {
		Name = "RightPaneSessions",
		InitCommand = function(self)
			self:visible(true)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end,
		Def.Quad {
			InitCommand = function(self)
				self:xy(sessionPanelX, sessionPanelY):halign(0):valign(0):zoomto(sessionPanelWidth, sessionPanelHeight):diffuse(color("#050505")):diffusealpha(0)
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(sessionPanelX + 16, sessionPanelY + 28):halign(0):zoom(0.5):settext("SESSION RECENT SCORES"):diffusealpha(0.8)
			end
		},
		-- Day Prev Button
		Def.ActorFrame {
			InitCommand = function(self)
				self:xy(sessionPanelX + sessionPanelWidth - 80, sessionPanelY + 28)
			end,
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(40, 40):diffusealpha(0)
				end,
				MouseDownCommand = function(self, params)
					if params.event == "DeviceButton_left mouse button" then
						shiftSelectedDay(-1)
						sessionScoreOffset = 0
						lastSessionDisplayKey = nil
						MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
					end
				end
			},
			LoadFont("Common Large") .. {
				InitCommand = function(self)
					self:zoom(0.5):settext("<"):diffusealpha(0.8)
				end
			}
		},
		-- Day Next Button
		Def.ActorFrame {
			InitCommand = function(self)
				self:xy(sessionPanelX + sessionPanelWidth - 40, sessionPanelY + 28)
			end,
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(40, 40):diffusealpha(0)
				end,
				MouseDownCommand = function(self, params)
					if params.event == "DeviceButton_left mouse button" then
						shiftSelectedDay(1)
						sessionScoreOffset = 0
						lastSessionDisplayKey = nil
						MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
					end
				end
			},
			LoadFont("Common Large") .. {
				InitCommand = function(self)
					self:zoom(0.5):settext(">"):diffusealpha(0.8)
				end
			}
		}
	},
	Def.ActorFrame {
		Name = "RightPaneOverall",
		InitCommand = function(self)
			self:visible(false)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(statsOverlayTab == statsOverlayTabs.Overall)
		end,
		Def.Quad {
			InitCommand = function(self)
				self:xy(sessionPanelX, sessionPanelY):halign(0):valign(0):zoomto(sessionPanelWidth, sessionPanelHeight):diffuse(color("#151515")):diffusealpha(0.95)
			end
		},
		overallSubviewButton(overallSubviewButtons[1]),
		overallSubviewButton(overallSubviewButtons[2]),
		overallSubviewButton(overallSubviewButtons[3]),
		overallSubviewButton(overallSubviewButtons[4]),
		LoadFont("Common Normal") .. {
			Name = "OverallOverviewHeader",
			InitCommand = function(self)
				self:xy(sessionPanelX + 12, sessionPanelY + 80):halign(0):zoom(0.2):diffuse(color("#AFAFAF"))
			end,
			SetCommand = function(self)
				self:visible(false)
				self:settext("Mode                Scores   Charts   Avg%     Best SSR")
			end,
			StatsOverlayTabChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			StatsOverlayOverallSubviewChangedMessageCommand = function(self)
				self:playcommand("Set")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "OverallOverviewEmpty",
			InitCommand = function(self)
				self:xy(sessionPanelX + 16, sessionPanelY + 116):halign(0):zoom(0.28):diffuse(color("#DDDDDD"))
			end,
			SetCommand = function(self)
				self:visible(false and #overallOverviewRowsForDisplay == 0)
				self:settext("No local score history available for overview.")
			end,
			StatsOverlayTabChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			StatsOverlayOverallSubviewChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			StatsOverlayDataChangedMessageCommand = function(self)
				self:playcommand("Set")
			end
		},
		Def.Quad {
			Name = "OverallTimelineGraphBackdrop",
			InitCommand = function(self)
				self:xy(timelineGraphLeft, timelineGraphTop):halign(0):valign(0):zoomto(timelineGraphWidth, timelineGraphHeight):diffuse(color("#101010")):diffusealpha(0.86)
			end,
			SetCommand = function(self)
				self:visible(isStatsOverlayOverallTimelineSubview() or isStatsOverlayOverallSubview(overallSubviewTabs.MsdGrade))
			end,
			StatsOverlayTabChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			StatsOverlayOverallSubviewChangedMessageCommand = function(self)
				self:playcommand("Set")
			end
		},
		Def.Quad {
			Name = "OverallTimelineHoverLine",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(1, timelineGraphHeight):diffuse(color("#FFFFFF")):diffusealpha(0.3):visible(false)
			end,
			SetCommand = function(self)
				if not isStatsOverlayOverallTimelineSubview() or not overallTimelineHoveredIndex then
					self:visible(false)
					return
				end
				self:visible(true):xy(timelineGraphLeft + fitOverallTimelineX(overallTimelineHoveredIndex), timelineGraphTop)
			end,
			StatsOverlayTabChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			StatsOverlayOverallSubviewChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			StatsOverlayDataChangedMessageCommand = function(self)
				self:playcommand("Set")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "OverallTimelineHoverDate",
			InitCommand = function(self)
				self:xy(timelineGraphLeft, timelineGraphTop + timelineGraphHeight + 40):halign(0):zoom(0.28):diffuse(color("#DDDDDD"))
			end,
			SetCommand = function(self)
				local day = overallTimelineDaysForDisplay[overallTimelineHoveredIndex or 0]
				self:visible(isStatsOverlayOverallTimelineSubview() and day ~= nil)
				self:settext(day and day.label or "")
			end,
			StatsOverlayTabChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			StatsOverlayOverallSubviewChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			StatsOverlayDataChangedMessageCommand = function(self)
				self:playcommand("Set")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "OverallTimelineEmpty",
			InitCommand = function(self)
				self:xy(sessionPanelX + 16, sessionPanelY + 116):halign(0):zoom(0.34):diffuse(color("#DDDDDD"))
			end,
			SetCommand = function(self)
				self:visible(isStatsOverlayOverallTimelineSubview() and #overallTimelineDaysForDisplay == 0)
				self:settext("No dated local score history available for timeline.")
			end,
			StatsOverlayTabChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			StatsOverlayOverallSubviewChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			StatsOverlayDataChangedMessageCommand = function(self)
				self:playcommand("Set")
			end
		}
	},
	Def.ActorFrame {
		Name = "RightPaneLeaderboards",
		InitCommand = function(self)
			self:visible(false)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(statsOverlayTab == statsOverlayTabs.Leaderboards)
		end,
		Def.Quad {
			InitCommand = function(self)
				self:xy(sessionPanelX, sessionPanelY):halign(0):valign(0):zoomto(sessionPanelWidth, sessionPanelHeight):diffuse(color("#151515")):diffusealpha(0.95)
			end
		},
		LoadFont("Common Large") .. {
			Name = "LeaderboardHeader",
			InitCommand = function(self)
				self:xy(sessionPanelX + 16, sessionPanelY + 18):halign(0):zoom(0.34):settext("Scores per judge difficulty")
			end,
			SetCommand = function(self)
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.JudgeBreakdown))
			end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
				self:playcommand("Set")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "LeaderboardStatusTitle",
			InitCommand = function(self)
				self:xy(sessionPanelX + 16, sessionPanelY + 48):halign(0):zoom(0.28):diffuse(color("#DDDDDD")):maxwidth(1500)
			end,
			SetCommand = function(self)
				self:settext(leaderboardStatus.title or "")
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.JudgeBreakdown) and (leaderboardStatus.state or "") ~= "ready")
			end,
			StatsOverlayDataChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "LeaderboardStatusDetail",
			InitCommand = function(self)
				self:xy(sessionPanelX + 16, sessionPanelY + 76):halign(0):zoom(0.24):diffuse(color("#AFAFAF")):maxwidth(1700)
			end,
			SetCommand = function(self)
				self:settext(leaderboardStatus.detail or "")
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.JudgeBreakdown) and (leaderboardStatus.state or "") ~= "ready")
			end,
			StatsOverlayDataChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end
		},
		LoadFont("Common Large") .. {
			Name = "PredictionHeader",
			InitCommand = function(self)
				self:xy(sessionPanelX + 16, sessionPanelY + 18):halign(0):zoom(0.34)
			end,
			SetCommand = function(self)
				self:settext("Skill Prediction")
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction))
			end,
			StatsOverlayDataChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end
		},
		skillPredictionModeButton(skillPredictionModeButtons[1]),
		skillPredictionModeButton(skillPredictionModeButtons[2]),
		Def.Quad {
			Name = "SkillPredictionGraphBackdrop",
			InitCommand = function(self)
				self:xy(skillPredictionGraphLeft, skillPredictionGraphTop):halign(0):valign(0):zoomto(skillPredictionGraphWidth, skillPredictionGraphHeight):diffuse(color("#101010")):diffusealpha(0.9):visible(false)
			end,
			SetCommand = function(self)
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction))
			end,
			StatsOverlayTabChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
				self:playcommand("Set")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "SkillPredictionYAxisTitle",
			InitCommand = function(self)
				self:xy(skillPredictionGraphLeft - 28, skillPredictionGraphTop - 22):halign(0):zoom(0.32):diffuse(color("#B8B8B8")):visible(false)
			end,
			SetCommand = function(self)
				if not isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction) then
					self:visible(false)
					return
				end
				self:visible(true)
				self:settext(skillPredictionMode == skillPredictionModes.AaProbability and "AA chance" or "SSR")
			end,
			StatsOverlayDataChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			StatsOverlaySkillPredictionModeChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "SkillPredictionXAxisTitle",
			InitCommand = function(self)
				self:xy(skillPredictionGraphLeft + skillPredictionGraphWidth, skillPredictionGraphTop + skillPredictionGraphHeight + 38):halign(1):zoom(0.32):diffuse(color("#B8B8B8")):settext("Chart MSD"):visible(false)
			end,
			SetCommand = function(self)
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction))
			end,
			StatsOverlayTabChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
				self:playcommand("Set")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "SkillPredictionEmpty",
			InitCommand = function(self)
				self:xy(skillPredictionGraphLeft + (skillPredictionGraphWidth / 2), skillPredictionGraphTop + (skillPredictionGraphHeight / 2)):halign(0.5):zoom(0.3):diffuse(color("#AFAFAF")):visible(false)
			end,
			SetCommand = function(self)
				local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction)
				if not active then
					self:visible(false)
					return
				end
				local empty = (skillPredictionMode == skillPredictionModes.AaProbability and #skillPredictionAaPointsForDisplay == 0)
					or (skillPredictionMode == skillPredictionModes.Ssr and #skillPredictionSsrPointsForDisplay == 0)
				self:visible(empty)
				self:settext(empty and "Not enough local data for this mode" or "")
			end,
			StatsOverlayDataChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			StatsOverlaySkillPredictionModeChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end
		},
		LoadFont("Common Large") .. {
			Name = "PerHandHeader",
			InitCommand = function(self)
				self:xy(sessionPanelX + 16, sessionPanelY + 18):halign(0):zoom(0.34)
			end,
			SetCommand = function(self)
				self:settext("Per-hand Breakdown")
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown))
			end,
			StatsOverlayDataChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
				self:queuecommand("Set")
			end
		},
		perHandModeButton(perHandModeButtons[1]),
		perHandModeButton(perHandModeButtons[2]),
		LoadFont("Common Large") .. {
			Name = "PerHandRatioTitle",
			InitCommand = function(self)
				self:xy(sessionPanelX + 32, sessionPanelY + 120):halign(0):zoom(0.4):diffuse(color("#FFFFFF"))
			end,
			SetCommand = function(self)
				local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Ratio
				self:visible(active)
				if not active then return end
				self:settext("Overall Hand Accuracy Ratio")
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		LoadFont("Common Normal") .. {
			Name = "PerHandRatioDesc",
			InitCommand = function(self)
				self:xy(sessionPanelX + 32, sessionPanelY + 144):halign(0):zoom(0.3):diffuse(color("#AFAFAF"))
			end,
			SetCommand = function(self)
				local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Ratio
				self:visible(active)
				if not active then return end
				self:settext(string.format("Calculated from the mean of Delta Scores across %d scores with replay data.", perHandValidScoreCount))
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		Def.Quad {
			Name = "RatioBarBackdrop",
			InitCommand = function(self)
				self:xy(sessionPanelX + (sessionPanelWidth / 2), sessionPanelY + 220):zoomto(424, 28):diffuse(color("#222222")):visible(false)
			end,
			SetCommand = function(self)
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Ratio)
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		Def.Quad {
			Name = "LeftHandFill",
			InitCommand = function(self)
				self:halign(0):valign(0.5):diffuse(color("#FF4B5C")):visible(false)
			end,
			SetCommand = function(self)
				local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Ratio
				self:visible(active)
				if not active then return end
				local w = (perHandOverallLeftRatio / 100) * 420
				self:xy(sessionPanelX + (sessionPanelWidth / 2) - 210, sessionPanelY + 220):zoomto(w, 24)
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		Def.Quad {
			Name = "RightHandFill",
			InitCommand = function(self)
				self:halign(1):valign(0.5):diffuse(color("#4B7CFF")):visible(false)
			end,
			SetCommand = function(self)
				local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Ratio
				self:visible(active)
				if not active then return end
				local w = (perHandOverallRightRatio / 100) * 420
				self:xy(sessionPanelX + (sessionPanelWidth / 2) + 210, sessionPanelY + 220):zoomto(w, 24)
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		Def.Quad {
			Name = "PerfectEvenLine",
			InitCommand = function(self)
				self:xy(sessionPanelX + (sessionPanelWidth / 2), sessionPanelY + 220):zoomto(2, 32):diffuse(color("#FFFFFF")):diffusealpha(0.6):visible(false)
			end,
			SetCommand = function(self)
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Ratio)
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		Def.Quad {
			Name = "RatioSplitLine",
			InitCommand = function(self)
				self:valign(0.5):zoomto(2, 28):diffuse(color("#FFFF00")):visible(false)
			end,
			SetCommand = function(self)
				local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Ratio
				self:visible(active)
				if not active then return end
				local splitX = sessionPanelX + (sessionPanelWidth / 2) - 210 + (perHandOverallLeftRatio / 100) * 420
				self:xy(splitX, sessionPanelY + 220)
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		LoadFont("Common Large") .. {
			Name = "LeftHandPercentage",
			InitCommand = function(self)
				self:xy(sessionPanelX + (sessionPanelWidth / 2) - 210, sessionPanelY + 188):halign(0):zoom(0.38):diffuse(color("#FF4B5C")):visible(false)
			end,
			SetCommand = function(self)
				local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Ratio
				self:visible(active)
				if not active then return end
				self:settextf("Left Hand: %.2f%%", perHandOverallLeftRatio)
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		LoadFont("Common Large") .. {
			Name = "RightHandPercentage",
			InitCommand = function(self)
				self:xy(sessionPanelX + (sessionPanelWidth / 2) + 210, sessionPanelY + 188):halign(1):zoom(0.38):diffuse(color("#4B7CFF")):visible(false)
			end,
			SetCommand = function(self)
				local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Ratio
				self:visible(active)
				if not active then return end
				self:settextf("Right Hand: %.2f%%", perHandOverallRightRatio)
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		LoadFont("Common Large") .. {
			Name = "PerHandDeltaText",
			InitCommand = function(self)
				self:xy(sessionPanelX + (sessionPanelWidth / 2), sessionPanelY + 264):halign(0.5):zoom(0.4):visible(false)
			end,
			SetCommand = function(self)
				local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Ratio
				self:visible(active)
				if not active then return end
				local direction = perHandOverallDelta > 0 and "Left Hand Dominant" or (perHandOverallDelta < 0 and "Right Hand Dominant" or "Perfectly Balanced")
				local sign = perHandOverallDelta > 0 and "+" or ""
				self:settextf("Δ Hand: %s%.4f%% (%s)", sign, perHandOverallDelta, direction)
				if perHandOverallDelta > 0 then
					self:diffuse(color("#FF4B5C"))
				elseif perHandOverallDelta < 0 then
					self:diffuse(color("#4B7CFF"))
				else
					self:diffuse(color("#FFFFFF"))
				end
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		Def.Quad {
			Name = "PerHandGraphBackdrop",
			InitCommand = function(self)
				self:xy(skillPredictionGraphLeft, skillPredictionGraphTop):halign(0):valign(0):zoomto(skillPredictionGraphWidth, skillPredictionGraphHeight):diffuse(color("#101010")):diffusealpha(0.9):visible(false)
			end,
			SetCommand = function(self)
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Graph)
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		LoadFont("Common Normal") .. {
			Name = "PerHandYAxisTitle",
			InitCommand = function(self)
				self:xy(skillPredictionGraphLeft - 28, skillPredictionGraphTop - 22):halign(0):zoom(0.32):diffuse(color("#B8B8B8")):visible(false)
			end,
			SetCommand = function(self)
				local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Graph
				self:visible(active)
				if not active then return end
				self:settext("Delta score accuracy bias")
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		LoadFont("Common Normal") .. {
			Name = "PerHandXAxisTitle",
			InitCommand = function(self)
				self:xy(skillPredictionGraphLeft + skillPredictionGraphWidth, skillPredictionGraphTop + skillPredictionGraphHeight + 38):halign(1):zoom(0.32):diffuse(color("#B8B8B8")):settext("Chart MSD"):visible(false)
			end,
			SetCommand = function(self)
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown) and perHandMode == perHandModes.Graph)
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayPerHandModeChangedMessageCommand = function(self) self:playcommand("Set") end
		}
	},
	Def.ActorFrame {
		Name = "LeftPaneOverall",
		InitCommand = function(self)
			self:visible(false)
		end,
		SetCommand = function(self)
			self:GetChild("OverallName"):settext(overallProfileSummary and overallProfileSummary.name or "No profile loaded")
			self:GetChild("OverallRating"):settext(string.format("%05.2f", overallProfileSummary and overallProfileSummary.rating or 0))
			self:GetChild("OverallPlayTime"):settext("Play time  " .. SecondsToHHMMSS(overallProfileSummary and overallProfileSummary.playTimeSeconds or 0))
			self:GetChild("OverallSongsPlayed"):settext("Songs played  " .. formatInteger(overallProfileSummary and overallProfileSummary.songsPlayed or 0))
			self:GetChild("OverallNotesHit"):settext("Arrows smashed  " .. formatInteger(overallProfileSummary and overallProfileSummary.notesHit or 0))
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlayOverallTab())
		end,
		LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(16, 88):halign(0):zoom(0.36):settext("PROFILE SUMMARY"):diffusealpha(0.6)
			end
		},
		LoadFont("Common Large") .. {
			Name = "OverallName",
			InitCommand = function(self)
				self:xy(16, 126):halign(0):zoom(0.42):maxwidth(640)
			end
		},
		LoadFont("Common Large") .. {
			Name = "OverallRating",
			InitCommand = function(self)
				self:xy(16, 164):halign(0):valign(0.5):zoom(0.8):diffuse(getMainColor("highlight"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "OverallPlayTime",
			InitCommand = function(self)
				self:xy(16, 210):halign(0):zoom(0.32):diffuse(color("#DDDDDD"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "OverallSongsPlayed",
			InitCommand = function(self)
				self:xy(16, 232):halign(0):zoom(0.32):diffuse(color("#DDDDDD"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "OverallNotesHit",
			InitCommand = function(self)
				self:xy(16, 254):halign(0):zoom(0.32):diffuse(color("#DDDDDD"))
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(16, SCREEN_CENTER_Y - 20):halign(0):zoom(0.448):settext("OVERVIEW MODES"):diffusealpha(0.6)
			end
		}
	},
	Def.ActorFrame {
		Name = "LeftPaneLeaderboards",
		InitCommand = function(self)
			self:visible(false)
		end,
		SetCommand = function(self)
			self:GetChild("BreakdownSelectedJudge"):settext(leaderboardStatus.title or "")
			self:GetChild("BreakdownSummary"):settext(leaderboardStatus.detail or "")
			self:GetChild("ProbabilityTitle"):settext("")
			self:GetChild("ProbabilityDetail"):settext("All values are estimate.")

			local isPH = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown)
			local isPred = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction)
			local isJudge = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.JudgeBreakdown)

			self:GetChild("JudgeSectionHeader"):visible(isJudge)
			self:GetChild("BreakdownSelectedJudge"):visible(isJudge)
			self:GetChild("BreakdownSummary"):visible(isJudge)

			self:GetChild("PredictionSectionHeader"):visible(isPred)
			self:GetChild("ProbabilityTitle"):visible(isPred)
			self:GetChild("ProbabilityDetail"):visible(isPred)

			self:GetChild("PerHandSectionHeader"):visible(isPH)
			self:GetChild("PerHandLeftRightLabel"):visible(isPH)
			self:GetChild("PerHandLeftRightSummary"):visible(isPH)

			if isPH then
				self:GetChild("PerHandLeftRightLabel"):playcommand("Set")
				self:GetChild("PerHandLeftRightSummary"):playcommand("Set")
			end
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlayLeaderboardsTab())
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			if isStatsOverlayLeaderboardsTab() then
				self:playcommand("Set")
			end
		end,
		StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
			if isStatsOverlayLeaderboardsTab() then
				self:playcommand("Set")
			end
		end,
		breakdownSubviewButton(breakdownSubviewButtons[1]),
		breakdownSubviewButton(breakdownSubviewButtons[2]),
		breakdownSubviewButton(breakdownSubviewButtons[3]),
		LoadFont("Common Large") .. {
			Name = "JudgeSectionHeader",
			InitCommand = function(self)
				self:xy(16, 192):halign(0):zoom(0.34):settext("JUDGE BREAKDOWN"):diffusealpha(0.6)
			end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.JudgeBreakdown))
			end
		},
		LoadFont("Common Large") .. {
			Name = "BreakdownSelectedJudge",
			InitCommand = function(self)
				self:xy(16, 226):halign(0):zoom(0.42):maxwidth(640)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "BreakdownSummary",
			InitCommand = function(self)
				self:xy(16, 264):halign(0):zoom(0.29):diffuse(color("#DDDDDD")):maxwidth(900)
			end
		},
		LoadFont("Common Large") .. {
			Name = "PredictionSectionHeader",
			InitCommand = function(self)
				self:xy(16, 192):halign(0):zoom(0.34):settext("SKILL PREDICTION"):diffusealpha(0.6)
			end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.SkillPrediction))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "ProbabilityTitle",
			InitCommand = function(self)
				self:xy(16, 226):halign(0):zoom(0.32):diffuse(getMainColor("highlight")):maxwidth(900)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "ProbabilityDetail",
			InitCommand = function(self)
				self:xy(16, 264):halign(0):zoom(0.26):diffuse(color("#AFAFAF")):maxwidth(900)
			end
		},
		LoadFont("Common Large") .. {
			Name = "PerHandSectionHeader",
			InitCommand = function(self)
				self:xy(16, 192):halign(0):zoom(0.34):settext("PER-HAND BREAKDOWN"):diffusealpha(0.6)
			end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self)
				self:visible(isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown))
			end
		},
		LoadFont("Common Large") .. {
			Name = "PerHandLeftRightLabel",
			InitCommand = function(self)
				self:xy(16, 226):halign(0):zoom(0.42):maxwidth(640)
			end,
			SetCommand = function(self)
				local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown)
				self:visible(active)
				if not active then return end
				self:settextf("L: %.2f%%  R: %.2f%%", perHandOverallLeftRatio, perHandOverallRightRatio)
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		LoadFont("Common Normal") .. {
			Name = "PerHandLeftRightSummary",
			InitCommand = function(self)
				self:xy(16, 264):halign(0):zoom(0.29):diffuse(color("#DDDDDD")):maxwidth(900)
			end,
			SetCommand = function(self)
				local active = isStatsOverlayBreakdownSubview(breakdownSubviewTabs.PerHandBreakdown)
				self:visible(active)
				if not active then return end
				local direction = perHandOverallDelta > 0 and "Left Hand Dominant" or (perHandOverallDelta < 0 and "Right Hand Dominant" or "Perfectly Balanced")
				local sign = perHandOverallDelta > 0 and "+" or ""
				self:settextf("Δ Hand: %s%.4f%%\n(%s)\nBased on %d scores", sign, perHandOverallDelta, direction, perHandValidScoreCount)
			end,
			StatsOverlayTabChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayBreakdownSubviewChangedMessageCommand = function(self) self:playcommand("Set") end,
			StatsOverlayDataChangedMessageCommand = function(self) self:playcommand("Set") end
		}
	},
	LoadFont("Common Large") .. {
		InitCommand = function(self)
			self:xy(16, 88):halign(0):zoom(0.36):settext("ACTIVITY HEATMAP"):diffusealpha(0.6)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Large") .. {
		Name = "PrevMonth",
		InitCommand = function(self)
			self:xy(activityPrevButtonX + 10, activityPrevButtonY + 10):halign(0.5):valign(0.5):zoom(0.3):settext("<"):diffuse(color("#FFFFFF"))
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Normal") .. {
		Name = "MonthLabel",
		InitCommand = function(self)
			self:xy(124, 198):halign(0.5):valign(0.5):zoom(0.32):diffuse(color("#FFFFFF"))
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Large") .. {
		Name = "NextMonth",
		InitCommand = function(self)
			self:xy(activityNextButtonX + 10, activityNextButtonY + 10):halign(0.5):valign(0.5):zoom(0.34):settext(">"):diffuse(color("#FFFFFF"))
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Normal") .. {
		Name = "SessionTime",
		InitCommand = function(self)
			self:xy(16, 460):halign(0):zoom(0.4)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Normal") .. {
		Name = "SongsPlayed",
		InitCommand = function(self)
			self:xy(16, 484):halign(0):zoom(0.4)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Normal") .. {
		Name = "SelectedDateLabel",
		InitCommand = function(self)
			self:xy(16, 508):halign(0):zoom(0.32):diffuse(color("#DDDDDD")):maxwidth(720)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Normal") .. {
		Name = "ActivityHint",
		InitCommand = function(self)
			self:xy(16, 532):halign(0):zoom(0.28):diffuse(color("#AFAFAF")):settext("Select a date to view that day's session")
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Normal") .. {
		Name = "EmptyState",
		InitCommand = function(self)
			self:xy(sessionPanelX + (sessionPanelWidth / 2), sessionPanelY + 150):halign(0.5):zoom(0.34):settext("No scores recorded on this date"):diffuse(color("#BBBBBB")):visible(false)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(false)
		end
	}
}

for i = 1, activityCellCount do
	local col = (i - 1) % activityColumnCount
	local row = math.floor((i - 1) / activityColumnCount)
	statsOverlay[#statsOverlay + 1] = Def.ActorFrame {
		Name = "Activity" .. i,
		InitCommand = function(self)
			self:xy(activityGridX + (col * activityCellStepX), activityGridY + (row * activityCellStepY))
		end,
		UpdateCommand = function(self)
			if not isStatsOverlaySessionTab() then
				self:visible(false)
				return
			end
			local offset = getMonthStartWeekday(selectedYear, selectedMonth) - 1
			local day = i - offset
			local active = day >= 1 and day <= activityMonthDayCount
			self:visible(active)
			if not active then return end
			local count = activityMonthCounts[day] or 0
			local fill = self:GetChild("Fill")
			local border = self:GetChild("Border")
			local dayText = self:GetChild("Day")
			if count > 0 and activityMonthMaxCount > 0 then
				local ratio = count / activityMonthMaxCount
				fill:diffuse(Brightness(getMainColor("highlight"), 0.35 + (ratio * 0.85))):diffusealpha(0.4 + (ratio * 0.6))
			else
				fill:diffuse(color("#242424")):diffusealpha(1)
			end
			if day == selectedDay then
				border:visible(true):diffuse(getMainColor("highlight")):diffusealpha(0.9)
			elseif day == hoveredActivityDay then
				border:visible(true):diffuse(getMainColor("highlight")):diffusealpha(0.55)
			else
				border:visible(false)
			end
			dayText:settext(tostring(day))
			dayText:diffuse(day == selectedDay and color("#FFFFFF") or color("#B8B8B8"))
			dayText:diffusealpha(count > 0 and 0.8 or 0.3)
		end,
		Def.Quad {
			Name = "Border",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(activityCellSize + 4, activityCellSize + 4):diffuse(getMainColor("highlight")):diffusealpha(0):visible(false)
			end
		},
		Def.Quad {
			Name = "Fill",
			InitCommand = function(self)
				self:xy(2, 2):halign(0):valign(0):zoomto(activityCellSize, activityCellSize):diffuse(color("#242424"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Day",
			InitCommand = function(self)
				self:xy(2 + (activityCellSize / 2), 2 + (activityCellSize / 2)):halign(0.5):valign(0.5):zoom(0.32):diffuse(color("#B8B8B8"))
			end
		}
	}
end

for i = 1, sessionRowCount do
	statsOverlay[#statsOverlay + 1] = sessionRow(i)
end

for i = 1, 8 do
	statsOverlay[#statsOverlay + 1] = overallSkillsetRow(i)
end

-- for i = 1, overviewRowCount do
-- 	statsOverlay[#statsOverlay + 1] = overallOverviewRow(i)
-- end

for i = 1, math.max(timelineYAxisTickCount, 11) do
	statsOverlay[#statsOverlay + 1] = overallTimelineHorizontalGridline(i)
	statsOverlay[#statsOverlay + 1] = overallTimelineYAxisLabel(i)
end

for i = 1, timelineXAxisTickCount do
	statsOverlay[#statsOverlay + 1] = overallTimelineVerticalGridline(i)
end

for i = 1, timelineXAxisTickCount do
	statsOverlay[#statsOverlay + 1] = overallTimelineXAxisLabel(i)
end

for i = 1, getOverallTimelineSkillsetCount() do
	statsOverlay[#statsOverlay + 1] = overallTimelineLine(i)
	statsOverlay[#statsOverlay + 1] = overallTimelineDot(i)
	statsOverlay[#statsOverlay + 1] = overallTimelineLegend(i)
end

statsOverlay[#statsOverlay + 1] = overallMostPlayedHeader("Charts", true)
statsOverlay[#statsOverlay + 1] = overallMostPlayedHeader("Folders", false)

for i = 1, overallBestScoreRowCount do
	statsOverlay[#statsOverlay + 1] = overallBestScoreRow(i)
end

for i = 1, 240 do
	statsOverlay[#statsOverlay + 1] = overallMsdGradePoint(i)
end

for i = 1, 12 do
	statsOverlay[#statsOverlay + 1] = overallMsdGradeLabel(i)
end

for i = 1, 5 do
	statsOverlay[#statsOverlay + 1] = overallMsdGradeXAxisLabel(i)
end

statsOverlay[#statsOverlay + 1] = overallMsdGradeTooltip()

for i = 1, 12 do
	statsOverlay[#statsOverlay + 1] = breakdownJudgeBar(i)
end

for i = 1, leaderboardRowCount do
	statsOverlay[#statsOverlay + 1] = leaderboardRow(i)
end

for i = 1, skillPredictionAxisTickCount do
	statsOverlay[#statsOverlay + 1] = skillPredictionHorizontalGridline(i)
	statsOverlay[#statsOverlay + 1] = skillPredictionVerticalGridline(i)
	statsOverlay[#statsOverlay + 1] = skillPredictionYAxisLabel(i)
	statsOverlay[#statsOverlay + 1] = skillPredictionXAxisLabel(i)
end

statsOverlay[#statsOverlay + 1] = skillPredictionCurveLine()

for i = 1, skillPredictionAxisTickCount do
	statsOverlay[#statsOverlay + 1] = perHandHorizontalGridline(i)
	statsOverlay[#statsOverlay + 1] = perHandVerticalGridline(i)
	statsOverlay[#statsOverlay + 1] = perHandYAxisLabel(i)
	statsOverlay[#statsOverlay + 1] = perHandXAxisLabel(i)
end

statsOverlay[#statsOverlay + 1] = perHandCenterLine()
statsOverlay[#statsOverlay + 1] = perHandCurveLine()

for i = 1, skillPredictionPointCount do
	statsOverlay[#statsOverlay + 1] = skillPredictionPoint(i)
end

local t = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen and screen.AddInputCallback then screen:AddInputCallback(input) end
		setStatsOverlayActive(true)
	end,
	StatsOverlayStateChangedMessageCommand = function(self, params)
		if params and params.active == false then
			SCREENMAN:SetNewScreen("ScreenSelectMusic")
		end
	end,
	EndCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen and screen.RemoveInputCallback then screen:RemoveInputCallback(input) end
		if statsOverlayActive then
			SCREENMAN:set_input_redirected(PLAYER_1, statsOverlayInputRedirect)
			statsOverlayActive = false
		end
		setenv("StatsOverlayActive", false)
	end
}

t[#t + 1] = statsOverlay

return t











