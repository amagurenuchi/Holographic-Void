--- Holographic Void: Playlists Tab
-- Uses SONGMAN:GetPlaylists() with Til Death-matching chart APIs
-- Supports drill-down into individual playlists, chart deletion, song selection

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local bgCard = color("0.04,0.04,0.04,0.97")

local overlayW = 680
local overlayH = 400
local rowH = 34
local chartsPerPage = 8
local playlistsPerPage = 8
local rowStartY = -overlayH/2 + 85
local playlistsActor = nil
local whee = nil

-- State
local allplaylists = {}
local singleplaylistactive = false
local allplaylistsactive = true
local currentPlaylistPage = 1
local currentChartPage = 1

-- Active playlist data
local pl = nil
local chartlist = {}

-- Helper to persist changes to disk (local profile is Player 1)
local function saveProfile()
	if PROFILEMAN and PROFILEMAN.SaveProfile then
		PROFILEMAN:SaveProfile(PLAYER_1 or 0)
	end
end

local function RefreshPlaylistList()
	allplaylists = {}
	local ok, playlists = pcall(function() return SONGMAN:GetPlaylists() end)
	if ok and playlists then
		for _, playlist in pairs(playlists) do
			if type(playlist) == "userdata" then
				table.insert(allplaylists, {name = playlist:GetName(), playlist = playlist})
			end
		end
		table.sort(allplaylists, function(a, b) return (a.name or "") < (b.name or "") end)
	end
end

local function RefreshChartList()
	chartlist = {}
	if pl then
		local ok, list = pcall(function() return pl:GetAllSteps() end)
		local ok2, keys = pcall(function() return pl:GetChartkeys() end)
		if ok and list and ok2 and keys then
			for i = 1, #list do
				table.insert(chartlist, {chart = list[i], key = keys[i]})
			end
		end
	end
end

local function GetPlaylistStats()
	local stats = {avgMSD = 0, totalDuration = 0, count = 0}
	if not pl or not chartlist or #chartlist == 0 then return stats end
	
	local totalMSD = 0
	for _, entry in ipairs(chartlist) do
		local steps = SONGMAN:GetStepsByChartKey(entry.key)
		if steps then
			totalMSD = totalMSD + steps:GetMSD(entry.chart:GetRate(), 1)
			local song = SONGMAN:GetSongByChartKey(entry.key)
			if song then
				stats.totalDuration = stats.totalDuration + (song:GetStepsSeconds() / entry.chart:GetRate())
			end
		end
	end
	stats.count = #chartlist
	stats.avgMSD = totalMSD / stats.count
	return stats
end

local function SortChartList(mode)
	if not pl then return end
	if mode == "title" then
		table.sort(chartlist, function(a, b) return (a.chart:GetSongTitle() or "") < (b.chart:GetSongTitle() or "") end)
	elseif mode == "msd" then
		table.sort(chartlist, function(a, b)
			local sA = SONGMAN:GetStepsByChartKey(a.key)
			local sB = SONGMAN:GetStepsByChartKey(b.key)
			local msA = sA and sA:GetMSD(a.chart:GetRate(), 1) or 0
			local msB = sB and sB:GetMSD(b.chart:GetRate(), 1) or 0
			return msA > msB
		end)
	elseif mode == "rate" then
		table.sort(chartlist, function(a, b) return a.chart:GetRate() > b.chart:GetRate() end)
	end
	-- Note: SONGMAN doesn't support persistent custom sorting via API easily, 
	-- we are just sorting the local 'chartlist' for display.
end

