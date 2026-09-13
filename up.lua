-- Simple Auto Upgrade v2
-- Live packet: Upgrade Slime (slotName, 1, uid, level)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

local DELAY = 0.25

local function getHui()
    local ok, h = pcall(function()
        return gethui and gethui()
    end)
    if ok and h then
        return h
    end
    return LP:FindFirstChild("PlayerGui") or CoreGui
end

pcall(function()
    for _, parent in ipairs({getHui(), CoreGui, LP:FindFirstChild("PlayerGui")}) do
        if parent then
            local old = parent:FindFirstChild("SimpleAutoUpgrade")
            if old then old:Destroy() end
        end
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "SimpleAutoUpgrade"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(gui) end
end)
gui.Parent = getHui()

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(230, 86)
frame.Position = UDim2.new(0, 18, 0.45, 0)
frame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -16, 0, 40)
btn.Position = UDim2.new(0, 8, 0, 8)
btn.BackgroundColor3 = Color3.fromRGB(45, 32, 36)
btn.Text = "Auto Upgrade: OFF"
btn.TextColor3 = Color3.fromRGB(255, 110, 110)
btn.TextSize = 15
btn.Font = Enum.Font.GothamBold
btn.Parent = frame
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 28)
status.Position = UDim2.new(0, 8, 0, 50)
status.BackgroundTransparency = 1
status.Text = "Booting..."
status.TextColor3 = Color3.fromRGB(190, 190, 205)
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local on = false
local cachedRemote

local function setStatus(t)
    status.Text = tostring(t)
end

local function lib()
    return rawget(_G, "_Lib")
end

local function getData()
    local L = lib()
    if L and L.Data and type(L.Data.Get) == "function" then
        local ok, data = pcall(function() return L.Data:Get() end)
        if ok and type(data) == "table" then return data end
    end
    local rf = RS:FindFirstChild("Data: Get", true)
    if rf and rf:IsA("RemoteFunction") then
        local ok, data = pcall(function() return rf:InvokeServer() end)
        if ok and type(data) == "table" then return data end
    end
    return nil
end

local function getCatalog(id)
    local L = lib()
    if not L or id == nil then return nil end
    local cat = L.SoccerGameCatalog and L.SoccerGameCatalog.SoccerPlayerCatalog
    if type(cat) == "table" then
        return cat[id] or cat[tostring(id)] or cat[tonumber(id)]
    end
    return nil
end

local function findRawRemote()
    if cachedRemote and cachedRemote.Parent then return cachedRemote end
    local net = RS:FindFirstChild("SharedModules")
    net = net and net:FindFirstChild("Network")
    local remotes = net and net:FindFirstChild("Remotes")
    if remotes then
        local v = remotes:FindFirstChild("Upgrade Slime")
        if v and v:IsA("RemoteEvent") then
            cachedRemote = v
            return v
        end
    end
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") and string.lower(v.Name) == "upgrade slime" then
            cachedRemote = v
            return v
        end
    end
    return nil
end

local function getChannel()
    local L = lib()
    if L and L.GameRemoteRegistry and type(L.GameRemoteRegistry.new) == "function" then
        local ok, ch = pcall(function()
            return L.GameRemoteRegistry.new("Upgrade Slime", "RemoteEvent")
        end)
        if ok and ch and type(ch.Fire) == "function" then return ch end
    end
    return nil
end

local function plot()
    if rawget(_G, "MyPlot") and _G.MyPlot.Parent then return _G.MyPlot end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, p in ipairs(plots:GetChildren()) do
        local owner = p:FindFirstChild("owner")
        if owner and tostring(owner.Value) == LP.Name then return p end
    end
    return nil
end

local function liveFolder()
    local live = workspace:FindFirstChild("Live")
    local folder = live and live:FindFirstChild("PlayerSlimes")
    return folder and folder:FindFirstChild(LP.Name)
end

