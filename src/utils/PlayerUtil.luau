local PlayerUtil = {}

function PlayerUtil.getPlayerId(player: Player): number
	return player.UserId
end

function PlayerUtil.getPlayerName(player: Player): string
	return player.Name
end

function PlayerUtil.isPlayerValid(player: Player): boolean
	return player and player.Parent == game:GetService("Players")
end

function PlayerUtil.getPlayerCharacter(player: Player): Model?
	return player.Character
end

function PlayerUtil.getPlayerHumanoid(player: Player): Humanoid?
	local character = PlayerUtil.getPlayerCharacter(player)
	if not character then
		return nil
	end
	return character:FindFirstChild("Humanoid")
end

function PlayerUtil.getPlayerHumanoidRootPart(player: Player): BasePart?
	local character = PlayerUtil.getPlayerCharacter(player)
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

function PlayerUtil.isPlayerAlive(player: Player): boolean
	local humanoid = PlayerUtil.getPlayerHumanoid(player)
	return humanoid and humanoid.Health > 0
end

function PlayerUtil.getPlayerPosition(player: Player): Vector3?
	local rootPart = PlayerUtil.getPlayerHumanoidRootPart(player)
	return rootPart and rootPart.Position or nil
end

function PlayerUtil.teleportPlayer(player: Player, position: Vector3): boolean
	local rootPart = PlayerUtil.getPlayerHumanoidRootPart(player)
	if not rootPart then
		return false
	end
	rootPart.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	return true
end

return PlayerUtil
