if not LunarVerified and not _G.LunarVerified then
    game:GetService("Players").LocalPlayer:Kick("🌙 Lunar Hub\n❌ Запуск без верификации запрещён!")
    return
end
local repo = "https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/"

local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

if not Library then error("Failed to load Linoria!") end

local Options = Library.Options
local Toggles = Library.Toggles

Library.GetIcon       = function() end
Library.GetCustomIcon = function() return nil end

-- Первые строки каждого скрипта на GitHub
if not LunarVerified then
    game:GetService("Players").LocalPlayer:Kick("🌙 Lunar Hub\n❌ Запуск без верификации запрещён!")
    return
end

-- ==================== СЕРВИСЫ ====================
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ==================== КОНФИГ ====================
local Config = {
    Speed  = { Enabled = false, Value = 60 },
    Fly    = { Enabled = false, Value = 80 },
    Spider = { Enabled = false },
    NoClip = { Enabled = false },

    Hitbox = {
        Enabled    = false,
        Mode       = "Legit",
        TargetPart = "HumanoidRootPart",
        LegitSize  = 5,
        RageSize   = 15,
        ShowVisual = true,
    },

    ESP = {
        Master     = true,
        Names      = true,
        ShowDist   = true,
        ShowHP     = true,
        Chams      = false,
        BoxMode    = "None",
        NamesColor = Color3.fromRGB(255, 255, 255),
        ChamsColor = Color3.fromRGB(255,  60,  60),
        BoxColor   = Color3.fromRGB(255, 255,   0),
        Info       = true,    -- групповое управление Name, Dist, HP
    },
}

local KEY_TYPE_LABELS = {
    free     = "🆓 Free",
    premium  = "💎 Premium",
    lifetime = "♾️ Lifetime",
}

local function FormatTime(sec)
    if key_type == "lifetime" then return "♾️ Forever" end
    local d = math.floor(sec / 86400)
    local h = math.floor((sec % 86400) / 3600)
    local m = math.floor((sec % 3600) / 60)
    if d > 0 then return d.."d "..h.."h "..m.."m"
    elseif h > 0 then return h.."h "..m.."m"
    else return m.."m" end
end

local _s = {}
pcall(function()
    _s = game:GetService("HttpService"):JSONDecode(readfile("LunarHub_session.dat"))
end)
Key       = _s.key      or "unknown"
hwid      = _s.hwid     or "unknown"
key_type  = _s.key_type or "free"
remaining = math.max(0, (_s.remaining or 0) - (os.time() - (_s.saved_at or os.time())))
-- ==================== ХЕЛПЕРЫ ====================
local function getChar(player)
    if player and player.Character then return player.Character end
    local wc = Workspace:FindFirstChild("Characters")
    if wc then local c = wc:FindFirstChild(player.Name) if c then return c end end
    local rc = ReplicatedStorage:FindFirstChild("_Characters")
    if rc then local c = rc:FindFirstChild(player.Name) if c then return c end end
end

local function getHRP(player)
    local c = getChar(player)
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
    local c = getChar(player)
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getDist(hrp)
    local myHRP = getHRP(LocalPlayer)
    if not myHRP or not hrp then return 0 end
    return math.floor((hrp.Position - myHRP.Position).Magnitude)
end

local CachedPlayers = {}
local function rebuildCache()
    CachedPlayers = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(CachedPlayers, p) end
    end
end
rebuildCache()
Players.PlayerAdded:Connect(rebuildCache)
Players.PlayerRemoving:Connect(rebuildCache)

-- ==================== СПИДХАК (CFrame) ====================
local speedCFrameConn
local function updateSpeed()
    if speedCFrameConn then speedCFrameConn:Disconnect() speedCFrameConn = nil end
    if not Config.Speed.Enabled then
        local hum = getHumanoid(LocalPlayer)
        if hum then hum.WalkSpeed = 16 end
        return
    end
    speedCFrameConn = RunService.Heartbeat:Connect(function(dt)
        local root = getHRP(LocalPlayer)
        local hum  = getHumanoid(LocalPlayer)
        if not root or not hum then return end
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0 then
            local speed = Config.Speed.Value
            root.CFrame = root.CFrame + (moveDir * speed * dt)
        end
    end)