-- Manual chart reordering workaround
-- pl:MoveChart is not available in this Etterna version,
-- so we rebuild the playlist by deleting all charts and re-adding them in the new order.
local function ManualMoveChart(fromIdx, toIdx)
	if not pl then return false end
	if fromIdx == toIdx then return false end
	if fromIdx < 1 or toIdx < 1 then return false end

	-- 1. Snapshot current state (keys + rates)
	local snapshot = {}
	local ok, steps = pcall(function() return pl:GetAllSteps() end)
	local ok2, keys = pcall(function() return pl:GetChartkeys() end)
	if not ok or not steps or not ok2 or not keys then return false end
	if fromIdx > #keys or toIdx > #keys then return false end

	for i = 1, #keys do
		snapshot[i] = { key = keys[i], rate = steps[i]:GetRate() }
	end

	-- 2. Swap entries in snapshot
	snapshot[fromIdx], snapshot[toIdx] = snapshot[toIdx], snapshot[fromIdx]

	-- 3. Delete all charts from the end to avoid index shifting
	for i = #keys, 1, -1 do
		pcall(function() pl:DeleteChart(i) end)
	end

	-- 4. Re-add all charts in new order
	for i = 1, #snapshot do
		pcall(function() pl:AddChart(snapshot[i].key) end)
	end

	-- 5. Restore rates (AddChart defaults to 1.0x, so adjust by delta)
	local ok3, newSteps = pcall(function() return pl:GetAllSteps() end)
	if ok3 and newSteps then
		for i = 1, #snapshot do
			if newSteps[i] then
				local targetRate = snapshot[i].rate
				local currentRate = newSteps[i]:GetRate()
				local delta = targetRate - currentRate
				if math.abs(delta) > 0.001 then
					pcall(function() newSteps[i]:ChangeRate(delta) end)
				end
			end
		end
	end
	saveProfile()
	return true
end

-- Manual playlist rename workaround
-- SONGMAN:RenamePlaylist is not available in some older Etterna versions
local function ManualRenamePlaylist(oldName, newName, oldPl)
	if not oldPl or not oldName or not newName or oldName == newName then return false end

	-- 1. Snapshot current state (keys + rates)
	local snapshot = {}
	local ok, steps = pcall(function() return oldPl:GetAllSteps() end)
	local ok2, keys = pcall(function() return oldPl:GetChartkeys() end)
	if not ok or not steps or not ok2 or not keys then return false end

	for i = 1, #keys do
		snapshot[i] = { key = keys[i], rate = steps[i]:GetRate() }
	end

	-- 2. Create NEW playlist
	SONGMAN:NewPlaylistNoDialog(newName)
	
	-- 3. Find the newly created playlist object
	local newPl = nil
	local allPls = SONGMAN:GetPlaylists()
	for _, p in pairs(allPls) do
		if p:GetName() == newName then
			newPl = p
			break
		end
	end
	
	if not newPl then return false end

	-- 4. Re-add all charts
	for i = 1, #snapshot do
		pcall(function() newPl:AddChart(snapshot[i].key) end)
	end

	-- 5. Restore rates in new playlist
	local ok3, newSteps = pcall(function() return newPl:GetAllSteps() end)
	if ok3 and newSteps then
		for i = 1, #snapshot do
			if newSteps[i] then
				local targetRate = snapshot[i].rate
				local currentRate = newSteps[i]:GetRate()
				local delta = targetRate - currentRate
				if math.abs(delta) > 0.001 then
					pcall(function() newSteps[i]:ChangeRate(delta) end)
				end
			end
		end
	end

	-- 6. Delete OLD playlist
	SONGMAN:DeletePlaylist(oldName)
	saveProfile()
	return true
end


