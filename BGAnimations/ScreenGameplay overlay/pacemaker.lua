-- Holographic Void: Pacemaker graph (from someone on Discord)
-- Visual score meter comparing current score against personal best and a target goal.
-- Includes a real-time grade display, colored by HVColor.

local pn = GAMESTATE:GetEnabledPlayers()[1]
local baseline = SCREEN_HEIGHT * 0.385
local meterheight = SCREEN_HEIGHT * 0.725
local panelWidth = SCREEN_HEIGHT * 0.22
local panelPos = 1 -- 1 = right, -1 = left
local pm = 2 -- Default to right side (2)
if pm == 0 then
	return Def.ActorFrame {}
elseif pm == 1 then
	panelPos = -1
end

local notes = GAMESTATE:GetCurrentSteps(pn):GetRadarValues(pn):GetValue(0)
local progress = 0
local curPct = 0
local incPct = 0
local passflag = 0
local targetWife = 0
local wifePoints = 0
local targetPoints = 0
local zoomMode = "none" -- none | AA | AAA | AAAA
local zoomFloorPctDisplayed = 0
local zoomFloorPctStart = 0
local zoomFloorPctTarget = 0
local zoomFloorAnimStart = 0
local zoomFloorAnimDuration = 0.22
local zoomFloorAnimating = false

-- HV-themed colors
local colour = {
	Current = color("#00CFFF"),
	Target = color("#FF6B6B")
}

-- Grade table using HV's grade color system
local percent2grade = {
	{percent = 0,        grade = "D",     tier = "Tier16"},
	{percent = 60,       grade = "C",     tier = "Tier15"},
	{percent = 70,       grade = "B",     tier = "Tier14"},
	{percent = 80,       grade = "A",     tier = "Tier13"},
	{percent = 93.00,    grade = "AA",    tier = "Tier10"},
	{percent = 99.70,    grade = "AAA",   tier = "Tier07"},
	{percent = 99.955,   grade = "AAAA",  tier = "Tier04"},
	{percent = 99.9935,  grade = "AAAAA", tier = "Tier01"},
}

local function getGoalTrackerTargetWife()
	local mode = ThemePrefs.Get("HV_PacemakerTargetType") or "Target"
	if mode == "PB" or mode == "PBReplay" then
		local best = GetDisplayScore()
		if best then
			return getJ4NormalizedPercentage(best)
		end
	end
	return tonumber(ThemePrefs.Get("HV_PacemakerTargetGoal")) or 93
end

-- Abort completely if disabled via ThemePrefs
local showPacemakerGraph = ThemePrefs.Get("HV_ShowPacemakerGraph")
if not showPacemakerGraph then
	return Def.ActorFrame {}
end

-- Font zoom scaled up for HV visibility
local fontZoom = (SCREEN_HEIGHT / 1000) * 1.3
local fontZoomSmall = (SCREEN_HEIGHT / 1200) * 1.3
local fontZoomBigNum = fontZoomSmall * 1.35
local fontZoomSmallNum = fontZoomSmall * 0.95

local function splitFloatText(v)
	if v == nil then v = 0 end
	local s = string.format("%.2f", v)
	local whole, frac = s:match("^(%-?%d+)%.(%d+)$")
	if not whole then
		return s, ""
	end
	return whole, "." .. frac
end

local function updateSplitNumber(frame, value)
	local whole, frac = splitFloatText(value)
	local wholeActor = frame:GetChild("Whole")
	local fracActor = frame:GetChild("Frac")
	if not wholeActor or not fracActor then return end

	wholeActor:settext(whole)
	fracActor:settext(frac)

	local fracWidth = 0
	pcall(function()
		local zoom = (fracActor.GetZoomX and fracActor:GetZoomX()) or 1
		fracWidth = (fracActor:GetWidth() or 0) * zoom
	end)
	fracActor:xy(0, 0)
	wholeActor:xy(-fracWidth, 0)
end