end

-- ==================== ФЛАЙХАК (CFrame) ====================
local flyConn, flying = nil, false

local function stopFly()
    flying = false
    if flyConn then flyConn:Disconnect() flyConn = nil end
    local hum = getHumanoid(LocalPlayer)
    if hum then hum.PlatformStand = false end
end

local function startFly()
    flying = true
    if flyConn then flyConn:Disconnect() end
    flyConn = RunService.RenderStepped:Connect(function(dt)
        if not Config.Fly.Enabled then stopFly() return end
        local root = getHRP(LocalPlayer)
        local hum  = getHumanoid(LocalPlayer)
        if not root or not hum then return end

        hum.PlatformStand = true
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        local camCF = Camera.CFrame
        local moveVector = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W)           then moveVector = moveVector + camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S)           then moveVector = moveVector - camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A)           then moveVector = moveVector - camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D)           then moveVector = moveVector + camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then moveVector = moveVector + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveVector = moveVector - Vector3.new(0, 1, 0) end

        local speed = Config.Fly.Value
        if moveVector.Magnitude > 0 then
            root.CFrame = CFrame.new(root.Position + (moveVector.Unit * speed * dt), root.Position + camCF.LookVector)
        else
            root.CFrame = CFrame.new(root.Position, root.Position + camCF.LookVector)
        end
    end)
end

local function updateFly()
    if Config.Fly.Enabled then
        if not flying then startFly() end
    else
        stopFly()
    end
end

-- ==================== СПАЙДЕРХАК ====================
local spiderConn
local function updateSpider()
    if spiderConn then spiderConn:Disconnect() spiderConn = nil end
    if not Config.Spider.Enabled then return end
    spiderConn = RunService.Heartbeat:Connect(function()
        if Config.Fly.Enabled then return end
        local char = getChar(LocalPlayer)
        local hum  = getHumanoid(LocalPlayer)
        local root = getHRP(LocalPlayer)
        if not (char and hum and root) then return end
        if hum.MoveDirection.Magnitude > 0 then
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = { char }
            params.FilterType = Enum.RaycastFilterType.Exclude
            local ray = Workspace:Raycast(root.Position, hum.MoveDirection * 2.5, params)
            if ray and math.abs(ray.Normal.Y) < 0.1 then
                root.AssemblyLinearVelocity = Vector3.new(
                    root.AssemblyLinearVelocity.X, 45,
                    root.AssemblyLinearVelocity.Z)
            end
        end
    end)
end

-- ==================== НОКЛИП ====================
local noclipConn
local function updateNoclip()
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if not Config.NoClip.Enabled then
        local char = getChar(LocalPlayer)
        if char then for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
        return
    end
    noclipConn = RunService.Stepped:Connect(function()
        local char = getChar(LocalPlayer)
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
    end)
end

-- ==================== ХИТБОКС ====================
local OriginalSizes = {}

local function ResetAllHitboxes()
    for player, data in pairs(OriginalSizes) do
        local char = getChar(player)
        if char then
            for partName, size in pairs(data) do
                local part = char:FindFirstChild(partName)
                if part then part.Size = size end
            end
        end
    end
    table.clear(OriginalSizes)
end

local function UpdateHitboxExpander()
    if not Config.Hitbox.Enabled then return end
    for _, player in ipairs(CachedPlayers) do
        local char = getChar(player)
        if not char then continue end
        local partName = (Config.Hitbox.Mode == "Rage") and "HumanoidRootPart" or Config.Hitbox.TargetPart
        local part = char:FindFirstChild(partName)
        if not part then continue end
        if not OriginalSizes[player] then OriginalSizes[player] = {} end
        if not OriginalSizes[player][partName] then OriginalSizes[player][partName] = part.Size end
        local newSize = (Config.Hitbox.Mode == "Rage") and Config.Hitbox.RageSize or Config.Hitbox.LegitSize
        part.Size         = Vector3.new(newSize, newSize, newSize)
        part.Transparency = Config.Hitbox.ShowVisual and 0.5 or 1
        part.CanCollide   = false
    end
