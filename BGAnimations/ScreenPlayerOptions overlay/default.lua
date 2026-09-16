--- Holographic Void: ScreenPlayerOptions Overlay
-- Shows tab bar (Player Options / Quick Theme Options / Effect Options),
-- effective scroll speed display, and noteskin preview.
-- Uses SpeedChoiceChangedMessage to update in real-time like Til Death.

local t = Def.ActorFrame {
	Name = "PlayerOptionsOverlay",
}

-- ============================================================
-- MOD ICONS (top-left)
-- Shows shorthand for currently active mods.
-- ============================================================
local modShorthands = {
	-- Turn
	["Mirror"] = "MIR", ["Back"] = "BAK", ["Left"] = "LFT", ["Right"] = "RGT",
	["Shuffle"] = "SHU", ["SoftShuffle"] = "SSH", ["SuperShuffle"] = "XSH",
	-- Appearance
	["Hidden"] = "HID", ["Sudden"] = "SUD", ["Stealth"] = "STL", ["Blink"] = "BLK", ["RandomVanish"] = "RVN",
	-- Hide
	["Dark"] = "DRK", ["Blind"] = "BLN", ["Cover"] = "COV",
	-- Remove
	["NoMines"] = "NOM", ["NoHolds"] = "NOH", ["NoRolls"] = "NOR", ["NoLifts"] = "NOL", ["NoFakes"] = "NOF",
	-- Other
	["Reverse"] = "REV", ["Mines"] = "MNS", ["HoldReleases"] = "HRE",
}

local function formatSpeedMode(mode, speed)
	if mode == "x" then
		return string.format("%.2fx", speed / 100)
	end
	return mode .. tostring(speed)
end

local function formatRateValue(rate)
	local r = string.format("%.2f", rate):gsub("%.?0+$", "") .. "x"
	if r == "1x" then r = "1.0x" end
	if r == "2x" then r = "2.0x" end
	return r
end

local function hasAssistEnabled(po, modStr)
	if po then
		if po.AssistClap and po:AssistClap() then return true end
		if po.AssistTick and po:AssistTick() then return true end
	end
	return string.find(modStr, "AssistClap") or string.find(modStr, "AssistTick") or string.find(modStr, "AutoPlay")
end

