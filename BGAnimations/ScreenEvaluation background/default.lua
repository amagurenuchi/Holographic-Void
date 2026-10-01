--- Holographic Void: ScreenEvaluation Background

local t = Def.ActorFrame {}
local parallaxZoom = 1.06
local parallaxX = 20
local parallaxY = 12

-- OLED Black
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}

-- Song Background Sprite
t[#t + 1] = Def.Sprite {
	Name = "SongBackground",
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH * parallaxZoom, SCREEN_HEIGHT * parallaxZoom):diffusealpha(0)
		self.hv_curX = SCREEN_CENTER_X
		self.hv_curY = SCREEN_CENTER_Y
		self.hv_targetX = SCREEN_CENTER_X
		self.hv_targetY = SCREEN_CENTER_Y
	end,
	OnCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		local showBG = HV.ShowSongBackground()
		if song and showBG and HV.GetSongBackgroundBrightness() > 0 and song:GetBackgroundPath() then
			self:visible(true):LoadBackground(song:GetBackgroundPath())
			self:zoomto(SCREEN_WIDTH * parallaxZoom, SCREEN_HEIGHT * parallaxZoom)
			local brightness = HV.GetSongBackgroundBrightness()
			self:stoptweening():linear(0.2):diffusealpha(brightness)
		else
			self:visible(false):diffusealpha(0)
		end
		self:queuecommand("ParallaxTick")
	end,
	ParallaxTickCommand = function(self)
		local showBG = HV.ShowSongBackground()
		local parallaxOn = (HV and HV.ParallaxEnabled and HV.ParallaxEnabled())
		if showBG and parallaxOn and self:GetVisible() and self:GetDiffuseAlpha() > 0 then
			local mx = INPUTFILTER:GetMouseX() or SCREEN_CENTER_X
			local my = INPUTFILTER:GetMouseY() or SCREEN_CENTER_Y
			local nx = (mx / SCREEN_WIDTH) - 0.5
			local ny = (my / SCREEN_HEIGHT) - 0.5
			self.hv_targetX = SCREEN_CENTER_X + (nx * 2 * parallaxX)
			self.hv_targetY = SCREEN_CENTER_Y + (ny * 2 * parallaxY)
		else
			self.hv_targetX = SCREEN_CENTER_X
			self.hv_targetY = SCREEN_CENTER_Y
		end
		self.hv_curX = self.hv_curX + (self.hv_targetX - self.hv_curX) * 0.16
		self.hv_curY = self.hv_curY + (self.hv_targetY - self.hv_curY) * 0.16
		self:xy(self.hv_curX, self.hv_curY)
		self:sleep(0.02):queuecommand("ParallaxTick")
	end
}

-- Subtle grid
for i = 1, 8 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, (SCREEN_HEIGHT / 9) * i)
				:zoomto(SCREEN_WIDTH, 1):diffuse(color("1,1,1,0.02"))
		end
	}
end

-- Load Shared Background Particles
t[#t + 1] = LoadActor("../_particles.lua")

return t
