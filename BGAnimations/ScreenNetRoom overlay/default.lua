--- Holographic Void: ScreenNetRoom Overlay
-- Redesigned cyberpunk Netplay Room browser and lobby dashboard.
-- Features:
--   - Modern glassmorphic room cards with state badges, password indicator, and description
--   - Dynamic keyboard, controller, and mouse navigation
--   - Interactive + CREATE ROOM button
--   - Live Lobby Players sidebar roster
--   - Seamless integration with ScreenChatOverlay and server events

local marginX = 16
local topBarH = 44
local contentY = topBarH + 12
local contentH = SCREEN_HEIGHT - contentY - 14

local roomSectionW = math.floor(SCREEN_WIDTH * 0.66)
local sidebarX = roomSectionW + marginX + 12
local sidebarW = SCREEN_WIDTH - sidebarX - marginX

local roomCardH = 64
local roomCardGap = 8
local roomCardW = roomSectionW
local maxVisibleRooms = math.max(1, math.floor((contentH - 32) / (roomCardH + roomCardGap)))

local function getAccent()
	return (HVColor and HVColor.Accent) or color("#5ABAFF")
end

local Colors = {
	cardBg = color("0.05,0.06,0.09,0.90"),
	cardSelected = color("0.11,0.14,0.22,0.98"),
	cardHover = color("0.08,0.10,0.15,0.95"),
	headerBg = color("0.03,0.04,0.06,0.98"),
	border = color("0.18,0.22,0.28,0.75"),
	dimText = color("0.45,0.48,0.55,1"),
	subText = color("0.65,0.70,0.78,1"),
	mainText = color("0.85,0.88,0.92,1"),
	brightText = color("1,1,1,1"),
	statusOpen = color("0.35,0.85,0.50,1"),
	statusInGame = color("0.95,0.65,0.25,1"),
	statusPassword = color("0.95,0.40,0.50,1"),
}

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

