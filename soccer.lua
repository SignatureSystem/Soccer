-- ============================================
-- LUCKY BLOCK TYPE FILTER (MULTI-SELECT)
-- Checkboxes for each type instead of single dropdown
-- ============================================

-- UPDATED: Full Lucky Block options including Japan
local LUCKY_BLOCK_OPTIONS = {
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

-- Track which Lucky Block types are selected
local selectedLuckyBlockTypes = {}
for _, typeName in ipairs(LUCKY_BLOCK_OPTIONS) do
    selectedLuckyBlockTypes[typeName] = true  -- Default: All selected
end

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

-- Replace single LuckyTypeDropBtn with a multi-select dropdown
local LuckyTypeDropBtn = Instance.new("TextButton")
LuckyTypeDropBtn.Name = "LuckyTypeDrop"
LuckyTypeDropBtn.Size = UDim2.new(0, 220, 0, 30)
LuckyTypeDropBtn.Position = UDim2.new(0, 15, 0, 166)
LuckyTypeDropBtn.BackgroundColor3 = Color3.fromRGB(58, 45, 22)
LuckyTypeDropBtn.BorderSizePixel = 0
LuckyTypeDropBtn.Text = "▼ Lucky Types: ALL"
LuckyTypeDropBtn.TextColor3 = Color3.fromRGB(255, 214, 125)
LuckyTypeDropBtn.TextSize = 11
LuckyTypeDropBtn.Font = Enum.Font.GothamBold
LuckyTypeDropBtn.ZIndex = 70
LuckyTypeDropBtn.Parent = MainFrame
Instance.new("UICorner", LuckyTypeDropBtn).CornerRadius = UDim.new(0, 8)

LuckyTypeDropList = Instance.new("ScrollingFrame")
LuckyTypeDropList.Name = "LuckyTypeDropList"
LuckyTypeDropList.Size = UDim2.new(0, 220, 0, 240)
LuckyTypeDropList.Position = UDim2.new(0, 15, 0, 198)
LuckyTypeDropList.BackgroundColor3 = Color3.fromRGB(35, 28, 18)
LuckyTypeDropList.BorderSizePixel = 0
LuckyTypeDropList.Visible = false
LuckyTypeDropList.ScrollBarThickness = 4
LuckyTypeDropList.CanvasSize = UDim2.new(0, 0, 0, #LUCKY_BLOCK_OPTIONS * 28)
LuckyTypeDropList.ZIndex = 80
LuckyTypeDropList.Parent = MainFrame
Instance.new("UICorner", LuckyTypeDropList).CornerRadius = UDim.new(0, 7)

local luckyTypeListLayout = Instance.new("UIListLayout")
luckyTypeListLayout.SortOrder = Enum.SortOrder.LayoutOrder
luckyTypeListLayout.Parent = LuckyTypeDropList

-- Helper to update the button text
local function updateLuckyTypeButtonText()
    local selected = {}
    for typeName, isSelected in pairs(selectedLuckyBlockTypes) do
        if isSelected then
            table.insert(selected, typeName)
        end
    end
    
    if #selected == 0 then
        LuckyTypeDropBtn.Text = "▼ Lucky Types: NONE"
    elseif #selected == #LUCKY_BLOCK_OPTIONS then
        LuckyTypeDropBtn.Text = "▼ Lucky Types: ALL"
    elseif #selected <= 3 then
        LuckyTypeDropBtn.Text = "▼ Lucky Types: " .. table.concat(selected, ", ")
    else
        LuckyTypeDropBtn.Text = "▼ Lucky Types: " .. #selected .. " selected"
    end
end

-- Create checkbox items for each Lucky Block type
for i, boxType in ipairs(LUCKY_BLOCK_OPTIONS) do
    local itemFrame = Instance.new("Frame")
    itemFrame.Size = UDim2.new(1, -4, 0, 26)
    itemFrame.BackgroundColor3 = Color3.fromRGB(52, 40, 23)
    itemFrame.BorderSizePixel = 0
    itemFrame.BackgroundTransparency = 0.5
    itemFrame.LayoutOrder = i
    itemFrame.ZIndex = 81
    itemFrame.Parent = LuckyTypeDropList
    
    local checkbox = Instance.new("TextButton")
    checkbox.Size = UDim2.new(0, 20, 0, 20)
    checkbox.Position = UDim2.new(0, 4, 0.5, -10)
    checkbox.BackgroundColor3 = selectedLuckyBlockTypes[boxType] and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(40, 40, 50)
    checkbox.BorderSizePixel = 1
    checkbox.BorderColor3 = Color3.fromRGB(150, 150, 170)
    checkbox.Text = selectedLuckyBlockTypes[boxType] and "✓" or ""
    checkbox.TextColor3 = Color3.fromRGB(255, 255, 255)
    checkbox.TextSize = 14
    checkbox.Font = Enum.Font.GothamBold
    checkbox.ZIndex = 82
    checkbox.Parent = itemFrame
    Instance.new("UICorner", checkbox).CornerRadius = UDim.new(0, 3)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -28, 1, 0)
    label.Position = UDim2.new(0, 28, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = boxType
    label.TextColor3 = Color3.fromRGB(244, 229, 195)
    label.TextSize = 11
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 82
    label.Parent = itemFrame
    
    local function toggleCheckbox()
        selectedLuckyBlockTypes[boxType] = not selectedLuckyBlockTypes[boxType]
        checkbox.BackgroundColor3 = selectedLuckyBlockTypes[boxType] and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(40, 40, 50)
        checkbox.Text = selectedLuckyBlockTypes[boxType] and "✓" or ""
        updateLuckyTypeButtonText()
    end
    
    checkbox.MouseButton1Click:Connect(toggleCheckbox)
    label.MouseButton1Click:Connect(toggleCheckbox)
    itemFrame.MouseButton1Click:Connect(toggleCheckbox)
end

-- Update button text on creation
updateLuckyTypeButtonText()

LuckyTypeDropBtn.MouseButton1Click:Connect(function()
    UpgradeRarityDropList.Visible = false
    UpgradeMutationDropList.Visible = false
    if PickupRangeDropList then
        PickupRangeDropList.Visible = false
    end
    LuckyTypeDropList.Visible = not LuckyTypeDropList.Visible
end)

-- Helper function to check if a Lucky Block type is selected
local function isLuckyTypeSelected(typeName)
    -- If no types selected, return false
    local hasAny = false
    for _, isSelected in pairs(selectedLuckyBlockTypes) do
        if isSelected then hasAny = true; break end
    end
    if not hasAny then return false end
    
    -- If the specific type is selected, return true
    return selectedLuckyBlockTypes[typeName] == true
end

-- ============================================
-- SELECT ALL / DESELECT ALL BUTTONS FOR LUCKY TYPES
-- ============================================
local SelectAllLuckyBtn = Instance.new("TextButton")
SelectAllLuckyBtn.Name = "SelectAllLuckyBtn"
SelectAllLuckyBtn.Size = UDim2.new(0, 108, 0, 24)
SelectAllLuckyBtn.Position = UDim2.new(0, 15, 0, 442)  -- Adjust position as needed
SelectAllLuckyBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
SelectAllLuckyBtn.BorderSizePixel = 0
SelectAllLuckyBtn.Text = "Select All"
SelectAllLuckyBtn.TextColor3 = Color3.fromRGB(120, 255, 150)
SelectAllLuckyBtn.TextSize = 10
SelectAllLuckyBtn.Font = Enum.Font.GothamBold
SelectAllLuckyBtn.ZIndex = 70
SelectAllLuckyBtn.Parent = MainFrame
Instance.new("UICorner", SelectAllLuckyBtn).CornerRadius = UDim.new(0, 6)

local DeselectAllLuckyBtn = Instance.new("TextButton")
DeselectAllLuckyBtn.Name = "DeselectAllLuckyBtn"
DeselectAllLuckyBtn.Size = UDim2.new(0, 108, 0, 24)
DeselectAllLuckyBtn.Position = UDim2.new(0, 127, 0, 442)
DeselectAllLuckyBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
DeselectAllLuckyBtn.BorderSizePixel = 0
DeselectAllLuckyBtn.Text = "Deselect All"
DeselectAllLuckyBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
DeselectAllLuckyBtn.TextSize = 10
DeselectAllLuckyBtn.Font = Enum.Font.GothamBold
DeselectAllLuckyBtn.ZIndex = 70
DeselectAllLuckyBtn.Parent = MainFrame
Instance.new("UICorner", DeselectAllLuckyBtn).CornerRadius = UDim.new(0, 6)

SelectAllLuckyBtn.MouseButton1Click:Connect(function()
    for typeName in pairs(selectedLuckyBlockTypes) do
        selectedLuckyBlockTypes[typeName] = true
    end
    -- Update all checkbox visuals
    for _, child in ipairs(LuckyTypeDropList:GetChildren()) do
        if child:IsA("Frame") then
            local checkbox = child:FindFirstChild("TextButton")
            if checkbox then
                checkbox.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
                checkbox.Text = "✓"
            end
        end
    end
    updateLuckyTypeButtonText()
end)

DeselectAllLuckyBtn.MouseButton1Click:Connect(function()
    for typeName in pairs(selectedLuckyBlockTypes) do
        selectedLuckyBlockTypes[typeName] = false
    end
    -- Update all checkbox visuals
    for _, child in ipairs(LuckyTypeDropList:GetChildren()) do
        if child:IsA("Frame") then
            local checkbox = child:FindFirstChild("TextButton")
            if checkbox then
                checkbox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
                checkbox.Text = ""
            end
        end
    end
    updateLuckyTypeButtonText()
end)

-- ============================================
-- UPDATED LUCKY BLOCK COLLECTION FUNCTIONS
-- ============================================

-- Check if a model name matches any selected Lucky Block type
local function matchesSelectedLuckyTypes(modelName)
    -- If no types selected, don't match anything
    local hasAny = false
    for _, isSelected in pairs(selectedLuckyBlockTypes) do
        if isSelected then hasAny = true; break end
    end
    if not hasAny then return false end
    
    for typeName, isSelected in pairs(selectedLuckyBlockTypes) do
        if isSelected then
            local allowedNames = LUCKY_BLOCK_MODEL_NAMES[typeName]
            if allowedNames and allowedNames[modelName] == true then
                return true
            end
        end
    end
    return false
end

-- Updated getTargetLuckyBlock to use multi-select
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
            
            -- Check if this model matches any selected type
            if matchesSelectedLuckyTypes(modelName) then
                local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                if not primary then continue end

                local value = tonumber(model:GetAttribute("Value")) or tonumber(model:GetAttribute("MoneyPerSecond")) or 0
                local distance = root and (root.Position - primary.Position).Magnitude or math.huge

                local prompt = nil
                for _, d in ipairs(model:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled then
                        local at = string.lower(tostring(d.ActionText or ""))
                        if at:find("steal", 1, true) or at:find("open", 1, true) or at:find("pick", 1, true) or at:find("take", 1, true) or not prompt then
                            prompt = d
                            if at:find("steal", 1, true) or at:find("open", 1, true) or at:find("pick", 1, true) or at:find("take", 1, true) then
                                break
                            end
                        end
                    end
                end

                -- Prefer highest value, then nearest
                if value > bestValue or (value == bestValue and distance < bestDistance) then
                    bestValue = value
                    bestDistance = distance
                    best = {
                        name = modelName,
                        type = "Multi-Select",
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

-- Updated getSelectedLuckyBlockTools for multi-select
local function getSelectedLuckyBlockTools()
    local list, seen = {}, {}
    local playerData = getData()
    local inventoryByUID = {}

    if playerData and type(playerData.Inventory) == "table" then
        for _, entry in ipairs(playerData.Inventory) do
            if type(entry) == "table" and entry.uid ~= nil then
                inventoryByUID[tostring(entry.uid)] = entry
            end
        end
    end

    local function scan(bag)
        if not bag then return end
        for _, item in ipairs(bag:GetChildren()) do
            if item:IsA("Tool") then
                local uid = item:GetAttribute("slimeUID")
                local key = uid ~= nil and tostring(uid) or nil
                if key and not seen[key] then
                    -- Check if this Lucky Block matches any selected type
                    if luckyBlockToolMatchesMultiSelect(item, playerData, inventoryByUID) then
                        seen[key] = true
                        table.insert(list, {
                            tool = item,
                            uid = uid,
                        })
                    end
                end
            end
        end
    end

    scan(LocalPlayer:FindFirstChild("Backpack"))
    scan(LocalPlayer.Character)

    return list
end

-- Updated luckyBlockToolMatchesType for multi-select
local function luckyBlockToolMatchesMultiSelect(tool, playerData, inventoryByUID)
    if not tool or not tool:IsA("Tool") or not isLuckyBlock(tool) then
        return false
    end

    -- If no types selected, return false
    local hasAny = false
    for _, isSelected in pairs(selectedLuckyBlockTypes) do
        if isSelected then hasAny = true; break end
    end
    if not hasAny then return false end

    local uid = tool:GetAttribute("slimeUID")
    local inventoryEntry = uid ~= nil and inventoryByUID and inventoryByUID[tostring(uid)] or nil
    local def = resolveSlimeDefinition(inventoryEntry)

    for typeName, isSelected in pairs(selectedLuckyBlockTypes) do
        if isSelected then
            local allowed = LUCKY_BLOCK_MODEL_NAMES[typeName]
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

            local rarity = tool:GetAttribute("Rarity") or tool:GetAttribute("rarity") or (def and (def.Rarity or def.rarity)) or (inventoryEntry and (inventoryEntry.Rarity or inventoryEntry.rarity))
            if rarity then
                local r = tostring(rarity)
                if typeName == "Soccer God" and r == "Slime God" then return true end
                if typeName == "Limited" and r == "LIMITED" then return true end
                if string.lower(r) == string.lower(typeName) then return true end
            end
        end
    end

    return false
end
