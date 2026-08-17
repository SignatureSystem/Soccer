-- SUPER LEAF FARM - XENO PC COMPATIBILITY BUILD
-- Conservative Luau syntax, ASCII-only GUI text, PlayerGui-only parenting.
-- GUI is created BEFORE any leaf remote/module discovery.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
if not PlayerGui then
    PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
end
if not PlayerGui then
    warn("[XenoLeaf] PlayerGui not found")
    return
end

print("[XenoLeaf] BOOT 1 - creating GUI")

-- Remove previous copy
local old = PlayerGui:FindFirstChild("SuperLeafXenoGui")
if old then
    pcall(function()
        old:Destroy()
    end)
end

-- ============================================================
-- GUI FIRST
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SuperLeafXenoGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.DisplayOrder = 9999
ScreenGui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 440, 0, 650)
Main.Position = UDim2.new(0, 30, 0.5, -325)
Main.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 10)
Corner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Thickness = 2
Stroke.Color = Color3.fromRGB(75, 90, 115)
Stroke.Parent = Main

local Header = Instance.new("TextLabel")
Header.Name = "Header"
Header.Size = UDim2.new(1, -28, 0, 42)
Header.Position = UDim2.new(0, 14, 0, 4)
Header.BackgroundTransparency = 1
Header.Text = "SUPER LEAF FARM - XENO"
Header.TextColor3 = Color3.fromRGB(245, 245, 250)
Header.TextSize = 21
Header.Font = Enum.Font.GothamBold
Header.TextXAlignment = Enum.TextXAlignment.Left
Header.Active = true
Header.Parent = Main

local KeyboardHelp = Instance.new("TextLabel")
KeyboardHelp.Size = UDim2.new(1, -28, 0, 26)
KeyboardHelp.Position = UDim2.new(0, 14, 0, 45)
KeyboardHelp.BackgroundTransparency = 1
KeyboardHelp.Text = "UP/DOWN Navigate   LEFT/RIGHT Change   LEFT SHIFT Select/Toggle"
KeyboardHelp.TextColor3 = Color3.fromRGB(155, 205, 255)
KeyboardHelp.TextSize = 12
KeyboardHelp.Font = Enum.Font.GothamBold
KeyboardHelp.TextXAlignment = Enum.TextXAlignment.Left
KeyboardHelp.Parent = Main

-- No minimize button in this build.

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -28, 0, 62)
Status.Position = UDim2.new(0, 14, 0, 76)
Status.BackgroundColor3 = Color3.fromRGB(30, 33, 41)
Status.BorderSizePixel = 0
Status.Text = "GUI EXPANDED - use UP/DOWN + LEFT SHIFT"
Status.TextColor3 = Color3.fromRGB(210, 220, 235)
Status.TextSize = 14
Status.Font = Enum.Font.Gotham
Status.TextWrapped = true
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.TextYAlignment = Enum.TextYAlignment.Center
Status.Parent = Main
local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 7)
StatusCorner.Parent = Status

local Stats = Instance.new("TextLabel")
Stats.Size = UDim2.new(1, -28, 0, 64)
Stats.Position = UDim2.new(0, 14, 0, 146)
Stats.BackgroundColor3 = Color3.fromRGB(28, 31, 38)
Stats.BorderSizePixel = 0
Stats.Text = "Bag: ? / ? | Mult: ?"
Stats.TextColor3 = Color3.fromRGB(210, 220, 230)
Stats.TextSize = 14
Stats.Font = Enum.Font.Gotham
Stats.TextWrapped = true
Stats.Parent = Main
local StatsCorner = Instance.new("UICorner")
StatsCorner.CornerRadius = UDim.new(0, 7)
StatsCorner.Parent = Stats

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -28, 0, 416)
Scroll.Position = UDim2.new(0, 14, 0, 222)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 9
Scroll.CanvasSize = UDim2.new(0, 0, 0, 760)
Scroll.Parent = Main

-- Force expanded/visible state.
Main.Visible = true
Header.Visible = true
KeyboardHelp.Visible = true
Status.Visible = true
Stats.Visible = true
Scroll.Visible = true
Scroll.ScrollingEnabled = true

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 8)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

