local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemotesModule = require(Shared:WaitForChild("Remotes"))
local remotes = RemotesModule.get()

local OreManager = require(script.Parent:WaitForChild("OreManager"))

local AutoMinerClient = {}

local LocalPlayer = Players.LocalPlayer

type MinerWatch = {
	model: Model,
	tweens: { Tween },
	connection: RBXScriptConnection,
	ownerLoopRunning: boolean,
}

local watched: { [Model]: MinerWatch } = {}

local myMinerSpeed: number = 6
local myMinerDelay: number = 1.5

remotes.MyMinerStats.OnClientEvent:Connect(function(minerSpeed, minerDelay)
	if typeof(minerSpeed) == "number" then
		myMinerSpeed = minerSpeed
	end
	if typeof(minerDelay) == "number" then
		myMinerDelay = minerDelay
	end
end)

local function cancelTweens(watch: MinerWatch)
	for _, tween in ipairs(watch.tweens) do
		tween:Cancel()
	end
	watch.tweens = {}
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

local function isOwnedByLocalPlayer(model: Model): boolean
	return model:GetAttribute("OwnerUserId") == LocalPlayer.UserId
end

local function isOnPlatform(orePos: Vector3, platform: BasePart): boolean
	local pp = platform.Position
	local ps = platform.Size
	local hx = ps.X / 2
	local hz = ps.Z / 2
	return orePos.X >= pp.X - hx
		and orePos.X <= pp.X + hx
		and orePos.Z >= pp.Z - hz
		and orePos.Z <= pp.Z + hz
end

local function findNearestMineable(bodyPos: Vector3, platform: BasePart?): (number?, number)
	local bestId: number? = nil
	local bestDist = math.huge
	for oreId, entry in pairs(OreManager.all()) do
		if not entry.isMineable or not entry.part or not entry.part.Parent then
			continue
		end
		local p = entry.part.Position
		if platform and not isOnPlatform(p, platform) then
			continue
		end
		local dx = p.X - bodyPos.X
		local dz = p.Z - bodyPos.Z
		local dist = math.sqrt(dx * dx + dz * dz)
		if dist < bestDist then
			bestDist = dist
			bestId = oreId
		end
	end
	return bestId, bestDist
end

local function runOwnerLoop(watch: MinerWatch)
	if watch.ownerLoopRunning then
		return
	end
	watch.ownerLoopRunning = true

	task.spawn(function()
		local model = watch.model
		local platform = model.Parent and model.Parent:IsA("BasePart") and model.Parent :: BasePart or nil

		while watched[model] == watch and model.Parent do
			local body = model:FindFirstChild("Body") :: Part
			if not body then
				task.wait(0.3)
				continue
			end

			local minerSpeed = myMinerSpeed
			local minerDelay = myMinerDelay

			local bestId, bestDist = findNearestMineable(body.Position, platform)

			if not bestId then
				remotes.SetMinerTarget:FireServer(body.Position.X, body.Position.Z, 0)
				task.wait(0.5)
				continue
			end

			local targetEntry = OreManager.get(bestId)
			if not targetEntry or not targetEntry.part then
				task.wait(0.1)
				continue
			end
			local targetPos = targetEntry.part.Position

			remotes.SetMinerTarget:FireServer(targetPos.X, targetPos.Z, minerSpeed)

			local duration = bestDist / minerSpeed
			local elapsed = 0
			local aborted = false
			while elapsed < duration do
				local dt = task.wait(0.1)
				elapsed += dt
				if watched[model] ~= watch or not model.Parent then
					aborted = true
					break
				end
				local cur = OreManager.get(bestId)
				if not cur or not cur.isMineable then
					aborted = true
					break
				end
			end

			if aborted then
				continue
			end

			task.wait(minerDelay)

			if watched[model] ~= watch or not model.Parent then
				break
			end

			local cur = OreManager.get(bestId)
			if cur and cur.isMineable then
				task.spawn(function()
					pcall(function()
						remotes.MineOre:InvokeServer(bestId)
					end)
				end)
			end
		end

		watch.ownerLoopRunning = false
	end)
end

local function watchModel(model: Model)
	if watched[model] then
		return
	end

	local watch: MinerWatch = {
		model = model,
		tweens = {},
		connection = nil :: any,
		ownerLoopRunning = false,
	}

	watch.connection = model.AttributeChanged:Connect(function(attr)
		if attr == "TargetX" or attr == "TargetZ" or attr == "Speed" then
			applyTarget(watch)
		elseif attr == "OwnerUserId" and isOwnedByLocalPlayer(model) then
			runOwnerLoop(watch)
		end
	end)

	watched[model] = watch
	applyTarget(watch)

	if isOwnedByLocalPlayer(model) then
		runOwnerLoop(watch)
	end
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
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "AutoMiner" then
			watchModel(descendant :: Model)
		end
	end

	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Model") and descendant.Name == "AutoMiner" then
			watchModel(descendant :: Model)
		end
	end)

	workspace.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("Model") and descendant.Name == "AutoMiner" then
			unwatchModel(descendant :: Model)
		end
	end)
end

return AutoMinerClient
