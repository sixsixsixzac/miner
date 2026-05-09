local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "OreRemotes"
local READY_ATTRIBUTE = "Ready"

local REMOTE_EVENTS = {
	"OreSpawned",
	"OreMineable",
	"OreDamaged",
	"OreDestroyed",
}

local REMOTE_FUNCTIONS = {
	"OreSnapshot",
	"MineOre",
}

local function ensureRemote(parent: Instance, className: string, name: string)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
if not folder then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
end

folder:SetAttribute(READY_ATTRIBUTE, false)

for _, name in ipairs(REMOTE_EVENTS) do
	ensureRemote(folder, "RemoteEvent", name)
end
for _, name in ipairs(REMOTE_FUNCTIONS) do
	ensureRemote(folder, "RemoteFunction", name)
end

folder:SetAttribute(READY_ATTRIBUTE, true)

print("[RemotesInit] OreRemotes folder ready")
