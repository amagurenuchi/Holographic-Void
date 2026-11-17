--- Holographic Void: ScreenHVCustomColors Overlay
-- Redesigned modern cyberpunk/holographic interface.
-- Category-element color customization screen (similar to 'Til Death's color config)
-- Allows users to select a category, then an element, and edit its custom color.
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

local function makeCornerBrackets(w, h, size, thickness)
	size = size or 8
	thickness = thickness or 1.5
	local halfW = w / 2
	local halfH = h / 2
	local function colorTick(self) self:diffuse(getAccent()):diffusealpha(0.85) end
	return Def.ActorFrame {
		Def.Quad { InitCommand = function(self) self:xy(-halfW + size / 2, -halfH + thickness / 2):zoomto(size, thickness); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(-halfW + thickness / 2, -halfH + size / 2):zoomto(thickness, size); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - size / 2, -halfH + thickness / 2):zoomto(size, thickness); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - thickness / 2, -halfH + size / 2):zoomto(thickness, size); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(-halfW + size / 2, halfH - thickness / 2):zoomto(size, thickness); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(-halfW + thickness / 2, halfH - size / 2):zoomto(thickness, size); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - size / 2, halfH - thickness / 2):zoomto(size, thickness); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - thickness / 2, halfH - size / 2):zoomto(thickness, size); colorTick(self) end,
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
-- GEOMETRY & LAYOUT CONSTANTS (Strictly bounded to prevent overflow)
-- =========================================================================
local marginX = 20
local gap = 16
local totalW = SCREEN_WIDTH - marginX * 2
local listW = math.floor(totalW * 0.58)
local panelW = totalW - gap - listW
local listX = marginX + listW / 2
local panelX = marginX + listW + gap + panelW / 2

local headerTop = 14
local headerLineY = 48

local panelTop = 60
local panelBottom = SCREEN_HEIGHT - 28
local panelH = panelBottom - panelTop
local panelCenterY = panelTop + panelH / 2

local catColW = math.floor(listW * 0.32)
local elemColW = math.floor(listW * 0.42)
local colorColW = listW - catColW - elemColW

local catColX = listX - listW / 2 + catColW / 2
local elemColX = listX - listW / 2 + catColW + elemColW / 2
local colorColX = listX + listW / 2 - colorColW / 2

local rowPitch = 20
local maxItems = 16
local rowsStartY = panelTop + 36

-- Right panel action button coordinates
local btnEditY = panelTop + 168
local btnExportY = panelTop + 208
local btnImportY = panelTop + 242
local btnResetY = panelTop + 276

-- State
local curLevel = 1 -- 1 = Category, 2 = Element
local cursorIndex = {1, 1}
local selected = {"", ""}
local currentItems = {{}, {}}

local categories = HVCustomColors.GetCategories()

local function exportColors()
	local encoded = HVCustomColors.ExportBase64()
	local ok, result = false, false
	if Arch and Arch.setClipboardText then
		ok, result = pcall(Arch.setClipboardText, encoded, "text")
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
	if imported then
		MESSAGEMAN:Broadcast("CategoryChanged", { category = selected[1] })
		MESSAGEMAN:Broadcast("RowChanged", { level = 2 })
	end
end

local function importColors()
	local initialText = ""
	if Arch and Arch.getClipboard then
		local ok, clipboard = pcall(Arch.getClipboard)
		if ok and clipboard then initialText = clipboard end
	end
	easyInputStringOKCancel("Paste color configuration (base64):", 12000, false, applyImportedColors, nil, initialText)
end

local function resetCategory()
	if selected[1] and selected[1] ~= "" and HVCustomColors.ResetCategoryToDefaults then
		HVCustomColors.ResetCategoryToDefaults(selected[1])
		SCREENMAN:SystemMessage("Reset category '" .. selected[1] .. "' to defaults")
		MESSAGEMAN:Broadcast("CategoryChanged", { category = selected[1] })
		MESSAGEMAN:Broadcast("RowChanged", { level = 2 })
	end
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
			SDG = "SDG", FC = "FC", NGFC = "NGFC", MF = "MF", SDCB = "SDCB",
			Clear = "Clear", Failed = "Failed", Invalid = "Invalid",
			NoPlay = "NoPlay", None = "None",
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

