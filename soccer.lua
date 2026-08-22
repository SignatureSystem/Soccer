-- Combined Script: ICONS UPDATE + BATCH-10 Auto Upgrade + FILTERED Lucky Block Collector
-- + selected-type Lucky Block Place + OPEN ALL active boxes + 10-slot Pickup Range + Place-by-Mutation + CURRENT INDIVIDUAL earnings desc + Invis
-- + expandable right-side Gift All inventory panel + Auto Accept Gifts + Pick Lowest Profit by count
-- + WORKING Lucky Box collector preserved; invisibility is best-effort/non-blocking
-- + UPDATED: Japan Lucky Block support, full mutation list, latest rarity values

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
local GIFT_REPEAT_INTERVAL = 1.25 -- re-send remaining inventory while Gift All stays ON
local AUTO_ACCEPT_GIFT_INTERVAL = 0.50 -- matches the game's native Accept button cooldown

local DELAY_EQUIP = 0.12
local DELAY_PLACE = 0.22
local DELAY_NEXT  = 0.12
local DELAY_PICK  = 0.12
local IGNORE_LOCK = true

-- Newest high tiers. Actual Auto Upgrade ordering remains cheapest-next-upgrade first.
local UPGRADE_PRIORITY = { ["Icons"] = 1, ["Spain"] = 2, ["Japan"] = 3 }
local TARGET_RARITIES  = { ["Icons"] = true, ["Spain"] = true, ["Japan"] = true }

-- UPDATED: Full rarity values matching the game
local RARITY_VALUE = {
    ["Japan"] = 7000000,
    ["Icons"] = 5000000,
    ["Spain"] = 2500000,
    ["Champions"] = 1000000,
    ["OG"] = 500000,
    ["Exclusive"] = 75000,
    ["LIMITED"] = 75000,
    ["Divine"] = 50000,
    ["Slime God"] = 30000,
    ["Secret"] = 10000,
    ["Mythic"] = 2500,
    ["Legendary"] = 750,
    ["Epic"] = 250,
    ["Rare"] = 100,
    ["Common"] = 25,
}

local ALL_RARITIES = {
    "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret",
    "Slime God", "Divine", "Exclusive", "LIMITED", "OG", "Champions",
    "Spain", "Icons", "Japan",
}

-- UPDATED: Full mutation list including all game mutations
local ALL_MUTATIONS = {
    "Golden", "Diamond", "Rainbow", "Cursed", "Divine", "Fallen",
    "Volcanic", "Toxic", "Taco", "Cosmic", "Slimey",
}
local PICK_OPTIONS = {}
for _, r in ipairs(ALL_RARITIES) do table.insert(PICK_OPTIONS, r) end
for _, m in ipairs(ALL_MUTATIONS) do table.insert(PICK_OPTIONS, m) end

-- Auto Upgrade RARITY filter.
-- "All" = every rarity.
local UPGRADE_RARITY_OPTIONS = {
    "All",
    "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret",
    "Slime God", "Divine", "Exclusive", "LIMITED", "OG", "Champions",
    "Spain", "Icons", "Japan",
}

local selectedUpgradeRarity = "All"

-- Auto Upgrade MUTATION filter.
-- "All" = any mutation.
-- "Common" is displayed as "Common (No Mutation)" and means
-- NO base mutation AND NO event mutation.
local UPGRADE_MUTATION_OPTIONS = { "All", "Common" }
for _, mutationName in ipairs(ALL_MUTATIONS) do
    table.insert(UPGRADE_MUTATION_OPTIONS, mutationName)
end

local selectedUpgradeMutation = "All"

-- UPDATED: Full Lucky Block types including Japan
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
    "Icons",
    "Japan",
}

-- UPDATED: Full Lucky Block model name mappings including Japan
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
    ["Icons"] = { ["Icons Lucky Block"] = true },
    ["Japan"] = { ["Japan Lucky Block"] = true },
}

-- Default to the newest live tier.
local selectedLuckyBlockType = "Icons"

-- Gift All state is declared before GUI construction so the side panel
-- and the worker loop share the same locals.
local giftAllEnabled = false
local giftTargetName = nil
local giftInFlight = {}
local autoAcceptGiftsEnabled = false
local pendingGiftUID = nil
local lastAcceptedGiftUID = nil
local lastAcceptedGiftAt = 0

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

-- ============================================
-- EXPANDABLE RIGHT-SIDE MENU: GIFT ALL
-- Collapsed by default.  The arrow moves with the main draggable frame.
-- ============================================
local SideArrowBtn = Instance.new("TextButton")
SideArrowBtn.Name = "SideArrow"
SideArrowBtn.Size = UDim2.new(0, 24, 0, 44)
SideArrowBtn.Position = UDim2.new(1, 4, 0, 36)
SideArrowBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
SideArrowBtn.BorderSizePixel = 0
SideArrowBtn.Text = ">"
SideArrowBtn.TextColor3 = Color3.fromRGB(220, 220, 235)
SideArrowBtn.TextSize = 18
SideArrowBtn.Font = Enum.Font.GothamBold
SideArrowBtn.ZIndex = 120
SideArrowBtn.Parent = MainFrame
Instance.new("UICorner", SideArrowBtn).CornerRadius = UDim.new(0, 7)
local sideArrowStroke = Instance.new("UIStroke", SideArrowBtn)
sideArrowStroke.Color = Color3.fromRGB(80, 80, 100)
sideArrowStroke.Thickness = 1.5