local function makeButton(text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -8, 0, 46)
    b.BackgroundColor3 = Color3.fromRGB(42, 43, 52)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(240, 240, 245)
    b.TextSize = 16
    b.Font = Enum.Font.GothamBold
    b.Parent = Scroll
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = b

    local selectStroke = Instance.new("UIStroke")
    selectStroke.Name = "KeyboardSelectStroke"
    selectStroke.Thickness = 1
    selectStroke.Transparency = 1
    selectStroke.Color = Color3.fromRGB(110, 195, 255)
    selectStroke.Parent = b

    return b
end

-- ============================================================
-- STATE
-- ============================================================

local State = {
    AutoCollect = false,
    AutoSell = true,
    TPSweep = false,
    ValueFirst = true,
    SmartCapacity = true,
    ReturnAfterSell = true,

    RadiusIndex = 3,
    BatchIndex = 3,
    DelayIndex = 2,
    SellIndex = 3,

    BusyCollect = false,
    BusySell = false,

    SessionCollected = 0,
    SessionSold = 0,
    SessionCash = 0,
    LastLeaves = tonumber(LocalPlayer:GetAttribute("Leaves")) or 0,
    Started = os.clock()
}

local RadiusValues = {15, 30, 60, 120, 99999}
local RadiusLabels = {"15", "30", "60", "120", "GLOBAL"}
local BatchValues = {1, 5, 10, 20, 40}
local DelayValues = {0.03, 0.08, 0.15, 0.25, 0.40}
local DelayLabels = {"0.03s", "0.08s", "0.15s", "0.25s", "0.40s"}
local SellValues = {70, 85, 95, 100}
local SellLabels = {"70%", "85%", "95%", "100%"}

-- Forward declarations used by keyboard actions.
local resolveSystems
local doSell

local AutoCollectBtn = makeButton("AUTO COLLECT: OFF")
local AutoSellBtn = makeButton("AUTO SELL: ON")
local TPSweepBtn = makeButton("TP SWEEP: OFF")
local ValueFirstBtn = makeButton("5x / 2x VALUE FIRST: ON")
local SmartCapacityBtn = makeButton("SMART CAPACITY: ON")
local ReturnBtn = makeButton("RETURN AFTER SELL: ON")

local RadiusBtn = makeButton("RADIUS: 60")
local BatchBtn = makeButton("SCAN BATCH: 10")
local DelayBtn = makeButton("DELAY: 0.08s")
local SellAtBtn = makeButton("SELL AT: 95%")

local SellNowBtn = makeButton("SELL NOW")
local RescanBtn = makeButton("RESCAN GAME SYSTEMS")
local StopBtn = makeButton("STOP ALL")

local function refreshToggle(button, label, value)
    if value then
        button.Text = label .. ": ON"
        button.TextColor3 = Color3.fromRGB(125, 255, 155)
        button.BackgroundColor3 = Color3.fromRGB(30, 63, 43)
    else
        button.Text = label .. ": OFF"
        button.TextColor3 = Color3.fromRGB(255, 135, 135)
        button.BackgroundColor3 = Color3.fromRGB(52, 43, 48)
    end
end

local function toggleField(button, field, label)
    State[field] = not State[field]
    refreshToggle(button, label, State[field])
end

local function changeRadius(direction)
    State.RadiusIndex = State.RadiusIndex + direction
    if State.RadiusIndex > #RadiusValues then
        State.RadiusIndex = 1
    elseif State.RadiusIndex < 1 then
        State.RadiusIndex = #RadiusValues
    end
    RadiusBtn.Text = "RADIUS: " .. RadiusLabels[State.RadiusIndex]
end

local function changeBatch(direction)
    State.BatchIndex = State.BatchIndex + direction
    if State.BatchIndex > #BatchValues then
        State.BatchIndex = 1
    elseif State.BatchIndex < 1 then
        State.BatchIndex = #BatchValues
    end
    BatchBtn.Text = "SCAN BATCH: " .. tostring(BatchValues[State.BatchIndex])
end

local function changeDelay(direction)
    State.DelayIndex = State.DelayIndex + direction
    if State.DelayIndex > #DelayValues then
        State.DelayIndex = 1
    elseif State.DelayIndex < 1 then
        State.DelayIndex = #DelayValues
    end
    DelayBtn.Text = "DELAY: " .. DelayLabels[State.DelayIndex]
end

local function changeSellAt(direction)
    State.SellIndex = State.SellIndex + direction
    if State.SellIndex > #SellValues then
        State.SellIndex = 1
    elseif State.SellIndex < 1 then
        State.SellIndex = #SellValues
    end
    SellAtBtn.Text = "SELL AT: " .. SellLabels[State.SellIndex]