-- =========================================================================
-- CATEGORY LIST BUILDER
-- =========================================================================
local function generateCategoryList()
	local t = Def.ActorFrame {
		RowChangedMessageCommand = function(self, params)
			if params.level == 1 then
				selected[1] = currentItems[1][cursorIndex[1]] or categories[1]
				MESSAGEMAN:Broadcast("CategoryChanged", { category = selected[1] })
			end
		end
	}

	currentItems[1] = {}
	for _, cat in ipairs(categories) do
		table.insert(currentItems[1], cat)
	end
	selected[1] = currentItems[1][1] or ""

	for k = 1, math.min(#categories, maxItems) do
		local rowY = rowsStartY + (k - 1) * rowPitch
		local itemCat = categories[k]

		t[#t + 1] = Def.ActorFrame {
			Name = "CatRow_" .. k,
			InitCommand = function(self) self:xy(catColX, rowY) end,

			-- Row backing
			Def.Quad {
				Name = "RowBg",
				InitCommand = function(self)
					self:zoomto(catColW - 8, rowPitch - 2):diffuse(color("0.05,0.06,0.08,0.5"))
				end,
				UpdateCommand = function(self)
					local isCur = (k == cursorIndex[1])
					if isCur and curLevel == 1 then
						self:diffuse(color("0.10,0.12,0.18,0.95"))
					elseif isCur and curLevel == 2 then
						self:diffuse(color("0.08,0.09,0.12,0.85"))
					elseif k % 2 == 0 then
						self:diffuse(color("0.06,0.07,0.09,0.5"))
					else
						self:diffuse(color("0.04,0.05,0.07,0.5"))
					end
				end,
				RowChangedMessageCommand = function(self) self:playcommand("Update") end,
				CategoryChangedMessageCommand = function(self) self:playcommand("Update") end,
			},

			-- Left accent glow bar
			Def.Quad {
				Name = "Bar",
				InitCommand = function(self)
					self:x(-(catColW - 8) / 2 + 1.5):zoomto(3, rowPitch - 4)
						:diffuse(getAccent()):diffusealpha(0.9):visible(false)
				end,
				UpdateCommand = function(self)
					local isCur = (k == cursorIndex[1])
					self:visible(isCur)
					if isCur and curLevel == 1 then
						self:diffuse(getAccent()):diffusealpha(0.95)
					else
						self:diffuse(color("0.5,0.55,0.65,0.5"))
					end
				end,
				RowChangedMessageCommand = function(self) self:playcommand("Update") end,
				CategoryChangedMessageCommand = function(self) self:playcommand("Update") end,
			},

			-- Category Label
			LoadFont("Common Normal") .. {
				Name = "CatText",
				InitCommand = function(self)
					self:x(-(catColW - 8) / 2 + 10):halign(0):zoom(0.30)
					self:settext(HVCustomColors.GetCategoryDisplayName(itemCat))
					self:playcommand("Update")
				end,
				UpdateCommand = function(self)
					local isCur = (k == cursorIndex[1])
					if isCur and curLevel == 1 then
						self:diffuse(color("1,1,1,1"))
					elseif isCur and curLevel == 2 then
						self:diffuse(getAccent())
					else
						self:diffuse(color("0.65,0.68,0.74,0.85"))
					end
				end,
				RowChangedMessageCommand = function(self) self:playcommand("Update") end,
				CategoryChangedMessageCommand = function(self) self:playcommand("Update") end,
			}
		}
	end

	return t
end

-- =========================================================================
-- ELEMENT LIST BUILDER
-- =========================================================================
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
				local row = self:GetChild("ElemRow_" .. i)
				if row then row:playcommand("Set") end
			end
		end
	}

	for i = 1, maxItems do
		local rowY = rowsStartY + (i - 1) * rowPitch

		t[#t + 1] = Def.ActorFrame {
			Name = "ElemRow_" .. i,
			InitCommand = function(self) self:xy(listX - listW / 2 + catColW, rowY) end,

			-- Element Row Backing
			Def.Quad {
				Name = "RowBg",
				InitCommand = function(self)
					self:halign(0):zoomto(elemColW + colorColW - 12, rowPitch - 2)
						:diffuse(color("0.05,0.06,0.08,0.5"))
				end,
				SetCommand = function(self)
					local hasElem = (currentItems[2] and currentItems[2][i])
					if not hasElem then
						self:visible(false)
						return
					end
					self:visible(true)
					local isCur = (i == cursorIndex[2])
					if isCur and curLevel == 2 then
						self:diffuse(color("0.10,0.12,0.18,0.95"))
					elseif isCur and curLevel == 1 then
						self:diffuse(color("0.07,0.08,0.11,0.7"))
					elseif i % 2 == 0 then
						self:diffuse(color("0.06,0.07,0.09,0.5"))
					else
						self:diffuse(color("0.04,0.05,0.07,0.5"))
					end
				end,
				RowChangedMessageCommand = function(self) self:playcommand("Set") end,
				CategoryChangedMessageCommand = function(self) self:playcommand("Set") end,
			},

			-- Left Accent Indicator Bar
			Def.Quad {
				Name = "Bar",
				InitCommand = function(self)
					self:halign(0):x(1.5):zoomto(3, rowPitch - 4)
						:diffuse(getAccent()):diffusealpha(0.9):visible(false)
				end,
				SetCommand = function(self)
					local hasElem = currentItems[2] and currentItems[2][i] ~= nil
					local isCur = (i == cursorIndex[2])
					self:visible(hasElem and isCur and curLevel == 2 or false)
					if isCur and curLevel == 2 then
						self:diffuse(getAccent()):diffusealpha(0.95)
					end
				end,
				RowChangedMessageCommand = function(self) self:playcommand("Set") end,
				CategoryChangedMessageCommand = function(self) self:playcommand("Set") end,
			},

			-- Element Name
			LoadFont("Common Normal") .. {
				Name = "ElementName",
				InitCommand = function(self)
					self:halign(0):x(12):zoom(0.30)
					self:playcommand("Set")
				end,
				SetCommand = function(self)
					if currentItems[2] and currentItems[2][i] then
						self:visible(true)
						local category = selected[1] or categories[1]
						local displayName = getDisplayNameForElement(category, currentItems[2][i])
						self:settext(displayName)
						if i == cursorIndex[2] and curLevel == 2 then
							self:diffuse(color("1,1,1,1"))
						elseif i == cursorIndex[2] then
							self:diffuse(getAccent())
						else
							self:diffuse(color("0.75,0.78,0.85,1"))
						end
					else
						self:visible(false)
					end
				end,
				RowChangedMessageCommand = function(self) self:playcommand("Set") end,
				CategoryChangedMessageCommand = function(self) self:playcommand("Set") end,
			},

			-- Color Chip & Hex Code on Right
			Def.ActorFrame {
				Name = "ColorPill",
				InitCommand = function(self)
					self:x(elemColW + colorColW - 20):halign(1)
				end,

				-- Color Preview Chip
				Def.Quad {
					Name = "ChipBorder",
					InitCommand = function(self)
						self:x(-72):zoomto(15, 15):diffuse(color("0.18,0.20,0.24,0.8"))
					end,
					SetCommand = function(self)
						self:visible(currentItems[2] and currentItems[2][i] ~= nil)
					end,
				},
				Def.Quad {
					Name = "Chip",
					InitCommand = function(self)
						self:x(-72):zoomto(13, 13)
					end,
					SetCommand = function(self)
						if currentItems[2] and currentItems[2][i] then
							self:visible(true)
							local category = selected[1] or categories[1]
							local hex = HVCustomColors.GetColor(category, currentItems[2][i])
							self:diffuse(color(hex))
						else
							self:visible(false)
						end
					end,
					CustomColorChangedMessageCommand = function(self, params)
						if params and currentItems[2] and currentItems[2][i] == params.Element then
							self:diffuse(color(params.Color))
						end
					end,
				},

				-- Hex Code Text
				LoadFont("Common Normal") .. {
					Name = "HexText",
					InitCommand = function(self)
						self:halign(1):x(-4):zoom(0.28)
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
								self:diffuse(color("0.65,0.68,0.74,1"))
							end
						else
							self:visible(false)
						end
					end,
					CustomColorChangedMessageCommand = function(self, params)
						if params and currentItems[2] and currentItems[2][i] == params.Element then
							self:settext(params.Color:upper()):diffuse(color(params.Color))
						end
					end,
				}
			}
		}
	end

	return t
