local OreState = require(script.Parent:WaitForChild("OreState"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))

local AutoMiner = {}

type MinerEntry = {
	runToken: {},
	model: Model,
	body: Part,
}

local miners: { [number]: MinerEntry } = {}

local function buildModel(platform: Part, heightAbove: number, initialSpeed: number): (Model, Part)
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

	model:SetAttribute("TargetX", px)
	model:SetAttribute("TargetZ", pz)
	model:SetAttribute("Speed", initialSpeed)
	model:SetAttribute("ServerOwned", true)

	model.PrimaryPart = body
	model.Parent = workspace

	return model, body
end

local function setMinerTarget(userId: number, targetX: number, targetZ: number, speed: number)
	local entry = miners[userId]
	if not entry then
		return
	end

	entry.model:SetAttribute("TargetX", targetX)
	entry.model:SetAttribute("TargetZ", targetZ)
	entry.model:SetAttribute("Speed", speed)
end

local function playMineEffect(body: Part)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(0, 255, 200)
	light.Brightness = 8
	light.Range = 14
	light.Parent = body
	task.wait(0.6)

	if light.Parent then
		light:Destroy()
	end
end

function AutoMiner.start(player: Player, platform: Part, getWorld: () -> any, heightAbove: number)
	local token = {}

	local initialStats = PlayerStats.get(player)
	local initialSpeed = if initialStats then initialStats.minerSpeed else 6
	local model, body = buildModel(platform, heightAbove, initialSpeed)

	miners[player.UserId] = {
		runToken = token,
		model = model,
		body = body,
	}

	local platformId = platform.Name
	local logicalPos = body.Position

	task.spawn(function()
		while miners[player.UserId] and miners[player.UserId].runToken == token do
			local world = getWorld()
			if not world then
				task.wait(0.5)
				continue
			end

			local bestOreId = nil
			local bestDist = math.huge

			for oreId, ore in pairs(world.ores) do
				if ore.platformId ~= platformId then
					continue
				end
				if ore.state ~= "mineable" then
					continue
				end
				local dx = ore.position.X - logicalPos.X
				local dz = ore.position.Z - logicalPos.Z

				local dist = math.sqrt(dx * dx + dz * dz)
				if dist < bestDist then
					bestDist = dist
					bestOreId = oreId
				end
			end

			if not bestOreId then
				setMinerTarget(player.UserId, logicalPos.X, logicalPos.Z, 0)
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
			setMinerTarget(player.UserId, ore.position.X, ore.position.Z, stats.minerSpeed)

			local dx = ore.position.X - logicalPos.X
			local dz = ore.position.Z - logicalPos.Z
			local dist = math.sqrt(dx * dx + dz * dz)
			local duration = dist / stats.minerSpeed

			local elapsed = 0
			local aborted = false
			while elapsed < duration do
				local dt = task.wait(0.1)
				elapsed += dt
				if miners[player.UserId] == nil or miners[player.UserId].runToken ~= token then
					aborted = true
					break
				end
				local w = getWorld()
				if not w or not w.ores[bestOreId] or w.ores[bestOreId].state ~= "mineable" then
					aborted = true
					break
				end
			end

			logicalPos = Vector3.new(ore.position.X, logicalPos.Y, ore.position.Z)

			if aborted then
				if miners[player.UserId] == nil or miners[player.UserId].runToken ~= token then
					break
				end
				setMinerTarget(player.UserId, logicalPos.X, logicalPos.Z, 0)
				continue
			end

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
	if entry.model then
		entry.model:Destroy()
	end
end

return AutoMiner