end

local function stopAllActions()
    State.AutoCollect = false
    State.AutoSell = false
    State.TPSweep = false

    refreshToggle(AutoCollectBtn, "AUTO COLLECT", State.AutoCollect)
    refreshToggle(AutoSellBtn, "AUTO SELL", State.AutoSell)
    refreshToggle(TPSweepBtn, "TP SWEEP", State.TPSweep)

    Status.Text = "Stopped Auto Collect / Auto Sell / TP Sweep."
end

-- Mouse controls use the exact same actions as the keyboard.
AutoCollectBtn.MouseButton1Click:Connect(function()
    toggleField(AutoCollectBtn, "AutoCollect", "AUTO COLLECT")
end)

AutoSellBtn.MouseButton1Click:Connect(function()
    toggleField(AutoSellBtn, "AutoSell", "AUTO SELL")
end)

TPSweepBtn.MouseButton1Click:Connect(function()
    toggleField(TPSweepBtn, "TPSweep", "TP SWEEP")
end)

ValueFirstBtn.MouseButton1Click:Connect(function()
    toggleField(ValueFirstBtn, "ValueFirst", "5x / 2x VALUE FIRST")
end)

SmartCapacityBtn.MouseButton1Click:Connect(function()
    toggleField(SmartCapacityBtn, "SmartCapacity", "SMART CAPACITY")
end)

ReturnBtn.MouseButton1Click:Connect(function()
    toggleField(ReturnBtn, "ReturnAfterSell", "RETURN AFTER SELL")
end)

RadiusBtn.MouseButton1Click:Connect(function()
    changeRadius(1)
end)

BatchBtn.MouseButton1Click:Connect(function()
    changeBatch(1)
end)

DelayBtn.MouseButton1Click:Connect(function()
    changeDelay(1)
end)

SellAtBtn.MouseButton1Click:Connect(function()
    changeSellAt(1)
end)

StopBtn.MouseButton1Click:Connect(function()
    stopAllActions()
end)

-- Keep the initial visual state accurate.
refreshToggle(AutoCollectBtn, "AUTO COLLECT", State.AutoCollect)
refreshToggle(AutoSellBtn, "AUTO SELL", State.AutoSell)
refreshToggle(TPSweepBtn, "TP SWEEP", State.TPSweep)
refreshToggle(ValueFirstBtn, "5x / 2x VALUE FIRST", State.ValueFirst)
refreshToggle(SmartCapacityBtn, "SMART CAPACITY", State.SmartCapacity)
refreshToggle(ReturnBtn, "RETURN AFTER SELL", State.ReturnAfterSell)

-- ============================================================
-- KEYBOARD NAVIGATION
-- UP/DOWN       = select row
-- LEFT/RIGHT    = change cycle value
-- LEFT SHIFT    = activate/toggle selected row
-- ENTER         = alternate activate key
-- ============================================================

local ControlRows = {
    {
        button = AutoCollectBtn,
        kind = "toggle",
        activate = function()
            toggleField(AutoCollectBtn, "AutoCollect", "AUTO COLLECT")
        end
    },
    {
        button = AutoSellBtn,
        kind = "toggle",
        activate = function()
            toggleField(AutoSellBtn, "AutoSell", "AUTO SELL")
        end
    },
    {
        button = TPSweepBtn,
        kind = "toggle",
        activate = function()
            toggleField(TPSweepBtn, "TPSweep", "TP SWEEP")
        end
    },
    {
        button = ValueFirstBtn,
        kind = "toggle",
        activate = function()
            toggleField(ValueFirstBtn, "ValueFirst", "5x / 2x VALUE FIRST")
        end
    },
    {
        button = SmartCapacityBtn,
        kind = "toggle",
        activate = function()
            toggleField(SmartCapacityBtn, "SmartCapacity", "SMART CAPACITY")
        end
    },
    {
        button = ReturnBtn,
        kind = "toggle",
        activate = function()
            toggleField(ReturnBtn, "ReturnAfterSell", "RETURN AFTER SELL")
        end
    },
    {
        button = RadiusBtn,
        kind = "cycle",
        left = function() changeRadius(-1) end,
        right = function() changeRadius(1) end,
        activate = function() changeRadius(1) end
    },
    {
        button = BatchBtn,
        kind = "cycle",
        left = function() changeBatch(-1) end,
        right = function() changeBatch(1) end,
        activate = function() changeBatch(1) end
    },
    {
        button = DelayBtn,
        kind = "cycle",
        left = function() changeDelay(-1) end,
        right = function() changeDelay(1) end,
        activate = function() changeDelay(1) end
    },
    {
        button = SellAtBtn,
        kind = "cycle",
        left = function() changeSellAt(-1) end,
        right = function() changeSellAt(1) end,
        activate = function() changeSellAt(1) end
    },
    {
        button = SellNowBtn,
        kind = "action",
        activate = function()
            task.spawn(function()
                if doSell then
                    Status.Text = "Selling now..."
                    local ok = doSell()
                    Status.Text = ok and "Sell confirmed." or "Sell not confirmed."
                else
                    Status.Text = "Sell system is still loading."
                end
            end)
        end
    },
    {
        button = RescanBtn,
        kind = "action",
        activate = function()
            task.spawn(function()
                if resolveSystems then
                    resolveSystems()
                else
                    Status.Text = "System scanner is still loading."
                end
            end)
        end
    },
    {
        button = StopBtn,
        kind = "action",
        activate = function()
            stopAllActions()
        end
    }
}

