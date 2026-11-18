--- Holographic Void: ScreenNetRoom Lobby User List
-- Sleek cyberpunk player roster card for the Netplay Lobby sidebar.

local function getAccent()
	return (HVColor and HVColor.Accent) or color("#5ABAFF")
end

local Colors = {
	cardBg = color("0.05,0.06,0.09,0.92"),
	headerBg = color("0.07,0.08,0.12,0.95"),
	rowBg = color("0.08,0.09,0.13,0.7"),
	rowSelf = color("0.10,0.14,0.22,0.9"),
	border = color("0.18,0.22,0.28,0.75"),
	dimText = color("0.45,0.48,0.55,1"),
	subText = color("0.65,0.70,0.78,1"),
	brightText = color("1,1,1,1"),
	statusOnline = color("0.40,0.85,0.50,1"),
}

local maxUsers = 24
local lobbos = {}
local localUser = ""

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

local function makeUserRow(i, rowW, rowH)
	return Def.ActorFrame {
		Name = "User" .. i,
		InitCommand = function(self)
			self:visible(false)
		end,
		UpdateLobbyUsersCommand = function(self)
			local name = lobbos[i]
			self:visible(name ~= nil and name ~= "")
			if not name or name == "" then return end

			local isMe = (localUser ~= "" and name:lower() == localUser:lower())
			local bg = self:GetChild("Bg")
			local dot = self:GetChild("Dot")
			local label = self:GetChild("Name")
			local youBadge = self:GetChild("YouBadge")

			bg:diffuse(isMe and Colors.rowSelf or Colors.rowBg)
			label:diffuse(isMe and getAccent() or Colors.brightText):settext(name)
			youBadge:visible(isMe)
		end,

		-- Row background
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(rowW, rowH):diffuse(Colors.rowBg)
			end
		},
		-- Status Online dot
		Def.Quad {
			Name = "Dot",
			InitCommand = function(self)
				self:xy(8, rowH / 2):halign(0.5):valign(0.5):zoomto(4, 4)
					:diffuse(Colors.statusOnline)
			end
		},
		-- Username
		LoadFont("Common Normal") .. {
			Name = "Name",
			InitCommand = function(self)
				self:xy(16, rowH / 2):halign(0):valign(0.5):zoom(0.30)
					:diffuse(Colors.brightText):maxwidth((rowW - 48) / 0.30)
			end
		},
		-- YOU badge
		LoadFont("Common Normal") .. {
			Name = "YouBadge",
			InitCommand = function(self)
				self:xy(rowW - 6, rowH / 2):halign(1):valign(0.5):zoom(0.24)
					:diffuse(getAccent()):settext("YOU"):visible(false)
			end,
			ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
		}
	}
end

return function(cardX, cardY, cardW, cardH)
	local headerH = 28
	local listH = cardH - headerH - 8
	local rowH = 22
	local rowGap = 4
	local cols = (cardW >= 240) and 2 or 1
	local colW = (cardW - 16 - (cols - 1) * 6) / cols
	local maxPerCol = math.floor(listH / (rowH + rowGap))

	local r = Def.ActorFrame {
		Name = "LobbyUserListCard",
		InitCommand = function(self)
			self:xy(cardX, cardY)
		end,
		OnCommand = function(self)
			self:playcommand("Refresh")
		end,
		RefreshCommand = function(self)
			lobbos = NSMAN:GetLobbyUserList() or {}
			localUser = NSMAN:GetLoggedInUsername() or ""
			local countBadge = self:GetChild("Header")
			countBadge = countBadge and countBadge:GetChild("CountBadge")
			local countLabel = countBadge and countBadge:GetChild("Text")
			if countLabel then
				countLabel:settext(tostring(#lobbos))
			end
			local emptyHint = self:GetChild("EmptyHint")
			if emptyHint then emptyHint:visible(#lobbos == 0) end
			local rowsChild = self:GetChild("Rows")
			for i = 1, maxUsers do
				local row = rowsChild and rowsChild:GetChild("User" .. i)
				if row then
					row:playcommand("UpdateLobbyUsers")
				end
			end
		end,
		UsersUpdateMessageCommand = function(self) self:playcommand("Refresh") end,
		PlayerJoinedMessageCommand = function(self) self:playcommand("Refresh") end,
		PlayerUnjoinedMessageCommand = function(self) self:playcommand("Refresh") end,

		-- Main Card Background
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(cardW, cardH):diffuse(Colors.cardBg)
			end
		},
		-- Top accent stripe
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(cardW, 2):diffuse(getAccent())
			end,
			ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
		},
		-- 1px Border
		Def.ActorFrame {
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(cardW, 1):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(0):valign(1):xy(0, cardH):zoomto(cardW, 1):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(1, cardH):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(1):valign(0):xy(cardW, 0):zoomto(1, cardH):diffuse(Colors.border) end },
		},
		-- Corner Brackets
		cornerTicks(cardW, cardH, 6, 1.5),

		-- Header
		Def.ActorFrame {
			Name = "Header",
			InitCommand = function(self) self:xy(0, 2) end,
			Def.Quad {
				InitCommand = function(self)
					self:halign(0):valign(0):zoomto(cardW, headerH):diffuse(Colors.headerBg)
				end
			},
			Def.Quad {
				InitCommand = function(self)
					self:halign(0):valign(1):xy(0, headerH):zoomto(cardW, 1):diffuse(Colors.border)
				end
			},
			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:xy(10, headerH / 2):halign(0):valign(0.5):zoom(0.34)
						:diffuse(Colors.brightText):settext(THEME:GetString("NetRoom", "LobbyPlayers"))
				end
			},
			-- Count Badge
			Def.ActorFrame {
				Name = "CountBadge",
				InitCommand = function(self) self:xy(cardW - 24, headerH / 2) end,
				Def.Quad {
					InitCommand = function(self)
						self:halign(0.5):valign(0.5):zoomto(26, 14):diffuse(color("0.12,0.16,0.22,0.9"))
					end
				},
				LoadFont("Common Normal") .. {
					Name = "Text",
					InitCommand = function(self)
						self:halign(0.5):valign(0.5):zoom(0.24):diffuse(getAccent())
					end,
					ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end
				}
			}
		},

		-- Empty hint
		LoadFont("Common Normal") .. {
			Name = "EmptyHint",
			InitCommand = function(self)
				self:xy(cardW / 2, cardH / 2):halign(0.5):valign(0.5):zoom(0.32)
					:diffuse(Colors.dimText):settext("No players in lobby"):visible(false)
			end
		},
	}

	local rowsContainer = Def.ActorFrame {
		Name = "Rows",
		InitCommand = function(self)
			self:xy(8, headerH + 6)
		end,
	}
	for i = 1, maxUsers do
		local col = math.floor((i - 1) / maxPerCol)
		local row = (i - 1) % maxPerCol
		if col < cols then
			local rowItem = makeUserRow(i, colW, rowH)
			rowItem.InitCommand = function(self)
				self:xy(col * (colW + 6), row * (rowH + rowGap))
				self:visible(false)
			end
			rowsContainer[#rowsContainer + 1] = rowItem
		end
	end
	r[#r + 1] = rowsContainer

	return r
end