end

RunService.Heartbeat:Connect(function()
    if Config.Hitbox.Enabled then UpdateHitboxExpander() end
end)

-- ==================== DRAWING ESP ====================

local function newText()
    local t = Drawing.new("Text")
    t.Visible   = false
    t.Center    = true
    t.Outline   = true
    t.OutlineColor = Color3.fromRGB(0,0,0)
    t.Font = 2
    t.Size = 14
    return t
end

local function newLine(color, thickness)
    local l = Drawing.new("Line")
    l.Color     = color or Color3.fromRGB(255,255,255)
    l.Thickness = thickness or 1.5
    l.Visible   = false
    return l
end

local function worldToScreen(pos)
    local sp, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), onScreen, sp.Z
end

local function getScreenBBox(char)
    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyOnScreen = false

    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            local s  = p.Size * 0.5
            local cf = p.CFrame
            for _, lv in ipairs({
                Vector3.new( s.X, s.Y, s.Z), Vector3.new(-s.X, s.Y, s.Z),
                Vector3.new( s.X,-s.Y, s.Z), Vector3.new(-s.X,-s.Y, s.Z),
                Vector3.new( s.X, s.Y,-s.Z), Vector3.new(-s.X, s.Y,-s.Z),
                Vector3.new( s.X,-s.Y,-s.Z), Vector3.new(-s.X,-s.Y,-s.Z),
            }) do
                local wp = cf:PointToWorldSpace(lv)
                local sp2, on = Camera:WorldToViewportPoint(wp)
                if on and sp2.Z > 0 then
                    anyOnScreen = true
                    if sp2.X < minX then minX = sp2.X end
                    if sp2.Y < minY then minY = sp2.Y end
                    if sp2.X > maxX then maxX = sp2.X end
                    if sp2.Y > maxY then maxY = sp2.Y end
                end
            end
        end
    end

    if not anyOnScreen then return nil end
    return minX, minY, maxX, maxY
end

local function makeESPObjects()
    return {
        infoText = newText(),
        boxLines = { newLine(), newLine(), newLine(), newLine() },
        cornLines = (function()
            local t = {}
            for i=1,8 do t[i] = newLine(Color3.fromRGB(255,255,255), 1.8) end
            return t
        end)(),
        box3dLines = (function()
            local t = {}
            for i=1,12 do t[i] = newLine() end
            return t
        end)(),
        corn3dLines = (function()
            local t = {}
            for i=1,24 do t[i] = newLine(Color3.fromRGB(255,255,255),1.8) end
            return t
        end)(),
        chamsHL = nil,
    }
end

local function hideAllDrawings(obj)
    obj.infoText.Visible = false
    for _, l in ipairs(obj.boxLines)    do l.Visible = false end
    for _, l in ipairs(obj.cornLines)   do l.Visible = false end
    for _, l in ipairs(obj.box3dLines)  do l.Visible = false end
    for _, l in ipairs(obj.corn3dLines) do l.Visible = false end
end

local function destroyESPObjects(obj)
    if not obj then return end
    pcall(function() obj.infoText:Remove() end)
    for _, l in ipairs(obj.boxLines)    do pcall(function() l:Remove() end) end
    for _, l in ipairs(obj.cornLines)   do pcall(function() l:Remove() end) end
    for _, l in ipairs(obj.box3dLines)  do pcall(function() l:Remove() end) end
    for _, l in ipairs(obj.corn3dLines) do pcall(function() l:Remove() end) end
    if obj.chamsHL then pcall(function() obj.chamsHL:Destroy() end) obj.chamsHL = nil end
end

local function drawBox2D(lines, x1,y1,x2,y2, color)
    local pts = {
        {Vector2.new(x1,y1), Vector2.new(x2,y1)},
        {Vector2.new(x1,y2), Vector2.new(x2,y2)},
        {Vector2.new(x1,y1), Vector2.new(x1,y2)},
        {Vector2.new(x2,y1), Vector2.new(x2,y2)},
    }
    for i,l in ipairs(lines) do
        l.From    = pts[i][1]
        l.To      = pts[i][2]
        l.Color   = color
        l.Visible = true
    end
