--- Holographic Void: Standalone Theme Options Screen
-- Redesigned modern cyberpunk/holographic interface.
-- Preserves all original functions, behaviors, metrics, and navigation logic.

local function getAccent()
	return (HVColor and HVColor.Accent) or color("#5ABAFF")
end

local function playSound(name)
	pcall(function()
		SOUND:PlayOnce(THEME:GetPathS("Common", name))
	end)
end

local function safeString(section, key, fallback)
	local ok, value = pcall(function() return THEME:GetString(section, key) end)
	if ok and value and value ~= "" then return value end
	return fallback or key
end

-- =========================================================================
-- GEOMETRY & LAYOUT CONSTANTS
-- =========================================================================
local marginX = 20
local gap = 16
local totalW = SCREEN_WIDTH - marginX * 2
local listW = math.floor(totalW * 0.52)
local panelW = totalW - gap - listW
local listX = marginX + listW / 2
local panelX = marginX + listW + gap + panelW / 2

local headerTop = 20
local headerLineY = 56
local tabY = 76
local tabH = 30
local tabW = totalW / 3

local panelTop = 98
local panelBottom = SCREEN_HEIGHT - 34
local panelH = panelBottom - panelTop
local panelCenterY = panelTop + panelH / 2

local listRowsTop = panelTop + 10
local listRowsBottom = panelBottom - 8
local rowPitch = 34
local visibleRows = math.max(1, math.floor((listRowsBottom - listRowsTop) / rowPitch))
local listFirstY = listRowsTop + rowPitch / 2

-- Choice grid constants on right inspector panel
local gridCols = 2
local gridRows = 5
local maxVisibleChoices = gridCols * gridRows
local choiceColW = math.floor((panelW - 36 - 10) / gridCols)
local choiceRowH = 28
local choiceGapX = 10
local choiceGapY = 6
local choicesStartY = panelTop + 184
local choiceX1 = panelX - panelW / 2 + 18 + choiceColW / 2
local choiceX2 = choiceX1 + choiceColW + choiceGapX

-- =========================================================================
-- THEME PREFERENCE DATA & OPTION ROWS
-- =========================================================================
local categoryOptions = {
	{"GlobalTheme", "HV_BGAnimIntensity", "HV_Parallax", "HV_BackgroundEffect", "HV_Particles", "HV_EnableGlow", "HV_QuotesMode"},
	{"HV_SongPreview", "HV_SongSelectBGM", "HV_InstantSearch", "HV_ShowMSD", "HV_OsuManiaStarRating", "HV_ShowProfileStats"},
	{
		"HV_MinimalisticMode", "HV_ShowJudgment", "HV_JudgmentAnimation", "HV_RecentJudgmentDisplay",
		"HV_PrioritizeLowerJudgements", "HV_DisplayLowerJudgementOffset", "HV_OffsetDisplayJudgement", "HV_ShowCombo",
		"HV_ComboAnimation", "HV_ShowCurrentWife", "HV_ShowJudgeCounter", "HV_JudgeCounterMode", "HV_ShowNGIndicator",
		"HV_ShowPlayerInfo", "HV_ProgressBarPosition", "HV_MiniProgressBar", "HV_ShowInGameLeaderboard", "HV_ShowNPS",
		"HV_ShowSSR", "HV_NPSWindowSize", "HV_ShowNPSGraph", "HV_ErrorBarMode", "HV_ErrorBarColoringMode", "HV_ShowMean",
		"HV_ScoreDisplayMode", "HV_ShowMeasureLines", "HV_ComboBreakHighlight", "HV_ShowPacemakerGraph", "HV_UseCustomGrades",
	},
}

local categoryNames = {"HVCategoryGlobal", "HVCategorySongSelect", "HVCategoryGameplay"}
local categoryDescriptions = {
	"Global theme settings as well as title screen behaviours.",
	"Song wheel, ratings, previews, and song selection display.",
	"Gameplay HUD, timing feedback, score displays, and grades.",
}

local function buildOptionRow(name)
	local metric = THEME:GetMetric("ScreenOptionsTheme", "Line" .. name)
	local expression = type(metric) == "string" and metric:match("^lua,(.+)$")
	if not expression then return nil end
	local chunk = loadstring("return " .. expression)
	if not chunk then return nil end
	local ok, row = pcall(chunk)
	if not ok or type(row) ~= "table" then return nil end
	return row
end

local function getSelectedChoice(row)
	local selections = {}
	if row.LoadSelections then
		pcall(row.LoadSelections, row, selections, PLAYER_1)
	end
	for index = 1, #(row.Choices or {}) do
		if selections[index] then return index end
	end
	return 1
end

-- State
local categoryIndex = 1
local pendingTheme = THEME:GetCurThemeName()
local selected = 0 -- 0 indicates Category Tabs are focused
local lastOptionSelected = 1
local scrollerSelection = 1
local scrollerFocused = false
local scrollStart = 1
local choicePageStart = 1
local entries = {}

