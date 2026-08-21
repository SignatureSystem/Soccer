--[[
    JAPAN LUCKY BLOCK COLLECTOR SCRIPT
    Automatically collects lucky blocks from each rarity zone
    
    How it works:
    1. GUI appears with checkboxes for each rarity
    2. When checked, player teleports to that zone's floor
    3. Automatically triggers the "Pick Up" proximity prompt
    4. Returns to the base spawn point
    5. Unchecks the box when complete
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

-- ====================================================
-- CONFIGURATION
-- ====================================================

local CONFIG = {
    -- Zone floor positions from the extracted data
    ZONES = {
        Japan = {
            floor1 = Vector3.new(198.1033935546875, 4072.846923828125, -1599.916259765625),
            floor2 = Vector3.new(198.1018524169922, 4794.3828125, -1694.916015625),
            rarity = "Japan",
            id = "1113"
        },
        Icons = {
            floor1 = Vector3.new(198.1033935546875, 2923, -1416),
            floor2 = Vector3.new(198.1033935546875, 3479, -1508),
            rarity = "Icons",
            id = "1112"
        },
        Spain = {
            floor1 = Vector3.new(198.1033935546875, 1964, -1221),
            floor2 = Vector3.new(198.1033935546875, 2367, -1317),
            rarity = "Spain",
            id = "1111"
        },
        Champions = {
            floor1 = Vector3.new(198.1033935546875, 1309, -1036),
            floor2 = Vector3.new(198.1033935546875, 1581, -1128),
            rarity = "Champions",
            id = "1103"
        }
    },
    
    -- Base spawn location (adjust as needed)
    BASE_POSITION = Vector3.new(0, 50, 0),
    
    -- Timing settings
    TELEPORT_DELAY = 0.5,          -- Delay between teleport and pickup attempt
    COLLECT_DELAY = 1.0,           -- Time to wait after collecting
    RETURN_DELAY = 0.5,            -- Delay before returning to base
    
    -- Humanoid settings
    WALK_SPEED = 24,
    JUMP_POWER = 50,
}

-- ====================================================
-- REMOTE REFERENCES
-- ====================================================

-- Find the pickup remote (from the extracted data: v8:Fire(v4))
local PickupRemote
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if Remotes then
    PickupRemote = Remotes:FindFirstChild("PickupSlime") 
        or Remotes:FindFirstChild("PickUpSlime")
        or Remotes:FindFirstChild("Pickup")
end

if not PickupRemote then
    warn("[Collector] Could not find pickup remote! Trying to find by search...")
    -- Search for any remote that might handle pickup
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and (
            obj.Name:lower():find("pickup") or 
            obj.Name:lower():find("collect")
        ) then
            PickupRemote = obj
            break
        end
    end
end

-- ====================================================
-- GUI CREATION
-- ====================================================

local function createGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "LuckyBlockCollector"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 250, 0, 300)
    MainFrame.Position = UDim2.new(0, 10, 0, 100)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    MainFrame.BackgroundTransparency = 0.1
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    -- Corner rounding
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = MainFrame
    
    -- Title
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.Position = UDim2.new(0, 0, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "LUCKY BLOCK COLLECTOR"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextScaled = true
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame
    
    -- Checkbox container
    local Container = Instance.new("Frame")
    Container.Name = "Container"
    Container.Size = UDim2.new(1, -20, 1, -60)
    Container.Position = UDim2.new(0, 10, 0, 35)
    Container.BackgroundTransparency = 1
    Container.Parent = MainFrame
    
    -- Create checkboxes for each rarity
    local checkboxes = {}
    local yOffset = 0
    local checkboxHeight = 35
    
    local RARITY_ORDER = {"Japan", "Icons", "Spain", "Champions"}
    local RARITY_COLORS = {
        Japan = Color3.fromRGB(170, 34, 34),
        Icons = Color3.fromRGB(212, 175, 55),
        Spain = Color3.fromRGB(255, 255, 255),
        Champions = Color3.fromRGB(255, 237, 99),
    }
    
    for _, rarity in ipairs(RARITY_ORDER) do
        local CheckboxFrame = Instance.new("Frame")
        CheckboxFrame.Name = rarity .. "Checkbox"
        CheckboxFrame.Size = UDim2.new(1, 0, 0, checkboxHeight)
        CheckboxFrame.Position = UDim2.new(0, 0, 0, yOffset)
        CheckboxFrame.BackgroundTransparency = 1
        CheckboxFrame.Parent = Container
        
        -- Checkbox button
        local Checkbox = Instance.new("ImageButton")
        Checkbox.Name = "Checkbox"
        Checkbox.Size = UDim2.new(0, 24, 0, 24)
        Checkbox.Position = UDim2.new(0, 0, 0, 5)
        Checkbox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        Checkbox.BackgroundTransparency = 0.3
        Checkbox.BorderSizePixel = 0
        Checkbox.Image = "rbxassetid://0"
        Checkbox.Parent = CheckboxFrame
        
        local CheckCorner = Instance.new("UICorner")
        CheckCorner.CornerRadius = UDim.new(0, 4)
        CheckCorner.Parent = Checkbox
        
        -- Checkmark (hidden by default)
        local Checkmark = Instance.new("ImageLabel")
        Checkmark.Name = "Checkmark"
        Checkmark.Size = UDim2.new(1, 0, 1, 0)
        Checkmark.BackgroundTransparency = 1
        Checkmark.Image = "rbxassetid://6023420880" -- Checkmark icon
        Checkmark.ImageColor3 = Color3.fromRGB(0, 255, 0)
        Checkmark.Visible = false
        Checkmark.Parent = Checkbox
        
        -- Label
        local Label = Instance.new("TextLabel")
        Label.Name = "Label"
        Label.Size = UDim2.new(1, -30, 1, 0)
        Label.Position = UDim2.new(0, 30, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = rarity .. " Lucky Block"
        Label.TextColor3 = RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.TextScaled = true
        Label.Font = Enum.Font.Gotham
        Label.Parent = CheckboxFrame
        
        -- Status label (shows collecting/complete)
        local Status = Instance.new("TextLabel")
        Status.Name = "Status"
        Status.Size = UDim2.new(0, 60, 1, 0)
        Status.Position = UDim2.new(1, -65, 0, 0)
        Status.BackgroundTransparency = 1
        Status.Text = ""
        Status.TextColor3 = Color3.fromRGB(150, 150, 150)
        Status.TextScaled = true
        Status.Font = Enum.Font.Gotham
        Status.TextXAlignment = Enum.TextXAlignment.Right
        Status.Parent = CheckboxFrame
        
        yOffset = yOffset + checkboxHeight + 5
        
        local checkboxData = {
            frame = CheckboxFrame,
            checkbox = Checkbox,
            checkmark = Checkmark,
            label = Label,
            status = Status,
            rarity = rarity,
            checked = false,
            isCollecting = false,
        }
        table.insert(checkboxes, checkboxData)
        
        -- Click handler
        Checkbox.MouseButton1Click:Connect(function()
            if checkboxData.isCollecting then return end
            checkboxData.checked = not checkboxData.checked
            Checkmark.Visible = checkboxData.checked
            
            if checkboxData.checked then
                -- Start collection
                task.spawn(function()
                    collectLuckyBlock(checkboxData)
                end)
            else
                Status.Text = ""
            end
        end)
    end
    
    -- Control buttons at bottom
    local ButtonFrame = Instance.new("Frame")
    ButtonFrame.Name = "ButtonFrame"
    ButtonFrame.Size = UDim2.new(1, -20, 0, 40)
    ButtonFrame.Position = UDim2.new(0, 10, 1, -45)
    ButtonFrame.BackgroundTransparency = 1
    ButtonFrame.Parent = MainFrame
    
    -- Select All button
    local SelectAll = Instance.new("TextButton")
    SelectAll.Name = "SelectAll"
    SelectAll.Size = UDim2.new(0.45, -5, 1, 0)
    SelectAll.Position = UDim2.new(0, 0, 0, 0)
    SelectAll.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
    SelectAll.Text = "SELECT ALL"
    SelectAll.TextColor3 = Color3.fromRGB(255, 255, 255)
    SelectAll.TextScaled = true
    SelectAll.Font = Enum.Font.GothamBold
    SelectAll.BorderSizePixel = 0
    SelectAll.Parent = ButtonFrame
    
    local SelectCorner = Instance.new("UICorner")
    SelectCorner.CornerRadius = UDim.new(0, 4)
    SelectCorner.Parent = SelectAll
    
    SelectAll.MouseButton1Click:Connect(function()
        for _, data in ipairs(checkboxes) do
            if not data.isCollecting then
                data.checked = true
                data.checkmark.Visible = true
                task.spawn(function()
                    collectLuckyBlock(data)
                end)
            end
        end
    end)
    
    -- Deselect All button
    local DeselectAll = Instance.new("TextButton")
    DeselectAll.Name = "DeselectAll"
    DeselectAll.Size = UDim2.new(0.45, -5, 1, 0)
    DeselectAll.Position = UDim2.new(0.55, 5, 0, 0)
    DeselectAll.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
    DeselectAll.Text = "DESELECT ALL"
    DeselectAll.TextColor3 = Color3.fromRGB(255, 255, 255)
    DeselectAll.TextScaled = true
    DeselectAll.Font = Enum.Font.GothamBold
    DeselectAll.BorderSizePixel = 0
    DeselectAll.Parent = ButtonFrame
    
    local DeselectCorner = Instance.new("UICorner")
    DeselectCorner.CornerRadius = UDim.new(0, 4)
    DeselectCorner.Parent = DeselectAll
    
    DeselectAll.MouseButton1Click:Connect(function()
        for _, data in ipairs(checkboxes) do
            data.checked = false
            data.checkmark.Visible = false
            data.status.Text = ""
        end
    end)
    
    return checkboxes, ScreenGui
end

-- ====================================================
-- COLLECTION LOGIC
-- ====================================================

local function teleportPlayer(position)
    if not Character or not Character.Parent then
        Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        Humanoid = Character:WaitForChild("Humanoid")
    end
    
    -- Store current position for return
    local rootPart = Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    
    -- Teleport
    rootPart.CFrame = CFrame.new(position)
    return true
end

local function triggerPickupPrompt()
    -- Method 1: Use the remote found earlier
    if PickupRemote then
        -- Find the stand name. The pickup remote expects a stand name.
        -- We need to find the nearest stand to our current position.
        local Stands = Workspace:FindFirstChild("Stands")
        if Stands then
            local nearestStand = nil
            local nearestDist = math.huge
            local currentPos = Character and Character:FindFirstChild("HumanoidRootPart")
            
            if currentPos then
                for _, stand in ipairs(Stands:GetChildren()) do
                    if stand:IsA("Model") then
                        local mainPart = stand:FindFirstChild("Main")
                        if mainPart then
                            local dist = (mainPart.Position - currentPos.Position).Magnitude
                            if dist < nearestDist then
                                nearestDist = dist
                                nearestStand = stand
                            end
                        end
                    end
                end
            end
            
            if nearestStand then
                -- Fire the pickup remote with the stand name
                PickupRemote:FireServer(tostring(nearestStand.Name))
                print("[Collector] Triggered pickup for stand:", nearestStand.Name)
                return true
            end
        end
        
        -- Fallback: just fire the remote with a generic name
        PickupRemote:FireServer("1")
        return true
    end
    
    -- Method 2: Simulate proximity prompt trigger
    -- Find proximity prompts in the area and trigger them
    if Character then
        local rootPart = Character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            -- Look for nearby proximity prompts
            for _, prompt in ipairs(Workspace:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") and 
                   prompt.Name == "Pick Up" and 
                   prompt.Enabled then
                    local parent = prompt.Parent
                    -- Check if the prompt is within range
                    local promptPos = prompt.Parent and prompt.Parent.Parent and 
                                     prompt.Parent.Parent:FindFirstChild("Main")
                    if promptPos then
                        local dist = (promptPos.Position - rootPart.Position).Magnitude
                        if dist <= prompt.MaxActivationDistance then
                            -- Trigger the prompt
                            prompt:InputHoldBegin()
                            task.wait(prompt.HoldDuration)
                            prompt:InputHoldEnd()
                            print("[Collector] Triggered proximity prompt:", prompt.Name)
                            return true
                        end
                    end
                end
            end
        end
    end
    
    warn("[Collector] Could not trigger pickup prompt!")
    return false
end

function collectLuckyBlock(checkboxData)
    if checkboxData.isCollecting then return end
    checkboxData.isCollecting = true
    checkboxData.status.Text = "Collecting..."
    checkboxData.status.TextColor3 = Color3.fromRGB(255, 255, 100)
    
    local rarity = checkboxData.rarity
    local zone = CONFIG.ZONES[rarity]
    
    if not zone then
        checkboxData.status.Text = "Error!"
        checkboxData.status.TextColor3 = Color3.fromRGB(255, 0, 0)
        checkboxData.isCollecting = false
        return
    end
    
    -- Get current position for return
    local startPos = Character and Character:FindFirstChild("HumanoidRootPart")
    local returnPos = startPos and startPos.Position or CONFIG.BASE_POSITION
    
    -- Disable jump while carrying (simulate the carry penalty)
    local originalJumpPower = Humanoid.JumpPower
    
    -- Step 1: Teleport to the zone
    print("[Collector] Teleporting to", rarity, "zone...")
    local success = teleportPlayer(zone.floor1)
    
    if not success then
        checkboxData.status.Text = "Teleport Failed!"
        checkboxData.status.TextColor3 = Color3.fromRGB(255, 0, 0)
        checkboxData.isCollecting = false
        return
    end
    
    -- Wait for the teleport to settle
    task.wait(CONFIG.TELEPORT_DELAY)
    
    -- Step 2: Find and collect the lucky block
    print("[Collector] Attempting to collect", rarity, "lucky block...")
    
    -- Try multiple times to trigger the prompt
    local collected = false
    for attempt = 1, 3 do
        local triggerSuccess = triggerPickupPrompt()
        if triggerSuccess then
            collected = true
            break
        end
        task.wait(0.5)
    end
    
    if not collected then
        -- Try alternative: look for the "Pick Up" prompt and trigger it directly
        local prompts = Workspace:GetDescendants()
        for _, prompt in ipairs(prompts) do
            if prompt:IsA("ProximityPrompt") and 
               prompt.Name == "Pick Up" and 
               prompt.Enabled and
               prompt:GetAttribute("IsCollecting") ~= false then
                -- Try to trigger it
                local rootPart = Character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local parentPart = prompt.Parent and prompt.Parent.Parent
                    if parentPart then
                        local mainPart = parentPart:FindFirstChild("Main")
                        if mainPart then
                            local dist = (mainPart.Position - rootPart.Position).Magnitude
                            if dist <= prompt.MaxActivationDistance then
                                prompt:InputHoldBegin()
                                task.wait(prompt.HoldDuration)
                                prompt:InputHoldEnd()
                                collected = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
    if collected then
        checkboxData.status.Text = "Collected!"
        checkboxData.status.TextColor3 = Color3.fromRGB(0, 255, 0)
        print("[Collector] Successfully collected", rarity, "lucky block!")
    else
        checkboxData.status.Text = "Failed!"
        checkboxData.status.TextColor3 = Color3.fromRGB(255, 0, 0)
        warn("[Collector] Failed to collect", rarity, "lucky block!")
    end
    
    -- Wait a moment for the collection to register
    task.wait(CONFIG.COLLECT_DELAY)
    
    -- Step 3: Return to base
    print("[Collector] Returning to base...")
    teleportPlayer(returnPos)
    
    task.wait(CONFIG.RETURN_DELAY)
    
    -- Step 4: Reset state
    checkboxData.checked = false
    checkboxData.checkmark.Visible = false
    checkboxData.isCollecting = false
    
    if collected then
        checkboxData.status.Text = "Done ✓"
        checkboxData.status.TextColor3 = Color3.fromRGB(0, 255, 0)
        -- Clear status after a moment
        task.wait(2)
        checkboxData.status.Text = ""
    else
        checkboxData.status.Text = "Retry?"
        checkboxData.status.TextColor3 = Color3.fromRGB(255, 100, 0)
    end
    
    -- Restore jump power
    Humanoid.JumpPower = originalJumpPower
end

-- ====================================================
-- BIND TO KEY (Optional)
-- ====================================================

local function toggleGUI(ScreenGui)
    if ScreenGui then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end

-- ====================================================
-- INITIALIZATION
-- ====================================================

print("[Collector] Initializing Japan Lucky Block Collector...")

-- Check for required services
if not ReplicatedStorage then
    warn("[Collector] ReplicatedStorage not found!")
end

-- Create the GUI
local checkboxes, ScreenGui = createGUI()

-- Set up keybind (F2 to toggle)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F2 then
        toggleGUI(ScreenGui)
    end
end)

-- Handle character respawn
LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    Humanoid = Character:WaitForChild("Humanoid")
end)

print("[Collector] Ready! Press F2 to toggle the GUI.")
print("[Collector] Check the boxes to automatically collect lucky blocks!")

-- ====================================================
-- AUTOMATIC COLLECTION (Optional)
-- ====================================================

-- Uncomment this section to automatically collect all blocks on startup
--[[
task.wait(3) -- Wait for everything to load
for _, data in ipairs(checkboxes) do
    data.checked = true
    data.checkmark.Visible = true
    task.spawn(function()
        collectLuckyBlock(data)
    end)
    task.wait(5) -- Wait between collections
end
--]]

return {
    collectLuckyBlock = collectLuckyBlock,
    checkboxes = checkboxes,
    ScreenGui = ScreenGui,
}