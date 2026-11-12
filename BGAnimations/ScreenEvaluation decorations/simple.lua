-- Dedicated Simple evaluation screen redesigned with a balanced dual-card layout
-- keeping the exact visual aesthetic, color palette, and styling of the Classic evaluation screen.
local data = HV.GetSimpleEvaluationData()

local frameX = 10
local frameY = 10
local frameW = SCREEN_CENTER_X - 20
local frameH = SCREEN_HEIGHT - 20
local pad = 12
local topHeaderY = pad + 14
local rowH = 22
local rightX = SCREEN_CENTER_X + 10
local rightW = SCREEN_CENTER_X - 20
local barWidth = rightW - pad * 2

local function formatDanName(dan)
	if dan == "0" then return "Below 1st" end
	if dan == "∞" or dan == "Infinity" then return "Infinity" end
	return dan
end

local accentColor = (HVColor and HVColor.Accent) or color("#5ABAFF")
local brightText = color("1,1,1,1")
local dimText = (HVColor and HVColor.TextDim) or color("0.4,0.4,0.4,1")
local subText = brightText
local mainText = brightText
local bgCard = color("0.06,0.06,0.06,0.7")
local dividerColor = color("0.2,0.2,0.2,1")

local function isOnlineEvaluation()
	return HV.OnlineEvaluationActive == true or HV.OnlineReplayActive == true
end

local function getOnlinePlayerName()
	local name = HV.OnlineEvaluationName or HV.OnlineReplayName
	if (not name or name == "") and DLMAN and DLMAN.IsLoggedIn and DLMAN:IsLoggedIn() then
		name = DLMAN:GetUsername()
	end
	return name
end

local function getLocalPlayerName()
	local profile = GAMESTATE:GetMasterPlayerNumber() and PROFILEMAN:GetProfile(GAMESTATE:GetMasterPlayerNumber())
	local name = profile and profile:GetDisplayName()
	return name and name ~= "" and name or nil
end

local function refreshOffsetPlot(self)
	if HV.GetSimpleEvaluationData then data = HV.GetSimpleEvaluationData() end
	local plot = (self:GetChild("RightPanel") and self:GetChild("RightPanel"):GetChild("OffsetPlot")) or self:GetChild("OffsetPlot")
	if not plot then return end
	plot:RunCommandsOnChildren(function(child)
		child:playcommand("Update", data.getOffsetData())
	end)
end

-- Judgment Tally Rows (proportional backdrop bars, labels, and counts sized to card width)
local judgmentRows = Def.ActorFrame {
	Name = "Judgments",
	InitCommand = function(self) self:xy(0, 0):diffusealpha(0) end,
	OnCommand = function(self)
		self:stoptweening():sleep(0.45):linear(0.25):diffusealpha(1)
	end,
}

local statsStartY = 40
for i, judgeName in ipairs(data.judges) do
	local rowIndex = i
	local rowName = judgeName
	local jy = statsStartY + (i - 1) * rowH
	local rowColor = function()
		if HV.ManiaState and HV.ManiaState.enabled then
			return HVColor.GetJudgmentColor(({"W1", "W2", "W3", "W4", "W5", "Miss"})[rowIndex])
		end
		return data.judgmentColors[rowIndex] or brightText
	end

	judgmentRows[#judgmentRows + 1] = Def.ActorFrame {
		Name = "Judgment" .. rowIndex,
		InitCommand = function(self) self:xy(0, 0) end,

		-- Proportional Backdrop Bar
		Def.Quad {
			Name = "Bar",
			InitCommand = function(self)
				self:halign(0):xy(pad, jy):zoomto(0, rowH - 3)
					:diffuse(rowColor()):diffusealpha(0.22)
					:visible(rowIndex <= data.getActiveJudgeCount())
			end,
			ManiaModeChangedMessageCommand = function(self)
				self:visible(rowIndex <= data.getActiveJudgeCount()):diffuse(rowColor()):diffusealpha(0.22)
				self:playcommand("SetJudge")
			end,
			OnCommand = function(self)
				local count = data.getJudgment(rowName, rowIndex)
				local totalNotes = data.totalNotes or 0
				local pct = totalNotes > 0 and (count / totalNotes) or 0
				self:zoomto(barWidth * pct, rowH - 3)
			end,
			SetJudgeCommand = function(self)
				local count = data.getJudgment(rowName, rowIndex)
				local totalNotes = data.totalNotes or 0
				local pct = totalNotes > 0 and (count / totalNotes) or 0
				self:finishtweening():linear(0.2):zoomto(barWidth * pct, rowH - 3)
			end
		},

		-- Judgment Label
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:halign(0):xy(pad + 8, jy + 1):zoom(0.46):diffuse(rowColor())
					:settext(data.getJudgmentLabel(rowName, rowIndex))
					:visible(rowIndex <= data.getActiveJudgeCount())
			end,
			ManiaModeChangedMessageCommand = function(self)
				self:settext(data.getJudgmentLabel(rowName, rowIndex)):diffuse(rowColor()):visible(rowIndex <= data.getActiveJudgeCount())
			end
		},

		-- Judgment Count
		LoadFont("Common Normal") .. {
			Name = "Count",
			InitCommand = function(self)
				self:halign(1):xy(rightW - pad - 8, jy + 1):zoom(0.52):diffuse(brightText)
					:settext(tostring(data.getJudgment(rowName, rowIndex)))
					:visible(rowIndex <= data.getActiveJudgeCount())
			end,
			ManiaModeChangedMessageCommand = function(self)
				self:visible(rowIndex <= data.getActiveJudgeCount())
				self:playcommand("SetJudge")
			end,
			OnCommand = function(self)
				self:settext(tostring(data.getJudgment(rowName, rowIndex)))
			end,
			SetJudgeCommand = function(self)
				self:settext(tostring(data.getJudgment(rowName, rowIndex)))
			end
		}
	}