local function makeOptionEntry(name)
	if name == "GlobalTheme" then
		local themes = THEME:GetSelectableThemeNames()
		local current = pendingTheme
		local choice = 1
		for i, themeName in ipairs(themes) do
			if themeName == current then choice = i; break end
		end
		return {
			name = name,
			title = safeString("OptionTitles", name, "Theme"),
			description = safeString("OptionExplanations", name, "Select the global Etterna theme."),
			choices = themes,
			choice = choice,
			globalTheme = true,
		}
	elseif name == "ServiceOptions" then
		return {
			name = name,
			title = safeString("OptionTitles", "Options Screen", "OPTIONS SCREEN"),
			description = safeString("OptionExplanations", "Options Screen", "Open Etterna's standard Options screen."),
			action = "ScreenOptionsService",
		}
	elseif name == "Exit" then
		return {
			name = name,
			title = safeString("OptionTitles", name, "EXIT"),
			description = safeString("OptionExplanations", name, "Return to the title screen."),
			exit = true,
		}
	end
	local row = buildOptionRow(name)
	if not row then return nil end
	return {
		name = name,
		title = row.Title or safeString("OptionTitles", name),
		description = safeString("OptionExplanations", name, "Adjust " .. (row.Title or name) .. "."),
		row = row,
		choice = getSelectedChoice(row),
		choices = row.Choices or {},
	}
end

