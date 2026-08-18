-- ============================================================
-- ICONS LUCKY BLOCK AUTO COLLECTOR + LIVE LOG UI
-- ============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local TARGET_NAME = "Icons Lucky Block"

local PICKUP_TRIES = 5
local PICKUP_CONFIRM_TIMEOUT = 1.5
local DEPOSIT_TIMEOUT = 5
local NO_BOX_WAIT = 0.5

-- ============================================================
-- STOP OLD INSTANCE
-- ============================================================

local RUN_TOKEN = {}
_G.__IconsLuckyCollector = RUN_TOKEN

local function isRunning()
    return _G.__IconsLuckyCollector == RUN_TOKEN
end

-- ============================================================
-- LOG UI
-- ============================================================

local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("IconsCollectorLogger")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "IconsCollectorLogger"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 390, 0, 270)
frame.Position = UDim2.new(0, 20, 0.5, -135)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
frame.BackgroundTransparency = 0.08
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 32)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.Text = "ICONIC LUCKY BOX COLLECTOR"
title.TextColor3 = Color3.fromRGB(255, 215, 80)
title.TextSize = 17
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 25)
statusLabel.Position = UDim2.new(0, 10, 0, 37)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Starting..."
statusLabel.TextColor3 = Color3.fromRGB(110, 255, 140)
statusLabel.TextSize = 14
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = frame

local counterLabel = Instance.new("TextLabel")
counterLabel.Size = UDim2.new(1, -20, 0, 20)
counterLabel.Position = UDim2.new(0, 10, 0, 61)
counterLabel.BackgroundTransparency = 1
counterLabel.Text = "Collected: 0"
counterLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
counterLabel.TextSize = 13
counterLabel.Font = Enum.Font.Gotham
counterLabel.TextXAlignment = Enum.TextXAlignment.Left
counterLabel.Parent = frame

local logBox = Instance.new("TextLabel")
logBox.Size = UDim2.new(1, -20, 1, -95)
logBox.Position = UDim2.new(0, 10, 0, 86)
logBox.BackgroundColor3 = Color3.fromRGB(5, 5, 7)
logBox.BackgroundTransparency = 0.15
logBox.BorderSizePixel = 0

logBox.Text = ""
logBox.TextColor3 = Color3.fromRGB(225, 225, 225)
logBox.TextSize = 12
logBox.Font = Enum.Font.Code

logBox.TextWrapped = true
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Top

logBox.Parent = frame

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 7)
logCorner.Parent = logBox

-- draggable
local dragging = false
local dragInput
local dragStart
local startPos

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)

frame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = false
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then

        local delta = input.Position - dragStart

        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- ============================================================
-- LOGGER
-- ============================================================

local logs = {}

local function log(message, status)
    local stamp = os.date("%H:%M:%S")

    table.insert(
        logs,
        "[" .. stamp .. "] " .. tostring(message)
    )

    while #logs > 11 do
        table.remove(logs, 1)
    end

    logBox.Text = table.concat(logs, "\n")

    if status then
        statusLabel.Text = "Status: " .. tostring(status)
    end

    print("[IconsLucky]", message)
end

-- ============================================================
-- CHARACTER
-- ============================================================

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

-- ============================================================
-- BASE
-- ============================================================

local function getMyPlot()

    if _G.MyPlot and _G.MyPlot.Parent then
        return _G.MyPlot
    end

    local plots = Workspace:FindFirstChild("Plots")

    if not plots then
        return nil
    end

    for _, plot in ipairs(plots:GetChildren()) do

        local owner = plot:FindFirstChild("owner")

        if owner and tostring(owner.Value) == LocalPlayer.Name then
            return plot
        end
    end

    return nil
end

local function teleportToBase()

    log("Trying to return to base...", "Returning to base")

    local root = getRoot()

    if not root then
        log("HumanoidRootPart missing!")
        return false
    end

    if _G.MyPlot
        and _G.MyPlot.Base
        and _G.MyPlot.Base.Teleport then

        local teleport = _G.MyPlot.Base.Teleport

        if teleport:IsA("Attachment") then

            root.CFrame =
                teleport.WorldCFrame
                + Vector3.new(0, 3, 0)

            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero

            log("Teleported to base.")

            return true
        end
    end

    local plot = getMyPlot()

    if plot then

        local base = plot:FindFirstChild("Base")

        local teleport =
            base and base:FindFirstChild("Teleport")

        if teleport then

            if teleport:IsA("Attachment") then

                root.CFrame =
                    teleport.WorldCFrame
                    + Vector3.new(0, 3, 0)

            elseif teleport:IsA("BasePart") then

                root.CFrame =
                    teleport.CFrame
                    + Vector3.new(0, 3, 0)

            end

            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero

            log("Returned to owned plot.")

            return true
        end
    end

    log("ERROR: Base teleport not found!", "Base not found")

    return false
