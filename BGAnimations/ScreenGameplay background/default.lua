--- Holographic Void: ScreenGameplay Background
-- Minimal OLED black with subtle animated accent elements.

local t = Def.ActorFrame {}

-- Full-screen black base
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}

-- Song Background Sprite
t[#t + 1] = Def.Sprite {
	Name = "SongBackground",
	InitCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		local showBG = HV.ShowSongBackground()
		if song and showBG and HV.GetSongBackgroundBrightness() > 0 and song:GetBackgroundPath() then
			self:visible(true):LoadBackground(song:GetBackgroundPath())
			self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			local brightness = HV.GetSongBackgroundBrightness()
			self:diffusealpha(brightness)
		else
			self:visible(false)
		end
	end
}

-- Subtle top border accent (very dim, doesn't distract)
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_TOP + 1)
			:zoomto(SCREEN_WIDTH, 1)
			:diffuse(HVColor.Accent):diffusealpha(0.08)
	end
}

-- Subtle bottom border accent
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 1)
			:zoomto(SCREEN_WIDTH, 1)
			:diffuse(HVColor.Accent):diffusealpha(0.08)
	end
}

return t
