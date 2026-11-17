--- Holographic Void: ScreenHVColorEdit Overlay
-- Redesigned modern cyberpunk/holographic interface.
-- HSV color picker for custom element colors.
-- Preserves all original functions, behaviors, metrics, and navigation logic.

local function getAccent()
	return (HVColor and HVColor.Accent) or color("#5ABAFF")
end

local function makeCornerBrackets(w, h, size, thickness)
	size = size or 8
	thickness = thickness or 1.5
	local halfW = w / 2
	local halfH = h / 2
	local function colorTick(self) self:diffuse(getAccent()):diffusealpha(0.85) end
	return Def.ActorFrame {
		Def.Quad { InitCommand = function(self) self:xy(-halfW + size / 2, -halfH + thickness / 2):zoomto(size, thickness); colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(-halfW + thickness / 2, -halfH + size / 2):zoomto(thickness, size); colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - size / 2, -halfH + thickness / 2):zoomto(size, thickness); colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - thickness / 2, -halfH + size / 2):zoomto(thickness, size); colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(-halfW + size / 2, halfH - thickness / 2):zoomto(size, thickness); colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(-halfW + thickness / 2, halfH - size / 2):zoomto(thickness, size); colorTick(self) end },
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

local selected = HV.SelectedCustomColor or {"grades", "AAAAA"}
local category = selected[1]
local element = selected[2]
local isAccentEdit = (category == "accent" and element == "Accent")
local themeColor = nil
if isAccentEdit then
	local customAccent = HVCustomColors.GetColor("accent", "Accent")
	local currentAccent = ThemePrefs.Get("HV_AccentColor")
	themeColor = customAccent or currentAccent or "#5ABAFF"
else
	themeColor = HVCustomColors.GetColor(category, element)
end

-- HSV state
local satNum = 0
local hueNum = 0
local valNum = 0
local alphaNum = 1
local currentColor = color("#FFFFFF")
local hexEntryString = "#"
local textCursorPos = 2
local aboutToSave = false

local colorBoxHeight = GetScreenAspectRatio() == 1 and 175 or 250
local saturationSliderWidth = 25
local genericSpacing = 15

local saturationOverlay = nil
local saturationSliderPos = nil
local colorPickPosition = nil
local alphaSliderPos = nil
local mouseLeftDown = false
local syncAccentEnabled = false

-- Layout geometry matching Theme Options
local marginX = 20
local headerTop = 20
local headerLineY = 56
local totalW = SCREEN_WIDTH - marginX * 2

local cardW = math.min(SCREEN_WIDTH - 40, 800)
local cardH = math.min(SCREEN_HEIGHT - 120, 480)
local cardX = SCREEN_CENTER_X
local cardY = SCREEN_CENTER_Y + 12

local pickerLeftX = cardX - cardW / 2 + 40
local pickerTopY = cardY - cardH / 2 + 70

local syncBtnW = 180
local syncBtnH = 28
local syncBtnX = cardX + cardW / 2 - 40 - syncBtnW / 2
local syncBtnY = pickerTopY + 14

local function isSyncAccentDisabled()
	return isAccentEdit
end

-- Convert color to HSV
local function colorToHSV(c)
	local r = c[1]
	local g = c[2]
	local b = c[3]
	local cmax = math.max(r, g, b)
	local cmin = math.min(r, g, b)
	local dc = cmax - cmin

	local h = 0
	if dc == 0 then
		h = 0
	elseif cmax == r then
		h = 60 * (((g-b)/dc) % 6)
	elseif cmax == g then
		h = 60 * (((b-r)/dc) + 2)
	elseif cmax == b then
		h = 60 * (((r-g)/dc) + 4)
	end

	local s = (cmax == 0 and 0 or dc / cmax)
	local v = cmax
	local alpha = c[4] or 1

	return h, 1-s, 1-v, alpha
end

