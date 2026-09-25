--- Holographic Void: Custom Mouse Cursor
-- Adapted from Til Death's _cursor.lua pattern.
-- Should be loaded from screen overlays via LoadActor("_cursor").
-- Integrates with the _fallback BUTTON system for UIElements click support.

local screenName = Var("LoadingScreen") or ...
local topScreen
local pointerActor
-- ScreenTextEntry has its own visual cursor, but it must not touch the shared
-- BUTTON state.  Modal screens can inherit the caller's LoadingScreen value,
-- so resetting here would clear the caller's hover/cursor state.
local currentScreen = SCREENMAN:GetTopScreen()
local isTextEntry = screenName == "ScreenTextEntry"
	 or (currentScreen and currentScreen:GetName() == "ScreenTextEntry")
if not isTextEntry then
	BUTTON:ResetButtonTable(screenName)
end

local function UpdateLoop()
	local mouseX = INPUTFILTER:GetMouseX()
	local mouseY = INPUTFILTER:GetMouseY()
	-- SetPosition intentionally returns early while the tooltip actor is being
	-- recreated. The pointer is a separate actor, so update it directly too.
	if pointerActor then
		pcall(function() pointerActor:xy(mouseX, mouseY) end)
	end
	pcall(function() TOOLTIP:SetPosition(mouseX, mouseY) end)
	if not isTextEntry then
		BUTTON:UpdateMouseState()
	end
	return false
end

local function updatePointerImmediately()
	-- A screen can regain focus before its first update tick.  Reposition the
	-- pointer here so returning from a sub-screen does not leave it at its old
	-- coordinates until the next mouse event.
	UpdateLoop()
end

-- ScreenTextEntry is pushed as a modal screen and is often popped from inside
-- its input callback.  In that case GainFocus can run before the screen stack
-- has finished changing, so the mouse position/button state is refreshed
-- against the text-entry screen instead of the screen underneath it.
local function refreshAfterModalPop(self)
	self:sleep(0):queuecommand("RefreshCursor")
end

local function cursorCheck()
	-- Show custom cursor in fullscreen (system cursor hidden)
	-- In windowed mode, the system cursor is visible so hide ours
	if not PREFSMAN:GetPreference("Windowed") and not PREFSMAN:GetPreference("FullscreenIsBorderlessWindow") then
		TOOLTIP:ShowPointer()
		if pointerActor then pointerActor:visible(true) end
	else
		TOOLTIP:HidePointer()
		if pointerActor then pointerActor:visible(false) end
	end
end

-- Registers (or re-registers) the BUTTON input callback on the current top screen.
-- Must be called both at init and whenever this screen regains focus after a
-- sub-screen is popped, because AddInputCallback only wires up a single screen handle.
local function registerInputCallback()
	if isTextEntry then return end
	topScreen = SCREENMAN:GetTopScreen()
	if topScreen then
		topScreen:AddInputCallback(function(event)
			if BUTTON and type(BUTTON.InputCallback) == "function" then
				BUTTON.InputCallback(event)
			end
		end)
	end
end

local t = Def.ActorFrame {
	OnCommand = function(self)
		self:draworder(20000)
		self:SetUpdateFunction(UpdateLoop)
		-- Match display refresh rate for smooth cursor tracking
		local refreshRate = DISPLAY:GetDisplayRefreshRate()
		if refreshRate and refreshRate > 0 then
			self:SetUpdateFunctionInterval(1 / refreshRate)
		end
		registerInputCallback()
		cursorCheck()
	end,
	-- Re-register when a sub-screen (e.g. ScreenHVColorEdit) is popped and this
	-- screen becomes the top screen again; the old topScreen handle is stale by then.
	GainFocusCommand = function(self)
		registerInputCallback()
		cursorCheck()
		updatePointerImmediately()
		refreshAfterModalPop(self)
	end,
	RefreshCursorCommand = function(self)
		registerInputCallback()
		cursorCheck()
		updatePointerImmediately()
	end,
	OffCommand = function(self)
		if not isTextEntry then
			BUTTON:ResetButtonTable(screenName)
		end
		pcall(function() TOOLTIP:Hide() end)
	end,
	CancelCommand = function(self)
		self:playcommand("Off")
	end,
	WindowedChangedMessageCommand = function(self)
		cursorCheck()
	end,
	ReloadedScriptsMessageCommand = function(self)
		cursorCheck()
	end,
}

-- Create tooltip + pointer + click wave actors from the _fallback system
local tooltip, pointer, clickwave = TOOLTIP:New()
pointerActor = pointer
t[#t + 1] = tooltip
t[#t + 1] = pointer
t[#t + 1] = clickwave

return t
