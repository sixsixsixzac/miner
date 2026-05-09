local HttpService = game:GetService("HttpService")

local Backpack = {}

local MAX_ORE_CAPACITY = 100

export type BackpackEntry = {
	ores: { [string]: number },
	capacity: number,
}

local backpacks: { [Player]: BackpackEntry } = {}

local function printBackpack(player: Player, entry: BackpackEntry)
	local ok, json = pcall(function()
		return HttpService:JSONEncode({
			player = player.Name,
			ores = entry.ores,
			capacity = entry.capacity,
		})
	end)
	if ok then
		print(string.format("[Backpack] update %s", json))
	end
end

function Backpack.set(player: Player)
	backpacks[player] = {
		ores = {},
		capacity = MAX_ORE_CAPACITY,
	}
end

function Backpack.get(player: Player): BackpackEntry?
	return backpacks[player]
end

function Backpack.addOre(player: Player, oreType: string, amount: number?): boolean
	local entry = backpacks[player]
	if not entry then
		return false
	end
	local qty = amount or 1
	local current = 0
	for _, count in pairs(entry.ores) do
		current += count
	end
	local space = entry.capacity - current
	if space <= 0 then
		print(string.format("[Backpack] full player=%s oreType=%s", player.Name, oreType))
		return false
	end
	local added = math.min(qty, space)
	entry.ores[oreType] = (entry.ores[oreType] or 0) + added
	printBackpack(player, entry)
	return added == qty
end

function Backpack.removeOre(player: Player, oreType: string, amount: number?): boolean
	local entry = backpacks[player]
	if not entry then
		return false
	end
	local qty = amount or 1
	local have = entry.ores[oreType] or 0
	if have < qty then
		return false
	end
	local newQty = have - qty
	if newQty == 0 then
		entry.ores[oreType] = nil
	else
		entry.ores[oreType] = newQty
	end
	printBackpack(player, entry)
	return true
end

function Backpack.totalOres(player: Player): number
	local entry = backpacks[player]
	if not entry then
		return 0
	end
	local total = 0
	for _, count in pairs(entry.ores) do
		total += count
	end
	return total
end

function Backpack.remove(player: Player)
	backpacks[player] = nil
end

return Backpack
