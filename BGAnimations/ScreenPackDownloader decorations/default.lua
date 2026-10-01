--- Holographic Void: ScreenPackDownloader Decorations
-- Full interactive pack browser with:
--   - Search by name (keyboard input)
--   - Paginated pack list via PackList API
--   - Downloaded pack detection via SONGMAN:DoesSongGroupExist()
--   - Download / queue management
--   - Average difficulty, song count, play count columns
--   - Real-time download progress
-- Keyboard navigable
-- Basically what you expect from other themes. Tags filtering will be added soon

local t = Def.ActorFrame {
	Name = "PackDownloaderUI"
}


local accentColor = HVColor.Accent
local installedColor = color("0.35,0.65,0.35,1")
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local borderColor = color("0.18,0.18,0.18,1")
local rowHilight = color("0.12,0.12,0.12,0.9")
local rowNormal = color("0.04,0.04,0.04,0.5")
local rowAlt = color("0.06,0.06,0.06,0.5")
local rowInstalled = color("0.04,0.08,0.04,0.6")

-- ============================================================
-- STATE
-- ============================================================
local packList = PackList:new()
local nameInput = ""
local selectedRow = 1
local packsPerPage = 14
local currentPacks = {}
local installedFlags = {} -- cache installed status per row
local isSearching = false

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
local selectedTags = {}    -- {["tag_name"] = true, ...}
local tagsMatchAny = true  -- true = OR, false = AND
local isTagListOpen = false
local availableTagsOrig = {"All"}
local function updateAvailableTags()
	local alltags = DLMAN:GetPackTags()
	availableTags = {"All"}
	availableTagsOrig = {"All"}
	
	-- Categories from Til Death
	local categories = {"global_keyCount", "global_skillset", "pack_tag", "etterna_tag"}
	for _, cat in ipairs(categories) do
		local tags = alltags[cat]
		if tags then
			-- Simple numeric sort for keycount if possible
			if cat == "global_keyCount" then
				table.sort(tags, function(a, b)
					local an = tonumber(a:match("%d+")) or 0
					local bn = tonumber(b:match("%d+")) or 0
					return an < bn
				end)
			else
				table.sort(tags)
			end

			for _, t in ipairs(tags) do
				local label = t
				if cat == "global_keyCount" and not t:find("[kK]$") then
					label = t .. "K"
				end
				table.insert(availableTags, label:sub(1,1):upper() .. label:sub(2))
				table.insert(availableTagsOrig, t)
			end
		end
	end
end
updateAvailableTags()

-- Check if a pack is installed locally (same as Til Death)
local function isPackInstalled(pack)
	if not pack then return false end
	return SONGMAN:DoesSongGroupExist(pack:GetName())
end

-- Check the active download list separately from the queued state. A pack is
-- removed from the queue once its download starts, so IsQueued() alone is not
-- enough to describe its current status.
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

-- ============================================================
-- BACKGROUND
-- ============================================================
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}
for i = 1, 8 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, (SCREEN_HEIGHT / 9) * i)
				:zoomto(SCREEN_WIDTH, 1):diffuse(color("1,1,1,0.02"))
		end
	}
end

-- ============================================================
-- HEADER
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "Header",
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, 20) end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.6):diffuse(brightText):settext("PACK DOWNLOADER")
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:y(14):zoomto(SCREEN_WIDTH * 0.92, 1):diffuse(borderColor)
		end
	}
}

-- ============================================================
-- SEARCH BAR
-- ============================================================
local searchBarY = 44
local searchBarW = SCREEN_WIDTH * 0.45
local searchBarX = SCREEN_WIDTH * 0.25

t[#t + 1] = Def.ActorFrame {
	Name = "SearchBar",
	InitCommand = function(self) self:xy(searchBarX, searchBarY) end,

	Def.Sprite {
		Texture = THEME:GetPathG("", "search.png"),
		InitCommand = function(self)
			self:halign(1):x(-searchBarW / 2 - 8):zoom(0.35):diffuse(mainText)
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(searchBarW, 20):diffuse(color("0.08,0.08,0.08,0.9"))
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):x(-searchBarW / 2 + 6):zoom(0.28):diffuse(dimText)
			self:settext("SEARCH:")
		end
	},
	LoadFont("Common Normal") .. {
		Name = "SearchText",
		InitCommand = function(self)
			self:halign(0):x(-searchBarW / 2 + 55):zoom(0.32):diffuse(mainText)
		end,
		UpdateSearchCommand = function(self)
			if nameInput == "" then
				self:settext(isSearching and "Type to search..." or "Click to search...")
				self:diffuse(dimText)
			else
				self:settext(nameInput .. (isSearching and "_" or ""))
				self:diffuse(mainText)
			end
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:y(10):zoomto(searchBarW, 1):diffuse(accentColor):diffusealpha(0.2)
		end
	}
}

