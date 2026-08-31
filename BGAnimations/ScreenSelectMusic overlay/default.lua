--- Holographic Void: ScreenSelectMusic Overlay
-- Restore sequential Til Death-style login flow.

local accentColor = HVColor.Accent
local brightText = color("1,1,1,1")

-- Load grade counter data (initializes GRADECOUNTERSTORAGE)
LoadActor("../gradecounter.lua")

-- Compact Profile Login Button Bounds
local panelX = 20
local panelW = SCREEN_WIDTH * 0.36
local compactProfileX = panelX + panelW + 16
local compactProfileY = SCREEN_HEIGHT - 40 - 75

local btnCX = compactProfileX + 40
local btnCY = compactProfileY - 22
local btnW, btnH = 80, 24

-- Profile Overlay Constants
local overlayW, overlayH = SCREEN_WIDTH * 0.94, SCREEN_HEIGHT * 0.75
local colW, scorePageSize = overlayW / 3, 10
local skillsets = {"Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical"}

-- New Column Constants
local gradeSidebarW = 70
local profileSidebarW = 160
local mainPartW = overlayW - gradeSidebarW - profileSidebarW
local sidebarW = gradeSidebarW + profileSidebarW
local skillsetTabH = 26
local rowH = 28
local rowsYStart = 60

local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local dimText = color("0.45,0.45,0.45,1")
local bgCard = color("0.06,0.06,0.06,0.9")

local profileOverlayActor = nil
local globalTooltipActor = nil
local previewActive = false
local inputDebugActor = nil
local searchString = ""

-- Mouse wheel locking to prevent double-moves
local lastWheelMove = 0
local wheelLockTime = 0.05

-- Bottom Footer Config (Top-level for scope)
local tabs = {"PROFILE", "SCORES", "PLAYLISTS", "FILTERS", "TAGS", "GOALS", "RANDOM"}
local tabW = 80
local footerH = 40
local footerOverlayTabs = {
	PROFILE = true,
	SCORES = true,
	PLAYLISTS = true,
	FILTERS = true,
	TAGS = true,
	GOALS = true,
}

-- discord rpc & nowplaying.txt
updateDiscordStatusForMenus()
updateNowPlaying()

local function PlayWhooshOverlayOpen()
	SOUND:PlayOnce(THEME:GetPathS("", "whoosh"))
end

local function IsSelectMusicBackgroundClickArea()
	local mx = INPUTFILTER:GetMouseX() or SCREEN_CENTER_X
	local my = INPUTFILTER:GetMouseY() or SCREEN_CENTER_Y
	if HV.ActiveTab and HV.ActiveTab ~= "" then return false end
	if my <= 40 or my >= SCREEN_HEIGHT - 40 then return false end
	if mx <= panelX + panelW + 110 then return false end
	if mx >= SCREEN_WIDTH - 390 and mx <= SCREEN_WIDTH - 10 and my >= 84 and my <= SCREEN_HEIGHT - 64 then return false end
	return true
end

local function ApplyNativeMusicWheelHoldTransform(p)
	local screen = SCREENMAN:GetTopScreen()
	local wheel = screen and screen.GetMusicWheel and screen:GetMusicWheel()
	if wheel then
		wheel:x((SCREEN_WIDTH - 180) + (SCREEN_WIDTH * 0.32) * p)
	end
end

local main_af = Def.ActorFrame {
	InitCommand = function(self)
		self:SetUpdateFunction(function(af)
			-- Hover Logic
			local virtualX = INPUTFILTER:GetMouseX()
			local virtualY = INPUTFILTER:GetMouseY()
			
			local over = virtualX >= btnCX - btnW/2 and virtualX <= btnCX + btnW/2
					 and virtualY >= btnCY - btnH/2 and virtualY <= btnCY + btnH/2

			-- Removed: local overlay updating of LoginButtonUI since it was moved to decorations
		end)
	end,
	BeginCommand = function(self)
		-- Store ScreenSelectMusic reference globally for chart preview to use
		HV = HV or {}
		HV.SSM = SCREENMAN:GetTopScreen()
		HV.ActiveTab = ""
		HV.SuppressSearchCloseEnter = false
		HV.GameplaySessionValid = false
		HV.ChartPreviewActive = false
		HV.LeftMousePeekHold = false
		HV.LeftMousePeekHoldAllowed = false
		ApplyNativeMusicWheelHoldTransform(0)
		if INPUTFILTER and INPUTFILTER.SetMouseVisible then
			INPUTFILTER:SetMouseVisible(true)
		end
		
		-- If returning from a gameplay session, reset the preview position to 0
		-- to avoid trying to "resume" from the end of the song.
		HV.LastPlayedSecond = 0
		
		-- Always default Practice Mode to Off when entering song select
		GAMESTATE:SetPracticeMode(false)
		
		-- Refresh EtternaOnline user data upon entering Select Music (e.g. after finishing a song)
		if DLMAN:IsLoggedIn() and DLMAN.RefreshUserData then
			DLMAN:RefreshUserData()
		end

		self:sleep(0.01):queuecommand("OpenPendingStatsScore"):queuecommand("CheckFirstLaunchSSM")
	end,
	OpenPendingStatsScoreCommand = function(self)
		local pending = getenv("HVPendingScoreFromStats")
		if not pending then return end
		setenv("HVPendingScoreFromStats", nil)
		local screen = SCREENMAN:GetTopScreen()
		if screen and screen.ShowEvalScreenForScore then
			screen:ShowEvalScreenForScore(pending)
		elseif STATSMAN:GetCurStageStats() then
			STATSMAN:GetCurStageStats():GetPlayerStageStats():SetHighScore(pending)
			SCREENMAN:SetNewScreen("ScreenEvaluation")
		end
	end,
	CheckFirstLaunchSSMCommand = function(self)
		if PROFILEMAN:GetNumLocalProfiles() == 0 then
			easyInputStringOKCancel(
				THEME:GetString("ScreenTitleMenu", "CreateProfilePrompt"), 255, false,
				function(name)
					if name ~= "" then
						local newProfile = PROFILEMAN:CreateDefaultProfile()
						if newProfile then
							newProfile:RenameProfile(name)
							if PROFILEMAN:GetNumLocalProfiles() > 0 then
								HV.TitleState = HV.TitleState or {}
								HV.TitleState.selectedProfile = 0
								ms.ok("Profile '" .. name .. "' created successfully!")
								MESSAGEMAN:Broadcast("ThemePrefChanged", {Name = "HV_BGAnimIntensity"})
							else
								ms.ok("Failed to create profile. Please try again.")
								self:sleep(0.5):queuecommand("CheckFirstLaunchSSM")
							end
						else
							ms.ok("Failed to create default profile.")
							self:sleep(0.5):queuecommand("CheckFirstLaunchSSM")
						end
					else
						ms.ok("A local profile is required to save scores.")
						self:sleep(0.5):queuecommand("CheckFirstLaunchSSM")
					end
				end,
				function()
					ms.ok("A local profile is required to save scores.")
					self:sleep(0.5):queuecommand("CheckFirstLaunchSSM")
				end
			)
		end
	end,
	EndCommand = function(self)
		SCREENMAN:set_input_redirected(PLAYER_1, false)
		SCREENMAN:set_input_redirected(PLAYER_2, false)
		if HV.LeftMousePeekHold then
			HV.LeftMousePeekHold = false
			HV.LeftMousePeekHoldAllowed = false
			MESSAGEMAN:Broadcast("HVLeftMousePeekHoldChanged", {Held = false, Allowed = false})
		end
		ApplyNativeMusicWheelHoldTransform(0)
	end,
	LoginMessageCommand = function(self)
		local user = DLMAN:GetUsername()
		local token = DLMAN:GetToken()
		if user and token and user ~= "" and token ~= "" then
			ThemePrefs.Set("HV_Username", user)
			ThemePrefs.Set("HV_PasswordToken", token)
			ThemePrefs.Save()
		end
	end,
	LoginFailedMessageCommand = function(self)
		ms.ok("Login Failed. Please check your credentials.")
	end,
	LogOutMessageCommand = function(self)
		-- Only clear username on manual logout to preserve auto-login token
	end,
	TriggerLoginFlowMessageCommand = function(self)
		-- Sequential Til Death flow with frame delay to avoid overlaps
		local tempEmail = ""
		easyInputStringOKCancel(
			"Email:", 255, true,
			function(email)
				if email ~= "" then
					self.tempEmail = email
					self:sleep(0.02):queuecommand("LoginStep2")
				else
					ms.ok("Login Canceled")
				end
			end,
			function() ms.ok("Login Canceled") end
		)
	end,
	
	LoginStep2Command = function(self)
		easyInputStringOKCancel(
			"Password:", 255, true,
			function(password)
				if password ~= "" then
					Trace("[HV] Attempting DLMAN:Login for " .. tostring(self.tempEmail))
					DLMAN:Login(self.tempEmail, password)
				else
					ms.ok("Login Canceled")
				end
			end,
			function() ms.ok("Login Canceled") end
		)
	end,
	
	CodeMessageCommand = function(self, params)
		if params.Name == "Permamirror" then
			-- The engine has already toggled the flag because the code was matched.
			-- We just need to trigger the UI update.
			MESSAGEMAN:Broadcast("PermamirrorChanged")
		end
	end
}


-- LoginButtonUI was moved to decorations/default.lua to nest visually within the profile card.

-- Rate adjustment via CodeMessage (EffectUp/EffectDown mapped in metrics.ini)
local lastRatePresses = {0, 0}

local function adjustRate(delta)
	local curRate = getCurRateValue() or 1.0
	local nr = math.floor((curRate + delta) * 100 + 0.5) / 100
	nr = math.max(0.05, math.min(3.0, nr))
	local songOpts = GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred")
	if songOpts then
		songOpts:MusicRate(nr)
		GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate(nr)
		GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(nr)
		MESSAGEMAN:Broadcast("CurrentRateChanged", {rate = nr, oldRate = curRate})
	end
end

local function resetRate()
	local songOpts = GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred")
	if songOpts then
		songOpts:MusicRate(1.0)
		GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate(1.0)
		GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(1.0)
		MESSAGEMAN:Broadcast("CurrentRateChanged")
	end
end

