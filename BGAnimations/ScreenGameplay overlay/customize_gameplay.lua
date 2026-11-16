local playerData = playerConfig and playerConfig:get_data(pn_to_profile_slot(PLAYER_1)) or nil
local allowed = playerData and playerData.CustomizeGameplay == true
local loadingScreen = Var "LoadingScreen" or ""
local isSync = loadingScreen:find("Sync") ~= nil

local entriesByName = {}
local elementList = {}

local level2Open = false
local level3Open = false

local selectedElement = nil
local selectedCategory = nil
local editingEntry = nil

local lvl1Selected = 1
local lvl1FirstVisible = 1

local lvl2Selected = 2
local lvl2FirstVisible = 1

local lvl3Selected = 2
local lvl3FirstVisible = 1

local snapshot
local resetArmed = false
local positionDrag = nil
local editorActive = false

-- Dimensions: Top-left aligned, small (35% of screen height)
local screenTop = SCREEN_TOP or 0
local screenLeft = SCREEN_LEFT or 0
local screenH = SCREEN_HEIGHT or 480
local overlayH = math.floor(screenH * 0.35) -- 168 px on standard 480p
local overlayTop = screenTop + 12
local overlayLeft = screenLeft + 12

local maxRows = 6
local rowH = 20
local headerH = 22
local listTopOffset = 23

local w1 = 152
local w2 = 114
local w3 = 196
local colGap = 6

local col1X = overlayLeft
local col2X = col1X + w1 + colGap
local col3X = col2X + w2 + colGap

local function elementLabel(name)
	local key = "Element" .. name
	local ok, label = pcall(function() return THEME:GetString("CustomizeGameplay", key) end)
	if ok and label and label ~= "" and label ~= key then return label end
	return name
end

local function addElementEntry(entry)
	if entry.data.condition == false then return end
	local name = entry.data.name
	if not entriesByName[name] then
		entriesByName[name] = {name = name, label = elementLabel(name), entries = {}}
	end
	table.insert(entriesByName[name].entries, entry)
end

