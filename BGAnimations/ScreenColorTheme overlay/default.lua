--- Holographic Void: ScreenColorTheme Overlay
-- Redesigned modern cyberpunk/holographic interface.
-- Features clickable swatches with a live preview panel that updates in real time.
-- Preserves all original functions, behaviors, metrics, and navigation logic.

local function getAccent()
	return (HVColor and HVColor.Accent) or color("#5ABAFF")
end

local function transitionToScreen(screenName)
	local screen = SCREENMAN:GetTopScreen()
	if not screen then return end
	screen:SetNextScreenName(screenName)
	screen:StartTransitioningScreen("SM_GoToNextScreen")
end

local accentChoices = {
	-- Cool Colors (Blues/Cyans/Greens)
	{ name = "Ice Blue",        hex = "#5ABAFF" },     -- Default
	{ name = "Arctic Blue",     hex = "#4A9AEF" },
	{ name = "Deep Ocean",      hex = "#2E5F8A" },
	{ name = "Cyan",            hex = "#00FFFF" },
	{ name = "Teal",            hex = "#008B8B" },
	{ name = "Mint",            hex = "#80FFB0" },
	{ name = "Emerald",         hex = "#00D050" },
	{ name = "Forest Green",    hex = "#228B22" },
	{ name = "Sky Blue",        hex = "#87CEEB" },

	-- Warm Colors (Yellows/Oranges/Reds)
	{ name = "Warm Gold",       hex = "#FFD080" },
	{ name = "Golden",          hex = "#FFD700" },
	{ name = "Sunset Orange",   hex = "#FF7A00" },
	{ name = "Coral",           hex = "#FF6B6B" },
	{ name = "Soft Red",        hex = "#FF8080" },
	{ name = "Crimson",         hex = "#DC143C" },
	{ name = "Rose",            hex = "#FF007F" },
	{ name = "Amber",           hex = "#FFBF00" },

	-- Purple/Violet Spectrum
	{ name = "Lavender",        hex = "#B6B6FF" },
	{ name = "Violet",          hex = "#B080FF" },
	{ name = "Electric Indigo", hex = "#4B0082" },
	{ name = "Cyber Purple",    hex = "#7000FF" },
	{ name = "Magenta",         hex = "#FF00FF" },
	{ name = "Orchid",          hex = "#DA70D6" },

	-- Neutral/Grayscale
	{ name = "Pure Gray",       hex = "#808080" },
	{ name = "Silver",          hex = "#C0C0C0" },
	{ name = "Platinum",        hex = "#E5E4E2" },
	{ name = "White",           hex = "#FFFFFF" },
	{ name = "Charcoal",        hex = "#333B40" },

	-- Custom (opens color picker)
	{ name = "Custom",          hex = "#5ABAFF", isCustom = true },
}

-- =========================================================================
-- GEOMETRY & LAYOUT CONSTANTS (Strictly bounded to prevent overflow)
-- =========================================================================
local marginX = 20
local gap = 16
local totalW = SCREEN_WIDTH - marginX * 2
local listW = math.floor(totalW * 0.52)
local panelW = totalW - gap - listW
local listX = marginX + listW / 2
local panelX = marginX + listW + gap + panelW / 2

local headerTop = 14
local headerLineY = 48

local panelTop = 60
local panelBottom = SCREEN_HEIGHT - 28
local panelH = panelBottom - panelTop
local panelCenterY = panelTop + panelH / 2

-- Swatch grid layout inside Left Panel (7-column layout preserving original grouping)
local cols = 7
local swatchSize = WideScale(30, 36)
local swatchGapX = WideScale(12, 18)
local swatchRowPitch = WideScale(48, 52)
local totalGridW = cols * swatchSize + (cols - 1) * swatchGapX
local swatchStartX = listX - totalGridW / 2 + swatchSize / 2
local swatchStartY = panelTop + 34 + swatchSize / 2

local function getSwatchPos(i)
	local r = math.floor((i - 1) / cols)
	local c = (i - 1) % cols
	local sx = swatchStartX + c * (swatchSize + swatchGapX)
	local sy = swatchStartY + r * swatchRowPitch
	return sx, sy
end

-- Preview panel constants (Right side chunks)
local chunkW = panelW - 24
local chunkH = 44
local chunkGap = 8
local previewStartY = panelTop + 34 + chunkH / 2
local function getChunkY(i) return previewStartY + (i - 1) * (chunkH + chunkGap) end

-- Visual styling helpers
local function makeCornerBrackets(w, h, size, thickness)
	size = size or 8
	thickness = thickness or 1.5
	local halfW = w / 2
	local halfH = h / 2
	local function colorTick(self) self:diffuse(getAccent()):diffusealpha(0.85) end
	return Def.ActorFrame {
		Def.Quad { InitCommand = function(self) self:xy(-halfW + size / 2, -halfH + thickness / 2):zoomto(size, thickness); colorTick(self) end,
			ColorThemeChangedMessageCommand = function(self) colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(-halfW + thickness / 2, -halfH + size / 2):zoomto(thickness, size); colorTick(self) end,
			ColorThemeChangedMessageCommand = function(self) colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - size / 2, -halfH + thickness / 2):zoomto(size, thickness); colorTick(self) end,
			ColorThemeChangedMessageCommand = function(self) colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - thickness / 2, -halfH + size / 2):zoomto(thickness, size); colorTick(self) end,
			ColorThemeChangedMessageCommand = function(self) colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(-halfW + size / 2, halfH - thickness / 2):zoomto(size, thickness); colorTick(self) end,
			ColorThemeChangedMessageCommand = function(self) colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(-halfW + thickness / 2, halfH - size / 2):zoomto(thickness, size); colorTick(self) end,
			ColorThemeChangedMessageCommand = function(self) colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - size / 2, halfH - thickness / 2):zoomto(size, thickness); colorTick(self) end,
			ColorThemeChangedMessageCommand = function(self) colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - thickness / 2, halfH - size / 2):zoomto(thickness, size); colorTick(self) end,
			ColorThemeChangedMessageCommand = function(self) colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
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
-- STYLE PREFERENCE OPTIONS & CYCLING
-- =========================================================================
local gradeStyles = {"Holographic", "Classic", "Custom"}
local msdScales = {"Holographic", "Classic", "None", "Monochrome", "Accent"}
local judgeStyles = {"Holographic", "Classic", "Custom"}
local diffStyles = {"Holographic", "Classic", "Custom"}
local ctStyles = {"Holographic", "Classic", "Custom"}