local GiftPanel = Instance.new("Frame")
GiftPanel.Name = "GiftPanel"
GiftPanel.Size = UDim2.new(0, 220, 0, 286)
GiftPanel.Position = UDim2.new(1, 32, 0, 36)
GiftPanel.BackgroundColor3 = Color3.fromRGB(24, 24, 31)
GiftPanel.BackgroundTransparency = 0.03
GiftPanel.BorderSizePixel = 0
GiftPanel.Visible = false
GiftPanel.ZIndex = 115
GiftPanel.Parent = MainFrame
Instance.new("UICorner", GiftPanel).CornerRadius = UDim.new(0, 9)
local giftPanelStroke = Instance.new("UIStroke", GiftPanel)
giftPanelStroke.Color = Color3.fromRGB(85, 85, 108)
giftPanelStroke.Thickness = 1.5

local GiftTitle = Instance.new("TextLabel")
GiftTitle.Size = UDim2.new(1, -20, 0, 26)
GiftTitle.Position = UDim2.new(0, 10, 0, 6)
GiftTitle.BackgroundTransparency = 1
GiftTitle.Text = "Gift Inventory"
GiftTitle.TextColor3 = Color3.fromRGB(245, 245, 250)
GiftTitle.TextSize = 13
GiftTitle.Font = Enum.Font.GothamBold
GiftTitle.TextXAlignment = Enum.TextXAlignment.Left
GiftTitle.ZIndex = 116
GiftTitle.Parent = GiftPanel

local GiftNameBox = Instance.new("TextBox")
GiftNameBox.Name = "PlayerName"
GiftNameBox.Size = UDim2.new(1, -20, 0, 32)
GiftNameBox.Position = UDim2.new(0, 10, 0, 36)
GiftNameBox.BackgroundColor3 = Color3.fromRGB(37, 37, 48)
GiftNameBox.BorderSizePixel = 0
GiftNameBox.PlaceholderText = "Player username..."
GiftNameBox.Text = ""
GiftNameBox.ClearTextOnFocus = false
GiftNameBox.TextColor3 = Color3.fromRGB(245, 245, 250)
GiftNameBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 155)
GiftNameBox.TextSize = 12
GiftNameBox.Font = Enum.Font.Gotham
GiftNameBox.ZIndex = 116
GiftNameBox.Parent = GiftPanel
Instance.new("UICorner", GiftNameBox).CornerRadius = UDim.new(0, 7)

local GiftAllBtn = Instance.new("TextButton")
GiftAllBtn.Name = "GiftAllToggle"
GiftAllBtn.Size = UDim2.new(1, -20, 0, 32)
GiftAllBtn.Position = UDim2.new(0, 10, 0, 75)
GiftAllBtn.BackgroundColor3 = Color3.fromRGB(52, 38, 42)
GiftAllBtn.BorderSizePixel = 0
GiftAllBtn.Text = "Gift All: OFF"
GiftAllBtn.TextColor3 = Color3.fromRGB(255, 105, 115)
GiftAllBtn.TextSize = 12
GiftAllBtn.Font = Enum.Font.GothamBold
GiftAllBtn.ZIndex = 116
GiftAllBtn.Parent = GiftPanel
Instance.new("UICorner", GiftAllBtn).CornerRadius = UDim.new(0, 7)

local GiftStatus = Instance.new("TextLabel")
GiftStatus.Size = UDim2.new(1, -20, 0, 42)
GiftStatus.Position = UDim2.new(0, 10, 0, 113)
GiftStatus.BackgroundTransparency = 1
GiftStatus.Text = "Enter a player in this server."
GiftStatus.TextColor3 = Color3.fromRGB(185, 185, 200)
GiftStatus.TextSize = 10
GiftStatus.Font = Enum.Font.Gotham
GiftStatus.TextWrapped = true
GiftStatus.TextXAlignment = Enum.TextXAlignment.Left
GiftStatus.TextYAlignment = Enum.TextYAlignment.Top
GiftStatus.ZIndex = 116
GiftStatus.Parent = GiftPanel

-- ============================================
-- LOWEST-PROFIT PICKUP CONTROL
-- Enter a count, then pick that many currently placed normal players
-- starting with the LOWEST calculated current cash/s.
-- ============================================
local LowestProfitLabel = Instance.new("TextLabel")
LowestProfitLabel.Name = "LowestProfitLabel"
LowestProfitLabel.Size = UDim2.new(1, -20, 0, 16)
LowestProfitLabel.Position = UDim2.new(0, 10, 0, 157)
LowestProfitLabel.BackgroundTransparency = 1
LowestProfitLabel.Text = "Pick lowest-profit players:"
LowestProfitLabel.TextColor3 = Color3.fromRGB(200, 200, 215)
LowestProfitLabel.TextSize = 10
LowestProfitLabel.Font = Enum.Font.Gotham
LowestProfitLabel.TextXAlignment = Enum.TextXAlignment.Left
LowestProfitLabel.ZIndex = 116
LowestProfitLabel.Parent = GiftPanel

local LowestProfitCountBox = Instance.new("TextBox")
LowestProfitCountBox.Name = "LowestProfitCount"
LowestProfitCountBox.Size = UDim2.new(0, 54, 0, 30)
LowestProfitCountBox.Position = UDim2.new(0, 10, 0, 176)
LowestProfitCountBox.BackgroundColor3 = Color3.fromRGB(37, 37, 48)
LowestProfitCountBox.BorderSizePixel = 0
LowestProfitCountBox.PlaceholderText = "Count"
LowestProfitCountBox.Text = "10"
LowestProfitCountBox.ClearTextOnFocus = false
LowestProfitCountBox.TextColor3 = Color3.fromRGB(245, 245, 250)
LowestProfitCountBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 155)
LowestProfitCountBox.TextSize = 12
LowestProfitCountBox.Font = Enum.Font.GothamBold
LowestProfitCountBox.ZIndex = 116
LowestProfitCountBox.Parent = GiftPanel
Instance.new("UICorner", LowestProfitCountBox).CornerRadius = UDim.new(0, 7)

