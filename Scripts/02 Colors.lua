--- Holographic Void: Monochromatic Color Palette
-- @module 02_Colors
-- Extends _Fallback's Color module with theme-specific colors.
-- All primary UI colors are shades of gray/white on OLED black.

HVColor = {
	-- Core palette (OLED blacks, whites, grays)
	Black       = color("0,0,0,1"),              -- #000000 - True OLED black
	BG1         = color("0.04,0.04,0.04,1"),     -- #0A0A0A - Deepest background
	BG2         = color("0.08,0.08,0.08,1"),     -- #141414 - Card/panel background
	BG3         = color("0.12,0.12,0.12,1"),     -- #1F1F1F - Elevated surface
	Border      = color("0.18,0.18,0.18,1"),     -- #2E2E2E - Subtle borders
	Separator   = color("0.22,0.22,0.22,1"),     -- #383838 - Dividers / separators
	TextDim     = color("0.45,0.45,0.45,1"),     -- #737373 - Disabled / dim text
	TextSub     = color("0.65,0.65,0.65,1"),     -- #A6A6A6 - Subtitle / secondary text
	Text        = color("0.85,0.85,0.85,1"),     -- #D9D9D9 - Primary body text
	TextBright  = color("1,1,1,1"),               -- #FFFFFF - Headers / emphasis
	White       = color("1,1,1,1"),               -- #FFFFFF

	-- Accent: configurable via ThemePrefs, defaults to a cool blue-white
	Accent      = color("#5ABAFF"),               -- Default accent (icy blue)
	AccentDim   = color("#2A6A9F"),               -- Dimmed accent for hover states

	-- Transparent overlays
	Overlay50   = color("0,0,0,0.5"),
	Overlay75   = color("0,0,0,0.75"),
	Overlay90   = color("0,0,0,0.9"),
}

--- Update the accent color from theme preferences.
-- Called after ThemePrefs loads to apply user's chosen accent.
function HVColor.RefreshAccent()
	if ThemePrefs and ThemePrefs.Get then
		local hex = ThemePrefs.Get("HV_AccentColor")
		if hex and hex ~= "" then
			HVColor.Accent = color(hex)
			-- Derive a dimmed version at 60% brightness
			local hsv = ColorToHSV(HVColor.Accent)
			if type(hsv) == "table" and hsv.Hue and hsv.Sat and hsv.Value then
				HVColor.AccentDim = HSV(hsv.Hue, hsv.Sat, hsv.Value * 0.6)
			else
				HVColor.AccentDim = color("#2A6A9F")
			end
		end
	end
end

-- Difficulty colors
HVColor.DifficultyHolographic = {
	Beginner    = color("#98B8CF"),   -- Light gray
	Easy        = color("#A0CFAB"),   -- Muted green-gray
	Medium      = color("#CFD198"),   -- Muted gold-gray
	Hard        = color("#CF9898"),   -- Muted red-gray
	Challenge   = color("#B898CF"),   -- Muted blue-gray
	Edit        = color("#8C8C8C"),   -- Muted purple-gray
}

HVColor.DifficultyClassic = {
	Beginner    = color("#66CCFF"),
	Easy        = color("#099948"),
	Medium      = color("#DDAA00"),
	Hard        = color("#FF6666"),
	Challenge   = color("#C97BFF"),
	Edit        = color("#666666"),
}

HVColor.Difficulty = HVColor.DifficultyHolographic

--- Refresh global difficulty color overrides based on style.
function HVColor.RefreshDifficultyColors()
	local style = ThemePrefs.Get("HV_DifficultyColorStyle") or "Holographic"
	local s = tostring(style):lower()
	local palette
	if s == "custom" and HVCustomColors then
		palette = {
			Beginner    = color(HVCustomColors.GetColor("difficulty", "Beginner")),
			Easy        = color(HVCustomColors.GetColor("difficulty", "Easy")),
			Medium      = color(HVCustomColors.GetColor("difficulty", "Medium")),
			Hard        = color(HVCustomColors.GetColor("difficulty", "Hard")),
			Challenge   = color(HVCustomColors.GetColor("difficulty", "Challenge")),
			Edit        = color(HVCustomColors.GetColor("difficulty", "Edit")),
		}
	elseif s == "classic" then
		palette = HVColor.DifficultyClassic
	else
		palette = HVColor.DifficultyHolographic
	end
	HVColor.Difficulty = palette
	
	if GameColor and GameColor.Difficulty then
		for k, v in pairs(palette) do
			GameColor.Difficulty[k] = v
			GameColor.Difficulty["Difficulty_" .. k] = v
		end
	end
