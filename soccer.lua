-- Combined Script: Auto Collect + Auto Upgrade + Lucky Block (OG) + Rebirth + Jump
-- + Pick Floor 1 / ALL / by Rarity|Mutation + Place (value desc) + Boxes + Invis
-- ONLY OG for Upgrade + Lucky Block Steal

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

-- ============================================
-- CONFIG
-- ============================================
local COLLECT_INTERVAL = 0.35
local COLLECT_SCAN = 1.5
local ONLY_WHEN_PADGUI_ENABLED = true

local UPGRADE_DELAY = 0.25
local UPGRADE_SCAN = 1.0
local MAX_LEVEL = 100

local REBIRTH_INTERVAL = 5
local JUMP_UPGRADE_INTERVAL = 0.5
local BOXES_AUTO_INTERVAL = 30
local INVIS_REFRESH = 2.5

local DELAY_EQUIP = 0.12
local DELAY_PLACE = 0.22
local DELAY_OPEN  = 0.30
local DELAY_NEXT  = 0.12
local DELAY_PICK  = 0.12
local IGNORE_LOCK = true

local UPGRADE_PRIORITY = { ["OG"] = 1 }
local TARGET_RARITIES  = { ["OG"] = true }

local RARITY_VALUE = {
    ["Spain"] = 2500000, ["Champions"] = 1000000, ["OG"] = 500000,
    ["Exclusive"] = 75000, ["LIMITED"] = 75000, ["Divine"] = 50000,
    ["Slime God"] = 30000, ["Secret"] = 10000, ["Mythic"] = 2500,
    ["Legendary"] = 750, ["Epic"] = 250, ["Rare"] = 100, ["Common"] = 25,
}

-- From game RarityOrders + MUTATION_MULTIPLIERS
local ALL_RARITIES = {
    "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret",
    "Slime God", "Divine", "Exclusive", "LIMITED", "OG", "Champions", "Spain",
}
local ALL_MUTATIONS = {
    "Golden", "Diamond", "Rainbow", "Cursed", "Volcanic", "Toxic", "Taco", "Cosmic", "Slimey",
}
local PICK_OPTIONS = {}
for _, r in ipairs(ALL_RARITIES) do table.insert(PICK_OPTIONS, r) end
for _, m in ipairs(ALL_MUTATIONS) do table.insert(PICK_OPTIONS, m) end

-- ============================================
-- GUI
-- ============================================
pcall(function()
    local old = PlayerGui and PlayerGui:FindFirstChild("AutoFarmGui")
    if old then old:Destroy() end
    old = CoreGui:FindFirstChild("AutoFarmGui")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoFarmGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.IgnoreGuiInset = true
pcall(function() ScreenGui.Parent = PlayerGui or CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = CoreGui end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 250, 0, 720)
MainFrame.Position = UDim2.new(0, 20, 0.5, -360)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BackgroundTransparency = 0.05
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local mainStroke = Instance.new("UIStroke", MainFrame)
mainStroke.Color = Color3.fromRGB(80, 80, 100)
mainStroke.Thickness = 2

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 28)
Title.BackgroundTransparency = 1
Title.Text = "Auto Farm Control"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local function createButton(name, y, text)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 220, 0, 32)
    btn.Position = UDim2.new(0, 15, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 90, 90)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Parent = MainFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local s = Instance.new("UIStroke", btn)
    s.Color = Color3.fromRGB(70, 70, 85)
    s.Thickness = 1.5
    return btn
end

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0, 230, 0, 48)
StatusLabel.Position = UDim2.new(0, 10, 0, 665)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Loading..."
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.TextWrapped = true
StatusLabel.Parent = MainFrame

local CollectBtn   = createButton("CollectToggle", 32, "Auto Collect: OFF")
local UpgradeBtn   = createButton("UpgradeToggle", 68, "Auto Upgrade: OFF")
local LuckyBtn     = createButton("LuckyToggle", 104, "Lucky Block: OFF")
local RebirthBtn   = createButton("RebirthToggle", 140, "Auto Rebirth: OFF")
local JumpBtn      = createButton("JumpToggle", 176, "Auto +10 Jump: OFF")
local BoxesAutoBtn = createButton("BoxesAutoToggle", 212, "Auto Place+Open Boxes: OFF")
local InvisBtn     = createButton("InvisToggle", 248, "Invis Cloak: OFF")

local PickupBtn    = createButton("PickupBtn", 292, "Pick Up Floor 1 (1-10)")
local PickupAllBtn = createButton("PickupAllBtn", 328, "Pick Up ALL Floors")
local PlaceBtn     = createButton("PlaceBtn", 364, "Place All (highest value first)")
local BoxesBtn     = createButton("BoxesBtn", 400, "Place + Open All Boxes (Once)")

-- Rarity / Mutation dropdown row
local RarityLabel = Instance.new("TextLabel")
RarityLabel.Size = UDim2.new(0, 220, 0, 16)
RarityLabel.Position = UDim2.new(0, 15, 0, 440)
RarityLabel.BackgroundTransparency = 1
RarityLabel.Text = "Pick by Rarity / Mutation:"
RarityLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
RarityLabel.TextSize = 11
RarityLabel.Font = Enum.Font.Gotham
RarityLabel.TextXAlignment = Enum.TextXAlignment.Left
RarityLabel.Parent = MainFrame

local selectedPickOption = "OG"
local DropBtn = Instance.new("TextButton")
DropBtn.Name = "RarityDrop"
DropBtn.Size = UDim2.new(0, 140, 0, 30)
DropBtn.Position = UDim2.new(0, 15, 0, 458)
DropBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
DropBtn.BorderSizePixel = 0
DropBtn.Text = "▼  " .. selectedPickOption
DropBtn.TextColor3 = Color3.fromRGB(220, 220, 255)
DropBtn.TextSize = 12
DropBtn.Font = Enum.Font.GothamBold
DropBtn.Parent = MainFrame
Instance.new("UICorner", DropBtn).CornerRadius = UDim.new(0, 6)

