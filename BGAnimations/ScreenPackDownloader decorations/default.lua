--- Holographic Void: ScreenPackDownloader Decorations
-- Redesigned modern cyberpunk/holographic interface.
-- Full interactive pack browser with:
--   - Search by name (keyboard input)
--   - Paginated pack list via PackList API
--   - Downloaded pack detection via SONGMAN:DoesSongGroupExist()
--   - Download / queue management
--   - Average difficulty, song count, pack size columns
--   - Real-time download progress and status badges
--   - Bundle & multi-tag filtering with AND/OR logic
--   - Keyboard & mouse navigation
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

local t = Def.ActorFrame {
	Name = "PackDownloaderUI"
}

-- Color palette matching Theme Options
local installedColor = color("0.4,0.85,0.45,1")
local dimText = color("0.45,0.47,0.52,1")
local subText = color("0.65,0.68,0.74,1")
local mainText = color("0.85,0.88,0.92,1")
local brightText = color("1,1,1,1")
local borderColor = color("0.16,0.18,0.22,0.8")
local rowHilight = color("0.10,0.12,0.18,0.95")
local rowNormal = color("0.04,0.05,0.07,0.5")
local rowAlt = color("0.06,0.07,0.09,0.5")
local rowInstalled = color("0.04,0.08,0.05,0.6")
local externalDownloadThreshold = 2000000000
local externalDownloadColor = color("1,0.65,0.2,1")

-- =========================================================================
-- GEOMETRY & LAYOUT CONSTANTS (Strictly bounded to prevent overflow)
-- =========================================================================
local marginX = 20
local totalW = SCREEN_WIDTH - marginX * 2
local headerTop = 14
local headerLineY = 48

local toolbarY = 66
local toolbarH = 26

local listTop = 84
local listBottom = SCREEN_HEIGHT - 28
local listH = listBottom - listTop
local listW = totalW
local listCenterY = listTop + listH / 2

local packsPerPage = 14
local rowH = math.floor((listH - 26) / packsPerPage)
local rowsStartY = listTop + 26

-- Relative column offsets from center of list
local colIdxX = -listW / 2 + 16
local colNameX = -listW / 2 + 44
local colAvgX = listW * 0.12
local colSongsX = listW * 0.22
local colSizeX = listW * 0.33
local colStatusX = listW / 2 - 56

-- Banner sizing inside row
local bannerWidth = math.min(120, math.floor(listW * 0.14))

-- =========================================================================
-- STATE
-- =========================================================================
local packList = PackList:new()
local nameInput = ""
local selectedRow = 1
local currentPacks = {}
local installedFlags = {}
local sortColumn = "name"
local sortAscending = true
packList.sortColumn = "name"
packList.sortIsAscending = true
local isSearching = false
local selectLastRowOnPageLoad = false

-- Bundle Selector State
local availableBundles = {"All"}
local currentBundleIndex = 1
local isBundleListOpen = false

local function updateAvailableBundles()
	local alltags = DLMAN:GetPackTags()
	local bundles = alltags["pack_bundle"]
	availableBundles = {"All"}
	if bundles then
		for _, b in ipairs(bundles) do
			table.insert(availableBundles, b:sub(1,1):upper() .. b:sub(2))
		end
	end
end
updateAvailableBundles()

-- Tag Selector State
local selectedTags = {}
local tagsMatchAny = true
local isTagListOpen = false
local availableTags = {"All"}
local availableTagsOrig = {"All"}

local function updateAvailableTags()
	local alltags = DLMAN:GetPackTags()
	availableTags = {"All"}
	availableTagsOrig = {"All"}

	local categories = {"global_keyCount", "global_skillset", "pack_tag", "etterna_tag"}
	for _, cat in ipairs(categories) do
		local tags = alltags[cat]
		if tags then
			if cat == "global_keyCount" then
				table.sort(tags, function(a, b)
					local an = tonumber(a:match("%d+")) or 0
					local bn = tonumber(b:match("%d+")) or 0
					return an < bn
				end)
			else
				table.sort(tags)
			end

			for _, tg in ipairs(tags) do
				local label = tg
				if cat == "global_keyCount" and not tg:find("[kK]$") then
					label = tg .. "K"
				end
				table.insert(availableTags, label:sub(1,1):upper() .. label:sub(2))
				table.insert(availableTagsOrig, tg)
			end
		end
	end
end
updateAvailableTags()

-- Check if a pack is installed locally
local function isPackInstalled(pack)
	if not pack then return false end
	return SONGMAN:DoesSongGroupExist(pack:GetName())
end

-- Check active downloads
local function isPackDownloading(pack)
	if not pack then return false end
	local downloadingPacks = DLMAN:GetDownloadingPacks()
	if not downloadingPacks then return false end
	for _, downloadingPack in ipairs(downloadingPacks) do
		if downloadingPack:GetName() == pack:GetName() then
			return true
		end
	end
	return false
end

local sortKeys = {
	name = "name",
	avg = "overall",
	songs = "song_count",
	size = "bytes",
}

local function chooseSort(column)
	if sortColumn == column then
		sortAscending = not sortAscending
	else
		sortColumn = column
		sortAscending = true
	end
	packList.sortColumn = sortKeys[sortColumn]
	packList.sortIsAscending = sortAscending
	packList:FilterAndSearch(nameInput, packList.lastTags or {}, packList.tagsMatchAny, packsPerPage)
end

-- =========================================================================
-- 1. BACKGROUND: OLED BLACK WITH GRID & PARTICLES
-- =========================================================================
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}

for i = 1, 8 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, (SCREEN_HEIGHT / 9) * i)
				:zoomto(SCREEN_WIDTH, 1):diffuse(getAccent()):diffusealpha(0.06)
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if params and params.Name == "HV_AccentColor" then
				self:stoptweening():linear(0.12):diffuse(getAccent()):diffusealpha(0.06)
			end
		end
	}
end