end

-- =========================================================================
-- MAIN ACTOR & INPUT HANDLING
-- =========================================================================
local t = Def.ActorFrame {
	Name = "CustomColorsRoot",
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

		local function openEditor()
			if selected[2] and selected[2] ~= "" then
				HV.SelectedCustomColor = { selected[1], selected[2] }
				transitionToScreen("ScreenHVColorEdit")
			end
		end

		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type ~= "InputEventType_FirstPress" then return end

			-- Mouse click handling
			if event.DeviceInput and event.DeviceInput.button == "DeviceButton_left mouse button" then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()

				-- Action Buttons in Right Panel
				local actionBtnW = panelW - 36
				if buttonHit(panelX, btnEditY, actionBtnW, 32) then openEditor(); return true end
				if buttonHit(panelX, btnExportY, actionBtnW, 28) then exportColors(); return true end
				if buttonHit(panelX, btnImportY, actionBtnW, 28) then importColors(); return true end
				if buttonHit(panelX, btnResetY, actionBtnW, 28) then resetCategory(); return true end

				-- Category click
				if mx >= catColX - catColW / 2 and mx <= catColX + catColW / 2 then
					for k = 1, math.min(#categories, maxItems) do
						local ry = rowsStartY + (k - 1) * rowPitch
						if my >= ry - rowPitch / 2 and my <= ry + rowPitch / 2 then
							cursorIndex[1] = k
							curLevel = 1
							selected[1] = categories[k]
							MESSAGEMAN:Broadcast("CategoryChanged", { category = selected[1] })
							MESSAGEMAN:Broadcast("RowChanged", { level = 1 })
							return true
						end
					end
				end

				-- Element click
				local elemLeft = listX - listW / 2 + catColW
				local elemRight = listX + listW / 2
				if mx >= elemLeft and mx <= elemRight then
					for i = 1, math.min(#currentItems[2], maxItems) do
						local ry = rowsStartY + (i - 1) * rowPitch
						if my >= ry - rowPitch / 2 and my <= ry + rowPitch / 2 then
							cursorIndex[2] = i
							curLevel = 2
							selected[2] = currentItems[2][i] or ""
							MESSAGEMAN:Broadcast("RowChanged", { level = 2 })
							return true
						end
					end
				end
			end

			-- Arrow Keys
			if event.button == "MenuUp" or (event.DeviceInput and event.DeviceInput.button == "DeviceButton_up") then
				if curLevel == 1 then
					cursorIndex[curLevel] = math.max(1, cursorIndex[curLevel] - 1)
					cursorIndex[2] = 1
				elseif curLevel == 2 then
					cursorIndex[curLevel] = math.max(1, cursorIndex[curLevel] - 1)
					selected[2] = currentItems[2][cursorIndex[2]] or ""
				end
				MESSAGEMAN:Broadcast("RowChanged", { level = curLevel })
				return true

			elseif event.button == "MenuDown" or (event.DeviceInput and event.DeviceInput.button == "DeviceButton_down") then
				if curLevel == 1 then
					cursorIndex[curLevel] = math.min(#categories, cursorIndex[curLevel] + 1)
					cursorIndex[2] = 1
				elseif curLevel == 2 then
					cursorIndex[curLevel] = math.min(#currentItems[2], cursorIndex[curLevel] + 1)
					selected[2] = currentItems[2][cursorIndex[2]] or ""
				end
				MESSAGEMAN:Broadcast("RowChanged", { level = curLevel })
				return true

			elseif event.button == "MenuLeft" or (event.DeviceInput and event.DeviceInput.button == "DeviceButton_left") then
				curLevel = math.max(1, curLevel - 1)
				MESSAGEMAN:Broadcast("CategoryChanged", { category = selected[1] })
				MESSAGEMAN:Broadcast("RowChanged", { level = curLevel })
				return true

			elseif event.button == "MenuRight" or (event.DeviceInput and event.DeviceInput.button == "DeviceButton_right") then
				curLevel = math.min(2, curLevel + 1)
				MESSAGEMAN:Broadcast("CategoryChanged", { category = selected[1] })
				MESSAGEMAN:Broadcast("RowChanged", { level = curLevel })
				return true

			elseif event.button == "Start" or (event.DeviceInput and event.DeviceInput.button == "DeviceButton_enter") then
				if curLevel == 1 then
					curLevel = 2
					MESSAGEMAN:Broadcast("CategoryChanged", { category = selected[1] })
					MESSAGEMAN:Broadcast("RowChanged", { level = 2 })
				elseif curLevel == 2 then
					openEditor()
				end
				return true

			elseif event.button == "Back" or (event.DeviceInput and event.DeviceInput.button == "DeviceButton_escape") then
				SCREENMAN:GetTopScreen():Cancel()
				return true

			elseif event.DeviceInput and event.DeviceInput.button == "DeviceButton_e" then
				exportColors()
				return true

			elseif event.DeviceInput and event.DeviceInput.button == "DeviceButton_i" then
				importColors()
				return true
			end
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
			self:settext("HOLOGRAPHIC VOID  //  CUSTOM ELEMENT COLORING")
		end,
	},
	-- Screen Title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX, headerTop + 14):halign(0):zoom(0.62):diffuse(color("1,1,1,1"))
			self:settext("CUSTOM COLORS")
		end,
	},
	-- Screen Subtitle
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX + 205, headerTop + 17):halign(0):zoom(0.32)
				:diffuse(color("0.65,0.68,0.74,0.85"))
			self:settext("Configure exact color values for HUD elements, judgments, grades & meters")
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
-- 2. LEFT PANEL: CATEGORIES & ELEMENTS MATRIX
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

-- Left Panel Header Banner with Column Headers
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
	-- Column Header: Category
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(-listW / 2 + 16):halign(0):zoom(0.26)
				:diffuse(getAccent()):diffusealpha(0.9)
			self:settext("CATEGORY")
		end,
	},
	-- Column Header: Element
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(-listW / 2 + catColW + 12):halign(0):zoom(0.26)
				:diffuse(getAccent()):diffusealpha(0.9)
			self:settext("ELEMENT")
		end,
	},
	-- Column Header: Color
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(listW / 2 - 16):halign(1):zoom(0.26)
				:diffuse(getAccent()):diffusealpha(0.9)
			self:settext("COLOR CODE")
		end,
	},
}

