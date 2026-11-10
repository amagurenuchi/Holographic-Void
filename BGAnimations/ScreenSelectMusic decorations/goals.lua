--- Holographic Void: Goals Tab

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local bgCard = color("0.04,0.04,0.04,0.97")

local overlayW = 680
local overlayH = 400
local rowH = 34
local numGoals = 8
local ind = 0 -- scroll offset
local goalsActor = nil
local whee = nil
local goaltable = {}

local function GetProfile()
	return GetPlayerOrMachineProfile(PLAYER_1) or PROFILEMAN:GetProfile(PLAYER_1)
end

local function RefreshGoals()
	goaltable = {}
	local profile = GetProfile()
	if profile then
		pcall(function() profile:SetFromAll() end)
		local ok, gt = pcall(function() return profile:GetGoalTable() end)
		if ok and gt then goaltable = gt end
	end
end

-- Granular score adjustment logic (Benchmarks for display coloring)
local benchmarks = {0.99, 0.997, 0.99955, 0.999935, 1.0}

local function formatGoalPercent(pct)
	local p = notShit.round(pct * 100, 5)
	if p < 99 then
		return string.format("%.2f%%", p)
	elseif p < 99.7 then
		return string.format("%.2f%%", p)
	elseif p < 99.955 then
		return string.format("%.3f%%", p)
	elseif p < 99.9935 then
		return string.format("%.4f%%", p)
	else
		return string.format("%.5f%%", p)
	end
end

local t = Def.ActorFrame {
	Name = "GoalsOverlay",
	InitCommand = function(self)
		goalsActor = self
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false)
	end,
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen and screen.GetMusicWheel then whee = screen:GetMusicWheel() end
	end,
	SelectMusicTabChangedMessageCommand = function(self, params)
		if params.Tab == "GOALS" then
			self:visible(not self:GetVisible())
			if self:GetVisible() then
				self:stoptweening():diffusealpha(0):linear(0.2):diffusealpha(1)
				HV.ActiveTab = "GOALS"
				ind = 0
				RefreshGoals()
			else
				HV.ActiveTab = ""
			end
		else
			self:visible(false)
			if HV.ActiveTab == "GOALS" then HV.ActiveTab = "" end
		end
		self:playcommand("GoalTableRefresh")
	end,
	NextGoalPageMessageCommand = function(self)
		ind = math.max(0, math.min(#goaltable - numGoals, ind + 1 * numGoals))
		self:playcommand("GoalTableRefresh")
	end,
	PrevGoalPageMessageCommand = function(self)
		ind = math.max(0, math.min(#goaltable - numGoals, ind - 1 * numGoals))
		self:playcommand("GoalTableRefresh")
	end,

	-- Glassmorphism Background
	Def.Quad { 
		InitCommand = function(self) 
			self:zoomto(overlayW, overlayH):diffuse(bgCard)
				:diffusealpha(0.98)
		end 
	},
	-- Subtle Glow Border
	Def.Quad { 
		InitCommand = function(self) 
			self:valign(0):y(-overlayH/2):zoomto(overlayW, 1):diffuse(accentColor):diffusealpha(0.4) 
		end 
	},
	Def.Quad { 
		InitCommand = function(self) 
			self:valign(1):y(overlayH/2):zoomto(overlayW, 1):diffuse(accentColor):diffusealpha(0.2) 
		end 
	},

	-- Title
	LoadFont("Common Normal") .. {
		Name = "Title",
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 24, -overlayH/2 + 18):zoom(0.55):diffuse(accentColor)
		end,
		GoalTableRefreshCommand = function(self)
			self:settextf(THEME:GetString("Goals", "Title"), #goaltable)
		end,
	},

	-- Add Goal button
	Def.ActorFrame {
		Name = "AddGoalBtn",
		InitCommand = function(self) self:xy(overlayW/2 - 85, -overlayH/2 + 28) end,
		Def.Quad { 
			InitCommand = function(self) 
				self:zoomto(110, 28):diffuse(accentColor):diffusealpha(0.12)
					:blend(Blend.Add)
			end 
		},
		Def.Quad { 
			InitCommand = function(self) 
				self:zoomto(110, 1):valign(1):y(14):diffuse(accentColor):diffusealpha(0.5)
			end 
		},
		LoadFont("Common Normal") .. { 
			InitCommand = function(self) 
				self:zoom(0.32):diffuse(brightText):settext(THEME:GetString("Goals", "AddGoal")) 
			end 
		},
	},

	-- Page indicator
	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self)
			self:halign(1):valign(0):xy(overlayW/2 - 16, -overlayH/2 + 38):zoom(0.22):diffuse(dimText)
		end,
		GoalTableRefreshCommand = function(self)
			if #goaltable > 0 then
				self:settextf("%d-%d / %d", ind + 1, math.min(ind + numGoals, #goaltable), #goaltable)
			else
				self:settext(THEME:GetString("Goals", "NoGoals"))
			end
		end,
	},

	-- Column Headers
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-overlayW/2 + 24, -overlayH/2 + 52) end,

		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0.5):x(45):zoom(0.35):diffuse(accentColor):settext(THEME:GetString("Goals", "PriorityColumn")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(85):zoom(0.4):diffuse(accentColor):settext(THEME:GetString("Goals", "SongColumn")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0.5):x(395):zoom(0.35):diffuse(accentColor):settext("MSD") end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0.5):x(445):zoom(0.35):diffuse(accentColor):settext(THEME:GetString("Goals", "RateColumn")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0.5):x(500):zoom(0.35):diffuse(accentColor):settext(THEME:GetString("Goals", "TargetColumn")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0.5):x(560):zoom(0.35):diffuse(accentColor):settext(THEME:GetString("Goals", "PBColumn") or "PB") end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0.5):x(620):zoom(0.35):diffuse(accentColor):settext(THEME:GetString("Goals", "StatusColumn")) end },
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 20, -overlayH/2 + 65)
				:zoomto(overlayW - 40, 1):diffuse(color("0.15,0.15,0.15,1"))
		end,
	},
}

