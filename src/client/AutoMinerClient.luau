local TweenService = game:GetService("TweenService")

local AutoMinerClient = {}

type MinerWatch = {
	model: Model,
	tweens: { Tween },
	connection: RBXScriptConnection,
	lastSyncTime: number,
	lastTargetX: number?,
	lastTargetZ: number?,
}

local watched: { [Model]: MinerWatch } = {}

local function cancelTweens(watch: MinerWatch)
	for _, tween in ipairs(watch.tweens) do
		tween:Cancel()
	end
	watch.tweens = {}
end

local function checkSync(watch: MinerWatch)
	local currentTime = tick()
	local targetX = watch.model:GetAttribute("TargetX")
	local targetZ = watch.model:GetAttribute("TargetZ")
	
	-- Check if attributes haven't changed for more than 10 seconds
	if currentTime - watch.lastSyncTime > 10 then
		if targetX ~= watch.lastTargetX or targetZ ~= watch.lastTargetZ then
			-- Attributes changed, update sync time
			watch.lastSyncTime = currentTime
			watch.lastTargetX = targetX
			watch.lastTargetZ = targetZ
		else
			-- No sync for 10+ seconds, print warning
			warn("⚠️ AutoMiner sync lost: Server attributes not updating for model", watch.model:GetFullName())
		end
	end
end

local function tweenTo(part: Part, targetCFrame: CFrame, duration: number): Tween
	local info = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tween = TweenService:Create(part, info, { CFrame = targetCFrame })
	tween:Play()
	return tween
end

local function applyTarget(watch: MinerWatch)
	local model = watch.model
	local body = model:FindFirstChild("Body") :: Part
	if not body then
		return
	end

	local targetX = model:GetAttribute("TargetX")
	local targetZ = model:GetAttribute("TargetZ")
	local speed = model:GetAttribute("Speed")

	if not targetX or not targetZ or not speed or speed <= 0 then
		cancelTweens(watch)
		return
	end

	-- Check for sync issues
	checkSync(watch)

	local pos = body.Position
	local dx = targetX - pos.X
	local dz = targetZ - pos.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	local duration = dist / speed

	if duration < 0.01 then
		return
	end

	cancelTweens(watch)

	local newTweens: { Tween } = {}

	local drill = model:FindFirstChild("Drill") :: Part
	local beamX = model:FindFirstChild("BeamX") :: Part
	local beamZ = model:FindFirstChild("BeamZ") :: Part

	local bodyTarget = CFrame.new(targetX, pos.Y, targetZ)
	table.insert(newTweens, tweenTo(body, bodyTarget, duration))

	if drill then
		local drillPos = drill.Position
		local drillTarget = CFrame.new(targetX, drillPos.Y, targetZ)
		table.insert(newTweens, tweenTo(drill, drillTarget, duration))
	end

	if beamX then
		local bPos = beamX.Position
		local bTarget = CFrame.new(bPos.X, bPos.Y, targetZ)
		table.insert(newTweens, tweenTo(beamX, bTarget, duration))
	end

	if beamZ then
		local bPos = beamZ.Position
		local bTarget = CFrame.new(targetX, bPos.Y, bPos.Z)
		table.insert(newTweens, tweenTo(beamZ, bTarget, duration))
	end

	watch.tweens = newTweens
end

local function isServerOwned(model: Model): boolean
	return model:GetAttribute("ServerOwned") == true
end

local function watchModel(model: Model)
	if watched[model] then
		return
	end
	if not isServerOwned(model) then
		return
	end

	local currentTime = tick()
	local targetX = model:GetAttribute("TargetX")
	local targetZ = model:GetAttribute("TargetZ")

	local watch: MinerWatch = {
		model = model,
		tweens = {},
		connection = nil :: any,
		lastSyncTime = currentTime,
		lastTargetX = targetX,
		lastTargetZ = targetZ,
	}

	watch.connection = model.AttributeChanged:Connect(function(attr)
		if attr == "TargetX" or attr == "TargetZ" or attr == "Speed" then
			applyTarget(watch)
		end
	end)

	watched[model] = watch
	applyTarget(watch)
end

local function unwatchModel(model: Model)
	local watch = watched[model]
	if not watch then
		return
	end
	cancelTweens(watch)
	watch.connection:Disconnect()
	watched[model] = nil
end

function AutoMinerClient.start()
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model") and child.Name == "AutoMiner" then
			watchModel(child :: Model)
		end
	end

	workspace.ChildAdded:Connect(function(child)
		if child:IsA("Model") and child.Name == "AutoMiner" then
			watchModel(child :: Model)
		end
	end)

	workspace.ChildRemoved:Connect(function(child)
		if child:IsA("Model") and child.Name == "AutoMiner" then
			unwatchModel(child :: Model)
		end
	end)
end

return AutoMinerClient
