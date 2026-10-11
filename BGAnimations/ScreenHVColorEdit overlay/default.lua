--- Holographic Void: ScreenHVColorEdit Overlay
-- HSV color picker for custom element colors
-- Based on 'Til Death's color editor

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
local syncBtnX = SCREEN_WIDTH / 2 + 200
local syncBtnY = SCREEN_HEIGHT / 8 + 38
local syncBtnW = 170
local syncBtnH = 26

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

-- Text/cursor helpers
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

local function localMousePos(self, mx, my)
	local parent = self:GetParent()
	local rz = 0
	while parent do
		rz = rz + parent:GetRotationZ()
		parent = parent:GetParent()
	end
	rz = math.rad(-rz)
	local x = mx - self:GetTrueX()
	local y = my - self:GetTrueY()
	return x * math.cos(rz) - y * math.sin(rz), x * math.sin(rz) + y * math.cos(rz)
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

		local r, g, b = finalcolor[1], finalcolor[2], finalcolor[3]
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
			toggleSyncAccentEnabled()
			return true
		end
	end

	if event.char and event.char:match('[%x]') then
		handleHexEntry(event.char)
	elseif deviceButton == "DeviceButton_delete" then
		if INPUTFILTER:IsControlPressed() then
			-- Reset to default
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
			-- Reset to saved
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
		SCREENMAN:GetTopScreen():Cancel()
	elseif gameButton == "Select" or deviceButton == "DeviceButton_tab" then
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
			SCREENMAN:GetTopScreen():Cancel()
		else
			handleTextUpdate()
		end
	end
end

-- Main actor
t = Def.ActorFrame {
	OnCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(inputeater)
		applyHSV()
		if HVCustomColors and HVCustomColors.IsSyncToAccentEnabled then
			syncAccentEnabled = HVCustomColors.IsSyncToAccentEnabled(category, element)
		end
		if syncAccentEnabled then
			syncToAccentColor()
		end
		MESSAGEMAN:Broadcast("SyncAccentToggleChanged", { Enabled = syncAccentEnabled })
		self:SetUpdateFunction(function()
			if mouseLeftDown or INPUTFILTER:IsBeingPressed("DeviceButton_left mouse button") then
				local mx = INPUTFILTER:GetMouseX()
				local my = INPUTFILTER:GetMouseY()
				local baseX = SCREEN_WIDTH / 12
				local baseY = SCREEN_HEIGHT / 8

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

	-- Background
	Def.Quad {
		Name = "MainBG",
		InitCommand = function(self)
			self:xy(0, 0):halign(0):valign(0):zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			self:diffuse(color("#000000")):diffusealpha(0.95)
		end
	}
}

t[#t + 1] = Def.ActorFrame {
	Name = "SyncAccentButton",
	InitCommand = function(self)
		self:xy(syncBtnX, syncBtnY)
	end,
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(syncBtnW, syncBtnH):diffuse(color("0.08,0.08,0.08,0.95"))
		end,
		SyncAccentToggleChangedMessageCommand = function(self, params)
			local enabled = params and params.Enabled
			if enabled then
				self:stoptweening():linear(0.1):diffuse(HVColor.Accent):diffusealpha(0.28)
			else
				self:stoptweening():linear(0.1):diffuse(color("0.08,0.08,0.08,0.95"))
			end
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if params and params.Name == "HV_AccentColor" and syncAccentEnabled then
				self:stoptweening():linear(0.1):diffuse(HVColor.Accent):diffusealpha(0.28)
			end
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(syncBtnW, 1):y(syncBtnH/2 - 1):diffuse(HVColor.Accent):diffusealpha(0.45)
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if params and params.Name == "HV_AccentColor" then
				self:stoptweening():linear(0.1):diffuse(HVColor.Accent):diffusealpha(0.45)
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.3):diffuse(color("0.8,0.8,0.8,1"))
			self:settext("Sync to Accent: OFF")
		end,
		SyncAccentToggleChangedMessageCommand = function(self, params)
			local enabled = params and params.Enabled
			self:settext(enabled and "Sync to Accent: ON" or "Sync to Accent: OFF")
			self:stoptweening():linear(0.1):diffuse(enabled and HVColor.Accent or color("0.8,0.8,0.8,1"))
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if params and params.Name == "HV_AccentColor" and syncAccentEnabled then
				self:stoptweening():linear(0.1):diffuse(HVColor.Accent)
			end
		end
	}
}

-- Title
t[#t + 1] = LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(10, 32):halign(0):valign(1):zoom(0.55):diffuse(HVColor.Accent)
		self:settext("EDIT COLOR")
	end
}

-- Element info
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(10, 60):halign(0):valign(0):zoom(0.4):diffuse(color("#AAAAAA"))
		local catName = HVCustomColors.GetCategoryDisplayName(category)
		self:settext(catName .. "  /  " .. element)
	end
}

