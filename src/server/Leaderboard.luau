local Players = game:GetService("Players")
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))

local function leaderboardSetup(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 0
	cash.Parent = leaderstats

	local rebirth = Instance.new("IntValue")
	rebirth.Name = "Rebirth"
	rebirth.Value = 0
	rebirth.Parent = leaderstats

	local isPrimary = Instance.new("BoolValue")
	isPrimary.Name = "IsPrimary"
	isPrimary.Value = true
	isPrimary.Parent = cash

	task.wait(0.1)
	local stats = PlayerStats.get(player)
	if stats then
		rebirth.Value = stats.rebirth
	end
end

Players.PlayerAdded:Connect(leaderboardSetup)

for _, player in ipairs(Players:GetPlayers()) do
	leaderboardSetup(player)
end

return {}
