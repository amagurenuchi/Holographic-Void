--- Holographic Void: ScreenInit Background
-- Modernized, sleek initialization screen with a holographic vibe.

if HVColor and HVColor.RefreshAccent then
	HVColor.RefreshAccent()
end

local t = Def.ActorFrame {
	InitCommand = function(self)
		if self.SortByDrawOrder then
			self:SortByDrawOrder()
		end
	end
}

-- 1. Void Gradient Background
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
	end,
	OnCommand = function(self)
		self:diffusetopedge(color("#050510"))
		self:diffusebottomedge(color("#000000"))
		self:diffusealpha(0):linear(0.3):diffusealpha(1)
	end
}

-- 2. Ambient Grid / Lines (Holographic effect)
local gridFrame = Def.ActorFrame {
	InitCommand = function(self) self:Center() end,
}
for i = -4, 4 do
	-- Horizontal lines fade out from center
	gridFrame[#gridFrame + 1] = Def.Quad {
		InitCommand = function(self)
			self:y(i * 35):zoomto(SCREEN_WIDTH, 1)
		end,
		OnCommand = function(self)
			self:diffuse(HVColor.Accent):diffusealpha(0)
				:sleep(0.1 + math.abs(i) * 0.05)
				:linear(0.4):diffusealpha(0.08)
				:sleep(2.4 - math.abs(i) * 0.05)
				:linear(0.5):diffusealpha(0)
		end
	}
end
t[#t + 1] = gridFrame

-- 3. Center Glow / Light burst
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, 100)
		self:blend("BlendMode_Add")
		self:fadetop(1):fadebottom(1)
	end,
	OnCommand = function(self)
		self:diffuse(HVColor.Accent):diffusealpha(0)
			:linear(0.5):diffusealpha(0.20):zoomto(SCREEN_WIDTH, 40)
			:sleep(2.3)
			:linear(0.5):diffusealpha(0)
	end
}