local function getGradeStyle() return ThemePrefs.Get("HV_GradeColorStyle") or "Holographic" end
local function cycleGradeStyle()
	local current = getGradeStyle()
	local nextStyle = gradeStyles[1]
	for i, s in ipairs(gradeStyles) do if s == current then nextStyle = gradeStyles[i % #gradeStyles + 1] break end end
	ThemePrefs.Set("HV_GradeColorStyle", nextStyle)
	ThemePrefs.ForceSave()
	if HVColor and HVColor.RefreshGradeColors then HVColor.RefreshGradeColors() end
	MESSAGEMAN:Broadcast("GradeStyleChanged")
end

local function getMSDScale() return ThemePrefs.Get("HV_MSDColorScaleV3") or "Holographic" end
local function cycleMSDScale()
	local current = getMSDScale()
	local nextScale = msdScales[1]
	for i, s in ipairs(msdScales) do if s == current then nextScale = msdScales[i % #msdScales + 1] break end end
	ThemePrefs.Set("HV_MSDColorScaleV3", nextScale)
	ThemePrefs.ForceSave()
	MESSAGEMAN:Broadcast("MSDScaleChanged")
end

local function getJudgeStyle() return ThemePrefs.Get("HV_JudgmentColorStyle") or "Holographic" end
local function cycleJudgeStyle()
	local current = getJudgeStyle()
	local nextStyle = judgeStyles[1]
	for i, s in ipairs(judgeStyles) do if s == current then nextStyle = judgeStyles[i % #judgeStyles + 1] break end end
	ThemePrefs.Set("HV_JudgmentColorStyle", nextStyle)
	ThemePrefs.ForceSave()
	if HVColor and HVColor.RefreshJudgmentColors then HVColor.RefreshJudgmentColors() end
	MESSAGEMAN:Broadcast("JudgeStyleChanged")
end

local function getDiffStyle() return ThemePrefs.Get("HV_DifficultyColorStyle") or "Holographic" end
local function cycleDiffStyle()
	local current = getDiffStyle()
	local nextStyle = diffStyles[1]
	for i, s in ipairs(diffStyles) do if s == current then nextStyle = diffStyles[i % #diffStyles + 1] break end end
	ThemePrefs.Set("HV_DifficultyColorStyle", nextStyle)
	ThemePrefs.ForceSave()
	if HVColor and HVColor.RefreshDifficultyColors then HVColor.RefreshDifficultyColors() end
	MESSAGEMAN:Broadcast("DiffStyleChanged")
end

local function getCTStyle() return ThemePrefs.Get("HV_ClearTypeColorStyle") or "Holographic" end
local function cycleCTStyle()
	local current = getCTStyle()
	local nextStyle = ctStyles[1]
	for i, s in ipairs(ctStyles) do if s == current then nextStyle = ctStyles[i % #ctStyles + 1] break end end
	ThemePrefs.Set("HV_ClearTypeColorStyle", nextStyle)
	ThemePrefs.ForceSave()
	if HVColor and HVColor.RefreshClearTypeColors then HVColor.RefreshClearTypeColors() end
	MESSAGEMAN:Broadcast("CTStyleChanged")
end

-- =========================================================================
-- STATE & DATA HELPERS
-- =========================================================================
local selectedIdx = 1
local hoveredIdx = nil
local previewColor = color("#5ABAFF")
local lastCustomClickTime = 0

local function getCustomAccentHex()
	if HVCustomColors and HVCustomColors.GetColor then
		local hex = HVCustomColors.GetColor("accent", "Accent")
		if hex and type(hex) == "string" and hex ~= "#FFFFFF" and hex:match("^#?[0-9A-Fa-f]+$") then
			if hex:sub(1, 1) ~= "#" then hex = "#" .. hex end
			return hex
		end
	end
	local activeHex = ThemePrefs and ThemePrefs.Get and ThemePrefs.Get("HV_AccentColor") or "#5ABAFF"
	if not activeHex or activeHex == "" then activeHex = "#5ABAFF" end
	if activeHex:sub(1, 1) ~= "#" then activeHex = "#" .. activeHex end
	return activeHex
end

local function refreshCustomChoiceHex()
	for _, choice in ipairs(accentChoices) do
		if choice.isCustom then
			choice.hex = getCustomAccentHex()
			break
		end
	end
end

refreshCustomChoiceHex()

local function getActiveHex()
	if ThemePrefs and ThemePrefs.Get then
		local h = ThemePrefs.Get("HV_AccentColor")
		if h and h ~= "" then return h end
	end
	return "#5ABAFF"
end

local function findSelectedIdx()
	local cur = getActiveHex():upper()
	for i, c in ipairs(accentChoices) do
		if c.hex:upper() == cur then return i end
	end
	return 1
end

local function syncSelectionFromActive()
	refreshCustomChoiceHex()
	selectedIdx = findSelectedIdx()
	previewColor = color(getActiveHex())
	MESSAGEMAN:Broadcast("ColorThemeChanged")
end

local function applyColor(idx, openCustomPicker)
	local choice = accentChoices[idx]
	if not choice then return end
	openCustomPicker = openCustomPicker or false

	if choice.isCustom then
		refreshCustomChoiceHex()
		selectedIdx = idx
		ThemePrefs.Set("HV_AccentColor", choice.hex)
		ThemePrefs.ForceSave()
		if HVColor and HVColor.RefreshAccent then
			HVColor.RefreshAccent()
		end
		if HVCustomColors and HVCustomColors.SyncAccentLinkedColors then
			HVCustomColors.SyncAccentLinkedColors(choice.hex)
		end
		previewColor = color(choice.hex)
		MESSAGEMAN:Broadcast("ColorThemeChanged")
		MESSAGEMAN:Broadcast("ThemePrefChanged", { Name = "HV_AccentColor" })

		if openCustomPicker then
			HV.SelectedCustomColor = {"accent", "Accent"}
			transitionToScreen("ScreenHVColorEdit")
		end
		return
	end

	selectedIdx = idx
	ThemePrefs.Set("HV_AccentColor", choice.hex)
	ThemePrefs.ForceSave()
	if HVColor and HVColor.RefreshAccent then
		HVColor.RefreshAccent()
	end
	if HVCustomColors and HVCustomColors.SyncAccentLinkedColors then
		HVCustomColors.SyncAccentLinkedColors(choice.hex)
	end
	previewColor = color(choice.hex)
	MESSAGEMAN:Broadcast("ColorThemeChanged")
	MESSAGEMAN:Broadcast("ThemePrefChanged", { Name = "HV_AccentColor" })
end

-- =========================================================================
-- ROOT ACTORFRAME & INPUT
-- =========================================================================
local t = Def.ActorFrame {
	Name = "ColorThemeRoot",
	BeginCommand = function(self)
		refreshCustomChoiceHex()
		selectedIdx = findSelectedIdx()
		previewColor = color(getActiveHex())

		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end

		screen:AddInputCallback(function(event)
			if event.type ~= "InputEventType_FirstPress" then return end
			local btn = (event.DeviceInput or {}).button or ""
			local gb = event.button or ""

			-- Escape / Back to exit
			if gb == "Back" or btn == "DeviceButton_escape" then
				screen:Cancel()
				return true
			end

			-- Grid navigation
			if gb == "MenuLeft" or btn == "DeviceButton_left" then
				local ni = selectedIdx - 1
				if ni < 1 then ni = #accentChoices end
				applyColor(ni)
				return true
			end
			if gb == "MenuRight" or btn == "DeviceButton_right" then
				local ni = selectedIdx + 1
				if ni > #accentChoices then ni = 1 end
				applyColor(ni)
				return true
			end
			if gb == "MenuUp" or btn == "DeviceButton_up" then
				local ni = selectedIdx - cols
				if ni >= 1 then applyColor(ni) return true end
			end
			if gb == "MenuDown" or btn == "DeviceButton_down" then
				local ni = selectedIdx + cols
				if ni <= #accentChoices then
					applyColor(ni)
					return true
				elseif selectedIdx >= 22 and selectedIdx <= 28 then
					-- Any item in Row 3 jumps down to Custom
					applyColor(#accentChoices)
					return true
				end
			end

			-- Enter / Start: on custom open color edit; on preset confirm and exit
			if gb == "Start" or btn == "DeviceButton_enter" then
				if not (accentChoices[selectedIdx] and accentChoices[selectedIdx].isCustom) then
					screen:Cancel()
				end
				return true
			end

			-- Scheme preview hotkeys
			if btn == "DeviceButton_g" or btn == "DeviceButton_G" then cycleGradeStyle() return true end
			if btn == "DeviceButton_m" or btn == "DeviceButton_M" then cycleMSDScale() return true end
			if btn == "DeviceButton_j" or btn == "DeviceButton_J" then cycleJudgeStyle() return true end
			if btn == "DeviceButton_d" or btn == "DeviceButton_D" then cycleDiffStyle() return true end
			if btn == "DeviceButton_c" or btn == "DeviceButton_C" then cycleCTStyle() return true end
			if btn == "DeviceButton_e" or btn == "DeviceButton_E" then
				HV.SelectedCustomColor = {"grades", "AAAAA"}
				transitionToScreen("ScreenHVCustomColors")
				return true
			end

			-- Mouse click handling
			if btn == "DeviceButton_left mouse button" then
				local mx = INPUTFILTER:GetMouseX()
				local my = INPUTFILTER:GetMouseY()

				-- Swatches click
				for i = 1, #accentChoices do
					local sx, sy = getSwatchPos(i)
					if mx >= sx - swatchSize / 2 and mx <= sx + swatchSize / 2
					   and my >= sy - swatchSize / 2 and my <= sy + swatchSize / 2 then
						if accentChoices[i].isCustom then
							local now = (GetTimeSinceStart and GetTimeSinceStart()) or os.clock()
							local doubleClicked = (lastCustomClickTime > 0) and ((now - lastCustomClickTime) <= 0.30)
							lastCustomClickTime = now
							applyColor(i, doubleClicked)
						else
							applyColor(i)
						end
						return true
					end
				end

				-- Interactive Chunks click
				local function isOverChunk(cy)
					return mx >= panelX - chunkW / 2 and mx <= panelX + chunkW / 2
					   and my >= cy - chunkH / 2 and my <= cy + chunkH / 2
				end

				if isOverChunk(getChunkY(1)) then cycleGradeStyle() return true end
				if isOverChunk(getChunkY(2)) then cycleMSDScale() return true end
				if isOverChunk(getChunkY(3)) then cycleJudgeStyle() return true end
				if isOverChunk(getChunkY(4)) then cycleDiffStyle() return true end
				if isOverChunk(getChunkY(5)) then cycleCTStyle() return true end
				if isOverChunk(getChunkY(6)) then
					HV.SelectedCustomColor = {"grades", "AAAAA"}
					transitionToScreen("ScreenHVCustomColors")
					return true
				end
			end
			return false
		end)
	end,
	GainFocusCommand = function(self)
		syncSelectionFromActive()
	end,
	CustomColorChangedMessageCommand = function(self, params)
		if params and params.Category == "accent" and params.Element == "Accent" then
			syncSelectionFromActive()
		end
	end,
	InitCommand = function(self)
		self:SetUpdateFunction(function(af)
			local mx = INPUTFILTER:GetMouseX()
			local my = INPUTFILTER:GetMouseY()

			-- Swatches hover detection
			local newHover = nil
			for i = 1, #accentChoices do
				local sx, sy = getSwatchPos(i)
				if mx >= sx - swatchSize / 2 and mx <= sx + swatchSize / 2
				   and my >= sy - swatchSize / 2 and my <= sy + swatchSize / 2 then
					newHover = i
					break
				end
			end
			if newHover ~= hoveredIdx then
				hoveredIdx = newHover
				MESSAGEMAN:Broadcast("SwatchHoverChanged")
			end

			-- Chunks hover detection
			local function isOverChunk(cy)
				return mx >= panelX - chunkW / 2 and mx <= panelX + chunkW / 2
				   and my >= cy - chunkH / 2 and my <= cy + chunkH / 2
			end

			local overG = isOverChunk(getChunkY(1))
			local overM = isOverChunk(getChunkY(2))
			local overJ = isOverChunk(getChunkY(3))
			local overD = isOverChunk(getChunkY(4))
			local overC = isOverChunk(getChunkY(5))
			local overCustom = isOverChunk(getChunkY(6))

			if overG ~= self.HG then self.HG = overG MESSAGEMAN:Broadcast("GradeHoverChanged", { Hovering = overG }) end
			if overM ~= self.HM then self.HM = overM MESSAGEMAN:Broadcast("MSDHoverChanged", { Hovering = overM }) end
			if overJ ~= self.HJ then self.HJ = overJ MESSAGEMAN:Broadcast("JudgeHoverChanged", { Hovering = overJ }) end
			if overD ~= self.HD then self.HD = overD MESSAGEMAN:Broadcast("DiffHoverChanged", { Hovering = overD }) end
			if overC ~= self.HC then self.HC = overC MESSAGEMAN:Broadcast("CTHoverChanged", { Hovering = overC }) end
			if overCustom ~= self.HCustom then self.HCustom = overCustom MESSAGEMAN:Broadcast("CustomElementHoverChanged", { Hovering = overCustom }) end
		end)
	end
}

-- =========================================================================
-- 1. TOP HEADER & BREADCRUMB BAR (Matching Theme Options)
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "Header",
	-- Brand / Kicker
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX, headerTop):halign(0):zoom(0.28)
				:diffuse(getAccent()):diffusealpha(0.85)
			self:settext("HOLOGRAPHIC VOID  //  COLOR CONFIGURATION")
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.12):diffuse(previewColor):diffusealpha(0.85)
		end,
	},
	-- Screen Title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX, headerTop + 14):halign(0):zoom(0.62):diffuse(color("1,1,1,1"))
			self:settext("COLOR THEME")
		end,
	},
	-- Screen Subtitle
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX + 190, headerTop + 17):halign(0):zoom(0.32)
				:diffuse(color("0.65,0.68,0.74,0.85"))
			self:settext("Select a color to match your mood.")
		end,
	},
	-- Glow line behind header divider
	Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, headerLineY):zoomto(totalW, 3)
				:diffuse(getAccent()):diffusealpha(0.18)
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.12):diffuse(previewColor):diffusealpha(0.18)
		end,
	},
	-- Header Divider Line
	Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, headerLineY):zoomto(totalW, 1)
				:diffuse(getAccent()):diffusealpha(0.65)
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.12):diffuse(previewColor):diffusealpha(0.65)
		end,
	},
}

