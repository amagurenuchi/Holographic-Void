--- Holographic Void: custom Theme Options scroller and option controls.

local accent = HVColor and HVColor.Accent or color("#5ABAFF")
local listW = SCREEN_WIDTH * 0.46
local panelW = SCREEN_WIDTH * 0.38
local listX = SCREEN_CENTER_X - SCREEN_WIDTH * 0.255
local panelX = SCREEN_CENTER_X + SCREEN_WIDTH * 0.245
local listTop, listBottom = 104, SCREEN_HEIGHT - 62
local rowPitch = 38
local visibleRows = math.max(1, math.floor((listBottom - listTop) / rowPitch))
local listFirstY = listTop + rowPitch / 2
local choiceRowY = SCREEN_CENTER_Y

local function safeString(section, key, fallback)
	local ok, value = pcall(function() return THEME:GetString(section, key) end)
	if ok and value and value ~= "" then return value end
	return fallback or key
end

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
local maxEntryCount = math.max(#categoryOptions[1], #categoryOptions[2], #categoryOptions[3]) + 2 -- Options Screen and Exit

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

local categoryNames = {"HVCategoryGlobal", "HVCategorySongSelect", "HVCategoryGameplay"}
local categoryDescriptions = {
	"Global theme settings as well as title screen behaviours.",
	"Song wheel, ratings, previews, and song selection display.",
	"Gameplay HUD, timing feedback, score displays, and grades.",
}
local categoryIndex = 1
local pendingTheme = THEME:GetCurThemeName()
local selected = 0 -- 0 is the category selector at the top of the screen.
local lastOptionSelected = 1
local scrollerSelection = 1
local scrollerFocused = false
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
local scrollStart = 1
local displayChoices, displayChoice = {}, 0
local choiceWindowStart = 1
local maxVisibleChoices = math.max(1, math.floor(panelW / 92))

local function ensureChoiceVisible(index)
	if index < choiceWindowStart then
		choiceWindowStart = index
	elseif index >= choiceWindowStart + maxVisibleChoices then
		choiceWindowStart = index - maxVisibleChoices + 1
	end
	local maxStart = math.max(1, #displayChoices - maxVisibleChoices + 1)
	choiceWindowStart = math.max(1, math.min(choiceWindowStart, maxStart))
end

local function ensureOptionVisible(index)
	if index < scrollStart then
		scrollStart = index
	elseif index >= scrollStart + visibleRows then
		scrollStart = index - visibleRows + 1
	end
	local maxStart = math.max(1, #entries - visibleRows + 1)
	scrollStart = math.max(1, math.min(scrollStart, maxStart))
end

local function switchCategory(delta)
	categoryIndex = ((categoryIndex - 1 + delta) % #categoryNames) + 1
	rebuildEntries()
	selected = 0
	lastOptionSelected = 1
	scrollStart = 1
end

local function activate(entry, screen)
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
		return
	end
	if not entry.row then return end
	local row = entry.row
	entry.choice = index
	local selection = {}
	for i = 1, #entry.choices do selection[i] = i == entry.choice end
	if row.SaveSelections then
		local ok = pcall(row.SaveSelections, row, selection, PLAYER_1)
		if ok and ThemePrefs and ThemePrefs.ForceSave then ThemePrefs.ForceSave() end
	end
	if MESSAGEMAN then MESSAGEMAN:Broadcast("ThemePrefChanged", {Name = entry.name}) end
end

local function changeChoice(entry, delta)
	if not entry or #entry.choices < 2 then return end
	setChoice(entry, ((entry.choice - 1 + delta) % #entry.choices) + 1)
end

local root = Def.ActorFrame {
	Name = "CustomThemeOptions",
	OnCommand = function(self) self:playcommand("Refresh") end,
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen or not screen.AddInputCallback then return end
		screen:AddInputCallback(function(event)
			if not event or event.type ~= "InputEventType_FirstPress" then return false end
			local button = event.button or event.GameButton or ""
			local device = event.DeviceInput and event.DeviceInput.button or ""
			local current = selected > 0 and entries[selected] or nil

			if button == "MenuUp" or device == "DeviceButton_up" then
				if selected > 1 then selected = selected - 1; lastOptionSelected = selected
				elseif selected == 1 then selected = 0 end
				if selected > 0 then ensureOptionVisible(selected) end
				self:playcommand("Refresh")
				return true
			elseif button == "MenuDown" or device == "DeviceButton_down" then
				if selected == 0 then selected = lastOptionSelected
				elseif selected < #entries then selected = selected + 1; lastOptionSelected = selected end
				if selected > 0 then ensureOptionVisible(selected) end
				self:playcommand("Refresh")
				return true
			elseif button == "MenuLeft" or device == "DeviceButton_left" then
				if selected == 0 then switchCategory(-1) else changeChoice(current, -1) end
				self:playcommand("Refresh")
				return true
			elseif button == "MenuRight" or device == "DeviceButton_right" then
				if selected == 0 then switchCategory(1) else changeChoice(current, 1) end
				self:playcommand("Refresh")
				return true
			elseif button == "Start" or device == "DeviceButton_enter" then
				if selected == 0 then selected = lastOptionSelected; self:playcommand("Refresh")
				elseif current then activate(current, screen) end
				return true
			elseif button == "Back" or device == "DeviceButton_escape" then
				screen:Cancel()
				return true
			elseif device == "DeviceButton_mousewheel up" then
				if selected > 1 then selected = selected - 1; lastOptionSelected = selected
				elseif selected == 1 then selected = 0 end
				if selected > 0 then ensureOptionVisible(selected) end
				self:playcommand("Refresh")
				return true
			elseif device == "DeviceButton_mousewheel down" then
				if selected == 0 then selected = lastOptionSelected
				elseif selected < #entries then selected = selected + 1; lastOptionSelected = selected end
				if selected > 0 then ensureOptionVisible(selected) end
				self:playcommand("Refresh")
				return true
			elseif device == "DeviceButton_left mouse button" then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				if mx >= listX - listW / 2 and mx <= listX + listW / 2 and my >= 59 and my <= 94 then
					local tab = math.floor((mx - (listX - listW / 2)) / (listW / #categoryNames)) + 1
					if tab >= 1 and tab <= #categoryNames then
						categoryIndex = tab
						rebuildEntries()
						selected = 0
						lastOptionSelected = 1
						scrollStart = 1
						self:playcommand("Refresh")
					end
					return true
				end
				if mx >= panelX - panelW / 2 and mx <= panelX + panelW / 2
					and my >= choiceRowY - 22 and my <= choiceRowY + 22 then
					local choiceWidth = panelW / maxVisibleChoices
					local choiceIndex = choiceWindowStart + math.floor((mx - (panelX - panelW / 2)) / choiceWidth)
					if selected > 0 then setChoice(entries[selected], choiceIndex) end
					self:playcommand("Refresh")
					return true
				end
				if mx >= listX - listW / 2 and mx <= listX + listW / 2 and my >= listTop and my <= listBottom then
					local offset = math.floor((my - listFirstY) / rowPitch + 0.5)
					local index = (selected > 0 and selected or lastOptionSelected) + offset
					if index >= 1 and index <= #entries then
						selected = index
						lastOptionSelected = index
						ensureOptionVisible(index)
						local entry = entries[selected]
						if entry.action or entry.exit then activate(entry, screen)
						elseif mx > listX then changeChoice(entry, 1) end
						self:playcommand("Refresh")
					end
					return true
				end
			end
			return false
		end)
	end,
	RefreshCommand = function(self)
		scrollerSelection = selected > 0 and selected or lastOptionSelected
		scrollerFocused = selected > 0
		self:GetChild("List"):playcommand("Refresh")
		self:GetChild("CategoryTabs"):playcommand("Refresh")
		local entry = selected > 0 and entries[selected] or nil
		self:GetChild("DetailTitle"):settext(entry and entry.title or safeString("OptionTitles", categoryNames[categoryIndex]))
		self:GetChild("DetailText"):settext(entry and entry.description or categoryDescriptions[categoryIndex])
		displayChoices = entry and entry.choices or {}
		displayChoice = entry and entry.choice or 0
		ensureChoiceVisible(displayChoice > 0 and displayChoice or 1)
		self:GetChild("ValueList"):playcommand("Refresh")
	end,
}

-- Custom scroller viewport and option list.
root[#root + 1] = Def.ActorFrame {
	Name = "CategoryTabs",
	RefreshCommand = function(self)
		for i = 1, #categoryNames do
			local tab = self:GetChild("Tab" .. i)
			local current = i == categoryIndex
			local focused = current and selected == 0
			tab:GetChild("Backing"):diffuse(accent):diffusealpha(current and (focused and 0.3 or 0.14) or 0.05)
			tab:GetChild("Label"):diffuse(accent):diffusealpha(current and (focused and 1 or 0.76) or 0.42)
		end
	end,
	unpack((function()
		local children = {}
		local tabW = listW / #categoryNames
		for i, name in ipairs(categoryNames) do
			children[#children + 1] = Def.ActorFrame {
				Name = "Tab" .. i,
				InitCommand = function(self) self:xy(listX - listW / 2 + tabW * (i - 0.5), 79) end,
				Def.Quad {
					Name = "Backing",
					InitCommand = function(self) self:zoomto(tabW - 3, 29):diffuse(accent):diffusealpha(0.07) end,
				},
				LoadFont("Common Normal") .. {
					Name = "Label",
					InitCommand = function(self)
						self:zoom(0.43):diffuse(accent):diffusealpha(0.58)
						self:settext(safeString("OptionTitles", name))
					end,
				},
			}
		end
		return children
	end)())
}

root[#root + 1] = Def.ActorFrame {
	Name = "List",
	RefreshCommand = function(self)
		local active = scrollerFocused
		for i = 1, maxEntryCount do
			local actor = self:GetChild("Entry" .. i)
			if actor then
				local entry = entries[i]
				if entry then
					local offset = i - scrollStart
					local focused = i == scrollerSelection and active
					actor:visible(i >= scrollStart and i < scrollStart + visibleRows)
					actor:y(listFirstY + offset * rowPitch)
					actor:GetChild("Backing"):diffuse(accent):diffusealpha(i == scrollerSelection and (focused and 0.24 or 0.14) or 0.07)
					actor:GetChild("Title"):settext(entry.title)
					actor:GetChild("Title"):diffuse(accent):diffusealpha(i == scrollerSelection and (focused and 1 or 0.82) or 0.58)
					local choice = entry.choices and entry.choices[entry.choice]
					actor:GetChild("Value"):visible(choice ~= nil and not (entry.action or entry.exit))
					actor:GetChild("Value"):settext(choice and tostring(choice) or "")
					actor:GetChild("Value"):diffuse(accent):diffusealpha(i == scrollerSelection and (focused and 1 or 0.8) or 0.58)
				else
					actor:visible(false)
				end
			end
		end
	end,
	unpack((function()
		local children = {}
		for i = 1, maxEntryCount do
			children[#children + 1] = Def.ActorFrame {
				Name = "Entry" .. i,
				InitCommand = function(self) self:x(listX) end,
				Def.Quad {
					Name = "Backing",
					InitCommand = function(self) self:zoomto(listW, 34):diffuse(accent):diffusealpha(0.07) end,
				},
				LoadFont("Common Normal") .. {
					Name = "Title",
					InitCommand = function(self) self:x(-listW / 2 + 10):halign(0):zoom(0.47) end,
				},
				LoadFont("Common Normal") .. {
					Name = "Value",
					InitCommand = function(self) self:x(listW / 2 - 9):halign(1):zoom(0.42) end,
				},
			}
		end
		return children
	end)())
}

-- Custom information panel for the selected preference.
root[#root + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(panelX, SCREEN_CENTER_Y):zoomto(panelW, SCREEN_HEIGHT * 0.82):diffuse(accent):diffusealpha(0.07)
	end
}
root[#root + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(panelX - panelW / 2, SCREEN_CENTER_Y):zoomto(3, SCREEN_HEIGHT * 0.82)
			:diffuse(accent):diffusealpha(0.95)
	end
}
root[#root + 1] = LoadFont("Common Normal") .. {
	Name = "DetailTitle",
	InitCommand = function(self) self:xy(panelX - panelW / 2 + 14, listTop + 8):halign(0):zoom(0.55):diffuse(accent) end,
}
root[#root + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(panelX, listTop + 30):zoomto(panelW - 28, 2):diffuse(accent):diffusealpha(0.52)
	end
}
root[#root + 1] = LoadFont("Common Normal") .. {
	Name = "DetailText",
	InitCommand = function(self)
		self:xy(panelX - panelW / 2 + 14, listTop + 48):halign(0):valign(0):zoom(0.4)
			:wrapwidthpixels(panelW / 0.4 - 28):maxwidth(panelW / 0.4 - 28):diffuse(accent):diffusealpha(0.78)
	end,
}
root[#root + 1] = Def.ActorFrame {
	Name = "ValueList",
	RefreshCommand = function(self)
		for i = 1, maxVisibleChoices do
			local item = self:GetChild("Choice" .. i)
			local choiceIndex = choiceWindowStart + i - 1
			local value = displayChoices[choiceIndex]
			item:visible(value ~= nil)
			if value ~= nil then
				local chosen = choiceIndex == displayChoice
				item:GetChild("Backing"):diffuse(accent):diffusealpha(chosen and 0.25 or 0.06)
				item:GetChild("Label"):settext(tostring(value))
				item:GetChild("Label"):diffuse(accent):diffusealpha(chosen and 1 or 0.62)
			end
		end
	end,
	unpack((function()
		local children = {}
		local choiceWidth = panelW / maxVisibleChoices
		for i = 1, maxVisibleChoices do
			children[#children + 1] = Def.ActorFrame {
				Name = "Choice" .. i,
				InitCommand = function(self)
					self:xy(panelX - panelW / 2 + choiceWidth * (i - 0.5), choiceRowY)
				end,
				Def.Quad {
					Name = "Backing",
					InitCommand = function(self) self:zoomto(choiceWidth - 3, 38):diffuse(accent):diffusealpha(0.06) end,
				},
				LoadFont("Common Normal") .. {
					Name = "Label",
					InitCommand = function(self)
						self:zoom(0.38):maxwidth((choiceWidth - 8) / 0.38):diffuse(accent)
					end,
				},
			}
		end
		return children
	end)())
}
root[#root + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(panelX - panelW / 2 + 14, SCREEN_BOTTOM - 46):halign(0):zoom(0.31):diffuse(accent):diffusealpha(0.68)
		self:settext("LEFT / RIGHT OR CLICK A VALUE TO CHANGE")
	end,
}

-- Header and footer accents.
root[#root + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, 23):zoom(0.78):diffuse(accent)
		self:settext(THEME:GetString("ScreenHVOptions", "Title"))
	end,
}
root[#root + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, 45):zoom(0.32):diffuse(accent):diffusealpha(0.72)
		self:settext(THEME:GetString("ScreenHVOptions", "Subtitle"))
	end,
}
root[#root + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, 58):zoomto(SCREEN_WIDTH * 0.72, 2):diffuse(accent):diffusealpha(0.72)
	end,
}
root[#root + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 15):zoom(0.3):diffuse(accent):diffusealpha(0.72)
		self:settext("UP / DOWN SELECT   ·   AT TOP: LEFT / RIGHT CATEGORY   ·   ENTER SELECT   ·   ESC BACK")
	end,
}

return root
