local pn = GAMESTATE:GetEnabledPlayers()[1] or PLAYER_1
local lScreen = Var "LoadingScreen" or ""
local isSync = lScreen:find("Sync") ~= nil
local isCustomizeGameplay = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay
local HV_PointsLost = 0
local HV_MaxPoints = 1 -- Placeholder, will be set in BeginCommand
local HV_PBThreshold = 0
local HV_JudgeScale = 1.0
local HV_AutoFailJudgeCounts = { W2 = 0, W3 = 0, W4 = 0, W5 = 0, Miss = 0 }
local HV_RidiculousCount = 0
local failSfxPath = THEME:GetPathS("", "ScreenGameplay failed")
local failSfxPlayed = false

local function PlayFailSfxOnce()
	if failSfxPlayed then return end
	failSfxPlayed = true
	if failSfxPath and failSfxPath ~= "" then
		SOUND:PlayOnce(failSfxPath)
	end
end

local function GetCurrentSongSecond()
	local pos = GAMESTATE:GetSongPosition()
	if pos and pos.GetMusicSeconds then
		return pos:GetMusicSeconds() or 0
	end
	return 0
end

local function HardStopAutofail(top)
	if not top then return end

	local freezePos = math.max(0, GetCurrentSongSecond())

	if top.SetSongPosition then
		pcall(function() top:SetSongPosition(freezePos) end)
	end

	if top.GetPaused and top.TogglePause then
		local ok, paused = pcall(function() return top:GetPaused() end)
		if ok and not paused then
			pcall(function() top:TogglePause() end)
		end
	end

	if top.GetLifeMeter then
		local lifeMeter = top:GetLifeMeter(pn)
		if lifeMeter and lifeMeter.ChangeLife then
			pcall(function() lifeMeter:ChangeLife(-10) end)
		end
	end
end

local function gameplayCoord(name)
	return (MovableValues and MovableValues[name]) or getDefaultGameplayCoordinate(name) or 0
end

local function gameplaySize(name)
	return (MovableValues and MovableValues[name]) or getDefaultGameplaySize(name) or 1
end

local function minimalisticHUDVisible(baseVisible, enabled)
	if enabled == nil then enabled = HV.MinimalisticMode() end
	return baseVisible and not enabled
end

local function animateGameplayHUDVisibility(self, visible, instant)
	self:stoptweening()
	if visible then
		self:visible(true)
		if instant then
			self:diffusealpha(1):zoom(1)
		else
			self:diffusealpha(0):zoom(0.96):decelerate(0.18):diffusealpha(1):zoom(1)
		end
	else
		if instant then
			self:diffusealpha(0):zoom(0.96):visible(false)
		else
			self:accelerate(0.14):diffusealpha(0):zoom(0.96):sleep(0):visible(false)
		end
	end
end

local function applyMinimalisticVisibility(self, baseVisible, enabled, instant)
	animateGameplayHUDVisibility(self, minimalisticHUDVisible(baseVisible, enabled), instant)
end

local function getChartLastSecond(song, steps)
	if steps then
		local ok, len = pcall(function() return steps:GetLastSecond() end)
		if ok and len and len > 0 then return len end
	end
	if song then
		local ok, len = pcall(function() return song:GetLastSecond() end)
		if ok and len and len > 0 then return len end
		ok, len = pcall(function() return song:MusicLengthSeconds() end)
		if ok and len and len > 0 then return len end
	end
	return 0
end

local function hideFallbackLifeBar()
	local top = SCREENMAN and SCREENMAN:GetTopScreen()
	if not top or not top.GetLifeMeter then return end
	for _, player in ipairs(GAMESTATE:GetEnabledPlayers()) do
		local lifeMeter = top:GetLifeMeter(player)
		if lifeMeter then
			lifeMeter:visible(false)
			lifeMeter:diffusealpha(0)
		end
	end
end

local function toggleMinimalisticModePreference()
	local enabled = not HV.MinimalisticMode()
	ThemePrefs.Set("HV_MinimalisticMode", enabled)
	local top = SCREENMAN and SCREENMAN:GetTopScreen()
	if top and top.GetChild then
		local overlay = top:GetChild("GameplayOverlay")
		if overlay then
			overlay:playcommand("ApplyMinimalisticMode", { Enabled = enabled })
		end
	end
	if SCREENMAN then
		SCREENMAN:SystemMessage("Minimalistic Mode: " .. (enabled and "On" or "Off"))
	end
	MESSAGEMAN:Broadcast("HV_MinimalisticModeChanged", { Enabled = enabled })
end

local function toggleInGameLeaderboardPreference()
	local mode = HV.ShowInGameLeaderboard()
	if mode == "Off" then
		local lastMode = ThemePrefs.Get("HV_LastInGameLeaderboardMode") or "Local"
		if lastMode ~= "Local" and lastMode ~= "Online" then lastMode = "Local" end
		ThemePrefs.Set("HV_ShowInGameLeaderboard", lastMode)
		MESSAGEMAN:Broadcast("HV_InGameLeaderboardModeChanged", { Mode = lastMode })
	else
		if mode == "Local" or mode == "Online" then
			ThemePrefs.Set("HV_LastInGameLeaderboardMode", mode)
		end
		ThemePrefs.Set("HV_ShowInGameLeaderboard", "Off")
		MESSAGEMAN:Broadcast("HV_InGameLeaderboardModeChanged", { Mode = "Off" })
	end
end

local function isRidiculousJudgment(params)
	return HV.EmulateRidiculousEnabled() and params and params.TapNoteScore == "TapNoteScore_W1" and params.TapNoteOffset and math.abs(params.TapNoteOffset) <= 0.01125 * (tonumber(HV_JudgeScale) or 1)
end

local t = Def.ActorFrame {
	Name = "GameplayOverlay",
	ApplyMinimalisticModeCommand = function(self, params)
		self:playcommand("HV_MinimalisticModeChangedMessage", params)
	end,
	BeginCommand = function(self)
		hideFallbackLifeBar()
		failSfxPlayed = false
		HV_AutoFailJudgeCounts = { W2 = 0, W3 = 0, W4 = 0, W5 = 0, Miss = 0 }
		-- Re-check sync mode via SCREENMAN now that it's safer
		local curScreen = SCREENMAN:GetTopScreen()
		if curScreen and curScreen:GetName():find("Sync") then
			isSync = true
		end
		-- Apply Measure Lines (Beat Bars) mod
		local beatBarMod = HV.ShowMeasureLines() and "beatbars" or "nobeatbars"
		
		-- Apply mods to all enabled players
		for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
			local ps = GAMESTATE:GetPlayerState(pn)
			for _, level in ipairs({"ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Current"}) do
				ps:GetPlayerOptions(level):FromString(beatBarMod)
			end

			-- Sync Mode overrides
			if isSync then
				for _, level in ipairs({"ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Current"}) do
					local po = ps:GetPlayerOptions(level)
					po:CMod(400)
					po:Reverse(0) -- Upscroll
				end
			end
		end
		
		HV.LastGameplayTime = os.time()
		HV.GameplaySessionValid = true

		-- Properly initialize total chart points once song/steps are loaded
		HV_MaxPoints = (getMaxNotes(PLAYER_1) or 1) * 2
		HV_PointsLost = 0
		HV_RidiculousCount = 0
		HV_JudgeScale = PREFSMAN:GetPreference("TimingWindowScale") or 1.0

		-- Initialize Auto-Fail Personal Best threshold if needed
		local condition = ThemePrefs.Get("HV_AutoFailCondition")
		if condition == "Personal Best" then
			local best = GetDisplayScore()
			if best then
				HV_PBThreshold = getJ4NormalizedPercentage(best)
			else
				-- Fallback to Wife Percent threshold if no PB exists
				HV_PBThreshold = tonumber(ThemePrefs.Get("HV_AutoFailThreshold_Wife")) or 93.00
			end
		end
	end,
	OnCommand = function(self)
		hideFallbackLifeBar()
		-- Double check mods on OnCommand just in case
		if isSync then
			for _, pn_loop in ipairs(GAMESTATE:GetEnabledPlayers()) do
				local ps = GAMESTATE:GetPlayerState(pn_loop)
				ps:GetPlayerOptions("ModsLevel_Current"):CMod(400)
				ps:GetPlayerOptions("ModsLevel_Current"):Reverse(0)
			end
		end

		-- Notefield Customization
		local top = SCREENMAN:GetTopScreen()
		if top then
			-- Input Callback for Ghost Tapping feedback
			top:AddInputCallback(function(event)
				if event.type == "InputEventType_Release" then return end
				if event.type == "InputEventType_FirstPress" then
					local b = event.button
					local db = event.DeviceInput and event.DeviceInput.button or ""
					if db == "DeviceButton_tab" and INPUTFILTER and INPUTFILTER:IsControlPressed() then
						toggleMinimalisticModePreference()
						return true
					elseif db == "DeviceButton_tab" then
						toggleInGameLeaderboardPreference()
						return true
					end
					-- Filter for common gameplay buttons to avoid menu buttons triggering HUD animations
					if b == "Left" or b == "Down" or b == "Up" or b == "Right" or
					   b == "Key 1" or b == "Key 2" or b == "Key 3" or b == "Key 4" or
					   b == "Key 5" or b == "Key 6" or b == "Key 7" then
						MESSAGEMAN:Broadcast("GhostTap")
					end
				end
			end)

			local player = top:GetChild("PlayerP1")
			if player then
				local notefield = player:GetChild("NoteField")
				if notefield then
					local nfX = gameplayCoord("NotefieldX")
					local nfY = gameplayCoord("NotefieldY")
					local usingReverse = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions():UsingReverse()
					
					notefield:addx(nfX)
					notefield:addy(nfY * (usingReverse and 1 or -1))
					
					local cols = notefield:get_column_actors()
					local nfW = gameplaySize("NotefieldWidth")
					local nfH = gameplaySize("NotefieldHeight")
					local nfS = gameplaySize("NotefieldSpacing")
					
					for _, col in ipairs(cols) do
						col:zoomtowidth(nfW)
						col:zoomtoheight(nfH)
					end
					
					if setMovableNotefield then
						setMovableNotefield(notefield, cols)
						if spaceNotefieldCols then
							spaceNotefieldCols(nfS)
						end
					end
				end
			end
		end
	end,
	

	
	CurrentSongChangedMessageCommand = function(self)
		hideFallbackLifeBar()
		HV_RidiculousCount = 0
		-- Re-apply sync mods on every loop start to prevent engine resets
		if isSync then
			for _, pn_loop in ipairs(GAMESTATE:GetEnabledPlayers()) do
				local ps = GAMESTATE:GetPlayerState(pn_loop)
				local po = ps:GetPlayerOptions("ModsLevel_Preferred")
				po:CMod(400)
				po:Reverse(0)
				local co = ps:GetPlayerOptions("ModsLevel_Current")
				co:CMod(400)
				co:Reverse(0)
			end
		end
	end,
	
	-- Shared PointsLost Accumulator (Wife3 Adherent)
	-- Fully compliant with Etterna's internal wife3 scoring and evaluation mechanics
	JudgmentMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		
		-- Exclude non-tap judgements that don't affect points
		local s = params.TapNoteScore
		if params.HoldNoteScore or not s or s == "TapNoteScore_None" or s == "TapNoteScore_AvoidMine" or 
		   s == "TapNoteScore_CheckpointHit" or s == "TapNoteScore_CheckpointMiss" then
			return 
		end

		if s == "TapNoteScore_HitMine" then
			-- Match Etterna engine internal Wife3 rescoring logic (-350% weight = 7.0 points lost)
			HV_PointsLost = HV_PointsLost + 7.0
		elseif params.TapNoteOffset then
			local offset = math.abs(params.TapNoteOffset) * 1000
			local weight = wife3(offset, HV_JudgeScale, "Wife3")
			HV_PointsLost = HV_PointsLost + (2.0 - weight)
		elseif s == "TapNoteScore_Miss" then
			-- A full miss loses 7.5 points relative to the 2.0 potential max per tap (2.0 - (-5.5) = 7.5)
			HV_PointsLost = HV_PointsLost + 7.5
		end

		if isRidiculousJudgment(params) then
			HV_RidiculousCount = HV_RidiculousCount + 1
		end

		if s == "TapNoteScore_W2" then
			HV_AutoFailJudgeCounts.W2 = HV_AutoFailJudgeCounts.W2 + 1
		elseif s == "TapNoteScore_W3" then
			HV_AutoFailJudgeCounts.W3 = HV_AutoFailJudgeCounts.W3 + 1
		elseif s == "TapNoteScore_W4" then
			HV_AutoFailJudgeCounts.W4 = HV_AutoFailJudgeCounts.W4 + 1
		elseif s == "TapNoteScore_W5" then
			HV_AutoFailJudgeCounts.W5 = HV_AutoFailJudgeCounts.W5 + 1
		elseif s == "TapNoteScore_Miss" then
			HV_AutoFailJudgeCounts.Miss = HV_AutoFailJudgeCounts.Miss + 1
		end
		
		MESSAGEMAN:Broadcast("HV_PointsUpdate")
	end,

	HoldNoteScoreMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		-- The engine applies the hold penalty even if the head was completely missed
		if params.HoldNoteScore == "HoldNoteScore_LetGo" or params.HoldNoteScore == "HoldNoteScore_MissedHold" then
			HV_PointsLost = HV_PointsLost + 4.5
			MESSAGEMAN:Broadcast("HV_PointsUpdate")
		end
	end,
	
	RollNoteScoreMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		if params.RollNoteScore == "RollNoteScore_LetGo" or params.RollNoteScore == "RollNoteScore_MissedRoll" then
			HV_PointsLost = HV_PointsLost + 4.5
			MESSAGEMAN:Broadcast("HV_PointsUpdate")
		end
	end,
	PlayingUpdateMessageCommand = function(self)
		hideFallbackLifeBar()
	end
}