-- Apply HSV and update visuals
local function applyHSV()
	local newColor = HSV(hueNum, 1 - satNum, 1 - valNum)
	newColor[4] = alphaNum
	currentColor = newColor

	if colorPickPosition then
		colorPickPosition:xy(saturationSliderWidth + (colorBoxHeight * hueNum/360), colorBoxHeight * valNum)
	end
	if saturationOverlay then
		saturationOverlay:diffusealpha(satNum)
	end
	if saturationSliderPos then
		saturationSliderPos:y(colorBoxHeight * satNum)
	end
	if alphaSliderPos then
		alphaSliderPos:y(colorBoxHeight * (1-alphaNum))
	end

	textCursorPos = 7
	hexEntryString = "#" .. ColorToHex(currentColor)

	MESSAGEMAN:Broadcast("ClickedNewColor")
end

-- Update functions
local function updateSaturation(percent)
	if percent < 0 then percent = 0 elseif percent > 1 then percent = 1 end
	satNum = percent
	applyHSV()
end

local function updateAlpha(percent)
	if percent < 0 then percent = 0 elseif percent > 1 then percent = 1 end
	alphaNum = 1 - percent
	applyHSV()
end

local function updateColor(percentX, percentY)
	if percentY < 0 then percentY = 0 elseif percentY > 1 then percentY = 1 end
	if percentX < 0 then percentX = 0 elseif percentX > 1 then percentX = 1 end

	hueNum = 360 * percentX
	valNum = percentY
	applyHSV()
end

-- Initialize from saved color
hueNum, satNum, valNum, alphaNum = colorToHSV(color(themeColor))

local function getXPositionInText(self, index)
	local tlChar1 = self:getGlyphRect(1)
	local tlCharIndex = self:getGlyphRect(index)
	local theX = tlCharIndex[1] - tlChar1[1]
	return theX * self:GetZoom()
end

local function getWidthOfChar(self, index)
	local tl, bl, tr, br = self:getGlyphRect(index)
	local glyphWidth = tr[1] - bl[1]
	return glyphWidth / (self:GetZoom() * 10)
end

-- Hex input handling
local function handleHexEntry(character)
	character = character:upper()
	if textCursorPos < 2 then textCursorPos = 2 end
	if textCursorPos > 7 then textCursorPos = 7 end

	if #hexEntryString < textCursorPos then
		hexEntryString = hexEntryString .. character
	else
		local left = hexEntryString:sub(1, textCursorPos - 1)
		local right = ""
		if textCursorPos < #hexEntryString then
			right = hexEntryString:sub(textCursorPos + 1)
		end
		hexEntryString = left .. character .. right
	end

	if #hexEntryString > 7 then
		hexEntryString = hexEntryString:sub(1, 7)
	end
	if textCursorPos < 7 then textCursorPos = textCursorPos + 1 end

	aboutToSave = false
	MESSAGEMAN:Broadcast("UpdateStringDisplay")
end

local function handleTextUpdate()
	local hxl = #hexEntryString - 1
	local finalcolor = color("#FFFFFF")

	if hxl == 6 or hxl == 8 then
		finalcolor[1] = tonumber("0x"..hexEntryString:sub(2,3)) / 255
		finalcolor[2] = tonumber("0x"..hexEntryString:sub(4,5)) / 255
		finalcolor[3] = tonumber("0x"..hexEntryString:sub(6,7)) / 255
		if hxl == 8 then
			finalcolor[4] = tonumber("0x"..hexEntryString:sub(8,9)) / 255
		end

		hueNum, satNum, valNum, alphaNum = colorToHSV(finalcolor)
		aboutToSave = true
		applyHSV()
	end
end

local function syncToAccentColor()
	local accentHex = (ThemePrefs and ThemePrefs.Get and ThemePrefs.Get("HV_AccentColor")) or "#5ABAFF"
	if not accentHex or accentHex == "" then accentHex = "#5ABAFF" end
	if accentHex:sub(1, 1) ~= "#" then accentHex = "#" .. accentHex end

	hueNum, satNum, valNum, alphaNum = colorToHSV(color(accentHex))
	if not isAccentEdit and HVCustomColors and HVCustomColors.SetColor then
		themeColor = accentHex
		HVCustomColors.SetColor(category, element, accentHex)
	end
	aboutToSave = true
	applyHSV()
	MESSAGEMAN:Broadcast("UpdateStringDisplay")
