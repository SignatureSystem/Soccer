--==============================================================
-- PERFECT PENALTY V3 - REAL INPUT TRIGGER
--
-- Why V3:
-- The game's PenaltyMinigameViewController only performs its normal
-- pointer lock path when InputBegan occurs. Instead of bypassing that
-- controller, this script waits for a guaranteed corner and then
-- generates a real MouseButton1 input through VirtualInputManager.
--
-- The ORIGINAL game controller then:
--   1) reads workspace:GetServerTimeNow()
--   2) updates the pointer
--   3) builds nonce / shotIndex / axis / lockedAt
--   4) invokes "Penalty Minigame Action" -> "LockAxis"
--
-- So this uses the exact normal client flow.
--==============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

local SharedModules =
    ReplicatedStorage:WaitForChild("SharedModules")

local Config =
    require(
        SharedModules:WaitForChild(
            "PenaltyMinigameConfig"
        )
    )

-- EXACT RAW PATH shown by the remote spy.
local Remotes =
    SharedModules
        :WaitForChild("Network")
        :WaitForChild("Remotes")

local Action =
    Remotes:WaitForChild(
        "Penalty Minigame Action"
    )

local State =
    Remotes:WaitForChild(
        "Penalty Minigame State"
    )

assert(
    Action:IsA("RemoteFunction"),
    "Penalty Minigame Action is not a RemoteFunction"
)

assert(
    State:IsA("RemoteEvent"),
    "Penalty Minigame State is not a RemoteEvent"
)

--==============================================================
-- SETTINGS
--==============================================================

-- Guaranteed goal starts at 0.85.
-- Aim deeper into corner for margin.
local TARGET_ABS = 0.92

-- Don't trigger multiple clicks while waiting for server response.
local CLICK_COOLDOWN = 0.40

-- Backup state poll, not spammed.
local POLL_INTERVAL = 0.75

--==============================================================
-- SINGLE INSTANCE
--==============================================================

local env =
    (getgenv and getgenv())
    or _G

if env.__PerfectPenaltyV4 then
    local old =
        env.__PerfectPenaltyV4

    old.running = false

    if old.connections then
        for _, c in ipairs(
            old.connections
        ) do
            pcall(function()
                c:Disconnect()
            end)
        end
    end
end

local control = {
    running = true,
    connections = {},
}

env.__PerfectPenaltyV4 =
    control

--==============================================================
-- ON-SCREEN LOG GUI
--==============================================================

local CoreGui = game:GetService("CoreGui")

local guiParent = CoreGui
pcall(function()
    if typeof(gethui) == "function" then
        guiParent = gethui()
    end
end)

-- Remove an older visible log GUI.
pcall(function()
    local oldGui = guiParent:FindFirstChild("PerfectPenaltyLogV4")
    if oldGui then
        oldGui:Destroy()
    end
end)

local LogGui = Instance.new("ScreenGui")
LogGui.Name = "PerfectPenaltyLogV4"
LogGui.ResetOnSpawn = false
LogGui.IgnoreGuiInset = true
LogGui.DisplayOrder = 999999
LogGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
LogGui.Parent = guiParent

local LogFrame = Instance.new("Frame")
LogFrame.Name = "Main"
LogFrame.Size = UDim2.new(0, 330, 0, 210)
LogFrame.Position = UDim2.new(0.5, -165, 0, 55)
LogFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
LogFrame.BackgroundTransparency = 0.10
LogFrame.BorderSizePixel = 0
LogFrame.Active = true
LogFrame.Draggable = true
LogFrame.Parent = LogGui
Instance.new("UICorner", LogFrame).CornerRadius = UDim.new(0, 10)

local Stroke = Instance.new("UIStroke")
Stroke.Thickness = 1
Stroke.Transparency = 0.25
Stroke.Color = Color3.fromRGB(160, 160, 180)
Stroke.Parent = LogFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -38, 0, 28)
Title.Position = UDim2.new(0, 10, 0, 2)
Title.BackgroundTransparency = 1
Title.Text = "Perfect Penalty V4"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = LogFrame

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 24)
MinBtn.Position = UDim2.new(1, -32, 0, 4)
MinBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
MinBtn.BorderSizePixel = 0
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(235, 235, 240)
MinBtn.TextSize = 14
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Parent = LogFrame
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 40)
Status.Position = UDim2.new(0, 10, 0, 31)
Status.BackgroundTransparency = 1
Status.Text = "Status: loading..."
Status.TextColor3 = Color3.fromRGB(130, 220, 255)
Status.TextSize = 12
Status.Font = Enum.Font.GothamBold
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.TextYAlignment = Enum.TextYAlignment.Top
Status.TextWrapped = true
Status.Parent = LogFrame

