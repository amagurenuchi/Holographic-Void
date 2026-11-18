--- Holographic Void: ScreenChatOverlay Overlay
-- Sleek monochromatic cyberpunk chat overlay with glassmorphism, responsive tabs,
-- unread notification badges, scroll indicators, and seamless keyboard/mouse interaction.

local width = capWideScale(360, 440)
local height = 270
local maxlines = 16
local lineNumber = maxlines
local inputH = 26
local tabH = 26
local headerH = 28
local x = 12
local y = SCREEN_HEIGHT - height - 10
local miniW = 260
local miniH = 26
local miniX = 12
local miniY = SCREEN_HEIGHT - miniH - 8

local scale = 0.36
local minimised = true
local typing = false
local typingText = ""
local enterKeyDown = false
local tweentime = 0.2
local lastScreenObj = nil

local function getAccent()
	return (HVColor and HVColor.Accent) or color("#5ABAFF")
end

local Colors = {
	bg = color("0.04,0.05,0.07,0.92"),
	headerBg = color("0.07,0.08,0.11,0.96"),
	outputBg = color("0.02,0.03,0.04,0.75"),
	inputBg = color("0.06,0.07,0.10,0.95"),
	inputActive = color("0.10,0.12,0.18,0.98"),
	border = color("0.18,0.22,0.28,0.75"),
	tabActive = color("0.12,0.15,0.22,0.95"),
	tabInactive = color("0.05,0.06,0.08,0.7"),
	dimText = color("0.45,0.48,0.55,1"),
	subText = color("0.65,0.70,0.78,1"),
	brightText = color("1,1,1,1"),
	systemText = color("0.95,0.80,0.30,1"),
	sentHighlight = color("0.40,0.85,0.95,1"),
	unreadBadge = color("0.95,0.35,0.45,1"),
}

local translated_info = {
	WindowTitle = THEME:GetString("MultiPlayer", "ChatTitle"),
	LobbyTab = THEME:GetString("MultiPlayer", "LobbyTabName"),
	RoomTab = THEME:GetString("MultiPlayer", "RoomTabName"),
	ServerTab = THEME:GetString("MultiPlayer", "ServerTabName"),
	ToggleTip = THEME:GetString("MultiPlayer", "InsertTip"),
	TypeMessage = THEME:GetString("MultiPlayer", "TypeMessage"),
	ClickToChat = THEME:GetString("MultiPlayer", "ClickToChat"),
}

-- Tab storage & chat structures
-- tabtype: 0=lobby, 1=room, 2=pm
local chats = {}
chats[0] = {[""] = {}}
chats[1] = {}
chats[2] = {}
local tabs = {{0, ""}}
local messages = chats[0][""]
local currentTabName = ""
local currentTabType = 0
local unreadPerTab = {}
local totalUnread = 0

local isGameplay = false
local isInSinglePlayer = false
local currentScreen = ""
local show = true
local online = false

local function getTabKey(tabType, tabName)
	return tostring(tabType) .. ":" .. tostring(tabName or "")
end

local function recalcTotalUnread()
	totalUnread = 0
	for _, count in pairs(unreadPerTab) do
		totalUnread = totalUnread + (count or 0)
	end
end