t[#t + 1] = Def.Actor {
	Name = "FailSoundController",
	CurrentSongChangedMessageCommand = function(self)
		failSfxPlayed = false
		HV_AutoFailJudgeCounts = { W2 = 0, W3 = 0, W4 = 0, W5 = 0, Miss = 0 }
		HV_RidiculousCount = 0
	end,
	PlayingUpdateMessageCommand = function(self)
		if failSfxPlayed then return end
		local top = SCREENMAN:GetTopScreen()
		if not top or not top.GetLifeMeter then return end
		local lifeMeter = top:GetLifeMeter(pn)
		if not lifeMeter or not lifeMeter.GetLife then return end
		local life = lifeMeter:GetLife() or 0
		if life <= 0 then
			PlayFailSfxOnce()
		end
	end,
}

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")

local judgmentColors = {
	HVColor.GetJudgmentColor("W1"),
	HVColor.GetJudgmentColor("W2"),
	HVColor.GetJudgmentColor("W3"),
	HVColor.GetJudgmentColor("W4"),
	HVColor.GetJudgmentColor("W5"),
	HVColor.GetJudgmentColor("Miss")
}
local judgmentLabels = {
	THEME:GetString("TapNoteScore", "W1"),
	THEME:GetString("TapNoteScore", "W2"),
	THEME:GetString("TapNoteScore", "W3"),
	THEME:GetString("TapNoteScore", "W4"),
	THEME:GetString("TapNoteScore", "W5"),
	THEME:GetString("TapNoteScore", "Miss")
}

local judgmentTNS = {
	"TapNoteScore_W1", "TapNoteScore_W2", "TapNoteScore_W3",
	"TapNoteScore_W4", "TapNoteScore_W5", "TapNoteScore_Miss"
}

if HV.EmulateRidiculousEnabled() then
	table.insert(judgmentColors, 1, HVColor.GetJudgmentColor("Ridiculous"))
	table.insert(judgmentLabels, 1, THEME:GetString("TapNoteScore", "Ridiculous"))
	table.insert(judgmentTNS, 1, "Ridiculous")
end

local function getGameplayJudgmentCount(pss, judgeName)
	if judgeName == "Ridiculous" then return HV_RidiculousCount end
	local count = pss:GetTapNoteScores(judgeName)
	if judgeName == "TapNoteScore_W1" and HV.EmulateRidiculousEnabled() then
		count = count - HV_RidiculousCount
	end
	return count
end

-- ============================================================
-- FRAME UPDATER (for time-based elements: life bar, progress bar)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		self:SetUpdateFunction(function(self)
			-- Lifebar still uses this for now
			MESSAGEMAN:Broadcast("PlayingUpdate")
		end)
	end,

	-- NoteMask for Sync Mode (placed here to be below judgments/combo)
	Def.Quad {
		Name = "SyncNoteMask",
		InitCommand = function(self)
			self:Center():zoomto(SCREEN_WIDTH * 0.4, SCREEN_HEIGHT)
				:diffuse(color("0,0,0,1")):diffusealpha(0)
				:visible(isSync)
		end,
		SyncTriggeredMessageCommand = function(self)
			self:linear(2):diffusealpha(1)
		end,
		CurrentSongChangedMessageCommand = function(self)
			self:stoptweening():diffusealpha(0)
		end
	}
}

-- ============================================================
-- SONG PROGRESS BAR (TOP of screen)
-- ============================================================
local progressBarPosition = HV.GetProgressBarPosition()
local barW = SCREEN_WIDTH * 0.4
local barH = 6
local barY = progressBarPosition == "Top" and 12 or (progressBarPosition == "Bottom" and SCREEN_BOTTOM - 12 or 12)

local showProgressBar = progressBarPosition ~= "Off" and not isSync