local function rebuildEntries()
	entries = {}
	for _, name in ipairs(categoryOptions[categoryIndex]) do
		local entry = makeOptionEntry(name)
		if entry then entries[#entries + 1] = entry end
	end
	entries[#entries + 1] = makeOptionEntry("ServiceOptions")
	entries[#entries + 1] = makeOptionEntry("Exit")
end
rebuildEntries()

local function ensureOptionVisible(index)
	if index < scrollStart then
		scrollStart = index
	elseif index >= scrollStart + visibleRows then
		scrollStart = index - visibleRows + 1
	end
	local maxStart = math.max(1, #entries - visibleRows + 1)
	scrollStart = math.max(1, math.min(scrollStart, maxStart))
end

local function activate(entry, screen)
	playSound("start")
	if entry.exit then
		if pendingTheme ~= THEME:GetCurThemeName() then
			local gameName = GAMESTATE:GetCurrentGame():GetName()
			GAMEMAN:SetGame(gameName, pendingTheme)
		else
			screen:Cancel()
		end
	elseif entry.action then
		SCREENMAN:SetNewScreen(entry.action)
	end
end

local function setChoice(entry, index)
	if not entry or not entry.choices or index < 1 or index > #entry.choices then return end
	if entry.globalTheme then
		pendingTheme = entry.choices[index]
		entry.choice = index
		playSound("value")
		return
	end
	if not entry.row then return end
	local row = entry.row
	entry.choice = index
	local selection = {}
	for i = 1, #entry.choices do selection[i] = (i == entry.choice) end
	if row.SaveSelections then
		local ok = pcall(row.SaveSelections, row, selection, PLAYER_1)
		if ok and ThemePrefs and ThemePrefs.ForceSave then ThemePrefs.ForceSave() end
	end
	playSound("value")
	if MESSAGEMAN then MESSAGEMAN:Broadcast("ThemePrefChanged", {Name = entry.name}) end
end

local function changeChoice(entry, delta)
	if not entry or not entry.choices or #entry.choices < 2 then return end
	setChoice(entry, ((entry.choice - 1 + delta) % #entry.choices) + 1)
end

-- =========================================================================
-- UI ACTOR REFS & REFRESH LOGIC
-- =========================================================================
local headerCounterActor = nil
local tabBackings = {}
local tabBorders = {}
local tabUnderlines = {}
local tabLabels = {}
local tabNumbers = {}

local slotFrames = {}
local slotBackings = {}
local slotBorders = {}
local slotBars = {}
local slotIndices = {}
local slotTitles = {}
local slotValuePillBorders = {}
local slotValuePillBackings = {}
local slotValueTexts = {}

local scrollThumbActor = nil
local scrollUpArrowActor = nil
local scrollDownArrowActor = nil
local listCounterTextActor = nil

local detailCategoryPillActor = nil
local detailTitleActor = nil
local detailDescActor = nil
local controlSectionHeaderActor = nil

local choiceGridFrame = nil
local choicePageTextActor = nil
local choiceFrames = {}
local choiceButtonBorders = {}
local choiceButtonBackings = {}
local choiceRadioDots = {}
local choiceLabels = {}

local function refreshTabs()
	local accent = getAccent()
	for i = 1, #categoryNames do
		local isCurrent = (i == categoryIndex)
		local isFocused = (isCurrent and selected == 0)
		if tabBorders[i] then
			if isCurrent then
				tabBorders[i]:diffuse(accent):diffusealpha(isFocused and 0.65 or 0.4)
			else
				tabBorders[i]:diffuse(color("0.18,0.20,0.24,0.5")):diffusealpha(0.5)
			end
		end
		if tabBackings[i] then
			if isCurrent then
				tabBackings[i]:diffuse(accent):diffusealpha(isFocused and 0.14 or 0.08)
			else
				tabBackings[i]:diffuse(color("0.07,0.07,0.09,0.75")):diffusealpha(0.75)
			end
		end
		if tabUnderlines[i] then
			if isCurrent then
				tabUnderlines[i]:visible(true):diffuse(accent):diffusealpha(isFocused and 0.85 or 0.6)
			else
				tabUnderlines[i]:visible(false)
			end
		end
		if tabLabels[i] then
			tabLabels[i]:settext(safeString("OptionTitles", categoryNames[i]))
			if isCurrent then
				tabLabels[i]:diffuse(isFocused and color("0.95,0.96,0.98,1") or accent):diffusealpha(isFocused and 0.95 or 0.8)
			else
				tabLabels[i]:diffuse(color("0.55,0.57,0.62,1")):diffusealpha(0.65)
			end
		end
	end
end

local function refreshList()
	local accent = getAccent()
	local active = (selected > 0)
	for slot = 1, visibleRows do
		local entryIndex = scrollStart + slot - 1
		local frame = slotFrames[slot]
		if frame then
			if entryIndex <= #entries then
				frame:visible(true)
				local entry = entries[entryIndex]
				local isSelected = (entryIndex == selected and active)
				local isChosen = (entryIndex == scrollerSelection and not active)
				local isAction = (entry.action or entry.exit)

				-- Backing & Indicator Bar
				if isSelected then
					slotBackings[slot]:diffuse(accent):diffusealpha(0.10)
					slotBorders[slot]:visible(true):diffuse(accent):diffusealpha(0.25)
					slotBars[slot]:visible(true):diffuse(accent):diffusealpha(0.75)
				elseif isChosen then
					slotBackings[slot]:diffuse(accent):diffusealpha(0.05)
					slotBorders[slot]:visible(false)
					slotBars[slot]:visible(true):diffuse(accent):diffusealpha(0.3)
				else
					local zebra = (slot % 2 == 0) and 0.02 or 0.04
					slotBackings[slot]:diffuse(color("0.08,0.08,0.1,1")):diffusealpha(zebra)
					slotBorders[slot]:visible(false)
					slotBars[slot]:visible(false)
				end

				-- Title
				slotTitles[slot]:settext(entry.title)
				if isSelected then
					slotTitles[slot]:diffuse(color("0.95,0.96,0.98,1")):diffusealpha(0.95)
				elseif isChosen then
					slotTitles[slot]:diffuse(accent):diffusealpha(0.8)
				elseif isAction then
					slotTitles[slot]:diffuse(color("0.85,0.88,0.92,1")):diffusealpha(0.85)
				else
					slotTitles[slot]:diffuse(color("0.75,0.77,0.82,1")):diffusealpha(0.75)
				end

				-- Value Pill (hidden for Options Screen and Exit)
				if isAction then
					slotValuePillBorders[slot]:visible(false)
					slotValuePillBackings[slot]:visible(false)
					slotValueTexts[slot]:visible(false)
				elseif entry.choices and #entry.choices > 0 then
					slotValuePillBorders[slot]:visible(true)
					slotValuePillBackings[slot]:visible(true)
					local choiceVal = entry.choices[entry.choice] or ""
					if isSelected then
						slotValuePillBorders[slot]:diffuse(accent):diffusealpha(0.55)
						slotValuePillBackings[slot]:diffuse(accent):diffusealpha(0.12)
						slotValueTexts[slot]:visible(true):settext(tostring(choiceVal))
							:diffuse(color("0.95,0.96,0.98,1")):diffusealpha(0.95)
					else
						slotValuePillBorders[slot]:diffuse(color("0.18,0.20,0.24,0.5")):diffusealpha(0.5)
						slotValuePillBackings[slot]:diffuse(color("0.09,0.09,0.11,0.85")):diffusealpha(0.85)
						slotValueTexts[slot]:visible(true):settext(tostring(choiceVal))
							:diffuse(color("0.7,0.73,0.8,1")):diffusealpha(0.7)
					end
				else
					slotValuePillBorders[slot]:visible(false)
					slotValuePillBackings[slot]:visible(false)
					slotValueTexts[slot]:visible(false)
				end
			else
				frame:visible(false)
			end
		end
	end
end

local function refreshScrollbar()
	local accent = getAccent()
	local total = #entries
	local trackH = (listRowsBottom - 14) - (listRowsTop + 14)
	local thumbH = math.max(20, math.floor((visibleRows / total) * trackH))
	local maxStart = math.max(1, total - visibleRows + 1)
	local scrollPct = (scrollStart - 1) / math.max(1, total - visibleRows)
	local thumbY = (listRowsTop + 14 + thumbH / 2) + scrollPct * (trackH - thumbH)

	if scrollThumbActor then
		scrollThumbActor:y(thumbY):zoomto(3, thumbH):diffuse(accent):diffusealpha(0.9)
	end
	if scrollUpArrowActor then
		scrollUpArrowActor:visible(scrollStart > 1):diffuse(accent)
	end
	if scrollDownArrowActor then
		scrollDownArrowActor:visible(scrollStart + visibleRows <= total):diffuse(accent)
	end
end

local function refreshInspector()
	local accent = getAccent()
	local entry = (selected > 0) and entries[selected] or nil

	if selected == 0 then
		-- Category Overview mode
		if detailCategoryPillActor then
			detailCategoryPillActor:settext("// CATEGORY OVERVIEW"):diffuse(accent):diffusealpha(0.8)
		end
		if detailTitleActor then
			detailTitleActor:settext(safeString("OptionTitles", categoryNames[categoryIndex])):diffuse(color("1,1,1,1"))
		end
		if detailDescActor then
			detailDescActor:settext(categoryDescriptions[categoryIndex]):diffuse(color("0.85,0.88,0.92,1"))
		end
		if controlSectionHeaderActor then
			controlSectionHeaderActor:settext(""):diffuse(accent)
		end
		if choiceGridFrame then choiceGridFrame:visible(false) end
	elseif entry and (entry.action or entry.exit) then
		-- Action / Exit mode
		if detailCategoryPillActor then
			detailCategoryPillActor:settext(entry.action and "// SYSTEM NAVIGATION" or "// NAVIGATION"):diffuse(accent):diffusealpha(0.8)
		end
		if detailTitleActor then
			detailTitleActor:settext(entry.title):diffuse(color("1,1,1,1"))
		end
		if detailDescActor then
			detailDescActor:settext(entry.description):diffuse(color("0.85,0.88,0.92,1"))
		end
		if controlSectionHeaderActor then
			controlSectionHeaderActor:settext(""):diffuse(accent)
		end
		if choiceGridFrame then choiceGridFrame:visible(false) end
	elseif entry then
		-- Normal Preference with Choices
		if detailCategoryPillActor then
			detailCategoryPillActor:settext("// " .. safeString("OptionTitles", categoryNames[categoryIndex])):diffuse(accent):diffusealpha(0.8)
		end
		if detailTitleActor then
			detailTitleActor:settext(entry.title):diffuse(color("1,1,1,1"))
		end
		if detailDescActor then
			detailDescActor:settext(entry.description):diffuse(color("0.85,0.88,0.92,1"))
		end
		if controlSectionHeaderActor then
			controlSectionHeaderActor:settext(""):diffuse(accent)
		end
		if choiceGridFrame then
			choiceGridFrame:visible(true)
			local choices = entry.choices or {}
			-- Ensure active choice is on the visible choice page
			if entry.choice < choicePageStart or entry.choice >= choicePageStart + maxVisibleChoices then
				choicePageStart = math.floor((entry.choice - 1) / maxVisibleChoices) * maxVisibleChoices + 1
			end
			if choicePageTextActor then
				if #choices > maxVisibleChoices then
					choicePageTextActor:visible(true)
						:settext(string.format("PAGE %d / %d", math.ceil(choicePageStart / maxVisibleChoices), math.ceil(#choices / maxVisibleChoices)))
						:diffuse(accent):diffusealpha(0.7)
				else
					choicePageTextActor:visible(false)
				end
			end
			for i = 1, maxVisibleChoices do
				local choiceIdx = choicePageStart + i - 1
				local btnFrame = choiceFrames[i]
				if btnFrame then
					if choiceIdx <= #choices then
						btnFrame:visible(true)
						local val = choices[choiceIdx]
						local isChosen = (choiceIdx == entry.choice)
						if isChosen then
							choiceButtonBorders[i]:diffuse(accent):diffusealpha(0.55)
							choiceButtonBackings[i]:diffuse(accent):diffusealpha(0.12)
							choiceRadioDots[i]:settext("●"):diffuse(accent):diffusealpha(0.85)
							choiceLabels[i]:settext(tostring(val)):diffuse(color("0.95,0.96,0.98,1")):diffusealpha(0.95)
						else
							choiceButtonBorders[i]:diffuse(color("0.18,0.20,0.24,0.5")):diffusealpha(0.5)
							choiceButtonBackings[i]:diffuse(color("0.08,0.08,0.1,0.85")):diffusealpha(0.85)
							choiceRadioDots[i]:settext("○"):diffuse(color("0.45,0.47,0.52,1")):diffusealpha(0.5)
							choiceLabels[i]:settext(tostring(val)):diffuse(color("0.65,0.67,0.72,1")):diffusealpha(0.7)
						end
					else
						btnFrame:visible(false)
					end
				end
			end
		end
	end
end

local function refreshUI()
	scrollerSelection = (selected > 0) and selected or lastOptionSelected
	scrollerFocused = (selected > 0)
	refreshTabs()
	refreshList()
	refreshScrollbar()
	refreshInspector()
	if headerCounterActor then
		headerCounterActor:settext(string.format("CATEGORY %d / %d", categoryIndex, #categoryNames))
		headerCounterActor:diffuse(getAccent())
	end
end

local function switchCategory(delta)
	categoryIndex = ((categoryIndex - 1 + delta) % #categoryNames) + 1
	rebuildEntries()
	selected = 0
	lastOptionSelected = 1
	scrollStart = 1
	choicePageStart = 1
	playSound("value")
end

-- =========================================================================
-- VISUAL DECORATIONS (CORNER BRACKETS & BORDERS)
-- =========================================================================
local function makeCornerBrackets(w, h, size, thickness)
	size = size or 8
	thickness = thickness or 1.5
	local halfW = w / 2
	local halfH = h / 2
	local function colorTick(self) self:diffuse(getAccent()):diffusealpha(0.85) end
	return Def.ActorFrame {
		-- Top-left
		Def.Quad { InitCommand = function(self) self:xy(-halfW + size / 2, -halfH + thickness / 2):zoomto(size, thickness); colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(-halfW + thickness / 2, -halfH + size / 2):zoomto(thickness, size); colorTick(self) end },
		-- Top-right
		Def.Quad { InitCommand = function(self) self:xy(halfW - size / 2, -halfH + thickness / 2):zoomto(size, thickness); colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - thickness / 2, -halfH + size / 2):zoomto(thickness, size); colorTick(self) end },
		-- Bottom-left
		Def.Quad { InitCommand = function(self) self:xy(-halfW + size / 2, halfH - thickness / 2):zoomto(size, thickness); colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(-halfW + thickness / 2, halfH - size / 2):zoomto(thickness, size); colorTick(self) end },
		-- Bottom-right
		Def.Quad { InitCommand = function(self) self:xy(halfW - size / 2, halfH - thickness / 2):zoomto(size, thickness); colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - thickness / 2, halfH - size / 2):zoomto(thickness, size); colorTick(self) end },
	}
end

local function makePanelBorder(w, h, borderColor)
	return Def.ActorFrame {
		Def.Quad { InitCommand = function(self) self:y(-h / 2):zoomto(w, 1):diffuse(borderColor) end },
		Def.Quad { InitCommand = function(self) self:y(h / 2):zoomto(w, 1):diffuse(borderColor) end },
		Def.Quad { InitCommand = function(self) self:x(-w / 2):zoomto(1, h):diffuse(borderColor) end },
		Def.Quad { InitCommand = function(self) self:x(w / 2):zoomto(1, h):diffuse(borderColor) end },
	}
end

-- =========================================================================
-- ROOT ACTORFRAME
-- =========================================================================
local root = Def.ActorFrame {
	Name = "CustomThemeOptions",
	InitCommand = function(self)
		self:playcommand("Refresh")
	end,
	OnCommand = function(self)
		refreshUI()
	end,
	ThemePrefChangedMessageCommand = function(self, params)
		if params and params.Name == "HV_AccentColor" and HVColor and HVColor.RefreshAccent then
			HVColor.RefreshAccent()
		end
		refreshUI()
	end,
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen or not screen.AddInputCallback then return end
		screen:AddInputCallback(function(event)
			if not event then return false end
			if event.type == "InputEventType_Release" then return false end
			local isFirstPress = (event.type == "InputEventType_FirstPress")
			local button = event.button or event.GameButton or ""
			local device = event.DeviceInput and event.DeviceInput.button or ""
			local current = (selected > 0) and entries[selected] or nil

			if button == "MenuUp" or device == "DeviceButton_up" then
				if selected > 1 then
					selected = selected - 1
					lastOptionSelected = selected
				elseif selected == 1 then
					selected = 0
				end
				if selected > 0 then ensureOptionVisible(selected) end
				playSound("value")
				refreshUI()
				return true
			elseif button == "MenuDown" or device == "DeviceButton_down" then
				if selected == 0 then
					selected = lastOptionSelected
				elseif selected < #entries then
					selected = selected + 1
					lastOptionSelected = selected
				end
				if selected > 0 then ensureOptionVisible(selected) end
				playSound("value")
				refreshUI()
				return true
			elseif button == "MenuLeft" or device == "DeviceButton_left" then
				if selected == 0 then
					switchCategory(-1)
				else
					changeChoice(current, -1)
				end
				refreshUI()
				return true
			elseif button == "MenuRight" or device == "DeviceButton_right" then
				if selected == 0 then
					switchCategory(1)
				else
					changeChoice(current, 1)
				end
				refreshUI()
				return true
			elseif isFirstPress and (button == "Start" or device == "DeviceButton_enter") then
				if selected == 0 then
					selected = lastOptionSelected
					playSound("value")
					refreshUI()
				elseif current and (current.action or current.exit) then
					activate(current, screen)
				elseif current then
					selected = #entries
					lastOptionSelected = selected
					ensureOptionVisible(selected)
					playSound("value")
					refreshUI()
				end
				return true
			elseif isFirstPress and (button == "Back" or device == "DeviceButton_escape") then
				playSound("cancel")
				screen:Cancel()
				return true
			elseif isFirstPress and device == "DeviceButton_mousewheel up" then
				if selected > 1 then
					selected = selected - 1
					lastOptionSelected = selected
				elseif selected == 1 then
					selected = 0
				end
				if selected > 0 then ensureOptionVisible(selected) end
				playSound("value")
				refreshUI()
				return true
			elseif isFirstPress and device == "DeviceButton_mousewheel down" then
				if selected == 0 then
					selected = lastOptionSelected
				elseif selected < #entries then
					selected = selected + 1
					lastOptionSelected = selected
				end
				if selected > 0 then ensureOptionVisible(selected) end
				playSound("value")
				refreshUI()
				return true
			elseif isFirstPress and device == "DeviceButton_left mouse button" then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()

				-- Category Tabs Click
				if my >= tabY - tabH / 2 and my <= tabY + tabH / 2 then
					for i = 1, #categoryNames do
						local tabLeft = marginX + (i - 1) * tabW
						local tabRight = tabLeft + tabW
						if mx >= tabLeft and mx <= tabRight then
							categoryIndex = i
							rebuildEntries()
							selected = 0
							lastOptionSelected = 1
							scrollStart = 1
							choicePageStart = 1
							playSound("value")
							refreshUI()
							return true
						end
					end
				end

				-- Left Panel Rows Click
				if mx >= listX - listW / 2 and mx <= listX + listW / 2
				   and my >= listRowsTop and my <= listRowsBottom then
					local slot = math.floor((my - listRowsTop) / rowPitch) + 1
					if slot >= 1 and slot <= visibleRows then
						local index = scrollStart + slot - 1
						if index >= 1 and index <= #entries then
							selected = index
							lastOptionSelected = index
							ensureOptionVisible(index)
							local entry = entries[selected]
							if entry.action or entry.exit then
								activate(entry, screen)
							elseif mx > (listX + listW * 0.15) then
								changeChoice(entry, 1)
							else
								playSound("value")
							end
							refreshUI()
							return true
						end
					end
				end

				-- Scrollbar / Scroll Buttons Click
				if mx >= listX + listW / 2 - 20 and mx <= listX + listW / 2 + 5
				   and my >= listRowsTop and my <= listRowsBottom then
					if my < listRowsTop + 24 then
						-- Up arrow
						if scrollStart > 1 then
							scrollStart = scrollStart - 1
							playSound("value")
							refreshUI()
						end
						return true
					elseif my > listRowsBottom - 24 then
						-- Down arrow
						if scrollStart + visibleRows <= #entries then
							scrollStart = scrollStart + 1
							playSound("value")
							refreshUI()
						end
						return true
					else
						-- Track jump
						local trackH = (listRowsBottom - 24) - (listRowsTop + 24)
						local clickPct = (my - (listRowsTop + 24)) / math.max(1, trackH)
						local maxStart = math.max(1, #entries - visibleRows + 1)
						scrollStart = math.max(1, math.min(maxStart, math.floor(clickPct * maxStart + 0.5)))
						playSound("value")
						refreshUI()
						return true
					end
				end

				-- Right Panel Choices Click
				if current and current.choices and #current.choices > 0 then
					for i = 1, maxVisibleChoices do
						local choiceIndex = choicePageStart + i - 1
						if choiceIndex <= #current.choices then
							local col = ((i - 1) % gridCols) + 1
							local row = math.floor((i - 1) / gridCols) + 1
							local cx = (col == 1) and choiceX1 or choiceX2
							local cy = choicesStartY + (row - 1) * (choiceRowH + choiceGapY)
							if mx >= cx - choiceColW / 2 and mx <= cx + choiceColW / 2
							   and my >= cy - choiceRowH / 2 and my <= cy + choiceRowH / 2 then
								setChoice(current, choiceIndex)
								refreshUI()
								return true
							end
						end
					end
					-- Choice pagination buttons
					if #current.choices > maxVisibleChoices then
						local pagY = choicesStartY + gridRows * (choiceRowH + choiceGapY) + 6
						if my >= pagY - 12 and my <= pagY + 12 then
							if mx >= panelX - 70 and mx <= panelX - 10 then
								if choicePageStart > 1 then
									choicePageStart = math.max(1, choicePageStart - maxVisibleChoices)
									playSound("value")
									refreshUI()
								end
								return true
							elseif mx >= panelX + 10 and mx <= panelX + 70 then
								if choicePageStart + maxVisibleChoices <= #current.choices then
									choicePageStart = choicePageStart + maxVisibleChoices
									playSound("value")
									refreshUI()
								end
								return true
							end
						end
					end
				end

				-- Right Panel Action / Exit Button Click
				if current and (current.action or current.exit) then
					local abW = panelW - 40
					local abH = 50
					local abY = panelTop + 210
					if mx >= panelX - abW / 2 and mx <= panelX + abW / 2
					   and my >= abY - abH / 2 and my <= abY + abH / 2 then
						activate(current, screen)
						return true
					end
				end

				return false
			end
			return false
		end)
	end,
}

-- =========================================================================
-- 1. TOP HEADER & BREADCRUMB BAR
-- =========================================================================
root[#root + 1] = Def.ActorFrame {
	Name = "Header",
	-- Brand / Kicker
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX, headerTop):halign(0):zoom(0.3)
				:diffuse(getAccent()):diffusealpha(0.85)
			self:settext("HOLOGRAPHIC VOID  //  CONFIGURATION")
		end,
	},
	-- Screen Title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX, headerTop + 16):halign(0):zoom(0.68):diffuse(color("1,1,1,1"))
			self:settext(THEME:GetString("ScreenHVOptions", "Title"))
		end,
	},
	-- Screen Subtitle
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX + 230, headerTop + 19):halign(0):zoom(0.34)
				:diffuse(color("0.65,0.68,0.74,0.85"))
			self:settext(THEME:GetString("ScreenHVOptions", "Subtitle"))
		end,
	},
	-- Category Badge (Right edge)
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH - marginX - 55, headerTop + 14)
		end,
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(110, 22):diffuse(color("0.08,0.08,0.1,0.9"))
			end,
		},
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(110, 22):diffuse(getAccent()):diffusealpha(0.2)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				headerCounterActor = self
				self:zoom(0.32):diffuse(getAccent())
				self:settext(string.format("CATEGORY %d / %d", categoryIndex, #categoryNames))
			end,
		},
	},
	-- Glow line behind header divider
	Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, headerLineY):zoomto(totalW, 3)
				:diffuse(getAccent()):diffusealpha(0.18)
		end,
	},
	-- Header Divider Line
	Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, headerLineY):zoomto(totalW, 1)
				:diffuse(getAccent()):diffusealpha(0.65)
		end,
	},
}

