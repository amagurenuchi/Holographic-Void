--- Holographic Void: ScreenSelectProfile Overlay (REBUILT)
-- Features a seamless zoom transition from the Title Screen chip.
-- Uses native ScreenSelectProfile methods for stability.

local pBtnW = 260
local pBtnH = 70
local compactRowH = 40
-- Keep a fixed-size window around the selected profile so the list stays on
-- screen even when a machine has many local profiles.
local visibleProfileCount = 9
local profileRowPitch = 48
local accentColor = HVColor.Accent
local brightText = color("1,1,1,1")
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")

-- Title Screen Chip Coordinates
local chipX = (SCREEN_RIGHT - 10) - pBtnW/2
local chipY = 10 + pBtnH/2

local profiles = {}
local numProfiles = PROFILEMAN:GetNumLocalProfiles()
for i = 0, numProfiles - 1 do
	local p = PROFILEMAN:GetLocalProfileFromIndex(i)
	local id = PROFILEMAN:GetLocalProfileIDFromIndex(i)
	profiles[#profiles + 1] = {
		index = i,
		id = id,
		name = p:GetDisplayName(),
		rating = p:GetPlayerRating(),
		songs = p:GetTotalNumSongsPlayed(),
	}
end

local selectedIdx = HV.DirectLaunchProfileIdx or HV.TitleState.selectedProfile or 0
selectedIdx = tonumber(selectedIdx)
if selectedIdx >= numProfiles then selectedIdx = 0 end

local function ensureCurrentStyle()
	if GAMESTATE:GetCurrentStyle() then return true end

	local game = GAMESTATE:GetCurrentGame()
	local gameName = (game and game.GetName and tostring(game:GetName())) or "dance"
	local candidates = {
		gameName .. "-single",
		gameName .. "-versus",
		gameName .. "-double",
	}

	for _, styleName in ipairs(candidates) do
		local ok = pcall(function()
			GAMESTATE:SetCurrentStyle(styleName)
		end)
		if ok and GAMESTATE:GetCurrentStyle() then
			return true
		end
	end

	return false
end

local function updateRows(self)
	local windowSize = math.min(visibleProfileCount, numProfiles)
	local firstVisible = math.max(0, math.min(selectedIdx - math.floor((windowSize - 1) / 2), numProfiles - windowSize))
	for i = 1, #profiles do
		local row = self:GetChild("Row_" .. i)
		if row then
			local isSelected = (i - 1) == selectedIdx
			local isVisible = (i - 1 >= firstVisible and i - 1 < firstVisible + windowSize)
			row:visible(isVisible)
			row:playcommand(isSelected and "Expanded" or "Minimized")
			local windowCenter = firstVisible + (windowSize - 1) / 2
			local rowY = SCREEN_CENTER_Y + ((i - 1) - windowCenter) * profileRowPitch
			-- The selected card is taller than compact rows. Shift rows after it
			-- down by half that extra height so both neighboring gaps stay even.
			if i - 1 > selectedIdx then
				rowY = rowY + (pBtnH - compactRowH) / 2
			elseif i - 1 < selectedIdx then
				rowY = rowY - (pBtnH - compactRowH) / 2
			end
			row:stoptweening():decelerate(0.3):y(rowY):x(SCREEN_CENTER_X)
		end
	end
	local parent = self:GetParent()
	local counter = parent and parent:GetChild("ProfileCount")
	if counter then counter:settextf("%d / %d", numProfiles > 0 and selectedIdx + 1 or 0, numProfiles) end
end

local list = Def.ActorFrame {
	Name = "ListContainer",
	InitCommand = function(self)
		-- Initial layout setup will be done per-row to match Title screen
	end,
}