-- Load cursor system for mouse button support (required for practice_input.lua QuadButton)
t[#t + 1] = LoadActor("../_cursor")
t[#t + 1] = LoadActor("practice_input.lua")

if showProgressBar then
t[#t + 1] = Def.ActorFrame {
	Name = "ProgressBarContainer",
	InitCommand = function(self)
		self:xy(gameplayCoord("FullProgressBarX"), gameplayCoord("FullProgressBarY"))
		self:visible(minimalisticHUDVisible(showProgressBar))
	end,
	HV_MinimalisticModeChangedMessageCommand = function(self, params)
		animateGameplayHUDVisibility(self, minimalisticHUDVisible(showProgressBar, params and params.Enabled))
	end,
	OnCommand = function(self)
		setMovableActor({"DeviceButton_9"}, self, self:GetChild("Border"))
	end,
	BeginCommand = function(self)
		self:SetUpdateFunction(function(self)
			self:playcommand("UpdateBars")
		end)
	end,
	Def.Quad {
		Name = "ProgressBarBG",
		InitCommand = function(self)
			self:zoomto(barW, barH):diffuse(color("0,0,0,0.2"))
		end
	},

	Def.Quad {
		Name = "ProgressFill",
		InitCommand = function(self)
			self:halign(0):x(-barW / 2)
				:zoomto(0, barH):diffuse(accentColor):diffusealpha(0.7)
		end,
		UpdateBarsCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local steps = GAMESTATE:GetCurrentSteps()
				local len = getChartLastSecond(song, steps)
				if len > 0 then
					local cur = GAMESTATE:GetSongPosition():GetMusicSeconds()
					local pct = math.max(0, math.min(cur / len, 1))
					self:zoomto(barW * pct, barH)
				end
			end
		end
	},

	-- Remaining Time (incorporating music rate and ms)
	LoadFont("Common Normal") .. {
		Name = "TimeRemaining",
		InitCommand = function(self)
			self:x(barW / 2 + 8):zoom(0.35):halign(0):diffuse(dimText)
		end,
		UpdateBarsCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local steps = GAMESTATE:GetCurrentSteps()
				local songLen = getChartLastSecond(song, steps)
				local curTime = GAMESTATE:GetSongPosition():GetMusicSeconds()
				local remaining = math.max(0, songLen - curTime) / getCurRateValue()
				local mins = math.floor(remaining / 60)
				local secs = math.floor(remaining % 60)
				local ms = math.floor((remaining - math.floor(remaining)) * 100)
				self:settext(string.format("-%d:%02d.%02d", mins, secs, ms))
			end
		end
	},

	-- Elapsed Time (incorporating music rate and ms)
	LoadFont("Common Normal") .. {
		Name = "TimeElapsed",
		InitCommand = function(self)
			self:x(-barW / 2 - 8):zoom(0.35):halign(1):diffuse(subText)
		end,
		UpdateBarsCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local curTime = math.max(0, GAMESTATE:GetSongPosition():GetMusicSeconds()) / getCurRateValue()
				local mins = math.floor(curTime / 60)
				local secs = math.floor(curTime % 60)
				local ms = math.floor((curTime - math.floor(curTime)) * 100)
				self:settext(string.format("%d:%02d.%02d", mins, secs, ms))
			end
		end,

	}
	,
	MovableBorder(barW, 16, 1, 0, 0)
}
end -- End progress bar visibility check

-- ============================================================
-- SCORE % (REAL-TIME)
-- ============================================================
local showCurrentWife = HV.ShowCurrentWife() and not isSync

if showCurrentWife then
t[#t + 1] = Def.ActorFrame {
	Name = "CenteredScore",
	InitCommand = function(self)
		self:xy(gameplayCoord("DisplayPercentX"), gameplayCoord("DisplayPercentY")):zoom(gameplaySize("DisplayPercentZoom")):diffusealpha(0.8)
		self:visible(minimalisticHUDVisible(showCurrentWife))
	end,
	HV_MinimalisticModeChangedMessageCommand = function(self, params)
		animateGameplayHUDVisibility(self, minimalisticHUDVisible(showCurrentWife, params and params.Enabled))
	end,
	OnCommand = function(self)
		setMovableActor({"DeviceButton_w", "DeviceButton_e"}, self, self:GetChild("Border"))
	end,

	LoadFont("Common Normal") .. {
		Name = "ScoreValue",
		InitCommand = function(self)
			self:zoom(0.45):diffuse(brightText):diffusealpha(0.7)
			self.currWifePoints = 0
			self.currScoredTaps = 0
			local scoreMode = ThemePrefs.Get("HV_ScoreDisplayMode") or "Normal"
			if scoreMode == "Subtractive" then
				self:settext("100.0000%")
			else
				self:settext("0.0000%")
			end
		end,
		OnCommand = function(self)
			self:queuecommand("UpdateAutoplay")
		end,
		UpdateAutoplayCommand = function(self)
			if getAutoplay and getAutoplay() ~= 0 then
				self:queuecommand("Update")
			end
			self:sleep(0.05):queuecommand("UpdateAutoplay")
		end,
		JudgmentMessageCommand = function(self, msg)
			if msg.Player ~= GAMESTATE:GetMasterPlayerNumber() then return end
			if msg.HoldNoteScore then return end -- Skip holds, handled in HoldNoteScoreMessageCommand
			if msg.TapNoteScore and msg.TapNoteScore ~= "TapNoteScore_AvoidMine" and msg.TapNoteScore ~= "TapNoteScore_CheckpointHit" and msg.TapNoteScore ~= "TapNoteScore_CheckpointMiss" then
				if msg.TapNoteOffset then
					self.currWifePoints = self.currWifePoints + wife3(math.abs(msg.TapNoteOffset) * 1000, HV_JudgeScale, "Wife3")
					self.currScoredTaps = self.currScoredTaps + 1
				elseif msg.TapNoteScore == "TapNoteScore_Miss" then
					self.currWifePoints = self.currWifePoints - 5.5
					self.currScoredTaps = self.currScoredTaps + 1
				elseif msg.TapNoteScore == "TapNoteScore_HitMine" then
					self.currWifePoints = self.currWifePoints - 7.0
				elseif msg.TapNoteScore ~= "TapNoteScore_None" then
					self.currWifePoints = self.currWifePoints + 2.0
					self.currScoredTaps = self.currScoredTaps + 1
				end
			end
			self:playcommand("Update")
		end,
		HoldNoteScoreMessageCommand = function(self, msg)
			if msg.Player ~= GAMESTATE:GetMasterPlayerNumber() then return end
			-- The engine applies the hold penalty even if the head was completely missed
			if msg.HoldNoteScore == "HoldNoteScore_LetGo" or msg.HoldNoteScore == "HoldNoteScore_MissedHold" then
				self.currWifePoints = self.currWifePoints - 4.5
				self:playcommand("Update")
			end
		end,
		RollNoteScoreMessageCommand = function(self, msg)
			if msg.Player ~= GAMESTATE:GetMasterPlayerNumber() then return end
			if msg.RollNoteScore == "RollNoteScore_LetGo" or msg.RollNoteScore == "RollNoteScore_MissedRoll" then
				self.currWifePoints = self.currWifePoints - 4.5
				self:playcommand("Update")
			end
		end,
		HV_PointsUpdateMessageCommand = function(self)
			self:playcommand("Update")
		end,
		UpdateCommand = function(self)
			local wifePct
			local scoreMode = ThemePrefs.Get("HV_ScoreDisplayMode") or "Normal"
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			local isAutoplay = getAutoplay and getAutoplay() ~= 0
			
			if isAutoplay and pss then
				local notesPassed = pss:GetTapNoteScores("TapNoteScore_W1") +
								   pss:GetTapNoteScores("TapNoteScore_W2") +
								   pss:GetTapNoteScores("TapNoteScore_W3") +
								   pss:GetTapNoteScores("TapNoteScore_W4") +
								   pss:GetTapNoteScores("TapNoteScore_W5") +
								   pss:GetTapNoteScores("TapNoteScore_Miss")
				local currentMaxPoints = notesPassed * 2
				if currentMaxPoints > 0 and type(pss.GetWifePoints) == "function" then
					local ok, value = pcall(pss.GetWifePoints, pss)
					value = ok and tonumber(value) or nil
					if value then wifePct = math.min((value / currentMaxPoints) * 100, 100) end
				end
				if not wifePct and type(pss.GetWifeScore) == "function" then
					local ok, value = pcall(pss.GetWifeScore, pss)
					value = ok and tonumber(value) or nil
					if value then wifePct = value * 100 end
				end
			elseif scoreMode == "Subtractive" then
				wifePct = ((HV_MaxPoints - HV_PointsLost) / HV_MaxPoints) * 100
			else
				if pss then
					local currentMaxPoints = self.currScoredTaps * 2
					if currentMaxPoints > 0 then
						local raw = (self.currWifePoints / currentMaxPoints) * 100
						wifePct = math.min(raw, 100)
					elseif self.currWifePoints < 0 then
						wifePct = (self.currWifePoints / 2) * 100
					else
						wifePct = 100.0000
					end
				end
			end			
			if not wifePct then return end
			self:settext(string.format("%.4f%%", wifePct))
			
			-- Use standard Etterna grade tiers and theme colors
			local tier = getEtternaGrade(wifePct)
			self:diffuse(HVColor.GetGradeColor(tier)):diffusealpha(0.7)
		end,

	}
	,
	MovableBorder(110, 20, 1, 0, 0)
}
end

-- ============================================================
-- GOAL TRACKER
-- ============================================================
local showGoalTrackerText = HV.ShowGoalTrackerText() and not isSync
if showGoalTrackerText then
	local pacemakerMode = ThemePrefs.Get("HV_PacemakerTargetType")
	if not pacemakerMode or pacemakerMode == "" then pacemakerMode = "Target" end

	local targetGoalPref = ThemePrefs.Get("HV_PacemakerTargetGoal")
	local targetGoalPct = tonumber(targetGoalPref) or 93
	local targetGoal = targetGoalPct / 100

	-- Set the engine-side target goal and replay mode
	GAMESTATE:GetPlayerState():SetTargetGoal(targetGoal)
	GAMESTATE:GetPlayerState():SetGoalTrackerUsesReplay(pacemakerMode == "PBReplay")

	t[#t + 1] = Def.ActorFrame {
		Name = "TextPacemaker",
		InitCommand = function(self)
			self:xy(gameplayCoord("TargetTrackerX"), gameplayCoord("TargetTrackerY")):zoom(gameplaySize("TargetTrackerZoom"))
			self:visible(minimalisticHUDVisible(showGoalTrackerText))
		end,
		HV_MinimalisticModeChangedMessageCommand = function(self, params)
			animateGameplayHUDVisibility(self, minimalisticHUDVisible(showGoalTrackerText, params and params.Enabled))
		end,
		OnCommand = function(self)
			setMovableActor({"DeviceButton_7", "DeviceButton_8"}, self, self:GetChild("Border"))
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0.5):zoom(0.35)
				self:settextf("%+5.2f (%5.2f%%)", 0, targetGoalPct)
				self:diffuse(HVColor.GetGoalTrackerColor("positive"))
			end,
			JudgmentMessageCommand = function(self, msg)
				self.msg = msg
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local msg = self.msg
				if not msg then return end
				local tDiff = msg.WifeDifferential
				local displayTarget = targetGoalPct

				-- In PB or PB Replay mode, use the PB goal/differential if available
				if (pacemakerMode == "PB" or pacemakerMode == "PBReplay") and msg.WifePBGoal ~= nil then
					tDiff = msg.WifePBDifferential
					displayTarget = msg.WifePBGoal * 100
				end

				if tDiff and tDiff >= 0 then
					self:diffuse(HVColor.GetGoalTrackerColor("positive"))
				else
					self:diffuse(HVColor.GetGoalTrackerColor("negative"))
				end
				self:settextf("%+5.2f (%5.2f%%)", tDiff or 0, displayTarget)
			end,

		}
		,
		MovableBorder(130, 18, 1, 0, 0)
	}
end