local function getSongFavoriteState(song)
	if not song then return nil end

	local getters = {"IsFavorited", "IsFavorite", "GetFavorited", "GetIsFavorited"}
	for _, fn in ipairs(getters) do
		local method = song[fn]
		if type(method) == "function" then
			local ok, result = pcall(method, song)
			if ok then
				return result and true or false
			end
		end
	end

	return nil
end

local function toggleCurrentSongFavorite()
	local song = GAMESTATE:GetCurrentSong()
	if not song then return false end

	local profile = PROFILEMAN and PROFILEMAN:GetProfile(PLAYER_1)
	local currentState = getSongFavoriteState(song)

	local songToggles = {
		"ToggleFavorited",
		"ToggleFavorite",
	}
	for _, fn in ipairs(songToggles) do
		local method = song[fn]
		if type(method) == "function" then
			local ok = pcall(method, song)
			if ok then
				MESSAGEMAN:Broadcast("FavoriteSongToggled", {Song = song})
				return true
			end
		end
	end

	local songSetters = {"SetFavorited", "SetFavorite"}
	if currentState ~= nil then
		for _, fn in ipairs(songSetters) do
			local method = song[fn]
			if type(method) == "function" then
				local ok = pcall(method, song, not currentState)
				if ok then
					MESSAGEMAN:Broadcast("FavoriteSongToggled", {Song = song})
					return true
				end
			end
		end
	end

	if profile then
		local profileToggles = {
			"ToggleSongFavorite",
			"ToggleFavorite",
		}
		for _, fn in ipairs(profileToggles) do
			local method = profile[fn]
			if type(method) == "function" then
				local ok = pcall(method, profile, song)
				if ok then
					MESSAGEMAN:Broadcast("FavoriteSongToggled", {Song = song})
					return true
				end
			end
		end

		if currentState ~= nil then
			local method = currentState and profile.RemoveFromFavorites or profile.AddToFavorites
			if type(method) == "function" then
				local ok = pcall(method, profile, song)
				if ok then
					MESSAGEMAN:Broadcast("FavoriteSongToggled", {Song = song})
					return true
				end
			end
		end
	end

	return false
end

