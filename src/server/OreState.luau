local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local OreTypes = require(Shared:WaitForChild("OreTypes"))
local RemotesModule = require(Shared:WaitForChild("Remotes"))
local Remotes = RemotesModule.get()

local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))

local OreState = {}

local PLATFORMS_FOLDER_NAME = "OrePlatforms"

local config = nil
local sharedWorld: any = nil
local platformPool: { Part } = {}
local platformInUse: { [Part]: boolean } = {}
local playerPlatforms: { [number]: Part } = {}

local function ensurePool()
	if #platformPool > 0 then
		return
	end
	local folder = workspace:WaitForChild(PLATFORMS_FOLDER_NAME)
	local platforms = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(platforms, child)
		end
	end
	table.sort(platforms, function(a, b)
		return a.Name < b.Name
	end)
	for _, platform in ipairs(platforms) do
		table.insert(platformPool, platform)
	end
	if #platformPool == 0 then
		warn(string.format("[OreServer] no platforms found in workspace.%s", PLATFORMS_FOLDER_NAME))
	end
end

local function acquirePlatform(): Part?
	for _, part in ipairs(platformPool) do
		if not platformInUse[part] then
			platformInUse[part] = true
			return part
		end
	end
	return nil
end

local function releasePlatform(part: Part)
	platformInUse[part] = nil
end