t[#t + 1] = Def.ActorFrame {
	Name = "ModIcons",
	InitCommand = function(self)
		self:xy(SCREEN_LEFT + 18, 18)
		self._lastModStr = ""
		self._lastExtra = ""
		local speed, mode = GetSpeedModeAndValueFromPoptions(PLAYER_1)
		self._speed = speed
		self._speedMode = mode
		self._rate = getCurRateValue()
	end,
	OnCommand = function(self)
		self:SetUpdateFunction(function(self)
			self:playcommand("Update")
		end)
	end,

	UpdateCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		local ps = GAMESTATE:GetPlayerState(PLAYER_1)
		local po = ps:GetPlayerOptions("ModsLevel_Preferred")
		local modStr = ps:GetPlayerOptionsString("ModsLevel_Preferred")

		local accent = (HVColor and HVColor.Accent or color("#5ABAFF"))
		local dim = color("0.4,0.4,0.4,1")
		local warn = color("#CF9898")

		-- Tentative values (from screen rows if available)
		local tLife = GetLifeDifficulty()
		local tJudge = GetTimingDifficulty()
		local tFail = po:FailSetting()
		local tAssist = hasAssistEnabled(po, modStr)
		local tTurn = nil -- For Mirror/etc
		local tSpeedMode = self._speedMode
		local tSpeed = self._speed
		local tRate = self._rate

		if screen and screen.GetNumRows then
			for i = 0, screen:GetNumRows() - 1 do
				local row = screen:GetOptionRow(i)
				if row and row.GetName and row.GetChoice then
					local rName = row:GetName():lower()
					local choice = row:GetChoice(PLAYER_1)
					
					-- Map rows by name
					if choice then
						if rName == "life" then
							tLife = choice + 1
						elseif rName == "judge" then
							tJudge = choice + 4
						elseif rName == "speed" and row.CurValues and row.CurValues[PLAYER_1] then
							tSpeedMode = row.CurValues[PLAYER_1].mode
							tSpeed = row.CurValues[PLAYER_1].speed
						elseif rName == "ratelist" then
							tRate = notShit.round(0.05 + choice * 0.05, 2)
						elseif rName == "fail" then
							if choice == 0 then tFail = "FailType_Immediate"
							elseif choice == 1 then tFail = "FailType_EndOfSong"
							elseif choice == 2 then tFail = "FailType_Off" end
						elseif rName == "assist" then
							tAssist = (choice ~= nil)
						elseif rName == "mirror" or rName == "turn" then
							if choice > 0 then tTurn = "MIR" end -- Simplify for icon
						end
					end
				end
			end
		end

		local speedActor = self:GetChild("Speed")
		speedActor:settext(formatSpeedMode(tSpeedMode, tSpeed))
		speedActor:diffuse(accent)

		local rateActor = self:GetChild("Rate")
		rateActor:settext(formatRateValue(tRate))
		rateActor:diffuse(accent)

		-- Life Difficulty
		local lifeKey = "L7"
		if tLife <= 1 then
			lifeKey = "L1"
		elseif tLife == 2 then
			lifeKey = "L2"
		elseif tLife == 3 then
			lifeKey = "L3"
		elseif tLife == 4 then
			lifeKey = "L4"
		elseif tLife == 5 then
			lifeKey = "L5"
		elseif tLife == 6 then
			lifeKey = "L6"
		end
		local lifeColor = (HVColor and HVColor.GetLifeBarColor and HVColor.GetLifeBarColor(lifeKey))
			or color("#FFFFFF")
		
		local lifeActor = self:GetChild("Life")
		lifeActor:settext(string.format("L%d", tLife))
		lifeActor:diffuse(lifeColor)

		-- Judge Difficulty
		local judgeActor = self:GetChild("Judge")
		judgeActor:settext(string.format("J%d", tJudge))
		judgeActor:diffuse(accent)

		-- Fail Setting (Always display)
		local failText = "F:IMM"
		if tFail == "FailType_Off" then failText = "F:OFF"
		elseif tFail == "FailType_EndOfSong" then failText = "F:END"
		end
		local failActor = self:GetChild("Fail")
		failActor:settext(failText)
		failActor:diffuse(tFail == "FailType_Immediate" and accent or warn)

		-- Assist (Always display AST, colored if active)
		local assistActor = self:GetChild("Assist")
		assistActor:settext("AST")
		assistActor:diffuse(tAssist and accent or dim)

		-- Existing mod shorthands
		local active = {}
		if tTurn then table.insert(active, tTurn) end
		
		for mod, short in pairs(modShorthands) do
			if mod ~= "Mirror" and string.find(modStr, mod) then
				table.insert(active, short)
			end
		end
		local receptorSize = tonumber(ThemePrefs.Get("HV_Mini")) or 100
		if math.abs(receptorSize - 100) > 0.001 then
			table.insert(active, "MN" .. math.round(receptorSize))
		end

		local modsText = table.concat(active, "  ")
		self:GetChild("Separator"):visible(#active > 0)
		
		local modsActor = self:GetChild("Mods")
		modsActor:settext(modsText)
		modsActor:diffuse(accent)
	end,

	MenuLeftMessageCommand = function(self) self:playcommand("Update") end,
	MenuRightMessageCommand = function(self) self:playcommand("Update") end,
	MenuUpMessageCommand = function(self) self:playcommand("Update") end,
	MenuDownMessageCommand = function(self) self:playcommand("Update") end,
	ChoiceChangedMessageCommand = function(self) self:playcommand("Update") end,
	SpeedChoiceChangedMessageCommand = function(self, param)
		if param.pn == PLAYER_1 then
			self._speed = param.speed
			self._speedMode = param.mode
			self:playcommand("Update")
		end
	end,
	RateListOptionChangedMessageCommand = function(self)
		self:finishtweening():sleep(0.01):queuecommand("Update")
	end,
	RateListOptionSavedMessageCommand = function(self, param)
		self._rate = param and param.rate or getCurRateValue()
		self:playcommand("Update")
	end,
	CurrentRateChangedMessageCommand = function(self)
		self._rate = getCurRateValue()
		self:playcommand("Update")
	end,

	-- Prefix Icons (L, J, F, AST)
	LoadFont("Common Normal") .. { Name = "Speed", InitCommand = function(self) self:zoom(0.4):halign(0) end },
	LoadFont("Common Normal") .. { Name = "Rate", InitCommand = function(self) self:x(42):zoom(0.4):halign(0) end },
	LoadFont("Common Normal") .. { Name = "Life", InitCommand = function(self) self:x(82):zoom(0.4):halign(0) end },
	LoadFont("Common Normal") .. { Name = "Judge", InitCommand = function(self) self:x(110):zoom(0.4):halign(0):diffuse(HVColor and HVColor.Accent or color("#5ABAFF")) end },
	LoadFont("Common Normal") .. { Name = "Fail", InitCommand = function(self) self:x(138):zoom(0.4):halign(0):diffuse(color("#CF9898")) end },
	LoadFont("Common Normal") .. { Name = "Assist", InitCommand = function(self) self:x(182):zoom(0.4):halign(0):diffuse(HVColor and HVColor.Accent or color("#5ABAFF")) end },
	
	-- Separator
	LoadFont("Common Normal") .. { 
		Name = "Separator", 
		InitCommand = function(self) self:x(217):zoom(0.4):halign(0):settext("|"):diffuse(color("0.4,0.4,0.4,1")) end 
	},

	-- Main Mods
	LoadFont("Common Normal") .. { 
		Name = "Mods", 
		InitCommand = function(self) self:x(232):zoom(0.4):halign(0):diffuse(HVColor and HVColor.Accent or color("#5ABAFF")) end 
	}
}

-- ============================================================
-- SCREEN NAME DISPLAY (top-right)
-- Shows only the current screen's name (tab label).
-- ============================================================
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "ScreenNameDisplay",
	InitCommand = function(self)
		self:xy(SCREEN_RIGHT - 18, 18):zoom(0.5):halign(1):valign(0.5)
			:shadowlength(0)
			:diffuse(HVColor and HVColor.Accent or color("#5ABAFF"))
	end,
	OnCommand = function(self)
		local key = HV and HV.GetCurrentPlayerOptionsTabKey() or "Main"
		local label = "Player Options"
		if HV and HV.PlayerOptionsTabs then
			for _, tab in ipairs(HV.PlayerOptionsTabs) do
				if tab.key == key then
					label = tab.label
					break
				end
			end
		end
		self:settext(label:upper())
	end,
}

