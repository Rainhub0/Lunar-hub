-- ==================== ANTI-AFK ====================
local VirtualUser = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ==================== БИБЛИОТЕКИ ====================
local repo = "https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/"
local function loadLib(path)
    local ok, r = pcall(function()
        return loadstring(game:HttpGet(repo .. path))()
    end)
    if not ok then
        warn("[LibError] " .. path .. " → " .. tostring(r))
    end
    return ok and r or nil
end

local Library      = loadLib("Library.lua")
local ThemeManager = loadLib("addons/ThemeManager.lua")
local SaveManager  = loadLib("addons/SaveManager.lua")

if not Library then
    error("Failed to load Linoria!")
end

local Options = Library.Options
local Toggles = Library.Toggles
Library.GetIcon = function() end
Library.GetCustomIcon = function() return nil end

-- ==================== СЕРВИСЫ ====================
local UIS   = game:GetService("UserInputService")
local RS    = game:GetService("RunService")
local WS    = game:GetService("Workspace")
local RepS  = game:GetService("ReplicatedStorage")
local Plrs  = game:GetService("Players")

local LP     = Plrs.LocalPlayer
local Cam    = WS.CurrentCamera
local SafeGui = (gethui and gethui()) or game:GetService("CoreGui")

-- ==================== SACK TIER ====================
local SackMap = { [0] = 5, [1] = 10, [2] = 15, [3] = 20 }

local function GetSackTier()
    local t = LP:GetAttribute("SackTier")
    if type(t) == "number" then return t end
    return 0
end

local function GetSackSize()
    return SackMap[GetSackTier()] or 5
end

local function GetSackCount()
    local char = LP.Character
    if not char then return 0 end
    local sack = nil
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("sack") then
            sack = t
            break
        end
    end
    if not sack then
        local bag = char:FindFirstChild("Item Bag")
        if bag and bag:IsA("Tool") then sack = bag end
    end
    if not sack then return 0 end
    local count = sack:GetAttribute("Stored")
    if type(count) == "number" then return count end
    local items = sack:FindFirstChild("Items")
    if items then return #items:GetChildren() end
    local inv = sack:FindFirstChild("Inventory")
    if inv then
        local cnt = 0
        for _ in inv:GetChildren() do cnt = cnt + 1 end
        return cnt
    end
    return 0
end

local function IsSackFull()
    return GetSackCount() >= GetSackSize()
end

-- ==================== КОНФИГ ====================
local Cfg = {
    -- fishing
    CastDelay    = 0.015,
    WaitBite     = 4,
    HitCount     = 10,
    HitInterval  = 0.05,
    ResetDelay   = 0.1,
    PerfectCatch = true,

    -- esp world
    MaxDist      = 1000,
    SearchFilter = "",
    SelectedItems  = {},
    SelectedOres   = {},
    SelectedTrees  = {},
    ItemColor   = Color3.fromRGB(255, 255, 255),
    OreColor    = Color3.fromRGB(255, 170, 0),
    TreeColor   = Color3.fromRGB(0, 255, 127),
    FishColor   = Color3.fromRGB(0, 200, 255),

    -- esp players
    PlayerColor = Color3.fromRGB(255, 80, 80),

    -- bag
    BagDelay     = 0.3,
    PickupRadius = 15,

    -- movement
    SpeedWalk = false,
    SpeedVal  = 50,
    InfJump   = false,
    NoClip    = false,
    Fly       = false,
    FlySpeed  = 80,

    -- farm
    FarmSelected   = {},
    CollectSelected = {},
    FarmRange      = 15,
    FarmHits       = 3,
    FarmHitDelay   = 0.08,
    FarmLoopDelay  = 0.15,
    FishHitbox = {
        Enabled     = false,
        Size        = Vector3.new(25, 25, 25),
        Transparency = 0.7,
        Orig        = {},
    },

    -- waypoints (сохраняются вручную)
    Waypoints = {},

    -- collect teleport
    CollectFromPos     = nil,   -- CFrame "откуда" (плот)
    CollectToPos       = nil,   -- CFrame "куда" (саркофаг и т.п.)
    UseCustomTPCollect = false,
}

-- ==================== СИСТЕМА СОХРАНЕНИЯ КАСТОМНЫХ ДАННЫХ ====================
-- Сохраняем waypoints + collect positions в отдельный файл через writefile/readfile
local SAVE_FILE = "LunarHub_CustomData.json"

local function CFrameToTable(cf)
    if not cf then return nil end
    local x,y,z = cf.X, cf.Y, cf.Z
    local r00,r01,r02,
          r10,r11,r12,
          r20,r21,r22 = cf:components()
    return {x,y,z, r00,r01,r02, r10,r11,r12, r20,r21,r22}
end

local function TableToCFrame(t)
    if not t or type(t) ~= "table" then return nil end
    return CFrame.new(t[1],t[2],t[3], t[4],t[5],t[6], t[7],t[8],t[9], t[10],t[11],t[12])
end

local function SaveCustomData()
    local data = {
        Waypoints = {},
        CollectFromPos = CFrameToTable(Cfg.CollectFromPos),
        CollectToPos   = CFrameToTable(Cfg.CollectToPos),
    }
    for name, cf in pairs(Cfg.Waypoints) do
        data.Waypoints[name] = CFrameToTable(cf)
    end
    local ok, err = pcall(function()
        writefile(SAVE_FILE, game:GetService("HttpService"):JSONEncode(data))
    end)
    if not ok then
        warn("[LunarHub] Ошибка сохранения: " .. tostring(err))
    end
end

local function LoadCustomData()
    local ok, raw = pcall(function()
        return readfile(SAVE_FILE)
    end)
    if not ok or not raw or raw == "" then return end

    local ok2, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(raw)
    end)
    if not ok2 or not data then return end

    if type(data.Waypoints) == "table" then
        Cfg.Waypoints = {}
        for name, t in pairs(data.Waypoints) do
            local cf = TableToCFrame(t)
            if cf then Cfg.Waypoints[name] = cf end
        end
    end

    if data.CollectFromPos then
        Cfg.CollectFromPos = TableToCFrame(data.CollectFromPos)
    end
    if data.CollectToPos then
        Cfg.CollectToPos = TableToCFrame(data.CollectToPos)
    end
end

-- Загружаем при старте
LoadCustomData()

-- ==================== PERFECT CATCH ====================
task.spawn(function()
    local AEv
    repeat
        local ev = RepS:FindFirstChild("Events")
        AEv = ev and ev:FindFirstChild("Tools") and ev.Tools:FindFirstChild("Attack")
        task.wait(0.1)
    until AEv

    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        if self == AEv and getnamecallmethod() == "FireServer" and Cfg.PerfectCatch then
            local a = { ... }
            if type(a[1]) == "table" then
                a[1].Alpha = 0.995 + math.random() * 0.004
                a[1].ResponseTime = 0.955 + math.random() * 0.005
            end
            return old(self, table.unpack(a))
        end
        return old(self, ...)
    end)

    setreadonly(mt, true)
    print("[PerfectCatch] ready")
end)

-- ==================== УТИЛИТЫ ====================
local function isDeco(name)
    local n = name:lower()
    return n:find("decorat", 1, true) or n:find("_decoration", 1, true)
end

