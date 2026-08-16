-- Combined Script: Spain Upgrade + Steal + Burst Place/Open + Instant Pick/Place
-- Place All sorted by real earning value (DB MPS × level × mutation) HIGH → LOW

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
local DELAY_NEXT  = 0.12
local DELAY_PICK  = 0.12
local IGNORE_LOCK = true

-- ONLY SPAIN
local UPGRADE_PRIORITY = { ["Spain"] = 1 }
local TARGET_RARITIES  = { ["Spain"] = true }

local RARITY_VALUE = {
    ["Spain"] = 2500000, ["Champions"] = 1000000, ["OG"] = 500000,
    ["Exclusive"] = 75000, ["LIMITED"] = 75000, ["Divine"] = 50000,
    ["Slime God"] = 30000, ["Secret"] = 10000, ["Mythic"] = 2500,
    ["Legendary"] = 750, ["Epic"] = 250, ["Rare"] = 100, ["Common"] = 25,
}

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
MainFrame.Size = UDim2.new(0, 250, 0, 760)
MainFrame.Position = UDim2.new(0, 20, 0.5, -380)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BackgroundTransparency = 0.05
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(80, 80, 100)
MainFrame:FindFirstChildOfClass("UIStroke").Thickness = 2

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
    btn.Size = UDim2.new(0, 220, 0, 30)
    btn.Position = UDim2.new(0, 15, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 90, 90)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.Parent = MainFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local s = Instance.new("UIStroke", btn)
    s.Color = Color3.fromRGB(70, 70, 85)
    s.Thickness = 1.5
    return btn
end

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0, 230, 0, 44)
StatusLabel.Position = UDim2.new(0, 10, 0, 708)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Loading..."
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.TextWrapped = true
StatusLabel.Parent = MainFrame

local CollectBtn   = createButton("CollectToggle", 30, "Auto Collect: OFF")
local UpgradeBtn   = createButton("UpgradeToggle", 64, "Auto Upgrade: OFF")
local LuckyBtn     = createButton("LuckyToggle", 98, "Lucky Block: OFF")
local RebirthBtn   = createButton("RebirthToggle", 132, "Auto Rebirth: OFF")
local JumpBtn      = createButton("JumpToggle", 166, "Auto +10 Jump: OFF")
local BoxesAutoBtn = createButton("BoxesAutoToggle", 200, "Auto Place+Open Boxes: OFF")
local InvisBtn     = createButton("InvisToggle", 234, "Invis Cloak: OFF")

local PickupBtn    = createButton("PickupBtn", 276, "Pick Up Floor 1 (1-10)")
local PickupAllBtn = createButton("PickupAllBtn", 310, "Pick Up ALL Floors")
local PlaceBtn     = createButton("PlaceBtn", 344, "Place All (highest value first)")
local BoxesBtn     = createButton("BoxesBtn", 378, "Place + Open Spain Boxes (Once)")

local PlaceBoxesBtn = Instance.new("TextButton")
PlaceBoxesBtn.Name = "PlaceBoxesBtn"
PlaceBoxesBtn.Size = UDim2.new(0, 106, 0, 30)
PlaceBoxesBtn.Position = UDim2.new(0, 15, 0, 412)
PlaceBoxesBtn.BackgroundColor3 = Color3.fromRGB(40, 55, 40)
PlaceBoxesBtn.BorderSizePixel = 0
PlaceBoxesBtn.Text = "Place Boxes"
PlaceBoxesBtn.TextColor3 = Color3.fromRGB(120, 255, 150)
PlaceBoxesBtn.TextSize = 11
PlaceBoxesBtn.Font = Enum.Font.GothamBold
PlaceBoxesBtn.Parent = MainFrame
Instance.new("UICorner", PlaceBoxesBtn).CornerRadius = UDim.new(0, 8)