-- =========================================================================
-- 2. LEFT PANEL: ACCENT PALETTE & SWATCHES
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "LeftPanel",
	InitCommand = function(self) self:xy(listX, panelCenterY) end,
	-- Glass Backing
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

-- Left Panel Header Banner
t[#t + 1] = Def.ActorFrame {
	Name = "LeftPanelHeader",
	InitCommand = function(self) self:xy(listX, panelTop + 12) end,
	-- Backing
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(listW - 4, 24):diffuse(color("0.07,0.07,0.09,0.95"))
		end,
	},
	-- Divider Line
	Def.Quad {
		InitCommand = function(self)
			self:y(12):zoomto(listW - 4, 1):diffuse(color("0.18,0.20,0.24,0.8"))
		end,
	},
	-- Kicker
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(-listW / 2 + 16):halign(0):zoom(0.28)
				:diffuse(getAccent()):diffusealpha(0.85)
			self:settext("// PRESET PALETTE")
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.12):diffuse(previewColor):diffusealpha(0.85)
		end,
	},
	-- Active Name Counter
	LoadFont("Common Normal") .. {
		Name = "ActiveLabelInHeader",
		InitCommand = function(self)
			self:x(listW / 2 - 16):halign(1):zoom(0.26):diffuse(color("0.85,0.88,0.92,1"))
		end,
		BeginCommand = function(self) self:playcommand("Set") end,
		ColorThemeChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self)
			local name = accentChoices[selectedIdx] and accentChoices[selectedIdx].name or "Custom"
			self:settext("ACTIVE: " .. name:upper())
		end,
	},
}

