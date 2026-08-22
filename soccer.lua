– Combined Script: ICONS UPDATE + BATCH-10 Auto Upgrade + FILTERED Lucky
Block Collector – + selected-type Lucky Block Place + OPEN ALL active
boxes + 10-slot Pickup Range + Place-by-Mutation + CURRENT INDIVIDUAL
earnings desc + Invis – + expandable right-side Gift All inventory
panel + HIGHEST CURRENT CASH/s gift priority + Gift Count/Delay + Auto
Accept Gifts + Pick Lowest Profit by count – + WORKING Lucky Box
collector preserved; invisibility is best-effort/non-blocking

local Players = game:GetService(“Players”) local ReplicatedStorage =
game:GetService(“ReplicatedStorage”) local Workspace =
game:GetService(“Workspace”) local CoreGui = game:GetService(“CoreGui”)

– ================= STABILITY PATCH ================= – Added: delayed
initialization, remote retry, error reporting helpers

local SCRIPT_READY = false local DEBUG_MODE = true

local function DebugPrint(…) if DEBUG_MODE then print(“[AutoFarm
Debug]”, …) end end

local function WaitForObject(getter, name, timeout) local start =
os.clock() timeout = timeout or 30

    while os.clock() - start < timeout do
        local ok, result = pcall(getter)
        if ok and result then
            DebugPrint(name .. " found")
            return result
        end
        task.wait(1)
    end

    DebugPrint(name .. " not found after timeout")
    return nil

end

local function SafeCall(name, fn, …) local args = {…} local ok, result =
pcall(function() return fn(table.unpack(args)) end)

    if not ok then
        DebugPrint(name .. " failed:", result)
        return nil
    end

    return result

end – ===================================================

local LocalPlayer = Players.LocalPlayer local PlayerGui =
LocalPlayer:WaitForChild(“PlayerGui”, 10)

– Give the game time to finish loading replicated objects task.wait(3)
SCRIPT_READY = true

– ============================================ – CONFIG –
============================================ local COLLECT_INTERVAL =
0.35 local COLLECT_SCAN = 1.5 local ONLY_WHEN_PADGUI_ENABLED = true

local UPGRADE_DELAY = 0.25 local UPGRADE_SCAN = 1.0 local MAX_LEVEL =
100

local REBIRTH_INTERVAL = 5 local JUMP_UPGRADE_INTERVAL = 0.5 local
BOXES_AUTO_INTERVAL = 30 local INVIS_REFRESH = 2.5 local
GIFT_REPEAT_INTERVAL = 1.25 – re-send remaining inventory while Gift All
stays ON local AUTO_ACCEPT_GIFT_INTERVAL = 0.50 – matches the game’s
native Accept button cooldown

local DELAY_EQUIP = 0.12 local DELAY_PLACE = 0.22 local DELAY_NEXT =
0.12 local DELAY_PICK = 0.12 local IGNORE_LOCK = true

– Newest high tiers. Actual Auto Upgrade ordering remains
cheapest-next-upgrade first. local UPGRADE_PRIORITY = { [“Icons”] = 1,
[“Spain”] = 2 } local TARGET_RARITIES = { [“Icons”] = true, [“Spain”] =
true }

local RARITY_VALUE = { [“Icons”] = 5000000, [“Spain”] = 2500000,
[“Champions”] = 1000000, [“OG”] = 500000, [“Exclusive”] = 75000,
[“LIMITED”] = 75000, [“Divine”] = 50000, [“Slime God”] = 30000,
[“Secret”] = 10000, [“Mythic”] = 2500, [“Legendary”] = 750, [“Epic”] =
250, [“Rare”] = 100, [“Common”] = 25, }

local ALL_RARITIES = { “Common”, “Rare”, “Epic”, “Legendary”, “Mythic”,
“Secret”, “Slime God”, “Divine”, “Exclusive”, “LIMITED”, “OG”,
“Champions”, “Spain”, “Icons”, }

– Latest live mutation table includes Divine + Fallen at 5x. local
ALL_MUTATIONS = { “Golden”, “Diamond”, “Rainbow”, “Cursed”, “Divine”,
“Fallen”, “Volcanic”, “Toxic”, “Taco”, “Cosmic”, “Slimey”, } local
PICK_OPTIONS = {} for , r in ipairs(ALL_RARITIES) do
table.insert(PICK_OPTIONS, r) end for , m in ipairs(ALL_MUTATIONS) do
table.insert(PICK_OPTIONS, m) end

– Auto Upgrade RARITY filter. – “All” = every rarity. local
UPGRADE_RARITY_OPTIONS = { “All”, “Common”, “Rare”, “Epic”, “Legendary”,
“Mythic”, “Secret”, “Slime God”, “Divine”, “Exclusive”, “LIMITED”, “OG”,
“Champions”, “Spain”, “Icons”, }

local selectedUpgradeRarity = “All”

– Auto Upgrade MUTATION filter. – “All” = any mutation. – “Common” is
displayed as “Common (No Mutation)” and means – NO base mutation AND NO
event mutation. local UPGRADE_MUTATION_OPTIONS = { “All”, “Common” } for
_, mutationName in ipairs(ALL_MUTATIONS) do
table.insert(UPGRADE_MUTATION_OPTIONS, mutationName) end

local selectedUpgradeMutation = “All”

– Exact Lucky Block types found in the latest game slime registry. – New
live entry: Icons Lucky Block (ID 1112, rarity Icons). – The dropdown
uses display labels; matching uses exact live model names. local
LUCKY_BLOCK_OPTIONS = { “All”, “Common”, “Water”, “Rare”, “Volcanic”,
“Epic”, “Ghost”, “Legendary”, “67”, “Mythic”, “Poison”, “Secret”,
“Cosmic”, “Soccer God”, “Rainbow”, “Exclusive”, “Limited”, “OG”,
“Champions”, “Spain”, “Icons”, }

local LUCKY_BLOCK_MODEL_NAMES = { [“Common”] = { [“Common Lucky Block”]
= true }, [“Water”] = { [“Water Lucky Block”] = true }, [“Rare”] = {
[“Rare Lucky Block”] = true }, [“Volcanic”] = { [“Volcanic Lucky Block”]
= true }, [“Epic”] = { [“Epic Lucky Block”] = true }, [“Ghost”] = {
[“Ghost Lucky Block”] = true }, [“Legendary”] = { [“Legendary Lucky
Block”] = true }, [“67”] = { [“67 Lucky Block”] = true }, [“Mythic”] = {
[“Mythic Lucky Block”] = true }, [“Poison”] = { [“Poison Lucky Block”] =
true }, [“Secret”] = { [“Secret Lucky Block”] = true }, [“Cosmic”] = {
[“Cosmic Lucky Block”] = true }, – Internal database name is Slime God
Lucky Block; the game displays Soccer God. [“Soccer God”] = { [“Slime
God Lucky Block”] = true, [“Soccer God Lucky Block”] = true, },
[“Rainbow”] = { [“Rainbow Lucky Block”] = true }, [“Exclusive”] = {
[“Exclusive Lucky Block”] = true }, [“Limited”] = { [“Limited Lucky
Block”] = true }, [“OG”] = { [“OG Lucky Block”] = true }, [“Champions”]
= { [“Champions Lucky Block”] = true }, [“Spain”] = { [“Spain Lucky
Block”] = true }, [“Icons”] = { [“Icons Lucky Block”] = true }, }

– Default to the newest live tier. local selectedLuckyBlockType =
“Icons”

– Gift All state is declared before GUI construction so the side panel –
and the worker loop share the same locals. local giftAllEnabled = false
local giftTargetName = nil local giftInFlight = {} local
autoAcceptGiftsEnabled = false local pendingGiftUID = nil local
lastAcceptedGiftUID = nil local lastAcceptedGiftAt = 0

– ============================================ – GUI –
============================================ pcall(function() local old
= PlayerGui and PlayerGui:FindFirstChild(“AutoFarmGui”) if old then
old:Destroy() end old = CoreGui:FindFirstChild(“AutoFarmGui”) if old
then old:Destroy() end end)

local ScreenGui = Instance.new(“ScreenGui”) ScreenGui.Name =
“AutoFarmGui” ScreenGui.ResetOnSpawn = false ScreenGui.ZIndexBehavior =
Enum.ZIndexBehavior.Sibling ScreenGui.DisplayOrder = 999
ScreenGui.IgnoreGuiInset = true pcall(function() ScreenGui.Parent =
PlayerGui or CoreGui end) if not ScreenGui.Parent then ScreenGui.Parent
= CoreGui end

local MainFrame = Instance.new(“Frame”) MainFrame.Size = UDim2.new(0,
250, 0, 794) MainFrame.Position = UDim2.new(0, 20, 0.5, -397)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BackgroundTransparency = 0.05 MainFrame.BorderSizePixel = 0
MainFrame.Active = true MainFrame.Draggable = true MainFrame.Parent =
ScreenGui Instance.new(“UICorner”, MainFrame).CornerRadius = UDim.new(0,
10) local mainStroke = Instance.new(“UIStroke”, MainFrame)
mainStroke.Color = Color3.fromRGB(80, 80, 100) mainStroke.Thickness = 2

local Title = Instance.new(“TextLabel”) Title.Size = UDim2.new(1, 0, 0,
28) Title.BackgroundTransparency = 1 Title.Text = “Auto Farm Control”
Title.TextColor3 = Color3.fromRGB(255, 255, 255) Title.TextSize = 15
Title.Font = Enum.Font.GothamBold Title.Parent = MainFrame

– ============================================ – EXPANDABLE RIGHT-SIDE
MENU: GIFT ALL – Collapsed by default. The arrow moves with the main
draggable frame. – ============================================ local
SideArrowBtn = Instance.new(“TextButton”) SideArrowBtn.Name =
“SideArrow” SideArrowBtn.Size = UDim2.new(0, 24, 0, 44)
SideArrowBtn.Position = UDim2.new(1, 4, 0, 36)
SideArrowBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
SideArrowBtn.BorderSizePixel = 0 SideArrowBtn.Text = “>”
SideArrowBtn.TextColor3 = Color3.fromRGB(220, 220, 235)
SideArrowBtn.TextSize = 18 SideArrowBtn.Font = Enum.Font.GothamBold
SideArrowBtn.ZIndex = 120 SideArrowBtn.Parent = MainFrame
Instance.new(“UICorner”, SideArrowBtn).CornerRadius = UDim.new(0, 7)
local sideArrowStroke = Instance.new(“UIStroke”, SideArrowBtn)
sideArrowStroke.Color = Color3.fromRGB(80, 80, 100)
sideArrowStroke.Thickness = 1.5

local GiftPanel = Instance.new(“Frame”) GiftPanel.Name = “GiftPanel”
GiftPanel.Size = UDim2.new(0, 220, 0, 326) GiftPanel.Position =
UDim2.new(1, 32, 0, 36) GiftPanel.BackgroundColor3 = Color3.fromRGB(24,
24, 31) GiftPanel.BackgroundTransparency = 0.03
GiftPanel.BorderSizePixel = 0 GiftPanel.Visible = false GiftPanel.ZIndex
= 115 GiftPanel.Parent = MainFrame Instance.new(“UICorner”,
GiftPanel).CornerRadius = UDim.new(0, 9) local giftPanelStroke =
Instance.new(“UIStroke”, GiftPanel) giftPanelStroke.Color =
Color3.fromRGB(85, 85, 108) giftPanelStroke.Thickness = 1.5

local GiftTitle = Instance.new(“TextLabel”) GiftTitle.Size =
UDim2.new(1, -20, 0, 26) GiftTitle.Position = UDim2.new(0, 10, 0, 6)
GiftTitle.BackgroundTransparency = 1 GiftTitle.Text = “Gift Inventory”
GiftTitle.TextColor3 = Color3.fromRGB(245, 245, 250) GiftTitle.TextSize
= 13 GiftTitle.Font = Enum.Font.GothamBold GiftTitle.TextXAlignment =
Enum.TextXAlignment.Left GiftTitle.ZIndex = 116 GiftTitle.Parent =
GiftPanel

local GiftNameBox = Instance.new(“TextBox”) GiftNameBox.Name =
“PlayerName” GiftNameBox.Size = UDim2.new(1, -20, 0, 32)
GiftNameBox.Position = UDim2.new(0, 10, 0, 36)
GiftNameBox.BackgroundColor3 = Color3.fromRGB(37, 37, 48)
GiftNameBox.BorderSizePixel = 0 GiftNameBox.PlaceholderText = “Player
username…” GiftNameBox.Text = “” GiftNameBox.ClearTextOnFocus = false
GiftNameBox.TextColor3 = Color3.fromRGB(245, 245, 250)
GiftNameBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 155)
GiftNameBox.TextSize = 12 GiftNameBox.Font = Enum.Font.Gotham
GiftNameBox.ZIndex = 116 GiftNameBox.Parent = GiftPanel
Instance.new(“UICorner”, GiftNameBox).CornerRadius = UDim.new(0, 7)

local GiftAllBtn = Instance.new(“TextButton”) GiftAllBtn.Name =
“GiftAllToggle” GiftAllBtn.Size = UDim2.new(1, -20, 0, 32)
GiftAllBtn.Position = UDim2.new(0, 10, 0, 75)
GiftAllBtn.BackgroundColor3 = Color3.fromRGB(52, 38, 42)
GiftAllBtn.BorderSizePixel = 0 GiftAllBtn.Text = “Gift All: OFF”
GiftAllBtn.TextColor3 = Color3.fromRGB(255, 105, 115)
GiftAllBtn.TextSize = 12 GiftAllBtn.Font = Enum.Font.GothamBold
GiftAllBtn.ZIndex = 116 GiftAllBtn.Parent = GiftPanel
Instance.new(“UICorner”, GiftAllBtn).CornerRadius = UDim.new(0, 7)

– Gift run controls. Kept inside a scope so this very large script does
not – add more long-lived top-level locals. The worker resolves them by
Name. do local countBox = Instance.new(“TextBox”) countBox.Name =
“GiftCount” countBox.Size = UDim2.new(0, 94, 0, 30) countBox.Position =
UDim2.new(0, 10, 0, 113) countBox.BackgroundColor3 = Color3.fromRGB(37,
37, 48) countBox.BorderSizePixel = 0 countBox.PlaceholderText = “Gift
Count” countBox.Text = “10” countBox.ClearTextOnFocus = false
countBox.TextColor3 = Color3.fromRGB(245, 245, 250)
countBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 155)
countBox.TextSize = 11 countBox.Font = Enum.Font.GothamBold
countBox.ZIndex = 116 countBox.Parent = GiftPanel
Instance.new(“UICorner”, countBox).CornerRadius = UDim.new(0, 7)

    local delayBox = Instance.new("TextBox")
    delayBox.Name = "GiftDelay"
    delayBox.Size = UDim2.new(0, 100, 0, 30)
    delayBox.Position = UDim2.new(0, 110, 0, 113)
    delayBox.BackgroundColor3 = Color3.fromRGB(37, 37, 48)
    delayBox.BorderSizePixel = 0
    delayBox.PlaceholderText = "Delay sec"
    delayBox.Text = "1.25"
    delayBox.ClearTextOnFocus = false
    delayBox.TextColor3 = Color3.fromRGB(245, 245, 250)
    delayBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 155)
    delayBox.TextSize = 11
    delayBox.Font = Enum.Font.GothamBold
    delayBox.ZIndex = 116
    delayBox.Parent = GiftPanel
    Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0, 7)

    countBox.FocusLost:Connect(function()
        local count = math.floor(tonumber(countBox.Text) or 10)
        countBox.Text = tostring(math.max(1, count))
    end)

    delayBox.FocusLost:Connect(function()
        local delay = tonumber(delayBox.Text) or 1.25
        delay = math.max(0, delay)
        delayBox.Text = string.format("%.2f", delay)
    end)

end

