-- Holographic Void: Online Leaderboard (ported from spawncamping-wallhack)
-- Displays EtternaOnline chart leaderboard with Local/Online toggle.
-- Current Rate: same-rate only, sorted by Wife%.
-- All Rates: all rates, sorted by SSR.
-- maybe merge this with MPscoreboard.lua?

local pn = GAMESTATE:GetEnabledPlayers()[1]
local steps = GAMESTATE:GetCurrentSteps()
local profile = PROFILEMAN:GetProfile(pn)
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
local score = pss:GetHighScore()

local hsTable = getScoreTable(pn, getCurRate()) or {}

-- HV Color palette
local accentColor = HVColor.Accent
local brightText = color("1,1,1,1")
local dimText = brightText
local subText = brightText
local mainText = brightText
local bgCard = color("0.06,0.06,0.06,0.7")

local offsetScoreID

local lbActor
local isLocal = true
local currentCountry = "Global"
local scoresPerPage = 4
local maxPages = math.max(1, math.ceil(#hsTable / scoresPerPage))
local curPage = 1
local alreadyPulled = false
local scoreList = hsTable
local showAllRates = false
local showInvalidScores = false

local function isOnlineScoreInvalid(s)
	if not s then return false end
	if type(s.GetEtternaValid) == "function" then
		local ok, valid = pcall(s.GetEtternaValid, s)
		if ok and valid == false then return true end
	end
	return IsScoreInvalid(s)
end

local function getViewedRateValue()
	if score and score.GetMusicRate then
		local viewedRate = score:GetMusicRate()
		if type(viewedRate) == "number" and viewedRate > 0 then
			return viewedRate
		end
	end
	return getCurRateValue and getCurRateValue() or 1.0
end

local function getViewedRateString()
	return string.format("%.2fx", getViewedRateValue())
end

local function isSameRateValue(a, b)
	return math.abs((a or 0) - (b or 0)) < 0.001
end

local function isSameRateScore(s, targetRateValue, targetRateString)
	if not s then return false end
	if s.GetMusicRate and isSameRateValue(s:GetMusicRate(), targetRateValue) then
		return true
	end
	return getRate and getRate(s) == targetRateString
end

local function getJudge(score)
	local scale = (score and type(score.GetJudgeScale) == "function") and score:GetJudgeScale() or 1.0
	if not scale then return "J4" end
	scale = math.floor(scale * 100 + 0.5) / 100
	for k, v in pairs(ms.JudgeScalers) do
		if math.floor(v * 100 + 0.5) / 100 == scale then
			return "J" .. math.max(4, k)
		end
	end
	return "J4"
end

local function updateLeaderBoardForCurrentChart()
	alreadyPulled = true
	if steps then
		DLMAN:RequestChartLeaderBoardFromOnline(
			steps:GetChartKey(),
			function(leaderboard)
				if lbActor then
					lbActor:queuecommand("SetFromLeaderboard", leaderboard)
				end
			end
		)
	else
		if lbActor then
			lbActor:queuecommand("SetFromLeaderboard", {})
		end
	end
end

local function syncOnlineRateFilter()
	if not DLMAN then return end
	if DLMAN.SetRateFilter then
		-- DLMAN's boolean semantics are inverted relative to the original theme-side assumption:
		-- `true` returns all rates, `false` keeps the current-rate filter active.
		pcall(function() DLMAN:SetRateFilter(showAllRates) end)
	elseif DLMAN.ToggleRateFilter then
		pcall(function() DLMAN:ToggleRateFilter() end)
	end
end

local function movePage(n)
	if maxPages <= 1 then return end
	if n > 0 then
		curPage = ((curPage + n - 1) % maxPages) + 1
	else
		curPage = ((curPage + n + maxPages - 1) % maxPages) + 1
	end
	MESSAGEMAN:Broadcast("UpdateOnlineList")
end

local function refreshScores(self)
	local targetRateValue = getViewedRateValue()
	local targetRate = getViewedRateString()
	if isLocal then
		scoreList = {}
		local ck = (steps and steps.GetChartKey) and steps:GetChartKey() or ""
		local scoresByKey = (ck ~= "") and SCOREMAN:GetScoresByKey(ck) or nil

		if scoresByKey then
			for rateStr, rateScores in pairs(scoresByKey) do
				-- If showing all rates, add everything. 
				-- Otherwise, only add scores for the current rate.
				if showAllRates or rateStr == targetRate then
					local scores = rateScores:GetScores()
					for j = 1, #scores do
						scoreList[#scoreList + 1] = scores[j]
					end
				end
			end
		end

		-- Exact-rate fallback only. Do not leak nearby-rate scores into Current Rate.
		if #scoreList == 0 and not showAllRates and hsTable then
			for i = 1, #hsTable do
				if isSameRateScore(hsTable[i], targetRateValue, targetRate) then
					scoreList[#scoreList + 1] = hsTable[i]
				end
			end
		end

		-- Local sorting:
		-- Current Rate -> J4/Wife%-first within the current rate only.
		-- All Rates -> SSR-first across every available rate.
		table.sort(scoreList, function(a, b)
			if showAllRates then
				local sa = a:GetSkillsetSSR("Overall") or 0
				local sb = b:GetSkillsetSSR("Overall") or 0
				if math.abs(sa - sb) > 0.0001 then return sa > sb end
				return (getJ4NormalizedPercentage(a) or 0) > (getJ4NormalizedPercentage(b) or 0)
			else
				local wa = getJ4NormalizedPercentage(a) or 0
				local wb = getJ4NormalizedPercentage(b) or 0
				if math.abs(wa - wb) > 0.000001 then return wa > wb end
				return (a:GetSkillsetSSR("Overall") or 0) > (b:GetSkillsetSSR("Overall") or 0)
			end
		end)
	else
		local rawOnlineScores = DLMAN:GetChartLeaderBoard(steps:GetChartKey(), currentCountry)
		scoreList = {}
		if rawOnlineScores then
			for i = 1, #rawOnlineScores do
				local s = rawOnlineScores[i]
				if (showInvalidScores or not isOnlineScoreInvalid(s)) and (showAllRates or isSameRateScore(s, targetRateValue, targetRate)) then
					scoreList[#scoreList + 1] = s
				end
			end
		end
		if scoreList ~= nil and #scoreList == 0 and not alreadyPulled then
			updateLeaderBoardForCurrentChart()
		end
		if scoreList then
			-- Online sorting:
			-- Current Rate -> Wife%-first within the current rate only.
			-- All Rates -> SSR-first across every available rate.
			table.sort(scoreList, function(a, b)
				if showAllRates then
					local sa = a:GetSkillsetSSR("Overall") or 0
					local sb = b:GetSkillsetSSR("Overall") or 0
					if math.abs(sa - sb) > 0.0001 then return sa > sb end
					return (a:GetWifeScore() or 0) > (b:GetWifeScore() or 0)
				else
					local wa = a:GetWifeScore() or 0
					local wb = b:GetWifeScore() or 0
					if math.abs(wa - wb) > 0.000001 then return wa > wb end
					return (a:GetSkillsetSSR("Overall") or 0) > (b:GetSkillsetSSR("Overall") or 0)
				end
			end)
		end
	end
	curPage = 1
	if scoreList ~= nil then
		maxPages = math.max(1, math.ceil(#scoreList / scoresPerPage))
	else
		maxPages = 1
		scoreList = {}
	end
end

local function scoreItem(i)
	return Def.ActorFrame {
		Name = "OnlineRow" .. i,
		InitCommand = function(self) self:y((i - 1) * 46):diffusealpha(0) end,
		OnCommand = function(self) self:playcommand("UpdateRow") end,
		UpdateOnlineListMessageCommand = function(self) self:playcommand("UpdateRow") end,
		RefreshOnlineScoreboardMessageCommand = function(self) self:playcommand("UpdateRow") end,
		UpdateRowCommand = function(self)
			local idx = (curPage - 1) * scoresPerPage + i
			if scoreList and scoreList[idx] then
				self:visible(true)
				self:stoptweening():diffusealpha(0):sleep(i * 0.05):linear(0.15):diffusealpha(1)
				self:RunCommandsOnChildren(function(child) child:playcommand("SetScore", {index = idx}) end)
			else
				self:visible(false)
			end
		end,

		-- Row BG
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(SCREEN_CENTER_X - 40, 42):diffuse(color("0,0,0,0.4"))
			end,
			SetScoreCommand = function(self, params)
				local s = scoreList[params.index]
				self:diffuse(not isLocal and isOnlineScoreInvalid(s) and color("#7A1018") or color("0,0,0,0.4"))
			end,
			WheelUpSlowMessageCommand = function(self) if isOver(self) then movePage(-1) end end,
			WheelDownSlowMessageCommand = function(self) if isOver(self) then movePage(1) end end
		},

		-- Rank #
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(10, 21):zoom(0.45):diffuse(accentColor):halign(0) end,
			SetScoreCommand = function(self, params)
				self:settext(params.index)
			end
		},

		-- Clear type
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(220, 8):zoom(0.32):halign(0):diffuse(subText) end,
			SetScoreCommand = function(self, params)
				local s = scoreList[params.index]
				local ct = (not isLocal and isOnlineScoreInvalid(s)) and "Invalid" or getDetailedClearType(s)
				self:settext(ct):diffuse(HVColor.GetClearTypeColor(ct))
			end
		},

		-- Player name (online only) or date (local + optional judge)
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(40, 8):zoom(0.4):halign(0):diffuse(brightText) end,
			SetScoreCommand = function(self, params)
				local s = scoreList[params.index]
				if isLocal then
					local judgeStr = ""
					if not PREFSMAN:GetPreference("SortBySSRNormPercent") then
						judgeStr = " (" .. getJudge(s) .. ")"
					end
					self:settext(s:GetDate() .. judgeStr)
				else
					local name = s:GetDisplayName()
					if name and name ~= "" then
						self:settext(name)
					else
						self:settext("Unknown")
					end
				end
			end
		},

		-- Grade
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(40, 26):zoom(0.5):halign(0) end,
			SetScoreCommand = function(self, params)
				local s = scoreList[params.index]
				local grade = s:GetWifeGrade()
				self:settext(HV.GetGradeName(ToEnumShortString(grade)))
				self:diffuse(HVColor.GetGradeColor(ToEnumShortString(grade)))
			end
		},

		-- Score %
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(90, 26):zoom(0.5):halign(0):diffuse(mainText) end,
			SetScoreCommand = function(self, params)
				local ws = scoreList[params.index]:GetWifeScore()
				if ws >= 0.99 then
					self:settextf("%.4f%%", math.floor(ws * 1000000) / 10000)
				else
					self:settextf("%.2f%%", math.floor(ws * 10000) / 100)
				end
			end
		},

		-- SSR
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(SCREEN_CENTER_X - 50, 8):zoom(0.55):halign(1) end,
			SetScoreCommand = function(self, params)
				if not HV.ShowMSD() then
					self:settext("")
					return
				end
				local ssr = scoreList[params.index]:GetSkillsetSSR("Overall")
				if ssr > 0 then
					self:settextf("%.2f", ssr)
					self:diffuse(HVColor.GetMSDRatingColor(ssr))
				else
					self:settext(""):diffuse(dimText)
				end
			end
		},

		-- Judgment tally (no labels)
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(SCREEN_CENTER_X - 50, 26):zoom(0.35):halign(1):diffuse(subText) end,
			SetScoreCommand = function(self, params)
				local s = scoreList[params.index]
				self:settext(HV.GetRidiculousTallyString(s))
			end
		},

		-- Rate Display (only for All Rates)
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(135, 24):zoom(0.3):halign(0):diffuse(mainText) end,
			SetScoreCommand = function(self, params)
				if showAllRates then
					local s = scoreList[params.index]
					self:settextf("%.2fx", s:GetMusicRate()):visible(true)
				else
					self:visible(false)
				end
			end
		},


		MouseDownCommand = function(self, params)
			self:RunCommandsOnChildren(function(child) child:playcommand("MouseDown", params) end)
		end,
	}
