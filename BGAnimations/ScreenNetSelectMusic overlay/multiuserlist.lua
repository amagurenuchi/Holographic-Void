--- Holographic Void: Multi-User Player List (ScreenNetSelectMusic)
-- Sleek glassmorphic roster displaying all players in the room.
-- Communicates player status purely via dynamic color:
--   - Green (#44FF88): Ready
--   - Dim Gray: Selecting / Waiting
--   - Amber/Gold: Player Options
--   - Cyan: In Gameplay
--   - Pure White: In Evaluation
-- Host indicator (★) and local player indicator (YOU).

local function getAccent()
	return (HVColor and HVColor.Accent) or color("#5ABAFF")
end

local Colors = {
	cardBg = color("0.05,0.06,0.09,0.92"),
	headerBg = color("0.07,0.08,0.12,0.96"),
	rowBg = color("0.08,0.09,0.13,0.75"),
	rowSelf = color("0.10,0.14,0.22,0.95"),
	border = color("0.18,0.22,0.28,0.75"),
	dimText = color("0.55,0.58,0.65,1"),
	subText = color("0.65,0.70,0.78,1"),
	brightText = color("1,1,1,1"),
	-- Status Colors
	stateReady = color("#44FF88"),
	stateSelecting = color("0.65,0.70,0.78,1"),
	stateOptions = color("1.0,0.80,0.25,1"),
	statePlaying = color("0.40,0.80,1.0,1"),
	stateEval = color("1,1,1,1"),
}

local panelX = 8
local panelW = SCREEN_WIDTH * 0.36
local rosterX = panelX + panelW + 12
local rosterY = 84
local rosterW = 280
local maxRows = 16
local rowH = 22
local rowGap = 3
local headerH = 26

local collapsed = false

local function makePlayerRow(index)
	return Def.ActorFrame {
		Name = "PlayerRow" .. index,
		InitCommand = function(self)
			self:xy(6, headerH + 6 + (index - 1) * (rowH + rowGap))
			self:visible(false)
		end,
		UpdatePlayerCommand = function(self, params)
			if not params or not params.name or params.name == "" then
				self:visible(false)
				return
			end
			self:visible(true)

			local bg = self:GetChild("Bg")
			local edge = self:GetChild("StatusEdge")
			local statusDot = self:GetChild("StatusDot")
			local nameActor = self:GetChild("Name")
			local hostIcon = self:GetChild("HostIcon")
			local youActor = self:GetChild("YouLabel")

			local isMe = params.isMe
			local isHost = (index == 1)

			-- Determine status color
			local sColor = Colors.stateSelecting
			if params.state == 3 then
				sColor = Colors.stateEval
			elseif params.state == 2 then
				sColor = Colors.statePlaying
			elseif params.state == 4 then
				sColor = Colors.stateOptions
			else
				if params.isReady then
					sColor = Colors.stateReady
				else
					sColor = Colors.stateSelecting
				end
			end

			bg:diffuse(isMe and Colors.rowSelf or Colors.rowBg)
			edge:diffuse(sColor)
			statusDot:diffuse(sColor)
			nameActor:settext(params.name):diffuse(sColor)
			hostIcon:visible(isHost)
			youActor:visible(isMe)
		end,

		-- Row background
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(rosterW - 12, rowH):diffuse(Colors.rowBg)
			end
		},
		-- Left status color stripe
		Def.Quad {
			Name = "StatusEdge",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(3, rowH):diffuse(Colors.stateSelecting)
			end
		},
		-- Status Dot
		Def.Quad {
			Name = "StatusDot",
			InitCommand = function(self)
				self:xy(9, rowH / 2):halign(0.5):valign(0.5):zoomto(4, 4):diffuse(Colors.stateSelecting)
			end
		},
		-- Host star icon
		LoadFont("Common Normal") .. {
			Name = "HostIcon",
			InitCommand = function(self)
				self:xy(17, rowH / 2):halign(0):valign(0.5):zoom(0.26)
					:diffuse(color("1.0,0.82,0.25,1")):settext("*"):visible(false)
			end
		},
		-- Player Name (diffused directly by status color)
		LoadFont("Common Normal") .. {
			Name = "Name",
			InitCommand = function(self)
				self:xy(28, rowH / 2):halign(0):valign(0.5):zoom(0.32)
					:diffuse(Colors.brightText):maxwidth((rosterW - 74) / 0.32)
			end
		},
		-- YOU Label
		LoadFont("Common Normal") .. {
			Name = "YouLabel",
			InitCommand = function(self)
				self:xy(rosterW - 18, rowH / 2):halign(1):valign(0.5):zoom(0.24)
					:diffuse(getAccent()):settext("YOU"):visible(false)
			end,
			ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
		}
	}
end