local OpenBoxesBtn = Instance.new("TextButton")
OpenBoxesBtn.Name = "OpenBoxesBtn"
OpenBoxesBtn.Size = UDim2.new(0, 106, 0, 30)
OpenBoxesBtn.Position = UDim2.new(0, 129, 0, 412)
OpenBoxesBtn.BackgroundColor3 = Color3.fromRGB(55, 45, 25)
OpenBoxesBtn.BorderSizePixel = 0
OpenBoxesBtn.Text = "Open Boxes"
OpenBoxesBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
OpenBoxesBtn.TextSize = 11
OpenBoxesBtn.Font = Enum.Font.GothamBold
OpenBoxesBtn.Parent = MainFrame
Instance.new("UICorner", OpenBoxesBtn).CornerRadius = UDim.new(0, 8)

local RarityLabel = Instance.new("TextLabel")
RarityLabel.Size = UDim2.new(0, 220, 0, 16)
RarityLabel.Position = UDim2.new(0, 15, 0, 450)
RarityLabel.BackgroundTransparency = 1
RarityLabel.Text = "Pick by Rarity / Mutation:"
RarityLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
RarityLabel.TextSize = 11
RarityLabel.Font = Enum.Font.Gotham
RarityLabel.TextXAlignment = Enum.TextXAlignment.Left
RarityLabel.Parent = MainFrame

local selectedPickOption = "Spain"
local DropBtn = Instance.new("TextButton")
DropBtn.Name = "RarityDrop"
DropBtn.Size = UDim2.new(0, 140, 0, 28)
DropBtn.Position = UDim2.new(0, 15, 0, 468)
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
PickRarityBtn.Size = UDim2.new(0, 72, 0, 28)
PickRarityBtn.Position = UDim2.new(0, 163, 0, 468)
PickRarityBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 80)
PickRarityBtn.BorderSizePixel = 0
PickRarityBtn.Text = "Pick"
PickRarityBtn.TextColor3 = Color3.fromRGB(200, 170, 255)
PickRarityBtn.TextSize = 12
PickRarityBtn.Font = Enum.Font.GothamBold
PickRarityBtn.Parent = MainFrame
Instance.new("UICorner", PickRarityBtn).CornerRadius = UDim.new(0, 6)

local DropList = Instance.new("ScrollingFrame")
DropList.Name = "DropList"
DropList.Size = UDim2.new(0, 220, 0, 140)
DropList.Position = UDim2.new(0, 15, 0, 500)
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

print("[AutoFarm] GUI ready — Spain | Instant pick/place | Value sort")

-- ============================================
-- STATE
-- ============================================
local collectEnabled, upgradeEnabled, luckyEnabled = false, false, false
local rebirthEnabled, jumpUpgradeEnabled, boxesAutoEnabled = false, false, false
local invisEnabled = false
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
        StatusLabel.Text = "Lucky Block: Spain only..."
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
            table.insert(list, { name = stand.Name, num = tonumber(stand.Name) or 0 })
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
            table.insert(list, { name = name, num = tonumber(name) or 9999 })
        end
    end
    table.sort(list, function(a, b) return a.num < b.num end)
    return list
end

local function getSlotRarityAndMutation(slotName, stand, plotSlimes, liveFolder)
    local rarity, mutation = nil, nil
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
    local model = liveFolder and (liveFolder:FindFirstChild(tostring(slotName)) or liveFolder:FindFirstChild(slotName))
    if model then
        if not rarity then rarity = model:GetAttribute("Rarity") or model:GetAttribute("rarity") end
        if not mutation then mutation = model:GetAttribute("mutation") or model:GetAttribute("Mutation") end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("TextLabel") and d.Name == "Rarity" and d.Text ~= "" and not rarity then
                local t = d.Text
                if t == "Player God" then t = "Slime God" end
                rarity = t
            end
        end
    end
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
                if mutation and string.lower(tostring(mutation)) == filterLower then match = true end
            else
                if rarity then
                    local r = tostring(rarity)
                    if r == "Player God" then r = "Slime God" end
                    if string.lower(r) == filterLower then match = true end
                end
            end
            if match then
                table.insert(list, { name = name, num = tonumber(name) or 9999 })
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

