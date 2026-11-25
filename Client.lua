-- Which game this copy is running in. Daylight UI loads only on WoW Retail
-- (Midnight, game type "standard"). Classic and Forever clients never load it.
-- Client.Retail() is always true while the addon is running; Forever() is kept
-- as a false stub so older call sites stay safe.

local _, DUI = ...

local Client = {}
DUI.Client = Client

-- Midnight 12.1.5 is 120105. The 12.1.7 PTR is 120107.
Client.RETAIL_INTERFACE = 120105

function Client.Forever()
    return false
end

function Client.Retail()
    return true
end

-- The modern client this addon runs on (not Classic).
function Client.Modern()
    return true
end
