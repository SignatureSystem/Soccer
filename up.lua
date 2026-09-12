-- Simple Auto Upgrade Spam
-- One button: toggles ON/OFF
-- Every 1 second: upgrade ALL placed stands in your base (no filters)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local enabled = false
local INTERVAL = 1.0

-- GUI
pcall(function()
    local old = PG:FindFirstChild("UpgradeSpamGui")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "UpgradeSpamGui"
gui.ResetOnSpawn = false
gui.Parent = PG

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 90)
frame.Position = UDim2.new(0, 16, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -20, 0, 40)
btn.Position = UDim2.new(0, 10, 0, 10)
btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
btn.BorderSizePixel = 0
btn.Text = "Upgrade Spam: OFF"
btn.TextColor3 = Color3.fromRGB(255, 90, 90)
btn.TextSize = 14
btn.Font = Enum.Font.GothamBold
btn.Parent = frame
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 28)
status.Position = UDim2.new(0, 8, 0, 54)
status.BackgroundTransparency = 1
status.Text = "Idle"
status.TextColor3 = Color3.fromRGB(180, 190, 210)
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextWrapped = true
status.Parent = frame

local function setOn(on)
    enabled = on
    if on then
        btn.Text = "Upgrade Spam: ON"
        btn.TextColor3 = Color3.fromRGB(80, 255, 120)
        btn.BackgroundColor3 = Color3.fromRGB(28, 52, 36)
        status.Text = "Spamming all slots every 1s..."
    else
        btn.Text = "Upgrade Spam: OFF"
        btn.TextColor3 = Color3.fromRGB(255, 90, 90)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
        status.Text = "Idle"
    end
end

btn.MouseButton1Click:Connect(function()
    setOn(not enabled)
end)

--------------------------------------------------
-- Resolve "Upgrade Slime"
--------------------------------------------------
local upgradeRemote
local upgradeChannel

local function resolveUpgrade()
    -- Preferred: game registry
    local _Lib = rawget(_G, "_Lib")
    if _Lib and _Lib.GameRemoteRegistry and typeof(_Lib.GameRemoteRegistry.new) == "function" then
        local ok, ch = pcall(function()
            return _Lib.GameRemoteRegistry.new("Upgrade Slime", "RemoteEvent")
        end)
        if ok and ch and typeof(ch.Fire) == "function" then
            upgradeChannel = ch
            return true
        end
    end
    if _Lib and _Lib.Network and typeof(_Lib.Network.new) == "function" then
        local ok, ch = pcall(function()
            return _Lib.Network.new("Upgrade Slime", "RemoteEvent")
        end)
        if ok and ch and typeof(ch.Fire) == "function" then
            upgradeChannel = ch
            return true
        end
    end

    if upgradeRemote and upgradeRemote.Parent and upgradeRemote:IsA("RemoteEvent") then
        return true
    end
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name == "Upgrade Slime" then
            upgradeRemote = v
            return true
        end
    end
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and string.find(string.lower(v.Name), "upgrade slime", 1, true) then
            upgradeRemote = v
            return true
        end
    end
    return false
end

local function fireUpgrade(slotName)
    slotName = tostring(slotName)
    if upgradeChannel and typeof(upgradeChannel.Fire) == "function" then
        local ok = pcall(function()
            upgradeChannel:Fire(slotName)
        end)
        if ok then return true end
        upgradeChannel = nil
    end
    if not resolveUpgrade() then
        return false
    end
    if upgradeChannel and typeof(upgradeChannel.Fire) == "function" then
        return pcall(function()
            upgradeChannel:Fire(slotName)
        end)
    end
    if upgradeRemote then
        return pcall(function()
            upgradeRemote:FireServer(slotName)
        end)
    end
    return false
end

--------------------------------------------------
-- Player data (PlotSlimes)
--------------------------------------------------
local function getData()
    local _Lib = rawget(_G, "_Lib")
    if _Lib and _Lib.Data then
        local d = _Lib.Data
        if type(d) == "table" and (d.PlotSlimes or d.Inventory) then
            return d
        end
    end
    -- RemoteFunction fallback
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteFunction") and (v.Name == "Data: Get" or v.Name == "GetData") then
            local ok, data = pcall(function()
                return v:InvokeServer()
            end)
            if ok and type(data) == "table" then
                return data
            end
        end
    end
    return nil
end

local function getMyPlot()
    if rawget(_G, "MyPlot") and _G.MyPlot then
        return _G.MyPlot
    end
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local o = plot:FindFirstChild("owner") or plot:FindFirstChild("Owner")
        if o and tostring(o.Value) == LP.Name then
            return plot
        end
    end
    return nil
end

local function getAllSlots()
    local slots, seen = {}, {}
    local function add(name)
        name = tostring(name)
        if name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(slots, name)
        end
    end

    local data = getData()
    if data and type(data.PlotSlimes) == "table" then
        for slotName, entry in pairs(data.PlotSlimes) do
            if entry ~= nil then
                add(slotName)
            end
        end
    end

    -- Fallback: every stand under your plot
    if #slots == 0 then
        local plot = getMyPlot()
        local stands = plot and plot:FindFirstChild("Stands")
        if stands then
            for _, stand in ipairs(stands:GetChildren()) do
                if stand:IsA("Model") or stand:IsA("Folder") then
                    add(stand.Name)
                end
            end
        end
    end

    table.sort(slots, function(a, b)
        local an, bn = tonumber(a), tonumber(b)
        if an and bn then return an < bn end
        if an then return true end
        if bn then return false end
        return a < b
    end)
    return slots
end

--------------------------------------------------
-- Loop: every 1s spam upgrade on all slots
--------------------------------------------------
task.spawn(function()
    while true do
        if enabled then
            resolveUpgrade()
            local slots = getAllSlots()
            if #slots == 0 then
                status.Text = "No placed slots found"
            else
                local fired = 0
                for _, slot in ipairs(slots) do
                    if not enabled then break end
                    if fireUpgrade(slot) then
                        fired += 1
                    end
                end
                status.Text = string.format("Upgraded %d / %d slots", fired, #slots)
            end
        end
        task.wait(INTERVAL)
    end
end)

print("[UpgradeSpam] Loaded — toggle the button to spam Upgrade Slime on all base slots every 1s")
