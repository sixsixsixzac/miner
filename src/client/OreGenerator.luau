local OreGenerator = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local OreTypes = require(Shared:WaitForChild("OreTypes"))
local RemotesModule = require(Shared:WaitForChild("Remotes"))

local OreManager = require(script.Parent:WaitForChild("OreManager"))

local Remotes
local connectionsBound = false

local function getOreContainer(): Folder
	local container = workspace:FindFirstChild("OreContainer")
	if container and container:IsA("Folder") then
		return container
	end
	container = Instance.new("Folder")
	container.Name = "OreContainer"
	container.Parent = workspace
	return container
end

local function buildPart(oreType: string, position: Vector3, size: Vector3): Part
	local def = OreTypes.get(oreType)
	if not def then
		def = OreTypes.get("Stone")
	end

	local ore = Instance.new("Part")
	ore.Shape = Enum.PartType.Block
	ore.Material = def.material
	ore.Color = def.color
	ore.Size = size
	ore.CanCollide = true
	ore.Anchored = true
	ore.CFrame = CFrame.new(position)
	ore.Parent = getOreContainer()
	return ore
end

local function handleOreClick(oreId: number, entry)
	if not entry.isMineable then
		print(string.format("[OreClient] mine blocked (not mineable yet) id=%d type=%s", oreId, entry.type))
		return
	end
	print(string.format("[OreClient] mine request id=%d type=%s", oreId, entry.type))
	local ok, result = pcall(function()
		return Remotes.MineOre:InvokeServer(oreId)
	end)
	if not ok then
		warn(string.format("[OreClient] MineOre invoke errored id=%d err=%s", oreId, tostring(result)))
	else
		print(string.format("[OreClient] mine response id=%d accepted=%s", oreId, tostring(result)))
	end
end

local function animateRise(part: Part, startY: number, endY: number, duration: number)
	part.CFrame = CFrame.new(part.Position.X, startY, part.Position.Z)
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Bounce, Enum.EasingDirection.In)
	local target = CFrame.new(part.Position.X, endY, part.Position.Z)
	local tween = TweenService:Create(part, tweenInfo, { CFrame = target })
	tween:Play()
end

local function playSpawnEffect(part: Part, oreType: string)
	local def = OreTypes.get(oreType) or OreTypes.get("Stone")
	local color = def.color

	local attachment = Instance.new("Attachment")
	attachment.Name = "SpawnFX"
	attachment.Position = Vector3.new(0, part.Size.Y / 2, 0)
	attachment.Parent = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.6
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Drag = 2
	emitter.Acceleration = Vector3.new(0, -10, 0)
	emitter.Parent = attachment
	emitter:Emit(24)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 5
	light.Range = 10
	light.Parent = part

	TweenService:Create(light, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
		Range = 0,
	}):Play()

	task.delay(0.5, function()
		if light.Parent then
			light:Destroy()
		end
	end)
	task.delay(1.2, function()
		if attachment.Parent then
			attachment:Destroy()
		end
	end)
end

local function createHpBar(part: Part, hp: number, maxHp: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HpBar"
	gui.Adornee = part
	gui.AlwaysOnTop = true
	gui.Size = UDim2.new(0, 60, 0, 8)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 1.2, 0)
	gui.Parent = part

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	bg.BackgroundTransparency = 0.2
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(math.clamp(hp / maxHp, 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
	fill.BorderSizePixel = 0
	fill.Parent = bg

	return gui, fill
end

local function attachHpBar(entry, hp: number, maxHp: number)
	if not maxHp or maxHp <= 1 then
		return
	end
	local gui, fill = createHpBar(entry.part, hp, maxHp)
	entry.hpBar = gui
	entry.hpFill = fill
	entry.hp = hp
	entry.maxHp = maxHp
end

local function playHitEffect(part: Part)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, part.Size.Y / 2, 0)
	attachment.Parent = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200))
	emitter.LightEmission = 0.8
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.25, 0.5)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -8, 0)
	emitter.Parent = attachment
	emitter:Emit(10)

	task.delay(0.7, function()
		if attachment.Parent then
			attachment:Destroy()
		end
	end)
end

local function spawnLocal(oreId: number, oreType: string, position: Vector3, startY: number, endY: number, riseDuration: number, size: Vector3, maxHp: number?)
	if OreManager.get(oreId) then
		return
	end
	local part = buildPart(oreType, Vector3.new(position.X, startY, position.Z), size)
	local entry = OreManager.add(oreId, part, oreType)
	local mhp = maxHp or 1
	attachHpBar(entry, mhp, mhp)
	animateRise(part, startY, endY, riseDuration)
	task.delay(riseDuration * 0.8, function()
		if part.Parent then
			playSpawnEffect(part, oreType)
		end
	end)
end

local function placeFinal(oreId: number, oreType: string, position: Vector3, size: Vector3, hp: number?, maxHp: number?)
	if OreManager.get(oreId) then
		return
	end
	local part = buildPart(oreType, position, size)
	local entry = OreManager.add(oreId, part, oreType)
	entry.isMineable = true
	if maxHp and maxHp > 1 then
		attachHpBar(entry, hp or maxHp, maxHp)
	end
