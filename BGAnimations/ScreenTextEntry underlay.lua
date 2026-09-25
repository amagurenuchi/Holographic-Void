--- Holographic Void: ScreenTextEntry Underlay
-- Provides the themed background and "Censor" toggle for native prompts.

local accentColor = HVColor.Accent
local bgCard = color("0.06,0.06,0.06,0.95")
local dimText = color("0.45,0.45,0.45,1")
local brightText = color("1,1,1,1")

local boxWidth = SCREEN_WIDTH / 2.5
local boxHeight = SCREEN_HEIGHT / 3

return Def.ActorFrame {
	Name = "TextEntryUnderlay",
	InitCommand = function(self) self:diffusealpha(0) end,
	OffCommand = function(self) self:stoptweening():smooth(0.1):diffusealpha(0) end,
	OnCommand = function(self)
		self:smooth(0.1):diffusealpha(1)
		
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end

		-- Capture right-click to cancel (like Til Death)
		screen:AddInputCallback(function(event)
			if event.DeviceInput.button == "DeviceButton_right mouse button" then
				if event.type == "InputEventType_FirstPress" then
					local top = SCREENMAN:GetTopScreen()
					if top then
						top:Cancel()
					end
				end
			end
		end)

		self:queuecommand("ResizeLoop")
	end,
	ResizeLoopCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		local q = screen:GetChild("Question")
		local a = screen:GetChild("Answer")
		
		if q and a then
			q:maxwidth((boxWidth - 40) / q:GetZoom()):diffusealpha(1):draworder(100)
			a:maxwidth((boxWidth - 40) / a:GetZoom()):diffusealpha(1):draworder(100)
		else
			self:sleep(0.05):queuecommand("ResizeLoop")
		end
	end,

	-- Dim background
	Def.Quad {
		InitCommand = function(self) self:FullScreen():diffuse(color("0,0,0,0.8")) end
	},

	-- Dialog Box
	Def.ActorFrame {
		InitCommand = function(self) self:Center() end,

		-- Main Background
		Def.Quad {
			InitCommand = function(self) self:zoomto(boxWidth, boxHeight):diffuse(bgCard) end
		},
		-- Accent Borders
		Def.Quad {
			InitCommand = function(self) self:zoomto(boxWidth, 1):y(-boxHeight/2):diffuse(accentColor) end
		},
		Def.Quad {
			InitCommand = function(self) self:zoomto(boxWidth, 1):y(boxHeight/2):diffuse(accentColor):diffusealpha(0.3) end
		},

		-- Censor / Unhide Button
		Def.ActorFrame {
			Name = "UnhideButton",
			InitCommand = function(self)
				self:xy(-boxWidth/2 + 60, boxHeight/2 - 25)
				self.isHeld = false
			end,
			BeginCommand = function(self)
				local screen = SCREENMAN:GetTopScreen()
				if screen and not screen:IsInputHidden() then self:visible(false) end
				
				screen:AddInputCallback(function(event)
					if event.DeviceInput.button == "DeviceButton_left mouse button" then
						if event.type == "InputEventType_FirstPress" then
							self:playcommand("PressMouse")
						elseif event.type == "InputEventType_Release" then
							self:playcommand("ReleaseMouse")
						end
					end
				end)
			end,
			OnCommand = function(self)
				self:playcommand("Update")
			end,
			UpdateUnhideTextMessageCommand = function(self) self:playcommand("Update") end,
			UpdateCommand = function(self)
				self:queuecommand("CheckVisibility")
			end,
			CheckVisibilityCommand = function(self)
				local screen = SCREENMAN:GetTopScreen()
				if screen then
					local q = screen:GetChild("Question")
					if q then
						local txt = q:GetText()
						if txt and txt ~= "" then
							local ltxt = string.lower(txt)
							if ltxt:match("password") or ltxt:match("email") or ltxt:match("username") then
								self:visible(true)
							else
								self:visible(false)
							end
							return -- Found it, stop looping
						end
					end
				end
				-- If we reach here, keep looping until text appears
				self:sleep(0.05):queuecommand("CheckVisibility")
			end,
			
			Def.Quad {
				Name = "UnhideHitbox",
				InitCommand = function(self) self:zoomto(100, 24):diffuse(color("1,1,1,0.05")) end,
				UpdateCommand = function(self) self:stoptweening():linear(0.1):diffusealpha(self:GetParent().isHeld and 0.4 or 0.1) end,
				PressMouseCommand = function(self)
					if self:GetParent():GetVisible() and isOver(self) then
						if self:GetParent().isHeld then return end
						self:GetParent().isHeld = true
						SCREENMAN:GetTopScreen():ToggleInputHidden()
						self:GetParent():playcommand("Update")
						MESSAGEMAN:Broadcast("UpdateUnhideText")
					end
				end,
				ReleaseMouseCommand = function(self)
					if self:GetParent().isHeld then
						self:GetParent().isHeld = false
						SCREENMAN:GetTopScreen():ToggleInputHidden()
						self:GetParent():playcommand("Update")
						MESSAGEMAN:Broadcast("UpdateUnhideText")
					end
				end
			},
			-- Outer Border for button
			Def.Quad {
				InitCommand = function(self) self:zoomto(100, 1):y(-12):diffuse(accentColor):diffusealpha(0.5) end
			},
			Def.Quad {
				InitCommand = function(self) self:zoomto(100, 1):y(12):diffuse(accentColor):diffusealpha(0.2) end
			},
			LoadFont("Common Normal") .. {
				Text = THEME:GetString("ScreenTextEntry", "Unhide"),
				InitCommand = function(self) self:zoom(0.4):diffuse(accentColor):shadowlength(1) end,
				UpdateUnhideTextMessageCommand = function(self) self:playcommand("Update") end,
				UpdateCommand = function(self) 
					local screen = SCREENMAN:GetTopScreen()
					local isMasked = screen and screen:IsInputHidden()
					if not isMasked then
						self:settext(THEME:GetString("ScreenTextEntry", "Hide"))
						self:diffuse(brightText):glow(accentColor)
					else
						self:settext(THEME:GetString("ScreenTextEntry", "Unhide"))
						self:diffuse(accentColor):glow(color("0,0,0,0"))
					end
				end
			}
		},

		-- Help Text
		LoadFont("Common Normal") .. {
			Text = THEME:GetString("ScreenTextEntry", "RightClickCancel"),
			InitCommand = function(self) self:xy(boxWidth/2 - 80, boxHeight/2 - 25):zoom(0.3):diffuse(dimText) end
		}
	},

	-- Mouse cursor (must render above the dialog)
	LoadActor("_cursor"),
}