-- ============================================================
-- NOTEFIELD MEAN DISPLAY
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "NotefieldMean",
	InitCommand = function(self)
		self:xy(gameplayCoord("DisplayMeanX"), gameplayCoord("DisplayMeanY")):zoom(gameplaySize("DisplayMeanZoom")):diffusealpha(0)
		-- Check if notefield stat should be shown
		local statType = HV.GetNotefieldStat()
		local showStat = statType ~= "Off" and not isSync
		self.HVBaseVisible = showStat
		self:visible(minimalisticHUDVisible(showStat))
	end,
	HV_MinimalisticModeChangedMessageCommand = function(self, params)
		animateGameplayHUDVisibility(self, minimalisticHUDVisible(self.HVBaseVisible, params and params.Enabled))
	end,
	OnCommand = function(self)
		setMovableActor({"DeviceButton_m", "DeviceButton_comma"}, self, self:GetChild("Border"))
		self:linear(0.2):diffusealpha(0.8)
	end,

		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:zoom(0.35):diffuse(mainText)
				local statType = HV.GetNotefieldStat()
				self.statType = statType
				self.currWifePoints = 0
				self.leftOffsetSumMs = 0
				self.leftOffsetCount = 0
				self.rightOffsetSumMs = 0
				self.rightOffsetCount = 0
				self.middleOffsetSumMs = 0
				self.middleOffsetCount = 0
				if statType == "J4" then
					self:settext("100.0000%")
				elseif statType == "MARatio" then
					self:settext("0.00:1")
				elseif statType == "DeltaHand" then
					self:settext("0.0000%")
				else
					self:settext("0.00ms")
				end
			end,
			JudgmentMessageCommand = function(self, msg)
				if msg.Player ~= GAMESTATE:GetMasterPlayerNumber() then return end
				if msg.HoldNoteScore then return end -- Skip holds, handled in HoldNoteScoreMessageCommand
				if self.statType == "J4" then
					if msg.TapNoteScore and msg.TapNoteScore ~= "TapNoteScore_AvoidMine" and msg.TapNoteScore ~= "TapNoteScore_CheckpointHit" then
						local ts = ms.JudgeScalers[4] or 1.0
						if msg.TapNoteOffset then
							self.currWifePoints = self.currWifePoints + wife3(math.abs(msg.TapNoteOffset) * 1000, ts, "Wife3")
						elseif msg.TapNoteScore == "TapNoteScore_Miss" then
							self.currWifePoints = self.currWifePoints - 5.5
						elseif msg.TapNoteScore == "TapNoteScore_HitMine" then
							self.currWifePoints = self.currWifePoints - 7.0
						elseif msg.TapNoteScore ~= "TapNoteScore_None" then
							self.currWifePoints = self.currWifePoints + 2.0
						end
					end
				elseif self.statType == "DeltaHand" then
					if msg.TapNoteOffset and msg.TapNoteScore and msg.TapNoteScore ~= "TapNoteScore_AvoidMine" and msg.TapNoteScore ~= "TapNoteScore_CheckpointHit" then
						local track = msg.FirstTrack
						if track == nil then track = msg.Track end
						if track ~= nil then
							local judge = (PREFSMAN:GetPreference("SortBySSRNormPercent") and 4) or GetTimingDifficulty()
							local ts = (ms.JudgeScalers and ms.JudgeScalers[judge]) or 1.0
							local pts = wife3(math.abs(msg.TapNoteOffset) * 1000, ts, "Wife3")

							local cols = 4
							local style = GAMESTATE:GetCurrentStyle()
							if style and style.ColumnsPerPlayer then cols = style:ColumnsPerPlayer() end
							local middleColumn = (cols - 1) / 2.0

							if track < middleColumn then
								self.leftOffsetSumMs = self.leftOffsetSumMs + pts
								self.leftOffsetCount = self.leftOffsetCount + 1
							elseif track > middleColumn then
								self.rightOffsetSumMs = self.rightOffsetSumMs + pts
								self.rightOffsetCount = self.rightOffsetCount + 1
							else
								-- Middle column (odd keymodes)
								self.middleOffsetSumMs = (self.middleOffsetSumMs or 0) + pts
								self.middleOffsetCount = (self.middleOffsetCount or 0) + 1
							end
						end
					end
				end
				self:queuecommand("Update")
			end,
			HoldNoteScoreMessageCommand = function(self, msg)
				if msg.Player ~= GAMESTATE:GetMasterPlayerNumber() then return end
				if self.statType == "J4" then
					-- The engine applies the hold penalty even if the head was completely missed
					if msg.HoldNoteScore == "HoldNoteScore_LetGo" or msg.HoldNoteScore == "HoldNoteScore_MissedHold" then
						self.currWifePoints = self.currWifePoints - 4.5
					end
				end
				self:queuecommand("Update")
			end,
			RollNoteScoreMessageCommand = function(self, msg)
				if msg.Player ~= GAMESTATE:GetMasterPlayerNumber() then return end
				if self.statType == "J4" then
					if msg.RollNoteScore == "RollNoteScore_LetGo" or msg.RollNoteScore == "RollNoteScore_MissedRoll" then
						self.currWifePoints = self.currWifePoints - 4.5
					end
				end
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if not pss then return end
				local ps = GAMESTATE:GetPlayerState(pn)

				if self.statType == "J4" then
					local notesPassed = pss:GetTapNoteScores("TapNoteScore_W1") +
									   pss:GetTapNoteScores("TapNoteScore_W2") +
									   pss:GetTapNoteScores("TapNoteScore_W3") +
									   pss:GetTapNoteScores("TapNoteScore_W4") +
									   pss:GetTapNoteScores("TapNoteScore_W5") +
									   pss:GetTapNoteScores("TapNoteScore_Miss")
					local maxPoints = notesPassed * 2
					if maxPoints > 0 then
						local j4 = math.min((self.currWifePoints / maxPoints) * 100, 100)
						self:settextf("%.4f%%", j4)
					elseif self.currWifePoints < 0 then
						-- Show penalty relative to total song max points until first tap
						local raw = (HV_MaxPoints + self.currWifePoints) / HV_MaxPoints
						self:settextf("%.4f%%", raw * 100)
					else
						self:settext("0.0000%")
					end
				elseif self.statType == "StdDev" then
					local dvt = pss:GetOffsetVector()
					if dvt and #dvt > 0 then
						self:settextf("%.2fms", wifeSd(dvt))
					end
				elseif self.statType == "MARatio" then
					local marv = pss:GetTapNoteScores("TapNoteScore_W1") or 0
					local perf = pss:GetTapNoteScores("TapNoteScore_W2") or 0
					if perf > 0 then
						self:settextf("%.2f:1", marv / perf)
					elseif marv > 0 then
						self:settext("∞")
					else
						self:settext("0.00:1")
					end
				elseif self.statType == "DeltaHand" then
					local cols = 4
					local style = GAMESTATE:GetCurrentStyle()
					if style and style.ColumnsPerPlayer then cols = style:ColumnsPerPlayer() end
					local oddColumns = (cols % 2) ~= 0

					local leftTaps, rightTaps = self.leftOffsetCount or 0, self.rightOffsetCount or 0
					local middleTaps = self.middleOffsetCount or 0
					local leftScore = leftTaps > 0 and (self.leftOffsetSumMs / (leftTaps * 2)) or 0
					local rightScore = rightTaps > 0 and (self.rightOffsetSumMs / (rightTaps * 2)) or 0
					local middleScore = middleTaps > 0 and ((self.middleOffsetSumMs or 0) / (middleTaps * 2)) or 0

					if oddColumns then
						if leftTaps == 0 and rightTaps == 0 and middleTaps == 0 then
							self:settext("0.0000%")
						else
							local scores = {L = leftScore, M = middleScore, R = rightScore}
							local minScore = math.min(leftScore, middleScore, rightScore)
							local maxScore = math.max(leftScore, middleScore, rightScore)
							local delta = (maxScore - minScore) * 100
							local sorted = {"L", "M", "R"}
							table.sort(sorted, function(a, b) return scores[a] > scores[b] end)
							local symbol = table.concat(sorted, ">")
							self:settextf("%s %.4f%%", symbol, delta)
						end
					else
						if leftTaps > 0 and rightTaps > 0 then
							local delta = math.abs(leftScore - rightScore) * 100
							local symbol = leftScore > rightScore and "> " or "< "
							self:settextf("%s%.4f%%", symbol, delta)
						else
							self:settext("0.0000%")
						end
					end
				else
					local dvt = pss:GetOffsetVector()
					if dvt and #dvt > 0 then
						self:settextf("%.2fms", wifeMean(dvt))
					end
				end
			end,
			PracticeModeResetMessageCommand = function(self)
				self.currWifePoints = 0
				self.leftOffsetSumMs, self.leftOffsetCount = 0, 0
				self.rightOffsetSumMs, self.rightOffsetCount = 0, 0
				self.middleOffsetSumMs, self.middleOffsetCount = 0, 0
				self:queuecommand("Update")
			end,
			PracticeModeReloadMessageCommand = function(self)
				self.currWifePoints = 0
				self.leftOffsetSumMs, self.leftOffsetCount = 0, 0
				self.rightOffsetSumMs, self.rightOffsetCount = 0, 0
				self.middleOffsetSumMs, self.middleOffsetCount = 0, 0
				self:queuecommand("Update")
			end
		
		},
		MovableBorder(100, 18, 1, 0, 0)
	}

-- ============================================================
-- CENTERED COMBO / MISS COMBO
-- ============================================================
local showCombo = HV.ShowCombo()

if showCombo then
t[#t + 1] = Def.ActorFrame {
	Name = "ComboDisplay",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X + gameplayCoord("ComboX"), SCREEN_CENTER_Y + gameplayCoord("ComboY")):zoom(gameplaySize("ComboZoom"))
		self.comboBreaks = 0
		self:visible(minimalisticHUDVisible(showCombo))
	end,
	HV_MinimalisticModeChangedMessageCommand = function(self, params)
		animateGameplayHUDVisibility(self, minimalisticHUDVisible(showCombo, params and params.Enabled))
	end,
	OnCommand = function(self)
		setMovableActor({"DeviceButton_3", "DeviceButton_4"}, self, self:GetChild("Border"))
	end,

	LoadFont("combo/_mochiy pop one 24px") .. {
		Name = "ComboNumber",
		InitCommand = function(self)
			self:zoom(0.75):diffuse(brightText):y(-4)
			self:settext("0"):shadowlength(1.5):shadowcolor(color("0,0,0,1"))
		end
	},

	Def.ActorFrame {
		Name = "ComboLabel",
		InitCommand = function(self)
			self:y(16)
		end,

		-- Graphic for "Combo"
		Def.Sprite {
			Name = "ComboGraphic",
			Texture = THEME:GetPathG("", "combo_label.png"),
			InitCommand = function(self)
				self:zoom(0.25):diffuse(subText):visible(true)
			end
		},

		-- Text for "Misses" (fallback if no graphic, or for text-specific label)
		LoadFont("Common Normal") .. {
			Name = "MissesText",
			InitCommand = function(self)
				self:zoom(0.22):diffuse(color("#FF5050")):visible(false)
				self:settext(THEME:GetString("ScreenGameplay", "Misses"))
			end
		}
	},

	JudgmentMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		if not pss then return end

		-- Synchronously calculate consecutive combo breaks 
		-- This prevents C++ CNote jumps from overwriting 'Update' queue params resulting in total missed sums
		if not params.HoldNoteScore and params.TapNoteScore then
			local tns = params.TapNoteScore
			if tns == "TapNoteScore_Miss" or tns == "TapNoteScore_W5" or tns == "TapNoteScore_W4" then
				self.comboBreaks = self.comboBreaks + 1
			elseif tns == "TapNoteScore_W1" or tns == "TapNoteScore_W2" or tns == "TapNoteScore_W3" then
				self.comboBreaks = 0
			end
		end

		-- Apply Combo Animation if enabled
		-- Triggering here avoids Engine race conditions on key release
		if HV.ComboAnimation and HV.ComboAnimation() then
			-- Avoid 1.3 zoom mistakenly triggering on hold releases
			if not params.HoldNoteScore then
				local tns = params.TapNoteScore
				if tns and tns ~= "TapNoteScore_None" and tns ~= "TapNoteScore_Miss" and tns ~= "TapNoteScore_HitMine" and tns ~= "TapNoteScore_AvoidMine" and tns ~= "TapNoteScore_CheckpointHit" and tns ~= "TapNoteScore_CheckpointMiss" then
					if pss:GetCurrentCombo() > 0 then
						self.lastHitTime = GetTimeSinceStart()
						self:stoptweening():zoom(1.3):linear(0.05):zoom(1.0)
					end
				end
			end
		end
		
		-- Redraw miss UI if combo is 0 (as combo=0 judgments don't reliably trigger ComboChanged per C++ implementation)
		if pss:GetCurrentCombo() == 0 then
			local numActor = self:GetChild("ComboNumber")
			local labelContainer = self:GetChild("ComboLabel")
			local graphic = labelContainer:GetChild("ComboGraphic")
			local text = labelContainer:GetChild("MissesText")
			
			if self.comboBreaks >= 5 then
				numActor:settext(tostring(self.comboBreaks)):diffuse(color("#FF5050")):shadowlength(0)
				graphic:visible(false)
				text:visible(true):settext(THEME:GetString("ScreenGameplay", "Misses"))
			else
				numActor:settext("0"):diffuse(dimText):shadowlength(0)
				graphic:visible(true):diffusealpha(0.5)
				text:visible(false)
			end
		end
	end,

	ComboChangedMessageCommand = function(self, params)
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		if not pss then return end

		local combo = pss:GetCurrentCombo()
		local numActor = self:GetChild("ComboNumber")
		local labelContainer = self:GetChild("ComboLabel")
		local graphic = labelContainer:GetChild("ComboGraphic")
		local text = labelContainer:GetChild("MissesText")

		if combo > 0 then
			local totalNotes = getMaxNotes(PLAYER_1) or 1
			local threshold = math.floor(totalNotes * 0.25)
			local ct = getDetailedClearType(pss)
			local ctColor = getClearTypeColor(ct)
			
			numActor:settext(tostring(combo)):diffuse(brightText)
			
			-- Shadow display logic: 25% threshold + No combo breaks (FC status so far)
			local isFC = (ct ~= "MF" and ct ~= "SDCB" and ct ~= "Clear" and ct ~= "Failed")
			
			if combo >= threshold and isFC then
				numActor:shadowcolor(ctColor)
				numActor:shadowlength(1.5) -- Improved visibility
			else
				numActor:shadowlength(0)
			end
			
			graphic:visible(true):diffusealpha(1)
			text:visible(false)
		elseif self.comboBreaks < 5 then
			numActor:settext("0"):diffuse(dimText):shadowlength(0)
			graphic:visible(true):diffusealpha(0.5)
			text:visible(false)
		end
	end,

	GhostTapMessageCommand = function(self)
		if HV.ComboAnimation and HV.ComboAnimation() then
			-- Prevent Ghost Tap from overriding the 1.3 zoom from a valid hit
			if self.lastHitTime and GetTimeSinceStart() - self.lastHitTime < 0.05 then return end
			self:stoptweening():zoom(1.08):linear(0.05):zoom(1.0)
		end
	end,

	MovableBorder(120, 40, 1, 0, 0),
}
end -- End combo visibility check

