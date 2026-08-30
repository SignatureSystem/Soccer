--==============================================================
-- PERFECT PENALTY V2 - ROBUST SERVER-TIMED AUTO LOCK
--
-- Mirrors PenaltyMinigameViewController's real LockAxis flow.
-- It DOES NOT fake isGoal/chance.
--
-- Server guarantee:
--   abs(horizontal) >= 0.85
--   abs(vertical)   >= 0.85
-- => CalculateGoalChance() == 1
--
-- This version:
--   * kills an older copy when re-executed
--   * listens to Penalty Minigame State
--   * polls GetState so missed events do not break it
--   * evaluates the REAL server-provided motion every RenderStepped
--   * sends the REAL workspace:GetServerTimeNow() timestamp
--   * retries rejected inputs
--   * handles Horizontal -> Vertical -> next shot automatically
--==============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local SharedModules = ReplicatedStorage:WaitForChild("SharedModules")

local GameRemoteRegistry =
    require(SharedModules:WaitForChild("GameRemoteRegistry"))

local Config =
    require(SharedModules:WaitForChild("PenaltyMinigameConfig"))

local Action =
    GameRemoteRegistry.new(
        "Penalty Minigame Action",
        "RemoteFunction"
    )

local State =
    GameRemoteRegistry.new(
        "Penalty Minigame State",
        "RemoteEvent"
    )

assert(Action, "Penalty Minigame Action missing")
assert(State, "Penalty Minigame State missing")

--==============================================================
-- SINGLE INSTANCE
--==============================================================

local env =
    (getgenv and getgenv())
    or _G

if env.__PerfectPenaltyV2 then
    local old = env.__PerfectPenaltyV2

    old.running = false

    if old.connections then
        for _, c in ipairs(old.connections) do
            pcall(function()
                c:Disconnect()
            end)
        end
    end

    print("[PerfectPenaltyV2] Previous copy stopped")
end

local controller = {
    running = true,
    connections = {},
}

env.__PerfectPenaltyV2 = controller

--==============================================================
-- SETTINGS
--==============================================================

-- 0.85 is guaranteed.
-- 0.90 leaves a comfortable guaranteed-goal margin.
local TARGET_ABS = 0.90

-- If a call is rejected, don't spam immediately.
local RETRY_DELAY = 0.06

-- Poll authoritative state in case a State packet was missed.
local STATE_POLL_INTERVAL = 0.15

-- Request-in-flight failsafe.
local REQUEST_TIMEOUT = 0.75

--==============================================================
-- LOCAL STATE
--==============================================================

local session = nil
local requestBusy = false
local requestStartedClock = 0
local lastPollClock = 0
local lastAttemptKey = nil
local lastAttemptClock = 0

--==============================================================
-- HELPERS
--==============================================================

local function safeInvoke(actionName, payload)
    local success, result = pcall(function()
        return Action:Fire(
            actionName,
            payload
        )
    end)

    if not success then
        return {
            ok = false,
            code = "NETWORK_ERROR",
            detail = tostring(result),
        }
    end

    if type(result) ~= "table" then
        return {
            ok = false,
            code = "INVALID_RESPONSE",
            detail = tostring(result),
        }
    end

    return result
end

local function describeMotion(m)
    if type(m) ~= "table" then
        return "nil"
    end

    return string.format(
        "start=%.3f dur=%.3f phase=%.3f dir=%s",
        tonumber(m.startedAt) or -1,
        tonumber(m.duration) or -1,
        tonumber(m.phase) or -1,
        tostring(m.direction)
    )
end

local function sameSessionState(serverSession)
    if not session then
        return false
    end

    if type(serverSession) ~= "table" then
        return false
    end

    return
        serverSession.nonce == session.nonce
        and (tonumber(serverSession.shotIndex) or 1) == session.shotIndex
        and (serverSession.expectedAxis or "Horizontal") == session.expectedAxis
end

