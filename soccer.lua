-- Combined Script: Auto Collect + Auto Upgrade + Lucky Block Farmer
-- One GUI, Three Toggles - All features in one place
-- Lucky Block: HIGHEST VALUE + MULTI-SELECT TYPES + UNDERGROUND + INVIS FIRST
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================
-- SECTION 1: CONFIGURATION
-- ============================================

-- Auto Collect Config
local COLLECT_DELAY = 0.35
local COLLECT_SCAN = 1.5
local ONLY_WHEN_PADGUI_ENABLED = true

-- Auto Upgrade Config
local UPGRADE_DELAY = 0.18
local UPGRADE_SCAN = 0.9
local MAX_LEVEL = 100

-- ============================================
-- SECTION 1.5: LUCKY BLOCK CONFIG (MULTI-SELECT)
-- ============================================

-- All available Lucky Block types with their display names
local LUCKY_BLOCK_TYPES = {
    "Japan",
    "Icons",
    "Spain",
    "Champions",
    "OG",
    "Exclusive",
    "LIMITED",
    "Divine",
    "Slime God",
    "Secret",
    "Mythic",
    "Legendary",
    "Epic",
    "Rare",
    "Common",
    "Water",
    "Volcanic",
    "Ghost",
    "67",
    "Poison",
    "Cosmic",
    "Rainbow",
    "Planet",  -- Display alias for Cosmic
}

-- Selected types (default: Japan + Icons)
local selectedLuckyBlockTypes = {
    ["Japan"] = true,
    ["Icons"] = true,
}

-- Rarity values for value-based selection
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

-- Lucky Block model name mappings (for detection)
local LUCKY_BLOCK_MODEL_NAMES = {
    ["Japan"] = { ["Japan Lucky Block"] = true },
    ["Icons"] = { ["Icons Lucky Block"] = true },
    ["Spain"] = { ["Spain Lucky Block"] = true },
    ["Champions"] = { ["Champions Lucky Block"] = true },
    ["OG"] = { ["OG Lucky Block"] = true },
    ["Exclusive"] = { ["Exclusive Lucky Block"] = true },
    ["LIMITED"] = { ["Limited Lucky Block"] = true },
    ["Divine"] = { ["Divine Lucky Block"] = true },
    ["Slime God"] = {
        ["Slime God Lucky Block"] = true,
        ["Soccer God Lucky Block"] = true,
    },
    ["Secret"] = { ["Secret Lucky Block"] = true },
    ["Mythic"] = { ["Mythic Lucky Block"] = true },
    ["Legendary"] = { ["Legendary Lucky Block"] = true },
    ["Epic"] = { ["Epic Lucky Block"] = true },
    ["Rare"] = { ["Rare Lucky Block"] = true },
    ["Common"] = { ["Common Lucky Block"] = true },
    ["Water"] = { ["Water Lucky Block"] = true },
    ["Volcanic"] = { ["Volcanic Lucky Block"] = true },
    ["Ghost"] = { ["Ghost Lucky Block"] = true },
    ["67"] = { ["67 Lucky Block"] = true },
    ["Poison"] = { ["Poison Lucky Block"] = true },
    ["Cosmic"] = { ["Cosmic Lucky Block"] = true },
    ["Planet"] = {
        ["Cosmic Lucky Block"] = true,
        ["Planet Lucky Block"] = true,
    },
    ["Rainbow"] = { ["Rainbow Lucky Block"] = true },
}

-- ============================================
-- SECTION 2: REMOTE FINDING
-- ============================================

local function findRemote(namePart)
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and string.find(string.lower(v.Name), string.lower(namePart), 1, true) then
            return v
        end
    end
    return nil
end

local function findExactRemote(name)
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name == name then
            return v
        end
    end
    return nil
end

local CollectRemote = findRemote("Collect Earnings")
local UpgradeRemote = findRemote("Upgrade Slime")
local PickupRemote = findExactRemote("Pickup Slime")

