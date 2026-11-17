local revert_sync_changes    = THEME:GetString("ScreenSyncOverlay", "revert_sync_changes")
local change_song_offset     = THEME:GetString("ScreenSyncOverlay", "change_song_offset")
local change_machine_offset  = THEME:GetString("ScreenSyncOverlay", "change_machine_offset")
local hold_alt               = THEME:GetString("ScreenSyncOverlay", "hold_alt")

local lbl_autoplaycpu        = THEME:GetString("ScreenSyncOverlay", "label_autoplaycpu")
local lbl_autoplay           = THEME:GetString("ScreenSyncOverlay", "label_autoplay")
local lbl_replay             = THEME:GetString("ScreenSyncOverlay", "label_replay")
local lbl_spectating         = THEME:GetString("ScreenSyncOverlay", "label_spectating")
local lbl_autosync_song      = THEME:GetString("ScreenSyncOverlay", "label_autosync_song")
local lbl_autosync_global    = THEME:GetString("ScreenSyncOverlay", "label_autosync_global")
local lbl_autosync_tempo     = THEME:GetString("ScreenSyncOverlay", "label_autosync_tempo")
local lbl_sync_reverted      = THEME:GetString("ScreenSyncOverlay", "label_sync_reverted")
local lbl_course_sync        = THEME:GetString("ScreenSyncOverlay", "label_course_sync_disabled")
local lbl_adj_format         = THEME:GetString("ScreenSyncOverlay", "adj_format")

local sh_r = THEME:GetMetric("Common", "ScreenHeight") / 480
local showadj = true

local function getAccent()
	return (HVColor and HVColor.Accent) or color("#5ABAFF")
end

local brightText  = color("1,1,1,1")
local mainText    = color("0.88,0.90,0.94,1")
local subText     = color("0.60,0.64,0.72,1")
local dimText     = color("0.42,0.45,0.52,1")
local borderColor = color("0.16,0.18,0.24,0.75")
local cardBg      = color("0.03,0.03,0.05,0.92")
local rowBg       = color("0.07,0.08,0.11,0.75")
local rowBorder   = color("0.16,0.18,0.24,0.5")

local function parseLabel(raw)
	if not raw then return "", nil end
	local title, sub = raw:match("^(.-) %- (.*)$")
	if title and sub then
		return title, sub
	end
	return raw, nil
end

local revertTitle, revertSub = parseLabel(revert_sync_changes)
local songTitle, songSub = parseLabel(change_song_offset)
local machineTitle, machineSub = parseLabel(change_machine_offset)

-- Custom labels for status (Autoplay, AutoplayCPU, Replay, etc.)
local function getCustomStatusLabel(raw)
	if not raw or raw == "" then return "" end
	local lower = raw:lower():gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
	if lower:find("autoplaycpu", 1, true) then
		return lbl_autoplaycpu
	elseif lower:find("autoplay", 1, true) then
		return lbl_autoplay
	elseif lower == "replay" then
		return lbl_replay
	elseif lower == "spectate" or lower == "spectating" then
		return lbl_spectating
	elseif lower:find("autosync%s*song") then
		return lbl_autosync_song
	elseif lower:find("autosync%s*machine") or lower:find("autosync%s*global") then
		return lbl_autosync_global
	elseif lower:find("autosync%s*tempo") then
		return lbl_autosync_tempo
	elseif lower:find("sync changes reverted") then
		return lbl_sync_reverted
	elseif lower:find("can't sync while playing a course") then
		return lbl_course_sync
	end
	return raw:upper()
end

local function setStatusDisplay(actor, label)
	actor:settext(label):visible(label ~= "")
	local parent = actor:GetParent()
	local bg = parent and parent:GetChild("StatusBG")
	if not bg then return end
	if label == "" then
		bg:visible(false)
		return
	end

	bg:visible(true)
	actor:xy(SCREEN_RIGHT - 24, SCREEN_TOP + 24):halign(1)
	local tw = actor:GetZoomedWidth()
	local bw = tw + 28
	local bh = 22
	local bx = SCREEN_RIGHT - 14 - bw / 2
	local by = SCREEN_TOP + 24
	bg:xy(bx, by)
	bg:GetChild("Border"):zoomto(bw, bh)
	bg:GetChild("Body"):zoomto(bw - 2, bh - 2)
	bg:GetChild("TopAccent"):xy(0, -bh / 2 + 0.75):zoomto(bw, 1.5)
	bg:GetChild("Pip"):xy(-bw / 2 + 8, 0)