local function changeTab(tabName, tabType)
	currentTabName = tabName or ""
	currentTabType = tabType or 0
	if not chats[currentTabType] then chats[currentTabType] = {} end
	if not chats[currentTabType][currentTabName] then
		chats[currentTabType][currentTabName] = {}
		tabs[#tabs + 1] = {currentTabType, currentTabName}
	end
	messages = chats[currentTabType][currentTabName]
	unreadPerTab[getTabKey(currentTabType, currentTabName)] = 0
	recalcTotalUnread()
	lineNumber = math.max(maxlines, #messages)
	MESSAGEMAN:Broadcast("UpdateChatOverlay")
end

local function toggleChat(openInput)
	minimised = not minimised
	if minimised then
		typing = false
		typingText = ""
	else
		unreadPerTab[getTabKey(currentTabType, currentTabName)] = 0
		recalcTotalUnread()
		lineNumber = math.max(maxlines, #messages)
		if openInput then
			typing = true
		end
	end
	MESSAGEMAN:Broadcast("Minimise")
	MESSAGEMAN:Broadcast("UpdateChatOverlay")
end

local chat = Def.ActorFrame {
	Name = "ChatOverlayRoot",
	BeginCommand = function(self)
		local updf = function(this)
			local s = SCREENMAN:GetTopScreen()
			if not s then return end

			-- Re-register input callback if screen instance changed
			if s ~= lastScreenObj and MPinput then
				lastScreenObj = s
				pcall(function() s:AddInputCallback(MPinput) end)
			end

			local oldScreen = currentScreen
			currentScreen = s:GetName()
			if currentScreen == oldScreen then return end

			if currentScreen == "ScreenSelectMusic" or currentScreen == "ScreenTitleMenu" or
				currentScreen == "ScreenOptionsService" or currentScreen == "ScreenInit" or
				currentScreen == "ScreenPackDownloader" or currentScreen == "ScreenSelectProfile" then
				isInSinglePlayer = true
			end
			if string.sub(currentScreen, 1, 9) == "ScreenNet" and currentScreen ~= "ScreenNetSelectProfile" then
				isInSinglePlayer = false
			end

			online = IsNetSMOnline() and IsSMOnlineLoggedIn() and NSMAN:IsETTP()
			isGameplay = (currentScreen:find("Gameplay") ~= nil or currentScreen:find("StageInformation") ~= nil
							or currentScreen:find("PlayerOptions") ~= nil)

			if currentScreen == "ScreenTextEntry" or isGameplay or isInSinglePlayer or not online then
				this:visible(false)
				show = false
				typing = false
			else
				this:visible(true)
				show = true
			end

			-- Auto-sync room tab when entering NetSelectMusic
			if currentScreen == "ScreenNetSelectMusic" then
				local curRoom = NSMAN:GetCurrentRoomName()
				if curRoom and curRoom ~= "" then
					local found = false
					for i = 1, #tabs do
						if tabs[i] and tabs[i][1] == 1 and tabs[i][2] == curRoom then
							found = true
							changeTab(curRoom, 1)
							break
						end
					end
					if not found then
						changeTab(curRoom, 1)
					end
				end
			end
			MESSAGEMAN:Broadcast("UpdateChatOverlay")
		end
		self:SetUpdateFunction(updf)
		updf(self)
		self:SetUpdateFunctionInterval(0.1)
	end,
	InitCommand = function(self)
		online = IsNetSMOnline() and IsSMOnlineLoggedIn() and NSMAN:IsETTP()
		self:visible(false)
		MESSAGEMAN:Broadcast("Minimise")
	end,
	MultiplayerDisconnectionMessageCommand = function(self)
		online = false
		self:visible(false)
		typing = false
		HV.ChatTyping = false
		chats = {[0] = {[""] = {}}, [1] = {}, [2] = {}}
		tabs = {{0, ""}}
		unreadPerTab = {}
		totalUnread = 0
		changeTab("", 0)
		SCREENMAN:set_input_redirected(PLAYER_1, false)
		MESSAGEMAN:Broadcast("UpdateChatOverlay")
	end,
	HVTextEntryOpenedMessageCommand = function(self)
		typing = false
		typingText = ""
		enterKeyDown = false
		show = false
		self:visible(false)
		if HV then HV.ChatTyping = false end
		SCREENMAN:set_input_redirected(PLAYER_1, false)
		MESSAGEMAN:Broadcast("UpdateChatOverlay")
	end,
	ChatMessageCommand = function(self, params)
		local pType = params.type or 0
		local pTab = params.tab or ""
		if not chats[pType] then chats[pType] = {} end
		local newTab = false
		if not chats[pType][pTab] then
			chats[pType][pTab] = {}
			tabs[#tabs + 1] = {pType, pTab}
			newTab = true
		end
		local msgs = chats[pType][pTab]
		local timeStr = os.date("%H:%M")
		msgs[#msgs + 1] = {
			time = timeStr,
			text = params.msg or "",
			raw = string.format("[%s] %s", timeStr, params.msg or ""),
			isSystem = (params.msg:find("^%s*System:") ~= nil or params.msg:find("^%s*%*%*%*") ~= nil),
		}

		local tabKey = getTabKey(pType, pTab)
		if minimised or pType ~= currentTabType or pTab ~= currentTabName then
			unreadPerTab[tabKey] = (unreadPerTab[tabKey] or 0) + 1
			recalcTotalUnread()
		else
			lineNumber = math.max(maxlines, #msgs)
		end
		MESSAGEMAN:Broadcast("UpdateChatOverlay")
	end,
}

-- =========================================================================
-- MINIMIZED DOCK (Floating Sleek Pill)
-- =========================================================================
local minibar = Def.ActorFrame {
	Name = "MinimizedBar",
	InitCommand = function(self)
		self:xy(miniX, miniY)
	end,
	MinimiseMessageCommand = function(self)
		self:stoptweening():decelerate(tweentime)
		if minimised then
			self:diffusealpha(1):visible(true)
		else
			self:diffusealpha(0):visible(false)
		end
	end,
	-- Glass background
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(miniW, miniH)
				:diffuse(Colors.headerBg):diffusealpha(0.92)
		end
	},
	-- Left accent border
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(3, miniH):diffuse(getAccent())
		end,
		ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
	},
	-- Subtle outline
	Def.ActorFrame {
		Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(miniW, 1):diffuse(Colors.border) end },
		Def.Quad { InitCommand = function(self) self:halign(0):valign(1):xy(0, miniH):zoomto(miniW, 1):diffuse(Colors.border) end },
		Def.Quad { InitCommand = function(self) self:halign(1):valign(0):xy(miniW, 0):zoomto(1, miniH):diffuse(Colors.border) end },
	},
	-- Chat Badge
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(10, miniH / 2):halign(0):valign(0.5):zoom(0.32)
				:diffuse(getAccent()):settext(translated_info.WindowTitle)
		end,
		ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
	},
	-- Current Channel Label
	LoadFont("Common Normal") .. {
		Name = "ChannelLabel",
		InitCommand = function(self)
			self:xy(58, miniH / 2):halign(0):valign(0.5):zoom(0.30):diffuse(Colors.subText)
		end,
		UpdateChatOverlayMessageCommand = function(self)
			local label = "# LOBBY"
			if currentTabType == 1 then
				label = "# " .. (currentTabName ~= "" and currentTabName or "ROOM")
			elseif currentTabType == 2 then
				label = "@ " .. currentTabName
			end
			self:settext(label):maxwidth(110 / 0.30)
		end
	},
	-- Unread Badge Pill
	Def.ActorFrame {
		Name = "UnreadBadge",
		InitCommand = function(self)
			self:xy(miniW - 54, miniH / 2)
		end,
		UpdateChatOverlayMessageCommand = function(self)
			self:visible(totalUnread > 0)
			local countLabel = self:GetChild("Count")
			if countLabel then
				countLabel:settext(tostring(totalUnread))
			end
		end,
		Def.Quad {
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):zoomto(24, 14)
					:diffuse(Colors.unreadBadge):diffusealpha(0.85)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Count",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):zoom(0.24):diffuse(Colors.brightText)
			end
		}
	},
	-- Hotkey Hint
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(miniW - 10, miniH / 2):halign(1):valign(0.5):zoom(0.26)
				:diffuse(Colors.dimText):settext("[T]")
		end
	},
}
chat[#chat + 1] = minibar

-- =========================================================================
-- EXPANDED CHAT WINDOW (Glassmorphic Window)
-- =========================================================================
local expanded = Def.ActorFrame {
	Name = "ExpandedWindow",
	InitCommand = function(self)
		self:xy(x, y)
	end,
	MinimiseMessageCommand = function(self)
		self:stoptweening():decelerate(tweentime)
		if minimised then
			self:diffusealpha(0):visible(false)
		else
			self:diffusealpha(1):visible(true)
		end
	end,
}

-- Card Main Background
expanded[#expanded + 1] = Def.Quad {
	InitCommand = function(self)
		self:halign(0):valign(0):zoomto(width, height)
			:diffuse(Colors.bg):diffusealpha(0.94)
	end
}

-- Card Top Accent Gradient Line
expanded[#expanded + 1] = Def.Quad {
	InitCommand = function(self)
		self:halign(0):valign(0):zoomto(width, 2):diffuse(getAccent())
	end,
	ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
}

-- Outer 1px Border
expanded[#expanded + 1] = Def.ActorFrame {
	Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(width, 1):diffuse(Colors.border) end },
	Def.Quad { InitCommand = function(self) self:halign(0):valign(1):xy(0, height):zoomto(width, 1):diffuse(Colors.border) end },
	Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(1, height):diffuse(Colors.border) end },
	Def.Quad { InitCommand = function(self) self:halign(1):valign(0):xy(width, 0):zoomto(1, height):diffuse(Colors.border) end },
}

