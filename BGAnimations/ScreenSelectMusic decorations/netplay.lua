--- Holographic Void: Netplay Control Dock (ScreenNetSelectMusic)
-- Modern glassmorphic control dock featuring:
--   - Room Name badge
--   - Reactive Ready / Unready toggle button with instant feedback
--   - Force Start button
--   - Player roster toggle pill

local function getAccent()
	return (HVColor and HVColor.Accent) or color("#5ABAFF")
end

local Colors = {
	bg = color("0.05,0.06,0.09,0.92"),
	border = color("0.18,0.22,0.28,0.75"),
	btnBg = color("0.08,0.10,0.14,0.85"),
	btnReady = color("0.15,0.75,0.45,0.95"),
	btnReadyBg = color("0.08,0.30,0.18,0.85"),
	dimText = color("0.45,0.48,0.55,1"),
	subText = color("0.65,0.70,0.78,1"),
	brightText = color("1,1,1,1"),
	accent = color("#5ABAFF"),
}

local panelX = 8
local panelW = SCREEN_WIDTH * 0.36
local dockX = panelX + panelW + 12
local dockY = 44
local dockW = 280
local dockH = 34

local function currentScreenIsNet()
	local top = SCREENMAN:GetTopScreen()
	return top ~= nil and top:GetName() == "ScreenNetSelectMusic"
end

local function getReadyState()
	local top = SCREENMAN:GetTopScreen()
	if not top or top:GetName() ~= "ScreenNetSelectMusic" then
		return false
	end
	local qty = top:GetUserQty() or 0
	local loggedInUser = NSMAN:GetLoggedInUsername() or ""
	for i = 1, qty do
		if top:GetUser(i) == loggedInUser then
			return top:GetUserReady(i) == true
		end
	end
	return false
end