-- Centralized Input Callback (Handles Click, Scroll, and both-EffectUp/Down reset)
main_af[#main_af + 1] = Def.ActorFrame {
	-- Handle rate changes via CodeMessageCommand (fired by metrics.ini CodeNames)
	CodeMessageCommand = function(self, params)
		if not params or not params.Name then return end
		if params.Name == "NextRate" then
			lastRatePresses[2] = GetTimeSinceStart and GetTimeSinceStart() or os.clock()
			-- Check for simultaneous press (both within 50ms)
			if math.abs(lastRatePresses[1] - lastRatePresses[2]) < 0.05 and lastRatePresses[1] ~= 0 and lastRatePresses[2] ~= 0 then
				resetRate()
			else
				adjustRate(0.05)
			end
		elseif params.Name == "PrevRate" then
			lastRatePresses[1] = GetTimeSinceStart and GetTimeSinceStart() or os.clock()
			if math.abs(lastRatePresses[1] - lastRatePresses[2]) < 0.05 and lastRatePresses[1] ~= 0 and lastRatePresses[2] ~= 0 then
				resetRate()
			else
				adjustRate(-0.05)
			end
		elseif params.Name == "FavoriteToggle" then
			toggleCurrentSongFavorite()
		end
	end,
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end

		-- Always cleanup any existing callback from a previous load
		if HV.OverlayInputCallback then
			pcall(function() screen:RemoveInputCallback(HV.OverlayInputCallback) end)
		end

		HV.OverlayInputCallback = function(event)
			-- Strict nil checks to prevent script crashes
			if not event or not event.DeviceInput then return false end

			-- Screen state awareness: Only handle input if we are the top screen
			-- This prevents blocking overlays like ScreenTextEntry (naming/login)
			local top = SCREENMAN:GetTopScreen()
			if not top or top:GetName() ~= "ScreenSelectMusic" then return false end
			
			-- Banish inputs processing if chart preview is active so clicks don't leak through
			if previewActive then return false end
			
			local deviceInput = event.DeviceInput
			local btn = deviceInput.button or ""
			local evType = event.type or ""
			if btn == "DeviceButton_left mouse button" then
				local nextHeld = nil
				local allowed = false
				if evType == "InputEventType_FirstPress" then
					allowed = IsSelectMusicBackgroundClickArea()
					nextHeld = allowed
				elseif evType == "InputEventType_Release" then
					nextHeld = false
				end
				if nextHeld ~= nil and HV.LeftMousePeekHold ~= nextHeld then
					HV.LeftMousePeekHold = nextHeld
					HV.LeftMousePeekHoldAllowed = allowed
					MESSAGEMAN:Broadcast("HVLeftMousePeekHoldChanged", {Held = nextHeld, Allowed = allowed})
				end
			end
			local isEnter = (event.button == "Start" or btn:lower() == "devicebutton_enter" or btn:lower() == "devicebutton_kp enter")
			
			-- After search confirm closes the tab, keep swallowing only the triggering Enter/Start
			-- until its release event arrives. This avoids leaking the confirm input into the
			-- native music wheel without trapping unrelated keyboard input.
			if HV.SuppressSearchCloseEnter and isEnter then
				if evType == "InputEventType_Release" then
					HV.SuppressSearchCloseEnter = false
				end
				return true
			end
			
			-- Log to the isolated debugger if it's loaded
			if HV_DEBUG_LOG then
				HV_DEBUG_LOG(string.format("Input: %s (%s)", tostring(btn), tostring(evType)))
			end

			-- 2. Mouse Click
			if btn == "DeviceButton_right mouse button" and evType == "InputEventType_FirstPress" then
				-- A. Handle Score Validation if over a row
				if HV.ActiveTab == "PROFILE" then
					local profileSidebarX = (SCREEN_CENTER_X - overlayW/2) + gradeSidebarW
					local scoreAreaX = profileSidebarX + profileSidebarW
					local absRowsYStart = SCREEN_CENTER_Y - overlayH/2 + rowsYStart
					for i = 1, scorePageSize do
						if IsMouseOver(scoreAreaX + 10, absRowsYStart + (i-1)*rowH - rowH/2, mainPartW - 20, rowH) then
							MESSAGEMAN:Broadcast("OverlayRowRightClicked", {index = i})
							return true
						end
					end
				end

				-- B. Fallback: Pause sample music (ONLY if no tab is open)
				if HV.ActiveTab == "" then
					local screen = SCREENMAN:GetTopScreen()
					if screen and screen.PauseSampleMusic then
						screen:PauseSampleMusic()
						MESSAGEMAN:Broadcast("MusicPauseToggled")
					end
					return true
				end

				-- Skip general overlay buttons and fallback traps if a decoration tab is busy
				if HV.ActiveTab ~= "" and HV.ActiveTab ~= "PROFILE" then return false end
			end
			if btn == "DeviceButton_left mouse button" and evType == "InputEventType_FirstPress" then
				local virtualX = INPUTFILTER:GetMouseX()
				local virtualY = INPUTFILTER:GetMouseY()

				-- If PROFILE tab is open, handle click-outside to close
				if HV.ActiveTab == "PROFILE" then
					if not IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
						return true
					end
				end

				-- Skip general overlay buttons (Login, etc.) if a tab is busy
				if HV.ActiveTab ~= "" and HV.ActiveTab ~= "PROFILE" then return false end

				local virtualX = INPUTFILTER:GetMouseX()
				local virtualY = INPUTFILTER:GetMouseY()
				
				-- Check Login Button logic (btnCX/btnCY defined above)
				local loginOver = virtualX >= btnCX - btnW/2 and virtualX <= btnCX + btnW/2
						 and virtualY >= btnCY - btnH/2 and virtualY <= btnCY + btnH/2
				if loginOver then
					if DLMAN:IsLoggedIn() then
						ThemePrefs.Set("HV_Username", "")
						ThemePrefs.Set("HV_PasswordToken", "")
						ThemePrefs.Save()
						DLMAN:Logout()
						ms.ok("Logged Out")
					else
						MESSAGEMAN:Broadcast("TriggerLoginFlow")
					end
					return true
				end

				-- Check Avatar Button
				if virtualX >= compactProfileX - 8 and virtualX <= compactProfileX + 50
				   and virtualY >= compactProfileY - 8 and virtualY <= compactProfileY + 50 then
					SCREENMAN:SetNewScreen("ScreenAssetSettings")
					return true
				end

				-- Check Header `< BACK` Button (0 to 80, 0 to 40)
				if virtualX >= 0 and virtualX <= 80 and virtualY >= 0 and virtualY <= 40 then
					screen:Cancel()
					return true
				end

				-- Check Header `SEARCH` Bar (Center)
				local searchStartX = SCREEN_WIDTH / 2 - 150
				local searchStartY = 6
				if virtualX >= searchStartX and virtualX <= searchStartX + 300 
				   and virtualY >= searchStartY and virtualY <= searchStartY + 28 then
					if evType == "InputEventType_FirstPress" then
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = "SEARCH"})
					end
					return true
				end

				-- Check Footer Tab Buttons (Uses top-level 'tabs', 'tabW', 'footerH')
				local footerY = SCREEN_HEIGHT - footerH
				for i, tabName in ipairs(tabs) do
					local tx = 10 + (i - 1) * tabW
					if virtualX >= tx and virtualX <= tx + tabW and virtualY >= footerY and virtualY <= SCREEN_HEIGHT then
						local target = tabName:upper()
						
						if target == "RANDOM" then
							local groups = SONGMAN:GetSongGroupNames()
							if groups and #groups > 0 then
								local group = groups[math.random(#groups)]
								local songs = SONGMAN:GetSongsInGroup(group)
								if songs and #songs > 0 then
									local song = songs[math.random(#songs)]
									if song then
										local whee = screen:GetMusicWheel()
										if whee then
											whee:SelectSong(song)
										end
									end
								end
							end
							return true
						end

						if target == "PROFILE" then target = "SOCIAL" end 

						local nextTab = ""
						if HV.ActiveTab == tabName:upper() then
							nextTab = ""
						else
							nextTab = tabName:upper()
						end

						if nextTab ~= "" and footerOverlayTabs[nextTab] then
							PlayWhooshOverlayOpen()
						end

						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = nextTab})
						return true
					end
				end



				-- --- PROFILE TAB SPECIFIC CLICKS ---
				if HV.ActiveTab == "PROFILE" then
					local gradeSidebarCX = SCREEN_CENTER_X - overlayW/2 + gradeSidebarW/2
					local gradeSidebarTop = SCREEN_CENTER_Y - overlayH/2
					local profileSidebarX = (SCREEN_CENTER_X - overlayW/2) + gradeSidebarW
					local scoreAreaX = profileSidebarX + profileSidebarW
					local headerY = SCREEN_CENTER_Y - overlayH/2 + 35

					-- 1. Dedicated profile stats screen
					if IsMouseOverCentered(gradeSidebarCX, gradeSidebarTop + 25, gradeSidebarW - 12, 22) then
						SCREENMAN:SetNewScreen("ScreenHVStats")
						return true
					end

					-- 2. Mode Toggle (TOP / RECENT)
					if IsMouseOverCentered(scoreAreaX + mainPartW - 250, headerY, 100, 24) then
						profileOverlayActor.isRecentMode = not profileOverlayActor.isRecentMode
						profileOverlayActor.topPage = 1; profileOverlayActor.recentPage = 1
						MESSAGEMAN:Broadcast("UpdateOverlayUI"); return true
					end
					-- 3. Source Toggle (ONLINE / LOCAL)
					if IsMouseOverCentered(scoreAreaX + mainPartW - 140, headerY, 100, 24) then
						if not profileOverlayActor.isRecentMode then
							profileOverlayActor.isOnlineMode = not profileOverlayActor.isOnlineMode
							profileOverlayActor.topPage = 1
							MESSAGEMAN:Broadcast("UpdateOverlayUI")
						end
						return true
					end
					-- 4. Upload Button
					if IsMouseOverCentered(scoreAreaX + mainPartW - 40, headerY, 80, 24) then
						if DLMAN:IsLoggedIn() then DLMAN:UploadAllScores() else ms.ok("Log in to upload scores.") end
						return true
					end
					-- 5. Avatar
					if IsMouseOverCentered(profileSidebarX + profileSidebarW/2, SCREEN_CENTER_Y - overlayH/2 + 50, 60, 60) then
						SCREENMAN:SetNewScreen("ScreenAssetSettings"); return true
					end
					-- 6. Skillset Tabs
					local tabsYStart = SCREEN_CENTER_Y - overlayH/2 + 140
					for i, ss in ipairs(skillsets) do
						if IsMouseOver(profileSidebarX + 10, tabsYStart + (i-1)*skillsetTabH - skillsetTabH/2, profileSidebarW - 20, skillsetTabH) then
							-- ms.ok("Skillset Click: " .. ss)
							profileOverlayActor.currentSkillset = ss; profileOverlayActor.isRecentMode = false; profileOverlayActor.topPage = 1
							if not profileOverlayActor.isOnlineMode then SCOREMAN:SortSSRsForGame(ss) end
							MESSAGEMAN:Broadcast("UpdateOverlayUI"); return true
						end
					end
					-- 7. Score Rows
					local absRowsYStart = SCREEN_CENTER_Y - overlayH/2 + rowsYStart
					for i = 1, scorePageSize do
						if IsMouseOver(scoreAreaX + 10, absRowsYStart + (i-1)*rowH - rowH/2, mainPartW - 20, rowH) then
							-- ms.ok("Row Click: " .. i)
							MESSAGEMAN:Broadcast("OverlayRowClicked", {index = i}); return true
						end
					end
				end

				-- If an overlay is active, and we haven't handled the click yet, 
				-- we return true to sink it so it doesn't click the music wheel under the overlay.
				-- EXCEPT if it's a decoration tab (GOALS, TAGS, etc.) which handle their own sinking.
				if HV.ActiveTab == "PROFILE" then
					return true
				end

				-- --- MUSIC WHEEL SELECTION ---
				-- If no tab is active, handle clicking on music wheel items
				if HV.ActiveTab == "" then
					-- MusicWheel is on the right side. 
					-- metrics.ini: MusicWheelX=SCREEN_WIDTH-180, MusicWheelItem width=280
					-- Hitbox: [SCREEN_WIDTH-320, SCREEN_WIDTH-40]
					if virtualX >= SCREEN_WIDTH - 325 and virtualX <= SCREEN_WIDTH - 35 then
						local mw = screen:GetMusicWheel()
						if mw then
							-- Calculate offset relative to center (SCREEN_CENTER_Y)
							-- Spacing is 40px per item (from metrics ItemTransformFunction)
							local offset = math.floor((virtualY - SCREEN_CENTER_Y) / 40 + 0.5)
							
							if offset == 0 then
								-- Clicked the center: Start the song
								screen:PostScreenMessage("SM_BeginStart", 0) -- Native Start() may be too aggressive
								-- or just call Select() on the wheel
								-- most themes use screen:SelectCurrent() or Start()
								screen:queuecommand("Start") 
							else
								-- Clicked another item: Scroll to it
								local dir = offset > 0 and 1 or -1
								local steps_to_move = math.abs(offset)
								
								-- Stop any existing wheel movement first
								mw:Move(0)
								
								-- Move item by item
								for i=1, steps_to_move do
									mw:Move(dir)
									mw:Move(0)
								end
							end
							return true
						end
					end
				end
			end
			
			-- 2.6 Mouse Wheel & Keyboard Navigation
			-- BLOCKED if an overlay tab is open
			local navigationBtns = {
				["DeviceButton_mousewheel up"] = -1,
				["DeviceButton_mousewheel down"] = 1,
				["DeviceButton_left"] = -1,
				["DeviceButton_right"] = 1,
				["DeviceButton_up"] = -1,
				["DeviceButton_down"] = 1,
			}
			local gameBtnDirs = {
				["MenuLeft"] = -1,
				["MenuRight"] = 1,
				["MenuUp"] = -1,
				["MenuDown"] = 1,
				["Left"] = -1,
				["Right"] = 1,
			}
			local logicalBtn = event.button or ""
			
			local dir = navigationBtns[btn] or gameBtnDirs[logicalBtn]
			
			if dir then
				if HV.ActiveTab ~= "" and HV.ActiveTab ~= "SEARCH" then
					if evType == "InputEventType_FirstPress" or evType == "InputEventType_Repeat" then
						if HV.ActiveTab == "PROFILE" then
							if dir < 0 then MESSAGEMAN:Broadcast("PrevScorePage")
							else MESSAGEMAN:Broadcast("NextScorePage") end
						elseif HV.ActiveTab == "PLAYLISTS" then
							if dir < 0 then MESSAGEMAN:Broadcast("PrevPlaylistPage")
							else MESSAGEMAN:Broadcast("NextPlaylistPage") end
						elseif HV.ActiveTab == "GOALS" then
							if dir < 0 then MESSAGEMAN:Broadcast("PrevGoalPage")
							else MESSAGEMAN:Broadcast("NextGoalPage") end
						else
							MESSAGEMAN:Broadcast("TabNavigation", {dir = dir})
						end
					end
					return true 
				end
				
				if HV.ActiveTab ~= "SEARCH" and (evType == "InputEventType_FirstPress" or evType == "InputEventType_Repeat") then
					if btn == "DeviceButton_mousewheel up" or btn == "DeviceButton_mousewheel down" then
						local now = (GetTimeSinceStart and GetTimeSinceStart()) or os.clock()
						if now - lastWheelMove < wheelLockTime then return true end
						
						local mw = screen:GetMusicWheel()
						if mw then
							mw:Move(dir)
							mw:Move(0)
							lastWheelMove = now
						end
						return true
					end
					-- Let other nav keys (left/right/up/down) fall through to the engine if no tab is open
				end
			end

			

			-- --- SEARCH INPUT HANDLING ---
			if HV.ActiveTab == "SEARCH" then
				local whee = top.GetMusicWheel and top:GetMusicWheel() or (HV.SSM and HV.SSM.GetMusicWheel and HV.SSM:GetMusicWheel())
				local instant = HV.InstantSearch()

				-- Handle Backspace
				if btn:lower() == "devicebutton_backspace" then
					if evType ~= "InputEventType_Release" then
						if #searchString > 0 then
							searchString = searchString:sub(1, -2)
							if instant and whee then whee:SongSearch(searchString) end
							MESSAGEMAN:Broadcast("SearchQueryUpdated", {query = searchString})
						else
							-- Backspace on empty search closes (sc-wh behavior)
							MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
						end
					end
					return true
				end

				-- Handle Delete
				if btn:lower() == "devicebutton_delete" then
					if evType ~= "InputEventType_Release" then
						searchString = ""
						if instant and whee then whee:SongSearch("") end
						MESSAGEMAN:Broadcast("SearchQueryUpdated", {query = searchString})
					end
					return true
				end

				-- Handle Enter / Escape (Deactivate)
				local isEscape = (event.button == "Back" or btn:lower() == "devicebutton_escape")
				
				if isEnter then
					if evType == "InputEventType_FirstPress" then
						-- Filter now if not instant
						if not instant and whee then whee:SongSearch(searchString) end
						-- CLOSE SEARCH but keep filter.
						HV.SuppressSearchCloseEnter = true
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
						MESSAGEMAN:Broadcast("SearchQueryUpdated", {query = searchString, applied = true})
					end
					return true -- STRICT CAPTURE
				end
				if isEscape then
					if evType == "InputEventType_FirstPress" then
						searchString = ""
						if whee then whee:SongSearch("") end
						MESSAGEMAN:Broadcast("SearchQueryUpdated", {query = searchString})
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
					end
					return true
				end

				-- Handle Paste (Ctrl + V)
				local ctrl = INPUTFILTER:IsBeingPressed("left ctrl") or INPUTFILTER:IsBeingPressed("right ctrl")
				if ctrl and btn:lower() == "devicebutton_v" then
					if evType == "InputEventType_FirstPress" then
						if Arch and Arch.getClipboard then
							local clip = Arch.getClipboard()
							if clip then
								searchString = searchString .. clip
								if instant and whee then whee:SongSearch(searchString) end
								MESSAGEMAN:Broadcast("SearchQueryUpdated", {query = searchString})
							end
						end
					end
					return true
				end

				-- Handle Typing (Robust character detection)
				local shifted = INPUTFILTER:IsBeingPressed("left shift") or INPUTFILTER:IsBeingPressed("right shift")
				local c = (event.char and event.char ~= "") and event.char or DeviceBtnToChar(btn, shifted)
				
				-- Use a whitelist for characters to ensure stability (adapted from spawncamping-wallhack)
				-- This regex covers letters, numbers, and a wide range of symbols.
				local whitelist = '[%%%+%-%!%@%#%$%^%&%*%(%)%=%_%.%,%:%;%\'%"%>%<%?%/%~%|%w%[%]%{%}%`%\\]'
				
				if c and c ~= "" then
					if c:match(whitelist) or c == " " then
						if evType ~= "InputEventType_Release" then
							searchString = searchString .. c
							if instant and whee then whee:SongSearch(searchString) end
							MESSAGEMAN:Broadcast("SearchQueryUpdated", {query = searchString})
						end
					end
					return true
				end

				-- Fallback: Sink most input to prevent music wheel movement while typing
				-- but allow mouse movement and clicks to close the search
				if btn:match("mouse") then return false end
				return true
			end

			-- 3. Key Presses (Global Shortcuts)
			if evType == "InputEventType_FirstPress" then
				-- Close any active tab on Escape or Back
				if btn == "DeviceButton_escape" or logicalBtn == "Back" then
					if HV.ActiveTab ~= "" then
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
						return true
					end
				end

				local ctrl = INPUTFILTER:IsBeingPressed("left ctrl") or INPUTFILTER:IsBeingPressed("right ctrl")
				if ctrl then
					if btn == "DeviceButton_1" then
						if HV.ActiveTab ~= "PROFILE" then PlayWhooshOverlayOpen() end
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = "PROFILE"})
						return true
					elseif btn == "DeviceButton_2" then
						if HV.ActiveTab ~= "SCORES" then PlayWhooshOverlayOpen() end
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = "SCORES"})
						return true
					elseif btn == "DeviceButton_3" then
						if HV.ActiveTab ~= "PLAYLISTS" then PlayWhooshOverlayOpen() end
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = "PLAYLISTS"})
						return true
					elseif btn == "DeviceButton_4" then
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = "SEARCH"})
						return true
					elseif btn == "DeviceButton_5" then
						if HV.ActiveTab ~= "TAGS" then PlayWhooshOverlayOpen() end
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = "TAGS"})
						return true
					elseif btn == "DeviceButton_6" then
						if HV.ActiveTab ~= "GOALS" then PlayWhooshOverlayOpen() end
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = "GOALS"})
						return true
					elseif btn == "DeviceButton_7" then
						-- Random Song action
						local groups = SONGMAN:GetSongGroupNames()
						if groups and #groups > 0 then
							local group = groups[math.random(#groups)]
							local songs = SONGMAN:GetSongsInGroup(group)
							if songs and #songs > 0 then
								local song = songs[math.random(#songs)]
								if song then
									local whee = screen:GetMusicWheel()
									if whee then
										whee:SelectSong(song)
									end
								end
							end
						end
						return true
					elseif btn == "DeviceButton_0" then
						MESSAGEMAN:Broadcast("ToggleInputDebugger")
						return true
					end
				end

				-- Global Del to clear search
				if btn:lower() == "devicebutton_delete" then
					if searchString ~= "" then
						searchString = ""
						local whee = top.GetMusicWheel and top:GetMusicWheel() or (HV.SSM and HV.SSM.GetMusicWheel and HV.SSM:GetMusicWheel())
						if whee then whee:SongSearch("") end
						MESSAGEMAN:Broadcast("SearchQueryUpdated", {query = searchString})
						return true
					end
				end
			end
			
			-- FALLBACK TRAPPING: PROFILE sinks everything internally.
			-- Other tabs handle their own sinking in their callbacks.
			if HV.ActiveTab == "PROFILE" then
				if IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
					return true
				end
			end
			
			return false
		end -- end of HV.OverlayInputCallback
		screen:AddInputCallback(HV.OverlayInputCallback)
	end
}


-- ============================================================
-- MUSIC WHEEL FIXED HIGHLIGHT
-- ============================================================
main_af[#main_af + 1] = Def.ActorFrame {
	Name = "MusicWheelHighlight",
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH - 180, SCREEN_CENTER_Y)
		self.hv_holdLerp = 0
		self.hv_holdTarget = 0
	end,
	OnCommand = function(self)
		self:SetUpdateFunction(function(actor)
			actor.hv_holdLerp = actor.hv_holdLerp + (actor.hv_holdTarget - actor.hv_holdLerp) * 0.16
			actor:x(SCREEN_WIDTH - 180 + SCREEN_WIDTH * 0.32 * actor.hv_holdLerp)
		end)
	end,
	HVLeftMousePeekHoldChangedMessageCommand = function(self, params)
		local held = params and params.Held and params.Allowed
		self.hv_holdTarget = held and 1 or 0
	end,
	
	-- The main highlight box - fixed in center
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(280, 40)
				:diffuse(accentColor):diffusealpha(0.12)
		end,
		OnCommand = function(self)
			self:playcommand("Pulse")
		end,
		PulseCommand = function(self)
			self:stoptweening()
				:linear(0.8):diffusealpha(0.2)
				:linear(0.8):diffusealpha(0.12)
				:queuecommand("Pulse")
		end
	},
	

}


-- ============================================================
-- MUSIC WHEEL HOLD TRANSFORM
-- ============================================================
main_af[#main_af + 1] = Def.ActorFrame {
	Name = "MusicWheelHoldTransformDriver",
	InitCommand = function(self)
		self.hv_holdLerp = 0
		self.hv_holdTarget = 0
	end,
	OnCommand = function(self)
		self:SetUpdateFunction(function(actor)
			actor.hv_holdLerp = actor.hv_holdLerp + (actor.hv_holdTarget - actor.hv_holdLerp) * 0.16
			ApplyNativeMusicWheelHoldTransform(actor.hv_holdLerp)
		end)
	end,
	HVLeftMousePeekHoldChangedMessageCommand = function(self, params)
		local held = params and params.Held and params.Allowed
		self.hv_holdTarget = held and 1 or 0
	end
}


-- ============================================================
-- PROFILE OVERLAY
-- ============================================================

-- ============================================================
-- PROFILE OVERLAY REDESIGN (Sidebar + Main)
-- ============================================================

-- ============================================================
-- PROFILE OVERLAY REDESIGN (Sidebar + Main)
-- ============================================================

local profileOverlay = Def.ActorFrame {
	Name = "ProfileOverlay",
	InitCommand = function(self)
		profileOverlayActor = self
		self.topPage = 1
		self.recentPage = 1
		self.currentSkillset = "Overall"
		self.isRecentMode = false
		self.isOnlineMode = true
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false)
	end,
	
	-- Dark Background (Dim the rest of the screen)
	Def.Quad {
		InitCommand = function(self) self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,0.85")) end,
	},
	-- Main Panel BG
	Def.Quad { InitCommand = function(self) self:zoomto(overlayW, overlayH):diffuse(bgCard):diffusealpha(0.98) end },
	
	-- 1. Grade Sidebar (Far Left)
	Def.ActorFrame {
		Name = "GradeSidebar",
		InitCommand = function(self) self:x(-overlayW/2 + gradeSidebarW/2) end,
		Def.Quad { InitCommand = function(self) self:zoomto(gradeSidebarW, overlayH):diffuse(color("0.05,0.05,0.05,1")) end },
		
		-- Vertical Line Separator
		Def.Quad {
			InitCommand = function(self) 
				self:halign(1):x(gradeSidebarW/2):zoomto(1, overlayH):diffuse(accentColor):diffusealpha(0.3)
			end
		},

		-- Grades Display
		(function()
			local g = Def.ActorFrame { InitCommand = function(self) self:y(-overlayH/2 + 60) end }
			local grades = {"AAAAA", "AAAA", "AAA", "AA", "A"}
			local tiers = {"Grade_Tier01", "Grade_Tier04", "Grade_Tier07", "Grade_Tier10", "Grade_Tier13"}

			g[#g+1] = Def.ActorFrame {
				InitCommand = function(self) self:y(-35) end,
				Def.Quad {
					InitCommand = function(self)
						self:zoomto(gradeSidebarW - 12, 20):diffuse(accentColor):diffusealpha(0.22)
					end
				},
				LoadFont("Common Normal") .. {
					Text = "STATS",
					InitCommand = function(self)
						self:zoom(0.28):diffuse(brightText)
					end
				}
			}
			
			for i, grade in ipairs(grades) do
				local gy = (i-1) * 32
				g[#g+1] = Def.ActorFrame {
					InitCommand = function(self) self:y(gy) end,
					-- Grade Label
					LoadFont("Common Normal") .. {
						Text = HV.GetGradeName(tiers[i]),
						InitCommand = function(self) 
							self:halign(0.5):xy(0, -6):zoom(0.35)
							self:diffuse(HVColor.GetGradeColor(tiers[i]))
						end
					},
					-- Count
					LoadFont("Common Normal") .. {
						InitCommand = function(self) 
							self:halign(0.5):xy(0, 8):zoom(0.35):diffuse(mainText)
						end,
						BeginCommand = function(self)
							if GRADECOUNTERSTORAGE then
								self:settext(GRADECOUNTERSTORAGE[grade] or 0)
							end
						end,
						UpdateOverlayUIMessageCommand = function(self)
							if GRADECOUNTERSTORAGE then
								self:settext(GRADECOUNTERSTORAGE[grade] or 0)
							end
						end
					}
				}
			end
			return g
		end)()
	},

	-- 2. Profile Sidebar (Middle)
	Def.ActorFrame {
		Name = "Sidebar",
		InitCommand = function(self) self:x(-overlayW/2 + gradeSidebarW + profileSidebarW/2) end,
		Def.Quad { InitCommand = function(self) self:zoomto(profileSidebarW, overlayH):diffuse(color("0.07,0.07,0.07,1")) end },
		
		-- Sidebar Separator with Glow
		Def.Quad {
			InitCommand = function(self) 
				self:halign(1):x(profileSidebarW/2):zoomto(1, overlayH):diffuse(accentColor):diffusealpha(0.3)
			end
		},
		Def.Quad {
			InitCommand = function(self) 
				self:halign(1):x(profileSidebarW/2):zoomto(4, overlayH):diffuse(accentColor):diffusealpha(0.1)
			end
		},
		
		-- Avatar / Info
		Def.ActorFrame {
			Name = "PlayerInfo",
			InitCommand = function(self) self:y(-overlayH/2 + 50) end,
			Def.Quad { Name = "Bg", InitCommand = function(self) self:zoomto(54, 54):diffuse(color("0,0,0,0.5")) end },
			Def.Sprite {
				Name = "Avatar",
				InitCommand = function(self) self:zoomto(54, 54):playcommand("UpdateAvatar") end,
				UpdateOverlaySkillsetsMessageCommand = function(self) self:playcommand("UpdateAvatar") end,
				AvatarChangedMessageCommand = function(self) self:playcommand("UpdateAvatar") end,
				UpdateAvatarCommand = function(self)
					local path = getAvatarPath()
					if path and path ~= "" and FILEMAN:DoesFileExist(path) then
						self:Load(path):visible(true)
					else
						self:visible(false)
					end
					self:scaletoclipped(54, 54)
				end
			},

			LoadFont("Common Normal") .. {
				InitCommand = function(self) self:y(40):zoom(0.4):diffuse(brightText) end,
				UpdateOverlaySkillsetsMessageCommand = function(self)
					local p = profileOverlayActor
					if p and not p.isOnlineMode then
						local prof = PROFILEMAN:GetProfile(PLAYER_1)
						if prof then
							self:settext(prof:GetDisplayName())
							return
						end
					end
					self:settext(HV.GetPlayerName())
				end
			},
			Def.ActorFrame {
				Name = "PlayerLevelBadge",
				InitCommand = function(self) self:xy(-22, 54) end,
				UpdateOverlaySkillsetsMessageCommand = function(self)
					local prof = PROFILEMAN:GetProfile(PLAYER_1)
					if prof and HV.GetLevelColor then
						local level = HV.GetLevel(prof)
						self:GetChild("Badge"):diffuse(HV.GetLevelColor(level))
						self:GetChild("Txt"):settextf("Lv. %d", level)
						self:visible(true)
					elseif prof then
						self:GetChild("Badge"):diffuse(color("#666666"))
						self:GetChild("Txt"):settextf("Lv. %d", HV.GetLevel(prof))
						self:visible(true)
					else
						self:visible(false)
					end
				end,
				-- Badge Quad
				Def.Quad {
					Name = "Badge",
					InitCommand = function(self)
						self:zoomto(36, 12):diffusealpha(0.8)
					end
				},
				-- Level Text
				LoadFont("Common Normal") .. {
					Name = "Txt",
					InitCommand = function(self)
						self:zoom(0.32):diffuse(color("#000000"))
					end
				}
			},
			-- Progress Bar
			Def.ActorFrame {
				Name = "LevelProgress",
				InitCommand = function(self) self:y(68) end,
				UpdateOverlaySkillsetsMessageCommand = function(self)
					local prof = PROFILEMAN:GetProfile(PLAYER_1)
					if prof and HV.GetLevelProgress then
						local progress, cur, total = HV.GetLevelProgress(prof)
						self:GetChild("Bar"):smooth(0.5):zoomx(60 * progress)
						self:GetChild("Num"):settextf("%d / %d XP", cur, total)
						self:visible(true)
					elseif prof then
						self:GetChild("Bar"):zoomx(0)
						self:GetChild("Num"):settext("")
						self:visible(true)
					else
						self:visible(false)
					end
				end,
				-- Bar BG
				Def.Quad {
					InitCommand = function(self) self:zoomto(60, 3):diffuse(0,0,0,0.5) end
				},
				-- Bar Fill
				Def.Quad {
					Name = "Bar",
					InitCommand = function(self) self:halign(0):x(-30):zoomto(0, 3):diffuse(color("#FF4081")) end
				},
				-- Numbers
				LoadFont("Common Normal") .. {
					Name = "Num",
					InitCommand = function(self) self:y(8):zoom(0.22):diffuse(subText) end
				}
			},
			LoadFont("Common Normal") .. {
				Name = "Rating",
				InitCommand = function(self) self:xy(22, 54):zoom(0.55):diffuse(accentColor) end,
				UpdateOverlaySkillsetsMessageCommand = function(self)
					if not HV.ShowMSD() then self:visible(false); return end
					local val = 0
					local prof = PROFILEMAN:GetProfile(PLAYER_1)
					if DLMAN:IsLoggedIn() and profileOverlayActor.isOnlineMode then 
						val = DLMAN:GetSkillsetRating("Overall")
					elseif prof then
						val = prof:GetPlayerRating()
					end
					self:visible(true):settext(string.format("%.2f", val)):diffuse(HVColor.GetMSDRatingColor(val))
				end
			}
		},

		-- Vertical Skillset Tabs
		(function()
			local tabs = Def.ActorFrame {
				Name = "SkillsetTabs",
				InitCommand = function(self) self:y(-overlayH/2 + 140) end
			}
			for i, ss in ipairs(skillsets) do
				tabs[#tabs+1] = Def.ActorFrame {
					Name = "Tab_" .. ss,
					InitCommand = function(self) self:y((i-1) * skillsetTabH) end,
					Def.Quad {
						Name = "Bg",
						InitCommand = function(self) self:zoomto(profileSidebarW - 12, skillsetTabH - 4):halign(0):x(-profileSidebarW/2 + 6):diffuse(bgCard):diffusealpha(0.4) end
					},
					-- Active bar
					Def.Quad {
						Name = "ActiveBar",
						InitCommand = function(self) self:halign(0):x(-profileSidebarW/2 + 6):zoomto(3, skillsetTabH - 4):diffuse(accentColor):visible(false) end,
						UpdateOverlayUIActionCommand = function(self)
							local parent = profileOverlayActor
							if not parent then return end
							self:visible(parent.currentSkillset == ss and not parent.isRecentMode)
						end,
						UpdateOverlayUIMessageCommand = function(self) self:playcommand("UpdateOverlayUIAction") end
					},
					LoadFont("Common Normal") .. {
						Name = "Label",
						InitCommand = function(self) self:halign(0):x(-profileSidebarW/2 + 16):zoom(0.30):diffuse(subText):settext(ss:upper()) end
					},
					LoadFont("Common Normal") .. {
						Name = "Val",
						InitCommand = function(self) self:halign(1):x(profileSidebarW/2 - 20):zoom(0.32):diffuse(mainText) end,
						UpdateOverlaySkillsetsMessageCommand = function(self)
							if not HV.ShowMSD() then self:visible(false); return end
							local val = 0
							local prof = PROFILEMAN:GetProfile(PLAYER_1)
							if DLMAN:IsLoggedIn() and profileOverlayActor.isOnlineMode then 
								val = DLMAN:GetSkillsetRating(ss)
							elseif prof then
								if ss == "Overall" then val = prof:GetPlayerRating()
								else val = prof:GetPlayerSkillsetRating(i-2) or 0 end
							end
							self:visible(true):settext(string.format("%.2f", val)):diffuse(HVColor.GetMSDRatingColor(val))
						end
					},
					SetUpdateFunction = function(af)
						local mouseX = INPUTFILTER:GetMouseX()
						local mouseY = INPUTFILTER:GetMouseY()
						local parent = profileOverlayActor
						if not parent or not parent:GetVisible() then return end
						
						local sidebarX = SCREEN_CENTER_X - overlayW/2
						local profileSidebarX = sidebarX + gradeSidebarW
						
						local rx = mouseX - profileSidebarX
						local ry = mouseY - (SCREEN_CENTER_Y - overlayH/2)
						
						local over = rx >= 10 and rx <= profileSidebarW - 10 
						         and ry >= (140 + (i-1)*skillsetTabH - skillsetTabH/2) 
								 and ry <= (140 + (i-1)*skillsetTabH + skillsetTabH/2)
						
						local active = (parent.currentSkillset == ss) and not parent.isRecentMode
						if active then
							bg:diffuse(accentColor):diffusealpha(0.25)
						elseif over then
							bg:diffuse(color("0.3,0.3,0.3,0.3"))
						else
							bg:diffuse(bgCard):diffusealpha(0.4)
						end
					end
				}
			end
			return tabs
		end)(),
	},

	-- 3. Main Area (Scores - Far Right)
	Def.ActorFrame {
		Name = "MainArea",
		InitCommand = function(self) self:x(-overlayW/2 + gradeSidebarW + profileSidebarW + mainPartW/2) end,
		-- Area Header
		Def.ActorFrame {
			Name = "MainHeader",
			InitCommand = function(self) self:y(-overlayH/2 + 35) end,
			LoadFont("Common Normal") .. {
				InitCommand = function(self) self:halign(0):x(-mainPartW/2 + 30):zoom(0.5):diffuse(brightText) end,
				UpdateOverlayUIMessageCommand = function(self)
					local p = profileOverlayActor
					if not p then return end
					local modeText
					if p.isRecentMode then
						modeText = "RECENT SCORES (LOCAL)"
					else
						local src = (p.isOnlineMode and DLMAN:IsLoggedIn()) and "ONLINE" or "LOCAL"
						modeText = "TOP SCORES (" .. p.currentSkillset:upper() .. " · " .. src .. ")"
					end
					self:settext(modeText)
				end
			},
			-- Toggle Top/Recent Button
			Def.ActorFrame {
				Name = "ModeToggle",
				InitCommand = function(self) self:x(mainPartW/2 - 250) end,
				Def.Quad {
					Name = "Bg",
					InitCommand = function(self) 
						self:zoomto(100, 24):diffuse(accentColor):diffusealpha(0.15)
					end
				},
				LoadFont("Common Normal") .. {
					Name = "Txt",
					InitCommand = function(self) self:zoom(0.32):diffuse(brightText):settext("TOP / RECENT") end
				},
				SetUpdateFunction = function(af)
					local mouseX = INPUTFILTER:GetMouseX()
					local mouseY = INPUTFILTER:GetMouseY()
					local parent = profileOverlayActor
					if not parent or not parent:GetVisible() then return end
					local rx = mouseX - (SCREEN_CENTER_X - overlayW/2)
					local ry = mouseY - (SCREEN_CENTER_Y - overlayH/2)
					local over = rx >= sidebarW + mainPartW - 300 and rx <= sidebarW + mainPartW - 200
					         and ry >= 23 and ry <= 47
					local bg = af:GetChild("Bg")
					if parent.isRecentMode then
						bg:diffusealpha(0.4)
					elseif over then
						bg:diffusealpha(0.3)
					else
						bg:diffusealpha(0.15)
					end
				end
			},
			-- Toggle Online/Local Button
			Def.ActorFrame {
				Name = "SourceToggle",
				InitCommand = function(self) self:x(mainPartW/2 - 140) end,
				Def.Quad {
					Name = "Bg",
					InitCommand = function(self) 
						self:zoomto(100, 24):diffuse(accentColor):diffusealpha(0.15)
					end
				},
				LoadFont("Common Normal") .. {
					Name = "Txt",
					InitCommand = function(self) self:zoom(0.32) end,
					UpdateOverlayUIMessageCommand = function(self)
						local p = profileOverlayActor
						if p.isRecentMode then
							self:settext("ONLINE/LOCAL"):diffuse(dimText)
						else
							local active = p.isOnlineMode and DLMAN:IsLoggedIn()
							self:settext(active and "ONLINE" or "LOCAL"):diffuse(brightText)
						end
					end
				},
				SetUpdateFunction = function(af)
					local mouseX = INPUTFILTER:GetMouseX()
					local mouseY = INPUTFILTER:GetMouseY()
					local parent = profileOverlayActor
					if not parent or not parent:GetVisible() then return end
					local rx = mouseX - (SCREEN_CENTER_X - overlayW/2)
					local ry = mouseY - (SCREEN_CENTER_Y - overlayH/2)
					local over = rx >= sidebarW + mainPartW - 190 and rx <= sidebarW + mainPartW - 90
					         and ry >= 23 and ry <= 47
					local bg = af:GetChild("Bg")
					if parent.isRecentMode then
						bg:diffuse(dimText):diffusealpha(0.1)
					elseif (parent.isOnlineMode and DLMAN:IsLoggedIn()) or over then
						bg:diffuse(accentColor):diffusealpha(0.4)
					else
						bg:diffuse(accentColor):diffusealpha(0.15)
					end
				end
			},
			-- Upload All Button
			Def.ActorFrame {
				Name = "UploadBtn",
				InitCommand = function(self) self:x(mainPartW/2 - 40) end,
				Def.Quad {
					Name = "Bg",
					InitCommand = function(self) self:zoomto(80, 24):diffuse(color("0.1,0.4,0.1,0.5")) end
				},
				LoadFont("Common Normal") .. {
					InitCommand = function(self) self:zoom(0.32):diffuse(brightText):settext("UPLOAD ALL") end
				},
				SetUpdateFunction = function(af)
					local mouseX = INPUTFILTER:GetMouseX()
					local mouseY = INPUTFILTER:GetMouseY()
					local parent = profileOverlayActor
					if not parent or not parent:GetVisible() then return end
					local rx = mouseX - (SCREEN_CENTER_X - overlayW/2)
					local ry = mouseY - (SCREEN_CENTER_Y - overlayH/2)
					local over = rx >= sidebarW + mainPartW - 80 and rx <= sidebarW + mainPartW and ry >= 23 and ry <= 47
					local bg = af:GetChild("Bg")
					if over then
						bg:diffusealpha(0.8)
					else
						bg:diffusealpha(0.5)
					end
				end
			}
		},
		
		-- Score List Rows
		(function()
			local rows = Def.ActorFrame {
				Name = "ScoreListRows",
				InitCommand = function(self) self:y(-overlayH/2 + rowsYStart) end,
			}
			for i = 1, scorePageSize do
				rows[#rows+1] = Def.ActorFrame {
					Name = "Row_" .. i,
					InitCommand = function(self) self:y((i-1) * rowH) end,
					Def.Quad {
						Name = "Bg",
						InitCommand = function(self) 
							self:zoomto(mainPartW - 30, rowH - 4)
								:diffuse(color("0,0,0,0.4"))
								:fadeleft(0.1):faderight(0.1)
						end
					},
					-- Row border accent
					Def.Quad {
						Name = "Border",
						InitCommand = function(self)
							self:zoomto(mainPartW - 30, 1):valign(1):y(rowH/2 - 2)
								:diffuse(accentColor):diffusealpha(0.05)
						end
					},
					LoadFont("Common Normal") .. {
						Name = "SSR",
						InitCommand = function(self) self:halign(0):x(-mainPartW/2 + 30):zoom(0.4) end
					},
					LoadFont("Zpix normal") .. {
						Name = "Title",
						InitCommand = function(self) self:halign(0):x(-mainPartW/2 + 90):y(-5):zoom(0.35):diffuse(brightText):maxwidth(400 * 1.5) end
					},
					LoadFont("Common Normal") .. {
						Name = "Details",
						InitCommand = function(self) self:halign(0):x(-mainPartW/2 + 90):y(7):zoom(0.25):diffuse(dimText) end
					},
					LoadFont("Common Normal") .. {
						Name = "Percent",
						InitCommand = function(self) self:halign(1):x(mainPartW/2 - 220):zoom(0.42):diffuse(accentColor) end
					},
					LoadFont("Common Normal") .. {
						Name = "Validation",
						InitCommand = function(self) self:halign(1):x(mainPartW/2 - 30):zoom(0.28):diffuse(subText) end
					},
					-- Invalid Indicator
					LoadFont("Common Normal") .. {
						Name = "InvalidIndicator",
						InitCommand = function(self) self:halign(0):x(-mainPartW/2 + 30):y(-8):zoom(0.25):diffuse(color("1,0,0,1")):settext("[INVALID]"):visible(false) end
					},
					SetUpdateFunction = function(af)
						local parent = profileOverlayActor
						if not parent or not parent:GetVisible() then return end
						local mouseX = INPUTFILTER:GetMouseX()
						local mouseY = INPUTFILTER:GetMouseY()
						local rx = mouseX - (SCREEN_CENTER_X - overlayW/2)
						local ry = mouseY - (SCREEN_CENTER_Y - overlayH/2)
						local rowTop = rowsYStart + (i-1)*rowH - rowH/2
						local rowBottom = rowTop + rowH
						local scoreAreaX = gradeSidebarW + profileSidebarW
						local over = rx >= scoreAreaX + 10 and rx <= overlayW - 10 and ry >= rowTop and ry <= rowBottom
						local bg = af:GetChild("Bg")
						local score = af.currentScore
						
						if score and type(score) ~= "table" and not score:GetEtternaValid() then
							bg:diffuse(color("0.5,0.2,0.2,0.3"))
						else
							bg:diffuse(color("0,0,0,0.3"))
						end
						
						if over then
							bg:diffusealpha(0.6)
						end
					end,
					OverlayRowClickedMessageCommand = function(self, params)
						if params.index ~= i then return end
						local score = self.currentScore
						if not score then return end
						local ck = (type(score)=="table") and score.chartkey or score:GetChartKey()
						if not ck then return end
						local song = SONGMAN:GetSongByChartKey(ck)
						if song then
							local screen = SCREENMAN:GetTopScreen()
							if screen and screen.GetMusicWheel then
								screen:GetMusicWheel():SelectSong(song)
							end
						end
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""}) -- Close on select
					end,
					OverlayRowRightClickedMessageCommand = function(self, params)
						if params.index ~= i then return end
						local score = self.currentScore
						if not score or type(score) == "table" then return end
						score:ToggleEtternaValidation()
						if score:GetEtternaValid() then
							ms.ok("Score validated")
						else
							ms.ok("Score invalidated")
						end
						MESSAGEMAN:Broadcast("UpdateOverlayUI")
					end
				}
			end
			return rows
		end)(),
		-- Footer Pagination
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:y(overlayH/2 - 25):zoom(0.35):diffuse(dimText) end,
			UpdateOverlayUIMessageCommand = function(self)
				local p = profileOverlayActor
				if not p then return end
				local cur = p.isRecentMode and p.recentPage or p.topPage
				self:settext("PAGE " .. cur .. " · CLICK TO FIND SONG · RIGHT-CLICK TO VALIDATE (LOCAL)")
			end
		}
	},

	UpdateAllScoresCommand = function(self)
		local rows = self:GetChild("MainArea"):GetChild("ScoreListRows")
		local start = ((self.isRecentMode and self.recentPage or self.topPage) - 1) * scorePageSize

		-- Safe Pagination: Instead of checking totals (which might not exist in all versions),
		-- we'll just allow scrolling up to a reasonble limit or until we hit empty rows.
		local maxPage = 100 -- Large enough safety net
		
		local maxPage = 100 -- Logic clamping below will handle real end
		
		if self.isRecentMode then
			SCOREMAN:SortRecentScoresForGame()
		elseif not self.isOnlineMode then
			SCOREMAN:SortSSRsForGame(self.currentSkillset)
		end
		
		local foundAnyOnPage = false
		for i = 1, scorePageSize do
			local row = rows:GetChild("Row_" .. i)
			local pageIndex = start + i
			local score = nil
			
			if self.isRecentMode then
				-- Local score APIs are 1-indexed; using pageIndex keeps row 1 aligned to slot 1.
				local ok, res = pcall(function() return SCOREMAN:GetRecentScoreForGame(pageIndex) end)
				score = (ok and res ~= nil) and res or nil
			else
				if self.isOnlineMode and DLMAN:IsLoggedIn() then
					-- Online scores are 1-indexed
					local ok, res = pcall(function() return DLMAN:GetTopSkillsetScore(pageIndex, self.currentSkillset) end)
					score = (ok and res ~= nil) and res or nil
				else
					local ok, res = pcall(function() return SCOREMAN:GetTopSSRHighScoreForGame(pageIndex, self.currentSkillset) end)
					score = (ok and res ~= nil) and res or nil
				end
			end
			
			row.currentScore = score
			if score then
				foundAnyOnPage = true
				row:visible(true)
				local title, diff, rate, date, wife, ssr, metadata
				if type(score) == "table" then
					title = score.songName or "???"
					diff = ToEnumShortString(score.difficulty or "Beginner")
					rate = score.rate or 1.0
					date = score.date or "N/A"
					wife = score.wife or 0
					ssr = score.ssr or 0
					
					local ct = "Clear"
					
					-- If judgments are available in the table, show them
					if score.w1 then
						metadata = string.format("%s  |  %d/%d/%d/%d/%d/%d", THEME:GetString("ClearTypes", ct), score.w1, score.w2, score.w3, score.w4, score.w5, score.miss or 0)
					else
						metadata = string.format("%s  |  ONLINE", THEME:GetString("ClearTypes", ct))
					end
				else
					local ck = score:GetChartKey()
					local thssong = SONGMAN:GetSongByChartKey(ck)
					local thssteps = SONGMAN:GetStepsByChartKey(ck)
					title = thssong and thssong:GetDisplayMainTitle() or "???"
					diff = thssteps and ToEnumShortString(thssteps:GetDifficulty()) or "?"
					rate = score:GetMusicRate()
					date = score:GetDate()
					wife = score:GetWifeScore()
					ssr = score:GetSkillsetSSR(self.isRecentMode and "Overall" or self.currentSkillset)
					
					local ct = getDetailedClearType(score)
					local w1 = score:GetTapNoteScore("TapNoteScore_W1")
					local w2 = score:GetTapNoteScore("TapNoteScore_W2")
					local w3 = score:GetTapNoteScore("TapNoteScore_W3")
					local w4 = score:GetTapNoteScore("TapNoteScore_W4")
					local w5 = score:GetTapNoteScore("TapNoteScore_W5")
					local m = score:GetTapNoteScore("TapNoteScore_Miss")
					
					-- Judge calculation
					local jIndex = 4
					if not PREFSMAN:GetPreference("SortBySSRNormPercent") and type(score.GetJudgeScale) == "function" then
						local scale = score:GetJudgeScale()
						if scale then
							scale = math.floor(scale * 100 + 0.5) / 100
							for k, v in pairs(ms.JudgeScalers) do
								if math.floor(v * 100 + 0.5) / 100 == scale then
									jIndex = k
									if jIndex >= 4 then break end
								end
							end
							jIndex = math.max(4, math.min(9, jIndex))
						end
					end
					metadata = string.format("J%d  |  %s  |  %d/%d/%d/%d/%d/%d", jIndex, THEME:GetString("ClearTypes", ct), w1, w2, w3, w4, w5, m)
				end
				
				local ssrLabel = row:GetChild("SSR")
				ssrLabel:settext(string.format("%.2f", ssr)):diffuse(HVColor.GetMSDRatingColor(ssr)):visible(HV.ShowMSD())
				row:GetChild("Title"):settext(title)
				row:GetChild("Details"):settext(string.format("%s · %.2fx · %s", diff, rate, date))
				
				local pLabel = row:GetChild("Percent")
				if wife >= 0.997 then
					pLabel:settext(string.format("%.4f%%", wife * 100))
				else
					pLabel:settext(string.format("%.2f%%", wife * 100))
				end
				
				-- Use centralized grade colors
				local grade = getWifeGradeTier(wife * 100)
				pLabel:diffuse(HVColor.GetGradeColor(grade))
				
				row:GetChild("Validation"):settext(metadata)
				
				local isInvalid = type(score) ~= "table" and not score:GetEtternaValid()
				row:GetChild("InvalidIndicator"):visible(isInvalid)
				if isInvalid then
					row:GetChild("Bg"):diffuse(color("0.5,0.05,0.05,0.4"))
					row:GetChild("SSR"):diffuse(color("0.6,0.6,0.6,1"))
					row:GetChild("Title"):diffuse(color("0.6,0.6,0.6,1"))
				else
					row:GetChild("Bg"):diffuse(color("0,0,0,0.3"))
					-- SSR color is set by HVColor.GetMSDRatingColor in line above
					row:GetChild("Title"):diffuse(brightText)
				end
			else
				row:visible(false)
			end
		end

		-- Dynamic Clamping: If page is empty and not page 1, go back
		if not foundAnyOnPage and (self.isRecentMode and self.recentPage > 1 or self.topPage > 1) then
			if self.isRecentMode then self.recentPage = self.recentPage - 1
			else self.topPage = self.topPage - 1 end
			self:playcommand("UpdateAllScores")
			return
		end
		
		self:playcommand("UpdateOverlaySkillsets")
		self:GetChild("MainArea"):playcommand("UpdateOverlayUI")
		self:GetChild("Sidebar"):playcommand("UpdateOverlayUI")
	end,

	-- Core Logic Signals
	UpdateOverlayUIMessageCommand = function(self) self:playcommand("UpdateAllScores") end,
	SelectMusicTabChangedMessageCommand = function(self, params)
		HV.ActiveTab = params and params.Tab or ""
		local targetTab = params and params.Tab or ""
		
		-- Set input redirection for ALL tabs to block the C++ MusicWheel
		-- Force redirection if tab is NOT empty, otherwise turn it off
		local redirected = (targetTab ~= "")
		
		if redirected then
			-- Cancel any pending unlock so we don't accidentally unlock if we switch tabs rapidly
			self:stoptweening()
			SCREENMAN:set_input_redirected(PLAYER_1, true)
			SCREENMAN:set_input_redirected(PLAYER_2, true)
		else
			-- Unlock is driven by the hide tween path below. Do not queue it here,
			-- because the subsequent stoptweening() for the fade-out would cancel it.
		end

		if targetTab == "PROFILE" then
			self:visible(true):stoptweening()
				:diffusealpha(0):linear(0.15):diffusealpha(1)
			self:playcommand("UpdateAllScores")
		else
			self:stoptweening():linear(0.1):diffusealpha(0):queuecommand("UnlockInput"):queuecommand("Hide")
		end
	end,
	HideCommand = function(self) self:visible(false) end,

	UnlockInputCommand = function(self)
		-- Only unlock if we are still not in an active tab (safety check)
		if (HV.ActiveTab or "") == "" then
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			SCREENMAN:set_input_redirected(PLAYER_2, false)
		end
	end,

	NextScorePageMessageCommand = function(self)
		if self.isRecentMode then self.recentPage = self.recentPage + 1
		else self.topPage = self.topPage + 1 end
		self:playcommand("UpdateAllScores")
	end,
	PrevScorePageMessageCommand = function(self)
		if self.isRecentMode then self.recentPage = math.max(1, self.recentPage - 1)
		else self.topPage = math.max(1, self.topPage - 1) end
		self:playcommand("UpdateAllScores")
	end
}