local function shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(1, i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

local function buildGrid(platform: Part)
	local platformSize = platform.Size
	local platformPos = platform.Position
	local gridSpacing = config.gridSpacing

	local halfWidth = platformSize.X / 2
	local halfDepth = platformSize.Z / 2

	local startX = platformPos.X - halfWidth + gridSpacing / 2
	local startZ = platformPos.Z - halfDepth + gridSpacing / 2

	local slots = {}
	for x = startX, platformPos.X + halfWidth - gridSpacing / 2, gridSpacing do
		for z = startZ, platformPos.Z + halfDepth - gridSpacing / 2, gridSpacing do
			table.insert(slots, { x = x, z = z })
		end
	end

	local bottomY = platformPos.Y - platformSize.Y / 2
	local topY = platformPos.Y + platformSize.Y / 2
	return slots, bottomY, topY
end

local function activeCount(platformId: string): number
	local count = 0
	for _, ore in pairs(sharedWorld.ores) do
		if ore.platformId == platformId then
			count += 1
		end
	end
	return count
end

local function shouldSpawn(platformId: string): boolean
	if activeCount(platformId) >= config.maxBlocks then
		return false
	end
	local platformData = sharedWorld.platforms[platformId]
	if not platformData then
		return false
	end
	local player = platformData.player
	local stats = PlayerStats.get(player)
	local luck = (stats and stats.luck) or 1.0
	local adjusted = math.min(config.spawnChance * luck, 1.0)
	return math.random() <= adjusted
end

local function spawnOreAtSlot(slotIndex: number, platformId: string)
	local slot = sharedWorld.gridSlots[platformId][slotIndex]
	if not slot then
		return
	end
	if sharedWorld.occupiedSlots[platformId][slotIndex] then
		return
	end

	local platformData = sharedWorld.platforms[platformId]
	local player = platformData.player
	local stats = PlayerStats.get(player)
	if not stats then
		return
	end

	local oreType = OreTypes.pickRandomOreType(stats.level, stats.rebirth, stats.luck)
	local oreDef = OreTypes.get(oreType) or OreTypes.get("Stone")
	local maxHp = oreDef.maxHp or 1
	local oreId = sharedWorld.nextId
	sharedWorld.nextId += 1

	local oreSize = config.oreSize
	local startY = platformData.bottomY - oreSize.Y / 2
	local endY = platformData.topY + oreSize.Y / 2
	local position = Vector3.new(slot.x, endY, slot.z)
	local now = os.clock()

	sharedWorld.ores[oreId] = {
		type = oreType,
		position = position,
		state = "rising",
		spawnTime = now,
		mineableAt = now + config.riseDuration,
		startY = startY,
		endY = endY,
		slotIndex = slotIndex,
		platformId = platformId,
		size = oreSize,
		hp = maxHp,
		maxHp = maxHp,
	}
	sharedWorld.occupiedSlots[platformId][slotIndex] = oreId

	Remotes.OreSpawned:FireAllClients(oreId, oreType, position, startY, endY, config.riseDuration, oreSize, maxHp)

	local capturedToken = sharedWorld.runToken
	task.delay(config.riseDuration, function()
		if sharedWorld.runToken ~= capturedToken then
			return
		end
		local entry = sharedWorld.ores[oreId]
		if not entry or entry.state ~= "rising" then
			return
		end
		entry.state = "mineable"
		Remotes.OreMineable:FireAllClients(oreId)
	end)
end

local function startInitialSpawns(platformId: string)
	local gridSlots = sharedWorld.gridSlots[platformId]
	local indices = {}
	for i = 1, #gridSlots do
		indices[i] = i
	end
	shuffle(indices)

	local capturedToken = sharedWorld.runToken
	for order, slotIndex in ipairs(indices) do
		task.delay((order - 1) * config.spawnDelay, function()
			if sharedWorld.runToken ~= capturedToken then
				return
			end
			if shouldSpawn(platformId) then
				spawnOreAtSlot(slotIndex, platformId)
			end
		end)
	end
end

local function startRegenLoop()
	local capturedToken = sharedWorld.runToken
	task.spawn(function()
		while sharedWorld.runToken == capturedToken do
			task.wait(0.5)
			if sharedWorld.runToken ~= capturedToken then
				break
			end
			local now = os.clock()
			for oreId, info in pairs(sharedWorld.destroyed) do
				if now - info.time >= config.regenerationDelay then
					sharedWorld.destroyed[oreId] = nil
					local platformId = info.platformId
					local slotIndex = info.slotIndex
					local slots = sharedWorld.occupiedSlots[platformId]
					if slots and not slots[slotIndex] and shouldSpawn(platformId) then
						spawnOreAtSlot(slotIndex, platformId)
					end
				end
			end
		end
	end)
end

function OreState.beginPlayer(player: Player): Part?
	if playerPlatforms[player.UserId] then
		return playerPlatforms[player.UserId]
	end
	ensurePool()
	local platform = acquirePlatform()
	if not platform then
		warn(string.format("[OreServer] beginPlayer player=%s no free platform in pool", player.Name))
		return nil
	end

	if not sharedWorld then
		sharedWorld = {
			platforms = {},
			ores = {},
			destroyed = {},
			gridSlots = {},
			occupiedSlots = {},
			nextId = 1,
			runToken = {},
		}
		startRegenLoop()
	end

	local platformId = platform.Name
	local gridSlots, bottomY, topY = buildGrid(platform)

	sharedWorld.platforms[platformId] = {
		player = player,
		platform = platform,
		bottomY = bottomY,
		topY = topY,
	}
	sharedWorld.gridSlots[platformId] = gridSlots
	sharedWorld.occupiedSlots[platformId] = {}
	playerPlatforms[player.UserId] = platform

	platform:SetAttribute("ownerId", player.UserId)

	startInitialSpawns(platformId)
	print(string.format("[OreServer] world begin player=%s platform=%s", player.Name, platform.Name))
	return platform
end

function OreState.endPlayer(player: Player)
	local platform = playerPlatforms[player.UserId]
	if not platform then
		return
	end
	playerPlatforms[player.UserId] = nil
	releasePlatform(platform)
	local platformId = platform.Name
	sharedWorld.platforms[platformId] = nil
	sharedWorld.gridSlots[platformId] = nil
	sharedWorld.occupiedSlots[platformId] = nil

	for oreId, ore in pairs(sharedWorld.ores) do
		if ore.platformId == platformId then
			sharedWorld.ores[oreId] = nil
		end
	end

	platform:SetAttribute("ownerId", nil)

	print(string.format("[OreServer] world end player=%s", player.Name))
end

function OreState.getPlayerPlatform(player: Player): Part?
	return playerPlatforms[player.UserId] or nil
end

function OreState.tryMine(player: Player, oreId: number): boolean
	if typeof(oreId) ~= "number" then
		print(string.format("[OreServer] mine reject player=%s reason=bad-id value=%s", player.Name, tostring(oreId)))
		return false
	end
	if not sharedWorld then
		print(string.format("[OreServer] mine reject player=%s id=%d reason=no-world", player.Name, oreId))
		return false
	end
	local entry = sharedWorld.ores[oreId]
	if not entry then
		print(string.format("[OreServer] mine reject player=%s id=%d reason=unknown-id", player.Name, oreId))
		return false
	end

	local playerPlatform = playerPlatforms[player.UserId]
	if not playerPlatform or playerPlatform.Name ~= entry.platformId then
		print(string.format("[OreServer] mine reject player=%s id=%d reason=not-owner", player.Name, oreId))
		return false
	end

	if entry.state ~= "mineable" then
		print(string.format("[OreServer] mine reject player=%s id=%d type=%s reason=state-%s", player.Name, oreId, entry.type, entry.state))
		return false
	end
	local stats = PlayerStats.get(player)
	if not stats then
		print(string.format("[OreServer] mine reject player=%s id=%d reason=no-stats", player.Name, oreId))
		return false
	end
	if not OreTypes.canPlayerMine(stats.level, stats.rebirth, entry.type) then
		print(string.format("[OreServer] mine reject player=%s id=%d type=%s reason=gated lvl=%d reb=%d", player.Name, oreId, entry.type, stats.level, stats.rebirth))
		return false
	end

	local damage = math.max(1, math.floor(stats.damage or 1))
	entry.hp = entry.hp - damage
	if entry.hp > 0 then
		print(string.format("[OreServer] hit player=%s id=%d type=%s hp=%d/%d dmg=%d", player.Name, oreId, entry.type, entry.hp, entry.maxHp, damage))
		Remotes.OreDamaged:FireAllClients(oreId, entry.hp, entry.maxHp)
		return true
	end

	local slotIndex = entry.slotIndex
	local platformId = entry.platformId
	sharedWorld.ores[oreId] = nil
	sharedWorld.occupiedSlots[platformId][slotIndex] = nil
	sharedWorld.destroyed[oreId] = {
		time = os.clock(),
		slotIndex = slotIndex,
		platformId = platformId,
	}

	print(string.format("[OreServer] mined player=%s id=%d type=%s slot=%d", player.Name, oreId, entry.type, slotIndex))
	Remotes.OreDestroyed:FireAllClients(oreId, player)
	return true
end

function OreState.snapshotFor(player: Player)
	if not sharedWorld then
		return {
			ores = {},
			riseDuration = config.riseDuration,
			serverNow = os.clock(),
			platforms = {},
		}
	end
	local platform = playerPlatforms[player.UserId]
	local platformId = platform and platform.Name
	local snapshot = {}
	local now = os.clock()
	for oreId, entry in pairs(sharedWorld.ores) do
		if entry.platformId ~= platformId then
			continue
		end
		table.insert(snapshot, {
			id = oreId,
			type = entry.type,
			position = entry.position,
			state = entry.state,
			mineableAt = entry.mineableAt,
			startY = entry.startY,
			endY = entry.endY,
			size = entry.size,
			hp = entry.hp,
			maxHp = entry.maxHp,
			platformId = entry.platformId,
		})
	end

	local platforms = {}
	if platformId and sharedWorld.platforms[platformId] then
		local platformData = sharedWorld.platforms[platformId]
		table.insert(platforms, {
			id = platformId,
			position = platformData.platform.Position,
			size = platformData.platform.Size,
		})
	end

	return {
		ores = snapshot,
		riseDuration = config.riseDuration,
		serverNow = now,
		platforms = platforms,
	}
end

function OreState.getSharedWorld()
	return sharedWorld
end

function OreState.init(cfg)
	config = cfg
end

return OreState
