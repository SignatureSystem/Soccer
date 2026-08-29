-- Combined Script: ALTERNATE + JAPAN + ICONS + BATCH-10 Auto Upgrade
-- + FILTERED Lucky Block Collector
-- + UNIVERSAL Place ALL inventory lucky boxes + OPEN ALL slot boxes
-- + 10-slot Pickup Range + CURRENT INDIVIDUAL earnings desc + Invis
-- + Gift All + highest current cash/s + Gift Count/Delay + Auto Accept Gifts
-- + Pick Lowest Profit by count
--
-- Alternate integration:
-- Dropdown label: Alternate
-- Exact lucky block name: Alternate Lucky Block
-- Rarity: Alternative
-- Registry ID: 1263
-- Min value fallback: 700000000
--
-- Place/Place Boxes dynamically target EVERY existing free stand/floor under Plot.Stands.

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
local AUTO_ACCEPT_GIFT_INTERVAL = 0.50
local DELAY_EQUIP = 0.12
local DELAY_PLACE = 0.22
local DELAY_NEXT = 0.12
local DELAY_PICK = 0.12
local IGNORE_LOCK = true

local ALTERNATE_LUCKY_BLOCK_ID = "1263"
local ALTERNATE_LUCKY_BLOCK_NAME = "Alternate Lucky Block"
local ALTERNATE_LUCKY_BLOCK_RARITY = "Alternative"
local ALTERNATE_LUCKY_BLOCK_MIN_VALUE = 700000000

local UPGRADE_PRIORITY = {
    ["Alternative"] = 1, ["Japan"] = 2, ["Icons"] = 3, ["Spain"] = 4
}

local TARGET_RARITIES = {
    ["Alternative"] = true, ["Japan"] = true, ["Icons"] = true, ["Spain"] = true
}

local RARITY_VALUE = {
    ["Alternative"] = 700000000,
    ["Japan"] = 10000000, ["Icons"] = 5000000, ["Spain"] = 2500000,
    ["Champions"] = 1000000, ["OG"] = 500000,
    ["Exclusive"] = 75000, ["LIMITED"] = 75000,
    ["Divine"] = 50000, ["Slime God"] = 30000, ["Secret"] = 10000,
    ["Mythic"] = 2500, ["Legendary"] = 750, ["Epic"] = 250,
    ["Rare"] = 100, ["Common"] = 25,
}

local ALL_RARITIES = {
    "Common","Rare","Epic","Legendary","Mythic","Secret","Slime God","Divine",
    "Exclusive","LIMITED","OG","Champions","Spain","Icons","Japan","Alternative",
}

local ALL_MUTATIONS = {
    "Golden","Diamond","Rainbow","Cursed","Divine","Fallen",
    "Volcanic","Toxic","Taco","Cosmic","Slimey",
}

local UPGRADE_RARITY_OPTIONS = {"All"}
for _,v in ipairs(ALL_RARITIES) do table.insert(UPGRADE_RARITY_OPTIONS,v) end

local UPGRADE_MUTATION_OPTIONS = {"All","Common"}
for _,v in ipairs(ALL_MUTATIONS) do table.insert(UPGRADE_MUTATION_OPTIONS,v) end

local LUCKY_BLOCK_OPTIONS = {
    "All","Common","Water","Rare","Volcanic","Epic","Ghost","Legendary","67",
    "Mythic","Poison","Secret","Cosmic","Soccer God","Rainbow","Exclusive",
    "Limited","OG","Champions","Spain","Icons","Japan","Alternate",
}

local LUCKY_BLOCK_MODEL_NAMES = {
    ["Common"]={["Common Lucky Block"]=true},
    ["Water"]={["Water Lucky Block"]=true},
    ["Rare"]={["Rare Lucky Block"]=true},
    ["Volcanic"]={["Volcanic Lucky Block"]=true},
    ["Epic"]={["Epic Lucky Block"]=true},
    ["Ghost"]={["Ghost Lucky Block"]=true},
    ["Legendary"]={["Legendary Lucky Block"]=true},
    ["67"]={["67 Lucky Block"]=true},
    ["Mythic"]={["Mythic Lucky Block"]=true},
    ["Poison"]={["Poison Lucky Block"]=true},
    ["Secret"]={["Secret Lucky Block"]=true},
    ["Cosmic"]={["Cosmic Lucky Block"]=true},
    ["Soccer God"]={["Slime God Lucky Block"]=true,["Soccer God Lucky Block"]=true},
    ["Rainbow"]={["Rainbow Lucky Block"]=true},
    ["Exclusive"]={["Exclusive Lucky Block"]=true},
    ["Limited"]={["Limited Lucky Block"]=true},
    ["OG"]={["OG Lucky Block"]=true},
    ["Champions"]={["Champions Lucky Block"]=true},
    ["Spain"]={["Spain Lucky Block"]=true},
    ["Icons"]={["Icons Lucky Block"]=true},
    ["Japan"]={["Japan Lucky Block"]=true},
    ["Alternate"]={
        ["Alternate Lucky Block"]=true,
        ["Alternative Lucky Block"]=true,
    },
}

local selectedUpgradeRarity = "All"
local selectedUpgradeMutation = "All"
local selectedLuckyBlockType = "Alternate"

-- ============================================
-- STATE / REMOTES
-- ============================================
local collectEnabled, upgradeEnabled, luckyEnabled = false,false,false
local rebirthEnabled, jumpUpgradeEnabled, boxesAutoEnabled = false,false,false
local invisEnabled = false
local totalCollected = 0
local luckyBlockBusy, actionBusy = false,false

local giftAllEnabled = false
local giftTargetName = nil
local giftInFlight = {}
local autoAcceptGiftsEnabled = false
local pendingGiftUID = nil
local lastAcceptedGiftUID = nil
local lastAcceptedGiftAt = 0

