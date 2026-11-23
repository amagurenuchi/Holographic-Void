local practiceMode = GAMESTATE:IsPracticeMode()
local pn = GAMESTATE:GetEnabledPlayers()[1] or PLAYER_1

if not practiceMode then
	return Def.ActorFrame {}
end

HV = HV or {}
HV.PracticeLoopStart = 0
HV.PracticeLoopEnd = 0
HV.PracticeLoopBestScore = nil
HV.PracticeLoopCurrentScore = nil

local prevZoom = 0.65
local musicratio = 1
local wodth = 300
local hidth = 40
local loopStartPos
local loopEndPos
local lastCoinPressAt = 0
local lastCoinWasPaused = false
local doubleCoinWindow = 0.35
local graphWidth = wodth * prevZoom
local loopAttemptScores = {}
local loopWifePoints, loopTapCount = 0, 0
local loopAttemptValid = true
local awaitingLoopStart = false
local lastObservedSongPos
local wasPaused = false
local awaitingPracticeSeek = false
local justCompletedLoop = false

local function hasPracticeLoop()
	return tonumber(HV.PracticeLoopEnd) and tonumber(HV.PracticeLoopStart)
		and HV.PracticeLoopEnd > HV.PracticeLoopStart
end

local function resetLoopAttempt(valid)
	loopWifePoints, loopTapCount = 0, 0
	loopAttemptValid = valid ~= false
	HV.PracticeLoopCurrentScore = nil
	MESSAGEMAN:Broadcast("PracticeLoopScoreUpdated")
end

local function currentLoopWifePercent()
	if loopTapCount == 0 then return 100 end
	return math.max(0, math.min(100, loopWifePoints / (loopTapCount * 2) * 100))
end

local function updateLoopGraphs()
	MESSAGEMAN:Broadcast("PracticeLoopGraphUpdated")
end

