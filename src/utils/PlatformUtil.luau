local PlatformUtil = {}

function PlatformUtil.getPlatformCenter(platform: Part): Vector3
	return platform.Position
end

function PlatformUtil.getPlatformSize(platform: Part): Vector3
	return platform.Size
end

function PlatformUtil.getPlatformBounds(platform: Part): (Vector3, Vector3)
	local pos = platform.Position
	local size = platform.Size
	local halfSize = size / 2

	local minBound = pos - halfSize
	local maxBound = pos + halfSize

	return minBound, maxBound
end

function PlatformUtil.isPointOnPlatform(platform: Part, point: Vector3): boolean
	local minBound, maxBound = PlatformUtil.getPlatformBounds(platform)

	return point.X >= minBound.X and point.X <= maxBound.X
		and point.Y >= minBound.Y and point.Y <= maxBound.Y
		and point.Z >= minBound.Z and point.Z <= maxBound.Z
end

function PlatformUtil.getRandomPointOnPlatform(platform: Part): Vector3
	local minBound, maxBound = PlatformUtil.getPlatformBounds(platform)

	local randomX = math.random(minBound.X * 100, maxBound.X * 100) / 100
	local randomZ = math.random(minBound.Z * 100, maxBound.Z * 100) / 100
	local y = platform.Position.Y + (platform.Size.Y / 2)

	return Vector3.new(randomX, y, randomZ)
end

return PlatformUtil