local function rebuildElementList()
	elementList = {}
	for _, data in pairs(entriesByName) do
		elementList[#elementList + 1] = data
	end
	table.sort(elementList, function(a, b) return a.label < b.label end)
end

local function propertyCategory(property)
	if property == "X" or property == "Y" then return "Position" end
	if property == "Zoom" or property == "Width" or property == "Height" then return "Size" end
	if property == "Spacing" then return "Spacing" end
	if property == "Scale" then return "Scale" end
	if property == "Rotation" then return "Rotation" end
	return property
end

local function getCategories(element)
	if not element then return {} end
	local cats = {}
	for _, entry in ipairs(element.entries) do
		for _, prop in ipairs(entry.data.properties or {}) do
			cats[propertyCategory(prop)] = true
		end
	end
	local list = {}
	for _, name in ipairs({"Position", "Size", "Spacing", "Scale", "Rotation"}) do
		if cats[name] then list[#list + 1] = name; cats[name] = nil end
	end
	local remaining = {}
	for name in pairs(cats) do remaining[#remaining + 1] = name end
	table.sort(remaining)
	for _, name in ipairs(remaining) do list[#list + 1] = name end
	return list
end

local function getCategoryEntries(element, category)
	if not element or not category then return {} end
	local result = {}
	for _, entry in ipairs(element.entries) do
		for _, suffix in ipairs(entry.data.properties or {}) do
			local propCategory = propertyCategory(suffix)
			if propCategory == category then
				result[#result + 1] = {entry = entry, suffix = suffix}
			end
		end
	end
	return result
end

local function getLevel2Rows(element)
	local rows = {"Back"}
	for _, category in ipairs(getCategories(element)) do rows[#rows + 1] = category end
	return rows
end

local function getLevel3Rows(element, category)
	local rows = {{isBack = true}}
	for _, prop in ipairs(getCategoryEntries(element, category)) do rows[#rows + 1] = prop end
	return rows
end

local function entryForElementBounds(element, category)
	if not element then return nil end
	local fallback
	for _, entry in ipairs(element.entries) do
		if not fallback then fallback = entry end
		local matchesCategory = category == nil
		for _, prop in ipairs(entry.data.properties or {}) do
			if propertyCategory(prop) == category then matchesCategory = true end
		end
		if matchesCategory and entry.data.Border then return entry end
	end
	if fallback and fallback.data.Border then return fallback end
	return fallback
end

local function getPropertyValue(prop)
	local data = prop.entry.data
	local value = MovableValues[data.name .. prop.suffix]
	if data.name == "FullProgressBar" and prop.suffix == "Y"
		and data.actor and data.actor.GetTrueY then
		local ok, absoluteY = pcall(function() return data.actor:GetTrueY() end)
		if ok and type(absoluteY) == "number" then value = absoluteY end
	end
	if type(value) ~= "number" then
		value = tonumber(value) or 0
	end
	return value
end

local function setColumnStyle(colActor, isDimmed)
	local p = colActor:GetChild("Panel")
	if p then
		p:diffusealpha(isDimmed and 0.32 or 0.55)
	end
	local b = colActor:GetChild("Border")
	if b then
		local alpha = isDimmed and 0.16 or 0.45
		local c = isDimmed and (HVColor.Border or color("0.25,0.25,0.25,1")) or HVColor.Accent
		b:GetChild("BTop"):diffuse(c):diffusealpha(alpha)
		b:GetChild("BBottom"):diffuse(c):diffusealpha(alpha)
		b:GetChild("BLeft"):diffuse(c):diffusealpha(alpha)
		b:GetChild("BRight"):diffuse(c):diffusealpha(alpha)
	end
	local hb = colActor:GetChild("HeaderBacking")
	if hb then
		hb:diffusealpha(isDimmed and 0.22 or 0.45)
	end
	local hd = colActor:GetChild("HeaderDivider")
	if hd then
		hd:diffusealpha(isDimmed and 0.15 or 0.35)
	end
	local fd = colActor:GetChild("FooterDivider")
	if fd then
		fd:diffusealpha(isDimmed and 0.15 or 0.35)
	end
	local h = colActor:GetChild("Header")
	if h then
		h:diffusealpha(isDimmed and 0.40 or 1.0)
	end
end

local function updateAll(self)
	local accent = HVColor.Accent or color("#5ABAFF")
	local textBright = HVColor.TextBright or color("1,1,1,1")

	-- 1. LEVEL 1 (ELEMENTS)
	local col1 = self:GetChild("Col1")
	local lvl1Dimmed = level2Open or level3Open
	setColumnStyle(col1, lvl1Dimmed)

	lvl1Selected = math.max(1, math.min(lvl1Selected, math.max(1, #elementList)))
	lvl1FirstVisible = math.max(1, math.min(lvl1FirstVisible, math.max(1, #elementList - maxRows + 1)))

	local rows1 = col1:GetChild("Rows")
	for i = 1, maxRows do
		local row = rows1:GetChild("Row" .. i)
		local idx = lvl1FirstVisible + i - 1
		local elem = elementList[idx]
		if elem then
			row:visible(true)
			local txt = row:GetChild("Text")
			local bkg = row:GetChild("Backing")
			txt:settext(elem.label)
			if idx == lvl1Selected then
				bkg:diffuse(accent):diffusealpha(lvl1Dimmed and 0.18 or 0.38)
				txt:diffuse(accent):diffusealpha(lvl1Dimmed and 0.50 or 1.0)
			else
				bkg:diffuse(color("1,1,1,1")):diffusealpha(lvl1Dimmed and 0.03 or 0.06)
				txt:diffuse(color("0.9,0.9,0.9,1")):diffusealpha(lvl1Dimmed and 0.40 or 0.90)
			end
		else
			row:visible(false)
		end
	end

	col1:GetChild("ScrollUp"):visible(lvl1FirstVisible > 1)
	col1:GetChild("ScrollDown"):visible(lvl1FirstVisible + maxRows <= #elementList)

	-- Footer buttons
	local revBtn = col1:GetChild("RevertBtn")
	revBtn:GetChild("Backing"):diffusealpha(lvl1Dimmed and 0.05 or 0.12)
	revBtn:GetChild("Text"):diffusealpha(lvl1Dimmed and 0.35 or 0.85)

	local rstBtn = col1:GetChild("ResetBtn")
	if resetArmed then
		rstBtn:GetChild("Backing"):diffuse(color("0.4,0.25,0.05,0.4")):diffusealpha(1)
		rstBtn:GetChild("Text"):settext("Confirm (3s)"):diffuse(color("1,0.72,0.25,1")):diffusealpha(1)
	else
		rstBtn:GetChild("Backing"):diffuse(color("1,1,1,1")):diffusealpha(lvl1Dimmed and 0.05 or 0.12)
		rstBtn:GetChild("Text"):settext("Reset All"):diffuse(textBright):diffusealpha(lvl1Dimmed and 0.35 or 0.85)
	end

	-- 2. LEVEL 2 (CATEGORIES)
	local col2 = self:GetChild("Col2")
	col2:visible(level2Open == true)
	if level2Open and selectedElement then
		local categories = getLevel2Rows(selectedElement)
		local lvl2Dimmed = level3Open == true
		setColumnStyle(col2, lvl2Dimmed)

		col2:GetChild("Header"):settext(selectedElement.label)

		lvl2Selected = math.max(1, math.min(lvl2Selected, math.max(1, #categories)))
		lvl2FirstVisible = math.max(1, math.min(lvl2FirstVisible, math.max(1, #categories - maxRows + 1)))

		local rows2 = col2:GetChild("Rows")
		for i = 1, maxRows do
			local row = rows2:GetChild("Row" .. i)
			local idx = lvl2FirstVisible + i - 1
			local cat = categories[idx]
			if cat then
				row:visible(true)
				local txt = row:GetChild("Text")
				local bkg = row:GetChild("Backing")
				txt:settext(cat)
				if idx == lvl2Selected then
					bkg:diffuse(accent):diffusealpha(lvl2Dimmed and 0.18 or 0.38)
					txt:diffuse(accent):diffusealpha(lvl2Dimmed and 0.50 or 1.0)
				else
					bkg:diffuse(color("1,1,1,1")):diffusealpha(lvl2Dimmed and 0.03 or 0.06)
					txt:diffuse(color("0.9,0.9,0.9,1")):diffusealpha(lvl2Dimmed and 0.40 or 0.90)
				end
			else
				row:visible(false)
			end
		end
		col2:GetChild("Footer"):settext(lvl2Dimmed and "" or "Select Category"):diffusealpha(0.60)
	end

	-- 3. LEVEL 3 (PARAMETERS)
	local col3 = self:GetChild("Col3")
	col3:visible(level3Open == true)
	if level3Open and selectedElement and selectedCategory then
		local properties = getLevel3Rows(selectedElement, selectedCategory)
		setColumnStyle(col3, false) -- Level 3 is active and never dimmed

		col3:GetChild("Header"):settext(selectedCategory)

		lvl3Selected = math.max(1, math.min(lvl3Selected, math.max(1, #properties)))
		lvl3FirstVisible = math.max(1, math.min(lvl3FirstVisible, math.max(1, #properties - maxRows + 1)))

		local rows3 = col3:GetChild("Rows")
		for i = 1, maxRows do
			local row = rows3:GetChild("Row" .. i)
			local idx = lvl3FirstVisible + i - 1
			local prop = properties[idx]
			if prop then
				row:visible(true)
				local isBack = prop.isBack == true
				local val = isBack and 0 or getPropertyValue(prop)
				local bkg = row:GetChild("Backing")
				local lbl = row:GetChild("Label")
				local vtxt = row:GetChild("Value")
				local lbtn = row:GetChild("LeftBtn")
				local rbtn = row:GetChild("RightBtn")

				lbl:settext(isBack and "Back" or prop.suffix)
				vtxt:settext(isBack and "" or string.format("%.2f", val))
				lbtn:visible(not isBack)
				rbtn:visible(not isBack)

				if idx == lvl3Selected then
					bkg:diffuse(accent):diffusealpha(0.32)
					lbl:diffuse(accent):diffusealpha(1.0)
					vtxt:diffuse(textBright):diffusealpha(1.0)
					lbtn:GetChild("Backing"):diffuse(accent):diffusealpha(0.28)
					lbtn:GetChild("Icon"):diffuse(accent):diffusealpha(1.0)
					rbtn:GetChild("Backing"):diffuse(accent):diffusealpha(0.28)
					rbtn:GetChild("Icon"):diffuse(accent):diffusealpha(1.0)
				else
					bkg:diffuse(color("1,1,1,1")):diffusealpha(0.06)
					lbl:diffuse(color("0.85,0.85,0.85,1")):diffusealpha(0.90)
					vtxt:diffuse(color("0.9,0.9,0.9,1")):diffusealpha(0.90)
					lbtn:GetChild("Backing"):diffuse(color("1,1,1,1")):diffusealpha(0.08)
					lbtn:GetChild("Icon"):diffuse(color("0.7,0.7,0.7,1")):diffusealpha(0.85)
					rbtn:GetChild("Backing"):diffuse(color("1,1,1,1")):diffusealpha(0.08)
					rbtn:GetChild("Icon"):diffuse(color("0.7,0.7,0.7,1")):diffusealpha(0.85)
				end
			else
				row:visible(false)
			end
		end
		col3:GetChild("Footer"):settext("Backspace: Default"):diffusealpha(0.60)
	end
end

local function goBack(self)
	if level3Open then
		level3Open = false
		editingEntry = entryForElementBounds(selectedElement)
		SelectGameplayCustomizationEntry(editingEntry)
		updateAll(self)
		return true
	elseif level2Open then
		level2Open = false
		level3Open = false
		selectedCategory = nil
		editingEntry = nil
		SelectGameplayCustomizationEntry(nil)
		updateAll(self)
		return true
	end
	return false
end

local function input(self, event)
	if not editorActive then return false end
	if not event or event.type == "InputEventType_Release" then return false end
	local button = event.DeviceInput and event.DeviceInput.button or ""
	local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()

	-- Handle Mouse Wheel scrolling or adjusting
	local scroll = GetMouseScrollDirection(button)
	if scroll ~= 0 then
		if level3Open and mx >= col3X and mx <= col3X + w3 and my >= overlayTop and my <= overlayTop + overlayH then
			local properties = getLevel3Rows(selectedElement, selectedCategory)
			local listTop = overlayTop + listTopOffset
			if my >= listTop and my < listTop + maxRows * rowH then
				local rowIdx = math.floor((my - listTop) / rowH) + 1
				local itemIdx = lvl3FirstVisible + rowIdx - 1
				local prop = properties[itemIdx]
				if prop and not prop.isBack and mx >= col3X + 104 and mx <= col3X + w3 - 4 then
					-- Over value or arrow: scroll adjusts value
					AdjustGameplayCustomization(prop.entry, prop.suffix, -scroll)
					lvl3Selected = itemIdx
					editingEntry = prop.entry
					SelectGameplayCustomizationEntry(editingEntry)
					updateAll(self)
					return true
				end
			end
			if #properties > maxRows then
				lvl3FirstVisible = math.max(1, math.min(#properties - maxRows + 1, lvl3FirstVisible + scroll))
				updateAll(self)
				return true
			end
		elseif level2Open and mx >= col2X and mx <= col2X + w2 and my >= overlayTop and my <= overlayTop + overlayH then
			local categories = getLevel2Rows(selectedElement)
			if #categories > maxRows then
				lvl2FirstVisible = math.max(1, math.min(#categories - maxRows + 1, lvl2FirstVisible + scroll))
				updateAll(self)
				return true
			end
		elseif mx >= col1X and mx <= col1X + w1 and my >= overlayTop and my <= overlayTop + overlayH then
			if #elementList > maxRows then
				lvl1FirstVisible = math.max(1, math.min(#elementList - maxRows + 1, lvl1FirstVisible + scroll))
				updateAll(self)
				return true
			end
		end
	end

	-- Handle Mouse Left Click
	if IsMouseLeftClick(button) then
		-- Level 3 clicks
		if level3Open and mx >= col3X and mx <= col3X + w3 and my >= overlayTop and my <= overlayTop + overlayH then
			local properties = getLevel3Rows(selectedElement, selectedCategory)
			local listTop = overlayTop + listTopOffset
			if my >= listTop and my < listTop + maxRows * rowH then
				local rowIdx = math.floor((my - listTop) / rowH) + 1
				local itemIdx = lvl3FirstVisible + rowIdx - 1
				local prop = properties[itemIdx]
				if prop then
					if prop.isBack then
						lvl3Selected = itemIdx
						goBack(self)
						return true
					end
					lvl3Selected = itemIdx
					editingEntry = prop.entry
					SelectGameplayCustomizationEntry(editingEntry)
					-- Check left arrow: col3X + 104 to col3X + 126
					if mx >= col3X + 104 and mx <= col3X + 126 then
						AdjustGameplayCustomization(prop.entry, prop.suffix, -1)
					-- Check right arrow: col3X + 172 to col3X + 192
					elseif mx >= col3X + 172 and mx <= col3X + 192 then
						AdjustGameplayCustomization(prop.entry, prop.suffix, 1)
					end
					updateAll(self)
					return true
				end
			end
			return true
		end

		-- Level 2 clicks
		if level2Open and mx >= col2X and mx <= col2X + w2 and my >= overlayTop and my <= overlayTop + overlayH then
			-- Click on Level 2 header closes Level 3
			if my >= overlayTop and my <= overlayTop + headerH then
				level3Open = false
				editingEntry = entryForElementBounds(selectedElement)
				SelectGameplayCustomizationEntry(editingEntry)
				updateAll(self)
				return true
			end
			local categories = getLevel2Rows(selectedElement)
			local listTop = overlayTop + listTopOffset
			if my >= listTop and my < listTop + maxRows * rowH then
				local rowIdx = math.floor((my - listTop) / rowH) + 1
				local itemIdx = lvl2FirstVisible + rowIdx - 1
				local cat = categories[itemIdx]
				if cat then
					if cat == "Back" then
						lvl2Selected = itemIdx
						goBack(self)
						return true
					end
					lvl2Selected = itemIdx
					selectedCategory = cat
					level3Open = true
					lvl3Selected = 2
					lvl3FirstVisible = 1
					editingEntry = entryForElementBounds(selectedElement, selectedCategory)
					SelectGameplayCustomizationEntry(editingEntry)
					updateAll(self)
					return true
				end
			end
			return true
		end

		-- Level 1 clicks
		if mx >= col1X and mx <= col1X + w1 and my >= overlayTop and my <= overlayTop + overlayH then
			-- Click on Level 1 header closes Level 2 and Level 3
			if my >= overlayTop and my <= overlayTop + headerH then
				level2Open = false
				level3Open = false
				selectedCategory = nil
				updateAll(self)
				return true
			end
			-- Footer Revert button
			if mx >= col1X + 6 and mx <= col1X + 72 and my >= overlayTop + overlayH - 22 and my <= overlayTop + overlayH - 2 then
				RestoreGameplayCustomizationSnapshot(snapshot)
				ms.ok(THEME:GetString("CustomizeGameplay", "Reverted"))
				updateAll(self)
				return true
			end
			-- Footer Reset button
			if mx >= col1X + 78 and mx <= col1X + 146 and my >= overlayTop + overlayH - 22 and my <= overlayTop + overlayH - 2 then
				if resetArmed then
					resetArmed = false
					self:GetChild("ResetTimer"):stoptweening():diffusealpha(0)
					ResetGameplayCustomizationKeymode()
				else
					resetArmed = true
					self:GetChild("ResetTimer"):stoptweening():diffusealpha(1):sleep(3):queuecommand("ResetExpired")
				end
				updateAll(self)
				return true
			end
			-- Rows
			local listTop = overlayTop + listTopOffset
			if my >= listTop and my < listTop + maxRows * rowH then
				local rowIdx = math.floor((my - listTop) / rowH) + 1
				local itemIdx = lvl1FirstVisible + rowIdx - 1
				local elem = elementList[itemIdx]
				if elem then
					lvl1Selected = itemIdx
					selectedElement = elem
					level2Open = true
					level3Open = false
					lvl2Selected = 2
					lvl2FirstVisible = 1
					selectedCategory = nil
					editingEntry = entryForElementBounds(selectedElement)
					SelectGameplayCustomizationEntry(editingEntry)
					updateAll(self)
					return true
				end
			end
			return true
		end
	end

	-- Keyboard navigation
	if button == "DeviceButton_up" then
		if level3Open then
			local properties = getLevel3Rows(selectedElement, selectedCategory)
			lvl3Selected = math.max(1, lvl3Selected - 1)
			if lvl3Selected < lvl3FirstVisible then lvl3FirstVisible = lvl3Selected end
			local prop = properties[lvl3Selected]
			if prop and not prop.isBack then
				editingEntry = prop.entry
				SelectGameplayCustomizationEntry(editingEntry)
			elseif prop then
				editingEntry = entryForElementBounds(selectedElement)
				SelectGameplayCustomizationEntry(editingEntry)
			end
		elseif level2Open then
			local categories = getLevel2Rows(selectedElement)
			lvl2Selected = math.max(1, lvl2Selected - 1)
			if lvl2Selected < lvl2FirstVisible then lvl2FirstVisible = lvl2Selected end
		else
			lvl1Selected = math.max(1, lvl1Selected - 1)
			if lvl1Selected < lvl1FirstVisible then lvl1FirstVisible = lvl1Selected end
			selectedElement = elementList[lvl1Selected]
			editingEntry = entryForElementBounds(selectedElement)
			SelectGameplayCustomizationEntry(editingEntry)
		end
		updateAll(self)
		return true
	elseif button == "DeviceButton_down" then
		if level3Open then
			local properties = getLevel3Rows(selectedElement, selectedCategory)
			lvl3Selected = math.min(#properties, lvl3Selected + 1)
			if lvl3Selected >= lvl3FirstVisible + maxRows then lvl3FirstVisible = lvl3Selected - maxRows + 1 end
			local prop = properties[lvl3Selected]
			if prop and not prop.isBack then
				editingEntry = prop.entry
				SelectGameplayCustomizationEntry(editingEntry)
			elseif prop then
				editingEntry = entryForElementBounds(selectedElement)
				SelectGameplayCustomizationEntry(editingEntry)
			end
		elseif level2Open then
			local categories = getLevel2Rows(selectedElement)
			lvl2Selected = math.min(#categories, lvl2Selected + 1)
			if lvl2Selected >= lvl2FirstVisible + maxRows then lvl2FirstVisible = lvl2Selected - maxRows + 1 end
		else
			lvl1Selected = math.min(#elementList, lvl1Selected + 1)
			if lvl1Selected >= lvl1FirstVisible + maxRows then lvl1FirstVisible = lvl1Selected - maxRows + 1 end
			selectedElement = elementList[lvl1Selected]
			editingEntry = entryForElementBounds(selectedElement)
			SelectGameplayCustomizationEntry(editingEntry)
		end
		updateAll(self)
		return true
	elseif button == "DeviceButton_right" then
		if level3Open then
			local properties = getLevel3Rows(selectedElement, selectedCategory)
			local prop = properties[lvl3Selected]
			if prop then
				if prop.isBack then goBack(self)
				else AdjustGameplayCustomization(prop.entry, prop.suffix, 1); updateAll(self) end
			end
		elseif level2Open then
			local categories = getLevel2Rows(selectedElement)
			selectedCategory = categories[lvl2Selected]
			if selectedCategory == "Back" then goBack(self)
			elseif selectedCategory then
				level3Open = true
				lvl3Selected = 2
				lvl3FirstVisible = 1
				editingEntry = entryForElementBounds(selectedElement, selectedCategory)
				SelectGameplayCustomizationEntry(editingEntry)
				updateAll(self)
			end
		else
			selectedElement = elementList[lvl1Selected]
			if selectedElement then
				level2Open = true
				level3Open = false
				lvl2Selected = 2
				lvl2FirstVisible = 1
				selectedCategory = nil
				editingEntry = entryForElementBounds(selectedElement)
				SelectGameplayCustomizationEntry(editingEntry)
				updateAll(self)
			end
		end
		return true
	elseif button == "DeviceButton_left" then
		if level3Open then
			local properties = getLevel3Rows(selectedElement, selectedCategory)
			local prop = properties[lvl3Selected]
			if prop then
				if prop.isBack then goBack(self)
				else AdjustGameplayCustomization(prop.entry, prop.suffix, -1); updateAll(self) end
			end
		elseif level2Open then
			goBack(self)
		end
		return true
	elseif button == "DeviceButton_enter" or button == "DeviceButton_start" then
		if level3Open then
			local properties = getLevel3Rows(selectedElement, selectedCategory)
			local prop = properties[lvl3Selected]
			if prop and prop.isBack then goBack(self) end
		elseif not level2Open then
			selectedElement = elementList[lvl1Selected]
			if selectedElement then
				level2Open = true
				level3Open = false
				lvl2Selected = 2
				lvl2FirstVisible = 1
				selectedCategory = nil
				editingEntry = entryForElementBounds(selectedElement)
				SelectGameplayCustomizationEntry(editingEntry)
				updateAll(self)
			end
		elseif not level3Open then
			local categories = getLevel2Rows(selectedElement)
			selectedCategory = categories[lvl2Selected]
			if selectedCategory == "Back" then goBack(self)
			elseif selectedCategory then
				level3Open = true
				lvl3Selected = 2
				lvl3FirstVisible = 1
				editingEntry = entryForElementBounds(selectedElement, selectedCategory)
				SelectGameplayCustomizationEntry(editingEntry)
				updateAll(self)
			end
		end
		return true
	elseif button == "DeviceButton_escape" or button == "DeviceButton_back" then
		if goBack(self) then return true end
		return false
	elseif button == "DeviceButton_backspace" then
		if level3Open then
			local properties = getLevel3Rows(selectedElement, selectedCategory)
			local prop = properties[lvl3Selected]
			if prop and not prop.isBack then
				ResetGameplayCustomizationProperty(prop.entry, prop.suffix)
				SelectGameplayCustomizationEntry(prop.entry)
				updateAll(self)
				return true
			end
		end
	end

	return false
end

local function makeRow1(i)
	return Def.ActorFrame {
		Name = "Row" .. i,
		InitCommand = function(self) self:xy(0, (i - 1) * rowH) end,
		Def.Quad {
			Name = "Backing",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(2, 1):zoomto(w1 - 4, rowH - 2)
					:diffuse(color("1,1,1,0.06"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Text",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(6, rowH / 2)
					:zoom(0.38):maxwidth((w1 - 14) / 0.38):shadowlength(1)
			end
		}
	}
end

local function makeRow2(i)
	return Def.ActorFrame {
		Name = "Row" .. i,
		InitCommand = function(self) self:xy(0, (i - 1) * rowH) end,
		Def.Quad {
			Name = "Backing",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(2, 1):zoomto(w2 - 4, rowH - 2)
					:diffuse(color("1,1,1,0.06"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Text",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(6, rowH / 2)
					:zoom(0.38):maxwidth((w2 - 12) / 0.38):shadowlength(1)
			end
		}
	}
end

local function makeRow3(i)
	return Def.ActorFrame {
		Name = "Row" .. i,
		InitCommand = function(self) self:xy(0, (i - 1) * rowH) end,
		Def.Quad {
			Name = "Backing",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(2, 1):zoomto(w3 - 4, rowH - 2)
					:diffuse(color("1,1,1,0.06"))
			end
		},
		-- Left end: Label
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(6, rowH / 2)
					:zoom(0.38):maxwidth(96 / 0.38):shadowlength(1)
			end
		},
		-- Right end: Left Arrow Button
		Def.ActorFrame {
			Name = "LeftBtn",
			InitCommand = function(self) self:xy(w3 - 88, 1) end,
			Def.Quad {
				Name = "Backing",
				InitCommand = function(self)
					self:halign(0):valign(0):zoomto(16, rowH - 2)
						:diffuse(color("1,1,1,0.08"))
				end
			},
			Def.Sprite {
				Name = "Icon",
				Texture = THEME:GetPathG("", "left.png"),
				InitCommand = function(self)
					self:xy(8, (rowH - 2) / 2):zoomto(10, 10)
				end
			}
		},
		-- Right end: Value
		LoadFont("Common Normal") .. {
			Name = "Value",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):xy(w3 - 47, rowH / 2)
					:zoom(0.36):maxwidth(44 / 0.36):shadowlength(1)
			end
		},
		-- Right end: Right Arrow Button
		Def.ActorFrame {
			Name = "RightBtn",
			InitCommand = function(self) self:xy(w3 - 22, 1) end,
			Def.Quad {
				Name = "Backing",
				InitCommand = function(self)
					self:halign(0):valign(0):zoomto(16, rowH - 2)
						:diffuse(color("1,1,1,0.08"))
				end
			},
			Def.Sprite {
				Name = "Icon",
				Texture = THEME:GetPathG("", "mp_play.png"),
				InitCommand = function(self)
					self:xy(8, (rowH - 2) / 2):zoomto(10, 10)
				end
			}
		}
	}
end

local function makeColumnBorder(w, h)
	return Def.ActorFrame {
		Name = "Border",
		Def.Quad {
			Name = "BTop",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, 0):zoomto(w, 1)
					:diffuse(HVColor.Accent):diffusealpha(0.45)
			end
		},
		Def.Quad {
			Name = "BBottom",
			InitCommand = function(self)
				self:halign(0):valign(1):xy(0, h):zoomto(w, 1)
					:diffuse(HVColor.Accent):diffusealpha(0.45)
			end
		},
		Def.Quad {
			Name = "BLeft",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, 0):zoomto(1, h)
					:diffuse(HVColor.Accent):diffusealpha(0.45)
			end
		},
		Def.Quad {
			Name = "BRight",
			InitCommand = function(self)
				self:halign(1):valign(0):xy(w, 0):zoomto(1, h)
					:diffuse(HVColor.Accent):diffusealpha(0.45)
			end
		}
	}
end

local function updateSelectedBounds(root)
	local bounds = root:GetChild("SelectedElementBounds")
	local border = GameplayCustomizationSelectedBorder
	local box
	if border then
		local ok, result = pcall(function() return border:GetChild("showybox") end)
		if ok then box = result end
	end
	if not box then
		bounds:visible(false)
		return
	end
	local ok, x, y, width, height = pcall(function()
		return box:GetTrueX(), box:GetTrueY(), box:GetZoomedWidth(), box:GetZoomedHeight()
	end)
	if not ok or not x or not y or not width or not height or width <= 0 or height <= 0 then
		bounds:visible(false)
		return
	end
	bounds:xy(x, y):visible(true)
	bounds:GetChild("Top"):y(-height / 2):zoomto(width, 2)
	bounds:GetChild("Bottom"):y(height / 2):zoomto(width, 2)
	bounds:GetChild("Left"):x(-width / 2):zoomto(2, height)
	bounds:GetChild("Right"):x(width / 2):zoomto(2, height)

	local mouseDown = INPUTFILTER:IsBeingPressed("Mouse 0", "Mouse")
	if not mouseDown then
		positionDrag = nil
		return
	end
	if not level3Open then
		positionDrag = nil
		return
	end
	local properties = getLevel3Rows(selectedElement, selectedCategory)
	local prop = properties[lvl3Selected]
	if not prop or prop.isBack or (prop.suffix ~= "X" and prop.suffix ~= "Y") then
		positionDrag = nil
		return
	end
	local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
	if positionDrag and positionDrag.entry == prop.entry and positionDrag.suffix == prop.suffix then
		local deltaX, deltaY = mx - positionDrag.x, my - positionDrag.y
		if deltaX ~= 0 or deltaY ~= 0 then
			local hasX, hasY = false, false
			for _, suffix in ipairs(prop.entry.data.properties or {}) do
				if suffix == "X" then hasX = true elseif suffix == "Y" then hasY = true end
			end
			if hasX and deltaX ~= 0 then MoveGameplayCustomizationPosition(prop.entry, "X", deltaX) end
			if hasY and deltaY ~= 0 then MoveGameplayCustomizationPosition(prop.entry, "Y", deltaY) end
			updateAll(root)
		end
	else
		local overBounds = mx >= x - width / 2 and mx <= x + width / 2
			and my >= y - height / 2 and my <= y + height / 2
		local overEditor = mx >= col1X and mx <= col3X + w3 and my >= overlayTop and my <= overlayTop + overlayH
		if overBounds and not overEditor then
			positionDrag = {entry = prop.entry, suffix = prop.suffix, x = mx, y = my}
		end
	end
	if positionDrag then positionDrag.x, positionDrag.y = mx, my end
end

local t = Def.ActorFrame {
	Name = "CustomizeGameplayTree",
	OnCommand = function(self)
		if not allowed or isSync then self:visible(false); return end
		editorActive = true
		self:SetUpdateFunction(function(root)
			if editorActive then pcall(updateSelectedBounds, root) end
		end)
		GAMESTATE:SetAutoplay(true)
		snapshot = GetGameplayCustomizationSnapshot()
		for _, entry in ipairs(GetGameplayCustomizationEntries()) do addElementEntry(entry) end
		rebuildElementList()
		SCREENMAN:GetTopScreen():AddInputCallback(function(event) return input(self, event) end)
		updateAll(self)
	end,
	OffCommand = function(self)
		editorActive = false
		self:SetUpdateFunction(nil)
		positionDrag = nil
		if allowed then
			SavePlayerConfig(pn_to_profile_slot(PLAYER_1))
			GAMESTATE:SetAutoplay(false)
		end
		SelectGameplayCustomizationEntry(nil)
	end,

	-- Column 1: Elements (Root Level)
	Def.ActorFrame {
		Name = "Col1",
		InitCommand = function(self) self:xy(col1X, overlayTop) end,
		Def.Quad {
			Name = "Panel",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, 0):zoomto(w1, overlayH)
					:diffuse(color("0.02,0.03,0.07,0.55"))
			end
		},
		makeColumnBorder(w1, overlayH),
		Def.Quad {
			Name = "HeaderBacking",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, 0):zoomto(w1, headerH)
					:diffuse(color("0.04,0.05,0.10,0.45"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Header",
			Text = "ELEMENTS",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(8, headerH / 2)
					:zoom(0.38):diffuse(HVColor.Accent):shadowlength(1)
			end
		},
		Def.Quad {
			Name = "HeaderDivider",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, headerH):zoomto(w1, 1)
					:diffuse(HVColor.Border or color("0.2,0.2,0.2,1")):diffusealpha(0.35)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "ScrollUp",
			Text = "^",
			InitCommand = function(self)
				self:halign(1):valign(0.5):xy(w1 - 8, headerH / 2):zoom(0.32):diffusealpha(0.7):visible(false)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "ScrollDown",
			Text = "v",
			InitCommand = function(self)
				self:halign(1):valign(0.5):xy(w1 - 8, overlayH - 12):zoom(0.32):diffusealpha(0.7):visible(false)
			end
		},
		Def.ActorFrame {
			Name = "Rows",
			InitCommand = function(self) self:xy(0, listTopOffset) end,
			unpack((function()
				local r = {}
				for i = 1, maxRows do r[#r + 1] = makeRow1(i) end
				return r
			end)())
		},
		Def.Quad {
			Name = "FooterDivider",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, overlayH - 24):zoomto(w1, 1)
					:diffuse(HVColor.Border or color("0.2,0.2,0.2,1")):diffusealpha(0.35)
			end
		},
		Def.ActorFrame {
			Name = "RevertBtn",
			InitCommand = function(self) self:xy(6, overlayH - 21) end,
			Def.Quad {
				Name = "Backing",
				InitCommand = function(self)
					self:halign(0):valign(0):zoomto(66, 18)
						:diffuse(color("1,1,1,0.08"))
				end
			},
			LoadFont("Common Normal") .. {
				Name = "Text",
				Text = "Revert",
				InitCommand = function(self)
					self:halign(0.5):valign(0.5):xy(33, 9):zoom(0.32):shadowlength(1)
				end
			}
		},
		Def.ActorFrame {
			Name = "ResetBtn",
			InitCommand = function(self) self:xy(78, overlayH - 21) end,
			Def.Quad {
				Name = "Backing",
				InitCommand = function(self)
					self:halign(0):valign(0):zoomto(68, 18)
						:diffuse(color("1,1,1,0.08"))
				end
			},
			LoadFont("Common Normal") .. {
				Name = "Text",
				Text = "Reset All",
				InitCommand = function(self)
					self:halign(0.5):valign(0.5):xy(34, 9):zoom(0.32):shadowlength(1)
				end
			}
		}
	},

	-- Column 2: Categories (Sub Level)
	Def.ActorFrame {
		Name = "Col2",
		InitCommand = function(self) self:xy(col2X, overlayTop):visible(false) end,
		Def.Quad {
			Name = "Panel",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, 0):zoomto(w2, overlayH)
					:diffuse(color("0.02,0.03,0.07,0.55"))
			end
		},
		makeColumnBorder(w2, overlayH),
		Def.Quad {
			Name = "HeaderBacking",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, 0):zoomto(w2, headerH)
					:diffuse(color("0.04,0.05,0.10,0.45"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Header",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(8, headerH / 2)
					:zoom(0.38):maxwidth((w2 - 16) / 0.38):diffuse(HVColor.Accent):shadowlength(1)
			end
		},
		Def.Quad {
			Name = "HeaderDivider",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, headerH):zoomto(w2, 1)
					:diffuse(HVColor.Border or color("0.2,0.2,0.2,1")):diffusealpha(0.35)
			end
		},
		Def.ActorFrame {
			Name = "Rows",
			InitCommand = function(self) self:xy(0, listTopOffset) end,
			unpack((function()
				local r = {}
				for i = 1, maxRows do r[#r + 1] = makeRow2(i) end
				return r
			end)())
		},
		Def.Quad {
			Name = "FooterDivider",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, overlayH - 24):zoomto(w2, 1)
					:diffuse(HVColor.Border or color("0.2,0.2,0.2,1")):diffusealpha(0.35)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Footer",
			Text = "Select Category",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):xy(w2 / 2, overlayH - 12)
					:zoom(0.28):diffusealpha(0.60):shadowlength(1)
			end
		}
	},

	-- Column 3: Parameters (Leaf Level)
	Def.ActorFrame {
		Name = "Col3",
		InitCommand = function(self) self:xy(col3X, overlayTop):visible(false) end,
		Def.Quad {
			Name = "Panel",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, 0):zoomto(w3, overlayH)
					:diffuse(color("0.02,0.03,0.07,0.55"))
			end
		},
		makeColumnBorder(w3, overlayH),
		Def.Quad {
			Name = "HeaderBacking",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, 0):zoomto(w3, headerH)
					:diffuse(color("0.04,0.05,0.10,0.45"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Header",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(8, headerH / 2)
					:zoom(0.38):maxwidth((w3 - 16) / 0.38):diffuse(HVColor.Accent):shadowlength(1)
			end
		},
		Def.Quad {
			Name = "HeaderDivider",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, headerH):zoomto(w3, 1)
					:diffuse(HVColor.Border or color("0.2,0.2,0.2,1")):diffusealpha(0.35)
			end
		},
		Def.ActorFrame {
			Name = "Rows",
			InitCommand = function(self) self:xy(0, listTopOffset) end,
			unpack((function()
				local r = {}
				for i = 1, maxRows do r[#r + 1] = makeRow3(i) end
				return r
			end)())
		},
		Def.Quad {
			Name = "FooterDivider",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, overlayH - 24):zoomto(w3, 1)
					:diffuse(HVColor.Border or color("0.2,0.2,0.2,1")):diffusealpha(0.35)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Footer",
			Text = "Backspace: Default",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):xy(w3 / 2, overlayH - 12)
					:zoom(0.28):diffusealpha(0.60):shadowlength(1)
			end
		}
	},

	Def.Actor {
		Name = "ResetTimer",
		ResetExpiredCommand = function(self)
			resetArmed = false
			updateAll(self:GetParent())
		end
	},

	Def.ActorFrame {
		Name = "SelectedElementBounds",
		InitCommand = function(self)
			self:visible(false)
		end,
		Def.Quad { Name = "Top", InitCommand = function(self) self:diffuse(HVColor.Accent) end },
		Def.Quad { Name = "Bottom", InitCommand = function(self) self:diffuse(HVColor.Accent) end },
		Def.Quad { Name = "Left", InitCommand = function(self) self:diffuse(HVColor.Accent) end },
		Def.Quad { Name = "Right", InitCommand = function(self) self:diffuse(HVColor.Accent) end }
	}
}

return t