local PickLowestProfitBtn = Instance.new("TextButton")
PickLowestProfitBtn.Name = "PickLowestProfitBtn"
PickLowestProfitBtn.Size = UDim2.new(0, 140, 0, 30)
PickLowestProfitBtn.Position = UDim2.new(0, 70, 0, 176)
PickLowestProfitBtn.BackgroundColor3 = Color3.fromRGB(38, 48, 62)
PickLowestProfitBtn.BorderSizePixel = 0
PickLowestProfitBtn.Text = "Pick Lowest Profit"
PickLowestProfitBtn.TextColor3 = Color3.fromRGB(165, 210, 255)
PickLowestProfitBtn.TextSize = 10
PickLowestProfitBtn.Font = Enum.Font.GothamBold
PickLowestProfitBtn.ZIndex = 116
PickLowestProfitBtn.Parent = GiftPanel
Instance.new("UICorner", PickLowestProfitBtn).CornerRadius = UDim.new(0, 7)

local LowestProfitStatus = Instance.new("TextLabel")
LowestProfitStatus.Name = "LowestProfitStatus"
LowestProfitStatus.Size = UDim2.new(1, -20, 0, 30)
LowestProfitStatus.Position = UDim2.new(0, 10, 0, 211)
LowestProfitStatus.BackgroundTransparency = 1
LowestProfitStatus.Text = "Lowest cash/s first."
LowestProfitStatus.TextColor3 = Color3.fromRGB(165, 165, 180)
LowestProfitStatus.TextSize = 9
LowestProfitStatus.Font = Enum.Font.Gotham
LowestProfitStatus.TextWrapped = true
LowestProfitStatus.TextXAlignment = Enum.TextXAlignment.Left
LowestProfitStatus.TextYAlignment = Enum.TextYAlignment.Top
LowestProfitStatus.ZIndex = 116
LowestProfitStatus.Parent = GiftPanel

-- ============================================
-- AUTO ACCEPT INCOMING GIFTS
-- The game receives Gift Slime Request("send", data), stores data.uid as
-- slimeUID on its gifting frame, and Accept calls Accept Gift(slimeUID).
-- ============================================
local AutoAcceptGiftBtn = Instance.new("TextButton")
AutoAcceptGiftBtn.Name = "AutoAcceptGiftToggle"
AutoAcceptGiftBtn.Size = UDim2.new(1, -20, 0, 30)
AutoAcceptGiftBtn.Position = UDim2.new(0, 10, 0, 248)
AutoAcceptGiftBtn.BackgroundColor3 = Color3.fromRGB(52, 38, 42)
AutoAcceptGiftBtn.BorderSizePixel = 0
AutoAcceptGiftBtn.Text = "Auto Accept Gifts: OFF"
AutoAcceptGiftBtn.TextColor3 = Color3.fromRGB(255, 105, 115)
AutoAcceptGiftBtn.TextSize = 11
AutoAcceptGiftBtn.Font = Enum.Font.GothamBold
AutoAcceptGiftBtn.ZIndex = 116
AutoAcceptGiftBtn.Parent = GiftPanel
Instance.new("UICorner", AutoAcceptGiftBtn).CornerRadius = UDim.new(0, 7)

LowestProfitCountBox.FocusLost:Connect(function()
    local count = math.floor(tonumber(LowestProfitCountBox.Text) or 0)
    if count < 1 then
        count = 1
    end
    LowestProfitCountBox.Text = tostring(count)
end)

SideArrowBtn.MouseButton1Click:Connect(function()
    GiftPanel.Visible = not GiftPanel.Visible
    SideArrowBtn.Text = GiftPanel.Visible and "<" or ">"
end)

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
-- AUTO UPGRADE RARITY + MUTATION FILTERS
-- Both selections are read live by Auto Upgrade.

-- Forward declaration is required because the Auto Upgrade dropdown
-- click callbacks also close the Lucky Type dropdown, which is built
-- slightly later in the GUI.
local LuckyTypeDropList
local PickupRangeDropList
-- Example:
--   Rarity = Champions
--   Mutation = Cosmic
-- -> only Cosmic Champions are eligible.
-- ============================================

local UpgradeRarityDropBtn = Instance.new("TextButton")
UpgradeRarityDropBtn.Name = "UpgradeRarityDrop"
UpgradeRarityDropBtn.Size = UDim2.new(0, 106, 0, 30)
UpgradeRarityDropBtn.Position = UDim2.new(0, 15, 0, 98)
UpgradeRarityDropBtn.BackgroundColor3 = Color3.fromRGB(28, 42, 62)
UpgradeRarityDropBtn.BorderSizePixel = 0
UpgradeRarityDropBtn.Text = "Rarity: ▼ All"
UpgradeRarityDropBtn.TextColor3 = Color3.fromRGB(150, 205, 255)
UpgradeRarityDropBtn.TextSize = 10
UpgradeRarityDropBtn.Font = Enum.Font.GothamBold
UpgradeRarityDropBtn.ZIndex = 50
UpgradeRarityDropBtn.Parent = MainFrame
Instance.new("UICorner", UpgradeRarityDropBtn).CornerRadius = UDim.new(0, 8)

