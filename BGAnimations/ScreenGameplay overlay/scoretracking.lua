-- Holographic Void: Score Tracking
-- Broadcasts timing messages for the pacemaker and other overlay elements.

local startFlag = false
local fcFlag = false
local fcFlagDelay = 0.5
local firstSecond
local lastSecond

local function Update(self)
	-- self.InitCommand = function(self)
	-- 	self:SetUpdateFunction(Update)
	-- end
	local curSecond = GAMESTATE:GetSongPosition():GetMusicSeconds()
	if HV then
		HV.LastPlayedSecond = curSecond
	end

	if not startFlag and (firstSecond - curSecond < 2 or curSecond > 1) then
		MESSAGEMAN:Broadcast("SongStarting")
		startFlag = true
	end

	if not fcFlag and curSecond > lastSecond + fcFlagDelay then
		fcFlag = true
	end
end

local t = Def.ActorFrame {
	InitCommand = function(self)
		self:SetUpdateFunction(Update)
	end,
	CurrentSongChangedMessageCommand = function(self)
		if GAMESTATE:GetCurrentSong() ~= nil then
			firstSecond = GAMESTATE:GetCurrentSong():GetFirstSecond()
			lastSecond = GAMESTATE:GetCurrentSong():GetLastSecond()
		end
		startFlag = false
		fcFlag = false
	end
}

return t