-- ============================================================
-- BUNDLE SELECTOR
-- ============================================================
local bundleBtnW = 100
local bundleBtnX = searchBarX + searchBarW / 2 + 10 + bundleBtnW / 2
local bundleListW = 140
local bundleItemH = 20

t[#t + 1] = Def.ActorFrame {
	Name = "BundleSelector",
	InitCommand = function(self) self:xy(bundleBtnX, searchBarY) end,

	-- Button background
	Def.Quad {
		Name = "BundleBtnBG",
		InitCommand = function(self)
			self:zoomto(bundleBtnW, 20):diffuse(color("0.12,0.12,0.12,0.9"))
		end,
		UpdateCommand = function(self)
			if isBundleListOpen then
				self:diffuse(accentColor):diffusealpha(0.4)
			else
				self:diffuse(color("0.12,0.12,0.12,0.9"))
			end
		end
	},
	LoadFont("Common Normal") .. {
		Name = "BundleLabel",
		InitCommand = function(self)
			self:zoom(0.26):diffuse(subText):settext("BUNDLE:")
			self:x(-bundleBtnW / 2 + 5):halign(0)
		end
	},
	LoadFont("Common Normal") .. {
		Name = "CurrentBundleText",
		InitCommand = function(self)
			self:zoom(0.28):diffuse(brightText)
			self:x(-bundleBtnW / 2 + 45):halign(0)
			self:settext(availableBundles[currentBundleIndex]:upper())
		end,
		UpdateCommand = function(self)
			self:settext(availableBundles[currentBundleIndex]:upper())
		end
	},
	-- Dropdown arrow
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(bundleBtnW / 2 - 10):zoom(0.3):diffuse(dimText):settext("▼")
		end
	}
}

-- ============================================================
-- TAG SELECTOR
-- ============================================================
local tagBtnW = 90
local tagBtnX = bundleBtnX + bundleBtnW / 2 + 10 + tagBtnW / 2
local tagListW = 400
local tagItemH = 20

t[#t + 1] = Def.ActorFrame {
	Name = "TagSelector",
	InitCommand = function(self) self:xy(tagBtnX, searchBarY) end,

	-- Button background
	Def.Quad {
		Name = "TagBtnBG",
		InitCommand = function(self)
			self:zoomto(tagBtnW, 20):diffuse(color("0.12,0.12,0.12,0.9"))
		end,
		UpdateCommand = function(self)
			if isTagListOpen then
				self:diffuse(accentColor):diffusealpha(0.4)
			else
				self:diffuse(color("0.12,0.12,0.12,0.9"))
			end
		end
	},
	LoadFont("Common Normal") .. {
		Name = "TagLabel",
		InitCommand = function(self)
			self:zoom(0.26):diffuse(subText):settext("TAGS:")
			self:x(-tagBtnW / 2 + 5):halign(0)
		end
	},
	LoadFont("Common Normal") .. {
		Name = "CurrentTagText",
		InitCommand = function(self)
			self:zoom(0.28):diffuse(brightText)
			self:x(-tagBtnW / 2 + 40):halign(0)
			self:settext("SELECT")
		end,
		UpdateCommand = function(self)
			local count = 0
			for _ in pairs(selectedTags) do count = count + 1 end
			if count == 0 then
				self:settext("ALL"):diffuse(brightText)
			else
				self:settextf("%d SEL", count):diffuse(accentColor)
			end
		end
	},
	-- Dropdown arrow
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(tagBtnW / 2 - 10):zoom(0.3):diffuse(dimText):settext("▼")
		end
	}
}