end

local t = Def.ActorFrame {
	Name = "OnlineLeaderboard",
	InitCommand = function(self) lbActor = self self:diffusealpha(0) end,
	OnCommand = function(self)
		self:sleep(0.6):linear(0.2):diffusealpha(1)
		refreshScores(self)
		self:playcommand("RefreshUI")
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if not self:GetVisible() then return end
			if event.type == "InputEventType_FirstPress" then
				if event.button == "MenuLeft" or event.DeviceInput.button == "DeviceButton_left" or event.button == "Left" then movePage(-1)
				elseif event.button == "MenuRight" or event.DeviceInput.button == "DeviceButton_right" or event.button == "Right" then movePage(1) end
				
				if event.DeviceInput.button == "DeviceButton_left mouse button" then
					self:RunCommandsOnChildren(function(child) child:playcommand("MouseDown", {event = event}) end)
				end
			end
		end)
	end,
	SetFromLeaderboardCommand = function(self, leaderboard)
		refreshScores(self)
		self:playcommand("RefreshUI")
	end,
	RefreshUICommand = function(self)
		MESSAGEMAN:Broadcast("RefreshOnlineScoreboard")
	end,

	-- ============================================================
	-- TAB BUTTONS: Local / Online
	-- ============================================================
	Def.Quad {
		Name = "LocalTab",
		InitCommand = function(self)
			self:xy(0, -38):zoomto(60, 16):halign(0):valign(0)
			self:diffuse(accentColor):diffusealpha(isLocal and 0.4 or 0.1)
		end,
		RefreshOnlineScoreboardMessageCommand = function(self)
			self:diffusealpha(isLocal and 0.4 or 0.1)
		end,
		MouseDownCommand = function(self)
			if isOver(self) and not isLocal then
				isLocal = true
				refreshScores(self:GetParent())
				self:GetParent():playcommand("RefreshUI")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(30, -30):zoom(0.32):diffuse(brightText):settext("Local") end
	},

	Def.Quad {
		Name = "OnlineTab",
		InitCommand = function(self)
			self:xy(64, -38):zoomto(60, 16):halign(0):valign(0)
			self:diffuse(accentColor):diffusealpha(not isLocal and 0.4 or 0.1)
		end,
		RefreshOnlineScoreboardMessageCommand = function(self)
			self:diffusealpha(not isLocal and 0.4 or 0.1)
		end,
		MouseDownCommand = function(self)
			if isOver(self) and isLocal and DLMAN:IsLoggedIn() then
				isLocal = false
				syncOnlineRateFilter()
				alreadyPulled = false
				updateLeaderBoardForCurrentChart()
				refreshScores(self:GetParent())
				self:GetParent():playcommand("RefreshUI")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(94, -30):zoom(0.32):diffuse(brightText):settext("Online") end
	},

	-- ============================================================
	-- RATE FILTER: Current / All
	-- ============================================================
	Def.Quad {
		Name = "CurrentRateTab",
		InitCommand = function(self)
			self:xy(160, -38):zoomto(70, 16):halign(0):valign(0)
			-- Flipped back as per user request
			self:diffuse(color("#555555")):diffusealpha(not showAllRates and 0.4 or 0.1)
		end,
		RefreshOnlineScoreboardMessageCommand = function(self)
			self:diffusealpha(isLocal and 0 or (not showAllRates and 0.4 or 0.1))
		end,
		MouseDownCommand = function(self)
			if isOver(self) and not isLocal and showAllRates then
				showAllRates = false
				syncOnlineRateFilter()
				alreadyPulled = false
				updateLeaderBoardForCurrentChart()
				refreshScores(self:GetParent())
				self:GetParent():playcommand("RefreshUI")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(195, -30):zoom(0.3):diffuse(brightText):settext("Current") end,
		RefreshOnlineScoreboardMessageCommand = function(self) self:visible(not isLocal) end
	},

	Def.Quad {
		Name = "AllRatesTab",
		InitCommand = function(self)
			self:xy(234, -38):zoomto(60, 16):halign(0):valign(0)
			-- Flipped back as per user request
			self:diffuse(color("#555555")):diffusealpha(isLocal and 0 or (showAllRates and 0.4 or 0.1))
		end,
		RefreshOnlineScoreboardMessageCommand = function(self)
			self:diffusealpha(isLocal and 0 or (showAllRates and 0.4 or 0.1))
		end,
		MouseDownCommand = function(self)
			if isOver(self) and not isLocal and not showAllRates then
				showAllRates = true
				syncOnlineRateFilter()
				alreadyPulled = false
				updateLeaderBoardForCurrentChart()
				refreshScores(self:GetParent())
				self:GetParent():playcommand("RefreshUI")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(264, -30):zoom(0.3):diffuse(brightText):settext("All") end,
		RefreshOnlineScoreboardMessageCommand = function(self) self:visible(not isLocal) end
	},

	-- Invalid score visibility
	Def.Quad {
		Name = "InvalidToggle",
		InitCommand = function(self)
			self:xy(305, -38):zoomto(92, 16):halign(0):valign(0):diffuse(color("#B01824"))
			self:diffusealpha(0)
		end,
		RefreshOnlineScoreboardMessageCommand = function(self)
			self:diffusealpha(not isLocal and (showInvalidScores and 0.65 or 0.2) or 0)
		end,
		MouseDownCommand = function(self)
			if isOver(self) and not isLocal then
				showInvalidScores = not showInvalidScores
				refreshScores(self:GetParent())
				self:GetParent():playcommand("RefreshUI")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(351, -30):zoom(0.28):diffuse(brightText) end,
		RefreshOnlineScoreboardMessageCommand = function(self)
			self:visible(not isLocal):settext(showInvalidScores and "Invalid ON" or "Invalid OFF")
		end
	},

	-- Page info
	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self) self:xy(150, scoresPerPage * 46 + 8):zoom(0.28):diffuse(dimText) end,
		OnCommand = function(self) self:playcommand("UpdateText") end,
		UpdateOnlineListMessageCommand = function(self) self:playcommand("UpdateText") end,
		RefreshOnlineScoreboardMessageCommand = function(self) self:playcommand("UpdateText") end,
		UpdateTextCommand = function(self)
			if scoreList and #scoreList > 0 then
				local src = isLocal and "Local" or "Online"
				local rateLabel = showAllRates and "All Rates" or "Current Rate"
				self:settextf("%s (%s) - Page %d/%d - %d scores", src, rateLabel, curPage, maxPages, #scoreList)
			else
				self:settext("No scores")
			end
		end
	},
}

for i = 1, scoresPerPage do
	t[#t + 1] = scoreItem(i)
end

return t
