-- Simple Auto Upgrade v3
-- Server->client echo Cobalt saw:
--   OnClientEvent(slot, uid, level)
-- Live client request from CharacterBulkUpgradeController:
--   FireServer(slot, mode, uid, level)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer
local DELAY = 0.28

local function hui()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    return LP:FindFirstChild("PlayerGui") or CoreGui
end

pcall(function()
    local p = hui()
    local old = p and p:FindFirstChild("SimpleAutoUpgrade")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "SimpleAutoUpgrade"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(gui) end
end)
gui.Parent = hui()

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(240, 90)
frame.Position = UDim2.new(0, 16, 0.45, 0)
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
status.Size = UDim2.new(1, -16, 0, 32)
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
local remote

local function say(t) status.Text = tostring(t) end

local function getRemote()
    if remote and remote.Parent then return remote end
    local ok, ev = pcall(function()
        return RS.SharedModules.Network.Remotes["Upgrade Slime"]
    end)
    if ok and ev then
        remote = ev
        return ev
    end
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name == "Upgrade Slime" then
            remote = v
            return v
        end
    end
    return nil
end

local function getData()
    local L = rawget(_G, "_Lib")
    if L and L.Data then
        local ok, data = pcall(function() return L.Data:Get() end)
        if ok and type(data) == "table" then return data end
    end
    return nil
end

local function liveFolder()
    local a = workspace:FindFirstChild("Live")
    a = a and a:FindFirstChild("PlayerSlimes")
    return a and a:FindFirstChild(LP.Name)
end

local function catalog(id)
    local L = rawget(_G, "_Lib")
    local cat = L and L.SoccerGameCatalog and L.SoccerGameCatalog.SoccerPlayerCatalog
    if type(cat) == "table" then
        return cat[id] or cat[tostring(id)] or cat[tonumber(id)]
    end
end

local function slots()
    local list, seen = {}, {}
    local function add(name, uid, level, id)
        name = tostring(name)
        if name == "" or seen[name] then return end
        seen[name] = true
        table.insert(list, {name = name, uid = uid, level = tonumber(level) or 1, id = id})
    end
    local data = getData()
    if data and type(data.PlotSlimes) == "table" then
        for k, e in pairs(data.PlotSlimes) do
            if type(e) == "table" then
                add(k, e.uid or e.UID, e.level or e.Level, e.id or e.Id)
            end
        end
    end
    local folder = liveFolder()
    if folder then
        for _, m in ipairs(folder:GetChildren()) do
            add(
                m.Name,
                m:GetAttribute("slimeUid") or m:GetAttribute("slimeUID"),
                m:GetAttribute("level"),
                m:GetAttribute("slimeId")
            )
        end
    end
    table.sort(list, function(a, b)
        local na, nb = tonumber(a.name), tonumber(b.name)
        if na and nb then return na < nb end
        return a.name < b.name
    end)
    return list
end

local function fireOne(info)
    local ev = getRemote()
    if not ev then return false, "no remote" end
    if info.uid == nil then return false, "no uid" end
    local def = catalog(info.id)
    if def and def.Type == "Lucky Block" then return false, "lucky" end

    local slot = tonumber(info.name) or info.name
    local uid = info.uid
    local lv = info.level

    -- 4-arg live Request()
    pcall(function() ev:FireServer(slot, 1, uid, lv) end)
    -- 3-arg shape Cobalt captured on the echo
    pcall(function() ev:FireServer(slot, uid, lv) end)
    -- string slot variants
    pcall(function() ev:FireServer(tostring(slot), 1, uid, lv) end)
    pcall(function() ev:FireServer(tostring(slot), uid, lv) end)

    local L = rawget(_G, "_Lib")
    if L and L.GameRemoteRegistry then
        pcall(function()
            L.GameRemoteRegistry.new("Upgrade Slime", "RemoteEvent"):Fire(slot, 1, uid, lv)
        end)
    end
    return true
end

btn.MouseButton1Click:Connect(function()
    on = not on
    btn.Text = on and "Auto Upgrade: ON" or "Auto Upgrade: OFF"
    btn.TextColor3 = on and Color3.fromRGB(90, 255, 140) or Color3.fromRGB(255, 110, 110)
    btn.BackgroundColor3 = on and Color3.fromRGB(28, 55, 38) or Color3.fromRGB(45, 32, 36)
    say(on and "Running" or "Stopped")
end)

task.spawn(function()
    local t = os.clock()
    while not getRemote() and os.clock() - t < 20 do
        say("Finding Upgrade Slime...")
        task.wait(0.3)
    end
    say(getRemote() and "Ready" or "Upgrade Slime missing")
end)

task.spawn(function()
    while true do
        if on then
            local list = slots()
            if #list == 0 then
                say("No placed players")
                task.wait(0.5)
            else
                local i = 1
                while i <= #list and on do
                    local info = list[i]
                    local ok, err = fireOne(info)
                    if ok then
                        say(string.format("%d/%d slot %s lv %d", i, #list, info.name, info.level))
                    else
                        say(string.format("%d/%d %s: %s", i, #list, info.name, tostring(err)))
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
