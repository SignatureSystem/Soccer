local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local flySpeed = 60          -- Change this to make it faster/slower
local flying = false

-- Detect when jump is pressed (works for both Space and the mobile jump button)
local function onJumpRequest()
	flying = true
end

-- Detect when jump is released
UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		flying = false
	end
end)

-- Mobile jump button release support
humanoid.StateChanged:Connect(function(_, newState)
	if newState \~= Enum.HumanoidStateType.Jumping and newState \~= Enum.HumanoidStateType.Freefall then
		flying = false
	end
end)

-- Listen for jump requests (this catches the original jump button)
humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
	if humanoid.Jump then
		flying = true
	end
end)

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	
	humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
		if humanoid.Jump then
			flying = true
		end
	end)
end)

-- Apply upward velocity while jump is held
RunService.RenderStepped:Connect(function()
	if not rootPart or not humanoid or humanoid.Health <= 0 then return end

	if flying then
		local velocity = rootPart.AssemblyLinearVelocity
		rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, flySpeed, velocity.Z)
		
		-- Prevent the normal jump from happening
		humanoid.Jump = false
	end
end)