local Live = Instance.new("TextLabel")
Live.Size = UDim2.new(1, -20, 0, 34)
Live.Position = UDim2.new(0, 10, 0, 70)
Live.BackgroundTransparency = 1
Live.Text = "Shot: - | Axis: - | Aim: -"
Live.TextColor3 = Color3.fromRGB(235, 235, 240)
Live.TextSize = 11
Live.Font = Enum.Font.Code
Live.TextXAlignment = Enum.TextXAlignment.Left
Live.TextYAlignment = Enum.TextYAlignment.Top
Live.TextWrapped = true
Live.Parent = LogFrame

local LogText = Instance.new("TextLabel")
LogText.Size = UDim2.new(1, -20, 1, -112)
LogText.Position = UDim2.new(0, 10, 0, 105)
LogText.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
LogText.BackgroundTransparency = 0.20
LogText.BorderSizePixel = 0
LogText.Text = ""
LogText.TextColor3 = Color3.fromRGB(210, 210, 220)
LogText.TextSize = 10
LogText.Font = Enum.Font.Code
LogText.TextXAlignment = Enum.TextXAlignment.Left
LogText.TextYAlignment = Enum.TextYAlignment.Top
LogText.TextWrapped = true
LogText.Parent = LogFrame
Instance.new("UICorner", LogText).CornerRadius = UDim.new(0, 7)

local logLines = {}
local minimized = false

local function setStatus(text)
    Status.Text = "Status: " .. tostring(text)
end

local function setLive(shot, axis, value)
    local valueText = "-"
    if type(value) == "number" then
        valueText = string.format("%+.4f", value)
    end

    Live.Text =
        string.format(
            "Shot: %s | Axis: %s | Aim: %s | Target: %.2f",
            tostring(shot or "-"),
            tostring(axis or "-"),
            valueText,
            0.92
        )
end

local function guiLog(message)
    local stamp = string.format("%.2f", os.clock() % 1000)
    table.insert(logLines, "[" .. stamp .. "] " .. tostring(message))

    while #logLines > 8 do
        table.remove(logLines, 1)
    end

    LogText.Text = table.concat(logLines, "\n")
    print("[PerfectPenaltyV4]", message)
end

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized

    if minimized then
        LogFrame.Size = UDim2.new(0, 330, 0, 34)
        Status.Visible = false
        Live.Visible = false
        LogText.Visible = false
        MinBtn.Text = "+"
    else
        LogFrame.Size = UDim2.new(0, 330, 0, 210)
        Status.Visible = true
        Live.Visible = true
        LogText.Visible = true
        MinBtn.Text = "—"
    end
end)

--==============================================================
-- STATE
--==============================================================

local session = nil

local waitingServer = false
local lastClickClock = 0
local lastPollClock = 0

-- Tracks the exact state we clicked for.
local clickedNonce = nil
local clickedShot = nil
local clickedAxis = nil

--==============================================================
-- RAW REMOTE
--==============================================================

local function getState()
    local ok, result =
        pcall(function()
            return Action:InvokeServer(
                "GetState"
            )
        end)

    if not ok then
        return nil
    end

    if type(result) ~= "table"
        or result.ok ~= true
    then
        return nil
    end

    return result
end

--==============================================================
-- APPLY SESSION
--==============================================================

local function applySession(s, source)
    if type(s) ~= "table"
        or type(s.nonce) ~= "string"
    then
        return
    end

    local previousNonce =
        session and session.nonce

    local previousShot =
        session and session.shotIndex

    local previousAxis =
        session and session.expectedAxis

    session = {
        nonce = s.nonce,

        shotIndex =
            tonumber(s.shotIndex)
            or 1,

        expectedAxis =
            s.expectedAxis
            or "Horizontal",

        motion =
            s.motion,

        goals =
            tonumber(s.goals)
            or 0,

        completed =
            s.completed == true,
    }

    if previousNonce ~= session.nonce
        or previousShot ~= session.shotIndex
        or previousAxis ~= session.expectedAxis
    then
        waitingServer = false

        setStatus(
            string.format(
                "session active | shot %d | %s",
                session.shotIndex,
                tostring(session.expectedAxis)
            )
        )
        setLive(session.shotIndex, session.expectedAxis, nil)
        guiLog(
            string.format(
                "%s -> shot %d / %s",
                tostring(source),
                session.shotIndex,
                tostring(session.expectedAxis)
            )
        )
    end
end

--==============================================================
-- SAFE CLICK POSITION
--==============================================================

