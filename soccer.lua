-- Combined Script: CHEAPEST-FIRST Spain Upgrade + FILTERED Lucky Block Collector + Burst Place/Open + Manual Place / Open
-- + Pick Floor 1 / ALL + dedicated Place-by-Mutation dropdown + FIXED Place button + CURRENT INDIVIDUAL earnings desc + Invis

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

-- Auto Upgrade mutation filter.
-- "All" = every mutation / no-mutation slime that is otherwise eligible.
-- "Common" = no base mutation AND no event mutation.
local UPGRADE_MUTATION_OPTIONS = { "All", "Common" }
for _, m in ipairs(ALL_MUTATIONS) do
    table.insert(UPGRADE_MUTATION_OPTIONS, m)
end

local selectedUpgradeMutation = "All"

-- Exact Lucky Block types found in this game's slime database.
-- The dropdown uses display labels; matching uses exact live model names.
local LUCKY_BLOCK_OPTIONS = {
    "All",
    "Common",
    "Water",
    "Rare",
    "Volcanic",
    "Epic",
    "Ghost",
    "Legendary",
    "67",
    "Mythic",
    "Poison",
    "Secret",
    "Cosmic",
    "Soccer God",
    "Rainbow",
    "Exclusive",
    "Limited",
    "OG",
    "Champions",
    "Spain",
}

local LUCKY_BLOCK_MODEL_NAMES = {
    ["Common"] = { ["Common Lucky Block"] = true },
    ["Water"] = { ["Water Lucky Block"] = true },
    ["Rare"] = { ["Rare Lucky Block"] = true },
    ["Volcanic"] = { ["Volcanic Lucky Block"] = true },
    ["Epic"] = { ["Epic Lucky Block"] = true },
    ["Ghost"] = { ["Ghost Lucky Block"] = true },
    ["Legendary"] = { ["Legendary Lucky Block"] = true },
    ["67"] = { ["67 Lucky Block"] = true },
    ["Mythic"] = { ["Mythic Lucky Block"] = true },
    ["Poison"] = { ["Poison Lucky Block"] = true },
    ["Secret"] = { ["Secret Lucky Block"] = true },
    ["Cosmic"] = { ["Cosmic Lucky Block"] = true },
    -- Internal database name is Slime God Lucky Block; the game displays Soccer God.
    ["Soccer God"] = {
        ["Slime God Lucky Block"] = true,
        ["Soccer God Lucky Block"] = true,
    },
    ["Rainbow"] = { ["Rainbow Lucky Block"] = true },
    ["Exclusive"] = { ["Exclusive Lucky Block"] = true },
    ["Limited"] = { ["Limited Lucky Block"] = true },
    ["OG"] = { ["OG Lucky Block"] = true },
    ["Champions"] = { ["Champions Lucky Block"] = true },
    ["Spain"] = { ["Spain Lucky Block"] = true },
}

local selectedLuckyBlockType = "Spain"

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
MainFrame.Size = UDim2.new(0, 250, 0, 794)
MainFrame.Position = UDim2.new(0, 20, 0.5, -397)
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
StatusLabel.Position = UDim2.new(0, 10, 0, 742)
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

-- ============================================
-- AUTO UPGRADE MUTATION FILTER
-- This selection is read live by the running Auto Upgrade loop.
-- You can change it before OR after enabling Auto Upgrade.
-- ============================================

local UpgradeMutationDropBtn = Instance.new("TextButton")
UpgradeMutationDropBtn.Name = "UpgradeMutationDrop"
UpgradeMutationDropBtn.Size = UDim2.new(0, 220, 0, 30)
UpgradeMutationDropBtn.Position = UDim2.new(0, 15, 0, 98)
UpgradeMutationDropBtn.BackgroundColor3 = Color3.fromRGB(28, 42, 62)
UpgradeMutationDropBtn.BorderSizePixel = 0
UpgradeMutationDropBtn.Text = "Upgrade Mutation: ▼  All"
UpgradeMutationDropBtn.TextColor3 = Color3.fromRGB(150, 205, 255)
UpgradeMutationDropBtn.TextSize = 11
UpgradeMutationDropBtn.Font = Enum.Font.GothamBold
UpgradeMutationDropBtn.ZIndex = 50
UpgradeMutationDropBtn.Parent = MainFrame
Instance.new("UICorner", UpgradeMutationDropBtn).CornerRadius = UDim.new(0, 8)