-- =========================================================================
-- 2. CATEGORY TABS (SEGMENTED CONTROL)
-- =========================================================================
root[#root + 1] = Def.ActorFrame {
	Name = "CategoryTabs",
	unpack((function()
		local children = {}
		for i = 1, #categoryNames do
			local cx = marginX + (i - 0.5) * tabW
			children[#children + 1] = Def.ActorFrame {
				Name = "Tab" .. i,
				InitCommand = function(self) self:xy(cx, tabY) end,
				-- Tab Border Outline
				Def.Quad {
					InitCommand = function(self)
						tabBorders[i] = self
						self:zoomto(tabW - 6, tabH):diffuse(color("0.18,0.20,0.24,0.6"))
					end,
				},
				-- Tab Backing Fill
				Def.Quad {
					InitCommand = function(self)
						tabBackings[i] = self
						self:zoomto(tabW - 8, tabH - 2):diffuse(color("0.07,0.07,0.09,0.75"))
					end,
				},
				-- Active Bottom Underline
				Def.Quad {
					InitCommand = function(self)
						tabUnderlines[i] = self
						self:y(tabH / 2 - 1.5):zoomto(tabW - 6, 3):diffuse(getAccent())
					end,
				},
				-- Tab Label
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						tabLabels[i] = self
						self:x(0):zoom(0.42):halign(0.5)
						self:settext(safeString("OptionTitles", categoryNames[i]))
					end,
				},
			}
		end
		return children
	end)())
}