local GiftStatus = Instance.new(“TextLabel”) GiftStatus.Size =
UDim2.new(1, -20, 0, 42) GiftStatus.Position = UDim2.new(0, 10, 0, 149)
GiftStatus.BackgroundTransparency = 1 GiftStatus.Text = “Enter a player
in this server.” GiftStatus.TextColor3 = Color3.fromRGB(185, 185, 200)
GiftStatus.TextSize = 10 GiftStatus.Font = Enum.Font.Gotham
GiftStatus.TextWrapped = true GiftStatus.TextXAlignment =
Enum.TextXAlignment.Left GiftStatus.TextYAlignment =
Enum.TextYAlignment.Top GiftStatus.ZIndex = 116 GiftStatus.Parent =
GiftPanel

– ============================================ – LOWEST-PROFIT PICKUP
CONTROL – Enter a count, then pick that many currently placed normal
players – starting with the LOWEST calculated current cash/s. –
============================================ local LowestProfitLabel =
Instance.new(“TextLabel”) LowestProfitLabel.Name = “LowestProfitLabel”
LowestProfitLabel.Size = UDim2.new(1, -20, 0, 16)
LowestProfitLabel.Position = UDim2.new(0, 10, 0, 190)
LowestProfitLabel.BackgroundTransparency = 1 LowestProfitLabel.Text =
“Pick lowest-profit players:” LowestProfitLabel.TextColor3 =
Color3.fromRGB(200, 200, 215) LowestProfitLabel.TextSize = 10
LowestProfitLabel.Font = Enum.Font.Gotham
LowestProfitLabel.TextXAlignment = Enum.TextXAlignment.Left
LowestProfitLabel.ZIndex = 116 LowestProfitLabel.Parent = GiftPanel

local LowestProfitCountBox = Instance.new(“TextBox”)
LowestProfitCountBox.Name = “LowestProfitCount”
LowestProfitCountBox.Size = UDim2.new(0, 54, 0, 30)
LowestProfitCountBox.Position = UDim2.new(0, 10, 0, 209)
LowestProfitCountBox.BackgroundColor3 = Color3.fromRGB(37, 37, 48)
LowestProfitCountBox.BorderSizePixel = 0
LowestProfitCountBox.PlaceholderText = “Count” LowestProfitCountBox.Text
= “10” LowestProfitCountBox.ClearTextOnFocus = false
LowestProfitCountBox.TextColor3 = Color3.fromRGB(245, 245, 250)
LowestProfitCountBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 155)
LowestProfitCountBox.TextSize = 12 LowestProfitCountBox.Font =
Enum.Font.GothamBold LowestProfitCountBox.ZIndex = 116
LowestProfitCountBox.Parent = GiftPanel Instance.new(“UICorner”,
LowestProfitCountBox).CornerRadius = UDim.new(0, 7)

local PickLowestProfitBtn = Instance.new(“TextButton”)
PickLowestProfitBtn.Name = “PickLowestProfitBtn”
PickLowestProfitBtn.Size = UDim2.new(0, 140, 0, 30)
PickLowestProfitBtn.Position = UDim2.new(0, 70, 0, 209)
PickLowestProfitBtn.BackgroundColor3 = Color3.fromRGB(38, 48, 62)
PickLowestProfitBtn.BorderSizePixel = 0 PickLowestProfitBtn.Text = “Pick
Lowest Profit” PickLowestProfitBtn.TextColor3 = Color3.fromRGB(165, 210,
255) PickLowestProfitBtn.TextSize = 10 PickLowestProfitBtn.Font =
Enum.Font.GothamBold PickLowestProfitBtn.ZIndex = 116
PickLowestProfitBtn.Parent = GiftPanel Instance.new(“UICorner”,
PickLowestProfitBtn).CornerRadius = UDim.new(0, 7)

local LowestProfitStatus = Instance.new(“TextLabel”)
LowestProfitStatus.Name = “LowestProfitStatus” LowestProfitStatus.Size =
UDim2.new(1, -20, 0, 30) LowestProfitStatus.Position = UDim2.new(0, 10,
0, 244) LowestProfitStatus.BackgroundTransparency = 1
LowestProfitStatus.Text = “Lowest cash/s first.”
LowestProfitStatus.TextColor3 = Color3.fromRGB(165, 165, 180)
LowestProfitStatus.TextSize = 9 LowestProfitStatus.Font =
Enum.Font.Gotham LowestProfitStatus.TextWrapped = true
LowestProfitStatus.TextXAlignment = Enum.TextXAlignment.Left
LowestProfitStatus.TextYAlignment = Enum.TextYAlignment.Top
LowestProfitStatus.ZIndex = 116 LowestProfitStatus.Parent = GiftPanel

– ============================================ – AUTO ACCEPT INCOMING
GIFTS – The game receives Gift Slime Request(“send”, data), stores
data.uid as – slimeUID on its gifting frame, and Accept calls Accept
Gift(slimeUID). – ============================================ local
AutoAcceptGiftBtn = Instance.new(“TextButton”) AutoAcceptGiftBtn.Name =
“AutoAcceptGiftToggle” AutoAcceptGiftBtn.Size = UDim2.new(1, -20, 0, 30)
AutoAcceptGiftBtn.Position = UDim2.new(0, 10, 0, 282)
AutoAcceptGiftBtn.BackgroundColor3 = Color3.fromRGB(52, 38, 42)
AutoAcceptGiftBtn.BorderSizePixel = 0 AutoAcceptGiftBtn.Text = “Auto
Accept Gifts: OFF” AutoAcceptGiftBtn.TextColor3 = Color3.fromRGB(255,
105, 115) AutoAcceptGiftBtn.TextSize = 11 AutoAcceptGiftBtn.Font =
Enum.Font.GothamBold AutoAcceptGiftBtn.ZIndex = 116
AutoAcceptGiftBtn.Parent = GiftPanel Instance.new(“UICorner”,
AutoAcceptGiftBtn).CornerRadius = UDim.new(0, 7)

LowestProfitCountBox.FocusLost:Connect(function() local count =
math.floor(tonumber(LowestProfitCountBox.Text) or 0) if count < 1 then
count = 1 end LowestProfitCountBox.Text = tostring(count) end)

SideArrowBtn.MouseButton1Click:Connect(function() GiftPanel.Visible =
not GiftPanel.Visible SideArrowBtn.Text = GiftPanel.Visible and “<” or
“>” end)

local function createButton(name, y, text) local btn =
Instance.new(“TextButton”) btn.Name = name btn.Size = UDim2.new(0, 220,
0, 30) btn.Position = UDim2.new(0, 15, 0, y) btn.BackgroundColor3 =
Color3.fromRGB(40, 40, 50) btn.BorderSizePixel = 0 btn.Text = text
btn.TextColor3 = Color3.fromRGB(255, 90, 90) btn.TextSize = 11 btn.Font
= Enum.Font.GothamBold btn.Parent = MainFrame Instance.new(“UICorner”,
btn).CornerRadius = UDim.new(0, 8) local s = Instance.new(“UIStroke”,
btn) s.Color = Color3.fromRGB(70, 70, 85) s.Thickness = 1.5 return btn
end

local StatusLabel = Instance.new(“TextLabel”) StatusLabel.Size =
UDim2.new(0, 230, 0, 44) StatusLabel.Position = UDim2.new(0, 10, 0, 742)
StatusLabel.BackgroundTransparency = 1 StatusLabel.Text = “Loading…”
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
StatusLabel.TextSize = 11 StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.TextWrapped = true StatusLabel.Parent = MainFrame

local CollectBtn = createButton(“CollectToggle”, 30, “Auto Collect:
OFF”) local UpgradeBtn = createButton(“UpgradeToggle”, 64, “Auto
Upgrade: OFF”)

– ============================================ – AUTO UPGRADE RARITY +
MUTATION FILTERS – Both selections are read live by Auto Upgrade.

– Forward declaration is required because the Auto Upgrade dropdown –
click callbacks also close the Lucky Type dropdown, which is built –
slightly later in the GUI. local LuckyTypeDropList local
PickupRangeDropList – Example: – Rarity = Champions – Mutation = Cosmic
– -> only Cosmic Champions are eligible. –
============================================

local UpgradeRarityDropBtn = Instance.new(“TextButton”)
UpgradeRarityDropBtn.Name = “UpgradeRarityDrop”
UpgradeRarityDropBtn.Size = UDim2.new(0, 106, 0, 30)
UpgradeRarityDropBtn.Position = UDim2.new(0, 15, 0, 98)
UpgradeRarityDropBtn.BackgroundColor3 = Color3.fromRGB(28, 42, 62)
UpgradeRarityDropBtn.BorderSizePixel = 0 UpgradeRarityDropBtn.Text =
“Rarity: ▼ All” UpgradeRarityDropBtn.TextColor3 = Color3.fromRGB(150,
205, 255) UpgradeRarityDropBtn.TextSize = 10 UpgradeRarityDropBtn.Font =
Enum.Font.GothamBold UpgradeRarityDropBtn.ZIndex = 50
UpgradeRarityDropBtn.Parent = MainFrame Instance.new(“UICorner”,
UpgradeRarityDropBtn).CornerRadius = UDim.new(0, 8)

local UpgradeMutationDropBtn = Instance.new(“TextButton”)
UpgradeMutationDropBtn.Name = “UpgradeMutationDrop”
UpgradeMutationDropBtn.Size = UDim2.new(0, 106, 0, 30)
UpgradeMutationDropBtn.Position = UDim2.new(0, 129, 0, 98)
UpgradeMutationDropBtn.BackgroundColor3 = Color3.fromRGB(48, 34, 62)
UpgradeMutationDropBtn.BorderSizePixel = 0 UpgradeMutationDropBtn.Text =
“Mutation: ▼ All” UpgradeMutationDropBtn.TextColor3 =
Color3.fromRGB(220, 180, 255) UpgradeMutationDropBtn.TextSize = 10
UpgradeMutationDropBtn.Font = Enum.Font.GothamBold
UpgradeMutationDropBtn.ZIndex = 50 UpgradeMutationDropBtn.Parent =
MainFrame Instance.new(“UICorner”, UpgradeMutationDropBtn).CornerRadius
= UDim.new(0, 8)

