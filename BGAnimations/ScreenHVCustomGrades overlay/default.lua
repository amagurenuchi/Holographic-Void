HV = HV or {}
HV.CustomGrades = HV.CustomGrades or {}
local keys, labels = {}, {}
for i = 1, 16 do keys[i] = string.format("Grade_Tier%02d", i) end
keys[17], keys[18] = "Grade_Failed", "Grade_None"

local saved = nil
local file = RageFileUtil.CreateRageFile()
if file:Open("Save/Holographic Void_settings/CustomGrades.lua", 1) then
	local chunk = loadstring(file:Read())
	if chunk then local ok, data = pcall(chunk); if ok and type(data) == "table" then saved = data end end
	file:Close()
end
file:destroy()
local defaults = {}
do
	local ok, data = pcall(dofile, "Scripts/CustomGrades.lua")
	if ok and type(data) == "table" then defaults = data end
end
if next(defaults) == nil then
	local fallback = {"AAAAA", "AAAA:", "AAAA.", "AAAA", "AAA:", "AAA.", "AAA", "AA:", "AA.", "AA", "A:", "A.", "A", "B", "C", "D"}
	for i, value in ipairs(fallback) do defaults[string.format("Grade_Tier%02d", i)] = value end
	defaults.Grade_Tier17, defaults.Grade_Failed, defaults.Grade_None = "Grade_Tier17", "F", "None"
end
for i, key in ipairs(keys) do
	labels[i] = (saved and saved[key]) or HV.CustomGrades[key] or defaults[key] or ""
	HV.CustomGrades[key] = labels[i]
end
local selected = 1
local startY, spacing = 92, 38

local function refresh(root)
	for i = 1, 18 do
		local row = root:GetChild("GradeRow" .. i)
		if row then row:playcommand("Set") end
		local value = root:GetChild("GradeValue" .. i)
		if value then value:playcommand("Set") end
	end
end

local t = Def.ActorFrame {
	OnCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		refresh(self)
			screen:AddInputCallback(function(event)
				if event.type ~= "InputEventType_FirstPress" then return false end
				local b = event.GameButton or event.button
				if b == "InsertCoin" or event.DeviceInput.button == "DeviceButton_insert" then
					for i, key in ipairs(keys) do
						labels[i] = defaults[key] or ""
						HV.CustomGrades[key] = labels[i]
					end
					if HV.SaveCustomGrades then HV.SaveCustomGrades() end
					refresh(self)
					return true
				end
				if b == "MenuUp" then selected = math.max(1, selected - 1); refresh(self); return true end
			if b == "MenuDown" then selected = math.min(#keys, selected + 1); refresh(self); return true end
			if b == "Start" or event.DeviceInput.button == "DeviceButton_enter" then
				easyInputStringOKCancel("Grade label (5 characters max)", 5, false, function(answer)
					labels[selected] = answer
					HV.CustomGrades[keys[selected]] = answer
					if HV.SaveCustomGrades then HV.SaveCustomGrades() end
					refresh(self)
				end)
				return true
			end
			if b == "Back" or event.DeviceInput.button == "DeviceButton_escape" then screen:Cancel(); return true end
			return false
		end)
	end
}

t[#t + 1] = Def.Quad { InitCommand = function(self) self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,0.9")) end }
t[#t + 1] = LoadFont("Common Large") .. { InitCommand = function(self) self:xy(10, 32):halign(0):valign(1):zoom(.55):diffuse(HVColor.Accent):settext("CUSTOM GRADES") end }
t[#t + 1] = LoadFont("Common Normal") .. { InitCommand = function(self) self:xy(90, startY - 25):halign(0):zoom(.55):diffuse(color("#888888")):settext("Grade") end }
	t[#t + 1] = LoadFont("Common Normal") .. { InitCommand = function(self) self:xy(270, startY - 25):halign(0):zoom(.55):diffuse(color("#888888")):settext("Label") end }
	t[#t + 1] = LoadFont("Common Normal") .. { InitCommand = function(self) self:xy(390, startY - 25):halign(0):zoom(.55):diffuse(color("#888888")):settext("Grade") end }
	t[#t + 1] = LoadFont("Common Normal") .. { InitCommand = function(self) self:xy(570, startY - 25):halign(0):zoom(.55):diffuse(color("#888888")):settext("Label") end }

for i = 1, 18 do
	local column = i <= 9 and 0 or 1
	local row = i <= 9 and i or i - 9
	local x = column == 0 and 90 or 390
	local name = i <= 16 and string.format("Tier %02d", i) or (i == 17 and "Failed" or "None")
	t[#t + 1] = LoadFont("Common Normal") .. {
		Name = "GradeRow" .. i,
		InitCommand = function(self) self:xy(x, startY + (row - 1) * spacing):halign(0):zoom(.65):playcommand("Set") end,
		SetCommand = function(self)
			self:settext(name)
			self:diffuse(i == selected and HVColor.Accent or color("#FFFFFF"))
		end
	}
	t[#t + 1] = LoadFont("Common Normal") .. {
		Name = "GradeValue" .. i,
		InitCommand = function(self) self:xy(x + 180, startY + (row - 1) * spacing):halign(0):zoom(.65):playcommand("Set") end,
		SetCommand = function(self)
			self:settext(labels[i] or "")
			self:diffuse(i == selected and HVColor.Accent or color("#AAAAAA"))
		end
	}
end

t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self) self:xy(60, SCREEN_BOTTOM - 34):halign(0):zoom(.45):diffuse(color("#AAAAAA")):settext("UP/DOWN: select   ENTER: edit   INSERT COIN: reset defaults   BACK: return") end
}
return t