end

--- Get a color for a difficulty short name (e.g. "Hard", "Challenge", "Edit").
function HVColor.GetDifficultyColor(diff)
	HVColor.RefreshDifficultyColors() -- Ensure we are using correct palette
	if not diff then return HVColor.Difficulty.Edit end
	local s = diff:gsub("Difficulty_", "")
	return HVColor.Difficulty[s] or HVColor.Difficulty.Edit
end

-- Judgment colors (kept distinct but desaturated to fit the theme)
HVColor.JudgmentHolographic = {
	Ridiculous = color("#FFD7FF"),
	W1   = color("#f1ffff"),    -- Marvelous: pure white
	W2   = color("#FFFFB7"),    -- Perfect: warm off-white
	W3   = color("#A0E0A0"),    -- Great: pale green
	W4   = color("#A0C8E0"),    -- Good: pale blue
	W5   = color("#C8A0E0"),    -- Bad: pale purple
	Miss = color("#E0A0A0"),    -- Miss: pale red
	Held = color("#8fbb84ff"),    -- OK (Held)
	LetGo = color("#E0A0A0"),   -- NG (LetGo)
}

HVColor.JudgmentClassic = {
	Ridiculous = color("#FF66CC"),
	W1   = color("#99CCFF"),
	W2   = color("#F2CB30"),
	W3   = color("#14CC8F"),
	W4   = color("#1AB2FF"),
	W5   = color("#FF1AB3"),
	Miss = color("#CC2929"),
	Held = color("#F2CB30"),    -- Til Death Held (OK)
	LetGo = color("#CC2929"),   -- Til Death LetGo (NG)
}

--- Refresh global judgment colors based on style.
function HVColor.RefreshJudgmentColors()
	local style = ThemePrefs.Get("HV_JudgmentColorStyle") or "Holographic"
	local s = tostring(style):lower()
	if s == "custom" and HVCustomColors then
		HVColor.Judgment = {
			Ridiculous = color(HVCustomColors.GetColor("judgment", "Ridiculous")),
			W1   = color(HVCustomColors.GetColor("judgment", "W1")),
			W2   = color(HVCustomColors.GetColor("judgment", "W2")),
			W3   = color(HVCustomColors.GetColor("judgment", "W3")),
			W4   = color(HVCustomColors.GetColor("judgment", "W4")),
			W5   = color(HVCustomColors.GetColor("judgment", "W5")),
			Miss = color(HVCustomColors.GetColor("judgment", "Miss")),
			Held = color(HVCustomColors.GetColor("judgment", "Held")),
			LetGo = color(HVCustomColors.GetColor("judgment", "LetGo")),
		}
	elseif s == "classic" then
		HVColor.Judgment = HVColor.JudgmentClassic
	else
		HVColor.Judgment = HVColor.JudgmentHolographic
	end
end

--- Get a color for a Judgment type based on style.
function HVColor.GetJudgmentColor(judge)
	HVColor.RefreshJudgmentColors() -- Ensure we are using correct palette
	local palette = HVColor.Judgment
	
	if not judge then return palette.Miss end
	local s = tostring(judge):gsub("TapNoteScore_", ""):gsub("HoldNoteScore_", "")
	
	-- Map internal scores to the palette
	if s == "Ridiculous" or s == "W0" then return palette.Ridiculous or palette.W1 end
	if s == "W1" then return palette.W1 end
	if s == "W2" then return palette.W2 end
	if s == "W3" then return palette.W3 end
	if s == "W4" then return palette.W4 end
	if s == "W5" then return palette.W5 end
	if s == "Miss" then return palette.Miss end
	
	-- Hold score mappings
	if s == "Held" then return palette.Held or palette.W1 end
	if s == "LetGo" then return palette.LetGo or palette.Miss end
	
	return palette[s] or palette.Miss
