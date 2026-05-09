local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemotesModule = require(Shared:WaitForChild("Remotes"))
local Remotes = RemotesModule.get()

local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))

local AutoMiner = {}

type MinerEntry = {
	model: Model,
	body: Part,
}

local miners: { [number]: MinerEntry } = {}

local function buildModel(platform: Part, heightAbove: number, ownerUserId: number, level: number): (Model, Part)
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

	local body: Part
	local drill: Part

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		local minerModels = assets:FindFirstChild("MinerModels")
		if minerModels then
			local bodysFolder = minerModels:FindFirstChild("Bodys")
			local drillsFolder = minerModels:FindFirstChild("Drills")

			local levelStr = tostring(level)
			local bodyTemplate = bodysFolder and bodysFolder:FindFirstChild("Body_" .. levelStr)
			local drillTemplate = drillsFolder and drillsFolder:FindFirstChild("Drill_" .. levelStr)

			if bodyTemplate and bodyTemplate:IsA("BasePart") then
				body = bodyTemplate:Clone()
				body.Name = "Body"
				body.Anchored = true
				body.CanCollide = false
				body.CFrame = CFrame.new(px, topY, pz)
				body.Parent = model
			elseif bodyTemplate and bodyTemplate:IsA("Model") then
				local clone = bodyTemplate:Clone()
				for _, desc in ipairs(clone:GetDescendants()) do
					if desc:IsA("BasePart") then
						desc.Anchored = true
						desc.CanCollide = false
					end
				end
				clone:PivotTo(CFrame.new(px, topY, pz))
				local part = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
				if part then
					part.Name = "Body"
					part.Parent = model
					body = part
				end
				clone:Destroy()
			else
				body = Instance.new("Part")
				body.Name = "Body"
				body.Size = Vector3.new(2, 2, 2)
				body.Color = Color3.fromRGB(40, 40, 40)
				body.Material = Enum.Material.Metal
				body.Anchored = true
				body.CanCollide = false
				body.CFrame = CFrame.new(px, topY, pz)
				body.Parent = model
			end

			if drillTemplate and drillTemplate:IsA("BasePart") then
				drill = drillTemplate:Clone()
				drill.Name = "Drill"
				drill.Anchored = true
				drill.CanCollide = false
				drill.CFrame = CFrame.new(px, topY - 1.5, pz)
				drill.Parent = model
			elseif drillTemplate and drillTemplate:IsA("Model") then
				local clone = drillTemplate:Clone()
				for _, desc in ipairs(clone:GetDescendants()) do
					if desc:IsA("BasePart") then
						desc.Anchored = true
						desc.CanCollide = false
					end
				end
				clone:PivotTo(CFrame.new(px, topY - 1.5, pz))
				local part = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
				if part then
					part.Name = "Drill"
					part.Parent = model
					drill = part
				end
				clone:Destroy()
			else
				drill = Instance.new("Part")
				drill.Name = "Drill"
				drill.Size = Vector3.new(0.6, 2.5, 0.6)
				drill.Color = Color3.fromRGB(0, 255, 200)
				drill.Material = Enum.Material.Neon
				drill.Anchored = true
				drill.CanCollide = false
				drill.Transparency = 0.3
				drill.CFrame = CFrame.new(px, topY - 1.5, pz)
				drill.Parent = model
			end
		else
			body = Instance.new("Part")
			body.Name = "Body"
			body.Size = Vector3.new(2, 2, 2)
			body.Color = Color3.fromRGB(40, 40, 40)
			body.Material = Enum.Material.Metal
			body.Anchored = true
			body.CanCollide = false
			body.CFrame = CFrame.new(px, topY, pz)
			body.Parent = model

			drill = Instance.new("Part")
			drill.Name = "Drill"
			drill.Size = Vector3.new(0.6, 2.5, 0.6)
			drill.Color = Color3.fromRGB(0, 255, 200)
			drill.Material = Enum.Material.Neon
			drill.Anchored = true
			drill.CanCollide = false
			drill.Transparency = 0.3
			drill.CFrame = CFrame.new(px, topY - 1.5, pz)
			drill.Parent = model
		end
	else
		body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(2, 2, 2)
		body.Color = Color3.fromRGB(40, 40, 40)
		body.Material = Enum.Material.Metal
		body.Anchored = true
		body.CanCollide = false
		body.CFrame = CFrame.new(px, topY, pz)
		body.Parent = model

		drill = Instance.new("Part")
		drill.Name = "Drill"
		drill.Size = Vector3.new(0.6, 2.5, 0.6)
		drill.Color = Color3.fromRGB(0, 255, 200)
		drill.Material = Enum.Material.Neon
		drill.Anchored = true
		drill.CanCollide = false
		drill.Transparency = 0.3
		drill.CFrame = CFrame.new(px, topY - 1.5, pz)
		drill.Parent = model
	end

	model:SetAttribute("TargetX", px)
	model:SetAttribute("TargetZ", pz)
	model:SetAttribute("Speed", 0)
	model:SetAttribute("OwnerUserId", ownerUserId)

	model.PrimaryPart = body
	model.Parent = platform

	return model, body
end

function AutoMiner.start(player: Player, platform: Part, heightAbove: number)
	local stats = PlayerStats.get(player)
	local playerLevel = if stats then stats.level else 1

	local model, body = buildModel(platform, heightAbove, player.UserId, playerLevel)

	miners[player.UserId] = {
		model = model,
		body = body,
	}
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

function AutoMiner.broadcastStats(player: Player)
	local stats = PlayerStats.get(player)
	if not stats then
		return
	end
	Remotes.MyMinerStats:FireClient(player, stats.minerSpeed, stats.minerDelay)
end

function AutoMiner.updateStats(player: Player)
	if not miners[player.UserId] then
		return
	end
	AutoMiner.broadcastStats(player)
end

Remotes.SetMinerTarget.OnServerEvent:Connect(function(player, targetX, targetZ, speed)
	if typeof(targetX) ~= "number" or typeof(targetZ) ~= "number" or typeof(speed) ~= "number" then
		return
	end
	if targetX ~= targetX or targetZ ~= targetZ or speed ~= speed then
		return
	end
	local entry = miners[player.UserId]
	if not entry then
		return
	end
	entry.model:SetAttribute("TargetX", targetX)
	entry.model:SetAttribute("TargetZ", targetZ)
	entry.model:SetAttribute("Speed", math.max(0, speed))
end)

return AutoMiner