end

local function drawCorner2D(lines, x1,y1,x2,y2, color)
    local w = (x2-x1)*0.25
    local h = (y2-y1)*0.25
    local segs = {
        {Vector2.new(x1,y1), Vector2.new(x1+w,y1)},
        {Vector2.new(x1,y1), Vector2.new(x1,y1+h)},
        {Vector2.new(x2,y1), Vector2.new(x2-w,y1)},
        {Vector2.new(x2,y1), Vector2.new(x2,y1+h)},
        {Vector2.new(x1,y2), Vector2.new(x1+w,y2)},
        {Vector2.new(x1,y2), Vector2.new(x1,y2-h)},
        {Vector2.new(x2,y2), Vector2.new(x2-w,y2)},
        {Vector2.new(x2,y2), Vector2.new(x2,y2-h)},
    }
    for i,l in ipairs(lines) do
        l.From    = segs[i][1]
        l.To      = segs[i][2]
        l.Color   = color
        l.Visible = true
    end
end

local function get3DCorners(char)
    local minP = Vector3.new( math.huge, math.huge, math.huge)
    local maxP = Vector3.new(-math.huge,-math.huge,-math.huge)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            local s = p.Size*0.5; local cf = p.CFrame
            for _, lv in ipairs({
                Vector3.new(s.X,s.Y,s.Z),Vector3.new(-s.X,s.Y,s.Z),
                Vector3.new(s.X,-s.Y,s.Z),Vector3.new(-s.X,-s.Y,s.Z),
                Vector3.new(s.X,s.Y,-s.Z),Vector3.new(-s.X,s.Y,-s.Z),
                Vector3.new(s.X,-s.Y,-s.Z),Vector3.new(-s.X,-s.Y,-s.Z),
            }) do
                local wp = cf:PointToWorldSpace(lv)
                minP = Vector3.new(math.min(minP.X,wp.X),math.min(minP.Y,wp.Y),math.min(minP.Z,wp.Z))
                maxP = Vector3.new(math.max(maxP.X,wp.X),math.max(maxP.Y,wp.Y),math.max(maxP.Z,wp.Z))
            end
        end
    end
    return {
        Vector3.new(minP.X,minP.Y,minP.Z), Vector3.new(maxP.X,minP.Y,minP.Z),
        Vector3.new(minP.X,maxP.Y,minP.Z), Vector3.new(maxP.X,maxP.Y,minP.Z),
        Vector3.new(minP.X,minP.Y,maxP.Z), Vector3.new(maxP.X,minP.Y,maxP.Z),
        Vector3.new(minP.X,maxP.Y,maxP.Z), Vector3.new(maxP.X,maxP.Y,maxP.Z),
    }
end

local CUBE_EDGES = {
    {1,2},{3,4},{5,6},{7,8},
    {1,3},{2,4},{5,7},{6,8},
    {1,5},{2,6},{3,7},{4,8},
}
local CORNER_EDGE_PAIRS = {
    {1,2},{2,4},{4,3},{3,1},
    {5,6},{6,8},{8,7},{7,5},
    {1,5},{2,6},{3,7},{4,8},
}

local function drawBox3D(lines, corners, color)
    for i, edge in ipairs(CUBE_EDGES) do
        local a2, aOn = worldToScreen(corners[edge[1]])
        local b2, bOn = worldToScreen(corners[edge[2]])
        local l = lines[i]
        l.Color = color
        if aOn or bOn then
            l.From = a2; l.To = b2; l.Visible = true
        else l.Visible = false end
    end
end

local function drawCorner3D(lines, corners, color)
    local idx = 1
    for _, edge in ipairs(CORNER_EDGE_PAIRS) do
        local a2, aOn = worldToScreen(corners[edge[1]])
        local b2, bOn = worldToScreen(corners[edge[2]])
        local ab = b2 - a2
        local la, lb = lines[idx], lines[idx+1]
        la.Color = color; lb.Color = color
        if aOn or bOn then
            la.From=a2; la.To=a2+ab*0.25; la.Visible=true
            lb.From=b2; lb.To=b2-ab*0.25; lb.Visible=true
        else la.Visible=false; lb.Visible=false end
        idx = idx + 2
    end