local function safeGetPlayerStageStats()
	local ss = STATSMAN and STATSMAN:GetCurStageStats()
	if not ss or not ss.GetPlayerStageStats then return nil end
	return ss:GetPlayerStageStats(pn)
end

local function getCurrentWifePoints()
	local pss = safeGetPlayerStageStats()
	if pss and type(pss.GetWifePoints) == "function" then
		local ok, value = pcall(pss.GetWifePoints, pss)
		value = ok and tonumber(value) or nil
		if value then return value end
	end
	return nil
end

local function computeCurrentMaxPoints()
	if notes and notes > 0 then
		local notesPassed = math.max(0, math.min(progress, notes))
		return notesPassed * 2
	end
	return math.max(1, progress * 2)
end

local function computeTotalMaxPoints()
	if notes and notes > 0 then
		return notes * 2
	end
	return math.max(1, progress * 2)
end

local function recomputeScoresFromMessage(msg)
	local current = getCurrentWifePoints()
	if current == nil then
		-- Fallback: derive from current % and taps passed
		local maxPts = computeCurrentMaxPoints()
		current = (tonumber(curPct) or 0) / 100 * maxPts
	end
	wifePoints = current

	-- Prefer replay-based target differential when available (PBReplay live target).
	local diff = nil
	if msg and msg.WifePBDifferential ~= nil then
		diff = tonumber(msg.WifePBDifferential)
	elseif msg and msg.WifeDifferential ~= nil then
		diff = tonumber(msg.WifeDifferential)
	end
	if diff == nil then diff = 0 end
	targetPoints = current - diff

	-- Current accuracy percent (normalized to passed notes)
	local curMaxPts = computeCurrentMaxPoints()
	if curMaxPts > 0 then
		curPct = math.min((current / curMaxPts) * 100, 100)
	end

	-- Incremental percent (normalized to full chart points) for "Grade X cleared" thresholds.
	local totalMaxPts = computeTotalMaxPoints()
	if totalMaxPts > 0 then
		incPct = math.min((current / totalMaxPts) * 100, 100)
	end
end

local AA_THRESHOLD = 93.00
local AAA_THRESHOLD = 99.70
local AAAA_THRESHOLD = 99.955

local function getZoomMinPct()
	if zoomMode == "AAAA" then return AAAA_THRESHOLD end
	if zoomMode == "AAA" then return AAA_THRESHOLD end
	if zoomMode == "AA" then return AA_THRESHOLD end
	return 0
end

local function zoomActive()
	return zoomMode ~= "none"
end

local function scalePctForMeter(pct)
	local p = pct or 0
	if not zoomActive() then
		return math.max(0, math.min(1, p / 100))
	end
	local minPct = zoomFloorPctDisplayed
	local clamped = math.max(minPct, math.min(100, p))
	return (clamped - minPct) / (100 - minPct)
end

local function meterFillFromPoints(points)
	local maxPts = computeTotalMaxPoints()
	if maxPts <= 0 then return 0 end
	local pct = (points / maxPts) * 100
	return scalePctForMeter(pct)
end

local function tierVisibleInZoomMode(tierKey)
	if not zoomActive() then return false end
	if zoomMode == "AA" then
		-- Show AA family mids, plus higher major tiers.
		return tierKey == "Grade_Tier10" or tierKey == "Grade_Tier09" or tierKey == "Grade_Tier08"
			or tierKey == "Grade_Tier07" or tierKey == "Grade_Tier04" or tierKey == "Grade_Tier01"
	end
	if zoomMode == "AAA" then
		-- Show AAA family mids, plus higher major tiers.
		return tierKey == "Grade_Tier07" or tierKey == "Grade_Tier06" or tierKey == "Grade_Tier05"
			or tierKey == "Grade_Tier04" or tierKey == "Grade_Tier01"
	end
	if zoomMode == "AAAA" then
		-- Show AAAA family mids and top tier.
		return tierKey == "Grade_Tier04" or tierKey == "Grade_Tier03" or tierKey == "Grade_Tier02"
			or tierKey == "Grade_Tier01"
	end
	return false
end