-- ============================================================
-- COMBO BREAK LANE HIGHLIGHT
-- ============================================================
local showComboBreakHighlight = HV.ComboBreakHighlight() and not isSync

if showComboBreakHighlight then

-- Helper: build a gradient AMV lane quad.
-- xOffset: lane center X (relative to parent ActorFrame at SCREEN_CENTER)
-- laneW: lane pixel width
-- The quad spans from y=0 (screen center, top of highlight, transparent)
--   to y=SCREEN_HEIGHT/2 (receptor area, bottom, opaque at flash time).
-- Vertices are ordered: TL, TR, BR, BL (quad strip).
local function makeCBLane(name, xOffset, laneW)
	local halfW   = laneW / 2
	-- The parent frame sits at SCREEN_CENTER_Y.
	-- Receptors are near SCREEN_BOTTOM, so the opaque end of the gradient
	-- is SCREEN_HEIGHT/2 pixels below the frame origin (positive Y = down).
	-- 80% height means topY = (bottomY) - (0.8 * SCREEN_HEIGHT) = -0.3 * SCREEN_HEIGHT
	local topY    = -SCREEN_HEIGHT * 0.3 -- 80% height highlight
	local bottomY = SCREEN_HEIGHT / 2    -- receptor area       → opaque at flash peak

	return Def.ActorMultiVertex {
		Name = name,
		InitCommand = function(self)
			self:x(xOffset)
			-- Pre-set vertices with the desired gradient (peak alpha handled in FlashCommand)
			self:SetVertices({
				{{-halfW, topY,    0}, {1, 1, 1, 0}}, -- TL
				{{ halfW, topY,    0}, {1, 1, 1, 0}}, -- TR
				{{ halfW, bottomY, 0}, {1, 1, 1, 1}}, -- BR
				{{-halfW, bottomY, 0}, {1, 1, 1, 1}}, -- BL
			})
			self:SetDrawState({Mode="DrawMode_Quads", First=1, Num=4})
			self:diffusealpha(0)
		end,
		FlashCommand = function(self, params)
			local c = params and params.color or color("#FF5050")
			self:stoptweening()
			self:diffuse(c)
			
			-- Instant snap to a clearer peak (0.35) and a single linear fade-out.
			-- This avoids the "snapping to dim" feeling of the dual-ramp approach.
			self:diffusealpha(0.35)
			self:linear(0.70)
			self:diffusealpha(0)
		end
	}
end

t[#t + 1] = Def.ActorFrame {
	Name = "ComboBreakHighlight",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
		self:visible(minimalisticHUDVisible(showComboBreakHighlight))
	end,
	HV_MinimalisticModeChangedMessageCommand = function(self, params)
		animateGameplayHUDVisibility(self, minimalisticHUDVisible(showComboBreakHighlight, params and params.Enabled))
	end,

	-- 4 gradient lane highlights for standard 4K (64px wide, spaced 64px apart)
	makeCBLane("Lane1", -96, 64),
	makeCBLane("Lane2", -32, 64),
	makeCBLane("Lane3",  32, 64),
	makeCBLane("Lane4",  96, 64),

	JudgmentMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		if not params.TapNoteScore then return end

		-- Flash on combo-breaking judgments
		local isComboBreak = (params.TapNoteScore == "TapNoteScore_Miss" or
							  params.TapNoteScore == "TapNoteScore_W5" or
							  params.TapNoteScore == "TapNoteScore_W4")

		if isComboBreak and params.Notes then
			local jColor = color("#FF5050")
			if params.TapNoteScore == "TapNoteScore_W4" then jColor = HVColor.GetJudgmentColor("W4")
			elseif params.TapNoteScore == "TapNoteScore_W5" then jColor = HVColor.GetJudgmentColor("W5")
			elseif params.TapNoteScore == "TapNoteScore_Miss" then jColor = HVColor.GetJudgmentColor("Miss") end

			-- Flash lanes that had notes in this judgment
			for i = 1, 4 do
				if params.Notes[i] ~= nil then
					local lane = self:GetChild("Lane" .. i)
					if lane then
						lane:playcommand("Flash", {color=jColor})
					end
				end
			end
		end
	end
}
end -- End combo break highlight


t[#t + 1] = Def.ActorFrame {
	Name = "IndicatorFrame",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, barY + 15):visible(GAMESTATE:IsPracticeMode())
	end,
	LoadFont("Common Normal") .. {
		Text = "** PRACTICE MODE **",
		InitCommand = function(self) self:zoom(0.35):diffuse(accentColor):diffusealpha(0.8) end
	}
}

t[#t + 1] = LoadActor("replayscrolling.lua")

-- ============================================================
-- ERROR BAR (TIMING BAR)
-- ============================================================
local baseEBW = 240
local ebW = baseEBW * gameplaySize("ErrorBarScale")
local ebH = 2
local ebCenterY = SCREEN_CENTER_Y + SCREEN_HEIGHT * 0.15 - 40
local maxOffset = 180 -- ms
local dotLife = 2.0  -- seconds

-- EWMA state
local ewmaValue = 0
local ewmaAlpha = 0.07
local ebMode = ThemePrefs.Get("HV_ErrorBarMode") or "Standard"
local showEWMA = (ebMode == "EWMAOnly" or ebMode == "Both")
local showStandard = (ebMode == "Standard" or ebMode == "Both")

	t[#t + 1] = Def.ActorFrame {
		Name = "ErrorBar",
		InitCommand = function(self)
			local ebMode = ThemePrefs.Get("HV_ErrorBarMode") or "Standard"
			self:xy(gameplayCoord("ErrorBarX"), gameplayCoord("ErrorBarY")):visible(ebMode ~= "Off" and not isSync)
		end,
		OnCommand = function(self)
			setMovableActor({"DeviceButton_5", "DeviceButton_6"}, self, self:GetChild("Border"))
		end,
		UpdateEBScaleCommand = function(self, params)
			ebW = baseEBW * params.scale
			self:GetChild("Border"):playcommand("ChangeWidth", {val = ebW})
			self:playcommand("UpdateChildrenEBWidth", {width = ebW})
		end,

	-- Background line
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(ebW, ebH):visible(false)
		end
	},

	-- Center Line (0ms)
	Def.Quad {
		Name = "CenterLine",
		InitCommand = function(self)
			self:zoomto(1, ebH + 8):diffuse(color("1,1,1,0.3"))
		end,
		UpdateChildrenEBWidthCommand = function(self, params)
			-- center line doesn't change size usually but we can react if needed
		end
	},
	
	-- Judgement window highlights (only visible when resizing)
	Def.ActorFrame {
		Name = "Highlights",
		InitCommand = function(self)
			self:visible(false)
		end,
		MovableUpdatedMessageCommand = function(self, params)
			local ebMode = ThemePrefs.Get("HV_ErrorBarMode") or "Standard"
			local isVisible = params and (params.button == "DeviceButton_6") and (ebMode ~= "Off")
			self:visible(isVisible or false)
		end,
		(function()
			local g = Def.ActorFrame{}
			local windows = {180, 135, 90, 45, 22.5}
			local colors = {
				HVColor.GetJudgmentColor("W5"),
				HVColor.GetJudgmentColor("W4"),
				HVColor.GetJudgmentColor("W3"),
				HVColor.GetJudgmentColor("W2"),
				HVColor.GetJudgmentColor("W1")
			}
			if HV.EmulateRidiculousEnabled() then
				table.insert(windows, 11.25 * (tonumber(HV_JudgeScale) or 1))
				table.insert(colors, HVColor.GetJudgmentColor("Ridiculous"))
			end
			for i=1, #windows do
				g[#g+1] = Def.Quad {
					InitCommand = function(self)
						local w = (windows[i] / maxOffset) * ebW
						self:zoomto(w, ebH + 16):diffuse(colors[i]):diffusealpha(0.35)
					end,
					UpdateChildrenEBWidthCommand = function(self, params)
						local w = (windows[i] / maxOffset) * params.width
						self:zoomto(w, ebH + 16)
					end
				}
			end
			return g
		end)()
	},
	
	-- Early Indicator (Left)
	LoadFont("Common Normal") .. {
		Text = "EARLY",
		InitCommand = function(self)
			self:x(-ebW/2 - 5):y(-12):zoom(0.25):halign(0):diffusealpha(0)
		end,
		OnCommand = function(self)
			self:sleep(0.5):linear(0.2):diffusealpha(0.6):sleep(1.2):linear(0.2):diffusealpha(0)
		end,
		UpdateChildrenEBWidthCommand = function(self, params)
			self:x(-params.width/2 - 5)
		end
	},
	-- Late Indicator (Right)
	LoadFont("Common Normal") .. {
		Text = "LATE",
		InitCommand = function(self)
			self:x(ebW/2 + 5):y(-12):zoom(0.25):halign(1):diffusealpha(0)
		end,
		OnCommand = function(self)
			self:sleep(0.5):linear(0.2):diffusealpha(0.6):sleep(1.2):linear(0.2):diffusealpha(0)
		end,
		UpdateChildrenEBWidthCommand = function(self, params)
			self:x(params.width/2 + 5)
		end
	},

	Def.Quad {
		Name = "EWMAMarker",
		InitCommand = function(self)
			self:zoomto(2, ebH + 8):diffuse(accentColor):visible(showEWMA)
		end,
		UpdateEWMACommand = function(self, params)
			local offset = params.offset
			ewmaValue = (1 - ewmaAlpha) * ewmaValue + ewmaAlpha * offset
			self:x((ewmaValue / maxOffset) * (ebW / 2))
		end,
		UpdateChildrenEBWidthCommand = function(self, params)
			self:x((ewmaValue / maxOffset) * (params.width / 2))
		end
	},

	JudgmentMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		if not params.TapNoteScore then return end
		if params.HoldNoteScore then return end -- Skip holds

		local offset = params.TapNoteOffset
		if not offset then return end

		-- Exclude misses from EWMA
		if params.TapNoteScore == "TapNoteScore_Miss" then return end

		-- Clamp for visualization
		local visualOffset = offset * 1000 -- to ms
		
		-- Update EWMA marker if enabled
		if showEWMA then
			self:GetChild("EWMAMarker"):playcommand("UpdateEWMA", {offset = visualOffset})
		end

		if not showStandard then return end
		if math.abs(visualOffset) > maxOffset then return end

		local ebColoring = ThemePrefs.Get("HV_ErrorBarColoringMode") or "Current"
		local jScale = 1
		if ebColoring == "Current" then
			jScale = PREFSMAN:GetPreference("TimingWindowScale")
		end

		local xPos = (visualOffset / maxOffset) * (ebW / 2)
		local jColor = offsetToJudgeColor(visualOffset, jScale)

		-- Pooling system: Cycle through child actors
		local pool = self:GetChild("Pool")
		if pool then
			self.poolIdx = (self.poolIdx or 0) % 50 + 1
			local dot = pool:GetChild("Dot"..self.poolIdx)
			if dot then
				dot:stoptweening():visible(true):x(xPos):diffuse(jColor):diffusealpha(0.8)
					:sleep(dotLife):linear(0.5):diffusealpha(0)
			end
		end
	end,

	(function()
		local poolDef = Def.ActorFrame { Name = "Pool" }
		for i=1, 50 do
			poolDef[#poolDef + 1] = Def.Quad {
				Name = "Dot"..i,
				InitCommand = function(s)
					s:zoomto(1, ebH + 6):visible(false)
				end
			}
		end
		return poolDef
	end)()
	,
	MovableBorder(ebW, ebH + 12, 1, 0, 0)
}

