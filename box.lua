-- ICONIC BOX COLLECTOR - BOOT DIAGNOSTIC
-- UI MUST APPEAR IMMEDIATELY

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- Remove old logger
pcall(function()
    CoreGui.IconicCollectorDebug:Destroy()
end)

-- =========================================================
-- UI FIRST
-- =========================================================

local gui = Instance.new("ScreenGui")
gui.Name = "IconicCollectorDebug"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local parentSuccess = pcall(function()
    gui.Parent = CoreGui
end)

if not parentSuccess then
    gui.Parent = player:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame")
frame.Parent = gui
frame.Size = UDim2.new(0, 420, 0, 260)
frame.Position = UDim2.new(0, 20, 0, 100)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frame.BorderSizePixel = 0

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Parent = frame
title.Size = UDim2.new(1, -20, 0, 35)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.Text = "ICONIC COLLECTOR DEBUG"
title.TextColor3 = Color3.fromRGB(255, 220, 70)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left

local status = Instance.new("TextLabel")
status.Parent = frame
status.Size = UDim2.new(1, -20, 0, 30)
status.Position = UDim2.new(0, 10, 0, 40)
status.BackgroundTransparency = 1
status.Text = "BOOTING..."
status.TextColor3 = Color3.fromRGB(100, 255, 130)
status.TextSize = 16
status.Font = Enum.Font.GothamBold
status.TextXAlignment = Enum.TextXAlignment.Left

local logs = Instance.new("TextLabel")
logs.Parent = frame
logs.Size = UDim2.new(1, -20, 1, -85)
logs.Position = UDim2.new(0, 10, 0, 75)
logs.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
logs.BorderSizePixel = 0
logs.Text = ""
logs.TextColor3 = Color3.fromRGB(235, 235, 235)
logs.TextSize = 13
logs.Font = Enum.Font.Code
logs.TextWrapped = true
logs.TextXAlignment = Enum.TextXAlignment.Left
logs.TextYAlignment = Enum.TextYAlignment.Top

Instance.new("UICorner", logs).CornerRadius = UDim.new(0, 7)

local messages = {}

local function LOG(text)
    text = tostring(text)

    table.insert(messages, text)

    if #messages > 12 then
        table.remove(messages, 1)
    end

    logs.Text = table.concat(messages, "\n")
    print("[ICONIC DEBUG] " .. text)
end

local function STATUS(text)
    status.Text = tostring(text)
    LOG("> " .. tostring(text))
end

STATUS("SCRIPT LAUNCHED")

-- =========================================================
-- BASIC CHECKS
-- =========================================================

task.wait(0.5)

if not player then
    STATUS("ERROR: LocalPlayer missing")
    return
end

LOG("Player: " .. player.Name)

local character = player.Character

if not character then
    STATUS("Waiting for character...")
    character = player.CharacterAdded:Wait()
end

LOG("Character found")

local root = character:FindFirstChild("HumanoidRootPart")

if root then
    LOG("HumanoidRootPart found")
else
    STATUS("ERROR: HumanoidRootPart missing")
    return
end

-- =========================================================
-- CHECK GAME STRUCTURE
-- =========================================================

local live = workspace:FindFirstChild("Live")

if not live then
    STATUS("ERROR: workspace.Live NOT FOUND")
    return
end

LOG("workspace.Live found")

local slimes = live:FindFirstChild("Slimes")

if not slimes then
    STATUS("ERROR: Live.Slimes NOT FOUND")
    return
end

LOG("Live.Slimes found")
LOG("Objects inside Slimes: " .. tostring(#slimes:GetChildren()))

-- =========================================================
-- LIST LUCKY BLOCK NAMES
-- =========================================================

STATUS("Scanning Lucky Blocks...")

local luckyNames = {}
local iconicCount = 0

for _, object in ipairs(slimes:GetChildren()) do
    local lower = string.lower(object.Name)

    if string.find(lower, "lucky")
        or string.find(lower, "icon")
        or string.find(lower, "block") then

        if not luckyNames[object.Name] then
            luckyNames[object.Name] = true
            LOG("Found model name: " .. object.Name)
        end

        if object.Name == "Icons Lucky Block" then
            iconicCount = iconicCount + 1
        end
    end
end

LOG("--------------------")
LOG("Exact 'Icons Lucky Block' count: " .. iconicCount)

if iconicCount > 0 then
    STATUS("ICONIC BOX FOUND - detector works")
else
    STATUS("NO EXACT ICONIC NAME FOUND")
end

-- =========================================================
-- CONTINUOUS WATCH
-- =========================================================

while task.wait(1) do

    local count = 0

    for _, object in ipairs(slimes:GetChildren()) do
        if object.Name == "Icons Lucky Block" then
            count = count + 1
        end
    end

    status.Text =
        "Running | Icons Lucky Block: "
        .. tostring(count)
        .. " | holdingSlime: "
        .. tostring(player:GetAttribute("holdingSlime"))
end