-- Separator line under header area
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(0, 30):halign(0):valign(0)
			:zoomto(SCREEN_WIDTH, 1)
			:diffuse(HVColor and HVColor.TextDim or color("#444466"))
			:diffusealpha(0.3)
	end,
}

-- Cache song BPMs at screen load time
local bpms = {}
if GAMESTATE:GetCurrentSong() then
	bpms = GAMESTATE:GetCurrentSong():GetDisplayBpms(true)
	bpms[1] = math.round(bpms[1])
	bpms[2] = math.round(bpms[2])
end

-- ============================================================
-- SPEED DISPLAY (top-left, above the options rows)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "SpeedDisplay",
	InitCommand = function(self)
		self:xy(SCREEN_LEFT + 16, 50)
	end,

	-- Label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.35):diffuse(HVColor.TextDim):halign(0)
			self:settext(THEME:GetString("ScreenPlayerOptions", "Speed"))
		end
	},

	-- Value (effective BPM)
	LoadFont("Common Normal") .. {
		Name = "SpeedValue",
		InitCommand = function(self)
			self:y(18):zoom(0.65):diffuse(HVColor.Accent):halign(0)
		end,
		BeginCommand = function(self)
			local speed, mode = GetSpeedModeAndValueFromPoptions(PLAYER_1)
			self:playcommand("SpeedChoiceChanged", {pn = PLAYER_1, mode = mode, speed = speed})
		end,
		RateListOptionChangedMessageCommand = function(self)
			self:finishtweening():sleep(0.01):queuecommand("DelayedUpdate")
		end,
		RateListOptionSavedMessageCommand = function(self)
			self:finishtweening():sleep(0.01):queuecommand("DelayedUpdate")
		end,
		DelayedUpdateCommand = function(self)
			self:playcommand("SpeedChoiceChanged", {pn = PLAYER_1, mode = self._mode, speed = self._speed})
		end,
		SpeedChoiceChangedMessageCommand = function(self, param)
			self._mode = param.mode
			self._speed = param.speed
			if param.pn == PLAYER_1 then
				local text = ""
				if param.mode == "x" then
					if not bpms[1] then
						text = "???"
					elseif bpms[1] == bpms[2] then
						text = tostring(math.round(bpms[1] * getCurRateValue() * param.speed / 100))
					else
						text = string.format("%d - %d",
							math.round(bpms[1] * getCurRateValue() * param.speed / 100),
							math.round(bpms[2] * getCurRateValue() * param.speed / 100))
					end
				elseif param.mode == "C" then
					text = tostring(param.speed)
				else
					-- mmod
					if not bpms[1] then
						text = "??? - " .. param.speed
					elseif bpms[1] == bpms[2] then
						text = tostring(param.speed)
					else
						local factor = param.speed / bpms[2]
						text = string.format("%d - %d", math.round(bpms[1] * factor), param.speed)
					end
				end
				self:settext(text)
			end
		end
	}
}

