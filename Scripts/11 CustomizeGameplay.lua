local keymode
local allowedCustomization
local usingReverse
local WIDESCREENWHY = -5
local WIDESCREENWHX = -5

MovableValues = {}

local function loadValuesTable()
	allowedCustomization = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay
	usingReverse = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions():UsingReverse()

	-- Cache player data to reduce repeated lookups
	local playerData = playerConfig:get_data(pn_to_profile_slot(PLAYER_1))
	local gameplayCoords = playerData.GameplayXYCoordinates[keymode] or {}
	local gameplaySizes = playerData.GameplaySizes[keymode] or {}
	local function coord(name)
		return gameplayCoords[name] or getDefaultGameplayCoordinate(name) or 0
	end
	local function size(name)
		return gameplaySizes[name] or getDefaultGameplaySize(name) or 1
	end

	MovableValues = {}

	-- Batch assign values to reduce table lookups
	MovableValues.JudgeX = coord("JudgeX")
	MovableValues.JudgeY = coord("JudgeY")
	MovableValues.JudgeZoom = size("JudgeZoom")
	MovableValues.ComboX = coord("ComboX")
	MovableValues.ComboY = coord("ComboY")
	MovableValues.ComboZoom = size("ComboZoom")
	MovableValues.MiniProgressBarX = coord("MiniProgressBarX")
	MovableValues.MiniProgressBarY = coord("MiniProgressBarY")
	MovableValues.MiniProgressBarZoom = size("MiniProgressBarZoom")
	MovableValues.ErrorBarX = coord("ErrorBarX")
	MovableValues.ErrorBarY = coord("ErrorBarY")
	MovableValues.TargetTrackerX = coord("TargetTrackerX")
	MovableValues.TargetTrackerY = coord("TargetTrackerY")
	MovableValues.TargetTrackerZoom = size("TargetTrackerZoom")
	MovableValues.FullProgressBarX = coord("FullProgressBarX")
	MovableValues.FullProgressBarY = coord("FullProgressBarY")
	MovableValues.DisplayPercentX = coord("DisplayPercentX")
	MovableValues.DisplayPercentY = coord("DisplayPercentY")
	MovableValues.DisplayPercentZoom = size("DisplayPercentZoom")
	MovableValues.DisplayMeanX = coord("DisplayMeanX")
	MovableValues.DisplayMeanY = coord("DisplayMeanY")
	MovableValues.DisplayMeanZoom = size("DisplayMeanZoom")
	MovableValues.JudgeCounterX = coord("JudgeCounterX")
	MovableValues.JudgeCounterY = coord("JudgeCounterY")
	MovableValues.ReplayButtonsX = coord("ReplayButtonsX")
	MovableValues.ReplayButtonsY = coord("ReplayButtonsY")
	MovableValues.NPSGraphX = coord("NPSGraphX")
	MovableValues.NPSGraphY = coord("NPSGraphY")
	MovableValues.NPSGraphWidth = size("NPSGraphWidth")
	MovableValues.NPSGraphHeight = size("NPSGraphHeight")
	MovableValues.NPSDisplayX = coord("NPSDisplayX")
	MovableValues.NPSDisplayY = coord("NPSDisplayY")
	MovableValues.NPSDisplayZoom = size("NPSDisplayZoom")
	MovableValues.SSRDisplayX = coord("SSRDisplayX")
	MovableValues.SSRDisplayY = coord("SSRDisplayY")
	MovableValues.SSRDisplayZoom = size("SSRDisplayZoom")
	MovableValues.LeaderboardX = coord("LeaderboardX")
	MovableValues.LeaderboardY = coord("LeaderboardY")
	MovableValues.LeaderboardWidth = size("LeaderboardWidth")
	MovableValues.LeaderboardHeight = size("LeaderboardHeight")
	MovableValues.LifeP1X = coord("LifeP1X")
	MovableValues.LifeP1Y = coord("LifeP1Y")
	MovableValues.LifeP1Rotation = coord("LifeP1Rotation")
	MovableValues.PracticeCDGraphX = coord("PracticeCDGraphX")
	MovableValues.PracticeCDGraphY = coord("PracticeCDGraphY")
	MovableValues.PracticeLoopAttemptsX = coord("PracticeLoopAttemptsX")
	MovableValues.PracticeLoopAttemptsY = coord("PracticeLoopAttemptsY")
	MovableValues.BPMTextX = coord("BPMTextX")
	MovableValues.BPMTextY = coord("BPMTextY")
	MovableValues.BPMTextZoom = size("BPMTextZoom")
	MovableValues.RecentJudgmentDisplayX = coord("RecentJudgmentDisplayX")
	MovableValues.RecentJudgmentDisplayY = coord("RecentJudgmentDisplayY")
	MovableValues.RecentJudgmentDisplayZoom = size("RecentJudgmentDisplayZoom")
	MovableValues.DPDisplayX = coord("DPDisplayX")
	MovableValues.DPDisplayY = coord("DPDisplayY")
	MovableValues.DPDisplayZoom = size("DPDisplayZoom")
	MovableValues.AutoFailDisplayX = coord("AutoFailDisplayX")
	MovableValues.AutoFailDisplayY = coord("AutoFailDisplayY")
	MovableValues.AutoFailDisplayZoom = size("AutoFailDisplayZoom")
	MovableValues.NotefieldX = coord("NotefieldX")
	MovableValues.NotefieldY = coord("NotefieldY")
	MovableValues.NotefieldWidth = size("NotefieldWidth")
	MovableValues.NotefieldHeight = size("NotefieldHeight")
	MovableValues.NotefieldSpacing = size("NotefieldSpacing")
	MovableValues.ErrorBarScale = size("ErrorBarScale")

	-- Apply widescreen offsets
	if GetScreenAspectRatio() > 1.7 then
		MovableValues.TargetTrackerY = MovableValues.TargetTrackerY + WIDESCREENWHY
		MovableValues.TargetTrackerX = MovableValues.TargetTrackerX - WIDESCREENWHX
	end
