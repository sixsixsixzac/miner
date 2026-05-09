local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemotesModule = require(Shared:WaitForChild("Remotes"))
local Remotes = RemotesModule.get()

local OreState = require(script:WaitForChild("OreState"))
local PlayerStats = require(script:WaitForChild("PlayerStats"))
local AutoMiner = require(script:WaitForChild("AutoMiner"))

local config = {
	gridSpacing = 4,
	oreSize = Vector3.new(4, 4, 4),
	riseDuration = 2,
	spawnDelay = 0.1,
	spawnChance = 1.0,
	maxBlocks = 10,
	regenerationDelay = 5,
	autoMinerSpeed = 12,
	autoMinerDelay = 1.5,
	autoMinerHeight = 12,
}

OreState.init(config)

local function placeCharacter(player: Player, platform: Part)
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local pos = platform.Position
	hrp.CFrame = CFrame.new(pos.X, pos.Y + platform.Size.Y / 2 + 5, pos.Z)
end

local function onPlayerAdded(player: Player)
	PlayerStats.set(player, nil)
	local platform = OreState.beginPlayer(player)

	local function onCharacter()
		task.wait(0.1)
		if platform then
			placeCharacter(player, platform)
		end
	end

	if platform then
		AutoMiner.start(player, platform, OreState.getSharedWorld, config.autoMinerHeight)
	end

	if player.Character then
		onCharacter()
	end
	player.CharacterAdded:Connect(onCharacter)
end

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	AutoMiner.stop(player)
	OreState.endPlayer(player)
	PlayerStats.remove(player)
end)

Remotes.OreSnapshot.OnServerInvoke = function(player)
	if not PlayerStats.get(player) then
		PlayerStats.set(player, nil)
	end
	if not OreState.getPlayerPlatform(player) then
		OreState.beginPlayer(player)
	end
	return OreState.snapshotFor(player)
end

Remotes.MineOre.OnServerInvoke = function(player, oreId)
	return OreState.tryMine(player, oreId)
end

print("Server initialized: per-player ore worlds")
