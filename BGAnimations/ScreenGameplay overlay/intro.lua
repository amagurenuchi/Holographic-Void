local lScreen = Var "LoadingScreen" or ""
local isSync = lScreen:find("Sync") ~= nil

if not isSync then
	local curScreen = SCREENMAN:GetTopScreen()
	if curScreen and curScreen:GetName():find("Sync") then
		isSync = true
	end
end

if isSync then return Def.Actor{} end

-- Layout constants (banner ratio matches music select: w/h = 3.2)
local bannerW = 160
local bannerH = 50
local metaW = 170
local totalW = bannerW + metaW + 12  -- banner + gap + metadata
local totalH = bannerH + 10
local gradientPad = 60  -- extra fade on each side
local accentColor = HVColor.Accent or color("#5ABAFF")

-- Invalidating mods (fetched at BeginCommand)
local invalidMods = {}

local t = Def.ActorFrame{
	Name = "IntroBanner",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 50)
		self:diffusealpha(0)
	end,
	CurrentSongChangedMessageCommand = function(self)
		self:stoptweening()
		self:decelerate(0.8)
		self:diffusealpha(1)
	end,
	SongStartingMessageCommand = function(self)
		self:stoptweening()
		self:smooth(0.5)
		self:diffusealpha(0)
	end
}

-- ============================================================
-- OUTWARDS-GRADIENT BACKGROUND (ActorMultiVertex)
-- Opaque center fading to transparent at left/right edges
-- ============================================================
t[#t+1] = Def.ActorFrame{

	Def.ActorMultiVertex{
		Name = "GradientBG",
		CurrentSongChangedMessageCommand = function(self)
			local diffColor = color("#000000")
			if GAMESTATE:GetCurrentSteps() then
				diffColor = HVColor.GetDifficultyColor(GAMESTATE:GetHardestStepsDifficulty())
			end
			-- Build gradient: transparent -> colored center -> transparent
			local halfW = (totalW + gradientPad * 2) / 2
			local halfH = (totalH + 6) / 2
			local cR, cG, cB = diffColor[1], diffColor[2], diffColor[3]
			local centerA = 0.7
			local edgeA = 0

			self:SetVertices({
				-- Left edge (transparent)
				{{-halfW, -halfH, 0}, {cR, cG, cB, edgeA}},
				{{-halfW,  halfH, 0}, {cR, cG, cB, edgeA}},
				-- Left-center (start of opaque)
				{{-totalW/2, -halfH, 0}, {cR, cG, cB, centerA * 0.6}},
				{{-totalW/2,  halfH, 0}, {cR, cG, cB, centerA * 0.6}},
				-- Center-left
				{{-totalW/4, -halfH, 0}, {cR, cG, cB, centerA}},
				{{-totalW/4,  halfH, 0}, {cR, cG, cB, centerA}},
				-- Center-right
				{{ totalW/4, -halfH, 0}, {cR, cG, cB, centerA}},
				{{ totalW/4,  halfH, 0}, {cR, cG, cB, centerA}},
				-- Right-center (start fading)
				{{ totalW/2, -halfH, 0}, {cR, cG, cB, centerA * 0.6}},
				{{ totalW/2,  halfH, 0}, {cR, cG, cB, centerA * 0.6}},
				-- Right edge (transparent)
				{{ halfW, -halfH, 0}, {cR, cG, cB, edgeA}},
				{{ halfW,  halfH, 0}, {cR, cG, cB, edgeA}},
			})
			self:SetDrawState({Mode = "DrawMode_QuadStrip", First = 1, Num = 12})
		end
	},

	-- Dark underlay for readability
	Def.Quad{
		InitCommand = function(self)
			self:zoomto(totalW + 4, totalH + 4)
			self:diffuse(color("#000000"))
			self:diffusealpha(0.6)
		end
	}
}

-- ============================================================
-- SONG BANNER (left side)
-- ============================================================
t[#t+1] = Def.Sprite{
	Name = "SongBanner",
	InitCommand = function(self)
		self:x(-totalW / 2 + bannerW / 2 + 4)
	end,
	CurrentSongChangedMessageCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		if song then
			local bnpath = song:GetBannerPath()
			if not bnpath then
				bnpath = THEME:GetPathG("Common", "fallback banner")
			end
			self:LoadBackground(bnpath)
		end
		self:scaletoclipped(bannerW, bannerH)
	end
}