end

local function setSyncAccentEnabled(enabled)
	syncAccentEnabled = enabled and true or false
	if HVCustomColors and HVCustomColors.SetSyncToAccentEnabled then
		HVCustomColors.SetSyncToAccentEnabled(category, element, syncAccentEnabled)
	end
	if syncAccentEnabled then
		syncToAccentColor()
	end
	MESSAGEMAN:Broadcast("SyncAccentToggleChanged", { Enabled = syncAccentEnabled })
end

local function toggleSyncAccentEnabled()
	setSyncAccentEnabled(not syncAccentEnabled)
end

-- Input callback
local function inputeater(event)
	local eventType = event.type or ""
	local deviceButton = event.DeviceInput and event.DeviceInput.button or ""
	local gameButton = event.GameButton or event.button or ""

	if deviceButton == "DeviceButton_left mouse button" then
		if eventType == "InputEventType_FirstPress" or eventType == "InputEventType_Repeat" then
			mouseLeftDown = true
		elseif eventType == "InputEventType_Release" then
			mouseLeftDown = false
		end
	end

	if eventType ~= "InputEventType_FirstPress" then return end

	if deviceButton == "DeviceButton_left mouse button" then
		local mx = INPUTFILTER:GetMouseX()
		local my = INPUTFILTER:GetMouseY()
		if mx >= syncBtnX - syncBtnW/2 and mx <= syncBtnX + syncBtnW/2
		   and my >= syncBtnY - syncBtnH/2 and my <= syncBtnY + syncBtnH/2 then
			if isSyncAccentDisabled() then return true end
			toggleSyncAccentEnabled()
			return true
		end
	end

	if event.char and event.char:match('[%x]') then
		handleHexEntry(event.char)
	elseif deviceButton == "DeviceButton_delete" then
		if INPUTFILTER:IsControlPressed() then
			local defaultColors = {
				accent = { Accent = "#5ABAFF" },
				grades = { AAAAA = "#FFFFFF", AAAA = "#80C0CF", AAA = "#CFD198", AA = "#A0CFAB", A = "#CF9898", B = "#98B8CF", C = "#B898CF", D = "#CF98B8", F = "#606060", None = "#454545" },
				judgment = { Ridiculous = "#FFD7FF", W1 = "#f1ffff", W2 = "#FFFFB7", W3 = "#A0E0A0", W4 = "#A0C8E0", W5 = "#C8A0E0", Miss = "#E0A0A0", Held = "#8fbb84ff", LetGo = "#E0A0A0" },
				difficulty = { Beginner = "#98B8CF", Easy = "#A0CFAB", Medium = "#CFD198", Hard = "#CF9898", Challenge = "#B898CF", Edit = "#8C8C8C" },
				clearType = { RFC = "#FFD7FF", RF = "#E8C8F8", SDM = "#D8C0F0", MFC = "#E0F8FF", WF = "#E0E0E0", SDP = "#CFD198", PFC = "#CFD198", BF = "#B898CF", SDG = "#A0CFAB", FC = "#A0CFAB", NGFC = "#80C0CF", MF = "#CF9898", SDCB = "#80C0CF", Clear = "#5ABAFF", Failed = "#CF9898", Invalid = "#454545", NoPlay = "#252525", None = "#252525" },
				goalTracker = { Positive = "#A0CFAB", Negative = "#CF9898" },
				lifeBar = { L1 = "#A0CFAB", L2 = "#A0CFAB", L3 = "#5ABAFF", L4 = "#5ABAFF", L5 = "#CFD198", L6 = "#E0B080", L7 = "#CF9898", Danger = "#FF4444" },
				radar = { Power = "#E0B080", Chaos = "#B898CF", Hell = "#CF9898", Mach = "#80C0CF", Freeze = "#CFD198", Earth = "#A0CFAB" },
			}
			local def = defaultColors[category] and defaultColors[category][element]
			if def then
				hueNum, satNum, valNum, alphaNum = colorToHSV(color(def))
				aboutToSave = false
				applyHSV()
			end                       
		elseif INPUTFILTER:IsBeingPressed("right alt") or INPUTFILTER:IsBeingPressed("left alt") then
			hueNum, satNum, valNum, alphaNum = colorToHSV(color(themeColor))
			aboutToSave = false
			applyHSV()
		else
			hexEntryString = "#"
			textCursorPos = 2
			aboutToSave = false
		end
		MESSAGEMAN:Broadcast("UpdateStringDisplay")
	elseif deviceButton == "DeviceButton_backspace" then
		if #hexEntryString > 1 then
			local removePos = math.max(2, textCursorPos - 1)
			hexEntryString = hexEntryString:sub(1, removePos - 1) .. hexEntryString:sub(removePos + 1)
			if textCursorPos > 2 then textCursorPos = textCursorPos - 1 end
			aboutToSave = false
			MESSAGEMAN:Broadcast("UpdateStringDisplay")
		end
	elseif gameButton == "Left" or gameButton == "MenuLeft" or deviceButton == "DeviceButton_left" then
		if textCursorPos > 2 then
			textCursorPos = textCursorPos - 1
			MESSAGEMAN:Broadcast("UpdateStringDisplay")
		end
	elseif gameButton == "Right" or gameButton == "MenuRight" or deviceButton == "DeviceButton_right" then
		if textCursorPos < 7 then
			textCursorPos = textCursorPos + 1
			MESSAGEMAN:Broadcast("UpdateStringDisplay")
		end
	elseif gameButton == "Back" or deviceButton == "DeviceButton_escape" then
		if isAccentEdit then
			local screen = SCREENMAN:GetTopScreen()
			screen:SetNextScreenName("ScreenColorTheme")
			screen:StartTransitioningScreen("SM_GoToNextScreen")
		else
			SCREENMAN:GetTopScreen():Cancel()
		end
	elseif gameButton == "Select" or deviceButton == "DeviceButton_tab" then
		if isSyncAccentDisabled() then return true end
		toggleSyncAccentEnabled()
	elseif gameButton == "Start" or deviceButton == "DeviceButton_enter" then
		if aboutToSave then
			local savedHex = "#" .. ColorToHex(currentColor)
			if isAccentEdit then
				HVCustomColors.SetColor("accent", "Accent", savedHex)
				ThemePrefs.Set("HV_AccentColor", savedHex)
				ThemePrefs.ForceSave()
				if HVColor and HVColor.RefreshAccent then HVColor.RefreshAccent() end
				if HVCustomColors and HVCustomColors.SyncAccentLinkedColors then
					HVCustomColors.SyncAccentLinkedColors(savedHex)
				end
				MESSAGEMAN:Broadcast("ColorThemeChanged")
				MESSAGEMAN:Broadcast("ThemePrefChanged", { Name = "HV_AccentColor" })
			else
				HVCustomColors.SetColor(category, element, savedHex)
			end
			HV.SelectedCustomColor = nil
			MESSAGEMAN:Broadcast("CustomColorChanged", { Category = category, Element = element, Color = savedHex })
			if isAccentEdit then
				local screen = SCREENMAN:GetTopScreen()
				screen:SetNextScreenName("ScreenColorTheme")
				screen:StartTransitioningScreen("SM_GoToNextScreen")
			else
				SCREENMAN:GetTopScreen():Cancel()
			end
		else
			handleTextUpdate()
		end
	end