local SelectedRow = 1

local function updateKeyboardSelection()
    local i = 1
    while i <= #ControlRows do
        local row = ControlRows[i]
        local stroke = row.button:FindFirstChild("KeyboardSelectStroke")

        if stroke then
            if i == SelectedRow then
                stroke.Transparency = 0
                stroke.Thickness = 3
                stroke.Color = Color3.fromRGB(100, 205, 255)
            else
                stroke.Transparency = 1
                stroke.Thickness = 1
            end
        end

        i = i + 1
    end

    local selected = ControlRows[SelectedRow]
    if selected and selected.button then
        -- Keep the selected row visible in the scrolling panel.
        local rowHeight = 54
        local targetY = (SelectedRow - 1) * rowHeight - 120
        if targetY < 0 then
            targetY = 0
        end

        local maxCanvas =
            math.max(0, Scroll.AbsoluteCanvasSize.Y - Scroll.AbsoluteWindowSize.Y)

        if targetY > maxCanvas then
            targetY = maxCanvas
        end

        Scroll.CanvasPosition = Vector2.new(0, targetY)

        Status.Text =
            "Selected " .. tostring(SelectedRow) .. "/" .. tostring(#ControlRows)
            .. ": " .. selected.button.Text
            .. " | LEFT SHIFT = activate"
    end
end

local function setSelectedRow(index)
    if index < 1 then
        index = #ControlRows
    elseif index > #ControlRows then
        index = 1
    end

    SelectedRow = index
    updateKeyboardSelection()
end

-- Mouse hover also moves the keyboard selection highlight.
local hoverIndex = 1
while hoverIndex <= #ControlRows do
    local indexCopy = hoverIndex
    ControlRows[hoverIndex].button.MouseEnter:Connect(function()
        setSelectedRow(indexCopy)
    end)
    hoverIndex = hoverIndex + 1
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    -- Do not steal keyboard shortcuts while typing in a TextBox.
    if UserInputService:GetFocusedTextBox() then
        return
    end

    local key = input.KeyCode

    if key == Enum.KeyCode.Up then
        setSelectedRow(SelectedRow - 1)

    elseif key == Enum.KeyCode.Down then
        setSelectedRow(SelectedRow + 1)

    elseif key == Enum.KeyCode.Left then
        local row = ControlRows[SelectedRow]
        if row and row.left then
            row.left()
            updateKeyboardSelection()
        end

    elseif key == Enum.KeyCode.Right then
        local row = ControlRows[SelectedRow]
        if row and row.right then
            row.right()
            updateKeyboardSelection()
        end

    elseif key == Enum.KeyCode.LeftShift
        or key == Enum.KeyCode.Return
        or key == Enum.KeyCode.KeypadEnter
    then
        local row = ControlRows[SelectedRow]

        if row and row.activate then
            row.activate()
            task.defer(updateKeyboardSelection)
        end
    end
end)

task.defer(updateKeyboardSelection)

print("[XenoLeaf] BOOT 2 - GUI parented to PlayerGui")

-- ============================================================
-- SIMPLE PC DRAG
-- ============================================================

local dragging = false
local dragStart = nil
local startPos = nil

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)

Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- ============================================================
-- GAME SYSTEM DISCOVERY - AFTER GUI
-- ============================================================

