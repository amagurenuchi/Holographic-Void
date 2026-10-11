--- Holographic Void: ScreenColorTheme Overlay
-- Custom Lua UI for selecting the theme's accent color.
-- Features clickable swatches with a live preview panel that updates in real time.
-- We use color presets for now. the proper color config screen will be here at some point.

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
	{ name = "Sky Blue",        hex = "#87CEEB" },      -- Extended cool color
	
	-- Warm Colors (Yellows/Oranges/Reds)
	{ name = "Warm Gold",       hex = "#FFD080" },
	{ name = "Golden",          hex = "#FFD700" },
	{ name = "Sunset Orange",   hex = "#FF7A00" },
	{ name = "Coral",           hex = "#FF6B6B" },
	{ name = "Soft Red",        hex = "#FF8080" },
	{ name = "Crimson",         hex = "#DC143C" },
	{ name = "Rose",            hex = "#FF007F" },
	{ name = "Amber",           hex = "#FFBF00" },      -- Extended warm color
	
	-- Purple/Violet Spectrum
	{ name = "Lavender",        hex = "#b6b6ff" },
	{ name = "Violet",          hex = "#B080FF" },
	{ name = "Electric Indigo", hex = "#4B0082" },
	{ name = "Cyber Purple",    hex = "#7000FF" },
	{ name = "Magenta",         hex = "#FF00FF" },
	{ name = "Orchid",          hex = "#DA70D6" },      -- Extended purple color
	
	-- Neutral/Grayscale
	{ name = "Pure Gray",       hex = "#808080" },
	{ name = "Silver",          hex = "#C0C0C0" },
	{ name = "Platinum",        hex = "#E5E4E2" },
	{ name = "White",           hex = "#FFFFFF" },
	{ name = "Charcoal",        hex = "#333b40" },      -- Extended neutral color
	
	-- Custom (opens color picker)
	{ name = "Custom",          hex = "#5ABAFF", isCustom = true },
}

-- Layout constants
local cols = 7
local rows = math.ceil(#accentChoices / cols)
local swatchSize = 50
local swatchGapX = 16
local swatchGapY = 44
local totalSwatchW = cols * (swatchSize + swatchGapX) - swatchGapX
local swatchStartX = SCREEN_LEFT + 60 + swatchSize / 2
local swatchStartY = SCREEN_CENTER_Y - 110

-- Preview panel constants (right side chunks)
local previewStartX = SCREEN_RIGHT - 180
local previewStartY = 118
local chunkW = 280
local chunkH = 44
local chunkGap = 6
local function getChunkY(i) return previewStartY + (i-1) * (chunkH + chunkGap) end

local function getSwatchPos(i)
	if accentChoices[i] and accentChoices[i].isCustom and i > 1 then
		local prevR = math.ceil((i - 1) / cols) - 1
		local prevC = ((i - 2) % cols) + 1
		sx = swatchStartX + prevC * (swatchSize + swatchGapX)
		sy = swatchStartY + prevR * (swatchSize + swatchGapY)
		return sx, sy
	end

	local r = math.ceil(i / cols) - 1
	local c = (i - 1) % cols
	sx = swatchStartX + c * (swatchSize + swatchGapX)
	sy = swatchStartY + r * (swatchSize + swatchGapY)
	return sx, sy
end

-- Interactivity for chunks
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

local function getGTStyle() return "Custom" end
local function cycleGTStyle()
	ThemePrefs.Set("HV_GoalTrackerColorStyle", "Custom")
	ThemePrefs.ForceSave()
	if HVColor and HVColor.RefreshGoalTrackerColors then HVColor.RefreshGoalTrackerColors() end
	MESSAGEMAN:Broadcast("GTStyleChanged")
end

-- State
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

-- ============================================================
-- Helpers
-- ============================================================
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
			SCREENMAN:AddNewScreenToTop("ScreenHVColorEdit")
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

-- ============================================================
-- Root ActorFrame
-- ============================================================
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

			-- Escape / Back
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
				if ni <= #accentChoices then applyColor(ni) return true end
			end

			-- Enter / Start to confirm and go back
			if gb == "Start" or btn == "DeviceButton_enter" then
				screen:Cancel()
				return true
			end

			-- Mouse click
			if btn == "DeviceButton_left mouse button" then
				local mx = INPUTFILTER:GetMouseX()
				local my = INPUTFILTER:GetMouseY()
				
				-- Swatches
				for i = 1, #accentChoices do
					local sx, sy = getSwatchPos(i)
					if mx >= sx - swatchSize/2 and mx <= sx + swatchSize/2
					   and my >= sy - swatchSize/2 and my <= sy + swatchSize/2 then
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

				-- Interactive Chunks
				local function isOverChunk(yOff)
					local cx = previewStartX
					local cy = yOff
					return mx >= cx - chunkW/2 and mx <= cx + chunkW/2
					   and my >= cy - chunkH/2 and my <= cy + chunkH/2
				end

				if isOverChunk(getChunkY(1)) then cycleGradeStyle() return true end
				if isOverChunk(getChunkY(2)) then cycleMSDScale() return true end
				if isOverChunk(getChunkY(3)) then cycleJudgeStyle() return true end
				if isOverChunk(getChunkY(4)) then cycleDiffStyle() return true end
				if isOverChunk(getChunkY(5)) then cycleCTStyle() return true end
				if isOverChunk(getChunkY(6)) then
					HV.SelectedCustomColor = {"grades", "AAAAA"}
					SCREENMAN:AddNewScreenToTop("ScreenHVCustomColors")
					return true
				end
			end
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
			-- Mouse hover detection
			local mx = INPUTFILTER:GetMouseX()
			local my = INPUTFILTER:GetMouseY()
			
			-- Swatches
			local newHover = nil
			for i = 1, #accentChoices do
				local sx, sy = getSwatchPos(i)
				if mx >= sx - swatchSize/2 and mx <= sx + swatchSize/2
				   and my >= sy - swatchSize/2 and my <= sy + swatchSize/2 then
					newHover = i
					break
				end
			end
			if newHover ~= hoveredIdx then
				hoveredIdx = newHover
				MESSAGEMAN:Broadcast("SwatchHoverChanged")
			end

			-- Chunk hovers
			local function isOverChunk(yOff)
				local cx = previewStartX
				local cy = yOff
				return mx >= cx - chunkW/2 and mx <= cx + chunkW/2
				   and my >= cy - chunkH/2 and my <= cy + chunkH/2
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

-- ============================================================
-- HEADER
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_TOP + 30) end,

	LoadFont("Common Large") .. {
		InitCommand = function(self)
			self:zoom(0.55):diffuse(color("1,1,1,1"))
			self:settext("COLOR THEME")
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(24):zoom(0.28):diffuse(color("0.45,0.45,0.45,1"))
			self:settext("Select an accent color for the Holographic Void experience")
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:y(38):zoomto(SCREEN_WIDTH * 0.4, 1)
				:diffuse(HVColor.Accent):diffusealpha(0.3)
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.5)
		end
	}
}

