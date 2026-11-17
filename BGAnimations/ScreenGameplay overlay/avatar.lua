-- Holographic Void: Avatar / Profile Display (adapted from Fatigue)
-- Shows player avatar, name, MSD, difficulty, mods, judge/scoring info,
-- life bar, and real-time DP / Wife% during gameplay.

local pn = GAMESTATE:GetEnabledPlayers()[1] or PLAYER_1
local profile = GetPlayerOrMachineProfile(pn)
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()

local avatarSize = 56
local panelX = 10
local panelY = SCREEN_HEIGHT - 66
local panelW = 240
local panelH = 60

-- HV accent color
local accentColor = HVColor.Accent or color("#00CFFF")
local dimText = color("0.5,0.5,0.5,1")
local fontZoom = 0.55
local fontZoomSmall = 0.45

local function formatDanName(dan)
	if dan == "0" then return "Below 1st" end
	if dan == "∞" or dan == "Infinity" then return "Infinity" end
	return dan
end

-- Gameplay reads the final Dan estimate from Save; it does not run Sunny SR
-- or ISOR. The existing direct MSD display remains unchanged.
local chartRatingCache = {}
local chartRatingCachePath = "Save/Holographic Void_settings/ChartRatingCache.lua"
do
	if FILEMAN and FILEMAN.DoesFileExist and FILEMAN:DoesFileExist(chartRatingCachePath) then
		local file = RageFileUtil.CreateRageFile()
		if file:Open(chartRatingCachePath, 1) then
			local source = file:Read()
			local chunk = type(source) == "string" and loadstring(source) or nil
			if chunk then
				setfenv(chunk, {})
				local ok, cache = pcall(chunk)
				if ok and type(cache) == "table" then chartRatingCache = cache end
			end
			file:Close()
		end
		file:destroy()
	end
end

local function getCachedChartEstimate(steps, rate)
	local enabled = ThemePrefs.Get("HV_EnableDanCalculator")
	if enabled ~= true and enabled ~= "true" then return nil end
	if not steps or not steps.GetChartKey then return nil end
	local chartKey = tostring(steps:GetChartKey())
	local rateKey = string.format("%.8f", tonumber(rate) or 1)
	local entry = chartRatingCache["isor-dp-v2|" .. chartKey .. "|" .. rateKey]
	if type(entry) ~= "table" then
		entry = chartRatingCache["isor-dp-v1|" .. chartKey .. "|" .. rateKey]
	end
	if type(entry) ~= "table" and HV.CurrentSongData then
		local data = HV.CurrentSongData
		local currentKey = data.steps and data.steps.GetChartKey and tostring(data.steps:GetChartKey())
		if currentKey == chartKey and math.abs((tonumber(data.rate) or tonumber(rate) or 1) - (tonumber(rate) or 1)) < 0.0005
			and type(data.isorEstimate) == "table" then entry = data.isorEstimate end
	end
	if type(entry) ~= "table" or type(entry.dan) ~= "string" or type(entry.dp) ~= "number" then return nil end
	return entry
end

local function animateAvatarVisibility(self, visible)
	self:stoptweening()
	if visible then
		self:visible(true):diffusealpha(0):decelerate(0.18):diffusealpha(1)
	else
		self:accelerate(0.14):diffusealpha(0)
	end
end

-- Life helper
local function PLife()
	-- Priority 1: Direct LifeMeter actor polling (Smoothest, most reliable)
	local screen = SCREENMAN:GetTopScreen()
	if screen and screen:GetLifeMeter(pn) then
		return screen:GetLifeMeter(pn):GetLife()
	end
	
	-- Priority 2: PlayerStageStats (Fallback)
	local stats = STATSMAN:GetCurStageStats():GetPlayerStageStats()
	local life = stats:GetCurrentLife() or 0
	return math.max(0, life)
end

-- DP tracking
local actual_dp = 0
local total_max = 0

local function updateDPFromJudgment(msg)
	if msg.HoldNoteScore or msg.RollNoteScore then
		if msg.HoldNoteScore == "HoldNoteScore_MissedHold" or msg.RollNoteScore == "RollNoteScore_MissedRoll" then
			actual_dp = actual_dp - 4.5
		end
		return
	end

	if msg.TapNoteScore and msg.TapNoteScore ~= "TapNoteScore_AvoidMine" and msg.TapNoteScore ~= "TapNoteScore_CheckpointHit" then
		if msg.TapNoteOffset then
			local ts = ms.JudgeScalers[GetTimingDifficulty()] or PREFSMAN:GetPreference("TimingWindowScale") or 1.0
			actual_dp = actual_dp + wife3(math.abs(msg.TapNoteOffset) * 1000, ts, "Wife3")
		elseif msg.TapNoteScore == "TapNoteScore_Miss" then
			actual_dp = actual_dp - 5.5
		elseif msg.TapNoteScore == "TapNoteScore_HitMine" then
			actual_dp = actual_dp - 7.0
		elseif msg.TapNoteScore ~= "TapNoteScore_None" then
			actual_dp = actual_dp + 2.0
		end
	end