local UpgradeRarityDropList = Instance.new(“ScrollingFrame”)
UpgradeRarityDropList.Name = “UpgradeRarityDropList”
UpgradeRarityDropList.Size = UDim2.new(0, 220, 0, 180)
UpgradeRarityDropList.Position = UDim2.new(0, 15, 0, 130)
UpgradeRarityDropList.BackgroundColor3 = Color3.fromRGB(20, 28, 40)
UpgradeRarityDropList.BorderSizePixel = 0 UpgradeRarityDropList.Visible
= false UpgradeRarityDropList.ScrollBarThickness = 4
UpgradeRarityDropList.CanvasSize = UDim2.new(0, 0, 0,
#UPGRADE_RARITY_OPTIONS * 26) UpgradeRarityDropList.ZIndex = 60
UpgradeRarityDropList.Parent = MainFrame Instance.new(“UICorner”,
UpgradeRarityDropList).CornerRadius = UDim.new(0, 7)

local upgradeRarityListLayout = Instance.new(“UIListLayout”)
upgradeRarityListLayout.SortOrder = Enum.SortOrder.LayoutOrder
upgradeRarityListLayout.Parent = UpgradeRarityDropList

local UpgradeMutationDropList = Instance.new(“ScrollingFrame”)
UpgradeMutationDropList.Name = “UpgradeMutationDropList”
UpgradeMutationDropList.Size = UDim2.new(0, 220, 0, 180)
UpgradeMutationDropList.Position = UDim2.new(0, 15, 0, 130)
UpgradeMutationDropList.BackgroundColor3 = Color3.fromRGB(32, 22, 42)
UpgradeMutationDropList.BorderSizePixel = 0
UpgradeMutationDropList.Visible = false
UpgradeMutationDropList.ScrollBarThickness = 4
UpgradeMutationDropList.CanvasSize = UDim2.new(0, 0, 0,
#UPGRADE_MUTATION_OPTIONS * 26) UpgradeMutationDropList.ZIndex = 65
UpgradeMutationDropList.Parent = MainFrame Instance.new(“UICorner”,
UpgradeMutationDropList).CornerRadius = UDim.new(0, 7)

local upgradeMutationListLayout = Instance.new(“UIListLayout”)
upgradeMutationListLayout.SortOrder = Enum.SortOrder.LayoutOrder
upgradeMutationListLayout.Parent = UpgradeMutationDropList

local function upgradeRarityDisplayName(value) return tostring(value)
end

local function upgradeMutationDisplayName(value) if tostring(value) ==
“Common” then return “Common (No Mutation)” end return tostring(value)
end

for i, rarityName in ipairs(UPGRADE_RARITY_OPTIONS) do local item =
Instance.new(“TextButton”) item.Size = UDim2.new(1, -4, 0, 24)
item.BackgroundColor3 = Color3.fromRGB(30, 42, 58) item.BorderSizePixel
= 0 item.Text = ” ” .. upgradeRarityDisplayName(rarityName)
item.TextColor3 = Color3.fromRGB(220, 232, 245) item.TextSize = 11
item.Font = Enum.Font.Gotham item.TextXAlignment =
Enum.TextXAlignment.Left item.LayoutOrder = i item.ZIndex = 61
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

for i, mutationName in ipairs(UPGRADE_MUTATION_OPTIONS) do local item =
Instance.new(“TextButton”) item.Size = UDim2.new(1, -4, 0, 24)
item.BackgroundColor3 = Color3.fromRGB(45, 31, 58) item.BorderSizePixel
= 0 item.Text = ” ” .. upgradeMutationDisplayName(mutationName)
item.TextColor3 = Color3.fromRGB(235, 220, 248) item.TextSize = 11
item.Font = Enum.Font.Gotham item.TextXAlignment =
Enum.TextXAlignment.Left item.LayoutOrder = i item.ZIndex = 66
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

local LuckyBtn = createButton(“LuckyToggle”, 132, “Lucky Block: OFF”)

– ============================================ – LUCKY BLOCK TYPE FILTER
– Change this before or while Lucky Block collector is ON. –
============================================ local LuckyTypeDropBtn =
Instance.new(“TextButton”) LuckyTypeDropBtn.Name = “LuckyTypeDrop”
LuckyTypeDropBtn.Size = UDim2.new(0, 220, 0, 30)
LuckyTypeDropBtn.Position = UDim2.new(0, 15, 0, 166)
LuckyTypeDropBtn.BackgroundColor3 = Color3.fromRGB(58, 45, 22)
LuckyTypeDropBtn.BorderSizePixel = 0 LuckyTypeDropBtn.Text = “Lucky
Type: ▼” .. selectedLuckyBlockType LuckyTypeDropBtn.TextColor3 =
Color3.fromRGB(255, 214, 125) LuckyTypeDropBtn.TextSize = 11
LuckyTypeDropBtn.Font = Enum.Font.GothamBold LuckyTypeDropBtn.ZIndex =
70 LuckyTypeDropBtn.Parent = MainFrame Instance.new(“UICorner”,
LuckyTypeDropBtn).CornerRadius = UDim.new(0, 8)

LuckyTypeDropList = Instance.new(“ScrollingFrame”)
LuckyTypeDropList.Name = “LuckyTypeDropList” LuckyTypeDropList.Size =
UDim2.new(0, 220, 0, 190) LuckyTypeDropList.Position = UDim2.new(0, 15,
0, 198) LuckyTypeDropList.BackgroundColor3 = Color3.fromRGB(35, 28, 18)
LuckyTypeDropList.BorderSizePixel = 0 LuckyTypeDropList.Visible = false
LuckyTypeDropList.ScrollBarThickness = 4 LuckyTypeDropList.CanvasSize =
UDim2.new(0, 0, 0, #LUCKY_BLOCK_OPTIONS * 26) LuckyTypeDropList.ZIndex =
80 LuckyTypeDropList.Parent = MainFrame Instance.new(“UICorner”,
LuckyTypeDropList).CornerRadius = UDim.new(0, 7)

local luckyTypeListLayout = Instance.new(“UIListLayout”)
luckyTypeListLayout.SortOrder = Enum.SortOrder.LayoutOrder
luckyTypeListLayout.Parent = LuckyTypeDropList

for i, boxType in ipairs(LUCKY_BLOCK_OPTIONS) do local item =
Instance.new(“TextButton”) item.Size = UDim2.new(1, -4, 0, 24)
item.BackgroundColor3 = Color3.fromRGB(52, 40, 23) item.BorderSizePixel
= 0 item.Text = ” ” .. boxType item.TextColor3 = Color3.fromRGB(244,
229, 195) item.TextSize = 11 item.Font = Enum.Font.Gotham
item.TextXAlignment = Enum.TextXAlignment.Left item.LayoutOrder = i
item.ZIndex = 81 item.Parent = LuckyTypeDropList

    item.MouseButton1Click:Connect(function()
        selectedLuckyBlockType = boxType
        LuckyTypeDropBtn.Text = "Lucky Type: ▼  " .. boxType
        LuckyTypeDropList.Visible = false

        StatusLabel.Text =
            "Lucky Type selected: " .. boxType
    end)

end

LuckyTypeDropBtn.MouseButton1Click:Connect(function()
UpgradeRarityDropList.Visible = false UpgradeMutationDropList.Visible =
false if PickupRangeDropList then PickupRangeDropList.Visible = false
end LuckyTypeDropList.Visible = not LuckyTypeDropList.Visible end)

local RebirthBtn = createButton(“RebirthToggle”, 200, “Auto Rebirth:
OFF”) local JumpBtn = createButton(“JumpToggle”, 234, “Auto +10 Jump:
OFF”) local BoxesAutoBtn = createButton(“BoxesAutoToggle”, 268, “Auto
Place+Open Boxes: OFF”) local InvisBtn = createButton(“InvisToggle”,
302, “Invis Cloak: OFF”)

– 10-slot pickup ranges: 1-10, 11-20, … 91-100. – These are
non-overlapping groups of exactly 10 slots each. local
PICKUP_RANGE_OPTIONS = {} for startSlot = 1, 100, 10 do local endSlot =
math.min(startSlot + 9, 100) table.insert(PICKUP_RANGE_OPTIONS, { label
= string.format(“%d-%d”, startSlot, endSlot), first = startSlot, last =
endSlot, }) end

local selectedPickupRange = PICKUP_RANGE_OPTIONS[1]

local PickupRangeDropBtn = Instance.new(“TextButton”)
PickupRangeDropBtn.Name = “PickupRangeDrop” PickupRangeDropBtn.Size =
UDim2.new(0, 140, 0, 30) PickupRangeDropBtn.Position = UDim2.new(0, 15,
0, 344) PickupRangeDropBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
PickupRangeDropBtn.BorderSizePixel = 0 PickupRangeDropBtn.Text = “▼” ..
selectedPickupRange.label PickupRangeDropBtn.TextColor3 =
Color3.fromRGB(190, 190, 255) PickupRangeDropBtn.TextSize = 12
PickupRangeDropBtn.Font = Enum.Font.GothamBold PickupRangeDropBtn.ZIndex
= 90 PickupRangeDropBtn.Parent = MainFrame Instance.new(“UICorner”,
PickupRangeDropBtn).CornerRadius = UDim.new(0, 8)

local PickupBtn = Instance.new(“TextButton”) PickupBtn.Name =
“PickupBtn” PickupBtn.Size = UDim2.new(0, 72, 0, 30) PickupBtn.Position
= UDim2.new(0, 163, 0, 344) PickupBtn.BackgroundColor3 =
Color3.fromRGB(45, 35, 70) PickupBtn.BorderSizePixel = 0 PickupBtn.Text
= “Pick Up” PickupBtn.TextColor3 = Color3.fromRGB(205, 175, 255)
PickupBtn.TextSize = 11 PickupBtn.Font = Enum.Font.GothamBold
PickupBtn.ZIndex = 90 PickupBtn.Parent = MainFrame
Instance.new(“UICorner”, PickupBtn).CornerRadius = UDim.new(0, 8)

PickupRangeDropList = Instance.new(“ScrollingFrame”)
PickupRangeDropList.Name = “PickupRangeDropList”
PickupRangeDropList.Size = UDim2.new(0, 220, 0, 156)
PickupRangeDropList.Position = UDim2.new(0, 15, 0, 376)
PickupRangeDropList.BackgroundColor3 = Color3.fromRGB(25, 24, 42)
PickupRangeDropList.BorderSizePixel = 0 PickupRangeDropList.Visible =
false PickupRangeDropList.ScrollBarThickness = 4
PickupRangeDropList.CanvasSize = UDim2.new(0, 0, 0,
#PICKUP_RANGE_OPTIONS * 26) PickupRangeDropList.ZIndex = 100
PickupRangeDropList.Parent = MainFrame Instance.new(“UICorner”,
PickupRangeDropList).CornerRadius = UDim.new(0, 7)

local pickupRangeLayout = Instance.new(“UIListLayout”)
pickupRangeLayout.SortOrder = Enum.SortOrder.LayoutOrder
pickupRangeLayout.Parent = PickupRangeDropList

for i, rangeInfo in ipairs(PICKUP_RANGE_OPTIONS) do local item =
Instance.new(“TextButton”) item.Size = UDim2.new(1, -4, 0, 24)
item.BackgroundColor3 = Color3.fromRGB(39, 36, 61) item.BorderSizePixel
= 0 item.Text = ” Slots ” .. rangeInfo.label item.TextColor3 =
Color3.fromRGB(225, 220, 245) item.TextSize = 11 item.Font =
Enum.Font.Gotham item.TextXAlignment = Enum.TextXAlignment.Left
item.LayoutOrder = i item.ZIndex = 101 item.Parent = PickupRangeDropList

    item.MouseButton1Click:Connect(function()
        selectedPickupRange = rangeInfo
        PickupRangeDropBtn.Text = "▼  " .. rangeInfo.label
        PickupRangeDropList.Visible = false
        StatusLabel.Text = "Pickup range selected: " .. rangeInfo.label
    end)

end

PickupRangeDropBtn.MouseButton1Click:Connect(function()
UpgradeRarityDropList.Visible = false UpgradeMutationDropList.Visible =
false if LuckyTypeDropList then LuckyTypeDropList.Visible = false end
PickupRangeDropList.Visible = not PickupRangeDropList.Visible
PickupRangeDropBtn.Text = (PickupRangeDropList.Visible and “▲” or “▼”)
.. selectedPickupRange.label end)

local PickupAllBtn = createButton(“PickupAllBtn”, 378, “Pick Up ALL
Floors”) local PlaceBtn = createButton(“PlaceBtn”, 412, “Place Slimes
(CURRENT CASH first)”) local BoxesBtn = createButton(“BoxesBtn”, 446,
“Place + Open Selected Boxes (Once)”)

– Side-by-side: Place Boxes | Open Boxes local PlaceBoxesBtn =
Instance.new(“TextButton”) PlaceBoxesBtn.Name = “PlaceBoxesBtn”
PlaceBoxesBtn.Size = UDim2.new(0, 106, 0, 30) PlaceBoxesBtn.Position =
UDim2.new(0, 15, 0, 480) PlaceBoxesBtn.BackgroundColor3 =
Color3.fromRGB(40, 55, 40) PlaceBoxesBtn.BorderSizePixel = 0
PlaceBoxesBtn.Text = “Place Boxes” PlaceBoxesBtn.TextColor3 =
Color3.fromRGB(120, 255, 150) PlaceBoxesBtn.TextSize = 11
PlaceBoxesBtn.Font = Enum.Font.GothamBold PlaceBoxesBtn.Parent =
MainFrame Instance.new(“UICorner”, PlaceBoxesBtn).CornerRadius =
UDim.new(0, 8)

local OpenBoxesBtn = Instance.new(“TextButton”) OpenBoxesBtn.Name =
“OpenBoxesBtn” OpenBoxesBtn.Size = UDim2.new(0, 106, 0, 30)
OpenBoxesBtn.Position = UDim2.new(0, 129, 0, 480)
OpenBoxesBtn.BackgroundColor3 = Color3.fromRGB(55, 45, 25)
OpenBoxesBtn.BorderSizePixel = 0 OpenBoxesBtn.Text = “Open Boxes”
OpenBoxesBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
OpenBoxesBtn.TextSize = 11 OpenBoxesBtn.Font = Enum.Font.GothamBold
OpenBoxesBtn.Parent = MainFrame Instance.new(“UICorner”,
OpenBoxesBtn).CornerRadius = UDim.new(0, 8)

– ============================================ – MANUAL PICK / PLACE
DUAL FILTERS – Rarity and Mutation are independent. – A slime must match
BOTH selected filters. – “All” is available for each filter. – Mutation
“None” means no base mutation AND no event mutation. –
============================================ local ManualFilters = {
pickRarity = “All”, pickMutation = “All”, placeRarity = “All”,
placeMutation = “All”, }

do local rarityOptions = {“All”} for _, rarityName in
ipairs(ALL_RARITIES) do table.insert(rarityOptions, rarityName) end

    local mutationOptions = {"All", "None"}
    for _, mutationName in ipairs(ALL_MUTATIONS) do
        table.insert(mutationOptions, mutationName)
    end

    local PickFilterLabel = Instance.new("TextLabel")
    PickFilterLabel.Size = UDim2.new(0, 220, 0, 16)
    PickFilterLabel.Position = UDim2.new(0, 15, 0, 518)
    PickFilterLabel.BackgroundTransparency = 1
    PickFilterLabel.Text = "Pick Up by Rarity + Mutation:"
    PickFilterLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    PickFilterLabel.TextSize = 11
    PickFilterLabel.Font = Enum.Font.Gotham
    PickFilterLabel.TextXAlignment = Enum.TextXAlignment.Left
    PickFilterLabel.Parent = MainFrame

    local PlaceFilterLabel = Instance.new("TextLabel")
    PlaceFilterLabel.Size = UDim2.new(0, 220, 0, 16)
    PlaceFilterLabel.Position = UDim2.new(0, 15, 0, 606)
    PlaceFilterLabel.BackgroundTransparency = 1
    PlaceFilterLabel.Text = "Place by Rarity + Mutation:"
    PlaceFilterLabel.TextColor3 = Color3.fromRGB(210, 180, 255)
    PlaceFilterLabel.TextSize = 11
    PlaceFilterLabel.Font = Enum.Font.Gotham
    PlaceFilterLabel.TextXAlignment = Enum.TextXAlignment.Left
    PlaceFilterLabel.Parent = MainFrame

    local function closeManualLists(except)
        for _, list in ipairs({
            ManualFilters.pickRarityList,
            ManualFilters.pickMutationList,
            ManualFilters.placeRarityList,
            ManualFilters.placeMutationList,
        }) do
            if list and list ~= except then
                list.Visible = false
            end
        end

        if PickupRangeDropList then PickupRangeDropList.Visible = false end
        if UpgradeRarityDropList then UpgradeRarityDropList.Visible = false end
        if UpgradeMutationDropList then UpgradeMutationDropList.Visible = false end
        if LuckyTypeDropList then LuckyTypeDropList.Visible = false end
    end

    local function makeFilterDropdown(name, x, y, listY, labelPrefix, options, stateKey, bg, fg, listBg, itemBg, z)
        local btn = Instance.new("TextButton")
        btn.Name = name .. "Button"
        btn.Size = UDim2.new(0, 106, 0, 28)
        btn.Position = UDim2.new(0, x, 0, y)
        btn.BackgroundColor3 = bg
        btn.BorderSizePixel = 0
        btn.Text = labelPrefix .. ": ▼ All"
        btn.TextColor3 = fg
        btn.TextSize = 10
        btn.Font = Enum.Font.GothamBold
        btn.ZIndex = z
        btn.Parent = MainFrame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local list = Instance.new("ScrollingFrame")
        list.Name = name .. "List"
        list.Size = UDim2.new(0, 220, 0, 168)
        list.Position = UDim2.new(0, 15, 0, listY)
        list.BackgroundColor3 = listBg
        list.BorderSizePixel = 0
        list.Visible = false
        list.ScrollBarThickness = 4
        list.CanvasSize = UDim2.new(0, 0, 0, #options * 26)
        list.ZIndex = z + 10
        list.Parent = MainFrame
        Instance.new("UICorner", list).CornerRadius = UDim.new(0, 6)
        Instance.new("UIListLayout", list).SortOrder = Enum.SortOrder.LayoutOrder

        for i, option in ipairs(options) do
            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1, -4, 0, 24)
            item.BackgroundColor3 = itemBg
            item.BorderSizePixel = 0
            item.Text = "  " .. tostring(option)
            item.TextColor3 = Color3.fromRGB(230, 230, 240)
            item.TextSize = 11
            item.Font = Enum.Font.Gotham
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.LayoutOrder = i
            item.ZIndex = z + 11
            item.Parent = list

            item.MouseButton1Click:Connect(function()
                ManualFilters[stateKey] = option
                btn.Text = labelPrefix .. ": ▼ " .. tostring(option)
                list.Visible = false
                StatusLabel.Text = string.format(
                    "%s filter = %s",
                    labelPrefix == "R" and "Rarity" or "Mutation",
                    tostring(option)
                )
            end)
        end

        btn.MouseButton1Click:Connect(function()
            closeManualLists(list)
            list.Visible = not list.Visible
            btn.Text = labelPrefix
                .. (list.Visible and ": ▲ " or ": ▼ ")
                .. tostring(ManualFilters[stateKey])
        end)

        return btn, list
    end

    ManualFilters.pickRarityButton, ManualFilters.pickRarityList =
        makeFilterDropdown(
            "PickRarityFilter", 15, 536, 566, "R",
            rarityOptions, "pickRarity",
            Color3.fromRGB(35, 40, 55),
            Color3.fromRGB(185, 210, 255),
            Color3.fromRGB(20, 24, 34),
            Color3.fromRGB(35, 40, 50),
            120
        )

    ManualFilters.pickMutationButton, ManualFilters.pickMutationList =
        makeFilterDropdown(
            "PickMutationFilter", 129, 536, 566, "M",
            mutationOptions, "pickMutation",
            Color3.fromRGB(48, 34, 62),
            Color3.fromRGB(225, 195, 255),
            Color3.fromRGB(31, 22, 40),
            Color3.fromRGB(45, 31, 58),
            125
        )

    ManualFilters.pickButton = Instance.new("TextButton")
    ManualFilters.pickButton.Name = "PickDualFilterBtn"
    ManualFilters.pickButton.Size = UDim2.new(0, 220, 0, 28)
    ManualFilters.pickButton.Position = UDim2.new(0, 15, 0, 570)
    ManualFilters.pickButton.BackgroundColor3 = Color3.fromRGB(50, 40, 80)
    ManualFilters.pickButton.BorderSizePixel = 0
    ManualFilters.pickButton.Text = "Pick Matching Players"
    ManualFilters.pickButton.TextColor3 = Color3.fromRGB(205, 180, 255)
    ManualFilters.pickButton.TextSize = 11
    ManualFilters.pickButton.Font = Enum.Font.GothamBold
    ManualFilters.pickButton.Parent = MainFrame
    Instance.new("UICorner", ManualFilters.pickButton).CornerRadius = UDim.new(0, 6)

    ManualFilters.placeRarityButton, ManualFilters.placeRarityList =
        makeFilterDropdown(
            "PlaceRarityFilter", 15, 624, 654, "R",
            rarityOptions, "placeRarity",
            Color3.fromRGB(35, 48, 44),
            Color3.fromRGB(175, 230, 195),
            Color3.fromRGB(22, 34, 30),
            Color3.fromRGB(34, 48, 42),
            130
        )

    ManualFilters.placeMutationButton, ManualFilters.placeMutationList =
        makeFilterDropdown(
            "PlaceMutationFilter", 129, 624, 654, "M",
            mutationOptions, "placeMutation",
            Color3.fromRGB(45, 35, 65),
            Color3.fromRGB(225, 205, 255),
            Color3.fromRGB(25, 20, 35),
            Color3.fromRGB(42, 32, 55),
            135
        )

    ManualFilters.placeButton = Instance.new("TextButton")
    ManualFilters.placeButton.Name = "PlaceDualFilterBtn"
    ManualFilters.placeButton.Size = UDim2.new(0, 220, 0, 28)
    ManualFilters.placeButton.Position = UDim2.new(0, 15, 0, 658)
    ManualFilters.placeButton.BackgroundColor3 = Color3.fromRGB(48, 38, 68)
    ManualFilters.placeButton.BorderSizePixel = 0
    ManualFilters.placeButton.Text = "Place Matching Players"
    ManualFilters.placeButton.TextColor3 = Color3.fromRGB(220, 195, 255)
    ManualFilters.placeButton.TextSize = 11
    ManualFilters.placeButton.Font = Enum.Font.GothamBold
    ManualFilters.placeButton.Parent = MainFrame
    Instance.new("UICorner", ManualFilters.placeButton).CornerRadius = UDim.new(0, 6)

end

PickupAllBtn.TextColor3 = Color3.fromRGB(200, 160, 255)
PickupAllBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 70)
PlaceBtn.TextColor3 = Color3.fromRGB(120, 220, 150)
PlaceBtn.BackgroundColor3 = Color3.fromRGB(30, 50, 40)
BoxesBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
BoxesBtn.BackgroundColor3 = Color3.fromRGB(55, 40, 20)

print(“[AutoFarm] GUI — ICONS UPDATE + selected-type Place/Open burst
buttons”) print(“[LuckyCollector] NO INVISIBILITY GATE BUILD”)

– ============================================ – STATE –
============================================ local collectEnabled,
upgradeEnabled, luckyEnabled = false, false, false local rebirthEnabled,
jumpUpgradeEnabled, boxesAutoEnabled = false, false, false local
invisEnabled = false local totalCollected = 0 local luckyBlockBusy,
actionBusy = false, false

local _Lib = nil local CollectRemote, UpgradeRemote, RebirthRemote,
JumpUpgradeRemote local ResolveUpgradeRemote local PlaceRemote,
PickupRemote, OpenRemote local UpgradeChannel = nil local
getPrioritizedUpgrades

local GiftChannel = nil local GiftRawRemote = nil local
AcceptGiftChannel = nil local AcceptGiftRawRemote = nil local
GiftRequestChannel = nil local giftRequestConnection = nil

– Match the game’s own gifting handler exactly: – _Lib.Network.new(“Gift
Slime”, “RemoteFunction”):Fire(playerName, slimeUID) local function
ResolveGiftChannel() if GiftChannel and type(GiftChannel) == “table”
then return GiftChannel end

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

local function ResolveGiftRawRemote() if GiftRawRemote and
GiftRawRemote.Parent and GiftRawRemote:IsA(“RemoteFunction”) then return
GiftRawRemote end

    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteFunction") and v.Name == "Gift Slime" then
            GiftRawRemote = v
            return GiftRawRemote
        end
    end

    return nil

end

local function ResolveAcceptGiftChannel() if AcceptGiftChannel and
type(AcceptGiftChannel) == “table” then return AcceptGiftChannel end

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

local function ResolveAcceptGiftRawRemote() if AcceptGiftRawRemote and
AcceptGiftRawRemote.Parent and AcceptGiftRawRemote:IsA(“RemoteFunction”)
then return AcceptGiftRawRemote end

    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteFunction") and v.Name == "Accept Gift" then
            AcceptGiftRawRemote = v
            return AcceptGiftRawRemote
        end
    end

    return nil

end

local function FireAcceptGift(slimeUID) if slimeUID == nil then return
false, “No pending gift UID” end

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

local function ResolveGiftRequestChannel() if GiftRequestChannel and
type(GiftRequestChannel) == “table” then return GiftRequestChannel end

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

local function getPendingGiftUIDFromGui() if not PlayerGui then return
nil end

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

local function hookGiftRequestListener() if giftRequestConnection then
return true end

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

local function FireGiftSlime(playerName, slimeUID) if
LocalPlayer:GetAttribute(“OldDataMigrationLocked”) == true then return
false, “Trade/Gift locked while saved data is loading” end

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

– Match the latest game’s own upgrade path exactly: –
_Lib.Network.new(“Upgrade Slime”, “RemoteEvent”):Fire(slotName) – Raw
RemoteEvent is retained only as a fallback. local function
ResolveUpgradeChannel() if UpgradeChannel and type(UpgradeChannel) ==
“table” then return UpgradeChannel end

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

local function FireUpgradeSlot(slotName) slotName = tostring(slotName)

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

– Robust exact RemoteEvent resolver. – The old Place button silently
returned when PlaceRemote had not been cached yet. local function
ResolveRemoteEventExact(name) for _, v in
ipairs(ReplicatedStorage:GetDescendants()) do if v:IsA(“RemoteEvent”)
and v.Name == name then return v end end

    return nil

end

local function ResolvePlaceRemote() if PlaceRemote and
PlaceRemote.Parent and PlaceRemote:IsA(“RemoteEvent”) then return
PlaceRemote end

    PlaceRemote = ResolveRemoteEventExact("Place Slime")
    return PlaceRemote

end

ResolveUpgradeRemote = function() if UpgradeRemote and
UpgradeRemote.Parent and UpgradeRemote:IsA(“RemoteEvent”) then return
UpgradeRemote end

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

local function setCollectState(on) collectEnabled = on CollectBtn.Text =
on and “Auto Collect: ON” or “Auto Collect: OFF” CollectBtn.TextColor3 =
on and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 90, 90)
CollectBtn.BackgroundColor3 = on and Color3.fromRGB(30, 55, 40) or
Color3.fromRGB(40, 40, 50) end local function setUpgradeState(on)
upgradeEnabled = on UpgradeBtn.Text = on and “Auto Upgrade: ON” or “Auto
Upgrade: OFF” UpgradeBtn.TextColor3 = on and Color3.fromRGB(80, 180,
255) or Color3.fromRGB(255, 90, 90) UpgradeBtn.BackgroundColor3 = on and
Color3.fromRGB(25, 45, 70) or Color3.fromRGB(40, 40, 50)

    StatusLabel.Text =
        "Auto Upgrade "
        .. (on and "ON" or "OFF")
        .. " | Rarity: "
        .. upgradeRarityDisplayName(selectedUpgradeRarity)
        .. " | Mutation: "
        .. upgradeMutationDisplayName(selectedUpgradeMutation)

end local function setLuckyState(on) luckyEnabled = on if on then
totalCollected = 0 LuckyBtn.Text = “Lucky Block: ON” LuckyBtn.TextColor3
= Color3.fromRGB(255, 200, 80) LuckyBtn.BackgroundColor3 =
Color3.fromRGB(60, 45, 20) StatusLabel.Text = “Lucky Block: ON | Type:”
.. selectedLuckyBlockType else LuckyBtn.Text = “Lucky Block: OFF”
LuckyBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
LuckyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50) luckyBlockBusy =
false end end local function setRebirthState(on) rebirthEnabled = on
RebirthBtn.Text = on and “Auto Rebirth: ON” or “Auto Rebirth: OFF”
RebirthBtn.TextColor3 = on and Color3.fromRGB(255, 150, 50) or
Color3.fromRGB(255, 90, 90) RebirthBtn.BackgroundColor3 = on and
Color3.fromRGB(70, 45, 15) or Color3.fromRGB(40, 40, 50) end local
function setJumpUpgradeState(on) jumpUpgradeEnabled = on JumpBtn.Text =
on and “Auto +10 Jump: ON” or “Auto +10 Jump: OFF” JumpBtn.TextColor3 =
on and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(255, 90, 90)
JumpBtn.BackgroundColor3 = on and Color3.fromRGB(30, 60, 40) or
Color3.fromRGB(40, 40, 50) end local function setBoxesAutoState(on)
boxesAutoEnabled = on BoxesAutoBtn.Text = on and “Auto Place+Open Boxes:
ON” or “Auto Place+Open Boxes: OFF” BoxesAutoBtn.TextColor3 = on and
Color3.fromRGB(255, 200, 80) or Color3.fromRGB(255, 90, 90)
BoxesAutoBtn.BackgroundColor3 = on and Color3.fromRGB(60, 45, 20) or
Color3.fromRGB(40, 40, 50) end local function setInvisState(on)
invisEnabled = on InvisBtn.Text = on and “Invis Cloak: ON” or “Invis
Cloak: OFF” InvisBtn.TextColor3 = on and Color3.fromRGB(180, 120, 255)
or Color3.fromRGB(255, 90, 90) InvisBtn.BackgroundColor3 = on and
Color3.fromRGB(45, 30, 70) or Color3.fromRGB(40, 40, 50) end

CollectBtn.MouseButton1Click:Connect(function() setCollectState(not
collectEnabled) end) UpgradeBtn.MouseButton1Click:Connect(function()
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

end) LuckyBtn.MouseButton1Click:Connect(function() setLuckyState(not
luckyEnabled) end) RebirthBtn.MouseButton1Click:Connect(function()
setRebirthState(not rebirthEnabled) end)
JumpBtn.MouseButton1Click:Connect(function() setJumpUpgradeState(not
jumpUpgradeEnabled) end)
BoxesAutoBtn.MouseButton1Click:Connect(function() setBoxesAutoState(not
boxesAutoEnabled) end) InvisBtn.MouseButton1Click:Connect(function()
setInvisState(not invisEnabled) end)

– ============================================ – REMOTES –
============================================ task.spawn(function() local
start = os.clock() while not _G._Lib and (os.clock() - start) < 30 do
StatusLabel.Text = string.format(“Waiting for game… %.0fs”, os.clock() -
start) task.wait(0.5) end _Lib = _G._Lib StatusLabel.Text = _Lib and
“Ready” or “WARNING: _G._Lib missing”

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

– ============================================ – HELPERS –
============================================ local function getCash() if
_Lib and _Lib.Data then local ok, data = pcall(function() return
_Lib.Data:Get() end) if ok and data and type(data.Cash) == “number” then
return data.Cash end end local ls =
LocalPlayer:FindFirstChild(“leaderstats”) if ls then local c =
ls:FindFirstChild(“Cash”) or ls:FindFirstChild(“Money”) if c then return
c.Value end end return 0 end

local function getJumpData() if _Lib and _Lib.Data then local ok, data =
pcall(function() return _Lib.Data:Get() end) if ok and data and
type(data.Jump) == “number” then return data.Jump end end local ls =
LocalPlayer:FindFirstChild(“leaderstats”) if ls then local j =
ls:FindFirstChild(“Jumps”) or ls:FindFirstChild(“Jump”) if j then return
j.Value end end return 0 end

local function getData() – Preferred source: game’s local data library.
if _Lib and _Lib.Data then local ok, data = pcall(function() return
_Lib.Data:Get() end)

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

local function trimText(value) value = tostring(value or ““) return
value:match(”^%s(.-)%s$“) or”” end

local function resolveGiftTarget(input) local wanted =
string.lower(trimText(input)) if wanted == “” then return nil, “Type a
player username first” end

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

local function setAutoAcceptGiftsState(on) autoAcceptGiftsEnabled = on
== true

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

local function setGiftAllState(on, resolvedPlayer) giftAllEnabled = on
== true

    if giftAllEnabled then
        giftTargetName = resolvedPlayer and resolvedPlayer.Name or giftTargetName
        GiftAllBtn.Text = "Gift All: ON"
        GiftAllBtn.TextColor3 = Color3.fromRGB(105, 255, 145)
        GiftAllBtn.BackgroundColor3 = Color3.fromRGB(30, 62, 43)
        GiftNameBox.TextEditable = false
        GiftStatus.Text = "Target: " .. tostring(giftTargetName) .. " | highest cash/s first..."
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

local function getBaseLevel(data) data = data or getData() if data and
type(data.BaseLevel) == “number” then return data.BaseLevel end return
LocalPlayer:GetAttribute(“BaseLevel”) or 0 end

local function getMyPlot() if _G.MyPlot and _G.MyPlot.Parent then return
G.MyPlot end local plots = workspace:FindFirstChild(“Plots”) if not
plots then return nil end for , plot in ipairs(plots:GetChildren()) do
local owner = plot:FindFirstChild(“owner”) if owner and
tostring(owner.Value) == LocalPlayer.Name then return plot end end end

local function getPlayerSlimesFolder() local live =
workspace:FindFirstChild(“Live”) local ps = live and
live:FindFirstChild(“PlayerSlimes”) return ps and
ps:FindFirstChild(LocalPlayer.Name) end

local function getHumanoid() local c = LocalPlayer.Character return c
and c:FindFirstChildOfClass(“Humanoid”) end

local function isUnlocked(slotName, baseLevel) if IGNORE_LOCK then
return true end local n = tonumber(slotName) if not n then return true
end return n <= 10 or (n - 10) <= (baseLevel or 0) end

local function isOccupied(slotName, plotSlimes, playerSlimesFolder,
stand) if type(plotSlimes) == “table” then if plotSlimes[slotName] or
plotSlimes[tostring(slotName)] then return true end local n =
tonumber(slotName) if n and plotSlimes[n] then return true end end if
playerSlimesFolder and
playerSlimesFolder:FindFirstChild(tostring(slotName)) then return true
end if stand then local main = stand:FindFirstChild(“Main”) local holder
= main and main:FindFirstChild(“Holder”) local pick = holder and
holder:FindFirstChild(“Pick Up”) if pick and pick:IsA(“ProximityPrompt”)
and pick.Enabled then return true end end return false end

local function getOccupiedSlotsInRange(firstSlot, lastSlot) firstSlot =
tonumber(firstSlot) or 1 lastSlot = tonumber(lastSlot) or firstSlot

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

local function getAllOccupiedSlots() local data = getData() local
plotSlimes = (data and data.PlotSlimes) or {} local plot = getMyPlot()
local liveFolder = getPlayerSlimesFolder() local list = {} if not plot
then return list end local stands = plot:FindFirstChild(“Stands”) if not
stands then return list end for _, stand in ipairs(stands:GetChildren())
do local name = stand.Name if isOccupied(name, plotSlimes, liveFolder,
stand) then table.insert(list, { name = name, num = tonumber(name) or
9999, stand = stand }) end end table.sort(list, function(a, b) return
a.num < b.num end) return list end

local function getSlotRarityAndMutation(slotName, stand, plotSlimes,
liveFolder) local rarity, mutation = nil, nil local hasEventMutation =
false local eventMutationNames = {}

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

local function manualMutationMatches(selectedMutation, mutation,
hasEventMutation, eventMutationNames) local wanted =
string.lower(tostring(selectedMutation or “All”))

    if wanted == "all" then
        return true
    end

    if wanted == "none"
        or wanted == "no mutation"
        or wanted == "normal"
    then
        return mutation == nil and not hasEventMutation
    end

    if mutation ~= nil
        and string.lower(tostring(mutation)) == wanted
    then
        return true
    end

    return type(eventMutationNames) == "table"
        and eventMutationNames[wanted] == true

end

local function getOccupiedSlotsByDualFilter(rarityFilter,
mutationFilter) local data = getData() local plotSlimes = (data and
data.PlotSlimes) or {} local plot = getMyPlot() local liveFolder =
getPlayerSlimesFolder() local list = {}

    if not plot then return list end

    local stands = plot:FindFirstChild("Stands")
    if not stands then return list end

    local wantedRarity = string.lower(tostring(rarityFilter or "All"))

    for _, stand in ipairs(stands:GetChildren()) do
        local slotName = tostring(stand.Name)

        if isOccupied(slotName, plotSlimes, liveFolder, stand) then
            local rarity, mutation, hasEventMutation, eventMutationNames =
                getSlotRarityAndMutation(
                    slotName,
                    stand,
                    plotSlimes,
                    liveFolder
                )

            local normalizedRarity = tostring(rarity or "")
            if normalizedRarity == "Player God" then
                normalizedRarity = "Slime God"
            end

            local rarityMatches =
                wantedRarity == "all"
                or string.lower(normalizedRarity) == wantedRarity

            local mutationMatches = manualMutationMatches(
                mutationFilter,
                mutation,
                hasEventMutation,
                eventMutationNames
            )

            if rarityMatches and mutationMatches then
                table.insert(list, {
                    name = slotName,
                    num = tonumber(slotName) or 9999,
                    stand = stand,
                    rarity = normalizedRarity,
                    mutation = mutation or "None",
                })
            end
        end
    end

    table.sort(list, function(a, b)
        return a.num < b.num
    end)

    return list

end

local function getAvailableSlots() local data = getData() local
baseLevel = getBaseLevel(data) local plotSlimes = (data and
data.PlotSlimes) or {} local plot = getMyPlot() local liveFolder =
getPlayerSlimesFolder() local free = {} if not plot then return free end
local stands = plot:FindFirstChild(“Stands”) if not stands then return
free end for _, stand in ipairs(stands:GetChildren()) do local n =
tonumber(stand.Name) if n == nil and not stand:FindFirstChild(“Main”)
then continue end if isUnlocked(stand.Name, baseLevel) and not
isOccupied(stand.Name, plotSlimes, liveFolder, stand) then
table.insert(free, { name = stand.Name, num = n or 999, stand = stand })
end end table.sort(free, function(a, b) return a.num < b.num end) return
free end

– Slots that currently hold an unopened Lucky Block local function
getUnopenedLuckyBlockSlots(filterType) filterType = tostring(filterType
or “All”)

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

    local function entryMatches(entry)
        if filterType == "All" then
            return true
        end

        if type(entry) ~= "table" then
            return false
        end

        local slimeId =
            entry.id
            or entry.Id
            or entry.slimeId
            or entry.slimeID

        local def = nil

        if slimeId ~= nil
            and _Lib
            and _Lib.Database
            and _Lib.Database.Slimes
        then
            local db = _Lib.Database.Slimes
            def =
                db[slimeId]
                or db[tostring(slimeId)]
                or db[tonumber(slimeId)]
        end

        local allowed = LUCKY_BLOCK_MODEL_NAMES[filterType]

        if allowed then
            local names = {
                tostring((def and def.Name) or ""),
                tostring(entry.Name or entry.name or ""),
            }

            for _, candidateName in ipairs(names) do
                if allowed[candidateName] == true then
                    return true
                end
            end
        end

        local rarity =
            (def and (def.Rarity or def.rarity))
            or entry.Rarity
            or entry.rarity

        if rarity then
            local r = tostring(rarity)

            if filterType == "Soccer God" and r == "Slime God" then
                return true
            end

            if filterType == "Limited" and r == "LIMITED" then
                return true
            end

            if string.lower(r) == string.lower(filterType) then
                return true
            end
        end

        return false
    end

    if type(plotSlimes) == "table" then
        for k, entry in pairs(plotSlimes) do
            if type(entry) == "table" then
                local slimeId =
                    entry.id
                    or entry.Id
                    or entry.slimeId
                    or entry.slimeID

                local def = nil

                if slimeId ~= nil
                    and _Lib
                    and _Lib.Database
                    and _Lib.Database.Slimes
                then
                    local db = _Lib.Database.Slimes
                    def =
                        db[slimeId]
                        or db[tostring(slimeId)]
                        or db[tonumber(slimeId)]
                end

                local typ =
                    tostring(
                        (def and def.Type)
                        or entry.Type
                        or entry.type
                        or ""
                    )

                if typ:lower():find("lucky", 1, true)
                    and entryMatches(entry)
                then
                    add(k)
                end
            end
        end
    end

    -- Fallback prompt scan is safe for "All".
    -- For a selected type we only use it if plot data did not identify anything,
    -- because a bare OPEN prompt does not expose the Lucky Block variant.
    if filterType == "All" or #list == 0 then
        local plot = getMyPlot()
        local stands = plot and plot:FindFirstChild("Stands")

        if stands then
            for _, stand in ipairs(stands:GetChildren()) do
                local entry =
                    type(plotSlimes) == "table"
                    and (
                        plotSlimes[stand.Name]
                        or plotSlimes[tostring(stand.Name)]
                        or plotSlimes[tonumber(stand.Name)]
                    )
                    or nil

                local allowFallback =
                    filterType == "All"
                    or (entry and entryMatches(entry))

                if allowFallback then
                    for _, d in ipairs(stand:GetDescendants()) do
                        if d:IsA("ProximityPrompt") and d.Enabled then
                            local at =
                                string.lower(tostring(d.ActionText or ""))

                            if at:find("open", 1, true) then
                                add(stand.Name)
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(list, function(a, b)
        return (tonumber(a) or 9999) < (tonumber(b) or 9999)
    end)

    return list

end

– ============================================================ – CURRENT
OWNED SLIME EARNINGS / PLACEMENT PRIORITY – – IMPORTANT: – The source of
truth is Data.Inventory, NOT Tool attributes. – – This mirrors the
game’s own “Equip Best” logic: – 1) Match each current inventory record
to its Tool by slimeUID – 2) Resolve that exact slime definition by
inventoryEntry.id – 3) Use THAT individual slime’s inventoryEntry.level
– 4) Apply THAT individual slime’s mutation + event_mutations – 5) Apply
current rebirth CashMulti – 6) Sort the final calculated earnings
DESCENDING – – Therefore: – A highly-upgraded NORMAL slime can rank
above a low-level CURSED slime. – Mutation rarity/name does NOT
determine placement order. – Only the final calculated money generation
determines order. –
============================================================

