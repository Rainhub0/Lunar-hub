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
    local r = request({
        Url     = API_URL.."/verify",
        Method  = "POST",
        Headers = {["Content-Type"]="application/json"},
        Body    = HttpService:JSONEncode({key=Key, hwid=hwid})
    })
    return HttpService:JSONDecode(r.Body)
end)

if not ok or not resp or not resp.ok then
    local reason = (resp and resp.reason) or "CONNECTION_ERROR"
    local msgs = {
        INVALID_KEY      = "Invalid key",
        EXPIRED          = "Key expired, get new in website",
        HWID_MISMATCH    = "HWID mismatch, reset in discord.",
        MISSING_FIELDS   = "Script error",
        CONNECTION_ERROR = "Server error",
    }
    kick(msgs[reason] or reason)
    return
end

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Lunar Hub",
    Text  = "✅ Key verified! Loading...",
    Duration = 5,
})

remaining     = resp.remaining or 0
key_type      = resp.key_type  or "free"
LunarVerified = true

local GameScripts = {
    [12196278347] = "RC2",
    [6516141723]  = "Doors",
    [6839171747]  = "Doors",
    [537413528]   = "BuildABoat",
}

local scriptName = GameScripts[game.PlaceId] or "Main"

local src
local ok2, err2 = pcall(function()
    src = game:HttpGet(API_URL.."/script/"..scriptName.."?key="..Key)
end)

if not ok2 then
    kick("HttpGet error: " .. tostring(err2))
    return
end

if not src or src == "" then
    kick("Empty script: " .. scriptName)
    return
end

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Lunar Hub",
    Text  = "Loaded: " .. scriptName .. " (" .. #src .. " chars)",
    Duration = 5,
})

local fn, compErr = loadstring(src)
if not fn then
    -- Находим проблемную строку
    local lineNum = tonumber(tostring(compErr):match(":(%d+):"))
    if lineNum then
        local lines = {}
        for line in src:gmatch("[^\n]+") do
            table.insert(lines, line)
        end
        warn("=== LUNAR HUB COMPILE ERROR ===")
        warn("Строка " .. lineNum .. ": " .. (lines[lineNum] or "не найдена"))
        warn("Предыдущая: " .. (lines[lineNum-1] or "—"))
        warn("Следующая:  " .. (lines[lineNum+1] or "—"))
        warn("================================")
    end
    kick("Compile error: " .. tostring(compErr))
    return
end

local runOk, runErr = pcall(fn)
if not runOk then
    kick("Run error: " .. tostring(runErr))
end
