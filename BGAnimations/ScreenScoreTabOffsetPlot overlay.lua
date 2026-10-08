-- if score is ever nil we done goofed way before this screen is ever loaded -mina
-- generalized code to reduce redundancy, load general code instead

local function input(event)
	if event.DeviceInput.button == "DeviceButton_right mouse button" and event.type == "InputEventType_Release" then
		SCREENMAN:GetTopScreen():Cancel()
	end
	return false
end

local t = Def.ActorFrame {
	BeginCommand = function()
		SCREENMAN:GetTopScreen():AddInputCallback(input)
	end,
	CodeMessageCommand = function(self, params)
		if
			params.Name == "PlotExit"
		 then
			SCREENMAN:GetTopScreen():Cancel() -- need this so we can leave
		end
	end
}

-- Keep the plot readable over the select-music background.
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,0.78"))
		self:z(0)
	end
}
t[#t + 1] = LoadActor("offsetplot")

-- Compact evaluation header for score-tab plots.
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self) self:halign(1):xy(SCREEN_WIDTH - 28, SCREEN_HEIGHT - 120):zoom(0.55) end,
	OnCommand = function(self)
		local score = getScoreForPlot()
		local wife = score and score.GetWifeScore and score:GetWifeScore() * 100 or 0
		self:settextf("%.4f%%", wife):diffuse(brightText or color("1,1,1,1"))
	end,
}
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self) self:halign(1):xy(SCREEN_WIDTH - 28, SCREEN_HEIGHT - 132):zoom(0.5) end,
	OnCommand = function(self)
		local score = getScoreForPlot()
		if not score then return end
		local grade = score.GetWifeGrade and ToEnumShortString(score:GetWifeGrade()) or "F"
		self:settext(HV.GetGradeName(grade)):diffuse(HVColor.GetGradeColor(grade))
	end,
}
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self) self:halign(1):xy(SCREEN_WIDTH - 28, SCREEN_HEIGHT - 142):zoom(0.38) end,
	OnCommand = function(self)
		local score = getScoreForPlot()
		local ssr = score and score.GetSkillsetSSR and score:GetSkillsetSSR("Overall") or 0
		self:settextf("%.2f", ssr):diffuse(HVColor.GetMSDRatingColor(ssr))
	end,
}
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self) self:halign(1):valign(1):xy(SCREEN_WIDTH - 28, SCREEN_HEIGHT - 145):zoom(0.24) end,
	OnCommand = function(self)
		local score = getScoreForPlot()
		if not score or type(score.GetTapNoteScores) ~= "function" then return end
		self:settext(string.format("MARV  %d\nPERF  %d\nGREAT %d\nGOOD  %d\nBOO   %d\nMISS  %d",
			score:GetTapNoteScores("TapNoteScore_W1"), score:GetTapNoteScores("TapNoteScore_W2"),
			score:GetTapNoteScores("TapNoteScore_W3"), score:GetTapNoteScores("TapNoteScore_W4"),
			score:GetTapNoteScores("TapNoteScore_W5"), score:GetTapNoteScores("TapNoteScore_Miss")))
	end,
}
return t