end

local function isStatusLine(raw)
	local lower = raw:lower()
	return lower:find("autoplay", 1, true) ~= nil
		or lower:find("replay", 1, true) ~= nil
		or lower:find("spectat", 1, true) ~= nil
		or lower:find("autosync", 1, true) ~= nil
		or lower:find("sync changes reverted", 1, true) ~= nil
		or lower:find("can't sync while playing a course", 1, true) ~= nil
end

local function setSyncChangeDisplay(actor, label, hasStatus)
	actor:settext(label):visible(label ~= "")
	local parent = actor:GetParent()
	local bg = parent and parent:GetChild("SyncChangeBG")
	if not bg then return end
	if label == "" then
		bg:visible(false)
		return
	end

	local y = SCREEN_TOP + (hasStatus and 52 or 24)
	actor:xy(SCREEN_RIGHT - 24, y):halign(1)
	local width = actor:GetZoomedWidth() + 28
	local height = 22
	bg:visible(true):xy(SCREEN_RIGHT - 14 - width / 2, y)
	bg:GetChild("Border"):zoomto(width, height)
	bg:GetChild("Body"):zoomto(width - 2, height - 2)
	bg:GetChild("TopAccent"):xy(0, -height / 2 + 0.75):zoomto(width, 1.5)
	bg:GetChild("Pip"):xy(-width / 2 + 8, 0)
end

-- Custom formatting for adjustments text
local function formatAdjustmentsText(raw)
	if not raw or raw == "" then return "" end
	local kind, fromVal, toVal, dir = raw:match("^(.-) [Ff][Rr][Oo][Mm] (%S+) [Tt][Oo] (%S+) %([Nn][Oo][Tt][Ee][Ss] (.-)%)$")
	if kind and fromVal and toVal and dir then
		return string.format(lbl_adj_format, kind, fromVal, toVal, dir)
	end
	local skind, sfrom, sto, sdir = raw:match("^(.-) [Dd][Ee] (%S+) [Aa] (%S+) %([Nn][Oo][Tt][Aa][Ss] (.-)%)$")
	if skind and sfrom and sto and sdir then
		return string.format(lbl_adj_format, skind, sfrom, sto, sdir)
	end
	return raw
end

-- Tooltip panel geometry (larger text, placed in bottom right corner)
local panelW = 340
local panelH = 172
local padX   = 14
local padY   = 14
local entryW = panelW - 18
local entryH = 30