local LeafSim = nil
local LeafFolder = nil
local CollectLeafRemote = nil
local EmptyBackpackRemote = nil
local Dumpsters = nil
local SellEventConnected = false

-- IMPORTANT:
-- Auto Collect uses the game's ALREADY-RUNNING input/tryCollect path.
-- This avoids requiring a second LeafSim instance with the wrong private
-- leaf-part -> leaf-ID mapping.
local MobileActionEvent = nil
local EquipToolRemote = nil

local function findNamed(root, wantedName, className)
    if not root then
        return nil
    end

    local direct = root:FindFirstChild(wantedName)
    if direct and (not className or direct:IsA(className)) then
        return direct
    end

    local all = root:GetDescendants()
    local i = 1
    while i <= #all do
        local obj = all[i]
        if obj.Name == wantedName and (not className or obj:IsA(className)) then
            return obj
        end
        i = i + 1
    end

    return nil
end

local function resolveLeafSim()
    local candidates = {}
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")

    if ps then
        local desc = ps:GetDescendants()
        local i = 1
        while i <= #desc do
            local obj = desc[i]
            if obj:IsA("ModuleScript") and obj.Name == "LeafSim" then
                candidates[#candidates + 1] = obj
            end
            i = i + 1
        end
    end

    local rsDesc = ReplicatedStorage:GetDescendants()
    local j = 1
    while j <= #rsDesc do
        local obj = rsDesc[j]
        if obj:IsA("ModuleScript") and obj.Name == "LeafSim" then
            candidates[#candidates + 1] = obj
        end
        j = j + 1
    end

    local k = 1
    while k <= #candidates do
        local module = candidates[k]
        local finished = false
        local result = nil

        task.spawn(function()
            local ok, value = pcall(require, module)
            if ok and type(value) == "table" then
                result = value
            end
            finished = true
        end)

        local deadline = os.clock() + 2
        while not finished and os.clock() < deadline do
            task.wait(0.05)
        end

        if result then
            return result
        end

        k = k + 1
    end

    return nil
end

local function connectSellEvent()
    if SellEventConnected then
        return
    end

    if EmptyBackpackRemote and EmptyBackpackRemote.Parent then
        SellEventConnected = true
        EmptyBackpackRemote.OnClientEvent:Connect(function(leafCount, cashPaid)
            State.SessionSold = State.SessionSold + (tonumber(leafCount) or 0)
            State.SessionCash = State.SessionCash + (tonumber(cashPaid) or 0)
        end)
    end
end

resolveSystems = function()
    Status.Text = "Scanning remotes..."

    CollectLeafRemote = findNamed(ReplicatedStorage, "CollectLeaf", "RemoteEvent")
    if not CollectLeafRemote then
        CollectLeafRemote = findNamed(ReplicatedStorage, "Collect Leaf", "RemoteEvent")
    end

    MobileActionEvent =
        findNamed(ReplicatedStorage, "MobileActionEvent", "BindableEvent")

    EquipToolRemote =
        findNamed(ReplicatedStorage, "EquipTool", "RemoteEvent")

    EmptyBackpackRemote = findNamed(ReplicatedStorage, "EmptyBackpack", "RemoteEvent")
    if not EmptyBackpackRemote then
        EmptyBackpackRemote = findNamed(ReplicatedStorage, "Empty Backpack", "RemoteEvent")
    end

    LeafFolder = Workspace:FindFirstChild("Leaves")
    if not LeafFolder then
        LeafFolder = findNamed(Workspace, "Leaves")
    end

    Dumpsters = Workspace:FindFirstChild("Dumpsters")
    if not Dumpsters then
        Dumpsters = findNamed(Workspace, "Dumpsters")
    end

    -- Do NOT require LeafSim here for collecting.
    -- Requiring it from the executor can create a separate private ID map.
    LeafFolder =
        Workspace:FindFirstChild("Leaves")
        or LeafFolder

    connectSellEvent()

    Status.Text =
        "NativeAction:" .. (MobileActionEvent and "OK" or "MISS")
        .. " | Leaves:" .. (LeafFolder and "OK" or "MISS")
        .. " | HandEquip:" .. (EquipToolRemote and "OK" or "MISS")
        .. " | Sell:" .. (EmptyBackpackRemote and "OK" or "MISS")
        .. " | Dumpsters:" .. (Dumpsters and "OK" or "MISS")
end

RescanBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        if resolveSystems then
            resolveSystems()
        end
    end)
end)

