local API_URL = "https://lunar-hub.ru"
local DISCORD  = "https://discord.gg/cz6jG43AFs"
local HttpService = game:GetService("HttpService")
local LP = game:GetService("Players").LocalPlayer

if not Key or Key == "" or Key == "XXXX-XXXX-XXXX-XXXX" then
    LP:Kick("\n\nLunar Hub\n━━━━━━━━━━━━━━━\nKey not specified\n━━━━━━━━━━━━━━━\n" .. DISCORD)
    return
end

local function getHWID()
    local ok2, id2 = pcall(function()
        if not isfile("lhwid.dat") then
            local g = tostring(math.random(1e9,9e9))..tostring(math.random(1e9,9e9))
            writefile("lhwid.dat", g) return g
        end
        return readfile("lhwid.dat")
    end)
    if ok2 and id2 then return id2 end
    return tostring(LP.UserId)
end

local function kick(msg)
    LP:Kick("\n\nLunar Hub\n━━━━━━━━━━━━━━━\n"..msg.."\n━━━━━━━━━━━━━━━\nDiscord: "..DISCORD)
end

hwid = getHWID()
local ok, resp = pcall(function()
    local r = request({ Url=API_URL.."/verify", Method="POST",
        Headers={["Content-Type"]="application/json"},
        Body=HttpService:JSONEncode({key=Key,hwid=hwid}) })
    return HttpService:JSONDecode(r.Body)
end)

if not ok or not resp or not resp.ok then
    local reason = (resp and resp.reason) or "CONNECTION_ERROR"
    local msgs = {
        INVALID_KEY="Invalid key", EXPIRED="Key expired, get new in website",
        HWID_MISMATCH="HWID mismatch, reset in discord.",
        MISSING_FIELDS="Script error", CONNECTION_ERROR="Server error",
    }
    kick(msgs[reason] or reason) return
end

remaining = resp.remaining or 0
key_type  = resp.key_type  or "free"
LunarVerified = true

-- Загружаем игровой скрипт через сервер (токен не нужен)
local GameScripts = {
    [12196278347] = "RC2",
    [6516141723]  = "Doors",
    [6839171747]  = "Doors",
    [537413528]   = "BuildABoat",
}

local scriptName = GameScripts[game.PlaceId] or "Main"
local src = game:HttpGet(API_URL.."/script/"..scriptName.."?key="..Key)
loadstring(src)()
