--- Holographic Void: ScreenOptionsTheme Background
-- Themed background for the theme options screen (ScreenOptionsServiceChild)

local t = Def.ActorFrame {}

-- OLED Black
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}

-- Subtle grid
for i = 1, 8 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, (SCREEN_HEIGHT / 9) * i)
				:zoomto(SCREEN_WIDTH, 1):diffuse(HVColor.Accent):diffusealpha(0.08)
		end
	}
end

-- Header accent line
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, 50)
			:zoomto(SCREEN_WIDTH * 0.5, 1)
			:diffuse(HVColor.Accent):diffusealpha(0.3)
	end
}

-- Listen for option changes and force save to disk immediately
t[#t + 1] = Def.Actor {
	ThemePrefChangedMessageCommand = function(self, params)
		if params and params.Name then
			-- If accent color changed, refresh it globally
			if params.Name == "HV_AccentColor" and HVColor and HVColor.RefreshAccent then
				HVColor.RefreshAccent()
			end
		end
		-- The fallback theme engine sets ThemePrefs.NeedsSaved = true
		-- but doesn't actually commit it to file automatically from this screen.
		-- Force it here so settings persist if the game is closed.
		if ThemePrefs and ThemePrefs.ForceSave then
			ThemePrefs.ForceSave()
		end
	end
}

-- Load Shared Background Particles
t[#t + 1] = LoadActor("../_particles.lua")

return t