local UpgradeMutationDropList = Instance.new("ScrollingFrame")
UpgradeMutationDropList.Name = "UpgradeMutationDropList"
UpgradeMutationDropList.Size = UDim2.new(0, 220, 0, 180)
UpgradeMutationDropList.Position = UDim2.new(0, 15, 0, 130)
UpgradeMutationDropList.BackgroundColor3 = Color3.fromRGB(20, 28, 40)
UpgradeMutationDropList.BorderSizePixel = 0
UpgradeMutationDropList.Visible = false
UpgradeMutationDropList.ScrollBarThickness = 4
UpgradeMutationDropList.CanvasSize =
    UDim2.new(0, 0, 0, #UPGRADE_MUTATION_OPTIONS * 26)
UpgradeMutationDropList.ZIndex = 60
UpgradeMutationDropList.Parent = MainFrame
Instance.new("UICorner", UpgradeMutationDropList).CornerRadius = UDim.new(0, 7)

local upgradeMutationListLayout = Instance.new("UIListLayout")
upgradeMutationListLayout.SortOrder = Enum.SortOrder.LayoutOrder
upgradeMutationListLayout.Parent = UpgradeMutationDropList

local function upgradeMutationDisplayName(value)
    if value == "Common" then
        return "Common (No Mutation)"
    end
    return tostring(value)
end

for i, mutationName in ipairs(UPGRADE_MUTATION_OPTIONS) do
    local item = Instance.new("TextButton")
    item.Size = UDim2.new(1, -4, 0, 24)
    item.BackgroundColor3 = Color3.fromRGB(30, 42, 58)
    item.BorderSizePixel = 0
    item.Text = "  " .. upgradeMutationDisplayName(mutationName)
    item.TextColor3 = Color3.fromRGB(220, 232, 245)
    item.TextSize = 11
    item.Font = Enum.Font.Gotham
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.LayoutOrder = i
    item.ZIndex = 61
    item.Parent = UpgradeMutationDropList

    item.MouseButton1Click:Connect(function()
        selectedUpgradeMutation = mutationName
        UpgradeMutationDropBtn.Text =
            "Upgrade Mutation: ▼  "
            .. upgradeMutationDisplayName(mutationName)

        UpgradeMutationDropList.Visible = false

        StatusLabel.Text =
            "Auto Upgrade "
            .. (upgradeEnabled and "ON" or "OFF")
            .. " | Mutation: "
            .. upgradeMutationDisplayName(mutationName)
    end)
end

UpgradeMutationDropBtn.MouseButton1Click:Connect(function()
    UpgradeMutationDropList.Visible =
        not UpgradeMutationDropList.Visible
end)

local LuckyBtn     = createButton("LuckyToggle", 132, "Lucky Block: OFF")

-- ============================================
-- LUCKY BLOCK TYPE FILTER
-- Change this before or while Lucky Block collector is ON.
-- ============================================
local LuckyTypeDropBtn = Instance.new("TextButton")
LuckyTypeDropBtn.Name = "LuckyTypeDrop"
LuckyTypeDropBtn.Size = UDim2.new(0, 220, 0, 30)
LuckyTypeDropBtn.Position = UDim2.new(0, 15, 0, 166)
LuckyTypeDropBtn.BackgroundColor3 = Color3.fromRGB(58, 45, 22)
LuckyTypeDropBtn.BorderSizePixel = 0
LuckyTypeDropBtn.Text = "Lucky Type: ▼  Spain"
LuckyTypeDropBtn.TextColor3 = Color3.fromRGB(255, 214, 125)
LuckyTypeDropBtn.TextSize = 11
LuckyTypeDropBtn.Font = Enum.Font.GothamBold
LuckyTypeDropBtn.ZIndex = 70
LuckyTypeDropBtn.Parent = MainFrame
Instance.new("UICorner", LuckyTypeDropBtn).CornerRadius = UDim.new(0, 8)

local LuckyTypeDropList = Instance.new("ScrollingFrame")
LuckyTypeDropList.Name = "LuckyTypeDropList"
LuckyTypeDropList.Size = UDim2.new(0, 220, 0, 190)
LuckyTypeDropList.Position = UDim2.new(0, 15, 0, 198)
LuckyTypeDropList.BackgroundColor3 = Color3.fromRGB(35, 28, 18)
LuckyTypeDropList.BorderSizePixel = 0
LuckyTypeDropList.Visible = false
LuckyTypeDropList.ScrollBarThickness = 4
LuckyTypeDropList.CanvasSize = UDim2.new(0, 0, 0, #LUCKY_BLOCK_OPTIONS * 26)
LuckyTypeDropList.ZIndex = 80
LuckyTypeDropList.Parent = MainFrame
Instance.new("UICorner", LuckyTypeDropList).CornerRadius = UDim.new(0, 7)

local luckyTypeListLayout = Instance.new("UIListLayout")
luckyTypeListLayout.SortOrder = Enum.SortOrder.LayoutOrder
luckyTypeListLayout.Parent = LuckyTypeDropList

for i, boxType in ipairs(LUCKY_BLOCK_OPTIONS) do
    local item = Instance.new("TextButton")
    item.Size = UDim2.new(1, -4, 0, 24)
    item.BackgroundColor3 = Color3.fromRGB(52, 40, 23)
    item.BorderSizePixel = 0
    item.Text = "  " .. boxType
    item.TextColor3 = Color3.fromRGB(244, 229, 195)
    item.TextSize = 11
    item.Font = Enum.Font.Gotham
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.LayoutOrder = i
    item.ZIndex = 81
    item.Parent = LuckyTypeDropList

    item.MouseButton1Click:Connect(function()
        selectedLuckyBlockType = boxType
        LuckyTypeDropBtn.Text = "Lucky Type: ▼  " .. boxType
        LuckyTypeDropList.Visible = false

        StatusLabel.Text =
            "Lucky Type selected: " .. boxType
    end)
end

LuckyTypeDropBtn.MouseButton1Click:Connect(function()
    UpgradeMutationDropList.Visible = false
    LuckyTypeDropList.Visible = not LuckyTypeDropList.Visible
end)

local RebirthBtn   = createButton("RebirthToggle", 200, "Auto Rebirth: OFF")
local JumpBtn      = createButton("JumpToggle", 234, "Auto +10 Jump: OFF")
local BoxesAutoBtn = createButton("BoxesAutoToggle", 268, "Auto Place+Open Boxes: OFF")
local InvisBtn     = createButton("InvisToggle", 302, "Invis Cloak: OFF")

local PickupBtn    = createButton("PickupBtn", 344, "Pick Up Floor 1 (1-10)")
local PickupAllBtn = createButton("PickupAllBtn", 378, "Pick Up ALL Floors")
local PlaceBtn     = createButton("PlaceBtn", 412, "Place Slimes (CURRENT CASH first)")
local BoxesBtn     = createButton("BoxesBtn", 446, "Place + Open Spain Boxes (Once)")

-- Side-by-side: Place Boxes | Open Boxes
local PlaceBoxesBtn = Instance.new("TextButton")
PlaceBoxesBtn.Name = "PlaceBoxesBtn"
PlaceBoxesBtn.Size = UDim2.new(0, 106, 0, 30)
PlaceBoxesBtn.Position = UDim2.new(0, 15, 0, 480)
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
OpenBoxesBtn.Position = UDim2.new(0, 129, 0, 480)
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
RarityLabel.Position = UDim2.new(0, 15, 0, 518)
RarityLabel.BackgroundTransparency = 1
RarityLabel.Text = "Pick by Rarity / Mutation (Common = None):"
RarityLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
RarityLabel.TextSize = 11
RarityLabel.Font = Enum.Font.Gotham
RarityLabel.TextXAlignment = Enum.TextXAlignment.Left
RarityLabel.Parent = MainFrame

local selectedPickOption = "Spain"
local DropBtn = Instance.new("TextButton")
DropBtn.Name = "RarityDrop"
DropBtn.Size = UDim2.new(0, 140, 0, 28)
DropBtn.Position = UDim2.new(0, 15, 0, 536)
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
PickRarityBtn.Position = UDim2.new(0, 163, 0, 536)
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
DropList.Position = UDim2.new(0, 15, 0, 568)
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
    item.Text = (opt == "Common") and "  Common (No Mutation)" or ("  " .. opt)
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

local MutationDropList

DropBtn.MouseButton1Click:Connect(function()
    if MutationDropList then
        MutationDropList.Visible = false
    end
    if UpgradeMutationDropList then
        UpgradeMutationDropList.Visible = false
    end
    LuckyTypeDropList.Visible = false
    DropList.Visible = not DropList.Visible
end)

-- ============================================
-- DEDICATED PICK BY MUTATION
-- Example: select Cursed -> Pick Up
--          picks every currently placed Cursed slime on all floors.
-- ============================================

local MutationLabel = Instance.new("TextLabel")
MutationLabel.Size = UDim2.new(0, 220, 0, 16)
MutationLabel.Position = UDim2.new(0, 15, 0, 574)
MutationLabel.BackgroundTransparency = 1
MutationLabel.Text = "Place by Mutation:"
MutationLabel.TextColor3 = Color3.fromRGB(210, 180, 255)
MutationLabel.TextSize = 11
MutationLabel.Font = Enum.Font.Gotham
MutationLabel.TextXAlignment = Enum.TextXAlignment.Left
MutationLabel.Parent = MainFrame

local selectedMutation = "Cursed"

local MutationDropBtn = Instance.new("TextButton")
MutationDropBtn.Name = "MutationDrop"
MutationDropBtn.Size = UDim2.new(0, 140, 0, 28)
MutationDropBtn.Position = UDim2.new(0, 15, 0, 592)
MutationDropBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 65)
MutationDropBtn.BorderSizePixel = 0
MutationDropBtn.Text = "▼  " .. selectedMutation
MutationDropBtn.TextColor3 = Color3.fromRGB(225, 205, 255)
MutationDropBtn.TextSize = 12
MutationDropBtn.Font = Enum.Font.GothamBold
MutationDropBtn.Parent = MainFrame
Instance.new("UICorner", MutationDropBtn).CornerRadius = UDim.new(0, 6)

local MutationPickBtn = Instance.new("TextButton")
MutationPickBtn.Name = "MutationPlaceBtn"
MutationPickBtn.Size = UDim2.new(0, 72, 0, 28)
MutationPickBtn.Position = UDim2.new(0, 163, 0, 592)
MutationPickBtn.BackgroundColor3 = Color3.fromRGB(65, 35, 85)
MutationPickBtn.BorderSizePixel = 0
MutationPickBtn.Text = "Place"
MutationPickBtn.TextColor3 = Color3.fromRGB(225, 180, 255)
MutationPickBtn.TextSize = 12
MutationPickBtn.Font = Enum.Font.GothamBold
MutationPickBtn.Parent = MainFrame
Instance.new("UICorner", MutationPickBtn).CornerRadius = UDim.new(0, 6)

MutationDropList = Instance.new("ScrollingFrame")
MutationDropList.Name = "MutationDropList"
MutationDropList.Size = UDim2.new(0, 220, 0, 140)
MutationDropList.Position = UDim2.new(0, 15, 0, 624)
MutationDropList.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
MutationDropList.BorderSizePixel = 0
MutationDropList.Visible = false
MutationDropList.ScrollBarThickness = 4
MutationDropList.CanvasSize = UDim2.new(0, 0, 0, #ALL_MUTATIONS * 26)
MutationDropList.ZIndex = 40
MutationDropList.Parent = MainFrame
Instance.new("UICorner", MutationDropList).CornerRadius = UDim.new(0, 6)

local mutationListLayout = Instance.new("UIListLayout")
mutationListLayout.SortOrder = Enum.SortOrder.LayoutOrder
mutationListLayout.Parent = MutationDropList

for i, mutationName in ipairs(ALL_MUTATIONS) do
    local item = Instance.new("TextButton")
    item.Size = UDim2.new(1, -4, 0, 24)
    item.BackgroundColor3 = Color3.fromRGB(42, 32, 55)
    item.BorderSizePixel = 0
    item.Text = "  " .. mutationName
    item.TextColor3 = Color3.fromRGB(230, 220, 240)
    item.TextSize = 12
    item.Font = Enum.Font.Gotham
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.LayoutOrder = i
    item.ZIndex = 41
    item.Parent = MutationDropList

    item.MouseButton1Click:Connect(function()
        selectedMutation = mutationName
        MutationDropBtn.Text = "▼  " .. mutationName
        MutationDropList.Visible = false
    end)
end

MutationDropBtn.MouseButton1Click:Connect(function()
    DropList.Visible = false
    UpgradeMutationDropList.Visible = false
    LuckyTypeDropList.Visible = false
    MutationDropList.Visible = not MutationDropList.Visible
end)

PickupBtn.TextColor3 = Color3.fromRGB(180, 180, 255)
PickupBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
PickupAllBtn.TextColor3 = Color3.fromRGB(200, 160, 255)
PickupAllBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 70)
PlaceBtn.TextColor3 = Color3.fromRGB(120, 220, 150)
PlaceBtn.BackgroundColor3 = Color3.fromRGB(30, 50, 40)
BoxesBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
BoxesBtn.BackgroundColor3 = Color3.fromRGB(55, 40, 20)

print("[AutoFarm] GUI — SPAIN ONLY + Place/Open burst buttons")

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

-- Robust exact RemoteEvent resolver.
-- The old Place button silently returned when PlaceRemote had not been cached yet.
local function ResolveRemoteEventExact(name)
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name == name then
            return v
        end
    end

    return nil
end

local function ResolvePlaceRemote()
    if PlaceRemote
        and PlaceRemote.Parent
        and PlaceRemote:IsA("RemoteEvent")
    then
        return PlaceRemote
    end

    PlaceRemote = ResolveRemoteEventExact("Place Slime")
    return PlaceRemote
end

local function ResolveUpgradeRemote()
    if UpgradeRemote
        and UpgradeRemote.Parent
        and UpgradeRemote:IsA("RemoteEvent")
    then
        return UpgradeRemote
    end

    -- Prefer exact name first.
    UpgradeRemote = ResolveRemoteEventExact("Upgrade Slime")

    -- Fallback for builds where the name contains extra text.
    if not UpgradeRemote then
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent")
                and string.find(
                    string.lower(v.Name),
                    "upgrade slime",
                    1,
                    true
                )
            then
                UpgradeRemote = v
                break
            end
        end
    end

    return UpgradeRemote
end

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

    StatusLabel.Text =
        "Auto Upgrade "
        .. (on and "ON" or "OFF")
        .. " | Mutation: "
        .. upgradeMutationDisplayName(selectedUpgradeMutation)
end
local function setLuckyState(on)
    luckyEnabled = on
    if on then
        totalCollected = 0
        LuckyBtn.Text = "Lucky Block: ON"
        LuckyBtn.TextColor3 = Color3.fromRGB(255, 200, 80)
        LuckyBtn.BackgroundColor3 = Color3.fromRGB(60, 45, 20)
        StatusLabel.Text =
            "Lucky Block: ON | Type: " .. selectedLuckyBlockType
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
UpgradeBtn.MouseButton1Click:Connect(function()
    setUpgradeState(not upgradeEnabled)

    if upgradeEnabled then
        local remote = ResolveUpgradeRemote()

        if remote then
            print(
                "[AutoUpgrade] ON | Filter:",
                upgradeMutationDisplayName(selectedUpgradeMutation),
                "| Remote:",
                remote:GetFullName()
            )
        else
            warn('[AutoUpgrade] "Upgrade Slime" RemoteEvent not found')
        end
    end
end)
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
    UpgradeRemote     = ResolveUpgradeRemote()
    RebirthRemote     = findRemote("Rebirth")
    JumpUpgradeRemote = findRemote("Buy Speed Upgrade")
    PlaceRemote       = ResolvePlaceRemote()
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
    -- Preferred source: game's local data library.
    if _Lib and _Lib.Data then
        local ok, data = pcall(function()
            return _Lib.Data:Get()
        end)

        if ok and data then
            return data
        end
    end

    -- Same fallback used by the game's own inventory / Equip Best code.
    local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
    local network = sharedModules and sharedModules:FindFirstChild("Network")
    local remotes = network and network:FindFirstChild("Remotes")
    local dataGet = remotes and remotes:FindFirstChild("Data: Get")

    if dataGet and dataGet:IsA("RemoteFunction") then
        local ok, data = pcall(function()
            return dataGet:InvokeServer()
        end)

        if ok and data then
            return data
        end
    end

    -- Broad fallback in case folder names differ in this saved build.
    local candidate = ReplicatedStorage:FindFirstChild("Data: Get", true)

    if candidate and candidate:IsA("RemoteFunction") then
        local ok, data = pcall(function()
            return candidate:InvokeServer()
        end)

        if ok and data then
            return data
        end
    end

    return nil
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

local function getSlotRarityAndMutation(slotName, stand, plotSlimes, liveFolder)
    local rarity, mutation = nil, nil
    local hasEventMutation = false
    local eventMutationNames = {}

    local function addEventMutationName(value)
        if value == nil then return end

        local s = tostring(value)
        local lower = string.lower(s)

        if s ~= ""
            and lower ~= "none"
            and s ~= "{}"
        then
            eventMutationNames[lower] = true
            hasEventMutation = true
        end
    end

    if type(plotSlimes) == "table" then
        local entry = plotSlimes[slotName] or plotSlimes[tostring(slotName)] or plotSlimes[tonumber(slotName)]

        if entry then
            rarity = entry.Rarity or entry.rarity
            mutation = entry.mutation or entry.Mutation

            -- A slime is only considered truly "Common / No Mutation" when
            -- it also has NO event mutations attached to it.
            local eventMutations = entry.event_mutations or entry.EventMutations

            if type(eventMutations) == "table" then
                for k, v in pairs(eventMutations) do
                    -- Support arrays like {"Cosmic"} and maps like {Cosmic=true}.
                    if type(k) == "string" and v == true then
                        addEventMutationName(k)
                    elseif type(v) == "string" then
                        addEventMutationName(v)
                    elseif type(k) == "string" then
                        addEventMutationName(k)
                    end
                end
            elseif eventMutations ~= nil then
                addEventMutationName(eventMutations)
            end

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

        -- Fallback detection for builds that expose event mutations only in the GUI.
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

                -- Event mutation labels are separate from the main Mutation label.
                local parent = d.Parent
                if parent
                    and tostring(parent.Name) == "EventMutations"
                    and d.Visible
                    and d.Text ~= ""
                then
                    addEventMutationName(d.Text)
                end
            end
        end
    end

    if stand then
        if not rarity then rarity = stand:GetAttribute("Rarity") or stand:GetAttribute("rarity") end
        if not mutation then mutation = stand:GetAttribute("mutation") or stand:GetAttribute("Mutation") end
    end

    if mutation ~= nil then
        local mutationText = string.lower(tostring(mutation))

        if mutationText == "none" or mutationText == "" or mutationText == "normal" then
            mutation = nil
        end
    end

    return rarity, mutation, hasEventMutation, eventMutationNames
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

    local filterLower = string.lower(tostring(filterName or ""))

    -- IMPORTANT FOR THIS GUI:
    -- "Common" means a NORMAL slime with NO mutation.
    -- It does NOT mean the database rarity named Common.
    local wantsNoMutation =
        filterLower == "common"
        or filterLower == "none"
        or filterLower == "normal"
        or filterLower == "no mutation"

    local isMutation = wantsNoMutation

    if not isMutation then
        for _, m in ipairs(ALL_MUTATIONS) do
            if string.lower(m) == filterLower then
                isMutation = true
                break
            end
        end
    end

    for _, stand in ipairs(stands:GetChildren()) do
        local name = stand.Name

        if isOccupied(name, plotSlimes, liveFolder, stand) then
            local rarity, mutation, hasEventMutation =
                getSlotRarityAndMutation(name, stand, plotSlimes, liveFolder)

            local match = false

            if wantsNoMutation then
                -- Common / Normal = no base mutation AND no event mutation.
                match = mutation == nil and not hasEventMutation

            elseif isMutation then
                if mutation and string.lower(tostring(mutation)) == filterLower then
                    match = true
                end

            else
                -- Other dropdown entries continue to work as rarities.
                if rarity then
                    local r = tostring(rarity)
                    if r == "Player God" then r = "Slime God" end

                    if string.lower(r) == filterLower then
                        match = true
                    end
                end
            end

            if match then
                table.insert(list, {
                    name = name,
                    num = tonumber(name) or 9999,
                    stand = stand,
                })
            end
        end
    end

    table.sort(list, function(a, b)
        return a.num < b.num
    end)

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

-- Slots that currently hold an unopened Lucky Block
local function getUnopenedLuckyBlockSlots()
    local data = getData()
    local plotSlimes = (data and data.PlotSlimes) or {}
    local list, seen = {}, {}

    local function add(name)
        name = tostring(name)
        if not seen[name] then
            seen[name] = true
            table.insert(list, name)
        end
    end

    if type(plotSlimes) == "table" then
        for k, entry in pairs(plotSlimes) do
            if type(entry) == "table" then
                local typ = tostring(entry.Type or entry.type or "")
                if typ:lower():find("lucky") then
                    add(k)
                end
            end
        end
    end

    -- Fallback: stands with OPEN prompt
    local plot = getMyPlot()
    local stands = plot and plot:FindFirstChild("Stands")
    if stands then
        for _, stand in ipairs(stands:GetChildren()) do
            for _, d in ipairs(stand:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    local at = tostring(d.ActionText or ""):lower()
                    if at:find("open") then
                        add(stand.Name)
                        break
                    end
                end
            end
        end
    end

    return list
end

-- ============================================================
-- CURRENT OWNED SLIME EARNINGS / PLACEMENT PRIORITY
--
-- IMPORTANT:
-- The source of truth is Data.Inventory, NOT Tool attributes.
--
-- This mirrors the game's own "Equip Best" logic:
--   1) Match each current inventory record to its Tool by slimeUID
--   2) Resolve that exact slime definition by inventoryEntry.id
--   3) Use THAT individual slime's inventoryEntry.level
--   4) Apply THAT individual slime's mutation + event_mutations
--   5) Apply current rebirth CashMulti
--   6) Sort the final calculated earnings DESCENDING
--
-- Therefore:
--   A highly-upgraded NORMAL slime can rank above a low-level CURSED slime.
--   Mutation rarity/name does NOT determine placement order.
--   Only the final calculated money generation determines order.
-- ============================================================

