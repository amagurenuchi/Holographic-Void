local practiceMode = GAMESTATE:IsPracticeMode()

if not practiceMode then
	return Def.ActorFrame {}
end

HV = HV or {}

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
	setSongPos(nextpos, false)
end

local function handlePracticeCommand(name)
	local top = getTop()
	if not top then return end

	if name == "PracRateUp" then
		if top.AddToRate then pcall(function() top:AddToRate(0.05) end) else changeMusicRate(0.05) end
	elseif name == "PracRateDown" then
		if top.AddToRate then pcall(function() top:AddToRate(-0.05) end) else changeMusicRate(-0.05) end
	elseif name == "PracPause" then
		if top.TogglePause then top:TogglePause() end
	elseif name == "PracRestart" then
		setSongPos(loopStartPos or 0, true)
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
				setSongPos(loopStartPos, true)
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
	local pos = getSongPos() / musicratio * prevZoom
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

local pm = Def.ActorFrame {
	Name = "ChartPreview",
	InitCommand = function(self)
		local x = (MovableValues and MovableValues.PracticeCDGraphX) or getDefaultGameplayCoordinate("PracticeCDGraphX") or SCREEN_LEFT + 20
		local y = (MovableValues and MovableValues.PracticeCDGraphY) or getDefaultGameplayCoordinate("PracticeCDGraphY") or SCREEN_CENTER_Y
		self:xy(x, y)
		self:SetUpdateFunction(UpdatePreviewPos)
	end,
	OnCommand = function(self)
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
					setSongPos(pos, false)
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
	}
}

local t = Def.ActorFrame {
	OnCommand = function(self)
		PREFSMAN:SetPreference("ShowMouseCursor", true)
	end,
	CodeMessageCommand = function(self, params)
		handlePracticeCommand(params.Name)
	end,
	pm
}

return t