t[#t + 1] = LoadActor("../_particles.lua")

-- =========================================================================
-- 2. TOP HEADER & BREADCRUMB BAR (Matching Theme Options)
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "Header",
	-- Brand / Kicker
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX, headerTop):halign(0):zoom(0.28)
				:diffuse(getAccent()):diffusealpha(0.85)
			self:settext("HOLOGRAPHIC VOID  //  PACK REPOSITORY")
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if params and params.Name == "HV_AccentColor" then
				self:stoptweening():linear(0.12):diffuse(getAccent()):diffusealpha(0.85)
			end
		end
	},
	-- Screen Title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX, headerTop + 14):halign(0):zoom(0.62):diffuse(color("1,1,1,1"))
			self:settext("PACK DOWNLOADER")
		end,
	},
	-- Screen Subtitle
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(marginX + 225, headerTop + 17):halign(0):zoom(0.32)
				:diffuse(color("0.65,0.68,0.74,0.85"))
			self:settext("Search, filter, and install new packs.")
		end,
	},
	-- Glow line behind header divider
	Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, headerLineY):zoomto(totalW, 3)
				:diffuse(getAccent()):diffusealpha(0.18)
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if params and params.Name == "HV_AccentColor" then
				self:stoptweening():linear(0.12):diffuse(getAccent()):diffusealpha(0.18)
			end
		end
	},
	-- Header Divider Line
	Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, headerLineY):zoomto(totalW, 1)
				:diffuse(getAccent()):diffusealpha(0.65)
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if params and params.Name == "HV_AccentColor" then
				self:stoptweening():linear(0.12):diffuse(getAccent()):diffusealpha(0.65)
			end
		end
	},
}

-- =========================================================================
-- 3. TOOLBAR & CONTROLS DECK
-- =========================================================================
local searchBarW = math.floor(totalW * 0.38)
local searchBarX = marginX + searchBarW / 2

local bundleBtnW = 110
local bundleBtnX = searchBarX + searchBarW / 2 + 8 + bundleBtnW / 2

local tagBtnW = 106
local tagBtnX = bundleBtnX + bundleBtnW / 2 + 8 + tagBtnW / 2

local cancelBtnW = 92
local cancelCurX = SCREEN_WIDTH - marginX - cancelBtnW - 8 - cancelBtnW / 2
local cancelAllX = SCREEN_WIDTH - marginX - cancelBtnW / 2

-- Search Bar
t[#t + 1] = Def.ActorFrame {
	Name = "SearchBar",
	InitCommand = function(self) self:xy(searchBarX, toolbarY) end,

	-- Search Input Backing
	Def.Quad {
		Name = "SearchBg",
		InitCommand = function(self)
			self:zoomto(searchBarW, toolbarH):diffuse(color("0.06,0.07,0.09,0.95"))
		end,
		UpdateSearchCommand = function(self)
			if isSearching then
				self:diffuse(color("0.08,0.10,0.14,0.98"))
			else
				self:diffuse(color("0.06,0.07,0.09,0.95"))
			end
		end
	},
	-- Border Outline
	Def.ActorFrame {
		makePanelBorder(searchBarW, toolbarH, color("0.18,0.20,0.24,0.8")),
	},
	-- Left Glowing Indicator Bar when searching
	Def.Quad {
		Name = "ActiveBar",
		InitCommand = function(self)
			self:halign(0):x(-searchBarW / 2 + 1.5):zoomto(3, toolbarH - 4)
				:diffuse(getAccent()):diffusealpha(0.9):visible(false)
		end,
		UpdateSearchCommand = function(self)
			self:visible(isSearching)
			self:diffuse(getAccent())
		end
	},
	-- Search Icon Sprite
	Def.Sprite {
		Texture = THEME:GetPathG("", "search.png"),
		InitCommand = function(self)
			self:x(-searchBarW / 2 + 14):zoom(0.30):diffuse(color("0.65,0.68,0.74,1"))
		end,
		UpdateSearchCommand = function(self)
			self:diffuse(isSearching and getAccent() or color("0.65,0.68,0.74,1"))
		end
	},
	-- Prefix Label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):x(-searchBarW / 2 + 30):zoom(0.32):diffuse(getAccent())
			self:settext("SEARCH:")
		end,
	},
	-- User Input Text / Placeholder
	LoadFont("Common Normal") .. {
		Name = "SearchText",
		InitCommand = function(self)
			self:halign(0):x(-searchBarW / 2 + 78):zoom(0.38):diffuse(mainText)
		end,
		UpdateSearchCommand = function(self)
			if nameInput == "" then
				self:settext(isSearching and "Type to search..." or "Click to search...")
				self:diffuse(dimText)
			else
				self:settext(nameInput .. (isSearching and "_" or ""))
				self:diffuse(brightText)
			end
		end
	},
}

-- Bundle Selector Button
t[#t + 1] = Def.ActorFrame {
	Name = "BundleSelector",
	InitCommand = function(self) self:xy(bundleBtnX, toolbarY) end,

	Def.Quad {
		Name = "BundleBtnBG",
		InitCommand = function(self)
			self:zoomto(bundleBtnW, toolbarH):diffuse(color("0.08,0.09,0.12,0.95"))
		end,
		UpdateCommand = function(self)
			if isBundleListOpen then
				self:diffuse(getAccent()):diffusealpha(0.28)
			else
				self:diffuse(color("0.08,0.09,0.12,0.95"))
			end
		end
	},
	Def.ActorFrame {
		makePanelBorder(bundleBtnW, toolbarH, color("0.18,0.20,0.24,0.8")),
	},
	LoadFont("Common Normal") .. {
		Name = "BundleLabel",
		InitCommand = function(self)
			self:zoom(0.29):diffuse(subText):settext("BUNDLE:")
			self:x(-bundleBtnW / 2 + 6):halign(0)
		end
	},
	LoadFont("Common Normal") .. {
		Name = "CurrentBundleText",
		InitCommand = function(self)
			self:zoom(0.32):diffuse(brightText)
			self:x(-bundleBtnW / 2 + 48):halign(0):maxwidth((bundleBtnW - 62) / 0.32)
			self:settext(availableBundles[currentBundleIndex]:upper())
		end,
		UpdateCommand = function(self)
			self:settext(availableBundles[currentBundleIndex]:upper())
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(bundleBtnW / 2 - 8):zoom(0.26):diffuse(dimText):settext("▼")
		end
	}
}

