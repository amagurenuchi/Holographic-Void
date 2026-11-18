--- Holographic Void: Multiplayer Scoreboard (ScreenNetEvaluation)
-- Redesigned evaluation leaderboard displaying online player scores with:
--   - Ranked player cards with gold/silver/bronze medals
--   - Wife3 accuracy, grade badge, and combo
--   - Click-to-inspect player score details & offset plot
--   - Holographic Void signature card styling with accent highlights

local lines = 12
local multiscores = {}
local rowW = 310
local rowH = 34
local rowGap = 4

local function getAccent()
	return (HVColor and HVColor.Accent) or color("#5ABAFF")
end

local Colors = {
	cardBg = color("0.05,0.06,0.09,0.92"),
	headerBg = color("0.07,0.08,0.12,0.96"),
	rowBg = color("0.08,0.09,0.13,0.75"),
	rowSelected = color("0.12,0.16,0.25,0.95"),
	border = color("0.18,0.22,0.28,0.75"),
	dimText = color("0.45,0.48,0.55,1"),
	subText = color("0.65,0.70,0.78,1"),
	mainText = color("0.85,0.88,0.92,1"),
	brightText = color("1,1,1,1"),
	gold = color("#FFD700"),
	silver = color("#C0C0C0"),
	bronze = color("#CD7F32"),
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

local function SetActivePlayer(localIndex)
	local screen = SCREENMAN:GetTopScreen()
	if not screen or not multiscores[localIndex] then return end
	if screen.SetCurrentPlayerByName then
		screen:SetCurrentPlayerByName(multiscores[localIndex].user)
	end
end

local sortFunction = function(first, second)
	if not first or not first.highscore then return false end
	if not second or not second.highscore then return true end
	return first.highscore:GetWifeScore() > second.highscore:GetWifeScore()
end

local function updateScoreBoard(self)
	local screen = SCREENMAN:GetTopScreen()
	if not screen then return end

	local selectedUserName = false
	if multiscores and screen.GetCurrentPlayer then
		local cur = screen:GetCurrentPlayer()
		for i = 1, #multiscores do
			if cur == multiscores[i].idx then
				selectedUserName = multiscores[i].user
			end
		end
	end
	selectedUserName = selectedUserName or NSMAN:GetLoggedInUsername()

	multiscores = NSMAN:GetEvalScores() or {}
	for i = 1, #multiscores do
		multiscores[i].idx = i
	end
	table.sort(multiscores, sortFunction)

	local rowsChild = self:GetChild("Rows")
	for i = 1, lines do
		local child = rowsChild and rowsChild:GetChild("Row" .. i)
		if child then
			child:playcommand("UpdateNetScore")
		end
		if selectedUserName and multiscores[i] and multiscores[i].user == selectedUserName then
			SetActivePlayer(i)
		end
	end

end

local function makeScoreRow(i)
	return Def.ActorFrame {
		Name = "Row" .. i,
		InitCommand = function(self)
			self:xy(0, (i - 1) * (rowH + rowGap))
			self:visible(false)
		end,
		UpdateNetScoreCommand = function(self)
			local scoreData = multiscores[i]
			self:visible(scoreData ~= nil)
			if not scoreData then return end

			local hs = scoreData.highscore
			local screen = SCREENMAN:GetTopScreen()
			local curPlayer = screen and screen.GetCurrentPlayer and screen:GetCurrentPlayer()
			local isSelected = (curPlayer == scoreData.idx)
			local localUser = NSMAN:GetLoggedInUsername() or ""
			local isMe = (localUser ~= "" and scoreData.user:lower() == localUser:lower())

			local bg = self:GetChild("Bg")
			local brackets = self:GetChild("Brackets")
			local rankActor = self:GetChild("Rank")
			local userActor = self:GetChild("User")
			local wifeActor = self:GetChild("Wife")
			local gradeActor = self:GetChild("Grade")
			local comboActor = self:GetChild("Combo")
			local judgeActor = self:GetChild("Judge")

			bg:diffuse(isSelected and Colors.rowSelected or Colors.rowBg)
			brackets:visible(isSelected)

			-- Rank medal / color
			rankActor:settextf("#%d", i)
			if i == 1 then rankActor:diffuse(Colors.gold)
			elseif i == 2 then rankActor:diffuse(Colors.silver)
			elseif i == 3 then rankActor:diffuse(Colors.bronze)
			else rankActor:diffuse(isSelected and getAccent() or Colors.dimText)
			end

			-- Username
			userActor:settext(scoreData.user)
			userActor:diffuse(isMe and getAccent() or Colors.brightText)

			-- Wife%
			local perc = hs:GetWifeScore() * 100
			if perc > 99.65 then
				wifeActor:settextf("%05.4f%%", notShit.floor(perc, 4))
			else
				wifeActor:settextf("%05.2f%%", notShit.floor(perc, 2))
			end

			-- Grade badge
			local gradeEnum = hs:GetWifeGrade()
			local gradeStr = ToEnumShortString(gradeEnum)
			local gradeName = (HV and HV.GetGradeName and HV.GetGradeName(gradeStr)) or gradeStr
			local gradeColor = (HVColor and HVColor.GetGradeColor and HVColor.GetGradeColor(gradeStr)) or Colors.brightText
			gradeActor:settext(gradeName):diffuse(gradeColor)

			-- Combo
			comboActor:settextf("x%d", hs:GetMaxCombo())

			-- Judgment counts
			local w1 = hs:GetTapNoteScore("TapNoteScore_W1") or 0
			local w2 = hs:GetTapNoteScore("TapNoteScore_W2") or 0
			local w3 = hs:GetTapNoteScore("TapNoteScore_W3") or 0
			local miss = hs:GetTapNoteScore("TapNoteScore_Miss") or 0
			judgeActor:settextf("%d / %d / %d / %d", w1, w2, w3, miss)
		end,
		UpdateNetEvalStatsMessageCommand = function(self)
			self:playcommand("UpdateNetScore")
		end,

		-- Row background
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(rowW, rowH):diffuse(Colors.rowBg)
			end
		},
		-- Left accent edge line
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(2, rowH):diffuse(getAccent()):diffusealpha(0.6)
			end,
			ThemePrefChangedMessageCommand = function(self) self:diffuse(getAccent()):diffusealpha(0.6) end
		},
		-- 1px Border
		Def.ActorFrame {
			Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(rowW, 1):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(0):valign(1):xy(0, rowH):zoomto(rowW, 1):diffuse(Colors.border) end },
			Def.Quad { InitCommand = function(self) self:halign(1):valign(0):xy(rowW, 0):zoomto(1, rowH):diffuse(Colors.border) end },
		},
		-- Selected Corner Brackets
		Def.ActorFrame {
			Name = "Brackets",
			cornerTicks(rowW, rowH, 5, 1.5)
		},

		-- Rank Number
		LoadFont("Common Normal") .. {
			Name = "Rank",
			InitCommand = function(self)
				self:xy(8, 10):halign(0):valign(0.5):zoom(0.28):diffuse(Colors.dimText)
			end
		},

		-- Username
		LoadFont("Common Normal") .. {
			Name = "User",
			InitCommand = function(self)
				self:xy(34, 10):halign(0):valign(0.5):zoom(0.30):diffuse(Colors.brightText):maxwidth(120 / 0.30)
			end
		},

		-- Wife%
		LoadFont("Common Normal") .. {
			Name = "Wife",
			InitCommand = function(self)
				self:xy(160, 10):halign(0):valign(0.5):zoom(0.28):diffuse(Colors.mainText)
			end
		},

		-- Grade Badge
		LoadFont("Common Normal") .. {
			Name = "Grade",
			InitCommand = function(self)
				self:xy(rowW - 54, 10):halign(1):valign(0.5):zoom(0.30)
			end
		},

		-- Max Combo
		LoadFont("Common Normal") .. {
			Name = "Combo",
			InitCommand = function(self)
				self:xy(rowW - 8, 10):halign(1):valign(0.5):zoom(0.24):diffuse(Colors.subText)
			end
		},

		-- Mini Judgment Tally
		LoadFont("Common Normal") .. {
			Name = "Judge",
			InitCommand = function(self)
				self:xy(34, 24):halign(0):valign(0.5):zoom(0.22):diffuse(Colors.dimText)
			end
		},

		-- Click to inspect player
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(rowW, rowH):diffusealpha(0)
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and i <= #multiscores then
					SetActivePlayer(i)
				end
			end
		}
	}
end

local t = Def.ActorFrame {
	Name = "MPScoreBoard",
	BeginCommand = function(self)
		pcall(function()
			local s = SCREENMAN:GetTopScreen()
			if s and MPinput then s:AddInputCallback(MPinput) end
		end)
		self:playcommand("UpdateBoard")
	end,
	UpdateBoardCommand = function(self)
		updateScoreBoard(self)
	end,
	NewMultiScoreMessageCommand = function(self)
		updateScoreBoard(self)
	end,

}

local rowsContainer = Def.ActorFrame {
	Name = "Rows",
	InitCommand = function(self) self:xy(0, 0) end,
}
for i = 1, lines do
	rowsContainer[#rowsContainer + 1] = makeScoreRow(i)
end
t[#t + 1] = rowsContainer

return t