local function getInventoryTable(playerData)
    if not playerData then
        return nil
    end

    if type(playerData.Inventory) == "table" then
        return playerData.Inventory
    end

    return nil
end

local function getRebirthCashMultiplier(playerData)
    if not playerData then
        return 1
    end

    local rebirth = playerData.Rebirth
    local rebirths =
        _Lib
        and _Lib.Database
        and _Lib.Database.Rebirths

    if rebirths then
        local def = rebirths[rebirth] or rebirths[tostring(rebirth)]

        if def and tonumber(def.CashMulti) then
            return tonumber(def.CashMulti)
        end
    end

    return 1
end

local function resolveSlimeDefinition(inventoryEntry)
    if type(inventoryEntry) ~= "table" then
        return nil
    end

    local slimeId = inventoryEntry.id or inventoryEntry.Id

    if slimeId == nil
        or not _Lib
        or not _Lib.Database
        or not _Lib.Database.Slimes
    then
        return nil
    end

    local db = _Lib.Database.Slimes

    return db[slimeId]
        or db[tostring(slimeId)]
        or db[tonumber(slimeId)]
end

local function isLuckyInventoryEntry(tool, inventoryEntry, def)
    local function containsBoxWord(value)
        value = string.lower(tostring(value or ""))

        return value:find("lucky block", 1, true) ~= nil
            or value:find("lucky", 1, true) ~= nil
            or value:find("box", 1, true) ~= nil
            or value:find("crate", 1, true) ~= nil
    end

    -- The strongest check is the game's database Type.
    if def then
        if tostring(def.Type or "") == "Lucky Block" then
            return true
        end

        if containsBoxWord(def.Type)
            or containsBoxWord(def.Category)
        then
            return true
        end
    end

    if inventoryEntry then
        if inventoryEntry.production_is_lucky_block == true then
            return true
        end

        if containsBoxWord(inventoryEntry.Type)
            or containsBoxWord(inventoryEntry.type)
            or containsBoxWord(inventoryEntry.Category)
            or containsBoxWord(inventoryEntry.category)
        then
            return true
        end
    end

    if tool then
        if containsBoxWord(tool.Name)
            or containsBoxWord(tool:GetAttribute("Type"))
            or containsBoxWord(tool:GetAttribute("ItemType"))
            or containsBoxWord(tool:GetAttribute("Category"))
        then
            return true
        end

        if tool:GetAttribute("LuckyBlock") == true
            or tool:GetAttribute("IsLuckyBlock") == true
            or tool:GetAttribute("isLuckyBlock") == true
        then
            return true
        end
    end

    return false