local function makeCornerBrackets(w, h, size, thickness)
	size = size or 8
	thickness = thickness or 1.5
	local halfW = w / 2
	local halfH = h / 2
	local function colorTick(self)
		self:diffuse(getAccent()):diffusealpha(0.85)
	end
	return Def.ActorFrame {
		-- Top Left
		Def.Quad { InitCommand = function(self) self:xy(-halfW + size / 2, -halfH + thickness / 2):zoomto(size, thickness); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(-halfW + thickness / 2, -halfH + size / 2):zoomto(thickness, size); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		-- Top Right
		Def.Quad { InitCommand = function(self) self:xy(halfW - size / 2, -halfH + thickness / 2):zoomto(size, thickness); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - thickness / 2, -halfH + size / 2):zoomto(thickness, size); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		-- Bottom Left
		Def.Quad { InitCommand = function(self) self:xy(-halfW + size / 2, halfH - thickness / 2):zoomto(size, thickness); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(-halfW + thickness / 2, halfH - size / 2):zoomto(thickness, size); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		-- Bottom Right
		Def.Quad { InitCommand = function(self) self:xy(halfW - size / 2, halfH - thickness / 2):zoomto(size, thickness); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
		Def.Quad { InitCommand = function(self) self:xy(halfW - thickness / 2, halfH - size / 2):zoomto(thickness, size); colorTick(self) end,
			ThemePrefChangedMessageCommand = function(self) colorTick(self) end },
	}
end

local function makeEntryRow(title, sub, keyText, keyW, yPos)
	local row = Def.ActorFrame {
		InitCommand = function(self) self:y(yPos) end,

		-- Row background card
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(entryW, entryH):diffuse(rowBg)
			end,
		},
		-- Subtle top and bottom borders
		Def.Quad {
			InitCommand = function(self)
				self:y(-entryH / 2 + 0.5):zoomto(entryW, 1):diffuse(rowBorder)
			end,
		},
		Def.Quad {
			InitCommand = function(self)
				self:y(entryH / 2 - 0.5):zoomto(entryW, 1):diffuse(rowBorder)
			end,
		},
		-- Left neon accent marker
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):xy(-entryW / 2, 0):zoomto(3, entryH - 2)
					:diffuse(getAccent()):diffusealpha(0.85)
			end,
			ThemePrefChangedMessageCommand = function(self)
				self:diffuse(getAccent()):diffusealpha(0.85)
			end,
		},
	}

	-- Action text block (larger font sizes)
	local hasSub = sub and sub ~= ""
	row[#row + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self)
			local textY = hasSub and -6 or 0
			self:halign(0):xy(-entryW / 2 + 10, textY):zoom(0.33)
				:diffuse(brightText):shadowlength(1):settext(title)
				:maxwidth((entryW - keyW - 20) / 0.33)
		end,
	}
	if hasSub then
		row[#row + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):xy(-entryW / 2 + 10, 7):zoom(0.24)
					:diffuse(subText):shadowlength(1):settext(sub)
					:maxwidth((entryW - keyW - 20) / 0.24)
			end,
		}
	end

	-- Decorated keycap badge
	local badgeX = entryW / 2 - 6 - keyW / 2
	local keycap = Def.ActorFrame {
		InitCommand = function(self) self:x(badgeX) end,
		-- Outer glowing border
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(keyW, 20):diffuse(getAccent()):diffusealpha(0.4)
			end,
			ThemePrefChangedMessageCommand = function(self)
				self:diffuse(getAccent()):diffusealpha(0.4)
			end,
		},
		-- Dark recessed keycap body
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(keyW - 2, 18):diffuse(color("0.09,0.11,0.16,0.95"))
			end,
		},
		-- Top highlight bevel
		Def.Quad {
			InitCommand = function(self)
				self:xy(0, -8):zoomto(keyW - 4, 1):diffuse(color("1,1,1,0.25"))
			end,
		},
		-- Keycap text (larger font)
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:zoom(0.30):diffuse(getAccent()):shadowlength(0):settext(keyText)
			end,
			ThemePrefChangedMessageCommand = function(self)
				self:diffuse(getAccent())
			end,
		},
	}
	row[#row + 1] = keycap

	return row
end

local function makeTipRow(yPos)
	local altClean = hold_alt:gsub("^%((.+)%)$", "%1")
	return Def.ActorFrame {
		InitCommand = function(self) self:y(yPos) end,

		-- "ALT" keycap badge
		Def.ActorFrame {
			InitCommand = function(self) self:x(-entryW / 2 + 22) end,
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(34, 16):diffuse(color("0.30,0.38,0.50,0.55"))
				end,
			},
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(32, 14):diffuse(color("0.08,0.10,0.14,0.95"))
				end,
			},
			Def.Quad {
				InitCommand = function(self)
					self:xy(0, -6):zoomto(30, 1):diffuse(color("1,1,1,0.22"))
				end,
			},
			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:zoom(0.26):diffuse(color("0.85,0.90,0.98,1")):shadowlength(0):settext("ALT")
				end,
			},
		},

		-- Hint text (larger font)
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):xy(-entryW / 2 + 44, 0):zoom(0.25)
					:diffuse(subText):shadowlength(1):settext(altClean)
					:maxwidth((entryW - 50) / 0.25)
			end,
		},
	}
end