local r = Def.ActorFrame {
	Name = "MultiUserListRoot",
	InitCommand = function(self)
		self:xy(rosterX, rosterY)
		self:visible(true)
	end,
	OnCommand = function(self)
		self:playcommand("Refresh")
	end,
	ToggleNetRosterMessageCommand = function(self)
		collapsed = not collapsed
		self:stoptweening():decelerate(0.2)
		if collapsed then
			self:diffusealpha(0):visible(false)
		else
			self:diffusealpha(1):visible(true)
		end
	end,
	RefreshCommand = function(self)
		local top = SCREENMAN:GetTopScreen()
		if not top or top:GetName() ~= "ScreenNetSelectMusic" then
			self:visible(false)
			return
		end
		if not collapsed then self:visible(true) end

		local qty = (top.GetUserQty and top:GetUserQty()) or 0
		local localUser = NSMAN:GetLoggedInUsername() or ""
		local readyCount = 0

		local visibleCount = math.min(qty, maxRows)
		for i = 1, maxRows do
			local rowActor = self:GetChild("PlayerRow" .. i)
			if rowActor then
				if i <= qty then
					local uName = top:GetUser(i)
					local uReady = (top.GetUserReady and top:GetUserReady(i)) == true
					local uState = (top.GetUserState and top:GetUserState(i)) or 1
					if uReady then readyCount = readyCount + 1 end
					local isMe = (localUser ~= "" and uName:lower() == localUser:lower())
					rowActor:playcommand("UpdatePlayer", {name = uName, isReady = uReady, state = uState, isMe = isMe})
				else
					rowActor:playcommand("UpdatePlayer", nil)
				end
			end
		end

		-- Dynamic height based on visible players
		local totalH = headerH + 10 + math.max(1, visibleCount) * (rowH + rowGap)
		local bgQuad = self:GetChild("CardBg")
		if bgQuad then bgQuad:zoomto(rosterW, totalH) end
		local bQuad = self:GetChild("CardBottomBorder")
		if bQuad then bQuad:y(totalH) end
		local rQuad = self:GetChild("CardRightBorder")
		if rQuad then rQuad:zoomto(1, totalH) end
		local lQuad = self:GetChild("CardLeftBorder")
		if lQuad then lQuad:zoomto(1, totalH) end

		-- Header count label
		local header = self:GetChild("Header")
		local headerText = header and header:GetChild("Title")
		if headerText then
			headerText:settextf("ROOM PLAYERS (%d/%d)", readyCount, qty)
		end
	end,
	UsersUpdateMessageCommand = function(self) self:playcommand("Refresh") end,
	PlayerJoinedMessageCommand = function(self) self:playcommand("Refresh") end,
	PlayerUnjoinedMessageCommand = function(self) self:playcommand("Refresh") end,
	ChatMessageCommand = function(self) self:playcommand("Refresh") end,

	-- Card Background
	Def.Quad {
		Name = "CardBg",
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(rosterW, 80):diffuse(Colors.cardBg)
		end
	},
	-- Top Accent Line
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(rosterW, 2):diffuse(getAccent())
		end,
		ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
	},
	-- 1px Borders
	Def.Quad { Name = "CardTopBorder", InitCommand = function(self) self:halign(0):valign(0):zoomto(rosterW, 1):diffuse(Colors.border) end },
	Def.Quad { Name = "CardBottomBorder", InitCommand = function(self) self:halign(0):valign(1):xy(0, 80):zoomto(rosterW, 1):diffuse(Colors.border) end },
	Def.Quad { Name = "CardLeftBorder", InitCommand = function(self) self:halign(0):valign(0):zoomto(1, 80):diffuse(Colors.border) end },
	Def.Quad { Name = "CardRightBorder", InitCommand = function(self) self:halign(1):valign(0):xy(rosterW, 0):zoomto(1, 80):diffuse(Colors.border) end },

	-- Header Bar
	Def.ActorFrame {
		Name = "Header",
		InitCommand = function(self) self:xy(0, 2) end,
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(rosterW, headerH):diffuse(Colors.headerBg)
			end
		},
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(1):xy(0, headerH):zoomto(rosterW, 1):diffuse(Colors.border)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Title",
			InitCommand = function(self)
				self:xy(10, headerH / 2):halign(0):valign(0.5):zoom(0.32)
					:diffuse(Colors.brightText):settext("ROOM PLAYERS")
			end
		},
		-- Collapse Button
		Def.ActorFrame {
			InitCommand = function(self) self:xy(rosterW - 16, headerH / 2) end,
			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:halign(0.5):valign(0.5):zoom(0.34):diffuse(Colors.dimText):settext("-")
				end
			},
			UIElements.QuadButton(1, 1) .. {
				InitCommand = function(self)
					self:halign(0.5):valign(0.5):zoomto(20, 20):diffusealpha(0)
				end,
				MouseDownCommand = function(self, params)
					if params.event == "DeviceButton_left mouse button" then
						MESSAGEMAN:Broadcast("ToggleNetRoster")
					end
				end
			}
		}
	}
}

for i = 1, maxRows do
	r[#r + 1] = makePlayerRow(i)
end

return r