if not CollectRemote then warn("[Auto] Collect Earnings remote not found") end
if not UpgradeRemote then warn("[Auto] Upgrade Slime remote not found") end

-- ============================================
-- SECTION 3: AUTO COLLECT LOGIC
-- ============================================

local function getAllCollectPads()
    local pads = {}
    local seen = {}
    local function add(pad)
        if pad and pad:IsA("Model") and not seen[pad] then
            seen[pad] = true
            table.insert(pads, pad)
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Top") then
            local padGui = obj.Top:FindFirstChild("PadGui")
            if padGui and (not ONLY_WHEN_PADGUI_ENABLED or padGui.Enabled) then
                add(obj)
            end
        end
        if obj.Name == "CollectPads" and obj:IsA("Folder") then
            for _, pad in ipairs(obj:GetChildren()) do
                if pad:IsA("Model") and pad:FindFirstChild("Top") then
                    local padGui = pad.Top:FindFirstChild("PadGui")
                    if padGui and (not ONLY_WHEN_PADGUI_ENABLED or padGui.Enabled) then
                        add(pad)
                    end
                end
            end
        end
    end
    return pads
end

-- ============================================
-- SECTION 4: AUTO UPGRADE LOGIC
-- ============================================

local function getUpgradeCost(sellPrice, level)
    if type(sellPrice) ~= "number" or type(level) ~= "number" then
        return math.huge
    end
    local cost = sellPrice * 2 * (1.3 ^ (level - 1))
    if cost ~= cost then return math.huge end
    return math.round(cost)
end

local function getCash()
    if _G._Lib and _G._Lib.Data then
        local data = _G._Lib.Data:Get()
        if data and type(data.Cash) == "number" then
            return data.Cash
        end
    end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        local cash = ls:FindFirstChild("Cash") or ls:FindFirstChild("Money")
        if cash then return cash.Value end
    end
    return 0
end

local function getStandInfo(stand)
    local level = stand:GetAttribute("level") or 1
    if level >= MAX_LEVEL then return nil end
    local sellPrice = nil
    local slimeId = nil
    if _G._Lib and _G._Lib.Data and _G._Lib.Database then
        local data = _G._Lib.Data:Get()
        if data and data.PlotSlimes then
            local entry = data.PlotSlimes[stand.Name] or data.PlotSlimes[tonumber(stand.Name)]
            if entry then
                slimeId = entry.id or entry.Id or entry.slimeId or entry.Name
                if type(entry.SellPrice) == "number" then
                    sellPrice = entry.SellPrice
                elseif type(entry.MoneyPerSecond) == "number" then
                    sellPrice = math.round(entry.MoneyPerSecond * 4)
                end
            end
        end
        if not sellPrice and slimeId and _G._Lib.Database.Slimes then
            local def = _G._Lib.Database.Slimes[slimeId]
            if def then
                sellPrice = def.SellPrice or (def.MoneyPerSecond and math.round(def.MoneyPerSecond * 4))
            end
        end
    end
    if not sellPrice then
        sellPrice = stand:GetAttribute("SellPrice")
            or stand:GetAttribute("sellPrice")
            or (stand:GetAttribute("MoneyPerSecond") and math.round(stand:GetAttribute("MoneyPerSecond") * 4))
    end
    if not sellPrice then
        local live = workspace:FindFirstChild("Live")
        local playerSlimes = live and live:FindFirstChild("PlayerSlimes")
        local myFolder = playerSlimes and playerSlimes:FindFirstChild(LocalPlayer.Name)
        local model = myFolder and myFolder:FindFirstChild(tostring(stand.Name))
        if model then
            sellPrice = model:GetAttribute("SellPrice")
                or model:GetAttribute("sellPrice")
                or (model:GetAttribute("MoneyPerSecond") and math.round(model:GetAttribute("MoneyPerSecond") * 4))
        end
    end
    if not sellPrice or sellPrice <= 0 then return nil end
    return {
        stand = stand,
        id = stand.Name,
        level = level,
        cost = getUpgradeCost(sellPrice, level)
    }
