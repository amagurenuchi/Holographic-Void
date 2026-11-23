local cdg

local optionalParam = Var("width")
local wodth = 300
if optionalParam ~= nil then
	wodth = optionalParam
end
local hidth = 40
local accentColor = HVColor.Accent or color("#00CFFF")

-- Helper: format seconds as m:ss.x
local function formatTime(s)
	if not s or s < 0 then return "-:--" end
	local m = math.floor(s / 60)
	local sec = s - m * 60
	return string.format("%d:%02d", m, math.floor(sec))
end

local function getChartLastSecond(song, steps)
	if steps then
		local ok, len = pcall(function() return steps:GetLastSecond() end)
		if ok and len and len > 0 then return len end
	end
	if song then
		local ok, len = pcall(function() return song:GetLastSecond() end)
		if ok and len and len > 0 then return len end
		ok, len = pcall(function() return song:MusicLengthSeconds() end)
		if ok and len and len > 0 then return len end
	end
	return 0
end

local function getActorLeft(actor)
	return actor:GetTrueX() - (actor:GetZoomedWidth() * actor:GetHAlign())
end

local function updateInteraction(self)
	local mouseX = INPUTFILTER:GetMouseX()
	local mouseY = INPUTFILTER:GetMouseY()
	
	local bg = self:GetChild("cdbg")
	local marker = self:GetChild("SeekMarker")
	local info = self:GetChild("InfoBar")
	local curMarker = self:GetChild("CurrentPosMarker")
	
	local steps = GAMESTATE:GetCurrentSteps()
	local song = GAMESTATE:GetCurrentSong()
	if not steps or not song then return end
	
	local musicLength = getChartLastSecond(song, steps)
	local rate = getCurRateValue()
	if musicLength <= 0 then return end
	
	-- Update Current Position Marker
	if curMarker then
		local curPos = GAMESTATE:GetSongPosition():GetMusicSeconds()
		local p = math.max(0, math.min(curPos / musicLength, 1))
		curMarker:x(p * wodth)
	end
	
	if isOver(bg) then
		local gx = getActorLeft(bg)
		local p = math.max(0, math.min((mouseX - gx) / wodth, 1))
		
		if marker then marker:visible(true):x(p * wodth) end
		
		if info then
			local time = p * musicLength
			local beat = song:GetTimingData():GetBeatFromElapsedTime(time)
			local bpm = song:GetTimingData():GetBPMAtBeat(beat) * rate
			
			local nps = 0
			if self.npsVector then
				local idx = math.floor(p * #self.npsVector) + 1
				idx = math.max(1, math.min(#self.npsVector, idx))
				nps = self.npsVector[idx]
			end
			
			info:settext(string.format("%s | %.0f BPM | %.1f NPS", formatTime(time), bpm, nps))
				:diffuse(accentColor)
		end
	else
		if marker then marker:visible(false) end
		if info then
			local curPos = GAMESTATE:GetSongPosition():GetMusicSeconds()
			local beat = song:GetTimingData():GetBeatFromElapsedTime(curPos)
			local bpm = song:GetTimingData():GetBPMAtBeat(beat) * rate
			
			local p = math.max(0, math.min(curPos / musicLength, 1))
			local nps = 0
			if self.npsVector then
				local idx = math.floor(p * #self.npsVector) + 1
				idx = math.max(1, math.min(#self.npsVector, idx))
				nps = self.npsVector[idx]
			end
			
			info:settext(string.format("%s | %.0f BPM | %.1f NPS", formatTime(curPos), bpm, nps))
				:diffuse(color("1,1,1,0.6"))
		end
	end
end

local function updateGraphMultiVertex(parent, realgraph)
	local steps = GAMESTATE:GetCurrentSteps()
	if steps then
		local ncol = steps:GetNumColumns()
		local rate = math.max(0.05, getCurRateValue())
		local graphVectors = steps:GetCDGraphVectors(rate)
		if graphVectors == nil then
			realgraph:SetVertices({})
			realgraph:SetDrawState({Mode = "DrawMode_Quads", First = 0, Num = 0})
			return
		end

		local npsVector = graphVectors[1]
		parent.npsVector = npsVector
		local numberOfColumns = #npsVector
		local columnWidth = wodth / numberOfColumns
		
		local hodth = 0
		for i = 1, #npsVector do
			if npsVector[i] * 2 > hodth then
				hodth = npsVector[i] * 2
			end
		end

		parent:GetChild("npsline"):y(-hidth * 0.7)
		parent:GetChild("npstext"):settext(string.format("%.1f NPS Peak", hodth / 2)):y(-hidth - 10):x(wodth):halign(1)
		
		hodth = hidth / hodth
		local verts = {}
		for density = 1, ncol do
			for column = 1, numberOfColumns do
				if graphVectors[density][column] > 0 then
					local interval = 1 / ncol
					local val = 1 - density * interval
					local barColor = color(tostring(val) .. "," .. tostring(val) .. "," .. tostring(val))
					
					local x, y = column * columnWidth, 0
					local bw, bh = columnWidth, graphVectors[density][column] * 2 * hodth
					verts[#verts + 1] = {{x, y - bh, 0}, barColor}
					verts[#verts + 1] = {{x - bw, y - bh, 0}, barColor}
					verts[#verts + 1] = {{x - bw, y, 0}, barColor}
					verts[#verts + 1] = {{x, y, 0}, barColor}
				end
			end
		end

		realgraph:SetVertices(verts)
		realgraph:SetDrawState({Mode = "DrawMode_Quads", First = 1, Num = #verts})
	end
end

local t = Def.ActorFrame {
	Name = "ChordDensityGraph",
	InitCommand = function(self)
		cdg = self
	end,
	OnCommand = function(self)
		self:SetUpdateFunction(updateInteraction)
		self:playcommand("GraphUpdate")
	end,
	GraphUpdateCommand = function(self)
		self:diffusealpha(0):linear(0.2):diffusealpha(1)
		updateGraphMultiVertex(self, self:GetChild("CDGraphDrawer"))
	end,
	PracticeModeReloadMessageCommand = function(self) self:queuecommand("GraphUpdate") end,
	PracticeModeResetMessageCommand = function(self) self:queuecommand("GraphUpdate") end,
	DelayedChartUpdateMessageCommand = function(self) self:queuecommand("GraphUpdate") end,

	-- Background
	Def.Quad {
		Name = "cdbg",
		InitCommand = function(self)
			self:zoomto(wodth, hidth):valign(1):diffuse(color("0,0,0,0.5")):halign(0)
		end,
		MouseDownCommand = function(self, params)
			local event = params.event or params.button
			if isOver(self) and event == "DeviceButton_left mouse button" then
				local song = GAMESTATE:GetCurrentSong()
				if song then
					local mx = INPUTFILTER:GetMouseX()
					local gx = getActorLeft(self)
					local p = math.max(0, math.min((mx - gx) / wodth, 1))
					local time = p * getChartLastSecond(song, GAMESTATE:GetCurrentSteps())
					if GAMESTATE:IsPracticeMode() and HV and HV.SeekPracticeSongPosition then
						HV.SeekPracticeSongPosition(time, false)
					else
						SCREENMAN:GetTopScreen():SetSongPosition(time)
					end
				end
			end
		end
	},

	-- Graph Drawer
	Def.ActorMultiVertex {
		Name = "CDGraphDrawer"
	},

	-- NPS Peak reference line
	Def.Quad {
		Name = "npsline",
		InitCommand = function(self)
			self:zoomto(wodth, 1):valign(1):diffuse(accentColor):diffusealpha(0.4):halign(0)
		end
	},

	-- NPS text label
	LoadFont("Common Normal") .. {
		Name = "npstext",
		InitCommand = function(self)
			self:zoom(0.45):diffuse(accentColor)
		end
	},
	
	-- Info Bar (Time | BPM | NPS)
	LoadFont("Common Normal") .. {
		Name = "InfoBar",
		InitCommand = function(self)
			self:y(18):halign(0):zoom(0.45)
		end
	},
	
	-- Current Position Marker
	Def.Quad {
		Name = "CurrentPosMarker",
		InitCommand = function(self)
			self:zoomto(1.5, hidth):valign(1):diffuse(accentColor):halign(0.5)
		end
	},
	
	-- Seek Marker (Hover)
	Def.Quad {
		Name = "SeekMarker",
		InitCommand = function(self)
			self:zoomto(1, hidth):valign(1):diffuse(color("1,1,1,0.5")):visible(false):halign(0.5)
		end
	}
}

return t
