--- Holographic Void: ScreenHVOptions Background/Overlay
local t = Def.ActorFrame {
	Name = "HVOptionsOverlay"
}

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local bgCard = color("0.06,0.06,0.06,0.95")

-- ============================================================
-- BACKGROUND: Dark overlay with grid
-- ============================================================
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,0.92"))
	end
}

-- Grid lines
for i = 1, 8 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, (SCREEN_HEIGHT / 9) * i)
				:zoomto(SCREEN_WIDTH, 1):diffuse(color("1,1,1,0.02"))
		end
	}
end

-- ============================================================
-- SIDE DECORATIONS (left and right)
-- ============================================================
-- Left decorative bar
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:halign(0):valign(0)
			:xy(SCREEN_LEFT + 12, SCREEN_TOP + 60)
			:zoomto(3, SCREEN_HEIGHT - 120)
			:diffuse(accentColor):diffusealpha(0.1)
	end
}
-- Left decorative dots
for i = 0, 6 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_LEFT + 24, SCREEN_TOP + 80 + i * 50)
				:zoomto(4, 4):diffuse(accentColor):diffusealpha(0.12 + i * 0.02)
		end
	}
end

-- Right decorative bar
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:halign(1):valign(0)
			:xy(SCREEN_RIGHT - 12, SCREEN_TOP + 60)
			:zoomto(3, SCREEN_HEIGHT - 120)
			:diffuse(accentColor):diffusealpha(0.1)
	end
}
-- Right decorative dots
for i = 0, 6 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_RIGHT - 24, SCREEN_TOP + 80 + i * 50)
				:zoomto(4, 4):diffuse(accentColor):diffusealpha(0.12 + i * 0.02)
		end
	}
end

-- Left bracket overlay
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(SCREEN_LEFT + 30, SCREEN_TOP + 70)
	end,
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(20, 1):diffuse(accentColor):diffusealpha(0.15)
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(1, 20):diffuse(accentColor):diffusealpha(0.15)
		end
	}
}

-- Right bracket overlay
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(SCREEN_RIGHT - 30, SCREEN_BOTTOM - 70)
	end,
	Def.Quad {
		InitCommand = function(self)
			self:halign(1):valign(1):zoomto(20, 1):diffuse(accentColor):diffusealpha(0.15)
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(1):valign(1):zoomto(1, 20):diffuse(accentColor):diffusealpha(0.15)
		end
	}
}

-- ============================================================
-- HEADER
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, 36)
	end,

	-- Title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.8):diffuse(brightText)
			self:settext(THEME:GetString("ScreenHVOptions", "Title"))
		end
	},

	-- Subtitle
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(22):zoom(0.3):diffuse(dimText)
			self:settext(THEME:GetString("ScreenHVOptions", "Subtitle"))
		end
	},

	-- Header accent line
	Def.Quad {
		InitCommand = function(self)
			self:y(38):zoomto(SCREEN_WIDTH * 0.5, 1)
				:diffuse(accentColor):diffusealpha(0.3)
		end
	}
}

-- ============================================================
-- OPTIONS PANEL (center card)
-- ============================================================
local panelW = SCREEN_WIDTH * 0.55
local panelH = SCREEN_HEIGHT * 0.6
local panelY = SCREEN_CENTER_Y + 15

t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, panelY)
	end,

	-- Panel background
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(panelW, panelH):diffuse(bgCard)
		end
	},

	-- Panel border
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(panelW, panelH)
				:diffuse(color("0.15,0.15,0.15,1"))
				:diffusealpha(0):blend("BlendMode_Add")
		end
	},

	-- Left accent
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):x(-panelW / 2):zoomto(2, panelH)
				:diffuse(accentColor):diffusealpha(0.25)
		end
	},

	-- Right accent
	Def.Quad {
		InitCommand = function(self)
			self:halign(1):x(panelW / 2):zoomto(2, panelH)
				:diffuse(accentColor):diffusealpha(0.15)
		end
	}
}

-- ============================================================
-- CURRENT SPEED DISPLAY (below the options panel)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "SpeedDisplay",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, panelY + panelH / 2 + 24)
	end,

	-- Speed label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(1):x(-8):zoom(0.3):diffuse(dimText)
			self:settext(THEME:GetString("ScreenHVOptions", "CurrentSpeed"))
		end
	},

	-- Speed value
	LoadFont("Common Normal") .. {
		Name = "SpeedValue",
		InitCommand = function(self)
			self:halign(0):x(8):zoom(0.45):diffuse(accentColor)
		end,
		SetCommand = function(self)
			-- Use the same helper as Til Death to read current speed mode
			local speed, mode = GetSpeedModeAndValueFromPoptions(PLAYER_1)
			if mode == "x" then
				-- Show effective BPM for xmod
				local song = GAMESTATE:GetCurrentSong()
				if song then
					local rate = GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate() or 1
					local bpms = song:GetDisplayBpms(true)
					local b1 = math.round(bpms[1])
					local b2 = math.round(bpms[2])
					if b1 == b2 then
						self:settext(tostring(math.round(b1 * rate * speed / 100)))
					else
						self:settext(string.format("%d - %d",
							math.round(b1 * rate * speed / 100),
							math.round(b2 * rate * speed / 100)))
					end
				else
					self:settext(string.format("%.2fx", speed / 100))
				end
			elseif mode == "C" then
				self:settext("C" .. speed)
			else
				self:settext("M" .. speed)
			end
		end,
		OnCommand = function(self) self:playcommand("Set") end
	}

}

-- ============================================================
-- FOOTER
-- ============================================================
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 16)
			:zoom(0.28):diffuse(dimText)
		self:settext(THEME:GetString("ScreenHVOptions", "Hint"))
	end
}

-- ============================================================
-- LISTEN FOR PREF CHANGES (refresh accent in real-time)
-- ============================================================
t[#t + 1] = Def.Actor {
	ThemePrefChangedMessageCommand = function(self, params)
		if params and params.Name == "HV_AccentColor" then
			if HVColor and HVColor.RefreshAccent then
				HVColor.RefreshAccent()
			end
			-- Save prefs immediately
			ThemePrefs.ForceSave()
		end
	end
}

return t