end

local function getPrioritizedUpgrades()
    local list = {}
    local seen = {}
    local function scanPlot(plot)
        if not plot then return end
        local standsFolder = plot:FindFirstChild("Stands")
        if not standsFolder then return end
        for _, stand in ipairs(standsFolder:GetChildren()) do
            if stand:IsA("Model") and not seen[stand.Name] then
                local info = getStandInfo(stand)
                if info then
                    seen[stand.Name] = true
                    table.insert(list, info)
                end
            end
        end
    end
    if _G.MyPlot then scanPlot(_G.MyPlot) end
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local owner = plot:FindFirstChild("owner")
            if owner and owner.Value == LocalPlayer.Name then
                scanPlot(plot)
            end
        end
    end
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "Stands" and obj:IsA("Folder") then
            local plot = obj.Parent
            local owner = plot and plot:FindFirstChild("owner")
            if owner and owner.Value == LocalPlayer.Name then
                scanPlot(plot)
            end
        end
    end
    table.sort(list, function(a, b) return a.cost < b.cost end)
    return list
end

-- ============================================
-- SECTION 5: INVISIBILITY
-- ============================================

local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function findCloakTool()
    local function scan(bag)
        if not bag then return nil end
        for _, item in ipairs(bag:GetChildren()) do
            if item:IsA("Tool") then
                local n = string.lower(item.Name)
                if string.find(n, "invisibility") or string.find(n, "cloak") or string.find(n, "invis") then
                    return item
                end
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
                if part:GetAttribute("_OrigTrans") == nil then
                    part:SetAttribute("_OrigTrans", part.Transparency)
                end
                part.Transparency = 1
            else
                local orig = part:GetAttribute("_OrigTrans")
                if orig ~= nil then
                    part.Transparency = orig
                    part:SetAttribute("_OrigTrans", nil)
                end
            end
        elseif part:IsA("Decal") or part:IsA("Texture") then
            if on then
                if part:GetAttribute("_OrigTrans") == nil then
                    part:SetAttribute("_OrigTrans", part.Transparency)
                end
                part.Transparency = 1
            else
                local orig = part:GetAttribute("_OrigTrans")
                if orig ~= nil then
                    part.Transparency = orig
                    part:SetAttribute("_OrigTrans", nil)
                end
            end
        end
    end
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") then
            local handle = acc:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                if on then
                    if handle:GetAttribute("_OrigTrans") == nil then
                        handle:SetAttribute("_OrigTrans", handle.Transparency)
                    end
                    handle.Transparency = 1
                else
                    local orig = handle:GetAttribute("_OrigTrans")
                    if orig ~= nil then
                        handle.Transparency = orig
                        handle:SetAttribute("_OrigTrans", nil)
                    end
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
        if tool.Parent ~= char then
            pcall(function() tool.Parent = char end)
        end
        task.wait(0.15)
    end
    local canAct = tool:FindFirstChild("CanActivate")
    if canAct and canAct:IsA("BoolValue") then
        canAct.Value = true
    end
    pcall(function() tool:Activate() end)
    setLocalInvisible(true)
    return true
end

local function deactivateCloak()
    setLocalInvisible(false)
    local hum = getHumanoid()
    if hum then
        pcall(function() hum:UnequipTools() end)
    end
end

-- ============================================
-- SECTION 6: LUCKY BLOCK LOGIC (UPDATED)
-- ============================================

local totalCollected = 0
local luckyBlockBusy = false

local function getRoot()
    local c = LocalPlayer.Character
    if not c or not c.Parent then return nil end
    return c:FindFirstChild("HumanoidRootPart")
end

local function getMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end

    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:FindFirstChild("owner")
        if owner and owner:IsA("StringValue") and owner.Value == LocalPlayer.Name then
            return plot
        end
    end

    return nil
end

