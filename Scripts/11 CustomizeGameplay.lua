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
	MovableValues.LeaderboardX = coord("LeaderboardX")
	MovableValues.LeaderboardY = coord("LeaderboardY")
	MovableValues.LeaderboardWidth = size("LeaderboardWidth")
	MovableValues.LeaderboardHeight = size("LeaderboardHeight")
	MovableValues.LifeP1X = coord("LifeP1X")
	MovableValues.LifeP1Y = coord("LifeP1Y")
	MovableValues.LifeP1Rotation = coord("LifeP1Rotation")
	MovableValues.PracticeCDGraphX = coord("PracticeCDGraphX")
	MovableValues.PracticeCDGraphY = coord("PracticeCDGraphY")
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

local Round = notShit.round
local Floor = notShit.floor
local queuecommand = Actor.queuecommand
local playcommand = Actor.queuecommand
local settext = BitmapText.settext

local function isCustomizeAutoplayActive()
	if getAutoplay and getAutoplay() ~= 0 then return true end
	local ps = GAMESTATE:GetPlayerState(PLAYER_1)
	return ps and ps.GetPlayerController and ps:GetPlayerController() == "PlayerController_Autoplay"
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

local function updatetext(button)
	local text = {Movable[button].textHeader}
	for _, prop in ipairs(Movable[button].properties) do
		local fullProp = Movable[button].name .. prop
		local val = MovableValues[fullProp]
		if type(val) == "number" then
			val = string.format("%.2f", val)
		end
		table.insert(text, prop .. ": " .. (val or "nil"))
	end
	Movable.current = button
	Movable.message:settext(table.concat(text, "\n"))
	Movable.message:visible(Movable.pressed)
	MESSAGEMAN:Broadcast("MovableUpdated", {button = button})
end

local function charToDeviceButton(ch)
	if not ch then return nil end
	if ch:match("^[a-z0-9]$") then return "DeviceButton_" .. ch end
	local symbolMap = {
		[","] = "DeviceButton_comma",
		["."] = "DeviceButton_period",
		["/"] = "DeviceButton_slash",
		["\\"] = "DeviceButton_backslash",
		["-"] = "DeviceButton_minus",
		["="] = "DeviceButton_equals",
		[";"] = "DeviceButton_semicolon",
		["'"] = "DeviceButton_apostrophe",
		["["] = "DeviceButton_left bracket",
		["]"] = "DeviceButton_right bracket",
		["`"] = "DeviceButton_grave",
		[" "] = "DeviceButton_space",
	}
	return symbolMap[ch]
end

local function normalizeMovableButton(event)
	if not event then return nil end
	local deviceButton = event.DeviceInput and event.DeviceInput.button or nil
	if deviceButton and Movable[deviceButton] then
		return deviceButton
	end

	local shifted = INPUTFILTER:IsBeingPressed("left shift") or INPUTFILTER:IsBeingPressed("right shift")
	if DeviceBtnToChar and deviceButton then
		local asChar = DeviceBtnToChar(deviceButton, shifted)
		local mapped = charToDeviceButton(asChar and asChar:lower() or nil)
		if mapped and Movable[mapped] then
			return mapped
		end
	end

	local logicalButton = event.button
	if type(logicalButton) == "string" then
		local key = logicalButton:match("^Key%s+(.+)$")
		if key then
			local mapped = charToDeviceButton(key:lower())
			if mapped and Movable[mapped] then
				return mapped
			end
		end
	end

	return deviceButton
end