local UpgradeMutationDropBtn = Instance.new("TextButton")
UpgradeMutationDropBtn.Name = "UpgradeMutationDrop"
UpgradeMutationDropBtn.Size = UDim2.new(0, 106, 0, 30)
UpgradeMutationDropBtn.Position = UDim2.new(0, 129, 0, 98)
UpgradeMutationDropBtn.BackgroundColor3 = Color3.fromRGB(48, 34, 62)
UpgradeMutationDropBtn.BorderSizePixel = 0
UpgradeMutationDropBtn.Text = "Mutation: ▼ All"
UpgradeMutationDropBtn.TextColor3 = Color3.fromRGB(220, 180, 255)
UpgradeMutationDropBtn.TextSize = 10
UpgradeMutationDropBtn.Font = Enum.Font.GothamBold
UpgradeMutationDropBtn.ZIndex = 50
UpgradeMutationDropBtn.Parent = MainFrame
Instance.new("UICorner", UpgradeMutationDropBtn).CornerRadius = UDim.new(0, 8)

local UpgradeRarityDropList = Instance.new("ScrollingFrame")
UpgradeRarityDropList.Name = "UpgradeRarityDropList"
UpgradeRarityDropList.Size = UDim2.new(0, 220, 0, 180)
UpgradeRarityDropList.Position = UDim2.new(0, 15, 0, 130)
UpgradeRarityDropList.BackgroundColor3 = Color3.fromRGB(20, 28, 40)
UpgradeRarityDropList.BorderSizePixel = 0
UpgradeRarityDropList.Visible = false
UpgradeRarityDropList.ScrollBarThickness = 4
UpgradeRarityDropList.CanvasSize =
    UDim2.new(0, 0, 0, #UPGRADE_RARITY_OPTIONS * 26)
UpgradeRarityDropList.ZIndex = 60
UpgradeRarityDropList.Parent = MainFrame
Instance.new("UICorner", UpgradeRarityDropList).CornerRadius = UDim.new(0, 7)

local upgradeRarityListLayout = Instance.new("UIListLayout")
upgradeRarityListLayout.SortOrder = Enum.SortOrder.LayoutOrder
upgradeRarityListLayout.Parent = UpgradeRarityDropList

local UpgradeMutationDropList = Instance.new("ScrollingFrame")
UpgradeMutationDropList.Name = "UpgradeMutationDropList"
UpgradeMutationDropList.Size = UDim2.new(0, 220, 0, 180)
UpgradeMutationDropList.Position = UDim2.new(0, 15, 0, 130)
UpgradeMutationDropList.BackgroundColor3 = Color3.fromRGB(32, 22, 42)
UpgradeMutationDropList.BorderSizePixel = 0
UpgradeMutationDropList.Visible = false
UpgradeMutationDropList.ScrollBarThickness = 4
UpgradeMutationDropList.CanvasSize =
    UDim2.new(0, 0, 0, #UPGRADE_MUTATION_OPTIONS * 26)
UpgradeMutationDropList.ZIndex = 65
UpgradeMutationDropList.Parent = MainFrame
Instance.new("UICorner", UpgradeMutationDropList).CornerRadius = UDim.new(0, 7)

local upgradeMutationListLayout = Instance.new("UIListLayout")
upgradeMutationListLayout.SortOrder = Enum.SortOrder.LayoutOrder
upgradeMutationListLayout.Parent = UpgradeMutationDropList

local function upgradeRarityDisplayName(value)
    return tostring(value)
end

local function upgradeMutationDisplayName(value)
    if tostring(value) == "Common" then
        return "Common (No Mutation)"
    end
    return tostring(value)
end

for i, rarityName in ipairs(UPGRADE_RARITY_OPTIONS) do
    local item = Instance.new("TextButton")
    item.Size = UDim2.new(1, -4, 0, 24)
    item.BackgroundColor3 = Color3.fromRGB(30, 42, 58)
    item.BorderSizePixel = 0
    item.Text = "  " .. upgradeRarityDisplayName(rarityName)
    item.TextColor3 = Color3.fromRGB(220, 232, 245)
    item.TextSize = 11
    item.Font = Enum.Font.Gotham
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.LayoutOrder = i
    item.ZIndex = 61
    item.Parent = UpgradeRarityDropList

    item.MouseButton1Click:Connect(function()
        selectedUpgradeRarity = rarityName
        UpgradeRarityDropBtn.Text =
            "Rarity: ▼ " .. upgradeRarityDisplayName(rarityName)

        UpgradeRarityDropList.Visible = false

        StatusLabel.Text =
            "Auto Upgrade | Rarity: "
            .. upgradeRarityDisplayName(selectedUpgradeRarity)
            .. " | Mutation: "
            .. upgradeMutationDisplayName(selectedUpgradeMutation)
    end)
end

for i, mutationName in ipairs(UPGRADE_MUTATION_OPTIONS) do
    local item = Instance.new("TextButton")
    item.Size = UDim2.new(1, -4, 0, 24)
    item.BackgroundColor3 = Color3.fromRGB(45, 31, 58)
    item.BorderSizePixel = 0
    item.Text = "  " .. upgradeMutationDisplayName(mutationName)
    item.TextColor3 = Color3.fromRGB(235, 220, 248)
    item.TextSize = 11
    item.Font = Enum.Font.Gotham
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.LayoutOrder = i
    item.ZIndex = 66
    item.Parent = UpgradeMutationDropList

    item.MouseButton1Click:Connect(function()
        selectedUpgradeMutation = mutationName

        local shortName =
            mutationName == "Common"
            and "No Mutation"
            or tostring(mutationName)

        UpgradeMutationDropBtn.Text =
            "Mutation: ▼ " .. shortName

        UpgradeMutationDropList.Visible = false

        StatusLabel.Text =
            "Auto Upgrade | Rarity: "
            .. upgradeRarityDisplayName(selectedUpgradeRarity)
            .. " | Mutation: "
            .. upgradeMutationDisplayName(selectedUpgradeMutation)
    end)
end

UpgradeRarityDropBtn.MouseButton1Click:Connect(function()
    UpgradeMutationDropList.Visible = false

    if PickupRangeDropList then
        PickupRangeDropList.Visible = false
    end

    if LuckyTypeDropList then
        LuckyTypeDropList.Visible = false
    end

    UpgradeRarityDropList.Visible =
        not UpgradeRarityDropList.Visible

    UpgradeRarityDropBtn.Text =
        (UpgradeRarityDropList.Visible and "Rarity: ▲ " or "Rarity: ▼ ")
        .. upgradeRarityDisplayName(selectedUpgradeRarity)
end)

UpgradeMutationDropBtn.MouseButton1Click:Connect(function()
    UpgradeRarityDropList.Visible = false

    if PickupRangeDropList then
        PickupRangeDropList.Visible = false
    end

    if LuckyTypeDropList then
        LuckyTypeDropList.Visible = false
    end

    UpgradeMutationDropList.Visible =
        not UpgradeMutationDropList.Visible

    local mutationLabel =
        selectedUpgradeMutation == "Common"
        and "No Mutation"
        or upgradeMutationDisplayName(selectedUpgradeMutation)

    UpgradeMutationDropBtn.Text =
        (UpgradeMutationDropList.Visible and "Mutation: ▲ " or "Mutation: ▼ ")
        .. mutationLabel
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
LuckyTypeDropBtn.Text = "Lucky Type: ▼  " .. selectedLuckyBlockType
LuckyTypeDropBtn.TextColor3 = Color3.fromRGB(255, 214, 125)
LuckyTypeDropBtn.TextSize = 11
LuckyTypeDropBtn.Font = Enum.Font.GothamBold
LuckyTypeDropBtn.ZIndex = 70
LuckyTypeDropBtn.Parent = MainFrame
Instance.new("UICorner", LuckyTypeDropBtn).CornerRadius = UDim.new(0, 8)

LuckyTypeDropList = Instance.new("ScrollingFrame")
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
    UpgradeRarityDropList.Visible = false
    UpgradeMutationDropList.Visible = false
    if PickupRangeDropList then
        PickupRangeDropList.Visible = false
    end
    LuckyTypeDropList.Visible = not LuckyTypeDropList.Visible
end)

local RebirthBtn   = createButton("RebirthToggle", 200, "Auto Rebirth: OFF")
local JumpBtn      = createButton("JumpToggle", 234, "Auto +10 Jump: OFF")
local BoxesAutoBtn = createButton("BoxesAutoToggle", 268, "Auto Place+Open Boxes: OFF")
local InvisBtn     = createButton("InvisToggle", 302, "Invis Cloak: OFF")

-- 10-slot pickup ranges: 1-10, 11-20, ... 91-100.
-- These are non-overlapping groups of exactly 10 slots each.
local PICKUP_RANGE_OPTIONS = {}
for startSlot = 1, 100, 10 do
    local endSlot = math.min(startSlot + 9, 100)
    table.insert(PICKUP_RANGE_OPTIONS, {
        label = string.format("%d-%d", startSlot, endSlot),
        first = startSlot,
        last = endSlot,
    })
end

local selectedPickupRange = PICKUP_RANGE_OPTIONS[1]

local PickupRangeDropBtn = Instance.new("TextButton")
PickupRangeDropBtn.Name = "PickupRangeDrop"
PickupRangeDropBtn.Size = UDim2.new(0, 140, 0, 30)
PickupRangeDropBtn.Position = UDim2.new(0, 15, 0, 344)
PickupRangeDropBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
PickupRangeDropBtn.BorderSizePixel = 0
PickupRangeDropBtn.Text = "▼  " .. selectedPickupRange.label
PickupRangeDropBtn.TextColor3 = Color3.fromRGB(190, 190, 255)
PickupRangeDropBtn.TextSize = 12
PickupRangeDropBtn.Font = Enum.Font.GothamBold
PickupRangeDropBtn.ZIndex = 90
PickupRangeDropBtn.Parent = MainFrame
Instance.new("UICorner", PickupRangeDropBtn).CornerRadius = UDim.new(0, 8)

local PickupBtn = Instance.new("TextButton")
PickupBtn.Name = "PickupBtn"
PickupBtn.Size = UDim2.new(0, 72, 0, 30)
PickupBtn.Position = UDim2.new(0, 163, 0, 344)
PickupBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 70)
PickupBtn.BorderSizePixel = 0
PickupBtn.Text = "Pick Up"
PickupBtn.TextColor3 = Color3.fromRGB(205, 175, 255)
PickupBtn.TextSize = 11
PickupBtn.Font = Enum.Font.GothamBold
PickupBtn.ZIndex = 90
PickupBtn.Parent = MainFrame
Instance.new("UICorner", PickupBtn).CornerRadius = UDim.new(0, 8)

PickupRangeDropList = Instance.new("ScrollingFrame")
PickupRangeDropList.Name = "PickupRangeDropList"
PickupRangeDropList.Size = UDim2.new(0, 220, 0, 156)
PickupRangeDropList.Position = UDim2.new(0, 15, 0, 376)
PickupRangeDropList.BackgroundColor3 = Color3.fromRGB(25, 24, 42)
PickupRangeDropList.BorderSizePixel = 0
PickupRangeDropList.Visible = false
PickupRangeDropList.ScrollBarThickness = 4
PickupRangeDropList.CanvasSize = UDim2.new(0, 0, 0, #PICKUP_RANGE_OPTIONS * 26)
PickupRangeDropList.ZIndex = 100
PickupRangeDropList.Parent = MainFrame
Instance.new("UICorner", PickupRangeDropList).CornerRadius = UDim.new(0, 7)

local pickupRangeLayout = Instance.new("UIListLayout")
pickupRangeLayout.SortOrder = Enum.SortOrder.LayoutOrder
pickupRangeLayout.Parent = PickupRangeDropList

for i, rangeInfo in ipairs(PICKUP_RANGE_OPTIONS) do
    local item = Instance.new("TextButton")
    item.Size = UDim2.new(1, -4, 0, 24)
    item.BackgroundColor3 = Color3.fromRGB(39, 36, 61)
    item.BorderSizePixel = 0
    item.Text = "  Slots " .. rangeInfo.label
    item.TextColor3 = Color3.fromRGB(225, 220, 245)
    item.TextSize = 11
    item.Font = Enum.Font.Gotham
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.LayoutOrder = i
    item.ZIndex = 101
    item.Parent = PickupRangeDropList

    item.MouseButton1Click:Connect(function()
        selectedPickupRange = rangeInfo
        PickupRangeDropBtn.Text = "▼  " .. rangeInfo.label
        PickupRangeDropList.Visible = false
        StatusLabel.Text = "Pickup range selected: " .. rangeInfo.label
    end)
end

PickupRangeDropBtn.MouseButton1Click:Connect(function()
    UpgradeRarityDropList.Visible = false
    UpgradeMutationDropList.Visible = false
    if LuckyTypeDropList then LuckyTypeDropList.Visible = false end
    PickupRangeDropList.Visible = not PickupRangeDropList.Visible
    PickupRangeDropBtn.Text =
        (PickupRangeDropList.Visible and "▲  " or "▼  ")
        .. selectedPickupRange.label
end)

local PickupAllBtn = createButton("PickupAllBtn", 378, "Pick Up ALL Floors")
local PlaceBtn     = createButton("PlaceBtn", 412, "Place Slimes (CURRENT CASH first)")
local BoxesBtn     = createButton("BoxesBtn", 446, "Place + Open Selected Boxes (Once)")

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

local selectedPickOption = "Icons"
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
    if PickupRangeDropList then
        PickupRangeDropList.Visible = false
    end
    if MutationDropList then
        MutationDropList.Visible = false
    end
    if UpgradeRarityDropList then
        UpgradeRarityDropList.Visible = false
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
    if PickupRangeDropList then
        PickupRangeDropList.Visible = false
    end
    DropList.Visible = false
    UpgradeRarityDropList.Visible = false
    UpgradeMutationDropList.Visible = false
    LuckyTypeDropList.Visible = false
    MutationDropList.Visible = not MutationDropList.Visible
end)

PickupAllBtn.TextColor3 = Color3.fromRGB(200, 160, 255)
PickupAllBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 70)
PlaceBtn.TextColor3 = Color3.fromRGB(120, 220, 150)
PlaceBtn.BackgroundColor3 = Color3.fromRGB(30, 50, 40)
BoxesBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
BoxesBtn.BackgroundColor3 = Color3.fromRGB(55, 40, 20)

