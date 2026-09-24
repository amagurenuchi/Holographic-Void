--- Holographic Void: ScreenHVCustomColors Overlay
-- Category-element color customization screen (similar to 'Til Death's color config)
-- Allows users to select a category, then an element, and edit its custom color.

local curLevel = 1
local cursorIndex = {1, 1}
local selected = {"", ""}
local currentItems = {{}, {}}

local maxItems = 18
local categoryX = 60
local elementX = 240
local colorX = 480
local startY = 80
local spacing = 20
local scale = 0.65

local categories = HVCustomColors.GetCategories()

local function exportColors()
	local encoded = HVCustomColors.ExportBase64()
	local ok, result = false, false
	if Arch and Arch.setClipboard then
		-- Etterna builds differ: newer builds accept a clipboard type tag.
		ok, result = pcall(Arch.setClipboard, encoded, "text")
		if not ok or result == false then ok, result = pcall(Arch.setClipboard, encoded) end
	end
	-- Windows Etterna builds expose clipboard reading but not always writing.
	if not ok or result == false then
		local pipe = io and io.popen and io.popen("clip.exe", "w")
		if pipe then
			local wrote = pcall(function() pipe:write(encoded) pipe:close() end)
			ok, result = wrote, wrote
		end
	end
	if ok and result ~= false then
		SCREENMAN:SystemMessage("Color configuration copied to clipboard")
	else
		Trace("Holographic Void color configuration export: " .. encoded)
		SCREENMAN:SystemMessage("Clipboard export failed\n\n" .. encoded)
	end
end

local function applyImportedColors(encoded)
	local imported, message = HVCustomColors.ImportBase64(encoded)
	SCREENMAN:SystemMessage(imported and "Color configuration imported" or message)
	if imported then MESSAGEMAN:Broadcast("RowChanged", { level = 2 }) end
end

local function importColors()
	local initialText = ""
	if Arch and Arch.getClipboard then
		local ok, clipboard = pcall(Arch.getClipboard)
		if ok and clipboard then initialText = clipboard end
	end
	easyInputStringOKCancel("Paste color configuration (base64):", 12000, false, applyImportedColors, nil, initialText)
end

local function buttonHit(x, y, width, height)
	local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
	return mx >= x - width / 2 and mx <= x + width / 2 and my >= y - height / 2 and my <= y + height / 2
end

local function findIndex(tbl, value)
	for i, v in ipairs(tbl) do
		if v == value then return i end
	end
	return nil
end

local function getDisplayNameForElement(category, element)
	local strings = {
		grades = {
			AAAAA = "AAAAA", ["AAAA:"] = "AAAA:", ["AAAA."] = "AAAA.", AAAA = "AAAA",
			["AAA:"] = "AAA:", ["AAA."] = "AAA.", AAA = "AAA",
			["AA:"] = "AA:", ["AA."] = "AA.", AA = "AA",
			["A:"] = "A:", ["A."] = "A.", A = "A",
			B = "B", C = "C", D = "D", F = "F", None = "None",
		},
		judgment = {
			W1 = "MARV (W1)", W2 = "PERF (W2)", W3 = "GREAT (W3)",
			W4 = "GOOD (W4)", W5 = "BAD (W5)", Miss = "MISS",
			Held = "OK (Held)", LetGo = "NG (LetGo)",
		},
		difficulty = {
			Beginner = "Beginner", Easy = "Easy", Medium = "Medium",
			Hard = "Hard", Challenge = "Challenge", Edit = "Edit",
		},
		clearType = {
			MFC = "MFC", WF = "WF", SDP = "SDP", PFC = "PFC", BF = "BF",
			SDG = "SDG", FC = "FC", MF = "MF", SDCB = "SDCB",
			Clear = "Clear", Failed = "Failed", Invalid = "Invalid",
			NoPlay = "NoPlay", None = "None", SoftInvalid = "SoftInvalid",
		},
		goalTracker = {
			Positive = "Positive (Ahead)", Negative = "Negative (Behind)",
		},
		lifeBar = {
			L1 = "Life Level 1", L2 = "Life Level 2", L3 = "Life Level 3", L4 = "Life Level 4",
			L5 = "Life Level 5", L6 = "Life Level 6", L7 = "Life Level 7",
			Danger = "Danger",
		},
		radar = {
			Power = "Power", Chaos = "Chaos", Hell = "Hell",
			Mach = "Mach", Freeze = "Freeze", Earth = "Earth",
		},
	}
	return strings[category] and strings[category][element] or element
