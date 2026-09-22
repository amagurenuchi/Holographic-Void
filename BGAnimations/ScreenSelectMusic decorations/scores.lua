--- Holographic Void: Scores Tab
-- Shows local score history and online leaderboard for the current chart
-- Online: DLMAN:GetChartLeaderBoard(ck) / RequestChartLeaderBoardFromOnline(ck, cb)

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local bgCard = color("0.04,0.04,0.04,0.97")

local overlayW = 680
local overlayH = 400
local rowH = 34
local pageSize = 8
local rowsStartY = -overlayH/2 + 82
local currentPage = 1
local scoresActor = nil
local whee = nil

-- View modes
local VIEW_LOCAL = 1
local VIEW_ONLINE = 2
local currentView = VIEW_LOCAL

-- Sort modes
local SORT_SSR = 1
local SORT_WIFE = 2
local currentSort = SORT_SSR

-- Data
local localScores = {}
local onlineScores = {}
local displayedScores = {}
local onlineLoading = false
local onlineRequestToken = 0
local filterCurrentRate = true
local displayAsJ4 = PREFSMAN:GetPreference("SortBySSRNormPercent")
local hoveredCommentScore = nil

local function GetScoreDisplayName(score)
	if not score then return nil end
	local fallback
	local placeholders = {
		["Player 1"] = true, ["Player 2"] = true, ["Replay"] = true,
		["Unknown"] = true, ["???"] = true, [""] = true
	}
	for _, getterName in ipairs({"GetDisplayName", "GetName"}) do
		local getter = score[getterName]
		if type(getter) == "function" then
			local ok, name = pcall(getter, score)
			if ok and name then
				name = tostring(name)
				if not placeholders[name] then return name end
				fallback = fallback or name
			end
		end
	end
	return nil
end

-- ============================================================
-- DATA HELPERS
-- ============================================================

local function GetSSR(s)
	if not s then return 0 end
	if s.GetSkillsetSSR then return s:GetSkillsetSSR("Overall") end
	if s.GetSkillsetSum then return s:GetSkillsetSum() end
	if s.GetSkillSetSum then return s:GetSkillSetSum() end
	return 0
end

local function SortScores(scoreTable)
	if not scoreTable or #scoreTable == 0 then return end
	
	table.sort(scoreTable, function(a, b)
		-- Handle different score structures (local vs online)
		local sA = a.score or a
		local sB = b.score or b
		
		if currentSort == SORT_SSR then
			local ssrA = GetSSR(sA)
			local ssrB = GetSSR(sB)
			if math.abs(ssrA - ssrB) > 0.0001 then return ssrA > ssrB end
			return sA:GetWifeScore() > sB:GetWifeScore()
		else
			-- Wife% sort
			local wA = displayAsJ4 and getJ4NormalizedPercentage(sA) or sA:GetWifeScore() * 100
			local wB = displayAsJ4 and getJ4NormalizedPercentage(sB) or sB:GetWifeScore() * 100
			if math.abs(wA - wB) > 0.000001 then return wA > wB end
			-- Fallback to SSR
			return GetSSR(sA) > GetSSR(sB)
		end
	end)
end

-- ============================================================
-- DATA FETCHING
-- ============================================================