print("[AutoFarm] GUI — ICONS UPDATE + selected-type Place/Open burst buttons")

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
local ResolveUpgradeRemote
local PlaceRemote, PickupRemote, OpenRemote
local UpgradeChannel = nil
local getPrioritizedUpgrades

local GiftChannel = nil
local GiftRawRemote = nil
local AcceptGiftChannel = nil
local AcceptGiftRawRemote = nil
local GiftRequestChannel = nil
local giftRequestConnection = nil

-- Match the game's own gifting handler exactly:
-- _Lib.Network.new("Gift Slime", "RemoteFunction"):Fire(playerName, slimeUID)
local function ResolveGiftChannel()
    if GiftChannel and type(GiftChannel) == "table" then
        return GiftChannel
    end

    if _Lib and _Lib.Network and typeof(_Lib.Network.new) == "function" then
        local ok, channel = pcall(function()
            return _Lib.Network.new("Gift Slime", "RemoteFunction")
        end)

        if ok and channel then
            GiftChannel = channel
            return GiftChannel
        end
    end

    return nil
end

local function ResolveGiftRawRemote()
    if GiftRawRemote
        and GiftRawRemote.Parent
        and GiftRawRemote:IsA("RemoteFunction")
    then
        return GiftRawRemote
    end

    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteFunction") and v.Name == "Gift Slime" then
            GiftRawRemote = v
            return GiftRawRemote
        end
    end

    return nil