local function teleportToBase()
    local root = getRoot()
    if not root then return false end

    if _G.MyPlot and _G.MyPlot.Base and _G.MyPlot.Base.Teleport then
        local teleport = _G.MyPlot.Base.Teleport
        if teleport.WorldCFrame then
            root.CFrame = teleport.WorldCFrame + Vector3.new(0, 3, 0)
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            return true
        end
    end

    local plot = getMyPlot()
    if plot then
        local base = plot:FindFirstChild("Base")
        if base then
            local teleport = base:FindFirstChild("Teleport")
            if teleport and teleport:IsA("Attachment") and teleport.WorldCFrame then
                root.CFrame = teleport.WorldCFrame + Vector3.new(0, 3, 0)
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                return true
            end
           
            local basePart = base:FindFirstChildWhichIsA("BasePart")
            if basePart then
                root.CFrame = basePart.CFrame + Vector3.new(0, 5, 0)
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                return true
            end
        end
    end

    return false
end

-- Returns the HIGHEST VALUE Lucky Block from selected types
local function getTargetLuckyBlock()
    local live = workspace:FindFirstChild("Live")
    if not live then return nil end
    local slimes = live:FindFirstChild("Slimes")
    if not slimes then return nil end

    local best = nil
    local bestValue = -math.huge

    for _, model in ipairs(slimes:GetChildren()) do
        if model:IsA("Model") and not model:GetAttribute("Carrying") then
            local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if not primary then continue end

            local modelName = tostring(model.Name)
            local matchedType = nil
            local value = 0

            -- Check which selected type this block matches
            for selectedType in pairs(selectedLuckyBlockTypes) do
                local allowedNames = LUCKY_BLOCK_MODEL_NAMES[selectedType]
                if allowedNames and allowedNames[modelName] == true then
                    matchedType = selectedType
                    value = RARITY_VALUE[selectedType] or 0
                    break
                end
            end

            if matchedType then
                -- Use MoneyPerSecond attribute as value if available (higher priority)
                local mps = model:GetAttribute("MoneyPerSecond") or model:GetAttribute("Value")
                if mps and tonumber(mps) then
                    value = tonumber(mps)
                end

                -- Find the interaction prompt
                local prompt = nil
                for _, d in ipairs(model:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled then
                        local actionText = string.lower(tostring(d.ActionText or ""))
                        if string.find(actionText, "steal") or string.find(actionText, "open") or 
                           string.find(actionText, "pick") or string.find(actionText, "take") then
                            prompt = d
                            break
                        end
                        if not prompt then
                            prompt = d
                        end
                    end
                end

                -- Keep the highest value block
                if value > bestValue then
                    bestValue = value
                    best = {
                        name = modelName,
                        type = matchedType,
                        value = value,
                        part = primary,
                        prompt = prompt,
                        model = model,
                    }
                end
            end
        end
    end

    return best
end

local function attemptSteal(prompt)
    if not prompt then return false end

    local holdDuration = prompt.HoldDuration or 0

    -- Try fireproximityprompt first (executor function)
    if typeof(fireproximityprompt) == "function" then
        local success, err = pcall(function()
            fireproximityprompt(prompt)
        end)
        if success then
            task.wait(holdDuration + 0.5)
            return true
        end
    end

    -- Fallback: Trigger the prompt directly
    local success, err = pcall(function()
        prompt:Trigger()
    end)

    if success then
        task.wait(holdDuration + 0.5)
        return true
    end

    return false
end

-- ============================================
-- SECTION 7: GUI CREATION
-- ============================================

pcall(function()
    local old = PlayerGui:FindFirstChild("AutoFarmGui")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoFarmGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 270, 0, 420)
MainFrame.Position = UDim2.new(0, 20, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BackgroundTransparency = 0.05
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = MainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(60, 60, 70)
mainStroke.Thickness = 1.5
mainStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 270, 0, 30)
Title.Position = UDim2.new(0, 0, 0, 5)
Title.BackgroundTransparency = 1
Title.Text = "Auto Farm Control"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local function createButton(name, yOffset, text, color)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 240, 0, 36)
    btn.Position = UDim2.new(0, 15, 0, yOffset)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = color or Color3.fromRGB(255, 90, 90)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.Parent = MainFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 80, 90)
    stroke.Thickness = 1.5
    stroke.Parent = btn
    
    return btn