-- 4. Text - Chromatic Aberration
local textGroup = Def.ActorFrame {
	InitCommand = function(self) self:Center():y(SCREEN_CENTER_Y - 15) end,
	-- Cyan layer (moves right to center)
	LoadFont("Common Large") .. {
		Text = "HOLOGRAPHIC VOID",
		InitCommand = function(self) self:zoom(0.6):x(-15):diffuse(color("#00FFFF")):blend("BlendMode_Add") end,
		OnCommand = function(self)
			self:diffusealpha(0)
				:decelerate(0.5):diffusealpha(0.8):x(-2)
				:sleep(2.3)
				:accelerate(0.5):diffusealpha(0):x(-10)
		end
	},
	-- Magenta layer (moves left to center)
	LoadFont("Common Large") .. {
		Text = "HOLOGRAPHIC VOID",
		InitCommand = function(self) self:zoom(0.6):x(15):diffuse(color("#FF00FF")):blend("BlendMode_Add") end,
		OnCommand = function(self)
			self:diffusealpha(0)
				:decelerate(0.5):diffusealpha(0.8):x(2)
				:sleep(2.3)
				:accelerate(0.5):diffusealpha(0):x(10)
		end
	},
	-- Main White layer
	LoadFont("Common Large") .. {
		Text = "HOLOGRAPHIC VOID",
		InitCommand = function(self) self:zoom(0.6):x(0) end,
		OnCommand = function(self)
			self:diffusealpha(0)
				:decelerate(0.5):diffusealpha(1)
				:sleep(2.3)
				:accelerate(0.5):diffusealpha(0)
		end
	}
}
t[#t + 1] = textGroup

-- 5. Version Subtitle
local themeVersion = "Unknown"
local themeName = THEME:GetCurThemeName()
local paths = {
	"Themes/" .. themeName .. "/ThemeInfo.ini",
	"ThemeInfo.ini"
}

-- Add GetCurrentThemeDirectory only if it exists
if THEME.GetCurrentThemeDirectory then
	table.insert(paths, 1, THEME:GetCurrentThemeDirectory() .. "ThemeInfo.ini")
end

for _, path in ipairs(paths) do
	local info = IniFile.ReadFile(path)
	if info and info["ThemeInfo"] and info["ThemeInfo"]["Version"] then
		themeVersion = info["ThemeInfo"]["Version"]
		break
	end
end

t[#t + 1] = LoadFont("Common Normal") .. {
	Text = "v" .. themeVersion,
	InitCommand = function(self) self:Center():y(SCREEN_CENTER_Y + 15):zoom(0.5) end,
	OnCommand = function(self)
		self:diffuse(color("0.6,0.6,0.6,1")):diffusealpha(0)
			:sleep(0.3):decelerate(0.4):diffusealpha(0.9):y(SCREEN_CENTER_Y + 7)
			:sleep(2.1):accelerate(0.5):diffusealpha(0):y(SCREEN_CENTER_Y + 15)
	end
}

-- 6. Modern Loading Bar / Scanning Line
t[#t + 1] = Def.Quad {
	InitCommand = function(self) 
		self:Center():y(SCREEN_CENTER_Y + 30):zoomto(0, 2)
	end,
	OnCommand = function(self)
		self:diffuse(HVColor.Accent):diffusealpha(0)
			:sleep(0.4):diffusealpha(0.9)
			:decelerate(0.8):zoomto(200, 2)
			:sleep(1.6)
			:accelerate(0.5):zoomto(0, 1):diffusealpha(0)
	end
}

-- 7. 10th Anniversary Celebratory Subtitle
local anniversaryGroup = Def.ActorFrame {
	InitCommand = function(self) self:Center():y(SCREEN_CENTER_Y + 54):draworder(1500) end,
	-- Subtle glow layer
	LoadFont("Common Normal") .. {
		Text = "Happy 10th Anniversary, Etterna!",
		InitCommand = function(self)
			self:zoom(0.48):diffuse(HVColor.Accent):diffusealpha(0)
		end,
		OnCommand = function(self)
			self:sleep(1.0)
				:zoom(0.7)
				:decelerate(0.35):zoom(0.48):diffusealpha(0.6):glow(HVColor.Accent)
				:sleep(1.8)
				:accelerate(0.45):diffusealpha(0)
		end
	},
	-- Main celebratory text
	LoadFont("Common Normal") .. {
		Text = "Happy 10th Anniversary, Etterna!",
		InitCommand = function(self)
			self:zoom(0.48):diffuse(HVColor.Accent):diffusealpha(0)
		end,
		OnCommand = function(self)
			self:sleep(1.0)
				:zoom(0.7)
				:decelerate(0.35):zoom(0.48):diffusealpha(1)
				:sleep(1.8)
				:accelerate(0.45):diffusealpha(0)
		end
	}
}
t[#t + 1] = anniversaryGroup

-- 8. Confetti Cannon System (Launches from both sides when text finishes tweening at 1.35s)
local numConfetti = 140
local confettiStartTime = 1.35 -- Exact time when the Happy 10th Anniversary text completes its entrance tween

-- Confetti palette strictly synced to the selected accent color family
local baseAccent = HVColor.Accent or color("#5ABAFF")
local hsv = ColorToHSV(baseAccent)
local h = (type(hsv) == "table" and hsv.Hue) or 200
local s = (type(hsv) == "table" and hsv.Sat) or 0.7
local v = (type(hsv) == "table" and hsv.Value) or 0.9

local confettiPalette = {
	baseAccent,                                                -- Selected theme accent
	baseAccent,                                                -- Weighted for accent
	HSV(h, math.max(0.1, s * 0.35), 1.0),                      -- Light pastel accent tint
	HSV(h, math.min(1.0, s * 1.15), math.max(0.4, v * 0.75)),  -- Deeper accent shade
	HSV((h + 15) % 360, s, v),                                 -- Subtle harmonic hue
	color("#FFFFFF"),                                          -- Crisp white sparkle
}

local confettiFrame = Def.ActorFrame {
	Name = "ConfettiFrame",
	InitCommand = function(self)
		self:draworder(2000)
	end
}

for i = 1, numConfetti do
	local isLeft = (i % 2 == 1)
	local cColor = confettiPalette[((i - 1) % #confettiPalette) + 1]
	local delay = confettiStartTime + math.random() * 0.25
	local upTime = 0.65 + math.random() * 0.35
	local fallTime = 0.95 + math.random() * 0.45
	local w = math.random(3, 5)   -- Sleek ribbon width
	local h = math.random(12, 22) -- Ribbon length
	local startY = SCREEN_CENTER_Y + math.random(10, 100)
	local peakY = SCREEN_TOP + math.random(20, 130)
	local fallY = SCREEN_BOTTOM + 30

	if isLeft then
		local startX = SCREEN_LEFT - 5
		local peakX = SCREEN_LEFT + math.random(160, math.floor(SCREEN_WIDTH * 0.58))
		local driftX = math.random(40, 160)
		local rot1 = math.random(0, 360)
		local rot2 = rot1 + math.random(240, 600)
		local rot3 = rot2 + math.random(240, 600)

		confettiFrame[#confettiFrame + 1] = Def.Quad {
			Name = "Confetti_" .. i,
			InitCommand = function(self)
				self:visible(false):draworder(2000)
			end,
			OnCommand = function(self)
				self:sleep(delay)
					:visible(true)
					:xy(startX, startY)
					:zoomto(w, h)
					:diffuse(cColor)
					:diffusealpha(1)
					:rotationz(rot1)
					:decelerate(upTime):xy(peakX, peakY):rotationz(rot2)
					:accelerate(fallTime):x(peakX + driftX):y(fallY):rotationz(rot3):diffusealpha(0)
			end
		}
	else
		local startX = SCREEN_RIGHT + 5
		local peakX = SCREEN_RIGHT - math.random(160, math.floor(SCREEN_WIDTH * 0.58))
		local driftX = -math.random(40, 160)
		local rot1 = math.random(0, 360)
		local rot2 = rot1 - math.random(240, 600)
		local rot3 = rot2 - math.random(240, 600)

		confettiFrame[#confettiFrame + 1] = Def.Quad {
			Name = "Confetti_" .. i,
			InitCommand = function(self)
				self:visible(false):draworder(2000)
			end,
			OnCommand = function(self)
				self:sleep(delay)
					:visible(true)
					:xy(startX, startY)
					:zoomto(w, h)
					:diffuse(cColor)
					:diffusealpha(1)
					:rotationz(rot1)
					:decelerate(upTime):xy(peakX, peakY):rotationz(rot2)
					:accelerate(fallTime):x(peakX + driftX):y(fallY):rotationz(rot3):diffusealpha(0)
			end
		}
	end
end

t[#t + 1] = confettiFrame

return t
