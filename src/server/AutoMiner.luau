local TweenService = game:GetService("TweenService")

local OreState = require(script.Parent:WaitForChild("OreState"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))

local AutoMiner = {}

type MinerEntry = {
	runToken: {},
	model: Model,
	body: Part,
	drill: Part,
	beamX: Part,
	beamZ: Part,
	tweens: { any },
}

local miners: { [number]: MinerEntry } = {}

local function buildModel(platform: Part, heightAbove: number): (Model, Part, Part, Part, Part)
	local model = Instance.new("Model")
	model.Name = "AutoMiner"

	local px = platform.Position.X
	local pz = platform.Position.Z
	local topY = platform.Position.Y + platform.Size.Y / 2 + heightAbove
	local halfX = platform.Size.X / 2
	local halfZ = platform.Size.Z / 2

	local beamX = Instance.new("Part")
	beamX.Name = "BeamX"
	beamX.Size = Vector3.new(platform.Size.X, 0.5, 0.5)
	beamX.Color = Color3.fromRGB(109, 109, 109)
	beamX.Material = Enum.Material.Metal
	beamX.Anchored = true
	beamX.CanCollide = false
	beamX.CFrame = CFrame.new(px, topY + 0.75, pz)
	beamX.Parent = model

	local beamZ = Instance.new("Part")
	beamZ.Name = "BeamZ"
	beamZ.Size = Vector3.new(0.5, 0.5, platform.Size.Z)
	beamZ.Color = Color3.fromRGB(109, 109, 109)
	beamZ.Material = Enum.Material.Metal
	beamZ.Anchored = true
	beamZ.CanCollide = false
	beamZ.CFrame = CFrame.new(px, topY + 0.75, pz)
	beamZ.Parent = model

	local railNX = Instance.new("Part")
	railNX.Name = "RailNX"
	railNX.Size = Vector3.new(0.8, 0.8, platform.Size.Z)
	railNX.Color = Color3.fromRGB(60, 60, 60)
	railNX.Material = Enum.Material.Metal
	railNX.Anchored = true
	railNX.CanCollide = false
	railNX.CFrame = CFrame.new(px - halfX, topY + 0.75, pz)
	railNX.Parent = model

	local railPX = Instance.new("Part")
	railPX.Name = "RailPX"
	railPX.Size = Vector3.new(0.8, 0.8, platform.Size.Z)
	railPX.Color = Color3.fromRGB(60, 60, 60)
	railPX.Material = Enum.Material.Metal
	railPX.Anchored = true
	railPX.CanCollide = false
	railPX.CFrame = CFrame.new(px + halfX, topY + 0.75, pz)
	railPX.Parent = model

	local railNZ = Instance.new("Part")
	railNZ.Name = "RailNZ"
	railNZ.Size = Vector3.new(platform.Size.X, 0.8, 0.8)
	railNZ.Color = Color3.fromRGB(60, 60, 60)
	railNZ.Material = Enum.Material.Metal
	railNZ.Anchored = true
	railNZ.CanCollide = false
	railNZ.CFrame = CFrame.new(px, topY + 0.75, pz - halfZ)
	railNZ.Parent = model

	local railPZ = Instance.new("Part")
	railPZ.Name = "RailPZ"
	railPZ.Size = Vector3.new(platform.Size.X, 0.8, 0.8)
	railPZ.Color = Color3.fromRGB(60, 60, 60)
	railPZ.Material = Enum.Material.Metal
	railPZ.Anchored = true
	railPZ.CanCollide = false
	railPZ.CFrame = CFrame.new(px, topY + 0.75, pz + halfZ)
	railPZ.Parent = model

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 2, 2)
	body.Color = Color3.fromRGB(40, 40, 40)
	body.Material = Enum.Material.Metal
	body.Anchored = true
	body.CanCollide = false
	body.CFrame = CFrame.new(px, topY, pz)
	body.Parent = model

	local drill = Instance.new("Part")
	drill.Name = "Drill"
	drill.Size = Vector3.new(0.6, 2.5, 0.6)
	drill.Color = Color3.fromRGB(0, 255, 200)
	drill.Material = Enum.Material.Neon
	drill.Anchored = true
	drill.CanCollide = false
	drill.Transparency = 0.3
	drill.CFrame = CFrame.new(px, topY - 1.5, pz)
	drill.Parent = model

	model.PrimaryPart = body
	model.Parent = workspace

	return model, body, drill, beamX, beamZ