-- Row drawing
local rowStartY = -overlayH/2 + 65

local function makeGoalRow(i)
	local sg, ck, goalsong, goalsteps

	local row = Def.ActorFrame {
		Name = "GoalRow_" .. i,
		InitCommand = function(self)
			self:xy(-overlayW/2 + 24, rowStartY + (i - 1) * rowH)
		end,
		GoalTableRefreshCommand = function(self)
			sg = goaltable[i + ind]
			if sg then
				ck = sg:GetChartKey()
				goalsong = SONGMAN:GetSongByChartKey(ck)
				goalsteps = SONGMAN:GetStepsByChartKey(ck)
				self:visible(true)
			else
				self:visible(false)
			end
		end,

		-- Row Highlight Quad
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(overlayW - 48, rowH - 4)
					:diffuse(color("1,1,1,0.03"))
			end,
			GoalTableRefreshCommand = function(self)
				if sg then
					if sg:IsAchieved() then
						self:diffuse(color("0.1,0.5,0.1,0.15"))
					elseif sg:IsVacuous() then
						self:diffuse(color("0.4,0.4,0.1,0.15"))
					else
						self:diffuse(color("1,1,1,0.03"))
					end
				end
			end,
		},

		-- Delete button (Hoverable style)
		LoadActor(THEME:GetPathG("", "delete")) .. {
			Name = "DeleteBtn",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):x(15):y(rowH/2 - 2):zoom(0.25):diffuse(color("0.8,0.2,0.2,0.6"))
			end,
		},

		-- Priority
		LoadFont("Common Normal") .. {
			Name = "Priority",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(45):y(rowH/2 - 2):zoom(0.42):diffuse(mainText) end,
			GoalTableRefreshCommand = function(self)
				if sg then self:settextf("%d", sg:GetPriority()) else self:settext("") end
			end,
		},

		-- Song & Difficulty
		Def.ActorFrame {
			Name = "SongDetails",
			InitCommand = function(self) self:xy(85, rowH/2 - 2) end,
			
			LoadFont("Common Normal") .. {
				Name = "SongName",
				InitCommand = function(self)
					self:halign(0):zoom(0.5):diffuse(brightText):maxwidth(290 / 0.5)
				end,
				GoalTableRefreshCommand = function(self)
					if sg then
						if goalsong then self:settext(goalsong:GetDisplayMainTitle())
						else self:settext(THEME:GetString("Goals", "SongMissing")):diffuse(color("1,0.3,0.3,1")) end
					end
				end,
			},
			LoadFont("MSD 20px") .. {
				Name = "MSD",
				InitCommand = function(self) self:halign(0.5):x(310):y(0):zoom(0.32) end,
				GoalTableRefreshCommand = function(self)
					if sg and goalsteps then
						local msd = goalsteps:GetMSD(sg:GetRate(), 1)
						self:settext(string.format("%.2f", msd)):diffuse(HVColor.GetMSDRatingColor(msd))
					else
						self:settext("")
					end
				end,
			},
		},

		-- Rate
		LoadFont("Common Normal") .. {
			Name = "Rate",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(445):y(rowH/2 - 2):zoom(0.42):diffuse(subText) end,
			GoalTableRefreshCommand = function(self)
				if sg then self:settextf("%.2fx", sg:GetRate()) end
			end,
		},

		-- Target % (Granular)
		LoadFont("Common Normal") .. {
			Name = "Target",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(500):y(rowH/2 - 2):zoom(0.4):diffuse(brightText) end,
			GoalTableRefreshCommand = function(self)
				if sg then self:settext(formatGoalPercent(sg:GetPercent())) end
			end,
		},

		-- PB
		LoadFont("Common Normal") .. {
			Name = "PB",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(560):y(rowH/2 - 2):zoom(0.38) end,
			GoalTableRefreshCommand = function(self)
				if sg then
					local pb = sg:GetPBUpTo()
					if pb then
						local pbc = pb:GetWifeScore() * 100
						self:settextf("%.2f%%", pbc):diffuse(sg:IsAchieved() and color("0.4,1,0.4,1") or subText)
					else
						self:settext("-"):diffuse(dimText)
					end
				end
			end,
		},

		-- Status Label (Moved left slightly)
		LoadFont("Common Normal") .. {
			Name = "Status",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(620):y(rowH/2 - 2):zoom(0.35) end,
			GoalTableRefreshCommand = function(self)
				if sg then
					if sg:IsVacuous() then self:settext(THEME:GetString("Goals", "Vacuous")):diffuse(color("0.9,0.9,0.3,1"))
					elseif sg:IsAchieved() then self:settext(THEME:GetString("Goals", "Achieved")):diffuse(color("0.4,1,0.4,1"))
					else self:settext(THEME:GetString("Goals", "Pending")):diffuse(color("1,0.6,0.2,1")) end
				end
			end,
		},
	}

	return row