-- Tag Selector Button
t[#t + 1] = Def.ActorFrame {
	Name = "TagSelector",
	InitCommand = function(self) self:xy(tagBtnX, toolbarY) end,

	Def.Quad {
		Name = "TagBtnBG",
		InitCommand = function(self)
			self:zoomto(tagBtnW, toolbarH):diffuse(color("0.08,0.09,0.12,0.95"))
		end,
		UpdateCommand = function(self)
			if isTagListOpen then
				self:diffuse(getAccent()):diffusealpha(0.28)
			else
				self:diffuse(color("0.08,0.09,0.12,0.95"))
			end
		end
	},
	Def.ActorFrame {
		makePanelBorder(tagBtnW, toolbarH, color("0.18,0.20,0.24,0.8")),
	},
	LoadFont("Common Normal") .. {
		Name = "TagLabel",
		InitCommand = function(self)
			self:zoom(0.29):diffuse(subText):settext("TAGS:")
			self:x(-tagBtnW / 2 + 6):halign(0)
		end
	},
	LoadFont("Common Normal") .. {
		Name = "CurrentTagText",
		InitCommand = function(self)
			self:zoom(0.32):diffuse(brightText)
			self:x(-tagBtnW / 2 + 38):halign(0):maxwidth((tagBtnW - 52) / 0.32)
			self:settext("ALL")
		end,
		UpdateCommand = function(self)
			local count = 0
			for _ in pairs(selectedTags) do count = count + 1 end
			if count == 0 then
				self:settext("ALL"):diffuse(brightText)
			else
				self:settextf("%d SEL", count):diffuse(getAccent())
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(tagBtnW / 2 - 8):zoom(0.26):diffuse(dimText):settext("▼")
		end
	}
}

-- Cancel Current Download Button
t[#t + 1] = Def.ActorFrame {
	Name = "CancelCurrent",
	InitCommand = function(self) self:xy(cancelCurX, toolbarY) end,
	Def.Quad {
		Name = "BG",
		InitCommand = function(self)
			self:zoomto(cancelBtnW, toolbarH):diffuse(color("0.15,0.06,0.06,0.85"))
		end,
		UpdateCommand = function(self)
			local dls = DLMAN:GetDownloads()
			if dls and #dls > 0 then
				self:diffusealpha(0.9)
			else
				self:diffusealpha(0.3)
			end
		end
	},
	Def.ActorFrame {
		makePanelBorder(cancelBtnW, toolbarH, color("0.35,0.15,0.15,0.8")),
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.24):settext("CANCEL CUR"):diffuse(color("1,0.5,0.5,1"))
		end,
		UpdateCommand = function(self)
			local dls = DLMAN:GetDownloads()
			if dls and #dls > 0 then
				self:diffuse(color("1,0.5,0.5,1"))
			else
				self:diffuse(dimText)
			end
		end
	}
}

-- Cancel All Downloads Button
t[#t + 1] = Def.ActorFrame {
	Name = "CancelAll",
	InitCommand = function(self) self:xy(cancelAllX, toolbarY) end,
	Def.Quad {
		Name = "BG",
		InitCommand = function(self)
			self:zoomto(cancelBtnW, toolbarH):diffuse(color("0.18,0.05,0.05,0.85"))
		end,
		UpdateCommand = function(self)
			local queued = DLMAN:GetQueuedPacks()
			local dls = DLMAN:GetDownloads()
			if (queued and #queued > 0) or (dls and #dls > 0) then
				self:diffusealpha(0.9)
			else
				self:diffusealpha(0.3)
			end
		end
	},
	Def.ActorFrame {
		makePanelBorder(cancelBtnW, toolbarH, color("0.45,0.12,0.12,0.8")),
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.24):settext("CANCEL ALL"):diffuse(color("1,0.3,0.3,1"))
		end,
		UpdateCommand = function(self)
			local queued = DLMAN:GetQueuedPacks()
			local dls = DLMAN:GetDownloads()
			if (queued and #queued > 0) or (dls and #dls > 0) then
				self:diffuse(color("1,0.3,0.3,1"))
			else
				self:diffuse(dimText)
			end
		end
	}
}

-- =========================================================================
-- 4. MAIN PACK LIST GLASS CONTAINER (Bounded strictly inside viewport)
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "MainListPanel",
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, listCenterY) end,
	-- Glass Backing
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(listW, listH):diffuse(color("0.04,0.04,0.05,0.92"))
		end,
	},
	-- Border Outline
	Def.ActorFrame {
		makePanelBorder(listW, listH, color("0.16,0.18,0.22,0.8")),
	},
	-- Corner Accent Brackets
	Def.ActorFrame {
		makeCornerBrackets(listW, listH, 8, 1.5),
	},
}