local function applyServerSession(serverSession, source)
    if type(serverSession) ~= "table" then
        return false
    end

    if type(serverSession.nonce) ~= "string" then
        return false
    end

    local oldNonce =
        session and session.nonce

    local oldShot =
        session and session.shotIndex

    local oldAxis =
        session and session.expectedAxis

    session = session or {}

    session.nonce =
        serverSession.nonce

    session.shotIndex =
        tonumber(serverSession.shotIndex)
        or session.shotIndex
        or 1

    session.expectedAxis =
        serverSession.expectedAxis
        or session.expectedAxis
        or "Horizontal"

    if type(serverSession.motion) == "table" then
        session.motion =
            serverSession.motion
    end

    session.goals =
        tonumber(serverSession.goals)
        or session.goals
        or 0

    session.completed =
        serverSession.completed == true

    local changed =
        oldNonce ~= session.nonce
        or oldShot ~= session.shotIndex
        or oldAxis ~= session.expectedAxis

    if changed then
        requestBusy = false
        lastAttemptKey = nil

        print(
            string.format(
                "[PerfectPenaltyV2] %s | shot=%d axis=%s goals=%d | %s",
                tostring(source or "STATE"),
                session.shotIndex,
                tostring(session.expectedAxis),
                session.goals,
                describeMotion(session.motion)
            )
        )
    end

    return true
end

local function clearSession(reason)
    if session then
        print(
            "[PerfectPenaltyV2] Session cleared:",
            tostring(reason or "")
        )
    end

    session = nil
    requestBusy = false
    lastAttemptKey = nil
end

--==============================================================
-- AUTHORITATIVE STATE POLL
--==============================================================

local function pollState()
    if not controller.running then
        return
    end

    task.spawn(function()
        local response =
            safeInvoke("GetState")

        if not controller.running then
            return
        end

        if response.ok ~= true then
            return
        end

        local serverSession =
            response.session

        if type(serverSession) == "table"
            and serverSession.completed ~= true
        then
            applyServerSession(
                serverSession,
                "GetState"
            )
        elseif session
            and session.completed
        then
            -- keep completed local state until the server has cleared it
        end
    end)
end

--==============================================================
-- SEND PERFECT LOCK
--==============================================================

local function sendLock(s, axis, now, value)
    if requestBusy
        or not controller.running
        or session ~= s
    then
        return
    end

    local key =
        tostring(s.nonce)
        .. ":"
        .. tostring(s.shotIndex)
        .. ":"
        .. tostring(axis)

    -- Small anti-double-fire guard.
    if lastAttemptKey == key
        and os.clock() - lastAttemptClock < 0.08
    then
        return
    end

    lastAttemptKey = key
    lastAttemptClock = os.clock()

    requestBusy = true
    requestStartedClock = os.clock()

    local payload = {
        nonce = s.nonce,
        shotIndex = s.shotIndex,
        axis = axis,
        lockedAt = now,
    }

    print(
        string.format(
            "[PerfectPenaltyV2] >>> LOCK %s | shot=%d | value=%+.4f | time=%.4f",
            tostring(axis),
            s.shotIndex,
            value,
            now
        )
    )

    task.spawn(function()
        local response =
            safeInvoke(
                "LockAxis",
                payload
            )

        if not controller.running then
            return
        end

        if session ~= s then
            return
        end

        print(
            "[PerfectPenaltyV2] Lock response:",
            "ok=" .. tostring(response.ok),
            "code=" .. tostring(response.code)
        )

        if response.ok ~= true then
            requestBusy = false

            warn(
                "[PerfectPenaltyV2] Rejected:",
                tostring(response.code),
                tostring(response.detail or "")
            )

            task.wait(RETRY_DELAY)

            -- Force a fresh authoritative state sync before retrying.
            pollState()
            return
        end

        -- Normally AxisLocked / ShotResolved will arrive immediately.
        -- Poll as a backup in case the RemoteEvent packet is missed.
        task.delay(0.08, function()
            if controller.running
                and session == s
            then
                pollState()
            end
        end)
    end)
end

--==============================================================
-- SERVER EVENT LISTENER
--==============================================================