main_af[#main_af + 1] = profileOverlay

-- ============================================================
-- TOP HEADER (Search & Back)
-- ============================================================
local headerH = 40
main_af[#main_af + 1] = Def.ActorFrame {
	Name = "HeaderBar",
	InitCommand = function(self)
		self:xy(0, 0)
		self.hv_holdLerp = 0
		self.hv_holdTarget = 0
	end,
	OnCommand = function(self)
		self:SetUpdateFunction(function(actor)
			actor.hv_holdLerp = actor.hv_holdLerp + (actor.hv_holdTarget - actor.hv_holdLerp) * 0.16
			actor:y(-(headerH + 16) * actor.hv_holdLerp)
		end)
	end,
	HVLeftMousePeekHoldChangedMessageCommand = function(self, params)
		local held = params and params.Held and params.Allowed
		self.hv_holdTarget = held and 1 or 0
	end,
	
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
				:zoomto(SCREEN_WIDTH, headerH)
				:diffuse(color("0.04,0.04,0.04,1"))
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(1)
				:xy(0, headerH)
				:zoomto(SCREEN_WIDTH, 2)
				:diffuse(accentColor):diffusealpha(0.5)
		end
	},
	
	-- Back Button
	Def.ActorFrame {
		Name = "BtnBack",
		InitCommand = function(self) self:xy(0, 0) end,
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(80, headerH):diffuse(color("0,0,0,0"))
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):xy(40, headerH / 2):zoom(0.4):diffuse(mainText):settext("< BACK")
			end
		}
	},
	
	-- Search Bar Frame
	Def.ActorFrame {
		Name = "SearchBar",
		InitCommand = function(self) self:xy(SCREEN_WIDTH / 2 - 150, 6) end,
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(300, 28)
					:diffuse(color("0.1,0.1,0.1,1"))
			end,
			SelectMusicTabChangedMessageCommand = function(self, params)
				if params.Tab == "SEARCH" then
					self:diffuse(color("0.12,0.12,0.12,1"))
				else
					self:diffuse(color("0.1,0.1,0.1,1"))
				end
			end
		},
		-- Left accent line (glows when search is active)
		Def.Quad {
			Name = "AccentBorder",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(2, 28)
					:diffuse(accentColor):diffusealpha(0)
			end,
			SelectMusicTabChangedMessageCommand = function(self, params)
				if params.Tab == "SEARCH" then
					self:diffusealpha(0.8)
				else
					self:diffusealpha(0)
				end
			end
		},
		Def.Sprite {
			Texture = THEME:GetPathG("", "search.png"),
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(8, 14):zoom(0.45):diffusealpha(0.7)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "SearchPlaceholder",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(32, 14):zoom(0.35):diffuse(subText):settext("Click here to Search (or Ctrl + 4)")
			end,
			SelectMusicTabChangedMessageCommand = function(self, params)
				if params.Tab == "SEARCH" then
					if searchString == "" then
						self:settext("Type to search..."):diffuse(subText)
					else
						self:settext(searchString):diffuse(brightText)
					end
				else
					if searchString ~= "" then
						self:settext("Search: " .. searchString):diffuse(brightText)
					else
						self:settext("Click here to Search (or Ctrl + 4)"):diffuse(subText)
					end
				end
			end,
			SearchQueryUpdatedMessageCommand = function(self, params)
				if HV.ActiveTab == "SEARCH" then
					if searchString == "" then
						self:settext("Type to search..."):diffuse(subText)
					else
						self:settext(searchString):diffuse(brightText)
					end
				else
					if searchString ~= "" then
						self:settext("Search: " .. searchString):diffuse(brightText)
					else
						self:settext("Click here to Search (or Ctrl + 4)"):diffuse(subText)
					end
				end
			end
		},
		-- Integrated Blinking Cursor
		LoadFont("Common Normal") .. {
			Name = "Cursor",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(32, 14):zoom(0.35):diffuse(accentColor):settext("|"):visible(false)
			end,
			SelectMusicTabChangedMessageCommand = function(self, params)
				if params.Tab == "SEARCH" then
					self:visible(true):playcommand("Blink")
					self:playcommand("Position")
				else
					self:visible(false):stoptweening()
				end
			end,
			SearchQueryUpdatedMessageCommand = function(self, params)
				self:playcommand("Position")
			end,
			PositionCommand = function(self)
				local placeholder = self:GetParent():GetChild("SearchPlaceholder")
				if placeholder then
					if searchString == "" then
						-- Left of "Type to search..."
						self:x(32 - 4) 
					else
						-- Right of query
						local textW = placeholder:GetZoomedWidth()
						self:x(32 + textW + 2)
					end
				end
			end,
			BlinkCommand = function(self)
				self:stoptweening():diffusealpha(1):sleep(0.5):linear(0.1):diffusealpha(0):sleep(0.3):queuecommand("Blink")
			end
		},
	},

	-- Nth Stage Display (Top Right)
	Def.ActorFrame {
		Name = "StageDisplayFrame",
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH - 20, headerH / 2)
		end,
		OnCommand = function(self)
			self:playcommand("UpdateStageDisplay")
		end,
		UpdateStageDisplayCommand = function(self)
			local stageLabel = self:GetChild("StageDisplay")
			local sessionLabel = self:GetChild("SessionGradeDisplay")
			if not stageLabel or not sessionLabel then 
				return 
			end

			-- Update Stage Number
			local stageIdx = GAMESTATE:GetCurrentStageIndex() + 1
			local text = "STAGE " .. stageIdx
			if GAMESTATE.GetCurrentStage then
				local stage = GAMESTATE:GetCurrentStage()
				if stage == "Stage_Extra1" then text = "EXTRA STAGE"
				elseif stage == "Stage_Extra2" then text = "ENCORE EXTRA"
				end
			end
			stageLabel:settext(text)

			-- Update Session Grades
			local gradeParts = {}
			if GRADECOUNTERSTORAGE then
				local grades = {"session_AAAAA", "session_AAAA", "session_AAA", "session_AA", "session_A", "session_UnderA"}
				local labels = {"AAAAA", "AAAA", "AAA", "AA", "A", "<A"}
				for i, g in ipairs(grades) do
					local count = GRADECOUNTERSTORAGE[g] or 0
					if count > 0 then
						table.insert(gradeParts, labels[i] .. ": " .. count)
					end
				end
			end
			local gradeStr = #gradeParts > 0 and table.concat(gradeParts, "  |  ") or ""
			sessionLabel:settext(gradeStr)
		end,

		LoadFont("Common Normal") .. {
			Name = "StageDisplay",
			InitCommand = function(self)
				self:halign(1):valign(1):zoom(0.4):diffuse(accentColor)
			end,
		},
		LoadFont("Common Normal") .. {
			Name = "SessionGradeDisplay",
			InitCommand = function(self)
				self:halign(1):valign(0):y(2):zoom(0.3):diffuse(accentColor)
			end,
		}
	}
}