end

-- Generate category list
local function generateCategoryList()
	local visibleItems = {}
	currentItems[1] = {}
	for _, cat in ipairs(categories) do
		table.insert(currentItems[1], cat)
	end
	for i = 1, math.min(#currentItems[1], maxItems) do
		visibleItems[i] = currentItems[1][i]
	end
	selected[1] = currentItems[1][1]

	local t = Def.ActorFrame {
		RowChangedMessageCommand = function(self, params)
			if params.level == 1 then
				selected[1] = currentItems[1][cursorIndex[1]]
				MESSAGEMAN:Broadcast("CategoryChanged", { category = selected[1] })
			end
		end
	}

	for k, v in ipairs(visibleItems) do
		t[#t + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(categoryX, startY + (k-1) * spacing)
				self:settext(HVCustomColors.GetCategoryDisplayName(visibleItems[k]))
				self:zoom(scale)
				self:halign(0)
				self:queuecommand("UpdateColor")
			end,
			RowChangedMessageCommand = function(self, params)
				if params.level == 1 then
					self:queuecommand("UpdateColor")
				end
			end,
			CategoryChangedMessageCommand = function(self, params)
				if curLevel == 1 then
					self:diffusealpha(1)
				else
					self:diffusealpha(0.5)
				end
			end,
			UpdateColorCommand = function(self)
				if visibleItems[k] == currentItems[1][cursorIndex[1]] then
					self:diffuse(HVColor.Accent)
				else
					self:diffuse(color("#FFFFFF"))
				end
			end
		}
	end

	return t
end

-- Generate element list based on selected category
local function generateElementList()
	local t = Def.ActorFrame {
		CategoryChangedMessageCommand = function(self, params)
			currentItems[2] = {}
			local elements = HVCustomColors.GetElements(params.category)
			for _, elem in ipairs(elements) do
				table.insert(currentItems[2], elem)
			end
			cursorIndex[2] = 1
			selected[2] = currentItems[2][1] or ""
			self:playcommand("RefreshElements")
		end,
		RefreshElementsMessageCommand = function(self)
			for i = 1, maxItems do
				local nameActor = self:GetChild("ElementName_" .. i)
				local colorActor = self:GetChild("ElementColor_" .. i)
				if nameActor then nameActor:playcommand("Set") end
				if colorActor then colorActor:playcommand("Set") end
			end
		end
	}

	for i = 1, maxItems do
		-- Element name
		t[#t + 1] = LoadFont("Common Normal") .. {
			Name = "ElementName_" .. i,
			InitCommand = function(self)
				self:xy(elementX, startY + (i-1) * spacing)
				self:zoom(scale)
				self:halign(0)
				self:playcommand("Set")
			end,
			SetCommand = function(self)
				if currentItems[2] and currentItems[2][i] then
					self:visible(true)
					local category = selected[1] or categories[1]
					local displayName = getDisplayNameForElement(category, currentItems[2][i])
					self:settext(displayName)
					if i == cursorIndex[2] and curLevel == 2 then
						self:diffuse(HVColor.Accent)
					else
						self:diffuse(color("#FFFFFF"))
					end
					if curLevel == 2 then
						self:diffusealpha(1)
					else
						self:diffusealpha(0.5)
					end
				else
					self:visible(false)
				end
			end,
			RowChangedMessageCommand = function(self, params)
				if params.level <= 2 then
					self:playcommand("Set")
				end
			end,
		}

		-- Element color value
		t[#t + 1] = LoadFont("Common Normal") .. {
			Name = "ElementColor_" .. i,
			InitCommand = function(self)
				self:xy(colorX, startY + (i-1) * spacing)
				self:zoom(scale)
				self:halign(0)
				self:playcommand("Set")
			end,
			SetCommand = function(self)
				if currentItems[2] and currentItems[2][i] then
					self:visible(true)
					local category = selected[1] or categories[1]
					local hex = HVCustomColors.GetColor(category, currentItems[2][i])
					self:settext(hex:upper())
					if i == cursorIndex[2] and curLevel == 2 then
						self:diffuse(color(hex))
					else
						self:diffuse(color("#888888"))
					end
					if curLevel == 2 then
						self:diffusealpha(1)
					else
						self:diffusealpha(0.5)
					end
				else
					self:visible(false)
				end
			end,
			RowChangedMessageCommand = function(self, params)
				if params.level <= 2 then
					self:playcommand("Set")
				end
			end,
			CustomColorChangedMessageCommand = function(self, params)
				if params and currentItems[2] and currentItems[2][i] == params.Element then
					self:playcommand("Set")
				end
			end,
		}
	end

	return t
end

-- Color preview panel
local function generateColorPreview()
	local previewSize = 80
	local previewX = SCREEN_RIGHT - 120
	local previewY = SCREEN_CENTER_Y - 40

	return Def.ActorFrame {
		InitCommand = function(self) self:xy(previewX, previewY) end,

		Def.Quad {
			Name = "PreviewBox",
			InitCommand = function(self)
				self:zoomto(previewSize, previewSize)
				self:diffuse(color("#5ABAFF"))
			end,
			RowChangedMessageCommand = function(self, params)
				if params.level <= 2 then
					local category = selected[1] or categories[1]
					local element = currentItems[2] and currentItems[2][cursorIndex[2]]
					if element then
						local hex = HVCustomColors.GetColor(category, element)
						self:stoptweening():linear(0.1):diffuse(color(hex))
					end
				end
			end,
			CustomColorChangedMessageCommand = function(self, params)
				if params and params.Color and selected[1] == params.Category and selected[2] == params.Element then
					self:stoptweening():linear(0.1):diffuse(color(params.Color))
				end
			end,
		},

		LoadFont("Common Normal") .. {
			Name = "PreviewLabel",
			InitCommand = function(self)
				self:y(previewSize/2 + 20)
				self:zoom(0.3)
				self:diffuse(color("#AAAAAA"))
				self:settext("Current Color")
			end,
		},

		LoadFont("Common Normal") .. {
			Name = "PreviewHex",
			InitCommand = function(self)
				self:y(previewSize/2 + 36)
				self:zoom(0.35)
				self:diffuse(HVColor.Accent)
				self:settext("#5ABAFF")
			end,
			RowChangedMessageCommand = function(self, params)
				if params.level <= 2 then
					local category = selected[1] or categories[1]
					local element = currentItems[2] and currentItems[2][cursorIndex[2]]
					if element then
						local hex = HVCustomColors.GetColor(category, element)
						self:settext(hex:upper())
					end
				end
			end,
			CustomColorChangedMessageCommand = function(self, params)
				if params and params.Color and selected[1] == params.Category and selected[2] == params.Element then
					self:settext(params.Color:upper())
				end
			end,
		},
	}
end

-- Main actor
local t = Def.ActorFrame {
	OnCommand = function(self)
		curLevel = 1
		cursorIndex[1] = 1
		cursorIndex[2] = 1

		local requested = HV.SelectedCustomColor
		local requestedCategory = (requested and requested[1]) or "grades"
		local requestedElement = requested and requested[2]

		local requestedCategoryIndex = findIndex(categories, requestedCategory)
		if requestedCategoryIndex then
			cursorIndex[1] = requestedCategoryIndex
		end
		selected[1] = categories[cursorIndex[1]] or categories[1]

		currentItems[2] = {}
		local elements = HVCustomColors.GetElements(selected[1])
		for _, elem in ipairs(elements) do
			table.insert(currentItems[2], elem)
		end

		if requestedElement then
			local requestedElementIndex = findIndex(currentItems[2], requestedElement)
			if requestedElementIndex then
				cursorIndex[2] = requestedElementIndex
			end
		end
		selected[2] = currentItems[2][cursorIndex[2]] or ""

		HV.SelectedCustomColor = nil
		MESSAGEMAN:Broadcast("CategoryChanged", { category = selected[1] })
		MESSAGEMAN:Broadcast("RowChanged", { level = 1 })
		MESSAGEMAN:Broadcast("RowChanged", { level = 2 })

		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type ~= "InputEventType_FirstPress" then return end
			if event.DeviceInput and event.DeviceInput.button == "DeviceButton_left mouse button" then
				if buttonHit(SCREEN_RIGHT - 120, SCREEN_BOTTOM - 48, 120, 24) then exportColors() return true end
				if buttonHit(SCREEN_RIGHT - 250, SCREEN_BOTTOM - 48, 120, 24) then importColors() return true end
			end

			if event.button == "MenuUp" then
				if curLevel == 1 then
					cursorIndex[curLevel] = math.max(1, cursorIndex[curLevel] - 1)
					cursorIndex[2] = 1
				elseif curLevel == 2 then
					cursorIndex[curLevel] = math.max(1, cursorIndex[curLevel] - 1)
					selected[2] = currentItems[2][cursorIndex[2]]
				end
				MESSAGEMAN:Broadcast("RowChanged", { level = curLevel })

			elseif event.button == "MenuDown" then
				if curLevel == 1 then
					cursorIndex[curLevel] = math.min(#categories, cursorIndex[curLevel] + 1)
					cursorIndex[2] = 1
				elseif curLevel == 2 then
					cursorIndex[curLevel] = math.min(#currentItems[2], cursorIndex[curLevel] + 1)
					selected[2] = currentItems[2][cursorIndex[2]]
				end
				MESSAGEMAN:Broadcast("RowChanged", { level = curLevel })

			elseif event.button == "MenuLeft" then
				curLevel = math.max(1, curLevel - 1)
				MESSAGEMAN:Broadcast("CategoryChanged", { category = selected[1] })

			elseif event.button == "MenuRight" then
				curLevel = math.min(2, curLevel + 1)
				MESSAGEMAN:Broadcast("CategoryChanged", { category = selected[1] })

			elseif event.button == "Start" then
				if curLevel == 1 then
					curLevel = 2
					MESSAGEMAN:Broadcast("CategoryChanged", { category = selected[1] })
				elseif curLevel == 2 and selected[2] and selected[2] ~= "" then
					-- Open color editor
					HV.SelectedCustomColor = { selected[1], selected[2] }
					SCREENMAN:AddNewScreenToTop("ScreenHVColorEdit")
				end

			elseif event.button == "Back" then
				SCREENMAN:GetTopScreen():Cancel()
			elseif event.DeviceInput and event.DeviceInput.button == "DeviceButton_e" then
				exportColors()
			elseif event.DeviceInput and event.DeviceInput.button == "DeviceButton_i" then
				importColors()
			end
		end)
	end
}

t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			:diffuse(color("0,0,0,0.9"))
	end
}

-- Title
t[#t + 1] = LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(10, 32):halign(0):valign(1):zoom(0.55):diffuse(HVColor.Accent)
		self:settext("CUSTOM COLORS")
	end
}

-- Column headers
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(categoryX, startY - 20):halign(0):valign(1):zoom(0.55):diffuse(color("#888888"))
		self:settext("Category")
	end
}
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(elementX, startY - 20):halign(0):valign(1):zoom(0.55):diffuse(color("#888888"))
		self:settext("Element")
	end
}
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(colorX, startY - 20):halign(0):valign(1):zoom(0.55):diffuse(color("#888888"))
		self:settext("Color")
	end
}

-- Category list
t[#t + 1] = generateCategoryList()

-- Element list
t[#t + 1] = generateElementList()

-- Color preview panel
t[#t + 1] = generateColorPreview()

-- Clipboard actions
local function actionButton(name, label, x)
	return Def.ActorFrame {
		InitCommand = function(self) self:xy(x, SCREEN_BOTTOM - 48) end,
		Def.Quad {
			InitCommand = function(self) self:zoomto(120, 24):diffuse(HVColor.Accent):diffusealpha(0.16) end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.35):diffuse(HVColor.Accent):settext(label) end,
		},
	}
end

t[#t + 1] = actionButton("ExportButton", "EXPORT", SCREEN_RIGHT - 120)
t[#t + 1] = actionButton("ImportButton", "IMPORT", SCREEN_RIGHT - 250)

-- Footer help text
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 20):zoom(0.28)
		self:diffuse(color("#666666"))
		self:settext("Up/Down: Navigate  ·  Left/Right: Switch Columns  ·  Enter: Edit  ·  E: Export  ·  I: Import  ·  Esc: Back")
	end
}

-- Mouse cursor
t[#t + 1] = LoadActor("../_cursor")

return t