end

-- ============================================================
-- CLOAK
-- ============================================================

local function findCloakTool()

    local function scan(container)

        if not container then
            return nil
        end

        for _, item in ipairs(container:GetChildren()) do

            if item:IsA("Tool") then

                local name = string.lower(item.Name)

                if name:find("invisibility", 1, true)
                    or name:find("cloak", 1, true)
                    or name:find("invis", 1, true) then

                    return item
                end
            end
        end

        return nil
    end

    return scan(LocalPlayer.Character)
        or scan(LocalPlayer:FindFirstChild("Backpack"))
end

local function setLocalInvisible()

    local character = LocalPlayer.Character

    if not character then
        return
    end

    for _, object in ipairs(character:GetDescendants()) do

        if object:IsA("BasePart")
            and object.Name ~= "HumanoidRootPart" then

            object.Transparency = 1

        elseif object:IsA("Decal")
            or object:IsA("Texture") then

            object.Transparency = 1
        end
    end
end

local function isInvisible()

    local character = LocalPlayer.Character

    if not character then
        return false
    end

    local checked = 0

    for _, object in ipairs(character:GetDescendants()) do

        if object:IsA("BasePart")
            and object.Name ~= "HumanoidRootPart" then

            checked += 1

            if object.Transparency < 0.95 then
                return false
            end
        end
    end

    return checked > 0
end

local function activateCloak()

    local tool = findCloakTool()

    if not tool then
        log(
            "Invisibility Cloak NOT FOUND.",
            "Waiting for cloak"
        )

        return false
    end

    log("Cloak found: " .. tool.Name)

    local humanoid = getHumanoid()
    local character = LocalPlayer.Character

    if not humanoid or not character then
        return false
    end

    if tool.Parent ~= character then

        pcall(function()
            humanoid:UnequipTools()
        end)

        task.wait(0.05)

        pcall(function()
            humanoid:EquipTool(tool)
        end)

        task.wait(0.12)
    end

    local canActivate = tool:FindFirstChild("CanActivate")

    if canActivate and canActivate:IsA("BoolValue") then
        canActivate.Value = true
    end

    pcall(function()
        tool:Activate()
    end)

    setLocalInvisible()

    log("Cloak activated.")

    return true
end

local function ensureInvisible()

    log("Checking invisibility...", "Activating cloak")

    for attempt = 1, 4 do

        if not isRunning() then
            return false
        end

        if isInvisible() then
            log("Invisible confirmed.")
            return true
        end

        log(
            "Cloak attempt "
            .. tostring(attempt)
            .. "/4"
        )

        activateCloak()

        task.wait(0.2)

        if isInvisible() then
            log("Invisible confirmed.")
            return true
        end
    end

    log(
        "Unable to confirm invisibility.",
        "Cloak failed"
    )

    return false
end

-- ============================================================
-- FIND ICONIC BOX
-- ============================================================

local function findPrompt(model)

    if not model then
        return nil
    end

    local fallback

    for _, object in ipairs(model:GetDescendants()) do

        if object:IsA("ProximityPrompt")
            and object.Enabled then

            local action =
                string.lower(
                    tostring(object.ActionText or "")
                )

            if action:find("steal", 1, true)
                or action:find("pick", 1, true)
                or action:find("take", 1, true)
                or action:find("open", 1, true) then

                return object
            end

            fallback = fallback or object
        end
    end

    return fallback
end

local function findIconsBox()

    local live = Workspace:FindFirstChild("Live")
    local slimes = live and live:FindFirstChild("Slimes")

    if not slimes then

        log(
            "Workspace.Live.Slimes not found.",
            "Waiting for Slimes"
        )

        return nil
    end

    local count = 0
    local closest
    local closestDistance = math.huge

    local root = getRoot()

    for _, model in ipairs(slimes:GetChildren()) do

        if model:IsA("Model")
            and model.Name == TARGET_NAME
            and not model:GetAttribute("Carrying") then

            local part =
                model.PrimaryPart
                or model:FindFirstChildWhichIsA("BasePart")

            if part then

                count += 1

                local distance =
                    root and
                    (root.Position - part.Position).Magnitude
                    or 0

                if distance < closestDistance then

                    closestDistance = distance

                    closest = {
                        model = model,
                        part = part,
                        prompt = findPrompt(model)
                    }
                end
            end
        end
    end

    if count > 0 then

        log(
            "Found "
            .. tostring(count)
            .. " Iconic box(es).",
            "Iconic box found"
        )

        return closest
    end

    return nil
end

-- ============================================================
-- HOLDING STATE
-- ============================================================

local function isHolding()
    return LocalPlayer:GetAttribute("holdingSlime") == true
end

local function waitForPickup(timeout)

    local deadline =
        os.clock() + timeout

    while isRunning()
        and os.clock() < deadline do

        if isHolding() then
            return true
        end

        task.wait(0.05)
    end

    return isHolding()