-- Swatches inside Left Panel
for i, choice in ipairs(accentChoices) do
	t[#t + 1] = Def.ActorFrame {
		Name = "Swatch_" .. i,
		InitCommand = function(self)
			local sx, sy = getSwatchPos(i)
			self:xy(sx, sy)
		end,

		-- Outer Tile Border
		Def.Quad {
			Name = "SwatchBorder",
			InitCommand = function(self)
				self:zoomto(swatchSize + 4, swatchSize + 4):diffuse(color("0.16,0.18,0.22,0.8"))
			end,
			ColorThemeChangedMessageCommand = function(self)
				if selectedIdx == i then
					self:stoptweening():linear(0.1):diffuse(color(choice.hex)):diffusealpha(0.95)
				elseif hoveredIdx == i then
					self:stoptweening():linear(0.1):diffuse(color("0.5,0.55,0.65,0.9"))
				else
					self:stoptweening():linear(0.1):diffuse(color("0.16,0.18,0.22,0.8"))
				end
			end,
			SwatchHoverChangedMessageCommand = function(self)
				if selectedIdx == i then
					self:diffuse(color(choice.hex)):diffusealpha(0.95)
				elseif hoveredIdx == i then
					self:stoptweening():linear(0.08):diffuse(color("0.5,0.55,0.65,0.9"))
				else
					self:stoptweening():linear(0.08):diffuse(color("0.16,0.18,0.22,0.8"))
				end
			end,
		},

		-- Main Color Fill Quad
		Def.Quad {
			Name = "SwatchBg",
			InitCommand = function(self)
				self:zoomto(swatchSize, swatchSize):diffuse(color(choice.hex))
			end,
			CustomColorChangedMessageCommand = function(self, params)
				if choice.isCustom and params and params.Color and params.Category == "accent" and params.Element == "Accent" then
					choice.hex = params.Color
					self:stoptweening():linear(0.12):diffuse(color(choice.hex))
				end
			end,
			SwatchHoverChangedMessageCommand = function(self)
				if hoveredIdx == i then
					self:stoptweening():decelerate(0.1):zoomto(swatchSize + 2, swatchSize + 2)
				else
					self:stoptweening():decelerate(0.1):zoomto(swatchSize, swatchSize)
				end
			end,
		},

		-- Selection Glow Ring
		Def.Quad {
			Name = "Ring",
			InitCommand = function(self)
				self:zoomto(swatchSize + 8, swatchSize + 8)
					:diffuse(color("1,1,1,0")):blend("BlendMode_Add")
			end,
			ColorThemeChangedMessageCommand = function(self)
				if selectedIdx == i then
					self:stoptweening():linear(0.12):diffuse(color(choice.hex)):diffusealpha(0.65)
				else
					self:stoptweening():linear(0.12):diffusealpha(0)
				end
			end,
			BeginCommand = function(self)
				if selectedIdx == i then
					self:diffuse(color(choice.hex)):diffusealpha(0.65)
				end
			end,
			CustomColorChangedMessageCommand = function(self, params)
				if choice.isCustom and params and params.Color and params.Category == "accent" and params.Element == "Accent" then
					choice.hex = params.Color
					if selectedIdx == i then
						self:stoptweening():linear(0.12):diffuse(color(choice.hex)):diffusealpha(0.65)
					end
				end
			end,
		},

		-- Selected Radio Dot Indicator
		LoadFont("Common Normal") .. {
			Name = "Check",
			InitCommand = function(self)
				self:y(swatchSize / 2 + 1):zoom(0.35):diffuse(color("1,1,1,0"))
				self:settext("●")
			end,
			ColorThemeChangedMessageCommand = function(self)
				if selectedIdx == i then
					self:stoptweening():linear(0.1):diffuse(color(choice.hex)):diffusealpha(1)
				else
					self:stoptweening():linear(0.1):diffusealpha(0)
				end
			end,
			BeginCommand = function(self)
				if selectedIdx == i then
					self:diffuse(color(choice.hex)):diffusealpha(1)
				end
			end,
		},

		-- Custom Indicator Badge (only for Custom swatch)
		choice.isCustom and LoadFont("Common Normal") .. {
			Name = "CustomIndicator",
			InitCommand = function(self)
				self:zoom(0.42):diffuse(color("1,1,1,0.95")):settext("C")
			end,
		} or nil,

		-- Swatch Label below
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:y(swatchSize / 2 + 9):zoom(0.20)
					:diffuse(color("0.65,0.68,0.74,1")):maxwidth((swatchSize + 14) / 0.20)
				self:settext(choice.name)
			end,
			SwatchHoverChangedMessageCommand = function(self)
				if hoveredIdx == i or selectedIdx == i then
					self:stoptweening():linear(0.08):diffuse(color("1,1,1,1"))
				else
					self:stoptweening():linear(0.08):diffuse(color("0.65,0.68,0.74,1"))
				end
			end,
			ColorThemeChangedMessageCommand = function(self)
				if selectedIdx == i then
					self:diffuse(color("1,1,1,1"))
				else
					self:diffuse(color("0.65,0.68,0.74,1"))
				end
			end,
		},
	}