-- ============================================================
-- BOTTOM FOOTER & TAB BUTTONS
-- ============================================================
local tabs = {"PROFILE", "SCORES", "PLAYLISTS", "FILTERS", "TAGS", "GOALS", "RANDOM"}
local tabW = 80
local footerH = 40

main_af[#main_af + 1] = Def.ActorFrame {
	Name = "FooterBar",
	InitCommand = function(self)
		self:xy(0, SCREEN_HEIGHT - footerH)
		self.hv_holdLerp = 0
		self.hv_holdTarget = 0
	end,
	OnCommand = function(self)
		self:SetUpdateFunction(function(actor)
			actor.hv_holdLerp = actor.hv_holdLerp + (actor.hv_holdTarget - actor.hv_holdLerp) * 0.16
			actor:y(SCREEN_HEIGHT - footerH + (footerH + 16) * actor.hv_holdLerp)
		end)
	end,
	HVLeftMousePeekHoldChangedMessageCommand = function(self, params)
		local held = params and params.Held and params.Allowed
		self.hv_holdTarget = held and 1 or 0
	end,
	
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
				:zoomto(SCREEN_WIDTH, footerH)
				:diffuse(color("0.04,0.04,0.04,1"))
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
				:zoomto(SCREEN_WIDTH, 2)
				:diffuse(accentColor):diffusealpha(0.5)
		end
	},
	
	-- Time Display (Right aligned)
	Def.ActorFrame {
		Name = "TimeFrame",
		InitCommand = function(self) self:xy(SCREEN_WIDTH - 20, footerH / 2) end,

		-- Session Time (Wasted human cycles)
		LoadFont("Common Normal") .. {
			Name = "SessionTime",
			InitCommand = function(self)
				self:halign(1):y(10):zoom(0.32):diffuse(dimText)
			end,
			OnCommand = function(self) self:queuecommand("Tick") end,
			TickCommand = function(self)
				local secs = GetTimeSinceStart()
				local h = math.floor(secs / 3600)
				local m = math.floor((secs % 3600) / 60)
				local s = math.floor(secs % 60)
				self:settextf("Wasted Human Cycles: %02d:%02d:%02d", h, m, s)
				self:sleep(1):queuecommand("Tick")
			end
		},

		-- Real Time Clock
		LoadFont("Common Normal") .. {
			Name = "Clock",
			InitCommand = function(self)
				self:halign(1):y(-6):zoom(0.5):diffuse(mainText)
			end,
			OnCommand = function(self) self:queuecommand("Tick") end,
			TickCommand = function(self)
				self:settext(os.date("%H:%M:%S"))
				self:sleep(1):queuecommand("Tick")
			end
		}
	}
}

