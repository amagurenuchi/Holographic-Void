--- Holographic Void: Branching Logic
-- Handles redirection between screens based on game state (e.g. no songs).

Branch.AfterInit = function()
	-- If zero songs found (and no downloads in progress), redirect to core bundle selector
	if SONGMAN:GetNumSongs() == 0 and SONGMAN:GetNumAdditionalSongs() == 0 and #DLMAN:GetDownloads() == 0 then
		return "ScreenCoreBundleSelect"
	end
	
	-- Normal flow
	return "ScreenTitleMenu"
end

function SMOnlineScreen()
	if not IsNetSMOnline() then
		return "ScreenSelectMusic"
	end
	if not IsSMOnlineLoggedIn() then
		return "ScreenSMOnlineLogin"
	end
	return "ScreenNetRoom"
end

Branch.TitleMenu = function()
	return "ScreenTitleMenu"
end

Branch.AfterTitleMenu = function()
	if PROFILEMAN:GetNumLocalProfiles() == 0 then
		return "ScreenSelectMusic"
	end
	return "ScreenSelectProfile"
end

Branch.MultiScreen = function()
	if IsNetSMOnline() then
		return "ScreenNetSelectProfile"
	end
	return "ScreenNetworkOptions"
end

Branch.AfterSelectProfile = function()
	return "ScreenSelectMusic"
end

Branch.AfterNetSelectProfile = function()
	return SMOnlineScreen()
end

Branch.LeavePackDownloader = function()
	return "ScreenTitleMenu"
end

Branch.LeaveAssets = function()
	if IsSMOnlineLoggedIn(PLAYER_1) then
		if NSMAN:GetCurrentRoomName() then
			return "ScreenNetSelectMusic"
		end
		return "ScreenNetRoom"
	end
	return "ScreenSelectMusic"
end

Trace("Holographic Void: 09 Branch.lua loaded.")