-- Corner Brackets (Holographic signature)
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
expanded[#expanded + 1] = cornerTicks(width, height, 6, 1.5)

-- =========================================================================
-- HEADER & TAB BAR
-- =========================================================================
local maxTabs = 6
local tabW = math.floor((width - 40) / maxTabs)

local function closeChatTab(index)
	local data = tabs[index]
	if not data then return false end
	local tType, tName = data[1], data[2]
	if tType == 0 or (tType == 1 and tName == NSMAN:GetCurrentRoomName()) then
		return false
	end
	table.remove(tabs, index)
	chats[tType][tName] = nil
	unreadPerTab[getTabKey(tType, tName)] = nil
	recalcTotalUnread()
	if tType == currentTabType and tName == currentTabName then
		local fallback = tabs[1] or {0, ""}
		changeTab(fallback[2], fallback[1])
	else
		MESSAGEMAN:Broadcast("UpdateChatOverlay")
	end
	return true
end

local tabContainer = Def.ActorFrame {
	Name = "TabContainer",
	InitCommand = function(self) self:xy(0, 2) end
}

-- Tab Bar Background
tabContainer[#tabContainer + 1] = Def.Quad {
	InitCommand = function(self)
		self:halign(0):valign(0):zoomto(width, tabH):diffuse(Colors.headerBg)
	end
}
tabContainer[#tabContainer + 1] = Def.Quad {
	InitCommand = function(self)
		self:halign(0):valign(1):xy(0, tabH):zoomto(width, 1):diffuse(Colors.border)
	end
}

local function makeTab(i)
	return Def.ActorFrame {
		Name = "Tab" .. i,
		InitCommand = function(self)
			self:xy((i - 1) * tabW, 0)
		end,
		UpdateChatOverlayMessageCommand = function(self)
			local data = tabs[i]
			self:visible(data ~= nil)
			if not data then return end
			local tType = data[1]
			local tName = data[2]
			local isCurrent = (tType == currentTabType and tName == currentTabName)
			local unread = unreadPerTab[getTabKey(tType, tName)] or 0

			local bg = self:GetChild("Bg")
			local label = self:GetChild("Label")
			local unreadDot = self:GetChild("UnreadDot")
			local closeBtn = self:GetChild("CloseBtn")

			if isCurrent then
				bg:diffuse(Colors.tabActive)
				label:diffuse(Colors.brightText)
			else
				bg:diffuse(Colors.tabInactive)
				label:diffuse(unread > 0 and getAccent() or Colors.subText)
			end

			-- Text Label
			local display = ""
			if tType == 0 and tName == "" then
				display = translated_info.LobbyTab
			elseif tType == 1 then
				display = (tName ~= "" and tName or translated_info.RoomTab)
			elseif tType == 0 and tName ~= "" then
				display = translated_info.ServerTab
			else
				display = tName
			end
			label:settext(display)

			-- Unread dot
			unreadDot:visible(unread > 0 and not isCurrent)

			-- Close button for PMs
			local canClose = not (tType == 0 or (tType == 1 and tName == NSMAN:GetCurrentRoomName()))
			closeBtn:visible(canClose)
		end,

		-- Tab BG
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(tabW - 2, tabH - 2):diffuse(Colors.tabInactive)
			end
		},
		-- Tab bottom active glow line
		Def.Quad {
			Name = "ActiveLine",
			InitCommand = function(self)
				self:halign(0):valign(1):xy(0, tabH):zoomto(tabW - 2, 2):diffuse(getAccent()):visible(false)
			end,
			ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end,
			UpdateChatOverlayMessageCommand = function(self)
				local data = tabs[i]
				self:visible(data ~= nil and data[1] == currentTabType and data[2] == currentTabName)
			end
		},
		-- Tab Label
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(8, tabH / 2):halign(0):valign(0.5):zoom(scale - 0.04)
					:diffuse(Colors.subText):maxwidth((tabW - 22) / (scale - 0.04))
			end
		},
		-- Unread notification dot
		Def.Quad {
			Name = "UnreadDot",
			InitCommand = function(self)
				self:xy(tabW - 16, tabH / 2):halign(0.5):valign(0.5):zoomto(5, 5)
					:diffuse(Colors.unreadBadge):visible(false)
			end
		},
		-- PM Close Button (×)
		Def.ActorFrame {
			Name = "CloseBtn",
			InitCommand = function(self)
				self:xy(tabW - 12, tabH / 2):visible(false)
			end,
			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:halign(0.5):valign(0.5):zoom(0.34):diffuse(Colors.dimText):settext("x")
				end
			}
		},
	}
