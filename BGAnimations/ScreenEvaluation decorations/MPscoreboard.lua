--- Holographic Void: Multiplayer Scoreboard (ported from spawncamping-wallhack)
-- Displays lobby player scores during ScreenNetEvaluation (redesign needed)

local lines = 16
local pn = GAMESTATE:GetEnabledPlayers()[1]
local multiscores = {}
local spacing = 34

-- HV Color palette
local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")

local judgmentColors = {
	color("#FFFFFF"), color("#E0E0A0"), color("#A0E0A0"),
	color("#A0C8E0"), color("#C8A0E0"), color("#E0A0A0")
}

local function SetActivePlayer(locaIndex)
	local scoreBoard = SCREENMAN:GetTopScreen():GetChildren().MPScoreBoard
	if not scoreBoard then return end
	SCREENMAN:GetTopScreen():SetCurrentPlayerByName(multiscores[locaIndex].user)
end

local sortFunction = function(first, second)
	return first.highscore:GetWifeScore() > second.highscore:GetWifeScore()
end

local function updateScoreBoard(self)
	local selectedUserName = false
	local screen = SCREENMAN:GetTopScreen()
	if multiscores then
		local cur = screen:GetCurrentPlayer()
		for i = 1, #multiscores do
			if cur == multiscores[i].idx then
				selectedUserName = multiscores[i].user
			end
		end
	end
	selectedUserName = selectedUserName or NSMAN:GetLoggedInUsername()

	multiscores = NSMAN:GetEvalScores()
	for i = 1, #multiscores do
		multiscores[i].idx = i
	end
	table.sort(multiscores, sortFunction)
	for i = 1, #multiscores do
		self:GetChild(tostring(i)):queuecommand("UpdateNetScore")
		if selectedUserName and multiscores[i].user == selectedUserName then
			SetActivePlayer(i)
		end
	end
end

local function scoreItem(i)
	return Def.ActorFrame {
		Name = tostring(i),
		InitCommand = function(self) self:visible(false) end,
		UpdateNetScoreCommand = function(self)
			self:visible(i <= #multiscores)
		end,

		-- Row BG
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:xy(0, (i - 1) * 36):zoomto(300, 32):halign(0):valign(0)
				self:diffuse(color("0,0,0,0.4"))
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and i <= #multiscores then
					SetActivePlayer(i)
				end
			end
		},

		-- Highlight for selected player
		Def.Quad {
			InitCommand = function(self)
				self:xy(0, (i - 1) * 36):zoomto(300, 32):halign(0):valign(0)
				self:diffuse(accentColor):diffusealpha(0)
			end,
			UpdateNetScoreCommand = function(self)
				if multiscores[i] and SCREENMAN:GetTopScreen():GetCurrentPlayer() == multiscores[i].idx then
					self:diffusealpha(0.15)
				else
					self:diffusealpha(0)
				end
			end,
			UpdateNetEvalStatsMessageCommand = function(self)
				self:playcommand("UpdateNetScore")
			end
		},

		-- Rank #
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(8, (i - 1) * 36 + 16):zoom(0.28):diffuse(dimText):halign(0)
			end,
			UpdateNetScoreCommand = function(self)
				if not multiscores[i] then return end
				self:settext(i)
				if SCREENMAN:GetTopScreen():GetCurrentPlayer() == multiscores[i].idx then
					self:diffuse(accentColor)
				else
					self:diffuse(dimText)
				end
			end
		},

		-- Username
		LoadFont("Common Normal") .. {
			Name = "user",
			InitCommand = function(self)
				self:xy(35, (i - 1) * 36 + 6):zoom(0.3):halign(0):maxwidth(180 / 0.3):diffuse(brightText)
			end,
			UpdateNetScoreCommand = function(self)
				if not multiscores[i] then return end
				self:settext(multiscores[i].user)
			end
		},

		-- Wife%
		LoadFont("Common Normal") .. {
			Name = "wife",
			InitCommand = function(self)
				self:xy(35, (i - 1) * 36 + 18):zoom(0.28):halign(0):maxwidth(160 / 0.28):diffuse(mainText)
			end,
			UpdateNetScoreCommand = function(self)
				if not multiscores[i] then return end
				local perc = multiscores[i].highscore:GetWifeScore() * 100
				if perc > 99.65 then
					self:settextf("%05.4f%%", notShit.floor(perc, 4))
				else
					self:settextf("%05.2f%%", notShit.floor(perc, 2))
				end
			end
		},

		-- Grade
		LoadFont("Common Normal") .. {
			Name = "grade",
			InitCommand = function(self)
				self:xy(260, (i - 1) * 36 + 6):zoom(0.3):halign(1)
			end,
			UpdateNetScoreCommand = function(self)
				if not multiscores[i] then return end
				local grade = multiscores[i].highscore:GetWifeGrade()
				self:settext(HV.GetGradeName(ToEnumShortString(grade)))
				self:diffuse(HVColor.GetGradeColor(ToEnumShortString(grade)))
			end
		},

		-- Combo
		LoadFont("Common Normal") .. {
			Name = "combo",
			InitCommand = function(self)
				self:xy(290, (i - 1) * 36 + 6):zoom(0.25):halign(1):diffuse(subText)
			end,
			UpdateNetScoreCommand = function(self)
				if not multiscores[i] then return end
				self:settextf("x%d", multiscores[i].highscore:GetMaxCombo())
			end
		},

		-- Judgment tally (no labels)
		LoadFont("Common Normal") .. {
			Name = "judge",
			InitCommand = function(self)
				self:xy(35, (i - 1) * 36 + 28):zoom(0.24):halign(0):diffuse(subText)
			end,
			UpdateNetScoreCommand = function(self)
				if not multiscores[i] then return end
				local hs = multiscores[i].highscore
				self:settextf("%d / %d / %d / %d / %d / %d",
					hs:GetTapNoteScore("TapNoteScore_W1"),
					hs:GetTapNoteScore("TapNoteScore_W2"),
					hs:GetTapNoteScore("TapNoteScore_W3"),
					hs:GetTapNoteScore("TapNoteScore_W4"),
					hs:GetTapNoteScore("TapNoteScore_W5"),
					hs:GetTapNoteScore("TapNoteScore_Miss"))
			end
		},
	}
end

local t = Def.ActorFrame {
	Name = "MPScoreBoard",
	BeginCommand = function(self)
		pcall(function() SCREENMAN:GetTopScreen():AddInputCallback(MPinput) end)
	end,
	NewMultiScoreMessageCommand = updateScoreBoard,
}

for i = 1, lines do
	t[#t + 1] = scoreItem(i)
end

return t