local function readEntry(slotName)
    local data = getData()
    local ps = data and data.PlotSlimes
    local entry
    if type(ps) == "table" then
        entry = ps[slotName] or ps[tonumber(slotName)] or ps[tostring(slotName)]
    end
    local uid, level, id
    if type(entry) == "table" then
        uid = entry.uid or entry.UID
        level = tonumber(entry.level or entry.Level)
        id = entry.id or entry.Id
    end
    local folder = liveFolder()
    local model = folder and folder:FindFirstChild(tostring(slotName))
    if model then
        uid = uid or model:GetAttribute("slimeUid") or model:GetAttribute("slimeUID")
        level = level or tonumber(model:GetAttribute("level"))
        id = id or model:GetAttribute("slimeId")
    end
    local my = plot()
    local stands = my and my:FindFirstChild("Stands")
    local stand = stands and stands:FindFirstChild(tostring(slotName))
    if stand then
        uid = uid or stand:GetAttribute("slimeUid")
        level = level or tonumber(stand:GetAttribute("level"))
        id = id or stand:GetAttribute("slimeId")
    end
    return uid, tonumber(level) or 1, id
end

local function isLucky(id)
    local def = getCatalog(id)
    return def and tostring(def.Type or "") == "Lucky Block"
end

local function fireSlot(slotName)
    if LP:GetAttribute("OldDataMigrationLocked") == true then
        return false, "migration locked"
    end
    local uid, level, id = readEntry(slotName)
    if isLucky(id) then return false, "lucky" end
    if uid == nil then return false, "no uid" end
    slotName = tostring(slotName)
    local sent = false
    local ch = getChannel()
    if ch then
        sent = pcall(function() ch:Fire(slotName, 1, uid, level) end) or sent
    end
    local raw = findRawRemote()
    if raw then
        sent = pcall(function() raw:FireServer(slotName, 1, uid, level) end) or sent
    end
    if not sent then return false, "no remote" end
    return true, uid, level
end

local function listSlots()
    local out, seen = {}, {}
    local function add(name)
        name = tostring(name)
        if name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(out, name)
        end
    end
    local data = getData()
    if data and type(data.PlotSlimes) == "table" then
        for k, v in pairs(data.PlotSlimes) do
            if type(v) == "table" then add(k) end
        end
    end
    local folder = liveFolder()
    if folder then
        for _, m in ipairs(folder:GetChildren()) do add(m.Name) end
    end
    local my = plot()
    local stands = my and my:FindFirstChild("Stands")
    if stands and #out == 0 then
        for _, s in ipairs(stands:GetChildren()) do
            if s:IsA("Model") and (s:GetAttribute("slimeUid") or s:GetAttribute("level")) then
                add(s.Name)
            end
        end
    end
    table.sort(out, function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then return na < nb end
        return a < b
    end)
    return out
end

btn.MouseButton1Click:Connect(function()
    on = not on
    if on then
        btn.Text = "Auto Upgrade: ON"
        btn.TextColor3 = Color3.fromRGB(90, 255, 140)
        btn.BackgroundColor3 = Color3.fromRGB(28, 55, 38)
        setStatus("Running")
    else
        btn.Text = "Auto Upgrade: OFF"
        btn.TextColor3 = Color3.fromRGB(255, 110, 110)
        btn.BackgroundColor3 = Color3.fromRGB(45, 32, 36)
        setStatus("Stopped")
    end
end)

task.spawn(function()
    local t0 = os.clock()
    while rawget(_G, "_loaded") ~= true and os.clock() - t0 < 45 do
        setStatus(string.format("Wait game load %.0fs", os.clock() - t0))
        task.wait(0.3)
    end
    local t1 = os.clock()
    while not lib() and os.clock() - t1 < 20 do
        setStatus("Wait _G._Lib...")
        task.wait(0.3)
    end
    local raw = findRawRemote()
    setStatus(string.format("Ready | lib=%s remote=%s", lib() and "yes" or "no", raw and raw.Name or "missing"))
end)

task.spawn(function()
    while true do
        if on then
            local slots = listSlots()
            if #slots == 0 then
                setStatus("No placed players found")
                task.wait(0.5)
            else
                local i = 1
                while i <= #slots and on do
                    local name = slots[i]
                    local ok, a, b = fireSlot(name)
                    if ok then
                        setStatus(string.format("%d/%d slot %s lv %s", i, #slots, name, tostring(b)))
                    else
                        setStatus(string.format("%d/%d slot %s: %s", i, #slots, name, tostring(a)))
                    end
                    task.wait(DELAY)
                    i = i + 1
                end
            end
        else
            task.wait(0.15)
        end
    end
end)