end

local function ResolveAcceptGiftChannel()
    if AcceptGiftChannel and type(AcceptGiftChannel) == "table" then
        return AcceptGiftChannel
    end

    if _Lib and _Lib.Network and typeof(_Lib.Network.new) == "function" then
        local ok, channel = pcall(function()
            return _Lib.Network.new("Accept Gift", "RemoteFunction")
        end)

        if ok and channel then
            AcceptGiftChannel = channel
            return AcceptGiftChannel
        end
    end

    return nil
end

local function ResolveAcceptGiftRawRemote()
    if AcceptGiftRawRemote
        and AcceptGiftRawRemote.Parent
        and AcceptGiftRawRemote:IsA("RemoteFunction")
    then
        return AcceptGiftRawRemote
    end

    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteFunction") and v.Name == "Accept Gift" then
            AcceptGiftRawRemote = v
            return AcceptGiftRawRemote
        end
    end

    return nil
end

local function FireAcceptGift(slimeUID)
    if slimeUID == nil then
        return false, "No pending gift UID"
    end

    if LocalPlayer:GetAttribute("OldDataMigrationLocked") == true then
        return false, "Trade/Gift locked while saved data is loading"
    end

    local channel = ResolveAcceptGiftChannel()
    if channel and typeof(channel.Fire) == "function" then
        local ok, result, message = pcall(function()
            return channel:Fire(slimeUID)
        end)

        if ok then
            if result == true then
                return true, message
            end

            return false,
                (type(message) == "string" and message ~= "" and message)
                or "Accept Gift rejected"
        end

        AcceptGiftChannel = nil
    end

    local raw = ResolveAcceptGiftRawRemote()
    if raw then
        local ok, result, message = pcall(function()
            return raw:InvokeServer(slimeUID)
        end)

        if ok then
            if result == true then
                return true, message
            end

            return false,
                (type(message) == "string" and message ~= "" and message)
                or "Accept Gift rejected"
        end

        return false, tostring(result)
    end

    return false, 'RemoteFunction "Accept Gift" unavailable'