-- ============================================================
-- DOWNLOAD STATUS
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "DownloadStatusBar",
	InitCommand = function(self) self:xy(SCREEN_WIDTH * 0.92, searchBarY) end,

	-- Cancel Current Button
	Def.ActorFrame {
		Name = "CancelCurrent",
		InitCommand = function(self) self:x(-120) end,
		Def.Quad {
			Name = "BG",
			InitCommand = function(self)
				self:zoomto(80, 20):diffuse(color("0.15,0.05,0.05,0.8"))
			end,
			UpdateCommand = function(self)
				local dls = DLMAN:GetDownloads()
				if dls and #dls > 0 then
					self:diffusealpha(0.8)
				else
					self:diffusealpha(0.2)
				end
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:zoom(0.24):settext("CANCEL CUR"):diffuse(mainText)
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
	},

	-- Cancel All Button
	Def.ActorFrame {
		Name = "CancelAll",
		InitCommand = function(self) self:x(-30) end,
		Def.Quad {
			Name = "BG",
			InitCommand = function(self)
				self:zoomto(80, 20):diffuse(color("0.15,0.05,0.05,0.8"))
			end,
			UpdateCommand = function(self)
				local queued = DLMAN:GetQueuedPacks()
				local dls = DLMAN:GetDownloads()
				if (queued and #queued > 0) or (dls and #dls > 0) then
					self:diffusealpha(0.8)
				else
					self:diffusealpha(0.2)
				end
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:zoom(0.24):settext("CANCEL ALL"):diffuse(mainText)
			end,
			UpdateCommand = function(self)
				local queued = DLMAN:GetQueuedPacks()
				local dls = DLMAN:GetDownloads()
				if (queued and #queued > 0) or (dls and #dls > 0) then
					self:diffuse(color("1,0.2,0.2,1"))
				else
					self:diffuse(dimText)
				end
			end
		}
	},

	OnCommand = function(self)
		self:SetUpdateFunction(function()
			self:playcommand("Update")
		end)
	end
}

-- ============================================================
-- COLUMN HEADERS
-- ============================================================
local listY = 62
local listX = SCREEN_WIDTH * 0.04
local listW = SCREEN_WIDTH * 0.92
local rowH = 24
local colIdxX = 4
local colNameX = 28
local colAvgX = listW * 0.58
local colSongsX = listW * 0.66
local colSizeX = listW * 0.76
local colStatusX = listW * 0.9

t[#t + 1] = Def.ActorFrame {
	Name = "ColumnHeaders",
	InitCommand = function(self) self:xy(listX, listY) end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):x(colNameX):zoom(0.24):diffuse(dimText):settext("PACK NAME")
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(1):x(colAvgX):zoom(0.24):diffuse(dimText):settext("AVG MSD")
			if not HV.ShowMSD() then self:visible(false) end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(1):x(colSongsX):zoom(0.24):diffuse(dimText):settext("SONGS")
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(1):x(colSizeX):zoom(0.24):diffuse(dimText):settext("SIZE")
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0.5):x(colStatusX):zoom(0.24):diffuse(dimText):settext("STATUS")
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):y(10):zoomto(listW, 1):diffuse(borderColor)
		end
	}
}

-- ============================================================
-- PACK LIST ROWS
-- ============================================================
local packListFrame = Def.ActorFrame {
	Name = "PackRows",
	InitCommand = function(self) self:xy(listX, listY + 14) end,

	PackListRequestFinishedMessageCommand = function(self)
		currentPacks = packList:GetPacks() or {}
		-- Cache installed flags
		installedFlags = {}
		for i, pack in ipairs(currentPacks) do
			installedFlags[i] = isPackInstalled(pack)
		end
		selectedRow = 1
		self:playcommand("RefreshRows")
	end,

	RefreshRowsCommand = function(self)
		for i = 1, packsPerPage do
			self:playcommand("UpdateRow" .. i)
		end
		MESSAGEMAN:Broadcast("UpdatePageInfo")
	end
}