local function GetPart(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    end
end

local function TPTo(cf)
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if r then r.CFrame = cf end
end

local function GetMyRoot()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetMyHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ==================== СОБЫТИЯ ИГРЫ ====================
local EvFolder  = RepS:WaitForChild("Events", 10)
local ToolsEv   = EvFolder and EvFolder:FindFirstChild("Tools")
local FishEv    = EvFolder and EvFolder:FindFirstChild("Fish")
local ChargeEv  = ToolsEv and ToolsEv:FindFirstChild("Charge")
local AttackEv  = ToolsEv and ToolsEv:FindFirstChild("Attack")
local HitEv     = FishEv  and FishEv:FindFirstChild("ReelSessionHit")
local EndEv     = FishEv  and FishEv:FindFirstChild("ReelSessionEnd")

-- ==================== HIGHLIGHT POOL ====================
local MAX_HL = 30
local HLPool = {}

for i = 1, MAX_HL do
    local h = Instance.new("Highlight")
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.FillTransparency = 0.5
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Enabled = false
    pcall(function() h.Parent = SafeGui end)
    HLPool[i] = h
end

-- ==================== ESP МИР ====================
local worldESP = {}

local function MakeWorldESPEntry(obj, cat, color)
    if worldESP[obj] or isDeco(obj.Name) then return end
    local ad = GetPart(obj) or obj
    local t = Drawing.new("Text")
    t.Visible = false
    t.Center = true
    t.Outline = true
    t.Size = 13
    t.Font = 2
    t.Color = color
    worldESP[obj] = { Text = t, Obj = obj, Cat = cat, Name = obj.Name, Ad = ad }
    obj.Destroying:Connect(function()
        local e = worldESP[obj]
        if e then
            pcall(function() e.Text:Remove() end)
            worldESP[obj] = nil
        end
    end)
end

local function RemWorldESP(obj)
    local e = worldESP[obj]
    if e then
        pcall(function() e.Text:Remove() end)
        worldESP[obj] = nil
    end
end

local function UpdateWorldESP()
    local root = GetMyRoot()
    local myPos = root and root.Position
    local mds = Cfg.MaxDist * Cfg.MaxDist
    local sf = Cfg.SearchFilter
    local cands = {}

    for obj, e in pairs(worldESP) do
        if not obj or not obj.Parent then
            RemWorldESP(obj)
            continue
        end
        local cat = e.Cat
        local en = false
        local col
        local useDD = false
        local sel = {}

        if cat == "Grab" and Toggles.ItemESP and Toggles.ItemESP.Value then
            en = true; col = Cfg.ItemColor; useDD = true; sel = Cfg.SelectedItems
        elseif cat == "Ores" and Toggles.OreESP and Toggles.OreESP.Value then
            en = true; col = Cfg.OreColor; useDD = true; sel = Cfg.SelectedOres
        elseif cat == "Trees" and Toggles.TreeESP and Toggles.TreeESP.Value then
            en = true; col = Cfg.TreeColor; useDD = true; sel = Cfg.SelectedTrees
        elseif cat == "BigFish" and Toggles.FishESP and Toggles.FishESP.Value then
            en = true; col = Cfg.FishColor
        end

        local isSel = true
        if useDD then
            local md = (sel[e.Name] == true)
            local mt2 = (sf ~= "") and (e.Name:lower():find(sf, 1, true) ~= nil)
            isSel = md or mt2
        end

        if not en or not isSel then
            if e.Text.Visible then e.Text.Visible = false end
            continue
        end

        local ad = e.Ad
        if not ad or not ad.Parent then
            if e.Text.Visible then e.Text.Visible = false end
            continue
        end

        local dsq = myPos and (myPos - ad.Position).Magnitude ^ 2 or math.huge
        if dsq > mds then
            if e.Text.Visible then e.Text.Visible = false end
            continue
        end

        if e.Text.Color ~= col then e.Text.Color = col end

        local sp, on = Cam:WorldToViewportPoint(ad.Position)
        if on then
            local d = myPos and math.floor(math.sqrt(dsq)) or 0
            local lbl = e.Name .. " [" .. d .. "m]"
            e.Text.Position = Vector2.new(sp.X, sp.Y - 18)
            if e.Text.Text ~= lbl then e.Text.Text = lbl end
            if not e.Text.Visible then e.Text.Visible = true end
        else
            if e.Text.Visible then e.Text.Visible = false end
        end

        table.insert(cands, { dsq = dsq, obj = e.Obj, col = col })
    end

    table.sort(cands, function(a, b) return a.dsq < b.dsq end)

    for i = 1, MAX_HL do
        local h = HLPool[i]
        local c = cands[i]
        if c then
            h.Adornee = c.obj
            h.FillColor = c.col
            h.Enabled = true
        else
            h.Enabled = false
            h.Adornee = nil
        end
    end
end

-- ==================== ESP ИГРОКИ ====================
local plESP = {}

local function CleanPlESP(p)
    local c = plESP[p]
    if not c then return end
    pcall(function() c.NameTag:Remove() end)
    pcall(function() c.Tracer:Remove() end)
    for _, l in pairs(c.Boxes or {}) do
        pcall(function() l:Remove() end)
    end
    if c.HL then pcall(function() c.HL:Destroy() end) end
    plESP[p] = nil
end

Plrs.PlayerRemoving:Connect(CleanPlESP)

local function UpdatePlayerESP()
    local on = (Toggles.PlayerESP and Toggles.PlayerESP.Value)
    local root0 = GetMyRoot()
    local myPos = root0 and root0.Position
    local vp = Cam.ViewportSize

    for _, pl in ipairs(Plrs:GetPlayers()) do
        if pl == LP then continue end
        local char = pl.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if not plESP[pl] then
            local e = {
                NameTag = Drawing.new("Text"),
                Tracer  = Drawing.new("Line"),
                Boxes   = {},
            }
            e.NameTag.Center = true; e.NameTag.Outline = true
            e.NameTag.Size = 14; e.NameTag.Font = 2
            e.Tracer.Thickness = 1.5
            for i = 1, 12 do
                local l = Drawing.new("Line")
                l.Thickness = 1.5; l.Visible = false
                e.Boxes[i] = l
            end
            plESP[pl] = e
        end

        local e = plESP[pl]
        local col = Cfg.PlayerColor
        if Toggles.PlayerRainbow and Toggles.PlayerRainbow.Value then
            col = Color3.fromHSV((tick() * 0.3) % 1, 1, 1)
        end

        if not on or not root or not hum or hum.Health <= 0 then
            e.NameTag.Visible = false; e.Tracer.Visible = false
            for _, l in pairs(e.Boxes) do l.Visible = false end
            if e.HL then pcall(function() e.HL:Destroy() end); e.HL = nil end
            continue
        end

        if Toggles.PlayerChams and Toggles.PlayerChams.Value then
            if not e.HL or not e.HL.Parent then
                local h = Instance.new("Highlight")
                h.FillColor = col
                h.OutlineColor = Color3.fromRGB(255, 255, 255)
                h.FillTransparency = 0.5
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.Adornee = char; h.Parent = SafeGui; e.HL = h
            else
                e.HL.FillColor = col
            end
        else
            if e.HL then pcall(function() e.HL:Destroy() end); e.HL = nil end
        end

        local rsp, onS = Cam:WorldToViewportPoint(root.Position)
        if not onS then
            e.NameTag.Visible = false; e.Tracer.Visible = false
            for _, l in pairs(e.Boxes) do l.Visible = false end
            continue
        end

        local dist = myPos and math.floor((myPos - root.Position).Magnitude) or 0
        local hp  = math.floor(hum.Health)
        local mhp = math.floor(hum.MaxHealth)

        if Toggles.PlayerNames and Toggles.PlayerNames.Value then
            e.NameTag.Text = pl.Name .. "  [" .. hp .. "/" .. mhp .. "hp]  [" .. dist .. "m]"
            e.NameTag.Color = col
            e.NameTag.Position = Vector2.new(rsp.X, rsp.Y - 38)
            e.NameTag.Visible = true
        else
            e.NameTag.Visible = false
        end

        if Toggles.PlayerBox and Toggles.PlayerBox.Value then
            local ext = Vector3.new(1.5, 3, 1.5)
            local cf  = root.CFrame
            local signs = {
                {-1,1,-1},{1,1,-1},{1,-1,-1},{-1,-1,-1},
                {-1,1,1},{1,1,1},{1,-1,1},{-1,-1,1},
            }
            local p2 = {}
            for i, s in ipairs(signs) do
                local wp = (cf * CFrame.new(ext.X*s[1], ext.Y*s[2], ext.Z*s[3])).Position
                local sp2 = Cam:WorldToViewportPoint(wp)
                p2[i] = Vector2.new(sp2.X, sp2.Y)
            end
            local edges = {
                {1,2},{2,3},{3,4},{4,1},
                {5,6},{6,7},{7,8},{8,5},
                {1,5},{2,6},{3,7},{4,8},
            }
            for i, ed in ipairs(edges) do
                local a, b = p2[ed[1]], p2[ed[2]]
                local cl = (b - a) * 0.25
                e.Boxes[i].From = a; e.Boxes[i].To = a + cl
                e.Boxes[i].Color = col; e.Boxes[i].Visible = true
            end
        else
            for _, l in pairs(e.Boxes) do l.Visible = false end
        end

        if Toggles.PlayerTracers and Toggles.PlayerTracers.Value then
            e.Tracer.From = Vector2.new(vp.X / 2, vp.Y)
            e.Tracer.To   = Vector2.new(rsp.X, rsp.Y)
            e.Tracer.Color = col; e.Tracer.Visible = true
        else
            e.Tracer.Visible = false
        end
    end

    for pl in pairs(plESP) do
        if not Plrs:FindFirstChild(pl.Name) then CleanPlESP(pl) end
    end
end

-- ==================== RENDER LOOP ====================
RS.RenderStepped:Connect(function()
    local wAny = (Toggles.ItemESP and Toggles.ItemESP.Value)
                or (Toggles.OreESP and Toggles.OreESP.Value)
                or (Toggles.TreeESP and Toggles.TreeESP.Value)
                or (Toggles.FishESP and Toggles.FishESP.Value)

    if wAny then
        UpdateWorldESP()
    else
        for _, e in pairs(worldESP) do
            if e.Text.Visible then e.Text.Visible = false end
        end
        for _, h in ipairs(HLPool) do
            h.Enabled = false; h.Adornee = nil
        end
    end
    UpdatePlayerESP()
end)

-- ==================== SCAN FOLDERS ====================
local function WatchFolder(folder, cat, getCol)
    if not folder then return end
    for _, o in ipairs(folder:GetChildren()) do
        if not isDeco(o.Name) then MakeWorldESPEntry(o, cat, getCol()) end
    end
    folder.ChildAdded:Connect(function(c)
        task.wait(0.1)
        if not isDeco(c.Name) then MakeWorldESPEntry(c, cat, getCol()) end
    end)
    folder.ChildRemoved:Connect(function(c) RemWorldESP(c) end)
end

task.spawn(function()
    local function fnd(name)
        if WS:FindFirstChild(name) then return WS[name] end
        local ws = WS:FindFirstChild("WorldSpawn")
        return ws and ws:FindFirstChild(name)
    end
    task.wait(1)
    local gf, of, tf = fnd("Grab"), fnd("Ores"), fnd("Trees")
    if gf then WatchFolder(gf, "Grab", function() return Cfg.ItemColor end) end
    if of then WatchFolder(of, "Ores", function() return Cfg.OreColor end) end
    if tf then WatchFolder(tf, "Trees", function() return Cfg.TreeColor end) end
    local ws = WS:FindFirstChild("WorldSpawn")
    if ws then
        if not gf then local f=ws:FindFirstChild("Grab"); if f then WatchFolder(f,"Grab",function() return Cfg.ItemColor end) end end
        if not of then local f=ws:FindFirstChild("Ores"); if f then WatchFolder(f,"Ores",function() return Cfg.OreColor end) end end
        if not tf then local f=ws:FindFirstChild("Trees"); if f then WatchFolder(f,"Trees",function() return Cfg.TreeColor end) end end
    end
end)

-- ==================== FISH HITBOX ====================
local function ApplyFishHB(obj)
    if not obj or isDeco(obj.Name) then return end
    local c = Cfg.FishHitbox
    local hf = obj:FindFirstChild("Hit")
    local rp = hf and hf:FindFirstChild("RootPart")
    if not rp or not rp:IsA("BasePart") then
        rp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    end
    if not rp then return end
    if not c.Orig[rp] then
        c.Orig[rp] = { Size = rp.Size, Tr = rp.Transparency, CC = rp.CanCollide }
    end
    local o = c.Orig[rp]
    if c.Enabled then
        rp.Size = c.Size; rp.Transparency = c.Transparency; rp.CanCollide = false
        pcall(function() rp.Massless = true end)
    else
        rp.Size = o.Size; rp.Transparency = o.Tr; rp.CanCollide = o.CC
        pcall(function() rp.Massless = false end)
    end
end

local function RefreshFishHB()
    local bf = WS:FindFirstChild("BigFish")
    if not bf then return end
    for _, f in ipairs(bf:GetChildren()) do ApplyFishHB(f) end
end

task.spawn(function()
    local bf = WS:WaitForChild("BigFish", 10)
    if not bf then return end
    for _, f in ipairs(bf:GetChildren()) do
        ApplyFishHB(f)
        MakeWorldESPEntry(f, "BigFish", Cfg.FishColor)
    end
    bf.ChildAdded:Connect(function(c)
        task.wait(0.05)
        ApplyFishHB(c)
        MakeWorldESPEntry(c, "BigFish", Cfg.FishColor)
    end)
    bf.ChildRemoved:Connect(function(c) RemWorldESP(c) end)
    local last = Cfg.FishHitbox.Enabled
    while true do
        task.wait(1)
        local cur = Cfg.FishHitbox.Enabled
        if cur ~= last then last = cur; RefreshFishHB() end
    end
end)

-- ==================== ПЛАТФОРМА ====================
local Platform = nil

local function MakePlatform(pos)
    if Platform then pcall(function() Platform:Destroy() end); Platform = nil end
    local hum = GetMyHum()
    if hum then hum.PlatformStand = true end
    local p = Instance.new("Part")
    p.Name = "LunarPlatform"
    p.Size = Vector3.new(8, 0.5, 8)
    p.Anchored = true; p.CanCollide = true; p.Locked = true
    p.Transparency = 0.5
    p.Material = Enum.Material.SmoothPlastic
    p.Color = Color3.fromRGB(50, 150, 255)
    p.CFrame = CFrame.new(pos.X, pos.Y - 3.1, pos.Z)
    p.Parent = WS; Platform = p
end

local function KillPlatform()
    if Platform then pcall(function() Platform:Destroy() end); Platform = nil end
    local hum = GetMyHum()
    if hum then hum.PlatformStand = false end
end

-- ==================== ПЛОТ ====================
local function GetPlot()
    local plots = WS:FindFirstChild("Plots")
    if not plots then return nil end
    for _, pl in ipairs(plots:GetChildren()) do
        local ow = pl:GetAttribute("Owner")
        if ow and (tostring(ow) == LP.Name or tostring(ow) == LP.DisplayName) then
            return pl
        end
    end
    return nil
end

local function TPToPlot()
    local p = GetPlot()
    if p and p.PrimaryPart then
        TPTo(p.PrimaryPart.CFrame + Vector3.new(0, 5, 0))
        return true
    end
    return false
end

-- ==================== ПРОДАЖА ====================
local function SellAll()
    local sellPart = WS:FindFirstChild("Map")
        and WS.Map:FindFirstChild("Structures")
        and WS.Map.Structures:FindFirstChild("Nova_Sellary")
        and WS.Map.Structures.Nova_Sellary:FindFirstChild("TalkPart")
        and WS.Map.Structures.Nova_Sellary.TalkPart:FindFirstChild("Interact")
    if not sellPart then Library:Notify("Sellary не найден!", 3); return false end
    local talkPart = WS.Map.Structures.Nova_Sellary.TalkPart
    TPTo(talkPart.CFrame + Vector3.new(0, 3, 0))
    task.wait(0.6)
    pcall(function() sellPart:FireServer("Deal", 1, nil) end)
    task.wait(0.3)
    Library:Notify("Продано!", 2)
    return true
end

-- ==================== АВТО-ЭКИПИРОВКА И СУМКА ====================
local function EquipTool(toolKeywords)
    local char = LP.Character
    if not char then return false end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") then
            local name = t.Name:lower()
            for _, kw in ipairs(toolKeywords) do
                if name:find(kw) then return true end
            end
        end
    end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then
                local name = t.Name:lower()
                for _, kw in ipairs(toolKeywords) do
                    if name:find(kw) then
                        t.Parent = char; task.wait(0.15); return true
                    end
                end
            end
        end
    end
    return false
end

local function EquipSack()
    return EquipTool({ "sack", "сумка", "мешок", "bag" })
end

local function GetItemPriority(name)
    local n = name:lower()
    if n:find("ancient") then return 1 end
    if n:find("obsidian") then return 2 end
    return 3
end

local function GetBagEv()
    local char = LP.Character
    if char then
        local bag = char:FindFirstChild("Item Bag")
        if bag then
            local act = bag:FindFirstChild("Action")
            if act then return act end
        end
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find("sack") then
                local act = t:FindFirstChild("Action")
                if act then return act end
            end
        end
    end
    return nil
end

local function DropBatch()
    EquipSack()
    local ev = GetBagEv()
    if not ev then return end
    local n = GetSackSize()
    for i = 1, n do
        pcall(function() ev:FireServer("Drop") end)
        task.wait(Cfg.BagDelay)
    end
end

-- ==================== АВТО-ФАРМ ====================
local FarmThread = nil
local FarmObjects = {}
local FarmDropValues = {}

local function RebuildFarmList()
    FarmObjects = {}; FarmDropValues = {}
    local seen = {}
    local function scan(folderName)
        local folder = WS:FindFirstChild(folderName) or (WS:FindFirstChild("WorldSpawn") and WS.WorldSpawn:FindFirstChild(folderName))
        if not folder then return end
        for _, obj in ipairs(folder:GetChildren()) do
            if isDeco(obj.Name) then continue end
            local p = GetPart(obj)
            if not p then continue end
            local key = folderName .. ":" .. obj.Name
            if not seen[key] then
                seen[key] = true
                table.insert(FarmObjects, { name=obj.Name, folder=folderName, obj=obj, part=p })
                if not table.find(FarmDropValues, obj.Name) then
                    table.insert(FarmDropValues, obj.Name)
                end
            end
        end
    end
    scan("Trees"); scan("Ores")
    table.sort(FarmDropValues)
end

local function GetNearestFarmTarget()
    local root = GetMyRoot()
    if not root then return nil, nil end
    local pos = root.Position
    local best = math.huge; local bestPart = nil; local bestIsTree = false
    local treeFolder = WS:FindFirstChild("Trees") or (WS:FindFirstChild("WorldSpawn") and WS.WorldSpawn:FindFirstChild("Trees"))
    local oreFolder  = WS:FindFirstChild("Ores")  or (WS:FindFirstChild("WorldSpawn") and WS.WorldSpawn:FindFirstChild("Ores"))
    local function scan(folder, isTree)
        if not folder then return end
        for _, obj in ipairs(folder:GetChildren()) do
            if isDeco(obj.Name) then continue end
            local allowed = next(Cfg.FarmSelected) == nil or Cfg.FarmSelected[obj.Name] == true
            if not allowed then continue end
            local p = GetPart(obj)
            if not p then continue end
            local d = (pos - p.Position).Magnitude
            if d < best then best=d; bestPart=p; bestIsTree=isTree end
        end
    end
    scan(treeFolder, true); scan(oreFolder, false)
    return bestPart, bestIsTree
end

local function WaitForItemsToDrop(timeoutSec)
    local t = 0
    local grab = WS:FindFirstChild("Grab") or (WS:FindFirstChild("WorldSpawn") and WS.WorldSpawn:FindFirstChild("Grab"))
    if not grab then return end
    while t < timeoutSec do
        local root = GetMyRoot()
        if root then
            for _, item in ipairs(grab:GetChildren()) do
                local p = GetPart(item)
                if p and (root.Position - p.Position).Magnitude <= Cfg.PickupRadius + 10 then return end
            end
        end
        task.wait(0.2); t = t + 0.2
    end
end

local function CollectNearbyItems()
    EquipSack(); task.wait(0.2)
    local ev = GetBagEv()
    if not ev then return end
    local grab = WS:FindFirstChild("Grab") or (WS:FindFirstChild("WorldSpawn") and WS.WorldSpawn:FindFirstChild("Grab"))
    if not grab then return end
    local root = GetMyRoot()
    if not root then return end
    local near = {}
    for _, item in ipairs(grab:GetChildren()) do
        local p = GetPart(item)
        if p then
            local d = (root.Position - p.Position).Magnitude
            local nm = next(Cfg.CollectSelected) == nil or Cfg.CollectSelected[item.Name] == true
            if d <= Cfg.PickupRadius and nm then
                table.insert(near, { p=p, d=d })
            end
        end
    end
    table.sort(near, function(a,b) return a.d < b.d end)
    for _, it in ipairs(near) do
        if it.p and it.p.Parent then
            pcall(function() ev:FireServer("Store", it.p) end)
            task.wait(Cfg.BagDelay)
        end
    end
end

local function DumpToPlot()
    local savedPos = GetMyRoot() and GetMyRoot().CFrame
    KillPlatform()
    local ok = TPToPlot()
    if not ok then Library:Notify("Плот не найден!", 3); return false end
    task.wait(0.5)
    EquipSack(); task.wait(0.2)
    DropBatch(); task.wait(0.5)
    Library:Notify("Сдача на плот", 2)
    if Toggles.AutoSellToggle and Toggles.AutoSellToggle.Value then
        SellAll(); task.wait(0.5)
    end
    if savedPos then TPTo(savedPos); task.wait(0.3) end
    return true
end

local function StopFarm()
    if FarmThread then task.cancel(FarmThread); FarmThread = nil end
    KillPlatform()
end

local function StartFarm()
    if FarmThread then return end
    FarmThread = task.spawn(function()
        while true do
            local active = (Toggles.AutoFarmToggle and Toggles.AutoFarmToggle.Value)
            if not active then break end
            local target, isTree = GetNearestFarmTarget()
            if not target or not target.Parent then task.wait(0.5); continue end
            if isTree then EquipTool({"axe"}) else EquipTool({"pickaxe","pick"}) end
            task.wait(0.2)
            local root = GetMyRoot()
            if not root then task.wait(0.5); continue end
            local dist = (root.Position - target.Position).Magnitude
            if dist > Cfg.FarmRange then
                local dir = (target.Position - root.Position).Unit
                root.CFrame = CFrame.new(target.Position - dir * 3 + Vector3.new(0,4,0))
                task.wait(0.15)
            end
            root = GetMyRoot()
            if root and Toggles.FarmPlatformToggle and Toggles.FarmPlatformToggle.Value then
                MakePlatform(root.Position); task.wait(0.05)
            end
            local function GetHitPos()
                if not target or not target.Parent then return Vector3.new() end
                if isTree then
                    local sizeY = target.Size and target.Size.Y or 4
                    return target.Position - Vector3.new(0, sizeY * 0.45, 0)
                else
                    return target.Position
                end
            end
            local maxHitAttempts = 200; local attempts = 0
            while target and target.Parent and (Toggles.AutoFarmToggle and Toggles.AutoFarmToggle.Value) do
                attempts = attempts + 1
                if attempts > maxHitAttempts then Library:Notify("Цель не умирает, пропускаю", 2); break end
                local hp = GetHitPos()
                pcall(function() ChargeEv:FireServer({ Target=target, HitPosition=hp }) end)
                task.wait(Cfg.FarmHitDelay)
                for i = 1, Cfg.FarmHits do
                    if not target or not target.Parent then break end
                    pcall(function()
                        AttackEv:FireServer({ Target=target, HitPosition=hp, Alpha=0.995+math.random()*0.004 })
                    end)
                    task.wait(0.04)
                end
                task.wait(0.05)
            end
            KillPlatform(); task.wait(0.3)
            WaitForItemsToDrop(2)
            CollectNearbyItems(); task.wait(0.2)
            local shouldDump = (Toggles.AutoDumpToggle and Toggles.AutoDumpToggle.Value) or IsSackFull()
            if shouldDump then DumpToPlot() end
            task.wait(Cfg.FarmLoopDelay)
        end
        StopFarm()
    end)
end

-- ==================== УСКОРЕННАЯ РЫБАЛКА ====================
local FishThread = nil

local function StopFish()
    if FishThread then task.cancel(FishThread); FishThread = nil end
end

local function StartFish()
    if FishThread then return end
    FishThread = task.spawn(function()
        local cachedRod = nil
        while Toggles.AutoFish and Toggles.AutoFish.Value do
            local char = LP.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not char or not root then task.wait(0.2); continue end
            if not (cachedRod and cachedRod.Parent) then
                cachedRod = nil
                for _, t in ipairs(char:GetChildren()) do
                    if t:IsA("Tool") then
                        local n = t.Name:lower()
                        if n:find("rod") or n:find("fish") or n:find("удочк") then
                            cachedRod = t; break
                        end
                    end
                end
                if not cachedRod then
                    local bp = LP:FindFirstChildOfClass("Backpack")
                    if bp then
                        for _, t in ipairs(bp:GetChildren()) do
                            if t:IsA("Tool") then
                                local n = t.Name:lower()
                                if n:find("rod") or n:find("fish") or n:find("удочк") then
                                    cachedRod = t; break
                                end
                            end
                        end
                    end
                end
            end
            if not cachedRod then task.wait(0.5); continue end
            if cachedRod.Parent ~= char then cachedRod.Parent = char end
            local castPos = CFrame.new(root.Position + root.CFrame.LookVector * 15 + Vector3.new(0,-3,0))
            ChargeEv:FireServer({ HitPosition = castPos })
            task.wait(Cfg.CastDelay)
            AttackEv:FireServer({
                Alpha        = 0.995 + math.random() * 0.004,
                ResponseTime = 0.995 + math.random() * 0.005,
                HitPosition  = castPos,
            })
            local biteHappened = false
            local biteTimeout = 15
            local conn
            local biteEv = FishEv and FishEv:FindFirstChild("ReelSessionStart")
            if biteEv then
                conn = biteEv.OnClientEvent:Connect(function() biteHappened = true end)
            end
            local elapsed = 0
            while not biteHappened and elapsed < biteTimeout do
                if not (Toggles.AutoFish and Toggles.AutoFish.Value) then break end
                task.wait(0.1); elapsed = elapsed + 0.1
            end
            if conn then conn:Disconnect() end
            if not biteHappened and biteEv then
                EndEv:FireServer(); task.wait(0.2); continue
            end
            if not biteEv then task.wait(Cfg.WaitBite) end
            for i = 1, Cfg.HitCount do
                if not (Toggles.AutoFish and Toggles.AutoFish.Value) then break end
                HitEv:FireServer(); task.wait(Cfg.HitInterval)
            end
            EndEv:FireServer(); task.wait(Cfg.ResetDelay)
        end
        StopFish()
    end)
end

-- ==================== АВТО-СБОР ====================
local CollectThread = nil

local function StopCollect()
    if CollectThread then task.cancel(CollectThread); CollectThread = nil end
end

local function StartCollect()
    if CollectThread then return end
    CollectThread = task.spawn(function()
        while Toggles.AutoCollectToggle and Toggles.AutoCollectToggle.Value do

            -- ТП к точке КУДА если включено и задано
            if Cfg.UseCustomTPCollect and Cfg.CollectToPos then
                local root = GetMyRoot()
                if root then
                    local dist = (root.Position - Cfg.CollectToPos.Position).Magnitude
                    if dist > 10 then
                        TPTo(Cfg.CollectToPos); task.wait(0.4)
                    end
                end
            end

            local grab = WS:FindFirstChild("Grab") or (WS:FindFirstChild("WorldSpawn") and WS.WorldSpawn:FindFirstChild("Grab"))
            if not grab then task.wait(1); continue end

            local items = {}
            for _, item in ipairs(grab:GetChildren()) do
                local p = GetPart(item)
                if p then
                    local nm = next(Cfg.CollectSelected) == nil or Cfg.CollectSelected[item.Name] == true
                    if nm then table.insert(items, { item=item, p=p }) end
                end
            end

            if #items == 0 then task.wait(1); continue end

            local root = GetMyRoot()
            if not root then task.wait(0.5); continue end

            table.sort(items, function(a, b)
                return (root.Position - a.p.Position).Magnitude < (root.Position - b.p.Position).Magnitude
            end)

            EquipSack(); task.wait(0.2)
            local bagEv = GetBagEv()
            if not bagEv then task.wait(1); continue end

            local sackSize = GetSackSize()
            local taken = 0

            local function DoUnload()
                -- Едем на точку ОТКУДА (или плот)
                if Cfg.UseCustomTPCollect and Cfg.CollectFromPos then
                    TPTo(Cfg.CollectFromPos); task.wait(0.5)
                else
                    local ok = TPToPlot()
                    if ok then task.wait(0.5) end
                end
                EquipSack(); task.wait(0.2)
                DropBatch(); task.wait(0.5)
                Library:Notify("Сдача: точка ОТКУДА", 2)
                if Toggles.AutoSellToggle and Toggles.AutoSellToggle.Value then
                    SellAll(); task.wait(0.5)
                end
                -- Возврат на точку КУДА
                if Cfg.UseCustomTPCollect and Cfg.CollectToPos then
                    TPTo(Cfg.CollectToPos); task.wait(0.4)
                end
                taken = 0
                EquipSack(); task.wait(0.2)
                bagEv = GetBagEv()
            end

            for _, it in ipairs(items) do
                if not (Toggles.AutoCollectToggle and Toggles.AutoCollectToggle.Value) then break end
                if taken >= sackSize then DoUnload() end
                if not bagEv then break end
                if not it.p or not it.p.Parent then continue end
                local myR = GetMyRoot()
                if not myR then continue end
                local d = (myR.Position - it.p.Position).Magnitude
                if d > Cfg.PickupRadius then
                    myR.CFrame = CFrame.new(it.p.Position + Vector3.new(0,3,0))
                    task.wait(0.15)
                end
                pcall(function() bagEv:FireServer("Store", it.p) end)
                taken = taken + 1; task.wait(Cfg.BagDelay)
            end

            if taken > 0 then
                DoUnload()
            end

            task.wait(0.3)
        end
        StopCollect()
    end)
end

-- ==================== ДВИЖЕНИЕ ====================
local NCP = {}

local function RebuildNCP(char)
    NCP = {}
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then table.insert(NCP, p) end
    end
end

LP.CharacterAdded:Connect(function(c)
    task.wait(0.5); RebuildNCP(c)
end)
if LP.Character then RebuildNCP(LP.Character) end

RS.Stepped:Connect(function()
    if not Cfg.NoClip then return end
    for _, p in ipairs(NCP) do
        if p and p.Parent then p.CanCollide = false end
    end
end)

RS.Heartbeat:Connect(function()
    local h = GetMyHum()
    if not h then return end
    if Cfg.SpeedWalk then h.WalkSpeed = Cfg.SpeedVal end
end)

UIS.JumpRequest:Connect(function()
    if not Cfg.InfJump then return end
    local h = GetMyHum()
    if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

local FBV = nil
local FBG = nil
local WF = false

local function MakeFly(root)
    if FBV then pcall(function() FBV:Destroy() end) end
    FBV = Instance.new("BodyVelocity")
    FBV.MaxForce = Vector3.new(1e5,1e5,1e5); FBV.Velocity = Vector3.new()
    FBV.P = 1e4; FBV.Parent = root
    if FBG then pcall(function() FBG:Destroy() end) end
    FBG = Instance.new("BodyGyro")
    FBG.MaxTorque = Vector3.new(1e5,1e5,1e5); FBG.P = 1e4; FBG.D = 100
    FBG.CFrame = root.CFrame; FBG.Parent = root
end

local function KillFly()
    if FBV then pcall(function() FBV:Destroy() end); FBV = nil end
    if FBG then pcall(function() FBG:Destroy() end); FBG = nil end
end

RS.RenderStepped:Connect(function()
    local root = GetMyRoot()
    local hum = GetMyHum()
    if not root or not hum then return end
    if Cfg.Fly then
        WF = true; hum.PlatformStand = true
        if not FBV or not FBV.Parent then MakeFly(root) end
        local cf = Cam.CFrame; local dir = Vector3.new()
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
        FBV.Velocity = dir.Magnitude > 0 and dir.Unit * Cfg.FlySpeed or FBV.Velocity * 0.8
        if FBV.Velocity.Magnitude < 0.5 then FBV.Velocity = Vector3.new() end
        FBG.CFrame = CFrame.new(Vector3.new(), cf.LookVector)
    else
        if WF then
            WF = false; KillFly()
            task.defer(function()
                local h2 = GetMyHum()
                if h2 then h2.PlatformStand = false end
            end)
        end
    end
end)

LP.CharacterAdded:Connect(function()
    WF = false; FBV = nil; FBG = nil
end)

-- ==================== КРАФТ ====================
local Recipes = {
    Factory = {
        ["Concrete"] = {
            CraftTime = 10,
            Input = { Solid = { Sand={Amount=10,Type="Material"}, Cobblestone={Amount=10,Type="Material"} }, Liquid={} },
            Machine = "Factory",
            Output = { Concrete = { Type="Material", Amount=10 } },
        },
        ["Rubber"] = {
            CraftTime = 20,
            Input = { Solid = { ["Pine Wood"]={Amount=20,Type="Material"}, Sulfur={Amount=5,Type="Material"} }, Liquid={} },
            Machine = "Factory",
            Output = { Rubber = { Type="Material", Amount=5 } },
        },
        ["Steel"] = {
            CraftTime = 10,
            Input = { Solid = { Coal={Amount=20,Type="Material"}, Iron={Amount=20,Type="Material"} }, Liquid={} },
            Machine = "Factory",
            Output = { Steel = { Type="Material", Amount=10 } },
        },
        ["Dynamite"] = {
            CraftTime = 20,
            Input = { Solid = { Coal={Amount=15,Type="Material"}, Sulfur={Amount=10,Type="Material"}, Iron={Amount=10,Type="Material"} }, Liquid={} },
            Machine = "Factory",
            Output = { Dynamite = { Type="Item", Amount=1 } },
        },
        ["Scorchium"] = {
            CraftTime = 30,
            Input = { Solid = { Volcanium={Amount=13,Type="Material"} }, Liquid = { Oil={Amount=5} } },
            Machine = "Factory",
            Output = { Scorchium = { Type="Material", Amount=3.375 } },
        },
        ["Fallen Key"] = {
            CraftTime = 30,
            Input = { Solid = { Steel={Amount=10,Type="Material"}, ["Fallen Star"]={Amount=1,Type="Material"} }, Liquid={} },
            Machine = "Factory",
            Output = { ["Fallen Key"] = { Type="Item", Amount=1 } },
        },
        ["Machinery Parts"] = {
            CraftTime = 15,
            Input = { Solid = { Steel={Amount=5,Type="Material"}, Rubber={Amount=5,Type="Material"} }, Liquid={} },
            Machine = "Factory",
            Output = { ["Machinery Parts"] = { Type="Item", Amount=1 } },
        },
        ["Hot Cocoa"] = {
            CraftTime = 10,
            Input = { Solid = { Sunstone={Amount=10,Type="Material"}, ["Cocoa Bag"]={Amount=1,Type="Item"}, Magma={Amount=15,Type="Material"} }, Liquid={} },
            Machine = "Factory",
            Output = { ["Hot Cocoa"] = { Type="Item", Amount=1 } },
        },
    },
    ["Oil Refinery"] = {
        ["Mineral Oil"] = {
            CraftTime = 30,
            Input = { Solid = { ["Raw Fish"]={Amount=3,Type="Item"} }, Liquid = { Oil={Amount=5} } },
            Machine = "Oil Refinery",
            Output = { ["Mineral Oil"] = { Type="Item", Amount=1 } },
        },
        ["Industrial Oil"] = {
            CraftTime = 30,
            Input = { Solid = { Lithium={Amount=10,Type="Material"}, Gasoline={Amount=3,Type="Item"} }, Liquid = { Oil={Amount=25} } },
            Machine = "Oil Refinery",
            Output = { ["Industrial Oil"] = { Type="Item", Amount=1 } },
        },
        ["Gasoline"] = {
            CraftTime = 3,
            Input = { Solid = {}, Liquid = { Oil={Amount=3} } },
            Machine = "Oil Refinery",
            Output = { Gasoline = { Type="Item", Amount=1 } },
        },
    },
}

local function Craft(mach, rec)
    local plot = GetPlot()
    if not plot then Library:Notify("Плот не найден!", 5); return end
    local obj = plot:FindFirstChild("Objects")
    local m = obj and obj:FindFirstChild(mach)
    if not m then Library:Notify("Машина " .. mach .. " не найдена!", 5); return end
    local rd = Recipes[mach] and Recipes[mach][rec]
    if not rd then Library:Notify("Рецепт не найден!", 5); return end
    local ev = RepS:FindFirstChild("Events")
    local cse = ev and ev:FindFirstChild("CraftSelect")
    local cie = ev and ev:FindFirstChild("CraftInput")
    if not cse then Library:Notify("CraftSelect не найден!", 5); return end
    if cie then cie:FireServer(m); task.wait(0.15) end
    cse:FireServer(rec, rd, m); task.wait(0.2)
    local ci = m:FindFirstChild("Craft") and m.Craft:FindFirstChild("Input") and m.Craft.Input:FindFirstChild("Interact")
    if ci then
        ci:FireServer(); Library:Notify("Крафт " .. rec .. " запущен!", 4)
    else
        Library:Notify("Interact не найден!", 5)
    end
end

-- ==================== GUI ====================
local Win = Library:CreateWindow({
    Title     = "Lunar Hub | RC2",
    Center    = true,
    AutoShow  = true,
    TabPadding = 7,
})

local T = {
    Main     = Win:AddTab("Main"),
    ESP      = Win:AddTab("ESP"),
    Misc     = Win:AddTab("Misc"),
    Settings = Win:AddTab("Settings"),
}

-- ===== MAIN =====
local TabBox = T.Main:AddLeftTabbox("Main")
local Tabbox = {
    Farm     = TabBox:AddTab("Farm"),
    Fishing  = TabBox:AddTab("Fishing"),
    Colletor = TabBox:AddTab("Colletor"),
    Craft    = TabBox:AddTab("Craft"),
}

-- Fishing
Tabbox.Fishing:AddToggle("PerfectCatch", {
    Text    = "Perfect Catch",
    Default = true,
    Callback = function(v) Cfg.PerfectCatch = v end,
})
Tabbox.Fishing:AddToggle("AutoFish", {
    Text    = "Auto Fish",
    Default = false,
    Callback = function(v)
        if v then StartFish() else StopFish() end
    end,
})

-- Collector
Tabbox.Colletor:AddButton("Продать сейчас", function() SellAll() end)
Tabbox.Colletor:AddToggle("AutoSellToggle", {
    Text    = "Авто-продажа (после сдачи)",
    Default = false,
    Callback = function() end,
})
Tabbox.Colletor:AddToggle("AutoCollectToggle", {
    Text    = "Авто-Сбор",
    Default = false,
    Callback = function(v)
        if v then StartCollect() else StopCollect() end
    end,
})

-- ----- КАСТОМНЫЙ ТП ДЛЯ СБОРА -----
Tabbox.Colletor:AddToggle("UseCustomTPCollect", {
    Text    = "CustomTp",
    Default = false,
    Callback = function(v)
        Cfg.UseCustomTPCollect = v
    end,
})

-- Показываем сохранённые точки из Waypoints в дропдаун
local CollectWpNames = {}
local function GetWaypointNames()
    CollectWpNames = {}
    for name in pairs(Cfg.Waypoints) do
        table.insert(CollectWpNames, name)
    end
    table.sort(CollectWpNames)
    return CollectWpNames
end

-- Дропдаун ОТКУДА
local CollectFromDD = Tabbox.Colletor:AddDropdown("CollectFromDD", {
    Values  = GetWaypointNames(),
    Default = 1,
    Multi   = false,
    Text    = "From",
    Callback = function(v)
        if v and Cfg.Waypoints[v] then
            Cfg.CollectFromPos = Cfg.Waypoints[v]
            Library:Notify("ОТКУДА = " .. v, 2)
        end
    end,
})

-- Кнопка — сохранить текущую позицию как ОТКУДА (в waypoints)
local CollectFromNameInput = ""
Tabbox.Colletor:AddInput("CollectFromName", {
    Default     = "",
    Numeric     = false,
    Finished    = false,
    Text        = "name positions",
    Placeholder = "idk",
    Callback    = function(v) CollectFromNameInput = v end,
})
Tabbox.Colletor:AddButton("Save pos from", function()
    local root = GetMyRoot()
    local name = CollectFromNameInput
    if not root then Library:Notify("Персонаж не найден!", 3); return end
    if name == "" then Library:Notify("Введи имя точки!", 3); return end
    Cfg.Waypoints[name] = root.CFrame
    Cfg.CollectFromPos  = root.CFrame
    SaveCustomData()
    local names = GetWaypointNames()
    CollectFromDD:SetValues(names)
    CollectToDD_ref_update()  -- обновим и второй дропдаун
    Library:Notify("ОТКУДА сохранено: " .. name, 3)
end)

-- Дропдаун КУДА
local CollectToDD = nil  -- объявим после, чтобы функция update могла его захватить
local function CollectToDD_ref_update() end  -- заглушка, переопределим ниже

CollectToDD = Tabbox.Colletor:AddDropdown("CollectToDD", {
    Values  = GetWaypointNames(),
    Default = 1,
    Multi   = false,
    Text    = "To",
    Callback = function(v)
        if v and Cfg.Waypoints[v] then
            Cfg.CollectToPos = Cfg.Waypoints[v]
            Library:Notify("КУДА = " .. v, 2)
        end
    end,
})

-- Имя + кнопка для точки КУДА
local CollectToNameInput = ""
Tabbox.Colletor:AddInput("CollectToName", {
    Default     = "",
    Numeric     = false,
    Finished    = false,
    Text        = "name pos to",
    Placeholder = "idk",
    Callback    = function(v) CollectToNameInput = v end,
})
Tabbox.Colletor:AddButton("save pos to", function()
    local root = GetMyRoot()
    local name = CollectToNameInput
    if not root then Library:Notify("Персонаж не найден!", 3); return end
    if name == "" then Library:Notify("Введи имя точки!", 3); return end
    Cfg.Waypoints[name] = root.CFrame
    Cfg.CollectToPos    = root.CFrame
    SaveCustomData()
    local names = GetWaypointNames()
    CollectFromDD:SetValues(names)
    CollectToDD:SetValues(names)
    Library:Notify("КУДА сохранено: " .. name, 3)
end)

-- Переопределяем заглушку теперь когда CollectToDD существует
CollectToDD_ref_update = function()
    local names = GetWaypointNames()
    CollectToDD:SetValues(names)
end

-- Кнопка — показать текущие точки
Tabbox.Colletor:AddButton("Show pos from/to", function()
    local function fmt(cf)
        if not cf then return "не задана" end
        return ("X:%d Y:%d Z:%d"):format(math.floor(cf.X), math.floor(cf.Y), math.floor(cf.Z))
    end
    Library:Notify("ОТКУДА: " .. fmt(Cfg.CollectFromPos) .. "\nКУДА: " .. fmt(Cfg.CollectToPos), 6)
end)

local GrabItems = {}
local ColDD = Tabbox.Colletor:AddDropdown("ColSelectDD", {
    Values  = {},
    Default = 1,
    Multi   = true,
    Text    = "item to take",
    Callback = function(v) Cfg.CollectSelected = v end,
})
Tabbox.Colletor:AddButton("Обновить список предметов", function()
    local grab = WS:FindFirstChild("Grab") or (WS:FindFirstChild("WorldSpawn") and WS.WorldSpawn:FindFirstChild("Grab"))
    GrabItems = {}
    if grab then
        local seen = {}
        for _, it in ipairs(grab:GetChildren()) do
            if not isDeco(it.Name) and not seen[it.Name] then
                seen[it.Name] = true
                table.insert(GrabItems, it.Name)
            end
        end
    end
    table.sort(GrabItems)
    ColDD:SetValues(GrabItems)
    Library:Notify("Grab: " .. #GrabItems .. " видов", 2)
end)

-- Craft
local FL = {}
for n in pairs(Recipes.Factory) do table.insert(FL, n) end
table.sort(FL)
local SF = FL[1]

Tabbox.Craft:AddDropdown("FactDD", {
    Values  = FL, Default = 1, Multi = false, Text = "Factory рецепт",
    Callback = function(v) SF = v end,
})
Tabbox.Craft:AddButton("Крафт Factory", function()
    if SF then Craft("Factory", SF) end
end)

local OL = {}
for n in pairs(Recipes["Oil Refinery"]) do table.insert(OL, n) end
table.sort(OL)
local SO = OL[1]

Tabbox.Craft:AddDropdown("OilDD", {
    Values  = OL, Default = 1, Multi = false, Text = "Oil Refinery рецепт",
    Callback = function(v) SO = v end,
})
Tabbox.Craft:AddButton("Крафт Oil Refinery", function()
    if SO then Craft("Oil Refinery", SO) end
end)

-- Farm
Tabbox.Farm:AddLabel("Предупреждение что скрипт в бета")
Tabbox.Farm:AddLabel("версии и функции могут плохо")
Tabbox.Farm:AddLabel("работать/не работать")

Tabbox.Farm:AddToggle("AutoFarmToggle", {
    Text    = "Авто-Фарм",
    Default = false,
    Callback = function(v)
        if v then StartFarm() else StopFarm() end
    end,
})
Tabbox.Farm:AddToggle("FarmPlatformToggle", {
    Text    = "Платформа (не падать)",
    Default = true,
    Callback = function(v) if not v then KillPlatform() end end,
})
Tabbox.Farm:AddToggle("AutoDumpToggle", {
    Text    = "Авто-сдача на плот",
    Default = true,
    Callback = function() end,
})

local FarmDD = Tabbox.Farm:AddDropdown("FarmSelectDD", {
    Values  = {}, Default = 1, Multi = true, Text = "Выберите цели",
    Callback = function(v) Cfg.FarmSelected = v end,
})
Tabbox.Farm:AddButton("Обновить список", function()
    RebuildFarmList()
    FarmDD:SetValues(FarmDropValues)
    Library:Notify("Список обновлён: " .. #FarmDropValues .. " объектов", 2)
end)

task.spawn(function()
    task.wait(2); RebuildFarmList(); FarmDD:SetValues(FarmDropValues)
end)

-- ===== ESP =====
local EspW = T.ESP:AddLeftGroupbox("Мир")
local EspP = T.ESP:AddRightGroupbox("Игроки")

EspW:AddSlider("MaxDist", {
    Text="Макс. дистанция", Default=1000, Min=50, Max=10000, Rounding=0,
    Callback = function(v) Cfg.MaxDist = v end,
})
EspW:AddInput("EspFilter", {
    Default="", Numeric=false, Finished=false, Text="Фильтр", Placeholder="Название...",
    Callback = function(v) Cfg.SearchFilter = v:lower() end,
})
EspW:AddToggle("ItemESP", { Text="ESP Предметов (Grab)", Default=false })
:AddColorPicker("ItemCol", { Default=Cfg.ItemColor, Title="Цвет", Callback=function(v) Cfg.ItemColor=v end })
local ItemDD = EspW:AddDropdown("ItemDD", {
    Values={}, Default=1, Multi=true, Text="Предметы",
    Callback=function(v) Cfg.SelectedItems=v end,
})
EspW:AddToggle("OreESP", { Text="ESP Руд", Default=false })
:AddColorPicker("OreCol", { Default=Cfg.OreColor, Title="Цвет", Callback=function(v) Cfg.OreColor=v end })
local OreDD = EspW:AddDropdown("OreDD", {
    Values={}, Default=1, Multi=true, Text="Руды",
    Callback=function(v) Cfg.SelectedOres=v end,
})
EspW:AddToggle("TreeESP", { Text="ESP Деревьев", Default=false })
:AddColorPicker("TreeCol", { Default=Cfg.TreeColor, Title="Цвет", Callback=function(v) Cfg.TreeColor=v end })
local TreeDD = EspW:AddDropdown("TreeDD", {
    Values={}, Default=1, Multi=true, Text="Деревья",
    Callback=function(v) Cfg.SelectedTrees=v end,
})
EspW:AddToggle("FishESP", { Text="ESP Большой Рыбы", Default=false })
:AddColorPicker("FishCol", { Default=Cfg.FishColor, Title="Цвет", Callback=function(v) Cfg.FishColor=v end })

EspP:AddToggle("PlayerESP", {
    Text="ESP Игроков", Default=false,
    Callback = function(v)
        if not v then
            for _, c in pairs(plESP) do
                if c.NameTag then c.NameTag.Visible=false end
                if c.Tracer  then c.Tracer.Visible=false end
                for _, l in pairs(c.Boxes or {}) do l.Visible=false end
            end
        end
    end,
})
:AddColorPicker("PlCol", { Default=Cfg.PlayerColor, Title="Цвет", Callback=function(v) Cfg.PlayerColor=v end })
EspP:AddToggle("PlayerNames",   { Text="Имена + HP + Дист",   Default=true,  Callback=function() end })
EspP:AddToggle("PlayerBox",     { Text="3D Corner Box",        Default=true,  Callback=function() end })
EspP:AddToggle("PlayerTracers", { Text="Трейсеры (снизу)",     Default=false, Callback=function() end })
EspP:AddToggle("PlayerChams",   { Text="Chams (Highlight)",    Default=false,
    Callback=function(v)
        if not v then
            for _, c in pairs(plESP) do
                if c.HL then pcall(function() c.HL:Destroy() end); c.HL=nil end
            end
        end
    end,
})
EspP:AddToggle("PlayerRainbow", { Text="Rainbow ESP", Default=false, Callback=function() end })

-- ===== MISC - MOVEMENT =====
local MvGrp  = T.Misc:AddLeftGroupbox("Движение")
local FlyGrp = T.Misc:AddRightGroupbox("Fly & NoClip")

MvGrp:AddToggle("SpeedWalkT", {
    Text="WalkSpeed", Default=false,
    Callback=function(v)
        Cfg.SpeedWalk=v
        if not v then local h=GetMyHum(); if h then h.WalkSpeed=16 end end
    end,
}):AddKeyPicker("SpeedKey", { Default="None", SyncToggleState=true, Mode="Toggle", Text="WalkSpeed" })
MvGrp:AddSlider("SpeedVal", { Text="Скорость", Default=50, Min=16, Max=300, Rounding=0, Callback=function(v) Cfg.SpeedVal=v end })
MvGrp:AddToggle("InfJumpT", { Text="Infinite Jump", Default=false, Callback=function(v) Cfg.InfJump=v end })
:AddKeyPicker("JumpKey", { Default="None", SyncToggleState=true, Mode="Toggle", Text="Inf Jump" })

FlyGrp:AddToggle("FlyT", {
    Text="Полёт", Default=false,
    Callback=function(v)
        Cfg.Fly=v
        if not v then KillFly(); task.defer(function() local h=GetMyHum(); if h then h.PlatformStand=false end end) end
    end,
}):AddKeyPicker("FlyKey", { Default="None", SyncToggleState=true, Mode="Toggle", Text="Fly" })
FlyGrp:AddSlider("FlySpd", { Text="Скорость полёта", Default=80, Min=20, Max=300, Rounding=0, Callback=function(v) Cfg.FlySpeed=v end })
FlyGrp:AddToggle("NoClipT", {
    Text="NoClip", Default=false,
    Callback=function(v)
        Cfg.NoClip=v
        if not v and LP.Character then
            for _, p in ipairs(LP.Character:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide=true end
            end
        end
    end,
}):AddKeyPicker("NcKey", { Default="None", SyncToggleState=true, Mode="Toggle", Text="NoClip" })

-- ===== MISC - HITBOX & TP =====
local HBGrp = T.Misc:AddLeftGroupbox("BigFish Hitbox")
local TpGrp = T.Misc:AddLeftGroupbox("Teleport")

HBGrp:AddToggle("FishHBT", {
    Text="BigFish Hitbox", Default=false,
    Callback=function(v) Cfg.FishHitbox.Enabled=v; RefreshFishHB() end,
})
HBGrp:AddSlider("FishHBSz", {
    Text="Размер", Default=25, Min=5, Max=100, Rounding=0,
    Callback=function(v) Cfg.FishHitbox.Size=Vector3.new(v,v,v); if Cfg.FishHitbox.Enabled then RefreshFishHB() end end,
})
HBGrp:AddSlider("FishHBTr", {
    Text="Прозрачность", Default=0.7, Min=0, Max=1, Rounding=2,
    Callback=function(v) Cfg.FishHitbox.Transparency=v; if Cfg.FishHitbox.Enabled then RefreshFishHB() end end,
})

TpGrp:AddButton("ТП на плот", function()
    if not TPToPlot() then Library:Notify("Плот не найден!", 3) end
end)
TpGrp:AddButton("ТП к продавцу", function()
    local sp = WS:FindFirstChild("Map")
        and WS.Map:FindFirstChild("Structures")
        and WS.Map.Structures:FindFirstChild("Nova_Sellary")
        and WS.Map.Structures.Nova_Sellary:FindFirstChild("TalkPart")
    if sp then
        TPTo(sp.CFrame + Vector3.new(0,3,0)); Library:Notify("ТП к Nova_Sellary", 2)
    else
        Library:Notify("Sellary не найден!", 3)
    end
end)

-- ===== WAYPOINTS (общие) =====
local WpGrp = T.Misc:AddRightGroupbox("Waypoints")

local NPN = ""
WpGrp:AddInput("WpName", {
    Default="", Numeric=false, Finished=false, Text="Имя точки", Placeholder="Название...",
    Callback=function(v) NPN=v end,
})

local WpDD = WpGrp:AddDropdown("WpDD", {
    Values={}, Default=1, Multi=false, Text="Сохранённые точки",
    Callback=function() end,
})

local SelWp = nil
WpDD:OnChanged(function(v) SelWp=v end)

local function RefWpDD()
    local ns = {}
    for n in pairs(Cfg.Waypoints) do table.insert(ns, n) end
    table.sort(ns)
    WpDD:SetValues(ns)
    -- также обновляем дропдауны collect
    CollectFromDD:SetValues(ns)
    CollectToDD:SetValues(ns)
    if #ns > 0 then SelWp = ns[1] end
end

WpGrp:AddButton("Сохранить точку", function()
    local r = GetMyRoot()
    if r and NPN ~= "" then
        Cfg.Waypoints[NPN] = r.CFrame
        SaveCustomData()
        Library:Notify("Сохранено: " .. NPN, 3)
        RefWpDD()
    else
        Library:Notify("Введите имя!", 3)
    end
end)
WpGrp:AddButton("ТП к точке", function()
    if SelWp and Cfg.Waypoints[SelWp] then
        TPTo(Cfg.Waypoints[SelWp]); Library:Notify("ТП: " .. SelWp, 2)
    else
        Library:Notify("Выберите точку!", 3)
    end
end)
WpGrp:AddButton("Удалить точку", function()
    if SelWp and Cfg.Waypoints[SelWp] then
        Cfg.Waypoints[SelWp] = nil
        SaveCustomData()
        Library:Notify("Удалено: " .. SelWp, 3)
        RefWpDD(); SelWp = nil
    else
        Library:Notify("Выберите точку!", 3)
    end
end)

-- ===== SETTINGS =====
local SetGrp = T.Settings:AddLeftGroupbox("Меню")
SetGrp:AddLabel("Keybind:")
:AddKeyPicker("MenuKey", {
    Default="RightShift", NoUI=true, Text="Menu",
    Callback=function() Library:Toggle() end,
})
SetGrp:AddButton("Unload Script", function() Library:Unload() end)
SetGrp:AddButton("Сохранить данные", function()
    SaveCustomData()
    Library:Notify("Данные сохранены!", 3)
end)
SetGrp:AddButton("Перезагрузить данные", function()
    LoadCustomData()
    RefWpDD()
    Library:Notify("Данные загружены!", 3)
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()

if SaveManager.BuildConfigbox then
    SaveManager:BuildConfigbox(T.Settings)
elseif SaveManager.BuildConfigSection then
    SaveManager:BuildConfigSection(T.Settings)
elseif SaveManager.BuildConfigBox then
    SaveManager:BuildConfigBox(T.Settings)
end

if ThemeManager.ApplyToTab then
    ThemeManager:ApplyToTab(T.Settings)
end

-- ==================== ДРОПДАУН SCAN ====================
local function ScanDD(folderName, dd)
    local function fnd(n)
        if WS:FindFirstChild(n) then return WS[n] end
        local ws = WS:FindFirstChild("WorldSpawn")
        return ws and ws:FindFirstChild(n)
    end
    local map = {}; local lst = {}
    local folder = fnd(folderName)
    if folder then
        local function proc(it)
            if isDeco(it.Name) then return end
            if not map[it.Name] then
                map[it.Name] = true; table.insert(lst, it.Name)
            end
        end
        for _, it in ipairs(folder:GetChildren()) do proc(it) end
        folder.ChildAdded:Connect(function(ni)
            task.wait(0.1)
            if not isDeco(ni.Name) and not map[ni.Name] then
                map[ni.Name] = true; table.insert(lst, ni.Name)
                table.sort(lst); dd:SetValues(lst)
            end
        end)
    end
    table.sort(lst); dd:SetValues(lst)
end

task.spawn(function()
    task.wait(1.5)
    ScanDD("Grab", ItemDD)
    ScanDD("Ores", OreDD)
    ScanDD("Trees", TreeDD)
end)

-- Обновляем waypoint дропдауны после загрузки
task.spawn(function()
    task.wait(0.5)
    RefWpDD()
end)

Library:Notify("Lunar Hub | RC2 loaded!", 5)

-- ==================== UNLOAD ====================
Library:OnUnload(function()
    StopFish(); StopFarm(); StopCollect()
    KillFly(); KillPlatform()
    for _, e in pairs(worldESP) do pcall(function() e.Text:Remove() end) end
    for _, h in ipairs(HLPool) do h.Enabled=false; h.Adornee=nil; pcall(function() h:Destroy() end) end
    for p in pairs(plESP) do CleanPlESP(p) end
    local h = GetMyHum()
    if h then h.WalkSpeed=16; h.PlatformStand=false end
    SaveCustomData()
end)