-- Create Tab Buttons on Footer
for i, tabName in ipairs(tabs) do
	main_af[#main_af + 1] = Def.ActorFrame {
		Name = "FooterTab_" .. tabName,
		InitCommand = function(self)
			self:xy(10 + (i - 1) * tabW, SCREEN_HEIGHT - footerH)
			self.hv_holdLerp = 0
			self.hv_holdTarget = 0
		end,
		OnCommand = function(self)
			self:SetUpdateFunction(function(actor)
				actor.hv_holdLerp = actor.hv_holdLerp + (actor.hv_holdTarget - actor.hv_holdLerp) * 0.16
				actor:y(SCREEN_HEIGHT - footerH + (footerH + 16) * actor.hv_holdLerp)
			end)
		end,
		HVLeftMousePeekHoldChangedMessageCommand = function(self, params)
			local held = params and params.Held and params.Allowed
			self.hv_holdTarget = held and 1 or 0
		end,
		
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0)
					:zoomto(tabW, footerH)
					:diffuse(accentColor):diffusealpha(0)
			end,
			SelectMusicTabChangedMessageCommand = function(self, params)
				if params.Tab == tabName:upper() then
					self:stoptweening():linear(0.15):diffusealpha(0.25)
				else
					self:stoptweening():linear(0.15):diffusealpha(0)
				end
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0.5):valign(0.5)
					:xy(tabW / 2, footerH / 2)
					:zoom(0.35):diffuse(mainText)
					:settext(tabName)
			end,
			SelectMusicTabChangedMessageCommand = function(self, params)
				if params.Tab == tabName:upper() then
					self:stoptweening():smooth(0.15):zoom(0.4):diffuse(brightText)
				else
					self:stoptweening():smooth(0.15):zoom(0.35):diffuse(mainText)
				end
			end
		}
	}
