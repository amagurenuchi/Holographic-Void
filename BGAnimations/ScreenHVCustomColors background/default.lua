--- Holographic Void: ScreenHVCustomColors Background
local t = Def.ActorFrame {}

local function getAccent()
	return (HVColor and HVColor.Accent) or color("#5ABAFF")
end

-- Opaque backdrop hides the screen underneath, which remains stacked below
-- this screen when it is opened with AddNewScreenToTop.
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0.015,0.02,0.03,1"))
	end
}

-- Subtle horizontal grid
for i = 1, 8 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, (SCREEN_HEIGHT / 9) * i)
				:zoomto(SCREEN_WIDTH, 1):diffuse(getAccent()):diffusealpha(0.06)
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if params and params.Name == "HV_AccentColor" then
				self:stoptweening():linear(0.12):diffuse(getAccent()):diffusealpha(0.06)
			end
		end
	}
end

t[#t + 1] = LoadActor("../_particles.lua")

return t