-- Category and Element rows
t[#t + 1] = generateCategoryList()
t[#t + 1] = generateElementList()

-- =========================================================================
-- 3. RIGHT PANEL: COLOR INSPECTOR & TOOLS
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
	-- Kicker
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(-panelW / 2 + 16):halign(0):zoom(0.28)
				:diffuse(getAccent()):diffusealpha(0.85)
			self:settext("// INSPECTOR & ACTIONS")
		end,
	},
	-- Tag
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(panelW / 2 - 16):halign(1):zoom(0.26):diffuse(color("0.65,0.68,0.74,0.85"))
			self:settext("PALETTE TOOLS")
		end,
	},
}

-- Compact Color Preview Card (Top of Right Panel)
local previewBoxW = panelW - 24
local previewBoxH = 96
local previewBoxY = panelTop + 90

t[#t + 1] = Def.ActorFrame {
	Name = "PreviewCard",
	InitCommand = function(self) self:xy(panelX, previewBoxY) end,

	-- Card Backing
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(previewBoxW, previewBoxH):diffuse(color("0.06,0.07,0.09,0.75"))
		end,
	},
	Def.ActorFrame {
		makePanelBorder(previewBoxW, previewBoxH, color("0.18,0.20,0.24,0.8")),
	},
	Def.ActorFrame {
		makeCornerBrackets(previewBoxW, previewBoxH, 6, 1.2),
	},
	-- Left Accent Line
	Def.Quad {
		InitCommand = function(self)
			self:x(-previewBoxW / 2 + 1.5):zoomto(3, previewBoxH):diffuse(getAccent()):diffusealpha(0.85)
		end,
	},

	-- Big Color Swatch Box
	Def.Quad {
		Name = "BigSwatchBorder",
		InitCommand = function(self)
			self:xy(-previewBoxW / 2 + 46, 0):zoomto(54, 54):diffuse(color("0.18,0.20,0.24,0.9"))
		end,
	},
	Def.Quad {
		Name = "BigSwatch",
		InitCommand = function(self)
			self:xy(-previewBoxW / 2 + 46, 0):zoomto(50, 50):diffuse(color("#5ABAFF"))
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

	-- Element Display Name
	LoadFont("Common Normal") .. {
		Name = "DetailElementName",
		InitCommand = function(self)
			self:xy(-previewBoxW / 2 + 84, -20):halign(0):zoom(0.38):diffuse(color("1,1,1,1"))
		end,
		SetCommand = function(self)
			local category = selected[1] or categories[1]
			local element = currentItems[2] and currentItems[2][cursorIndex[2]]
			if element then
				self:settext(getDisplayNameForElement(category, element))
			else
				self:settext("No Element Selected")
			end
		end,
		RowChangedMessageCommand = function(self) self:playcommand("Set") end,
		CategoryChangedMessageCommand = function(self) self:playcommand("Set") end,
	},

	-- Category Tag
	LoadFont("Common Normal") .. {
		Name = "DetailCategoryName",
		InitCommand = function(self)
			self:xy(-previewBoxW / 2 + 84, -4):halign(0):zoom(0.24):diffuse(color("0.65,0.68,0.74,1"))
		end,
		SetCommand = function(self)
			local category = selected[1] or categories[1]
			self:settext("CATEGORY: " .. (HVCustomColors.GetCategoryDisplayName(category)):upper())
		end,
		RowChangedMessageCommand = function(self) self:playcommand("Set") end,
		CategoryChangedMessageCommand = function(self) self:playcommand("Set") end,
	},

	-- Big Hex Code Readout
	LoadFont("Common Normal") .. {
		Name = "DetailHexText",
		InitCommand = function(self)
			self:xy(-previewBoxW / 2 + 84, 18):halign(0):zoom(0.42):diffuse(getAccent())
		end,
		SetCommand = function(self)
			local category = selected[1] or categories[1]
			local element = currentItems[2] and currentItems[2][cursorIndex[2]]
			if element then
				local hex = HVCustomColors.GetColor(category, element)
				self:settext(hex:upper()):diffuse(color(hex))
			else
				self:settext("#FFFFFF"):diffuse(color("#FFFFFF"))
			end
		end,
		RowChangedMessageCommand = function(self) self:playcommand("Set") end,
		CategoryChangedMessageCommand = function(self) self:playcommand("Set") end,
		CustomColorChangedMessageCommand = function(self, params)
			if params and params.Color and selected[1] == params.Category and selected[2] == params.Element then
				self:settext(params.Color:upper()):diffuse(color(params.Color))
			end
		end,
	},
}

