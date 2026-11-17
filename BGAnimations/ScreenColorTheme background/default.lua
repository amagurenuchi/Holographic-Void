--- Holographic Void: ScreenColorTheme Background
-- Cyberpunk grid background matching Theme Options aesthetics

local t = Def.ActorFrame {}

local function getAccent()
	return (HVColor and HVColor.Accent) or color("#5ABAFF")
end

-- OLED Black
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}

-- Subtle horizontal grid
for i = 1, 8 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, (SCREEN_HEIGHT / 9) * i)
				:zoomto(SCREEN_WIDTH, 1):diffuse(getAccent()):diffusealpha(0.06)
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.12):diffuse(getAccent()):diffusealpha(0.06)
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if params and params.Name == "HV_AccentColor" then
				self:stoptweening():linear(0.12):diffuse(getAccent()):diffusealpha(0.06)
			end
		end
	}
end

-- Particles
t[#t + 1] = LoadActor("../_particles.lua")

-- Refresh accent color globally when changed in this screen
t[#t + 1] = Def.Actor {
	ThemePrefChangedMessageCommand = function(self, params)
		if params and params.Name == "HV_AccentColor" and HVColor and HVColor.RefreshAccent then
			HVColor.RefreshAccent()
		end
	end
}

return t