end

-- Root ActorFrame
local t = Def.ActorFrame {
	Name = "ColorEditRoot",
	OnCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(inputeater)
		applyHSV()
		if HVCustomColors and HVCustomColors.IsSyncToAccentEnabled then
			syncAccentEnabled = HVCustomColors.IsSyncToAccentEnabled(category, element)
		end
		if isSyncAccentDisabled() then
			syncAccentEnabled = false
		end
		if syncAccentEnabled then
			syncToAccentColor()
		end
		MESSAGEMAN:Broadcast("SyncAccentToggleChanged", { Enabled = syncAccentEnabled })
		self:SetUpdateFunction(function()
			if mouseLeftDown or INPUTFILTER:IsBeingPressed("DeviceButton_left mouse button") then
				local mx = INPUTFILTER:GetMouseX()
				local my = INPUTFILTER:GetMouseY()
				local baseX = pickerLeftX
				local baseY = pickerTopY

				if mx >= baseX and mx <= baseX + saturationSliderWidth and
				   my >= baseY and my <= baseY + colorBoxHeight then
					aboutToSave = true
					updateSaturation((my - baseY) / colorBoxHeight)
				elseif mx >= baseX + saturationSliderWidth and mx <= baseX + saturationSliderWidth + colorBoxHeight and
				       my >= baseY and my <= baseY + colorBoxHeight then
					aboutToSave = true
					updateColor((mx - (baseX + saturationSliderWidth)) / colorBoxHeight, (my - baseY) / colorBoxHeight)
				end
			end
		end)
	end,
	ThemePrefChangedMessageCommand = function(self, params)
		if params and params.Name == "HV_AccentColor" and syncAccentEnabled then
			syncToAccentColor()
		end
	end,
	CustomColorSyncChangedMessageCommand = function(self, params)
		if params and params.Category == category and params.Element == element then
			syncAccentEnabled = params.Enabled and true or false
			MESSAGEMAN:Broadcast("SyncAccentToggleChanged", { Enabled = syncAccentEnabled })
		end
	end,
}