local PickRarityBtn = Instance.new("TextButton")
PickRarityBtn.Name = "PickRarityBtn"
PickRarityBtn.Size = UDim2.new(0, 72, 0, 30)
PickRarityBtn.Position = UDim2.new(0, 163, 0, 458)
PickRarityBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 80)
PickRarityBtn.BorderSizePixel = 0
PickRarityBtn.Text = "Pick"
PickRarityBtn.TextColor3 = Color3.fromRGB(200, 170, 255)
PickRarityBtn.TextSize = 12
PickRarityBtn.Font = Enum.Font.GothamBold
PickRarityBtn.Parent = MainFrame
Instance.new("UICorner", PickRarityBtn).CornerRadius = UDim.new(0, 6)

-- Dropdown list (hidden by default)
local DropList = Instance.new("ScrollingFrame")
DropList.Name = "DropList"
DropList.Size = UDim2.new(0, 220, 0, 150)
DropList.Position = UDim2.new(0, 15, 0, 492)
DropList.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
DropList.BorderSizePixel = 0
DropList.Visible = false
DropList.ScrollBarThickness = 4
DropList.CanvasSize = UDim2.new(0, 0, 0, #PICK_OPTIONS * 26)
DropList.ZIndex = 20
DropList.Parent = MainFrame
Instance.new("UICorner", DropList).CornerRadius = UDim.new(0, 6)

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = DropList

for i, opt in ipairs(PICK_OPTIONS) do
    local item = Instance.new("TextButton")
    item.Size = UDim2.new(1, -4, 0, 24)
    item.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
    item.BorderSizePixel = 0
    item.Text = "  " .. opt
    item.TextColor3 = Color3.fromRGB(220, 220, 230)
    item.TextSize = 12
    item.Font = Enum.Font.Gotham
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.LayoutOrder = i
    item.ZIndex = 21
    item.Parent = DropList
    item.MouseButton1Click:Connect(function()
        selectedPickOption = opt
        DropBtn.Text = "▼  " .. opt
        DropList.Visible = false
    end)
end

DropBtn.MouseButton1Click:Connect(function()
    DropList.Visible = not DropList.Visible
end)

PickupBtn.TextColor3 = Color3.fromRGB(180, 180, 255)
PickupBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
PickupAllBtn.TextColor3 = Color3.fromRGB(200, 160, 255)
PickupAllBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 70)
PlaceBtn.TextColor3 = Color3.fromRGB(120, 220, 150)
PlaceBtn.BackgroundColor3 = Color3.fromRGB(30, 50, 40)
BoxesBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
BoxesBtn.BackgroundColor3 = Color3.fromRGB(55, 40, 20)

print("[AutoFarm] GUI created")

-- ============================================
-- STATE
-- ============================================
local collectEnabled, upgradeEnabled, luckyEnabled = false, false, false
local rebirthEnabled, jumpUpgradeEnabled, boxesAutoEnabled = false, false, false
local invisEnabled = false
local upgradeDebugOnce = true
local totalCollected = 0
local luckyBlockBusy, actionBusy = false, false

local _Lib = nil
local CollectRemote, UpgradeRemote, RebirthRemote, JumpUpgradeRemote
local PlaceRemote, PickupRemote, OpenRemote

local function setCollectState(on)
    collectEnabled = on
    CollectBtn.Text = on and "Auto Collect: ON" or "Auto Collect: OFF"
    CollectBtn.TextColor3 = on and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 90, 90)
    CollectBtn.BackgroundColor3 = on and Color3.fromRGB(30, 55, 40) or Color3.fromRGB(40, 40, 50)
end
local function setUpgradeState(on)
    upgradeEnabled = on
    upgradeDebugOnce = on
    UpgradeBtn.Text = on and "Auto Upgrade: ON" or "Auto Upgrade: OFF"
    UpgradeBtn.TextColor3 = on and Color3.fromRGB(80, 180, 255) or Color3.fromRGB(255, 90, 90)
    UpgradeBtn.BackgroundColor3 = on and Color3.fromRGB(25, 45, 70) or Color3.fromRGB(40, 40, 50)
end
local function setLuckyState(on)
    luckyEnabled = on
    if on then
        totalCollected = 0
        LuckyBtn.Text = "Lucky Block: ON"
        LuckyBtn.TextColor3 = Color3.fromRGB(255, 200, 80)
        LuckyBtn.BackgroundColor3 = Color3.fromRGB(60, 45, 20)
        StatusLabel.Text = "Lucky Block: OG only..."
    else
        LuckyBtn.Text = "Lucky Block: OFF"
        LuckyBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
        LuckyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        luckyBlockBusy = false
    end
end
local function setRebirthState(on)
    rebirthEnabled = on
    RebirthBtn.Text = on and "Auto Rebirth: ON" or "Auto Rebirth: OFF"
    RebirthBtn.TextColor3 = on and Color3.fromRGB(255, 150, 50) or Color3.fromRGB(255, 90, 90)
    RebirthBtn.BackgroundColor3 = on and Color3.fromRGB(70, 45, 15) or Color3.fromRGB(40, 40, 50)
end
local function setJumpUpgradeState(on)
    jumpUpgradeEnabled = on
    JumpBtn.Text = on and "Auto +10 Jump: ON" or "Auto +10 Jump: OFF"
    JumpBtn.TextColor3 = on and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(255, 90, 90)
    JumpBtn.BackgroundColor3 = on and Color3.fromRGB(30, 60, 40) or Color3.fromRGB(40, 40, 50)
