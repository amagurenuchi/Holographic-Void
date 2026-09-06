-- Holographic Void: ScreenChartPreview Overlay
-- Integrated sc-wh logic with HV Aesthetics (Glassmorphism, Accents, OLED Blacks).
-- oh yea the hovering on CDgraph is broken. i might or might not fix it

local pn = PLAYER_1
local song = GAMESTATE:GetCurrentSong()
local steps = GAMESTATE:GetCurrentSteps()

-- Global state
local ssm = nil
local musicratio = 1
local snapGraph = nil
local densityGraph = nil
local musicLength = 0
local inputCallback = nil

-- Safe fallbacks for engine globals that may not exist in all contexts
local function getCurRateValue()
	local ok, rate = pcall(function()
		return GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate()
	end)
	return (ok and type(rate) == "number") and rate or 1.0
end

local function changeMusicRate(delta)
	local curRate = getCurRateValue()
	-- Round to 2 dp to avoid floating-point drift (matches adjustRate in song select)
	local newRate = math.floor((curRate + delta) * 100 + 0.5) / 100
	newRate = math.max(0.05, math.min(3.0, newRate))
	pcall(function()
		GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(newRate)
		GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate(newRate)
		GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(newRate)
	end)
	MESSAGEMAN:Broadcast("CurrentRateChanged", {rate = newRate, oldRate = curRate})
end

-- References for sync
local noteFieldRef = nil
local progressRef = nil
local cdgFrameRef = nil
local rootRef = nil
local cdgInfoTimeRef = nil
local cdgInfoBPMRef  = nil
local cdgInfoNPSRef  = nil

local musicStartTime = 0
local musicStartOffset = 0
local isPaused = false
local pausedPos = 0
local visualSeekActive = false
local visualSeekStartTime = 0
local visualSeekStartPos = 0

local fullSongMode = false

local function syncPreviewSongPosition(pos)
	local screen = ssm or SCREENMAN:GetTopScreen()
	if not screen or not screen.SetSongPosition then return end

	local ok = pcall(function()
		screen:SetSongPosition(pos, 0, false)
	end)
	if not ok then
		pcall(function()
			screen:SetSongPosition(pos)
		end)
	end
end

local function setPreviewClock(pos)
	if not song then return end
	pos = math.max(0, pos or 0)
	local td = song:GetTimingData()
	if not td then return end

	local beat = td:GetBeatFromElapsedTime(pos)

	pcall(function()
		Actor.SetBGMTime(pos, beat, pos, beat)
	end)
	pcall(function()
		Actor.SetPlayerBGMBeat(beat, beat)
	end)
end

local function applyPreviewPosition(pos)
	pos = math.max(0, math.min(pos or 0, musicLength > 0 and musicLength or math.huge))
	setPreviewClock(pos)

	if progressRef then
		local p = math.min(pos / math.max(1, musicLength), 1)
		progressRef:stoptweening():zoomto(p * (SCREEN_WIDTH - 40), 2)
	end

	if cdgFrameRef then
		local seek = cdgFrameRef:GetChild("ProgressMarker")
		if seek then
			local p = math.min(pos / math.max(1, musicLength), 1)
			seek:x(p * (SCREEN_WIDTH - 120) - (SCREEN_WIDTH - 120) / 2)
		end
	end
end

local function scheduleVerifiedSeek(pos)
	pos = math.max(0, pos or 0)
	if not rootRef then return end
	rootRef.pendingSeekPos = pos
	rootRef:stoptweening():sleep(0.04):queuecommand("PerformSeek")
end

local function startVisualSeekClock(pos)
	visualSeekActive = true
	visualSeekStartTime = GetTimeSinceStart()
	visualSeekStartPos = math.max(0, pos or 0)
end

local function playFrom(pos, forceRestart, isInitialOpen)
	if not song then return end
	isPaused = false
	local screen = ssm or SCREENMAN:GetTopScreen()
	if not screen then return end
	
	if isInitialOpen or forceRestart or not fullSongMode then
		-- Stop any bgm.lua-managed stream and hand ownership to the screen's
		-- sample-music system (required for GetSampleMusicPosition / updateSync).
		SOUND:StopMusic()
		screen:PlayCurrentSongSampleMusic(true, true)
		fullSongMode = true
		-- isInitialOpen: seek is deferred to PlayingSampleMusicMessageCommand
		-- so the stream is guaranteed to be ready before we seek.
		if not isInitialOpen and screen.SetSampleMusicPosition then
			screen:SetSampleMusicPosition(pos)
		end
	else
		if screen.SetSampleMusicPosition then
			screen:SetSampleMusicPosition(pos)
		end
	end
end

-- Helper: format seconds as m:ss.x
local function formatTime(s)
	if not s or s < 0 then return "-:--" end
	local m = math.floor(s / 60)
	local sec = s - m * 60
	return string.format("%d:%04.1f", m, sec)
end

-- HV Aesthetics constants
local accentColor = HVColor.Accent
local textDim = HVColor.TextDim
local textSub = HVColor.TextSub
local textMain = HVColor.Text
local textBright = HVColor.TextBright
local bgCard = HVColor.BG2
local bgDark = HVColor.BG1

-- Layout constants
local sidePanelWidth = 140
local headerHeight = 60
local footerHeight = 100
local innerPadding = 10
local frameWidth = SCREEN_WIDTH - (sidePanelWidth * 2) - (innerPadding * 4)
local frameHeight = SCREEN_HEIGHT - headerHeight - footerHeight - (innerPadding * 4)

-- Helper: Steps identification
local stepsTable = {}
local curStepIndex = 0

