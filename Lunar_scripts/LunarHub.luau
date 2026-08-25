local Key = "2A4728DE-4571D53D-CBDB8471-5C1D027B"
local API_URL = "https://lunar-hub.ru"
local DISCORD  = "https://discord.gg/cz6jG43AFs"

local HttpService = game:GetService("HttpService")
local LP          = game:GetService("Players").LocalPlayer

if not Key or Key == "" or Key == "XXXX-XXXX-XXXX-XXXX" then
    LP:Kick("\n\nLunar Hub\n━━━━━━━━━━━━━━━\nKey not specified\nPaste key/get key in website\n━━━━━━━━━━━━━━━\n" .. DISCORD)
    return
end

local function getHWID()
    local ok2, id2 = pcall(function()
        if not isfile("lhwid.dat") then
            local g = tostring(math.random(1e9, 9e9)) .. tostring(math.random(1e9, 9e9))
            writefile("lhwid.dat", g)
            return g
        end
        return readfile("lhwid.dat")
    end)
    if ok2 and id2 then return id2 end
    return tostring(LP.UserId)
end

local function kick(msg)
    LP:Kick("\n\nLunar Hub\n━━━━━━━━━━━━━━━\n" .. msg .. "\n━━━━━━━━━━━━━━━\nDiscord: " .. DISCORD)
end

hwid      = getHWID()
remaining = 0
key_type  = "free"

local ok, resp = pcall(function()
    local r = request({
        Url    = API_URL .. "/verify",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body   = HttpService:JSONEncode({ key = Key, hwid = hwid })
    })
    return HttpService:JSONDecode(r.Body)
end)

if not ok then
    kick("DEBUG: " .. tostring(resp))
    return
end

if not resp or not resp.ok then
    local reason = (resp and resp.reason) or "CONNECTION_ERROR"
    local msgs = {
        INVALID_KEY      = "Invalid key",
        EXPIRED          = "The key has expired, get new in website",
        HWID_MISMATCH    = "HWID mismatch, reset in discord.",
        MISSING_FIELDS   = "Error, pls wait when delovers fix it",
        CONNECTION_ERROR = "Server error, pls wait when delovers fix it",
    }
    kick(msgs[reason] or reason)
    return
end

remaining = resp.remaining or 0
key_type  = resp.key_type  or "free"
LunarVerified = true

pcall(function()
    writefile("LunarHub_session.dat", HttpService:JSONEncode({
        key       = Key,
        hwid      = hwid,
        key_type  = key_type,
        remaining = remaining,
        saved_at  = os.time()
    }))
end)

local Games = {
    [12196278347]     = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_place_script/RC2.luau?token=GHSAT0AAAAAAED7DTHR3WFJUEB44Y2CIXMS2UNLA6A",
    [6516141723]      = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_place_script/Doors%20Lunar.luau?token=GHSAT0AAAAAAED7DTHRMZTIRCHBBLLLH36O2UNLAVQ",
    [6839171747]      = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_place_script/Doors%20Lunar.luau?token=GHSAT0AAAAAAED7DTHRMZTIRCHBBLLLH36O2UNLAVQ",
    [537413528]       = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_place_script/Build%20A%20Boat%20For%20Treasure%20Lunar.luau?token=GHSAT0AAAAAAED7DTHR3H2UGSK2TSG3KKLQ2UNK77A",
}

local url = Games[game.PlaceId]
if url then
    loadstring(game:HttpGet(url))()
else
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_Main?token=GHSAT0AAAAAAED7DTHRTVAOOX7YLWBENU4U2UNLBDQ"))()
end
