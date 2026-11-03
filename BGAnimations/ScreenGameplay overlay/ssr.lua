-- Holographic Void: real-time chart SSR display

local pn = GAMESTATE:GetEnabledPlayers()[1]
local accentColor = HVColor.Accent or color("#00CFFF")
local ssrTextActor
local lastWifeScore
local currentSSR = 0
local ssrPollInterval = 0.2

local function updateSSR()
	local steps = GAMESTATE:GetCurrentSteps(pn)
	local stageStats = STATSMAN:GetCurStageStats()
	local pss = stageStats and stageStats:GetPlayerStageStats(pn)
	if not steps or not pss or type(steps.GetSSRs) ~= "function" or type(pss.GetWifeScore) ~= "function" then
		return 0
	end

	local wifeScore = tonumber(pss:GetWifeScore()) or 0
	if wifeScore ~= lastWifeScore then
		lastWifeScore = wifeScore
		local ok, ssrs = pcall(steps.GetSSRs, steps, getCurRateValue(), wifeScore)
		currentSSR = ok and type(ssrs) == "table" and (tonumber(ssrs[1]) or 0) or 0
	end
	return currentSSR
end

local x = (MovableValues and MovableValues.SSRDisplayX) or getDefaultGameplayCoordinate("SSRDisplayX") or 10
local y = (MovableValues and MovableValues.SSRDisplayY) or getDefaultGameplayCoordinate("SSRDisplayY") or (SCREEN_CENTER_Y + 75)
local zoom = (MovableValues and MovableValues.SSRDisplayZoom) or getDefaultGameplaySize("SSRDisplayZoom") or 0.65

return Def.ActorFrame {
	Name = "SSRDisplay",
	InitCommand = function(self)
		local elapsed = ssrPollInterval
		self:xy(x, y):zoom(zoom):SetUpdateFunction(function(_, delta)
			elapsed = elapsed + (delta or 0)
			if elapsed < ssrPollInterval then return end
			elapsed = 0
			local ssr = updateSSR()
			if ssrTextActor then
				ssrTextActor:settextf("%0.2f", ssr):diffuse(HVColor.GetMSDRatingColor(ssr))
			end
		end)
	end,
	OnCommand = function(self)
		setMovableActor({"DeviceButton_j", "DeviceButton_k"}, self, self:GetChild("Border"))
	end,
	LoadFont("MSD 20px") .. {
		Name = "Text",
		InitCommand = function(self)
			self:halign(0):valign(1):diffuse(accentColor):settext("0.00")
			ssrTextActor = self
		end
	},
	MovableBorder(70, 18, 1, 35, -9)
}