-- =========================================================================
-- 3. LEFT PANEL: PREFERENCES SCROLLER
-- =========================================================================
root[#root + 1] = Def.ActorFrame {
	Name = "LeftPanel",
	InitCommand = function(self) self:xy(listX, panelCenterY) end,
	-- Main Panel Glass Backing
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(listW, panelH):diffuse(color("0.04,0.04,0.05,0.92"))
		end,
	},
	-- Border Outline
	Def.ActorFrame {
		makePanelBorder(listW, panelH, color("0.16,0.18,0.22,0.8")),
	},
	-- Corner Accent Brackets
	Def.ActorFrame {
		makeCornerBrackets(listW, panelH, 8, 1.5),
	},
}

-- Left Panel Visible Row Slots
root[#root + 1] = Def.ActorFrame {
	Name = "List",
	unpack((function()
		local children = {}
		for slot = 1, visibleRows do
			local slotY = listFirstY + (slot - 1) * rowPitch
			children[#children + 1] = Def.ActorFrame {
				Name = "Slot" .. slot,
				InitCommand = function(self)
					slotFrames[slot] = self
					self:xy(listX, slotY)
				end,
				-- Row Backing
				Def.Quad {
					InitCommand = function(self)
						slotBackings[slot] = self
						self:zoomto(listW - 14, rowPitch - 3)
					end,
				},
				-- Row Top Border Line
				Def.Quad {
					InitCommand = function(self)
						slotBorders[slot] = self
						self:y(-(rowPitch - 3) / 2):zoomto(listW - 14, 1):visible(false)
					end,
				},
				-- Left Glowing Indicator Bar
				Def.Quad {
					InitCommand = function(self)
						slotBars[slot] = self
						self:x(-(listW - 14) / 2 + 1.5):zoomto(3, rowPitch - 5):visible(false)
					end,
				},
				-- Option Title
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						slotTitles[slot] = self
						self:x(-(listW - 14) / 2 + 16):zoom(0.44):halign(0)
							:maxwidth((listW * 0.52) / 0.44)
					end,
				},
				-- Value Pill Border
				Def.Quad {
					InitCommand = function(self)
						slotValuePillBorders[slot] = self
						local pillW = math.floor(listW * 0.38)
						self:x((listW - 14) / 2 - 9):halign(1):zoomto(pillW + 2, 24)
					end,
				},
				-- Value Pill Backing
				Def.Quad {
					InitCommand = function(self)
						slotValuePillBackings[slot] = self
						local pillW = math.floor(listW * 0.38)
						self:x((listW - 14) / 2 - 10):halign(1):zoomto(pillW, 22)
					end,
				},
				-- Value Text
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						slotValueTexts[slot] = self
						local pillW = math.floor(listW * 0.38)
						self:x((listW - 14) / 2 - 10 - pillW / 2):halign(0.5):zoom(0.38)
							:maxwidth((pillW - 10) / 0.38)
					end,
				},
			}
		end
		return children
	end)())
}