-- =========================================================================
-- 1. TOP HEADER & BREADCRUMB BAR (Matching Theme Options)
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "Header",
	-- Brand / Kicker
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX, headerTop):halign(0):zoom(0.3)
				:diffuse(getAccent()):diffusealpha(0.85)
			self:settext("HOLOGRAPHIC VOID  //  HSV PALETTE PICKER")
		end,
	},
	-- Screen Title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX, headerTop + 16):halign(0):zoom(0.68):diffuse(color("1,1,1,1"))
			self:settext("EDIT COLOR")
		end,
	},
	-- Screen Subtitle
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX + 170, headerTop + 19):halign(0):zoom(0.34)
				:diffuse(color("0.65,0.68,0.74,0.85"))
			local catName = HVCustomColors.GetCategoryDisplayName(category)
			self:settext(string.format("%s  //  %s", catName:upper(), tostring(element):upper()))
		end,
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
-- 2. CENTER GLASS CARD
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "CenterCard",
	InitCommand = function(self) self:xy(cardX, cardY) end,
	-- Glass Backing
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(cardW, cardH):diffuse(color("0.04,0.04,0.05,0.92"))
		end,
	},
	-- Border Outline
	Def.ActorFrame {
		makePanelBorder(cardW, cardH, color("0.16,0.18,0.22,0.8")),
	},
	-- Corner Accent Brackets
	Def.ActorFrame {
		makeCornerBrackets(cardW, cardH, 8, 1.5),
	},
}

-- Card Header Banner
t[#t + 1] = Def.ActorFrame {
	Name = "CardHeaderBanner",
	InitCommand = function(self) self:xy(cardX, cardY - cardH / 2 + 14) end,
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(cardW - 4, 28):diffuse(color("0.07,0.07,0.09,0.95"))
		end,
	},
	Def.Quad {
		InitCommand = function(self)
			self:y(14):zoomto(cardW - 4, 1):diffuse(color("0.18,0.20,0.24,0.8"))
		end,
	},
	-- Keep the two upper card brackets visible over the banner.
	Def.Quad {
		InitCommand = function(self)
			self:xy(-(cardW - 4) / 2 + 4, -10):zoomto(8, 1.5)
				:diffuse(getAccent()):diffusealpha(0.85)
		end,
	},
	Def.Quad {
		InitCommand = function(self)
			self:xy(-(cardW - 4) / 2 + 0.75, -6):zoomto(1.5, 8)
				:diffuse(getAccent()):diffusealpha(0.85)
		end,
	},
	Def.Quad {
		InitCommand = function(self)
			self:xy((cardW - 4) / 2 - 4, -10):zoomto(8, 1.5)
				:diffuse(getAccent()):diffusealpha(0.85)
		end,
	},
	Def.Quad {
		InitCommand = function(self)
			self:xy((cardW - 4) / 2 - 0.75, -6):zoomto(1.5, 8)
				:diffuse(getAccent()):diffusealpha(0.85)
		end,
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(-cardW / 2 + 16):halign(0):zoom(0.3)
				:diffuse(getAccent()):diffusealpha(0.85)
			self:settext("// SELECT COLOR")
		end,
	},
}