-- ============================================================
-- TWO-COLUMN JUDGMENT TALLY + PERFORMANCE METRICS
-- ============================================================
local colSpacing = 70
local showJudgeCounter = HV.ShowJudgeCounter()
local tallyX = SCREEN_CENTER_X + 160
local tallyY = SCREEN_HEIGHT - 176

if showJudgeCounter and not isSync then
t[#t + 1] = Def.ActorFrame {
	Name = "TallyAndMetrics",
	InitCommand = function(self)
		self:xy(gameplayCoord("JudgeCounterX"), gameplayCoord("JudgeCounterY")):diffusealpha(0.8)
		self:visible(minimalisticHUDVisible(showJudgeCounter))
	end,
	HV_MinimalisticModeChangedMessageCommand = function(self, params)
		animateGameplayHUDVisibility(self, minimalisticHUDVisible(showJudgeCounter, params and params.Enabled))
	end,
	OnCommand = function(self)
		setMovableActor({"DeviceButton_p"}, self, self:GetChild("Border"))
	end,

	-- COLUMN 1: Judgments + OK/NG
	Def.ActorFrame {
		Name = "Column1_Judgments",
		
		-- Loop through standard judgments (W1-Miss)
		(function()
			local g = Def.ActorFrame{}
			for i, label in ipairs(judgmentLabels) do
				g[#g+1] = Def.ActorFrame {
					InitCommand = function(self)
						self:y((i - 1) * 16)
					end,

					LoadFont("Common Normal") .. {
						InitCommand = function(self)
							self:halign(0):valign(0):zoom(0.34):diffuse(judgmentColors[i]):diffusealpha(0.8)
							self:settext(label)
						end
					},

					LoadFont("Common Normal") .. {
						Name = "TallyCount_" .. label,
						InitCommand = function(self)
							self:halign(1):valign(0):x(60):zoom(0.34):diffuse(mainText):diffusealpha(0.8)
							self:settext("0")
						end,
						JudgmentMessageCommand = function(self)
							self:queuecommand("Update")
						end,
						UpdateCommand = function(self)
							local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
							if pss then
								self:settext(getGameplayJudgmentCount(pss, judgmentTNS[i]))
							end
						end,
						PracticeModeResetMessageCommand = function(self)
							if judgmentTNS[i] == "Ridiculous" then HV_RidiculousCount = 0 end
							self:settext("0")
						end,
						PracticeModeReloadMessageCommand = function(self)
							if judgmentTNS[i] == "Ridiculous" then HV_RidiculousCount = 0 end
							self:settext("0")
						end
					}
				}
			end
			return g
		end)(),

		-- OK / NG counters
		Def.ActorFrame {
			Name = "OKNGDisplay",
			InitCommand = function(self)
				self:y(#judgmentLabels * 16 + 4)
			end,

			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:halign(0):valign(0):zoom(0.34):diffuse(HVColor.GetJudgmentColor("Held")):diffusealpha(0.8)
					self:settext(THEME:GetString("HoldNoteScore", "OK"))
				end
			},
			LoadFont("Common Normal") .. {
				Name = "OKCount",
				InitCommand = function(self)
					self:halign(1):valign(0):x(60):zoom(0.34):diffuse(mainText):diffusealpha(0.8)
					self:settext("0")
				end,
				JudgmentMessageCommand = function(self)
					self:queuecommand("Update")
				end,
				UpdateCommand = function(self)
					local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
					if pss then
						local ok = pss:GetHoldNoteScores("HoldNoteScore_Held")
						self:settext(tostring(ok))
					end
				end,
				PracticeModeResetMessageCommand = function(self) self:settext("0") end,
				PracticeModeReloadMessageCommand = function(self) self:settext("0") end
			},

			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:halign(0):valign(0):y(16):zoom(0.34):diffuse(HVColor.GetJudgmentColor("LetGo")):diffusealpha(0.8)
					self:settext(THEME:GetString("HoldNoteScore", "NG"))
				end
			},
			LoadFont("Common Normal") .. {
				Name = "NGCount",
				InitCommand = function(self)
					self:halign(1):valign(0):x(60):y(16):zoom(0.34):diffuse(mainText):diffusealpha(0.8)
					self:settext("0")
				end,
				JudgmentMessageCommand = function(self)
					self:queuecommand("Update")
				end,
				UpdateCommand = function(self)
					local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
					if pss then
						local ng = pss:GetHoldNoteScores("HoldNoteScore_LetGo")
						self:settext(tostring(ng))
					end
				end,
				PracticeModeResetMessageCommand = function(self) self:settext("0") end,
				PracticeModeReloadMessageCommand = function(self) self:settext("0") end
			}
		}
	},

	-- COLUMN 2: Performance Metrics (aligned to the right of Column 1)
	Def.ActorFrame {
		Name = "Column2_Metrics",
		InitCommand = function(self)
			self:x(colSpacing)
			-- Hide metrics in Simple mode
			if HV.GetJudgmentTallyMode() == "Simple" then
				self:visible(false)
			end
		end,

		-- Rescored % (J4)
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):zoom(0.34):diffuse(dimText)
				self:settext("J4")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "RescoreValue",
			InitCommand = function(self)
				self:halign(1):valign(0):x(65):zoom(0.34):diffuse(subText)
				self:settext("0.0000%")
				self.currWifePoints = 0
			end,
			JudgmentMessageCommand = function(self, msg)
				-- Only process tap-related judgments.
				if msg.HoldNoteScore or msg.RollNoteScore then
					if msg.HoldNoteScore == "HoldNoteScore_LetGo" or msg.RollNoteScore == "RollNoteScore_MissedRoll" then
						self.currWifePoints = self.currWifePoints - 4.5
						self:queuecommand("Update")
					end
					return
				end

				if msg.TapNoteScore and msg.TapNoteScore ~= "TapNoteScore_AvoidMine" and msg.TapNoteScore ~= "TapNoteScore_CheckpointHit" then
					local ts = ms.JudgeScalers[4] or 1.0 -- J4 rescaling always uses J4 (Index 4)
					if msg.TapNoteOffset then
						self.currWifePoints = self.currWifePoints + wife3(math.abs(msg.TapNoteOffset) * 1000, ts, "Wife3")
					elseif msg.TapNoteScore == "TapNoteScore_Miss" then
						self.currWifePoints = self.currWifePoints - 5.5
					elseif msg.TapNoteScore == "TapNoteScore_HitMine" then
						self.currWifePoints = self.currWifePoints - 7.0
					elseif msg.TapNoteScore ~= "TapNoteScore_None" then
						self.currWifePoints = self.currWifePoints + 2.0
					end
				end
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local notesPassed = pss:GetTapNoteScores("TapNoteScore_W1") +
									   pss:GetTapNoteScores("TapNoteScore_W2") +
									   pss:GetTapNoteScores("TapNoteScore_W3") +
									   pss:GetTapNoteScores("TapNoteScore_W4") +
									   pss:GetTapNoteScores("TapNoteScore_W5") +
									   pss:GetTapNoteScores("TapNoteScore_Miss")
					
					local maxPoints = notesPassed * 2
					if maxPoints > 0 then
						local j4 = math.min((self.currWifePoints / maxPoints) * 100, 100)
						self:settext(string.format("%.4f%%", j4))
					else
						self:settext("100.0000%")
					end
				end
			end,
			PracticeModeResetMessageCommand = function(self) self.currWifePoints = 0; self:settext("100.0000%") end,
			PracticeModeReloadMessageCommand = function(self) self.currWifePoints = 0; self:settext("100.0000%") end
		},

		-- MA Ratio (W1/W2)
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):y(16):zoom(0.34):diffuse(dimText)
				self:settext("MA Ratio")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "MARatioValue",
			InitCommand = function(self)
				self:halign(1):valign(0):x(65):y(16):zoom(0.34):diffuse(subText)
				self:settext("0.00:1")
			end,
			JudgmentMessageCommand = function(self)
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local w1 = pss:GetTapNoteScores("TapNoteScore_W1")
					local w2 = pss:GetTapNoteScores("TapNoteScore_W2")
					local ratio = 0
					if w2 > 0 then
						ratio = w1 / w2
						self:settext(string.format("%.2f:1", ratio))
					elseif w1 > 0 then
						self:settext("inf:1")
					else
						self:settext("0.00:1")
					end
				end
			end,
			PracticeModeResetMessageCommand = function(self) self:settext("0.00:1") end,
			PracticeModeReloadMessageCommand = function(self) self:settext("0.00:1") end
		},

		-- PA Ratio (W2/W3)
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):y(32):zoom(0.34):diffuse(dimText)
				self:settext("PA Ratio")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "PARatioValue",
			InitCommand = function(self)
				self:halign(1):valign(0):x(65):y(32):zoom(0.34):diffuse(subText)
				self:settext("0.00:1")
			end,
			JudgmentMessageCommand = function(self)
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local w2 = pss:GetTapNoteScores("TapNoteScore_W2")
					local w3 = pss:GetTapNoteScores("TapNoteScore_W3")
					local ratio = 0
					if w3 > 0 then
						ratio = w2 / w3
						self:settext(string.format("%.2f:1", ratio))
					elseif w2 > 0 then
						self:settext("inf:1")
					else
						self:settext("0.00:1")
					end
				end
			end,
			PracticeModeResetMessageCommand = function(self) self:settext("0.00:1") end,
			PracticeModeReloadMessageCommand = function(self) self:settext("0.00:1") end
		},

		-- Longest Combo
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):y(48):zoom(0.34):diffuse(dimText)
				self:settext("Longest")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "MaxComboValue",
			InitCommand = function(self)
				self:halign(1):valign(0):x(65):y(48):zoom(0.34):diffuse(subText)
				self:settext("0")
			end,
			JudgmentMessageCommand = function(self)
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					self:settext(tostring(pss:MaxCombo()))
				end
			end,
			PracticeModeResetMessageCommand = function(self) self:settext("0") end,
			PracticeModeReloadMessageCommand = function(self) self:settext("0") end
		},

		-- Std Dev
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):y(64):zoom(0.34):diffuse(dimText)
				self:settext("SD")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "SDValue",
			InitCommand = function(self)
				self:halign(1):valign(0):x(65):y(64):zoom(0.34):diffuse(subText)
				self:settext("0.00")
			end,
			JudgmentMessageCommand = function(self)
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local dvt = pss:GetOffsetVector()
					if dvt and #dvt > 0 then
						local sd = wifeSd(dvt)
						self:settext(string.format("%.2f", sd))
					end
				end
			end,
			PracticeModeResetMessageCommand = function(self) self:settext("0.00") end,
			PracticeModeReloadMessageCommand = function(self) self:settext("0.00") end
		},

		-- Largest Offset
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):y(80):zoom(0.34):diffuse(dimText)
				self:settext("Max")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "LargestValue",
			InitCommand = function(self)
				self:halign(1):valign(0):x(65):y(80):zoom(0.34):diffuse(subText)
				self:settext("0.00")
			end,
			JudgmentMessageCommand = function(self)
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local dvt = pss:GetOffsetVector()
					if dvt and #dvt > 0 then
						local max = wifeMax(dvt)
						self:settext(string.format("%.2f", max))
					end
				end
			end,
			PracticeModeResetMessageCommand = function(self) self:settext("0.00") end,
			PracticeModeReloadMessageCommand = function(self) self:settext("0.00") end
		}
	}
	,
	MovableBorder(140, 100, 1, 70, 50)
}
end