local function getInventoryTable(playerData) if not playerData then
return nil end

    if type(playerData.Inventory) == "table" then
        return playerData.Inventory
    end

    return nil

end

local function getRebirthCashMultiplier(playerData) if not playerData
then return 1 end

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

local function resolveSlimeDefinition(inventoryEntry) if
type(inventoryEntry) ~= “table” then return nil end

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

local function isLuckyInventoryEntry(tool, inventoryEntry, def) local
function containsBoxWord(value) value = string.lower(tostring(value or
““))

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

local function getBaseProductionMPS(inventoryEntry, def) – This is
exactly the priority used by the game’s own Equip Best: – database
MoneyPerSecond first, persisted production fallback second. local
baseMps = def and tonumber(def.MoneyPerSecond) or nil

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

local function calculateOwnedSlimeEarnings(inventoryEntry, def,
playerData) if type(inventoryEntry) ~= “table” then return 0 end

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

– Gift queue ordered by the EXACT same final CURRENT cash/s used by
Place Slimes. – This means level + rebirth + base production +
mutation/event mutation + – invite/friend/admin production multipliers
are already included. local function getGiftableInventoryUIDs() local
data = getData() local inventory = data and data.Inventory local list,
seen = {}, {}

    if type(inventory) ~= "table" then
        return list
    end

    for _, entry in pairs(inventory) do
        if type(entry) == "table" and entry.uid ~= nil then
            local key = tostring(entry.uid)

            if not seen[key] then
                seen[key] = true

                local def = resolveSlimeDefinition(entry)
                local earnings = calculateOwnedSlimeEarnings(entry, def, data)
                local rarity =
                    (def and (def.Rarity or def.rarity))
                    or entry.Rarity
                    or entry.rarity
                    or "Unknown"

                if tostring(rarity) == "Player God" then
                    rarity = "Slime God"
                end

                table.insert(list, {
                    uid = entry.uid,
                    value = tonumber(earnings) or 0,
                    level = math.max(1, tonumber(entry.level) or 1),
                    mutation = entry.mutation or entry.Mutation or "None",
                    rarity = tostring(rarity),
                    displayName =
                        (def and def.Name)
                        or tostring(entry.Name or entry.name or entry.id or entry.uid),
                })
            end
        end
    end

    table.sort(list, function(a, b)
        local av = tonumber(a.value) or 0
        local bv = tonumber(b.value) or 0

        if av ~= bv then
            return av > bv
        end

        if (a.level or 1) ~= (b.level or 1) then
            return (a.level or 1) > (b.level or 1)
        end

        return tostring(a.uid) < tostring(b.uid)
    end)

    return list

