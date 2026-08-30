-- Auto Perfect Penalty Minigame
-- Uses the game's real server-synchronized motion and normal LockAxis requests.
-- Target: abs(H) >= 0.92 and abs(V) >= 0.92
-- Config guarantee starts at 0.85, so 0.92 gives margin.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local SharedModules = ReplicatedStorage:WaitForChild("SharedModules")

local GameRemoteRegistry = require(
    SharedModules:WaitForChild("GameRemoteRegistry")
)

local Config = require(
    SharedModules:WaitForChild("PenaltyMinigameConfig")
)

local Action = GameRemoteRegistry.new(
    "Penalty Minigame Action",
    "RemoteFunction"
)

local State = GameRemoteRegistry.new(
    "Penalty Minigame State",
    "RemoteEvent"
)

assert(Action, "Penalty Minigame Action remote not found")
assert(State, "Penalty Minigame State remote not found")

------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------

-- Guaranteed corner starts at 0.85.
-- 0.92 gives extra safety margin while still being easy to hit.
local TARGET_ABS = 0.92

-- If a request is rejected, allow another attempt.
local RETRY_DELAY = 0.08

-- Prevent accidental duplicate lock requests.
local REQUEST_TIMEOUT = 1.25

------------------------------------------------------------
-- STATE
------------------------------------------------------------

local session = nil
local requestBusy = false
local requestStartedAt = 0
local running = true

------------------------------------------------------------
-- REMOTE HELPER
------------------------------------------------------------

local function invoke(actionName, payload)
    local ok, result = pcall(function()
        return Action:Fire(actionName, payload)
    end)

    if not ok then
        warn("[PerfectPenalty] Network error:", result)
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
        }
    end

    return result
end

------------------------------------------------------------
-- SESSION HELPERS
------------------------------------------------------------

local function loadSession(serverSession)
    if type(serverSession) ~= "table" then
        return
    end

    if type(serverSession.nonce) ~= "string" then
        return
    end

    session = {
        nonce = serverSession.nonce,
        shotIndex = tonumber(serverSession.shotIndex) or 1,
        expectedAxis = serverSession.expectedAxis or "Horizontal",
        motion = serverSession.motion,
        goals = tonumber(serverSession.goals) or 0,
        completed = serverSession.completed == true,
    }

    requestBusy = false

    print(
        string.format(
            "[PerfectPenalty] Session active | shot %d | %s",
            session.shotIndex,
            tostring(session.expectedAxis)
        )
    )
end

local function clearSession()
    session = nil
    requestBusy = false
end

------------------------------------------------------------
-- PERFECT LOCK
------------------------------------------------------------

local function tryPerfectLock()
    local s = session

    if not running
        or not s
        or s.completed
        or requestBusy
        or type(s.motion) ~= "table"
    then
        return
    end

    local now = workspace:GetServerTimeNow()
    local startedAt = tonumber(s.motion.startedAt) or math.huge

    if now < startedAt then
        return
    end

    local value = Config.EvaluateMotion(
        s.motion,
        now
    )

    -- Only submit inside the guaranteed-goal corner range.
    if math.abs(value) < TARGET_ABS then
        return
    end

    requestBusy = true
    requestStartedAt = os.clock()

    local payload = {
        nonce = s.nonce,
        shotIndex = s.shotIndex,
        axis = s.expectedAxis,

        -- IMPORTANT:
        -- use the real synchronized server timestamp.
        lockedAt = now,
    }

    print(
        string.format(
            "[PerfectPenalty] Locking %s at %+.4f | shot %d",
            tostring(payload.axis),
            value,
            payload.shotIndex
        )
    )

    task.spawn(function()
        local result = invoke(
            "LockAxis",
            payload
        )

        -- The authoritative progression arrives through
        -- Penalty Minigame State, so a successful invocation
        -- stays busy until that event arrives.
        if not result.ok then
            warn(
                "[PerfectPenalty] Lock rejected:",
                tostring(result.code),
                tostring(result.detail or "")
            )

            task.wait(RETRY_DELAY)

            if session == s then
                requestBusy = false
            end
        end
    end)
end

------------------------------------------------------------
-- SERVER STATE EVENTS
------------------------------------------------------------

State:Connect(function(packet)
    if type(packet) ~= "table" then
        return
    end

    local kind = packet.kind

    if kind == "SessionStarted" then
        loadSession(packet.session)
        return
    end

    local s = session

    if not s then
        return
    end

    if packet.nonce
        and packet.nonce ~= s.nonce
    then
        return
    end

    --------------------------------------------------------
    -- HORIZONTAL ACCEPTED
    --------------------------------------------------------

    if kind == "AxisLocked" then
        requestBusy = false

        s.expectedAxis = "Vertical"
        s.motion = packet.nextMotion

        print(
            string.format(
                "[PerfectPenalty] Horizontal confirmed: %+.4f",
                tonumber(packet.value) or 0
            )
        )

        return
    end

    --------------------------------------------------------
    -- SHOT RESOLVED
    --------------------------------------------------------

    if kind == "ShotResolved" then
        requestBusy = false

        local h = tonumber(packet.horizontal) or 0
        local v = tonumber(packet.vertical) or 0
        local chance = tonumber(packet.chance) or 0

        print(
            string.format(
                "[PerfectPenalty] Shot %d | H %+.4f | V %+.4f | chance %.1f%% | %s",
                tonumber(packet.shotIndex) or s.shotIndex,
                h,
                v,
                chance * 100,
                packet.isGoal and "GOAL" or "SAVED"
            )
        )

        s.goals = tonumber(packet.goals) or s.goals

        if packet.nextMotion then
            s.shotIndex =
                (tonumber(packet.shotIndex) or s.shotIndex)
                + 1

            s.expectedAxis = "Horizontal"
            s.motion = packet.nextMotion
        end

        return
    end

    --------------------------------------------------------
    -- SESSION COMPLETE
    --------------------------------------------------------

    if kind == "SessionCompleted" then
        local goals = tonumber(packet.goals) or s.goals

        print(
            string.format(
                "[PerfectPenalty] COMPLETE: %d/%d goals",
                goals,
                Config.ShotsPerSession
            )
        )

        s.completed = true
        requestBusy = false
        return
    end

    if kind == "SessionCancelled" then
        print("[PerfectPenalty] Session cancelled")
        clearSession()
        return
    end
end)

------------------------------------------------------------
-- WATCHER
------------------------------------------------------------

RunService.Heartbeat:Connect(function()
    if not running then
        return
    end

    -- Failsafe in case a response/event gets lost.
    if requestBusy
        and os.clock() - requestStartedAt > REQUEST_TIMEOUT
    then
        requestBusy = false
    end

    tryPerfectLock()
end)

------------------------------------------------------------
-- RECOVER AN ALREADY-ACTIVE SESSION
------------------------------------------------------------

task.spawn(function()
    local state = invoke("GetState")

    if state.ok
        and type(state.session) == "table"
        and not state.session.completed
    then
        loadSession(state.session)
    else
        print(
            "[PerfectPenalty] Ready. Start the penalty minigame normally."
        )
    end
end)

print(
    "[PerfectPenalty] Loaded | guaranteed-corner auto lock = "
    .. tostring(TARGET_ABS)
)