-- Action Buttons Deck (Strictly bounded inside right panel)
local function makeCyberButton(name, title, subtitle, y, height, isPrimary)
	local btnW = panelW - 24
	return Def.ActorFrame {
		Name = name,
		InitCommand = function(self) self:xy(panelX, y) end,

		-- Button Backing
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:zoomto(btnW, height)
				if isPrimary then
					self:diffuse(color("0.08,0.10,0.14,0.95"))
				else
					self:diffuse(color("0.06,0.07,0.09,0.85"))
				end
			end,
		},
		-- Border
		Def.ActorFrame {
			makePanelBorder(btnW, height, isPrimary and color("0.24,0.28,0.36,0.9") or color("0.16,0.18,0.22,0.8")),
		},
		-- Left Accent Line
		Def.Quad {
			InitCommand = function(self)
				self:x(-btnW / 2 + 1.5):zoomto(3, height)
					:diffuse(getAccent()):diffusealpha(isPrimary and 0.95 or 0.6)
			end,
		},
		-- Title
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-btnW / 2 + 14, subtitle and -5 or 0):halign(0)
					:zoom(isPrimary and 0.32 or 0.28):diffuse(color("1,1,1,1"))
				self:settext(title)
			end,
		},
		-- Subtitle
		subtitle and LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-btnW / 2 + 14, 7):halign(0):zoom(0.22)
					:diffuse(color("0.65,0.68,0.74,1"))
				self:settext(subtitle)
			end,
		} or nil,
		-- Right Arrow / Tag
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(btnW / 2 - 14, 0):halign(1):zoom(0.26)
					:diffuse(getAccent()):diffusealpha(0.85)
				self:settext(isPrimary and "ENTER ->" or "->")
			end,
		}
	}
end

t[#t + 1] = makeCyberButton("BtnEdit", "EDIT COLOR", nil, btnEditY, 32, true)
t[#t + 1] = makeCyberButton("BtnExport", "EXPORT TO CLIPBOARD (E)", nil, btnExportY, 28, false)
t[#t + 1] = makeCyberButton("BtnImport", "IMPORT FROM CLIPBOARD (I)", nil, btnImportY, 28, false)
t[#t + 1] = makeCyberButton("BtnReset", "RESET CATEGORY DEFAULTS", nil, btnResetY, 28, false)

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