-- Left Panel Scrollbar
root[#root + 1] = Def.ActorFrame {
	Name = "Scrollbar",
	InitCommand = function(self)
		self:x(listX + listW / 2 - 8)
	end,
	-- Up Arrow
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			scrollUpArrowActor = self
			self:y(listRowsTop + 4):zoom(0.28):settext("▲")
		end,
	},
	-- Down Arrow
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			scrollDownArrowActor = self
			self:y(listRowsBottom - 4):zoom(0.28):settext("▼")
		end,
	},
	-- Track
	Def.Quad {
		InitCommand = function(self)
			self:y(panelCenterY + 14):zoomto(3, (listRowsBottom - 14) - (listRowsTop + 14))
				:diffuse(color("0.14,0.15,0.18,0.7"))
		end,
	},
	-- Thumb
	Def.Quad {
		InitCommand = function(self)
			scrollThumbActor = self
			self:zoomto(3, 30):diffuse(getAccent())
		end,
	},
}

-- =========================================================================
-- 4. RIGHT PANEL: INSPECTOR & CONTROLS
-- =========================================================================
root[#root + 1] = Def.ActorFrame {
	Name = "RightPanel",
	InitCommand = function(self) self:xy(panelX, panelCenterY) end,
	-- Main Panel Glass Backing
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(panelW, panelH):diffuse(color("0.04,0.04,0.05,0.92"))
		end,
	},
	-- Border Outline
	Def.ActorFrame {
		makePanelBorder(panelW, panelH, color("0.16,0.18,0.22,0.8")),
	},
	-- Corner Accent Brackets
	Def.ActorFrame {
		makeCornerBrackets(panelW, panelH, 8, 1.5),
	},
}

