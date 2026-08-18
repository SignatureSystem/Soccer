-- ============================================================
-- ICONS LUCKY BLOCK AUTO COLLECTOR
-- NO GUI / AUTO START / ICONS ONLY
--
-- FLOW:
-- 1. Find exact "Icons Lucky Block"
-- 2. Activate + confirm Invisibility Cloak
-- 3. Teleport beside target
-- 4. Trigger pickup prompt
-- 5. Confirm holdingSlime == true
-- 6. ONLY THEN teleport back to base
-- 7. Wait until deposited
-- 8. Repeat
-- ============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local TARGET_NAME = "Icons Lucky Block"

local PICKUP_TRIES = 5
local PICKUP_CONFIRM_TIMEOUT = 1.50
local DEPOSIT_TIMEOUT = 5
local NO_BOX_WAIT = 0.50

-- Allows a newer execution of the script to replace the old loop.
local RUN_TOKEN = {}
_G.__IconsLuckyCollector = RUN_TOKEN

local function isRunning()
    return _G.__IconsLuckyCollector == RUN_TOKEN
end

-- ============================================================
-- CHARACTER
-- ============================================================

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- ============================================================
-- PLAYER BASE
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
    local root = getRoot()
    if not root then
        return false
    end

    -- Preferred existing game plot reference.
    if _G.MyPlot
        and _G.MyPlot.Base
        and _G.MyPlot.Base.Teleport
        and _G.MyPlot.Base.Teleport.WorldCFrame
    then
        root.CFrame =
            _G.MyPlot.Base.Teleport.WorldCFrame
            + Vector3.new(0, 3, 0)

        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        return true
    end

    -- Fallback: locate your owned plot.
    local plot = getMyPlot()

    if plot then
        local base = plot:FindFirstChild("Base")
        local tp = base and base:FindFirstChild("Teleport")

        if tp and tp:IsA("Attachment") then
            root.CFrame =
                tp.WorldCFrame
                + Vector3.new(0, 3, 0)

            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero

            return true
        end
    end

    return false
end

-- ============================================================
-- INVISIBILITY
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
                    or name:find("invis", 1, true)
                then
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
    local char = LocalPlayer.Character
    if not char then
        return
    end

    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart")
            and obj.Name ~= "HumanoidRootPart"
        then
            if obj:GetAttribute("_OrigTrans") == nil then
                obj:SetAttribute(
                    "_OrigTrans",
                    obj.Transparency
                )
            end

            obj.Transparency = 1

        elseif obj:IsA("Decal")
            or obj:IsA("Texture")
        then
            if obj:GetAttribute("_OrigTrans") == nil then
                obj:SetAttribute(
                    "_OrigTrans",
                    obj.Transparency
                )
            end

            obj.Transparency = 1
        end
    end
end

local function activateCloak()
    local tool = findCloakTool()
    if not tool then
        return false
    end

    local humanoid = getHumanoid()
    local char = LocalPlayer.Character

    if not humanoid or not char then
        return false
    end

    if tool.Parent ~= char then
        pcall(function()
            humanoid:UnequipTools()
        end)

        task.wait(0.05)

        pcall(function()
            humanoid:EquipTool(tool)
        end)

        if tool.Parent ~= char then
            pcall(function()
                tool.Parent = char
            end)
        end

        task.wait(0.15)
    end

    local canActivate = tool:FindFirstChild("CanActivate")

    if canActivate
        and canActivate:IsA("BoolValue")
    then
        canActivate.Value = true
    end

    pcall(function()
        tool:Activate()
    end)

    setLocalInvisible()

    return true
end

local function isInvisible()
    local char = LocalPlayer.Character
    if not char then
        return false
    end

    local checked = 0

    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart")
            and obj.Name ~= "HumanoidRootPart"
        then
            checked += 1

            if obj.Transparency < 0.95 then
                return false
            end
        end
    end

    return checked > 0
end

local function ensureInvisible()
    for attempt = 1, 4 do
        if not isRunning() then
            return false
        end

        local cloak = findCloakTool()

        if not cloak then
            warn("[IconsLucky] Invisibility Cloak not found")
            return false
        end

        local activated = activateCloak()

        task.wait(0.20)

        local char = LocalPlayer.Character

        if activated
            and char
            and cloak.Parent == char
            and isInvisible()
        then
            return true
        end

        task.wait(0.15)
    end

    return false
end

-- ============================================================
-- ICONS LUCKY BLOCK SEARCH
-- ============================================================

local function findPrompt(model)
    if not model or not model.Parent then
        return nil
    end

    local fallback = nil

    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("ProximityPrompt")
            and obj.Enabled
        then
            local action =
                string.lower(
                    tostring(obj.ActionText or "")
                )

            if action:find("steal", 1, true)
                or action:find("pick", 1, true)
                or action:find("take", 1, true)
                or action:find("open", 1, true)
            then
                return obj
            end

            fallback = fallback or obj
        end
    end

    return fallback
end

