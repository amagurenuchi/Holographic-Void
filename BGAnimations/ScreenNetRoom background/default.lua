--- Holographic Void: ScreenNetRoom Background
-- Monochromatic cyberpunk background with subtle grid and ambient floating particles.

local t = Def.ActorFrame {}

-- Deep OLED Black Base
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}

-- Subtle Perspective / Matrix Grid
for i = 1, 9 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, (SCREEN_HEIGHT / 10) * i)
				:zoomto(SCREEN_WIDTH, 1):diffuse(HVColor.Accent):diffusealpha(0.06)
		end,
		ThemePrefChangedMessageCommand = function(self)
			self:diffuse(HVColor.Accent):diffusealpha(0.06)
		end
	}
end

-- Header accent separation glow
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, 44)
			:zoomto(SCREEN_WIDTH, 1)
			:diffuse(HVColor.Accent):diffusealpha(0.35)
	end,
	ThemePrefChangedMessageCommand = function(self)
		self:diffuse(HVColor.Accent):diffusealpha(0.35)
	end
}

-- Floating Particle Ambience
t[#t + 1] = LoadActor("../_particles.lua")

return t