-- ============================================================
-- COLOR SWATCHES
-- ============================================================
for i, choice in ipairs(accentChoices) do
	t[#t + 1] = Def.ActorFrame {
		Name = "Swatch_" .. i,
		InitCommand = function(self)
			local sx, sy = getSwatchPos(i)
			self:xy(sx, sy)
		end,

		-- Swatch background (color fill)
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
					self:stoptweening():decelerate(0.1):zoomto(swatchSize + 6, swatchSize + 6)
				else
					self:stoptweening():decelerate(0.1):zoomto(swatchSize, swatchSize)
				end
			end
		},

		-- Selection ring
		Def.Quad {
			Name = "Ring",
			InitCommand = function(self)
				self:zoomto(swatchSize + 8, swatchSize + 8)
					:diffuse(color("1,1,1,0")):blend("BlendMode_Add")
			end,
			ColorThemeChangedMessageCommand = function(self)
				if selectedIdx == i then
					self:stoptweening():linear(0.12)
						:diffuse(color(choice.hex)):diffusealpha(0.7)
				else
					self:stoptweening():linear(0.12):diffusealpha(0)
				end
			end,
			BeginCommand = function(self)
				if selectedIdx == i then
					self:diffuse(color(choice.hex)):diffusealpha(0.7)
				end
			end,
			CustomColorChangedMessageCommand = function(self, params)
				if choice.isCustom and params and params.Color and params.Category == "accent" and params.Element == "Accent" then
					choice.hex = params.Color
					if selectedIdx == i then
						self:stoptweening():linear(0.12):diffuse(color(choice.hex)):diffusealpha(0.7)
					end
				end
			end
		},

		-- Selected checkmark indicator
		LoadFont("Common Normal") .. {
			Name = "Check",
			InitCommand = function(self)
				self:y(swatchSize/2 + 2):zoom(0.45):diffuse(color("1,1,1,0"))
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
			CustomColorChangedMessageCommand = function(self, params)
				if choice.isCustom and params and params.Color and params.Category == "accent" and params.Element == "Accent" then
					choice.hex = params.Color
					if selectedIdx == i then
						self:stoptweening():linear(0.1):diffuse(color(choice.hex)):diffusealpha(1)
					end
				end
			end
		},

		-- Custom indicator (only for Custom swatch)
		choice.isCustom and LoadFont("Common Normal") .. {
			Name = "CustomIndicator",
			InitCommand = function(self)
				self:zoom(0.5):diffuse(color("1,1,1,0.8")):settext("C")
			end
		} or nil,

		-- Label
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:y(swatchSize/2 + 14):zoom(0.28)
					:diffuse(color("0.65,0.65,0.65,1"))
				self:settext(choice.name)
			end,
			SwatchHoverChangedMessageCommand = function(self)
				if hoveredIdx == i then
					self:stoptweening():linear(0.1):diffuse(color("1,1,1,1"))
				else
					self:stoptweening():linear(0.1):diffuse(color("0.65,0.65,0.65,1"))
				end
			end
		}
	}