local function getUnopenedLuckyBlockSlots()
    local data = getData()
    local plotSlimes = (data and data.PlotSlimes) or {}
    local list, seen = {}, {}
    local function add(name)
        name = tostring(name)
        if not seen[name] then seen[name] = true table.insert(list, name) end
    end
    if type(plotSlimes) == "table" then
        for k, entry in pairs(plotSlimes) do
            if type(entry) == "table" then
                local typ = tostring(entry.Type or entry.type or "")
                if typ:lower():find("lucky") then add(k) end
            end
        end
    end
    local plot = getMyPlot()
    local stands = plot and plot:FindFirstChild("Stands")
    if stands then
        for _, stand in ipairs(stands:GetChildren()) do
            for _, d in ipairs(stand:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    if tostring(d.ActionText or ""):lower():find("open") then
                        add(stand.Name)
                        break
                    end
                end
            end
        end
    end
    return list
end

-- ===== REAL EARNING VALUE (from game formula) =====
-- baseMPS from Database.Slimes[id].MoneyPerSecond
-- × level scale ≈ (rebirth + (level^1.05-1)*sqrt(rebirth))  — use rebirth=1 for inventory sort
-- × mutation multi
local MUTATION_MULTI = {
    Golden = 2, Diamond = 2.5, Rainbow = 3, Cursed = 4,
    Volcanic = 2, Toxic = 2, Taco = 3, Cosmic = 3, Slimey = 3,
}

local function getMutationMulti(mutation, eventMutations)
    if _Lib and _Lib.Shared and typeof(_Lib.Shared.getMutationMulti) == "function" then
        local ok, m = pcall(_Lib.Shared.getMutationMulti, mutation, eventMutations)
        if ok and type(m) == "number" and m > 0 then return m end
    end
    local multi = 1
    if mutation and mutation ~= "None" and mutation ~= "" then
        multi = MUTATION_MULTI[tostring(mutation)] or multi
    end
    if type(eventMutations) == "table" then
        for _, em in pairs(eventMutations) do
            local add = MUTATION_MULTI[tostring(em)]
            if add then multi = multi + (add - 1) end
        end
    end
    return multi
end

local function getRebirthScaledEarnings(baseMps, level, rebirthMulti)
    if _Lib and _Lib.Shared and typeof(_Lib.Shared.getRebirthScaledEarnings) == "function" then
        local ok, v = pcall(_Lib.Shared.getRebirthScaledEarnings, baseMps, level, rebirthMulti)
        if ok and type(v) == "number" then return v end
    end
    level = math.max(1, level or 1)
    rebirthMulti = math.max(1, rebirthMulti or 1)
    return math.round(baseMps * (rebirthMulti + (level ^ 1.05 - 1) * math.sqrt(rebirthMulti)))
end

local function getToolValue(tool)
    if not tool then return 0 end

    local slimeId = tool:GetAttribute("slimeID") or tool:GetAttribute("slimeId")
        or tool:GetAttribute("id") or tool:GetAttribute("SlimeId")
    local level = tonumber(tool:GetAttribute("level") or tool:GetAttribute("Level")) or 1
    local mutation = tool:GetAttribute("mutation") or tool:GetAttribute("Mutation")
    local eventMut = tool:GetAttribute("event_mutations")

    local baseMps = nil
    if slimeId and _Lib and _Lib.Database and _Lib.Database.Slimes then
        local def = _Lib.Database.Slimes[slimeId]
            or _Lib.Database.Slimes[tostring(slimeId)]
            or _Lib.Database.Slimes[tonumber(slimeId)]
        if def then
            baseMps = tonumber(def.MoneyPerSecond)
            -- unopened lucky block = 0
            if def.Type == "Lucky Block" then return 0 end
        end
    end

    if not baseMps then
        baseMps = tonumber(tool:GetAttribute("MoneyPerSecond") or tool:GetAttribute("moneyPerSecond")
            or tool:GetAttribute("Value") or tool:GetAttribute("value")
            or tool:GetAttribute("SellPrice") or tool:GetAttribute("sellPrice")) or 0
    end

    if baseMps <= 0 then return 0 end

    -- Inventory tools: use rebirth multi 1 for relative sort (same for all tools)
    local scaled = getRebirthScaledEarnings(baseMps, level, 1)
    local mutMulti = getMutationMulti(mutation, eventMut)
    return math.round(scaled * mutMulti)
end

local function getSlimeTools()
    local list, seen = {}, {}
    local function scan(bag)
        if not bag then return end
        for _, item in ipairs(bag:GetChildren()) do
            if item:IsA("Tool") then
                local uid = item:GetAttribute("slimeUID")
                if uid ~= nil and not seen[tostring(uid)] then
                    -- skip pure unopened lucky blocks for slime place-all (optional: still include)
                    seen[tostring(uid)] = true
                    local val = getToolValue(item)
                    table.insert(list, { tool = item, uid = uid, value = val })
                end
            end
        end
    end
    scan(LocalPlayer:FindFirstChild("Backpack"))
    scan(LocalPlayer.Character)

    -- HIGHEST value first
    table.sort(list, function(a, b)
        return (a.value or 0) > (b.value or 0)
    end)
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

local function isSpainLuckyBlock(tool)
    if not isLuckyBlock(tool) then return false end
    local name = string.lower(tostring(tool.Name))
    if name:find("spain", 1, true) then return true end
    local rarity = tool:GetAttribute("Rarity") or tool:GetAttribute("rarity")
    if rarity and string.lower(tostring(rarity)) == "spain" then return true end
    return false
end

local function getSpainLuckyBlockTools()
    local list, seen = {}, {}
    local function scan(bag)
        if not bag then return end
        for _, item in ipairs(bag:GetChildren()) do
            if item:IsA("Tool") then
                local uid = item:GetAttribute("slimeUID")
                if uid ~= nil and not seen[tostring(uid)] and isSpainLuckyBlock(item) then
                    seen[tostring(uid)] = true
                    table.insert(list, { tool = item, uid = uid })
                end
            end
        end
    end
    scan(LocalPlayer:FindFirstChild("Backpack"))
    scan(LocalPlayer.Character)
    return list
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
    if not rarity or rarity ~= "Spain" then return nil end
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
            if rarity ~= "Spain" then continue end
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

-- INSTANT pick: fire all at once
local function doPickBurst(slots)
    if not PickupRemote or not slots then return 0 end
    local n = 0
    for _, slot in ipairs(slots) do
        if pcall(function() PickupRemote:FireServer(slot.name) end) then
            n += 1
        end
    end
    return n
end

-- INSTANT place: highest value first, fire all at once (no equip)
local function doPlaceBurst()
    if not PlaceRemote then return 0 end
    local tools = getSlimeTools() -- already sorted high → low
    local slots = getAvailableSlots() -- low slot num first
    if #tools == 0 or #slots == 0 then return 0 end

    local total = math.min(#tools, #slots)
    local placed = 0

    -- Debug order
    for i = 1, math.min(5, total) do
        print(string.format("[PlaceOrder] #%d value=%s uid=%s → slot %s",
            i, tostring(tools[i].value), tostring(tools[i].uid), slots[i].name))
    end

    for i = 1, total do
        local entry, slot = tools[i], slots[i]
        if entry and entry.uid and slot then
            if pcall(function() PlaceRemote:FireServer(slot.name, entry.uid) end) then
                placed += 1
            end
        end
    end
    return placed
end

local function doPlaceBoxesOnly()
    if not PlaceRemote then return 0 end
    local boxes = getSpainLuckyBlockTools()
    local slots = getAvailableSlots()
    if #boxes == 0 or #slots == 0 then return 0 end
    local total = math.min(#boxes, #slots)
    local placed = 0
    for i = 1, total do
        local entry, slot = boxes[i], slots[i]
        if entry and entry.uid and slot then
            if pcall(function() PlaceRemote:FireServer(slot.name, entry.uid) end) then
                placed += 1
            end
        end
    end
    return placed
end

local function doOpenBoxesOnly()
    if not OpenRemote then return 0 end
    local slots = getUnopenedLuckyBlockSlots()
    local opened = 0
    for _, slotName in ipairs(slots) do
        if pcall(function() OpenRemote:FireServer(slotName) end) then
            opened += 1
        end
    end
    return opened
end

local function doPlaceAndOpenBoxes()
    if not PlaceRemote or not OpenRemote then return 0, 0 end
    local boxes = getSpainLuckyBlockTools()
    local slots = getAvailableSlots()
    if #boxes == 0 or #slots == 0 then return 0, 0 end
    local total = math.min(#boxes, #slots)
    local placed, opened = 0, 0
    for i = 1, total do
        local entry, slot = boxes[i], slots[i]
        if entry and entry.uid and slot then
            if pcall(function() PlaceRemote:FireServer(slot.name, entry.uid) end) then
                placed += 1
            end
            if pcall(function() OpenRemote:FireServer(slot.name) end) then
                opened += 1
            end
        end
    end
    return placed, opened
end

-- ============================================
-- MANUAL BUTTONS
-- ============================================
PickupBtn.MouseButton1Click:Connect(function()
    if actionBusy or not PickupRemote then return end
    actionBusy = true
    PickupBtn.Text = "..."
    local n = doPickBurst(getFloor1OccupiedSlots())
    StatusLabel.Text = string.format("Picked %d Floor 1 (instant)", n)
    PickupBtn.Text = "Pick Up Floor 1 (1-10)"
    actionBusy = false
end)

PickupAllBtn.MouseButton1Click:Connect(function()
    if actionBusy or not PickupRemote then return end
    actionBusy = true
    PickupAllBtn.Text = "..."
    local n = doPickBurst(getAllOccupiedSlots())
    StatusLabel.Text = string.format("Picked %d ALL floors (instant)", n)
    PickupAllBtn.Text = "Pick Up ALL Floors"
    actionBusy = false
end)

PickRarityBtn.MouseButton1Click:Connect(function()
    if actionBusy or not PickupRemote then return end
    actionBusy = true
    DropList.Visible = false
    PickRarityBtn.Text = "..."
    local filter = selectedPickOption
    local slots = getOccupiedSlotsByFilter(filter)
    local n = doPickBurst(slots)
    StatusLabel.Text = string.format("Picked %d × %s (instant)", n, filter)
    PickRarityBtn.Text = "Pick"
    actionBusy = false
end)

PlaceBtn.MouseButton1Click:Connect(function()
    if actionBusy or not PlaceRemote then return end
    actionBusy = true
    PlaceBtn.Text = "..."
    local n = doPlaceBurst()
    StatusLabel.Text = string.format("Placed %d (highest value first, instant)", n)
    PlaceBtn.Text = "Place All (highest value first)"
    actionBusy = false
end)

BoxesBtn.MouseButton1Click:Connect(function()
    if actionBusy then return end
    actionBusy = true
    BoxesBtn.Text = "..."
    local p, o = doPlaceAndOpenBoxes()
    StatusLabel.Text = string.format("Burst — Placed %d | Opened %d Spain", p, o)
    BoxesBtn.Text = "Place + Open Spain Boxes (Once)"
    actionBusy = false
end)

PlaceBoxesBtn.MouseButton1Click:Connect(function()
    if actionBusy then return end
    actionBusy = true
    PlaceBoxesBtn.Text = "..."
    local p = doPlaceBoxesOnly()
    StatusLabel.Text = string.format("Placed %d Spain boxes (instant)", p)
    PlaceBoxesBtn.Text = "Place Boxes"
    actionBusy = false
end)

OpenBoxesBtn.MouseButton1Click:Connect(function()
    if actionBusy then return end
    actionBusy = true
    OpenBoxesBtn.Text = "..."
    local o = doOpenBoxesOnly()
    StatusLabel.Text = string.format("Opened %d boxes (instant)", o)
    OpenBoxesBtn.Text = "Open Boxes"
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
                StatusLabel.Text = string.format("No Spain to upgrade\nCash: $%s", tostring(cash))
            else
                for _, info in ipairs(upgrades) do
                    if not upgradeEnabled then break end
                    cash = getCash()
                    if info.cost <= cash then
                        pcall(function() UpgradeRemote:FireServer(info.id) end)
                        StatusLabel.Text = string.format("Upgraded Spain %s Lv%d", info.id, info.level)
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
                StatusLabel.Text = string.format("No Spain boxes | Total: %d", totalCollected)
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
                        StatusLabel.Text = string.format("✓ Stole Spain! (#%d)", totalCollected)
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
                StatusLabel.Text = string.format("Auto Boxes: +%d / +%d Spain", p, o)
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
print("[AutoFarm] Spain | Instant pick/place burst | Value = DB MPS × level × mutation")
print("Place order: highest earning first → lowest slot numbers")
print("Commands: stopAll() | goToBase()")
print("========================================")