local function makeRoomCard(index)
	return Def.ActorFrame {
		Name = "RoomCard" .. index,
		InitCommand = function(self)
			self:xy(0, (index - 1) * (roomCardH + roomCardGap))
			self:visible(false)
		end,
		SetRoomCommand = function(self, params)
			self.room = params.room
			self.isSelected = params.selected
			self:visible(params.room ~= nil)
			if not params.room then return end

			local bg = self:GetChild("Bg")
			local accentStripe = self:GetChild("AccentStripe")
			local nameActor = self:GetChild("Name")
			local descActor = self:GetChild("Desc")
			local statePill = self:GetChild("StatePill")
			local passBadge = self:GetChild("PassBadge")
			local brackets = self:GetChild("Brackets")

			bg:diffuse(params.selected and Colors.cardSelected or Colors.cardBg)
			brackets:visible(params.selected)

			-- Name
			nameActor:settext(params.room.name or "Room")
			nameActor:diffuse(params.selected and getAccent() or Colors.brightText)

			-- Description
			local desc = params.room.description or ""
			descActor:settext(desc ~= "" and desc or "No description provided.")

			-- State: 0 = Selecting / Open, 1 = In Gameplay
			local isPlaying = (params.room.state == 1)
			statePill:GetChild("Label"):settext(isPlaying and THEME:GetString("NetRoom", "InGameplay") or THEME:GetString("NetRoom", "Open"))
			statePill:GetChild("Bg"):diffuse(isPlaying and Colors.statusInGame or Colors.statusOpen):diffusealpha(0.2)
			statePill:GetChild("Label"):diffuse(isPlaying and Colors.statusInGame or Colors.statusOpen)
			accentStripe:diffuse(isPlaying and Colors.statusInGame or getAccent())

			-- Password
			passBadge:visible(params.room.passworded == true)
		end,

		-- Card Background
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(roomCardW, roomCardH):diffuse(Colors.cardBg)
			end
		},
		-- Left accent status stripe
		Def.Quad {
			Name = "AccentStripe",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(3, roomCardH):diffuse(getAccent())
			end,
			ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
		},
		-- 1px Border
		Def.ActorFrame {
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(roomCardW, 1):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(0):valign(1):xy(0, roomCardH):zoomto(roomCardW, 1):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(1):valign(0):xy(roomCardW, 0):zoomto(1, roomCardH):diffuse(Colors.border) end },
		},
		-- Selected Corner Brackets
		Def.ActorFrame {
			Name = "Brackets",
			cornerTicks(roomCardW, roomCardH, 8, 1.5)
		},

		-- Room Name
		LoadFont("Common Normal") .. {
			Name = "Name",
			InitCommand = function(self)
				self:xy(14, 12):halign(0):valign(0):zoom(0.40)
					:diffuse(Colors.brightText):maxwidth((roomCardW - 160) / 0.40)
			end
		},

		-- Room Description
		LoadFont("Common Normal") .. {
			Name = "Desc",
			InitCommand = function(self)
				self:xy(14, 38):halign(0):valign(0):zoom(0.28)
					:diffuse(Colors.subText):maxwidth((roomCardW - 160) / 0.28)
			end
		},

		-- State Pill (Top Right)
		Def.ActorFrame {
			Name = "StatePill",
			InitCommand = function(self)
				self:xy(roomCardW - 14, 12)
			end,
			Def.Quad {
				Name = "Bg",
				InitCommand = function(self)
					self:halign(1):valign(0):zoomto(72, 18):diffuse(Colors.statusOpen):diffusealpha(0.2)
				end
			},
			LoadFont("Common Normal") .. {
				Name = "Label",
				InitCommand = function(self)
					self:xy(-36, 9):halign(0.5):valign(0.5):zoom(0.24):diffuse(Colors.statusOpen)
				end
			}
		},

		-- Password Badge (Bottom Right)
		Def.ActorFrame {
			Name = "PassBadge",
			InitCommand = function(self)
				self:xy(roomCardW - 14, 38):visible(false)
			end,
			Def.Quad {
				InitCommand = function(self)
					self:halign(1):valign(0):zoomto(72, 16):diffuse(Colors.statusPassword):diffusealpha(0.2)
				end
			},
			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:xy(-36, 8):halign(0.5):valign(0.5):zoom(0.22)
						:diffuse(Colors.statusPassword):settext(THEME:GetString("NetRoom", "Passworded"))
				end
			}
		},

		-- Click to Join Button
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(roomCardW, roomCardH):diffusealpha(0)
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and self:GetParent().room then
					SCREENMAN:GetTopScreen():SelectRoom(self:GetParent().room.name)
				end
			end
		}
	}
end