end

-- ============================================================
-- FEATURE PREVIEW CHUNKS (Right Side)
-- ============================================================





-- ============================================================
-- INTERACTIVE GRADE PREVIEW
-- ============================================================
t[#t+1] = Def.ActorFrame {
	Name = "Chunk_Grade",
	InitCommand = function(self) self:xy(previewStartX, getChunkY(1)) end,
	
	Def.Quad {
		InitCommand = function(self) self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.06,0.06,0.9")) end,
		GradeHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffuse(params.Hovering and color("0.1,0.1,0.1,0.9") or color("0.06,0.06,0.06,0.9"))
		end
	},
	
	Def.Quad {
		Name = "ChunkAccentBar",
		InitCommand = function(self)
			self:halign(0):x(-chunkW/2):zoomto(3, chunkH):diffuse(color(getActiveHex())):diffusealpha(0.8)
		end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.8) end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW/2 + 18, 0):zoom(0.4):diffuse(color(getActiveHex())):settext("G") end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW/2 + 38, -9):halign(0):zoom(0.34):diffuse(color("1,1,1,1")) end,
		BeginCommand = function(self) self:playcommand("Set") end,
		GradeStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self) self:settext("Grade Style: " .. getGradeStyle()) end
	},
	
	-- Grade Examples
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-chunkW/2 + 38, 9) end,
		(function()
			local grades = {"AAAAA", "AAAA", "AAA", "AA", "A", "B", "C", "D", "F"}
			local am = Def.ActorFrame {}
			for i, g in ipairs(grades) do
				am[#am+1] = LoadFont("Common Normal") .. {
					InitCommand = function(self) self:x((i-1)*26):zoom(0.24):halign(0) end,
					BeginCommand = function(self) self:playcommand("Set") end,
					GradeStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
					SetCommand = function(self) self:settext(g):diffuse(HVColor.GetGradeColor(g)) end
				}
			end
			return am
		end)()
	}
}

-- ============================================================
-- INTERACTIVE MSD SCALE PREVIEW
-- ============================================================
t[#t+1] = Def.ActorFrame {
	Name = "Chunk_MSD",
	InitCommand = function(self) self:xy(previewStartX, getChunkY(2)) end,
	
	Def.Quad {
		InitCommand = function(self) self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.06,0.06,0.9")) end,
		MSDHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffuse(params.Hovering and color("0.1,0.1,0.1,0.9") or color("0.06,0.06,0.06,0.9"))
		end
	},
	
	Def.Quad {
		InitCommand = function(self) self:halign(0):x(-chunkW/2):zoomto(3, chunkH):diffuse(color(getActiveHex())):diffusealpha(0.8) end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.8) end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW/2 + 18, 0):zoom(0.4):diffuse(color(getActiveHex())):settext("M") end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW/2 + 38, -9):halign(0):zoom(0.34):diffuse(color("1,1,1,1")) end,
		BeginCommand = function(self) self:playcommand("Set") end,
		MSDScaleChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self) self:settext("MSD Scale: " .. getMSDScale()) end
	},
	
	-- MSD Scale Bar (0-40)
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-chunkW/2 + 38, 9) end,
		(function()
			local am = Def.ActorFrame {}
			local segments = 40
			local segW = 200 / segments
			for i = 0, segments do
				am[#am+1] = Def.Quad {
					InitCommand = function(self) self:x(i * segW):halign(0):zoomto(segW, 4) end,
					BeginCommand = function(self) self:playcommand("Set") end,
					MSDScaleChangedMessageCommand = function(self) self:playcommand("Set") end,
					SetCommand = function(self) self:diffuse(HVColor.GetMSDRatingColor(i)) end
				}
			end
			return am
		end)()
	}
}

