--- Holographic Void: ScreenSelectMusic Out Transition / Options Overlay
--
-- Layout specifications:
-- 1. Full-screen background showing chart background in full across the entire display.
-- 2. Screen height-long diagonal slant dividing the left background and darkened right side.
-- 3. Slanted dark background panel underlaying the info overlay, gliding in unison with
--    the divider, banner, metadata, MSD, and options prompt.
-- 4. Right side elements aligned to lower right:
--    - Slanted Banner
--    - BPM
--    - Song Title, Subtitle, Artist, Pack
--    - Difficulty Label (without meter) directly above Overall MSD
--    - Overall MSD rating (no 'Overall MSD' text, no skillsets)
--    - Press Start for Options text (bigger, farther from corner, NO background card)
-- 5. Animation:
--    - Smooth decelerated entry sliding in from the left.
--    - Slowed continuous slide to the right for the entire duration of the screen.
--    - No exit animation.
--
-- Engine broadcasts:
--   ShowPressStartForOptionsCommand
--   ShowEnteringOptionsCommand
--   HidePressStartForOptionsCommand

local translated_info = {
	PressStart = THEME:GetString("ScreenSelectMusic", "PressStartForOptions"),
	EnteringOptions = THEME:GetString("ScreenSelectMusic", "EnteringOptions"),
}

local function getAccent()
	return (HVColor and HVColor.Accent) or color("#5ABAFF")
end

local brightText  = color("1,1,1,1")
local subText     = color("0.70,0.74,0.82,1")
local dimText     = color("0.44,0.47,0.55,1")
local darkenedBg  = color("0.03,0.03,0.05,0.96")

-- Helper accessors for selected chart info
local function getSelectedSong()
	if HV and HV.CurrentSongData and HV.CurrentSongData.song then
		return HV.CurrentSongData.song
	end
	if GAMESTATE and GAMESTATE.GetCurrentSong then
		return GAMESTATE:GetCurrentSong()
	end
	return nil
end

local function getSelectedSteps()
	if HV and HV.CurrentSongData and HV.CurrentSongData.steps then
		return HV.CurrentSongData.steps
	end
	if GAMESTATE and GAMESTATE.GetCurrentSteps then
		return GAMESTATE:GetCurrentSteps(PLAYER_1) or GAMESTATE:GetCurrentSteps()
	end
	return nil
end

local function getSelectedRate()
	if HV and HV.CurrentSongData and HV.CurrentSongData.rate then
		return HV.CurrentSongData.rate
	end
	if getCurRateValue then
		return getCurRateValue()
	end
	return 1.0
end

local function formatBPM(song, rate)
	if not song or not song.GetDisplayBpms then return "--- BPM" end
	rate = rate or 1.0
	local bpms = song:GetDisplayBpms(true)
	if not bpms or not bpms[1] then return "--- BPM" end
	local b1 = math.round(bpms[1] * rate)
	local b2 = math.round((bpms[2] or bpms[1]) * rate)
	if math.abs(b1 - b2) < 1 then
		return string.format("%d BPM", b1)
	else
		return string.format("%d - %d BPM", b1, b2)
	end
end

local function toShortDiff(diff)
	if not diff then return "Edit" end
	if ToEnumShortString then
		local s = ToEnumShortString(diff)
		if s and s ~= "" then return s end
	end
	return tostring(diff):gsub("Difficulty_", "")
end

local function getDifficultyInfo(steps)
	if not steps or not steps.GetDifficulty then
		return "EDIT", 0, color("#8C8C8C")
	end
	local diff = steps:GetDifficulty()
	local diffName = toShortDiff(diff)
	local meter = steps:GetMeter() or 0
	local diffColor = (HVColor and HVColor.GetDifficultyColor and HVColor.GetDifficultyColor(diff)) or color("#8C8C8C")
	return diffName:upper(), meter, diffColor
end