local function animatePacemakerVisibility(self, visible)
	self:stoptweening()
	if visible then
		self:visible(true):diffusealpha(0):decelerate(0.18):diffusealpha(1)
	else
		self:accelerate(0.14):diffusealpha(0)
	end
end

local t = Def.ActorFrame {
	Name = "PaceMaker",

	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X + ((SCREEN_WIDTH - panelWidth) / 2 * panelPos), SCREEN_CENTER_Y)
		self:visible(not HV.MinimalisticMode())
		self:diffusealpha(HV.MinimalisticMode() and 0 or 1)
		zoomFloorPctDisplayed = 0
		zoomFloorPctStart = 0
		zoomFloorPctTarget = 0
		zoomFloorAnimating = false
		self:SetUpdateFunction(function(actor, delta)
			if not zoomFloorAnimating then return end
			local elapsed = os.clock() - zoomFloorAnimStart
			local alpha = math.min(1, elapsed / zoomFloorAnimDuration)
			local eased = 1 - math.pow(1 - alpha, 3)
			zoomFloorPctDisplayed = zoomFloorPctStart + (zoomFloorPctTarget - zoomFloorPctStart) * eased
			actor:playcommand("Update")
			actor:playcommand("UpdateGrade")
			if alpha >= 1 then
				zoomFloorAnimating = false
				zoomFloorPctDisplayed = zoomFloorPctTarget
			end
		end)
		targetWife = getGoalTrackerTargetWife()
		self:queuecommand("RefreshTarget")
	end,
	HV_MinimalisticModeChangedMessageCommand = function(self, params)
		animatePacemakerVisibility(self, not (params and params.Enabled))
	end,
	ThemePrefChangedMessageCommand = function(self, params)
		if not params or not params.Name then return end
		if params.Name == "HV_PacemakerTargetType" or params.Name == "HV_PacemakerTargetGoal" then
			self:queuecommand("RefreshTarget")
		end
	end,
	RefreshTargetCommand = function(self)
		targetWife = getGoalTrackerTargetWife()
		self:playcommand("Update")
	end,
	JudgmentMessageCommand = function(self, msg)
		if msg.Judgment == "TapNoteScore_W1" or
			msg.Judgment == "TapNoteScore_W2" or
			msg.Judgment == "TapNoteScore_W3" or
			msg.Judgment == "TapNoteScore_W4" or
			msg.Judgment == "TapNoteScore_W5" or
			msg.Judgment == "TapNoteScore_Miss" then
				progress = progress + 1
				curPct = msg.WifePercent
				recomputeScoresFromMessage(msg)
				local newZoomMode = zoomMode
				if incPct >= AAAA_THRESHOLD then
					newZoomMode = "AAAA"
				elseif incPct >= AAA_THRESHOLD then
					newZoomMode = "AAA"
				elseif incPct >= AA_THRESHOLD then
					newZoomMode = "AA"
				end
				if newZoomMode ~= zoomMode then
					zoomMode = newZoomMode
					self:playcommand("ZoomModeChanged")
				end
				self:playcommand("Update")
				local nextGrade = percent2grade[passflag + 1]
				if nextGrade and incPct >= nextGrade.percent then
				for j = 1, #percent2grade do
					if incPct >= percent2grade[j].percent then
						passflag = j
					end
				end
				self:playcommand("UpdateGrade")
			end
		end
	end,
	ZoomModeChangedCommand = function(self)
		-- Do not animate the whole graph container (avoids pop/jump).
		self:stoptweening()
		zoomFloorPctStart = zoomFloorPctDisplayed
		zoomFloorPctTarget = getZoomMinPct()
		zoomFloorAnimStart = os.clock()
		zoomFloorAnimating = true
		self:playcommand("Update")
		self:playcommand("UpdateGrade")
	end,

	-- Panel background
			Def.Quad {
		InitCommand = function(self)
			self:zoomto(panelWidth, SCREEN_HEIGHT)
			self:diffuse(0.03, 0.03, 0.03, 0.85)
		end,
	},

	-- Current score meter
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(-0.20 * panelWidth * panelPos, baseline)
		end,
		Def.Quad {
			InitCommand = function(self)
				self:align(0.5, 1)
				self:zoomto(panelWidth * 0.30, 0)
				self:diffuse(colour.Current)
				self:diffusealpha(0.2)
			end,
				UpdateCommand = function(self)
					self:zoomtoheight(meterheight * meterFillFromPoints(wifePoints))
				end,
			},
		Def.Quad {
			InitCommand = function(self)
				self:align(0.5, 1)
				self:zoomto(panelWidth * 0.30, 0)
				self:diffuse(colour.Current)
				self:diffusealpha(0.75)
			end,
				UpdateCommand = function(self)
					self:zoomtoheight(meterheight * meterFillFromPoints(wifePoints))
				end,
			},
		},

	-- Target score meter
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(0.20 * panelWidth * panelPos, baseline)
		end,
		Def.Quad {
			InitCommand = function(self)
				self:align(0.5, 1)
				self:zoomto(panelWidth * 0.30, 0)
				self:diffuse(colour.Target):diffusealpha(0.2)
			end,
				UpdateCommand = function(self)
					self:zoomtoheight(meterheight * meterFillFromPoints(targetPoints))
				end,
			},
		Def.Quad {
			InitCommand = function(self)
				self:align(0.5, 1)
				self:zoomto(panelWidth * 0.30, 0)
				self:diffuse(colour.Target)
				self:diffusealpha(0.75)
			end,
				UpdateCommand = function(self)
					self:zoomtoheight(meterheight * meterFillFromPoints(targetPoints))
				end,
			},
		},

	-- Top text (left side)
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(-panelWidth * 0.48, -SCREEN_HEIGHT * 0.410)
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:align(0, 1):zoom(fontZoomSmall)
				self:settext("Current"):y(-30)
				self:diffusealpha(0.5)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:align(0, 1):zoom(fontZoomSmall)
				self:settext("Target"):y(-16)
				self:diffusealpha(0.5)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:align(0, 1):zoom(fontZoomSmall)
				self:diffuse(colour.Current)
				self:settext("")
				self:visible(false)
			end,
		},
		},

	-- Top text (right side)
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(panelWidth * 0.48, -SCREEN_HEIGHT * 0.410)
		end,
		-- Current Wife number (big whole, smaller decimals)
		Def.ActorFrame {
			Name = "CurrentWife",
			InitCommand = function(self)
				self:y(-30):playcommand("Update")
			end,
			UpdateCommand = function(self)
				updateSplitNumber(self, wifePoints)
			end,
			LoadFont("Common Normal") .. {
				Name = "Whole",
				InitCommand = function(self)
					self:align(1, 1):zoom(fontZoomBigNum):diffuse(colour.Current):diffusealpha(0.85)
				end,
			},
			LoadFont("Common Normal") .. {
				Name = "Frac",
				InitCommand = function(self)
					self:align(1, 1):zoom(fontZoomSmallNum):diffuse(colour.Current):diffusealpha(0.75)
				end,
			},
		},
		-- Target Wife number (big whole, smaller decimals)
		Def.ActorFrame {
			Name = "TargetWife",
			InitCommand = function(self)
				self:y(-16):playcommand("Update")
			end,
			UpdateCommand = function(self)
				updateSplitNumber(self, targetPoints)
			end,
			LoadFont("Common Normal") .. {
				Name = "Whole",
				InitCommand = function(self)
					self:align(1, 1):zoom(fontZoomBigNum):diffuse(colour.Target):diffusealpha(0.85)
				end,
			},
			LoadFont("Common Normal") .. {
				Name = "Frac",
				InitCommand = function(self)
					self:align(1, 1):zoom(fontZoomSmallNum):diffuse(colour.Target):diffusealpha(0.75)
				end,
			},
		},
	},

	-- Bottom text + Real-Time Grade Display
	Def.ActorFrame {
		-- Real-time Grade (colored by HV grade colors)
		LoadFont("Common Normal") .. {
			Name = "PacemakerGrade",
			InitCommand = function(self)
				self:zoom(fontZoom * 1.8)
				self:valign(1)
				self:y(baseline - 10)
				self:diffusealpha(0.8)
				self:settext("")
			end,
			UpdateGradeCommand = function(self)
				if passflag > 0 and passflag <= #percent2grade then
					local g = percent2grade[passflag]
					self:settext(g.grade)
					self:diffuse(HVColor.GetGradeColor(g.grade))
				end
			end,
			UpdateCommand = function(self)
				-- Also update on every judgment in case the grade mapping changes
				local wifePct = math.max(0, incPct)
				local gradeStr = "D"
				for j = 1, #percent2grade do
					if wifePct >= percent2grade[j].percent then
						gradeStr = percent2grade[j].grade
					end
				end
				self:settext(gradeStr)
				self:diffuse(HVColor.GetGradeColor(gradeStr))
			end,
		},
		Def.ActorFrame {
			Name = "TargetDiff",
			InitCommand = function(self)
				self:y(baseline + (SCREEN_HEIGHT * 0.064))
				self:x(0.20 * panelWidth * panelPos)
			end,
			LoadFont("Common Normal") .. {
				Name = "Label",
				InitCommand = function(self)
					self:align(1, 0):zoom(fontZoomSmall * 1.05)
					self:settext("Target")
					self:diffusealpha(0.5)
					self:x(-6)
				end
			},
			LoadFont("Common Normal") .. {
				Name = "Value",
				InitCommand = function(self)
					self:align(0, 0):zoom(fontZoomSmall * 1.05)
					self:settext("")
					self:diffusealpha(0.9)
				end,
				UpdateCommand = function(self)
					local diff = (tonumber(wifePoints) or 0) - (tonumber(targetPoints) or 0)
					self:settextf("%+.2f", diff)
					if diff >= 0 then
						self:diffuse(HVColor.GetGoalTrackerColor("positive"))
					else
						self:diffuse(HVColor.GetGoalTrackerColor("negative"))
					end
				end,
			},
		},
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(panelWidth, 2):y(baseline):align(0.5, 0)
				self:diffusealpha(0.3)
			end,
			UpdateCommand = function(self)
				if incPct > 0 then
					self:diffuse(color("#00CFFF66"))
				end
			end
		},
	},
}