end

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0, 240, 0, 50)
StatusLabel.Position = UDim2.new(0, 15, 0, 360)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Ready"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.TextWrapped = true
StatusLabel.Parent = MainFrame

local CollectBtn = createButton("CollectToggle", 40, "Auto Collect: OFF", Color3.fromRGB(255, 90, 90))
local UpgradeBtn = createButton("UpgradeToggle", 82, "Auto Upgrade: OFF", Color3.fromRGB(255, 90, 90))
local LuckyBtn = createButton("LuckyToggle", 124, "Lucky Block: OFF", Color3.fromRGB(255, 90, 90))

-- ============================================
-- SECTION 7.5: LUCKY TYPE MULTI-SELECT DROPDOWN
-- ============================================

local LuckyTypeDropBtn = Instance.new("TextButton")
LuckyTypeDropBtn.Name = "LuckyTypeDrop"
LuckyTypeDropBtn.Size = UDim2.new(0, 240, 0, 32)
LuckyTypeDropBtn.Position = UDim2.new(0, 15, 0, 160)
LuckyTypeDropBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 25)
LuckyTypeDropBtn.BorderSizePixel = 0
LuckyTypeDropBtn.Text = "▼ Lucky Types: Japan, Icons"
LuckyTypeDropBtn.TextColor3 = Color3.fromRGB(255, 214, 125)
LuckyTypeDropBtn.TextSize = 12
LuckyTypeDropBtn.Font = Enum.Font.GothamBold
LuckyTypeDropBtn.Parent = MainFrame
Instance.new("UICorner", LuckyTypeDropBtn).CornerRadius = UDim.new(0, 8)
local typeDropStroke = Instance.new("UIStroke", LuckyTypeDropBtn)
typeDropStroke.Color = Color3.fromRGB(100, 80, 50)
typeDropStroke.Thickness = 1.5

local LuckyTypeDropList = Instance.new("ScrollingFrame")
LuckyTypeDropList.Name = "LuckyTypeDropList"
LuckyTypeDropList.Size = UDim2.new(0, 240, 0, 160)
LuckyTypeDropList.Position = UDim2.new(0, 15, 0, 195)
LuckyTypeDropList.BackgroundColor3 = Color3.fromRGB(30, 28, 22)
LuckyTypeDropList.BorderSizePixel = 0
LuckyTypeDropList.Visible = false
LuckyTypeDropList.ScrollBarThickness = 4
LuckyTypeDropList.ZIndex = 50
LuckyTypeDropList.Parent = MainFrame
Instance.new("UICorner", LuckyTypeDropList).CornerRadius = UDim.new(0, 8)

local luckyTypeListLayout = Instance.new("UIListLayout")
luckyTypeListLayout.SortOrder = Enum.SortOrder.LayoutOrder
luckyTypeListLayout.Parent = LuckyTypeDropList

-- Track checkbox button references
local typeCheckboxes = {}

-- Function to update the dropdown button text
local function updateLuckyTypeButtonText()
    local selected = {}
    for typeName, isSelected in pairs(selectedLuckyBlockTypes) do
        if isSelected then
            table.insert(selected, typeName)
        end
    end
    if #selected == 0 then
        LuckyTypeDropBtn.Text = "▼ Lucky Types: (None Selected)"
    else
        LuckyTypeDropBtn.Text = "▼ Lucky Types: " .. table.concat(selected, ", ")
    end
end