-- Shared input function reference to allow removal/cleanup
local function SharedInputHandler(event)
	if not playlistsActor or not playlistsActor:GetVisible() then return false end
	if not event or not event.DeviceInput then return false end

	-- Screen state awareness: Only handle input if we are the top screen
	-- This prevents blocking overlays like ScreenTextEntry (naming/login)
	-- Safe extraction matching goals.lua
	local btn = event.DeviceInput.button or ""
	if type(btn) ~= "string" then btn = tostring(btn) end
	local evType = event.type

	-- Sink releases immediately
	if evType == "InputEventType_Release" then return true end

	-- Only respond to first presses for clicks!
	if evType ~= "InputEventType_FirstPress" then return true end

	if btn == "DeviceButton_left mouse button" then
		local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()

		-- Header click for sorting
		local headerY = SCREEN_CENTER_Y - overlayH/2 + 65
		if singleplaylistactive and my >= headerY - 10 and my <= headerY + 10 then
			local hx = mx - (SCREEN_CENTER_X - overlayW/2 + 25)
			if hx >= 60 and hx <= 340 then SortChartList("title") end
			if hx >= overlayW - 190 and hx <= overlayW - 150 then SortChartList("rate") end
			if hx >= overlayW - 130 and hx <= overlayW - 90 then SortChartList("msd") end
			playlistsActor:playcommand("RefreshUI")
			return true
		end

		-- Close on outside click
		if not IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
			MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
			return true
		end

		-- Back button
		if singleplaylistactive then
			if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 50, SCREEN_CENTER_Y - overlayH/2 + 18, 60, 18) then
				singleplaylistactive = false
				allplaylistsactive = true
				currentPlaylistPage = 1
				playlistsActor:playcommand("RefreshUI")
				return true
			end
		end

		-- Add Current button
		if singleplaylistactive then
			if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 235, SCREEN_CENTER_Y - overlayH/2 + 18, 100, 18) then
				local currentSteps = GAMESTATE:GetCurrentSteps()
				if currentSteps then
					local ck = currentSteps:GetChartKey()
					if pl then
						pl:AddChart(ck)
						ms.ok(string.format(THEME:GetString("Playlists", "ChartAdded"), pl:GetName()))
						saveProfile()
						RefreshChartList()
						playlistsActor:playcommand("RefreshUI")
					end
				end
				return true
			end
			
			-- Play as Course button
			if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 130, SCREEN_CENTER_Y - overlayH/2 + 18, 90, 18) then
				if pl and #chartlist > 0 then
					SCREENMAN:GetTopScreen():StartPlaylistAsCourse(pl:GetName())
				end
				return true
			end
		end

		-- Advanced Controls
		if not singleplaylistactive then
			local ctrlsY = SCREEN_CENTER_Y + overlayH / 2 - 35
			if IsMouseOverCentered(SCREEN_CENTER_X - 55, ctrlsY, 70, 20) then -- NEW
				easyInputStringOKCancel(THEME:GetString("Playlists", "PromptNewName"), 32, false, function(name)
					if name and name ~= "" then
						SONGMAN:NewPlaylistNoDialog(name)
						ms.ok(string.format(THEME:GetString("Playlists", "PlaylistCreated"), name))
						saveProfile()
						RefreshPlaylistList()
						playlistsActor:playcommand("RefreshUI")
					end
				end)
				return true
			end
			if DLMAN:IsLoggedIn() and IsMouseOverCentered(SCREEN_CENTER_X + 55, ctrlsY, 100, 20) then -- GET EO
				ms.ok(THEME:GetString("Playlists", "DownloadingPlaylists"))
				DLMAN:DownloadMissingPlaylists()
				return true
			end
		end

		-- Row clicks
		local perPage = singleplaylistactive and chartsPerPage or playlistsPerPage
		for ri = 1, perPage do
			local rowTop = SCREEN_CENTER_Y + rowStartY + (ri - 1) * rowH
			local rowLeft = SCREEN_CENTER_X - overlayW/2 + 25
			if mx >= rowLeft and mx <= rowLeft + overlayW - 50 and my >= rowTop and my <= rowTop + rowH then
				if singleplaylistactive then
					local idx = (currentChartPage - 1) * chartsPerPage + ri
					if idx <= #chartlist then
						local entry = chartlist[idx]
						local hx = mx - rowLeft
						
						-- 1. Reorder Column (More generous hitbox: 0 to 45)
						if hx <= 45 then
							if my < rowTop + rowH / 2 then -- UP
								if idx > 1 then
									if ManualMoveChart(idx, idx - 1) then
										RefreshChartList()
										playlistsActor:playcommand("RefreshUI")
									end
								end
							else -- DOWN
								if idx < #chartlist then
									if ManualMoveChart(idx, idx + 1) then
										RefreshChartList()
										playlistsActor:playcommand("RefreshUI")
									end
								end
							end
							return true
						
						-- 2. Rate Adjustment
						elseif hx >= overlayW - 260 and hx <= overlayW - 200 then
							local curRate = entry.chart:GetRate()
							if hx <= overlayW - 230 then -- Left side (-0.1)
								entry.chart:ChangeRate(-0.1)
							else -- Right side (+0.1)
								entry.chart:ChangeRate(0.1)
							end
							playlistsActor:playcommand("RefreshUI")
							return true

						-- 3. Delete button
						elseif hx >= overlayW - 80 then
							pcall(function() pl:DeleteChart(idx) end)
							saveProfile()
							RefreshChartList()
							playlistsActor:playcommand("RefreshUI")
							return true

						-- 4. Song selection (Center area)
						else
							local ck = entry.key
							if ck then
								local song = SONGMAN:GetSongByChartKey(ck)
								if song and whee then
									whee:SelectSong(song)
								end
							end
							MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
							return true
						end
					end
				else
					local idx = (currentPlaylistPage - 1) * playlistsPerPage + ri
					if idx <= #allplaylists then
						local plEntry = allplaylists[idx]
						local name = plEntry.name
						local hx = mx - rowLeft

						-- Action: Delete
						if hx >= overlayW - 75 then
							if plEntry.playlist then
								SONGMAN:DeletePlaylist(name)
								ms.ok(string.format(THEME:GetString("Playlists", "PlaylistDeleted"), name))
								saveProfile()
								RefreshPlaylistList()
								playlistsActor:playcommand("RefreshUI")
							end
							return true

						-- Action: Rename
						elseif hx >= overlayW - 105 and hx < overlayW - 75 then
							if plEntry.playlist then
								easyInputStringOKCancel(THEME:GetString("Playlists", "PromptRename"), 32, false, function(newName)
									if newName and newName ~= "" then
										if ManualRenamePlaylist(name, newName, plEntry.playlist) then
											ms.ok(string.format(THEME:GetString("Playlists", "PlaylistRenamed"), name, newName))
											RefreshPlaylistList()
											playlistsActor:playcommand("RefreshUI")
										else
											ms.ok(THEME:GetString("Common", "Error"))
										end
									end
								end, nil, name)
							end
							return true
							
						-- Action: Select Playlist
						else
							pl = plEntry.playlist
							SONGMAN:SetActivePlaylist(name)
							singleplaylistactive = true
							allplaylistsactive = false
							currentChartPage = 1
							RefreshChartList()
							playlistsActor:playcommand("RefreshUI")
						end
					end
					return true
				end
			end
		end
		
		return true -- Sink all other clicks inside the overlay
	end

	if event.button == "Back" or btn == "DeviceButton_escape" then
		if singleplaylistactive then
			singleplaylistactive = false
			allplaylistsactive = true
			playlistsActor:playcommand("RefreshUI")
		else
			MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
		end
		return true
	end

	-- Sink all input when overlay is visible
	return true