end

local function makeChams(char, color)
    local hl = Instance.new("Highlight")
    hl.FillColor           = color
    hl.OutlineColor        = color
    hl.FillTransparency    = 0.45
    hl.OutlineTransparency = 0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee             = char
    hl.Parent              = char
    return hl
end

-- ==================== ESP STORE ====================
local espStore = {}

local function removeFromStore(store, player)
    local obj = store[player]
    if obj then destroyESPObjects(obj) store[player] = nil end
end

local function clearStore(store)
    for p in pairs(store) do removeFromStore(store, p) end
end

-- ==================== ГЛАВНЫЙ UPDATE ESP ====================
local function updateESPForPlayer(player, cfg, store)
    local char = getChar(player)
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")

    local obj = store[player]
    if not char or not hrp then
        if obj then hideAllDrawings(obj) end
        return
    end

    if not obj then
        obj = makeESPObjects()
        store[player] = obj
    end

    hideAllDrawings(obj)

    local bbox = getScreenBBox(char)
    if not bbox then return end

    -- Отрисовка всей инфы в ОДНУ СТРОКУ
    if cfg.Info then
        local head = char:FindFirstChild("Head")
        local topPos = head and (head.Position + Vector3.new(0, head.Size.Y + 0.5, 0)) or (hrp.Position + Vector3.new(0, 3.5, 0))
        local headScreen, headOnScreen = worldToScreen(topPos)
        if headOnScreen then
            local textParts = {}

            if cfg.Names then
                table.insert(textParts, player.Name)
            end

            if cfg.ShowDist then
                table.insert(textParts, string.format("[%d st]", getDist(hrp)))
            end

            if cfg.ShowHP and hum then
                local hp    = math.floor(hum.Health)
                local maxHp = math.max(math.floor(hum.MaxHealth), 1)
                table.insert(textParts, string.format("HP %d/%d", hp, maxHp))
            end

            if #textParts > 0 then
                obj.infoText.Position = Vector2.new(headScreen.X, headScreen.Y - 14)
                obj.infoText.Text     = table.concat(textParts, " | ")
                obj.infoText.Color    = cfg.NamesColor
                obj.infoText.Visible  = true
            end
        end
    end

    -- Боксы
    local boxMode = cfg.BoxMode
    local boxColor = cfg.BoxColor
    local x1, y1, x2, y2 = bbox
    if boxMode == "Box 2D" then
        drawBox2D(obj.boxLines, x1,y1,x2,y2, boxColor)
    elseif boxMode == "Corner 2D" then
        drawCorner2D(obj.cornLines, x1,y1,x2,y2, boxColor)
    elseif boxMode == "Box 3D" then
        local corners = get3DCorners(char)
        drawBox3D(obj.box3dLines, corners, boxColor)
    elseif boxMode == "Corner 3D" then
        local corners = get3DCorners(char)
        drawCorner3D(obj.corn3dLines, corners, boxColor)
    end

    -- Chams
    if cfg.Chams then
        if not obj.chamsHL or not obj.chamsHL.Parent then
            if obj.chamsHL then pcall(function() obj.chamsHL:Destroy() end) end
            obj.chamsHL = makeChams(char, cfg.ChamsColor)
        else
            obj.chamsHL.FillColor    = cfg.ChamsColor
            obj.chamsHL.OutlineColor = cfg.ChamsColor
        end
    else
        if obj.chamsHL then
            pcall(function() obj.chamsHL:Destroy() end)
            obj.chamsHL = nil
        end
    end
end

-- ==================== PLAYERS EVENTS ====================
Players.PlayerRemoving:Connect(function(p)
    removeFromStore(espStore, p)
    rebuildCache()
end)
Players.PlayerAdded:Connect(function(p)
    rebuildCache()
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        removeFromStore(espStore, p)
    end)
end)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            removeFromStore(espStore, p)
        end)
    end
end