end

– Return currently PLACED normal players ordered by CURRENT cash/s
ASCENDING. – This intentionally mirrors the same earnings calculation
used by – “Place Slimes (CURRENT CASH first)”, then reverses the
priority. local function getLowestProfitPlacedSlots(requestedCount)
requestedCount = math.max(1, math.floor(tonumber(requestedCount) or 1))

    local playerData = getData()
    local plotSlimes = (playerData and playerData.PlotSlimes) or {}
    local plot = getMyPlot()
    local liveFolder = getPlayerSlimesFolder()
    local ranked = {}

    if type(plotSlimes) ~= "table" or not plot then
        return ranked, 0
    end

    local stands = plot:FindFirstChild("Stands")
    if not stands then
        return ranked, 0
    end

    for _, stand in ipairs(stands:GetChildren()) do
        local slotName = tostring(stand.Name)

        if isOccupied(slotName, plotSlimes, liveFolder, stand) then
            local entry =
                plotSlimes[slotName]
                or plotSlimes[tonumber(slotName)]

            if type(entry) == "table" then
                local def = resolveSlimeDefinition(entry)

                -- Do not include unopened Lucky Blocks / crates in profit pickup.
                if not isLuckyInventoryEntry(nil, entry, def) then
                    local earnings = calculateOwnedSlimeEarnings(
                        entry,
                        def,
                        playerData
                    )

                    table.insert(ranked, {
                        name = slotName,
                        num = tonumber(slotName) or 9999,
                        stand = stand,
                        value = tonumber(earnings) or 0,
                        level = math.max(1, tonumber(entry.level) or 1),
                        mutation = entry.mutation or entry.Mutation or "None",
                        id = entry.id or entry.Id,
                        displayName =
                            (def and def.Name)
                            or tostring(entry.Name or entry.name or entry.id or slotName),
                    })
                end
            end
        end
    end

    table.sort(ranked, function(a, b)
        local aCash = tonumber(a.value) or 0
        local bCash = tonumber(b.value) or 0

        if aCash ~= bCash then
            return aCash < bCash
        end

        if (a.level or 1) ~= (b.level or 1) then
            return (a.level or 1) < (b.level or 1)
        end

        return (a.num or 9999) < (b.num or 9999)
    end)

    local totalPlaced = #ranked
    local limited = {}
    local take = math.min(requestedCount, totalPlaced)

    for i = 1, take do
        limited[i] = ranked[i]
    end

    return limited, totalPlaced

end

local function collectCurrentSlimeToolsByUID() local toolsByUID = {}

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

local function getSlimeTools() local playerData = getData() local
inventory = getInventoryTable(playerData) local toolsByUID =
collectCurrentSlimeToolsByUID() local list = {}

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
                        rarity =
                            (def and (def.Rarity or def.rarity))
                            or inventoryEntry.Rarity
                            or inventoryEntry.rarity
                            or "Unknown",
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

local function normalizeMutationName(mutation) mutation =
tostring(mutation or “None”) mutation = string.lower(mutation) if
mutation == “” or mutation == “nil” or mutation == “none” or mutation ==
“normal” or mutation == “no mutation” then return “None” end return
mutation end

– Robust rarity resolver for held tools. Some live items store rarity in
– different fields (rarity, Rarity, tier, Attributes, or display names).
local function resolveHeldToolRarity(entry) local candidates = {
entry.rarity, entry.Rarity, entry.tier, entry.Tier, entry.displayRarity,
entry.displayName, entry.name, entry.id, }

    for _, value in ipairs(candidates) do
        if value ~= nil then
            local text = tostring(value)
            local lower = string.lower(text)

            if lower:find("icons") then return "Icons" end
            if lower:find("spain") then return "Spain" end
            if lower:find("champion") then return "Champions" end
            if lower:find("exclusive") then return "Exclusive" end
            if lower:find("legendary") then return "Legendary" end
            if lower:find("mythic") then return "Mythic" end
            if lower:find("secret") then return "Secret" end
            if lower:find("divine") then return "Divine" end
            if lower:find("rare") then return "Rare" end
            if lower:find("epic") then return "Epic" end
            if lower:find("common") then return "Common" end
        end
    end

    return tostring(entry.rarity or "")

end

local function getHeldSlimeToolsByDualFilter(rarityFilter,
mutationFilter) local allTools = getSlimeTools() local filtered = {}
local wantedRarity = string.lower(tostring(rarityFilter or “All”))

    for _, entry in ipairs(allTools) do
        local entryRarity = resolveHeldToolRarity(entry)
        if entryRarity == "Player God" then
            entryRarity = "Slime God"
        end

        local rarityMatches =
            wantedRarity == "all"
            or string.lower(entryRarity) == wantedRarity

        local eventNames = {}
        local hasEventMutation = false
        local eventMutations = entry.eventMutations

        if type(eventMutations) == "table" then
            for k, v in pairs(eventMutations) do
                local name = nil

                if type(k) == "string" and v == true then
                    name = k
                elseif type(v) == "string" then
                    name = v
                elseif type(k) == "string" then
                    name = k
                end

                if name then
                    local lower = string.lower(tostring(name))
                    if lower ~= "" and lower ~= "none" then
                        eventNames[lower] = true
                        hasEventMutation = true
                    end
                end
            end
        elseif eventMutations ~= nil then
            local lower = string.lower(tostring(eventMutations))
            if lower ~= "" and lower ~= "none" then
                eventNames[lower] = true
                hasEventMutation = true
            end
        end

        local baseMutation = entry.mutation
        if baseMutation ~= nil then
            local lower = string.lower(tostring(baseMutation))
            if lower == "" or lower == "none" or lower == "normal" or lower == "no mutation" then
                baseMutation = nil
            end
        end

        local mutationMatches = manualMutationMatches(
            mutationFilter,
            baseMutation,
            hasEventMutation,
            eventNames
        )

        if rarityMatches and mutationMatches then
            table.insert(filtered, entry)
        end
    end

    -- Keep the exact same CURRENT final cash/s placement priority.
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

local function isLuckyBlock(tool) if not tool or not tool:IsA(“Tool”)
then return false end local typ = tool:GetAttribute(“Type”) or
tool:GetAttribute(“type”) if typ and tostring(typ):lower():find(“lucky”)
then return true end local name = tostring(tool.Name):lower() if
name:find(“lucky”) or name:find(“box”) or name:find(“crate”) then return
true end for _, n in ipairs({“spain”, “champions”, “og”, “exclusive”,
“limited”, “divine”, “slime god”, “secret”}) do if name:find(n) then
return true end end return false end

local function luckyBlockToolMatchesType(tool, filterType, playerData,
inventoryByUID) if not tool or not tool:IsA(“Tool”) or not
isLuckyBlock(tool) then return false end

    filterType = tostring(filterType or "All")

    if filterType == "All" then
        return true
    end

    local uid = tool:GetAttribute("slimeUID")
    local inventoryEntry =
        uid ~= nil
        and inventoryByUID
        and inventoryByUID[tostring(uid)]
        or nil

    local def = resolveSlimeDefinition(inventoryEntry)
    local allowed = LUCKY_BLOCK_MODEL_NAMES[filterType]

    if allowed then
        local names = {
            tostring(tool.Name or ""),
            tostring((def and def.Name) or ""),
        }

        for _, candidateName in ipairs(names) do
            if allowed[candidateName] == true then
                return true
            end
        end
    end

    local rarity =
        tool:GetAttribute("Rarity")
        or tool:GetAttribute("rarity")
        or (def and (def.Rarity or def.rarity))
        or (inventoryEntry and (inventoryEntry.Rarity or inventoryEntry.rarity))

    if rarity then
        local r = tostring(rarity)

        if filterType == "Soccer God" and r == "Slime God" then
            return true
        end

        if filterType == "Limited" and r == "LIMITED" then
            return true
        end

        if string.lower(r) == string.lower(filterType) then
            return true
        end
    end

    return false

