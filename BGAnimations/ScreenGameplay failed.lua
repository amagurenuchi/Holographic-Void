local t = Def.ActorFrame{
	InitCommand = function(self)
		self:diffusealpha(1)
	end,
}

-- The Darkening Slide (90% opacity)
t[#t+1] = Def.Quad{
	Name = "DarkSlide",
	InitCommand = function(self)
		self:FullScreen():diffuse(color("0,0,0,0.9")):x(-SCREEN_WIDTH)
	end,
	OffCommand = function(self)
		-- On fail, we slide in immediately (no sleep)
		self:linear(0.3):x(SCREEN_CENTER_X)
	end
}

-- Stage Failed Text
t[#t+1] = LoadFont("Common Normal")..{
	Name = "FailedText",
	InitCommand = function(self)
		self:settext("Stage Failed")
		self:Center():zoom(0.6):diffusealpha(0):x(-SCREEN_WIDTH)
	end,
	OffCommand = function(self)
		self:linear(0.3):x(SCREEN_CENTER_X):diffusealpha(0.8)
		self:diffuseshift()
		self:effectcolor1(color("#FFFFFF")):effectcolor2(HVColor.Negative or color("#FF0000"))
		
		-- Hold then fade out
		self:sleep(3):smooth(1):diffusealpha(0)
	end
}

return t