end



-- Active Color Status Card (Bottom of Left Panel - strictly within bounds)
local activeCardW = listW - 20
local activeCardH = 38
local activeCardY = panelBottom - 24

t[#t + 1] = Def.ActorFrame {
	Name = "ActiveColorCard",
	InitCommand = function(self) self:xy(listX, activeCardY) end,

	-- Card Backing
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(activeCardW, activeCardH):diffuse(color("0.06,0.07,0.09,0.95"))
		end,
	},
	-- Card Border
	Def.ActorFrame {
		makePanelBorder(activeCardW, activeCardH, color("0.18,0.20,0.24,0.8")),
	},
	-- Corner Accent Brackets
	Def.ActorFrame {
		makeCornerBrackets(activeCardW, activeCardH, 6, 1.2),
	},
	-- Left Accent Glow Bar
	Def.Quad {
		InitCommand = function(self)
			self:x(-activeCardW / 2 + 1.5):zoomto(3, activeCardH)
				:diffuse(getAccent()):diffusealpha(0.85)
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.12):diffuse(previewColor):diffusealpha(0.85)
		end,
	},

	-- Live Color Chip
	Def.Quad {
		Name = "ActiveChipBorder",
		InitCommand = function(self)
			self:x(-activeCardW / 2 + 20):zoomto(24, 24):diffuse(color("0.18,0.20,0.24,0.9"))
		end,
	},
	Def.Quad {
		Name = "ActiveChipFill",
		InitCommand = function(self)
			self:x(-activeCardW / 2 + 20):zoomto(20, 20):diffuse(color(getActiveHex()))
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.12):diffuse(previewColor)
		end,
	},

	-- Active Color Name & Title
	LoadFont("Common Normal") .. {
		Name = "ActiveTitle",
		InitCommand = function(self)
			self:xy(-activeCardW / 2 + 40, -6):halign(0):zoom(0.32):diffuse(color("1,1,1,1"))
		end,
		BeginCommand = function(self) self:playcommand("Set") end,
		ColorThemeChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self)
			local choice = accentChoices[selectedIdx]
			local name = choice and choice.name or "Accent"
			self:settext(name:upper())
		end,
	},

	-- Active Color Subtitle / Hex / Hint
	LoadFont("Common Normal") .. {
		Name = "ActiveSubtitle",
		InitCommand = function(self)
			self:xy(-activeCardW / 2 + 40, 7):halign(0):zoom(0.24):diffuse(color("0.65,0.68,0.74,1"))
		end,
		BeginCommand = function(self) self:playcommand("Set") end,
		ColorThemeChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self)
			local choice = accentChoices[selectedIdx]
			if choice and choice.isCustom then
				self:settext("CUSTOM COLOR (" .. choice.hex:upper() .. ")  ·  DOUBLE-CLICK TO EDIT HSV")
			else
				local hex = choice and choice.hex:upper() or "#5ABAFF"
				self:settext("HEX: " .. hex)
			end
		end,
	},

	-- "ACTIVE" pill badge on right
	Def.ActorFrame {
		InitCommand = function(self) self:x(activeCardW / 2 - 42) end,
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(62, 18):diffuse(color("0.10,0.12,0.16,0.85"))
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:zoom(0.24):diffuse(getAccent()):settext("ACTIVE")
			end,
			ColorThemeChangedMessageCommand = function(self)
				self:stoptweening():linear(0.12):diffuse(previewColor)
			end,
		},
	},
}