-- =========================================================================
-- 3. COLOR PICKER EQUIPMENT & CONTROLS
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "SyncAccentButton",
	InitCommand = function(self)
		self:xy(syncBtnX, syncBtnY):visible(not isAccentEdit)
	end,
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(syncBtnW, syncBtnH):diffuse(color("0.08,0.09,0.12,0.95"))
			:diffusealpha(isSyncAccentDisabled() and 0.45 or 0.95)
		end,
		SyncAccentToggleChangedMessageCommand = function(self, params)
			local enabled = params and params.Enabled
			self:stoptweening():linear(0.1):diffuse(enabled and getAccent() or color("0.08,0.09,0.12,0.95"))
				:diffusealpha(enabled and 0.28 or 0.95)
		end,
	},
	Def.ActorFrame {
		makePanelBorder(syncBtnW, syncBtnH, color("0.18,0.20,0.24,0.8")),
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):x(-syncBtnW / 2 + 1.5):zoomto(3, syncBtnH):diffuse(getAccent()):diffusealpha(0.85)
		end,
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.3):diffuse(isSyncAccentDisabled() and color("0.45,0.47,0.50,1") or color("0.85,0.88,0.92,1"))
				:settext(isSyncAccentDisabled() and "Sync to Accent: N/A" or "Sync to Accent: OFF")
		end,
		SyncAccentToggleChangedMessageCommand = function(self, params)
			local enabled = params and params.Enabled
			self:settext(enabled and "Sync to Accent: ON" or "Sync to Accent: OFF")
			self:stoptweening():linear(0.1):diffuse(enabled and getAccent() or color("0.85,0.88,0.92,1"))
		end,
	}
}

-- Color Picker Box Frame
t[#t + 1] = Def.ActorFrame {
	Name = "ColorPickEquipment",
	InitCommand = function(self) self:xy(pickerLeftX, pickerTopY) end,

	-- Saturation Slider Backing Quad
	Def.Quad {
		Name = "SaturationSlider",
		InitCommand = function(self)
			self:zoomto(saturationSliderWidth, colorBoxHeight)
			self:valign(0):halign(0)
			self:diffuse(color("0.16,0.18,0.22,0.9"))
		end
	},

	-- Saturation Slider Position Indicator Line
	Def.Quad {
		Name = "SaturationSliderPos",
		InitCommand = function(self)
			self:diffuse(getAccent())
			self:zoomto(saturationSliderWidth, 2)
			self:xy(0, 0)
			self:valign(0):halign(0)
			saturationSliderPos = self
		end,
	},

	-- HSV Image
	Def.Sprite {
		Name = "HSVImage",
		Texture = THEME:GetPathG("", "color_hsv"),
		InitCommand = function(self)
			self:zoomto(colorBoxHeight, colorBoxHeight)
			self:x(saturationSliderWidth)
			self:valign(0):halign(0)
			if not self:GetTexture() then self:visible(false) end
		end,
	},

	-- Saturation Overlay
	Def.Sprite {
		Name = "SaturationOverlay",
		Texture = THEME:GetPathG("", "color_sat_overlay"),
		InitCommand = function(self)
			self:zoomto(colorBoxHeight, colorBoxHeight)
			self:x(saturationSliderWidth)
			self:diffuse(color("#FFFFFF")):diffusealpha(0.0)
			self:valign(0):halign(0)
			if not self:GetTexture() then self:visible(false) end
			saturationOverlay = self
		end,
	},

	-- Border around color box
	Def.ActorFrame {
		InitCommand = function(self) self:xy(saturationSliderWidth + colorBoxHeight / 2, colorBoxHeight / 2) end,
		makePanelBorder(colorBoxHeight, colorBoxHeight, color("0.18,0.20,0.24,0.8")),
	},

	-- Color Picker Crosshair
	Def.Sprite {
		Name = "ColorPickPosition",
		Texture = THEME:GetPathG("", "_thick circle"),
		InitCommand = function(self)
			self:diffuse(color("#FFFFFF")):diffusealpha(0.9)
			self:zoomto(8, 8)
			self:x(saturationSliderWidth)
			colorPickPosition = self
		end,
	},

	-- Saturation Label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:valign(1):xy(saturationSliderWidth / 2, -6):zoom(0.26):diffuse(color("0.65,0.68,0.74,1"))
			self:settext("SAT")
		end
	},
}

