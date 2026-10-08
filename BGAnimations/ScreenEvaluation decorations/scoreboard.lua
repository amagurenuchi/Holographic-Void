--- Holographic Void: Local Scoreboard (ported from spawncamping-wallhack)
-- Displays paginated local high-scores for the chart at the current rate.
-- Features: SSR, Judgment tally (no labels), ClearType lamp, sort by SSR.
-- NEW: Clickable score cards to view different score data

local lines = 4
local pn = GAMESTATE:GetEnabledPlayers()[1]
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
local steps = GAMESTATE:GetCurrentSteps()
local score = pss:GetHighScore()
local hsTable = {}
local targetRate = getCurRate()
local ck = (steps and steps.GetChartKey) and steps:GetChartKey() or ""
local scoresByKey = (ck ~= "") and SCOREMAN:GetScoresByKey(ck) or nil
if scoresByKey then
	-- Manual filter to ensure only target rate scores are included
	for rateStr, rateScores in pairs(scoresByKey) do
		if rateStr == targetRate then
			local scores = rateScores:GetScores()
			for j = 1, #scores do
				hsTable[#hsTable + 1] = scores[j]
			end
		end
	end
end
-- Fallback in case manual scan failed or was empty
if #hsTable == 0 then
	hsTable = getScoreTable(pn, targetRate) or {}
end

-- Currently selected score index (for viewing)
local selectedScoreIndex = 0

local scoreIndex = 0
if #hsTable > 0 then
	local ok, idx = pcall(function() return getHighScoreIndex(hsTable, score) end)
	if ok and idx then scoreIndex = idx end
end

-- Sort by J4 Normalized% (descending)
table.sort(hsTable, function(a, b)
	local wa = getJ4NormalizedPercentage(a)
	local wb = getJ4NormalizedPercentage(b)
	if math.abs(wa - wb) > 0.000001 then return wa > wb end
	return (a:GetSkillsetSSR("Overall") or 0) > (b:GetSkillsetSSR("Overall") or 0)
end)

-- Re-find scoreIndex after sort
for i, s in ipairs(hsTable) do
	if s == score then
		scoreIndex = i
		break
	end
end

-- The table is sorted above, so initialize the selection only after the
-- final row indices are known.  Otherwise the selected row can point at a
-- different score than the one shown by the evaluation panel.
selectedScoreIndex = scoreIndex

local curPage = scoreIndex > 0 and math.ceil(scoreIndex / lines) or 1
local maxPages = math.max(1, math.ceil(#hsTable / lines))

local function movePage(n)
	if maxPages <= 1 then return end
	if n > 0 then
		curPage = ((curPage + n - 1) % maxPages) + 1
	else
		curPage = ((curPage + n + maxPages - 1) % maxPages) + 1
	end
	MESSAGEMAN:Broadcast("UpdateLocalScoreboard")
end

-- Function to select a score when clicked
local function selectScore(idx)
	if not hsTable[idx] then return end
	selectedScoreIndex = idx
	-- Set the score for viewing in the main eval screen
	if hsTable[idx] then
		HV.SelectedEvaluationScore = hsTable[idx]
		if HV.SelectEvaluationScore then HV.SelectEvaluationScore(hsTable[idx]) end
		MESSAGEMAN:Broadcast("ScoreChanged")
		MESSAGEMAN:Broadcast("UpdateLocalScoreboard")
	end
end

-- HV Color palette
local accentColor = HVColor.Accent
local brightText = color("1,1,1,1")
local dimText = brightText
local subText = brightText
local mainText = brightText
local bgCard = color("0.06,0.06,0.06,0.7")
local selectedHighlight = color("#00CFFF")

-- Judgment colors (same as main eval for tally coloring)
local judgmentColors = {
	color("#FFFFFF"), color("#E0E0A0"), color("#A0E0A0"),
	color("#A0C8E0"), color("#C8A0E0"), color("#E0A0A0")
}

local function scoreItem(i)
	local rowIdx = 0
	return Def.ActorFrame {
		Name = "LocalRow" .. i,
		InitCommand = function(self) self:y((i - 1) * 46) end,
		OnCommand = function(self) self:playcommand("UpdateRow") end,
		UpdateLocalScoreboardMessageCommand = function(self) self:playcommand("UpdateRow") end,
		UpdateRowCommand = function(self)
			local idx = (curPage - 1) * lines + i
			rowIdx = idx
			if hsTable[idx] then
				self:visible(true)
				self:RunCommandsOnChildren(function(child) child:playcommand("SetScore", {index = idx}) end)
			else
				self:visible(false)
			end
		end,

		-- Click handling row (invisible overlay)
		Def.Quad {
			Name = "ClickArea",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(300, 42):diffusealpha(0)
			end,
			MouseLeftClickMessageCommand = function(self, params)
				if self:IsOver() and rowIdx > 0 then
					selectScore(rowIdx)
				end
			end,
			MouseOverCommand = function(self)
				if rowIdx > 0 and rowIdx ~= selectedScoreIndex then
					self:GetParent():GetChild("RowBG"):diffuse(color("0.1,0.1,0.1,0.6"))
				end
			end,
			MouseOutCommand = function(self)
				if rowIdx > 0 then
					local bg = self:GetParent():GetChild("RowBG")
					if rowIdx == selectedScoreIndex then
						bg:diffuse(selectedHighlight):diffusealpha(0.15)
					elseif rowIdx == scoreIndex then
						bg:diffuse(accentColor):diffusealpha(0.1)
					else
						bg:diffuse(color("0,0,0,0.4"))
					end
				end
			end
		},

		-- Row BG
		Def.Quad {
			Name = "RowBG",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(300, 42):diffuse(color("0,0,0,0.4"))
			end,
			SetScoreCommand = function(self, params)
				if params.index == selectedScoreIndex then
					-- Highlight for selected score
					self:diffuse(selectedHighlight):diffusealpha(0.15)
				elseif params.index == scoreIndex then
					-- Original play score highlight
					self:diffuse(accentColor):diffusealpha(0.1)
				else
					self:diffuse(color("0,0,0,0.4"))
				end
			end,
			WheelUpSlowMessageCommand = function(self) if self:IsOver() then movePage(-1) end end,
			WheelDownSlowMessageCommand = function(self) if self:IsOver() then movePage(1) end end
		},

		-- Selection indicator (left border)
		Def.Quad {
			Name = "SelectionIndicator",
			InitCommand = function(self) self:halign(0):valign(0):zoomto(3, 42):diffusealpha(0) end,
			SetScoreCommand = function(self, params)
				if params.index == selectedScoreIndex then
					self:diffuse(selectedHighlight):diffusealpha(1)
				else
					self:diffusealpha(0)
				end
			end
		},

		-- ClearType lamp
		Def.Quad {
			InitCommand = function(self) self:halign(0):valign(0):zoomto(4, 42) end,
			SetScoreCommand = function(self, params)
				local ct = getClearType(pn, steps, hsTable[params.index])
				self:diffuse(getClearTypeColor(ct))
			end
		},

		-- Rank #
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(-10, 12):zoom(0.28):diffuse(dimText) end,
			SetScoreCommand = function(self, params)
				self:settext(params.index)
				if params.index == scoreIndex then
					self:diffuse(accentColor)
				else
					self:diffuse(dimText)
				end
			end
		},

		-- Grade
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(16, 8):zoom(0.45):halign(0) end,
			SetScoreCommand = function(self, params)
				local grade = hsTable[params.index]:GetWifeGrade()
				self:settext(HV.GetGradeName(ToEnumShortString(grade)))
				self:diffuse(HVColor.GetGradeColor(ToEnumShortString(grade)))
			end
		},

		-- Score %
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(60, 8):zoom(0.45):halign(0):diffuse(mainText) end,
			SetScoreCommand = function(self, params)
				local ws = hsTable[params.index]:GetWifeScore()
				if ws >= 0.99 then
					self:settextf("%.4f%%", math.floor(ws * 1000000) / 10000)
				else
					self:settextf("%.2f%%", math.floor(ws * 10000) / 100)
				end
			end
		},

		-- SSR
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(290, 8):zoom(0.45):halign(1) end,
			SetScoreCommand = function(self, params)
				if not HV.ShowMSD() then
					self:settext("")
					return
				end
				local ssr = hsTable[params.index]:GetSkillsetSSR("Overall")
				if ssr > 0 then
					self:settextf("%.2f", ssr)
					self:diffuse(HVColor.GetMSDRatingColor(ssr))
				else
					self:settext(""):diffuse(dimText)
				end
			end
		},

		-- Judgment tally (colored, no labels)
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(16, 24):zoom(0.25):halign(0) end,
			SetScoreCommand = function(self, params)
				local s = hsTable[params.index]
				local counts = {
					s:GetTapNoteScore("TapNoteScore_W1"),
					s:GetTapNoteScore("TapNoteScore_W2"),
					s:GetTapNoteScore("TapNoteScore_W3"),
					s:GetTapNoteScore("TapNoteScore_W4"),
					s:GetTapNoteScore("TapNoteScore_W5"),
					s:GetTapNoteScore("TapNoteScore_Miss")
				}
				self:settextf("%d / %d / %d / %d / %d / %d",
					counts[1], counts[2], counts[3], counts[4], counts[5], counts[6])
				self:diffuse(subText)
			end
		},

		-- Date
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(290, 24):zoom(0.3):halign(1):diffuse(dimText) end,
			SetScoreCommand = function(self, params)
				self:settext(hsTable[params.index]:GetDate())
			end
		},

		-- CC Indicator
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(150, 35):zoom(0.24):halign(0):diffuse(color("#FF0000")):settext("CC ON"):visible(false) end,
			SetScoreCommand = function(self, params)
				local s = hsTable[params.index]
				if s and s:GetChordCohesion() then
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- Replay dot
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(290, 35):zoom(0.15):halign(1):diffuse(color("#7AFFAF"))
				self:settext("●"):visible(false)
			end,
			SetScoreCommand = function(self, params)
				self:visible(hsTable[params.index]:HasReplayData())
			end
		},
	}