-- =========================================================================
-- 3. RIGHT PANEL: SYSTEM SCHEMES & STYLE PREVIEWS
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "RightPanel",
	InitCommand = function(self) self:xy(panelX, panelCenterY) end,
	-- Glass Backing
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
t[#t + 1] = Def.ActorFrame {
	Name = "RightPanelHeader",
	InitCommand = function(self) self:xy(panelX, panelTop + 12) end,
	-- Backing
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(panelW - 4, 24):diffuse(color("0.07,0.07,0.09,0.95"))
		end,
	},
	-- Divider Line
	Def.Quad {
		InitCommand = function(self)
			self:y(12):zoomto(panelW - 4, 1):diffuse(color("0.18,0.20,0.24,0.8"))
		end,
	},
	-- Breadcrumb Kicker
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(-panelW / 2 + 16):halign(0):zoom(0.28)
				:diffuse(getAccent()):diffusealpha(0.85)
			self:settext("// COMPONENTS COLORS")
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.12):diffuse(previewColor):diffusealpha(0.85)
		end,
	},
}

-- =========================================================================
-- CHUNK 1: GRADE COLORING PREVIEW
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "Chunk_Grade",
	InitCommand = function(self) self:xy(panelX, getChunkY(1)) end,

	Def.Quad {
		Name = "ChunkBg",
		InitCommand = function(self) self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.07,0.09,0.8")) end,
		GradeHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffuse(params.Hovering and color("0.10,0.12,0.16,0.95") or color("0.06,0.07,0.09,0.8"))
		end,
	},
	Def.ActorFrame {
		makePanelBorder(chunkW, chunkH, color("0.16,0.18,0.22,0.75")),
	},
	Def.Quad {
		Name = "ChunkAccentBar",
		InitCommand = function(self)
			self:halign(0):x(-chunkW / 2):zoomto(3, chunkH):diffuse(getAccent()):diffusealpha(0.85)
		end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.85) end,
	},

	-- Icon Badge
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW / 2 + 16, -9):zoom(0.34):diffuse(getAccent()):settext("[G]") end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end,
	},
	-- Title & Current Value
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW / 2 + 34, -9):halign(0):zoom(0.32):diffuse(color("1,1,1,1")) end,
		BeginCommand = function(self) self:playcommand("Set") end,
		GradeStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self) self:settext("Grade Style: " .. getGradeStyle()) end,
	},
	-- Grade Samples Row
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-chunkW / 2 + 34, 9) end,
		(function()
			local grades = {"AAAAA", "AAAA", "AAA", "AA", "A", "B", "C", "D", "F"}
			local am = Def.ActorFrame {}
			for i, g in ipairs(grades) do
				am[#am + 1] = LoadFont("Common Normal") .. {
					InitCommand = function(self) self:x((i - 1) * 28):zoom(0.24):halign(0) end,
					BeginCommand = function(self) self:playcommand("Set") end,
					GradeStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
					SetCommand = function(self) self:settext(g):diffuse(HVColor.GetGradeColor(g)) end,
				}
			end
			return am
		end)()
	}
}