local function appendLoopAttempt()
	if loopAttemptValid then
		local score = currentLoopWifePercent()
		loopAttemptScores[#loopAttemptScores + 1] = score
		while #loopAttemptScores > 40 do table.remove(loopAttemptScores, 1) end
		if not HV.PracticeLoopBestScore or score > HV.PracticeLoopBestScore then
			HV.PracticeLoopBestScore = score
			MESSAGEMAN:Broadcast("PracticeLoopBestChanged")
		end
	end
	updateLoopGraphs()
end

local function notify(message)
	if ms and ms.ok then
		ms.ok(message)
	end
end

local function getTop()
	return SCREENMAN:GetTopScreen()
end

local function getSongPos()
	local top = getTop()
	if top and top.GetSongPosition then
		local ok, pos = pcall(function() return top:GetSongPosition() end)
		if ok and type(pos) == "number" then return pos end
	end
	local sp = GAMESTATE:GetSongPosition()
	return sp and sp:GetMusicSeconds() or 0
end

local function setSongPos(pos, unpause)
	local top = getTop()
	if not top then return end
	pos = math.max(0, pos or 0)
	if unpause and top.SetSongPositionAndUnpause then
		local ok = pcall(function() top:SetSongPositionAndUnpause(pos, 1, true) end)
		if ok then return end
	end
	if top.SetSongPosition then
		pcall(function() top:SetSongPosition(pos, 0, false) end)
	end
end

local function seekPracticeSongPos(pos, unpause)
	setSongPos(pos, unpause)
	awaitingPracticeSeek = true
	-- This is a HUD reset boundary even when Etterna only seeks the music and
	-- leaves the current stage statistics intact.
	MESSAGEMAN:Broadcast("PracticeModeReload")
	MESSAGEMAN:Broadcast("PracticeAttemptInvalidated")
end

HV.SeekPracticeSongPosition = seekPracticeSongPos

local function isPaused()
	local top = getTop()
	if top and top.GetPaused then
		local ok, paused = pcall(function() return top:GetPaused() end)
		if ok then return paused and true or false end
	end
	return GAMESTATE:IsPaused() and true or false
end

local function pauseAtCurrentPos()
	local top = getTop()
	if not top then return end
	local pos = getSongPos()
	if top.TogglePause then
		if not isPaused() then
			setSongPos(pos, false)
		end
		pcall(function() top:TogglePause() end)
		MESSAGEMAN:Broadcast("PracticeAttemptInvalidated")
		if isPaused() then
			setSongPos(pos, false)
		end
	end
end

-- Direct reference to the graph Hitbox, set once actors are ready
local graphHitboxRef = nil

local function isMouseOverGraph()
	local hitbox = graphHitboxRef
	if not hitbox then return false end
	local width = hitbox:GetZoomedWidth()
	local height = hitbox:GetZoomedHeight()
	local left = hitbox:GetTrueX() - (width * hitbox:GetHAlign())
	local topY = hitbox:GetTrueY() - (height * hitbox:GetVAlign())
	local mouseX = INPUTFILTER:GetMouseX()
	local mouseY = INPUTFILTER:GetMouseY()
	return mouseX >= left and mouseX <= left + width and mouseY >= topY and mouseY <= topY + height
end

local function setNativeLoopRegion()
	local top = getTop()
	if not top then return end
	if loopStartPos and loopEndPos and top.SetLoopRegion then
		pcall(function() top:SetLoopRegion(loopStartPos, loopEndPos) end)
	elseif top.ResetLoopRegion then
		pcall(function() top:ResetLoopRegion() end)
	end
end

local function broadcastRegion(loopLength)
	HV.PracticeLoopStart = loopStartPos or 0
	HV.PracticeLoopEnd = loopEndPos or 0
	loopAttemptScores = {}
	HV.PracticeLoopBestScore = nil
	HV.PracticeLoopCurrentScore = nil
	if loopLength then
		MESSAGEMAN:Broadcast("RegionSet", {loopLength = loopLength})
	else
		MESSAGEMAN:Broadcast("RegionSet")
	end
	MESSAGEMAN:Broadcast("PracticeLoopChanged")
end

local function clearRegion()
	loopStartPos = nil
	loopEndPos = nil
	HV.PracticeLoopStart = 0
	HV.PracticeLoopEnd = 0
	local top = getTop()
	if top and top.ResetLoopRegion then
		pcall(function() top:ResetLoopRegion() end)
	end
	broadcastRegion()
end

local function resetLoopToBookmark()
	if not loopStartPos then return false end
	loopEndPos = nil
	local top = getTop()
	if top and top.ResetLoopRegion then
		pcall(function() top:ResetLoopRegion() end)
	end
	broadcastRegion()
	return true
end

local function handleRegionSetting(positionGiven)
	if not positionGiven or positionGiven < 0 then return end

	if not loopStartPos and not loopEndPos then
		loopStartPos = positionGiven
		broadcastRegion()
		return
	end

	if positionGiven == loopStartPos or positionGiven == loopEndPos then
		loopEndPos = nil
		loopStartPos = positionGiven
		local top = getTop()
		if top and top.ResetLoopRegion then
			pcall(function() top:ResetLoopRegion() end)
		end
		broadcastRegion()
		return
	end

	local startDiff = math.abs(positionGiven - loopStartPos)
	local endDiff = startDiff + 0.1
	if loopEndPos then
		endDiff = math.abs(positionGiven - loopEndPos)
	end

	if not loopEndPos then
		if loopStartPos < positionGiven then
			loopEndPos = positionGiven
		elseif loopStartPos > positionGiven then
			loopEndPos = loopStartPos
			loopStartPos = positionGiven
		else
			loopEndPos = nil
			loopStartPos = positionGiven
			local top = getTop()
			if top and top.ResetLoopRegion then
				pcall(function() top:ResetLoopRegion() end)
			end
			broadcastRegion()
			return
		end
	elseif startDiff < endDiff then
		loopStartPos = positionGiven
	else
		loopEndPos = positionGiven
	end

	setNativeLoopRegion()
	broadcastRegion(loopEndPos - loopStartPos)
end

local function frameStep(delta)
	local pos = getSongPos()
	local dir = 1
	local ps = GAMESTATE:GetPlayerState(PLAYER_1)
	if ps and ps.GetCurrentPlayerOptions and ps:GetCurrentPlayerOptions():UsingReverse() then
		dir = -1
	end
	local nextpos = pos + dir * delta
	if loopEndPos and nextpos >= loopEndPos then
		handleRegionSetting(nextpos + 1)
	end
	seekPracticeSongPos(nextpos, false)
end

local function handlePracticeCommand(name)
	local top = getTop()
	if not top then return end

	if name == "PracRateUp" then
		if top.AddToRate then pcall(function() top:AddToRate(0.05) end) else changeMusicRate(0.05) end
	elseif name == "PracRateDown" then
		if top.AddToRate then pcall(function() top:AddToRate(-0.05) end) else changeMusicRate(-0.05) end
	elseif name == "PracPause" then
		if top.TogglePause then
			top:TogglePause()
			MESSAGEMAN:Broadcast("PracticeAttemptInvalidated")
		end
	elseif name == "PracRestart" then
		seekPracticeSongPos(loopStartPos or 0, true)
	elseif name == "PracLoopStart" then
		handleRegionSetting(getSongPos())
		notify(string.format("Loop Start: %.2fs", loopStartPos or 0))
	elseif name == "PracLoopEnd" then
		handleRegionSetting(getSongPos())
		notify(string.format("Loop End: %.2fs", loopEndPos or loopStartPos or 0))
	elseif name == "PracLoopClear" then
		clearRegion()
		notify("Loop Cleared")
	elseif name == "PracClap" then
		local cur = PREFSMAN:GetPreference("CenterClap")
		PREFSMAN:SetPreference("CenterClap", not cur)
		notify("Clap: " .. (not cur and "ON" or "OFF"))
	elseif name == "PracMetronome" then
		local ps = GAMESTATE:GetPlayerState(PLAYER_1)
		local po = ps and ps:GetPlayerOptions("ModsLevel_Current")
		if po then
			local cur = po:AssistTick()
			po:AssistTick(not cur)
			notify("Metronome: " .. (not cur and "ON" or "OFF"))
		end
	elseif name == "PracAutoplay" then
		local cur = getAutoplay and getAutoplay() ~= 0
		GAMESTATE:SetAutoplay(not cur)
		notify("Autoplay: " .. (not cur and "ON" or "OFF"))
	end
end

local function duminput(event)
	if event.type == "InputEventType_FirstPress" then
		if event.DeviceInput and event.DeviceInput.button == "DeviceButton_right mouse button" then
			if not isMouseOverGraph() then
				pauseAtCurrentPos()
				return true
			end
		end
		if event.DeviceInput and event.DeviceInput.button == "DeviceButton_backspace" then
			if loopStartPos ~= nil then
				seekPracticeSongPos(loopStartPos, true)
			end
		elseif event.button == "Coin" then
			local now = os.clock()
			local paused = isPaused()
			if paused and lastCoinWasPaused and now - lastCoinPressAt <= doubleCoinWindow then
				if resetLoopToBookmark() then
					notify("Loop Reset to Bookmark")
				end
				lastCoinPressAt = 0
				lastCoinWasPaused = false
			else
				handleRegionSetting(getSongPos())
				lastCoinPressAt = now
				lastCoinWasPaused = paused
			end
		elseif event.DeviceInput and event.DeviceInput.button == "DeviceButton_mousewheel up" then
			if GAMESTATE:IsPaused() then frameStep(0.05) end
		elseif event.DeviceInput and event.DeviceInput.button == "DeviceButton_mousewheel down" then
			if GAMESTATE:IsPaused() then frameStep(-0.05) end
		end
	end
	return false
end

local function UpdatePreviewPos(self)
	local top = getTop()
	if not top then return end
	local songPos = getSongPos()
	local paused = isPaused()
	local changedBySeek = false
	if paused and not wasPaused then
		MESSAGEMAN:Broadcast("PracticeAttemptInvalidated")
	end
	if wasPaused and not paused then
		resetLoopAttempt(false)
		awaitingLoopStart = hasPracticeLoop()
		if hasPracticeLoop() and math.abs(songPos - HV.PracticeLoopStart) <= 0.5 then
			resetLoopAttempt(true)
			awaitingLoopStart = false
		end
		updateLoopGraphs()
	end
	wasPaused = paused
	if awaitingPracticeSeek and lastObservedSongPos and math.abs(songPos - lastObservedSongPos) > 0.05 then
		resetLoopAttempt(false)
		awaitingLoopStart = hasPracticeLoop()
		if hasPracticeLoop() and math.abs(songPos - HV.PracticeLoopStart) <= 0.5 then
			resetLoopAttempt(true)
			awaitingLoopStart = false
		end
		awaitingPracticeSeek = false
		changedBySeek = true
		updateLoopGraphs()
	end
	if lastObservedSongPos and songPos < lastObservedSongPos - 0.25 then
		local looped = hasPracticeLoop()
			and lastObservedSongPos >= HV.PracticeLoopEnd - 0.75
			and songPos <= HV.PracticeLoopStart + 1.0
		if looped and not changedBySeek and not justCompletedLoop then
			-- The new loop attempt begins at the loop start. Reset gameplay HUD
			-- calculations at this boundary just as we do for a manual seek.
			MESSAGEMAN:Broadcast("PracticeModeReload")
		end
		if looped and not changedBySeek then
			if not justCompletedLoop then appendLoopAttempt() end
			justCompletedLoop = false
			resetLoopAttempt(true)
			awaitingLoopStart = false
		else
			resetLoopAttempt(false)
			awaitingLoopStart = hasPracticeLoop()
		end
		updateLoopGraphs()
	end
	if awaitingLoopStart and not paused and hasPracticeLoop()
		and math.abs(songPos - HV.PracticeLoopStart) <= 0.5 then
		resetLoopAttempt(true)
		awaitingLoopStart = false
		updateLoopGraphs()
	end
	lastObservedSongPos = songPos
	local pos = songPos / musicratio * prevZoom
	local marker = self:GetChild("CurrentPos")
	if marker then marker:x(pos) end

	local hoverMarker = self:GetChild("HoverMarker")
	local hitbox = self:GetChild("Hitbox")
	if hoverMarker and hitbox then
		local width = hitbox:GetZoomedWidth()
		local height = hitbox:GetZoomedHeight()
		local left = hitbox:GetTrueX() - (width * hitbox:GetHAlign())
		local topY = hitbox:GetTrueY() - (height * hitbox:GetVAlign())
		local mouseX = INPUTFILTER:GetMouseX()
		local mouseY = INPUTFILTER:GetMouseY()

		if mouseX >= left and mouseX <= left + width and mouseY >= topY and mouseY <= topY + height then
			hoverMarker:visible(true):x(mouseX - left)
		else
			hoverMarker:visible(false)
		end
	end
end

local loopCardW, loopCardH = 236, 102
local loopPlotW, loopPlotH = 214, 48
local gradeBandThresholds = {93, 96.5, 99.7, 99.955, 99.9935}

local function wifePercentToGraphPosition(percent)
	percent = math.max(0, math.min(100, tonumber(percent) or 0))
	local lower = 0
	local bandHeight = 1 / (#gradeBandThresholds)
	for i, threshold in ipairs(gradeBandThresholds) do
		if percent <= threshold then
			local portion = threshold > lower and (percent - lower) / (threshold - lower) or 1
			return ((i - 1) + portion) * bandHeight
		end
		lower = threshold
	end
	return 1
end

local function withAlpha(c, a)
	if not c then return {1, 1, 1, a or 1} end
	return {c[1] or 1, c[2] or 1, c[3] or 1, a or 1}
end

local function safeGrade(percent)
	if getEtternaGrade then
		local ok, g = pcall(getEtternaGrade, percent)
		if ok and g then return g end
	end
	return "Tier16"
end

local function safeGradeColor(percent)
	local g = safeGrade(percent)
	if HVColor and HVColor.GetGradeColor then
		local ok, c = pcall(HVColor.GetGradeColor, g)
		if ok and c then return c end
	end
	return color("1,1,1,1")
end

local function getGradeShort(wife)
	local p = tonumber(wife) or 0
	if p >= 99.9935 then return "AAAAA"
	elseif p >= 99.955 then return "AAAA"
	elseif p >= 99.70 then return "AAA"
	elseif p >= 93.00 then return "AA"
	elseif p >= 80.00 then return "A"
	elseif p >= 70.00 then return "B"
	elseif p >= 60.00 then return "C"
	elseif p >= 0 then return "D"
	else return "F" end
end

local function makePracticeLoopGraph(name, label, xValue, yValue, button, valuesFn)
	local bestScoreCache = nil
	local lastHoverIdx = nil
	local hoverElapsed = 0

	local function updateHover(self, delta)
		hoverElapsed = hoverElapsed + (delta or 0)
		if hoverElapsed < 0.033 then return end
		hoverElapsed = 0

		if not self:GetVisible() or not INPUTFILTER then return end
		local values = valuesFn and valuesFn() or {}
		local count = #values
		local plot = self:GetChild("PlotArea")
		local bottomArea = self:GetChild("BottomArea")

		if count == 0 then
			if lastHoverIdx ~= nil then
				lastHoverIdx = nil
				if plot then
					local hl = plot:GetChild("HoverLine")
					local hm = plot:GetChild("HoverMarker")
					if hl then hl:visible(false) end
					if hm then hm:visible(false) end
				end
				self:playcommand("UpdateDefaultStatus")
			end
			return
		end

		local mx = INPUTFILTER:GetMouseX()
		local my = INPUTFILTER:GetMouseY()
		if not mx or not my then return end

		local zoom = self:GetZoom() or 1
		local halfW = (loopPlotW / 2) * zoom
		local halfH = (loopPlotH / 2) * zoom
		local cx = self:GetTrueX()
		local cy = self:GetTrueY() + (13 * zoom)
		local left, right = cx - halfW, cx + halfW
		local top, bottom = cy - halfH, cy + halfH

		if mx >= left and mx <= right and my >= top and my <= bottom then
			local ratio = math.max(0, math.min(1, (mx - left) / (loopPlotW * zoom)))
			local hoverIdx = count == 1 and 1 or (math.floor(ratio * (count - 1) + 0.5) + 1)
			hoverIdx = math.max(1, math.min(count, hoverIdx))

			if hoverIdx ~= lastHoverIdx then
				lastHoverIdx = hoverIdx
				local val = tonumber(values[hoverIdx]) or 0
				local normY = wifePercentToGraphPosition(val)
				local hx = count > 1 and (-loopPlotW / 2 + ((hoverIdx - 1) / (count - 1)) * loopPlotW) or 0
				local hy = (loopPlotH / 2) - normY * loopPlotH
				local col = safeGradeColor(val)

				if plot then
					local hl = plot:GetChild("HoverLine")
					local hm = plot:GetChild("HoverMarker")
					if hl then hl:visible(true):x(hx) end
					if hm then
						hm:visible(true):xy(hx, hy)
						local halo = hm:GetChild("Halo")
						if halo then halo:diffuse(col):diffusealpha(0.4) end
					end
				end

				local statusText = bottomArea and bottomArea:GetChild("StatusText")
				if statusText then
					statusText:settext(string.format("Loop #%d: %.2f%% (%s)", hoverIdx, val, getGradeShort(val)))
						:diffuse(col)
				end
			end
		elseif lastHoverIdx ~= nil then
			lastHoverIdx = nil
			if plot then
				local hl = plot:GetChild("HoverLine")
				local hm = plot:GetChild("HoverMarker")
				if hl then hl:visible(false) end
				if hm then hm:visible(false) end
			end
			self:playcommand("UpdateDefaultStatus")
		end
	end

	return Def.ActorFrame {
		Name = name,
		InitCommand = function(self)
			local x = (MovableValues and MovableValues[xValue]) or getDefaultGameplayCoordinate(xValue) or SCREEN_RIGHT - 210
			local y = (MovableValues and MovableValues[yValue]) or getDefaultGameplayCoordinate(yValue) or SCREEN_TOP + 100
			self:xy(x, y):visible(hasPracticeLoop())
			self:SetUpdateFunction(updateHover)
		end,
		OnCommand = function(self)
			setMovableActor({button}, self, self:GetChild("Border"))
		end,
		PracticeLoopChangedMessageCommand = function(self)
			self:visible(hasPracticeLoop())
			loopAttemptScores = {}
			resetLoopAttempt(not hasPracticeLoop())
			awaitingLoopStart = hasPracticeLoop()
			justCompletedLoop = false
			lastHoverIdx = nil
			self:playcommand("RefreshGraph")
		end,
		PracticeLoopGraphUpdatedMessageCommand = function(self) self:playcommand("RefreshGraph") end,
		PracticeAttemptInvalidatedMessageCommand = function(self)
			loopAttemptValid = false
			awaitingLoopStart = hasPracticeLoop()
			loopWifePoints, loopTapCount = 0, 0
			HV.PracticeLoopCurrentScore = nil
			MESSAGEMAN:Broadcast("PracticeLoopScoreUpdated")
			self:playcommand("RefreshGraph")
		end,
		UpdateDefaultStatusCommand = function(self)
			local values = valuesFn and valuesFn() or {}
			local count = #values
			local bottomArea = self:GetChild("BottomArea")
			local statusText = bottomArea and bottomArea:GetChild("StatusText")
			if not statusText then return end

			if count == 0 then
				statusText:settext("Play a loop to record Wife scores"):diffuse(HVColor.TextDim or color("0.45,0.45,0.45,1"))
			elseif count == 1 then
				local v = tonumber(values[1]) or 0
				statusText:settext(string.format("Loop #1: %.2f%% (%s)", v, getGradeShort(v)))
					:diffuse(safeGradeColor(v))
			else
				local last = tonumber(values[count]) or 0
				local prev = tonumber(values[count - 1]) or 0
				local diff = last - prev
				local sign = diff > 0 and "+" or ""
				local trendCol
				if diff > 0.005 then
					trendCol = HVColor.Positive or color("#A0CFAB")
				elseif diff < -0.005 then
					trendCol = HVColor.Negative or color("#CF9898")
				else
					trendCol = HVColor.TextSub or color("0.65,0.65,0.65,1")
				end
				statusText:settext(string.format("Trend: %s%.2f%% vs prev  (PB: %.2f%%)", sign, diff, bestScoreCache or last))
					:diffuse(trendCol)
			end
		end,
		RefreshGraphCommand = function(self)
			local values = valuesFn and valuesFn() or {}
			local count = #values
			local accent = HVColor.Accent or color("#5ABAFF")
			local dimText = HVColor.TextDim or color("0.45,0.45,0.45,1")
			local subText = HVColor.TextSub or color("0.65,0.65,0.65,1")

			local bestScore, bestIdx = nil, nil
			local scoreSum = 0
			for i, v in ipairs(values) do
				local val = tonumber(v) or 0
				scoreSum = scoreSum + val
				if not bestScore or val > bestScore then
					bestScore = val
					bestIdx = i
				end
			end
			bestScoreCache = bestScore
			local avgScore = count > 0 and (scoreSum / count) or nil
			local lastScore = count > 0 and (tonumber(values[count]) or 0) or nil

			local isLive = hasPracticeLoop() and loopAttemptValid and not isPaused() and loopTapCount > 0
			local liveScore = isLive and currentLoopWifePercent() or nil

			-- Update header badge
			local badge = self:GetChild("CountBadge")
			if badge then
				if count == 0 then
					badge:settext("0 LOOPS"):diffuse(dimText)
				elseif count == 1 then
					badge:settext("1 LOOP"):diffuse(subText)
				else
					badge:settext(count .. " LOOPS"):diffuse(accent)
				end
			end

			-- Update stats row
			local bestVal = self:GetChild("BestVal")
			if bestVal then
				if bestScore then
					bestVal:settext(string.format("%.2f%%", bestScore)):diffuse(safeGradeColor(bestScore))
				else
					bestVal:settext("--"):diffuse(dimText)
				end
			end

			local avgVal = self:GetChild("AvgVal")
			if avgVal then
				if avgScore then
					avgVal:settext(string.format("%.2f%%", avgScore)):diffuse(subText)
				else
					avgVal:settext("--"):diffuse(dimText)
				end
			end

			local lastLabel = self:GetChild("LastLabel")
			local lastVal = self:GetChild("LastVal")
			if lastLabel and lastVal then
				if isLive and liveScore then
					lastLabel:settext("LIVE"):diffuse(accent)
					lastVal:settext(string.format("%.2f%%", liveScore)):diffuse(safeGradeColor(liveScore))
				else
					lastLabel:settext("LAST"):diffuse(dimText)
					if lastScore then
						lastVal:settext(string.format("%.2f%%", lastScore)):diffuse(safeGradeColor(lastScore))
					else
						lastVal:settext("--"):diffuse(dimText)
					end
				end
			end

			-- Update plot area
			local plot = self:GetChild("PlotArea")
			if plot then
				local emptyState = plot:GetChild("EmptyState")
				local singleLine = plot:GetChild("SingleLine")
				local areaDrawer = plot:GetChild("AreaFill")
				local lineDrawer = plot:GetChild("GraphLine")
				local pointDrawer = plot:GetChild("Points")
				local bestMarker = plot:GetChild("BestMarker")
				local latestMarker = plot:GetChild("LatestMarker")
				local liveDot = plot:GetChild("LiveDot")

				if count == 0 then
					if emptyState then emptyState:visible(true) end
					if singleLine then singleLine:visible(false) end
					if areaDrawer then areaDrawer:visible(false) end
					if lineDrawer then lineDrawer:visible(false) end
					if pointDrawer then pointDrawer:visible(false) end
					if bestMarker then bestMarker:visible(false) end
					if latestMarker then latestMarker:visible(false) end
				elseif count == 1 then
					if emptyState then emptyState:visible(false) end
					if areaDrawer then areaDrawer:visible(false) end
					if lineDrawer then lineDrawer:visible(false) end

					local val1 = tonumber(values[1]) or 0
					local normY1 = wifePercentToGraphPosition(val1)
					local y1 = (loopPlotH / 2) - normY1 * loopPlotH
					local c1 = safeGradeColor(val1)

					if singleLine then
						singleLine:visible(true):y(y1):diffuse(c1):diffusealpha(0.35)
					end

					if pointDrawer then
						local dotVerts = {
							{{-2.5, y1 - 2.5, 0}, c1},
							{{ 2.5, y1 - 2.5, 0}, c1},
							{{ 2.5, y1 + 2.5, 0}, c1},
							{{-2.5, y1 + 2.5, 0}, c1}
						}
						pointDrawer:SetVertices(dotVerts)
						pointDrawer:SetDrawState {Mode = "DrawMode_Quads", First = 1, Num = 4}
						pointDrawer:visible(true)
					end

					if bestMarker then
						bestMarker:visible(true):xy(0, y1)
						local halo = bestMarker:GetChild("Halo")
						if halo then halo:diffuse(c1):diffusealpha(0.4) end
					end
					if latestMarker then latestMarker:visible(false) end
				else
					if emptyState then emptyState:visible(false) end
					if singleLine then singleLine:visible(false) end

					local verts = {}
					for i, sample in ipairs(values) do
						local x = -loopPlotW / 2 + ((i - 1) / (count - 1)) * loopPlotW
						local percent = tonumber(sample) or 0
						local normY = wifePercentToGraphPosition(percent)
						local y = (loopPlotH / 2) - normY * loopPlotH
						verts[#verts + 1] = {x = x, y = y, c = safeGradeColor(percent)}
					end

					-- Area fill beneath graph line
					if areaDrawer then
						local areaVerts = {}
						local baseY = loopPlotH / 2
						for i = 1, count - 1 do
							local p1 = verts[i]
							local p2 = verts[i + 1]
							areaVerts[#areaVerts + 1] = {{p1.x, p1.y, 0}, withAlpha(accent, 0.22)}
							areaVerts[#areaVerts + 1] = {{p2.x, p2.y, 0}, withAlpha(accent, 0.22)}
							areaVerts[#areaVerts + 1] = {{p2.x, baseY, 0}, withAlpha(accent, 0.02)}
							areaVerts[#areaVerts + 1] = {{p1.x, baseY, 0}, withAlpha(accent, 0.02)}
						end
						areaDrawer:SetVertices(areaVerts)
						areaDrawer:SetDrawState {Mode = "DrawMode_Quads", First = 1, Num = #areaVerts}
						areaDrawer:visible(true)
					end

					-- Graph line strip
					if lineDrawer then
						local lineVerts = {}
						for _, v in ipairs(verts) do
							lineVerts[#lineVerts + 1] = {{v.x, v.y, 0}, withAlpha(v.c, 0.95)}
						end
						lineDrawer:SetVertices(lineVerts)
						lineDrawer:SetDrawState {Mode = "DrawMode_LineStrip", First = 1, Num = #lineVerts}
						lineDrawer:visible(true)
					end

					-- Point quads
					if pointDrawer then
						local dotVerts = {}
						for _, v in ipairs(verts) do
							dotVerts[#dotVerts + 1] = {{v.x - 2, v.y - 2, 0}, v.c}
							dotVerts[#dotVerts + 1] = {{v.x + 2, v.y - 2, 0}, v.c}
							dotVerts[#dotVerts + 1] = {{v.x + 2, v.y + 2, 0}, v.c}
							dotVerts[#dotVerts + 1] = {{v.x - 2, v.y + 2, 0}, v.c}
						end
						pointDrawer:SetVertices(dotVerts)
						pointDrawer:SetDrawState {Mode = "DrawMode_Quads", First = 1, Num = #dotVerts}
						pointDrawer:visible(true)
					end

					-- Best attempt highlight marker
					if bestMarker and bestIdx and verts[bestIdx] then
						local bv = verts[bestIdx]
						bestMarker:visible(true):xy(bv.x, bv.y)
						local halo = bestMarker:GetChild("Halo")
						if halo then halo:diffuse(bv.c):diffusealpha(0.4) end
					end

					-- Latest attempt highlight marker
					if latestMarker and verts[count] then
						if bestIdx ~= count then
							local lv = verts[count]
							latestMarker:visible(true):xy(lv.x, lv.y)
							local ring = latestMarker:GetChild("Ring")
							if ring then ring:diffuse(lv.c):diffusealpha(0.4) end
						else
							latestMarker:visible(false)
						end
					end
				end

				-- Live attempt indicator dot
				if liveDot then
					if isLive and liveScore then
						local liveNormY = wifePercentToGraphPosition(liveScore)
						local liveY = (loopPlotH / 2) - liveNormY * loopPlotH
						local liveX = count > 0 and (loopPlotW / 2) or 0
						liveDot:visible(true):xy(liveX, liveY):diffuse(safeGradeColor(liveScore))
					else
						liveDot:visible(false)
					end
				end
			end

			-- Update bottom axis labels and default status
			local bottomArea = self:GetChild("BottomArea")
			if bottomArea then
				local axisLeft = bottomArea:GetChild("AxisLeft")
				local axisRight = bottomArea:GetChild("AxisRight")
				if axisLeft then axisLeft:visible(count > 1):settext("#1") end
				if axisRight then axisRight:visible(count > 1):settext("#" .. count) end
			end

			if lastHoverIdx == nil then
				self:playcommand("UpdateDefaultStatus")
			end
		end,

		-- Main Card Background
		Def.Quad {
			Name = "CardBg",
			InitCommand = function(self)
				self:zoomto(loopCardW, loopCardH):diffuse(color("0.03,0.035,0.05,0.92"))
			end
		},
		-- Top Accent Stripe
		Def.Quad {
			Name = "TopAccent",
			InitCommand = function(self)
				self:y(-loopCardH / 2 + 1):zoomto(loopCardW, 2):diffuse(HVColor.Accent or color("#5ABAFF"))
			end
		},
		-- Card Subtle Outer Borders
		Def.Quad {
			InitCommand = function(self)
				self:y(loopCardH / 2 - 0.5):zoomto(loopCardW, 1):diffuse(HVColor.Border or color("0.18,0.18,0.18,1")):diffusealpha(0.5)
			end
		},
		Def.Quad {
			InitCommand = function(self)
				self:x(-loopCardW / 2 + 0.5):zoomto(1, loopCardH):diffuse(HVColor.Border or color("0.18,0.18,0.18,1")):diffusealpha(0.5)
			end
		},
		Def.Quad {
			InitCommand = function(self)
				self:x(loopCardW / 2 - 0.5):zoomto(1, loopCardH):diffuse(HVColor.Border or color("0.18,0.18,0.18,1")):diffusealpha(0.5)
			end
		},

		-- Header Section
		Def.Quad {
			InitCommand = function(self)
				self:xy(-loopPlotW / 2 + 2, -38):zoomto(3, 11):diffuse(HVColor.Accent or color("#5ABAFF"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Title",
			Text = label:upper(),
			InitCommand = function(self)
				self:xy(-loopPlotW / 2 + 9, -38):halign(0):zoom(0.36):diffuse(HVColor.White or color("1,1,1,1"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "CountBadge",
			Text = "0 LOOPS",
			InitCommand = function(self)
				self:xy(loopPlotW / 2, -38):halign(1):zoom(0.32):diffuse(HVColor.TextDim or color("0.45,0.45,0.45,1"))
			end
		},

		-- Stats Summary Row (BEST | AVG | LAST/LIVE)
		LoadFont("Common Normal") .. {
			Name = "BestLabel",
			Text = "BEST",
			InitCommand = function(self)
				self:xy(-loopPlotW / 2, -22):halign(0):zoom(0.30):diffuse(HVColor.TextDim or color("0.45,0.45,0.45,1"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "BestVal",
			Text = "--",
			InitCommand = function(self)
				self:xy(-loopPlotW / 2 + 30, -22):halign(0):zoom(0.34):diffuse(HVColor.Text or color("0.85,0.85,0.85,1"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "AvgLabel",
			Text = "AVG",
			InitCommand = function(self)
				self:xy(-28, -22):halign(0):zoom(0.30):diffuse(HVColor.TextDim or color("0.45,0.45,0.45,1"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "AvgVal",
			Text = "--",
			InitCommand = function(self)
				self:xy(-4, -22):halign(0):zoom(0.34):diffuse(HVColor.TextSub or color("0.65,0.65,0.65,1"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "LastLabel",
			Text = "LAST",
			InitCommand = function(self)
				self:xy(44, -22):halign(0):zoom(0.30):diffuse(HVColor.TextDim or color("0.45,0.45,0.45,1"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "LastVal",
			Text = "--",
			InitCommand = function(self)
				self:xy(72, -22):halign(0):zoom(0.34):diffuse(HVColor.Text or color("0.85,0.85,0.85,1"))
			end
		},

		-- Plot Area Container
		Def.ActorFrame {
			Name = "PlotArea",
			InitCommand = function(self) self:xy(0, 13) end,

			-- Plot Background Box
			Def.Quad {
				Name = "PlotBg",
				InitCommand = function(self)
					self:zoomto(loopPlotW, loopPlotH):diffuse(color("0.015,0.018,0.025,0.7")):diffusealpha(0.85)
				end
			},
			Def.Quad {
				InitCommand = function(self)
					self:y(-loopPlotH / 2 + 0.5):zoomto(loopPlotW, 1):diffuse(color("1,1,1,0.06"))
				end
			},
			Def.Quad {
				InitCommand = function(self)
					self:y(loopPlotH / 2 - 0.5):zoomto(loopPlotW, 1):diffuse(color("1,1,1,0.06"))
				end
			},

			-- Grade Threshold Reference Lines (AAAA, AAA, AA)
			Def.Quad {
				Name = "LineAAAA",
				InitCommand = function(self)
					local y = (loopPlotH / 2) - 0.80 * loopPlotH
					self:y(y):zoomto(loopPlotW, 1):diffuse(safeGradeColor(99.955)):diffusealpha(0.16)
				end
			},
			LoadFont("Common Normal") .. {
				Text = "AAAA",
				InitCommand = function(self)
					local y = (loopPlotH / 2) - 0.80 * loopPlotH
					self:xy(loopPlotW / 2 - 2, y - 1):halign(1):zoom(0.24):diffuse(safeGradeColor(99.955)):diffusealpha(0.45)
				end
			},
			Def.Quad {
				Name = "LineAAA",
				InitCommand = function(self)
					local y = (loopPlotH / 2) - 0.60 * loopPlotH
					self:y(y):zoomto(loopPlotW, 1):diffuse(safeGradeColor(99.70)):diffusealpha(0.20)
				end
			},
			LoadFont("Common Normal") .. {
				Text = "AAA",
				InitCommand = function(self)
					local y = (loopPlotH / 2) - 0.60 * loopPlotH
					self:xy(loopPlotW / 2 - 2, y - 1):halign(1):zoom(0.24):diffuse(safeGradeColor(99.70)):diffusealpha(0.55)
				end
			},
			Def.Quad {
				Name = "LineAA",
				InitCommand = function(self)
					local y = (loopPlotH / 2) - 0.20 * loopPlotH
					self:y(y):zoomto(loopPlotW, 1):diffuse(safeGradeColor(93.00)):diffusealpha(0.16)
				end
			},
			LoadFont("Common Normal") .. {
				Text = "AA",
				InitCommand = function(self)
					local y = (loopPlotH / 2) - 0.20 * loopPlotH
					self:xy(loopPlotW / 2 - 2, y - 1):halign(1):zoom(0.24):diffuse(safeGradeColor(93.00)):diffusealpha(0.45)
				end
			},

			-- Empty State Message
			Def.ActorFrame {
				Name = "EmptyState",
				LoadFont("Common Normal") .. {
					Text = "AWAITING LOOP ATTEMPTS",
					InitCommand = function(self)
						self:y(-4):zoom(0.34):diffuse(HVColor.TextDim or color("0.45,0.45,0.45,1")):diffusealpha(0.7)
					end
				},
				LoadFont("Common Normal") .. {
					Text = "Practice repetitions will plot here",
					InitCommand = function(self)
						self:y(9):zoom(0.25):diffuse(HVColor.TextDim or color("0.45,0.45,0.45,1")):diffusealpha(0.45)
					end
				}
			},

			-- Single Attempt Line
			Def.Quad {
				Name = "SingleLine",
				InitCommand = function(self)
					self:zoomto(loopPlotW, 1):diffusealpha(0.35):visible(false)
				end
			},

			-- Area Gradient Fill
			Def.ActorMultiVertex {
				Name = "AreaFill",
				InitCommand = function(self) self:SetDrawState {Mode = "DrawMode_Quads"} end
			},

			-- Graph Line Strip
			Def.ActorMultiVertex {
				Name = "GraphLine",
				InitCommand = function(self) self:SetDrawState {Mode = "DrawMode_LineStrip"} end
			},

			-- Graph Attempt Data Points
			Def.ActorMultiVertex {
				Name = "Points",
				InitCommand = function(self) self:SetDrawState {Mode = "DrawMode_Quads"} end
			},

			-- Best Attempt Highlight
			Def.ActorFrame {
				Name = "BestMarker",
				InitCommand = function(self) self:visible(false) end,
				Def.Quad {
					Name = "Halo",
					InitCommand = function(self)
						self:zoomto(7, 7):rotationz(45):diffusealpha(0.4)
					end
				},
				Def.Quad {
					Name = "Core",
					InitCommand = function(self)
						self:zoomto(3, 3):rotationz(45):diffuse(HVColor.White or color("1,1,1,1"))
					end
				},
				LoadFont("Common Normal") .. {
					Text = "PB",
					InitCommand = function(self)
						self:y(-8):zoom(0.24):diffuse(HVColor.Accent or color("#5ABAFF"))
					end
				}
			},

			-- Latest Attempt Highlight
			Def.ActorFrame {
				Name = "LatestMarker",
				InitCommand = function(self) self:visible(false) end,
				Def.Quad {
					Name = "Ring",
					InitCommand = function(self)
						self:zoomto(6, 6):diffusealpha(0.4)
					end
				},
				Def.Quad {
					Name = "Dot",
					InitCommand = function(self)
						self:zoomto(2.5, 2.5):diffuse(HVColor.White or color("1,1,1,1"))
					end
				}
			},

			-- Live Dot during loop execution
			Def.Quad {
				Name = "LiveDot",
				InitCommand = function(self)
					self:zoomto(4.5, 4.5):rotationz(45):diffuse(HVColor.Accent or color("#5ABAFF")):visible(false)
				end
			},

			-- Hover Vertical Hairline
			Def.Quad {
				Name = "HoverLine",
				InitCommand = function(self)
					self:zoomto(1, loopPlotH):diffuse(HVColor.Accent or color("#5ABAFF")):diffusealpha(0.6):visible(false)
				end
			},

			-- Hover Ring / Marker
			Def.ActorFrame {
				Name = "HoverMarker",
				InitCommand = function(self) self:visible(false) end,
				Def.Quad {
					Name = "Halo",
					InitCommand = function(self)
						self:zoomto(8, 8):rotationz(45):diffusealpha(0.4)
					end
				},
				Def.Quad {
					Name = "Dot",
					InitCommand = function(self)
						self:zoomto(3, 3):rotationz(45):diffuse(HVColor.White or color("1,1,1,1"))
					end
				}
			}
		},

		-- Bottom Area (Axis Indicators + Status / Tooltip)
		Def.ActorFrame {
			Name = "BottomArea",
			InitCommand = function(self) self:y(44) end,

			LoadFont("Common Normal") .. {
				Name = "AxisLeft",
				Text = "#1",
				InitCommand = function(self)
					self:xy(-loopPlotW / 2, 0):halign(0):zoom(0.25):diffuse(HVColor.TextDim or color("0.45,0.45,0.45,1")):diffusealpha(0.5):visible(false)
				end
			},
			LoadFont("Common Normal") .. {
				Name = "AxisRight",
				Text = "#40",
				InitCommand = function(self)
					self:xy(loopPlotW / 2, 0):halign(1):zoom(0.25):diffuse(HVColor.TextDim or color("0.45,0.45,0.45,1")):diffusealpha(0.5):visible(false)
				end
			},
			LoadFont("Common Normal") .. {
				Name = "StatusText",
				Text = "Play a loop to record Wife scores",
				InitCommand = function(self)
					self:xy(0, 0):halign(0.5):zoom(0.30):diffuse(HVColor.TextDim or color("0.45,0.45,0.45,1"))
				end
			}
		},

		MovableBorder(loopCardW, loopCardH, 1, 0, 0)
	}
end

local pm = Def.ActorFrame {
	Name = "ChartPreview",
	InitCommand = function(self)
		local x = (MovableValues and MovableValues.PracticeCDGraphX) or getDefaultGameplayCoordinate("PracticeCDGraphX") or SCREEN_LEFT + 20
		local y = (MovableValues and MovableValues.PracticeCDGraphY) or getDefaultGameplayCoordinate("PracticeCDGraphY") or SCREEN_CENTER_Y
		self:xy(x, y)
		self:SetUpdateFunction(UpdatePreviewPos)
	end,
	OnCommand = function(self)
		-- The practice graph is a single movable unit. Register its containing
		-- frame so customization input can apply AddX/AddY to a real Actor.
		setMovableActor({"DeviceButton_z"}, self, self:GetChild("Border"))
		-- Disable the chord density graph's internal hover marker since it doesn't account for zoom
		local cdg = self:GetChild("ChordDensityGraph")
		if cdg then
			local seekMarker = cdg:GetChild("SeekMarker")
			if seekMarker then seekMarker:diffusealpha(0) end
		end
	end,
	BeginCommand = function(self)
		local steps = GAMESTATE:GetCurrentSteps()
		if steps and steps.GetLastSecond then
			musicratio = steps:GetLastSecond() / wodth
			if musicratio <= 0 then musicratio = 1 end
		end
		-- Store direct reference to Hitbox for input hit-testing
		graphHitboxRef = self:GetChild("Hitbox")
		local top = getTop()
		if top and top.AddInputCallback then
			top:AddInputCallback(duminput)
		end
		self:SortByDrawOrder()
		self:queuecommand("GraphUpdate")
	end,
	EndCommand = function(self)
		PREFSMAN:SetPreference("ShowMouseCursor", false)
	end,
	PracticeModeReloadMessageCommand = function(self)
		local steps = GAMESTATE:GetCurrentSteps()
		if steps and steps.GetLastSecond then
			musicratio = steps:GetLastSecond() / wodth
			if musicratio <= 0 then musicratio = 1 end
		end
			local songPos = getSongPos()
			if hasPracticeLoop() and not awaitingPracticeSeek and lastObservedSongPos
				and lastObservedSongPos >= HV.PracticeLoopEnd - 0.75
				and songPos <= HV.PracticeLoopStart + 1.0 then
				appendLoopAttempt()
				resetLoopAttempt(true)
				awaitingLoopStart = false
				justCompletedLoop = true
			end
	end,
	JudgmentMessageCommand = function(self, params)
		if not hasPracticeLoop() or not loopAttemptValid or isPaused() then return end
		if params.Player ~= pn or params.HoldNoteScore or params.RollNoteScore then return end
		local score = params.TapNoteScore
		if not score or score == "TapNoteScore_None" or score == "TapNoteScore_AvoidMine"
			or score == "TapNoteScore_CheckpointHit" or score == "TapNoteScore_CheckpointMiss" then return end
		if score == "TapNoteScore_HitMine" then
			loopWifePoints = loopWifePoints - 7
		elseif params.TapNoteOffset ~= nil then
			loopTapCount = loopTapCount + 1
			loopWifePoints = loopWifePoints + wife3(math.abs(params.TapNoteOffset) * 1000, ms.JudgeScalers[4] or 1, "Wife3")
		elseif score == "TapNoteScore_Miss" then
			loopTapCount = loopTapCount + 1
			loopWifePoints = loopWifePoints - 5.5
		else
			loopTapCount = loopTapCount + 1
			loopWifePoints = loopWifePoints + 2
		end
		HV.PracticeLoopCurrentScore = currentLoopWifePercent()
		updateLoopGraphs()
		MESSAGEMAN:Broadcast("PracticeLoopScoreUpdated")
	end,
	HoldNoteScoreMessageCommand = function(self, params)
		if params.Player == pn and hasPracticeLoop() and loopAttemptValid and not isPaused()
			and (params.HoldNoteScore == "HoldNoteScore_LetGo" or params.HoldNoteScore == "HoldNoteScore_MissedHold") then
			loopWifePoints = loopWifePoints - 4.5
			HV.PracticeLoopCurrentScore = currentLoopWifePercent()
			updateLoopGraphs()
			MESSAGEMAN:Broadcast("PracticeLoopScoreUpdated")
		end
	end,
	RollNoteScoreMessageCommand = function(self, params)
		if params.Player == pn and hasPracticeLoop() and loopAttemptValid and not isPaused()
			and (params.RollNoteScore == "RollNoteScore_LetGo" or params.RollNoteScore == "RollNoteScore_MissedRoll") then
			loopWifePoints = loopWifePoints - 4.5
			HV.PracticeLoopCurrentScore = currentLoopWifePercent()
			updateLoopGraphs()
			MESSAGEMAN:Broadcast("PracticeLoopScoreUpdated")
		end
	end,
	LoadActor("../_chorddensitygraph.lua") .. {
		InitCommand = function(self)
			self:zoom(prevZoom)
		end
	},
	UIElements.QuadButton(1, 1) .. {
		Name = "Hitbox",
		InitCommand = function(self)
			self:halign(0):valign(1):zoomto(wodth * prevZoom, hidth * prevZoom):diffusealpha(0):draworder(1099)
		end,
		MouseDownCommand = function(self, params)
			local event = params.event or params.button
			local width = self:GetZoomedWidth()
			local left = self:GetTrueX() - (width * self:GetHAlign())
			local pos = math.max(0, math.min(wodth, ((INPUTFILTER:GetMouseX() - left) / width) * wodth)) * musicratio
			if event == "DeviceButton_left mouse button" then
				if INPUTFILTER:IsControlPressed() then
					handleRegionSetting(pos)
				else
				seekPracticeSongPos(pos, false)
				end
			elseif event == "DeviceButton_right mouse button" then
				handleRegionSetting(pos)
			end
		end
	},
	Def.Quad {
		Name = "BookmarkPos",
		InitCommand = function(self)
			self:zoomto(2, hidth * prevZoom):diffuse(color(".2,.5,1,1")):halign(0):valign(1):draworder(1100):visible(false)
		end,
		SetCommand = function(self)
			if loopStartPos then
				self:visible(true):zoomto(2, hidth * prevZoom):diffuse(color(".2,.5,1,1")):halign(0):valign(1):x(loopStartPos / musicratio * prevZoom)
			else
				self:visible(false)
			end
		end,
		RegionSetMessageCommand = function(self, params)
			if not params or not params.loopLength then
				self:playcommand("Set")
			else
				self:visible(true):x(loopStartPos / musicratio * prevZoom):halign(0):valign(1):zoomto(params.loopLength / musicratio * prevZoom, hidth * prevZoom):diffuse(color(".7,.2,.7,0.5"))
			end
		end,
		CurrentRateChangedMessageCommand = function(self)
			if not loopEndPos and loopStartPos then
				self:playcommand("Set")
			elseif loopEndPos and loopStartPos then
				self:playcommand("RegionSet", {loopLength = (loopEndPos - loopStartPos)})
			end
		end,
		PracticeModeReloadMessageCommand = function(self)
			self:playcommand("CurrentRateChanged")
		end
	},
	Def.Quad {
		Name = "CurrentPos",
		InitCommand = function(self)
			self:zoomto(2, hidth * prevZoom):diffuse(HVColor.Accent):halign(0.5):valign(1):draworder(1101)
		end
	},
	-- Custom hover marker that accounts for zoom
	Def.Quad {
		Name = "HoverMarker",
		InitCommand = function(self)
			self:zoomto(1, hidth * prevZoom):diffuse(color("1,1,1,0.5")):halign(0.5):valign(1):visible(false):draworder(1100)
		end
	},
	MovableBorder(wodth * prevZoom, hidth * prevZoom, 1, (wodth * prevZoom) / 2, -(hidth * prevZoom) / 2)
}

local t = Def.ActorFrame {
	OnCommand = function(self)
		PREFSMAN:SetPreference("ShowMouseCursor", true)
	end,
	CodeMessageCommand = function(self, params)
		handlePracticeCommand(params.Name)
	end,
	pm,
	makePracticeLoopGraph("LoopAttemptsGraph", "Wife score by loop", "PracticeLoopAttemptsX", "PracticeLoopAttemptsY", "DeviceButton_F1", function() return loopAttemptScores end)
}

return t
