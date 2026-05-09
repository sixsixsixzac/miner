local LoadingScreen = {}

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local FADE_DURATION = 0.6
local BAR_TWEEN_DURATION = 0.35

local state = {
	gui = nil :: ScreenGui?,
	bg = nil :: Frame?,
	statusLabel = nil :: TextLabel?,
	percentLabel = nil :: TextLabel?,
	barFill = nil :: Frame?,
	currentProgress = 0,
	hidden = false,
}

local function safeRemoveDefault()
	pcall(function()
		ReplicatedFirst:RemoveDefaultLoadingScreen()
	end)
end

local function buildGui(): ScreenGui
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.Parent = playerGui

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
	bg.BorderSizePixel = 0
	bg.BackgroundTransparency = 0
	bg.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0, 0, 0.32, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "Roblox Mining"
	title.TextColor3 = Color3.fromRGB(240, 240, 245)
	title.TextScaled = true
	title.Parent = bg

	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MaxTextSize = 48
	titleSize.Parent = title

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, 0, 0, 30)
	statusLabel.Position = UDim2.new(0, 0, 0.5, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Text = "Loading..."
	statusLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
	statusLabel.TextScaled = true
	statusLabel.Parent = bg

	local barContainer = Instance.new("Frame")
	barContainer.Name = "BarContainer"
	barContainer.Size = UDim2.new(0.5, 0, 0, 18)
	barContainer.Position = UDim2.new(0.25, 0, 0.58, 0)
	barContainer.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
	barContainer.BorderSizePixel = 0
	barContainer.Parent = bg

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = barContainer

	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(80, 170, 255)
	barFill.BorderSizePixel = 0
	barFill.Parent = barContainer

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = barFill

	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 170, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 220, 255)),
	})
	fillGradient.Parent = barFill

	local percentLabel = Instance.new("TextLabel")
	percentLabel.Name = "Percent"
	percentLabel.Size = UDim2.new(0.5, 0, 0, 22)
	percentLabel.Position = UDim2.new(0.25, 0, 0.62, 0)
	percentLabel.BackgroundTransparency = 1
	percentLabel.Font = Enum.Font.GothamMedium
	percentLabel.Text = "0%"
	percentLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
	percentLabel.TextScaled = true
	percentLabel.Parent = bg

	state.gui = gui
	state.bg = bg
	state.statusLabel = statusLabel
	state.percentLabel = percentLabel
	state.barFill = barFill

	return gui
end

function LoadingScreen.show()
	if state.gui then
		return
	end
	safeRemoveDefault()
	buildGui()
end

function LoadingScreen.setStatus(text: string)
	if state.statusLabel then
		state.statusLabel.Text = text
	end
end

function LoadingScreen.setProgress(progress: number)
	progress = math.clamp(progress, 0, 1)
	if progress < state.currentProgress then
		return
	end
	state.currentProgress = progress
	if not state.barFill or not state.percentLabel then
		return
	end
	local targetSize = UDim2.new(progress, 0, 1, 0)
	TweenService:Create(
		state.barFill,
		TweenInfo.new(BAR_TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = targetSize }
	):Play()
	state.percentLabel.Text = string.format("%d%%", math.floor(progress * 100 + 0.5))
end

function LoadingScreen.hide()
	if state.hidden or not state.gui then
		return
	end
	state.hidden = true

	local gui = state.gui
	local bg = state.bg
	local barFill = state.barFill

	if barFill then
		TweenService:Create(
			barFill,
			TweenInfo.new(BAR_TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(1, 0, 1, 0) }
		):Play()
	end

	task.wait(0.1)

	if bg then
		local fadeInfo = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(bg, fadeInfo, { BackgroundTransparency = 1 }):Play()
		for _, child in ipairs(bg:GetDescendants()) do
			if child:IsA("TextLabel") then
				TweenService:Create(child, fadeInfo, { TextTransparency = 1 }):Play()
			elseif child:IsA("Frame") then
				TweenService:Create(child, fadeInfo, { BackgroundTransparency = 1 }):Play()
			end
		end
	end

	task.delay(FADE_DURATION + 0.1, function()
		if gui then
			gui:Destroy()
		end
		state.gui = nil
		state.bg = nil
		state.statusLabel = nil
		state.percentLabel = nil
		state.barFill = nil
	end)
end

return LoadingScreen
