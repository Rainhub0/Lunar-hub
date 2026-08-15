local Games = {
    [12196278347] = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_scripts/Refirency_Caves_2.luau",
    [126331002216562] = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_scripts/Chasing%20lunar.luau",
    [6516141723] = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_scripts/Doors%20Lunar.luau",
    [537413528] = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_scripts/Build%20A%20Boat%20For%20Treasure%20Lunar.luau",
}

local UniversalScript = "https://raw.githubusercontent.com/Rainhub0/Lunar-hub/refs/heads/main/Lunar_Main"

local currentPlaceId = game.PlaceId

if Games[currentPlaceId] then
    loadstring(game:HttpGet(Games[currentPlaceId]))()
else
    loadstring(game:HttpGet(UniversalScript))()
end
