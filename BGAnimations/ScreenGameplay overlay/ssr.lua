-- Holographic Void: real-time chart SSR display

local pn = GAMESTATE:GetEnabledPlayers()[1]
local accentColor = HVColor.Accent or color("#00CFFF")
local ssrTextActor
local lastWifeScore
local currentSSR = 0

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

local x = (MovableValues and MovableValues.NPSDisplayX) or getDefaultGameplayCoordinate("NPSDisplayX") or 10
local y = (MovableValues and MovableValues.NPSDisplayY) or getDefaultGameplayCoordinate("NPSDisplayY") or (SCREEN_CENTER_Y + 95)
local zoom = (MovableValues and MovableValues.NPSDisplayZoom) or getDefaultGameplaySize("NPSDisplayZoom") or 0.65

return Def.ActorFrame {
	Name = "SSRDisplay",
	InitCommand = function(self)
		self:xy(x, y - 20):zoom(zoom):SetUpdateFunction(function()
			local ssr = updateSSR()
			if ssrTextActor then
				ssrTextActor:settextf("%0.2f", ssr):diffuse(HVColor.GetMSDRatingColor(ssr))
			end
		end)
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