end

local function waitForDeposit()

    log(
        "Waiting for box deposit...",
        "Depositing"
    )

    local deadline =
        os.clock() + DEPOSIT_TIMEOUT

    while isRunning()
        and isHolding()
        and os.clock() < deadline do

        task.wait(0.1)
    end

    if not isHolding() then
        log("Deposit confirmed.")
        return true
    end

    log(
        "Deposit timeout - still holding.",
        "Deposit issue"
    )

    return false
end

-- ============================================================
-- PICKUP
-- ============================================================

local function triggerPrompt(prompt)

    if not prompt or not prompt.Parent then

        log("Pickup prompt missing.")

        return false
    end

    log(
        "Triggering prompt: "
        .. tostring(prompt.ActionText)
    )

    if typeof(fireproximityprompt) == "function" then

        local success = pcall(function()
            fireproximityprompt(prompt)
        end)

        if success then
            return true
        end
    end

    local success = pcall(function()

        prompt:InputHoldBegin()

        task.wait(
            math.max(
                0.05,
                prompt.HoldDuration
            )
        )

        prompt:InputHoldEnd()
    end)

    return success
end

-- ============================================================
-- START
-- ============================================================

local totalCollected = 0
local lastNoBoxMessage = 0

log("Collector launched.", "Searching")

while isRunning() do

    ----------------------------------------------------------
    -- ALREADY HOLDING
    ----------------------------------------------------------

    if isHolding() then

        log(
            "holdingSlime = TRUE",
            "Box currently held"
        )

        teleportToBase()

        task.wait(0.3)

        waitForDeposit()

        continue
    end

    ----------------------------------------------------------
    -- SEARCH BOX
    ----------------------------------------------------------

    local box = findIconsBox()

    if not box then

        if os.clock() - lastNoBoxMessage > 3 then

            log(
                "No Icons Lucky Block currently found.",
                "Searching..."
            )

            lastNoBoxMessage = os.clock()
        end

        task.wait(NO_BOX_WAIT)

        continue
    end

    ----------------------------------------------------------
    -- CLOAK
    ----------------------------------------------------------

    if not ensureInvisible() then

        task.wait(0.5)

        continue
    end

    ----------------------------------------------------------
    -- TELEPORT TO BOX
    ----------------------------------------------------------

    if not box.part
        or not box.part.Parent then

        log("Target disappeared.")

        task.wait(0.2)

        continue
    end

    local root = getRoot()

    if not root then

        log(
            "Character root missing.",
            "Waiting for character"
        )

        task.wait(0.5)

        continue
    end

    log(
        "Teleporting beside Iconic box...",
        "Approaching target"
    )

    root.CFrame =
        box.part.CFrame
        * CFrame.new(0, 3, 4)

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    task.wait(0.2)

    ----------------------------------------------------------
    -- PICKUP
    ----------------------------------------------------------

    local collected = false

    for attempt = 1, PICKUP_TRIES do

        if isHolding() then

            collected = true
            break
        end

        log(
            "Pickup attempt "
            .. tostring(attempt)
            .. "/"
            .. tostring(PICKUP_TRIES),
            "Trying pickup"
        )

        activateCloak()

        task.wait(0.1)

        if box.part
            and box.part.Parent then

            local retryRoot = getRoot()

            if retryRoot then

                retryRoot.CFrame =
                    box.part.CFrame
                    * CFrame.new(0, 3, 4)

                retryRoot.AssemblyLinearVelocity =
                    Vector3.zero

                retryRoot.AssemblyAngularVelocity =
                    Vector3.zero
            end
        end

        local prompt =
            box.model
            and box.model.Parent
            and findPrompt(box.model)

        if not prompt then

            log("No ProximityPrompt found on target.")

        else

            triggerPrompt(prompt)

            log(
                "Waiting for holdingSlime confirmation..."
            )

            if waitForPickup(PICKUP_CONFIRM_TIMEOUT) then

                collected = true

                break
            else

                log(
                    "Pickup not confirmed."
                )
            end
        end

        task.wait(0.15)
    end

    ----------------------------------------------------------
    -- FAILED
    ----------------------------------------------------------

    if not collected then

        log(
            "Failed to collect target after retries.",
            "Pickup failed"
        )

        task.wait(0.4)

        continue
    end

    ----------------------------------------------------------
    -- SUCCESS
    ----------------------------------------------------------

    totalCollected += 1

    counterLabel.Text =
        "Collected: "
        .. tostring(totalCollected)

    log(
        "SUCCESS! holdingSlime = TRUE",
        "Collected"
    )

    task.wait(0.1)

    teleportToBase()

    task.wait(0.35)

    waitForDeposit()

    statusLabel.Text =
        "Status: Searching next Iconic box..."

    task.wait(0.15)
end

log("Collector stopped.", "Stopped")