-- =========================================================================
-- CHUNK 2: MSD RATING SCALE PREVIEW
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "Chunk_MSD",
	InitCommand = function(self) self:xy(panelX, getChunkY(2)) end,

	Def.Quad {
		InitCommand = function(self) self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.07,0.09,0.8")) end,
		MSDHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffuse(params.Hovering and color("0.10,0.12,0.16,0.95") or color("0.06,0.07,0.09,0.8"))
		end,
	},
	Def.ActorFrame {
		makePanelBorder(chunkW, chunkH, color("0.16,0.18,0.22,0.75")),
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):x(-chunkW / 2):zoomto(3, chunkH):diffuse(getAccent()):diffusealpha(0.85)
		end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.85) end,
	},

	-- Icon Badge
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW / 2 + 16, -9):zoom(0.34):diffuse(getAccent()):settext("[M]") end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end,
	},
	-- Title & Current Value
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW / 2 + 34, -9):halign(0):zoom(0.32):diffuse(color("1,1,1,1")) end,
		BeginCommand = function(self) self:playcommand("Set") end,
		MSDScaleChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self) self:settext("MSD Rating Scale: " .. getMSDScale()) end,
	},
	-- MSD Scale Bar (0-40)
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-chunkW / 2 + 34, 9) end,
		(function()
			local am = Def.ActorFrame {}
			local segments = 40
			local barTotalW = chunkW - 68
			local segW = barTotalW / segments
			for i = 0, segments do
				am[#am + 1] = Def.Quad {
					InitCommand = function(self) self:x(i * segW):halign(0):zoomto(math.max(1, segW), 5) end,
					BeginCommand = function(self) self:playcommand("Set") end,
					MSDScaleChangedMessageCommand = function(self) self:playcommand("Set") end,
					SetCommand = function(self) self:diffuse(HVColor.GetMSDRatingColor(i)) end,
				}
			end
			return am
		end)()
	}
}

-- =========================================================================
-- CHUNK 3: JUDGMENT COLORING PREVIEW
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "Chunk_Judge",
	InitCommand = function(self) self:xy(panelX, getChunkY(3)) end,

	Def.Quad {
		InitCommand = function(self) self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.07,0.09,0.8")) end,
		JudgeHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffuse(params.Hovering and color("0.10,0.12,0.16,0.95") or color("0.06,0.07,0.09,0.8"))
		end,
	},
	Def.ActorFrame {
		makePanelBorder(chunkW, chunkH, color("0.16,0.18,0.22,0.75")),
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):x(-chunkW / 2):zoomto(3, chunkH):diffuse(getAccent()):diffusealpha(0.85)
		end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.85) end,
	},

	-- Icon Badge
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW / 2 + 16, -9):zoom(0.34):diffuse(getAccent()):settext("[J]") end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end,
	},
	-- Title & Current Value
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW / 2 + 34, -9):halign(0):zoom(0.32):diffuse(color("1,1,1,1")) end,
		BeginCommand = function(self) self:playcommand("Set") end,
		JudgeStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self) self:settext("Judgment Style: " .. getJudgeStyle()) end,
	},
	-- Judgment Samples Row
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-chunkW / 2 + 34, 9) end,
		(function()
			local judges = {"W1", "W2", "W3", "W4", "W5", "Miss", "Held", "LetGo"}
			local labels = {"MARV", "PERF", "GREAT", "GOOD", "BAD", "MISS", "OK", "NG"}
			local am = Def.ActorFrame {}
			for i, j in ipairs(judges) do
				am[#am + 1] = LoadFont("Common Normal") .. {
					InitCommand = function(self) self:x((i - 1) * 32):zoom(0.24):halign(0) end,
					BeginCommand = function(self) self:playcommand("Set") end,
					JudgeStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
					SetCommand = function(self) self:settext(labels[i]):diffuse(HVColor.GetJudgmentColor(j)) end,
				}
			end
			return am
		end)()
	}
}

-- =========================================================================
-- CHUNK 4: DIFFICULTY COLORING PREVIEW
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "Chunk_Diff",
	InitCommand = function(self) self:xy(panelX, getChunkY(4)) end,

	Def.Quad {
		InitCommand = function(self) self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.07,0.09,0.8")) end,
		DiffHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffuse(params.Hovering and color("0.10,0.12,0.16,0.95") or color("0.06,0.07,0.09,0.8"))
		end,
	},
	Def.ActorFrame {
		makePanelBorder(chunkW, chunkH, color("0.16,0.18,0.22,0.75")),
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):x(-chunkW / 2):zoomto(3, chunkH):diffuse(getAccent()):diffusealpha(0.85)
		end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.85) end,
	},

	-- Icon Badge
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW / 2 + 16, -9):zoom(0.34):diffuse(getAccent()):settext("[D]") end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end,
	},
	-- Title & Current Value
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW / 2 + 34, -9):halign(0):zoom(0.32):diffuse(color("1,1,1,1")) end,
		BeginCommand = function(self) self:playcommand("Set") end,
		DiffStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self) self:settext("Difficulty Style: " .. getDiffStyle()) end,
	},
	-- Difficulty Samples Row
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-chunkW / 2 + 34, 9) end,
		(function()
			local diffs = {"Beginner", "Easy", "Medium", "Hard", "Challenge", "Edit"}
			local labels = {"BEG", "EASY", "MED", "HARD", "CHAL", "EDIT"}
			local am = Def.ActorFrame {}
			for i, d in ipairs(diffs) do
				am[#am + 1] = LoadFont("Common Normal") .. {
					InitCommand = function(self) self:x((i - 1) * 40):zoom(0.24):halign(0) end,
					BeginCommand = function(self) self:playcommand("Set") end,
					DiffStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
					SetCommand = function(self) self:settext(labels[i]):diffuse(HVColor.GetDifficultyColor(d)) end,
				}
			end
			return am
		end)()
	}
}