local function pointInside(gui, x, y)
    if not gui
        or not gui:IsA("GuiObject")
        or not gui.Visible
    then
        return false
    end

    local p =
        gui.AbsolutePosition

    local s =
        gui.AbsoluteSize

    return
        x >= p.X
        and x <= p.X + s.X
        and y >= p.Y
        and y <= p.Y + s.Y
end

local function getSafeClickPoint()
    local camera =
        workspace.CurrentCamera

    if not camera then
        return 100, 100
    end

    local size =
        camera.ViewportSize

    -- Start at screen center.
    local x =
        math.floor(size.X * 0.50)

    local y =
        math.floor(size.Y * 0.50)

    -- The real controller ignores clicks only when they are over CancelButton.
    local penaltyGui =
        LocalPlayer
            :FindFirstChild("PlayerGui")

    if penaltyGui then
        penaltyGui =
            penaltyGui:FindFirstChild(
                "PenaltyMinigameViewController"
            )
    end

    local cancel =
        penaltyGui
        and penaltyGui:FindFirstChild(
            "CancelButton",
            true
        )

    if pointInside(
        cancel,
        x,
        y
    ) then
        x =
            math.floor(size.X * 0.20)

        y =
            math.floor(size.Y * 0.25)
    end

    return x, y
end

--==============================================================
-- REAL INPUT
--==============================================================

local function performRealClick()
    local x, y =
        getSafeClickPoint()

    setStatus("sending real input")
    guiLog(
        string.format(
            "REAL INPUT at %d,%d",
            x,
            y
        )
    )

    -- This produces MouseButton1 InputBegan.
    -- PenaltyMinigameViewController accepts:
    --   MouseButton1
    --   Touch
    --
    -- Therefore its own v_u_915() path should run.
    VirtualInputManager:SendMouseButtonEvent(
        x,
        y,
        0,
        true,
        game,
        0
    )

    task.wait(0.035)

    VirtualInputManager:SendMouseButtonEvent(
        x,
        y,
        0,
        false,
        game,
        0
    )
end

--==============================================================
-- PENALTY STATE EVENTS
--==============================================================

local stateConn =
    State.OnClientEvent:Connect(
        function(packet)
            if not control.running
                or type(packet) ~= "table"
            then
                return
            end

            local kind =
                packet.kind

            if kind ==
                "SessionStarted"
            then
                applySession(
                    packet.session,
                    "SessionStarted"
                )

                return
            end

            if kind ==
                "SessionCancelled"
            then
                session = nil
                waitingServer = false
                setStatus("session cancelled")
                setLive(nil, nil, nil)
                guiLog("Session cancelled")
                return
            end

            if not session then
                return
            end

            if packet.nonce
                and packet.nonce
                    ~= session.nonce
            then
                return
            end

            ------------------------------------------
            -- HORIZONTAL LOCK CONFIRMED
            ------------------------------------------

            if kind == "AxisLocked" then
                waitingServer = false

                local confirmedH = tonumber(packet.value) or 0
                setStatus("horizontal confirmed -> waiting vertical")
                setLive(session.shotIndex, "Vertical", confirmedH)
                guiLog(
                    string.format(
                        "H confirmed %+.4f",
                        confirmedH
                    )
                )

                session.expectedAxis =
                    "Vertical"

                session.motion =
                    packet.nextMotion

                return
            end

            ------------------------------------------
            -- SHOT RESOLVED
            ------------------------------------------

            if kind == "ShotResolved" then
                waitingServer = false

                local shot =
                    tonumber(
                        packet.shotIndex
                    )
                    or session.shotIndex

                local h = tonumber(packet.horizontal) or 0
                local v = tonumber(packet.vertical) or 0
                local chance = (tonumber(packet.chance) or 0) * 100
                local resultText = packet.isGoal and "GOAL" or "SAVED"

                setStatus(
                    string.format(
                        "%s | chance %.1f%%",
                        resultText,
                        chance
                    )
                )
                setLive(shot, "Resolved", v)
                guiLog(
                    string.format(
                        "SHOT %d | H=%+.4f V=%+.4f | %.1f%% | %s",
                        shot,
                        h,
                        v,
                        chance,
                        resultText
                    )
                )

                session.goals =
                    tonumber(
                        packet.goals
                    )
                    or session.goals

                if type(
                    packet.nextMotion
                ) == "table" then
                    session.shotIndex =
                        shot + 1

                    session.expectedAxis =
                        "Horizontal"

                    session.motion =
                        packet.nextMotion
                end

                return
            end

            ------------------------------------------
            -- COMPLETE
            ------------------------------------------

            if kind ==
                "SessionCompleted"
            then
                waitingServer = false
                session.completed = true

                local finalGoals =
                    tonumber(packet.goals)
                    or session.goals
                    or 0

                setStatus(
                    string.format(
                        "COMPLETE %d/%d",
                        finalGoals,
                        Config.ShotsPerSession
                    )
                )
                guiLog(
                    string.format(
                        "COMPLETE %d/%d",
                        finalGoals,
                        Config.ShotsPerSession
                    )
                )

                return
            end
        end
    )

