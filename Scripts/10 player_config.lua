local defaultGameplayCoordinates = {
	JudgeX = 0,
	JudgeY = 0,
	ComboX = 0,
	ComboY = -55,
	ErrorBarX = SCREEN_CENTER_X,
	ErrorBarY = SCREEN_CENTER_Y + SCREEN_HEIGHT * 0.15 - 40,
	TargetTrackerX = SCREEN_CENTER_X,
	TargetTrackerY = SCREEN_CENTER_Y - 115,
	FullProgressBarX = SCREEN_CENTER_X,
	FullProgressBarY = 12,
	JudgeCounterX = SCREEN_CENTER_X + 160,
	JudgeCounterY = SCREEN_HEIGHT - 176,
	DisplayPercentX = SCREEN_CENTER_X,
	DisplayPercentY = SCREEN_CENTER_Y - 90,
	DisplayMeanX = SCREEN_CENTER_X,
	DisplayMeanY = SCREEN_CENTER_Y + 70,
	NPSDisplayX = 10,
	NPSDisplayY = SCREEN_CENTER_Y + 95,
	NPSGraphX = 10,
	NPSGraphY = SCREEN_CENTER_Y + 100,
	ProgressBarPos = 1,
	LeaderboardX = 10,
	LeaderboardY = 40,
	ReplayButtonsX = SCREEN_RIGHT - 40,
	ReplayButtonsY = SCREEN_CENTER_Y + 50,
	LifeP1X = 178,
	LifeP1Y = 10,
	LifeP1Rotation = 0,
	PracticeCDGraphX = 10,
	PracticeCDGraphY = 85,
	BPMTextX = SCREEN_CENTER_X,
	BPMTextY = SCREEN_BOTTOM - 20,
	RecentJudgmentDisplayX = -160,
	RecentJudgmentDisplayY = 50,
	DPDisplayX = 60,
	DPDisplayY = -12,
	AutoFailDisplayX = 10,
	AutoFailDisplayY = SCREEN_CENTER_Y + 40,
	NotefieldX = 0,
	NotefieldY = 0
}

local defaultGameplaySizes = {
	JudgeZoom = 1.0,
	ComboZoom = 1.0,
	TargetTrackerZoom = 1.0,
	DisplayPercentZoom = 1,
	DisplayMeanZoom = 1,
	NPSDisplayZoom = 0.65,
	NPSGraphWidth = 1.0,
	NPSGraphHeight = 1.0,
	LeaderboardWidth = 1.0,
	LeaderboardHeight = 1.0,
	RecentJudgmentDisplayZoom = 1.0,
	DPDisplayZoom = 1.0,
	BPMTextZoom = 1.0,
	AutoFailDisplayZoom = 1.0,
	NotefieldWidth = 1.0,
	NotefieldHeight = 1.0,
	NotefieldSpacing = 0.0,
	ErrorBarScale = 1.0
}

local defaultConfig = {
	ScreenFilter = 1,
	JudgeType = 1,
	AvgScoreType = 0,
	GhostScoreType = 1,
	DisplayPercent = true,
	DisplayMean = false,
	TargetTracker = true,
	TargetGoal = 93,
	TargetTrackerMode = 0, -- 0: set percent, 1: pb, 2: pb (replay)
	JudgeCounter = true,
	ErrorBar = 1,
	leaderboardEnabled = false,
	PlayerInfo = true,
	FullProgressBar = true,
	MiniProgressBar = true,
	LaneCover = 0, -- soon to be changed to: 0=off, 1=sudden, 2=hidden
	LaneCoverHeight = 10,
	NPSDisplay = true,
	NPSGraph = false,
	CBHighlight = false,
	OneShotMirror = false,
	JudgmentText = true,
	ComboText = true,
	ReceptorSize = 100,
	ErrorBarCount = 30,
	BackgroundType = 1,
	UserName = "",
	PasswordToken = "",
	CustomizeGameplay = false,
	CustomEvaluationWindowTimings = false,
	PracticeMode = false,
	GameplayXYCoordinates = {
		["3K"] = DeepCopy(defaultGameplayCoordinates),
		["4K"] = DeepCopy(defaultGameplayCoordinates),
		["5K"] = DeepCopy(defaultGameplayCoordinates),
		["6K"] = DeepCopy(defaultGameplayCoordinates),
		["7K"] = DeepCopy(defaultGameplayCoordinates),
		["8K"] = DeepCopy(defaultGameplayCoordinates),
		["9K"] = DeepCopy(defaultGameplayCoordinates),
		["10K"] = DeepCopy(defaultGameplayCoordinates),
		["12K"] = DeepCopy(defaultGameplayCoordinates),
		["16K"] = DeepCopy(defaultGameplayCoordinates)
	},
	GameplaySizes = {
		["3K"] = DeepCopy(defaultGameplaySizes),
		["4K"] = DeepCopy(defaultGameplaySizes),
		["5K"] = DeepCopy(defaultGameplaySizes),
		["6K"] = DeepCopy(defaultGameplaySizes),
		["7K"] = DeepCopy(defaultGameplaySizes),
		["8K"] = DeepCopy(defaultGameplaySizes),
		["9K"] = DeepCopy(defaultGameplaySizes),
		["10K"] = DeepCopy(defaultGameplaySizes),
		["12K"] = DeepCopy(defaultGameplaySizes),
		["16K"] = DeepCopy(defaultGameplaySizes)
	}
}