end

-- ============================================================
-- MASTER INPUT SINK & TAB MANAGEMENT
-- ============================================================
-- (Relocated to bottom to ensure decoration callbacks are prioritized)

-- 4. Song Preview Logic (Ported from spawncamping-wallhack)
-- Loaded before other layers to ensure its message listeners clear state first.
main_af[#main_af + 1] = LoadActor("bgm.lua")

-- Load the Chart Preview layer (initially hidden)
main_af[#main_af + 1] = LoadActor("../ScreenChartPreview overlay/default.lua") .. {
	InitCommand = function(self)
		self:visible(false)
	end
}

-- Load Isolated Input Debugger (Always on top with draworder 9999)
main_af[#main_af + 1] = LoadActor("input_debugger.lua")

-- Sync previewActive state from outside


-- Load Decoration Overlays (Initially hidden, using standard Toggle[NAME]Overlay messages)
local decorOverlays = {"scores", "filters", "playlists", "tags", "goals"}
for _, name in ipairs(decorOverlays) do
	main_af[#main_af + 1] = LoadActor("../ScreenSelectMusic decorations/" .. name .. ".lua")
end

main_af[#main_af + 1] = LoadActor("../_cursor")


-- ============================================================
-- MASTER INPUT SINK & TAB MANAGEMENT (LOWER PRIORITY)
-- ============================================================
-- Relocated to ensures decoration input callbacks (search, playlists, etc.) 
-- can capture input FIRST before the global sink takes over.
main_af[#main_af + 1] = Def.ActorFrame {
	Name = "MasterInputSink",
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		
		screen:AddInputCallback(function(event)
			if not event or not event.DeviceInput then return end
			local btn = event.DeviceInput.button

			-- 1. TRACK GLOBAL TAB STATE
			local activeTab = HV.ActiveTab or ""
			
			-- 2. CHART PREVIEW TRIGGER (Space key)
			if btn == "DeviceButton_space" and activeTab == "" then
				if event.type ~= "InputEventType_FirstPress" then return end
				if previewActive then
					previewActive = false
					HV.ChartPreviewActive = false
					MESSAGEMAN:Broadcast("ChartPreviewOff")
				else
					previewActive = true
					HV.ChartPreviewActive = true
					MESSAGEMAN:Broadcast("ChartPreviewOn")
				end
				return true
			end
			
			-- 3. HANDLE OVERLAY INPUT SINKING
			if activeTab ~= "" then
				-- Sink everything for any active tab (mouse excluded)
				-- This is a fallback; primary tab logic is in HV.OverlayInputCallback
				if btn and btn:match("mouse") then return false end
				return true
			end
			
			-- 3. HANDLE CHART PREVIEW INPUT
			if previewActive then
				-- SINK ALL INPUT while preview is active except mouse
				if btn and btn:match("mouse") then return false end
				
				if event.type ~= "InputEventType_FirstPress" then return true end
				
				-- Let rate preview shortcuts pass through to the chart preview's own callback
				if event.button == "EffectUp" or event.button == "EffectDown" then return false end
				
				if event.button == "Back" or event.button == "Start" or btn == "DeviceButton_escape" then
					previewActive = false
					HV.ChartPreviewActive = false
					MESSAGEMAN:Broadcast("ChartPreviewOff")
				end
				return true
			end

			return false -- Allow all other input through
		end)
	end
}

return main_af