local function GetLocalScores()
	localScores = {}
	local steps = GAMESTATE:GetCurrentSteps()
	if not steps then return end
	local ck = steps:GetChartKey()
	if not ck then return end
	local sl = SCOREMAN:GetScoresByKey(ck)
	if not sl then return end

	local currentRate = getCurRateValue()

	for rateName, scoreList in pairs(sl) do
		local rNum = tonumber((rateName:gsub("x", ""))) or 0
		-- Apply rate filter if enabled (tolerate small floating point differences)
		if not filterCurrentRate or math.abs(rNum - currentRate) < 0.001 then
			local scores = scoreList:GetScores()
			if scores then
				for _, s in ipairs(scores) do
					localScores[#localScores + 1] = {score = s, rate = rateName}
				end
			end
		end
	end

	-- Sort using helper
	SortScores(localScores)
end

local function FetchOnlineScores()
	onlineRequestToken = onlineRequestToken + 1
	local requestToken = onlineRequestToken
	onlineScores = {}
	onlineLoading = true

	local steps = GAMESTATE:GetCurrentSteps()
	if not steps then
		onlineLoading = false
		return
	end

	local ck = steps:GetChartKey()
	if not ck then
		onlineLoading = false
		return
	end

	if not DLMAN:IsLoggedIn() then
		onlineLoading = false
		return
	end

	-- Try cached first
	local cached = DLMAN:GetChartLeaderBoard(ck)
	if cached and #cached > 0 then
		onlineScores = cached
		onlineLoading = false
		if scoresActor then scoresActor:playcommand("RefreshScores") end
		return
	end

	-- Request from server
	DLMAN:RequestChartLeaderBoardFromOnline(
		ck,
		function(leaderboard)
			if requestToken ~= onlineRequestToken then return end
			if type(leaderboard) == "table" then
				onlineScores = leaderboard
				-- Sort using helper
				SortScores(onlineScores)
			else
				onlineScores = {}
			end
			onlineLoading = false
			local actor = scoresActor
			if actor then
				local ok = pcall(function() actor:queuecommand("RefreshScores") end)
				if not ok then scoresActor = nil end
			end
		end
	)
end

local function ViewScore(score)
	if not score then return end
	local ss = score.score or score
	HV.OnlineEvaluationActive = (currentView == VIEW_ONLINE)
	HV.OnlineEvaluationName = HV.OnlineEvaluationActive and GetScoreDisplayName(ss) or nil
	local screen = SCREENMAN:GetTopScreen()
	-- ShowEvalScreenForScore is a standard Etterna ScreenSelectMusic method for viewing historical scores
	if screen and screen.ShowEvalScreenForScore then
		screen:ShowEvalScreenForScore(ss)
	else
		-- Fallback if engine method behaves unexpectedly
		if STATSMAN:GetCurStageStats() then
			STATSMAN:GetCurStageStats():GetPlayerStageStats():SetHighScore(ss)
			SCREENMAN:SetNewScreen("ScreenEvaluation")
		end
	end
end

-- ============================================================
-- UI
-- ============================================================

local t = Def.ActorFrame {
	Name = "ScoresOverlay",
	InitCommand = function(self)
		scoresActor = self
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false):diffusealpha(0)
	end,
	OffCommand = function(self)
		if scoresActor == self then scoresActor = nil end
	end,
	OnCommand = function(self)
		self:SetUpdateFunction(function(actor)
			if not actor:GetVisible() then
				local tooltip = actor:GetChild("ScoreCommentTooltip")
				if tooltip then tooltip:visible(false) end
				return
			end
			local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
			local found = nil
			for ri = 1, pageSize do
				local ry = SCREEN_CENTER_Y + rowsStartY + (ri - 1) * rowH + rowH / 2
				if mx >= SCREEN_CENTER_X - overlayW / 2 + 25 and mx <= SCREEN_CENTER_X + overlayW / 2 - 25
					and my >= ry - rowH / 2 and my <= ry + rowH / 2 then
					local entry = displayedScores[(currentPage - 1) * pageSize + ri]
					found = entry and (entry.score or entry) or nil
					break
				end
			end
			local tooltip = actor:GetChild("ScoreCommentTooltip")
			local comment = found and HV.GetScoreComment(found) or ""
			hoveredCommentScore = found
			if tooltip then
				local hasComment = comment ~= ""
				tooltip:visible(hasComment)
				if hasComment then
					local text = tooltip:GetChild("Text")
					local bg = tooltip:GetChild("Bg")
					local wrappedComment = HV.WrapScoreComment(comment, 58)
					text:settext(wrappedComment)
					local textWidth = #comment * 0.32 * 8
					if text.GetWidth then
						local measuredWidth = text:GetWidth() * 0.32
						if measuredWidth > 0 then textWidth = measuredWidth end
					end
					local lineCount = 1
					for _ in wrappedComment:gmatch("\n") do lineCount = lineCount + 1 end
					local tooltipWidth = math.max(140, math.min(520, textWidth + 24))
					bg:zoomto(tooltipWidth, math.max(42, lineCount * 16 + 16))
					-- Keep the tooltip attached to the cursor, even while the
					-- cursor moves within the same score row.
					tooltip:xy(mx - SCREEN_CENTER_X + 16, my - SCREEN_CENTER_Y + 16)
				end
			end
		end)
	end,
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen and screen.GetMusicWheel then whee = screen:GetMusicWheel() end
	end,
	SelectMusicTabChangedMessageCommand = function(self, params)
		if params.Tab == "SCORES" then
			self:visible(not self:GetVisible())
			if self:GetVisible() then
				self:stoptweening():diffusealpha(0):linear(0.2):diffusealpha(1)
				HV.ActiveTab = "SCORES"
				currentPage = 1
				currentView = VIEW_LOCAL
				GetLocalScores()
				self:playcommand("RefreshScores")
			else
				HV.ActiveTab = ""
			end
		else
			self:visible(false)
			onlineRequestToken = onlineRequestToken + 1
			if HV.ActiveTab == "SCORES" then HV.ActiveTab = "" end
		end
	end,
	TabNavigationMessageCommand = function(self, params)
		if self:GetVisible() and params and params.dir then
			local totalPages = math.max(1, math.ceil(#displayedScores / pageSize))
			currentPage = math.max(1, math.min(totalPages, currentPage + params.dir))
			self:playcommand("RefreshScores")
		end
	end,
	CurrentStepsChangedMessageCommand = function(self)
		if self:GetVisible() then
			currentPage = 1
			if currentView == VIEW_LOCAL then
				GetLocalScores()
			else
				FetchOnlineScores()
			end
			self:playcommand("RefreshScores")
		end
	end,

	-- Background
	Def.Quad { InitCommand = function(self) self:zoomto(overlayW, overlayH):diffuse(bgCard) end },
	Def.Quad { InitCommand = function(self) self:valign(0):y(-overlayH/2):zoomto(overlayW, 2):diffuse(accentColor):diffusealpha(0.7) end },

	-- Title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 25, -overlayH/2 + 15):zoom(0.5):diffuse(accentColor)
		end,
		RefreshScoresCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			local steps = GAMESTATE:GetCurrentSteps()
			local viewLabel = currentView == VIEW_LOCAL and THEME:GetString("Scores", "Local") or THEME:GetString("Scores", "Online")
			if song and steps then
				local diff = ToEnumShortString(steps:GetDifficulty())
				self:settextf(THEME:GetString("Scores", "TitleGeneric"), viewLabel, song:GetDisplayMainTitle(), diff)
			else
				self:settextf(THEME:GetString("Scores", "TitleGenericNoChart"), viewLabel)
			end
		end
	},

	-- View toggle button (Merged LOCAL/ONLINE)
	Def.ActorFrame {
		InitCommand = function(self) self:xy(overlayW/2 - 55, -overlayH/2 + 18) end,
		Def.Quad {
			Name = "ToggleViewBg",
			InitCommand = function(self) self:zoomto(100, 18):diffuse(accentColor):diffusealpha(0.4) end,
			RefreshScoresCommand = function(self)
				if not DLMAN:IsLoggedIn() and currentView == VIEW_LOCAL then
					self:diffuse(color("#444444"))
				else
					self:diffuse(accentColor)
				end
			end,
		},
		LoadFont("Common Normal") .. {
			Name = "ToggleViewText",
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText) end,
			RefreshScoresCommand = function(self)
				local viewName = currentView == VIEW_LOCAL and THEME:GetString("Scores", "Local") or THEME:GetString("Scores", "Online")
				self:settextf(THEME:GetString("Scores", "ViewToggle"), viewName)
				if currentView == VIEW_ONLINE and not DLMAN:IsLoggedIn() then
					self:diffuse(dimText)
				else
					self:diffuse(brightText)
				end
			end,
		},
	},

	-- Rate filter toggle button
	Def.ActorFrame {
		InitCommand = function(self) self:xy(overlayW/2 - 145, -overlayH/2 + 18) end,
		Def.Quad {
			Name = "RateBtnBg",
			InitCommand = function(self) self:zoomto(65, 18):diffuse(accentColor):diffusealpha(0.15) end,
			RefreshScoresCommand = function(self)
				self:diffusealpha(filterCurrentRate and 0.5 or 0.15)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText) end,
			RefreshScoresCommand = function(self)
				self:settext(filterCurrentRate and THEME:GetString("Scores", "FilterCurrRate") or THEME:GetString("Scores", "FilterAllRates"))
				self:diffusealpha(filterCurrentRate and 1 or 0.5)
			end,
		},
	},

	-- Sort toggle button
	Def.ActorFrame {
		InitCommand = function(self) self:xy(overlayW/2 - 215, -overlayH/2 + 18) end,
		Def.Quad {
			Name = "SortBtnBg",
			InitCommand = function(self) self:zoomto(65, 18):diffuse(accentColor):diffusealpha(0.15) end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText) end,
			RefreshScoresCommand = function(self)
				self:settext(currentSort == SORT_SSR and THEME:GetString("Scores", "SortSSR") or THEME:GetString("Scores", "SortWife"))
				local bg = self:GetParent():GetChild("SortBtnBg")
				if bg then bg:diffusealpha(0.5) end
			end,
		},
	},

	-- J4 Display Toggle Button
	Def.ActorFrame {
		Name = "J4ToggleFrame",
		InitCommand = function(self) self:xy(overlayW/2 - 285, -overlayH/2 + 18) end,
		RefreshScoresCommand = function(self)
			local normPref = PREFSMAN:GetPreference("SortBySSRNormPercent")
			self:visible(not normPref)
		end,
		Def.Quad {
			Name = "J4BtnBg",
			InitCommand = function(self) self:zoomto(65, 18):diffuse(accentColor):diffusealpha(0.15) end,
			RefreshScoresCommand = function(self)
				self:diffusealpha(displayAsJ4 and 0.5 or 0.15)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText) end,
			RefreshScoresCommand = function(self)
				self:settext(displayAsJ4 and "Display: J4" or "Display: Raw")
				self:diffusealpha(displayAsJ4 and 1 or 0.5)
			end,
		},
	},

	-- Page info
	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self)
			self:halign(1):valign(0):xy(overlayW/2 - 16, -overlayH/2 + 30):zoom(0.24):diffuse(dimText)
		end,
	},

	-- Column headers
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-overlayW/2 + 25, -overlayH/2 + 65) end,
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):zoom(0.32):diffuse(dimText):settext("#") end },
		LoadFont("Common Normal") .. { Name = "HdrName", InitCommand = function(self) self:halign(0):x(30):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "PlayerColumn")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(190):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "WifeColumn")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(280):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "SSRColumn")):visible(HV.ShowMSD()) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(345):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "GradeColumn")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(415):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "RateColumn")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(485):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "ClearColumn")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(1):x(overlayW - 50):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "DateColumn")) end },
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 12, -overlayH/2 + 82)
				:zoomto(overlayW - 24, 1):diffuse(color("0.12,0.12,0.12,1"))
		end,
	},

	-- Loading indicator
	LoadFont("Common Normal") .. {
		Name = "LoadingText",
		InitCommand = function(self)
			self:xy(0, 0):zoom(0.35):diffuse(accentColor):settext(THEME:GetString("Common", "Loading")):visible(false)
		end,
		RefreshScoresCommand = function(self)
			self:visible(onlineLoading and currentView == VIEW_ONLINE)
		end,
	},

	-- Empty state message
	LoadFont("Common Normal") .. {
		Name = "EmptyState",
		InitCommand = function(self)
			self:xy(0, 0):zoom(0.35):diffuse(dimText):visible(false)
		end,
		RefreshScoresCommand = function(self)
			if #displayedScores == 0 and not (onlineLoading and currentView == VIEW_ONLINE) then
				self:visible(true)
				if currentView == VIEW_LOCAL then
					self:settext(THEME:GetString("Scores", "NoScoresLocal"))
				else
					self:settext(THEME:GetString("Scores", "NoScoresOnline"))
				end
			else
				self:visible(false)
			end
		end,
	},

	-- Hint
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0.5):valign(1):xy(0, overlayH/2 - 8):zoom(0.20):diffuse(dimText)
				:settext(THEME:GetString("Scores", "ScoreHint"))
		end,
	},
	Def.ActorFrame {
		Name = "ScoreCommentTooltip",
		InitCommand = function(self) self:visible(false):z(20) end,
		Def.Quad { Name = "Bg", InitCommand = function(self) self:halign(0):valign(0):zoomto(140, 70):diffuse(color("0.01,0.01,0.01,0.90")) end },
		LoadFont("Common Normal") .. { Name = "Text", InitCommand = function(self) self:halign(0):valign(0):xy(10, 8):zoom(0.32):diffuse(brightText) end }
	},
}