end

-- MSD rating color scale (smooth gradient)
local msdTable = {
	{0, color("#80C0CF")},  -- Muted Cyan
	{10, color("#A0CFAB")}, -- Green
	{15, color("#CFD198")}, -- Yellow
	{20, color("#E0B080")}, -- Muted Orange
	{25, color("#CF9898")}, -- Muted Red
	{30, color("#CF98B8")}, -- Muted Pink
	{35, color("#B898CF")}, -- Muted Purple
	{40, color("#5C4B7A")}, -- Dark Purple
}

--- Get a color for a numeric MSD value based on theme preferences.
-- @param msd Number (0-40+)
-- @return Color
function HVColor.GetMSDRatingColor(msd)
	if not msd or msd < 0 then return msdTable[1][2] end

	local scale = "Holographic"
	if ThemePrefs and ThemePrefs.Get then
		local prefValue = ThemePrefs.Get("HV_MSDColorScaleV3")
		-- Robust fallback: if preference is empty, nil, or explicitly "None" (which was causing issues), 
		-- default to our premium "Holographic" scale.
		if prefValue and prefValue ~= "" then
			scale = prefValue
		end
	end

	-- Normalize case for robustness
	local s = scale:lower()
	if s == "classic" then
		-- Classic Til Death hue shift logic
		return HSV(math.max(95 - (msd / 40) * 150, -50), 0.9, 0.9)
	elseif s == "none" then
		-- Static White
		return color("#FFFFFF")
	elseif s == "monochrome" then
		-- Asymptotically darker (White -> Dark Gray)
		local v = 1.0 / (1.0 + (msd * 0.04))
		return color(v..","..v..","..v..",1")
	elseif s == "accent" then
		-- Match current accent color
		return HVColor.Accent or color("#5ABAFF")
	end

	-- Holographic Void: smooth interpolation between muted thresholds
	for i = 1, #msdTable - 1 do
		local lower = msdTable[i]
		local upper = msdTable[i+1]
		if msd >= lower[1] and msd <= upper[1] then
			local p = (msd - lower[1]) / (upper[1] - lower[1])
			return HV.LerpColor(p, lower[2], upper[2])
		end
	end

	if msd > 40 then return msdTable[#msdTable][2] end
	return msdTable[1][2]
end

-- Clear Type colors
HVColor.ClearTypeHolographic = {
	RFC     = color("#FFD7FF"),
	RF      = color("#E8C8F8"),
	SDM     = color("#D8C0F0"),
	MFC     = color("#E0F8FF"), -- Slightly cyan white (Marvelous Full Combo)
	WF      = color("#E0E0E0"), -- Muted White (White Flag - 1xW2 FC)
	SDP     = color("#CFD198"), -- Muted Yellow (Single Digit Perfects)
	PFC     = color("#CFD198"), -- Muted Yellow (Perfect Full Combo)
	BF      = color("#B898CF"), -- Muted Purple (Black Flag - 1xW3 FC)
	SDG     = color("#A0CFAB"), -- Muted Green (Single Digit Greats)
	FC      = color("#A0CFAB"), -- Muted Green (Full Combo)
	MF      = color("#CF9898"), -- Muted Red (Miss Flag - 1xMiss)
	SDCB    = color("#80C0CF"), -- Muted Cyan (Single Digit Combo Breakers)
	Clear   = color("#5ABAFF"), -- Accent Blue
	Failed  = color("#CF9898"), -- Muted Red
	Invalid = color("#454545"), -- Dim Gray
	NoPlay  = color("#252525"), -- Darkest Gray
	None    = color("#252525"), -- Darkest Gray
	SoftInvalid = color("#A68060"), -- Muted Bronze/Amber
}

HVColor.ClearTypeClassic = {
	RFC     = color("#FF66CC"),
	RF      = color("#DD66FF"),
	SDM     = color("#BB66FF"),
	MFC     = color("#66CCFF"),
	WF      = color("#DDDDDD"),
	SDP     = color("#CC8800"),
	PFC     = color("#EEAA00"),
	BF      = color("#999999"),
	SDG     = color("#448844"),
	FC      = color("#66CC66"),
	MF      = color("#CC6666"),
	SDCB    = color("#33BBFF"),
	Clear   = color("#33AAFF"),
	Failed  = color("#E61E25"),
	Invalid = color("#E61E25"),
	NoPlay  = color("#666666"),
	None    = color("#666666"),
	SoftInvalid = color("#CC8844"),
}

--- Refresh global clear type colors based on style.
function HVColor.RefreshClearTypeColors()
	local style = ThemePrefs.Get("HV_ClearTypeColorStyle") or "Holographic"
	local s = tostring(style):lower()
	if s == "custom" and HVCustomColors then
		HVColor.ClearType = {
			RFC     = color(HVCustomColors.GetColor("clearType", "RFC")),
			RF      = color(HVCustomColors.GetColor("clearType", "RF")),
			SDM     = color(HVCustomColors.GetColor("clearType", "SDM")),
			MFC     = color(HVCustomColors.GetColor("clearType", "MFC")),
			WF      = color(HVCustomColors.GetColor("clearType", "WF")),
			SDP     = color(HVCustomColors.GetColor("clearType", "SDP")),
			PFC     = color(HVCustomColors.GetColor("clearType", "PFC")),
			BF      = color(HVCustomColors.GetColor("clearType", "BF")),
			SDG     = color(HVCustomColors.GetColor("clearType", "SDG")),
			FC      = color(HVCustomColors.GetColor("clearType", "FC")),
			MF      = color(HVCustomColors.GetColor("clearType", "MF")),
			SDCB    = color(HVCustomColors.GetColor("clearType", "SDCB")),
			Clear   = color(HVCustomColors.GetColor("clearType", "Clear")),
			Failed  = color(HVCustomColors.GetColor("clearType", "Failed")),
			Invalid = color(HVCustomColors.GetColor("clearType", "Invalid")),
			NoPlay  = color(HVCustomColors.GetColor("clearType", "NoPlay")),
			None    = color(HVCustomColors.GetColor("clearType", "None")),
			SoftInvalid = color(HVCustomColors.GetColor("clearType", "SoftInvalid")),
		}
	elseif s == "classic" then
		HVColor.ClearType = HVColor.ClearTypeClassic
	else
		HVColor.ClearType = HVColor.ClearTypeHolographic
	end
end

--- Get a color for a Clear Type string.
function HVColor.GetClearTypeColor(ct)
	HVColor.RefreshClearTypeColors() -- Ensure we are using correct palette
	local palette = HVColor.ClearType

	if not ct then return palette.Clear end
	local s = ct:upper():gsub(" ", ""):gsub("CLEARTYPE_", "")
	
	if palette[s] then return palette[s] end
	
	-- Fallback patterns
	if s:find("MARVELOUS") then return palette.MFC end
	if s:find("PERFECT")   then return palette.PFC end
	if s:find("COMBO")     then return palette.FC end
	if s:find("FAILED")    then return palette.Failed end
	if s:find("SOFT")      then return palette.SoftInvalid end
	if s:find("INVALID")   then return palette.Invalid end
	return palette.Clear
end

-- Song Length colors
HVColor.SongLength = {
	Normal   = color("#D9D9D9"), -- Standard text
	Long     = color("#E0B080"), -- Muted Orange (>= 2:30)
	Marathon = color("#CF9898"), -- Muted Red (>= 5:00)
}

--- Get a color for song duration in seconds.
function HVColor.GetSongLengthColor(seconds)
	if not seconds then return HVColor.SongLength.Normal end
	if seconds >= 300 then return HVColor.SongLength.Marathon end
	if seconds >= 150 then return HVColor.SongLength.Long end
	return HVColor.SongLength.Normal
end

-- Grade colors (muted, matching the theme aesthetic)
HVColor.Grade = {
	AAAAA = color("#FFFFFF"),    -- Pure White
	AAAA  = color("#80C0CF"),    -- Muted Cyan
	AAA   = color("#CFD198"),    -- Muted Yellow
	AA    = color("#A0CFAB"),    -- Muted Green
	A     = color("#CF9898"),    -- Muted Red
	B     = color("#98B8CF"),    -- Muted Blue-Gray
	C     = color("#B898CF"),    -- Muted Purple
	D     = color("#CF98B8"),    -- Muted Pink
	F     = color("#606060"),    -- Dim Gray
	None  = color("#454545"),    -- Dim Gray
}

-- Classic Til Death grade colors
HVColor.GradeClassic = {
	AAAAA = color("#FFFFFF"),    -- White
	AAAA  = color("#66CCFF"),    -- Cyan
	AAA   = color("#EEBB00"),    -- Yellow
	AA    = color("#66cc66"),    -- Green
	A     = color("#DA5757"),    -- Red
	B     = color("#5B78BB"),    -- Blue
	C     = color("#C97BFF"),    -- Purple
	D     = color("#8C6239"),    -- Pink
	F     = color("#CDCDCD"),    -- Gray
	None  = color("#666666"),    -- Dark Gray
}

--- Refresh global grade colors based on style.
function HVColor.RefreshGradeColors()
	local style = ThemePrefs.Get("HV_GradeColorStyle") or "Holographic"
	local s = tostring(style):lower()
	if s == "custom" and HVCustomColors then
		HVColor.GradePalette = {
			AAAAA = color(HVCustomColors.GetColor("grades", "AAAAA")),
			AAAA  = color(HVCustomColors.GetColor("grades", "AAAA")),
			AAA   = color(HVCustomColors.GetColor("grades", "AAA")),
			AA    = color(HVCustomColors.GetColor("grades", "AA")),
			A     = color(HVCustomColors.GetColor("grades", "A")),
			B     = color(HVCustomColors.GetColor("grades", "B")),
			C     = color(HVCustomColors.GetColor("grades", "C")),
			D     = color(HVCustomColors.GetColor("grades", "D")),
			F     = color(HVCustomColors.GetColor("grades", "F")),
			None  = color(HVCustomColors.GetColor("grades", "None")),
			["AAAA:"] = color(HVCustomColors.GetColor("grades", "AAAA:")),
			["AAAA."] = color(HVCustomColors.GetColor("grades", "AAAA.")),
			["AAA:"]  = color(HVCustomColors.GetColor("grades", "AAA:")),
			["AAA."]  = color(HVCustomColors.GetColor("grades", "AAA.")),
			["AA:"]   = color(HVCustomColors.GetColor("grades", "AA:")),
			["AA."]   = color(HVCustomColors.GetColor("grades", "AA.")),
			["A:"]    = color(HVCustomColors.GetColor("grades", "A:")),
			["A."]    = color(HVCustomColors.GetColor("grades", "A.")),
		}
	elseif s == "classic" then
		HVColor.GradePalette = HVColor.GradeClassic
	else
		HVColor.GradePalette = HVColor.Grade
	end
end

--- Get a color for a Grade string or enum.
function HVColor.GetGradeColor(grade)
	HVColor.RefreshGradeColors() -- Ensure we are using correct palette
	local palette = HVColor.GradePalette or HVColor.Grade

	if not grade then return palette.None end
	local s = tostring(grade):upper():gsub("GRADE_", "")
	
	-- Handle Tier specific matches first (Etterna Tiers)
	if s:find("TIER01") then return palette.AAAAA end
	if s:find("TIER02") or s:find("TIER03") or s:find("TIER04") then return palette.AAAA end
	if s:find("TIER05") or s:find("TIER06") or s:find("TIER07") then return palette.AAA end
	if s:find("TIER08") or s:find("TIER09") or s:find("TIER10") then return palette.AA end
	if s:find("TIER11") or s:find("TIER12") or s:find("TIER13") then return palette.A end
	if s:find("TIER14") then return palette.B end
	if s:find("TIER15") then return palette.C end
	if s:find("TIER16") then return palette.D end
	if s:find("TIER17") or s:find("FAILED") then return palette.F end
	
	-- Fallback text matches
	if s:find("AAAAA") then return palette.AAAAA end
	if s:find("AAAA")  then return palette.AAAA end
	if s:find("AAA")   then return palette.AAA  end
	if s:find("AA")    then return palette.AA   end
	if s:find("A")     then return palette.A    end
	if s:find("B")     then return palette.B    end
	if s:find("C")     then return palette.C    end
	if s:find("D")     then return palette.D    end
	
	return palette.None
end

-- Goal Tracker colors
HVColor.GoalTrackerHolographic = {
	Positive = color("#A0CFAB"),
	Negative = color("#CF9898"),
}

HVColor.GoalTrackerClassic = {
	Positive = color("#4CBB17"),
	Negative = color("#FF9999"),
}

HVColor.GoalTracker = HVColor.GoalTrackerHolographic

--- Refresh goal tracker colors from Custom values with Holographic fallbacks.
function HVColor.RefreshGoalTrackerColors()
	local positive = "#A0CFAB"
	local negative = "#CF9898"

	if HVCustomColors and HVCustomColors.GetColor then
		positive = HVCustomColors.GetColor("goalTracker", "Positive") or positive
		negative = HVCustomColors.GetColor("goalTracker", "Negative") or negative
	end

	HVColor.GoalTracker = {
		Positive = color(positive),
		Negative = color(negative),
	}
	HVColor.Positive = HVColor.GoalTracker.Positive
	HVColor.Negative = HVColor.GoalTracker.Negative
end

--- Get a goal tracker color (positive or negative)
function HVColor.GetGoalTrackerColor(type)
	HVColor.RefreshGoalTrackerColors()
	if type == "positive" then return HVColor.GoalTracker.Positive end
	if type == "negative" then return HVColor.GoalTracker.Negative end
	return HVColor.GoalTracker.Positive
end

HVColor.LifeBarDefaults = {
	L1 = color("#A0CFAB"),
	L2 = color("#A0CFAB"),
	L3 = color("#5ABAFF"),
	L4 = color("#5ABAFF"),
	L5 = color("#CFD198"),
	L6 = color("#E0B080"),
	L7 = color("#CF9898"),
	Danger = color("#FF4444"),
}

function HVColor.GetLifeBarColor(key)
	if HVCustomColors and HVCustomColors.GetColor then
		return color(HVCustomColors.GetColor("lifeBar", key))
	end
	return HVColor.LifeBarDefaults[key] or HVColor.Accent
end

HVColor.RadarDefaults = {
	Power = color("#E0B080"),
	Chaos = color("#B898CF"),
	Hell = color("#CF9898"),
	Mach = color("#80C0CF"),
	Freeze = color("#CFD198"),
	Earth = color("#A0CFAB"),
}

function HVColor.GetRadarColor(key)
	if HVCustomColors and HVCustomColors.GetColor then
		return color(HVCustomColors.GetColor("radar", key))
	end
	return HVColor.RadarDefaults[key] or HVColor.Accent
end

--- Get a color for an online rank number.
function HVColor.GetSkillsetRankColor(rank)
	if not rank or rank <= 0 then return color("#737373") end
	
	if rank <= 10 then return color("#CFD198") end       -- Top 10 (Muted Gold)
	if rank <= 50 then return color("#A0CFAB") end       -- Top 50 (Muted Green)
	if rank <= 100 then return color("#80C0CF") end      -- Top 100 (Muted Cyan)
	if rank <= 500 then return color("#D9D9D9") end      -- Top 500 (White-Gray)
	return color("#A6A6A6")                              -- Fallback (Subtitle Text)
end

-- Global helper expected by some fallback or legacy scripts
function getMainColor(type)
	if not type or type == "" then return HVColor.Accent end
	if type == "highlight" then return HVColor.Accent end
	if type == "positive" then return color("#A0CFAB") end
	if type == "negative" then return color("#CF9898") end
	-- Fallback for any other requested type
	return HVColor.Accent
end

-- Initial refresh
if ThemePrefs and ThemePrefs.Get then
	HVColor.RefreshAccent()
	HVColor.RefreshDifficultyColors()
	HVColor.RefreshJudgmentColors()
	HVColor.RefreshClearTypeColors()
	HVColor.RefreshGradeColors()
	HVColor.RefreshGoalTrackerColors()
end

Trace("Holographic Void: 02 Colors.lua loaded.")
