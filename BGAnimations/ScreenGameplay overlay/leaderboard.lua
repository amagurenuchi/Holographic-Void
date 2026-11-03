-- Holographic Void: In-Game Leaderboard (Single Player)
-- Shows local or online high scores for the current song during gameplay
-- Top-left corner, individual score cards + live current score
-- THe judgement display is not shown here.

local leaderboardMode = HV.ShowInGameLeaderboard() or "Off"
local topScreen = SCREENMAN:GetTopScreen()
local isNetMultiplayer = NSMAN and NSMAN.IsETTP and NSMAN:IsETTP() and topScreen and topScreen:GetName() and topScreen:GetName():find("Net") ~= nil or false
if GAMESTATE:IsPracticeMode() then
	return Def.ActorFrame {}
end

-- Check if we have a current song and steps
local song = GAMESTATE:GetCurrentSong()
local steps = GAMESTATE:GetCurrentSteps()
if not song or not steps then
	return Def.ActorFrame {}
end

-- HV-themed colors
local accentColor = HVColor.Accent or color("#00CFFF")
local brightText = color("1,1,1,1")
local dimText = color("0.65,0.65,0.65,1")
local bgCard = color("0.06,0.06,0.06,0.85")
local bgCardSelected = color("0.12,0.12,0.12,0.95")

-- Layout
local cardW = 155
local cardH = 38
local cardGap = 3
local startX = 10
local startY = 40
local maxEntries = 5
local isCustomizeGameplay = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay

-- Get player name (prefer online)
local profileName = HV.GetPlayerName()

-- Grade helper
local function GetGradeStr(wife)
	if     wife >= 99.9935 then return "AAAAA"
	elseif wife >= 99.955  then return "AAAA"
	elseif wife >= 99.70   then return "AAA"
	elseif wife >= 93.00   then return "AA"
	elseif wife >= 80.00   then return "A"
	elseif wife >= 70.00   then return "B"
	elseif wife >= 60.00   then return "C"
	elseif wife >= 0       then return "D"
	end
	return "F"
end

-- Score data storage (shared between logic and commands)
local highScores = {}

local function leaderboardVisible()
	return (isNetMultiplayer or leaderboardMode ~= "Off") and not HV.MinimalisticMode()
end

local function animateLeaderboardVisibility(self, visible)
	self:stoptweening()
	if visible then
		self:visible(true):diffusealpha(0):decelerate(0.18):diffusealpha(1)
	else
		self:accelerate(0.14):diffusealpha(0)
	end
end