end

for i = 1, numGoals do
	t[#t + 1] = makeGoalRow(i)
end

-- Input handler
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		screen:AddInputCallback(function(event)
			if not goalsActor or not goalsActor:GetVisible() then return false end
			if not event or not event.DeviceInput then return true end
			
			local btn = event.DeviceInput.button or ""
			local evType = event.type
			local isRight = btn == "DeviceButton_right mouse button"
			local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
			
			if evType == "InputEventType_Release" then return true end

			-- Add Goal Button (Top Right)
			if btn == "DeviceButton_left mouse button" and evType == "InputEventType_FirstPress" then
				local btnCX = SCREEN_CENTER_X + (overlayW / 2) - 85
				local btnCY = SCREEN_CENTER_Y - (overlayH / 2) + 28
				if mx >= btnCX - 55 and mx <= btnCX + 55 and my >= btnCY - 14 and my <= btnCY + 14 then
					local steps = GAMESTATE:GetCurrentSteps()
					local profile = GetProfile()
					if steps and profile then
						local ck = steps:GetChartKey()
						if ck then
							local sg = profile:AddGoal(ck)
							-- AddGoal might return true or a scoregoal object
							if not sg or type(sg) == "boolean" then
								local gt = profile:GetGoalTable()
								for _, g in ipairs(gt) do if g:GetChartKey() == ck then sg = g; break end end
							end
							if sg and type(sg) ~= "boolean" then
								sg:SetPercent(0.93)
								sg:SetRate(getCurRateValue() or 1.0)
								sg:SetPriority(0)
								pcall(function() profile:SetFromAll() end)
							end
							RefreshGoals()
							goalsActor:playcommand("GoalTableRefresh")
						end
					end
					return true
				end
			end

			-- Scroll (Now routed via global TabNavigation in default.lua)

			-- Row Clicks
			if btn == "DeviceButton_left mouse button" or btn == "DeviceButton_right mouse button" then
				if mx < SCREEN_CENTER_X - overlayW/2 or mx > SCREEN_CENTER_X + overlayW/2 or my < SCREEN_CENTER_Y - overlayH/2 or my > SCREEN_CENTER_Y + overlayH/2 then
					if evType ~= "InputEventType_FirstPress" then return true end
					MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
					return true
				end

				for ri = 1, numGoals do
					local rowTop = SCREEN_CENTER_Y + rowStartY + (ri - 1) * rowH
					local rowLeft = SCREEN_CENTER_X - overlayW/2 + 24
					if my >= rowTop and my <= rowTop + rowH then
						local gIdx = ri + ind
						if gIdx <= #goaltable then
							local sg = goaltable[gIdx]
							local hx = mx - rowLeft

							-- Delete
							if hx >= 0 and hx <= 35 then
								if not isRight then
									pcall(function() sg:Delete() end)
									pcall(function() GetProfile():SetFromAll() end)
									RefreshGoals()
									if whee then whee:RebuildWheelItems() end
									goalsActor:playcommand("GoalTableRefresh")
								end
								return true
							end

							-- Priority
							if hx >= 35 and hx <= 75 then
								local p = sg:GetPriority()
								pcall(function() sg:SetPriority(isRight and p - 1 or p + 1) end)
								goalsActor:playcommand("GoalTableRefresh")
								return true
							end

							-- Rate (Task 3: Constraints + Infinite spawning fix)
							if hx >= 360 and hx <= 410 then
								easyInputStringOKCancel(THEME:GetString("Goals", "RateLabel"), 4, false, function(answer)
									local r = tonumber(answer)
									if r then
										-- Task 3.1: Validation Warnings
										local invalid = false
										if r < 0.05 or r > 3.0 then
											ms.ok("Rate must be between 0.05 and 3.0")
											invalid = true
										elseif math.abs(r*20 - math.floor(r*20 + 0.5)) > 0.0001 then
											ms.ok("Rate must be a multiple of 0.05")
											invalid = true
										end
										
										if invalid then return end

										local oldRate = sg:GetRate()
										if math.abs(r - oldRate) > 0.001 then
											-- FIX: If rate changes, delete old one and create new one to avoid "spawning" duplicates
											local ck = sg:GetChartKey()
											local pct = sg:GetPercent()
											local prio = sg:GetPriority()
											
											pcall(function() sg:Delete() end)
											local profile = GetProfile()
											if profile then
												local newSg = profile:AddGoal(ck)
												-- Handle newSg being a boolean (true) or a scoregoal object
												if not newSg or type(newSg) == "boolean" then
													local gt = profile:GetGoalTable()
													for _, g in ipairs(gt) do
														if g:GetChartKey() == ck then
															newSg = g
															break
														end
													end
												end

												if newSg and type(newSg) ~= "boolean" then
													newSg:SetRate(r)
													newSg:SetPercent(pct)
													newSg:SetPriority(prio)
												end
											end
										else
											pcall(function() sg:SetRate(r) end)
										end
										RefreshGoals()
										goalsActor:playcommand("GoalTableRefresh")
									end
								end)
								return true
							end

							-- Target % (The request: Direct overlay entry)
							if hx >= 410 and hx <= 510 then
								easyInputStringOKCancel(THEME:GetString("Goals", "TargetLabel"), 10, false, function(answer)
									local p = tonumber((answer:gsub("%%", "")))
									if p then
										-- Fix: Round to 6 decimal places before storing to avoid floating-point truncation issues
										-- This ensures values like 99.35% don't get corrupted by FP representation errors
										local clamped = math.max(0, math.min(100.0, p))
										local rounded = notShit.round(clamped, 6) / 100
										pcall(function() sg:SetPercent(rounded) end)
										goalsActor:playcommand("GoalTableRefresh")
									end
								end)
								return true
							end

							-- Song click find
							if hx >= 75 and hx <= 360 and not isRight then
								local ck = sg:GetChartKey()
								if ck then
									local song = SONGMAN:GetSongByChartKey(ck)
									if song and whee then whee:SelectSong(song) end
								end
								MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
								return true
							end
						end
						return true
					end
				end
				return true
			end

			if event.button == "Back" or event.DeviceInput.button == "DeviceButton_escape" then
				MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
				return true
			end
			return false
		end)
	end,
}

return t
