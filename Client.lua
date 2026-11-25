-- Which game this copy is running in. WoW Retail (Midnight, game type
-- "standard") and WoW: Forever (game type "forever" / "camelot") share the
-- mainline UI, including secret values and the C_* APIs. They are not the
-- same game: Forever is classic content with its own systems, and Retail's
-- second name from UnitFullName is a realm, not a surname.
--
-- Read on each call. A test sets the globals before the files load, and the
-- real client has them from the start.

local _, DUI = ...

local Client = {}
DUI.Client = Client

-- Midnight 12.1.5 is 120105. The 12.1.7 PTR is 120107. Forever is 16001.
Client.RETAIL_INTERFACE = 120105
Client.FOREVER_INTERFACE = 16001

local function interfaceVersion()
    if type(GetBuildInfo) ~= "function" then return nil end
    local _, _, _, version = GetBuildInfo()
    return tonumber(version)
end

local function projectId()
    local id = _G.WOW_PROJECT_ID
    if type(id) ~= "number" then return nil end
    return id
end

-- Forever, including early builds that still reported the retail project id
-- while their interface number was 16001. With nothing set (the test client),
-- this is Forever: that is the client the suite stands in for.
function Client.Forever()
    local version = interfaceVersion()
    if version and version >= 16000 and version < 20000 then return true end
    local id = projectId()
    if id ~= nil and id == (_G.WOW_PROJECT_CAMELOT or 18) then return true end
    if id == nil and version == nil then return true end
    return false
end

-- WoW Retail on the Midnight client. Classic clients are neither.
function Client.Retail()
    if Client.Forever() then return false end
    local id = projectId()
    if id ~= nil and id == (_G.WOW_PROJECT_MAINLINE or 1) then return true end
    local version = interfaceVersion()
    return version ~= nil and version >= 100000 and version < 16000
end

-- Retail or Forever: the modern client, not a Classic era client.
function Client.Modern()
    return Client.Retail() or Client.Forever()
end