-- ============================================================
-- Data Fetching Logic
-- ============================================================
local function UpdateScores()
	highScores = {}
	local ck = steps:GetChartKey()
	if not ck then return end

	-- Get current rate for filtering
	local curRate = getCurRateValue()
	local curRateStr = getCurRateString()

	if isNetMultiplayer then
		local lb = NSMAN:GetMPLeaderboard() or {}
		table.sort(lb, function(a, b)
			return (a.wife or -1) > (b.wife or -1)
		end)
		for i = 1, math.min(maxEntries, #lb) do
			local s = lb[i]
			local wife = (s.wife or 0) * 100
			highScores[#highScores + 1] = {
				rank = i,
				wife = wife,
				combo = 0,
				gradeStr = GetGradeStr(wife),
				name = s.user or "???",
				rate = curRate,
				ssr = -1,
			}
		end
	elseif leaderboardMode == "Online" then
		-- Fetch from DLMAN
		local lb = DLMAN:GetChartLeaderBoard(ck)
		if lb then
			local filtered = {}
			for i = 1, #lb do
				local s = lb[i]
				-- Filter by current rate (within epsilon)
				if math.abs(s:GetMusicRate() - curRate) < 0.001 then
					filtered[#filtered + 1] = s
				end
			end

			-- Sort by wife% descending
			table.sort(filtered, function(a, b)
				return a:GetWifeScore() > b:GetWifeScore()
			end)

			for i = 1, math.min(maxEntries, #filtered) do
				local s = filtered[i]
				pcall(function()
					local wife = s:GetWifeScore() * 100
					local ssr = s:GetSkillsetSSR("Overall") or 0
					highScores[#highScores + 1] = {
						rank = i,
						wife = wife,
						combo = s:GetMaxCombo(),
						gradeStr = GetGradeStr(wife),
						name = s:GetDisplayName() or s:GetName() or "???",
						rate = s:GetMusicRate(),
						ssr = ssr,
					}
				end)
			end
		end

		-- If none found, request them
		if #highScores == 0 and DLMAN:IsLoggedIn() then
			DLMAN:RequestChartLeaderBoardFromOnline(ck, function(lbData)
				if lbData and #lbData > 0 then
					MESSAGEMAN:Broadcast("RefreshLeaderboard")
				end
			end)
		end
	else
		-- Local Scores: Only for current rate
		local sl = getScoreTable(PLAYER_1, curRateStr)
		if sl then
			-- Already sorted by score usually, but let's be sure it's wife%
			table.sort(sl, function(a, b) return a:GetWifeScore() > b:GetWifeScore() end)
			
			for i = 1, math.min(maxEntries, #sl) do
				local s = sl[i]
				local wife = s:GetWifeScore() * 100
				local ssr = s:GetSkillsetSSR("Overall") or 0
				highScores[#highScores + 1] = {
					rank = i,
					wife = wife,
					combo = s:GetMaxCombo(),
					gradeStr = GetGradeStr(wife),
					name = HV.GetPlayerName(),
					rate = s:GetMusicRate(),
					ssr = ssr,
				}
			end
		end
	end
end

-- Initial fetch
UpdateScores()

-- ============================================================
-- UI Construction
-- ============================================================
local t = Def.ActorFrame {
	Name = "InGameLeaderboard",
	InitCommand = function(self)
		self:xy((MovableValues and MovableValues.LeaderboardX) or getDefaultGameplayCoordinate("LeaderboardX") or startX, (MovableValues and MovableValues.LeaderboardY) or getDefaultGameplayCoordinate("LeaderboardY") or startY):zoomtowidth((MovableValues and MovableValues.LeaderboardWidth) or getDefaultGameplaySize("LeaderboardWidth") or 1):zoomtoheight((MovableValues and MovableValues.LeaderboardHeight) or getDefaultGameplaySize("LeaderboardHeight") or 1)
		self:visible(leaderboardVisible())
		self:diffusealpha(leaderboardVisible() and 1 or 0)
	end,
	OnCommand = function(self)
		setMovableActor({"DeviceButton_a", "DeviceButton_s"}, self, self:GetChild("Border"))
	end,
	HV_InGameLeaderboardModeChangedMessageCommand = function(self, params)
		leaderboardMode = params and params.Mode or HV.ShowInGameLeaderboard() or "Off"
		animateLeaderboardVisibility(self, leaderboardVisible())
		UpdateScores()
		self:playcommand("RefreshScores")
	end,
	HV_MinimalisticModeChangedMessageCommand = function(self)
		animateLeaderboardVisibility(self, leaderboardVisible())
	end,
	RefreshLeaderboardMessageCommand = function(self)
		UpdateScores()
		self:playcommand("RefreshScores")
	end,
	JudgmentMessageCommand = function(self)
		if isNetMultiplayer then
			UpdateScores()
			self:playcommand("RefreshScores")
		end
	end,

	-- Mode Tag
	LoadFont("Common Normal") .. {
		Name = "ModeTag",
		InitCommand = function(self)
			self:halign(0):valign(0):xy(4, -12):zoom(0.24)
				:diffuse(accentColor):diffusealpha(0.6)
				:settext((isNetMultiplayer and "MULTI") or leaderboardMode:upper())
		end,
		HV_InGameLeaderboardModeChangedMessageCommand = function(self)
			self:settext((isNetMultiplayer and "MULTI") or leaderboardMode:upper())
		end
	}
}

-- Create historical cards
for i = 1, maxEntries do
	local cardY = (i - 1) * (cardH + cardGap)

	t[#t + 1] = Def.ActorFrame {
		Name = "ScoreCard_" .. i,
		InitCommand = function(self) self:xy(0, cardY) end,
		RefreshScoresCommand = function(self)
			local data = highScores[i]
			self:visible(data ~= nil)
			if data then self:playcommand("SetData", data) end
		end,

		-- Card Background (Subtle Gradient)
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(cardW, cardH)
					:diffuse(bgCard)
					:diffusetopedge(color("0.1,0.1,0.1,0.85"))
			end
		},

		-- Accent Strip (Grade Colored)
		Def.Quad {
			Name = "AccentStrip",
			InitCommand = function(self) self:halign(0):valign(0):zoomto(2, cardH) end,
			SetDataCommand = function(self, data)
				self:diffuse(HVColor.GetGradeColor(data.gradeStr)):diffusealpha(0.8)
			end
		},

		-- Rank
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(6, 3):zoom(0.28):diffuse(dimText) end,
			SetDataCommand = function(self, data) self:settextf("#%d", data.rank) end
		},

		-- Player Name
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(28, 3):zoom(0.28):maxwidth((cardW - 80) / 0.28) end,
			SetDataCommand = function(self, data)
				self:settext(data.name)
				local isLocalUser = (data.name == profileName)
				self:diffuse(isLocalUser and brightText or dimText)
			end
		},

		-- Wife %
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(6, 19):zoom(0.32) end,
			SetDataCommand = function(self, data)
				self:diffuse(HVColor.GetGradeColor(data.gradeStr))
				if data.wife >= 99.7 then self:settextf("%.4f%%", data.wife)
				else self:settextf("%.2f%%", data.wife) end
			end
		},

		-- Rate / Combo (Right-aligned)
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):valign(0):xy(cardW - 6, 3):zoom(0.22):diffuse(dimText) end,
			SetDataCommand = function(self, data) self:settextf("%.2fx", data.rate) end
		},
		-- SSR
		LoadFont("MSD 20px") .. {
			InitCommand = function(self) self:halign(1):valign(0):xy(cardW - 6, 11):zoom(0.24) end,
			SetDataCommand = function(self, data)
				if data.ssr > 0 then
					self:settextf("%.2f", data.ssr):diffuse(HVColor.GetMSDRatingColor(data.ssr))
				else
					self:settext("")
				end
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):valign(0):xy(cardW - 6, 21):zoom(0.22):diffuse(dimText) end,
			SetDataCommand = function(self, data) self:settextf("%dx", data.combo) end
		}
	}