local function findCurStepIndex(givenSteps)
	if not givenSteps then return 0 end
	for i = 1, #stepsTable do
		if stepsTable[i]:GetChartKey() == givenSteps:GetChartKey() then
			return i
		end
	end
	return 0
end

local function meterComparator(stepA, stepB)
	return Enum.Reverse(Difficulty)[stepA:GetDifficulty()] < Enum.Reverse(Difficulty)[stepB:GetDifficulty()]
end

-- HV Helper fallbacks
local function getDifficultyShort(diff)
	local d = ToEnumShortString(diff):gsub("Difficulty_", "")
	local map = {
		Beginner = "BG",
		Easy = "EZ",
		Medium = "MD",
		Hard = "HD",
		Challenge = "CH",
		Edit = "ED"
	}
	return map[d] or d:sub(1,2):upper()
end

local function getDifficultyColor(diff)
	return HVColor and HVColor.GetDifficultyColor(diff) or textBright
end

local function GetCustomDifficulty(stype, diff)
	return diff
end

local function getSongLengthColor(len)
	return HVColor and HVColor.GetSongLengthColor(len) or textBright
end

function getMSDColor(msd)
	if not msd or msd == 0 then return textDim end
	return (HVColor and HVColor.GetMSDRatingColor) and HVColor.GetMSDRatingColor(msd) or textBright
end