local t = Def.ActorFrame {
	OnCommand = function(self)
		-- Start the zoom/slide animation
		updateRows(self:GetChild("ListContainer"))

		-- Check for direct launch from Title Screen OR single profile auto-skip
		if HV.DirectLaunchProfileIdx or numProfiles == 1 then
			-- If single profile, ensure we use index 0
			if numProfiles == 1 then
				selectedIdx = 0
				-- Hide everything during auto-skip
				self:GetChild("ListContainer"):visible(false)
				self:GetChild("HeaderText"):visible(false)
				self:GetChild("Hints"):visible(false)
			end
			self:sleep(0.02):queuecommand("DirectLaunch")
		end
	end,
	DirectLaunchCommand = function(self)
		local directIdx = HV.DirectLaunchProfileIdx or selectedIdx
		HV.DirectLaunchProfileIdx = nil
		local screen = SCREENMAN:GetTopScreen()
		if screen and screen.SetProfileIndex then
			-- Ensure player is joined and style is set before finishing
			GAMESTATE:JoinPlayer(PLAYER_1)
			ensureCurrentStyle()
			screen:SetProfileIndex(PLAYER_1, tonumber(directIdx) + 1)
			screen:Finish()
		end
	end,
	
	-- BG (Reuse Title Screen Background)
	LoadActor("../ScreenTitleMenu background/default.lua"),
	
	-- Dark Overlay
	Def.Quad {
		InitCommand = function(self) self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,0.85")) end
	},
	
	-- Header
	LoadFont("Common Large") .. {
		Name = "HeaderText",
		Text = THEME:GetString("ScreenSelectProfile", "HeaderText"),
		InitCommand = function(self) self:xy(SCREEN_CENTER_X, 60):zoom(0.6):diffuse(accentColor):diffusealpha(0) end,
		OnCommand = function(self) self:sleep(0.2):linear(0.2):diffusealpha(1) end
	},
	
	-- Profile List Container
	list,

	-- Control Hints
	LoadFont("Common Normal") .. {
		Name = "Hints",
		Text = "UP / DOWN: SELECT     START: CONFIRM     BACK: CANCEL",
		InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 40):zoom(0.35):diffuse(subText):diffusealpha(0) end,
		OnCommand = function(self) self:sleep(0.4):linear(0.2):diffusealpha(1) end
	},
	LoadFont("Common Normal") .. {
		Name = "ProfileCount",
		Text = "",
		InitCommand = function(self) self:xy(SCREEN_RIGHT - 40, SCREEN_BOTTOM - 40):halign(1):zoom(0.35):diffuse(subText) end
	},
	
	-- Native Input Handling via Screen fallback
	Def.Actor {
		OnCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if not screen then return end
			screen:AddInputCallback(function(event)
				if event.type ~= "InputEventType_FirstPress" then return end
				local btn = event.button
				if btn == "MenuUp" or btn == "Up" then
					if numProfiles > 0 then
						selectedIdx = (selectedIdx - 1 + numProfiles) % numProfiles
						updateRows(self:GetParent():GetChild("ListContainer"))
						SOUND:PlayOnce(THEME:GetPathS("Common", "value"))
					end
				elseif btn == "MenuDown" or btn == "Down" then
					if numProfiles > 0 then
						selectedIdx = (selectedIdx + 1) % numProfiles
						updateRows(self:GetParent():GetChild("ListContainer"))
						SOUND:PlayOnce(THEME:GetPathS("Common", "value"))
					end
				elseif btn == "Start" then
					HV.TitleState.selectedProfile = selectedIdx
					local top = SCREENMAN:GetTopScreen()
					if top and top.SetProfileIndex then
						top:SetProfileIndex(PLAYER_1, selectedIdx + 1)
						top:Finish()
						SOUND:PlayOnce(THEME:GetPathS("Common", "start"))
					end
				elseif btn == "Back" then
					local top = SCREENMAN:GetTopScreen()
					if top and top.Cancel then
						top:Cancel()
					end
				end
			end)
		end
	}
}