-- Right Panel Header Banner
root[#root + 1] = Def.ActorFrame {
	Name = "RightPanelHeader",
	InitCommand = function(self) self:xy(panelX, panelTop + 16) end,
	-- Backing
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(panelW - 4, 28):diffuse(color("0.07,0.07,0.09,0.95"))
		end,
	},
	-- Divider Line
	Def.Quad {
		InitCommand = function(self)
			self:y(14):zoomto(panelW - 4, 1):diffuse(color("0.18,0.20,0.24,0.8"))
		end,
	},
	-- Category Tag / Breadcrumb
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			detailCategoryPillActor = self
			self:x(-panelW / 2 + 16):halign(0):zoom(0.3)
				:diffuse(getAccent()):diffusealpha(0.85)
			self:settext("// GLOBAL PREFERENCE")
		end,
	},
}

-- Right Panel Option Title & Accent Divider
root[#root + 1] = Def.ActorFrame {
	Name = "RightPanelTitle",
	-- Detail Title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			detailTitleActor = self
			self:xy(panelX - panelW / 2 + 16, panelTop + 42):halign(0):zoom(0.56)
				:maxwidth((panelW - 32) / 0.56):diffuse(color("1,1,1,1"))
			self:settext("Option Title")
		end,
	},
	-- Glowing Accent Line
	Def.Quad {
		InitCommand = function(self)
			self:xy(panelX, panelTop + 60):zoomto(panelW - 32, 2)
				:diffuse(getAccent()):diffusealpha(0.8)
		end,
	},
}

