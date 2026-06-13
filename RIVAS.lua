local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local isAiming = false
local isAimbotEnabled = true
local ignoredPlayers = {}
local currentTarget = nil

local spamClickEnabled = true
local spamState = false
local lastClick = 0
local clickDelay = 0.03
local holdingClick = false

local highlightSyncTick = 0
local highlightSyncRate = 0.2

local function Notify(message)
	StarterGui:SetCore("SendNotification", {
		Title = "Aim Assist",
		Text = message,
		Duration = 10
	})
end

Notify("Script khởi động! Giữ chuột phải để nhắm.\nNhấn [Y] để bật/tắt aimbot.\nNhấn [B] để loại bỏ người chơi gần.\nNhấn [N] để thêm lại tất cả.\nNhấn [H] để bật/tắt animation.")

local function IsIgnored(player)
	return ignoredPlayers[player] == true
end

local function ClearIgnoredPlayers()
	ignoredPlayers = {}
	Notify("Đã thêm lại tất cả người chơi vào aimbot.")
end

local function RemovePlayersInRange()
	local character = LocalPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local playerPosition = character.HumanoidRootPart.Position
	local removedCount = 0

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= LocalPlayer and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (otherPlayer.Character.HumanoidRootPart.Position - playerPosition).Magnitude
			if distance <= 70 then
				ignoredPlayers[otherPlayer] = true
				removedCount += 1
			end
		end
	end

	Notify("Đã loại bỏ " .. removedCount .. " người chơi trong phạm vi 70m khỏi aimbot.")
end

local function RemoveESP(player)
	if not player or not player.Character then
		return
	end

	local highlight = player.Character:FindFirstChild("ESP_Highlight")
	if highlight then
		highlight:Destroy()
	end
end

local function EnsureESP(player)
	if not player or not player.Character then
		return
	end

	if IsIgnored(player) then
		RemoveESP(player)
		return
	end

	local character = player.Character
	local highlight = character:FindFirstChild("ESP_Highlight")

	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "ESP_Highlight"
		highlight.FillTransparency = 1
		highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = character
	end
end

local function SyncAllESP()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			EnsureESP(player)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		EnsureESP(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer then
		player.CharacterAdded:Connect(function()
			task.wait(0.1)
			EnsureESP(player)
		end)
	end
end

local function IsVisible(targetPlayer)
	local myChar = LocalPlayer.Character
	local targetChar = targetPlayer and targetPlayer.Character
	if not myChar or not targetChar then
		return false
	end

	local myHead = myChar:FindFirstChild("Head")
	local targetHead = targetChar:FindFirstChild("Head")
	if not myHead or not targetHead then
		return false
	end

	local origin = myHead.Position
	local direction = targetHead.Position - origin
	if direction.Magnitude <= 0 then
		return true
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = { myChar }
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, direction, params)
	if not result then
		return true
	end

	return result.Instance and result.Instance:IsDescendantOf(targetChar)
end

local function GetClosestPlayerToCenter()
	local closestPlayer = nil
	local closestDistance = math.huge
	local crosshairPosition = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local maxRadius = 200

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= LocalPlayer and not IsIgnored(otherPlayer) and otherPlayer.Character and otherPlayer.Character:FindFirstChild("Head") then
			if IsVisible(otherPlayer) then
				local head = otherPlayer.Character.Head
				local screenPoint, onScreen = Camera:WorldToViewportPoint(head.Position)
				if onScreen then
					local screenPos = Vector2.new(screenPoint.X, screenPoint.Y)
					local distance = (screenPos - crosshairPosition).Magnitude
					if distance < closestDistance and distance <= maxRadius then
						closestDistance = distance
						closestPlayer = otherPlayer
					end
				end
			end
		end
	end

	return closestPlayer
end

local function GetClosestPlayerToPlayer()
	local closestPlayer = nil
	local closestDistance = math.huge
	local character = LocalPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return nil
	end

	local playerPosition = character.HumanoidRootPart.Position

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= LocalPlayer and not IsIgnored(otherPlayer) and otherPlayer.Character and otherPlayer.Character:FindFirstChild("Head") then
			if IsVisible(otherPlayer) then
				local head = otherPlayer.Character.Head
				local distance = (head.Position - playerPosition).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestPlayer = otherPlayer
				end
			end
		end
	end

	return closestPlayer
end

local function sendClick(isDown)
	local m = UserInputService:GetMouseLocation()
	VirtualInputManager:SendMouseButtonEvent(m.X, m.Y, 0, isDown, game, 0)
end

local function UpdateSpamClick(target)
	if not spamClickEnabled then
		if holdingClick then
			sendClick(false)
			holdingClick = false
		end
		if spamState then
			sendClick(false)
			spamState = false
		end
		return
	end

	local active = isAiming and isAimbotEnabled and target and target.Character and target.Character:FindFirstChild("Head")

	if active then
		if tick() - lastClick >= clickDelay then
			lastClick = tick()
			spamState = not spamState
			sendClick(spamState)
		end
	else
		if holdingClick then
			sendClick(false)
			holdingClick = false
		end
		if spamState then
			sendClick(false)
			spamState = false
		end
	end
end

local function UpdateAim()
	if isAiming and isAimbotEnabled then
		local target = GetClosestPlayerToCenter()

		if target ~= currentTarget then
			currentTarget = target
		end

		if target and target.Character and target.Character:FindFirstChild("Head") then
			local headPosition = target.Character.Head.Position
			Camera.CFrame = CFrame.new(Camera.CFrame.Position, headPosition)
		end

		UpdateSpamClick(target)
	else
		currentTarget = nil
		UpdateSpamClick(nil)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isAiming = true
	elseif input.KeyCode == Enum.KeyCode.Y then
		isAimbotEnabled = not isAimbotEnabled
		Notify("Aimbot: " .. (isAimbotEnabled and "Bật" or "Tắt"))
		if not isAimbotEnabled then
			currentTarget = nil
		end
	elseif input.KeyCode == Enum.KeyCode.B then
		RemovePlayersInRange()
	elseif input.KeyCode == Enum.KeyCode.N then
		ClearIgnoredPlayers()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isAiming = false
		currentTarget = nil
		UpdateSpamClick(nil)
	end
end)

RunService.RenderStepped:Connect(function()
	local now = tick()

	UpdateAim()

	if now - highlightSyncTick >= highlightSyncRate then
		highlightSyncTick = now
		SyncAllESP()
	end
end)

local AnimationId = "rbxassetid://507770818"
local Animation
local AnimationTrack

local function LoadAnimation(character)
	local Humanoid = character:WaitForChild("Humanoid", 5)
	if not Humanoid then
		return
	end

	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Parent = Humanoid
	end

	Animation = Instance.new("Animation")
	Animation.AnimationId = AnimationId
	AnimationTrack = Animator:LoadAnimation(Animation)
end

local function onInputBegan(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then
		return
	end

	if input.KeyCode == Enum.KeyCode.H and AnimationTrack then
		if AnimationTrack.IsPlaying then
			AnimationTrack:Stop()
		else
			AnimationTrack:Play()
		end
	end
end

LocalPlayer.CharacterAdded:Connect(function(character)
	LoadAnimation(character)
	task.wait(0.2)
	SyncAllESP()
end)

UserInputService.InputBegan:Connect(onInputBegan)

if LocalPlayer.Character then
	LoadAnimation(LocalPlayer.Character)
	task.wait(0.2)
	SyncAllESP()
end