end

local t = Def.ActorFrame {
	Name = "PlaylistsOverlay",
	InitCommand = function(self)
		playlistsActor = self
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false)
	end,
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen and screen.GetMusicWheel then whee = screen:GetMusicWheel() end
	end,
	SelectMusicTabChangedMessageCommand = function(self, params)
		if params.Tab == "PLAYLISTS" then
			-- Use explicit visibility to avoid toggle double-triggering
			self:visible(true)
			self:stoptweening():diffusealpha(0):linear(0.2):diffusealpha(1)
			HV.ActiveTab = "PLAYLISTS"
			singleplaylistactive = false
			allplaylistsactive = true
			currentPlaylistPage = 1
			currentChartPage = 1
			RefreshPlaylistList()
			self:playcommand("RefreshUI")
		else
			self:visible(false)
			if HV.ActiveTab == "PLAYLISTS" then HV.ActiveTab = "" end
		end
	end,
	NextPlaylistPageMessageCommand = function(self)
		if singleplaylistactive then
			local totalPages = math.max(1, math.ceil(#chartlist / chartsPerPage))
			currentChartPage = math.max(1, math.min(totalPages, currentChartPage + 1))
		else
			local totalPages = math.max(1, math.ceil(#allplaylists / playlistsPerPage))
			currentPlaylistPage = math.max(1, math.min(totalPages, currentPlaylistPage + 1))
		end
		self:playcommand("RefreshUI")
	end,
	PrevPlaylistPageMessageCommand = function(self)
		if singleplaylistactive then
			local totalPages = math.max(1, math.ceil(#chartlist / chartsPerPage))
			currentChartPage = math.max(1, math.min(totalPages, currentChartPage - 1))
		else
			local totalPages = math.max(1, math.ceil(#allplaylists / playlistsPerPage))
			currentPlaylistPage = math.max(1, math.min(totalPages, currentPlaylistPage - 1))
		end
		self:playcommand("RefreshUI")
	end,

	-- Background
	Def.Quad { InitCommand = function(self) self:zoomto(overlayW, overlayH):diffuse(bgCard) end },
	Def.Quad { InitCommand = function(self) self:valign(0):y(-overlayH/2):zoomto(overlayW, 2):diffuse(accentColor):diffusealpha(0.7) end },

	-- Title & Stats
	Def.ActorFrame {
		Name = "HeaderInfo",
		InitCommand = function(self) self:xy(-overlayW/2 + 25, -overlayH/2 + 15) end,
		
		LoadFont("Common Normal") .. {
			Name = "Title",
			InitCommand = function(self) self:halign(0):zoom(0.5):diffuse(accentColor) end,
			RefreshUICommand = function(self)
				if singleplaylistactive and pl then
					self:settextf(THEME:GetString("Playlists", "SingleTitle"), pl:GetName())
				else
					self:settextf(THEME:GetString("Playlists", "Title"), #allplaylists)
				end
			end,
		},
		
		LoadFont("Common Normal") .. {
			Name = "Stats",
			InitCommand = function(self) self:halign(0):y(20):zoom(0.24):diffuse(subText) end,
			RefreshUICommand = function(self)
				if singleplaylistactive and pl then
					local s = GetPlaylistStats()
					self:settextf("%s: %.2f  ·  %s: %s  ·  %s: %d", 
						THEME:GetString("Playlists", "AvgMSD"), s.avgMSD, 
						THEME:GetString("Playlists", "Duration"), SecondsToMSS(s.totalDuration), 
						THEME:GetString("Playlists", "Charts"), s.count)
				else
					self:settext("")
				end
			end,
		},
	},

	-- Back button
	Def.ActorFrame {
		Name = "BackBtn",
		InitCommand = function(self) self:xy(overlayW/2 - 50, -overlayH/2 + 18):visible(false) end,
		RefreshUICommand = function(self)
			self:visible(singleplaylistactive)
		end,
		Def.Quad {
			InitCommand = function(self) self:zoomto(60, 18):diffuse(accentColor):diffusealpha(0.4) end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText):settext("<- " .. THEME:GetString("Common", "Back")) end,
		},
	},

	-- Play as Course button
	Def.ActorFrame {
		Name = "PlayAsCourseBtn",
		InitCommand = function(self) self:xy(overlayW/2 - 130, -overlayH/2 + 18):visible(false) end,
		RefreshUICommand = function(self)
			self:visible(singleplaylistactive and pl ~= nil and #chartlist > 0)
		end,
		Def.Quad {
			InitCommand = function(self) self:zoomto(90, 18):diffuse(accentColor):diffusealpha(0.4) end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText):settext(THEME:GetString("Playlists", "PlayAsCourse")) end,
		},
	},

	-- Page info
	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self)
			self:halign(1):valign(0):xy(overlayW/2 - 16, -overlayH/2 + 30):zoom(0.24):diffuse(dimText)
		end,
		RefreshUICommand = function(self)
			local total, perPage, curPage
			if singleplaylistactive then
				total = #chartlist
				perPage = chartsPerPage
				curPage = currentChartPage
			else
				total = #allplaylists
				perPage = playlistsPerPage
				curPage = currentPlaylistPage
			end
			local totalPages = math.max(1, math.ceil(total / perPage))
			self:settextf(THEME:GetString("Common", "PageInfo"), curPage, totalPages)
		end,
	},
	Def.ActorFrame {
		Name = "AddCurrentBtn",
		InitCommand = function(self)
			self:xy(overlayW/2 - 235, -overlayH/2 + 18)
		end,
		RefreshUICommand = function(self)
			self:visible(singleplaylistactive)
		end,
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:zoomto(100, 18):diffuse(accentColor):diffusealpha(0.15)
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:zoom(0.24):diffuse(brightText):settext(THEME:GetString("Playlists", "AddCurrent"))
			end
		}
	},

	-- Advanced Controls Row (Bottom)
	Def.ActorFrame {
		Name = "AdvancedControls",
		InitCommand = function(self) self:xy(0, overlayH / 2 - 35) end,
		RefreshUICommand = function(self)
			self:visible(not singleplaylistactive)
		end,

		-- NEW
		Def.ActorFrame {
			Name = "NewBtn",
			InitCommand = function(self) self:x(-55) end,
			Def.Quad { InitCommand = function(self) self:zoomto(70, 20):diffuse(accentColor):diffusealpha(0.2) end },
			LoadFont("Common Normal") .. { InitCommand = function(self) self:zoom(0.32):diffuse(brightText):settext(THEME:GetString("Playlists", "New")) end },
		},
		-- GET EO PLAYLISTS
		Def.ActorFrame {
			Name = "GetEOBtn",
			InitCommand = function(self) self:x(55) end,
			RefreshUICommand = function(self)
				self:visible(DLMAN:IsLoggedIn())
			end,
			Def.Quad { InitCommand = function(self) self:zoomto(100, 20):diffuse(accentColor):diffusealpha(0.2) end },
			LoadFont("Common Normal") .. { InitCommand = function(self) self:zoom(0.32):diffuse(brightText):settext(THEME:GetString("Playlists", "GetEO")) end },
		},
	},
}

-- Single Playlist EO Controls (Top Right)
t[#t+1] = Def.ActorFrame {
	Name = "SingleEOControls",
	InitCommand = function(self) self:xy(overlayW/2 - 365, -overlayH/2 + 18) end,
	RefreshUICommand = function(self)
		self:visible(singleplaylistactive and DLMAN:IsLoggedIn() and pl and pl:GetName() ~= "Favorites")
	end,
	-- UPLOAD
	Def.ActorFrame {
		Name = "UploadBtn",
		InitCommand = function(self) self:x(-45) end,
		Def.Quad { InitCommand = function(self) self:zoomto(70, 18):diffuse(accentColor):diffusealpha(0.15) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:zoom(0.24):diffuse(brightText):settext("UPLOAD EO") end },
	},
	-- SYNC (DL)
	Def.ActorFrame {
		Name = "SyncBtn",
		InitCommand = function(self) self:x(35) end,
		Def.Quad { InitCommand = function(self) self:zoomto(70, 18):diffuse(accentColor):diffusealpha(0.15) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:zoom(0.24):diffuse(brightText):settext("SYNC EO") end },
	},
}


-- Column Headers (Sortable)
t[#t+1] = Def.ActorFrame {
	Name = "ColumnHeaders",
	InitCommand = function(self) self:xy(-overlayW/2 + 25, -overlayH/2 + 65):visible(false) end,
	RefreshUICommand = function(self) self:visible(singleplaylistactive) end,
	
	LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(60):zoom(0.32):diffuse(accentColor):settext(THEME:GetString("Common", "SongTitle")) end },
	LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0.5):x(overlayW - 230):zoom(0.32):diffuse(accentColor):settext(THEME:GetString("Playlists", "Rate")) end },
	LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0.5):x(overlayW - 165):zoom(0.32):diffuse(accentColor):settext(THEME:GetString("Playlists", "MSD")) end },
	LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0.5):x(overlayW - 115):zoom(0.32):diffuse(accentColor):settext(THEME:GetString("Playlists", "PB")) end },
}