end

local function getSelectedLuckyBlockTools() local list, seen = {}, {}
local playerData = getData() local inventoryByUID = {}

    if playerData and type(playerData.Inventory) == "table" then
        for _, entry in ipairs(playerData.Inventory) do
            if type(entry) == "table" and entry.uid ~= nil then
                inventoryByUID[tostring(entry.uid)] = entry
            end
        end
    end

    local function scan(bag)
        if not bag then
            return
        end

        for _, item in ipairs(bag:GetChildren()) do
            if item:IsA("Tool") then
                local uid = item:GetAttribute("slimeUID")
                local key = uid ~= nil and tostring(uid) or nil

                if key
                    and not seen[key]
                    and luckyBlockToolMatchesType(
                        item,
                        selectedLuckyBlockType,
                        playerData,
                        inventoryByUID
                    )
                then
                    seen[key] = true
                    table.insert(list, {
                        tool = item,
                        uid = uid,
                    })
                end
            end
        end
    end

    scan(LocalPlayer:FindFirstChild("Backpack"))
    scan(LocalPlayer.Character)

    return list

end

local function equipTool(tool) local hum = getHumanoid() local char =
LocalPlayer.Character if not hum or not char or not tool then return
false end if tool.Parent == char then return true end pcall(function()
hum:UnequipTools() end) task.wait(0.05) pcall(function()
hum:EquipTool(tool) end) if tool.Parent ~= char then pcall(function()
tool.Parent = char end) end task.wait(DELAY_EQUIP) return tool.Parent ==
char end

local function findCloakTool() local function scan(bag) if not bag then
return nil end for _, item in ipairs(bag:GetChildren()) do if
item:IsA(“Tool”) then local n = string.lower(item.Name) if
n:find(“invisibility”) or n:find(“cloak”) or n:find(“invis”) then return
item end end end end return scan(LocalPlayer.Character) or
scan(LocalPlayer:FindFirstChild(“Backpack”)) end

local function setLocalInvisible(on) local char = LocalPlayer.Character
if not char then return end for _, part in ipairs(char:GetDescendants())
do if part:IsA(“BasePart”) and part.Name ~= “HumanoidRootPart” then if
on then if part:GetAttribute(“_OrigTrans”) == nil then
part:SetAttribute(“_OrigTrans”, part.Transparency) end part.Transparency
= 1 else local orig = part:GetAttribute(“_OrigTrans”) if orig ~= nil
then part.Transparency = orig part:SetAttribute(“_OrigTrans”, nil) end
end elseif part:IsA(“Decal”) or part:IsA(“Texture”) then if on then if
part:GetAttribute(“_OrigTrans”) == nil then
part:SetAttribute(“_OrigTrans”, part.Transparency) end part.Transparency
= 1 else local orig = part:GetAttribute(“_OrigTrans”) if orig ~= nil
then part.Transparency = orig part:SetAttribute(“_OrigTrans”, nil) end
end end end end

local function activateCloak() local tool = findCloakTool() if not tool
then return false end local hum = getHumanoid() local char =
LocalPlayer.Character if not hum or not char then return false end if
tool.Parent ~= char then pcall(function() hum:UnequipTools() end)
task.wait(0.05) pcall(function() hum:EquipTool(tool) end) if tool.Parent
~= char then pcall(function() tool.Parent = char end) end
task.wait(0.15) end local canAct = tool:FindFirstChild(“CanActivate”) if
canAct and canAct:IsA(“BoolValue”) then canAct.Value = true end
pcall(function() tool:Activate() end) setLocalInvisible(true) return
true end

local function deactivateCloak() setLocalInvisible(false) local hum =
getHumanoid() if hum then pcall(function() hum:UnequipTools() end) end
end

local function getUpgradeCost(sellPrice, level) if _Lib and _Lib.Shared
and typeof(_Lib.Shared.getUpgradePrice) == “function” then local ok,
cost = pcall(_Lib.Shared.getUpgradePrice, sellPrice, level) if ok and
type(cost) == “number” and cost == cost and cost > 0 then return
math.round(cost) end end if type(sellPrice) ~= “number” or type(level)
~= “number” then return math.huge end local cost = sellPrice * 2 * (1.3
^ (level - 1)) if cost ~= cost then return math.huge end return
math.round(cost) end

local function getJumpUpgradePrice(currentJump) if type(currentJump) ~=
“number” then return math.huge end return math.round(260 * (1.082 ^
currentJump) * 2.18 * 10) end

local function getSlimeDef(slimeId) if not slimeId or not _Lib or not
_Lib.Database or not _Lib.Database.Slimes then return nil end local db =
_Lib.Database.Slimes return db[slimeId] or db[tostring(slimeId)] or
db[tonumber(slimeId)] end

local function readRarityFromBillboard(model) if not model then return
nil end for _, d in ipairs(model:GetDescendants()) do if
d:IsA(“TextLabel”) and d.Name == “Rarity” then local t = d.Text if t and
t ~= “” then if t == “Player God” then t = “Slime God” end return t end
end end end

local function upgradeMutationMatches( selected, mutation,
hasEventMutation, eventMutationNames ) selected = tostring(selected or
“All”) local selectedLower = string.lower(selected)

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

local function normalizeUpgradeRarity(rarity) rarity = tostring(rarity
or ““) if rarity ==”Player God” then return “Slime God” end return
rarity end

local function readEventMutationNamesFromEntry(entry) local names = {}
local hasEventMutation = false

    local function add(value)
        if value == nil then return end
        local text = tostring(value)
        local lower = string.lower(text)

        if text ~= ""
            and lower ~= "none"
            and text ~= "{}"
        then
            names[lower] = true
            hasEventMutation = true
        end
    end

    local eventMutations =
        type(entry) == "table"
        and (entry.event_mutations or entry.EventMutations)
        or nil

    if type(eventMutations) == "table" then
        for k, v in pairs(eventMutations) do
            if type(k) == "string" and v == true then
                add(k)
            elseif type(v) == "string" then
                add(v)
            elseif type(k) == "string" then
                add(k)
            end
        end
    elseif eventMutations ~= nil then
        add(eventMutations)
    end

    return hasEventMutation, names

end

local function getUpgradeButtonForStand(stand) if not stand then return
nil end

    local upgrade = stand:FindFirstChild("Upgrade")
    if not upgrade then return nil end

    local surface = upgrade:FindFirstChild("SurfaceGui")
    local frame = surface and surface:FindFirstChild("Frame")
    local button = frame and frame:FindFirstChild("Button")

    if button and button:IsA("GuiButton") then
        return button
    end

    return nil

end

local function parseUpgradePriceText(text) text = tostring(text or ““)
text = text:gsub(”%$“,”“):gsub(”,“,”“):gsub(”%s+“,”“)

    if text == "" then return nil end

    local num, suffix = text:match("^([%d%.]+)([%a]+)$")
    if not num then
        return tonumber(text)
    end

    num = tonumber(num)
    if not num then return nil end

    local multipliers = {
        K = 1e3,
        M = 1e6,
        B = 1e9,
        T = 1e12,
        Qa = 1e15,
        Qi = 1e18,
        Sx = 1e21,
        Sp = 1e24,
        Oc = 1e27,
        No = 1e30,
        Dc = 1e33,
    }

    local multi = multipliers[suffix]
    if not multi then return nil end
    return num * multi

end

local function getUpgradeGuiPrice(stand) local button =
getUpgradeButtonForStand(stand) if not button then return nil end

    local price = button:FindFirstChild("Price")
    if price and price:IsA("TextLabel") then
        return parseUpgradePriceText(price.Text)
    end

    for _, d in ipairs(button:GetDescendants()) do
        if d:IsA("TextLabel") and string.lower(d.Name) == "price" then
            local parsed = parseUpgradePriceText(d.Text)
            if parsed then return parsed end
        end
    end

    return nil

end

local function getLiveUpgradeLevel(slotName, stand, suppliedData) local
data = suppliedData or getData() local plotSlimes = data and
data.PlotSlimes local entry = nil

    if type(plotSlimes) == "table" then
        entry =
            plotSlimes[slotName]
            or plotSlimes[tostring(slotName)]
            or plotSlimes[tonumber(slotName)]
    end

    local level =
        (type(entry) == "table" and (tonumber(entry.level) or tonumber(entry.Level)))
        or (stand and tonumber(stand:GetAttribute("level")))
        or (stand and tonumber(stand:GetAttribute("Level")))
        or 1

    return level, entry

end

local function getUpgradeInfoRobust(slotName, stand, suppliedData) local
data = suppliedData or getData() local plotSlimes = (data and
data.PlotSlimes) or {} local liveFolder = getPlayerSlimesFolder() local
level, entry = getLiveUpgradeLevel(slotName, stand, data)

    local liveMaxLevel = MAX_LEVEL
    if _Lib and _Lib.Shared and tonumber(_Lib.Shared.MAX_SLIME_LEVEL) then
        liveMaxLevel = tonumber(_Lib.Shared.MAX_SLIME_LEVEL)
    end

    if level >= liveMaxLevel then
        return nil, "max"
    end

    local rarity, mutation, hasEventMutation, eventMutationNames =
        getSlotRarityAndMutation(
            tostring(slotName),
            stand,
            plotSlimes,
            liveFolder
        )

    if not rarity or tostring(rarity) == "" then
        return nil, "rarity"
    end

    local slimeId = nil
    if type(entry) == "table" then
        slimeId =
            entry.id
            or entry.Id
            or entry.slimeId
            or entry.slimeID
    end

    local model = liveFolder and liveFolder:FindFirstChild(tostring(slotName))
    if not slimeId and model then
        slimeId =
            model:GetAttribute("slimeID")
            or model:GetAttribute("slimeId")
            or model:GetAttribute("id")
            or model:GetAttribute("SlimeId")
    end

    local def = getSlimeDef(slimeId)

    -- Lucky Blocks do not have the normal Upgrade control.
    if def and tostring(def.Type or "Normal") == "Lucky Block" then
        return nil, "lucky"
    end

    if type(entry) == "table" then
        local entryType = string.lower(tostring(entry.Type or entry.type or ""))
        if entryType:find("lucky", 1, true) then
            return nil, "lucky"
        end
    end

    local sellPrice = nil

    if def then
        sellPrice = tonumber(def.SellPrice)
        if not sellPrice and tonumber(def.MoneyPerSecond) then
            sellPrice = math.round(tonumber(def.MoneyPerSecond) * 4)
        end
    end

    if not sellPrice and type(entry) == "table" then
        sellPrice =
            tonumber(entry.SellPrice)
            or tonumber(entry.sellPrice)
            or tonumber(entry.production_sell_price)

        if not sellPrice then
            local mps =
                tonumber(entry.MoneyPerSecond)
                or tonumber(entry.money_per_second)
                or tonumber(entry.production_mps)
                or tonumber(entry.mps)

            if mps then
                sellPrice = math.round(mps * 4)
            end
        end
    end

    if not sellPrice and model then
        sellPrice =
            tonumber(model:GetAttribute("SellPrice"))
            or tonumber(model:GetAttribute("sellPrice"))

        if not sellPrice then
            local mps =
                tonumber(model:GetAttribute("MoneyPerSecond"))
                or tonumber(model:GetAttribute("money_per_second"))

            if mps then
                sellPrice = math.round(mps * 4)
            end
        end
    end

    local cost = nil
    if sellPrice and sellPrice > 0 then
        cost = getUpgradeCost(sellPrice, level)
    end

    -- If _G._Lib/database access is unavailable, the game's own Upgrade GUI
    -- still exposes its current calculated price. Use that as a fallback.
    if not cost or cost == math.huge then
        cost = getUpgradeGuiPrice(stand)
    end

    -- Auto Upgrade priority metadata.  Reuse the exact CURRENT cash/s
    -- calculation already trusted by Place Slimes (CURRENT CASH first).
    local currentCashPerSecond = 0
    local mutationMultiplier = 1

    if type(entry) == "table" then
        currentCashPerSecond = calculateOwnedSlimeEarnings(entry, def, data)

        if _Lib
            and _Lib.Shared
            and typeof(_Lib.Shared.getMutationMulti) == "function"
        then
            local okMutation, resultMutation = pcall(function()
                return _Lib.Shared.getMutationMulti(
                    entry.mutation or entry.Mutation or mutation or "None",
                    entry.event_mutations or entry.EventMutations or {}
                )
            end)

            if okMutation and tonumber(resultMutation) then
                mutationMultiplier = tonumber(resultMutation)
            end
        end
    elseif def then
        -- Rare fallback when PlotSlimes data is temporarily incomplete.
        local syntheticEntry = {
            level = level,
            mutation = mutation or "None",
            event_mutations = {},
        }
        currentCashPerSecond = calculateOwnedSlimeEarnings(syntheticEntry, def, data)

        if _Lib
            and _Lib.Shared
            and typeof(_Lib.Shared.getMutationMulti) == "function"
        then
            local okMutation, resultMutation = pcall(function()
                return _Lib.Shared.getMutationMulti(mutation or "None", {})
            end)

            if okMutation and tonumber(resultMutation) then
                mutationMultiplier = tonumber(resultMutation)
            end
        end
    end

    return {
        stand = stand,
        id = tostring(slotName),
        level = level,
        cost = tonumber(cost),
        costKnown = tonumber(cost) ~= nil,
        rarity = rarity,
        slimeId = slimeId,
        mutation = mutation,
        hasEventMutation = hasEventMutation,
        eventMutationNames = eventMutationNames,
        def = def,
        currentCashPerSecond = tonumber(currentCashPerSecond) or 0,
        mutationMultiplier = tonumber(mutationMultiplier) or 1,
    }

end

local function candidateMatchesUpgradeFilters(info) if not info then
return false end

    if selectedUpgradeRarity ~= "All" then
        local candidateRarity =
            string.lower(normalizeUpgradeRarity(info.rarity))
        local wantedRarity =
            string.lower(normalizeUpgradeRarity(selectedUpgradeRarity))

        if candidateRarity ~= wantedRarity then
            return false
        end
    end

    return upgradeMutationMatches(
        selectedUpgradeMutation,
        info.mutation,
        info.hasEventMutation,
        info.eventMutationNames
    )

end

