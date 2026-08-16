local API_URL = "https://lunarhub.loca.lt"
local DISCORD  = "https://discord.gg/cz6jG43AFs"

local HttpService = game:GetService("HttpService")
local LP          = game:GetService("Players").LocalPlayer

-- Проверяем что ключ передан
if not Key or Key == "" or Key == "XXXX-XXXX-XXXX-XXXX" then
    LP:Kick("\n\n🌙 Lunar Hub\n━━━━━━━━━━━━━━━\n❌ Ключ не указан!\nПолучи ключ в Discord.\n━━━━━━━━━━━━━━━\n" .. DISCORD)
    return
end

-- Получаем HWID
local function getHWID()
    local ok, id = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and id and id ~= "" then return id end

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
    LP:Kick("\n\n🌙 Lunar Hub\n━━━━━━━━━━━━━━━\n" .. msg .. "\n━━━━━━━━━━━━━━━\nDiscord: " .. DISCORD)
end

-- Глобальные переменные
hwid      = getHWID()
remaining = 0
key_type  = "free"

-- Верификация ключа на сервере
local ok, resp = pcall(function()
    local r = HttpService:RequestAsync({
        Url    = API_URL .. "/verify",
        Method = "POST",
        Headers = {
            ["Content-Type"]           = "application/json",
            ["bypass-tunnel-reminder"] = "true",
            ["User-Agent"]             = "LunarHub/1.0",
        },
        Body = HttpService:JSONEncode({ key = Key, hwid = hwid })
    })
    return HttpService:JSONDecode(r.Body)
end)

if not ok or not resp or not resp.ok then
    local reason = (resp and resp.reason) or "CONNECTION_ERROR"
    local msgs = {
        INVALID_KEY      = "❌ Ключ недействителен или удалён.",
        EXPIRED          = "⏰ Ключ истёк. Получи новый в Discord.",
        HWID_MISMATCH    = "💻 HWID не совпадает. Напиши в Discord для сброса.",
        MISSING_FIELDS   = "⚠️ Ошибка скрипта.",
        CONNECTION_ERROR = "🌐 Не удалось подключиться к серверу.",
    }
    kick(msgs[reason] or reason)
    return
end

-- Сохраняем данные глобально
remaining = resp.remaining or 0
key_type  = resp.key_type  or "free"

-- Сохраняем сессию на диск
pcall(function()
    writefile("LunarHub_session.dat", HttpService:JSONEncode({
        key       = Key,
        hwid      = hwid,
        key_type  = key_type,
        remaining = remaining,
        saved_at  = os.time()
    }))
end)

-- Загружаем игровой скрипт по PlaceId
local Games = {
    [12196278347]     = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_scripts/Refirency_Caves_2.luau",
    [126331002216562] = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_scripts/Chasing%20lunar.luau",
    [6516141723]      = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_scripts/Doors%20Lunar.luau",
    [6839171747]      = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_scripts/Doors%20Lunar.luau",
    [537413528]       = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_scripts/Build%20A%20Boat%20For%20Treasure%20Lunar.luau",
}

local url = Games[game.PlaceId]
if url then
    loadstring(game:HttpGet(url))()
else
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_Main"))()
end
