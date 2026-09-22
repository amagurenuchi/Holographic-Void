-- Holographic Void: Replay Control Overlay
-- Ported from 'Til Death with HV-style visuals and simplified logic
-- Supports mouse interaction and keyboard shortcuts

-- Robust replay detection
local function isReplayActive()
	local screen = SCREENMAN:GetTopScreen()
	if not screen then return false end
	local ps = GAMESTATE:GetPlayerState(PLAYER_1)
	if ps and ps:GetPlayerController() == "PlayerController_Replay" then return true end
	return false
end

if not isReplayActive() then
	return Def.Actor {}
end

-- Visual constants
local btnW = 60
local btnH = 24
local spacing = 30
local accentColor = HVColor.Accent or color("#00CFFF")
local bgSubtle = color("0.05,0.05,0.05,0.7")
local textMain = color("1,1,1,1")
local textDim = color("0.6,0.6,0.6,1")

-- Replay-safe pause check
local function isPaused()
	local top = SCREENMAN:GetTopScreen()
	return top and top.GetPaused and top:GetPaused() or false
end

-- Replay-safe position retrieval
local function getSongPos()
	return GAMESTATE:GetSongPosition():GetMusicSeconds()
end

-- Key/Gamepad Input Logic
local function input(event)
	if event.type == "InputEventType_Release" then return end
	
	local top = SCREENMAN:GetTopScreen()
	if not top then return end

	-- Keyboard / GameButtons
	if event.type == "InputEventType_FirstPress" then
		if event.GameButton == "EffectUp" then
			top:SetSongPosition(getSongPos() + 5)
		elseif event.GameButton == "EffectDown" then
			top:SetSongPosition(math.max(0, getSongPos() - 5))
		elseif event.GameButton == "Coin" then
			top:TogglePause()
		elseif event.GameButton == "Back" then
			top:Cancel()
		end
		
		-- Mouse Click Broadcast
		if event.DeviceInput.button == "DeviceButton_left mouse button" then
			MESSAGEMAN:Broadcast("ReplayControlClick")
		end
	end
end

-- Button helper
local function makeButton(name, y, text, clickFunc)
	return Def.ActorFrame {
		Name = name .. "Button",
		InitCommand = function(self) self:y(y) end,
		ReplayControlClickMessageCommand = function(self)
			local bg = self:GetChild("BG")
			if bg and isOver(bg) then
				clickFunc()
			end
		end,
		
		Def.Quad {
			Name = "BG",
			InitCommand = function(self)
				self:zoomto(btnW, btnH):diffuse(color("0.15,0.15,0.15,0.8"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:zoom(0.32):settext(text):diffuse(textMain)
			end
		}
	}
end

local inputAdded = false
local playerName = "Replay"
if HV.OnlineReplayActive and HV.OnlineReplayName then
	playerName = HV.OnlineReplayName
end
local isCustomizeGameplay = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay

local t = Def.ActorFrame {
	Name = "ReplayControls",
	InitCommand = function(self)
		self:xy((MovableValues and MovableValues.ReplayButtonsX) or getDefaultGameplayCoordinate("ReplayButtonsX") or (SCREEN_RIGHT - 40), (MovableValues and MovableValues.ReplayButtonsY) or getDefaultGameplayCoordinate("ReplayButtonsY") or (SCREEN_CENTER_Y + 50))
		self:diffusealpha(0)
	end,
	OnCommand = function(self)
		setMovableActor({"DeviceButton_f"}, self, self:GetChild("Border"))
		-- Fetch name once
		local screen = SCREENMAN:GetTopScreen()
		if screen and screen.GetReplayScore then
			local score = screen:GetReplayScore(PLAYER_1)
			if score and not (HV.OnlineReplayActive and HV.OnlineReplayName) then
				playerName = score:GetDisplayName() or score:GetName() or "Replay"
			end
		end
		
		if not inputAdded then
			local top = SCREENMAN:GetTopScreen()
			if top then 
				top:AddInputCallback(input)
				inputAdded = true
			end
		end
		self:linear(0.2):diffusealpha(1)
		
		if self.SetUpdateFunction then
			self:SetUpdateFunction(function(self)
				self:playcommand("UpdateVisuals")
			end)
		else
			self:SetUpdate(true)
			self:setupdatecommand("UpdateVisuals")
		end
	end,
	
	UpdateVisualsCommand = function(self)
		local buttons = self:GetChild("Buttons")
		if not buttons then return end
		
		local bList = {"Rewind", "Pause", "Forward", "Results", "Exit"}
		local paused = isPaused()
		for _, bName in ipairs(bList) do
			local b = buttons:GetChild(bName .. "Button")
			if b then
				local bg = b:GetChild("BG")
				if bg then
					if isOver(bg) then
						bg:diffuse(accentColor):diffusealpha(0.4)
					else
						bg:diffuse(color("0.15,0.15,0.15,0.8"))
					end
				end
				
				if bName == "Pause" then
					local label = b:GetChild("Label")
					if label then
						label:settext(paused and "PLAY" or "PAUSE")
					end
				end
			end
		end
	end,

	-- Background panel
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(btnW + 10, (spacing * 5) + 60):diffuse(bgSubtle)
		end
	},
	-- Accent border right
	Def.Quad {
		InitCommand = function(self)
			self:halign(1):x((btnW + 10)/2):zoomto(2, (spacing * 5) + 60):diffuse(accentColor):diffusealpha(0.5)
		end
	},

	-- Player Name Display
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(-(spacing * 2.5) - 15):zoom(0.35):diffuse(accentColor)
				:maxwidth((btnW + 4)/0.35)
		end,
		OnCommand = function(self) self:settext(playerName) end
	},

	-- Buttons Container
	Def.ActorFrame {
		Name = "Buttons",
		InitCommand = function(self) self:y(10) end,
		
		makeButton("Rewind", -spacing * 2, "<< 5s", function()
			local top = SCREENMAN:GetTopScreen()
			if top then top:SetSongPosition(math.max(0, getSongPos() - 5)) end
		end),
		
		makeButton("Pause", -spacing, "PAUSE", function()
			local top = SCREENMAN:GetTopScreen()
			if top then top:TogglePause() end
		end),
		
		makeButton("Forward", 0, "5s >>", function()
			local top = SCREENMAN:GetTopScreen()
			if top then top:SetSongPosition(getSongPos() + 5) end
		end),

		makeButton("Results", spacing, "RESULTS", function()
			local top = SCREENMAN:GetTopScreen()
			if top then top:PostScreenMessage("SM_NotesEnded", 0) end
		end),

		makeButton("Exit", spacing * 2, "EXIT", function()
			local top = SCREENMAN:GetTopScreen()
			if top then top:Cancel() end
		end),
	},
	MovableBorder(btnW + 10, (spacing * 5) + 60, 1, 0, 0)
}

return t