-- Populate ListContainer with rows
for i, p in ipairs(profiles) do
	local isInitiallySelected = (i - 1) == selectedIdx
	
	-- Initial Position (Matching Title Screen Chip)
	local initX = chipX
	local initY = chipY
	if not isInitiallySelected then
		-- Map to compact rows
		local relativeIdx = i - 1
		if relativeIdx > selectedIdx then relativeIdx = relativeIdx - 1 end
		initY = chipY + pBtnH/2 + compactRowH/2 + 4 + relativeIdx * (compactRowH + 2)
	end
	
	list[#list + 1] = Def.ActorFrame {
		Name = "Row_" .. i,
		InitCommand = function(self) self:xy(initX, initY) end,
		
		ExpandedCommand = function(self)
			self:GetChild("Full"):stoptweening():linear(0.2):diffusealpha(1)
			self:GetChild("Mini"):stoptweening():linear(0.1):diffusealpha(0)
		end,
		MinimizedCommand = function(self)
			self:GetChild("Full"):stoptweening():linear(0.1):diffusealpha(0)
			self:GetChild("Mini"):stoptweening():linear(0.2):diffusealpha(1)
		end,
		
		-- Full Sized Display
		Def.ActorFrame {
			Name = "Full",
			InitCommand = function(self) self:diffusealpha(isInitiallySelected and 1 or 0) end,
			
			Def.Quad {
				InitCommand = function(self) self:zoomto(450, pBtnH):diffuse(color("0.1,0.1,0.1,0.95")):diffuseleftedge(accentColor) end
			},
			Def.Sprite {
				Name = "Avatar",
				InitCommand = function(self) 
					local path = getAssetPathFromProfileID("avatar", p.id)
					if path then self:Load(path) end
					self:xy(-180, 0):zoomto(50, 50) 
				end
			},
			LoadFont("Common Normal") .. {
				Text = p.name,
				InitCommand = function(self) self:xy(-140, -10):halign(0):zoom(0.6):diffuse(brightText) end
			},
			LoadFont("MSD 20px") .. {
				Text = string.format("%.2f", p.rating),
				InitCommand = function(self) self:xy(-140, 18):halign(0):zoom(0.8):diffuse(HVColor.GetMSDRatingColor(p.rating)) end
			},
			LoadFont("Common Normal") .. {
				Text = string.format("%d Songs", p.songs),
				InitCommand = function(self) self:xy(210, 18):halign(1):zoom(0.35):diffuse(subText) end
			}
		},
		
		-- Minimal Sized Display
		Def.ActorFrame {
			Name = "Mini",
			InitCommand = function(self) self:diffusealpha(isInitiallySelected and 0 or 1) end,
			
			Def.Quad {
				InitCommand = function(self) self:zoomto(450, compactRowH):diffuse(color("0.1,0.1,0.1,0.7")):diffuseleftedge(dimText) end
			},
			Def.Sprite {
				Name = "Avatar",
				InitCommand = function(self) 
					local path = getAssetPathFromProfileID("avatar", p.id)
					if path then self:Load(path) end
					self:xy(-210, 0):zoomto(22, 22) 
				end
			},
			LoadFont("Common Normal") .. {
				Text = p.name,
				InitCommand = function(self) self:xy(-190, 0):halign(0):zoom(0.4):diffuse(subText) end
			},
			LoadFont("Common Normal") .. {
				Text = string.format("%.2f", p.rating),
				InitCommand = function(self) self:xy(215, 0):halign(1):zoom(0.35):diffuse(dimText) end
			}
		},
		
		-- Click Handler
		UIElements.QuadButton(1) .. {
			InitCommand = function(self) self:zoomto(450, pBtnH):diffusealpha(0) end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" then
					if selectedIdx == (i - 1) then
						local top = SCREENMAN:GetTopScreen()
						if top and top.SetProfileIndex then
							top:SetProfileIndex(PLAYER_1, selectedIdx + 1)
							top:Finish()
							SOUND:PlayOnce(THEME:GetPathS("Common", "start"))
						end
					else
						selectedIdx = i - 1
						updateRows(self:GetParent():GetParent())
						SOUND:PlayOnce(THEME:GetPathS("Common", "value"))
					end
				end
			end
		}
	}
end

return t
