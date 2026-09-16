-- BGM resolver for menu and song select screens
-- Uses the REbirth theme's quiver BGM loop.

local function shouldPlay()
	if playSongSelectBGM ~= nil then
		return playSongSelectBGM()
	elseif ThemePrefs and ThemePrefs.Get then
		return ThemePrefs.Get("HV_SongSelectBGM") ~= false
	end
	return true
end

if not shouldPlay() then
	return THEME:GetPathS("", "_silent")
end

local function resolveSound(dir, file)
	local ok, res = pcall(function() return THEME:GetPathS(dir, file) end)
	if ok and res and res ~= "" then return res end
	return nil
end

return resolveSound("", "music/quiver")
	 or resolveSound("music", "quiver")
	 or THEME:GetPathS("", "_silent")