local function getTargetIconsBox()
    local live = Workspace:FindFirstChild("Live")
    local slimes = live and live:FindFirstChild("Slimes")

    if not slimes then
        return nil
    end

    local root = getRoot()

    local best = nil
    local bestValue = -math.huge
    local bestDistance = math.huge

    for _, model in ipairs(slimes:GetChildren()) do
        -- STRICT FILTER:
        -- NOTHING except exact Icons Lucky Block.
        if model:IsA("Model")
            and model.Name == TARGET_NAME
            and not model:GetAttribute("Carrying")
        then
            local part =
                model.PrimaryPart
                or model:FindFirstChildWhichIsA("BasePart")

            if part then
                local value =
                    tonumber(model:GetAttribute("Value"))
                    or tonumber(
                        model:GetAttribute("MoneyPerSecond")
                    )
                    or 0

                local distance =
                    root
                    and (root.Position - part.Position).Magnitude
                    or math.huge

                if value > bestValue
                    or (
                        value == bestValue
                        and distance < bestDistance
                    )
                then
                    bestValue = value
                    bestDistance = distance

                    best = {
                        model = model,
                        part = part,
                        prompt = findPrompt(model),
                        value = value,
                    }
                end
            end
        end
    end

    return best
end

-- ============================================================
-- PICKUP
-- ============================================================

local function attemptPickup(prompt)
    if not prompt or not prompt.Parent then
        return false
    end

    local hold =
        tonumber(prompt.HoldDuration)
        or 0

    if typeof(fireproximityprompt) == "function" then
        local ok = pcall(function()
            fireproximityprompt(prompt)
        end)

        if ok then
            task.wait(
                math.max(
                    0.12,
                    hold + 0.15
                )
            )

            return true
        end
    end

    -- Fallback.
    local ok = pcall(function()
        prompt:InputHoldBegin()

        task.wait(
            math.max(
                0.05,
                hold
            )
        )

        prompt:InputHoldEnd()
    end)

    if ok then
        task.wait(0.15)
        return true
    end

    return false
end

local function isHolding()
    return
        LocalPlayer:GetAttribute("holdingSlime")
        == true
end

local function waitForPickup(timeout)
    local deadline =
        os.clock()
        + (timeout or PICKUP_CONFIRM_TIMEOUT)

    while isRunning()
        and os.clock() < deadline
    do
        if isHolding() then
            return true
        end

        task.wait(0.05)
    end

    return isHolding()
end

local function waitForDeposit()
    local deadline =
        os.clock()
        + DEPOSIT_TIMEOUT

    while isRunning()
        and isHolding()
        and os.clock() < deadline
    do
        task.wait(0.10)
    end

    return not isHolding()
end

-- ============================================================
-- AUTO LAUNCH
-- ============================================================

local totalCollected = 0

print("[IconsLucky] AUTO COLLECT STARTED")
print("[IconsLucky] Target:", TARGET_NAME)

while isRunning() do

    -- If already carrying one, finish the return first.
    if isHolding() then
        teleportToBase()
        task.wait(0.35)
        waitForDeposit()

        task.wait(0.10)
        continue
    end

    local block = getTargetIconsBox()

    if not block then
        task.wait(NO_BOX_WAIT)
        continue
    end

    -- STEP 1:
    -- Cloak MUST be active/confirmed before approaching.
    if not ensureInvisible() then
        task.wait(0.50)
        continue
    end

    if not block.model.Parent
        or not block.part.Parent
    then
        task.wait(0.20)
        continue
    end

    local root = getRoot()

    if not root then
        task.wait(0.50)
        continue
    end

    -- STEP 2:
    -- Move beside the exact Icons Lucky Block.
    root.CFrame =
        block.part.CFrame
        * CFrame.new(0, 3, 4)

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    task.wait(0.18)

    -- STEP 3:
    -- Pickup and REQUIRE holdingSlime confirmation.
    local collected = false

    for pickupTry = 1, PICKUP_TRIES do
        if not isRunning() then
            break
        end

        if isHolding() then
            collected = true
            break
        end

        -- Re-fire cloak before retrying.
        activateCloak()
        task.wait(0.12)

        -- Keep beside the same Icons box.
        if block.part
            and block.part.Parent
        then
            local retryRoot = getRoot()

            if retryRoot then
                retryRoot.CFrame =
                    block.part.CFrame
                    * CFrame.new(0, 3, 4)

                retryRoot.AssemblyLinearVelocity =
                    Vector3.zero

                retryRoot.AssemblyAngularVelocity =
                    Vector3.zero
            end
        end

        -- Re-find live prompt every attempt.
        local prompt = nil

        if block.model
            and block.model.Parent
        then
            prompt = findPrompt(block.model)
        end

        prompt = prompt or block.prompt

        if prompt
            and prompt.Parent
        then
            attemptPickup(prompt)

            if waitForPickup(
                PICKUP_CONFIRM_TIMEOUT
            ) then
                collected = true
                break
            end
        end

        task.wait(0.20)
    end

    if not collected then
        -- IMPORTANT:
        -- failed pickup = DO NOT teleport home.
        task.wait(0.25)
        continue
    end

    -- STEP 4:
    -- Game confirmed pickup.
    totalCollected += 1

    print(
        "[IconsLucky] Collected #"
        .. tostring(totalCollected)
    )

    -- ONLY AFTER holdingSlime == true.
    teleportToBase()

    task.wait(0.35)

    -- STEP 5:
    -- Wait for successful deposit before next target.
    waitForDeposit()

    task.wait(0.10)
end

print("[IconsLucky] Collector stopped")