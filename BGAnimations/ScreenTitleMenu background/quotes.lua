-- Holographic Void: Scrolling Quotes & Tips Display
-- A horizontally scrolling text component for the title screen.

local quotes = {
    "PUSH THE LIMITS. BREAK THE VOID.",
    "BEYOND ACCURACY lies the rhythm of the soul.",
    "HOLOGRAPHIC DREAMS, digital reality.",
    "THE VOID IS NOT EMPTY; it's waiting to be filled with your music.",
    "EVERY GREAT PLAYER was once a beginner who didn't quit.",
    "RHYTHM IS THE HEARTBEAT of the digital world.",
    "FOCUS. PRECISION. EXECUTION.",
    "THE PERFECT SCORE is a journey, not a destination.",
    "SYNCHRONIZE with the rhythm, conquer the machine.",
    "TRANSFORM the sound into movement.",
    "LEVEL UP your skills, transcend the void.",
    "DANCE WITH THE DATA, master the flow.",
    "YOUR ONLY COMPETITION is who you were yesterday.",
    "STAY IN THE FLOW STATE.",
    "THE VORTEX OF SOUND beckons you forward.",
}

local tips = {
    "TIP: Use the backslash key (\\) to pause the jukebox anytime on the title screen.",
    "TIP: Press F3 + P to toggle the profiler and check your FPS.",
    "TIP: You can cycle rates easily in the music wheel using - and = keys.",
    "TIP: Hold Ctrl + 4 on Music Select to jump straight to the search bar.",
    "TIP: Use the Color Config menu to customize your HUD and accent colors.",
    "TIP: The Pacemaker Graph adds an IIDX-like pacemaker graph! (found it somewhere on the Etterna server)",
    "TIP: The MSD and the player stats can be hidden.",
    "TIP: You can search for songs by title, artist, or author.",
    "TIP: Join the Etterna Discord! There are a lot of underrated goats",
    "TIP: Don't forget to set up your online profile for leaderboards and ranking.",
}

local mode = ThemePrefs.Get("HV_QuotesMode")
local selectedText = ""

if mode == "Tips" then
    selectedText = tips[math.random(#tips)]
else
    -- Default to quotes if not tips (assuming Off is handled by visibility)
    selectedText = quotes[math.random(#quotes)]
end

local speed = 100 -- Pixels per second
local accentColor = HVColor.Accent
local subText = color("0.65,0.65,0.65,1")

local t = Def.ActorFrame {
    Name = "QuotesContainer",
    InitCommand = function(self)
        self:SetUpdateFunction(function(af, dt)
            local text = af:GetChild("QuoteText")
            if text then
                local x = text:GetX()
                local width = text:GetZoomedWidth()
                x = x - speed * dt
                
                -- Wrap around when the text is completely off-screen to the left
                if x < -width then
                    x = SCREEN_WIDTH
                end
                text:x(x)
            end
        end)
    end,

    LoadFont("Common Normal") .. {
        Name = "QuoteText",
        InitCommand = function(self)
            self:settext(selectedText)
            self:halign(0):valign(0.5)
            self:zoom(0.4)
            self:diffuse(subText)
            self:x(SCREEN_WIDTH) -- Start off-screen to the right
        end,
        OnCommand = function(self)
            -- Subtle glow if enabled
            if HV.IsGlowEnabled() then
                self:glow(accentColor):diffusealpha(0.8)
            end
        end
    }
}

return t