local function makeRoomBrowser()
	local selectedIdx = 1
	local scrollOffset = 0
	local focusOnCreate = false
	local rooms = {}
	local totalRooms = 0

	local function refreshUI(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen or not screen.GetRoomWheel then return end
		local whe = screen:GetRoomWheel()
		if not whe then return end
		-- The custom selector owns room focus and selection. Keep the legacy C++
		-- wheel hidden so its synthetic Create Room rows cannot appear or receive focus.
		if whe then pcall(function() whe:visible(false) end) end
		if screen.InfoSetVisible then pcall(function() screen:InfoSetVisible(false) end) end
		rooms = whe:GetRooms() or {}
		totalRooms = #rooms

		if totalRooms == 0 then
			focusOnCreate = true
			selectedIdx = 1
			scrollOffset = 0
		else
			if selectedIdx < 1 then selectedIdx = 1 end
			if selectedIdx > totalRooms then selectedIdx = totalRooms end
			if selectedIdx <= scrollOffset then
				scrollOffset = selectedIdx - 1
			elseif selectedIdx > scrollOffset + maxVisibleRooms then
				scrollOffset = selectedIdx - maxVisibleRooms
			end
		end

		-- Update header count badge
		local countBadge = self:GetChild("SectionHeader")
		countBadge = countBadge and countBadge:GetChild("CountBadge")
		countBadge = countBadge and countBadge:GetChild("Text")
		if countBadge then countBadge:settext(tostring(totalRooms)) end

		-- Update visible cards
		local cardsFrameActor = self:GetChild("CardsFrame")
		if cardsFrameActor then
			for i = 1, maxVisibleRooms do
				local card = cardsFrameActor:GetChild("RoomCard" .. i)
				if card then
					local rIdx = i + scrollOffset
					local roomData = rooms[rIdx]
					local isSel = (not focusOnCreate and rIdx == selectedIdx)
					card:playcommand("SetRoom", {room = roomData, selected = isSel})
				end
			end
		end

		-- Empty state visibility
		local emptyState = self:GetChild("EmptyState")
		if emptyState then emptyState:visible(totalRooms == 0) end

		-- Update sidebar create button state
		MESSAGEMAN:Broadcast("UpdateRoomChoices", {focusCreate = focusOnCreate})
	end

	local cardsFrame = Def.ActorFrame {
		Name = "CardsFrame",
		InitCommand = function(self) self:xy(0, 26) end,
	}
	for i = 1, maxVisibleRooms do
		cardsFrame[#cardsFrame + 1] = makeRoomCard(i)
	end

	local af = Def.ActorFrame {
		Name = "RoomBrowserFrame",
		InitCommand = function(self)
			self:xy(marginX, contentY)
		end,
		OnCommand = function(self)
			SCREENMAN:set_input_redirected(PLAYER_1, true)
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				screen:AddInputCallback(function(event)
					-- The room browser must yield keyboard input while the chat field owns it.
					-- Player input remains redirected, so the native RoomWheel never sees it.
					if HV and HV.ChatTyping then return false end
					if event.type ~= "InputEventType_FirstPress" and event.type ~= "InputEventType_Repeat" then
						return false
					end

					local btn = event.button
					local dBtn = event.DeviceInput and event.DeviceInput.button or ""

					-- Cancel / Back
					if btn == "Back" or dBtn == "DeviceButton_escape" then
						screen:Cancel()
						return true
					end

					-- Left / Right toggles focus between room list and Create Room button
					if btn == "MenuLeft" or btn == "Left" or btn == "MenuRight" or btn == "Right" then
						focusOnCreate = not focusOnCreate
						refreshUI(self)
						return true
					end

					-- Up / Down navigation
					if btn == "MenuUp" or btn == "Up" or btn == "MenuDown" or btn == "Down" then
						local step = (btn == "MenuDown" or btn == "Down") and 1 or -1
						if focusOnCreate then
							focusOnCreate = false
							selectedIdx = (step > 0) and 1 or totalRooms
						elseif totalRooms > 0 then
							selectedIdx = selectedIdx + step
							if selectedIdx < 1 then selectedIdx = totalRooms end
							if selectedIdx > totalRooms then selectedIdx = 1 end
						end
						refreshUI(self)
						return true
					end

					-- Start / Enter
					if btn == "Start" or dBtn == "DeviceButton_enter" then
						if focusOnCreate or totalRooms == 0 then
							screen:GetRoomWheel():MakeNewRoom()
						elseif rooms[selectedIdx] then
							screen:SelectRoom(rooms[selectedIdx].name)
						end
						return true
					end

					return false
				end)
			end
			self:playcommand("RefreshRooms")
		end,
		RefreshRoomsCommand = function(self) refreshUI(self) end,
		RoomListUpdatedMessageCommand = function(self) refreshUI(self) end,

		-- Section Header
		Def.ActorFrame {
			Name = "SectionHeader",
			InitCommand = function(self) self:xy(0, 0) end,
			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:xy(0, 10):halign(0):valign(0.5):zoom(0.38)
						:diffuse(Colors.brightText):settext("ACTIVE ROOMS")
				end
			},
			-- Count Badge
			Def.ActorFrame {
				Name = "CountBadge",
				InitCommand = function(self) self:xy(108, 10) end,
				Def.Quad {
					InitCommand = function(self)
						self:halign(0):valign(0.5):zoomto(28, 16):diffuse(color("0.12,0.16,0.24,0.9"))
					end
				},
				LoadFont("Common Normal") .. {
					Name = "Text",
					InitCommand = function(self)
						self:xy(14, 0):halign(0.5):valign(0.5):zoom(0.26):diffuse(getAccent())
					end,
					ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
				}
			}
		},

		-- Cards Container
		cardsFrame,

		-- Empty State Card (Visible when 0 rooms)
		Def.ActorFrame {
			Name = "EmptyState",
			InitCommand = function(self)
				self:xy(0, 26):visible(false)
			end,
			Def.Quad {
				InitCommand = function(self)
					self:halign(0):valign(0):zoomto(roomCardW, 140):diffuse(Colors.cardBg)
				end
			},
			Def.ActorFrame {
				Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(roomCardW, 1):diffuse(Colors.border) end },
				Def.Quad { InitCommand = function(self) self:halign(0):valign(1):xy(0, 140):zoomto(roomCardW, 1):diffuse(Colors.border) end },
				Def.Quad { InitCommand = function(self) self:halign(1):valign(0):xy(roomCardW, 0):zoomto(1, 140):diffuse(Colors.border) end },
			},
			cornerTicks(roomCardW, 140, 8, 1.5),
			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:xy(roomCardW / 2, 42):halign(0.5):valign(0.5):zoom(0.42)
						:diffuse(Colors.brightText):settext(THEME:GetString("NetRoom", "NoRooms"))
				end
			},
			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:xy(roomCardW / 2, 68):halign(0.5):valign(0.5):zoom(0.30)
						:diffuse(Colors.subText):settext(THEME:GetString("NetRoom", "NoRoomsSub"))
				end
			},
			-- Empty state Action button
			Def.ActorFrame {
				InitCommand = function(self)
					self:xy(roomCardW / 2, 104)
				end,
				Def.Quad {
					InitCommand = function(self)
						self:halign(0.5):valign(0.5):zoomto(160, 26):diffuse(getAccent()):diffusealpha(0.85)
					end,
					ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()):diffusealpha(0.85) end
				},
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						self:halign(0.5):valign(0.5):zoom(0.32):diffuse(color("0,0,0,1")):settext(THEME:GetString("NetRoom", "CreateRoom"))
					end
				},
				UIElements.QuadButton(1, 1) .. {
					InitCommand = function(self)
						self:halign(0.5):valign(0.5):zoomto(160, 26):diffusealpha(0)
					end,
					MouseDownCommand = function(self, params)
						if params.event == "DeviceButton_left mouse button" then
							SCREENMAN:GetTopScreen():GetRoomWheel():MakeNewRoom()
						end
					end
				}
			}
		}
	}

	return af
