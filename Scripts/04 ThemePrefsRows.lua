--- Holographic Void: ThemePrefs Option Rows
-- @module 04_ThemePrefsRows
-- Defines option row handlers for the in-client ThemePrefs system.
-- These rows appear in ScreenOptionsService when theme options are accessed.
-- Uses _Fallback's ThemePrefsRows.Init system.

-- Generate 5% increment tables for Lane Cover heights (0-100%)
local laneCoverChoices = {"Off"}
local laneCoverValues = {0}
for i = 1, 20 do
	local val = i * 5
	table.insert(laneCoverChoices, tostring(val) .. "%")
	table.insert(laneCoverValues, val)
end

local HVPrefRows = {
	-- Auto Login Tokens (Secret, non-visible in menu)
	HV_Username = {
		Default = "",
		Choices = {""},
		Values  = {""},
	},
	HV_PasswordToken = {
		Default = "",
		Choices = {""},
		Values  = {""},
	},


	-- Background Animation Intensity
	HV_BGAnimIntensity = {
		Default = 1,
		Choices = {"Off", "Subtle", "Full"},
		Values = {0, 1, 2},
	},

	-- Mouse Parallax
	HV_Parallax = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Song Preview Mode
	HV_SongPreview = {
		Default = 1,
		Choices = {"SM Style", "osu! Style (New)", "osu! Style (Old)"},
		Values = {1, 2, 3},
	},


	-- Show MSD Ratings
	HV_ShowMSD = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},


	-- Show Profile Stats on Select Music
	HV_ShowProfileStats = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},




	-- Show Measure Lines
	HV_ShowMeasureLines = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Screen Filter
	HV_ScreenFilter = {
		Default = 0.0,
		Choices = {"0%", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "100%"},
		Values = {0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0},
	},


	-- Song Background Brightness
	HV_SongBackgroundBrightness = {
		Default = 0.5,
		Choices = {"0%", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "100%"},
		Values = {0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0},
	},

	-- Lane Cover
	HV_LaneCoverSudden = {
		Default = 0,
		Choices = laneCoverChoices,
		Values = laneCoverValues,
	},
	HV_LaneCoverHidden = {
		Default = 0,
		Choices = laneCoverChoices,
		Values = laneCoverValues,
	},

	-- Glow Effects
	HV_EnableGlow = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Show NPS
	HV_ShowNPS = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- NPS Window Size
	HV_NPSWindowSize = {
		Default = 1,
		Choices = {"1s", "2s", "3s", "4s", "5s"},
		Values = {1, 2, 3, 4, 5},
	},

	-- Error Bar Mode
	HV_ErrorBarMode = {
		Default = "Standard",
		Choices = {"Off", "Standard", "EWMA Only", "Both"},
		Values  = {"Off", "Standard", "EWMAOnly", "Both"},
	},

	-- Error Bar Coloring Mode
	HV_ErrorBarColoringMode = {
		Default = "Current",
		Choices = {"J4", "Current Judge"},
		Values  = {"J4", "Current"},
	},

	-- Show Full Pacemaker Graph
	HV_ShowPacemakerGraph = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Show Mini Text Goal Tracker (formerly Pacemaker)
	HV_ShowGoalTracker = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Pacemaker Target Type
	HV_PacemakerTargetType = {
		Default = "Target",
		Choices = {"Target", "PB", "PB Replay"},
		Values  = {"Target", "PB", "PBReplay"},
	},

	-- Pacemaker Target Goal
	HV_PacemakerTargetGoal = {
		Default = 93,
		Choices = {
			"0%", "1%", "2%", "3%", "4%", "5%", "6%", "7%", "8%", "9%", "10%",
			"11%", "12%", "13%", "14%", "15%", "16%", "17%", "18%", "19%", "20%",
			"21%", "22%", "23%", "24%", "25%", "26%", "27%", "28%", "29%", "30%",
			"31%", "32%", "33%", "34%", "35%", "36%", "37%", "38%", "39%", "40%",
			"41%", "42%", "43%", "44%", "45%", "46%", "47%", "48%", "49%", "50%",
			"51%", "52%", "53%", "54%", "55%", "56%", "57%", "58%", "59%", "60%",
			"61%", "62%", "63%", "64%", "65%", "66%", "67%", "68%", "69%", "70%",
			"71%", "72%", "73%", "74%", "75%", "76%", "77%", "78%", "79%", "80%",
			"81%", "82%", "83%", "84%", "85%", "86%", "87%", "88%", "89%", "90%",
			"91%", "92%", "93%", "94%", "95%", "96%", "97%", "98%", "99%",
			"99.50%", "99.70%", "99.80%", "99.90%", "99.95%",
			"99.96%", "99.97%", "99.98%", "99.99%",
			"99.990%", "99.991%", "99.992%", "99.993%", "99.994%",
			"99.995%", "99.996%", "99.997%", "99.998%", "99.999%", "100%"
		},
		Values = {
			0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
			11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
			21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
			31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
			41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
			51, 52, 53, 54, 55, 56, 57, 58, 59, 60,
			61, 62, 63, 64, 65, 66, 67, 68, 69, 70,
			71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
			81, 82, 83, 84, 85, 86, 87, 88, 89, 90,
			91, 92, 93, 94, 95, 96, 97, 98, 99,
			99.50, 99.70, 99.80, 99.90, 99.95,
			99.96, 99.97, 99.98, 99.99,
			99.990, 99.991, 99.992, 99.993, 99.994,
			99.995, 99.996, 99.997, 99.998, 99.999, 100
		},
	},

	-- Show Particles
	HV_Particles = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Show Mean on Notefield
	HV_ShowMean = {
		Default = "Mean",
		Choices = {"Off", "Mean", "Std Dev", "J4 Score", "MA Ratio", "Delta Hand"},
		Values = {"Off", "Mean", "StdDev", "J4", "MARatio", "DeltaHand"},
	},
	
	-- Accent Color
	HV_AccentColor = {
		Default = "#5ABAFF",
		Choices = {"Blue", "Pink", "Mint", "Orange", "Purple", "White"},
		Values  = {"#5ABAFF", "#FF5ABB", "#5AFFBA", "#FFBA5A", "#BA5AFF", "#D9D9D9"},
	},

	-- Use Custom Grade Names (from grade.costom.md)
	HV_UseCustomGrades = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true},
	},


	
	-- Background Effect Style
	HV_BackgroundEffect = {
		Default = "Grid",
		Choices = {"Grid", "Hex", "Scanlines", "Flow", "Rays", "None"},
		Values  = {"Grid", "Hex", "Scanlines", "Flow", "Rays", "None"},
	},

	-- Title Screen Text Mode
	HV_QuotesMode = {
		Default = "Quotes",
		Choices = {"Off", "Quotes", "Tips"},
		Values  = {"Off", "Quotes", "Tips"},
	},

	-- Gameplay HUD Customization
	HV_ShowJudgment = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},
	HV_ShowCombo = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},
	HV_ShowCurrentWife = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},
	HV_ShowJudgeCounter = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},
	HV_ShowPlayerInfo = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},
	HV_ProgressBarPosition = {
		Default = "Top",
		Choices = {"Top", "Bottom", "Off"},
		Values = {"Top", "Bottom", "Off"},
	},
	HV_ShowInGameLeaderboard = {
		Default = "Off",
		Choices = {"Off", "Local", "Online"},
		Values = {"Off", "Local", "Online"},
	},
	HV_ShowNPSGraph = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},
	HV_ComboBreakHighlight = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},
	HV_AssistMode = {
		Default = "Off",
		Choices = {"Off", "Clap", "Metronome", "Both"},
		Values = {"Off", "Clap", "Metronome", "Both"},
	},
	HV_GoalTrackerText = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Minimalistic Mode
	HV_MinimalisticMode = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Judgment Tally Mode
	HV_JudgeCounterMode = {
		Default = "Full",
		Choices = {"Full", "Simple"},
		Values = {"Full", "Simple"},
	},

	-- NG Indicator
	HV_ShowNGIndicator = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},
	-- Instant Search
	HV_InstantSearch = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Prioritize Lower Judgements
	HV_PrioritizeLowerJudgements = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Display Lower Judgement Offset
	HV_DisplayLowerJudgementOffset = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Offset Display Judgement
	HV_OffsetDisplayJudgement = {
		Default = "W3",
		Choices = {"Marvelous", "Perfect", "Great", "Good", "Bad"},
		Values = {"W1", "W2", "W3", "W4", "W5"},
	},

	-- Judgment Animation
	HV_JudgmentAnimation = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Combo Animation
	HV_ComboAnimation = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Recent Judgement Display
	HV_RecentJudgmentDisplay = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Score Display Mode
	HV_ScoreDisplayMode = {
		Default = "Normal",
		Choices = {"Normal", "Subtractive"},
		Values = {"Normal", "Subtractive"},
	},

	-- Auto-Fail Action Mode
	HV_AutoFailMode = {
		Default = "Off",
		Choices = {"Off", "Fail", "Restart"},
		Values = {"Off", "Fail", "Restart"},
	},

	-- Auto-Fail Trigger Condition
	HV_AutoFailCondition = {
		Default = "Wife Percent",
		Choices = {"Wife Percent", "Judgement Count", "Personal Best"},
		Values = {"Wife Percent", "Judgement Count", "Personal Best"},
	},

	-- Auto-Fail Judgement
	HV_AutoFailJudgement = {
		Default = "Miss",
		Choices = {"Perfect", "Great", "Good", "Bad", "Miss"},
		Values = {"W2", "W3", "W4", "W5", "Miss"},
	},

	-- Auto-Fail Threshold Wife Percent
	HV_AutoFailThreshold_Wife = {
		Default = 93,
		Choices = {
			"0%", "1%", "2%", "3%", "4%", "5%", "6%", "7%", "8%", "9%", "10%",
			"11%", "12%", "13%", "14%", "15%", "16%", "17%", "18%", "19%", "20%",
			"21%", "22%", "23%", "24%", "25%", "26%", "27%", "28%", "29%", "30%",
			"31%", "32%", "33%", "34%", "35%", "36%", "37%", "38%", "39%", "40%",
			"41%", "42%", "43%", "44%", "45%", "46%", "47%", "48%", "49%", "50%",
			"51%", "52%", "53%", "54%", "55%", "56%", "57%", "58%", "59%", "60%",
			"61%", "62%", "63%", "64%", "65%", "66%", "67%", "68%", "69%", "70%",
			"71%", "72%", "73%", "74%", "75%", "76%", "77%", "78%", "79%", "80%",
			"81%", "82%", "83%", "84%", "85%", "86%", "87%", "88%", "89%", "90%",
			"91%", "92%", "93%", "94%", "95%", "96%", "97%", "98%", "99%",
			"99.50%", "99.60%", "99.70%", "99.80%", "99.90%", "99.95%", "99.955%",
			"99.96%", "99.97%", "99.98%", "99.99%",
			"99.990%", "99.991%", "99.992%", "99.993%", "99.9935%", "99.994%",
			"99.995%", "99.996%", "99.997%", "99.998%", "99.999%", "100%"
		},
		Values = {
			0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
			11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
			21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
			31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
			41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
			51, 52, 53, 54, 55, 56, 57, 58, 59, 60,
			61, 62, 63, 64, 65, 66, 67, 68, 69, 70,
			71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
			81, 82, 83, 84, 85, 86, 87, 88, 89, 90,
			91, 92, 93, 94, 95, 96, 97, 98, 99,
			99.50, 99.60, 99.70, 99.80, 99.90, 99.95, 99.955,
			99.96, 99.97, 99.98, 99.99,
			99.990, 99.991, 99.992, 99.993, 99.9935, 99.994,
			99.995, 99.996, 99.997, 99.998, 99.999, 100
		},
	},

	-- Auto-Fail Judgement Limit 0 to 99
	HV_AutoFailThreshold_Count = {
		Default = 10,
		Choices = (function() local c = {}; for i=0, 99 do c[#c+1]=tostring(i) end return c end)(),
		Values = (function() local v = {}; for i=0, 99 do v[#v+1]=i end return v end)(),
	},
	-- Emulate Ridiculous Judgement
	HV_EmulateRidiculous = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true},
	},
} -- End of HVPrefRows

-- Register the rows with the _Fallback ThemePrefsRows system
ThemePrefsRows.Init(HVPrefRows)

-- Helper for 1% - 250% choices
local RSChoices = {}
for i = 1, 250 do
	RSChoices[i] = tostring(i) .. "%"
end

-- ReceptorSize OptionRow (Til' Death style)
function OptionRowMini()
	return {
		Name = "Mini",
		LayoutType = "ShowAllInRow",
		SelectType = "SelectOne",
		OneChoiceForAllPlayers = true,
		ExportOnChange = false,
		ExportOnCancel = true,
		Choices = RSChoices,
		LoadSelections = function(self, list, pn)
			local prefs = tonumber(ThemePrefs.Get("HV_Mini")) or 100
			-- Ensure index is within range [1, 250]
			local idx = math.max(1, math.min(math.floor(prefs), 250))
			list[idx] = true
		end,
		SaveSelections = function(self, list, pn)
			for i = 1, #list do
				if list[i] then
					ThemePrefs.Set("HV_Mini", i)
					ThemePrefs.Save()
					break
				end
			end
		end
	}
end

-- Also register a global function to get all HV option row lines
-- for use in metrics.ini ScreenOptionsService Lines
function HVThemeOptionsLines()
	-- Logical grouping of theme options
	local l = table.concat({
		-- General / Visual
		"HV_BGAnimIntensity", "HV_Parallax", "HV_BackgroundEffect", "HV_Particles", "HV_EnableGlow", "HV_QuotesMode",
		"HV_SongBackgroundBrightness",
		
		-- Music Select
		-- Music Select
		"HV_ShowMSD", "HV_ShowProfileStats", "HV_SongPreview", "HV_InstantSearch",
		
		-- Gameplay HUD
		"HV_MinimalisticMode", "HV_ShowJudgment", "HV_EmulateRidiculous", "HV_JudgmentAnimation", "HV_RecentJudgmentDisplay", "HV_PrioritizeLowerJudgements", "HV_DisplayLowerJudgementOffset", "HV_OffsetDisplayJudgement", "HV_ShowCombo", "HV_ComboAnimation", "HV_ShowCurrentWife",
			"HV_ShowJudgeCounter", "HV_JudgeCounterMode", "HV_ShowNGIndicator",
		"HV_ShowPlayerInfo", "HV_ProgressBarPosition", "HV_ShowInGameLeaderboard",
		
		-- Gameplay Tools
		"HV_ShowNPS", "HV_NPSWindowSize", "HV_ShowNPSGraph", "HV_ErrorBarMode",
		"HV_ErrorBarColoringMode", "HV_ShowMean", "HV_ShowMeasureLines",
		"HV_ComboBreakHighlight", "HV_AssistMode", "HV_ScoreDisplayMode",
		
		-- Goal Tracker
		"HV_ShowGoalTracker",
		
		-- Grades
		"HV_UseCustomGrades"
	}, ",")
	return l
end

-- Wrap ThemePrefRow to ensure it saves to disk immediately when changed
-- Robustly wrap ThemePrefRow to ensure it correctly loads and saves boolean values
local function HVThemePrefRow(name, title)
	local row = ThemePrefRow(name, title)
	local hvPref = HVPrefRows[name]
	
	-- Explicitly set choices and values if we have them in our local table
	if hvPref then
		row.Choices = hvPref.Choices
		row.Values = hvPref.Values
	end
	
	row.ExportOnChange = true
	
	-- Define a robust load function that handles string/boolean mismatch
	row.LoadSelections = function(self, list, pn)
		local val = ThemePrefs.Get(name)
		local found = false
		for i, v in ipairs(self.Values) do
			if v == val or tostring(v) == tostring(val) then
				list[i] = true
				found = true
				break
			end
		end
		-- If not found, default based on truthiness or fallback to first index
		if not found then
			if val == "true" or val == true or val == 1 or val == "1" then
				list[#list] = true -- Usually 'On'
			else
				list[1] = true -- Usually 'Off'
			end
		end
	end

	-- Define a robust save function that ensures disk persistence
	row.SaveSelections = function(self, list, pn)
		local val = nil
		for i, selected in ipairs(list) do
			if selected then
				val = self.Values[i]
				break
						end
		end
		ThemePrefs.Set(name, val)
		ThemePrefs.ForceSave() -- Bypass NeedsSaved check to be certain
	end
	
	return row
end
function OptionRowSongPreview()
	return HVThemePrefRow("HV_SongPreview", "Song Preview Mode")
end
_G["OptionRowSongPreview"] = OptionRowSongPreview


function OptionRowShowMSD()
	return HVThemePrefRow("HV_ShowMSD", "Show MSD Ratings")
end

function OptionRowShowProfileStats()
	return HVThemePrefRow("HV_ShowProfileStats", "Show Profile Stats")
end

function OptionRowInstantSearch()
	return HVThemePrefRow("HV_InstantSearch", "Instant Search")
end

function OptionRowShowNPS()
	return HVThemePrefRow("HV_ShowNPS", "Show NPS")
end

function OptionRowShowMean()
	local row = HVThemePrefRow("HV_ShowMean", "Mean Display")
	row.LoadSelections = function(self, list, pn)
		local val = ThemePrefs.Get("HV_ShowMean")
		if val == true or val == "true" then
			list[2] = true -- "Mean"
		elseif val == false or val == "false" then
			list[1] = true -- "Off"
		else
			local found = false
			for i, v in ipairs(self.Values) do
				if v == val then
					list[i] = true
					found = true
					break
				end
			end
			if not found then
				list[2] = true -- Fallback to "Mean"
			end
		end
	end
	return row
end

function OptionRowPacemakerType()
	return HVThemePrefRow("HV_PacemakerTargetType", "Pacemaker Target Type")
end

function OptionRowPacemakerGoal()
	return HVThemePrefRow("HV_PacemakerTargetGoal", "Pacemaker Target Goal")
end

function OptionRowShowGoalTracker()
	return HVThemePrefRow("HV_ShowGoalTracker", "Goal Tracker")
end


-- ScreenPlayerOptions Helpers
function OptionRowScreenFilter()
	return HVThemePrefRow("HV_ScreenFilter", "Screen Filter")
end

function OptionRowLaneCoverSudden()
	return HVThemePrefRow("HV_LaneCoverSudden", "Sudden Height")
end

function OptionRowLaneCoverHidden()
	return HVThemePrefRow("HV_LaneCoverHidden", "Hidden Height")
end

function OptionRowErrorBarMode()
	return HVThemePrefRow("HV_ErrorBarMode", "Error Bar Mode")
end

function OptionRowErrorBarColoringMode()
	local name = "HV_ErrorBarColoringMode"
	local row = ThemePrefRow(name, "Error Bar Coloring")
	row.Choices = {"J4", "Current Judge"}
	row.Values = {"J4", "Current"}

	row.LoadSelections = function(self, list, pn)
		local val = ThemePrefs.Get(name)
		local found = false
		for i, v in ipairs(self.Values) do
			if v == val then
				list[i] = true
				found = true
				break
			end
		end
		if not found then
			list[2] = true -- Default to index 2 (Current)
		end
	end

	row.SaveSelections = function(self, list, pn)
		local val = "Current"
		for i, selected in ipairs(list) do
			if selected then
				val = self.Values[i]
				break
			end
		end
		ThemePrefs.Set(name, val)
	end
	return row
end

function OptionRowProgressBarPosition()
	return HVThemePrefRow("HV_ProgressBarPosition", "Progress Bar Position")
end

function OptionRowShowJudgment()
	local row = ThemePrefRow("HV_ShowJudgment", "Show Judgment")
	local baseLoad = row.LoadSelections
	row.LoadSelections = function(self, list, pn)
		local val = ThemePrefs.Get("HV_ShowJudgment")
		if val == "true" or val == true then
			list[2] = true  -- On
		else
			list[1] = true  -- Off
		end
	end
	return row
end

function OptionRowEmulateRidiculous()
	return HVThemePrefRow("HV_EmulateRidiculous", "Emulate Ridiculous")
end

function OptionRowShowCombo()
	local row = ThemePrefRow("HV_ShowCombo", "Show Combo")
	local baseLoad = row.LoadSelections
	row.LoadSelections = function(self, list, pn)
		local val = ThemePrefs.Get("HV_ShowCombo")
		if val == "true" or val == true then
			list[2] = true  -- On
		else
			list[1] = true  -- Off
		end
	end
	return row
end

function OptionRowShowCurrentWife()
	local row = ThemePrefRow("HV_ShowCurrentWife", "Show Current %")
	local baseLoad = row.LoadSelections
	row.LoadSelections = function(self, list, pn)
		local val = ThemePrefs.Get("HV_ShowCurrentWife")
		if val == "true" or val == true then
			list[2] = true  -- On
		else
			list[1] = true  -- Off
		end
	end
	return row
end

function OptionRowShowJudgeCounter()
	local row = ThemePrefRow("HV_ShowJudgeCounter", "Show Judge Counter")
	local baseLoad = row.LoadSelections
	row.LoadSelections = function(self, list, pn)
		local val = ThemePrefs.Get("HV_ShowJudgeCounter")
		if val == "true" or val == true then
			list[2] = true  -- On
		else
			list[1] = true  -- Off
		end
	end
	return row
end

function OptionRowShowPlayerInfo()
	local row = ThemePrefRow("HV_ShowPlayerInfo", "Show Player Info")
	local baseLoad = row.LoadSelections
	row.LoadSelections = function(self, list, pn)
		local val = ThemePrefs.Get("HV_ShowPlayerInfo")
		if val == "true" or val == true then
			list[2] = true  -- On
		else
			list[1] = true  -- Off
		end
	end
	return row
end

function OptionRowShowInGameLeaderboard()
	return HVThemePrefRow("HV_ShowInGameLeaderboard", "In-Game Leaderboard")
end

function OptionRowShowNPSGraph()
	local row = ThemePrefRow("HV_ShowNPSGraph", "Show NPS Graph")
	local baseLoad = row.LoadSelections
	row.LoadSelections = function(self, list, pn)
		local val = ThemePrefs.Get("HV_ShowNPSGraph")
		if val == "true" or val == true then
			list[2] = true  -- On
		else
			list[1] = true  -- Off
		end
	end
	return row
end

function OptionRowComboBreakHighlight()
	local row = ThemePrefRow("HV_ComboBreakHighlight", "Combo Break Highlight")
	local baseLoad = row.LoadSelections
	row.LoadSelections = function(self, list, pn)
		local val = ThemePrefs.Get("HV_ComboBreakHighlight")
		if val == "true" or val == true then
			list[2] = true  -- On
		else
			list[1] = true  -- Off
		end
	end
	return row
end

function OptionRowAssistMode()
	return HVThemePrefRow("HV_AssistMode", "Assist Clap")
end

function OptionRowGoalTrackerText()
	return HVThemePrefRow("HV_GoalTrackerText", "Goal Tracker Text")
end

function OptionRowMinimalisticMode()
	return HVThemePrefRow("HV_MinimalisticMode", "Minimalistic Mode")
end

function OptionRowJudgeCounterMode()
	return HVThemePrefRow("HV_JudgeCounterMode", "Judgment Tally Mode")
end

function OptionRowShowNGIndicator()
	return HVThemePrefRow("HV_ShowNGIndicator", "Show NG Indicator")
end

function OptionRowPrioritizeLowerJudgements()
	return HVThemePrefRow("HV_PrioritizeLowerJudgements", "Prioritize Lower Judgements")
end

function OptionRowDisplayLowerJudgementOffset()
	return HVThemePrefRow("HV_DisplayLowerJudgementOffset", "Display Lower Judgement Offset")
end

function OptionRowOffsetDisplayJudgement()
	return HVThemePrefRow("HV_OffsetDisplayJudgement", "Offset Display Judgement")
end

function OptionRowJudgmentAnimation()
	return HVThemePrefRow("HV_JudgmentAnimation", "Judgment Animation")
end

function OptionRowComboAnimation()
	return HVThemePrefRow("HV_ComboAnimation", "Combo Animation")
end

function OptionRowRecentJudgmentDisplay()
	return HVThemePrefRow("HV_RecentJudgmentDisplay", "Recent Judgement Display")
end

function OptionRowSongBackgroundBrightness()
	return HVThemePrefRow("HV_SongBackgroundBrightness", "Background Brightness")
end

-- Customize Gameplay toggle (used in ScreenPlayerOptions)
function OptionRowCustomizeGameplay()
	return {
		Name = "HV_CustomizeGameplay",
		LayoutType = "ShowAllInRow",
		SelectType = "SelectOne",
		OneChoiceForAllPlayers = true,
		ExportOnChange = true,
		Choices = {"Off", "On"},
		LoadSelections = function(self, list, pn)
			local enabled = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay
			if enabled then
				list[2] = true
			else
				list[1] = true
			end
		end,
		SaveSelections = function(self, list, pn)
			if list[2] then
				playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay = true
			else
				playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay = false
				GAMESTATE:SetAutoplay(false)
			end
		end
	}
end
_G["OptionRowCustomizeGameplay"] = OptionRowCustomizeGameplay

-- Practice Mode toggle (used in ScreenPlayerOptions)
function PracticeMode()
	return {
		Name = "PracticeMode",
		LayoutType = "ShowAllInRow",
		SelectType = "SelectOne",
		OneChoiceForAllPlayers = true,
		ExportOnChange = true,
		Choices = {"Off", "On"},
		LoadSelections = function(self, list, pn)
			if GAMESTATE:IsPracticeMode() then
				list[2] = true
			else
				list[1] = true
			end
		end,
		SaveSelections = function(self, list, pn)
			if list[2] then
				GAMESTATE:SetPracticeMode(true)
			else
				GAMESTATE:SetPracticeMode(false)
			end
		end
	}
end
_G["PracticeMode"] = PracticeMode

-- Listen for pref changes and refresh accent color
local function OnThemePrefChanged(params)
	if params and params.Name == "HV_AccentColor" then
		if HVColor and HVColor.RefreshAccent then
			HVColor.RefreshAccent()
		end
		if HVCustomColors and HVCustomColors.SyncAccentLinkedColors then
			HVCustomColors.SyncAccentLinkedColors(ThemePrefs.Get("HV_AccentColor"))
		end
	end
end

-- Hook into the broadcast system
-- This is called from _Fallback when a ThemePref is saved
if MESSAGEMAN then
	-- We can't directly subscribe here, but themes handle this
	-- via the ThemePrefChangedMessageCommand on actors
end

-- Auto-Fail / Restart Option Rows for ScreenPlayerOptions
function OptionRowAutoFailMode()
	return HVThemePrefRow("HV_AutoFailMode", "Auto-Fail/Restart Action")
end
function OptionRowAutoFailCondition()
	return HVThemePrefRow("HV_AutoFailCondition", "Auto-Fail Condition")
end
function OptionRowAutoFailJudgement()
	return HVThemePrefRow("HV_AutoFailJudgement", "Judgement Criteria")
end
function OptionRowAutoFailThresholdWife()
	return HVThemePrefRow("HV_AutoFailThreshold_Wife", "Wife% Threshold")
end
function OptionRowAutoFailThresholdCount()
	return HVThemePrefRow("HV_AutoFailThreshold_Count", "Judgement Limit")
end

Trace("Holographic Void: 04 ThemePrefsRows.lua loaded.")