function MovableInput(event)
	if SCREENMAN:GetTopScreen():GetName() == "ScreenGameplaySyncMachine" then return end
	if not allowedCustomization then return false end
	if isCustomizeAutoplayActive() then
		-- this will eat any other mouse input than a right click (toggle)
		-- so we don't have to worry about anything weird happening with the ersatz inputs -mina
		if event.DeviceInput and event.DeviceInput.is_mouse then	
			if event.DeviceInput.button == "DeviceButton_right mouse button" then
				Movable.current = "None"
				Movable.pressed = false
				Movable.message:visible(Movable.pressed)
			end
			return 
		end

		local button = normalizeMovableButton(event)	
		event.hellothisismouse = event.hellothisismouse and true or false -- so that's why bools kept getting set to nil -mina
		local notReleased = not (event.type == "InputEventType_Release")
		-- changed to toggle rather than hold down -mina
		if (Movable[button] and Movable[button].condition and notReleased) or event.hellothisismouse then
			Movable.pressed = not Movable.pressed or event.hellothisismouse	-- this stuff is getting pretty hacky now -mina
			if Movable.current ~= button and not event.hellothisismouse then
				Movable.pressed = true	-- allow toggling using the kb to directly move to a different key rather than forcing an untoggle first -mina
			end
			Movable.current = button
			if not Movable.pressed then 
				Movable.current = "None"
			end
			updatetext(button)	-- this will only update the text when the toggles occur
		end
		
		local current = Movable[Movable.current]

		-- left/right move along the x axis and up/down along the y; set them directly here -mina
		if event.hellothisismouse then
			if event.axis == "x" then
				button = "DeviceButton_left"
			else
				button = "DeviceButton_up"
			end
			Movable.pressed = true	-- we need to do this or the mouse input facsimile will toggle on when moving x, and off when moving y
		end

		if button == "DeviceButton_backspace" then
			event.defaultreset = true
		else
			event.defaultreset = false
		end

		-- reset to default
		if event.defaultreset then
			Movable.pressed = true
			if current ~= nil and current.condition and notReleased and current.external == nil then
				local sizevals = {
					Height = true,
					Width = true,
					Zoom = true,
					Spacing = true,
				}
				local posvals = {
					X = true,
					Y = true,
				}
				local keys = {
					"DeviceButton_left", -- right redundant
					"DeviceButton_up", -- down redundant
				}
				-- run update functions for "all keys"
				for _, b in ipairs(keys) do
					local curKey = current[b]
					if curKey ~= nil then
						local keyProperty = curKey.property
						local prop = current.name .. string.gsub(keyProperty, "Add", "")
						local newVal = 0
						if posvals[keyProperty] then
							newVal = getDefaultGameplayCoordinate(prop)
						elseif sizevals[keyProperty] then
							newVal = getDefaultGameplaySize(prop)
						end
						local diff = newVal - (MovableValues[prop] or 0)
						MovableValues[prop] = newVal
						if curKey.arbitraryFunction then
							if curKey.arbitraryInc then
								-- this definitely breaks for something probably maybe
								-- this is just for visuals anyways
								-- pressing the default button and restarting gameplay fixes it
								curKey.arbitraryFunction(diff)
							else
								curKey.arbitraryFunction(newVal)
							end
						elseif keyProperty == "AddX" or keyProperty == "AddY" then
							if keyProperty == "AddY" then
								diff = -diff -- sigh
							end
							propsFunctions[keyProperty](current.element, diff)
						elseif current.actor then
							propsFunctions[keyProperty](current.actor, newVal)
						elseif current.children then
							for _, attribute in ipairs(current.children) do
								propsFunctions[keyProperty](current.element[attribute], newVal)
							end
						elseif current.elementList then
							for _, elem in ipairs(current.element) do
								propsFunctions[keyProperty](elem, newVal)
							end
						else
							propsFunctions[keyProperty](current.element, newVal)
						end
			
						if not current.noBorder then
							local border = Movable[Movable.current]["Border"]
							if keyProperty == "Height" or keyProperty == "Width" or keyProperty == "Zoom" then
								border:playcommand("Change" .. keyProperty, {val = newVal} )
							end
						end
						updatetext(Movable.current)
						local playerData = playerConfig:get_data(pn_to_profile_slot(PLAYER_1))
						playerData[current.elementTree][keymode] = playerData[current.elementTree][keymode] or {}
						playerData[current.elementTree][keymode][prop] = MovableValues[prop]
						playerConfig:set_dirty(pn_to_profile_slot(PLAYER_1))
					end
				end
				return false
			end
		end
		
		if current and Movable.pressed and current[button] and current.condition and notReleased and current.external == nil then
			local curKey = current[button]
			local keyProperty = curKey.property
			local prop = current.name .. string.gsub(keyProperty, "Add", "")
			local newVal

			-- directly set newval if we're using the mouse -mina
			if event.hellothisismouse then
				if current.mouseRelativeToCenter and keyProperty == "AddX" then
					newVal = event.val - SCREEN_CENTER_X
				elseif current.mouseRelativeToCenter and keyProperty == "AddY" then
					newVal = event.val - SCREEN_CENTER_Y
				elseif keyProperty == "AddX" and current.element and current.element.GetTrueX and current.element.GetX then
					newVal = event.val - (current.element:GetTrueX() - current.element:GetX())
				elseif keyProperty == "AddY" and current.element and current.element.GetTrueY and current.element.GetY then
					newVal = event.val - (current.element:GetTrueY() - current.element:GetY())
				else
					newVal = event.val
				end
			else
				newVal = (MovableValues[prop] or 0) + (curKey.inc * ((curKey.notefieldY and not usingReverse) and -1 or 1))
				if prop == "ErrorBarScale" then
					newVal = math.max(0, newVal)
				end
			end
			
			MovableValues[prop] = newVal
			if curKey.arbitraryFunction then
				if curKey.arbitraryInc then
					curKey.arbitraryFunction(curKey.inc)
				else
					curKey.arbitraryFunction(newVal)
				end
			elseif keyProperty == "AddX" or keyProperty == "AddY" then
				if event.hellothisismouse then
					local axisProp = string.gsub(keyProperty, "Add", "")
					if current.actorUsesAbsolutePosition and current.mouseRelativeToCenter then
						local appliedVal = newVal + (axisProp == "X" and SCREEN_CENTER_X or SCREEN_CENTER_Y)
						propsFunctions[axisProp](current.element, appliedVal)
					else
						propsFunctions[axisProp](current.element, newVal)
					end
				else
					propsFunctions[keyProperty](current.element, curKey.inc)
				end
			elseif current.actor then
				propsFunctions[keyProperty](current.actor, newVal)
			elseif current.children then
				for _, attribute in ipairs(current.children) do
					propsFunctions[curKey.property](current.element[attribute], newVal)
				end
			elseif current.elementList then
				for _, elem in ipairs(current.element) do
					propsFunctions[keyProperty](elem, newVal)
				end
			else
				propsFunctions[keyProperty](current.element, newVal)
			end

			if not current.noBorder then
				local border = Movable[Movable.current]["Border"]
				if keyProperty == "Height" or keyProperty == "Width" or keyProperty == "Zoom" then
					border:playcommand("Change" .. keyProperty, {val = newVal} )
				end
			end

			if not event.hellothisismouse then
				updatetext(Movable.current)	-- updates text when keyboard movements are made (mouse already updated)
			end
			local playerData = playerConfig:get_data(pn_to_profile_slot(PLAYER_1))
			playerData[current.elementTree][keymode] = playerData[current.elementTree][keymode] or {}
			playerData[current.elementTree][keymode][prop] = newVal
			playerConfig:set_dirty(pn_to_profile_slot(PLAYER_1))
			-- commented this to save I/O time and reduce lag
			-- just make sure to call this somewhere else to make sure stuff saves.
			-- (like when the screen changes....)
			--playerConfig:save(pn_to_profile_slot(PLAYER_1))
		end
	end
	return false