task.spawn(function()
    task.wait(0.2)
    resolveSystems()
end)

-- ============================================================
-- LEAF HELPERS
-- ============================================================

local function getRoot()
    local char = LocalPlayer.Character
    if not char then
        return nil
    end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getLeaves()
    return tonumber(LocalPlayer:GetAttribute("Leaves")) or 0
end

local function getCapacity()
    return tonumber(LocalPlayer:GetAttribute("LeafCapacity")) or 25
end

local function getMult()
    return tonumber(LocalPlayer:GetAttribute("LeafMult")) or 1
end

local function infiniteBag()
    return LocalPlayer:GetAttribute("InfiniteBag") == true
end

local function bagPercent()
    if infiniteBag() then
        return 0
    end

    local cap = getCapacity()
    if cap <= 0 then
        return 0
    end

    local pct = (getLeaves() / cap) * 100
    if pct < 0 then
        pct = 0
    end
    return pct
end

local function leafValue(part)
    if not part then
        return 1
    end

    -- Values observed in this game's own LeafSim:
    -- 5x texture = 131583021402420
    -- 2x texture = 136781903202871
    local texture = ""

    pcall(function()
        texture = tostring(part.TextureID or "")
    end)

    if string.find(texture, "131583021402420", 1, true) then
        return 5
    end

    if string.find(texture, "136781903202871", 1, true) then
        return 2
    end

    return 1
end

local function validLeaf(part)
    if not part then
        return false
    end
    if not part:IsA("BasePart") then
        return false
    end
    if not LeafFolder then
        return false
    end
    return part.Parent == LeafFolder
end