end

-- Current Score Card (Live)
local currentAccent = accentColor

t[#t + 1] = Def.ActorFrame {
	Name = "CurrentScoreRow",
	RefreshScoresCommand = function(self)
		local y = #highScores * (cardH + cardGap) + 6
		self:stoptweening():linear(0.2):y(y)
		self:visible(true)
	end,

	-- Card Background
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(cardW, cardH)
				:diffuse(bgCardSelected)
		end
	},

	-- Pulsing Accent Strip
	Def.Quad {
		Name = "CurrentAccent",
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(2, cardH)
				:diffuse(currentAccent)
				:diffusealpha(0.8)
				:pulse():effectmagnitude(1.0, 0.4, 0):effectperiod(1.5)
		end
	},

	-- "NOW" Label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(6, 3):zoom(0.24)
				:diffuse(currentAccent):settext("NOW")
		end
	},

	-- Player Name
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(32, 3):zoom(0.28)
				:diffuse(brightText):settext(profileName)
		end
	},

	-- Live Stats
	LoadFont("Common Normal") .. {
		Name = "LiveWife",
		InitCommand = function(self) self:halign(0):valign(0):xy(6, 19):zoom(0.32):settext("100.00%") end,
		JudgmentMessageCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(PLAYER_1)
			if not pss then return end
			local wife = pss:GetWifeScore() * 100
			
			local notesPassed = pss:GetTapNoteScores("TapNoteScore_W1") +
							   pss:GetTapNoteScores("TapNoteScore_W2") +
							   pss:GetTapNoteScores("TapNoteScore_W3") +
							   pss:GetTapNoteScores("TapNoteScore_W4") +
							   pss:GetTapNoteScores("TapNoteScore_W5") +
							   pss:GetTapNoteScores("TapNoteScore_Miss")
			if notesPassed == 0 then
				wife = 100.0000
			end
			
			if wife >= 99.7 then self:settextf("%.4f%%", wife)
			else self:settextf("%.2f%%", wife) end
			local g = GetGradeStr(wife)
			local c = HVColor.GetGradeColor(g)
			self:diffuse(c)
			local acc = self:GetParent():GetChild("CurrentAccent")
			if acc then acc:diffuse(c) end
		end
	},
	LoadFont("Common Normal") .. {
		Name = "LiveCombo",
		InitCommand = function(self) self:halign(1):valign(0):xy(cardW - 6, 21):zoom(0.22):diffuse(dimText):settext("0x") end,
		JudgmentMessageCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(PLAYER_1)
			if not pss then return end
			local combo = pss:GetCurrentCombo()
			self:settextf("%dx", combo)
			self:diffuse(combo >= 100 and accentColor or dimText)
		end
	}
}

-- Trigger first refresh
t.BeginCommand = function(self) self:playcommand("RefreshScores") end

t[#t + 1] = MovableBorder(cardW, ((cardH + cardGap) * (maxEntries + 1)), 1, cardW / 2, ((cardH + cardGap) * (maxEntries + 1)) / 2)

return t