local function applyDanTextGradient(actor, text, stops)
	if not actor or type(stops) ~= "table" or #stops < 2 then return false end
	actor:ClearAttributes():diffuse(color("#FFFFFF"))
	local glyphCount = 0
	for i = 1, #text do
		local byte = text:byte(i)
		if byte < 128 or byte >= 192 then glyphCount = glyphCount + 1 end
	end
	if glyphCount == 0 then return false end
	for glyph = 0, glyphCount - 1 do
		local glyphColor
		if #stops >= 3 then
			local band = math.min(#stops, math.floor(((glyph + 0.5) / glyphCount) * #stops) + 1)
			glyphColor = stops[band]
		else
			local position = glyphCount == 1 and 0.5 or glyph / (glyphCount - 1)
			glyphColor = HV.LerpColor(position, stops[1], stops[2])
		end
		actor:AddAttribute(glyph, {Length = 1, Diffuse = glyphColor})
	end
	return true
end

local function broadcastSet(af)
	if not af or not af.GetChildren then return end
	for _, c in pairs(af:GetChildren()) do
		if type(c) == "userdata" then
			if c.playcommand then c:playcommand("Set") end
			if c.GetChildren then broadcastSet(c) end
		elseif type(c) == "table" then
			for _, sub in ipairs(c) do
				if sub.playcommand then sub:playcommand("Set") end
				if sub.GetChildren then broadcastSet(sub) end
			end
		end
	end
end

local t = Def.ActorFrame {
	Name = "ScreenSelectMusicOutRoot",
	StartTransitioningCommand = function(self)
		-- Evaluation and replay entry use the shared growing-circle transition.
		-- This custom outgoing screen covers the full display, so remove it before
		-- the transition starts instead of animating the song-select artwork over it.
		local nextScreenName = ""
		local top = SCREENMAN and SCREENMAN:GetTopScreen()
		if top and top.GetNextScreenName then
			local ok, value = pcall(function() return top:GetNextScreenName() end)
			if ok and value then nextScreenName = tostring(value) end
		end
		local enteringReplay = HV and HV.SuppressSelectMusicOutForReplay
		if enteringReplay then HV.SuppressSelectMusicOutForReplay = nil end
		if nextScreenName == "ScreenEvaluation" or enteringReplay then
			self:visible(false)
			return
		end
		self:playcommand("Set")
	end,
	HideSelectMusicOutroMessageCommand = function(self) self:visible(false) end,
	ReplayTransitionOutMessageCommand = function(self) self:visible(false) end,
	ShowPressStartForOptionsCommand = function(self)
		self:playcommand("Set")
	end,
	SetCommand = function(self)
		broadcastSet(self)
	end,
}

-- Slanted divider geometry across the full screen height (480px)
local slantTopX    = WideScale(SCREEN_WIDTH * 0.54, SCREEN_WIDTH * 0.52)
local slantBottomX = WideScale(SCREEN_WIDTH * 0.38, SCREEN_WIDTH * 0.36)
local rightMargin  = SCREEN_RIGHT - WideScale(52, 65)

-- Animation parameters
local slideInOffset = WideScale(240, 320)
local driftDistance = WideScale(28, 36)

local animEntryTime = 0.65
local animDriftTime = 3.00
local totalAnimTime = animEntryTime + animDriftTime

-- ============================================================
-- 1. FULL-SCREEN BACKGROUND (STATIONARY, NO ANIMATION)
-- ============================================================
-- Solid OLED black base
t[#t + 1] = Def.Quad {
	Name = "OLEDBlackBase",
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}

-- Full-screen chart background image (clear / full opacity)
t[#t + 1] = Def.Sprite {
	Name = "FullBackgroundSprite",
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			:diffuse(color("1,1,1,1"))
		pcall(function() self:SetTextureFiltering(true) end)
	end,
	StartTransitioningCommand = function(self)
		self:playcommand("Set")
	end,
	SetCommand = function(self)
		local song = getSelectedSong()
		local bgPath = (song and song.GetBackgroundPath and song:GetBackgroundPath()) or ""
		if not bgPath or bgPath == "" or not (FILEMAN and FILEMAN.DoesFileExist and FILEMAN:DoesFileExist(bgPath)) then
			bgPath = THEME:GetPathG("Common", "fallback background")
		end
		if bgPath and bgPath ~= "" then
			self:visible(true):LoadBackground(bgPath)
			self:scaletocover(SCREEN_LEFT, SCREEN_TOP, SCREEN_RIGHT, SCREEN_BOTTOM)
		else
			self:visible(false)
		end
	end
}

-- Subtle CRT scanlines over the full screen
local scanLines = Def.ActorFrame { Name = "Scanlines" }
for i = 0, math.floor(SCREEN_HEIGHT / 6) do
	scanLines[#scanLines + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, i * 6):zoomto(SCREEN_WIDTH, 1):diffuse(color("1,1,1,0.015"))
		end
	}
end
t[#t + 1] = scanLines

-- ============================================================
-- 2. SCREEN ELEMENTS CONTAINER
--    (ENTRY FROM LEFT + SLOW CONTINUOUS SLIDE TO THE RIGHT)
--    Contains the dark underlay background, slanted divider lines,
--    and all overlay info elements so they glide together seamlessly.
-- ============================================================
local rightSideContainer = Def.ActorFrame {
	Name = "RightSideContainer",
	InitCommand = function(self)
		self:x(-slideInOffset)
	end,
	StartTransitioningCommand = function(self)
		self:playcommand("Set")
		-- Smooth entry from left (decelerate), then slowed continuous slide to the right (no exit)
		self:stoptweening()
			:x(-slideInOffset)
			:decelerate(animEntryTime):x(0)
			:linear(animDriftTime):x(driftDistance)
	end,
	ShowPressStartForOptionsCommand = function(self)
		self:playcommand("Set")
	end,
	ShowEnteringOptionsCommand = function(self)
		-- Freeze position so elements do not drift when entering options
		self:stoptweening()
	end,
	SetCommand = function(self)
		broadcastSet(self)
	end,
}

-- Slanted dark background panel underlaying the info overlay (glides in unison with container)
-- Vertices extend far to the right (+2000px) so the right screen edge is always fully covered
rightSideContainer[#rightSideContainer + 1] = Def.ActorMultiVertex {
	Name = "DarkenedRightPanel",
	InitCommand = function(self)
		self:SetVertices({
			{{slantTopX, SCREEN_TOP - 10, 0}, darkenedBg},
			{{SCREEN_WIDTH + 2000, SCREEN_TOP - 10, 0}, darkenedBg},
			{{SCREEN_WIDTH + 2000, SCREEN_BOTTOM + 10, 0}, darkenedBg},
			{{slantBottomX, SCREEN_BOTTOM + 10, 0}, darkenedBg},
		})
		self:SetDrawState({Mode = "DrawMode_Quads"})
	end
}

-- Slanted dividing accent line (outer soft glow)
rightSideContainer[#rightSideContainer + 1] = Def.ActorMultiVertex {
	Name = "SlantDividerGlow",
	InitCommand = function(self)
		self:playcommand("Set")
	end,
	SetCommand = function(self)
		local cg = getAccent()
		local glowCol = color(string.format("%.3f,%.3f,%.3f,0.22", cg[1], cg[2], cg[3]))
		self:SetVertices({
			{{slantTopX - 4, SCREEN_TOP - 10, 0}, glowCol},
			{{slantTopX + 4, SCREEN_TOP - 10, 0}, glowCol},
			{{slantBottomX + 4, SCREEN_BOTTOM + 10, 0}, glowCol},
			{{slantBottomX - 4, SCREEN_BOTTOM + 10, 0}, glowCol},
		})
		self:SetDrawState({Mode = "DrawMode_Quads"})
	end
}

-- Slanted dividing accent line (sharp core line)
rightSideContainer[#rightSideContainer + 1] = Def.ActorMultiVertex {
	Name = "SlantDividerCore",
	InitCommand = function(self)
		self:playcommand("Set")
	end,
	SetCommand = function(self)
		local ca = getAccent()
		self:SetVertices({
			{{slantTopX - 1.25, SCREEN_TOP - 10, 0}, ca},
			{{slantTopX + 1.25, SCREEN_TOP - 10, 0}, ca},
			{{slantBottomX + 1.25, SCREEN_BOTTOM + 10, 0}, ca},
			{{slantBottomX - 1.25, SCREEN_BOTTOM + 10, 0}, ca},
		})
		self:SetDrawState({Mode = "DrawMode_Quads"})
	end
}

-- ============================================================
-- 3. RIGHT SIDE CONTENT: ALIGNED TO LOWER RIGHT CORNER
-- ============================================================
local contentAF = Def.ActorFrame {
	Name = "LowerRightContent",
	InitCommand = function(self)
		self:diffusealpha(1)
	end,
	SetCommand = function(self)
		broadcastSet(self)
	end,
}

local bannerW = WideScale(260, 310)
local bannerH = WideScale(72, 86)
local bannerY = 142
local bannerSkew = -0.25

-- ------------------------------------------------------------
-- SLANTED BANNER
-- ------------------------------------------------------------
-- Banner frame back
contentAF[#contentAF + 1] = Def.Quad {
	Name = "BannerFrameBack",
	InitCommand = function(self)
		self:halign(1):xy(rightMargin + 2, bannerY)
			:zoomto(bannerW + 6, bannerH + 6)
			:diffuse(color("0.08, 0.09, 0.12, 1")):skewx(bannerSkew)
	end
}

-- Banner frame border line (top)
contentAF[#contentAF + 1] = Def.Quad {
	Name = "BannerBorderTop",
	InitCommand = function(self)
		self:halign(1):valign(0):xy(rightMargin + 2, bannerY - bannerH / 2 - 2)
			:zoomto(bannerW + 6, 1.5)
			:diffuse(getAccent()):diffusealpha(0.75):skewx(bannerSkew)
	end,
	SetCommand = function(self)
		self:diffuse(getAccent()):diffusealpha(0.75)
	end
}

-- Banner frame border line (bottom)
contentAF[#contentAF + 1] = Def.Quad {
	Name = "BannerBorderBottom",
	InitCommand = function(self)
		self:halign(1):valign(1):xy(rightMargin + 2, bannerY + bannerH / 2 + 2)
			:zoomto(bannerW + 6, 1)
			:diffuse(getAccent()):diffusealpha(0.35):skewx(bannerSkew)
	end,
	SetCommand = function(self)
		self:diffuse(getAccent()):diffusealpha(0.35)
	end
}

-- Banner Sprite
contentAF[#contentAF + 1] = Def.Sprite {
	Name = "RightBannerSprite",
	InitCommand = function(self)
		self:halign(1):xy(rightMargin, bannerY)
			:zoomto(bannerW, bannerH):skewx(bannerSkew)
	end,
	SetCommand = function(self)
		local song = getSelectedSong()
		local group = (HV and HV.CurrentSongData and HV.CurrentSongData.group)
		local bnPath = ""
		if song and song.GetBannerPath then
			bnPath = song:GetBannerPath()
		elseif group and SONGMAN and SONGMAN.GetSongGroupBannerPath then
			bnPath = SONGMAN:GetSongGroupBannerPath(group)
		end
		if not bnPath or bnPath == "" or not (FILEMAN and FILEMAN.DoesFileExist and FILEMAN:DoesFileExist(bnPath)) then
			bnPath = THEME:GetPathG("Common", "fallback banner")
		end
		if bnPath and bnPath ~= "" then
			self:visible(true):Load(bnPath):zoomto(bannerW, bannerH)
		else
			self:visible(false)
		end
	end
}

-- ------------------------------------------------------------
-- BPM (BELOW BANNER)
-- ------------------------------------------------------------
contentAF[#contentAF + 1] = LoadFont("Common Normal") .. {
	Name = "BPMDisplay",
	InitCommand = function(self)
		self:halign(1):xy(rightMargin, 202)
			:zoom(0.38):diffuse(brightText)
	end,
	SetCommand = function(self)
		local song = getSelectedSong()
		local rate = getSelectedRate()
		local bpmStr = formatBPM(song, rate)
		if math.abs(rate - 1.0) >= 0.01 then
			self:settext(string.format("%s (%.2fx)", bpmStr, rate))
		else
			self:settext(bpmStr)
		end
	end
}

-- ------------------------------------------------------------
-- METADATA: NAME / SUBTITLE / ARTIST / PACK
-- ------------------------------------------------------------
local maxMetaW = bannerW + 40

-- Song Name (Title)
contentAF[#contentAF + 1] = LoadFont("Zpix Normal") .. {
	Name = "SongTitle",
	InitCommand = function(self)
		self:halign(1):valign(0):xy(rightMargin, 222)
			:zoom(0.76):diffuse(brightText):maxwidth(maxMetaW / 0.76)
	end,
	SetCommand = function(self)
		local song = getSelectedSong()
		local group = (HV and HV.CurrentSongData and HV.CurrentSongData.group)
		if song then
			self:settext(song:GetDisplayMainTitle())
		elseif group then
			self:settext(group)
		else
			self:settext("")
		end
	end
}

-- Song Subtitle
contentAF[#contentAF + 1] = LoadFont("Common Normal") .. {
	Name = "SongSubTitle",
	InitCommand = function(self)
		self:halign(1):valign(0):xy(rightMargin, 252)
			:zoom(0.36):diffuse(dimText):maxwidth(maxMetaW / 0.36)
	end,
	SetCommand = function(self)
		local song = getSelectedSong()
		if song and song.GetDisplaySubTitle and song:GetDisplaySubTitle() ~= "" then
			self:settext(song:GetDisplaySubTitle()):visible(true)
		else
			self:settext(""):visible(false)
		end
	end
}

-- Song Artist
contentAF[#contentAF + 1] = LoadFont("Common Normal") .. {
	Name = "SongArtist",
	InitCommand = function(self)
		self:halign(1):valign(0):xy(rightMargin, 272)
			:zoom(0.44):diffuse(subText):maxwidth(maxMetaW / 0.44)
	end,
	SetCommand = function(self)
		local song = getSelectedSong()
		if song then
			self:settext(song:GetDisplayArtist())
		else
			self:settext("")
		end
	end
}

-- Song Pack
contentAF[#contentAF + 1] = LoadFont("Common Normal") .. {
	Name = "SongPack",
	InitCommand = function(self)
		self:halign(1):valign(0):xy(rightMargin, 296)
			:zoom(0.32):diffuse(dimText):maxwidth(maxMetaW / 0.32)
	end,
	SetCommand = function(self)
		local song = getSelectedSong()
		local group = (HV and HV.CurrentSongData and HV.CurrentSongData.group)
		if song then
			self:settext(song:GetGroupName())
		elseif group then
			self:settext(group)
		else
			self:settext("")
		end
	end
}

-- Subtle separator line before MSD
contentAF[#contentAF + 1] = Def.Quad {
	Name = "MSDDivider",
	InitCommand = function(self)
		self:halign(1):xy(rightMargin, 322)
			:zoomto(bannerW, 1)
			:diffuse(color("0.16, 0.18, 0.24, 0.7")):skewx(bannerSkew)
	end
}

-- ------------------------------------------------------------
-- DIFFICULTY LABEL  & OVERALL MSD
-- ------------------------------------------------------------
-- Difficulty Label
contentAF[#contentAF + 1] = LoadFont("Common Normal") .. {
	Name = "DifficultyLabel",
	InitCommand = function(self)
		self:halign(1):xy(rightMargin, 344)
			:zoom(0.48)
	end,
	SetCommand = function(self)
		local steps = getSelectedSteps()
		local diffName, _, diffColor = getDifficultyInfo(steps)
		self:settext(diffName):diffuse(diffColor)
	end
}

-- Large Overall MSD Rating
contentAF[#contentAF + 1] = LoadFont("MSD 20px") .. {
	Name = "OverallMSDValue",
	InitCommand = function(self)
		self:halign(1):xy(rightMargin, 376)
			:zoom(0.95):diffuse(brightText)
	end,
	SetCommand = function(self)
		local steps = getSelectedSteps()
		local rate = getSelectedRate()
		local msd = 0
		if HV and HV.CurrentSongData and HV.CurrentSongData.skillsetMSDs and HV.CurrentSongData.skillsetMSDs[1] then
			msd = HV.CurrentSongData.skillsetMSDs[1]
		elseif steps and steps.GetMSD then
			local ok, val = pcall(steps.GetMSD, steps, rate, 1)
			if ok and val then msd = tonumber(val) or 0 end
		end
		if msd and msd > 0 then
			self:settext(string.format("%.2f", msd))
			self:diffuse(HVColor.GetMSDRatingColor(msd))
		else
			self:settext("-"):diffuse(dimText)
		end
	end
}

-- Cached Dan estimate shown beneath MSD. This only reads the estimate already
-- populated by the song-select calculator; it never starts a calculation here.
contentAF[#contentAF + 1] = LoadFont("MSD 20px") .. {
	Name = "CachedDanLevel",
	InitCommand = function(self)
		self:halign(1):xy(rightMargin, 401):zoom(0.30):diffuse(subText):visible(false)
	end,
	SetCommand = function(self)
		local data = HV and HV.CurrentSongData
		local estimate = data and data.isorEstimate
		if HV and HV.GetDanCalculatorEstimate then
			estimate = HV.GetDanCalculatorEstimate(estimate)
		end
		local text = estimate and HV.GetDanCalculatorText and HV.GetDanCalculatorText(estimate) or ""
		if estimate and estimate.fixedDanChart and not estimate.celestial and text ~= "" then
			text = text .. " Dan"
		end
		if text ~= "" then
			self:settext(text):visible(true)
			local stops = estimate.celestial and HV.GetCelestialDanGradient and HV.GetCelestialDanGradient(estimate.group)
				or HV.GetReformDanGradient and HV.GetReformDanGradient(estimate)
			if not applyDanTextGradient(self, text, stops) then self:ClearAttributes():diffuse(subText) end
		else
			self:settext(""):visible(false)
		end
	end
}

-- ------------------------------------------------------------
-- PRESS START FOR OPTIONS
-- ------------------------------------------------------------
contentAF[#contentAF + 1] = Def.ActorFrame {
	Name = "OptionsPrompt",
	InitCommand = function(self)
		self:xy(rightMargin, SCREEN_BOTTOM - 42):diffusealpha(1)
	end,

	-- Floating text
	LoadFont("Common Normal") .. {
		Name = "PressStartText",
		InitCommand = function(self)
			self:halign(1):valign(1):zoom(0.65)
				:diffuse(color("0.88,0.90,0.94,1"))
				:shadowlength(1.5)
		end,
		ShowPressStartForOptionsCommand = function(self)
			self:settext(translated_info["PressStart"])
				:stoptweening():diffuse(color("0.88,0.90,0.94,1")):diffusealpha(1):zoom(0.65)
				:sleep(0.3):glowshift()
				:effectcolor1(color("1,1,1,1"))
				:effectcolor2(getAccent())
				:effectperiod(1.4)
		end,
		ShowEnteringOptionsCommand = function(self)
			self:stopeffect():stoptweening()
				:settext(translated_info["EnteringOptions"])
				:diffuse(getAccent()):diffusealpha(1):zoom(0.68)
		end,
		HidePressStartForOptionsCommand = function(self)
			self:stopeffect():stoptweening():decelerate(0.15):diffusealpha(0)
		end,
	}
}

rightSideContainer[#rightSideContainer + 1] = contentAF

t[#t + 1] = rightSideContainer

-- ============================================================
-- 4. TRANSITION TIMING
-- ============================================================
-- Transition timer matched to entry + continuous drift duration (3.65s)
t[#t + 1] = Def.Actor {
	Name = "TransitionTimer",
	OnCommand = function(self)
		self:sleep(totalAnimTime)
	end
}

return t