local function allLeaves()
    local result = {}
    if not LeafFolder then
        return result
    end

    local children = LeafFolder:GetChildren()
    local i = 1
    while i <= #children do
        local obj = children[i]
        if validLeaf(obj) then
            result[#result + 1] = obj
        end
        i = i + 1
    end
    return result
end

local function sortLeaves(list, position)
    table.sort(list, function(a, b)
        if State.ValueFirst then
            local av = leafValue(a)
            local bv = leafValue(b)
            if av ~= bv then
                return av > bv
            end
        end

        if position then
            local ad = (a.Position - position).Magnitude
            local bd = (b.Position - position).Magnitude
            if ad ~= bd then
                return ad < bd
            end
        end

        return tostring(a) < tostring(b)
    end)
end

local function buildBatch()
    local root = getRoot()
    if not root or not LeafFolder then
        return {}
    end

    local leaves = allLeaves()
    if #leaves == 0 then
        return {}
    end

    sortLeaves(leaves, root.Position)

    if State.TPSweep then
        local target = leaves[1]
        if target and target.Parent then
            root.CFrame = target.CFrame * CFrame.new(0, 2.5, 0)
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            task.wait(0.06)
        end
    end

    root = getRoot()
    if not root then
        return {}
    end

    local radius = RadiusValues[State.RadiusIndex]
    local maxBatch = BatchValues[State.BatchIndex]
    local eligible = {}

    local i = 1
    while i <= #leaves do
        local leaf = leaves[i]
        if validLeaf(leaf) then
            local d = (leaf.Position - root.Position).Magnitude
            if radius >= 99999 or d <= radius then
                eligible[#eligible + 1] = leaf
            end
        end
        i = i + 1
    end

    sortLeaves(eligible, root.Position)

    local result = {}
    local remaining = math.huge

    if not infiniteBag() then
        remaining = getCapacity() - getLeaves()
        if remaining < 0 then
            remaining = 0
        end
    end

    local mult = getMult()
    if mult < 1 then
        mult = 1
    end

    local j = 1
    while j <= #eligible and #result < maxBatch do
        local leaf = eligible[j]

        if not State.SmartCapacity or remaining == math.huge then
            result[#result + 1] = leaf
        else
            local weighted = leafValue(leaf) * mult
            if weighted <= remaining then
                result[#result + 1] = leaf
                remaining = remaining - weighted
            end
        end

        j = j + 1
    end

    return result
end

local function waitForHandReady(timeout)
    local deadline = os.clock() + (timeout or 1.5)

    while os.clock() < deadline do
        if LocalPlayer:GetAttribute("HandCooldown") ~= true then
            return true
        end
        task.wait(0.03)
    end

    return LocalPlayer:GetAttribute("HandCooldown") ~= true
end

local function ensureHandSelected()
    -- The normal game's Hand is represented by no equipped special tool.
    if EquipToolRemote and EquipToolRemote.Parent then
        pcall(function()
            EquipToolRemote:FireServer(nil)
        end)
    end

    -- tryCollect() itself checks this CLIENT attribute.
    pcall(function()
        LocalPlayer:SetAttribute("SelectedTool", "Hand")
    end)

    task.wait(0.05)

    return (LocalPlayer:GetAttribute("SelectedTool") or "Hand") == "Hand"
end

local function nativeCollectLeaf(leaf)
    if not leaf
        or not leaf.Parent
        or leaf.Parent ~= LeafFolder
    then
        return 0
    end

    if not MobileActionEvent
        or not MobileActionEvent.Parent
        or not MobileActionEvent:IsA("BindableEvent")
    then
        return 0
    end

    local root = getRoot()
    local camera = Workspace.CurrentCamera

    if not root or not camera then
        return 0
    end

    if not ensureHandSelected() then
        Status.Text = "Could not select Hand."
        return 0
    end

    if not waitForHandReady(1.5) then
        Status.Text = "Waiting for Hand cooldown..."
        return 0
    end

    if getLeaves() >= getCapacity() and not infiniteBag() then
        return 0
    end

    local beforeLeaves = getLeaves()
    local beforeParent = leaf.Parent

    -- Move close enough for the game's own camera Spherecast (10 studs).
    local target = leaf.Position
    local standPos = target + Vector3.new(0, 2.5, 4.5)

    root.CFrame = CFrame.lookAt(standPos, target)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

    -- Force the camera to look straight at THIS leaf briefly.
    -- The game's RenderStepped selector sets its private v8 target from this ray.
    local oldCameraType = camera.CameraType
    local oldCameraCF = camera.CFrame

    pcall(function()
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame =
            CFrame.lookAt(
                target + Vector3.new(0, 2.8, 6),
                target
            )
    end)

    -- Give the game's own RenderStepped selection code several frames.
    task.wait(0.12)

    -- Fire the exact BindableEvent consumed by the game's own LocalScript:
    -- MobileActionEvent.Event -> doToolAction() -> tryCollect()
    pcall(function()
        MobileActionEvent:Fire("leaf", "began")
    end)

    task.wait(0.05)

    pcall(function()
        MobileActionEvent:Fire("leaf", "ended")
    end)

    -- Wait for either server-confirmed bag increase OR the live leaf to be
    -- removed by the game's own collectMany().
    local deadline = os.clock() + 0.85
    local success = false

    while os.clock() < deadline do
        if getLeaves() > beforeLeaves then
            success = true
            break
        end

        if leaf.Parent ~= beforeParent or leaf.Parent == nil then
            success = true
            break
        end

        task.wait(0.03)
    end

    pcall(function()
        camera.CameraType = oldCameraType
        camera.CFrame = oldCameraCF
    end)

    return success and 1 or 0
end

local function collectBatch(batch)
    if #batch == 0 then
        return 0
    end

    -- Native Hand collection automatically applies the game's own Grasp
    -- upgrade to nearby leaves, so one valid targeted action is enough.
    return nativeCollectLeaf(batch[1])
end

-- ============================================================
-- SELL HELPERS
-- ============================================================

local function findNearestDumpster()
    local root = getRoot()
    if not root or not Dumpsters then
        return nil
    end

    local best = nil
    local bestDistance = math.huge
    local children = Dumpsters:GetChildren()

    local i = 1
    while i <= #children do
        local obj = children[i]
        local pos = nil

        if obj:IsA("Model") then
            pos = obj:GetPivot().Position
        elseif obj:IsA("BasePart") then
            pos = obj.Position
        end

        if pos then
            local d = (pos - root.Position).Magnitude
            if d < bestDistance then
                bestDistance = d
                best = obj
            end
        end

        i = i + 1
    end

    return best
end

local function dumpsterCF(obj)
    if not obj then
        return nil
    end

    if obj:IsA("Model") then
        local leavesPart = obj:FindFirstChild("Leaves", true)
        if leavesPart and leavesPart:IsA("BasePart") then
            return leavesPart.CFrame * CFrame.new(0, 0, 4)
        end
        return obj:GetPivot() * CFrame.new(0, 0, 4)
    end

    if obj:IsA("BasePart") then
        return obj.CFrame * CFrame.new(0, 0, 4)
    end

    return nil
end

doSell = function()
    if State.BusySell or getLeaves() <= 0 then
        return false
    end

    if not EmptyBackpackRemote or not EmptyBackpackRemote.Parent then
        resolveSystems()
        if not EmptyBackpackRemote then
            return false
        end
    end

    State.BusySell = true

    local root = getRoot()
    local original = nil
    if root then
        original = root.CFrame
    end

    local dumpster = findNearestDumpster()
    local cf = dumpsterCF(dumpster)

    if root and cf then
        root.CFrame = cf
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        task.wait(0.15)
    end

    local before = getLeaves()

    pcall(function()
        EmptyBackpackRemote:FireServer()
    end)

    local deadline = os.clock() + 2.5
    local sold = false

    while os.clock() < deadline do
        if getLeaves() < before then
            sold = true
            break
        end
        task.wait(0.05)
    end

    if State.ReturnAfterSell and original and getRoot() then
        task.wait(0.08)
        getRoot().CFrame = original
        getRoot().AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        getRoot().AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end

    State.BusySell = false
    return sold
end

SellNowBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        if not doSell then
            Status.Text = "Sell system is still loading."
            return
        end

        Status.Text = "Selling now..."
        local ok = doSell()

        if ok then
            Status.Text = "Sell confirmed."
        else
            Status.Text = "Sell not confirmed."
        end
    end)
end)

-- ============================================================
-- TRACKING
-- ============================================================

LocalPlayer:GetAttributeChangedSignal("Leaves"):Connect(function()
    local current = getLeaves()
    local oldValue = State.LastLeaves

    if current > oldValue then
        State.SessionCollected = State.SessionCollected + (current - oldValue)
    end

    State.LastLeaves = current
end)

-- ============================================================
-- LOOPS
-- ============================================================

task.spawn(function()
    while ScreenGui.Parent do
        if State.AutoCollect and not State.BusyCollect and not State.BusySell then
            if State.AutoSell
                and not infiniteBag()
                and getLeaves() > 0
                and bagPercent() >= SellValues[State.SellIndex]
            then
                Status.Text = "Sell threshold reached..."
                doSell()
            else
                State.BusyCollect = true

                local batch = buildBatch()
                if #batch > 0 then
                    local count = collectBatch(batch)
                    if count > 0 then
                        Status.Text =
                            "NATIVE COLLECT OK | value x"
                            .. tostring(leafValue(batch[1]))
                            .. " | bag "
                            .. tostring(getLeaves())
                            .. "/"
                            .. tostring(getCapacity())
                    else
                        Status.Text =
                            "Native action fired but leaf was not collected."
                    end
                else
                    Status.Text = "No leaves in selected radius."
                end

                State.BusyCollect = false
                task.wait(DelayValues[State.DelayIndex])
            end
        else
            task.wait(0.08)
        end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        if State.AutoSell
            and not State.BusySell
            and not infiniteBag()
            and getLeaves() > 0
            and bagPercent() >= SellValues[State.SellIndex]
        then
            doSell()
        end

        task.wait(0.2)
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        local leaves = getLeaves()
        local cap = getCapacity()
        local mult = getMult()
        local elapsed = os.clock() - State.Started
        if elapsed < 1 then
            elapsed = 1
        end
        local perMinute = State.SessionCollected / elapsed * 60

        if infiniteBag() then
            Stats.Text =
                "Bag: " .. tostring(leaves) .. " / INF"
                .. " | Mult: x" .. tostring(mult)
                .. "\nSession: +" .. tostring(math.floor(State.SessionCollected))
                .. " | " .. string.format("%.1f", perMinute) .. "/min"
                .. " | Sold $" .. tostring(math.floor(State.SessionCash))
        else
            Stats.Text =
                "Bag: " .. tostring(leaves) .. " / " .. tostring(cap)
                .. " (" .. string.format("%.0f", bagPercent()) .. "%)"
                .. " | Mult: x" .. tostring(mult)
                .. "\nSession: +" .. tostring(math.floor(State.SessionCollected))
                .. " | " .. string.format("%.1f", perMinute) .. "/min"
                .. " | Sold $" .. tostring(math.floor(State.SessionCash))
        end

        task.wait(0.3)
    end
end)

print("[XenoLeaf] BOOT 3 - script fully loaded")