end

local snapshotApplied = false
local pendingMineable: { [number]: boolean } = {}
local pendingDestroyed: { [number]: Player? } = {}
local pendingDamaged: { [number]: { hp: number, maxHp: number } } = {}

local function handleMineable(oreId: number)
	local entry = OreManager.get(oreId)
	if entry then
		entry.isMineable = true
	end
end

local function handleDamaged(oreId: number, hp: number, maxHp: number)
	local entry = OreManager.get(oreId)
	if not entry then
		return
	end
	entry.hp = hp
	entry.maxHp = maxHp
	if not entry.hpFill and entry.part and maxHp and maxHp > 1 then
		attachHpBar(entry, hp, maxHp)
	end
	if entry.hpFill then
		local target = UDim2.new(math.clamp(hp / maxHp, 0, 1), 0, 1, 0)
		TweenService:Create(entry.hpFill, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = target,
		}):Play()
	end
	if entry.part and entry.part.Parent then
		playHitEffect(entry.part)
	end
	print(string.format("[OreClient] hit id=%d type=%s hp=%d/%d", oreId, entry.type, hp, maxHp))
end

local function handleDestroyed(oreId: number, byPlayer: Player?)
	local entry = OreManager.get(oreId)
	local typeStr = entry and entry.type or "?"
	local byName = if typeof(byPlayer) == "Instance" and byPlayer:IsA("Player") then byPlayer.Name else "?"
	print(string.format("[OreClient] mined id=%d type=%s by=%s", oreId, typeStr, byName))
	OreManager.remove(oreId)
end

local function bindRemoteHandlers()
	if connectionsBound then
		return
	end
	connectionsBound = true

	local UserInputService = game:GetService("UserInputService")
	local Players = game:GetService("Players")
	local Camera = workspace.CurrentCamera
	local player = Players.LocalPlayer

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local mouse = player:GetMouse()
		local unitRay = Camera:ScreenPointToRay(mouse.X, mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
		raycastParams.FilterDescendantsInstances = { workspace:FindFirstChild("OreContainer") }

		local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
		if result then
			local hitPart = result.Instance
			for oreId, entry in pairs(OreManager.all()) do
				if entry.part == hitPart then
					handleOreClick(oreId, entry)
					break
				end
			end
		end
	end)

	Remotes.OreSpawned.OnClientEvent:Connect(function(oreId, oreType, position, startY, endY, riseDuration, size, maxHp)
		spawnLocal(oreId, oreType, position, startY, endY, riseDuration, size, maxHp)
	end)

	Remotes.OreMineable.OnClientEvent:Connect(function(oreId)
		if not snapshotApplied then
			pendingMineable[oreId] = true
			return
		end
		handleMineable(oreId)
	end)

	Remotes.OreDamaged.OnClientEvent:Connect(function(oreId, hp, maxHp)
		if not snapshotApplied then
			pendingDamaged[oreId] = { hp = hp, maxHp = maxHp }
			return
		end
		handleDamaged(oreId, hp, maxHp)
	end)

	Remotes.OreDestroyed.OnClientEvent:Connect(function(oreId, byPlayer)
		if not snapshotApplied then
			pendingDestroyed[oreId] = byPlayer or false
			return
		end
		handleDestroyed(oreId, byPlayer)
	end)
end

local function applySnapshot(snapshot)
	if not snapshot or not snapshot.ores then
		return
	end
	local riseDuration = snapshot.riseDuration
	local serverNow = snapshot.serverNow

	for _, info in ipairs(snapshot.ores) do
		if OreManager.get(info.id) then
			continue
		end
		if info.state == "mineable" then
			placeFinal(info.id, info.type, info.position, info.size, info.hp, info.maxHp)
		else
			local remaining = math.max(0, (info.mineableAt or 0) - (serverNow or 0))
			local duration = if remaining > 0 then remaining else riseDuration
			spawnLocal(info.id, info.type, info.position, info.startY, info.endY, duration, info.size, info.maxHp)
			local entry = OreManager.get(info.id)
			if entry and info.hp and info.maxHp and info.hp < info.maxHp and entry.hpFill then
				entry.hp = info.hp
				entry.hpFill.Size = UDim2.new(math.clamp(info.hp / info.maxHp, 0, 1), 0, 1, 0)
			end
		end
	end
end

function OreGenerator.start()
	OreManager.clear()

	Remotes = RemotesModule.get()
	bindRemoteHandlers()

	local ok, snapshot = pcall(function()
		return Remotes.OreSnapshot:InvokeServer()
	end)
	if ok and snapshot then
		applySnapshot(snapshot)
	else
		warn("OreSnapshot request failed")
	end

	for oreId, byPlayer in pairs(pendingDestroyed) do
		handleDestroyed(oreId, if byPlayer == false then nil else byPlayer)
	end
	for oreId in pairs(pendingMineable) do
		handleMineable(oreId)
	end
	for oreId, info in pairs(pendingDamaged) do
		handleDamaged(oreId, info.hp, info.maxHp)
	end
	pendingDestroyed = {}
	pendingMineable = {}
	pendingDamaged = {}
	snapshotApplied = true
end

return OreGenerator