-- Color Picker Area
t[#t + 1] = Def.ActorFrame {
	Name = "ColorPickEquipment",
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH / 12, SCREEN_HEIGHT / 8)
	end,

	-- HSV gradient image
	Def.Sprite {
		Name = "HSVImage",
		Texture = THEME:GetPathG("", "color_hsv"),
		InitCommand = function(self)
			self:zoomto(colorBoxHeight, colorBoxHeight)
			self:x(saturationSliderWidth)
			self:valign(0):halign(0)
			-- Create a simple gradient if texture not found
			if not self:GetTexture() then
				self:visible(false)
			end
		end,
		OnCommand = function(self)
			if not self:GetTexture() then
				-- Fallback: use a quad with rainbow shader or just colored quads
				self:visible(false)
			end
		end
	},

	-- Saturation overlay texture (more visible as saturation decreases)
	Def.Sprite {
		Name = "SaturationOverlay",
		Texture = THEME:GetPathG("", "color_sat_overlay"),
		InitCommand = function(self)
			self:zoomto(colorBoxHeight, colorBoxHeight)
			self:x(saturationSliderWidth)
			self:diffuse(color("#FFFFFF")):diffusealpha(0.0)
			self:valign(0):halign(0)
			if not self:GetTexture() then
				self:visible(false)
			end
			saturationOverlay = self
		end,
	},

	-- Saturation slider
	Def.Quad {
		Name = "SaturationSlider",
		InitCommand = function(self)
			self:zoomto(saturationSliderWidth, colorBoxHeight)
			self:valign(0):halign(0)
			self:diffuse(color("#555555"))
		end
	},

	-- Saturation slider position indicator
	Def.Quad {
		Name = "SaturationSliderPos",
		InitCommand = function(self)
			self:diffuse(HVColor.Accent)
			self:zoomto(saturationSliderWidth, 2)
			self:xy(0,0)
			self:valign(0):halign(0)
			saturationSliderPos = self
		end,
	},

	-- Color picker crosshair
	Def.Sprite {
		Name = "ColorPickPosition",
		Texture = THEME:GetPathG("", "_thick circle"),
		InitCommand = function(self)
			self:diffuse(color("#FFFFFF")):diffusealpha(0.8)
			self:zoomto(7,7)
			self:x(saturationSliderWidth)
			colorPickPosition = self
		end,
	},

	-- Labels
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:valign(1):xy(saturationSliderWidth/2, -5):zoom(0.25):diffuse(color("#888888"))
			self:settext("Sat")
		end
	},
}

-- Manual hex entry
t[#t + 1] = Def.ActorFrame {
	Name = "ManualEntryArea",
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH / 12 + saturationSliderWidth + 5 * colorBoxHeight / 4 + 20, SCREEN_HEIGHT / 8)
	end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.35):diffuse(color("#888888"))
			self:settext("Hex Code")
		end
	},

	LoadFont("Common Normal") .. {
		Name = "InputText",
		InitCommand = function(self)
			self:y(25):halign(0):valign(0):zoom(0.5):diffuse(color("#FFFFFF"))
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

	Def.Quad {
		Name = "CursorPosition",
		InitCommand = function(self)
			self:x(12):halign(0):valign(0):zoomto(14,2):y(45)
			self:diffuse(HVColor.Accent)
		end,
		UpdateCursorDisplayCommand = function(self)
			local pos = 12
			local txt = self:GetParent():GetChild("InputText")
			if textCursorPos ~= #hexEntryString + 1 then
				local glyphWidth = getWidthOfChar(txt, textCursorPos) + 3
				self:zoomto(glyphWidth, 2)
				pos = getXPositionInText(txt, textCursorPos)
			else
				pos = getXPositionInText(txt, textCursorPos-1) + getWidthOfChar(txt, textCursorPos-1)
				if #hexEntryString <= 1 then
					self:zoomto(10, 2)
				else
					self:zoomto(14, 2)
				end
			end
			self:finishtweening():linear(0.05):x(pos)
		end
	},

	LoadFont("Common Normal") .. {
		Name = "SavingIndicator",
		InitCommand = function(self)
			self:xy(-20, 60):halign(0):valign(0):zoom(0.4):diffuse(HVColor.Accent)
			self:settext("READY TO SAVE")
			self:visible(false)
		end,
		ClickedNewColorMessageCommand = function(self)
			self:visible(aboutToSave)
		end,
		UpdateStringDisplayMessageCommand = function(self)
			self:visible(aboutToSave)
		end
	},

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(135):halign(0):valign(0):zoom(0.25):diffuse(color("#666666"))
			self:maxwidth(400)
			self:settext("Type hex code and press Enter to save\nCtrl+Delete = Reset to default\nAlt+Delete = Reset to saved color\nTab/Select = Toggle accent sync")
		end
	}
}

-- Color info
t[#t + 1] = Def.ActorFrame {
	Name = "ColorInformation",
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH / 12, SCREEN_HEIGHT / 8 + colorBoxHeight + genericSpacing + 10)
	end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:valign(0):halign(0):zoom(0.35):diffuse(color("#888888"))
			self:settext("RGBA Values")
		end
	},

	LoadFont("Common Normal") .. {
		Name = "SelectedRGB",
		InitCommand = function(self)
			self:y(0):x(colorBoxHeight):valign(0):halign(1):zoom(0.4)
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

-- Original/Saved color preview
t[#t + 1] = Def.ActorFrame {
	Name = "SavedColorPreview",
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH / 2 + 50, SCREEN_HEIGHT / 8)
	end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.35):diffuse(color("#888888"))
			self:settext("Saved Color")
		end
	},

	Def.Quad {
		InitCommand = function(self)
			self:y(25):halign(0):valign(0):zoomto(60, 60)
			self:diffuse(color(themeColor))
		end,
		CustomColorChangedMessageCommand = function(self, params)
			if params and params.Color and params.Category == category and params.Element == element then
				self:stoptweening():linear(0.1):diffuse(color(params.Color))
			end
		end
	},

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(25+70):halign(0):valign(0):zoom(0.3):diffuse(color("#666666"))
			self:settext(themeColor:upper())
		end,
		CustomColorChangedMessageCommand = function(self, params)
			if params and params.Color and params.Category == category and params.Element == element then
				self:settext(params.Color:upper())
			end
		end
	}
}

-- Footer
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 20):zoom(0.28)
		self:diffuse(color("#666666"))
		self:settext("Arrows: Navigate hex  ·  Start/Enter: Save  ·  Esc: Cancel without saving")
	end
}

-- Mouse cursor
t[#t + 1] = LoadActor("../_cursor")

return t
