local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadingScreen = require(script:WaitForChild("LoadingScreen"))

LoadingScreen.show()
LoadingScreen.setStatus("กำลังเริ่มต้น...")
LoadingScreen.setProgress(0.05)

LoadingScreen.setStatus("กำลังเชื่อมต่อเซิร์ฟเวอร์...")

local Shared = ReplicatedStorage:WaitForChild("Shared")
LoadingScreen.setProgress(0.15)

local RemotesModule = require(Shared:WaitForChild("Remotes"))
RemotesModule.waitReady()
LoadingScreen.setProgress(0.30)

LoadingScreen.setStatus("กำลังโหลดข้อมูลผู้เล่น...")

local OreGenerator = require(script:WaitForChild("OreGenerator"))
LoadingScreen.setProgress(0.50)

LoadingScreen.setStatus("กำลังสร้างฉาก...")

local ok, err = pcall(function()
	OreGenerator.start()
end)
if not ok then
	warn(string.format("[Client] OreGenerator.start failed: %s", tostring(err)))
end

LoadingScreen.setProgress(0.90)

LoadingScreen.setStatus("เสร็จสิ้น")
LoadingScreen.setProgress(1.0)

task.wait(0.25)
LoadingScreen.hide()