local function makeHeader(yPos)
	return Def.ActorFrame {
		InitCommand = function(self) self:y(yPos) end,

		-- Status indicator dot
		Def.Quad {
			InitCommand = function(self)
				self:xy(-panelW / 2 + 15, 0):zoomto(5, 5):diffuse(getAccent())
			end,
			ThemePrefChangedMessageCommand = function(self)
				self:diffuse(getAccent())
			end,
		},

		-- Main title
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):xy(-panelW / 2 + 25, 0):zoom(0.30)
					:diffuse(mainText):shadowlength(1):settext("AUDIO SYNC")
			end,
		},

		-- Subtitle tag on right
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(1):xy(panelW / 2 - 15, 0):zoom(0.24)
					:diffuse(getAccent()):diffusealpha(0.75):shadowlength(0):settext("CALIBRATION")
			end,
			ThemePrefChangedMessageCommand = function(self)
				self:diffuse(getAccent()):diffusealpha(0.75)
			end,
		},
	}
end

-- Tooltip panel: placed in the bottom right corner with half-alpha (0.5 opacity)
local helpPanel = Def.ActorFrame {
	Name = "HelpPanel",
	InitCommand = function(self)
		local tx = SCREEN_RIGHT - panelW / 2 - padX
		local ty = SCREEN_BOTTOM - panelH / 2 - padY
		self:xy(tx, ty):diffusealpha(0):visible(false)
	end,
	ShowCommand = function(self)
		local tx = SCREEN_RIGHT - panelW / 2 - padX
		local ty = SCREEN_BOTTOM - panelH / 2 - padY
		self:y(ty):visible(true):stoptweening()
		-- Half-alpha (0.5) when active
		if self:GetDiffuseAlpha() < 0.05 then
			self:x(tx + 25):diffusealpha(0)
			self:decelerate(0.25):x(tx):diffusealpha(0.5)
		else
			self:decelerate(0.1):x(tx):diffusealpha(0.5)
		end
		self:sleep(6)
		self:accelerate(0.25):x(tx + 25):diffusealpha(0)
		self:queuecommand("HideSelf")
	end,
	HideSelfCommand = function(self)
		self:visible(false)
	end,
	HideCommand = function(self)
		self:stoptweening():visible(false):diffusealpha(0)
	end,

	-- Outer border / glow
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(panelW, panelH):diffuse(borderColor)
		end,
	},
	-- Deep OLED background
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(panelW - 2, panelH - 2):diffuse(cardBg)
		end,
	},
	-- Glowing top accent stripe
	Def.Quad {
		InitCommand = function(self)
			self:y(-panelH / 2 + 1):zoomto(panelW, 2):diffuse(getAccent()):diffusealpha(0.9)
		end,
		ThemePrefChangedMessageCommand = function(self)
			self:diffuse(getAccent()):diffusealpha(0.9)
		end,
	},
	-- Corner brackets
	makeCornerBrackets(panelW, panelH, 8, 1.5),

	-- Header
	makeHeader(-panelH / 2 + 16),

	-- Header divider line
	Def.Quad {
		InitCommand = function(self)
			self:xy(0, -panelH / 2 + 30):zoomto(panelW - 24, 1):diffuse(color("1,1,1,0.06"))
		end,
	},

	-- Entries (larger decorated cards)
	makeEntryRow(revertTitle, revertSub, "F4", 42, -35),
	makeEntryRow(songTitle, songSub, "F11 / F12", 82, 0),
	makeEntryRow(machineTitle, machineSub, "Shift + F11/12", 114, 35),

	-- Tip divider line
	Def.Quad {
		InitCommand = function(self)
			self:xy(0, panelH / 2 - 30):zoomto(panelW - 24, 1):diffuse(color("1,1,1,0.06"))
		end,
	},

	-- Tip row
	makeTipRow(panelH / 2 - 16),
}

-- Position the adjustments card below the status card when both are visible.
local function updateAdjustmentsPosition(adj, adjBg, hasStatus)
	local adjY = hasStatus and (SCREEN_TOP + 52) or (SCREEN_TOP + 24)
	adj:xy(SCREEN_RIGHT - 24, adjY):halign(1)
	if adjBg then
		local tw = adj:GetZoomedWidth()
		local bw = tw + 24
		local bh = math.max(22, adj:GetZoomedHeight() + 8)
		local bx = SCREEN_RIGHT - 14 - bw / 2
		adjBg:xy(bx, adjY)
		adjBg:GetChild("Border"):zoomto(bw, bh)
		adjBg:GetChild("Body"):zoomto(bw - 2, bh - 2)
		adjBg:GetChild("TopAccent"):xy(0, -bh / 2 + 0.75):zoomto(bw, 1.5)
		adjBg:GetChild("AccentBar"):xy(-bw / 2 + 1.5, 0):zoomto(3, bh - 4)
	end