end

-- =========================================================================
-- MAIN OVERLAY
-- =========================================================================
local t = Def.ActorFrame {
	Name = "ScreenNetRoomRoot"
}

-- Top Header Bar
local topBar = Def.ActorFrame {
	Name = "TopHeaderBar",
	InitCommand = function(self) self:xy(0, 0) end,

	-- Top Bar Glass Background
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(SCREEN_WIDTH, topBarH):diffuse(Colors.headerBg)
		end
	},
	-- Header Bottom Accent Line
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(1):xy(0, topBarH):zoomto(SCREEN_WIDTH, 1.5):diffuse(getAccent())
		end,
		ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
	},

	-- `< BACK` Button (0..80)
	Def.ActorFrame {
		Name = "BackButton",
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(80, topBarH):diffusealpha(0)
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(20, topBarH / 2):halign(0):valign(0.5):zoom(0.38)
					:diffuse(Colors.mainText):settext("< BACK")
			end
		},
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(80, topBarH):diffusealpha(0)
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" then
					SCREENMAN:GetTopScreen():Cancel()
				end
			end
		}
	},

	-- Screen Title & Subtitle
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(90, 14):halign(0):valign(0.5):zoom(0.44)
				:diffuse(Colors.brightText):settext(THEME:GetString("NetRoom", "Name"))
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(90, 30):halign(0):valign(0.5):zoom(0.26)
				:diffuse(Colors.dimText):settext(THEME:GetString("NetRoom", "Explain"))
		end
	},

	-- Right Connection Status Badge
	Def.ActorFrame {
		Name = "ServerStatus",
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH - marginX, topBarH / 2)
		end,
		-- Online Dot
		Def.Quad {
			InitCommand = function(self)
				self:xy(-140, 0):halign(0.5):valign(0.5):zoomto(6, 6)
					:diffuse(Colors.statusOpen)
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				local name = NSMAN:GetLoggedInUsername() or "Player"
				self:xy(0, 0):halign(1):valign(0.5):zoom(0.32)
					:diffuse(Colors.mainText):settextf("CONNECTED · %s", name)
			end
		}
	}
}
t[#t + 1] = topBar

-- Left: Room Browser
t[#t + 1] = makeRoomBrowser()

-- Right: Sidebar (Create Room Action + Lobby Users List + Navigation Guide)
local sidebar = Def.ActorFrame {
	Name = "SidebarFrame",
	InitCommand = function(self)
		self:xy(sidebarX, contentY)
	end
}

-- 1. Create Room Action Card
local createBtnH = 38
sidebar[#sidebar + 1] = Def.ActorFrame {
	Name = "CreateRoomButtonCard",
	InitCommand = function(self) self:xy(0, 0) end,
	UpdateRoomChoicesMessageCommand = function(self, params)
		local isSel = params and params.focusCreate
		local bg = self:GetChild("Bg")
		local label = self:GetChild("Label")
		if isSel then
			bg:diffuse(getAccent()):diffusealpha(0.95)
			label:diffuse(color("0,0,0,1"))
		else
			bg:diffuse(Colors.cardBg):diffusealpha(0.9)
			label:diffuse(getAccent())
		end
	end,

	Def.Quad {
		Name = "Bg",
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(sidebarW, createBtnH):diffuse(Colors.cardBg)
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(3, createBtnH):diffuse(getAccent())
		end,
		ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
	},
	Def.ActorFrame {
		Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(sidebarW, 1):diffuse(Colors.border) end },
		Def.Quad { InitCommand = function(self) self:halign(0):valign(1):xy(0, createBtnH):zoomto(sidebarW, 1):diffuse(Colors.border) end },
		Def.Quad { InitCommand = function(self) self:halign(1):valign(0):xy(sidebarW, 0):zoomto(1, createBtnH):diffuse(Colors.border) end },
	},
	cornerTicks(sidebarW, createBtnH, 6, 1.5),

	-- Create Room button label
	LoadFont("Common Normal") .. {
		Name = "Label",
		InitCommand = function(self)
			self:xy(14, createBtnH / 2):halign(0):valign(0.5):zoom(0.36)
				:diffuse(getAccent()):settext(THEME:GetString("NetRoom", "CreateRoom"))
		end,
		ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(sidebarW, createBtnH):diffusealpha(0)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				SCREENMAN:GetTopScreen():GetRoomWheel():MakeNewRoom()
			end
		end
	}
}

-- 2. Lobby User List (Takes main vertical area)
local lobbyListY = createBtnH + 10
local lobbyListH = contentH - lobbyListY
local makeLobbyList = LoadActor("lobbyuserlist.lua")
sidebar[#sidebar + 1] = makeLobbyList(0, lobbyListY, sidebarW, lobbyListH)

t[#t + 1] = sidebar

-- Shared theme cursor
t[#t + 1] = LoadActor("../_cursor")

return t