end

local t = Def.ActorFrame {
	Name = "LocalScoreboard",
	OnCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type == "InputEventType_FirstPress" then
				if event.button == "MenuLeft" then movePage(-1)
				elseif event.button == "MenuRight" then movePage(1) end
			end
		end)
	end,

	-- Header
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(0, -18):zoom(0.35):halign(0):diffuse(accentColor) end,
		OnCommand = function(self)
			local label = HV.ShowMSD() and "Local Scores (sorted by SSR)" or "Local Scores"
			self:settextf("%s - %d total", label, #hsTable)
		end,
		UpdateLocalScoreboardMessageCommand = function(self)
			-- Show indicator if viewing a different score
			if selectedScoreIndex > 0 and selectedScoreIndex ~= scoreIndex then
				self:settextf("Viewing Score #%d (Click current play to return)", selectedScoreIndex)
			else
				local label = HV.ShowMSD() and "Local Scores (sorted by SSR)" or "Local Scores"
				self:settextf("%s - %d total", label, #hsTable)
			end
		end
	},

	-- Page info
	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self) self:xy(150, lines * 46 + 8):zoom(0.28):diffuse(dimText) end,
		OnCommand = function(self) self:playcommand("UpdateText") end,
		UpdateLocalScoreboardMessageCommand = function(self) self:playcommand("UpdateText") end,
		UpdateTextCommand = function(self)
			if #hsTable > 0 then
				self:settextf("Page %d/%d", curPage, maxPages)
			else
				self:settext("No scores")
			end
		end
	},
}

for i = 1, lines do
	t[#t + 1] = scoreItem(i)
end

return t