-- Column Headers Banner
t[#t + 1] = Def.ActorFrame {
	Name = "ColumnHeaders",
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, listTop + 13) end,
	UpdateSortHeadersMessageCommand = function(self) self:playcommand("Update") end,
	UpdateCommand = function(self)
		local arrow = sortAscending and " ▲" or " ▼"
		self:GetChild("NameHeader"):settext("PACK NAME" .. (sortColumn == "name" and arrow or ""))
		self:GetChild("AvgHeader"):settext("AVG MSD" .. (sortColumn == "avg" and arrow or ""))
		self:GetChild("SongsHeader"):settext("SONGS" .. (sortColumn == "songs" and arrow or ""))
		self:GetChild("SizeHeader"):settext("SIZE" .. (sortColumn == "size" and arrow or ""))
	end,

	-- Header Backing
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(listW - 4, 24):diffuse(color("0.07,0.07,0.09,0.95"))
		end,
	},
	-- Bottom Divider Line
	Def.Quad {
		InitCommand = function(self)
			self:y(12):zoomto(listW - 4, 1):diffuse(color("0.18,0.20,0.24,0.8"))
		end,
	},

	-- Index Header
	LoadFont("Common Normal") .. {
		Name = "IdxHeader",
		InitCommand = function(self) self:halign(0):x(colIdxX):zoom(0.24):diffuse(getAccent()):settext("#") end
	},
	-- Name Header
	LoadFont("Common Normal") .. {
		Name = "NameHeader",
		InitCommand = function(self) self:halign(0):x(colNameX):zoom(0.24):diffuse(getAccent()):settext("PACK NAME") end
	},
	-- Avg MSD Header
	LoadFont("Common Normal") .. {
		Name = "AvgHeader",
		InitCommand = function(self)
			self:halign(1):x(colAvgX):zoom(0.24):diffuse(getAccent()):settext("AVG MSD")
			if not HV.ShowMSD() then self:visible(false) end
		end
	},
	-- Songs Header
	LoadFont("Common Normal") .. {
		Name = "SongsHeader",
		InitCommand = function(self) self:halign(1):x(colSongsX):zoom(0.24):diffuse(getAccent()):settext("SONGS") end
	},
	-- Size Header
	LoadFont("Common Normal") .. {
		Name = "SizeHeader",
		InitCommand = function(self) self:halign(1):x(colSizeX):zoom(0.24):diffuse(getAccent()):settext("SIZE") end
	},
	-- Status Header
	LoadFont("Common Normal") .. {
		Name = "StatusHeader",
		InitCommand = function(self) self:halign(0.5):x(colStatusX):zoom(0.24):diffuse(getAccent()):settext("STATUS") end
	},
}

-- =========================================================================
-- 5. PACK LIST ROWS
-- =========================================================================
local packListFrame = Def.ActorFrame {
	Name = "PackRows",
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, rowsStartY) end,

	PackListRequestFinishedMessageCommand = function(self)
		currentPacks = packList:GetPacks() or {}
		installedFlags = {}
		for i, pack in ipairs(currentPacks) do
			installedFlags[i] = isPackInstalled(pack)
		end
		if selectLastRowOnPageLoad then
			selectedRow = math.min(#currentPacks, packsPerPage)
			selectLastRowOnPageLoad = false
		else
			selectedRow = 1
		end
		self:playcommand("RefreshRows")
		MESSAGEMAN:Broadcast("UpdateSortHeaders")
	end,

	RefreshRowsCommand = function(self)
		for i = 1, packsPerPage do
			self:playcommand("UpdateRow" .. i)
		end
		MESSAGEMAN:Broadcast("UpdatePageInfo")
	end
}