function getDefaultGameplaySize(obj)
	return defaultGameplaySizes[obj]
end

function getDefaultGameplayCoordinate(obj)
	return defaultGameplayCoordinates[obj]
end

-- create the playerConfig global
playerConfig = create_setting("playerConfig", "playerConfig.lua", defaultConfig, -1)

-- shadow settings_mt.load to do several things:
--	load missing values from default
--	load missing values for the current keymode from the 4k config
--	load missing values for the current slot from the global slot
local tmp2 = playerConfig.load
playerConfig.load = function(self, slot)
	-- redefinition of force_table_elements_to_match_type to let settings_system
	-- completely ignore the format of the table if it changed dramatically between versions
	-- this lets us introduce backwards/forwards compatibility
	local tmp = force_table_elements_to_match_type
	force_table_elements_to_match_type = function()
	end

	local x = create_setting("playerConfig", "playerConfig.lua", {}, -1)
	x = x:load(slot)
	local coords = x.GameplayXYCoordinates
	local sizes = x.GameplaySizes
	if sizes and not sizes["4K"] then
		defaultConfig.GameplaySizes["3K"] = sizes
		defaultConfig.GameplaySizes["4K"] = sizes
		defaultConfig.GameplaySizes["5K"] = sizes
		defaultConfig.GameplaySizes["6K"] = sizes
		defaultConfig.GameplaySizes["7K"] = sizes
		defaultConfig.GameplaySizes["8K"] = sizes
		defaultConfig.GameplaySizes["9K"] = sizes
		defaultConfig.GameplaySizes["10K"] = sizes
		defaultConfig.GameplaySizes["12K"] = sizes
		defaultConfig.GameplaySizes["16K"] = sizes

	end
	if coords and not coords["4K"] then
		defaultConfig.GameplayXYCoordinates["3K"] = coords
		defaultConfig.GameplayXYCoordinates["4K"] = coords
		defaultConfig.GameplayXYCoordinates["5K"] = coords
		defaultConfig.GameplayXYCoordinates["6K"] = coords
		defaultConfig.GameplayXYCoordinates["7K"] = coords
		defaultConfig.GameplayXYCoordinates["8K"] = coords
		defaultConfig.GameplayXYCoordinates["9K"] = coords
		defaultConfig.GameplayXYCoordinates["10K"] = coords
		defaultConfig.GameplayXYCoordinates["12K"] = coords
		defaultConfig.GameplayXYCoordinates["16K"] = coords
	end
	force_table_elements_to_match_type = tmp
	local loaded = tmp2(self, slot)
	-- Customization is an editing mode, not a gameplay preference.  Keep the
	-- saved layout, but always require it to be enabled again after a reboot.
	if loaded then
		loaded.CustomizeGameplay = false
	end
	return loaded
end
playerConfig:load()

-- Persist in-place edits consistently, including changes made by option rows.
function SavePlayerConfig(slot)
	if not slot then return end
	playerConfig:set_dirty(slot)
	playerConfig:save(slot)
end

function LoadProfileCustom(profile, dir)
	local players = GAMESTATE:GetEnabledPlayers()
	local playerProfile
	local pn
	for k, v in pairs(players) do
		playerProfile = PROFILEMAN:GetProfile(v)
		if playerProfile:GetGUID() == profile:GetGUID() then
			pn = v
		end
	end

	if pn then
		local conf = playerConfig:load(pn_to_profile_slot(pn))
	end
end

function SaveProfileCustom(profile, dir)
	local players = GAMESTATE:GetEnabledPlayers()
	local playerProfile
	local pn
	for k, v in pairs(players) do
		playerProfile = PROFILEMAN:GetProfile(v)
		if playerProfile:GetGUID() == profile:GetGUID() then
			pn = v
		end
	end

	if pn then
		SavePlayerConfig(pn_to_profile_slot(pn))
	end
end