local function cornerTicks(w, h, sz, th)
	local function colorTick(self) self:diffuse(getAccent()):diffusealpha(0.85) end
	return Def.ActorFrame {
		Def.Quad { InitCommand = function(self) self:xy(0, 0):zoomto(sz, th):halign(0):valign(0); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(0, 0):zoomto(th, sz):halign(0):valign(0); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(w, 0):zoomto(sz, th):halign(1):valign(0); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(w, 0):zoomto(th, sz):halign(1):valign(0); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(0, h):zoomto(sz, th):halign(0):valign(1); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(0, h):zoomto(th, sz):halign(0):valign(1); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(w, h):zoomto(sz, th):halign(1):valign(1); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(w, h):zoomto(th, sz):halign(1):valign(1); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
	}
end

return Def.ActorFrame {
	Name = "NetPlayControlDock",
	InitCommand = function(self)
		self:xy(dockX, dockY)
		self:visible(currentScreenIsNet())
	end,
	OnCommand = function(self)
		self:playcommand("Refresh")
	end,
	RefreshCommand = function(self)
		local isNet = currentScreenIsNet()
		self:visible(isNet)
		if not isNet then return end

		local roomLabel = self:GetChild("RoomName")
		if roomLabel then
			local roomName = NSMAN:GetCurrentRoomName()
			roomLabel:settext(roomName and roomName ~= "" and roomName:upper() or "NETPLAY")
		end

		self:GetChild("ReadyButton"):playcommand("Refresh")
		self:GetChild("ForceButton"):playcommand("Refresh")
		self:GetChild("RosterToggle"):playcommand("Refresh")
	end,
	UsersUpdateMessageCommand = function(self) self:playcommand("Refresh") end,
	ChatMessageCommand = function(self) self:playcommand("Refresh") end,
	PlayerJoinedMessageCommand = function(self) self:playcommand("Refresh") end,
	PlayerUnjoinedMessageCommand = function(self) self:playcommand("Refresh") end,

	-- Card Background
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(dockW, dockH):diffuse(Colors.bg)
		end
	},
	-- Left accent stripe
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(3, dockH):diffuse(getAccent())
		end,
		ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
	},
	-- 1px Border
	Def.ActorFrame {
		Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(dockW, 1):diffuse(Colors.border) end },
		Def.Quad { InitCommand = function(self) self:halign(0):valign(1):xy(0, dockH):zoomto(dockW, 1):diffuse(Colors.border) end },
		Def.Quad { InitCommand = function(self) self:halign(1):valign(0):xy(dockW, 0):zoomto(1, dockH):diffuse(Colors.border) end },
	},
	cornerTicks(dockW, dockH, 5, 1.5),

	-- Room Name Label
	LoadFont("Common Normal") .. {
		Name = "RoomName",
		InitCommand = function(self)
			self:xy(10, dockH / 2):halign(0):valign(0.5):zoom(0.32)
				:diffuse(Colors.brightText):maxwidth(90 / 0.32)
		end
	},

	-- READY / UNREADY Button (Pill Button)
	Def.ActorFrame {
		Name = "ReadyButton",
		InitCommand = function(self)
			self:xy(102, dockH / 2)
		end,
		RefreshCommand = function(self)
			local readied = getReadyState()
			local bg = self:GetChild("Bg")
			local label = self:GetChild("Label")
			if readied then
				bg:diffuse(Colors.btnReadyBg)
				label:diffuse(Colors.btnReady):settext("READY")
			else
				bg:diffuse(Colors.btnBg)
				label:diffuse(Colors.dimText):settext(THEME:GetString("ScreenSelectMusic", "Ready"))
			end
		end,
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0.5):zoomto(68, 22):diffuse(Colors.btnBg)
			end
		},
		Def.ActorFrame {
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0.5):xy(0, -11):zoomto(68, 1):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0.5):xy(0, 11):zoomto(68, 1):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0.5):xy(0, 0):zoomto(1, 22):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0.5):xy(68, 0):zoomto(1, 22):diffuse(Colors.border) end },
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(34, 0):halign(0.5):valign(0.5):zoom(0.28):diffuse(Colors.dimText)
			end
		},
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:halign(0):valign(0.5):zoomto(68, 22):diffusealpha(0)
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and currentScreenIsNet() then
					NSMAN:SendChatMsg("/ready", 1, NSMAN:GetCurrentRoomName())
					self:GetParent():playcommand("Refresh")
				end
			end
		}
	},

	-- FORCE START Button
	Def.ActorFrame {
		Name = "ForceButton",
		InitCommand = function(self)
			self:xy(174, dockH / 2)
		end,
		RefreshCommand = function(self)
			self:GetChild("Label"):settext("FORCE"):diffuse(Colors.subText)
		end,
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0.5):zoomto(48, 22):diffuse(Colors.btnBg)
			end
		},
		Def.ActorFrame {
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0.5):xy(0, -11):zoomto(48, 1):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0.5):xy(0, 11):zoomto(48, 1):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0.5):xy(0, 0):zoomto(1, 22):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0.5):xy(48, 0):zoomto(1, 22):diffuse(Colors.border) end },
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(24, 0):halign(0.5):valign(0.5):zoom(0.26):diffuse(Colors.subText):settext("FORCE")
			end
		},
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:halign(0):valign(0.5):zoomto(48, 22):diffusealpha(0)
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and currentScreenIsNet() then
					NSMAN:SendChatMsg("/force", 1, NSMAN:GetCurrentRoomName())
					self:GetParent():playcommand("Refresh")
				end
			end
		}
	},

	-- ROSTER TOGGLE Button
	Def.ActorFrame {
		Name = "RosterToggle",
		InitCommand = function(self)
			self:xy(226, dockH / 2)
		end,
		RefreshCommand = function(self)
			local top = SCREENMAN:GetTopScreen()
			local qty = (top and top.GetUserQty and top:GetUserQty()) or 0
			self:GetChild("Label"):settextf("%d", qty)
		end,
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0.5):zoomto(46, 22):diffuse(color("0.10,0.13,0.19,0.9"))
			end
		},
		Def.ActorFrame {
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0.5):xy(0, -11):zoomto(46, 1):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0.5):xy(0, 11):zoomto(46, 1):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0.5):xy(0, 0):zoomto(1, 22):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0.5):xy(46, 0):zoomto(1, 22):diffuse(Colors.border) end },
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(23, 0):halign(0.5):valign(0.5):zoom(0.28):diffuse(getAccent())
			end,
			ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
		},
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:halign(0):valign(0.5):zoomto(46, 22):diffusealpha(0)
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" then
					MESSAGEMAN:Broadcast("ToggleNetRoster")
				end
			end
		}
	}
}