-- ==================== RENDER LOOP ====================
RunService.RenderStepped:Connect(function()
    if Config.ESP.Master then
        for _, player in ipairs(CachedPlayers) do
            updateESPForPlayer(player, Config.ESP, espStore)
        end
    else
        for p, obj in pairs(espStore) do
            hideAllDrawings(obj)
            if obj.chamsHL then pcall(function() obj.chamsHL:Destroy() end) obj.chamsHL = nil end
        end
    end
end)

-- ==================== UI ====================
local Window = Library:CreateWindow({
    Title      = "Lunar Hub | Chasing",
    Center     = true,
    AutoShow   = true,
    TabPadding = 5,
})

local Tabs = {
    Main     = Window:AddTab("Main"),
    Visuals  = Window:AddTab("Visuals"),
    Combat   = Window:AddTab("Combat"),
    Settings = Window:AddTab("Settings"),
}

-- ======================== MAIN ========================
local PlayerMod = Tabs.Main:AddLeftGroupbox("Player")

PlayerMod:AddToggle("SpeedHackToggle", {
    Text = "Speed Hack (CFrame)", Default = false,
    Callback = function(v) Config.Speed.Enabled = v updateSpeed() end,
})
PlayerMod:AddSlider("SpeedValueSlider", {
    Text = "Speed Value", Default = 60,
    Min = 10, Max = 300, Rounding = 1,
    Callback = function(v) Config.Speed.Value = v end,
})
PlayerMod:AddToggle("FlyHackToggle", {
    Text = "Fly Hack (CFrame)", Default = false,
    Callback = function(v) Config.Fly.Enabled = v updateFly() end,
})
PlayerMod:AddSlider("FlyValueSlider", {
    Text = "Fly Value", Default = 80,
    Min = 10, Max = 300, Rounding = 1,
    Callback = function(v) Config.Fly.Value = v end,
})
PlayerMod:AddToggle("SpiderHackToggle", {
    Text = "Spider Hack", Default = false,
    Callback = function(v) Config.Spider.Enabled = v updateSpider() end,
})
PlayerMod:AddToggle("NoClipToggle", {
    Text = "No Clip", Default = false,
    Callback = function(v) Config.NoClip.Enabled = v updateNoclip() end,
})

-- ======================== VISUALS ========================
local ESPGroup = Tabs.Visuals:AddLeftGroupbox("ESP")

ESPGroup:AddToggle("ESPMasterToggle", {
    Text = "ESP Master", Default = false,
    Callback = function(v) Config.ESP.Master = v end,
})

local ESPDep = ESPGroup:AddDependencyBox()

ESPDep:AddToggle("ESPInfoToggle", {
    Text = "ESP Info (Name, Dist, HP)", Default = true,
    Callback = function(v) Config.ESP.Info = v end,
})

ESPDep:AddToggle("ESPNamesToggle", {
    Text = "Names", Default = true,
    Callback = function(v) Config.ESP.Names = v end,
}):AddColorPicker("ESPNamesColor", {
    Default = Config.ESP.NamesColor,
    Callback = function(v) Config.ESP.NamesColor = v end,
})

ESPDep:AddToggle("ESPChamsToggle", {
    Text = "Chams", Default = false,
    Callback = function(v) Config.ESP.Chams = v end,
}):AddColorPicker("ESPChamsColor", {
    Default = Config.ESP.ChamsColor,
    Callback = function(v) Config.ESP.ChamsColor = v end,
})

ESPDep:AddDropdown("ESPBoxDropdown", {
    Text    = "Box Type",
    Values  = { "None", "Box 2D", "Corner 2D", "Box 3D", "Corner 3D" },
    Default = "None",
    Callback = function(v) Config.ESP.BoxMode = v end,
})

ESPDep:SetupDependencies({ { Toggles.ESPMasterToggle, true } })

-- ======================== COMBAT ========================
local HitboxGroup = Tabs.Combat:AddLeftGroupbox("Hitbox")

