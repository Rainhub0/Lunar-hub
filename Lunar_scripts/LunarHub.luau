local Games = {
    [12196278347] = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_scripts/Refirency_Caves_2.luau",
}

local UniversalScript = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_Main"

local currentPlaceId = game.PlaceId

if Games[currentPlaceId] then
    loadstring(game:HttpGet(Games[currentPlaceId]))()
else
    loadstring(game:HttpGet(UniversalScript))()
end