-- ============================================================
-- SONG TITLE (BOTTOM of screen)
-- ============================================================
if not isSync then
t[#t + 1] = Def.ActorFrame {
	Name = "BPMText",
	InitCommand = function(self)
		self:xy(gameplayCoord("BPMTextX"), gameplayCoord("BPMTextY")):zoom(gameplaySize("BPMTextZoom"))
		self:visible(minimalisticHUDVisible(true))
	end,
	HV_MinimalisticModeChangedMessageCommand = function(self, params)
		animateGameplayHUDVisibility(self, minimalisticHUDVisible(true, params and params.Enabled))
	end,
	OnCommand = function(self)
		setMovableActor({"DeviceButton_x", "DeviceButton_c"}, self, self:GetChild("Border"))
		self:diffusealpha(0.6)
	end,
	LoadFont("Common Normal") .. {
		Name = "Text",
		InitCommand = function(self)
			self:zoom(0.35):diffuse(subText):maxwidth(SCREEN_WIDTH / 0.35)
		end,
		PlayingUpdateMessageCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local bps = GAMESTATE:GetSongPosition():GetCurBPS()
				local bpm = bps * 60 * getCurRateValue()
				local rate = getCurRateString()
				self:settextf("%d BPM    %s Rate", math.floor(bpm + 0.5), rate)
			end
		end
	},
	MovableBorder(150, 18, 1, 0, 0)
}

t[#t + 1] = Def.ActorFrame {
	Name = "SongInfoHUD",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 14)
		self:visible(minimalisticHUDVisible(true))
	end,
	HV_MinimalisticModeChangedMessageCommand = function(self, params)
		animateGameplayHUDVisibility(self, minimalisticHUDVisible(true, params and params.Enabled))
	end,
	OnCommand = function(self)
		self:diffusealpha(0.6)
	end,

	LoadFont("Zpix Normal") .. {
		InitCommand = function(self)
			self:zoom(0.35):diffuse(mainText):maxwidth(SCREEN_WIDTH * 0.5 / 0.35)
		end,
		BeginCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				self:settext(song:GetDisplayMainTitle())
			end
		end
	}
}
end

-- ============================================================
-- TOASTY (fires at combo 250, 500, 750, 1000, ...)
-- technically it should be every 250 perfect combo but eh
-- ============================================================
local lastToastyCombo = 0

local function safeGetThemePath(type, folder, element)
	local possiblePaths = {
		"Themes/Holographic Void/" .. folder .. "/" .. element,
		"Themes/_fallback/" .. folder .. "/" .. element
	}
	for _, p in ipairs(possiblePaths) do
		local extensions = type == "G" and {".png", ".jpg", ".jpeg", ".gif", ".webm"} or {".ogg", ".wav", ".mp3"}
		for _, ext in ipairs(extensions) do
			if FILEMAN:DoesFileExist(p .. ext) then
				return p .. ext
			end
		end
	end
	return nil
end

local toastyImgPath = safeGetThemePath("G", "Graphics", "toasty") or safeGetThemePath("G", "Graphics", "Common toasty")
local toastySndPath = safeGetThemePath("S", "Sounds", "toasty") or safeGetThemePath("S", "Sounds", "Common toasty")

if not isSync then
t[#t + 1] = Def.ActorFrame {
	Name = "Toasty",
	InitCommand = function(self)
		lastToastyCombo = 0
	end,

	Def.Sprite {
		Name = "ToastySprite",
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH + 100, SCREEN_CENTER_Y):diffusealpha(0)
			if toastyImgPath then
				self:Load(toastyImgPath)
			end
		end,
		StartTransitioningCommand = function(self)
			if not toastyImgPath then return end
			self:stoptweening()
			self:diffusealpha(1)
			self:decelerate(0.25):x(SCREEN_WIDTH - 100)
			self:sleep(1.75)
			self:accelerate(0.5):x(SCREEN_WIDTH + 100)
			self:linear(0):diffusealpha(0)
		end
	},

	Def.Sound {
		Name = "ToastySound",
		InitCommand = function(self)
			if toastySndPath then
				self:load(toastySndPath)
			end
		end,
		StartTransitioningCommand = function(self)
			if toastySndPath then self:play() end
		end
	},

	JudgmentMessageCommand = function(self)
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		if pss then
			local combo = pss:GetCurrentCombo()
			if combo and combo >= 250 then
				local milestone = math.floor(combo / 250)
				local lastMilestone = math.floor(lastToastyCombo / 250)
				if milestone > lastMilestone then
					self:playcommand("StartTransitioning")
				end
			end
			if combo then
				lastToastyCombo = combo
			end
		end
	end
}
end

-- ============================================================
-- LANE COVER
-- ============================================================
local suddenHeight = HV.GetLaneCoverSudden()
local hiddenHeight = HV.GetLaneCoverHidden()