-- ============================================================
-- CHART METADATA (right side)
-- ============================================================
local metaX = -totalW / 2 + bannerW + 12  -- right of banner + gap

-- Song Title
t[#t+1] = LoadFont("Zpix Normal") .. {
	InitCommand = function(self)
		self:x(metaX):y(-16):halign(0):zoom(0.5)
		self:maxwidth(metaW / 0.5)
	end,
	CurrentSongChangedMessageCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		if song then self:settext(song:GetDisplayMainTitle()) end
	end
}

-- Artist
t[#t+1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:x(metaX):y(-2):halign(0):zoom(0.35)
		self:diffuse(color("0.7,0.7,0.7,1"))
		self:maxwidth(metaW / 0.35)
	end,
	CurrentSongChangedMessageCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		if song then self:settext(song:GetDisplayArtist()) end
	end
}

-- Difficulty + MSD
t[#t+1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:x(metaX):y(10):halign(0):zoom(0.35)
		self:maxwidth(metaW / 0.35)
	end,
	CurrentSongChangedMessageCommand = function(self)
		local steps = GAMESTATE:GetCurrentSteps()
		if steps then
			local diff = ToEnumShortString(steps:GetDifficulty())
			local diffName = getDifficulty(steps:GetDifficulty())
			local meter = steps:GetMSD(getCurRateValue(), 1)
			local msdStr = meter > 0 and string.format(" [%.2f]", meter) or ""
			self:settext(diffName .. msdStr)
			self:diffuse(HVColor.GetDifficultyColor(diff))
		end
	end
}

-- Rate + Chart Author
t[#t+1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:x(metaX):y(20):halign(0):zoom(0.3)
		self:diffuse(color("0.55,0.55,0.55,1"))
		self:maxwidth(metaW / 0.3)
	end,
	CurrentSongChangedMessageCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		local rate = getCurRateString()
		local author = ""
		if song and song.GetOrTryAtLeastToGetSimfileAuthor then
			author = song:GetOrTryAtLeastToGetSimfileAuthor()
		end
		local parts = {}
		if rate ~= "1.0x" then table.insert(parts, rate .. " Rate") end
		if author ~= "" then table.insert(parts, "By: " .. author) end
		self:settext(table.concat(parts, "  ·  "))
	end
}

-- ============================================================
-- INVALIDATING MODS BADGE ROW
-- ============================================================
-- Shorthand abbreviations for each mod ID
local modShorthand = {
	NoMines = "NM",   Mines = "+M",
	NoHolds = "NH",   NoRolls = "NR",
	NoHands = "NHD",  NoJumps = "NJ",
	NoLifts = "NL",   NoQuads = "NQ",
	NoStretch = "NST",NoFakes = "NF",
	Little = "LIT",
	Wide = "WD",  Big = "BIG",  Quick = "QCK",
	BMRize = "BMR", Skippy = "SKP",
	Echo = "ECH", Stomp = "STP",
	JackJS = "JJS", AnchorJS = "AJS", IcyWorld = "ICY",
	Backwards = "BWD", TurnLeft = "LFT", TurnRight = "RGT",
	Shuffle = "SHF", SoftShuffle = "SSH",
	SuperShuffle = "SUP", HRanShuffle = "HRS",
	Planted = "PLT", Floored = "FLR",
	Twister = "TWS", HoldRolls = "H>R", HoldReleases = "HRE",
	Autoplay = "AP",  PracticeMode = "PRC",
}