-- Manual Hex Entry & Status Area (Right side inside center card)
local entryX = pickerLeftX + saturationSliderWidth + colorBoxHeight + 36
local entryY = pickerTopY + 54

t[#t + 1] = Def.ActorFrame {
	Name = "ManualEntryArea",
	InitCommand = function(self) self:xy(entryX, entryY) end,

	-- Hex Code Section Label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.32):diffuse(getAccent())
			self:settext("HEXADECIMAL COLOR")
		end
	},

	-- Hex Input Box Frame
	Def.ActorFrame {
		InitCommand = function(self) self:xy(90, 36) end,
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(180, 34):diffuse(color("0.06,0.07,0.09,0.95"))
			end,
		},
		makePanelBorder(180, 34, color("0.18,0.20,0.24,0.8")),
		Def.Quad {
			InitCommand = function(self)
				self:x(-90 + 1.5):zoomto(3, 34):diffuse(getAccent()):diffusealpha(0.85)
			end,
		},
	},

	-- Hex Input Text
	LoadFont("Common Normal") .. {
		Name = "InputText",
		InitCommand = function(self)
			self:xy(12, 36):halign(0):valign(0.5):zoom(0.54):diffuse(color("1,1,1,1"))
			self:settext("#")
		end,
		UpdateStringDisplayMessageCommand = function(self)
			self:settext(hexEntryString)
			self:GetParent():GetChild("CursorPosition"):playcommand("UpdateCursorDisplay")
		end,
		ClickedNewColorMessageCommand = function(self)
			self:playcommand("UpdateStringDisplay")
		end
	},

	-- Hex Input Cursor Underline
	Def.Quad {
		Name = "CursorPosition",
		InitCommand = function(self)
			self:x(12):halign(0):valign(0):zoomto(14, 2):y(48)
			self:diffuse(getAccent())
		end,
		UpdateCursorDisplayCommand = function(self)
			local pos = 12
			local txt = self:GetParent():GetChild("InputText")
			if textCursorPos ~= #hexEntryString + 1 then
				local glyphWidth = getWidthOfChar(txt, textCursorPos) + 3
				self:zoomto(glyphWidth, 2)
				pos = getXPositionInText(txt, textCursorPos)
			else
				pos = getXPositionInText(txt, textCursorPos - 1) + getWidthOfChar(txt, textCursorPos - 1)
				if #hexEntryString <= 1 then
					self:zoomto(10, 2)
				else
					self:zoomto(14, 2)
				end
			end
			self:finishtweening():linear(0.05):x(pos + 12)
		end
	},

	-- "READY TO SAVE" Badge
	Def.ActorFrame {
		Name = "SavingBadge",
		InitCommand = function(self) self:xy(90, 78) end,
		Def.Quad {
			Name = "SavingBg",
			InitCommand = function(self)
				self:zoomto(180, 24):diffuse(getAccent()):diffusealpha(0.18):visible(false)
			end,
			ClickedNewColorMessageCommand = function(self) self:visible(aboutToSave) end,
			UpdateStringDisplayMessageCommand = function(self) self:visible(aboutToSave) end,
		},
		LoadFont("Common Normal") .. {
			Name = "SavingIndicator",
			InitCommand = function(self)
				self:zoom(0.32):diffuse(getAccent()):settext("Press Enter to Save")
				self:visible(false)
			end,
			ClickedNewColorMessageCommand = function(self) self:visible(aboutToSave) end,
			UpdateStringDisplayMessageCommand = function(self) self:visible(aboutToSave) end,
		}
	},

	-- Instructions List
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(0, 116):halign(0):valign(0):zoom(0.26):diffuse(color("0.65,0.68,0.74,1"))
			self:settext("Type hex characters (0-9, A-F) & press Enter to save\n Ctrl + Delete: Reset element to theme default\n Alt + Delete: Revert element to saved color\n Tab / Select: Toggle accent synchronization")
		end
	}
}