end
local function setBoxesAutoState(on)
    boxesAutoEnabled = on
    BoxesAutoBtn.Text = on and "Auto Place+Open Boxes: ON" or "Auto Place+Open Boxes: OFF"
    BoxesAutoBtn.TextColor3 = on and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(255, 90, 90)
    BoxesAutoBtn.BackgroundColor3 = on and Color3.fromRGB(60, 45, 20) or Color3.fromRGB(40, 40, 50)
end
local function setInvisState(on)
    invisEnabled = on
    InvisBtn.Text = on and "Invis Cloak: ON" or "Invis Cloak: OFF"
    InvisBtn.TextColor3 = on and Color3.fromRGB(180, 120, 255) or Color3.fromRGB(255, 90, 90)
    InvisBtn.BackgroundColor3 = on and Color3.fromRGB(45, 30, 70) or Color3.fromRGB(40, 40, 50)
end

CollectBtn.MouseButton1Click:Connect(function() setCollectState(not collectEnabled) end)
UpgradeBtn.MouseButton1Click:Connect(function() setUpgradeState(not upgradeEnabled) end)
LuckyBtn.MouseButton1Click:Connect(function() setLuckyState(not luckyEnabled) end)
RebirthBtn.MouseButton1Click:Connect(function() setRebirthState(not rebirthEnabled) end)
JumpBtn.MouseButton1Click:Connect(function() setJumpUpgradeState(not jumpUpgradeEnabled) end)
BoxesAutoBtn.MouseButton1Click:Connect(function() setBoxesAutoState(not boxesAutoEnabled) end)
InvisBtn.MouseButton1Click:Connect(function() setInvisState(not invisEnabled) end)

-- ============================================
-- REMOTES
-- ============================================
task.spawn(function()
    local start = os.clock()
    while not _G._Lib and (os.clock() - start) < 30 do
        StatusLabel.Text = string.format("Waiting for game... %.0fs", os.clock() - start)
        task.wait(0.5)
    end
    _Lib = _G._Lib
    StatusLabel.Text = _Lib and "Ready" or "WARNING: _G._Lib missing"

    local function findRemote(part)
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") and v.Name:lower():find(part:lower()) then return v end
        end
    end
    local function findExact(name)
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") and v.Name == name then return v end
        end
    end

    CollectRemote     = findRemote("Collect Earnings")
    UpgradeRemote     = findRemote("Upgrade Slime")
    RebirthRemote     = findRemote("Rebirth")
    JumpUpgradeRemote = findRemote("Buy Speed Upgrade")
    PlaceRemote       = findExact("Place Slime")
    PickupRemote      = findExact("Pickup Slime")
    OpenRemote        = findExact("Open Lucky Block")
end)

-- ============================================
-- HELPERS
-- ============================================
local function getCash()
    if _Lib and _Lib.Data then
        local ok, data = pcall(function() return _Lib.Data:Get() end)
        if ok and data and type(data.Cash) == "number" then return data.Cash end
    end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        local c = ls:FindFirstChild("Cash") or ls:FindFirstChild("Money")
        if c then return c.Value end
    end
    return 0
end

local function getJumpData()
    if _Lib and _Lib.Data then
        local ok, data = pcall(function() return _Lib.Data:Get() end)
        if ok and data and type(data.Jump) == "number" then return data.Jump end
    end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        local j = ls:FindFirstChild("Jumps") or ls:FindFirstChild("Jump")
        if j then return j.Value end
    end
    return 0
end

local function getData()
    if not _Lib or not _Lib.Data then return nil end
    local ok, data = pcall(function() return _Lib.Data:Get() end)
    return ok and data or nil
end

local function getBaseLevel(data)
    data = data or getData()
    if data and type(data.BaseLevel) == "number" then return data.BaseLevel end
    return LocalPlayer:GetAttribute("BaseLevel") or 0
end

local function getMyPlot()
    if _G.MyPlot and _G.MyPlot.Parent then return _G.MyPlot end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:FindFirstChild("owner")
        if owner and tostring(owner.Value) == LocalPlayer.Name then return plot end
    end
end

local function getPlayerSlimesFolder()
    local live = workspace:FindFirstChild("Live")
    local ps = live and live:FindFirstChild("PlayerSlimes")
    return ps and ps:FindFirstChild(LocalPlayer.Name)
end

local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function isUnlocked(slotName, baseLevel)
    if IGNORE_LOCK then return true end
    local n = tonumber(slotName)
    if not n then return true end
    return n <= 10 or (n - 10) <= (baseLevel or 0)
end

local function isOccupied(slotName, plotSlimes, playerSlimesFolder, stand)
    if type(plotSlimes) == "table" then
        if plotSlimes[slotName] or plotSlimes[tostring(slotName)] then return true end
        local n = tonumber(slotName)
        if n and plotSlimes[n] then return true end
    end
    if playerSlimesFolder and playerSlimesFolder:FindFirstChild(tostring(slotName)) then return true end
    if stand then
        local main = stand:FindFirstChild("Main")
        local holder = main and main:FindFirstChild("Holder")
        local pick = holder and holder:FindFirstChild("Pick Up")
        if pick and pick:IsA("ProximityPrompt") and pick.Enabled then return true end
    end
    return false
end

local function isFloor1(slotName)
    local n = tonumber(slotName)
    return n and n >= 1 and n <= 10
end

local function getFloor1OccupiedSlots()
    local data = getData()
    local plotSlimes = (data and data.PlotSlimes) or {}
    local plot = getMyPlot()
    local liveFolder = getPlayerSlimesFolder()
    local list = {}
    if not plot then return list end
    local stands = plot:FindFirstChild("Stands")
    if not stands then return list end
    for _, stand in ipairs(stands:GetChildren()) do
        if isFloor1(stand.Name) and isOccupied(stand.Name, plotSlimes, liveFolder, stand) then
            table.insert(list, { name = stand.Name, num = tonumber(stand.Name) or 0, stand = stand })
        end
    end
    table.sort(list, function(a, b) return a.num < b.num end)
    return list