-- =========================================================================
-- CHUNK 5: CLEAR TYPE COLORING PREVIEW
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "Chunk_CT",
	InitCommand = function(self) self:xy(panelX, getChunkY(5)) end,

	Def.Quad {
		InitCommand = function(self) self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.07,0.09,0.8")) end,
		CTHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffuse(params.Hovering and color("0.10,0.12,0.16,0.95") or color("0.06,0.07,0.09,0.8"))
		end,
	},
	Def.ActorFrame {
		makePanelBorder(chunkW, chunkH, color("0.16,0.18,0.22,0.75")),
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):x(-chunkW / 2):zoomto(3, chunkH):diffuse(getAccent()):diffusealpha(0.85)
		end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.85) end,
	},

	-- Icon Badge
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW / 2 + 16, -9):zoom(0.34):diffuse(getAccent()):settext("[C]") end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end,
	},
	-- Title & Current Value
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW / 2 + 34, -9):halign(0):zoom(0.32):diffuse(color("1,1,1,1")) end,
		BeginCommand = function(self) self:playcommand("Set") end,
		CTStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self) self:settext("Clear Type Style: " .. getCTStyle()) end,
	},
	-- Clear Type Samples Row
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-chunkW / 2 + 34, 9) end,
		(function()
			local cts = {"MFC", "WF", "SDP", "PFC", "BF", "SDG", "FC", "NGFC", "MF", "SDCB", "Clear", "Failed", "NoPlay"}
			local labels = {"MFC", "WF", "SDP", "PFC", "BF", "SDG", "FC", "NGFC", "MF", "SDCB", "CLR", "FAIL", "NOP"}
			local am = Def.ActorFrame {}
			for i, ct in ipairs(cts) do
				am[#am + 1] = LoadFont("Common Normal") .. {
					InitCommand = function(self) self:x((i - 1) * 19):zoom(0.19):halign(0) end,
					BeginCommand = function(self) self:playcommand("Set") end,
					CTStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
					SetCommand = function(self) self:settext(labels[i]):diffuse(HVColor.GetClearTypeColor(ct)) end,
				}
			end
			return am
		end)()
	}
}

-- =========================================================================
-- CHUNK 6: CUSTOM ELEMENT COLORING CTA BUTTON
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "Chunk_CustomElement",
	InitCommand = function(self) self:xy(panelX, getChunkY(6)) end,

	-- Button Backing
	Def.Quad {
		Name = "ButtonBg",
		InitCommand = function(self)
			self:zoomto(chunkW, chunkH):diffuse(color("0.08,0.09,0.12,0.95"))
		end,
		CustomElementHoverChangedMessageCommand = function(self, params)
			if params.Hovering then
				self:stoptweening():linear(0.1):diffuse(getAccent()):diffusealpha(0.22)
			else
				self:stoptweening():linear(0.1):diffuse(color("0.08,0.09,0.12,0.95"))
			end
		end,
	},
	-- Border Outline
	Def.ActorFrame {
		makePanelBorder(chunkW, chunkH, color("0.22,0.25,0.32,0.85")),
	},
	-- Corner Accent Brackets
	Def.ActorFrame {
		makeCornerBrackets(chunkW, chunkH, 6, 1.2),
	},
	-- Left Accent Glow Bar
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):x(-chunkW / 2):zoomto(3, chunkH)
				:diffuse(getAccent()):diffusealpha(0.9)
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.9)
		end,
	},

	-- Plus Badge
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-chunkW / 2 + 16, -6):zoom(0.38):diffuse(getAccent()):settext("[+]")
		end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end,
	},
	-- Button Title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-chunkW / 2 + 34, -6):halign(0):zoom(0.36):diffuse(color("1,1,1,1"))
			self:settext("CUSTOM ELEMENT COLORING →")
		end,
	},
	-- Subtitle
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-chunkW / 2 + 34, 9):halign(0):zoom(0.24):diffuse(color("0.65,0.68,0.74,1"))
			self:settext("Configure individual HUD, judgment, clear type & grade colors")
		end,
	},
	-- Right Indicator Badge
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(chunkW / 2 - 14, 0):halign(1):zoom(0.30):diffuse(getAccent()):settext("→")
		end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end,
	},
}

-- =========================================================================
-- 4. NAVIGATION FOOTER BAR (Matching Theme Options)
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "FooterBar",
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 13) end,
	-- Backing
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(SCREEN_WIDTH, 22):diffuse(color("0.03,0.03,0.04,0.95"))
		end,
	},
	-- Top Divider Line
	Def.Quad {
		InitCommand = function(self)
			self:y(-11):zoomto(SCREEN_WIDTH, 1):diffuse(color("0.16,0.18,0.22,0.8"))
		end,
	},
}

-- =========================================================================
-- 5. MOUSE CURSOR
-- =========================================================================
t[#t + 1] = LoadActor("../_cursor")

return t