-- Score rows
for i = 1, pageSize do
	t[#t + 1] = Def.ActorFrame {
		Name = "ScoreRow_" .. i,
		InitCommand = function(self)
			self:xy(-overlayW/2 + 25, rowsStartY + (i-1) * rowH):diffusealpha(0)
		end,

		Def.Quad { Name = "Bg", InitCommand = function(self) self:halign(0):valign(0):zoomto(overlayW - 50, rowH - 4):diffuse(color("0,0,0,0.2")) end },
		LoadFont("Common Normal") .. { Name = "Rank", InitCommand = function(self) self:halign(0):valign(0.5):y(rowH/2):zoom(0.35):diffuse(dimText) end },
		LoadFont("Common Normal") .. { Name = "Player", InitCommand = function(self) self:halign(0):valign(0.5):x(30):y(rowH/2):zoom(0.42):diffuse(mainText):maxwidth(150 / 0.42) end },
		LoadFont("Common Normal") .. { Name = "Wife", InitCommand = function(self) self:halign(0):valign(0.5):x(190):y(rowH/2 - 5):zoom(0.40):diffuse(brightText) end },
		LoadFont("Common Normal") .. { Name = "Judge", InitCommand = function(self) self:halign(1):valign(0.5):x(185):y(rowH/2 - 5):zoom(0.30):diffuse(subText) end },
		LoadFont("Common Normal") .. { Name = "Judgments", InitCommand = function(self) self:halign(0):valign(0.5):x(190):y(rowH/2 + 8):zoom(0.28):diffuse(subText) end },
		LoadFont("Common Normal") .. { Name = "SSR", InitCommand = function(self) self:halign(0):valign(0.5):x(280):y(rowH/2):zoom(0.50):diffuse(brightText):visible(HV.ShowMSD()) end },
		LoadFont("Common Normal") .. { Name = "Grade", InitCommand = function(self) self:halign(0):valign(0.5):x(345):y(rowH/2):zoom(0.38) end },
		LoadFont("Common Normal") .. { Name = "Rate", InitCommand = function(self) self:halign(0):valign(0.5):x(415):y(rowH/2):zoom(0.38):diffuse(mainText) end },
		LoadFont("Common Normal") .. { Name = "Clear", InitCommand = function(self) self:halign(0):valign(0.5):x(485):y(rowH/2):zoom(0.35) end },
		LoadFont("Common Normal") .. { Name = "Date", InitCommand = function(self) self:halign(1):valign(0.5):x(overlayW - 90):y(rowH/2):zoom(0.32):diffuse(subText) end },
		LoadFont("Common Normal") .. { Name = "CC", InitCommand = function(self) self:halign(0):valign(0.5):x(30):y(rowH/2 + 8):zoom(0.28):diffuse(color("#FF0000")):settext("Chord Cohesion ON") end },
		-- Replay Button
		Def.ActorFrame {
			Name = "ReplayButton",
			InitCommand = function(self) self:xy(overlayW - 60, rowH / 2):zoom(0.32) end,
			RefreshScoresCommand = function(self)
				local idx = (currentPage - 1) * pageSize + i
				local s = displayedScores[idx]
				if s then
					local ss = s.score or s
					if currentView == VIEW_LOCAL then
						self:visible(ss:HasReplayData())
					else
						self:visible(true)
					end
				else
					self:visible(false)
				end
			end,
			Def.Quad { Name = "Hit", InitCommand = function(self) self:zoomto(60, 60):diffusealpha(0) end },
			LoadActor(THEME:GetPathG("", "mp_play")) .. {
				InitCommand = function(self) self:diffuse(accentColor) end,
			},
		},

		RefreshScoresCommand = function(self)
			local idx = (currentPage - 1) * pageSize + i
			local scores = displayedScores

			if idx <= #scores then
				self:visible(true)
				self:stoptweening():diffusealpha(0):sleep(i * 0.04):linear(0.15):diffusealpha(1)
				self:GetChild("Rank"):settext(tostring(idx))

				if currentView == VIEW_LOCAL then
					local entry = scores[idx]
					local s = entry.score
					self:GetChild("Player"):settext(THEME:GetString("Common", "You"))
					
					-- Judgments
					self:GetChild("Judgments"):settext(HV.GetRidiculousTallyString(s))

					-- Wife% display
					local wife = s:GetWifeScore() * 100
					if displayAsJ4 then
						wife = getJ4NormalizedPercentage(s)
					end
					
					if wife >= 99.7 then
						self:GetChild("Wife"):settextf("%.4f%%", wife)
					else
						self:GetChild("Wife"):settextf("%.2f%%", wife)
					end
					
					local norm = PREFSMAN:GetPreference("SortBySSRNormPercent")
					local judgeIndex = ""
					if displayAsJ4 then
						judgeIndex = "J4"
					elseif not norm and type(s.GetJudgeScale) == "function" then
						local scale = s:GetJudgeScale()
						if scale then
							scale = math.floor(scale * 100 + 0.5) / 100
							local j = 4
							for k, v in pairs(ms.JudgeScalers) do
								if math.floor(v * 100 + 0.5) / 100 == scale then
									j = k
									if j >= 4 then break end
								end
							end
							j = math.max(4, math.min(9, j))
							judgeIndex = "J" .. j
						end
					end
					self:GetChild("Judge"):settext(judgeIndex)
					if displayAsJ4 then
						self:GetChild("Judge"):diffuse(accentColor)
					else
						self:GetChild("Judge"):diffuse(subText)
					end

					local ssr = 0
					if s.GetSkillsetSSR then ssr = s:GetSkillsetSSR("Overall")
					elseif s.GetSkillsetSum then ssr = s:GetSkillsetSum()
					elseif s.GetSkillSetSum then ssr = s:GetSkillSetSum() end
					
					self:GetChild("SSR"):settextf("%.2f", ssr):diffuse(HVColor.GetMSDRatingColor(ssr)):visible(HV.ShowMSD())

					local gradeStr = ToEnumShortString(s:GetWifeGrade())
					self:GetChild("Grade"):settext(HV.GetGradeName(gradeStr)):diffuse(HVColor.GetGradeColor(gradeStr))
					self:GetChild("Rate"):settextf("%.2fx", s:GetMusicRate())

					local ct = getDetailedClearType(s)
					self:GetChild("Clear"):settext(ct):diffuse(HVColor.GetClearTypeColor(ct))
					self:GetChild("Date"):settext(s:GetDate())

					-- Chord Cohesion indicator
					local cc = self:GetChild("CC")
					if cc then
						cc:visible(s:GetChordCohesion())
					end
				else
					-- Online leaderboard score
					local s = scores[idx]
					pcall(function()
						local username = GetScoreDisplayName(s) or "Unknown"
						self:GetChild("Player"):settext(username)

						-- Online judgments if available
						self:GetChild("Judgments"):settext(HV.GetRidiculousTallyString(s))

						local wife = s:GetWifeScore() * 100
						if wife >= 99.7 then
							self:GetChild("Wife"):settextf("%.4f%%", wife)
						else
							self:GetChild("Wife"):settextf("%.2f%%", wife)
						end
						
						self:GetChild("Judge"):settext("")

						local ssr = 0
						if s.GetSkillsetSSR then ssr = s:GetSkillsetSSR("Overall")
						elseif s.GetSkillsetSum then ssr = s:GetSkillsetSum()
						elseif s.GetSkillSetSum then ssr = s:GetSkillSetSum() end
						
						self:GetChild("SSR"):settextf("%.2f", ssr):diffuse(HVColor.GetMSDRatingColor(ssr)):visible(HV.ShowMSD())

						local gradeStr = ToEnumShortString(s:GetWifeGrade())
						self:GetChild("Grade"):settext(HV.GetGradeName(gradeStr)):diffuse(HVColor.GetGradeColor(gradeStr))
						self:GetChild("Rate"):settextf("%.2fx", s:GetMusicRate())

						local ct = getDetailedClearType(s)
						self:GetChild("Clear"):settext(ct):diffuse(HVColor.GetClearTypeColor(ct))
						self:GetChild("Date"):settext(s:GetDate())

						-- Chord Cohesion indicator (online scores might not always have this)
						local cc = self:GetChild("CC")
						if cc then
							if s.GetChordCohesion then
								cc:visible(s:GetChordCohesion())
							else
								cc:visible(false)
							end
						end
					end)
				end
			else
				self:visible(false)
			end
		end,
	}