end

local t = Def.ActorFrame {
	-- Tooltip placed in bottom right corner (half-alpha)
	helpPanel,

	-- =========================================================================
	-- TOP RIGHT DECORATED HUD LABELS (Status & Adjustments)
	-- =========================================================================

	-- Status Badge Background (Decorated pill for AutoPlay / Replay / AutoSync)
	Def.ActorFrame {
		Name = "StatusBG",
		InitCommand = function(self)
			self:visible(false)
		end,
		Def.Quad {
			Name = "Border",
			InitCommand = function(self) self:diffuse(borderColor) end,
		},
		Def.Quad {
			Name = "Body",
			InitCommand = function(self) self:diffuse(cardBg) end,
		},
		Def.Quad {
			Name = "TopAccent",
			InitCommand = function(self) self:diffuse(getAccent()):diffusealpha(0.85) end,
			ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()):diffusealpha(0.85) end,
		},
		Def.Quad {
			Name = "Pip",
			InitCommand = function(self) self:zoomto(4, 4):diffuse(getAccent()) end,
			ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end,
		},
	},

	-- Actual Status label (e.g. "AutoPlayCPU", "AutoSync Song", "Sync changes reverted.")
	-- Moved to top right corner, rendered with custom labels inside a decorated badge
	LoadFont("Common Large") .. {
		Name = "Status",
		Font = "ScreenSyncOverlay status",
		InitCommand = function(self)
			ActorUtil.LoadAllCommands(self, "ScreenSyncOverlay")
			self:zoom(0.32):diffuse(getAccent()):strokecolor(color("#07110F")):shadowlength(0)
			self:xy(SCREEN_RIGHT - 24, SCREEN_TOP + 24):halign(1)
		end,
		ThemePrefChangedMessageCommand = function(self)
			self:diffuse(getAccent())
		end,
		SetStatusCommand = function(self, param)
			local raw = param.text or ""
			local statusLines = {}
			local changeLines = {}
			for line in raw:gmatch("[^\r\n]+") do
				if isStatusLine(line) then
					table.insert(statusLines, getCustomStatusLabel(line))
				else
					table.insert(changeLines, line)
				end
			end
			local statusLabel = table.concat(statusLines, "\n")
			setStatusDisplay(self, statusLabel)

			local parent = self:GetParent()
			local adj = parent and parent:GetChild("Adjustments")
			local adjBg = parent and parent:GetChild("AdjustmentsBG")
			local syncChange = parent and parent:GetChild("SyncChange")
			local syncText = formatAdjustmentsText(table.concat(changeLines, "\n"))
			if syncChange then
				setSyncChangeDisplay(syncChange, syncText, statusLabel ~= "")
			end

			if adj and adj:GetVisible() and adj:GetText() ~= "" then
				updateAdjustmentsPosition(adj, adjBg, statusLabel ~= "")
			end
		end,
		HideCommand = function(self)
			self:settext("")
			self:visible(false)
			local parent = self:GetParent()
			local bg = parent and parent:GetChild("StatusBG")
			if bg then bg:visible(false) end
			local syncChange = parent and parent:GetChild("SyncChange")
			local syncChangeBg = parent and parent:GetChild("SyncChangeBG")
			if syncChange then syncChange:settext(""):visible(false) end
			if syncChangeBg then syncChangeBg:visible(false) end
			local adj = parent and parent:GetChild("Adjustments")
			local adjBg = parent and parent:GetChild("AdjustmentsBG")
			if adj and adj:GetVisible() and adj:GetText() ~= "" then
				updateAdjustmentsPosition(adj, adjBg, false)
			end
		end,
	},

	-- Separate card for offset-change lines appended to SetStatus by Etterna.
	Def.ActorFrame {
		Name = "SyncChangeBG",
		InitCommand = function(self) self:visible(false) end,
		Def.Quad { Name = "Border", InitCommand = function(self) self:diffuse(borderColor) end },
		Def.Quad { Name = "Body", InitCommand = function(self) self:diffuse(cardBg) end },
		Def.Quad {
			Name = "TopAccent",
			InitCommand = function(self) self:diffuse(getAccent()):diffusealpha(0.85) end,
			ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()):diffusealpha(0.85) end,
		},
		Def.Quad {
			Name = "Pip",
			InitCommand = function(self) self:zoomto(4, 4):diffuse(getAccent()) end,
			ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end,
		},
	},
	LoadFont("Common Large") .. {
		Name = "SyncChange",
		Font = "ScreenSyncOverlay status",
		InitCommand = function(self)
			self:zoom(0.32):diffuse(getAccent()):strokecolor(color("#07110F")):shadowlength(0)
		end,
		ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()) end,
	},

	-- Adjustments card background
	Def.ActorFrame {
		Name = "AdjustmentsBG",
		InitCommand = function(self) self:visible(false) end,
		Def.Quad {
			Name = "Border",
			InitCommand = function(self) self:diffuse(borderColor) end,
		},
		Def.Quad {
			Name = "Body",
			InitCommand = function(self) self:diffuse(cardBg) end,
		},
		Def.Quad {
			Name = "TopAccent",
			InitCommand = function(self) self:diffuse(getAccent()):diffusealpha(0.85) end,
			ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()):diffusealpha(0.85) end,
		},
		Def.Quad {
			Name = "AccentBar",
			InitCommand = function(self) self:diffuse(getAccent()):diffusealpha(0.85) end,
			ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()):diffusealpha(0.85) end,
		},
	},

	-- Custom formatted sync adjustment text
	LoadFont("Common Large") .. {
		Name = "Adjustments",
		Font = "ScreenSyncOverlay adjustments",
		InitCommand = function(self)
			ActorUtil.LoadAllCommands(self, "ScreenSyncOverlay")
			self:zoom(0.28):diffuse(brightText):strokecolor(color("#07110F")):shadowlength(0)
			self:xy(SCREEN_RIGHT - 24, SCREEN_TOP + 52):halign(1)
		end,
		SetAdjustmentsCommand = function(self, param)
			local raw = param.text or ""
			local formatted = formatAdjustmentsText(raw)
			local isVis = param.visible and formatted ~= ""
			self:visible(isVis):settext(formatted)

			local parent = self:GetParent()
			local statusChild = parent and parent:GetChild("Status")
			local hasStatus = statusChild and statusChild:GetVisible() and statusChild:GetText() ~= ""
			local adjBg = parent and parent:GetChild("AdjustmentsBG")

			if isVis then
				if SCREEN_WIDTH / SCREEN_HEIGHT < 5.02 / 4 then
					self:zoom(0.25 * sh_r):bounceend(0.05):zoom(math.min(1, 0.55 * sh_r) / 2)
				elseif SCREEN_WIDTH / SCREEN_HEIGHT < 4.02 / 3 then
					self:zoom(0.25 * sh_r):bounceend(0.05):zoom(math.min(1, 0.65 * sh_r) / 2)
				else
					self:zoom(0.25 * sh_r):bounceend(0.05):zoom(math.min(1, 0.85 * sh_r) / 2)
				end
				showadj = false
				if adjBg then adjBg:visible(true) end
				updateAdjustmentsPosition(self, adjBg, hasStatus)
			elseif not param.visible then
				showadj = true
				if adjBg then adjBg:visible(false) end
			end
		end,
		HideCommand = function(self)
			self:settext("")
			self:visible(false)
			local parent = self:GetParent()
			local adjBg = parent and parent:GetChild("AdjustmentsBG")
			if adjBg then adjBg:visible(false) end
		end,
	},

	-- Legacy compatibility dummies for external scripts that might query GetChild
	Def.Quad {
		Name = "quad",
		InitCommand = function(self) self:visible(false) end,
	},
	Def.BitmapText {
		Font = "Common Normal",
		Name = "help_text",
		InitCommand = function(self) self:visible(false) end,
	},
}

return t