local stateConnection =
    State:Connect(function(packet)
        if not controller.running then
            return
        end

        if type(packet) ~= "table"
            or type(packet.kind) ~= "string"
        then
            return
        end

        local kind =
            packet.kind

        if kind == "SessionStarted" then
            applyServerSession(
                packet.session,
                "SessionStarted"
            )
            return
        end

        if kind == "SessionCancelled" then
            if not session
                or packet.nonce == session.nonce
            then
                clearSession(
                    "SessionCancelled"
                )
            end
            return
        end

        local s =
            session

        if not s then
            pollState()
            return
        end

        if packet.nonce
            and packet.nonce ~= s.nonce
        then
            return
        end

        ------------------------------------------------------
        -- SERVER CONFIRMED HORIZONTAL
        ------------------------------------------------------

        if kind == "AxisLocked" then
            requestBusy = false
            lastAttemptKey = nil

            local confirmed =
                tonumber(packet.value)
                or 0

            print(
                string.format(
                    "[PerfectPenaltyV2] <<< H confirmed %+.4f",
                    confirmed
                )
            )

            s.expectedAxis = "Vertical"
            s.motion = packet.nextMotion

            return
        end

        ------------------------------------------------------
        -- SERVER RESOLVED SHOT
        ------------------------------------------------------

        if kind == "ShotResolved" then
            requestBusy = false
            lastAttemptKey = nil

            local shot =
                tonumber(packet.shotIndex)
                or s.shotIndex

            local h =
                tonumber(packet.horizontal)
                or 0

            local v =
                tonumber(packet.vertical)
                or 0

            local chance =
                tonumber(packet.chance)
                or 0

            print(
                string.format(
                    "[PerfectPenaltyV2] <<< SHOT %d | H=%+.4f V=%+.4f chance=%.1f%% | %s",
                    shot,
                    h,
                    v,
                    chance * 100,
                    packet.isGoal and "GOAL" or "SAVED"
                )
            )

            s.goals =
                tonumber(packet.goals)
                or s.goals
                or 0

            if type(packet.nextMotion) == "table" then
                s.shotIndex =
                    shot + 1

                s.expectedAxis =
                    "Horizontal"

                s.motion =
                    packet.nextMotion
            end

            return
        end

        ------------------------------------------------------
        -- SESSION COMPLETE
        ------------------------------------------------------

        if kind == "SessionCompleted" then
            requestBusy = false

            local goals =
                tonumber(packet.goals)
                or s.goals
                or 0

            print(
                string.format(
                    "[PerfectPenaltyV2] COMPLETE %d/%d",
                    goals,
                    Config.ShotsPerSession
                )
            )

            s.completed = true
            return
        end
    end)

table.insert(
    controller.connections,
    stateConnection
)

--==============================================================
-- EXACT CONTROLLER-STYLE RENDER LOOP
--==============================================================

local renderConnection =
    RunService.RenderStepped:Connect(function()
        if not controller.running then
            return
        end

        ------------------------------------------------------
        -- periodic GetState recovery
        ------------------------------------------------------

        local clockNow =
            os.clock()

        if clockNow - lastPollClock
            >= STATE_POLL_INTERVAL
        then
            lastPollClock =
                clockNow

            pollState()
        end

        ------------------------------------------------------
        -- request timeout recovery
        ------------------------------------------------------

        if requestBusy
            and clockNow - requestStartedClock
                >= REQUEST_TIMEOUT
        then
            requestBusy = false
            lastAttemptKey = nil

            print(
                "[PerfectPenaltyV2] Request timeout -> resync"
            )

            pollState()
        end

        ------------------------------------------------------
        -- active axis
        ------------------------------------------------------

        local s =
            session

        if not s
            or s.completed
            or requestBusy
            or type(s.motion) ~= "table"
        then
            return
        end

        local now =
            workspace:GetServerTimeNow()

        local startedAt =
            tonumber(s.motion.startedAt)
            or math.huge

        if now < startedAt then
            return
        end

        local value =
            Config.EvaluateMotion(
                s.motion,
                now
            )

        ------------------------------------------------------
        -- GUARANTEED CORNER
        ------------------------------------------------------

        if math.abs(value) >= TARGET_ABS then
            sendLock(
                s,
                s.expectedAxis,
                now,
                value
            )
        end
    end)

table.insert(
    controller.connections,
    renderConnection
)

--==============================================================
-- INITIAL STATE
--==============================================================

pollState()

print("======================================================")
print("[PerfectPenaltyV2] LOADED")
print("[PerfectPenaltyV2] Target corner:", TARGET_ABS)
print("[PerfectPenaltyV2] Guaranteed threshold:", Config.Aim.GuaranteedGoalCorner)
print("[PerfectPenaltyV2] Start/play the penalty session normally.")
print("[PerfectPenaltyV2] It will lock H + V automatically.")
print("======================================================")