end

local t = Def.ActorFrame {
	Name = "SimpleEvaluationScreen",
	InitCommand = function(self)
		self:visible(HV.EvaluationCompact == true)
	end,
	SetJudgeMessageCommand = function(self)
		self:playcommand("UpdateValues")
		refreshOffsetPlot(self)
	end,
	SetJudgeCommand = function(self)
		self:playcommand("UpdateValues")
		refreshOffsetPlot(self)
	end,
	OffsetPlotModificationMessageCommand = function(self)
		self:playcommand("UpdateValues")
		refreshOffsetPlot(self)
	end,
	ScoreChangedMessageCommand = function(self)
		self:playcommand("UpdateValues")
		refreshOffsetPlot(self)
	end,
	ManiaModeChangedMessageCommand = function(self)
		self:playcommand("UpdateValues", {resetWifeAnimation = true})
		refreshOffsetPlot(self)
	end,
	LoadedCustomWindowMessageCommand = function(self)
		self:playcommand("UpdateValues", {resetWifeAnimation = true})
		refreshOffsetPlot(self)
	end,
	UnloadedCustomWindowMessageCommand = function(self)
		self:playcommand("UpdateValues", {resetWifeAnimation = true})
		refreshOffsetPlot(self)
	end,
	CustomWindowStateChangedMessageCommand = function(self)
		self:playcommand("UpdateValues", {resetWifeAnimation = true})
		refreshOffsetPlot(self)
	end,
	ToggleCustomWindowsMessageCommand = function(self)
		self:playcommand("UpdateValues", {resetWifeAnimation = true})
		refreshOffsetPlot(self)
	end,
	UpdateValuesCommand = function(self, params)
		if HV.GetSimpleEvaluationData then data = HV.GetSimpleEvaluationData() end
		local leftPanel = self:GetChild("LeftPanel")
		local rightPanel = self:GetChild("RightPanel")
		if not leftPanel then return end

		-- Song Info & Banner
		local song = data.song
		local profileData = data.getProfileDisplay()
		local profileFrame = leftPanel:GetChild("ProfileDisplay")
		if profileFrame and profileData then
			local avatar = profileFrame:GetChild("Avatar")
			if avatar and profileData.avatar and avatar.path ~= profileData.avatar then
				avatar.path = profileData.avatar
				avatar:Load(profileData.avatar):zoomto(60, 60)
			end
			local nameActor = profileFrame:GetChild("PlayerName")
			if nameActor then nameActor:playcommand("RefreshName") end
			local badge = profileFrame:GetChild("PlayerLevelBadge")
			if badge then
				badge:visible(profileData.showLevel == true)
				badge:GetChild("BadgeQuad"):diffuse(profileData.levelColor or color("#666666"))
				badge:GetChild("LevelText"):settext(profileData.level and string.format("Lv. %d", profileData.level) or "")
			end
			local progress = profileFrame:GetChild("LevelProgress")
			if progress then
				progress:visible(profileData.showLevel == true)
				progress:GetChild("BarFill"):zoomto((profileData.progressWidth or 0) * (profileData.progress or 0), 4)
				progress:GetChild("ProgressText"):settext(profileData.progressText or "")
			end
			local rating = profileFrame:GetChild("PlayerRating")
			if rating then
				rating:playcommand("RefreshRating")
			end
		end
		local modIcons = leftPanel:GetChild("ModIcons")
		if modIcons then modIcons:playcommand("Update") end
		leftPanel:GetChild("SongTitle"):settext(song and song:GetDisplayMainTitle() or "")

		local sub = song and song:GetDisplaySubTitle() or ""
		local hasSub = sub ~= ""
		local subActor = leftPanel:GetChild("SongSubtitle")
		local artistActor = leftPanel:GetChild("SongArtist")
		local packActor = leftPanel:GetChild("PackName")

		if subActor then
			subActor:visible(hasSub):settext(sub)
		end
		if artistActor then
			artistActor:y(hasSub and (pad + 114) or (pad + 104))
			artistActor:settext(song and ("// " .. song:GetDisplayArtist()) or "")
		end
		if packActor then
			packActor:y(hasSub and (pad + 128) or (pad + 120))
			packActor:settext(song and song:GetGroupName() or "")
		end

		-- Difficulty & Rate
		local diffActor = leftPanel:GetChild("DifficultyRate")
		if diffActor then
			local diffLabel, difficultyColor = data.getDifficulty()
			local meterText, meterColor = data.getMeterText()
			diffActor:GetChild("Difficulty"):settext(diffLabel):diffuse(difficultyColor or accentColor)
			local ratingActor = diffActor:GetChild("MSD")
			if ratingActor then ratingActor:playcommand("SetRatingPages", {meterText = meterText, meterColor = meterColor}) end
			diffActor:GetChild("Rate"):settext(data.getRateText())
			diffActor:GetChild("Judge"):settext(data.getJudgeText())
			local offsetStatus = diffActor:GetChild("OffsetPriorityStatus")
			if offsetStatus then
				local active = data.getOffsetPriorityStatus and data.getOffsetPriorityStatus()
				offsetStatus:settext(active and "Offsets Reprioritized" or ""):visible(active == true)
			end
		end
		local customWindow = leftPanel:GetChild("CustomScoringLabel")
		if customWindow and data.getCustomWindowName then
			local name = data.getCustomWindowName()
			customWindow:settext(name):visible(name ~= "")
		end

		-- Grade, WifeScore, and MSDSSR
		local grade, gradeColor = data.getGrade()
		leftPanel:GetChild("Grade"):settext(grade):diffuse(gradeColor or brightText)
		local wifeFrame = leftPanel:GetChild("WifeScore")
		local wifeValue = wifeFrame:GetChild("Value")
		wifeValue:settext(data.getWife())
		if params and params.resetWifeAnimation and HV.AnimateEvaluationFloat then
			HV.AnimateEvaluationFloat(wifeFrame, data.getWifeValue(), function(value)
				wifeValue:settext(data.formatWifeValue(value))
			end, 1, 0, 0.5)
		end
		local j4Actor = leftPanel:GetChild("J4WifeScore")
		if j4Actor and data.getJ4Wife then
			local j4Text = data.getJ4Wife()
			j4Actor:settext(j4Text or ""):visible(j4Text ~= nil and j4Text ~= "")
		end
		local ssrText, ssrColor = data.getMSDSSR()
		leftPanel:GetChild("MSDSSR"):settext(ssrText):diffuse(ssrColor or subText)

		-- Secondary Score Info
		local clearActor = leftPanel:GetChild("ClearType")
		if clearActor and data.getClearType then
			local ctText, ctColor = data.getClearType()
			clearActor:settext(ctText):diffuse(ctColor or accentColor)
		end
		local cmpActor = leftPanel:GetChild("WifeComparison")
		if cmpActor and data.getWifeComparison then
			cmpActor:settext(data.getWifeComparison() or "")
		end
		local nearActor = leftPanel:GetChild("NearestGrade")
		if nearActor and data.getNearestGrade then
			nearActor:settext(data.getNearestGrade() or "")
		end

		-- Judgments Tally
		local judgments = (rightPanel and rightPanel:GetChild("Judgments")) or (leftPanel and leftPanel:GetChild("Judgments"))
		local totalNotes = data.totalNotes or 0
		local activeCount = data.getActiveJudgeCount()
		for i, name in ipairs(data.judges) do
			local row = judgments and judgments:GetChild("Judgment" .. i)
			if row then
				local isVisible = i <= activeCount
				row:GetChild("Bar"):visible(isVisible)
				row:GetChild("Label"):visible(isVisible)
				row:GetChild("Count"):visible(isVisible)

				if isVisible then
					local count = data.getJudgment(name, i)
					local pct = totalNotes > 0 and (count / totalNotes) or 0
					row:GetChild("Label"):settext(data.getJudgmentLabel(name, i))
					row:GetChild("Count"):settext(tostring(count))
					row:GetChild("Bar"):finishtweening():linear(0.2):zoomto(barWidth * pct, rowH - 3)
				end
			end
		end
	end,
	OnCommand = function(self)
		self:playcommand("UpdateValues")
		self:sleep(0):queuecommand("UpdateOffsetPlot")
	end,
	UpdateOffsetPlotCommand = refreshOffsetPlot,

	-- ============================================================
	-- LEFT PANEL: SONG & SCORE CARD
	-- ============================================================
	Def.ActorFrame {
		Name = "LeftPanel",
		InitCommand = function(self)
			self:xy(frameX - 55, frameY):diffusealpha(0)
		end,
		OnCommand = function(self)
			self:sleep(0.25):linear(0.4):x(frameX):diffusealpha(1)
		end,

		-- Main Card BG (Classic frame dimensions)
		Def.Quad {
			Name = "Background",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(frameW, frameH):diffuse(bgCard):diffusealpha(0)
			end,
			OnCommand = function(self)
				self:sleep(0.05):linear(0.35):diffusealpha(0.7):x(0)
			end
		},

		-- Mod line (same position and shorthand fields as Classic)
		Def.ActorFrame {
			Name = "ModIcons",
			InitCommand = function(self) self:xy(20, 8):diffusealpha(0) end,
			OnCommand = function(self)
				self:playcommand("Update")
				self:sleep(0.12):linear(0.25):diffusealpha(1)
			end,
			UpdateCommand = function(self)
				local m = data.getModDisplay()
				self:GetChild("Speed"):settext(m.speed):diffuse(m.accent)
				self:GetChild("Rate"):settext(m.rate):diffuse(m.accent)
				self:GetChild("BPM"):settext(m.bpm):diffuse(m.accent)
				self:GetChild("Life"):settext(m.life):diffuse(m.lifeColor)
				self:GetChild("Judge"):settext(m.judge):diffuse(m.accent)
				self:GetChild("Fail"):settext(m.fail):diffuse(m.failColor)
				self:GetChild("Assist"):settext("AST"):diffuse(m.assist and m.accent or m.dim)
				self:GetChild("Separator"):visible(m.mods ~= "")
				self:GetChild("Mods"):settext(m.mods):diffuse(m.accent)
			end,
			LoadFont("Common Normal") .. { Name = "Speed", InitCommand = function(self) self:zoom(0.4):halign(0) end },
			LoadFont("Common Normal") .. { Name = "Rate", InitCommand = function(self) self:x(42):y(-4):zoom(0.4):halign(0) end },
			LoadFont("Common Normal") .. { Name = "BPM", InitCommand = function(self) self:x(42):y(6):zoom(0.4):halign(0) end },
			LoadFont("Common Normal") .. { Name = "Life", InitCommand = function(self) self:x(82):zoom(0.4):halign(0) end },
			LoadFont("Common Normal") .. { Name = "Judge", InitCommand = function(self) self:x(110):zoom(0.4):halign(0) end },
			LoadFont("Common Normal") .. { Name = "Fail", InitCommand = function(self) self:x(138):zoom(0.4):halign(0) end },
			LoadFont("Common Normal") .. { Name = "Assist", InitCommand = function(self) self:x(182):zoom(0.4):halign(0) end },
			LoadFont("Common Normal") .. {
				Name = "Separator",
				InitCommand = function(self) self:x(217):zoom(0.4):halign(0):settext("|"):diffuse(color("0.4,0.4,0.4,1")) end
			},
			LoadFont("Common Normal") .. {
				Name = "Mods",
				InitCommand = function(self) self:x(232):zoom(0.4):halign(0):diffuse(accentColor) end
			}
		},

		-- Banner (Classic scale and placement)
		Def.Sprite {
			Name = "SongBanner",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, topHeaderY):diffusealpha(0)
			end,
			OnCommand = function(self)
				local song = data.song
				local bpath = song and song:GetBannerPath() or nil
				if not bpath then bpath = THEME:GetPathG("Common", "fallback banner") end
				self:LoadBackground(bpath):scaletoclipped((frameW - pad * 3) * 0.5, 60)
				self:stoptweening():sleep(0.05):linear(0.25):diffusealpha(1)
			end
		},

		-- Profile details beside the banner, matching Classic's top header.
		Def.ActorFrame {
			Name = "ProfileDisplay",
			InitCommand = function(self)
				self:xy(pad + (frameW - pad * 3) * 0.5 + pad, topHeaderY):diffusealpha(0)
			end,
			OnCommand = function(self) self:sleep(0.1):linear(0.25):diffusealpha(1) end,
			Def.Sprite {
				Name = "Avatar",
				InitCommand = function(self) self:halign(0):valign(0):zoomto(60, 60) end
			},
			LoadFont("Common Normal") .. {
				Name = "PlayerName",
				InitCommand = function(self)
					self:xy(65, 8):zoom(0.45):halign(0):maxwidth(((frameW - pad * 3) * 0.5 - 65) / 0.45)
					self.showOnline = true
					self.transitionDuration = 0.25
					self.displayDuration = 3
					self.onlineName = getOnlinePlayerName()
					self.offlineName = getLocalPlayerName()
					if isOnlineEvaluation() then self.offlineName = nil end
				end,
				OnCommand = function(self)
					if isOnlineEvaluation() then self:settext(self.onlineName or "Online Player"); return end
					if not self.onlineName then self:settext(self.offlineName or "Player 1"); return end
					if not self.offlineName or self.onlineName == self.offlineName then self:settext(self.onlineName); return end
					self:playcommand("UpdateName")
				end,
				RefreshNameCommand = function(self)
					if isOnlineEvaluation() then self:settext(getOnlinePlayerName() or "Online Player"); return end
					self.onlineName = getOnlinePlayerName()
					self.offlineName = getLocalPlayerName()
					self:playcommand("On")
				end,
				UpdateNameCommand = function(self)
					self:stoptweening():linear(self.transitionDuration * 0.5):diffusealpha(0):queuecommand("SwapName")
				end,
				SwapNameCommand = function(self)
					self:settext(self.showOnline and self.onlineName or self.offlineName)
					self.showOnline = not self.showOnline
					self:stoptweening():linear(self.transitionDuration * 0.5):diffusealpha(1):sleep(self.displayDuration):queuecommand("UpdateName")
				end
			},
			Def.ActorFrame {
				Name = "PlayerLevelBadge",
				InitCommand = function(self) self:xy(65, 23) end,
				Def.Quad {
					Name = "BadgeQuad",
					InitCommand = function(self) self:halign(0):zoomto(38, 14):diffusealpha(0.8) end
				},
				LoadFont("Common Normal") .. {
					Name = "LevelText",
					InitCommand = function(self) self:halign(0):x(4):zoom(0.32):diffuse(color("#FFFFFF")) end
				}
			},
			Def.ActorFrame {
				Name = "LevelProgress",
				InitCommand = function(self) self:xy(65, 34) end,
				Def.Quad {
					Name = "BarBG",
					InitCommand = function(self) self:halign(0):zoomto(frameW * 0.18, 4):diffuse(0, 0, 0, 0.5) end
				},
				Def.Quad {
					Name = "BarFill",
					InitCommand = function(self) self:halign(0):zoomto(0, 4):diffuse(color("#FF4081")) end
				},
				LoadFont("Common Normal") .. {
					Name = "ProgressText",
					InitCommand = function(self) self:halign(0):xy(0, 8):zoom(0.22):diffuse(subText) end
				}
			},
			LoadFont("MSD 20px") .. {
				Name = "PlayerRating",
				InitCommand = function(self)
					self:xy(65, 53):zoom(0.35):halign(0):maxwidth(((frameW - pad * 3) * 0.5 - 65) / 0.35)
					self.showOnline = true
					self.transitionDuration = 0.25
					self.onlineRating = DLMAN and DLMAN.IsLoggedIn and DLMAN:IsLoggedIn() and DLMAN.GetSkillsetRating and tonumber(DLMAN:GetSkillsetRating("Overall")) or nil
					local pn = GAMESTATE:GetMasterPlayerNumber()
					local profile = pn and PROFILEMAN:GetProfile(pn)
					self.offlineRating = profile and profile:GetPlayerRating() or nil
				end,
				OnCommand = function(self)
					if isOnlineEvaluation() or not HV.ShowMSD() then self:visible(false); return end
					if not self.onlineRating or self.onlineRating <= 0 then
						if self.offlineRating and self.offlineRating > 0 then self:settextf("%.2f", self.offlineRating):diffuse(HVColor.GetMSDRatingColor(self.offlineRating)) else self:visible(false) end
						return
					elseif not self.offlineRating or self.offlineRating <= 0 or math.abs(self.onlineRating - self.offlineRating) < 0.01 then
						self:settextf("%.2f", self.onlineRating):diffuse(HVColor.GetMSDRatingColor(self.onlineRating))
						return
					end
					self:playcommand("UpdateRating")
				end,
				RefreshRatingCommand = function(self)
					local pn = GAMESTATE:GetMasterPlayerNumber()
					local profile = pn and PROFILEMAN:GetProfile(pn)
					self.offlineRating = profile and profile:GetPlayerRating() or nil
					self:playcommand("On")
				end,
				UpdateRatingCommand = function(self)
					self:stoptweening():linear(self.transitionDuration * 0.5):diffusealpha(0):queuecommand("SwapRating")
				end,
				SwapRatingCommand = function(self)
					local value = self.showOnline and self.onlineRating or self.offlineRating
					self:settextf("%.2f", value):diffuse(HVColor.GetMSDRatingColor(value))
					self.showOnline = not self.showOnline
					self:stoptweening():linear(self.transitionDuration * 0.5):diffusealpha(1):sleep(3):queuecommand("UpdateRating")
				end
			}
		},

		-- Song Title (Classic position, font, zoom, and entrance)
		LoadFont("Common Large") .. {
			Name = "SongTitle",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad - 10, pad + 80):zoom(0.55):diffuse(brightText):diffusealpha(0)
				self:maxwidth((frameW - pad * 2 - 105) / 0.55)
			end,
			OnCommand = function(self)
				local song = data.song
				if song then self:settext(song:GetDisplayMainTitle()) end
				self:sleep(0.1):linear(0.25):xy(pad, pad + 80):diffusealpha(1)
			end
		},

		-- Song Subtitle
		LoadFont("Common Normal") .. {
			Name = "SongSubtitle",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad - 10, pad + 96):zoom(0.42):diffuse(subText):diffusealpha(0)
				self:maxwidth((frameW - pad * 2 - 105) / 0.42):visible(false)
			end,
			OnCommand = function(self)
				local sub = data.song and data.song:GetDisplaySubTitle() or ""
				if sub ~= "" then
					self:visible(true):settext(sub):sleep(0.12):linear(0.25):xy(pad, pad + 96):diffusealpha(1)
				else
					self:visible(false)
				end
			end
		},

		-- Song Artist
		LoadFont("Common Normal") .. {
			Name = "SongArtist",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad - 10, pad + 104):zoom(0.48):diffuse(subText):diffusealpha(0)
				self:maxwidth((frameW - pad * 2 - 105) / 0.48)
			end,
			OnCommand = function(self)
				local song = data.song
				if song then self:settext("// " .. song:GetDisplayArtist()) end
				self:sleep(0.15):linear(0.25):xy(pad, pad + 104):diffusealpha(1)
			end
		},

		-- Pack Name
		LoadFont("Common Normal") .. {
			Name = "PackName",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad - 10, pad + 120):zoom(0.38):diffuse(subText):diffusealpha(0)
				self:maxwidth((frameW - pad * 2 - 105) / 0.38)
			end,
			OnCommand = function(self)
				local song = data.song
				if song then self:settext(song:GetGroupName()) end
				self:sleep(0.2):linear(0.25):xy(pad, pad + 120):diffusealpha(1)
			end
		},

		-- Difficulty, MSD, rate, and judge (Classic layout)
		Def.ActorFrame {
			Name = "DifficultyRate",
			InitCommand = function(self)
				self:xy(frameW - pad + 10, pad + 80):diffusealpha(0)
			end,
			OnCommand = function(self)
				self:sleep(0.2):linear(0.25):xy(frameW - pad, pad + 80):diffusealpha(1)
			end,
			LoadFont("Common Normal") .. {
				Name = "Difficulty",
				InitCommand = function(self) self:halign(1):valign(1):xy(0, -5):zoom(0.55):diffuse(accentColor) end
			},
			LoadFont("MSD 20px") .. {
				Name = "MSD",
				InitCommand = function(self) self:halign(1):valign(0):xy(0, -2):zoom(0.6):maxwidth((frameW - pad * 2) / 0.6):diffuse(subText); self.transitionDuration = 0.25 end,
				SetRatingPagesCommand = function(self, params)
					self:stoptweening()
					self.hvRatingPages = {}
					self.hvRatingPage = 1
					if params and params.meterText and params.meterText ~= "" then
						self.hvRatingPages[1] = {text = params.meterText, color = params.meterColor or subText}
					end
					if HV.EnableDanCalculator and HV.EnableDanCalculator() and steps then
						local rate = tonumber(getCurRateValue()) or 1
						local chartKey = steps.GetChartKey and tostring(steps:GetChartKey())
						local estimate
						if chartKey and FILEMAN and FILEMAN.DoesFileExist then
							local path = "Save/Holographic Void_settings/ChartRatingCache.lua"
							if FILEMAN:DoesFileExist(path) then
								local file = RageFileUtil.CreateRageFile()
								if file:Open(path, 1) then
									local source = file:Read()
									local chunk = type(source) == "string" and loadstring(source) or nil
									if chunk then
										setfenv(chunk, {})
										local ok, cache = pcall(chunk)
										if ok and type(cache) == "table" then
											local key = chartKey .. "|" .. string.format("%.8f", rate)
											estimate = cache["isor-dp-v2|" .. key] or cache["isor-dp-v1|" .. key]
										end
									end
									file:Close()
								end
								file:destroy()
							end
						end
						if type(estimate) ~= "table" and data and data.steps then
							local dataKey = data.steps.GetChartKey and tostring(data.steps:GetChartKey())
							if dataKey == chartKey and math.abs((tonumber(data.rate) or rate) - rate) < 0.0005 then estimate = data.isorEstimate end
						end
						if type(estimate) == "table" and type(estimate.dan) == "string" then
							local text = formatDanName(estimate.dan) .. (type(estimate.sublevel) == "string" and (" " .. estimate.sublevel) or "")
							self.hvRatingPages[#self.hvRatingPages + 1] = {text = text, color = (HV.GetReformDanColor and HV.GetReformDanColor(estimate)) or HVColor.GetMSDRatingColor(tonumber(estimate.dp) or 1)}
						end
					end
					if #self.hvRatingPages > 0 then
						local page = self.hvRatingPages[1]
						self:settext(page.text):diffuse(page.color):diffusealpha(1)
						if #self.hvRatingPages > 1 then self:sleep(3):queuecommand("FadeRatingOut") end
					else
						self:settext("")
					end
				end,
				FadeRatingOutCommand = function(self)
					if not self.hvRatingPages or #self.hvRatingPages < 2 then return end
					self:stoptweening():linear(self.transitionDuration * 0.5):diffusealpha(0):queuecommand("CycleRating")
				end,
				CycleRatingCommand = function(self)
					if not self.hvRatingPages or #self.hvRatingPages < 2 then return end
					self.hvRatingPage = self.hvRatingPage % #self.hvRatingPages + 1
					local page = self.hvRatingPages[self.hvRatingPage]
					self:settext(page.text):diffuse(page.color)
					self:stoptweening():linear(self.transitionDuration * 0.5):diffusealpha(1):sleep(3):queuecommand("FadeRatingOut")
				end
			},
			LoadFont("Common Normal") .. {
				Name = "Rate",
				InitCommand = function(self) self:halign(1):valign(0):xy(0, 20):zoom(0.65):diffuse(brightText) end
			},
			LoadFont("Common Normal") .. {
				Name = "Judge",
				InitCommand = function(self) self:halign(1):valign(0):xy(0, 34):zoom(0.5):diffuse(dimText) end
			},
			LoadFont("Common Normal") .. {
				Name = "OffsetPriorityStatus",
				InitCommand = function(self) self:halign(1):valign(0):xy(0, 48):zoom(0.28):diffuse(accentColor):visible(false) end
			}
		},
		LoadFont("Common Normal") .. {
			Name = "CustomScoringLabel",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 110, pad + 140):zoom(0.45):diffuse(accentColor):visible(false)
			end
		},

		-- Separator 1 (Classic divider styling)
		Def.Quad {
			Name = "Separator1",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, pad + 140):zoomto(frameW - pad * 2, 1):diffuse(dividerColor)
			end
		},

		-- ============================================================
		-- HERO SCORE SECTION
		-- ============================================================
		-- Hero Result Background Plate
		Def.Quad {
			Name = "HeroCardBG",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, pad + 150):zoomto(frameW - pad * 2, 280)
					:diffuse(color("0,0,0,0.22")):diffusealpha(0)
			end,
			OnCommand = function(self)
				self:sleep(0.18):linear(0.25):diffusealpha(0.5)
			end
		},
		Def.Quad {
			Name = "HeroCardAccent",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, pad + 150):zoomto(frameW - pad * 2, 2)
					:diffuse(accentColor):diffusealpha(0)
			end,
			OnCommand = function(self)
				self:sleep(0.2):linear(0.25):diffusealpha(0.45)
			end
		},

		-- Grade (Prominent showcase)
		LoadFont("Common Large") .. {
			Name = "Grade",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 16, pad + 168):zoom(1.1):diffuse(mainText):diffusealpha(0)
			end,
			OnCommand = function(self)
				local grade, gradeColor = data.getGrade()
				self:settext(grade):diffuse(gradeColor or brightText)
				self:stoptweening():sleep(0.25):zoom(1.3):linear(0.2):zoom(1.05):diffusealpha(1)
			end
		},

		-- WifeScore (Primary percentage display)
		Def.ActorFrame {
			Name = "WifeScore",
			InitCommand = function(self)
				self:xy(pad + 145, pad + 168)
			end,
			OnCommand = function(self)
				local valueActor = self:GetChild("Value")
				valueActor:settext(data.getWife())
				if HV.AnimateEvaluationFloat then
					HV.AnimateEvaluationFloat(self, data.getWifeValue(), function(value)
						valueActor:settext(data.formatWifeValue(value))
					end)
				end
				valueActor:sleep(0.35):linear(0.15):diffusealpha(1)
			end,
			LoadFont("Common Large") .. {
				Name = "Value",
				InitCommand = function(self)
					self:halign(0):valign(0):zoom(0.85):diffuse(mainText):diffusealpha(0)
				end
			}
		},
		LoadFont("Common Normal") .. {
			Name = "J4WifeScore",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 145, pad + 151):zoom(0.4):diffuse(color("#FF6666")):diffusealpha(1):visible(false)
			end
		},

		-- MSDSSR Label & Value
		LoadFont("Common Normal") .. {
			Name = "SSRLabel",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 146, pad + 218):zoom(0.36):diffuse(dimText):settext("SSR"):diffusealpha(0)
			end,
			OnCommand = function(self)
				self:sleep(0.32):linear(0.2):diffusealpha(1)
			end
		},
		LoadFont("MSD 20px") .. {
			Name = "MSDSSR",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 145, pad + 232):zoom(0.62):diffuse(subText):diffusealpha(0)
			end,
			OnCommand = function(self)
				local ssrText, ssrColor = data.getMSDSSR()
				self:settext(tostring(ssrText or "0.00")):diffuse(ssrColor or subText)
				self:sleep(0.35):linear(0.2):diffusealpha(1)
			end
		},

		-- Separator 2
		Def.Quad {
			Name = "Separator2",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 12, pad + 278):zoomto(frameW - pad * 2 - 24, 1):diffuse(dividerColor)
			end
		},

		-- Clear Type Display
		LoadFont("Common Normal") .. {
			Name = "ClearTypeLabel",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 16, pad + 296):zoom(0.38):diffuse(dimText):settext("CLEAR TYPE"):diffusealpha(0)
			end,
			OnCommand = function(self) self:sleep(0.38):linear(0.2):diffusealpha(1) end
		},
		LoadFont("Common Normal") .. {
			Name = "ClearType",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 16, pad + 312):zoom(0.62):diffuse(accentColor):diffusealpha(0)
			end,
			OnCommand = function(self)
				if data.getClearType then
					local ctText, ctColor = data.getClearType()
					self:settext(ctText):diffuse(ctColor or accentColor)
				end
				self:sleep(0.4):linear(0.2):diffusealpha(1)
			end
		},

		-- Best Score Comparison
		LoadFont("Common Normal") .. {
			Name = "WifeComparisonLabel",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 146, pad + 296):zoom(0.38):diffuse(dimText):settext("To Best"):diffusealpha(0)
			end,
			OnCommand = function(self) self:sleep(0.38):linear(0.2):diffusealpha(1) end
		},
		LoadFont("Common Normal") .. {
			Name = "WifeComparison",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 146, pad + 312):zoom(0.5):diffuse(subText):diffusealpha(0)
			end,
			OnCommand = function(self)
				if data.getWifeComparison then
					self:settext(data.getWifeComparison() or "")
				end
				self:sleep(0.42):linear(0.2):diffusealpha(1)
			end
		},

		-- Nearest Grade Target
		LoadFont("Common Normal") .. {
			Name = "NearestGrade",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 16, pad + 206):zoom(0.42):diffuse(dimText):diffusealpha(0)
			end,
			OnCommand = function(self)
				if data.getNearestGrade then
					self:settext(data.getNearestGrade() or "")
				end
				self:sleep(0.45):linear(0.2):diffusealpha(1)
			end
		}
	},

	-- ============================================================
	-- RIGHT PANEL: JUDGMENTS & OFFSET TIMING CARD
	-- ============================================================
	Def.ActorFrame {
		Name = "RightPanel",
		InitCommand = function(self)
			self:xy(rightX + 50, frameY):diffusealpha(0)
		end,
		OnCommand = function(self)
			self:sleep(0.25):linear(0.4):x(rightX):diffusealpha(1)
		end,

		-- Right Card BG
		Def.Quad {
			Name = "RightBackground",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(rightW, frameH):diffuse(bgCard):diffusealpha(0)
			end,
			OnCommand = function(self)
				self:sleep(0.05):linear(0.35):diffusealpha(0.7):x(0)
			end
		},

		-- Judgments Category Header
		LoadFont("Common Normal") .. {
			Name = "JudgmentsHeader",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, 14):zoom(0.46):diffuse(subText):diffusealpha(0)
					:settext(THEME:GetString("ScreenEvaluation", "CategoryJudgment"))
			end,
			OnCommand = function(self)
				self:sleep(0.2):linear(0.25):diffusealpha(1)
			end
		},

		-- Judgment Rows Tally
		judgmentRows,

		-- Divider between Judgments and Offset Plot
		Def.Quad {
			Name = "RightDivider",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, 192):zoomto(rightW - pad * 2, 1):diffuse(dividerColor):diffusealpha(0)
			end,
			OnCommand = function(self)
				self:sleep(0.25):linear(0.25):diffusealpha(1)
			end
		},

		-- Offset Plot Container
		Def.ActorFrame {
			Name = "OffsetPlot",
			InitCommand = function(self) self:xy(0, 204) end,

			-- Offset Category Header
			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:xy(pad, 0):zoom(0.46):halign(0):diffuse(subText):diffusealpha(0)
						:settext(THEME:GetString("ScreenEvaluation", "CategoryOffset"))
				end,
				OnCommand = function(self)
					self:sleep(0.25):linear(0.25):diffusealpha(1)
				end
			},

			-- Offset Graph
			LoadActor(THEME:GetPathG("", "OffsetGraph")) .. {
				InitCommand = function(self) self:xy(10, 26) end,
				OnCommand = function(self)
					self:RunCommandsOnChildren(function(child)
						child:playcommand("Update", data.getOffsetData())
					end)
				end,
				SetJudgeMessageCommand = function(self)
					self:RunCommandsOnChildren(function(child)
						child:playcommand("Update", data.getOffsetData())
					end)
				end,
				ManiaModeChangedMessageCommand = function(self) self:playcommand("SetJudge") end,
				LoadedCustomWindowMessageCommand = function(self) self:playcommand("SetJudge") end,
				UnloadedCustomWindowMessageCommand = function(self) self:playcommand("SetJudge") end,
			}
		}
	}
}

return t