end

local function ResolveGiftRequestChannel()
    if GiftRequestChannel and type(GiftRequestChannel) == "table" then
        return GiftRequestChannel
    end

    if _Lib and _Lib.Network and typeof(_Lib.Network.new) == "function" then
        local ok, channel = pcall(function()
            return _Lib.Network.new("Gift Slime Request", "RemoteEvent")
        end)

        if ok and channel then
            GiftRequestChannel = channel
            return GiftRequestChannel
        end
    end

    return nil
end

local function getPendingGiftUIDFromGui()
    if not PlayerGui then
        return nil
    end

    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        local uid = obj:GetAttribute("slimeUID")

        if uid ~= nil then
            local main = obj:FindFirstChild("Main")
            local accept = main and main:FindFirstChild("Accept")
            local decline = main and main:FindFirstChild("Decline")

            if accept and decline then
                return uid
            end
        end
    end

    return nil
end

local function hookGiftRequestListener()
    if giftRequestConnection then
        return true
    end

    local channel = ResolveGiftRequestChannel()
    if not channel or typeof(channel.Connect) ~= "function" then
        return false
    end

    local ok, connection = pcall(function()
        return channel:Connect(function(action, data)
            if action == "send"
                and type(data) == "table"
                and data.uid ~= nil
            then
                -- Record the newest incoming UID.  The continuous worker below
                -- performs the accept on the same 0.5s cadence as the game button.
                pendingGiftUID = data.uid

            elseif action == "remove" then
                pendingGiftUID = nil
            end
        end)
    end)

    if ok and connection then
        giftRequestConnection = connection
        return true
    end

    return false
end

local function FireGiftSlime(playerName, slimeUID)
    if LocalPlayer:GetAttribute("OldDataMigrationLocked") == true then
        return false, "Trade/Gift locked while saved data is loading"
    end

    local channel = ResolveGiftChannel()
    if channel and typeof(channel.Fire) == "function" then
        local ok, result, message = pcall(function()
            return channel:Fire(playerName, slimeUID)
        end)

        if ok then
            if result == true then
                return true, message
            end
            return false, (type(message) == "string" and message ~= "" and message) or "Gift request rejected"
        end

        GiftChannel = nil
    end

    local raw = ResolveGiftRawRemote()
    if raw then
        local ok, result, message = pcall(function()
            return raw:InvokeServer(playerName, slimeUID)
        end)

        if ok then
            if result == true then
                return true, message
            end
            return false, (type(message) == "string" and message ~= "" and message) or "Gift request rejected"
        end

        return false, tostring(result)
    end

    return false, 'RemoteFunction "Gift Slime" unavailable'
end

-- Match the latest game's own upgrade path exactly:
-- _Lib.Network.new("Upgrade Slime", "RemoteEvent"):Fire(slotName)
-- Raw RemoteEvent is retained only as a fallback.
local function ResolveUpgradeChannel()
    if UpgradeChannel and type(UpgradeChannel) == "table" then
        return UpgradeChannel
    end

    if _Lib and _Lib.Network and typeof(_Lib.Network.new) == "function" then
        local ok, channel = pcall(function()
            return _Lib.Network.new("Upgrade Slime", "RemoteEvent")
        end)

        if ok and channel then
            UpgradeChannel = channel
            return UpgradeChannel
        end
    end

    return nil
end

local function FireUpgradeSlot(slotName)
    slotName = tostring(slotName)

    local channel = ResolveUpgradeChannel()
    if channel and typeof(channel.Fire) == "function" then
        local ok, err = pcall(function()
            channel:Fire(slotName)
        end)

        if ok then
            return true
        end

        warn("[AutoUpgrade] Network wrapper failed:", err)
        UpgradeChannel = nil
    end

    local raw = ResolveUpgradeRemote and ResolveUpgradeRemote() or UpgradeRemote
    if raw and raw.Parent and raw:IsA("RemoteEvent") then
        local ok, err = pcall(function()
            raw:FireServer(slotName)
        end)

        if ok then
            return true
        end

        return false, err
    end

    return false, 'Upgrade Slime channel/RemoteEvent unavailable'
end

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

