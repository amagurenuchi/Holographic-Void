--- Holographic Void: ScreenTitleMenu Overlay
-- Rebuilt to focus only on custom cursor and jukebox shortcuts.

local choiceNames = {"Start", "Multi", "ColorTheme", "PackDownloader", "Options", "Quit"}
local customGradesEnabled = ThemePrefs.Get("HV_UseCustomGrades") == true or ThemePrefs.Get("HV_UseCustomGrades") == "true"

local t = Def.ActorFrame {}

-- Cursor stays on top
t[#t+1] = LoadActor("../_cursor")

-- Combined Input Controller
t[#t+1] = Def.ActorFrame {
	BeginCommand = function(self)
		HV.TitleState.keyboardIndex = HV.TitleState.keyboardIndex or 1
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		screen:AddInputCallback(function(event)
			-- Background shortcuts (Jukebox Pause)
			if event.type == "InputEventType_FirstPress" then
				local btn = event.DeviceInput.button
				if btn == "DeviceButton_backslash" then
					MESSAGEMAN:Broadcast("TriggerJukeboxPause")
					return true
				end
			end
			return false
		end)
	end
}

-- Menu Click Handler
t[#t+1] = UIElements.QuadButton(1) .. {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):zoomto(300, 240):diffusealpha(0)
	end,
	MouseDownCommand = function(self, params)
		if params.event == "DeviceButton_left mouse button" then
			local virtualX = INPUTFILTER:GetMouseX()
			local virtualY = INPUTFILTER:GetMouseY()
			local hovered = nil
			for i = 1, #choiceNames do
				local static_iy = SCREEN_CENTER_Y + 40 * (i - ((#choiceNames + 1) / 2))
				if virtualX >= SCREEN_CENTER_X-150 and virtualX <= SCREEN_CENTER_X+150 
				   and virtualY >= static_iy-20 and virtualY <= static_iy+20 then
					hovered = i break
				end
			end
			
			if hovered then
				local screen = SCREENMAN:GetTopScreen()
				if screen then
					-- Execute the action for the choice
					local name = choiceNames[hovered]
					
					-- 1. Sync scroller visual and engine selection
					if screen:GetChild("Scroller") then
						screen:GetChild("Scroller"):SetDestinationItem(hovered - 1)
					end
					
					-- 2. Join player if they clicked Start (parity with Til' Death)
					if name == "Start" then
						GAMESTATE:JoinPlayer()
					end
					
					-- 3. Play selection commands to trigger animations/logic
					screen:playcommand("MadeChoicePlayer_1")
					screen:playcommand("Choose")
					
					-- 4. Apply the game command defined in metrics
					local command = THEME:GetMetric("ScreenTitleMenu", "Choice" .. name)
					if command then
						GAMESTATE:ApplyGameCommand(command)
						SOUND:PlayOnce(THEME:GetPathS("Common", "start"))
					end
				end
			end
		end
	end
}

-- Custom grade editing is a separate title-screen entry, outside the main list.
if customGradesEnabled then
	t[#t+1] = UIElements.QuadButton(1) .. {
		InitCommand = function(self)
			self:xy(SCREEN_LEFT + 16, SCREEN_TOP + 140):zoomto(180, 32):diffusealpha(0)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				local x, y = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				if x >= SCREEN_LEFT + 16 and x <= SCREEN_LEFT + 196 and y >= SCREEN_TOP + 124 and y <= SCREEN_TOP + 156 then
					SCREENMAN:AddNewScreenToTop("ScreenHVCustomGrades")
				end
			end
		end
	}
	t[#t+1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(SCREEN_LEFT + 26, SCREEN_TOP + 140):halign(0):zoom(.5):settext("EDIT GRADES") end,
	}
end

return t