-- Saved vs New Color Preview Swatches
local compareX = cardX + cardW / 2 - 130
local compareY = pickerTopY + 54
local compareGap = 46

t[#t + 1] = Def.ActorFrame {
	Name = "SavedColorPreview",
	InitCommand = function(self) self:xy(compareX - compareGap, compareY) end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0.5):valign(0):zoom(0.30):diffuse(color("0.65,0.68,0.74,1"))
			self:settext("ORIGINAL VALUE")
		end
	},

	Def.ActorFrame {
		InitCommand = function(self) self:y(54) end,
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(68, 68):diffuse(color("0.18,0.20,0.24,0.9"))
			end,
		},
		Def.Quad {
			Name = "OriginalSwatch",
			InitCommand = function(self)
				self:zoomto(64, 64):diffuse(color(themeColor))
			end,
			CustomColorChangedMessageCommand = function(self, params)
				if params and params.Color and params.Category == category and params.Element == element then
					self:stoptweening():linear(0.1):diffuse(color(params.Color))
				end
			end
		},
	},

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(98):halign(0.5):zoom(0.28):diffuse(color("0.65,0.68,0.74,1"))
			self:settext(themeColor:upper())
		end,
		CustomColorChangedMessageCommand = function(self, params)
			if params and params.Color and params.Category == category and params.Element == element then
				self:settext(params.Color:upper())
			end
		end
	}
}

t[#t + 1] = Def.ActorFrame {
	Name = "NewColorPreview",
	InitCommand = function(self) self:xy(compareX + compareGap, compareY) end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0.5):valign(0):zoom(0.30):diffuse(color("0.65,0.68,0.74,1"))
			self:settext("NEW VALUE")
		end
	},

	Def.ActorFrame {
		InitCommand = function(self) self:y(54) end,
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(68, 68):diffuse(color("0.18,0.20,0.24,0.9"))
			end,
		},
		Def.Quad {
			Name = "NewSwatch",
			InitCommand = function(self)
				self:zoomto(64, 64):diffuse(currentColor)
			end,
			ClickedNewColorMessageCommand = function(self)
				self:stoptweening():linear(0.08):diffuse(currentColor)
			end,
		},
	},

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(98):halign(0.5):zoom(0.28):diffuse(color("0.65,0.68,0.74,1"))
			self:settext("#" .. ColorToHex(currentColor))
		end,
		ClickedNewColorMessageCommand = function(self)
			self:settext("#" .. ColorToHex(currentColor))
		end,
	},
}

-- RGBA Readout at Bottom Left of Card
t[#t + 1] = Def.ActorFrame {
	Name = "ColorInformation",
	InitCommand = function(self) self:xy(pickerLeftX, cardY + cardH / 2 - 32) end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):zoom(0.30):diffuse(color("0.65,0.68,0.74,1")):settext("RGBA CHANNELS:")
		end
	},
	LoadFont("Common Normal") .. {
		Name = "SelectedRGB",
		InitCommand = function(self)
			self:halign(0):x(105):zoom(0.34):diffuse(color("1,1,1,1"))
		end,
		ClickedNewColorMessageCommand = function(self)
			local r = math.floor(currentColor[1] * 255)
			local g = math.floor(currentColor[2] * 255)
			local b = math.floor(currentColor[3] * 255)
			local a = math.floor((currentColor[4] or 1) * 255)
			self:settextf("%d, %d, %d, %d", r, g, b, a)
		end
	},
}

-- =========================================================================
-- 4. NAVIGATION FOOTER BAR (Matching Theme Options)
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
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
}

-- =========================================================================
-- 5. MOUSE CURSOR
-- =========================================================================
t[#t + 1] = LoadActor("../_cursor")

return t