-- Rows for playlist list and chart entries
for i = 1, math.max(chartsPerPage, playlistsPerPage) do
	t[#t + 1] = Def.ActorFrame {
		Name = "Row_" .. i,
		InitCommand = function(self)
			self:xy(-overlayW/2 + 25, rowStartY + (i - 1) * rowH)
		end,

		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(overlayW - 50, rowH - 4):diffuse(color("0,0,0,0.2"))
			end,
		},

		-- Reorder Buttons
		Def.ActorFrame {
			Name = "Reorder",
			InitCommand = function(self) self:visible(false) end,
			RefreshUICommand = function(self) self:visible(singleplaylistactive) end,
			
			Def.Sprite {
				Name = "Up",
				Texture = THEME:GetPathG("", "left"),
				InitCommand = function(self) self:halign(0.5):xy(15, rowH/2 - 6):zoomto(10, 10):rotationz(90):diffuse(accentColor) end
			},
			Def.Sprite {
				Name = "Down",
				Texture = THEME:GetPathG("", "right"),
				InitCommand = function(self) self:halign(0.5):xy(15, rowH/2 + 6):zoomto(10, 10):rotationz(90):diffuse(accentColor) end
			},
		},

		-- Difficulty text
		LoadFont("Common Normal") .. {
			Name = "DiffText",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(40, rowH / 2):zoom(0.32):visible(false)
			end,
		},

		-- Main text line
		LoadFont("Common Normal") .. {
			Name = "MainText",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(90, rowH / 2):zoom(0.42):diffuse(brightText):maxwidth((overlayW - 350) / 0.42)
			end,
		},

		-- Rate Controls
		Def.ActorFrame {
			Name = "RateControls",
			InitCommand = function(self) self:x(overlayW - 230):y(rowH/2):visible(false) end,
			RefreshUICommand = function(self) self:visible(singleplaylistactive) end,
			Def.Sprite {
				Name = "L",
				Texture = THEME:GetPathG("", "left"),
				InitCommand = function(self) self:x(-25):zoomto(12, 12):diffuse(accentColor) end
			},
			LoadFont("Common Normal") .. { Name = "Val", InitCommand = function(self) self:zoom(0.35):diffuse(brightText) end },
			Def.Sprite {
				Name = "R",
				Texture = THEME:GetPathG("", "right"),
				InitCommand = function(self) self:x(25):zoomto(12, 12):diffuse(accentColor) end
			},
		},

		-- Sub text (PB display)
		LoadFont("Common Normal") .. {
			Name = "SubText",
			InitCommand = function(self)
				self:halign(1):valign(0.5):x(overlayW - 115):y(rowH / 2):zoom(0.32):diffuse(subText)
			end,
		},

		-- MSD display
		LoadFont("MSD 20px") .. {
			Name = "RateText",
			InitCommand = function(self)
				self:halign(1):valign(0.5):x(overlayW - 165):y(rowH / 2):zoom(0.32):diffuse(dimText)
			end,
		},

		-- Rename button (only for playlist list view)
		Def.Sprite {
			Name = "RenameBtn",
			Texture = THEME:GetPathG("", "rename"),
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):xy(overlayW - 90, rowH / 2):zoomto(18, 18)
			end,
		},

		-- Delete button (visible in both chart view and playlist list view)
		Def.Sprite {
			Name = "DelBtn",
			Texture = THEME:GetPathG("", "delete"),
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):xy(overlayW - 65, rowH / 2):zoomto(18, 18)
			end,
		},

		RefreshUICommand = function(self)
			if singleplaylistactive then
				-- Chart entries
				local idx = (currentChartPage - 1) * chartsPerPage + i
				if idx <= #chartlist then
					self:visible(true)
					local entry = chartlist[idx]
					local songTitle = entry.chart:GetSongTitle() or "???"
					self:GetChild("MainText"):settext(songTitle)

					-- Fetch and set difficulty
					local diff = entry.chart:GetDifficulty()
					self:GetChild("DiffText"):settext(getShortDifficulty(diff))
					self:GetChild("DiffText"):diffuse(HVColor.GetDifficultyColor(diff)):visible(true)

					-- Check if song exists
					local song = SONGMAN:GetSongByChartKey(entry.key)
					if song then
						self:GetChild("MainText"):diffuse(brightText)
					else
						self:GetChild("MainText"):diffuse(color("1,0.3,0.3,1"))
					end

					self:GetChild("RateControls"):GetChild("Val"):settextf("%.1fx", entry.chart:GetRate())
					
					-- MSD calculation
					local msd = 0
					local steps = SONGMAN:GetStepsByChartKey(entry.key)
					if steps then
						msd = steps:GetMSD(entry.chart:GetRate(), 1)
					end
					self:GetChild("RateText"):settextf("%.2f", msd):visible(true)

					-- Show personal best if available
					local pb = ""
					pcall(function()
						local best = SCOREMAN:GetScoresByKey(entry.key)
						if best then
							for _, sl in pairs(best) do
								local scores = sl:GetScores()
								if scores and #scores > 0 then
									pb = string.format("%.2f%%", scores[1]:GetWifeScore() * 100)
									break
								end
							end
						end
					end)
					self:GetChild("SubText"):settext(pb):visible(true)
					self:GetChild("DelBtn"):visible(true)
					self:GetChild("DelBtn"):diffusealpha(0.6)
					if self:GetChild("RenameBtn") then self:GetChild("RenameBtn"):visible(false) end
					self:GetChild("Reorder"):playcommand("RefreshUI")
					self:GetChild("RateControls"):playcommand("RefreshUI")
				else
					self:visible(false)
				end
			else
				-- Playlist list
				local idx = (currentPlaylistPage - 1) * playlistsPerPage + i
				if idx <= #allplaylists then
					self:visible(true)
					local plEntry = allplaylists[idx]
					self:GetChild("MainText"):settext(plEntry.name)
					-- Highlight active playlist
					local activePl = SONGMAN:GetActivePlaylist()
					if activePl and activePl:GetName() == plEntry.name then
						self:GetChild("MainText"):diffuse(accentColor)
					else
						self:GetChild("MainText"):diffuse(brightText)
					end
					self:GetChild("DiffText"):settext(""):visible(false)
					local ct = 0
					pcall(function() ct = plEntry.playlist:GetNumCharts() end)
					self:GetChild("SubText"):settextf("%d %s", ct, THEME:GetString("Playlists", "Charts"):lower()):visible(true)
					self:GetChild("RateText"):settext(""):visible(false)
					self:GetChild("DelBtn"):visible(true)
					self:GetChild("DelBtn"):diffusealpha(1.0)
					if self:GetChild("RenameBtn") then self:GetChild("RenameBtn"):visible(true) end
				else
					self:visible(false)
				end
			end
		end,
	}
end

-- Input handler
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		-- Always cleanup any existing callback from a previous load
		if HV.PlaylistsInputCallback then
			pcall(function() screen:RemoveInputCallback(HV.PlaylistsInputCallback) end)
		end
		-- Only the primary instance (1) or the latest reloaded one should handle input.
		-- We assign a fresh function here to ensure it uses the latest local state.
		HV.PlaylistsInputCallback = function(event) return SharedInputHandler(event) end
		screen:AddInputCallback(HV.PlaylistsInputCallback)
	end,
}

return t
