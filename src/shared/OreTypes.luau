local OreTypes = {}

OreTypes.Definitions = {
	Stone = {
		color = Color3.fromRGB(128, 128, 128),
		material = Enum.Material.Concrete,
		rarity = 1.0,
		minLevel = 1,
		minRebirth = 0,
		maxHp = 1,
	},
	Coal = {
		color = Color3.fromRGB(30, 30, 30),
		material = Enum.Material.Rock,
		rarity = 0.8,
		minLevel = 5,
		minRebirth = 0,
		maxHp = 2,
	},
	Iron = {
		color = Color3.fromRGB(180, 180, 200),
		material = Enum.Material.Metal,
		rarity = 0.6,
		minLevel = 15,
		minRebirth = 0,
		maxHp = 4,
	},
	Gold = {
		color = Color3.fromRGB(255, 200, 0),
		material = Enum.Material.Metal,
		rarity = 0.1,
		minLevel = 30,
		minRebirth = 0,
		maxHp = 6,
	},
	Diamond = {
		color = Color3.fromRGB(150, 220, 255),
		material = Enum.Material.Glass,
		rarity = 0.05,
		minLevel = 50,
		minRebirth = 1,
		maxHp = 10,
	},
}

function OreTypes.get(typeName: string)
	return OreTypes.Definitions[typeName]
end

function OreTypes.canSpawnOreType(level: number, rebirth: number, typeName: string): boolean
	local def = OreTypes.Definitions[typeName]
	if not def then
		return false
	end
	return level >= def.minLevel and rebirth >= def.minRebirth
end

function OreTypes.canPlayerMine(playerLevel: number, playerRebirth: number, typeName: string): boolean
	return true
end

function OreTypes.pickRandomOreType(level: number, rebirth: number, luck: number?): string
	luck = luck or 1.0

	local belowLevelChance = math.min(0.01 * luck, 0.1)
	if math.random() < belowLevelChance then
		local allTypes = {}
		for typeName in pairs(OreTypes.Definitions) do
			table.insert(allTypes, typeName)
		end
		return allTypes[math.random(1, #allTypes)]
	end

	local typeNames = {}
	local weights = {}

	for typeName, typeData in pairs(OreTypes.Definitions) do
		if OreTypes.canSpawnOreType(level, rebirth, typeName) then
			table.insert(typeNames, typeName)
			table.insert(weights, typeData.rarity)
		end
	end

	if #typeNames == 0 then
		return "Stone"
	end

	local totalWeight = 0
	for _, weight in ipairs(weights) do
		totalWeight = totalWeight + weight
	end

	local random = math.random() * totalWeight
	local accumulated = 0

	for i, weight in ipairs(weights) do
		accumulated = accumulated + weight
		if random <= accumulated then
			return typeNames[i]
		end
	end

	return typeNames[1]
end

return OreTypes