end

local t = Def.ActorFrame {
	Name = "AvatarDisplay",
	InitCommand = function(self)
		self:xy(panelX, panelY)
		-- Check if player info should be shown
		local showPlayerInfo = HV.ShowPlayerInfo() and not HV.MinimalisticMode()
		self:visible(showPlayerInfo)
		self:diffusealpha(showPlayerInfo and 1 or 0)
		actual_dp = 0
		total_max = 0
		local steps = GAMESTATE:GetCurrentSteps()
		if steps then
			total_max = steps:GetRadarValues(PLAYER_1):GetValue("RadarCategory_Notes") * 2
		end
	end,
	HV_MinimalisticModeChangedMessageCommand = function(self, params)
		animateAvatarVisibility(self, HV.ShowPlayerInfo() and not (params and params.Enabled))
	end,

	-- Panel background
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
			self:zoomto(panelW, panelH)
			self:diffuse(0.03, 0.03, 0.03, 0.8)
		end,
	},

	-- Avatar border accent
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
			self:xy(-2, -2)
			self:zoomto(avatarSize + 4, avatarSize + 4)
			self:diffuse(accentColor)
			self:diffusealpha(0.5)
		end,
	},

	-- Avatar sprite
	Def.Sprite {
		InitCommand = function(self)
			self:halign(0):valign(0)
		end,
		BeginCommand = function(self)
			self:finishtweening()
			self:Load(getAvatarPath(PLAYER_1))
			self:zoomto(avatarSize, avatarSize)
		end
	},

	-- Profile name
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(avatarSize + 6, 5):zoom(fontZoom):halign(0):maxwidth(130 / fontZoom)
			self:diffuse(color("1,1,1,1"))
			self.cycleState = 0
			self:playcommand("CycleName")
		end,
		CycleNameCommand = function(self)
			self:stoptweening()
			local pn = PLAYER_1
			local onlineName = HV.OnlineReplayActive
				and (HV.OnlineReplayName or "")
				or ((DLMAN:IsLoggedIn()) and DLMAN:GetUsername() or "")
			if HV.OnlineReplayActive and onlineName == "" then
				local screen = SCREENMAN:GetTopScreen()
				if screen and screen.GetReplayScore then
					local replayScore = screen:GetReplayScore(pn)
					if replayScore then
						local getter = replayScore.GetDisplayName or replayScore.GetName
						if getter then
							local ok, name = pcall(getter, replayScore)
							local placeholder = { ["Player 1"] = true, ["Player 2"] = true, ["Replay"] = true, ["Unknown"] = true, ["???"] = true }
							if ok and name and name ~= "" and not placeholder[tostring(name)] then onlineName = tostring(name) end
						end
					end
				end
			end
			local localName = ""
			local profile = PROFILEMAN:GetProfile(pn)
			if profile then localName = profile:GetDisplayName() end
			if localName == "" then localName = "Player 1" end
			
			if HV.OnlineReplayActive and onlineName ~= "" then
				self.cycleState = 0
				self:diffusealpha(1):settext(onlineName)
				self:sleep(3):queuecommand("CycleName")
			elseif onlineName ~= "" and onlineName ~= localName then
				if self.cycleState == 0 then
					self:settext(onlineName)
				else
					self:settext(localName)
				end
				self.cycleState = 1 - self.cycleState
				
				self:diffusealpha(0):linear(0.25):diffusealpha(1)
				self:sleep(2.5):linear(0.25):diffusealpha(0):queuecommand("CycleName")
			else
				self:diffusealpha(1)
				self:settext(onlineName ~= "" and onlineName or localName)
				self:sleep(3):queuecommand("CycleName")
			end
		end
	},
	
	-- Judge Display (Customized)
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(panelW - 6, 22):zoom(fontZoomSmall):halign(1)
		end,

		BeginCommand = function(self) self:queuecommand("Set") end,
		SetCommand = function(self)
			local j = GetTimingDifficulty()

			local names = {
				[4] = "Normal",
				[5] = "Pro",
				[6] = "Master",
				[7] = "Insane",
				[8] = "Godly",
				[9] = "Justice"
			}
			local name = names[j] or "Custom"
			self:settext(string.format("%s (J%d)", name, j))
			self:diffuse(accentColor)
		end

	},


	-- Cycle the existing MSD value with the cached Dan tier/sublevel.
	LoadFont("MSD 20px") .. {
		InitCommand = function(self)
			self:xy(avatarSize + 8, 22):zoom(fontZoom * 0.825):halign(0):maxwidth((100 / fontZoom) - 15)
		end,
		BeginCommand = function(self) self:queuecommand("Set") end,
		SetCommand = function(self)
			self:stoptweening()
			local steps = GAMESTATE:GetCurrentSteps(pn)
			if not steps then self:visible(false); self:settext(""); return end
			local meter = tonumber(steps:GetMSD(getCurRateValue(), 1)) or 0
			local entry = getCachedChartEstimate(steps, getCurRateValue())
			local pages = {}
			if meter and meter > 0 then
				pages[#pages + 1] = {text = string.format("%5.2f", meter), color = HVColor.GetMSDRatingColor(meter)}
			end
			if entry then
				local danName = formatDanName(entry.dan)
				local sublevel = type(entry.sublevel) == "string" and entry.sublevel or ""
				pages[#pages + 1] = {text = danName .. (sublevel ~= "" and (" " .. sublevel) or ""), color = (HV.GetReformDanColor and HV.GetReformDanColor(entry)) or HVColor.GetMSDRatingColor(tonumber(entry.dp) or 1)}
			end
			self.hvRatingPages = pages
			self.hvRatingPage = 1
			local showRating = HV.ShowMSD() and (meter > 0 or entry ~= nil)
			self:visible(showRating)
			if showRating then
				self:settext(pages[1].text):diffuse(pages[1].color)
				if #pages > 1 then self:sleep(3):queuecommand("CycleRating") end
			else
				self:settext("")
			end
		end,
		CycleRatingCommand = function(self)
			if not self.hvRatingPages or #self.hvRatingPages < 2 or not self:GetVisible() then return end
			self.hvRatingPage = self.hvRatingPage % #self.hvRatingPages + 1
			local page = self.hvRatingPages[self.hvRatingPage]
			self:settext(page.text):diffuse(page.color):sleep(3):queuecommand("CycleRating")
		end,
		CurrentRateChangedMessageCommand = function(self) self:queuecommand("Set") end,
	},

	-- Difficulty name
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(avatarSize + 85, 22):zoom(fontZoomSmall):halign(0):maxwidth(150 / fontZoomSmall)
		end,
		BeginCommand = function(self) self:queuecommand("Set") end,
		SetCommand = function(self)
			local steps = GAMESTATE:GetCurrentSteps()
			local diff = ToEnumShortString(steps:GetDifficulty())
			self:settext(getDifficulty(steps:GetDifficulty()))
			self:diffuse(HVColor.GetDifficultyColor(diff))
		end,
	},

	-- Mods string
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(avatarSize + 8, 38):halign(0):zoom(fontZoomSmall * 0.9):maxwidth(panelW * 0.75 / (fontZoomSmall * 0.9))
			self:diffuse(dimText)
		end,
		BeginCommand = function(self)
			self:settext(getModifierTranslations(GAMESTATE:GetPlayerState():GetPlayerOptionsString("ModsLevel_Current")))
		end
	},

	-- Life % counter
	-- it took me 30 hours to make sure it properly works.
	LoadFont("Common Normal") .. {
		Name = "LifePct",
		InitCommand = function(self)
			self:xy(avatarSize + 6, 52):halign(0):zoom(fontZoomSmall * 1.1)
		end,
		BeginCommand = function(self)
			self:playcommand("UpdateLife")
		end,
		JudgmentMessageCommand = function(self)
			self:playcommand("UpdateLife")
		end,
		PlayingUpdateMessageCommand = function(self)
			self:playcommand("UpdateLife")
		end,
		UpdateLifeCommand = function(self)
			local life = PLife()
			self:settextf("%.1f%%", life * 100)

			local diff = GetLifeDifficulty()
			local lifeKey = "L7"
			if diff <= 1 then
				lifeKey = "L1"
			elseif diff == 2 then
				lifeKey = "L2"
			elseif diff == 3 then
				lifeKey = "L3"
			elseif diff == 4 then
				lifeKey = "L4"
			elseif diff == 5 then
				lifeKey = "L5"
			elseif diff == 6 then
				lifeKey = "L6"
			end
			self:diffuse(HVColor.GetLifeBarColor(lifeKey))
		end
	},

	-- Life bar background
	Def.Quad {
		InitCommand = function(self)
			self:halign(0)
			self:xy(avatarSize + 40, 52)
			self:zoomto(panelW - avatarSize - 44, 6)
			self:diffuse(0.15, 0.15, 0.15, 1)
		end
	},

	-- Life bar fill
	Def.Quad {
		InitCommand = function(self)
			self:halign(0)
			self:xy(avatarSize + 40, 52)
			self:zoomto(0, 6)
			self:diffuse(accentColor)
			self:queuecommand("Set")
		end,
		JudgmentMessageCommand = function(self, params)
			self:playcommand("Set", params)
		end,
		PlayingUpdateMessageCommand = function(self)
			self:playcommand("Set")
		end,
		SetCommand = function(self, params)
			if params ~= nil and params.TapNoteScore == "TapNoteScore_AvoidMine" then
				return
			end
			self:finishtweening()
			self:smooth(0.1)
			local barMaxW = panelW - avatarSize - 44
			self:zoomx(PLife() * barMaxW)
			-- Color shift based on Life Difficulty and low life
			local life = PLife()
			if life < 0.3 and life > 0 then
				self:diffuse(HVColor.GetLifeBarColor("Danger"))
			elseif life <= 0 then
				self:diffuse(HVColor.GetLifeBarColor("Danger"))
			else
				local diff = GetLifeDifficulty()
				local lifeKey = "L7"
				if diff <= 1 then
					lifeKey = "L1"
				elseif diff == 2 then
					lifeKey = "L2"
				elseif diff == 3 then
					lifeKey = "L3"
				elseif diff == 4 then
					lifeKey = "L4"
				elseif diff == 5 then
					lifeKey = "L5"
				elseif diff == 6 then
					lifeKey = "L6"
				end
				self:diffuse(HVColor.GetLifeBarColor(lifeKey))
			end
		end
	},

	-- DP Display Frame
		Def.ActorFrame {
		Name = "DPDisplay",
		InitCommand = function(self)
			self:xy(-panelX, -12):halign(0)
			self:xy((MovableValues and MovableValues.DPDisplayX) or getDefaultGameplayCoordinate("DPDisplayX") or (-panelX), (MovableValues and MovableValues.DPDisplayY) or getDefaultGameplayCoordinate("DPDisplayY") or -12):zoom((MovableValues and MovableValues.DPDisplayZoom) or getDefaultGameplaySize("DPDisplayZoom") or 1)
			self:visible(not GAMESTATE:IsPracticeMode())
		end,
		JudgmentMessageCommand = function(self, msg)
			updateDPFromJudgment(msg)
		end,
		OnCommand = function(self)
			setMovableActor({"DeviceButton_period", "DeviceButton_slash"}, self, self:GetChild("Border"))
		end,

		-- DP% (above, larger font)
		LoadFont("Common Normal") .. {
			Name = "DPPercent",
			InitCommand = function(self)
				self:y(-18):halign(0):zoom(0.5)
				self:settext("0.00%")
				self:diffuse(color("#b3b3b3"))
			end,
			JudgmentMessageCommand = function(self, msg)
				self:stoptweening()
				
				local current_perc = pss:GetWifeScore() * 100
				if total_max > 0 then
					current_perc = math.max(0, (actual_dp / total_max) * 100)
				end
				
				self:settextf("%.2f%%", current_perc)
			end
		},

		-- Current DP score (larger font)
		LoadFont("Common Normal") .. {
			Name = "DPScore",
			InitCommand = function(self)
				self:y(0):halign(0):zoom(0.6)
				self:settext("0.00")
				self:diffuse(color("#ffffff"))
			end,
			JudgmentMessageCommand = function(self, msg)
				self:stoptweening()
				self:settextf("%.2f", actual_dp)
			end
		},

		-- Max score (smaller font, to the right of DP score)
		LoadFont("Common Normal") .. {
			Name = "MaxScore",
			InitCommand = function(self)
				self:y(0):x(42):halign(0):zoom(0.35)
				self:settextf("/ %d", total_max)
				self:diffuse(color("#888888"))
			end,
			JudgmentMessageCommand = function(self)
				self:stoptweening()
				local score = self:GetParent():GetChild("DPScore")
				if score then
					self:x(score:GetZoomedWidth() + 6)
				end
				self:settextf("/ %d", total_max)
			end
		},

		-- Movable border
		MovableBorder(120, 40, 1, 0, 0)
	},
}

return t