-- ============================================================
-- INTERACTIVE JUDGMENT PREVIEW
-- ============================================================
t[#t+1] = Def.ActorFrame {
	Name = "Chunk_Judge",
	InitCommand = function(self) self:xy(previewStartX, getChunkY(3)) end,
	
	Def.Quad {
		InitCommand = function(self) self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.06,0.06,0.9")) end,
		JudgeHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffuse(params.Hovering and color("0.1,0.1,0.1,0.9") or color("0.06,0.06,0.06,0.9"))
		end
	},
	
	Def.Quad {
		InitCommand = function(self) self:halign(0):x(-chunkW/2):zoomto(3, chunkH):diffuse(color(getActiveHex())):diffusealpha(0.8) end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.8) end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW/2 + 18, 0):zoom(0.4):diffuse(color(getActiveHex())):settext("J") end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW/2 + 38, -9):halign(0):zoom(0.34):diffuse(color("1,1,1,1")) end,
		BeginCommand = function(self) self:playcommand("Set") end,
		JudgeStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self) self:settext("Judgment Style: " .. getJudgeStyle()) end
	},
	
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-chunkW/2 + 38, 9) end,
		(function()
			local judges = {"W1", "W2", "W3", "W4", "W5", "Miss", "Held", "LetGo"}
			local labels = {"MARV", "PERF", "GREAT", "GOOD", "BAD", "MISS", "OK", "NG"}
			local am = Def.ActorFrame {}
			for i, j in ipairs(judges) do
				am[#am+1] = LoadFont("Common Normal") .. {
					InitCommand = function(self) self:x((i-1)*32):zoom(0.24):halign(0) end,
					BeginCommand = function(self) self:playcommand("Set") end,
					JudgeStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
					SetCommand = function(self) self:settext(labels[i]):diffuse(HVColor.GetJudgmentColor(j)) end
				}
			end
			return am
		end)()
	}
}

-- ============================================================
-- INTERACTIVE DIFFICULTY PREVIEW
-- ============================================================
t[#t+1] = Def.ActorFrame {
	Name = "Chunk_Diff",
	InitCommand = function(self) self:xy(previewStartX, getChunkY(4)) end,
	
	Def.Quad {
		InitCommand = function(self) self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.06,0.06,0.9")) end,
		DiffHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffuse(params.Hovering and color("0.1,0.1,0.1,0.9") or color("0.06,0.06,0.06,0.9"))
		end
	},
	
	Def.Quad {
		InitCommand = function(self) self:halign(0):x(-chunkW/2):zoomto(3, chunkH):diffuse(color(getActiveHex())):diffusealpha(0.8) end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.8) end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW/2 + 18, 0):zoom(0.4):diffuse(color(getActiveHex())):settext("D") end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW/2 + 38, -9):halign(0):zoom(0.34):diffuse(color("1,1,1,1")) end,
		BeginCommand = function(self) self:playcommand("Set") end,
		DiffStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self) self:settext("Difficulty Style: " .. getDiffStyle()) end
	},
	
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-chunkW/2 + 38, 9) end,
		(function()
			local diffs = {"Beginner", "Easy", "Medium", "Hard", "Challenge", "Edit"}
			local labels = {"BEG", "EASY", "MED", "HARD", "CHAL", "EDIT"}
			local am = Def.ActorFrame {}
			for i, d in ipairs(diffs) do
				am[#am+1] = LoadFont("Common Normal") .. {
					InitCommand = function(self) self:x((i-1)*40):zoom(0.24):halign(0) end,
					BeginCommand = function(self) self:playcommand("Set") end,
					DiffStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
					SetCommand = function(self) self:settext(labels[i]):diffuse(HVColor.GetDifficultyColor(d)) end
				}
			end
			return am
		end)()
	}
}