getPrioritizedUpgrades = function() – Scan the player’s actual stands,
just like the working Pick-by-Rarity path. – Do NOT require _G._Lib /
Database.Slimes in order to keep a candidate. local data = getData()
local plotSlimes = (data and data.PlotSlimes) or {} local plot =
getMyPlot() local liveFolder = getPlayerSlimesFolder() local stands =
plot and plot:FindFirstChild(“Stands”) local list = {} local stats = {
stands = 0, occupied = 0, readable = 0, matched = 0, maxed = 0, }

    if not stands then
        return list, stats
    end

    for _, stand in ipairs(stands:GetChildren()) do
        if stand:IsA("Model") then
            stats.stands += 1
            local slotName = tostring(stand.Name)

            if isOccupied(slotName, plotSlimes, liveFolder, stand) then
                stats.occupied += 1

                local info, reason = getUpgradeInfoRobust(slotName, stand, data)
                if info then
                    stats.readable += 1
                    if candidateMatchesUpgradeFilters(info) then
                        stats.matched += 1
                        table.insert(list, info)
                    end
                elseif reason == "max" then
                    stats.maxed += 1
                end
            end
        end
    end

    table.sort(list, function(a, b)
        local aCost = tonumber(a.cost)
        local bCost = tonumber(b.cost)

        -- Special priority only when Mutation dropdown = All:
        --   1) Higher CURRENT cash/s first
        --   2) Stronger effective mutation multiplier first
        --   3) Lower next-upgrade cost first
        -- This keeps a high mutation ahead only when it is actually producing
        -- more cash than weaker mutations, exactly as requested.
        if tostring(selectedUpgradeMutation) == "All" then
            local aCash = tonumber(a.currentCashPerSecond) or 0
            local bCash = tonumber(b.currentCashPerSecond) or 0

            if aCash ~= bCash then
                return aCash > bCash
            end

            local aMutationMulti = tonumber(a.mutationMultiplier) or 1
            local bMutationMulti = tonumber(b.mutationMultiplier) or 1

            if aMutationMulti ~= bMutationMulti then
                return aMutationMulti > bMutationMulti
            end
        end

        -- For a specifically selected mutation, preserve the old cheapest-first
        -- behavior.  For Mutation=All this is the third tie-breaker above.
        if aCost and bCost and aCost ~= bCost then
            return aCost < bCost
        elseif aCost and not bCost then
            return true
        elseif bCost and not aCost then
            return false
        end

        local aLevel = tonumber(a.level) or 1
        local bLevel = tonumber(b.level) or 1
        if aLevel ~= bLevel then
            return aLevel < bLevel
        end

        return (tonumber(a.id) or math.huge) < (tonumber(b.id) or math.huge)
    end)

    return list, stats

end

local function waitForUpgradeLevelIncrease(info, beforeLevel, timeout)
local deadline = os.clock() + (timeout or 0.9)

    while os.clock() < deadline do
        task.wait(0.08)
        local current = getLiveUpgradeLevel(info.id, info.stand)
        if tonumber(current) and tonumber(current) > tonumber(beforeLevel or 0) then
            return true, current
        end
    end

    return false, getLiveUpgradeLevel(info.id, info.stand)

end

local function fireUpgradeThroughRealButton(info) local button = info
and getUpgradeButtonForStand(info.stand) if not button then return
false, “no Upgrade GUI button” end

    if typeof(firesignal) == "function" then
        local ok, err = pcall(function()
            firesignal(button.Activated)
        end)
        return ok, err
    end

    if typeof(getconnections) == "function" then
        local ok, err = pcall(function()
            local connections = getconnections(button.Activated)
            for _, connection in ipairs(connections) do
                if connection and typeof(connection.Fire) == "function" then
                    connection:Fire()
                elseif connection and typeof(connection.Function) == "function" then
                    connection.Function()
                end
            end
        end)
        return ok, err
    end

    return false, "firesignal/getconnections unavailable"

end

local function performUpgradeCandidate(info) if not info then return
false, “missing candidate” end

    local beforeLevel = getLiveUpgradeLevel(info.id, info.stand)

    -- First route: exact Upgrade Slime RemoteEvent used by the game.
    local fired, fireErr = FireUpgradeSlot(info.id)
    if fired then
        local increased, newLevel =
            waitForUpgradeLevelIncrease(info, beforeLevel, 0.85)

        if increased then
            return true, "remote", newLevel
        end
    end

    -- Fallback: execute the game's own on-stand Upgrade button callback.
    -- That callback performs the same cash check and v8:Fire(slotName) call.
    local uiFired, uiErr = fireUpgradeThroughRealButton(info)
    if uiFired then
        local increased, newLevel =
            waitForUpgradeLevelIncrease(info, beforeLevel, 0.95)

        if increased then
            return true, "stand-button", newLevel
        end
    end

    return false,
        tostring(fireErr or "remote sent but level unchanged")
        .. " | UI: "
        .. tostring(uiErr or "level unchanged")

end

local function getAllCollectPads() local pads, seen = {}, {} local
function add(pad) if pad and pad:IsA(“Model”) and not seen[pad] then
seen[pad] = true table.insert(pads, pad) end end for _, obj in
ipairs(workspace:GetDescendants()) do if obj:IsA(“Model”) and
obj:FindFirstChild(“Top”) then local padGui =
obj.Top:FindFirstChild(“PadGui”) if padGui and (not
ONLY_WHEN_PADGUI_ENABLED or padGui.Enabled) then add(obj) end end end
return pads end

local function getRoot() local c = LocalPlayer.Character return c and
c:FindFirstChild(“HumanoidRootPart”) end

local function getRarityValue(name, model) name = tostring(name or ““)
for rarity, value in pairs(RARITY_VALUE) do if
string.find(string.lower(name), string.lower(rarity), 1, true) then
return value, rarity end end if model then local attr =
model:GetAttribute(”Rarity”) or model:GetAttribute(“rarity”) or
model:GetAttribute(“Type”) if attr then attr = tostring(attr) for
rarity, value in pairs(RARITY_VALUE) do if
string.find(string.lower(attr), string.lower(rarity), 1, true) then
return value, rarity end end end end return 1, “Unknown” end

local function teleportToBase() local root = getRoot() if not root then
return false end if _G.MyPlot and _G.MyPlot.Base and
_G.MyPlot.Base.Teleport and _G.MyPlot.Base.Teleport.WorldCFrame then
root.CFrame = _G.MyPlot.Base.Teleport.WorldCFrame + Vector3.new(0, 3, 0)
root.AssemblyLinearVelocity = Vector3.zero return true end local plot =
getMyPlot() if plot then local base = plot:FindFirstChild(“Base”) if
base then local tp = base:FindFirstChild(“Teleport”) if tp and
tp:IsA(“Attachment”) and tp.WorldCFrame then root.CFrame =
tp.WorldCFrame + Vector3.new(0, 3, 0) root.AssemblyLinearVelocity =
Vector3.zero return true end end end return false end

local function getTargetLuckyBlock() local live =
workspace:FindFirstChild(“Live”) if not live then return nil end

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

local function attemptSteal(prompt) if not prompt then return false end
local hold = prompt.HoldDuration or 0 if typeof(fireproximityprompt) ==
“function” then local ok = pcall(function() fireproximityprompt(prompt)
end) if ok then task.wait(hold + 0.5) return true end end local ok =
pcall(function() prompt:Trigger() end) if ok then task.wait(hold + 0.5)
return true end return false end

– BURST place selected Lucky Block type (no open) local function
doPlaceBoxesOnly() if not PlaceRemote then return 0 end local boxes =
getSelectedLuckyBlockTools() local slots = getAvailableSlots() if #boxes
== 0 or #slots == 0 then return 0 end local total = math.min(#boxes,
#slots) local placed = 0 for i = 1, total do local entry, slot =
boxes[i], slots[i] if entry and entry.uid and slot then if
pcall(function() PlaceRemote:FireServer(slot.name, entry.uid) end) then
placed += 1 end end end return placed end

– BURST OPEN ALL ACTIVE LUCKY BLOCKS IN SLIME SLOTS – IMPORTANT: do not
filter by rarity/type/name here. – The real game opens a Lucky Block by
slot name only: – Open Lucky Block(slotName) – So we fire the open
request at EVERY currently occupied slime slot. – Normal players are
rejected/ignored by the server; any active Lucky Block – (Icons, Spain,
Divine/event/new tiers, etc.) is opened automatically. local function
doOpenBoxesOnly() – Resolve lazily on every click in case startup
caching was late. local remote = OpenRemote

    if not (remote and remote.Parent and remote:IsA("RemoteEvent")) then
        remote = ResolveRemoteEventExact("Open Lucky Block")
        OpenRemote = remote
    end

    if not remote then
        warn('[OpenBoxes] RemoteEvent "Open Lucky Block" not found')
        return 0
    end

    -- This is intentionally ALL occupied slime stands, not a Lucky Block filter.
    local occupiedSlots = getAllOccupiedSlots()
    if #occupiedSlots == 0 then
        return 0
    end

    local fired = 0

    -- Burst every occupied slot with no artificial per-slot delay.
    for _, slot in ipairs(occupiedSlots) do
        local slotName = tostring(slot.name)

        local ok, err = pcall(function()
            remote:FireServer(slotName)
        end)

        if ok then
            fired += 1
        else
            warn("[OpenBoxes] Fire failed for slot", slotName, err)
        end
    end

    return fired

end

