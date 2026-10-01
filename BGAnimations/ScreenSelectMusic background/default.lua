--- Holographic Void: ScreenSelectMusic Background
-- OLED black with subtle animated scan lines.

local t = Def.ActorFrame {}
local parallaxZoom = 1.10
local parallaxX = 40
local parallaxY = 24
local holdFillZoom = 1.22

-- Full-screen OLED black
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}

-- Song Background Sprite
t[#t + 1] = Def.Sprite {
	Name = "SongBackground",
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH * parallaxZoom, SCREEN_HEIGHT * parallaxZoom)
			:diffusealpha(0)
		self.hv_curX = SCREEN_CENTER_X
		self.hv_curY = SCREEN_CENTER_Y
		self.hv_targetX = SCREEN_CENTER_X
		self.hv_targetY = SCREEN_CENTER_Y
		self.hv_holdLerp = 0
		self.hv_holdTarget = 0
	end,
	OnCommand = function(self)
		self:playcommand("Set")
		self:stoptweening()
		self:queuecommand("ParallaxTick")
	end,
	CurrentSongChangedMessageCommand = function(self)
		self:playcommand("Set")
	end,
	OffCommand = function(self)
		self:stoptweening()
	end,
	HVLeftMousePeekHoldChangedMessageCommand = function(self, params)
		local held = params and params.Held and params.Allowed
		self.hv_holdTarget = held and 1 or 0
	end,
	ParallaxTickCommand = function(self)
		local showBG = HV.ShowSongBackground()
		local parallaxOn = (HV and HV.ParallaxEnabled and HV.ParallaxEnabled())
		self.hv_holdLerp = self.hv_holdLerp + (self.hv_holdTarget - self.hv_holdLerp) * 0.14
		if showBG and parallaxOn and self:GetVisible() and self:GetDiffuseAlpha() > 0 then
			local mx = INPUTFILTER:GetMouseX() or SCREEN_CENTER_X
			local my = INPUTFILTER:GetMouseY() or SCREEN_CENTER_Y
			local nx = (mx / SCREEN_WIDTH) - 0.5
			local ny = (my / SCREEN_HEIGHT) - 0.5
			local moveScale = 1 - self.hv_holdLerp
			self.hv_targetX = SCREEN_CENTER_X + (nx * 2 * parallaxX * moveScale)
			self.hv_targetY = SCREEN_CENTER_Y + (ny * 2 * parallaxY * moveScale)
		else
			self.hv_targetX = SCREEN_CENTER_X
			self.hv_targetY = SCREEN_CENTER_Y
		end
		self.hv_curX = self.hv_curX + (self.hv_targetX - self.hv_curX) * 0.18
		self.hv_curY = self.hv_curY + (self.hv_targetY - self.hv_curY) * 0.18
		self:xy(self.hv_curX, self.hv_curY)
		local curZoom = parallaxZoom + ((holdFillZoom - parallaxZoom) * self.hv_holdLerp)
		self:zoomto(SCREEN_WIDTH * curZoom, SCREEN_HEIGHT * curZoom)
		if showBG and self:GetVisible() then
			local brightness = HV.GetSongBackgroundBrightness()
			local boosted = brightness + ((1 - brightness) * self.hv_holdLerp)
			self:diffusealpha(boosted)
		end
		self:sleep(0.02):queuecommand("ParallaxTick")
	end,
	SetCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		local showBG = HV.ShowSongBackground()
		if song and showBG and HV.GetSongBackgroundBrightness() > 0 and song:GetBackgroundPath() then
			self:visible(true):LoadBackground(song:GetBackgroundPath())
			self:zoomto(SCREEN_WIDTH * parallaxZoom, SCREEN_HEIGHT * parallaxZoom)
			local brightness = HV.GetSongBackgroundBrightness()
			local boosted = brightness + ((1 - brightness) * self.hv_holdLerp)
			self:diffusealpha(boosted)
		else
			self:diffusealpha(0)
		end
	end
}

-- Subtle horizontal scan lines (every 3 pixels for a CRT effect)
for i = 0, math.floor(SCREEN_HEIGHT / 6) do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, i * 6)
				:zoomto(SCREEN_WIDTH, 1)
				:diffuse(color("1,1,1,0.015"))
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

-- Load Shared Background Particles
t[#t + 1] = LoadActor("../_particles.lua")

return t