end

local function getBaseProductionMPS(inventoryEntry, def)
    -- This is exactly the priority used by the game's own Equip Best:
    -- database MoneyPerSecond first, persisted production fallback second.
    local baseMps = def and tonumber(def.MoneyPerSecond) or nil

    if baseMps == nil and inventoryEntry then
        baseMps =
            tonumber(inventoryEntry.production_mps)
            or tonumber(inventoryEntry.money_per_second)
            or tonumber(inventoryEntry.MoneyPerSecond)
            or tonumber(inventoryEntry.mps)
            or tonumber(inventoryEntry.base_mps)
    end

    return math.max(0, tonumber(baseMps) or 0)
end

local function calculateOwnedSlimeEarnings(inventoryEntry, def, playerData)
    if type(inventoryEntry) ~= "table" then
        return 0
    end

    local baseMps = getBaseProductionMPS(inventoryEntry, def)
    local level = math.max(1, tonumber(inventoryEntry.level) or 1)
    local rebirthMulti = getRebirthCashMultiplier(playerData)

    local earnings = baseMps

    -- Game's own level + rebirth earnings formula.
    if _Lib
        and _Lib.Shared
        and typeof(_Lib.Shared.getRebirthScaledEarnings) == "function"
    then
        local ok, result = pcall(function()
            return _Lib.Shared.getRebirthScaledEarnings(
                baseMps,
                level,
                rebirthMulti
            )
        end)

        if ok and tonumber(result) then
            earnings = tonumber(result)
        end
    end

    -- Game's own mutation calculation.
    local mutation = inventoryEntry.mutation or "None"
    local eventMutations = inventoryEntry.event_mutations or {}
    local mutationMulti = 1

    if _Lib
        and _Lib.Shared
        and typeof(_Lib.Shared.getMutationMulti) == "function"
    then
        local ok, result = pcall(function()
            return _Lib.Shared.getMutationMulti(
                mutation,
                eventMutations
            )
        end)

        if ok and tonumber(result) then
            mutationMulti = tonumber(result)
        end
    end

    earnings = earnings * mutationMulti

    -- These are current global/player production multipliers.
    -- They do not change the relative order because they apply equally
    -- to every owned slime, but applying them makes the debug Cash/s
    -- closer to the game's current production display.
    local inviteBonus = tonumber(playerData and playerData.InviteBonusMult) or 0
    local friendBonus = tonumber(LocalPlayer:GetAttribute("FriendPresenceBonus")) or 0
    local productionBonus = 1 + inviteBonus + friendBonus
    local adminProductionMult =
        tonumber(workspace:GetAttribute("AdminProductionMult")) or 1

    earnings = earnings * productionBonus * adminProductionMult

    earnings = tonumber(earnings) or 0

    if earnings ~= earnings then
        earnings = 0
    end

    return math.max(0, earnings)
