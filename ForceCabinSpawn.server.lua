-- ============================================================
-- ForceCabinSpawn (Script, ServerScriptService)
--
-- Ger varje joinande spelare sin egen numrerade Spawn-del
-- (Spawn, Spawn2, Spawn3, ... Spawn12) direkt i Workspace, så
-- spelare inte staplas på varandra i lobbyn.
-- ============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local assignedSpawns = {}

local function getSpawnPoints()
	local spawns = {}

	for _, object in ipairs(Workspace:GetChildren()) do
		if object:IsA("BasePart") and object.Name:match("^Spawn%d*$") then
			table.insert(spawns, object)
		end
	end

	table.sort(spawns, function(a, b)
		local aNumber = tonumber(a.Name:match("%d+")) or 1
		local bNumber = tonumber(b.Name:match("%d+")) or 1
		return aNumber < bNumber
	end)

	return spawns
end

local function getFreeSpawn()
	for _, spawnPart in ipairs(getSpawnPoints()) do
		local used = false

		for _, assignedSpawn in pairs(assignedSpawns) do
			if assignedSpawn == spawnPart then
				used = true
				break
			end
		end

		if not used then
			return spawnPart
		end
	end

	return nil
end

local function moveToSpawn(player, character)
	local spawnPart = assignedSpawns[player.UserId]

	if not spawnPart then
		return
	end

	local root = character:WaitForChild("HumanoidRootPart", 10)

	if not root then
		return
	end

	task.wait(2)

	character:PivotTo(spawnPart.CFrame + Vector3.new(0, 4, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	print("[CabinSpawn] Flyttade " .. player.Name .. " till " .. spawnPart.Name)
end

local function setupPlayer(player)
	local spawnPart = getFreeSpawn()

	if not spawnPart then
		warn("[CabinSpawn] Ingen ledig spawn för " .. player.Name)
		return
	end

	assignedSpawns[player.UserId] = spawnPart

	player.CharacterAdded:Connect(function(character)
		task.spawn(moveToSpawn, player, character)
	end)

	if player.Character then
		task.spawn(moveToSpawn, player, player.Character)
	end
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	assignedSpawns[player.UserId] = nil
end)