table.insert(
    control.connections,
    stateConn
)

--==============================================================
-- PERFECT TIMING LOOP
--==============================================================

local renderConn =
    RunService.RenderStepped:Connect(
        function()
            if not control.running then
                return
            end

            local clockNow =
                os.clock()

            ------------------------------------------
            -- BACKUP GETSTATE SYNC
            ------------------------------------------

            if clockNow - lastPollClock
                >= POLL_INTERVAL
            then
                lastPollClock =
                    clockNow

                task.spawn(function()
                    local state =
                        getState()

                    if not control.running
                        or not state
                    then
                        return
                    end

                    if type(
                        state.session
                    ) == "table"
                        and state.session.completed
                            ~= true
                    then
                        if not session
                            or state.session.nonce
                                ~= session.nonce
                            or tonumber(
                                state.session.shotIndex
                            )
                                ~= session.shotIndex
                            or (
                                state.session.expectedAxis
                                or "Horizontal"
                            )
                                ~= session.expectedAxis
                        then
                            applySession(
                                state.session,
                                "GetState"
                            )
                        end
                    end
                end)
            end

            ------------------------------------------
            -- ACTIVE MOTION
            ------------------------------------------

            local s =
                session

            if not s
                or s.completed
                or waitingServer
                or type(s.motion)
                    ~= "table"
            then
                return
            end

            if clockNow - lastClickClock
                < CLICK_COOLDOWN
            then
                return
            end

            local serverNow =
                workspace:GetServerTimeNow()

            local startedAt =
                tonumber(
                    s.motion.startedAt
                )
                or math.huge

            if serverNow < startedAt then
                return
            end

            local value =
                Config.EvaluateMotion(
                    s.motion,
                    serverNow
                )

            -- Keep the on-screen monitor live every frame.
            setLive(
                s.shotIndex,
                s.expectedAxis,
                value
            )

            ------------------------------------------
            -- GUARANTEED CORNER
            ------------------------------------------

            if math.abs(value)
                >= TARGET_ABS
            then
                waitingServer = true
                lastClickClock = clockNow

                clickedNonce =
                    s.nonce

                clickedShot =
                    s.shotIndex

                clickedAxis =
                    s.expectedAxis

                setStatus(
                    string.format(
                        "TARGET HIT -> %s",
                        tostring(s.expectedAxis)
                    )
                )
                setLive(s.shotIndex, s.expectedAxis, value)
                guiLog(
                    string.format(
                        "TARGET %s %+.4f | shot %d",
                        tostring(s.expectedAxis),
                        value,
                        s.shotIndex
                    )
                )

                -- IMPORTANT:
                -- no manual InvokeServer("LockAxis") here.
                --
                -- We trigger the SAME input event the
                -- original controller expects.
                task.spawn(
                    performRealClick
                )

                -- If no state change arrives, allow
                -- another attempt after a short delay.
                task.delay(
                    0.55,
                    function()
                        if not control.running
                            or not session
                        then
                            return
                        end

                        if waitingServer
                            and session.nonce
                                == clickedNonce
                            and session.shotIndex
                                == clickedShot
                            and session.expectedAxis
                                == clickedAxis
                        then
                            waitingServer = false

                            setStatus("no confirmation -> retrying")
                            guiLog("No lock confirmation -> retrying")
                        end
                    end
                )
            end
        end
    )

table.insert(
    control.connections,
    renderConn
)

--==============================================================
-- INITIAL SYNC
--==============================================================

task.spawn(function()
    local state =
        getState()

    if state
        and type(state.session)
            == "table"
        and state.session.completed
            ~= true
    then
        applySession(
            state.session,
            "Initial GetState"
        )
    else
        setStatus("waiting for penalty session")
        guiLog("Loaded. Start the penalty minigame normally.")
    end
end)

setStatus("loaded | waiting for session")
setLive(nil, nil, nil)
guiLog("V4 GUI logger loaded")
guiLog("Target = " .. tostring(TARGET_ABS))
guiLog("Guaranteed corner = " .. tostring(Config.Aim.GuaranteedGoalCorner))
guiLog("Using game's own input handler")