for i = 1, packsPerPage do
	local rowCenterY = (i - 0.5) * rowH

	packListFrame[#packListFrame + 1] = Def.ActorFrame {
		Name = "Row" .. i,
		InitCommand = function(self) self:y(rowCenterY) end,

		-- Row Background
		Def.Quad {
			Name = "RowBG",
			InitCommand = function(self)
				self:zoomto(listW - 8, rowH - 2)
				if i % 2 == 0 then self:diffuse(rowAlt) else self:diffuse(rowNormal) end
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if i == selectedRow and pack then
					self:diffuse(rowHilight)
				elseif pack and installedFlags[i] then
					self:diffuse(rowInstalled)
				elseif i % 2 == 0 then
					self:diffuse(rowAlt)
				else
					self:diffuse(rowNormal)
				end
			end
		},

		-- Left Glowing Indicator Bar for Selected Row
		Def.Quad {
			Name = "SelectBar",
			InitCommand = function(self)
				self:halign(0):x(-(listW - 8) / 2 + 1.5):zoomto(3, rowH - 4)
					:diffuse(getAccent()):diffusealpha(0.95):visible(false)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				self:visible(i == selectedRow and currentPacks[i] ~= nil)
				self:diffuse(getAccent())
			end
		},

		-- Pack Banner Sprite (Behind pack name)
		Def.Sprite {
			Name = "PackBanner",
			InitCommand = function(self)
				self:halign(0):x(colNameX):zoomto(bannerWidth, rowH - 4)
					:scaletoclipped(bannerWidth, rowH - 4):diffusealpha(0)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if not pack then
					self:diffusealpha(0)
					self:GetParent():GetChild("PackBannerShade"):visible(false)
					return
				end
				local packName = pack:GetName()
				if self.hvBannerPackName == packName then return end
				self.hvBannerPackName = packName
				self:diffusealpha(0)
				self:GetParent():GetChild("PackBannerShade"):visible(false)
				pack:DownloadBanner(function(success, texture)
					if not success or not texture then return end
					local currentPack = currentPacks[i]
					if not currentPack or currentPack:GetName() ~= packName then return end
					self:SetTexture(texture)
					self:scaletoclipped(bannerWidth, rowH - 4)
					self:diffusealpha(1)
					self:GetParent():GetChild("PackBannerShade"):visible(true)
				end)
			end
		},
		-- Dark Glass Shade Overlay on banner
		Def.Quad {
			Name = "PackBannerShade",
			InitCommand = function(self)
				self:halign(0):x(colNameX):zoomto(bannerWidth, rowH - 4)
					:diffuse(color("0.02,0.02,0.03,0.65")):visible(false)
			end
		},

		-- Row Index Number
		LoadFont("Common Normal") .. {
			Name = "RowIdx",
			InitCommand = function(self)
				self:halign(0):x(colIdxX):zoom(0.30):diffuse(dimText)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					local pageOffset = (packList:GetCurrentPage() - 1) * packsPerPage
					self:settextf("%02d", pageOffset + i)
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- Pack Name
		LoadFont("Common Normal") .. {
			Name = "PackName",
			InitCommand = function(self)
				self:halign(0):x(colNameX + 8):zoom(0.38):diffuse(mainText)
					:maxwidth((colAvgX - colNameX - 24) / 0.38)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					self:settext(pack:GetName())
					if installedFlags[i] then
						self:diffuse(installedColor)
					elseif i == selectedRow then
						self:diffuse(brightText)
					else
						self:diffuse(mainText)
					end
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- NSFW Red Badge
		LoadFont("Common Normal") .. {
			Name = "NSFWLabel",
			InitCommand = function(self)
				self:halign(0):x(colNameX + 8):y(7):zoom(0.22):diffuse(color("1,0.2,0.2,1"))
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack and pack:IsNSFW() then
					self:settext("[NSFW]")
					self:visible(true)
					self:GetParent():GetChild("PackName"):y(-4)
				else
					self:visible(false)
					self:GetParent():GetChild("PackName"):y(0)
				end
			end
		},

		-- Average MSD
		LoadFont("MSD 20px") .. {
			Name = "AvgMSD",
			InitCommand = function(self)
				self:halign(1):x(colAvgX):zoom(0.36):diffuse(subText)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				if not HV.ShowMSD() then
					self:visible(false)
					return
				end
				local pack = currentPacks[i]
				if pack then
					local avg = pack:GetAvgDifficulty()
					if avg and avg > 0 then
						self:settextf("%.1f", avg)
						if HVColor and HVColor.GetMSDRatingColor then
							self:diffuse(HVColor.GetMSDRatingColor(avg))
						end
					else
						self:settext("-")
						self:diffuse(dimText)
					end
					self:visible(HV.ShowMSD())
				else
					self:visible(false)
				end
			end
		},

		-- Song Count
		LoadFont("Common Normal") .. {
			Name = "SongCount",
			InitCommand = function(self)
				self:halign(1):x(colSongsX):zoom(0.34):diffuse(subText)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					local count = pack:GetSongCount()
					if count and count > 0 then
						self:settext(tostring(count))
						self:diffuse(subText)
					else
						self:settext("-"):diffuse(dimText)
					end
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- Pack Size
		LoadFont("Common Normal") .. {
			Name = "PackSize",
			InitCommand = function(self)
				self:halign(1):x(colSizeX):zoom(0.34):diffuse(subText)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					local bytes = pack:GetSize()
					if bytes and bytes > 0 then
						local mb = bytes / (1024 * 1024)
						if mb >= 1024 then
							self:settextf("%.1f GB", mb / 1024)
						else
							self:settextf("%.0f MB", mb)
						end
					else
						self:settext("--")
					end
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- External Download Notice Tag
		LoadFont("Common Normal") .. {
			Name = "ExternalDownloadNotice",
			InitCommand = function(self)
				self:halign(1):x(colSizeX):y(7):zoom(0.20):diffuse(externalDownloadColor)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack and pack:GetSize() > externalDownloadThreshold then
					self:settext("[EXTERNAL]")
					self:visible(true)
					self:GetParent():GetChild("PackSize"):y(-4)
				else
					self:visible(false)
					self:GetParent():GetChild("PackSize"):y(0)
				end
			end
		},

		-- Status Pill Badge
		Def.ActorFrame {
			Name = "StatusBadgeFrame",
			InitCommand = function(self) self:x(colStatusX) end,

			-- Status Badge Backing
			Def.Quad {
				Name = "BadgeBg",
				InitCommand = function(self)
					self:zoomto(88, rowH - 6):diffuse(color("0.08,0.09,0.12,0.85"))
				end,
				["UpdateRow" .. i .. "Command"] = function(self)
					local pack = currentPacks[i]
					if not pack then self:visible(false); return end
					self:visible(true)
					if installedFlags[i] then
						self:diffuse(color("0.04,0.15,0.07,0.8"))
					elseif isPackDownloading(pack) then
						self:diffuse(getAccent()):diffusealpha(0.25)
					elseif pack:IsQueued() then
						self:diffuse(color("0.08,0.12,0.18,0.85"))
					else
						self:diffuse(color("0.08,0.09,0.12,0.85"))
					end
				end
			},
			-- Status Badge Border
			Def.ActorFrame {
				Name = "BadgeBorder",
				makePanelBorder(88, rowH - 6, color("0.18,0.20,0.24,0.7")),
			},
			-- Status Text
			LoadFont("Common Normal") .. {
				Name = "StatusText",
				InitCommand = function(self)
					self:zoom(0.28):halign(0.5)
				end,
				["UpdateRow" .. i .. "Command"] = function(self)
					local pack = currentPacks[i]
					if pack then
						if installedFlags[i] then
							self:settext("INSTALLED"):diffuse(installedColor)
						elseif isPackDownloading(pack) then
							self:settext("DOWNLOADING"):diffuse(getAccent())
						elseif pack:IsQueued() then
							self:settext("QUEUED"):diffuse(getAccent())
						else
							self:settext("DOWNLOAD"):diffuse(subText)
						end
						self:visible(true)
					else
						self:visible(false)
					end
				end
			}
		},

		-- Progress Bar on row bottom
		Def.Quad {
			Name = "DLBar",
			InitCommand = function(self)
				self:halign(0):valign(1):y(rowH / 2 - 1):x(-(listW - 8) / 2)
					:zoomto(0, 2):diffuse(getAccent()):diffusealpha(0.85)
			end
		}
	}
end

t[#t + 1] = packListFrame

-- Status Text for Center of list
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "LoadingText",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, listCenterY):zoom(0.38):diffuse(subText):visible(false)
	end,
	PackListRequestFinishedMessageCommand = function(self)
		local packs = packList:GetPacks()
		if packs and #packs > 0 then
			self:visible(false)
		else
			if packList:GetTotalResults() == 0 then
				self:settext("No packs found matching your search criteria."):visible(true)
				self:diffuse(dimText)
			else
				self:visible(false)
			end
		end
	end,
	ShowLoadingCommand = function(self)
		-- Optional loading indicator
	end
}

-- =========================================================================
-- 6. DROPDOWN OVERLAYS (Bundle & Tag Selector Overlays)
-- =========================================================================
local bundleListW = 150
local bundleItemH = 20
local bundleListFrame = Def.ActorFrame {
	Name = "BundleListOverlay",
	InitCommand = function(self)
		self:xy(bundleBtnX, toolbarY + 16 + (bundleItemH * #availableBundles / 2))
		self:visible(false)
	end,
	UpdateCommand = function(self)
		self:visible(isBundleListOpen)
		self:y(toolbarY + 16 + (bundleItemH * #availableBundles / 2))
	end
}

bundleListFrame[#bundleListFrame + 1] = Def.Quad {
	InitCommand = function(self)
		self:zoomto(bundleListW, bundleItemH * #availableBundles)
		self:diffuse(color("0.05,0.06,0.08,0.98"))
	end
}
bundleListFrame[#bundleListFrame + 1] = Def.ActorFrame {
	makePanelBorder(bundleListW, bundleItemH * #availableBundles, color("0.22,0.25,0.32,0.95")),
}
bundleListFrame[#bundleListFrame + 1] = Def.ActorFrame {
	makeCornerBrackets(bundleListW, bundleItemH * #availableBundles, 6, 1.2),
}

for i, bundleName in ipairs(availableBundles) do
	bundleListFrame[#bundleListFrame + 1] = Def.ActorFrame {
		Name = "BundleItem" .. i,
		InitCommand = function(self)
			self:y((i - 1 - (#availableBundles - 1) / 2) * bundleItemH)
		end,

		Def.Quad {
			Name = "ItemBG",
			InitCommand = function(self)
				self:zoomto(bundleListW - 4, bundleItemH - 2):diffusealpha(0)
			end,
			UpdateCommand = function(self)
				if i == currentBundleIndex then
					self:diffuse(getAccent()):diffusealpha(0.25)
				else
					self:diffusealpha(0)
				end
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:zoom(0.32):diffuse(mainText):settext(bundleName:upper())
			end,
			UpdateCommand = function(self)
				if i == currentBundleIndex then
					self:diffuse(brightText)
				else
					self:diffuse(mainText)
				end
			end
		}
	}
end

t[#t + 1] = bundleListFrame

-- Tag List Overlay (Grid Layout)
local tagCols = 4
local tagItemW = 105
local tagItemH = 20
local tagListW = tagCols * tagItemW
local tagListFrame = Def.ActorFrame {
	Name = "TagListOverlay",
	InitCommand = function(self)
		self:xy(tagBtnX + tagBtnW / 2 - tagListW / 2, toolbarY + 16)
		self:visible(false)
	end,
	UpdateCommand = function(self)
		self:visible(isTagListOpen)
		local rows = math.ceil(#availableTags / tagCols)
		self:y(toolbarY + 16 + (tagItemH * rows / 2) + 14)
	end
}

tagListFrame[#tagListFrame + 1] = Def.Quad {
	Name = "ListBG",
	InitCommand = function(self)
		self:diffuse(color("0.05,0.06,0.08,0.98"))
	end,
	UpdateCommand = function(self)
		local rows = math.ceil(#availableTags / tagCols)
		self:zoomto(tagListW + 12, tagItemH * rows + 34)
	end
}
tagListFrame[#tagListFrame + 1] = Def.ActorFrame {
	Name = "ListBorder",
	UpdateCommand = function(self)
		local rows = math.ceil(#availableTags / tagCols)
		self:RemoveAllChildren()
		self:AddChild(makePanelBorder(tagListW + 12, tagItemH * rows + 34, color("0.22,0.25,0.32,0.95")))
		self:AddChild(makeCornerBrackets(tagListW + 12, tagItemH * rows + 34, 6, 1.2))
	end
}

-- AND/OR Toggle Button in tag overlay
tagListFrame[#tagListFrame + 1] = Def.ActorFrame {
	Name = "ConditionToggle",
	UpdateCommand = function(self)
		local rows = math.ceil(#availableTags / tagCols)
		self:y(-(tagItemH * rows / 2) - 4)
	end,

	Def.Quad {
		Name = "BtnBG",
		InitCommand = function(self)
			self:zoomto(tagListW, 18):diffuse(color("0.10,0.12,0.16,0.95"))
		end
	},
	Def.ActorFrame {
		makePanelBorder(tagListW, 18, color("0.18,0.20,0.24,0.8")),
	},
	LoadFont("Common Normal") .. {
		Name = "BtnText",
		InitCommand = function(self)
			self:zoom(0.30)
		end,
		UpdateCommand = function(self)
			self:settextf("FILTER LOGIC: %s  (CLICK TO TOGGLE)", tagsMatchAny and "MATCH ANY (OR)" or "MATCH ALL (AND)")
			self:diffuse(tagsMatchAny and getAccent() or color("1,0.75,0.4,1"))
		end
	}
}

for i = 1, 100 do
	tagListFrame[#tagListFrame + 1] = Def.ActorFrame {
		Name = "TagItem" .. i,
		UpdateCommand = function(self)
			local tag = availableTags[i]
			if tag then
				self:visible(true)
				local rows = math.ceil(#availableTags / tagCols)
				local r = math.floor((i - 1) / tagCols)
				local c = (i - 1) % tagCols
				self:xy((c - (tagCols - 1) / 2) * tagItemW,
					    (r - (rows - 1) / 2) * tagItemH + 10)
			else
				self:visible(false)
			end
		end,

		Def.Quad {
			Name = "ItemBG",
			InitCommand = function(self)
				self:zoomto(tagItemW - 4, tagItemH - 2):diffusealpha(0)
			end,
			UpdateCommand = function(self)
				local origTag = availableTagsOrig[i]
				if origTag and selectedTags[origTag] then
					self:diffuse(getAccent()):diffusealpha(0.28)
				else
					self:diffusealpha(0)
				end
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Text",
			InitCommand = function(self)
				self:zoom(0.30):diffuse(mainText)
			end,
			UpdateCommand = function(self)
				local tag = availableTags[i]
				if tag then
					self:settext(tag:upper())
					local origTag = availableTagsOrig[i]
					if selectedTags[origTag] then
						self:diffuse(brightText)
					else
						self:diffuse(mainText)
					end
				end
			end
		}
	}
end

t[#t + 1] = tagListFrame

-- =========================================================================
-- 7. NAVIGATION FOOTER BAR (Matching Theme Options)
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
	-- Left Page Info Pill
	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self)
			self:x(-SCREEN_WIDTH / 2 + marginX):halign(0):zoom(0.26):diffuse(color("0.65,0.68,0.74,1"))
		end,
		UpdatePageInfoMessageCommand = function(self)
			local page = packList:GetCurrentPage()
			local total = packList:GetTotalPages()
			local results = packList:GetTotalResults()
			if total > 0 then
				self:settextf("PAGE %d / %d   ·   %d PACKS FOUND", page, total, results)
			else
				if packList:IsAwaitingRequest() then
					self:settext("SEARCHING PACK ARCHIVE...")
				else
					self:settext("NO RESULTS MATCH SEARCH")
				end
			end
		end
	},
}

-- =========================================================================
-- 8. INPUT HANDLER & EVENT LOGIC
-- =========================================================================
t[#t + 1] = Def.ActorFrame {
	Name = "InputHandler",
	BeginCommand = function(self)
		packList:FilterAndSearch("", {}, true, packsPerPage)
		self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")

		local inputCallback = function(event)
			if event.type == "InputEventType_Release" then return end

			local btn = event.DeviceInput and event.DeviceInput.button or ""
			local gameBtn = event.button or ""

			-- Mouse wheel -> scroll rows up/down
			local scroll = GetMouseScrollDirection(btn)
			if scroll ~= 0 then
				if scroll < 0 then
					if selectedRow > 1 then
						selectedRow = selectedRow - 1
					else
						selectLastRowOnPageLoad = true
						if not packList:PrevPage() then
							selectLastRowOnPageLoad = false
						else
							self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")
						end
					end
				else
					local lastRow = math.min(#currentPacks, packsPerPage)
					if selectedRow < lastRow then
						selectedRow = selectedRow + 1
					elseif packList:NextPage() then
						self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")
					end
				end
				self:GetParent():GetChild("PackRows"):playcommand("RefreshRows")
				return
			end

			-- Mouse left click
			if IsMouseLeftClick(btn) then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()

				-- Check Bundle list overlay clicks
				if isBundleListOpen then
					for i = 1, #availableBundles do
						local itemY = toolbarY + 16 + (i - 0.5) * bundleItemH
						if mx >= bundleBtnX - bundleListW / 2 and mx <= bundleBtnX + bundleListW / 2
							and my >= itemY - bundleItemH / 2 and my <= itemY + bundleItemH / 2 then
							currentBundleIndex = i
							isBundleListOpen = false
							self:GetParent():GetChild("BundleSelector"):playcommand("Update")
							self:GetParent():GetChild("BundleListOverlay"):playcommand("Update")
							self:playcommand("DoSearch")
							return
						end
					end
					isBundleListOpen = false
					self:GetParent():GetChild("BundleSelector"):playcommand("Update")
					self:GetParent():GetChild("BundleListOverlay"):playcommand("Update")
					return
				end

				-- Check Tag list overlay clicks
				if isTagListOpen then
					local rows = math.ceil(#availableTags / tagCols)
					local gridOriginX = tagBtnX + tagBtnW / 2 - tagListW / 2
					local gridOriginY = toolbarY + 16 + (tagItemH * rows / 2) + 14
					local gridStartY = gridOriginY - (tagItemH * rows / 2) + 10

					-- Condition toggle
					local toggleY = gridOriginY - (tagItemH * rows / 2) - 4
					if mx >= gridOriginX - tagListW / 2 and mx <= gridOriginX + tagListW / 2
						and my >= toggleY - 9 and my <= toggleY + 9 then
						tagsMatchAny = not tagsMatchAny
						self:GetParent():playcommand("Update")
						self:playcommand("DoSearch")
						return
					end

					for i = 1, #availableTags do
						local r = math.floor((i - 1) / tagCols)
						local c = (i - 1) % tagCols
						local itemX = gridOriginX + (c - (tagCols - 1) / 2) * tagItemW
						local itemY = gridStartY + (r + 0.5) * tagItemH

						if mx >= itemX - tagItemW / 2 and mx <= itemX + tagItemW / 2
							and my >= itemY - tagItemH / 2 and my <= itemY + tagItemH / 2 then
							local tg = availableTagsOrig[i]
							if tg == "All" then
								selectedTags = {}
							else
								if selectedTags[tg] then
									selectedTags[tg] = nil
								else
									selectedTags[tg] = true
								end
							end
							self:GetParent():playcommand("Update")
							self:playcommand("DoSearch")
							return
						end
					end
					isTagListOpen = false
					self:GetParent():playcommand("Update")
					return
				end

				-- Bundle selector button
				if mx >= bundleBtnX - bundleBtnW / 2 and mx <= bundleBtnX + bundleBtnW / 2
					and my >= toolbarY - toolbarH / 2 and my <= toolbarY + toolbarH / 2 then
					isBundleListOpen = not isBundleListOpen
					isTagListOpen = false
					self:GetParent():GetChild("BundleSelector"):playcommand("Update")
					self:GetParent():GetChild("BundleListOverlay"):playcommand("Update")
					self:GetParent():GetChild("TagSelector"):playcommand("Update")
					self:GetParent():GetChild("TagListOverlay"):playcommand("Update")
					return
				end

				-- Tag selector button
				if mx >= tagBtnX - tagBtnW / 2 and mx <= tagBtnX + tagBtnW / 2
					and my >= toolbarY - toolbarH / 2 and my <= toolbarY + toolbarH / 2 then
					isTagListOpen = not isTagListOpen
					isBundleListOpen = false
					self:GetParent():playcommand("Update")
					return
				end

				-- Cancel Current button
				if mx >= cancelCurX - cancelBtnW / 2 and mx <= cancelCurX + cancelBtnW / 2
					and my >= toolbarY - toolbarH / 2 and my <= toolbarY + toolbarH / 2 then
					local dls = DLMAN:GetDownloads()
					if dls and dls[1] then
						dls[1]:Stop()
					end
					return
				end

				-- Cancel All button
				if mx >= cancelAllX - cancelBtnW / 2 and mx <= cancelAllX + cancelBtnW / 2
					and my >= toolbarY - toolbarH / 2 and my <= toolbarY + toolbarH / 2 then
					for _, p in ipairs(DLMAN:GetQueuedPacks()) do p:RemoveFromQueue() end
					for _, p in ipairs(DLMAN:GetDownloads()) do p:Stop() end
					for _, p in ipairs(DLMAN:GetDownloadingPacks()) do
						local dl = p:GetDownload()
						if dl then dl:Stop() end
					end
					return
				end

				-- Search bar click
				if mx >= searchBarX - searchBarW / 2 and mx <= searchBarX + searchBarW / 2
					and my >= toolbarY - toolbarH / 2 and my <= toolbarY + toolbarH / 2 then
					isSearching = true
					self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
					return
				else
					if isSearching then
						isSearching = false
						self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
					end
				end

				-- Column Headers click to sort
				if my >= listTop and my <= listTop + 26 then
					local colTable = {
						{ "name", SCREEN_CENTER_X + colNameX, SCREEN_CENTER_X + colAvgX - 40 },
						{ "avg", SCREEN_CENTER_X + colAvgX - 40, SCREEN_CENTER_X + colAvgX + 20 },
						{ "songs", SCREEN_CENTER_X + colAvgX + 20, SCREEN_CENTER_X + colSongsX + 20 },
						{ "size", SCREEN_CENTER_X + colSongsX + 20, SCREEN_CENTER_X + colSizeX + 20 },
					}
					for _, column in ipairs(colTable) do
						if mx >= column[2] and mx <= column[3] then
							if column[1] ~= "avg" or HV.ShowMSD() then
								chooseSort(column[1])
								selectedRow = 1
								self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")
								self:GetParent():GetChild("ColumnHeaders"):playcommand("Update")
							end
							return
						end
					end
				end

				-- Pack list rows click
				for i = 1, math.min(#currentPacks, packsPerPage) do
					local rowTopY = rowsStartY + (i - 1) * rowH
					if mx >= marginX and mx <= SCREEN_WIDTH - marginX
						and my >= rowTopY and my <= rowTopY + rowH then
						if selectedRow == i then
							local pack = currentPacks[i]
							if pack and not installedFlags[i] and not pack:IsQueued() and not isPackDownloading(pack) then
								if pack:GetSize() > externalDownloadThreshold then
									pack:DownloadExternally()
								else
									pack:DownloadAndInstall(false)
								end
							end
						else
							selectedRow = i
						end
						self:GetParent():GetChild("PackRows"):playcommand("RefreshRows")
						return
					end
				end
				return
			end

			-- Text search input
			if isSearching then
				if btn == "DeviceButton_backspace" then
					nameInput = nameInput:sub(1, -2)
					self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
					self:stoptweening():sleep(0.5):queuecommand("DoSearch")
					return
				end

				if btn == "DeviceButton_delete" then
					nameInput = ""
					self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
					packList:FilterAndSearch("", {}, true, packsPerPage)
					self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")
					return
				end

				local char = inputToCharacter(event)
				if char then
					nameInput = nameInput .. char
					self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
					self:stoptweening():sleep(0.5):queuecommand("DoSearch")
					return
				end
			end

			-- Arrow navigation
			if gameBtn == "MenuDown" or gameBtn == "Down" then
				selectedRow = math.min(selectedRow + 1, math.min(#currentPacks, packsPerPage))
				self:GetParent():GetChild("PackRows"):playcommand("RefreshRows")
				return
			elseif gameBtn == "MenuUp" or gameBtn == "Up" then
				selectedRow = math.max(selectedRow - 1, 1)
				self:GetParent():GetChild("PackRows"):playcommand("RefreshRows")
				return
			elseif btn == "DeviceButton_enter" or gameBtn == "Start" then
				local pack = currentPacks[selectedRow]
				if pack and not installedFlags[selectedRow] and not pack:IsQueued() and not isPackDownloading(pack) then
					if pack:GetSize() > externalDownloadThreshold then
						pack:DownloadExternally()
					else
						pack:DownloadAndInstall(false)
					end
					self:GetParent():GetChild("PackRows"):playcommand("RefreshRows")
				end
				return
			elseif gameBtn == "MenuRight" or gameBtn == "Right" or gameBtn == "EffectDown" then
				if packList:NextPage() then
					self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")
				end
				return
			elseif gameBtn == "MenuLeft" or gameBtn == "Left" or gameBtn == "EffectUp" then
				if packList:PrevPage() then
					self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")
				end
				return
			end
		end

		SCREENMAN:GetTopScreen():AddInputCallback(inputCallback)
		self.inputCallback = inputCallback
		self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
	end,

	OffCommand = function(self)
		if self.inputCallback then
			SCREENMAN:GetTopScreen():RemoveInputCallback(self.inputCallback)
		end
	end,

	DoSearchCommand = function(self)
		local tags = {}
		if availableBundles[currentBundleIndex] ~= "All" then
			table.insert(tags, availableBundles[currentBundleIndex]:lower())
		end
		for tg, _ in pairs(selectedTags) do
			table.insert(tags, tg)
		end
		packList:FilterAndSearch(nameInput, tags, tagsMatchAny, packsPerPage)
		self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")
	end,

	PackTagsRefreshedMessageCommand = function(self)
		updateAvailableBundles()
		updateAvailableTags()
		self:GetParent():GetChild("BundleSelector"):playcommand("Update")
		self:GetParent():GetChild("TagSelector"):playcommand("Update")
		self:GetParent():GetChild("BundleListOverlay"):playcommand("Update")
		self:GetParent():GetChild("TagListOverlay"):playcommand("Update")
	end,

	-- Periodic update for progress and active installation status
	OnCommand = function(self)
		self:SetUpdateFunction(function(af)
			if currentPacks and #currentPacks > 0 then
				local packRows = af:GetParent():GetChild("PackRows")
				for i = 1, math.min(#currentPacks, packsPerPage) do
					local pack = currentPacks[i]
					if pack then
						installedFlags[i] = isPackInstalled(pack)
						packRows:playcommand("UpdateRow" .. i)
					end
				end
			end
		end)
	end
}

-- Custom mouse cursor (highest Z-order)
t[#t + 1] = LoadActor("../_cursor")

return t
