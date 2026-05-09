local OreManager = {}

local oresById = {}

function OreManager.add(oreId: number, part: Part, oreType: string)
	local entry = {
		id = oreId,
		part = part,
		type = oreType,
		isMineable = false,
	}
	oresById[oreId] = entry
	return entry
end

function OreManager.get(oreId: number)
	return oresById[oreId]
end

function OreManager.remove(oreId: number)
	local entry = oresById[oreId]
	if not entry then
		return
	end
	if entry.part then
		entry.part:Destroy()
	end
	oresById[oreId] = nil
end

function OreManager.clear()
	for oreId, entry in pairs(oresById) do
		if entry.part then
			entry.part:Destroy()
		end
		oresById[oreId] = nil
	end
end

function OreManager.all()
	return oresById
end

return OreManager