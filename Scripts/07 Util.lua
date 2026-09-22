--- Holographic Void: Utility Functions
-- Ported and adapted from Til Death for consistent engine-level interactions.

-- ms fallback for notifications and judge scaling
ms = ms or {}
ms.JudgeScalers = {
	1.5,   -- J1
	1.33,  -- J2
	1.16,  -- J3
	1.0,   -- J4 (Standard)
	0.84,  -- J5
	0.66,  -- J6
	0.5,   -- J7
	0.33,  -- J8
	0.2,   -- J9
}

-- Shared comment wrapping is defined here because screen decorations can be
-- constructed before the later score/rescore utility script is loaded.
HV = HV or {}
function HV.WrapScoreComment(text, maxCharacters)
	local lines = {}
	maxCharacters = math.max(1, tonumber(maxCharacters) or 40)
	for paragraph in (tostring(text or "") .. "\n"):gmatch("([^\r\n]*)\r?\n") do
		if paragraph ~= "" then
			local line = ""
			for word in paragraph:gmatch("%S+") do
				local candidate = line == "" and word or (line .. " " .. word)
				if line ~= "" and #candidate > maxCharacters then
					lines[#lines + 1] = line
					line = word
				else
					line = candidate
				end
			end
			if line ~= "" then lines[#lines + 1] = line end
		else
			lines[#lines + 1] = ""
		end
	end
	return table.concat(lines, "\n")
end

function ms.ok(text)
	SCREENMAN:SystemMessage(text)
end

--- Open a ScreenTextEntry popup with OK and Cancel callbacks.
-- @param question   The question/prompt to display
-- @param maxLength  Maximum input character length
-- @param isPassword Boolean to mask the input
-- @param funcOK     Function(answer) to call on OK
-- @param funcCancel Function() to call on Cancel or Esc
function easyInputStringOKCancel(question, maxLength, isPassword, funcOK, funcCancel, initialText)
	SCREENMAN:AddNewScreenToTop("ScreenTextEntry")
	local settings = {
		Question = question,
		MaxInputLength = maxLength,
		Password = isPassword,
		InitialText = initialText or "",
		OnOK = function(answer)
			local top = SCREENMAN:GetTopScreen()
			if top and top:GetName() == "ScreenTextEntry" then top:Cancel() end
			funcOK(answer)
		end,
		OnCancel = function()
			local top = SCREENMAN:GetTopScreen()
			if top and top:GetName() == "ScreenTextEntry" then top:Cancel() end
			if funcCancel then funcCancel() end
		end,
	}
	SCREENMAN:GetTopScreen():Load(settings)
end

--- Wrapper for simple text entry with only an OK callback.
-- @param question   The question/prompt to display
-- @param maxLength  Maximum input character length
-- @param isPassword Boolean to mask the input
-- @param func       Function(answer) to call on OK
function easyInputStringWithFunction(question, maxLength, isPassword, func)
	easyInputStringOKCancel(
		question,
		maxLength,
		isPassword,
		function(answer)
			func(answer)
		end,
		nil
	)
end

--- Map a DeviceInput button name to its equivalent character.
-- @param btn     The button string (e.g., "DeviceButton_a")
-- @param shifted Boolean for shift key state
-- @return        A single character string, or nil
function DeviceBtnToChar(btn, shifted)
	if not btn then return nil end
	local b = btn:lower()
	
	-- Standard Letters (devicebutton_a to devicebutton_z)
	local letter = b:match("^devicebutton_([a-z])$")
	if letter then return shifted and letter:upper() or letter end
	
	-- Standard Digits (devicebutton_0 to devicebutton_9)
	local digit = b:match("^devicebutton_([0-9])$")
	-- Numpad Digits (devicebutton_kp 0 to devicebutton_kp 9)
	if not digit then digit = b:match("^devicebutton_kp ([0-9])$") end
	
	if digit then
		if shifted then
			local shiftMap = { ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%",
				["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(", ["0"] = ")" }
			return shiftMap[digit] or digit
		end
		return digit
	end
	
	-- Symbols and Special Keys
	local symMap = {
		["devicebutton_period"] = shifted and ">" or ".",
		["devicebutton_comma"] = shifted and "<" or ",",
		["devicebutton_slash"] = shifted and "?" or "/",
		["devicebutton_backslash"] = shifted and "|" or "\\",
		["devicebutton_minus"] = shifted and "_" or "-",
		["devicebutton_equals"] = shifted and "+" or "=",
		["devicebutton_semicolon"] = shifted and ":" or ";",
		["devicebutton_apostrophe"] = shifted and "\"" or "'",
		["devicebutton_left bracket"] = shifted and "{" or "[",
		["devicebutton_right bracket"] = shifted and "}" or "]",
		["devicebutton_grave"] = shifted and "~" or "`",
		["devicebutton_space"] = " ",
		-- Numpad Operators
		["devicebutton_kp /"] = "/",
		["devicebutton_kp *"] = "*",
		["devicebutton_kp -"] = "-",
		["devicebutton_kp +"] = "+",
		["devicebutton_kp ."] = ".",
	}
	return symMap[b]
end

Trace("Holographic Void: 07 Util.lua loaded.")