end

function unsetMovableKeymode()
	MovableValues = {}
end

function setMovableKeymode(key)
	keymode = key
	loadValuesTable()
end

function setMovableActor(buttons, actor, border)
	if not allowedCustomization then return end
	for _, button in ipairs(buttons) do
		if Movable[button] then
			Movable[button].actor = actor
			Movable[button].element = actor
			Movable[button].condition = true
			if border then
				Movable[button].Border = border
			end
		end
	end
end

local noteColumns = {}
function spaceNotefieldCols(inc)
	if inc == nil then inc = 0 end
	for i = #noteColumns, 1, -1 do
		local col = noteColumns[i]
		local ok = col and col.addx and pcall(function()
			return col:GetX()
		end)
		if not ok then
			table.remove(noteColumns, i)
		end
	end
	local hCols = math.floor(#noteColumns / 2)
	for i, col in ipairs(noteColumns) do
		if col and col.addx then
			pcall(function()
				col:addx((i - hCols - 1) * inc)
			end)
		end
	end
end

function setMovableNotefield(notefield, columns)
	if not allowedCustomization then return end
	noteColumns = columns or {}
	Movable.DeviceButton_r.element = notefield
	Movable.DeviceButton_r.condition = true
	Movable.DeviceButton_t.element = noteColumns
	Movable.DeviceButton_t.condition = true
	Movable.DeviceButton_n.condition = true
	Movable.DeviceButton_n._lastSpacing = MovableValues.NotefieldSpacing or 0
	if Movable.DeviceButton_n._lastSpacing ~= 0 then
		spaceNotefieldCols(Movable.DeviceButton_n._lastSpacing)
	end
	Movable.DeviceButton_n.DeviceButton_up.arbitraryFunction = spaceNotefieldCols
	Movable.DeviceButton_n.DeviceButton_down.arbitraryFunction = spaceNotefieldCols
end

local propsFunctions = {
	X = Actor.x,
	Y = Actor.y,
	Zoom = Actor.zoom,
	Height = Actor.zoomtoheight,
	Width = Actor.zoomtowidth,
	AddX = Actor.addx,
	AddY = Actor.addy,
	Scale = function(self, val)
		self:playcommand("UpdateEBScale", {scale = val})
	end,
	Rotation = Actor.rotationz,
}

function GetGameplayCustomizationEntries()
	local entries, seen = {}, {}
	for button, entry in pairs(Movable) do
		if type(entry) == "table" and entry.name and entry.elementTree and entry.properties then
			local group = entry.name .. ":" .. entry.elementTree .. ":" .. table.concat(entry.properties, ",")
			if not seen[group] then
				seen[group] = true
				entries[#entries + 1] = {button = button, data = entry, key = group}
			end
		end
	end
	table.sort(entries, function(a, b)
		if a.data.name == b.data.name then
			return a.data.elementTree < b.data.elementTree
		end
		return a.data.name < b.data.name
	end)
	return entries
end

local function applyCustomizationEntry(entry, previousValues)
	local data = entry.data
	local actor = data.actor or data.element
	local hasSpacing = false
	for _, suffix in ipairs(data.properties or {}) do if suffix == "Spacing" then hasSpacing = true end end
	if not actor and not hasSpacing then return end
	for _, suffix in ipairs(data.properties or {}) do
		local value = MovableValues[data.name .. suffix]
		if value == nil then
			value = data.elementTree == "GameplaySizes"
				and getDefaultGameplaySize(data.name .. suffix)
				or getDefaultGameplayCoordinate(data.name .. suffix)
		end
		if value == nil then value = 0 end
		if suffix == "X" or suffix == "Y" then
			local difference = value - (previousValues and previousValues[data.name .. suffix] or value)
			local method = propsFunctions[suffix == "X" and "AddX" or "AddY"]
			if data.name == "Combo" and actor and difference ~= 0 then
				method(actor, difference)
			elseif data.children then
				for _, childName in ipairs(data.children) do
					local child = data.element[childName]
					if child and difference ~= 0 then method(child, difference) end
				end
			elseif actor and difference ~= 0 then
				method(actor, difference)
			end
		elseif data.arbitraryFunction then
			data.arbitraryFunction(value)
		elseif suffix == "Spacing" then
			spaceNotefieldCols(value - (data._lastSpacing or 0))
			data._lastSpacing = value
		elseif data.elementList then
			local method = propsFunctions[suffix]
			if method then for _, elem in ipairs(data.element) do method(elem, value) end end
		elseif suffix == "Scale" then
			actor:playcommand("UpdateEBScale", {scale = value})
		elseif propsFunctions[suffix] then
			propsFunctions[suffix](actor, value)
		end
	end
end

function SelectGameplayCustomizationEntry(entry)
	local borders = {}
	local selectedBorder
	for _, candidate in ipairs(GetGameplayCustomizationEntries()) do
		local border = candidate.data.Border
		if border then
			local matches = entry ~= nil and candidate.key == entry.key
			borders[border] = borders[border] or matches
		end
	end
	for border, selected in pairs(borders) do
		-- Borders are rendered by the editor's screen-level outline. Keeping
		-- embedded borders hidden lets the outline work for hidden HUD actors.
		local ok = pcall(function()
			border:visible(false):diffusealpha(selected and 1 or 0)
		end)
		-- Practice-mode reloads can destroy and recreate their actors while the
		-- customization menu still holds the previous border reference.
		if selected and ok then selectedBorder = border end
	end
	GameplayCustomizationSelectedBorder = selectedBorder
	MESSAGEMAN:Broadcast("MovableUpdated", {button = entry and entry.button})
end

function AdjustGameplayCustomization(entry, suffix, direction)
	local data = entry and entry.data
	if not data or data.condition == false or data.external then return end
	local propertyKey = data.name .. suffix
	local current = tonumber(MovableValues[propertyKey]) or 0
	if propertyKey == "FullProgressBarY" and data.actor and data.actor.GetTrueY then
		local ok, absoluteY = pcall(function() return data.actor:GetTrueY() end)
		if ok and type(absoluteY) == "number" then current = absoluteY end
	end
	local increment = 1
	local key = suffix == "X" and "DeviceButton_right"
		or suffix == "Y" and "DeviceButton_down"
		or (suffix == "Height" and "DeviceButton_down")
		or (suffix == "Width" and "DeviceButton_right")
		or "DeviceButton_right"
	local adjustment = data[key] or data.DeviceButton_up or data.DeviceButton_down
	if adjustment and adjustment.inc then increment = math.abs(adjustment.inc) end
	local nextValue = current + increment * direction
	if propertyKey == "ErrorBarScale" then nextValue = math.max(0, nextValue) end
	MovableValues[propertyKey] = nextValue
	if suffix == "Spacing" then
		spaceNotefieldCols(increment * direction)
		data._lastSpacing = nextValue
	elseif data.arbitraryFunction then
		data.arbitraryFunction(nextValue)
	elseif suffix == "Scale" then
		local actor = data.actor or data.element
		if actor then actor:playcommand("UpdateEBScale", {scale = nextValue}) end
	elseif suffix == "X" or suffix == "Y" then
		local axis = suffix
		local delta = increment * direction
		if suffix == "Y" and data.name == "Notefield" and not usingReverse then delta = -delta end
		local method = propsFunctions[axis == "X" and "AddX" or "AddY"]
		if data.name == "Combo" and data.element then
			method(data.element, delta)
		elseif data.children then
			for _, childName in ipairs(data.children) do
				local child = data.element[childName]
				if child then method(child, delta) end
			end
		elseif data.actor then method(data.actor, delta)
		elseif data.element then method(data.element, delta) end
	elseif data.elementList then
		for _, elem in ipairs(data.element) do propsFunctions[suffix](elem, nextValue) end
	else
		local actor = data.actor or data.element
		if actor and propsFunctions[suffix] then propsFunctions[suffix](actor, nextValue) end
	end
	if data.Border and (suffix == "Zoom" or suffix == "Width" or suffix == "Height") then
		data.Border:playcommand("Change" .. suffix, {val = nextValue})
	end
	local playerData = playerConfig:get_data(pn_to_profile_slot(PLAYER_1))
	playerData[data.elementTree][keymode] = playerData[data.elementTree][keymode] or {}
	playerData[data.elementTree][keymode][propertyKey] = nextValue
	playerConfig:set_dirty(pn_to_profile_slot(PLAYER_1))
end

function MoveGameplayCustomizationPosition(entry, suffix, screenDelta)
	local data = entry and entry.data
	if not data or data.condition == false or data.external then return end
	if (suffix ~= "X" and suffix ~= "Y") or screenDelta == 0 then return end
	local key = data.name .. suffix
	local valueDelta = screenDelta
	if suffix == "Y" and data.name == "Notefield" and not usingReverse then
		valueDelta = -screenDelta
	end
	local nextValue = (tonumber(MovableValues[key]) or 0) + valueDelta
	MovableValues[key] = nextValue
	if data.name == "FullProgressBar" and suffix == "Y" then
		local actor = data.actor or data.element
		if actor then actor:y(nextValue) end
	elseif data.name == "Combo" and data.element then
		local method = propsFunctions[suffix == "X" and "AddX" or "AddY"]
		method(data.element, screenDelta)
	elseif data.children then
		local method = propsFunctions[suffix == "X" and "AddX" or "AddY"]
		for _, childName in ipairs(data.children) do
			local child = data.element and data.element[childName]
			if child then method(child, screenDelta) end
		end
	else
		local actor = data.actor or data.element
		local method = propsFunctions[suffix == "X" and "AddX" or "AddY"]
		if actor then method(actor, screenDelta) end
	end
	local playerData = playerConfig:get_data(pn_to_profile_slot(PLAYER_1))
	playerData[data.elementTree][keymode] = playerData[data.elementTree][keymode] or {}
	playerData[data.elementTree][keymode][key] = nextValue
	playerConfig:set_dirty(pn_to_profile_slot(PLAYER_1))
end

function ResetGameplayCustomizationProperty(entry, suffix)
	local data = entry and entry.data
	if not data or data.condition == false or data.external then return end
	local propertyKey = data.name .. suffix
	local defaultValue = data.elementTree == "GameplaySizes"
		and getDefaultGameplaySize(propertyKey)
		or getDefaultGameplayCoordinate(propertyKey)
	if defaultValue == nil then return end
	if propertyKey == "FullProgressBarY" then
		local position = HV.GetProgressBarPosition()
		defaultValue = position == "Bottom" and (SCREEN_BOTTOM - 14) or 12
	end
	local current = tonumber(MovableValues[propertyKey]) or 0
	local delta = defaultValue - current
	MovableValues[propertyKey] = defaultValue
	if suffix == "Spacing" then
		spaceNotefieldCols(delta)
		data._lastSpacing = defaultValue
	elseif data.arbitraryFunction then
		data.arbitraryFunction(defaultValue)
	elseif suffix == "Scale" then
		local actor = data.actor or data.element
		if actor then actor:playcommand("UpdateEBScale", {scale = defaultValue}) end
	elseif suffix == "X" or suffix == "Y" then
		if data.name == "FullProgressBar" and suffix == "Y" and data.element and data.element.y then
			data.element:y(defaultValue)
		elseif data.name == "Combo" and data.element and delta ~= 0 then
			local method = propsFunctions[suffix == "X" and "AddX" or "AddY"]
			method(data.element, delta)
		elseif data.children then
			local method = propsFunctions[suffix == "X" and "AddX" or "AddY"]
			for _, childName in ipairs(data.children) do
				local child = data.element[childName]
				if child and delta ~= 0 then method(child, delta) end
			end
		else
			local actor = data.actor or data.element
			local method = propsFunctions[suffix == "X" and "AddX" or "AddY"]
			if actor and delta ~= 0 then method(actor, delta) end
		end
	elseif data.elementList then
		for _, actor in ipairs(data.element) do propsFunctions[suffix](actor, defaultValue) end
	else
		local actor = data.actor or data.element
		if actor and propsFunctions[suffix] then propsFunctions[suffix](actor, defaultValue) end
	end
	if data.Border and (suffix == "Zoom" or suffix == "Width" or suffix == "Height") then
		data.Border:playcommand("Change" .. suffix, {val = defaultValue})
	end
	local playerData = playerConfig:get_data(pn_to_profile_slot(PLAYER_1))
	playerData[data.elementTree][keymode] = playerData[data.elementTree][keymode] or {}
	playerData[data.elementTree][keymode][propertyKey] = defaultValue
	playerConfig:set_dirty(pn_to_profile_slot(PLAYER_1))
end

function GetGameplayCustomizationSnapshot()
	local pdata = playerConfig:get_data(pn_to_profile_slot(PLAYER_1))
	local function clone(source)
		local copy = {}
		for key, value in pairs(source or {}) do
			copy[key] = type(value) == "table" and clone(value) or value
		end
		return copy
	end
	return {
		coords = clone(pdata.GameplayXYCoordinates[keymode]),
		sizes = clone(pdata.GameplaySizes[keymode]),
		values = clone(MovableValues)
	}
end

function RestoreGameplayCustomizationSnapshot(snapshot)
	if not snapshot then return end
	local previousValues = {}
	for key, value in pairs(MovableValues) do previousValues[key] = value end
	local pdata = playerConfig:get_data(pn_to_profile_slot(PLAYER_1))
	pdata.GameplayXYCoordinates[keymode] = snapshot.coords
	pdata.GameplaySizes[keymode] = snapshot.sizes
	MovableValues = snapshot.values
	for _, entry in ipairs(GetGameplayCustomizationEntries()) do applyCustomizationEntry(entry, previousValues) end
	playerConfig:set_dirty(pn_to_profile_slot(PLAYER_1))
end

function ResetGameplayCustomizationKeymode()
	local pdata = playerConfig:get_data(pn_to_profile_slot(PLAYER_1))
	local previousValues = {}
	for key, value in pairs(MovableValues) do previousValues[key] = value end
	local coords, sizes = {}, {}
	for _, entry in ipairs(GetGameplayCustomizationEntries()) do
		for _, suffix in ipairs(entry.data.properties) do
			local property = entry.data.name .. suffix
			if entry.data.elementTree == "GameplayXYCoordinates" then
				coords[property] = getDefaultGameplayCoordinate(property) or 0
			else
				sizes[property] = getDefaultGameplaySize(property) or 1
			end
		end
	end
	pdata.GameplayXYCoordinates[keymode] = coords
	pdata.GameplaySizes[keymode] = sizes
	loadValuesTable()
	for _, entry in ipairs(GetGameplayCustomizationEntries()) do applyCustomizationEntry(entry, previousValues) end
	playerConfig:set_dirty(pn_to_profile_slot(PLAYER_1))
end

Movable = {
	message = {},
	current = "None",
	pressed = false,
	DeviceButton_1 = {
		name = "Judge",
		textHeader = "Judgment Label Position:",
		element = {},
		children = {"Judgment", "Border"},
		properties = {"X", "Y"},
		mouseRelativeToCenter = true,
		-- PlayerJudgment is already centered by the gameplay player actor.
		-- JudgeX/JudgeY are offsets from that origin, so applying the mouse
		-- position as an absolute screen coordinate double-adds half the
		-- screen width/height and separates the label from its cursor.
		actorUsesAbsolutePosition = false,
		propertyOffsets = nil,	-- manual offsets for stuff hardcoded to be relative to center and maybe other things (init in wifejudgmentspotting)
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {
			property = "AddY",
			inc = -5
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 5
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -5
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 5
		}
	},
	DeviceButton_2 = {	-- note: there's almost certainly an update function associated with this that is doing things we aren't aware of
		name = "Judge",
		textHeader = "Judgment Label Size:",
		element = {},
		children = {"Judgment"},
		properties = {"Zoom"},
		elementTree = "GameplaySizes",
		noBorder = true,
		arbitraryFunction = function(val)
			local actor = Movable.DeviceButton_2.actor
			if not actor then return end
			actor:zoom(val)
			local offsetText = actor:GetChild("JudgmentContainer"):GetChild("OffsetText")
			if offsetText then offsetText:zoom(0.455 / val) end
		end,
		DeviceButton_up = {
			property = "Zoom",
			inc = 0.01
		},
		DeviceButton_down = {
			property = "Zoom",
			inc = -0.01
		}
	},
	DeviceButton_3 = {
		name = "Combo",
		textHeader = "Combo Position:",
		element = {},
		children = {"Label", "Number", "Border"},
		properties = {"X", "Y"},
		mouseRelativeToCenter = true,
		actorUsesAbsolutePosition = true,
		propertyOffsets = nil,
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {
			property = "AddY",
			inc = -5
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 5
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -5
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 5
		}
	},
	DeviceButton_4 = {	-- combo and label are 2 text objects, 1 right aligned and 1 left, this makes border resizing desync from the text sometimes
		name = "Combo",	-- i really dont want to deal with this right now -mina
		textHeader = "Combo Size:",
		element = {},
		children = {"Label", "Number"},
		properties = {"Zoom"},
		elementTree = "GameplaySizes",
		noBorder = true,
		DeviceButton_up = {
			property = "Zoom",
			inc = 0.01
		},
		DeviceButton_down = {
			property = "Zoom",
			inc = -0.01
		}
	},
	DeviceButton_5 = {
		name = "ErrorBar",
		textHeader = "Error Bar Position:",
		element = {},
		properties = {"X", "Y"},
		children = {"Center", "WeightedBar", "Border"},
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {
			property = "AddY",
			inc = -5
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 5
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -5
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 5
		}
	},
	DeviceButton_6 = {
		name = "ErrorBar",
		textHeader = "Error Bar Scale:",
		element = {},
		properties = {"Scale"},
		elementTree = "GameplaySizes",
		DeviceButton_up = {
			property = "Scale",
			inc = 0.05
		},
		DeviceButton_down = {
			property = "Scale",
			inc = -0.05
		},
		DeviceButton_left = {
			property = "Scale",
			inc = -0.05
		},
		DeviceButton_right = {
			property = "Scale",
			inc = 0.05
		}
	},
	DeviceButton_7 = {
		name = "TargetTracker",
		textHeader = "Goal Tracker Position:",
		element = {},
		properties = {"X", "Y"},
		-- no children so the changes are applied to the element itself
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {
			property = "AddY",
			inc = -5
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 5
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -5
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 5
		}
	},
	DeviceButton_8 = {
		name = "TargetTracker",
		textHeader = "Goal Tracker Size:",
		element = {},
		properties = {"Zoom"},
		elementTree = "GameplaySizes",
		DeviceButton_up = {
			property = "Zoom",
			inc = 0.01
		},
		DeviceButton_down = {
			property = "Zoom",
			inc = -0.01
		}
	},
	DeviceButton_9 = {
		name = "FullProgressBar",
		textHeader = "Full Progress Bar Position:",
		element = {},
		properties = {"X", "Y"},
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {
			property = "AddY",
			inc = -3
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 3
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -5
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 5
		}
	},
	DeviceButton_q = {
		name = "MiniProgressBar",
		textHeader = "Mini Progress Bar Position:",
		element = {}, properties = {"X", "Y"},
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = { property = "AddY", inc = -3 }, DeviceButton_down = { property = "AddY", inc = 3 },
		DeviceButton_left = { property = "AddX", inc = -5 }, DeviceButton_right = { property = "AddX", inc = 5 }
	},
	DeviceButton_e = {
		name = "MiniProgressBar", textHeader = "Mini Progress Bar Zoom:",
		element = {}, properties = {"Zoom"}, elementTree = "GameplaySizes",
		DeviceButton_up = { property = "Zoom", inc = 0.05 }, DeviceButton_down = { property = "Zoom", inc = -0.05 }
	},
	DeviceButton_w = {
		name = "DisplayPercent",
		textHeader = "Current Percent Position:",
		element = {},
		properties = {"X", "Y"},
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {
			property = "AddY",
			inc = -5
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 5
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -5
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 5
		}
	},
	DeviceButton_e = {
		name = "DisplayPercent",
		textHeader = "Current Percent Size:",
		element = {},
		properties = {"Zoom"},
		elementTree = "GameplaySizes",
		DeviceButton_up = {
			property = "Zoom",
			inc = 0.01
		},
		DeviceButton_down = {
			property = "Zoom",
			inc = -0.01
		}
	},
	DeviceButton_r = {
		name = "Notefield",
		textHeader = "Notefield Position:",
		element = {},
		properties = {"X", "Y"},
		elementTree = "GameplayXYCoordinates",
		noBorder = true,
		DeviceButton_up = {
			notefieldY = true,
			property = "AddY",
			inc = -3
		},
		DeviceButton_down = {
			notefieldY = true,
			property = "AddY",
			inc = 3
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -3
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 3
		}
	},
	DeviceButton_t = {
		name = "Notefield",
		textHeader = "Notefield Size:",
		element = {},
		elementList = true, -- god bless the notefield
		properties = {"Width", "Height"},
		elementTree = "GameplaySizes",
		noBorder = true,
		DeviceButton_up = {
			property = "Height",
			inc = 0.01
		},
		DeviceButton_down = {
			property = "Height",
			inc = -0.01
		},
		DeviceButton_left = {
			property = "Width",
			inc = -0.01
		},
		DeviceButton_right = {
			property = "Width",
			inc = 0.01
		}
	},
	DeviceButton_n = {
		name = "Notefield",
		textHeader = "Notefield Columns:",
		properties = {"Spacing"},
		elementTree = "GameplaySizes",
		noBorder = true,
		DeviceButton_up = {
			arbitraryInc = true,
			property = "Spacing",
			inc = 1
		},
		DeviceButton_down = {
			arbitraryInc = true,
			property = "Spacing",
			inc = -1
		},
	},
	DeviceButton_y = {
		name = "NPSDisplay",
		textHeader = "NPS Display Position:",
		element = {},
		properties = {"X", "Y"},
		propertyOffsets = {55, -9},
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {
			property = "AddY",
			inc = -5
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 5
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -5
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 5
		}
	},
	DeviceButton_u = {
		name = "NPSDisplay",
		textHeader = "NPS Display Size:",
		element = {},
		properties = {"Zoom"},
		elementTree = "GameplaySizes",
		DeviceButton_up = {
			property = "Zoom",
			inc = 0.01
		},
		DeviceButton_down = {
			property = "Zoom",
			inc = -0.01
		}
	},
	DeviceButton_j = {
		name = "SSRDisplay",
		textHeader = "SSR Display Position:",
		element = {},
		properties = {"X", "Y"},
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {property = "AddY", inc = -5},
		DeviceButton_down = {property = "AddY", inc = 5},
		DeviceButton_left = {property = "AddX", inc = -5},
		DeviceButton_right = {property = "AddX", inc = 5}
	},
	DeviceButton_k = {
		name = "SSRDisplay",
		textHeader = "SSR Display Size:",
		element = {},
		properties = {"Zoom"},
		elementTree = "GameplaySizes",
		DeviceButton_up = {property = "Zoom", inc = 0.01},
		DeviceButton_down = {property = "Zoom", inc = -0.01}
	},
	DeviceButton_i = {
		name = "NPSGraph",
		textHeader = "NPS Graph Position:",
		element = {},
		properties = {"X", "Y"},
		propertyOffsets = {70, 25},
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {
			property = "AddY",
			inc = -5
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 5
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -5
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 5
		}
	},
	DeviceButton_o = {
		name = "NPSGraph",
		textHeader = "NPS Graph Size:",
		element = {},
		properties = {"Width", "Height"},
		noBorder = true,
		elementTree = "GameplaySizes",
		DeviceButton_up = {
			property = "Height",
			inc = 0.01
		},
		DeviceButton_down = {
			property = "Height",
			inc = -0.01
		},
		DeviceButton_left = {
			property = "Width",
			inc = -0.01
		},
		DeviceButton_right = {
			property = "Width",
			inc = 0.01
		}
	},
	DeviceButton_p = {
		name = "JudgeCounter",
		textHeader = "Judge Counter Position:",
		element = {},
		properties = {"X", "Y"},
		propertyOffsets = {70, 50},
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {
			property = "AddY",
			inc = -3
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 3
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -3
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 3
		}
	},
	DeviceButton_a = {
		name = "Leaderboard",
		textHeader = "Leaderboard Position:",
		properties = {"X", "Y"},
		element = {},
		propertyOffsets = {77.5, 123},
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {
			property = "AddY",
			inc = -3
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 3
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -3
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 3
		}
	},
	DeviceButton_s = {
		name = "Leaderboard",
		textHeader = "Leaderboard Size:",
		properties = {"Width", "Height"},
		element = {},
		elementTree = "GameplaySizes",
		noBorder = true,
		DeviceButton_up = {
			property = "Height",
			inc = 0.01
		},
		DeviceButton_down = {
			property = "Height",
			inc = -0.01
		},
		DeviceButton_left = {
			property = "Width",
			inc = -0.01
		},
		DeviceButton_right = {
			property = "Width",
			inc = 0.01
		}
	},
	DeviceButton_f = {
		name = "ReplayButtons",
		textHeader = "Replay Buttons Position:",
		element = {},
		properties = {"X", "Y"},
		elementTree = "GameplayXYCoordinates",
		condition = false,
		DeviceButton_up = {
			property = "AddY",
			inc = -3
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 3
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -3
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 3
		}
	},
	DeviceButton_g = {
		name = "AutoFailDisplay",
		textHeader = "Auto-Fail Display Position:",
		element = {},
		properties = {"X", "Y"},
		elementTree = "GameplayXYCoordinates",
		condition = false,
		DeviceButton_up = {
			property = "AddY",
			inc = -3
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 3
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -3
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 3
		}
	},
	DeviceButton_h = {
		name = "AutoFailDisplay",
		textHeader = "Auto-Fail Display Size:",
		element = {},
		properties = {"Zoom"},
		elementTree = "GameplaySizes",
		condition = false,
		DeviceButton_up = {
			property = "Zoom",
			inc = 0.01
		},
		DeviceButton_down = {
			property = "Zoom",
			inc = -0.01
		}
	},
	DeviceButton_z = {
		name = "PracticeCDGraph",
		textHeader = "Chord Density Graph Position:",
		properties = {"X","Y"},
		element = {},
		elementTree = "GameplayXYCoordinates",
		propertyOffsets = nil,
		DeviceButton_up = {
			property = "AddY",
			inc = -5
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 5
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -5
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 5
		}
	},
	DeviceButton_F1 = {
		name = "PracticeLoopAttempts",
		textHeader = "Loop Attempt Graph Position:",
		element = {}, properties = {"X", "Y"}, elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {property = "AddY", inc = -5}, DeviceButton_down = {property = "AddY", inc = 5},
		DeviceButton_left = {property = "AddX", inc = -5}, DeviceButton_right = {property = "AddX", inc = 5}
	},
	DeviceButton_x = {
		name = "BPMText",
		textHeader = "BPM / Rate Position:",
		element = {},
		properties = {"X", "Y"},
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {
			property = "AddY",
			inc = -5
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 5
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -5
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 5
		}
	},
	DeviceButton_c = {
		name = "BPMText",
		textHeader = "BPM / Rate Size:",
		element = {},
		properties = {"Zoom"},
		elementTree = "GameplaySizes",
		DeviceButton_up = {
			property = "Zoom",
			inc = 0.01
		},
		DeviceButton_down = {
			property = "Zoom",
			inc = -0.01
		}
	},
	DeviceButton_v = {
		name = "RecentJudgmentDisplay",
		textHeader = "Recent Judgment Display Position:",
		element = {},
		properties = {"X", "Y"},
		elementTree = "GameplayXYCoordinates",
		propertyOffsets = {0, 76},
		DeviceButton_up = {
			property = "AddY",
			inc = -5
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 5
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -5
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 5
		}
	},
	DeviceButton_b = {
		name = "RecentJudgmentDisplay",
		textHeader = "Recent Judgment Display Size:",
		element = {},
		properties = {"Zoom"},
		elementTree = "GameplaySizes",
		DeviceButton_up = {
			property = "Zoom",
			inc = 0.01
		},
		DeviceButton_down = {
			property = "Zoom",
			inc = -0.01
		}
	},
	DeviceButton_m = {
		name = "DisplayMean",
		textHeader = "Current Mean Position:",
		element = {},
		properties = {"X", "Y"},
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {
			property = "AddY",
			inc = -5
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 5
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -5
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 5
		}
	},
	DeviceButton_comma = {
		name = "DisplayMean",
		textHeader = "Current Mean Size:",
		element = {},
		properties = {"Zoom"},
		elementTree = "GameplaySizes",
		DeviceButton_up = {
			property = "Zoom",
			inc = 0.01
		},
		DeviceButton_down = {
			property = "Zoom",
			inc = -0.01
		}
	},
	DeviceButton_period = {
		name = "DPDisplay",
		textHeader = "DP Display Position:",
		element = {},
		properties = {"X", "Y"},
		elementTree = "GameplayXYCoordinates",
		DeviceButton_up = {
			property = "AddY",
			inc = -3
		},
		DeviceButton_down = {
			property = "AddY",
			inc = 3
		},
		DeviceButton_left = {
			property = "AddX",
			inc = -3
		},
		DeviceButton_right = {
			property = "AddX",
			inc = 3
		}
	},
	DeviceButton_slash = {
		name = "DPDisplay",
		textHeader = "DP Display Size:",
		properties = {"Zoom"},
		element = {},
		elementTree = "GameplaySizes",
		DeviceButton_up = {
			property = "Zoom",
			inc = 0.01
		},
		DeviceButton_down = {
			property = "Zoom",
			inc = -0.01
		}
	}
	
}

function setBorderAlignment(self, h, v)
	self:RunCommandsOnChildren(
		function(self)
			self:halign(h):valign(v)
		end
	)
	self:GetChild("hideybox"):addx(-2 * (h - 0.5))
	self:GetChild("hideybox"):addy(-2 * (v - 0.5))
end

function setBorderToText(b, t)
	b:playcommand("ChangeWidth", {val = t:GetZoomedWidth()})
	b:playcommand("ChangeHeight", {val = t:GetZoomedHeight()})
	b:playcommand("ChangeZoom", {val = t:GetParent():GetZoom()})
end

-- this is supreme lazy -mina
-- border function in use -mina
function MovableBorder(width, height, bw, x, y)
	if not allowedCustomization then return end	-- we don't want to be loading all this garbage if we aren't in customization
	return Def.ActorFrame {
		Name = "Border",
		InitCommand=function(self) self:xy(x,y):visible(false):diffusealpha(0) end,
		OnCommand=function(self)
			if SCREENMAN:GetTopScreen():GetName() == "ScreenGameplaySyncMachine" then
				self:visible(false)
			end
		end,
		UpdateEBWidthCommand=function(self, params)
			self:playcommand("ChangeWidth", {val = params.width})
		end,
		ChangeWidthCommand=function(self, params)
			self:GetChild("xbar"):zoomx(params.val)
			self:GetChild("showybox"):zoomx(params.val)
			self:GetChild("hideybox"):zoomx(params.val-2*bw)
		end,
		ChangeHeightCommand=function(self, params)
			self:GetChild("ybar"):zoomy(params.val)
			self:GetChild("showybox"):zoomy(params.val)
			self:GetChild("hideybox"):zoomy(params.val-2*bw)
		end,
		ChangeZoomCommand=function(self,params)
			local wot = self:GetZoom()/(1/params.val)
			self:zoom(1/params.val)
			self:playcommand("ChangeWidth", {val = self:GetChild("showybox"):GetZoomX() * wot})
			self:playcommand("ChangeHeight", {val = self:GetChild("showybox"):GetZoomY() * wot})
		end,
		Def.Quad {
			Name = "xbar",
			InitCommand=function(self)
				self:zoomto(width,bw):diffusealpha(0.5)	-- did not realize this was multiplicative with parent's value -mina
			end
		},
		Def.Quad {
			Name = "ybar",
			InitCommand=function(self)
				self:zoomto(bw,height):diffusealpha(0.5)
			end
		},
		Def.Quad {
			Name = "hideybox",
			InitCommand=function(self)
				self:zoomto(width-2*bw, height-2*bw):MaskSource(true)
			end
		},
		Def.Quad {
			Name = "showybox",
			InitCommand=function(self)
				self:zoomto(width,height):MaskDest()
			end,
		},
	}
end