end

local function moveMiner(userId: number, targetX: number, targetZ: number, speed: number)
	local entry = miners[userId]
	if not entry then
		return
	end

	local body = entry.body
	local currentPos = body.Position
	local dx = targetX - currentPos.X
	local dz = targetZ - currentPos.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < 0.01 then
		return
	end
	local duration = dist / speed

	local tweens = {}

	local function addTween(part: Part, cx: number, cy: number, cz: number)
		local tween = TweenService:Create(
			part,
			TweenInfo.new(duration, Enum.EasingStyle.Linear),
			{ CFrame = CFrame.new(cx, cy, cz) }
		)
		table.insert(tweens, tween)
	end

	local bodyY = body.Position.Y
	addTween(body, targetX, bodyY, targetZ)

	local drill = entry.drill
	addTween(drill, targetX, drill.Position.Y, targetZ)

	local beamX = entry.beamX
	addTween(beamX, beamX.Position.X, beamX.Position.Y, targetZ)

	local beamZ = entry.beamZ
	addTween(beamZ, targetX, beamZ.Position.Y, beamZ.Position.Z)

	entry.tweens = tweens

	for _, tween in ipairs(tweens) do
		tween:Play()
	end
	task.wait(duration)

	if miners[userId] then
		miners[userId].tweens = {}
	end
end

local function playMineEffect(body: Part)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(0, 255, 200)
	light.Brightness = 8
	light.Range = 14
	light.Parent = body
	TweenService:Create(light, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
		Range = 0,
	}):Play()
	task.delay(0.7, function()
		if light.Parent then
			light:Destroy()
		end
	end)
end

function AutoMiner.start(player: Player, platform: Part, getWorld: () -> any, heightAbove: number)
	local token = {}

	local model, body, drill, beamX, beamZ = buildModel(platform, heightAbove)

	miners[player.UserId] = {
		runToken = token,
		model = model,
		body = body,
		drill = drill,
		beamX = beamX,
		beamZ = beamZ,
		tweens = {},
	}

	local platformId = platform.Name

	task.spawn(function()
		while miners[player.UserId] and miners[player.UserId].runToken == token do
			local world = getWorld()
			if not world then
				task.wait(0.5)
				continue
			end

			local bestOreId = nil
			local bestDist = math.huge
			local bodyPos = body.Position

			for oreId, ore in pairs(world.ores) do
				if ore.platformId ~= platformId then
					continue
				end
				if ore.state ~= "mineable" then
					continue
				end
				local dx = ore.position.X - bodyPos.X
				local dz = ore.position.Z - bodyPos.Z
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist < bestDist then
					bestDist = dist
					bestOreId = oreId
				end
			end

			if not bestOreId then
				task.wait(0.5)
				continue
			end

			if miners[player.UserId] == nil or miners[player.UserId].runToken ~= token then
				break
			end

			local ore = world.ores[bestOreId]
			if not ore then
				continue
			end

			local stats = PlayerStats.get(player)
			if not stats then
				task.wait(0.5)
				continue
			end
			moveMiner(player.UserId, ore.position.X, ore.position.Z, stats.minerSpeed)

			if miners[player.UserId] == nil or miners[player.UserId].runToken ~= token then
				break
			end

			task.wait(stats.minerDelay)

			if miners[player.UserId] == nil or miners[player.UserId].runToken ~= token then
				break
			end

			playMineEffect(body)

			local currentWorld = getWorld()
			if currentWorld and currentWorld.ores[bestOreId] and currentWorld.ores[bestOreId].state == "mineable" then
				OreState.tryMine(player, bestOreId)
			end
		end

		if miners[player.UserId] and miners[player.UserId].model then
			miners[player.UserId].model:Destroy()
		end
	end)
end

function AutoMiner.stop(player: Player)
	local entry = miners[player.UserId]
	if not entry then
		return
	end
	miners[player.UserId] = nil
	for _, tween in ipairs(entry.tweens) do
		tween:Cancel()
	end
	if entry.model then
		entry.model:Destroy()
	end
end

return AutoMiner