end

for i = 1, maxTabs do
	tabContainer[#tabContainer + 1] = makeTab(i)
end

-- Top-Right Minimize Button
tabContainer[#tabContainer + 1] = Def.ActorFrame {
	Name = "MinBtn",
	InitCommand = function(self)
		self:xy(width - 24, tabH / 2)
	end,
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0.5):valign(0.5):zoom(0.4):diffuse(Colors.subText):settext("-")
		end
	}
}

expanded[#expanded + 1] = tabContainer

-- =========================================================================
-- MESSAGE WINDOW (Bounded text display with scrollbar)
-- =========================================================================
local msgBoxY = tabH + 4
local msgBoxH = height - tabH - inputH - 12
local msgBoxW = width - 8

local messageFrame = Def.ActorFrame {
	Name = "MessageFrame",
	InitCommand = function(self) self:xy(4, msgBoxY) end,
}

-- Message Background
messageFrame[#messageFrame + 1] = Def.Quad {
	Name = "MessageBg",
	InitCommand = function(self)
		self:halign(0):valign(0):zoomto(msgBoxW, msgBoxH):diffuse(Colors.outputBg)
	end
}

-- Formatted Chat Text Actor
messageFrame[#messageFrame + 1] = LoadColorFont("Common Normal") .. {
	Name = "ChatContent",
	InitCommand = function(self)
		self:xy(6, msgBoxH - 4):halign(0):valign(1):zoom(scale)
		self:SetMaxLines(maxlines, 1)
		self:wrapwidthpixels((msgBoxW - 20) / scale)
	end,
	UpdateChatOverlayMsgsMessageCommand = function(self)
		local t = ""
		local count = #messages
		local startIdx = math.max(1, lineNumber - maxlines + 1)
		local endIdx = math.min(count, lineNumber)
		for idx = startIdx, endIdx do
			local item = messages[idx]
			if item then
				t = t .. item.raw .. "\n"
			end
		end
		self:settext(t)
	end,
	UpdateChatOverlayMessageCommand = function(self)
		self:playcommand("UpdateChatOverlayMsgs")
	end
}

-- Vertical Scrollbar Track & Thumb
local scrollTrackH = msgBoxH - 8
local scrollX = msgBoxW - 6
messageFrame[#messageFrame + 1] = Def.ActorFrame {
	Name = "ScrollBar",
	InitCommand = function(self)
		self:xy(scrollX, 4)
	end,
	UpdateChatOverlayMessageCommand = function(self)
		local total = #messages
		self:visible(total > maxlines)
		if total <= maxlines then return end
		local thumb = self:GetChild("Thumb")
		local trackRatio = math.max(0.15, maxlines / total)
		local thumbH = scrollTrackH * trackRatio
		local maxOffset = total - maxlines
		local curOffset = (lineNumber - maxlines)
		local thumbY = (maxOffset > 0) and ((curOffset / maxOffset) * (scrollTrackH - thumbH)) or (scrollTrackH - thumbH)
		thumb:zoomto(3, thumbH):y(thumbY)
	end,
	Def.Quad {
		Name = "Track",
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(3, scrollTrackH):diffuse(color("0.1,0.12,0.16,0.6"))
		end
	},
	Def.Quad {
		Name = "Thumb",
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(3, 20):diffuse(getAccent()):diffusealpha(0.8)
		end,
		ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
	}
}

-- Floating "Scroll to Bottom" indicator pill
messageFrame[#messageFrame + 1] = Def.ActorFrame {
	Name = "ScrollDownPill",
	InitCommand = function(self)
		self:xy(msgBoxW / 2, msgBoxH - 14):visible(false)
	end,
	UpdateChatOverlayMessageCommand = function(self)
		self:visible(lineNumber < #messages)
	end,
	Def.Quad {
		InitCommand = function(self)
			self:halign(0.5):valign(0.5):zoomto(80, 16):diffuse(Colors.headerBg):diffusealpha(0.9)
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0.5):valign(0.5):zoom(0.26):diffuse(getAccent()):settext("v NEW v")
		end,
		ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:halign(0.5):valign(0.5):zoomto(80, 16):diffusealpha(0)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				lineNumber = #messages
				MESSAGEMAN:Broadcast("UpdateChatOverlay")
			end
		end
	}
}

expanded[#expanded + 1] = messageFrame

-- =========================================================================
-- INPUT BOX
-- =========================================================================
local inputFrameY = height - inputH - 4
local inputFrame = Def.ActorFrame {
	Name = "InputContainer",
	InitCommand = function(self) self:xy(4, inputFrameY) end,
	UpdateChatOverlayMessageCommand = function(self)
		local bg = self:GetChild("InputBg")
		local line = self:GetChild("AccentLine")
		local cursor = self:GetChild("Cursor")
		local placeholder = self:GetChild("Placeholder")
		local textActor = self:GetChild("InputText")

		if typing then
			bg:diffuse(Colors.inputActive)
			line:diffusealpha(0.85)
			cursor:visible(true):playcommand("Blink")
			placeholder:visible(typingText == ""):settext(translated_info.TypeMessage)
			textActor:settext(typingText)
		else
			bg:diffuse(Colors.inputBg)
			line:diffusealpha(0)
			cursor:visible(false):stoptweening()
			placeholder:visible(true):settext(translated_info.ClickToChat)
			textActor:settext("")
		end
	end,
}

-- Input Background
inputFrame[#inputFrame + 1] = Def.Quad {
	Name = "InputBg",
	InitCommand = function(self)
		self:halign(0):valign(0):zoomto(msgBoxW, inputH):diffuse(Colors.inputBg)
	end
}

-- Glowing bottom border when active
inputFrame[#inputFrame + 1] = Def.Quad {
	Name = "AccentLine",
	InitCommand = function(self)
		self:halign(0):valign(1):xy(0, inputH):zoomto(msgBoxW, 1.5):diffuse(getAccent()):diffusealpha(0)
	end,
	ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
}

-- Placeholder text
inputFrame[#inputFrame + 1] = LoadFont("Common Normal") .. {
	Name = "Placeholder",
	InitCommand = function(self)
		self:xy(8, inputH / 2):halign(0):valign(0.5):zoom(scale - 0.04)
			:diffuse(Colors.dimText):settext(translated_info.ClickToChat)
	end
}

-- Typed Text
inputFrame[#inputFrame + 1] = LoadFont("Common Normal") .. {
	Name = "InputText",
	InitCommand = function(self)
		self:xy(8, inputH / 2):halign(0):valign(0.5):zoom(scale - 0.04)
			:diffuse(Colors.brightText):maxwidth((msgBoxW - 50) / (scale - 0.04))
	end
}

-- Blinking Cursor
inputFrame[#inputFrame + 1] = LoadFont("Common Normal") .. {
	Name = "Cursor",
	InitCommand = function(self)
		self:xy(8, inputH / 2):halign(0):valign(0.5):zoom(scale - 0.04)
			:diffuse(getAccent()):settext("|"):visible(false)
	end,
	ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end,
	BlinkCommand = function(self)
		local textActor = self:GetParent():GetChild("InputText")
		local w = (textActor and textActor:GetZoomedWidth()) or 0
		self:x(8 + w + 1)
		self:stoptweening():diffusealpha(1):sleep(0.4):linear(0.1):diffusealpha(0):sleep(0.2):queuecommand("Blink")
	end
}

-- Send Button / Hint
inputFrame[#inputFrame + 1] = Def.ActorFrame {
	Name = "SendAction",
	InitCommand = function(self)
		self:xy(msgBoxW - 44, inputH / 2)
	end,
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0.5):valign(0.5):zoom(0.28):diffuse(Colors.subText):settext("SEND")
		end
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:halign(0.5):valign(0.5):zoomto(40, 20):diffusealpha(0)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and typingText:len() > 0 then
				NSMAN:SendChatMsg(typingText, currentTabType, currentTabName)
				typingText = ""
				typing = false
				MESSAGEMAN:Broadcast("UpdateChatOverlay")
			end
		end
	}
}