ResolveUpgradeRemote = function()
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
        .. " | Rarity: "
        .. upgradeRarityDisplayName(selectedUpgradeRarity)
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
        task.spawn(function()
            local channel = ResolveUpgradeChannel()
            local remote = ResolveUpgradeRemote()
            local upgrades, stats = getPrioritizedUpgrades()

            print(
                "[AutoUpgrade] ON | Rarity:",
                upgradeRarityDisplayName(selectedUpgradeRarity),
                "| Mutation:",
                upgradeMutationDisplayName(selectedUpgradeMutation),
                "| Route:",
                channel and "_Lib.Network" or (remote and remote:GetFullName() or "missing"),
                "| Occupied:",
                stats and stats.occupied or 0,
                "| Readable:",
                stats and stats.readable or 0,
                "| Matched:",
                #upgrades
            )

            StatusLabel.Text = string.format(
                "Upgrade ON | %s + %s | %d matching / %d occupied",
                upgradeRarityDisplayName(selectedUpgradeRarity),
                upgradeMutationDisplayName(selectedUpgradeMutation),
                #upgrades,
                stats and stats.occupied or 0
            )
        end)
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

    if _Lib then
        ResolveAcceptGiftChannel()
        ResolveGiftRequestChannel()
        hookGiftRequestListener()
    end

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
    UpgradeChannel    = ResolveUpgradeChannel()
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

local function trimText(value)
    value = tostring(value or "")
    return value:match("^%s*(.-)%s*$") or ""
end

local function resolveGiftTarget(input)
    local wanted = string.lower(trimText(input))
    if wanted == "" then
        return nil, "Type a player username first"
    end

    -- Exact username first.
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and string.lower(player.Name) == wanted then
            return player
        end
    end

    -- Exact display name second.
    local exactDisplay = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and string.lower(player.DisplayName) == wanted then
            if exactDisplay then
                return nil, "Display name matches multiple players; use username"
            end
            exactDisplay = player
        end
    end
    if exactDisplay then
        return exactDisplay
    end

    -- Unique username prefix for convenience.
    local prefixMatch = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer
            and string.sub(string.lower(player.Name), 1, #wanted) == wanted
        then
            if prefixMatch then
                return nil, "Name prefix matches multiple players; type more letters"
            end
            prefixMatch = player
        end
    end

    if prefixMatch then
        return prefixMatch
    end

    return nil, "Player not found in this server"
end

local function getGiftableInventoryUIDs()
    local data = getData()
    local inventory = data and data.Inventory
    local list, seen = {}, {}

    if type(inventory) ~= "table" then
        return list
    end

    for _, entry in pairs(inventory) do
        if type(entry) == "table" and entry.uid ~= nil then
            local key = tostring(entry.uid)
            if not seen[key] then
                seen[key] = true
                table.insert(list, entry.uid)
            end
        end
    end

    return list
end

local function setAutoAcceptGiftsState(on)
    autoAcceptGiftsEnabled = on == true

    if autoAcceptGiftsEnabled then
        AutoAcceptGiftBtn.Text = "Auto Accept Gifts: ON"
        AutoAcceptGiftBtn.TextColor3 = Color3.fromRGB(105, 255, 145)
        AutoAcceptGiftBtn.BackgroundColor3 = Color3.fromRGB(30, 62, 43)

        hookGiftRequestListener()

        if not giftAllEnabled then
            GiftStatus.Text = "Auto Accept ON | waiting for incoming gifts..."
        end
    else
        AutoAcceptGiftBtn.Text = "Auto Accept Gifts: OFF"
        AutoAcceptGiftBtn.TextColor3 = Color3.fromRGB(255, 105, 115)
        AutoAcceptGiftBtn.BackgroundColor3 = Color3.fromRGB(52, 38, 42)
        pendingGiftUID = nil

        if not giftAllEnabled then
            GiftStatus.Text = "Auto Accept stopped."
        end
    end
end

local function setGiftAllState(on, resolvedPlayer)
    giftAllEnabled = on == true

    if giftAllEnabled then
        giftTargetName = resolvedPlayer and resolvedPlayer.Name or giftTargetName
        GiftAllBtn.Text = "Gift All: ON"
        GiftAllBtn.TextColor3 = Color3.fromRGB(105, 255, 145)
        GiftAllBtn.BackgroundColor3 = Color3.fromRGB(30, 62, 43)
        GiftNameBox.TextEditable = false
        GiftStatus.Text = "Target: " .. tostring(giftTargetName) .. " | sending inventory..."
    else
        GiftAllBtn.Text = "Gift All: OFF"
        GiftAllBtn.TextColor3 = Color3.fromRGB(255, 105, 115)
        GiftAllBtn.BackgroundColor3 = Color3.fromRGB(52, 38, 42)
        GiftNameBox.TextEditable = true
        giftTargetName = nil
        table.clear(giftInFlight)
        GiftStatus.Text = "Gift All stopped."
    end
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

local function getOccupiedSlotsInRange(firstSlot, lastSlot)
    firstSlot = tonumber(firstSlot) or 1
    lastSlot = tonumber(lastSlot) or firstSlot

    if firstSlot > lastSlot then
        firstSlot, lastSlot = lastSlot, firstSlot
    end

    local data = getData()
    local plotSlimes = (data and data.PlotSlimes) or {}
    local plot = getMyPlot()
    local liveFolder = getPlayerSlimesFolder()
    local list = {}

    if not plot then return list end

    local stands = plot:FindFirstChild("Stands")
    if not stands then return list end

    for _, stand in ipairs(stands:GetChildren()) do
        local n = tonumber(stand.Name)

        if n
            and n >= firstSlot
            and n <= lastSlot
            and isOccupied(stand.Name, plotSlimes, liveFolder, stand)
        then
            table.insert(list, {
                name = stand.Name,
                num = n,
                stand = stand,
            })
        end
    end

    table.sort(list, function(a, b)
        return a.num < b.num
    end)

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
                    e