t[#t+1] = LoadFont("Common Normal") .. {
	Name = "InvalidModsBadges",
	InitCommand = function(self)
		self:y(totalH / 2 + 14):zoom(0.38):valign(0)
		self:diffuse(color("#CF7070")):diffusealpha(0)
		self:shadowlength(1):shadowcolor(color("0,0,0,0.8"))
	end,
	CurrentSongChangedMessageCommand = function(self)
		-- Repopulate mods here — this fires after screen is fully loaded
		-- and player options are applied, avoiding the BeginCommand ordering bug
		if GetInvalidatingMods then
			invalidMods = GetInvalidatingMods(PLAYER_1)
		end
		if #invalidMods > 0 then
			local badges = {}
			for _, mod in ipairs(invalidMods) do
				local short = modShorthand[mod] or mod:sub(1, 3):upper()
				table.insert(badges, "[" .. short .. "]")
			end
			self:settext("INVALIDATING MODS ACTIVE:  " .. table.concat(badges, "  "))
			self:stoptweening()
			self:decelerate(0.8):diffusealpha(1)
		else
			self:diffusealpha(0)
		end
	end,
	SongStartingMessageCommand = function(self)
		if #invalidMods > 0 then
			self:stoptweening()
			self:sleep(1):smooth(0.8):diffusealpha(0)
		end
	end
}

-- ============================================================
-- TARGET GOAL & AUTO-FAIL DISPLAY (above banner)
-- ============================================================
t[#t+1] = Def.ActorFrame{
	Name = "IntroBannerExtra",
	CurrentSongChangedMessageCommand = function(self)
		local targetActor = self:GetChild("TargetGoal")
		local failActor = self:GetChild("AutoFail")
		local bg = self:GetChild("ExtraBG")
		
		-- Target Goal
		local showGoal = ThemePrefs.Get("HV_ShowGoalTracker")
		if showGoal then
			local pacemakerMode = ThemePrefs.Get("HV_PacemakerTargetType") or "Target"
			if pacemakerMode == "PB" or pacemakerMode == "PBReplay" then
				local best = GetDisplayScore()
				if best then
					targetActor:settext(string.format("Target: PB %.2f%%", getJ4NormalizedPercentage(best)))
				else
					local goal = ThemePrefs.Get("HV_PacemakerTargetGoal") or 93
					targetActor:settext(string.format("Target: %.2f%%", goal))
				end
			else
				local goal = ThemePrefs.Get("HV_PacemakerTargetGoal") or 93
				targetActor:settext(string.format("Target: %.2f%%", goal))
			end
			targetActor:visible(true)
		else
			targetActor:visible(false)
		end
		
		-- Auto-Fail
		local failMode = ThemePrefs.Get("HV_AutoFailMode")
		local hasFail = failMode and failMode ~= "Off"
		if hasFail then
			local condition = ThemePrefs.Get("HV_AutoFailCondition")
			local threshold = ""
			if condition == "Wife Percent" then
				threshold = string.format("< %.2f%%", ThemePrefs.Get("HV_AutoFailThreshold_Wife") or 93)
			elseif condition == "Judgement Count" then
				local judge = ThemePrefs.Get("HV_AutoFailJudgement") or "Miss"
				local judgeName = THEME:GetString("TapNoteScore", judge)
				threshold = string.format(">= %d %s", ThemePrefs.Get("HV_AutoFailThreshold_Count") or 10, judgeName)
			elseif condition == "Personal Best" then
				local best = GetDisplayScore()
				local pbStr = ""
				if best then
					pbStr = string.format(" (%.2f%%)", getJ4NormalizedPercentage(best))
				end
				threshold = "PB" .. pbStr
			end
			failActor:settext(string.format("Auto-Fail: %s (%s)", failMode, threshold))
			failActor:visible(true)
		else
			failActor:visible(false)
		end

		-- Background visibility
		bg:visible(showGoal or hasFail)
	end,

	Def.Quad{
		Name = "ExtraBG",
		InitCommand = function(self)
			self:y(-48):zoomto(totalW + 20, 26)
			self:diffuse(color("#000000")):diffusealpha(0.5)
			self:fadeleft(0.4):faderight(0.4)
		end
	},

	LoadFont("Common Normal") .. {
		Name = "TargetGoal",
		InitCommand = function(self)
			self:y(-42):zoom(0.35):diffuse(color("#FFFFFF")):diffusealpha(0.8)
			self:shadowlength(1):shadowcolor(color("0,0,0,0.5"))
		end
	},
	LoadFont("Common Normal") .. {
		Name = "AutoFail",
		InitCommand = function(self)
			self:y(-54):zoom(0.35):diffuse(color("#FF8888")):diffusealpha(0.8)
			self:shadowlength(1):shadowcolor(color("0,0,0,0.5"))
		end
	}
}

return t