– BURST place selected Lucky Block type, then open ALL active boxes on
the plot. local function doPlaceAndOpenBoxes() local placeRemote =
ResolvePlaceRemote() if not placeRemote then return 0, 0 end

    local boxes = getSelectedLuckyBlockTools()
    local slots = getAvailableSlots()
    if #boxes == 0 or #slots == 0 then
        -- Even if there is nothing new to place, still open boxes already active.
        return 0, doOpenBoxesOnly()
    end

    local total = math.min(#boxes, #slots)
    local placed = 0

    -- Keep the already-working placement logic unchanged.
    for i = 1, total do
        local entry, slot = boxes[i], slots[i]
        if entry and entry.uid and slot then
            if pcall(function()
                placeRemote:FireServer(slot.name, entry.uid)
            end) then
                placed += 1
            end
        end
    end

    -- Give newly placed blocks a moment to become active PlotSlimes/stands.
    task.wait(0.35)

    -- Open EVERY active box currently occupying a slime slot, regardless of type.
    local openedRequests = doOpenBoxesOnly()
    return placed, openedRequests

end

– ============================================ – GIFT ALL SIDE-PANEL
CONTROL – ============================================
GiftAllBtn.MouseButton1Click:Connect(function() if giftAllEnabled then
setGiftAllState(false) return end

    local target, err = resolveGiftTarget(GiftNameBox.Text)
    if not target then
        GiftStatus.Text = tostring(err)
        return
    end

    GiftNameBox.Text = target.Name
    setGiftAllState(true, target)

end)

AutoAcceptGiftBtn.MouseButton1Click:Connect(function()
setAutoAcceptGiftsState(not autoAcceptGiftsEnabled) end)

– ============================================ – MANUAL BUTTONS –
============================================
PickLowestProfitBtn.MouseButton1Click:Connect(function() if actionBusy
then LowestProfitStatus.Text = “Another action is running…” return end

    if not PickupRemote then
        LowestProfitStatus.Text = 'Pickup error: "Pickup Slime" remote missing'
        return
    end

    local requested = math.floor(tonumber(LowestProfitCountBox.Text) or 0)

    if requested < 1 then
        LowestProfitStatus.Text = "Enter a valid count (1 or more)."
        return
    end

    LowestProfitCountBox.Text = tostring(requested)
    actionBusy = true
    PickLowestProfitBtn.Text = "Picking..."
    LowestProfitStatus.Text = "Calculating current cash/s..."

    local ok, err = xpcall(function()
        local lowest, totalPlaced = getLowestProfitPlacedSlots(requested)

        if #lowest == 0 then
            LowestProfitStatus.Text = "No placed normal players found."
            return
        end

        print("====================================================")
        print("[PickLowestProfit] LOWEST CURRENT CASH/s FIRST")
        print("Requested:", requested, "Eligible placed:", totalPlaced)
        print("====================================================")

        for i, entry in ipairs(lowest) do
            print(string.format(
                "#%d Slot %s | %s | Cash/s=%.2f | Lv=%d | Mutation=%s",
                i,
                tostring(entry.name),
                tostring(entry.displayName),
                tonumber(entry.value) or 0,
                tonumber(entry.level) or 1,
                tostring(entry.mutation or "None")
            ))
        end

        local picked = 0

        for i, entry in ipairs(lowest) do
            local fired, fireErr = pcall(function()
                PickupRemote:FireServer(entry.name)
            end)

            if fired then
                picked += 1
                LowestProfitStatus.Text = string.format(
                    "Picking %d/%d | %.2f cash/s",
                    picked,
                    #lowest,
                    tonumber(entry.value) or 0
                )
            else
                warn(
                    "[PickLowestProfit] Pickup failed slot",
                    tostring(entry.name),
                    fireErr
                )
            end

            task.wait(DELAY_PICK)
        end

        LowestProfitStatus.Text = string.format(
            "Picked %d lowest-profit player%s%s",
            picked,
            picked == 1 and "" or "s",
            totalPlaced < requested
                and string.format(" (only %d available)", totalPlaced)
                or ""
        )

        StatusLabel.Text = string.format(
            "Picked %d lowest current cash/s players",
            picked
        )
    end, debug.traceback)

    if not ok then
        warn("[PickLowestProfit] ERROR:", err)
        LowestProfitStatus.Text =
            "Lowest-profit error: "
            .. tostring(err):match("^[^\n]+")
    end

    PickLowestProfitBtn.Text = "Pick Lowest Profit"
    actionBusy = false

end)

PickupBtn.MouseButton1Click:Connect(function() if actionBusy or not
PickupRemote then return end

    actionBusy = true
    PickupRangeDropList.Visible = false
    PickupBtn.Text = "Picking..."

    local rangeInfo = selectedPickupRange
    local slots = getOccupiedSlotsInRange(
        rangeInfo.first,
        rangeInfo.last
    )

    local n = 0
    for _, slot in ipairs(slots) do
        if pcall(function()
            PickupRemote:FireServer(slot.name)
        end) then
            n += 1
        end
        task.wait(DELAY_PICK)
    end

    StatusLabel.Text = string.format(
        "Picked %d from slots %s",
        n,
        rangeInfo.label
    )

    PickupBtn.Text = "Pick Up"
    actionBusy = false

end)

PickupAllBtn.MouseButton1Click:Connect(function() if actionBusy or not
PickupRemote then return end actionBusy = true PickupAllBtn.Text =
“Picking ALL…” local slots = getAllOccupiedSlots() local n = 0 for _,
slot in ipairs(slots) do if pcall(function()
PickupRemote:FireServer(slot.name) end) then n += 1 end
task.wait(DELAY_PICK) end StatusLabel.Text = string.format(“Picked %d
from ALL floors”, n) PickupAllBtn.Text = “Pick Up ALL Floors” actionBusy
= false end)

ManualFilters.pickButton.MouseButton1Click:Connect(function() if
actionBusy or not PickupRemote then return end

    actionBusy = true
    ManualFilters.pickRarityList.Visible = false
    ManualFilters.pickMutationList.Visible = false
    ManualFilters.pickButton.Text = "Picking..."

    local rarityFilter = ManualFilters.pickRarity
    local mutationFilter = ManualFilters.pickMutation
    local slots = getOccupiedSlotsByDualFilter(
        rarityFilter,
        mutationFilter
    )

    if #slots == 0 then
        StatusLabel.Text = string.format(
            "No placed players match R:%s + M:%s",
            tostring(rarityFilter),
            tostring(mutationFilter)
        )
        ManualFilters.pickButton.Text = "Pick Matching Players"
        actionBusy = false
        return
    end

    local n = 0
    for _, slot in ipairs(slots) do
        if pcall(function()
            PickupRemote:FireServer(slot.name)
        end) then
            n += 1
        end
        task.wait(DELAY_PICK)
    end

    StatusLabel.Text = string.format(
        "Picked %d | R:%s + M:%s",
        n,
        tostring(rarityFilter),
        tostring(mutationFilter)
    )

    ManualFilters.pickButton.Text = "Pick Matching Players"
    actionBusy = false

end)

ManualFilters.placeButton.MouseButton1Click:Connect(function() if
actionBusy then StatusLabel.Text = “Another action is still running…”
return end

    local remote = ResolvePlaceRemote()

    if not remote then
        StatusLabel.Text = 'Place error: RemoteEvent "Place Slime" not found'
        return
    end

    actionBusy = true
    ManualFilters.placeRarityList.Visible = false
    ManualFilters.placeMutationList.Visible = false
    ManualFilters.placeButton.Text = "Placing..."

    local ok, err = xpcall(function()
        local rarityFilter = ManualFilters.placeRarity
        local mutationFilter = ManualFilters.placeMutation

        -- Only CURRENTLY HELD normal slime tools matching BOTH filters.
        -- Lucky Boxes are already excluded by getSlimeTools().
        local tools = getHeldSlimeToolsByDualFilter(
            rarityFilter,
            mutationFilter
        )
        local slots = getAvailableSlots()

        if #tools == 0 then
            error(
                string.format(
                    "No held players match R:%s + M:%s",
                    tostring(rarityFilter),
                    tostring(mutationFilter)
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
            "[PlaceDualFilter]",
            "R=" .. tostring(rarityFilter),
            "M=" .. tostring(mutationFilter),
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
                                "Placed %d/%d | R:%s M:%s | %.2f cash/s",
                                placed,
                                total,
                                tostring(rarityFilter),
                                tostring(mutationFilter),
                                tonumber(rankedEntry.value) or 0
                            )
                        else
                            warn(
                                "[PlaceDualFilter] Place failed UID",
                                tostring(rankedEntry.uid),
                                fireErr
                            )
                        end

                        task.wait(DELAY_PLACE)
                    end
                end
            else
                warn(
                    "[PlaceDualFilter] Missing Tool UID",
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
            "Placed %d | R:%s + M:%s",
            placed,
            tostring(rarityFilter),
            tostring(mutationFilter)
        )
    end, debug.traceback)

    if not ok then
        warn("[PlaceDualFilter] ERROR:", err)
        StatusLabel.Text =
            "Filtered place error: "
            .. tostring(err):match("^[^\n]+")
    end

    ManualFilters.placeButton.Text = "Place Matching Players"
    actionBusy = false

end)

PlaceBtn.MouseButton1Click:Connect(function() – Never silently ignore
the click. if actionBusy then StatusLabel.Text = “Another action is
still running…” return end

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

BoxesBtn.MouseButton1Click:Connect(function() if actionBusy then return
end actionBusy = true BoxesBtn.Text = “Burst…” local p, o =
doPlaceAndOpenBoxes() StatusLabel.Text = string.format( “Burst %s —
Placed %d | Opened %d”, selectedLuckyBlockType, p, o ) BoxesBtn.Text =
“Place + Open Selected Boxes (Once)” actionBusy = false end)

PlaceBoxesBtn.MouseButton1Click:Connect(function() if actionBusy then
return end actionBusy = true PlaceBoxesBtn.Text = “…” local p =
doPlaceBoxesOnly() StatusLabel.Text = string.format( “Placed %d %s boxes
(instant)”, p, selectedLuckyBlockType ) PlaceBoxesBtn.Text = “Place
Boxes” actionBusy = false end)

OpenBoxesBtn.MouseButton1Click:Connect(function() if actionBusy then
return end actionBusy = true OpenBoxesBtn.Text = “…” local o =
doOpenBoxesOnly() StatusLabel.Text = string.format( “Open All: fired %d
occupied slime slots”, o ) OpenBoxesBtn.Text = “Open Boxes” actionBusy =
false end)

– ============================================ – LOOPS –
============================================ task.spawn(function() while
true do if collectEnabled and CollectRemote then for _, pad in
ipairs(getAllCollectPads()) do if not collectEnabled then break end
pcall(function() CollectRemote:FireServer(pad.Name) end)
task.wait(COLLECT_INTERVAL) end end task.wait(COLLECT_SCAN) end end)

task.spawn(function() while true do if upgradeEnabled then local ok, err
= xpcall(function() local rarityAtDecision = selectedUpgradeRarity local
mutationAtDecision = selectedUpgradeMutation

                local upgrades, stats = getPrioritizedUpgrades()

                if rarityAtDecision ~= selectedUpgradeRarity
                    or mutationAtDecision ~= selectedUpgradeMutation
                then
                    return
                end

                if #upgrades == 0 then
                    StatusLabel.Text = string.format(
                        "Upgrade ON | %s + %s | matched 0 | occupied %d/read %d/max %d",
                        upgradeRarityDisplayName(rarityAtDecision),
                        upgradeMutationDisplayName(mutationAtDecision),
                        tonumber(stats.occupied) or 0,
                        tonumber(stats.readable) or 0,
                        tonumber(stats.maxed) or 0
                    )
                    task.wait(0.35)
                    return
                end

                -- Build one affordability-aware batch of up to 10 DIFFERENT slots.
                -- Known costs reserve from the current cash budget so we do not
                -- intentionally queue more known-cost upgrades than the player can pay.
                -- Unknown costs are still allowed so the server remains authoritative.
                local cash = getCash()
                local remainingCash = cash
                local batch = {}

                for _, candidate in ipairs(upgrades) do
                    if #batch >= 10 then
                        break
                    end

                    local candidateCost = tonumber(candidate.cost)

                    if not candidateCost or candidateCost <= remainingCash then
                        table.insert(batch, candidate)

                        if candidateCost then
                            remainingCash = math.max(0, remainingCash - candidateCost)
                        end
                    end
                end

                if #batch == 0 then
                    local first = upgrades[1]
                    StatusLabel.Text = string.format(
                        "Upgrade ON | %d match | no affordable batch | first $%s | cash $%s",
                        #upgrades,
                        tostring(first and first.cost and math.floor(first.cost) or "?"),
                        tostring(math.floor(cash))
                    )
                    task.wait(0.35)
                    return
                end

                StatusLabel.Text = string.format(
                    "Batch upgrading %d/10 | %s + %s | %d matching",
                    #batch,
                    upgradeRarityDisplayName(rarityAtDecision),
                    upgradeMutationDisplayName(mutationAtDecision),
                    #upgrades
                )

                print("====================================================")
                print(
                    "[AutoUpgrade] BATCH",
                    #batch,
                    "| Rarity:", rarityAtDecision,
                    "| Mutation:", mutationAtDecision,
                    "| Matches:", #upgrades
                )

                for i, candidate in ipairs(batch) do
                    print(string.format(
                        "#%d Slot %s | Cash/s=%.2f | Mutation=%s | Multi=%.2fx | Cost=%s | Lv=%d",
                        i,
                        tostring(candidate.id),
                        tonumber(candidate.currentCashPerSecond) or 0,
                        tostring(candidate.mutation or "None"),
                        tonumber(candidate.mutationMultiplier) or 1,
                        candidate.cost and tostring(math.floor(candidate.cost)) or "?",
                        tonumber(candidate.level) or 1
                    ))
                end
                print("====================================================")

                -- Fire all 10 candidates concurrently. performUpgradeCandidate()
                -- sends the real Upgrade Slime request immediately, then each task
                -- independently verifies/falls back without serializing the batch.
                local completed = 0
                local succeeded = 0

                for _, candidate in ipairs(batch) do
                    task.spawn(function()
                        local success, routeOrErr = performUpgradeCandidate(candidate)

                        if success then
                            succeeded += 1
                        else
                            warn(
                                "[AutoUpgrade] Batch slot",
                                tostring(candidate.id),
                                "did not level:",
                                tostring(routeOrErr)
                            )
                        end

                        completed += 1
                    end)
                end

                -- Keep the requests concurrent, but allow their normal verification
                -- window to finish before rebuilding the next top-10 batch.
                local batchDeadline = os.clock() + 1.20
                while completed < #batch and os.clock() < batchDeadline do
                    task.wait(0.04)
                end

                StatusLabel.Text = string.format(
                    "Batch fired %d | confirmed %d | %d matching",
                    #batch,
                    succeeded,
                    #upgrades
                )

                task.wait(UPGRADE_DELAY)
            end, debug.traceback)

            if not ok then
                warn("[AutoUpgrade] ERROR:", err)
                StatusLabel.Text =
                    "Auto Upgrade error: "
                    .. tostring(err):match("^[^\\n]+")
                task.wait(0.45)
            end

            task.wait(0.05)
        else
            task.wait(UPGRADE_SCAN)
        end
    end

end)

task.spawn(function() while true do if luckyEnabled and not
luckyBlockBusy then luckyBlockBusy = true

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
                    "No %s boxes | Total: %d",
                    selectedLuckyBlockType,
                    totalCollected
                )
                luckyBlockBusy = false
                task.wait(0.50)
                continue
            end

            -- ===================================================
            -- WORKING LUCKY BLOCK ORDER (kept intact):
            -- 1) FIRE invisibility attempt first
            -- 2) Do NOT require invisibility to succeed/confirm
            -- 3) Teleport to Lucky Block
            -- 4) Pick it up / retry using the original prompt mechanism
            -- 5) Wait until holdingSlime == true
            -- 6) ONLY THEN return to base
            -- ===================================================

            StatusLabel.Text = "Lucky Block: cloak fire (NON-BLOCKING) -> collecting..."

            -- Invisibility is best-effort only. It MUST be attempted, but a
            -- missing cloak / failed activation must never block collection.
            pcall(function()
                activateCloak()
            end)
            task.wait(0.12)

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

            -- Go to the Lucky Block after the best-effort invisibility fire.
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

                -- Do NOT retry/verify invisibility here. Collection must proceed
                -- regardless of cloak state once the initial fire was attempted.

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

– Continuously accept incoming gifts while enabled. The live game keeps
– the current incoming gift UID on the gifting frame and its native
Accept – button uses a 0.5-second cooldown, so this worker follows the
same cadence. task.spawn(function() while true do if
autoAcceptGiftsEnabled then hookGiftRequestListener()

            local uid = pendingGiftUID or getPendingGiftUIDFromGui()

            -- The game may leave the gifting frame populated for a fraction of
            -- a second after a successful accept. Avoid immediately re-sending
            -- the exact same UID while still remaining fully continuous.
            if uid ~= nil
                and lastAcceptedGiftUID ~= nil
                and tostring(uid) == tostring(lastAcceptedGiftUID)
                and (os.clock() - lastAcceptedGiftAt) < 2
            then
                uid = nil
            end

            if uid ~= nil then
                local accepted, message = FireAcceptGift(uid)

                if accepted then
                    pendingGiftUID = nil
                    lastAcceptedGiftUID = uid
                    lastAcceptedGiftAt = os.clock()

                    if not giftAllEnabled then
                        GiftStatus.Text = "Auto Accept: accepted gift UID " .. tostring(uid)
                    end
                elseif type(message) == "string" and message ~= "" then
                    if not giftAllEnabled then
                        GiftStatus.Text = "Auto Accept: " .. message
                    end
                end
            elseif not giftAllEnabled then
                GiftStatus.Text = "Auto Accept ON | waiting for incoming gifts..."
            end
        end

        task.wait(AUTO_ACCEPT_GIFT_INTERVAL)
    end

end)

– Gift worker: highest FINAL current cash/s first. – Gift Count =
maximum number of DISTINCT inventory slimes attempted per run. – Gift
Delay = seconds between each request. The server remains authoritative –
for acceptance, restrictions, and any hidden rate limits.
task.spawn(function() while true do if giftAllEnabled then local target
= giftTargetName and Players:FindFirstChild(giftTargetName)

            if not target or target == LocalPlayer then
                GiftStatus.Text = "Target left the server. Gift All stopped."
                setGiftAllState(false)
                task.wait(0.20)
                continue
            end

            local countBox = GiftPanel:FindFirstChild("GiftCount")
            local delayBox = GiftPanel:FindFirstChild("GiftDelay")
            local requestedCount = math.max(
                1,
                math.floor(tonumber(countBox and countBox.Text) or 10)
            )
            local giftDelay = math.max(
                0,
                tonumber(delayBox and delayBox.Text) or 1.25
            )

            if countBox then
                countBox.Text = tostring(requestedCount)
            end
            if delayBox then
                delayBox.Text = string.format("%.2f", giftDelay)
            end

            local ranked = getGiftableInventoryUIDs()

            if #ranked == 0 then
                GiftStatus.Text = "Inventory empty | Gift All stopped"
                setGiftAllState(false)
                task.wait(0.20)
                continue
            end

            local attempted = 0
            local availableAtStart = #ranked

            for _, gift in ipairs(ranked) do
                if not giftAllEnabled or attempted >= requestedCount then
                    break
                end

                local key = tostring(gift.uid)

                -- Keep each UID unique for this Gift All run. setGiftAllState(false)
                -- clears this table ready for the next run.
                if not giftInFlight[key] then
                    giftInFlight[key] = true
                    attempted += 1

                    GiftStatus.Text = string.format(
                        "%d/%d | %s | %.2f cash/s | %s | %s",
                        attempted,
                        math.min(requestedCount, availableAtStart),
                        tostring(gift.displayName),
                        tonumber(gift.value) or 0,
                        tostring(gift.rarity),
                        tostring(gift.mutation)
                    )

                    print(string.format(
                        "[GiftPriority] #%d UID=%s | %s | Cash/s=%.2f | Lv=%d | Rarity=%s | Mutation=%s",
                        attempted,
                        tostring(gift.uid),
                        tostring(gift.displayName),
                        tonumber(gift.value) or 0,
                        tonumber(gift.level) or 1,
                        tostring(gift.rarity),
                        tostring(gift.mutation)
                    ))

                    local ok, message = FireGiftSlime(target.Name, gift.uid)

                    if type(message) == "string" and message ~= "" then
                        GiftStatus.Text = string.format(
                            "%d/%d | %.2f cash/s | %s",
                            attempted,
                            math.min(requestedCount, availableAtStart),
                            tonumber(gift.value) or 0,
                            message
                        )
                    elseif not ok then
                        GiftStatus.Text = string.format(
                            "%d/%d | request rejected | %.2f cash/s",
                            attempted,
                            math.min(requestedCount, availableAtStart),
                            tonumber(gift.value) or 0
                        )
                    end

                    if giftAllEnabled and attempted < requestedCount then
                        task.wait(giftDelay)
                    end
                end
            end

            local completed = attempted
            local wanted = requestedCount
            setGiftAllState(false)
            GiftStatus.Text = string.format(
                "Gift run complete: %d/%d attempted | highest cash/s first | delay %.2fs",
                completed,
                wanted,
                giftDelay
            )
        end

        task.wait(0.10)
    end

end)

task.spawn(function() while true do if rebirthEnabled and RebirthRemote
then pcall(function() RebirthRemote:FireServer() end) end
task.wait(REBIRTH_INTERVAL) end end)

task.spawn(function() while true do if jumpUpgradeEnabled and
JumpUpgradeRemote then local cash, jump = getCash(), getJumpData() if
getJumpUpgradePrice(jump) <= cash then pcall(function()
JumpUpgradeRemote:FireServer(3) end) end end
task.wait(JUMP_UPGRADE_INTERVAL) end end)

task.spawn(function() while true do if boxesAutoEnabled and not
actionBusy then actionBusy = true local p, o = doPlaceAndOpenBoxes() if
p > 0 or o > 0 then StatusLabel.Text = string.format( “Auto Boxes [%s]:
+%d / +%d”, selectedLuckyBlockType, p, o ) else StatusLabel.Text = “Auto
Boxes: waiting… (still running)” end actionBusy = false end
task.wait(BOXES_AUTO_INTERVAL) end end)

task.spawn(function() while true do if invisEnabled then activateCloak()
end task.wait(INVIS_REFRESH) end end)

LocalPlayer.CharacterAdded:Connect(function() task.wait(1) if
invisEnabled then activateCloak() end end)

function stopAll() setCollectState(false) setUpgradeState(false)
setLuckyState(false) setRebirthState(false) setJumpUpgradeState(false)
setBoxesAutoState(false) setInvisState(false) setGiftAllState(false)
setAutoAcceptGiftsState(false) deactivateCloak() StatusLabel.Text = “All
systems stopped” end

function goToBase() return teleportToBase() end

print(“========================================”) print(“[AutoFarm]
ICONS + upgrade + steal + OPEN ALL boxes + Gift highest-cash priority +
count/delay + Auto Accept + Lowest Profit”) print(“Place Boxes = burst
place only | Open Boxes = burst open only”) print(“Commands: stopAll() |
goToBase()”) print(“========================================”)