end

local function collectCurrentSlimeToolsByUID()
    local toolsByUID = {}

    local function scan(container)
        if not container then
            return
        end

        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local uid = tool:GetAttribute("slimeUID")

                if uid ~= nil then
                    toolsByUID[tostring(uid)] = tool
                end
            end
        end
    end

    scan(LocalPlayer:FindFirstChild("Backpack"))
    scan(LocalPlayer.Character)

    return toolsByUID
end

local function getSlimeTools()
    local playerData = getData()
    local inventory = getInventoryTable(playerData)
    local toolsByUID = collectCurrentSlimeToolsByUID()
    local list = {}

    if type(inventory) ~= "table" then
        warn("[PlaceAll] Data.Inventory unavailable. Current-cash ranking cannot run.")
        return list
    end

    -- CRITICAL CHANGE:
    -- Iterate Data.Inventory FIRST, exactly like the game's own Equip Best.
    -- This guarantees level/mutation belong to the exact slime UID.
    for _, inventoryEntry in ipairs(inventory) do
        if type(inventoryEntry) == "table"
            and inventoryEntry.uid ~= nil
        then
            local uidKey = tostring(inventoryEntry.uid)
            local tool = toolsByUID[uidKey]

            -- Only rank slime records that the player is CURRENTLY holding.
            if tool and tool.Parent then
                local def = resolveSlimeDefinition(inventoryEntry)

                if not isLuckyInventoryEntry(tool, inventoryEntry, def) then
                    local earnings =
                        calculateOwnedSlimeEarnings(
                            inventoryEntry,
                            def,
                            playerData
                        )

                    table.insert(list, {
                        tool = tool,
                        uid = inventoryEntry.uid,
                        id = inventoryEntry.id or inventoryEntry.Id,

                        -- FINAL CURRENT earnings used for sorting.
                        value = earnings,

                        baseMps = getBaseProductionMPS(inventoryEntry, def),
                        level = math.max(
                            1,
                            tonumber(inventoryEntry.level) or 1
                        ),
                        mutation = inventoryEntry.mutation or "None",
                        eventMutations = inventoryEntry.event_mutations or {},
                        displayName =
                            (def and def.Name)
                            or tool.Name
                            or tostring(inventoryEntry.id),
                    })
                else
                    print(
                        "[PlaceAll] SKIP Lucky Box:",
                        tostring(tool.Name),
                        "UID=" .. uidKey
                    )
                end
            end
        end
    end

    -- ABSOLUTE DESCENDING ORDER BY EACH INDIVIDUAL SLIME'S
    -- CURRENT CALCULATED MONEY GENERATION.
    table.sort(list, function(a, b)
        local aCash = tonumber(a.value) or 0
        local bCash = tonumber(b.value) or 0

        if aCash ~= bCash then
            return aCash > bCash
        end

        -- Stable deterministic tie breakers only.
        if (a.level or 1) ~= (b.level or 1) then
            return (a.level or 1) > (b.level or 1)
        end

        return tostring(a.uid) < tostring(b.uid)
    end)

    return list
end

local function normalizeMutationName(mutation)
    mutation = tostring(mutation or "None")
    if mutation == "" then
        mutation = "None"
    end
    return mutation
end

local function getHeldSlimeToolsByMutation(filterMutation)
    local allTools = getSlimeTools()
    local filtered = {}
    local wanted = string.lower(normalizeMutationName(filterMutation))

    for _, entry in ipairs(allTools) do
        local mutation = string.lower(
            normalizeMutationName(entry.mutation)
        )

        if mutation == wanted then
            table.insert(filtered, entry)
        end
    end

    -- STRICT: within the selected mutation, place the slime
    -- with the highest CURRENT calculated cash/s first.
    table.sort(filtered, function(a, b)
        local aCash = tonumber(a.value) or 0
        local bCash = tonumber(b.value) or 0

        if aCash ~= bCash then
            return aCash > bCash
        end

        return tostring(a.uid) < tostring(b.uid)
    end)

    return filtered
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

local function upgradeMutationMatches(
    selected,
    mutation,
    hasEventMutation,
    eventMutationNames
)
    selected = tostring(selected or "All")
    local selectedLower = string.lower(selected)

    if selectedLower == "all" then
        return true
    end

    -- Common in this dropdown means NO mutation at all.
    if selectedLower == "common"
        or selectedLower == "none"
        or selectedLower == "normal"
        or selectedLower == "no mutation"
    then
        return mutation == nil and not hasEventMutation
    end

    if mutation
        and string.lower(tostring(mutation)) == selectedLower
    then
        return true
    end

    if type(eventMutationNames) == "table"
        and eventMutationNames[selectedLower] == true
    then
        return true
    end

    return false
end

local function getStandInfo(stand)
    -- ORIGINAL WORKING AUTO-UPGRADE SCANNER.
    local level =
        stand:GetAttribute("level")
        or stand:GetAttribute("Level")
        or 1

    if level >= MAX_LEVEL then
        return nil
    end

    local slimeId, sellPrice, rarity, model = nil, nil, nil, nil

    if _Lib and _Lib.Data then
        local ok, data = pcall(function()
            return _Lib.Data:Get()
        end)

        if ok and data and data.PlotSlimes then
            local entry =
                data.PlotSlimes[stand.Name]
                or data.PlotSlimes[tostring(stand.Name)]
                or data.PlotSlimes[tonumber(stand.Name)]

            if entry then
                slimeId =
                    entry.id
                    or entry.Id
                    or entry.slimeId
                    or entry.slimeID
            end
        end
    end

    local live = workspace:FindFirstChild("Live")
    local playerSlimes = live and live:FindFirstChild("PlayerSlimes")
    local myFolder =
        playerSlimes
        and playerSlimes:FindFirstChild(LocalPlayer.Name)

    model =
        myFolder
        and (
            myFolder:FindFirstChild(tostring(stand.Name))
            or myFolder:FindFirstChild(stand.Name)
        )

    if model and not slimeId then
        slimeId =
            model:GetAttribute("slimeID")
            or model:GetAttribute("slimeId")
            or model:GetAttribute("id")
            or model:GetAttribute("SlimeId")
    end

    local def = getSlimeDef(slimeId)

    if def then
        rarity = def.Rarity or def.rarity
        sellPrice =
            def.SellPrice
            or (
                def.MoneyPerSecond
                and math.round(def.MoneyPerSecond * 4)
            )
    end

    if not rarity and model then
        rarity = readRarityFromBillboard(model)
    end

    if not rarity and model then
        rarity =
            model:GetAttribute("Rarity")
            or model:GetAttribute("rarity")
    end

    if not rarity then
        rarity =
            stand:GetAttribute("Rarity")
            or stand:GetAttribute("rarity")
    end

    if not sellPrice and model then
        sellPrice =
            model:GetAttribute("SellPrice")
            or model:GetAttribute("sellPrice")
            or (
                model:GetAttribute("MoneyPerSecond")
                and math.round(
                    model:GetAttribute("MoneyPerSecond") * 4
                )
            )
    end

    if not sellPrice then
        sellPrice =
            stand:GetAttribute("SellPrice")
            or stand:GetAttribute("sellPrice")
            or (
                stand:GetAttribute("MoneyPerSecond")
                and math.round(
                    stand:GetAttribute("MoneyPerSecond") * 4
                )
            )
    end

    -- Keep the original script's Spain-only Auto Upgrade scope.
    if not rarity or rarity ~= "Spain" then
        return nil
    end

    if not sellPrice or sellPrice <= 0 then
        return nil
    end

    return {
        stand = stand,
        id = stand.Name,
        level = level,
        cost = getUpgradeCost(sellPrice, level),
        rarity = rarity,
        priority = UPGRADE_PRIORITY[rarity],
        slimeId = slimeId,
    }