end

local function UpdateDisplayedScores()
	displayedScores = {}
	local source = currentView == VIEW_LOCAL and localScores or onlineScores
	
	if currentView == VIEW_LOCAL then
		displayedScores = source -- localScores is already filtered in GetLocalScores
	else
		-- Online scores need manual filtering if CUR. RATE is active
		local currentRate = getCurRateValue()
		for _, s in ipairs(source) do
			local rNum = s:GetMusicRate()
			if not filterCurrentRate or math.abs(rNum - currentRate) < 0.001 then
				displayedScores[#displayedScores + 1] = s
			end
		end
	end

	-- Always sort the final displayed list if we just switched sort mode
	SortScores(displayedScores)
end

-- RefreshScores on main frame
t.RefreshScoresCommand = function(self)
	hoveredCommentScore = nil
	UpdateDisplayedScores()
	
	local scores = displayedScores
	local totalPages = math.max(1, math.ceil(#scores / pageSize))
	currentPage = math.min(currentPage, totalPages)

	local pageInfo = self:GetChild("PageInfo")
	if pageInfo then
		pageInfo:settextf(THEME:GetString("Common", "PageInfoDetailed"), currentPage, totalPages, #scores)
	end

	for ri = 1, pageSize do
		local row = self:GetChild("ScoreRow_" .. ri)
		if row then row:playcommand("RefreshScores") end
	end
end

-- Input handler
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		screen:AddInputCallback(function(event)
			if not scoresActor or not scoresActor:GetVisible() then return false end
			if not event or not event.DeviceInput then return false end
			
			local btn = event.DeviceInput.button
			local isPress = event.type == "InputEventType_FirstPress"

			if isPress and btn == "DeviceButton_left mouse button" then
				-- Close on outside click
				if not IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
					MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
					return true
				end

				-- Close button
				if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 16, SCREEN_CENTER_Y - overlayH/2 + 16, 24, 24) then
					MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
					return true
				end

				-- Mode toggle
				if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 55, SCREEN_CENTER_Y - overlayH/2 + 18, 100, 18) then
					if currentView == VIEW_LOCAL then
						currentView = VIEW_ONLINE
						FetchOnlineScores()
					else
						currentView = VIEW_LOCAL
						GetLocalScores()
					end
					currentPage = 1
					scoresActor:playcommand("RefreshScores")
					return true
				end

				-- Rate button
				if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 145, SCREEN_CENTER_Y - overlayH/2 + 18, 65, 18) then
					filterCurrentRate = not filterCurrentRate
					currentPage = 1
					if currentView == VIEW_LOCAL then
						GetLocalScores()
					end
					scoresActor:playcommand("RefreshScores")
					return true
				end

				-- Sort button
				if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 215, SCREEN_CENTER_Y - overlayH/2 + 18, 65, 18) then
					currentSort = (currentSort == SORT_SSR) and SORT_WIFE or SORT_SSR
					currentPage = 1
					SortScores(localScores)
					SortScores(onlineScores)
					scoresActor:playcommand("RefreshScores")
					return true
				end

				-- J4 Display button
				local normPref = PREFSMAN:GetPreference("SortBySSRNormPercent")
				if not normPref and IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 285, SCREEN_CENTER_Y - overlayH/2 + 18, 65, 18) then
					displayAsJ4 = not displayAsJ4
					currentPage = 1
					SortScores(localScores)
					SortScores(onlineScores)
					scoresActor:playcommand("RefreshScores")
					return true
				end

				-- Row interaction
				local replayX = SCREEN_CENTER_X + 305
				for ri = 1, pageSize do
					local ry = SCREEN_CENTER_Y + rowsStartY + (ri - 1) * rowH + rowH / 2
					
					-- Replay button
					-- Check Replay Button.
					if IsMouseOverCentered(replayX, ry, 35, 30) then
						local idx = (currentPage - 1) * pageSize + ri
						local s = displayedScores[idx]
						if s then
							local ss = s.score or s
							if currentView == VIEW_LOCAL then
								HV.OnlineReplayActive = false
								HV.OnlineReplayName = nil
								HV.OnlineEvaluationName = nil
								if ss:HasReplayData() then
									SCREENMAN:GetTopScreen():PlayReplay(ss)
								end
							else
								-- Online Replay: Request data first, then play
								HV.OnlineReplayActive = true
								-- Keep the leaderboard author's name alongside the replay. The
								-- engine may not preserve online score metadata on the replay
								-- score object after PlayReplay switches screens.
								HV.OnlineReplayName = GetScoreDisplayName(ss)
								HV.OnlineEvaluationName = HV.OnlineReplayName
								DLMAN:RequestOnlineScoreReplayData(
									ss,
									function()
										if ss:GetReplay():HasReplayData() then
											SCREENMAN:GetTopScreen():PlayReplay(ss)
										else
											ms.ok("Replay not available")
										end
									end
								)
							end
						end
						return true
					end

					-- Check Row Click (View Score)
					if IsMouseOverCentered(SCREEN_CENTER_X, ry, overlayW - 50, rowH) then
						local idx = (currentPage - 1) * pageSize + ri
						local s = displayedScores[idx]
						if s then
							ViewScore(s)
						end
						return true
					end
				end
			end

			-- Paging handling
			if isPress then
				if btn == "MenuLeft" or event.button == "Left" or event.DeviceInput.button == "DeviceButton_left" then
					MESSAGEMAN:Broadcast("TabNavigation", {dir = -1})
					return true
				elseif btn == "MenuRight" or event.button == "Right" or event.DeviceInput.button == "DeviceButton_right" then
					MESSAGEMAN:Broadcast("TabNavigation", {dir = 1})
					return true
				end
			end

			if event.button == "Back" or event.DeviceInput.button == "DeviceButton_escape" then
				MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
				return true
			end

			return true
		end)
	end,
}

return t