-- ============================================================
-- NOTESKIN PREVIEW
-- ============================================================
local widescreen = GetScreenAspectRatio() > 1.7

local NSPreviewSize   = 0.5
local NSPreviewX      = 20
local NSPreviewY      = 125
local NSPreviewXSpan  = 35
local NSPreviewReceptorY = -32
local OptionRowHeight = 35
local NoteskinRow     = 0
local NSDirTable      = GameToNSkinElements()

local function NSkinPreviewWrapper(dir, ele)
	return Def.ActorFrame {
		InitCommand = function(self)
			self:zoom(NSPreviewSize)
		end,
		LoadNSkinPreview("Get", dir, ele, PLAYER_1)
	}
end

local function NSkinPreviewExtraTaps()
	local out = Def.ActorFrame {}
	for i = 1, #NSDirTable do
		if i ~= 2 then
			out[#out + 1] = Def.ActorFrame {
				Def.ActorFrame {
					InitCommand = function(self)
						self:x(NSPreviewXSpan * (i - 1))
					end,
					NSkinPreviewWrapper(NSDirTable[i], "Tap Note")
				},
				Def.ActorFrame {
					InitCommand = function(self)
						self:x(NSPreviewXSpan * (i - 1)):y(NSPreviewReceptorY)
					end,
					NSkinPreviewWrapper(NSDirTable[i], "Receptor")
				}
			}
		end
	end
	return out
end

t[#t + 1] = Def.ActorFrame {
	OnCommand = function(self)
		self:xy(NSPreviewX, NSPreviewY)
		
		local top = SCREENMAN:GetTopScreen()
		if top and top.GetNumRows then
			for i = 0, top:GetNumRows() - 1 do
				local row = top:GetOptionRow(i)
				if row and row:GetName() == "NoteSk" then
					NoteskinRow = i
				end
			end
		end

		self:SetUpdateFunction(function(self)
			local currentTop = SCREENMAN:GetTopScreen()
			if currentTop and currentTop.GetCurrentRowIndex then
				local row = currentTop:GetCurrentRowIndex(PLAYER_1)
				if row then
					local pos = 0
					if row > 4 then
						pos = NSPreviewY + NoteskinRow * OptionRowHeight -
						      (row - 4) * OptionRowHeight
					else
						pos = NSPreviewY + NoteskinRow * OptionRowHeight
					end
					self:y(pos)
					self:visible(NoteskinRow - row > -5 and NoteskinRow - row < 7)
				end
			end
		end)
	end,

	-- Middle column (always shown)
	Def.ActorFrame {
		InitCommand = function(self)
			if widescreen then
				self:x(NSPreviewXSpan)
			else
				self:x(NSPreviewXSpan / 4)
			end
		end,
		NSkinPreviewWrapper(NSDirTable[2], "Tap Note")
	},
	Def.ActorFrame {
		InitCommand = function(self)
			if widescreen then
				self:x(NSPreviewXSpan)
			else
				self:x(NSPreviewXSpan / 4)
			end
			self:y(NSPreviewReceptorY)
		end,
		NSkinPreviewWrapper(NSDirTable[2], "Receptor")
	}
}

-- Extra columns on widescreen
if widescreen then
	t[#t][#(t[#t]) + 1] = NSkinPreviewExtraTaps()
end

return t