for i = 1, packsPerPage do
	local rowY = (i - 1) * rowH

	packListFrame[#packListFrame + 1] = Def.ActorFrame {
		Name = "Row" .. i,
		InitCommand = function(self) self:y(rowY) end,

		-- Row background
		Def.Quad {
			Name = "RowBG",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(listW, rowH - 1)
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

		-- Selection indicator
		Def.Quad {
			Name = "SelectBar",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(2, rowH - 1)
					:diffuse(accentColor):visible(false)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				self:visible(i == selectedRow and currentPacks[i] ~= nil)
			end
		},

		-- Row index
		LoadFont("Common Normal") .. {
			Name = "RowIdx",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(colIdxX, 3)
					:zoom(0.36):diffuse(dimText)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					local pageOffset = (packList:GetCurrentPage() - 1) * packsPerPage
					self:settextf("%d.", pageOffset + i)
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- Pack name
		LoadFont("Common Normal") .. {
			Name = "PackName",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(colNameX, 3)
					:zoom(0.44):diffuse(mainText)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					self:settext(pack:GetName())
					if installedFlags[i] then
						self:diffuse(installedColor)
					elseif pack:IsNSFW() then
						self:diffuse(color("1,0,0,1"))
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

		-- Average difficulty
		LoadFont("Common Normal") .. {
			Name = "AvgMSD",
			InitCommand = function(self)
				self:halign(1):valign(0):xy(colAvgX, 3)
					:zoom(0.38):diffuse(subText)
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
						self:diffuse(subText)
					end
					self:visible(HV.ShowMSD())
				else
					self:visible(false)
				end
			end
		},

		-- Song count
		LoadFont("Common Normal") .. {
			Name = "SongCount",
			InitCommand = function(self)
				self:halign(1):valign(0):xy(colSongsX, 3)
					:zoom(0.38):diffuse(subText)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					local count = pack:GetSongCount()
					if count and count > 0 then
						self:settext(tostring(count))
					else
						self:settext("-")
					end
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- Pack size
		LoadFont("Common Normal") .. {
			Name = "PackSize",
			InitCommand = function(self)
				self:halign(1):valign(0):xy(colSizeX, 3)
					:zoom(0.38):diffuse(subText)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					local bytes = pack:GetSize()
					if bytes and bytes > 0 then
						local mb = bytes / (1024 * 1024)
						if mb >= 1024 then
							self:settextf("%.1fGB", mb / 1024)
						else
							self:settextf("%.0fMB", mb)
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

		-- Status text
		LoadFont("Common Normal") .. {
			Name = "StatusText",
			InitCommand = function(self)
				self:halign(0.5):valign(0):xy(colStatusX, 3):zoom(0.36)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					if installedFlags[i] then
						self:settext("INSTALLED")
						self:diffuse(installedColor)
					elseif isPackDownloading(pack) then
						self:settext("DOWNLOADING")
						self:diffuse(accentColor)
					elseif pack:IsQueued() then
						self:settext("QUEUED")
						self:diffuse(accentColor)
					else
						self:settext("DOWNLOAD")
						self:diffuse(subText)
					end
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- Download progress bar (per row)
		Def.Quad {
			Name = "DLBar",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, rowH - 2)
					:zoomto(0, 1):diffuse(accentColor):diffusealpha(0.5)
			end
		}
	}
end

t[#t + 1] = packListFrame

-- ============================================================
-- STATUS INDICATOR (center of list area, shows when no rows visible)
-- ============================================================
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "LoadingText",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):zoom(0.4):diffuse(subText):visible(false)
	end,
	PackListRequestFinishedMessageCommand = function(self)
		local packs = packList:GetPacks()
		if packs and #packs > 0 then
			self:visible(false)
		else
			if packList:GetTotalResults() == 0 then
				self:settext("No packs found matching your search."):visible(true)
				self:diffuse(dimText)
			else
				self:visible(false)
			end
		end
	end,
	ShowLoadingCommand = function(self)
		-- self:settext("Fetching packs from server..."):visible(true)
		-- self:diffuse(accentColor):diffusealpha(0.6)
	end
}

-- Bundle List Overlay (Moved here for higher Z-order)
local bundleListFrame = Def.ActorFrame {
	Name = "BundleListOverlay",
	InitCommand = function(self) 
		self:xy(bundleBtnX - bundleBtnW / 2 + bundleListW / 2, searchBarY + 12 + (bundleItemH * #availableBundles / 2))
		self:visible(false)
	end,
	UpdateCommand = function(self)
		self:visible(isBundleListOpen)
		-- Re-center based on number of items
		self:y(searchBarY + 12 + (bundleItemH * #availableBundles / 2))
	end
}

-- List Background
bundleListFrame[#bundleListFrame + 1] = Def.Quad {
	InitCommand = function(self)
		self:zoomto(bundleListW, bundleItemH * #availableBundles)
		self:diffuse(color("0.05,0.05,0.05,0.95"))
	end
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
				self:zoomto(bundleListW - 2, bundleItemH - 2):diffusealpha(0)
			end,
			UpdateCommand = function(self)
				if i == currentBundleIndex then
					self:diffuse(accentColor):diffusealpha(0.2)
				else
					self:diffusealpha(0)
				end
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:zoom(0.28):diffuse(mainText):settext(bundleName:upper())
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
local tagItemW = 100
local tagListW = tagCols * tagItemW
local tagListFrame = Def.ActorFrame {
	Name = "TagListOverlay",
	InitCommand = function(self) 
		-- Align right edge of menu to right edge of button
		self:xy(tagBtnX + tagBtnW / 2 - tagListW / 2, searchBarY + 12)
		self:visible(false)
	end,
	UpdateCommand = function(self)
		self:visible(isTagListOpen)
		-- Re-center based on number of items
		local rows = math.ceil(#availableTags / tagCols)
		self:y(searchBarY + 20 + (tagItemH * rows / 2))
	end
}

-- List Background
tagListFrame[#tagListFrame + 1] = Def.Quad {
	Name = "ListBG",
	InitCommand = function(self)
		self:diffuse(color("0.05,0.05,0.05,0.95"))
	end,
	UpdateCommand = function(self)
		local rows = math.ceil(#availableTags / tagCols)
		self:zoomto(tagListW, tagItemH * rows + 30) -- +30 for the AND/OR footer
		self:y(15) -- Shift down to accommodate footer at the top or bottom
	end
}

-- AND/OR Toggle Button (in the overlay)
tagListFrame[#tagListFrame + 1] = Def.ActorFrame {
	Name = "ConditionToggle",
	InitCommand = function(self)
		self:y(-10) -- top of list
	end,
	UpdateCommand = function(self)
		local rows = math.ceil(#availableTags / tagCols)
		self:y(-(tagItemH * rows / 2) + 10)
	end,

	Def.Quad {
		Name = "BtnBG",
		InitCommand = function(self)
			self:zoomto(tagListW - 10, 18):diffuse(color("0.1,0.1,0.1,1"))
		end
	},
	LoadFont("Common Normal") .. {
		Name = "BtnText",
		InitCommand = function(self)
			self:zoom(0.26)
		end,
		UpdateCommand = function(self)
			self:settextf("MATCHING: %s (CLICK TO TOGGLE)", tagsMatchAny and "ANY (OR)" or "ALL (AND)")
			self:diffuse(tagsMatchAny and color("0.6,0.8,1,1") or color("1,0.8,0.6,1"))
		end
	}
}

for i = 1, 100 do -- Increased limit for grid
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
					    (r - (rows - 1) / 2) * tagItemH + 15)
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
				local tag = availableTagsOrig[i]
				if tag and selectedTags[tag] then
					self:diffuse(accentColor):diffusealpha(0.3)
				else
					self:diffusealpha(0)
				end
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Text",
			InitCommand = function(self)
				self:zoom(0.24):diffuse(mainText)
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

-- ============================================================
-- FOOTER
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "Footer",
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 26) end,

	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self) self:zoom(0.28):diffuse(subText) end,
		UpdatePageInfoMessageCommand = function(self)
			local page = packList:GetCurrentPage()
			local total = packList:GetTotalPages()
			local results = packList:GetTotalResults()
			if total > 0 then
				self:settextf("Page %d / %d  ·  %d packs found", page, total, results)
			else
				if packList:IsAwaitingRequest() then
					self:settext("Searching...")
				else
					self:settext("No results - type to search")
				end
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(14):zoom(0.22):diffuse(dimText)
			self:settext("Type = search  ·  ↑↓/Scroll = select  ·  Enter/Click = download  ·  ←→ = pages  ·  Del = reset  ·  Esc = exit")
		end
	}
}

-- ============================================================
-- INPUT HANDLER
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "InputHandler",
	BeginCommand = function(self)
		-- Initial search: show all packs
		packList:FilterAndSearch("", {}, true, packsPerPage)
		self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")

		local inputCallback = function(event)
			if event.type == "InputEventType_Release" then return end

			local btn = event.DeviceInput.button
			local gameBtn = event.button

			-- Mouse wheel -> scroll rows up/down
			local scroll = GetMouseScrollDirection(btn)
			if scroll ~= 0 then
				if scroll < 0 then
					selectedRow = math.max(selectedRow - 1, 1)
				else
					selectedRow = math.min(selectedRow + 1, math.min(#currentPacks, packsPerPage))
				end
				self:GetParent():GetChild("PackRows"):playcommand("RefreshRows")
				return
			end

			-- Mouse left click -> select/download row
			if IsMouseLeftClick(btn) then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()

				-- Check if bundle list is open and click is inside
				if isBundleListOpen then
					for i = 1, #availableBundles do
						local itemY = searchBarY + 12 + (i - 0.5) * bundleItemH
						if mx >= bundleBtnX - bundleBtnW / 2 and mx <= bundleBtnX - bundleBtnW / 2 + bundleListW
							and my >= itemY - bundleItemH / 2 and my <= itemY + bundleItemH / 2 then
							currentBundleIndex = i
							isBundleListOpen = false
							self:GetParent():GetChild("BundleSelector"):playcommand("Update")
							self:GetParent():GetChild("BundleListOverlay"):playcommand("Update")
							self:playcommand("DoSearch")
							return
						end
					end
					-- Clicked outside bundle list
					isBundleListOpen = false
					self:GetParent():GetChild("BundleSelector"):playcommand("Update")
					self:GetParent():GetChild("BundleListOverlay"):playcommand("Update")
					return
				end

				-- Check if tag list is open and click is inside
				if isTagListOpen then
					local rows = math.ceil(#availableTags / tagCols)
					local gridOriginX = tagBtnX + tagBtnW / 2 - tagListW / 2
					local gridOriginY = searchBarY + 20 + (tagItemH * rows / 2)
					local gridStartY = gridOriginY + 15 - (tagItemH * rows / 2)
					
					-- Check condition toggle button
					local toggleY = gridOriginY - (tagItemH * rows / 2) + 10
					if mx >= gridOriginX - (tagListW - 10) / 2
						and mx <= gridOriginX + (tagListW - 10) / 2
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
						
						if mx >= itemX - tagItemW/2 and mx <= itemX + tagItemW/2
							and my >= itemY - tagItemH/2 and my <= itemY + tagItemH/2 then
							
							local tag = availableTagsOrig[i]
							if tag == "All" then
								selectedTags = {}
							else
								if selectedTags[tag] then
									selectedTags[tag] = nil
								else
									selectedTags[tag] = true
								end
							end
							
							self:GetParent():playcommand("Update")
							self:playcommand("DoSearch")
							return
						end
					end
					-- Clicked outside tag list
					isTagListOpen = false
					self:GetParent():playcommand("Update")
					return
				end

				-- Check if click is on bundle selector button
				if mx >= bundleBtnX - bundleBtnW / 2 and mx <= bundleBtnX + bundleBtnW / 2
					and my >= searchBarY - 10 and my <= searchBarY + 10 then
					isBundleListOpen = not isBundleListOpen
					isTagListOpen = false -- Close other dropdown
					self:GetParent():GetChild("BundleSelector"):playcommand("Update")
					self:GetParent():GetChild("BundleListOverlay"):playcommand("Update")
					self:GetParent():GetChild("TagSelector"):playcommand("Update")
					self:GetParent():GetChild("TagListOverlay"):playcommand("Update")
					return
				end

				-- Check if click is on tag selector button
				if mx >= tagBtnX - tagBtnW / 2 and mx <= tagBtnX + tagBtnW / 2
					and my >= searchBarY - 10 and my <= searchBarY + 10 then
					isTagListOpen = not isTagListOpen
					isBundleListOpen = false -- Close other dropdown
					self:GetParent():playcommand("Update")
					return
				end
				
				-- Check if click is on Cancel Current
				local ccX = SCREEN_WIDTH * 0.92 - 120
				if mx >= ccX - 40 and mx <= ccX + 40 and my >= searchBarY - 10 and my <= searchBarY + 10 then
					local dls = DLMAN:GetDownloads()
					if dls and dls[1] then
						dls[1]:Stop()
					end
					return
				end

				-- Check if click is on Cancel All
				local caX = SCREEN_WIDTH * 0.92 - 30
				if mx >= caX - 40 and mx <= caX + 40 and my >= searchBarY - 10 and my <= searchBarY + 10 then
					for _, p in ipairs(DLMAN:GetQueuedPacks()) do
						p:RemoveFromQueue()
					end
					for _, p in ipairs(DLMAN:GetDownloads()) do
						p:Stop()
					end
					for _, p in ipairs(DLMAN:GetDownloadingPacks()) do
						local dl = p:GetDownload()
						if dl then dl:Stop() end
					end
					return
				end
				
				-- Check if click is on the search bar
				local sbX = SCREEN_WIDTH * 0.28
				local sbW = searchBarW
				local sbH = 20
				if mx >= sbX - sbW / 2 and mx <= sbX + sbW / 2 and my >= searchBarY - sbH / 2 and my <= searchBarY + sbH / 2 then
					isSearching = true
					self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
					return
				else
					if isSearching then
						isSearching = false
						self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
					end
				end

				-- Check if click is within the pack list area
				for i = 1, math.min(#currentPacks, packsPerPage) do
					local rowTopY = listY + 14 + (i - 1) * rowH
					if mx >= listX and mx <= listX + listW
						and my >= rowTopY and my <= rowTopY + rowH then
						if selectedRow == i then
							-- Already selected, trigger download
							local pack = currentPacks[i]
							if pack and not installedFlags[i] and not pack:IsQueued() and not isPackDownloading(pack) then
								if pack:GetSize() > 2000000000 then
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

			-- Text input — consume before checking navigation keys
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
				-- Enter/Start = download/queue selected pack
				local pack = currentPacks[selectedRow]
				if pack and not installedFlags[selectedRow] and not pack:IsQueued() and not isPackDownloading(pack) then
					if pack:GetSize() > 2000000000 then
						pack:DownloadExternally()
					else
						pack:DownloadAndInstall(false)
					end
					self:GetParent():GetChild("PackRows"):playcommand("RefreshRows")
				end
				return
			elseif gameBtn == "MenuRight" or gameBtn == "Right" or gameBtn == "EffectDown" then
				-- Right / Select+Down = next page
				if packList:NextPage() then
					self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")
				end
				return
			elseif gameBtn == "MenuLeft" or gameBtn == "Left" or gameBtn == "EffectUp" then
				-- Left / Select+Up = prev page
				if packList:PrevPage() then
					self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")
				end
				return
			end
		end

		SCREENMAN:GetTopScreen():AddInputCallback(inputCallback)

		-- Store callback reference for cleanup
		self.inputCallback = inputCallback

		self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
	end,

	OffCommand = function(self)
		-- Remove input callback when screen exits to prevent crash
		if self.inputCallback then
			SCREENMAN:GetTopScreen():RemoveInputCallback(self.inputCallback)
		end
	end,

	-- Auto-search triggered after typing debounce
	DoSearchCommand = function(self)
		local tags = {}
		if availableBundles[currentBundleIndex] ~= "All" then
			table.insert(tags, availableBundles[currentBundleIndex]:lower())
		end
		-- Add multiple selected tags
		for t, _ in pairs(selectedTags) do
			table.insert(tags, t)
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

	-- Periodic refresh for download progress
	OnCommand = function(self)
		self:SetUpdateFunction(function(af)
			if currentPacks and #currentPacks > 0 then
				local packRows = af:GetParent():GetChild("PackRows")
				for i = 1, math.min(#currentPacks, packsPerPage) do
					local pack = currentPacks[i]
					if pack then
						-- Installation can finish after the page was loaded, so do not
						-- rely solely on the initial installedFlags cache.
						installedFlags[i] = isPackInstalled(pack)
						packRows:playcommand("UpdateRow" .. i)
					end
				end
			end
		end)
	end
}

-- Load custom mouse cursor (highest Z-order)
t[#t + 1] = LoadActor("../_cursor")

return t
