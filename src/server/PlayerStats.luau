local PlayerStats = {}

local stats: { [Player]: { level: number, rebirth: number, luck: number, damage: number, minerSpeed: number, minerDelay: number } } = {}

local DEFAULTS = {
	level = 1,
	rebirth = 0,
	luck = 1.0,
	damage = 1,
	minerSpeed = 6,
	minerDelay = 1.5,
}

function PlayerStats.set(player: Player, override: { level: number?, rebirth: number?, luck: number?, damage: number?, minerSpeed: number?, minerDelay: number? }?)
	local entry = {
		level = (override and override.level) or DEFAULTS.level,
		rebirth = (override and override.rebirth) or DEFAULTS.rebirth,
		luck = (override and override.luck) or DEFAULTS.luck,
		damage = (override and override.damage) or DEFAULTS.damage,
		minerSpeed = (override and override.minerSpeed) or DEFAULTS.minerSpeed,
		minerDelay = (override and override.minerDelay) or DEFAULTS.minerDelay,
	}
	stats[player] = entry
	return entry
end

function PlayerStats.get(player: Player)
	return stats[player]
end

function PlayerStats.update(player: Player, patch: { level: number?, rebirth: number?, luck: number?, damage: number?, minerSpeed: number?, minerDelay: number? })
	local entry = stats[player]
	if not entry then
		return nil
	end
	if patch.level then
		entry.level = patch.level
	end
	if patch.rebirth then
		entry.rebirth = patch.rebirth
	end
	if patch.luck then
		entry.luck = patch.luck
	end
	if patch.damage then
		entry.damage = patch.damage
	end
	if patch.minerSpeed then
		entry.minerSpeed = patch.minerSpeed
	end
	if patch.minerDelay then
		entry.minerDelay = patch.minerDelay
	end
	return entry
end

function PlayerStats.remove(player: Player)
	stats[player] = nil
end

return PlayerStats
