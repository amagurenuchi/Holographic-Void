--- Holographic Void: MusicWheelItem SectionExpanded NormalPart
-- Group header row: left-aligned pack name, right-aligned song count (engine).
-- Scratch re-implementation of the pack progression bar.

local wheelItemW = 280
local barH = 5 -- Thicker for better visibility

local t = Def.ActorFrame {}

-- Background
t[#t + 1] = Def.Quad {
	Name = "BgQuad",
	InitCommand = function(self)
		self:zoomto(wheelItemW, 38):diffuse(color("0.10,0.10,0.10,1"))
	end,
	GainFocusCommand = function(self)
		-- Removed focus-based highlighting to match fixed scroll
	end,
	LoseFocusCommand = function(self)
		-- Removed focus-based highlighting to match fixed scroll
	end
}

-- Left accent bar
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:x(-wheelItemW/2 + 2):zoomto(4, 34):diffuse(HVColor.Accent):diffusealpha(0.5)
	end
}

-- Multi-stop color scale helper
local function getCompletionColor(percent)
	if percent <= 0 then return {0.4, 0.4, 0.4, 1} end -- 0% Gray
	if percent >= 1 then return {1, 1, 1, 1} end     -- 100% White (Bright)

	-- Elaborative Scale: Red -> Orange -> Yellow -> Green -> Cyan -> Gold
	local stops = {
		{0.0,  {1.0, 0.3, 0.3, 1}}, -- Clear Red
		{0.20, {1.0, 0.6, 0.2, 1}}, -- Vibrant Orange
		{0.40, {1.0, 1.0, 0.2, 1}}, -- Bright Yellow
		{0.60, {0.2, 1.0, 0.2, 1}}, -- Bright Green
		{0.80, {0.2, 1.0, 1.0, 1}}, -- Clear Cyan
		{1.0,  {1.0, 0.9, 0.5, 1}}, -- Rich Gold
	}

	for i = 1, #stops - 1 do
		local s1 = stops[i]
		local s2 = stops[i+1]
		if percent >= s1[1] and percent <= s2[1] then
			local p = (percent - s1[1]) / (s2[1] - s1[1])
			return HV.LerpColor(p, s1[2], s2[2])
		end
	end
	return stops[#stops][2]
end

-- New Progression Bar Implementation
local barPadding = 30
local barW = wheelItemW - (barPadding * 2)
local gradesToTrack = {
	"Tier01", "Tier02", "Tier03", "Tier04", "Tier05", "Tier06", "Tier07", 
	"Tier08", "Tier09", "Tier10", "Tier11", "Tier12", "Tier13", "Tier14", "Tier15",
}

local function getGradeColor(tier)
	return HVColor.GetGradeColor("Grade_" .. tier)
end

local function getPackLamp(songs)
	local lowestLevel, lowestType = 0, nil
	local stepsType = GAMESTATE:GetCurrentStyle():GetStepsType()
	for _, song in ipairs(songs) do
		local songLevel, songType
		for _, steps in ipairs(song:GetStepsByStepsType(stepsType)) do
			local scoreList = SCOREMAN:GetScoresByKey(steps:GetChartKey())
			if scoreList then
				for _, rateScores in pairs(scoreList) do
					for _, score in ipairs(rateScores:GetScores() or {}) do
						local ct = getClearType(PLAYER_1, steps, score)
						local level = getClearTypeLevel(ct)
						if level < 19 and (not songLevel or level < songLevel) then songLevel, songType = level, ct end
					end
				end
			end
		end
		if not songLevel then return nil end
		if songLevel > lowestLevel then lowestLevel, lowestType = songLevel, songType end
	end
	local key = tostring(lowestType or "")
	return key:find("^ClearType_") and key or "ClearType_" .. key
end

local progressionBar = Def.ActorFrame {
	Name = "ProgressionBar",
	InitCommand = function(self)
		self:y(14):draworder(150):ztest(false)
	end,
	SetCommand = function(self, params) self:playcommand("UpdateData", params) end,
	SetMessageCommand = function(self, params) self:playcommand("UpdateData", params) end,
	UpdateDataCommand = function(self, params)
		local normalPart = self:GetParent()
		local mwi = normalPart:GetParent()
		if not mwi then return end

		-- DEFENSIVE SECTION DETECTION
		local sectionName = params and (params.GroupName or params.Text)
		if not sectionName or sectionName == "" then
			if mwi.GetSectionName then sectionName = mwi:GetSectionName() end
		end
		if not sectionName or sectionName == "" then
			local sa = mwi:GetChild("SectionExpanded") or mwi:GetChild("SectionCollapsed")
			if sa and sa.GetText then sectionName = sa:GetText() end
		end

		local songs = sectionName and sectionName ~= "" and SONGMAN:GetSongsInGroup(sectionName) or {}
		local totalSongs = #songs
		local gradeCounts = {}
		for _, g in ipairs(gradesToTrack) do gradeCounts[g] = 0 end
		local totalCleared = 0

		if totalSongs > 0 then
			for _, song in ipairs(songs) do
				local bestGrade = song:GetHighestGrade()
				if bestGrade and bestGrade ~= "Grade_None" and bestGrade ~= "Grade_Failed" then
					totalCleared = totalCleared + 1
					local tier = tostring(bestGrade):match("Tier%d+")
					if tier and gradeCounts[tier] then
						gradeCounts[tier] = gradeCounts[tier] + 1
					end
				end
			end
		end

		local percent = totalSongs > 0 and (totalCleared / totalSongs) or 0
		
		-- Update Segments
		local currentX = -barW/2
		for _, tier in ipairs(gradesToTrack) do
			local count = gradeCounts[tier] or 0
			local quad = self:GetChild("Bar_" .. tier)
			if quad then
				local segmentW = (count / math.max(1, totalSongs)) * barW
				quad:stoptweening():halign(0):x(currentX):zoomto(segmentW, barH):diffusealpha(1)
				currentX = currentX + segmentW
			end
		end

		-- Background part (Remaining)
		local bg = self:GetChild("BarBG")
		if bg then
			local remainingW = barW - (currentX + barW/2)
			bg:stoptweening():halign(0):x(currentX):zoomto(math.max(0, remainingW), barH):diffusealpha(0.4)
		end

		self.hv_stats = { cleared = totalCleared, total = totalSongs, percent = percent,
			lamp = percent >= 1 and getPackLamp(songs) or nil }
	end
}

for _, tier in ipairs(gradesToTrack) do
	progressionBar[#progressionBar + 1] = Def.Quad {
		Name = "Bar_" .. tier,
		InitCommand = function(self)
			self:valign(1):diffuse(getGradeColor(tier))
		end
	}
end

progressionBar[#progressionBar + 1] = Def.Quad {
	Name = "BarBG",
	InitCommand = function(self)
		self:valign(1):diffuse(color("0.3,0.3,0.3,1"))
	end
}

t[#t + 1] = progressionBar

t[#t + 1] = Def.ActorFrame {
	Name = "PackLamp",
	InitCommand = function(self) self:x(wheelItemW / 2 - 10):y(16):halign(1):draworder(151) end,
	SetMessageCommand = function(self)
		local stats = self:GetParent():GetChild("ProgressionBar").hv_stats
		local label = self:GetChild("Text")
		if stats and stats.lamp then
			label:settext(getClearTypeText(stats.lamp)):diffuse(getClearTypeColor(stats.lamp)):visible(true)
		else
			label:visible(false)
		end
	end,
	LoadFont("Common Normal") .. { Name = "Text", InitCommand = function(self) self:zoom(0.32) end }
}

-- Engine text color and title alignment override
t[#t + 1] = Def.Actor {
	SetMessageCommand = function(self)
		local normalPart = self:GetParent()
		local mwi = normalPart:GetParent()
		if not mwi then return end

		-- Title alignment override (Standardize to left-aligned)
		local titles = {"SectionExpanded", "SectionCollapsed"}
		for _, name in ipairs(titles) do
			local a = mwi:GetChild(name)
			if a and a:GetVisible() then
				a:diffuse(HVColor.Accent):halign(0):x(-wheelItemW/2 + 12):y(0)
			end
		end
		
		-- Dynamic SectionCount coloring
		local countActor = mwi:GetChild("SectionCount")
		if countActor then
			local bar = normalPart:GetChild("ProgressionBar")
			if bar and bar.hv_stats then
				local stats = bar.hv_stats
				local c = getCompletionColor(stats.percent or 0)
				countActor:diffuse(c[1], c[2], c[3], c[4])
			else
				countActor:diffuse(color("0.5,0.5,0.5,1"))
			end
		end
	end,
	ColorThemeChangedMessageCommand = function(self) self:playcommand("Set") end
}

return t
