local settext = BitmapText.settext
local isPractice = GAMESTATE:IsPracticeMode()
local allowedCustomization = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay

local function highlight(self)
	self:queuecommand("Highlight")
end

local function highlightIfOver(self)
	if isOver(self) then
		self:diffusealpha(0.2)
	else
		self:diffusealpha(1)
	end
end

local function transStr(line)
	return THEME:GetString("CustomizeGameplay", line)
end

return Def.ActorFrame {
	OnCommand = function(self)
		if not allowedCustomization then
			self:visible(false)
			return
		end
		if SCREENMAN:GetTopScreen():GetName() == "ScreenGameplaySyncMachine" then 
			self:visible(false)
		end
		GAMESTATE:SetAutoplay(true)
		SCREENMAN:GetTopScreen():AddInputCallback(MovableInput)
		self:SetUpdateFunction(highlight)
	end,
	OffCommand = function(self)
		if allowedCustomization then
			-- save CustomizeGameplay changes when leaving the screen
			SavePlayerConfig(pn_to_profile_slot(PLAYER_1))
			GAMESTATE:SetAutoplay(false)
		end
	end,
	Def.BitmapText {
		Name = "message",
		Font = "Common Normal",
		InitCommand = function(self)
			Movable.message = self
			self:horizalign(left):vertalign(top):shadowlength(2):xy(10, 20):zoom(.5):visible(false)
		end
	},
	Def.BitmapText {
		Name = "Instructions",
		Font = "Common Normal",
		InitCommand = function(self)
			self:horizalign(left):vertalign(top):xy(SCREEN_WIDTH - 240, 20):zoom(.375):visible(allowedCustomization)
		end,
		HighlightCommand = function(self)
			highlightIfOver(self)
		end,
		OnCommand = function(self)
			local text = {
				transStr("InstructionAutoplay"),
				transStr("InstructionPressKeys"),
				transStr("InstructionCancel"),
				"1: "..transStr("JudgmentPosition"),
				"2: "..transStr("JudgmentSize"),
				"3: "..transStr("ComboPosition"),
				"4: "..transStr("ComboSize"),
				"5: "..transStr("ErrorBarPosition"),
				"6: "..transStr("ErrorBarSize"),
				"7: "..transStr("TargetTrackerPosition"),
				"8: "..transStr("TargetTrackerSize"),
				"9: "..transStr("FullProgressBarPosition"),
				"w: "..transStr("DisplayPercentPosition"),
				"e: "..transStr("DisplayPercentSize"),
				"r: "..transStr("NotefieldPosition"),
				"t: "..transStr("NotefieldSize"),
				"y: "..transStr("NPSDisplayPosition"),
				"u: "..transStr("NPSDisplaySize"),
				"i: "..transStr("NPSGraphPosition"),
				"o: "..transStr("NPSGraphSize"),
				"p: "..transStr("JudgeCounterPosition"),
				"a: "..transStr("LeaderboardPosition"),
				"s: "..transStr("LeaderboardSize"),
				"f: "..transStr("ReplayButtonPosition"),
				"g: "..transStr("AutoFailPosition"),
				"h: "..transStr("AutoFailSize"),
				"x: "..transStr("BPMPosition"),
				"c: "..transStr("BPMSize"),
				"v: "..transStr("RatePosition"),
				"b: "..transStr("RateSize"),
				"m: "..transStr("MeanPosition"),
				"n: "..transStr("NotefieldSpacing"),
				",: "..transStr("MeanSize"),
				".: "..transStr("DPDisplayPosition"),
				"/: "..transStr("DPDisplaySize"),
			}
			if playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).LaneCover ~= 0 then
				local selectStr = THEME:GetString("GameButton", "Select")
				table.insert(text, selectStr..": "..transStr("LaneCoverHeight"))
			end
			if isPractice then
				table.insert(text, "z: "..transStr("DensityGraphPosition"))
			end
			self:settext(table.concat(text, "\n"))
		end
	}
}