-- Build the checkbox list
for _, typeName in ipairs(LUCKY_BLOCK_TYPES) do
    local item = Instance.new("TextButton")
    item.Size = UDim2.new(1, -4, 0, 26)
    item.BackgroundColor3 = Color3.fromRGB(40, 36, 28)
    item.BorderSizePixel = 0
    item.Text = "  ☐ " .. typeName
    item.TextColor3 = Color3.fromRGB(230, 220, 200)
    item.TextSize = 12
    item.Font = Enum.Font.Gotham
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.ZIndex = 51
    item.Parent = LuckyTypeDropList
    
    typeCheckboxes[typeName] = item
    
    item.MouseButton1Click:Connect(function()
        -- Toggle selection
        local current = selectedLuckyBlockTypes[typeName] or false
        selectedLuckyBlockTypes[typeName] = not current
        
        -- Update checkbox text
        if selectedLuckyBlockTypes[typeName] then
            item.Text = "  ☑ " .. typeName
            item.TextColor3 = Color3.fromRGB(255, 230, 150)
        else
            item.Text = "  ☐ " .. typeName
            item.TextColor3 = Color3.fromRGB(230, 220, 200)
        end
        
        updateLuckyTypeButtonText()
        
        -- Update status
        local selected = {}
        for t, s in pairs(selectedLuckyBlockTypes) do
            if s then table.insert(selected, t) end
        end
        if #selected > 0 then
            StatusLabel.Text = "Lucky Types: " .. table.concat(selected, ", ")
        else
            StatusLabel.Text = "WARNING: No Lucky Block types selected!"
        end
    end)
end

-- Set initial checkbox states
for typeName, isSelected in pairs(selectedLuckyBlockTypes) do
    if isSelected and typeCheckboxes[typeName] then
        typeCheckboxes[typeName].Text = "  ☑ " .. typeName
        typeCheckboxes[typeName].TextColor3 = Color3.fromRGB(255, 230, 150)
    end
end
updateLuckyTypeButtonText()

LuckyTypeDropBtn.MouseButton1Click:Connect(function()
    LuckyTypeDropList.Visible = not LuckyTypeDropList.Visible
    if LuckyTypeDropList.Visible then
        LuckyTypeDropBtn.Text = "▲ " .. LuckyTypeDropBtn.Text:sub(3)
    else
        LuckyTypeDropBtn.Text = "▼ " .. LuckyTypeDropBtn.Text:sub(3)
    end
end)

-- ============================================
-- SECTION 8: STATE MANAGEMENT
-- ============================================

local collectEnabled = false
local upgradeEnabled = false
local luckyEnabled = false

local function setCollectState(on)
    collectEnabled = on
    if on then
        CollectBtn.Text = "Auto Collect: ON"
        CollectBtn.TextColor3 = Color3.fromRGB(80, 255, 120)
        CollectBtn.BackgroundColor3 = Color3.fromRGB(30, 55, 40)
    else
        CollectBtn.Text = "Auto Collect: OFF"
        CollectBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
        CollectBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    end
end

local function setUpgradeState(on)
    upgradeEnabled = on
    if on then
        UpgradeBtn.Text = "Auto Upgrade: ON"
        UpgradeBtn.TextColor3 = Color3.fromRGB(80, 180, 255)
        UpgradeBtn.BackgroundColor3 = Color3.fromRGB(25, 45, 70)
    else
        UpgradeBtn.Text = "Auto Upgrade: OFF"
        UpgradeBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
        UpgradeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    end
end