HitboxGroup:AddToggle("HitboxToggle", {
    Text = "Hitbox Expander", Default = false,
    Callback = function(v)
        Config.Hitbox.Enabled = v
        if not v then ResetAllHitboxes() end
    end,
})
HitboxGroup:AddDropdown("HitboxModeDropdown", {
    Text = "Mode", Values = { "Legit", "Rage" }, Default = "Legit",
    Callback = function(v) Config.Hitbox.Mode = v end,
})
HitboxGroup:AddSlider("HitboxLegitSlider", {
    Text = "Legit Size", Default = 5,
    Min = 1, Max = 20, Rounding = 1,
    Callback = function(v) Config.Hitbox.LegitSize = v end,
})
HitboxGroup:AddSlider("HitboxRageSlider", {
    Text = "Rage Size", Default = 15,
    Min = 1, Max = 60, Rounding = 1,
    Callback = function(v) Config.Hitbox.RageSize = v end,
})
HitboxGroup:AddToggle("HitboxVisualToggle", {
    Text = "Show Visual", Default = true,
    Callback = function(v) Config.Hitbox.ShowVisual = v end,
})

-- ======================== SETTINGS ========================
local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")

MenuGroup:AddLabel("Menu Key"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift", NoUI = true, Text = "Menu Keybind",
    Callback = function() Library:Toggle() end,
})
MenuGroup:AddButton("Show Keybinds List", function()
    if Library.KeybindFrame then
        Library.KeybindFrame.Visible = not Library.KeybindFrame.Visible
    end
end)
MenuGroup:AddButton("Unload", function() Library:Unload() end)

KeyBox:AddLabel("Key: " .. (Key or "unknown"))
KeyBox:AddLabel("Type: " .. (KEY_TYPE_LABELS[key_type] or "Unknown"))
KeyBox:AddLabel("HWID: " .. (getHWID() or "unknown"))

local TimeLabel = KeyBox:AddLabel("Time left: " .. FormatTime(remaining or 0))

KeyBox:AddDivider()

if key_type ~= "lifetime" then
    local _startTime = tick()
    task.spawn(function()
        while task.wait(60) do
            local left = math.max(0, (remaining or 0) - (tick() - _startTime))
            TimeLabel:SetText("Time left: " .. FormatTime(left))
        end
    end)
end

task.spawn(function()
    repeat task.wait(0.1) until ThemeManager and SaveManager
        and type(ThemeManager.SetLibrary) == "function"
        and type(SaveManager.SetLibrary)  == "function"
    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    ThemeManager:SetFolder("LunarHub")
    SaveManager:SetFolder("LunarHub_Chasing/configs")
    SaveManager:BuildConfigSection(Tabs.Settings)
    ThemeManager:ApplyToTab(Tabs.Settings)
    pcall(function() SaveManager:LoadAutoloadConfig() end)
end)

local KeyBox = Tabs.Settings:AddRightGroupbox("Key Info")

KeyBox:AddLabel("Key: " .. (Key or "unknown"))
KeyBox:AddLabel("Type: " .. (KEY_TYPE_LABELS[key_type] or "Unknown"))
KeyBox:AddLabel("HWID: " .. (hwid or "unknown"))

local TimeLabel = KeyBox:AddLabel("Time left: " .. FormatTime(remaining or 0))

KeyBox:AddDivider()

if key_type ~= "lifetime" then
    local _startTime = tick()
    task.spawn(function()
        while task.wait(60) do
            local left = math.max(0, (remaining or 0) - (tick() - _startTime))
            TimeLabel:SetText("Time left: " .. FormatTime(left))
        end
    end)
end

-- ==================== ВЫГРУЗКА ====================
Library:OnUnload(function()
    Config.Speed.Enabled = false
    if speedCFrameConn then speedCFrameConn:Disconnect() end
    local hum = getHumanoid(LocalPlayer)
    if hum then hum.WalkSpeed = 16 end

    Config.Fly.Enabled = false; stopFly()

    Config.Spider.Enabled = false
    if spiderConn then spiderConn:Disconnect() end

    Config.NoClip.Enabled = false
    if noclipConn then noclipConn:Disconnect() end
    local char = getChar(LocalPlayer)
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end

    Config.Hitbox.Enabled = false
    ResetAllHitboxes()

    Config.ESP.Master = false
    clearStore(espStore)
end)