-- Right Panel Description Card
root[#root + 1] = Def.ActorFrame {
	Name = "RightPanelDescCard",
	InitCommand = function(self) self:xy(panelX, panelTop + 104) end,
	-- Card Backing
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(panelW - 32, 72):diffuse(color("0.06,0.06,0.08,0.85"))
		end,
	},
	-- Border Outline
	Def.ActorFrame {
		makePanelBorder(panelW - 32, 72, color("0.16,0.18,0.22,0.6")),
	},
	-- Left Accent Accent-line
	Def.Quad {
		InitCommand = function(self)
			self:x(-(panelW - 32) / 2 + 1.5):zoomto(3, 72)
				:diffuse(getAccent()):diffusealpha(0.85)
		end,
	},
	-- Kicker
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-(panelW - 32) / 2 + 14, -26):halign(0):zoom(0.28)
				:diffuse(getAccent()):diffusealpha(0.9)
			self:settext("DESCRIPTION & FUNCTION")
		end,
	},
	-- Detail Text
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			detailDescActor = self
			self:xy(-(panelW - 32) / 2 + 14, -12):halign(0):valign(0):zoom(0.38)
				:wrapwidthpixels((panelW - 56) / 0.38):maxwidth((panelW - 56) / 0.38)
				:diffuse(color("0.85,0.88,0.92,1"))
			self:settext("Option description goes here.")
		end,
	},
}

-- Section Header for Controls Area
root[#root + 1] = Def.ActorFrame {
	Name = "ControlsHeader",
	InitCommand = function(self) self:xy(panelX, panelTop + 154) end,
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			controlSectionHeaderActor = self
			self:x(-panelW / 2 + 16):halign(0):zoom(0.32):diffuse(getAccent())
			self:settext("AVAILABLE CHOICES")
		end,
	},
	Def.Quad {
		InitCommand = function(self)
			self:y(10):zoomto(panelW - 32, 1):diffuse(color("0.18,0.20,0.24,0.75"))
		end,
	},
}

-- Mode C: Choice Grid (visible when normal option selected)
root[#root + 1] = Def.ActorFrame {
	Name = "ChoiceGrid",
	InitCommand = function(self)
		choiceGridFrame = self
		self:visible(true)
	end,
	-- Pagination text (for options with > 10 choices)
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			choicePageTextActor = self
			self:xy(panelX, choicesStartY + gridRows * (choiceRowH + choiceGapY) + 6)
				:zoom(0.32):diffuse(getAccent()):visible(false)
			self:settext("PAGE 1 / 1")
		end,
	},
	unpack((function()
		local children = {}
		for i = 1, maxVisibleChoices do
			local col = ((i - 1) % gridCols) + 1
			local row = math.floor((i - 1) / gridCols) + 1
			local cx = (col == 1) and choiceX1 or choiceX2
			local cy = choicesStartY + (row - 1) * (choiceRowH + choiceGapY)

			children[#children + 1] = Def.ActorFrame {
				Name = "Choice" .. i,
				InitCommand = function(self)
					choiceFrames[i] = self
					self:xy(cx, cy)
				end,
				-- Button Border
				Def.Quad {
					InitCommand = function(self)
						choiceButtonBorders[i] = self
						self:zoomto(choiceColW, choiceRowH)
							:diffuse(color("0.18,0.20,0.24,0.6"))
					end,
				},
				-- Button Backing Fill
				Def.Quad {
					InitCommand = function(self)
						choiceButtonBackings[i] = self
						self:zoomto(choiceColW - 2, choiceRowH - 2)
							:diffuse(color("0.08,0.08,0.1,0.85"))
					end,
				},
				-- Radio Dot Indicator
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						choiceRadioDots[i] = self
						self:x(-choiceColW / 2 + 14):zoom(0.38):halign(0.5)
						self:settext("○"):diffuse(color("0.45,0.47,0.52,1"))
					end,
				},
				-- Choice Label
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						choiceLabels[i] = self
						self:x(-choiceColW / 2 + 28):zoom(0.38):halign(0)
							:maxwidth((choiceColW - 32) / 0.38)
						self:settext("Value")
					end,
				},
			}
		end
		return children
	end)())
}

-- =========================================================================
-- 5. NAVIGATION FOOTER BAR
-- =========================================================================
root[#root + 1] = Def.ActorFrame {
	Name = "FooterBar",
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 18) end,
	-- Backing
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(SCREEN_WIDTH, 26):diffuse(color("0.03,0.03,0.04,0.95"))
		end,
	},
	-- Top Divider Line
	Def.Quad {
		InitCommand = function(self)
			self:y(-13):zoomto(SCREEN_WIDTH, 1):diffuse(color("0.16,0.18,0.22,0.8"))
		end,
	},
	-- Keyboard Shortcuts (Left aligned)
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(-SCREEN_WIDTH / 2 + marginX):halign(0):zoom(0.3)
				:diffuse(color("0.7,0.72,0.78,0.85"))
			self:settext("[↑ / ↓] SELECT OPTION   ·   [← / →] CHANGE / TAB   ·   [ENTER] SELECT / JUMP   ·   [ESC] BACK")
		end,
	},
	-- Mouse Interaction Hint (Right aligned)
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(SCREEN_WIDTH / 2 - marginX):halign(1):zoom(0.28)
				:diffuse(color("0.5,0.52,0.58,0.8"))
			self:settext("CLICK OPTION OR VALUE TO CHANGE   ·   MOUSE WHEEL TO BROWSE")
		end,
	},
}

-- =========================================================================
-- 6. MOUSE CURSOR
-- =========================================================================
root[#root + 1] = LoadActor("../_cursor")

return root