end

local function candidateMatchesUpgradeMutation(info)
    -- "All" MUST behave exactly like the old working Auto Upgrade.
    if tostring(selectedUpgradeMutation) == "All" then
        return true
    end

    if not info or not info.stand then
        return false
    end

    local data = getData()
    local plotSlimes = (data and data.PlotSlimes) or {}
    local liveFolder = getPlayerSlimesFolder()

    local ok, rarity, mutation, hasEventMutation, eventMutationNames =
        pcall(
            getSlotRarityAndMutation,
            info.stand.Name,
            info.stand,
            plotSlimes,
            liveFolder
        )

    if not ok then
        warn(
            "[AutoUpgrade] Mutation read failed for slot",
            tostring(info.stand.Name),
            rarity
        )
        return false
    end

    return upgradeMutationMatches(
        selectedUpgradeMutation,
        mutation,
        hasEventMutation,
        eventMutationNames
    )
end

local function getPrioritizedUpgrades()
    local list, seen = {}, {}

    local function scanPlot(plot)
        if not plot then
            return
        end

        local stands = plot:FindFirstChild("Stands")
        if not stands then
            return
        end

        for _, stand in ipairs(stands:GetChildren()) do
            if stand:IsA("Model") and not seen[stand.Name] then
                seen[stand.Name] = true

                -- First run the ORIGINAL working eligibility/cost scanner.
                local info = getStandInfo(stand)

                -- Then apply the mutation dropdown as a narrow final filter.
                if info and candidateMatchesUpgradeMutation(info) then
                    table.insert(list, info)
                end
            end
        end
    end

    if _G.MyPlot then
        scanPlot(_G.MyPlot)
    end

    local plots = workspace:FindFirstChild("Plots")

    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local owner = plot:FindFirstChild("owner")

            if owner and owner.Value == LocalPlayer.Name then
                scanPlot(plot)
            end
        end
    end

    table.sort(list, function(a, b)
        local aCost = tonumber(a.cost) or math.huge
        local bCost = tonumber(b.cost) or math.huge

        -- STRICT PRIORITY:
        -- Always put the slime requiring the LEAST cash for its
        -- NEXT upgrade at the front of the queue.
        if aCost ~= bCost then
            return aCost < bCost
        end

        -- Deterministic tie-breakers only.
        local aLevel = tonumber(a.level) or 1
        local bLevel = tonumber(b.level) or 1

        if aLevel ~= bLevel then
            return aLevel < bLevel
        end

        return tostring(a.id) < tostring(b.id)
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

    local best = nil
    local bestValue = -math.huge
    local bestDistance = math.huge
    local root = getRoot()

    for _, model in ipairs(slimes:GetChildren()) do
        if model:IsA("Model") and not model:GetAttribute("Carrying") then
            local modelName = tostring(model.Name)
            local matches = false

            if selectedLuckyBlockType == "All" then
                -- Only accept the exact Lucky Block models from this game's database.
                for _, names in pairs(LUCKY_BLOCK_MODEL_NAMES) do
                    if names[modelName] == true then
                        matches = true
                        break
                    end
                end
            else
                local allowedNames =
                    LUCKY_BLOCK_MODEL_NAMES[selectedLuckyBlockType]

                matches =
                    allowedNames ~= nil
                    and allowedNames[modelName] == true
            end

            if not matches then
                continue
            end

            local primary =
                model.PrimaryPart
                or model:FindFirstChildWhichIsA("BasePart")

            if not primary then
                continue
            end

            local value =
                tonumber(model:GetAttribute("Value"))
                or tonumber(model:GetAttribute("MoneyPerSecond"))
                or 0

            local distance =
                root and (root.Position - primary.Position).Magnitude
                or math.huge

            local prompt = nil

            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    local at = string.lower(
                        tostring(d.ActionText or "")
                    )

                    if at:find("steal", 1, true)
                        or at:find("open", 1, true)
                        or at:find("pick", 1, true)
                        or at:find("take", 1, true)
                        or not prompt
                    then
                        prompt = d

                        if at:find("steal", 1, true)
                            or at:find("open", 1, true)
                            or at:find("pick", 1, true)
                            or at:find("take", 1, true)
                        then
                            break
                        end
                    end
                end
            end

            -- Within the selected type, prefer the highest value.
            -- For equal values, use the nearest matching block.
            if value > bestValue
                or (value == bestValue and distance < bestDistance)
            then
                bestValue = value
                bestDistance = distance
                best = {
                    name = modelName,
                    type = selectedLuckyBlockType,
                    value = value,
                    part = primary,
                    prompt = prompt,
                    model = model,
                }
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

-- BURST place all Spain boxes (no open)
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

-- BURST open all unopened lucky blocks on plot
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

-- BURST place + open Spain boxes
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

PickRarityBtn.MouseButton1Click:Connect(function()
    if actionBusy or not PickupRemote then return end
    actionBusy = true
    DropList.Visible = false
    PickRarityBtn.Text = "..."
    local filter = selectedPickOption
    local slots = getOccupiedSlotsByFilter(filter)
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

MutationPickBtn.MouseButton1Click:Connect(function()
    if actionBusy then
        StatusLabel.Text = "Another action is still running..."
        return
    end

    local remote = ResolvePlaceRemote()

    if not remote then
        StatusLabel.Text = 'Place error: RemoteEvent "Place Slime" not found'
        return
    end

    actionBusy = true
    MutationDropList.Visible = false
    DropList.Visible = false
    MutationPickBtn.Text = "Placing..."

    local ok, err = xpcall(function()
        local mutationName = selectedMutation

        -- Only CURRENTLY HELD normal slime tools with the selected mutation.
        -- Lucky Boxes are already excluded by getSlimeTools().
        local tools = getHeldSlimeToolsByMutation(mutationName)
        local slots = getAvailableSlots()

        if #tools == 0 then
            error(
                string.format(
                    "No held %s mutation slimes found",
                    mutationName
                )
            )
        end

        if #slots == 0 then
            error("No free slime slots")
        end

        local total = math.min(#tools, #slots)

        -- Lock the selected-mutation ranking for this placement cycle.
        table.sort(tools, function(a, b)
            local aCash = tonumber(a.value) or 0
            local bCash = tonumber(b.value) or 0

            if aCash ~= bCash then
                return aCash > bCash
            end

            return tostring(a.uid) < tostring(b.uid)
        end)

        print("====================================================")
        print(
            "[PlaceMutation]",
            mutationName,
            "- CURRENT CASH DESCENDING"
        )
        print("====================================================")

        for i = 1, total do
            local e = tools[i]
            print(
                string.format(
                    "#%d %s | Cash/s=%.2f | Lv=%d | Mutation=%s | UID=%s -> Slot %s",
                    i,
                    tostring(e.displayName or e.id),
                    tonumber(e.value) or 0,
                    tonumber(e.level) or 1,
                    tostring(e.mutation or "None"),
                    tostring(e.uid),
                    tostring(slots[i] and slots[i].name or "?")
                )
            )
        end

        local placed = 0

        for i = 1, total do
            local rankedEntry = tools[i]
            local slot = slots[i]

            -- Re-find exact physical Tool by slime UID if needed,
            -- but DO NOT recalculate/reorder the locked ranking.
            local tool = rankedEntry.tool

            if not tool or not tool.Parent then
                local currentTools = collectCurrentSlimeToolsByUID()
                tool = currentTools[tostring(rankedEntry.uid)]
            end

            if tool and tool.Parent and slot then
                local latestData = getData()
                local plotSlimes =
                    (latestData and latestData.PlotSlimes) or {}

                if not isOccupied(
                    slot.name,
                    plotSlimes,
                    getPlayerSlimesFolder(),
                    slot.stand
                ) then
                    if equipTool(tool) then
                        local fired, fireErr = pcall(function()
                            remote:FireServer(
                                slot.name,
                                rankedEntry.uid
                            )
                        end)

                        if fired then
                            placed += 1

                            StatusLabel.Text = string.format(
                                "Placed %s %d/%d | %.2f cash/s",
                                mutationName,
                                placed,
                                total,
                                tonumber(rankedEntry.value) or 0
                            )
                        else
                            warn(
                                "[PlaceMutation] Place failed UID",
                                tostring(rankedEntry.uid),
                                fireErr
                            )
                        end

                        task.wait(DELAY_PLACE)
                    end
                end
            else
                warn(
                    "[PlaceMutation] Missing Tool UID",
                    tostring(rankedEntry.uid)
                )
            end

            task.wait(DELAY_NEXT)
        end

        local hum = getHumanoid()
        if hum then
            pcall(function()
                hum:UnequipTools()
            end)
        end

        StatusLabel.Text = string.format(
            "Placed %d × %s mutation slimes",
            placed,
            mutationName
        )
    end, debug.traceback)

    if not ok then
        warn("[PlaceMutation] ERROR:", err)
        StatusLabel.Text =
            "Mutation place error: "
            .. tostring(err):match("^[^\n]+")
    end

    MutationPickBtn.Text = "Place"
    actionBusy = false
end)

PlaceBtn.MouseButton1Click:Connect(function()
    -- Never silently ignore the click.
    if actionBusy then
        StatusLabel.Text = "Another action is still running..."
        return
    end

    actionBusy = true
    PlaceBtn.Text = "Calculating current cash..."
    StatusLabel.Text = "Reading current slime levels / mutations..."

    local ok, err = xpcall(function()
        -- Resolve the remote NOW instead of depending on the startup thread.
        local remote = ResolvePlaceRemote()

        if not remote then
            error('RemoteEvent "Place Slime" was not found')
        end

        local playerData = getData()

        if not playerData then
            error("Player data could not be read")
        end

        if type(playerData.Inventory) ~= "table" then
            error("Data.Inventory is missing")
        end

        local tools = getSlimeTools()
        local slots = getAvailableSlots()

        if #tools == 0 then
            error("No normal slime tools matched your current Data.Inventory. Lucky Boxes are excluded.")
        end

        if #slots == 0 then
            error("No free slime slots")
        end

        local total = math.min(#tools, #slots)

        -- IMPORTANT: re-sort immediately before placement.
        -- This guarantees no earlier code can disturb CURRENT earnings order.
        table.sort(tools, function(a, b)
            local aCash = tonumber(a.value) or 0
            local bCash = tonumber(b.value) or 0

            if aCash ~= bCash then
                return aCash > bCash
            end

            return tostring(a.uid) < tostring(b.uid)
        end)

        print("====================================================")
        print("[PlaceAll] CURRENT OWNED SLIME EARNINGS - DESCENDING")
        print("====================================================")

        for i = 1, total do
            local e = tools[i]

            print(
                string.format(
                    "#%d %s | Current Cash/s=%.2f | Base=%.2f | Lv=%d | Mutation=%s | UID=%s -> Slot %s",
                    i,
                    tostring(e.displayName or e.id),
                    tonumber(e.value) or 0,
                    tonumber(e.baseMps) or 0,
                    tonumber(e.level) or 1,
                    tostring(e.mutation or "None"),
                    tostring(e.uid),
                    tostring(slots[i] and slots[i].name or "?")
                )
            )
        end

        print("====================================================")

        PlaceBtn.Text = "Placing highest current cash..."
        local placed = 0

        for i = 1, total do
            local rankedEntry = tools[i]
            local slot = slots[i]

            -- Re-find the physical Tool by exact UID just before equipping.
            -- Do NOT recalculate/reorder here: preserve the locked descending list.
            local tool = rankedEntry.tool

            if not tool or not tool.Parent then
                local currentTools = collectCurrentSlimeToolsByUID()
                tool = currentTools[tostring(rankedEntry.uid)]
            end

            if tool and tool.Parent and slot then
                local latestData = getData()
                local plotSlimes = (latestData and latestData.PlotSlimes) or {}

                if not isOccupied(
                    slot.name,
                    plotSlimes,
                    getPlayerSlimesFolder(),
                    slot.stand
                ) then
                    if equipTool(tool) then
                        local fired, fireErr = pcall(function()
                            remote:FireServer(slot.name, rankedEntry.uid)
                        end)

                        if fired then
                            placed += 1

                            StatusLabel.Text = string.format(
                                "Placed #%d/%d | %.2f cash/s -> slot %s",
                                i,
                                total,
                                tonumber(rankedEntry.value) or 0,
                                tostring(slot.name)
                            )
                        else
                            warn(
                                "[PlaceAll] Place failed UID",
                                rankedEntry.uid,
                                fireErr
                            )
                        end

                        task.wait(DELAY_PLACE)
                    end
                end
            else
                warn(
                    "[PlaceAll] Missing Tool for UID",
                    tostring(rankedEntry.uid)
                )
            end

            task.wait(DELAY_NEXT)
        end

        local hum = getHumanoid()
        if hum then
            pcall(function()
                hum:UnequipTools()
            end)
        end

        StatusLabel.Text = string.format(
            "Placed %d/%d — CURRENT cash descending",
            placed,
            total
        )
    end, debug.traceback)

    if not ok then
        warn("[PlaceAll] ERROR:", err)
        StatusLabel.Text = "Place error: " .. tostring(err):match("^[^\n]+")
    end

    -- ALWAYS restore the button and busy state, even after an exception.
    PlaceBtn.Text = "Place Slimes (CURRENT CASH first)"
    actionBusy = false
end)

BoxesBtn.MouseButton1Click:Connect(function()
    if actionBusy then return end
    actionBusy = true
    BoxesBtn.Text = "Burst..."
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
        if upgradeEnabled then
            local ok, err = xpcall(function()
                local remote = ResolveUpgradeRemote()

                if not remote then
                    StatusLabel.Text =
                        'Auto Upgrade: "Upgrade Slime" remote not found'
                    return
                end

                local filterAtDecision = selectedUpgradeMutation

                -- IMPORTANT:
                -- Rebuild the full eligible list before EVERY SINGLE upgrade.
                -- getPrioritizedUpgrades() sorts by current next-upgrade cost,
                -- so upgrades[1] is always the cheapest slime RIGHT NOW.
                local upgrades = getPrioritizedUpgrades()

                if #upgrades == 0 then
                    StatusLabel.Text = string.format(
                        "Auto Upgrade ON | %s | No eligible Spain slime",
                        upgradeMutationDisplayName(filterAtDecision)
                    )
                    return
                end

                local cheapest = upgrades[1]
                local cash = getCash()
                local cost = tonumber(cheapest.cost) or math.huge

                -- If the cheapest candidate is not affordable, then none
                -- of the more expensive candidates should be upgraded.
                if cost > cash then
                    StatusLabel.Text = string.format(
                        "Auto Upgrade [%s] | Cheapest $%s | Cash $%s",
                        upgradeMutationDisplayName(filterAtDecision),
                        tostring(math.floor(cost)),
                        tostring(math.floor(cash))
                    )
                    return
                end

                -- If the dropdown changed after the list was built,
                -- do not spend cash on a stale candidate.
                if filterAtDecision ~= selectedUpgradeMutation then
                    return
                end

                local fired, fireErr = pcall(function()
                    remote:FireServer(cheapest.id)
                end)

                if not fired then
                    warn(
                        "[AutoUpgrade] FireServer failed:",
                        tostring(cheapest.id),
                        fireErr
                    )
                    return
                end

                StatusLabel.Text = string.format(
                    "Upgraded cheapest [%s] | Slot %s | Cost $%s | Lv%d",
                    upgradeMutationDisplayName(filterAtDecision),
                    tostring(cheapest.id),
                    tostring(math.floor(cost)),
                    tonumber(cheapest.level) or 1
                )

                -- Allow the server/data to update the slime level and its
                -- NEXT upgrade cost before we make the next decision.
                task.wait(UPGRADE_DELAY)
            end, debug.traceback)

            if not ok then
                warn("[AutoUpgrade] ERROR:", err)

                StatusLabel.Text =
                    "Auto Upgrade error: "
                    .. tostring(err):match("^[^\\n]+")
            end

            -- Fast re-scan after each decision. If an upgrade happened,
            -- its new higher cost will be included in the next ranking.
            task.wait(0.05)
        else
            task.wait(UPGRADE_SCAN)
        end
    end
end)

task.spawn(function()
    while true do
        if luckyEnabled and not luckyBlockBusy then
            luckyBlockBusy = true

            -- If we are already carrying a stolen Lucky Block,
            -- finish returning/depositing it before looking for another.
            if LocalPlayer:GetAttribute("holdingSlime") == true then
                StatusLabel.Text = "Lucky Block: carrying -> returning to base"
                teleportToBase()
                task.wait(0.35)

                local depositDeadline = os.clock() + 5
                while luckyEnabled
                    and LocalPlayer:GetAttribute("holdingSlime") == true
                    and os.clock() < depositDeadline
                do
                    task.wait(0.10)
                end

                luckyBlockBusy = false
                task.wait(0.10)
                continue
            end

            local block = getTargetLuckyBlock()

            if not block then
                StatusLabel.Text = string.format(
                    "No Spain boxes | Total: %d",
                    totalCollected
                )
                luckyBlockBusy = false
                task.wait(0.50)
                continue
            end

            -- ===================================================
            -- REQUIRED ORDER:
            -- 1) Turn invisibility ON
            -- 2) Verify local invisibility
            -- 3) Teleport to Lucky Block
            -- 4) Pick it up / retry
            -- 5) Wait until holdingSlime == true
            -- 6) ONLY THEN return to base
            -- ===================================================

            StatusLabel.Text = "Lucky Block: turning invisibility ON..."

            local cloakReady = false

            for invisTry = 1, 4 do
                if activateCloak() then
                    task.wait(0.20)

                    local char = LocalPlayer.Character
                    local invisible = char ~= nil
                    local visiblePartFound = false

                    if char then
                        for _, obj in ipairs(char:GetDescendants()) do
                            if obj:IsA("BasePart")
                                and obj.Name ~= "HumanoidRootPart"
                                and obj.Transparency < 0.95
                            then
                                visiblePartFound = true
                                break
                            end
                        end
                    end

                    invisible = invisible and not visiblePartFound

                    if invisible then
                        cloakReady = true
                        break
                    end
                end

                StatusLabel.Text = string.format(
                    "Lucky Block: invis retry %d/4",
                    invisTry
                )

                task.wait(0.15)
            end

            if not cloakReady then
                StatusLabel.Text =
                    "Lucky Block: invisibility could not be confirmed"
                luckyBlockBusy = false
                task.wait(0.50)
                continue
            end

            local root = getRoot()

            if not root
                or not block.part
                or not block.part.Parent
            then
                StatusLabel.Text = "Lucky Block: target disappeared"
                luckyBlockBusy = false
                task.wait(0.25)
                continue
            end

            -- Go to the Lucky Block only after invisibility is confirmed.
            root.CFrame = block.part.CFrame * CFrame.new(0, 3, 4)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            task.wait(0.18)

            local collected = false

            for pickupTry = 1, 5 do
                if not luckyEnabled then
                    break
                end

                -- Game's actual success state.
                if LocalPlayer:GetAttribute("holdingSlime") == true then
                    collected = true
                    break
                end

                -- Re-assert invisibility before every retry.
                activateCloak()
                task.wait(0.12)

                -- Stay beside the same target while retrying.
                if block.part and block.part.Parent then
                    local retryRoot = getRoot()

                    if retryRoot then
                        retryRoot.CFrame =
                            block.part.CFrame * CFrame.new(0, 3, 4)

                        retryRoot.AssemblyLinearVelocity = Vector3.zero
                        retryRoot.AssemblyAngularVelocity = Vector3.zero
                    end
                end

                -- Re-find a live prompt every attempt.
                local prompt = nil

                if block.model and block.model.Parent then
                    for _, d in ipairs(block.model:GetDescendants()) do
                        if d:IsA("ProximityPrompt") and d.Enabled then
                            local action =
                                string.lower(
                                    tostring(d.ActionText or "")
                                )

                            if action:find("steal", 1, true)
                                or action:find("pick", 1, true)
                                or action:find("take", 1, true)
                                or action:find("open", 1, true)
                            then
                                prompt = d
                                break
                            end

                            if not prompt then
                                prompt = d
                            end
                        end
                    end
                end

                prompt = prompt or block.prompt

                if prompt and prompt.Parent then
                    StatusLabel.Text = string.format(
                        "Lucky Block: pickup attempt %d/5",
                        pickupTry
                    )

                    attemptSteal(prompt)

                    -- DO NOT return home based on attemptSteal().
                    -- Wait for the game's own holding state instead.
                    local pickupDeadline = os.clock() + 1.50

                    while luckyEnabled
                        and os.clock() < pickupDeadline
                    do
                        if LocalPlayer:GetAttribute("holdingSlime") == true then
                            collected = true
                            break
                        end

                        task.wait(0.05)
                    end

                    if collected then
                        break
                    end
                else
                    StatusLabel.Text = string.format(
                        "Lucky Block: prompt missing %d/5",
                        pickupTry
                    )
                end

                task.wait(0.20)
            end

            if not collected then
                -- Failed pickup: DO NOT teleport home.
                StatusLabel.Text =
                    "Lucky Block: pickup not confirmed - retrying"
                luckyBlockBusy = false
                task.wait(0.25)
                continue
            end

            totalCollected += 1

            StatusLabel.Text = string.format(
                "✓ Lucky Block confirmed (#%d) -> Base",
                totalCollected
            )

            -- ONLY NOW, after holdingSlime is true, return to base.
            teleportToBase()
            task.wait(0.35)

            -- Wait for deposit/release before searching for the next block.
            local clearDeadline = os.clock() + 5

            while luckyEnabled
                and LocalPlayer:GetAttribute("holdingSlime") == true
                and os.clock() < clearDeadline
            do
                task.wait(0.10)
            end

            if LocalPlayer:GetAttribute("holdingSlime") == true then
                StatusLabel.Text =
                    "Lucky Block: still carrying at base - retrying base"
            else
                StatusLabel.Text = string.format(
                    "✓ Deposited (#%d) | finding next...",
                    totalCollected
                )
            end

            luckyBlockBusy = false
        end

        task.wait(0.10)
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
print("[AutoFarm] SPAIN ONLY upgrade + steal + place/open")
print("Place Boxes = burst place only | Open Boxes = burst open only")
print("Commands: stopAll() | goToBase()")
print("========================================")