-- Grade tier markers along the meter
-- Displaying C, B, A, AA, AAA, AAAA, AAAAA (Indices 2 to 8 in percent2grade)
-- Static grade tier markers (C, B, A, AA)
for i = 2, 5 do
	t[#t + 1] = Def.ActorFrame {
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(panelWidth, SCREEN_HEIGHT / 300)
				self:y(baseline - (meterheight * percent2grade[i].percent / 100))
				self:align(0.5, 1)
				self:diffusealpha(0.3)
			end,
			UpdateCommand = function(self)
				self:visible(not zoomActive())
			end,
			UpdateGradeCommand = function(self)
				if passflag >= i then
					self:diffuse(color("#00CFFF66"))
				end
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-panelWidth * 0.5 * panelPos, baseline - (meterheight * percent2grade[i].percent / 100) - 2)
				self:align((1 - panelPos) / 2, 1)
				self:settext(percent2grade[i].grade)
				self:zoom(fontZoomSmall)
				self:diffusealpha(0.3)
			end,
			UpdateCommand = function(self)
				self:visible(not zoomActive())
			end,
			UpdateGradeCommand = function(self)
				if passflag == i then
					self:diffusealpha(0.7)
					local g = percent2grade[passflag]
					self:settext(g.grade)
					self:diffuse(HVColor.GetGradeColor(g.grade))
				end
			end
		},
	}