local _Lib = nil
local CollectRemote, UpgradeRemote, RebirthRemote, JumpUpgradeRemote
local PlaceRemote, PickupRemote, OpenRemote
local UpgradeChannel = nil
local GiftChannel, GiftRawRemote = nil,nil
local AcceptGiftChannel, AcceptGiftRawRemote = nil,nil
local GiftRequestChannel, giftRequestConnection = nil,nil

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
ScreenGui.DisplayOrder = 999
ScreenGui.IgnoreGuiInset = true
pcall(function() ScreenGui.Parent = PlayerGui or CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = CoreGui end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0,250,0,794)
MainFrame.Position = UDim2.new(0,20,0.5,-397)
MainFrame.BackgroundColor3 = Color3.fromRGB(25,25,30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner",MainFrame).CornerRadius = UDim.new(0,10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1,0,0,28)
Title.BackgroundTransparency = 1
Title.Text = "Auto Farm Control"
Title.TextColor3 = Color3.new(1,1,1)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local function createButton(name,y,text)
    local b=Instance.new("TextButton")
    b.Name=name;b.Size=UDim2.new(0,220,0,30);b.Position=UDim2.new(0,15,0,y)
    b.BackgroundColor3=Color3.fromRGB(40,40,50);b.BorderSizePixel=0
    b.Text=text;b.TextColor3=Color3.fromRGB(255,90,90);b.TextSize=11
    b.Font=Enum.Font.GothamBold;b.Parent=MainFrame
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
    return b
end

local StatusLabel=Instance.new("TextLabel")
StatusLabel.Size=UDim2.new(0,230,0,44)
StatusLabel.Position=UDim2.new(0,10,0,742)
StatusLabel.BackgroundTransparency=1
StatusLabel.Text="Loading..."
StatusLabel.TextColor3=Color3.fromRGB(200,200,210)
StatusLabel.TextSize=11;StatusLabel.Font=Enum.Font.Gotham
StatusLabel.TextXAlignment=Enum.TextXAlignment.Left
StatusLabel.TextYAlignment=Enum.TextYAlignment.Top
StatusLabel.TextWrapped=true;StatusLabel.Parent=MainFrame

local CollectBtn=createButton("CollectToggle",30,"Auto Collect: OFF")
local UpgradeBtn=createButton("UpgradeToggle",64,"Auto Upgrade: OFF")
local LuckyBtn=createButton("LuckyToggle",132,"Lucky Block: OFF")
local RebirthBtn=createButton("RebirthToggle",200,"Auto Rebirth: OFF")
local JumpBtn=createButton("JumpToggle",234,"Auto +10 Jump: OFF")
local BoxesAutoBtn=createButton("BoxesAutoToggle",268,"Auto Place+Open Boxes: OFF")
local InvisBtn=createButton("InvisToggle",302,"Invis Cloak: OFF")
local PickupAllBtn=createButton("PickupAllBtn",378,"Pick Up ALL Floors")
local PlaceBtn=createButton("PlaceBtn",412,"Place Slimes (CURRENT CASH first)")
local BoxesBtn=createButton("BoxesBtn",446,"Place + Open Selected Boxes (Once)")

local PlaceBoxesBtn=Instance.new("TextButton")
PlaceBoxesBtn.Size=UDim2.new(0,106,0,30);PlaceBoxesBtn.Position=UDim2.new(0,15,0,480)
PlaceBoxesBtn.BackgroundColor3=Color3.fromRGB(40,55,40);PlaceBoxesBtn.BorderSizePixel=0
PlaceBoxesBtn.Text="Place Boxes";PlaceBoxesBtn.TextColor3=Color3.fromRGB(120,255,150)
PlaceBoxesBtn.TextSize=11;PlaceBoxesBtn.Font=Enum.Font.GothamBold;PlaceBoxesBtn.Parent=MainFrame

local OpenBoxesBtn=Instance.new("TextButton")
OpenBoxesBtn.Size=UDim2.new(0,106,0,30);OpenBoxesBtn.Position=UDim2.new(0,129,0,480)
OpenBoxesBtn.BackgroundColor3=Color3.fromRGB(55,45,25);OpenBoxesBtn.BorderSizePixel=0
OpenBoxesBtn.Text="Open Boxes";OpenBoxesBtn.TextColor3=Color3.fromRGB(255,200,100)
OpenBoxesBtn.TextSize=11;OpenBoxesBtn.Font=Enum.Font.GothamBold;OpenBoxesBtn.Parent=MainFrame

-- reusable dropdown
local function makeDropdown(x,y,w,label,options,z,parent,onSelect)
    parent=parent or MainFrame
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(0,w,0,30);btn.Position=UDim2.new(0,x,0,y)
    btn.BackgroundColor3=Color3.fromRGB(35,38,52);btn.BorderSizePixel=0
    btn.Text=label.." ▼ "..tostring(options[1]);btn.TextColor3=Color3.fromRGB(210,220,245)
    btn.TextSize=10;btn.Font=Enum.Font.GothamBold;btn.ZIndex=z;btn.Parent=parent
    local list=Instance.new("ScrollingFrame")
    list.Size=UDim2.new(0,220,0,180);list.Position=UDim2.new(0,15,0,y+32)
    list.BackgroundColor3=Color3.fromRGB(24,27,37);list.BorderSizePixel=0
    list.Visible=false;list.ScrollBarThickness=4
    list.CanvasSize=UDim2.new(0,0,0,#options*26);list.ZIndex=z+10;list.Parent=parent
    Instance.new("UIListLayout",list).SortOrder=Enum.SortOrder.LayoutOrder
    for i,opt in ipairs(options) do
        local item=Instance.new("TextButton")
        item.Size=UDim2.new(1,-4,0,24);item.BackgroundColor3=Color3.fromRGB(36,40,52)
        item.BorderSizePixel=0;item.Text="  "..tostring(opt);item.TextColor3=Color3.fromRGB(230,230,240)
        item.TextSize=11;item.Font=Enum.Font.Gotham;item.TextXAlignment=Enum.TextXAlignment.Left
        item.LayoutOrder=i;item.ZIndex=z+11;item.Parent=list
        item.MouseButton1Click:Connect(function()
            btn.Text=label.." ▼ "..tostring(opt);list.Visible=false;onSelect(opt)
        end)
    end
    btn.MouseButton1Click:Connect(function() list.Visible=not list.Visible end)
    return btn,list
end

local UpgradeRarityDropBtn,UpgradeRarityDropList =
makeDropdown(15,98,106,"Rarity:",UPGRADE_RARITY_OPTIONS,50,MainFrame,function(v)
    selectedUpgradeRarity=v
end)

local UpgradeMutationDropBtn,UpgradeMutationDropList =
makeDropdown(129,98,106,"Mutation:",UPGRADE_MUTATION_OPTIONS,55,MainFrame,function(v)
    selectedUpgradeMutation=v
end)

local LuckyTypeDropBtn,LuckyTypeDropList =
makeDropdown(15,166,220,"Lucky Type:",LUCKY_BLOCK_OPTIONS,70,MainFrame,function(v)
    selectedLuckyBlockType=v
    StatusLabel.Text="Lucky Type selected: "..v
end)
LuckyTypeDropBtn.Text="Lucky Type: ▼ Alternate"

local PICKUP_RANGE_OPTIONS={}
for s=1,100,10 do
    table.insert(PICKUP_RANGE_OPTIONS,{
        label=string.format("%d-%d",s,math.min(s+9,100)),first=s,last=math.min(s+9,100)
    })
end
local selectedPickupRange=PICKUP_RANGE_OPTIONS[1]
local rangeLabels={}
for _,r in ipairs(PICKUP_RANGE_OPTIONS) do table.insert(rangeLabels,r.label) end

local PickupRangeDropBtn,PickupRangeDropList =
makeDropdown(15,344,140,"",rangeLabels,90,MainFrame,function(v)
    for _,r in ipairs(PICKUP_RANGE_OPTIONS) do if r.label==v then selectedPickupRange=r break end end
end)

local PickupBtn=Instance.new("TextButton")
PickupBtn.Size=UDim2.new(0,72,0,30);PickupBtn.Position=UDim2.new(0,163,0,344)
PickupBtn.BackgroundColor3=Color3.fromRGB(45,35,70);PickupBtn.BorderSizePixel=0
PickupBtn.Text="Pick Up";PickupBtn.TextColor3=Color3.fromRGB(205,175,255)
PickupBtn.TextSize=11;PickupBtn.Font=Enum.Font.GothamBold;PickupBtn.Parent=MainFrame

-- manual filters
local ManualFilters={pickRarity="All",pickMutation="All",placeRarity="All",placeMutation="All"}
local rarityOptions={"All"};for _,v in ipairs(ALL_RARITIES) do table.insert(rarityOptions,v) end
local mutationOptions={"All","None"};for _,v in ipairs(ALL_MUTATIONS) do table.insert(mutationOptions,v) end

local _,pickRarityList=makeDropdown(15,536,106,"R:",rarityOptions,120,MainFrame,function(v) ManualFilters.pickRarity=v end)
local _,pickMutationList=makeDropdown(129,536,106,"M:",mutationOptions,125,MainFrame,function(v) ManualFilters.pickMutation=v end)
ManualFilters.pickRarityList=pickRarityList;ManualFilters.pickMutationList=pickMutationList

ManualFilters.pickButton=Instance.new("TextButton")
ManualFilters.pickButton.Size=UDim2.new(0,220,0,28);ManualFilters.pickButton.Position=UDim2.new(0,15,0,570)
ManualFilters.pickButton.BackgroundColor3=Color3.fromRGB(50,40,80);ManualFilters.pickButton.BorderSizePixel=0
ManualFilters.pickButton.Text="Pick Matching Players";ManualFilters.pickButton.TextColor3=Color3.fromRGB(205,180,255)
ManualFilters.pickButton.TextSize=11;ManualFilters.pickButton.Font=Enum.Font.GothamBold;ManualFilters.pickButton.Parent=MainFrame

local _,placeRarityList=makeDropdown(15,624,106,"R:",rarityOptions,130,MainFrame,function(v) ManualFilters.placeRarity=v end)
local _,placeMutationList=makeDropdown(129,624,106,"M:",mutationOptions,135,MainFrame,function(v) ManualFilters.placeMutation=v end)
ManualFilters.placeRarityList=placeRarityList;ManualFilters.placeMutationList=placeMutationList

ManualFilters.placeButton=Instance.new("TextButton")
ManualFilters.placeButton.Size=UDim2.new(0,220,0,28);ManualFilters.placeButton.Position=UDim2.new(0,15,0,658)
ManualFilters.placeButton.BackgroundColor3=Color3.fromRGB(48,38,68);ManualFilters.placeButton.BorderSizePixel=0
ManualFilters.placeButton.Text="Place Matching Players";ManualFilters.placeButton.TextColor3=Color3.fromRGB(220,195,255)
ManualFilters.placeButton.TextSize=11;ManualFilters.placeButton.Font=Enum.Font.GothamBold;ManualFilters.placeButton.Parent=MainFrame

-- Gift panel
local SideArrowBtn=Instance.new("TextButton")
SideArrowBtn.Size=UDim2.new(0,24,0,44);SideArrowBtn.Position=UDim2.new(1,4,0,36)
SideArrowBtn.BackgroundColor3=Color3.fromRGB(35,35,45);SideArrowBtn.BorderSizePixel=0
SideArrowBtn.Text=">";SideArrowBtn.TextColor3=Color3.fromRGB(220,220,235)
SideArrowBtn.TextSize=18;SideArrowBtn.Font=Enum.Font.GothamBold;SideArrowBtn.Parent=MainFrame

local GiftPanel=Instance.new("Frame")
GiftPanel.Size=UDim2.new(0,220,0,326);GiftPanel.Position=UDim2.new(1,32,0,36)
GiftPanel.BackgroundColor3=Color3.fromRGB(24,24,31);GiftPanel.BorderSizePixel=0
GiftPanel.Visible=false;GiftPanel.Parent=MainFrame

local GiftNameBox=Instance.new("TextBox")
GiftNameBox.Size=UDim2.new(1,-20,0,32);GiftNameBox.Position=UDim2.new(0,10,0,36)
GiftNameBox.BackgroundColor3=Color3.fromRGB(37,37,48);GiftNameBox.BorderSizePixel=0
GiftNameBox.PlaceholderText="Player username...";GiftNameBox.Text="";GiftNameBox.ClearTextOnFocus=false
GiftNameBox.TextColor3=Color3.new(1,1,1);GiftNameBox.TextSize=12;GiftNameBox.Font=Enum.Font.Gotham
GiftNameBox.Parent=GiftPanel

local GiftAllBtn=Instance.new("TextButton")
GiftAllBtn.Size=UDim2.new(1,-20,0,32);GiftAllBtn.Position=UDim2.new(0,10,0,75)
GiftAllBtn.BackgroundColor3=Color3.fromRGB(52,38,42);GiftAllBtn.BorderSizePixel=0
GiftAllBtn.Text="Gift All: OFF";GiftAllBtn.TextColor3=Color3.fromRGB(255,105,115)
GiftAllBtn.TextSize=12;GiftAllBtn.Font=Enum.Font.GothamBold;GiftAllBtn.Parent=GiftPanel

local GiftCountBox=Instance.new("TextBox")
GiftCountBox.Size=UDim2.new(0,94,0,30);GiftCountBox.Position=UDim2.new(0,10,0,113)
GiftCountBox.BackgroundColor3=Color3.fromRGB(37,37,48);GiftCountBox.BorderSizePixel=0
GiftCountBox.Text="10";GiftCountBox.TextColor3=Color3.new(1,1,1);GiftCountBox.TextSize=11
GiftCountBox.Font=Enum.Font.GothamBold;GiftCountBox.Parent=GiftPanel

local GiftDelayBox=Instance.new("TextBox")
GiftDelayBox.Size=UDim2.new(0,100,0,30);GiftDelayBox.Position=UDim2.new(0,110,0,113)
GiftDelayBox.BackgroundColor3=Color3.fromRGB(37,37,48);GiftDelayBox.BorderSizePixel=0
GiftDelayBox.Text="1.25";GiftDelayBox.TextColor3=Color3.new(1,1,1);GiftDelayBox.TextSize=11
GiftDelayBox.Font=Enum.Font.GothamBold;GiftDelayBox.Parent=GiftPanel

local GiftStatus=Instance.new("TextLabel")
GiftStatus.Size=UDim2.new(1,-20,0,42);GiftStatus.Position=UDim2.new(0,10,0,149)
GiftStatus.BackgroundTransparency=1;GiftStatus.Text="Enter a player in this server."
GiftStatus.TextColor3=Color3.fromRGB(185,185,200);GiftStatus.TextSize=10;GiftStatus.Font=Enum.Font.Gotham
GiftStatus.TextWrapped=true;GiftStatus.TextXAlignment=Enum.TextXAlignment.Left;GiftStatus.Parent=GiftPanel

local LowestProfitCountBox=Instance.new("TextBox")
LowestProfitCountBox.Size=UDim2.new(0,54,0,30);LowestProfitCountBox.Position=UDim2.new(0,10,0,209)
LowestProfitCountBox.BackgroundColor3=Color3.fromRGB(37,37,48);LowestProfitCountBox.BorderSizePixel=0
LowestProfitCountBox.Text="10";LowestProfitCountBox.TextColor3=Color3.new(1,1,1)
LowestProfitCountBox.TextSize=12;LowestProfitCountBox.Font=Enum.Font.GothamBold;LowestProfitCountBox.Parent=GiftPanel

local PickLowestProfitBtn=Instance.new("TextButton")
PickLowestProfitBtn.Size=UDim2.new(0,140,0,30);PickLowestProfitBtn.Position=UDim2.new(0,70,0,209)
PickLowestProfitBtn.BackgroundColor3=Color3.fromRGB(38,48,62);PickLowestProfitBtn.BorderSizePixel=0
PickLowestProfitBtn.Text="Pick Lowest Profit";PickLowestProfitBtn.TextColor3=Color3.fromRGB(165,210,255)
PickLowestProfitBtn.TextSize=10;PickLowestProfitBtn.Font=Enum.Font.GothamBold;PickLowestProfitBtn.Parent=GiftPanel

local LowestProfitStatus=Instance.new("TextLabel")
LowestProfitStatus.Size=UDim2.new(1,-20,0,30);LowestProfitStatus.Position=UDim2.new(0,10,0,244)
LowestProfitStatus.BackgroundTransparency=1;LowestProfitStatus.Text="Lowest cash/s first."
LowestProfitStatus.TextColor3=Color3.fromRGB(165,165,180);LowestProfitStatus.TextSize=9
LowestProfitStatus.Font=Enum.Font.Gotham;LowestProfitStatus.TextWrapped=true;LowestProfitStatus.Parent=GiftPanel

local AutoAcceptGiftBtn=Instance.new("TextButton")
AutoAcceptGiftBtn.Size=UDim2.new(1,-20,0,30);AutoAcceptGiftBtn.Position=UDim2.new(0,10,0,282)
AutoAcceptGiftBtn.BackgroundColor3=Color3.fromRGB(52,38,42);AutoAcceptGiftBtn.BorderSizePixel=0
AutoAcceptGiftBtn.Text="Auto Accept Gifts: OFF";AutoAcceptGiftBtn.TextColor3=Color3.fromRGB(255,105,115)
AutoAcceptGiftBtn.TextSize=11;AutoAcceptGiftBtn.Font=Enum.Font.GothamBold;AutoAcceptGiftBtn.Parent=GiftPanel

SideArrowBtn.MouseButton1Click:Connect(function()
    GiftPanel.Visible=not GiftPanel.Visible
    SideArrowBtn.Text=GiftPanel.Visible and "<" or ">"
end)


-- ============================================
-- CORE HELPERS
-- ============================================
local function trimText(v)
    v=tostring(v or "")
    return v:match("^%s*(.-)%s*$") or ""
end

local function getHumanoid()
    local c=LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local c=LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getData()
    if _Lib and _Lib.Data then
        local ok,data=pcall(function() return _Lib.Data:Get() end)
        if ok and data then return data end
    end
    local candidate=ReplicatedStorage:FindFirstChild("Data: Get",true)
    if candidate and candidate:IsA("RemoteFunction") then
        local ok,data=pcall(function() return candidate:InvokeServer() end)
        if ok and data then return data end
    end
    return nil
end

local function getCash()
    local data=getData()
    if data and type(data.Cash)=="number" then return data.Cash end
    local ls=LocalPlayer:FindFirstChild("leaderstats")
    local c=ls and (ls:FindFirstChild("Cash") or ls:FindFirstChild("Money"))
    return c and tonumber(c.Value) or 0
end

local function getJumpData()
    local data=getData()
    if data and type(data.Jump)=="number" then return data.Jump end
    local ls=LocalPlayer:FindFirstChild("leaderstats")
    local j=ls and (ls:FindFirstChild("Jumps") or ls:FindFirstChild("Jump"))
    return j and tonumber(j.Value) or 0
end

local function getBaseLevel(data)
    data=data or getData()
    if data and type(data.BaseLevel)=="number" then return data.BaseLevel end
    return LocalPlayer:GetAttribute("BaseLevel") or 0
end

local function getMyPlot()
    if _G.MyPlot and _G.MyPlot.Parent then return _G.MyPlot end
    local plots=workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _,plot in ipairs(plots:GetChildren()) do
        local owner=plot:FindFirstChild("owner")
        if owner and tostring(owner.Value)==LocalPlayer.Name then return plot end
    end
end

local function getPlayerSlimesFolder()
    local live=workspace:FindFirstChild("Live")
    local ps=live and live:FindFirstChild("PlayerSlimes")
    return ps and ps:FindFirstChild(LocalPlayer.Name)
end

local function isUnlocked(slotName,baseLevel)
    if IGNORE_LOCK then return true end
    local n=tonumber(slotName)
    if not n then return true end
    return n<=10 or (n-10)<=(baseLevel or 0)
end

local function isOccupied(slotName,plotSlimes,playerSlimesFolder,stand)
    if type(plotSlimes)=="table" then
        if plotSlimes[slotName] or plotSlimes[tostring(slotName)] then return true end
        local n=tonumber(slotName)
        if n and plotSlimes[n] then return true end
    end
    if playerSlimesFolder and playerSlimesFolder:FindFirstChild(tostring(slotName)) then return true end
    if stand then
        local main=stand:FindFirstChild("Main")
        local holder=main and main:FindFirstChild("Holder")
        local pick=holder and holder:FindFirstChild("Pick Up")
        if pick and pick:IsA("ProximityPrompt") and pick.Enabled then return true end
    end
    return false
end

-- Dynamic placement: targets every existing free stand/floor.
local function getAvailableSlots()
    local data=getData()
    local baseLevel=getBaseLevel(data)
    local plotSlimes=(data and data.PlotSlimes) or {}
    local plot=getMyPlot()
    local liveFolder=getPlayerSlimesFolder()
    local free={}
    if not plot then return free end
    local stands=plot:FindFirstChild("Stands")
    if not stands then return free end
    for _,stand in ipairs(stands:GetChildren()) do
        local n=tonumber(stand.Name)
        if n==nil and not stand:FindFirstChild("Main") then continue end
        if isUnlocked(stand.Name,baseLevel)
            and not isOccupied(stand.Name,plotSlimes,liveFolder,stand)
        then
            table.insert(free,{name=stand.Name,num=n or 9999,stand=stand})
        end
    end
    table.sort(free,function(a,b) return a.num<b.num end)
    return free
end

local function getAllOccupiedSlots()
    local data=getData()
    local plotSlimes=(data and data.PlotSlimes) or {}
    local plot=getMyPlot()
    local liveFolder=getPlayerSlimesFolder()
    local list={}
    if not plot then return list end
    local stands=plot:FindFirstChild("Stands")
    if not stands then return list end
    for _,stand in ipairs(stands:GetChildren()) do
        if isOccupied(stand.Name,plotSlimes,liveFolder,stand) then
            table.insert(list,{name=stand.Name,num=tonumber(stand.Name) or 9999,stand=stand})
        end
    end
    table.sort(list,function(a,b) return a.num<b.num end)
    return list
end

local function getOccupiedSlotsInRange(firstSlot,lastSlot)
    local result={}
    for _,s in ipairs(getAllOccupiedSlots()) do
        if s.num>=firstSlot and s.num<=lastSlot then table.insert(result,s) end
    end
    return result
end

local function teleportToBase()
    local root=getRoot()
    if not root then return false end
    if _G.MyPlot and _G.MyPlot.Base and _G.MyPlot.Base.Teleport and _G.MyPlot.Base.Teleport.WorldCFrame then
        root.CFrame=_G.MyPlot.Base.Teleport.WorldCFrame+Vector3.new(0,3,0)
        root.AssemblyLinearVelocity=Vector3.zero
        return true
    end
    local plot=getMyPlot()
    local base=plot and plot:FindFirstChild("Base")
    local tp=base and base:FindFirstChild("Teleport")
    if tp and tp:IsA("Attachment") and tp.WorldCFrame then
        root.CFrame=tp.WorldCFrame+Vector3.new(0,3,0)
        root.AssemblyLinearVelocity=Vector3.zero
        return true
    end
    return false
end

-- ============================================
-- ALTERNATE DETECTION
-- ============================================
local function isAlternateWorldLuckyBlock(model)
    if not model or not model:IsA("Model") then return false end
    local lower=string.lower(tostring(model.Name or ""))
    if lower:find("alternate lucky block",1,true) or lower:find("alternative",1,true) then return true end

    local id=model:GetAttribute("ID") or model:GetAttribute("Id") or model:GetAttribute("id")
        or model:GetAttribute("_RegisteredID") or model:GetAttribute("RegisteredID")
        or model:GetAttribute("LuckyBlockID") or model:GetAttribute("SlimeId")
        or model:GetAttribute("slimeId") or model:GetAttribute("slimeID")
    if id~=nil and tostring(id)==ALTERNATE_LUCKY_BLOCK_ID then return true end

    local rarity=model:GetAttribute("Rarity") or model:GetAttribute("_Rarity") or model:GetAttribute("rarity")
    if rarity~=nil and string.lower(tostring(rarity))=="alternative" then return true end

    local blockName=model:GetAttribute("LuckyBlockName") or model:GetAttribute("BlockName") or model:GetAttribute("DisplayName")
    if blockName and string.lower(tostring(blockName)):find("alternate lucky block",1,true) then return true end

    for _,childName in ipairs({"ID","Id","_RegisteredID","RegisteredID","LuckyBlockID","Rarity","_Rarity","LuckyBlockName","BlockName"}) do
        local obj=model:FindFirstChild(childName)
        if obj and obj:IsA("ValueBase") then
            local v=tostring(obj.Value)
            if v==ALTERNATE_LUCKY_BLOCK_ID or string.lower(v)=="alternative"
                or string.lower(v):find("alternate lucky block",1,true)
            then return true end
        end
    end
    return false
end

local function resolveSlimeDefinition(entry)
    if type(entry)~="table" then return nil end
    local id=entry.id or entry.Id
    if id==nil or not _Lib or not _Lib.Database or not _Lib.Database.Slimes then return nil end
    local db=_Lib.Database.Slimes
    return db[id] or db[tostring(id)] or db[tonumber(id)]
end

local function isAlternateLuckyBlockData(entry,def,tool)
    local id=type(entry)=="table" and (entry.id or entry.Id or entry.slimeId or entry.slimeID) or nil
    if id~=nil and tostring(id)==ALTERNATE_LUCKY_BLOCK_ID then return true end

    if def then
        local name=string.lower(tostring(def.Name or ""))
        local rarity=string.lower(tostring(def.Rarity or def.rarity or ""))
        local typ=string.lower(tostring(def.Type or ""))
        if name:find("alternate lucky block",1,true) then return true end
        if rarity=="alternative" and typ:find("lucky",1,true) then return true end
    end

    if type(entry)=="table" then
        local name=string.lower(tostring(entry.Name or entry.name or ""))
        local rarity=string.lower(tostring(entry.Rarity or entry.rarity or ""))
        local typ=string.lower(tostring(entry.Type or entry.type or ""))
        if name:find("alternate lucky block",1,true) then return true end
        if rarity=="alternative" and (typ:find("lucky",1,true) or name:find("lucky",1,true)
            or entry.production_is_lucky_block==true) then return true end
    end

    if tool and tool:IsA("Tool") then
        local name=string.lower(tostring(tool.Name or ""))
        if name:find("alternate lucky block",1,true) then return true end
        local rarity=tool:GetAttribute("Rarity") or tool:GetAttribute("rarity")
        local typ=tool:GetAttribute("Type") or tool:GetAttribute("type") or tool:GetAttribute("ItemType")
        if rarity and string.lower(tostring(rarity))=="alternative"
            and (string.lower(tostring(typ or "")):find("lucky",1,true) or name:find("lucky",1,true))
        then return true end
    end
    return false
end

local function isLuckyInventoryEntry(tool,entry,def)
    if isAlternateLuckyBlockData(entry,def,tool) then return true end
    local function has(v)
        v=string.lower(tostring(v or ""))
        return v:find("lucky block",1,true) or v:find("lucky",1,true)
            or v:find("box",1,true) or v:find("crate",1,true)
    end
    if def and (tostring(def.Type or "")=="Lucky Block" or has(def.Type) or has(def.Category)) then return true end
    if entry and (entry.production_is_lucky_block==true or has(entry.Type) or has(entry.type) or has(entry.Category) or has(entry.category)) then return true end
    if tool and (has(tool.Name) or has(tool:GetAttribute("Type")) or has(tool:GetAttribute("ItemType")) or has(tool:GetAttribute("Category"))
        or tool:GetAttribute("LuckyBlock")==true or tool:GetAttribute("IsLuckyBlock")==true or tool:GetAttribute("isLuckyBlock")==true)
    then return true end
    return false
end

local function isLuckyBlock(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local typ=tool:GetAttribute("Type") or tool:GetAttribute("type")
    if typ and string.lower(tostring(typ)):find("lucky",1,true) then return true end
    local name=string.lower(tostring(tool.Name))
    return name:find("lucky",1,true)~=nil or name:find("box",1,true)~=nil or name:find("crate",1,true)~=nil
end

-- ============================================
-- CLOAK / EQUIP
-- ============================================
local function findCloakTool()
    local function scan(bag)
        if not bag then return nil end
        for _,item in ipairs(bag:GetChildren()) do
            if item:IsA("Tool") then
                local n=string.lower(item.Name)
                if n:find("invisibility") or n:find("cloak") or n:find("invis") then return item end
            end
        end
    end
    return scan(LocalPlayer.Character) or scan(LocalPlayer:FindFirstChild("Backpack"))
end

local function setLocalInvisible(on)
    local char=LocalPlayer.Character
    if not char then return end
    for _,p in ipairs(char:GetDescendants()) do
        if (p:IsA("BasePart") and p.Name~="HumanoidRootPart") or p:IsA("Decal") or p:IsA("Texture") then
            if on then
                if p:GetAttribute("_OrigTrans")==nil then p:SetAttribute("_OrigTrans",p.Transparency) end
                p.Transparency=1
            else
                local orig=p:GetAttribute("_OrigTrans")
                if orig~=nil then p.Transparency=orig;p:SetAttribute("_OrigTrans",nil) end
            end
        end
    end
end

local function activateCloak()
    local tool=findCloakTool()
    local hum=getHumanoid()
    local char=LocalPlayer.Character
    if not tool or not hum or not char then return false end
    if tool.Parent~=char then
        pcall(function() hum:UnequipTools() end);task.wait(.05)
        pcall(function() hum:EquipTool(tool) end)
        if tool.Parent~=char then pcall(function() tool.Parent=char end) end
        task.wait(.15)
    end
    local ca=tool:FindFirstChild("CanActivate")
    if ca and ca:IsA("BoolValue") then ca.Value=true end
    pcall(function() tool:Activate() end)
    setLocalInvisible(true)
    return true
end

local function deactivateCloak()
    setLocalInvisible(false)
    local hum=getHumanoid()
    if hum then pcall(function() hum:UnequipTools() end) end
end

local function equipTool(tool)
    local hum=getHumanoid()
    local char=LocalPlayer.Character
    if not hum or not char or not tool then return false end
    if tool.Parent==char then return true end
    pcall(function() hum:UnequipTools() end);task.wait(.05)
    pcall(function() hum:EquipTool(tool) end)
    if tool.Parent~=char then pcall(function() tool.Parent=char end) end
    task.wait(DELAY_EQUIP)
    return tool.Parent==char
end

-- ============================================
-- REMOTES
-- ============================================
local function ResolveRemoteEventExact(name)
    for _,v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name==name then return v end
    end
end

local function findRemote(part)
    part=string.lower(part)
    for _,v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and string.lower(v.Name):find(part,1,true) then return v end
    end
end

local function ResolvePlaceRemote()
    if PlaceRemote and PlaceRemote.Parent and PlaceRemote:IsA("RemoteEvent") then return PlaceRemote end
    PlaceRemote=ResolveRemoteEventExact("Place Slime")
    return PlaceRemote
end

local function ResolveUpgradeChannel()
    if UpgradeChannel and type(UpgradeChannel)=="table" then return UpgradeChannel end
    if _Lib and _Lib.Network and typeof(_Lib.Network.new)=="function" then
        local ok,ch=pcall(function() return _Lib.Network.new("Upgrade Slime","RemoteEvent") end)
        if ok and ch then UpgradeChannel=ch;return ch end
    end
end

local function ResolveUpgradeRemote()
    if UpgradeRemote and UpgradeRemote.Parent and UpgradeRemote:IsA("RemoteEvent") then return UpgradeRemote end
    UpgradeRemote=ResolveRemoteEventExact("Upgrade Slime")
    return UpgradeRemote
end

local function FireUpgradeSlot(slot)
    local ch=ResolveUpgradeChannel()
    if ch and typeof(ch.Fire)=="function" then
        local ok=pcall(function() ch:Fire(tostring(slot)) end)
        if ok then return true end
        UpgradeChannel=nil
    end
    local r=ResolveUpgradeRemote()
    return r and pcall(function() r:FireServer(tostring(slot)) end) or false
end

local function ResolveRF(name)
    for _,v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteFunction") and v.Name==name then return v end
    end
end

local function ResolveGiftChannel()
    if GiftChannel and type(GiftChannel)=="table" then return GiftChannel end
    if _Lib and _Lib.Network and typeof(_Lib.Network.new)=="function" then
        local ok,ch=pcall(function() return _Lib.Network.new("Gift Slime","RemoteFunction") end)
        if ok and ch then GiftChannel=ch;return ch end
    end
end

local function ResolveAcceptGiftChannel()
    if AcceptGiftChannel and type(AcceptGiftChannel)=="table" then return AcceptGiftChannel end
    if _Lib and _Lib.Network and typeof(_Lib.Network.new)=="function" then
        local ok,ch=pcall(function() return _Lib.Network.new("Accept Gift","RemoteFunction") end)
        if ok and ch then AcceptGiftChannel=ch;return ch end
    end
end

local function ResolveGiftRequestChannel()
    if GiftRequestChannel and type(GiftRequestChannel)=="table" then return GiftRequestChannel end
    if _Lib and _Lib.Network and typeof(_Lib.Network.new)=="function" then
        local ok,ch=pcall(function() return _Lib.Network.new("Gift Slime Request","RemoteEvent") end)
        if ok and ch then GiftRequestChannel=ch;return ch end
    end
end

local function FireGiftSlime(playerName,uid)
    local ch=ResolveGiftChannel()
    if ch and typeof(ch.Fire)=="function" then
        local ok,res,msg=pcall(function() return ch:Fire(playerName,uid) end)
        if ok then return res==true,msg end
        GiftChannel=nil
    end
    GiftRawRemote=GiftRawRemote or ResolveRF("Gift Slime")
    if GiftRawRemote then
        local ok,res,msg=pcall(function() return GiftRawRemote:InvokeServer(playerName,uid) end)
        if ok then return res==true,msg end
    end
    return false,"Gift Slime unavailable"
end

local function FireAcceptGift(uid)
    local ch=ResolveAcceptGiftChannel()
    if ch and typeof(ch.Fire)=="function" then
        local ok,res,msg=pcall(function() return ch:Fire(uid) end)
        if ok then return res==true,msg end
        AcceptGiftChannel=nil
    end
    AcceptGiftRawRemote=AcceptGiftRawRemote or ResolveRF("Accept Gift")
    if AcceptGiftRawRemote then
        local ok,res,msg=pcall(function() return AcceptGiftRawRemote:InvokeServer(uid) end)
        if ok then return res==true,msg end
    end
    return false,"Accept Gift unavailable"
end

local function hookGiftRequestListener()
    if giftRequestConnection then return true end
    local ch=ResolveGiftRequestChannel()
    if not ch or typeof(ch.Connect)~="function" then return false end
    local ok,conn=pcall(function()
        return ch:Connect(function(action,data)
            if action=="send" and type(data)=="table" and data.uid~=nil then pendingGiftUID=data.uid
            elseif action=="remove" then pendingGiftUID=nil end
        end)
    end)
    if ok and conn then giftRequestConnection=conn;return true end
    return false
end

local function getPendingGiftUIDFromGui()
    if not PlayerGui then return nil end
    for _,obj in ipairs(PlayerGui:GetDescendants()) do
        local uid=obj:GetAttribute("slimeUID")
        if uid~=nil then
            local main=obj:FindFirstChild("Main")
            if main and main:FindFirstChild("Accept") and main:FindFirstChild("Decline") then return uid end
        end
    end
end


-- ============================================
-- EARNINGS / INVENTORY
-- ============================================
local function getRebirthCashMultiplier(data)
    if not data then return 1 end
    local db=_Lib and _Lib.Database and _Lib.Database.Rebirths
    local def=db and (db[data.Rebirth] or db[tostring(data.Rebirth)])
    return def and tonumber(def.CashMulti) or 1
end

local function getBaseProductionMPS(entry,def)
    local base=def and tonumber(def.MoneyPerSecond) or nil
    if base==nil and entry then
        base=tonumber(entry.production_mps) or tonumber(entry.money_per_second)
            or tonumber(entry.MoneyPerSecond) or tonumber(entry.mps) or tonumber(entry.base_mps)
    end
    return math.max(0,tonumber(base) or 0)
end

local function calculateOwnedSlimeEarnings(entry,def,data)
    if type(entry)~="table" then return 0 end
    local base=getBaseProductionMPS(entry,def)
    local level=math.max(1,tonumber(entry.level) or 1)
    local earnings=base
    if _Lib and _Lib.Shared and typeof(_Lib.Shared.getRebirthScaledEarnings)=="function" then
        local ok,v=pcall(function()
            return _Lib.Shared.getRebirthScaledEarnings(base,level,getRebirthCashMultiplier(data))
        end)
        if ok and tonumber(v) then earnings=tonumber(v) end
    end
    local multi=1
    if _Lib and _Lib.Shared and typeof(_Lib.Shared.getMutationMulti)=="function" then
        local ok,v=pcall(function()
            return _Lib.Shared.getMutationMulti(entry.mutation or "None",entry.event_mutations or {})
        end)
        if ok and tonumber(v) then multi=tonumber(v) end
    end
    earnings*=multi
    earnings*=1+(tonumber(data and data.InviteBonusMult) or 0)+(tonumber(LocalPlayer:GetAttribute("FriendPresenceBonus")) or 0)
    earnings*=tonumber(workspace:GetAttribute("AdminProductionMult")) or 1
    if earnings~=earnings then earnings=0 end
    return math.max(0,tonumber(earnings) or 0)
end

local function collectCurrentSlimeToolsByUID()
    local map={}
    local function scan(c)
        if not c then return end
        for _,tool in ipairs(c:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("slimeUID")~=nil then
                map[tostring(tool:GetAttribute("slimeUID"))]=tool
            end
        end
    end
    scan(LocalPlayer:FindFirstChild("Backpack"));scan(LocalPlayer.Character)
    return map
end

local function getSlimeTools()
    local data=getData()
    local inv=data and data.Inventory
    local tools=collectCurrentSlimeToolsByUID()
    local list={}
    if type(inv)~="table" then return list end
    for _,entry in pairs(inv) do
        if type(entry)=="table" and entry.uid~=nil then
            local tool=tools[tostring(entry.uid)]
            if tool and tool.Parent then
                local def=resolveSlimeDefinition(entry)
                if not isLuckyInventoryEntry(tool,entry,def) then
                    table.insert(list,{
                        tool=tool,uid=entry.uid,id=entry.id or entry.Id,
                        value=calculateOwnedSlimeEarnings(entry,def,data),
                        baseMps=getBaseProductionMPS(entry,def),
                        level=math.max(1,tonumber(entry.level) or 1),
                        rarity=(def and (def.Rarity or def.rarity)) or entry.Rarity or entry.rarity or "Unknown",
                        mutation=entry.mutation or "None",
                        eventMutations=entry.event_mutations or {},
                        displayName=(def and def.Name) or tool.Name,
                    })
                end
            end
        end
    end
    table.sort(list,function(a,b)
        if a.value~=b.value then return a.value>b.value end
        return tostring(a.uid)<tostring(b.uid)
    end)
    return list
end

local function resolveHeldToolRarity(e)
    for _,v in ipairs({e.rarity,e.Rarity,e.tier,e.Tier,e.displayRarity,e.displayName,e.name,e.id}) do
        if v~=nil then
            local s=tostring(v);local l=string.lower(s)
            if s==ALTERNATE_LUCKY_BLOCK_ID or l:find("alternative",1,true) or l:find("alternate",1,true) then
                return "Alternative"
            end
            for _,r in ipairs(ALL_RARITIES) do
                if l:find(string.lower(r),1,true) then return r end
            end
        end
    end
    return tostring(e.rarity or "")
end

local function parseEventMutations(value)
    local names={};local has=false
    local function add(v)
        if v==nil then return end
        local l=string.lower(tostring(v))
        if l~="" and l~="none" then names[l]=true;has=true end
    end
    if type(value)=="table" then
        for k,v in pairs(value) do
            if type(k)=="string" and v==true then add(k)
            elseif type(v)=="string" then add(v)
            elseif type(k)=="string" then add(k) end
        end
    else add(value) end
    return has,names
end

local function manualMutationMatches(selected,mutation,hasEvent,eventNames)
    local wanted=string.lower(tostring(selected or "All"))
    if wanted=="all" then return true end
    if wanted=="none" or wanted=="no mutation" or wanted=="normal" then return mutation==nil and not hasEvent end
    if mutation and string.lower(tostring(mutation))==wanted then return true end
    return type(eventNames)=="table" and eventNames[wanted]==true
end

local function getHeldSlimeToolsByDualFilter(rarityFilter,mutationFilter)
    local result={}
    local wanted=string.lower(tostring(rarityFilter or "All"))
    for _,e in ipairs(getSlimeTools()) do
        local r=resolveHeldToolRarity(e)
        local rarityOK=wanted=="all" or string.lower(r)==wanted
        local hasEvent,names=parseEventMutations(e.eventMutations)
        local mutation=e.mutation
        if mutation and table.find({"","None","none","Normal","normal","No Mutation"},tostring(mutation)) then mutation=nil end
        if rarityOK and manualMutationMatches(mutationFilter,mutation,hasEvent,names) then table.insert(result,e) end
    end
    table.sort(result,function(a,b) return a.value==b.value and tostring(a.uid)<tostring(b.uid) or a.value>b.value end)
    return result
end

local function getSlotRarityAndMutation(slotName,stand,plotSlimes,liveFolder)
    local rarity,mutation=nil,nil
    local hasEvent,eventNames=false,{}
    local entry=type(plotSlimes)=="table" and (plotSlimes[slotName] or plotSlimes[tonumber(slotName)]) or nil
    if type(entry)=="table" then
        rarity=entry.Rarity or entry.rarity
        mutation=entry.mutation or entry.Mutation
        hasEvent,eventNames=parseEventMutations(entry.event_mutations or entry.EventMutations)
        if not rarity then
            local def=resolveSlimeDefinition(entry)
            rarity=def and (def.Rarity or def.rarity) or nil
        end
    end
    local model=liveFolder and liveFolder:FindFirstChild(tostring(slotName))
    if model then
        rarity=rarity or model:GetAttribute("Rarity") or model:GetAttribute("rarity")
        mutation=mutation or model:GetAttribute("Mutation") or model:GetAttribute("mutation")
    end
    if stand then
        rarity=rarity or stand:GetAttribute("Rarity") or stand:GetAttribute("rarity")
        mutation=mutation or stand:GetAttribute("Mutation") or stand:GetAttribute("mutation")
    end
    if mutation then
        local l=string.lower(tostring(mutation))
        if l=="" or l=="none" or l=="normal" then mutation=nil end
    end
    return rarity,mutation,hasEvent,eventNames
end

local function getOccupiedSlotsByDualFilter(rarityFilter,mutationFilter)
    local data=getData()
    local plotSlimes=(data and data.PlotSlimes) or {}
    local liveFolder=getPlayerSlimesFolder()
    local result={}
    local wanted=string.lower(tostring(rarityFilter or "All"))
    for _,slot in ipairs(getAllOccupiedSlots()) do
        local rarity,mutation,hasEvent,names=getSlotRarityAndMutation(slot.name,slot.stand,plotSlimes,liveFolder)
        local r=tostring(rarity or "")
        if r=="Player God" then r="Slime God" end
        if (wanted=="all" or string.lower(r)==wanted) and manualMutationMatches(mutationFilter,mutation,hasEvent,names) then
            slot.rarity=r;slot.mutation=mutation or "None";table.insert(result,slot)
        end
    end
    return result
end

-- ============================================
-- LUCKY INVENTORY / SLOT MATCHING
-- ============================================
local function luckyBlockToolMatchesType(tool,filterType,inventoryByUID)
    if not tool or not isLuckyBlock(tool) then return false end
    filterType=tostring(filterType or "All")
    if filterType=="All" then return true end
    local uid=tool:GetAttribute("slimeUID")
    local entry=uid~=nil and inventoryByUID[tostring(uid)] or nil
    local def=resolveSlimeDefinition(entry)
    if filterType=="Alternate" and isAlternateLuckyBlockData(entry,def,tool) then return true end
    local allowed=LUCKY_BLOCK_MODEL_NAMES[filterType]
    if allowed and (allowed[tostring(tool.Name)] or allowed[tostring(def and def.Name or "")]) then return true end
    local rarity=tool:GetAttribute("Rarity") or tool:GetAttribute("rarity")
        or (def and (def.Rarity or def.rarity)) or (entry and (entry.Rarity or entry.rarity))
    if rarity then
        local r=tostring(rarity)
        if filterType=="Soccer God" and r=="Slime God" then return true end
        if filterType=="Limited" and r=="LIMITED" then return true end
        if filterType=="Alternate" and string.lower(r)=="alternative" then return true end
        if string.lower(r)==string.lower(filterType) then return true end
    end
    return false
end

local function getSelectedLuckyBlockTools()
    local data=getData();local map={};local list={};local seen={}
    if data and type(data.Inventory)=="table" then
        for _,e in pairs(data.Inventory) do if type(e)=="table" and e.uid~=nil then map[tostring(e.uid)]=e end end
    end
    local function scan(bag)
        if not bag then return end
        for _,item in ipairs(bag:GetChildren()) do
            local uid=item:IsA("Tool") and item:GetAttribute("slimeUID") or nil
            if uid~=nil and not seen[tostring(uid)] and luckyBlockToolMatchesType(item,selectedLuckyBlockType,map) then
                seen[tostring(uid)]=true;table.insert(list,{tool=item,uid=uid})
            end
        end
    end
    scan(LocalPlayer:FindFirstChild("Backpack"));scan(LocalPlayer.Character)
    return list
end

local function getUnopenedLuckyBlockSlots(filterType)
    filterType=tostring(filterType or "All")
    local data=getData();local plotSlimes=(data and data.PlotSlimes) or {}
    local list,seen={},{}
    local function add(n) n=tostring(n);if not seen[n] then seen[n]=true;table.insert(list,n) end end
    local function matches(entry)
        if filterType=="All" then return true end
        if type(entry)~="table" then return false end
        local def=resolveSlimeDefinition(entry)
        if filterType=="Alternate" and isAlternateLuckyBlockData(entry,def,nil) then return true end
        local allowed=LUCKY_BLOCK_MODEL_NAMES[filterType]
        if allowed and (allowed[tostring(def and def.Name or "")] or allowed[tostring(entry.Name or entry.name or "")]) then return true end
        local r=(def and (def.Rarity or def.rarity)) or entry.Rarity or entry.rarity
        if r then
            r=tostring(r)
            if filterType=="Soccer God" and r=="Slime God" then return true end
            if filterType=="Limited" and r=="LIMITED" then return true end
            if filterType=="Alternate" and string.lower(r)=="alternative" then return true end
            if string.lower(r)==string.lower(filterType) then return true end
        end
        return false
    end
    for k,e in pairs(plotSlimes) do
        if type(e)=="table" then
            local def=resolveSlimeDefinition(e)
            local typ=string.lower(tostring((def and def.Type) or e.Type or e.type or ""))
            if typ:find("lucky",1,true) and matches(e) then add(k) end
        end
    end
    table.sort(list,function(a,b) return (tonumber(a) or 9999)<(tonumber(b) or 9999) end)
    return list
end

-- ============================================
-- WORLD LUCKY COLLECTOR TARGET
-- ============================================
local function getTargetLuckyBlock()
    local live=workspace:FindFirstChild("Live")
    local slimes=live and live:FindFirstChild("Slimes")
    if not slimes then return nil end
    local best,bestValue,bestDistance=nil,-math.huge,math.huge
    local root=getRoot()

    for _,model in ipairs(slimes:GetChildren()) do
        if model:IsA("Model") and not model:GetAttribute("Carrying") then
            local name=tostring(model.Name)
            local matches=false
            if selectedLuckyBlockType=="All" then
                for _,names in pairs(LUCKY_BLOCK_MODEL_NAMES) do if names[name] then matches=true;break end end
                if not matches and isAlternateWorldLuckyBlock(model) then matches=true end
            elseif selectedLuckyBlockType=="Alternate" then
                matches=isAlternateWorldLuckyBlock(model)
            else
                local allowed=LUCKY_BLOCK_MODEL_NAMES[selectedLuckyBlockType]
                matches=allowed and allowed[name]==true or false
            end
            if not matches then continue end

            local part=model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if not part then continue end
            local isAlt=isAlternateWorldLuckyBlock(model)
            local value=tonumber(model:GetAttribute("Value"))
                or tonumber(model:GetAttribute("MoneyPerSecond"))
                or tonumber(model:GetAttribute("_AutoMoneyPerSecond"))
                or tonumber(model:GetAttribute("_MpsOverride"))
                or (isAlt and ALTERNATE_LUCKY_BLOCK_MIN_VALUE or 0)
            local dist=root and (root.Position-part.Position).Magnitude or math.huge
            local prompt=nil
            for _,d in ipairs(model:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    local a=string.lower(tostring(d.ActionText or ""))
                    prompt=prompt or d
                    if a:find("steal",1,true) or a:find("pick",1,true) or a:find("take",1,true) or a:find("open",1,true) then prompt=d;break end
                end
            end
            if value>bestValue or (value==bestValue and dist<bestDistance) then
                bestValue=value;bestDistance=dist
                best={name=name,type=isAlt and "Alternate" or selectedLuckyBlockType,
                    rarity=isAlt and "Alternative" or nil,id=isAlt and ALTERNATE_LUCKY_BLOCK_ID or nil,
                    value=value,part=part,prompt=prompt,model=model}
            end
        end
    end
    return best
end

local function attemptSteal(prompt)
    if not prompt then return false end
    local hold=prompt.HoldDuration or 0
    if typeof(fireproximityprompt)=="function" and pcall(fireproximityprompt,prompt) then task.wait(hold+.5);return true end
    if pcall(function() prompt:Trigger() end) then task.wait(hold+.5);return true end
    return false
end

-- ============================================
-- UNIVERSAL PLACE / OPEN ALL LUCKY BOXES
-- ============================================
local LUCKY_BLOCK_RARITY_VALUE = {
    ["Common"] = 5,
    ["Rare"] = 220,
    ["Epic"] = 750,
    ["Legendary"] = 2500,
    ["Mythic"] = 8500,
    ["Secret"] = 29000,
    ["Divine"] = 35000,
    ["Slime God"] = 95000,
    ["Exclusive"] = 330000,
    ["LIMITED"] = 330000,
    ["OG"] = 1100000,
    ["Champions"] = 5250000,
    ["Spain"] = 18400000,
    ["Icons"] = 82500000,
    ["Japan"] = 209000000,
    ["Alternative"] = 700000000,
}

local function getLuckyBlockPlacementValue(entry, def, tool)
    -- Prefer a real live/persisted value if this build exposes one.
    local direct = nil

    if tool then
        direct =
            tonumber(tool:GetAttribute("Value"))
            or tonumber(tool:GetAttribute("MoneyPerSecond"))
            or tonumber(tool:GetAttribute("_AutoMoneyPerSecond"))
            or tonumber(tool:GetAttribute("_MpsOverride"))
    end

    if not direct and type(entry) == "table" then
        direct =
            tonumber(entry.Value)
            or tonumber(entry.value)
            or tonumber(entry.MoneyPerSecond)
            or tonumber(entry.money_per_second)
            or tonumber(entry.production_mps)
            or tonumber(entry.mps)
    end

    if not direct and def then
        local mps = tonumber(def.MoneyPerSecond)
        if mps and mps > 0 then
            direct = mps
        end
    end

    if direct and direct > 0 then
        return direct
    end

    -- Lucky Block database entries often have MoneyPerSecond = 0, so use
    -- the block's content-rarity floor as the placement priority fallback.
    local rarity =
        (def and (def.Rarity or def.rarity))
        or (type(entry) == "table" and (entry.Rarity or entry.rarity))
        or (tool and (tool:GetAttribute("Rarity") or tool:GetAttribute("rarity")))
        or nil

    if isAlternateLuckyBlockData(entry, def, tool) then
        rarity = "Alternative"
    end

    rarity = tostring(rarity or "")

    if rarity == "Player God" then
        rarity = "Slime God"
    elseif rarity == "Limited" then
        rarity = "LIMITED"
    elseif rarity == "Alternate" then
        rarity = "Alternative"
    end

    return LUCKY_BLOCK_RARITY_VALUE[rarity] or RARITY_VALUE[rarity] or 0
end

local function getAllLuckyBlockPlaceEntries()
    local list, seen = {}, {}
    local data = getData()
    local inventoryByUID = {}
    local toolsByUID = collectCurrentSlimeToolsByUID()

    if data and type(data.Inventory) == "table" then
        for _, entry in pairs(data.Inventory) do
            if type(entry) == "table" and entry.uid ~= nil then
                inventoryByUID[tostring(entry.uid)] = entry
            end
        end
    end

    local function add(uid, tool, entry)
        if uid == nil then return end

        local key = tostring(uid)
        if seen[key] then return end

        entry = entry or inventoryByUID[key]
        tool = tool or toolsByUID[key]

        local def = resolveSlimeDefinition(entry)

        if not isLuckyInventoryEntry(tool, entry, def) then
            return
        end

        seen[key] = true

        local rarity =
            (def and (def.Rarity or def.rarity))
            or (entry and (entry.Rarity or entry.rarity))
            or (tool and (tool:GetAttribute("Rarity") or tool:GetAttribute("rarity")))
            or "Unknown"

        if isAlternateLuckyBlockData(entry, def, tool) then
            rarity = "Alternative"
        end

        table.insert(list, {
            uid = uid,
            tool = tool,
            entry = entry,
            def = def,
            rarity = tostring(rarity),
            name =
                (def and def.Name)
                or (entry and (entry.Name or entry.name))
                or (tool and tool.Name)
                or tostring(uid),
            value = getLuckyBlockPlacementValue(entry, def, tool),
        })
    end

    -- Inventory is the source of truth. Physical tools are attached by UID.
    for key, entry in pairs(inventoryByUID) do
        add(entry.uid, toolsByUID[key], entry)
    end

    -- Fallback for a tool that is visible before Data.Inventory refreshes.
    for key, tool in pairs(toolsByUID) do
        if not seen[key] then
            add(tool:GetAttribute("slimeUID"), tool, inventoryByUID[key])
        end
    end

    -- HIGHEST VALUE LUCKY BOX ALWAYS FIRST.
    table.sort(list, function(a, b)
        local av = tonumber(a.value) or 0
        local bv = tonumber(b.value) or 0

        if av ~= bv then
            return av > bv
        end

        -- Stable tie-breakers.
        if tostring(a.rarity) ~= tostring(b.rarity) then
            return tostring(a.rarity) < tostring(b.rarity)
        end

        return tostring(a.uid) < tostring(b.uid)
    end)

    return list
end

local function doPlaceBoxesOnly()
    local remote = ResolvePlaceRemote()
    if not remote then
        StatusLabel.Text = 'Place Boxes: "Place Slime" remote missing'
        return 0
    end

    local boxes = getAllLuckyBlockPlaceEntries()
    local slots = getAvailableSlots() -- ALL currently free stands/floors.
    local total = math.min(#boxes, #slots)

    if total <= 0 then
        if #boxes == 0 then
            StatusLabel.Text = "Place Boxes: no Lucky Boxes detected"
        else
            StatusLabel.Text = "Place Boxes: no free stands/floors"
        end
        return 0
    end

    print("====================================================")
    print("[PlaceBoxes] HIGHEST VALUE LUCKY BOX FIRST")
    print("Detected boxes:", #boxes, "| Free slots:", #slots, "| Placing:", total)

    for i = 1, total do
        local box = boxes[i]
        print(string.format(
            "#%d %s | Rarity=%s | PriorityValue=%.0f | UID=%s -> Slot %s",
            i,
            tostring(box.name),
            tostring(box.rarity),
            tonumber(box.value) or 0,
            tostring(box.uid),
            tostring(slots[i].name)
        ))
    end
    print("====================================================")

    local placed = 0

    for i = 1, total do
        local box = boxes[i]
        local slot = slots[i]

        -- Re-find the current physical tool just before placing.
        local currentTool = box.tool
        if not currentTool or not currentTool.Parent then
            currentTool = collectCurrentSlimeToolsByUID()[tostring(box.uid)]
        end

        -- Use the same equip path as the working normal Place button whenever
        -- a physical tool exists. Inventory-only entries still get a remote try.
        if currentTool and currentTool.Parent then
            equipTool(currentTool)
        end

        local success = false

        -- Controlled retries are more reliable than blasting every UID into every
        -- slot for eight rounds. The server remains authoritative.
        for attempt = 1, 3 do
            local fired = pcall(function()
                remote:FireServer(tostring(slot.name), box.uid)
            end)

            if fired then
                success = true
                break
            end

            task.wait(0.10)
        end

        if success then
            placed += 1
            StatusLabel.Text = string.format(
                "Place Boxes %d/%d | %s | %.0f -> slot %s",
                placed,
                total,
                tostring(box.name),
                tonumber(box.value) or 0,
                tostring(slot.name)
            )
        else
            warn(
                "[PlaceBoxes] Failed UID",
                tostring(box.uid),
                "-> slot",
                tostring(slot.name)
            )
        end

        task.wait(DELAY_PLACE)
    end

    local hum = getHumanoid()
    if hum then
        pcall(function()
            hum:UnequipTools()
        end)
    end

    return placed
end

local function doOpenBoxesOnly()
    local remote=OpenRemote or ResolveRemoteEventExact("Open Lucky Block")
    OpenRemote=remote
    if not remote then return 0 end
    local names,seen={},{}
    for _,slot in ipairs(getAllOccupiedSlots()) do
        local n=tostring(slot.name);if not seen[n] then seen[n]=true;table.insert(names,n) end
    end
    for _,n in ipairs(getUnopenedLuckyBlockSlots("All")) do
        if not seen[n] then seen[n]=true;table.insert(names,n) end
    end
    for _=1,10 do for _,n in ipairs(names) do pcall(function() remote:FireServer(n) end) end end
    return #names
end

local function doPlaceAndOpenBoxes()
    return doPlaceBoxesOnly(),doOpenBoxesOnly()
end


-- ============================================
-- UPGRADE FILTER / PRIORITY
-- ============================================
local function normalizeUpgradeRarity(r)
    r=tostring(r or "")
    if r=="Player God" then return "Slime God" end
    local l=string.lower(r)
    if l=="alternate" or l:find("alternate lucky block",1,true) then return "Alternative" end
    return r
end

local function upgradeMutationMatches(selected,mutation,hasEvent,eventNames)
    local s=string.lower(tostring(selected or "All"))
    if s=="all" then return true end
    if s=="common" or s=="none" or s=="normal" or s=="no mutation" then return mutation==nil and not hasEvent end
    if mutation and string.lower(tostring(mutation))==s then return true end
    return type(eventNames)=="table" and eventNames[s]==true
end

local function getPrioritizedUpgrades()
    local data=getData()
    local plotSlimes=(data and data.PlotSlimes) or {}
    local liveFolder=getPlayerSlimesFolder()
    local list={}
    for _,slot in ipairs(getAllOccupiedSlots()) do
        local entry=plotSlimes[slot.name] or plotSlimes[tonumber(slot.name)]
        if type(entry)=="table" then
            local def=resolveSlimeDefinition(entry)
            if not (def and tostring(def.Type or "")=="Lucky Block") then
                local level=tonumber(entry.level or entry.Level) or 1
                if level<MAX_LEVEL then
                    local rarity,mutation,hasEvent,names=getSlotRarityAndMutation(slot.name,slot.stand,plotSlimes,liveFolder)
                    rarity=normalizeUpgradeRarity(rarity)
                    local rarityOK=selectedUpgradeRarity=="All"
                        or string.lower(rarity)==string.lower(normalizeUpgradeRarity(selectedUpgradeRarity))
                    if rarityOK and upgradeMutationMatches(selectedUpgradeMutation,mutation,hasEvent,names) then
                        local multi=1
                        if _Lib and _Lib.Shared and typeof(_Lib.Shared.getMutationMulti)=="function" then
                            local ok,v=pcall(function()
                                return _Lib.Shared.getMutationMulti(entry.mutation or mutation or "None",entry.event_mutations or {})
                            end)
                            if ok and tonumber(v) then multi=tonumber(v) end
                        end
                        table.insert(list,{
                            id=tostring(slot.name),stand=slot.stand,level=level,rarity=rarity,mutation=mutation,
                            currentCashPerSecond=calculateOwnedSlimeEarnings(entry,def,data),mutationMultiplier=multi
                        })
                    end
                end
            end
        end
    end
    table.sort(list,function(a,b)
        if selectedUpgradeMutation=="All" then
            if a.currentCashPerSecond~=b.currentCashPerSecond then return a.currentCashPerSecond>b.currentCashPerSecond end
            if a.mutationMultiplier~=b.mutationMultiplier then return a.mutationMultiplier>b.mutationMultiplier end
        end
        if a.level~=b.level then return a.level<b.level end
        return (tonumber(a.id) or math.huge)<(tonumber(b.id) or math.huge)
    end)
    return list
end

-- ============================================
-- COLLECT PADS
-- ============================================
local function getAllCollectPads()
    local pads,seen={},{}
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Top") then
            local gui=obj.Top:FindFirstChild("PadGui")
            if gui and (not ONLY_WHEN_PADGUI_ENABLED or gui.Enabled) and not seen[obj] then
                seen[obj]=true;table.insert(pads,obj)
            end
        end
    end
    return pads
end

-- ============================================
-- LOWEST PROFIT / GIFT
-- ============================================
local function getLowestProfitPlacedSlots(count)
    count=math.max(1,math.floor(tonumber(count) or 1))
    local data=getData();local plotSlimes=(data and data.PlotSlimes) or {};local list={}
    for _,slot in ipairs(getAllOccupiedSlots()) do
        local e=plotSlimes[slot.name] or plotSlimes[tonumber(slot.name)]
        if type(e)=="table" then
            local def=resolveSlimeDefinition(e)
            if not isLuckyInventoryEntry(nil,e,def) then
                table.insert(list,{
                    name=slot.name,num=slot.num,value=calculateOwnedSlimeEarnings(e,def,data),
                    level=math.max(1,tonumber(e.level) or 1),mutation=e.mutation or "None",
                    displayName=(def and def.Name) or tostring(e.Name or e.name or e.id or slot.name)
                })
            end
        end
    end
    table.sort(list,function(a,b)
        if a.value~=b.value then return a.value<b.value end
        if a.level~=b.level then return a.level<b.level end
        return a.num<b.num
    end)
    local total=#list;local limited={}
    for i=1,math.min(count,total) do limited[i]=list[i] end
    return limited,total
end

local function getGiftableInventoryUIDs()
    local data=getData();local inv=data and data.Inventory;local list,seen={},{}
    if type(inv)~="table" then return list end
    for _,e in pairs(inv) do
        if type(e)=="table" and e.uid~=nil and not seen[tostring(e.uid)] then
            seen[tostring(e.uid)]=true
            local def=resolveSlimeDefinition(e)
            table.insert(list,{
                uid=e.uid,value=calculateOwnedSlimeEarnings(e,def,data),
                level=math.max(1,tonumber(e.level) or 1),mutation=e.mutation or "None",
                rarity=tostring((def and (def.Rarity or def.rarity)) or e.Rarity or e.rarity or "Unknown"),
                displayName=(def and def.Name) or tostring(e.Name or e.name or e.id or e.uid),
            })
        end
    end
    table.sort(list,function(a,b) return a.value==b.value and tostring(a.uid)<tostring(b.uid) or a.value>b.value end)
    return list
end

local function resolveGiftTarget(input)
    local wanted=string.lower(trimText(input))
    if wanted=="" then return nil,"Type a player username first" end
    for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer and string.lower(p.Name)==wanted then return p end end
    for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer and string.lower(p.DisplayName)==wanted then return p end end
    return nil,"Player not found in this server"
end

-- ============================================
-- STATE SETTERS
-- ============================================
local function setCollectState(on)
    collectEnabled=on;CollectBtn.Text=on and "Auto Collect: ON" or "Auto Collect: OFF"
end
local function setUpgradeState(on)
    upgradeEnabled=on;UpgradeBtn.Text=on and "Auto Upgrade: ON" or "Auto Upgrade: OFF"
end
local function setLuckyState(on)
    luckyEnabled=on
    if on then
        totalCollected=0;LuckyBtn.Text="Lucky Block: ON"
        StatusLabel.Text="Lucky Block ON | Type: "..selectedLuckyBlockType
    else LuckyBtn.Text="Lucky Block: OFF";luckyBlockBusy=false end
end
local function setRebirthState(on)
    rebirthEnabled=on;RebirthBtn.Text=on and "Auto Rebirth: ON" or "Auto Rebirth: OFF"
end
local function setJumpUpgradeState(on)
    jumpUpgradeEnabled=on;JumpBtn.Text=on and "Auto +10 Jump: ON" or "Auto +10 Jump: OFF"
end
local function setBoxesAutoState(on)
    boxesAutoEnabled=on;BoxesAutoBtn.Text=on and "Auto Place+Open Boxes: ON" or "Auto Place+Open Boxes: OFF"
end
local function setInvisState(on)
    invisEnabled=on;InvisBtn.Text=on and "Invis Cloak: ON" or "Invis Cloak: OFF"
end
local function setGiftAllState(on,target)
    giftAllEnabled=on
    if on then
        giftTargetName=target and target.Name or giftTargetName
        GiftAllBtn.Text="Gift All: ON";GiftNameBox.TextEditable=false
    else
        GiftAllBtn.Text="Gift All: OFF";GiftNameBox.TextEditable=true;giftTargetName=nil;table.clear(giftInFlight)
    end
end
local function setAutoAcceptGiftsState(on)
    autoAcceptGiftsEnabled=on
    AutoAcceptGiftBtn.Text=on and "Auto Accept Gifts: ON" or "Auto Accept Gifts: OFF"
    if on then hookGiftRequestListener() else pendingGiftUID=nil end
end

-- ============================================
-- STARTUP REMOTES
-- ============================================
task.spawn(function()
    local start=os.clock()
    while not _G._Lib and os.clock()-start<30 do task.wait(.5) end
    _Lib=_G._Lib
    CollectRemote=findRemote("Collect Earnings")
    UpgradeRemote=ResolveUpgradeRemote()
    RebirthRemote=findRemote("Rebirth")
    JumpUpgradeRemote=findRemote("Buy Speed Upgrade")
    PlaceRemote=ResolvePlaceRemote()
    PickupRemote=ResolveRemoteEventExact("Pickup Slime")
    OpenRemote=ResolveRemoteEventExact("Open Lucky Block")
    if _Lib then
        ResolveUpgradeChannel();ResolveGiftChannel();ResolveAcceptGiftChannel();ResolveGiftRequestChannel();hookGiftRequestListener()
    end
    StatusLabel.Text="Ready | Alternate integrated | Place uses all free floors"
end)

-- ============================================
-- BUTTONS
-- ============================================
CollectBtn.MouseButton1Click:Connect(function() setCollectState(not collectEnabled) end)
UpgradeBtn.MouseButton1Click:Connect(function() setUpgradeState(not upgradeEnabled) end)
LuckyBtn.MouseButton1Click:Connect(function() setLuckyState(not luckyEnabled) end)
RebirthBtn.MouseButton1Click:Connect(function() setRebirthState(not rebirthEnabled) end)
JumpBtn.MouseButton1Click:Connect(function() setJumpUpgradeState(not jumpUpgradeEnabled) end)
BoxesAutoBtn.MouseButton1Click:Connect(function() setBoxesAutoState(not boxesAutoEnabled) end)
InvisBtn.MouseButton1Click:Connect(function() setInvisState(not invisEnabled) end)

GiftAllBtn.MouseButton1Click:Connect(function()
    if giftAllEnabled then setGiftAllState(false);GiftStatus.Text="Gift All stopped.";return end
    local target,err=resolveGiftTarget(GiftNameBox.Text)
    if not target then GiftStatus.Text=tostring(err);return end
    GiftNameBox.Text=target.Name;setGiftAllState(true,target)
end)

AutoAcceptGiftBtn.MouseButton1Click:Connect(function() setAutoAcceptGiftsState(not autoAcceptGiftsEnabled) end)

PickupBtn.MouseButton1Click:Connect(function()
    if actionBusy or not PickupRemote then return end
    actionBusy=true;PickupBtn.Text="Picking..."
    local n=0
    for _,slot in ipairs(getOccupiedSlotsInRange(selectedPickupRange.first,selectedPickupRange.last)) do
        if pcall(function() PickupRemote:FireServer(slot.name) end) then n+=1 end
        task.wait(DELAY_PICK)
    end
    StatusLabel.Text=string.format("Picked %d from %s",n,selectedPickupRange.label)
    PickupBtn.Text="Pick Up";actionBusy=false
end)

PickupAllBtn.MouseButton1Click:Connect(function()
    if actionBusy or not PickupRemote then return end
    actionBusy=true;PickupAllBtn.Text="Picking ALL..."
    local n=0
    for _,slot in ipairs(getAllOccupiedSlots()) do
        if pcall(function() PickupRemote:FireServer(slot.name) end) then n+=1 end
        task.wait(DELAY_PICK)
    end
    StatusLabel.Text=string.format("Picked %d from ALL floors",n)
    PickupAllBtn.Text="Pick Up ALL Floors";actionBusy=false
end)

PickLowestProfitBtn.MouseButton1Click:Connect(function()
    if actionBusy or not PickupRemote then return end
    actionBusy=true;PickLowestProfitBtn.Text="Picking..."
    local requested=math.max(1,math.floor(tonumber(LowestProfitCountBox.Text) or 1))
    local lowest,total=getLowestProfitPlacedSlots(requested)
    local picked=0
    for _,e in ipairs(lowest) do
        if pcall(function() PickupRemote:FireServer(e.name) end) then picked+=1 end
        LowestProfitStatus.Text=string.format("%d/%d | %.2f cash/s",picked,#lowest,e.value)
        task.wait(DELAY_PICK)
    end
    LowestProfitStatus.Text=string.format("Picked %d/%d lowest-profit",picked,math.min(requested,total))
    PickLowestProfitBtn.Text="Pick Lowest Profit";actionBusy=false
end)

ManualFilters.pickButton.MouseButton1Click:Connect(function()
    if actionBusy or not PickupRemote then return end
    actionBusy=true;ManualFilters.pickButton.Text="Picking..."
    local list=getOccupiedSlotsByDualFilter(ManualFilters.pickRarity,ManualFilters.pickMutation)
    local n=0
    for _,slot in ipairs(list) do
        if pcall(function() PickupRemote:FireServer(slot.name) end) then n+=1 end
        task.wait(DELAY_PICK)
    end
    StatusLabel.Text=string.format("Picked %d | R:%s M:%s",n,ManualFilters.pickRarity,ManualFilters.pickMutation)
    ManualFilters.pickButton.Text="Pick Matching Players";actionBusy=false
end)

local function placeEntries(entries,finalLabel)
    local remote=ResolvePlaceRemote()
    if not remote then StatusLabel.Text="Place Slime remote missing";return 0 end
    local slots=getAvailableSlots() -- all free floors
    local total=math.min(#entries,#slots)
    local placed=0
    for i=1,total do
        local e=entries[i];local slot=slots[i]
        local tool=e.tool
        if not tool or not tool.Parent then tool=collectCurrentSlimeToolsByUID()[tostring(e.uid)] end
        if tool and slot and equipTool(tool) then
            if pcall(function() remote:FireServer(slot.name,e.uid) end) then placed+=1 end
            task.wait(DELAY_PLACE)
        end
        task.wait(DELAY_NEXT)
    end
    local hum=getHumanoid();if hum then pcall(function() hum:UnequipTools() end) end
    StatusLabel.Text=string.format("%s | %d/%d",finalLabel,placed,total)
    return placed
end

PlaceBtn.MouseButton1Click:Connect(function()
    if actionBusy then return end
    actionBusy=true;PlaceBtn.Text="Placing..."
    placeEntries(getSlimeTools(),"Placed CURRENT cash desc")
    PlaceBtn.Text="Place Slimes (CURRENT CASH first)";actionBusy=false
end)

ManualFilters.placeButton.MouseButton1Click:Connect(function()
    if actionBusy then return end
    actionBusy=true;ManualFilters.placeButton.Text="Placing..."
    local list=getHeldSlimeToolsByDualFilter(ManualFilters.placeRarity,ManualFilters.placeMutation)
    placeEntries(list,string.format("Placed R:%s M:%s",ManualFilters.placeRarity,ManualFilters.placeMutation))
    ManualFilters.placeButton.Text="Place Matching Players";actionBusy=false
end)

BoxesBtn.MouseButton1Click:Connect(function()
    if actionBusy then return end
    actionBusy=true;BoxesBtn.Text="Burst..."
    local p,o=doPlaceAndOpenBoxes()
    StatusLabel.Text=string.format("ALL Lucky Boxes | place %d | open %d",p,o)
    BoxesBtn.Text="Place + Open Selected Boxes (Once)";actionBusy=false
end)

PlaceBoxesBtn.MouseButton1Click:Connect(function()
    if actionBusy then return end
    actionBusy=true;PlaceBoxesBtn.Text="Spam..."
    local p=doPlaceBoxesOnly()
    StatusLabel.Text=string.format("Placed %d Lucky Boxes | highest value first",p)
    PlaceBoxesBtn.Text="Place Boxes";actionBusy=false
end)

OpenBoxesBtn.MouseButton1Click:Connect(function()
    if actionBusy then return end
    actionBusy=true;OpenBoxesBtn.Text="Spam..."
    local o=doOpenBoxesOnly()
    StatusLabel.Text=string.format("Opened %d slot targets",o)
    OpenBoxesBtn.Text="Open Boxes";actionBusy=false
end)

-- ============================================
-- LOOPS
-- ============================================
task.spawn(function()
    while true do
        if collectEnabled and CollectRemote then
            for _,pad in ipairs(getAllCollectPads()) do
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
            local list=getPrioritizedUpgrades()
            if #list==0 then
                StatusLabel.Text=string.format("Upgrade ON | %s + %s | no matches",selectedUpgradeRarity,selectedUpgradeMutation)
                task.wait(.35)
            else
                local max=math.min(10,#list)
                for i=1,max do task.spawn(function() FireUpgradeSlot(list[i].id) end) end
                StatusLabel.Text=string.format("Batch upgrade %d | %s + %s",max,selectedUpgradeRarity,selectedUpgradeMutation)
                task.wait(UPGRADE_DELAY)
            end
        else task.wait(UPGRADE_SCAN) end
    end
end)

-- Same collector mechanism for Alternate and all other Lucky types.
task.spawn(function()
    while true do
        if luckyEnabled and not luckyBlockBusy then
            luckyBlockBusy=true
            if LocalPlayer:GetAttribute("holdingSlime")==true then
                StatusLabel.Text="Lucky Block carrying -> base"
                teleportToBase();task.wait(.35)
                local deadline=os.clock()+5
                while luckyEnabled and LocalPlayer:GetAttribute("holdingSlime")==true and os.clock()<deadline do task.wait(.1) end
                luckyBlockBusy=false;task.wait(.1);continue
            end

            local block=getTargetLuckyBlock()
            if not block then
                StatusLabel.Text=string.format("No %s boxes | Total %d",selectedLuckyBlockType,totalCollected)
                luckyBlockBusy=false;task.wait(.5);continue
            end

            StatusLabel.Text=string.format("%s found -> cloak -> steal",block.name)
            pcall(activateCloak);task.wait(.12)
            local root=getRoot()
            if not root or not block.part or not block.part.Parent then luckyBlockBusy=false;task.wait(.25);continue end
            root.CFrame=block.part.CFrame*CFrame.new(0,3,4)
            root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero;task.wait(.18)

            local collected=false
            for pickupTry=1,5 do
                if not luckyEnabled then break end
                if LocalPlayer:GetAttribute("holdingSlime")==true then collected=true;break end
                if block.part and block.part.Parent then
                    local r=getRoot()
                    if r then
                        r.CFrame=block.part.CFrame*CFrame.new(0,3,4)
                        r.AssemblyLinearVelocity=Vector3.zero;r.AssemblyAngularVelocity=Vector3.zero
                    end
                end
                local prompt=nil
                if block.model and block.model.Parent then
                    for _,d in ipairs(block.model:GetDescendants()) do
                        if d:IsA("ProximityPrompt") and d.Enabled then
                            local a=string.lower(tostring(d.ActionText or ""));prompt=prompt or d
                            if a:find("steal",1,true) or a:find("pick",1,true) or a:find("take",1,true) or a:find("open",1,true) then prompt=d;break end
                        end
                    end
                end
                prompt=prompt or block.prompt
                if prompt and prompt.Parent then
                    StatusLabel.Text=string.format("%s pickup %d/5",block.type,pickupTry)
                    attemptSteal(prompt)
                    local pd=os.clock()+1.5
                    while luckyEnabled and os.clock()<pd do
                        if LocalPlayer:GetAttribute("holdingSlime")==true then collected=true;break end
                        task.wait(.05)
                    end
                    if collected then break end
                end
                task.wait(.2)
            end

            if not collected then
                StatusLabel.Text="Lucky pickup not confirmed";luckyBlockBusy=false;task.wait(.25);continue
            end
            totalCollected+=1
            StatusLabel.Text=string.format("✓ %s #%d -> base",block.type,totalCollected)
            teleportToBase();task.wait(.35)
            local cd=os.clock()+5
            while luckyEnabled and LocalPlayer:GetAttribute("holdingSlime")==true and os.clock()<cd do task.wait(.1) end
            luckyBlockBusy=false
        end
        task.wait(.1)
    end
end)

task.spawn(function()
    while true do
        if rebirthEnabled and RebirthRemote then pcall(function() RebirthRemote:FireServer() end) end
        task.wait(REBIRTH_INTERVAL)
    end
end)

local function getJumpUpgradePrice(jump)
    return type(jump)=="number" and math.round(260*(1.082^jump)*2.18*10) or math.huge
end

task.spawn(function()
    while true do
        if jumpUpgradeEnabled and JumpUpgradeRemote then
            local cash,jump=getCash(),getJumpData()
            if getJumpUpgradePrice(jump)<=cash then pcall(function() JumpUpgradeRemote:FireServer(3) end) end
        end
        task.wait(JUMP_UPGRADE_INTERVAL)
    end
end)

task.spawn(function()
    while true do
        if boxesAutoEnabled and not actionBusy then
            actionBusy=true
            local p,o=doPlaceAndOpenBoxes()
            StatusLabel.Text=(p>0 or o>0) and string.format("Auto Boxes ALL | +%d place / +%d open",p,o) or "Auto Boxes waiting..."
            actionBusy=false
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

task.spawn(function()
    while true do
        if autoAcceptGiftsEnabled then
            hookGiftRequestListener()
            local uid=pendingGiftUID or getPendingGiftUIDFromGui()
            if uid~=nil and lastAcceptedGiftUID~=nil and tostring(uid)==tostring(lastAcceptedGiftUID) and os.clock()-lastAcceptedGiftAt<2 then uid=nil end
            if uid~=nil then
                local ok,msg=FireAcceptGift(uid)
                if ok then pendingGiftUID=nil;lastAcceptedGiftUID=uid;lastAcceptedGiftAt=os.clock();GiftStatus.Text="Accepted gift "..tostring(uid)
                elseif msg then GiftStatus.Text="Auto Accept: "..tostring(msg) end
            end
        end
        task.wait(AUTO_ACCEPT_GIFT_INTERVAL)
    end
end)

task.spawn(function()
    while true do
        if giftAllEnabled then
            local target=giftTargetName and Players:FindFirstChild(giftTargetName)
            if not target or target==LocalPlayer then
                GiftStatus.Text="Target left server";setGiftAllState(false);task.wait(.2);continue
            end
            local count=math.max(1,math.floor(tonumber(GiftCountBox.Text) or 10))
            local delay=math.max(0,tonumber(GiftDelayBox.Text) or 1.25)
            local attempted=0
            for _,gift in ipairs(getGiftableInventoryUIDs()) do
                if not giftAllEnabled or attempted>=count then break end
                local key=tostring(gift.uid)
                if not giftInFlight[key] then
                    giftInFlight[key]=true;attempted+=1
                    GiftStatus.Text=string.format("%d/%d | %s | %.2f cash/s",attempted,count,gift.displayName,gift.value)
                    FireGiftSlime(target.Name,gift.uid)
                    if attempted<count then task.wait(delay) end
                end
            end
            setGiftAllState(false)
            GiftStatus.Text=string.format("Gift run complete: %d/%d attempted",attempted,count)
        end
        task.wait(.1)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if invisEnabled then activateCloak() end
end)

-- ============================================
-- PUBLIC COMMANDS
-- ============================================
function stopAll()
    setCollectState(false);setUpgradeState(false);setLuckyState(false)
    setRebirthState(false);setJumpUpgradeState(false);setBoxesAutoState(false)
    setInvisState(false);setGiftAllState(false);setAutoAcceptGiftsState(false)
    deactivateCloak();StatusLabel.Text="All systems stopped"
end

function goToBase()
    return teleportToBase()
end

function countMyFloors()
    local plot=getMyPlot();local stands=plot and plot:FindFirstChild("Stands")
    local n=stands and #stands:GetChildren() or 0
    print("[Floors]",n,"| Place uses every currently free stand/floor")
    return n
end

print("====================================================")
print("[AutoFarm] Alternate Lucky Block fully integrated")
print("Alternate = dropdown | Alternate Lucky Block = exact name")
print("Alternative = rarity | ID = 1263")
print("Place and Place Boxes = ALL available stands/floors | Lucky Boxes highest value first")
print("Commands: stopAll() | goToBase() | countMyFloors()")
print("====================================================")