end

local function getAllOccupiedSlots()
    local data = getData()
    local plotSlimes = (data and data.PlotSlimes) or {}
    local plot = getMyPlot()
    local liveFolder = getPlayerSlimesFolder()
    local list = {}
    if not plot then return list end
    local stands = plot:FindFirstChild("Stands")
    if not stands then return list end
    for _, stand in ipairs(stands:GetChildren()) do
        local name = stand.Name
        if isOccupied(name, plotSlimes, liveFolder, stand) then
            table.insert(list, { name = name, num = tonumber(name) or 9999, stand = stand })
        end
    end
    table.sort(list, function(a, b) return a.num < b.num end)
    return list
end

-- Resolve rarity + mutation for a stand/slot
local function getSlotRarityAndMutation(slotName, stand, plotSlimes, liveFolder)
    local rarity, mutation = nil, nil

    -- 1) PlotSlimes data
    if type(plotSlimes) == "table" then
        local entry = plotSlimes[slotName] or plotSlimes[tostring(slotName)] or plotSlimes[tonumber(slotName)]
        if entry then
            rarity = entry.Rarity or entry.rarity
            mutation = entry.mutation or entry.Mutation
            if not rarity and entry.id and _Lib and _Lib.Database and _Lib.Database.Slimes then
                local def = _Lib.Database.Slimes[entry.id] or _Lib.Database.Slimes[tostring(entry.id)]
                if def then rarity = def.Rarity or def.rarity end
            end
        end
    end

    -- 2) Live model
    local model = liveFolder and (liveFolder:FindFirstChild(tostring(slotName)) or liveFolder:FindFirstChild(slotName))
    if model then
        if not rarity then
            rarity = model:GetAttribute("Rarity") or model:GetAttribute("rarity")
        end
        if not mutation then
            mutation = model:GetAttribute("mutation") or model:GetAttribute("Mutation")
        end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("TextLabel") then
                if d.Name == "Rarity" and d.Text ~= "" and not rarity then
                    local t = d.Text
                    if t == "Player God" then t = "Slime God" end
                    rarity = t
                end
                if (d.Name == "Mutation" or d.Name == "mutation") and d.Text ~= "" and not mutation then
                    mutation = d.Text
                end
            end
        end
    end

    -- 3) Stand attributes
    if stand then
        if not rarity then rarity = stand:GetAttribute("Rarity") or stand:GetAttribute("rarity") end
        if not mutation then mutation = stand:GetAttribute("mutation") or stand:GetAttribute("Mutation") end
    end

    if mutation == "None" or mutation == "" then mutation = nil end
    return rarity, mutation
end

local function getOccupiedSlotsByFilter(filterName)
    local data = getData()
    local plotSlimes = (data and data.PlotSlimes) or {}
    local plot = getMyPlot()
    local liveFolder = getPlayerSlimesFolder()
    local list = {}
    if not plot then return list end
    local stands = plot:FindFirstChild("Stands")
    if not stands then return list end

    local filterLower = string.lower(filterName)
    local isMutation = false
    for _, m in ipairs(ALL_MUTATIONS) do
        if string.lower(m) == filterLower then isMutation = true break end
    end

    for _, stand in ipairs(stands:GetChildren()) do
        local name = stand.Name
        if isOccupied(name, plotSlimes, liveFolder, stand) then
            local rarity, mutation = getSlotRarityAndMutation(name, stand, plotSlimes, liveFolder)
            local match = false
            if isMutation then
                if mutation and string.lower(tostring(mutation)) == filterLower then
                    match = true
                end
            else
                if rarity then
                    local r = tostring(rarity)
                    if r == "Player God" then r = "Slime God" end
                    if string.lower(r) == filterLower then match = true end
                end
            end
            if match then
                table.insert(list, { name = name, num = tonumber(name) or 9999, stand = stand, rarity = rarity, mutation = mutation })
            end
        end
    end
    table.sort(list, function(a, b) return a.num < b.num end)
    return list
end

local function getAvailableSlots()
    local data = getData()
    local baseLevel = getBaseLevel(data)
    local plotSlimes = (data and data.PlotSlimes) or {}
    local plot = getMyPlot()
    local liveFolder = getPlayerSlimesFolder()
    local free = {}
    if not plot then return free end
    local stands = plot:FindFirstChild("Stands")
    if not stands then return free end
    for _, stand in ipairs(stands:GetChildren()) do
        local n = tonumber(stand.Name)
        if n == nil and not stand:FindFirstChild("Main") then continue end
        if isUnlocked(stand.Name, baseLevel) and not isOccupied(stand.Name, plotSlimes, liveFolder, stand) then
            table.insert(free, { name = stand.Name, num = n or 999, stand = stand })
        end
    end
    table.sort(free, function(a, b) return a.num < b.num end)
    return free
end

local function getToolValue(tool)
    if not tool then return 0 end
    local mps = tool:GetAttribute("MoneyPerSecond") or tool:GetAttribute("moneyPerSecond")
    if mps and tonumber(mps) then return tonumber(mps) end
    local val = tool:GetAttribute("Value") or tool:GetAttribute("value")
        or tool:GetAttribute("CashValue") or tool:GetAttribute("SellPrice") or tool:GetAttribute("sellPrice")
    if val and tonumber(val) then return tonumber(val) end
    local slimeId = tool:GetAttribute("slimeID") or tool:GetAttribute("slimeId") or tool:GetAttribute("id") or tool:GetAttribute("SlimeId")
    if slimeId and _Lib and _Lib.Database and _Lib.Database.Slimes then
        local def = _Lib.Database.Slimes[slimeId] or _Lib.Database.Slimes[tostring(slimeId)] or _Lib.Database.Slimes[tonumber(slimeId)]
        if def then
            if def.MoneyPerSecond then return tonumber(def.MoneyPerSecond) or 0 end
            if def.SellPrice then return tonumber(def.SellPrice) or 0 end
        end
    end
    return 0