if suddenHeight > 0 or hiddenHeight > 0 then
	local isReverse = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions():UsingReverse()
	
	-- Helper to create a cover quad (isTop=true for Top, false for Bottom)
	local function createCover(height, isTop)
		local h = SCREEN_HEIGHT * (height / 100)
		return Def.Quad {
			InitCommand = function(self)
				self:zoomto(SCREEN_WIDTH, h)
					:diffuse(color("0,0,0,1"))
				if isTop then
					self:valign(0):y(-SCREEN_HEIGHT / 2)
				else
					self:valign(1):y(SCREEN_HEIGHT / 2)
				end
			end
		}
	end

	local t_cover = Def.ActorFrame {
		Name = "LaneCoverLayer",
		InitCommand = function(self)
			self:Center()
			self:visible(not isSync)
		end,
	}

	-- Sudden: spawn side (Top for Standard, Bottom for Reverse)
	if suddenHeight > 0 then
		t_cover[#t_cover + 1] = createCover(suddenHeight, not isReverse)
	end

	-- Hidden: receptor side (Bottom for Standard, Top for Reverse)
	if hiddenHeight > 0 then
		t_cover[#t_cover + 1] = createCover(hiddenHeight, isReverse)
	end
	
	t[#t + 1] = t_cover
end

if not isSync then
	t[#t + 1] = LoadActor("scoretracking")
	t[#t + 1] = LoadActor("pacemaker")
	t[#t + 1] = Def.ActorFrame {
		Name = "AutofailDisplay",
		InitCommand = function(self)
			self:xy(gameplayCoord("AutoFailDisplayX"), gameplayCoord("AutoFailDisplayY")):zoom(gameplaySize("AutoFailDisplayZoom"))
			self:visible(false)
		end,
		OnCommand = function(self)
			setMovableActor({"DeviceButton_g", "DeviceButton_h"}, self, self:GetChild("Border"))
		end,
		BeginCommand = function(self)
			self:queuecommand("Refresh")
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if not params or not params.Name then return end
			if params.Name:find("HV_AutoFail") then
				self:queuecommand("Refresh")
			end
		end,
		HV_PointsUpdateMessageCommand = function(self)
			self:queuecommand("Refresh")
		end,
		RefreshCommand = function(self)
			local actionMode = ThemePrefs.Get("HV_AutoFailMode")
			if actionMode == "Off" or not actionMode then
				self:visible(false)
				return
			end
			self:visible(true)
			local condition = ThemePrefs.Get("HV_AutoFailCondition")
			local iconWife = self:GetChild("IconWife")
			local iconPB = self:GetChild("IconPB")
			local iconTarget = self:GetChild("IconTarget")
			if iconWife then iconWife:visible(condition == "Wife Percent") end
			if iconPB then iconPB:visible(condition == "Personal Best") end
			if iconTarget then iconTarget:visible(condition == "Judgement Count") end
			local txt = self:GetChild("Value")
			if not txt then return end
			local display = ""
			local c = color("1,1,1,1")
			if condition == "Wife Percent" then
				local threshold = tonumber(ThemePrefs.Get("HV_AutoFailThreshold_Wife")) or 93.00
				local subtractiveWife = ((HV_MaxPoints - HV_PointsLost) / HV_MaxPoints) * 100
				display = string.format("%.4f%%", threshold)
				txt:xy(11, 20)
			elseif condition == "Personal Best" then
				if not HV_PBThreshold or HV_PBThreshold == 0 then
					local best = GetDisplayScore()
					if best then
						HV_PBThreshold = getJ4NormalizedPercentage(best)
					else
						HV_PBThreshold = tonumber(ThemePrefs.Get("HV_AutoFailThreshold_Wife")) or 93.00
					end
				end
				local subtractiveWife = ((HV_MaxPoints - HV_PointsLost) / HV_MaxPoints) * 100
				display = string.format("%.4f%%", HV_PBThreshold or 0)
				txt:xy(11, 20)
			elseif condition == "Judgement Count" then
				local limit = tonumber(ThemePrefs.Get("HV_AutoFailThreshold_Count")) or 10
				local judgePref = ThemePrefs.Get("HV_AutoFailJudgement") or "Miss"
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				local currentCount = 0
				if pss then
					local order = {"W2","W3","W4","W5","Miss"}
					local idx = 5
					for i=1, #order do
						if order[i] == judgePref then idx = i break end
					end
					for i=idx, #order do
						currentCount = currentCount + pss:GetTapNoteScores("TapNoteScore_" .. order[i])
					end
				end
				local remaining = math.max(0, limit - currentCount)
				display = tostring(remaining)
				c = HVColor.GetJudgmentColor(judgePref)
				txt:xy(24, 20)
			end
			txt:settext(display)
			txt:diffuse(c)
		end,
		Def.Sprite {
			Name = "IconWife",
			Texture = THEME:GetPathG("", "wife.png"),
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(0, 0):zoom(0.20):visible(false)
			end
		},
		Def.Sprite {
			Name = "IconPB",
			Texture = THEME:GetPathG("", "pb.png"),
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(0, 0):zoom(0.20):visible(false)
			end
		},
		Def.Sprite {
			Name = "IconTarget",
			Texture = THEME:GetPathG("", "target.png"),
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(0, 0):zoom(0.20):visible(false)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Value",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(11, 20):zoom(0.55)
				self:settext("")
			end
		},
		MovableBorder(64, 64, 1, 32, 0)
	}
	t[#t + 1] = LoadActor("npscalc")
	t[#t + 1] = LoadActor("multiplayer")
	t[#t + 1] = LoadActor("leaderboard")
	t[#t + 1] = LoadActor("avatar")
end
t[#t + 1] = LoadActor("intro")
t[#t + 1] = LoadActor("messagebox")

-- ============================================================
-- NG INDICATOR (POPUP)
-- ============================================================
if HV.ShowNGIndicator() and not isSync then
	local isReverse = GAMESTATE:GetPlayerState(PLAYER_1):GetCurrentPlayerOptions():UsingReverse()
	local ngY = isReverse and (SCREEN_CENTER_Y + 164 - 40) or (SCREEN_CENTER_Y - 164 + 40)
	local colOffsets = {-96, -32, 32, 96}

	local ngFrame = Def.ActorFrame {
		Name = "NGIndicator",
		InitCommand = function(self)
			self:visible(minimalisticHUDVisible(true))
		end,
		HV_MinimalisticModeChangedMessageCommand = function(self, params)
			animateGameplayHUDVisibility(self, minimalisticHUDVisible(true, params and params.Enabled))
		end,
	}
	for i = 1, 4 do
		ngFrame[#ngFrame + 1] = LoadFont("Common Normal") .. {
			Name = "NG_" .. i,
			InitCommand = function(self)
				self:xy(SCREEN_CENTER_X + colOffsets[i], ngY)
				self:zoom(1.2):diffuse(color("#FF4444")):diffusealpha(0):settext("NG")
			end,
			JudgmentMessageCommand = function(self, params)
				if params.HoldNoteScore == "HoldNoteScore_LetGo" then
					local laneMatch = false
					if params.Notes and params.Notes[i] ~= nil then
						laneMatch = true
					elseif params.FirstTrack == (i - 1) then
						laneMatch = true
					end
					if laneMatch then
						self:stoptweening():diffusealpha(1):zoom(1.2):linear(0.2):zoom(1.5):linear(0.2):zoom(1.2):sleep(0.5):linear(0.2):diffusealpha(0)
					end
				end
			end
		}
	end
	t[#t + 1] = ngFrame
end


-- ============================================================
-- SYNC MODE CHALLENGE (Note Fading)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "SyncChallengeOverlay",
	InitCommand = function(self) self:visible(isSync) end,
	(function()
		local noteCounter = 0
		local threshold = 10
		local triggered = false
		
		return Def.ActorFrame {
			LoadFont("Common Normal") .. {
				Name = "Message",
				InitCommand = function(self)
					self:Center():zoom(0.8):diffusealpha(0):settext("Keep tapping to the beat")
				end,
				PulseCommand = function(self)
					self:stoptweening():linear(0.5):zoom(0.85):linear(0.5):zoom(0.8):queuecommand("Pulse")
				end
			},
			JudgmentMessageCommand = function(self, params)
				if not isSync or triggered then return end
				if params.TapNoteScore then
					noteCounter = noteCounter + 1
					if noteCounter >= threshold then
						triggered = true
						MESSAGEMAN:Broadcast("SyncTriggered")
						local msg = self:GetChild("Message")
						msg:linear(1):diffusealpha(1):queuecommand("Pulse")
					end
				end
			end,
			CurrentSongChangedMessageCommand = function(self)
				noteCounter = 0
				triggered = false
				local msg = self:GetChild("Message")
				if msg then msg:stoptweening():diffusealpha(0) end
			end
		}
	end)()
}

-- ============================================================
-- END-OF-CHART CLEAR TYPE CELEBRATION
-- FC and above: rise-up text with color animation at chart end
-- ============================================================
local function CelebrationBurst()
	local burst = Def.ActorFrame{
		CelebrationCommand = function(self, params)
			local count = 0
			local maxRays = params.numRays or 10
			local speed = params.speed or 0.6
			local burstColor = params.color or color("#FFFFFF")
			
			self:RunCommandsOnChildren(function(child)
				count = count + 1
				if count <= maxRays then
					child:playcommand("Burst", {
						numRays = maxRays, 
						speed = speed, 
						color = burstColor, 
						index = count
					})
				end
			end)
		end,
	}
	-- Create a pool of 24 rays (max intensity)
	for i = 1, 24 do
		burst[#burst+1] = Def.Quad{
			InitCommand = function(self)
				self:zoomto(2, 200):diffusealpha(0)
			end,
			BurstCommand = function(self, params)
				self:stoptweening():diffusealpha(0):zoomto(2, 0)
				-- Distribute rays evenly based on the current active count
				self:rotationz((params.index - 1) * (360 / params.numRays))
				
				-- Start white (or red flash for heartbreaks) then transition to clear type color
				if params.isHeartbreak then
					self:diffuse(color("#FF0000"))
				else
					self:diffuse(color("#FFFFFF"))
				end
				
				self:sleep(0.05):linear(params.speed * 0.4):zoomto(4, 400):diffusealpha(0.6):diffuse(params.color)
				self:linear(params.speed * 0.6):zoomto(0, 0):diffusealpha(0)
			end
		}
	end
	return burst
end

t[#t+1] = Def.ActorFrame{
	Name = "EndOfChartClearType",
	InitCommand = function(self)
		self:Center():visible(true)
	end,

	CelebrationBurst(),

	Def.ActorFrame{
		Name = "CTRiseFrame",
		InitCommand = function(self)
			self:diffusealpha(0):y(30)  -- start below center
		end,
		OffCommand = function(self)
			if isSync then return end
			
			-- Delay slightly to ensure statistics are stabilized
			self:sleep(0.05)
			
			local epn = pn or GAMESTATE:GetEnabledPlayers()[1] or PLAYER_1
			local epss = STATSMAN:GetCurStageStats():GetPlayerStageStats(epn)
			if not epss then return end
			local steps = GAMESTATE:GetCurrentSteps()
			if not steps then return end
			
			local clearLevel = getClearLevel(epn, steps, epss)

			-- Fallback: if getClearLevel failed but it's a Full Combo
			if clearLevel > 7 and epss:FullComboOfScore("TapNoteScore_W3") then
				clearLevel = 7 -- Regular FC
			end

			-- MFC=1 ... FC=7
			if clearLevel <= 7 then
				local ctName = getClearType(epn, steps, epss)
				if clearLevel == 7 and (not ctName or ctName == "") then ctName = "FC" end
				
				local ctText = getClearTypeText(ctName)
				local ctColor = getClearTypeColor(ctName)

				-- Intensity settings: rays and speed
				local numRays = 10
				local burstSpeed = 0.6
				local isHeartbreak = false
				
				if clearLevel == 1 then -- MFC
					numRays = 24
					burstSpeed = 0.4
				elseif clearLevel == 2 then -- WF (Heartbreak)
					numRays = 20
					burstSpeed = 0.45
					isHeartbreak = true
				elseif clearLevel <= 4 then -- PFC variants
					numRays = 16
					burstSpeed = 0.5
				elseif clearLevel == 5 then -- BF (Heartbreak)
					numRays = 14
					burstSpeed = 0.55
					isHeartbreak = true
				end

				local txt = self:GetChild("CTText")
				txt:stoptweening():settext(ctText)
				
				-- Intense red flash for heartbreaks
				if isHeartbreak then
					txt:diffuse(color("#FF0000"))
				else
					txt:diffuse(color("#FFFFFF"))
				end

				-- Trigger dynamic burst
				self:GetParent():RunCommandsOnChildren(function(c) 
					c:playcommand("Celebration", {
						numRays = numRays, 
						speed = burstSpeed, 
						color = ctColor, 
						isHeartbreak = isHeartbreak
					})
				end)

				-- Rise-up animation: from y=30 to y=0
				self:stoptweening()
				self:y(30):diffusealpha(0):zoom(1.5)
				self:decelerate(0.5):y(0):diffusealpha(1):zoom(1)

				-- Special Heartbreak Shake/Pulse
				if clearLevel == 2 then -- WF: Jitter shake
					for i=1, 4 do
						self:sleep(0.02):x(-3):sleep(0.02):x(3)
					end
					self:sleep(0.02):x(0)
				elseif clearLevel == 5 then -- BF: Vertical thump/pulse
					self:bounce(0.2):effectmagnitude(0, -6, 0):effectclock("bgm"):effectperiod(0.1)
					self:sleep(0.4):stopeffect()
				end

				-- Color sweep: stay red/white then transition to clear type color
				if isHeartbreak then
					txt:sleep(0.4):linear(0.2):diffuse(color("#FFFFFF")):linear(0.5):diffuse(ctColor)
				else
					txt:sleep(0.3):linear(0.5):diffuse(ctColor)
				end
				
				-- Gentle pulse
				txt:sleep(0.2):linear(0.4):diffusealpha(0.8):linear(0.4):diffusealpha(1)

				-- Hold then fade out before the evaluation screen takes over
				self:sleep(3):smooth(1):diffusealpha(0):y(-10)
			end
		end,

		LoadFont("Common Large") .. {
			Name = "CTText",
			InitCommand = function(self)
				self:zoom(0.7):strokecolor(color("0,0,0,0.6"))
			end
		}
	}
}



-- ============================================================
-- AUTO-FAIL / RESTART MECHANIC
-- ============================================================
t[#t + 1] = Def.Actor {
	Name = "AutoFailController",
	InitCommand = function(self)
		self.hasTriggered = false
	end,
	HV_PointsUpdateMessageCommand = function(self)
		local actionMode = ThemePrefs.Get("HV_AutoFailMode")
		if actionMode == "Off" or not actionMode or self.hasTriggered then return end
		
		local condition = ThemePrefs.Get("HV_AutoFailCondition")
		
		local triggered = false

		if condition == "Wife Percent" then
			local threshold = tonumber(ThemePrefs.Get("HV_AutoFailThreshold_Wife")) or 93.00
			local subtractiveWife = ((HV_MaxPoints - HV_PointsLost) / HV_MaxPoints) * 100
			if subtractiveWife <= threshold then 
				triggered = true 
			end
		elseif condition == "Personal Best" then
			local subtractiveWife = ((HV_MaxPoints - HV_PointsLost) / HV_MaxPoints) * 100
			if subtractiveWife <= HV_PBThreshold then
				triggered = true
			end
		elseif condition == "Judgement Count" then
			local limit = tonumber(ThemePrefs.Get("HV_AutoFailThreshold_Count")) or 10
			local judgePref = ThemePrefs.Get("HV_AutoFailJudgement") or "Miss"
			local order = {"W2","W3","W4","W5","Miss"}
			local idx = 5
			for i=1, #order do
				if order[i] == judgePref then idx = i break end
			end
			local currentCount = 0
			for i=idx, #order do
				currentCount = currentCount + (HV_AutoFailJudgeCounts[order[i]] or 0)
			end
			if currentCount > 0 and currentCount >= limit then 
				triggered = true 
			end
		end

		if triggered then
			-- Prevent multiple triggers
			self:playcommand("ActionTriggered")
		end
	end,
	ActionTriggeredCommand = function(self)
		if self.hasTriggered then return end
		self.hasTriggered = true

		local actionMode = ThemePrefs.Get("HV_AutoFailMode")
		local top = SCREENMAN:GetTopScreen()
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		
		if top and pss then
			PlayFailSfxOnce()

			-- Explicitly mark the score as Failed for the engine's stats committer
			if pss.FailPlayer then
				pss:FailPlayer()
			end
			
			if actionMode == "Fail" then
				if top.GetLifeMeter then
					local lifeMeter = top:GetLifeMeter(pn)
					if lifeMeter and lifeMeter.ChangeLife then
						lifeMeter:ChangeLife(-10)
					end
				end
				top:PostScreenMessage("SM_BeginFailed", 0)
			elseif actionMode == "Restart" then
				SCREENMAN:SetNewScreen("ScreenGameplay")
			end
		end
	end
}

return t