end

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
local function elementtobutton(name)
	local aliases = {
		PlayerJudgment = "Judge",
		ComboDisplay = "Combo",
		CenteredScore = "DisplayPercent",
		TextPacemaker = "TargetTracker",
		ProgressBarContainer = "FullProgressBar",
		VerticalLifeBar = "LifeP1",
		TallyAndMetrics = "JudgeCounter",
		NotefieldMean = "DisplayMean",
		NPSCalcContainer = "NPSDisplay",
		NPSGraph = "NPSGraph",
		InGameLeaderboard = "Leaderboard",
		ReplayControls = "ReplayButtons",
		AutofailDisplay = "AutoFailDisplay",
	}
	name = aliases[name] or name
	name = name == "Judgment" and "Judge" or name
	for k,v in pairs(Movable) do
		if type(v) == 'table' and v.name == name and v.properties[1] == "X" then
			return k
		end
	end
end

local function bordermousereact(self)
	self:queuecommand("mousereact")
end

local function getMovableButtonForActor(actor)
	local current = actor
	while current do
		local name = current.GetName and current:GetName() or nil
		local button = name and elementtobutton(name) or nil
		if button and Movable[button] then
			return button
		end
		current = current.GetParent and current:GetParent() or nil
	end
	return nil
end

local function movewhendragged(self)
	local b = getMovableButtonForActor(self)
	if not b or not Movable[b] then
		self:GetParent():diffusealpha(0.1)
		return
	end
	if isOver(self) or (Movable.pressed and Movable.current == b) then
		if Movable.pressed and Movable.current == b then
			self:GetParent():diffusealpha(0.75)	-- this is active
		else
			self:GetParent():diffusealpha(0.35)	-- this has been moused over
		end
		
		-- second half of the expr stops elements from being activated if you mouse over them while moving something else
		if INPUTFILTER:IsBeingPressed("Mouse 0", "Mouse") and (Movable.current == b or Movable.current == "None") then
			local nx = Round(INPUTFILTER:GetMouseX())
			local ny = Round(INPUTFILTER:GetMouseY())
			if Movable[b] and Movable[b].propertyOffsets ~= nil then
				nx = nx - Movable[b].propertyOffsets[1]
				ny = ny - Movable[b].propertyOffsets[2]
			end
			MovableInput({DeviceInput = {button = b}, hellothisismouse = true, axis = "x", val = nx})
			MovableInput({DeviceInput = {button = b}, hellothisismouse = true, axis = "y", val = ny})
		end
	elseif Movable.pressed then 
		self:GetParent():diffusealpha(0.35)		-- something is active, but not this
	else
		self:GetParent():diffusealpha(0.1)		-- nothing is active and this is not moused over
	end
end

-- border function in use -mina
function MovableBorder(width, height, bw, x, y)
	if not allowedCustomization then return end	-- we don't want to be loading all this garbage if we aren't in customization
	return Def.ActorFrame {
		Name = "Border",
		InitCommand=function(self)
			self:xy(x,y):diffusealpha(0)
			self:SetUpdateFunction(bordermousereact)
		end,
		OnCommand=function(self)
			if SCREENMAN:GetTopScreen():GetName() == "ScreenGameplaySyncMachine" then
				self:visible(false)
				self:SetUpdateFunction(nil)
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
			mousereactCommand=function(self)
				movewhendragged(self)	-- this quad owns the mouse movement function -mina
			end
		},
	}
end
