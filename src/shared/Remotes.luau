local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "OreRemotes"
local READY_ATTRIBUTE = "Ready"

local Remotes = {}

local cached: {
	OreSpawned: RemoteEvent,
	OreMineable: RemoteEvent,
	OreDamaged: RemoteEvent,
	OreDestroyed: RemoteEvent,
	SetMinerTarget: RemoteEvent,
	MyMinerStats: RemoteEvent,
	OreSnapshot: RemoteFunction,
	MineOre: RemoteFunction,
}? = nil

local function waitForReady(folder: Folder)
	if folder:GetAttribute(READY_ATTRIBUTE) == true then
		return
	end
	local conn
	local done = false
	conn = folder:GetAttributeChangedSignal(READY_ATTRIBUTE):Connect(function()
		if folder:GetAttribute(READY_ATTRIBUTE) == true then
			done = true
		end
	end)
	while not done do
		if folder:GetAttribute(READY_ATTRIBUTE) == true then
			break
		end
		task.wait(0.05)
	end
	if conn then
		conn:Disconnect()
	end
end

local function resolveFolder(): Folder
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	if RunService:IsClient() then
		waitForReady(folder)
	end
	return folder
end

local function buildCache(folder: Folder)
	cached = {
		OreSpawned = folder:WaitForChild("OreSpawned") :: RemoteEvent,
		OreMineable = folder:WaitForChild("OreMineable") :: RemoteEvent,
		OreDamaged = folder:WaitForChild("OreDamaged") :: RemoteEvent,
		OreDestroyed = folder:WaitForChild("OreDestroyed") :: RemoteEvent,
		SetMinerTarget = folder:WaitForChild("SetMinerTarget") :: RemoteEvent,
		MyMinerStats = folder:WaitForChild("MyMinerStats") :: RemoteEvent,
		OreSnapshot = folder:WaitForChild("OreSnapshot") :: RemoteFunction,
		MineOre = folder:WaitForChild("MineOre") :: RemoteFunction,
	}
end

function Remotes.get()
	if cached then
		return cached
	end
	local folder = resolveFolder()
	buildCache(folder)
	return cached
end

function Remotes.isReady(): boolean
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		return false
	end
	return folder:GetAttribute(READY_ATTRIBUTE) == true
end

function Remotes.waitReady()
	resolveFolder()
end

return Remotes
