--[[
  Penalty Minigame — predictive peak locker (pro automation)

  Reality check:
  - Server computes aim from motion + lockedAt (you cannot send aim=1).
  - ValidateLockTimestamp allows only a small rewind/future window.
  - This script PREDICTS the next time |EvaluateMotion| hits ~1.0 and
    fires LockAxis at that server time. That is the best client-side play.

  Flow: use midfield ball when event is open → this handles all 5 shots.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer

-- Config mirrors PenaltyMinigameConfig (live values from place dump)
local CFG = {
	GoalCorner = 0.85,
	MaxRewind = 0.35,
	FutureTol = 0.10,
	MinRewind = 0.25,
	MinFuture = 0.075,
}

local function findRemote(name, className)
	local sm = ReplicatedStorage:FindFirstChild("SharedModules")
	local remotes = sm and sm:FindFirstChild("Network") and sm.Network:FindFirstChild("Remotes")
	if remotes then
		local r = remotes:FindFirstChild(name)
		if r and r:IsA(className) then return r end
	end
	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
		if obj.Name == name and obj:IsA(className) then
			return obj
		end
	end
	return nil
end

local ActionRF, StateRE

local function ensureRemotes()
	ActionRF = ActionRF or findRemote("Penalty Minigame Action", "RemoteFunction")
	StateRE = StateRE or findRemote("Penalty Minigame State", "RemoteEvent")
	return ActionRF ~= nil and StateRE ~= nil
end

local function invokeAction(action, payload)
	if not ensureRemotes() then
		return { ok = false, code = "NO_REMOTE" }
	end
	local ok, res = pcall(function()
		if typeof(ActionRF.InvokeServer) == "function" then
			return ActionRF:InvokeServer(action, payload)
		end
		return ActionRF:Fire(action, payload)
	end)
	if not ok then
		return { ok = false, code = tostring(res) }
	end
	return type(res) == "table" and res or { ok = true, raw = res }
end

-- Triangle wave identical to config EvaluateMotion → value in [-1, 1]
local function evalMotion(motion, t)
	local startedAt = tonumber(motion.startedAt)
	local duration = tonumber(motion.duration)
	local phase = tonumber(motion.phase) or 0
	local dir = tonumber(motion.direction)
	if not startedAt or not duration or duration <= 0 then return 0 end
	if dir ~= 1 and dir ~= -1 then return 0 end
	local u = (phase + dir * ((t - startedAt) / duration)) % 2
	if u <= 1 then
		return -1 + 2 * u
	end
	return 3 - 2 * u
end

--[[
  Peak |aim|=1 when the triangle hits a tip.
  u in [0,2): peak at u=0.5 (aim=+1) and u=1.5 (aim=-1)
  Solve for next server time >= now where u hits those.
]]
local function nextPeakTime(motion, now)
	local startedAt = tonumber(motion.startedAt)
	local duration = tonumber(motion.duration)
	local phase = tonumber(motion.phase) or 0
	local dir = tonumber(motion.direction)
	if not startedAt or not duration or duration <= 0 then return nil end
	if dir ~= 1 and dir ~= -1 then return nil end

	-- current u
	local u0 = (phase + dir * ((now - startedAt) / duration)) % 2
	local bestT, bestAbs = nil, -1

	for _, targetU in ipairs({ 0.5, 1.5 }) do
		local du = targetU - u0
		if dir == 1 then
			if du < 0 then du += 2 end
		else
			-- direction -1: u decreases as time increases → invert
			du = u0 - targetU
			if du < 0 then du += 2 end
		end
		-- For dir=-1 the parametrization still uses + dir * dt/duration in eval;
		-- solve t from: (phase + dir * (t-start)/dur) % 2 == targetU
		local t
		if dir == 1 then
			t = startedAt + ((targetU - phase) % 2) * duration
			-- advance cycles until t >= now
			while t < now - 1e-4 do
				t += 2 * duration
			end
		else
			-- phase + (-1)*(t-start)/dur ≡ targetU (mod 2)
			-- (phase - targetU) % 2 = (t-start)/dur
			local need = (phase - targetU) % 2
			t = startedAt + need * duration
			while t < now - 1e-4 do
				t += 2 * duration
			end
		end
		local aim = evalMotion(motion, t)
		local a = math.abs(aim)
		if a > bestAbs then
			bestAbs = a
			bestT = t
		end
	end
	return bestT, bestAbs
end

local session = nil
local lockInFlight = false
local lastLockKey = ""
local scheduled = nil -- { t, axis, shot, nonce }

local function sessionKey(s)
	if type(s) ~= "table" then return "" end
	return string.format("%s:%s:%s", tostring(s.nonce), tostring(s.shotIndex), tostring(s.expectedAxis))
end

local function adoptSession(blob)
	if type(blob) ~= "table" then return end
	-- Accept full session or nested .session
	if type(blob.session) == "table" and blob.session.nonce then
		session = blob.session
	elseif blob.nonce and (blob.motion or blob.expectedAxis) then
		session = blob
	elseif type(blob.data) == "table" then
		adoptSession(blob.data)
		return
	else
		return
	end
	scheduled = nil
	lockInFlight = false
end

local function fireLock(axis, shotIndex, nonce, lockedAt)
	local key = string.format("%s:%s:%s", tostring(nonce), tostring(shotIndex), tostring(axis))
	if key == lastLockKey then
		return
	end
	lastLockKey = key
	lockInFlight = true

	local res = invokeAction("LockAxis", {
		nonce = nonce,
		shotIndex = shotIndex,
		axis = axis,
		lockedAt = lockedAt,
	})

	lockInFlight = false
	if res and res.ok then
		print(string.format(
			"[ProLocker] LOCKED %s shot=%s at t=%.3f |aim|~1",
			tostring(axis),
			tostring(shotIndex),
			lockedAt
		))
	else
		-- Allow one retry on next peak
		lastLockKey = ""
		warn("[ProLocker] rejected:", res and res.code or res)
	end
end

-- Heartbeat: schedule + fire at peak inside server timing window
RunService.Heartbeat:Connect(function()
	if type(session) ~= "table" or session.completed or session.finalizing then
		return
	end
	if lockInFlight then return end

	local motion = session.motion
	local axis = session.expectedAxis
	local nonce = session.nonce
	local shot = session.shotIndex
	if type(motion) ~= "table" or not axis or not nonce or not shot then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local peakT, peakAbs = nextPeakTime(motion, now)
	if not peakT then return end

	-- Prefer true peak; if prediction weak, fall back to live threshold
	local live = math.abs(evalMotion(motion, now))
	local targetT = peakT

	-- If we are already in the corner band, lock immediately (don't wait next cycle)
	if live >= CFG.GoalCorner then
		targetT = now
	end

	-- Wait until within a few frames of target
	local dt = targetT - now
	if dt > 0.045 then
		return
	end

	-- Clamp lockedAt into server acceptance window relative to "now"
	local lockedAt = math.clamp(targetT, now - CFG.MaxRewind, now + CFG.FutureTol)

	-- Only fire once per axis/shot
	local key = sessionKey(session)
	if key == lastLockKey then return end

	task.spawn(fireLock, axis, shot, nonce, lockedAt)
end)

local function onState(payload)
	if type(payload) ~= "table" then return end
	local kind = payload.kind or payload.Kind

	if kind == "SessionStarted" then
		adoptSession(payload)
		print("[ProLocker] Session started — peak locking armed")
	elseif kind == "AxisLocked" or kind == "ShotResolved" then
		adoptSession(payload)
		if kind == "ShotResolved" then
			local goal = payload.goal
			if goal == nil and type(payload.session) == "table" then
				goal = payload.scored or payload.wasGoal
			end
			print("[ProLocker] ShotResolved goal=", tostring(goal))
		end
	elseif kind == "SessionCompleted" then
		print("[ProLocker] COMPLETE", payload.confirmedGoals or payload.goals or "?")
		session = nil
		lastLockKey = ""
	elseif kind == "SessionCancelled" then
		session = nil
		lastLockKey = ""
	elseif kind == "Window" then
		-- ignore
	else
		adoptSession(payload)
	end
end

task.spawn(function()
	for _ = 1, 60 do
		if ensureRemotes() then break end
		task.wait(0.25)
	end
	if not StateRE then
		warn("[ProLocker] State remote missing")
		return
	end
	StateRE.OnClientEvent:Connect(onState)
	print("[ProLocker] Ready. Start penalty at midfield ball when window is open.")

	-- Pull current state if already mid-session
	task.wait(0.3)
	local st = invokeAction("GetState", nil)
	if type(st) == "table" then
		onState(st)
		if st.session then onState(st.session) end
		if st.kind then onState(st) end
	end
end)