-- ============================================================
-- INTERACTIVE CLEAR TYPE PREVIEW
-- ============================================================
t[#t+1] = Def.ActorFrame {
	Name = "Chunk_CT",
	InitCommand = function(self) self:xy(previewStartX, getChunkY(5)) end,
	
	Def.Quad {
		InitCommand = function(self) self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.06,0.06,0.9")) end,
		CTHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffuse(params.Hovering and color("0.1,0.1,0.1,0.9") or color("0.06,0.06,0.06,0.9"))
		end
	},
	
	Def.Quad {
		InitCommand = function(self) self:halign(0):x(-chunkW/2):zoomto(3, chunkH):diffuse(color(getActiveHex())):diffusealpha(0.8) end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.8) end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW/2 + 18, 0):zoom(0.4):diffuse(color(getActiveHex())):settext("C") end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW/2 + 38, -9):halign(0):zoom(0.34):diffuse(color("1,1,1,1")) end,
		BeginCommand = function(self) self:playcommand("Set") end,
		CTStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self) self:settext("Clear Type Style: " .. getCTStyle()) end
	},
	
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-chunkW/2 + 38, 9) end,
		(function()
			local cts = {"MFC", "WF", "SDP", "PFC", "BF", "SDG", "FC", "NGFC", "MF", "SDCB", "Clear", "Failed", "NoPlay"}
			local labels = {"MFC", "WF", "SDP", "PFC", "BF", "SDG", "FC", "NGFC", "MF", "SDCB", "CLR", "FAIL", "NOP"}
			local am = Def.ActorFrame {}
			for i, ct in ipairs(cts) do
				am[#am+1] = LoadFont("Common Normal") .. {
					InitCommand = function(self) self:x((i-1)*18):zoom(0.18):halign(0) end,
					BeginCommand = function(self) self:playcommand("Set") end,
					CTStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
					SetCommand = function(self) self:settext(labels[i]):diffuse(HVColor.GetClearTypeColor(ct)) end
				}
			end
			return am
		end)()
	}
}

-- ============================================================
-- CUSTOM ELEMENT COLORING BUTTON (replaces Goal Tracker chunk)
-- ============================================================
t[#t+1] = Def.ActorFrame {
	Name = "Chunk_CustomElement",
	InitCommand = function(self) 
		self:xy(previewStartX, getChunkY(6))
	end,
	
	Def.Quad {
		Name = "ButtonBg",
		InitCommand = function(self) self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.06,0.06,0.9")) end,
		CustomElementHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffuse(params.Hovering and color("0.1,0.1,0.1,0.95") or color("0.06,0.06,0.06,0.9"))
		end
	},
	
	Def.Quad {
		InitCommand = function(self) self:halign(0):x(-chunkW/2):zoomto(3, chunkH):diffuse(HVColor.Accent):diffusealpha(0.8) end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.8) end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW/2 + 18, 0):zoom(0.4):diffuse(HVColor.Accent):settext("+") end,
		ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(-chunkW/2 + 38, 0):halign(0):zoom(0.34):diffuse(color("1,1,1,1")) end,
		BeginCommand = function(self) self:settext("Custom Element Coloring") end
	}
}

-- ============================================================
-- CURRENT SELECTION DISPLAY
-- ============================================================
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "CurrentLabel",
	InitCommand = function(self)
		self:xy(swatchStartX + totalSwatchW/2 - swatchSize/2, swatchStartY + 4 * (swatchSize + swatchGapY) + 20):zoom(0.32)
			:diffuse(color("0.65,0.65,0.65,1"))
	end,
	ColorThemeChangedMessageCommand = function(self)
		local name = accentChoices[selectedIdx] and accentChoices[selectedIdx].name or "?"
		self:settext("Active: " .. name)
	end,
	BeginCommand = function(self)
		local name = accentChoices[selectedIdx] and accentChoices[selectedIdx].name or "?"
		self:settext("Active: " .. name)
	end
}

-- ============================================================
-- FOOTER
-- ============================================================
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 20):zoom(0.28)
			:diffuse(color("0.45,0.45,0.45,1"))
		self:settext("Click a swatch or use Left/Right · Enter to confirm · Escape to go back")
	end
}

-- ============================================================
-- DECORATIVE BRACKETS
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:diffusealpha(0.2) end,
	Def.ActorFrame {
		InitCommand = function(self) self:xy(SCREEN_LEFT + 20, SCREEN_TOP + 20) end,
		Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(40, 1):diffuse(color(getActiveHex())) end,
			ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end },
		Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(1, 40):diffuse(color(getActiveHex())) end,
			ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end }
	},
	Def.ActorFrame {
		InitCommand = function(self) self:xy(SCREEN_RIGHT - 20, SCREEN_BOTTOM - 20) end,
		Def.Quad { InitCommand = function(self) self:halign(1):valign(1):zoomto(40, 1):diffuse(color(getActiveHex())) end,
			ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end },
		Def.Quad { InitCommand = function(self) self:halign(1):valign(1):zoomto(1, 40):diffuse(color(getActiveHex())) end,
			ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end }
	}
}

-- ============================================================
-- MOUSE CURSOR
-- ============================================================
t[#t + 1] = LoadActor("../_cursor")

return t
