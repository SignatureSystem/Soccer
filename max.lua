-- Auto MAX Upgrade (Correct packet)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

local DELAY = 1

-- Force remove old GUI
pcall(function()
    for _, v in pairs(CoreGui:GetChildren()) do
        if v.Name == "SimpleAutoUpgrade" then v:Destroy() end
    end
    if LP:FindFirstChild("PlayerGui") then
        for _, v in pairs(LP.PlayerGui:GetChildren()) do
            if v.Name == "SimpleAutoUpgrade" then v:Destroy() end
        end
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "SimpleAutoUpgrade"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(gui)
    elseif gethui then
        gui.Parent = gethui()
        return
    end
end)

gui.Parent = CoreGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(220, 80)
frame.Position = UDim2.new(0.5, -110, 0.75, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 80, 90)
stroke.Thickness = 2
stroke.Parent = frame

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -16, 0, 40)
btn.Position = UDim2.new(0, 8, 0, 8)
btn.BackgroundColor3 = Color3.fromRGB(50, 30, 35)
btn.Text = "MAX Upgrade: OFF"
btn.TextColor3 = Color3.fromRGB(255, 100, 100)
btn.TextSize = 16
btn.Font = Enum.Font.GothamBold
btn.Parent = frame

Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 22)
status.Position = UDim2.new(0, 8, 0, 52)
status.BackgroundTransparency = 1
status.Text = "Loading..."
status.TextColor3 = Color3.fromRGB(180, 180, 190)
status.TextSize = 12
status.Font = Enum.Font.Gotham
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
    return nil
end

local function findRawRemote()
    if cachedRemote and cachedRemote.Parent then return cachedRemote end
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

local function liveFolder()
    local live = workspace:FindFirstChild("Live")
    local folder = live and live:FindFirstChild("PlayerSlimes")
    return folder and folder:FindFirstChild(LP.Name)
end

local function readEntry(slotName)
    local data = getData()
    local ps = data and data.PlotSlimes
    local entry = type(ps) == "table" and (ps[slotName] or ps[tonumber(slotName)] or ps[tostring(slotName)])
    
    local uid, level
    if type(entry) == "table" then
        uid = entry.uid or entry.UID
        level = tonumber(entry.level or entry.Level)
    end

    local folder = liveFolder()
    local model = folder and folder:FindFirstChild(tostring(slotName))
    if model then
        uid = uid or model:GetAttribute("slimeUid") or model:GetAttribute("slimeUID")
        level = level or tonumber(model:GetAttribute("level"))
    end

    return uid, tonumber(level) or 1
end

local function fireMax(slotName)
    local uid, level = readEntry(slotName)
    if not uid then return false end

    slotName = tostring(slotName)

    -- Correct packet: slot, "Max", uid, level
    local ch = getChannel()
    if ch then
        pcall(function()
            ch:Fire(slotName, "Max", uid, level)
        end)
    end

    local raw = findRawRemote()
    if raw then
        pcall(function()
            raw:FireServer(slotName, "Max", uid, level)
        end)
    end

    return true
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
        for _, m in ipairs(folder:GetChildren()) do
            add(m.Name)
        end
    end

    return out
end

btn.MouseButton1Click:Connect(function()
    on = not on
    if on then
        btn.Text = "MAX Upgrade: ON"
        btn.TextColor3 = Color3.fromRGB(100, 255, 140)
        btn.BackgroundColor3 = Color3.fromRGB(30, 60, 40)
        setStatus("Running MAX...")
    else
        btn.Text = "MAX Upgrade: OFF"
        btn.TextColor3 = Color3.fromRGB(255, 100, 100)
        btn.BackgroundColor3 = Color3.fromRGB(50, 30, 35)
        setStatus("Stopped")
    end
end)

task.spawn(function()
    task.wait(1)
    setStatus("Ready")
end)

task.spawn(function()
    while true do
        if on then
            local slots = listSlots()
            if #slots > 0 then
                for _, name in ipairs(slots) do
                    task.spawn(function()
                        fireMax(name)
                    end)
                end
                setStatus("MAX fired on " .. #slots .. " slots")
            else
                setStatus("No slots found")
            end
            task.wait(DELAY)
        else
            task.wait(0.2)
        end
    end
end)
