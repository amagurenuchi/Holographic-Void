--- Holographic Void: ScreenInit Background
-- Minimalist & Elegant Logo Reveal with procedural geometric glyph, kinetic typography, and subtle particle drift.

if HVColor and HVColor.RefreshAccent then
	HVColor.RefreshAccent()
end

local accent = (HVColor and HVColor.Accent) or color("#00E5FF")

-- Theme Version Reader
local themeVersion = "Unknown"
local themeName = THEME:GetCurThemeName()
local paths = {
	"Themes/" .. themeName .. "/ThemeInfo.ini",
	"ThemeInfo.ini"
}

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

local t = Def.ActorFrame {
	InitCommand = function(self)
		if self.SortByDrawOrder then
			self:SortByDrawOrder()
		end
	end
}

-- 1. Deep Void Gradient & Vignette Background
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
	end,
	OnCommand = function(self)
		self:diffusetopedge(color("#05060f"))
		self:diffusebottomedge(color("#010103"))
		self:diffusealpha(0):linear(0.25):diffusealpha(1)
	end
}

-- Subtle Radial Ambient Glow at Center
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH * 0.75, SCREEN_HEIGHT * 0.45)
		self:blend("BlendMode_Add")
		self:fadetop(1):fadebottom(1):fadeleft(1):faderight(1)
	end,
	OnCommand = function(self)
		self:diffuse(accent):diffusealpha(0)
			:sleep(0.15)
			:linear(0.8):diffusealpha(0.09)
			:sleep(1.4)
			:linear(0.6):diffusealpha(0)
	end
}

-- 2. Ambient Floating Micro-particles (Void motes)
local numParticles = 16
local particleFrame = Def.ActorFrame {}

for i = 1, numParticles do
	local startX = SCREEN_CENTER_X + (math.random() * SCREEN_WIDTH * 0.6 - SCREEN_WIDTH * 0.3)
	local startY = SCREEN_CENTER_Y + (math.random() * 140 - 70)
	local driftY = math.random(30, 70)
	local size = math.random(1, 2)
	local pDelay = 0.1 + math.random() * 0.6
	local pDuration = 2.1 + math.random() * 0.5
	local pAlpha = 0.2 + math.random() * 0.35

	particleFrame[#particleFrame + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(startX, startY):zoomto(size, size):diffuse(accent):diffusealpha(0)
		end,
		OnCommand = function(self)
			self:sleep(pDelay)
				:decelerate(pDuration * 0.3):diffusealpha(pAlpha)
				:linear(pDuration * 0.7):y(startY - driftY):diffusealpha(0)
		end
	}