local function setLuckyState(on)
    luckyEnabled = on
    if on then
        LuckyBtn.Text = "Lucky Block: ON"
        LuckyBtn.TextColor3 = Color3.fromRGB(255, 200, 80)
        LuckyBtn.BackgroundColor3 = Color3.fromRGB(60, 45, 20)
        totalCollected = 0
        local selected = {}
        for t, s in pairs(selectedLuckyBlockTypes) do
            if s then table.insert(selected, t) end
        end
        StatusLabel.Text = "Lucky Block: Targeting " .. (#selected > 0 and table.concat(selected, ", ") or "NO TYPES SELECTED!")
    else
        LuckyBtn.Text = "Lucky Block: OFF"
        LuckyBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
        LuckyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        StatusLabel.Text = "Ready"
        luckyBlockBusy = false
    end
end

CollectBtn.MouseButton1Click:Connect(function()
    setCollectState(not collectEnabled)
end)
UpgradeBtn.MouseButton1Click:Connect(function()
    setUpgradeState(not upgradeEnabled)
end)
LuckyBtn.MouseButton1Click:Connect(function()
    setLuckyState(not luckyEnabled)
end)

-- ============================================
-- SECTION 9: AUTO COLLECT LOOP
-- ============================================

task.spawn(function()
    while true do
        if collectEnabled and CollectRemote then
            local pads = getAllCollectPads()
            for _, pad in ipairs(pads) do
                if not collectEnabled then break end
                local id = pad.Name
                if id and id ~= "" then
                    pcall(function()
                        CollectRemote:FireServer(id)
                    end)
                end
                task.wait(COLLECT_DELAY)
            end
        end
        task.wait(COLLECT_SCAN)
    end
end)

-- ============================================
-- SECTION 10: AUTO UPGRADE LOOP
-- ============================================

task.spawn(function()
    while true do
        if upgradeEnabled and UpgradeRemote then
            local upgrades = getPrioritizedUpgrades()
            local upgraded = 0
            for _, info in ipairs(upgrades) do
                if not upgradeEnabled then break end
                local cash = getCash()
                if info.cost <= cash then
                    pcall(function()
                        UpgradeRemote:FireServer(info.id)
                    end)
                    upgraded = upgraded + 1
                    StatusLabel.Text = string.format("Upgraded %s (Lv %d)\nCost: $%s", info.id, info.level, tostring(info.cost))
                    task.wait(UPGRADE_DELAY)
                else
                    break
                end
            end
            if upgraded == 0 and upgradeEnabled then
                if not string.find(StatusLabel.Text, "Lucky") and not string.find(StatusLabel.Text, "Collect") then
                    StatusLabel.Text = "Waiting for cash / no upgrades..."
                end
            end
        else
            if not upgradeEnabled and not collectEnabled and not luckyEnabled then
                StatusLabel.Text = "Ready"
            end
        end
        task.wait(UPGRADE_SCAN)
    end
end)

-- ============================================
-- SECTION 11: LUCKY BLOCK LOOP (UPDATED)
-- ============================================

task.spawn(function()
    while true do
        if luckyEnabled and not luckyBlockBusy then
            luckyBlockBusy = true

            -- Check if any types are selected
            local hasTypes = false
            for _, s in pairs(selectedLuckyBlockTypes) do
                if s then hasTypes = true break end
            end
            
            if not hasTypes then
                StatusLabel.Text = "ERROR: No Lucky Block types selected!"
                luckyBlockBusy = false
                task.wait(1)
                continue
            end

            -- Find the highest value target block
            local block = getTargetLuckyBlock()
           
            if not block then
                local selected = {}
                for t, s in pairs(selectedLuckyBlockTypes) do
                    if s then table.insert(selected, t) end
                end
                StatusLabel.Text = string.format("No target blocks found | Total: %d | Types: %s", 
                    totalCollected, table.concat(selected, ", "))
                luckyBlockBusy = false
                task.wait(0.5)
                continue
            end
           
            local root = getRoot()
            if not root then
                luckyBlockBusy = false
                task.wait(0.5)
                continue
            end

            -- STEP 1: Activate invisibility BEFORE teleporting
            StatusLabel.Text = "Activating invis..."
            local invisOk = activateCloak()
            if invisOk then
                StatusLabel.Text = "Invis ON → teleporting..."
            else
                StatusLabel.Text = "No cloak tool found (still going)..."
            end
            task.wait(0.25)
           
            -- STEP 2: Teleport 1 stud UNDER the lucky block
            if block.part then
                local targetPos = block.part.CFrame * CFrame.new(0, -1, 0)
                root.CFrame = targetPos
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end

            -- STEP 3: Hold position with BodyVelocity
            local floatBV = Instance.new("BodyVelocity")
            floatBV.Name = "LuckyFloat"
            floatBV.Velocity = Vector3.new(0, 0, 0)
            floatBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            floatBV.P = 1250
            floatBV.Parent = root
           
            StatusLabel.Text = string.format("Underground at: %s (value: %s)", block.type, tostring(block.value))
            task.wait(0.2)
           
            -- STEP 4: Attempt to steal
            local success = false
            if block.prompt then
                StatusLabel.Text = string.format("Stealing: %s...", block.type)
                success = attemptSteal(block.prompt)
            else
                StatusLabel.Text = "✗ No prompt found!"
            end

            -- STEP 5: Clean up
            if floatBV and floatBV.Parent then
                floatBV:Destroy()
            end
            if root and root.Parent then
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
           
            -- STEP 6: Report result
            if success then
                totalCollected = totalCollected + 1
                StatusLabel.Text = string.format("✓ Stole %s! (#%d)", block.type, totalCollected)
                print(string.format("[LuckyBlock] Stole %s! Total: %d", block.type, totalCollected))
               
                StatusLabel.Text = string.format("Returning to base... (#%d)", totalCollected)
                task.wait(0.3)
            else
                StatusLabel.Text = "✗ Failed to steal!"
                task.wait(0.3)
            end
           
            -- STEP 7: Teleport back to base
            local teleportSuccess = teleportToBase()
            if teleportSuccess then
                StatusLabel.Text = string.format("✓ At base! (#%d)", totalCollected)
                print(string.format("[LuckyBlock] Teleported to base. Total: %d", totalCollected))
            else
                StatusLabel.Text = "✗ Teleport failed!"
            end
           
            task.wait(0.5)
            luckyBlockBusy = false
        end
       
        task.wait(0.1)
    end
end)

-- ============================================
-- SECTION 12: EMERGENCY FUNCTIONS
-- ============================================

local function stopAll()
    setCollectState(false)
    setUpgradeState(false)
    setLuckyState(false)
    deactivateCloak()
    StatusLabel.Text = "All systems stopped"
    print("[AutoFarm] All systems stopped")
end

local function goToBase()
    local success = teleportToBase()
    if success then
        StatusLabel.Text = "✓ Teleported to base!"
        print("[AutoFarm] Teleported to base")
    else
        StatusLabel.Text = "✗ Teleport failed!"
        print("[AutoFarm] Teleport failed")
    end
    return success
end

local function getStats()
    local stats = string.format("Total Lucky Blocks stolen: %d", totalCollected)
    local selected = {}
    for t, s in pairs(selectedLuckyBlockTypes) do
        if s then table.insert(selected, t) end
    end
    stats = stats .. "\nTargeting: " .. table.concat(selected, ", ")
    print(stats)
    return stats
end

-- ============================================
-- SECTION 13: INITIALIZATION
-- ============================================

print("========================================")
print("[AutoFarm] ALL SYSTEMS LOADED")
print("[AutoFarm] Player: " .. LocalPlayer.Name)
print("========================================")
print("FEATURES:")
print(" 1. Auto Collect - Collects earnings from pads")
print(" 2. Auto Upgrade - Upgrades slimes (cheapest first)")
print(" 3. Lucky Block - MULTI-SELECT types (checkboxes)")
print("    • Click 'Lucky Types' to choose which blocks to steal")
print("    • Selects the HIGHEST VALUE block from chosen types")
print("    • Activates Invis Cloak before teleport")
print("    • Teleports 1 stud underground")
print("    • Holds position with BodyVelocity")
print("========================================")
print("COMMANDS:")
print(" stopAll() - Stop all systems + deactivate cloak")
print(" goToBase() - Teleport to base")
print(" getStats() - Show total collected + active types")
print("========================================")