end

	-- Zoom mode markers (AA -> 100%) including midgrades
	do
		local zoomTiers = {
			"Grade_Tier10", -- AA
		"Grade_Tier09", -- AA.
		"Grade_Tier08", -- AA:
		"Grade_Tier07", -- AAA
		"Grade_Tier06", -- AAA.
		"Grade_Tier05", -- AAA:
		"Grade_Tier04", -- AAAA
		"Grade_Tier03", -- AAAA.
		"Grade_Tier02", -- AAAA:
		"Grade_Tier01", -- AAAAA
	}

		for _, tierKey in ipairs(zoomTiers) do
			local pct = (WifeTiers and WifeTiers[tierKey] or 0) * 100
			t[#t + 1] = Def.ActorFrame {
				Name = "ZoomTierMarker_" .. tierKey,
				UpdateCommand = function(self)
					local active = zoomActive() and tierVisibleInZoomMode(tierKey) and pct >= getZoomMinPct()
					self:visible(active)
					if not active then return end
					self:y(baseline - (meterheight * scalePctForMeter(pct)))
				end,
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(panelWidth, SCREEN_HEIGHT / 300)
					self:align(0.5, 1)
					self:diffusealpha(0.3)
				end,
			},
			LoadFont("Common Normal") .. {
				Name = "Label",
				InitCommand = function(self)
					self:xy(-panelWidth * 0.5 * panelPos, -2)
					self:align((1 - panelPos) / 2, 1)
					self:settext(HV.GetGradeName(tierKey))
					self:zoom(fontZoomSmall)
					self:diffusealpha(0.3)
				end,
					UpdateCommand = function(self)
						if not (zoomActive() and tierVisibleInZoomMode(tierKey) and pct >= getZoomMinPct()) then
							self:visible(false)
							return
						end
						self:visible(true)
						if incPct >= pct then
							self:diffusealpha(0.7)
							self:diffuse(HVColor.GetGradeColor(tierKey))
						else
							self:diffuse(color("#FFFFFF4D"))
						end
					end,
				},
			}
		end
	end