end

local function getSlimeTools()
    local list, seen = {}, {}
    local function scan(bag)
        if not bag then return end
        for _, item in ipairs(bag:GetChildren()) do
            if item:IsA("Tool") then
                local uid = item:GetAttribute("slimeUID")
                if uid ~= nil and not seen[tostring(uid)] then
                    seen[tostring(uid)] = true
                    table.insert(list, { tool = item, uid = uid, value = getToolValue(item) })
                end
            end
        end
    end
    scan(LocalPlayer:FindFirstChild("Backpack"))
    scan(LocalPlayer.Character)
    table.sort(list, function(a, b) return (a.value or 0) > (b.value or 0) end)
    return list
end

local function isLuckyBlock(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local typ = tool:GetAttribute("Type") or tool:GetAttribute("type")
    if typ and tostring(typ):lower():find("lucky") then return true end
    local name = tostring(tool.Name):lower()
    if name:find("lucky") or name:find("box") or name:find("crate") then return true end
    for _, n in ipairs({"spain", "champions", "og", "exclusive", "limited", "divine", "slime god", "secret"}) do
        if name:find(n) then return true end
    end
    return false
end

local function getLuckyBlockTools()
    local list, seen = {}, {}
    local function scan(bag)
        if not bag then return end
        for _, item in ipairs(bag:GetChildren()) do
            if item:IsA("Tool") then
                local uid = item:GetAttribute("slimeUID")
                if uid ~= nil and not seen[tostring(uid)] and isLuckyBlock(item) then
                    seen[tostring(uid)] = true
                    table.insert(list, { tool = item, uid = uid, value = getToolValue(item) })
                end
            end
        end
    end
    scan(LocalPlayer:FindFirstChild("Backpack"))
    scan(LocalPlayer.Character)
    table.sort(list, function(a, b) return (a.value or 0) > (b.value or 0) end)
    return list
end

local function equipTool(tool)
    local hum = getHumanoid()
    local char = LocalPlayer.Character
    if not hum or not char or not tool then return false end
    if tool.Parent == char then return true end
    pcall(function() hum:UnequipTools() end)
    task.wait(0.05)
    pcall(function() hum:EquipTool(tool) end)
    if tool.Parent ~= char then pcall(function() tool.Parent = char end) end
    task.wait(DELAY_EQUIP)
    return tool.Parent == char
end

local function findCloakTool()
    local function scan(bag)
        if not bag then return nil end
        for _, item in ipairs(bag:GetChildren()) do
            if item:IsA("Tool") then
                local n = string.lower(item.Name)
                if n:find("invisibility") or n:find("cloak") or n:find("invis") then return item end
            end
        end
    end
    return scan(LocalPlayer.Character) or scan(LocalPlayer:FindFirstChild("Backpack"))
end

local function setLocalInvisible(on)
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            if on then
                if part:GetAttribute("_OrigTrans") == nil then part:SetAttribute("_OrigTrans", part.Transparency) end
                part.Transparency = 1
            else
                local orig = part:GetAttribute("_OrigTrans")
                if orig ~= nil then part.Transparency = orig part:SetAttribute("_OrigTrans", nil) end
            end
        elseif part:IsA("Decal") or part:IsA("Texture") then
            if on then
                if part:GetAttribute("_OrigTrans") == nil then part:SetAttribute("_OrigTrans", part.Transparency) end
                part.Transparency = 1
            else
                local orig = part:GetAttribute("_OrigTrans")
                if orig ~= nil then part.Transparency = orig part:SetAttribute("_OrigTrans", nil) end
            end
        end
    end
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") then
            local handle = acc:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                if on then
                    if handle:GetAttribute("_OrigTrans") == nil then handle:SetAttribute("_OrigTrans", handle.Transparency) end
                    handle.Transparency = 1
                else
                    local orig = handle:GetAttribute("_OrigTrans")
                    if orig ~= nil then handle.Transparency = orig handle:SetAttribute("_OrigTrans", nil) end
                end
            end
        end
    end
end

local function activateCloak()
    local tool = findCloakTool()
    if not tool then return false end
    local hum = getHumanoid()
    local char = LocalPlayer.Character
    if not hum or not char then return false end
    if tool.Parent ~= char then
        pcall(function() hum:UnequipTools() end)
        task.wait(0.05)
        pcall(function() hum:EquipTool(tool) end)
        if tool.Parent ~= char then pcall(function() tool.Parent = char end) end
        task.wait(0.15)
    end
    local canAct = tool:FindFirstChild("CanActivate")
    if canAct and canAct:IsA("BoolValue") then canAct.Value = true end
    pcall(function() tool:Activate() end)
    setLocalInvisible(true)
    return true
end

local function deactivateCloak()
    setLocalInvisible(false)
    local hum = getHumanoid()
    if hum then pcall(function() hum:UnequipTools() end) end
end

local function getUpgradeCost(sellPrice, level)
    if _Lib and _Lib.Shared and typeof(_Lib.Shared.getUpgradePrice) == "function" then
        local ok, cost = pcall(_Lib.Shared.getUpgradePrice, sellPrice, level)
        if ok and type(cost) == "number" and cost == cost and cost > 0 then return math.round(cost) end
    end
    if type(sellPrice) ~= "number" or type(level) ~= "number" then return math.huge end
    local cost = sellPrice * 2 * (1.3 ^ (level - 1))
    if cost ~= cost then return math.huge end
    return math.round(cost)
end

local function getJumpUpgradePrice(currentJump)
    if type(currentJump) ~= "number" then return math.huge end
    return math.round(260 * (1.082 ^ currentJump) * 2.18 * 10)
end

local function getSlimeDef(slimeId)
    if not slimeId or not _Lib or not _Lib.Database or not _Lib.Database.Slimes then return nil end
    local db = _Lib.Database.Slimes
    return db[slimeId] or db[tostring(slimeId)] or db[tonumber(slimeId)]
end

local function readRarityFromBillboard(model)
    if not model then return nil end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("TextLabel") and d.Name == "Rarity" then
            local t = d.Text
            if t and t ~= "" then
                if t == "Player God" then t = "Slime God" end
                return t
            end
        end
    end
end

local function getStandInfo(stand)
    local level = stand:GetAttribute("level") or stand:GetAttribute("Level") or 1
    if level >= MAX_LEVEL then return nil end
    local slimeId, sellPrice, rarity, model = nil, nil, nil, nil
    if _Lib and _Lib.Data then
        local ok, data = pcall(function() return _Lib.Data:Get() end)
        if ok and data and data.PlotSlimes then
            local entry = data.PlotSlimes[stand.Name] or data.PlotSlimes[tostring(stand.Name)] or data.PlotSlimes[tonumber(stand.Name)]
            if entry then slimeId = entry.id or entry.Id or entry.slimeId or entry.slimeID end
        end
    end
    local live = workspace:FindFirstChild("Live")
    local playerSlimes = live and live:FindFirstChild("PlayerSlimes")
    local myFolder = playerSlimes and playerSlimes:FindFirstChild(LocalPlayer.Name)
    model = myFolder and (myFolder:FindFirstChild(tostring(stand.Name)) or myFolder:FindFirstChild(stand.Name))
    if model and not slimeId then
        slimeId = model:GetAttribute("slimeID") or model:GetAttribute("slimeId") or model:GetAttribute("id") or model:GetAttribute("SlimeId")
    end
    local def = getSlimeDef(slimeId)
    if def then
        rarity = def.Rarity or def.rarity
        sellPrice = def.SellPrice or (def.MoneyPerSecond and math.round(def.MoneyPerSecond * 4))
    end
    if not rarity and model then rarity = readRarityFromBillboard(model) end
    if not rarity and model then rarity = model:GetAttribute("Rarity") or model:GetAttribute("rarity") end
    if not rarity then rarity = stand:GetAttribute("Rarity") or stand:GetAttribute("rarity") end
    if not sellPrice and model then
        sellPrice = model:GetAttribute("SellPrice") or model:GetAttribute("sellPrice")
            or (model:GetAttribute("MoneyPerSecond") and math.round(model:GetAttribute("MoneyPerSecond") * 4))
    end
    if not sellPrice then
        sellPrice = stand:GetAttribute("SellPrice") or stand:GetAttribute("sellPrice")
            or (stand:GetAttribute("MoneyPerSecond") and math.round(stand:GetAttribute("MoneyPerSecond") * 4))
    end
    if not rarity or rarity ~= "OG" then return nil end
    if not sellPrice or sellPrice <= 0 then return nil end
    return {
        stand = stand, id = stand.Name, level = level,
        cost = getUpgradeCost(sellPrice, level), rarity = rarity,
        priority = UPGRADE_PRIORITY[rarity], slimeId = slimeId,
    }
end

local function getPrioritizedUpgrades()
    local list, seen = {}, {}
    local function scanPlot(plot)
        if not plot then return end
        local stands = plot:FindFirstChild("Stands")
        if not stands then return end
        for _, stand in ipairs(stands:GetChildren()) do
            if stand:IsA("Model") and not seen[stand.Name] then
                seen[stand.Name] = true
                local info = getStandInfo(stand)
                if info then table.insert(list, info) end
            end
        end
    end
    if _G.MyPlot then scanPlot(_G.MyPlot) end
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local owner = plot:FindFirstChild("owner")
            if owner and owner.Value == LocalPlayer.Name then scanPlot(plot) end
        end
    end
    table.sort(list, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.cost < b.cost
    end)
    return list
end

local function getAllCollectPads()
    local pads, seen = {}, {}
    local function add(pad)
        if pad and pad:IsA("Model") and not seen[pad] then
            seen[pad] = true
            table.insert(pads, pad)
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Top") then
            local padGui = obj.Top:FindFirstChild("PadGui")
            if padGui and (not ONLY_WHEN_PADGUI_ENABLED or padGui.Enabled) then add(obj) end
        end
    end
    return pads
end

local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getRarityValue(name, model)
    name = tostring(name or "")
    for rarity, value in pairs(RARITY_VALUE) do
        if string.find(string.lower(name), string.lower(rarity), 1, true) then
            return value, rarity
        end
    end
    if model then
        local attr = model:GetAttribute("Rarity") or model:GetAttribute("rarity") or model:GetAttribute("Type")
        if attr then
            attr = tostring(attr)
            for rarity, value in pairs(RARITY_VALUE) do
                if string.find(string.lower(attr), string.lower(rarity), 1, true) then
                    return value, rarity
                end
            end
        end
    end
    return 1, "Unknown"
end

local function teleportToBase()
    local root = getRoot()
    if not root then return false end
    if _G.MyPlot and _G.MyPlot.Base and _G.MyPlot.Base.Teleport and _G.MyPlot.Base.Teleport.WorldCFrame then
        root.CFrame = _G.MyPlot.Base.Teleport.WorldCFrame + Vector3.new(0, 3, 0)
        root.AssemblyLinearVelocity = Vector3.zero
        return true
    end
    local plot = getMyPlot()
    if plot then
        local base = plot:FindFirstChild("Base")
        if base then
            local tp = base:FindFirstChild("Teleport")
            if tp and tp:IsA("Attachment") and tp.WorldCFrame then
                root.CFrame = tp.WorldCFrame + Vector3.new(0, 3, 0)
                root.AssemblyLinearVelocity = Vector3.zero
                return true
            end
        end
    end
    return false
end

local function getTargetLuckyBlock()
    local live = workspace:FindFirstChild("Live")
    if not live then return nil end
    local slimes = live:FindFirstChild("Slimes")
    if not slimes then return nil end
    local best, bestValue = nil, 0
    for _, model in ipairs(slimes:GetChildren()) do
        if model:IsA("Model") and not model:GetAttribute("Carrying") then
            local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if not primary then continue end
            local value, rarity = getRarityValue(model.Name, model)
            if rarity ~= "OG" then continue end
            local attrValue = model:GetAttribute("Value") or model:GetAttribute("MoneyPerSecond")
            if attrValue and tonumber(attrValue) then value = tonumber(attrValue) end
            local prompt = nil
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    local at = tostring(d.ActionText or ""):lower()
                    if at:find("steal") or at:find("open") or at:find("pick") or at:find("take") or not prompt then
                        prompt = d
                        if at:find("steal") or at:find("open") or at:find("pick") or at:find("take") then break end
                    end
                end
            end
            if value > bestValue then
                bestValue = value
                best = { name = model.Name, rarity = rarity, value = value, part = primary, prompt = prompt, model = model }
            end
        end
    end
    return best
end

local function attemptSteal(prompt)
    if not prompt then return false end
    local hold = prompt.HoldDuration or 0
    if typeof(fireproximityprompt) == "function" then
        local ok = pcall(function() fireproximityprompt(prompt) end)
        if ok then task.wait(hold + 0.5) return true end
    end
    local ok = pcall(function() prompt:Trigger() end)
    if ok then task.wait(hold + 0.5) return true end
    return false
end

local function doPlaceAndOpenBoxes()
    if not PlaceRemote or not OpenRemote then return 0, 0 end
    local placed, opened = 0, 0
    while true do
        local boxes = getLuckyBlockTools()
        local slots = getAvailableSlots()
        if #boxes == 0 or #slots == 0 then break end
        local entry, slot = boxes[1], slots[1]
        if not entry.tool or not entry.tool.Parent then
            for _, t in ipairs(getLuckyBlockTools()) do
                if tostring(t.uid) == tostring(entry.uid) then entry = t break end
            end
        end
        if not entry.tool then break end
        local data = getData()
        local plotSlimes = (data and data.PlotSlimes) or {}
        if isOccupied(slot.name, plotSlimes, getPlayerSlimesFolder(), slot.stand) then
            task.wait(0.05)
            continue
        end
        if equipTool(entry.tool) then
            local uid = entry.uid
            if pcall(function() PlaceRemote:FireServer(slot.name, uid) end) then
                placed += 1
                task.wait(DELAY_PLACE)
                if pcall(function() OpenRemote:FireServer(slot.name) end) then opened += 1 end
                task.wait(DELAY_OPEN)
            end
        end
        task.wait(DELAY_NEXT)
    end
    local hum = getHumanoid()
    if hum then pcall(function() hum:UnequipTools() end) end
    return placed, opened
end

-- ============================================
-- MANUAL BUTTONS
-- ============================================
PickupBtn.MouseButton1Click:Connect(function()
    if actionBusy or not PickupRemote then return end
    actionBusy = true
    PickupBtn.Text = "Picking..."
    local slots = getFloor1OccupiedSlots()
    local n = 0
    for _, slot in ipairs(slots) do
        if pcall(function() PickupRemote:FireServer(slot.name) end) then n += 1 end
        task.wait(DELAY_PICK)
    end
    StatusLabel.Text = string.format("Picked %d from Floor 1", n)
    PickupBtn.Text = "Pick Up Floor 1 (1-10)"
    actionBusy = false
end)

PickupAllBtn.MouseButton1Click:Connect(function()
    if actionBusy or not PickupRemote then return end
    actionBusy = true
    PickupAllBtn.Text = "Picking ALL..."
    local slots = getAllOccupiedSlots()
    local n = 0
    for _, slot in ipairs(slots) do
        if pcall(function() PickupRemote:FireServer(slot.name) end) then n += 1 end
        task.wait(DELAY_PICK)
    end
    StatusLabel.Text = string.format("Picked %d from ALL floors", n)
    PickupAllBtn.Text = "Pick Up ALL Floors"
    actionBusy = false
end)

-- NEW: Pick by selected rarity OR mutation (all floors)
PickRarityBtn.MouseButton1Click:Connect(function()
    if actionBusy or not PickupRemote then return end
    actionBusy = true
    DropList.Visible = false
    PickRarityBtn.Text = "..."
    local filter = selectedPickOption
    local slots = getOccupiedSlotsByFilter(filter)
    StatusLabel.Text = string.format("Picking %s: %d found", filter, #slots)

    if #slots == 0 then
        StatusLabel.Text = string.format("No %s slimes on any floor", filter)
        PickRarityBtn.Text = "Pick"
        actionBusy = false
        return
    end

    local n = 0
    for _, slot in ipairs(slots) do
        if pcall(function() PickupRemote:FireServer(slot.name) end) then n += 1 end
        task.wait(DELAY_PICK)
    end

    StatusLabel.Text = string.format("Picked %d × %s (all floors)", n, filter)
    PickRarityBtn.Text = "Pick"
    actionBusy = false
end)

PlaceBtn.MouseButton1Click:Connect(function()
    if actionBusy or not PlaceRemote then return end
    actionBusy = true
    PlaceBtn.Text = "Placing..."
    local tools = getSlimeTools()
    local slots = getAvailableSlots()
    if #tools == 0 or #slots == 0 then
        StatusLabel.Text = #tools == 0 and "No slime tools" or "No free slots"
        PlaceBtn.Text = "Place All (highest value first)"
        actionBusy = false
        return
    end
    local total = math.min(#tools, #slots)
    local placed = 0
    for i = 1, total do
        local entry, slot = tools[i], slots[i]
        if not entry.tool or not entry.tool.Parent then
            for _, t in ipairs(getSlimeTools()) do
                if tostring(t.uid) == tostring(entry.uid) then entry = t break end
            end
        end
        local data = getData()
        local plotSlimes = (data and data.PlotSlimes) or {}
        if not isOccupied(slot.name, plotSlimes, getPlayerSlimesFolder(), slot.stand) then
            if entry.tool and equipTool(entry.tool) then
                if pcall(function() PlaceRemote:FireServer(slot.name, entry.uid) end) then placed += 1 end
                task.wait(DELAY_PLACE)
            end
        end
        task.wait(DELAY_NEXT)
    end
    local hum = getHumanoid()
    if hum then pcall(function() hum:UnequipTools() end) end
    StatusLabel.Text = string.format("Placed %d (highest value first)", placed)
    PlaceBtn.Text = "Place All (highest value first)"
    actionBusy = false
end)

BoxesBtn.MouseButton1Click:Connect(function()
    if actionBusy then return end
    actionBusy = true
    BoxesBtn.Text = "Working..."
    local p, o = doPlaceAndOpenBoxes()
    StatusLabel.Text = string.format("Pass done — Placed %d | Opened %d", p, o)
    BoxesBtn.Text = "Place + Open All Boxes (Once)"
    actionBusy = false
end)

-- ============================================
-- LOOPS
-- ============================================
task.spawn(function()
    while true do
        if collectEnabled and CollectRemote then
            for _, pad in ipairs(getAllCollectPads()) do
                if not collectEnabled then break end
                pcall(function() CollectRemote:FireServer(pad.Name) end)
                task.wait(COLLECT_INTERVAL)
            end
        end
        task.wait(COLLECT_SCAN)
    end
end)

task.spawn(function()
    while true do
        if upgradeEnabled and UpgradeRemote then
            local upgrades = getPrioritizedUpgrades()
            local cash = getCash()
            if #upgrades == 0 then
                StatusLabel.Text = string.format("No OG to upgrade\nCash: $%s", tostring(cash))
            else
                for _, info in ipairs(upgrades) do
                    if not upgradeEnabled then break end
                    cash = getCash()
                    if info.cost <= cash then
                        pcall(function() UpgradeRemote:FireServer(info.id) end)
                        StatusLabel.Text = string.format("Upgraded OG %s Lv%d", info.id, info.level)
                        task.wait(UPGRADE_DELAY)
                    else break end
                end
            end
        end
        task.wait(UPGRADE_SCAN)
    end
end)

task.spawn(function()
    while true do
        if luckyEnabled and not luckyBlockBusy then
            luckyBlockBusy = true
            local block = getTargetLuckyBlock()
            if not block then
                StatusLabel.Text = string.format("No OG boxes | Total: %d", totalCollected)
                luckyBlockBusy = false
                task.wait(0.5)
            else
                local root = getRoot()
                if root and block.part then
                    root.CFrame = block.part.CFrame * CFrame.new(0, 3, 4)
                    root.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.15)
                    if block.prompt and attemptSteal(block.prompt) then
                        totalCollected += 1
                        StatusLabel.Text = string.format("✓ Stole OG! (#%d)", totalCollected)
                        task.wait(0.3)
                        teleportToBase()
                        task.wait(0.5)
                    else
                        task.wait(0.3)
                    end
                end
                luckyBlockBusy = false
            end
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        if rebirthEnabled and RebirthRemote then
            pcall(function() RebirthRemote:FireServer() end)
        end
        task.wait(REBIRTH_INTERVAL)
    end
end)

task.spawn(function()
    while true do
        if jumpUpgradeEnabled and JumpUpgradeRemote then
            local cash, jump = getCash(), getJumpData()
            if getJumpUpgradePrice(jump) <= cash then
                pcall(function() JumpUpgradeRemote:FireServer(3) end)
            end
        end
        task.wait(JUMP_UPGRADE_INTERVAL)
    end
end)

task.spawn(function()
    while true do
        if boxesAutoEnabled and not actionBusy then
            actionBusy = true
            local p, o = doPlaceAndOpenBoxes()
            if p > 0 or o > 0 then
                StatusLabel.Text = string.format("Auto Boxes: +%d placed, +%d opened", p, o)
            else
                StatusLabel.Text = "Auto Boxes: waiting... (still running)"
            end
            actionBusy = false
        end
        task.wait(BOXES_AUTO_INTERVAL)
    end
end)

task.spawn(function()
    while true do
        if invisEnabled then activateCloak() end
        task.wait(INVIS_REFRESH)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if invisEnabled then activateCloak() end
end)

function stopAll()
    setCollectState(false)
    setUpgradeState(false)
    setLuckyState(false)
    setRebirthState(false)
    setJumpUpgradeState(false)
    setBoxesAutoState(false)
    setInvisState(false)
    deactivateCloak()
    StatusLabel.Text = "All systems stopped"
end

function goToBase()
    return teleportToBase()
end

print("========================================")
print("[AutoFarm] Pick by Rarity/Mutation added")
print("Rarities: Common→Spain | Mutations: Golden, Diamond, Rainbow, Cursed, Volcanic, Toxic, Taco, Cosmic, Slimey")
print("Commands: stopAll() | goToBase()")
print("========================================")