end
t[#t + 1] = particleFrame

-- Master Container for Hero Glyph & Typography (Handles coordinated entrance & exit)
local heroGroup = Def.ActorFrame {
	InitCommand = function(self)
		self:Center():zoom(1)
	end,
	OnCommand = function(self)
		-- Breathing / exit tween
		self:sleep(2.55)
			:accelerate(0.5):zoom(1.03):diffusealpha(0)
	end
}

-- 3. Procedural Geometric Glyph (Void Prism / Concentric Diamond Rings)
local glyphFrame = Def.ActorFrame {
	InitCommand = function(self)
		self:y(-42):zoom(0.4):diffusealpha(0)
	end,
	OnCommand = function(self)
		self:sleep(0.2)
			:decelerate(0.7):zoom(1):diffusealpha(1)
	end
}

-- Outer Rotating Diamond Wireframe (Thin borders formed with lines)
local outerDiamond = Def.ActorFrame {
	OnCommand = function(self)
		self:rotationz(45)
			:decelerate(2.4):rotationz(90)
	end
}
-- 4 sides of outer diamond
local diamondSize = 48
local borderThick = 1.2

-- Top, Right, Bottom, Left edges
outerDiamond[#outerDiamond + 1] = Def.Quad {
	InitCommand = function(self) self:xy(0, -diamondSize / 2):zoomto(diamondSize, borderThick):diffuse(accent):diffusealpha(0.65) end
}
outerDiamond[#outerDiamond + 1] = Def.Quad {
	InitCommand = function(self) self:xy(0, diamondSize / 2):zoomto(diamondSize, borderThick):diffuse(accent):diffusealpha(0.65) end
}
outerDiamond[#outerDiamond + 1] = Def.Quad {
	InitCommand = function(self) self:xy(-diamondSize / 2, 0):zoomto(borderThick, diamondSize):diffuse(accent):diffusealpha(0.65) end
}
outerDiamond[#outerDiamond + 1] = Def.Quad {
	InitCommand = function(self) self:xy(diamondSize / 2, 0):zoomto(borderThick, diamondSize):diffuse(accent):diffusealpha(0.65) end
}
glyphFrame[#glyphFrame + 1] = outerDiamond

-- Inner Concentric Rotating Ring (Rotates in counter direction)
local innerDiamond = Def.ActorFrame {
	OnCommand = function(self)
		self:rotationz(0)
			:decelerate(2.5):rotationz(-45)
	end
}
local innerSize = 26
local innerThick = 1.0
innerDiamond[#innerDiamond + 1] = Def.Quad {
	InitCommand = function(self) self:xy(0, -innerSize / 2):zoomto(innerSize, innerThick):diffuse(color("#FFFFFF")):diffusealpha(0.8) end
}
innerDiamond[#innerDiamond + 1] = Def.Quad {
	InitCommand = function(self) self:xy(0, innerSize / 2):zoomto(innerSize, innerThick):diffuse(color("#FFFFFF")):diffusealpha(0.8) end
}
innerDiamond[#innerDiamond + 1] = Def.Quad {
	InitCommand = function(self) self:xy(-innerSize / 2, 0):zoomto(innerThick, innerSize):diffuse(color("#FFFFFF")):diffusealpha(0.8) end
}
innerDiamond[#innerDiamond + 1] = Def.Quad {
	InitCommand = function(self) self:xy(innerSize / 2, 0):zoomto(innerThick, innerSize):diffuse(color("#FFFFFF")):diffusealpha(0.8) end
}
glyphFrame[#glyphFrame + 1] = innerDiamond

-- Center Prism Core Glow (Additive soft dot)
glyphFrame[#glyphFrame + 1] = Def.Quad {
	InitCommand = function(self)
		self:zoomto(6, 6):rotationz(45):diffuse(color("#FFFFFF"))
	end,
	OnCommand = function(self)
		self:diffusealpha(0)
			:sleep(0.4)
			:decelerate(0.4):diffusealpha(1):zoomto(8, 8)
			:linear(1.4):zoomto(5, 5)
	end
}

-- Center Soft Halo behind glyph
glyphFrame[#glyphFrame + 1] = Def.Quad {
	InitCommand = function(self)
		self:zoomto(72, 72):diffuse(accent):blend("BlendMode_Add"):diffusealpha(0)
		self:fadetop(0.8):fadebottom(0.8):fadeleft(0.8):faderight(0.8)
	end,
	OnCommand = function(self)
		self:sleep(0.3)
			:decelerate(0.6):diffusealpha(0.35)
			:linear(1.5):diffusealpha(0.2)
	end
}

heroGroup[#heroGroup + 1] = glyphFrame

-- 4. Kinetic Typography ("HOLOGRAPHIC VOID")
local textGroup = Def.ActorFrame {
	InitCommand = function(self)
		self:y(18):diffusealpha(0)
	end,
	OnCommand = function(self)
		self:sleep(0.4)
			:decelerate(0.55):diffusealpha(1):y(10)
	end
}

-- Accent-based Shadow Text (Exact underlay — same position as title, accent color, drawn behind)
textGroup[#textGroup + 1] = LoadFont("Common Large") .. {
	Text = "HOLOGRAPHIC VOID",
	InitCommand = function(self)
		self:zoom(0.62):diffuse(accent):diffusealpha(0)
	end,
	OnCommand = function(self)
		self:sleep(0.4)
			:decelerate(0.55):diffusealpha(0.7)
			:linear(1.4):diffusealpha(0.55)
	end
}

-- Ambient Accent Underglow for Text
textGroup[#textGroup + 1] = LoadFont("Common Large") .. {
	Text = "HOLOGRAPHIC VOID",
	InitCommand = function(self)
		self:zoom(0.62):diffuse(accent):diffusealpha(0):blend("BlendMode_Add")
	end,
	OnCommand = function(self)
		self:sleep(0.42)
			:decelerate(0.6):diffusealpha(0.45)
			:linear(1.4):diffusealpha(0.25)
	end
}

-- Crisp Primary Text
textGroup[#textGroup + 1] = LoadFont("Common Large") .. {
	Text = "HOLOGRAPHIC VOID",
	InitCommand = function(self)
		self:zoom(0.62):diffuse(color("#F4F8FA")):diffusealpha(0)
	end,
	OnCommand = function(self)
		self:sleep(0.4)
			:decelerate(0.55):diffusealpha(1)
	end
}

-- Horizontal Light Sweep across text
textGroup[#textGroup + 1] = Def.Quad {
	InitCommand = function(self)
		self:y(0):zoomto(35, 18):diffuse(color("#FFFFFF")):blend("BlendMode_Add"):diffusealpha(0)
		self:fadeleft(0.8):faderight(0.8)
	end,
	OnCommand = function(self)
		self:x(-200):sleep(0.65)
			:linear(0.05):diffusealpha(0.35)
			:decelerate(0.75):x(200)
			:linear(0.05):diffusealpha(0)
	end
}

heroGroup[#heroGroup + 1] = textGroup

-- 5. Version Subtitle & Fine Divider Lines
local subMetaGroup = Def.ActorFrame {
	InitCommand = function(self)
		self:y(38):diffusealpha(0)
	end,
	OnCommand = function(self)
		self:sleep(0.7)
			:decelerate(0.5):diffusealpha(0.85):y(34)
	end
}

-- Left fine line
subMetaGroup[#subMetaGroup + 1] = Def.Quad {
	InitCommand = function(self)
		self:x(-72):zoomto(0, 1):diffuse(accent):diffusealpha(0.5)
	end,
	OnCommand = function(self)
		self:sleep(0.75):decelerate(0.4):zoomto(50, 1)
	end
}

-- Right fine line
subMetaGroup[#subMetaGroup + 1] = Def.Quad {
	InitCommand = function(self)
		self:x(72):zoomto(0, 1):diffuse(accent):diffusealpha(0.5)
	end,
	OnCommand = function(self)
		self:sleep(0.75):decelerate(0.4):zoomto(50, 1)
	end
}

-- Version text badge
subMetaGroup[#subMetaGroup + 1] = LoadFont("Common Normal") .. {
	Text = "v" .. themeVersion,
	InitCommand = function(self)
		self:zoom(0.4):diffuse(color("#A0AAB5"))
	end
}

heroGroup[#heroGroup + 1] = subMetaGroup

t[#t + 1] = heroGroup

-- 6. Celebration / Confetti (Cleanly archived & disabled)
local anniversaryFeaturesEnabled = false
if anniversaryFeaturesEnabled then
	-- Placeholder for celebratory components if re-enabled in future milestones
end

return t