-- Dynamic high-tier marker (AAA -> AAAA -> AAAAA)
t[#t + 1] = Def.ActorFrame {
	Name = "DynamicHighTier",
	Def.Quad {
		Name = "Line",
		InitCommand = function(self)
			self:zoomto(panelWidth, SCREEN_HEIGHT / 300)
			self:align(0.5, 1)
			self:diffusealpha(0.3)
			self:playcommand("UpdateGrade")
		end,
			UpdateGradeCommand = function(self)
				local targetIdx = math.max(6, math.min(8, passflag))
				local g = percent2grade[targetIdx]
				self:y(baseline - (meterheight * scalePctForMeter(g.percent)))
				if passflag >= targetIdx then
					self:diffuse(color("#00CFFF66"))
				else
					self:diffuse(color("#FFFFFF4D"))
				end
		end
	},
	LoadFont("Common Normal") .. {
		Name = "Label",
		InitCommand = function(self)
			self:align((1 - panelPos) / 2, 1)
			self:zoom(fontZoomSmall)
			self:diffusealpha(0.3)
			self:playcommand("UpdateGrade")
		end,
			UpdateGradeCommand = function(self)
				local targetIdx = math.max(6, math.min(8, passflag))
				local g = percent2grade[targetIdx]
				self:xy(-panelWidth * 0.5 * panelPos, baseline - (meterheight * scalePctForMeter(g.percent)) - 2)
				self:settext(g.grade)
				
				if passflag >= targetIdx then
					self:diffusealpha(0.7)
				self:diffuse(HVColor.GetGradeColor(g.grade))
			else
				self:diffuse(color("#FFFFFF4D"))
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:align(0.5, 1):zoom(fontZoom)
			self:diffusealpha(0)
		end,
		UpdateGradeCommand = function(self)
			if passflag >= 6 then
				self:stoptweening()
				local g = percent2grade[passflag]
				self:settext("Rank " .. g.grade .. " Pass")
				self:diffusealpha(0):x(panelWidth * panelPos):linear(0.2):diffusealpha(1):x(0)
				self:sleep(1):linear(0.2):x(panelWidth * panelPos):diffusealpha(0)
			end
		end
	},
}

return t