------------------------------------------------------------
-- AUDIO CONTROL & SYNC
------------------------------------------------------------
local function updateSync(self)
	if isPaused then
		applyPreviewPosition(pausedPos)
		-- Still update tooltip while paused
		return
	end
	if not ssm then return end
	
	local pos = ssm:GetSampleMusicPosition()
	if visualSeekActive then
		local visualPos = visualSeekStartPos + ((GetTimeSinceStart() - visualSeekStartTime) * math.max(MIN_MUSIC_RATE, getCurRateValue()))
		if pos and math.abs(pos - visualPos) < 0.15 then
			visualSeekActive = false
		else
			pos = visualPos
		end
	end
	if pos > musicLength then pos = musicLength end

	applyPreviewPosition(pos)

	-- CDG hover + info bar update
	local cdgX = SCREEN_CENTER_X - (SCREEN_WIDTH - 120)/2
	local cdgY = SCREEN_HEIGHT - 60 - 40  -- frame center minus half height
	local cdgW = SCREEN_WIDTH - 120
	local cdgH = 80
	local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
	local inGraph = mx >= cdgX and mx <= cdgX + cdgW and my >= cdgY and my <= cdgY + cdgH

	-- Update NPS tooltip (floating)
	if npsTooltipActor and rootRef and rootRef:GetVisible() and steps then
		if inGraph then
			npsTooltipActor:visible(true)
			npsTooltipActor:xy(mx + 15, my - 35)
			
			local relX = mx - cdgX
			local p = math.max(0, math.min(1, relX / cdgW))
			
			local rate = math.max(MIN_MUSIC_RATE, getCurRateValue())
			local vectors = steps:GetCDGraphVectors(rate)
			
			if vectors and vectors[1] and #vectors[1] > 0 then
				local npsV = vectors[1]
				local idx = math.floor(p * #npsV) + 1
				idx = math.max(1, math.min(#npsV, idx))
				local nps = npsV[idx]
				local textActor = npsTooltipActor:GetChild("NPSText")
				if textActor then textActor:settextf("%.1f NPS", nps) end
			else
				local textActor = npsTooltipActor:GetChild("NPSText")
				if textActor then textActor:settext("no data") end
			end
		else
			npsTooltipActor:visible(false)
		end
	elseif npsTooltipActor then
		npsTooltipActor:visible(false)
	end

	-- Helper: BPM at a given elapsed-time position (rate-adjusted)
	local function getBPMAt(t)
		local td = song and song:GetTimingData()
		if not td then return 0 end
		local beat = td:GetBeatFromElapsedTime(t)
		local bpm  = td:GetBPMAtBeat(beat)
		return bpm * math.max(MIN_MUSIC_RATE, getCurRateValue())
	end

	-- Helper: NPS at a proportion p (0–1)
	local function getNPSAt(p)
		local rate = math.max(MIN_MUSIC_RATE, getCurRateValue())
		local vectors = steps:GetCDGraphVectors(rate)
		if not (vectors and vectors[1] and #vectors[1] > 0) then return 0 end
		local npsV = vectors[1]
		local idx = math.floor(p * #npsV) + 1
		idx = math.max(1, math.min(#npsV, idx))
		return npsV[idx]
	end

	-- Update info bar below CDG
	if cdgInfoTimeRef and cdgInfoBPMRef and cdgInfoNPSRef and steps then
		if inGraph then
			-- Hover mode: show hovered timestamp, BPM, and NPS in accent color
			local relX    = mx - cdgX
			local p       = math.max(0, math.min(1, relX / cdgW))
			local hoverT  = p * musicLength
			local hoverBPM = getBPMAt(hoverT)
			local hoverNPS = getNPSAt(p)

			cdgInfoTimeRef:settextf("%s",         formatTime(hoverT)):diffuse(accentColor)
			cdgInfoBPMRef :settextf("%.0f BPM",   hoverBPM):diffuse(accentColor)
			cdgInfoNPSRef :settextf("%.1f NPS",   hoverNPS):diffuse(accentColor)
		else
			-- Normal mode: show current playback values in dim colors
			local p      = math.max(0, math.min(1, pos / math.max(1, musicLength)))
			local curBPM = getBPMAt(pos)
			local curNPS = getNPSAt(p)

			cdgInfoTimeRef:settextf("%s",         formatTime(pos)):diffuse(textDim)
			cdgInfoBPMRef :settextf("%.0f BPM",   curBPM):diffuse(textSub)
			cdgInfoNPSRef :settextf("%.1f NPS",   curNPS):diffuse(textSub)
		end
	end
	
	-- MSD Tooltip hover check
	if msdTooltipActor and rootRef and rootRef:GetVisible() then
		local rightSidebar = rootRef:GetChild("RightSidebar")
		local chartPanelRef = rightSidebar and rightSidebar:GetChild("ChartPanel")
		local hoveredSteps = nil
		if chartPanelRef and chartPanelRef:GetVisible() then
			local list = chartPanelRef:GetChild("List")
			if list then
				local diffs = {"Beginner", "Easy", "Medium", "Hard", "Challenge", "Edit"}
				for _, d in ipairs(diffs) do
					local short = getDifficultyShort("Difficulty_"..d)
					local item = list:GetChild("Item_" .. short)
					if item then
						local clickArea = item:GetChild("ClickArea")
						if clickArea and clickArea:GetVisible() and isOver(clickArea) then
							hoveredSteps = chartPanelRef.available and chartPanelRef.available[d]
							break
						end
					end
				end
			end
		end
		
		if hoveredSteps and HV.ShowMSD() then
			local mx2, my2 = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
			msdTooltipActor:visible(true):xy(mx2 + 5, my2 - 15)
			msdTooltipActor:playcommand("SetHover", {steps = hoveredSteps})
		else
			msdTooltipActor:visible(false)
		end
	end
end

------------------------------------------------------------
-- INPUT HANDLING
------------------------------------------------------------
local function input(event)
	-- Guard: if the overlay isn't visible the callback is stale — drop silently.
	-- This also protects against the callback firing after RemoveInputCallback races.
	if not rootRef or not rootRef:GetVisible() then return false end

	if event.type ~= "InputEventType_FirstPress" then return false end
	local btn = event.DeviceInput.button

	-- Close mechanisms — sink the event only.
	-- MasterInputSink is the sole authority for broadcasting ChartPreviewOff
	-- so that previewActive and HV.ChartPreviewActive stay in sync.
	if btn == "DeviceButton_escape" or event.button == "Back" or event.button == "Start" then
		return true
	end

	-- Keyboard Rate Control (EffectUp/EffectDown are logical game buttons)
	if event.button == "EffectUp" then
		changeMusicRate(0.05)
		return true
	end
	if event.button == "EffectDown" then
		changeMusicRate(-0.05)
		return true
	end

	-- Mouse Interaction
	if btn == "DeviceButton_left mouse button" then
		if not rootRef or not rootRef:GetVisible() then return false end

		-- Difficulty Selection (New Location: RightSidebar -> ChartPanel)
		local chartPanelRef = rootRef:GetChild("RightSidebar"):GetChild("ChartPanel")
		if chartPanelRef then
			local list = chartPanelRef:GetChild("List")
			local diffs = {"Beginner", "Easy", "Medium", "Hard", "Challenge", "Edit"}
			for i, d in ipairs(diffs) do
				local short = getDifficultyShort("Difficulty_"..d)
				local item = list:GetChild("Item_" .. short)
				if item and isOver(item:GetChild("ClickArea")) then
					local s = chartPanelRef.available and chartPanelRef.available[d]
					if s then
						GAMESTATE:SetCurrentSteps(PLAYER_1, s)
						steps = s
						MESSAGEMAN:Broadcast("ReloadChartPreview")
						return true
					end
				end
			end
		end

		-- Rate Control
		local rateFrame = rootRef:GetChild("HeaderFrame"):GetChild("RateController")
		if rateFrame then
			if isOver(rateFrame:GetChild("Dec")) then 
				changeMusicRate(-0.05)
				return true 
			end
			if isOver(rateFrame:GetChild("Inc")) then 
				changeMusicRate(0.05)
				return true 
			end
		end

		-- Seek on CDG
		if cdgFrameRef then
			local clickArea = cdgFrameRef:GetChild("ClickArea")
			if isOver(clickArea) then
				local mx = INPUTFILTER:GetMouseX()
				local fx = cdgFrameRef:GetTrueX() - (SCREEN_WIDTH - 120)/2
				local p = (mx - fx) / (SCREEN_WIDTH - 120)
				p = math.max(0, math.min(1, p))
				local pos = p * musicLength
				pausedPos = pos
				startVisualSeekClock(pos)
				syncPreviewSongPosition(pos)
				applyPreviewPosition(pos)
				playFrom(pos)
				scheduleVerifiedSeek(pos)
				return true
			end
		end
	end

	-- Right click to pause/unpause
	if btn == "DeviceButton_right mouse button" then
		if ssm and ssm.PauseSampleMusic then
			-- Capture exact position BEFORE toggling pause to avoid frame slip
			if not isPaused then
				pausedPos = ssm:GetSampleMusicPosition() or 0
			end
			ssm:PauseSampleMusic()
			isPaused = not isPaused
			MESSAGEMAN:Broadcast("MusicPauseToggled")
			if rootRef then
				local text = rootRef:GetChild("NoteFieldContainer"):GetChild("PausedText")
				if text then text:diffusealpha(isPaused and 1 or 0) end
			end
		end
		return true
	end

	return true -- Sink ALL input while preview is active
end

------------------------------------------------------------
-- UI COMPONENTS
------------------------------------------------------------

-- 1. HEADER (Song Info + Diff + Rate)
local function header()
	return Def.ActorFrame {
		Name = "HeaderFrame",
		InitCommand = function(self) self:xy(SCREEN_CENTER_X, 40) end,
		ReloadCommand = function(self) self:RunCommandsOnChildren(function(c) c:playcommand("Reload") end) end,
		-- Glassmorphism Base
		Def.Quad { InitCommand = function(self) self:zoomto(SCREEN_WIDTH - 40, 60):diffuse(bgCard):diffusealpha(0.9) end },
		Def.Quad { InitCommand = function(self) self:zoomto(SCREEN_WIDTH - 40, 1):valign(0):y(-30):diffuse(accentColor):diffusealpha(0.5) end },
		
		-- Song Data
		Def.ActorFrame {
			Name = "SongInfo",
			InitCommand = function(self) self:x(-(SCREEN_WIDTH-40)/2 + 20) end,
			LoadFont("Common Normal") .. {
				Name = "Title",
				ReloadCommand = function(self) self:settext(song:GetMainTitle()):zoom(0.6):halign(0):y(-10):diffuse(textBright) end
			},
			LoadFont("Common Normal") .. {
				Name = "Artist",
				ReloadCommand = function(self) self:settext(song:GetDisplayArtist()):zoom(0.35):halign(0):y(10):diffuse(textSub) end
			}
		},

		-- Rate Controller
		Def.ActorFrame {
			Name = "RateController",
			InitCommand = function(self) self:x((SCREEN_WIDTH-40)/2 - 100) end,
			Def.Quad { Name = "Dec", InitCommand = function(self) self:x(-60):zoomto(30, 40):diffusealpha(0) end },
			Def.Quad { Name = "Inc", InitCommand = function(self) self:x(60):zoomto(30, 40):diffusealpha(0) end },
			LoadFont("Common Normal") .. { InitCommand = function(self) self:x(-60):settext("<"):zoom(0.6):diffuse(textDim) end },
			LoadFont("Common Normal") .. { InitCommand = function(self) self:x(60):settext(">"):zoom(0.6):diffuse(textDim) end },
			LoadFont("Common Normal") .. {
				Name = "RateVal",
				ReloadCommand = function(self) 
					local rate = getCurRateValue()
					self:settextf("%.2fx", rate):zoom(0.5):diffuse(accentColor)
				end
			},
			LoadFont("Common Normal") .. {
				Name = "BPM",
				ReloadCommand = function(self)
					local curSong = song or GAMESTATE:GetCurrentSong()
					if curSong then
						local rate = getCurRateValue()
						local bpms = curSong:GetDisplayBpms(true)
						local b1 = bpms[1] * rate
						local b2 = bpms[2] * rate
						if math.abs(b1 - b2) < 1 then
							self:settext(string.format("%.0f BPM", b1)):y(18):zoom(0.25):diffuse(textDim)
						else
							self:settext(string.format("%.0f-%.0f BPM", b1, b2)):y(18):zoom(0.25):diffuse(textDim)
						end
					else
						self:settext("--- BPM"):y(18):zoom(0.25):diffuse(textDim)
					end
				end
			}
		},

	}
end

-- 2. SIDEBARS (Skillsets & Analysis)
local function skillsetPanel()
	local skillsets = {"Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical"}
	return Def.ActorFrame {
		Name = "SkillsetPanel",
		InitCommand = function(self)
			self:visible(HV.ShowMSD())
		end,
		Def.Quad { InitCommand = function(self) self:zoomto(sidePanelWidth, 300):diffuse(bgCard):diffusealpha(0.8) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:y(-135):settext("SKILLSETS"):zoom(0.4):diffuse(accentColor) end },
		Def.ActorFrame {
			Name = "Grid",
			InitCommand = function(self) self:y(-110) end,
		} .. (function()
			local rows = {}
			for i, ss in ipairs(skillsets) do
				rows[#rows+1] = Def.ActorFrame {
					Name = "Row"..i,
					InitCommand = function(self) self:y((i-1)*30) end,
					LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(-sidePanelWidth/2 + 10):settext(ss:upper()):zoom(0.25):diffuse(textSub) end },
					LoadFont("Common Normal") .. {
						Name = "Val",
						ReloadCommand = function(self)
							local val = steps:GetMSD(getCurRateValue(), i)
							if val > 0 then
								self:settextf("%.2f", val):diffuse(HVColor.GetMSDRatingColor(val))
							else
								self:settext("-"):diffuse(textDim)
							end
							self:halign(1):x(sidePanelWidth/2 - 10):zoom(0.35)
						end
					}
				}
			end
			return rows
		end)()
	}
end

local function radarPanel()
	local categories = {
		{"TAPS", "RadarCategory_Notes"}, {"JUMPS", "RadarCategory_Jumps"}, {"HANDS", "RadarCategory_Hands"},
		{"HOLDS", "RadarCategory_Holds"}, {"ROLLS", "RadarCategory_Rolls"}, {"MINES", "RadarCategory_Mines"}
	}
	return Def.ActorFrame {
		Name = "RadarPanel",
		Def.Quad { InitCommand = function(self) self:zoomto(sidePanelWidth, 300):diffuse(bgCard):diffusealpha(0.8) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:y(-135):settext("ANALYSIS"):zoom(0.4):diffuse(accentColor) end },
		Def.ActorFrame {
			Name = "Grid",
			InitCommand = function(self) self:y(-110) end,
		} .. (function()
			local rows = {}
			for i, c in ipairs(categories) do
				rows[#rows+1] = Def.ActorFrame {
					Name = "Row"..i,
					InitCommand = function(self) self:y((i-1)*30) end,
					LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(-sidePanelWidth/2 + 10):settext(c[1]):zoom(0.25):diffuse(textSub) end },
					LoadFont("Common Normal") .. {
						Name = "Val",
						ReloadCommand = function(self)
							local val = steps:GetRadarValues(pn):GetValue(c[2])
							self:settext(val):halign(1):x(sidePanelWidth/2 - 10):zoom(0.35):diffuse(textBright)
						end
					}
				}
			end
			return rows
		end)()
	}
end

-- 2. CHART Panel (New Difficulty Selector)
local function chartPanel()
	local diffs = {"Beginner", "Easy", "Medium", "Hard", "Challenge", "Edit"}
	return Def.ActorFrame {
		Name = "ChartPanel",
		ReloadCommand = function(self)
			stepsTable = song:GetStepsByStepsType(steps:GetStepsType())
			self.available = {}
			for _, s in ipairs(stepsTable) do
				local dStr = ToEnumShortString(s:GetDifficulty()):gsub("Difficulty_", "")
				self.available[dStr] = s
			end
			self:RunCommandsOnChildren(function(c) c:playcommand("Update") end)
		end,

		LoadFont("Common Normal") .. { 
			InitCommand = function(self) self:y(-135):settext("CHART"):zoom(0.4):diffuse(accentColor) end 
		},

		Def.ActorFrame {
			Name = "List",
			InitCommand = function(self) self:y(-100) end,
		} .. (function()
			local items = {}
			for i, d in ipairs(diffs) do
				local short = getDifficultyShort("Difficulty_"..d)
				items[#items+1] = Def.ActorFrame {
					Name = "Item_" .. short,
					InitCommand = function(self) self:y((i-1)*30) end,
					
					Def.Quad {
						Name = "Bg",
						InitCommand = function(self) self:zoomto(sidePanelWidth - 10, 26):diffuse(bgDark):diffusealpha(0.8) end,
						UpdateCommand = function(self)
							local panel = self:GetParent():GetParent():GetParent()
							local s = panel.available and panel.available[d]
							local isCur = s and (s:GetChartKey() == steps:GetChartKey())
							if isCur then
								self:diffuse(HVColor.GetDifficultyColor(s:GetDifficulty())):diffusealpha(0.5)
							else
								self:diffuse(bgDark):diffusealpha(0.8)
							end
						end
					},

					LoadFont("Common Normal") .. {
						InitCommand = function(self) self:halign(0):x(-sidePanelWidth/2 + 10):settext(short):zoom(0.3):diffuse(textSub) end,
						UpdateCommand = function(self)
							local panel = self:GetParent():GetParent():GetParent()
							local s = panel.available and panel.available[d]
							self:diffuse(s and textBright or textDim)
						end
					},

					LoadFont("Common Normal") .. {
						Name = "Meter",
						InitCommand = function(self) self:halign(1):x(sidePanelWidth/2 - 10):zoom(0.3) end,
						UpdateCommand = function(self)
							local panel = self:GetParent():GetParent():GetParent()
							local s = panel.available and panel.available[d]
							if s then
								if HV.ShowMSD() then
									local val = s:GetMSD(getCurRateValue(), 1)
									self:settextf("%.2f", val):diffuse(HVColor.GetMSDRatingColor(val)):visible(true)
								else
									self:settext(tostring(s:GetMeter())):diffuse(textMain):visible(true)
								end
							else
								self:visible(false)
							end
						end
					},

					Def.Quad {
						Name = "ClickArea",
						InitCommand = function(self) self:zoomto(sidePanelWidth - 10, 26):diffusealpha(0) end,
						UpdateCommand = function(self)
							local panel = self:GetParent():GetParent():GetParent()
							local s = panel.available and panel.available[d]
							self:visible(s ~= nil)
						end
					}
				}
			end
			return items
		end)()
	}
end

-- 3. SIDEBARS (Skillsets & Analysis)
local function skillsetPanelComp()
	return skillsetPanel()
end

local function radarPanelComp()
	return radarPanel()
end

-- 3. CHORD DENSITY GRAPH
local peak70LineActor = nil
local tooltipActor = nil
local npsTooltipActor = nil
local showTooltip = false

local function densityGraphComp()
	return Def.ActorFrame {
		Name = "CDGFrame",
		InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_HEIGHT - 60); cdgFrameRef = self end,
		ReloadCommand = function(self) self:RunCommandsOnChildren(function(c) c:playcommand("Reload") end) end,
		-- BG
		Def.Quad { InitCommand = function(self) self:zoomto(SCREEN_WIDTH - 120, 80):diffuse(bgCard):diffusealpha(0.9) end },
		
		Def.Quad { Name = "ClickArea", InitCommand = function(self) self:zoomto(SCREEN_WIDTH - 120, 80):diffusealpha(0) end },

		-- Graph (AMV)
		Def.ActorMultiVertex {
			Name = "GraphAMV",
			ReloadCommand = function(self)
				local rate = math.max(MIN_MUSIC_RATE, getCurRateValue())
				local vectors = steps:GetCDGraphVectors(rate)
				if not vectors then self:SetVertices({}):SetDrawState({Mode="DrawMode_Quads", First=0, Num=0}) return end
				
				local npsV = vectors[1]
				local nRows = #npsV
				local gW = SCREEN_WIDTH - 120
				local gH = 40
				local rW = gW / nRows
				local mNPS = 0
				for i=1, #npsV do
					if npsV[i] > mNPS then mNPS = npsV[i] end
				end
				
				local mHeight = gH / math.max(1, mNPS)
				local verts, nCols = {}, steps:GetNumColumns()
				
				for d=1, nCols do
					for r=1, nRows do
						if vectors[d][r] > 0 then
							local val = 0.2 + (nCols - (d-1)) * (0.6 / nCols)
							local c = color(val..","..val..","..val..",1")
							local x, y = -(gW/2) + (r-1)*rW, gH/2 +20
							local bh, bw = rW, -(vectors[d][r]*2*mHeight)
							verts[#verts+1] = {{x, y, 0}, c}
							verts[#verts+1] = {{x+bh, y, 0}, c}
							verts[#verts+1] = {{x+bh, y+bw, 0}, c}
							verts[#verts+1] = {{x, y+bw, 0}, c}
						end
					end
				end
				self:SetVertices(verts):SetDrawState({Mode="DrawMode_Quads", First=1, Num=#verts})
			end
		},

		-- 70% Peak NPS Reference Line (drawn on top of graph)
		Def.ActorFrame {
			Name = "Peak70Container",
			InitCommand = function(self)
				self:xy(-(SCREEN_WIDTH - 120)/2, 0)
				self:halign(0)
				self:z(1000)  -- Ensure it's above all other elements
			end,
			ReloadCommand = function(self)
				if steps then
					local rate = math.max(MIN_MUSIC_RATE, getCurRateValue())
					local vectors = steps:GetCDGraphVectors(rate)
					if vectors and vectors[1] then
						local npsV = vectors[1]
						local mNPS = 0
						local maxRaw = 0
						for i=1, #npsV do
							local raw = npsV[i]
							if raw > maxRaw then maxRaw = raw end
							local val = npsV[i]  -- NPS values are already correct, don't multiply by 2
							if val > mNPS then mNPS = val end
						end
						if mNPS >= 2 then
							local peak70 = mNPS * 0.7
							-- Graph height is 70, center is 0, range is -35 to +35
							-- 70% line should be 70% of the way up from bottom
							local yPos = 35 - (0.7 * 70)  -- = 35 - 49 = -14
							self:y(yPos)
							self:visible(true)
							-- Update the text with the actual 70% NPS value
							local textActor = self:GetChild("Peak70Text")
							if textActor then
								textActor:settextf("%.1f (70%%)", peak70)
							end
						else
							self:visible(false)
						end
					else
						self:visible(false)
					end
				end
			end,

			-- The line (thicker with accent color)
			Def.Quad {
				Name = "Peak70Line",
				InitCommand = function(self)
					self:zoomto(SCREEN_WIDTH - 120, 2)
					self:diffuse(accentColor)
					self:diffusealpha(0.6)
					self:halign(0)
				end,
			},

			-- The text label (with accent color)
			LoadFont("Common Normal") .. {
				Name = "Peak70Text",
				InitCommand = function(self)
					self:x(SCREEN_WIDTH - 130)
					self:y(-4)
					self:zoom(0.28)
					self:diffuse(accentColor)
					self:halign(1)
					self:settext("-- (70%)")
				end
			}
		},

		-- ProgressMarker drawn AFTER the graph so it renders on top
		Def.Quad { Name = "ProgressMarker", InitCommand = function(self) self:x(-(SCREEN_WIDTH-120)/2):zoomto(2, 80):diffuse(accentColor) end },

		-- Hover Tooltip Area (invisible but captures mouse)
		Def.Quad {
			Name = "TooltipArea",
			InitCommand = function(self)
				self:zoomto(SCREEN_WIDTH - 120, 80)
				self:xy(-(SCREEN_WIDTH - 120)/2, 40)
				self:halign(0):valign(1)
				self:diffusealpha(0)
				self:z(400)
			end
		},

		-- Tooltip Display (positioned in updateSync) -- kept for compatibility but hidden in favor of info bar
		Def.ActorFrame {
			Name = "NPSTooltip",
			InitCommand = function(self)
				npsTooltipActor = self
				self:visible(false)
				self:z(500)
			end,

			-- Background
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(90, 26)
					self:diffuse(bgDark):diffusealpha(0.95)
					self:halign(0):valign(1)
				end
			},

			-- Border
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(90, 2)
					self:y(-26)
					self:diffuse(accentColor)
					self:halign(0)
				end
			},

			-- Text
			LoadFont("Common Normal") .. {
				Name = "NPSText",
				InitCommand = function(self)
					self:halign(0):valign(0)
					self:x(5):y(-22)
					self:zoom(0.35)
					self:diffuse(accentColor)
					self:settext("-- NPS")
				end
			}
		},

		-- Info bar below CDG: centered TIME · BPM · NPS; accent color on hover
		Def.ActorFrame {
			Name = "CDGInfoBar",
			-- CDGFrame center is at SCREEN_HEIGHT-60; place bar 48px below that
			InitCommand = function(self) self:y(48) end,

			-- Time (left of center trio)
			LoadFont("Common Normal") .. {
				Name = "CDGInfoTime",
				InitCommand = function(self)
					self:halign(1):x(-90)
					self:zoom(0.3):diffuse(textDim):settext("-:--")
					cdgInfoTimeRef = self
				end
			},

			-- BPM (center)
			LoadFont("Common Normal") .. {
				Name = "CDGInfoBPM",
				InitCommand = function(self)
					self:halign(0.5):x(0)
					self:zoom(0.3):diffuse(textSub):settext("-- BPM")
					cdgInfoBPMRef = self
				end
			},

			-- NPS (right of center trio)
			LoadFont("Common Normal") .. {
				Name = "CDGInfoNPS",
				InitCommand = function(self)
					self:halign(0):x(90)
					self:zoom(0.3):diffuse(textSub):settext("-- NPS")
					cdgInfoNPSRef = self
				end
			},
		}
	}
end

-- ============================================================
-- MSD SKILLSET TOOLTIP
-- ============================================================
local tooltipW = 280
local tooltipH = 56
local msdTooltipActor = nil

local msdTooltip = Def.ActorFrame {
	Name = "MSDTooltip",
	InitCommand = function(self)
		msdTooltipActor = self
		self:visible(false)
		self:z(1000)
	end,
	-- Background
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(1):zoomto(tooltipW, tooltipH):diffuse(bgDark):diffusealpha(0.95)
		end
	},
	-- Border
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(1):zoomto(tooltipW, 1):y(-tooltipH):diffuse(accentColor):diffusealpha(0.5)
		end
	}
}

local skillsetsList = {
	{name="Stream", idx=2}, {name="Jumpstream", idx=3}, {name="Handstream", idx=4}, {name="Stamina", idx=5},
	{name="JackSpeed", idx=6}, {name="Chordjack", idx=7}, {name="Technical", idx=8}
}

for i, ss in ipairs(skillsetsList) do
	local col, row, colW, offsetX
	if i <= 4 then
		row = 0
		col = i - 1
		colW = tooltipW / 4
		offsetX = col * colW + (colW / 2)
	else
		row = 1
		col = i - 5
		colW = tooltipW / 3
		offsetX = col * colW + (colW / 2)
	end

	local offsetY = -tooltipH + 12 + row * 24

	msdTooltip[#msdTooltip + 1] = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(offsetX, offsetY)
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:y(-7):zoom(0.25):diffuse(textSub):settext(ss.name) end
		},
		LoadFont("Common Normal") .. {
			Name = "Val",
			InitCommand = function(self) self:y(5):zoom(0.35):diffuse(textMain) end,
			SetHoverCommand = function(self, params)
				if params.steps then
					local rate = getCurRateValue and getCurRateValue() or 1
					local msd = params.steps:GetMSD(rate, ss.idx)
					if msd and msd > 0 then
						self:settext(string.format("%.2f", msd)):diffuse(getMSDColor(msd))
					else
						self:settext("-"):diffuse(textDim)
					end
				else
					self:settext("-"):diffuse(textDim)
				end
			end
		}
	}
end

------------------------------------------------------------
-- ROOT ACTORFRAME
------------------------------------------------------------
local t = Def.ActorFrame {
	Name = "ChartPreviewRoot",
	InitCommand = function(self) 
		rootRef = self
		self:SetUpdateFunction(updateSync)
		self:visible(false)
	end,
	
	ChartPreviewOnMessageCommand = function(self)
		ssm = SCREENMAN:GetTopScreen()
		song = GAMESTATE:GetCurrentSong()
		steps = GAMESTATE:GetCurrentSteps()
		if not song or not steps then return end
		
		musicLength = song:GetLastSecond()
		visualSeekActive = false
		
		-- Always remove any stale callback first to prevent double-registration
		-- across repeated open/close cycles (even if RemoveOldCallback hasn't fired yet).
		if inputCallback and ssm then
			pcall(function() ssm:RemoveInputCallback(inputCallback) end)
		end
		inputCallback = function(event) return input(event) end
		ssm:AddInputCallback(inputCallback)
		
		-- Always enter with a clean, unpaused state
		isPaused = false
		pausedPos = 0
		local pText = self:GetChild("NoteFieldContainer") and self:GetChild("NoteFieldContainer"):GetChild("PausedText")
		if pText then pText:diffusealpha(0) end
		
		-- Capture current audio position from bgm.lua's wall-clock tracker.
		-- HV.GetBgmCurrentPos() is set at every SOUND:PlayMusicPart call, so it
		-- correctly reflects the live absolute-seconds position for ALL preview modes.
		-- We store it as a pending seek rather than applying immediately, because
		-- PlayCurrentSongSampleMusic initialises its stream asynchronously — any
		-- SetSampleMusicPosition called before the stream is ready gets overwritten
		-- by the engine's own reset to song:GetSampleStart().
		-- PlayingSampleMusicMessageCommand (below) applies the seek once the stream is live.
		local capturedPos = 0
		if HV.GetBgmCurrentPos then
			capturedPos = HV.GetBgmCurrentPos()
		end
		if capturedPos <= 0 and ssm and ssm.GetSampleMusicPosition then
			local sp = ssm:GetSampleMusicPosition()
			if sp and sp > 0 then capturedPos = sp end
		end
		if capturedPos < 0 then capturedPos = 0 end
		self.pendingSeekPos = capturedPos
		
		-- Try the seek immediately on open so audio can snap to the
		-- notefield ASAP, then let the deferred seek path verify it.
		playFrom(capturedPos, false, false)
		syncPreviewSongPosition(capturedPos)
		applyPreviewPosition(capturedPos)
		scheduleVerifiedSeek(capturedPos)
		
		SCREENMAN:set_input_redirected(PLAYER_1, true)
		self:visible(true)
		MESSAGEMAN:Broadcast("ReloadChartPreview")
	end,

	-- Apply the deferred seek once PlayCurrentSongSampleMusic signals the stream is live.
	-- This fires after the audio thread has initialised the stream. We perform an
	-- immediate seek, followed by a verification seek after a short delay (0.04s)
	-- to ensure the engine's asynchronous audio start didn't overwrite the initial call.
	PlayingSampleMusicMessageCommand = function(self)
		if not HV.ChartPreviewActive then return end
		if self.pendingSeekPos ~= nil and ssm and ssm.SetSampleMusicPosition then
			-- First attempt: immediate
			ssm:SetSampleMusicPosition(self.pendingSeekPos)
			syncPreviewSongPosition(self.pendingSeekPos)
			applyPreviewPosition(self.pendingSeekPos)
			startVisualSeekClock(self.pendingSeekPos)
			-- Second attempt: verification after a short delay to be certain
			scheduleVerifiedSeek(self.pendingSeekPos)
		end
	end,
	
	PerformSeekCommand = function(self)
		if not HV.ChartPreviewActive then return end
		if self.pendingSeekPos ~= nil and ssm and ssm.SetSampleMusicPosition then
			ssm:SetSampleMusicPosition(self.pendingSeekPos)
			syncPreviewSongPosition(self.pendingSeekPos)
			applyPreviewPosition(self.pendingSeekPos)
			startVisualSeekClock(self.pendingSeekPos)
		end
		self.pendingSeekPos = nil
	end,
	
	ChartPreviewOffMessageCommand = function(self)
		self:visible(false)
		SCREENMAN:set_input_redirected(PLAYER_1, false)
		-- Don't stop music — let the screen handle it naturally
		fullSongMode = false
		visualSeekActive = false
		-- Always clear pause state so re-entry does not inherit a stale flag
		isPaused = false
		pausedPos = 0
		local pText = self:GetChild("NoteFieldContainer") and self:GetChild("NoteFieldContainer"):GetChild("PausedText")
		if pText then pText:diffusealpha(0) end
		if ssm and inputCallback then
			-- If the music was left paused, resume it before exiting
			if ssm.IsSampleMusicPaused and ssm:IsSampleMusicPaused() then
				ssm:PauseSampleMusic()
			end
			-- Defer removal to the next frame: RemoveInputCallback called from *within*
			-- the callback itself (via Broadcast) is unreliable — the engine may ignore
			-- it because the callback is currently on the call stack.  The visibility
			-- guard at the top of input() keeps stale firings harmless in the meantime.
			local cbToRemove = inputCallback
			local ssmRef     = ssm
			inputCallback = nil  -- clear immediately so the guard triggers on next press
			self:queuecommand("RemoveOldCallback")
			self.pendingRemove     = cbToRemove
			self.pendingRemoveSsm  = ssmRef
		end
		self.pendingSeekPos = nil
		self:stoptweening()
	end,

	RemoveOldCallbackCommand = function(self)
		if self.pendingRemoveSsm and self.pendingRemove then
			pcall(function() self.pendingRemoveSsm:RemoveInputCallback(self.pendingRemove) end)
		end
		self.pendingRemove    = nil
		self.pendingRemoveSsm = nil
	end,

	ReloadChartPreviewMessageCommand = function(self) 
		song = GAMESTATE:GetCurrentSong()
		steps = GAMESTATE:GetCurrentSteps()
		if not song or not steps then return end
		self:RunCommandsOnChildren(function(c) c:playcommand("Reload") end) 
	end,
	CurrentRateChangedMessageCommand = function(self) MESSAGEMAN:Broadcast("ReloadChartPreview") end,

	-- Screen Dim & Input Guard
	Def.Quad { InitCommand = function(self) self:FullScreen():diffuse(color("0,0,0,0.85")) end },
	Def.Quad { Name = "InputGuard", InitCommand = function(self) self:FullScreen():diffusealpha(0) end },

	-- Main Components
	header(),
	
	-- Sidebar (Left): Skillsets (Far Left)
	Def.ActorFrame {
		Name = "LeftSidebar",
		InitCommand = function(self) self:xy(sidePanelWidth/2 + 20, SCREEN_CENTER_Y) end,
		skillsetPanelComp()
	},

	densityGraphComp(),

	-- Center NoteField Container
	Def.ActorFrame {
		Name = "NoteFieldContainer",
		-- USER: match receptor up to match bottom line of middle area
		-- We move the container slightly up or shift the receptors.
		-- Receptors are at "0" in the NoteFieldPreview.
		-- If container is at SCREEN_CENTER_Y - 20, receptors are also there.
		-- Middle area bottom line is likely the top of the Chord Density Graph?
		-- Or maybe the user means the top border of the NoteFieldContainer.
		InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 40) end,
		ReloadCommand = function(self) self:RunCommandsOnChildren(function(c) c:playcommand("Reload") end) end,
		Def.Quad { InitCommand = function(self) self:zoomto(frameWidth, frameHeight):diffuse(bgDark):diffusealpha(0.5) end },
		Def.Quad { InitCommand = function(self) self:zoomto(frameWidth, 1):y(-frameHeight/2):diffuse(accentColor):diffusealpha(0.3) end },
		Def.Quad { InitCommand = function(self) self:zoomto(frameWidth, 1):y(frameHeight/2):diffuse(accentColor):diffusealpha(0.3) end },
		
		Def.NoteFieldPreview {
			Name = "NoteField",
			DrawDistanceBeforeTargetsPixels = 1200, DrawDistanceAfterTargetsPixels = 0,
			-- Move Y up so receptors (at 0) align near the top border of the box if desired,
			-- OR just move Y to 0 so receptors are at SCREEN_CENTER_Y - 40.
			InitCommand = function(self) self:zoom(0.7):y(0) end,
			OnCommand = function(self) noteFieldRef = self end,
			ReloadCommand = function(self) if steps then self:LoadNoteData(steps) end end
		},
		
		LoadFont("Common Large") .. {
			Name = "PausedText",
			InitCommand = function(self) self:settext("PAUSED"):zoom(0.5):diffuse(color("1,0.2,0.2,1")):diffusealpha(0):shadowlength(1):shadowcolor(0,0,0,1) end
		}
	},

	-- Right Area: CHART + ANALYSIS (Moved to end for draw order)
	Def.ActorFrame {
		Name = "RightSidebar",
		InitCommand = function(self) self:xy(SCREEN_WIDTH - 20, SCREEN_CENTER_Y):SortByDrawOrder() end,
		
		-- CHART (Difficulty Selector) - To the left of Radar
		chartPanel() .. { InitCommand = function(self) self:x(-sidePanelWidth * 1.5 - innerPadding):draworder(1000) end },
		
		-- ANALYSIS (Radar) - Far Right
		radarPanelComp() .. { InitCommand = function(self) self:x(-sidePanelWidth/2) end },
	},

	-- Bottom Global Progress (Tiny line)
	Def.Quad {
		Name = "GlobalProgressBar",
		InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_HEIGHT - 2):zoomto(0, 2):diffuse(accentColor):diffusealpha(0.8); progressRef = self end
	},

	-- Tooltip (drawn last for z-order)
	msdTooltip
}

return t