-- Input Click Activator
inputFrame[#inputFrame + 1] = UIElements.QuadButton(1, 1) .. {
	InitCommand = function(self)
		self:halign(0):valign(0):zoomto(msgBoxW - 46, inputH):diffusealpha(0)
	end,
	MouseDownCommand = function(self, params)
		if params.event == "DeviceButton_left mouse button" then
			typing = true
			MESSAGEMAN:Broadcast("UpdateChatOverlay")
		end
	end
}

expanded[#expanded + 1] = inputFrame

chat[#chat + 1] = expanded

-- Sync input redirection whenever typing state changes
chat.UpdateChatOverlayMessageCommand = function(self)
	HV.ChatTyping = typing
	local top = SCREENMAN:GetTopScreen()
	local roomListActive = online and top and top:GetName() == "ScreenNetRoom"
	SCREENMAN:set_input_redirected(PLAYER_1, typing or roomListActive)
end

-- =========================================================================
-- INPUT HANDLING (MPinput)
-- =========================================================================
local shouldOpenSlash = false

function MPinput(event)
	if not show or not online or isGameplay then
		return false
	end
	local topScreen = SCREENMAN:GetTopScreen()
	if (HV and HV.TextEntryActive) or (topScreen and topScreen:GetName() == "ScreenTextEntry") then
		return false
	end

	local wasTyping = typing
	local update = false
	if enterKeyDown and event.DeviceInput.button == "DeviceButton_enter" and event.type == "InputEventType_Release" then
		enterKeyDown = false
		return true
	end
	if event.type == "InputEventType_FirstPress" and event.DeviceInput.button == "DeviceButton_left mouse button" then
		local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
		if minimised and mx >= miniX and mx <= miniX + miniW and my >= miniY and my <= miniY + miniH then
			toggleChat(false)
			return true
		elseif not minimised and mx >= x + width - 36 and mx <= x + width - 12 and
			my >= y + 2 + tabH / 2 - 10 and my <= y + 2 + tabH / 2 + 10 then
			toggleChat(false)
			return true
		elseif not minimised and mx >= x and mx <= x + width and
			my >= y + 2 and my <= y + 2 + tabH then
			local tabX = mx - x
			for i = 1, maxTabs do
				local data = tabs[i]
				local left = (i - 1) * tabW
				if data and tabX >= left and tabX <= left + tabW - 2 then
					local canClose = not (data[1] == 0 or
						(data[1] == 1 and data[2] == NSMAN:GetCurrentRoomName()))
					local closeX = left + tabW - 12
					local closeY = y + 2 + tabH / 2
					if canClose and tabX >= closeX - 7 and tabX <= closeX + 7 and
						my >= closeY - 7 and my <= closeY + 7 then
						closeChatTab(i)
					else
						changeTab(data[2], data[1])
					end
					return true
				end
			end
			return true
		elseif not minimised and mx >= x + 4 and mx <= x + 4 + msgBoxW and
			my >= y + inputFrameY and my <= y + inputFrameY + inputH then
			if mx >= x + 4 + msgBoxW - 64 then
				if typingText:len() > 0 then
					NSMAN:SendChatMsg(typingText, currentTabType, currentTabName)
					typingText = ""
					typing = false
				end
			else
				typing = true
			end
			MESSAGEMAN:Broadcast("UpdateChatOverlay")
			return true
		end
		-- Leave tab and message-area clicks to their own UI buttons.
		return false
	end

	-- Global Keyboard shortcuts when not typing
	if not typing and event.type == "InputEventType_FirstPress" then
		if event.DeviceInput.button == "DeviceButton_t" then
			toggleChat(false)
			return true
		elseif event.DeviceInput.button == "DeviceButton_insert" then
			toggleChat(true)
			return true
		elseif event.DeviceInput.button == "DeviceButton_/" then
			shouldOpenSlash = true
		end
	end

	-- Slash key auto-open
	if shouldOpenSlash and event.type == "InputEventType_FirstPress" and event.DeviceInput.button ~= "DeviceButton_/" then
		shouldOpenSlash = false
	end
	if not typing and event.type == "InputEventType_Release" and event.DeviceInput.button == "DeviceButton_/" and shouldOpenSlash then
		shouldOpenSlash = false
		if minimised then
			minimised = false
			MESSAGEMAN:Broadcast("Minimise")
		end
		typing = true
		typingText = "/"
		MESSAGEMAN:Broadcast("UpdateChatOverlay")
		return true
	end

	-- Mouse wheel scrolling over messages
	if event.type == "InputEventType_FirstPress" and not minimised then
		local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
		if mx >= x and mx <= x + width and my >= y + tabH and my <= y + height - inputH then
			if event.DeviceInput.button == "DeviceButton_mousewheel up" then
				if lineNumber > maxlines then
					lineNumber = math.max(maxlines, lineNumber - 2)
					update = true
				end
			elseif event.DeviceInput.button == "DeviceButton_mousewheel down" then
				if lineNumber < #messages then
					lineNumber = math.min(#messages, lineNumber + 2)
					update = true
				end
			end
		end
	end

	-- Active Typing Input
	if typing then
		if event.button == "Back" or (event.type == "InputEventType_FirstPress" and event.DeviceInput.button == "DeviceButton_escape") then
			typing = false
			update = true
		elseif event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat" then
			if event.DeviceInput.button == "DeviceButton_space" then
				typingText = typingText .. " "
				update = true
			elseif event.DeviceInput.button == "DeviceButton_delete" then
				typingText = ""
				update = true
			elseif (INPUTFILTER:IsBeingPressed("left ctrl") or INPUTFILTER:IsBeingPressed("right ctrl")) and
				event.DeviceInput.button == "DeviceButton_v" then
				local clip = tostring(Arch.getClipboard() or ""):gsub("%c", "")
				typingText = typingText .. clip
				update = true
			elseif event.DeviceInput.button == "DeviceButton_backspace" then
				if typingText:len() > 0 then
					typingText = typingText:sub(1, -2)
					update = true
				end
			elseif event.DeviceInput.button == "DeviceButton_enter" and event.type == "InputEventType_FirstPress" then
				enterKeyDown = true
				if typingText:len() > 0 then
					NSMAN:SendChatMsg(typingText, currentTabType, currentTabName)
				end
				typingText = ""
				typing = false
				update = true
			elseif event.char then
				local printable = tostring(event.char):gsub("%c", "")
				if printable ~= "" then
					typingText = typingText .. printable
					update = true
				end
			end
		end
	end

	if update then
		MESSAGEMAN:Broadcast("UpdateChatOverlay")
	end

	return wasTyping or typing or enterKeyDown
end

return chat
